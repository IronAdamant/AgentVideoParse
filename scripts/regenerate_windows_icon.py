"""Regenerate assets/icon.ico (and logo-256.png) from logo.png.

Small Explorer sizes get a tight content crop so the mark stays readable
on dark Windows shells (full transparent pad collapses to a black blob at 16–32px).
"""
from __future__ import annotations

import io
import struct
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
SRC = ASSETS / "logo.png"


def content_bbox(im: Image.Image, alpha_thresh: int = 8) -> tuple[int, int, int, int]:
    a = im.split()[-1]
    bb = a.point(lambda p: 255 if p > alpha_thresh else 0).getbbox()
    if bb is None:
        return (0, 0, im.width, im.height)
    return bb


def square_crop(im: Image.Image, pad_frac: float = 0.06) -> Image.Image:
    """Crop to non-transparent content, pad slightly, force transparent square."""
    x0, y0, x1, y1 = content_bbox(im)
    w, h = x1 - x0, y1 - y0
    side = max(w, h)
    pad = int(round(side * pad_frac))
    side = side + pad * 2
    out = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    crop = im.crop((x0, y0, x1, y1))
    paste_x = int(round(side / 2 - w / 2))
    paste_y = int(round(side / 2 - h / 2))
    out.paste(crop, (paste_x, paste_y), crop)
    return out


def resize_high(im: Image.Image, size: int) -> Image.Image:
    return im.resize((size, size), Image.Resampling.LANCZOS)


def write_ico(path: Path, images: list[Image.Image]) -> None:
    """Multi-size ICO with PNG-compressed entries (Vista+)."""
    entries: list[tuple[int, int, bytes]] = []
    for im in images:
        if im.mode != "RGBA":
            im = im.convert("RGBA")
        buf = io.BytesIO()
        im.save(buf, format="PNG", optimize=True)
        data = buf.getvalue()
        w, h = im.size
        entries.append((0 if w >= 256 else w, 0 if h >= 256 else h, data))

    count = len(entries)
    offset = 6 + 16 * count
    parts: list[bytes] = [struct.pack("<HHH", 0, 1, count)]
    for w, h, data in entries:
        parts.append(struct.pack("<BBBBHHII", w, h, 0, 0, 1, 32, len(data), offset))
        offset += len(data)
    for _, _, data in entries:
        parts.append(data)
    path.write_bytes(b"".join(parts))
    print(f"Wrote {path} ({path.stat().st_size} bytes, {count} sizes)")


def main() -> int:
    if not SRC.is_file():
        print(f"missing {SRC}", file=sys.stderr)
        return 1

    im = Image.open(SRC).convert("RGBA")
    print("source", SRC.name, im.size, "corner", im.getpixel((0, 0)), "bbox", content_bbox(im))

    tight = square_crop(im, pad_frac=0.08)
    fullish = square_crop(im, pad_frac=0.12)
    print("tight", tight.size, "fullish", fullish.size)

    sizes_tight = [16, 24, 32, 48, 64]
    sizes_full = [128, 256]
    images = [resize_high(tight, s) for s in sizes_tight]
    images += [resize_high(fullish, s) for s in sizes_full]

    for ims in images:
        pix = list(ims.getdata())
        opaque = [p for p in pix if p[3] > 20]
        colorful = (
            sum(1 for p in opaque if sum(p[:3]) / 3 > 50) / len(opaque) if opaque else 0.0
        )
        print(
            f"  {ims.size[0]:>3}x{ims.size[1]:<3} opaque={len(opaque)/len(pix):.2f} "
            f"colorful={colorful:.2f}"
        )

    write_ico(ASSETS / "icon.ico", images)

    logo256 = resize_high(fullish, 256)
    logo256.save(ASSETS / "logo-256.png", format="PNG", optimize=True)
    print("Wrote logo-256.png", (ASSETS / "logo-256.png").stat().st_size)

    # Side-by-side preview on dark + light (like Explorer)
    prev = Image.new("RGBA", (sum(i.size[0] for i in images) + 8 * (len(images) + 1), 280), (40, 40, 42, 255))
    x = 8
    for ims in images:
        prev.paste(ims, (x, 8), ims)
        light = Image.new("RGBA", ims.size, (240, 240, 242, 255))
        light.alpha_composite(ims)
        prev.paste(light, (x, 150))
        x += ims.size[0] + 8
    preview_path = ROOT / "dist" / "_icon_preview.png"
    preview_path.parent.mkdir(parents=True, exist_ok=True)
    prev.save(preview_path)
    print("Preview", preview_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
