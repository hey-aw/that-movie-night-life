from __future__ import annotations

import argparse
import json
from json import JSONDecodeError
from pathlib import Path
from typing import Any

from catalog_spine import enrichment_context_for_entry, normalize_seed_lanes, spine_fields_for_movie


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
    parser.add_argument("--tranche-id", type=int, help="Optional tranche index for this exported worker batch set.")
    parser.add_argument("--pretty", action="store_true", help="Pretty-print batch JSON for manual review")
    return parser.parse_args()


def load_seed_payload(path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except JSONDecodeError:
        raise TypeError(f"{path}: malformed JSON")
    if not isinstance(payload, dict):
        raise TypeError(f"{path}: expected JSON object")
    return payload


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

    enrichment_context = enrichment_context_for_entry(existing_entry)
    spine_fields = spine_fields_for_movie(movie, existing_entry)

    return {
        "title_id": spine_fields["title_id"],
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
        "catalog_status": spine_fields["catalog_status"],
        "enrichment_status": spine_fields["enrichment_status"],
        "review_signal_count": spine_fields["review_signal_count"],
        "last_enriched_at": spine_fields["last_enriched_at"],
        "availability_flags": spine_fields["availability_flags"],
        "enrichment_context": enrichment_context,
    }


def main() -> int:
    args = parse_args()
    seed_payload = load_seed_payload(args.seed)
    ordered_slugs_any = seed_payload.get("ordered_slugs")
    if not isinstance(ordered_slugs_any, list):
        raise TypeError("ordered_slugs must be a list")
    ordered_slugs = [slug for slug in ordered_slugs_any if isinstance(slug, str)]
    catalog_by_slug = load_catalog_lookup(args.catalog)
    source_payload = load_existing_source(args.source)
    lane_version, lanes = normalize_seed_lanes(seed_payload, fallback_batch_size=args.batch_size)

    if lanes:
        batch_slices: list[dict[str, Any]] = []
        for lane in lanes:
            lane_batch_size = int(lane.get("batch_size") or args.batch_size)
            start = 0
            batch_index = 0
            while start < len(lane["slugs"]):
                end = min(start + lane_batch_size, len(lane["slugs"]))
                batch_slices.append(
                    {
                        "lane_id": lane["lane_id"],
                        "lane_family": lane["lane_family"],
                        "lane_version": lane["lane_version"],
                        "batch_index": batch_index,
                        "total_lane_batches": (len(lane["slugs"]) + lane_batch_size - 1) // lane_batch_size,
                        "slugs": lane["slugs"][start:end],
                        "title_ids": lane["title_ids"][start:end],
                        "start": start,
                        "end": end - 1,
                    }
                )
                start = end
                batch_index += 1
    else:
        batch_slices = []
        for batch_index, slugs in enumerate(chunked(ordered_slugs, args.batch_size)):
            batch_slices.append(
                {
                    "lane_id": f"batch-{batch_index + 1:02d}",
                    "lane_family": "frontier",
                    "lane_version": lane_version,
                    "batch_index": batch_index,
                    "total_lane_batches": len(chunked(ordered_slugs, args.batch_size)),
                    "slugs": slugs,
                    "title_ids": [f"tmnl:{slug}" for slug in slugs],
                    "start": batch_index * args.batch_size,
                    "end": batch_index * args.batch_size + len(slugs) - 1,
                }
            )

    missing = [slug for slug in ordered_slugs if slug not in catalog_by_slug]
    if missing:
        print(
            f"ERROR: missing {len(missing)} slugs in catalog: "
            + ", ".join(missing[:5])
            + ("..." if len(missing) > 5 else ""),
        )
        return 1

    args.output_dir.mkdir(parents=True, exist_ok=True)

    manifest: list[dict[str, Any]] = []
    total_batches = len(batch_slices)
    for batch_id, batch in enumerate(batch_slices, start=1):
        slugs = batch["slugs"]
        titles = []
        for slug in slugs:
            movie = catalog_by_slug[slug]
            existing_entry = source_payload.get(slug, {}) if isinstance(source_payload, dict) else {}
            titles.append({"slug": slug, **build_context(movie, existing_entry)})

        payload = {
            "tranche_id": args.tranche_id,
            "lane_id": batch["lane_id"],
            "lane_family": batch["lane_family"],
            "lane_version": batch["lane_version"],
            "batch_id": batch_id,
            "batch_index": batch["batch_index"],
            "total_batches": total_batches,
            "total_lane_batches": batch["total_lane_batches"],
            "batch_size": args.batch_size,
            "slug_range": {
                "start": batch["start"],
                "end": batch["end"],
            },
            "slugs": slugs,
            "title_ids": batch["title_ids"],
            "dispatch_prompt": "Draft concise, spoiler-safe Why People Like It updates for these frontier titles.",
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
                "tranche_id": args.tranche_id,
                "source_seed": str(args.seed),
                "source_catalog": str(args.catalog),
                "source_dataset": str(args.source),
                "lane_version": lane_version,
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

    tranche_manifest_path = args.output_dir / "tranche-manifest.json"
    tranche_manifest_path.write_text(
        json.dumps(
            {
                "tranche_id": args.tranche_id,
                "lane_version": lane_version,
                "count": len(ordered_slugs),
                "batch_size": args.batch_size,
                "total_batches": total_batches,
                "update_filename_template": (
                    f"movie-appeal-updates-tranche-{args.tranche_id:03d}-batch-{{batch_id:02d}}.json"
                    if args.tranche_id is not None
                    else "movie-appeal-updates-next-batch-{batch_id:02d}.json"
                ),
                "batches": [
                    {
                        "batch_id": batch["batch_id"],
                        "filename": Path(batch["path"]).name,
                        "count": batch["count"],
                        "lane_id": batch_slices[batch["batch_id"] - 1]["lane_id"],
                        "lane_family": batch_slices[batch["batch_id"] - 1]["lane_family"],
                        "batch_index": batch_slices[batch["batch_id"] - 1]["batch_index"],
                        "slugs": batch_slices[batch["batch_id"] - 1]["slugs"],
                        "title_ids": batch_slices[batch["batch_id"] - 1]["title_ids"],
                    }
                    for batch in manifest
                ],
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    tranche_index_path = args.output_dir / "tranche-index.json"
    tranche_index_path.write_text(
        json.dumps(
            {
                "tranche_id": args.tranche_id,
                "lane_version": lane_version,
                "count": len(ordered_slugs),
                "batch_size": args.batch_size,
                "total_batches": total_batches,
                "update_filename_template": (
                    f"movie-appeal-updates-tranche-{args.tranche_id:03d}-batch-{{batch_id:02d}}.json"
                    if args.tranche_id is not None
                    else "movie-appeal-updates-next-batch-{batch_id:02d}.json"
                ),
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    print(f"Wrote {total_batches} worker batches to {args.output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
