# Test fixtures

Synthetic solid-color videos for accept/reject tests. Generated with **system AVFoundation** only (`scripts/generate_fixtures_macos.swift`) — no FFmpeg.

| File | Duration | Purpose |
|------|----------|---------|
| `short-2s.mp4` | ~2s | happy path |
| `short-10s.mp4` | ~10s | multi-frame |
| `edge-30s.mp4` | ~30s | accept boundary |
| `long-31s.mp4` | ~31s | hard reject |

Regenerate on macOS:

```bash
swiftc -O -framework AVFoundation -framework CoreMedia -framework CoreVideo -framework AppKit \
  scripts/generate_fixtures_macos.swift -o /tmp/genfix
/tmp/genfix fixtures 2 && mv fixtures/clip-2s.mp4 fixtures/short-2s.mp4
# etc.
```
