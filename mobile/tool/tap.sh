#!/usr/bin/env bash
# Tap the on-screen node whose label matches the argument (exact match first, then first containing), or tap raw coordinates.
#   tool/tap.sh "Start"          tap by label
#   tool/tap.sh 640 1800         tap by pixel
#   SERIAL=emulator-5554 tool/tap.sh ...
set -e
cd "$(dirname "$0")/.."
serial="${SERIAL:-emulator-5554}"
if [[ "$1" =~ ^[0-9]+$ && "$2" =~ ^[0-9]+$ ]]; then adb -s "$serial" shell input tap "$1" "$2"; echo "tapped $1 $2"; exit 0; fi
all="$(bash tool/ui.sh "$serial" "$1")"
line="$(echo "$all" | awk -F' \\| ' -v q="$1" '$1 == q { print; exit }')"
[ -z "$line" ] && line="$(echo "$all" | head -1)"
if [ -z "$line" ]; then echo "no node matching: $1" >&2; exit 1; fi
xy="$(echo "$line" | sed -E 's/.*centre ([0-9]+) ([0-9]+).*/\1 \2/')"
adb -s "$serial" shell input tap $xy
echo "tapped '$1' at $xy"
