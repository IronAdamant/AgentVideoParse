# AgentVideoParse

<p align="center">
  <img src="assets/logo.png" alt="AgentVideoParse logo" width="160" height="160" />
</p>

**Local, fully open-source** desktop helper for **macOS and Windows**: drop a **short debug video (max 30 seconds)** and get an **ordered folder of frame screenshots** for AI/coding agents.

> Agents read still images well but struggle to “watch” video. AgentVideoParse turns a **≤30s** clip into a small set of ordered stills. Longer videos are **rejected** (nothing is extracted).

**Supported platforms:** **macOS** and **Windows** (native apps, releases, and ongoing product focus).  
**Linux:** not a primary product target. A **Linux base** remains in the repo (`ui/linux/`, `backends/linux/`, shared core). Because the project is **fully open source (MIT)**, Linux users can **fork this repository** and build or adapt a version for the distro they use. There is **no maintained Linux release** and **no promise** of out-of-the-box support across distros.

**Logo / app icon:** flat transparent mark — [`assets/logo-mark.png`](assets/logo-mark.png) (native aspect) and square [`assets/logo.png`](assets/logo.png) (1024×1024), plus [`assets/icon.png`](assets/icon.png), [`assets/logo-512.png`](assets/logo-512.png), [`assets/logo-256.png`](assets/logo-256.png), [`assets/icon.ico`](assets/icon.ico).

See [PROJECT-BASIS.md](PROJECT-BASIS.md) for product origin and [IMPLEMENTATION-PLAN.md](IMPLEMENTATION-PLAN.md) for architecture (historical plan; product support is macOS + Windows).

---

## Debug logging (macOS / Windows GUIs)

Every supported GUI has **Debug logging**:

1. Turn on **Debug logging**
2. Run an export (or reproduce a failure)
3. Use **Open debug log** / **Copy log path** to extract the text log

Logs go under (local only, never uploaded):

| OS | Default log folder |
|----|--------------------|
| macOS | `~/Movies/AgentVideoParse/logs/` |
| Windows | `%USERPROFILE%\Videos\AgentVideoParse\logs\` |

CLI (shared core): `AVP_DEBUG=1` or `AVP_DEBUG_LOG=/path/to/file.log python3 -m avp export …`

---

## Downloads (GitHub Releases)

Official releases for the **supported** platforms:

| OS | Release | What’s inside |
|----|---------|----------------|
| **macOS** (Apple Silicon) | [v1.1.2-macos](https://github.com/IronAdamant/AgentVideoParse/releases/tag/v1.1.2-macos) | Double-click **AgentVideoParse.app** (no Python; ≤30s; dark UI default; flat logo) |
| **Windows** | [v1.1.2-windows](https://github.com/IronAdamant/AgentVideoParse/releases/tag/v1.1.2-windows) | Unzip → double-click **AgentVideoParse.exe** (no install / no Python; ≤30s; dark UI default) |

All releases: [github.com/IronAdamant/AgentVideoParse/releases](https://github.com/IronAdamant/AgentVideoParse/releases)

Older Linux-tagged archives may still appear under Releases for historical reasons; they are **not** a supported product channel. Prefer forking the source if you want Linux.

---

## For non-technical users (recommended)

**→ Read [START-HERE.md](START-HERE.md)** — plain-language install + double-click instructions (**Mac / Windows**).

### macOS app (recommended on Mac — no Python)

```bash
./scripts/build-macos-app.sh   # once after clone (needs Xcode CLT)
open dist/AgentVideoParse.app  # or double-click in Finder
```

Drag **`dist/AgentVideoParse.app`** to **Applications** if you like. First open: right-click → **Open** if Gatekeeper blocks it.

Then: choose a video **≤ 30 seconds** → **Reveal in Finder** for the screenshots folder.

### Windows app (recommended on Windows — no Python)

```powershell
powershell -File .\scripts\build-windows-app.ps1   # once after clone (needs .NET SDK)
.\dist\AgentVideoParse\AgentVideoParse.exe         # or double-click / AgentVideoParse.bat
```

Portable folder: copy `dist\AgentVideoParse\` anywhere and double-click **AgentVideoParse.exe**. No installer.

---

## Run (technical / CLI)

| OS | App / double-click | CLI |
|----|--------------------|-----|
| **macOS** | `dist/AgentVideoParse.app` | `dist/AgentVideoParse.app/Contents/MacOS/AgentVideoParse export clip.mp4` |
| **Windows** | `dist\AgentVideoParse\AgentVideoParse.exe` | `dist\AgentVideoParse\AgentVideoParse.exe export clip.mp4` |

```bash
./scripts/build-macos-app.sh
open dist/AgentVideoParse.app
# CLI through the app binary:
dist/AgentVideoParse.app/Contents/MacOS/AgentVideoParse export fixtures/short-2s.mp4
```

Mac app: **SwiftUI + AVFoundation** only (no Python). Windows app: **WPF + MediaPlayer** only (no Python).

---

## Fully open source

This project is released under the **MIT License** — see [LICENSE](LICENSE).  
It runs **only on your computer**. It does **not** upload your video.

---

## Platforms

| OS | Status | Media stack (system only) | GUI |
|----|--------|---------------------------|-----|
| **macOS** | **Supported** | AVFoundation + ImageIO | Native SwiftUI app (`macos/`, `ui/macos`); optional Python/tkinter fallback |
| **Windows** | **Supported** | WPF **MediaPlayer** (inbox) + WIC JPEG encode | Native WPF app (`ui/windows` → `dist\AgentVideoParse\AgentVideoParse.exe`); optional Python/tkinter fallback |
| **Linux** | **Community / fork** — not a primary supported product | GStreamer 1.x base in-tree (`backends/linux`, optional `avp_gst`) | Base tkinter shell (`ui/linux/app.py`) — adapt for your distro |

### Linux (fork and build your own)

Linux is **optional**. The repo keeps a **Linux base** (shared pure-Python core + GStreamer backend sketch + tkinter GUI) so anyone can:

1. **Fork** [IronAdamant/AgentVideoParse](https://github.com/IronAdamant/AgentVideoParse)  
2. Install **your distro’s** Python/Tk and GStreamer packages  
3. Run or package `ui/linux/app.py` / `./AgentVideoParse` for **your** environment  

There is **no** commitment to multi-distro packaging, CI, or official Linux releases. Maintainers focus on **macOS and Windows**.

---

## Hard limit: 30 seconds

- Videos **longer than 30.0 seconds are rejected**.
- **No partial processing** (we do **not** extract only the first 30 seconds).
- Reason: longer clips produce too many images and overwhelm agent debug sessions.

Default sampling: **2 frames per second**, hard max **60** stills (a full 30s clip is at most 60 images at 2 fps).  
Stills are **agent-friendly JPEGs** (long edge ≤ **1280px**) so folders stay small enough to hand to an LLM.

---

## Debugging tool only

AgentVideoParse is for **debugging / AI agent UI review only**.

**Do not** use it as:

- a general video editor  
- an archival or production media converter  
- a long-form video analysis suite  

---

## Zero third-party application dependencies

Product code uses:

- **Python 3 standard library** for shared core (duration gate, sampler, manifest, export orchestration)
- **OS system frameworks only** for decode and native UI  
  - macOS: AVFoundation, SwiftUI  
  - Windows: Media Foundation / WPF (inbox), no NuGet `PackageReference`  
  - Linux base (community): GStreamer system packages if you build the in-tree backend yourself

**Not used:** vendored FFmpeg, npm/pip/cargo product packages, Electron, Qt-via-packages, analytics SDKs.

Dependency gate:

```bash
sh scripts/check-no-third-party-deps.sh
# Windows: powershell -File scripts/check-no-third-party-deps.ps1
```

---

## Disclaimer

```
DISCLAIMER

