// Selection: which muscles a workout works and which exercise works each one. Two ledgers per muscle, readiness
// (the muscle map) and share (sets over the look-back against a target scaled by emphasis), and one word per exercise
// (liked, fine, not for me). The ledgers are worked out from logged sets every time, never stored. The muscles are the
// map's own (data/index.dart `trackedMuscles`), the same ones the muscle picker shows. SELECTION.md.
import '../data/index.dart';
import '../data/library.dart';
import '../data/model.dart';
import 'muscle_map.dart';
import 'person.dart';

/// The user's word on an exercise.
const prefLiked = 'liked';
const prefFine = 'fine';
const prefNo = 'no';
const preferenceLabel = {prefLiked: 'Liked', prefFine: 'Fine', prefNo: 'Not for me'};
/// A manual pick of an unrated exercise counts as liked for this long.
const softLikeDays = 28;
/// Swapped out this many times in a row, never done in between, asks "still like it?".
const swapsBeforeAsking = 3;
/// A muscle asked for by hand this many times in this many days earns one line suggesting more emphasis.
const askedMuscleTimes = 3;
const askedMuscleDays = 14;

/// The order muscles take when nothing else separates them: the big movers first, so a first workout is squat, row,
/// bench and hinge rather than four small muscles.
const selectionOrder = [
  'quads', 'upper back', 'chest', 'hamstrings', 'lats', 'front shoulders', 'glutes', 'abs', 'side shoulders', 'triceps',
  'biceps', 'rear shoulders', 'calves', 'lower back', 'obliques', 'traps', 'forearms', 'outer hips', 'inner thighs',
];

/// The preference in play: the user's word, else a soft like from a manual pick, else unrated (null).
String? preferenceOf(ExerciseState? st, DateTime now) {
  if (st == null) return null;
  if (st.preference != null) return st.preference;
  if (st.likedUntil != null && now.isBefore(st.likedUntil!)) return prefLiked;
  return null;
}

/// Liked first, then fine and unrated together, then not for me.
int preferenceRank(String? p) => p == prefLiked ? 0 : p == prefNo ? 2 : 1;

/// The muscle groups an exercise works mainly: for browsing and the library's coverage, not for selection.
Set<String> primaryGroups(Exercise ex) => {for (final m in ex.primary) muscleGroup(m)};

/// The sets each muscle has had over the look-back, against its target.
class Share {
  Share(this.sets, this.targets, this.lastWorked);
  final Map<String, double> sets;
  final Map<String, double> targets;
  final Map<String, DateTime?> lastWorked;

  double of(String muscle) => sets[muscle] ?? 0;
  double target(String muscle) => targets[muscle] ?? 0;
  double deficit(String muscle) => target(muscle) - of(muscle);

  /// 0 behind (under half the target), 1 on track (half to just under it), 2 done (the target or more).
  int band(String muscle) {
    final t = target(muscle);
    if (t <= 0) return 2;
    final x = of(muscle);
    return x >= t ? 2 : x < t / 2 ? 0 : 1;
  }

  String bandWord(String muscle) => const ['behind', 'on track', 'has had its share'][band(muscle)];
}

/// Share over the goal's look-back, today included, from the attempted sets of every lifting workout: one to each
/// primary muscle, a half to each secondary one, a light set half of that.
Share shareOver(AppState s, DateTime now) {
  final g = s.goal!;
  final from = dayOf(now).subtract(Duration(days: g.lookBackDays - 1));
  final sets = <String, double>{};
  for (final x in s.sessions) {
    if (x.type != 'lift' || x.endedAt == null || x.endedAt!.isBefore(from) || x.endedAt!.isAfter(now)) continue;
    for (final e in x.exercises) { addShare(sets, e.exercise, e.attempted.length.toDouble(), light: e.intent == 'light'); }
  }
  final days = s.profile?.daysPerWeek ?? 3;
  final targets = {for (final m in trackedMuscles) m: g.targetFor(m, days)};
  return Share(sets, targets, MuscleMap(s).lastWorked());
}

