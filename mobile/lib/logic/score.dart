// One score per exercise, and what the app reads from a workout before it is logged (docs/prototypes/score.html).
// A set is worth its load times (1 + reps / 30), the Epley formula the levels already use. A loaded set's load is its
// weight; a bodyweight version's load is the share of bodyweight the working muscles move. The workout's score is the
// average of its sets. It steps up when the average reaches the top of the range and is worth the next level at its
// floor: for a loaded lift that is today's rule (every set at the top), for a bodyweight version, whose next version is
// a bigger jump, it takes more reps. Sets done at the next level that average its floor make it yours at once. It is
// short when the average is under this level at the floor. Two short workouts in a row step down.
import 'dart:math';

import '../data/library.dart';
import '../data/model.dart';
import 'calibrate.dart' show calibrationCap;
import 'ladder.dart';
import 'workout.dart';

double epley(int reps) => 1 + reps / 30;

/// Measured shares of bodyweight for push-up versions: Ebben et al. 2011 (force plate) for incline (hands on a 61 cm box),
/// knee, regular and feet on a 61 cm box. The rest are estimates.
const measuredShare = <String, double>{
  'Wall push-ups': 0.20,
  'Incline push-ups': 0.41,
  'Knee push-ups': 0.49,
  'Push-ups': 0.64,
  'Feet-elevated push-ups': 0.74,
  'Archer push-ups': 0.90,
  'One-arm push-ups': 1.15,
  'Incline close-grip push-ups': 0.41,
  'Knee close-grip push-ups': 0.49,
  'Close-grip push-ups': 0.64,
  'Paused close-grip push-ups': 0.70,
  'Feet-elevated close-grip push-ups': 0.74,
  'Upright suspension push-ups': 0.55,
  'Suspension push-ups': 0.72,
  'Low suspension push-ups': 0.80,
};

/// Where nothing is measured, each version is taken as this much harder than the one before (an estimate: the measured
/// push-up steps run 1.16 to 1.31).
const estimatedStep = 1.2;

/// A bodyweight version's load, as a share of bodyweight. Only the ratio between versions of one exercise matters.
/// Versions past the last (loaded with a vest or belt) add a tenth each.
double versionShare(Exercise ex, int rung) {
  final v = ex.ladder!.variants;
  final shares = List<double?>.generate(v.length, (i) => measuredShare[v[i].name]);
  final known = shares.indexWhere((x) => x != null);
  if (known < 0) {
    for (var i = 0; i < v.length; i++) { shares[i] = 0.5 * pow(estimatedStep, i); }
  } else {
    for (var i = known - 1; i >= 0; i--) { shares[i] ??= shares[i + 1]! / estimatedStep; }
    for (var i = known + 1; i < v.length; i++) { shares[i] ??= shares[i - 1]! * estimatedStep; }
  }
  if (rung < 0) return shares.first!;
  if (rung < v.length) return shares[rung]!;
  return shares.last! * (1 + 0.1 * (rung - v.length + 1));
}

/// The load of a level of this exercise in today's reps: kilograms, or a version's share.
double levelLoad(AppState s, SessionExercise e, int rung) {
  final ex = e.exercise;
  if (!ex.loaded) return versionShare(ex, rung);
  return loadFor(s, ex, ensureState(s, ex), rung, e.range);
}

/// One set's load: the weight or the version it was done at.
double setLoad(AppState s, SessionExercise e, SetLog x) =>
    e.exercise.loaded ? (x.kg ?? e.loadKg ?? levelLoad(s, e, e.rung)) : versionShare(e.exercise, x.rung ?? e.rung);

double setScore(AppState s, SessionExercise e, SetLog x) => setLoad(s, e, x) * epley(x.reps ?? 0);

int _mid(SessionExercise e) => ((e.lo + e.hi) / 2).round();

/// The score that steps up from a level: the top of the range at this level, and at least the next level's floor.
double stepUpScore(AppState s, SessionExercise e, int rung) => max(levelLoad(s, e, rung) * epley(e.hi), levelLoad(s, e, rung + 1) * epley(e.lo));

/// The reps a set at this level needs to step up, or null at the top.
int? repsToStepUp(AppState s, SessionExercise e, {int? rung}) {
  final r = rung ?? ensureState(s, e.exercise).rung;
  if (e.atCeiling) return null;
  final here = levelLoad(s, e, r);
  if (here <= 0) return null;
  return (30 * (stepUpScore(s, e, r) / here - 1) - 1e-9).ceil();
}

enum Call { up, hold, down }

/// The direction of a call, in a word, as next time feels: harder, the same, easier.
const callWord = {Call.up: 'Harder', Call.hold: 'Same', Call.down: 'Easier'};

