import io, re
def patch(path, pairs):
    t = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert old in t, (path, old[:70])
        t = t.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(t)

# ---------------- library.dart
patch('lib/data/library.dart', [
("""class Goal {
  const Goal(this.id, this.name, this.blurb, {required this.bands, required this.moveEvery, required this.lifts, required this.explain});
  final String id;
  final String name;
  final String blurb;
  /// Rep range per cost band: heavy (cost 4 to 5), medium (cost 3), light (cost 1 to 2).
  final List<RepRange> bands;
  final int moveEvery;
  /// Exercises a workout plans.
  final int lifts;
  final List<String> explain;
}

const goals = {
  'strength': Goal('strength', 'Get stronger', 'Heavier over time. Fewer reps per set.',
      bands: [RepRange(4, 6), RepRange(6, 10), RepRange(10, 15)], moveEvery: 4, lifts: 4,
      explain: ['Heavy lifts in sets of 4 to 6 reps', 'One movement day in four', 'About 45 minutes a workout']),
  'muscle': Goal('muscle', 'Build muscle', 'Moderate reps, steady volume.',
      bands: [RepRange(6, 10), RepRange(8, 12), RepRange(12, 15)], moveEvery: 4, lifts: 4,
      explain: ['Heavy lifts in sets of 6 to 10 reps', 'One movement day in four', 'About 40 minutes a workout']),
  'fit': Goal('fit', 'Stay fit and mobile', 'Lifting plus plenty of movement.',
      bands: [RepRange(10, 15), RepRange(12, 20), RepRange(15, 20)], moveEvery: 2, lifts: 4,
      explain: ['Heavy lifts in sets of 10 to 15 reps', 'Every other day is a movement day', 'About 35 minutes a workout']),
  'feel': Goal('feel', 'Feel better', 'Short sessions, lots of movement. The floor is low.',
      bands: [RepRange(10, 15), RepRange(12, 20), RepRange(15, 20)], moveEvery: 2, lifts: 3,
      explain: ['Three exercises, 10 to 15 reps', 'Every other day is a movement day', 'About 25 minutes a workout']),
};""",
 """/// The reps a goal likes: heavy and few, middle, or light and many. A level is strength; this only picks how it is expressed.
enum Expression { heavy, middle, light }

class Goal {
  const Goal(this.id, this.name, this.blurb, {required this.reps, required this.moveEvery, required this.lifts, required this.explain});
  final String id;
  final String name;
  final String blurb;
  final Expression reps;
  final int moveEvery;
  /// Exercises a workout plans.
  final int lifts;
  final List<String> explain;
}

const goals = {
  'strength': Goal('strength', 'Get stronger', 'Heavier over time. Fewer reps per set.',
      reps: Expression.heavy, moveEvery: 4, lifts: 4,
      explain: ['Heavy and few: 4 to 6 reps on the big lifts', 'One movement day in four', 'About 45 minutes a workout']),
  'muscle': Goal('muscle', 'Build muscle', 'Moderate reps, steady volume.',
      reps: Expression.middle, moveEvery: 4, lifts: 4,
      explain: ['Middle reps: 8 to 12', 'One movement day in four', 'About 40 minutes a workout']),
  'fit': Goal('fit', 'Stay fit and mobile', 'Lifting plus plenty of movement.',
      reps: Expression.light, moveEvery: 2, lifts: 4,
      explain: ['Light and many: 12 to 15 reps', 'Every other day is a movement day', 'About 35 minutes a workout']),
  'feel': Goal('feel', 'Feel better', 'Short sessions, lots of movement. The floor is low.',
      reps: Expression.light, moveEvery: 2, lifts: 3,
      explain: ['Three exercises, light and many', 'Every other day is a movement day', 'About 25 minutes a workout']),
};"""),
("""  /// Default cost 1 to 5: how much a hard set takes out of the whole body.
  final int cost;""",
 """  /// Library cost 1 to 5. Shown and used as a difficulty of three: 1 and 2 easy, 3 medium, 4 and 5 hard.
  final int cost;
  int get difficulty => foldDifficulty(cost);"""),
("""  bool get loaded => ladder == null;
}""",
 """  bool get loaded => ladder == null;
}

int foldDifficulty(int cost) => cost >= 4 ? 3 : cost == 3 ? 2 : 1;
const difficultyLabel = {1: 'easy', 2: 'medium', 3: 'hard'};"""),
])

