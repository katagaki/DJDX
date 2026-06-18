"""
Render labelled bboxes onto each image for visual review.

Reads ``training/labels/labels.json`` (or ``--labels <path>``), draws a red
outline + class-name tag above each box, and writes to
``training/output/label_preview/<image_stem>.jpg``.

Usage:
    uv run python scripts/draw_labels.py                     # all labelled images
    uv run python scripts/draw_labels.py 235.jpg IMG_0028.jpeg
    uv run python scripts/draw_labels.py --labels labels/auto_seed.json
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from _common import DATA_DIR, LABELS_FILE, OUTPUT_DIR, load_upright
from PIL import ImageDraw, ImageFont

PREVIEW_DIR = OUTPUT_DIR / "label_preview"
OUTLINE_COLOR = "#ff2222"
TAG_BG = "#ff2222"
TAG_FG = "#ffffff"


def _load_font(size: int) -> ImageFont.ImageFont:
    # Try common macOS system fonts in order; fall back to PIL default.
    for path in (
        "/System/Library/Fonts/Menlo.ttc",
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
    ):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def _box_corners(b: dict, iw: int, ih: int) -> list[tuple[int, int]]:
    """Return 4 polygon corners (pixel coords).

    If the box has a ``polygon`` field (list of [x, y] in [0, 1]), use it
    verbatim. Otherwise derive from the axis-aligned x/y/w/h fields.
    """
    if "polygon" in b:
        return [(int(px * iw), int(py * ih)) for px, py in b["polygon"]]
    x1, y1 = int(b["x"] * iw), int(b["y"] * ih)
    x2, y2 = int((b["x"] + b["w"]) * iw), int((b["y"] + b["h"]) * ih)
    return [(x1, y1), (x2, y1), (x2, y2), (x1, y2)]


def draw_one(image_path: Path, boxes: list[dict], out_path: Path) -> None:
    im = load_upright(image_path)
    iw, ih = im.size
    draw = ImageDraw.Draw(im)

    # Scale outline + tag size to image resolution.
    # Tags are kept small so they don't occlude tightly-packed boxes
    # (e.g. the 5-row judgement breakdown).
    line_w = max(2, iw // 500)
    tag_size = max(8, iw // 200)
    font = _load_font(tag_size)
    pad_x, pad_y = max(1, tag_size // 5), max(1, tag_size // 10)

    for b in boxes:
        corners = _box_corners(b, iw, ih)
        # Polygon outline (handles both rectangles and skewed quads).
        draw.line([*corners, corners[0]], fill=OUTLINE_COLOR, width=line_w)

        # Class tag anchored to the top-most corner — works for any shape.
        # If the box has a confidence score (model predictions do), show it.
        tag = b["cls"] + (f" {b['conf']:.2f}" if "conf" in b else "")
        top_x, top_y = min(corners, key=lambda c: c[1])
        tl, tt, tr, tb = draw.textbbox((0, 0), tag, font=font)
        tw, th = tr - tl, tb - tt
        tag_h = th + 2 * pad_y
        tag_w = tw + 2 * pad_x
        ty = top_y - tag_h if top_y - tag_h >= 0 else max(c[1] for c in corners)
        tx = max(0, min(iw - tag_w, top_x))
        draw.rectangle((tx, ty, tx + tag_w, ty + tag_h), fill=TAG_BG)
        draw.text((tx + pad_x, ty + pad_y - tt), tag, fill=TAG_FG, font=font)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    im.save(out_path, quality=85)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("images", nargs="*", help="image filenames to render (default: all in labels.json)")
    ap.add_argument("--labels", type=Path, default=LABELS_FILE)
    ap.add_argument("--out", type=Path, default=PREVIEW_DIR)
    args = ap.parse_args()

    if not args.labels.exists():
        raise SystemExit(f"labels file not found: {args.labels}")
    data = json.loads(args.labels.read_text())

    names = args.images or sorted(n for n, boxes in data.items() if boxes)
    if not names:
        raise SystemExit("no labelled images to render")

    for name in names:
        boxes = data.get(name) or []
        if not boxes:
            print(f"  skip {name}: no boxes")
            continue
        src = DATA_DIR / name
        if not src.exists():
            print(f"  skip {name}: source image missing at {src}")
            continue
        out_path = args.out / f"{Path(name).stem}.jpg"
        draw_one(src, boxes, out_path)
        print(f"  {name}: {len(boxes)} boxes -> {out_path}")


if __name__ == "__main__":
    main()
