from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from movie_appeal_reviews import aggregate_movie_metrics


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CATALOG_PATH = ROOT / "Sources" / "TMNLCore" / "Resources" / "movies.catalog.json"
DEFAULT_OUTPUT_PATH = ROOT / "Data" / "letterboxdpy-reviews.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG_PATH)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT_PATH)
    parser.add_argument("--batch-input", type=Path, help="Optional worker batch/frontier job payload used to scope titles.")
    parser.add_argument("--limit", type=int)
    parser.add_argument(
        "--start-index",
        type=int,
        default=0,
        help="Zero-based index into the scoped catalog to start processing.",
    )
    parser.add_argument(
        "--count",
        type=int,
        help="Maximum number of scoped catalog titles to process from --start-index.",
    )
    parser.add_argument(
        "--resume-from-output",
        action="store_true",
        help="Load existing --output movies first and merge newly processed titles into that payload.",
    )
    parser.add_argument(
        "--only-missing",
        action="store_true",
        help="With --resume-from-output, skip scoped titles already present in the existing output.",
    )
    parser.add_argument(
        "--checkpoint-every",
        type=int,
        default=25,
        help="Write an atomic output checkpoint after this many newly processed titles. Use 0 to disable.",
    )
    parser.add_argument("--max-reviews", type=int, default=12)
    parser.add_argument(
        "--lookup",
        choices=("auto", "slug", "tmdb"),
        default="auto",
        help="How to instantiate letterboxdpy Movie objects. auto prefers tmdbMovieID when present.",
    )
    parser.add_argument(
        "--fail-on-error",
        action="store_true",
        help="Return a non-zero exit code if any title cannot be loaded.",
    )
    args = parser.parse_args()
    if args.start_index < 0:
        parser.error("--start-index must be >= 0")
    if args.count is not None and args.count < 0:
        parser.error("--count must be >= 0")
    if args.limit is not None and args.limit < 0:
        parser.error("--limit must be >= 0")
    if args.checkpoint_every < 0:
        parser.error("--checkpoint-every must be >= 0")
    if args.count is not None and args.limit is not None:
        parser.error("Use --count or --limit, not both.")
    if args.only_missing and not args.resume_from_output:
        parser.error("--only-missing requires --resume-from-output")
    return args


def load_catalog(path: Path) -> list[dict[str, Any]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, list):
        raise TypeError(f"{path}: expected JSON array")
    return [
        movie
        for movie in payload
        if isinstance(movie, dict)
        and isinstance(movie.get("slug"), str)
        and isinstance(movie.get("letterboxdURL"), str)
    ]


def load_requested_slugs(path: Path) -> set[str]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    requested_slugs: set[str] = set()
    if isinstance(payload, dict):
        slugs = payload.get("slugs")
        if isinstance(slugs, list):
            requested_slugs.update(slug for slug in slugs if isinstance(slug, str))
        jobs = payload.get("jobs")
        if isinstance(jobs, list):
            for job in jobs:
                if isinstance(job, dict) and isinstance(job.get("slug"), str):
                    requested_slugs.add(job["slug"])
    if not requested_slugs:
        raise ValueError(f"{path}: expected a payload with 'slugs' or 'jobs[].slug'.")
    return requested_slugs


def load_test_movies() -> dict[str, dict[str, Any]]:
    raw = os.environ.get("TMNL_LETTERBOXDPY_TEST_MOVIES")
    if not raw:
        return {}
    payload = json.loads(raw)
    return payload if isinstance(payload, dict) else {}


