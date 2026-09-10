# Where to click (Apple Developer + App Store Connect)

Two websites. Do not mix them.

| Site | URL | What it is for |
|---|---|---|
| Apple Developer | https://developer.apple.com/account | Paid membership, agreements, bundle ID |
| App Store Connect | https://appstoreconnect.apple.com | Listing, privacy, screenshots, submit |

Sign in both as `omriland@gmail.com`. Team: `477WWCHXU7`.

---

## 1. Apple Developer — prove you can ship

Open [developer.apple.com/account](https://developer.apple.com/account).

1. Top of the account page: membership must say **Apple Developer Program**, not "free".
2. If it is free: [developer.apple.com/programs/enroll](https://developer.apple.com/programs/enroll) → enroll as **Individual** → pay the $99. Wait for the email that membership is active. Stop here until that email arrives. A free Apple ID cannot create an App Store listing or TestFlight.
3. Still on the account page, open **Agreements** (left). Accept any pending Apple Developer Program license.

Then open [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **Business** (the grid on the homepage, not Apps).

4. Sign the latest **Paid Applications** / **Free Applications** agreement if it is waiting. Connect will not let you create an app until the Account Holder does this.

You do **not** need Certificates, Identifiers & Profiles by hand if Xcode already signed the app onto your iPhone with automatic signing. Only go there if step 2 below is missing the bundle ID.

### Only if the bundle ID is missing later

[developer.apple.com/account/resources/identifiers/list](https://developer.apple.com/account/resources/identifiers/list)

1. **+** → App IDs → App
2. Description: `Yahpaz Responder`
3. Bundle ID: **Explicit** `com.yahpz.responder`
4. Capabilities: leave defaults. Location background is in the app Info.plist, not a portal switch.
5. Continue → Register

---

## 2. App Store Connect — create the app record

[appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **Apps**.

1. **+** (top left) → **New App**
2. Platforms: **iOS** only
3. Name: `אבן דרך`
4. Primary Language: **Hebrew**
5. Bundle ID: `com.yahpz.responder` (dropdown of IDs registered to this team)
6. SKU: `yahpaz-responder-ios` (internal, never shown on the Store)
7. User Access: **Full Access**
8. **Create**

Status becomes **Prepare for Submission**. If the name is taken, Apple says so here. Do not change the bundle ID.

---

## 3. Left sidebar inside the app

You are now inside אבן דרך. Top tabs: **Distribution** | **TestFlight**. Stay on **Distribution**.

Left sidebar, do these pages in this order:

### A. App Information

Distribution → General → **App Information**

| Field | Paste |
|---|---|
| Name | `אבן דרך` |
| Subtitle | `אפליקציית הכוננים של יחפ״צ` |
| Privacy Policy URL | `https://yahpz.com/privacy` |
| Category (primary) | Productivity |
| Category (secondary, optional) | Utilities |
| Content Rights | This app does **not** contain, show, or access third-party content (it is your unit's own data) |

**Age Rating** on this same page → **Edit** / start questionnaire. Answer **None** / **No** for violence, sex, drugs, gambling, unrestricted web, public user-generated content. Made for Kids: **No**. Expected result: **4+**. Save.

The Store icon is **not** uploaded here. It comes from the 1024 PNG inside the uploaded build.

### B. Pricing and Availability

Distribution → General → **Pricing and Availability**

- Price: **Free** (or $0.00)
- Availability: uncheck all, then enable **Israel** only
- Apple Vision Pro: **Don't make available** (iPhone-only binary)

### C. App Privacy (nutrition label)

Distribution → General → **App Privacy** → **Get Started**

1. Privacy Policy URL: `https://yahpz.com/privacy`
2. Do you collect data? **Yes**
3. Used for tracking? **No**
4. Add these data types. For each: **Linked to the user's identity** = Yes, **Used for tracking** = No, purpose = **App Functionality**:
   - Name
   - Email Address
   - Phone Number
   - User ID
   - Precise Location
   - Other User Content
5. Publish / Save. This is the public nutrition label. It must match `App/Resources/PrivacyInfo.xcprivacy`.

### D. Version 1.0 iOS listing (screenshots + copy)

Distribution → iOS App → **1.0 Prepare for Submission**

**Screenshots** — iPhone 6.9" display. Drag these, in this order, from:

`yahpaz-ios/docs/app-store/screenshots/iphone-6.9-1320x2868/`

1. `01-login.png`
2. `02-inbox.png`
3. `03-shifts.png`
4. `04-availability.png`
5. `05-tracking.png`

Skip iPad. Skip 6.5" unless Connect still shows it as required (it should scale from 6.9").

**Copy** — paste from `docs/app-store/LISTING.md`:

| Field | File section |
|---|---|
| Promotional Text | Promotional text |
| Description | Description |
| Keywords | Keywords |
| Support URL | `https://yahpz.com` |
| Marketing URL | `https://yahpz.com` |
| Version | `1.0.0` |
| Copyright | `2026 Omri Landman` |
| What's New | What's New |

**App Review Information** on this same version page:

| Field | Value |
|---|---|
| Sign-in required | **Yes** |
| Demo user / password | TODO: create a Supabase responder with no live incident data, then paste here |
| Contact name | Omri Landman |
| Contact email | `omriland@gmail.com` |
| Contact phone | your number |
| Notes | paste the English block in this file below |

English notes for the reviewer:

```
Even Derech (אבן דרך) is a private responder app for authorized members of an Israeli volunteer road-clearance unit. It is not a public 911 or consumer navigation app.

Sign-in uses the same email/password account as yahpz.com. Please use the demo account provided in this form.

Background location is used only while the responder is assigned to an open event, via a tracking token. The tracking screen can stop sharing at any time. When the user is not on an open event, the app does not collect location.

The UI is Hebrew, right-to-left. The app does not use encryption beyond HTTPS (ITSAppUsesNonExemptEncryption = false).
```

Release: **Manually release this version** until you have seen it on TestFlight yourself.

---

## 4. Upload the binary (not in the portal)

The portal cannot attach an IPA you drag in. Xcode / the script uploads it.

In `project.yml` bump `CURRENT_PROJECT_VERSION` from `2` to `3`, then:

```bash
cd /Users/omrilandman/CursorProjects/today-i/yahpaz-ios
xcodegen generate
./scripts/upload-testflight.sh
```

Wait for the email that processing finished (5–30 min). Then back in Connect:

Distribution → iOS App → 1.0 → **Build** → **+** → select the processed build.

Export compliance: **No** (HTTPS only; Info.plist already has `ITSAppUsesNonExemptEncryption = false`).

---

## 5. Submit

On the 1.0 page, top right: **Add for Review** → confirm the checkboxes → **Submit to App Review**.

Do not submit until:

- [ ] Membership is paid
- [ ] `https://yahpz.com/privacy` loads logged-out
- [ ] Demo account works on the iPhone login screen
- [ ] 6.9" screenshots are attached
- [ ] A build is selected

Then TestFlight: Connect → **TestFlight** tab → Internal Testing → add `omriland@gmail.com`. External testers need a Beta Review; skip that until the App Store review is in flight.
