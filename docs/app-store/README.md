# App Store package

Paste-ready listing for the first App Store submission of אבן דרך (`com.yahpz.responder`). Does not upload anything.

| File | What |
|---|---|
| [LISTING.md](LISTING.md) | Name, subtitle, description, keywords, what's new, URLs |
| [CHECKLIST.md](CHECKLIST.md) | Icon, version, privacy manifest, location strings |
| [CONNECT.md](CONNECT.md) | App Store Connect click-list |
| [screenshots/](screenshots/) | 6.9" (1290 and 1320) and 6.5" PNG sets |
| [AppIcon-1024.png](AppIcon-1024.png) | Store icon copy |
| [screens.html](screens.html) | Source for the screenshots |
| [generate-screenshots.py](generate-screenshots.py) | Regenerates the PNGs |

Regenerate screenshots:

```bash
python3 -m venv /tmp/yahpaz-store-venv
/tmp/yahpaz-store-venv/bin/pip install playwright
/tmp/yahpaz-store-venv/bin/python -m playwright install chromium
/tmp/yahpaz-store-venv/bin/python docs/app-store/generate-screenshots.py
```
