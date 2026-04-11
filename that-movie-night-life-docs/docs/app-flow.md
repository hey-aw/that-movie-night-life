# App Flow

## Core arc

The app flow should feel like one continuous movie-night ritual:

**Pick → Gather → Watch → React → Pass it on**

The app is organized around this sequence rather than around endless browsing.

## Main navigation

- **Tonight**
- **Rooms**
- **Feature**
- **Encore**
- **Library**

## 1. Tonight

### Purpose
Start or join a movie night.

### Key questions
- What are we watching tonight?
- Am I starting from scratch or joining a room?
- What is a strong shortlist for this moment?

### Primary actions
- Start a Night
- Join a Night
- Spin the Marquee
- Use a saved mode

### Main sections
- hero card for starting or continuing a night
- recent rooms
- quick mode chips
- recommended candidates
- recent movie nights

## 2. Start a Night

This should be a focused, step-based flow.

### Step 1: Who’s watching?
Options:
- Just Me
- Me + Someone
- A Room
- New Group

### Step 2: How do we want to pick?
Options:
- Watchlist Draw
- Shared Overlap
- Streaming Now
- Under 2 Hours
- Followed List
- Wild Card

### Step 3: Optional filters
Examples:
- streaming service
- runtime
- genre
- decade
- unseen only

### Step 4: Shortlist
Return a small set of strong candidates.

Each candidate card should show:
- poster
- title and year
- runtime
- where to watch
- rating signal
- source badge
- spoiler-safe blurb

### Step 5: Lock the pick
Once the group or individual selects a movie, move into the chosen-film state.

## 3. Join a Night

Users can join by:
- deep link
- invite code
- recent room

If a movie has already been chosen, the user lands on the pick screen.
If the group is still deciding, the user lands in shortlist or voting mode.

## 4. Chosen film screen

### Purpose
This is the “tonight’s feature” moment.

### Content
- large poster or backdrop
- title, year, runtime
- where to watch
- who is in the room
- why it surfaced
- spoiler-safe review snippets

### Primary actions
- Start Watching
- Open in Streaming App
- Invite Friends
- Swap Pick

## 5. Feature

### Purpose
A lightweight companion while the movie is playing.

### Main sections
- Cast
- Places
- Context
- Notes

### Behavior
This should be the quietest screen in the app.
It should provide quick, satisfying answers without encouraging deep scrolling.

### Cast
- actor list
- familiar roles
- “you know them from” patterns

### Places
- filming locations
- map or location cards
- “also filmed here” style context

### Context
- spoiler-safe production and cultural context
- source material
- director overview
- year / country / movement context

### Notes
- standout performance
- favorite line
- quick reaction prompts
- reminder to recommend later

## 6. Encore

### Purpose
Capture the reaction while the movie is still fresh.

### Main actions
- Rate It
- Write a Quick Take
- Log to Letterboxd
- Read Reactions
- Recommend It
- What Next?

### Modules
- quick star rating
- one-line take
- optional draft review
- related films
- related lists
- recommendation composer

## 7. Rooms

### Purpose
Create continuity across movie nights.

### Room detail should include
- members
- recent watches
- current shortlist or pick
- room history
- recommendations for the room

Examples:
- Friday Night
- Horror Club
- Just Us
- Criterion Sundays

## 8. Library

### Purpose
Store the user’s connected film life and preferences.

### Sections
- connected Letterboxd
- watchlist
- followed lists
- streaming services
- spoiler settings
- archived nights
- selection defaults

## Flow principles

### Always bias toward choosing
The app should help people reach a pick.
It should not reward endless browsing.

### Keep the during-movie experience lightweight
Feature mode should support the movie, not compete with it.

### Make the post-movie reaction fast
Users lose momentum quickly after the credits.
Encore should capture that moment with low friction.

### Rooms create habit
Rooms are the bridge between one movie night and the next.
