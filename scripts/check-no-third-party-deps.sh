#!/usr/bin/env sh
# Fail if product third-party package deps or vendored decoders appear.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"
fail=0

log() { printf '%s\n' "$*"; }

check_absent() {
  pattern=$1
  msg=$2
  if find . -type f \
    ! -path './.git/*' \
    ! -path './.wikifier_staging/*' \
    ! -path '*/__pycache__/*' \
    2>/dev/null | head -1 >/dev/null; then
    :
  fi
  if find . -type f \
    ! -path './.git/*' \
    ! -path './.wikifier_staging/*' \
    ! -path '*/__pycache__/*' \
    \( -name 'package.json' -o -name 'Package.resolved' -o -name 'requirements.txt' \
       -o -name 'Cargo.toml' -o -name 'Pipfile' -o -name 'poetry.lock' \) \
    2>/dev/null | grep -q .; then
    log "FAIL: $msg (lock/package file present)"
    find . -type f \
      ! -path './.git/*' \
      ! -path './.wikifier_staging/*' \
      \( -name 'package.json' -o -name 'Package.resolved' -o -name 'requirements.txt' \
         -o -name 'Cargo.toml' -o -name 'Pipfile' -o -name 'poetry.lock' \)
    fail=1
  fi
}

# package manager manifests that pull remote product deps
for f in package.json Package.resolved requirements.txt Pipfile poetry.lock go.mod; do
  if find . -name "$f" ! -path './.git/*' ! -path './.wikifier_staging/*' 2>/dev/null | grep -q .; then
    log "FAIL: found $f (third-party product deps not allowed)"
    fail=1
  fi
done

# Cargo.toml only allowed if it has no dependencies section with crates — ban any Cargo.toml for product
if find . -name 'Cargo.toml' ! -path './.git/*' 2>/dev/null | grep -q .; then
  log "FAIL: Cargo.toml present"
  fail=1
fi

# NuGet PackageReference in csproj (ignore comments)
if grep -R --include='*.csproj' 'PackageReference' . 2>/dev/null \
  | grep -v '.git' \
  | grep -v '^\s*//' \
  | grep -v '<!--' \
  | grep -q .; then
  log "FAIL: NuGet PackageReference found in csproj"
  grep -R --include='*.csproj' 'PackageReference' . 2>/dev/null | grep -v '<!--' | head -20
  fail=1
fi

# SPM remote
if grep -R 'XCRemoteSwiftPackageReference\|url:.*github' --include='*.pbxproj' --include='Package.swift' . 2>/dev/null | grep -q .; then
  log "FAIL: Swift remote package reference found"
  fail=1
fi

# Vendored ffmpeg / libav
if find . -type d \( -iname 'ffmpeg' -o -iname 'libav*' \) ! -path './.git/*' 2>/dev/null | grep -q .; then
  log "FAIL: vendored ffmpeg/libav directory"
  fail=1
fi
if find . -type f \( -iname 'ffmpeg' -o -iname 'ffmpeg.exe' -o -iname 'libavcodec*' \) ! -path './.git/*' 2>/dev/null | grep -q .; then
  log "FAIL: vendored ffmpeg binary/lib"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  log "deps-scan: FAILED"
  exit 1
fi
log "deps-scan: OK (no third-party product package deps / vendored ffmpeg)"
exit 0
