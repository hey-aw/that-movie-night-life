# TestFlight readiness — 2026-10-03

No signed TestFlight build or upload exists. Source is available on draft PR #2; the browser contract/relay code is on web draft PR #25.

## Implemented
SwiftUI rooms on iOS, macOS and tvOS: one list, durable random/list-order picks, watch history and explicit nightly readiness/availability timestamps. Core Data stores local data/cache; explicit CloudKit records support private rooms, CKShare graphs, tagged conflict handling and responses when a verified container is configured. iOS sharing acceptance, Live Activity actions, validated FaceTime shortcuts, regional provider search links, public-list projection/browse/import/delete and GroupActivities lobby hints are implemented. Public controls remain gated pending verified schema permissions/moderation. SharePlay hints are ephemeral and never authorize or overwrite CloudKit state. The web /cloud-rooms adapter uses the same contract and safe import previews; legacy Blob rooms remain unchanged. Its large-response pagination and personal response reload remain incomplete; oversized responses fail closed. No production relay authorization/storage adapter exists; endpoint stays 503.

## Verified
- 36 XCTest plus 4 Swift Testing tests passed in a clean /tmp scratch directory.
- iOS simulator, tvOS simulator and macOS arm64 builds passed. macOS/tvOS emit only the standard no-AppIntents metadata extraction warning.
- Unsigned Release archive passed: /tmp/TMNL-final-unsigned.xcarchive. This cannot be installed through TestFlight.
- Web 133 tests across 18 files, TypeScript, ESLint and Next.js production build passed after a frozen-lockfile dependency reinstall into a task-local pnpm store.
- No physical, multi-user CloudKit, real APNs/Live Activity actions, cross-platform browser sync or SharePlay verification is claimed. No configured Swift linter is available; whitespace checks and compilation are distinct from Swift lint.

## Account and distribution blockers
The executor is midnightair. Existing codesigning identities report teams 4346Y7BWDM, D574C64JJL and WN52T2UJ4W; none for DX543XXXVC and no matching TMNL provisioning profile was found. This does not verify Apple Account team membership. Safari contains only its start page; the visible ChatGPT window does not show App Store Connect. Browser inspection tools are unavailable in this task; Safari JavaScript from Apple Events is disabled and was not enabled. The user's ready message therefore does not establish an accessible ASC session. App/team/bundle/container records remain unverified. A manual signing attempt uses existing assets only, without automatic provisioning.

Required next steps: establish an inspectable authorized ASC/Developer session; verify the actual team, app, bundle/container ownership; approve any genuinely new credentials/capability grants when required; configure native entitlements and browser origins/API token; deploy/verify schema/indexes/public permissions; physical two-account sharing/conflict/revocation and SharePlay/Live Activity checks; app icon/privacy/export/data-rights/version review; signed archive and validated ASC upload. No credentials, grants, agreements, invitations or public release were changed.

## Hygiene
Native feat/rooms-v1 and web main track browser-profile artifacts. Only named source files were used or published; profile contents were not read/merged/exported. Original user checkouts and stashes remain untouched. Repo history cleanup is a separate owner decision.

The manual signed-archive check failed (exit 65): TMNLRoomActivity and ThatMovieNightLifeIOS require provisioning profiles, and no iOS Distribution certificate with a private key matching DX543XXXVC was found. Automatic provisioning was disabled; no assets were created. Log: /tmp/tmnl-signing-verification.log.
