# App Privacy (nutrition label)

App Store Connect → App Privacy → Get Started. Derived from the code of build 1.0.2 (17) and
kept identical to `App/Resources/PrivacyInfo.xcprivacy` (9 collected types, tracking off).

## Third-party code in the binary

| Package | Version | What it does | Data it sends anywhere else |
|---|---|---|---|
| supabase-swift (with swift-crypto, swift-asn1, swift-http-types, swift-clocks, swift-concurrency-extras, xctest-dynamic-overlay) | 2.55.1 | Auth, database, storage client for the app's own Supabase project | None. It talks only to `rtvizpsfvtjowbimugns.supabase.co` |

**No analytics, no PostHog, no crash reporter, no ad SDK** in the iOS app.
`Yahpaz.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` lists every
package; none of them collects data on its own. (The web app's PostHog is not in the iOS
binary.) Apple frameworks used: MapKit (address search goes to Apple and is not stored by us),
Vision (plate reading runs on the device), AVFoundation, PhotosUI, UserNotifications, WebKit.

## Answers

- Do you or your third-party partners collect data from this app? **Yes**
- Is the data used to track users? **No** (manifest: `NSPrivacyTracking` false, no tracking domains)

For **every** type below: **Linked to the user's identity: Yes**, **Used for tracking: No**,
**Purpose: App Functionality** only.

| Category → type | What exactly | Proof in code |
|---|---|---|
| Contact Info → **Name** | Full name and callsign on the profile; admins enter names when inviting or editing members | `App/API/YahpazAPI.swift:278` (`loadProfile`), `:2146` (`inviteAdminUser`), `:2236` (`saveAdminUser`) |
| Contact Info → **Email Address** | Sign-in email, invites, password reset | `App/API/YahpazAPI.swift:124` (`signIn`), `:2146` |
| Contact Info → **Phone Number** | Member phone on the profile, entered by admins | `App/API/YahpazAPI.swift:278`, `:2236` |
| Identifiers → **User ID** | Supabase account id, keys every row | `App/API/YahpazAPI.swift:113` (`sessionUserId`) |
| User Content → **Photos or Videos** | Event photos on the fill screen (bucket `event-media`); screenshots or short videos attached to feedback (bucket `user-feedback`) | `App/API/YahpazAPI.swift:1790`, `:1810` (`uploadEventMedia`); `:2412`, `:2443` (`submitUserFeedback`); `App/Screens/FillMediaTab.swift:96` (`PhotosPicker`) |
| User Content → **Audio Data** | Optional voice note in the feedback sheet | `App/Screens/FeedbackSheet.swift:292`, `:308` (`AVAudioRecorder`); uploaded in `submitUserFeedback` |
| User Content → **Customer Support** | Bug or suggestion text sent from the feedback sheet | `App/API/YahpazAPI.swift:2412` (`submitUserFeedback`) |
| User Content → **Other User Content** | Event and shift records: vehicle plate, odometer, route, treatment notes, treated plates; the member's own vehicles; availability | `App/API/YahpazAPI.swift:1610` (`saveFill`), `:591` (`createUnitEvent`), `:1367`/`:1408` (shifts), `:1965` (vehicles), `:1922` (`saveAvailability`) |
| Usage Data → **Product Interaction** | On app open, the build number, version and last-seen time are written to the member's profile so admins can see who still needs to update | `App/AppModel.swift` `reportSessionIfDue` → `App/API/YahpazAPI.swift:218` → RPC `report_android_session` (`Sources/YahpazDomain/SessionReport.swift:7`) |

## Not collected (and why)

| Type | Why not |
|---|---|
| **Precise / Coarse Location** | Live tracking is compiled out of this build (`LIVE_TRACKING` off), so nothing reads the device location and Info.plist has no location strings. Event locations are typed or searched place names of the incident, not the user's position; they are part of Other User Content. **If live tracking is turned back on, add Precise Location here and in the manifest.** |
| Physical Address | The iOS app shows members' saved addresses (map, admin screen) but never writes them; addresses are entered on the web |
| Contacts | The address book is never accessed. The contacts tab lists unit members from the server |
| Device ID | The APNs push token is stored with the account (`upsert_device_token`) only to deliver notifications. Apple's Device ID type refers to device-level identifiers such as the advertising ID; a push token is app-scoped. Declare it if you prefer the stricter reading |
| Crash Data, Performance Data, Other Diagnostic Data | No crash or performance SDK. Apple's own opt-in crash reports do not count |
| Search History, Browsing History | Map address search goes to Apple's MapKit and is not stored by the app |
| Health, Fitness, Financial Info, Sensitive Info, Purchases, Advertising Data | Not handled |

## Required-reason APIs (manifest only, not part of the label)

`NSPrivacyAccessedAPICategoryUserDefaults` `CA92.1` (drafts, settings, push token) and
`NSPrivacyAccessedAPICategoryFileTimestamp` `C617.1` (size of the recorded voice note,
`App/Screens/FeedbackSheet.swift`; also covers `attributesOfItem` in Supabase Storage's
multipart upload). No other required-reason API is used by the app or by supabase-swift.
