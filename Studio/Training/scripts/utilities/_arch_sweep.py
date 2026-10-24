"""Sequentially train + eval a list of detector architectures on the current
dataset (1280) and log dj_level_now AP50, for an apples-to-apples comparison.
Runs unattended; appends one JSON line per model to the log.
"""
from __future__ import annotations
import json, subprocess, sys
from pathlib import Path

UTIL_DIR = Path(__file__).resolve().parent          # Training/scripts/utilities (this, eval_detector)
SCRIPTS = UTIL_DIR.parent                            # Training/scripts (train_detector)
TRAINING = SCRIPTS.parent                            # Training (subprocess cwd)
MODELS_DIR = TRAINING.parent / "Outputs" / "models"  # generated models live under Outputs/
LOG = Path("/tmp/arch_sweep.jsonl")

# (pretrained weights, run name under models/, batch)
MODELS = [
    ("yolov10n.pt", "detector10", 4),   # end2end / NMS-free head
    ("yolo11n.pt",  "detector11", 8),   # standard head
]

def run(cmd):
    print(f"\n$ {' '.join(cmd)}", flush=True)
    r = subprocess.run(cmd, cwd=TRAINING, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stdout[-2500:]); print(r.stderr[-2500:], file=sys.stderr)
    return r

def eval_model(name, tag):
    r = run([sys.executable, str(UTIL_DIR / "eval_detector.py"),
             "--model", str(MODELS_DIR / name / "weights" / "best.pt"), "--imgsz", "1280", "--tag", tag])
    for line in r.stdout.splitlines():
        if line.startswith("EVAL_JSON "):
            return json.loads(line[len("EVAL_JSON "):])
    return None

def main():
    for weights, name, batch in MODELS:
        print(f"\n===== {weights} -> models/{name} (batch {batch}) =====", flush=True)
        import shutil
        shutil.rmtree(MODELS_DIR / name, ignore_errors=True)
        tr = run([sys.executable, str(SCRIPTS / "train_detector.py"), "--target", "results",
                  "--weights", weights, "--name", name, "--imgsz", "1280",
                  "--patience", "40", "--epochs", "200", "--batch", str(batch)])
        rec = {"weights": weights, "name": name, "batch": batch,
               "trained_ok": tr.returncode == 0}
        if tr.returncode == 0:
            m = eval_model(name, name)
            if m:
                rec.update({"map50": m["map50"],
                            "dj_level_now": m.get("dj_level_now"),
                            "dj_level_prev": m.get("dj_level_prev")})
        with LOG.open("a") as f:
            f.write(json.dumps(rec) + "\n")
        djn = (rec.get("dj_level_now") or {})
        print(f"[SWEEP DONE] {name}: trained_ok={rec['trained_ok']} "
              f"mAP50={rec.get('map50')} dj_level_now AP50={djn.get('ap50')}", flush=True)
    print("\nARCH SWEEP COMPLETE", flush=True)

if __name__ == "__main__":
    main()
