import io
def patch(path, pairs):
    t = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert old in t, (path, old[:70])
        t = t.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(t)

# ---- library.dart: goal templates by cost band, rotation items as one ordered pattern list
patch('lib/data/library.dart', [
("""class Goal {
  const Goal(this.id, this.name, this.blurb, {required this.main, required this.acc, required this.moveEvery, required this.mains, required this.accs, required this.explain});
  final String id;
  final String name;
  final String blurb;
  final RepRange main;
  final RepRange acc;
  final int moveEvery;
  final int mains;
  final int accs;
  final List<String> explain;
}

const goals = {
  'strength': Goal('strength', 'Get stronger', 'Heavier over time. Fewer reps per set.',
      main: RepRange(4, 6), acc: RepRange(6, 10), moveEvery: 4, mains: 3, accs: 1,
      explain: ['Main lifts in sets of 4 to 6 reps', 'One movement day in four', 'About 45 minutes a session']),
  'muscle': Goal('muscle', 'Build muscle', 'Moderate reps, steady volume.',
      main: RepRange(8, 12), acc: RepRange(10, 15), moveEvery: 4, mains: 3, accs: 1,
      explain: ['Main lifts in sets of 8 to 12 reps', 'One movement day in four', 'About 40 minutes a session']),
  'fit': Goal('fit', 'Stay fit and mobile', 'Lifting plus plenty of movement.',
      main: RepRange(10, 15), acc: RepRange(12, 20), moveEvery: 2, mains: 3, accs: 1,
      explain: ['Main lifts in sets of 10 to 15 reps', 'Every other day is a movement day', 'About 35 minutes a session']),
  'feel': Goal('feel', 'Feel better', 'Short sessions, lots of movement. The floor is low.',
      main: RepRange(10, 15), acc: RepRange(12, 20), moveEvery: 2, mains: 2, accs: 1,
      explain: ['Two main lifts, 10 to 15 reps', 'Every other day is a movement day', 'About 25 minutes a session']),
};""",
 """class Goal {
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
};"""),
("""class RotationItem {
  const RotationItem({required this.name, required this.focus, required this.mains, required this.accs});
  final String name;
  final String focus;
  final List<String> mains;
  final List<String> accs;
}

const liftItems = [
  RotationItem(name: 'Workout A', focus: 'legs, chest, back', mains: ['squat', 'push', 'pull'], accs: ['core']),
  RotationItem(name: 'Workout B', focus: 'hips, back, chest', mains: ['hinge', 'pull', 'push'], accs: ['carry', 'arms']),
  RotationItem(name: 'Workout C', focus: 'legs, back, chest', mains: ['squat', 'pull', 'push'], accs: ['shoulders', 'legs']),
  RotationItem(name: 'Workout D', focus: 'hips, chest, back', mains: ['hinge', 'push', 'pull'], accs: ['arms', 'core']),""",
 """/// Rotation items are written in patterns, in priority order. The goal says how many a workout plans.
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
  RotationItem(name: 'Workout D', focus: 'hips, chest, back', patterns: ['hinge', 'push', 'pull', 'arms', 'core', 'legs']),"""),
])

