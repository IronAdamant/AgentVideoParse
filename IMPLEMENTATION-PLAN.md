# AgentVideoParse — Implementation Plan (v1)

**Status:** Plan only — **do not implement until a goal/execution command is run on this file.**  
**Audience:** Multi-agent swarm (3+ agents) + human review  
**Workspace:** `/Users/aron/Documents/coding_projects/AgentVideoParse`  
**Related basis:** `PROJECT-BASIS.md`, `README.md` (to be rewritten per this plan)  
**Plan version:** 1.1 — **cross-platform** (macOS, Windows, Linux)

---

## 0. Executive summary

Build **AgentVideoParse** as a **local, fully open-source desktop GUI application** for **macOS, Windows, and Linux** that:

1. Lets the user **drop a video file** (`.mov`, `.mp4`, and other common containers) into a clear drop zone.
2. **Hard-rejects** any video longer than **30.0 seconds** (no partial processing).
3. Extracts an **ordered set of still screenshots** (frame images) to a folder the user can hand to an AI coding agent.
4. Surfaces a **permanent disclaimer** that the file must be under 30s, and that this is a **debugging tool only**.
5. Ships with a **README** that states the 30s rule, debug-only purpose, full open-source nature, and **all three OS** support.

### Target platforms (v1 — all required)

| Platform | Support level | Notes |
|----------|---------------|--------|
| **macOS** | Required | Apple Silicon + Intel |
| **Windows** | Required | Windows 10 21H2+ / Windows 11 (x64; arm64 if practical) |
| **Linux** | Required | One primary desktop path: **X11 and/or Wayland** via system GUI toolkit; document tested distros (e.g. Ubuntu 22.04+, Fedora) |

Same product rules and UX intent on every OS. Implementation may use **platform-native media and GUI stacks** (see §0.2–§5), but behavior must match the shared core contracts.

### Non-negotiable constraints (product + engineering)

| ID | Constraint |
|----|------------|
| C1 | **Zero third-party *application* dependencies.** No vendored FFmpeg/OpenCV, no npm/pip/cargo/SPM/NuGet **packages pulled into the product**, no remote SDKs, no analytics SDKs. |
| C2 | **Allowed:** language standard libraries + **OS / distro system frameworks and libraries** only (see §2). Linking against OS media stacks is required for real video decode. |
| C3 | **Hard max duration: 30 seconds.** Longer → clear error; **do not** extract any frames. |
| C4 | **Local only.** No network required for core path; no upload. |
| C5 | **GUI-first UX:** drag-and-drop (and click-to-browse) is the primary interaction **on all platforms**. |
| C6 | **Output = still image files** (ordered), not a re-encoded video as the main deliverable. |
| C7 | **Purpose = debugging / agent review only** — stated in UI + README. |
| C8 | **Fully open source** — LICENSE + README statement. |
| C9 | **Cross-platform parity:** macOS, Windows, and Linux all implement the same duration gate, sampling policy, manifest format, disclaimer text, and output layout semantics. |

### 0.1 Why zero third-party deps still allows cross-platform video

Decoding `.mov` / H.264 / HEVC **without shipping a decoder** requires **each OS’s media stack** (or distro-provided system media libraries). That is **not** “add a third-party package to the repo”; it is the same class of dependency as linking against the OS windowing system.

| Approach | Allowed under C1–C2? | Cross-platform? |
|----------|----------------------|-----------------|
| Vendored FFmpeg binary / libav in repo | **No** | — |
| pip/npm/cargo package for decode | **No** | — |
| **macOS AVFoundation** (system) | **Yes** | macOS |
| **Windows Media Foundation** (system) | **Yes** | Windows |
| **Linux GStreamer 1.x** (distro system packages) | **Yes** — treated as OS media stack | Linux |
| Electron + node modules | **No** | — |
| Qt / Flutter / Avalonia via package managers | **No** (third-party app frameworks) | — |

**Locked strategy for v1:**  
**Shared pure-logic core** (duration gate, sampler, manifest, paths, error codes) + **three platform media backends** + **three thin native GUIs** (or one stdlib GUI shell with native backends — see §5). No third-party app frameworks.

### 0.2 Locked high-level stack

