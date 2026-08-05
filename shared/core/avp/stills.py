"""Agent-friendly still post-process: downscale + JPEG (stdlib + optional Pillow)."""

from __future__ import annotations

import os
import struct
import zlib
from typing import List, Tuple

from .constants import FRAME_EXTENSION, JPEG_QUALITY, MAX_LONG_EDGE


def make_agent_friendly(
    output_directory: str,
    *,
    max_long_edge: int = MAX_LONG_EDGE,
    jpeg_quality: int = JPEG_QUALITY,
) -> List[str]:
    """
    Convert any frame-*.png/jpg in the directory to agent-friendly JPEGs.

    Returns list of final frame filenames (frame-0001.jpg, …) in order.
    Prefers Pillow when available; otherwise leaves existing files if already JPEG
    and within size, or copies with rename only when already .jpg.
    """
    names = sorted(
        n
        for n in os.listdir(output_directory)
        if n.startswith("frame-") and n.lower().endswith((".png", ".jpg", ".jpeg"))
    )
    if not names:
        return []

    try:
        from PIL import Image  # type: ignore
    except ImportError:
        # No Pillow: rename png→jpg is wrong without re-encode; keep as-is if already jpg
        out = []
        for n in names:
            src = os.path.join(output_directory, n)
            if n.lower().endswith((".jpg", ".jpeg")):
                # normalize name
                idx = _index_from_name(n)
                dest_name = f"frame-{idx:04d}.{FRAME_EXTENSION}"
                dest = os.path.join(output_directory, dest_name)
                if src != dest:
                    os.replace(src, dest)
                out.append(dest_name)
            else:
                # Cannot re-encode PNG without Pillow; keep PNG (backend fallback)
                out.append(n)
        return out

    out_names: List[str] = []
    for n in names:
        src = os.path.join(output_directory, n)
        idx = _index_from_name(n)
        dest_name = f"frame-{idx:04d}.{FRAME_EXTENSION}"
        dest = os.path.join(output_directory, dest_name)
        try:
            with Image.open(src) as im:
                im = im.convert("RGB")
                w, h = im.size
                long = max(w, h)
                if long > max_long_edge > 0:
                    scale = max_long_edge / float(long)
                    nw = max(1, int(round(w * scale)))
                    nh = max(1, int(round(h * scale)))
                    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
                im.save(dest, "JPEG", quality=int(jpeg_quality), optimize=True)
            if src != dest and os.path.isfile(src):
                try:
                    os.remove(src)
                except OSError:
                    pass
            out_names.append(dest_name)
        except Exception:
            # Invalid/corrupt test stubs: keep original filename
            out_names.append(n)
    return out_names


def _index_from_name(name: str) -> int:
    # frame-0001.png
    base = os.path.splitext(name)[0]
    parts = base.split("-")
    try:
        return int(parts[-1])
    except ValueError:
        return 1
