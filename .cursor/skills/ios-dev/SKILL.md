---
name: ios-dev
description: >-
  Build, run, screenshot, and deploy iOS apps using Xcode command-line tools.
  Use when building for simulator or device, taking simulator screenshots,
  installing on a physical iPhone, or reviewing UI changes visually. Triggers
  on: "build", "run on simulator", "screenshot", "push to phone", "install on
  device", "review design", "run on iPhone".
---

# iOS Development Workflow

## Project conventions

- Xcode project: `ThatMovieNightLife.xcodeproj`
- iOS scheme: `ThatMovieNightLifeIOS`
- Bundle ID: `com.aw.ThatMovieNightLifeIOS`
- Deployment target: iOS 17.0

## Quick reference

```bash
# Run the helper for any operation
bash .cursor/skills/ios-dev/scripts/ios.sh <command> [args]
```

| Command | What it does |
|---------|-------------|
| `ios.sh build sim` | Build for simulator |
| `ios.sh build device` | Build for physical device |
| `ios.sh boot [sim-id]` | Boot a simulator (default: iPhone 16) |
| `ios.sh install sim [sim-id]` | Install app on booted simulator |
| `ios.sh install device [device-id]` | Install app on physical device |
| `ios.sh launch sim [sim-id]` | Launch app in simulator |
| `ios.sh launch device [device-id]` | Launch app on physical device |
| `ios.sh screenshot [path]` | Take simulator screenshot |
| `ios.sh devices` | List connected physical devices |
| `ios.sh simulators` | List available simulators |
| `ios.sh run sim` | Build + install + launch on simulator |
| `ios.sh run device` | Build + install + launch on device |

## Workflow: Review UI changes

1. Build and run on simulator:
   ```bash
   bash .cursor/skills/ios-dev/scripts/ios.sh run sim
   ```
2. Wait 2-3 seconds for launch, then screenshot:
   ```bash
   bash .cursor/skills/ios-dev/scripts/ios.sh screenshot /tmp/review.png
   ```
3. Read the screenshot image to inspect the design.
4. Make changes, rebuild, re-screenshot.

## Workflow: Deploy to physical device

1. Build for device:
   ```bash
   bash .cursor/skills/ios-dev/scripts/ios.sh build device
   ```
2. Find the target device:
   ```bash
   bash .cursor/skills/ios-dev/scripts/ios.sh devices
   ```
3. Install and launch (uses first available device by default):
   ```bash
   bash .cursor/skills/ios-dev/scripts/ios.sh run device
   ```
4. If the device is locked, the launch will fail. Ask the user to unlock, then retry launch only:
   ```bash
   bash .cursor/skills/ios-dev/scripts/ios.sh launch device
   ```

## Simulator interaction limitations

- `xcrun simctl io screenshot` captures the simulator screen without macOS permissions.
- There is **no CLI for simulating taps or swipes** in the simulator. Navigation requires either:
  - XCUITest automation (requires a test target)
  - macOS Accessibility permissions for `cliclick` / `osascript` System Events
  - Manual user interaction
- To view different app states, modify the code to set a default tab/state, rebuild, and screenshot. Revert afterward.

## Build tips

- Always pass `-allowProvisioningUpdates` when building for device.
- Check for build errors in the last 10 lines of output: `| tail -10`
- The Xcode derived data path for the built app is printed by the script.
- If a physical device shows "profile has not been explicitly trusted," the user must go to Settings → General → VPN & Device Management and trust the developer profile.