| Layer | Choice | Rationale |
|-------|--------|-----------|
| **Shared logic** | Language-portable **behavioral spec** + preferred single implementation language for core (see §5.1) | Identical gate/sampling/manifest on all OS |
| **macOS media** | **AVFoundation** / ImageIO | System only |
| **Windows media** | **Media Foundation** (`IMFSourceReader` / related) + WIC for PNG | System only |
| **Linux media** | **GStreamer 1.x** (system `.so` via distro packages) | Linux has no AVFoundation/MF equivalent; GStreamer is the standard system multimedia framework. **Do not vendor** GStreamer; document `apt`/`dnf` packages |
| **macOS GUI** | **SwiftUI** (or AppKit if needed) | System UI |
| **Windows GUI** | **WPF** or **WinUI 3** with **only** Windows SDK / inbox assemblies (no third-party NuGet UI kits) | System / SDK UI |
| **Linux GUI** | **GTK 4** (system) **or** **Python 3 + tkinter** (stdlib) calling a small native helper | Must be system/stdlib only |

> **Linux install note (README):** Runtime may require distro packages such as `gstreamer1.0-plugins-base`, `gstreamer1.0-plugins-good`, `gstreamer1.0-libav` (or equivalent) and GTK if using GTK. That is **OS package install**, not an app-vendored third-party dependency. Prefer plugins that maximize `.mp4`/`.mov` decode success on common distros; document failures for exotic codecs.

---

## 1. Product definition (what “done” means)

### 1.1 One-sentence product

**AgentVideoParse** is a local open-source desktop app for **macOS, Windows, and Linux**: drop a **≤30s** debug video → get an ordered folder of **frame screenshots** for AI agents; longer videos are rejected; debugging only.

### 1.2 Primary user journey (happy path)

1. User launches the app on their OS.
2. User sees:
   - App name / short purpose
   - **Disclaimer (always visible):** video must be under 30 seconds; tool is for debugging only; open source / local
   - Large **drop zone** (“Drop a video here or click to choose”)
3. User drops e.g. `repro.mov` / `repro.mp4`.
4. App:
   - Validates it can open the asset (platform backend)
   - Reads **duration**
   - If `duration > 30.0s` → **reject**; no frames written
   - If OK → shows progress, extracts ordered stills to an output folder
5. On success:
   - Shows path to output folder
   - Shows count of images + duration
   - Buttons: **Reveal in file manager**, **Copy path**, **Open folder**
   - Optional: small grid preview of first N thumbnails
6. User points a coding agent at that folder.

### 1.3 Platform-specific “reveal folder” actions

| OS | Action |
|----|--------|
| macOS | Reveal in Finder (`NSWorkspace`) |
| Windows | Open in Explorer (`explorer.exe /select,` or open directory) |
| Linux | `xdg-open` on the directory (or file manager if available); fail gracefully with path copy if no handler |

### 1.4 Failure journeys (must be explicit UX)

| Case | Behavior |
|------|----------|
| Duration > 30.0s | Block extraction; show error with measured duration; no frames |
| Unreadable / unsupported codec | Clear error; no crash |
| Zero video tracks | Clear error |
| Missing system media components (esp. Linux plugins) | Clear error: which packages/frameworks to install (README link) |
| Disk full / cannot write output | Clear error |
| User cancels mid-export | Stop cleanly; **delete partial** output directory |
| Empty drop / wrong file type | Gentle validation message |

### 1.5 Explicit non-goals (v1)

- Videos longer than 30s (including “process first 30s only”)
- Speech-to-text / audio analysis as a feature
- Cloud upload, accounts, telemetry SDKs
- **Vendoring** FFmpeg or shipping decoder binaries in the repo
- Third-party app package managers for runtime product code
- Full NLE / trim / color grade / export video
- Replacing Interpres or Live Captions tools
- Keyframe-only ML “best frame” AI
- Network license checks
- Mobile (iOS / Android)
- Browser-only version

---

## 2. Dependency policy (strict, multi-platform)

### 2.1 Forbidden (all platforms)

