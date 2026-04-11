# Agents

## Project

That Movie Night Life — a SwiftUI iOS/tvOS app for picking, watching, and reacting to movies together.

- Xcode project: `ThatMovieNightLife.xcodeproj`
- iOS scheme: `ThatMovieNightLifeIOS`
- Bundle ID: `com.aw.ThatMovieNightLifeIOS`
- Deployment target: iOS 17.0
- UI framework: SwiftUI with `@Observable` / `@Bindable`
- Design: dark cinematic theme, native iOS controls, serif display typography

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
uv run python scripts/run_movie_appeal_batches.py
uv run python scripts/select_movie_appeal_seed_titles.py
uv run python scripts/select_movie_appeal_seed_titles.py --source Data/movie-appeal-source.json --exclude-existing-source
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

- Always lint and build to check for errors before finishing.
- Use `AppTheme` for all colors, spacing, radii, and typography.
- Prefer native iOS button styles (`.borderedProminent`, `.bordered`) over custom `ButtonStyle` implementations.
- Dark mode only — `.preferredColorScheme(.dark)` is set at the root `TabView`.
- Use `#available` checks when adopting iOS 18+ or iOS 26+ APIs.
