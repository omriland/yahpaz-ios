# App Review information

App Store Connect → the 1.0.2 version page → App Review Information.

## Notes for the reviewer (paste into "Notes")

```
Even Derech (אבן דרך) is the internal app of the Israeli National Road Clearance Unit (יחפ״צ), a volunteer unit that clears stuck vehicles and obstacles from highways. It is for authorized members only: there is no public sign-up. Accounts are created by the unit's administrators, and members sign in with the same email and password they use on https://yahpz.com.

Please sign in with the demo account in the Sign-In Information fields. It is a regular volunteer (responder) account limited to demo data: the events, contacts and map points it sees are demo records, not real people or incidents.

What to try:
1. האירועים שלי (My events): events waiting for this member's report and events already reported.
2. Tap "השלמת התיעוד שלי" / "המשך התיעוד" on an event to complete your part: vehicle, odometer start and end, route, treated vehicles' plates (the camera can read a plate), photos.
3. אנשי קשר (Contacts): the unit's members, with call and message actions.
4. Under עוד (More): מפה (Map) and פרופיל (Profile), where availability is updated.
5. The round speech-bubble button opens the feedback form (bug or suggestion, text, optional voice note or screenshot).

Permissions: the camera is used only to read a licence plate on the event report screen; the microphone only for the optional voice note in the feedback form. The app does not use location and has no background modes.

Help: https://yahpz.com/support. Data deletion: accounts are created and removed by the unit; members can request deletion of their data at https://yahpz.com/delete-data.

The interface is Hebrew only, right to left. Encryption: HTTPS only (ITSAppUsesNonExemptEncryption = false).
```

Length: 1,671 characters (the field allows 4,000).

The notes point to `https://yahpz.com/support`, which goes **live with the op-yh-26 deploy**.
Do not submit before that page loads logged out.

## Sign-in information

| Field | Value |
|---|---|
| Sign-in required | **Yes**. Every screen except login is behind sign-in, so App Review cannot test anything without an account (guideline 2.1) |
| User name | The App Review demo account's email, as created by the provisioning script (planned: `app-review-demo@yahpz.com`; use whatever the script reports) |
| Password | **Typed by Omri** from `~/.yahpz-secrets/app-review-demo.env`. It is not in this repo or in any file I wrote, and nothing here reads that file |

## The demo account

**Account to use: the `app-review-demo` account**, created by the provisioning script being
built in a separate session in `op-yh-26` (worktree `../op-yh-26-appreview`, branch
`feat/app-review-demo`). It is created only after you approve that deploy. I did not edit
op-yh-26.

What that work sets up, per its brief (`op-yh-26-appreview/APP-REVIEW-BRIEF.md`):

- A server-side App Review demo flag on the profile (e.g. `profiles.is_app_review_demo`),
  settable only by admins or the service role. For a flagged account, which must be
  **responder-only**, everything it can reach returns demo rows only: events, contacts
  (`list_unit_contacts`), map pins (`list_unit_map_pins`). It cannot read real profiles,
  clear its own flag or trigger notifications.
- `scripts/app-review-demo/create-app-review-demo.*`: creates the auth user directly (no
  invite email), sets the flag and the responder role, turns login OTP off, and adds two or
  three demo events labelled "דמו - App Review" (for example event 4127). The password goes to
  `~/.yahpz-secrets/app-review-demo.env` (chmod 600) and is never printed. There is a matching
  teardown script.

Order: deploy the migration and functions (your approval) → run the provisioning script →
sign in on a phone with the demo account and check the list below → paste the email and type
the password into App Store Connect.

Check on a phone before submitting:

- [ ] Sign-in works, with no OTP step (the iOS app has none).
- [ ] האירועים שלי shows only the "דמו - App Review" events.
- [ ] אנשי קשר and מפה show only demo people, no real names, phones or addresses.
- [ ] Saving a report on a demo event works and notifies nobody.

The old test account (`yahpz-onboarding-video/.test-login.env`, deleted after the video) is
**not** used.

## Contact information

| Field | Value |
|---|---|
| First and last name | Omri Landman |
| Email | the address you use for App Store Connect |
| Phone | your number |

## Attachment (optional)

None needed. If App Review asks how the volunteer flow works, the screenshots in
`store-assets/screenshots/` show it on demo data.
