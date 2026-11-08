#!/usr/bin/env bash
set -e

echo "==========================================="
echo " Building glMusic for Linux (x86_64)      "
echo "==========================================="

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Compiling natively on Linux..."
    # Ensure system dependencies are installed
    if command -v apt-get &> /dev/null; then
        echo "Checking Debian/Ubuntu packages..."
        sudo apt-get update
        sudo apt-get install -y libwebkit2gtk-4.1-dev libappindicator3-dev librsvg2-dev patchelf libasound2-dev libssl-dev
    fi

    pnpm install
    pnpm tauri build --target x86_64-unknown-linux-gnu
    echo ""
    echo "Linux packages created in src-tauri/target/release/bundle/"
else
    echo "Non-Linux host detected (macOS / Windows)."
    if command -v docker &> /dev/null; then
        echo "Using Docker to build Linux packages..."
        docker build -t glmusic-linux-builder -f Dockerfile.linux .
        docker run --rm -v "$(pwd)/dist-linux:/app/src-tauri/target/release/bundle" glmusic-linux-builder
        echo "Linux bundles (.deb, .AppImage) generated into ./dist-linux!"
    else
        echo "Tip: Run via GitHub Actions workflow or install Docker to compile Linux binaries on non-Linux systems."
    fi
fi