- Vendored **FFmpeg**, libav, OpenCV, libvpx, etc. in the repository or app bundle as redistributed blobs (unless already part of the OS — do not ship your own copy)
- npm / pip / cargo / SPM / NuGet **product** dependencies
- Electron, Tauri, CEF wrappers as the app shell
- Qt, Flutter, Avalonia, React Native Desktop as product UI (third-party frameworks)
- Analytics / crash SaaS SDKs
- Remote model APIs
- “Install via Homebrew/Chocolatey as the only way the app works” for a **bundled** codec kit

### 2.2 Allowed

| Platform | Allowed stacks |
|----------|----------------|
| **All** | Language standard library; project-local source only |
| **macOS** | Swift stdlib; SwiftUI/AppKit; AVFoundation; CoreMedia; CoreVideo; ImageIO; UniformTypeIdentifiers; Foundation |
| **Windows** | .NET (inbox / Windows SDK); WPF or WinUI; Media Foundation; Windows Imaging Component (WIC); Win32 APIs for shell/drag-drop as needed |
| **Linux** | C/C++ or Python stdlib; GTK 4 **system** libraries; GStreamer 1.x **system** libraries; POSIX filesystem APIs; `xdg-open` |
| **Shared core option** | Pure C99 / C11 or pure Python **stdlib-only** modules with **no** pip packages |

### 2.3 Definition of “zero third-party” for CI / agents

A change **fails** the dependency gate if:

1. Any lockfile pulls remote third-party packages into the **product** (e.g. `Package.resolved` remote URLs, `package.json`, `requirements.txt` with packages, `Cargo.toml` dependencies beyond empty, `*.csproj` `PackageReference` for non-system packages).
2. The repo vendors decoder binaries under e.g. `third_party/ffmpeg`.
3. README requires installing a **project-specific** dependency pack that is not an OS media stack (e.g. “download our patched FFmpeg”).

**Allowed README requirements:**

- Xcode / Windows SDK / build-essential / `libgstreamer` dev packages to **build**
- GStreamer runtime plugins to **run** on Linux
- Python 3 (if Linux UI uses tkinter) — language runtime, not a PyPI package

### 2.4 Verification scripts (implementers must add)

| Script | Role |
|--------|------|
| `scripts/check-no-third-party-deps.sh` | Grep/scan for lockfiles, vendored ffmpeg, PackageReference, SPM remotes, requirements.txt, etc. Portable `sh` + common Unix tools; on Windows run via Git Bash or provide `scripts/check-no-third-party-deps.ps1` equivalent |
| Optional CI matrix | Build/test core + smoke per OS when runners available |

---

## 3. Frame extraction policy (first principles — same on all OS)

### 3.1 Tension

- “Screenshots of each frame” vs agent vision budget  
- 30s × 60fps ≈ 1800 files is hostile to debug sessions  

### 3.2 Locked v1 policy (all platforms)

| Rule | Value |
|------|-------|
| **Duration gate** | Reject if `duration > 30.0` seconds (accept if `duration <= 30.0`) |
| **Default sampling** | **2 frames per second** (every 0.5s), include `t ≈ 0` |
| **Hard max stills** | **60** images max per successful run |
| **Order** | Strictly increasing presentation timestamps |
| **Dense “every frame”** | Not default; if ever added, still capped at 60 |

**Algorithm (default):**

```
duration = backend.probeDuration(path)
if duration > 30.0: reject (write nothing)
times = sampleTimes(duration, fps=2.0, maxFrames=60)
for each t in times:
  image = backend.extractFrame(path, t)
  write frame-XXXX.png
write MANIFEST.txt + README-FOR-AGENT.txt
```

### 3.3 Output layout (identical semantics all OS)

Default output root:

| OS | Default root |
|----|----------------|
| macOS | `~/Movies/AgentVideoParse/` |
| Windows | `%USERPROFILE%\Videos\AgentVideoParse\` (fallback: `%USERPROFILE%\AgentVideoParse\`) |
| Linux | `~/Videos/AgentVideoParse/` (fallback: `~/AgentVideoParse/` if `~/Videos` missing) |

Per-run directory:

```
<output-root>/<video-basename>-<yyyyMMdd-HHmmss>/
  frame-0001.png
  frame-0002.png
  ...
  MANIFEST.txt
  README-FOR-AGENT.txt
