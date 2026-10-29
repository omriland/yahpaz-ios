# App Store readiness audit: אבן דרך 1.0.2 (17)

Run on 29 Oct 2026, branch `feat/appstore-submit-2026-10` (from `feat/android-parity-appstore`
@ `52788f9`), Xcode 27.1, xcodegen 2.46.0, iOS 27 simulators. `xcodegen generate` was run
before every check. Nothing was pushed, uploaded or signed.

## Verdict

The Release build is clean and store-shaped: unsigned archive at
`dist/Yahpaz-appstore-17.xcarchive`, no warnings in project code, launches to the login
screen. Since the second pass (brief 2, 29 Oct), it has no Ad Hoc update code and no bundled
trademark artwork. **What stands between this build and a submission is all outside this
repo:** signing access, the op-yh-26 deploy (demo isolation, `/support`, privacy policy), the
demo account it provisions, and the build-number confirmation (§8).

## 1. Checklist against code and `project.yml`

| Check | State | Evidence |
|---|---|---|
| Bundle ID | `com.yahpz.responder` | `project.yml` `PRODUCT_BUNDLE_IDENTIFIER`; archived Info.plist |
| Team | `477WWCHXU7`, automatic signing | `project.yml` `DEVELOPMENT_TEAM` |
| Marketing version | `1.0.2` | `MARKETING_VERSION` and the hard-coded `CFBundleShortVersionString` in `project.yml` `info.properties` (two places to bump next time) |
| Build number | **17** (was 16) | `CURRENT_PROJECT_VERSION`. 16 is what Ad Hoc phones run and what `yahpz.com/ios/version.json` has as `minBuild`/`latestBuild` (fetched today), so 17 passes the force-update gate. **Unconfirmed**: you are checking that nothing ≥ 17 was uploaded to App Store Connect before |
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
| Signed-in screens | Exercised on demo data via `-StoreScreenshots` (inbox, fill, contacts, map, profile, availability, feedback). Not exercised against production (no account) | `UITests/StoreScreenshotTests.swift` |
| Update path | App Store only: below `minBuild` the app shows the update screen, whose button opens `appStoreUrl` from version.json or the App Store app. No `itms-services`, no `LSApplicationQueriesSchemes`, no `embedded.mobileprovision` check | `App/API/AppUpdateCheck.swift`, `App/Screens/ForceUpdateView.swift`, archived binary |
| Third-party artwork | None bundled. Vehicle rows show a neutral `car.fill` symbol; the contacts message action shows a `message` symbol with the text וואטסאפ | `App/Components/VehicleMark.swift`, `App/Screens/ContactsView.swift` |
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

**Decided (29 Oct): off for the store.** The `yahpaz://` URL scheme stays registered; with
the flag off it does nothing.

## 3. Review risks, highest first

| # | Risk | Severity | State |
|---|---|---|---|
| 1 | **Demo account exposes real people.** Any active account sees all members' names, phones and emails (contacts) and saved home/work addresses (map), via `list_unit_contacts` / `list_unit_map_pins`. A lead account also sees real incidents | High (privacy, and App Review needs an account) | **Decided**: an App Review demo flag that limits a responder-only account to demo rows, plus a provisioning script, being built in op-yh-26 (`feat/app-review-demo`). Open until deployed and provisioned (REVIEW-NOTES.md) |
| 2 | Live tracking declared but not reachable | High | **Fixed** behind `LIVE_TRACKING` (§2) |
| 3 | Privacy policy does not mention photos/videos, voice notes, push token, app-version check-in (5.1.1(i)) | Medium | **Decided**: added on `feat/app-review-demo`; covered once deployed (URLS.md) |
| 4 | Ad Hoc OTA code in the binary (`itms-services`, `LSApplicationQueriesSchemes`, OTA install path) (2.5.2) | Low to medium | **Fixed**: removed completely (`d144cc5`, §5) |
| 5 | Support URL: `yahpz.com` is a login page with no contact details | Low to medium | **Decided**: `https://yahpz.com/support`, being added on `feat/app-review-demo`; live after deploy |
| 6 | Bundled third-party logos (47 car manufacturers, WhatsApp icon) and the Content Rights answer (5.2.1) | Low | **Fixed**: removed and replaced with generic SF Symbols (`33a97dc`); Content Rights: No |
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
| `745433e` | Store drafts in `store-assets/`; archive path now `dist/Yahpaz-appstore-<build>.xcarchive`; superseded notes on the old `docs/app-store` files |
| `d144cc5` | **Brief 2.** Ad Hoc OTA update path removed: optional-update sheet, `itms-services` install actions and fallback, `isStoreInstall` / `embedded.mobileprovision`, `itmsInstallHref` and `needsOptionalUpdate` (5 tests), `LSApplicationQueriesSchemes`, OTA URLs in Config; deleted `build-adhoc.sh`, `publish-ios.sh`, `publish-ios-batch.sh`, `export-options-adhoc.plist`, `docs/index.html`; README and xtool doc updated |
| `33a97dc` | 47 car-manufacturer logos and the WhatsApp icon deleted; `VehicleMark` (`car.fill`) and a `message` symbol with text label instead |
| `276473d` | Screenshots retaken: `04-contacts` replaces `04-my-shifts`; all 16 regenerated |
| this commit | Listing without משמרות / דוחות, support URL `/support`, demo-account notes, closed decisions |

