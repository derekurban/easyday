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

/// The level steps the max by enough that even the lightest band moves by one plate step.
double levelStepKg(AppState s, Exercise ex) => stepKg(s, ex) / lightestShare;

/// The estimated max at a rung.
double maxFor(AppState s, Exercise ex, ExerciseState st, int rung) => st.baseKg! + rung * levelStepKg(s, ex);

/// Smallest practical step for a loaded exercise, in kilograms, following the display unit.
double stepKg(AppState s, Exercise ex) {
  final step = ex.stepKg ?? ex.ladder?.loadStep ?? 2.5;
  if (s.units == 'lb') return (step >= 5 ? 10 : 5) / lbPerKg;
  return step;
}

String fmtKg(AppState s, double kg, {bool each = false}) {
  final suffix = each ? ' each' : '';
  if (s.units == 'lb') {
    final lb = (kg * lbPerKg / 2.5).round() * 2.5;
    return '${lb % 1 == 0 ? lb.toInt() : lb.toStringAsFixed(1)} lb$suffix';
  }
  return '${kg % 1 == 0 ? kg.toInt() : kg.toStringAsFixed(1)} kg$suffix';
}

/// Load in kilograms for a loaded exercise at a rung, for a rep band (today's by default). Never below one step.
double loadFor(AppState s, Exercise ex, ExerciseState st, int rung, [RepRange? range]) {
  final step = stepKg(s, ex);
  return max(step, roundStep(maxFor(s, ex, st, rung) * pctFor(range ?? todayRange(s, ex)), step));
}

/// Lowest rung a loaded exercise can hold: the lightest band is still one plate step.
int floorRung(AppState s, Exercise ex, ExerciseState st) {
  if (!ex.loaded) return 0;
  final minMax = stepKg(s, ex) / lightestShare;
  return (-(st.baseKg! - minMax) / levelStepKg(s, ex)).ceil();
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

String rungLabel(AppState s, Exercise ex, ExerciseState st, int rung, [RepRange? range]) {
  final l = ex.ladder;
  if (l == null) return fmtKg(s, loadFor(s, ex, st, rung, range), each: ex.each);
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
  if (existing != null) return existing;
  final exp = experienceIndex(s.profile!.experience);
  final seed = seedSeconds(s, ex, todayRange(s, ex));
  late final ExerciseState st;
  if (ex.loaded) {
    // the library's starting weights are middle-band working weights; the level is the max behind them
    var base = ex.startKg![exp] / pctFor(middleReps);
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
      final ratio = (maxFor(s, known, knownSt!, knownSt.rung) / (known.startKg![exp] / pctFor(middleReps))).clamp(0.5, 2.0);
      base = base * ratio;
    }
    st = ExerciseState(rung: 0, startRung: 0, baseKg: roundStep(base, stepKg(s, ex)), secPerSet: seed);
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

/// Convert a load for a rep band (today's by default) into a rung for a loaded exercise.
int rungForLoad(AppState s, Exercise ex, ExerciseState st, double kg, [RepRange? range]) =>
    ((kg / pctFor(range ?? todayRange(s, ex)) - st.baseKg!) / levelStepKg(s, ex)).round();

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
