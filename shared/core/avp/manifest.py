"""Manifest and agent readme writers (stdlib only)."""

from __future__ import annotations

import os
from datetime import datetime, timezone
from typing import List, Sequence, Tuple

from .constants import (
    DEFAULT_SAMPLE_FPS,
    DURATION_LIMIT_SECONDS,
    FRAME_EXTENSION,
    JPEG_QUALITY,
    MAX_FRAMES,
    MAX_LONG_EDGE,
)


def write_manifest(
    output_directory: str,
    source_path: str,
    duration_seconds: float,
    frame_entries: Sequence[Tuple[int, float, str]],
    *,
    sample_fps: float = DEFAULT_SAMPLE_FPS,
    platform: str = "unknown",
) -> str:
    """
    Write MANIFEST.txt mapping index/timestamp → filename.

    frame_entries: sequence of (index, timestamp_seconds, filename)
    Returns path to manifest file.
    """
    path = os.path.join(output_directory, "MANIFEST.txt")
    generated = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    lines = [
        "# AgentVideoParse manifest",
        "# purpose: debugging / agent UI review only",
        f"# source: {source_path}",
        f"# duration_seconds: {duration_seconds:.6f}",
        f"# max_allowed_seconds: {DURATION_LIMIT_SECONDS:g}",
        f"# sample_fps: {sample_fps:g}",
        f"# frame_count: {len(frame_entries)}",
        f"# max_frames: {MAX_FRAMES}",
        f"# image_format: {FRAME_EXTENSION}",
        f"# max_long_edge: {MAX_LONG_EDGE}",
        f"# jpeg_quality: {JPEG_QUALITY}",
        f"# platform: {platform}",
        f"# generated_at: {generated}",
        "",
        "index\ttimestamp_seconds\tfilename",
    ]
    for index, ts, filename in frame_entries:
        lines.append(f"{index}\t{ts:.3f}\t{filename}")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    return path


def write_agent_readme(output_directory: str) -> str:
    path = os.path.join(output_directory, "README-FOR-AGENT.txt")
    text = (
        "AgentVideoParse output\n"
        "======================\n"
        "\n"
        "These ordered screenshots were extracted from a short debug video "
        "(maximum 30 seconds). This folder is for AI/agent UI debugging only.\n"
        "\n"
        "Read MANIFEST.txt for index → timestamp → filename mapping.\n"
        f"Frames are named frame-0001.{FRAME_EXTENSION}, … in time order "
        f"(agent-friendly JPEG, long edge ≤ {MAX_LONG_EDGE}px).\n"
    )
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)
    return path


def frame_filename(index: int) -> str:
    return f"frame-{index:04d}.{FRAME_EXTENSION}"
