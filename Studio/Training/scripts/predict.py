"""
Run the trained detector on one or more images and write predictions to a
labels.json-compatible JSON so they can be inspected with draw_labels.py.

Usage:
    uv run python scripts/predict.py IMG_1081.jpeg IMG_1156.jpeg
    uv run python scripts/predict.py --next 5            # next 5 unlabelled images
    uv run python scripts/predict.py --out /tmp/pred.json IMG_1081.jpeg

By default writes ``../Outputs/predictions.json``. Then:

    uv run python scripts/draw_labels.py --labels ../Outputs/predictions.json
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from _common import (
    DATA_DIR,
    LABELS_FILE,
    MODELS_DIR,
    OUTPUT_DIR,
    iter_images,
    load_schema,
    load_upright,
)
from ultralytics import YOLO

DEFAULT_OUT = OUTPUT_DIR / "predictions.json"


def _iou(a: dict, b: dict) -> float:
    ax1, ay1, ax2, ay2 = a["x"], a["y"], a["x"] + a["w"], a["y"] + a["h"]
    bx1, by1, bx2, by2 = b["x"], b["y"], b["x"] + b["w"], b["y"] + b["h"]
    ix1, iy1 = max(ax1, bx1), max(ay1, by1)
    ix2, iy2 = min(ax2, bx2), min(ay2, by2)
    if ix2 <= ix1 or iy2 <= iy1:
        return 0.0
    inter = (ix2 - ix1) * (iy2 - iy1)
    union = a["w"] * a["h"] + b["w"] * b["h"] - inter
    return inter / union if union > 0 else 0.0


def dedupe_per_class(boxes: list[dict], iou_threshold: float = 0.4) -> list[dict]:
    """Per-class NMS: drop any box that overlaps an already-kept higher-conf
    box of the same class by more than ``iou_threshold``."""
    by_class: dict[str, list[dict]] = {}
    for b in boxes:
        by_class.setdefault(b["cls"], []).append(b)
    kept: list[dict] = []
    for group in by_class.values():
        group_sorted = sorted(group, key=lambda b: -b.get("conf", 0))
        survivors: list[dict] = []
        for b in group_sorted:
            if any(_iou(b, k) > iou_threshold for k in survivors):
                continue
            survivors.append(b)
        kept.extend(survivors)
    kept.sort(key=lambda b: (round(b["y"], 2), b["x"]))
    return kept


# Mutually exclusive class pairs — these occupy the LEFT vs RIGHT cells of
# the same result row, so a true _prev and true _now never overlap. If the
# model predicts both at the same position, one is wrong; keep the higher conf.
EXCLUSIVE_PAIRS = [
    ("clear_type_prev", "clear_type_now"),
    ("score_prev",      "score_now"),
    ("miss_count_prev", "miss_count_now"),
    ("dj_level_prev",   "dj_level_now"),
]


# Classes that live in specific regions of the screen. Any detection
# outside its expected region is almost certainly a false positive from
# the right-side leaderboard / rival panel / character art.
_LEFT_TABLE_CLASSES = {
    "clear_type_prev", "clear_type_now",
    "dj_level_prev", "dj_level_now",
    "score_prev", "score_now", "score_delta",
    "miss_count_prev", "miss_count_now", "miss_count_delta",
    "pacemaker_aa",
    "judge_pgreat", "judge_great", "judge_good", "judge_bad", "judge_poor",
}
_BOTTOM_INFO_CLASSES = {
    "song_title", "song_artist", "difficulty_label", "notes_count",
}


def positional_filter(boxes: list[dict]) -> list[dict]:
    """Drop predictions outside their expected screen region.
    The right-side leaderboard panel often gets false positives."""
    out = []
    for b in boxes:
        cls = b["cls"]
        x, y, w = b["x"], b["y"], b["w"]
        x_end = x + w
        if cls in _LEFT_TABLE_CLASSES and x_end > 0.60:
            continue   # result-table classes only on the left half
        if cls in _BOTTOM_INFO_CLASSES and y < 0.75:
            continue   # song info / difficulty only in bottom band
        if cls == "stage_label" and (y > 0.20 or w < 0.10 or x > 0.70):
            continue   # stage banner: top, wide, left of right-edge
        out.append(b)
    return out


def enforce_singletons(boxes: list[dict]) -> list[dict]:
    """Every field on a result screen appears exactly once, so keep only the
    highest-confidence detection per class. Catches non-overlapping duplicates
    that NMS can't (e.g. dj_level_prev firing on both row glyphs)."""
    best: dict[str, dict] = {}
    for b in boxes:
        cur = best.get(b["cls"])
        if cur is None or b.get("conf", 0) > cur.get("conf", 0):
            best[b["cls"]] = b
    return list(best.values())


