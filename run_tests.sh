#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

# Preferred path: normal Xcode toolchain (works once the Xcode license is accepted).
if xcrun --sdk macosx --show-sdk-path >/dev/null 2>&1; then
    exec swift test "$@"
fi

# Fallback: Xcode toolchain binaries directly, bypassing the license-gated xcrun,
# with explicit XCTest search/link paths and runtime DYLD resolution.
XCODE=/Applications/Xcode.app/Contents/Developer
SDK="$XCODE/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.sdk"
XCTLIB="$XCODE/Platforms/MacOSX.platform/Developer/usr/lib"
XCTFW="$XCODE/Platforms/MacOSX.platform/Developer/Library/Frameworks"

export SDKROOT="$SDK"
export DYLD_FRAMEWORK_PATH="$XCTFW"
export DYLD_LIBRARY_PATH="$XCTLIB"

SWIFT="$XCODE/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"
SCRATCH=".build-xcode-tests"

"$SWIFT" build --build-tests --scratch-path "$SCRATCH" \
    -Xswiftc -I"$XCTLIB" \
    -Xswiftc -F"$XCTFW" \
    -Xlinker -F -Xlinker "$XCTFW" \
    -Xlinker -framework -Xlinker XCTest \
    -Xlinker -L -Xlinker "$XCTLIB" \
    -Xlinker -lXCTestSwiftSupport

BIN_DIR="$("$SWIFT" build --scratch-path "$SCRATCH" --show-bin-path)"
exec "$XCODE/usr/bin/xctest" -XCTest All "$BIN_DIR/GLMStatusBarPackageTests.xctest"
