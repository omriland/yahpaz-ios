# App Store Connect: what to type, field by field

For build **1.0.2 (17)**, bundle `com.yahpz.responder`, team `477WWCHXU7`. Order follows the
App Store Connect sidebar. Copy comes from the other files in this folder; this page says
which value goes where. Nothing here was entered by me: there is no App Store Connect
session on this Mac.

## 0. Before you start

- The op-yh-26 deploy from `feat/app-review-demo` is live: App Review demo flag, `/support`,
  the updated privacy policy. Then the demo account has been provisioned (`REVIEW-NOTES.md`).
  Without it, App Review stops at the login screen.
- **3.2 decided: public App Store** (29 Oct). The reply in REVIEW-NOTES.md answers Apple's five
  questions for a public listing.
- Build 17: confirmed fine (TestFlight has only builds 1–4, under 1.0.0).

**Scripted path (instead of most of the clicks below).** With the Team API key in
`~/.appstoreconnect/` (`docs/xtool-deploy.md`): `scripts/deploy-xtool.sh archive` → `validate`
→ `upload`, then `node scripts/asc-metadata.mjs` (dry run) and `--apply`. It renames 1.0 to
1.0.2 and fills the listing, app info, categories, age rating, review notes (demo account left
empty), screenshots and build 17. It does not touch availability or pricing, and it never
submits. What stays manual: the demo account name and password, the review contact phone,
App Privacy, **Submit for Review**, and the Resolution Center reply.

## 1. The app record already exists

Apps → **אבן דרך**, Apple ID **6802333227**. Do not create a new app. Version 1.0 was rejected
on 18 Aug 2026 (build 1.0 (3), reviewed on an iPad Air 11-inch (M3)); this submission
answers that rejection (REVIEW-NOTES.md).

### Version string: 1.0 on App Store Connect, 1.0.2 in the build

The version record on App Store Connect says **1.0**; the build says **1.0.2**
(`MARKETING_VERSION` and `CFBundleShortVersionString` in `project.yml`). They must match or the
build cannot be attached.

**Recommended: change the App Store Connect version to `1.0.2`** (iOS App → the version page
→ the version number field, editable because 1.0 was never approved). Reasons: no rebuild;
1.0.2 is what Ad Hoc phones run and what `yahpz.com/ios/version.json` and the app's session
check-in already report; and it stays above the 1.0.0 TestFlight builds. The other way
(`MARKETING_VERSION` to 1.0) means editing two places in `project.yml`, a new archive, and a
store version that reads lower than what volunteers already run.

### App Store URL, for after launch

`https://apps.apple.com/app/id6802333227`. Put it in `op-yh-26/public/ios/version.json` as
`"appStoreUrl"` once the app is live (README.md, "Forced updates").

## 2. General → App Information

| Field | Value |
|---|---|
| Name | `אבן דרך` |
| Subtitle | `אפליקציית הכוננים של יחפ״צ` |
| Category, primary | Productivity (matches `LSApplicationCategoryType` in the build) |
| Category, secondary | Utilities (optional) |
| Content Rights | **No**, the app does not contain, show or access third-party content. Car-manufacturer logos and the WhatsApp icon were removed on 29 Oct; maps are Apple's own MapKit |
| Age Rating | Edit → answers in `AGE-RATING.md` → expected **4+**. Made for Kids: No |
| License Agreement | Apple's standard EULA (leave as is) |

## 3. General → Pricing and Availability

| Field | Value |
|---|---|
| Distribution | **Public App Store** (decided 29 Oct). Leave the distribution method as is; 3.2 is answered in the reply. Unlisted was considered and not chosen |
| Price | Free |
| Availability | Israel only (deselect all, select Israel) |
| Apple silicon Mac | Do not make available (iPhone-only, untested on Mac) |
| Apple Vision Pro | Do not make available |
| Pre-order | No |

## 4. General → App Privacy

| Field | Value |
|---|---|
| Privacy Policy URL | `https://yahpz.com/privacy` |
| User Privacy Choices URL (optional) | `https://yahpz.com/delete-data` |
| Data collection | Yes, collected. Not used for tracking |
| Data types | The **9 types** in `APP-PRIVACY.md`: Name, Email Address, Phone Number, User ID, Photos or Videos, Audio Data, Customer Support, Other User Content, Product Interaction. Each: linked to identity, not tracking, App Functionality only |

These are the same nine entries as `App/Resources/PrivacyInfo.xcprivacy`. The older
`docs/app-store/CONNECT.md` lists Precise Location: **do not add it** for this build, because
live tracking is compiled out.

Then **Publish**.

## 5. iOS App → the version page (rejected 1.0, renamed to 1.0.2)

### Screenshots

iPhone only. Upload in this order (same names in both folders):

| Display | Folder |
|---|---|
| iPhone 6.9" (required) | `store-assets/screenshots/iphone-6.9-1320x2868/` |
| iPhone 6.5" | `store-assets/screenshots/iphone-6.5-1242x2688/` (**replace** the old 6.5" set, which showed only the login screen: App Review 2.3.3) |

Delete every screenshot already on the version page first, then upload:

1. `01-my-events.png`
2. `02-complete-my-part.png`
3. `03-contacts.png`
4. `04-map.png`
5. `05-profile.png`
6. `06-availability.png`
7. `07-feedback.png`

No login screen, no iPad screenshots (iPhone-only build), no app preview video.

### Text (from `LISTING.md`)

| Field | Value |
|---|---|
| Promotional Text | LISTING.md → Promotional text |
| Description | LISTING.md → Description |
| Keywords | LISTING.md → Keywords |
| Support URL | `https://yahpz.com/support` (**live after the op-yh-26 deploy**; see `URLS.md`) |
| Marketing URL | `https://yahpz.com` (optional) |
| Version | `1.0.2` (change it from 1.0; see §1) |
| Copyright | `2026 Omri Landman` |
| What's New | not shown for a first release; keep LISTING.md → What's New for the next one |

### Build

After upload and processing: Build → **+** → `1.0.2 (17)`. Export compliance is answered by
the build (`ITSAppUsesNonExemptEncryption = false`), so no question should appear.

### App Review Information (from `REVIEW-NOTES.md`)

| Field | Value |
|---|---|
| Sign-in required | Yes |
| User name | the `app-review-demo` account email the provisioning script reports |
| Password | from `~/.yahpz-secrets/app-review-demo.env`; type it here, nowhere else |
| Contact | Omri Landman, your email and phone |
| Notes | REVIEW-NOTES.md → the English block |

### Version Release

**Manually release this version.**

## 6. Submit

Add for Review → Submit, then answer the rejection in the Resolution Center with the reply in
REVIEW-NOTES.md ("Reply to App Review"). Before that:

- [ ] 3.2 reply pasted (public listing answers)
- [ ] Version page reads 1.0.2
- [ ] Demo account provisioned, responder-only, sees only demo data, signs in on a phone (REVIEW-NOTES.md checklist)
- [ ] `https://yahpz.com/support` renders logged out (not deployed on 29 Oct)
- [ ] `https://yahpz.com/privacy` opens logged out and lists photos, voice notes, push token and app-version check-in
- [ ] Old screenshots removed; the 7 new ones uploaded for 6.9" and 6.5"
- [ ] Build 1.0.2 (17) selected
- [ ] Age rating and App Privacy published

## Not needed for this app

In-App Purchases, Subscriptions, Game Center, App Clips, Routing App Coverage File, Sign in
with Apple (email and password only, no third-party login), iPad and Mac.
