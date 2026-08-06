# Windows launchers

## One-click app (recommended)

Build once, then double-click — **no installer, no Python**:

```powershell
powershell -File .\scripts\build-windows-app.ps1
.\dist\AgentVideoParse\AgentVideoParse.exe
```

Or from the repo root:

```bat
AgentVideoParse.bat
```

That launches `dist\AgentVideoParse\AgentVideoParse.exe` (native WPF GUI).  
Copy the whole `dist\AgentVideoParse\` folder anywhere; double-click the `.exe`.

### CLI

```bat
dist\AgentVideoParse\AgentVideoParse.exe export path\to\short.mp4
dist\AgentVideoParse\AgentVideoParse.exe export path\to\short.mp4 -o C:\Temp\avp-out
dist\AgentVideoParse\AgentVideoParse.exe help
```

### Requirements (runtime)

- Windows 10/11 with inbox **.NET Framework 4.7.2+** (already present on modern Windows)
- Media Foundation codecs for common `.mp4` / `.mov` (system)

No NuGet packages, no pip installs, no vendored FFmpeg, no setup wizard.

---

## Python fallback (optional)

If the native app is not built, `AgentVideoParse.bat` falls back to these scripts:

```bat
bin\windows\run.bat
bin\windows\run.bat export path\to\short.mp4
bin\windows\run.ps1 test
```

Needs **Python 3** + tkinter on `PATH`. Media extract uses `backends\windows\AvpExtract.exe` (auto-built with `csc` when missing).
