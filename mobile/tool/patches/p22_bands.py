import io, re
def patch(path, pairs):
    t = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert old in t, (path, old[:70])
        t = t.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(t)

# ---------------- library.dart: templates carry rep schemes per difficulty and a maximum of exercises
patch('lib/data/library.dart', [
("""class Goal {
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
};""",
 """/// The preset rep bands: heavy and few, middle, light and many. Any band can be edited into something else.
const heavyReps = RepRange(4, 7);
const middleReps = RepRange(8, 12);
const lightReps = RepRange(13, 18);

/// Rep schemes per difficulty, easy first: one band each, or several to cycle by workout.
typedef Schemes = List<List<RepRange>>;

const strengthSchemes = [[lightReps], [middleReps], [heavyReps]];
const buildSchemes = [[lightReps], [middleReps], [middleReps]];
const enduranceSchemes = [[lightReps], [lightReps], [lightReps]];
const mixedSchemes = [[lightReps], [middleReps], [heavyReps, middleReps]];
const programSchemes = {'strength': strengthSchemes, 'build': buildSchemes, 'endurance': enduranceSchemes, 'mixed': mixedSchemes};
const programLabel = {'strength': 'Strength', 'build': 'Build', 'endurance': 'Endurance', 'mixed': 'Mixed'};

class Goal {
  const Goal(this.id, this.name, this.blurb, {required this.schemes, required this.moveEvery, required this.maxExercises, required this.explain});
  final String id;
  final String name;
  final String blurb;
  final Schemes schemes;
  final int moveEvery;
  /// The most different exercises a workout holds.
  final int maxExercises;
  final List<String> explain;
}

const goals = {
  'strength': Goal('strength', 'Get stronger', 'Heavier over time. Fewer reps per set.',
      schemes: strengthSchemes, moveEvery: 4, maxExercises: 4,
      explain: ['Heavy and few: 4 to 7 reps on the big lifts', 'One movement day in four', 'About 45 minutes a workout']),
  'muscle': Goal('muscle', 'Build muscle', 'Moderate reps, steady volume.',
      schemes: buildSchemes, moveEvery: 4, maxExercises: 4,
      explain: ['Middle reps: 8 to 12', 'One movement day in four', 'About 40 minutes a workout']),
  'fit': Goal('fit', 'Stay fit and mobile', 'Lifting plus plenty of movement.',
      schemes: enduranceSchemes, moveEvery: 2, maxExercises: 4,
      explain: ['Light and many: 13 to 18 reps', 'Every other day is a movement day', 'About 35 minutes a workout']),
  'feel': Goal('feel', 'Feel better', 'Short sessions, lots of movement. The floor is low.',
      schemes: enduranceSchemes, moveEvery: 2, maxExercises: 3,
      explain: ['Three exercises, light and many', 'Every other day is a movement day', 'About 25 minutes a workout']),
};"""),
])
t = io.open('lib/data/library.dart', encoding='utf-8').read()
# RepRange needs equality for isTemplate comparisons; add == and hashCode if missing
m = re.search(r"class RepRange \{.*?\n\}", t, re.S)
assert m, 'RepRange class'
block = m.group(0)
if 'operator ==' not in block:
    new_block = block[:-1] + "  @override\n  bool operator ==(Object o) => o is RepRange && o.lo == lo && o.hi == hi;\n  @override\n  int get hashCode => lo * 1000 + hi;\n}"
    t = t.replace(block, new_block)
io.open('lib/data/library.dart', 'w', encoding='utf-8', newline='\n').write(t)

