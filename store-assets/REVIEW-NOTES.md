# App Review information

App Store Connect → the 1.0.2 version page → App Review Information.

## Notes for the reviewer (paste into "Notes")

```
Even Derech (אבן דרך) is the internal app of the Israeli National Road Clearance Unit (יחפ״צ), a volunteer unit that clears stuck vehicles and obstacles from highways. It is for authorized members only: there is no public sign-up. Accounts are created by the unit's administrators, and members sign in with the same email and password they use on https://yahpz.com.

Please sign in with the demo account in the Sign-In Information fields. It is a regular volunteer (responder) account with demo data only.

What to try:
1. האירועים שלי (My events): events waiting for this member's report and events already reported.
2. Tap "השלמת התיעוד שלי" / "המשך התיעוד" on an event to complete your part: vehicle, odometer start and end, route, treated vehicles' plates (the camera can read a plate), photos.
3. המשמרות שלי (My shifts), and under עוד (More): מפה (Map) and פרופיל (Profile), where availability is updated.
4. The round speech-bubble button opens the feedback form (bug or suggestion, text, optional voice note or screenshot).

Permissions: the camera is used only to read a licence plate on the event report screen; the microphone only for the optional voice note in the feedback form. The app does not use location and has no background modes.

Data deletion: accounts are created and removed by the unit. Members can request deletion of their data at https://yahpz.com/delete-data.

The interface is Hebrew only, right to left. Encryption: HTTPS only (ITSAppUsesNonExemptEncryption = false).
```

Length: 1,499 characters (the field allows 4,000).

## Sign-in information

| Field | Value |
|---|---|
| Sign-in required | **Yes**. Every screen except login is behind sign-in, so App Review cannot test anything without an account (guideline 2.1) |
| User name | the demo account's email (see below) |
| Password | typed by Omri into App Store Connect. **Not stored in this repo or in any file I wrote** |

## The existing test account

- **Where it was loaded from**: `yahpz-onboarding-video/.test-login.env`, variables
  `YAHPZ_TEST_EMAIL` and `YAHPZ_TEST_PASSWORD`, read at runtime by the onboarding video's
  Playwright script (`yahpz-onboarding-video/PHASE2.md`).
- **Current state**: `yahpz-volunteer-video/BRIEF.md` says that file was deleted after
  recording, and it is not on this Mac. I did not look for the credentials anywhere else.
- **Role**: not verified (that would need the credentials or a database read). The onboarding
  brief used it to create demo events and as the secondary אחמ״ש, so it most likely has the
  shift-lead or admin role, not plain responder.

## Is it suitable for App Review? No, not as it is

1. **Real people's data.** Any active account sees every active member's name, phone and
   email in אנשי קשר (RPC `list_unit_contacts`) and every member's saved home and work
   address on the map (RPC `list_unit_map_pins`). The RPCs filter only on "caller is active"
   (`op-yh-26/supabase/migrations/20260816143142_list_unit_contacts.sql`,
   `20260827100000_list_unit_map_pins_skip_invite_pending.sql`). A reviewer would see real
   volunteers' personal details.
2. **Real incidents.** A shift-lead or admin account also sees the unit's real events
   (police event numbers, roads, locations, names).
3. **Live writes.** Whatever the reviewer saves (a report, availability, feedback) lands in
   production, and lead actions such as assigning volunteers can notify real people.

**What a suitable account looks like:** a new responder-only account (for example
"App Review דמו"), login OTP off, assigned only to two or three demo events labelled דמו, and
a server-side rule so `list_unit_contacts` and `list_unit_map_pins` return only demo rows to
that account. That rule is a web-repo change (`op-yh-26`) and is Omri's call; it is listed
under Open questions in AUDIT.md.

Login OTP does not get in the way: the iOS app has no OTP step, so no SMS is involved.

## Contact information

| Field | Value |
|---|---|
| First and last name | Omri Landman |
| Email | the address you use for App Store Connect |
| Phone | your number |

## Attachment (optional)

None needed. If App Review asks how the volunteer flow works, the screenshots in
`store-assets/screenshots/` show it on demo data.