# ---------------- model.dart
t = io.open('lib/data/model.dart', encoding='utf-8').read()
start = t.index('/// Effort budgets at forty minutes')
end = t.index('class Profile {')
new_goal = '''/// What spare minutes are for, once the planned exercises fit.
enum Spare { exercises, cardio, rest }

const spareLabel = {Spare.exercises: 'More exercises', Spare.cardio: 'Cardio', Spare.rest: 'Rest'};
const expressionLabel = {Expression.heavy: 'Heavy and few', Expression.middle: 'Middle', Expression.light: 'Light and many'};
const expressionRange = {Expression.heavy: RepRange(4, 6), Expression.middle: RepRange(8, 12), Expression.light: RepRange(12, 15)};
/// Share of the level (an estimated max) lifted in each expression.
const expressionPct = {Expression.heavy: 0.85, Expression.middle: 0.70, Expression.light: 0.60};
/// Rest after a set, by expression. Generous on purpose; the timing model replaces it.
const expressionRest = {Expression.heavy: 180, Expression.middle: 90, Expression.light: 60};
const defaultWorkingSets = 3;
const defaultExtras = 1;
const defaultCardioPct = 15;
const defaultStretchPct = 10;

/// The user's goal: started from a template, every knob in plain words. See WORKOUT.md.
class GoalConfig {
  GoalConfig({
    required this.template, required this.name, required this.reps, required this.lifts, required this.moveEvery,
    this.workingSets = defaultWorkingSets, this.extras = defaultExtras, this.spare = Spare.exercises,
    this.cardioPct = defaultCardioPct, this.stretchPct = defaultStretchPct,
  });
  String template;       // the template it started from, or 'custom'
  String name;
  Expression reps;       // the reps the goal likes; the weight follows from the level
  int lifts;             // exercises a workout plans (2 to 6)
  int moveEvery;         // a movement day after every N lifting days (0 = none)
  int workingSets;       // sets at the working level (2 to 5); progress is the level rising, never the sets
  int extras;            // exercises given an extra set on a hard day, 1 to 5; 0 means all
  Spare spare;           // what spare minutes are for
  int cardioPct;         // share of every workout's minutes for cardio at the end
  int stretchPct;        // share for stretching, last

  /// The expression an exercise trains in: the goal's reps, shifted lighter for easier exercises.
  Expression expressionFor(int difficulty) => Expression.values[(reps.index + (3 - difficulty)).clamp(0, 2)];

  static GoalConfig fromTemplate(Goal g) => GoalConfig(template: g.id, name: g.name, reps: g.reps, lifts: g.lifts, moveEvery: g.moveEvery);

  /// True when every knob still matches the template it came from.
  bool get isTemplate {
    final g = goals[template];
    return g != null && g.reps == reps && g.lifts == lifts && g.moveEvery == moveEvery &&
        workingSets == defaultWorkingSets && extras == defaultExtras && spare == Spare.exercises &&
        cardioPct == defaultCardioPct && stretchPct == defaultStretchPct;
  }

  Map<String, dynamic> toJson() => {
        'template': template, 'name': name, 'reps': _e(reps), 'lifts': lifts, 'moveEvery': moveEvery,
        'workingSets': workingSets, 'extras': extras, 'spare': _e(spare), 'cardioPct': cardioPct, 'stretchPct': stretchPct,
      };
  static GoalConfig fromJson(Map<String, dynamic> j) {
    final tpl = goals[j['template']];
    return GoalConfig(
      template: j['template'] ?? 'custom', name: j['name'] ?? 'Custom',
      reps: j['reps'] != null ? _p(Expression.values, j['reps'], Expression.middle) : (tpl?.reps ?? Expression.middle),
      lifts: j['lifts'] ?? ((j['mains'] ?? 3) + (j['accs'] ?? 1)), moveEvery: j['moveEvery'] ?? 4,
      workingSets: j['workingSets'] ?? defaultWorkingSets, extras: j['extras'] ?? defaultExtras, spare: _p(Spare.values, j['spare'], Spare.exercises),
      cardioPct: j['cardioPct'] ?? defaultCardioPct, stretchPct: j['stretchPct'] ?? defaultStretchPct,
    );
  }
}

'''
t = t[:start] + new_goal + t[end:]
io.open('lib/data/model.dart', 'w', encoding='utf-8', newline='\n').write(t)