# ---------------- model.dart
t = io.open('lib/data/model.dart', encoding='utf-8').read()
start = t.index('const expressionLabel = ')
end = t.index('class Profile {')
new = '''const expressionLabel = {Expression.heavy: 'Heavy and few', Expression.middle: 'Middle', Expression.light: 'Light and many'};
const expressionRange = {Expression.heavy: heavyReps, Expression.middle: middleReps, Expression.light: lightReps};
/// An easy day's weight, as a share of the usual. Fixed for now; tunable later (IDEAS.md).
const easyShare = 0.85;
/// An easy day's lifting window, as a share of the normal one: fewer exercises at full sets, the rest is cardio or rest.
const easyWindowShare = 0.67;
/// The lightest share of a max any band lifts; the level steps the max by one plate step over it.
const lightestShare = 0.6;

/// Share of the level (an estimated max) a band lifts: the top of the range is about the max, by Epley.
double pctFor(RepRange r) => (1 / (1 + r.hi / 30)).clamp(lightestShare, 0.9);
/// Rest after a set, by band. Generous on purpose; the timing model replaces it.
int restFor(RepRange r) => r.hi <= 7 ? 180 : r.hi <= 12 ? 90 : 60;
const defaultWorkingSets = 3;
const defaultExtras = 2;
const defaultCardioPct = 15;
const defaultStretchPct = 10;
const maxExercisesMin = 1;
const maxExercisesMax = 10;

String rangeText(RepRange r) => '${r.lo} to ${r.hi}';
List<int> _rr(RepRange r) => [r.lo, r.hi];
RepRange _pr(dynamic v) => RepRange(v[0], v[1]);

/// The user's goal: started from a template, every knob in plain words. See WORKOUT.md.
class GoalConfig {
  GoalConfig({
    required this.template, required this.name, required Schemes schemes, required this.maxExercises, required this.moveEvery,
    this.workingSets = defaultWorkingSets, this.extras = defaultExtras, this.spare = Spare.exercises,
    this.cardioPct = defaultCardioPct, this.stretchPct = defaultStretchPct,
  }) : schemes = [for (final row in schemes) List.of(row)];
  String template;       // the template it started from, or 'custom'
  String name;
  Schemes schemes;       // rep bands per difficulty, easy first; several in a row cycle by workout
  int maxExercises;      // the most different exercises a workout holds (1 to 10)
  int moveEvery;         // a movement day after every N lifting days (0 = none)
  int workingSets;       // sets at the working level (2 to 5); progress is the level rising, never the sets
  int extras;            // exercises trained at the next level on a hard day, 1 to 5; 0 means all
  Spare spare;           // what spare minutes are for
  int cardioPct;         // share of every workout's minutes for cardio at the end
  int stretchPct;        // share for stretching, last

  /// The band an exercise of this difficulty trains in on the nth lifting workout of the rotation.
  RepRange rangeForDifficulty(int difficulty, int liftIndex) {
    final row = schemes[(difficulty - 1).clamp(0, 2)];
    return row.isEmpty ? middleReps : row[liftIndex % row.length];
  }

  /// The named program these schemes match, or null when edited by hand.
  String? get program => programSchemes.entries.where((e) => _sameSchemes(e.value, schemes)).map((e) => e.key).firstOrNull;

  static bool _sameSchemes(Schemes a, Schemes b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].length != b[i].length) return false;
      for (var k = 0; k < a[i].length; k++) { if (a[i][k] != b[i][k]) return false; }
    }
    return true;
  }

  static GoalConfig fromTemplate(Goal g) => GoalConfig(template: g.id, name: g.name, schemes: g.schemes, maxExercises: g.maxExercises, moveEvery: g.moveEvery);

  /// True when every knob still matches the template it came from.
  bool get isTemplate {
    final g = goals[template];
    return g != null && _sameSchemes(g.schemes, schemes) && g.maxExercises == maxExercises && g.moveEvery == moveEvery &&
        workingSets == defaultWorkingSets && extras == defaultExtras && spare == Spare.exercises &&
        cardioPct == defaultCardioPct && stretchPct == defaultStretchPct;
  }

  Map<String, dynamic> toJson() => {
        'template': template, 'name': name, 'schemes': [for (final row in schemes) [for (final r in row) _rr(r)]], 'maxExercises': maxExercises, 'moveEvery': moveEvery,
        'workingSets': workingSets, 'extras': extras, 'spare': _e(spare), 'cardioPct': cardioPct, 'stretchPct': stretchPct,
      };
  static GoalConfig fromJson(Map<String, dynamic> j) {
    final tpl = goals[j['template']];
    Schemes schemes;
    if (j['schemes'] != null) {
      schemes = [for (final row in (j['schemes'] as List)) [for (final r in (row as List)) _pr(r)]];
    } else if (j['reps'] != null) {
      // older data: one preset shifted lighter for easier exercises, or the mixed flag
      final base = _p(Expression.values, j['reps'], Expression.middle);
      schemes = j['mixed'] == true ? mixedSchemes : [for (var d = 1; d <= 3; d++) [expressionRange[Expression.values[(base.index + (3 - d)).clamp(0, 2)]]!]];
    } else {
      schemes = (tpl ?? goals['muscle']!).schemes;
    }
    return GoalConfig(
      template: j['template'] ?? 'custom', name: j['name'] ?? 'Custom', schemes: schemes,
      maxExercises: (j['maxExercises'] ?? j['lifts'] ?? ((j['mains'] ?? 3) + (j['accs'] ?? 1))).clamp(maxExercisesMin, maxExercisesMax), moveEvery: j['moveEvery'] ?? 4,
      workingSets: j['workingSets'] ?? defaultWorkingSets, extras: j['extras'] ?? defaultExtras, spare: _p(Spare.values, j['spare'], Spare.exercises),
      cardioPct: j['cardioPct'] ?? defaultCardioPct, stretchPct: j['stretchPct'] ?? defaultStretchPct,
    );
  }
}

'''
t = t[:start] + new + t[end:]
io.open('lib/data/model.dart', 'w', encoding='utf-8', newline='\n').write(t)