# ---- model.dart
patch('lib/data/model.dart', [
("""/// The user's goal: started from a template, every knob editable.
class GoalConfig {
  GoalConfig({required this.template, required this.name, required this.main, required this.acc, required this.mains, required this.accs, required this.moveEvery});
  String template;   // the template it started from, or 'custom'
  String name;
  RepRange main;     // rep range for main lifts
  RepRange acc;      // rep range for accessories
  int mains;         // main lifts per session (1 to 4)
  int accs;          // accessories per session (0 to 3)
  int moveEvery;     // a movement day after every N lifting days (0 = none)

  static GoalConfig fromTemplate(Goal g) =>
      GoalConfig(template: g.id, name: g.name, main: g.main, acc: g.acc, mains: g.mains, accs: g.accs, moveEvery: g.moveEvery);

  /// True when every knob still matches the template it came from.
  bool get isTemplate {
    final g = goals[template];
    return g != null && g.main.lo == main.lo && g.main.hi == main.hi && g.acc.lo == acc.lo && g.acc.hi == acc.hi && g.mains == mains && g.accs == accs && g.moveEvery == moveEvery;
  }

  Map<String, dynamic> toJson() => {
        'template': template, 'name': name, 'main': [main.lo, main.hi], 'acc': [acc.lo, acc.hi], 'mains': mains, 'accs': accs, 'moveEvery': moveEvery,
      };
  static GoalConfig fromJson(Map<String, dynamic> j) => GoalConfig(
        template: j['template'] ?? 'custom', name: j['name'] ?? 'Custom', main: RepRange(j['main'][0], j['main'][1]), acc: RepRange(j['acc'][0], j['acc'][1]),
        mains: j['mains'] ?? 3, accs: j['accs'] ?? 1, moveEvery: j['moveEvery'] ?? 4,
      );
}""",
 """/// Effort budgets at forty minutes, easy / normal / hard, and the bands they may be tuned within.
const defaultBudgets = [20, 40, 60];
const budgetMin = [10, 30, 45];
const budgetMax = [35, 55, 80];
const defaultWorkingSets = 3;
const defaultExtras = 1;
const defaultCardioPct = 15;
const defaultStretchPct = 10;

/// The user's goal: started from a template, every knob editable. See WORKOUT.md.
class GoalConfig {
  GoalConfig({
    required this.template, required this.name, required this.bands, required this.lifts, required this.moveEvery,
    this.workingSets = defaultWorkingSets, this.extras = defaultExtras, List<int>? budgets, this.cardioPct = defaultCardioPct, this.stretchPct = defaultStretchPct,
  }) : budgets = budgets ?? List.of(defaultBudgets);
  String template;       // the template it started from, or 'custom'
  String name;
  List<RepRange> bands;  // rep range per cost band: heavy (4 to 5), medium (3), light (1 to 2)
  int lifts;             // exercises a workout plans (2 to 6)
  int moveEvery;         // a movement day after every N lifting days (0 = none)
  int workingSets;       // sets at the working level (2 to 5); progress is the level rising, never the sets
  int extras;            // exercises given an extra set on a hard day, 1 to 5; 0 means all
  List<int> budgets;     // effort points at 40 minutes: easy, normal, hard
  int cardioPct;         // share of every workout's minutes for cardio at the end
  int stretchPct;        // share for stretching, last

  RepRange bandFor(int cost) => cost >= 4 ? bands[0] : cost == 3 ? bands[1] : bands[2];
  int budgetFor(Energy e) => budgets[e.index];

  static GoalConfig fromTemplate(Goal g) =>
      GoalConfig(template: g.id, name: g.name, bands: List.of(g.bands), lifts: g.lifts, moveEvery: g.moveEvery);

  /// True when every knob still matches the template it came from.
  bool get isTemplate {
    final g = goals[template];
    if (g == null || g.lifts != lifts || g.moveEvery != moveEvery) return false;
    for (var i = 0; i < 3; i++) { if (g.bands[i].lo != bands[i].lo || g.bands[i].hi != bands[i].hi) return false; }
    return workingSets == defaultWorkingSets && extras == defaultExtras && cardioPct == defaultCardioPct && stretchPct == defaultStretchPct &&
        budgets[0] == defaultBudgets[0] && budgets[1] == defaultBudgets[1] && budgets[2] == defaultBudgets[2];
  }

  Map<String, dynamic> toJson() => {
        'template': template, 'name': name, 'bands': bands.map((b) => [b.lo, b.hi]).toList(), 'lifts': lifts, 'moveEvery': moveEvery,
        'workingSets': workingSets, 'extras': extras, 'budgets': budgets, 'cardioPct': cardioPct, 'stretchPct': stretchPct,
      };
  static GoalConfig fromJson(Map<String, dynamic> j) {
    final tpl = goals[j['template']];
    List<RepRange> bands;
    if (j['bands'] != null) {
      bands = (j['bands'] as List).map((b) => RepRange(b[0], b[1])).toList();
    } else if (j['main'] != null && j['acc'] != null) {
      // older data: a main range and an accessory range
      final main = RepRange(j['main'][0], j['main'][1]), acc = RepRange(j['acc'][0], j['acc'][1]);
      bands = tpl?.bands.toList() ?? [main, RepRange(main.lo, acc.hi), acc];
    } else {
      bands = (tpl ?? goals['muscle']!).bands.toList();
    }
    return GoalConfig(
      template: j['template'] ?? 'custom', name: j['name'] ?? 'Custom', bands: bands,
      lifts: j['lifts'] ?? ((j['mains'] ?? 3) + (j['accs'] ?? 1)), moveEvery: j['moveEvery'] ?? 4,
      workingSets: j['workingSets'] ?? defaultWorkingSets, extras: j['extras'] ?? defaultExtras,
      budgets: j['budgets'] == null ? null : List<int>.from(j['budgets']), cardioPct: j['cardioPct'] ?? defaultCardioPct, stretchPct: j['stretchPct'] ?? defaultStretchPct,
    );
  }
}"""),
("""  int bestTotal = 0;      // best total reps at the current rung
  double secPerSet;       // timing model: seconds per set including the rest after it
""",
 """  int bestTotal = 0;      // best total reps at the current rung
  DateTime? lastWorkingAt; // last time the exercise was asked for its working level; the working turns go to the longest-waiting
  double secPerSet;       // timing model: seconds per set including the rest after it
"""),
("""        'costOverride': costOverride, 'costUp': costUp, 'costDown': costDown, 'ceilingRun': ceilingRun, 'bestTotal': bestTotal, 'secPerSet': secPerSet,
      };""",
 """        'costOverride': costOverride, 'costUp': costUp, 'costDown': costDown, 'ceilingRun': ceilingRun, 'bestTotal': bestTotal, 'secPerSet': secPerSet,
        'lastWorkingAt': _ms(lastWorkingAt),
      };"""),
("""    ..bestTotal = j['bestTotal'] ?? 0;
}""",
 """    ..bestTotal = j['bestTotal'] ?? 0
    ..lastWorkingAt = _d(j['lastWorkingAt']);
}"""),
# SessionExercise: intent instead of role
("""    required this.slot, required this.exId, required this.pattern, required this.role, required this.rung, required this.rungLabel,
    required this.target, required this.lo, required this.hi, required this.atCeiling, required this.bestTotal, required this.cost,
    required this.secPerSet, required this.sets, this.warmups = const [], this.edited = false, this.lightened = false,
  });
  String slot;
  String exId;
  String pattern;
  String role; // main | acc""",
 """    required this.slot, required this.exId, required this.pattern, required this.intent, required this.workingSets, required this.rung, required this.rungLabel,
    required this.target, required this.lo, required this.hi, required this.atCeiling, required this.bestTotal, required this.cost,
    required this.secPerSet, required this.sets, this.warmups = const [], this.edited = false, this.lightened = false,
  });
  String slot;
  String exId;
  String pattern;
  String intent;      // light | working | extra: what today asks of this exercise. Never a judgement.
  int workingSets;    // the working set count at the time, so judging knows what the working level was"""),
("""  Map<String, dynamic> toJson() => {
        'slot': slot, 'exId': exId, 'pattern': pattern, 'role': role, 'rung': rung, 'rungLabel': rungLabel, 'target': target, 'lo': lo, 'hi': hi,""",
 """  /// True when today asked for the working level: the user's level and at least the working sets.
  bool get atWorkingLevel => intent != 'light' && !lightened && sets.length >= workingSets;

  Map<String, dynamic> toJson() => {
        'slot': slot, 'exId': exId, 'pattern': pattern, 'intent': intent, 'workingSets': workingSets, 'rung': rung, 'rungLabel': rungLabel, 'target': target, 'lo': lo, 'hi': hi,"""),
("""        slot: j['slot'], exId: j['exId'], pattern: j['pattern'], role: j['role'], rung: j['rung'], rungLabel: j['rungLabel'], target: j['target'],""",
 """        slot: j['slot'], exId: j['exId'], pattern: j['pattern'], intent: j['intent'] ?? 'working', workingSets: j['workingSets'] ?? (j['sets'] as List).length,
        rung: j['rung'], rungLabel: j['rungLabel'], target: j['target'],"""),
# Session: cardio and stretching blocks, points and budget
("""    this.kind, this.exercises = const [], this.minutes, this.routine, this.cardio, this.estMinutes = 0, this.bonusCardioMinutes, this.circuit = false,
  });""",
 """    this.kind, this.exercises = const [], this.minutes, this.routine, this.cardio, this.estMinutes = 0, this.cardioMinutes = 0, this.stretchMinutes = 0,
    this.points = 0, this.budget = 0, this.circuit = false,
  });"""),
("""  int estMinutes;
  int? bonusCardioMinutes;
  bool circuit;""",
 """  int estMinutes;
  int cardioMinutes;     // the cardio block at the end: the share, plus any slack the lifting left
  int stretchMinutes;    // the stretching block, last
  double points;         // effort points of the lifting: cost x sets x intent factor, summed
  double budget;         // the effort budget it was built to
  bool circuit;"""),
("""        'minutes': minutes, 'routine': routine, 'cardio': cardio, 'effort': effort, 'estMinutes': estMinutes, 'bonusCardioMinutes': bonusCardioMinutes,""",
 """        'minutes': minutes, 'routine': routine, 'cardio': cardio, 'effort': effort, 'estMinutes': estMinutes, 'cardioMinutes': cardioMinutes,
        'stretchMinutes': stretchMinutes, 'points': points, 'budget': budget,"""),
# RotationEntry: one ordered pattern list
("""  RotationEntry({required this.type, required this.name, this.focus = '', this.mains = const [], this.accs = const [], this.kind, this.routine});
  String type;   // lift | move
  String name;
  String focus;
  List<String> mains;
  List<String> accs;
  String? kind;  // cardio | mobility
  String? routine;
  Map<String, dynamic> toJson() => {'type': type, 'name': name, 'focus': focus, 'mains': mains, 'accs': accs, 'kind': kind, 'routine': routine};
  static RotationEntry fromJson(Map<String, dynamic> j) => RotationEntry(
      type: j['type'], name: j['name'], focus: j['focus'] ?? '', mains: List<String>.from(j['mains'] ?? []), accs: List<String>.from(j['accs'] ?? []),
      kind: j['kind'], routine: j['routine']);""",
 """  RotationEntry({required this.type, required this.name, this.focus = '', this.patterns = const [], this.kind, this.routine});
  String type;   // lift | move
  String name;
  String focus;
  List<String> patterns;  // in priority order: the first get the work first and lose it last
  String? kind;  // cardio | mobility
  String? routine;
  Map<String, dynamic> toJson() => {'type': type, 'name': name, 'focus': focus, 'patterns': patterns, 'kind': kind, 'routine': routine};
  static RotationEntry fromJson(Map<String, dynamic> j) => RotationEntry(
      type: j['type'], name: j['name'], focus: j['focus'] ?? '',
      patterns: List<String>.from(j['patterns'] ?? [...?j['mains'], ...?j['accs']]),
      kind: j['kind'], routine: j['routine']);"""),
])

