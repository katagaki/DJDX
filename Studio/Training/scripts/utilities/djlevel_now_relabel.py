"""Relabel `dj_level_now` from the big top-left rank glyph to the score-table
right-column DJ LEVEL value (the one to the right of `dj_level_prev`).

The big glyph is unreliable: it is hidden when the current rank is D or below.
The score-table value is always present. This script moves the `dj_level_now`
box for every labelled result screen onto that table glyph.

Geometry: the table's DJ LEVEL row has `dj_level_prev` (left/best column) as a
fixed anchor. The current value sits one column to the right, same row, larger &
brighter (cyan/white), with a small "<rank> +/-NNNN" subtitle below and an
optional yellow NEW RECORD badge further right. We define a generous now-column
ROI from the prev anchor + the clear_type now/prev column offset, segment the
bright glyph inside it (B & G high → excludes the yellow badge; drop the small
subtitle blobs), and union the main-glyph components into a tight box.

Modes:
  propose  --out proposals.json [--montage sheet.png] [--names a.jpg b.jpg]
  apply    --proposals proposals.json [--names ... | --limit N | --order sorted]
           writes the new dj_level_now boxes into labels/labels.json (drops the
           old big-glyph box).
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent.parent))  # Training/scripts: shared _common/_ocr
from _common import LABELS_FILE, RESULTS_DIR, load_upright

DEFAULT_OFFSET = 0.105   # dj_level_prev.x → now-column center, in normalised x


def _get(boxes, cls):
    for b in boxes:
        if b["cls"] == cls:
            return b
    return None


def _now_offset(boxes) -> float:
    """Center-to-center now−prev x offset, triangulated from the table rows that
    have both columns labelled (clear_type / score / miss_count)."""
    pairs = [
        ("clear_type_now", "clear_type_prev"),
        ("score_now", "score_prev"),
        ("miss_count_now", "miss_count_prev"),
    ]
    offs = []
    for n, p in pairs:
        bn, bp = _get(boxes, n), _get(boxes, p)
        if bn and bp and bn["x"] > bp["x"]:
            offs.append(bn["x"] - bp["x"])
    # clear_type sits directly above DJ LEVEL → most representative; else median.
    ct_n, ct_p = _get(boxes, "clear_type_now"), _get(boxes, "clear_type_prev")
    if ct_n and ct_p and ct_n["x"] > ct_p["x"]:
        return ct_n["x"] - ct_p["x"]
    return float(np.median(offs)) if offs else DEFAULT_OFFSET


def roi_rect(boxes) -> tuple[float, float, float, float] | None:
    """Generous now-column ROI (normalised l,t,r,b) that reliably contains the
    table's current DJ LEVEL glyph plus its subtitle, excluding the prev glyph.
    Anchored on dj_level_prev + the now/prev column offset."""
    dp = _get(boxes, "dj_level_prev")
    if dp is None:
        return None
    off = _now_offset(boxes)
    left = dp["x"] + dp["w"] / 2 + 0.10 * off
    right = dp["x"] + dp["w"] / 2 + 1.95 * off
    top = dp["y"] - 1.7 * dp["h"]
    bot = dp["y"] + 2.0 * dp["h"]
    return (max(0.0, left), max(0.0, top), min(1.0, right), min(1.0, bot))


def _grid_font(size: int):
    for p in ("/System/Library/Fonts/SFNSMono.ttf",
              "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
              "/System/Library/Fonts/Helvetica.ttc"):
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            continue
    return ImageFont.load_default()


def delta_roi_rect(now_box: dict) -> tuple[float, float, float, float]:
    """ROI containing the "<rank> +/-NNNN" subtitle directly BELOW the now glyph.
    Anchored on the (already-placed) dj_level_now box; widened right to capture the
    signed 4-digit tail and dropped below the glyph."""
    nx, ny, nw, nh = now_box["x"], now_box["y"], now_box["w"], now_box["h"]
    left = nx - nw / 2 - 0.4 * nw
    right = nx - nw / 2 + 4.2 * nw          # rank + space + sign + 4 digits
    top = ny + 0.10 * nh                    # from the glyph's lower half down
    bot = ny + 1.70 * nh                    # through the subtitle, above the SCORE row
    return (max(0.0, left), max(0.0, top), min(1.0, right), min(1.0, bot))


def render_roi_grid(im: Image.Image, boxes, target_w: int = 1100,
                    roi: tuple | None = None) -> tuple[Image.Image, tuple]:
    """Zoomed ROI crop with a 0–100 percentage grid (of the ROI box) overlaid,
    for vision to read tight box coordinates off. Returns (image, roi_rect).
    Sized to ~target_w px so thick gridlines survive display downscaling."""
    W, H = im.size
    if roi is None:
        roi = roi_rect(boxes)
    l, t, r, b = roi
    pl, pt, pr, pb = int(l * W), int(t * H), int(r * W), int(b * H)
    crop = im.crop((pl, pt, pr, pb)).convert("RGB")
    cw, ch = crop.size
    scale = max(1.0, target_w / cw)
    crop = crop.resize((int(cw * scale), int(ch * scale)), Image.LANCZOS)
    # pad a margin so axis labels sit outside the image content
    M = 34
    CW, CH = crop.size
    canvas = Image.new("RGB", (CW + M, CH + M), (12, 12, 12))
    canvas.paste(crop, (M, M))
    dr = ImageDraw.Draw(canvas)
    font = _grid_font(20)
    for p in range(0, 101, 10):
        x = M + int(p / 100 * (CW - 1))
        y = M + int(p / 100 * (CH - 1))
        major = p % 50 == 0
        col = (0, 230, 0) if major else (70, 70, 80)
        w = 2 if major else 1
        dr.line([(x, M), (x, M + CH)], fill=col, width=w)
        dr.line([(M, y), (M + CW, y)], fill=col, width=w)
        dr.text((x - 8, 6), str(p), fill=(255, 255, 0), font=font)
        dr.text((2, y - 10), str(p), fill=(255, 255, 0), font=font)
    return canvas, roi


def box_from_grid(roi, gx0, gy0, gx1, gy1) -> dict:
    """Map an ROI-fraction box (each 0–100) back to a normalised image box."""
    l, t, r, b = roi
    x0 = l + (r - l) * gx0 / 100
    x1 = l + (r - l) * gx1 / 100
    y0 = t + (b - t) * gy0 / 100
    y1 = t + (b - t) * gy1 / 100
    return {"cls": "dj_level_now", "x": (x0 + x1) / 2, "y": (y0 + y1) / 2,
            "w": x1 - x0, "h": y1 - y0, "conf": 1.0, "source": "djlevel_now_relabel_grid"}


def propose_box(im: Image.Image, boxes) -> tuple[dict | None, dict]:
    """Return (box | None, debug). box is normalised {x,y,w,h} center form."""
    W, H = im.size
    dp = _get(boxes, "dj_level_prev")
    if dp is None:
        return None, {"reason": "no dj_level_prev anchor"}
    off = _now_offset(boxes)

    # Generous now-column ROI (shared with the grid renderer).
    roi_l, roi_t, roi_r, roi_b = roi_rect(boxes)

    pl, pr = int(roi_l * W), int(roi_r * W)
    pt, pb = int(roi_t * H), int(roi_b * H)
    if pr - pl < 4 or pb - pt < 4:
        return None, {"reason": "degenerate ROI"}

    crop = np.asarray(im.crop((pl, pt, pr, pb)).convert("RGB")).astype(np.int32)
    R, G, B = crop[..., 0], crop[..., 1], crop[..., 2]
    lum = (0.299 * R + 0.587 * G + 0.114 * B)
    ch, cw = lum.shape
    dph_px = max(3.0, dp["h"] * H)            # prev-glyph height in ROI pixels
    dp_cy = (dp["y"] - roi_t) * H             # prev row center, in ROI pixels

    # Bright cyan/white mask. Requiring G&B high rejects the yellow/red NEW
    # RECORD badge (low B) and red accents (low G/B).
    thr = max(150, np.percentile(lum, 80))
    mask = (lum > thr) & (G > 110) & (B > 110)
    if mask.sum() < 8:
        thr = max(140, np.percentile(lum, 85))
        mask = lum > thr
    if mask.sum() < 8:
        return None, {"reason": "no bright glyph in ROI", "roi": [roi_l, roi_t, roi_r, roi_b]}

    # --- Vertical: horizontal projection → bright row-bands. The DJ LEVEL row
    # has three stacked bright bands inside the ROI: (clip of) clear_type above,
    # the main glyph on the prev row, the "+NNNN" subtitle below. Pick the band
    # whose center is nearest the prev-glyph row — that's the main glyph. ---
    row_sum = mask.sum(axis=1).astype(float)
    ract = row_sum > max(1.0, 0.16 * row_sum.max())
    bands = []
    i = 0
    while i < ch:
        if ract[i]:
            j = i
            while j + 1 < ch and ract[j + 1]:
                j += 1
            bands.append((i, j))
            i = j + 1
        else:
            i += 1
    bands = [(a, b) for a, b in bands if (b - a + 1) >= 0.30 * dph_px]
    if not bands:
        return None, {"reason": "no row-band", "roi": [roi_l, roi_t, roi_r, roi_b]}
    # The big glyph is the TALLEST band sitting in the central window of the ROI:
    # the clear_type row is clipped near the top, the "+NNNN" subtitle is below,
    # the score row is clipped near the bottom. Window brackets the glyph row.
    win = [(a, b) for a, b in bands if 0.28 <= (a + b) / 2 / ch <= 0.66]
    pool = win or bands
    gy0, gy1 = max(pool, key=lambda bd: bd[1] - bd[0])
    # Merge any other window band that vertically overlaps/abuts the chosen one
    # (a glyph can split into two bands across a thin dark seam).
    for a, b in pool:
        if a <= gy1 + 0.25 * dph_px and b >= gy0 - 0.25 * dph_px:
            gy0, gy1 = min(gy0, a), max(gy1, b)
    _ = dp_cy  # retained for debug parity

    # --- Horizontal: within the glyph band, project to columns and take the
    # leftmost contiguous run (merging inter-letter gaps). The far-right NEW
    # RECORD badge, if any survived, sits past a wide gap and is dropped. ---
    band_mask = mask[gy0:gy1 + 1]
    col_sum = band_mask.sum(axis=0).astype(float)
    cact = col_sum > max(1.0, 0.12 * col_sum.max())
    gap_merge = max(2, int(0.55 * dph_px))     # merge gaps narrower than this
    runs = []
    i = 0
    while i < cw:
        if cact[i]:
            j = i
            gap = 0
            k = i
            while k + 1 < cw:
                if cact[k + 1]:
                    j = k + 1
                    gap = 0
                else:
                    gap += 1
                    if gap > gap_merge:
                        break
                k += 1
            runs.append((i, j))
            i = k + 1
        else:
            i += 1
    if not runs:
        return None, {"reason": "no column run", "roi": [roi_l, roi_t, roi_r, roi_b]}
    # leftmost run that is wide enough to be a glyph (not a 1px speck)
    glyph_runs = [r for r in runs if (r[1] - r[0] + 1) >= 0.3 * dph_px]
    gx0, gx1 = (glyph_runs or runs)[0]

    # Pad slightly, back to absolute px, then normalise.
    padx = 0.10 * (gx1 - gx0 + 1)
    pady = 0.16 * (gy1 - gy0 + 1)
    ax0 = pl + max(0, gx0 - padx)
    ax1 = pl + min(cw - 1, gx1 + padx)
    ay0 = pt + max(0, gy0 - pady)
    ay1 = pt + min(ch - 1, gy1 + pady)

    bx = (ax0 + ax1) / 2 / W
    by = (ay0 + ay1) / 2 / H
    bw = (ax1 - ax0) / W
    bh = (ay1 - ay0) / H
    box = {"cls": "dj_level_now", "x": bx, "y": by, "w": bw, "h": bh, "conf": 1.0,
           "source": "djlevel_now_relabel"}
    dbg = {"roi": [roi_l, roi_t, roi_r, roi_b], "n_band": len(bands),
           "n_run": len(runs), "off": off}
    return box, dbg


def render_montage(items, labels, out: Path, cols: int = 3):
    tiles = []
    for name in items:
        src = RESULTS_DIR / name
        if not src.exists():
            continue
        im = load_upright(src).convert("RGB")
        W, H = im.size
        box, dbg = propose_box(im, labels[name])
        dr = ImageDraw.Draw(im)
        dp = _get(labels[name], "dj_level_prev")
        if dp:
            cx, cy, bw, bh = dp["x"] * W, dp["y"] * H, dp["w"] * W, dp["h"] * H
            dr.rectangle([cx - bw / 2, cy - bh / 2, cx + bw / 2, cy + bh / 2],
                         outline="lime", width=4)
        roi = dbg.get("roi")
        if roi:
            dr.rectangle([roi[0] * W, roi[1] * H, roi[2] * W, roi[3] * H],
                         outline="yellow", width=2)
        if box:
            cx, cy, bw, bh = box["x"] * W, box["y"] * H, box["w"] * W, box["h"] * H
            dr.rectangle([cx - bw / 2, cy - bh / 2, cx + bw / 2, cy + bh / 2],
                         outline="red", width=5)
        # crop around the DJ LEVEL row
        if dp:
            ccx = dp["x"] * W
            cl = int(max(0, ccx - 0.06 * W))
            crr = int(min(W, ccx + 0.34 * W))
            ct = int(max(0, dp["y"] * H - 0.10 * H))
            cb = int(min(H, dp["y"] * H + 0.10 * H))
            tile = im.crop((cl, ct, crr, cb))
        else:
            tile = im
        tile.thumbnail((520, 520))
        label = f"{name}" + ("" if box else "  !! " + dbg.get("reason", "FAIL"))
        tiles.append((label, tile))
    if not tiles:
        print("no tiles")
        return
    pad = 26
    tw = max(t[1].width for t in tiles)
    th = max(t[1].height for t in tiles) + 22
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (tw + pad) + pad, rows * (th + pad) + pad), (15, 15, 15))
    dr = ImageDraw.Draw(sheet)
    for i, (label, t) in enumerate(tiles):
        r, c = divmod(i, cols)
        x = pad + c * (tw + pad)
        y = pad + r * (th + pad)
        dr.text((x, y), label, fill=("red" if "!!" in label else "white"))
        sheet.paste(t, (x, y + 16))
    sheet.save(out)
    print(f"montage → {out}  ({sheet.size}, {len(tiles)} tiles)")


def cmd_propose(args):
    labels = json.loads(LABELS_FILE.read_text())
    targets = [n for n, b in labels.items()
               if _get(b, "dj_level_now") and (RESULTS_DIR / n).exists()]
    if args.names:
        targets = [n for n in args.names if n in labels]
    proposals = {}
    fails = []
    for name in targets:
        src = RESULTS_DIR / name
        if not src.exists():
            continue
        im = load_upright(src).convert("RGB")
        box, dbg = propose_box(im, labels[name])
        if box:
            proposals[name] = box
        else:
            fails.append((name, dbg.get("reason")))
    if args.out:
        Path(args.out).write_text(json.dumps(proposals, indent=2))
        print(f"{len(proposals)} proposals → {args.out};  {len(fails)} failed")
    for n, r in fails:
        print(f"  FAIL {n}: {r}")
    if args.montage:
        render_montage(args.names or targets, labels, Path(args.montage))


def cmd_gridcrops_delta(args):
    """Render grid crops of the subtitle ROI (anchored on each image's existing
    dj_level_now box) for the distractor-class labeling pass."""
    labels = json.loads(LABELS_FILE.read_text())
    targets = [n for n, b in labels.items()
               if _get(b, "dj_level_now") and (RESULTS_DIR / n).exists()]
    if args.names:
        targets = [n for n in args.names if n in labels]
    out = Path(args.dir)
    out.mkdir(parents=True, exist_ok=True)
    for name in targets:
        now = _get(labels[name], "dj_level_now")
        im = load_upright(RESULTS_DIR / name).convert("RGB")
        crop, _roi = render_roi_grid(im, labels[name], roi=delta_roi_rect(now))
        crop.save(out / f"{Path(name).stem}.png")
    print(f"rendered {len(targets)} delta grid crops → {out}")


def cmd_applygrid_delta(args):
    labels = json.loads(LABELS_FILE.read_text())
    grid = json.loads(Path(args.grid).read_text())
    proposals, bad = {}, []
    for name, g in grid.items():
        if name not in labels:
            cand = [k for k in labels if Path(k).stem == name]
            if not cand:
                bad.append((name, "not in labels"))
                continue
            name = cand[0]
        now = _get(labels[name], "dj_level_now")
        if now is None:
            bad.append((name, "no now box"))
            continue
        try:
            gx0, gy0, gx1, gy1 = g[:4]
        except Exception:
            bad.append((name, "bad coords"))
            continue
        box = box_from_grid(delta_roi_rect(now), gx0, gy0, gx1, gy1)
        box["cls"] = "dj_level_now_delta"
        box["source"] = "djlevel_delta_grid"
        proposals[name] = box
    Path(args.out).write_text(json.dumps(proposals, indent=2))
    print(f"{len(proposals)} delta proposals → {args.out}; {len(bad)} bad")
    for n, r in bad:
        print(f"  bad {n}: {r}")


def cmd_auditprops(args):
    """Render montages of externally-supplied proposals (normalised boxes) drawn
    over each image's DJ LEVEL row, for visual audit."""
    labels = json.loads(LABELS_FILE.read_text())
    props = json.loads(Path(args.proposals).read_text())
    out = Path(args.dir)
    out.mkdir(parents=True, exist_ok=True)
    names = sorted(props.keys())
    per = args.per
    cols = 3
    for page in range((len(names) + per - 1) // per):
        group = names[page * per:(page + 1) * per]
        tiles = []
        for name in group:
            src = RESULTS_DIR / name
            if not src.exists():
                continue
            im = load_upright(src).convert("RGB")
            W, H = im.size
            dr = ImageDraw.Draw(im)
            dp = _get(labels.get(name, []), "dj_level_prev")
            if dp:
                cx, cy, bw, bh = dp["x"] * W, dp["y"] * H, dp["w"] * W, dp["h"] * H
                dr.rectangle([cx - bw / 2, cy - bh / 2, cx + bw / 2, cy + bh / 2],
                             outline="lime", width=4)
            b = props[name]
            cx, cy, bw, bh = b["x"] * W, b["y"] * H, b["w"] * W, b["h"] * H
            dr.rectangle([cx - bw / 2, cy - bh / 2, cx + bw / 2, cy + bh / 2],
                         outline="red", width=5)
            if dp:
                ccx = dp["x"] * W
                tile = im.crop((int(max(0, ccx - 0.05 * W)), int(max(0, dp["y"] * H - 0.085 * H)),
                                int(min(W, ccx + 0.33 * W)), int(min(H, dp["y"] * H + 0.10 * H))))
            else:
                tile = im
            tile.thumbnail((480, 480))
            tiles.append((name, tile))
        if not tiles:
            continue
        pad = 24
        tw = max(t[1].width for t in tiles)
        th = max(t[1].height for t in tiles) + 20
        rows = (len(tiles) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * (tw + pad) + pad, rows * (th + pad) + pad), (15, 15, 15))
        dr = ImageDraw.Draw(sheet)
        for i, (name, t) in enumerate(tiles):
            r, c = divmod(i, cols)
            x = pad + c * (tw + pad)
            y = pad + r * (th + pad)
            dr.text((x, y), name, fill="white")
            sheet.paste(t, (x, y + 14))
        sheet.save(out / f"audit_{page:02d}.png")
    print(f"audit montages → {out}")


