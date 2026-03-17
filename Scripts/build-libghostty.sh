#!/bin/bash
set -euo pipefail

# Build libghostty.a from Ghostty source using Zig
# This script is called from Xcode Build Phases

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
GHOSTTY_DIR="$PROJECT_ROOT/Vendor/ghostty"
BUILD_DIR="$PROJECT_ROOT/build"

# Ensure Ghostty submodule is initialized
if [ ! -f "$GHOSTTY_DIR/build.zig" ]; then
    echo "error: Ghostty submodule not initialized. Run: git submodule update --init"
    exit 1
fi

# Check Zig is available
if ! command -v zig &> /dev/null; then
    echo "error: Zig compiler not found. Install via: brew install zig"
    exit 1
fi

echo "Building libghostty..."
echo "  Ghostty dir: $GHOSTTY_DIR"
echo "  Zig version: $(zig version)"

cd "$GHOSTTY_DIR"

# Build xcframework (native only, no macOS app)
# This produces libghostty-fat.a in .zig-cache
zig build \
    -Doptimize=ReleaseFast \
    -Demit-macos-app=false \
    -Dxcframework-target=native \
    2>&1

# Find the fat static library in zig-cache
LIBGHOSTTY_FAT=$(find "$GHOSTTY_DIR/.zig-cache" -name "libghostty-fat.a" -type f 2>/dev/null | head -1)

if [ -n "$LIBGHOSTTY_FAT" ] && [ -f "$LIBGHOSTTY_FAT" ]; then
    echo "Found: $LIBGHOSTTY_FAT ($(ls -lh "$LIBGHOSTTY_FAT" | awk '{print $5}'))"

    # Copy to build directory
    mkdir -p "$BUILD_DIR/lib"
    cp "$LIBGHOSTTY_FAT" "$BUILD_DIR/lib/libghostty.a"

    # Copy headers
    mkdir -p "$BUILD_DIR/include"
    cp "$GHOSTTY_DIR/include/ghostty.h" "$BUILD_DIR/include/" 2>/dev/null || true
    cp -r "$GHOSTTY_DIR/include/ghostty" "$BUILD_DIR/include/" 2>/dev/null || true

    echo "Success: $BUILD_DIR/lib/libghostty.a"
else
    echo "error: libghostty-fat.a not found in zig-cache"
    echo "Checking for any .a files:"
    find "$GHOSTTY_DIR/.zig-cache" -name "libghostty*.a" 2>/dev/null || echo "  None found"
    exit 1
fi
