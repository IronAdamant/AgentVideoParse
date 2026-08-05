"""
Export orchestrator: probe → gate → sample → extract → manifest.

All frame writes happen only after DurationGate accepts.
"""

from __future__ import annotations

import os
import shutil
import sys
from dataclasses import dataclass
from typing import Callable, List, Optional, Protocol, Sequence

from .constants import DEFAULT_SAMPLE_FPS, DURATION_LIMIT_SECONDS, MAX_FRAMES
from .duration_gate import DurationStatus, evaluate_duration
from .frame_sampler import sample_times
from .manifest import frame_filename, write_agent_readme, write_manifest


class MediaBackend(Protocol):
    """Platform media stack adapter (AVFoundation / MF / GStreamer)."""

    name: str

    def probe_duration(self, input_path: str) -> float:
        """Return duration in seconds; raise on unreadable media."""

    def extract_frames(
        self,
        input_path: str,
        times: Sequence[float],
        output_directory: str,
        *,
        progress: Optional[Callable[[int, int], None]] = None,
        should_cancel: Optional[Callable[[], bool]] = None,
    ) -> List[float]:
        """
        Write frame-0001.png … for each time.
        Returns actual timestamps used (same length as times ideally).
        Must not be called for rejected durations by export_video.
        """


class ExportError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


@dataclass
class ExportResult:
    frame_count: int
    duration_seconds: float
    output_directory: str
    manifest_path: str
    sample_times: List[float]


def default_output_root() -> str:
    home = os.path.expanduser("~")
    if sys.platform == "darwin":
        base = os.path.join(home, "Movies", "AgentVideoParse")
    elif sys.platform.startswith("win"):
        videos = os.path.join(home, "Videos", "AgentVideoParse")
        base = videos if os.path.isdir(os.path.join(home, "Videos")) or True else os.path.join(
            home, "AgentVideoParse"
        )
    else:
        videos = os.path.join(home, "Videos")
        base = (
            os.path.join(videos, "AgentVideoParse")
            if os.path.isdir(videos)
            else os.path.join(home, "AgentVideoParse")
        )
    return base


def make_run_directory(output_root: str, source_path: str) -> str:
    from datetime import datetime

    base = os.path.splitext(os.path.basename(source_path))[0] or "video"
    # sanitize
    safe = "".join(c if c.isalnum() or c in "-_" else "_" for c in base)[:80]
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    path = os.path.join(output_root, f"{safe}-{stamp}")
    os.makedirs(path, exist_ok=False)
    return path


