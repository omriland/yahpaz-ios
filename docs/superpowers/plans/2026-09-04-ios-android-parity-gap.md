# iOS ↔ Android parity gap inventory

**Generated:** 2026-09-04  
**Scope:** User-facing phone flows for `responder` / `shift_lead` / `admin` on Supabase `yahpaz-2026`. Android `:app` + `:domain` is source of truth. Web-only admin surfaces excluded unless the same capability exists in the Android app UI.

---

## Versions & git

| Repo | HEAD | Version |
|------|------|---------|
| **Android** `yahpaz-android` | `6a1fe54b3a83988a93cf94f31c8194492851201e` — *Ship 0.3.25 with in-app APK download and install* | `versionName` **0.3.25**, `versionCode` **36** (`app/build.gradle.kts`) |
| **iOS** `yahpaz-ios` | `feat/android-parity` (working tree dirty — parity slices + 2026-09-04 audit) | `CFBundleShortVersionString` **1.0.0**, `CFBundleVersion` **9** (`App/Info.plist`) |

**Version gap:** Version numbers are not aligned by design (0.3.25/36 vs 1.0.0/9). Android 0.3.25 vs 0.3.24 is in-app APK sideload only — not an iOS surface.

**Audit 2026-09-04:** All **25** reachable Android phone surfaces are **Present** on iOS. **0 Partial / 0 Missing.** See implementation plan § Audit 2026-09-04. Goal is **not** marked complete — device Ad Hoc smoke + UDID enrollment remain.

### Drift check 2026-09-04 (evening)

Re-fetched `origin/main` on `/Users/omrilandman/CursorProjects/today-i/yahpaz-android`. **HEAD is still `6a1fe54b3a83988a93cf94f31c8194492851201e`** (`0.3.25` / `36`). `git log 6a1fe54..HEAD` is empty; `app/src` + `domain/src` diff vs that SHA is empty.

Working tree dirt is only untracked `play/assets/*` screenshots and `.cursor/skills/` — no new Compose screens or nav.

`MobileNav.kt` / `AdminShell` / `RootScreen` unchanged: still 25 reachable surfaces; cockpit / closed lists / broadcast / fuel quarter still have no nav entry (`ToolsHubScreen` remains unused; admin tab is `AdminShell` = users + reports). Android עוד is still `ModalBottomSheet` + `MoreSheet` — Android-only chrome, not a new flow.

**No new iOS port. No new IPA.**

---

## Summary counts (reachable Android surfaces)

Counted **25** distinct user-facing destinations that are **reachable** in the shipped Android navigation (tabs, overlays, full-screen routes, modals tied to those routes).

| Status | Count | Meaning |
|--------|------:|---------|
| **Present** | **25** | Screen + domain rules match the reachable Android phone surface |
| **Partial** | **0** | — |
| **Missing** | **0** | — |

Additional **4** Android screens (`Cockpit`, `ClosedLists` hub, `Broadcast`, `FuelQuarter`) are **implemented in code but have no navigation entry point** in the current Android UI (see § Unreachable on Android). Not counted as Missing on iOS unless Android wires them later.

---

## Screen-by-screen table

**Superseded 2026-09-04:** every row below that was Partial / Missing / Different is now **Present** (login bidi-strip + car logos closed in the same audit). Historical notes kept for archaeology. Canonical table: implementation plan § Audit 2026-09-04.

