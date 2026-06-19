"""
Seed labels via Apple Vision OCR so the human only refines bboxes
instead of drawing every one from scratch.

Reads every image in ``../Inputs/`` and writes a single
``labels/auto_seed.json`` keyed by image name:

    {
      "235.jpg": [
        {"cls": "score_now", "x": 0.21, "y": 0.49, "w": 0.18, "h": 0.03},
        ...
      ],
      "IMG_0028.jpeg": [...]
    }

The labeller (``scripts/labeler.py``) reads this on first launch, lets the
human refine, then writes ``labels.json`` in the same shape.
"""
from __future__ import annotations

import argparse
import json
import re

from _common import AUTO_SEED_FILE, DATA_DIR, iter_images, load_schema
from _ocr import ocr_images

# ---------------------------------------------------------------------------
# Snap recognised text → schema class via positional + content heuristics.
# Loose on purpose; the human refines in the labeller.
# ---------------------------------------------------------------------------
DIGIT_RE = re.compile(r"^\d{1,5}$")
DELTA_RE = re.compile(r"^[+\-]\d+$")
CLEAR_WORDS = {
    "FAILED", "NO PLAY", "CLEAR", "H-CLEAR", "EX-HARD",
    "ASSIST", "EASY", "FULLCOMBO", "A-CLEAR",
}


def classify(rec: dict) -> str:
    txt = rec["text"].strip().upper()
    x, y = rec["x"], rec["y"]
    in_left_col = 0.05 < x < 0.55

    if not in_left_col:
        if "NOTES" in txt:
            return "notes_count"
        if any(d in txt for d in ("HYPER", "ANOTHER", "LEGGENDARIA", "NORMAL", "BEGINNER")):
            return "difficulty_label"
        if "STAGE RESULT" in txt:
            return "stage_label"
        if 0.80 < y < 0.95:
            return "song_title"
        if 0.85 < y < 0.99:
            return "song_artist"
        return "unlabeled_text"

    if "PACEMAKER" in txt:
        return "pacemaker_aa"
    if "CLEAR TYPE" in txt or txt in CLEAR_WORDS or "CLEAR" in txt or "FAILED" in txt:
        return "clear_type_now"
    if "DJ LEVEL" in txt or txt == "SCORE" or "MISS COUNT" in txt:
        return "unlabeled_text"

    if DELTA_RE.match(txt):
        return "score_delta"

    if DIGIT_RE.match(txt):
        # Vertical bands (rough IIDX result layout):
        # score row    ~ y 0.45-0.55
        # miss row     ~ y 0.55-0.65
        # pacemaker    ~ y 0.65-0.72
        # judgement table inside pie callout ~ y 0.75-0.90
        if 0.43 <= y <= 0.55:
            return "score_now"
        if 0.55 <= y <= 0.66:
            return "miss_count_now"
        if 0.65 <= y <= 0.74:
            return "pacemaker_aa"
        if 0.72 <= y <= 0.95:
            return "judge_great"

    return "unlabeled_text"


def rec_to_box(rec: dict) -> dict:
    return {
        "cls": classify(rec),
        "x": rec["x"], "y": rec["y"],
        "w": rec["w"], "h": rec["h"],
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--batch", type=int, default=8,
                    help="images per ocr_helper subprocess")
    ap.add_argument("--limit", type=int, default=None,
                    help="only process the first N images")
    args = ap.parse_args()

    schema = load_schema()
    valid = set(schema["detector"]["classes"]) | {"unlabeled_text"}
    images = list(iter_images(DATA_DIR))
    if args.limit:
        images = images[: args.limit]

    seeds: dict[str, list[dict]] = {}
    for start in range(0, len(images), args.batch):
        chunk = images[start: start + args.batch]
        for img, recs in ocr_images(chunk).items():
            boxes = [rec_to_box(r) for r in recs]
            for b in boxes:
                assert b["cls"] in valid, f"unknown class {b['cls']}"
            seeds[img.name] = boxes
            print(f"OCR {img.name}: {len(boxes)} regions")

    AUTO_SEED_FILE.parent.mkdir(parents=True, exist_ok=True)
    AUTO_SEED_FILE.write_text(json.dumps(seeds, indent=2))
    print(f"\nWrote {len(seeds)} entries → {AUTO_SEED_FILE}")


if __name__ == "__main__":
    main()