/// Add [n] sets of [ex] to a share tally.
void addShare(Map<String, double> sets, Exercise ex, double n, {bool light = false}) {
  if (n <= 0) return;
  final share = light ? 0.5 : 1.0;
  for (final m in ex.primary) { sets[m] = (sets[m] ?? 0) + n * share; }
  for (final m in ex.secondary) {
    if (ex.primary.contains(m)) continue;
    sets[m] = (sets[m] ?? 0) + n * 0.5 * share;
  }
}

/// How many lifting workouts in a row, latest first, have worked [muscle] with [exId]: the run the practised pick has had.
int runOf(AppState s, String muscle, String exId) {
  var run = 0;
  for (final x in s.sessions.reversed) {
    if (x.type != 'lift') continue;
    final here = x.exercises.where((e) => e.attempted.isNotEmpty && e.exercise.primary.contains(muscle)).toList();
    if (here.isEmpty) continue;
    if (here.any((e) => e.exId == exId)) { run++; } else { break; }
  }
  return run;
}

/// Exercises the builder may choose for a muscle here: that muscle among the primary muscles, doable with the
/// equipment, not paused for pain, not in [exclude], and with none of [avoid] (today's excluded muscles) among its
/// primary muscles.
List<Exercise> candidatesFor(AppState s, String muscle, Iterable<String> equipment, Iterable<String> exclude, DateTime now, {Set<String> avoid = const {}}) {
  final ex = exclude.toSet();
  final pausedMuscles = pausedMusclesAt(s, now);
  return exercises.where((e) =>
      e.primary.contains(muscle) && available(e, equipment) && !ex.contains(e.id) && !e.primary.any(avoid.contains) &&
      !s.plan!.paused.containsKey(e.id) && !e.primary.any(pausedMuscles.contains)).toList();
}

/// The muscles resting for pain: the primary muscles of every paused exercise.
Set<String> pausedMusclesAt(AppState s, DateTime now) => {
      for (final e in s.plan!.paused.entries) if (now.isBefore(e.value) && exerciseById[e.key] != null) ...exerciseById[e.key]!.primary,
    };

/// The exercises the builder put on a plan that the user swapped out: their count in a row goes up. Doing one resets it.
void noteSwappedOut(AppState s, Iterable<String> exIds) {
  for (final id in exIds) {
    final st = s.ex[id];
    if (st != null) st.swappedOut++;
  }
}

/// Exercises that appeared for the first time in [session] and carry no word yet: the ones to ask about after it.
List<Exercise> firstTimers(AppState s, Session session) => [
      for (final e in session.exercises)
        if (e.attempted.isNotEmpty && (s.ex[e.exId]?.appearances ?? 0) == 1 && s.ex[e.exId]?.preference == null) e.exercise,
    ];

/// The one line on why an exercise was chosen, from the two ledgers and the word.
String whyLine({required bool ready, required int band, required int emphasis, String? preference, bool fresh = false, bool asked = false}) {
  final parts = <String>[];
  if (asked) parts.add('you asked for it');
  parts.add(ready ? 'ready' : 'still carrying strain');
  parts.add(const ['behind this week', 'on track this week', 'has had its share'][band]);
  if (emphasis > 0) parts.add('you want more');
  if (emphasis < 0) parts.add('you want less');
  if (preference == prefLiked) parts.add('you like it');
  if (preference == prefNo) parts.add('not for you, nothing else fits');
  if (fresh) parts.add('something new to try');
  return parts.join(', ');
}

/// The muscles that should move to more emphasis after being asked for by hand [askedMuscleTimes] times in
/// [askedMuscleDays] days: the line is said once per muscle. Returns the muscles to say it for.
List<String> moreSuggestions(AppState s, DateTime now) {
  final p = s.plan!;
  final since = now.subtract(const Duration(days: askedMuscleDays));
  final counts = <String, int>{};
  for (final a in p.asked) { if (!a.at.isBefore(since)) counts[a.muscle] = (counts[a.muscle] ?? 0) + 1; }
  return [for (final e in counts.entries) if (e.value >= askedMuscleTimes && s.goal!.emphasisOf(e.key) < 1 && !p.moreSuggested.contains(e.key)) e.key];
}

/// Days since a muscle was worked, or null.
int? daysSinceWorked(Share share, String muscle, DateTime now) => share.lastWorked[muscle] == null ? null : daysAgo(share.lastWorked[muscle]!, now);
