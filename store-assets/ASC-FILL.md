# App Store Connect: what to type, field by field

For build **1.0.2 (17)**, bundle `com.yahpz.responder`, team `477WWCHXU7`. Order follows the
App Store Connect sidebar. Copy comes from the other files in this folder; this page says
which value goes where. Nothing here was entered by me: there is no App Store Connect
session on this Mac.

## 0. Before you start

- Apple Developer Program membership active, latest agreements accepted
  (`docs/app-store/CONNECT.md` §1 has the clicks).
- The op-yh-26 deploy from `feat/app-review-demo` is live: App Review demo flag, `/support`,
  the updated privacy policy. Then the demo account has been provisioned (`REVIEW-NOTES.md`).
  Without it, App Review stops at the login screen.
- Build number 17 is confirmed as never uploaded before (still unconfirmed on 29 Oct).

## 1. Apps → + → New App

| Field | Value |
|---|---|
| Platforms | iOS |
| Name | `אבן דרך` (fallback if taken: `אבן דרך - יחפ״צ`) |
| Primary Language | Hebrew |
| Bundle ID | `com.yahpz.responder` |
| SKU | `yahpaz-responder-ios` |
| User Access | Full Access |

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

## 5. iOS App → 1.0.2 Prepare for Submission

### Screenshots

iPhone only. Upload in this order (same names in both folders):

| Display | Folder |
|---|---|
| iPhone 6.9" (required) | `store-assets/screenshots/iphone-6.9-1320x2868/` |
| iPhone 6.5" (only if App Store Connect asks for it; it normally scales from 6.9") | `store-assets/screenshots/iphone-6.5-1242x2688/` |

1. `01-login.png`
2. `02-my-events.png`
3. `03-complete-my-part.png`
4. `04-contacts.png`
5. `05-map.png`
6. `06-profile.png`
7. `07-availability.png`
8. `08-feedback.png`

No iPad screenshots (iPhone-only build). No app preview video.

### Text (from `LISTING.md`)

| Field | Value |
|---|---|
| Promotional Text | LISTING.md → Promotional text |
| Description | LISTING.md → Description |
| Keywords | LISTING.md → Keywords |
| Support URL | `https://yahpz.com/support` (**live after the op-yh-26 deploy**; see `URLS.md`) |
| Marketing URL | `https://yahpz.com` (optional) |
| Version | `1.0.2` |
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

Add for Review → Submit. Before that:

- [ ] Demo account provisioned, responder-only, sees only demo data, signs in on a phone (REVIEW-NOTES.md checklist)
- [ ] `https://yahpz.com/support` renders logged out (not deployed on 29 Oct)
- [ ] `https://yahpz.com/privacy` opens logged out and lists photos, voice notes, push token and app-version check-in
- [ ] 6.9" screenshots attached
- [ ] Build 17 selected (number confirmed as never uploaded)
- [ ] Age rating and App Privacy published

## Not needed for this app

In-App Purchases, Subscriptions, Game Center, App Clips, Routing App Coverage File, Sign in
with Apple (email and password only, no third-party login), iPad and Mac.
