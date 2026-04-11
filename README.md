# That Movie Night Life

`That Movie Night Life` is a native SwiftUI iOS/tvOS app for drawing a winner from the 10,734-film Random Movie Roulette Letterboxd list, while filtering out watched titles and optional buzz kills.

The app ships with a bundled JSON catalog instead of generated Swift source. Letterboxd is the primary data source for list membership, poster URLs, aggregate rating, genres, and TMDb IDs. TMDb is optional enrichment for future metadata work and is not required at runtime.

## Project Layout

- `Sources/TMNLCore`: shared movie models, catalog loading, filtering, daily selection state, import logic, and bundled JSON resources.
- `Tests/TMNLCoreTests`: package tests for catalog loading, filtering, import matching, and daily-state rules.
- `Checks/TMNLCoreChecks`: smoke checks for the bundled dataset.
- `scripts/build_letterboxd_catalog.py`: refreshes the bundled catalog from Letterboxd HTML and optional TMDb enrichment.
- `scripts/build_movie_tags.py`: rebuilds the buzz-kill overlay from catalog metadata plus manual overrides.
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

Generate the Xcode project:

```bash
xcodegen generate
open ThatMovieNightLife.xcodeproj
```

If you later want TMDb enrichment, set `TMDB_READ_ACCESS_TOKEN` in the environment before running the catalog refresh script or in the generated target settings.
