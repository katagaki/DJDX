"""
Promote a staged evaluation .mlpackage to its production slot in ../Outputs/.

Re-saves <eval>.mlpackage as <prod>.mlpackage with the CoreML description
(MLModelDescriptionKey) rewritten so the production model card no longer
carries the "-eval" staging suffix. The AGPL-3.0 license, author, and class
metadata stamped at export time are preserved. The eval package is left in
place for further iteration.

    uv run python scripts/promote_coreml.py --eval-name X-eval --prod-name X
"""
from __future__ import annotations

import argparse
import shutil
from pathlib import Path

import coremltools as ct
from _common import OUTPUT_DIR


def promote(eval_name: str, prod_name: str) -> Path:
    src = OUTPUT_DIR / f"{eval_name}.mlpackage"
    if not src.exists():
        raise SystemExit(f"missing evaluation model: {src}")

    mlmodel = ct.models.MLModel(str(src))
    # Strip the staging suffix from the embedded description so the production
    # model advertises itself as production, not an eval build.
    desc = mlmodel.short_description or ""
    mlmodel.short_description = desc.replace(eval_name, prod_name)

    dst = OUTPUT_DIR / f"{prod_name}.mlpackage"
    if dst.exists():
        shutil.rmtree(dst)
    mlmodel.save(str(dst))
    print(f"Promoted {src.name} → {dst.name}")
    return dst


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--eval-name", required=True,
                    help="eval .mlpackage base name, e.g. DJDXResultDetector-eval")
    ap.add_argument("--prod-name", required=True,
                    help="production .mlpackage base name, e.g. DJDXResultDetector")
    args = ap.parse_args()
    promote(args.eval_name, args.prod_name)


if __name__ == "__main__":
    main()
