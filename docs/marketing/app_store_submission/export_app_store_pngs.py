#!/usr/bin/env python3
"""
Upscale docs/marketing halide_image_*.png assets to App Store Connect sizes.

Apple requires PNG/JPEG without transparency for screenshots. Sources are
composited on black, then scaled with LANCZOS and letterboxed to exact pixels.

See: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
"""
from __future__ import annotations

import os
from pathlib import Path

from PIL import Image

_MKT = Path(__file__).resolve().parent.parent  # docs/marketing
SRC_GRID = _MKT / "halide_image_grid.png"
SRC_VIEW = _MKT / "halide_image_view.png"
OUT = Path(__file__).resolve().parent

# (label_for_filename, width, height) portrait
TARGETS = [
    ("iphone_6.9_display", 1290, 2796),
    ("iphone_6.5_display", 1284, 2778),
    ("iphone_6.3_display", 1206, 2622),
]


def flatten_rgb(im: Image.Image) -> Image.Image:
    if im.mode != "RGBA":
        return im.convert("RGB")
    bg = Image.new("RGB", im.size, (0, 0, 0))
    bg.paste(im, (0, 0), im)
    return bg


def contain_center(canvas_w: int, canvas_h: int, im: Image.Image) -> Image.Image:
    """Scale image to fit inside canvas (contain), center on black RGB canvas."""
    im = flatten_rgb(im)
    w, h = im.size
    scale = min(canvas_w / w, canvas_h / h)
    nw, nh = max(1, int(round(w * scale))), max(1, int(round(h * scale)))
    resized = im.resize((nw, nh), Image.Resampling.LANCZOS)
    out = Image.new("RGB", (canvas_w, canvas_h), (0, 0, 0))
    x = (canvas_w - nw) // 2
    y = (canvas_h - nh) // 2
    out.paste(resized, (x, y))
    return out


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    grid = Image.open(SRC_GRID)
    view = Image.open(SRC_VIEW)

    for label, tw, th in TARGETS:
        g = contain_center(tw, th, grid)
        v = contain_center(tw, th, view)
        gp = OUT / f"{label}_{tw}x{th}_01_image_grid.png"
        vp = OUT / f"{label}_{tw}x{th}_02_image_view.png"
        g.save(gp, format="PNG", optimize=True)
        v.save(vp, format="PNG", optimize=True)
        print("Wrote", gp.name, vp.name)

    readme = OUT / "README.txt"
    readme.write_text(
        "App Store Connect screenshot exports generated from docs/marketing/halide_image_*.png\n"
        "\n"
        "Sizes follow Apple’s screenshot specifications (portrait):\n"
        "- 6.9\" display: 1290 × 2796\n"
        "- 6.5\" display: 1284 × 2778\n"
        "- 6.3\" display: 1206 × 2622\n"
        "\n"
        "Upload the 6.9\" set for current iPhone requirements; Apple scales down for other\n"
        "phones if you only provide one size. Use PNG or JPEG without transparency.\n"
        "\n"
        "Regenerate: python3 export_app_store_pngs.py\n",
        encoding="utf-8",
    )
    print("Wrote", readme.name)


if __name__ == "__main__":
    main()
