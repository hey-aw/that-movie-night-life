-- Catalog spine and frontier-scoped enrichment schema for That Movie Night Life.
-- This is the canonical contract for the future database-backed implementation.
-- Current repo JSON files are short-term mirrors of these structures.

CREATE TABLE titles (
    title_id TEXT PRIMARY KEY,
    title_type TEXT NOT NULL DEFAULT 'movie',
    slug TEXT NOT NULL UNIQUE,
    display_title TEXT NOT NULL,
    release_year INTEGER,
    runtime_minutes INTEGER,
    synopsis TEXT,
    poster_url TEXT,
    backdrop_url TEXT,
    watch_url TEXT,
    letterboxd_url TEXT,
    certification TEXT,
    director TEXT,
    cast_json TEXT NOT NULL DEFAULT '[]',
    genres_json TEXT NOT NULL DEFAULT '[]',
    availability_flags_json TEXT NOT NULL DEFAULT '[]',
    catalog_status TEXT NOT NULL DEFAULT 'ready',
    enrichment_status TEXT NOT NULL DEFAULT 'pending',
    review_signal_count INTEGER NOT NULL DEFAULT 0,
    last_enriched_at TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    CHECK (catalog_status IN ('ready')),
    CHECK (enrichment_status IN ('pending', 'ready', 'stale', 'failed'))
);

CREATE TABLE title_external_ids (
    title_id TEXT NOT NULL REFERENCES titles(title_id) ON DELETE CASCADE,
    provider TEXT NOT NULL,
    external_id TEXT NOT NULL,
    is_primary INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (title_id, provider),
    UNIQUE (provider, external_id)
);

CREATE TABLE roulette_lanes (
    lane_id TEXT PRIMARY KEY,
    lane_family TEXT NOT NULL,
    version TEXT NOT NULL,
    batch_size INTEGER NOT NULL,
    total_titles INTEGER NOT NULL,
    created_at TEXT NOT NULL,
    UNIQUE (lane_family, version)
);

CREATE TABLE roulette_lane_entries (
    lane_id TEXT NOT NULL REFERENCES roulette_lanes(lane_id) ON DELETE CASCADE,
    position INTEGER NOT NULL,
    title_id TEXT NOT NULL REFERENCES titles(title_id) ON DELETE CASCADE,
    batch_index INTEGER NOT NULL,
    position_in_batch INTEGER NOT NULL,
    PRIMARY KEY (lane_id, position),
    UNIQUE (lane_id, title_id)
);

CREATE TABLE user_roulette_state (
    user_id TEXT PRIMARY KEY,
    lane_id TEXT NOT NULL REFERENCES roulette_lanes(lane_id),
    batch_index INTEGER NOT NULL DEFAULT 0,
    cursor_in_batch INTEGER NOT NULL DEFAULT 0,
    seen_count INTEGER NOT NULL DEFAULT 0,
    exclusions_json TEXT NOT NULL DEFAULT '[]',
    seen_title_ids_json TEXT NOT NULL DEFAULT '[]',
    last_active_at TEXT NOT NULL
);

CREATE TABLE review_signals_raw (
    review_signal_id TEXT PRIMARY KEY,
    title_id TEXT NOT NULL REFERENCES titles(title_id) ON DELETE CASCADE,
    source TEXT NOT NULL,
    source_review_id TEXT NOT NULL,
    source_url TEXT NOT NULL,
    author_name TEXT,
    authored_at TEXT,
    rating_value REAL,
    excerpt TEXT,
    spoiler_flag INTEGER NOT NULL DEFAULT 0,
    fetched_at TEXT NOT NULL,
    raw_payload_json TEXT NOT NULL,
    UNIQUE (source, source_review_id)
);

CREATE TABLE review_signals_aggregate (
    title_id TEXT PRIMARY KEY REFERENCES titles(title_id) ON DELETE CASCADE,
    source_count INTEGER NOT NULL DEFAULT 0,
    spoiler_safe_count INTEGER NOT NULL DEFAULT 0,
    freshness_score REAL,
    sentiment_summary_json TEXT NOT NULL DEFAULT '{}',
    theme_summary_json TEXT NOT NULL DEFAULT '{}',
    updated_at TEXT NOT NULL
);

CREATE TABLE title_enrichment_snapshots (
    snapshot_id TEXT PRIMARY KEY,
    title_id TEXT NOT NULL REFERENCES titles(title_id) ON DELETE CASCADE,
    artifact_version TEXT NOT NULL,
    why_people_like_this TEXT NOT NULL,
    highlight_excerpts_json TEXT NOT NULL DEFAULT '[]',
    theme_tags_json TEXT NOT NULL DEFAULT '[]',
    spoiler_safe_summary TEXT NOT NULL,
    confidence TEXT,
    source_count INTEGER NOT NULL DEFAULT 0,
    generated_at TEXT NOT NULL,
    published_at TEXT NOT NULL,
    is_current INTEGER NOT NULL DEFAULT 1,
    CHECK (confidence IN ('high', 'medium', 'low') OR confidence IS NULL)
);

CREATE UNIQUE INDEX title_enrichment_snapshots_current_idx
    ON title_enrichment_snapshots(title_id)
    WHERE is_current = 1;

CREATE TABLE enrichment_jobs (
    job_id TEXT PRIMARY KEY,
    title_id TEXT NOT NULL REFERENCES titles(title_id) ON DELETE CASCADE,
    priority INTEGER NOT NULL,
    reason TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'queued',
    attempt_count INTEGER NOT NULL DEFAULT 0,
    lane_id TEXT REFERENCES roulette_lanes(lane_id),
    batch_index INTEGER,
    scheduled_for TEXT,
    started_at TEXT,
    completed_at TEXT,
    last_error TEXT,
    created_at TEXT NOT NULL,
    CHECK (reason IN (
        'lane_frontier_current',
        'lane_frontier_next',
        'new_lane_claim',
        'hot_title',
        'artifact_stale',
        'cold_backfill'
    )),
    CHECK (status IN ('queued', 'running', 'succeeded', 'failed', 'canceled'))
);
