# iOS ↔ Android parity gap (Android 0.3.26 → 0.3.47)

**Written:** 2026-10-22, before any implementation on `feat/android-parity-appstore`.
**Closed:** 2026-10-22 on the same branch. All 28 items ported; 426 domain tests green
(`swift test`), app builds clean for simulator and Release.
**Android:** `yahpaz-android` `main` @ `72b29b0` — 0.3.47 / versionCode 61 (read only).
**iOS base:** `feat/android-parity` @ `7f00c62` — 1.0.2 (16).

## How this list was built

The previous inventory (`docs/superpowers/plans/2026-09-04-ios-android-parity-gap.md`) closed parity
at Android **0.3.25** (`6a1fe54`). The iOS commits after it ported only part of what Android shipped
next, so this audit starts at 0.3.25, not at the 10 Sep sync date:

- every Android commit `6a1fe54..72b29b0` was read in full (25 commits, `app/src` + `domain/src`);
- each change was checked against the iOS code (`Sources/YahpazDomain`, `App/`), not against commit
  messages;
- the current Android domain files were compared with their iOS ports, and the domain test suites were
  compared name by name.

Already on iOS and **not** listed below: 0.3.31 (אחמ״ש משני may edit), 0.3.33 (אמצעים on by default),
0.3.34 (equal odometers allowed, shift-born plates on event detail), 0.3.35 (junction search), and most
of 0.3.36 (form sections, field notes, split או״ק fields, event-level start/end with עכשיו).

Android-only, out of scope for iOS: Play in-app updates and install-source detection (0.3.46), Target SDK
36, APK sideload, FCM. Screens with no Android nav entry (Cockpit, ClosedLists, Broadcast,
FuelQuarter/ToolsHub) stay out, as in the previous audit.

## Gap list

Status is filled in as each item lands. `Done` means ported, with domain tests where the rule lives in
`YahpazDomain`.

### Responders (everyone with a mine list)

| # | Android | What changed on Android | iOS before this branch | Status |
|---|---|---|---|---|
| R1 | 0.3.26 | Leftover-plate copy is `יש ללחוץ הוספה לשמירת המספר`; that error shows only under the plate field, not as a form error or toast | Old copy `השלימו או מחקו את המספר בתחתית.`, shown twice | Done |
| R2 | 0.3.27, 0.3.37 | Own stamp says `סיימת לתעד` (green) while lead KM is missing. If the event has no end time (non-shift), the own stamp is `תועד חלקית` with note `ממתין לפרטים נוספים מאחמש`. No lead note on shift-born events | Always `הושלם` + KM note | Done |
| R3 | 0.3.37 | Event detail paints missing lead fields red (מספר אירוע, סוג, כביש, מיקום) | Plain rows | Done |
| R4 | 0.3.38, 0.3.40 | Manual events are **held from responders** until מספר אירוע, כביש and או״ק number are all filled: hidden from pending and logged lists, fill cannot open, no fill CTA. Shift-born events are never held | Shown as soon as assigned | Done |
| R5 | 2e0ceb8 | Before saving a fill, list treated vehicles with no photo on the event (`לא צורפו תמונות לרכבים הבאים:`), with `חזרה לעריכה` / `שמירה ללא תמונות נוספות`. Another responder's photo of the same plate counts | No check | Done |
| R6 | 0.3.46 | Fill autosaves a draft to the server (debounced, only when draft-valid) and flushes on leave and on background. Copy: `נשמר אוטומטית במכשיר …` / `הפרטים נשמרים אוטומטית במכשיר ובענן עד לשליחה.` | Device-only stash | Done |
| R7 | 0.3.46 | Availability: tapping זמין / לא זמין saves at once; לא זמין + date autosaves after 800 ms; `השינויים נשמרים אוטומטית.` | Save button only | Done |
| R8 | 0.3.46 | Profile vehicles: leaving an edited vehicle row saves it if plate + model are valid | Lost unless saved | Done |
| R9 | 0.3.46 | Force-update gate is re-checked when the app returns to foreground, not only at launch | Launch only | Done |
| R10 | 0.3.37 | Fuel note: `שימו לב! אירועים שטרם תועדו על ידי המתנדב, או ללא ק״מ, אינם נכללים בהחזר הדלק הרבעוני` | Old copy | Done |
| R11 | 0.3.28, 0.3.29, 0.3.36 | **מפה tab** for every signed-in user (`map` in the עוד overflow): unit address pins from `list_unit_map_pins` (no admin/basic-training/shifts-only), colour by availability and phone-training, clustering at zoom ≤ 10, name chips at zoom ≥ 12, legend, layers sheet (police station boundaries; mile posts at zoom ≥ 14, on by default), address search → `מתנדבים קרובים` within 30 km, live en-route pins for leads (5 s poll, 30 s stale) | No map at all | Done |

### Shift leads and admins

