"""Shared helpers: paths, schema loading, image enumeration."""
from __future__ import annotations

from collections.abc import Iterable
from pathlib import Path

import yaml

TRAINING_DIR = Path(__file__).resolve().parents[1]
PROJECT_DIR = TRAINING_DIR.parent
DATA_DIR = PROJECT_DIR / "data"
LABELS_DIR = TRAINING_DIR / "labels"
LABELS_FILE = LABELS_DIR / "labels.json"          # canonical, edited by labeler.py
AUTO_SEED_FILE = LABELS_DIR / "auto_seed.json"     # OCR-derived seeds
DATASET_DIR = TRAINING_DIR / "dataset"
MODELS_DIR = TRAINING_DIR / "models"
OUTPUT_DIR = TRAINING_DIR / "output"
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
