# Assets

## Screenshots (README)

| File | Description |
|------|-------------|
| [`screenshots/macos-unified.png`](screenshots/macos-unified.png) | Shipping macOS GUI (dark, unified shell) |
| [`screenshots/windows-unified.png`](screenshots/windows-unified.png) | Shipping Windows GUI (dark, unified shell) |

## Logo / app icon

All committed logo files are the **corrected flat mark** (play tile + stills + agent eye) on a **transparent** background. There is **no** dark squircle / rounded plate baked into the bitmaps.

| File | Size | Use |
|------|------|-----|
| [`logo-mark.png`](logo-mark.png) | 414×268 RGBA | **Source mark** (native aspect). In-window GUI header on macOS & Windows |
| [`logo.png`](logo.png) | 1024×1024 RGBA | Primary square logo (mark centered, transparent pad) — README / app icon source |
| [`icon.png`](icon.png) | 1024×1024 RGBA | Same as `logo.png` (icon alias) |
| [`logo-512.png`](logo-512.png) | 512×512 RGBA | Medium square |
| [`logo-256.png`](logo-256.png) | 256×256 RGBA | Small square / Windows window icon resource |
| [`icon.ico`](icon.ico) | multi-size (16–256) | Windows `.exe` ApplicationIcon |

**Motif:** short video (play tile) → ordered still frames (filmstrip stack) with an agent/circuit accent.

macOS builds `.icns` from `logo.png` via `scripts/build-macos-app.sh` and ships `LogoMark.png` for the GUI header. Windows embeds `logo-mark.png` (header) + `logo-256.png` (window icon) and uses `icon.ico` for the executable.

### Regenerating the Windows `.ico`

Explorer uses **tiny** icon slots (16–32px). If `icon.ico` is a naive downscale of the full 1024² pad, the mark collapses to a near-black blob on dark shells. After changing `logo.png`, regenerate:

```bash
python scripts/regenerate_windows_icon.py
```

That rewrites `icon.ico` (tight content crop for small sizes, full framing for 128/256) and refreshes `logo-256.png`, then rebuild with `scripts/build-windows-app.ps1`.

OS chrome (Dock / taskbar) may still *mask* square icons with a system shape; that is the platform, not a plate in our artwork.