patch('lib/data/model.dart', [
("""  Expression? band;       // reps override for this exercise, set on the card; null follows the goal""",
 """  RepRange? repsOverride; // a rep band for this exercise regardless of the program, set on the card"""),
("""        'lastWorkingAt': _ms(lastWorkingAt), 'band': band == null ? null : _e(band!),
      };""",
 """        'lastWorkingAt': _ms(lastWorkingAt), 'reps': repsOverride == null ? null : _rr(repsOverride!),
      };"""),
("""    ..band = j['band'] == null ? null : _p(Expression.values, j['band'], Expression.middle);
}""",
 """    ..repsOverride = j['reps'] != null ? _pr(j['reps']) : (j['band'] == null ? null : expressionRange[_p(Expression.values, j['band'], Expression.middle)]);
}"""),
("""    required this.target, required this.lo, required this.hi, required this.atCeiling, required this.bestTotal, required this.difficulty,
    required this.expression, this.loadKg, required this.secPerSet, required this.sets, this.warmups = const [], this.edited = false, this.lightened = false,
  });""",
 """    required this.target, required this.lo, required this.hi, required this.atCeiling, required this.bestTotal, required this.difficulty,
    this.loadKg, required this.secPerSet, required this.sets, this.warmups = const [], this.edited = false, this.lightened = false,
  });"""),
("""  int difficulty;     // 1 to 3, in play
  Expression expression; // the reps this set of sets is expressed in; the weight follows
  double? loadKg;     // loaded exercises: the weight today""",
 """  int difficulty;     // 1 to 3, in play
  double? loadKg;     // loaded exercises: the weight today
  RepRange get range => RepRange(lo, hi);"""),
("""        'atCeiling': atCeiling, 'bestTotal': bestTotal, 'difficulty': difficulty, 'expression': _e(expression), 'loadKg': loadKg, 'relative': relative,""",
 """        'atCeiling': atCeiling, 'bestTotal': bestTotal, 'difficulty': difficulty, 'loadKg': loadKg, 'relative': relative,"""),
("""        difficulty: j['difficulty'] ?? foldDifficulty(j['cost'] ?? 3), expression: _p(Expression.values, j['expression'], Expression.middle),
        loadKg: (j['loadKg'] as num?)?.toDouble(), secPerSet: (j['secPerSet'] as num).toDouble(),""",
 """        difficulty: j['difficulty'] ?? foldDifficulty(j['cost'] ?? 3),
        loadKg: (j['loadKg'] as num?)?.toDouble(), secPerSet: (j['secPerSet'] as num).toDouble(),"""),
])

