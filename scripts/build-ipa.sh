#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if command -v xcodegen >/dev/null; then
  xcodegen generate
fi

xcodebuild \
  -scheme Yahpaz \
  -project Yahpaz.xcodeproj \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

APP=$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/Yahpaz-*/Build/Products/Release-iphoneos/Yahpaz.app | head -1)
STAGE=$(mktemp -d)
mkdir -p "$STAGE/Payload" "$ROOT/dist"
rsync -a "$APP" "$STAGE/Payload/"
rm -f "$ROOT/dist/Yahpaz.ipa"
(cd "$STAGE" && zip -qr "$ROOT/dist/Yahpaz.ipa" Payload)
ls -lh "$ROOT/dist/Yahpaz.ipa"
