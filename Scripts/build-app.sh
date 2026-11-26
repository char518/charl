#!/bin/bash
set -euo pipefail
ROOT="$(dirname "$0")/.."
cd "$ROOT"
CONFIG=debug
UNIVERSAL=0
for arg in "$@"; do
  case "$arg" in
    --release) CONFIG=release ;;
    --universal) CONFIG=release; UNIVERSAL=1 ;;
    *) printf 'Unknown option: %s\n' "$arg" >&2; exit 1 ;;
  esac
done
mkdir -p dist
if [ "$UNIVERSAL" -eq 1 ]; then
  swift build --product charl -c release --triple arm64-apple-macosx14.0
  swift build --product charl -c release --triple x86_64-apple-macosx14.0
  ARM="$(swift build -c release --triple arm64-apple-macosx14.0 --show-bin-path)/charl"
  INTEL="$(swift build -c release --triple x86_64-apple-macosx14.0 --show-bin-path)/charl"
  lipo -create "$ARM" "$INTEL" -output dist/charl-universal
  BIN=dist/charl-universal
else
  swift build --product charl -c "$CONFIG"
  BIN="$(swift build -c "$CONFIG" --show-bin-path)/charl"
fi
APP=dist/charl.app
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/charl"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"; fi
# 权限用途说明按语言取 InfoPlist.strings（系统弹窗读这个，不看代码里的 loc）
for lproj in Resources/*.lproj; do
  cp -R "$lproj" "$APP/Contents/Resources/"
done
SIGN_IDENTITY="${CHARL_SIGN_IDENTITY:-}"
if [ -z "$SIGN_IDENTITY" ] && security find-certificate -c "charl Local Development" >/dev/null 2>&1; then
  SIGN_IDENTITY="charl Local Development"
fi
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
codesign --force --sign "$SIGN_IDENTITY" --identifier com.charl.charl "$APP"
printf 'Built %s (%s)\n' "$APP" "$CONFIG"
lipo -info "$APP/Contents/MacOS/charl"
