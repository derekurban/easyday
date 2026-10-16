#!/usr/bin/env bash
# Screenshot the emulator into build/shots/<name>.png and print the path.
#   tool/shot.sh [name] [serial]
set -e
cd "$(dirname "$0")/.."
name="${1:-shot}"; serial="${2:-emulator-5554}"
mkdir -p build/shots
adb -s "$serial" exec-out screencap -p > "build/shots/$name.png"
echo "$(pwd)/build/shots/$name.png"
