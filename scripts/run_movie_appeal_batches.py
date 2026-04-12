from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from movie_appeal_tranche_state import (
    CLAIM_FILE_NAME,
    TRANCHE_INDEX_NAME,
    TRANCHE_MANIFEST_NAME,
    WORKER_MANIFEST_NAME,
    acquire_prepare_lock,
    infer_next_tranche_id,
    init_tranche_claim,
    load_json,
    release_prepare_lock,
    replace_tranche_entry,
    tranche_dir_for,
    update_tranche_status,
    write_queue_manifest,
)

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SOURCE_PATH = ROOT / "Data" / "movie-appeal-source.json"
DEFAULT_CATALOG_PATH = ROOT / "Sources" / "TMNLCore" / "Resources" / "movies.catalog.json"
DEFAULT_SEED_PATH = ROOT / "Data" / "movie-appeal-seed-slugs.json"
DEFAULT_BATCH_OUTPUT_DIR = ROOT / "Data" / "movie-appeal-worker-batches"
DEFAULT_RUNTIME_OUTPUT = ROOT / "Sources" / "TMNLCore" / "Resources" / "movie-appeal.json"
DEFAULT_QUEUE_DIR = ROOT / "Data" / "movie-appeal-tranche-queue"
DEFAULT_FRONTIER_JOBS_OUTPUT = ROOT / "Data" / "movie-appeal-enrichment-jobs.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("updates", nargs="*", type=Path, help="Update JSON files to merge before preparing the next tranche.")
    parser.add_argument(
        "--update-glob",
        action="append",
        default=[],
        help="Glob pattern for update files to merge before preparing the next tranche.",
    )
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE_PATH)
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG_PATH)
    parser.add_argument("--seed-output", type=Path, default=DEFAULT_SEED_PATH)
    parser.add_argument("--batch-output-dir", type=Path, default=DEFAULT_BATCH_OUTPUT_DIR)
    parser.add_argument("--runtime-output", type=Path, default=DEFAULT_RUNTIME_OUTPUT)
    parser.add_argument("--queue-dir", type=Path, default=DEFAULT_QUEUE_DIR)
    parser.add_argument("--jobs-output", type=Path, default=DEFAULT_FRONTIER_JOBS_OUTPUT)
    parser.add_argument("--per-lane", type=int, default=10)
    parser.add_argument("--batch-size", type=int, default=10)
    parser.add_argument("--backup", action="store_true", help="Write a backup before merging updates.")
    parser.add_argument("--pretty", action="store_true", help="Pretty-print generated worker batch JSON.")
    parser.add_argument("--dry-run", action="store_true", help="Print steps without executing them.")
    parser.add_argument("--skip-merge", action="store_true", help="Do not merge update files before preparing the next tranche.")
    parser.add_argument("--skip-build", action="store_true", help="Do not rebuild the runtime sidecar after merging updates.")
    parser.add_argument("--skip-select", action="store_true", help="Do not generate the next seed tranche.")
    parser.add_argument("--skip-export", action="store_true", help="Do not generate worker batch files.")
    parser.add_argument("--skip-frontier-jobs", action="store_true", help="Do not generate the frontier enrichment job snapshot.")
    parser.add_argument("--skip-queue", action="store_true", help="Do not snapshot the freshly prepared tranche into the queue.")
    return parser.parse_args()


def collect_update_files(paths: list[Path], patterns: list[str]) -> list[Path]:
    collected: list[Path] = []
    seen: set[Path] = set()

    for path in paths:
        resolved = path if path.is_absolute() else (ROOT / path)
        if resolved not in seen:
            collected.append(resolved)
            seen.add(resolved)

    for pattern in patterns:
        for match in sorted(ROOT.glob(pattern)):
            resolved = match.resolve()
            if resolved not in seen:
                collected.append(resolved)
                seen.add(resolved)

    return collected

