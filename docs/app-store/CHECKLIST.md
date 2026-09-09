# Icon and privacy checklist

## Identity (confirmed in project)

| Item | Value |
|---|---|
| Display name | אבן דרך |
| Bundle ID | `com.yahpz.responder` |
| Marketing version | 1.0.0 |
| Build | 2 |
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

Background mode `location` is already in Info.plist. No camera or photos usage, so no extra permission strings.

## PrivacyInfo.xcprivacy

Present at `App/Resources/PrivacyInfo.xcprivacy` and bundled via `App/Resources`.

Declared, linked, not used for tracking, purpose App Functionality:

- Name
- Email address
- Phone number
- User ID
- Precise location
- Other user content (event/shift fill)

Required-reason API: UserDefaults `CA92.1`. Tracking: false.

## Privacy policy URL

Use `https://yahpz.com/privacy` (existing Hebrew policy on the web app). Do not invent a second policy. If that URL 404s from a public network, fix the web route before submit. Do not ship the iOS binary without a working Connect privacy URL.
