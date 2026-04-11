from __future__ import annotations

import argparse
import json
import sys
import urllib.error
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from movie_appeal_reviews import (
    DEFAULT_CACHE_DIR,
    DEFAULT_CATALOG_PATH,
    DEFAULT_MANIFEST_PATH,
    DEFAULT_REVIEWS_OUTPUT_PATH,
    RETRYABLE_FETCH_STATUSES,
    SUCCESS_FETCH_STATUSES,
    aggregate_movie_metrics,
    build_reviews_url,
    cache_is_fresh,
    cache_path_for_slug,
    detect_challenge_html,
    detect_interactive_console,
    ensure_manifest_entry,
    extract_reviews_from_html,
    fetch_text,
    fetch_text_via_browser,
    is_unexpected_html,
    load_catalog,
    load_manifest,
    now_utc_iso,
    read_cache_html,
    save_manifest,
    sleep_with_backoff,
    write_cache_html,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG_PATH)
    parser.add_argument("--output", type=Path, default=DEFAULT_REVIEWS_OUTPUT_PATH)
    parser.add_argument("--cache-dir", type=Path, default=DEFAULT_CACHE_DIR)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST_PATH)
    parser.add_argument("--max-reviews", type=int, default=3)
    parser.add_argument("--limit", type=int)
    parser.add_argument("--fetch-only", action="store_true")
    parser.add_argument("--parse-only", action="store_true")
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--retry-errors-only", action="store_true")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--max-age-hours", type=int)
    parser.add_argument("--browser-only", action="store_true")
    parser.add_argument("--allow-user-assist", action="store_true")
    parser.add_argument("--interactive-mode", choices=("auto", "always", "never"), default="auto")
    parser.add_argument("--max-challenge-retries", type=int, default=3)
    parser.add_argument("--max-network-retries", type=int, default=3)
    parser.add_argument(
        "--fail-on-error",
        action="store_true",
        help="Return a non-zero exit code if any title ends in a non-success status.",
    )
    return parser.parse_args()


def should_attempt_fetch(
    *,
    args: argparse.Namespace,
    entry: dict[str, Any],
    cache_path: Path,
) -> bool:
    if args.parse_only:
        return False
    if args.force:
        return True
    if args.retry_errors_only:
        return entry.get("fetch_status") in RETRYABLE_FETCH_STATUSES or not cache_path.exists()
    return not cache_is_fresh(cache_path, max_age_hours=args.max_age_hours)


def classify_fetch_success(*, used_cache: bool) -> str:
    return "cached_ok" if used_cache else "ok"


def record_fetch_result(
    entry: dict[str, Any],
    *,
    fetch_status: str,
    http_status: int | None,
    last_error: str | None,
    assist_mode_used: str | None = None,
) -> None:
    entry["fetch_status"] = fetch_status
    entry["http_status"] = http_status
    entry["last_error"] = last_error
    entry["assist_mode_used"] = assist_mode_used
    if fetch_status in SUCCESS_FETCH_STATUSES:
        entry["fetched_at"] = now_utc_iso()


def fetch_with_http(
    url: str,
    *,
    max_network_retries: int,
) -> tuple[str | None, int | None, str | None]:
    http_status: int | None = None
    last_error: str | None = None
    for attempt in range(1, max_network_retries + 1):
        try:
            return fetch_text(url), http_status, None
        except urllib.error.HTTPError as exc:
            http_status = exc.code
            last_error = f"HTTP {exc.code}"
            if exc.code in {429, 500, 502, 503, 504} and attempt < max_network_retries:
                sleep_with_backoff(attempt, base=0.25, maximum=2.0)
                continue
            return None, http_status, last_error
        except Exception as exc:  # noqa: BLE001
            last_error = str(exc)
            if attempt < max_network_retries:
                sleep_with_backoff(attempt, base=0.25, maximum=2.0)
                continue
            return None, http_status, last_error
    return None, http_status, last_error


