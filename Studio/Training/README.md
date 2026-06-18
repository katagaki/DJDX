# DJDX PEAK — Model Training

Trains the CoreML models that extract structured score information from
photographs of IIDX result screens.

## Architecture

A photo of a result screen contains rich, stylised graphics that defeat a
single end-to-end OCR model. Instead, we use a three-stage pipeline:

```
   photo
     │
     ▼
 ┌──────────────────────────┐
 │ 1. Object detector       │   YOLOv8n → CoreML
 │    Finds ROIs:           │   22 classes (score_now, dj_level_now, …)
 │    score, rank, song, …  │
 └────────────┬─────────────┘
              ▼
   ┌──────────────────────┐
   │ 2a. Apple Vision OCR │   Built in; no training
   │     on text ROIs     │   (score, miss count, song title, …)
   └──────────────────────┘
   ┌──────────────────────┐
   │ 2b. Image classifier │   YOLOv8n-cls → CoreML
   │     on glyph ROIs    │   rank: F/E/D/C/B/A/AA/AAA/MAX
   │                      │   clear: FAILED/CLEAR/H-CLEAR/…
   └──────────────────────┘
              ▼
 ┌──────────────────────────┐
 │ 3. Assembly              │   Structured JSON (see schema below)
 └──────────────────────────┘
```

Why split it up?

* The detector only has to *find* boxes, not read them. 22 classes × ~150
  training images is comfortably in YOLO's wheelhouse.
* OCR is solved well by Apple Vision; piggybacking saves us from training
  a digit reader on tiny stylised IIDX fonts.
* The rank and clear-type glyphs are highly stylised, so a small dedicated
  classifier on tight crops beats OCR on them.

All three artefacts ship as `.mlpackage` files (ML Program, FP16, iOS 17+
deployment target) ready to drop into a Swift app.

## Output schema

```json
{
  "song": {
    "title": "Fashion Fruit",
    "artist": "Tatsunoshin x Aira Arere",
    "difficulty": "ANOTHER",
    "notes": 1534
  },
  "stage": "EXTRA STAGE",
  "dj_level":   { "current": "A",  "previous_best": "B" },
  "clear_type": { "current": "A-CLEAR", "previous_best": "CLEAR" },
  "score":      { "current": 1906, "previous_best": 2031, "delta": -125 },
  "miss_count": { "current": 84,   "previous_best": 79,   "delta": 5 },
  "pacemaker_aa": 2387,
  "judgement": {
    "pgreat": 763, "great": 380, "good": 35, "bad": 24, "poor": 60
  },
  "combo_break": 69
}
```

## Workflow

### 0. Install