def build_steps(args: argparse.Namespace, update_files: list[Path]) -> list[list[str]]:
    steps: list[list[str]] = []
    next_tranche_id = infer_next_tranche_id(args.queue_dir)

    if not args.skip_merge and update_files:
        merge_step = [
            sys.executable,
            str(ROOT / "scripts" / "merge_movie_appeal_worker_updates.py"),
            "--source",
            str(args.source),
            "--allow-new-slugs",
        ]
        if args.backup:
            merge_step.append("--backup")
        merge_step.extend(str(path) for path in update_files)
        steps.append(merge_step)

        if not args.skip_build:
            steps.append(
                [
                    sys.executable,
                    str(ROOT / "scripts" / "build_movie_appeal.py"),
                    "--source",
                    str(args.source),
                    "--output",
                    str(args.runtime_output),
                ]
            )

    if not args.skip_select:
        steps.append(
            [
                sys.executable,
                str(ROOT / "scripts" / "select_movie_appeal_seed_titles.py"),
                "--catalog",
                str(args.catalog),
                "--output",
                str(args.seed_output),
                "--source",
                str(args.source),
                "--exclude-existing-source",
                "--per-lane",
                str(args.per_lane),
            ]
        )

    if not args.skip_export:
        export_step = [
            sys.executable,
            str(ROOT / "scripts" / "export_movie_appeal_worker_batches.py"),
            "--seed",
            str(args.seed_output),
            "--catalog",
            str(args.catalog),
            "--source",
            str(args.source),
            "--output-dir",
            str(args.batch_output_dir),
            "--batch-size",
            str(args.batch_size),
            "--tranche-id",
            str(next_tranche_id),
        ]
        if args.pretty:
            export_step.append("--pretty")
        steps.append(export_step)

    if not args.skip_frontier_jobs and not args.skip_select:
        steps.append(
            [
                sys.executable,
                str(ROOT / "scripts" / "build_frontier_enrichment_jobs.py"),
                "--seed",
                str(args.seed_output),
                "--catalog",
                str(args.catalog),
                "--source",
                str(args.source),
                "--output",
                str(args.jobs_output),
            ]
        )

    return steps


def run_step(step: list[str], *, dry_run: bool) -> int:
    print("+ " + " ".join(step))
    if dry_run:
        return 0
    completed = subprocess.run(step, cwd=ROOT, check=False)
    return completed.returncode


def seed_payload_is_complete(seed_path: Path) -> bool:
    if not seed_path.exists():
        return False
    payload = load_json(seed_path, default={})
    if not isinstance(payload, dict):
        return False
    ordered_slugs = payload.get("ordered_slugs")
    return payload.get("eligibility_mode") == "complete" and ordered_slugs == []


