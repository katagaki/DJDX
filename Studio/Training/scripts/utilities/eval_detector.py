"""Validate the result detector and print mAP50 metrics as JSON.

Reports overall mAP50 plus the per-class AP50 / precision / recall for the
class(es) of interest (default dj_level_now), so a relabeling loop can track
exactly the class it is changing.

    uv run python scripts/eval_detector.py [--model PATH] [--split val]
"""
from __future__ import annotations

import argparse
import json

import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent.parent))  # Training/scripts: shared _common/_ocr
from _common import DATASET_DIR, MODELS_DIR, OUTPUT_DIR
from ultralytics import YOLO


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default=str(MODELS_DIR / "detector" / "weights" / "best.pt"))
    ap.add_argument("--data", default=str(DATASET_DIR / "dataset.yaml"))
    ap.add_argument("--split", default="val")
    ap.add_argument("--imgsz", type=int, default=768)
    ap.add_argument("--classes", nargs="*", default=["dj_level_now", "dj_level_prev"])
    ap.add_argument("--tag", default="")
    args = ap.parse_args()

    model = YOLO(args.model)
    # project/name keep YOLO's val artefacts under Outputs/runs (not a stray
    # runs/ in the CWD / Training).
    m = model.val(data=args.data, split=args.split, imgsz=args.imgsz,
                  verbose=False, plots=False,
                  project=str(OUTPUT_DIR / "runs"), name="val", exist_ok=True)
    names = m.names  # id -> name
    box = m.box
    idx = list(box.ap_class_index)  # class ids that have instances in val

    per = {}
    for ci in idx:
        nm = names[ci]
        pos = idx.index(ci)
        per[nm] = {
            "ap50": round(float(box.ap50[pos]), 4),
            "ap": round(float(box.ap[pos]), 4),
            "p": round(float(box.p[pos]), 4),
            "r": round(float(box.r[pos]), 4),
        }

    out = {
        "tag": args.tag,
        "model": args.model,
        "split": args.split,
        "map50": round(float(box.map50), 4),
        "map50_95": round(float(box.map), 4),
        "n_classes_eval": len(idx),
    }
    for c in args.classes:
        out[c] = per.get(c, None)
    print("EVAL_JSON " + json.dumps(out))


if __name__ == "__main__":
    main()