Uses [uv](https://docs.astral.sh/uv/) — installs Python 3.13, creates `.venv/`,
locks deps from `pyproject.toml`.

> Python is pinned to 3.13 (not 3.14) because `coremltools` 9.0 only ships
> prebuilt wheels through 3.13; on 3.14 it builds from source and the native
> `libmilstoragepython` / `libcoremlpython` blob serializers are absent, so
> `.mlpackage` writes fail with `BlobWriter not loaded`. Revisit when
> coremltools ships 3.14 wheels.

Lint with `uv run ruff check scripts/` — configured under `[tool.ruff]` in
`pyproject.toml`.

```sh
cd training
./setup.sh                      # = `uv sync`
```

Run scripts via `uv run` (auto-uses the venv, no `activate` needed):

```sh
uv run python scripts/<name>.py
```

Or activate the venv directly if you prefer:

```sh
source .venv/bin/activate
```

### 1. Auto-label (first pass)

```sh
uv run python scripts/auto_label.py
```

Runs Apple Vision OCR on every image in `../data/` and writes
`training/labels/auto_seed.json` — a flat
`{image_name: [{cls, x, y, w, h}, ...]}` dict. The class assignment is
intentionally permissive; the labeller is where you fix it.

### 2. Refine in the offline labeller

```sh
uv run python scripts/labeler.py
```

Native tkinter window — no web server, no extra deps. On launch it loads
your work-in-progress from `labels/labels.json`, falling back to
`labels/auto_seed.json` from step 1.

| Control                | Action |
|------------------------|--------|
| Click empty + drag     | Draw a new box in the armed class |
| Click box              | Select |
| Drag corner handle     | Resize |
| Drag box body          | Move |
| Right-side class list  | Click to arm class (or assign to selection) |
| `1`–`9`, `0`           | Hotkey first 10 classes |
| `/`                    | Cycle class of selected box |
| `←` / `→`              | Prev / next image (autosaves) |
| `Delete` / `Backspace` | Delete selected box |
| `Cmd+S` / `Ctrl+S`     | Save |
| `Cmd+Z` / `Ctrl+Z`     | Undo last edit on current image |

Saves to `labels/labels.json` — the same file `prepare_dataset.py` reads.
No export step.

### 3. Build the dataset

```sh
uv run python scripts/prepare_dataset.py --emit-classifier-crops
```

Writes the YOLO-format dataset to `training/dataset/` and dumps crops for
the rank and clear-type classifiers under
`training/rank_classifier_data/_unsorted/` and
`training/clear_type_data/_unsorted/`.

Sort each pile by hand into `train/<CLASS>/` and `val/<CLASS>/` subfolders.
This is the only step that doesn't scale, but it's a one-time ~30-minute
task across all 184 images.

### 4. Train

```sh
uv run python scripts/train_detector.py
uv run python scripts/train_rank_classifier.py --target rank
uv run python scripts/train_rank_classifier.py --target clear_type
```

Each writes to `training/models/<run-name>/weights/best.pt` and dumps loss
curves + a validation confusion matrix into the same folder.

### 5. Export to CoreML

```sh
uv run python scripts/export_coreml.py
```

Produces:

```
training/output/
    DJDXResultDetector.mlpackage
    DJDXRankClassifier.mlpackage
    DJDXClearTypeClassifier.mlpackage
```

Class names are baked into each model's `user_defined_metadata["classes_json"]`,
so the Swift consumer doesn't need a sidecar file.

### 6. Sanity check

```sh
uv run python scripts/inference_test.py ../data/IMG_0028.jpeg
```

Prints the structured JSON your Swift app should expect to emit. This script
is also the reference implementation — the Swift pipeline mirrors it
1-for-1 (detector → crop → Vision OCR for text ROIs, classifier inference
for glyph ROIs, assemble).

## Files

| Path | Purpose |
|---|---|
| `schema.yaml` | Single source of truth: class names, hyperparams, splits. Change here, not in scripts. |
| `pyproject.toml` / `.python-version` / `setup.sh` | Python env (managed by `uv`). |
| `uv.lock` | Reproducible dependency lockfile (generated by `uv sync`). |
| `scripts/labeler.py` | Offline native bbox labeller (tkinter, no deps). |
| `labels/auto_seed.json` | OCR-derived seed labels (written by `auto_label.py`). |
| `labels/labels.json` | Refined labels (the labeller writes here, prepare_dataset reads it). |
| `dataset/` | YOLO-format dataset (generated). |
| `rank_classifier_data/`, `clear_type_data/` | Classifier crops (generated, then hand-sorted). |
| `models/` | Training runs (weights, plots). |
| `output/` | Final `.mlpackage` artefacts. |
| `scripts/auto_label.py` | OCR-driven first-pass labelling. |
| `scripts/prepare_dataset.py` | `labels.json` → YOLO format. |
| `scripts/train_detector.py` | Trains the ROI detector. |
| `scripts/train_rank_classifier.py` | Trains rank / clear-type classifiers. |
| `scripts/export_coreml.py` | `.pt` → `.mlpackage`. |
| `scripts/inference_test.py` | End-to-end pipeline reference. |

## Consuming from Swift

```swift
import CoreML
import Vision

let detector = try VNCoreMLModel(for: DJDXResultDetector(configuration: .init()).model)
let rankClassifier = try VNCoreMLModel(for: DJDXRankClassifier(configuration: .init()).model)
let clearClassifier = try VNCoreMLModel(for: DJDXClearTypeClassifier(configuration: .init()).model)

// 1. Run detector on full image → VNRecognizedObjectObservations
// 2. For each observation:
//      - text ROIs → VNRecognizeTextRequest on the crop
//      - glyph ROIs (dj_level_*, clear_type_*) → run matching classifier
// 3. Assemble into your Codable result struct
```

`inference_test.py` is the canonical reference — Swift should produce the
same JSON shape for the same input.

## Iterating

* **More data improves everything.** Each new photo should be funnelled
  through steps 1–3 (auto-label → refine → re-build dataset → retrain).
* **Schema changes** (new fields, renamed classes) live in `schema.yaml`.
  Every script picks them up automatically — the labeller too.
* **Underperforming class?** Look at `models/detector/confusion_matrix.png`.
  Usually you just need more examples of that class.
