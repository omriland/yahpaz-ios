#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Override when publishing from a git worktree of the web repo.
WEB="${YAHPAZ_WEB:-/Users/omrilandman/CursorProjects/today-i/op-yh-26}"
SRC="$ROOT/dist/adhoc"
DEST="$WEB/public/ios"

if [ ! -f "$SRC/Yahpaz.ipa" ] || [ ! -f "$SRC/manifest.plist" ]; then
  echo "ERROR: run ./scripts/build-adhoc.sh first." >&2
  exit 1
fi

if [ ! -d "$DEST" ]; then
  echo "ERROR: $DEST does not exist. Is YAHPAZ_WEB pointing at the web repo?" >&2
  exit 1
fi

cp "$SRC/Yahpaz.ipa" "$DEST/Yahpaz.ipa"
cp "$SRC/manifest.plist" "$DEST/manifest.plist"

# Read the shipped build number straight out of the IPA so version.json
# can never drift from the binary it describes.
WORK=$(mktemp -d)
unzip -qq "$SRC/Yahpaz.ipa" -d "$WORK"
PLIST="$WORK/Payload/Yahpaz.app/Info.plist"
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")
NAME=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")
rm -rf "$WORK"

# Forcing an update is a decision, not a side effect of publishing — carry minBuild over.
MIN=$(/usr/bin/python3 -c "import json;print(json.load(open('$DEST/version.json'))['minBuild'])")

cat > "$DEST/version.json" <<JSON
{
  "minBuild": $MIN,
  "latestBuild": $BUILD,
  "latestVersionName": "$NAME",
  "manifestUrl": "https://yahpz.com/ios/manifest.plist",
  "messageHe": "יש גרסה חדשה של האפליקציה. יש להוריד ולהתקין כדי להמשיך."
}
JSON

echo "✅ published build $BUILD ($NAME) to $DEST"
echo "   minBuild left at $MIN — raise it by hand only when forcing an update"
