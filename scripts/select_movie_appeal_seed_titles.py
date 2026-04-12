from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from catalog_spine import DEFAULT_LANE_VERSION, lane_id_for_name, title_id_for_slug


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CATALOG_PATH = ROOT / "Sources" / "TMNLCore" / "Resources" / "movies.catalog.json"
DEFAULT_OUTPUT_PATH = ROOT / "Data" / "movie-appeal-seed-slugs.json"
DEFAULT_SOURCE_PATH = ROOT / "Data" / "movie-appeal-source.json"

LANES: tuple[tuple[str, set[str]], ...] = (
    ("comedy", {"Comedy"}),
    ("drama-romance", {"Drama", "Romance"}),
    ("thriller-horror", {"Thriller", "Horror"}),
    ("action-science-fiction", {"Action", "Science Fiction"}),
    ("animation-family", {"Animation", "Family"}),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG_PATH)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT_PATH)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE_PATH)
    parser.add_argument(
        "--exclude-existing-source",
        action="store_true",
        help="Skip slugs already present in the reviewed movie-appeal source dataset.",
    )
    parser.add_argument("--per-lane", type=int, default=10)
    return parser.parse_args()


def load_catalog(path: Path) -> list[dict[str, Any]]:
    return json.loads(path.read_text(encoding="utf-8"))


def load_existing_source_slugs(path: Path) -> set[str]:
    if not path.exists():
        return set()
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise TypeError("movie-appeal source must be an object keyed by slug")
    return {slug for slug in payload if isinstance(slug, str)}


def is_eligible(movie: dict[str, Any], *, require_runtime: bool) -> bool:
    return bool(
        movie.get("overview")
        and movie.get("genres")
        and movie.get("aggregateRating") is not None
        and (movie.get("runtimeMinutes") is not None or not require_runtime)
    )


def lane_candidates(
    catalog: list[dict[str, Any]],
    lane_genres: set[str],
    *,
    require_runtime: bool,
    excluded_slugs: set[str],
) -> list[dict[str, Any]]:
    matches = [
        movie
        for movie in catalog
        if is_eligible(movie, require_runtime=require_runtime)
        and lane_genres.intersection(set(movie.get("genres") or []))
        and movie.get("slug") not in excluded_slugs
    ]
    return sorted(
        matches,
        key=lambda movie: (
            -float(movie["aggregateRating"]),
            -int(movie.get("ratingCount") or 0),
            int(movie["number"]),
        ),
    )


def build_seed_payload(
    catalog: list[dict[str, Any]],
    *,
    per_lane: int,
    excluded_slugs: set[str] | None = None,
) -> dict[str, Any]:
    selected_slugs: set[str] = set()
    ordered_slugs: list[str] = []
    lanes_payload: list[dict[str, Any]] = []
    used_runtime_fallback = False
    excluded_slugs = excluded_slugs or set()

    any_remaining_candidates = False

    for lane_name, lane_genres in LANES:
        lane_slugs: list[str] = []
        candidates = lane_candidates(
            catalog,
            lane_genres,
            require_runtime=True,
            excluded_slugs=excluded_slugs,
        )
        if candidates:
            any_remaining_candidates = True
        if len(candidates) < per_lane:
            candidates = lane_candidates(
                catalog,
                lane_genres,
                require_runtime=False,
                excluded_slugs=excluded_slugs,
            )
            used_runtime_fallback = True
            if candidates:
                any_remaining_candidates = True

        for movie in candidates:
            slug = movie["slug"]
            if slug in selected_slugs:
                continue
            selected_slugs.add(slug)
            lane_slugs.append(slug)
            ordered_slugs.append(slug)
            if len(lane_slugs) == per_lane:
                break

        if len(lane_slugs) != per_lane:
            if not any_remaining_candidates:
                return {
                    "eligibility_mode": "complete",
                    "lane_version": DEFAULT_LANE_VERSION,
                    "batch_size": per_lane,
                    "lanes": [],
                    "ordered_slugs": [],
                }
            raise ValueError(
                f"Lane '{lane_name}' only found {len(lane_slugs)} eligible unique titles; expected {per_lane}."
            )

        lanes_payload.append(
            {
                "lane_id": lane_id_for_name(lane_name),
                "lane_family": lane_name,
                "lane_version": DEFAULT_LANE_VERSION,
                "name": lane_name,
                "genres": sorted(lane_genres),
                "batch_size": per_lane,
                "total_titles": len(lane_slugs),
                "slugs": lane_slugs,
                "title_ids": [title_id_for_slug(slug) for slug in lane_slugs],
            }
        )

    return {
        "lane_version": DEFAULT_LANE_VERSION,
        "batch_size": per_lane,
        "eligibility_mode": "missing-runtime-fallback" if used_runtime_fallback else "strict",
        "lanes": lanes_payload,
        "ordered_slugs": ordered_slugs,
    }


def main() -> int:
    args = parse_args()
    catalog = load_catalog(args.catalog)
    excluded_slugs = load_existing_source_slugs(args.source) if args.exclude_existing_source else set()
    payload = build_seed_payload(catalog, per_lane=args.per_lane, excluded_slugs=excluded_slugs)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    if not payload["ordered_slugs"]:
        print(f"no eligible movie appeal titles remain; dataset is complete at {args.output}")
        return 0
    print(f"wrote {len(payload['ordered_slugs'])} seed titles to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
