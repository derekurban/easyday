// The ladder: what a rung means for each exercise, where it starts, where it tops out, and how it is shown.
import 'dart:math';

import '../data/index.dart';
import '../data/library.dart';
import '../data/model.dart';

const lbPerKg = 2.20462;

double roundStep(double x, double step) => (x / step).round() * step;

/// The rep band an exercise trains in today: the card's override if set, else the goal's band for its difficulty on
/// this lifting workout of the rotation (bands in a row cycle by workout), floored by the bodyweight range.
RepRange todayRange(AppState s, Exercise ex, {int liftIndex = 0}) =>
    rangeFor(s, ex, s.ex[ex.id]?.repsOverride ?? s.goal!.rangeForDifficulty(ex.difficulty, liftIndex));

/// What a set is worth, read at the user's usual weight: the reps it would be at that weight. The same
/// percent-of-max table that defines the expressions (Epley: max = weight x (1 + reps / 30)).
double repsEquivalent(int reps, double kg, double usualKg) => 30 * (kg * (1 + reps / 30) / usualKg - 1);

/// A rep band applied to an exercise: floored by the bodyweight range. Holds keep their own seconds.
RepRange rangeFor(AppState s, Exercise ex, RepRange base) {
  final bw = ex.bwRange;
  if (ex.repLabel == 'seconds' && bw != null) return bw;
  var r = base;
  if (bw != null) r = RepRange(max(r.lo, bw.lo), max(r.hi, bw.hi));
  if (r.hi <= r.lo) r = RepRange(r.lo, r.lo + 2);
  return r;
}

/// The reps a loaded exercise's level is kept in: the card's range if set, else the first range the goal gives its
/// difficulty. Here one level is exactly one plate step; other reps carry the weight to them.
RepRange homeRange(AppState s, Exercise ex) => todayRange(s, ex);

/// A weight for one rep range carried to another by the percent-of-max table: what lifts the same at those reps.
double carryLoad(double kg, RepRange from, RepRange to) => kg * pctFor(to) / pctFor(from);

/// A loaded level's grid: the weight at level 0 in the home reps, and the plate step each level adds. When the home
/// reps or the step have changed since the grid was laid (the goal, the card's reps, the unit), or the level was saved
/// before version 7 as an estimated max, it is laid again around the current level, so that level keeps its weight.
({double base, double step}) levelGrid(AppState s, Exercise ex, ExerciseState st) {
  final step = stepKg(s, ex), home = homeRange(s, ex);
  if (st.baseReps == home && st.baseStepKg == step) return (base: st.baseKg!, step: step);
  final now = st.baseReps == null || st.baseStepKg == null
      ? (st.baseKg! + st.rung * step / lightestShare) * pctFor(home) // the old max stepped by a plate over the lightest share
      : carryLoad(st.baseKg! + st.rung * st.baseStepKg!, st.baseReps!, home);
  return (base: max(ex.platesAdded ? 0.0 : step, roundStep(now, step)) - st.rung * step, step: step);
}

/// Keep the saved grid in step with [levelGrid], before anything moves the level.
void relayLevel(AppState s, Exercise ex, ExerciseState st) {
  if (!ex.loaded || st.baseKg == null) return;
  final g = levelGrid(s, ex, st);
  st.baseKg = g.base;
  st.baseReps = homeRange(s, ex);
  st.baseStepKg = g.step;
}

/// A level's working weight in the home reps: the base plus one plate step a level.
double levelKg(AppState s, Exercise ex, ExerciseState st, int rung) {
  final g = levelGrid(s, ex, st);
  return g.base + rung * g.step;
}

/// The estimated max behind a level, by the percent-of-max table. Shown on the card; seeds a related exercise.
double maxFor(AppState s, Exercise ex, ExerciseState st, int rung) => levelKg(s, ex, st, rung) / pctFor(homeRange(s, ex));

