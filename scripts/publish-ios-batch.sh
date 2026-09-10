#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]; then
  echo "ERROR: set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in the environment." >&2
  exit 1
fi

API="$SUPABASE_URL/rest/v1"
KEY="$SUPABASE_SERVICE_ROLE_KEY"
AUTH=( -H "apikey: $KEY" -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" )

echo "Fetching approved iOS devices…"
JSON=$(curl -fsS "${API}/ios_devices?status=eq.approved&select=id,udid,user_id,device_name" "${AUTH[@]}")
COUNT=$(/usr/bin/python3 -c "import json,sys; print(len(json.loads(sys.argv[1])))" "$JSON")
if [ "$COUNT" -eq 0 ]; then
  echo "No approved devices queued. Nothing to publish."
  exit 0
fi

echo ""
echo "Register these UDIDs in Apple Developer (Devices → register / bulk), then press Enter:"
/usr/bin/python3 -c "import json,sys
for row in json.loads(sys.argv[1]):
  print(row['udid'])
" "$JSON"
echo ""
read -r '?Continue after portal registration? '

"$ROOT/scripts/build-adhoc.sh"

WORK=$(mktemp -d)
LIVE_WORK=""
trap 'rm -rf "$WORK" ${LIVE_WORK:+"$LIVE_WORK"}' EXIT
unzip -qq "$ROOT/dist/adhoc/Yahpaz.ipa" -d "$WORK"
PROFILE="$WORK/Payload/Yahpaz.app/embedded.mobileprovision"
security cms -D -i "$PROFILE" > "$WORK/profile.plist"
DEVICES_PLIST=$(/usr/libexec/PlistBuddy -c 'Print :ProvisionedDevices' "$WORK/profile.plist" 2>/dev/null || true)

MISSING=0
while IFS= read -r udid; do
  [ -z "$udid" ] && continue
  if ! print -r -- "$DEVICES_PLIST" | grep -q -- "$udid"; then
    echo "ERROR: UDID $udid missing from embedded Ad Hoc profile." >&2
    MISSING=1
  fi
done < <(/usr/bin/python3 -c "import json,sys
for row in json.loads(sys.argv[1]):
  print(row['udid'])
" "$JSON")

if [ "$MISSING" -ne 0 ]; then
  exit 1
fi

"$ROOT/scripts/publish-ios.sh"

BUILD=$(/usr/bin/python3 -c "import json; print(json.load(open('${YAHPAZ_WEB:-/Users/omrilandman/CursorProjects/today-i/op-yh-26}/public/ios/version.json'))['latestBuild'])")

# CRITICAL ORDER: emails must not go out until https://yahpz.com serves this IPA.
# Local publish-ios.sh only copies into the web repo — production needs a deploy/push first.
echo ""
echo "Deploy public/ios to production (commit+push infra/bootstrap, or Netlify prod deploy),"
echo "then press Enter so we can verify the LIVE IPA before emailing anyone."
read -r '?Continue after yahpz.com has the new IPA? '

echo "Verifying live IPA at https://yahpz.com/ios/Yahpaz.ipa …"
LIVE_WORK=$(mktemp -d)
curl -fsSL -o "$LIVE_WORK/Yahpaz.ipa" "https://yahpz.com/ios/Yahpaz.ipa?ts=$(date +%s)"
unzip -qq "$LIVE_WORK/Yahpaz.ipa" -d "$LIVE_WORK/out"
security cms -D -i "$LIVE_WORK/out/Payload/Yahpaz.app/embedded.mobileprovision" > "$LIVE_WORK/profile.plist"
LIVE_DEVICES=$(/usr/libexec/PlistBuddy -c 'Print :ProvisionedDevices' "$LIVE_WORK/profile.plist" 2>/dev/null || true)

LIVE_MISSING=0
while IFS= read -r udid; do
  [ -z "$udid" ] && continue
  if ! print -r -- "$LIVE_DEVICES" | grep -q -- "$udid"; then
    echo "ERROR: live yahpz.com IPA is missing UDID $udid — NOT emailing." >&2
    LIVE_MISSING=1
  fi
done < <(/usr/bin/python3 -c "import json,sys
for row in json.loads(sys.argv[1]):
  print(row['udid'])
" "$JSON")

if [ "$LIVE_MISSING" -ne 0 ]; then
  echo "Fix production deploy and re-run. Emails were not sent; devices stay approved." >&2
  exit 1
fi
echo "✅ Live IPA includes all batch UDIDs. Sending email…"

EMAIL_FAILS=()
while IFS=$'\t' read -r id uid; do
  [ -z "$id" ] && continue
  BODY=$(/usr/bin/python3 - <<PY
import json
print(json.dumps({
  "user_id": "$uid",
  "subject": "האפליקציה מוכנה להתקנה באייפון",
  "html": "<p>המכשיר שלכם אושר וגרסה חדשה מוכנה להתקנה.</p><p><a href=\"https://yahpz.com/ios\">להתקנה מ‑Safari</a></p>",
  "idempotency_key": f"ios-ready-$id-$BUILD",
}))
PY
)
  if ! curl -fsS -X POST "$SUPABASE_URL/functions/v1/send-email" \
    -H "Authorization: Bearer $KEY" \
    -H "apikey: $KEY" \
    -H "Content-Type: application/json" \
    -d "$BODY" >/dev/null; then
    EMAIL_FAILS+=("$uid")
  fi

  NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  curl -fsS -X PATCH "${API}/ios_devices?id=eq.${id}" \
    "${AUTH[@]}" \
    -H "Prefer: return=minimal" \
    -d "{\"status\":\"registered\",\"registered_at\":\"$NOW\"}" >/dev/null
done < <(/usr/bin/python3 -c "import json,sys
for row in json.loads(sys.argv[1]):
  print(row['id'] + '\t' + row['user_id'])
" "$JSON")

echo "✅ Batch live + emailed (build $BUILD). Marked $COUNT device(s) registered."
if [ "${#EMAIL_FAILS[@]}" -gt 0 ]; then
  echo "WARNING: email failed for user_ids:" >&2
  print -l -- "${EMAIL_FAILS[@]}" >&2
fi
