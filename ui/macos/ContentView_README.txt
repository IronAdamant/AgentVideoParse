macOS GUI notes
===============

Primary product app (recommended):
  macos/AgentVideoParse/   →  ./scripts/build-macos-app.sh
  Output: dist/AgentVideoParse.app  (SwiftUI + AVFoundation, no Python runtime)

This folder (ui/macos/) is a legacy/alternate shell sketch that shells out to
the Python export path. Prefer the native app under macos/ for day-to-day use
and releases. Windows/Linux bases remain under ui/windows and ui/linux.
