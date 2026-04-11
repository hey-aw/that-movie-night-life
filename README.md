# That Movie Night Life

`That Movie Night Life` is a native SwiftUI iOS/tvOS app for drawing a winner from the 10,734-film Random Movie Roulette Letterboxd list, while filtering out watched titles and optional buzz kills.

The app ships with a bundled JSON catalog instead of generated Swift source. Letterboxd is the primary data source for list membership, poster URLs, aggregate rating, genres, and TMDb IDs. TMDb is optional enrichment for future metadata work and is not required at runtime.

## Project Layout

- `Sources/TMNLCore`: shared movie models, catalog loading, filtering, daily selection state, import logic, and bundled JSON resources.
- `Tests/TMNLCoreTests`: package tests for catalog loading, filtering, import matching, and daily-state rules.
- `Checks/TMNLCoreChecks`: smoke checks for the bundled dataset.
- `scripts/build_letterboxd_catalog.py`: refreshes the bundled catalog from Letterboxd HTML and optional TMDb enrichment.
- `scripts/build_movie_tags.py`: rebuilds the buzz-kill overlay from catalog metadata plus manual overrides.
- `scripts/scrape_letterboxd_reviews.py`: scrape raw per-title Letterboxd review text into a standalone JSON dataset.
- `scripts/generate_movie_appeal_summaries.py`: turn scraped review text into draft `Why People Like It` summary entries.
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

Refresh the `Why People Like It` seed list and bundled appeal sidecar:

```bash
uv run playwright install chromium
uv run python scripts/scrape_letterboxd_reviews.py
uv run python scripts/generate_movie_appeal_summaries.py
uv run python scripts/select_movie_appeal_seed_titles.py
uv run python scripts/build_movie_appeal.py
```

The review scraper now defaults to a Playwright-backed browser session with persistent state stored at
`Data/letterboxd-playwright-state.json`. Normal interactive runs will reuse that local session and pause on
Letterboxd challenge pages so you can solve the block in-browser before the scrape resumes. Use
`--fetch-mode http` to force the legacy raw HTTP path when needed.

Generate the Xcode project:

```bash
xcodegen generate
open ThatMovieNightLife.xcodeproj
```

If you later want TMDb enrichment, set `TMDB_READ_ACCESS_TOKEN` in the environment before running the catalog refresh script or in the generated target settings.
