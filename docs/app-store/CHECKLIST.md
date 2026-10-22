# Icon and privacy checklist

## Identity (confirmed in project)

| Item | Value |
|---|---|
| Display name | אבן דרך |
| Bundle ID | `com.yahpz.responder` |
| Marketing version | 1.0.2 (`MARKETING_VERSION` in `project.yml`) |
| Build | 16 (`CURRENT_PROJECT_VERSION`); bump before every upload |
| Team | `477WWCHXU7` (personal) |
| Devices | iPhone only (`TARGETED_DEVICE_FAMILY = 1`) |
| Minimum iOS | 17.0 |
| Localization | `he` only |
| Encryption export | `ITSAppUsesNonExemptEncryption = false` |
| Category | Productivity |

## App Icon

- [x] 1024×1024 PNG at `App/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
- [x] RGB, no alpha (Apple rejects transparency on the App Store icon)
- [x] Square; Apple applies the squircle mask
- [x] Single-size iOS 17+ catalog (`universal` 1024) is enough; Xcode generates the rest
- Copy for Connect: `docs/app-store/AppIcon-1024.png` (generated with the screenshots)

## Location strings (unchanged)

`NSLocationWhenInUseUsageDescription`

> אבן דרך משתמש במיקום כדי לשתף את מיקומך עם האחמ״ש בזמן אירוע. אפשר לעצור בכל רגע מסך המעקב.

`NSLocationAlwaysAndWhenInUseUsageDescription`

> אבן דרך ממשיך לשתף מיקום גם כשהמסך כבוי כל עוד שובצת לאירוע פתוח.

Background mode `location` is already in Info.plist.

Other usage strings in Info.plist:

- `NSCameraUsageDescription`: plate scan on the fill screen
- `NSMicrophoneUsageDescription`: voice note in the feedback sheet

Photos are picked with `PhotosPicker`, which needs no permission string. The מפה tab draws Apple
Maps and searches addresses with MapKit; it never asks for the user's location.

## PrivacyInfo.xcprivacy

Present at `App/Resources/PrivacyInfo.xcprivacy` and bundled via `App/Resources`.

Declared, linked, not used for tracking, purpose App Functionality:

- Name
- Email address
- Phone number
- User ID
- Precise location
- Photos or videos (event photos on the fill screen, feedback attachments)
- Audio data (feedback voice note)
- Other user content (event/shift fill)

Required-reason APIs: UserDefaults `CA92.1`, file timestamp `C617.1` (size of the recorded feedback note in the app container). Tracking: false.

## Privacy policy URL

Use `https://yahpz.com/privacy` (existing Hebrew policy on the web app). Do not invent a second policy. If that URL 404s from a public network, fix the web route before submit. Do not ship the iOS binary without a working Connect privacy URL.