# Session.fromJson: the rest of the constructor args
t = io.open('lib/data/model.dart', encoding='utf-8').read()
old = "estMinutes: j['estMinutes'] ?? 0, bonusCardioMinutes: j['bonusCardioMinutes'],"
assert old in t, 'session fromJson'
t = t.replace(old, "estMinutes: j['estMinutes'] ?? 0, cardioMinutes: j['cardioMinutes'] ?? j['bonusCardioMinutes'] ?? 0, stretchMinutes: j['stretchMinutes'] ?? 0,\n        points: (j['points'] as num?)?.toDouble() ?? 0, budget: (j['budget'] as num?)?.toDouble() ?? 0,")
io.open('lib/data/model.dart', 'w', encoding='utf-8', newline='\n').write(t)

# ---- ladder.dart: range by cost band, timing seeds from reps and rest
patch('lib/logic/ladder.dart', [
("""/// Rep range for an exercise in a role: from the goal (or the settings override), floored by the bodyweight range.
RepRange rangeFor(AppState s, Exercise ex, String role) {
  final g = s.goal!;
  var r = role == 'main' ? g.main : g.acc;
  final bw = ex.bwRange;""",
 """/// Rep range for an exercise: the goal's band for its cost, floored by the bodyweight range.
RepRange rangeFor(AppState s, Exercise ex, int cost) {
  var r = s.goal!.bandFor(cost);
  final bw = ex.bwRange;"""),
("""/// Timing seed by cost: roughly four minutes for a cost-5 lift, ninety seconds for a cost-1 move.
double seedSeconds(int cost) => const {1: 90.0, 2: 110.0, 3: 150.0, 4: 200.0, 5: 240.0}[cost.clamp(1, 5)]!;""",
 """/// Rest after a set, by cost. Generous on purpose; the timing model replaces it with the user's own seconds.
const restSeconds = {1: 60, 2: 75, 3: 90, 4: 150, 5: 180};

/// Timing seed: work (3 s a rep, or the hold seconds) plus rest by cost plus 15 s transition, rounded up to 15 s.
double seedSeconds(int cost, int reps, {bool hold = false}) {
  final work = hold ? reps : reps * 3;
  final secs = work + restSeconds[cost.clamp(1, 5)]! + 15;
  return ((secs / 15).ceil() * 15).toDouble();
}"""),
("""    st = ExerciseState(rung: 0, startRung: 0, baseKg: roundStep(base, stepKg(s, ex)), secPerSet: seedSeconds(ex.cost));
  } else {
    final start = ex.ladder!.start[exp].clamp(0, ex.ladder!.variants.length - 1);
    st = ExerciseState(rung: start, startRung: start, secPerSet: seedSeconds(ex.cost));
  }""",
 """    st = ExerciseState(rung: 0, startRung: 0, baseKg: roundStep(base, stepKg(s, ex)), secPerSet: seed);
  } else {
    final start = ex.ladder!.start[exp].clamp(0, ex.ladder!.variants.length - 1);
    st = ExerciseState(rung: start, startRung: start, secPerSet: seed);
  }"""),
("""  final exp = experienceIndex(s.profile!.experience);
  late final ExerciseState st;
  if (ex.loaded) {""",
 """  final exp = experienceIndex(s.profile!.experience);
  final seed = seedSeconds(ex.cost, rangeFor(s, ex, ex.cost).hi, hold: ex.repLabel == 'seconds');
  late final ExerciseState st;
  if (ex.loaded) {"""),
("""/// Warm-up suggestion for a loaded main lift: two lighter sets, never logged.""",
 """/// Warm-up suggestion for a loaded exercise at cost 4 or 5: two lighter sets, never logged."""),
])

# ---- rotation.dart
patch('lib/logic/rotation.dart', [
("""  final lifts = liftItems.take(count).map((it) => RotationEntry(
      type: 'lift', name: it.name, focus: it.focus, mains: it.mains.take(goal.mains).toList(), accs: it.accs.take(goal.accs).toList()));""",
 """  final lifts = liftItems.take(count).map((it) => RotationEntry(
      type: 'lift', name: it.name, focus: it.focus, patterns: it.patterns.take(goal.lifts).toList()));"""),
])
print('ok')
