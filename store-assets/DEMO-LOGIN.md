# Demo account login: does it need a working mailbox?

**No. Email + password is enough.** Nothing on the sign-in path sends or reads mail, so
`app-review-demo@yahpz.com` works as App Review's user name even though no mailbox exists for
it. Checked against the iOS code on `feat/appstore-submit-2026-10` and the web/server code and
create script on op-yh-26 `feat/app-review-demo` (29 Oct 2026).

## The iOS sign-in path, step by step

| Step | What happens | Needs mail? | Evidence |
|---|---|---|---|
| Login screen | Email and password fields only | No | `App/Screens/LoginView.swift` |
| Sign in | `client.auth.signIn(email:password:)` (Supabase password grant) | No, if the email is already confirmed | `App/API/YahpazAPI.swift` `signIn` |
| Email confirmation | Supabase refuses unconfirmed emails; the script creates the user with `email_confirm: true` | No | `scripts/app-review-demo/lib.mjs` (`createUser`, `email_confirm: true`) |
| Login OTP (SMS) | The iOS app has **no** OTP step; the web's login OTP gate is client-side only (no RLS policy or auth hook uses `otp_login_enabled`). The script sets `otp_login_enabled: false` anyway | No | iOS: no OTP code in `LoginView`/`AppModel`; web: `src/App.tsx` `loginOtp`; no hooks in `supabase/config.toml`, migrations or functions |
| Profile load | `profiles` row must be `active`; the script sets `active: true` | No | `YahpazAPI.loadProfile`, `lib.mjs` |
| Forced password change | Shown only when `must_change_password` is true; the script sets it **false** | No | `RootView` (`mustChangePassword` → `ProfileView`), `lib.mjs` |
| Magic link / invite | Not used by iOS; the script never invites (`createUser`, no `inviteUser`/`generateLink`) | No | `lib.mjs` header comment and code |
| Push prompt | Asks for notification permission after login; no mail | No | `PushRegistration.requestAfterSignIn` |

**The only mail-dependent action** is "שכחתי סיסמה" (password reset), which App Review does
not need. Password changes go through the script instead: `--rotate-password` generates a new
one into `~/.yahpz-secrets/app-review-demo.env`.

## What the create script sets (`scripts/app-review-demo/lib.mjs`)

- Demo account `app-review-demo@yahpz.com`, "App Review דמו", או״ק `דמו-1`: responder only,
  `is_app_review_demo: true`, `active: true`, `must_change_password: false`,
  `otp_login_enabled: false`, no phone, `email_confirm: true`.
- Password: generated at run time, set last (after the flag), written only to
  `~/.yahpz-secrets/app-review-demo.env` (mode 600), never printed.
- Demo lead `app-review-demo-lead@yahpz.com`: banned, no password, never signs in.
- Demo events 4127, 4128, 4129, a demo shift, vehicle `00-000-01`, one map pin at
  מחלף גלילות. No email, SMS or push is sent.

## Is the address deliverable?

No. `yahpz.com` has **no MX record** and its SPF is `v=spf1 -all` (DNS lookup, 29 Oct), so mail
to `app-review-demo@yahpz.com` cannot be delivered. That matters only if someone triggers a
password reset or an email change for the account; the mail would bounce. It does not affect
sign-in.

## Options

1. **Recommended: keep `app-review-demo@yahpz.com`, password only.** No change, no mailbox.
   App Review only needs the user name and password typed into App Store Connect.
2. **If you want a reachable inbox** (to be able to use "forgot password" on it), use
   plus-addressing on a mailbox you already have, e.g. `omriland+yahpz-review@gmail.com`:
   Gmail delivers `+tag` addresses to the base inbox, so nothing new is created. The change is
   one constant: `DEMO_USER.email` in `scripts/app-review-demo/lib.mjs` (line 24), plus the
   address in that folder's `README.md` and `lib.test.mjs`. The remove script imports the same
   constant, and nothing in the migrations or the app hard-codes the address. Change it
   **before** the first production run; after that, the old account must be removed first,
   because both scripts refuse to touch an unflagged account with a demo address.

   I did not make this change: option 1 already works, and the other session
   (`yahpz-web-appreview`) is active in that worktree and owns the deploy.

## What App Store Connect needs

User name: the address above (or the option-2 address). Password: type it from
`~/.yahpz-secrets/app-review-demo.env`. "Sign-in required" on. No mailbox access is shared
with Apple, and Apple does not email demo accounts.