patch('lib/data/model.dart', [
("  double? baseKg;         // loaded exercises: load = baseKg + rung * step",
 "  double? baseKg;         // loaded exercises: the estimated max at rung 0; the level steps it, the expression picks the weight"),
("  int? costOverride;      // 1 to 5, set in the catalog", "  int? costOverride;      // difficulty override 1 to 3, set on the card"),
("    ..costOverride = j['costOverride']\n", "    ..costOverride = j['costOverride'] == null ? null : (j['costOverride'] > 3 ? foldDifficulty(j['costOverride']) : j['costOverride'])\n"),
# SessionExercise
("""    required this.target, required this.lo, required this.hi, required this.atCeiling, required this.bestTotal, required this.cost,
    required this.secPerSet, required this.sets, this.warmups = const [], this.edited = false, this.lightened = false,
  });""",
 """    required this.target, required this.lo, required this.hi, required this.atCeiling, required this.bestTotal, required this.difficulty,
    required this.expression, this.loadKg, required this.secPerSet, required this.sets, this.warmups = const [], this.edited = false, this.lightened = false,
  });"""),
("""  bool atCeiling;
  int bestTotal;
  int cost;
  double secPerSet;""",
 """  bool atCeiling;
  int bestTotal;
  int difficulty;     // 1 to 3, in play
  Expression expression; // the reps this set of sets is expressed in; the weight follows
  double? loadKg;     // loaded exercises: the weight today
  double secPerSet;"""),
("""        'atCeiling': atCeiling, 'bestTotal': bestTotal, 'cost': cost, 'secPerSet': secPerSet, 'sets': sets.map((s) => s.toJson()).toList(),""",
 """        'atCeiling': atCeiling, 'bestTotal': bestTotal, 'difficulty': difficulty, 'expression': _e(expression), 'loadKg': loadKg, 'secPerSet': secPerSet, 'sets': sets.map((s) => s.toJson()).toList(),"""),
("""        lo: j['lo'], hi: j['hi'], atCeiling: j['atCeiling'] ?? false, bestTotal: j['bestTotal'] ?? 0, cost: j['cost'], secPerSet: (j['secPerSet'] as num).toDouble(),""",
 """        lo: j['lo'], hi: j['hi'], atCeiling: j['atCeiling'] ?? false, bestTotal: j['bestTotal'] ?? 0,
        difficulty: j['difficulty'] ?? foldDifficulty(j['cost'] ?? 3), expression: _p(Expression.values, j['expression'], Expression.middle),
        loadKg: (j['loadKg'] as num?)?.toDouble(), secPerSet: (j['secPerSet'] as num).toDouble(),"""),
# Session
("""    this.kind, this.exercises = const [], this.minutes, this.routine, this.cardio, this.estMinutes = 0, this.cardioMinutes = 0, this.stretchMinutes = 0,
    this.points = 0, this.budget = 0, this.circuit = false,
  });""",
 """    this.kind, this.exercises = const [], this.minutes, this.routine, this.cardio, this.estMinutes = 0, this.cardioMinutes = 0, this.stretchMinutes = 0,
    this.spareMinutes = 0, this.circuit = false,
  });"""),
("""  int stretchMinutes;    // the stretching block, last
  double points;         // effort points of the lifting: cost x sets x intent factor, summed
  double budget;         // the effort budget it was built to
  bool circuit;""",
 """  int stretchMinutes;    // the stretching block, last
  int spareMinutes;      // minutes left as rest when spare minutes are for rest
  bool circuit;"""),
("""        'stretchMinutes': stretchMinutes, 'points': points, 'budget': budget,""",
 """        'stretchMinutes': stretchMinutes, 'spareMinutes': spareMinutes,"""),
("""        points: (j['points'] as num?)?.toDouble() ?? 0, budget: (j['budget'] as num?)?.toDouble() ?? 0,""",
 """        spareMinutes: j['spareMinutes'] ?? 0,"""),
# AppState version and migration
("  int version = 3;", "  int version = 4;"),
])

