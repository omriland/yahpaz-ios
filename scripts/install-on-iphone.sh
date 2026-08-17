#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEVICE_JSON=$(xcrun devicectl list devices --json-output /dev/stdout 2>/dev/null || true)
echo "$DEVICE_JSON" | python3 - <<'PY' || true
import json,sys
raw=sys.stdin.read()
print(raw[:200])
PY

echo "Looking for a connected iPhone..."
xcrun xctrace list devices 2>/dev/null | sed -n '1,40p' || true

# Prefer a physical iPhone that is available.
DEST=$(xcodebuild -showdestinations -scheme Yahpaz -project Yahpaz.xcodeproj 2>/dev/null | awk -F'destination: ' '/platform:iOS,/ && /id:/ && $0 !~ /Simulator/ {print; exit}')
echo "Xcode destination: ${DEST:-none}"

if [[ -z "${DEST}" ]]; then
  echo "No physical iPhone is connected and available."
  echo "Plug in the iPhone, trust this Mac, enable Developer Mode, then run this script again."
  echo "Until then install from: https://omriland.github.io/yahpaz-ios/"
  exit 1
fi

xcodebuild \
  -scheme Yahpaz \
  -project Yahpaz.xcodeproj \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM=477WWCHXU7 \
  CODE_SIGN_STYLE=Automatic \
  -configuration Release \
  build
