from __future__ import annotations

import argparse
import concurrent.futures
import html
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

from catalog_spine import CATALOG_STATUS_READY, ENRICHMENT_STATUS_PENDING, availability_flags_for_movie, title_id_for_slug


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SEED = Path("/Users/aw/Developer/random-movie-roulette/movies-data.js")
CACHE_PATH = ROOT / "Data" / "letterboxd-page-cache.json"
TMDB_CACHE_PATH = ROOT / "Data" / "tmdb-detail-cache.json"
OUTPUT_PATH = ROOT / "Sources" / "TMNLCore" / "Resources" / "movies.catalog.json"
USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_0_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Safari/537.36"
TMDB_API_BASE_URL = "https://api.themoviedb.org/3"
TMDB_IMAGE_BASE_URL = "https://image.tmdb.org/t/p/w1280"
TMDB_MAX_CAST = 5

MOVIES_PREFIX = "window.MOVIES = "
TMDB_ID_PATTERN = re.compile(r'data-tmdb-id="(?P<id>\d+)"')
RUNTIME_PATTERN = re.compile(r">(?P<minutes>\d+)&nbsp;mins")
JSON_LD_PATTERN = re.compile(r'<script type="application/ld\+json">(?P<payload>.*?)</script>', re.S)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=Path, default=DEFAULT_SEED)
    parser.add_argument("--limit", type=int)
    parser.add_argument("--workers", type=int, default=10)
    parser.add_argument("--force", action="store_true")
    return parser.parse_args()


def read_seed_movies(path: Path) -> list[dict[str, Any]]:
    text = path.read_text(encoding="utf-8")
    if not text.startswith(MOVIES_PREFIX):
        raise ValueError(f"Unsupported movies-data.js format: {path}")
    payload = json.loads(text[len(MOVIES_PREFIX):].rstrip(";\n"))
    movies: list[dict[str, Any]] = []
    for item in payload:
        slug = slug_from_url(item["url"])
        movies.append(
            {
                "number": int(item["number"]),
                "slug": slug,
                "title_id": title_id_for_slug(slug),
                "title": item["title"],
                "year": item["year"],
                "displayName": item["displayName"],
                "letterboxdURL": item["url"],
                "watchURL": f'{item["url"].rstrip("/")}/watch/',
                "posterURL": item["posterUrl"],
                "catalog_status": CATALOG_STATUS_READY,
                "enrichment_status": ENRICHMENT_STATUS_PENDING,
                "review_signal_count": 0,
                "last_enriched_at": None,
            }
        )
    return movies


def slug_from_url(url: str) -> str:
    parts = [part for part in url.split("/") if part]
    if len(parts) < 2 or parts[-2] != "film":
        raise ValueError(f"Unsupported Letterboxd film URL: {url}")
    return parts[-1]


def load_cache() -> dict[str, Any]:
    if not CACHE_PATH.exists():
        return {}
    return json.loads(CACHE_PATH.read_text(encoding="utf-8"))


