from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
CATALOG_PATH = ROOT / "Sources" / "TMNLCore" / "Resources" / "movies.catalog.json"
OVERRIDES_PATH = ROOT / "Data" / "movie-tag-overrides.json"
OUTPUT_PATH = ROOT / "Sources" / "TMNLCore" / "Resources" / "movie-tags.json"

VIOLENT_GENRES = {"Action", "Crime", "Horror", "Thriller", "War", "Western"}
VIOLENT_TITLE_KEYWORDS = ("kill", "dead", "blood", "revenge", "massacre", "slaughter", "battle", "war")


def load_json(path: Path, default):
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def seed_tags(movie: dict) -> set[str]:
    tags: set[str] = set()
    genres = set(movie.get("genres") or [])
    title = (movie.get("title") or "").lower()

    if genres.intersection(VIOLENT_GENRES) or any(keyword in title for keyword in VIOLENT_TITLE_KEYWORDS):
        tags.add("violent")

    return tags


def main() -> int:
    catalog = load_json(CATALOG_PATH, [])
    overrides = load_json(OVERRIDES_PATH, {"add": {}, "remove": {}})
    add_map = overrides.get("add", {})
    remove_map = overrides.get("remove", {})

    tag_map: dict[str, list[str]] = {}
    for movie in catalog:
        slug = movie["slug"]
        tags = seed_tags(movie)
        tags.update(add_map.get(slug, []))
        tags.difference_update(remove_map.get(slug, []))
        if tags:
            tag_map[slug] = sorted(tags)

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(
        json.dumps(tag_map, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {len(tag_map)} tagged titles to {OUTPUT_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