/// Smallest practical step for a loaded exercise, in kilograms, following the display unit.
double stepKg(AppState s, Exercise ex) {
  final step = ex.stepKg ?? ex.ladder?.loadStep ?? 2.5;
  if (s.units == 'lb') return (step >= 5 ? 10 : 5) / lbPerKg;
  return step;
}

/// A weight in the user's unit, with an optional suffix (' per hand').
String fmtKg(AppState s, double kg, {String suffix = ''}) {
  if (s.units == 'lb') {
    final lb = (kg * lbPerKg / 2.5).round() * 2.5;
    return '${lb % 1 == 0 ? lb.toInt() : lb.toStringAsFixed(1)} lb$suffix';
  }
  return '${kg % 1 == 0 ? kg.toInt() : kg.toStringAsFixed(1)} kg$suffix';
}

/// Load in kilograms for a loaded exercise at a rung, for a rep band (the home reps by default): the level's weight in
/// the home reps, carried to other reps and rounded to a plate step. Never below one step, except on a Smith machine
/// or landmine, where 0 is the empty bar. For the assisted machine this is what the user lifts ([assistRefKg] less the
/// assistance); [fmtLoad] shows it as assistance.
double loadFor(AppState s, Exercise ex, ExerciseState st, int rung, [RepRange? range]) {
  final step = stepKg(s, ex), home = homeRange(s, ex);
  final kg = levelKg(s, ex, st, rung);
  return max(ex.platesAdded ? 0 : step, range == null || range == home ? kg : roundStep(carryLoad(kg, home, range), step));
}

/// The assisted machine's loads are assistance, which falls as the user gets stronger. The app works with what the user
/// lifts instead, a reference body weight less the assistance, so a level up is more work like everywhere else.
const assistRefKg = 80.0;

/// A loaded exercise's starting load for an experience, as the app works with it: assistance turned into what is lifted.
double startLoad(Exercise ex, int exp) => ex.assist ? assistRefKg - ex.startKg![exp] : ex.startKg![exp];

Iterable<String> _here(AppState s) => s.location(s.lastLocationId)?.equipment ?? const <String>[];

/// The equipment option an exercise is done with here: the first one fully available, else its first.
List<String> usedOption(Exercise ex, Iterable<String> equipment) {
  final have = equipment.toSet();
  return ex.needs.firstWhere((o) => o.every(have.contains), orElse: () => ex.needs.first);
}

/// The other implement's loads when that is all the location offers for the exercise: dumbbells for a bar exercise,
/// a trap bar for the farmer's carry (EXERCISE_DATA.md, "How loads are written"). Null when the main one is here.
({String gear, AltLoad load})? altHere(Exercise ex, Iterable<String> equipment) {
  if (ex.altLoad.isEmpty) return null;
  final have = equipment.toSet();
  final ok = ex.needs.where((o) => o.every(have.contains)).toList();
  if (ok.isEmpty) return null;
  for (final a in ex.altLoad.entries) {
    if (ok.every((o) => o.contains(a.key))) return (gear: a.key, load: a.value);
  }
  return null;
}

String _perWhat(List<String> option) => option.contains('dumbbell') || option.contains('kettlebell') ? ' per hand' : ' per side';

/// A loaded exercise's weight as the user reads it, at a location (the last one by default): dumbbells and
/// kettlebells per hand, a one-limb load per side, a bar as its total, a Smith machine or landmine as the plates added
/// ('empty bar' at 0), the assisted machine as its assistance, and a bar exercise done with dumbbells in dumbbells.
String fmtLoad(AppState s, Exercise ex, double kg, {Iterable<String>? equipment}) {
  final eq = equipment ?? _here(s);
  if (ex.assist) {
    final help = assistRefKg - kg;
    return help <= 0 ? 'no assistance' : '${fmtKg(s, help)} assistance';
  }
  final alt = altHere(ex, eq);
  if (alt != null) {
    final shown = max(alt.load.stepKg, roundStep(kg * alt.load.startKg[1] / ex.startKg![1], alt.load.stepKg));
    return fmtKg(s, shown, suffix: alt.load.each ? ' per hand' : '');
  }
  if (ex.platesAdded) return kg <= 0 ? 'empty bar' : '+${fmtKg(s, kg)}';
  return fmtKg(s, kg, suffix: ex.each ? _perWhat(usedOption(ex, eq)) : '');
}