def save_cache(cache: dict[str, Any]) -> None:
    CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
    CACHE_PATH.write_text(
        json.dumps(cache, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def fetch(url: str, retries: int = 3) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    last_error: Exception | None = None
    for attempt in range(1, retries + 1):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return response.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as exc:
            last_error = exc
            if exc.code in {403, 429} and attempt < retries:
                time.sleep(attempt * 2)
                continue
            raise
        except Exception as exc:  # noqa: BLE001
            last_error = exc
            if attempt < retries:
                time.sleep(attempt)
                continue
            raise
    if last_error:
        raise last_error
    raise RuntimeError(f"Unable to fetch {url}")


def extract_movie_json_ld(page_html: str) -> dict[str, Any]:
    for match in JSON_LD_PATTERN.finditer(page_html):
        raw_payload = html.unescape(match.group("payload")).strip()
        raw_payload = raw_payload.replace("/* <![CDATA[ */", "").replace("/* ]]> */", "").strip()
        if not raw_payload:
            continue
        try:
            parsed = json.loads(raw_payload)
        except json.JSONDecodeError:
            continue

        if isinstance(parsed, dict) and parsed.get("@type") == "Movie":
            return parsed

        graph = parsed.get("@graph") if isinstance(parsed, dict) else None
        if isinstance(graph, list):
            for entry in graph:
                if isinstance(entry, dict) and entry.get("@type") == "Movie":
                    return entry

    raise ValueError("No Movie JSON-LD block found")


def fetch_metadata(movie: dict[str, Any]) -> dict[str, Any]:
    page_html = fetch(movie["letterboxdURL"])
    movie_json = extract_movie_json_ld(page_html)

    rating = movie_json.get("aggregateRating") or {}
    rating_value = rating.get("ratingValue")
    rating_count = rating.get("ratingCount")
    genres = movie_json.get("genre") or []
    if isinstance(genres, str):
        genres = [genres]

    tmdb_match = TMDB_ID_PATTERN.search(page_html)
    runtime_match = RUNTIME_PATTERN.search(page_html)

    return {
        "aggregateRating": float(rating_value) if rating_value is not None else None,
        "ratingCount": int(rating_count) if rating_count is not None else None,
        "genres": genres,
        "tmdbMovieID": int(tmdb_match.group("id")) if tmdb_match else None,
        "runtimeMinutes": int(runtime_match.group("minutes")) if runtime_match else None,
        "certification": None,
        "backdropURL": None,
    }


def load_tmdb_token() -> str | None:
    token = os.environ.get("TMDB_READ_ACCESS_TOKEN")
    if token:
        return token.strip()
    env_path = ROOT / ".env"
    if env_path.exists():
        for line in env_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" not in line:
                continue
            key, _, value = line.partition("=")
            if key.strip() == "TMDB_READ_ACCESS_TOKEN":
                return value.strip().strip('"').strip("'")
    return None


def load_tmdb_cache() -> dict[str, Any]:
    if not TMDB_CACHE_PATH.exists():
        return {}
    return json.loads(TMDB_CACHE_PATH.read_text(encoding="utf-8"))


def save_tmdb_cache(cache: dict[str, Any]) -> None:
    TMDB_CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
    TMDB_CACHE_PATH.write_text(
        json.dumps(cache, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def tmdb_get_json(path: str, params: dict[str, Any], token: str, retries: int = 4) -> dict[str, Any]:
    query = urllib.parse.urlencode(params)
    url = f"{TMDB_API_BASE_URL}{path}"
    if query:
        url = f"{url}?{query}"
    request = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {token}",
            "accept": "application/json",
        },
    )
    last_error: Exception | None = None
    for attempt in range(1, retries + 1):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return json.load(response)
        except urllib.error.HTTPError as exc:
            last_error = exc
            if exc.code == 404:
                raise
            if exc.code in {429, 500, 502, 503, 504} and attempt < retries:
                time.sleep(attempt * 2)
                continue
            raise
        except Exception as exc:  # noqa: BLE001
            last_error = exc
            if attempt < retries:
                time.sleep(attempt)
                continue
            raise
    if last_error:
        raise last_error
    raise RuntimeError(f"Unable to fetch {url}")


def fetch_tmdb_details(tmdb_id: int, token: str) -> dict[str, Any]:
    payload = tmdb_get_json(
        f"/movie/{tmdb_id}",
        {"append_to_response": "credits,release_dates"},
        token,
    )

    crew = (payload.get("credits") or {}).get("crew") or []
    director = next(
        (member.get("name") for member in crew if member.get("job") == "Director" and member.get("name")),
        None,
    )

    cast_entries = (payload.get("credits") or {}).get("cast") or []
    cast_entries.sort(key=lambda c: (c.get("order") if c.get("order") is not None else 1_000_000))
    cast_names = [member.get("name") for member in cast_entries if member.get("name")][:TMDB_MAX_CAST]

    release_dates = (payload.get("release_dates") or {}).get("results") or []
    certification: str | None = None
    for entry in release_dates:
        if entry.get("iso_3166_1") != "US":
            continue
        for release in entry.get("release_dates") or []:
            cert = (release.get("certification") or "").strip()
            if cert:
                certification = cert
                break
        if certification:
            break

    backdrop_path = payload.get("backdrop_path") or None
    backdrop_url = f"{TMDB_IMAGE_BASE_URL}{backdrop_path}" if backdrop_path else None

    overview = (payload.get("overview") or "").strip() or None
    tagline = (payload.get("tagline") or "").strip() or None

    return {
        "overview": overview,
        "tagline": tagline,
        "director": director,
        "cast": cast_names,
        "certification": certification,
        "backdropURL": backdrop_url,
    }


def enrich_with_tmdb(catalog: list[dict[str, Any]], *, workers: int, force: bool) -> None:
    token = load_tmdb_token()
    if not token:
        print("TMDB_READ_ACCESS_TOKEN not set; skipping TMDB enrichment", file=sys.stderr)
        return

    cache = load_tmdb_cache()
    pending_ids = []
    seen: set[int] = set()
    for movie in catalog:
        tmdb_id = movie.get("tmdbMovieID")
        if tmdb_id is None:
            continue
        key = str(tmdb_id)
        if not force and key in cache:
            continue
        if tmdb_id in seen:
            continue
        seen.add(tmdb_id)
        pending_ids.append(tmdb_id)

    if pending_ids:
        total = len(pending_ids)
        print(f"fetching tmdb details: {total} movies", flush=True)
        completed = 0
        last_save = 0
        with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
            futures = {
                executor.submit(fetch_tmdb_details, tmdb_id, token): tmdb_id
                for tmdb_id in pending_ids
            }
            for future in concurrent.futures.as_completed(futures):
                tmdb_id = futures[future]
                completed += 1
                try:
                    cache[str(tmdb_id)] = future.result()
                except urllib.error.HTTPError as exc:
                    print(f"tmdb fetch failed for {tmdb_id}: HTTP {exc.code}", file=sys.stderr, flush=True)
                    cache[str(tmdb_id)] = {
                        "overview": None,
                        "tagline": None,
                        "director": None,
                        "cast": [],
                        "certification": None,
                        "backdropURL": None,
                    }
                except Exception as exc:  # noqa: BLE001
                    print(f"tmdb fetch failed for {tmdb_id}: {exc}", file=sys.stderr, flush=True)
                if completed % 100 == 0 or completed == total:
                    print(f"tmdb progress: {completed}/{total}", flush=True)
                if completed - last_save >= 500:
                    save_tmdb_cache(cache)
                    last_save = completed
        save_tmdb_cache(cache)

    for movie in catalog:
        tmdb_id = movie.get("tmdbMovieID")
        if tmdb_id is None:
            movie.setdefault("overview", None)
            movie.setdefault("tagline", None)
            movie.setdefault("director", None)
            movie.setdefault("cast", [])
            continue
        details = cache.get(str(tmdb_id)) or {}
        movie["overview"] = details.get("overview")
        movie["tagline"] = details.get("tagline")
        movie["director"] = details.get("director")
        movie["cast"] = details.get("cast") or []
        if details.get("certification") and not movie.get("certification"):
            movie["certification"] = details.get("certification")
        if details.get("backdropURL") and not movie.get("backdropURL"):
            movie["backdropURL"] = details.get("backdropURL")


def build_catalog(seed_movies: list[dict[str, Any]], *, workers: int, force: bool) -> list[dict[str, Any]]:
    cache = load_cache()
    pending = [
        movie
        for movie in seed_movies
        if force or movie["slug"] not in cache
    ]

    if pending:
        with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
            futures = {executor.submit(fetch_metadata, movie): movie["slug"] for movie in pending}
            completed = 0
            total = len(futures)
            for future in concurrent.futures.as_completed(futures):
                slug = futures[future]
                completed += 1
                try:
                    cache[slug] = future.result()
                except Exception as exc:  # noqa: BLE001
                    print(f"metadata fetch failed for {slug}: {exc}", file=sys.stderr, flush=True)
                    cache[slug] = {
                        "aggregateRating": None,
                        "ratingCount": None,
                        "genres": [],
                        "tmdbMovieID": None,
                        "runtimeMinutes": None,
                        "certification": None,
                        "backdropURL": None,
                    }
                if completed % 100 == 0 or completed == total:
                    print(f"metadata progress: {completed}/{total}", flush=True)
        save_cache(cache)

    catalog: list[dict[str, Any]] = []
    for movie in seed_movies:
        metadata = cache.get(movie["slug"], {})
        catalog.append(
            {
                **movie,
                "aggregateRating": metadata.get("aggregateRating"),
                "ratingCount": metadata.get("ratingCount"),
                "genres": metadata.get("genres", []),
                "tmdbMovieID": metadata.get("tmdbMovieID"),
                "runtimeMinutes": metadata.get("runtimeMinutes"),
                "certification": metadata.get("certification"),
                "backdropURL": metadata.get("backdropURL"),
            }
        )
        catalog[-1]["availability_flags"] = availability_flags_for_movie(catalog[-1])
    return catalog


def main() -> int:
    args = parse_args()
    seed_movies = read_seed_movies(args.seed)
    if args.limit:
        seed_movies = seed_movies[: args.limit]

    catalog = build_catalog(seed_movies, workers=args.workers, force=args.force)
    enrich_with_tmdb(catalog, workers=args.workers, force=args.force)
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    known_ratings = sum(1 for movie in catalog if movie["aggregateRating"] is not None)
    known_genres = sum(1 for movie in catalog if movie["genres"])
    known_tmdb = sum(1 for movie in catalog if movie["tmdbMovieID"] is not None)
    print(f"wrote {len(catalog)} movies to {OUTPUT_PATH}")
    print(f"aggregate ratings present: {known_ratings}")
    print(f"genres present: {known_genres}")
    print(f"tmdb ids present: {known_tmdb}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
