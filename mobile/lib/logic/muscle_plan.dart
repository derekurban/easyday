// The muscle plan: today's word on each muscle before the workout is built. The muscles are the map's own
// (data/index.dart `trackedMuscles`), the same ones selection and its ledgers run on. Every muscle is in one of three
// states. Excluded: no exercise works it as a main muscle today. Available: in the pool selection draws from
// (SELECTION.md). Forced: worked today for certain, by an exercise that has it as a main muscle. The defaults come
// from the muscle map: a muscle carrying enough strain starts excluded, the rest start available, nothing starts
// forced. The user changes any of them on the muscle picker, for today only: select muscles, then pick their state.
import '../data/index.dart';
import 'muscle_map.dart';

enum MuscleState { excluded, available, forced }

const muscleStateLabel = {MuscleState.forced: 'Forced', MuscleState.available: 'Available', MuscleState.excluded: 'Excluded'};
const muscleStateBlurb = {
  MuscleState.forced: 'Worked today, as a main muscle.',
  MuscleState.available: 'In the pool the workout is drawn from.',
  MuscleState.excluded: 'Not worked as a main muscle today.',
};

/// A muscle starts excluded when it sits at this shade or higher: 1 any strain, 2 medium or high, 3 high only. Any
/// strain is the muscle map's own word for not ready (MUSCLE_MAP.md): three working sets leave 0.60, low strain the next
/// day and strain-free the day after, so a Monday, Wednesday, Friday week still works. At 2 a usual workout would
/// exclude nothing the next day; only four sets or more would.
const excludeFromShade = 1;

/// Today's muscle plan as a whole: the states, the list's order, and how the rest of the workout is filled. Shuffle
/// (the default) fills the places after the forced muscles from the available pool, by selection's rules, or at random
/// among the ready ones once [seed] is above zero (Draw again). Manual works the forced muscles only.
class MusclePlan {
  MusclePlan({Map<String, MuscleState>? states, List<String>? order, this.manual = false, this.seed = 0})
      : states = {...?states}, order = [...?order];
  final Map<String, MuscleState> states;
  final List<String> order;
  bool manual;
  int seed;

  MusclePlan copy() => MusclePlan(states: states, order: order, manual: manual, seed: seed);

  /// The muscles worked for certain, in the list's order.
  List<String> get forced => musclesIn(states, MuscleState.forced, order);

  /// The muscles no exercise may work as a main muscle today.
  Set<String> get excluded => musclesIn(states, MuscleState.excluded).toSet();

  /// The seed the builder draws with, or null for selection's own order.
  int? get shuffle => manual || seed <= 0 ? null : seed;

  /// Give every muscle in [muscles] the state [state]: the pill row on the picker, applied to the selected muscles.
  void set(Iterable<String> muscles, MuscleState state) {
    for (final m in muscles) { states[m] = state; }
  }
}

/// Today's defaults from the muscle map: excluded at [excludeFromShade] or above, else available.
Map<String, MuscleState> defaultMuscleStates(StrainPoints current) => {
      for (final m in trackedMuscles) m: current.shade(m) >= excludeFromShade ? MuscleState.excluded : MuscleState.available,
    };

/// The muscles in [state], in [order] (the user's list order; muscles not in it follow in the map's order).
List<String> musclesIn(Map<String, MuscleState> states, MuscleState state, [List<String> order = const []]) {
  final all = [...order, for (final m in trackedMuscles) if (!order.contains(m)) m];
  return [for (final m in all) if (states[m] == state) m];
}

/// Words for a list: "chest", "lats and biceps", "lats, triceps and forearms".
String listWords(Iterable<String> xs) {
  final l = xs.toList();
  if (l.isEmpty) return '';
  if (l.length == 1) return l.single;
  return '${l.sublist(0, l.length - 1).join(', ')} and ${l.last}';
}

/// A workout's name from the muscles it works, in order: "Chest day", "Lats and biceps day",
/// "Upper back, triceps and forearms day". The first word takes a capital, the rest stay lowercase.
String dayName(List<String> muscles) {
  if (muscles.isEmpty) return 'Workout';
  return '${muscleTitle(listWords([for (final m in muscles) m.toLowerCase()]))} day';
}
