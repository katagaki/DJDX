"""
Train the DJ-level rank classifier (and, optionally, the clear-type classifier).

Expected input layout (produced by prepare_dataset.py --emit-classifier-crops,
then sorted into class subfolders by hand):

    rank_classifier_data/
        train/{F,E,D,C,B,A,AA,AAA}/*.jpg
        val/{F,E,D,C,B,A,AA,AAA}/*.jpg

ultralytics' YOLOv8-cls handles the train/val split if you only provide one
folder per class — it'll auto-split — but we recommend explicit train/val
folders so the same images don't drift between runs.
"""
from __future__ import annotations

import argparse
from pathlib import Path

from _common import CLEAR_CLS_DIR, MODELS_DIR, RANK_CLS_DIR, best_device, load_schema
from ultralytics import YOLO


def main() -> None:
    schema = load_schema()
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--target",
        choices=["rank", "clear_type"],
        default="rank",
        help="Which classifier to train (uses its hyperparams from schema.yaml)",
    )
    ap.add_argument("--epochs", type=int)
    ap.add_argument("--batch",  type=int)
    ap.add_argument("--imgsz",  type=int)
    ap.add_argument("--data",   type=Path)
    ap.add_argument("--device", default=best_device(),
                    help="Training device (e.g. mps, cpu, 0). Defaults to the GPU when available.")
    args = ap.parse_args()

    if args.target == "rank":
        hp = schema["training"]["rank_classifier"]
        data_dir = args.data or RANK_CLS_DIR
        run_name = "rank_classifier"
    else:
        hp = schema["training"]["clear_type_classifier"]
        data_dir = args.data or CLEAR_CLS_DIR
        run_name = "clear_type_classifier"

    if not data_dir.exists():
        raise SystemExit(
            f"{data_dir} not found. Run prepare_dataset.py --emit-classifier-crops\n"
            "and sort the unsorted crops into class subfolders first."
        )

    model = YOLO(hp["base_weights"])
    model.train(
        data=str(data_dir),
        epochs=args.epochs or hp["epochs"],
        batch=args.batch or hp["batch"],
        imgsz=args.imgsz or hp["image_size"],
        device=args.device,
        project=str(MODELS_DIR),
        name=run_name,
        exist_ok=True,
        plots=True,
        save=True,
    )
    print(f"\nBest weights: {MODELS_DIR / run_name / 'weights' / 'best.pt'}")


if __name__ == "__main__":
    main()
