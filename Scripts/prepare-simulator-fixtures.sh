#!/bin/bash
# prepare-simulator-fixtures.sh — Rehearsal (copy byte-identical into your project)
# Loads all <consumer>UITests/Fixtures/*.jpg into the BOOTED simulator's Photos library.
# Idempotent: re-adding same image is a no-op.

set -e
SIM_NAME="${1:-iPhone 17 Pro}"
FIXTURES_DIR="${2:-$(dirname "$0")/../Fixtures}"

# Verify simctl
xcrun simctl --version >/dev/null 2>&1 || {
  echo "Error: xcrun simctl unavailable. Run 'sudo xcode-select -s /Applications/Xcode.app/Contents/Developer' to fix."
  exit 1
}

# Find booted simulator with matching name
DEVICE_ID=$(xcrun simctl list devices booted | grep "$SIM_NAME" | grep -oE '[0-9A-F-]{36}' | head -1)
[ -z "$DEVICE_ID" ] && {
  echo "Error: No booted simulator named '$SIM_NAME'. Boot one via Simulator.app or 'xcrun simctl boot <id>' first."
  exit 1
}

# Add each fixture JPG
for img in "$FIXTURES_DIR"/*.jpg; do
  [ -e "$img" ] || continue
  echo "Loading: $(basename "$img")"
  xcrun simctl addmedia "$DEVICE_ID" "$img"
done

echo "Fixtures loaded for $SIM_NAME ($DEVICE_ID)"
