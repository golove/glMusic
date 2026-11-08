#!/usr/bin/env bash
set -e

echo "==========================================="
echo " Building glMusic for Windows (x86_64)    "
echo "==========================================="

# Check if running natively on Windows or cross-compiling
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    echo "Compiling natively on Windows..."
    pnpm install
    pnpm tauri build --target x86_64-pc-windows-msvc
else
    echo "Cross-compiling for Windows using cargo-xwin..."
    # Ensure target is installed
    rustup target add x86_64-pc-windows-msvc 2>/dev/null || true

    # Install cargo-xwin if not present
    if ! command -v cargo-xwin &> /dev/null; then
        echo "Installing cargo-xwin..."
        cargo install cargo-xwin
    fi

    pnpm install
    pnpm build
    cd src-tauri
    cargo xwin build --release --target x86_64-pc-windows-msvc
    echo ""
    echo "Windows executable created at: src-tauri/target/x86_64-pc-windows-msvc/release/glmusic.exe"
fi
