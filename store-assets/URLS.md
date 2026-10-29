# URLs for App Store Connect

Checked on 29 Oct 2026 with `curl`, logged out, no cookies. No browser was used.

| Field | URL | Use it? |
|---|---|---|
| Privacy Policy URL (required) | `https://yahpz.com/privacy` | **Yes**. Real policy page, see below |
| Support URL (required) | `https://yahpz.com/privacy` | **Yes, for now**. It is the only public page with contact details; see below |
| Marketing URL (optional) | `https://yahpz.com` | Optional. Public home page; it is the login screen with the unit's description |
| Data deletion (not an ASC field) | `https://yahpz.com/delete-data` | Cite it in the review notes |

## Privacy policy: `https://yahpz.com/privacy`

**Verdict: a real privacy policy page that loads logged out.** The site is a single-page app,
so the HTTP status alone proves nothing:

| Request | Result |
|---|---|
| `GET /privacy` | 200, `text/html`, 4.7 KB: the shared SPA shell (`index.html`) |
| `GET /this-route-does-not-exist-zz` | 200, the same shell (Netlify `/* → /index.html` rewrite in `netlify.toml`) |
| `GET /delete-data` | 200, same shell |

So the content check was done on the route and on the deployed bundle:

- **Route** (`../op-yh-26/src`): `lib/privacyPageToken.ts` defines `PRIVACY_PATH = '/privacy'`;
  `lib/appRoute.ts` maps it to `legalPage: 'privacy'`; in `App.tsx`, with no session
  (`!session && legalPage === 'privacy'`) the app renders `PrivacyPolicyPage` with no login
  wall. The `?t=` HMAC token only changes the embedded variant the iOS app opens; it is not
  needed to read the page.
- **Deployed bundle**: the live `assets/index-C2YvRNI7.js` contains the policy text from
  `lib/privacyPolicy.ts`: title מדיניות פרטיות, product line, effective date 05.10.2026,
  sections 1 to 8 (collection, use, third parties, security, Israeli law, changes, contact) and
  the contact email and address. The `/privacy` route check is in the same bundle.

What a reviewer sees in a browser: the Hebrew policy with a back button, rendered by
JavaScript. The page adds `noindex`, which does not matter to App Review.

### Gaps between the policy and what the iOS app collects

Apple expects the policy to name what the app collects (guideline 5.1.1(i)). The current
text covers identity, contact, operational records, vehicles, incident location and IP and
access logs. It does **not** mention:

1. Photos and short videos (event photos on the fill screen, feedback attachments).
2. Voice recordings (feedback voice note).
3. The push notification token and the app version and last-seen time the app reports.

None of this blocks a submission today, but a reviewer comparing the label to the policy can
ask. The fix is a short addition to `op-yh-26/src/lib/privacyPolicy.ts` (section 2.1), which
is outside this repo, so it is listed as an open question in AUDIT.md.

## Support URL

`https://yahpz.com` is the login page. It has a privacy link but no contact details, and
Apple asks that the support URL lead to a way to contact you. Until there is a support page,
use `https://yahpz.com/privacy`: its section 8 gives the contact email and address. A small
`/support` page on the web app would be cleaner (open question in AUDIT.md).

## Account deletion: `https://yahpz.com/delete-data`

Live and public (`DeleteDataPage.tsx`: a deletion request by email to the policy contact).
Accounts are created by unit administrators, never by sign-up in the app, so guideline
5.1.1(v) (in-app deletion for apps that offer account creation) should not apply. The review
notes still point to this page in case a reviewer asks.
