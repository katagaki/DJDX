"""
Convert a labels JSON → YOLO format under a per-target dataset dir, plus
per-image ``.txt`` files and a ``dataset.yaml`` for ultralytics.

Two detector targets share this script (same YOLO machinery, different inputs):

    --target results   labels/labels.json        → dataset/        (result detector)
    --target digits    labels/digit_labels.json  → digit_dataset/  (digit detector)

Output layout (per target):
    <dataset>/
        images/{train,val,test}/<name>.jpg   (symlinks back to ../../Inputs/<dir>/)
        labels/{train,val,test}/<name>.txt   (YOLO: class cx cy w h, normalised)
        dataset.yaml

Extra crop emission (results target only):
    --emit-crops-to-outputs   DJ-level + numeric crops → ../Outputs/crops/{DJLevels,DigitDetector}/
                              (the app calls this on Result Detector export; you then copy
                               the crops into Inputs/DJLevels and Inputs/DigitDetector to label)
    --emit-classifier-crops   rank + clear-type sorted-crop piles under Training/ (legacy;
                              still used for the clear-type classifier)
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
    CROPS_OUT_DIR,
    DATASET_DIR,
    DIGIT_DATASET_DIR,
    DIGIT_DIR,
    DIGIT_LABELS_FILE,
    LABELS_FILE,
    RANK_CLS_DIR,
    RESULTS_DIR,
    TRAINING_DIR,
    load_schema,
    load_upright,
)

# Detector classes whose crops feed the two reader models. The result-detector
# export slices these out so DJ Level / DigitDetector mode have something to label.
DJLEVEL_CLASSES = ["dj_level_now", "dj_level_prev"]
NUMERIC_CLASSES = [
    "score_now", "score_prev", "score_delta",
    "miss_count_now", "miss_count_prev", "miss_count_delta",
    "pacemaker_aa",
    "judge_pgreat", "judge_great", "judge_good", "judge_bad", "judge_poor",
    "notes_count", "combo_break",
]

# Per-target wiring. "results" is the default and matches the historical behaviour.
TARGETS = {
    "results": {
        "data_dir": RESULTS_DIR,
        "labels_file": LABELS_FILE,
        "fallback": AUTO_SEED_FILE,
        "classes_key": "detector",
        "dataset_dir": DATASET_DIR,
    },
    "digits": {
        "data_dir": DIGIT_DIR,
        "labels_file": DIGIT_LABELS_FILE,
        "fallback": None,
        "classes_key": "digit_detector",
        "dataset_dir": DIGIT_DATASET_DIR,
    },
}


def load_labels(path: Path, fallback: Path | None) -> dict[str, list[dict]]:
    """Load a labels JSON, optionally falling back to an OCR seed so an
    unrefined run still produces a (rough) dataset."""
    if not path.exists() and fallback is not None and fallback.exists():
        path = fallback
    if not path.exists():
        hint = f" (or {fallback.name})" if fallback else ""
        raise SystemExit(
            f"no labels found at {path.name}{hint}.\n"
            "Label some images first (in the app, or scripts/auto_label.py)."
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
                          roi_class: str, out_root: Path, data_dir: Path) -> None:
    """Crop every box matching roi_class. Human then sorts into class subfolders."""
    pending = out_root / "_unsorted"
    pending.mkdir(parents=True, exist_ok=True)
    for name, boxes in items:
        src = data_dir / name
        if not src.exists():
            continue
        im = load_upright(src)
        iw, ih = im.size
        for i, b in enumerate(boxes):
            if b["cls"] != roi_class:
                continue
            x, y, w, h = _aabb(b)
            im.crop((
                int(x * iw), int(y * ih),
                int((x + w) * iw), int((y + h) * ih),
            )).save(pending / f"{Path(name).stem}__{i}.jpg")


def emit_crops_to_outputs(items: list[tuple[str, list[dict]]], data_dir: Path) -> None:
    """Slice DJ-level glyph crops and numeric-field crops out of the result-screen
    photos into ../Outputs/crops/{DJLevels,DigitDetector}/. These are the raw material
    the user copies into Inputs/DJLevels and Inputs/DigitDetector to label."""
    djl = CROPS_OUT_DIR / "DJLevels"
    sco = CROPS_OUT_DIR / "DigitDetector"
    djl.mkdir(parents=True, exist_ok=True)
    sco.mkdir(parents=True, exist_ok=True)
    n_djl = n_sco = 0
    for name, boxes in items:
        src = data_dir / name
        if not src.exists():
            continue
        im = None
        for i, b in enumerate(boxes):
            cls = b["cls"]
            if cls in DJLEVEL_CLASSES:
                dest = djl
            elif cls in NUMERIC_CLASSES:
                dest = sco
            else:
                continue
            if im is None:
                im = load_upright(src)
                iw, ih = im.size
            x, y, w, h = _aabb(b)
            im.crop((
                int(x * iw), int(y * ih),
                int((x + w) * iw), int((y + h) * ih),
            )).save(dest / f"{Path(name).stem}__{i}.jpg")
            if dest is djl:
                n_djl += 1
            else:
                n_sco += 1
    print(f"  → {n_djl} DJ-level crops → {djl}")
    print(f"  → {n_sco} numeric crops → {sco}")
    print("    Copy these into Inputs/DJLevels and Inputs/DigitDetector to label them.")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--target", choices=list(TARGETS), default="results",
                    help="which detector dataset to build (default: results)")
    ap.add_argument("--labels", type=Path, default=None,
                    help="override the labels JSON for the chosen target")
    ap.add_argument("--emit-classifier-crops", action="store_true",
                    help="(results) dump rank + clear-type crop piles under Training/")
    ap.add_argument("--emit-crops-to-outputs", action="store_true",
                    help="(results) dump DJ-level + numeric crops to ../Outputs/crops/")
    ap.add_argument("--train", type=int, default=None,
                    help="explicit train count (overrides schema split ratios)")
    ap.add_argument("--val", type=int, default=None,
                    help="explicit val (eval) count")
    ap.add_argument("--test", type=int, default=None,
                    help="explicit test count")
    args = ap.parse_args()

    tgt = TARGETS[args.target]
    data_dir: Path = tgt["data_dir"]
    dataset_dir: Path = tgt["dataset_dir"]

    schema = load_schema()
    classes = schema[tgt["classes_key"]]["classes"]
    class_to_id = {c: i for i, c in enumerate(classes)}

    labels = load_labels(args.labels or tgt["labels_file"], tgt["fallback"])
    items = list(labels.items())
    print(f"[{args.target}] Loaded {len(items)} labelled images from {data_dir.name}/.")

    if dataset_dir.exists():
        shutil.rmtree(dataset_dir)
    for split in ("train", "val", "test"):
        (dataset_dir / "images" / split).mkdir(parents=True)
        (dataset_dir / "labels" / split).mkdir(parents=True)

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

    from PIL import Image as _Image  # noqa: N813

    for split, group in splits.items():
        for name, boxes in group:
            src = data_dir / name
            if not src.exists():
                print(f"  missing: {name}, skipping")
                continue
            dst_img = dataset_dir / "images" / split / name
            # If the photo has a non-trivial EXIF orientation, bake an upright
            # copy so the trainer sees the same pixels as predict/draw_labels.
            # Otherwise symlink to save disk.
            orientation = _Image.open(src).getexif().get(274, 1)
            if orientation != 1:
                load_upright(src).save(dst_img, quality=95)
            else:
                with contextlib.suppress(FileExistsError):
                    dst_img.symlink_to(src.resolve())
            label_path = dataset_dir / "labels" / split / f"{Path(name).stem}.txt"
            write_yolo_label(label_path, boxes, class_to_id)
        print(f"  {split}: {len(group)} images")

    yaml_path = dataset_dir / "dataset.yaml"
    yaml_path.write_text(
        f"path: {dataset_dir}\n"
        f"train: images/train\n"
        f"val: images/val\n"
        f"test: images/test\n"
        f"names:\n" + "\n".join(f"  {i}: {c}" for i, c in enumerate(classes)) + "\n"
    )
    print(f"\nWrote {yaml_path}")

    if args.emit_crops_to_outputs:
        if args.target != "results":
            raise SystemExit("--emit-crops-to-outputs only applies to --target results")
        print("\nEmitting reader-training crops → ../Outputs/crops/")
        emit_crops_to_outputs(items, data_dir)

    if args.emit_classifier_crops:
        if args.target != "results":
            raise SystemExit("--emit-classifier-crops only applies to --target results")
        print("\nEmitting rank crops → rank_classifier_data/_unsorted/")
        emit_classifier_crops(items, "dj_level_now", RANK_CLS_DIR, data_dir)
        emit_classifier_crops(items, "dj_level_prev", RANK_CLS_DIR, data_dir)
        print("\nEmitting clear-type crops → clear_type_data/_unsorted/")
        clear_root = TRAINING_DIR / "clear_type_data"
        emit_classifier_crops(items, "clear_type_now", clear_root, data_dir)
        emit_classifier_crops(items, "clear_type_prev", clear_root, data_dir)
        print(
            "\nNext: move each crop into a subfolder named after its class\n"
            "      (F/E/D/C/B/A/AA/AAA for rank,\n"
            "       FAILED/CLEAR/HARD_CLEAR/... for clear type).\n"
            "      The classifier trainer reads that folder layout directly."
        )


if __name__ == "__main__":
    main()
