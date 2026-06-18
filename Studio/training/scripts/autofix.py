"""
Heuristic auto-fixer for common detector mistakes in predictions.json.

Fixes, per image:
  1. Spurious miss_count_delta that overlaps miss_count_now -> drop.
  2. Missing judge_* row -> the five judges form an evenly-spaced vertical
     column; least-squares fit y = a + b*index from the present rows and
     insert any missing class at its predicted slot.
  3. song_title / song_artist missing or mis-sized -> re-derive tight boxes
     from Apple Vision OCR text lines in the bottom-right info band,
     skipping difficulty / notes lines.

Usage:
    uv run python scripts/autofix.py IMG_1.jpeg IMG_2.jpeg ...
    uv run python scripts/autofix.py --all          # every image in predictions.json
"""
from __future__ import annotations

import argparse
import json

from _common import DATA_DIR, OUTPUT_DIR
from _ocr import ocr_images

PRED_PATH = OUTPUT_DIR / "predictions.json"

JUDGE_ORDER = ["judge_pgreat", "judge_great", "judge_good", "judge_bad", "judge_poor"]
DIFFICULTY_WORDS = ("HYPER", "ANOTHER", "LEGGENDARIA", "NORMAL", "BEGINNER")


def _iou(a: dict, b: dict) -> float:
    ax1, ay1, ax2, ay2 = a["x"], a["y"], a["x"] + a["w"], a["y"] + a["h"]
    bx1, by1, bx2, by2 = b["x"], b["y"], b["x"] + b["w"], b["y"] + b["h"]
    ix1, iy1, ix2, iy2 = max(ax1, bx1), max(ay1, by1), min(ax2, bx2), min(ay2, by2)
    if ix2 <= ix1 or iy2 <= iy1:
        return 0.0
    inter = (ix2 - ix1) * (iy2 - iy1)
    return inter / (a["w"] * a["h"] + b["w"] * b["h"] - inter)


def fix_miss_delta(boxes: list[dict]) -> int:
    now = next((b for b in boxes if b["cls"] == "miss_count_now"), None)
    delta = next((b for b in boxes if b["cls"] == "miss_count_delta"), None)
    if now and delta and _iou(now, delta) > 0.25:
        boxes.remove(delta)
        return 1
    return 0


def fix_judges(boxes: list[dict]) -> int:
    present = [b for b in boxes if b["cls"] in JUDGE_ORDER]
    if len(present) < 3 or len(present) == 5:
        return 0
    # Fit y = a + b*index from present rows (least squares).
    pts = [(JUDGE_ORDER.index(b["cls"]), b["y"]) for b in present]
    n = len(pts)
    sx = sum(i for i, _ in pts)
    sy = sum(y for _, y in pts)
    sxx = sum(i * i for i, _ in pts)
    sxy = sum(i * y for i, y in pts)
    denom = n * sxx - sx * sx
    if denom == 0:
        return 0
    slope = (n * sxy - sx * sy) / denom
    intercept = (sy - slope * sx) / n
    mx = sum(b["x"] for b in present) / n
    mw = sum(b["w"] for b in present) / n
    mh = sum(b["h"] for b in present) / n
    added = 0
    have = {b["cls"] for b in present}
    for i, cls in enumerate(JUDGE_ORDER):
        if cls in have:
            continue
        boxes.append({"cls": cls, "x": round(mx, 4), "y": round(intercept + slope * i, 4),
                      "w": round(mw, 4), "h": round(mh, 4)})
        added += 1
    return added


def _song_candidates(regions: list[dict]) -> list[dict]:
    out = []
    for r in regions:
        # bottom-right info band
        if r["y"] < 0.78 or r["x"] < 0.45:
            continue
        txt = r["text"].strip().upper()
        if not txt:
            continue
        if "NOTES" in txt or txt.startswith("SP"):
            continue
        if any(d in txt for d in DIFFICULTY_WORDS):
            continue
        if "PASELI" in txt or "CREDIT" in txt or "SHOP" in txt or "RANK" in txt:
            continue
        out.append(r)
    out.sort(key=lambda r: r["y"])
    return out


def fix_song(boxes: list[dict], regions: list[dict]) -> int:
    cands = _song_candidates(regions)
    if not cands:
        return 0
    changed = 0

    def upsert(cls: str, r: dict) -> None:
        box = {"cls": cls, "x": round(r["x"], 4), "y": round(r["y"], 4),
               "w": round(r["w"], 4), "h": round(min(r["h"], 0.035), 4)}
        existing = next((b for b in boxes if b["cls"] == cls), None)
        if existing:
            existing.update(box)
        else:
            boxes.append(box)

    # Topmost candidate is the title; next distinct line is the artist.
    upsert("song_title", cands[0])
    changed += 1
    if len(cands) >= 2:
        upsert("song_artist", cands[1])
        changed += 1
    return changed


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("images", nargs="*")
    ap.add_argument("--all", action="store_true")
    args = ap.parse_args()

    preds = json.loads(PRED_PATH.read_text())
    targets = list(preds) if args.all else args.images
    targets = [t for t in targets if t in preds]
    if not targets:
        raise SystemExit("no matching images in predictions.json")

    ocr = ocr_images([DATA_DIR / t for t in targets])
    ocr = {p.name: regs for p, regs in ocr.items()}

    tally = {"miss_delta": 0, "judges": 0, "song": 0}
    for name in targets:
        boxes = preds[name]
        tally["miss_delta"] += fix_miss_delta(boxes)
        tally["judges"] += fix_judges(boxes)
        tally["song"] += fix_song(boxes, ocr.get(name, []))
        boxes.sort(key=lambda b: (round(b["y"], 2), b["x"]))

    PRED_PATH.write_text(json.dumps(preds, indent=2, ensure_ascii=False))
    print(f"Fixed {len(targets)} images: "
          f"{tally['miss_delta']} stray miss-deltas dropped, "
          f"{tally['judges']} judge rows inserted, "
          f"{tally['song']} song boxes set.")


if __name__ == "__main__":
    main()
