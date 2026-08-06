#!/usr/bin/env python3
"""
AgentVideoParse portable GUI — Python 3 + tkinter (stdlib only).

Used on Linux and as the easy launcher GUI on macOS/Windows.
Includes a Debug control to write/extract operation logs.
"""

from __future__ import annotations

import os
import sys
import threading
import tkinter as tk
from tkinter import filedialog, messagebox

# Repo paths
_REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(_REPO, "shared", "core"))
sys.path.insert(0, _REPO)

from avp import debug_log
from avp.backends import get_backend
from avp.constants import (
    DEFAULT_SAMPLE_FPS,
    DISCLAIMER_TEXT,
    DURATION_LIMIT_SECONDS,
    MAX_FRAMES,
)
from avp.export import ExportError, default_output_root, export_video, make_run_directory


class App(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("AgentVideoParse")
        self.minsize(520, 600)
        self._busy = False
        self._output_root = default_output_root()
        self._debug_on = tk.BooleanVar(value=False)
        self._last_out: str | None = None
        self._last_log: str | None = None

        header = tk.Label(
            self,
            text="AgentVideoParse\nShort debug video → ordered screenshots for AI agents",
            font=("Helvetica", 14, "bold"),
            justify="center",
        )
        header.pack(pady=(12, 6))

        disc_frame = tk.LabelFrame(self, text="Disclaimer (always visible)", padx=8, pady=6)
        disc_frame.pack(fill="x", padx=12, pady=6)
        disc = tk.Label(
            disc_frame,
            text=DISCLAIMER_TEXT.strip(),
            justify="left",
            wraplength=480,
            fg="#4a2000",
            bg="#fff3cd",
        )
        disc.pack(fill="x")
        disc.configure(bg="#fff3cd")
        disc_frame.configure(bg="#fff3cd")

        self.drop = tk.Label(
            self,
            text="Drop a video here\n(.mov, .mp4, …)\nor click to choose file",
            relief="groove",
            borderwidth=2,
            width=48,
            height=8,
            bg="#f0f4f8",
        )
        self.drop.pack(padx=12, pady=12, fill="both", expand=True)
        self.drop.bind("<Button-1>", lambda e: self.choose_file())

        out_row = tk.Frame(self)
        out_row.pack(fill="x", padx=12)
        tk.Label(out_row, text="Output folder:").pack(side="left")
        self.out_var = tk.StringVar(value=self._output_root)
        tk.Entry(out_row, textvariable=self.out_var).pack(
            side="left", fill="x", expand=True, padx=4
        )
        tk.Button(out_row, text="Change", command=self.choose_out).pack(side="left")

        tk.Label(
            self,
            text=(
                f"Sampling: {DEFAULT_SAMPLE_FPS:g} fps · max {MAX_FRAMES} stills · "
                f"max {DURATION_LIMIT_SECONDS:g}s duration"
            ),
        ).pack(pady=4)

        debug_row = tk.Frame(self)
        debug_row.pack(fill="x", padx=12, pady=4)
        tk.Checkbutton(
            debug_row,
            text="Debug logging",
            variable=self._debug_on,
            command=self.toggle_debug,
        ).pack(side="left")
        self.open_log_btn = tk.Button(
            debug_row, text="Open debug log", command=self.open_log, state="disabled"
        )
        self.open_log_btn.pack(side="left", padx=4)
        self.copy_log_btn = tk.Button(
            debug_row, text="Copy log path", command=self.copy_log_path, state="disabled"
        )
        self.copy_log_btn.pack(side="left", padx=4)

        self.status = tk.Label(
            self, text="Ready.", anchor="w", justify="left", wraplength=480
        )
        self.status.pack(fill="x", padx=12, pady=6)

        btn_row = tk.Frame(self)
        btn_row.pack(pady=6)
        self.reveal_btn = tk.Button(
            btn_row, text="Reveal in file manager", command=self.reveal, state="disabled"
        )
        self.reveal_btn.pack(side="left", padx=4)
        self.copy_btn = tk.Button(
            btn_row, text="Copy path", command=self.copy_path, state="disabled"
        )
        self.copy_btn.pack(side="left", padx=4)

        tk.Label(
            self,
            text="Open Source · Debug only · ≤30s · macOS / Windows / Linux",
            fg="#555",
        ).pack(side="bottom", pady=8)

    def toggle_debug(self) -> None:
        if self._debug_on.get():
            path = debug_log.set_enabled(True)
            self._last_log = path
            debug_log.log("GUI: debug logging enabled by user")
            self.open_log_btn.config(state="normal")
            self.copy_log_btn.config(state="normal")
            self.status.config(text=f"Debug logging ON\n{path}")
        else:
            debug_log.log("GUI: debug logging disabled by user")
            debug_log.set_enabled(False)
            self.status.config(text="Debug logging OFF")

    def open_log(self) -> None:
        path = self._last_log or debug_log.log_path()
        if not path or not os.path.isfile(path):
            messagebox.showinfo("Debug log", "No debug log yet. Enable Debug logging first.")
            return
        self._reveal_path(path)

    def copy_log_path(self) -> None:
        path = self._last_log or debug_log.log_path()
        if not path:
            messagebox.showinfo("Debug log", "No debug log path yet.")
            return
        self.clipboard_clear()
        self.clipboard_append(path)
        self.status.config(text=f"Copied log path:\n{path}")

    def choose_out(self) -> None:
        d = filedialog.askdirectory(initialdir=self._output_root)
        if d:
            self.out_var.set(d)
            self._output_root = d
            debug_log.log(f"GUI: output root changed to {d!r}")

    def choose_file(self) -> None:
        if self._busy:
            return
        path = filedialog.askopenfilename(
            title="Choose a short debug video (≤30s)",
            filetypes=[
                ("Video", "*.mov *.mp4 *.m4v *.webm *.avi"),
                ("All", "*.*"),
            ],
        )
        if path:
            self.start_export(path)

    def start_export(self, path: str) -> None:
        if self._busy:
            return
        self._busy = True
        self.status.config(text=f"Processing: {os.path.basename(path)} …")
        self.reveal_btn.config(state="disabled")
        self.copy_btn.config(state="disabled")
        debug_log.log(f"GUI: start_export path={path!r}")

        def work() -> None:
            try:
                backend = get_backend()
                debug_log.log(f"GUI: backend={getattr(backend, 'name', '?')}")
                root = self.out_var.get().strip() or default_output_root()
                os.makedirs(root, exist_ok=True)
                out = make_run_directory(root, path)

                def progress(i: int, n: int) -> None:
                    self.after(
                        0, lambda: self.status.config(text=f"Exporting frame {i}/{n}…")
                    )

                result = export_video(path, out, backend=backend, progress=progress)
                self._last_out = result.output_directory
                msg = (
                    f"Wrote {result.frame_count} screenshots ({result.duration_seconds:.2f}s)\n"
                    f"{result.output_directory}"
                )
                if debug_log.is_enabled() and debug_log.log_path():
                    msg += f"\nDebug log: {debug_log.log_path()}"
                self.after(0, lambda: self._ok(msg))
            except ExportError as exc:
                debug_log.log(f"GUI: ExportError [{exc.code}] {exc.message}")
                self.after(0, lambda: self._err(exc.message))
            except Exception as exc:  # noqa: BLE001
                debug_log.log_exception("GUI: unexpected error", exc)
                self.after(0, lambda: self._err(str(exc)))

        threading.Thread(target=work, daemon=True).start()

    def _ok(self, msg: str) -> None:
        self._busy = False
        self.status.config(text=msg)
        self.reveal_btn.config(state="normal")
        self.copy_btn.config(state="normal")
        if debug_log.log_path():
            self._last_log = debug_log.log_path()
            self.open_log_btn.config(state="normal")
            self.copy_log_btn.config(state="normal")

    def _err(self, msg: str) -> None:
        self._busy = False
        self.status.config(text=msg)
        if debug_log.log_path():
            self._last_log = debug_log.log_path()
            self.open_log_btn.config(state="normal")
            self.copy_log_btn.config(state="normal")
            msg = f"{msg}\n\nDebug log: {self._last_log}"
        messagebox.showerror("AgentVideoParse", msg)

    def _reveal_path(self, path: str) -> None:
        if sys.platform == "darwin":
            os.system(f'open -R "{path}"' if os.path.isfile(path) else f'open "{path}"')
        elif sys.platform.startswith("win"):
            if os.path.isfile(path):
                os.system(f'explorer /select,"{path}"')
            else:
                os.startfile(path)  # type: ignore[attr-defined]
        else:
            folder = path if os.path.isdir(path) else os.path.dirname(path)
            os.system(f'xdg-open "{folder}" >/dev/null 2>&1 &')

    def reveal(self) -> None:
        if not self._last_out:
            return
        self._reveal_path(self._last_out)

    def copy_path(self) -> None:
        if not self._last_out:
            return
        self.clipboard_clear()
        self.clipboard_append(self._last_out)
        self.status.config(text=f"Copied path:\n{self._last_out}")


def main() -> None:
    app = App()
    app.mainloop()


if __name__ == "__main__":
    main()
