#!/usr/bin/env bash
set -euo pipefail

# iOS development helper for That Movie Night Life
# Usage: bash ios.sh <command> [args]

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PROJECT="$PROJECT_ROOT/ThatMovieNightLife.xcodeproj"
SCHEME="ThatMovieNightLifeIOS"
BUNDLE_ID="com.aw.ThatMovieNightLifeIOS"

DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"

DEFAULT_SIM_NAME="iPhone 16"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

find_derived_data_dir() {
  local pattern="ThatMovieNightLife-*"
  local dir
  dir=$(find "$DERIVED_DATA" -maxdepth 1 -name "$pattern" -type d | head -1)
  if [[ -z "$dir" ]]; then
    echo "ERROR: No derived data found. Build first." >&2
    exit 1
  fi
  echo "$dir"
}

sim_app_path() {
  echo "$(find_derived_data_dir)/Build/Products/Debug-iphonesimulator/That Movie Night Life.app"
}

device_app_path() {
  echo "$(find_derived_data_dir)/Build/Products/Debug-iphoneos/That Movie Night Life.app"
}

default_sim_id() {
  local sim_id="${1:-}"
  if [[ -n "$sim_id" ]]; then
    echo "$sim_id"
    return
  fi
  xcrun simctl list devices available \
    | grep "$DEFAULT_SIM_NAME" \
    | head -1 \
    | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/'
}

default_device_id() {
  local dev_id="${1:-}"
  if [[ -n "$dev_id" ]]; then
    echo "$dev_id"
    return
  fi
  # Match only lines with "available (paired)" to skip unavailable devices
  xcrun devicectl list devices 2>&1 \
    | grep "available (paired)" \
    | head -1 \
    | awk '{for(i=1;i<=NF;i++) if($i ~ /^[A-F0-9]{8}-[A-F0-9]{4}-/) print $i}'
}

booted_sim_id() {
  xcrun simctl list devices booted \
    | grep -E '\(Booted\)' \
    | head -1 \
    | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/'
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

cmd_build() {
  local target="${1:-sim}"
  echo "==> Building for $target..."
  case "$target" in
    sim|simulator)
      local sim_id
      sim_id=$(default_sim_id "${2:-}")
      xcodebuild \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,id=$sim_id" \
        build 2>&1 | tail -10
      echo "==> App: $(sim_app_path)"
      ;;
    device|phone)
      xcodebuild \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination 'generic/platform=iOS' \
        -allowProvisioningUpdates \
        build 2>&1 | tail -10
      echo "==> App: $(device_app_path)"
      ;;
    *)
      echo "Usage: build <sim|device>" >&2
      exit 1
      ;;
  esac
}

cmd_boot() {
  local sim_id
  sim_id=$(default_sim_id "${1:-}")
  echo "==> Booting simulator $sim_id..."
  xcrun simctl boot "$sim_id" 2>/dev/null || true
  open -a Simulator 2>/dev/null || true
  echo "==> Booted."
}

cmd_install() {
  local target="${1:-sim}"
  case "$target" in
    sim|simulator)
      local sim_id
      sim_id=$(default_sim_id "${2:-}")
      local booted
      booted=$(booted_sim_id)
      if [[ -z "$booted" ]]; then
        echo "==> No booted simulator. Booting $sim_id..."
        cmd_boot "$sim_id"
        sleep 2
        sim_id=$(booted_sim_id)
      else
        sim_id="$booted"
      fi
      echo "==> Installing on simulator $sim_id..."
      xcrun simctl install "$sim_id" "$(sim_app_path)"
      echo "==> Installed."
      ;;
    device|phone)
      local dev_id
      dev_id=$(default_device_id "${2:-}")
      echo "==> Installing on device $dev_id..."
      xcrun devicectl device install app \
        --device "$dev_id" \
        "$(device_app_path)" 2>&1
      echo "==> Installed."
      ;;
    *)
      echo "Usage: install <sim|device> [id]" >&2
      exit 1
      ;;
  esac
}

cmd_launch() {
  local target="${1:-sim}"
  case "$target" in
    sim|simulator)
      local sim_id
      sim_id=$(booted_sim_id)
      if [[ -z "$sim_id" ]]; then
        sim_id=$(default_sim_id "${2:-}")
      fi
      echo "==> Launching on simulator..."
      xcrun simctl launch "$sim_id" "$BUNDLE_ID" 2>&1
      ;;
    device|phone)
      local dev_id
      dev_id=$(default_device_id "${2:-}")
      echo "==> Launching on device $dev_id..."
      xcrun devicectl device process launch \
        --device "$dev_id" \
        "$BUNDLE_ID" 2>&1
      ;;
    *)
      echo "Usage: launch <sim|device> [id]" >&2
      exit 1
      ;;
  esac
}

cmd_screenshot() {
  local output="${1:-/tmp/ios_screenshot.png}"
  local sim_id
  sim_id=$(booted_sim_id)
  if [[ -z "$sim_id" ]]; then
    echo "ERROR: No booted simulator found." >&2
    exit 1
  fi
  xcrun simctl io "$sim_id" screenshot "$output" 2>&1
  echo "$output"
}

cmd_devices() {
  echo "==> Physical devices:"
  xcrun devicectl list devices 2>&1 | grep -E "Name|available|unavailable"
}

cmd_simulators() {
  echo "==> Available simulators:"
  xcrun simctl list devices available | grep "iPhone\|iPad"
}

cmd_run() {
  local target="${1:-sim}"
  shift || true
  cmd_build "$target" "$@"
  cmd_install "$target" "$@"
  cmd_launch "$target" "$@"
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

cmd="${1:-help}"
shift || true

case "$cmd" in
  build)      cmd_build "$@" ;;
  boot)       cmd_boot "$@" ;;
  install)    cmd_install "$@" ;;
  launch)     cmd_launch "$@" ;;
  screenshot) cmd_screenshot "$@" ;;
  devices)    cmd_devices ;;
  simulators) cmd_simulators ;;
  run)        cmd_run "$@" ;;
  help|--help|-h)
    echo "Usage: ios.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  build <sim|device>        Build the app"
    echo "  boot [sim-id]             Boot a simulator"
    echo "  install <sim|device> [id] Install on target"
    echo "  launch <sim|device> [id]  Launch on target"
    echo "  screenshot [path]         Capture simulator screen"
    echo "  devices                   List physical devices"
    echo "  simulators                List available simulators"
    echo "  run <sim|device>          Build + install + launch"
    echo "  help                      Show this help"
    ;;
  *)
    echo "Unknown command: $cmd" >&2
    echo "Run 'ios.sh help' for usage." >&2
    exit 1
    ;;
esac
