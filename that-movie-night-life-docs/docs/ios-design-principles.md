# iOS Design Principles

## Design goal

That Movie Night Life should feel like a native iPhone app first and a branded movie-night world second.

The neon / Vegas / Elvis identity should shape:
- atmosphere
- color
- copy
- card treatments
- selected moments of typography

It should not replace standard iOS structure.

## Core principles

### 1. Native before branded
Use platform-standard navigation, spacing, motion, controls, and content hierarchy.

### 2. One clear task per screen
Every screen should answer a single question:
- Tonight: what are we watching?
- Rooms: who is here and what is the shared context?
- Feature: what do I want to know right now?
- Encore: what do I want to say or do next?
- Library: what is connected and configured?

### 3. Sheets for focused tasks
Use sheets for:
- Start a Night
- filters
- quick take writing
- recommendation composition
- room invite or sharing workflows

### 4. Cards for rich film content
Movie posters, room summaries, and reaction summaries should live in cards.
Cards should be legible, visual, and lightly branded.

### 5. Quiet during-movie experience
The Feature tab should reduce visual noise and interaction complexity.
The app should feel like a subtle companion, not a second screen distraction.

### 6. Fast post-credit capture
Encore should prioritize quick actions and low-friction writing.
People are most likely to engage with reaction tools immediately after finishing the movie.

## Recommended navigation

### Top-level structure
- TabView for primary navigation
- NavigationStack within each tab
- large titles on root screens
- inline titles on detail screens

### Recommended tabs
- Tonight
- Rooms
- Feature
- Encore
- Library

## Layout guidance

### Tonight
Use a vertically scrolling home screen with:
- hero card
- horizontal rails for rooms or candidates
- quick mode chips
- recent history modules

### Rooms
Use either:
- card stack in a scroll view
- or inset grouped list style for cleaner room management

### Feature
Use a quiet, content-first layout with:
- compact header
- segmented control for cast / places / context / notes
- light cards and sparse visual chrome

### Encore
Use stacked action cards with clear primary and secondary actions.
The order should match the post-movie mental model:
1. rate
2. say something
3. log / review
4. read reactions
5. recommend
6. choose what next

### Library
Use grouped list styling and conventional settings layouts.
This area should feel stable and utility-oriented.

## Interaction patterns

### Primary CTA placement
Use a bottom safe-area inset action bar for the most important action on detail or selection screens.
Examples:
- Pick This Movie
- Start Watching
- Log to Letterboxd

### Secondary actions
Use compact buttons, menu buttons, or trailing actions inside cards.
Avoid overloading the main button row.

### Progressive disclosure
Do not show every option at once.
Use:
- sheets
- segmented controls
- expandable sections
- nested detail pages

to keep screens calm and readable.

## Visual design system

### Backgrounds
Use dark, cinematic backgrounds with selective accent glow.

### Surfaces
Use layered surfaces for:
- cards
- bottom action areas
- toolbars
- lightweight overlays

### Color behavior
Accent color should be concentrated in:
- selected states
- key buttons
- hero moments
- room or pick highlights

Do not turn the entire app into a neon glow treatment.

### Typography
Use SF for primary interface text.
Reserve display styling for:
- feature headers
- hero banners
- promotional or empty states

### Motion
Use subtle motion:
- card expansion
- sheet presentation
- small glow or fade transitions
- no theatrical over-animation

## Accessibility and usability

### Dynamic Type
All text-heavy views should support Dynamic Type.

### Contrast
Ensure that neon color accents still meet contrast requirements on dark surfaces.

### VoiceOver
Buttons and poster cards should have descriptive labels.

### Touch targets
Interactive chips, cast rows, and poster actions should use comfortable iOS touch target sizing.

## Brand translation

The brand should feel like:
- a movie palace at midnight
- an old marquee updated for iPhone
- a friend who makes movie night feel like an event

The app should not feel like:
- a novelty retro theme
- a skeuomorphic jukebox
- a custom UI fighting iOS behavior

## Design rule of thumb

Use Apple’s structure.
Brand the atmosphere.
