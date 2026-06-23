"""
Offline, native bbox labeller for the DJDX PEAK pipeline.

Replaces Label Studio with a self-contained tkinter window — no web server,
no extra dependencies (tkinter ships with Python). Reads the same JSON
format ``prepare_dataset.py`` expects, so it slots into the existing flow:

    uv run python scripts/auto_label.py        # OCR seeds bboxes
    uv run python scripts/labeler.py           # human refines, saves
    uv run python scripts/prepare_dataset.py   # → YOLO dataset

On launch it loads, in priority order:
    labels/labels.json       (your work in progress)
    labels/auto_seed.json    (OCR seeds from auto_label.py)
    (nothing — start from scratch)

Saving always writes ``labels/labels.json`` in the flat shape:

    {"235.jpg": [{"cls": "score_now", "x": 0.21, "y": 0.49, ...}, ...]}

UI:
  Left   — image list (filename + label count); ↑/↓ or click to switch.
  Center — image with bbox overlay; click-drag empty area to draw a new box,
           click an existing box to select it, drag handles to resize,
           drag body to move, Delete to remove.
  Right  — class palette; click a class to assign to selection (or arm it
           for the next drawn box). Number keys 1–9, 0 select the first
           ten classes; / cycles class for the selected box.
Keyboard:
  ← / →   prev / next image
  Delete  remove selected box
  Cmd+S   save (autosave also runs on every navigation)
  Cmd+Z   undo last edit on current image
"""
from __future__ import annotations

import json
import sys
import tkinter as tk
from pathlib import Path

import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent.parent))  # Training/scripts: shared _common/_ocr
from _common import AUTO_SEED_FILE, DATA_DIR, LABELS_FILE, iter_images, load_schema
from PIL import Image, ImageTk

# Per-class outline colours for the bbox overlay (one stable colour per class).
CLASS_COLORS = {
    "dj_level_now":      "#ff595e",
    "dj_level_prev":     "#ff924c",
    "clear_type_now":    "#ffca3a",
    "clear_type_prev":   "#c5ca30",
    "score_now":         "#8ac926",
    "score_prev":        "#52a675",
    "score_delta":       "#1982c4",
    "miss_count_now":    "#4267ac",
    "miss_count_prev":   "#565aa0",
    "miss_count_delta":  "#6a4c93",
    "pacemaker_aa":      "#b5179e",
    "judge_pgreat":      "#7209b7",
    "judge_great":       "#560bad",
    "judge_good":        "#480ca8",
    "judge_bad":         "#3a0ca3",
    "judge_poor":        "#3f37c9",
    "song_title":        "#4361ee",
    "song_artist":       "#4895ef",
    "difficulty_label":  "#4cc9f0",
    "notes_count":       "#80ed99",
    "stage_label":       "#fee440",
    "combo_break":       "#ff70a6",
    "unlabeled_text":    "#999999",
}

# Handle = small grab square at each box corner, in screen pixels.
HANDLE = 6
# Minimum drag distance (screen px) to count as "drew a new box" vs a click.
MIN_DRAG = 4


def color_for(cls: str) -> str:
    return CLASS_COLORS.get(cls, "#cccccc")


# ---------------------------------------------------------------------------
# I/O — labels kept as {image_name: [{cls, x, y, w, h}, ...]} with coords
# normalised to [0, 1]. One flat JSON file on disk; same shape in-memory.
# ---------------------------------------------------------------------------
def load_existing_labels() -> dict[str, list[dict]]:
    for path in (LABELS_FILE, AUTO_SEED_FILE):
        if path.exists():
            return json.loads(path.read_text())
    return {}


