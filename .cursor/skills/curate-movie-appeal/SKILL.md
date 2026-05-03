---
name: curate-movie-appeal
description: >-
  Curate TMNL's spoiler-safe "Why People Like It" entries and generate the
  bundled `movie-appeal.json` sidecar. Use when selecting the starter title
  set, drafting appeal summaries, reviewing tone or spoiler safety, updating
  `Data/movie-appeal-source.json`, or regenerating bundled appeal data.
  Triggers on: "Why People Like It", "movie appeal", "spoiler-safe movie
  explanation", "movie-appeal.json", "appeal summaries", "curate bundled
  content".
---

# Curate Movie Appeal

Use this skill for TMNL's offline `Why People Like It` workflow. Keep the runtime bundled and deterministic; do not add live scraping or runtime generation.

Treat the bundled catalog as the source-of-truth spine. Review processing is asynchronous enrichment layered on top and should be scoped to explicit frontier titles, never the entire catalog by default.

## Files and commands

```bash
uv run python scripts/run_movie_appeal_batches.py
uv run python scripts/select_movie_appeal_seed_titles.py
uv run python scripts/select_movie_appeal_seed_titles.py \
  --source Data/movie-appeal-source.json \
  --exclude-existing-source
uv run python scripts/build_frontier_enrichment_jobs.py \
  --seed Data/movie-appeal-seed-slugs.json \
  --source Data/movie-appeal-source.json
uv run python scripts/export_movie_appeal_worker_batches.py \
  --seed Data/movie-appeal-seed-slugs.json \
  --catalog Sources/TMNLCore/Resources/movies.catalog.json
uv run python scripts/merge_movie_appeal_worker_updates.py \
  --source Data/movie-appeal-source.json \
  --backup updates/*.json
uv run python scripts/build_movie_appeal.py
uv run python -m unittest discover -s tests_python
swift test --filter BundledMovieAppealTests
```

- Seed list: `Data/movie-appeal-seed-slugs.json`
- Reviewed source: `Data/movie-appeal-source.json`
- Bundled runtime sidecar: `Sources/TMNLCore/Resources/movie-appeal.json`
- Queued tranche snapshots: `Data/movie-appeal-tranche-queue/`

Read these references before drafting or reviewing:
- Schema and limits: `references/schema.md`
- Agent editorial workflow: `references/editorial-agent-brief.md`
- Update-file JSON Schema: `references/movie-appeal-update.schema.json`
- Editorial rules: `references/editorial-rubric.md`
- Canonical examples: `references/examples.md`

## Workflow

1. Refresh the deterministic seed list with `uv run python scripts/select_movie_appeal_seed_titles.py`.
   The selector prefers titles with runtime data, then falls back to the current catalog shape when runtime coverage is missing.
   For the next unprocessed tranche, add `--source Data/movie-appeal-source.json --exclude-existing-source`.
   To merge completed update files, rebuild the sidecar, and prepare the next worker batches in one pass, use `uv run python scripts/run_movie_appeal_batches.py`.
   That runner also snapshots the freshly prepared tranche into `Data/movie-appeal-tranche-queue/tranche-XXX/` and emits the frontier enrichment job snapshot.
2. Load `Data/movie-appeal-seed-slugs.json` and split the lane frontier into fixed worker batches using `uv run python scripts/export_movie_appeal_worker_batches.py`.
3. Build the prioritized enrichment queue with `uv run python scripts/build_frontier_enrichment_jobs.py`.
   Use this queue to decide which titles deserve expensive review ingest first.
   If manual review ingest is needed, scope it to explicit batch files or title IDs rather than the entire catalog.
3. Use subagents as the editorial desk for drafting. Each subagent gets one owned slice file, 8-15 slugs, catalog context, and the relevant review-signal store. They read reviews, select short spoiler-safe quotes, self-validate the slice, and return schema-valid update objects plus counts written/skipped.
4. Do not let subagents make final merge decisions. The main thread acts as head editor: reconcile tone, cut risky entries, combine slices into an approved desk file, validate with a dry-run merge and strict temp-source build, then merge approved updates and rebuild the runtime sidecar when requested.
5. Write or update `Data/movie-appeal-source.json`.
   Store at least one real user quote in `source_quotes` for every entry, and make sure the summary itself includes a quoted fragment. If the user asks to lean on Letterboxd, prefer Letterboxd review excerpts when they are spoiler-safe. The build step strips provenance fields from the runtime sidecar.
6. Generate the runtime sidecar with `uv run python scripts/build_movie_appeal.py`.
7. Validate with `uv run python -m unittest discover -s tests_python` and `swift test --filter BundledMovieAppealTests`.

## Drafting rules

- Use subagents for drafting and quote selection, not final signoff.
- Use bundled metadata, local project docs, and local review-signal files while drafting.
- Prefer 2-4 parallel writers with 8-15 titles each. Use 5-title slices only for trial batches or especially difficult lanes.
- Tell each writer to write exactly one file under `Data/movie-appeal-editorial-desk/`, run JSON/dry-run validation, and report written/skipped counts.
- Do not depend on live scraping at app runtime.
- Do not default to catalog-wide review scraping. Frontier-scoped enrichment only.
- Prefer mood, craft, audience fit, and room energy over synopsis.
- Keep output spoiler-safe by default.
- Keep real user quotes short, store provenance in `source_quotes`, and quote at least one fragment in the summary itself.
- If the brief asks for review-backed copy, prefer Letterboxd quotes first when available and spoiler-safe.
- Prefer `uv run` over invoking `python3` directly.
- If you change validators, loaders, or tests, follow red/green TDD.

## Review checklist

- Summary is specific and concise, not generic praise.
- Tags are short, readable aloud, and not repetitive.
- `good_pick_if` and `maybe_skip_if` help a group decide tonight.
- No endings, reveals, surprise pivots, or identity disclosures.
- The entry sounds like TMNL, not like a review aggregator.
