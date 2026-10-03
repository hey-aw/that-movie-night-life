# TestFlight readiness — 2026-10-03

Source is on draft PR #2; browser contract/relay source is on draft web PR #25. ASC iOS app record is [6818691370](https://appstoreconnect.apple.com/apps/6818691370).

## Verified Apple setup
Awesomely Done, LLC team `WN52T2UJ4W`, Account Holder role and existing valid Apple Distribution identity were verified through the user's signed-in Safari and local public certificate labels. User approved creation of `com.aw.ThatMovieNightLifeIOS`, `com.aw.ThatMovieNightLifeIOS.RoomActivity`, `iCloud.com.aw.ThatMovieNightLife`, exact container associations, CloudKit and main-app Group Activities, and the two App Store profiles. These assets were created and verified; see apple-signing-state.md. No App Group, new certificate, APNs key, macOS/tvOS security resource, agreement or invitation was created.

## Validation
36 XCTest plus 4 Swift Testing tests passed with final signing/packaging source. Signed Release archives and local App Store export passed. Strict signature checks verified app/extension team, exact container entitlements, matching version 0.1.0/build 1, beta icon, main CKSharingSupported/NSSupportsLiveActivities and extension display name. Apple's first upload rejected a missing extension CFBundleDisplayName; it was corrected and the authorized upload retried. The corrected upload succeeded on 2026-10-03 at 02:49 UTC; Apple reported the uploaded package is processing. TestFlight processing, export compliance and installation remain separate checks.

Earlier iOS/tvOS simulator and macOS arm64 builds passed. Web 137 tests/18 files, TypeScript, ESLint and production build passed. No physical, multi-user CloudKit, real APNs/Live Activity action, browser cross-account sync or SharePlay verification is claimed. No configured Swift linter is available.

## Beta scope and remaining work
Runtime cloud identifiers stay blank until production schema/index and two-account sharing/conflict/revocation checks pass. The beta therefore exercises Core Data local rooms, one list, durable random/list-order picks, watch history and explicit availability timestamps. Expired estimates never imply Ready. CloudKit permissions are trusted-friends CKShare write access, not actor-specific server roles. Public publishing stays gated pending creator permissions/moderation. Temporary SharePlay lobby hints never overwrite durable room state or authorize CloudKit writes. Relay endpoint remains 503; broad web token delegation is not approved.

Production cloud configuration, physical validation, privacy/data-rights and export-compliance declarations remain. TestFlight upload is authorized; public release and tester invitations are not.

## Hygiene
Native feat/rooms-v1 and web main track browser profiles. Only named source paths were used/published; profile contents were not read, merged or exported. Original user checkouts and stashes remain untouched. Historical cleanup is a separate owner decision. Signed profiles and private keys are outside source.

Current build 0.1.0 (1) finished processing and ASC shows Ready to Submit after saving the encryption-questionnaire answer None of the algorithms mentioned above. Reviewed source uses Apple SHA-256 hashing/system networking; ZIPFoundation rejects encrypted archives, and no proprietary or separately implemented encryption was found. No new agreement was accepted. No tester assignment or invitation has been performed; an approved internal tester/group assignment is still needed for installation. Future encryption changes require renewed review.
