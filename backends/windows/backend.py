"""
Windows media backend: system WPF MediaPlayer + WIC via C# helper.

AvpExtract.cs uses inbox PresentationCore MediaPlayer (ScrubbingEnabled) and
PngBitmapEncoder — no NuGet, no vendored FFmpeg, no IMFSourceReader COM layer.
(Media Foundation codecs still back MediaPlayer for common containers on Windows.)
"""

from __future__ import annotations

import os
import subprocess
import sys
from typing import Callable, List, Optional, Sequence

_DIR = os.path.dirname(os.path.abspath(__file__))
_EXE = os.path.join(_DIR, "AvpExtract.exe")
_CS = os.path.join(_DIR, "AvpExtract.cs")


def _find_csc() -> Optional[str]:
    # Typical .NET Framework csc locations; also respect CSC env
    if os.environ.get("CSC"):
        return os.environ["CSC"]
    windir = os.environ.get("WINDIR", r"C:\Windows")
    candidates = [
        os.path.join(
            windir,
            "Microsoft.NET",
            "Framework64",
            "v4.0.30319",
            "csc.exe",
        ),
        os.path.join(windir, "Microsoft.NET", "Framework", "v4.0.30319", "csc.exe"),
    ]
    for c in candidates:
        if os.path.isfile(c):
            return c
    return None


def ensure_helper() -> str:
    if sys.platform.startswith("win"):
        if os.path.isfile(_EXE) and os.path.getmtime(_EXE) >= os.path.getmtime(_CS):
            return _EXE
        csc = _find_csc()
        if not csc:
            raise RuntimeError(
                "csc.exe not found. Install .NET Framework developer pack / Visual Studio."
            )
        # Reference system assemblies only
        cmd = [
            csc,
            "/nologo",
            "/optimize+",
            "/target:exe",
            f"/out:{_EXE}",
            "/r:System.dll",
            "/r:System.Core.dll",
            "/r:PresentationCore.dll",
            "/r:WindowsBase.dll",
            _CS,
        ]
        proc = subprocess.run(cmd, capture_output=True, text=True)
        if proc.returncode != 0:
            raise RuntimeError("Build AvpExtract.exe failed:\n" + (proc.stderr or proc.stdout))
        return _EXE
    # Cross-compile not available on non-Windows hosts
    if os.path.isfile(_EXE):
        return _EXE
    raise RuntimeError(
        "Windows backend helper AvpExtract.exe must be built on Windows "
        "(Media Foundation). Source: backends/windows/AvpExtract.cs"
    )


class WindowsBackend:
    name = "windows"

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
        return float(proc.stdout.strip().splitlines()[-1])

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
