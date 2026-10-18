// Indexes: ways of grouping the library for browsing. The user picks one; it never changes what gets built.
import 'library.dart';

enum ExerciseIndex { muscle, region, pattern, equipment, progression, difficulty }

const indexLabel = {
  ExerciseIndex.muscle: 'Muscle group',
  ExerciseIndex.region: 'Body region',
  ExerciseIndex.pattern: 'Movement pattern',
  ExerciseIndex.equipment: 'Equipment',
  ExerciseIndex.progression: 'Progression type',
  ExerciseIndex.difficulty: 'Difficulty',
};

const indexBlurb = {
  ExerciseIndex.muscle: 'Chest, back, quads… by the main muscle each exercise works.',
  ExerciseIndex.region: 'Upper body, lower body, core.',
  ExerciseIndex.pattern: 'Squat, hinge, push, pull… the way the workout builder sees them.',
  ExerciseIndex.equipment: 'Barbell, dumbbell, machine, bodyweight… what each one needs.',
  ExerciseIndex.progression: 'By weight or by version.',
  ExerciseIndex.difficulty: 'Easy, medium, hard: how much one hard set takes out of you.',
};

/// The muscles by the names people use for them: what exercises are tagged with, what the body map highlights and
/// names on a tap (each plate's `name` in assets/muscle/flat.json), what the workout's "works" line says. Shins are on
/// the map but no exercise works them.
const muscleNames = [
  'chest', 'front shoulders', 'side shoulders', 'rear shoulders', 'biceps', 'triceps', 'forearms', 'abs', 'obliques',
  'traps', 'lats', 'upper back', 'lower back', 'glutes', 'outer hips', 'inner thighs', 'quads', 'hamstrings', 'calves', 'shins',
];

/// The muscles exercises work, whose work is tracked over time: all but the shins.
final trackedMuscles = [for (final m in muscleNames) if (m != 'shins') m];

/// A muscle name as a title: "Front shoulders".
String muscleTitle(String muscle) => muscle.isEmpty ? muscle : muscle[0].toUpperCase() + muscle.substring(1);

/// The eleven groups the muscles fold onto, for browsing and for tracking work over time.
const muscleGroups = ['Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps', 'Forearms', 'Core', 'Glutes', 'Quads', 'Hamstrings', 'Calves'];

const _muscleFold = {
  'chest': 'Chest', 'front shoulders': 'Shoulders', 'side shoulders': 'Shoulders', 'rear shoulders': 'Shoulders',
  'biceps': 'Biceps', 'triceps': 'Triceps', 'forearms': 'Forearms', 'abs': 'Core', 'obliques': 'Core',
  'traps': 'Back', 'lats': 'Back', 'upper back': 'Back', 'lower back': 'Core', 'glutes': 'Glutes', 'outer hips': 'Glutes',
  'inner thighs': 'Quads', 'quads': 'Quads', 'hamstrings': 'Hamstrings', 'calves': 'Calves',
};

/// The group a muscle folds onto, or 'Other' (the shins).
String muscleGroup(String muscle) => _muscleFold[muscle] ?? 'Other';

const _regionOf = {
  'Chest': 'Upper body', 'Back': 'Upper body', 'Shoulders': 'Upper body', 'Biceps': 'Upper body', 'Triceps': 'Upper body', 'Forearms': 'Upper body',
  'Core': 'Core', 'Glutes': 'Lower body', 'Quads': 'Lower body', 'Hamstrings': 'Lower body', 'Calves': 'Lower body',
};

const _patternLabel = {
  'squat': 'Squat', 'hinge': 'Hinge', 'push': 'Push', 'pull': 'Pull', 'core': 'Core', 'carry': 'Carry',
  'arms': 'Arms', 'shoulders': 'Shoulders', 'legs': 'Legs',
};

const _equipmentOrder = ['Barbell', 'Dumbbell', 'Kettlebell', 'Cable', 'Machine', 'Band', 'Suspension', 'Bodyweight'];
const _barbellLike = {'barbell', 'ez_bar', 'trap_bar', 'landmine', 'smith'};
const _cableLike = {'cable', 'lat_pulldown', 'row_machine'};
const _machineLike = {
  'chest_press_machine', 'shoulder_press_machine', 'leg_press', 'hack_squat', 'leg_extension', 'leg_curl', 'assisted_machine',
  'back_extension', 'calf_machine', 'pec_deck', 'abduction_machine', 'ghd',
};

/// Heading order for an index. Groups not listed here (none today) sort after these, alphabetically.
List<String> indexOrder(ExerciseIndex ix) => switch (ix) {
      ExerciseIndex.muscle => muscleGroups,
      ExerciseIndex.region => const ['Upper body', 'Lower body', 'Core'],
      ExerciseIndex.pattern => _patternLabel.values.toList(),
      ExerciseIndex.equipment => _equipmentOrder,
      ExerciseIndex.progression => const ['By weight', 'By version'],
      ExerciseIndex.difficulty => const ['Easy', 'Medium', 'Hard'],
    };

/// The group an exercise sits under for an index. One group per exercise, so nothing appears twice.
String indexGroup(Exercise e, ExerciseIndex ix) => switch (ix) {
      ExerciseIndex.muscle => e.primary.isEmpty ? 'Other' : muscleGroup(e.primary.first),
      ExerciseIndex.region => _regionOf[indexGroup(e, ExerciseIndex.muscle)] ?? 'Other',
      ExerciseIndex.pattern => _patternLabel[e.pattern] ?? e.pattern,
      ExerciseIndex.equipment => _equipmentGroup(e),
      ExerciseIndex.progression => e.loaded ? 'By weight' : 'By version',
      ExerciseIndex.difficulty => const ['Easy', 'Medium', 'Hard'][e.difficulty - 1],
    };

String _equipmentGroup(Exercise e) {
  final need = e.needs.isEmpty ? const <String>[] : e.needs.first;
  if (need.any(_barbellLike.contains)) return 'Barbell';
  if (need.contains('dumbbell')) return 'Dumbbell';
  if (need.contains('kettlebell') || need.contains('medicine_ball')) return 'Kettlebell';
  if (need.any(_cableLike.contains)) return 'Cable';
  if (need.any(_machineLike.contains)) return 'Machine';
  if (need.contains('band')) return 'Band';
  if (need.contains('suspension')) return 'Suspension';
  return 'Bodyweight';
}

/// Every muscle group an exercise touches, primary first, for the "works" line and the muscle filter.
List<String> muscleGroupsOf(Exercise e) {
  final out = <String>[];
  for (final m in [...e.primary, ...e.secondary]) {
    final g = muscleGroup(m);
    if (!out.contains(g)) out.add(g);
  }
  return out;
}

/// Exercises grouped under an index, in heading order, each group sorted by [sort].
List<MapEntry<String, List<Exercise>>> groupBy(Iterable<Exercise> list, ExerciseIndex ix, {int Function(Exercise, Exercise)? sort}) {
  final map = <String, List<Exercise>>{};
  for (final e in list) {
    map.putIfAbsent(indexGroup(e, ix), () => []).add(e);
  }
  final order = indexOrder(ix);
  int rank(String g) { final i = order.indexOf(g); return i < 0 ? order.length : i; }
  final keys = map.keys.toList()..sort((a, b) { final c = rank(a).compareTo(rank(b)); return c != 0 ? c : a.compareTo(b); });
  return [for (final k in keys) MapEntry(k, map[k]!..sort(sort ?? (a, b) => a.name.compareTo(b.name)))];
}
