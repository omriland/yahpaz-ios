#!/bin/zsh
# App Store screenshots from the running app on DEBUG demo data (`-StoreScreenshots`).
# In that mode the app never reaches Supabase and shows only demo people and events.
#
#   scripts/store-screenshots.sh
#
# Writes store-assets/screenshots/<size>/NN-name.png as RGB PNGs with no alpha, each checked
# for exact pixel size. Simulators are created on first run:
#   iphone-6.9-1320x2868  "Yahpaz Store 6.9"  iPhone 17 Pro Max
#   iphone-6.5-1242x2688  "Yahpaz Store 6.5"  iPhone 11 Pro Max
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/store-assets/screenshots"
# Both device types exist only on the iOS 27.0 runtime with Xcode 27.1.
RUNTIME=com.apple.CoreSimulator.SimRuntime.iOS-27-0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

say() { print -r -- "▸ $*"; }

sim_udid() {
  local name=$1 type=$2 udid
  udid=$(xcrun simctl list devices | grep -F "$name (" | grep -oE '[0-9A-F-]{36}' | head -1 || true)
  if [[ -z $udid ]]; then
    udid=$(xcrun simctl create "$name" "com.apple.CoreSimulator.SimDeviceType.$type" "$RUNTIME")
  fi
  print -r -- "$udid"
}

capture() {
  local name=$1 type=$2 folder=$3 width=$4 height=$5 udid raw
  udid=$(sim_udid "$name" "$type")
  raw="$WORK/$folder"
  mkdir -p "$raw" "$OUT/$folder"
  say "$folder on $name ($udid)"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  # Fresh container: no fill drafts or stashes left over from an earlier run.
  xcrun simctl uninstall "$udid" com.yahpz.responder 2>/dev/null || true
  xcrun simctl status_bar "$udid" override --time 09:41 --dataNetwork wifi --wifiMode active \
    --wifiBars 3 --cellularMode active --cellularBars 4 --operatorName '' \
    --batteryState charged --batteryLevel 100
  # Diagnostics collection hangs xcodebuild for 10+ minutes after the test on Xcode 27.1.
  TEST_RUNNER_STORE_SHOTS_DIR="$raw" xcodebuild test -quiet \
    -project "$ROOT/Yahpaz.xcodeproj" -scheme Yahpaz -configuration Debug \
    -destination "id=$udid" -derivedDataPath "$ROOT/.derivedData" \
    -clonedSourcePackagesDirPath "$ROOT/.derivedData/SourcePackages" \
    -only-testing:YahpazUITests/StoreScreenshotTests -collect-test-diagnostics never
  "$WORK/flatten-png" "$width" "$height" "$OUT/$folder" "$raw"/*.png
}

xcodegen generate --spec "$ROOT/project.yml" --project "$ROOT" >/dev/null
swiftc -O "$ROOT/scripts/flatten-png.swift" -o "$WORK/flatten-png"
capture "Yahpaz Store 6.9" iPhone-17-Pro-Max iphone-6.9-1320x2868 1320 2868
capture "Yahpaz Store 6.5" iPhone-11-Pro-Max iphone-6.5-1242x2688 1242 2688
say "done: ${OUT#$ROOT/}"
