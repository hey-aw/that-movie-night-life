from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CATALOG_PATH = ROOT / "Sources" / "TMNLCore" / "Resources" / "movies.catalog.json"
DEFAULT_OUTPUT_PATH = ROOT / "Data" / "movie-appeal-seed-slugs.json"

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
    parser.add_argument("--per-lane", type=int, default=10)
    return parser.parse_args()


def load_catalog(path: Path) -> list[dict[str, Any]]:
    return json.loads(path.read_text(encoding="utf-8"))


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
) -> list[dict[str, Any]]:
    matches = [
        movie
        for movie in catalog
        if is_eligible(movie, require_runtime=require_runtime)
        and lane_genres.intersection(set(movie.get("genres") or []))
    ]
    return sorted(
        matches,
        key=lambda movie: (
            -float(movie["aggregateRating"]),
            -int(movie.get("ratingCount") or 0),
            int(movie["number"]),
        ),
    )


def build_seed_payload(catalog: list[dict[str, Any]], *, per_lane: int) -> dict[str, Any]:
    selected_slugs: set[str] = set()
    ordered_slugs: list[str] = []
    lanes_payload: list[dict[str, Any]] = []
    used_runtime_fallback = False

    for lane_name, lane_genres in LANES:
        lane_slugs: list[str] = []
        candidates = lane_candidates(catalog, lane_genres, require_runtime=True)
        if len(candidates) < per_lane:
            candidates = lane_candidates(catalog, lane_genres, require_runtime=False)
            used_runtime_fallback = True

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
            raise ValueError(
                f"Lane '{lane_name}' only found {len(lane_slugs)} eligible unique titles; expected {per_lane}."
            )

        lanes_payload.append(
            {
                "name": lane_name,
                "genres": sorted(lane_genres),
                "slugs": lane_slugs,
            }
        )

    return {
        "eligibility_mode": "missing-runtime-fallback" if used_runtime_fallback else "strict",
        "lanes": lanes_payload,
        "ordered_slugs": ordered_slugs,
    }


def main() -> int:
    args = parse_args()
    catalog = load_catalog(args.catalog)
    payload = build_seed_payload(catalog, per_lane=args.per_lane)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {len(payload['ordered_slugs'])} seed titles to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
