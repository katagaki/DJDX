"""Apple Vision OCR wrapper.

Compiles training/scripts/ocr_helper.swift once into
training/.cache/ocr_helper and reuses it for every image — turns
~30 s/image (swift re-compile each time) into ~0.2 s/image (binary
launch + Vision inference).
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

from _common import TRAINING_DIR

_HELPER_SRC = TRAINING_DIR / "scripts" / "ocr_helper.swift"
_HELPER_BIN = TRAINING_DIR / ".cache" / "ocr_helper"


def _ensure_built() -> Path:
    if _HELPER_BIN.exists() and _HELPER_BIN.stat().st_mtime >= _HELPER_SRC.stat().st_mtime:
        return _HELPER_BIN
    _HELPER_BIN.parent.mkdir(parents=True, exist_ok=True)
    print(f"compiling {_HELPER_SRC.name} → {_HELPER_BIN}", file=sys.stderr)
    swiftc = shutil.which("swiftc") or "/usr/bin/swiftc"
    res = subprocess.run(
        [swiftc, "-O", str(_HELPER_SRC), "-o", str(_HELPER_BIN)],
        capture_output=True, text=True, check=False,
    )
    if res.returncode != 0:
        sys.stderr.write(res.stderr)
        raise SystemExit(f"swiftc failed (rc={res.returncode})")
    return _HELPER_BIN


def _parse_line(line: str) -> dict | None:
    """Each line from the helper is one JSON object, possibly followed by
    stdout-leak warning text from the TextRecognition framework. Use
    raw_decode to consume just the JSON value."""
    try:
        obj, _end = json.JSONDecoder().raw_decode(line.lstrip())
    except json.JSONDecodeError:
        return None
    return obj


def ocr_images(paths: list[Path]) -> dict[Path, list[dict]]:
    """Batch OCR. Returns {Path: [region_dict, ...]} for each input path.
    Single subprocess call regardless of how many paths are passed."""
    if not paths:
        return {}
    helper = _ensure_built()
    res = subprocess.run(
        [str(helper), *[str(p) for p in paths]],
        capture_output=True, text=True, check=False,
    )
    if res.returncode != 0:
        sys.stderr.write(f"ocr_helper failed (rc={res.returncode}): {res.stderr}\n")
        return {p: [] for p in paths}

    by_path: dict[str, list[dict]] = {}
    for raw_line in res.stdout.splitlines():
        if not raw_line.strip():
            continue
        obj = _parse_line(raw_line)
        if obj is None or "path" not in obj:
            continue
        by_path[obj["path"]] = obj.get("regions", [])
    return {p: by_path.get(str(p), []) for p in paths}


def ocr_image(path: Path) -> list[dict]:
    return ocr_images([path]).get(path, [])
