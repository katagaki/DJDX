# DJDX PEAK — Model Training

Trains the CoreML models that extract structured score information from
photographs of IIDX result screens.

Inputs live in `../Inputs/`, split per training target (mirroring the studio
app's three workspaces), and all generated artefacts (`.mlpackage` models,
crops, prediction/label previews) land in `../Outputs/`, both at the repo root
beside the Swift studio app — *not* inside `Training/`.

```
../Inputs/
    Results/        full result-screen photos   → DJDXResultDetector  (object detector)
    DJLevels/       cropped rank glyphs          → DJDXRankClassifier  (image classifier)
    DigitDetector/  cropped numeric fields       → DJDXDigitsDetector  (per-digit detector)
```

The three models compose: the **result detector** locates ROIs on a full photo;
the **rank classifier** reads each `dj_level_*` crop into `F…AAA`; the **digit
detector** reads every numeric crop digit-by-digit (replacing Apple Vision OCR for
numbers). DJLevels/DigitDetector crops are produced *by* the result-detector export
(`--emit-crops-to-outputs` → `../Outputs/crops/{DJLevels,DigitDetector}/`); you copy
them into the matching `Inputs/` folder and label them in the app's DJ Level /
DigitDetector modes.

## Architecture

A photo of a result screen contains rich, stylised graphics that defeat a
single end-to-end OCR model. Instead, we use a three-stage pipeline:

```
   photo
     │
     ▼
 ┌──────────────────────────┐
 │ 1. Object detector       │   YOLOv9t @1280 → CoreML
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
   │     on glyph ROIs    │   rank: F/E/D/C/B/A/AA/AAA
   │                      │   clear: FAILED/CLEAR/H-CLEAR/EX-HARD/…
   └──────────────────────┘
              ▼
 ┌──────────────────────────┐
 │ 3. Assembly              │   Structured JSON (see schema below)
 └──────────────────────────┘
```

Why split it up?

* The detector only has to *find* boxes, not read them. 22 classes × ~180
  training images is comfortably in YOLO's wheelhouse.
* OCR is solved well by Apple Vision; piggybacking saves us from training
  a digit reader on tiny stylised IIDX fonts. The OCR runs through a tiny
  Swift helper (`scripts/ocr_helper.swift`) that is compiled once and cached
  at `.cache/ocr_helper`, so each image is ~0.2 s instead of a fresh
  `swiftc` compile every call.
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
  "clear_type": { "current": "HARD_CLEAR", "previous_best": "CLEAR" },
  "score":      { "current": 1906, "previous_best": 2031, "delta": -125 },
  "miss_count": { "current": 84,   "previous_best": 79,   "delta": 5 },
  "pacemaker_aa": 2387,
  "judgement": {
    "pgreat": 763, "great": 380, "good": 35, "bad": 24, "poor": 60
  },
  "combo_break": 69
}
```

`dj_level` values come from the rank classifier (`F` … `AAA`); `clear_type`
values from the clear-type classifier (`NO_PLAY`, `FAILED`, `ASSIST_CLEAR`,
`EASY_CLEAR`, `CLEAR`, `HARD_CLEAR`, `EX_HARD_CLEAR`, `FULLCOMBO`). The
authoritative lists live in `schema.yaml`.

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
cd Training
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

Runs Apple Vision OCR (via the cached Swift helper) on every image in
`../Inputs/` and writes `labels/auto_seed.json` — a flat
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

To eyeball labels without opening the labeller, render overlays to
`../Outputs/label_preview/`:

```sh
uv run python scripts/draw_labels.py                       # all labelled images
uv run python scripts/draw_labels.py 235.jpg IMG_0028.jpeg # specific images
uv run python scripts/draw_labels.py --labels labels/auto_seed.json
```

### 3. Build the dataset

```sh
uv run python scripts/prepare_dataset.py --emit-classifier-crops
```

Writes the YOLO-format dataset (train/val/test split, ratios from
`schema.yaml`) to `dataset/` and dumps crops for the rank and clear-type
classifiers under `rank_classifier_data/_unsorted/` and
`clear_type_data/_unsorted/`.

Sort each pile by hand into `train/<CLASS>/` and `val/<CLASS>/` subfolders.
This is the only step that doesn't scale, but it's a one-time task across
the whole image set.

### 4. Train

```sh
uv run python scripts/train_detector.py
uv run python scripts/train_rank_classifier.py --target rank
uv run python scripts/train_rank_classifier.py --target clear_type
```

Each writes to `models/<run-name>/weights/best.pt` (`detector`,
`rank_classifier`, `clear_type_classifier`) and dumps loss curves + a
validation confusion matrix into the same folder. The training device is
auto-selected — `mps` on Apple Silicon, CUDA where present, else CPU —
overridable with `--device`.

### 5. Export to CoreML

```sh
uv run python scripts/export_coreml.py
```

Produces, in `../Outputs/`:

```
../Outputs/
    DJDXResultDetector.mlpackage
    DJDXRankClassifier.mlpackage
    DJDXClearTypeClassifier.mlpackage   (if trained)