/// How a workout ended, as the app reads it or the user says. Finished: [done], [low] (finished but faded), and two the
/// user can say, [normal] and [easy]. Ended early: [time], [energy], [none]; [ask] when time and energy both fit.
enum EndRead { done, low, normal, easy, time, energy, none, ask }

/// Levels can step down only on a day read as a normal one.
bool downsCount(EndRead r) => r == EndRead.done || r == EndRead.normal || r == EndRead.time;

class ExerciseRead {
  ExerciseRead({required this.index, required this.judged, this.reason = ''});
  final int index;
  final bool judged;      // false: not started, skipped, rested for pain, or edited away from the plan
  final String reason;    // why not judged, in words
  double avg = 0, floor = 0, upAt = double.infinity, fade = 0;
  bool short = false;     // the average is under this level's floor
  bool worthUp = false;   // the average is worth stepping up
  bool proven = false;    // done at the next level, at its floor or better: it is yours today
  double progress = 0;    // from this level's floor (0) to stepping up (1): how close today came
  bool ceiling = false;   // at the top of what this place can do: judged by its best total
  Call auto = Call.hold;  // what the app concluded
  Call call = Call.hold;  // what happens: the app's, or the user's change
  int? toStepUp;          // reps a set at this level needs to be worth the next
  double? worthKg;        // loaded: the average as a weight at the middle of the range
  Map<Call, String> outcomes = {}; // each call as the level it lands on next time: '42.5 kg', 'Incline push-up'
  Map<Call, int> levels = {};      // each call as the rung it lands on
  String hint = '';       // what would move it, or why it moved, in one short sentence; may be empty
  String get outcome => outcomes[call] ?? '';
  bool get changed => call != auto;
}

class WorkoutRead {
  WorkoutRead(this.exercises, this.guess, this.end);
  final List<ExerciseRead> exercises;
  final EndRead guess;    // what the app concluded about how it ended
  final EndRead end;      // what counts: the user's word, else the guess; [ask] unanswered counts as no reason
  bool get finished => guess == EndRead.done || guess == EndRead.low;
}

EndRead? endReadOf(String? name) => name == null ? null : EndRead.values.where((r) => r.name == name).firstOrNull;

/// Every exercise in the plan done, every set of it. Time only shapes how many exercises a workout holds; an exercise
/// left out, skipped or cut short means it ended early.
bool finishedPlan(Session x) => x.exercises.every((e) => e.done);

/// The minutes from start to end, at least one.
int elapsedOf(Session x, DateTime now) => max(1, ((x.endedAt ?? now).difference(x.startedAt ?? now).inSeconds / 60).round());

/// The read of a workout as it stands: each exercise's score and what it means, and how it ended.
WorkoutRead readWorkout(AppState s, Session x, DateTime now) {
  final reads = [for (var i = 0; i < x.exercises.length; i++) _readExercise(s, x, i)];
  // calibration sets go to failure on purpose: they say nothing about how the day went
  final judged = reads.where((r) => r.judged && !r.ceiling && !x.exercises[r.index].sets.any((l) => l.test)).toList();
  final energy = judged.any((r) => r.fade >= 0.15 || r.short);
  final EndRead guess;
  if (finishedPlan(x)) {
    final fades = judged.where((r) => x.exercises[r.index].attempted.length > 1).map((r) => r.fade).toList();
    final mean = fades.isEmpty ? 0.0 : fades.reduce((a, b) => a + b) / fades.length;
    guess = mean >= 0.15 ? EndRead.low : EndRead.done;
  } else {
    final time = elapsedOf(x, now) >= 0.7 * x.timeMinutes;
    guess = time && energy ? EndRead.ask : time ? EndRead.time : energy ? EndRead.energy : EndRead.none;
  }
  var end = endReadOf(x.endRead) ?? guess;
  if (end == EndRead.ask) end = EndRead.none;
  final easyDay = x.energy == Energy.easy;
  for (final r in reads) {
    if (!r.judged) continue;
    final e = x.exercises[r.index];
    final st = ensureState(s, e.exercise);
    final downs = downsCount(end) && !easyDay && e.atWorkingLevel;
    final signal = st.appearances == 0 ? repSignalOf(e) : null;
    // still finding the level: reps over the top go straight to the level they are worth
    final tested = e.sets.any((l) => l.test);
    final jump = st.calibrating && !tested && !r.ceiling && !e.atCeiling ? impliedRung(s, x, e, st, r.avg) : null;
    if (r.ceiling || tested) {
      // calibration sets have already put the level where the reps said
      r.auto = Call.hold;
    } else if (st.appearances == 0 && !r.proven) {
      // a first time is taken as the right level unless the reps say plainly otherwise
      r.auto = (jump != null || signal == 'high') && !e.atCeiling ? Call.up : signal == 'low' ? Call.down : Call.hold;
    } else if (jump != null) {
      r.auto = Call.up;
    } else if (r.proven || (r.worthUp && (st.calibrating || st.decayedBy > 0 || st.topRun + 1 >= s.settings.stepUp))) {
      r.auto = Call.up;
    } else if (r.short && downs && st.shortRun + 1 >= s.settings.stepDown) {
      r.auto = Call.down;
    } else {
      r.auto = Call.hold;
    }
    r.levels = _levels(s, x, e, st, jump: jump);
    if (!r.levels.containsKey(r.auto)) r.auto = Call.hold;
    r.call = switch (e.call) { 'up' => Call.up, 'hold' => Call.hold, 'down' => Call.down, _ => r.auto };
    if (!r.levels.containsKey(r.call)) r.call = Call.hold;
    final eq = s.location(x.locationId)?.equipment ?? const <String>[];
    r.outcomes = {for (final c in r.levels.entries) c.key: rungLabel(s, e.exercise, st, c.value, e.range, eq)};
    r.hint = _hint(s, x, e, st, r, downs);
  }
  return WorkoutRead(reads, guess, end);
}

