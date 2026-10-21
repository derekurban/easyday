// Exercise library, equipment, goals, progressions, routines. Pure data and small pure helpers. The exercises themselves
// are data/library.json, generated into exercises.g.dart by tool/gen_library.py (docs/app/EXERCISE_DATA.md).
part 'exercises.g.dart';

class EquipmentGroup {
  const EquipmentGroup(this.name, this.items);
  final String name;
  final Map<String, String> items;
}

const equipmentGroups = [
  EquipmentGroup('Free weights', {
    'barbell': 'Barbell and plates', 'ez_bar': 'EZ curl bar', 'trap_bar': 'Trap bar', 'dumbbell': 'Dumbbells',
    'kettlebell': 'Kettlebells', 'medicine_ball': 'Medicine ball', 'weight_plate': 'Weight plates',
  }),
  EquipmentGroup('Stations', {
    'squat_rack': 'Squat rack', 'bench_flat': 'Flat bench', 'bench_incline': 'Incline bench', 'pullup_bar': 'Pull-up bar',
    'dip_bars': 'Dip bars', 'box': 'Box or step', 'landmine': 'Landmine', 'bench_decline': 'Decline bench',
    'preacher_bench': 'Preacher bench',
  }),
  EquipmentGroup('Machines', {
    'cable': 'Cable station', 'lat_pulldown': 'Lat pulldown', 'row_machine': 'Seated row machine',
    'chest_press_machine': 'Chest press machine', 'shoulder_press_machine': 'Shoulder press machine', 'leg_press': 'Leg press',
    'hack_squat': 'Hack squat', 'leg_extension': 'Leg extension', 'leg_curl': 'Leg curl', 'smith': 'Smith machine',
    'assisted_machine': 'Assisted pull-up / dip', 'back_extension': 'Back extension bench', 'calf_machine': 'Calf raise machine',
    'pec_deck': 'Pec deck / reverse fly machine', 'abduction_machine': 'Hip abduction / adduction machine', 'ghd': 'Glute-ham developer',
    'sled': 'Sled',
  }),
  EquipmentGroup('Loading gear', {
    'vest': 'Weighted vest', 'dip_belt': 'Dip belt', 'backpack': 'Loadable backpack',
  }),
  EquipmentGroup('Small gear', {
    'band': 'Resistance bands', 'suspension': 'Suspension trainer', 'ab_wheel': 'Ab wheel', 'exercise_ball': 'Exercise ball',
    'foam_roller': 'Foam roller', 'jump_rope': 'Jump rope', 'gym_rings': 'Gym rings', 'wrist_roller': 'Wrist roller',
  }),
  EquipmentGroup('Cardio', {
    'treadmill': 'Treadmill', 'bike': 'Bike', 'rower': 'Rower', 'elliptical': 'Elliptical', 'stairs': 'Stair machine',
  }),
];

final Map<String, String> equipment = {for (final g in equipmentGroups) ...g.items};
final List<String> allEquipment = equipment.keys.toList();

class LocationTemplate {
  const LocationTemplate(this.id, this.name, this.equipment);
  final String id;
  final String name;
  final List<String> equipment;
}

final templates = [
  LocationTemplate('gym', 'Commercial gym', allEquipment),
  const LocationTemplate('home_full', 'Home · rack, barbell, bench', ['barbell', 'weight_plate', 'squat_rack', 'bench_flat', 'dumbbell', 'pullup_bar']),
  const LocationTemplate('home_db', 'Home · dumbbells and a bench', ['dumbbell', 'bench_flat']),
  const LocationTemplate('home_kb', 'Home · a kettlebell', ['kettlebell']),
  const LocationTemplate('home_band', 'Home · bands and a pull-up bar', ['band', 'pullup_bar']),
  const LocationTemplate('hotel', 'Hotel gym', ['dumbbell', 'bench_flat', 'cable', 'treadmill', 'bike']),
  const LocationTemplate('none', 'Nothing', []),
];

