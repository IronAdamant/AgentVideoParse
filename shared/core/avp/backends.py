"""Select platform media backend (stdlib orchestration only)."""

from __future__ import annotations

import sys
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .export import MediaBackend


def get_backend() -> "MediaBackend":
    if sys.platform == "darwin":
        from backends.macos.backend import MacOSBackend

        return MacOSBackend()
    if sys.platform.startswith("win"):
        from backends.windows.backend import WindowsBackend

        return WindowsBackend()
    from backends.linux.backend import LinuxBackend

    return LinuxBackend()