ExerciseRead _readExercise(AppState s, Session x, int i) {
  final e = x.exercises[i];
  final sets = e.attempted.toList();
  if (sets.isEmpty) return ExerciseRead(index: i, judged: false, reason: 'not started · not judged');
  if (x.painAt == i) return ExerciseRead(index: i, judged: false, reason: 'rests a week');
  final st = ensureState(s, e.exercise);
  if (e.edited && e.asPlanned != st.rung) return ExerciseRead(index: i, judged: false, reason: 'changed from your level · not judged');
  final r = ExerciseRead(index: i, judged: true);
  final scores = [for (final x in sets) setScore(s, e, x)];
  r.avg = scores.reduce((a, b) => a + b) / scores.length;
  // the fade in reps: the last set against the first, both read at the first set's load
  final load0 = setLoad(s, e, sets.first);
  double repsAt(double score) => 30 * (score / load0 - 1);
  r.fade = scores.length > 1 && load0 > 0 && repsAt(scores.first) > 0 ? (1 - repsAt(scores.last) / repsAt(scores.first)).clamp(0.0, 1.0) : 0;
  final here = levelLoad(s, e, st.rung);
  r.floor = here * epley(e.lo);
  r.ceiling = e.atCeiling && e.atWorkingLevel;
  if (!r.ceiling && !e.atCeiling) r.upAt = stepUpScore(s, e, st.rung);
  r.short = r.avg < r.floor;
  r.worthUp = r.avg >= r.upAt - 1e-9;
  if (r.upAt.isFinite && r.upAt > r.floor) r.progress = ((r.avg - r.floor) / (r.upAt - r.floor)).clamp(0.0, 1.0);
  final atNext = sets.every((x) => (x.rung ?? e.rung) > st.rung);
  r.proven = !e.atCeiling && atNext && r.avg >= levelLoad(s, e, st.rung + 1) * epley(e.lo) - 1e-9;
  r.toStepUp = r.ceiling ? null : repsToStepUp(s, e);
  if (e.exercise.loaded) r.worthKg = roundStep(r.avg / epley(_mid(e)), stepKg(s, e.exercise));
  return r;
}

/// Each call as the rung it lands on next time: one step either way, the level the reps were worth while calibrating
/// ([jump]), or the level the user picked for it.
Map<Call, int> _levels(AppState s, Session x, SessionExercise e, ExerciseState st, {int? jump}) {
  final range = nextRange(s, x, e);
  final picked = e.next;
  return {
    if (range.hi > st.rung) Call.up: picked != null && picked > st.rung && picked <= range.hi ? picked : min(jump ?? st.rung + 1, range.hi),
    Call.hold: st.rung,
    if (range.lo < st.rung) Call.down: picked != null && picked < st.rung && picked >= range.lo ? picked : st.rung - 1,
  };
}

/// The levels an exercise can be set to for next time, lowest first: from its floor to the top this place can do, or
/// for an open ladder a handful of steps above today.
({int lo, int hi}) nextRange(AppState s, Session x, SessionExercise e) {
  final ex = e.exercise;
  final st = ensureState(s, ex);
  final lo = ex.loaded ? floorRung(s, ex, st) : 0;
  final top = ceilingFor(ex, s.location(x.locationId)?.equipment ?? const <String>[]);
  return (lo: min(lo, st.rung), hi: max(st.rung, top ?? st.rung + 8));
}