# ---------------- ladder.dart
patch('lib/logic/ladder.dart', [
("""/// The reps an exercise trains in: the card's override if set; else the goal's reps (heavy and middle alternating by
/// workout on the Mixed program), shifted lighter for easier exercises.
Expression expressionFor(AppState s, Exercise ex, {int liftIndex = 0}) {
  final override = s.ex[ex.id]?.band;
  if (override != null) return override;
  final g = s.goal!;
  final base = g.mixed ? (liftIndex.isEven ? Expression.heavy : Expression.middle) : g.reps;
  return Expression.values[(base.index + (3 - ex.difficulty)).clamp(0, 2)];
}""",
 """/// The rep band an exercise trains in today: the card's override if set, else the goal's band for its difficulty on
/// this lifting workout of the rotation (bands in a row cycle by workout), floored by the bodyweight range.
RepRange todayRange(AppState s, Exercise ex, {int liftIndex = 0}) =>
    rangeFor(s, ex, s.ex[ex.id]?.repsOverride ?? s.goal!.rangeForDifficulty(ex.difficulty, liftIndex));"""),
("""/// Rep range for an exercise in an expression, floored by the bodyweight range. Holds keep their own seconds.
RepRange rangeFor(AppState s, Exercise ex, Expression expr) {
  final bw = ex.bwRange;
  if (ex.repLabel == 'seconds' && bw != null) return bw;
  var r = expressionRange[expr]!;""",
 """/// A rep band applied to an exercise: floored by the bodyweight range. Holds keep their own seconds.
RepRange rangeFor(AppState s, Exercise ex, RepRange base) {
  final bw = ex.bwRange;
  if (ex.repLabel == 'seconds' && bw != null) return bw;
  var r = base;"""),
("""/// The level steps the max by enough that even the light expression moves by one plate step.
double levelStepKg(AppState s, Exercise ex) => stepKg(s, ex) / expressionPct[Expression.light]!;""",
 """/// The level steps the max by enough that even the lightest band moves by one plate step.
double levelStepKg(AppState s, Exercise ex) => stepKg(s, ex) / lightestShare;"""),
("""/// Load in kilograms for a loaded exercise at a rung, in an expression (the goal's by default). Never below one step.
double loadFor(AppState s, Exercise ex, ExerciseState st, int rung, [Expression? expr]) {
  final step = stepKg(s, ex);
  return max(step, roundStep(maxFor(s, ex, st, rung) * expressionPct[expr ?? expressionFor(s, ex)]!, step));
}

/// Lowest rung a loaded exercise can hold: the light expression is still one plate step.
int floorRung(AppState s, Exercise ex, ExerciseState st) {
  if (!ex.loaded) return 0;
  final minMax = stepKg(s, ex) / expressionPct[Expression.light]!;""",
 """/// Load in kilograms for a loaded exercise at a rung, for a rep band (today's by default). Never below one step.
double loadFor(AppState s, Exercise ex, ExerciseState st, int rung, [RepRange? range]) {
  final step = stepKg(s, ex);
  return max(step, roundStep(maxFor(s, ex, st, rung) * pctFor(range ?? todayRange(s, ex)), step));
}

/// Lowest rung a loaded exercise can hold: the lightest band is still one plate step.
int floorRung(AppState s, Exercise ex, ExerciseState st) {
  if (!ex.loaded) return 0;
  final minMax = stepKg(s, ex) / lightestShare;"""),
("""String rungLabel(AppState s, Exercise ex, ExerciseState st, int rung, [Expression? expr]) {
  final l = ex.ladder;
  if (l == null) return fmtKg(s, loadFor(s, ex, st, rung, expr), each: ex.each);""",
 """String rungLabel(AppState s, Exercise ex, ExerciseState st, int rung, [RepRange? range]) {
  final l = ex.ladder;
  if (l == null) return fmtKg(s, loadFor(s, ex, st, rung, range), each: ex.each);"""),
("""/// Timing seed for an expression: work (3 s a rep at the top of the range, or the hold seconds) plus rest plus 15 s
/// transition, rounded up to 15 s. Generous on purpose; the timing model replaces it with the user's own seconds.
double seedSeconds(AppState s, Exercise ex, Expression expr) {
  final range = rangeFor(s, ex, expr);
  final work = ex.repLabel == 'seconds' ? range.hi : range.hi * 3;
  final secs = work + expressionRest[expr]! + 15;""",
 """/// Timing seed for a band: work (3 s a rep at the top of the range, or the hold seconds) plus rest plus 15 s
/// transition, rounded up to 15 s. Generous on purpose; the timing model replaces it with the user's own seconds.
double seedSeconds(AppState s, Exercise ex, RepRange range) {
  final work = ex.repLabel == 'seconds' ? range.hi : range.hi * 3;
  final secs = work + restFor(range) + 15;"""),
("""  final seed = seedSeconds(s, ex, expressionFor(s, ex));""",
 """  final seed = seedSeconds(s, ex, todayRange(s, ex));"""),
("""    // the library's starting weights are middle-expression working weights; the level is the max behind them
    var base = ex.startKg![exp] / expressionPct[Expression.middle]!;""",
 """    // the library's starting weights are middle-band working weights; the level is the max behind them
    var base = ex.startKg![exp] / pctFor(middleReps);"""),
("""      final ratio = (maxFor(s, known, knownSt!, knownSt.rung) / (known.startKg![exp] / expressionPct[Expression.middle]!)).clamp(0.5, 2.0);""",
 """      final ratio = (maxFor(s, known, knownSt!, knownSt.rung) / (known.startKg![exp] / pctFor(middleReps))).clamp(0.5, 2.0);"""),
("""/// Convert a load in an expression (the goal's by default) into a rung for a loaded exercise.
int rungForLoad(AppState s, Exercise ex, ExerciseState st, double kg, [Expression? expr]) =>
    ((kg / expressionPct[expr ?? expressionFor(s, ex)]! - st.baseKg!) / levelStepKg(s, ex)).round();""",
 """/// Convert a load for a rep band (today's by default) into a rung for a loaded exercise.
int rungForLoad(AppState s, Exercise ex, ExerciseState st, double kg, [RepRange? range]) =>
    ((kg / pctFor(range ?? todayRange(s, ex)) - st.baseKg!) / levelStepKg(s, ex)).round();"""),
])

