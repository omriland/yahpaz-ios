#!/bin/zsh
# Build, sign and deploy אבן דרך from the command line.
#
#   xtool   → dev builds: iOS Simulator and a USB/Wi-Fi iPhone (SwiftPM wrapper in xtool/)
#   Xcode   → App Store: archive, export, validate, upload (xtool has no store signing or upload)
#
# Every command accepts --dry-run: it prints what would run and touches nothing.
# Secrets never pass through this script's output: the App Store Connect key is read
# from the environment and only ever referred to by variable name. See docs/xtool-deploy.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
XT="$ROOT/xtool"
GEN="$XT/.generated"
DIST="$ROOT/dist"
EXPORT_DIR="$DIST/appstore"
SCHEME=Yahpaz
TEAM=477WWCHXU7
BUNDLE_ID=com.yahpz.responder

DRY_RUN=0
UNSIGNED=0
CONFIRM_UPLOAD=0
SIM_UDID=""
DEVICE_UDID=""

usage() {
  cat <<'USAGE'
Usage: scripts/deploy-xtool.sh <command> [--dry-run] [options]

Dev (xtool):
  doctor              Check tools, simulator runtime, xtool login, ASC key variables
  setup               xtool one-time setup check (login itself is interactive: run by Omri)
  sim [--udid ID]     Build with xtool, install and launch on a booted simulator
  device [--udid ID]  Build with xtool, sign, install and launch on a connected iPhone

App Store (Xcode):
  archive             Release archive + App Store .ipa export to dist/appstore (no upload)
  archive --unsigned  Release archive with signing off: proves it builds, touches no account
  validate            Validate the exported .ipa with App Store Connect (needs ASC key)
  upload --confirm-upload
                      Upload the exported .ipa to App Store Connect / TestFlight.
                      Also requires YAHPAZ_ALLOW_UPLOAD=1 in the environment.

Options:
  --dry-run           Print the commands instead of running them
  --udid ID           Pick a simulator / device instead of the first one

ASC key (validate / upload / archive provisioning), set by Omri, never committed:
  ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH (absolute path to AuthKey_<id>.p8)
USAGE
}

say() { print -r -- "▸ $*"; }
fail() { print -r -- "✗ $*" >&2; exit 1; }

# Run a command, or print it under --dry-run. Arguments are printed as given, so callers
# pass the ASC key only as "$ASC_KEY_ID"-style variable references through `run_secret`.
run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    print -r -- "[dry-run] ${(q)@}"
  else
    "$@"
  fi
}

# Same as run, but the printed form keeps the key variables unexpanded.
run_secret() {
  local printable="$1"
  shift
  if [[ $DRY_RUN -eq 1 ]]; then
    print -r -- "[dry-run] $printable"
  else
    "$@"
  fi
}

project_build_number() {
  awk '/CURRENT_PROJECT_VERSION:/ {print $2; exit}' "$ROOT/project.yml"
}

