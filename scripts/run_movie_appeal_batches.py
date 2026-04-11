from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SOURCE_PATH = ROOT / "Data" / "movie-appeal-source.json"
DEFAULT_CATALOG_PATH = ROOT / "Sources" / "TMNLCore" / "Resources" / "movies.catalog.json"
DEFAULT_SEED_PATH = ROOT / "Data" / "movie-appeal-seed-slugs.json"
DEFAULT_BATCH_OUTPUT_DIR = ROOT / "Data" / "movie-appeal-worker-batches"
DEFAULT_RUNTIME_OUTPUT = ROOT / "Sources" / "TMNLCore" / "Resources" / "movie-appeal.json"


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
    parser.add_argument("--per-lane", type=int, default=10)
    parser.add_argument("--batch-size", type=int, default=10)
    parser.add_argument("--backup", action="store_true", help="Write a backup before merging updates.")
    parser.add_argument("--pretty", action="store_true", help="Pretty-print generated worker batch JSON.")
    parser.add_argument("--dry-run", action="store_true", help="Print steps without executing them.")
    parser.add_argument("--skip-merge", action="store_true", help="Do not merge update files before preparing the next tranche.")
    parser.add_argument("--skip-build", action="store_true", help="Do not rebuild the runtime sidecar after merging updates.")
    parser.add_argument("--skip-select", action="store_true", help="Do not generate the next seed tranche.")
    parser.add_argument("--skip-export", action="store_true", help="Do not generate worker batch files.")
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
        ]
        if args.pretty:
            export_step.append("--pretty")
        steps.append(export_step)

    return steps


def run_step(step: list[str], *, dry_run: bool) -> int:
    print("+ " + " ".join(step))
    if dry_run:
        return 0
    completed = subprocess.run(step, cwd=ROOT, check=False)
    return completed.returncode


def main() -> int:
    args = parse_args()
    update_files = collect_update_files(args.updates, args.update_glob)
    if not args.skip_merge:
        missing = [path for path in update_files if not path.exists()]
        if missing:
            print("ERROR: missing update files: " + ", ".join(str(path) for path in missing))
            return 1

    steps = build_steps(args, update_files)
    if not steps:
        print("Nothing to do.")
        return 0

    for step in steps:
        exit_code = run_step(step, dry_run=args.dry_run)
        if exit_code != 0:
            return exit_code

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
