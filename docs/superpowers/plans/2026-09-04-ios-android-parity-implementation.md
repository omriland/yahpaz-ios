# iOS ↔ Android parity — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `yahpaz-ios` match the reachable feature set of Android `yahpaz-android` HEAD `6ba4f88` (0.3.24 / 35), Hebrew RTL, same domain rules — no web-only admin, no unreachable Android screens.

**Architecture:** Port Android `:domain` modules into `Sources/YahpazDomain` with XCTest first, then wire SwiftUI screens to those functions. Do not invent product rules. Android Compose screens are the UX source; iOS keeps the existing Field/Command visual language.

**Tech Stack:** Swift 5.9, SwiftUI, iOS 17, local SPM `YahpazDomain`, Supabase Swift, XCTest. Bundle `com.yahpz.responder`, team `477WWCHXU7`, display name אבן דרך.

**Source inventory:** `docs/superpowers/plans/2026-09-04-ios-android-parity-gap.md` (trust it; spot-check Android if something looks wrong).

## Global Constraints

- Hebrew-only product UI, `lang=he`, RTL. No English copy on user surfaces.
- Match Android domain rules exactly. Do not invent statuses, labels, or nav ranks.
- Exclude cockpit / closed lists / broadcast / fuel quarter until Android gives them a nav entry.
- Do not touch web (`op-yh-26`) unless a backend API is actually missing (it should not be).
- Do not kill/restart any Vite / localhost server.
- Working tree may already be dirty (Ad Hoc, push, shifts). Do **not** stash, reset, or overwrite unrelated user work. Commit only when asked.
- Bundle `com.yahpz.responder`, team `477WWCHXU7`, display name אבן דרך.
- Visual: stay consistent with existing Yahpaz iOS Field/Command tokens; information architecture follows Android.

---

## File map (locked)

| Area | Android (copy from) | iOS |
|------|---------------------|-----|
| Inbox open rule, stamps, KM note | `domain/.../Status.kt`, `MineInbox.kt`, `OverdueFill.kt` | `Sources/YahpazDomain/Status.swift`, `MineInbox.swift`, **create** `OverdueFill.swift` |
| Role nav | `domain/.../Roles.kt`, `MobileNav.kt` | **create** `Roles.swift`, `MobileNav.swift`; change `RootView.swift`, `AppModel.swift` |
| Profile + vehicles + availability | `ProfileScreen.kt`, `ProfileVehicles.kt` | `ProfileView.swift`, `AvailabilityView.swift` |
| Contacts | `ContactsScreen.kt`, `Contacts.kt` | **create** screen + domain + `YahpazAPI.fetchContacts` |
| Fill media / drafts | `FillScreen.kt`, `FillMediaTab.kt`, `FillDraftSurvival.kt`, `EventMedia.kt` | `FillView.swift` + new domain |
| Unit shifts | `UnitShiftsScreen.kt`, `ShiftFormScreen.kt`, `ShiftDraft.kt` | **create** screens + API |
| Unit events | `UnitEventsScreen.kt`, `EventFormScreen.kt`, `EventDraft.kt` | **create** screens + API |
| Reports | `ReportsCatalogScreen.kt`, `ReportScreen.kt`, `Reports.kt` | **create** screens + API |
| Admin users | `AdminUsersScreen.kt`, `AdminUserDraft.kt` | **create** screen + API |
| Force update / session / feedback / view-as | matching `:domain` + `RootScreen.kt` | **done** (slices 10–12) |

**Shipped so far:** slices 1–12. No further executable Android-parity slices remain in this plan.

---

### Task 1: Inbox domain rules + inbox UI (SLICE 1 — this turn)

**Why first:** Gap doc order item 1. Unblocks the correct responder inbox without new screens. Role-based nav is slice 2 (it does not depend on this, but inbox correctness is the smaller, already-visible surface).

**Files:**
- Modify: `Sources/YahpazDomain/Status.swift`
- Modify: `Sources/YahpazDomain/MineInbox.swift`
- Create: `Sources/YahpazDomain/OverdueFill.swift`
- Modify: `Tests/YahpazDomainTests/MineInboxTests.swift`
- Create: `Tests/YahpazDomainTests/StatusTests.swift`
- Create: `Tests/YahpazDomainTests/OverdueFillTests.swift`
- Modify: `App/Theme/Theme.swift` (`StampTone.alert`)
- Modify: `App/Components/Components.swift` (`StampWithNote`)
- Modify: `App/API/Models.swift` (`ResponderSummary.totalKm`, `fillCompletableAt`, `ownTotalKm`, `ownFillCompletableAt`)
- Modify: `App/API/YahpazAPI.swift` (`eventListSelect` add `fill_completable_at, total_km`)
- Modify: `App/Screens/InboxView.swift`
- Modify: `App/Screens/FillView.swift` (lead-KM note + title copy)

**Android sources:**
- `yahpaz-android/domain/src/main/kotlin/com/yahpz/domain/Status.kt` (`mineInboxIsOpen`, `leadKmPendingNote`, `StampTone.ALERT`, stamp/CTA copy, `reportingDocumentationStamp`)
- `yahpaz-android/domain/src/main/kotlin/com/yahpz/domain/MineInbox.kt` (`MineListEvent.totalKm`, `partitionMineList` uses `mineInboxIsOpen`, `searchHighlightRanges`)
- `yahpaz-android/domain/src/main/kotlin/com/yahpz/domain/OverdueFill.kt`
- Tests: `StatusTest.kt`, `MineInboxTest.kt`, `OverdueFillTest.kt`
- UI: `app/.../InboxScreen.kt`, `FillScreen.kt`, `Components.kt` (`StampWithNote`), `Theme.kt` (`StampTone.ALERT`)