| # | Android | What changed on Android | iOS before this branch | Status |
|---|---|---|---|---|
| L1 | 2e0ceb8, 0.3.40 | Event times live on the event only. Responder rows no longer carry their own start/end; every assignment is written with the event's times. Incomplete `שעות` uses event times when set; callsign chip label `אוק - מס` | Times copied onto each responder draft; responder detail shows its own times | Done |
| L2 | 2e0ceb8 | **7-day edit lock** for non-admins: edit disabled with `לא ניתן לערוך אירוע שנוצר לפני מעל ל-7 ימים`, toast on open, locked form state (delete still offered to owner/admin), server write refused | No lock | Done |
| L3 | 2e0ceb8 | מספר אירוע input capped at 5 digits | 7 digits | Done |
| L4 | 0.3.30, 2e0ceb8 | Assigned responder rows show a caption (`12 ק״מ`, or `ק״מ` when empty) and a chevron, with an accessible label | Name only | Done |
| L5 | 0.3.32, 0.3.33 | Removing a responder with lead data asks `האם אתה בטוח שברצונך להסיר את {שם}?`. An unsaved assignment's default אמצעים does not count | Removes at once | Done |
| L6 | 0.3.38 | Remove או״ק and מיקום placeholders | Placeholders shown | Done |
| L7 | 0.3.40 | Create needs only date + סוג (+ מיקום on the system שלוחה). כביש and או״ק may be empty; copy `יש למלא תאריך וסוג אירוע כדי ליצור אירוע.` Form and detail show `האירוע לא יוצג למתנדב עד שאו״ק, כביש ומספר אירוע מלאים.`; list chips add `לא נשלח למתנדבים` | Road required | Done |
| L8 | 0.3.41 | Same-day duplicate מספר אירוע is refused before writing (`כבר קיים אירוע עם המספר הזה באותו תאריך.`), and a unique violation maps to the same copy. Error sits under the field and clears on edit | Generic save failure | Done |
| L9 | 0.3.42 | Done-guard: write the event row as `partial` before responders, then promote to `done`. Map the DB guard messages (`לא ניתן להשלים אירוע …`) instead of the network toast | Writes `done` first; guard 400s look like network errors | Done |
| L10 | 0.3.43 | **Edit writes only changed columns** (event row, responder lead fields, treated vehicles, secondary leads), so entering KM cannot null location, notes or anything else | Full-row rewrite on every save | Done |
| L11 | 0.3.43 | Event form autosaves quietly (800 ms debounce, serialized writes) and flushes the last keystrokes when the form closes. Copy `שומר…` / `השינויים נשמרים אוטומטית.` | Explicit save only | Done |
| L12 | 0.3.46 | New-event draft is stashed on the device (24 h) and restored on reopen; `הטיוטה נשמרת אוטומטית במכשיר.` | Lost on close | Done |
| L13 | 0.3.46 | Shift form: new shift stashed on device; edits autosave (800 ms) and flush on close | Explicit save only | Done |
| L14 | 0.3.46 | Owner/admin may delete an event even with responders (`יש מתנדבים משובצים באירוע. הפעולה תמחק גם את הנתונים שלהם…`), via the `delete_event` RPC | Blocked when responders exist | Done |
| L15 | 0.3.47 | When `events.started_at`/`ended_at` is NULL and the form prefilled it from a responder, the next save persists it | Never persisted | Done |
| L16 | 2e0ceb8, 0.3.38 | Unit event detail: `אוק`, `שעת התחלה`, `שעת סיום` rows (red when missing); per-responder time rows removed; lead KM shown as `ק״מ (אחמ״ש)` only to lead roles, red when missing | Old layout; KM visible to responders | Done |
| L17 | 4623acd | KM-exception threshold 60 → **80** (freeze copy, report, KM exceptions) | 60 | Done |

## Where iOS deliberately differs

- **Fill autosave (R6) writes only after a real change.** On Android every draft save also sets
  `event_responders.status = in_progress`, and the autosave fires on the initial draft, so merely
  opening a pending fill turns it into `טיוטה נשמרה`. iOS saves only when the draft differs from what
  the server returned. **Worth fixing on Android too.**
- **New-event device stash (L12).** On Android, tapping `יצירת אירוע` within 800 ms of the last
  keystroke (before any quiet autosave created the row) leaves `createdEventId` empty, so the
  leave-flush stashes the event it just created and the next `אירוע חדש` restores it. iOS records the
  created id on every successful create. **Same one-line fix applies to Android.**

An independent review of the write path found more problems that Android (and in one case the web)
share. iOS fixes them; Android still has them:

| Problem on Android today | iOS on this branch |
|---|---|
| Leave-flush that creates the event leaves its device stash, so the next `אירוע חדש` restores it and autosave inserts a duplicate | Stash carries its form session and is cleared once that session's row exists |
| A create that inserted the row but failed later (responders, leads) is forgotten, so the next autosave inserts another event | The returned id is kept; the next save updates that row |
| A failed or cancelled vehicle lookup marks every responder vehicle-less, and the next edit nulls every lead KM | Lookup failures leave the crew untouched |
| An autosave deletes assignments that another lead (or a shift sync) added since the form loaded, with their documentation | Only responders removed in this form are deleted |
| Adding a pending responder to a `done` event leaves the row `done` (both sides persist as `partial`, so the diff skips `status`), which locks the new responder's fill. **The web `eventForm.ts` has the same gap** | Status is written whenever the derived status changed |
| Fill and shift writes can interleave (plates deleted and re-inserted twice; duplicate crew rows) | One write queue per kind (event, fill, shift), outside the screen's lifetime |
| A just-created shift is re-stashed as a new draft on close | Not stashed after a create |
| Device stashes are global, so the next user on the phone inherits them | Scoped to the user who typed them |
| Creating an event with another lead as main: save and autosave refuse silently (the foreign-lead ack is not limited to editing) | Ack required only when editing |

## Notes on platform differences

- **Map (R11).** Android uses Google Maps and Places with `MAPS_API_KEY`. iOS has no Google key since
  `72bced6`, so the iOS port uses MapKit for tiles, pins and polygons, and `MKLocalSearchCompleter` for
  address search. Same data, same rules (shared `OpsMap` domain port), no key to manage. The Google-only
  error copy (`יש לבחור כתובת מרשימת Google.`) becomes `יש לבחור כתובת מהרשימה.` on iOS.
- **Store updates (R9).** Android 0.3.46 sends Play installs to the Play Store. The iOS equivalent is an
  App Store install: it must open the App Store page, never the Ad Hoc `itms-services` link. That is
  also an App Store review requirement; see `docs/HANDOFF-appstore.md`.
