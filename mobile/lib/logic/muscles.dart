// Muscles over time: what recent workouts worked, fading over a few days, and what a planned workout targets. Also
// the level history of one exercise, so progress can be felt as weights and versions rather than counted as levels.
// Pure functions over the state; nothing here changes a level or a pick.
import 'dart:math';

import '../data/index.dart';
import '../data/library.dart';
import '../data/model.dart';
import 'ladder.dart';

/// The muscle-map dataset's 17 groups folded onto the app's eleven. The shin (tibialis) has no group and never highlights.
const datasetToAppGroup = {
  'abdominals': 'Core', 'abductors': 'Glutes', 'adductors': 'Quads', 'biceps': 'Biceps', 'calves': 'Calves', 'chest': 'Chest',
  'forearms': 'Forearms', 'glutes': 'Glutes', 'hamstrings': 'Hamstrings', 'lats': 'Back', 'lower back': 'Core', 'middle back': 'Back',
  'quadriceps': 'Quads', 'shoulders': 'Shoulders', 'traps': 'Back', 'triceps': 'Triceps',
};

String? appGroupOf(String datasetGroup) => datasetToAppGroup[datasetGroup];

/// A library muscle name as the dataset spells it.
String datasetGroupOf(String libraryMuscle) => switch (libraryMuscle) { 'middleback' => 'middle back', 'lowerback' => 'lower back', _ => libraryMuscle };

/// The muscles a workout uses, by dataset group: the exercises' primary muscles strong, their secondary ones light.
Map<String, double> workoutMuscles(Session x) {
  final out = <String, double>{};
  if (x.type != 'lift') return out;
  for (final e in x.exercises) {
    for (final m in e.exercise.primary) { out[datasetGroupOf(m)] = 1.0; }
    for (final m in e.exercise.secondary) { final g = datasetGroupOf(m); out[g] = max(out[g] ?? 0, 0.5); }
  }
  return out;
}

/// An app-group map spread over the dataset groups it folds, for the figure.
Map<String, double> byDatasetGroup(Map<String, double> byApp) =>
    {for (final e in datasetToAppGroup.entries) if ((byApp[e.value] ?? 0) > 0) e.key: byApp[e.value]!};

/// A muscle group's work fades to nothing over this many days.
const muscleFadeDays = 5;
/// Credits that count as fully worked: about two exercises of three sets on the group.
const muscleFullCredits = 6.0;

/// Credits per muscle group for one exercise: a set credits the first primary group one point and each secondary
/// group half a point; light sets credit half of that. [planned] counts every set, otherwise the attempted ones.
Map<String, double> exerciseCredits(SessionExercise e, {bool planned = false}) {
  final ex = e.exercise;
  final sets = planned ? e.sets.length : e.attempted.length;
  if (sets == 0) return const {};
  final weight = e.intent == 'light' ? 0.5 : 1.0;
  final out = <String, double>{};
  if (ex.primary.isNotEmpty) out[muscleGroup(ex.primary.first)] = sets * weight;
  for (final m in ex.secondary) {
    final g = muscleGroup(m);
    out[g] = (out[g] ?? 0) + sets * weight * 0.5;
  }
  return out;
}

Map<String, double> sessionCredits(Session x, {bool planned = false}) {
  final out = <String, double>{};
  if (x.type != 'lift') return out;
  for (final e in x.exercises) {
    for (final c in exerciseCredits(e, planned: planned).entries) { out[c.key] = (out[c.key] ?? 0) + c.value; }
  }
  return out;
}

double _fade(int daysAgo) => max(0, 1 - daysAgo / muscleFadeDays);

int daysAgo(DateTime at, DateTime now) => DateTime(now.year, now.month, now.day).difference(DateTime(at.year, at.month, at.day)).inDays;

/// How worked each group is right now, 0 to 1: recent credits, faded by the days since, against a full day's work.
Map<String, double> recentWork(AppState s, DateTime now) {
  final sum = <String, double>{};
  for (final x in s.sessions) {
    if (x.endedAt == null) continue;
    final d = daysAgo(x.endedAt!, now);
    if (d < 0 || d >= muscleFadeDays) continue;
    for (final c in sessionCredits(x).entries) { sum[c.key] = (sum[c.key] ?? 0) + c.value * _fade(d); }
  }
  return {for (final g in muscleGroups) g: ((sum[g] ?? 0) / muscleFullCredits).clamp(0.0, 1.0)};
}

