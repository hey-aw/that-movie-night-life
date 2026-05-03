from __future__ import annotations

from typing import Any


TITLE_ID_PREFIX = "tmnl:"
DEFAULT_LANE_VERSION = "movie-appeal-v1"
CATALOG_STATUS_READY = "ready"
ENRICHMENT_STATUS_PENDING = "pending"
ENRICHMENT_STATUS_READY = "ready"


def title_id_for_slug(slug: str) -> str:
    return f"{TITLE_ID_PREFIX}{slug}"


def lane_id_for_name(name: str) -> str:
    return name.strip().lower()


def availability_flags_for_movie(movie: dict[str, Any]) -> list[str]:
    flags: list[str] = []
    if movie.get("watchURL"):
        flags.append("watch_url_available")
    if movie.get("posterURL"):
        flags.append("poster_available")
    if movie.get("backdropURL"):
        flags.append("backdrop_available")
    return flags


def _clean_source_quotes(existing_entry: dict[str, Any] | None) -> list[dict[str, str]]:
    if not isinstance(existing_entry, dict):
        return []
    source_quotes = existing_entry.get("source_quotes")
    if not isinstance(source_quotes, list):
        return []

    cleaned: list[dict[str, str]] = []
    for source_quote in source_quotes:
        if not isinstance(source_quote, dict):
            continue
        text = str(source_quote.get("text") or "").strip()
        source = str(source_quote.get("source") or "").strip()
        url = str(source_quote.get("url") or "").strip()
        if not text or not source or not url:
            continue
        cleaned.append(
            {
                "text": text,
                "source": source,
                "url": url,
            }
        )
    return cleaned


def enrichment_context_for_entry(existing_entry: dict[str, Any] | None) -> dict[str, Any] | None:
    if not isinstance(existing_entry, dict):
        return None

    summary = str(existing_entry.get("summary") or "").strip()
    if not summary:
        return None

    quotes = _clean_source_quotes(existing_entry)
    raw_theme_tags = existing_entry.get("appeal_tags")
    theme_tags = [tag.strip() for tag in raw_theme_tags if isinstance(tag, str) and tag.strip()] if isinstance(raw_theme_tags, list) else []

    return {
        "why_people_like_this": summary,
        "highlight_excerpts": [quote["text"] for quote in quotes[:3]],
        "theme_tags": theme_tags,
        "spoiler_safe_summary": str(existing_entry.get("spoiler_safe_summary") or summary).strip(),
        "confidence": existing_entry.get("confidence"),
        "source_count": len(quotes),
        "generated_at": existing_entry.get("generated_at"),
    }


def enrichment_status_for(existing_entry: dict[str, Any] | None, explicit_status: Any = None) -> str:
    if isinstance(explicit_status, str) and explicit_status.strip():
        return explicit_status.strip()
    return ENRICHMENT_STATUS_READY if enrichment_context_for_entry(existing_entry) else ENRICHMENT_STATUS_PENDING


def review_signal_count_for(existing_entry: dict[str, Any] | None, explicit_count: Any = None) -> int:
    if isinstance(explicit_count, int):
        return explicit_count
    return len(_clean_source_quotes(existing_entry))


def last_enriched_at_for(existing_entry: dict[str, Any] | None, explicit_value: Any = None) -> str | None:
    if isinstance(explicit_value, str) and explicit_value.strip():
        return explicit_value.strip()
    context = enrichment_context_for_entry(existing_entry)
    if context is None:
        return None
    generated_at = context.get("generated_at")
    return generated_at if isinstance(generated_at, str) and generated_at.strip() else None


def spine_fields_for_movie(movie: dict[str, Any], existing_entry: dict[str, Any] | None = None) -> dict[str, Any]:
    slug = str(movie["slug"])
    return {
        "title_id": str(movie.get("title_id") or movie.get("titleID") or title_id_for_slug(slug)),
        "catalog_status": str(movie.get("catalog_status") or movie.get("catalogStatus") or CATALOG_STATUS_READY),
        "enrichment_status": enrichment_status_for(
            existing_entry,
            movie.get("enrichment_status") or movie.get("enrichmentStatus"),
        ),
        "review_signal_count": review_signal_count_for(
            existing_entry,
            movie.get("review_signal_count") or movie.get("reviewSignalCount"),
        ),
        "last_enriched_at": last_enriched_at_for(
            existing_entry,
            movie.get("last_enriched_at") or movie.get("lastEnrichedAt"),
        ),
        "availability_flags": list(movie.get("availability_flags") or movie.get("availabilityFlags") or availability_flags_for_movie(movie)),
    }


def normalize_seed_lanes(payload: dict[str, Any], *, fallback_batch_size: int | None = None) -> tuple[str, list[dict[str, Any]]]:
    lane_version = str(payload.get("lane_version") or DEFAULT_LANE_VERSION)
    raw_lanes = payload.get("lanes")
    if not isinstance(raw_lanes, list):
        return lane_version, []

    normalized: list[dict[str, Any]] = []
    for index, raw_lane in enumerate(raw_lanes, start=1):
        if not isinstance(raw_lane, dict):
            continue
        name = str(raw_lane.get("name") or f"lane-{index}").strip()
        slugs = [slug for slug in raw_lane.get("slugs", []) if isinstance(slug, str)]
        if not slugs:
            continue
        title_ids = [title_id for title_id in raw_lane.get("title_ids", []) if isinstance(title_id, str)]
        if len(title_ids) != len(slugs):
            title_ids = [title_id_for_slug(slug) for slug in slugs]

        batch_size = raw_lane.get("batch_size")
        if not isinstance(batch_size, int) or batch_size <= 0:
            inherited_batch_size = payload.get("batch_size")
            if isinstance(inherited_batch_size, int) and inherited_batch_size > 0:
                batch_size = inherited_batch_size
            elif isinstance(fallback_batch_size, int) and fallback_batch_size > 0:
                batch_size = fallback_batch_size
            else:
                batch_size = len(slugs)

        normalized.append(
            {
                "lane_id": str(raw_lane.get("lane_id") or lane_id_for_name(name)),
                "lane_family": str(raw_lane.get("lane_family") or name),
                "name": name,
                "lane_version": str(raw_lane.get("lane_version") or lane_version),
                "batch_size": batch_size,
                "slugs": slugs,
                "title_ids": title_ids,
                "total_titles": len(slugs),
            }
        )
    return lane_version, normalized


def iter_lane_batches(lane: dict[str, Any], *, batch_size: int | None = None) -> list[dict[str, Any]]:
    slugs = list(lane["slugs"])
    title_ids = list(lane["title_ids"])
    size = batch_size if isinstance(batch_size, int) and batch_size > 0 else int(lane.get("batch_size") or len(slugs) or 1)
    total_batches = (len(slugs) + size - 1) // size

    batches: list[dict[str, Any]] = []
    for batch_index, start in enumerate(range(0, len(slugs), size)):
        end = min(start + size, len(slugs))
        batches.append(
            {
                "lane_id": lane["lane_id"],
                "lane_family": lane["lane_family"],
                "lane_version": lane["lane_version"],
                "batch_index": batch_index,
                "total_batches": total_batches,
                "slugs": slugs[start:end],
                "title_ids": title_ids[start:end],
                "start": start,
                "end": end - 1,
            }
        )
    return batches