**Interfaces:**
- Consumes: existing `ParticipationStatus`, `EventStatus`, `MineListEvent`, inbox list models
- Produces: `mineInboxIsOpen(_:totalKm:) -> Bool`, `leadKmPendingNote(_:totalKm:) -> String?`, `isMineFillOverdue(...) -> Bool`, `searchHighlightRanges(_:query:) -> [TextHighlightRange]`, `StampTone.alert`, `reportingDocumentationStamp`, `overlayMissingKmOnDoneStamp`

- [x] **Step 1: Write failing domain tests** (port Android assertions verbatim)

`Tests/YahpazDomainTests/StatusTests.swift` — copy `StatusTest.kt`:
- done + missing KM → stamp `חסר ק״מ` / `.alert`
- done + KM filled stays `הושלם`
- partial + missing KM is **not** overridden
- overlay only a green `הושלם` stamp
- `leadKmPendingNote(.done, nil) == "אחמ״ש טרם הזין ק״מ"`; `(.done, 0) == nil`; `(.inProgress, nil) == nil`
- `mineInboxIsOpen(.done, nil) == true`; `(.done, 12) == false`

`Tests/YahpazDomainTests/MineInboxTests.swift` — add/replace:
- `partitionKeepsDoneWithoutKmInPending` (done+12 logged; done+nil pending)
- fill CTA: `"השלמת התיעוד שלי"` / `"המשך התיעוד"`
- viewer pending stamp: `"ממתין לתיעוד"` (not `"ממתין למילוי פרטים"`)
- non-viewer pending stamp: `"ממתין למתנדב"`
- `searchHighlightRanges("צומת גזר", query: "גזר") == [TextHighlightRange(start: 5, endExclusive: 8)]`
- English-keyboard mapped Hebrew: `"dzr"` hits the same range
- blank query → empty ranges

`Tests/YahpazDomainTests/OverdueFillTests.swift` — copy `OverdueFillTest.kt` with `t0 = "2026-08-16T10:00:00.000Z"`.

- [x] **Step 2: Run tests — expect FAIL** (missing symbols / wrong copy)

```bash
cd /Users/omrilandman/CursorProjects/today-i/yahpaz-ios
swift test --filter YahpazDomainTests
```

Expected: compile errors for `mineInboxIsOpen`, `StampTone.alert`, `isMineFillOverdue`, and/or assertion failures on stamp/CTA copy.

- [x] **Step 3: Implement domain (minimal port)**

`Status.swift`:
```swift
public enum StampTone: String, Sendable {
    case done, partial, pending, draft, alert
}

public let MISSING_KM_STAMP_LABEL = "חסר ק״מ"
public let LEAD_KM_PENDING_NOTE = "אחמ״ש טרם הזין ק״מ"

public func reportingDocumentationStamp(_ status: EventStatus, missingKm: Bool) -> StampDescriptor {
    overlayMissingKmOnDoneStamp(eventStamp(status), missingKm: missingKm)
}

public func overlayMissingKmOnDoneStamp(_ stamp: StampDescriptor, missingKm: Bool) -> StampDescriptor {
    if missingKm && stamp.tone == .done && stamp.label == "הושלם" {
        return StampDescriptor(label: MISSING_KM_STAMP_LABEL, tone: .alert)
    }
    return stamp
}

public func participationStamp(_ status: ParticipationStatus, isViewer: Bool) -> StampDescriptor {
    if status == .done { return StampDescriptor(label: "הושלם", tone: .done) }
    if status == .inProgress && isViewer {
        return StampDescriptor(label: "טיוטה נשמרה", tone: .draft)
    }
    return StampDescriptor(label: isViewer ? "ממתין לתיעוד" : "ממתין למתנדב", tone: .pending)
}

public func leadKmPendingNote(_ participation: ParticipationStatus?, totalKm: Double?) -> String? {
    if participation == .done && totalKm == nil { return LEAD_KM_PENDING_NOTE }
    return nil
}

public func mineInboxIsOpen(_ participation: ParticipationStatus?, totalKm: Double?) -> Bool {
    if participation != .done { return true }
    return totalKm == nil
}

public func mineFillCtaLabel(_ status: ParticipationStatus) -> String? {
    switch status {
    case .done: return nil
    case .inProgress: return "המשך התיעוד"
    case .pending: return "השלמת התיעוד שלי"
    }
}
```

`MineInbox.swift` — add `totalKm: Double? = nil` to `MineListEvent`; `partitionMineList` uses `mineInboxIsOpen(item.participation, totalKm: item.totalKm)`; port `searchHighlightRanges` + `TextHighlightRange` from `MineInbox.kt`.

`OverdueFill.swift` — port `OverdueFill.kt` (`OVERDUE_48H_MS = 48 * 60 * 60 * 1000`, `OVERDUE_FILL_CARD_TIP`, ISO-8601 parse of `fillCompletableAt`). Done / cancelled / missing timestamp → not overdue.

- [x] **Step 4: Run domain tests — expect PASS**

```bash
swift test --filter YahpazDomainTests
```

- [x] **Step 5: Wire inbox + fill UI**

