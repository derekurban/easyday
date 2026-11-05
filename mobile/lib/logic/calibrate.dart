// Calibration sets: how a new exercise finds its weight in one workout (docs/app/WORKOUT.md, "Calibrating").
//
// The first set of an exercise that is calibrating is as many good reps as the user can, up to [calibrationCap], at the
// app's starting weight. Under the cap, that set says how strong they are: the exercise is calibrated, and the rest of
// its sets are working sets at the weight it implies for today's range. At the cap it only says "at least this many",
// so the next set is heavier, by what the cap implies and a margin, and another calibration set, up to
// [calibrationTries] in a workout. Checked against simulated lifters before it was built (one session calibrated 97 to
// 100 % of exercises with one or two hard sets; a person's own pick of weight was riskier than the app's start).
import 'dart:math';

import '../data/library.dart';
import '../data/model.dart';
import 'ladder.dart';
import 'score.dart';
import 'workout.dart';

/// The most reps a calibration set asks for. Fewer and a strong lifter hits it twice; more and a set runs long.
const calibrationCap = 20;

/// Calibration sets in one workout, at most.
const calibrationTries = 3;

/// The rep people leave in the tank when told to go to failure: counted back when a calibration set sets the weight.
/// Not in the rating: working sets stop short too, and both are read the same way, so a lift does not drop after it
/// calibrates.
const leftInTheTank = 1;

/// Past the cap, how much more than the cap implies the next set asks for: the cap was not failure.
const capMargin = 1.15;

/// A newcomer's weight grows at most this much from one calibration set to the next.
const newcomerJump = 1.25;

/// Exercises that calibrate with calibration sets: rated strength exercises counted in reps.
bool calibrates(Exercise ex) => ex.isStrength && ex.tracked && ex.repLabel != 'seconds';

/// Whether set [k] of [e] is a calibration set: the exercise is calibrating today, and every set before it was a
/// calibration set that reached the cap or got nothing, up to [calibrationTries].
bool isTestSet(SessionExercise e, int k) {
  if (!e.calibrating || k >= calibrationTries) return false;
  for (var j = 0; j < k; j++) {
    final x = e.sets[j];
    if (!x.test || x.reps == null) return false;
    if (x.reps! > 0 && x.reps! < calibrationCap) return false;
  }
  return true;
}

/// The calibration set that found the level today: the first with reps under the cap. Null while none has.
SetLog? calibrationSet(SessionExercise e) => e.sets.where((x) => x.test && (x.reps ?? 0) > 0 && x.reps! < calibrationCap).firstOrNull;

/// Whether today calibrated [e]: a calibration set ended under the cap, or reached it at the top of what this place has.
bool calibratedToday(SessionExercise e) => calibrationSet(e) != null || (e.atCeiling && e.sets.any((x) => x.test && (x.reps ?? 0) >= calibrationCap));


/// Log the reps of the set under way, and if it was a calibration set, set the weight for the next one: heavier past the
/// cap, lighter with none, and under the cap the level found, kept as the user's own from now on.
void logReps(AppState state, Session s, int reps, DateTime now) {
  final cur = currentItem(s);
  final r = cur == null ? null : liftingSet(s, cur);
  enterReps(s, reps, now);
  if (r != null && setOf(s, r).test) afterCalibrationSet(state, s, r.ex);
}

/// What calibration set [x] of exercise [i] says the level is: the weight (or the version) for the next sets, and
/// whether it found it. Heavier past the cap, lighter with nothing done, and under the cap the level it is worth.
({double? kg, int? rung, bool found}) _levelFrom(AppState state, Session s, int i, SetLog x, {bool margin = true}) {
  final e = s.exercises[i];
  final ex = e.exercise;
  final reps = x.reps ?? 0;
  final mid = epley(((e.lo + e.hi) / 2).round());
  final load = ex.loaded ? (x.kg ?? e.loadKg ?? levelLoad(state, e, e.rung)) : versionShare(ex, x.rung ?? e.rung);
  final found = reps > 0 && reps < calibrationCap;
  double target;
  if (reps == 0) {
    target = load * 0.8;
  } else if (found) {
    target = load * epley(reps + leftInTheTank) / mid;
  } else {
    target = load * epley(calibrationCap + leftInTheTank) / mid * (margin ? capMargin : 1);
    if (experienceIndex(state.profile?.experience ?? 'some') == 0) target = min(target, load * newcomerJump);
  }
  if (ex.loaded) {
    final step = stepKg(state, ex), floor = ex.platesAdded ? 0.0 : step;
    var kg = max(floor, (target / step + 1e-9).floor() * step);
    if (!found && reps > 0 && kg <= load) kg = load + step; // past the cap: always heavier
    return (kg: kg, rung: null, found: found);
  }
  final eq = state.location(s.locationId)?.equipment ?? const <String>[];
  final top = ceilingFor(ex, eq) ?? ex.ladder!.variants.length - 1;
  var rung = 0;
  for (var k = 1; k <= top; k++) { if (versionShare(ex, k) <= target + 1e-9) rung = k; }
  if (!found && reps > 0 && rung <= (x.rung ?? e.rung)) rung = min(top, (x.rung ?? e.rung) + 1);
  return (kg: null, rung: rung, found: found);
}

/// Keep the level a calibration set said as the user's own: the grid's nearest level, still calibrating unless found.
void _keep(AppState state, Session s, int i, ({double? kg, int? rung, bool found}) l) {
  final e = s.exercises[i];
  final ex = e.exercise;
  final st = ensureState(state, ex);
  setRung(state, ex, l.kg != null ? rungForLoad(state, ex, st, l.kg!, e.range) : l.rung!);
  st.calibrating = !l.found && !calibratedToday(e);
}

/// After a calibration set of exercise [i]: the sets to come at the level it said, and that level kept. Past the
/// cap the next set takes the margin, but the level kept for next time does not: that workout opens on it with a set
/// to failure, with nothing after it in the same workout to correct an overshoot.
void afterCalibrationSet(AppState state, Session s, int i) {
  final e = s.exercises[i];
  final x = e.sets.lastWhere((x) => x.attempted);
  if (!x.test) return;
  final next = _levelFrom(state, s, i, x);
  final ex = e.exercise;
  _keep(state, s, i, _levelFrom(state, s, i, x, margin: false));
  final st = ensureState(state, ex);
  if (ex.loaded) {
    // found: on the grid's own weight for the level; still looking: the next set's weight, with the margin
    changeLevel(state, s, i, kg: next.found ? loadFor(state, ex, st, st.rung, e.range) : next.kg);
  } else {
    changeLevel(state, s, i, rung: next.rung);
  }
}

/// On logging a workout: the level its calibration sets said, however the reps were entered. The set that found it,
/// else the last one, then without the margin: the next workout opens on it with a set to failure, and nothing in the
/// same workout can correct an overshoot.
void settleCalibration(AppState state, Session s, int i) {
  final e = s.exercises[i];
  final x = calibrationSet(e) ?? e.sets.lastWhere((x) => x.test && x.attempted, orElse: () => SetLog());
  if (!x.test) return;
  _keep(state, s, i, _levelFrom(state, s, i, x, margin: false));
}