def export_video(
    input_path: str,
    output_directory: Optional[str] = None,
    *,
    backend: MediaBackend,
    fps: float = DEFAULT_SAMPLE_FPS,
    max_frames: int = MAX_FRAMES,
    progress: Optional[Callable[[int, int], None]] = None,
    should_cancel: Optional[Callable[[], bool]] = None,
) -> ExportResult:
    """
    Full export path used by all GUIs/CLIs.

    1) probe duration
    2) evaluate_duration — if rejected, write nothing and raise ExportError
    3) sample_times
    4) extract frames via backend
    5) manifest + agent readme
    """
    from . import debug_log

    input_path = os.path.abspath(input_path)
    debug_log.log(
        f"export_video start input={input_path!r} backend={getattr(backend, 'name', '?')} "
        f"fps={fps} max_frames={max_frames}"
    )
    if not os.path.isfile(input_path):
        debug_log.log("export_video fail: file not found")
        raise ExportError("unsupported", f"File not found: {input_path}")

    # Probe first (no writes yet)
    try:
        duration = float(backend.probe_duration(input_path))
        debug_log.log(f"probe_duration ok duration_seconds={duration:.6f}")
    except ExportError:
        raise
    except Exception as exc:  # noqa: BLE001 — surface as unsupported
        debug_log.log_exception("probe_duration failed", exc)
        raise ExportError(
            "unsupported",
            f"Could not read this video with the system media stack: {exc}",
        ) from exc

    decision = evaluate_duration(duration)
    debug_log.log(f"duration_gate status={decision.status.value} limit={DURATION_LIMIT_SECONDS}")
    if decision.status is DurationStatus.REJECTED_INVALID:
        debug_log.log("export_video rejected: invalid duration")
        raise ExportError("unsupported", "Could not determine a valid video duration.")
    if decision.status is DurationStatus.REJECTED_TOO_LONG:
        debug_log.log(f"export_video rejected: too_long duration={duration:.3f}")
        raise ExportError(
            "too_long",
            (
                f"This video is {duration:.2f}s long. AgentVideoParse only accepts "
                f"videos of {DURATION_LIMIT_SECONDS:g} seconds or less "
                f"(debugging sessions). No screenshots were created."
            ),
        )

    # Gate passed — only now prepare output directory and write frames.
    # Safety: never shutil.rmtree a caller-supplied directory (may contain
    # pre-existing user files). Only rmtree run dirs we created empty ourselves.
    remove_dir_on_failure = False
    if output_directory is None:
        root = default_output_root()
        os.makedirs(root, exist_ok=True)
        output_directory = make_run_directory(root, input_path)
        remove_dir_on_failure = True
    else:
        output_directory = os.path.abspath(output_directory)
        os.makedirs(output_directory, exist_ok=True)
        remove_dir_on_failure = False
    debug_log.log(
        f"output_directory={output_directory!r} remove_dir_on_failure={remove_dir_on_failure}"
    )

    times = sample_times(duration, fps=fps, max_frames=max_frames)
    debug_log.log(f"sample_times count={len(times)} first={times[0] if times else None} last={times[-1] if times else None}")
    written_names: List[str] = []
    try:
        if should_cancel and should_cancel():
            debug_log.log("export_video cancelled before extract")
            raise ExportError("cancelled", "Export cancelled. Incomplete output was removed.")

        def _progress(i: int, n: int) -> None:
            debug_log.log(f"extract progress {i}/{n}")
            if progress:
                progress(i, n)

        actual_times = backend.extract_frames(
            input_path,
            times,
            output_directory,
            progress=_progress,
            should_cancel=should_cancel,
        )
        if not actual_times:
            actual_times = list(times)
        debug_log.log(f"extract_frames done actual_count={len(actual_times)}")

        # Downscale + JPEG for agent-friendly sizes (Pillow if available)
        from .stills import make_agent_friendly

        final_names = make_agent_friendly(output_directory)
        debug_log.log(f"agent_friendly stills count={len(final_names)}")

        entries = []
        for i, ts in enumerate(actual_times, start=1):
            name = (
                final_names[i - 1]
                if i - 1 < len(final_names)
                else frame_filename(i)
            )
            fpath = os.path.join(output_directory, name)
            if not os.path.isfile(fpath):
                # fall back: any frame-XXXX.*
                alt = None
                for ext in (".jpg", ".jpeg", ".png"):
                    cand = os.path.join(output_directory, f"frame-{i:04d}{ext}")
                    if os.path.isfile(cand):
                        alt = os.path.basename(cand)
                        break
                if alt is None:
                    debug_log.log(f"missing frame file {name}")
                    raise ExportError(
                        "write_failed",
                        f"Expected frame file missing: {name}",
                    )
                name = alt
                fpath = os.path.join(output_directory, name)
            written_names.append(name)
            entries.append((i, float(ts), name))

        manifest_path = write_manifest(
            output_directory,
            input_path,
            duration,
            entries,
            sample_fps=fps,
            platform=getattr(backend, "name", "unknown"),
        )
        written_names.append(os.path.basename(manifest_path))
        agent_path = write_agent_readme(output_directory)
        written_names.append(os.path.basename(agent_path))
        debug_log.log(
            f"export_video success frames={len(entries)} manifest={manifest_path!r}"
        )

        return ExportResult(
            frame_count=len(entries),
            duration_seconds=duration,
            output_directory=output_directory,
            manifest_path=manifest_path,
            sample_times=[e[1] for e in entries],
        )
    except Exception as exc:
        debug_log.log_exception("export_video failed; cleaning partial output", exc)
        _cleanup_partial_export(
            output_directory,
            written_names=written_names,
            remove_directory=remove_dir_on_failure,
        )
        raise


def _cleanup_partial_export(
    output_directory: Optional[str],
    *,
    written_names: Sequence[str],
    remove_directory: bool,
) -> None:
    """
    On failure/cancel: drop partial AgentVideoParse outputs.

    - If remove_directory is True (we created a fresh run folder), rmtree it.
    - If the caller supplied -o, only remove our product files (frame-*.png,
      MANIFEST.txt, README-FOR-AGENT.txt) and never delete unrelated pre-existing files.
    """
    if not output_directory or not os.path.isdir(output_directory):
        return
    if remove_directory:
        shutil.rmtree(output_directory, ignore_errors=True)
        return
    # Caller-owned directory: only remove our artifacts (including any frames
    # the backend may have written even if not yet tracked in written_names).
    try:
        for name in os.listdir(output_directory):
            if (
                name.startswith("frame-")
                and name.lower().endswith((".png", ".jpg", ".jpeg"))
            ) or name in (
                "MANIFEST.txt",
                "README-FOR-AGENT.txt",
            ) or name in written_names:
                try:
                    os.remove(os.path.join(output_directory, name))
                except OSError:
                    pass
    except OSError:
        pass
