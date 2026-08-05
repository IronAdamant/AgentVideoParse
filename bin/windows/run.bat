@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ---------------------------------------------------------------------------
REM AgentVideoParse Windows launcher (batch)
REM   No args          -> portable GUI (ui\linux\app.py, tkinter)
REM   export <video> [-o dir]
REM   disclaimer | test | help
REM ---------------------------------------------------------------------------

REM Repo root: this script lives at <root>\bin\windows\run.bat
set "SCRIPT_DIR=%~dp0"
REM strip trailing backslash for nicer joins, then go up two levels
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
for %%I in ("%SCRIPT_DIR%\..\..") do set "ROOT=%%~fI"

cd /d "%ROOT%"

set "PYTHONPATH=%ROOT%\shared\core;%ROOT%"
if defined PYTHONPATH_EXTRA set "PYTHONPATH=%PYTHONPATH%;%PYTHONPATH_EXTRA%"

call :find_python
if errorlevel 1 exit /b 1

REM Best-effort: build AvpExtract.exe if missing (do not hard-fail GUI)
call :try_build_helper

if "%~1"=="" goto :gui

if /i "%~1"=="help" goto :help
if /i "%~1"=="-h" goto :help
if /i "%~1"=="--help" goto :help
if /i "%~1"=="/?" goto :help

if /i "%~1"=="test" goto :test
if /i "%~1"=="disclaimer" goto :disclaimer
if /i "%~1"=="export" goto :export
if /i "%~1"=="gui" goto :gui

echo Unknown command: %~1
echo.
goto :help_and_fail

:gui
echo Launching AgentVideoParse GUI...
%PY% "%ROOT%\ui\linux\app.py"
exit /b %ERRORLEVEL%

:export
if "%~2"=="" (
  echo ERROR: export requires a video path.
  echo Usage: run.bat export ^<video^> [-o dir]
  exit /b 1
)
REM Forward: export <video> [-o dir] ... to python -m avp
%PY% -m avp %*
exit /b %ERRORLEVEL%

:disclaimer
%PY% -m avp disclaimer
exit /b %ERRORLEVEL%

:test
echo Running shared core tests...
%PY% "%ROOT%\shared\core\tests\test_core.py" -v
set "TEST_RC=%ERRORLEVEL%"
if exist "%ROOT%\scripts\check-no-third-party-deps.ps1" (
  echo.
  echo Running third-party deps scan...
  powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\check-no-third-party-deps.ps1"
  if errorlevel 1 set "TEST_RC=1"
)
exit /b %TEST_RC%

:help
call :print_help
exit /b 0

:help_and_fail
call :print_help
exit /b 1

:print_help
echo AgentVideoParse - Windows launcher
echo.
echo Usage:
echo   run.bat                         Launch portable GUI (tkinter^)
echo   run.bat gui                     Same as no args
echo   run.bat export ^<video^> [-o dir]  Export frames via host backend
echo   run.bat disclaimer              Print product disclaimer
echo   run.bat test                    Run core tests + deps scan
echo   run.bat help                    This message
echo.
echo Repo root: %ROOT%
echo Python:    %PY%
echo PYTHONPATH=%PYTHONPATH%
echo.
echo Double-click AgentVideoParse.bat at the repo root for the GUI.
exit /b 0

REM ---------------------------------------------------------------------------
:find_python
REM Prefer py -3, then python, then python3
set "PY="

py -3 -c "import sys; raise SystemExit(0 if sys.version_info[0] >= 3 else 1)" >nul 2>&1
if not errorlevel 1 (
  set "PY=py -3"
  goto :python_ok
)

python -c "import sys; raise SystemExit(0 if sys.version_info[0] >= 3 else 1)" >nul 2>&1
if not errorlevel 1 (
  set "PY=python"
  goto :python_ok
)

python3 -c "import sys; raise SystemExit(0 if sys.version_info[0] >= 3 else 1)" >nul 2>&1
if not errorlevel 1 (
  set "PY=python3"
  goto :python_ok
)

echo ERROR: Python 3 not found.
echo Install Python 3 from https://www.python.org/ or the Microsoft Store,
echo and ensure "py -3", "python", or "python3" is on PATH.
exit /b 1

:python_ok
exit /b 0

REM ---------------------------------------------------------------------------
:try_build_helper
set "HELPER=%ROOT%\backends\windows\AvpExtract.exe"
set "HELPER_CS=%ROOT%\backends\windows\AvpExtract.cs"
if exist "%HELPER%" exit /b 0
if not exist "%HELPER_CS%" exit /b 0

echo AvpExtract.exe missing - attempting best-effort build with csc...

set "CSC_EXE="
if defined CSC if exist "%CSC%" (
  set "CSC_EXE=%CSC%"
  goto :have_csc
)

if exist "%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe" (
  set "CSC_EXE=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
  goto :have_csc
)
if exist "%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe" (
  set "CSC_EXE=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
  goto :have_csc
)
where csc >nul 2>&1
if not errorlevel 1 (
  for /f "delims=" %%C in ('where csc 2^>nul') do (
    set "CSC_EXE=%%C"
    goto :have_csc
  )
)

echo   csc.exe not found; skipping helper build (GUI still opens; export needs helper on Windows^).
exit /b 0

:have_csc
"%CSC_EXE%" /nologo /optimize+ /target:exe /out:"%HELPER%" ^
  /r:System.dll /r:System.Core.dll /r:PresentationCore.dll /r:WindowsBase.dll /r:System.Xaml.dll ^
  "%HELPER_CS%"
if errorlevel 1 (
  echo   Build of AvpExtract.exe failed (non-fatal for GUI^).
  exit /b 0
)
echo   Built %HELPER%
exit /b 0