def cmd_gridcrops(args):
    labels = json.loads(LABELS_FILE.read_text())
    targets = [n for n, b in labels.items()
               if _get(b, "dj_level_now") and _get(b, "dj_level_prev")
               and (RESULTS_DIR / n).exists()]
    if args.names:
        targets = [n for n in args.names if n in labels]
    out = Path(args.dir)
    out.mkdir(parents=True, exist_ok=True)
    for name in targets:
        im = load_upright(RESULTS_DIR / name).convert("RGB")
        crop, _roi = render_roi_grid(im, labels[name])
        crop.save(out / f"{Path(name).stem}.png")
    print(f"rendered {len(targets)} grid crops → {out}")


def cmd_applygrid(args):
    labels = json.loads(LABELS_FILE.read_text())
    grid = json.loads(Path(args.grid).read_text())
    proposals = {}
    bad = []
    for name, g in grid.items():
        if name not in labels:
            # allow stem keys
            cand = [k for k in labels if Path(k).stem == name]
            if not cand:
                bad.append((name, "not in labels"))
                continue
            name = cand[0]
        try:
            gx0, gy0, gx1, gy1 = g[:4]
        except Exception:
            bad.append((name, "bad coords"))
            continue
        roi = roi_rect(labels[name])
        if roi is None:
            bad.append((name, "no roi"))
            continue
        proposals[name] = box_from_grid(roi, gx0, gy0, gx1, gy1)
    Path(args.out).write_text(json.dumps(proposals, indent=2))
    print(f"{len(proposals)} proposals → {args.out}; {len(bad)} bad")
    for n, r in bad:
        print(f"  bad {n}: {r}")


