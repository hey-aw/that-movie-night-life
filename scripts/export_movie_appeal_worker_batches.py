from __future__ import annotations

import argparse
import json
from json import JSONDecodeError
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SEED_PATH = ROOT / "Data" / "movie-appeal-seed-slugs.json"
DEFAULT_CATALOG_PATH = ROOT / "Sources" / "TMNLCore" / "Resources" / "movies.catalog.json"
DEFAULT_SOURCE_PATH = ROOT / "Data" / "movie-appeal-source.json"
DEFAULT_OUTPUT_DIR = ROOT / "Data" / "movie-appeal-worker-batches"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=Path, default=DEFAULT_SEED_PATH)
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG_PATH)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE_PATH)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--batch-size", type=int, default=10)
    parser.add_argument("--pretty", action="store_true", help="Pretty-print batch JSON for manual review")
    return parser.parse_args()


def load_ordered_slugs(path: Path) -> list[str]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except JSONDecodeError:
        raise TypeError(f"{path}: malformed JSON")

    slugs = payload["ordered_slugs"]
    if not isinstance(slugs, list):
        raise TypeError("ordered_slugs must be a list")
    return [slug for slug in slugs if isinstance(slug, str)]


def load_catalog_lookup(path: Path) -> dict[str, dict[str, Any]]:
    try:
        movies = json.loads(path.read_text(encoding="utf-8"))
    except JSONDecodeError:
        raise TypeError(f"{path}: malformed JSON")
    return {
        movie["slug"]: movie
        for movie in movies
        if isinstance(movie, dict) and movie.get("slug")
    }


def load_existing_source(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except JSONDecodeError:
        raise TypeError(f"{path}: malformed JSON")
    if not isinstance(payload, dict):
        raise TypeError("movie-appeal source must be an object keyed by slug")
    return payload


def chunked(items: list[str], size: int) -> list[list[str]]:
    if size <= 0:
        raise ValueError("--batch-size must be greater than 0")
    return [items[i : i + size] for i in range(0, len(items), size)]


def build_context(movie: dict[str, Any], existing_entry: dict[str, Any] | None) -> dict[str, Any]:
    summary = existing_entry.get("summary") if isinstance(existing_entry, dict) else None
    quote_count = 0
    if isinstance(existing_entry, dict):
        source_quotes = existing_entry.get("source_quotes", [])
        if isinstance(source_quotes, list):
            quote_count = len(source_quotes)

    return {
        "title": movie.get("title")
        or movie.get("displayName")
        or movie.get("slug"),
        "year": movie.get("year"),
        "genres": movie.get("genres") or [],
        "aggregateRating": movie.get("aggregateRating"),
        "ratingCount": movie.get("ratingCount"),
        "overview": (movie.get("overview") or "")[:300],
        "has_existing_entry": bool(summary),
        "existing_summary": summary,
        "source_quote_count": quote_count,
    }


def main() -> int:
    args = parse_args()
    ordered_slugs = load_ordered_slugs(args.seed)
    catalog_by_slug = load_catalog_lookup(args.catalog)
    source_payload = load_existing_source(args.source)

    missing = [slug for slug in ordered_slugs if slug not in catalog_by_slug]
    if missing:
        print(
            f"ERROR: missing {len(missing)} slugs in catalog: "
            + ", ".join(missing[:5])
            + ("..." if len(missing) > 5 else ""),
        )
        return 1

    batches = chunked(ordered_slugs, args.batch_size)
    args.output_dir.mkdir(parents=True, exist_ok=True)

    manifest: list[dict[str, Any]] = []
    for batch_index, slugs in enumerate(batches):
        batch_id = batch_index + 1
        titles = []
        for slug in slugs:
            movie = catalog_by_slug[slug]
            existing_entry = source_payload.get(slug, {}) if isinstance(source_payload, dict) else {}
            titles.append({"slug": slug, **build_context(movie, existing_entry)})

        payload = {
            "batch_id": batch_id,
            "total_batches": len(batches),
            "batch_size": args.batch_size,
            "slug_range": {
                "start": batch_index * args.batch_size,
                "end": batch_index * args.batch_size + len(slugs) - 1,
            },
            "slugs": slugs,
            "dispatch_prompt": "Draft concise, spoiler-safe Why People Like It updates for these slugs.",
            "titles": titles,
        }

        batch_path = args.output_dir / f"batch-{batch_id:02d}.json"
        batch_path.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2 if args.pretty else None) + "\n",
            encoding="utf-8",
        )
        manifest.append(
            {
                "batch_id": batch_id,
                "path": str(batch_path),
                "count": len(slugs),
            }
        )

    manifest_path = args.output_dir / "manifest.json"
    manifest_path.write_text(
        json.dumps(
            {
                "source_seed": str(args.seed),
                "source_catalog": str(args.catalog),
                "source_dataset": str(args.source),
                "batch_size": args.batch_size,
                "count": len(ordered_slugs),
                "batches": manifest,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    print(f"Wrote {len(batches)} worker batches to {args.output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
