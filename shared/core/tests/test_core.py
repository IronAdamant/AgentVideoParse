"""Unit tests for shipped DurationGate and FrameSampler (no video required)."""

from __future__ import annotations

import math
import os
import sys
import unittest

# shipped package path
_CORE = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if _CORE not in sys.path:
    sys.path.insert(0, _CORE)

from avp.constants import DEFAULT_SAMPLE_FPS, DURATION_LIMIT_SECONDS, MAX_FRAMES
from avp.duration_gate import DurationStatus, evaluate_duration
from avp.frame_sampler import sample_times
from avp.manifest import write_manifest


class TestDurationGate(unittest.TestCase):
    def test_accept_boundary_30(self):
        d = evaluate_duration(30.0)
        self.assertTrue(d.accepted)
        self.assertEqual(d.status, DurationStatus.ACCEPTED)

    def test_accept_under(self):
        for v in (0.0, 0.1, 1.0, 10.0, 29.999):
            with self.subTest(v=v):
                self.assertTrue(evaluate_duration(v).accepted)

    def test_reject_over_30(self):
        for v in (30.001, 30.1, 31.0, 60.0, 120.0):
            with self.subTest(v=v):
                d = evaluate_duration(v)
                self.assertFalse(d.accepted)
                self.assertEqual(d.status, DurationStatus.REJECTED_TOO_LONG)
                self.assertEqual(d.limit, DURATION_LIMIT_SECONDS)
                self.assertGreater(d.seconds, DURATION_LIMIT_SECONDS)

    def test_reject_invalid(self):
        for v in (float("nan"), float("inf"), -1.0, -0.01):
            with self.subTest(v=v):
                d = evaluate_duration(v)
                self.assertEqual(d.status, DurationStatus.REJECTED_INVALID)


class TestFrameSampler(unittest.TestCase):
    def test_times_ordered_within_duration(self):
        for duration in (1.0, 10.0, 30.0):
            times = sample_times(duration)
            self.assertGreaterEqual(len(times), 1)
            self.assertLessEqual(len(times), MAX_FRAMES)
            for i, t in enumerate(times):
                self.assertGreaterEqual(t, 0.0)
                self.assertLessEqual(t, duration)
                if i:
                    self.assertGreater(t, times[i - 1])

    def test_never_exceeds_max_frames(self):
        # high fps request still capped
        times = sample_times(30.0, fps=100.0, max_frames=MAX_FRAMES)
        self.assertLessEqual(len(times), MAX_FRAMES)
        self.assertEqual(len(times), MAX_FRAMES)

    def test_default_fps_30s_is_60_or_less(self):
        times = sample_times(30.0, fps=DEFAULT_SAMPLE_FPS)
        # 0..29.5 step 0.5 => ~60 samples (capped at MAX_FRAMES)
        self.assertLessEqual(len(times), MAX_FRAMES)
        self.assertEqual(times[0], 0.0)

    def test_short_clip(self):
        times = sample_times(1.0)
        self.assertEqual(times[0], 0.0)
        self.assertLessEqual(len(times), MAX_FRAMES)
        self.assertTrue(all(t <= 1.0 for t in times))


class TestDebugLog(unittest.TestCase):
    def test_enable_writes_file(self):
        import tempfile
        from avp import debug_log

        with tempfile.TemporaryDirectory() as td:
            path = debug_log.set_enabled(True, log_directory=td)
            self.assertTrue(os.path.isfile(path))
            debug_log.log("hello-operation")
            debug_log.set_enabled(False)
            with open(path, encoding="utf-8") as fh:
                text = fh.read()
            self.assertIn("hello-operation", text)
            self.assertIn("DISABLED", text)


class TestManifest(unittest.TestCase):
    def test_write_manifest(self):
        import tempfile

        with tempfile.TemporaryDirectory() as td:
            path = write_manifest(
                td,
                "/tmp/source.mov",
                2.5,
                [(1, 0.0, "frame-0001.jpg"), (2, 0.5, "frame-0002.jpg")],
                platform="test",
            )
            self.assertTrue(os.path.isfile(path))
            with open(path, encoding="utf-8") as fh:
                text = fh.read()
            self.assertIn("frame-0001.jpg", text)
            self.assertIn("debugging", text.lower())
            self.assertIn("index\ttimestamp_seconds\tfilename", text)


