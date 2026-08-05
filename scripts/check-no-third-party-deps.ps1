# Windows equivalent of check-no-third-party-deps.sh
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root
$fail = $false

function Fail($msg) {
  Write-Host "FAIL: $msg"
  $script:fail = $true
}

$bannedNames = @("package.json", "Package.resolved", "requirements.txt", "Pipfile", "poetry.lock", "Cargo.toml", "go.mod")
Get-ChildItem -Recurse -File | Where-Object {
  $_.FullName -notmatch '\\\.git\\' -and $bannedNames -contains $_.Name
} | ForEach-Object { Fail "found $($_.FullName)" }

Get-ChildItem -Recurse -Filter *.csproj | ForEach-Object {
  if (Select-String -Path $_.FullName -Pattern "PackageReference" -Quiet) {
    Fail "PackageReference in $($_.FullName)"
  }
}

if (Get-ChildItem -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object {
  $_.Name -match '^(ffmpeg|libav)' -and $_.FullName -notmatch '\\\.git\\'
}) { Fail "vendored ffmpeg/libav directory" }

if ($fail) { Write-Host "deps-scan: FAILED"; exit 1 }
Write-Host "deps-scan: OK"
exit 0