# migration hook in AppState.fromJson: after ex map is parsed
t = io.open('lib/data/model.dart', encoding='utf-8').read()
old = "      ..ex = (j['ex'] as Map? ?? {}).map((k, v) => MapEntry(k as String, ExerciseState.fromJson(v)))\n"
assert old in t
new = old + "      ..version = 4\n"
t = t.replace(old, new)
# find end of the fromJson cascade: the line with '..seenHow' — append migration after the statement
m = re.search(r"(      \.\.seenHow = j\['seenHow'\] \?\? false)(;?)\n", t)
assert m, 'seenHow anchor'
old_line = m.group(0)
new_line = old_line.replace(';', '', 1).rstrip('\n') + ";\n" if m.group(2) == ';' else old_line
t = t.replace(old_line, new_line)
# add migration function call before 'return s;' inside fromJson
idx = t.index('static AppState fromJson')
ret = t.index('    return s;', idx)
t = t[:ret] + "    if ((j['version'] ?? 1) < 4) _migrateMaxes(s, j);\n" + t[ret:]
t = t.rstrip('\n') + '''

/// Before version 4 a loaded exercise's base was its working weight; now it is an estimated max. Lift it by the share the
/// old goal trained at, so the weights the user sees do not change.
void _migrateMaxes(AppState s, Map<String, dynamic> j) {
  final tpl = (j['goal'] as Map?)?['template'];
  final pct = tpl == 'strength' ? 0.85 : (tpl == 'fit' || tpl == 'feel') ? 0.60 : 0.70;
  for (final st in s.ex.values) {
    if (st.baseKg != null) st.baseKg = st.baseKg! / pct;
  }
}
'''
io.open('lib/data/model.dart', 'w', encoding='utf-8', newline='\n').write(t)

