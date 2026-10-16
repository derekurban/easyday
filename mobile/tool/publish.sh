#!/usr/bin/env bash
# Build the release APKs and publish them to ../dist/ for download over Tailscale.
#   bash tool/publish.sh                 build prod and staging, copy both, and publish a GitHub release v<version>
#   NOTES="what changed" bash tool/publish.sh   with release notes (the app shows them under Update)
#   bash tool/publish.sh staging         build one flavour
#   bash tool/publish.sh --no-build      copy the last builds only
# Then open http://derek-desktop.tail546211.ts.net:5180/dist/ on the phone. The two flavours install side by side:
# prod is dev.derekurban.fitness ("Fitness", green icon), staging adds .staging ("Fitness Staging", amber icon).
set -e
cd "$(dirname "$0")/.."
flavors="prod staging"
build=1
case "${1:-}" in
  --no-build) build=0 ;;
  prod|staging) flavors="$1" ;;
  "") ;;
  *) echo "usage: tool/publish.sh [prod|staging|--no-build]" >&2; exit 2 ;;
esac
mkdir -p ../dist
ver="$(grep -E '^version:' pubspec.yaml | sed 's/version: *//')"
: > ../dist/build.txt
for f in $flavors; do
  if [ "$build" = 1 ]; then flutter build apk --release --flavor "$f"; fi
  apk="build/app/outputs/flutter-apk/app-$f-release.apk"
  [ -f "$apk" ] || { echo "no release apk at $apk" >&2; exit 1; }
  out="fitness.apk"; [ "$f" = staging ] && out="fitness-staging.apk"
  cp "$apk" "../dist/$out"
  size="$(du -h "../dist/$out" | cut -f1)"
  sha="$(sha1sum "../dist/$out" | cut -c1-12)"
  echo "$f: Version $ver · built $(date '+%Y-%m-%d %H:%M') · $size · sha1 $sha · $out" >> ../dist/build.txt
done
cat ../dist/build.txt
echo "published to ../dist/"

# A GitHub release carries both APKs; the app's Updates panel reads the latest one. Only when both were built.
if [ "$flavors" = "prod staging" ] && command -v gh >/dev/null; then
  tag="v${ver%%+*}"
  notes="${NOTES:-$(cat ../dist/build.txt)}"
  if gh release view "$tag" --repo derekurban/fitness >/dev/null 2>&1; then
    gh release upload "$tag" ../dist/fitness.apk ../dist/fitness-staging.apk --clobber --repo derekurban/fitness
  else
    gh release create "$tag" ../dist/fitness.apk ../dist/fitness-staging.apk --title "$tag" --notes "$notes" --repo derekurban/fitness
  fi
  echo "released $tag on github.com/derekurban/fitness"
fi
