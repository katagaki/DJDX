"""Train a YOLOv8 detector on a prepared dataset.

Two targets share this script (same machinery, different dataset + hyperparams):
    --target results   dataset/        → models/detector        (ROI detector)
    --target digits    digit_dataset/  → models/digit_detector  (per-digit reader)
"""
from __future__ import annotations

import argparse

from _common import DATASET_DIR, DIGIT_DATASET_DIR, MODELS_DIR, best_device, load_schema
from ultralytics import YOLO

# dataset dir, schema hyperparam key, run name (under models/).
TARGETS = {
    "results": (DATASET_DIR, "detector", "detector"),
    "digits": (DIGIT_DATASET_DIR, "digit_detector", "digit_detector"),
}


def main() -> None:
    pre = argparse.ArgumentParser(add_help=False)
    pre.add_argument("--target", choices=list(TARGETS), default="results")
    known, _ = pre.parse_known_args()
    dataset_dir, hp_key, run_name = TARGETS[known.target]

    schema = load_schema()
    hp = schema["training"][hp_key]
    aug = hp["augmentations"]

    ap = argparse.ArgumentParser(parents=[pre])
    ap.add_argument("--epochs", type=int, default=hp["epochs"])
    ap.add_argument("--batch",  type=int, default=hp["batch"])
    ap.add_argument("--imgsz",  type=int, default=hp["image_size"])
    ap.add_argument("--weights", default=hp["base_weights"])
    ap.add_argument("--device", default=best_device(),
                    help="Training device (e.g. mps, cpu, 0). Defaults to the GPU when available.")
    ap.add_argument("--cache", default=hp.get("cache", "ram"),
                    help="Image cache: 'ram', 'disk', or '' to disable. RAM is fastest for small sets.")
    ap.add_argument("--workers", type=int, default=hp.get("workers", 8))
    ap.add_argument("--resume", action="store_true")
    args = ap.parse_args()

    dataset_yaml = dataset_dir / "dataset.yaml"
    if not dataset_yaml.exists():
        raise SystemExit(
            f"Expected {dataset_yaml}; run prepare_dataset.py --target {known.target} first."
        )

    model = YOLO(args.weights)
    model.train(
        data=str(dataset_yaml),
        epochs=args.epochs,
        batch=args.batch,
        imgsz=args.imgsz,
        device=args.device,
        cache=(args.cache or False),
        workers=args.workers,
        patience=hp["patience"],
        project=str(MODELS_DIR),
        name=run_name,
        exist_ok=True,
        resume=args.resume,
        # augmentations
        mosaic=aug["mosaic"],
        mixup=aug["mixup"],
        hsv_h=aug["hsv_h"],
        hsv_s=aug["hsv_s"],
        hsv_v=aug["hsv_v"],
        degrees=aug["degrees"],
        translate=aug["translate"],
        scale=aug["scale"],
        perspective=aug["perspective"],
        fliplr=aug["fliplr"],
        # bookkeeping
        plots=True,
        save=True,
    )

    print(f"\nBest weights: {MODELS_DIR / run_name / 'weights' / 'best.pt'}")


if __name__ == "__main__":
    main()
