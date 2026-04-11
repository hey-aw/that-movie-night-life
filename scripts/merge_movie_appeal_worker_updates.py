from __future__ import annotations

import argparse
import json
from json import JSONDecodeError
from pathlib import Path
from typing import Any

from movie_appeal_tranche_state import (
    CLAIM_FILE_NAME,
    TRANCHE_MANIFEST_NAME,
    claim_is_expired,
    normalize_update_payload,
    read_claim,
    read_mirror_state,
    tranche_dir_for,
)

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SOURCE_PATH = ROOT / "Data" / "movie-appeal-source.json"
DEFAULT_QUEUE_DIR = ROOT / "Data" / "movie-appeal-tranche-queue"
DEFAULT_WORKER_BATCHES_DIR = ROOT / "Data" / "movie-appeal-worker-batches"

ALLOWED_UPDATE_FIELDS = {
    "summary",
    "appeal_tags",
    "good_pick_if",
    "maybe_skip_if",
    "nearby_comps",
    "confidence",
    "source_quotes",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE_PATH)
    parser.add_argument("--queue-dir", type=Path, default=DEFAULT_QUEUE_DIR)
    parser.add_argument("--worker-batches-dir", type=Path, default=DEFAULT_WORKER_BATCHES_DIR)
    parser.add_argument("--owner", help="Claim owner attempting the merge for tranche-aware update envelopes.")
    parser.add_argument(
        "--allow-new-slugs",
        action="store_true",
        help="Allow update files to introduce new slug entries into the source dataset.",
    )
    parser.add_argument("updates", nargs="+", type=Path, help="JSON files produced by subagents")
    parser.add_argument("--dry-run", action="store_true", help="Show diffs only, do not write source file")
    parser.add_argument("--backup", action="store_true", help="Write .bak backup before applying")
    return parser.parse_args()


