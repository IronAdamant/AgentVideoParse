@echo off
REM AgentVideoParse - double-click to launch the portable GUI (tkinter).
REM Also forwards CLI args to bin\windows\run.bat when run from a console.
setlocal
cd /d "%~dp0"
call "%~dp0bin\windows\run.bat" %*
exit /b %ERRORLEVEL%
