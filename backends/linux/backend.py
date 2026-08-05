"""
Linux media backend: GStreamer 1.x (system packages only; not vendored).

Primary path: native helper ``avp_gst`` (C + libgstreamer) with real seeks.
Auto-builds the helper when gcc and pkg-config are available.

Fallback path: gst-launch-1.0 with a seek-capable pipeline per timestamp
(using a temporary pipeline script that seeks after PAUSED — not the broken
uridecodebin start-time= property).
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import tempfile
from typing import Callable, List, Optional, Sequence

_DIR = os.path.dirname(os.path.abspath(__file__))
_HELPER = os.path.join(_DIR, "avp_gst")
_HELPER_SRC = os.path.join(_DIR, "avp_gst.c")


def _which(name: str) -> Optional[str]:
    return shutil.which(name)


def ensure_helper() -> Optional[str]:
    """Build avp_gst from system GStreamer if missing/stale. Returns path or None."""
    if os.path.isfile(_HELPER) and os.access(_HELPER, os.X_OK):
        if os.path.isfile(_HELPER_SRC) and os.path.getmtime(_HELPER) >= os.path.getmtime(
            _HELPER_SRC
        ):
            return _HELPER
    cc = _which("cc") or _which("gcc")
    pkg = _which("pkg-config")
    if not cc or not pkg or not os.path.isfile(_HELPER_SRC):
        return _HELPER if os.path.isfile(_HELPER) and os.access(_HELPER, os.X_OK) else None
    try:
        flags = subprocess.run(
            [pkg, "--cflags", "--libs", "gstreamer-1.0", "gstreamer-pbutils-1.0"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return _HELPER if os.path.isfile(_HELPER) and os.access(_HELPER, os.X_OK) else None
    cmd = [cc, "-O2", "-o", _HELPER, _HELPER_SRC] + flags.split()
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        return None
    return _HELPER if os.path.isfile(_HELPER) and os.access(_HELPER, os.X_OK) else None


class LinuxBackend:
    name = "linux"

    def probe_duration(self, input_path: str) -> float:
        helper = ensure_helper()
        if helper:
            proc = subprocess.run(
                [helper, "probe", input_path], capture_output=True, text=True
            )
            if proc.returncode == 0:
                return float(proc.stdout.strip().splitlines()[-1])

        discoverer = _which("gst-discoverer-1.0")
        if not discoverer:
            raise RuntimeError(
                "Required system media components are missing. "
                "Install GStreamer (gst-discoverer-1.0 / libgstreamer) — see README."
            )
        proc = subprocess.run(
            [discoverer, "-v", input_path],
            capture_output=True,
            text=True,
        )
        text = (proc.stdout or "") + (proc.stderr or "")
        m = re.search(
            r"Duration:\s*(?:(\d+):)?(\d+):(\d+)(?:\.(\d+))?",
            text,
        )
        if not m:
            m2 = re.search(r"duration:\s*(\d+)", text, re.I)
            if m2:
                return int(m2.group(1)) / 1e9
            raise RuntimeError(
                "Could not parse duration from gst-discoverer-1.0. "
                "Install gstreamer1.0-plugins-base/good/libav."
            )
        hours = int(m.group(1) or 0)
        minutes = int(m.group(2))
        seconds = int(m.group(3))
        frac = m.group(4) or "0"
        frac_val = float(f"0.{frac}") if frac else 0.0
        return hours * 3600 + minutes * 60 + seconds + frac_val

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

        os.makedirs(output_directory, exist_ok=True)
        helper = ensure_helper()
        if helper:
            return self._extract_via_helper(
                helper, input_path, times, output_directory, progress, should_cancel
            )
        return self._extract_via_gst_launch(
            input_path, times, output_directory, progress, should_cancel
        )

    def _extract_via_helper(
        self,
        helper: str,
        input_path: str,
        times: Sequence[float],
        output_directory: str,
        progress: Optional[Callable[[int, int], None]],
        should_cancel: Optional[Callable[[], bool]],
    ) -> List[float]:
        if should_cancel and should_cancel():
            from avp.export import ExportError

            raise ExportError("cancelled", "Export cancelled. Incomplete output was removed.")
        csv = ",".join(f"{t:.6f}" for t in times)
        if progress:
            progress(0, len(times))
        proc = subprocess.run(
            [helper, "extract", input_path, output_directory, csv],
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            raise RuntimeError(proc.stderr.strip() or "avp_gst extract failed")
        actual: List[float] = []
        for line in (proc.stdout or "").splitlines():
            parts = line.strip().split("\t")
            if len(parts) >= 2:
                actual.append(float(parts[1]))
        if progress:
            progress(len(times), len(times))
        return actual if actual else list(times)

    def _extract_via_gst_launch(
        self,
        input_path: str,
        times: Sequence[float],
        output_directory: str,
        progress: Optional[Callable[[int, int], None]],
        should_cancel: Optional[Callable[[], bool]],
    ) -> List[float]:
        """
        Fallback when ``avp_gst`` cannot be built.

        Uses system **python3-gi** (distro package) for real PAUSED→seek→snapshot
        so multi-time samples are not all the first frame. Does **not** use the
        broken ``uridecodebin start-time=`` gst-launch pattern.
        """
        try:
            return self._extract_via_gi(
                input_path, times, output_directory, progress, should_cancel
            )
        except Exception as gi_err:  # noqa: BLE001
            raise RuntimeError(
                "Linux multi-timestamp extract needs avp_gst (preferred; "
                "cc + pkg-config gstreamer-1.0 gstreamer-pbutils-1.0) or "
                "python3-gi for seeks. See README. "
                f"Detail: {gi_err}"
            ) from gi_err

    def _extract_via_gi(
        self,
        input_path: str,
        times: Sequence[float],
        output_directory: str,
        progress: Optional[Callable[[int, int], None]],
        should_cancel: Optional[Callable[[], bool]],
    ) -> List[float]:
        """Seek + snapshot using system PyGObject (python3-gi distro package)."""
        import gi  # type: ignore

        gi.require_version("Gst", "1.0")
        from gi.repository import Gst  # type: ignore

        Gst.init(None)
        abs_path = os.path.abspath(input_path)
        uri = Gst.filename_to_uri(abs_path)
        actual: List[float] = []

        for i, t in enumerate(times, start=1):
            if should_cancel and should_cancel():
                from avp.export import ExportError

                raise ExportError(
                    "cancelled", "Export cancelled. Incomplete output was removed."
                )
            name = f"frame-{i:04d}.png"
            dest = os.path.join(output_directory, name)
            # Pipeline: uridecodebin ! videoconvert ! pngenc snapshot ! filesink
            descr = (
                f"uridecodebin uri={uri} ! videoconvert ! videoscale ! "
                f"video/x-raw,format=RGB ! pngenc snapshot=true ! "
                f"filesink location={dest}"
            )
            pipeline = Gst.parse_launch(descr)
            pipeline.set_state(Gst.State.PAUSED)
            # Wait for preroll
            ret = pipeline.get_state(5 * Gst.SECOND)
            if ret[0] == Gst.StateChangeReturn.FAILURE:
                pipeline.set_state(Gst.State.NULL)
                raise RuntimeError(f"GStreamer preroll failed at t={t}")
            # Seek to timestamp (key unit flush)
            ok = pipeline.seek_simple(
                Gst.Format.TIME,
                Gst.SeekFlags.FLUSH | Gst.SeekFlags.KEY_UNIT,
                int(t * Gst.SECOND),
            )
            if not ok:
                # try accurate seek
                ok = pipeline.seek_simple(
                    Gst.Format.TIME,
                    Gst.SeekFlags.FLUSH | Gst.SeekFlags.ACCURATE,
                    int(t * Gst.SECOND),
                )
            pipeline.set_state(Gst.State.PLAYING)
            bus = pipeline.get_bus()
            msg = bus.timed_pop_filtered(
                10 * Gst.SECOND,
                Gst.MessageType.ERROR | Gst.MessageType.EOS | Gst.MessageType.ASYNC_DONE,
            )
            # Allow encode to finish
            bus.timed_pop_filtered(2 * Gst.SECOND, Gst.MessageType.EOS | Gst.MessageType.ERROR)
            pipeline.set_state(Gst.State.NULL)
            if not os.path.isfile(dest) or os.path.getsize(dest) < 32:
                raise RuntimeError(
                    f"GStreamer did not write frame at t={t}s (seek ok={ok}, msg={msg})"
                )
            actual.append(float(t))
            if progress:
                progress(i, len(times))
        return actual
