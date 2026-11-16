#!/bin/sh
# Xcode Cloud runs this after every xcodebuild action.
#
# After a successful archive, write TestFlight "What to Test" notes so internal
# testers can see which pull request and commit a build came from. Xcode Cloud
# picks up TestFlight/WhatToTest.<locale>.txt next to ci_scripts/ and attaches
# it to the build it uploads.

set -eu

if [ "${CI_XCODEBUILD_ACTION:-}" != "archive" ] || [ -z "${CI_ARCHIVE_PATH:-}" ]; then
  exit 0
fi

NOTES_DIR="$CI_PRIMARY_REPOSITORY_PATH/TestFlight"
NOTES_FILE="$NOTES_DIR/WhatToTest.en-US.txt"
mkdir -p "$NOTES_DIR"

SHORT_SHA=$(printf '%s' "${CI_COMMIT:-unknown}" | cut -c1-7)

{
  if [ -n "${CI_PULL_REQUEST_NUMBER:-}" ]; then
    echo "PR #${CI_PULL_REQUEST_NUMBER}: ${CI_PULL_REQUEST_SOURCE_BRANCH:-?} -> ${CI_PULL_REQUEST_TARGET_BRANCH:-?}"
    [ -n "${CI_PULL_REQUEST_HTML_URL:-}" ] && echo "${CI_PULL_REQUEST_HTML_URL}"
  else
    echo "Branch: ${CI_BRANCH:-${CI_TAG:-unknown}}"
  fi
  echo "Commit: ${SHORT_SHA}  Build: ${CI_BUILD_NUMBER:-?}  Workflow: ${CI_WORKFLOW:-?}"
  echo ""
  echo "Recent commits:"
  cd "$CI_PRIMARY_REPOSITORY_PATH"
  RANGE="HEAD"
  if [ -n "${CI_PULL_REQUEST_TARGET_BRANCH:-}" ] && \
     git rev-parse --verify --quiet "origin/${CI_PULL_REQUEST_TARGET_BRANCH}" >/dev/null; then
    RANGE="origin/${CI_PULL_REQUEST_TARGET_BRANCH}..HEAD"
  fi
  git log --no-merges --format='- %s' -n 15 "$RANGE" 2>/dev/null || echo "- (commit history unavailable)"
} | cut -c1-200 | head -c 3900 > "$NOTES_FILE"

echo "ci_post_xcodebuild: wrote $NOTES_FILE"
cat "$NOTES_FILE"
