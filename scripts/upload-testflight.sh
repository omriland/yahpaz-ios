#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if command -v xcodegen >/dev/null; then
  xcodegen generate
fi

ARCHIVE="$ROOT/dist/Yahpaz.xcarchive"
EXPORT_OPTS="$ROOT/scripts/export-options-appstore.plist"
mkdir -p "$ROOT/dist"
rm -rf "$ARCHIVE"

xcodebuild \
  -scheme Yahpaz \
  -project Yahpaz.xcodeproj \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  archive

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$EXPORT_OPTS" \
  -allowProvisioningUpdates
