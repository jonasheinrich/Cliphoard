#!/bin/bash
#
# Builds Cliphoard once: scripts/build.sh [Debug|Release] (default Release).
# The app ends up in build/DerivedData/Build/Products/<configuration>/.

set -u

CONFIGURATION="${1:-Release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! xcodebuild -version >/dev/null 2>&1; then
    echo "error: xcodebuild needs the full Xcode app, not just the Command Line Tools." >&2
    echo "Install Xcode, then run: sudo xcode-select -s /Applications/Xcode.app" >&2
    exit 1
fi

xcodebuild -quiet \
    -project Cliphoard.xcodeproj -scheme Cliphoard -configuration "$CONFIGURATION" \
    -destination "platform=macOS,arch=$(uname -m)" \
    -derivedDataPath "$ROOT/build/DerivedData" build 2>&1 \
    | grep -E '^[^ ]+:[0-9]+:[0-9]+: (error|warning):|^\*\* BUILD' \
    | awk '!seen[$0]++'
# xcodebuild's exit code, not grep's.
exit "${PIPESTATUS[0]}"
