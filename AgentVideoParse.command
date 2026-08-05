#!/bin/bash
# Double-clickable / CLI-runnable macOS launcher for AgentVideoParse.
# macOS opens .command files in Terminal when double-clicked.
set -eu

# Always resolve repo root from this script's location (not cwd).
ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
cd "$ROOT"

exec "$ROOT/bin/macos/run" "$@"