```

**MANIFEST.txt** (plain text, identical columns everywhere):

```
# AgentVideoParse manifest
# purpose: debugging / agent UI review only
# source: <absolute-or-normalized-path>
# duration_seconds: 12.34
# max_allowed_seconds: 30
# sample_fps: 2
# frame_count: 25
# platform: macos|windows|linux
# generated_at: ISO-8601

index	timestamp_seconds	filename
1	0.000	frame-0001.png
2	0.500	frame-0002.png
```

### 3.4 Image format

- Default: **PNG**  
- Encode via: ImageIO (macOS), WIC (Windows), GDK-Pixbuf / GStreamer PNG encoder / stb-free **system** path on Linux (e.g. GStreamer `pngenc` or GTK/cairo surface write). Prefer one documented path per backend.

---

## 4. GUI / UX specification (parity across OS)

### 4.1 Window

- Single primary window  
- Minimum ~520×560  
- Title: **AgentVideoParse**  
- Native look is fine; **layout and copy must match**

### 4.2 Layout (all platforms)

```
┌─────────────────────────────────────────────────────────┐
│  AgentVideoParse                                        │
│  Short debug video → ordered screenshots for AI agents  │
├─────────────────────────────────────────────────────────┤
│  ⚠ DISCLAIMER (always visible, non-dismissible banner)  │
│  • Video must be 30 seconds or shorter…                 │
│  • Debugging / agent review only…                       │
│  • Fully open source. Local only. No upload.            │
├─────────────────────────────────────────────────────────┤
│         [ Drop video here / click to choose ]           │
│  Output folder: <path>                    [Change]      │
│  Sampling: 2 fps · max 60 stills · max 30.0s            │
├─────────────────────────────────────────────────────────┤
│  Status / progress / errors                             │
│  [Reveal in file manager] [Copy path]                   │
├─────────────────────────────────────────────────────────┤
│  Footer: Open Source · Debug only · ≤30s · Win/Mac/Linux│
└─────────────────────────────────────────────────────────┘
```

### 4.3 Drag-and-drop

| OS | Mechanism |
|----|-----------|
| macOS | SwiftUI `.onDrop` / NSItemProvider file URLs |
| Windows | WPF/WinUI drag-drop of file paths |
| Linux | GTK `GtkDropTarget` / tkinter drop if using tk (may need platform DnD support; **click-to-browse must always work** if DnD is flaky) |

Accept common extensions: `.mov`, `.mp4`, `.m4v`, `.webm`, `.avi` (decode success is best-effort per backend).

### 4.4 Disclaimer

1. In-app permanent banner (all OS)  
2. On reject: restate 30s rule + measured duration  
3. README sections (§7)  
4. `README-FOR-AGENT.txt` in every output folder  

### 4.5 Canonical disclaimer text

```text
DISCLAIMER

• Your video file must be 30 seconds or shorter. Longer files are rejected; no frames are extracted.
• AgentVideoParse is a debugging tool for AI/agent UI review only. Do not use it as a general video editor or archival converter.
• This software is fully open source and runs locally on your computer (macOS, Windows, or Linux). It does not upload your video.
```

---

## 5. Architecture (cross-platform)

### 5.1 Preferred structure

```
AgentVideoParse/
  README.md
  LICENSE
  PROJECT-BASIS.md
  IMPLEMENTATION-PLAN.md
  scripts/
    check-no-third-party-deps.sh
    check-no-third-party-deps.ps1
    generate-fixtures/          # platform scripts using system media only
  shared/
    SPEC.md                     # behavioral spec for gate/sampler/manifest (source of truth)
    # Preferred: ONE pure implementation used by all hosts:
    core/                       # see language choice below
  backends/
    macos/                      # AVFoundation exporter + thin glue
    windows/                    # Media Foundation exporter + thin glue
    linux/                      # GStreamer exporter + thin glue
  ui/
    macos/                      # SwiftUI app
    windows/                    # WPF or WinUI app
    linux/                      # GTK app OR Python tkinter shell
  tests/
    shared/                     # pure tests for DurationGate + FrameSampler + Manifest
    integration/                # per-OS if needed
