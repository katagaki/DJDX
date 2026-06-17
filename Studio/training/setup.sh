#!/usr/bin/env bash
# One-shot environment setup for the DJDX PEAK training pipeline.
# Uses uv: provisions Python 3.13, creates .venv/, locks + installs deps.
# Pinned to 3.13 because coremltools 9.0 ships no 3.14 wheel and its native
# blob serializer can't be built from source via pip.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

if ! command -v uv >/dev/null 2>&1; then
  cat >&2 <<'EOF'
uv is not on PATH. Install it with one of:
    brew install uv
    curl -LsSf https://astral.sh/uv/install.sh | sh
EOF
  exit 1
fi

echo "==> uv version: $(uv --version)"
echo "==> Syncing environment (Python $(cat .python-version), core deps)"
uv sync

cat <<'EOF'

Setup complete.

Run commands via uv (no manual activate needed):
    uv run python scripts/auto_label.py
    uv run python scripts/labeler.py
    uv run python scripts/prepare_dataset.py
    uv run python scripts/train_detector.py
    uv run python scripts/train_rank_classifier.py --target rank
    uv run python scripts/export_coreml.py
    uv run python scripts/inference_test.py ../data/IMG_0028.jpeg

Or activate the venv yourself the old-fashioned way:
    source .venv/bin/activate
EOF