/// What one level adds, as the user reads it: "2.5 kg", "1 kg per hand", "5 kg less assistance".
String fmtLevelStep(AppState s, Exercise ex, {Iterable<String>? equipment}) {
  final eq = equipment ?? _here(s);
  if (ex.assist) return '${fmtKg(s, stepKg(s, ex))} less assistance';
  final alt = altHere(ex, eq);
  if (alt != null) return fmtKg(s, alt.load.stepKg, suffix: alt.load.each ? ' per hand' : '');
  return fmtKg(s, stepKg(s, ex), suffix: ex.each && !ex.platesAdded ? _perWhat(usedOption(ex, eq)) : '');
}

/// Lowest rung a loaded exercise can hold: one plate step in the home reps, or the empty bar where 0 is one.
int floorRung(AppState s, Exercise ex, ExerciseState st) {
  if (!ex.loaded) return 0;
  final g = levelGrid(s, ex, st);
  return (((ex.platesAdded ? 0 : g.step) - g.base) / g.step).round();
}

/// Highest rung at a location, or null when the ladder has no top (loaded, or loading gear present).
int? ceilingFor(Exercise ex, Iterable<String> equipment) {
  final l = ex.ladder;
  if (l == null) return null;
  final have = equipment.toSet();
  if (l.loadGear.any(have.contains)) return null;
  return l.variants.length - 1;
}

/// The rung actually usable at a location: the stored rung clamped to the location's ceiling.
int effectiveRung(Exercise ex, ExerciseState st, Iterable<String> equipment) {
  final c = ceilingFor(ex, equipment);
  return c == null ? st.rung : min(st.rung, c);
}

bool atCeiling(Exercise ex, ExerciseState st, Iterable<String> equipment) {
  final c = ceilingFor(ex, equipment);
  return c != null && st.rung >= c;
}

String rungLabel(AppState s, Exercise ex, ExerciseState st, int rung, [RepRange? range, Iterable<String>? equipment]) {
  final l = ex.ladder;
  if (l == null) return fmtLoad(s, ex, loadFor(s, ex, st, rung, range), equipment: equipment);
  if (rung < l.variants.length) return l.variants[max(0, rung)].name;
  final extra = (rung - l.variants.length + 1) * (s.units == 'lb' ? 5 / lbPerKg : l.loadStep);
  return '${l.variants.last.name} +${fmtKg(s, extra)}';
}

String? rungNote(Exercise ex, int rung) {
  final l = ex.ladder;
  if (l == null) return null;
  if (rung < l.variants.length) return l.variants[max(0, rung)].note;
  return 'with ${l.loadGear.map((g) => equipment[g]!.toLowerCase()).join(' or ')}';
}

/// Timing seed for a band: work (3 s a rep at the top of the range, or the hold seconds) plus rest plus 15 s
/// transition, rounded up to 15 s. Generous on purpose; the timing model replaces it with the user's own seconds.
double seedSeconds(AppState s, Exercise ex, RepRange range) {
  final work = ex.repLabel == 'seconds' ? range.hi : range.hi * 3;
  final secs = work + restFor(range) + 15;
  return ((secs / 15).ceil() * 15).toDouble();
}

/// Difficulty in play: default or override, moved by the user's own history, clamped 1 to 3.
int difficultyInPlay(Exercise ex, ExerciseState? st) {
  final base = st?.costOverride ?? ex.difficulty;
  return (base + (st?.costUp ?? 0) - (st?.costDown ?? 0)).clamp(1, 3);
}

