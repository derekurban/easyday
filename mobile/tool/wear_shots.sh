#!/usr/bin/env bash
# Every watch screen, on a Wear OS emulator, from made-up views (Demo.kt): builds the staging debug watch app, installs
# it, and writes build/shots/wear/<screen>.png and a contact sheet, grid.png. docs/app/WATCH.md.
#   bash tool/wear_shots.sh [serial]          serial defaults to emulator-5560 (the Easyday_Wear_API_34 AVD)
#   bash tool/wear_shots.sh [serial] --no-build
set -e
cd "$(dirname "$0")/.."
serial="${1:-emulator-5560}"
if [ "$2" != "--no-build" ]; then
  (cd android && JAVA_HOME="${JAVA_HOME_17:-/c/Program Files/Java/jdk-17}" ./gradlew :wear:assembleStagingDebug -q --console=plain)
fi
# Git Bash would rewrite the device paths below; set only after the build, whose classpath needs the rewrite
export MSYS_NO_PATHCONV=1
adb -s "$serial" install -r build/wear/outputs/apk/staging/debug/wear-staging-debug.apk > /dev/null
pkg=app.easyday.staging.dev
for p in android.permission.BODY_SENSORS android.permission.ACTIVITY_RECOGNITION android.permission.POST_NOTIFICATIONS; do
  adb -s "$serial" shell pm grant $pkg $p 2> /dev/null || true
done
out=build/shots/wear
mkdir -p $out
screens="lift rest timed choose today idle asleep review paused"
for d in $screens; do
  adb -s "$serial" shell am force-stop $pkg
  adb -s "$serial" shell am start -n $pkg/app.easyday.wear.MainActivity --es demo $d > /dev/null
  sleep 3
  adb -s "$serial" exec-out screencap -p > $out/$d.png
done
python -I - "$out" $screens <<'EOF'
import sys
from PIL import Image
out, names = sys.argv[1], sys.argv[2:]
ims = [Image.open(f'{out}/{n}.png') for n in names]
w = ims[0].width
g = Image.new('RGB', (w * 3 + 20, w * ((len(ims) + 2) // 3) + 10 * ((len(ims) - 1) // 3)), '#444')
for i, im in enumerate(ims):
    g.paste(im, ((i % 3) * (w + 10), (i // 3) * (w + 10)))
g.save(f'{out}/grid.png')
EOF
echo "$out/grid.png"
