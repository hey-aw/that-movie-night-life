# Readiness — 2026-10-02

This review branch is a local-room vertical slice. Shared rooms, remote RSVP, public lists, Live Activities, SharePlay, FaceTime room links and regional provider lookup remain unimplemented. No signed archive, App Store Connect record or TestFlight upload has been produced.

## Validation
- Swift package: 29 XCTest tests plus 4 Swift Testing tests passed, zero failures. Six new room/record-contract tests cover ordered/random selection, stable picks, duplicate avoidance, explicit readiness, SQLite persistence after reopening a repository, and explicit CloudKit record validation/round-trip.
- iOS simulator Debug build: passed (iOS 26.4 iPhone 17 Pro destination, signing disabled).
- tvOS simulator Debug build: passed (tvOS 26.4 Apple TV 4K destination, signing disabled). Baseline iOS-only source compile errors fixed by source exclusions and an iOS availability guard.
- Native macOS Debug arm64 build: passed, signing disabled. Room-only SwiftUI shell shares domain and Core Data persistence.
- xcodegen project generation and git diff --check: passed. No configured Swift lint tool or installed swiftlint found; whitespace validation is not a Swift lint claim.
- iOS simulator install and launch passed (bundle com.aw.ThatMovieNightLifeIOS); screenshot showed Tonight home UI. Automated Rooms-tab tap left the screen unchanged, so no room UI interaction/relaunch claim is made.
- Simulator build evidence is not physical-device, multiple-user, CloudKit or SharePlay validation.

## Access and decisions remaining
1. Latest decision: one explicit CloudKit record model shared by native clients and CloudKit JS, with Core Data as cache and Vercel restricted to a minimal APNs relay. Implement and verify the remaining record graph, sharing, and cache reconciliation. Current local Core Data aggregate is a prototype and would become a cache or migrate to normalized shared entities.
2. Unlock Mac and sign into App Store Connect; verify app record/bundle ownership and intended Apple developer team. Main specifies DX543XXXVC. Existing certificates were found, but no certificate proves that this team owns this app. No team changed, credentials created, or agreement accepted.
3. Verify existing iCloud container/capabilities if CloudKit is selected, or authenticated backend membership and APNs access if API/push work is selected. New credentials/grants require appropriate approval.
4. Complete icon/version/build/privacy/export-compliance/data-rights checks, obtain matching distribution profile, create a signed archive, inspect entitlements and upload to the verified existing/new App Store Connect record. Do not invite testers or submit a public release.

## Hygiene
1,826 browser-profile paths are tracked on feat/rooms-v1. Only names were inspected; no browser content was read or checked out. Branch was not merged. New ignore rules prevent accidental future profile tracking; historical exposure still requires separate owner review.
