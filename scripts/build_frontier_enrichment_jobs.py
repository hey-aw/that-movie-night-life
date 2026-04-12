from __future__ import annotations

import argparse
import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from catalog_spine import (
    DEFAULT_LANE_VERSION,
    ENRICHMENT_STATUS_READY,
    enrichment_status_for,
    normalize_seed_lanes,
    spine_fields_for_movie,
)


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SEED_PATH = ROOT / "Data" / "movie-appeal-seed-slugs.json"
DEFAULT_CATALOG_PATH = ROOT / "Sources" / "TMNLCore" / "Resources" / "movies.catalog.json"
DEFAULT_SOURCE_PATH = ROOT / "Data" / "movie-appeal-source.json"
DEFAULT_OUTPUT_PATH = ROOT / "Data" / "movie-appeal-enrichment-jobs.json"

REASON_PRIORITY = {
    "lane_frontier_current": 700,
    "lane_frontier_next": 600,
    "new_lane_claim": 500,
    "hot_title": 400,
    "artifact_stale": 300,
    "cold_backfill": 100,
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=Path, default=DEFAULT_SEED_PATH)
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG_PATH)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE_PATH)
    parser.add_argument("--activity", type=Path)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT_PATH)
    parser.add_argument("--batch-size", type=int)
    parser.add_argument("--next-batch-window", type=int, default=3)
    parser.add_argument("--global-frontier-batches", type=int, default=10)
    return parser.parse_args()


def load_json_object(path: Path | None, *, default: dict[str, Any] | None = None) -> dict[str, Any]:
    if path is None or not path.exists():
        return {} if default is None else default
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise TypeError(f"{path}: expected JSON object")
    return payload


def load_catalog_lookup(path: Path) -> dict[str, dict[str, Any]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, list):
        raise TypeError(f"{path}: expected JSON array")
    return {
        movie["slug"]: movie
        for movie in payload
        if isinstance(movie, dict) and isinstance(movie.get("slug"), str)
    }