def queue_tranche(args: argparse.Namespace) -> int:
    seed_path = args.seed_output
    batch_manifest_path = args.batch_output_dir / "manifest.json"
    tranche_index_path = args.batch_output_dir / TRANCHE_INDEX_NAME
    tranche_manifest_path = args.batch_output_dir / TRANCHE_MANIFEST_NAME
    queue_dir = args.queue_dir
    next_index = infer_next_tranche_id(queue_dir)
    tranche_dir = queue_dir / f"tranche-{next_index:03d}"

    print(f"+ queue_tranche {tranche_dir}")
    if args.dry_run:
        return 0

    if not seed_path.exists():
        print(f"ERROR: seed file not found for queueing: {seed_path}")
        return 1
    if not batch_manifest_path.exists():
        print(f"ERROR: batch manifest not found for queueing: {batch_manifest_path}")
        return 1
    if not tranche_index_path.exists():
        print(f"ERROR: tranche index not found for queueing: {tranche_index_path}")
        return 1
    if not tranche_manifest_path.exists():
        print(f"ERROR: tranche manifest not found for queueing: {tranche_manifest_path}")
        return 1

    queue_dir.mkdir(parents=True, exist_ok=True)
    temp_root = Path(tempfile.mkdtemp(prefix=f".tranche-{next_index:03d}-", dir=queue_dir))

    queued_seed_path = temp_root / "seed.json"
    queued_manifest_path = temp_root / WORKER_MANIFEST_NAME
    queued_index_path = temp_root / TRANCHE_INDEX_NAME
    queued_tranche_manifest_path = temp_root / TRANCHE_MANIFEST_NAME
    shutil.copy2(seed_path, queued_seed_path)
    shutil.copy2(tranche_index_path, queued_index_path)
    shutil.copy2(tranche_manifest_path, queued_tranche_manifest_path)

    worker_manifest = json.loads(batch_manifest_path.read_text(encoding="utf-8"))
    tranche_index = json.loads(tranche_index_path.read_text(encoding="utf-8"))
    tranche_id = tranche_index.get("tranche_id")
    if tranche_id != next_index:
        print(
            "ERROR: active tranche index does not match next queue slot: "
            f"{tranche_id!r} != {next_index}"
        )
        return 1
    queued_batches: list[dict[str, object]] = []
    for batch in worker_manifest.get("batches", []):
        batch_path = Path(batch["path"])
        if not batch_path.is_absolute():
            batch_path = ROOT / batch_path
        queued_batch_path = temp_root / batch_path.name
        shutil.copy2(batch_path, queued_batch_path)
        queued_batches.append(
            {
                "batch_id": batch["batch_id"],
                "path": str(queued_batch_path),
                "count": batch["count"],
            }
        )

    queued_worker_manifest = dict(worker_manifest)
    queued_worker_manifest["source_seed"] = str(queued_seed_path)
    queued_worker_manifest["batches"] = queued_batches
    atomic_manifest_path = queued_manifest_path
    atomic_manifest_path.write_text(
        json.dumps(queued_worker_manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    claim_path = init_tranche_claim(temp_root, next_index)
    temp_root.rename(tranche_dir)

    seed_payload = json.loads(seed_path.read_text(encoding="utf-8"))
    entry = {
        "tranche_id": next_index,
        "path": str(tranche_dir),
        "seed_path": str(tranche_dir / "seed.json"),
        "worker_manifest_path": str(tranche_dir / WORKER_MANIFEST_NAME),
        "tranche_index_path": str(tranche_dir / TRANCHE_INDEX_NAME),
        "claim_path": str(tranche_dir / CLAIM_FILE_NAME),
        "count": len(seed_payload.get("ordered_slugs", [])),
        "status": "queued",
    }
    replace_tranche_entry(queue_dir, entry)
    update_tranche_status(queue_dir, next_index, "queued", claim_path=tranche_dir / CLAIM_FILE_NAME)
    return 0


def main() -> int:
    args = parse_args()
    update_files = collect_update_files(args.updates, args.update_glob)
    if not args.skip_merge:
        missing = [path for path in update_files if not path.exists()]
        if missing:
            print("ERROR: missing update files: " + ", ".join(str(path) for path in missing))
            return 1

    lock_path: Path | None = None
    try:
        if not args.dry_run:
            try:
                lock_path = acquire_prepare_lock(args.queue_dir)
            except ValueError as error:
                print(f"ERROR: {error}")
                return 1

        steps = build_steps(args, update_files)
        if not steps:
            print("Nothing to do.")
            return 0

        for step in steps:
            exit_code = run_step(step, dry_run=args.dry_run)
            if exit_code != 0:
                return exit_code
            if (
                not args.dry_run
                and not args.skip_select
                and step[1].endswith("select_movie_appeal_seed_titles.py")
                and seed_payload_is_complete(args.seed_output)
            ):
                print("Dataset is complete; no eligible movie appeal titles remain, skipping export and queue.")
                return 0

        if not args.skip_queue and not args.skip_select and not args.skip_export:
            exit_code = queue_tranche(args)
            if exit_code != 0:
                return exit_code

        return 0
    finally:
        release_prepare_lock(lock_path)


if __name__ == "__main__":
    raise SystemExit(main())