/// The template id of a location made by hand.
const customLocation = 'custom';

class RepRange {
  const RepRange(this.lo, this.hi);
  final int lo;
  final int hi;
  @override
  String toString() => '$lo to $hi';
  @override
  bool operator ==(Object other) => other is RepRange && other.lo == lo && other.hi == hi;
  @override
  int get hashCode => lo * 1000 + hi;
}

/// A goal template. The user's actual goal is a GoalConfig in the app state: filled from a template, editable in full.
/// The reps a goal likes: heavy and few, middle, or light and many. A level is strength; this only picks how it is expressed.
enum Expression { heavy, middle, light }

/// The preset rep bands: heavy and few, middle, light and many. Any band can be edited into something else.
const heavyReps = RepRange(4, 7);
const middleReps = RepRange(8, 12);
const lightReps = RepRange(13, 18);

/// A rep band in the goal: a range, tagged with the difficulties it applies to (1 easy, 2 medium, 3 hard). The bands
/// tagged with a difficulty, in list order, cycle by workout for that difficulty's exercises.
class Band {
  Band(this.range, Iterable<int> difficulties) : difficulties = {...difficulties};
  RepRange range;
  Set<int> difficulties;
  Band copy() => Band(range, difficulties);
  @override
  bool operator ==(Object other) => other is Band && other.range == range && other.difficulties.length == difficulties.length && other.difficulties.containsAll(difficulties);
  @override
  int get hashCode => Object.hash(range, difficulties.fold<int>(0, (a, d) => a + d));
}

/// The rows per difficulty, easy first, derived from the bands.
typedef Schemes = List<List<RepRange>>;

/// The suggested programs: each fills the band list. Hard first, so a band shared by hard and medium cycles after a
/// hard-only one.
List<Band> strengthBands() => [Band(heavyReps, [3]), Band(middleReps, [2]), Band(lightReps, [1])];
List<Band> buildBands() => [Band(middleReps, [3, 2]), Band(lightReps, [1])];
List<Band> enduranceBands() => [Band(lightReps, [3, 2, 1])];
List<Band> mixedBands() => [Band(heavyReps, [3]), Band(middleReps, [3, 2]), Band(lightReps, [1])];
final programBands = {'strength': strengthBands, 'build': buildBands, 'endurance': enduranceBands, 'mixed': mixedBands};
const programLabel = {'strength': 'Strength', 'build': 'Build', 'endurance': 'Endurance', 'mixed': 'Mixed'};
const programBlurb = {
  'strength': 'Heavy and few on the hard lifts, middle on medium ones, light and many on easy ones.',
  'build': 'Middle reps on hard and medium exercises, light and many on easy ones.',
  'endurance': 'Light and many everywhere.',
  'mixed': 'Hard lifts alternate heavy and middle by workout: A and C heavy, B and D middle.',
};
const maxBands = 6;

/// A calibration: the fewest, the ideal, and the most. Never fewer than the fewest; the ideal is the sweet spot; the
/// most only on long workouts or hard days.
class Tri {
  const Tri(this.min, this.ideal, this.max);
  final int min;
  final int ideal;
  final int max;
  Tri clampTo(int lo, int hi) {
    final i = ideal.clamp(lo, hi);
    return Tri(min.clamp(lo, i), i, max.clamp(i, hi));
  }
  Tri withMin(int v) => Tri(v, v > ideal ? v : ideal, v > max ? v : max);
  Tri withIdeal(int v) => Tri(v < min ? v : min, v, v > max ? v : max);
  Tri withMax(int v) => Tri(v < min ? v : min, v < ideal ? v : ideal, v);
  @override
  String toString() => '$min/$ideal/$max';
  @override
  bool operator ==(Object other) => other is Tri && other.min == min && other.ideal == ideal && other.max == max;
  @override
  int get hashCode => Object.hash(min, ideal, max);
}

