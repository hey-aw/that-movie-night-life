#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import re
import sys
import urllib.parse
import urllib.request
from dataclasses import asdict, dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_JSON_PATH = REPO_ROOT / "Data" / "elvis-films.tmdb.json"
OUTPUT_SWIFT_PATH = REPO_ROOT / "Sources" / "ElvisCore" / "ElvisCatalog.swift"
PROJECT_YML_PATH = REPO_ROOT / "project.yml"
TMDB_API_BASE_URL = "https://api.themoviedb.org/3"


@dataclass(frozen=True)
class SeedFilm:
    title: str
    year: int
    letterboxd_slug: str


@dataclass(frozen=True)
class FilmRecord:
    title: str
    year: int
    letterboxdSlug: str
    tmdbMovieID: int
    tmdbPosterPath: str | None
    tmdbBackdropPath: str | None
    tmdbReleaseDate: str
    tmdbRuntimeMinutes: int | None
    tmdbGenres: list[str]
    tmdbTagline: str | None
    logline: str | None


SEED_FILMS = [
    SeedFilm("Love Me Tender", 1956, "love-me-tender"),
    SeedFilm("Loving You", 1957, "loving-you"),
    SeedFilm("Jailhouse Rock", 1957, "jailhouse-rock"),
    SeedFilm("King Creole", 1958, "king-creole"),
    SeedFilm("G.I. Blues", 1960, "gi-blues"),
    SeedFilm("Flaming Star", 1960, "flaming-star"),
    SeedFilm("Wild in the Country", 1961, "wild-in-the-country"),
    SeedFilm("Blue Hawaii", 1961, "blue-hawaii"),
    SeedFilm("Follow That Dream", 1962, "follow-that-dream"),
    SeedFilm("Girls! Girls! Girls!", 1962, "girls-girls-girls"),
    SeedFilm("Kid Galahad", 1962, "kid-galahad-1962"),
    SeedFilm("Fun in Acapulco", 1963, "fun-in-acapulco"),
    SeedFilm("It Happened at the World's Fair", 1963, "it-happened-at-the-worlds-fair"),
    SeedFilm("Kissin' Cousins", 1964, "kissin-cousins"),
    SeedFilm("Viva Las Vegas", 1964, "viva-las-vegas"),
    SeedFilm("Roustabout", 1964, "roustabout"),
    SeedFilm("Girl Happy", 1965, "girl-happy"),
    SeedFilm("Tickle Me", 1965, "tickle-me"),
    SeedFilm("Harum Scarum", 1965, "harum-scarum"),
    SeedFilm("Frankie and Johnny", 1966, "frankie-and-johnny"),
    SeedFilm("Paradise, Hawaiian Style", 1966, "paradise-hawaiian-style"),
    SeedFilm("Spinout", 1966, "spinout"),
    SeedFilm("Clambake", 1967, "clambake"),
    SeedFilm("Easy Come, Easy Go", 1967, "easy-come-easy-go-1967"),
    SeedFilm("Double Trouble", 1967, "double-trouble-1967"),
    SeedFilm("Speedway", 1968, "speedway"),
    SeedFilm("Stay Away, Joe", 1968, "stay-away-joe"),
    SeedFilm("Live a Little, Love a Little", 1968, "live-a-little-love-a-little"),
    SeedFilm("Change of Habit", 1969, "change-of-habit"),
    SeedFilm("Charro!", 1969, "charro"),
    SeedFilm("The Trouble with Girls", 1969, "the-trouble-with-girls"),
]


def main() -> int:
    token = load_tmdb_token()
    output_records: list[FilmRecord] = []

    for seed in SEED_FILMS:
        search_payload = tmdb_get_json(
            "/search/movie",
            {"query": seed.title, "year": seed.year, "include_adult": "false"},
            token,
        )
        match = select_search_match(seed, search_payload.get("results", []))
        if match is None:
            raise SystemExit(f"No TMDb match found for {seed.title} ({seed.year})")

        details = tmdb_get_json(f"/movie/{match['id']}", {}, token)
        output_records.append(build_record(seed, details))

    OUTPUT_JSON_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_JSON_PATH.write_text(
        json.dumps([asdict(record) for record in output_records], indent=2) + "\n"
    )
    OUTPUT_SWIFT_PATH.write_text(render_swift_catalog(output_records))

    print(f"Wrote {len(output_records)} records to {OUTPUT_JSON_PATH}")
    print(f"Wrote Swift catalog to {OUTPUT_SWIFT_PATH}")
    return 0


