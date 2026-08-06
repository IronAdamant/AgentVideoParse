# Build a double-clickable AgentVideoParse.exe (WPF + system media, no Python runtime).
# Output: dist\AgentVideoParse\AgentVideoParse.exe  (portable folder — not an installer)
# Requires: .NET SDK with Windows Desktop support (dotnet). Runtime: .NET Framework 4.7.2+ (inbox on Win10/11).

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Proj = Join-Path $Root "ui\windows\AgentVideoParse.csproj"
$Dist = Join-Path $Root "dist\AgentVideoParse"
$OutExe = Join-Path $Dist "AgentVideoParse.exe"

Write-Host "==> Building AgentVideoParse Windows app (one-click portable)"
Write-Host "    Project: $Proj"
Write-Host "    Output:  $Dist"

if (-not (Test-Path -LiteralPath $Proj)) {
    Write-Error "Project not found: $Proj"
}

$dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
if (-not $dotnet) {
    Write-Error "dotnet SDK not found. Install .NET SDK from https://dotnet.microsoft.com/download"
}

# Clean dist target (stop a running app if it locks the exe)
Get-Process -Name "AgentVideoParse" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 300
if (Test-Path -LiteralPath $Dist) {
    try {
        Remove-Item -LiteralPath $Dist -Recurse -Force -ErrorAction Stop
    } catch {
        Write-Host "warning: could not fully clear dist (file in use?); publishing over existing files..."
    }
}
if (-not (Test-Path -LiteralPath $Dist)) {
    New-Item -ItemType Directory -Path $Dist | Out-Null
}

# Framework-dependent publish: single small exe + deps next to it.
# No installer, no self-extracting setup — unzip/copy folder and double-click.
Write-Host "==> dotnet publish (net472, Release)"
& dotnet publish $Proj `
    -c Release `
    -o $Dist `
    /p:DebugType=None `
    /p:DebugSymbols=false

if ($LASTEXITCODE -ne 0) {
    Write-Error "dotnet publish failed with exit $LASTEXITCODE"
}

if (-not (Test-Path -LiteralPath $OutExe)) {
    Write-Error "Expected exe missing: $OutExe"
}

# Copy a short README into dist so release zips are self-explanatory
$readme = @"
AgentVideoParse for Windows
===========================

Double-click **AgentVideoParse.exe** — no installer, no Python.

Requirements (already on Windows 10/11):
  - .NET Framework 4.7.2 or later (inbox)
  - Media Foundation codecs for common .mp4/.mov

Usage:
  1. Double-click AgentVideoParse.exe
  2. Drop or choose a video that is 30 seconds or shorter
  3. Click **Reveal in Explorer** for the screenshots folder

CLI (optional):
  AgentVideoParse.exe export path\to\short.mp4
  AgentVideoParse.exe export path\to\short.mp4 -o C:\Temp\avp-out

Output default: %USERPROFILE%\Videos\AgentVideoParse\

Privacy: everything runs locally; videos are not uploaded.
"@
Set-Content -LiteralPath (Join-Path $Dist "README.txt") -Value $readme -Encoding UTF8

# Also place a root-level convenience launcher if building in-repo
$rootShortcut = Join-Path $Root "AgentVideoParse.exe"
# Do not copy exe to root (keeps git clean); bat launcher will find dist\

Write-Host ""
Write-Host "Built: $OutExe"
Write-Host "One-click: double-click that file (or AgentVideoParse.bat at repo root)."
Get-ChildItem $Dist | Format-Table Name, Length -AutoSize