/// Starting state for an exercise: from experience, or from history with another loaded exercise for the same primary
/// muscle, the most practised one.
ExerciseState ensureState(AppState s, Exercise ex) {
  final existing = s.ex[ex.id];
  if (existing != null) {
    relayLevel(s, ex, existing);
    return existing;
  }
  final exp = experienceIndex(s.profile!.experience);
  final seed = seedSeconds(s, ex, todayRange(s, ex));
  late final ExerciseState st;
  if (ex.loaded) {
    // the library's starting weights are middle-band working weights; the level keeps them in the home reps
    final home = homeRange(s, ex), step = stepKg(s, ex);
    var base = carryLoad(startLoad(ex, exp), middleReps, home);
    ExerciseState? knownSt;
    Exercise? known;
    final group = ex.primary.isEmpty ? null : muscleGroup(ex.primary.first);
    for (final other in exercises) {
      if (other.id == ex.id || !other.loaded || !other.isStrength || other.primary.isEmpty || muscleGroup(other.primary.first) != group) continue;
      final o = s.ex[other.id];
      if (o == null || o.appearances == 0) continue;
      if (knownSt == null || o.appearances > knownSt.appearances) { knownSt = o; known = other; }
    }
    if (known != null) {
      final ratio = (maxFor(s, known, knownSt!, knownSt.rung) / (startLoad(known, exp) / pctFor(middleReps))).clamp(0.5, 2.0);
      base = base * ratio;
    }
    st = ExerciseState(rung: 0, startRung: 0, baseKg: max(ex.platesAdded ? 0 : step, roundStep(base, step)), baseReps: home, baseStepKg: step, secPerSet: seed);
  } else {
    final start = ex.ladder!.start[exp].clamp(0, ex.ladder!.variants.length - 1);
    st = ExerciseState(rung: start, startRung: start, secPerSet: seed);
  }
  s.ex[ex.id] = st;
  return st;
}

/// A saved edit: the user says this is the rung. Streaks reset and the decay floor follows.
void setRung(AppState s, Exercise ex, int rung) {
  final st = ensureState(s, ex);
  st.rung = ex.loaded ? max(floorRung(s, ex, st), rung) : max(0, rung);
  st.startRung = st.rung;
  st.topRun = 0;
  st.shortRun = 0;
  st.decayedBy = 0;
  st.calibrating = false;
  st.bestTotal = 0;
}

/// Convert a load for a rep band (the home reps by default) into the nearest rung for a loaded exercise.
int rungForLoad(AppState s, Exercise ex, ExerciseState st, double kg, [RepRange? range]) {
  final g = levelGrid(s, ex, st), home = homeRange(s, ex);
  final kgHome = range == null || range == home ? kg : carryLoad(kg, range, home);
  return ((kgHome - g.base) / g.step).round();
}

/// Warm-up suggestion for a loaded exercise at cost 4 or 5: two lighter sets, never logged.
List<Warmup> warmupsFor(AppState s, Exercise ex, double load) {
  if (!ex.loaded) return const [];
  final step = stepKg(s, ex);
  final half = roundStep(load * 0.5, step), three = roundStep(load * 0.75, step);
  if (half < step * 2 || three >= load) return const [];
  return [Warmup(8, half), Warmup(5, three)];
}

/// The ladder as a list for the exercise card: every rung the location can show, with the current one marked.
List<({int rung, String label, String? note, bool current, bool reached})> ladderView(AppState s, Exercise ex, Iterable<String> equipment) {
  final st = ensureState(s, ex);
  final out = <({int rung, String label, String? note, bool current, bool reached})>[];
  if (ex.loaded) {
    for (var r = st.rung - 2; r <= st.rung + 2; r++) {
      if (r < floorRung(s, ex, st)) continue;
      out.add((rung: r, label: rungLabel(s, ex, st, r), note: null, current: r == st.rung, reached: r <= st.rung));
    }
    return out;
  }
  final l = ex.ladder!;
  final c = ceilingFor(ex, equipment);
  final top = c ?? max(l.variants.length + 1, st.rung + 2);
  for (var r = 0; r <= top; r++) {
    out.add((rung: r, label: rungLabel(s, ex, st, r), note: rungNote(ex, r), current: r == st.rung, reached: r <= st.rung));
  }
  return out;
}
