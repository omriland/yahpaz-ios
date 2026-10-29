# App Store listing: אבן דרך (Hebrew)

Primary language: **Hebrew**. Character counts are Unicode characters, which is how App Store
Connect counts them (״ counts as one). Counts were checked with a script, not by hand.

Everything here matches build 1.0.2 (17) as it ships: live tracking is compiled out of that
build, so the listing does not mention שיתוף מיקום.

## Name (limit 30): 7

```
אבן דרך
```

Same as `CFBundleDisplayName`. If App Store Connect says the name is taken, use
`אבן דרך - יחפ״צ` (15) and keep the home-screen name unchanged.

## Subtitle (limit 30): 26

```
אפליקציית הכוננים של יחפ״צ
```

## Promotional text (limit 170): 115

Can change at any time without a new build.

```
תיעוד אירועים ומשמרות, עדכון זמינות ומפת היחידה, לכונני היחידה הארצית לפינוי צירים. כניסה באותו חשבון של yahpz.com.
```

## Description (limit 4000): 987

```
אבן דרך היא אפליקציית הכוננים של היחידה הארצית לפינוי צירים (יחפ״צ).

האפליקציה מיועדת לאנשי יחידה מורשים בלבד. אין בה הרשמה: החשבון נפתח על ידי מנהלי היחידה, והכניסה היא בדוא״ל וסיסמה, באותו חשבון של האתר yahpz.com.

מה אפשר לעשות באפליקציה:

• האירועים שלי: לראות אילו אירועים ממתינים לתיעוד ואילו כבר תועדו, ולחפש לפי מספר אירוע, כביש או מיקום.
• השלמת התיעוד שלי: רכב, מד אוץ בתחילה ובסיום, מסלול, פרטי הטיפול ולוחיות רישוי של רכבים שטופלו, כולל סריקת לוחית במצלמה ותמונות מהשטח. הפרטים נשמרים אוטומטית עד לשליחה.
• המשמרות שלי: משמרות שממתינות לתיעוד, משמרות עתידיות ומשמרות שתועדו.
• זמינות: לעדכן אם אתם זמינים לשיבוץ. הסטטוס מוצג לאחמ״ש.
• מפה: מתנדבי היחידה על המפה, שכבות תחנות משטרה ועמודי קילומטר, וחיפוש כתובת שמראה מי קרוב.
• אנשי קשר: רשימת אנשי היחידה.
• פרופיל: פרטים אישיים, הרכבים שלי וסיכום פעילות.
• משוב: לדווח על באג או להציע שיפור, בכתב, בהקלטה או עם צילום מסך.

לאחמ״שים ולמנהלים יש גם ניהול אירועים ומשמרות של היחידה ודוחות.

האפליקציה בעברית בלבד, מימין לשמאל.
```

## Keywords (limit 100): 76

Comma-separated with no space after commas, no words from the app name (אבן, דרך).

```
כונן,כוננים,יחפצ,פינוי צירים,משמרות,זמינות,תיעוד אירועים,אחמש,מתנדבים,כבישים
```

## What's New (version 1.0.2): 111

```
הגרסה הראשונה ב-App Store: האירועים שלי והשלמת התיעוד, המשמרות שלי, זמינות, מפת היחידה, אנשי קשר, פרופיל ומשוב.
```

## What the copy deliberately leaves out

- **שיתוף מיקום / מעקב חי**: not operational, and compiled out of this build (see AUDIT.md).
- **Push notifications**: the app asks for permission and registers the device, but whether
  the server sends iOS pushes was not verified, so the listing does not promise them.
- **Hebrew-only**: no English localization; none is needed for an Israel-only release.
