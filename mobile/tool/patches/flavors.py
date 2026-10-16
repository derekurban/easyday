# Two Android flavours: prod (dev.derekurban.fitness, "Fitness") and staging (.staging suffix, "Fitness Staging",
# amber icon). The dev loop and the published builds use them.
p='android/app/build.gradle.kts'
s=open(p,encoding='utf-8').read()
old="""    buildTypes {
        release {"""
new="""    flavorDimensions += "env"
    productFlavors {
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "Fitness")
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            resValue("string", "app_name", "Fitness Staging")
        }
    }

    buildTypes {
        release {"""
assert old in s; s=s.replace(old,new,1)
s=s.replace("""        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.derekurban.fitness"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
""","""        applicationId = "dev.derekurban.fitness"
""",1)
s=s.replace("""            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
""","""            // Still signed with the debug keys: a release keystore is not set up yet.
""",1)
open(p,'w',encoding='utf-8').write(s)

p='android/app/src/main/AndroidManifest.xml'
s=open(p,encoding='utf-8').read()
old='        android:label="Fitness"'
assert old in s; s=s.replace(old,'        android:label="@string/app_name"',1)
open(p,'w',encoding='utf-8').write(s)

p='tool/dev.mjs'
s=open(p,encoding='utf-8').read()
old='''//   node tool/dev.mjs [deviceId]          start (default device: emulator-5554), listens on 127.0.0.1:5181'''
new='''//   node tool/dev.mjs [deviceId]          start (default device: emulator-5554), listens on 127.0.0.1:5181
//   FLAVOR=prod node tool/dev.mjs         run the prod flavour instead of the default staging one'''
assert old in s; s=s.replace(old,new,1)
old='''const device = process.argv[2] ?? "emulator-5554";'''
new='''const device = process.argv[2] ?? "emulator-5554";
const flavor = process.env.FLAVOR ?? "staging";'''
assert old in s; s=s.replace(old,new,1)
old='''const child = spawn(flutter, ["run", "--machine", "-d", device], {'''
new='''const child = spawn(flutter, ["run", "--machine", "-d", device, "--flavor", flavor], {'''
assert old in s; s=s.replace(old,new,1)
old='''    if (url.pathname === "/status") return reply(200, { running: child.exitCode == null, appId, ready, device });'''
new='''    if (url.pathname === "/status") return reply(200, { running: child.exitCode == null, appId, ready, device, flavor });'''
assert old in s; s=s.replace(old,new,1)
open(p,'w',encoding='utf-8').write(s)

p='tool/publish.sh'
open(p,'w',encoding='utf-8',newline='\n').write('''#!/usr/bin/env bash
# Build the release APKs and publish them to ../dist/ for download over Tailscale.
#   bash tool/publish.sh                 build prod and staging, copy both
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
''')

p='lib/ui/settings.dart'
s=open(p,encoding='utf-8').read()
old="Text('Version 0.13.4 · body map: brand moss fills, group outline, tooltip, expand · ${exercises.length} exercises'"
new="Text('Version 0.13.4${appFlavor == null || appFlavor == 'prod' ? '' : ' $appFlavor'} · body map: brand moss fills, group outline, tooltip, expand · ${exercises.length} exercises'"
assert old in s; s=s.replace(old,new,1)
if "package:flutter/services.dart" not in s:
    s=s.replace("import 'package:flutter/material.dart';","import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart' show appFlavor;",1)
open(p,'w',encoding='utf-8').write(s)
print('ok')
