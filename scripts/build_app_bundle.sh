#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="${APP_NAME:-CaptureLingo}"
APP_DISPLAY_NAME="${APP_DISPLAY_NAME:-Capture Lingo}"
SOURCE_BIN_NAME="${SOURCE_BIN_NAME:-CaptureLingo}"
APP_VERSION="${APP_VERSION:-1.0.0}"
BUNDLE_ID="${BUNDLE_ID:-com.capturelingo.app}"
BUILD_DIR=".build/release"
BIN_PATH="$BUILD_DIR/$SOURCE_BIN_NAME"
APP_DIR="$BUILD_DIR/$APP_NAME.app"

export HOME="$ROOT_DIR/.local-home"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT_DIR/.build/module-cache"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"
mkdir -p "$HOME/Library/Caches/org.swift.swiftpm" "$HOME/.cache/clang/ModuleCache" "$SWIFTPM_MODULECACHE_OVERRIDE"

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  swift build -c release
fi

if [[ ! -x "$BIN_PATH" ]]; then
  echo "error: release binary not found at $BIN_PATH" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>ja</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>12.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
EOF

printf "APPL????" > "$APP_DIR/Contents/PkgInfo"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true
fi

echo "Created: $APP_DIR"
