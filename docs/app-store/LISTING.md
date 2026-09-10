# App Store listing — אבן דרך

Paste into App Store Connect. Primary locale: **Hebrew (Israel)**. English listing is not required.

Character counts are Unicode length (Apple's limit).

## Name
Limit 30. Current: 7.

```
אבן דרך
```

## Subtitle
Limit 30. Current: 26.

```
אפליקציית הכוננים של יחפ״צ
```

## Promotional text
Limit 170. Optional. Can change without a new binary. Current: 85.

```
תיעוד אירועים, משמרות וזמינות לכונני היחידה הארצית לפינוי צירים. אותו חשבון כמו באתר.
```

## Description
Limit 4000.

```
אבן דרך היא אפליקציית הכוננים של היחידה הארצית לפינוי צירים (יחפ״צ).

האפליקציה מיועדת לאנשי יחידה מורשים בלבד. הכניסה היא בדוא״ל וסיסמה, באותו חשבון של האתר yahpz.com.

מה אפשר לעשות באפליקציה:

• האירועים שלי: לראות מה ממתין לתיעוד ומה כבר תועד, ולהשלים את הפרטים מהשטח.
• המשמרות שלי: לעקוב אחרי משמרות ממתינות, עתידיות ותועדו.
• זמינות: לעדכן אם אתם זמינים לשיבוץ. הסטטוס מוצג לאחמ״ש.
• פרופיל: שם, או״ק וסיכום פעילות.
• שיתוף מיקום: בזמן אירוע פתוח אפשר לשתף מיקום עם האחמ״ש, כולל כשהמסך כבוי. אפשר לעצור בכל רגע ממסך המעקב.

האפליקציה בעברית בלבד, מימין לשמאל.
```

## Keywords
Limit 100, comma-separated. Do not repeat the app name. Current: 52.

```
כונן,כוננים,יחפצ,פינוי צירים,משמרת,זמינות,תיעוד,אחמש
```

## What's New
Limit 4000. Version 1.0.0.

```
גרסה ראשונה לכוננים: כניסה, האירועים שלי, המשמרות שלי, זמינות, פרופיל ושיתוף מיקום בזמן אירוע.
```

## URLs

| Field | Value |
|---|---|
| Privacy Policy | https://yahpz.com/privacy |
| Support URL | https://yahpz.com |
| Marketing URL | https://yahpz.com |
| Copyright | 2026 Omri Landman |

Confirm `https://yahpz.com/privacy` loads in a private browser before submit. The page already exists on the web app.

## Category

- Primary: Productivity (`public.app-category.productivity`, already in the Xcode project)
- Secondary (optional): Utilities

## Screenshots to upload

Upload the 6.9" set first. Apple accepts 1290×2796 or 1320×2868 for that class, then scales down. The 6.5" set is a fallback if you skip 6.9".

Order (same in every size folder):

1. `01-login.png` — כניסה
2. `02-inbox.png` — האירועים שלי
3. `03-shifts.png` — המשמרות שלי
4. `04-availability.png` — זמינות
5. `05-tracking.png` — שיתוף מיקום

Folders:

- `screenshots/iphone-6.9-1290x2796/` (also valid as the old 6.7" size)
- `screenshots/iphone-6.9-1320x2868/` (native iPhone 16/17 Pro Max)
- `screenshots/iphone-6.5-1242x2688/`

Inbox uses a **תרגול יחידה** card with a date only. No police event number, road, or live-incident location.
