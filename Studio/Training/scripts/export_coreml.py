"""
Export trained YOLO weights → CoreML .mlpackage, attaching the schema
class names so a Swift consumer can decode predictions without a side file.

Outputs land in training/output/:
    DJDXResultDetector.mlpackage
    DJDXRankClassifier.mlpackage
    DJDXClearTypeClassifier.mlpackage  (if trained)
"""
from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

import coremltools as ct
from _common import MODELS_DIR, OUTPUT_DIR, load_schema
from ultralytics import YOLO


def _export(weights: Path, target_name: str, classes: list[str], imgsz: int,
            schema_coreml: dict, is_detector: bool) -> Path:
    if not weights.exists():
        raise SystemExit(f"missing weights: {weights}")

    model = YOLO(str(weights))
    print(f"Exporting {weights.name} → CoreML ({target_name})...")
    export_kwargs = {
        "format": "coreml",
        "imgsz": imgsz,
        "half": schema_coreml["compute_precision"] == "float16",
        "int8": False,
    }
    if is_detector:
        export_kwargs["nms"] = True  # ultralytics rejects nms=True for cls models
    exported = model.export(**export_kwargs)
    exported_path = Path(exported)

    # Load ultralytics' output, stamp metadata, save to OUTPUT_DIR.
    # Saving in place would trigger copytree(self, self) — coremltools holds
    # the package directory as its package_path, so save(same_path) errors out.
    mlmodel = ct.models.MLModel(str(exported_path))
    mlmodel.author = "DJDX PEAK training pipeline"
    mlmodel.short_description = (
        f"{target_name}: IIDX result-screen extraction. "
        f"Trained from training/schema.yaml."
    )
    mlmodel.user_defined_metadata["classes_json"] = json.dumps(classes)
    mlmodel.user_defined_metadata["schema_version"] = "1"

    dst = OUTPUT_DIR / f"{target_name}.mlpackage"
    if dst.exists():
        shutil.rmtree(dst)
    mlmodel.save(str(dst))
    # Tidy up the ultralytics-side copy now that the canonical one is in output/.
    if exported_path.exists() and exported_path != dst:
        shutil.rmtree(exported_path, ignore_errors=True)

    print(f"  → {dst}  ({len(classes)} classes)")
    return dst


def main() -> None:
    schema = load_schema()
    cml = schema["coreml"]

    ap = argparse.ArgumentParser()
    ap.add_argument("--only", choices=["detector", "rank", "clear_type"])
    ap.add_argument("--detector-name", default=None,
                    help="override the detector .mlpackage base name "
                         "(e.g. an evaluation model staged beside production)")
    args = ap.parse_args()

    OUTPUT_DIR.mkdir(exist_ok=True)
    detector_name = args.detector_name or cml["detector_output_name"]
    targets = {
        "detector": (
            MODELS_DIR / "detector" / "weights" / "best.pt",
            detector_name,
            schema["detector"]["classes"],
            schema["training"]["detector"]["image_size"],
        ),
        "rank": (
            MODELS_DIR / "rank_classifier" / "weights" / "best.pt",
            cml["rank_output_name"],
            schema["rank_classifier"]["classes"],
            schema["training"]["rank_classifier"]["image_size"],
        ),
        "clear_type": (
            MODELS_DIR / "clear_type_classifier" / "weights" / "best.pt",
            cml["clear_type_output_name"],
            schema["clear_type_classifier"]["classes"],
            schema["training"]["clear_type_classifier"]["image_size"],
        ),
    }

    for key, (weights, name, classes, imgsz) in targets.items():
        if args.only and args.only != key:
            continue
        if not weights.exists():
            print(f"  skip {key}: {weights} not found")
            continue
        _export(weights, name, classes, imgsz, cml, is_detector=(key == "detector"))


if __name__ == "__main__":
    main()
