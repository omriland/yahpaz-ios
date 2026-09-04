# אבן דרך — אפליקציית כוננים ל-iOS

Native SwiftUI app for Yahpaz responders. Same Supabase backend as [yahpz.com](https://yahpz.com).

**Install:** [yahpz.com/ios](https://yahpz.com/ios) — Safari on iPhone only

## What it does

- Email + password login (Hebrew RTL, רשומה Field/Command)
- **האירועים שלי** — pending / logged inbox, shift grouping
- **השלמת הפרטים שלי** — vehicle, odometers, route, treatment; draft + complete
- **זמינות**
- **פרופיל** + lifetime stats + forced password change
- Live location sharing when opened with `?track_token=` or `yahpaz://track?token=`

## Install

Distribution is **Ad Hoc, self-hosted from yahpz.com** — no App Store, no TestFlight, no
AltStore. A device only installs if its UDID was registered in team `477WWCHXU7` *before*
the build was signed.

Volunteers open <https://yahpz.com/ios> in **Safari** on the iPhone and tap install.
`itms-services://` links do nothing in Chrome, Firefox, or in-app browsers.

Hard limits worth knowing: 100 iPhones per membership year, resetting only at renewal, and
the provisioning profile expires 12 months after it is issued — at which point the app
stops launching until everyone reinstalls.

Design: `op-yh-26/docs/superpowers/specs/2026-09-04-yahpaz-ios-adhoc-selfhosted-distribution-design.md`

### Cutting a release

```bash
./scripts/build-adhoc.sh    # signed IPA + OTA manifest in dist/adhoc/
./scripts/publish-ios.sh    # copies into op-yh-26/public/ios/ and refreshes version.json
```

To add a volunteer: register the UDID at
<https://developer.apple.com/account/resources/devices/list>, then rerun both scripts.
Automatic signing picks up every registered device on each build.

## Build

Requires Xcode 16+ / iOS 17+.

```bash
xcodegen generate
swift test
xcodebuild -scheme Yahpaz -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
```

For a distributable build see "Cutting a release" above — `build-ipa.sh` produced an
unsigned IPA for AltStore and has been removed.

Bundle ID: `com.yahpz.responder`

## Domain tests

```bash
swift test
```
