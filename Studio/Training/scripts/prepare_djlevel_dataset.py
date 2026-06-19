"""
Materialise the DJ-level classification dataset for ``train_rank_classifier.py``.

The app's DJ Level mode labels each *already-cropped* rank glyph in
``Inputs/DJLevels/`` with a single class, saved to ``labels/djlevel_labels.json``:

    { "235__1.jpg": "AA", "IMG_0028__3.jpg": "AAA", ... }

ultralytics' YOLOv8-cls trainer instead wants a sorted folder layout
(``rank_classifier_data/<split>/<CLASS>/*.jpg``). This script bridges the two:
it splits the labelled images per ``schema.split`` and symlinks each into the
right ``train/`` / ``val/`` / ``test/`` class subfolder. Then:

    uv run python scripts/train_rank_classifier.py --target rank
"""
from __future__ import annotations

import argparse
import json
import random
import shutil
from pathlib import Path

from _common import (
    DJLEVEL_LABELS_FILE,
    DJLEVELS_DIR,
    RANK_CLS_DIR,
    load_schema,
)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--labels", type=Path, default=DJLEVEL_LABELS_FILE,
                    help=f"DJ-level labels JSON (default: {DJLEVEL_LABELS_FILE.name})")
    args = ap.parse_args()

    schema = load_schema()
    valid = set(schema["rank_classifier"]["classes"])

    if not args.labels.exists():
        raise SystemExit(
            f"no labels at {args.labels}.\n"
            "Label some crops in DJ Level mode first (copy Outputs/crops/DJLevels "
            "into Inputs/DJLevels, then tag each in the app)."
        )

    raw = json.loads(args.labels.read_text())
    items = [(name, cls) for name, cls in raw.items() if cls]
    bad = sorted({cls for _, cls in items if cls not in valid})
    if bad:
        raise SystemExit(f"labels reference classes not in schema rank_classifier: {bad}")
    if not items:
        raise SystemExit("no labelled images found.")
    print(f"Loaded {len(items)} labelled crops.")

    # Reset only the split dirs we own; leave any legacy _unsorted pile alone.
    for split in ("train", "val", "test"):
        d = RANK_CLS_DIR / split
        if d.exists():
            shutil.rmtree(d)

    rng = random.Random(schema["split"]["seed"])
    rng.shuffle(items)
    n = len(items)
    n_train = int(n * schema["split"]["train"])
    n_val = int(n * schema["split"]["val"])
    splits = {
        "train": items[:n_train],
        "val":   items[n_train:n_train + n_val],
        "test":  items[n_train + n_val:],
    }

    for split, group in splits.items():
        for name, cls in group:
            src = DJLEVELS_DIR / name
            if not src.exists():
                print(f"  missing: {name}, skipping")
                continue
            dst_dir = RANK_CLS_DIR / split / cls
            dst_dir.mkdir(parents=True, exist_ok=True)
            dst = dst_dir / name
            dst.unlink(missing_ok=True)
            dst.symlink_to(src.resolve())
        counts = {}
        for _, cls in group:
            counts[cls] = counts.get(cls, 0) + 1
        print(f"  {split}: {len(group)} images {dict(sorted(counts.items()))}")

    print(f"\nWrote {RANK_CLS_DIR}. Next: train_rank_classifier.py --target rank")


if __name__ == "__main__":
    main()
