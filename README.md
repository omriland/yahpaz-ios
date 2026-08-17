# אבן דרך — אפליקציית כוננים ל-iOS

Native SwiftUI app for Yahpaz responders. Same Supabase backend as [yahpz.com](https://yahpz.com).

**Install:** [omriland.github.io/yahpaz-ios](https://omriland.github.io/yahpaz-ios/)  
**IPA:** [github.com/omriland/yahpaz-ios/releases](https://github.com/omriland/yahpaz-ios/releases)

## What it does

- Email + password login (Hebrew RTL, רשומה Field/Command)
- **האירועים שלי** — pending / logged inbox, shift grouping
- **השלמת הפרטים שלי** — vehicle, odometers, route, treatment; draft + complete
- **זמינות**
- **פרופיל** + lifetime stats + forced password change
- Live location sharing when opened with `?track_token=` or `yahpaz://track?token=`

## Install

Personal Apple team `477WWCHXU7` cannot publish to TestFlight. Two working paths:

1. **Xcode → iPhone** (best): sign in to Xcode with `omriland@gmail.com`, plug in the iPhone, Run `Yahpaz`.
2. **AltStore:** add source `https://omriland.github.io/yahpaz-ios/altstore.json` and install. Free signing lasts 7 days.

## Build

Requires Xcode 16+ / iOS 17+.

```bash
xcodegen generate
swift test
xcodebuild -scheme Yahpaz -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
./scripts/build-ipa.sh
```

Bundle ID: `com.yahpz.responder`

## Domain tests

```bash
swift test
```
