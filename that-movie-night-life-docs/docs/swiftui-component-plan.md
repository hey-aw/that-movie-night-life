# SwiftUI Component Plan

## Architectural approach

Build the app with:
- `TabView` for primary navigation
- `NavigationStack` within each tab
- `sheet` for bounded decision flows
- reusable view components for cards, buttons, rails, and metadata
- observable view models per major flow
- service protocols to keep the UI independent from integration details

## Top-level tabs

### Tonight
Home for starting or joining a movie night.

### Rooms
Shared spaces for recurring groups and room history.

### Feature
Live movie companion for cast, places, context, and notes.

### Encore
Post-movie reaction, logging, recommendation, and next steps.

### Library
Connected services, watchlist, followed lists, settings, and archives.

## Suggested view hierarchy

### App shell
- `RootTabView`
- `AppTheme`
- `AppRouter` or lightweight route state if needed later

### Tonight flow
- `TonightFlowView`
- `TonightHomeView`
- `TonightHeroCard`
- `RoomRailSection`
- `QuickModeSection`
- `CandidateRailSection`
- `MovieDetailView`
- `StartNightSheet`

### Rooms flow
- `RoomsFlowView`
- `RoomsHomeView`
- `RoomCard`
- `RoomDetailView`
- `RoomHistorySection`
- `RoomRecommendationSection`

### Feature flow
- `FeatureFlowView`
- `FeatureHomeView`
- `ActiveFeatureView`
- `ActiveMovieHeader`
- `CastSectionView`
- `FilmingLocationsSectionView`
- `ContextSectionView`
- `NotesSectionView`

### Encore flow
- `EncoreFlowView`
- `EncoreHomeView`
- `EncoreHeroCard`
- `QuickRatingSection`
- `QuickTakeCard`
- `LetterboxdHandoffCard`
- `ReadReactionsSection`
- `RecommendSection`
- `WhatNextSection`

### Library flow
- `LibraryFlowView`
- `LibraryHomeView`
- `LetterboxdConnectionView`
- `WatchlistView`
- `FollowedListsView`
- `StreamingServicesView`
- `SpoilerSettingsView`
- `ArchivedNightsView`

## Shared UI components

### Cards
- `GlowCard`
- `PosterCard`
- `RoomCard`
- `ReactionSnippetCard`
- `MarqueeHeroCard`

### Buttons and actions
- `PrimaryCTAButton`
- `SecondaryCTAButton`
- `QuickModeChip`
- `RecommendationPill`
- `RoomInviteButton`

### Media components
- `PosterThumbnail`
- `BackdropHeader`
- `StreamingBadge`
- `CastAvatar`
- `RoomAvatarStack`

### Status components
- `NightStatusBadge`
- `SpoilerSafeBadge`
- `SeenByRoomIndicator`
- `SourceBadge`

### Input components
- `StarRatingControl`
- `QuickPromptComposer`
- `FilterChip`
- `TagSelectorRow`
- `RuntimeFilterControl`

## Domain models

### Movie
Core title metadata, poster, runtime, rating signal, availability, cast, and locations.

### Room
Member group, recent watches, and active room state.

### MovieNight
A session that moves from planning to chosen to watching to finished.

### NightFilters
Selection constraints such as runtime, streaming service, and unseen-only rules.

### QuickReaction
Star rating, one-line take, recommend flag, and handoff state.

## View models

### `TonightViewModel`
Owns home state:
- rooms
- recommendations
- recent nights
- active movie night
- presentation state for Start a Night sheet

### `StartNightViewModel`
Owns step flow state:
- audience selection
- selection mode
- filters
- shortlist
- loading state

### `RoomsViewModel`
Owns room list and room summaries.

### `FeatureViewModel`
Owns active movie, selected companion section, and notes.

### `EncoreViewModel`
Owns post-movie reaction state, snippets, and next suggestions.

### `LibraryViewModel`
Owns connected services, watchlist summaries, and app settings.

## Service protocols

Use protocols for integration points.

### `MovieService`
Responsibilities:
- fetch recommendations
- fetch movie detail
- generate shortlist
- fetch related films and context

### `RoomService`
Responsibilities:
- fetch rooms
- create room
- update room state
- fetch room history

### `LetterboxdService`
Responsibilities:
- connect account
- import watchlist and lists
- open handoff flow for logging or reviewing

### `AvailabilityService`
Responsibilities:
- fetch streaming availability
- filter titles by service

## Recommended MVP build order

### Step 1
App shell with tabs, theme tokens, and mocked data.

### Step 2
Tonight flow:
- home
- Start a Night sheet
- shortlist
- movie detail

### Step 3
Feature flow:
- active movie header
- cast
- locations
- notes

### Step 4
Encore flow:
- quick rating
- one-line take
- recommend flow

### Step 5
Library and connection placeholders.

### Step 6
Swap mock services for real integrations.

## File organization

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
  AvailabilityService.swift
  Mock/
```

## Prototyping note

The first prototype should use mocked movies, rooms, reactions, availability, and cast data so the team can refine the flow and feel before integration work begins.
