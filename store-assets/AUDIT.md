# App Store readiness audit: אבן דרך 1.0.2 (17)

Run on 29 Oct 2026, branch `feat/appstore-submit-2026-10` (from `feat/android-parity-appstore`
@ `52788f9`), Xcode 27.1, xcodegen 2.46.0, iOS 27 simulators. `xcodegen generate` was run
before every check. Nothing was pushed, uploaded or signed.

## Verdict

The Release build is clean and store-shaped: unsigned archive at
`dist/Yahpaz-appstore-17.xcarchive`, no warnings in project code, launches to the login
screen. **Three things stand between this build and a submission, and all three are yours:**
signing access, a demo account that does not expose real people, and the open questions
at the end.

## 1. Checklist against code and `project.yml`

| Check | State | Evidence |
|---|---|---|
| Bundle ID | `com.yahpz.responder` | `project.yml` `PRODUCT_BUNDLE_IDENTIFIER`; archived Info.plist |
| Team | `477WWCHXU7`, automatic signing | `project.yml` `DEVELOPMENT_TEAM` |
| Marketing version | `1.0.2` | `MARKETING_VERSION` and the hard-coded `CFBundleShortVersionString` in `project.yml` `info.properties` (two places to bump next time) |
| Build number | **17** (was 16) | `CURRENT_PROJECT_VERSION`. 16 is what Ad Hoc phones run and what `yahpz.com/ios/version.json` has as `minBuild`/`latestBuild` (fetched today), so 17 passes the force-update gate. If any build ≥ 17 was ever uploaded to App Store Connect, pick a higher one |
| Devices / OS | iPhone only (`UIDeviceFamily` [1]), iOS 17.0+, portrait | archived Info.plist |
| App icon | 1024×1024 PNG, RGB, **no alpha**, single-size catalog | `sips` on `App/Assets.xcassets/AppIcon.appiconset/AppIcon.png` |
| Launch screen | `UILaunchScreen` → colour `LaunchBackground` (exists in the asset catalog) | `project.yml`, `App/Assets.xcassets` |
| Camera string | `אבן דרך משתמש במצלמה לסריקת לוחית רישוי בעת תיעוד אירוע.` Accurate: the camera is used only by `PlateScanView` (AVCapture + on-device Vision) | `App/Screens/PlateScanView.swift` |
| Microphone string | `אבן דרך משתמש במיקרופון כדי להקליט הודעת משוב. אפשר לכתוב הערה במקום.` Accurate: only the feedback voice note records | `App/Screens/FeedbackSheet.swift:292,308` |
| Photos | `PhotosPicker` only, no string needed; nothing saves to the library | `FillMediaTab.swift`, `FeedbackSheet.swift` |
| Location strings | **Removed** (see §3). Nothing in the Release binary calls `CLLocationManager` | `strings`/`otool` on the archived binary |
| Background modes | **None** (was `location`) | archived Info.plist |
| `aps-environment` | `production` in `App/Yahpaz.entitlements` (Release), `development` in Debug | entitlements files. Applied at signing; the unsigned archive carries none |
| `ITSAppUsesNonExemptEncryption` | `false` (HTTPS only; supabase-swift uses swift-crypto for the PKCE SHA-256 hash in `Auth/Internal/PKCE.swift`, which is exempt) | archived Info.plist |
| Privacy manifest | Present in the bundle, tracking false, **9 collected types**, required-reason APIs `CA92.1` + `C617.1`. Matches the code and the only third-party SDK | `App/Resources/PrivacyInfo.xcprivacy`, `APP-PRIVACY.md` |
| Third-party SDKs | supabase-swift 2.55.1 and its dependencies only. **No analytics, PostHog, crash or ad SDK** | `Package.resolved` |
| Simulator launch | Debug and Release both launch, no crash, login screen renders (iPhone 17 Pro Max sim, iOS 27.0) | screenshots in this run |
| Signed-in screens | Exercised on demo data via `-StoreScreenshots` (inbox, fill, shifts, map, profile, availability, feedback). Not exercised against production (no account) | `UITests/StoreScreenshotTests.swift` |
| Placeholder screens | None reachable. `ComingSoonPage` (`App/Screens/ComingSoonViews.swift`) is defined but never used; left in place | `grep` |
| Dead buttons | None found: no empty button actions in `App/Screens` or `App/Components`, and every button tapped in the UI test did what its label says | `grep`, UI test |

