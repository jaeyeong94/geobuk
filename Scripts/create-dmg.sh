#!/bin/bash
set -euo pipefail

# Usage: create-dmg.sh [version]
# Creates Geobuk-v{version}.dmg from build/Geobuk.app

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VERSION="${1:-0.1.0}"
APP_PATH="$PROJECT_ROOT/build/Geobuk.app"
DMG_NAME="Geobuk-v${VERSION}.dmg"
DMG_PATH="$PROJECT_ROOT/build/$DMG_NAME"

if [ ! -d "$APP_PATH" ]; then
    echo "error: $APP_PATH not found"
    echo "Build the app first: xcodebuild archive ..."
    exit 1
fi

echo "Creating DMG: $DMG_NAME"

# create-dmg가 있으면 사용 (예쁜 DMG)
if command -v create-dmg &> /dev/null; then
    # 기존 DMG 제거 (create-dmg는 덮어쓰기 불가)
    rm -f "$DMG_PATH"

    BG_IMG="$SCRIPT_DIR/dmg-background.png"
    BG_OPTS=()
    if [ -f "$BG_IMG" ]; then
        BG_OPTS+=(--background "$BG_IMG")
    fi

    ICON_OPTS=()
    if [ -f "$APP_PATH/Contents/Resources/AppIcon.icns" ]; then
        ICON_OPTS+=(--volicon "$APP_PATH/Contents/Resources/AppIcon.icns")
    fi

    create-dmg \
        --volname "Geobuk" \
        "${ICON_OPTS[@]}" \
        "${BG_OPTS[@]}" \
        --window-pos 200 120 \
        --window-size 512 384 \
        --icon-size 100 \
        --icon "Geobuk.app" 130 190 \
        --hide-extension "Geobuk.app" \
        --app-drop-link 382 190 \
        "$DMG_PATH" \
        "$APP_PATH"
else
    # fallback: hdiutil로 기본 DMG 생성
    echo "create-dmg not found, using hdiutil fallback"
    STAGING_DIR=$(mktemp -d)
    cp -R "$APP_PATH" "$STAGING_DIR/"
    ln -s /Applications "$STAGING_DIR/Applications"

    hdiutil create \
        -volname "Geobuk" \
        -srcfolder "$STAGING_DIR" \
        -ov \
        -format UDZO \
        "$DMG_PATH"

    rm -rf "$STAGING_DIR"
fi

echo "DMG created: $DMG_PATH ($(ls -lh "$DMG_PATH" | awk '{print $5}'))"