- `eventListSelect` responders: `id, responder_id, status, fill_completable_at, total_km, profile:profiles(...)` (Android `YahpazAPI.kt` event list).
- `InboxView.pending` uses `mineInboxIsOpen(event.ownParticipation(...), totalKm: event.ownTotalKm(...))`.
- `partitionMineList` passes `totalKm`.
- Pending cards: `isMineFillOverdue` → `FieldTheme.alertTint` fill + 3pt alert rail + hourglass with `OVERDUE_FILL_CARD_TIP`.
- `StampWithNote(stamp, note: leadKmPendingNote(...))` on cards, logged rows, summary sheet, fill read-only header.
- Logged search: highlight ranges with Android yellow `0xFFF59D`.
- Fill screen title: `השלמת התיעוד שלי` (Android `FillScreen.kt`).
- `Theme.swift`: `.alert` → `FieldTheme.alert` / `alertTint`.

- [x] **Step 6: Verify compile**

```bash
swift test --filter YahpazDomainTests
xcodebuild -scheme Yahpaz -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

If the simulator name differs, pick any available iPhone simulator from `xcodebuild -scheme Yahpaz -showdestinations`.

**Done when:** a participation with `status=done` and `total_km=null` stays in ממתינים לתיעוד, shows `אחמ״ש טרם הזין ק״מ`, and a pending fill older than 48h from `fill_completable_at` uses the alert stripe. Logged search highlights the hit.

---

### Task 2: Role-based navigation (DONE)

Prerequisite for lead/admin destinations. Domain-only first, then a tab bar that can host placeholder screens.

**Files:**
- Create: `Sources/YahpazDomain/Roles.swift` (port `Roles.kt` — `AppRole`, `roleSet`, `managesUnit`, `isAdmin`, `isResponder`, labels, assignable-role helpers used later by admin)
- Create: `Sources/YahpazDomain/MobileNav.swift` (port `MobileNav.kt` — `mobileNavEntries`, `splitMobileNav`, `defaultMobileView`, `MOBILE_MORE_LABEL = "עוד"`)
- Create: `Tests/YahpazDomainTests/RolesTests.swift` (port `RolesTest.kt`)
- Create: `Tests/YahpazDomainTests/MobileNavTests.swift` (port `MobileNavTest.kt`)
- Modify: `App/AppModel.swift` — tab identity becomes Android view keys (`mine`, `my_shifts`, `contacts`, `events`, `shifts`, `reports`, `users`, `profile`); default tab = `defaultMobileView(roles)`
- Modify: `App/Screens/RootView.swift` — replace fixed 4-tab `TabView` with `splitMobileNav(mobileNavEntries(app.roles))`; overflow sheet labeled `עוד`; **drop dedicated Availability tab** (Android removed it; availability moves in slice 3)
- Create stub screens (Hebrew title + “בקרוב” empty, same Field page) for destinations not yet ported: contacts, unit events, unit shifts, reports, admin users — so leads/admins can land on `events` without crashing

**Android sources:** `Roles.kt`, `MobileNav.kt`, `MobileNavTest.kt`, `RolesTest.kt`, `RootScreen.kt` tab wiring, `AppModel.kt` `canManageUnit` / `defaultMobileView`.

**Verification:**
```bash
swift test --filter RolesTests --filter MobileNavTests
xcodebuild -scheme Yahpaz -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build CODE_SIGNING_ALLOWED=NO
```
Responder: tabs האירועים שלי / המשמרות שלי / אנשי קשר / פרופיל (no overflow if ≤4). Shift-lead: bar has אירועים first; default tab `events`. Admin: ניהול in bar, reports not a separate tab (lives under ניהול later).

**Placeholder rule:** stubs are allowed only for destinations the next slices will fill. Do not stub cockpit/broadcast/fuel/closed lists.

---

### Task 3: Profile parity (DONE)

**Depends on:** slice 2 (profile is a nav destination, not a dedicated availability tab).

**Android:** `ProfileScreen.kt`, `domain/ProfileVehicles.kt`, `PrivacyPageToken.kt`, `Availability.kt` (already on iOS).

**iOS:**
- Move `AvailabilityView` into a profile sheet (Android bottom sheet).
- Port `ProfileVehicles` + API list/create/archive/default (`set_default_vehicle`).
- Privacy overlay (WKWebView + signed `/privacy?t=` URL, same secret/origin as Android).
- Keep identity ledger + activity summary + sign out.

**Verify:** `swift test --filter YahpazDomainTests`; profile shows רכבים CRUD; availability is not a root tab.

- [x] Domain: `ProfileVehicles.swift` + `PrivacyPageToken.swift` + tests (Android assertions)
- [x] Availability row → sheet; Android copy (`הסטטוס יוצג…`, `ניתן לבחור רק תאריך עתידי`)
- [x] Vehicles CRUD + רכב ראשי (`canChooseDefaultVehicle` ≥ 2 active, `set_default_vehicle`)
- [x] Privacy link on profile + login; in-app overlay
- [x] `swift test --filter YahpazDomainTests` PASS (102 tests)
- [x] `xcodebuild -scheme Yahpaz -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build CODE_SIGNING_ALLOWED=NO` **BUILD SUCCEEDED**

---

### Task 4: Contacts tab (DONE)

**Android:** `ContactsScreen.kt`, `domain/Contacts.kt`, `YahpazAPI.fetchUnitContacts`.

**iOS:**
- Port `Contacts.kt` (phone format / tel / WhatsApp / `filterContacts` + digit search).
- `YahpazAPI.fetchUnitContacts` → RPC `list_unit_contacts`.
- Replace slice-2 `בקרוב` stub with list: search, call (`tel:+972…`), WhatsApp (`https://wa.me/972…`). Same Hebrew copy and empty/fail/loading states as Android.

