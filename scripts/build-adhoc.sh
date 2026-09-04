#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ARCHIVE="$ROOT/dist/Yahpaz-adhoc.xcarchive"
OUT="$ROOT/dist/adhoc"

if command -v xcodegen >/dev/null; then
  xcodegen generate
fi

rm -rf "$ARCHIVE" "$OUT"

xcodebuild archive \
  -scheme Yahpaz \
  -project Yahpaz.xcodeproj \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$ROOT/scripts/export-options-adhoc.plist" \
  -exportPath "$OUT" \
  -allowProvisioningUpdates

# Xcode fills the manifest title from CFBundleName, so the iOS install sheet
# would prompt in English. The UI is Hebrew-only; use the display name.
/usr/libexec/PlistBuddy -c 'Set :items:0:metadata:title אבן דרך' "$OUT/manifest.plist"

# Fail loudly if the embedded profile is not Ad Hoc or has no devices.
WORK=$(mktemp -d)
unzip -qq "$OUT/Yahpaz.ipa" -d "$WORK"
PROFILE="$WORK/Payload/Yahpaz.app/embedded.mobileprovision"
security cms -D -i "$PROFILE" > "$WORK/profile.plist"

DEVICES=$(/usr/libexec/PlistBuddy -c 'Print :ProvisionedDevices' "$WORK/profile.plist" 2>/dev/null | grep -c '^ ' || true)
EXPIRES=$(/usr/libexec/PlistBuddy -c 'Print :ExpirationDate' "$WORK/profile.plist")

if [ "$DEVICES" -lt 1 ]; then
  echo "ERROR: embedded profile has no provisioned devices — this build installs nowhere." >&2
  exit 1
fi

echo "✅ Ad Hoc IPA ready"
echo "   devices in profile: $DEVICES"
echo "   profile expires:    $EXPIRES"
ls -lh "$OUT/Yahpaz.ipa" "$OUT/manifest.plist"
rm -rf "$WORK"