def dedupe_cross_class(boxes: list[dict], iou_threshold: float = 0.4) -> list[dict]:
    """For each mutually-exclusive class pair, if a box of class A overlaps a
    box of class B by more than ``iou_threshold``, drop the lower-confidence
    one. Resolves "model can't decide between prev and now at this position"."""
    drop: set[int] = set()
    for a_cls, b_cls in EXCLUSIVE_PAIRS:
        a_idx = [i for i, b in enumerate(boxes) if b["cls"] == a_cls]
        b_idx = [i for i, b in enumerate(boxes) if b["cls"] == b_cls]
        for i in a_idx:
            for j in b_idx:
                if i in drop or j in drop:
                    continue
                if _iou(boxes[i], boxes[j]) > iou_threshold:
                    loser = i if boxes[i].get("conf", 0) < boxes[j].get("conf", 0) else j
                    drop.add(loser)
    return [b for i, b in enumerate(boxes) if i not in drop]


EXCLUDE_FILE = LABELS_FILE.parent / "exclude.json"


def _excluded() -> set[str]:
    """Image filenames to skip entirely (outliers, unusable crops)."""
    if EXCLUDE_FILE.exists():
        return set(json.loads(EXCLUDE_FILE.read_text()))
    return set()


def _unlabelled(n: int) -> list[Path]:
    labelled = set(json.loads(LABELS_FILE.read_text()).keys()) if LABELS_FILE.exists() else set()
    skip = labelled | _excluded()
    out = []
    for p in iter_images(DATA_DIR):
        if p.name in skip:
            continue
        out.append(p)
        if len(out) >= n:
            break
    return out


def predict(images: list[Path], weights: Path, conf: float = 0.15,
            dedupe_iou: float = 0.4, singletons: bool = True) -> dict[str, list[dict]]:
    schema = load_schema()
    classes = schema["detector"]["classes"]
    model = YOLO(str(weights))
    results: dict[str, list[dict]] = {}
    for img in images:
        # Load with EXIF orientation applied so rotated phone photos are
        # upright; feed the array directly so model + coords agree.
        im = load_upright(img)
        iw, ih = im.size
        pred = model.predict(
            im,
            imgsz=schema["training"]["detector"]["image_size"],
            conf=conf,
            verbose=False,
        )[0]
        boxes = []
        for box, cls_id, score in zip(
            pred.boxes.xyxy.tolist(),
            pred.boxes.cls.tolist(),
            pred.boxes.conf.tolist(),
            strict=True,
        ):
            x1, y1, x2, y2 = box
            boxes.append({
                "cls": classes[int(cls_id)],
                "x": x1 / iw,
                "y": y1 / ih,
                "w": (x2 - x1) / iw,
                "h": (y2 - y1) / ih,
                "conf": round(float(score), 3),
            })
        raw = len(boxes)
        boxes = positional_filter(boxes)
        if dedupe_iou > 0:
            boxes = dedupe_per_class(boxes, iou_threshold=dedupe_iou)
            boxes = dedupe_cross_class(boxes, iou_threshold=dedupe_iou)
        if singletons:
            boxes = enforce_singletons(boxes)
        boxes.sort(key=lambda b: (round(b["y"], 2), b["x"]))
        results[img.name] = boxes
        suffix = f" (raw: {raw})" if raw != len(boxes) else ""
        print(f"  {img.name}: {len(boxes)} detections{suffix}")
    return results


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("images", nargs="*", help="image filenames in ../Inputs/")
    ap.add_argument("--next", type=int, default=0,
                    help="run on the next N images NOT in labels.json")
    ap.add_argument("--weights", type=Path,
                    default=MODELS_DIR / "detector" / "weights" / "best.pt")
    ap.add_argument("--conf", type=float, default=0.15,
                    help="confidence threshold (default: 0.15, conservative)")
    ap.add_argument("--dedupe-iou", type=float, default=0.4,
                    help="per-class NMS IoU threshold; 0 disables (default: 0.4)")
    ap.add_argument("--no-singletons", action="store_true",
                    help="disable keep-top-1-per-class (every field is unique per screen)")
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = ap.parse_args()

    if not args.weights.exists():
        raise SystemExit(f"weights not found: {args.weights}\nTrain first via train_detector.py")

    if args.next:
        targets = _unlabelled(args.next)
    elif args.images:
        targets = [DATA_DIR / n for n in args.images]
    else:
        raise SystemExit("pass image filenames or --next N")

    missing = [p for p in targets if not p.exists()]
    if missing:
        raise SystemExit(f"missing images: {[p.name for p in missing]}")

    preds = predict(targets, args.weights, conf=args.conf, dedupe_iou=args.dedupe_iou,
                    singletons=not args.no_singletons)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(preds, indent=2))
    print(f"\nWrote {args.out}")
    print(f"Render: uv run python scripts/draw_labels.py --labels {args.out}")


if __name__ == "__main__":
    main()
