// The muscle map: the app's one view of the body. The muscles by the names people use, and strain points, how much
// work each muscle has taken (0.00 to 1.00) and how much of it is still there. Strain points are never stored: they
// are worked out from the logged sets every time, so the figure, the timeline and the builder always agree.
// MUSCLE_MAP.md.
import 'dart:math';

import '../data/index.dart';
import '../data/library.dart';
import '../data/model.dart';
import 'person.dart';

/// Strain points from one working set, on each primary muscle of its exercise and on each secondary one.
const strainPointsPrimarySet = 0.20;
const strainPointsSecondarySet = 0.10;
/// A light set gives this share of a working set's strain points.
const strainPointsLightShare = 0.5;
/// Secondary work tops out here in one workout (or one exercise).
const strainPointsSecondaryMax = 0.50;
/// A muscle tops out here, in one workout and in what it carries.
const strainPointsMax = 1.0;
/// Strain point decay: what comes off at the start of each calendar day. A third, so a muscle drops one shade a day.
const strainPointDecayPerDay = 1 / 3;
/// The shades strain points are drawn in, low, medium and high, each an exact third of 0 to 1.
const strainShades = 3;
const strainShadeLabels = ['high', 'medium', 'low'];
/// The strain points timeline: how many days back it goes.
const strainTimelineDays = 30;

const _eps = 1e-9;

/// The shade of some strain points: 0 strain-free, 1 low (0.01 to 0.33), 2 medium (to 0.66), 3 high (to 1.00).
/// With the decay a third a day, it is also how many days the muscle needs to be strain-free.
int strainShade(double points) => points <= _eps ? 0 : (points * strainShades - _eps).ceil().clamp(1, strainShades);

/// Strain points as they are written: two decimals.
String strainPointsText(double points) => points.toStringAsFixed(2);

/// Strain points per muscle. Muscles at 0.00 are left out.
class StrainPoints {
  StrainPoints([Map<String, double> byMuscle = const {}])
      : byMuscle = Map.unmodifiable({for (final e in byMuscle.entries) if (e.value > _eps) e.key: min(strainPointsMax, e.value)});
  final Map<String, double> byMuscle;

  static final none = StrainPoints();

  double operator [](String muscle) => byMuscle[muscle] ?? 0;
  Iterable<String> get muscles => byMuscle.keys;
  bool get isEmpty => byMuscle.isEmpty;
  int shade(String muscle) => strainShade(this[muscle]);
  bool strainFree(String muscle) => this[muscle] <= _eps;

  /// Muscle by muscle, added and capped at 1.00.
  StrainPoints plus(StrainPoints other) {
    final out = {...byMuscle};
    for (final e in other.byMuscle.entries) { out[e.key] = (out[e.key] ?? 0) + e.value; }
    return StrainPoints(out);
  }

  /// After [days] of strain point decay.
  StrainPoints decayed(int days) {
    if (days <= 0) return this;
    return StrainPoints({for (final e in byMuscle.entries) e.key: e.value - days * strainPointDecayPerDay});
  }

  /// The muscles, most strained first, then by the order of the muscle names.
  List<String> ranked() => muscles.toList()
    ..sort((a, b) { final c = this[b].compareTo(this[a]); return c != 0 ? c : muscleNames.indexOf(a).compareTo(muscleNames.indexOf(b)); });

  /// The highest shade among [names]: 0 when every one is strain-free.
  int highestShade(Iterable<String> names) => names.fold(0, (a, m) => max(a, shade(m)));
}

/// Primary and secondary strain points kept apart until the limits are applied.
class _Tally {
  final primary = <String, double>{};
  final secondary = <String, double>{};

  void add(Exercise ex, double sets, {bool light = false}) {
    if (sets <= 0) return;
    final share = light ? strainPointsLightShare : 1.0;
    for (final m in ex.primary) { primary[m] = (primary[m] ?? 0) + sets * strainPointsPrimarySet * share; }
    for (final m in ex.secondary) {
      if (ex.primary.contains(m)) continue;
      secondary[m] = (secondary[m] ?? 0) + sets * strainPointsSecondarySet * share;
    }
  }

  /// Secondary work up to 0.50, each muscle up to 1.00.
  StrainPoints get points => StrainPoints({
        for (final m in {...primary.keys, ...secondary.keys}) m: (primary[m] ?? 0) + min(strainPointsSecondaryMax, secondary[m] ?? 0),
      });
}

/// Strain points from set: what one set of [ex] gives each of its muscles.
StrainPoints strainPointsFromSet(Exercise ex, {bool light = false}) => (_Tally()..add(ex, 1, light: light)).points;

