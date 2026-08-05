# Start here (no coding required)

**AgentVideoParse** turns a **short phone or screen video (30 seconds or less)** into a folder of **screenshots** so an AI coding assistant can see what was on screen.

You do **not** need the Terminal for normal use. You only need to do a **one-time setup** (install Python), then **double-click** to open the app.

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

### macOS

1. Install **Python 3** from [https://www.python.org/downloads/](https://www.python.org/downloads/)  
   - Use the official installer.  
   - On the install screen, leave options that install **Tcl/Tk** / GUI support enabled if shown.
2. Download this project (GitHub **Code → Download ZIP**, then unzip).
3. In Finder, open the unzipped folder.
4. Double-click **`AgentVideoParse.command`**.  
   - The first time, macOS may say it can’t open an app from the internet.  
   - Right-click → **Open** → **Open**, or: System Settings → Privacy & Security → allow it.
5. A window appears: choose your video and go.

### Windows

1. Install **Python 3** from [https://www.python.org/downloads/](https://www.python.org/downloads/)  
   - **Important:** check **“Add python.exe to PATH”** on the first installer screen.  
   - Leave **tcl/tk and IDLE** enabled if listed.
2. Download this project (GitHub **Code → Download ZIP**, then unzip).
3. Open the unzipped folder.
4. Double-click **`AgentVideoParse.bat`**.  
   - If Windows SmartScreen warns, choose **More info** → **Run anyway** (only if you trust this project).
5. A window appears: choose your video and go.

### Linux (simple desktop)

1. Install Python 3 and the GUI toolkit (Ubuntu/Debian example):

   ```bash
   sudo apt install python3 python3-tk
   ```

   For video reading you also need GStreamer (once):

   ```bash
   sudo apt install gstreamer1.0-tools gstreamer1.0-plugins-base \
     gstreamer1.0-plugins-good gstreamer1.0-libav
   ```

2. Download / clone this project and open a file manager in the folder.
3. Double-click **`AgentVideoParse`** if your desktop allows running scripts, **or** right-click → Run as program.  
   If nothing happens, open Terminal in the folder and run:

   ```bash
   ./AgentVideoParse
   ```

---

## Using the window (GUI)

| Control | What it does |
|--------|----------------|
| Big drop / click area | Pick the video file |
| Output folder | Where screenshot folders are saved (defaults are fine) |
| **Debug logging** | Optional: writes a text log if something fails |
| **Open debug log** / **Copy log path** | Find that log to send to a helper |
| **Reveal…** | Opens the folder of screenshots |
| **Copy path** | Copies the folder path for pasting into an AI chat |

Disclaimer at the top is always visible: **≤30 seconds**, **debugging only**, **open source / local**.

---

## Where the screenshots go

| Computer | Default place |
|----------|----------------|
| Mac | `Movies/AgentVideoParse/` |
| Windows | `Videos\AgentVideoParse\` |
| Linux | `Videos/AgentVideoParse/` (or `AgentVideoParse` in your home folder) |

Each run creates a **new subfolder** with `frame-0001.png`, `frame-0002.png`, … and a small `MANIFEST.txt`.

---

## Common problems (plain language)

| What you see | What to try |
|--------------|-------------|
| “python3 not found” / window flashes and closes | Install Python from python.org and **re-open** the launcher. On Windows, reinstall with **Add to PATH**. |
| “tkinter” / GUI errors | Reinstall Python with Tcl/Tk options. On Linux: `sudo apt install python3-tk`. |
| Video rejected as too long | Re-record under **30 seconds**. The app will not cut a long video. |
| Can’t read the video | Export a short **.mp4** or **.mov** from Photos/QuickTime/Phone, try again. |
| macOS blocks `.command` | Right-click → Open, or allow in Privacy & Security. |
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
```

---

## Privacy

Everything runs **on your computer**. Your video is **not uploaded** by AgentVideoParse.

---

## Still stuck?

1. Turn on **Debug logging** in the app, try once more, then **Copy log path** and open that file.  
2. Open an issue on GitHub: [IronAdamant/AgentVideoParse](https://github.com/IronAdamant/AgentVideoParse) with the log and your OS (Mac / Windows / Linux).
