"""Drive the dj_level_now relabeling loop with the user's eval/train cadence.

Starting from a pristine copy of labels.json (big-glyph dj_level_now), apply the
score-table relabel proposals cumulatively in sorted-name order. At each
checkpoint rebuild the dataset and evaluate; at build checkpoints retrain the
detector first. Every checkpoint's metrics are appended to a JSONL log.

  uv run python scripts/relabel_eval_loop.py \
      --proposals /tmp/djnow_final.json --base /tmp/labels.backup.json \
      --log /tmp/loop_metrics.jsonl [--dry] [--resume]

Cadence (applied-count → action): eval every 20, build (fresh train) every 50.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent.parent))  # Training/scripts: shared _common/_ocr
from _common import LABELS_FILE

UTIL_DIR = Path(__file__).resolve().parent   # Training/scripts/utilities (this script, eval_detector)
SCRIPTS = UTIL_DIR.parent                     # Training/scripts (prepare_dataset, train_detector)
TRAINING = SCRIPTS.parent                     # Training (subprocess cwd)

# (applied_count, build?) — eval at every 20; build at every 50 + final.
CHECKPOINTS = [
    (20, False), (40, False), (50, True), (60, False), (80, False),
    (100, True), (120, False), (140, False), (150, True), (160, False),
    (176, True),
]


def run(cmd: list[str]) -> str:
    print(f"\n$ {' '.join(cmd)}", flush=True)
    r = subprocess.run(cmd, cwd=TRAINING, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stdout[-3000:])
        print(r.stderr[-3000:], file=sys.stderr)
        raise SystemExit(f"command failed: {' '.join(cmd)}")
    return r.stdout


def apply_first_n(base: dict, proposals: dict, order: list[str], n: int) -> dict:
    """Original labels with the first n proposals' dj_level_now replaced.
    Preserves base key order so the seed-1729 dataset split is invariant."""
    chosen = set(order[:n])
    out = {}
    for name, boxes in base.items():
        if name in chosen and name in proposals:
            kept = [b for b in boxes if b["cls"] != "dj_level_now"]
            kept.append(dict(proposals[name]))
            out[name] = kept
        else:
            out[name] = boxes
    return out


def eval_now(tag: str) -> dict:
    out = run([sys.executable, str(UTIL_DIR / "eval_detector.py"), "--tag", tag])
    for line in out.splitlines():
        if line.startswith("EVAL_JSON "):
            return json.loads(line[len("EVAL_JSON "):])
    raise SystemExit("no EVAL_JSON in eval output")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--proposals", required=True)
    ap.add_argument("--base", required=True, help="pristine labels.json copy")
    ap.add_argument("--log", default="/tmp/loop_metrics.jsonl")
    ap.add_argument("--dry", action="store_true", help="skip training (builds become eval-only)")
    ap.add_argument("--resume", action="store_true")
    ap.add_argument("--only-first", type=int, default=None, help="run only the first K checkpoints (testing)")
    args = ap.parse_args()

    base = json.loads(Path(args.base).read_text())
    proposals = json.loads(Path(args.proposals).read_text())
    order = sorted(n for n in base if n in proposals)
    print(f"base images: {len(base)}; proposals: {len(proposals)}; ordered targets: {len(order)}")

    logp = Path(args.log)
    done = set()
    if args.resume and logp.exists():
        for line in logp.read_text().splitlines():
            try:
                done.add(json.loads(line)["applied"])
            except Exception:
                pass
        print(f"resume: {sorted(done)} already logged")
    elif not args.resume:
        logp.write_text("")

    checkpoints = CHECKPOINTS[: args.only_first] if args.only_first else CHECKPOINTS

    for n, build in checkpoints:
        if n in done:
            print(f"skip checkpoint {n} (already done)")
            continue
        n = min(n, len(order)) if n == 176 else n
        print(f"\n===== checkpoint applied={n}  build={build and not args.dry} =====", flush=True)
        labels = apply_first_n(base, proposals, order, n)
        LABELS_FILE.write_text(json.dumps(labels, indent=2))
        run([sys.executable, str(SCRIPTS / "prepare_dataset.py"), "--target", "results"])
        did_build = False
        if build and not args.dry:
            run([sys.executable, str(SCRIPTS / "train_detector.py"), "--target", "results"])
            did_build = True
        metrics = eval_now(f"applied{n}{'_built' if did_build else ''}")
        rec = {
            "applied": n, "built": did_build,
            "map50": metrics["map50"], "map50_95": metrics["map50_95"],
            "dj_level_now": metrics.get("dj_level_now"),
            "dj_level_prev": metrics.get("dj_level_prev"),
        }
        with logp.open("a") as f:
            f.write(json.dumps(rec) + "\n")
        djn = rec["dj_level_now"] or {}
        print(f"[CHECKPOINT {n}] built={did_build} mAP50={rec['map50']} "
              f"dj_level_now AP50={djn.get('ap50')} P={djn.get('p')} R={djn.get('r')}", flush=True)

    print("\nLOOP COMPLETE", flush=True)


if __name__ == "__main__":
    main()
