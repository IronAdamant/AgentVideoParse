@echo off
REM AgentVideoParse - one-click launcher for Windows.
REM Prefers the native portable GUI (dist\AgentVideoParse\AgentVideoParse.exe).
REM Falls back to Python/tkinter only if the native build is missing.
setlocal
cd /d "%~dp0"

set "NATIVE=%~dp0dist\AgentVideoParse\AgentVideoParse.exe"
if exist "%NATIVE%" (
  if "%~1"=="" (
    start "" "%NATIVE%"
    exit /b 0
  )
  "%NATIVE%" %*
  exit /b %ERRORLEVEL%
)

echo Native app not built yet. Building once...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build-windows-app.ps1"
if exist "%NATIVE%" (
  if "%~1"=="" (
    start "" "%NATIVE%"
    exit /b 0
  )
  "%NATIVE%" %*
  exit /b %ERRORLEVEL%
)

echo.
echo Build of native app failed. Falling back to Python GUI...
echo (Install Python 3 with tkinter, or fix the .NET SDK build — see START-HERE.md)
echo.
call "%~dp0bin\windows\run.bat" %*
exit /b %ERRORLEVEL%