def save_labels(labels: dict[str, list[dict]]) -> None:
    LABELS_FILE.parent.mkdir(parents=True, exist_ok=True)
    LABELS_FILE.write_text(json.dumps(labels, indent=2))


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
class Labeler(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("DJDX PEAK Labeler")
        self.geometry("1400x900")

        self.schema = load_schema()
        self.classes: list[str] = [*self.schema["detector"]["classes"], "unlabeled_text"]
        self.images: list[Path] = list(iter_images(DATA_DIR))
        if not self.images:
            raise SystemExit(f"no images in {DATA_DIR}")
        self.labels: dict[str, list[dict]] = load_existing_labels()
        # Ensure every image has an entry so navigation doesn't KeyError.
        for img in self.images:
            self.labels.setdefault(img.name, [])

        self.current_idx: int = 0
        self.current_class: str | None = self.classes[0]
        self.selected_box: int | None = None
        self.undo_stack: dict[str, list[list[dict]]] = {}

        # canvas → image transform (set per-frame in render_image)
        self.tk_image: ImageTk.PhotoImage | None = None
        self.scale: float = 1.0
        self.offset: tuple[int, int] = (0, 0)
        self.disp_size: tuple[int, int] = (1, 1)

        # drag state
        self.drag_mode: str | None = None   # "new" | "move" | "resize-<corner>"
        self.drag_start: tuple[float, float] | None = None
        self.drag_origin_box: dict | None = None

        self._build_ui()
        self._bind_keys()
        self.show(0)

    # ---------------- UI construction ---------------------------------------
    def _build_ui(self) -> None:
        outer = tk.PanedWindow(self, orient="horizontal", sashwidth=4)
        outer.pack(fill="both", expand=True)

        # left: image list
        left = tk.Frame(outer, width=240)
        outer.add(left, minsize=200)
        tk.Label(left, text="Images", anchor="w").pack(fill="x")
        self.list_var = tk.StringVar(value=self._list_entries())
        self.listbox = tk.Listbox(left, listvariable=self.list_var, exportselection=False)
        self.listbox.pack(fill="both", expand=True)
        self.listbox.bind("<<ListboxSelect>>", self._on_list_select)

        # center: image canvas
        center = tk.Frame(outer)
        outer.add(center, minsize=600)
        self.canvas = tk.Canvas(center, bg="#222")
        self.canvas.pack(fill="both", expand=True)
        self.canvas.bind("<Configure>", lambda _e: self._rerender())
        self.canvas.bind("<ButtonPress-1>", self._on_press)
        self.canvas.bind("<B1-Motion>", self._on_drag)
        self.canvas.bind("<ButtonRelease-1>", self._on_release)

        # right: class palette
        right = tk.Frame(outer, width=220)
        outer.add(right, minsize=180)
        tk.Label(right, text="Classes  (click to arm / assign)", anchor="w").pack(fill="x")
        self.cls_buttons: dict[str, tk.Button] = {}
        for i, cls in enumerate(self.classes):
            hotkey = f"{(i + 1) % 10}" if i < 10 else " "
            b = tk.Button(
                right,
                text=f"{hotkey}  {cls}",
                anchor="w",
                bg=color_for(cls),
                fg="#000",
                activebackground=color_for(cls),
                command=lambda c=cls: self.set_class(c),
            )
            b.pack(fill="x", padx=2, pady=1)
            self.cls_buttons[cls] = b
        self._highlight_class()

        # bottom status bar
        self.status = tk.StringVar()
        tk.Label(self, textvariable=self.status, anchor="w").pack(fill="x", side="bottom")

    def _bind_keys(self) -> None:
        self.bind("<Left>",       lambda _e: self.show(self.current_idx - 1))
        self.bind("<Right>",      lambda _e: self.show(self.current_idx + 1))
        self.bind("<Delete>",     lambda _e: self.delete_selected())
        self.bind("<BackSpace>",  lambda _e: self.delete_selected())
        self.bind("<Command-s>",  lambda _e: self.save())
        self.bind("<Control-s>",  lambda _e: self.save())
        self.bind("<Command-z>",  lambda _e: self.undo())
        self.bind("<Control-z>",  lambda _e: self.undo())
        self.bind("/",            lambda _e: self.cycle_selected_class())
        for i in range(10):
            self.bind(str(i), lambda _e, k=i: self._hotkey_class(k))

    # ---------------- helpers ----------------------------------------------
    def _list_entries(self) -> list[str]:
        return [f"{img.name}  ({len(self.labels.get(img.name, []))})" for img in self.images]

    def _refresh_list(self) -> None:
        self.list_var.set(self._list_entries())
        self.listbox.selection_clear(0, "end")
        self.listbox.selection_set(self.current_idx)
        self.listbox.see(self.current_idx)

    def _highlight_class(self) -> None:
        for cls, btn in self.cls_buttons.items():
            btn.config(relief="sunken" if cls == self.current_class else "raised")

    def _hotkey_class(self, k: int) -> None:
        # 1..9, 0 → classes[0..9]
        idx = (k - 1) % 10
        if idx < len(self.classes):
            self.set_class(self.classes[idx])

    def _current_image(self) -> Path:
        return self.images[self.current_idx]

    def _current_boxes(self) -> list[dict]:
        return self.labels[self._current_image().name]

    def _push_undo(self) -> None:
        name = self._current_image().name
        snap = json.loads(json.dumps(self._current_boxes()))   # deep copy of plain dicts
        self.undo_stack.setdefault(name, []).append(snap)
        # cap depth
        self.undo_stack[name] = self.undo_stack[name][-30:]

    def _set_status(self, msg: str = "") -> None:
        n = len(self._current_boxes())
        self.status.set(
            f"[{self.current_idx + 1}/{len(self.images)}] {self._current_image().name}   "
            f"{n} box{'es' if n != 1 else ''}   class={self.current_class}   {msg}"
        )

    # ---------------- coord transforms -------------------------------------
    def _canvas_to_norm(self, cx: float, cy: float) -> tuple[float, float]:
        ox, oy = self.offset
        dw, dh = self.disp_size
        x = (cx - ox) / dw
        y = (cy - oy) / dh
        return max(0.0, min(1.0, x)), max(0.0, min(1.0, y))

    def _norm_to_canvas(self, nx: float, ny: float) -> tuple[float, float]:
        ox, oy = self.offset
        dw, dh = self.disp_size
        return ox + nx * dw, oy + ny * dh

    # ---------------- navigation / render ----------------------------------
    def show(self, idx: int) -> None:
        if not (0 <= idx < len(self.images)):
            return
        self.save(quiet=True)
        self.current_idx = idx
        self.selected_box = None
        self._refresh_list()
        self._rerender()

    def _on_list_select(self, _event: object) -> None:
        sel = self.listbox.curselection()
        if sel:
            self.show(sel[0])

    def _rerender(self) -> None:
        self.canvas.delete("all")
        cw = max(self.canvas.winfo_width(), 1)
        ch = max(self.canvas.winfo_height(), 1)
        try:
            im = Image.open(self._current_image()).convert("RGB")
        except (OSError, ValueError) as e:
            self.canvas.create_text(cw // 2, ch // 2, fill="white",
                                    text=f"load error: {e}")
            return
        iw, ih = im.size
        self.scale = min(cw / iw, ch / ih)
        dw, dh = max(int(iw * self.scale), 1), max(int(ih * self.scale), 1)
        if dw < 8 or dh < 8:
            # Canvas hasn't been laid out yet; try again after Tk settles.
            self.after(50, self._rerender)
            return
        ox, oy = (cw - dw) // 2, (ch - dh) // 2
        self.disp_size = (dw, dh)
        self.offset = (ox, oy)
        self.tk_image = ImageTk.PhotoImage(im.resize((dw, dh), Image.LANCZOS))
        self.canvas.create_image(ox, oy, anchor="nw", image=self.tk_image)

        for i, b in enumerate(self._current_boxes()):
            self._draw_box(i, b, selected=(i == self.selected_box))

        self._set_status()

    def _draw_box(self, idx: int, b: dict, *, selected: bool) -> None:
        x1, y1 = self._norm_to_canvas(b["x"], b["y"])
        x2, y2 = self._norm_to_canvas(b["x"] + b["w"], b["y"] + b["h"])
        color = color_for(b["cls"])
        width = 3 if selected else 2
        self.canvas.create_rectangle(x1, y1, x2, y2, outline=color, width=width)
        # tag-on label
        self.canvas.create_text(
            x1 + 4, y1 + 8, anchor="w", text=b["cls"],
            fill=color, font=("Menlo", 10, "bold" if selected else "normal"),
        )
        if selected:
            for hx, hy in ((x1, y1), (x2, y1), (x1, y2), (x2, y2)):
                self.canvas.create_rectangle(
                    hx - HANDLE, hy - HANDLE, hx + HANDLE, hy + HANDLE,
                    outline=color, fill="#fff",
                )

    # ---------------- mouse interactions -----------------------------------
    def _hit_test(self, cx: float, cy: float) -> tuple[int | None, str | None]:
        """Return (box_index, hit_kind) where hit_kind is 'nw'|'ne'|'sw'|'se'|'body' or None."""
        for i, b in reversed(list(enumerate(self._current_boxes()))):
            x1, y1 = self._norm_to_canvas(b["x"], b["y"])
            x2, y2 = self._norm_to_canvas(b["x"] + b["w"], b["y"] + b["h"])
            for corner, (hx, hy) in (("nw", (x1, y1)), ("ne", (x2, y1)),
                                     ("sw", (x1, y2)), ("se", (x2, y2))):
                if abs(cx - hx) <= HANDLE and abs(cy - hy) <= HANDLE:
                    return i, corner
            if x1 <= cx <= x2 and y1 <= cy <= y2:
                return i, "body"
        return None, None

    def _on_press(self, event: tk.Event) -> None:
        idx, hit = self._hit_test(event.x, event.y)
        self.drag_start = (event.x, event.y)
        if idx is not None:
            self.selected_box = idx
            self.drag_origin_box = dict(self._current_boxes()[idx])
            self.drag_mode = f"resize-{hit}" if hit and hit != "body" else "move"
        else:
            self.selected_box = None
            self.drag_mode = "new"
        self._rerender()

    def _on_drag(self, event: tk.Event) -> None:
        if self.drag_start is None or self.drag_mode is None:
            return
        sx, sy = self.drag_start
        if self.drag_mode == "new":
            if abs(event.x - sx) < MIN_DRAG and abs(event.y - sy) < MIN_DRAG:
                return
            self.canvas.delete("preview")
            self.canvas.create_rectangle(sx, sy, event.x, event.y, outline="#fff",
                                          dash=(3, 2), tag="preview")
            return
        box = self._current_boxes()[self.selected_box]   # type: ignore[index]
        orig = self.drag_origin_box or box
        if self.drag_mode == "move":
            dx = (event.x - sx) / self.disp_size[0]
            dy = (event.y - sy) / self.disp_size[1]
            box["x"] = max(0.0, min(1.0 - orig["w"], orig["x"] + dx))
            box["y"] = max(0.0, min(1.0 - orig["h"], orig["y"] + dy))
        else:  # resize-<corner>
            corner = self.drag_mode.split("-")[1]
            nx, ny = self._canvas_to_norm(event.x, event.y)
            x1, y1 = orig["x"], orig["y"]
            x2, y2 = orig["x"] + orig["w"], orig["y"] + orig["h"]
            if "w" in corner:
                x1 = nx
            if "e" in corner:
                x2 = nx
            if "n" in corner:
                y1 = ny
            if "s" in corner:
                y2 = ny
            box["x"], box["y"] = min(x1, x2), min(y1, y2)
            box["w"], box["h"] = abs(x2 - x1), abs(y2 - y1)
        self._rerender()

    def _on_release(self, event: tk.Event) -> None:
        if self.drag_mode == "new" and self.drag_start is not None:
            sx, sy = self.drag_start
            if abs(event.x - sx) >= MIN_DRAG and abs(event.y - sy) >= MIN_DRAG:
                self._push_undo()
                x1, y1 = self._canvas_to_norm(min(sx, event.x), min(sy, event.y))
                x2, y2 = self._canvas_to_norm(max(sx, event.x), max(sy, event.y))
                cls = self.current_class or "unlabeled_text"
                self._current_boxes().append({
                    "cls": cls, "x": x1, "y": y1, "w": x2 - x1, "h": y2 - y1,
                })
                self.selected_box = len(self._current_boxes()) - 1
        elif self.drag_mode in ("move",) or (self.drag_mode and self.drag_mode.startswith("resize")):
            self._push_undo()
        self.drag_mode = None
        self.drag_start = None
        self.drag_origin_box = None
        self.canvas.delete("preview")
        self._refresh_list()
        self._rerender()

    # ---------------- actions ----------------------------------------------
    def set_class(self, cls: str) -> None:
        self.current_class = cls
        self._highlight_class()
        if self.selected_box is not None:
            self._push_undo()
            self._current_boxes()[self.selected_box]["cls"] = cls
        self._rerender()

    def cycle_selected_class(self) -> None:
        if self.selected_box is None:
            return
        box = self._current_boxes()[self.selected_box]
        i = self.classes.index(box["cls"]) if box["cls"] in self.classes else -1
        self._push_undo()
        box["cls"] = self.classes[(i + 1) % len(self.classes)]
        self._rerender()

    def delete_selected(self) -> None:
        if self.selected_box is None:
            return
        self._push_undo()
        del self._current_boxes()[self.selected_box]
        self.selected_box = None
        self._refresh_list()
        self._rerender()

    def undo(self) -> None:
        stack = self.undo_stack.get(self._current_image().name)
        if not stack:
            self._set_status("nothing to undo")
            return
        self.labels[self._current_image().name] = stack.pop()
        self.selected_box = None
        self._refresh_list()
        self._rerender()

    def save(self, *, quiet: bool = False) -> None:
        save_labels(self.labels)
        if not quiet:
            self._set_status(f"saved → {LABELS_FILE.name}")


def main() -> None:
    try:
        app = Labeler()
    except SystemExit:
        raise
    except Exception as e:   # noqa: BLE001
        print(f"failed to start labeler: {e}", file=sys.stderr)
        sys.exit(1)
    app.mainloop()


if __name__ == "__main__":
    main()
