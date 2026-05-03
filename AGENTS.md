# Agents

## Project

That Movie Night Life — a SwiftUI iOS/tvOS app for picking, watching, and reacting to movies together.

- Xcode project: `ThatMovieNightLife.xcodeproj`
- iOS scheme: `ThatMovieNightLifeIOS`
- Bundle ID: `com.aw.ThatMovieNightLifeIOS`
- Deployment target: iOS 17.0
- UI framework: SwiftUI with `@Observable` / `@Bindable`
- Design: dark cinematic theme, native iOS controls, serif display typography

## Data Architecture

- Treat the bundled catalog as the product's catalog spine and source of truth.
- Every title must remain renderable from spine data alone, even when no enrichment exists.
- Review-derived copy is asynchronous enrichment layered onto the spine; it must never block runtime rendering.
- Predetermined lanes are routing infrastructure as well as UX. They determine which titles should receive expensive enrichment first.
- Do not run catalog-wide review scraping as the default workflow. Any review ingest must be frontier-scoped to explicit lane, batch, or `title_id` inputs.
- Long-term Letterboxd enrichment goal: process the entire bundled movie list through bounded, checkpointed batches so every catalog title can eventually have cached review signals when available.
- Prefer `letterboxdpy` for Letterboxd review-store building before raw HTML scraping. Use `scripts/build_letterboxdpy_review_store.py` for scoped batches and preserve output as optional enrichment.
- `movie-appeal.json` is a published enrichment projection, not the primary authoring source. Editorial source of truth stays in `Data/movie-appeal-source.json`.

## Skills

### ios-dev

Location: `.cursor/skills/ios-dev/`

Build, run, screenshot, and deploy the iOS app. Wraps `xcodebuild`, `xcrun simctl`, and `xcrun devicectl` into a single helper script.

```bash
bash .cursor/skills/ios-dev/scripts/ios.sh <command>
```

Key commands: `run sim`, `run device`, `screenshot`, `devices`, `build sim`, `build device`.

Use this skill whenever building, running on simulator, taking screenshots for design review, or pushing to a physical iPhone.

### curate-movie-appeal

Location: `.cursor/skills/curate-movie-appeal/`

Curate spoiler-safe `Why People Like It` entries and generate the bundled `movie-appeal.json` resource from reviewed source data.

```bash
uv run python scripts/select_movie_appeal_seed_titles.py
uv run python scripts/export_movie_appeal_worker_batches.py
uv run python scripts/build_frontier_enrichment_jobs.py
uv run python scripts/build_movie_appeal.py
```

Use this skill whenever working on TMNL's `Why People Like It` content, curating appeal summaries, reviewing bundled movie-appeal data, or regenerating the bundled appeal sidecar.

Queued tranche snapshots are written under `Data/movie-appeal-tranche-queue/`.

Skill workflow includes:

```bash
uv run python scripts/run_movie_appeal_batches.py
uv run python scripts/select_movie_appeal_seed_titles.py
uv run python scripts/select_movie_appeal_seed_titles.py --source Data/movie-appeal-source.json --exclude-existing-source
uv run python scripts/export_movie_appeal_worker_batches.py
uv run python scripts/build_frontier_enrichment_jobs.py
uv run python scripts/merge_movie_appeal_worker_updates.py --source Data/movie-appeal-source.json --backup updates/*.json
uv run python scripts/build_movie_appeal.py
```

## Architecture

```
App/
  ThatMovieNightLifeIOS/    # iOS app entry point
  ThatMovieNightLifeTV/     # tvOS app entry point
  TMNLShared/               # Shared SwiftUI views and theme
Sources/
  TMNLCore/                 # Domain models, protocols, catalog loader
that-movie-night-life-docs/ # Product docs, design principles, roadmap
```

## Conventions

- Always lint and run the relevant checks before finishing. Run Swift builds/tests for Swift or app-resource changes; for Python/data-tooling-only changes, run the relevant `uv run python -m unittest` and lint checks instead.
- Use `AppTheme` for all colors, spacing, radii, and typography.
- Prefer native iOS button styles (`.borderedProminent`, `.bordered`) over custom `ButtonStyle` implementations.
- Dark mode only — `.preferredColorScheme(.dark)` is set at the root `TabView`.
- Use `#available` checks when adopting iOS 18+ or iOS 26+ APIs.
- Prefer `title_id` and lane metadata in new contracts instead of relying on positional batch state alone.
- When touching movie-appeal or review-processing scripts, keep the flow spine-first and frontier-scoped.
