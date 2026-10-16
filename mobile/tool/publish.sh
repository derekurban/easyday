#!/usr/bin/env bash
# Build the release APK and publish it to ../dist/ for download over Tailscale.
#   bash tool/publish.sh            build and copy
#   bash tool/publish.sh --no-build copy the last build only
# Then open http://derek-desktop.tail546211.ts.net:5180/dist/ on the phone.
set -e
cd "$(dirname "$0")/.."
if [ "${1:-}" != "--no-build" ]; then flutter build apk --release; fi
apk="build/app/outputs/flutter-apk/app-release.apk"
[ -f "$apk" ] || { echo "no release apk at $apk" >&2; exit 1; }
mkdir -p ../dist
cp "$apk" ../dist/fitness.apk
ver="$(grep -E '^version:' pubspec.yaml | sed 's/version: *//')"
size="$(du -h ../dist/fitness.apk | cut -f1)"
sha="$(sha1sum ../dist/fitness.apk | cut -c1-12)"
echo "Version $ver · built $(date '+%Y-%m-%d %H:%M') · $size · sha1 $sha" > ../dist/build.txt
cat ../dist/build.txt
echo "published to ../dist/fitness.apk"
