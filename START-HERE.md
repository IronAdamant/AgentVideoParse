# Start here (no coding required)

**AgentVideoParse** turns a **short phone or screen video (30 seconds or less)** into a folder of **screenshots** so an AI coding assistant can see what was on screen.

### Easiest: download a Release

**Official support is Mac and Windows only.**

| Your computer | Download |
|---------------|----------|
| **Mac** (Apple Silicon) | [v1.1.2-macos](https://github.com/IronAdamant/AgentVideoParse/releases/tag/v1.1.2-macos) → unzip → double-click **AgentVideoParse.app** (no Python; ≤30s) |
| **Windows** | [v1.1.2-windows](https://github.com/IronAdamant/AgentVideoParse/releases/tag/v1.1.2-windows) → unzip → double-click **AgentVideoParse.exe** (no install, no Python; ≤30s) |

On **Mac** and **Windows**, the release app does **not** need Python.

**Linux:** not a primary product. The repo still has a Linux base under open source (MIT). If you use Linux, **fork the project** and build or adapt it for your distro — see [README.md](README.md#linux-fork-and-build-your-own). There is no maintained “double-click for every distro” app.

---

You do **not** need the Terminal for normal Mac/Windows use after that.

---

## What you will do (everyday use)

1. Record a short video of the bug (phone or screen recording) — **keep it under 30 seconds**.
2. Open AgentVideoParse (double-click, see below).
3. Click the big drop area and choose your video (or drop the file if your system supports it).
4. Wait until it finishes.
5. Click **Reveal in file manager** / **Reveal in Finder** / **Reveal in Explorer**.
6. Point your AI agent at that folder of images (or attach a few frames).

**If the video is longer than 30 seconds**, the app will refuse it on purpose (so the AI is not flooded with images). Record a shorter clip.

---

## One-time setup

### macOS (recommended: real Mac app — no Python)

**If you have a built app** (`dist/AgentVideoParse.app` — see below):

1. Open the project folder in Finder (or open `dist`).
2. Double-click **`AgentVideoParse.app`**.  
   - First time: right-click → **Open** → **Open** if macOS blocks it.  
   - Optional: drag the app into **Applications**.
3. In the window: click the big area → choose a video **≤ 30 seconds** → wait → **Reveal in Finder**.

**Build the app once** (developers / after clone):

```bash
# From the project folder (needs Xcode Command Line Tools)
./scripts/build-macos-app.sh
open dist/AgentVideoParse.app
```

**Fallback (Python GUI)** — only if you prefer not to build:

1. Install **Python 3** from [https://www.python.org/downloads/](https://www.python.org/downloads/)  
2. Double-click **`AgentVideoParse.command`**.

### Windows (recommended: portable .exe — no install, no Python)

**If you have a built app** (`dist\AgentVideoParse\AgentVideoParse.exe`):

1. Open that folder (or double-click **`AgentVideoParse.bat`** at the project root — it launches the same app).
2. Double-click **`AgentVideoParse.exe`**.  
   - If Windows SmartScreen warns, choose **More info** → **Run anyway** (only if you trust this project).  
   - No installer and no Python — copy the whole `dist\AgentVideoParse` folder anywhere and double-click.
3. In the window: click the big area → choose a video **≤ 30 seconds** → wait → **Reveal in Explorer**.

**Build the app once** (developers / after clone; needs [.NET SDK](https://dotnet.microsoft.com/download)):

```powershell
powershell -File .\scripts\build-windows-app.ps1
# then:
.\dist\AgentVideoParse\AgentVideoParse.exe
# or:
.\AgentVideoParse.bat
```

**Fallback (Python GUI)** — only if you prefer not to build the native app:

1. Install **Python 3** from [https://www.python.org/downloads/](https://www.python.org/downloads/) with **Add to PATH** and **tcl/tk**.
2. Run `bin\windows\run.bat` (or `AgentVideoParse.bat` if the native build is missing).

### Linux (not officially supported)

This start guide is for **Mac and Windows**. Linux users: fork the open-source repo and adapt the in-tree Linux base for your distro — details in [README.md](README.md#linux-fork-and-build-your-own).

---

## Using the window (GUI)

**Mac and Windows look the same** (unified product shell). Only the window chrome and “Reveal in Finder” vs “Reveal in Explorer” differ.

| Control | What it does |
|--------|----------------|
| Big drop / click area | Pick the video file |
| Output folder | Where screenshot folders are saved (defaults are fine) |
| **Debug logging** | Optional: writes a text log if something fails |
| **Open debug log** / **Copy log path** | Find that log to send to a helper |
| **Reveal…** | Opens the folder of screenshots |
| **Copy path** | Copies the folder path for pasting into an AI chat |
| **Appearance** (Dark / Light) | Dark is the default; choice is remembered |

Disclaimer at the top is always visible: **≤30 seconds**, **debugging only**, **open source / local**.

---

## Where the screenshots go

| Computer | Default place |
|----------|----------------|
| Mac | `Movies/AgentVideoParse/` |
| Windows | `Videos\AgentVideoParse\` |

Each run creates a **new subfolder** with `frame-0001.jpg`, `frame-0002.jpg`, … and a small `MANIFEST.txt`.

---

## Common problems (plain language)

| What you see | What to try |
|--------------|-------------|
| “python3 not found” / window flashes and closes | You are on a Python fallback path. Prefer the native Mac app or Windows `.exe`. Or install Python from python.org with **Add to PATH** (Windows) / Tcl/Tk, then re-open. |
| “tkinter” / GUI errors | Reinstall Python with Tcl/Tk options (fallback launchers only). Prefer the native Mac/Windows apps. |
| Video rejected as too long | Re-record under **30 seconds**. The app will not cut a long video. |
| Can’t read the video | Export a short **.mp4** or **.mov** from Photos/QuickTime/Phone, try again. |
| macOS blocks `.command` | Right-click → Open, or allow in Privacy & Security. Prefer **AgentVideoParse.app**. |
| Windows SmartScreen | More info → Run anyway (if you trust the download). |

---

## For people who prefer the keyboard (optional)

```bash
./AgentVideoParse                 # open GUI
./AgentVideoParse export my.mp4   # no GUI
./AgentVideoParse help
```

Windows:

```bat
AgentVideoParse.bat
AgentVideoParse.bat export my.mp4
dist\AgentVideoParse\AgentVideoParse.exe export my.mp4
```

---

## Privacy

Everything runs **on your computer**. Your video is **not uploaded** by AgentVideoParse.

---

## Still stuck?

1. Turn on **Debug logging** in the app, try once more, then **Copy log path** and open that file.  
2. Open an issue on GitHub: [IronAdamant/AgentVideoParse](https://github.com/IronAdamant/AgentVideoParse) with the log and your OS (**Mac** or **Windows**). Linux is community/fork territory — see the README.