/// The reps went over the top of the range: the average of the sets is more than [SessionExercise.hi]. Saying the level
/// was right settles it all the same.
bool overTop(SessionExercise e) {
  final sets = e.attempted.toList();
  if (sets.isEmpty || e.feel == Call.hold.name) return false;
  return sets.fold(0, (a, l) => a + (l.reps ?? 0)) / sets.length > e.hi;
}

/// Whether a workout found this exercise's level: the reps landed in the range or under it, the user said it was right,
/// or it is at the top of what this place can do, where the reps carry it. Until one does the exercise is calibrating.
bool foundLevel(SessionExercise e) => e.attempted.isNotEmpty && (e.atCeiling || !overTop(e));

/// While calibrating, the level a workout with reps over the top was worth: the heaviest level whose middle of the range
/// today's average still reaches. Null when the reps were not over the top or are not worth a level more.
int? impliedRung(AppState s, Session x, SessionExercise e, ExerciseState st, double avg) {
  if (!overTop(e)) return null;
  final hi = nextRange(s, x, e).hi;
  int? best;
  for (var k = st.rung + 1; k <= hi; k++) {
    if (levelLoad(s, e, k) * epley(_mid(e)) > avg + 1e-9) break;
    best = k;
  }
  return best;
}

/// What would move it, or why it moved, in one short sentence a newcomer can read. Empty when the outcome says it all.
String _hint(AppState s, Session x, SessionExercise e, ExerciseState st, ExerciseRead r, bool downs) {
  final ex = e.exercise;
  final eq = s.location(x.locationId)?.equipment ?? const <String>[];
  final unit = ex.repLabel == 'seconds' ? 'seconds' : 'reps';
  if (r.ceiling) {
    final total = e.total;
    return total > st.bestTotal ? '$total $unit in total, a new best.' : '$total $unit in total. Your best is ${st.bestTotal}.';
  }
  if (r.changed) return 'Your call.';
  switch (r.call) {
    case Call.up:
      return st.appearances == 0 ? 'A strong first go.' : '';
    case Call.down:
      return 'Under ${e.lo} $unit a set twice in a row.';
    case Call.hold:
      if (r.short && downs) return 'Under ${e.lo} $unit a set. Once more and it goes down.';
      if (r.short) return 'Under ${e.lo} $unit a set, but today doesn\'t count against you.';
      if (r.worthUp) {
        final left = s.settings.stepUp - st.topRun - 1;
        return '$left more ${left == 1 ? 'workout' : 'workouts'} like this and it goes up.';
      }
      if (r.toStepUp != null) return '${r.toStepUp} $unit a set moves you up to ${rungLabel(s, ex, st, st.rung + 1, e.range, eq)}.';
      return '';
  }
}

/// The one line under Logged: a level earned leads, else how the day was read.
String headline(AppState s, Session x, WorkoutRead w) {
  if (x.painAt != null && x.painAt! < x.exercises.length) return '${_name(x.exercises[x.painAt!])} rests a week.';
  for (final r in w.exercises) {
    if (r.judged && r.call == Call.up) {
      final e = x.exercises[r.index];
      final st = ensureState(s, e.exercise);
      return '${e.exercise.name}: up to ${rungLabel(s, e.exercise, st, st.rung + 1, e.range, s.location(x.locationId)?.equipment ?? const [])} next time.';
    }
  }
  return switch (w.end) {
    EndRead.low => 'A low-energy day. Nothing steps down.',
    EndRead.energy => 'Out of energy. Nothing steps down.',
    EndRead.easy => 'An easy day. Nothing steps down.',
    EndRead.time => 'Out of time. ${timeDefaultAfter(x)} min is the default now.',
    EndRead.none => 'Stopped. Nothing changes; what you did still counts.',
    _ => w.guess == EndRead.ask && x.endRead == null ? 'Ended early.' : 'Every level holds.',
  };
}

/// The minutes a time stop makes the default: the minutes the user actually had.
int timeDefaultAfter(Session x) => clampMinutes(max(minutesMin, x.elapsedMinutes ?? x.timeMinutes - 10));

/// What an ending read does, in one line.
String endEffect(Session x, EndRead r) => switch (r) {
      EndRead.time => 'Next time we\'ll plan about ${timeDefaultAfter(x)} min.',
      EndRead.energy || EndRead.low => 'Your levels stay put. If it happens again, we\'ll plan an easier day.',
      EndRead.easy => 'Your levels stay put.',
      EndRead.none => 'Nothing changes.',
      EndRead.normal || EndRead.done => 'Your sets count as they are.',
      EndRead.ask => 'Pick one, or leave it: nothing changes.',
    };

