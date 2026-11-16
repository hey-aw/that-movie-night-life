# Siri AI integration

That Movie Night Life exposes its core actions and its film catalog to Siri through App Intents, following Apple's [Siri AI Developer Preview](https://developer.apple.com/documentation/appintents/siri-ai-developer-preview).

## Requirements

- Xcode 27.3 beta (the iOS 27.3 SDK). `ToolIntent`, `@AppIntent(.tool)`, `CardSnippet`, the `description:`/`visibility:` property arguments, and skills bundles are new in that SDK.
- The deployment target stays at iOS 17. On iOS 17–27.2 the intents still work in Shortcuts, Spotlight and App Shortcuts; Siri tool calling, card snippets and app skills light up on iOS 27.3+.
- Siri AI features only work in development-signed builds on a device that supports Apple Intelligence, or for internal TestFlight testers. They are not available to external TestFlight testers or App Store builds during the preview.

## What Siri can do

| Tool intent | Example request |
| --- | --- |
| Draw Tonight's Movie | "Pick an 80s horror movie, nothing too gory" |
| Shortlist Movies | "Give me three comedies rated over 3.5" |
| Get Tonight's Movie | "What are we watching tonight?" |
| Set Tonight's Movie | "Make The Thing tonight's movie" |
| Explain Why People Like a Movie | "Why do people like this?" (uses the curated Why People Like It notes) |
| Mark Movie as Watched | "We just watched it, mark it watched" |
| Update Saved Movie Filters | "Always skip violent movies from now on" |

Supporting pieces:

- `MovieEntity` (App/ThatMovieNightLifeIOS/MovieEntity.swift): every film, with described properties, a string query, Spotlight indexing (iOS 18+), and a `Transferable` text/URL representation so Siri can send a film to Messages or Mail.
- `MovieSnippetCard`: the card Siri shows for a film.
- Onscreen context: the film detail screen publishes its film so "this movie" works.
- Donations: spinning the reel or choosing a film donates the matching intent as a behavioral cue.
- App skills (App/ThatMovieNightLifeIOS/Skills.skillsbundle): `pick-tonights-movie`, `pitch-a-movie`, `wrap-up-movie-night` guide Siri through multi-step requests.

## Testing

1. Open the project in Xcode 27.3 beta (or `xcodegen generate` first) and check the Siri Integration Advisor for suggestions.
2. Run on a supported device, keep the app in the foreground, and try the requests above. With the app in the background, include "That Movie Night Life" in the request.
3. Vary the wording to confirm each skill's description is picked up.