def load_existing_movies(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise TypeError(f"{path}: expected JSON object")
    movies = payload.get("movies")
    if not isinstance(movies, dict):
        raise TypeError(f"{path}: expected JSON object with 'movies'")
    return dict(movies)


def select_catalog_slice(catalog: list[dict[str, Any]], *, start_index: int, count: int | None) -> list[dict[str, Any]]:
    selected = catalog[start_index:]
    if count is not None:
        selected = selected[:count]
    return selected


def write_payload(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = path.with_name(f".{path.name}.tmp")
    temp_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    temp_path.replace(path)


def normalize_review(review: dict[str, Any]) -> dict[str, Any] | None:
    text = review.get("review")
    link = review.get("link")
    user = review.get("user") if isinstance(review.get("user"), dict) else {}
    author = user.get("display_name") or user.get("username")
    if not isinstance(text, str) or not text.strip() or not isinstance(link, str) or not link.strip():
        return None
    rating = review.get("rating")
    return {
        "author": str(author) if author else "",
        "text": " ".join(text.split()),
        "url": link,
        "like_count": None,
        "rating_value": float(rating) if isinstance(rating, (int, float)) else None,
    }


def normalize_reviews(reviews: Any, *, max_reviews: int) -> list[dict[str, Any]]:
    if not isinstance(reviews, list):
        return []
    normalized: list[dict[str, Any]] = []
    for review in reviews:
        if not isinstance(review, dict):
            continue
        normalized_review = normalize_review(review)
        if normalized_review is None:
            continue
        normalized.append(normalized_review)
        if len(normalized) >= max_reviews:
            break
    return normalized


def load_movie_with_letterboxdpy(movie: dict[str, Any], *, lookup: str) -> dict[str, Any]:
    try:
        from letterboxdpy.movie import Movie
    except ImportError as exc:
        raise RuntimeError("letterboxdpy is not installed. Run `uv add letterboxdpy`.") from exc

    tmdb_id = movie.get("tmdbMovieID")
    if lookup in {"auto", "tmdb"} and tmdb_id is not None:
        letterboxd_movie = Movie.from_tmdb(tmdb_id)
    else:
        letterboxd_movie = Movie(movie["slug"])
    return {
        "slug": getattr(letterboxd_movie, "slug", movie["slug"]),
        "title": getattr(letterboxd_movie, "title", movie.get("title")),
        "year": getattr(letterboxd_movie, "year", movie.get("year")),
        "tmdb_id": getattr(letterboxd_movie, "tmdb_id", tmdb_id),
        "rating": getattr(letterboxd_movie, "rating", None),
        "popular_reviews": getattr(letterboxd_movie, "popular_reviews", []),
    }


def load_movie_payload(movie: dict[str, Any], *, lookup: str, test_movies: dict[str, dict[str, Any]]) -> dict[str, Any]:
    fixture = test_movies.get(movie["slug"])
    if fixture is not None:
        return fixture
    return load_movie_with_letterboxdpy(movie, lookup=lookup)


def build_output_movie(
    *,
    catalog_movie: dict[str, Any],
    letterboxd_movie: dict[str, Any],
    reviews: list[dict[str, Any]],
    error: str | None = None,
) -> dict[str, Any]:
    status = "ok" if reviews else "no_reviews_found"
    payload: dict[str, Any] = {
        "slug": catalog_movie["slug"],
        "title": catalog_movie.get("title") or catalog_movie.get("displayName") or letterboxd_movie.get("title") or catalog_movie["slug"],
        "letterboxd_url": catalog_movie["letterboxdURL"],
        "source": "letterboxdpy",
        "status": "fetch_error" if error else status,
        "fetch_status": "letterboxdpy_error" if error else "letterboxdpy_ok",
        "parser_status": None if error else ("ok" if reviews else "no_reviews_found"),
        "review_count": len(reviews),
        "reviews": reviews,
        "letterboxdpy": {
            "slug": letterboxd_movie.get("slug"),
            "title": letterboxd_movie.get("title"),
            "year": letterboxd_movie.get("year"),
            "tmdb_id": letterboxd_movie.get("tmdb_id"),
            "rating": letterboxd_movie.get("rating"),
        },
        **aggregate_movie_metrics(reviews),
    }
    if error:
        payload["error"] = error
    return payload


def main() -> int:
    args = parse_args()
    catalog = load_catalog(args.catalog)
    if args.batch_input is not None:
        requested_slugs = load_requested_slugs(args.batch_input)
        catalog = [movie for movie in catalog if movie["slug"] in requested_slugs]
    count = args.count if args.count is not None else args.limit
    catalog = select_catalog_slice(catalog, start_index=args.start_index, count=count)

    test_movies = load_test_movies()
    existing_movies = load_existing_movies(args.output) if args.resume_from_output else {}
    if args.only_missing:
        catalog = [movie for movie in catalog if movie["slug"] not in existing_movies]

    payload: dict[str, Any] = {
        "generated_at": datetime.now(UTC).isoformat(),
        "catalog_path": str(args.catalog),
        "processed_count": 0,
        "source": "letterboxdpy",
        "movies": existing_movies,
    }
    movies_payload = payload["movies"]
    assert isinstance(movies_payload, dict)

    error_count = 0
    for index, movie in enumerate(catalog, start=1):
        slug = movie["slug"]
        print(f"[{index}/{len(catalog)}] loading {slug} with letterboxdpy")
        try:
            letterboxd_movie = load_movie_payload(movie, lookup=args.lookup, test_movies=test_movies)
            reviews = normalize_reviews(letterboxd_movie.get("popular_reviews"), max_reviews=args.max_reviews)
            movies_payload[slug] = build_output_movie(
                catalog_movie=movie,
                letterboxd_movie=letterboxd_movie,
                reviews=reviews,
            )
        except Exception as exc:  # noqa: BLE001
            error_count += 1
            print(f"warning: failed to load {slug}: {exc}", file=sys.stderr)
            movies_payload[slug] = build_output_movie(
                catalog_movie=movie,
                letterboxd_movie={},
                reviews=[],
                error=str(exc),
            )
        if args.checkpoint_every and index % args.checkpoint_every == 0:
            payload["processed_count"] = len(movies_payload)
            write_payload(args.output, payload)
            print(f"Checkpointed {len(movies_payload)} movies to {args.output}")

    payload["processed_count"] = len(movies_payload)
    write_payload(args.output, payload)
    print(f"Wrote {len(movies_payload)} movies to {args.output}")
    if args.fail_on_error and error_count:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