```

Pass `--only detector|rank|clear_type` to export a single model, or
`--detector-name <Name>` to override the detector's base filename (used for
the staged/eval variants alongside the Studio app in `../Outputs/`).

Class names are baked into each model's `user_defined_metadata["classes_json"]`,
so the Swift consumer doesn't need a sidecar file.

### 6. Sanity check

```sh
uv run python scripts/inference_test.py ../Inputs/IMG_0028.jpeg
uv run python scripts/inference_test.py ../Inputs/IMG_0028.jpeg --json out.json
```

Prints (or writes, with `--json`) the structured JSON your Swift app should
expect to emit. This script is also the reference implementation — the Swift
pipeline mirrors it 1-for-1 (detector → crop → Vision OCR for text ROIs,
classifier inference for glyph ROIs, assemble).

## Iterating with the detector (active learning)

Once a detector exists, use it to pre-label new photos instead of drawing
from scratch:

```sh
uv run python scripts/predict.py IMG_1081.jpeg IMG_1156.jpeg
uv run python scripts/predict.py --next 5        # next 5 unlabelled images
```

This runs the trained detector and writes `../Outputs/predictions.json` in
the same shape as `labels.json`. Optionally clean it up with heuristics
(drop spurious miss-deltas, fill in missing judge rows from the evenly-spaced
column, re-derive song title/artist boxes from OCR):

```sh
uv run python scripts/autofix.py --all
uv run python scripts/autofix.py IMG_1081.jpeg   # specific images
```

Review the result with `draw_labels.py --labels ../Outputs/predictions.json`,
fold the good boxes into `labels.json` via the labeller, then re-run
steps 3–5. Each new photo funnelled through this loop improves everything.

## Files

| Path | Purpose |
|---|---|
| `schema.yaml` | Single source of truth: class names, hyperparams, splits. Change here, not in scripts. |
| `pyproject.toml` / `.python-version` / `setup.sh` | Python env (managed by `uv`). |
| `uv.lock` | Reproducible dependency lockfile (generated by `uv sync`). |
| `scripts/_common.py` | Shared paths (Inputs/Outputs), schema loading, EXIF-upright image loading, device pick. |
| `scripts/_ocr.py` | Apple Vision OCR wrapper — compiles & caches the Swift helper. |
| `scripts/ocr_helper.swift` | Swift/Vision OCR binary source (compiled to `.cache/ocr_helper`). |
| `scripts/labeler.py` | Offline native bbox labeller (tkinter, no deps). |
| `scripts/draw_labels.py` | Render bbox overlays for visual review → `../Outputs/label_preview/`. |
| `scripts/auto_label.py` | OCR-driven first-pass labelling → `labels/auto_seed.json`. |
| `scripts/predict.py` | Run the trained detector on images → `../Outputs/predictions.json`. |
| `scripts/autofix.py` | Heuristic cleanup of `predictions.json` (judge rows, song boxes, …). |
| `scripts/prepare_dataset.py` | `--target {results,scores}`: labels JSON → YOLO dataset. `--emit-crops-to-outputs` slices DJ-level + numeric crops to `../Outputs/crops/`. |
| `scripts/prepare_djlevel_dataset.py` | `djlevel_labels.json` (per-image rank) → sorted `rank_classifier_data/<split>/<class>/` for the rank trainer. |
| `scripts/train_detector.py` | `--target {results,digits}`: trains the ROI detector or the per-digit digit detector. |
| `scripts/train_rank_classifier.py` | Trains rank / clear-type classifiers. |
| `scripts/export_coreml.py` | `.pt` → `.mlpackage` in `../Outputs/`. `--only detector\|rank\|clear_type\|digits`, with `--{detector,rank,digits}-name` overrides for eval variants. Stamps the AGPL-3.0 license (weights derive from Ultralytics YOLO). |
| `scripts/promote_coreml.py` | Promote a staged `-eval` `.mlpackage` to its production name. `--eval-name`/`--prod-name`; re-stamps the model description (drops the `-eval` suffix) and preserves the license. The Studio "Promote Model" button calls this. |
| `scripts/inference_test.py` | End-to-end pipeline reference (numbers via the digit reader, OCR fallback). |
| `labels/auto_seed.json` | OCR-derived seed labels (written by `auto_label.py`). |
| `labels/labels.json` | Result-detector labels (bbox; the app/labeller writes here). |
| `labels/djlevel_labels.json` | DJ Level labels (`{name: "AAA"}`, one rank per crop). |
| `labels/digit_labels.json` | DigitDetector labels (per-digit bbox over `Inputs/DigitDetector/`). |
| `labels/exclude.json` | Images to skip when building the dataset. |
| `../Inputs/{Results,DJLevels,DigitDetector}/` | Source images, split per training target. |
| `dataset/`, `digit_dataset/` | YOLO datasets for the detector / digit detector (generated). |
| `rank_classifier_data/`, `clear_type_data/` | Classifier crops (generated, then sorted). |
| `models/` | Training runs (weights, plots). |
| `../Outputs/` | Final `.mlpackage` artefacts, `crops/`, prediction/label previews, Studio app. |

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
  through the loop above (predict / auto-label → refine → re-build dataset →
  retrain).
* **Schema changes** (new fields, renamed classes) live in `schema.yaml`.
  Every script picks them up automatically — the labeller too.
* **Underperforming class?** Look at `models/detector/confusion_matrix.png`.
  Usually you just need more examples of that class.
