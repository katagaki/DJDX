"""
Assisted digit-box labelling for the DigitDetector inputs.

The DigitDetector crops (Inputs/DigitDetector/*.jpg) are single numeric fields
(scores, miss counts, deltas, "NNNN NOTES", etc.). Each needs one tight bbox per
glyph, classed 0-9 / minus / plus, written to labels/digit_labels.json in the same
{name: [{cls,x,y,w,h}, ...]} normalised shape every other tool uses.

Hand-drawing 2k+ crops is infeasible, so this does the mechanical part:

    propose   classical-CV glyph segmentation (Otsu + connected components +
              projection-valley split of touching digits) → tight boxes.
    sheet     render a contact sheet of N unlabelled crops with proposals drawn
              and per-box indices, for a human (or vision model) to read.
    apply     take an assignment {name: [...]} and commit real labels.

The boxes are CV-accurate; only the *reading* (which glyph each box is, and
dropping non-digit boxes) is left to the reviewer.

apply assignment format — per crop, a list aligned to the proposal boxes
left-to-right, each entry one of:
    "0".."9"        this box is that digit
    "+" / "-"       plus / minus  (written as schema classes plus / minus)
    "x"             drop this proposal (e.g. a "NOTES" letter, junk)
Or, when the proposals are wrong (touching digits merged, a glyph missed),
override the whole crop with {"relayout": "DIGITS"} where DIGITS is the exact
left-to-right string (e.g. "+1029"); N even boxes are laid across the glyph
region. relayout boxes are rougher but get the count/classes right for Studio
refinement.
"""
from __future__ import annotations

import argparse
import json
import os
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
from _common import DIGIT_DIR, DIGIT_LABELS_FILE, load_schema  # noqa: E402

CLASS_FOR = {"+": "plus", "-": "minus", **{str(d): str(d) for d in range(10)}}