**Verify:** `swift test --filter ContactsTests`; signed-in user sees אנשי קשר.

- [x] Domain: `Contacts.swift` + `ContactsTests.swift` (Android assertions)
- [x] API + AppModel `reloadContacts` (background after session; pull-to-refresh; empty-list retry)
- [x] `ContactsView` wired to slice-2 `contacts` tab
- [x] `swift test --filter YahpazDomainTests` PASS (**105 tests**, including 3 ContactsTests)
- [x] `xcodebuild -scheme Yahpaz -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build CODE_SIGNING_ALLOWED=NO` **BUILD SUCCEEDED**

---

### Task 5: Fill hardening (DONE)

**Android:** `FillDraftSurvival.kt`, `FillScreen.kt` stash, `EventMedia.kt`, `FillMediaTab.kt`, `CompressEventImage.kt`, `PlateScan.kt` + `ExperimentalPlateScanDialog` (real treated-plates control labeled סריקה ניסיונית).

**iOS:**
- Local draft stash keyed `yahpaz.fillDraft.responder.{assignmentId}` (UserDefaults + RAM live map), 14-day freshness, 600ms debounce, persist on background/back. Restores across token-refresh boot via `shouldKeepLiveFormBoot`.
- Docs / מדיה tabs; event media list/upload/edit/delete; complete blocked on unfinished media drafts (`בחרו מתי צולמה כל תמונה.`), not on missing photos.
- Complete-validation parity: both odometers required; end > start; leftover treated plate; `gateResponderFillWrite` (already-done complete is success); two-step save so plates write before status=`done`. Lead `total_km` is **not** a complete client error (matches Android `Fill.kt` / `FillValidationTest`).
- Plate scan: domain OCR + streak confirm; camera UI labeled סריקה ניסיונית.

**Verify:** `swift test --filter YahpazDomainTests` PASS (147 tests); `xcodebuild -scheme Yahpaz -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build CODE_SIGNING_ALLOWED=NO` **BUILD SUCCEEDED**

- [x] Domain: `FillDraftSurvival`, `EventMedia`, `CompressEventImage`, `PlateScan`, `FillValidation` (`eventMedia`, `unfinishedMediaDraftCount`, `FillWriteGate`)
- [x] Tests: `FillDraftSurvivalTests`, `EventMediaTests`, `CompressEventImageTests`, `PlateScanTests`, extended `FillValidationTests`
- [x] `FillDraftStore` + FillView restore / debounce / back
- [x] `FillMediaTab` + storage `event-media` API
- [x] Plate scan domain + camera UI
- [x] `swift test --filter YahpazDomainTests` PASS (**147 tests**)
- [x] `xcodebuild … iPhone 17 … CODE_SIGNING_ALLOWED=NO` **BUILD SUCCEEDED**

---

### Task 6: Unit shifts list + shift form (DONE)

**Android:** `UnitShiftsScreen.kt`, `ShiftFormScreen.kt`, `ShiftDraft.kt`, `Shifts.kt` (mine-shifts already on iOS).

**iOS:** replace stub; FAB create; detail sheet; identity-lock rules for responders.

**Verify:** domain `ShiftDraft` tests; lead can open משמרות from עוד (or tab if ranked in).

- [x] Domain: `ShiftDraft.swift` + `ShiftDraftTests.swift` (Android assertions + identity lock + assignable filter)
- [x] `shiftStamp(.inProgress)` aligned to Android `פתוחה`
- [x] API: `fetchUnitShifts`, `fetchAssignableProfiles`, `fetchVehiclesForResponders`, `fetchShiftFormDetail`, `createUnitShift`, `updateUnitShift`
- [x] `UnitShiftsView` replaces slice-2 stub (search, detail sheet, FAB, born-event → fill)
- [x] `ShiftFormView` create/edit; identity fields disabled unless `canEditShiftIdentity` (`managesUnit`)
- [x] `swift test --filter YahpazDomainTests` PASS (**158 tests**, including 11 ShiftDraftTests)
- [x] `xcodebuild … iPhone 17 … CODE_SIGNING_ALLOWED=NO` **BUILD SUCCEEDED**

---

### Task 7: Unit events list + event form

**Largest slice.** Depends on lookups, assignable profiles, my-active prefs.

**Android:** `UnitEventsScreen.kt`, `EventFormScreen.kt`, `EventDraft.kt`, `UnitEventsScope.kt`, `MyActiveEvents.kt`, `EventFreeze.kt`, `EventShiftLeads.kt`, `AssignedVolunteerEventEdit.kt`, `ForeignEventEdit.kt`.

**Verify:** domain tests for those modules; lead default tab shows אירועים with search + FAB.

---

### Task 8: Reports catalog + runner (DONE)

**Android:** `Reports.kt` (6 kinds), `ReportsCatalogScreen.kt`, `ReportScreen.kt`, `KmDiscrepancy.kt`, `OpenDocumentation.kt`, `EventsByResponder.kt`, `KmExceptions.kt`, `DuplicateEvents.kt`, `FuelRefund.kt`.

**Admin** uses ניהול → דוחות (slice 9); non-admin lead uses דוחות tab/overflow. No admin reports tab (matches `MobileNav`).