# ---------------- ladder.dart
patch('lib/logic/ladder.dart', [
("""/// Rep range for an exercise: the goal's band for its cost, floored by the bodyweight range.
RepRange rangeFor(AppState s, Exercise ex, int cost) {
  var r = s.goal!.bandFor(cost);
  final bw = ex.bwRange;
  if (bw != null) r = RepRange(max(r.lo, bw.lo), max(r.hi, bw.hi));
  if (r.hi <= r.lo) r = RepRange(r.lo, r.lo + 2);
  return r;
}""",
 """/// The expression an exercise trains in by default: the goal's reps, shifted lighter for easier exercises.
Expression expressionFor(AppState s, Exercise ex) => s.goal!.expressionFor(ex.difficulty);

/// One expression lighter: more reps, less weight. The level does not move.
Expression lighter(Expression e) => Expression.values[min(e.index + 1, Expression.values.length - 1)];

/// Rep range for an exercise in an expression, floored by the bodyweight range. Holds keep their own seconds.
RepRange rangeFor(AppState s, Exercise ex, Expression expr) {
  final bw = ex.bwRange;
  if (ex.repLabel == 'seconds' && bw != null) return bw;
  var r = expressionRange[expr]!;
  if (bw != null) r = RepRange(max(r.lo, bw.lo), max(r.hi, bw.hi));
  if (r.hi <= r.lo) r = RepRange(r.lo, r.lo + 2);
  return r;
}

/// The level steps the max by enough that even the light expression moves by one plate step.
double levelStepKg(AppState s, Exercise ex) => stepKg(s, ex) / expressionPct[Expression.light]!;

/// The estimated max at a rung.
double maxFor(AppState s, Exercise ex, ExerciseState st, int rung) => st.baseKg! + rung * levelStepKg(s, ex);"""),
("""/// Load in kilograms for a loaded exercise at a rung. Never below one step.
double loadFor(AppState s, Exercise ex, ExerciseState st, int rung) {
  final step = stepKg(s, ex);
  return max(step, roundStep(st.baseKg! + rung * step, step));
}

/// Lowest rung a loaded exercise can hold (one step of load).
int floorRung(AppState s, Exercise ex, ExerciseState st) {
  if (!ex.loaded) return 0;
  final step = stepKg(s, ex);
  return (-(st.baseKg! - step) / step).ceil();
}""",
 """/// Load in kilograms for a loaded exercise at a rung, in an expression (the goal's by default). Never below one step.
double loadFor(AppState s, Exercise ex, ExerciseState st, int rung, [Expression? expr]) {
  final step = stepKg(s, ex);
  return max(step, roundStep(maxFor(s, ex, st, rung) * expressionPct[expr ?? expressionFor(s, ex)]!, step));
}

/// Lowest rung a loaded exercise can hold: the light expression is still one plate step.
int floorRung(AppState s, Exercise ex, ExerciseState st) {
  if (!ex.loaded) return 0;
  final minMax = stepKg(s, ex) / expressionPct[Expression.light]!;
  return (-(st.baseKg! - minMax) / levelStepKg(s, ex)).ceil();
}"""),
("""String rungLabel(AppState s, Exercise ex, ExerciseState st, int rung) {
  final l = ex.ladder;
  if (l == null) return fmtKg(s, loadFor(s, ex, st, rung), each: ex.each);""",
 """String rungLabel(AppState s, Exercise ex, ExerciseState st, int rung, [Expression? expr]) {
  final l = ex.ladder;
  if (l == null) return fmtKg(s, loadFor(s, ex, st, rung, expr), each: ex.each);"""),
("""/// Rest after a set, by cost. Generous on purpose; the timing model replaces it with the user's own seconds.
const restSeconds = {1: 60, 2: 75, 3: 90, 4: 150, 5: 180};

/// Timing seed: work (3 s a rep, or the hold seconds) plus rest by cost plus 15 s transition, rounded up to 15 s.
double seedSeconds(int cost, int reps, {bool hold = false}) {
  final work = hold ? reps : reps * 3;
  final secs = work + restSeconds[cost.clamp(1, 5)]! + 15;
  return ((secs / 15).ceil() * 15).toDouble();
}

/// Cost in play: default or override, moved by the user's own history, clamped 1 to 5.
int costInPlay(Exercise ex, ExerciseState? st) {
  final base = st?.costOverride ?? ex.cost;
  return (base + (st?.costUp ?? 0) - (st?.costDown ?? 0)).clamp(1, 5);
}""",
 """/// Timing seed for an expression: work (3 s a rep at the top of the range, or the hold seconds) plus rest plus 15 s
/// transition, rounded up to 15 s. Generous on purpose; the timing model replaces it with the user's own seconds.
double seedSeconds(AppState s, Exercise ex, Expression expr) {
  final range = rangeFor(s, ex, expr);
  final work = ex.repLabel == 'seconds' ? range.hi : range.hi * 3;
  final secs = work + expressionRest[expr]! + 15;
  return ((secs / 15).ceil() * 15).toDouble();
}

/// Difficulty in play: default or override, moved by the user's own history, clamped 1 to 3.
int difficultyInPlay(Exercise ex, ExerciseState? st) {
  final base = st?.costOverride ?? ex.difficulty;
  return (base + (st?.costUp ?? 0) - (st?.costDown ?? 0)).clamp(1, 3);
}"""),
("""  final exp = experienceIndex(s.profile!.experience);
  final seed = seedSeconds(ex.cost, rangeFor(s, ex, ex.cost).hi, hold: ex.repLabel == 'seconds');
  late final ExerciseState st;
  if (ex.loaded) {
    var base = ex.startKg![exp];""",
 """  final exp = experienceIndex(s.profile!.experience);
  final seed = seedSeconds(s, ex, expressionFor(s, ex));
  late final ExerciseState st;
  if (ex.loaded) {
    // the library's starting weights are middle-expression working weights; the level is the max behind them
    var base = ex.startKg![exp] / expressionPct[Expression.middle]!;"""),
("""    if (known != null) {
      final ratio = (loadFor(s, known, knownSt!, knownSt.rung) / known.startKg![exp]).clamp(0.5, 2.0);
      base = base * ratio;
    }""",
 """    if (known != null) {
      final ratio = (maxFor(s, known, knownSt!, knownSt.rung) / (known.startKg![exp] / expressionPct[Expression.middle]!)).clamp(0.5, 2.0);
      base = base * ratio;
    }"""),
("""/// Convert a load the user typed into a rung for a loaded exercise.
int rungForLoad(AppState s, Exercise ex, ExerciseState st, double kg) => ((kg - st.baseKg!) / stepKg(s, ex)).round();""",
 """/// Convert a load in an expression (the goal's by default) into a rung for a loaded exercise.
int rungForLoad(AppState s, Exercise ex, ExerciseState st, double kg, [Expression? expr]) =>
    ((kg / expressionPct[expr ?? expressionFor(s, ex)]! - st.baseKg!) / levelStepKg(s, ex)).round();"""),
])