String _name(SessionExercise e) => e.exercise.ladder != null ? e.rungLabel : e.exercise.name;

/// The stop reason a read stands for, when the workout is logged: null for a finished one.
StopReason? stopReasonOf(EndRead r) => switch (r) {
      EndRead.time => StopReason.time,
      EndRead.energy || EndRead.low => StopReason.energy,
      EndRead.none || EndRead.ask => StopReason.none,
      _ => null,
    };

// ---- after the workout: looking back at a set's time ----

/// The first moment in the workout at or after [t]: a set starting, an item starting, or the end. At, not after: a rest
/// of nothing is the next set starting the moment this one ended.
DateTime? nextMomentAfter(Session x, DateTime t) {
  DateTime? best;
  void see(DateTime? m) { if (m != null && !m.isBefore(t) && (best == null || m.isBefore(best!))) best = m; }
  // an exercise started but never done has no row of its own: its time runs on as the rest before it
  for (final it in workoutItems(x)) {
    if (it.lifting && !it.exercises.any((i) => x.exercises[i].attempted.isNotEmpty)) continue;
    see(x.itemStarts[it.key]);
  }
  for (final e in x.exercises) { for (final s in e.sets) { see(s.start); } }
  see(x.endedAt);
  return best;
}

/// A done set's seconds, start to reps; null when it has no start.
int? setSecondsOf(Session x, SetRef r) {
  final s = setOf(x, r);
  return s.start == null || s.at == null ? null : s.at!.difference(s.start!).inSeconds;
}

/// The rest after a done set: until the next thing started.
int? restAfterOf(Session x, SetRef r) {
  final s = setOf(x, r);
  if (s.at == null) return null;
  final next = nextMomentAfter(x, s.at!);
  return next?.difference(s.at!).inSeconds;
}

/// Everything at or after [from] moves by [d]: later sets, later items, the end.
void _shift(Session x, DateTime from, Duration d) {
  if (d == Duration.zero) return;
  DateTime mv(DateTime t) => t.isBefore(from) ? t : t.add(d);
  x.itemStarts.updateAll((_, t) => mv(t));
  for (final e in x.exercises) {
    for (final s in e.sets) {
      if (s.start != null) s.start = mv(s.start!);
      if (s.at != null) s.at = mv(s.at!);
    }
  }
  if (x.endedAt != null) x.endedAt = mv(x.endedAt!);
}

/// Say a set took this long: its reps move to the new time, and everything after moves with them.
void setSetSeconds(Session x, SetRef r, int seconds) {
  final s = setOf(x, r);
  if (s.start == null || s.at == null) return;
  _shift(x, s.at!, s.start!.add(Duration(seconds: max(1, seconds))).difference(s.at!));
}

/// Say the rest after a set was this long: what came next, and everything after it, moves.
void setRestAfter(Session x, SetRef r, int seconds) {
  final s = setOf(x, r);
  if (s.at == null) return;
  final next = nextMomentAfter(x, s.at!);
  if (next == null) return;
  final end = s.at!;
  _shift(x, next, end.add(Duration(seconds: max(0, seconds))).difference(next));
  s.at = end; // the set itself keeps its end when the rest after it was nothing
}

/// Change a done set's weight or version afterwards. Only that set.
void fixSetLevel(AppState st, Session x, SetRef r, {double? kg, int? rung}) {
  final s = setOf(x, r);
  if (!s.attempted) return;
  final e = x.exercises[r.ex];
  if (e.exercise.loaded && kg != null) {
    s.kg = kg;
    s.rung = rungForLoad(st, e.exercise, ensureState(st, e.exercise), kg, e.range);
  } else if (!e.exercise.loaded && rung != null) {
    s.rung = rung;
  }
}

/// End: the clock stops and the workout waits on Logged, where its reads can be changed before they count. A set under
/// way is dropped.
void endWorkout(Session x, DateTime now) {
  resumeWorkout(x, now);
  for (final e in x.exercises) {
    for (final s in e.sets) { if (s.lifting) s.start = null; }
  }
  x.endedAt = now;
  x.reviewing = true;
}

/// Back to the workout from Logged: the time on Logged counts as a pause.
void reopenWorkout(Session x, DateTime now) {
  x.reviewing = false;
  x.pausedAt = x.endedAt;
  x.endedAt = null;
  resumeWorkout(x, now);
}