/// Strain points from [sets] sets of [ex], under the limits of one workout: what an exercise on a plan will give.
StrainPoints strainPointsFromSets(Exercise ex, int sets, {bool light = false}) => (_Tally()..add(ex, sets.toDouble(), light: light)).points;

int _sets(SessionExercise e, bool planned) => planned ? e.sets.length : e.attempted.length;

/// Strain points from exercise: its sets (every set when [planned], else the attempted ones), under the limits.
StrainPoints strainPointsFromExercise(SessionExercise e, {bool planned = false}) =>
    strainPointsFromSets(e.exercise, _sets(e, planned), light: e.intent == 'light');

/// Strain points from workout: every exercise's sets added up per muscle, secondary work up to 0.50, each muscle up to
/// 1.00. Movement workouts give none.
StrainPoints strainPointsFromWorkout(Session x, {bool planned = false}) {
  if (x.type != 'lift') return StrainPoints.none;
  return strainPointsFromPlan([for (final e in x.exercises) (exercise: e.exercise, sets: _sets(e, planned), light: e.intent == 'light')]);
}

/// Strain points from workout for a list still being built: exercises and their sets, under the same limits.
StrainPoints strainPointsFromPlan(Iterable<({Exercise exercise, int sets, bool light})> plan) {
  final t = _Tally();
  for (final p in plan) { t.add(p.exercise, p.sets.toDouble(), light: p.light); }
  return t.points;
}

/// The day a moment counts on.
DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// One day of the strain points timeline: the current strain points at the end of [day], and the workouts that day
/// with the strain points each gave.
class StrainDay {
  const StrainDay(this.day, this.points, this.workouts);
  final DateTime day;
  final StrainPoints points;
  final List<({Session session, StrainPoints points})> workouts;
}

/// The muscle map over the state: everything about strain points over time.
class MuscleMap {
  MuscleMap(this.s);
  final AppState s;

  /// The finished lifting workouts, oldest first.
  List<Session> get _workouts => s.sessions.where((x) => x.type == 'lift' && x.endedAt != null).toList()
    ..sort((a, b) => a.endedAt!.compareTo(b.endedAt!));

  /// Current strain points at [at]: every workout finished by then, its strain points from workout added to what was
  /// left after the decay, capped at 1.00.
  StrainPoints currentStrainPoints(DateTime at) {
    var points = StrainPoints.none;
    DateTime? day;
    for (final x in _workouts) {
      if (x.endedAt!.isAfter(at)) break;
      final d = dayOf(x.endedAt!);
      if (day != null) points = points.decayed(daysBetween(day, d));
      points = points.plus(strainPointsFromWorkout(x));
      day = d;
    }
    return day == null ? points : points.decayed(daysBetween(day, at));
  }

  /// The strain points timeline: one entry per day from [from] to [to], both included, oldest first.
  List<StrainDay> strainPointsTimeline(DateTime from, DateTime to) {
    final first = dayOf(from), last = dayOf(to);
    final byDay = <DateTime, List<Session>>{};
    for (final x in _workouts) { byDay.putIfAbsent(dayOf(x.endedAt!), () => []).add(x); }
    // what was carried into the first day
    var points = currentStrainPoints(first.subtract(const Duration(milliseconds: 1)));
    var prev = first.subtract(const Duration(days: 1));
    final out = <StrainDay>[];
    for (var d = first; !d.isAfter(last); d = DateTime(d.year, d.month, d.day + 1)) {
      points = points.decayed(daysBetween(prev, d));
      final workouts = [for (final x in byDay[d] ?? const <Session>[]) (session: x, points: strainPointsFromWorkout(x))];
      for (final w in workouts) { points = points.plus(w.points); }
      out.add(StrainDay(d, points, workouts));
      prev = d;
    }
    return out;
  }

  /// The day [muscle] will be strain-free, from [now]: today when it already is.
  DateTime strainFreeOn(String muscle, DateTime now) {
    final days = currentStrainPoints(now).shade(muscle);
    final d = dayOf(now);
    return DateTime(d.year, d.month, d.day + days);
  }

  /// When each muscle was last worked, or null.
  Map<String, DateTime?> lastWorked() {
    final out = <String, DateTime?>{for (final m in trackedMuscles) m: null};
    for (final x in _workouts) {
      for (final m in strainPointsFromWorkout(x).muscles) { out[m] = x.endedAt; }
    }
    return out;
  }
}

/// A day in words, from [now]: "today", "tomorrow", "Thursday", or "Thu 23 Oct" past the coming week.
String dayText(DateTime day, DateTime now) {
  final d = daysBetween(now, day);
  if (d == 0) return 'today';
  if (d == 1) return 'tomorrow';
  const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  if (d > 1 && d < 7) return names[day.weekday - 1];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${names[day.weekday - 1].substring(0, 3)} ${day.day} ${months[day.month - 1]}';
}
