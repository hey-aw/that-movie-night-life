#!/bin/sh
# Xcode Cloud runs this before every xcodebuild action.
#
# Build numbers are plain incrementing integers. Xcode Cloud's CI_BUILD_NUMBER
# increases by one for every build of this product, so we stamp it into
# CURRENT_PROJECT_VERSION (CFBundleVersion) before archiving. That keeps the
# number inside the archive identical to the one TestFlight shows. The marketing
# version (CFBundleShortVersionString) stays whatever MARKETING_VERSION says.

set -eu

if [ "${CI_XCODEBUILD_ACTION:-}" != "archive" ]; then
  echo "ci_pre_xcodebuild: action is '${CI_XCODEBUILD_ACTION:-}', leaving build number alone."
  exit 0
fi

BUILD_NUMBER="${CI_BUILD_NUMBER:-}"
case "$BUILD_NUMBER" in
  ''|*[!0-9]*)
    echo "error: CI_BUILD_NUMBER '$BUILD_NUMBER' is not a plain integer." >&2
    exit 1
    ;;
esac

PBXPROJ="$CI_PRIMARY_REPOSITORY_PATH/ThatMovieNightLife.xcodeproj/project.pbxproj"

if ! grep -q "CURRENT_PROJECT_VERSION = " "$PBXPROJ"; then
  echo "error: CURRENT_PROJECT_VERSION is missing from $PBXPROJ" >&2
  exit 1
fi

# Only the iOS target sets CURRENT_PROJECT_VERSION, so this touches nothing else.
sed -i '' -E "s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = $BUILD_NUMBER;/" "$PBXPROJ"

echo "ci_pre_xcodebuild: build number set to $BUILD_NUMBER"
grep -n "CURRENT_PROJECT_VERSION" "$PBXPROJ"
