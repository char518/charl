#!/bin/bash
set -euo pipefail
ROOT="$(dirname "$0")/.."
cd "$ROOT"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"

# 1) 构建 Universal app（x86_64 + arm64）
bash Scripts/build-app.sh --universal

# 2) 若提供 Developer ID，则用其重签并加 hardened runtime + 时间戳
IDENTITY="${CHARL_SIGN_IDENTITY:-}"
if [ -n "$IDENTITY" ]; then
  codesign --force --deep --options runtime --timestamp \
    --sign "$IDENTITY" --identifier com.charl.charl dist/charl.app
fi
codesign --verify --deep --strict dist/charl.app

# 3) 打包 DMG（卷图标 + Applications 拖入链接 + 双语文档）
rm -rf dist/dmg-stage dist/charl-rw.dmg
mkdir -p dist/dmg-stage
cp -R dist/charl.app dist/dmg-stage/charl.app
cp README.md README.zh-CN.md dist/dmg-stage/
ln -s /Applications dist/dmg-stage/Applications
cp Resources/AppIcon.icns dist/dmg-stage/.VolumeIcon.icns

hdiutil create -srcfolder dist/dmg-stage -volname "charl" -fs HFS+ -format UDRW -o dist/charl-rw.dmg -quiet
mkdir -p /tmp/charl-dmg-mount
hdiutil attach dist/charl-rw.dmg -nobrowse -mountpoint /tmp/charl-dmg-mount -quiet
SetFile -a C /tmp/charl-dmg-mount
hdiutil detach /tmp/charl-dmg-mount -quiet
hdiutil convert dist/charl-rw.dmg -format UDZO -imagekey zlib-level=9 -o dist/charl-$VERSION.dmg -quiet -ov
rm -f dist/charl-rw.dmg
rm -rf dist/dmg-stage

# 4) 若提供公证 profile，则提交公证并装订；否则仅本地自签包
if [ -n "${CHARL_NOTARY_PROFILE:-}" ]; then
  xcrun notarytool submit dist/charl-$VERSION.dmg --keychain-profile "$CHARL_NOTARY_PROFILE" --wait
  xcrun stapler staple dist/charl-$VERSION.dmg
else
  echo "DMG ready (self-signed, not notarized). Set CHARL_NOTARY_PROFILE to notarize."
fi
echo "Done: dist/charl-$VERSION.dmg"
