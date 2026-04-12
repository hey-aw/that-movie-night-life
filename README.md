# That Movie Night Life

`That Movie Night Life` is a native SwiftUI iOS/tvOS app for drawing a winner from the 10,734-film Random Movie Roulette Letterboxd list, while filtering out watched titles and optional buzz kills.

The app ships with a bundled JSON catalog instead of generated Swift source. Letterboxd is the primary data source for list membership, poster URLs, aggregate rating, genres, and TMDb IDs. TMDb is optional enrichment for future metadata work and is not required at runtime.

The bundled catalog is the app's catalog spine. Review-derived copy is asynchronous enrichment layered on top of that spine, and titles must remain renderable even when no enrichment exists yet.

## Project Layout

- `Sources/TMNLCore`: shared movie models, catalog loading, filtering, daily selection state, import logic, and bundled JSON resources.
- `Tests/TMNLCoreTests`: package tests for catalog loading, filtering, import matching, and daily-state rules.
- `Checks/TMNLCoreChecks`: smoke checks for the bundled dataset.
- `scripts/build_letterboxd_catalog.py`: refreshes the bundled catalog from Letterboxd HTML and optional TMDb enrichment.
- `scripts/build_movie_tags.py`: rebuilds the buzz-kill overlay from catalog metadata plus manual overrides.
- `scripts/build_frontier_enrichment_jobs.py`: build a prioritized, frontier-scoped enrichment queue from lane data and current editorial coverage.
- `scripts/scrape_letterboxd_reviews.py`: optional assisted ingest for explicit frontier titles or worker batches.
- `scripts/generate_movie_appeal_summaries.py`: legacy draft generator for scraped review text; no longer part of the default workflow.
- `scripts/select_movie_appeal_seed_titles.py`: deterministically selects the 50-title starter set for `Why People Like It` curation.
- `scripts/build_movie_appeal.py`: validates curated appeal entries and emits the bundled `movie-appeal.json` sidecar.
- `App/TMNLShared`: shared SwiftUI picker views and app state.
- `App/ThatMovieNightLifeIOS`: iOS app entrypoint.
- `App/ThatMovieNightLifeTV`: tvOS app entrypoint.
- `project.yml`: `xcodegen` spec for the iOS and tvOS app targets.

## Local Verification

Run the package tests:

```bash
HOME=/tmp SWIFTPM_MODULECACHE_OVERRIDE=/tmp/org.swift.swiftpm swift test
```

Refresh the bundled Letterboxd catalog and tag overlay:

```bash
uv run python scripts/build_letterboxd_catalog.py
uv run python scripts/build_movie_tags.py
```

Prepare the next frontier tranche and publish the bundled appeal projection:

```bash
uv run python scripts/select_movie_appeal_seed_titles.py
uv run python scripts/export_movie_appeal_worker_batches.py
uv run python scripts/build_frontier_enrichment_jobs.py
uv run python scripts/build_movie_appeal.py
```

If you need fresh review signals for a specific frontier batch, scope the scraper to that batch instead of the whole catalog:

```bash
uv run playwright install chromium
uv run python scripts/scrape_letterboxd_reviews.py --batch-input Data/movie-appeal-worker-batches/batch-01.json
```

The review scraper uses a Playwright-backed browser session with persistent state stored at
`Data/letterboxd-playwright-state.json`, but it should be treated as a frontier-scoped enrichment worker rather than the default catalog refresh path.

Generate the Xcode project:

```bash
xcodegen generate
open ThatMovieNightLife.xcodeproj
```

If you later want TMDb enrichment, set `TMDB_READ_ACCESS_TOKEN` in the environment before running the catalog refresh script or in the generated target settings.
