#!/usr/bin/env sh
# Portable GUI (tkinter) — works on macOS/Windows/Linux with Python 3 + tkinter.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
export PYTHONPATH="$ROOT/shared/core:$ROOT${PYTHONPATH:+:$PYTHONPATH}"
exec python3 "$ROOT/ui/linux/app.py"
