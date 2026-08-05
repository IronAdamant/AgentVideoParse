"""
Optional operation debug log (stdlib only).

Enable from any GUI "Debug" control so users can extract a text log of
probe / gate / sample / extract steps when something fails.
"""

from __future__ import annotations

import os
import sys
import threading
import traceback
from datetime import datetime, timezone
from typing import Optional

_lock = threading.Lock()
_enabled = False
_log_path: Optional[str] = None


def enable_from_environment() -> None:
    """
    If AVP_DEBUG_LOG is set to a file path, append logs there.
    If AVP_DEBUG=1 (and no path), create a new log under default_log_dir().
    """
    path = os.environ.get("AVP_DEBUG_LOG", "").strip()
    flag = os.environ.get("AVP_DEBUG", "").strip().lower()
    if path:
        global _enabled, _log_path
        with _lock:
            _enabled = True
            os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
            _log_path = path
            _append_unlocked(f"=== AgentVideoParse debug (env AVP_DEBUG_LOG) {_iso()} ===")
        return
    if flag in ("1", "true", "yes", "on"):
        set_enabled(True)


def default_log_dir() -> str:
    home = os.path.expanduser("~")
    if sys.platform == "darwin":
        base = os.path.join(home, "Movies", "AgentVideoParse", "logs")
    elif sys.platform.startswith("win"):
        base = os.path.join(home, "Videos", "AgentVideoParse", "logs")
    else:
        videos = os.path.join(home, "Videos")
        base = (
            os.path.join(videos, "AgentVideoParse", "logs")
            if os.path.isdir(videos)
            else os.path.join(home, "AgentVideoParse", "logs")
        )
    return base


def is_enabled() -> bool:
    return _enabled


def log_path() -> Optional[str]:
    return _log_path


def set_enabled(enabled: bool, *, log_directory: Optional[str] = None) -> str:
    """
    Enable or disable debug logging.

    Returns the path of the active log file (created when enabling).
    """
    global _enabled, _log_path
    with _lock:
        _enabled = bool(enabled)
        if not _enabled:
            if _log_path:
                _append_unlocked(f"=== debug logging DISABLED at {_iso()} ===")
            return _log_path or ""
        log_dir = log_directory or default_log_dir()
        os.makedirs(log_dir, exist_ok=True)
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        _log_path = os.path.join(log_dir, f"agentvideoparse-debug-{stamp}.log")
        with open(_log_path, "w", encoding="utf-8") as fh:
            fh.write(f"=== AgentVideoParse debug log started {_iso()} ===\n")
            fh.write(f"platform={sys.platform} python={sys.version.split()[0]}\n")
            fh.write(f"cwd={os.getcwd()}\n")
            fh.write(
                "This log is for debugging exports only. "
                "It is written locally and never uploaded.\n\n"
            )
        return _log_path


def log(message: str) -> None:
    """Append one line if logging is enabled."""
    with _lock:
        if not _enabled or not _log_path:
            return
        _append_unlocked(message)


def log_exception(prefix: str, exc: BaseException) -> None:
    with _lock:
        if not _enabled or not _log_path:
            return
        _append_unlocked(f"{prefix}: {type(exc).__name__}: {exc}")
        tb = "".join(traceback.format_exception(type(exc), exc, exc.__traceback__))
        for line in tb.rstrip().splitlines():
            _append_unlocked("  | " + line)


def _iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _append_unlocked(message: str) -> None:
    if not _log_path:
        return
    line = f"[{_iso()}] {message}\n"
    try:
        with open(_log_path, "a", encoding="utf-8") as fh:
            fh.write(line)
    except OSError:
        pass