## 2. Live tracking (מעקב חי / שיתוף מיקום): fact check

You said live tracking is not operational. That is consistent with the code:

**How build 16 exposed it.**

- Info.plist declared `NSLocationWhenInUseUsageDescription`,
  `NSLocationAlwaysAndWhenInUseUsageDescription` ("…ממשיך לשתף מיקום גם כשהמסך כבוי…") and
  `UIBackgroundModes: [location]`.
- `LocationTracker` (`App/Live/LocationTracker.swift`) asked for **Always** authorization,
  turned on background updates and the blue indicator, and pinged the `responder-track` edge
  function.
- `LiveTrackView` ("שיתוף מיקום") opened **only** from an incoming URL with `track_token=` or
  `token=` (`AppModel.applyIncomingURL`), as a full-screen cover over everything.
- **Nothing issues such a link to the iOS app.** The app registers only the `yahpaz://`
  scheme and has no associated-domains entitlement, so `https://yahpz.com/?track_token=…`
  links (the web SMS flow) open Safari's `LiveTrackPage`, never the app. No code in `op-yh-26`
  builds a `yahpaz://` link. No button in the app starts tracking. In practice the screen
  could not be reached.
- The מפה tab also reads `event_responder_live_locations` for "en route" pins. That is a read
  of other devices' data and shows nothing when nobody is tracking.

**Why it mattered for review.** App Review checks every declared background mode and asks to
see it work (guideline 2.5.4). An "Always" location prompt and a `location` background mode
with no reachable feature is a common rejection, and the old listing and reviewer notes
promised the feature.

**What I did** (commit `d1eb993`): a compile flag, `LIVE_TRACKING`, off by default.

- Off: `LocationTracker` is not compiled; `LiveTrackView` is an empty stub so `RootView`
  compiles unchanged; `applyIncomingURL` ignores track tokens; both location strings and the
  background mode are gone from `project.yml`/Info.plist; Precise Location is gone from the
  privacy manifest. The Release binary has no `CLLocationManager`, `requestAlwaysAuthorization`
  or `allowsBackgroundLocationUpdates` (checked with `strings`).
- On: add `LIVE_TRACKING` to `SWIFT_ACTIVE_COMPILATION_CONDITIONS` in `project.yml`, restore
  the two strings and the background mode (comment in `project.yml` lists them) and Precise
  Location in the manifest, and add `.define("LIVE_TRACKING")` to `xtool/Package.swift` for
  xtool builds. Checked: the app target still builds with the flag on.
- No visible behaviour changes for users, because the screen was unreachable.

**Your decision:** keep it off for the store (recommended), or ship it on and own the 2.5.4
review conversation. The `yahpaz://` URL scheme stays registered either way; with the flag off
it does nothing.

## 3. Review risks, highest first