/// A timed part's seconds (warm-up, cardio, stretching): from its start until the next thing started. Null when it
/// never started.
int? itemSecondsOf(Session x, WorkoutItem it, DateTime now) {
  final start = x.itemStarts[it.key];
  return start == null ? null : itemEnd(x, it, x.endedAt ?? now).difference(start).inSeconds;
}

/// Say a timed part took this long: what came after it, and the end, move with it.
void setItemSeconds(Session x, WorkoutItem it, int seconds, DateTime now) {
  final start = x.itemStarts[it.key];
  if (start == null) return;
  final end = itemEnd(x, it, x.endedAt ?? now);
  _shift(x, end, start.add(Duration(seconds: max(0, seconds))).difference(end));
}

/// The workout's time as the check adds it up: every timed part, and every set with the rest after it.
int checkSeconds(Session x, DateTime now) {
  var total = 0;
  for (final it in workoutItems(x)) {
    if (!it.lifting) { total += itemSecondsOf(x, it, now) ?? 0; continue; }
    for (final i in it.exercises) {
      final e = x.exercises[i];
      for (var k = 0; k < e.sets.length; k++) {
        if (!e.sets[k].attempted) continue;
        total += (setSecondsOf(x, (ex: i, set: k)) ?? 0) + (restAfterOf(x, (ex: i, set: k)) ?? 0);
      }
    }
  }
  return total;
}

// ---- the finish: what went well today, against last time ----

enum WinKind { levelUp, heavier, moreReps, firstTime }

/// One thing that went well, for the finish screen: a level earned, more weight or reps than last time, or a first.
class Win {
  const Win(this.index, this.kind, this.text);
  final int index;    // the exercise
  final WinKind kind;
  final String text;  // "+4 reps on last time", "42.5 kg, up from 40 kg"
}

/// The exercise as it was done the last time before this workout, or null when it never was.
SessionExercise? lastTimeOf(AppState s, String exId, Session current) {
  for (final p in s.sessions.reversed) {
    if (identical(p, current)) continue;
    for (final e in p.exercises) { if (e.exId == exId && e.attempted.isNotEmpty) return e; }
  }
  return null;
}

/// What went well, in order: levels earned, then more than last time, then firsts. An exercise counts once, by its
/// best win; one that held steady is not listed.
List<Win> winsOf(AppState s, Session x, WorkoutRead w) {
  final out = <Win>[];
  final eq = s.location(x.locationId)?.equipment ?? const <String>[];
  for (final r in w.exercises) {
    final e = x.exercises[r.index];
    if (e.attempted.isEmpty || x.painAt == r.index) continue;
    final ex = e.exercise;
    final st = ensureState(s, ex);
    // a level the app earned; the user's own Harder is their call, not a win
    if (r.judged && r.call == Call.up && !r.changed) { out.add(Win(r.index, WinKind.levelUp, 'Harder next time: ${r.outcome}')); continue; }
    final prev = lastTimeOf(s, e.exId, x);
    if (prev == null) { out.add(Win(r.index, WinKind.firstTime, 'A new one for the log')); continue; }
    double top(SessionExercise q) => q.attempted.map((l) => setLoad(s, q, l)).reduce(max);
    final now = top(e), then = top(prev);
    String level(SessionExercise q) {
      final l = q.attempted.reduce((a, b) => setLoad(s, q, a) >= setLoad(s, q, b) ? a : b);
      return ex.loaded ? fmtLoad(s, ex, l.kg ?? q.loadKg ?? 0, equipment: eq) : rungLabel(s, ex, st, l.rung ?? q.rung, q.range, eq);
    }
    if (now > then * 1.001) {
      out.add(Win(r.index, WinKind.heavier, ex.loaded ? '${level(e)}, up from ${level(prev)}' : '${level(e)}, up from ${level(prev)}'));
    } else if ((now - then).abs() <= then * 0.001 && e.total > prev.total) {
      final unit = ex.repLabel == 'seconds' ? 'seconds' : e.total - prev.total == 1 ? 'rep' : 'reps';
      out.add(Win(r.index, WinKind.moreReps, '${e.total - prev.total} more $unit than last time'));
    }
  }
  out.sort((a, b) => a.kind.index.compareTo(b.kind.index));
  return out;
}

/// How many workouts in the seven days up to this one, this one included.
int workoutsThisWeek(AppState s, Session x) {
  final at = x.startedAt ?? DateTime.now();
  return 1 + s.sessions.where((p) => !identical(p, x) && p.startedAt != null && at.difference(p.startedAt!).inDays < 7 && !p.startedAt!.isAfter(at)).length;
}

// ---- the finish's expression: what the app noticed, and the tone that fits it ----

