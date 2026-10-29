# Handoff: Android parity, App Store readiness, xtool pipeline

Branch `feat/android-parity-appstore` (off `feat/android-parity` @ `7f00c62`). Local commits only:
nothing pushed, no PR touched, nothing uploaded to App Store Connect or TestFlight, nothing published
to yahpz.com.

## What changed

### 1. Android parity (0.3.26 → 0.3.47)

Full list with Android versions: [android-parity-gap.md](android-parity-gap.md). 28 items, all
ported. The ones that change behaviour most:

- **Event saves write only what changed** (Android 0.3.43). Before, every iOS save rewrote the whole
  `events` row, so a lead entering KM could null fields another device had just set. Now the event
  row, each assignment, treated vehicles and secondary leads are diffed against what was loaded.
- **Done-guard ordering** (0.3.42). The row is written as `partial`, responders and KM go in, then
  the event is promoted to `done`, so `guard_event_done_requirements` no longer 400s.
- **Same-day duplicate מספר אירוע refused** (0.3.41), and the field is capped at 5 digits.
- **Manual events held from responders** until מספר אירוע, כביש and או״ק number are filled
  (0.3.38/0.3.40); כביש and או״ק are no longer required to create the event.
- **7-day edit lock** for non-admins; owners and admins can delete an event even with responders,
  via the `delete_event` RPC (0.3.46).
- **Autosave everywhere Android has it**: event form (with leave-flush and a 24 h device stash for new
  events), shift form, fill (device + server), availability, profile vehicles.
- **מפה tab** for every signed-in user, on MapKit (no Google key): unit address pins with clustering,
  legend, police-station and mile-post layers, address search with nearby responders, and live
  en-route pins for leads.
- Responder stamps `סיימת לתעד` / `ממתין לפרטים נוספים מאחמש`, missing fields in red, lead KM hidden from
  responders, missing-photo prompt before a fill save, KM freeze threshold 80.

Where iOS deliberately does **not** copy Android: the fill no longer flips to `in_progress` just by
being opened, and a fast full create no longer re-stashes itself as a new draft. An independent code
review of the write path then found nine more problems that Android shares (one also on the web):
duplicate events from stale stashes and half-failed creates, lead KM wiped after a failed vehicle
lookup, autosave deleting assignments added elsewhere, `done` events not reopening when a responder
is added, interleaved fill and shift writes. All fixed on iOS; the table in the gap doc lists them for
Android.

### 2. App Store readiness

