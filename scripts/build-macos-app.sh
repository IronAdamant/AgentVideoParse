#!/usr/bin/env bash
# Build a double-clickable AgentVideoParse.app (SwiftUI + AVFoundation, no Python runtime).
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
SRC_DIR="$ROOT/macos/AgentVideoParse/Sources"
INFO="$ROOT/macos/AgentVideoParse/Info.plist"
DIST="$ROOT/dist"
APP="$DIST/AgentVideoParse.app"
BIN="$APP/Contents/MacOS/AgentVideoParse"
RES="$APP/Contents/Resources"
ICONSET="$ROOT/macos/icon.iconset"
ICNS="$RES/AppIcon.icns"
LOGO="$ROOT/assets/logo.png"

echo "==> Building AgentVideoParse.app"

rm -rf "$APP"
mkdir -p "$DIST" "$APP/Contents/MacOS" "$RES"

# --- App icon (.icns) from assets/logo.png (flat mark on transparent square; no baked plate) ---
if [[ -f "$LOGO" ]]; then
  echo "==> Generating AppIcon.icns from logo.png"
  rm -rf "$ICONSET"
  mkdir -p "$ICONSET"
  sips -z 16 16 "$LOGO" --out "$ICONSET/icon_16x16.png" >/dev/null
  sips -z 32 32 "$LOGO" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$LOGO" --out "$ICONSET/icon_32x32.png" >/dev/null
  sips -z 64 64 "$LOGO" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$LOGO" --out "$ICONSET/icon_128x128.png" >/dev/null
  sips -z 256 256 "$LOGO" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$LOGO" --out "$ICONSET/icon_256x256.png" >/dev/null
  sips -z 512 512 "$LOGO" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$LOGO" --out "$ICONSET/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$LOGO" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
  iconutil -c icns "$ICONSET" -o "$ICNS"
  sips -z 256 256 "$LOGO" --out "$RES/AppIcon.png" >/dev/null
else
  echo "warning: no assets/logo.png — building without custom icon" >&2
fi

# Native-aspect mark for the in-window header (same art family as logo.png).
MARK="$ROOT/assets/logo-mark.png"
if [[ -f "$MARK" ]]; then
  cp "$MARK" "$RES/LogoMark.png"
elif [[ -f "$LOGO" ]]; then
  cp "$LOGO" "$RES/LogoMark.png"
  echo "warning: no assets/logo-mark.png — using logo.png for header" >&2
else
  echo "warning: no logo assets — GUI header will be text-only" >&2
fi

# --- Compile Swift sources ---
SDK=$(xcrun --sdk macosx --show-sdk-path)
ARCH=$(uname -m)
TARGET="${ARCH}-apple-macos13.0"
# shellcheck disable=SC2206
SOURCES=( "$SRC_DIR"/*.swift )

echo "==> Compiling for $TARGET"
xcrun swiftc -O \
  -parse-as-library \
  -sdk "$SDK" \
  -target "$TARGET" \
  "${SOURCES[@]}" \
  -o "$BIN" \
  -framework SwiftUI \
  -framework AppKit \
  -framework AVFoundation \
  -framework CoreMedia \
  -framework CoreGraphics \
  -framework ImageIO \
  -framework UniformTypeIdentifiers

chmod +x "$BIN"
cp "$INFO" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

if command -v codesign >/dev/null 2>&1; then
  echo "==> Ad-hoc codesign"
  codesign --force --deep --sign - "$APP" 2>/dev/null || true
fi

echo ""
echo "Built: $APP"
echo "Open with: open \"$APP\""
echo "Or drag to /Applications."
ls -la "$APP/Contents/MacOS/"
file "$BIN"