| # | Risk | Severity | State |
|---|---|---|---|
| 1 | **Demo account exposes real people.** Any active account sees all members' names, phones and emails (contacts) and saved home/work addresses (map), via `list_unit_contacts` / `list_unit_map_pins`. A lead account also sees real incidents | High (privacy, and App Review needs an account) | Open question 1 |
| 2 | Live tracking declared but not reachable | High | **Fixed** behind `LIVE_TRACKING` (§2) |
| 3 | Privacy policy does not mention photos/videos, voice notes, push token, app version heartbeat (5.1.1(i)) | Medium | Open question 3 (web repo) |
| 4 | Ad Hoc OTA code still in the binary: `itms-services` in `LSApplicationQueriesSchemes` and the install path in `AppUpdateCheck.swift`/`ForceUpdateView.swift`. Store installs never reach it (`isStoreInstall()` is true without `embedded.mobileprovision`, so App Review's build shows only the App Store update path), but a reviewer reading the plist may ask (2.5.2) | Low to medium | Open question 2 |
| 5 | Support URL: `yahpz.com` is a login page with no contact details | Low to medium | Use `/privacy` for now (URLS.md); open question 4 |
| 6 | Bundled third-party logos (car manufacturers in `car-logos/`, WhatsApp icon) and the Content Rights answer (5.2.1) | Low | Store screenshots use a neutral demo vehicle with no logo. Open question 5 |
| 7 | Account deletion (5.1.1(v)): no in-app path | Low | Accounts are admin-created, no sign-up; reviewer notes cite `yahpz.com/delete-data` |
| 8 | Status bar clock renders dark on navy on login and force-update (`.preferredColorScheme(.light)` wins over `UIStatusBarStyleLightContent`) | Cosmetic | Not changed; visible in `01-login.png` |

## 4. HMAC secret in `App/Config.swift` (note only)

`privacyPageSecret` is compiled into the app and becomes public with the first store binary
(anyone can run `strings`). Today it only mints the `?t=` token for the embedded privacy page,
and that page is public anyway, so the impact is low. Do not reuse that secret for anything
else, and treat it as public from now on. Moving token minting server-side removes the issue.
The Supabase anon key next to it is public by design.

## 5. Changes in this pass

| Commit | What |
|---|---|
| `d1eb993` | `LIVE_TRACKING` flag; location strings, background mode and Precise Location removed; manifest adds Customer Support and Product Interaction; build 17 |
| `66b0aa9` | DEBUG-only `-StoreScreenshots` demo mode (`App/Debug/StoreScreenshots.swift`, one early return per volunteer read in `YahpazAPI`, no update check or push prompt in that mode, Supabase pointed at `127.0.0.1:9`); `StoreScreenshotTests`; `scripts/store-screenshots.sh` and `scripts/flatten-png.swift`; the 16 PNGs |
| this commit | Store drafts in `store-assets/`; archive path now `dist/Yahpaz-appstore-<build>.xcarchive`; superseded notes on the old `docs/app-store` files |

The Release binary contains none of the demo code: no `StoreScreenshots`, `-StoreScreenshots`
or `127.0.0.1:9` in `strings` of the archived executable.

## 6. Verification run (final code)

| Check | Result |
|---|---|
| `swift test` | 426 passed, 0 failed |
| Debug build, simulator | Succeeded, no warnings in project code |
| Release build, simulator | Succeeded, launched, login screen |
| Build with `LIVE_TRACKING` on (temporarily, then reverted) | Succeeded |
| `scripts/deploy-xtool.sh archive --unsigned` | `** ARCHIVE SUCCEEDED **`, `dist/Yahpaz-appstore-17.xcarchive`, 1.0.2 (17), iOS 17.0+, iPhone, no location keys, manifest bundled |
| `scripts/store-screenshots.sh` | 8 screens × 2 sizes; every PNG exact size, RGB, no alpha (`sips`) |

Tooling note: on Xcode 27.1, `xcodebuild test` hung for more than 10 minutes after the test
passed, collecting simulator diagnostics. The screenshot script passes
`-collect-test-diagnostics never` and writes PNGs straight to disk, so it does not depend on
the result bundle.

## 7. Signing and archive

| Item | State on this Mac |
|---|---|
| Code-signing identities | **0** (`security find-identity -v -p codesigning`) |
| Xcode accounts | none signed in (not attempted) |
| Provisioning profiles | none |
| ASC API key (`ASC_KEY_ID`/`ASC_ISSUER_ID`/`ASC_KEY_PATH`) | not set |
| Archive produced | `dist/Yahpaz-appstore-17.xcarchive`, **unsigned** (`CODE_SIGNING_ALLOWED=NO`). It proves the Release build; it cannot be exported or uploaded |

**What a signed archive and upload need, in order:**

1. Paid Apple Developer Program membership on team `477WWCHXU7`, agreements accepted, and the
   App Store Connect app record for `com.yahpz.responder`.
2. A way for Xcode to sign: either sign in to Xcode → Settings → Accounts with the team's
   Apple ID, or create an App Store Connect **Team API key** with the Admin role (or App
   Manager with access to Certificates, Identifiers & Profiles), keep the `.p8` outside the
   repo, and export `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`.
3. An Apple Distribution certificate and an App Store profile for `com.yahpz.responder` with
   Push Notifications. Automatic signing creates both on the first signed archive
   (`-allowProvisioningUpdates`). Run it yourself the first time so you see what it creates.
4. `scripts/deploy-xtool.sh archive` (signed, exports `dist/appstore/Yahpaz.ipa`) →
   `scripts/deploy-xtool.sh validate` → `YAHPAZ_ALLOW_UPLOAD=1 scripts/deploy-xtool.sh upload --confirm-upload`.

## 8. Open questions for Omri

1. **Demo account for App Review.** The old test account (`yahpz-onboarding-video/.test-login.env`,
   deleted after the video) is not suitable: it is probably a lead, and any account sees real
   members' contacts and addresses. Options: (a) a new responder-only "App Review דמו" account
   on demo events, plus a server-side rule so the contacts and map-pin RPCs return only demo
   rows for that account (change in `op-yh-26`, recommended); (b) the same account without the
   server rule, accepting that App Review sees real names, phones and addresses (not
   recommended). Which one?
2. **Ad Hoc OTA code in the store binary.** Keep it (store installs never see it), or compile
   it out of store builds with a second flag (Ad Hoc builds would then set that flag)?
3. **Privacy policy text** (`op-yh-26/src/lib/privacyPolicy.ts`): add photos and videos,
   voice notes, the push token and the app-version heartbeat? A few lines in section 2.1.
4. **Support URL.** Use `https://yahpz.com/privacy` (has contact details), or add a small
   public `/support` page to the web app?
5. **Content Rights and logos.** The app bundles 47 car-manufacturer logos and a WhatsApp
   icon. Answer Content Rights as nominative use, or remove or replace the logos?
6. **Live tracking flag.** Off for the store (done), or ship it on? See §2.
7. **Build number.** 17 assumes nothing ≥ 17 was uploaded to App Store Connect before. Correct?

## 9. Noticed, not changed

- `report_android_session` is the RPC iOS uses for its heartbeat, so **iOS sessions are written
  into `last_android_seen_at` / `last_android_version_*`**. Admin views cannot tell iOS from
  Android. Data quality, not a store issue.
- **Login OTP is enforced only by the web client.** No RLS policy uses `otp_login_enabled`,
  and the iOS app has no OTP step, so a member with login OTP on can sign in on iOS with just
  the password. Security note for the web and iOS backlog.
- `googleMapsApiKey` is empty, so Google place suggestions in the leads' event form fail
  silently over to the highway-junction search and free text. Leads only.
- The fill screen shows "נשמר אוטומטית במכשיר HH:MM" with the real clock, so `03-complete-my-part.png`
  shows a time that differs from the 09:41 status bar. Cosmetic.
- `AppIcon76x76@2x~ipad.png` is generated into the iPhone-only bundle by the universal icon
  slot. Harmless.
- While this pass ran, another process wrote and then deleted
  `store-assets/.asc-shots/asc1.png` (a Chrome screenshot of the App Store Connect login page,
  with calendar notifications visible). It was not mine and was never committed.
