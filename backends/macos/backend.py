"""macOS media backend: AVFoundation via compiled Swift helper (system frameworks only)."""

from __future__ import annotations

import os
import subprocess
import sys
from typing import Callable, List, Optional, Sequence

_BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
_HELPER_NAME = "ExtractFrames"
_HELPER_PATH = os.path.join(_BACKEND_DIR, _HELPER_NAME)


def _swift_bin() -> str:
    return os.environ.get("SWIFT", "swiftc")


def ensure_helper() -> str:
    """Build ExtractFrames with swiftc + AVFoundation if missing or source newer."""
    src = os.path.join(_BACKEND_DIR, "ExtractFrames.swift")
    if not os.path.isfile(src):
        raise RuntimeError(f"missing {src}")
    need_build = not os.path.isfile(_HELPER_PATH)
    if not need_build:
        need_build = os.path.getmtime(src) > os.path.getmtime(_HELPER_PATH)
    if need_build:
        cmd = [
            _swift_bin(),
            "-O",
            "-framework",
            "AVFoundation",
            "-framework",
            "AppKit",
            "-framework",
            "CoreMedia",
            "-framework",
            "ImageIO",
            "-framework",
            "CoreGraphics",
            "-framework",
            "UniformTypeIdentifiers",
            src,
            "-o",
            _HELPER_PATH,
        ]
        proc = subprocess.run(cmd, capture_output=True, text=True)
        if proc.returncode != 0:
            raise RuntimeError(
                "Failed to build macOS ExtractFrames helper:\n"
                + (proc.stderr or proc.stdout or "unknown error")
            )
    return _HELPER_PATH


class MacOSBackend:
    name = "macos"

    def __init__(self) -> None:
        self._helper = ensure_helper()

    def probe_duration(self, input_path: str) -> float:
        proc = subprocess.run(
            [self._helper, "probe", input_path],
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            raise RuntimeError(proc.stderr.strip() or "probe failed")
        line = (proc.stdout or "").strip().splitlines()[-1]
        return float(line)

    def extract_frames(
        self,
        input_path: str,
        times: Sequence[float],
        output_directory: str,
        *,
        progress: Optional[Callable[[int, int], None]] = None,
        should_cancel: Optional[Callable[[], bool]] = None,
    ) -> List[float]:
        if should_cancel and should_cancel():
            from avp.export import ExportError

            raise ExportError("cancelled", "Export cancelled. Incomplete output was removed.")

        csv = ",".join(f"{t:.6f}" for t in times)
        # Progress: run all at once (AVFoundation generator); report start/end
        if progress:
            progress(0, len(times))
        proc = subprocess.run(
            [self._helper, "extract", input_path, output_directory, csv],
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            raise RuntimeError(proc.stderr.strip() or "extract failed")
        actual: List[float] = []
        for line in (proc.stdout or "").splitlines():
            parts = line.strip().split("\t")
            if len(parts) >= 2:
                actual.append(float(parts[1]))
        if progress:
            progress(len(times), len(times))
        return actual if actual else list(times)


# Allow `python backend.py probe|extract ...` for debugging
if __name__ == "__main__":
    b = MacOSBackend()
    if len(sys.argv) >= 3 and sys.argv[1] == "probe":
        print(b.probe_duration(sys.argv[2]))
    else:
        print("usage: backend.py probe <video>", file=sys.stderr)
        sys.exit(1)