/// When each group was last worked, or null.
Map<String, DateTime?> lastWorked(AppState s) {
  final out = <String, DateTime?>{for (final g in muscleGroups) g: null};
  for (final x in s.sessions) {
    if (x.endedAt == null) continue;
    for (final g in sessionCredits(x).keys) {
      if (out[g] == null || x.endedAt!.isAfter(out[g]!)) out[g] = x.endedAt;
    }
  }
  return out;
}

/// What a planned workout targets, 0 to 1 per group.
Map<String, double> plannedTargets(Session x) {
  final c = sessionCredits(x, planned: true);
  final top = c.values.fold(0.0, max);
  return {for (final e in c.entries) e.key: top == 0 ? 0 : (e.value / top).clamp(0.0, 1.0)};
}

/// Credits per day for one group over the last [days] days, oldest first. The timeline strip.
List<double> dayStrip(AppState s, String group, DateTime now, {int days = 14}) {
  final out = List<double>.filled(days, 0);
  for (final x in s.sessions) {
    if (x.endedAt == null) continue;
    final d = daysAgo(x.endedAt!, now);
    if (d < 0 || d >= days) continue;
    out[days - 1 - d] += sessionCredits(x)[group] ?? 0;
  }
  return out;
}

String agoText(DateTime? at, DateTime now) {
  if (at == null) return 'not yet';
  final d = daysAgo(at, now);
  return d == 0 ? 'today' : d == 1 ? 'yesterday' : d < 14 ? '$d days ago' : d < 60 ? '${d ~/ 7} weeks ago' : 'long ago';
}

/// One point of an exercise's history: the user's level on that day, as the label they would have seen at today's reps.
class LevelPoint {
  const LevelPoint({required this.at, required this.rung, required this.label, this.kg, this.stepped = false});
  final DateTime at;
  final int rung;
  final String label;
  final double? kg;     // loaded: the weight at that level for today's reps
  final bool stepped;   // the level rose after this workout
}

/// The level of an exercise at every workout it appeared in, oldest first, then now. The level is the user's, not
/// the day's: a hard day's next level or an easy day's version down is folded back.
List<LevelPoint> levelHistory(AppState s, Exercise ex) {
  final st = s.ex[ex.id];
  if (st == null) return const [];
  final range = todayRange(s, ex);
  final out = <LevelPoint>[];
  for (final x in s.sessions) {
    if (x.type != 'lift' || x.endedAt == null) continue;
    for (final e in x.exercises) {
      if (e.exId != ex.id || e.attempted.isEmpty) continue;
      var rung = e.rung;
      if (e.nextLevel) rung -= 1;
      if (e.intent == 'light' && !ex.loaded) rung += 1;
      if (e.lightened) rung += 1;
      out.add(LevelPoint(at: x.endedAt!, rung: rung, label: rungLabel(s, ex, st, rung, range), kg: ex.loaded ? loadFor(s, ex, st, rung, range) : null));
    }
  }
  for (var i = 0; i < out.length - 1; i++) {
    if (out[i + 1].rung > out[i].rung) out[i] = LevelPoint(at: out[i].at, rung: out[i].rung, label: out[i].label, kg: out[i].kg, stepped: true);
  }
  final nowPoint = LevelPoint(at: DateTime.now(), rung: st.rung, label: rungLabel(s, ex, st, st.rung, range), kg: ex.loaded ? loadFor(s, ex, st, st.rung, range) : null);
  if (out.isNotEmpty && st.rung > out.last.rung) out[out.length - 1] = LevelPoint(at: out.last.at, rung: out.last.rung, label: out.last.label, kg: out.last.kg, stepped: true);
  out.add(nowPoint);
  return out;
}

/// The growth in words: "40 kg to 47.5 kg, 3 levels up, about 19 % more" or "knee push-ups to push-ups, 2 versions up".
String growthText(Exercise ex, LevelPoint from, LevelPoint to) {
  final d = to.rung - from.rung;
  if (d == 0) return 'holding at ${to.label}';
  final dir = d > 0 ? 'up' : 'down';
  final n = d.abs();
  if (ex.loaded && from.kg != null && to.kg != null && from.kg! > 0) {
    final pct = ((to.kg! / from.kg! - 1) * 100).round();
    return '${from.label} to ${to.label}: $n level${n == 1 ? '' : 's'} $dir, ${pct >= 0 ? '+' : ''}$pct %';
  }
  return '${from.label} to ${to.label}: $n version${n == 1 ? '' : 's'} $dir';
}
