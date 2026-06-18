"""
End-to-end inference test: detector → per-ROI crops → OCR (Apple Vision)
→ rank/clear-type classifier → structured JSON.

Useful both as a sanity check (before exporting to Swift) and as the
reference implementation Swift code should mirror.

Usage:
    python scripts/inference_test.py ../data/IMG_0028.jpeg
    python scripts/inference_test.py ../data/IMG_0028.jpeg --json out.json
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import tempfile
from pathlib import Path

from _common import MODELS_DIR, load_schema
from _ocr import ocr_image
from PIL import Image
from ultralytics import YOLO


def ocr_crop(pil_img: Image.Image) -> str:
    """Run Apple Vision OCR on a cropped ROI and return concatenated text."""
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        tmp = Path(f.name)
    try:
        pil_img.save(tmp)
        recs = ocr_image(tmp)
        recs.sort(key=lambda r: (round(r["y"], 2), r["x"]))
        return " ".join(r["text"] for r in recs).strip()
    finally:
        tmp.unlink(missing_ok=True)


# ---------------------------------------------------------------------------
# Score parsing
# ---------------------------------------------------------------------------
DIGITS_RE = re.compile(r"\d+")


def parse_int(text: str) -> int | None:
    nums = DIGITS_RE.findall(text.replace(",", ""))
    return int("".join(nums)) if nums else None


# ---------------------------------------------------------------------------
# Pipeline
# ---------------------------------------------------------------------------
def run(image_path: Path) -> dict:
    schema = load_schema()
    det_classes = schema["detector"]["classes"]
    rank_classes = schema["rank_classifier"]["classes"]
    clear_classes = schema["clear_type_classifier"]["classes"]

    detector = YOLO(str(MODELS_DIR / "detector" / "weights" / "best.pt"))
    rank_clf = _load_or_none(MODELS_DIR / "rank_classifier" / "weights" / "best.pt")
    clear_clf = _load_or_none(MODELS_DIR / "clear_type_classifier" / "weights" / "best.pt")

    img = Image.open(image_path).convert("RGB")
    pred = detector.predict(
        str(image_path),
        imgsz=schema["training"]["detector"]["image_size"],
        verbose=False,
    )[0]

    rois: dict[str, list[Image.Image]] = {c: [] for c in det_classes}
    for box, cls_id, _conf in zip(
        pred.boxes.xyxy.tolist(),
        pred.boxes.cls.tolist(),
        pred.boxes.conf.tolist(),
        strict=True,
    ):
        name = det_classes[int(cls_id)]
        x1, y1, x2, y2 = map(int, box)
        rois[name].append(img.crop((x1, y1, x2, y2)))

    def first_text(name: str) -> str:
        crops = rois.get(name, [])
        return ocr_crop(crops[0]) if crops else ""

    def first_int(name: str) -> int | None:
        return parse_int(first_text(name))

    def classify(crop_name: str, clf, classes) -> str | None:
        crops = rois.get(crop_name, [])
        if not crops or clf is None:
            return None
        out = clf.predict(crops[0], verbose=False)[0]
        idx = int(out.probs.top1)
        return classes[idx]

    return {
        "song": {
            "title": first_text("song_title"),
            "artist": first_text("song_artist"),
            "difficulty": first_text("difficulty_label"),
            "notes": first_int("notes_count"),
        },
        "stage": first_text("stage_label"),
        "dj_level": {
            "current": classify("dj_level_now", rank_clf, rank_classes),
            "previous_best": classify("dj_level_prev", rank_clf, rank_classes),
        },
        "clear_type": {
            "current": classify("clear_type_now", clear_clf, clear_classes),
            "previous_best": classify("clear_type_prev", clear_clf, clear_classes),
        },
        "score": {
            "current": first_int("score_now"),
            "previous_best": first_int("score_prev"),
            "delta": parse_int(first_text("score_delta")),
        },
        "miss_count": {
            "current": first_int("miss_count_now"),
            "previous_best": first_int("miss_count_prev"),
            "delta": parse_int(first_text("miss_count_delta")),
        },
        "pacemaker_aa": first_int("pacemaker_aa"),
        "judgement": {
            "pgreat": first_int("judge_pgreat"),
            "great":  first_int("judge_great"),
            "good":   first_int("judge_good"),
            "bad":    first_int("judge_bad"),
            "poor":   first_int("judge_poor"),
        },
        "combo_break": first_int("combo_break"),
    }


def _load_or_none(path: Path) -> YOLO | None:
    return YOLO(str(path)) if path.exists() else None


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("image", type=Path)
    ap.add_argument("--json", type=Path, help="write to file instead of stdout")
    args = ap.parse_args()

    if not args.image.exists():
        sys.exit(f"no such image: {args.image}")

    out = run(args.image)
    rendered = json.dumps(out, indent=2, ensure_ascii=False)
    if args.json:
        args.json.write_text(rendered)
        print(f"wrote {args.json}")
    else:
        print(rendered)


if __name__ == "__main__":
    main()
