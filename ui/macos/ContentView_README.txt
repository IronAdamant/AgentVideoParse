macOS GUI: AgentVideoParseApp.swift (SwiftUI + permanent disclaimer + drop/browse).

Build (from repo root, developer machines with Xcode):
  cd ui/macos
  # Or open an Xcode project; for a quick tool-style build of the Python+tk GUI on macOS:
  #   python3 ui/linux/app.py
  # Native SwiftUI entry is AgentVideoParseApp.swift (system frameworks only).

The SwiftUI app shells out to the shipped Python export path so DurationGate /
FrameSampler remain the single pure-core implementation.
