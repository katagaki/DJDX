"""
Convert ``training/labels/labels.json`` → YOLO format under ``training/dataset/``,
plus per-image ``.txt`` files and a ``dataset.yaml`` for ultralytics.

Output layout:
    training/dataset/
        images/{train,val,test}/<name>.jpg   (symlinks back to ../../data/)
        labels/{train,val,test}/<name>.txt   (YOLO: class cx cy w h, normalised)
        dataset.yaml

Also emits per-class crops for the rank + clear-type classifiers under
``training/rank_classifier_data/`` if ``--emit-classifier-crops`` is passed.
"""
from __future__ import annotations

import argparse
import contextlib
import json
import random
import shutil
from pathlib import Path

from _common import (
    AUTO_SEED_FILE,
    DATA_DIR,
    DATASET_DIR,
    LABELS_FILE,
    RANK_CLS_DIR,
    TRAINING_DIR,
    load_schema,
)
from PIL import Image


def load_labels(path: Path | None) -> dict[str, list[dict]]:
    """Load labels.json, falling back to auto_seed.json so an unrefined
    run still produces a (rough) dataset."""
    if path is None:
        path = LABELS_FILE if LABELS_FILE.exists() else AUTO_SEED_FILE
    if not path.exists():
        raise SystemExit(
            f"no labels found (looked at {LABELS_FILE.name} and {AUTO_SEED_FILE.name}).\n"
            "Run scripts/auto_label.py first."
        )
    print(f"Reading labels from {path.name}")
    data = json.loads(path.read_text())
    return {name: boxes for name, boxes in data.items() if boxes}


def _aabb(b: dict) -> tuple[float, float, float, float]:
    """Axis-aligned (x, y, w, h) in [0, 1] for either format."""
    if "polygon" in b:
        xs = [p[0] for p in b["polygon"]]
        ys = [p[1] for p in b["polygon"]]
        x, y = min(xs), min(ys)
        return x, y, max(xs) - x, max(ys) - y
    return b["x"], b["y"], b["w"], b["h"]


def write_yolo_label(path: Path, boxes: list[dict], class_to_id: dict[str, int]) -> None:
    lines = []
    for b in boxes:
        if b["cls"] not in class_to_id:
            continue   # e.g. "unlabeled_text" — present in seeds, not in the schema
        cid = class_to_id[b["cls"]]
        x, y, w, h = _aabb(b)
        cx = x + w / 2
        cy = y + h / 2
        lines.append(f"{cid} {cx:.6f} {cy:.6f} {w:.6f} {h:.6f}")
    path.write_text("\n".join(lines))


def emit_classifier_crops(items: list[tuple[str, list[dict]]],
                          roi_class: str, out_root: Path) -> None:
    """Crop every box matching roi_class. Human then sorts into class subfolders."""
    pending = out_root / "_unsorted"
    pending.mkdir(parents=True, exist_ok=True)
    for name, boxes in items:
        src = DATA_DIR / name
        if not src.exists():
            continue
        with Image.open(src) as im:
            iw, ih = im.size
            for i, b in enumerate(boxes):
                if b["cls"] != roi_class:
                    continue
                x, y, w, h = _aabb(b)
                im.crop((
                    int(x * iw), int(y * ih),
                    int((x + w) * iw), int((y + h) * ih),
                )).save(pending / f"{Path(name).stem}__{i}.jpg")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--labels", type=Path, default=None,
                    help=f"labels JSON (default: {LABELS_FILE.name}, "
                         f"fallback: {AUTO_SEED_FILE.name})")
    ap.add_argument("--emit-classifier-crops", action="store_true")
    ap.add_argument("--train", type=int, default=None,
                    help="explicit train count (overrides schema split ratios)")
    ap.add_argument("--val", type=int, default=None,
                    help="explicit val (eval) count")
    ap.add_argument("--test", type=int, default=None,
                    help="explicit test count")
    args = ap.parse_args()

    schema = load_schema()
    classes = schema["detector"]["classes"]
    class_to_id = {c: i for i, c in enumerate(classes)}

    labels = load_labels(args.labels)
    items = list(labels.items())
    print(f"Loaded {len(items)} labelled images.")

    if DATASET_DIR.exists():
        shutil.rmtree(DATASET_DIR)
    for split in ("train", "val", "test"):
        (DATASET_DIR / "images" / split).mkdir(parents=True)
        (DATASET_DIR / "labels" / split).mkdir(parents=True)

    rng = random.Random(schema["split"]["seed"])
    rng.shuffle(items)
    n = len(items)

    if args.train is not None or args.val is not None:
        n_train = args.train or 0
        n_val = args.val or 0
        n_test = args.test or 0
        if n_train + n_val + n_test > n:
            raise SystemExit(
                f"requested {n_train}+{n_val}+{n_test}={n_train+n_val+n_test} "
                f"but only {n} labelled images available"
            )
    else:
        n_train = int(n * schema["split"]["train"])
        n_val = int(n * schema["split"]["val"])
        n_test = n - n_train - n_val

    splits = {
        "train": items[:n_train],
        "val":   items[n_train:n_train + n_val],
        "test":  items[n_train + n_val:n_train + n_val + n_test],
    }

    for split, group in splits.items():
        for name, boxes in group:
            src = DATA_DIR / name
            if not src.exists():
                print(f"  missing: {name}, skipping")
                continue
            dst_img = DATASET_DIR / "images" / split / name
            with contextlib.suppress(FileExistsError):
                dst_img.symlink_to(src.resolve())
            label_path = DATASET_DIR / "labels" / split / f"{Path(name).stem}.txt"
            write_yolo_label(label_path, boxes, class_to_id)
        print(f"  {split}: {len(group)} images")

    yaml_path = DATASET_DIR / "dataset.yaml"
    yaml_path.write_text(
        f"path: {DATASET_DIR}\n"
        f"train: images/train\n"
        f"val: images/val\n"
        f"test: images/test\n"
        f"names:\n" + "\n".join(f"  {i}: {c}" for i, c in enumerate(classes)) + "\n"
    )
    print(f"\nWrote {yaml_path}")

    if args.emit_classifier_crops:
        print("\nEmitting rank crops → training/rank_classifier_data/_unsorted/")
        emit_classifier_crops(items, "dj_level_now", RANK_CLS_DIR)
        emit_classifier_crops(items, "dj_level_prev", RANK_CLS_DIR)
        print("\nEmitting clear-type crops → training/clear_type_data/_unsorted/")
        clear_root = TRAINING_DIR / "clear_type_data"
        emit_classifier_crops(items, "clear_type_now", clear_root)
        emit_classifier_crops(items, "clear_type_prev", clear_root)
        print(
            "\nNext: move each crop into a subfolder named after its class\n"
            "      (F/E/D/C/B/A/AA/AAA/MAX for rank,\n"
            "       FAILED/CLEAR/HARD_CLEAR/... for clear type).\n"
            "      The classifier trainer reads that folder layout directly."
        )


if __name__ == "__main__":
    main()