def load_json_object(path: Path, *, allow_array: bool = False) -> dict[str, Any] | list[Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except JSONDecodeError:
        raise ValueError(f"{path}: malformed JSON")

    if isinstance(payload, dict):
        return payload
    if allow_array and isinstance(payload, list):
        return payload
    if allow_array:
        raise ValueError(f"{path}: expected JSON array or object")
    raise ValueError(f"{path}: expected JSON object")


def validate_envelope_context(
    *,
    queue_dir: Path,
    worker_batches_dir: Path,
    owner: str | None,
    tranche_id: int,
    batch_id: int,
    update_slugs: list[str],
) -> list[str]:
    errors: list[str] = []
    tranche_dir = tranche_dir_for(queue_dir, tranche_id)
    if not tranche_dir.exists():
        return [f"{tranche_dir}: tranche directory does not exist"]

    claim = read_claim(tranche_dir)
    if claim.get("status") == "completed":
        return [f"tranche {tranche_id} is already completed; archive or quarantine this update file instead of merging it"]

    mirror_state = read_mirror_state(worker_batches_dir)
    mirrored_tranche_id = None
    if mirror_state is not None:
        mirrored_tranche_id = mirror_state.get("tranche_id")
    else:
        tranche_index_path = worker_batches_dir / "tranche-index.json"
        if tranche_index_path.exists():
            mirror_index = load_json_object(tranche_index_path)
            if isinstance(mirror_index, dict):
                mirrored_tranche_id = mirror_index.get("tranche_id")
    if mirrored_tranche_id is not None and int(mirrored_tranche_id) != tranche_id:
        errors.append(
            f"update file targets tranche {tranche_id}, but active mirrored tranche is {mirrored_tranche_id}"
        )

    if claim.get("status") == "claimed":
        if owner is None:
            errors.append(
                f"tranche {tranche_id} is claimed by {claim.get('owner')} until {claim.get('expires_at')}; pass --owner to merge safely"
            )
        elif claim.get("owner") != owner and not claim_is_expired(claim):
            errors.append(
                f"tranche {tranche_id} is claimed by {claim.get('owner')} until {claim.get('expires_at')}"
            )

    tranche_manifest_path = tranche_dir / TRANCHE_MANIFEST_NAME
    tranche_manifest = load_json_object(tranche_manifest_path)
    if not isinstance(tranche_manifest, dict):
        return errors + [f"{tranche_manifest_path}: expected JSON object"]
    batches = tranche_manifest.get("batches")
    if not isinstance(batches, list):
        return errors + [f"{tranche_manifest_path}: missing batches list"]
    batch_entry = next((entry for entry in batches if int(entry.get("batch_id")) == batch_id), None)
    if batch_entry is None:
        return errors + [f"tranche {tranche_id} does not define batch {batch_id}"]
    expected_slugs = batch_entry.get("slugs", [])
    if not isinstance(expected_slugs, list):
        return errors + [f"{tranche_manifest_path}: batch {batch_id} is missing slugs"]
    unexpected_slugs = [slug for slug in update_slugs if slug not in expected_slugs]
    if unexpected_slugs:
        errors.append(
            f"batch {batch_id} for tranche {tranche_id} does not include slugs: {', '.join(unexpected_slugs)}"
        )
    return errors


def validate_update_object(
    update: Any,
    source_slugs: set[str],
    *,
    allow_new_slugs: bool,
) -> tuple[str, dict[str, Any], list[str]]:
    errors: list[str] = []
    if not isinstance(update, dict):
        return "", {}, ["update item must be an object"]

    slug = update.get("slug")
    if not isinstance(slug, str) or not slug.strip():
        return "", {}, ["update item missing slug"]
    slug = slug.strip()

    if slug not in source_slugs and not allow_new_slugs:
        errors.append(f"{slug}: slug is not in current source dataset")

    if not isinstance(update.get("slug"), str):
        errors.append(f"{slug or '<missing>'}: slug must be string")

    payload: dict[str, Any] = {}
    for key, value in update.items():
        if key == "slug":
            continue
        if key not in ALLOWED_UPDATE_FIELDS:
            errors.append(f"{slug}: unexpected field '{key}'")
            continue
        payload[key] = value

    if not payload:
        errors.append(f"{slug}: no update fields provided")

    summary = payload.get("summary")
    if summary is not None:
        if not isinstance(summary, str) or not summary.strip():
            errors.append(f"{slug}: summary must be a non-empty string")

    appeal_tags = payload.get("appeal_tags")
    if appeal_tags is not None:
        if not isinstance(appeal_tags, list):
            errors.append(f"{slug}: appeal_tags must be a list")
        else:
            cleaned_tags: list[str] = []
            for raw_tag in appeal_tags:
                if not isinstance(raw_tag, str) or not raw_tag.strip():
                    errors.append(f"{slug}: appeal_tags entries must be non-empty strings")
                    continue
                cleaned_tags.append(raw_tag.strip())
            payload["appeal_tags"] = cleaned_tags

    source_quotes = payload.get("source_quotes")
    if source_quotes is not None:
        if not isinstance(source_quotes, list) or len(source_quotes) == 0:
            errors.append(f"{slug}: source_quotes must be a non-empty array when present")
        else:
            for index, source_quote in enumerate(source_quotes, start=1):
                if not isinstance(source_quote, dict):
                    errors.append(f"{slug}: source_quotes[{index}] must be an object.")
                    continue
                text = source_quote.get("text")
                source = source_quote.get("source")
                url = source_quote.get("url")
                if not isinstance(text, str) or not text.strip():
                    errors.append(f"{slug}: source_quotes[{index}].text is required.")
                if not isinstance(source, str) or not source.strip():
                    errors.append(f"{slug}: source_quotes[{index}].source is required.")
                if not isinstance(url, str) or not url.strip():
                    errors.append(f"{slug}: source_quotes[{index}].url is required.")

    return slug, payload, errors


def main() -> int:
    args = parse_args()
    if not args.source.exists():
        print(f"ERROR: source file not found: {args.source}")
        return 1

    original_source_text = args.source.read_text(encoding="utf-8")
    try:
        source_payload_any = load_json_object(args.source)
    except ValueError as error:
        print(f"ERROR: {error}")
        return 1
    source_payload = source_payload_any
    if not isinstance(source_payload, dict):
        print("ERROR: source must be a JSON object keyed by slug")
        return 1

    source_slugs = set(source_payload.keys())
    updated = 0
    errors: list[str] = []

    for update_path in args.updates:
        if not update_path.exists():
            errors.append(f"{update_path}: update file does not exist")
            continue
        try:
            update_payload = load_json_object(update_path, allow_array=True)
        except ValueError as error:
            errors.append(str(error))
            continue
        try:
            tranche_id, batch_id, updates, _is_legacy_array = normalize_update_payload(update_payload, update_path)
        except ValueError as error:
            errors.append(str(error))
            continue
        if tranche_id is not None and batch_id is not None:
            envelope_errors = validate_envelope_context(
                queue_dir=args.queue_dir,
                worker_batches_dir=args.worker_batches_dir,
                owner=args.owner,
                tranche_id=tranche_id,
                batch_id=batch_id,
                update_slugs=[
                    item.get("slug")
                    for item in updates
                    if isinstance(item, dict) and isinstance(item.get("slug"), str)
                ],
            )
            if envelope_errors:
                errors.extend(envelope_errors)
                continue

        for item in updates:
            slug, update_data, item_errors = validate_update_object(
                item,
                source_slugs,
                allow_new_slugs=args.allow_new_slugs,
            )
            if item_errors:
                errors.extend(item_errors)
                continue
            if slug not in source_payload:
                if not args.allow_new_slugs:
                    errors.append(f"{slug}: existing source entry must be an object to merge updates")
                    continue
                source_payload[slug] = {}
                source_slugs.add(slug)
            elif not isinstance(source_payload.get(slug), dict):
                errors.append(f"{slug}: existing source entry must be an object to merge updates")
                continue

            source_payload[slug].update(update_data)
            updated += 1

    if errors:
        print("\n".join(errors))
        return 1

    print(f"Applying {updated} updates")

    if args.dry_run:
        print(f"Applying {updated} updates (dry-run)")
        return 0

    if args.backup:
        backup_path = args.source.with_suffix(".json.bak")
        backup_path.write_text(original_source_text, encoding="utf-8")

    args.source.write_text(json.dumps(source_payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote merged source to {args.source}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