• Your video file must be 30 seconds or shorter. Longer files are rejected; no frames are extracted.
• AgentVideoParse is a debugging tool for AI/agent UI review only. Do not use it as a general video editor or archival converter.
• This software is fully open source and runs locally on your computer (macOS, Windows, or Linux). It does not upload your video.
```

The same text appears as a **permanent banner** in the **macOS and Windows** GUIs. (Wording may still mention Linux because the codebase retains a Linux base for forks.)

---

## What it does

1. You drop or choose a short `.mov` / `.mp4` (or similar).  
2. The app probes duration with the **system** media stack.  
3. If duration **> 30s** → clear error, **zero** frame files.  
4. If OK → writes ordered `frame-0001.png` … plus `MANIFEST.txt` and `README-FOR-AGENT.txt`.

Default output roots (supported platforms):

| OS | Path |
|----|------|
| macOS | `~/Movies/AgentVideoParse/` |
| Windows | `%USERPROFILE%\Videos\AgentVideoParse\` |

---

## Build & run

### Shared core tests (any OS with Python 3)

```bash
cd /path/to/AgentVideoParse
PYTHONPATH=shared/core:. python3 -m unittest shared.core.tests.test_core -v
# or:
PYTHONPATH=shared/core:. python3 shared/core/tests/test_core.py -v
```

### CLI export (uses host OS backend)

```bash
export PYTHONPATH="shared/core:."
python3 -m avp export /path/to/short.mp4
python3 -m avp disclaimer
```

### macOS

1. **Native app** (recommended):

```bash
./scripts/build-macos-app.sh
open dist/AgentVideoParse.app
```

2. **Portable GUI** (tkinter fallback — needs Python 3 + Tk):

```bash
PYTHONPATH=shared/core:. python3 ui/linux/app.py
```

3. **Native SwiftUI** sources: `macos/` and `ui/macos/` (system frameworks only).

### Windows

**Native one-click app** (recommended — no Python):

```powershell
powershell -File .\scripts\build-windows-app.ps1
.\dist\AgentVideoParse\AgentVideoParse.exe
.\dist\AgentVideoParse\AgentVideoParse.exe export fixtures\short-2s.mp4
```

Requires Windows 10/11 with Media Foundation (standard) and .NET Framework 4.7.2+ (inbox).  
Build needs the .NET SDK once; the published folder is portable (not an installer).

**Optional Python path** (shared core + `AvpExtract` helper):

```bat
bin\windows\run.bat export short.mp4
bin\windows\run.bat
```

### Linux (community — fork / self-build)

Not an official support target. Starting points in-tree: `backends/linux/`, `ui/linux/app.py`, `bin/linux/run`. Expect to install **your** distro’s Python/Tk and GStreamer packages and fix path/codec issues yourself (or with an AI assistant). See [Platforms](#platforms).

---

## Output layout

```
frame-0001.png
frame-0002.png
...
MANIFEST.txt          # index → timestamp → filename
README-FOR-AGENT.txt  # debug-only purpose note
```

---

## Repository layout

```
shared/core/avp/     # shipped pure core + export orchestrator
backends/macos|windows|linux/
ui/macos|windows|linux/
scripts/check-no-third-party-deps.*
fixtures/            # generated short/long test videos (optional)
```

---

## License

MIT — [LICENSE](LICENSE).
