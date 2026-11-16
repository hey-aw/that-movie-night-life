# TestFlight builds for pull requests

Every pull request against `main` gets an Xcode Cloud archive of the iOS app,
uploaded to TestFlight for **internal testers only**. Builds never go to
external testers or the App Store from this workflow.

## What lives in the repo

| File | What it does |
| --- | --- |
| `ci_scripts/ci_pre_xcodebuild.sh` | Before archiving, sets `CURRENT_PROJECT_VERSION` (CFBundleVersion) to Xcode Cloud's `CI_BUILD_NUMBER`. Fails the build if that is not a plain integer. |
| `ci_scripts/ci_post_xcodebuild.sh` | After archiving, writes `TestFlight/WhatToTest.en-US.txt` with the PR number, branch, commit, build number and recent commit subjects. Xcode Cloud attaches it to the TestFlight build. |
| `project.yml` / `project.pbxproj` | iOS target now has `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1`, an `AppIcon` asset, automatic signing and `ITSAppUsesNonExemptEncryption = NO`, all required for an App Store Connect upload. |
| `App/ThatMovieNightLifeIOS/Assets.xcassets/AppIcon.appiconset` | Placeholder 1024px icon (gold reel on dark). App Store Connect rejects uploads with no icon. Replace it with the real icon whenever it exists. |

## Build numbers

- Build numbers are plain incrementing integers: 1, 2, 3… never dates.
- The source of truth is Xcode Cloud's per-product build counter
  (`CI_BUILD_NUMBER`). It goes up by one on every Xcode Cloud build of the app,
  across all workflows.
- `CURRENT_PROJECT_VERSION = 1` in the project is only the local default.
- When uploading by hand from Xcode's Organizer, **untick "Manage Version and
  Build Number"** so Xcode does not rewrite the number, and bump
  `CURRENT_PROJECT_VERSION` above the latest Xcode Cloud build first. Better:
  let Xcode Cloud do every upload.

## One-time setup (needs AW's Apple account)

These steps happen in Xcode and App Store Connect and can't be done from the
repo.

### 1. App Store Connect app record

1. In [App Store Connect › Apps](https://appstoreconnect.apple.com/apps), check
   there is an app for bundle ID `com.aw.ThatMovieNightLifeIOS` (team
   `DX543XXXVC`). If not, click **+ › New App**, platform iOS, name
   "That Movie Night Life", pick that bundle ID (register it under
   [Identifiers](https://developer.apple.com/account/resources/identifiers/list)
   first if it is not listed).
2. Open the app › **TestFlight** › **Internal Testing** › **+**, create a group
   called **PR Builds**, and add yourself (and anyone else on the team).
   Leave "Enable automatic distribution" on.

### 2. Create the Xcode Cloud workflow

1. Open `ThatMovieNightLife.xcodeproj` (not `Package.swift`) in **Xcode 27.3
   beta**, so the workflow can build the Siri/App Intents work in PR #3.
2. **Integrate › Create Workflow…**, choose the **ThatMovieNightLifeIOS**
   product, and grant Xcode Cloud access to `hey-aw/that-movie-night-life` on
   GitHub when asked.
3. Edit the workflow:
   - **General**: name it `PR Builds`. Leave "Restrict editing" off.
   - **Environment**: Xcode version **Latest Beta (27.3)**, macOS **Latest**.
   - **Start Conditions**: delete the default "Branch Changes" condition. Add
     **Pull Request Changes**: source branch **Any Branch**, target branch
     **Custom › `main`**. Turn on **Auto-cancel Builds** so a new push
     replaces an in-flight build for the same PR.
   - **Actions**: one **Archive** action, platform **iOS**, scheme
     **ThatMovieNightLifeIOS**, deployment preparation **TestFlight (Internal
     Testing Only)**. Don't add a Test action yet; the scheme has no test
     targets (the core tests run through `swift test`).
   - **Post-Actions**: add **TestFlight Internal Testing** and pick the
     **PR Builds** group.
4. Save. Signing is handled by Xcode Cloud's cloud-managed certificates; no
   profiles need to be committed.

### 3. Set the next build number

In App Store Connect › the app › **Xcode Cloud** › **Settings** › **Build
Number**, set **Next Build Number** to one more than the highest build already
uploaded for this app (or leave it at 1 if nothing has been uploaded).

### 4. Check it works

Push any commit to an open PR (PR #3 is the obvious first one). Within a few
minutes you should see:

1. A build in Xcode's Report navigator (or App Store Connect › Xcode Cloud ›
   Builds) titled with the PR.
2. The `ci_pre_xcodebuild` log line `build number set to N`.
3. A new TestFlight build N under **PR Builds**, whose "What to Test" names
   the PR and commit.

## Things to know

- Only the PR's own branch is built. There is no combined "main + all open
  PRs" preview build; that needs a separate coordinator and can be added later.
- Builds made with a beta Xcode/SDK can go to TestFlight but not the App
  Store. If App Store Connect ever rejects an upload for using a beta SDK, the
  workflow's Xcode version is the cause.
- If the app later adds non-exempt encryption, flip
  `ITSAppUsesNonExemptEncryption` to `YES` and answer the export compliance
  questions in App Store Connect.
- A green Xcode Cloud build only proves the app compiled, signed and uploaded.
  It is not a substitute for opening the build on a device.