def handle_challenge(
    *,
    url: str,
    args: argparse.Namespace,
    interactive: bool,
    entry: dict[str, Any],
    browser_session_state: dict[str, bool],
) -> tuple[str | None, str, str | None]:
    entry["challenge_count"] = int(entry.get("challenge_count") or 0) + 1

    if interactive and args.allow_user_assist:
        try:
            html = fetch_text_via_browser(url)
        except Exception as exc:  # noqa: BLE001
            return None, "challenge", str(exc)
        browser_session_state["active"] = True
        if detect_challenge_html(html):
            return None, "challenge", "Browser assist still returned a challenge page."
        return html, "ok", None

    for attempt in range(1, args.max_challenge_retries + 1):
        sleep_with_backoff(attempt, base=0.5, maximum=4.0)
        html, _, error = fetch_with_http(url, max_network_retries=1)
        if html and not detect_challenge_html(html):
            return html, "ok", None
        if error:
            return None, "fetch_error", error
    return None, "challenge_deferred", "Challenge page persisted without interactive assist."


def fetch_movie_page(
    *,
    url: str,
    args: argparse.Namespace,
    interactive: bool,
    entry: dict[str, Any],
    browser_session_state: dict[str, bool],
) -> tuple[str | None, str, int | None, str | None, str | None]:
    entry["attempt_count"] = int(entry.get("attempt_count") or 0) + 1

    if args.browser_only:
        try:
            html = fetch_text_via_browser(url)
        except Exception as exc:  # noqa: BLE001
            return None, "fetch_error", None, str(exc), "browser"
        if detect_challenge_html(html):
            return None, "challenge", None, "Browser-only fetch returned a challenge page.", "browser"
        if is_unexpected_html(html):
            return None, "unexpected_html", None, "Browser fetch returned unexpected HTML.", "browser"
        browser_session_state["active"] = True
        return html, "ok", None, None, "browser"

    html, http_status, error = fetch_with_http(url, max_network_retries=args.max_network_retries)
    if html is None:
        return None, "fetch_error", http_status, error, None
    if detect_challenge_html(html):
        challenge_html, challenge_status, challenge_error = handle_challenge(
            url=url,
            args=args,
            interactive=interactive,
            entry=entry,
            browser_session_state=browser_session_state,
        )
        assist_mode = "browser" if interactive and args.allow_user_assist and browser_session_state.get("active") else None
        if challenge_html is None:
            return None, challenge_status, http_status, challenge_error, assist_mode
        html = challenge_html
        if is_unexpected_html(html):
            return None, "unexpected_html", http_status, "Assisted fetch returned unexpected HTML.", assist_mode
        return html, "ok", http_status, None, assist_mode
    if is_unexpected_html(html):
        return None, "unexpected_html", http_status, "HTTP fetch returned unexpected HTML.", None
    return html, "ok", http_status, None, None


def build_output_movie(
    *,
    movie: dict[str, Any],
    reviews_url: str,
    status: str,
    fetch_status: str | None,
    parser_status: str | None,
    reviews: list[dict[str, Any]],
    last_error: str | None,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "slug": movie["slug"],
        "title": movie.get("title") or movie.get("displayName") or movie["slug"],
        "letterboxd_url": movie["letterboxdURL"],
        "reviews_url": reviews_url,
        "status": status,
        "fetch_status": fetch_status,
        "parser_status": parser_status,
        "review_count": len(reviews),
        "reviews": reviews,
        **aggregate_movie_metrics(reviews),
    }
    if last_error:
        payload["error"] = last_error
    return payload


def parse_cached_movie(
    *,
    movie: dict[str, Any],
    reviews_url: str,
    cache_dir: Path,
    max_reviews: int,
    used_cache: bool,
    entry: dict[str, Any],
) -> dict[str, Any]:
    page_html = read_cache_html(cache_dir, movie["slug"])
    reviews = extract_reviews_from_html(page_html, slug=movie["slug"], max_reviews=max_reviews)
    if reviews:
        entry["parser_status"] = "ok"
        status = classify_fetch_success(used_cache=used_cache)
        return build_output_movie(
            movie=movie,
            reviews_url=reviews_url,
            status=status,
            fetch_status=entry.get("fetch_status"),
            parser_status=entry.get("parser_status"),
            reviews=reviews,
            last_error=entry.get("last_error"),
        )

    entry["parser_status"] = "no_reviews_found"
    return build_output_movie(
        movie=movie,
        reviews_url=reviews_url,
        status="no_reviews_found",
        fetch_status=entry.get("fetch_status"),
        parser_status=entry.get("parser_status"),
        reviews=[],
        last_error=entry.get("last_error") or "No reviews found in cached HTML.",
    )


