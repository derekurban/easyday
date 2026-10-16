#!/usr/bin/env bash
# Dump the accessibility tree of the emulator and print every node with a label, as "label | centre x y | box".
# Flutter publishes its semantics tree to Android, so this lists buttons, labels and their tap targets.
#   tool/ui.sh [serial]            full list
#   tool/ui.sh [serial] "Start"    only nodes whose label contains the string
set -e
export MSYS_NO_PATHCONV=1   # Git Bash would otherwise rewrite /sdcard/ui.xml into a Windows path
serial="${1:-emulator-5554}"; q="${2:-}"
adb -s "$serial" shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 || true
adb -s "$serial" shell cat /sdcard/ui.xml | sed 's/<node/\n<node/g' | awk -v q="$q" '
  /<node/ {
    label = ""
    if (match($0, /text="[^"]+"/)) label = substr($0, RSTART + 6, RLENGTH - 7)
    if (label == "" && match($0, /content-desc="[^"]+"/)) label = substr($0, RSTART + 14, RLENGTH - 15)
    if (label == "") next
    gsub(/&#10;/, " / ", label); gsub(/&quot;/, "\"", label); gsub(/&amp;/, "\\&", label)
    if (q != "" && index(label, q) == 0) next
    if (!match($0, /bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"/)) next
    b = substr($0, RSTART + 8, RLENGTH - 9); gsub(/[\[\]]/, " ", b); gsub(/,/, " ", b); split(b, c, " ")
    printf "%s | centre %d %d | box %d %d %d %d\n", label, (c[1] + c[3]) / 2, (c[2] + c[4]) / 2, c[1], c[2], c[3], c[4]
  }'
