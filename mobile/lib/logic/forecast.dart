// The forecast: what the rules will actually do, by running them. The next [workouts] strength workouts from the
// user's state as it is, on a copy, every set done at the top of its range, at the usual minutes and location, each
// built with the picker's defaults. Per muscle: how many of those workouts work it directly and help it, which
// exercises helped it, and so about every how many workouts its turn comes. SELECTION.md, "The forecast".
import 'dart:convert';

import '../data/index.dart';
import '../data/model.dart';
import 'after.dart';
import 'builder.dart';
import 'muscle_map.dart';
import 'muscle_plan.dart';

const forecastWorkouts = 12;

class Forecast {
  Forecast({required this.workouts, required this.direct, required this.helped, required this.helpedBy, required this.names, required this.recovering});
  final int workouts;
  final Map<String, int> direct;            // workouts that worked the muscle as a main muscle
  final Map<String, int> helped;            // workouts that worked or helped it
  final Map<String, List<String>> helpedBy; // the exercises that helped it, most often first
  final List<String> names;                 // the workouts' names, in order
  final Map<String, int> recovering;

  int directOf(String m) => direct[m] ?? 0;
  int helpedOf(String m) => helped[m] ?? 0;

  /// About every how many workouts the muscle is worked directly, or null when never in the forecast.
  double? every(String m) => directOf(m) == 0 ? null : workouts / directOf(m);

  /// "about every 3 workouts", "every workout", "not in the next 12 workouts".
  String everyText(String m) {
    final e = every(m);
    if (e == null) return 'not in the next $workouts workouts';
    if (e < 1.5) return 'every workout';
    return 'about every ${e.round()} workouts';
  }

  /// "helped by rows and deadlifts", or "helped by nothing you do here".
  String helpedByText(String m) {
    final by = helpedBy[m] ?? const [];
    if (by.isEmpty) return 'no help in the next $workouts workouts here';
    return 'helped by ${by.take(3).join(', ')}';
  }

  /// The one line: how the active muscles come round.
  String summary(GoalConfig g) {
    final actives = g.activeMuscles;
    if (actives.isEmpty) return 'No active muscles: nothing gets an exercise of its own.';
    final worked = actives.where((m) => directOf(m) > 0).toList();
    if (worked.isEmpty) return 'No active muscles worked in the next $workouts workouts here.';
    final avg = worked.fold(0.0, (a, m) => a + every(m)!) / worked.length;
    final missing = actives.length - worked.length;
    return 'Your ${actives.length} active muscles come round about every ${avg.round()} workouts'
        '${missing > 0 ? ', $missing not in the next $workouts' : ''}.';
  }
}

/// Run the next [workouts] strength workouts on a copy of [s]: each built with the picker's defaults at [minutes] (the
/// plan's default) at [locationId] (the last one), every set done at the top of its range, finished and learned from.
Forecast forecast(AppState s, DateTime now, {int workouts = forecastWorkouts, int? minutes, String? locationId}) {
  final copy = AppState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
  final mins = clampMinutes(minutes ?? copy.plan!.timeDefault);
  final loc = locationId ?? copy.lastLocationId ?? copy.locations.firstOrNull?.id;
  final days = copy.profile?.daysPerWeek ?? 3;
  final gap = (7 / days).clamp(1, 7).toDouble();
  final direct = <String, int>{};
  final helped = <String, int>{};
  final helpers = <String, Map<String, int>>{};
  final recovering = <String, int>{};
  final names = <String>[];
  var at = now;
  for (var i = 0; i < workouts; i++) {
    if (i > 0) at = at.add(Duration(hours: (gap * 24).round()));
    final strain = MuscleMap(copy).currentStrainPoints(at);
    final states = defaultMuscleStates(strain, copy.goal);
    for (final m in copy.goal!.activeMuscles) {
      if (!strain.strainFree(m)) recovering[m] = (recovering[m] ?? 0) + 1;
    }
    final x = buildSession(copy, BuildOptions(
      energy: Energy.normal, minutes: mins, locationId: loc, liftInstead: true,
      excluded: musclesIn(states, MuscleState.excluded).toSet(),
      exerciseCount: copy.settings.timeLimit ? null : copy.goal!.exercises.ideal,
      warmupMinutes: copy.settings.warmup,
    ), at);
    if (x.type != 'lift' || x.exercises.isEmpty) { names.add(x.name); continue; }
    names.add(x.name);
    final workedHere = <String>{}, helpedHere = <String>{};
    for (final e in x.exercises) {
      workedHere.addAll(e.exercise.primary);
      helpedHere.addAll([...e.exercise.primary, ...e.exercise.secondary]);
      for (final m in {...e.exercise.primary, ...e.exercise.secondary}) {
        final h = helpers.putIfAbsent(m, () => {});
        h[e.exercise.name] = (h[e.exercise.name] ?? 0) + 1;
      }
    }
    for (final m in workedHere) { direct[m] = (direct[m] ?? 0) + 1; }
    for (final m in helpedHere) { helped[m] = (helped[m] ?? 0) + 1; }
    startSession(copy, x, at);
    var clock = at;
    for (var k = 0; k < x.exercises.length; k++) {
      for (var j = 0; j < x.exercises[k].sets.length; j++) {
        clock = clock.add(const Duration(seconds: 120));
        logSet(x, k, x.exercises[k].target, clock);
      }
    }
    finishSession(copy, x, Finish(), clock);
  }
  return Forecast(
    workouts: workouts, direct: direct, helped: helped, names: names, recovering: recovering,
    helpedBy: {
      for (final m in trackedMuscles)
        m: ((helpers[m] ?? {}).entries.toList()..sort((a, b) => b.value.compareTo(a.value))).map((e) => e.key).toList(),
    },
  );
}