The Release binary contains none of the demo code: no `StoreScreenshots`, `-StoreScreenshots`
or `127.0.0.1:9` in `strings` of the archived executable.

## 6. Verification run (final code, after brief 2)

| Check | Result |
|---|---|
| `swift test` | **421 passed**, 0 failed (426 before; the 5 removed tests covered the deleted OTA helpers) |
| Debug build, simulator | Succeeded, no warnings in project code |
| Clean Release build (`clean build`, fresh derived data, `generic/platform=iOS`, unsigned) | `** BUILD SUCCEEDED **`, no warnings in project code |
| `scripts/deploy-xtool.sh archive --unsigned` | `** ARCHIVE SUCCEEDED **`, refreshed `dist/Yahpaz-appstore-17.xcarchive`, 1.0.2 (17) |
| Release binary `strings` | 0 hits for `itms-services`, `mobileprovision`, `manifest.plist`, `isStoreInstall`, `OptionalUpdate`, `StoreScreenshots`, `127.0.0.1:9`, `CLLocationManager`, `requestAlwaysAuthorization`. `whatsapp` appears only as supabase-swift Auth enum values (an OTP channel) and the Swift property `onWhatsApp` |
| Archived bundle | No `car-logos`, no WhatsApp image; `Assets.car` holds only AccentColor, AppIcon, LaunchBackground; Info.plist has no `LSApplicationQueriesSchemes`, `UIBackgroundModes` or location keys |
| `scripts/store-screenshots.sh` | 8 screens × 2 sizes; every PNG exact size, RGB, no alpha (`sips`) |
| Release build, simulator | Launched to the login screen; the new `checkForceUpdate` read the live version.json (`minBuild` 16) and let build 17 through |
| First pass only (not repeated) | Build with `LIVE_TRACKING` on |

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

## 8. Decisions and what is left

**Decided on 29 Oct (09:21) and done here:**

| Question | Decision | Where |
|---|---|---|
| Demo account | App Review demo flag + responder-only demo account | op-yh-26 `feat/app-review-demo` (other session); REVIEW-NOTES.md |
| Ad Hoc OTA code | Remove completely | `d144cc5` |
| Privacy policy text | Add photos/videos, voice notes, push token, app-version check-in | op-yh-26 `feat/app-review-demo` |
| Support URL | `https://yahpz.com/support` | op-yh-26 `feat/app-review-demo`; ASC-FILL.md, URLS.md |
| Logos | Replace with generic artwork | `33a97dc` |
| Live tracking | Off | `d1eb993` |
| Listing | No משמרות / דוחות in any field | LISTING.md (counts rechecked by script) |

**Still yours, in order:**

1. **Approve and deploy op-yh-26 `feat/app-review-demo`**: migration and functions (demo
   flag), the site (`/support`, privacy policy). Then check `/support` and `/privacy` logged out
   (URLS.md).
2. **Provision the demo account** with that branch's script, sign in on a phone and run the
   checklist in REVIEW-NOTES.md.
3. **Confirm build 17** was never uploaded before (unconfirmed).
4. **Signing** (§7), then archive → validate → upload, then ASC-FILL.md.
5. **After launch**, in `op-yh-26/public/ios/version.json`: add
   `"appStoreUrl": "https://apps.apple.com/app/id<APP_ID>"`, and say "App Store" in `messageHe`
   if you like (today it says "יש להוריד ולהתקין"). Raise `minBuild` only when the App Store
   serves that build.
6. **Ad Hoc phones still on build 16** keep their old OTA update screen. When `minBuild` goes
   above 16, that screen opens the `itms-services` link built from version.json's
   `manifestUrl`, and opens `https://yahpz.com/ios` instead only when `manifestUrl` is not a
   yahpz.com `.plist`. To move them to the App Store: set `"manifestUrl": "https://yahpz.com/ios"`
   in version.json, make that page link to the App Store, and stop publishing
   `manifest.plist`/`Yahpaz.ipa` (all web-repo changes).

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
- Every signed-in screenshot with the tab bar shows its real label **המשמרות שלי** (the
  responder tab bar is האירועים שלי · המשמרות שלי · אנשי קשר · עוד). That is the actual UI, so it
  was not altered; no screenshot shows a shifts screen. Login, availability and feedback
  cover the tab bar.
- `AppIcon76x76@2x~ipad.png` is generated into the iPhone-only bundle by the universal icon
  slot. Harmless.
- While this pass ran, another process wrote and then deleted
  `store-assets/.asc-shots/asc1.png` (a Chrome screenshot of the App Store Connect login page,
  with calendar notifications visible). It was not mine and was never committed.