| # | Android surface | Entry / roles | Key user actions | iOS | Notes |
|---|-----------------|---------------|------------------|-----|-------|
| 1 | **Boot / session restore** | App launch | Restore session, route to login or tabs | **Present** | `RootView` boot spinner; `AppModel.bootstrap()` |
| 2 | **Force update gate** | App launch if `version.json` min &gt; installed | Block app; open APK URL | **Missing** | Android: `AppUpdateCheck.kt`, `ForceUpdateScreen`, `yahpz.com/android/version.json`. iOS has publish script + `public/ios/version.json` but **no in-app check** |
| 3 | **Login** | Signed out | Email+password sign-in; password reset email | **Partial** | `LoginView` — no `PrivacyPolicyLink` (Android `LoginScreen` + `openPrivacy()`) |
| 4 | **Live track** | Deep link `yahpaz://…` / unsigned | Share GPS pings; close | **Present** | `LiveTrackView`, `LocationTracker`, domain `LiveTrack.swift` |
| 5 | **Must-change-password gate** | Profile after invite | Force password change before tabs | **Present** | Blocks tabs until password saved; triggers push registration after |
| 6 | **האירועים שלי (Inbox)** | Tab `mine` — responder / lead | Pending vs logged tabs; pull refresh; search logged; shift groups; event detail sheet; open fill | **Partial** | `InboxView` — missing `mineInboxIsOpen` / lead-KM pending inbox rule, overdue 48h card styling, `leadKmPendingNote`, search highlight ranges |
| 7 | **המשמרות שלי (My shifts)** | Tab `my_shifts` | Pending / future / logged sections; 30-day windows; shift sheet; jump to linked event fill | **Present** | `MyShiftsView` + `Shifts.swift` — matches Android `MyShiftsScreen` structure |
| 8 | **אנשי קשר (Contacts)** | Tab `contacts` — all signed-in | Search; call; WhatsApp | **Missing** | Android `ContactsScreen` + `:domain/Contacts.kt`. No iOS screen or API wiring |
| 9 | **אירועים (Unit events)** | Tab `events` — `managesUnit` | Search; my-active board drag/drop; incomplete partition; create FAB; edit/delete; fill self; filter own-created (volunteer lead) | **Missing** | Android `UnitEventsScreen` (~990 lines). iOS has no unit-events list or APIs in `YahpazAPI` |
| 10 | **משמרות (Unit shifts)** | Tab `shifts` — `managesUnit` | Search; detail sheet; create FAB; edit | **Missing** | Android `UnitShiftsScreen`. iOS only has *my* shifts |
| 11 | **דוחות catalog** | Tab `reports` (non-admin lead) or admin segment | Pick report kind | **Missing** | Android `ReportsCatalogScreen` + `:domain/Reports.kt` (6 kinds) |
| 12 | **Report runner** | From catalog | Date range; search; load rows; KM discrepancy write action | **Missing** | Android `ReportScreen` + `AppModel.openReport` / `reloadReport` |
| 13 | **ניהול → משתמשים (Admin users)** | Tab `users` — admin | Search; invite; edit roles/volunteer status/OTP; deactivate/delete; admin vehicle CRUD | **Missing** | Android `AdminUsersScreen` (~800 lines). iOS loads roles but does not expose admin UI |
| 14 | **ניהול → דוחות** | Admin segment chip | Same as reports catalog | **Missing** | Wired in `AdminShell`; iOS N/A |
| 15 | **פרופיל (Profile)** | Tab `profile` | Identity ledger; activity summary; availability row → sheet; **vehicles CRUD**; privacy link; sign out | **Partial** | `ProfileView` — ledger + password gate + sign out only. No vehicles, no availability row (separate tab instead), no privacy |
| 16 | **זמינות editor** | Profile bottom sheet (Android) | Available / unavailable + return date | **Different** | iOS: dedicated **tab** `AvailabilityView` (Android removed availability tab per `MobileNav.kt` / design doc). Logic mostly ported in `Availability.swift` |
| 17 | **Fill / השלמת התיעוד** | From inbox, shifts, unit events | Vehicle picker; odometer; route; treatment; treated plates + lookup; **media tab**; local draft stash; plate scan; draft/complete | **Partial** | `FillView` — core fields + plate lookup OK. **Missing:** event media (`FillMediaTab`), `FillDraftStore` / survival, experimental plate scan, `eventMedia` validation on complete |
| 18 | **Event form (create/edit)** | FAB on unit events; edit from list | Full event draft: district/road/station, crew, shift leads, treated vehicles, cancel/freeze, media, assigned-volunteer edit block | **Missing** | Android `EventFormScreen` + large `:domain/EventDraft.kt` etc. |
| 19 | **Shift form (create/edit)** | FAB on unit shifts | Shift date, kind, vehicle, crew, linked events | **Missing** | Android `ShiftFormScreen` + `:domain/ShiftDraft.kt` |
| 20 | **Privacy policy overlay** | Login + profile | In-app WebView/page | **Missing** | Android `PrivacyPolicyScreen` |
| 21 | **Feedback FAB + sheet** | Most signed-in screens | Bug/idea + optional audio/attachments | **Missing** | Android `FeedbackSheet` + `:domain/UserFeedback.kt` |
| 22 | **View-as banner + sheets** | More menu — super_admin | Impersonate user; role preview; stop | **Missing** | Android `ViewAsSheets.kt` + `:domain/ImpersonationEligibility.kt`, `RolePreview.kt` |
| 23 | **More (עוד) overflow** | Bottom bar when &gt;4 nav entries | Secondary tabs: contacts, unit shifts, reports; view-as rows | **Missing** | iOS fixed 4 tabs; no role-based nav (`mobileNavEntries`) |
| 24 | **Role-based tab bar & default tab** | All signed-in | Lead/admin → `events`; responder → `mine`; admin `users` tab | **Missing** | iOS always shows inbox / shifts / availability / profile |
| 25 | **Toast / error patterns** | Global | List reload failure semantics | **Partial** | iOS has `listReloadFailure` in domain; not all Android list surfaces exist |

### Unreachable on Android (code present, no nav — do not prioritize for iOS yet)

