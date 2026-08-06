# Assets

## Logo / app icon

| File | Size | Use |
|------|------|-----|
| [`logo.png`](logo.png) | 1024×1024 | Primary project logo & app icon source |
| [`icon.png`](icon.png) | 1024×1024 | Same as primary (icon alias) |
| [`logo-512.png`](logo-512.png) | 512×512 | Medium icon |
| [`logo-256.png`](logo-256.png) | 256×256 | Small icon / in-app header (Windows WPF resource) |
| [`icon.ico`](icon.ico) | multi-size | Windows `.exe` ApplicationIcon |

**Motif:** short video (play tile) → ordered still frames (filmstrip stack) with an agent/circuit accent — matching AgentVideoParse’s job.

Generated with Imagine (`image_gen` + `image_edit` cleanup). macOS builds `.icns` via `scripts/build-macos-app.sh`; Windows embeds `logo-256.png` and uses `icon.ico` for the executable.
