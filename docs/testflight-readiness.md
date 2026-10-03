# Readiness — 2026-10-02

Source is ready for draft review; no installable TestFlight build exists.

Implemented: local SwiftUI rooms on iOS/tvOS/macOS, Core Data persistence/cache, explicit CloudKit record contract and private/shared client APIs, iOS sharing/acceptance code, ActivityKit extension and availability intents. Cloud configuration is blank until verified ownership/entitlements. Shared-account operation and real pushes have not been tested.

## Validation
- 32 XCTest plus 4 Swift Testing tests passed, zero failures. Covers stable ordered/random unwatched picks, duplicate avoidance, SQLite reopen durability, history/night record round-trip, malformed record rejection, explicit delayed status and native/relay JSON Unix timestamps.
- Final iOS 26.4 simulator Debug build including ActivityKit extension passed with zero warnings; install/launch passed, bundle com.aw.ThatMovieNightLifeIOS. Initial home screenshot rendered. Automated Rooms-tab tap left the screen unchanged; no interactive room UI verification claimed. Final visual inspection was interrupted by simulator/browser tool transport loss.
- Final tvOS simulator Debug build passed using Xcode CLI after tool transport loss.
- Native macOS Debug arm64 build passed, signing disabled.
- xcodegen generation passed. Changed-source whitespace checks passed before later additions; no configured Swift lint tool/installed swiftlint was found. Compilation is not a Swift lint claim.
- Web relay: 123 tests/16 files, TypeScript and ESLint passed with current main's locked dependencies. Mocked authority/store/transport tests are not production CKShare/APNs/atomic-store verification.
- No physical-device, multi-user, CloudKit account/schema, real Live Activity action, APNs delivery or SharePlay validation claimed.

## Exact blockers
1. App Store Connect sign-in and actual ownership verification for chosen team DX543XXXVC, existing app/bundle and CloudKit container. Browser UI connection is currently unavailable; no record creation or upload performed.
2. Configure the verified existing container identifier/entitlements, schema and indexes; test two iCloud accounts and share acceptance/conflicts/revocation before treating shared sync as ready.
3. Choose/approve relay access protocol. Apple bearer delegation is container-wide private/shared access, not single-room access; new transfer/retention needs explicit consent. Also verify existing atomic storage/encryption/APNs credentials and deployment permission. Route remains 503.
4. Complete web CloudKit migration, public lists, FaceTime links, regional official provider links and own-app SharePlay; no parallel room authority.
5. Icon/privacy/export/data-rights/version checks, matching provisioning, signed archive and validated upload. No credentials/grants/agreements/invitations/public release changed.

## Hygiene
Browser-profile artifacts on native feature history and web main are separate owner-review risks. Only named source paths are committed; no browser contents are part of PR changes. Existing user checkouts and stashes were not modified.

## Additional native room features

Validated HTTPS FaceTime shortcuts are optional Room metadata, shared privately with the room. Regional JustWatch and Apple TV searches do not claim title availability. Explicit PublicList projection strips room IDs, history, attendance and links; publication/browse/import/delete code is gated by TMNLPublicListsEnabled until public schema roles, indexes and moderation are verified. Native GroupActivities sends temporary room/night-scoped pick/readiness hints; rejects stale/replayed/wrong-night messages and removes departed participants. It never persists received hints or treats FaceTime membership as CloudKit permission. No AVPlayer or provider playback interception is added. GroupActivities signed entitlement and physical multi-user verification remain required.

A clean /tmp Swift scratch directory avoids Finder metadata on cached test bundles. Local signing/cache/simulator sandbox errors were resolved through approved build execution, with no permission changes. New builds have only the standard no-AppIntents metadata-extraction warning on macOS/tvOS.
