# AgentVideoParse Windows launcher (PowerShell)
#   No args          -> portable GUI (ui\linux\app.py, tkinter)
#   export <video> [-o dir]
#   disclaimer | test | help
# No NuGet / no third-party packages.

$ErrorActionPreference = "Stop"

# Repo root: this script lives at <root>\bin\windows\run.ps1
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = (Resolve-Path (Join-Path $ScriptDir "..\..")).Path
Set-Location $Root

$env:PYTHONPATH = "$(Join-Path $Root 'shared\core');$Root"
if ($env:PYTHONPATH_EXTRA) {
    $env:PYTHONPATH = "$($env:PYTHONPATH);$($env:PYTHONPATH_EXTRA)"
}

function Find-Python {
    $candidates = @(
        @{ Exe = "py"; Args = @("-3") },
        @{ Exe = "python"; Args = @() },
        @{ Exe = "python3"; Args = @() }
    )
    $oldEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    foreach ($c in $candidates) {
        $cmd = Get-Command $c.Exe -ErrorAction SilentlyContinue
        if (-not $cmd) { continue }
        try {
            $probe = @("-c", "import sys; raise SystemExit(0 if sys.version_info[0] >= 3 else 1)")
            if ($c.Args.Count -gt 0) {
                & $c.Exe @($c.Args) @probe 1>$null 2>$null
            } else {
                & $c.Exe @probe 1>$null 2>$null
            }
            if ($LASTEXITCODE -eq 0) {
                $ErrorActionPreference = $oldEap
                return @{ Exe = $c.Exe; PrefixArgs = $c.Args }
            }
        } catch {
            # try next candidate
        }
    }
    $ErrorActionPreference = $oldEap
    return $null
}

function Invoke-Python {
    param(
        [Parameter(Mandatory = $true)]$Py,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$PyArgs
    )
    $all = @()
    if ($Py.PrefixArgs) { $all += $Py.PrefixArgs }
    if ($PyArgs) { $all += $PyArgs }
    & $Py.Exe @all
    return $LASTEXITCODE
}

function Try-Build-Helper {
    $helper = Join-Path $Root "backends\windows\AvpExtract.exe"
    $cs = Join-Path $Root "backends\windows\AvpExtract.cs"
    if (Test-Path -LiteralPath $helper) { return }
    if (-not (Test-Path -LiteralPath $cs)) { return }

    Write-Host "AvpExtract.exe missing - attempting best-effort build with csc..."

    $csc = $null
    if ($env:CSC -and (Test-Path -LiteralPath $env:CSC)) {
        $csc = $env:CSC
    } else {
        $windir = if ($env:WINDIR) { $env:WINDIR } else { "C:\Windows" }
        $candidates = @(
            (Join-Path $windir "Microsoft.NET\Framework64\v4.0.30319\csc.exe"),
            (Join-Path $windir "Microsoft.NET\Framework\v4.0.30319\csc.exe")
        )
        foreach ($c in $candidates) {
            if (Test-Path -LiteralPath $c) { $csc = $c; break }
        }
        if (-not $csc) {
            $onPath = Get-Command csc -ErrorAction SilentlyContinue
            if ($onPath) { $csc = $onPath.Source }
        }
    }

    if (-not $csc) {
        Write-Host "  csc.exe not found; skipping helper build (GUI still opens; export needs helper on Windows)."
        return
    }

    try {
        $cscArgs = @(
            "/nologo", "/optimize+", "/target:exe",
            "/out:$helper",
            "/r:System.dll", "/r:System.Core.dll",
            "/r:PresentationCore.dll", "/r:WindowsBase.dll", "/r:System.Xaml.dll",
            $cs
        )
        & $csc @cscArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Build of AvpExtract.exe failed (non-fatal for GUI)."
        } else {
            Write-Host "  Built $helper"
        }
    } catch {
        Write-Host "  Build of AvpExtract.exe failed (non-fatal for GUI): $_"
    }
}

function Show-Help {
    param([string]$PyLabel)
    Write-Host @"
AgentVideoParse - Windows launcher

Usage:
  run.ps1                         Launch portable GUI (tkinter)
  run.ps1 gui                     Same as no args
  run.ps1 export <video> [-o dir] Export frames via host backend
  run.ps1 disclaimer              Print product disclaimer
  run.ps1 test                    Run core tests + deps scan
  run.ps1 help                    This message

Repo root: $Root
Python:    $PyLabel
PYTHONPATH=$($env:PYTHONPATH)

Double-click AgentVideoParse.bat at the repo root for the GUI.
"@
}

# --- main ---
$Py = Find-Python
if (-not $Py) {
    Write-Host "ERROR: Python 3 not found."
    Write-Host "Install Python 3 from https://www.python.org/ or the Microsoft Store,"
    Write-Host "and ensure 'py -3', 'python', or 'python3' is on PATH."
    exit 1
}

$pyLabel = if ($Py.PrefixArgs -and $Py.PrefixArgs.Count -gt 0) {
    "$($Py.Exe) $($Py.PrefixArgs -join ' ')"
} else {
    "$($Py.Exe)"
}

Try-Build-Helper

$argv = @($args)
if ($argv.Count -eq 0 -or ($argv.Count -ge 1 -and $argv[0] -ieq "gui")) {
    Write-Host "Launching AgentVideoParse GUI..."
    $rc = Invoke-Python $Py (Join-Path $Root "ui\linux\app.py")
    exit $rc
}

$cmd = $argv[0]
switch -Regex ($cmd) {
    '^(?i:help|-h|--help|/\?)$' {
        Show-Help $pyLabel
        exit 0
    }
    '^(?i:disclaimer)$' {
        $rc = Invoke-Python $Py @("-m", "avp", "disclaimer")
        exit $rc
    }
    '^(?i:export)$' {
        if ($argv.Count -lt 2) {
            Write-Host "ERROR: export requires a video path."
            Write-Host "Usage: run.ps1 export <video> [-o dir]"
            exit 1
        }
        # Forward full arg list to python -m avp
        $rc = Invoke-Python $Py (@("-m", "avp") + $argv)
        exit $rc
    }
    '^(?i:test)$' {
        Write-Host "Running shared core tests..."
        $rc = Invoke-Python $Py @((Join-Path $Root "shared\core\tests\test_core.py"), "-v")
        $deps = Join-Path $Root "scripts\check-no-third-party-deps.ps1"
        if (Test-Path -LiteralPath $deps) {
            Write-Host ""
            Write-Host "Running third-party deps scan..."
            & powershell -NoProfile -ExecutionPolicy Bypass -File $deps
            if ($LASTEXITCODE -ne 0) { $rc = 1 }
        }
        exit $rc
    }
    default {
        Write-Host "Unknown command: $cmd"
        Write-Host ""
        Show-Help $pyLabel
        exit 1
    }
}