def cmd_apply(args):
    labels = json.loads(LABELS_FILE.read_text())
    proposals = json.loads(Path(args.proposals).read_text())
    names = list(proposals.keys())
    if args.order == "sorted":
        names.sort()
    if args.names:
        names = [n for n in args.names if n in proposals]
    elif args.limit is not None:
        names = names[: args.limit]
    changed = 0
    for name in names:
        if name not in labels:
            continue
        new = proposals[name]
        boxes = [b for b in labels[name] if b["cls"] != "dj_level_now"]
        boxes.append(dict(new))
        labels[name] = boxes
        changed += 1
    LABELS_FILE.write_text(json.dumps(labels, indent=2))
    print(f"applied {changed} dj_level_now relabels to {LABELS_FILE.name}")


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("propose")
    p.add_argument("--out", default=None)
    p.add_argument("--montage", default=None)
    p.add_argument("--names", nargs="*")
    p.set_defaults(func=cmd_propose)
    gd = sub.add_parser("gridcrops_delta")
    gd.add_argument("--dir", required=True)
    gd.add_argument("--names", nargs="*")
    gd.set_defaults(func=cmd_gridcrops_delta)
    agd = sub.add_parser("applygrid_delta")
    agd.add_argument("--grid", required=True)
    agd.add_argument("--out", required=True)
    agd.set_defaults(func=cmd_applygrid_delta)
    ad = sub.add_parser("auditprops")
    ad.add_argument("--proposals", required=True)
    ad.add_argument("--dir", required=True)
    ad.add_argument("--per", type=int, default=12)
    ad.set_defaults(func=cmd_auditprops)
    g = sub.add_parser("gridcrops")
    g.add_argument("--dir", required=True)
    g.add_argument("--names", nargs="*")
    g.set_defaults(func=cmd_gridcrops)
    ag = sub.add_parser("applygrid")
    ag.add_argument("--grid", required=True)
    ag.add_argument("--out", required=True)
    ag.set_defaults(func=cmd_applygrid)
    a = sub.add_parser("apply")
    a.add_argument("--proposals", required=True)
    a.add_argument("--names", nargs="*")
    a.add_argument("--limit", type=int, default=None)
    a.add_argument("--order", choices=["sorted", "as-is"], default="sorted")
    a.set_defaults(func=cmd_apply)
    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
