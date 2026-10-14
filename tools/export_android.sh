#!/usr/bin/env bash
# Exports a debug-signed arm64 APK to build/emberpit-debug.apk and verifies the signature.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . --export-debug "Android" build/emberpit-debug.apk 2>&1 | grep -E "ERROR|error|DONE" || true
/opt/android-sdk/build-tools/35.0.0/apksigner verify build/emberpit-debug.apk 2>&1 | grep -v JAVA_TOOL
ls -la build/emberpit-debug.apk
