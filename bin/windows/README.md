# Windows launchers

Double-click **`AgentVideoParse.bat`** at the repo root for the portable GUI (Python + tkinter).

## One-liners

```bat
REM GUI
AgentVideoParse.bat
bin\windows\run.bat

REM CLI export
bin\windows\run.bat export path\to\short.mp4
bin\windows\run.bat export path\to\short.mp4 -o C:\Temp\avp-out

REM Disclaimer / tests
bin\windows\run.bat disclaimer
bin\windows\run.bat test
```

PowerShell equivalent:

```powershell
.\bin\windows\run.ps1
.\bin\windows\run.ps1 export path\to\short.mp4
.\bin\windows\run.ps1 export path\to\short.mp4 -o C:\Temp\avp-out
.\bin\windows\run.ps1 disclaimer
.\bin\windows\run.ps1 test
```

## Requirements

- **Python 3** on `PATH` (`py -3`, `python`, or `python3`) with **tkinter** for the GUI
- Windows 10/11 (Media Foundation for frame extract)
- Optional: `.NET Framework` `csc.exe` — launchers try a best-effort build of `backends\windows\AvpExtract.exe` if missing (non-fatal for GUI)

No NuGet packages, no pip installs, no vendored FFmpeg.

## What the launchers do

1. Resolve the repo root from the script location  
2. Set `PYTHONPATH=shared\core;<repo root>`  
3. Prefer `py -3`, then `python`, then `python3`  
4. No args → `ui\linux\app.py` (portable tkinter GUI; works on Windows)  
5. `export` / `disclaimer` → `python -m avp ...`  
6. `test` → core unit tests + `scripts\check-no-third-party-deps.ps1`
