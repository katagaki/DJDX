# Plan — Swift macOS dev tool (`DJDX PEAK Studio`)

> **Status:** proposal for review. No code written yet.
>
> **Goal:** move the *drawing* and *output-inspection* developer tooling out of
> Python and into a native macOS app, leaning on **Foundation / Core Graphics /
> Vision**. Keep Python only where it genuinely earns its place (PyTorch
> training, CoreML export), reached through thin "quick start" shims the Swift
> app can launch.

---

## 1. Guiding principles

1. **Foundation/Core Graphics first.** Anything that is rendering, image I/O,
   JSON, file watching, or Vision OCR moves to Swift. PIL and tkinter go away.
2. **Python only where it's irreplaceable.** Training (ultralytics/PyTorch) and
   CoreML export (`coremltools`) are Python-native; don't rewrite them. The app
   *orchestrates* them, it doesn't reimplement them.
3. **`labels.json` and `schema.yaml` stay the single source of truth.** Both
   Swift and Python read/write the same files in the same shape — no new
   formats, no migration. This is what lets the two halves coexist.
4. **Nothing already working gets broken.** The Python scripts keep running as-is
   for anyone who prefers the terminal; the app is an additive front-end.

---

## 2. What moves, what stays

| Current script | Disposition | Replacement |
|---|---|---|
| [`labeler.py`](training/scripts/labeler.py) (tkinter editor) | **→ Swift** | SwiftUI canvas + drag gestures |
| [`draw_labels.py`](training/scripts/draw_labels.py) (PIL overlay render) | **→ Swift** | Core Graphics, live overlay + export |
| [`auto_label.py`](training/scripts/auto_label.py) (OCR seeding) | **→ Swift** | native Vision (OCR is *already* Swift) |
| [`ocr_helper.swift`](training/scripts/ocr_helper.swift) + [`_ocr.py`](training/scripts/_ocr.py) | **→ absorbed** | becomes an in-app Vision module; no subprocess |
| `predict.py` / `inference_test.py` on **`.mlpackage`** | **→ Swift** | CoreML + Vision, the production-mirror path |
| `predict.py` / `inference_test.py` on raw **`.pt`** | **stays Python** | launched as a quick-start (needs ultralytics) |
| [`prepare_dataset.py`](training/scripts/prepare_dataset.py) | **stays Python** | quick-start (plumbing; port later if desired) |
| `train_detector.py`, `train_rank_classifier.py` | **stays Python** | quick-start (PyTorch) |
| `export_coreml.py` | **stays Python** | quick-start (`coremltools`) |

**Net Python reduction:** drops PIL (`Pillow`) and tkinter entirely from the
day-to-day labeling/inspection loop. The remaining Python is the train/export
back-end, which the app shells out to.

---

## 3. The "Python quick starts"

The app never reimplements PyTorch. Instead it exposes the Python steps as
buttons/menu commands that shell out to the existing `uv` workflow and stream
output into a log pane:

```
Run ▸ Prepare dataset      → uv run python scripts/prepare_dataset.py --emit-classifier-crops
Run ▸ Train detector       → uv run python scripts/train_detector.py
Run ▸ Export CoreML        → uv run python scripts/export_coreml.py
Run ▸ Predict (.pt) next N → uv run python scripts/predict.py --next N   (raw-weights path)
```

- Implemented with `Process` (Foundation) invoking `uv` in `training/`.
- stdout/stderr piped to an in-app console view; exit code surfaced.
- These are **optional conveniences** — the same commands still work in a plain
  terminal. The app is a launcher, not a dependency.
- Detecting `uv`: resolve from `PATH`, fall back to `~/.local/bin/uv`; if absent,
  show a one-line "install uv" hint rather than failing silently.

---

## 4. App architecture