| Surface | Evidence |
|---------|----------|
| **הקוקפיט** | `CockpitScreen.kt`, `:domain/Cockpit.kt`; `MobileNav.kt` explicitly skips cockpit; no `setToolsDestination(COCKPIT)` call |
| **הגדרות / closed lists** | `ClosedListsScreen.kt`; no entry except back-navigation from broadcast |
| **תפוצה (Broadcast)** | `BroadcastScreen.kt`; only reachable from closed-lists hub (itself unreachable) |
| **ניהול דלק (Fuel quarter)** | `FuelQuarterScreen.kt`; web `adminSegments` includes it; Android `AdminShell` only exposes users + reports |

Web admin also has **Telegram bot registration** (`settingsPanes.ts` → `partner_bot`). **Not in Android app.** Exclude from iOS parity unless Android adds it.

---

## Domain-rule gaps (`YahpazDomain` vs `:domain`)

Android `:domain` has **49** Kotlin source files; iOS `Sources/YahpazDomain` has **9** Swift files.

| Area | Android | iOS | Gap |
|------|---------|-----|-----|
| **Mine inbox open rule** | `mineInboxIsOpen(participation, totalKm)` — stays open if done but lead KM null | Pending = `participation != .done` only | **Behavior bug** — events disappear from pending too early |
| **Lead KM pending note** | `leadKmPendingNote` + `LEAD_KM_PENDING_NOTE` | Not ported | Missing inbox/fill UX copy |
| **Overdue fill (48h)** | `OverdueFill.kt`, card tip + alert stripe | Not ported | Missing |
| **Participation stamps copy** | e.g. "ממתין לתיעוד" / "ממתין למתנדב" | Different strings ("ממתין למילוי פרטים") | **Copy drift** |
| **StampTone.alert** | Missing-KM overlay stamps | Not in iOS enum | Needed for unit-event lists |
| **Fill validation** | Requires route, treatment, plates; **`eventMedia`** + `unfinishedMediaDraftCount` | No media fields | Complete flow diverges |
| **Fill draft survival** | `FillDraftSurvival.kt`, local stash | None | Data loss on kill |
| **Mobile nav / roles** | `MobileNav.kt`, `Roles.kt` | Roles fetched, unused | Nav not role-aware |
| **Profile vehicles** | `ProfileVehicles.kt` | None | Fill assumes vehicles exist; no self-service |
| **Unit events scope** | `UnitEventsScope`, `MyActiveEvents`, incomplete partitions | None | |
| **Event / shift drafts** | `EventDraft`, `ShiftDraft`, freeze, shift leads | None | |
| **Reports** | `Reports`, `OpenDocumentation`, `KmDiscrepancy`, … | None | |
| **Admin users** | `AdminUserDraft`, OTP helpers | None | |
| **Broadcast / closed lists / fuel** | Full domain modules | None | Match Android **when** nav exists |
| **Cockpit** | Full module | None | Desktop-skipped on mobile |
| **Contacts** | `Contacts.kt` | None | |
| **App update** | `AppUpdate.kt` | None | |
| **Android session report** | `AndroidSessionReport.kt` + RPC | None | iOS needs equivalent telemetry RPC if desired |
| **User feedback** | `UserFeedback.kt` | None | |
| **Impersonation / role preview** | Eligibility + preview | None | |
| **Login normalize** | `LoginCredentials.kt` invisible-char strip | Not verified on iOS | Minor |
| **Plate scan** | `PlateScan.kt` | None | Experimental on Android |
| **Event media** | `EventMedia.kt`, compress | None | |
| **Assigned volunteer edit block** | `AssignedVolunteerEventEdit.kt` | None | |

**Already aligned (good parity):** `Format` (plates, dates), `TreatedPlates`, core `validateResponderFillDraft` (minus media), `Availability` write rules, `MineInbox` partition/search (minus open rule), `Shifts` partition, `LiveTrack` ping throttle, `PlateLookup`.

---

## Infrastructure

| Capability | Android | iOS | Gap |
|------------|---------|-----|-----|
| **Auth** | Email + password; reset via Supabase | Same | **Present**. No phone OTP login on either app (admin OTP enable is admin-user management, not login UI) |
| **Push (FCM / APNs)** | Server-side push on broadcast; **`user_ids_with_device_tokens` RPC** for preview counts. **No FCM client registration found** in app code | `PushRegistration.swift` + `upsert_device_token` RPC; `AppDelegate` (uncommitted) | iOS **ahead** on device token registration; Android may not register tokens yet |
| **Force update** | Boot check vs `yahpz.com/android/version.json`; blocking screen | `public/ios/version.json` + manifest published; **no in-app gate** | **Missing** on iOS |
| **Distribution** | APK sideload + `scripts/publish-apk-to-website.sh` | Ad Hoc OTA at `yahpz.com/ios` via `scripts/publish-ios.sh` | iOS OTA **done** (see below). No TestFlight/App Store requirement for parity doc |
| **Install / session telemetry** | `reportAndroidSession` RPC on sign-in (15 min throttle) | None | **Missing** on iOS |
| **Telegram connect** | Not in app | Not in app | Web-only (`partner_bot` settings). **Out of scope** |
| **Deep links** | Track token | `yahpaz://` track token | **Present** |

