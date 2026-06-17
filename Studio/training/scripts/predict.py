"""
Run the trained detector on one or more images and write predictions to a
labels.json-compatible JSON so they can be inspected with draw_labels.py.

Usage:
    uv run python scripts/predict.py IMG_1081.jpeg IMG_1156.jpeg
    uv run python scripts/predict.py --next 5            # next 5 unlabelled images
    uv run python scripts/predict.py --out /tmp/pred.json IMG_1081.jpeg

By default writes ``training/output/predictions.json``. Then:

    uv run python scripts/draw_labels.py --labels output/predictions.json
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from _common import DATA_DIR, LABELS_FILE, MODELS_DIR, OUTPUT_DIR, iter_images, load_schema
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


def _unlabelled(n: int) -> list[Path]:
    labelled = set(json.loads(LABELS_FILE.read_text()).keys()) if LABELS_FILE.exists() else set()
    out = []
    for p in iter_images(DATA_DIR):
        if p.name in labelled:
            continue
        out.append(p)
        if len(out) >= n:
            break
    return out


def predict(images: list[Path], weights: Path, conf: float = 0.15,
            dedupe_iou: float = 0.4) -> dict[str, list[dict]]:
    schema = load_schema()
    classes = schema["detector"]["classes"]
    model = YOLO(str(weights))
    results: dict[str, list[dict]] = {}
    for img in images:
        from PIL import Image
        with Image.open(img) as im:
            iw, ih = im.size
        pred = model.predict(
            str(img),
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
        if dedupe_iou > 0:
            boxes = dedupe_per_class(boxes, iou_threshold=dedupe_iou)
        results[img.name] = boxes
        suffix = f" (raw: {raw})" if raw != len(boxes) else ""
        print(f"  {img.name}: {len(boxes)} detections{suffix}")
    return results


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("images", nargs="*", help="image filenames in ../data/")
    ap.add_argument("--next", type=int, default=0,
                    help="run on the next N images NOT in labels.json")
    ap.add_argument("--weights", type=Path,
                    default=MODELS_DIR / "detector" / "weights" / "best.pt")
    ap.add_argument("--conf", type=float, default=0.15,
                    help="confidence threshold (default: 0.15, conservative)")
    ap.add_argument("--dedupe-iou", type=float, default=0.4,
                    help="per-class NMS IoU threshold; 0 disables (default: 0.4)")
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

    preds = predict(targets, args.weights, conf=args.conf, dedupe_iou=args.dedupe_iou)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(preds, indent=2))
    print(f"\nWrote {args.out}")
    print(f"Render: uv run python scripts/draw_labels.py --labels {args.out}")


if __name__ == "__main__":
    main()
