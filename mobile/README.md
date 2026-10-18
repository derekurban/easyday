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

### Branches and releases

Work lands on `dev`. Releases come from CI (`../.github/workflows/release.yml`), never from a laptop:

| Merge | Builds | GitHub release |
|---|---|---|
| `dev` → `staging` | staging flavour | `v<version>-staging.<versionCode>` with `fitness-staging.apk` |
| `staging` → `main` | prod flavour | `v<version>-prod.<versionCode>` with `fitness.apk`, marked latest |

Each run analyzes, tests, builds the flavour signed with the release key and publishes the release. `<version>` is
`pubspec.yaml`'s version name (bump it for a new version); the versionCode is 100000 + the workflow's run number, so
every build installs over the last. A pull request into `staging` or `main` runs the same build as a check without
releasing (the APK is kept as a run artifact): open the PR, let it go green, merge, and the merge publishes. The
signing key reaches CI as repo secrets `KEYSTORE_BASE64` (the keystore, base64), `KEYSTORE_PASSWORD`, `KEY_ALIAS` and
`KEY_PASSWORD`.

### Updates in the app

Installed apps update themselves (`AutoUpdater` in `lib/ui/updates.dart`). On launch, and on coming back to the front
at most every half hour, the app reads `api.github.com/repos/derekurban/fitness/releases`, takes the newest release
carrying its own flavour's APK, and if it is a higher version (or the same version with a higher build number) it
downloads it, shows "Updating to …", and installs it over itself through a PackageInstaller session; Android closes
the app and the new version opens next time. It waits while a workout is in progress, installs nothing in debug builds, and
needs "install unknown apps" allowed for the app once (Settings → Updates asks for it and still offers a manual check
and Update button). On Android 12+ Android installs without a prompt once the app is its own installer of record,
that is from the second self-update on; the first one (and every one before Android 12) shows Android's confirm
screen (the manifest's `UPDATE_PACKAGES_WITHOUT_USER_ACTION` is what lets Android skip it). On a phone with Play
services, Play Protect may still stop a new APK it has not seen to recommend a scan: "More details" offers "Install
without scanning"; turning off "Scan apps with Play Protect" in the Play Store removes that too. Verified on the
emulator (Android 16): the first self-update asked once, a later one installed with no Android prompt, Play Protect
asked each time.

Every check also feeds a trail to the waiting update, for whenever the install does not happen on its own (installs
not allowed yet, a failed install, a debug build): an amber dot on the Settings tab, an amber banner at the top of
Settings ("A new update is available") whose "Go to update" button scrolls to the Updates section, and a dot on that
section's header. All three go away once a check finds the app current.

A test build can read its release list from somewhere other than GitHub:
`--dart-define=UPDATE_FEED=http://127.0.0.1:8765/feed.json`, a JSON list shaped like GitHub's whose asset URL points
at an APK served beside it, from the computer through `adb reverse tcp:8765 tcp:8765`. (Files pushed with adb into the
app's external storage belong to the shell user, so the app cannot read them.) The dev loop takes the same feed as
`UPDATE_FEED=http://127.0.0.1:8765/feed.json node tool/dev.mjs`.

`bash tool/publish.sh [prod|staging|--no-build]` still builds release APKs locally into `../dist/` for the Tailscale
install page (`../dist/index.html`); it no longer makes GitHub releases.

### Feedback

Settings → Feedback: people write a problem or an idea in the app, and the repo's issue form
(`../.github/ISSUE_TEMPLATE/`) opens in the browser with all of it filled in, plus the version and phone; they sign in
and send. `lib/logic/feedback.dart` builds the links, and `test/feedback_test.dart` fails if a field the app fills is
renamed, relabelled or made a dropdown in a form. See `../docs/app/FEEDBACK.md`.

## Words

The spec and the UI say **progression** and **level**; the code still says ladder and rung in a few places (`ladder.dart`,
`rung` fields). The UI says **workout**; the code says `Session`. Movement patterns (squat, hinge, push, pull, ...) are
internal to the builder and never shown.

## Not in this build yet

Diagrams and the step guides with visuals (see `../docs/`). The rotation (which slot types each workout
holds) is fixed; the goal decides how many of them a workout plans. The reminder is a fixed line at a fixed hour; it does
not yet know whether today's workout is already done.