---

## What is already done on iOS

- **Ad Hoc OTA pipeline:** `scripts/build-adhoc.sh`, `scripts/publish-ios.sh` → `op-yh-26/public/ios/` (`Yahpaz.ipa`, `manifest.plist`, `version.json`). HEAD commit message: *Publish the Ad Hoc build to yahpz.com*.
- **Responder core:** Login, inbox (basic), my shifts, fill (text fields + treated plates + plate lookup), live track, must-change-password.
- **Domain slice:** Ported modules under `Sources/YahpazDomain/` with XCTest coverage.
- **Push scaffolding (WIP, uncommitted):** `PushRegistration.swift`, `AppDelegate.swift`, entitlements, API `upsertDeviceToken` / `deleteDeviceToken`.
- **App Store prep docs:** `docs/app-store/*` (listing, privacy manifest, screenshots script).

**Git status (iOS):** Many modified + untracked files (Ad Hoc, push, `MyShiftsView`, domain tests). **Not committed** — gap doc written without disturbing that work.

---

## Recommended implementation order

Smallest testable slices, dependency-first:

1. **Domain fixes on existing screens** — `mineInboxIsOpen`, `leadKmPendingNote`, `OverdueFill`, stamp copy/`StampTone.alert`; fix pending filter in `InboxView`. *Unblocks correct responder inbox without new screens.*
2. **Role-based navigation** — Port `MobileNav.kt` + `splitMobileNav`; replace fixed `TabView` in `RootView`; default tab by role. *Prerequisite for lead/admin flows.*
3. **Profile parity** — Move availability into profile sheet (drop dedicated tab to match Android); add vehicles section + `:domain/ProfileVehicles` port; privacy link.
4. **Contacts tab** — Single list screen + `YahpazAPI.fetchContacts`. *Small, isolated.*
5. **Fill hardening** — Local draft stash; then event media tab (larger); plate scan optional last.
6. **Unit shifts list + shift form** — Lead daily ops; FAB pattern mirrors Android.
7. **Unit events list + event form** — Largest slice; depends on lookups, assignable profiles, my-active prefs APIs.
8. **Reports catalog + shared report runner** — After unit events (shared patterns).
9. **Admin users** — Admin-only; depends on many RPCs already in Android `YahpazAPI`.
10. **Force update gate** — Read `https://yahpz.com/ios/version.json`; block with manifest install link.
11. **Session telemetry** — iOS analogue of `reportAndroidSession`.
12. **Feedback + impersonation** — Lower frequency; admin/super_admin only for view-as.

Defer until Android exposes nav: closed lists, broadcast UI, fuel quarter, cockpit.

---

## Top 10 gaps that block “same app”

1. **Role-based navigation** — iOS shows responder tabs to admins/leads; Android shows unit events/shifts, admin, reports, contacts, overflow.
2. **Unit events (אירועים)** — Core lead/admin workflow: board, create/edit events, assign crew, my-active.
3. **Event form** — Create/edit event with full domain validation and shift-lead rules.
4. **Unit shifts + shift form** — Lead shift management (separate from “my shifts”).
5. **Admin users (ניהול)** — Invite, roles, OTP flags, volunteer status, vehicle admin.
6. **Reports** — All six report kinds for leads/admins.
7. **Contacts** — Unit phone directory with call/WhatsApp.
8. **Profile vehicles + availability placement** — Self-service cars; availability on profile not tab.
9. **Fill completeness** — Event media + draft survival + validation parity (complete report blocked without photos when Android requires them).
10. **Inbox domain rules** — Lead-KM pending stays in pending; overdue 48h treatment; stamp/note parity.

Honorable mention: **force update** (ops), **feedback**, **impersonation** (super_admin), **privacy policy** link.

---

## Evidence index (primary files)

**Android:** `RootScreen.kt`, `AppModel.kt`, `MobileNav.kt` (domain), screens under `app/.../responder/*Screen.kt`, `:domain/*.kt`, `AppUpdateCheck.kt`, `AppConfig.kt`.

**iOS:** `RootView.swift`, `AppModel.swift`, `App/Screens/*.swift`, `Sources/YahpazDomain/*.swift`, `YahpazAPI.swift`, `PushRegistration.swift`, `scripts/publish-ios.sh`.

**Web context (not required on iOS unless Android ships it):** `op-yh-26/src/lib/adminSegments.ts`, `settingsPanes.ts` (lists, broadcast, Telegram bot).