def load_tmdb_token() -> str:
    token = os.environ.get("TMDB_READ_ACCESS_TOKEN")
    if token:
        return token

    if PROJECT_YML_PATH.exists():
        match = re.search(
            r'INFOPLIST_KEY_TMDBReadAccessToken:\s*"([^"]+)"',
            PROJECT_YML_PATH.read_text(),
        )
        if match:
            return match.group(1)

    raise SystemExit("TMDB_READ_ACCESS_TOKEN is required")


def tmdb_get_json(path: str, params: dict[str, object], token: str) -> dict[str, object]:
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
    with urllib.request.urlopen(request) as response:
        return json.load(response)


def select_search_match(seed: SeedFilm, results: list[dict[str, object]]) -> dict[str, object] | None:
    if not results:
        return None

    def score(result: dict[str, object]) -> tuple[int, int, int, float]:
        title = str(result.get("title") or "")
        release_date = str(result.get("release_date") or "")
        exact_title = normalize_title(title) == normalize_title(seed.title)
        exact_year = release_date.startswith(str(seed.year))
        has_poster = bool(result.get("poster_path"))
        popularity = float(result.get("popularity") or 0)
        return (
            1 if exact_title else 0,
            1 if exact_year else 0,
            1 if has_poster else 0,
            popularity,
        )

    return max(results, key=score)


def build_record(seed: SeedFilm, details: dict[str, object]) -> FilmRecord:
    genres = [genre["name"] for genre in details.get("genres", []) if genre.get("name")]
    return FilmRecord(
        title=seed.title,
        year=seed.year,
        letterboxdSlug=seed.letterboxd_slug,
        tmdbMovieID=int(details["id"]),
        tmdbPosterPath=blank_to_none(details.get("poster_path")),
        tmdbBackdropPath=blank_to_none(details.get("backdrop_path")),
        tmdbReleaseDate=str(details.get("release_date") or ""),
        tmdbRuntimeMinutes=int(details["runtime"]) if details.get("runtime") else None,
        tmdbGenres=genres,
        tmdbTagline=blank_to_none(details.get("tagline")),
        logline=blank_to_none(details.get("overview")),
    )


def normalize_title(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def blank_to_none(value: object) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def swift_string(value: str) -> str:
    escaped_parts: list[str] = []
    for character in value:
        if character == "\\":
            escaped_parts.append("\\\\")
        elif character == "\"":
            escaped_parts.append("\\\"")
        elif character == "\n":
            escaped_parts.append("\\n")
        elif ord(character) < 128:
            escaped_parts.append(character)
        else:
            escaped_parts.append(f"\\u{{{ord(character):X}}}")
    return "".join(escaped_parts)


def swift_optional_string(value: str | None) -> str:
    if value is None:
        return "nil"
    return f"\"{swift_string(value)}\""


def render_swift_catalog(records: list[FilmRecord]) -> str:
    lines = [
        "import Foundation",
        "",
        "// Generated by scripts/build_tmdb_base_dataset.py",
        "public enum ElvisCatalog {",
        "    public static let elvisFilms: [Film] = [",
    ]

    for record in records:
        lines.extend(
            [
                "        Film(",
                f"            title: \"{swift_string(record.title)}\",",
                f"            year: {record.year},",
                f"            letterboxdSlug: \"{swift_string(record.letterboxdSlug)}\",",
                f"            tmdbMovieID: {record.tmdbMovieID},",
                f"            tmdbPosterPath: {swift_optional_string(record.tmdbPosterPath)},",
                f"            tmdbBackdropPath: {swift_optional_string(record.tmdbBackdropPath)},",
                f"            tmdbReleaseDate: \"{swift_string(record.tmdbReleaseDate)}\",",
                f"            tmdbRuntimeMinutes: {record.tmdbRuntimeMinutes if record.tmdbRuntimeMinutes is not None else 'nil'},",
                f"            tmdbGenres: {render_swift_string_array(record.tmdbGenres)},",
                f"            tmdbTagline: {swift_optional_string(record.tmdbTagline)},",
                f"            logline: {swift_optional_string(record.logline)}",
                "        ),",
            ]
        )

    lines.extend(
        [
            "    ]",
            "}",
            "",
        ]
    )
    return "\n".join(lines)


def render_swift_string_array(values: list[str]) -> str:
    return "[" + ", ".join(f"\"{swift_string(value)}\"" for value in values) + "]"


if __name__ == "__main__":
    sys.exit(main())