# ---------------- rotation.dart
patch('lib/logic/rotation.dart', [
("patterns: it.patterns.take(goal.lifts).toList()));", "patterns: it.patterns.take(goal.maxExercises).toList()));"),
])

# ---------------- builder.dart
patch('lib/logic/builder.dart', [
("""// Builds today's workout: the same exercises at every energy; energy turns three dials on each (expression, sets,
// reserve); the minutes are filled; spare minutes go where the goal says. WORKOUT.md and section 7 of APPLICATION.md.""",
 """// Builds today's workout: the list is built once at normal and fitted to the minutes; energy turns the dials on it
// (hard: the next level; easy: lighter, fewer exercises at full sets). WORKOUT.md and section 7 of APPLICATION.md."""),
("""const _maxAddedExercises = 3;
""", ""),
("""/// Sets by intent. Light is a set fewer, never under two; working and extra are the working sets.
int setsFor(String intent, int workingSets) => intent == intentLight ? max(2, workingSets - 1) : workingSets;""",
 """/// Sets by intent: always the working sets. An easy day keeps full sets and holds fewer exercises instead.
int setsFor(String intent, int workingSets) => workingSets;"""),
("""/// Grow into what is left when spare minutes are for exercises: one more pattern at a time, at the energy's intent.
void _grow(AppState s, List<_Slot> slots, double window, Energy energy, GoalConfig g, Iterable<String> equipment,
    List<String> morePatterns, Map<String, DateTime> paused) {
  var added = 0;
  for (var guard = 0; guard < 20 && added < _maxAddedExercises; guard++) {""",
 """/// Grow into what is left when spare minutes are for exercises: one more pattern at a time, up to the goal's maximum.
void _grow(AppState s, List<_Slot> slots, double window, Energy energy, GoalConfig g, Iterable<String> equipment,
    List<String> morePatterns, Map<String, DateTime> paused) {
  var added = 0;
  for (var guard = 0; guard < 20 && slots.length < g.maxExercises; guard++) {"""),
("""  // 4. the dials
  _turnDials(s, slots, o.energy, g);
  final liftIndex = plan.rotation.take(plan.index).where((r) => r.type == 'lift').length;""",
 """  // 4. the dials. An easy day keeps full sets and fewer exercises: the last light ones go until the lifting fits
  //    a smaller window, so what is left is few exercises done properly rather than many done thinly.
  _turnDials(s, slots, o.energy, g);
  final listedAtNormal = slots.length;
  if (o.energy == Energy.easy) {
    final easyWindow = window * easyWindowShare;
    for (var guard = 0; guard < 20 && slots.length > 1 && _totalSeconds(s, slots) > easyWindow; guard++) {
      final byPriority = slots.toList()..sort((a, b) => b.priority.compareTo(a.priority));
      final victim = byPriority.where((x) => x.intent == intentLight).firstOrNull ?? byPriority.first;
      slots.remove(victim);
    }
  }
  final liftIndex = plan.rotation.take(plan.index).where((r) => r.type == 'lift').length;"""),
("""    final light = sl.intent == intentLight;
    final expr = expressionFor(s, ex, liftIndex: liftIndex);
    final range = rangeFor(s, ex, expr);""",
 """    final light = sl.intent == intentLight;
    final range = todayRange(s, ex, liftIndex: liftIndex);"""),
("""    final usual = ex.loaded ? loadFor(s, ex, st, st.rung, expr) : null;
    var load = ex.loaded ? loadFor(s, ex, st, rung, expr) : null;
    if (light && ex.loaded) load = max(stepKg(s, ex), roundStep(usual! * easyShare, stepKg(s, ex)));
    final label = ex.loaded ? fmtKg(s, load!, each: ex.each) : rungLabel(s, ex, st, rung, expr);""",
 """    final usual = ex.loaded ? loadFor(s, ex, st, st.rung, range) : null;
    var load = ex.loaded ? loadFor(s, ex, st, rung, range) : null;
    if (light && ex.loaded) load = max(stepKg(s, ex), roundStep(usual! * easyShare, stepKg(s, ex)));
    final label = ex.loaded ? fmtKg(s, load!, each: ex.each) : rungLabel(s, ex, st, rung, range);"""),
("""      target: target, lo: range.lo, hi: range.hi, atCeiling: ceilingToday, bestTotal: st.bestTotal, difficulty: difficulty, expression: expr, loadKg: load,""",
 """      target: target, lo: range.lo, hi: range.hi, atCeiling: ceilingToday, bestTotal: st.bestTotal, difficulty: difficulty, loadKg: load,"""),
("""  final weight = out.fold(0, (a, e) => a + e.difficulty);
  final relative = weight == 0 ? 1.0 : out.fold(0.0, (a, e) => a + e.relative * e.difficulty) / weight;""",
 """  final weight = out.fold(0, (a, e) => a + e.difficulty);
  final relative = (weight == 0 ? 1.0 : out.fold(0.0, (a, e) => a + e.relative * e.difficulty) / weight) * (listedAtNormal == 0 ? 1 : out.length / listedAtNormal);"""),
])