def main() -> int:
    args = parse_args()
    if args.fetch_only and args.parse_only:
        print("ERROR: --fetch-only and --parse-only cannot be used together.", file=sys.stderr)
        return 1

    catalog = load_catalog(args.catalog)
    if args.limit is not None:
        catalog = catalog[: args.limit]

    interactive = detect_interactive_console(args.interactive_mode)
    manifest = load_manifest(args.manifest)
    browser_session_state = {"active": False}
    payload: dict[str, object] = {
        "generated_at": datetime.now(UTC).isoformat(),
        "catalog_path": str(args.catalog),
        "processed_count": len(catalog),
        "movies": {},
    }
    movies_payload = payload["movies"]
    assert isinstance(movies_payload, dict)

    error_count = 0
    for index, movie in enumerate(catalog, start=1):
        slug = movie["slug"]
        reviews_url = build_reviews_url(movie)
        cache_path = cache_path_for_slug(args.cache_dir, slug)
        entry = ensure_manifest_entry(manifest, slug=slug, reviews_url=reviews_url)
        used_cache = False

        print(f"[{index}/{len(catalog)}] scraping {slug} from {reviews_url}")

        if should_attempt_fetch(args=args, entry=entry, cache_path=cache_path):
            html, fetch_status, http_status, error, assist_mode_used = fetch_movie_page(
                url=reviews_url,
                args=args,
                interactive=interactive,
                entry=entry,
                browser_session_state=browser_session_state,
            )
            record_fetch_result(
                entry,
                fetch_status=fetch_status,
                http_status=http_status,
                last_error=error,
                assist_mode_used=assist_mode_used,
            )
            if html is not None and fetch_status == "ok":
                write_cache_html(args.cache_dir, slug, html)
            elif error:
                print(f"warning: failed to scrape {slug}: {error}", file=sys.stderr)
        elif cache_path.exists():
            used_cache = True
            record_fetch_result(
                entry,
                fetch_status="cached_ok",
                http_status=entry.get("http_status"),
                last_error=entry.get("last_error"),
                assist_mode_used=entry.get("assist_mode_used"),
            )
        else:
            record_fetch_result(
                entry,
                fetch_status="fetch_error",
                http_status=entry.get("http_status"),
                last_error="No cached HTML available for parse-only or resume mode.",
                assist_mode_used=entry.get("assist_mode_used"),
            )

        if args.fetch_only:
            movies_payload[slug] = build_output_movie(
                movie=movie,
                reviews_url=reviews_url,
                status=str(entry.get("fetch_status") or "fetch_error"),
                fetch_status=entry.get("fetch_status"),
                parser_status=entry.get("parser_status"),
                reviews=[],
                last_error=entry.get("last_error"),
            )
        elif cache_path.exists() and str(entry.get("fetch_status")) in SUCCESS_FETCH_STATUSES:
            movies_payload[slug] = parse_cached_movie(
                movie=movie,
                reviews_url=reviews_url,
                cache_dir=args.cache_dir,
                max_reviews=args.max_reviews,
                used_cache=used_cache or args.parse_only,
                entry=entry,
            )
        else:
            movies_payload[slug] = build_output_movie(
                movie=movie,
                reviews_url=reviews_url,
                status=str(entry.get("fetch_status") or "fetch_error"),
                fetch_status=entry.get("fetch_status"),
                parser_status=entry.get("parser_status"),
                reviews=[],
                last_error=entry.get("last_error"),
            )

        if movies_payload[slug]["status"] not in SUCCESS_FETCH_STATUSES:
            error_count += 1

        save_manifest(args.manifest, manifest)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Scraped {len(catalog)} titles into {args.output} ({len(catalog) - error_count} ok, {error_count} non-success)")
    if error_count and args.fail_on_error:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