```

### 5.2 Shared core language choice (locked for implementers)

**Primary recommendation:** implement shared pure logic once in **C11** (`shared/core/`) with a tiny C ABI:

- `avp_duration_gate(double seconds, …)`
- `avp_sample_times(…)`
- `avp_write_manifest(…)`

Then each platform UI/backend links or P/Invokes / calls this core.

**Acceptable alternative** if swarm prefers less FFI: **duplicate pure logic** in each platform language **only if** `shared/SPEC.md` + identical golden tests are maintained (DurationGate / FrameSampler vectors in `tests/shared/vectors.json` or plain text — **no JSON library required**: use simple line-based vectors).

**Not allowed:** three divergent sampling policies.

### 5.3 Media backend interface (logical contract)

Every backend must implement:

```
probe(path) -> { durationSeconds, hasVideoTrack, error? }
extractFrames(path, times[], outputDir, progress_cb, cancel_cb) -> { files[], actualTimes[] }
```

Rules:

- Call duration gate **before** any frame write (UI and backend both enforce; backend is last line of defense).
- Apply orientation/transform when the platform provides it (macOS preferred transform; Windows MF / Linux caps as available).
- Thread-safe cancellation.

### 5.4 Platform backend notes

#### macOS (`backends/macos`)

- `AVURLAsset` duration  
- `AVAssetImageGenerator` at sampled times  
- `appliesPreferredTrackTransform = true`  
- PNG via ImageIO  

#### Windows (`backends/windows`)

- Media Foundation source reader  
- Duration from presentation descriptor / media type  
- Seek / grab RGB frames at sample times (document accuracy vs keyframes)  
- PNG via WIC  
- COM init / MF startup lifecycle correct on UI thread or MTA as required  

#### Linux (`backends/linux`)

- GStreamer pipeline for duration query (`gst_discoverer` or pad probes / `decodebin`)  
- Frame grab at timestamps (e.g. `appsink` + seek, or documented equivalent)  
- PNG encode without bundling libpng if possible via GStreamer `pngenc` + `filesink`, or system libpng **only if** it is a normal distro link (prefer GStreamer path to stay consistent)  
- Clear errors if `libav`/codec plugins missing  

### 5.5 UI layering

| Layer | Responsibility |
|-------|----------------|
| UI | Disclaimer, drop zone, browse dialog, progress, open folder, copy path |
| Orchestrator | Wire path → probe → gate → sample → extract → manifest |
| Backend | OS media only |
| Core | Pure policy + manifest formatting |

UI **must not** reimplement the 30s rule with different numbers.

### 5.6 Concurrency

- Background extraction on all platforms  
- UI thread for widgets only  
- Cancel mid-run  

---

## 6. Core algorithms (implementation contracts — OS-independent)

### 6.1 `DurationGate`

```
limit = 30.0
if duration is non-finite or < 0: rejectedInvalid
if duration > 30.0: rejectedTooLong
else: accepted
```

Unit-test: `0`, `0.1`, `29.999`, `30.0`, `30.001`, `60`, NaN, −1.

### 6.2 `FrameSampler`

```
fps = 2.0, maxFrames = 60
emit t = 0, 0.5, 1.0, … while t < duration (and t <= duration bound)
ensure count <= maxFrames (uniform thin if needed)
all times in [0, duration]
strictly increasing
```

### 6.3 Manifest writer

Stable UTF-8 text; tab-separated body; headers as comments.

### 6.4 Error codes (shared)

| Code | Meaning |
|------|---------|
| `too_long` | duration > 30 |
| `no_video_track` | no video |
| `unsupported` | cannot decode |
| `missing_system_media` | Linux plugins / MF / AVFoundation unavailable |
| `write_failed` | I/O |
| `cancelled` | user cancel |

User-visible strings in Appendix B (platform-neutral wording; “Finder/Explorer/file manager” adapted in UI).

---

## 7. README & licensing requirements

### 7.1 README.md mandatory sections

1. Title + one-liner  
2. **Fully open source** + LICENSE link  
3. **Platforms: macOS, Windows, Linux**  
4. **Hard limit: 30 seconds**  
5. **Debugging tool only**  
6. What it does / does not do  
7. **Zero third-party app dependencies** + OS media stacks explanation  
8. **Per-OS requirements** (build + runtime, including Linux GStreamer packages)  
9. **Build & run** for each OS  
10. Output layout + sampling defaults  
11. **Disclaimer** block (canonical text)  
12. Optional Interpres relation  
13. License  

### 7.2 LICENSE

- **MIT** default for v1  

### 7.3 Platform requirements table (must appear in README)

| OS | To run | To build |
|----|--------|----------|
| macOS | macOS 13+/14+ as chosen | Xcode |
| Windows | Windows 10/11 with Media Foundation (standard) | Visual Studio + Windows SDK |
| Linux | GStreamer 1.x + needed plugins; GUI libs | gcc/clang + dev packages for GStreamer/GTK (or Python 3 for tkinter UI) |

---

## 8. Testing strategy

### 8.1 Shared pure tests (run everywhere)

- DurationGate / FrameSampler / Manifest golden vectors  
- Prefer tests that run **without** video files  

### 8.2 Fixtures (per platform or shared binaries)

Generate short synthetic videos **using only system APIs** (no vendored FFmpeg in repo):

| Fixture | Duration | Purpose |
|---------|----------|---------|
| `short-1s` | ~1s | happy path |
| `short-10s` | ~10s | multi-frame |
| `edge-30s` | ≤30s | accept boundary |
| `long-31s` | >30s | **must reject**, zero frame files |

Generation scripts:

- macOS: AVFoundation writer script  
- Windows: Media Foundation / sink writer script  
- Linux: GStreamer `videotestsrc` + encoder pipeline via `gst-launch-1.0` **if** present as system tool (dev machine only), or C API in `scripts/generate-fixtures`

Commit small fixtures if generation is painful for CI.

### 8.3 Integration tests per backend

- Accept path writes N PNGs + manifest  
- Reject path creates no frames  
- Cancel path cleans partial dir  

### 8.4 Manual QA matrix (required before v1 done)

| Check | macOS | Windows | Linux |
|-------|-------|---------|-------|
| Drop/browse ≤30s → stills | ☐ | ☐ | ☐ |
| >30s reject, no frames | ☐ | ☐ | ☐ |
| Disclaimer visible | ☐ | ☐ | ☐ |
| Reveal folder / copy path | ☐ | ☐ | ☐ |
| Dep gate script clean | ☐ | ☐ | ☐ |
| README matches behavior | ☐ | ☐ | ☐ |

---

## 9. Build & packaging

### 9.1 Build entry points

| OS | Command (illustrative — finalize in README) |
|----|-----------------------------------------------|
| macOS | `xcodebuild -scheme AgentVideoParse -configuration Debug build` |
| Windows | `msbuild AgentVideoParse.sln /p:Configuration=Debug` or `dotnet build` **without** extra PackageReferences |
| Linux | `cmake --build build` or `meson compile` for native; or documented Python launch for tkinter UI + native `.so` backend |

### 9.2 Distribution (v1)

- Local build & run is enough  
- Optional zip of binaries **without** bundling FFmpeg  
- Store / notarization optional later  

### 9.3 Installers

- Out of scope for v1 beyond “open project and build” / simple script  

---

## 10. Multi-agent swarm execution plan (3+ agents)

> When a goal command executes this plan, **do not freestyle architecture**. Follow C1–C9 and shared SPEC.

### 10.1 Agent roles (recommended 4; minimum 3)

| Agent | Codename | Owns | Must not |
|-------|----------|------|----------|
| **A** | **Shared core + SPEC** | `shared/SPEC.md`, DurationGate, FrameSampler, ManifestWriter, pure tests, dep-check scripts | Platform GUI chrome |
| **B** | **Media backends** | macOS AVFoundation, Windows MF, Linux GStreamer exporters implementing the same interface | Change sampling constants without SPEC update |
| **C** | **GUI shells** | macOS + Windows + Linux UI parity (disclaimer, drop, progress, reveal) | Bypass duration gate |
| **D** | **Docs + fixtures + QA matrix** | README multi-OS, LICENSE, fixtures, manual QA results | Feature creep |

**If only 3 agents:** A = core; B = all backends; C = all UIs + README (D merged into A/C).

### 10.2 Parallelization graph

```
[Agent A] shared core + SPEC + pure tests + dep scripts
     │
     ├──────────────┬──────────────┐
     ▼              ▼              ▼