/// What the app noticed about one exercise.
enum Moment { pushed, levelUp, better, steady, reached, short, eased, first, hurt }

class ExerciseMoment {
  const ExerciseMoment(this.index, this.moment, this.text);
  final int index;
  final Moment moment;
  final String text; // one plain line: what happened, never a slogan
}

/// The tone of the whole finish, from the most telling moment.
enum Tone { celebrate, pleased, proud, encourage, steady, brief, curious }

/// Each exercise done, with what the app noticed: chose more and made it, a level, more than last time, held, reached
/// for more and not yet, fell short, eased off, a first, or a hurt.
List<ExerciseMoment> momentsOf(AppState s, Session x, WorkoutRead w) {
  final out = <ExerciseMoment>[];
  final eq = s.location(x.locationId)?.equipment ?? const <String>[];
  final wins = {for (final v in winsOf(s, x, w)) v.index: v};
  for (final r in w.exercises) {
    final e = x.exercises[r.index];
    if (e.attempted.isEmpty) continue;
    final ex = e.exercise;
    final st = ensureState(s, ex);
    final unit = ex.repLabel == 'seconds' ? 'seconds' : 'reps';
    String label(SetLog l) => ex.loaded ? fmtLoad(s, ex, l.kg ?? e.loadKg ?? 0, equipment: eq) : rungLabel(s, ex, st, l.rung ?? e.rung, e.range, eq);
    if (x.painAt == r.index) { out.add(ExerciseMoment(r.index, Moment.hurt, 'Something hurt. It rests a week.')); continue; }
    // calibration sets moved the weight, not the user: what found it, said plainly, never celebrated as a push
    final tests = [for (final l in e.attempted) if (l.test) l];
    if (tests.isNotEmpty) {
      final found = tests.where((l) => (l.reps ?? 0) > 0 && l.reps! < calibrationCap).firstOrNull;
      out.add(ExerciseMoment(r.index, Moment.first, found != null
          ? '${found.reps} ${found.reps == 1 ? 'rep' : 'reps'} at ${label(found)} found it.'
          : '$calibrationCap reps at ${label(tests.last)}, still more to find.'));
      continue;
    }
    // the plan's level against what was done: above it is the user's own choice, below it easing off
    final planned = ex.loaded ? (e.plannedKg ?? e.loadKg ?? 0) : (e.plannedRung ?? e.rung).toDouble();
    double levelOf(SetLog l) => ex.loaded ? (l.kg ?? e.loadKg ?? 0) : (l.rung ?? e.rung).toDouble();
    final sets = e.attempted.toList();
    final above = sets.where((l) => levelOf(l) > planned + 1e-6).toList();
    final below = sets.where((l) => levelOf(l) < planned - 1e-6).toList();
    final topReps = sets.map((l) => l.reps ?? 0).reduce(max);
    if (above.isNotEmpty) {
      final best = above.reduce((a, b) => levelOf(a) >= levelOf(b) ? a : b);
      final made = above.every((l) => (l.reps ?? 0) >= e.lo);
      out.add(made
          ? ExerciseMoment(r.index, Moment.pushed, ex.loaded ? 'Went up to ${label(best)} yourself and made every set.' : 'Took on ${label(best)} yourself and made every set.')
          : ExerciseMoment(r.index, Moment.reached, 'Reached for ${label(best)}. Not there yet.'));
      continue;
    }
    // a first time sets a starting point: not a level earned, so not celebrated; where it starts next time is a fact
    final did = '${sets.map((l) => l.reps ?? 0).join(', ')}${ex.loaded ? ' at ${label(sets.first)}' : ''}';
    if (st.appearances == 0) {
      out.add(ExerciseMoment(r.index, Moment.first, '$did.'));
      continue;
    }
    // a level the app earned; one the user asked for is their call, said by the row's word, not celebrated
    // where it lands is next time's chip; the line says what earned it
    if (r.judged && r.call == Call.up && !r.changed) { out.add(ExerciseMoment(r.index, Moment.levelUp, 'Every set at the top: ${sets.map((l) => l.reps ?? 0).join(', ')}.')); continue; }
    final win = wins[r.index];
    // easing off is the user's own choice: said before anything else about the exercise
    if (below.isNotEmpty) { out.add(ExerciseMoment(r.index, Moment.eased, 'Eased to ${label(below.first)} partway through.')); continue; }
    if (win != null && win.kind == WinKind.firstTime) { out.add(ExerciseMoment(r.index, Moment.first, 'First time with this one.')); continue; }
    if (win != null) { out.add(ExerciseMoment(r.index, Moment.better, win.text[0].toUpperCase() + win.text.substring(1))); continue; }
    if (topReps > e.hi) { out.add(ExerciseMoment(r.index, Moment.pushed, 'Went past the top of the range: $topReps $unit on your best set.')); continue; }
    if (r.short) {
      final got = sets.map((l) => l.reps ?? 0).toSet().length == 1 ? '${sets.first.reps} a set' : sets.map((l) => l.reps ?? 0).join(', ');
      // what next time does is the row's own word (Harder, Same, Easier), so the line only says what happened
      out.add(ExerciseMoment(r.index, Moment.short, 'Got $got, aiming for ${e.lo}.'));
      continue;
    }
    final at = sets.map(label).toSet();
    // what moves it up, only when today came genuinely close
    out.add(ExerciseMoment(r.index, Moment.steady, '${ex.loaded ? 'Stayed at ${at.length == 1 ? at.first : label(sets.first)}' : 'Same version'}: ${sets.map((l) => l.reps ?? 0).join(', ')}.${r.toStepUp != null && r.progress >= 0.6 ? ' ${r.toStepUp} $unit a set moves you up.' : ''}'));
  }
  return out;
}

