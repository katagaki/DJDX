# DJDX PEAK Studio

Native macOS dev tool for the DJDX PEAK pipeline — labeling, OCR auto-label,
preview/overlay rendering, and output inspection. Swift / SwiftUI / Vision /
Core Graphics, with the Python training scripts reachable as quick-starts.
See [`../SWIFT_DEVTOOL_PLAN.md`](../SWIFT_DEVTOOL_PLAN.md).

## Build & run

```sh
swift run                 # quick dev iteration
./scripts/bundle.sh       # build "DJDX PEAK Studio.app" → .build/dist/
open ".build/dist/DJDX PEAK Studio.app"
```

On first launch, choose the project folder (the directory containing `data/`
and `training/`). It's remembered across launches.

## Smoke test

```sh
swift build -c release
./.build/release/DJDXStudio --selftest /path/to/project
```

Runs the non-UI core (schema parse → image list → OCR → auto-label → label
JSON round-trip) and prints a summary.

## What it does

| Area | Status | Replaces |
|---|---|---|
| Label editor (draw/move/resize, palette, undo, autosave) | done | `labeler.py` |
| Overlay render → JPEG | done | `draw_labels.py` |
| Native Vision OCR auto-label | done | `auto_label.py` + `ocr_helper.swift` |
| Output inspector (labels / predictions.json overlay, preview export) | done | `predict.py` viewing side |
| Live CoreML inference on `.mlpackage` | pending exported models | `inference_test.py` |
| Python quick-starts (prepare / train / export / predict) | done | `uv run` launcher |

Shares `training/labels/labels.json` and `training/schema.yaml` as-is — no new
formats. Supported image formats: `.jpg`, `.jpeg`, `.heic`.
