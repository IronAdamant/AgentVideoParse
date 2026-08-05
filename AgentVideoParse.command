#!/bin/bash
# Double-clickable macOS launcher (opens in Terminal).
# Keeps the window open if something goes wrong so you can read the message.
set -u

ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
cd "$ROOT" || exit 1

echo ""
echo "  AgentVideoParse"
echo "  Opening the app window…"
echo "  (First run may take a few seconds.)"
echo ""

if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 is not installed (or not on PATH)."
  echo ""
  echo "One-time setup for non-technical users:"
  echo "  1) Open https://www.python.org/downloads/"
  echo "  2) Download and install Python 3 for Mac"
  echo "  3) Double-click this file again"
  echo ""
  echo "Full guide: open START-HERE.md in this folder."
  echo ""
  read -r -p "Press Return to close…"
  exit 1
fi

if ! python3 -c "import tkinter" 2>/dev/null; then
  echo "Python is installed, but the GUI toolkit (tkinter) is missing."
  echo "Reinstall Python from python.org and include Tcl/Tk options."
  echo "See START-HERE.md"
  echo ""
  read -r -p "Press Return to close…"
  exit 1
fi

# Run GUI; if it crashes, pause so the error is readable
set +e
"$ROOT/bin/macos/run"
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  echo ""
  echo "Something went wrong (exit code $rc)."
  echo "See START-HERE.md, or turn on Debug logging after a successful open."
  echo ""
  read -r -p "Press Return to close…"
fi
exit "$rc"
