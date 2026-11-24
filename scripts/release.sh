#!/bin/bash
#
# Builds a release DMG and the matching Homebrew cask:
#   scripts/release.sh            build/Cliphoard-<version>.dmg + build/cliphoard.rb
#   scripts/release.sh --publish  also creates the GitHub release v<version>
#
# Without a developer account the app stays ad-hoc signed and users must allow
# it once in System Settings. To sign and notarize, set both:
#   DEVELOPER_ID="Developer ID Application: Name (TEAMID)"
#   NOTARY_PROFILE=<profile saved with `xcrun notarytool store-credentials`>

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REPO="jonasheinrich/Cliphoard"
BUNDLE_ID="dev.local.Cliphoard"
APP="build/DerivedData/Build/Products/Release/Cliphoard.app"

PUBLISH=false
[ "${1:-}" = "--publish" ] && PUBLISH=true

NOTARIZE=false
if [ -n "${DEVELOPER_ID:-}" ] || [ -n "${NOTARY_PROFILE:-}" ]; then
    if [ -z "${DEVELOPER_ID:-}" ] || [ -z "${NOTARY_PROFILE:-}" ]; then
        echo "error: set both DEVELOPER_ID and NOTARY_PROFILE, or neither" >&2
        exit 1
    fi
    NOTARIZE=true
fi

log() { printf '\033[1;34m[release]\033[0m %s\n' "$*"; }

log "Building"
scripts/build.sh Release

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")"
DMG="build/Cliphoard-$VERSION.dmg"
CASK="build/cliphoard.rb"

if $NOTARIZE; then
    log "Signing with $DEVELOPER_ID"
    codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" "$APP"
fi
codesign --verify --strict "$APP"

log "Creating $DMG"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/Cliphoard.app"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -quiet -volname "Cliphoard" -srcfolder "$STAGING" -format UDZO "$DMG"

if $NOTARIZE; then
    codesign --sign "$DEVELOPER_ID" --timestamp "$DMG"
    log "Notarizing (usually a few minutes)"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
fi

SHA256="$(shasum -a 256 "$DMG" | cut -d ' ' -f 1)"

log "Writing $CASK"
{
    cat <<EOF
cask "cliphoard" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/$REPO/releases/download/v#{version}/Cliphoard-#{version}.dmg"
  name "Cliphoard"
  desc "Clipboard history for text"
  homepage "https://github.com/$REPO"

  depends_on macos: :sequoia

  app "Cliphoard.app"

  zap trash: [
    "~/Library/Application Support/$BUNDLE_ID",
    "~/Library/Preferences/$BUNDLE_ID.plist",
  ]
EOF
    if ! $NOTARIZE; then
        cat <<'EOF'

  caveats <<~EOS
    Cliphoard isn't notarized by Apple yet, so macOS blocks its first launch.
    Open System Settings > Privacy & Security and click "Open Anyway".
  EOS
EOF
    fi
    echo "end"
} > "$CASK"

if $PUBLISH; then
    log "Publishing GitHub release v$VERSION"
    git rev-parse "v$VERSION" >/dev/null 2>&1 || git tag "v$VERSION"
    git push origin "v$VERSION"
    gh release create "v$VERSION" "$DMG" --repo "$REPO" --title "Cliphoard $VERSION" --generate-notes
fi

log "Done: $DMG (sha256 $SHA256)"
if $PUBLISH; then
    log "Next: copy $CASK to Casks/cliphoard.rb in jonasheinrich/homebrew-tap and push"
else
    log "Next: check the DMG, then run scripts/release.sh --publish"
fi
