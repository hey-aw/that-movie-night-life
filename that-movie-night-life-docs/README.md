# That Movie Night Life

**Movie Nights with Friends**

A movie-night companion app for iPhone that enhances the Letterboxd experience around the night itself: choosing what to watch, sharing the moment with friends, using spoiler-safe companion features during the movie, and carrying the energy into reviews, lists, and recommendations afterward.

## Project summary

That Movie Night Life is designed as a companion product, not a Letterboxd replacement.

- **Letterboxd** remains the home for logging, rating, reviewing, lists, and long-term film memory.
- **That Movie Night Life** focuses on the movie-night ritual:
  - **Before**: what should we watch tonight?
  - **During**: lightweight, spoiler-safe companion info
  - **After**: review, react, recommend, and queue up what comes next

The product identity is social, cinematic, and playful, with a **neon lights / Vegas strip / Elvis vibe** layered on top of a clean iOS-native experience.

## Product thesis

**Pick → Gather → Watch → React → Pass it on**

The core experience is built around a single movie night.

### Before
Help people choose a movie using:
- watchlists
- followed lists
- room overlap
- random or sequential selection modes
- where-to-watch filters
- runtime and mood constraints

### During
Support the movie without interrupting it:
- “Where have I seen this actor before?”
- filming locations
- spoiler-safe context
- quick notes and pause-safe prompts

### After
Capture the energy while it is still fresh:
- quick star rating
- one-line take
- draft review
- handoff to Letterboxd
- related films and lists
- recommend to a friend or room

## Brand

**That Movie Night Life**

**Movie Nights with Friends**

The visual system should feel like:
- backlit marquee signage
- midnight movie-palace atmosphere
- vintage Vegas lounge energy
- modern iOS polish

The app should use standard iOS patterns first and let the brand show up through color, typography moments, copy, cards, and motion.

## Core tabs

- **Tonight** — Start or join a movie night
- **Rooms** — Shared spaces for recurring groups or one-off nights
- **Feature** — Live companion while the movie is playing
- **Encore** — Post-movie reactions, recommendations, and handoff
- **Library** — Watchlist, followed lists, settings, and connected services

## MVP

The first version should prove one thing:

> This is the best way to have one movie night.

### MVP scope
- iPhone only
- Connect or import watchlist data
- Start a movie night
- Choose a selection mode
- Generate a shortlist
- Lock a pick
- Use a spoiler-safe companion during the movie
- Capture a reaction after the movie
- Recommend the film to a friend

### Explicitly out of scope for V1
- replacing Letterboxd review and diary features
- building a standalone film social network
- deep stats and gamification
- broad web community features
- overly complex recommendation infrastructure

## Recommended architecture

- **SwiftUI** app
- **TabView** for primary navigation
- **NavigationStack** within tabs
- **Sheets** for bounded decision flows
- lightweight local persistence for session state
- service layer for movie metadata, availability, room data, and Letterboxd integration

## Document map

- [`docs/product-overview.md`](docs/product-overview.md)
- [`docs/app-flow.md`](docs/app-flow.md)
- [`docs/ios-design-principles.md`](docs/ios-design-principles.md)
- [`docs/swiftui-component-plan.md`](docs/swiftui-component-plan.md)
- [`docs/roadmap.md`](docs/roadmap.md)

## Suggested repo structure

```text
App/
  RootTabView.swift
  AppTheme.swift

Features/
  Tonight/
  Rooms/
  Feature/
  Encore/
  Library/

Components/
  Cards/
  Buttons/
  Badges/
  Media/
  Inputs/

Models/
  Movie.swift
  Room.swift
  MovieNight.swift
  Reaction.swift

Services/
  MovieService.swift
  RoomService.swift
  LetterboxdService.swift
  Mock/

Resources/
  Colors/
  Assets/
```

## Design principles

- Native iOS structure first
- Branded atmosphere second
- One clear job per screen
- Sheets for focused tasks
- Cards for media-rich browsing
- Minimal distraction during the movie
- Fast post-credit reaction flow

## Product framing

**Free = a great movie night**

**Paid = a richer movie-night life**

A future subscription model can expand:
- unlimited rooms
- advanced selection modes
- room history
- richer recommendation logic
- saved rituals and themed nights

## Next build steps

1. Create the SwiftUI app shell and tab structure
2. Build the Tonight flow with mocked data
3. Build the Start a Night sheet and shortlist flow
4. Build Feature and Encore screens
5. Add real data integrations and sharing
6. Test around real movie-night usage
