# Editorial Agent Brief

Use this brief when subagents are acting as the editorial desk for `Why People Like It`.

## Roles

- Subagents are writers. They read the catalog spine and review signals, choose useful source quotes, and draft appeal entries.
- The main agent is head editor. The main agent assigns slugs, reconciles tone, rejects risky entries, merges approved work, and rebuilds the runtime sidecar.
- Subagents do not merge into `Data/movie-appeal-source.json`.

## Inputs

Give each writer a bounded list of 8-15 slugs and these files:

- `Sources/TMNLCore/Resources/movies.catalog.json`
- `Data/letterboxdpy-reviews-full.json`
- `Data/movie-appeal-source.json`
- `.cursor/skills/curate-movie-appeal/references/movie-appeal-update.schema.json`
- `.cursor/skills/curate-movie-appeal/references/editorial-rubric.md`

Writers should skip slugs already present in `Data/movie-appeal-source.json` unless the assignment explicitly asks for a refresh.

## Fast Desk Orchestration

Run the desk as a parallel editorial queue, not as a deterministic batch script:

1. The head editor selects the next frontier slugs with `select_movie_appeal_seed_titles.py --source Data/movie-appeal-source.json --exclude-existing-source`.
2. The head editor creates 2-4 writer slices of 8-15 slugs each, balanced across lanes when possible.
3. Each writer owns exactly one output file under `Data/movie-appeal-editorial-desk/`.
4. Writers must validate their own slice before returning.
5. The head editor combines validated slices into one approved file, runs a strict temp-source build, then decides whether to merge.

Use this handoff shape in the writer prompt:

```text
Write only: Data/movie-appeal-editorial-desk/<batch-id>-slice-<n>.json
Target slugs: <slug list>
Return: changed file path, validation commands run, count written, count skipped, JSON array.
Do not modify Data/movie-appeal-source.json or movie-appeal.json.
```

Prefer fewer, larger slices over many tiny slices. A good default is 3 writers x 10 titles. Use 5-title slices only for test runs or high-risk lanes.

## Writer Task

For each assigned slug:

1. Read the catalog entry first. Use title, year, genres, runtime, overview, and rating context to understand what kind of movie it is.
2. Read the available Letterboxd review records for that slug.
3. Choose 1-3 short, spoiler-safe, useful review excerpts.
4. Draft one update object that conforms to `movie-appeal-update.schema.json`.
5. Omit the slug if no usable quote exists.

Return the final JSON array to the main agent and, when asked, write it to the slice path assigned by the main agent.

Before returning, each writer should run:

```bash
uv run python -m json.tool <slice.json>
uv run python scripts/merge_movie_appeal_worker_updates.py --allow-new-slugs --dry-run <slice.json>
```

If the writer has time, also build a temporary merged source to catch the stricter projection rules:

```bash
uv run python scripts/build_movie_appeal.py --source <temp-source.json> --output <temp-output.json>
```

## Quote Selection

Prefer quotes that signal:

- mood or room energy
- performance texture
- pacing, intensity, or rewatchability
- craft that affects the viewing experience
- audience fit or likely divisiveness

Avoid quotes that are:

- plot summary without appeal signal
- spoilers, endings, reveals, surprise pivots, or identity disclosures
- meme-only, diary-style, or context-dependent jokes
- profane, crude, sexually explicit, or review-bomb language
- too long to excerpt cleanly
- generic praise that could apply to any movie

The quote stored in `source_quotes[].text` should usually be the short exact excerpt used by the summary, not the full raw review. Keep it under the schema limit.

## Copy Rules

- The summary must help a group decide whether the movie fits tonight.
- The summary must include an exact quoted fragment from one `source_quotes[].text` item.
- Summaries should sound like TMNL: casual, specific, spoiler-safe, and useful.
- Do not explain the plot as the main move.
- Do not mention internal workflow, scraping, Letterboxdpy, schema, or validation in the app-facing copy.
- Use `confidence: "low"` for mechanically drafted or thinly sourced entries, `"medium"` for solid review-backed entries, and `"high"` only when the quote and catalog context are both strong.

## Output

Return a JSON array of update objects. Do not wrap it in an envelope unless explicitly requested.

For faster review, also include a short handoff line outside the JSON:

```text
Wrote <n> entries, skipped <n> slugs: <reasons>. Checks: <commands>.
```

The main agent validates the combined desk output with:

```bash
uv run python scripts/merge_movie_appeal_worker_updates.py --allow-new-slugs --dry-run <slice-1.json> <slice-2.json> ...
uv run python scripts/build_movie_appeal.py --source <temp-source.json> --output <temp-output.json>
```

Only the main agent may merge into `Data/movie-appeal-source.json` and rebuild `Sources/TMNLCore/Resources/movie-appeal.json`.