require_asc_key() {
  local missing=()
  [[ -n "${ASC_KEY_ID:-}" ]] || missing+=(ASC_KEY_ID)
  [[ -n "${ASC_ISSUER_ID:-}" ]] || missing+=(ASC_ISSUER_ID)
  [[ -n "${ASC_KEY_PATH:-}" ]] || missing+=(ASC_KEY_PATH)
  if (( ${#missing} )); then
    [[ $DRY_RUN -eq 1 ]] && { say "would need: ${missing[*]} (not set)"; return 0; }
    fail "set ${missing[*]} first (Omri's App Store Connect API key; see docs/xtool-deploy.md)"
  fi
  if [[ $DRY_RUN -eq 0 && ! -f "$ASC_KEY_PATH" ]]; then
    fail "ASC_KEY_PATH does not point at a file"
  fi
  case "$ASC_KEY_PATH" in
    "$ROOT"/*) fail "keep the .p8 outside the repo (ASC_KEY_PATH points inside it)" ;;
  esac
}

# ---------------------------------------------------------------- xtool inputs

# xtool merges a partial Info.plist into its own. App/Info.plist uses Xcode build
# variables, so drop the keys xtool owns and pin the build number from project.yml.
generate_xtool_inputs() {
  local platform="$1"
  run mkdir -p "$GEN"
  run cp "$ROOT/App/Info.plist" "$GEN/Info.plist"
  local key
  for key in CFBundleExecutable CFBundleIdentifier CFBundlePackageType CFBundleInfoDictionaryVersion; do
    run /usr/libexec/PlistBuddy -c "Delete :$key" "$GEN/Info.plist"
  done
  run /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(project_build_number)" "$GEN/Info.plist"
  run /usr/libexec/PlistBuddy -c "Add :UIDeviceFamily array" -c "Add :UIDeviceFamily:0 integer 1" "$GEN/Info.plist"
  # SwiftPM does not compile asset catalogs for the app bundle; actool does.
  run xcrun actool "$ROOT/App/Assets.xcassets" --compile "$GEN" --platform "$platform" \
    --minimum-deployment-target 17.0 --app-icon AppIcon \
    --output-partial-info-plist "$GEN/assets-partial.plist" --output-format human-readable-text
  # Same package pins as the Xcode project.
  run cp "$ROOT/Yahpaz.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" "$XT/Package.resolved"
}

# xtool 1.22 expects a resource bundle for every target that declares resources, even
# targets SwiftPM only builds on Linux (swift-crypto's CXKCP*/BoringSSL shims behind a
# platform condition). Swift Build skips them on Apple platforms, so packing fails with
# "<bundle> couldn't be opened". Stand in an empty bundle for each one it names.
xtool_with_bundle_workaround() {
  local products="$1"
  shift
  if [[ $DRY_RUN -eq 1 ]]; then
    print -r -- "[dry-run] (cd xtool && ${(q)@})  # retried with placeholder bundles for Linux-only swift-crypto targets"
    return 0
  fi
  local attempt out missing bundle
  for attempt in {1..12}; do
    if out=$(cd "$XT" && "$@" 2>&1); then
      print -r -- "$out" | tail -5
      return 0
    fi
    missing=$(print -r -- "$out" | sed -n 's/.*The file “\(.*\.bundle\)” couldn’t be opened.*/\1/p' | head -1)
    if [[ -z "$missing" ]]; then
      print -r -- "$out" | tail -40 >&2
      return 1
    fi
    say "placeholder for $missing (xtool platform-condition bug)"
    bundle="$XT/.build/out/Products/$products/$missing"
    mkdir -p "$bundle"
    [[ -f "$bundle/Info.plist" ]] || /usr/libexec/PlistBuddy \
      -c "Add :CFBundleIdentifier string org.swift.placeholder.${missing%.bundle}" \
      -c "Add :CFBundlePackageType string BNDL" "$bundle/Info.plist" >/dev/null
  done
  fail "xtool kept failing after placeholder bundles"
}

require_xtool() {
  command -v xtool >/dev/null || fail "xtool is not installed: brew install xtool-org/tap/xtool"
}

# ---------------------------------------------------------------- commands

cmd_doctor() {
  say "Xcode: $(xcodebuild -version | head -1)"
  say "xtool: $(command -v xtool >/dev/null && xtool --version || print 'missing — brew install xtool-org/tap/xtool')"
  say "xcodegen: $(command -v xcodegen >/dev/null && xcodegen --version || print 'missing — brew install xcodegen')"
  local runtimes
  runtimes=$(xcrun simctl list runtimes 2>/dev/null | grep -c 'iOS ' || true)
  say "iOS simulator runtimes: $runtimes"
  [[ "$runtimes" == 0 ]] && say "  install one: xcodebuild -downloadPlatform iOS"
  if command -v xtool >/dev/null; then
    say "xtool login: $(xtool auth status 2>&1 | head -1)"
  fi
  local name
  for name in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH; do
    if [[ -n "${(P)name:-}" ]]; then say "$name: set"; else say "$name: not set"; fi
  done
  say "build number (project.yml): $(project_build_number)"
}

cmd_setup() {
  require_xtool
  say "xtool sdk: $(xtool sdk status 2>&1 | head -1) (macOS uses Xcode's SDK; nothing to install)"
  local login_state
  login_state=$(xtool auth status 2>&1 | head -1)
  say "xtool login: $login_state"
  if [[ "$login_state" == "Logged out" ]]; then
    cat <<'STEP'

  Omri's step (interactive, needs the Apple Developer account):
    xtool auth login
  Pick "API Key" (paid program): Team Key with the App Manager role from
  App Store Connect → Users and Access → Integrations. Simulator builds work without it.
STEP
  fi
}

cmd_sim() {
  require_xtool
  generate_xtool_inputs iphonesimulator
  xtool_with_bundle_workaround Debug-iphonesimulator xtool dev build --triple arm64-apple-ios-simulator
  local udid="$SIM_UDID"
  if [[ -z "$udid" ]]; then
    udid=$(xcrun simctl list devices booted | sed -n 's/.*(\([0-9A-F-]\{36\}\)) (Booted).*/\1/p' | head -1)
  fi
  if [[ -z "$udid" ]]; then
    udid=$(xcrun simctl list devices available | grep -E 'iPhone' | sed -n 's/.*(\([0-9A-F-]\{36\}\)).*/\1/p' | head -1)
    [[ -n "$udid" ]] || fail "no iPhone simulator; run: xcodebuild -downloadPlatform iOS"
    run xcrun simctl boot "$udid"
  fi
  run xcrun simctl install "$udid" "$XT/xtool/Yahpaz.app"
  run xcrun simctl launch "$udid" "$BUNDLE_ID"
  say "running on simulator $udid"
}

cmd_device() {
  require_xtool
  if [[ $DRY_RUN -eq 0 && "$(xtool auth status 2>&1 | head -1)" == "Logged out" ]]; then
    fail "device builds need xtool signing. Omri: run 'xtool auth login' once (see setup)"
  fi
  generate_xtool_inputs iphoneos
  # xtool signs with a development profile under a team-prefixed bundle ID (XTL-…),
  # so this installs beside the App Store build instead of replacing it.
  local args=(xtool dev run)
  [[ -n "$DEVICE_UDID" ]] && args+=(--udid "$DEVICE_UDID")
  xtool_with_bundle_workaround Debug-iphoneos "${args[@]}"
}

cmd_archive() {
  local build
  build=$(project_build_number)
  local ARCHIVE="$DIST/Yahpaz-appstore-$build.xcarchive"
  run xcodegen generate --spec "$ROOT/project.yml" --project "$ROOT"
  run rm -rf "$ARCHIVE" "$EXPORT_DIR"
  run mkdir -p "$DIST"
  if [[ $UNSIGNED -eq 1 ]]; then
    run xcodebuild archive -project "$ROOT/Yahpaz.xcodeproj" -scheme "$SCHEME" -configuration Release \
      -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" CODE_SIGNING_ALLOWED=NO
    say "unsigned Release archive of build $build at ${ARCHIVE#$ROOT/} (not installable, not exportable)"
    return 0
  fi
  local auth=()
  local auth_print=""
  if [[ -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" && -n "${ASC_KEY_PATH:-}" ]]; then
    require_asc_key
    auth=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
    auth_print='-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID"'
  fi
  run_secret "xcodebuild archive -project Yahpaz.xcodeproj -scheme $SCHEME -configuration Release -destination generic/platform=iOS -archivePath ${ARCHIVE#$ROOT/} -allowProvisioningUpdates $auth_print" \
    xcodebuild archive -project "$ROOT/Yahpaz.xcodeproj" -scheme "$SCHEME" -configuration Release \
      -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" -allowProvisioningUpdates "${auth[@]}"
  # App Store signing, destination export: writes the .ipa, uploads nothing. Not the
  # -local plist: that one marks the build TestFlight-internal-only, which App Review refuses.
  run_secret "xcodebuild -exportArchive -archivePath ${ARCHIVE#$ROOT/} -exportOptionsPlist scripts/export-options-appstore-ipa.plist -exportPath ${EXPORT_DIR#$ROOT/} -allowProvisioningUpdates $auth_print" \
    xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$ROOT/scripts/export-options-appstore-ipa.plist" \
      -exportPath "$EXPORT_DIR" -allowProvisioningUpdates "${auth[@]}"
  say "App Store build $build exported to ${EXPORT_DIR#$ROOT/}/Yahpaz.ipa (not uploaded)"
}

exported_ipa() {
  local ipa="$EXPORT_DIR/Yahpaz.ipa"
  [[ $DRY_RUN -eq 1 || -f "$ipa" ]] || fail "no exported .ipa; run: scripts/deploy-xtool.sh archive"
  print -r -- "$ipa"
}

cmd_validate() {
  require_asc_key
  local ipa
  ipa=$(exported_ipa)
  # altool reads the key from ~/.appstoreconnect/private_keys or API_PRIVATE_KEYS_DIR.
  run_secret "API_PRIVATE_KEYS_DIR=\"\$(dirname \"\$ASC_KEY_PATH\")\" xcrun altool --validate-app -f ${ipa#$ROOT/} -t ios --apiKey \"\$ASC_KEY_ID\" --apiIssuer \"\$ASC_ISSUER_ID\"" \
    env API_PRIVATE_KEYS_DIR="$(dirname "${ASC_KEY_PATH:-/}")" \
      xcrun altool --validate-app -f "$ipa" -t ios --apiKey "${ASC_KEY_ID:-}" --apiIssuer "${ASC_ISSUER_ID:-}"
}

cmd_upload() {
  if [[ $CONFIRM_UPLOAD -ne 1 || "${YAHPAZ_ALLOW_UPLOAD:-}" != "1" ]]; then
    fail "upload needs both --confirm-upload and YAHPAZ_ALLOW_UPLOAD=1 (this sends the build to App Store Connect)"
  fi
  require_asc_key
  local ipa
  ipa=$(exported_ipa)
  run_secret "API_PRIVATE_KEYS_DIR=\"\$(dirname \"\$ASC_KEY_PATH\")\" xcrun altool --upload-app -f ${ipa#$ROOT/} -t ios --apiKey \"\$ASC_KEY_ID\" --apiIssuer \"\$ASC_ISSUER_ID\"" \
    env API_PRIVATE_KEYS_DIR="$(dirname "$ASC_KEY_PATH")" \
      xcrun altool --upload-app -f "$ipa" -t ios --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
}

# ---------------------------------------------------------------- main

[[ $# -ge 1 ]] || { usage; exit 1; }
COMMAND="$1"
shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --confirm-upload) CONFIRM_UPLOAD=1 ;;
    --unsigned) UNSIGNED=1 ;;
    --udid) shift; SIM_UDID="${1:-}"; DEVICE_UDID="${1:-}" ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
  shift
done

case "$COMMAND" in
  doctor) cmd_doctor ;;
  setup) cmd_setup ;;
  sim) cmd_sim ;;
  device) cmd_device ;;
  archive) cmd_archive ;;
  validate) cmd_validate ;;
  upload) cmd_upload ;;
  -h|--help|help) usage ;;
  *) usage; exit 1 ;;
esac