# ---------------- today.dart
patch('lib/ui/today.dart', [
("Text(rungLabel(s, ex, st, rung, e.expression), style:", "Text(rungLabel(s, ex, st, rung, e.range), style:"),
("""        '${e.sets.length} × ${e.atCeiling ? 'beat ${e.bestTotal} total' : '${e.lo} to ${e.hi}$unit'}${e.nextLevel ? ' · the next level' : e.intent == intentLight ? (e.exercise.loaded ? ' · ${(easyShare * 100).round()} % of usual' : ' · a version down') : ''}'""",
 """        '${e.sets.length} × ${e.atCeiling ? 'beat ${e.bestTotal} total' : '${e.lo} to ${e.hi}$unit'}${e.nextLevel ? ' · the next level' : e.intent == intentLight ? (e.exercise.loaded ? ' · ${(easyShare * 100).round()} % of usual' : ' · a version down') : ''}'"""),
("""        Energy.easy => weekAway ? 'A week away: easy is the default today. The same exercises, 15 % lighter (a version down for bodyweight), a set fewer, nothing judged. Two of the easier ones at full.' : 'The same exercises, 15 % lighter (a version down for bodyweight), a set fewer, nothing judged. Two of the easier ones at full.',""",
 """        Energy.easy => weekAway ? 'A week away: easy is the default today. Fewer exercises, full sets, 15 % lighter (a version down for bodyweight), nothing judged. Two of the easier ones at full weight.' : 'Fewer exercises, full sets, 15 % lighter (a version down for bodyweight), nothing judged. Two of the easier ones at full weight.',"""),
])