class Goal {
  const Goal(this.id, this.name, this.blurb, {required this.program, required this.moveEvery, required this.exercises, required this.sets, required this.pushes, required this.explain});
  final String id;
  final String name;
  final String blurb;
  final String program;      // the rep program it fills the bands from
  final int moveEvery;
  final Tri exercises;       // different exercises in a workout
  final Tri sets;            // working sets
  final Tri pushes;          // exercises at the next level on a hard day
  final List<String> explain;
  List<Band> bands() => programBands[program]!();
}

const goals = {
  'strength': Goal('strength', 'Get stronger', 'Heavier over time. Fewer reps per set.',
      program: 'strength', moveEvery: 4, exercises: Tri(2, 4, 6), sets: Tri(2, 3, 4), pushes: Tri(1, 2, 3),
      explain: ['Heavy and few: 4 to 7 reps on the big lifts', 'One movement day in four', 'About 45 minutes a workout']),
  'muscle': Goal('muscle', 'Build muscle', 'Moderate reps, steady volume.',
      program: 'build', moveEvery: 4, exercises: Tri(2, 4, 6), sets: Tri(2, 3, 4), pushes: Tri(1, 2, 3),
      explain: ['Middle reps: 8 to 12', 'One movement day in four', 'About 40 minutes a workout']),
  'fit': Goal('fit', 'Stay fit and mobile', 'Lifting plus plenty of movement.',
      program: 'endurance', moveEvery: 2, exercises: Tri(2, 4, 5), sets: Tri(2, 3, 3), pushes: Tri(1, 1, 2),
      explain: ['Light and many: 13 to 18 reps', 'Every other day is a movement day', 'About 35 minutes a workout']),
  'feel': Goal('feel', 'Feel better', 'Short sessions, lots of movement. The floor is low.',
      program: 'endurance', moveEvery: 2, exercises: Tri(1, 3, 4), sets: Tri(2, 2, 3), pushes: Tri(0, 1, 2),
      explain: ['Three exercises, light and many', 'Every other day is a movement day', 'About 25 minutes a workout']),
};

class Experience {
  const Experience(this.id, this.name, this.blurb);
  final String id;
  final String name;
  final String blurb;
}

const experiences = [
  Experience('new', 'New to this', 'Little or no lifting before.'),
  Experience('some', 'Some experience', 'Have lifted on and off.'),
  Experience('experienced', 'Experienced', 'Years of consistent training.'),
];

int experienceIndex(String id) => experiences.indexWhere((e) => e.id == id).clamp(0, 2);

/// One level of a bodyweight progression. [how] overrides the exercise description at this level.
class Variant {
  const Variant(this.name, [this.note, this.how]);
  final String name;
  final String? note;
  final String? how;
  Map<String, dynamic> toJson() => {'name': name, 'note': note, 'how': how};
  static Variant fromJson(Map<String, dynamic> j) => Variant(j['name'], j['note'], j['how']);
}

/// A bodyweight ladder: variants in order of difficulty, then loaded rungs on top if the location has loading gear.
class Ladder {
  const Ladder(this.variants, {this.start = const [0, 1, 2], this.loadGear = const [], this.loadStep = 2.5});
  Map<String, dynamic> toJson() => {'variants': variants.map((v) => v.toJson()).toList(), 'start': start, 'loadGear': loadGear, 'loadStep': loadStep};
  static Ladder fromJson(Map<String, dynamic> j) => Ladder((j['variants'] as List).map((v) => Variant.fromJson(v)).toList(),
      start: List<int>.from(j['start'] ?? [0, 1, 2]), loadGear: List<String>.from(j['loadGear'] ?? []), loadStep: (j['loadStep'] as num?)?.toDouble() ?? 2.5);
  final List<Variant> variants;
  /// Starting rung by experience: new, some, experienced.
  final List<int> start;
  /// Equipment that unlocks loaded rungs above the last variant. Empty means the last variant is the ceiling.
  final List<String> loadGear;
  final double loadStep;
}