class TestExportGateBeforeWrite(unittest.TestCase):
    """Ensure export_video calls shipped gate and writes nothing when too long."""

    def test_reject_writes_zero_frames(self):
        import tempfile
        from avp.export import ExportError, export_video

        class LongBackend:
            name = "test"

            def probe_duration(self, input_path: str) -> float:
                return 45.0

            def extract_frames(self, *args, **kwargs):
                raise AssertionError("extract_frames must not be called when too long")

        with tempfile.TemporaryDirectory() as td:
            # create dummy input file path existence check needs a file
            src = os.path.join(td, "long.mov")
            open(src, "wb").close()
            out = os.path.join(td, "out")
            with self.assertRaises(ExportError) as ctx:
                export_video(src, out, backend=LongBackend())
            self.assertEqual(ctx.exception.code, "too_long")
            # no png frames
            if os.path.isdir(out):
                frames = [
                    f
                    for f in os.listdir(out)
                    if f.startswith("frame-")
                ]
                self.assertEqual(frames, [])

    def test_accept_calls_extract_after_gate(self):
        import tempfile
        from avp.export import export_video
        from avp.manifest import frame_filename

        class ShortBackend:
            name = "test"
            called = False

            def probe_duration(self, input_path: str) -> float:
                return 2.0

            def extract_frames(self, input_path, times, output_directory, **kwargs):
                ShortBackend.called = True
                for i, _t in enumerate(times, start=1):
                    path = os.path.join(output_directory, frame_filename(i))
                    # stub file (not a real image; stills step tolerates this)
                    with open(path, "wb") as fh:
                        fh.write(b"stub-frame")
                return list(times)

        with tempfile.TemporaryDirectory() as td:
            src = os.path.join(td, "short.mov")
            open(src, "wb").close()
            out = os.path.join(td, "out")
            result = export_video(src, out, backend=ShortBackend())
            self.assertTrue(ShortBackend.called)
            self.assertGreater(result.frame_count, 0)
            self.assertTrue(os.path.isfile(result.manifest_path))
            frames = sorted(
                f for f in os.listdir(out) if f.startswith("frame-")
            )
            self.assertEqual(len(frames), result.frame_count)

    def test_caller_supplied_out_preserves_preexisting_on_failure(self):
        """Skeptic: -o dir must not rmtree pre-existing user files on extract failure."""
        import tempfile
        from avp.export import ExportError, export_video
        from avp.manifest import frame_filename

        class FailAfterWriteBackend:
            name = "test"

            def probe_duration(self, input_path: str) -> float:
                return 1.0

            def extract_frames(self, input_path, times, output_directory, **kwargs):
                # Write one partial frame then fail
                path = os.path.join(output_directory, frame_filename(1))
                with open(path, "wb") as fh:
                    fh.write(b"\x89PNG\r\n\x1a\n" + b"\x00" * 8)
                raise RuntimeError("simulated extract failure")

        with tempfile.TemporaryDirectory() as td:
            src = os.path.join(td, "short.mov")
            with open(src, "wb") as fh:
                fh.write(b"x")
            out = os.path.join(td, "out")
            os.makedirs(out)
            keep = os.path.join(out, "preexisting.txt")
            with open(keep, "w", encoding="utf-8") as fh:
                fh.write("do-not-delete")
            with self.assertRaises(RuntimeError):
                export_video(src, out, backend=FailAfterWriteBackend())
            self.assertTrue(os.path.isfile(keep), "preexisting.txt must survive")
            with open(keep, encoding="utf-8") as fh:
                self.assertEqual(fh.read(), "do-not-delete")
            # Partial product frames should be cleaned; user file remains
            frames = [f for f in os.listdir(out) if f.startswith("frame-")]
            self.assertEqual(frames, [])

    def test_fresh_run_dir_removed_on_failure(self):
        """Auto-created run directories may be rmtree'd entirely on failure."""
        import tempfile
        from avp.export import export_video
        from avp.manifest import frame_filename

        class FailBackend:
            name = "test"

            def probe_duration(self, input_path: str) -> float:
                return 1.0

            def extract_frames(self, input_path, times, output_directory, **kwargs):
                path = os.path.join(output_directory, frame_filename(1))
                with open(path, "wb") as fh:
                    fh.write(b"stub")
                raise RuntimeError("boom")

        with tempfile.TemporaryDirectory() as td:
            src = os.path.join(td, "short.mov")
            with open(src, "wb") as fh:
                fh.write(b"x")
            # Force default_output_root under td via monkeypatch
            import avp.export as exp

            old = exp.default_output_root
            exp.default_output_root = lambda: td
            try:
                with self.assertRaises(RuntimeError):
                    export_video(src, None, backend=FailBackend())
                # Only source file should remain under td (run subdir removed)
                names = set(os.listdir(td))
                self.assertIn("short.mov", names)
                # no leftover frame stills in any subdir
                for root, _dirs, files in os.walk(td):
                    for f in files:
                        self.assertFalse(
                            f.startswith("frame-"), f"leftover {f} in {root}"
                        )
            finally:
                exp.default_output_root = old


if __name__ == "__main__":
    unittest.main()