[Agent B macOS] [Agent B Win] [Agent B Linux]   (can be one agent sequential or three sub-agents)
     │              │              │
     └──────────────┼──────────────┘
                    ▼
        [Agent C] three UIs wire to backends + core
                    ▼
        [Agent D] fixtures, README, QA matrix on all OS
```

### 10.3 Frozen shared constants

```
DURATION_LIMIT_SECONDS = 30.0
DEFAULT_SAMPLE_FPS = 2.0
MAX_FRAMES = 60
```

### 10.4 Frozen logical export API

```
export(inputPath, outputDirectory) -> Result
  probe duration
  gate (must reject too long BEFORE writes)
  sample times
  extract frames
  write manifest + agent readme
```

### 10.5 Integration checklist (coordinator)

1. Same disclaimer string on all UIs + README  
2. Same gate/sampler behavior (shared tests pass on at least one CI host; vectors committed)  
3. macOS, Windows, Linux each: happy path + reject path  
4. Dep gate scripts pass  
5. No vendored FFmpeg  

---

## 11. Acceptance criteria (v1 ship gate)

### 11.1 Functional (each of macOS, Windows, Linux)

- [ ] Drop or choose a video via GUI  
- [ ] `duration <= 30s` → ordered PNGs + MANIFEST + README-FOR-AGENT  
- [ ] `duration > 30s` → clear error, **zero** frame files  
- [ ] Reveal/open folder + copy path work (or documented fallback on minimal Linux)  
- [ ] Progress or busy state during export  
- [ ] Orientation handled when platform metadata allows  

### 11.2 Policy / messaging

- [ ] Disclaimer always visible on all UIs  
- [ ] README: 30s, debug-only, open source, **three OS**, zero third-party app deps  
- [ ] Output agent readme states debug-only purpose  

### 11.3 Engineering

- [ ] No third-party product packages; no vendored FFmpeg  
- [ ] Shared pure tests for gate + sampler  
- [ ] Reject-path integration coverage on each backend  
- [ ] No network on core path  

### 11.4 Hard fail conditions

- Partial extraction of long videos  
- Shipping FFmpeg in-tree  
- SPM/npm/pip/cargo/NuGet product deps  
- macOS-only implementation presented as “done”  
- Missing disclaimer on any platform UI  

---

## 12. PR / commit sequencing

| PR | Title | Contents |
|----|-------|----------|
| PR1 | `chore: repo scaffold, LICENSE, SPEC, dep gates` | Layout, MIT, shared SPEC, check scripts |
| PR2 | `feat(core): duration gate, sampler, manifest` | Shared core + pure tests |
| PR3 | `feat(backend-macos): AVFoundation export` | macOS media |
| PR4 | `feat(backend-windows): Media Foundation export` | Windows media |
| PR5 | `feat(backend-linux): GStreamer export` | Linux media |
| PR6 | `feat(ui): macOS / Windows / Linux shells` | Three UIs wired to export |
| PR7 | `docs: multi-OS README + disclaimers` | Full README |
| PR8 | `test: fixtures + reject/accept matrix` | Fixtures + QA notes |

PRs 3–5 can proceed in parallel after PR2. PR6 depends on at least one backend; complete all three backends before calling v1 done.

---

## 13. Risk register

| Risk | Impact | Mitigation |
|------|--------|------------|
| Linux codec plugins missing | User cannot open phone `.mov` | README package list; clear `missing_system_media` error; test on Ubuntu with documented packages |
| MF seek accuracy | Wrong timestamps | Document tolerance; prefer accurate-as-possible; still ordered stills |
| Three UIs diverge | Product inconsistency | Shared copy constants file / SPEC; QA matrix |
| Swarm adds FFmpeg “just for Linux” | Violates C1 | Dep scripts + plan language |
| GTK vs tkinter scope | Delay | Pick **one** Linux UI path early (recommend **GTK4 system** for DnD quality; tkinter acceptable if GTK skill scarce) |
| Build matrix heavy | Slow CI | Pure tests always; media tests on available runners; manual matrix otherwise |
| HEVC licensing/codecs | Some files fail | Explicit unsupported message; suggest re-export short MP4 H.264 |

---

## 14. Open decisions (defaults locked; amend plan to change)

| Topic | v1 default |
|-------|------------|
| Sample rate | 2 fps |
| Max frames | 60 |
| Image format | PNG |
| License | MIT |
| Linux UI | GTK 4 (system) preferred; tkinter alternative documented |
| Linux media | GStreamer 1.x system |
| Windows UI | WPF (widely known, inbox) unless team standardizes on WinUI without extra packages |
| Shared core language | C11 ABI preferred |
| Min macOS | 14.0 recommended (13.0 if needed) |
| Min Windows | 10 21H2+ |
| Min Linux | Document one reference distro (Ubuntu 22.04 LTS) |

---

## 15. Coordinator instructions (goal runners)

1. Read this file + `PROJECT-BASIS.md`.  
2. **Ship all three OS** before calling v1 complete.  
3. **Never** vendor FFmpeg or add third-party app packages.  
4. **Never** “process first 30s only” for long videos.  
5. Keep disclaimer + sampling constants identical across platforms.  
6. Use §10 agent split; integrate via shared SPEC/core.  
7. Meet §11 on **macOS, Windows, and Linux**.  
8. Treat Linux GStreamer/GTK **system packages** as allowed OS dependencies; document them.  

---

## 16. Appendix A — Canonical disclaimer

```text
DISCLAIMER