# ---------------- exercise card
patch('lib/ui/exercise_card.dart', [
("    final expr = expressionFor(s, ex);\n    final range = rangeFor(s, ex, expr);\n", "    final range = todayRange(s, ex);\n"),
("""          ChoiceRow<String>(
            label: 'This exercise trains at',
            value: st.band?.name ?? 'goal',
            options: {'goal': 'Goal', for (final e in Expression.values) e.name: expressionLabel[e]!},
            hint: '${range.lo} to ${range.hi} ${ex.repLabel} now. ${st.band == null ? 'Following the goal: hard exercises get the reps it likes, easier ones get more.' : 'Set here for this exercise.'} Same strength either way; the weight follows the reps.',
            onChanged: (v) => store.update((_) => st.band = v == 'goal' ? null : Expression.values.byName(v)),
          ),""",
 """          ChoiceRow<String>(
            label: 'This exercise trains at',
            value: st.repsOverride == null ? 'goal' : (Expression.values.where((e) => expressionRange[e] == st.repsOverride).map((e) => e.name).firstOrNull ?? 'custom'),
            options: {'goal': 'Goal', for (final e in Expression.values) e.name: '${expressionLabel[e]} (${rangeText(expressionRange[e]!)})', if (st.repsOverride != null && !expressionRange.values.contains(st.repsOverride)) 'custom': rangeText(st.repsOverride!)},
            hint: '${range.lo} to ${range.hi} ${ex.repLabel} now. ${st.repsOverride == null ? 'Following the goal: its band for ${difficultyLabel[ex.difficulty]} exercises.' : 'Set here for this exercise.'} Same strength either way; the weight follows the reps.',
            onChanged: (v) => store.update((_) => st.repsOverride = v == 'goal' ? null : v == 'custom' ? st.repsOverride : expressionRange[Expression.values.byName(v)]),
          ),"""),
])

# ---------------- settings summary
patch('lib/ui/settings.dart', [
("              Text('${expressionLabel[s.goal!.reps]!.toLowerCase()} reps · spare minutes: ${spareLabel[s.goal!.spare]!.toLowerCase()}', style: t.bodySmall),\n",
 "              Text('${s.goal!.program == null ? 'custom reps' : programLabel[s.goal!.program]!} · hard lifts ${s.goal!.schemes[2].map(rangeText).join(', then ')} · spare minutes: ${spareLabel[s.goal!.spare]!.toLowerCase()}', style: t.bodySmall),\n"),
("              Text('${s.goal!.lifts} exercises, ${s.goal!.workingSets} working sets · ${s.goal!.moveEvery == 0 ? 'no movement days' : 'a movement day after every ${s.goal!.moveEvery} workouts'}', style: t.bodySmall),\n",
 "              Text('up to ${s.goal!.maxExercises} exercises, ${s.goal!.workingSets} working sets · ${s.goal!.moveEvery == 0 ? 'no movement days' : 'a movement day after every ${s.goal!.moveEvery} workouts'}', style: t.bodySmall),\n"),
])
print('ok')
