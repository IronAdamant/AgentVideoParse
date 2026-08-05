#!/usr/bin/env sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
export PYTHONPATH="$ROOT/shared/core:$ROOT"
python3 "$ROOT/shared/core/tests/test_core.py" -v
sh "$ROOT/scripts/check-no-third-party-deps.sh"
