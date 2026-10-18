// Exercise library, equipment, patterns, goals, progressions. Pure data and small pure helpers.
import 'howto.dart';

class EquipmentGroup {
  const EquipmentGroup(this.name, this.items);
  final String name;
  final Map<String, String> items;
}

const equipmentGroups = [
  EquipmentGroup('Free weights', {
    'barbell': 'Barbell and plates', 'ez_bar': 'EZ curl bar', 'trap_bar': 'Trap bar', 'dumbbell': 'Dumbbells',
    'kettlebell': 'Kettlebells', 'medicine_ball': 'Medicine ball',
  }),
  EquipmentGroup('Stations', {
    'squat_rack': 'Squat rack', 'bench_flat': 'Flat bench', 'bench_incline': 'Incline bench', 'pullup_bar': 'Pull-up bar',
    'dip_bars': 'Dip bars', 'box': 'Box or step', 'landmine': 'Landmine',
  }),
  EquipmentGroup('Machines', {
    'cable': 'Cable station', 'lat_pulldown': 'Lat pulldown', 'row_machine': 'Seated row machine',
    'chest_press_machine': 'Chest press machine', 'shoulder_press_machine': 'Shoulder press machine', 'leg_press': 'Leg press',
    'hack_squat': 'Hack squat', 'leg_extension': 'Leg extension', 'leg_curl': 'Leg curl', 'smith': 'Smith machine',
    'assisted_machine': 'Assisted pull-up / dip', 'back_extension': 'Back extension bench', 'calf_machine': 'Calf raise machine',
    'pec_deck': 'Pec deck / reverse fly machine', 'abduction_machine': 'Hip abduction / adduction machine', 'ghd': 'Glute-ham developer',
  }),
  EquipmentGroup('Loading gear', {
    'vest': 'Weighted vest', 'dip_belt': 'Dip belt', 'backpack': 'Loadable backpack',
  }),
  EquipmentGroup('Small gear', {
    'band': 'Resistance bands', 'suspension': 'Suspension trainer', 'ab_wheel': 'Ab wheel', 'exercise_ball': 'Exercise ball',
    'foam_roller': 'Foam roller', 'jump_rope': 'Jump rope',
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
  const LocationTemplate('home_full', 'Home · rack, barbell, bench', ['barbell', 'squat_rack', 'bench_flat', 'dumbbell', 'pullup_bar']),
  const LocationTemplate('home_db', 'Home · dumbbells and a bench', ['dumbbell', 'bench_flat']),
  const LocationTemplate('home_kb', 'Home · a kettlebell', ['kettlebell']),
  const LocationTemplate('home_band', 'Home · bands and a pull-up bar', ['band', 'pullup_bar']),
  const LocationTemplate('hotel', 'Hotel gym', ['dumbbell', 'bench_flat', 'cable', 'treadmill', 'bike']),
  const LocationTemplate('none', 'Nothing', []),
];

/// The template id of a location made by hand.
const customLocation = 'custom';

class Pattern {
  const Pattern(this.id, this.name, {required this.main});
  final String id;
  final String name;
  final bool main;
}

const patterns = {
  'squat': Pattern('squat', 'Squat', main: true),
  'hinge': Pattern('hinge', 'Hinge', main: true),
  'push': Pattern('push', 'Push', main: true),
  'pull': Pattern('pull', 'Pull', main: true),
  'core': Pattern('core', 'Core', main: false),
  'carry': Pattern('carry', 'Carry', main: false),
  'arms': Pattern('arms', 'Arms', main: false),
  'shoulders': Pattern('shoulders', 'Shoulders', main: false),
  'legs': Pattern('legs', 'Legs', main: false),
};

String patternName(String id) => patterns[id]?.name ?? id;

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

class Exercise {
  const Exercise({
    required this.id, required this.name, required this.pattern, required this.needs, required this.cost, required this.rank,
    required this.primary, required this.secondary, required this.how, this.ref,
    this.startKg, this.stepKg, this.each = false, this.repLabel = 'reps', this.ladder, this.bwRange,
  });
  final String id;
  final String name;
  final String pattern;
  /// Any one of the listed equipment sets must be fully available. [[]] means nothing needed.
  final List<List<String>> needs;
  /// Library cost 1 to 5. Shown and used as a difficulty of three: 1 and 2 easy, 3 medium, 4 and 5 hard.
  final int cost;
  int get difficulty => foldDifficulty(cost);
  final int rank;
  /// The muscles it works mainly, then the ones that help, by their everyday names (index.dart `muscleNames`).
  final List<String> primary;
  final List<String> secondary;
  final String how;
  final String? ref;
  /// Loaded exercises: conservative starting kilograms by experience and the smallest practical step.
  final List<double>? startKg;
  final double? stepKg;
  final bool each;
  final String repLabel;
  /// Bodyweight exercises: the variant ladder.
  final Ladder? ladder;
  /// Bodyweight exercises: a sensible floor for the rep range when the goal's range is lower.
  final RepRange? bwRange;
  bool get loaded => ladder == null;
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
  if (bandLadders.contains(ex.id)) return '${ex.how} ${bandLevels[rung.clamp(0, bandLevels.length - 1)]}';
  final table = levelHow[ex.id];
  final fromTable = table != null && rung < table.length ? table[rung] : null;
  if (fromTable != null) return fromTable;
  if (v.note != null && v.note!.isNotEmpty) {
    final n = v.note!;
    return '${ex.how} ${n[0].toUpperCase()}${n.substring(1)}${n.endsWith('.') ? '' : '.'}';
  }
  return ex.how;
}

Exercise _kg(String id, String name, String pattern, List<List<String>> needs, List<double> start, double step,
    {required int cost, required int rank, bool each = false, String repLabel = 'reps', String? ref,
    required List<String> p, List<String> s = const [], required String how}) =>
    Exercise(id: id, name: name, pattern: pattern, needs: needs, cost: cost, rank: rank, primary: p, secondary: s, how: how, ref: ref,
        startKg: start, stepKg: step, each: each, repLabel: repLabel);

Exercise _bw(String id, String name, String pattern, List<List<String>> needs, RepRange range, Ladder ladder,
    {required int cost, required int rank, String? ref, required List<String> p, List<String> s = const [], required String how, String repLabel = 'reps'}) =>
    Exercise(id: id, name: name, pattern: pattern, needs: needs, cost: cost, rank: rank, primary: p, secondary: s, how: how, ref: ref,
        ladder: ladder, bwRange: range, repLabel: repLabel);

const _vestOrPack = ['vest', 'backpack'];
const _beltOrVest = ['dip_belt', 'vest'];

final List<Exercise> _builtIn = [
  // ---------- push
  _kg('bb_bench', 'Barbell bench press', 'push', [['barbell', 'bench_flat']], [20, 30, 40], 2.5, cost: 4, rank: 1, ref: 'Barbell_Bench_Press_-_Medium_Grip',
      p: ['chest'], s: ['front shoulders', 'triceps'],
      how: 'Lie on the bench, feet flat, bar over your chest. Lower it to your mid-chest with elbows about 45 degrees from your body, then press it back up.'),
  _kg('db_bench', 'Dumbbell bench press', 'push', [['dumbbell', 'bench_flat']], [8, 12, 16], 2, each: true, cost: 3, rank: 2, ref: 'Dumbbell_Bench_Press',
      p: ['chest'], s: ['front shoulders', 'triceps'],
      how: 'Lie on the bench with a dumbbell in each hand at chest height. Press both up until your arms are straight, then lower under control.'),
  _kg('incline_db', 'Incline dumbbell press', 'push', [['dumbbell', 'bench_incline']], [8, 10, 14], 2, each: true, cost: 3, rank: 3, ref: 'Incline_Dumbbell_Press',
      p: ['chest'], s: ['front shoulders', 'triceps'],
      how: 'Set the bench to a low incline. Press the dumbbells up from shoulder height until your arms are straight, then lower slowly.'),
  _kg('db_floor', 'Dumbbell floor press', 'push', [['dumbbell']], [8, 12, 16], 2, each: true, cost: 3, rank: 4, ref: 'Dumbbell_Floor_Press',
      p: ['chest'], s: ['front shoulders', 'triceps'],
      how: 'Lie on the floor, knees bent, dumbbells at chest height with upper arms resting on the floor. Press up, then lower until your arms touch down again.'),
  _kg('ohp', 'Overhead press', 'push', [['barbell']], [20, 25, 30], 2.5, cost: 4, rank: 5, ref: 'Standing_Military_Press',
      p: ['front shoulders'], s: ['side shoulders', 'triceps'],
      how: 'Stand with the bar at your collarbones, hands just outside shoulder width. Brace, press straight overhead until your arms lock out, then lower to the start.'),
  _kg('db_ohp', 'Dumbbell shoulder press', 'push', [['dumbbell']], [6, 8, 12], 2, each: true, cost: 3, rank: 6, ref: 'Dumbbell_Shoulder_Press',
      p: ['front shoulders'], s: ['side shoulders', 'triceps'],
      how: 'Sit or stand with a dumbbell at each shoulder, palms forward. Press both overhead until your arms are straight, then lower to your shoulders.'),
  _kg('kb_press', 'Kettlebell press', 'push', [['kettlebell']], [8, 12, 16], 4, each: true, cost: 3, rank: 7, ref: 'Alternating_Kettlebell_Press',
      p: ['front shoulders'], s: ['side shoulders', 'triceps'],
      how: 'Hold the kettlebell at your shoulder with the bell resting on the back of your forearm. Press overhead, lock out, and lower it back to the rack position.'),
  _kg('chest_press', 'Machine chest press', 'push', [['chest_press_machine']], [20, 30, 40], 5, cost: 2, rank: 8, ref: 'Leverage_Chest_Press',
      p: ['chest'], s: ['front shoulders', 'triceps'],
      how: 'Set the seat so the handles are at mid-chest. Press forward until your arms are nearly straight, then bring the handles back without letting the weight stack touch.'),
  _kg('smith_bench', 'Smith machine bench press', 'push', [['smith', 'bench_flat']], [20, 30, 40], 2.5, cost: 3, rank: 9, ref: 'Smith_Machine_Bench_Press',
      p: ['chest'], s: ['front shoulders', 'triceps'],
      how: 'Lie on the bench under the bar. Unhook it, lower it to your chest, and press straight back up.'),
  _bw('dips', 'Dips', 'push', [['dip_bars'], ['assisted_machine']], const RepRange(5, 8),
      const Ladder([Variant('Assisted dips', 'band under the knees or the assist machine'), Variant('Negative dips', 'jump up, lower over 3 seconds'), Variant('Dips'), Variant('Paused dips', '2 seconds at the bottom'), Variant('Deep dips', 'full range, slow down')], start: [0, 1, 2], loadGear: _beltOrVest),
      cost: 4, rank: 10, ref: 'Dips_-_Chest_Version', p: ['chest'], s: ['front shoulders', 'triceps'],
      how: 'Support yourself on the bars with straight arms. Lean slightly forward and lower until your upper arms are about parallel with the floor, then push back up.'),
  _kg('cable_fly', 'Cable fly', 'push', [['cable']], [5, 8, 12], 2.5, each: true, cost: 1, rank: 11, ref: 'Cable_Crossover',
      p: ['chest'], s: ['front shoulders'],
      how: 'Stand between the cables with a handle in each hand, slight bend in the elbows. Bring your hands together in front of your chest in an arc, then open slowly.'),
  _bw('pushup', 'Push-ups', 'push', [[]], const RepRange(6, 10),
      const Ladder([Variant('Wall push-ups'), Variant('Incline push-ups', 'hands on a bench or counter'), Variant('Knee push-ups'), Variant('Push-ups'), Variant('Feet-elevated push-ups'), Variant('Archer push-ups', 'one arm does most of the work')], start: [2, 3, 4], loadGear: _vestOrPack),
      cost: 3, rank: 12, ref: 'Pushups', p: ['chest'], s: ['front shoulders', 'triceps', 'abs'],
      how: 'Hands under your shoulders, body in a straight line. Lower your chest to just above the floor with elbows tucked about 45 degrees, then push back up.'),
  _bw('pike_pushup', 'Pike push-ups', 'push', [[]], const RepRange(5, 8),
      const Ladder([Variant('Short pike push-ups', 'hips high, small bend'), Variant('Pike push-ups'), Variant('Feet-elevated pike push-ups'), Variant('Wall handstand push-ups, partial'), Variant('Wall handstand push-ups')], start: [0, 1, 2]),
      cost: 3, rank: 13, ref: 'Handstand_Push-Ups', p: ['front shoulders'], s: ['side shoulders', 'triceps', 'chest'],
      how: 'From a push-up position, walk your feet in so your hips are high and your body forms an upside-down V. Bend your elbows to lower the top of your head toward the floor, then press back up.'),
  // ---------- pull
  _kg('bb_row', 'Barbell row', 'pull', [['barbell']], [20, 30, 40], 2.5, cost: 4, rank: 1, ref: 'Bent_Over_Barbell_Row',
      p: ['upper back'], s: ['lats', 'biceps', 'rear shoulders'],
      how: 'Hinge forward with a flat back until your torso is about 45 degrees, bar hanging at arm\'s length. Pull it to your lower ribs, squeeze your shoulder blades, and lower under control.'),
  _kg('db_row', 'Dumbbell row', 'pull', [['dumbbell']], [10, 14, 18], 2, each: true, cost: 3, rank: 2, ref: 'Bent_Over_Two-Dumbbell_Row',
      p: ['upper back'], s: ['lats', 'biceps', 'rear shoulders'],
      how: 'Support one hand on a bench or your knee, flat back. Pull the dumbbell to your hip, elbow close to your body, then lower all the way. Do both sides.'),
  _kg('pulldown', 'Lat pulldown', 'pull', [['lat_pulldown'], ['cable']], [25, 35, 45], 2.5, cost: 2, rank: 3, ref: 'Wide-Grip_Lat_Pulldown',
      p: ['lats'], s: ['biceps', 'upper back', 'rear shoulders'],
      how: 'Grip the bar wider than your shoulders, sit tall. Pull the bar down to your upper chest, leading with your elbows, then let it rise slowly until your arms are straight.'),
  _kg('cable_row', 'Seated cable row', 'pull', [['row_machine'], ['cable']], [25, 35, 45], 2.5, cost: 2, rank: 4, ref: 'Seated_Cable_Rows',
      p: ['upper back'], s: ['lats', 'biceps', 'rear shoulders'],
      how: 'Sit with knees slightly bent, chest up. Pull the handle to your stomach, squeezing your shoulder blades together, then reach forward under control.'),
  _bw('pullup', 'Pull-ups', 'pull', [['pullup_bar']], const RepRange(3, 6),
      const Ladder([Variant('Assisted pull-ups', 'band under a foot, or toes on a chair'), Variant('Negative pull-ups', 'jump to the top, lower over 3 seconds'), Variant('Pull-ups'), Variant('Paused pull-ups', '2 seconds at the top'), Variant('Chest-to-bar pull-ups')], start: [0, 1, 2], loadGear: _beltOrVest),
      cost: 4, rank: 5, ref: 'Pullups', p: ['lats'], s: ['biceps', 'upper back'],
      how: 'Hang from the bar with palms facing away. Pull until your chin clears the bar, then lower all the way.'),
  _kg('assisted_pullup', 'Assisted pull-ups', 'pull', [['assisted_machine']], [40, 30, 20], 5, cost: 2, rank: 6, ref: 'Pullups',
      p: ['lats'], s: ['biceps', 'upper back'],
      how: 'Kneel on the pad, grip the handles. Pull until your chin passes your hands, then lower slowly. On this machine, lower weight means harder.'),
  _kg('kb_row', 'Kettlebell row', 'pull', [['kettlebell']], [12, 16, 20], 4, each: true, cost: 3, rank: 7, ref: 'One-Arm_Kettlebell_Row',
      p: ['upper back'], s: ['lats', 'biceps', 'rear shoulders'],
      how: 'Hinge forward with one hand braced on your knee. Row the kettlebell to your hip, pause, and lower. Do both sides.'),
  _bw('trx_row', 'Suspension row', 'pull', [['suspension']], const RepRange(8, 12),
      const Ladder([Variant('Upright suspension row', 'body nearly vertical'), Variant('Suspension row', 'body at 45 degrees'), Variant('Low suspension row', 'body nearly flat'), Variant('Feet-elevated suspension row'), Variant('Single-arm suspension row')], start: [0, 1, 2]),
      cost: 2, rank: 8, ref: 'Inverted_Row_with_Straps', p: ['upper back'], s: ['lats', 'biceps', 'rear shoulders'],
      how: 'Lean back holding the handles with straight arms, body in a line. Pull your chest to your hands, then lower.'),
  _bw('band_row', 'Band row', 'pull', [['band']], const RepRange(10, 15),
      const Ladder([Variant('Light band row'), Variant('Medium band row'), Variant('Heavy band row'), Variant('Doubled band row', 'two bands, or the band doubled over')], start: [0, 1, 1]),
      cost: 1, rank: 9, ref: 'Inverted_Row', p: ['upper back'], s: ['lats', 'biceps', 'rear shoulders'],
      how: 'Anchor the band at chest height or loop it around your feet while seated. Pull the handles to your ribs with elbows tucked, squeeze, and return slowly.'),
  _bw('inverted_row', 'Inverted row', 'pull', [[]], const RepRange(6, 10),
      const Ladder([Variant('Knees-bent inverted row'), Variant('Inverted row'), Variant('Feet-elevated inverted row'), Variant('Paused inverted row', '2 seconds at the top'), Variant('Single-arm inverted row')], start: [0, 1, 2], loadGear: _vestOrPack),
      cost: 3, rank: 10, ref: 'Inverted_Row', p: ['upper back'], s: ['lats', 'biceps', 'rear shoulders'],
      how: 'Lie under a sturdy table edge or low bar and grip it. Keep your body straight and pull your chest up to it, then lower.'),
  // ---------- squat
  _kg('bb_squat', 'Barbell back squat', 'squat', [['barbell', 'squat_rack']], [20, 40, 60], 2.5, cost: 5, rank: 1, ref: 'Barbell_Full_Squat',
      p: ['quads', 'glutes'], s: ['hamstrings', 'lower back', 'calves', 'inner thighs'],
      how: 'Bar on your upper back, feet shoulder width, toes slightly out. Sit down between your knees until your thighs are at least parallel, then drive back up through your whole foot.'),
  _kg('smith_squat', 'Smith machine squat', 'squat', [['smith']], [20, 40, 60], 2.5, cost: 4, rank: 2, ref: 'Smith_Machine_Squat',
      p: ['quads', 'glutes'], s: ['hamstrings', 'calves'],
      how: 'Bar on your upper back, feet slightly in front of you. Unhook, squat until your thighs are parallel, and stand back up.'),
  _kg('goblet', 'Goblet squat', 'squat', [['dumbbell'], ['kettlebell']], [8, 12, 16], 2, cost: 3, rank: 3, ref: 'Dumbbell_Squat',
      p: ['quads', 'glutes'], s: ['hamstrings', 'abs', 'inner thighs'],
      how: 'Hold one weight against your chest with both hands. Squat as deep as you comfortably can, elbows inside your knees, then stand up.'),
  _kg('leg_press', 'Leg press', 'squat', [['leg_press']], [40, 60, 90], 5, cost: 2, rank: 4, ref: 'Leg_Press',
      p: ['quads', 'glutes'], s: ['hamstrings', 'calves'],
      how: 'Feet shoulder width on the platform. Lower the sled until your knees are at about 90 degrees without letting your lower back lift, then press back out without locking your knees.'),
  _kg('hack_squat', 'Hack squat', 'squat', [['hack_squat']], [40, 60, 80], 5, cost: 3, rank: 5, ref: 'Hack_Squat',
      p: ['quads'], s: ['glutes', 'hamstrings', 'calves'],
      how: 'Shoulders under the pads, feet mid-platform. Lower until your thighs are parallel, then press back up.'),
  _kg('db_split', 'Dumbbell split squat', 'squat', [['dumbbell']], [6, 8, 12], 2, each: true, cost: 3, rank: 6, ref: 'Split_Squat_with_Dumbbells',
      p: ['quads', 'glutes'], s: ['hamstrings'],
      how: 'Stand in a long stride with a dumbbell in each hand. Lower your back knee toward the floor, keeping your front shin upright, then stand. Do both sides.'),
  _bw('step_up', 'Step-ups', 'squat', [['box'], ['bench_flat']], const RepRange(8, 12),
      const Ladder([Variant('Low step-ups', 'shin-height step'), Variant('Step-ups', 'knee-height step'), Variant('High step-ups', 'above the knee'), Variant('Slow step-downs', '3 seconds down')], start: [0, 1, 2], loadGear: _vestOrPack),
      cost: 3, rank: 7, ref: 'Dumbbell_Step_Ups', p: ['quads', 'glutes'], s: ['hamstrings', 'calves', 'outer hips'],
      how: 'Place one whole foot on the box. Push through that foot to stand on top, then step down slowly. Do all reps on one side, then switch.'),
  _bw('bw_squat', 'Bodyweight squat', 'squat', [[]], const RepRange(10, 15),
      const Ladder([Variant('Box squats', 'sit to a chair and stand'), Variant('Bodyweight squats'), Variant('Paused squats', '2 seconds at the bottom'), Variant('Tempo squats', '3 seconds down'), Variant('Cossack squats', 'wide stance, shift side to side'), Variant('Pistol squats to a box')], start: [1, 1, 2], loadGear: _vestOrPack),
      cost: 3, rank: 8, ref: 'Bodyweight_Squat', p: ['quads', 'glutes'], s: ['hamstrings'],
      how: 'Feet shoulder width, arms out in front for balance. Sit back and down until your thighs are at least parallel, then stand up.'),
  _bw('bw_split', 'Split squat', 'squat', [[]], const RepRange(6, 10),
      const Ladder([Variant('Supported split squats', 'hand on a wall'), Variant('Split squats'), Variant('Rear-foot-elevated split squats'), Variant('Paused rear-foot-elevated split squats', '2 seconds at the bottom')], start: [0, 1, 2], loadGear: _vestOrPack),
      cost: 3, rank: 9, ref: 'Split_Squats', p: ['quads', 'glutes'], s: ['hamstrings', 'calves'],
      how: 'Long stride stance. Lower your back knee toward the floor, front shin upright, then stand. Do both sides.'),
  // ---------- hinge
  _kg('deadlift', 'Deadlift', 'hinge', [['barbell']], [40, 60, 80], 2.5, cost: 5, rank: 1, ref: 'Barbell_Deadlift',
      p: ['hamstrings', 'glutes', 'lower back'], s: ['quads', 'traps', 'forearms', 'lats'],
      how: 'Bar over mid-foot, grip just outside your legs, flat back, chest up. Push the floor away and stand tall with the bar close to your legs, then lower it the same way.'),
  _kg('trap_deadlift', 'Trap bar deadlift', 'hinge', [['trap_bar']], [40, 60, 80], 2.5, cost: 5, rank: 2, ref: 'Trap_Bar_Deadlift',
      p: ['hamstrings', 'glutes', 'quads'], s: ['lower back', 'traps', 'forearms'],
      how: 'Stand inside the bar, grip the handles, flat back. Stand up tall, then lower it under control. Easier on the back than a straight bar.'),
  _kg('rdl', 'Romanian deadlift', 'hinge', [['barbell']], [30, 40, 60], 2.5, cost: 4, rank: 3, ref: 'Romanian_Deadlift',
      p: ['hamstrings', 'glutes'], s: ['lower back', 'forearms'],
      how: 'Hold the bar at your hips. Push your hips back and lower the bar down your legs with a flat back and soft knees until you feel your hamstrings, then stand up.'),
  _kg('db_rdl', 'Dumbbell Romanian deadlift', 'hinge', [['dumbbell']], [10, 14, 18], 2, each: true, cost: 3, rank: 4, ref: 'Romanian_Deadlift',
      p: ['hamstrings', 'glutes'], s: ['lower back'],
      how: 'Dumbbells in front of your thighs. Push your hips back, keeping the weights close to your legs and your back flat, until your hamstrings stretch. Stand up by squeezing your glutes.'),
  _kg('kb_swing', 'Kettlebell swing', 'hinge', [['kettlebell']], [12, 16, 20], 4, cost: 3, rank: 5, ref: 'One-Arm_Kettlebell_Swings',
      p: ['hamstrings', 'glutes'], s: ['lower back', 'abs'],
      how: 'Hike the bell back between your legs, then snap your hips forward to swing it to chest height. Arms stay relaxed; the hips do the work.'),
  _kg('hip_thrust', 'Barbell hip thrust', 'hinge', [['barbell', 'bench_flat']], [30, 40, 60], 5, cost: 3, rank: 6, ref: 'Barbell_Hip_Thrust',
      p: ['glutes'], s: ['hamstrings'],
      how: 'Upper back on the bench, bar across your hips, feet flat. Drive your hips up until your body is level from shoulders to knees, squeeze, and lower.'),
  _bw('back_ext', 'Back extension', 'hinge', [['back_extension']], const RepRange(10, 15),
      const Ladder([Variant('Partial back extensions'), Variant('Back extensions'), Variant('Paused back extensions', '2 seconds at the top'), Variant('Slow back extensions', '3 seconds each way')], start: [0, 1, 1], loadGear: _vestOrPack),
      cost: 2, rank: 7, ref: 'Hyperextensions_Back_Extensions', p: ['lower back', 'glutes'], s: ['hamstrings'],
      how: 'Hips on the pad, feet locked in. Hinge down until your torso is below the pad, then raise it until your body is in a straight line. Do not arch past straight.'),
  _bw('glute_bridge', 'Glute bridge', 'hinge', [[]], const RepRange(10, 15),
      const Ladder([Variant('Glute bridges'), Variant('Paused glute bridges', '2 seconds at the top'), Variant('Feet-elevated glute bridges'), Variant('Single-leg glute bridges'), Variant('Single-leg feet-elevated glute bridges')], start: [0, 1, 2], loadGear: _vestOrPack),
      cost: 1, rank: 8, ref: 'Single_Leg_Glute_Bridge', p: ['glutes'], s: ['hamstrings'],
      how: 'Lie on your back, knees bent, feet flat. Drive through your heels to lift your hips until your body is straight from shoulders to knees, squeeze, and lower.'),
  _bw('sl_rdl', 'Single-leg Romanian deadlift', 'hinge', [[]], const RepRange(6, 10),
      const Ladder([Variant('Supported single-leg RDL', 'hand on a wall'), Variant('Single-leg RDL'), Variant('Paused single-leg RDL', '2 seconds at the bottom'), Variant('Slow single-leg RDL', '3 seconds down')], start: [0, 1, 1]),
      cost: 2, rank: 9, ref: 'Kettlebell_One-Legged_Deadlift', p: ['hamstrings', 'glutes'], s: ['lower back', 'outer hips'],
      how: 'Balance on one leg. Hinge forward with a flat back, letting the other leg float behind you, until your torso is near horizontal. Stand back up. Do both sides.'),
  // ---------- core
  _bw('dead_bug', 'Dead bug', 'core', [[]], const RepRange(8, 12),
      const Ladder([Variant('Dead bug, arms only'), Variant('Dead bug, legs only'), Variant('Dead bug'), Variant('Slow dead bug', '3 seconds each rep'), Variant('Dead bug with heel taps', 'leg fully extended')], start: [1, 2, 2]),
      cost: 1, rank: 1, ref: 'Dead_Bug', p: ['abs'], s: ['obliques'],
      how: 'Lie on your back, arms straight up, knees over hips. Lower one arm overhead and the opposite leg toward the floor while your lower back stays pressed down. Return and switch.'),
  _bw('hanging_knee', 'Hanging knee raise', 'core', [['pullup_bar'], ['dip_bars']], const RepRange(6, 10),
      const Ladder([Variant('Hanging knee tucks'), Variant('Hanging knee raises'), Variant('Paused hanging knee raises', '2 seconds at the top'), Variant('Hanging straight-leg raises'), Variant('Toes to bar')], start: [0, 1, 2]),
      cost: 2, rank: 2, ref: 'Hanging_Leg_Raise', p: ['abs'], s: ['forearms'],
      how: 'Hang from the bar. Draw your knees up toward your chest, curling your hips slightly, then lower slowly without swinging.'),
  _kg('cable_crunch', 'Cable crunch', 'core', [['cable']], [20, 30, 40], 2.5, cost: 1, rank: 3, ref: 'Cable_Crunch',
      p: ['abs'],
      how: 'Kneel facing the cable with the rope held at your forehead. Crunch your elbows toward your knees by curling your spine, then return slowly.'),
  _kg('pallof', 'Pallof press', 'core', [['cable'], ['band']], [10, 15, 20], 2.5, cost: 1, rank: 4, ref: 'Pallof_Press',
      p: ['obliques'], s: ['abs'],
      how: 'Stand side-on to the cable with the handle at your chest. Press it straight out and hold without letting it pull you around, then bring it back. Do both sides.'),
  _bw('ab_wheel', 'Ab wheel rollout', 'core', [['ab_wheel']], const RepRange(5, 8),
      const Ladder([Variant('Short rollouts', 'roll to a wall stop'), Variant('Half rollouts'), Variant('Kneeling rollouts'), Variant('Paused kneeling rollouts', '2 seconds extended'), Variant('Standing rollouts')], start: [0, 1, 2]),
      cost: 2, rank: 5, ref: 'Ab_Roller', p: ['abs'], s: ['lats'],
      how: 'Kneel with the wheel under your shoulders. Roll forward as far as you can keep your lower back from sagging, then pull back to the start.'),
  _bw('mb_slam', 'Medicine ball slam', 'core', [['medicine_ball']], const RepRange(8, 12),
      const Ladder([Variant('Light ball slams'), Variant('Ball slams'), Variant('Heavy ball slams'), Variant('Rotational slams', 'slam to alternate sides')], start: [0, 1, 1]),
      cost: 2, rank: 6, ref: 'One-Arm_Medicine_Ball_Slam', p: ['abs'], s: ['lats'],
      how: 'Raise the ball overhead, then slam it into the floor as hard as you can by folding at the hips. Pick it up and repeat.'),
  _bw('situp', 'Sit-ups', 'core', [[]], const RepRange(10, 15),
      const Ladder([Variant('Crunches'), Variant('Sit-ups'), Variant('Slow sit-ups', '3 seconds down'), Variant('Straight-leg sit-ups'), Variant('V-ups')], start: [0, 1, 1]),
      cost: 1, rank: 7, ref: 'Sit-Up', p: ['abs'],
      how: 'Lie on your back with knees bent. Curl up until your chest reaches your thighs, then lower slowly.'),
  // ---------- carry
  _kg('farmer', "Farmer's carry", 'carry', [['dumbbell'], ['kettlebell'], ['trap_bar']], [12, 16, 24], 4, each: true, repLabel: 'steps', cost: 3, rank: 1, ref: 'Farmers_Walk',
      p: ['forearms', 'traps'], s: ['abs', 'glutes', 'quads'],
      how: 'Pick up a heavy weight in each hand. Stand tall, shoulders back, and walk with short quick steps. Count the steps.'),
  _kg('suitcase', 'Suitcase carry', 'carry', [['dumbbell'], ['kettlebell']], [12, 16, 24], 4, repLabel: 'steps', cost: 2, rank: 2, ref: 'Farmers_Walk',
      p: ['obliques', 'forearms'], s: ['traps', 'glutes'],
      how: 'Carry one heavy weight in one hand like a suitcase and walk without leaning. Switch hands halfway.'),
  // ---------- arms
  _kg('db_curl', 'Dumbbell curl', 'arms', [['dumbbell']], [6, 8, 10], 2, each: true, cost: 1, rank: 1, ref: 'Dumbbell_Bicep_Curl',
      p: ['biceps'], s: ['forearms'],
      how: 'Stand with dumbbells at your sides, palms forward. Curl them to your shoulders without swinging, then lower slowly.'),
  _kg('pushdown', 'Triceps pushdown', 'arms', [['cable']], [15, 20, 25], 2.5, cost: 1, rank: 2, ref: 'Triceps_Pushdown',
      p: ['triceps'],
      how: 'Elbows pinned to your sides, grip the bar or rope at chest height. Push down until your arms are straight, then let it rise to chest height.'),
  _kg('ez_curl', 'EZ bar curl', 'arms', [['ez_bar']], [15, 20, 25], 2.5, cost: 1, rank: 3, ref: 'EZ-Bar_Curl',
      p: ['biceps'], s: ['forearms'],
      how: 'Hold the bar on the angled grips. Curl it to your shoulders keeping your elbows still, then lower slowly.'),
  _kg('skull_crusher', 'Skull crusher', 'arms', [['ez_bar', 'bench_flat'], ['dumbbell', 'bench_flat']], [10, 15, 20], 2.5, cost: 1, rank: 4, ref: 'EZ-Bar_Skullcrusher',
      p: ['triceps'],
      how: 'Lie on the bench with the bar above your chest. Bend only your elbows to lower it toward your forehead, then straighten your arms.'),
  _kg('bb_curl', 'Barbell curl', 'arms', [['barbell']], [15, 20, 25], 2.5, cost: 1, rank: 5, ref: 'Barbell_Curl',
      p: ['biceps'], s: ['forearms'],
      how: 'Hold the bar at your thighs, palms forward. Curl to your shoulders without leaning back, then lower slowly.'),
  _bw('tri_dips', 'Triceps dips', 'arms', [['dip_bars']], const RepRange(5, 8),
      const Ladder([Variant('Assisted triceps dips', 'band under the knees'), Variant('Negative triceps dips', 'lower over 3 seconds'), Variant('Triceps dips'), Variant('Paused triceps dips', '2 seconds at the bottom')], start: [0, 1, 2], loadGear: _beltOrVest),
      cost: 2, rank: 6, ref: 'Dips_-_Triceps_Version', p: ['triceps'], s: ['chest', 'front shoulders'],
      how: 'On the bars with your body upright, lower until your elbows are at 90 degrees, then push back up.'),
  _bw('bench_dip', 'Bench dips', 'arms', [['bench_flat'], ['box']], const RepRange(8, 12),
      const Ladder([Variant('Bench dips, knees bent'), Variant('Bench dips, legs straight'), Variant('Feet-elevated bench dips'), Variant('Paused feet-elevated bench dips', '2 seconds at the bottom')], start: [0, 1, 2]),
      cost: 1, rank: 7, ref: 'Bench_Dips', p: ['triceps'], s: ['chest', 'front shoulders'],
      how: 'Hands on the bench edge behind you, legs out in front. Bend your elbows to lower your hips toward the floor, then push back up.'),
  _bw('band_curl', 'Band curl', 'arms', [['band']], const RepRange(12, 16),
      const Ladder([Variant('Light band curls'), Variant('Medium band curls'), Variant('Heavy band curls'), Variant('Doubled band curls')], start: [0, 1, 1]),
      cost: 1, rank: 8, ref: 'Barbell_Curl', p: ['biceps'], s: ['forearms'],
      how: 'Stand on the band, handles in your hands. Curl to your shoulders and lower slowly.'),
  _bw('diamond_pushup', 'Close-grip push-ups', 'arms', [[]], const RepRange(5, 8),
      const Ladder([Variant('Incline close-grip push-ups'), Variant('Knee close-grip push-ups'), Variant('Close-grip push-ups'), Variant('Feet-elevated close-grip push-ups'), Variant('Paused close-grip push-ups', '2 seconds at the bottom')], start: [0, 1, 2], loadGear: _vestOrPack),
      cost: 2, rank: 9, ref: 'Push-Ups_-_Close_Triceps_Position', p: ['triceps'], s: ['chest', 'front shoulders'],
      how: 'Push-up position with your hands close together under your chest. Lower with elbows tucked tight, then press up.'),
  // ---------- shoulders
  _kg('lat_raise', 'Lateral raise', 'shoulders', [['dumbbell']], [4, 6, 8], 2, each: true, cost: 1, rank: 1, ref: 'Side_Lateral_Raise',
      p: ['side shoulders'], s: ['traps'],
      how: 'Dumbbells at your sides, slight bend in the elbows. Raise your arms out to the sides until they are level with your shoulders, then lower slowly.'),
  _kg('face_pull', 'Face pull', 'shoulders', [['cable']], [10, 15, 20], 2.5, cost: 1, rank: 2, ref: 'Face_Pull',
      p: ['rear shoulders'], s: ['upper back', 'traps'],
      how: 'Rope at face height. Pull it toward your face, elbows high and wide, until your hands are beside your ears. Return slowly.'),
  _kg('rear_fly', 'Rear delt fly', 'shoulders', [['dumbbell']], [4, 6, 8], 2, each: true, cost: 1, rank: 3, ref: 'Reverse_Flyes',
      p: ['rear shoulders'], s: ['upper back'],
      how: 'Hinge forward with a flat back, dumbbells hanging below you. Raise your arms out to the sides, squeezing your shoulder blades, then lower.'),
  _kg('machine_shoulder', 'Machine shoulder press', 'shoulders', [['shoulder_press_machine']], [15, 20, 30], 5, cost: 2, rank: 4, ref: 'Machine_Shoulder_Military_Press',
      p: ['front shoulders'], s: ['side shoulders', 'triceps'],
      how: 'Seat set so the handles start at shoulder height. Press up until your arms are nearly straight, then lower.'),
  _bw('band_pull_apart', 'Band pull-apart', 'shoulders', [['band']], const RepRange(12, 16),
      const Ladder([Variant('Light band pull-aparts'), Variant('Medium band pull-aparts'), Variant('Heavy band pull-aparts'), Variant('Doubled band pull-aparts')], start: [0, 1, 1]),
      cost: 1, rank: 5, ref: 'Band_Pull_Apart', p: ['rear shoulders'], s: ['upper back', 'traps'],
      how: 'Hold the band in front of you at shoulder height, arms straight. Pull your hands apart until the band touches your chest, then return slowly.'),
  // ---------- legs (accessory)
  _kg('leg_curl', 'Leg curl', 'legs', [['leg_curl']], [15, 25, 35], 5, cost: 1, rank: 1, ref: 'Lying_Leg_Curls',
      p: ['hamstrings'], s: ['calves'],
      how: 'Pad just above your heels. Curl your heels toward your glutes, pause, and lower slowly.'),
  _kg('leg_ext', 'Leg extension', 'legs', [['leg_extension']], [15, 25, 35], 5, cost: 1, rank: 2, ref: 'Leg_Extensions',
      p: ['quads'],
      how: 'Pad on your shins. Straighten your legs fully, pause, and lower slowly.'),
  _bw('calf_raise', 'Calf raise', 'legs', [['calf_machine'], ['box'], []], const RepRange(12, 20),
      const Ladder([Variant('Calf raises on the floor'), Variant('Calf raises on an edge'), Variant('Paused calf raises on an edge', '2 seconds at the top'), Variant('Single-leg calf raises'), Variant('Paused single-leg calf raises')], start: [0, 1, 2], loadGear: _vestOrPack),
      cost: 1, rank: 3, ref: 'Calf_Raise_On_A_Dumbbell', p: ['calves'],
      how: 'Stand on the balls of your feet on an edge. Rise as high as you can, pause, then lower your heels below the edge.'),
  _bw('reverse_lunge', 'Reverse lunge', 'legs', [[]], const RepRange(8, 12),
      const Ladder([Variant('Supported reverse lunges', 'hand on a wall'), Variant('Reverse lunges'), Variant('Deficit reverse lunges', 'front foot on a step'), Variant('Paused deficit reverse lunges', '2 seconds at the bottom')], start: [0, 1, 2], loadGear: _vestOrPack),
      cost: 2, rank: 4, ref: 'Dumbbell_Rear_Lunge', p: ['quads', 'glutes'], s: ['hamstrings'],
      how: 'Step one foot back and lower that knee toward the floor, front shin upright. Push through the front foot to stand. Alternate sides.'),

  // ====================================================================================================================
  // Fuller catalogue. Loaded movements are standalone exercises; bodyweight movements are rungs on a ladder.
  // ---------- push, more
  _kg('incline_bb', 'Incline barbell bench press', 'push', [['barbell', 'bench_incline']], [20, 30, 40], 2.5, cost: 4, rank: 14, ref: 'Barbell_Incline_Bench_Press_-_Medium_Grip',
      p: ['chest'], s: ['front shoulders', 'triceps'],
      how: 'Bench at a low incline, bar over your upper chest. Lower it to just below the collarbones, then press back up.'),
  _kg('close_grip_bench', 'Close-grip bench press', 'push', [['barbell', 'bench_flat']], [20, 30, 40], 2.5, cost: 4, rank: 15, ref: 'Close-Grip_Barbell_Bench_Press',
      p: ['triceps'], s: ['chest', 'front shoulders'],
      how: 'Hands just inside shoulder width. Lower the bar to your lower chest with elbows tucked, then press up.'),
  _kg('landmine_press', 'Landmine press', 'push', [['landmine']], [10, 15, 20], 2.5, cost: 3, rank: 16, ref: 'Landmine_Press',
      p: ['front shoulders'], s: ['chest', 'triceps'],
      how: 'Bar end at your shoulder, feet staggered. Press it up and forward until your arm is straight, then lower.'),
  _kg('db_fly', 'Dumbbell fly', 'push', [['dumbbell', 'bench_flat']], [4, 6, 10], 2, each: true, cost: 1, rank: 17, ref: 'Dumbbell_Flyes',
      p: ['chest'], s: ['front shoulders'],
      how: 'Lie on the bench, dumbbells above your chest, slight bend in the elbows. Open your arms wide until you feel a stretch, then bring them back together.'),
  _kg('pec_deck', 'Pec deck', 'push', [['pec_deck']], [15, 25, 35], 5, cost: 1, rank: 18, ref: 'Butterfly',
      p: ['chest'], s: ['front shoulders'],
      how: 'Elbows or forearms on the pads at chest height. Squeeze the pads together in front of you, pause, and open slowly.'),
  _kg('kb_floor_press', 'Kettlebell floor press', 'push', [['kettlebell']], [8, 12, 16], 4, each: true, cost: 3, rank: 19, ref: 'Kettlebell_Floor_Press',
      p: ['chest'], s: ['front shoulders', 'triceps'],
      how: 'Lie on the floor, bell resting on the back of your forearm. Press up until your arm is straight, then lower until your upper arm touches the floor.'),
  _kg('smith_ohp', 'Smith machine shoulder press', 'push', [['smith']], [15, 20, 30], 2.5, cost: 3, rank: 20, ref: 'Smith_Machine_Overhead_Shoulder_Press',
      p: ['front shoulders'], s: ['side shoulders', 'triceps'],
      how: 'Seated under the bar with it at collarbone height. Unhook, press overhead to lockout, and lower under control.'),
  _bw('trx_pushup', 'Suspension push-ups', 'push', [['suspension']], const RepRange(6, 10),
      const Ladder([Variant('Upright suspension push-ups', 'body nearly vertical'), Variant('Suspension push-ups', 'body at 45 degrees'), Variant('Low suspension push-ups', 'body nearly flat'), Variant('Feet-elevated suspension push-ups'), Variant('Suspension archer push-ups')], start: [0, 1, 2]),
      cost: 3, rank: 21, ref: 'Suspended_Push-Up', p: ['chest'], s: ['front shoulders', 'triceps', 'abs'],
      how: 'Handles low, body in a straight line. Lower your chest between the handles, then press back up without letting the straps wobble.'),
  _bw('band_press', 'Band chest press', 'push', [['band']], const RepRange(10, 15),
      const Ladder([Variant('Light band chest press'), Variant('Medium band chest press'), Variant('Heavy band chest press'), Variant('Doubled band chest press')], start: [0, 1, 1]),
      cost: 1, rank: 22, ref: 'Band_Chest_Press', p: ['chest'], s: ['front shoulders', 'triceps'],
      how: 'Band anchored behind you at chest height, handles at your chest. Press forward until your arms are straight, then return slowly.'),
  // ---------- pull, more
  _bw('chinup', 'Chin-ups', 'pull', [['pullup_bar']], const RepRange(3, 6),
      const Ladder([Variant('Assisted chin-ups', 'band under a foot, or toes on a chair'), Variant('Negative chin-ups', 'jump to the top, lower over 3 seconds'), Variant('Chin-ups'), Variant('Paused chin-ups', '2 seconds at the top'), Variant('Chest-to-bar chin-ups')], start: [0, 1, 2], loadGear: _beltOrVest),
      cost: 4, rank: 11, ref: 'Chin-Up', p: ['lats', 'biceps'], s: ['upper back'],
      how: 'Hang with palms facing you, hands shoulder width. Pull until your chin clears the bar, then lower all the way.'),
  _kg('tbar_row', 'T-bar row', 'pull', [['landmine']], [20, 30, 40], 2.5, cost: 4, rank: 12, ref: 'Bent_Over_Barbell_Row',
      p: ['upper back'], s: ['lats', 'biceps', 'rear shoulders'],
      how: 'Straddle the bar, hinge forward with a flat back, grip the handle. Row it to your chest, squeeze, and lower under control.'),
  _kg('chest_supported_row', 'Chest-supported dumbbell row', 'pull', [['dumbbell', 'bench_incline']], [8, 12, 16], 2, each: true, cost: 2, rank: 13, ref: 'Incline_Dumbbell_Row',
      p: ['upper back'], s: ['lats', 'biceps', 'rear shoulders'],
      how: 'Lie chest-down on an incline bench, dumbbells hanging. Row them to your hips with elbows close, pause, and lower.'),
  _kg('cable_row_single', 'Single-arm cable row', 'pull', [['cable']], [15, 20, 25], 2.5, each: true, cost: 2, rank: 14, ref: 'One_Arm_Cable_Row',
      p: ['upper back'], s: ['lats', 'biceps', 'rear shoulders'],
      how: 'Handle at waist height, one hand. Row to your hip without twisting, pause, and reach forward. Do both sides.'),
  _kg('landmine_row', 'Landmine row', 'pull', [['landmine']], [15, 20, 30], 2.5, cost: 3, rank: 15, ref: 'Bent_Over_Barbell_Row',
      p: ['upper back'], s: ['lats', 'biceps', 'rear shoulders'],
      how: 'Stand beside the bar end, hinge forward, grip it with one hand. Row to your hip, pause, and lower. Do both sides.'),
  _kg('straight_arm_pulldown', 'Straight-arm pulldown', 'pull', [['cable']], [10, 15, 20], 2.5, cost: 1, rank: 16, ref: 'Straight-Arm_Pulldown',
      p: ['lats'], s: ['triceps'],
      how: 'Bar at the high cable, arms straight, hinge slightly. Pull the bar down to your thighs in an arc, then let it rise slowly.'),
  _kg('db_pullover', 'Dumbbell pullover', 'pull', [['dumbbell', 'bench_flat']], [8, 12, 16], 2, cost: 2, rank: 17, ref: 'Bent-Arm_Dumbbell_Pullover',
      p: ['lats'], s: ['chest', 'triceps'],
      how: 'Lie across or along the bench, one dumbbell held over your chest with both hands. Lower it behind your head until you feel a stretch, then pull it back over.'),
  _bw('band_pulldown', 'Band pulldown', 'pull', [['band']], const RepRange(10, 15),
      const Ladder([Variant('Light band pulldown'), Variant('Medium band pulldown'), Variant('Heavy band pulldown'), Variant('Doubled band pulldown')], start: [0, 1, 1]),
      cost: 1, rank: 18, ref: 'Band_Pulldown', p: ['lats'], s: ['biceps', 'upper back'],
      how: 'Band anchored high. Kneel or sit, pull the handles down to your chest leading with your elbows, and return slowly.'),
  // ---------- squat, more
  _kg('front_squat', 'Front squat', 'squat', [['barbell', 'squat_rack']], [20, 30, 50], 2.5, cost: 5, rank: 10, ref: 'Front_Barbell_Squat',
      p: ['quads', 'glutes'], s: ['abs', 'hamstrings', 'inner thighs'],
      how: 'Bar on the front of your shoulders, elbows high. Squat straight down keeping your chest up, then drive back up.'),
  _kg('box_squat_bb', 'Barbell box squat', 'squat', [['barbell', 'squat_rack', 'box']], [20, 40, 60], 2.5, cost: 4, rank: 11, ref: 'Box_Squat',
      p: ['quads', 'glutes'], s: ['hamstrings', 'lower back', 'inner thighs'],
      how: 'Bar on your back, box behind you. Sit back onto the box under control, pause without relaxing, and stand up.'),
  _kg('kb_front_squat', 'Kettlebell front squat', 'squat', [['kettlebell']], [12, 16, 24], 4, cost: 3, rank: 12, ref: 'Kettlebell_Front_Squat',
      p: ['quads', 'glutes'], s: ['abs', 'hamstrings'],
      how: 'Bell in the rack position at your shoulder, or two bells. Squat deep with your chest up, then stand.'),
  _kg('db_bulgarian', 'Bulgarian split squat, dumbbells', 'squat', [['dumbbell', 'bench_flat']], [6, 8, 12], 2, each: true, cost: 3, rank: 13, ref: 'Dumbbell_Bulgarian_Split_Squat',
      p: ['quads', 'glutes'], s: ['hamstrings', 'outer hips'],
      how: 'Rear foot on the bench, dumbbells at your sides. Lower until your front thigh is parallel, then drive up. Do both sides.'),
  _kg('walking_lunge_db', 'Walking lunge, dumbbells', 'squat', [['dumbbell']], [6, 8, 12], 2, each: true, cost: 3, rank: 14, ref: 'Dumbbell_Lunges',
      p: ['quads', 'glutes'], s: ['hamstrings', 'calves'],
      how: 'Dumbbells at your sides. Step forward into a lunge, lower the back knee toward the floor, then step through into the next one.'),
  _kg('db_step_up', 'Step-ups, dumbbells', 'squat', [['dumbbell', 'box'], ['dumbbell', 'bench_flat']], [6, 8, 12], 2, each: true, cost: 3, rank: 15, ref: 'Dumbbell_Step_Ups',
      p: ['quads', 'glutes'], s: ['hamstrings', 'calves', 'outer hips'],
      how: 'Dumbbells at your sides, one whole foot on the box. Stand up through that foot, step down slowly. All reps one side, then switch.'),
  _bw('sissy_squat', 'Sissy squat', 'squat', [[]], const RepRange(6, 10),
      const Ladder([Variant('Supported sissy squats', 'hold a post, small range'), Variant('Supported sissy squats, full range'), Variant('Sissy squats'), Variant('Paused sissy squats', '2 seconds at the bottom')], start: [0, 0, 1]),
      cost: 2, rank: 16, ref: 'Sissy_Squat', p: ['quads'], s: [],
      how: 'Heels up, knees forward, body in a straight line from knees to shoulders. Lean back and bend the knees as far as you can, then return.'),
  // ---------- hinge, more
  _kg('sumo_deadlift', 'Sumo deadlift', 'hinge', [['barbell']], [40, 60, 80], 2.5, cost: 5, rank: 10, ref: 'Sumo_Deadlift',
      p: ['glutes', 'hamstrings', 'quads'], s: ['lower back', 'traps', 'forearms', 'inner thighs'],
      how: 'Wide stance, toes out, hands inside your knees. Chest up, push the knees out and the floor away, stand tall, then lower.'),
  _kg('rack_pull', 'Rack pull', 'hinge', [['barbell', 'squat_rack']], [40, 60, 90], 2.5, cost: 4, rank: 11, ref: 'Rack_Pulls',
      p: ['lower back', 'glutes'], s: ['hamstrings', 'traps', 'forearms'],
      how: 'Bar on the rack pins at knee height. Hinge, grip, and stand tall, squeezing your glutes, then lower to the pins.'),
  _kg('good_morning', 'Good morning', 'hinge', [['barbell', 'squat_rack']], [15, 20, 30], 2.5, cost: 4, rank: 12, ref: 'Good_Morning',
      p: ['hamstrings', 'lower back'], s: ['glutes'],
      how: 'Bar on your upper back, soft knees. Push your hips back and fold forward with a flat back until you feel your hamstrings, then stand.'),
  _kg('kb_deadlift', 'Kettlebell deadlift', 'hinge', [['kettlebell']], [12, 16, 24], 4, cost: 3, rank: 13, ref: 'Kettlebell_Sumo_Deadlift',
      p: ['hamstrings', 'glutes'], s: ['lower back'],
      how: 'Bell between your feet. Hinge down with a flat back, grip it, and stand tall. Lower it the same way.'),
  _kg('cable_pullthrough', 'Cable pull-through', 'hinge', [['cable']], [15, 20, 30], 2.5, cost: 2, rank: 14, ref: 'Pull_Through',
      p: ['glutes', 'hamstrings'], s: ['lower back'],
      how: 'Face away from a low cable with the rope between your legs. Hinge back, then snap your hips forward to stand, squeezing your glutes.'),
  _kg('db_hip_thrust', 'Hip thrust, dumbbell', 'hinge', [['dumbbell', 'bench_flat']], [10, 16, 24], 2, cost: 2, rank: 15, ref: 'Barbell_Hip_Thrust',
      p: ['glutes'], s: ['hamstrings'],
      how: 'Upper back on the bench, dumbbell on your hips. Drive your hips up until your body is level from shoulders to knees, squeeze, and lower.'),
  _kg('sl_rdl_db', 'Single-leg Romanian deadlift, dumbbell', 'hinge', [['dumbbell'], ['kettlebell']], [6, 8, 12], 2, each: true, cost: 2, rank: 16, ref: 'Single_Leg_Romanian_Deadlift',
      p: ['hamstrings', 'glutes'], s: ['lower back', 'outer hips'],
      how: 'One leg, weight in the opposite hand. Hinge forward with a flat back, letting the free leg float back, then stand. Do both sides.'),
  _bw('nordic', 'Nordic curl', 'hinge', [[]], const RepRange(4, 8),
      const Ladder([Variant('Band-assisted nordic curls', 'or hands on a box'), Variant('Nordic negatives', 'lower slowly, push back up'), Variant('Nordic curls, partial'), Variant('Nordic curls'), Variant('Paused nordic curls', '2 seconds at the bottom')], start: [0, 0, 1]),
      cost: 3, rank: 17, ref: 'Natural_Glute_Ham_Raise', p: ['hamstrings'], s: ['glutes', 'calves'],
      how: 'Kneel with your feet anchored under something heavy. Keep your hips straight and lower your body forward as slowly as you can, then pull back up.'),
  _bw('ghd_raise', 'Glute-ham raise', 'hinge', [['ghd']], const RepRange(5, 8),
      const Ladder([Variant('Glute-ham raise negatives'), Variant('Assisted glute-ham raises', 'hands push off the pad'), Variant('Glute-ham raises'), Variant('Paused glute-ham raises', '2 seconds at the bottom')], start: [0, 1, 2], loadGear: _vestOrPack),
      cost: 3, rank: 18, ref: 'Glute_Ham_Raise', p: ['hamstrings'], s: ['glutes', 'lower back'],
      how: 'Feet locked in, knees on the pad. Lower your torso forward until it is horizontal, then curl yourself back up with your hamstrings.'),
  _bw('band_good_morning', 'Band good morning', 'hinge', [['band']], const RepRange(12, 16),
      const Ladder([Variant('Light band good mornings'), Variant('Medium band good mornings'), Variant('Heavy band good mornings'), Variant('Doubled band good mornings')], start: [0, 1, 1]),
      cost: 1, rank: 19, ref: 'Good_Morning', p: ['hamstrings', 'glutes'], s: ['lower back'],
      how: 'Stand on the band with it across the back of your neck. Push your hips back and fold forward with a flat back, then stand.'),
  // ---------- core, more. Holds count seconds instead of reps.
  _bw('plank', 'Plank', 'core', [[]], const RepRange(20, 45),
      const Ladder([Variant('Knee plank'), Variant('Plank'), Variant('Feet-elevated plank'), Variant('Long-lever plank', 'elbows ahead of your shoulders'), Variant('RKC plank', 'squeeze everything, as hard as you can')], start: [0, 1, 2], loadGear: _vestOrPack),
      cost: 1, rank: 8, ref: 'Plank', repLabel: 'seconds', p: ['abs'], s: ['glutes', 'obliques'],
      how: 'Forearms down, body in a straight line from head to heels. Brace as if about to be punched and hold for the seconds shown.'),
  _bw('side_plank', 'Side plank', 'core', [[]], const RepRange(20, 45),
      const Ladder([Variant('Knee side plank'), Variant('Side plank'), Variant('Feet-elevated side plank'), Variant('Side plank with leg raise')], start: [0, 1, 2]),
      cost: 1, rank: 9, ref: 'Side_Bridge', repLabel: 'seconds', p: ['obliques'], s: ['glutes', 'abs', 'outer hips'],
      how: 'On one forearm, feet stacked, hips lifted so your body is a straight line. Hold for the seconds shown, then switch sides.'),
  _bw('hollow_hold', 'Hollow hold', 'core', [[]], const RepRange(15, 40),
      const Ladder([Variant('Tuck hold', 'knees pulled in'), Variant('Bent-knee hollow hold'), Variant('Hollow hold'), Variant('Hollow rocks', 'count the seconds')], start: [0, 1, 2]),
      cost: 1, rank: 10, ref: 'Hollow_Hold', repLabel: 'seconds', p: ['abs'], s: [],
      how: 'Lie on your back, lower back pressed into the floor, shoulders and legs lifted a few inches. Hold for the seconds shown.'),
  _bw('bird_dog', 'Bird dog', 'core', [[]], const RepRange(8, 12),
      const Ladder([Variant('Bird dog, arm only'), Variant('Bird dog, leg only'), Variant('Bird dog'), Variant('Paused bird dog', '3 seconds extended'), Variant('Bird dog with elbow-to-knee')], start: [1, 2, 2]),
      cost: 1, rank: 11, ref: 'Bird_Dog', p: ['abs', 'lower back'], s: ['glutes', 'obliques'],
      how: 'On hands and knees. Reach one arm forward and the opposite leg back without letting your hips tilt, return, and switch.'),
  _bw('reverse_crunch', 'Reverse crunch', 'core', [[]], const RepRange(10, 15),
      const Ladder([Variant('Reverse crunches, knees bent'), Variant('Reverse crunches'), Variant('Slow reverse crunches', '3 seconds down'), Variant('Straight-leg reverse crunches'), Variant('Dragon flag negatives')], start: [0, 1, 1]),
      cost: 1, rank: 12, ref: 'Reverse_Crunch', p: ['abs'], s: [],
      how: 'Lie on your back, hands by your hips, knees up. Curl your hips off the floor toward your chest, then lower slowly.'),
  _bw('russian_twist', 'Russian twist', 'core', [[]], const RepRange(10, 16),
      const Ladder([Variant('Russian twists, feet down'), Variant('Russian twists, feet up'), Variant('Slow Russian twists', 'pause each side'), Variant('Russian twists with a weight held out')], start: [0, 1, 1]),
      cost: 1, rank: 13, ref: 'Russian_Twist', p: ['obliques'], s: ['abs'],
      how: 'Sit leaning back with knees bent. Rotate your torso to tap the floor beside each hip. One tap each side is one rep.'),
  _kg('cable_woodchop', 'Cable woodchop', 'core', [['cable']], [10, 15, 20], 2.5, each: true, cost: 1, rank: 14, ref: 'Cable_Woodchop',
      p: ['obliques'], s: ['abs'],
      how: 'Handle at the high cable, both hands. Pull it down and across your body to the opposite hip, rotating through the hips. Do both sides.'),
  // ---------- carry, more
  _kg('rack_carry', 'Kettlebell rack carry', 'carry', [['kettlebell']], [12, 16, 24], 4, each: true, repLabel: 'steps', cost: 3, rank: 3, ref: 'Farmers_Walk',
      p: ['abs', 'front shoulders'], s: ['forearms', 'glutes', 'quads'],
      how: 'Bells racked at your shoulders, elbows in. Stand tall and walk with short steps. Count the steps.'),
  _kg('overhead_carry', 'Overhead carry', 'carry', [['dumbbell'], ['kettlebell']], [8, 12, 16], 2, each: true, repLabel: 'steps', cost: 3, rank: 4, ref: 'Farmers_Walk',
      p: ['front shoulders', 'obliques'], s: ['traps', 'triceps'],
      how: 'Weight pressed overhead, arm locked, ribs down. Walk slowly and count the steps. Switch arms halfway.'),
  // ---------- arms, more
  _kg('hammer_curl', 'Hammer curl', 'arms', [['dumbbell']], [6, 8, 10], 2, each: true, cost: 1, rank: 10, ref: 'Hammer_Curls',
      p: ['biceps'], s: ['forearms'],
      how: 'Dumbbells at your sides, palms facing in. Curl to your shoulders keeping the thumbs up, then lower slowly.'),
  _kg('incline_curl', 'Incline dumbbell curl', 'arms', [['dumbbell', 'bench_incline']], [4, 6, 8], 2, each: true, cost: 1, rank: 11, ref: 'Incline_Dumbbell_Curl',
      p: ['biceps'], s: ['forearms'],
      how: 'Sit back on an incline bench, arms hanging. Curl both dumbbells without moving your upper arms, then lower slowly.'),
  _kg('preacher_curl', 'Preacher curl', 'arms', [['ez_bar', 'bench_incline'], ['dumbbell', 'bench_incline']], [10, 15, 20], 2.5, cost: 1, rank: 12, ref: 'Preacher_Curl',
      p: ['biceps'], s: ['forearms'],
      how: 'Upper arms flat on the pad. Curl the bar up, pause, and lower until your arms are nearly straight.'),
  _kg('cable_curl', 'Cable curl', 'arms', [['cable']], [10, 15, 20], 2.5, cost: 1, rank: 13, ref: 'Cable_Curl',
      p: ['biceps'], s: ['forearms'],
      how: 'Bar on the low cable, elbows at your sides. Curl to your shoulders and lower slowly.'),
  _kg('reverse_curl', 'Reverse curl', 'arms', [['ez_bar'], ['barbell']], [10, 12, 15], 2.5, cost: 1, rank: 14, ref: 'Reverse_Barbell_Curl',
      p: ['forearms'], s: ['biceps'],
      how: 'Hold the bar with palms facing down. Curl to your shoulders keeping the wrists straight, then lower slowly.'),
  _kg('overhead_tri_ext', 'Overhead triceps extension', 'arms', [['dumbbell'], ['cable']], [8, 12, 16], 2, cost: 1, rank: 15, ref: 'Dumbbell_One-Arm_Triceps_Extension',
      p: ['triceps'], s: [],
      how: 'One dumbbell held overhead with both hands. Lower it behind your head by bending only the elbows, then straighten.'),
  _kg('kickback', 'Triceps kickback', 'arms', [['dumbbell']], [4, 6, 8], 2, each: true, cost: 1, rank: 16, ref: 'Tricep_Dumbbell_Kickback',
      p: ['triceps'], s: [],
      how: 'Hinge forward, upper arm against your side and parallel to the floor. Straighten the arm fully, pause, and bend it back.'),
  _bw('bw_tri_ext', 'Bodyweight triceps extension', 'arms', [[]], const RepRange(6, 10),
      const Ladder([Variant('Triceps extensions on a counter'), Variant('Triceps extensions on a low bar or table'), Variant('Triceps extensions on the floor', 'hands on the floor, knees down'), Variant('Triceps extensions on the floor, knees up')], start: [0, 1, 1]),
      cost: 2, rank: 17, ref: 'Bodyweight_Triceps_Extension', p: ['triceps'], s: ['abs'],
      how: 'Hands on an edge, body straight. Bend only your elbows to lower your head past your hands, then press back up.'),
  _bw('band_tri', 'Band triceps pushdown', 'arms', [['band']], const RepRange(12, 16),
      const Ladder([Variant('Light band pushdowns'), Variant('Medium band pushdowns'), Variant('Heavy band pushdowns'), Variant('Doubled band pushdowns')], start: [0, 1, 1]),
      cost: 1, rank: 18, ref: 'Triceps_Pushdown', p: ['triceps'], s: [],
      how: 'Band anchored high, elbows at your sides. Push down until your arms are straight, then let it rise to chest height.'),
  // ---------- shoulders, more
  _kg('arnold_press', 'Arnold press', 'shoulders', [['dumbbell']], [6, 8, 12], 2, each: true, cost: 3, rank: 6, ref: 'Arnold_Dumbbell_Press',
      p: ['front shoulders'], s: ['side shoulders', 'triceps'],
      how: 'Dumbbells in front of your shoulders, palms facing you. Press up while rotating the palms forward, then reverse on the way down.'),
  _kg('upright_row', 'Upright row', 'shoulders', [['barbell'], ['ez_bar'], ['dumbbell']], [10, 15, 20], 2.5, cost: 2, rank: 7, ref: 'Upright_Barbell_Row',
      p: ['side shoulders'], s: ['traps', 'biceps'],
      how: 'Bar at your thighs, hands shoulder width. Pull it up to your chest with elbows high and wide, then lower.'),
  _kg('front_raise', 'Front raise', 'shoulders', [['dumbbell']], [4, 6, 8], 2, each: true, cost: 1, rank: 8, ref: 'Front_Dumbbell_Raise',
      p: ['front shoulders'], s: [],
      how: 'Dumbbells at your thighs. Raise one or both arms straight in front of you to shoulder height, then lower slowly.'),
  _kg('cable_lat_raise', 'Cable lateral raise', 'shoulders', [['cable']], [2.5, 5, 7.5], 2.5, each: true, cost: 1, rank: 9, ref: 'Cable_Lateral_Raise',
      p: ['side shoulders'], s: ['traps'],
      how: 'Low cable at your side, handle in the far hand. Raise your arm out to shoulder height, then lower slowly. Do both sides.'),
  _kg('shrug', 'Shrug', 'shoulders', [['barbell'], ['dumbbell'], ['trap_bar']], [30, 40, 60], 2.5, cost: 2, rank: 10, ref: 'Barbell_Shrug',
      p: ['traps'], s: ['forearms'],
      how: 'Weight at arm\'s length. Lift your shoulders straight up toward your ears, pause, and lower.'),
  _kg('reverse_pec_deck', 'Reverse pec deck', 'shoulders', [['pec_deck']], [15, 20, 30], 5, cost: 1, rank: 11, ref: 'Reverse_Machine_Flyes',
      p: ['rear shoulders'], s: ['upper back'],
      how: 'Face the machine, handles in front of you. Open your arms wide, squeezing your shoulder blades, then return slowly.'),
  _kg('y_raise', 'Y raise', 'shoulders', [['dumbbell'], ['cable']], [2, 3, 5], 1, each: true, cost: 1, rank: 12, ref: 'Y_Raise',
      p: ['rear shoulders'], s: ['upper back', 'traps'],
      how: 'Hinge forward with a flat back, thumbs up. Raise both arms into a Y shape above your head, then lower.'),
  _bw('band_lateral', 'Band lateral raise', 'shoulders', [['band']], const RepRange(12, 16),
      const Ladder([Variant('Light band lateral raises'), Variant('Medium band lateral raises'), Variant('Heavy band lateral raises'), Variant('Doubled band lateral raises')], start: [0, 1, 1]),
      cost: 1, rank: 13, ref: 'Side_Lateral_Raise', p: ['side shoulders'], s: ['traps'],
      how: 'Stand on the band, handles at your sides. Raise your arms out to shoulder height, then lower slowly.'),
  _bw('pike_hold', 'Wall handstand hold', 'shoulders', [[]], const RepRange(15, 40),
      const Ladder([Variant('Pike hold', 'hips high, hands on the floor'), Variant('Feet-elevated pike hold'), Variant('Wall handstand hold, chest to wall, partial'), Variant('Wall handstand hold')], start: [0, 0, 1]),
      cost: 2, rank: 14, ref: 'Handstand_Hold', repLabel: 'seconds', p: ['front shoulders'], s: ['side shoulders', 'triceps', 'abs'],
      how: 'Hands shoulder width, body as straight as the variant allows. Push the floor away and hold for the seconds shown.'),
  // ---------- legs, more
  _kg('db_calf_raise', 'Calf raise, dumbbells', 'legs', [['dumbbell']], [10, 14, 20], 2, each: true, cost: 1, rank: 5, ref: 'Standing_Dumbbell_Calf_Raise',
      p: ['calves'], s: [],
      how: 'Dumbbells at your sides, balls of your feet on an edge. Rise as high as you can, pause, and lower below the edge.'),
  _kg('leg_press_calf', 'Calf raise on the leg press', 'legs', [['leg_press']], [40, 60, 90], 5, cost: 1, rank: 6, ref: 'Calf_Press_On_The_Leg_Press_Machine',
      p: ['calves'], s: [],
      how: 'Balls of your feet on the bottom edge of the platform, legs nearly straight. Press through your toes, pause, and lower slowly.'),
  _kg('cable_kickback', 'Cable glute kickback', 'legs', [['cable']], [5, 10, 15], 2.5, each: true, cost: 1, rank: 7, ref: 'Glute_Kickback',
      p: ['glutes'], s: ['hamstrings'],
      how: 'Ankle strap on a low cable, hands on the frame. Kick the leg straight back, squeeze, and return. Do both sides.'),
  _kg('hip_abduction', 'Hip abduction machine', 'legs', [['abduction_machine']], [20, 30, 40], 5, cost: 1, rank: 8, ref: 'Thigh_Abductor',
      p: ['outer hips'], s: ['glutes'],
      how: 'Sit with the pads outside your knees. Push your knees apart as far as you can, pause, and return slowly.'),
  _kg('hip_adduction', 'Hip adduction machine', 'legs', [['abduction_machine']], [20, 30, 40], 5, cost: 1, rank: 9, ref: 'Thigh_Adductor',
      p: ['inner thighs'], s: [],
      how: 'Sit with the pads inside your knees. Squeeze your knees together, pause, and open slowly.'),
  _bw('lateral_lunge', 'Lateral lunge', 'legs', [[]], const RepRange(8, 12),
      const Ladder([Variant('Supported lateral lunges', 'hand on a wall'), Variant('Lateral lunges'), Variant('Deep lateral lunges'), Variant('Paused lateral lunges', '2 seconds at the bottom')], start: [0, 1, 2], loadGear: _vestOrPack),
      cost: 2, rank: 10, ref: 'Side_Lunge', p: ['inner thighs', 'glutes'], s: ['quads', 'outer hips'],
      how: 'Step wide to one side and sit into that hip, the other leg straight. Push back to standing. Alternate sides.'),
  _bw('wall_sit', 'Wall sit', 'legs', [[]], const RepRange(20, 45),
      const Ladder([Variant('Wall sit, high', 'thighs above parallel'), Variant('Wall sit'), Variant('Wall sit with heels raised'), Variant('Single-leg wall sit')], start: [0, 1, 1], loadGear: _vestOrPack),
      cost: 1, rank: 11, ref: 'Wall_Sit', repLabel: 'seconds', p: ['quads'], s: ['glutes'],
      how: 'Back flat against a wall, thighs parallel to the floor, knees over ankles. Hold for the seconds shown.'),
  _bw('glute_bridge_march', 'Glute bridge march', 'legs', [[]], const RepRange(8, 12),
      const Ladder([Variant('Glute bridge marches'), Variant('Slow glute bridge marches', '3 seconds each lift'), Variant('Feet-elevated glute bridge marches')], start: [0, 1, 1]),
      cost: 1, rank: 12, ref: 'Glute_Bridge_March', p: ['glutes'], s: ['hamstrings', 'abs'],
      how: 'Hold a glute bridge. Lift one foot off the floor without letting your hips drop, replace it, and switch. One lift each side is one rep.'),
];

final List<Exercise> exercises = List.unmodifiable(_builtIn);
final Map<String, Exercise> exerciseById = {for (final e in _builtIn) e.id: e};

bool available(Exercise ex, Iterable<String> have) {
  final set = have.toSet();
  return ex.needs.any((need) => need.every(set.contains));
}

/// Rotation items are written in patterns. Mains come first, then accessories.
/// Rotation items are written in patterns, in priority order. The goal says how many a workout plans.
class RotationItem {
  const RotationItem({required this.name, required this.focus, required this.patterns});
  final String name;
  final String focus;
  final List<String> patterns;
}

const liftItems = [
  RotationItem(name: 'Workout A', focus: 'legs, chest, back', patterns: ['squat', 'push', 'pull', 'core', 'arms']),
  RotationItem(name: 'Workout B', focus: 'hips, back, chest', patterns: ['hinge', 'pull', 'push', 'carry', 'arms', 'core']),
  RotationItem(name: 'Workout C', focus: 'legs, back, chest', patterns: ['squat', 'pull', 'push', 'shoulders', 'legs', 'core']),
  RotationItem(name: 'Workout D', focus: 'hips, chest, back', patterns: ['hinge', 'push', 'pull', 'arms', 'core', 'legs']),
];

class Move {
  const Move(this.n, this.how);
  final String n;
  final String how;
}

class Routine {
  const Routine(this.id, this.name, this.seconds, this.moves);
  final String id;
  final String name;
  final int seconds;
  final List<Move> moves;
}

const routines = {
  'reset': Routine('reset', 'Full body reset', 40, [
    Move('Cat-cow', 'On hands and knees, arch your back up, then let it sag while lifting your head. Slow and steady.'),
    Move("World's greatest stretch, left", 'Lunge forward with the left foot, drop the right knee, and reach your left elbow toward the floor inside your left foot. Then rotate your left arm up to the ceiling.'),
    Move("World's greatest stretch, right", 'Same on the other side.'),
    Move('Hip flexor stretch, left', 'Kneel on the left knee, right foot forward. Tuck your pelvis and shift forward until you feel the front of the left hip.'),
    Move('Hip flexor stretch, right', 'Same on the other side.'),
    Move('Thoracic rotation, left', 'On hands and knees, left hand behind your head. Rotate your elbow toward the ceiling, then down toward the opposite wrist.'),
    Move('Thoracic rotation, right', 'Same on the other side.'),
    Move('Deep squat hold', 'Sink into the deepest squat you can, heels down, elbows pushing your knees out. Breathe.'),
    Move('Hamstring sweep', 'Step one heel forward, toes up, and hinge forward sweeping your hands toward the floor. Alternate legs.'),
    Move('Shoulder circles', 'Big slow circles with straight arms, forward then backward.'),
  ]),
  'hips': Routine('hips', 'Hips and hamstrings', 45, [
    Move('90/90 hip switch', 'Sit with one leg bent in front and the other bent to the side, both at 90 degrees. Rotate your knees to the other side without using your hands.'),
    Move('Pigeon, left', 'Left shin across in front of you, right leg straight behind. Fold forward over the front leg.'),
    Move('Pigeon, right', 'Same on the other side.'),
    Move('Hamstring sweep', 'Step one heel forward, toes up, and hinge forward sweeping your hands toward the floor. Alternate legs.'),
    Move('Couch stretch, left', 'Left knee on the floor against a wall or couch, left foot up the wall, right foot forward. Stand tall and tuck your pelvis.'),
    Move('Couch stretch, right', 'Same on the other side.'),
    Move('Deep squat hold', 'Sink into the deepest squat you can, heels down, elbows pushing your knees out. Breathe.'),
    Move('Glute bridge hold', 'Lie on your back, knees bent. Lift your hips and hold them up, squeezing your glutes.'),
  ]),
  'upper': Routine('upper', 'Shoulders and upper back', 40, [
    Move('Cat-cow', 'On hands and knees, arch your back up, then let it sag while lifting your head. Slow and steady.'),
    Move('Thread the needle, left', 'On hands and knees, slide your left arm under your body, palm up, letting your left shoulder rest on the floor.'),
    Move('Thread the needle, right', 'Same on the other side.'),
    Move('Wall slides', 'Back against a wall, arms in a goalpost shape touching the wall. Slide them up and down keeping contact.'),
    Move('Doorway chest stretch', 'Forearms on a door frame at shoulder height. Step through until you feel the stretch across your chest.'),
    Move('Thoracic rotation, left', 'On hands and knees, left hand behind your head. Rotate your elbow toward the ceiling, then down toward the opposite wrist.'),
    Move('Thoracic rotation, right', 'Same on the other side.'),
    Move('Shoulder circles', 'Big slow circles with straight arms, forward then backward.'),
  ]),
};

class Cardio {
  const Cardio(this.id, this.name, [this.needs]);
  final String id;
  final String name;
  final String? needs;
}

const cardio = [
  Cardio('walk', 'Brisk walk'),
  Cardio('run', 'Easy run'),
  Cardio('treadmill', 'Treadmill', 'treadmill'),
  Cardio('bike', 'Bike', 'bike'),
  Cardio('rower', 'Rower', 'rower'),
  Cardio('elliptical', 'Elliptical', 'elliptical'),
  Cardio('stairs', 'Stair machine', 'stairs'),
  Cardio('jump_rope', 'Jump rope', 'jump_rope'),
  Cardio('any', 'Anything that raises the pulse'),
];

List<Cardio> cardioFor(Iterable<String> have) {
  final set = have.toSet();
  return cardio.where((c) => c.needs == null || set.contains(c.needs)).toList();
}