**Verify:** catalog lists the same 6 kinds; KM discrepancy write matches Android RPC.

- [x] Domain: `Reports`, `OpenDocumentation`, `EventsByResponder`, `KmExceptions`, `KmDiscrepancy`, `DuplicateEvents`, `FuelRefund` + tests (Android assertions)
- [x] API: `fetchReport` (6 kinds) + `applyLeadKmFromOdometer`
- [x] `ReportsCatalogView` replaces slice-2 stub; `ReportView` date-range runner + search + KM apply sheet
- [x] Wired to existing `reports` tab; admin still has no דוחות tab
- [x] `swift test --filter YahpazDomainTests` PASS (**269 tests**, including 46 report-catalog/runner tests)
- [x] `xcodebuild … iPhone 17 … CODE_SIGNING_ALLOWED=NO` **BUILD SUCCEEDED**

---

### Task 9: Admin users (DONE)

**Android:** `AdminUsersScreen.kt`, `AdminUserDraft.kt`, OTP helpers, volunteer status, vehicle admin.

**Verify:** admin tab ניהול lists users; invite/edit/deactivate; no English.

- [x] Domain: `VolunteerStatus.swift` + `AdminUserDraft.swift` + `findDuplicatePlate` (Android assertions)
- [x] Tests: `AdminUserDraftTests` (26) + `findDuplicatePlate` in format tests
- [x] API: `fetchAdminUsers`, invite/save/delete/resend/copy-link, OTP flags, admin vehicle archive/delete, role/vehicle sync
- [x] `AdminUsersView` replaces slice-2 stub (search, invite, edit, OTP, deactivate/reactivate, delete, vehicles)
- [x] `AdminShellView` chips: משתמשים / דוחות וסטטיסטיקות (admin has no דוחות tab)
- [x] No web-only super_admin impersonation / set-password / set-email
- [x] `swift test --filter YahpazDomainTests` PASS (**296 tests**, including 26 AdminUserDraftTests)
- [x] `xcodebuild … iPhone 17 … CODE_SIGNING_ALLOWED=NO` **BUILD SUCCEEDED**

---

### Task 10: Force update gate (DONE)

**Android:** `AppUpdate.kt`, `AppUpdateCheck.kt`, `ForceUpdateScreen`, `yahpz.com/android/version.json`.

**iOS:** read `https://yahpz.com/ios/version.json` (ephemeral / no-store); block if `CFBundleVersion` < `minBuild`; Hebrew `messageHe`; CTA opens `itms-services` from `manifestUrl` (Safari `/ios` fallback). Soft “newer available” sheet matches Android `needsOptionalUpdate` + skip prefs.

- [x] Domain: `AppUpdate.swift` (`needsForceUpdate`, `needsOptionalUpdate`, `itmsInstallHref`) + `AppUpdateTests`
- [x] App: `AppUpdateCheck.swift` fetch + gate models; `ForceUpdateView` + optional sheet
- [x] Boot: `AppModel.bootstrap` checks before session restore; `RootView` blocks all routes
- [x] No UDID enrollment Edge Function (not this slice)
- [x] No provisioning-profile expiry warning (Android does not ship it; iOS Ad Hoc plan 3 — not slice 10)
- [x] Web `version.json` fields already sufficient — no web change
- [x] `swift test --filter YahpazDomainTests` PASS (**303 tests**, including 7 AppUpdateTests)
- [x] `xcodebuild … iPhone 17 … CODE_SIGNING_ALLOWED=NO` **BUILD SUCCEEDED**

---

### Task 11: Session telemetry (DONE)

**Android:** `AndroidSessionReport.kt` + `report_android_session` RPC on sign-in / foreground / force-update boot (15 min throttle).

**iOS:** same RPC + `profiles.last_android_*` columns. Schema has **no platform field** — payload is `p_version_code` / `p_version_name` only (iOS `CFBundleVersion` / `CFBundleShortVersionString`). No new table.

- [x] Domain: `SessionReport.swift` (`SESSION_REPORT_THROTTLE_MS`, `sessionRpcParams`, `shouldReportSession`) + `SessionReportTests` (Android assertions)
- [x] API: `YahpazAPI.reportSession` → `report_android_session`
- [x] App: report after `applySession`, on force-update boot if signed in, and `scenePhase == .active` (Android `onForeground`)
- [x] Failures swallowed (Android `runCatching`)
- [x] `swift test --filter YahpazDomainTests` PASS (**307 tests**, including 4 SessionReportTests)
- [x] `xcodebuild … iPhone 17 … CODE_SIGNING_ALLOWED=NO` **BUILD SUCCEEDED**

---

### Task 12: Feedback + impersonation (view-as) (DONE)

**Android phone ships both.** Ported: Feedback FAB + sheet (`UserFeedback`, `FeedbackSheet`) and More-menu view-as (`ImpersonationEligibility`, `RolePreview`, `ViewAsSheets`, `ViewAsStore`). Not web-only — Android `RootScreen` / `MoreViewAsRows` expose it for `super_admin`. Hide view-as unless `canStartImpersonation` / `canStartRolePreview` (super_admin, not already impersonating).

