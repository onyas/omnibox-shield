#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Omnibox Shield"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"

swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/.build/release/omnibox-shield" "$MACOS_DIR/omnibox-shield"
cp "$ROOT_DIR/packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(date +%Y%m%d%H%M%S)" "$CONTENTS_DIR/Info.plist"
swift "$ROOT_DIR/scripts/make_app_icon.swift" "$RESOURCES_DIR/AppIcon.icns"
chmod +x "$MACOS_DIR/omnibox-shield"
codesign --force --deep --sign - "$APP_DIR"

echo "Built app: $APP_DIR"
echo "Open it with: open \"$APP_DIR\""
