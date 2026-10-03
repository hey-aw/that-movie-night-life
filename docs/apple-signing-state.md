# Apple signing state

Verified Apple Developer team: Awesomely Done, LLC (`WN52T2UJ4W`). Approved and created main App ID `com.aw.ThatMovieNightLifeIOS`, extension App ID `com.aw.ThatMovieNightLifeIOS.RoomActivity`, and dedicated container `iCloud.com.aw.ThatMovieNightLife`. Both IDs have CloudKit and one-container association; only the main app has Group Activities. No App Group, new certificate, APNs key, macOS/tvOS security assets or broad web delegation was created.

Approved App Store profiles: `TMNL iOS App Store` and `TMNL Room Activity App Store`, using the existing Apple Distribution identity, expiring September 16, 2027. Profiles and private keys are excluded from source; local signing setup must install the approved profiles. Release signing is explicit; Debug defaults to Development CloudKit environment and requires suitable existing development signing for physical devices.

ASC app: https://appstoreconnect.apple.com/apps/6818691370 — That Movie Night Life, iOS, English (U.S.), SKU `tmnl-ios`. Limited access selected; no tester invitations or public release.

The beta app icon is an original deterministic film/play mark in the existing app palette. CKSharingSupported is now an explicit plist property. Runtime CloudKit container identifiers remain blank until production schema and multi-account validation; this signed slice therefore exercises local rooms. Container entitlements authorize only the approved dedicated container. Production public lists and the web APNs relay remain disabled.

Required follow-up: production CloudKit schema/index verification, physical two-account sharing/conflict/revocation, physical Live Activity and SharePlay; export-compliance and privacy/data-rights declarations. No claim of multi-user validation or public distribution.

Signed build 0.1.0 (1) uploaded successfully on 2026-10-03 at 02:49 UTC. Apple accepted the corrected extension display name and reported processing. Upload success does not establish installation readiness or completion of export compliance.

Current build 0.1.0 (1) finished processing and ASC shows Ready to Submit after saving the encryption-questionnaire answer None of the algorithms mentioned above. Reviewed source uses Apple SHA-256 hashing/system networking; ZIPFoundation rejects encrypted archives, and no proprietary or separately implemented encryption was found. No new agreement was accepted. No tester assignment or invitation has been performed; an approved internal tester/group assignment is still needed for installation. Future encryption changes require renewed review.
