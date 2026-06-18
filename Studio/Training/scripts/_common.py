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
OUTPUT_DIR = REPO_ROOT / "Outputs"
LABELS_DIR = TRAINING_DIR / "labels"
LABELS_FILE = LABELS_DIR / "labels.json"          # canonical, edited by labeler.py
AUTO_SEED_FILE = LABELS_DIR / "auto_seed.json"     # OCR-derived seeds
DATASET_DIR = TRAINING_DIR / "dataset"
MODELS_DIR = TRAINING_DIR / "models"
RANK_CLS_DIR = TRAINING_DIR / "rank_classifier_data"
SCHEMA_PATH = TRAINING_DIR / "schema.yaml"

IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".heic"}


def load_schema() -> dict:
    with SCHEMA_PATH.open("r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def iter_images(root: Path = DATA_DIR) -> Iterable[Path]:
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
