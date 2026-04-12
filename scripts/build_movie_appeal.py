from __future__ import annotations

import argparse
import json
import sys
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SOURCE_PATH = ROOT / "Data" / "movie-appeal-source.json"
DEFAULT_OUTPUT_PATH = ROOT / "Sources" / "TMNLCore" / "Resources" / "movie-appeal.json"
VALID_CONFIDENCE = {"high", "medium", "low"}
MAX_SUMMARY_LENGTH = 420
MAX_GUIDANCE_LENGTH = 120
MAX_TAG_COUNT = 3
MAX_SOURCE_QUOTE_COUNT = 3
MAX_SOURCE_QUOTE_LENGTH = 180
MIN_SOURCE_QUOTE_COUNT = 1


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE_PATH)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT_PATH)
    return parser.parse_args()


def load_source(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def normalize_entry(slug: str, entry: Any) -> tuple[dict[str, Any] | None, list[str]]:
    errors: list[str] = []
    if not isinstance(entry, dict):
        return None, [f"{slug}: entry must be an object."]

    normalized: dict[str, Any] = {}

    summary = entry.get("summary")
    if not isinstance(summary, str) or not summary.strip():
        errors.append(f"{slug}: summary is required.")
    else:
        summary = summary.strip()
        if len(summary) > MAX_SUMMARY_LENGTH:
            errors.append(f"{slug}: summary must be {MAX_SUMMARY_LENGTH} characters or fewer.")
        elif summary.count('"') < 2:
            errors.append(f'{slug}: summary must include at least one quoted fragment from a real user quote.')
        else:
            normalized["summary"] = summary

    appeal_tags = entry.get("appeal_tags", [])
    if appeal_tags is None:
        appeal_tags = []
    if not isinstance(appeal_tags, list):
        errors.append(f"{slug}: appeal_tags must be a list.")
    else:
        cleaned_tags: list[str] = []
        if len(appeal_tags) > MAX_TAG_COUNT:
            errors.append(f"{slug}: appeal_tags must contain at most {MAX_TAG_COUNT} items.")
        for raw_tag in appeal_tags:
            if not isinstance(raw_tag, str) or not raw_tag.strip():
                errors.append(f"{slug}: every appeal tag must be a non-empty string.")
                continue
            tag = raw_tag.strip()
            word_count = len(tag.split())
            if word_count < 2 or word_count > 4:
                errors.append(f"{slug}: appeal tag '{tag}' must be 2-4 words.")
                continue
            cleaned_tags.append(tag)
        if cleaned_tags:
            normalized["appeal_tags"] = cleaned_tags

    for source_key in ("good_pick_if", "maybe_skip_if"):
        value = entry.get(source_key)
        if value is None:
            continue
        if not isinstance(value, str) or not value.strip():
            errors.append(f"{slug}: {source_key} must be a non-empty string when present.")
            continue
        value = value.strip()
        if len(value) > MAX_GUIDANCE_LENGTH:
            errors.append(f"{slug}: {source_key} must be {MAX_GUIDANCE_LENGTH} characters or fewer.")
            continue
        normalized[source_key] = value

    confidence = entry.get("confidence")
    if confidence is not None:
        if confidence not in VALID_CONFIDENCE:
            errors.append(f"{slug}: confidence must be one of {sorted(VALID_CONFIDENCE)}.")
        else:
            normalized["confidence"] = confidence

    source_quotes = entry.get("source_quotes")
    if source_quotes is None:
        errors.append(f"{slug}: source_quotes is required.")
    elif not isinstance(source_quotes, list):
        errors.append(f"{slug}: source_quotes must be a list.")
    elif len(source_quotes) < MIN_SOURCE_QUOTE_COUNT:
        errors.append(f"{slug}: source_quotes must contain at least {MIN_SOURCE_QUOTE_COUNT} item.")
    elif len(source_quotes) > MAX_SOURCE_QUOTE_COUNT:
            errors.append(f"{slug}: source_quotes must contain at most {MAX_SOURCE_QUOTE_COUNT} items.")
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
            elif len(text.strip()) > MAX_SOURCE_QUOTE_LENGTH:
                errors.append(
                    f"{slug}: source_quotes[{index}].text must be {MAX_SOURCE_QUOTE_LENGTH} characters or fewer."
                )
            if not isinstance(source, str) or not source.strip():
                errors.append(f"{slug}: source_quotes[{index}].source is required.")
            if not isinstance(url, str) or not url.strip():
                errors.append(f"{slug}: source_quotes[{index}].url is required.")

    return (normalized if not errors else None), errors


def build_payload(source: dict[str, Any]) -> tuple[dict[str, Any], list[str]]:
    if not isinstance(source, dict):
        return {}, ["Top-level source JSON must be an object keyed by movie slug."]

    payload: dict[str, Any] = {}
    errors: list[str] = []
    generated_at = datetime.now(UTC).isoformat()
    for slug in sorted(source):
        normalized, entry_errors = normalize_entry(slug, source[slug])
        if entry_errors:
            errors.extend(entry_errors)
            continue
        assert normalized is not None
        source_quotes = source[slug].get("source_quotes", []) if isinstance(source[slug], dict) else []
        cleaned_highlights = [
            source_quote.get("text", "").strip()
            for source_quote in source_quotes
            if isinstance(source_quote, dict) and isinstance(source_quote.get("text"), str) and source_quote.get("text", "").strip()
        ][:MAX_SOURCE_QUOTE_COUNT]
        payload[slug] = {
            **normalized,
            "why_people_like_this": normalized["summary"],
            "theme_tags": normalized.get("appeal_tags", []),
            "spoiler_safe_summary": normalized["summary"],
            "highlight_excerpts": cleaned_highlights,
            "source_count": len(cleaned_highlights),
            "generated_at": generated_at,
        }
    return payload, errors


def main() -> int:
    args = parse_args()
    source = load_source(args.source)
    payload, errors = build_payload(source)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {len(payload)} movie appeal entries to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
