#!/usr/bin/env python3
"""
Selective negative-film inversion for smartphone photos of film on a backlight.

Only the film strip (polygon mask) is converted to a positive; the rest of the
photo (tablet, keyboard, background) stays untouched.

Usage:
    python process_selective_inversion.py input.jpg output.jpg
    python process_selective_inversion.py input.jpg  # writes input_inverted.jpg
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import cv2
import numpy as np

# ---------------------------------------------------------------------------
# Tweakable parameters — adjust for your capture geometry / film stock
# ---------------------------------------------------------------------------

# Film strip polygon (x, y).  None for y = image height - BOTTOM_INSET.
FILM_POLYGON_POINTS = [
    (310,  10),
    (610,  10),
    (580, None),
    (260, None),
]
BOTTOM_INSET = 5

# Orange-base sample region — must land on unexposed film rebate, NOT backlight.
# 85th-percentile used so dark frame content in the patch is ignored.
# Diagnostic value: BGR 85-pct ≈ [0.161, 0.294, 0.702] on the test strip.
# Format: (y_start, y_end, x_start, x_end) in pixels.
ORANGE_SAMPLE_REGION = (540, 610, 350, 450)

# Histogram stretch percentiles (only film-masked pixels counted).
STRETCH_LOW_PCT  = 0.5
STRETCH_HIGH_PCT = 99.5

# Gamma applied after stretch (>1 slightly darkens midtones, <1 lifts them).
GAMMA = 1.10

# CLAHE local-contrast parameters.
CLAHE_CLIP_LIMIT   = 1.8
CLAHE_TILE_SIZE    = 8

# Colour-balance gain cap — prevents individual channels exploding (±20 %).
COLOUR_GAIN_MIN = 0.80
COLOUR_GAIN_MAX = 1.20

# Unsharp-mask amount / blur sigma.
UNSHARP_AMOUNT = 0.45
UNSHARP_SIGMA  = 1.2


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _resolve_polygon(height: int) -> np.ndarray:
    points = []
    for x, y in FILM_POLYGON_POINTS:
        resolved_y = (height - BOTTOM_INSET) if y is None else y
        points.append([x, resolved_y])
    return np.array(points, dtype=np.int32)


def _sample_orange_base(img_float: np.ndarray) -> np.ndarray:
    """
    85th-percentile BGR of the orange-sample region.

    Using the upper percentile (not mean) ensures stray dark image pixels
    inside the patch don't pull the base value down and cause overflow.
    """
    y0, y1, x0, x1 = ORANGE_SAMPLE_REGION
    h, w = img_float.shape[:2]
    y0, y1 = max(0, y0), min(h, y1)
    x0, x1 = max(0, x0), min(w, x1)
    patch = img_float[y0:y1, x0:x1].reshape(-1, 3)
    orange = np.percentile(patch, 85, axis=0)
    return np.maximum(orange, 1e-6)


def _per_channel_levels(
    image: np.ndarray,
    mask: np.ndarray,
    lo_pct: float,
    hi_pct: float,
) -> np.ndarray:
    """Stretch each channel using percentiles computed only from masked pixels."""
    out = np.zeros_like(image)
    for c in range(3):
        ch = image[:, :, c]
        px = ch[mask == 255]
        if px.size == 0:
            out[:, :, c] = np.clip(ch, 0, 1)
            continue
        lo, hi = np.percentile(px, lo_pct), np.percentile(px, hi_pct)
        out[:, :, c] = np.clip((ch - lo) / max(hi - lo, 1e-6), 0.0, 1.0)
    return out


def _clahe(image: np.ndarray) -> np.ndarray:
    """Apply CLAHE independently to each channel for local contrast."""
    clahe = cv2.createCLAHE(
        clipLimit=CLAHE_CLIP_LIMIT,
        tileGridSize=(CLAHE_TILE_SIZE, CLAHE_TILE_SIZE),
    )
    out = image.copy()
    for c in range(3):
        u8 = (image[:, :, c] * 255).astype(np.uint8)
        out[:, :, c] = clahe.apply(u8).astype(np.float32) / 255.0
    return out


def _colour_balance(
    image: np.ndarray,
    mask: np.ndarray,
    reference: np.ndarray | None,
) -> np.ndarray:
    """
    Scale each BGR channel so the masked-pixel mean matches the reference mean.

    When no reference is supplied, a neutral gray-world balance is applied.
    """
    px = image[mask == 255].reshape(-1, 3)
    src_mean = px.mean(axis=0)
    src_mean = np.maximum(src_mean, 1e-6)

    if reference is not None:
        ref_f = reference.astype(np.float32) / 255.0
        tgt_mean = ref_f.mean(axis=(0, 1))
    else:
        tgt_mean = np.full(3, src_mean.mean())

    gain = (tgt_mean / tgt_mean.mean()) / (src_mean / src_mean.mean())
    gain = np.clip(gain, COLOUR_GAIN_MIN, COLOUR_GAIN_MAX)
    return np.clip(image * gain, 0.0, 1.0)


def _unsharp_mask(image: np.ndarray) -> np.ndarray:
    blurred = cv2.GaussianBlur(image, (0, 0), sigmaX=UNSHARP_SIGMA)
    return np.clip(image + UNSHARP_AMOUNT * (image - blurred), 0.0, 1.0)


# ---------------------------------------------------------------------------
# Main pipeline
# ---------------------------------------------------------------------------

def process_selective_inversion(
    image_path: str | Path,
    output_path: str | Path,
    reference_path: str | Path | None = None,
) -> Path:
    """
    Convert masked film strip from negative → positive; blend onto original.

    Pipeline:
      1.  Load + strict float32 /255  (prevents integer overflow)
      2.  Polygon mask
      3.  Orange-base sample (85th pct, avoids dark frame content)
      4.  Normalise by base → clip [0,1] → invert
      5.  Per-channel auto-levels (0.5–99.5 pct, masked pixels only)
      6.  Gamma
      7.  CLAHE  (local contrast, film-like)
      8.  Colour balance  (match reference or gray-world)
      9.  Unsharp mask
      10. Blend: processed × mask + original × (1 − mask)
    """
    image_path  = Path(image_path)
    output_path = Path(output_path)

    img = cv2.imread(str(image_path))
    if img is None:
        raise FileNotFoundError(f"Could not load image: {image_path}")

    ref = None
    if reference_path is not None:
        ref = cv2.imread(str(reference_path))

    h, w = img.shape[:2]

    # 1. Strict float32 normalisation — ALL downstream math stays in [0, 1].
    img_float: np.ndarray = img.astype(np.float32) / 255.0

    # 2. Film polygon mask
    film_points = _resolve_polygon(h)
    mask = np.zeros((h, w), dtype=np.uint8)
    cv2.fillPoly(mask, [film_points], 255)

    # 3. Orange base sample
    orange = _sample_orange_base(img_float)
    print(f"  orange base (BGR 85-pct): {orange.round(3)}")

    # 4. Normalise → clip [0, 1] → invert
    #    Clip BEFORE invert prevents negative values overflowing to 255 in uint8.
    img_neutralised = np.clip(
        img_float.astype(np.float32) / orange.astype(np.float32),
        0.0, 1.0,
    )
    img_inverted = (1.0 - img_neutralised).astype(np.float32)

    # 5. Per-channel auto-levels (masked film pixels only)
    img_levelled = _per_channel_levels(
        img_inverted, mask, STRETCH_LOW_PCT, STRETCH_HIGH_PCT,
    )

    # 6. Gamma
    img_gamma = np.power(img_levelled, GAMMA).astype(np.float32)

    # 7. CLAHE — local contrast (the film-grain "pop" effect)
    img_clahe = _clahe(img_gamma)

    # 8. Colour balance
    img_balanced = _colour_balance(img_clahe, mask, ref)

    # 9. Unsharp mask
    img_sharp = _unsharp_mask(img_balanced)

    # 10. Blend back onto original
    m3 = cv2.merge([mask, mask, mask]).astype(np.float32) / 255.0
    final = np.clip(img_sharp * m3 + img_float * (1.0 - m3), 0.0, 1.0)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(output_path), (final * 255).astype(np.uint8))
    return output_path


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Selective C-41 inversion for film-strip photos (OpenCV + NumPy)."
    )
    parser.add_argument("input",  help="Input photograph (JPEG/PNG)")
    parser.add_argument("output", nargs="?",
                        help="Output path (default: <input_stem>_inverted.jpg)")
    parser.add_argument("--reference", "-r", default=None,
                        help="Optional reference positive scan for colour balance")
    args = parser.parse_args()

    input_path = Path(args.input)
    output_path = (
        Path(args.output)
        if args.output
        else input_path.with_name(f"{input_path.stem}_inverted.jpg")
    )

    try:
        result = process_selective_inversion(
            input_path, output_path,
            reference_path=args.reference,
        )
    except FileNotFoundError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    print(f"Saved → {result}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