def build_jobs(
    *,
    lanes: list[dict[str, Any]],
    catalog_by_slug: dict[str, dict[str, Any]],
    source_payload: dict[str, Any],
    activity_payload: dict[str, Any],
    next_batch_window: int,
    global_frontier_batches: int,
) -> list[dict[str, Any]]:
    active_lanes = {
        str(entry["lane_id"]): int(entry.get("current_batch_index") or 0)
        for entry in activity_payload.get("active_lanes", [])
        if isinstance(entry, dict) and isinstance(entry.get("lane_id"), str)
    }
    newly_claimed_lane_ids = {
        str(lane_id)
        for lane_id in activity_payload.get("newly_claimed_lane_ids", [])
        if isinstance(lane_id, str)
    }
    hot_title_ids = {
        str(title_id)
        for title_id in activity_payload.get("hot_title_ids", [])
        if isinstance(title_id, str)
    }
    stale_title_ids = {
        str(title_id)
        for title_id in activity_payload.get("stale_title_ids", [])
        if isinstance(title_id, str)
    }

    jobs: dict[str, dict[str, Any]] = {}

    def add_job(
        *,
        title_id: str,
        slug: str,
        reason: str,
        priority: int | None = None,
        lane_id: str | None = None,
        lane_family: str | None = None,
        batch_index: int | None = None,
        position_in_batch: int | None = None,
    ) -> None:
        movie = catalog_by_slug[slug]
        existing_entry = source_payload.get(slug) if isinstance(source_payload, dict) else None
        spine_fields = spine_fields_for_movie(movie, existing_entry if isinstance(existing_entry, dict) else None)
        current_status = enrichment_status_for(existing_entry if isinstance(existing_entry, dict) else None, spine_fields["enrichment_status"])
        if reason != "artifact_stale" and current_status == ENRICHMENT_STATUS_READY:
            return

        resolved_priority = priority if isinstance(priority, int) else REASON_PRIORITY[reason]
        current_job = jobs.get(title_id)
        if current_job is not None and current_job["priority"] >= resolved_priority:
            return

        jobs[title_id] = {
            "job_id": f"{reason}:{title_id}",
            "title_id": title_id,
            "slug": slug,
            "reason": reason,
            "priority": resolved_priority,
            "lane_id": lane_id,
            "lane_family": lane_family,
            "batch_index": batch_index,
            "position_in_batch": position_in_batch,
            "status": "queued",
        }

    for lane in lanes:
        batch_size = int(lane.get("batch_size") or len(lane["slugs"]) or 1)
        batches = [
            {
                "batch_index": batch_index,
                "slugs": lane["slugs"][start : start + batch_size],
                "title_ids": lane["title_ids"][start : start + batch_size],
            }
            for batch_index, start in enumerate(range(0, len(lane["slugs"]), batch_size))
        ]

        current_batch_index = active_lanes.get(lane["lane_id"])
        if current_batch_index is not None:
            for batch in batches:
                distance = batch["batch_index"] - current_batch_index
                if distance < 0:
                    continue
                if distance == 0:
                    reason = "lane_frontier_current"
                elif distance <= next_batch_window:
                    reason = "lane_frontier_next"
                else:
                    continue
                for position_in_batch, (slug, title_id) in enumerate(zip(batch["slugs"], batch["title_ids"])):
                    add_job(
                        title_id=title_id,
                        slug=slug,
                        reason=reason,
                        priority=REASON_PRIORITY[reason],
                        lane_id=lane["lane_id"],
                        lane_family=lane["lane_family"],
                        batch_index=batch["batch_index"],
                        position_in_batch=position_in_batch,
                    )

        if lane["lane_id"] in newly_claimed_lane_ids and batches:
            for position_in_batch, (slug, title_id) in enumerate(zip(batches[0]["slugs"], batches[0]["title_ids"])):
                add_job(
                    title_id=title_id,
                    slug=slug,
                    reason="new_lane_claim",
                    priority=REASON_PRIORITY["new_lane_claim"],
                    lane_id=lane["lane_id"],
                    lane_family=lane["lane_family"],
                    batch_index=0,
                    position_in_batch=position_in_batch,
                )

        for batch in batches[:global_frontier_batches]:
            for position_in_batch, (slug, title_id) in enumerate(zip(batch["slugs"], batch["title_ids"])):
                add_job(
                    title_id=title_id,
                    slug=slug,
                    reason="lane_frontier_next",
                    priority=450,
                    lane_id=lane["lane_id"],
                    lane_family=lane["lane_family"],
                    batch_index=batch["batch_index"],
                    position_in_batch=position_in_batch,
                )

    title_id_to_slug = {
        spine_fields_for_movie(movie)["title_id"]: slug
        for slug, movie in catalog_by_slug.items()
    }
    for title_id in hot_title_ids:
        slug = title_id_to_slug.get(title_id)
        if slug:
            add_job(title_id=title_id, slug=slug, reason="hot_title")

    for title_id in stale_title_ids:
        slug = title_id_to_slug.get(title_id)
        if slug:
            add_job(title_id=title_id, slug=slug, reason="artifact_stale")

    for slug, movie in catalog_by_slug.items():
        title_id = spine_fields_for_movie(movie, source_payload.get(slug) if isinstance(source_payload.get(slug), dict) else None)["title_id"]
        add_job(title_id=title_id, slug=slug, reason="cold_backfill")

    return sorted(
        jobs.values(),
        key=lambda job: (
            -int(job["priority"]),
            str(job.get("lane_id") or ""),
            int(job.get("batch_index") or 0),
            int(job.get("position_in_batch") or 0),
            job["title_id"],
        ),
    )


def main() -> int:
    args = parse_args()
    seed_payload = load_json_object(args.seed)
    lane_version, lanes = normalize_seed_lanes(seed_payload, fallback_batch_size=args.batch_size)
    catalog_by_slug = load_catalog_lookup(args.catalog)
    source_payload = load_json_object(args.source, default={})
    activity_payload = load_json_object(args.activity, default={})

    jobs = build_jobs(
        lanes=lanes,
        catalog_by_slug=catalog_by_slug,
        source_payload=source_payload,
        activity_payload=activity_payload,
        next_batch_window=args.next_batch_window,
        global_frontier_batches=args.global_frontier_batches,
    )

    payload = {
        "generated_at": datetime.now(UTC).isoformat(),
        "lane_version": lane_version or DEFAULT_LANE_VERSION,
        "count": len(jobs),
        "jobs": jobs,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(jobs)} frontier enrichment jobs to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