/// What an exercise is (docs/app/EXERCISES.md): strength builds muscle and is the only type a workout's exercises are
/// picked from; power is explosive work; stability is control and light holds; cardio is kept going for time;
/// stretching is range of motion.
enum ExerciseType { strength, power, stability, cardio, stretching }

const typeLabel = {
  ExerciseType.strength: 'Strength', ExerciseType.power: 'Power', ExerciseType.stability: 'Stability',
  ExerciseType.cardio: 'Cardio', ExerciseType.stretching: 'Stretching',
};

/// The loads for an exercise done with another implement than its main one: a bar exercise with dumbbells (per hand),
/// or the farmer's carry with a trap bar (a total).
class AltLoad {
  const AltLoad({required this.startKg, required this.stepKg, required this.each});
  final List<double> startKg;
  final double stepKg;
  final bool each;
}

class Exercise {
  const Exercise({
    required this.id, required this.name, required this.type, required this.format, this.primary = const [], this.secondary = const [],
    this.targets = const [], required this.needs, this.cost = 1, required this.rank, this.how = '',
    this.startKg, this.stepKg, this.each = false, this.altLoad = const {}, this.ladder, this.range, this.seconds, this.perSide = false,
  });
  final String id;
  final String name;
  final ExerciseType type;
  /// How it is done: reps, hold (seconds), carry (steps); steady or intervals for cardio; moving or held for stretches.
  final String format;
  /// Any one of the listed equipment sets must be fully available. [[]] means nothing needed.
  final List<List<String>> needs;
  /// Library cost 1 to 5. Shown and used as a difficulty of three: 1 and 2 easy, 3 medium, 4 and 5 hard.
  final int cost;
  int get difficulty => foldDifficulty(cost);
  /// Tie-break among equally good choices: lower first.
  final int rank;
  /// The muscles it works mainly, then the ones that help, by their everyday names (index.dart `muscleNames`). Only
  /// strength exercises are built into workouts, so only they earn strain from these.
  final List<String> primary;
  final List<String> secondary;
  /// Stretches: the muscles lengthened.
  final List<String> targets;
  final String how;
  /// Loaded exercises: conservative starting kilograms by experience and the smallest practical step. Dumbbells and
  /// kettlebells are per hand ([each]); bars are the total.
  final List<double>? startKg;
  final double? stepKg;
  /// The load is held in one hand or on one limb: the kilograms shown are per hand.
  final bool each;
  /// The loads with another implement, by equipment id.
  final Map<String, AltLoad> altLoad;
  /// Bodyweight and band exercises: the variant ladder.
  final Ladder? ladder;
  /// Bodyweight exercises: a sensible floor for the rep range (holds: the seconds) when the goal's range is lower.
  final RepRange? range;
  RepRange? get bwRange => range;
  /// Stretches and routine moves: seconds per set, or per side when [perSide].
  final int? seconds;
  final bool perSide;
  bool get loaded => startKg != null;
  /// Has levels the app can track: a ladder or starting loads.
  bool get tracked => ladder != null || startKg != null;
  bool get isStrength => type == ExerciseType.strength;
  String get repLabel => switch (format) { 'hold' || 'held' || 'moving' => 'seconds', 'carry' => 'steps', _ => 'reps' };
}

int foldDifficulty(int cost) => cost >= 4 ? 3 : cost == 3 ? 2 : 1;
const difficultyLabel = {1: 'easy', 2: 'medium', 3: 'hard'};

