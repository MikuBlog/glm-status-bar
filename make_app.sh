#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="GLM StatusBar"
BIN_NAME="GLMStatusBar"

SWIFT_BIN="swift"
if ! xcrun --sdk macosx --show-sdk-path >/dev/null 2>&1; then
    echo "==> Xcode license not accepted; falling back to CommandLineTools toolchain..."
    export DEVELOPER_DIR=/Library/Developer/CommandLineTools
    SWIFT_BIN="/Library/Developer/CommandLineTools/usr/bin/swift"
fi

echo "==> Building release binary..."
"$SWIFT_BIN" build -c release

echo "==> Assembling ${APP_NAME}.app ..."
rm -rf "${APP_NAME}.app"
mkdir -p "${APP_NAME}.app/Contents/MacOS"
cp ".build/release/${BIN_NAME}" "${APP_NAME}.app/Contents/MacOS/${BIN_NAME}"
cp Info.plist "${APP_NAME}.app/Contents/Info.plist"

echo "==> Ad-hoc code signing..."
codesign --force --sign - "${APP_NAME}.app" >/dev/null 2>&1 || true

echo "==> Done: $(pwd)/${APP_NAME}.app"
