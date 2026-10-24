"""Shared helpers: paths, schema loading, image enumeration."""
from __future__ import annotations

from collections.abc import Iterable
from pathlib import Path

import yaml

# Layout: scripts/ live under Training/; inputs/ and outputs/ are shared dirs
# at the repo root (one level above Training/), beside the Swift studio app.
TRAINING_DIR = Path(__file__).resolve().parents[1]   # the Training/ folder
REPO_ROOT = TRAINING_DIR.parent                       # repo root (studio app lives here)
DATA_DIR = REPO_ROOT / "Inputs"
# Inputs are split per training target (mirrors the app's workspaces):
#   Results/       full result-screen photos → result detector
#   DJLevels/      cropped rank glyphs        → rank classifier
#   DigitDetector/ cropped numeric fields     → digit detector
RESULTS_DIR = DATA_DIR / "Results"
DJLEVELS_DIR = DATA_DIR / "DJLevels"
DIGIT_DIR = DATA_DIR / "DigitDetector"

OUTPUT_DIR = REPO_ROOT / "Outputs"
# Result-detector export dumps reader-training crops here; the user then copies
# them into the matching Inputs/ subfolder to label in DJ Level / DigitDetector mode.
CROPS_OUT_DIR = OUTPUT_DIR / "crops"

LABELS_DIR = TRAINING_DIR / "labels"
LABELS_FILE = LABELS_DIR / "labels.json"            # result detector (bbox)
AUTO_SEED_FILE = LABELS_DIR / "auto_seed.json"       # OCR-derived seeds
DJLEVEL_LABELS_FILE = LABELS_DIR / "djlevel_labels.json"  # DJ level ({name: "AAA"})
DIGIT_LABELS_FILE = LABELS_DIR / "digit_labels.json"      # digit detector (per-digit bbox)

# All generated/derived artefacts live under Outputs/ (re-derivable from labels +
# scripts); Training/ holds only source: scripts, schema.yaml, and hand labels/.
DATASET_DIR = OUTPUT_DIR / "dataset"               # result detector YOLO dataset
DIGIT_DATASET_DIR = OUTPUT_DIR / "digit_dataset"   # digit detector YOLO dataset
MODELS_DIR = OUTPUT_DIR / "models"                 # YOLO training runs (weights, plots)
RANK_CLS_DIR = OUTPUT_DIR / "rank_classifier_data"   # rank classifier crops
CLEAR_CLS_DIR = OUTPUT_DIR / "clear_type_data"       # clear-type classifier crops
SCHEMA_PATH = TRAINING_DIR / "schema.yaml"

IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".heic"}


def load_schema() -> dict:
    with SCHEMA_PATH.open("r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def iter_images(root: Path = RESULTS_DIR) -> Iterable[Path]:
    for p in sorted(root.iterdir()):
        if p.suffix.lower() in IMAGE_SUFFIXES:
            yield p


def load_upright(path: Path):
    """Open an image and apply its EXIF orientation so pixels are upright.

    Some phone photos store landscape pixels with an EXIF orientation tag
    (e.g. tag 6 = rotate 90° CW). Tools that read raw pixels see them
    sideways. Normalising here keeps OCR, training, prediction, and
    rendering all consistent. Returns an RGB PIL.Image with no EXIF.
    """
    from PIL import Image, ImageOps

    im = Image.open(path)
    return ImageOps.exif_transpose(im).convert("RGB")


def best_device() -> str:
    """Pick the fastest available training device.

    Ultralytics only auto-selects CUDA-or-CPU; it never picks Apple's MPS
    backend on its own, so on Apple Silicon it silently falls back to CPU.
    Return "mps" when Metal is available so training uses the GPU.
    """
    import torch

    if torch.cuda.is_available():
        return "0"
    if torch.backends.mps.is_available():
        return "mps"
    return "cpu"