/// How to perform an exercise at a given level: the level's own text, the library's per-level text, or the base
/// description with the level's note folded in.
String howAt(Exercise ex, int rung) {
  final l = ex.ladder;
  if (l == null || rung < 0) return ex.how;
  if (rung >= l.variants.length) return '${ex.how} Add load with ${l.loadGear.map((g) => equipment[g]!.toLowerCase()).join(' or ')}.';
  final v = l.variants[rung];
  if (v.how != null && v.how!.isNotEmpty) return v.how!;
  if (v.note != null && v.note!.isNotEmpty) {
    final n = v.note!;
    return '${ex.how} ${n[0].toUpperCase()}${n.substring(1)}${n.endsWith('.') ? '' : '.'}';
  }
  return ex.how;
}

/// Where a saved rung on a ladder whose versions moved now sits: the same version by name, or the nearest easier one
/// still there. Loaded rungs above the top version keep their distance from it.
int remapRung(String id, int rung) {
  final old = rungHistory[id];
  final names = exerciseById[id]?.ladder?.variants.map((v) => v.name).toList();
  if (old == null || names == null || rung < 0) return rung;
  if (rung >= old.length) return names.length + rung - old.length;
  for (var j = rung; j >= 0; j--) {
    final k = names.indexOf(old[j]);
    if (k >= 0) return k;
  }
  return 0;
}

final List<Exercise> exercises = List.unmodifiable(builtInExercises);
final Map<String, Exercise> exerciseById = {for (final e in builtInExercises) e.id: e};

/// The exercises with levels the user can browse, practise and see on a card: strength, power and stability. Stretches
/// and cardio live in the stretching routines and the cardio choices; a few routine moves have no levels.
final List<Exercise> browsable = [for (final e in builtInExercises) if (e.tracked && e.type != ExerciseType.cardio && e.type != ExerciseType.stretching) e];

bool available(Exercise ex, Iterable<String> have) {
  final set = have.toSet();
  return ex.needs.any((need) => need.every(set.contains));
}

/// A move in a stretching routine: a stretch or a light drill from the library, timed by its seconds (both sides when
/// it is done per side).
class Move {
  const Move(this.n, this.how, this.seconds);
  final String n;
  final String how;
  final int seconds;
}

class Routine {
  const Routine(this.id, this.name, this.ids);
  final String id;
  final String name;
  final List<String> ids;
  List<Move> get moves => [
        for (final id in ids)
          if (exerciseById[id] case final e?) Move(e.name, e.how, (e.seconds ?? 40) * (e.perSide ? 2 : 1)),
      ];
  /// The whole routine, in seconds.
  int get seconds => moves.fold(0, (a, m) => a + m.seconds);
}

const routines = {
  'reset': Routine('reset', 'Full body reset',
      ['cat_cow', 'worlds_greatest_stretch', 'kneeling_hip_flexor_stretch', 'thoracic_rotation', 'deep_squat_hold', 'hamstring_sweep', 'arm_circles']),
  'hips': Routine('hips', 'Hips and hamstrings', ['90_90_hip_switch', 'pigeon', 'hamstring_sweep', 'couch_stretch', 'deep_squat_hold', 'glute_bridge_hold']),
  'upper': Routine('upper', 'Shoulders and upper back', ['cat_cow', 'thread_the_needle', 'wall_slides', 'doorway_chest_stretch', 'thoracic_rotation', 'arm_circles']),
};

/// A cardio choice for a movement day: a steady cardio entry of the library, and the one machine it needs, if any.
class Cardio {
  const Cardio(this.id, this.name, [this.needs]);
  final String id;
  final String name;
  final String? needs;
}

const _cardioOrder = ['walk', 'run', 'treadmill', 'bike', 'rower', 'elliptical', 'stairs', 'jump_rope', 'any'];

final cardio = [
  for (final id in _cardioOrder)
    if (exerciseById[id] case final e?) Cardio(e.id, e.name, e.needs.first.isEmpty ? null : e.needs.first.first),
];

List<Cardio> cardioFor(Iterable<String> have) {
  final set = have.toSet();
  return cardio.where((c) => c.needs == null || set.contains(c.needs)).toList();
}
