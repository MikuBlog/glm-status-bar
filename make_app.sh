#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="GLM StatusBar"
BIN_NAME="GLMStatusBar"

if xcrun --sdk macosx --show-sdk-path >/dev/null 2>&1; then
    # Normal path: licensed Xcode toolchain.
    SWIFT_BIN="swift"
    SCRATCH=".build"
else
    # Xcode license not accepted: invoke the Xcode toolchain binaries directly
    # (bypasses the license-gated xcrun), like run_tests.sh does.
    XCODE=/Applications/Xcode.app/Contents/Developer
    if [ ! -d "$XCODE/Toolchains/XcodeDefault.xctoolchain" ]; then
        echo "==> Xcode missing; falling back to CommandLineTools toolchain..."
        export DEVELOPER_DIR=/Library/Developer/CommandLineTools
        SWIFT_BIN="/Library/Developer/CommandLineTools/usr/bin/swift"
        SCRATCH=".build-clt"
    else
        SDK=$(ls -d "$XCODE"/Platforms/MacOSX.platform/Developer/SDKs/MacOSX*.sdk 2>/dev/null | sort -V | tail -1)
        export SDKROOT="$SDK"
        SWIFT_BIN="$XCODE/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"
        SCRATCH=".build-xcode"
    fi
fi

echo "==> Building release binary..."
"$SWIFT_BIN" build -c release --scratch-path "$SCRATCH"

echo "==> Assembling ${APP_NAME}.app ..."
rm -rf "${APP_NAME}.app"
mkdir -p "${APP_NAME}.app/Contents/MacOS"
cp "${SCRATCH}/release/${BIN_NAME}" "${APP_NAME}.app/Contents/MacOS/${BIN_NAME}"
cp Info.plist "${APP_NAME}.app/Contents/Info.plist"

echo "==> Ad-hoc code signing..."
/usr/bin/codesign --force --sign - "${APP_NAME}.app" >/dev/null 2>&1 || true

echo "==> Done: $(pwd)/${APP_NAME}.app"
