from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from movie_appeal_reviews import (
    DEFAULT_REVIEWS_OUTPUT_PATH,
    DEFAULT_SUMMARY_OUTPUT_PATH,
    SUCCESS_FETCH_STATUSES,
    summary_fragment,
    trim_quote_text,
)


SUCCESS_REVIEW_STATUSES = SUCCESS_FETCH_STATUSES | {"letterboxdpy_ok"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--reviews", type=Path, default=DEFAULT_REVIEWS_OUTPUT_PATH)
    parser.add_argument("--output", type=Path, default=DEFAULT_SUMMARY_OUTPUT_PATH)
    return parser.parse_args()


def build_summary_entry(movie: dict[str, Any]) -> dict[str, Any] | None:
    reviews = movie.get("reviews")
    fetch_status = movie.get("fetch_status") or movie.get("status")
    parser_status = movie.get("parser_status")
    if fetch_status not in SUCCESS_REVIEW_STATUSES or parser_status not in {None, "ok"}:
        return None
    if not isinstance(reviews, list) or not reviews:
        return None

    selected_reviews: list[dict[str, str]] = []
    seen_texts: set[str] = set()
    for review in reviews:
        if not isinstance(review, dict):
            continue
        text = trim_quote_text(str(review.get("text") or ""))
        author = str(review.get("author") or "").strip()
        url = str(review.get("url") or "").strip()
        if not text or not author or not url or text in seen_texts:
            continue
        seen_texts.add(text)
        selected_reviews.append(
            {
                "text": text,
                "source": f"Letterboxd review by {author}",
                "url": url,
            }
        )
        if len(selected_reviews) == 3:
            break

    if not selected_reviews:
        return None

    title = str(movie.get("title") or movie.get("slug") or "this movie")
    first_fragment = summary_fragment(selected_reviews[0]["text"])
    if len(selected_reviews) > 1:
        second_fragment = summary_fragment(selected_reviews[1]["text"])
        summary = (
            f'Letterboxd reviews keep calling {title} "{first_fragment}" and "{second_fragment}," '
            "which makes the audience case quickly and clearly."
        )
    else:
        summary = (
            f'One Letterboxd review calls {title} "{first_fragment}," '
            "which gets at the movie's immediate appeal."
        )

    return {
        "summary": summary,
        "source_quotes": selected_reviews,
        "confidence": "low",
    }


def main() -> int:
    args = parse_args()
    reviews_payload = json.loads(args.reviews.read_text(encoding="utf-8"))
    movies = reviews_payload.get("movies", {})
    if not isinstance(movies, dict):
        raise ValueError("Scraped review payload must contain a top-level 'movies' object.")

    output_payload: dict[str, Any] = {}
    for slug in sorted(movies):
        movie = movies[slug]
        if not isinstance(movie, dict):
            continue
        entry = build_summary_entry(movie)
        if entry is not None:
            output_payload[slug] = entry

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(output_payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {len(output_payload)} movie appeal draft summaries to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
