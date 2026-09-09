#!/usr/bin/env python3
"""Render App Store screenshots at Apple's accepted portrait sizes."""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HTML = Path(__file__).resolve().parent / "screens.html"
OUT = Path(__file__).resolve().parent / "screenshots"
ICON_SRC = ROOT / "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
SCREENS = ("login", "inbox", "shifts", "availability", "tracking")
SIZES = (
    ("iphone-6.9-1290x2796", 430, 932, 3),
    ("iphone-6.5-1242x2688", 414, 896, 3),
    ("iphone-6.9-1320x2868", 440, 956, 3),
)


def main() -> int:
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print("pip install playwright && python3 -m playwright install chromium", file=sys.stderr)
        return 1

    if not HTML.exists():
        print(f"missing {HTML}", file=sys.stderr)
        return 1

    OUT.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ICON_SRC, Path(__file__).resolve().parent / "AppIcon-1024.png")

    with sync_playwright() as p:
        browser = p.chromium.launch()
        for folder, width, height, scale in SIZES:
            dest = OUT / folder
            dest.mkdir(parents=True, exist_ok=True)
            context = browser.new_context(
                viewport={"width": width, "height": height},
                device_scale_factor=scale,
                locale="he-IL",
            )
            page = context.new_page()
            for index, screen in enumerate(SCREENS, start=1):
                page.goto(HTML.as_uri() + f"?screen={screen}", wait_until="networkidle")
                page.evaluate("async () => { await document.fonts.ready }")
                page.wait_for_timeout(150)
                path = dest / f"{index:02d}-{screen}.png"
                page.screenshot(path=str(path), type="png")
                print(path.relative_to(ROOT), flush=True)
            context.close()
        browser.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
