# WATCH

Easyday on a Wear OS watch (built for the Galaxy Watch 4, Wear OS 3 and later). The watch is a second screen for the
workout under way on the phone, plus a heart-rate sensor. It plans nothing and judges nothing. The phone is the only
source of truth, so the watch can be lost, flat or left at home and nothing changes.

## What it does

- **Follows the workout.** One thing at a time, as on the phone: the set under way with its reps on a dial, then the
  rest and the button to what comes next, a timed part (warm-up, stretching, cardio with its stopwatch), or the free-form
  list. The workout's clock runs along the top edge; it is the only clock, as on the phone (`WORKOUT.md`). A ring of
  marks round the edge is the phone's strip: done, the one under way, still to come.
- **Takes the taps.** Log (turn the bezel to the number), I'm ready, the free-form pick, Done for cardio. Swiping left
  shows pause or resume and End, with a confirm. A movement day has no End on the watch: it ends with Done, and leaving
  it without logging stays on the phone. After each step the button waits a moment before it can be pressed, as on the
  phone with its setting on, so a quick second tap cannot skip what comes next.
- **Starts Today's workout.** While Today is on screen on the phone, the watch shows its name and one line of numbers,
  and Start starts it, exactly as the phone's Start would.
- **Records the heart.** While a workout is under way the watch holds a Health Services exercise (strength training,
  or a general workout for a movement day) and sends its heart rate and energy to the phone every 15 seconds. The
  current rate shows on the watch during rests, and its average and peak when the workout ends.

The finish on the phone then shows one line, `Heart 118 avg · 156 peak · 320 kcal`. Its details show a heart-rate
panel (the three numbers and a line over the workout's time with the sets marked under it) and a Peak column in each
exercise's table: the highest reading from the set's start until 20 seconds after its reps, stopping at the next thing
started. Heart rate is never a target, a zone or a reason for anything the app decides. It is a record of the workout,
nothing more (`APPLICATION.md`, section 14).

## How the two talk

The phone and watch apps share an application id per flavour and build type (`app.easyday`, `app.easyday.staging`,
each with `.dev` for debug builds) and the release key. The Wear data layer only connects an app to its twin with the
same id and signature, so prod talks to prod and staging to staging.

- **Phone to watch: one data item, `/easyday/state`.** It is the watch view, worked out in `lib/logic/watch_view.dart`
  and sent whole by `lib/watch.dart` whenever it changes (urgent, so a watch on the wrist hears it at once). It holds
  the phase (`idle`, `today`, `lift`, `rest`, `timed`, `choose`, `review`, `done`), what that phase shows, the workout's
  start and pause times, whether to record, and the step token. Times are the phone's clock; `skew` is how far that
  clock is from real time (the prototype's day shift), so the watch can run the clock by itself.
- **Watch to phone: messages.** `/easyday/cmd` is a tap: `{op, step, session, at}` plus `reps` or `ex`. `/easyday/heart`
  is a batch: `{session, samples: [[ms, bpm]...], kcal, device}`. Android hands both to `WatchListenerService` on the
  phone, even with the app closed, which keeps them in a small inbox file (`WatchInbox.kt`) until Dart reads it. So no
  heart batch is lost to a phone app that was asleep; it lands on its workout by id, even one already logged.
- **Every tap names its step.** The step token is the workout screen's own step (`<session> lift <ex> <set>`,
  `<session> rest ...`, a timed part's key) or `today <name>`. A tap whose step is not the phone's step now does nothing
  (the phone was tapped first, or the message was slow), and nor does one older than two minutes. Pause, resume and end
  need only the workout. The phone always answers a tap with its view, so the watch knows it was heard; no answer in six
  seconds and the watch says to open Easyday on the phone.
- **The workout screen does the work.** A tap that applies is handed to the workout screen, which runs the same code as
  its own button (`_fromWatch` in `lib/ui/session.dart`): the same haptics, the same waits, the end of the workout when
  the last thing is done. Today's Start is Today's own `_start`.

## Heart rate on the workout's clock

Resuming a pause moves every time in the workout on by the pause (`resumeWorkout`), so the workout reads as if the pause
never happened. Heart samples are kept as they came, in real time, and each pause is kept on the session as when it
began and how long it lasted. Reading them (`lib/logic/heart.dart`) moves each sample on by every pause that began after
it and drops the ones inside a pause. Samples are kept at most one every five seconds, between 30 and 230 bpm; a batch
sent twice changes nothing; the energy is the watch's running total, so the largest stands. A workout's samples are a
few kilobytes in the saved state (`HeartLog` in `model.dart`: a start and whole seconds after it).

## The watch app

`mobile/android/wear` is a Kotlin and Compose for Wear OS module beside the Flutter app's `app` module.

- `View.kt` reads the phone's view. `Link.kt` keeps it, loads the last one when the app opens, says hello (the answer
  says whether the phone app is awake), and sends taps and heart batches to the phone that has the `easyday_phone`
  capability.
- `Ui.kt` draws it, in the phone's dark theme (`Theme.kt`: true black, ink, the sun on the one button, Albert Sans and
  Wix Madefor Text from the app's own fonts). The reps dial takes the bezel, or a drag.
- `WorkoutService.kt` is the foreground service holding the exercise. It starts when the app is on screen and the phone's
  view says to record (Android lets a foreground health service start only from something the user sees), follows the
  view's pauses, ends with the workout, and keeps unsent samples until the phone has them. A workout left running is
  ended after four hours. While it runs, the watch face shows it as an ongoing activity.
- `PhoneListener.kt` hears the phone's view with the app closed. A workout started on the phone then gets one
  notification on the watch: tap it to open the app, which starts recording.
- Permissions: the heart rate (`BODY_SENSORS` up to Wear OS 5, `health.READ_HEART_RATE` on Wear OS 6), activity
  recognition for the energy, and notifications. They are asked for once, the first time the app opens. Without them
  the watch still follows and taps; it just records nothing.

## Building, installing, releasing

From `mobile/android`: `./gradlew :wear:assembleStagingDebug` (or `ProdRelease`, `StagingRelease`); the APK is in
`mobile/build/wear/outputs/apk/`. The version follows `pubspec.yaml`. A release from CI carries the watch APK beside the
phone's (`easyday-wear.apk`, `easyday-wear-staging.apk`), signed with the same key.

The watch app is not on the Play Store, so it goes on the watch with adb over Wi-Fi: on the watch, Settings > About
watch > Software information, tap Software version five times for Developer options, then Developer options > ADB debugging and
Wireless debugging > Pair new device. Then `adb pair <ip:port> <code>`, `adb connect <ip:port>` and
`adb -s <ip:port> install -r easyday-wear.apk`. Install the flavour that matches the phone's. The watch app does not
update itself; install the new APK the same way when the protocol changes (the watch says "Update Easyday on your
watch" for a view version it does not know).

Debug builds take a made-up view for looking at every screen without a phone:
`adb shell am start -n app.easyday.staging.dev/app.easyday.wear.MainActivity --es demo lift` (also `today`, `idle`,
`rest`, `timed`, `choose`, `paused`, `asleep`, `review`).

## Not yet

- Rep counting from the wrist's motion, to open the dial on the reps it counted.
- A tile and a watch-face complication with Today's workout.
- The watch updating itself from the releases.
- Sleep and resting heart rate setting the energy default (Health Connect on the phone, no watch app needed).
