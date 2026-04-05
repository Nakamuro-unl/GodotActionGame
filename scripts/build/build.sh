#!/bin/bash
set -euo pipefail

# Math Mage - CLI Build Script
# Usage: ./scripts/build/build.sh [ios|android|all|test|clean]

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT_BIN:-godot}"
BUILD_DIR="${PROJECT_DIR}/builds"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()   { echo -e "${GREEN}[BUILD]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

check_godot() {
    if ! command -v "$GODOT" &> /dev/null; then
        error "Godot not found. Set GODOT_BIN or add godot to PATH."
    fi
    log "Godot: $($GODOT --version 2>&1 | head -1)"
}

run_tests() {
    log "Running tests..."
    cd "$PROJECT_DIR"
    "$GODOT" --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
        --ignoreHeadlessMode -a tests/ 2>&1 | tail -5
    local exit_code=${PIPESTATUS[0]}
    if [ $exit_code -ne 0 ]; then
        error "Tests failed (exit code: $exit_code)"
    fi
    log "Tests passed."
}

build_ios() {
    log "Building iOS..."
    mkdir -p "$BUILD_DIR/ios"
    cd "$PROJECT_DIR"

    # Import resources first
    "$GODOT" --headless --import 2>&1 | tail -3 || true

    "$GODOT" --headless --export-release "iOS" \
        "$BUILD_DIR/ios/mathmage.ipa" 2>&1

    if [ -f "$BUILD_DIR/ios/mathmage.ipa" ]; then
        log "iOS build success: $BUILD_DIR/ios/mathmage.ipa"
    else
        # Godot might output xcodeproj instead of ipa
        if [ -d "$BUILD_DIR/ios/mathmage.xcodeproj" ] || [ -f "$BUILD_DIR/ios/mathmage" ]; then
            log "iOS export success: $BUILD_DIR/ios/"
        else
            warn "iOS build completed but output not found. Check Godot export settings."
        fi
    fi
}

build_android() {
    log "Building Android..."
    mkdir -p "$BUILD_DIR/android"
    cd "$PROJECT_DIR"

    # Import resources first
    "$GODOT" --headless --import 2>&1 | tail -3 || true

    "$GODOT" --headless --export-release "Android" \
        "$BUILD_DIR/android/mathmage.apk" 2>&1

    if [ -f "$BUILD_DIR/android/mathmage.apk" ]; then
        log "Android build success: $BUILD_DIR/android/mathmage.apk"
        ls -lh "$BUILD_DIR/android/mathmage.apk"
    else
        warn "Android build completed but APK not found. Check:"
        warn "  - Android SDK path in Editor Settings"
        warn "  - Export templates installed"
        warn "  - Debug keystore configured"
    fi
}

clean() {
    log "Cleaning builds..."
    rm -rf "$BUILD_DIR"
    log "Done."
}

show_help() {
    echo "Math Mage Build Script"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  ios       Build for iOS"
    echo "  android   Build for Android"
    echo "  all       Build for all platforms"
    echo "  test      Run tests only"
    echo "  clean     Remove build outputs"
    echo "  help      Show this help"
    echo ""
    echo "Environment:"
    echo "  GODOT_BIN   Path to Godot binary (default: godot)"
    echo ""
    echo "Prerequisites:"
    echo "  iOS:     macOS + Xcode + Godot export templates"
    echo "  Android: Android SDK + Godot export templates + debug keystore"
}

# Main
check_godot

case "${1:-help}" in
    ios)
        run_tests
        build_ios
        ;;
    android)
        run_tests
        build_android
        ;;
    all)
        run_tests
        build_ios
        build_android
        log "All builds complete."
        ;;
    test)
        run_tests
        ;;
    clean)
        clean
        ;;
    help|*)
        show_help
        ;;
esac