• Your video file must be 30 seconds or shorter. Longer files are rejected; no frames are extracted.
• AgentVideoParse is a debugging tool for AI/agent UI review only. Do not use it as a general video editor or archival converter.
• This software is fully open source and runs locally on your computer (macOS, Windows, or Linux). It does not upload your video.
```

## 17. Appendix B — Example user-visible errors

| Code | Message |
|------|---------|
| too_long | `This video is {duration}s long. AgentVideoParse only accepts videos of 30 seconds or less (debugging sessions). No screenshots were created.` |
| no_video_track | `This file has no video track that can be read.` |
| unsupported | `Could not read this video with the system media stack on this OS. Try a short .mp4/.mov screen recording under 30 seconds.` |
| missing_system_media | `Required system media components are missing. On Linux, install GStreamer and the plugins listed in the README. On Windows, ensure Media Foundation is available. On macOS, use a supported OS version.` |
| write_failed | `Could not write screenshots to {path}. Check folder permissions and disk space.` |
| cancelled | `Export cancelled. Incomplete output was removed.` |

## 18. Appendix C — Platform media stack map

```
                    ┌─────────────────────┐
                    │  Shared Core (pure) │
                    │  gate / sample /    │
                    │  manifest           │
                    └──────────┬──────────┘
           ┌───────────────────┼───────────────────┐
           ▼                   ▼                   ▼
    ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
    │ macOS       │     │ Windows     │     │ Linux       │
    │ AVFoundation│     │ Media Found.│     │ GStreamer   │
    │ ImageIO     │     │ WIC         │     │ (system)    │
    └──────┬──────┘     └──────┬──────┘     └──────┬──────┘
           ▼                   ▼                   ▼
    ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
    │ SwiftUI     │     │ WPF/WinUI   │     │ GTK4/tkinter│
    └─────────────┘     └─────────────┘     └─────────────┘
```

## 19. Appendix D — Why not one Electron/FFmpeg binary

Electron + FFmpeg would be faster to unify but **violates** the zero third-party / no-vendored-decoder rule. This project deliberately trades single-codebase convenience for **auditable, local, OS-native** stacks on each platform—consistent with a debugging tool users may run on sensitive screen recordings.

## 20. Document control

| Field | Value |
|-------|--------|
| Plan version | **1.1** |
| Change from 1.0 | **macOS-only removed**; Windows + Linux required; multi-backend architecture; GStreamer/GTK as Linux system stack; swarm roles updated |
| Execution | **Not started** — await explicit implement/goal command |
| Primary artifact | `IMPLEMENTATION-PLAN.md` |

---

*End of implementation plan. Do not begin coding until an execution/goal command targets this document.*