# ---------------------------------------------------------------------------
# Segmentation
# ---------------------------------------------------------------------------
def _binarize(gray: np.ndarray) -> np.ndarray:
    """Bright glyphs → white foreground, regardless of panel polarity."""
    _, thr = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    if thr.mean() > 127:                       # foreground should be the minority
        thr = 255 - thr
    h = gray.shape[0]
    k = max(1, h // 30)
    return cv2.morphologyEx(thr, cv2.MORPH_CLOSE, np.ones((k, k), np.uint8))


def _split_wide(box, thr, med_w):
    """Split a too-wide component into digits at vertical-projection valleys."""
    x, y, w, h = box
    if med_w <= 0 or w < 1.5 * med_w:
        return [box]
    n = max(2, int(round(w / med_w)))
    col = (thr[y:y + h, x:x + w] > 0).sum(axis=0).astype(float)
    if col.sum() == 0:
        return [box]
    # candidate cut columns: local minima of ink, searched in n-1 interior bands
    cuts = []
    for i in range(1, n):
        c = int(round(i * w / n))
        lo, hi = max(1, c - w // (2 * n)), min(w - 1, c + w // (2 * n))
        cuts.append(lo + int(np.argmin(col[lo:hi])) if hi > lo else c)
    xs = [0, *cuts, w]
    out = []
    for a, b in zip(xs, xs[1:]):
        if b - a < 2:
            continue
        sub = thr[y:y + h, x + a:x + b]
        ys = np.where(sub.any(axis=1))[0]
        if len(ys) == 0:
            continue
        out.append([x + a, y + int(ys[0]), b - a, int(ys[-1] - ys[0] + 1)])
    return out or [box]


def propose(path: str):
    """Return (W, H, [[x,y,w,h], ...]) pixel boxes, left-to-right."""
    gray = cv2.imread(path, cv2.IMREAD_GRAYSCALE)
    H, W = gray.shape
    thr = _binarize(gray)
    n, _lab, stats, _c = cv2.connectedComponentsWithStats(thr, connectivity=8)
    raw = []
    for i in range(1, n):
        x, y, w, h, area = stats[i]
        if h < 0.40 * H or w > 0.92 * W or area < 0.05 * w * h:
            continue
        raw.append([int(x), int(y), int(w), int(h)])
    raw.sort(key=lambda b: b[0])

    # merge components that overlap heavily in x (vertical splits of one glyph)
    merged = []
    for b in raw:
        if merged:
            px, py, pw, ph = merged[-1]
            ox = min(px + pw, b[0] + b[2]) - max(px, b[0])
            if ox > 0.55 * min(pw, b[2]):
                nx, ny = min(px, b[0]), min(py, b[1])
                merged[-1] = [nx, ny,
                              max(px + pw, b[0] + b[2]) - nx,
                              max(py + ph, b[1] + b[3]) - ny]
                continue
        merged.append(b)

    # NB: no width-based splitting. IIDX digit widths vary too much (a "1" is
    # narrow, "0"/"8" are wide) for a median-width split to be reliable — it
    # over-splits wide single glyphs. Separated digits already come out as one
    # box each; genuinely-touching digits stay merged and are fixed per-crop
    # with an explicit {"relayout": "..."} override at apply time.
    merged.sort(key=lambda b: b[0])
    return W, H, merged


def _norm(box, W, H):
    x, y, w, h = box
    return {"x": x / W, "y": y / H, "w": w / W, "h": h / H}


# ---------------------------------------------------------------------------
# Model-assisted proposals (once a digit_detector is trained)
# ---------------------------------------------------------------------------
_MODEL = None


def _digit_model():
    global _MODEL
    if _MODEL is None:
        from ultralytics import YOLO
        from _common import MODELS_DIR
        _MODEL = YOLO(str(MODELS_DIR / "digit_detector" / "weights" / "best.pt"))
    return _MODEL


def model_predict(path: str, conf=0.25):
    """Return (W, H, [(x,y,w,h,cls_symbol), ...]) from the trained detector,
    left-to-right. cls_symbol is '0'..'9'/'+'/'-'."""
    schema = load_schema()
    classes = schema["digit_detector"]["classes"]
    sym = {"plus": "+", "minus": "-"}
    imgsz = schema["training"]["digit_detector"]["image_size"]
    im = Image.open(path)
    W, H = im.size
    r = _digit_model().predict(path, imgsz=imgsz, conf=conf, verbose=False)[0]
    out = []
    for b, c in zip(r.boxes.xyxy.tolist(), r.boxes.cls.tolist()):
        x1, y1, x2, y2 = b
        out.append((x1, y1, x2 - x1, y2 - y1, sym.get(classes[int(c)], classes[int(c)])))
    out.sort(key=lambda t: t[0])
    return W, H, out


# ---------------------------------------------------------------------------
# Contact sheet
# ---------------------------------------------------------------------------
def _font(sz):
    for p in ("/System/Library/Fonts/SFNSMono.ttf",
              "/System/Library/Fonts/Supplemental/Arial.ttf"):
        if os.path.exists(p):
            return ImageFont.truetype(p, sz)
    return ImageFont.load_default()


def render_sheet(names, out_path, scale=4, cols=2):
    pad, label_h = 12, 24
    cells = []
    for name in names:
        p = str(DIGIT_DIR / name)
        W, H, boxes = propose(p)
        im = Image.open(p).convert("RGB").resize((W * scale, H * scale), Image.NEAREST)
        d = ImageDraw.Draw(im)
        for i, (x, y, w, h) in enumerate(boxes):
            x, y, w, h = x * scale, y * scale, w * scale, h * scale
            d.rectangle([x, y, x + w, y + h], outline=(255, 40, 40), width=3)
            # index chip above each box for unambiguous reference
            d.rectangle([x, max(0, y - 18), x + 16, max(0, y - 18) + 16], fill=(10, 10, 10))
            d.text((x + 2, max(0, y - 18)), str(i), fill=(120, 230, 255), font=_font(15))
        cells.append((name, len(boxes), im))

    colw = max(im.size[0] for _, _, im in cells) + 2 * pad
    rows = (len(cells) + cols - 1) // cols
    rowh = [0] * rows
    for idx, (_, _, im) in enumerate(cells):
        r = idx // cols
        rowh[r] = max(rowh[r], im.size[1] + label_h + pad)
    sheet = Image.new("RGB", (colw * cols, sum(rowh) + pad), (24, 24, 24))
    dd = ImageDraw.Draw(sheet)
    yoff = [pad + sum(rowh[:r]) for r in range(rows)]
    for idx, (name, nb, im) in enumerate(cells):
        r, c = idx // cols, idx % cols
        x0 = c * colw + pad
        y0 = yoff[r]
        dd.text((x0, y0), f"{name}   [{nb} boxes]", fill=(255, 230, 80), font=_font(15))
        sheet.paste(im, (x0, y0 + label_h))
    sheet.save(out_path)
    return out_path, [(n, nb) for n, nb, _ in cells]


def render_zoom(names, out_path, scale=4, boxes=False):
    """Vertical strip of named crops, upscaled for close reading.

    With boxes=True, draws CV proposal boxes + indices (NEAREST upscale so pixels
    stay crisp); otherwise a clean LANCZOS upscale. Returns per-crop geometry
    (width + proposal-box x/end fractions) so relayout xspans can be set.
    """
    pad, label_h = 8, 20
    cells, info = [], []
    for name in names:
        p = str(DIGIT_DIR / name)
        W, H, bx = propose(p)
        resample = Image.NEAREST if boxes else Image.LANCZOS
        im = Image.open(p).convert("RGB").resize((W * scale, H * scale), resample)
        if boxes:
            d = ImageDraw.Draw(im)
            for i, (x, y, w, h) in enumerate(bx):
                x, y, w, h = x * scale, y * scale, w * scale, h * scale
                d.rectangle([x, y, x + w, y + h], outline=(0, 255, 90), width=2)
                d.rectangle([x, max(0, y - 15), x + 14, max(0, y - 15) + 14], fill=(0, 0, 0))
                d.text((x + 2, max(0, y - 15)), str(i), fill=(120, 230, 255), font=_font(13))
        cells.append((name, im))
        info.append({"name": name, "w": W, "nboxes": len(bx),
                     "x": [round(b[0] / W, 3) for b in bx],
                     "end": [round((b[0] + b[2]) / W, 3) for b in bx]})

    Wm = max(i.size[0] for _, i in cells) + 2 * pad
    Ht = sum(i.size[1] + label_h + pad for _, i in cells) + pad
    sheet = Image.new("RGB", (Wm, Ht), (22, 22, 22))
    dd = ImageDraw.Draw(sheet)
    y = pad
    for name, im in cells:
        dd.text((pad, y), name, fill=(255, 230, 80), font=_font(14))
        sheet.paste(im, (pad, y + label_h))
        y += im.size[1] + label_h + pad
    sheet.save(out_path)
    return info


# ---------------------------------------------------------------------------
# Apply assignments → digit_labels.json
# ---------------------------------------------------------------------------
def _relayout(names_boxes, W, H, digits, xspan=None):
    """Lay len(digits) even boxes across the glyph region.

    By default the region is the union of all proposal boxes. Pass xspan
    [x0_frac, x1_frac] to confine it horizontally (e.g. to the digit part of
    a "NNNN NOTES" crop, excluding the letters); the vertical extent is then
    taken from the proposal boxes whose centre falls inside that span.
    """
    if xspan is not None:
        x0, x1 = xspan[0] * W, xspan[1] * W
        inside = [b for b in names_boxes if x0 <= b[0] + b[2] / 2 <= x1]
        if inside:
            y0 = min(b[1] for b in inside)
            y1 = max(b[1] + b[3] for b in inside)
        else:
            y0, y1 = int(0.1 * H), int(0.9 * H)
    elif names_boxes:
        x0 = min(b[0] for b in names_boxes)
        x1 = max(b[0] + b[2] for b in names_boxes)
        y0 = min(b[1] for b in names_boxes)
        y1 = max(b[1] + b[3] for b in names_boxes)
    else:
        x0, y0, x1, y1 = int(0.05 * W), int(0.1 * H), int(0.95 * W), int(0.9 * H)
    n = len(digits)
    bw = (x1 - x0) / n
    out = []
    for i, ch in enumerate(digits):
        out.append({"cls": CLASS_FOR[ch],
                    "x": (x0 + i * bw) / W, "y": y0 / H,
                    "w": bw / W, "h": (y1 - y0) / H})
    return out


def apply(assignments: dict):
    data = json.loads(DIGIT_LABELS_FILE.read_text())
    changed = 0
    for name, spec in assignments.items():
        if name not in data:
            print(f"  ! {name} not in digit_labels.json, skipping", file=sys.stderr)
            continue
        if isinstance(spec, dict) and "model" in spec:
            # Use the trained detector's boxes. spec["model"] is True (accept its
            # classes verbatim) or a token list overriding classes per box
            # left-to-right ("x" drops a box).
            W, H, dets = model_predict(str(DIGIT_DIR / name))
            toks = spec["model"]
            out = []
            for i, (x, y, w, h, s) in enumerate(dets):
                tok = s if toks is True else (toks[i] if i < len(toks) else "x")
                if tok in ("x", "X", "_", None, ""):
                    continue
                out.append({"cls": CLASS_FOR[tok], **_norm([x, y, w, h], W, H)})
            data[name] = out
            changed += 1
            continue

        W, H, boxes = propose(str(DIGIT_DIR / name))
        if isinstance(spec, dict) and "relayout" in spec:
            data[name] = _relayout(boxes, W, H, spec["relayout"], spec.get("xspan"))
        else:
            out = []
            for tok, box in zip(spec, boxes):
                if tok in ("x", "X", "_", None, ""):
                    continue
                out.append({"cls": CLASS_FOR[tok], **_norm(box, W, H)})
            data[name] = out
        changed += 1
    DIGIT_LABELS_FILE.write_text(json.dumps(data, indent=2))
    return changed


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("sheet")
    s.add_argument("--out", default="/tmp/digit_batch.png")
    s.add_argument("--start", type=int, default=0, help="index into unlabelled list")
    s.add_argument("-n", type=int, default=10)
    s.add_argument("--cols", type=int, default=1,
                   help="contact-sheet columns; 1 (default) keeps name↔crop unambiguous")
    s.add_argument("--names", nargs="*", help="explicit crop names instead of --start/-n")

    z = sub.add_parser("zoom", help="upscaled strip of named crops for close reading")
    z.add_argument("--names", nargs="+", required=True)
    z.add_argument("--out", default="/tmp/digit_zoom.png")
    z.add_argument("--scale", type=int, default=4)
    z.add_argument("--boxes", action="store_true",
                   help="draw CV proposal boxes + indices (else clean LANCZOS upscale)")

    m = sub.add_parser("mpred", help="render trained-model predictions for crops")
    m.add_argument("--names", nargs="*")
    m.add_argument("--start", type=int, default=0)
    m.add_argument("-n", type=int, default=10)
    m.add_argument("--out", default="/tmp/digit_mpred.png")
    m.add_argument("--conf", type=float, default=0.25)
    m.add_argument("--scale", type=int, default=4)

    a = sub.add_parser("apply")
    a.add_argument("json", help="path to assignments JSON, or - for stdin")

    st = sub.add_parser("status")
    args = ap.parse_args()

    if args.cmd == "status":
        data = json.loads(DIGIT_LABELS_FILE.read_text())
        done = sum(1 for v in data.values() if v)
        print(f"labelled {done}/{len(data)}  ({len(data)-done} remaining)")
        return

    if args.cmd == "sheet":
        data = json.loads(DIGIT_LABELS_FILE.read_text())
        if args.names:
            names = args.names
        else:
            todo = [k for k, v in data.items() if not v]
            names = todo[args.start:args.start + args.n]
        out, info = render_sheet(names, args.out, cols=args.cols)
        print(json.dumps({"out": out, "names": [n for n, _ in info],
                          "box_counts": {n: c for n, c in info}}, indent=2))
        return

    if args.cmd == "zoom":
        info = render_zoom(args.names, args.out, scale=args.scale, boxes=args.boxes)
        print(json.dumps({"out": args.out, "crops": info}, indent=2))
        return

    if args.cmd == "mpred":
        if args.names:
            names = args.names
        else:
            data = json.loads(DIGIT_LABELS_FILE.read_text())
            todo = [k for k, v in data.items() if not v]
            names = todo[args.start:args.start + args.n]
        pad, label_h, sc = 8, 20, args.scale
        cells, info = [], []
        for name in names:
            W, H, dets = model_predict(str(DIGIT_DIR / name), conf=args.conf)
            im = Image.open(str(DIGIT_DIR / name)).convert("RGB").resize((W * sc, H * sc), Image.NEAREST)
            d = ImageDraw.Draw(im)
            read = ""
            for x, y, w, h, s in dets:
                read += s
                x, y, w, h = x * sc, y * sc, w * sc, h * sc
                d.rectangle([x, y, x + w, y + h], outline=(255, 120, 0), width=2)
                d.rectangle([x, max(0, y - 15), x + 13, max(0, y - 15) + 14], fill=(0, 0, 0))
                d.text((x + 1, max(0, y - 15)), s, fill=(255, 210, 0), font=_font(13))
            cells.append((f"{name}  ={read}", im))
            info.append({"name": name, "read": read, "n": len(dets)})
        Wm = max(i.size[0] for _, i in cells) + 2 * pad
        Ht = sum(i.size[1] + label_h + pad for _, i in cells) + pad
        sheet = Image.new("RGB", (Wm, Ht), (22, 22, 22))
        dd = ImageDraw.Draw(sheet)
        y = pad
        for t, im in cells:
            dd.text((pad, y), t, fill=(255, 230, 80), font=_font(14))
            sheet.paste(im, (pad, y + label_h))
            y += im.size[1] + label_h + pad
        sheet.save(args.out)
        print(json.dumps({"out": args.out, "preds": info}, indent=2))
        return

    if args.cmd == "apply":
        raw = sys.stdin.read() if args.json == "-" else open(args.json).read()
        changed = apply(json.loads(raw))
        print(f"applied {changed} crops")


if __name__ == "__main__":
    main()