- [x] Domain: `UserFeedback.swift`, `ImpersonationEligibility.swift`, `RolePreview.swift` + tests (Android assertions)
- [x] Feedback FAB on signed-in screens; hidden on fill / event form / shift form / hide-until-refresh (same `shouldShowFeedbackFab` rule)
- [x] Feedback sheet: bug/suggestion, body, 90s audio, ≤3 image/video attachments → `user_feedback` + `user-feedback` storage
- [x] More-menu view-as: role preview (local) + impersonate (`admin-users` impersonate / stop_impersonation); banner; availability lock while impersonating
- [x] `swift test --filter YahpazDomainTests` PASS (**325 tests**, including 11 UserFeedbackTests + 2 ImpersonationEligibilityTests + 5 RolePreviewTests)
- [x] `xcodebuild … iPhone 17 … CODE_SIGNING_ALLOWED=NO` **BUILD SUCCEEDED**

---

## Deferred (Android unreachable — do not implement)

Cockpit, closed lists hub, broadcast, fuel quarter, Telegram bot (`partner_bot`). Revisit only if Android `MobileNav` / `AdminShell` grows an entry.

---

## Progress

| Slice | Name | Status |
|------:|------|--------|
| 1 | Inbox domain rules + inbox UI | done |
| 2 | Role-based navigation (`mobileNavEntries` / `splitMobileNav`) | done |
| 3 | Profile parity | done |
| 4 | Contacts | done |
| 5 | Fill hardening | done |
| 6 | Unit shifts + shift form | done |
| 7 | Unit events + event form | **done** |
| 8 | Reports catalog + runner | done |
| 9 | Admin users | done |
| 10 | Force update | done |
| 11 | Session telemetry | done |
| 12 | Feedback + impersonation | **done this turn** |

## Remaining vs exact Android

This was the last **executable** Android-parity slice. What is still not a 1:1 phone clone:

**Deferred — Android code exists but has no nav entry (do not implement until Android ships one):**
- הקוקפיט (`CockpitScreen`)
- Closed lists hub / הגדרות
- תפוצה (Broadcast) — only reachable from the unreachable lists hub
- ניהול דלק (Fuel quarter) — web admin segment; Android `AdminShell` is users + reports only
- Telegram `partner_bot` — web-only; not in Android app

**Not Android feature parity (ops / distribution):**
- **UDID enrollment** — Ad Hoc plan 2; no Android analogue. Do not add an Edge Function for it as part of this parity track.
- **Physical-device smoke** — Ad Hoc install + force-update CTA (`itms-services` only works on a registered iPhone). Simulator `xcodebuild` does not prove OTA.

**Known acceptable deltas (not gaps):**
- Version numbers (Android 0.3.24/35 vs iOS 1.0.0/5) are not aligned by design.
- Session heartbeat still uses `report_android_session` / `last_android_*` (no platform column).
- Visual language stays iOS Field/Command tokens; IA and domain rules match Android.

---

## Audit 2026-09-04

Re-scanned Android `mobileNavEntries` / `RootScreen` / `AdminShell` at HEAD `6a1fe54` (**0.3.25 / 36**) and current iOS `feat/android-parity` screens. Android 0.3.25 vs the gap-doc 0.3.24 delta is **in-app APK download/install** only — Android-specific sideload, not an iOS surface (iOS already gates on `yahpz.com/ios/version.json` + `itms-services`).

### Reachable Android phone surfaces (25)

| Status | Count |
|--------|------:|
| **Present** | **25** |
| **Partial** | **0** |
| **Missing** | **0** |
| **Deferred-no-nav** | **4** (cockpit, closed lists, broadcast, fuel quarter) |

| # | Android surface | Status | Evidence |
|---|-----------------|--------|----------|
| 1 | Boot / session restore | Present | `RootView` + `AppModel.bootstrap` |
| 2 | Force update gate | Present | `AppUpdate` / `ForceUpdateView` / `yahpz.com/ios/version.json` |
| 3 | Login | Present | Email+password, reset, privacy; **this audit** added `normalizeLoginEmail` / `normalizeLoginSecret` |
| 4 | Live track | Present | `LiveTrackView` |
| 5 | Must-change-password | Present | Blocks tabs until password saved |
| 6 | האירועים שלי | Present | `mineInboxIsOpen`, overdue 48h, lead-KM note, search highlight |
| 7 | המשמרות שלי | Present | `MyShiftsView` |
| 8 | אנשי קשר | Present | Search / tel / WhatsApp |
| 9 | אירועים | Present | Search, own-created toggle, my-active drag/drop, incomplete pin, FAB |
| 10 | משמרות | Present | List + FAB + form |
| 11 | דוחות catalog | Present | 6 kinds; non-admin lead tab |
| 12 | Report runner | Present | Date range + KM discrepancy write |
| 13 | ניהול → משתמשים | Present | Invite / roles / OTP / vehicles |
| 14 | ניהול → דוחות | Present | `AdminShellView` chips |
| 15 | פרופיל | Present | Ledger, vehicles CRUD, availability row, privacy, sign out; **this audit** added car logos |
| 16 | זמינות editor | Present | Profile sheet (not a root tab) |
| 17 | Fill | Present | Draft stash, media tab, plate scan, complete validation; **this audit** added manufacturer/logo lookup + logos |
| 18 | Event form | Present | Create/edit, freeze, shift leads, volunteer-edit block |
| 19 | Shift form | Present | Identity lock for responders |
| 20 | Privacy overlay | Present | Login + profile |
| 21 | Feedback FAB + sheet | Present | Same hide-on-form rule |
| 22 | View-as | Present | More menu; super_admin only |
| 23 | עוד overflow | Present | `splitMobileNav` + view-as rows |
| 24 | Role-based tab bar | Present | `mobileNavEntries` / `defaultMobileView` |
| 25 | Toast / list reload | Present | `listReloadFailure` on inbox, shifts, contacts, unit lists, vehicles |