| Check | State |
|---|---|
| Bundle ID / team | `com.yahpz.responder`, team `477WWCHXU7`, automatic signing |
| Version | `MARKETING_VERSION` 1.0.2, `CURRENT_PROJECT_VERSION` 16 (bump before each upload) |
| Devices | iPhone only, iOS 17+, portrait |
| App icon | 1024×1024 PNG, no alpha, single-size catalog |
| Launch screen | `UILaunchScreen` with the `LaunchBackground` colour |
| Usage strings | Location (when in use + always), camera, microphone. Photos use `PhotosPicker` (no string needed); the map never requests location |
| Background mode | `location` only, used by live tracking |
| Encryption | `ITSAppUsesNonExemptEncryption = false` |
| Privacy manifest | Tracking off; 8 collected data types; required-reason APIs UserDefaults `CA92.1` and **file timestamp `C617.1` (added)** |
| Push | `aps-environment` production in Release, development in Debug |
| Store vs Ad Hoc updates | **Fixed.** Store installs (no embedded provisioning profile) never see the Ad Hoc `itms-services` OTA prompt; the forced-update screen opens the App Store instead |
| Warnings | The four `try?`-unused warnings fixed; the app target builds without warnings in our code |
| Archive | Release archive builds (`scripts/deploy-xtool.sh archive --unsigned`) |
| Validation | **Not run**: `altool --validate-app` needs the ASC key (Omri's step) |

`docs/app-store/CHECKLIST.md`, `CONNECT.md` and `LISTING.md` were brought up to date (version,
usage strings, privacy label now includes Photos or Videos and Audio Data).

### 3. xtool pipeline

`scripts/deploy-xtool.sh` + [xtool-deploy.md](xtool-deploy.md).

- **xtool 1.22.2 is installed** (`brew install xtool-org/tap/xtool`), plus xcodegen 2.46.0 and the
  iOS 27 simulator runtimes.
- **Dev builds run on xtool**: `scripts/deploy-xtool.sh sim` builds the app with xtool, installs and
  launches it in the simulator. Tested end to end on this machine.
- **xtool does not fit the store half**: it builds SwiftPM packages, signs with development profiles,
  and has no distribution signing or upload. So `archive` / `validate` / `upload` use Xcode
  (`xcodebuild`, `xcrun altool`). The project is not SwiftPM-shaped, so a thin wrapper in `xtool/`
  presents `App/` to xtool without changing the Xcode project.
- One xtool bug is worked around automatically (Linux-only swift-crypto resource bundles); details in
  the deploy doc. Worth filing upstream.
- Upload is double-gated (`--confirm-upload` and `YAHPAZ_ALLOW_UPLOAD=1`) and was never run.

## Verified

Run on this Mac (Xcode 27.1, iOS 27 simulators) on 22 Oct 2026, on the final commit unless noted:

| Check | Result |
|---|---|
| `swift test` (domain) | **426 passed**, 0 failed (382 before this branch) |
| App build, Debug, simulator | Succeeded, no warnings in project code |
| `scripts/deploy-xtool.sh sim` | xtool built, installed and launched the app in the iPhone 18 Pro simulator (about 30 s from clean) |
| `scripts/deploy-xtool.sh archive --unsigned` | Release archive succeeded, no warnings. Archived app: 1.0.2 (16), iOS 17+, iPhone/portrait, encryption exempt, privacy manifest and map layers bundled, arm64 |
| Other commands | `doctor` and `setup` run; `device`, `archive`, `validate` checked with `--dry-run`; `upload` refuses without both gates |
| UI tests (`UITests/`) | Full suite before the review fixes: 10 run, 1 passed (login typing), **9 skipped**, 0 failed. The sweeps skip unless the simulator is signed in to production, and I did not sign in. Login typing test re-run on the final code: passed |
| Code review | Independent review of the write path; its 3 critical, 5 important and 7 minor findings fixed in `37f81f5`, then everything above re-run on the final code |
| מפה tab | Checked in the simulator with sample pins through a throwaway harness (since removed): clusters zoom on tap, police boundaries toggle on, address search returns nearby responders within 30 km |

Not verified, because it needs a signed-in session or your credentials: every signed-in screen
against live data (inbox, event form autosave, fill, shifts), device install, App Store export,
validation, upload. The domain rules behind those screens are covered by the unit tests; the
screens themselves need a pass on a phone with a test account.

## What still needs Omri

1. **Apple Developer / App Store Connect access** (`docs/app-store/CONNECT.md` has the click list):
   paid membership active, agreements signed, app record `com.yahpz.responder` created.
2. **App Store Connect API key** (Team Key, App Manager role), stored outside the repo, then export
   `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH` in your shell. Needed for `validate`, `upload`, and
   for `xtool auth login` (choose "API Key").
3. **xtool device builds**: run `xtool auth login` once. Simulator builds need nothing.
4. **Distribution signing**: the first `scripts/deploy-xtool.sh archive` lets Xcode create the App
   Store provisioning profile (and an Apple Distribution certificate if the team has none). Run it
   yourself the first time so you see what it creates.
5. **Build number**: bump `CURRENT_PROJECT_VERSION` above anything uploaded before, `xcodegen generate`,
   then archive → validate → upload.
6. **After the app is live**, add `"appStoreUrl": "https://apps.apple.com/app/id<APP_ID>"` to
   `yahpz.com/ios/version.json` (web repo `op-yh-26/public/ios/version.json`). Until then the
   forced-update button on store installs opens the App Store app. Note that `minBuild` now gates
   store installs too, so raise it only when the App Store has that build.
7. **App Store Connect metadata**: screenshots (the 6.9" set in `docs/app-store/screenshots/` predates
   the מפה tab and the new form; retake if you want them current), description and keywords from
   `LISTING.md`, privacy nutrition label (now 8 types: add Photos or Videos and Audio Data), age
   rating, Israel-only availability, privacy policy URL `https://yahpz.com/privacy` (must load logged
   out).
8. **App Review demo account**: a responder (and ideally a shift lead) with no live incident data;
   paste into App Review Information. Reviewer notes are drafted in `CONNECT.md`.
9. **Review risk to decide on**: the binary still contains the Ad Hoc OTA update flow
   (`itms-services`, `LSApplicationQueriesSchemes`). Store installs never reach it, but a reviewer who
   finds it may ask. If you go store-only later, remove it. **Done 29 Oct 2026: removed; App Store only.**
10. **Android follow-ups** (not touched, repo is read only): the eleven Android problems listed in
    the gap doc. The `done`-not-reopening one also exists in the web form (`eventForm.ts`).

## Other things I noticed (not changed)

- `App/Config.swift` compiles the HMAC secret for the web `/privacy?t=` gate into the app. Anyone
  can pull strings out of a public App Store binary, so treat that secret as public once the app
  ships, or move the token minting server-side. (The Supabase anon key there is meant to be public.)
- On the dark login and force-update screens the status bar clock renders dark on navy, because
  `.preferredColorScheme(.light)` most likely wins over `UIStatusBarStyleLightContent` (not
  investigated). Cosmetic.
- The App Store screenshots in `docs/app-store/screenshots/` were rendered from HTML mock-ups
  (`screens.html`), not the running app. Apple accepts them, but they no longer show the current UI.
