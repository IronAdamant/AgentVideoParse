"""Structural tests for committed logo / app icon assets (no third-party deps beyond stdlib+optional PIL)."""

from __future__ import annotations

import struct
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
ASSETS = REPO / "assets"


class TestLogoAssets(unittest.TestCase):
    def test_primary_logo_is_square_png(self):
        logo = ASSETS / "logo.png"
        self.assertTrue(logo.is_file(), "assets/logo.png must exist")
        data = logo.read_bytes()
        self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
        w, h = struct.unpack(">II", data[16:24])
        self.assertEqual(w, h)
        self.assertGreaterEqual(w, 256)

    def test_icon_variants_exist(self):
        for name in ("icon.png", "logo-512.png", "logo-256.png"):
            self.assertTrue((ASSETS / name).is_file(), name)

    def test_readme_references_logo(self):
        readme = (REPO / "README.md").read_text(encoding="utf-8")
        self.assertIn("assets/logo.png", readme)

    def test_no_bright_watermark_corner(self):
        """Bottom-right corner must stay dark (no Grok-style light watermark glyphs)."""
        try:
            from PIL import Image
        except ImportError:
            self.skipTest("Pillow not available for pixel inspection")

        for name in ("logo.png", "icon.png", "logo-512.png", "logo-256.png"):
            path = ASSETS / name
            im = Image.open(path).convert("RGB")
            w, h = im.size
            # sample bottom-right 18% x 12%
            box = (int(w * 0.82), int(h * 0.88), w, h)
            crop = im.crop(box)
            pixels = list(crop.getdata())
            n = len(pixels)
            mean = sum(sum(p) / 3 for p in pixels) / n
            bright = sum(1 for p in pixels if sum(p) / 3 > 120) / n
            self.assertLess(mean, 60, f"{name} corner mean too bright: {mean}")
            self.assertLess(bright, 0.02, f"{name} bright watermark-like pixels: {bright}")


if __name__ == "__main__":
    unittest.main()
