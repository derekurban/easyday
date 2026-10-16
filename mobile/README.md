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
| `tool/` | The dev loop (below) |

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

## Installable APK

```
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

The release APK is signed with the debug key, which is fine for sideloading on your own phone. Application id
`dev.derekurban.fitness`.

## Words

The spec and the UI say **progression** and **level**; the code still says ladder and rung in a few places (`ladder.dart`,
`rung` fields). The UI says **workout**; the code says `Session`. Movement patterns (squat, hinge, push, pull, ...) are
internal to the builder and never shown.

## Not in this build yet

Diagrams, the muscle map, and the step guides with visuals (see `../docs/`). The rotation (which slot types each workout
holds) is fixed; the goal decides how many of them a workout plans. The reminder is a fixed line at a fixed hour; it does
not yet know whether today's workout is already done.
