# אבן דרך — אפליקציית כוננים ל-iOS

Native SwiftUI app for Yahpaz responders. Same Supabase backend as [yahpz.com](https://yahpz.com).

## What it does

- Email + password login (Hebrew RTL, רשומה Field/Command)
- **האירועים שלי** — pending / logged inbox, shift grouping
- **השלמת הפרטים שלי** — vehicle, odometers, route, treatment; draft + complete
- **זמינות**
- **פרופיל** + lifetime stats + forced password change
- Live location sharing, compiled out unless `LIVE_TRACKING` is set (see `project.yml`)

## Distribution

The App Store only. The submission pack is in [store-assets/](store-assets/AUDIT.md); archive,
validate and upload run through `scripts/deploy-xtool.sh` (below).

The Ad Hoc / OTA path (self-hosted `itms-services` installs from yahpz.com) was removed on
29 Oct 2026. Builds already installed that way still carry their own OTA update screen.

**Forced updates.** On launch and on every return to the foreground the app reads
`https://yahpz.com/ios/version.json` (web repo `op-yh-26/public/ios/version.json`). If the
installed build is below `minBuild`, the app shows only the update screen, whose button opens
`appStoreUrl`. **Add `"appStoreUrl": "https://apps.apple.com/app/id<APP_ID>"` to that file once
the app is live**; until then the button opens the App Store app. Raise `minBuild` only when
the App Store already serves that build.

## Build

Requires Xcode 16+ / iOS 17+.

```bash
xcodegen generate
swift test
xcodebuild -scheme Yahpaz -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
```

Command-line dev builds and the App Store pipeline run through `scripts/deploy-xtool.sh`
(xtool for simulator and device, Xcode for archive / validate / upload). See
[docs/xtool-deploy.md](docs/xtool-deploy.md).

```bash
scripts/deploy-xtool.sh doctor
scripts/deploy-xtool.sh sim              # xtool build → simulator
scripts/deploy-xtool.sh archive --dry-run
```

Bundle ID: `com.yahpz.responder`

## Domain tests

```bash
swift test
```
