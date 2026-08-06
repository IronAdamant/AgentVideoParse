"""CLI: python -m avp export <video> [--output DIR]"""

from __future__ import annotations

import argparse
import os
import sys

# Allow running from repo root without install
_REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if _REPO not in sys.path:
    sys.path.insert(0, os.path.join(_REPO, "shared", "core"))
if _REPO not in sys.path:
    sys.path.insert(0, _REPO)

from avp.backends import get_backend  # noqa: E402
from avp.constants import DISCLAIMER_TEXT  # noqa: E402
from avp import debug_log  # noqa: E402
from avp.export import ExportError, export_video  # noqa: E402


def main(argv: list[str] | None = None) -> int:
    debug_log.enable_from_environment()
    parser = argparse.ArgumentParser(
        description="AgentVideoParse: short debug video → ordered screenshots (≤30s)."
    )
    parser.add_argument(
        "command",
        choices=["export", "disclaimer"],
        help="export video or print disclaimer",
    )
    parser.add_argument("video", nargs="?", help="Input video path")
    parser.add_argument(
        "-o",
        "--output",
        help="Output directory (default: under Movies/Videos/AgentVideoParse)",
    )
    args = parser.parse_args(argv)

    if args.command == "disclaimer":
        sys.stdout.write(DISCLAIMER_TEXT)
        return 0

    if not args.video:
        parser.error("video path required for export")

    backend = get_backend()

    def progress(i: int, n: int) -> None:
        sys.stderr.write(f"\rframe {i}/{n}")
        sys.stderr.flush()

    try:
        result = export_video(
            args.video,
            args.output,
            backend=backend,
            progress=progress,
        )
        sys.stderr.write("\n")
        print(result.output_directory)
        print(f"frames={result.frame_count} duration={result.duration_seconds:.3f}s")
        print(f"manifest={result.manifest_path}")
        return 0
    except ExportError as exc:
        sys.stderr.write(f"\nERROR [{exc.code}]: {exc.message}\n")
        return 2 if exc.code == "too_long" else 1


if __name__ == "__main__":
    raise SystemExit(main())