/// The tone of the finish: the user's own push leads, then a level, then more than last time; a hard day is met
/// with pride, a short one with encouragement, an ordinary one with calm.
Tone toneOf(List<ExerciseMoment> m, WorkoutRead w) {
  bool any(Moment k) => m.any((v) => v.moment == k);
  if (any(Moment.pushed) || any(Moment.levelUp)) return Tone.celebrate;
  if (any(Moment.better)) return Tone.pleased;
  if (any(Moment.reached)) return Tone.encourage; // reaching for more is its own thing, not a hard day
  if (w.end == EndRead.low || w.end == EndRead.energy) return Tone.proud;
  if (w.end == EndRead.time) return Tone.brief;
  if (any(Moment.short)) return Tone.encourage;
  if (m.isNotEmpty && m.every((v) => v.moment == Moment.first)) return Tone.curious;
  return Tone.steady;
}

/// The headline for a tone, specific to what happened.
String toneHeadline(Tone t, List<ExerciseMoment> m) {
  final levels = m.where((v) => v.moment == Moment.levelUp).length;
  final pushedWeight = m.any((v) => v.moment == Moment.pushed && (v.text.startsWith('Went up') || v.text.startsWith('Took on')));
  return switch (t) {
    Tone.celebrate => m.any((v) => v.moment == Moment.pushed)
        ? (pushedWeight ? 'You went heavier, and made it.' : 'You pushed past the plan.')
        : levels == 1 ? 'New level earned.' : '${const ['', '', 'Two', 'Three', 'Four', 'Five', 'Six'].elementAtOrNull(levels) ?? '$levels'} new levels.',
    Tone.pleased => 'More than last time.',
    Tone.proud => 'You showed up on a hard day.',
    Tone.encourage => m.any((v) => v.moment == Moment.reached) ? 'You reached for more.' : 'Tough sets today. They still count.',
    Tone.steady => m.any((v) => v.moment == Moment.eased) ? 'Eased off where you needed to.' : 'Steady work. That\'s how it builds.',
    Tone.brief => 'Short, and still done.',
    Tone.curious => 'New ground today.',
  };
}

/// The last line, for a tone: rest, and what comes next. Closure, not a task.
String toneSignOff(Tone t) => switch (t) {
      Tone.celebrate => 'Rest well. You earned it.',
      Tone.pleased => 'Rest up. Keep it rolling.',
      Tone.proud => 'Rest up. Next time can be easier.',
      Tone.encourage => 'Rest up. Same plan next time, fresh start.',
      Tone.curious => 'Rest up. Your levels settle in as you go.',
      _ => 'Rest up. Your next workout will be ready.',
    };

/// Whether today's reps say the rep band may not suit this exercise: well past the top of the range ('high'), or well
/// under the bottom ('low'). Only then is the user asked how they like it. Null when the reps landed about right.
String? repSignalOf(SessionExercise e) {
  final sets = e.attempted.toList();
  if (sets.isEmpty) return null;
  final avg = sets.fold(0, (a, l) => a + (l.reps ?? 0)) / sets.length;
  if (avg >= e.hi + 3) return 'high';
  if (avg <= e.lo - 2) return 'low';
  return null;
}

/// The rep band an exercise was done in today.
Expression bandOf(SessionExercise e) =>
    Expression.values.firstWhere((x) => expressionRange[x]!.lo <= e.lo && e.lo <= expressionRange[x]!.hi, orElse: () => Expression.middle);