A SwiftUI macOS app. Proposed location: `studio/` at repo root (sibling to
`training/` and `data/`), built as a SwiftPM package so it compiles from the CLI
with `swift build` — no Xcode required, matching the project's no-IDE ethos —
then **assembled into a `DJDX PEAK Studio.app` bundle** so it runs as a proper
macOS app (see §4.1).

`Package.swift` declares one executable target plus the **`Yams`** dependency
(decision Q1) for reading `schema.yaml`.

```
studio/
  Package.swift             // executable target + Yams dependency
  scripts/bundle.sh         // swift build + assemble the .app (see §4.1)
  Resources/
    Info.plist              // bundle id, display name, LSMinimumSystemVersion
    AppIcon.icns            // optional
  Sources/DJDXStudio/
    App.swift                 // @main, window/scene
    Model/
      Schema.swift            // loads ../training/schema.yaml (class list, etc.)
      Label.swift             // Codable box: cls, x, y, w, h, polygon?, conf?
      LabelStore.swift        // load/save labels.json; same flat shape, atomic writes
    Vision/
      OCR.swift               // VNRecognizeTextRequest — ports ocr_helper.swift
      AutoLabel.swift         // OCR → seed boxes (ports auto_label.py heuristics)
      CoreMLPipeline.swift    // detector + classifiers on .mlpackage → result JSON
    Render/
      BoxOverlay.swift        // Core Graphics box + tag drawing (ports draw_labels.py)
      PreviewExport.swift     // write annotated JPEGs to output/label_preview/
    UI/
      LabelEditorView.swift   // canvas, drag-to-draw, resize handles, undo
      ClassPaletteView.swift  // class list + hotkeys 1–9,0 + arm/assign
      ImageListView.swift     // filenames + label counts, ←/→ nav
      OutputInspectorView.swift // run inference, show JSON + overlay side by side
      PythonRunnerView.swift  // quick-start buttons + streamed console
```

### Shared contracts (no new formats)
- **`training/labels/labels.json`** — `{image_name: [{cls,x,y,w,h}, …]}`,
  coords normalised `[0,1]`. Swift `Codable` mirrors this exactly; the Python
  `prepare_dataset.py` keeps reading it untouched.
- **`training/schema.yaml`** — class names + hyperparams. Swift reads it so the
  class palette stays in sync, parsed with `Yams` (decision Q1).
- **`training/output/predictions.json`** — same shape as `labels.json` plus a
  `conf` field; the inspector can render either Python- or Swift-produced files.

### 4.1 Packaging into `DJDX PEAK Studio.app` (decision Q3)

A bare SwiftPM executable can't reliably host a SwiftUI app (no `Info.plist`
means flaky window activation, menu bar, and file-open panels). So the build
produces a real bundle. We stay on SwiftPM (no Xcode project) and add a thin
`scripts/bundle.sh` that assembles the standard layout:

```
DJDX PEAK Studio.app/
  Contents/
    Info.plist              // from Resources/Info.plist
    MacOS/DJDXStudio        // the `swift build -c release` binary, copied in
    Resources/AppIcon.icns  // optional
```

- `bundle.sh` = `swift build -c release` → `mkdir` the bundle tree → copy binary
  + `Info.plist` → optional ad-hoc `codesign --sign -` so Gatekeeper lets it run
  locally. One command, CLI-only, no Xcode.
- `Info.plist` sets `CFBundleIdentifier`, `CFBundleName` = "DJDX PEAK Studio",
  `LSMinimumSystemVersion`, and `NSHighResolutionCapable`.
- **Not sandboxed.** As a local dev tool it needs free read/write to
  `../training/` and `../data/`; App Sandbox would force file-access prompts for
  no benefit. (If we ever notarize/distribute, revisit — out of scope here.)
- Result is a double-clickable `.app`; `swift run` still works for quick
  inner-loop iteration during development.

---

## 5. Feature parity checklist (labeler)

Porting [`labeler.py`](training/scripts/labeler.py) — every behaviour to preserve:

- [ ] Image list with live label counts; `↑/↓`/click to switch; `←/→` nav
- [ ] Click-drag empty area → new box in the armed class
- [ ] Click box to select; drag body to move; drag corner handle to resize
- [ ] Class palette: click to arm or assign-to-selection; colors match
      `CLASS_COLORS`
- [ ] Hotkeys `1`–`9`,`0` for first ten classes; `/` cycles selected box's class
- [ ] `Delete`/`Backspace` removes selection
- [ ] Per-image undo stack (`Cmd+Z`), depth-capped
- [ ] Autosave on navigation; explicit `Cmd+S`
- [ ] Loads `labels.json`, falls back to `auto_seed.json`, else empty
- [ ] Letterbox scaling + canvas↔normalized coord transforms
- [ ] Renders `polygon` boxes too (draw_labels supports skewed quads)

UX upgrades native macOS makes cheap (nice-to-have, not required for parity):
zoom/pan, retina-crisp rendering, multi-select, drag-reorder.

---

## 6. Phased delivery

**Phase 0 — scaffold.** `studio/` SwiftPM package (with `Yams`), `Info.plist` +
`bundle.sh` producing `DJDX PEAK Studio.app`, app window, `Schema` +
`LabelStore` loading the real `labels.json`/`schema.yaml`. Read-only image list
over `data/`, filtered to the supported formats (decision Q4): **`.jpg`,
`.jpeg`, `.heic`** — the common iPhone-photo formats — loaded via ImageIO
(`CGImageSource`), which decodes HEIC natively on macOS.

**Phase 1 — drawing (highest value, lowest risk).**
Core Graphics `BoxOverlay` + the full `LabelEditorView`. At end of phase the
Swift editor can replace `labeler.py` for daily use. `PreviewExport` replaces
`draw_labels.py`.

**Phase 2 — native Vision.** Port `ocr_helper.swift`/`_ocr.py` into `OCR.swift`
and build `AutoLabel.swift`, replacing `auto_label.py`. PIL + the OCR subprocess
dance are gone from the loop.

**Phase 3 — output inspector.** `CoreMLPipeline` runs the exported `.mlpackage`
models (detector → crop → OCR → classifier → JSON), shown beside the overlay —
the Swift mirror of `inference_test.py`. Inspector can also load a Python
`predictions.json` for the raw-`.pt` path.

**Phase 4 — Python quick-starts.** `PythonRunnerView` wires up the prepare /
train / export / predict-`.pt` buttons via `Process`.

Phases 1–2 alone already deliver the "lean on Foundation, drop PIL/tkinter" win;
3–4 are about consolidation and convenience.

---

## 7. Decisions (resolved)

- **Q1 — YAML → use `Yams`.** Add the pure-Swift `Yams` SwiftPM dependency and
  read `schema.yaml` directly. `schema.yaml` stays the single source of truth;
  no `schema.json` side-file.
- **Q2 — `.pt` inference → keep it Python.** The app never runs raw `.pt`
  weights; that path stays in `predict.py`/`inference_test.py`, preserving the
  fast train→inspect loop. The app does native inference only on exported
  `.mlpackage` (Phase 3), and can also load Python-produced `predictions.json`.
- **Q3 — packaging → ship a `.app`.** Build with SwiftPM, then assemble
  `DJDX PEAK Studio.app` via `scripts/bundle.sh` (details in §4.1). No Xcode
  project; not sandboxed.
- **Q4 — formats → `.jpg`, `.jpeg`, `.heic`.** The common iPhone-photo formats,
  decoded via ImageIO/`CGImageSource` (native HEIC support on macOS). Other
  formats in `data/` are ignored by the image list.

---

## 8. Explicitly out of scope

- The production iOS/macOS consumer app (separate effort; this is a dev tool).
- Rewriting training or CoreML export in Swift.
- Changing the model architecture, schema, or `labels.json` format.