### This audit implemented

- Domain: `LoginCredentials`, `CarLogoMap`; `PlateLookupHit.manufacturer` + `tozeret_nm`; `applyTreatedPlateLookup` + logo fields on `TreatedPlate`.
- App: login/reset strip bidi marks; fill/media/profile show `CarLogo`; persist `manufacturer` / `logo_slug` on fill write + local stash; 47 PNGs from Android `assets/car-logos`.

### Evidence

- `swift test --filter YahpazDomainTests` — **337 tests, 0 failures** (was 325; +4 LoginCredentials, +5 CarLogoMap, +2 TreatedPlates, +1 PlateLookup).
- `xcodebuild -scheme Yahpaz -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build CODE_SIGNING_ALLOWED=NO` — **BUILD SUCCEEDED**.

### Unverified / still blocks “fully functional and verified”

Do **not** treat the goal as complete. Remaining is ops/device, not another phone screen:

1. **Physical-device Ad Hoc smoke** — install from `yahpz.com/ios`, sign in as responder / shift-lead / admin, walk inbox → fill → unit events/shifts → reports → admin.
2. **Force-update CTA on a registered iPhone** — `itms-services` / manifest install is not provable in Simulator.
3. **UDID enrollment** — Ad Hoc plan 2; no Android analogue; no Edge Function added.

### Deferred-no-nav (do not implement)

Cockpit, closed lists hub, broadcast, fuel quarter, Telegram `partner_bot`. `ToolsHubScreen` on Android is also unreferenced (`AdminShell` is the admin tab).

### Acceptable deltas (not gaps)

- Version numbers (Android 0.3.25/36 vs iOS 1.0.0/6).
- Session RPC still `report_android_session` / `last_android_*`.
- Android in-app APK sideload vs iOS `itms-services`.
- Field/Command visual tokens (not Compose Material).

---

## Simulator smoke 2026-09-04

**Goal is not complete.** This is Simulator-only evidence. Physical-device Ad Hoc / `itms-services` / live fill still need Omri on a registered iPhone.

### What launched

| Item | Value |
|------|--------|
| Device | `iPhone 17` Simulator, UDID `61234583-6209-415A-9FB5-D2FDF599F942` (booted) |
| Build | `xcodebuild -scheme Yahpaz -destination 'platform=iOS Simulator,id=61234583-6209-415A-9FB5-D2FDF599F942' -configuration Debug CODE_SIGNING_ALLOWED=NO` — **BUILD SUCCEEDED** |
| App | `Yahpaz.app` → `simctl install` + `simctl launch` |
| Bundle | `com.yahpz.responder` |
| Display name | אבן דרך |
| Installed version | `CFBundleShortVersionString` **1.0.0**, `CFBundleVersion` **6** (Info.plist of the installed `.app`) |
| Process | `com.yahpz.responder` PID **31677** after relaunch |
| Live `version.json` | `https://yahpz.com/ios/version.json` — `minBuild: 1`, `latestBuild: 6`, `latestVersionName: "1.0.0"` |
| Version fetch | App process logged CFNetwork **HTTP 200** to the version check (ephemeral, no-store) after launch |

No `.env`, `Config.local.xcconfig`, or `App/Secrets.plist` on disk. Simulator `UserDefaults` for this container had **no keys**. `simctl keychain` has no list/dump of stored logins (add-cert / reset only). **No safe local/dev test account** — did not invent credentials; stopped at unauthenticated surfaces.

### Screens proven (Simulator)

Screenshots under `/tmp/yahpaz-ios-smoke-2026-09-04/` (`01-after-launch.png`, `02-login-after-version-check.png`, `03-after-privacy-tap.png` — all the same login surface).

| Surface | Result |
|---------|--------|
| Launch | App reaches UI; no crash. |
| Login (Hebrew RTL) | Navy Command page + white Field card. Masthead **אבן דרך** on the trailing (right) side, **היחידה הארצית / לפינוי צירים** beside the rail. Card title **כניסה למערכת** right-aligned. Labels **דוא״ל**, placeholder **סיסמה**, primary **כניסה** (disabled while email empty), **שכחתי סיסמה**. |
| Privacy link | **מדיניות פרטיות** visible under the card. Overlay / WKWebView **not** opened (Simulator AX click failed; no tap API). Link presence is proven; in-app privacy page is not. |
| Force-update **not** blocking | After the 200 version fetch, login stays fully visible — no `ForceUpdateView`, no **הורדה והתקנה**, no optional **גרסה חדשה** sheet. Matches domain: `needsForceUpdate(6, minBuild: 1) == false`; `needsOptionalUpdate(6, 1, latest: 6) == false`. |

### Domain tests (re-run this turn)

```text
swift test --filter YahpazDomainTests
Test Suite 'YahpazDomainPackageTests.xctest' passed
  Executed 337 tests, with 0 failures (0 unexpected)
```

**337 tests, 0 failures.**

### Still only true on a registered iPhone

Do **not** treat these as Simulator-proven:

1. **Ad Hoc / OTA install** from `yahpz.com/ios` (`itms-services` + `manifest.plist`). Simulator Debug sideload is not that path.
2. **Force-update CTA** — opening `itms-services://?action=download-manifest&url=…` and completing an install. Gate *absence* is proven for build 6 vs `minBuild` 1; the install CTA is not.
3. **Signed-in walk** — inbox / fill / unit events / shifts / reports / admin / view-as. No safe test login in repo, xcconfig, or keychain.
4. **Privacy overlay content** — signed `/privacy?t=` WKWebView load. Link is on login; page not opened.
5. **Physical-device smoke** — registered UDID, trust prompt, live fill. Still Omri-only.

UDID enrollment remains Ad Hoc plan 2 (no Android analogue; no Edge Function added).

## uniqueKeys launch trap (2026-09-04, post build 7)

**Goal is not complete.** Build 7 is already live on yahpz.com/ios (`keyedLastWins` in `UnitEventsView`). Do not publish another IPA from this note.

Build 6 crash: `Dictionary(uniqueKeysWithValues:)` in `UnitEventsView` when unit list + my-active shared event IDs (signed-in admin).

Repo grep after 7:

| Site | Verdict |
|------|---------|
| `UnitEventsView.catalogById` | Already last-wins; now `mergeIdentifiedLastWins` so the test covers the production merge. |
| `MyShiftsView.mapped` | Same-class trap — `app.shifts` keyed by id. **Fixed** (`keyedLastWins`). List tab, not first paint for admin (אירועים). Duplicate shift ids from one query are unlikely; **not** a definite launch crash. |
| `YahpazAPI.syncEventResponders` | Same-class trap on `responderId`. **Fixed**. Save path only. |
| `AppModel` / `RootView` / `YahpazApp` | No force-unwrap / `uniqueKeysWithValues` on boot. |
| `UnitShiftsView` / `InboxView` | No unique-key dictionaries. |
| `App/Config.swift` `URL(string:)!` | Compile-time constants, not a launch trap. |

Verify this turn: `swift test --filter YahpazDomainTests` — **341 tests, 0 failures** (4 in `KeyedLastWinsTests`). `xcodebuild` iPhone 17 Debug `CODE_SIGNING_ALLOWED=NO` — **BUILD SUCCEEDED**.

No second definite-on-open crash. **No new IPA.** Omri should install 7.

## Drift check + Simulator smoke 2026-09-04 (evening, build 9)

**Goal is not complete.** Build 9 is already live on yahpz.com/ios. Do not publish another IPA from this note.

### Android vs last inventory

| Item | Value |
|------|--------|
| Last inventory | `6a1fe54` / **0.3.25** / **36** |
| Current `HEAD` + `origin/main` | **same SHA** `6a1fe54b3a83988a93cf94f31c8194492851201e` |
| New reachable phone screens/flows | **None** |
| Skipped | In-app APK sideload (0.3.25); no-nav cockpit / closed lists / broadcast / fuel quarter; unused `ToolsHubScreen` |

No port. No IPA.

### Simulator (unauthenticated)

| Item | Value |
|------|--------|
| Device | iPhone 17 Simulator, UDID `61234583-6209-415A-9FB5-D2FDF599F942` (iOS 26.3, already booted) |
| Build | `xcodebuild -scheme Yahpaz -destination 'platform=iOS Simulator,id=61234583-6209-415A-9FB5-D2FDF599F942' -configuration Debug CODE_SIGNING_ALLOWED=NO` — **BUILD SUCCEEDED** |
| Install / launch | `simctl install` + `simctl launch` → `com.yahpz.responder` **PID 55609** (still alive after 1 min; no crash) |
| Installed | `CFBundleShortVersionString` **1.0.0**, `CFBundleVersion` **9**, display **אבן דרך** |
| Live `version.json` | `https://yahpz.com/ios/version.json` — `latestBuild: 9`, `minBuild: 1` |
| Credentials | None on disk / sim container. Stopped unsigned. |

Screenshots: `/tmp/yahpaz-ios-smoke-2026-09-04-b/01-after-launch.png`, `02-after-settle.png`.

**AX tree (Simulator → System Events, guest UI visible):** `אבן דרך`, `היחידה הארצית`, `לפינוי צירים`, `כניסה למערכת`, `דוא״ל`, `סיסמה`, buttons `כניסה` / `שכחתי סיסמה` / `מדיניות פרטיות`. **No tab-bar buttons. No `עוד`.** Matches login-only `RootView` (`!isSignedIn` → `LoginView`).

### Tab bar / עוד — signed-in only on device; sim AX cannot show them unsigned

Code + binary (Debug dylib), not Simulator AX:

- Tab bar is `mobileTabBar` (`HStack` of `split.tabs` + optional `עוד`), not `TabView`.
- `עוד` sets `moreListVisible = true` and replaces `tabBody` with `MoreListView` (in-flow `ScrollView` list). It is **not** attached with `.sheet`.
- Debug dylib: `MoreListView` present; `MoreSheet` / `ModalBottomSheet` **absent**. Hebrew nav labels compiled in (`עוד`, `האירועים שלי`, …).
- Acceptable chrome delta vs Android: Android `RootScreen` still opens `ModalBottomSheet { MoreSheet(...) }`. iOS list is the HIG change in build 9.

### Still only true on a registered iPhone

1. Ad Hoc / OTA from `yahpz.com/ios` (`itms-services`).
2. Signed-in walk (inbox / fill / unit events / shifts / reports / admin / tap `עוד` and confirm the list).
3. Force-update CTA / physical-device smoke.

UDID enrollment remains Ad Hoc plan 2. **Do not mark the goal complete.**
