// The muscle plan: today's word on each of the eleven muscle groups before the workout is built. Every group is in
// one of three states. Excluded: not worked today. Available: in the pool selection draws from (SELECTION.md).
// Forced: worked today for certain, by an exercise that has it as a primary muscle. The defaults come from the
// muscle map: a group carrying enough strain starts excluded, the rest start available, nothing starts forced.
// The user changes any of them on the muscle picker, for today only: select muscles, then pick their state.
import '../data/index.dart';
import 'muscle_map.dart';

enum MuscleState { excluded, available, forced }

const muscleStateLabel = {MuscleState.forced: 'Forced', MuscleState.available: 'Available', MuscleState.excluded: 'Excluded'};
const muscleStateBlurb = {
  MuscleState.forced: 'Worked today, as a main muscle.',
  MuscleState.available: 'In the pool the workout is drawn from.',
  MuscleState.excluded: 'Not worked today.',
};

/// A group starts excluded when its most strained muscle sits at this shade or higher: 1 any strain, 2 medium or
/// high, 3 high only. Any strain is the muscle map's own word for not ready (MUSCLE_MAP.md): three working sets leave
/// 0.60, low strain the next day and strain-free the day after, so a Monday, Wednesday, Friday week still works.
/// At 2 a usual workout would exclude nothing the next day; only four sets or more would.
const excludeFromShade = 1;

/// Today's muscle plan as a whole: the states, the list's order, and how the rest of the workout is filled. Shuffle
/// (the default) fills the places after the forced groups from the available pool, by selection's rules, or at random
/// among the ready ones once [seed] is above zero (the Shuffle button). Manual works the forced groups only.
class MusclePlan {
  MusclePlan({Map<String, MuscleState>? states, List<String>? order, this.manual = false, this.seed = 0})
      : states = {...?states}, order = [...?order];
  final Map<String, MuscleState> states;
  final List<String> order;
  bool manual;
  int seed;

  MusclePlan copy() => MusclePlan(states: states, order: order, manual: manual, seed: seed);

  /// The groups worked for certain, in the list's order.
  List<String> get forced => groupsIn(states, MuscleState.forced, order);

  /// The groups the builder may not touch: the excluded ones, or everything not forced when manual.
  Set<String> get excluded => manual
      ? {for (final g in muscleGroups) if (states[g] != MuscleState.forced) g}
      : groupsIn(states, MuscleState.excluded).toSet();

  /// The seed the builder draws with, or null for selection's own order.
  int? get shuffle => manual || seed <= 0 ? null : seed;

  /// Give every group in [groups] the state [state]: the pill row on the picker, applied to the selected muscles.
  void set(Iterable<String> groups, MuscleState state) {
    for (final g in groups) { states[g] = state; }
  }
}

/// The muscles (by their everyday names) that fold onto a group.
List<String> musclesOf(String group) => [for (final m in trackedMuscles) if (muscleGroup(m) == group) m];

/// The highest shade among a group's muscles: 0 when every one is strain-free.
int groupShade(StrainPoints current, String group) => current.highestShade(musclesOf(group));

/// Today's defaults from the muscle map: excluded at [excludeFromShade] or above, else available.
Map<String, MuscleState> defaultMuscleStates(StrainPoints current) => {
      for (final g in muscleGroups) g: groupShade(current, g) >= excludeFromShade ? MuscleState.excluded : MuscleState.available,
    };

/// The groups in [state], in [order] (the user's list order; groups not in it follow in the index order).
List<String> groupsIn(Map<String, MuscleState> states, MuscleState state, [List<String> order = const []]) {
  final all = [...order, for (final g in muscleGroups) if (!order.contains(g)) g];
  return [for (final g in all) if (states[g] == state) g];
}

/// Words for a list: "chest", "back and biceps", "back, triceps and forearms".
String listWords(Iterable<String> xs) {
  final l = xs.toList();
  if (l.isEmpty) return '';
  if (l.length == 1) return l.single;
  return '${l.sublist(0, l.length - 1).join(', ')} and ${l.last}';
}

/// A workout's name from the groups it works, in order: "Chest day", "Back and biceps day",
/// "Back, triceps and forearms day". The first group keeps its capital, the rest go lowercase.
String dayName(List<String> groups) {
  if (groups.isEmpty) return 'Workout';
  final words = [groups.first, for (final g in groups.skip(1)) g.toLowerCase()];
  return '${listWords(words)} day';
}
