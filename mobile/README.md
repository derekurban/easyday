# Fitness · Android

The Android build of the habit-first training app. Flutter, no code generation. Dependencies: shared_preferences, lucide_icons_flutter,
flutter_local_notifications (+ timezone, flutter_timezone), geolocator. Calendar access is a 40-line method channel in MainActivity.kt.
The logic in `lib/logic/` is the spec in `../docs/app/APPLICATION.md` (sections 7 to 10) and is covered by `test/logic_test.dart`.

## Layout

| Path | What |
|---|---|
| `lib/data/library.dart` | Exercise library: 137 built-in exercises (loaded ones standalone, bodyweight ones as progressions of levels), equipment, location and goal templates, routines |
| `lib/data/index.dart` | Indexes: the five ways the library can be grouped for browsing (muscle group, body region, movement pattern, equipment, progression type) |
| `lib/data/howto.dart` | How-to text per level for every bodyweight progression |
| `lib/integrations.dart` | Notifications (daily reminder), calendar (busy minutes today), location (nearest saved place) |
| `lib/data/model.dart` | Persisted state with hand-written JSON |
| `lib/data/store.dart` | One JSON blob in shared preferences, plus the shiftable clock |
| `lib/logic/ladder.dart` | Levels: what one means per exercise, ceilings, labels, cost in play, timing seeds (the code still says rung/ladder; the UI says level/progression) |
| `lib/logic/builder.dart` | Builds a workout: the same exercises at every energy; intents (light / working / extra) set the expression, sets and reserve; the minutes are filled, spare minutes go where the goal says, cardio and stretching close it (docs/app/WORKOUT.md) |
| `lib/logic/after.dart` | After a workout: each exercise judged against its working level (neutral / hit / step up now / hold / miss), timing model, the feel tap moving spare minutes, defaults, the one line |
| `lib/logic/person.dart` | Person state and nudges |
| `lib/logic/rotation.dart` | The rotation |
| `lib/ui/` | Screens: onboarding, today (with the done-for-today state), session (straight sets or circuit), exercise card, catalog (grouped by the chosen index), progress, settings. `theme.dart` carries the design-system tokens, `widgets.dart` the shared controls, `motion.dart` the motion tokens |
| `tool/` | The dev loop, `icons.py`, `publish.sh` (below) |

## Dev loop

Everything runs from `mobile/`. The emulator is the `Pixel_9_Pro_API_36` AVD; boot it with

```
"%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe" -avd Pixel_9_Pro_API_36 -no-boot-anim
```

1. **Logic**: `flutter test` runs the spec tests in a few seconds. `flutter analyze` for lints.
2. **Run with hot reload, no terminal needed**: `node tool/dev.mjs [serial]` starts `flutter run --machine` and listens on
   `127.0.0.1:5181`:
   - `curl localhost:5181/reload` hot reload (keeps state), `/restart` hot restart (resets state)
   - `curl localhost:5181/log?tail=80` the app log, `/status`, `/stop`
3. **See the screen**: `bash tool/shot.sh name` writes `build/shots/name.png`.
4. **Find and tap things by label**: `bash tool/ui.sh` lists every labelled node with its tap centre (Flutter publishes
   its semantics tree in debug builds, so buttons, list rows and text are all there). `bash tool/tap.sh "Start"` taps the
   first match; `bash tool/tap.sh 640 1800` taps a pixel.
5. **Dark mode**: `adb shell cmd uimode night yes|no`.
   Avoid `adb shell input keyevent 4` on a root tab: it exits the app, and a cold relaunch runs the installed snapshot
   rather than the hot-reloaded code, so the dev loop has to be restarted (`/stop`, then `node tool/dev.mjs` again).
   `tap.sh` prefers an exact label match, then the first label containing the text, so use the full button label.
6. **Time travel**: Settings → Prototype tools moves the app clock by days and simulates clean or short sessions, so decay,
   person state and defaults can be exercised without waiting.

## Builds, releases and updates

Two flavours on one dimension, so a try-out never touches the real install:

| Flavour | Application id | Name | Icon |
|---|---|---|---|
| `prod` | `dev.derekurban.fitness` | Fitness | green bracket |
| `staging` | `dev.derekurban.fitness.staging` | Fitness Staging | amber bracket |

The dev loop runs staging (`FLAVOR=prod node tool/dev.mjs` for prod). Every `flutter run` or `flutter build apk` needs
`--flavor prod|staging`. The launcher icons are drawn from the brand mark `../app/icon.svg` by `python -I tool/icons.py`.

Release builds are signed with the keystore named in `android/key.properties` (ignored by git; the keystore lives in
`~/.keys/fitness/`). Without that file a checkout still builds, signed with the debug key, but such a build cannot update
an install signed with the release key.

```
bash tool/publish.sh                      # build both flavours, copy to ../dist/, publish GitHub release v<version>
NOTES="what changed" bash tool/publish.sh # with release notes, shown in the app under Update
bash tool/publish.sh staging              # one flavour, no GitHub release
```

The version is `pubspec.yaml`'s `version:`; bump it before publishing (the tag is `v<version without build number>`,
and a tag that exists gets its assets replaced). The app's Settings → Updates panel reads
`api.github.com/repos/derekurban/fitness/releases`, takes the newest release carrying its flavour's APK, compares the
tag with the installed version, downloads its
flavour's APK into the app cache and opens the Android installer. The first time, Android asks to allow installs from
the app, and on a phone with Play services Play Protect may ask to scan the app: "More details" offers "Install without
scanning". Verified 0.13.5 to 0.13.6 on the emulator. `../dist/index.html` is the fallback install page over Tailscale.

### Branches and staging builds

Work lands on `dev`. Merging `dev` into `staging` (or any push to `staging`) runs `.github/workflows/staging.yml`:
analyze, test, build the staging flavour signed with the release key, and publish a GitHub release tagged
`v<version>-staging.<versionCode>` carrying only `fitness-staging.apk` (never marked latest). The versionCode is the pubspec build number × 1000
plus the run number, so each staging build installs over the last. The staging app's Updates panel reads the release
list and offers the newest release with its APK, comparing the build number when the version is the same; prod does
the same for `fitness.apk`, which staging releases never carry, so staging builds never reach prod (and as staging
releases are never marked latest, prod installs from 0.13.6, which still read `releases/latest`, are safe too). `main`
stays the prod line, published with `tool/publish.sh` as above (marked latest).

The signing key reaches CI as repo secrets `KEYSTORE_BASE64` (the keystore, base64), `KEYSTORE_PASSWORD`, `KEY_ALIAS`
and `KEY_PASSWORD`. A pull request into `staging` runs the same build as a check without releasing (the APK is kept
as a run artifact), so the flow is: open a PR `dev` → `staging`, let it go green, merge, and the merge publishes.

## Words

The spec and the UI say **progression** and **level**; the code still says ladder and rung in a few places (`ladder.dart`,
`rung` fields). The UI says **workout**; the code says `Session`. Movement patterns (squat, hinge, push, pull, ...) are
internal to the builder and never shown.

## Not in this build yet

Diagrams and the step guides with visuals (see `../docs/`). The rotation (which slot types each workout
holds) is fixed; the goal decides how many of them a workout plans. The reminder is a fixed line at a fixed hour; it does
not yet know whether today's workout is already done.
