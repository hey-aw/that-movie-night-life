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

## Files and commands

```bash
uv run python scripts/run_movie_appeal_batches.py
uv run python scripts/select_movie_appeal_seed_titles.py
uv run python scripts/select_movie_appeal_seed_titles.py \
  --source Data/movie-appeal-source.json \
  --exclude-existing-source
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
- Editorial rules: `references/editorial-rubric.md`
- Canonical examples: `references/examples.md`

## Workflow

1. Refresh the deterministic seed list with `uv run python scripts/select_movie_appeal_seed_titles.py`.
   The selector prefers titles with runtime data, then falls back to the current catalog shape when runtime coverage is missing.
   For the next unprocessed tranche, add `--source Data/movie-appeal-source.json --exclude-existing-source`.
   To merge completed update files, rebuild the sidecar, and prepare the next worker batches in one pass, use `uv run python scripts/run_movie_appeal_batches.py`.
   That runner also snapshots the freshly prepared tranche into `Data/movie-appeal-tranche-queue/tranche-XXX/`.
2. Load `Data/movie-appeal-seed-slugs.json` and split `ordered_slugs` into fixed batches of 10 using `uv run python scripts/export_movie_appeal_worker_batches.py`.
3. Use subagents for drafting only. Each subagent gets one 10-title batch and only the bundled metadata already in `movies.catalog.json`.
4. Do not let subagents make final editorial decisions. Reconcile tone, spoiler safety, and consistency in the main thread.
5. Write or update `Data/movie-appeal-source.json`.
   Store at least one real user quote in `source_quotes` for every entry, and make sure the summary itself includes a quoted fragment. If the user asks to lean on Letterboxd, prefer Letterboxd review excerpts when they are spoiler-safe. The build step strips provenance fields from the runtime sidecar.
6. Generate the runtime sidecar with `uv run python scripts/build_movie_appeal.py`.
7. Validate with `uv run python -m unittest discover -s tests_python` and `swift test --filter BundledMovieAppealTests`.

## Drafting rules

- Use subagents for drafting only, not final signoff.
- Use only bundled metadata and local project docs while drafting.
- Do not depend on live scraping at app runtime.
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
