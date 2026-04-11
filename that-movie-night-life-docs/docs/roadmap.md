# Roadmap

## Goal

Ship a focused iPhone MVP that proves a single claim:

> That Movie Night Life makes one movie night better.

## Phase 0 — Product framing

### Outcomes
- brand direction aligned
- app flow defined
- information architecture agreed
- MVP scope locked

### Deliverables
- README
- product overview
- app flow
- iOS design principles
- SwiftUI component plan

## Phase 1 — App shell and mocked prototype

### Goals
Create a believable product prototype with no real integrations yet.

### Build
- tab bar shell
- navigation stacks
- theme tokens
- mocked movie data
- mocked room data
- Tonight tab
- Start a Night sheet
- shortlist flow
- movie detail

### Success criteria
- a user can start a movie night from mock data
- a shortlist can be generated
- a film can be selected and displayed cleanly

## Phase 2 — During and after flows

### Goals
Complete the emotional arc of movie night.

### Build
- Feature tab
- cast lookup view
- filming location view
- spoiler-safe context view
- notes view
- Encore tab
- quick rating
- one-line take
- recommendation composer

### Success criteria
- a user can move from pick to companion mode to post-movie reaction
- the app feels coherent as a single ritual

## Phase 3 — Basic integrations

### Goals
Bring in real data where it matters most.

### Build
- Letterboxd connection or import path
- watchlist import
- followed-list import or placeholders
- movie metadata integration
- streaming availability integration
- deep linking and sharing

### Success criteria
- a user can start from real watchlist or list data
- a recommendation or invite can be shared with a friend

## Phase 4 — Rooms and continuity

### Goals
Turn one movie night into an ongoing pattern.

### Build
- room creation
- room membership and invite flow
- room history
- recommendations to a room
- recurring room behavior

### Success criteria
- a user can return to the same room for multiple movie nights
- room history makes the app more useful over time

## Phase 5 — Monetization and expansion

### Goals
Introduce a paid tier without weakening the free movie-night experience.

### Possible paid features
- unlimited rooms
- advanced selection modes
- room history depth
- richer recommendation logic
- saved rituals and themes
- enhanced filtering and defaults

### Success criteria
- free remains great for one movie night
- paid makes recurring and organized movie-night life better

## Suggested timeline

### Weeks 1–2
- finalize product framing
- build shell
- build Tonight flow with mock data

### Weeks 3–4
- build Feature and Encore
- refine theme and UI system
- begin clickable prototype or internal build testing

### Weeks 5–6
- add first integration layer
- add sharing and room basics
- test with real movie-night use cases

## Risks

### 1. Overbuilding before testing
The product should not expand into a full film-social platform before the movie-night flow is validated.

### 2. Integration complexity
Letterboxd and metadata availability may require fallback paths and staged integration.

### 3. During-movie distraction
Feature mode must remain lightweight.

### 4. Scope creep in recommendations
The first recommendation system only needs to produce a few strong candidates, not a comprehensive taste graph.

## Decision rule

When a feature is proposed, ask:

**Does this make one movie night meaningfully better?**

If not, it should probably wait.