# ---------------- index.dart: difficulty index
patch('lib/data/index.dart', [
("enum ExerciseIndex { muscle, region, pattern, equipment, progression }", "enum ExerciseIndex { muscle, region, pattern, equipment, progression, difficulty }"),
("  ExerciseIndex.progression: 'Progression type',\n};", "  ExerciseIndex.progression: 'Progression type',\n  ExerciseIndex.difficulty: 'Difficulty',\n};"),
("  ExerciseIndex.progression: 'By weight or by version.',\n};", "  ExerciseIndex.progression: 'By weight or by version.',\n  ExerciseIndex.difficulty: 'Easy, medium, hard: how much one hard set takes out of you.',\n};"),
("      ExerciseIndex.progression => const ['By weight', 'By version'],\n    };", "      ExerciseIndex.progression => const ['By weight', 'By version'],\n      ExerciseIndex.difficulty => const ['Easy', 'Medium', 'Hard'],\n    };"),
("      ExerciseIndex.progression => e.loaded ? 'By weight' : 'By version',\n    };", "      ExerciseIndex.progression => e.loaded ? 'By weight' : 'By version',\n      ExerciseIndex.difficulty => const ['Easy', 'Medium', 'Hard'][e.difficulty - 1],\n    };"),
])

# ---------------- theme.dart: three dots
patch('lib/ui/theme.dart', [
("""class CostDots extends StatelessWidget {
  const CostDots(this.cost, {super.key, this.size = 6});
  final int cost;""",
 """/// Difficulty as three dots: easy, medium, hard.
class CostDots extends StatelessWidget {
  const CostDots(this.cost, {super.key, this.size = 6});
  final int cost;"""),
("      for (var i = 1; i <= 5; i++)\n        Container(width: size, height: size, margin: EdgeInsets.only(right: size * 0.5),",
 "      for (var i = 1; i <= 3; i++)\n        Container(width: size, height: size, margin: EdgeInsets.only(right: size * 0.5),"),
])
print('ok')
