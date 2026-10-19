// Selection: which muscles a workout works and which exercise works each one. Two ledgers per muscle group, readiness
// (the muscle map) and share (sets over the look-back against a target scaled by emphasis), and one word per exercise
// (liked, fine, not for me). The ledgers are worked out from logged sets every time, never stored. SELECTION.md.
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

/// The order groups take when nothing else separates them: the big movers first, so a first workout is squat, row,
/// bench and hinge rather than four small upper-body muscles.
const selectionOrder = ['Quads', 'Back', 'Chest', 'Hamstrings', 'Glutes', 'Shoulders', 'Core', 'Triceps', 'Biceps', 'Calves', 'Forearms'];

/// The preference in play: the user's word, else a soft like from a manual pick, else unrated (null).
String? preferenceOf(ExerciseState? st, DateTime now) {
  if (st == null) return null;
  if (st.preference != null) return st.preference;
  if (st.likedUntil != null && now.isBefore(st.likedUntil!)) return prefLiked;
  return null;
}

/// Liked first, then fine and unrated together, then not for me.
int preferenceRank(String? p) => p == prefLiked ? 0 : p == prefNo ? 2 : 1;

/// The muscle groups an exercise works mainly.
Set<String> primaryGroups(Exercise ex) => {for (final m in ex.primary) muscleGroup(m)};

/// The sets each muscle group has had over the look-back, against its target.
class Share {
  Share(this.sets, this.targets, this.lastWorked);
  final Map<String, double> sets;
  final Map<String, double> targets;
  final Map<String, DateTime?> lastWorked;

  double of(String group) => sets[group] ?? 0;
  double target(String group) => targets[group] ?? 0;
  double deficit(String group) => target(group) - of(group);

  /// 0 behind (under half the target), 1 on track (half to just under it), 2 done (the target or more).
  int band(String group) {
    final t = target(group);
    if (t <= 0) return 2;
    final x = of(group);
    return x >= t ? 2 : x < t / 2 ? 0 : 1;
  }

  String bandWord(String group) => const ['behind', 'on track', 'has had its share'][band(group)];
}

/// Share over the goal's look-back, today included, from the attempted sets of every lifting workout: one to the group of
/// each primary muscle, a half to the group of each secondary one, a light set half of that.
Share shareOver(AppState s, DateTime now) {
  final g = s.goal!;
  final from = dayOf(now).subtract(Duration(days: g.lookBackDays - 1));
  final sets = <String, double>{};
  for (final x in s.sessions) {
    if (x.type != 'lift' || x.endedAt == null || x.endedAt!.isBefore(from) || x.endedAt!.isAfter(now)) continue;
    for (final e in x.exercises) { addShare(sets, e.exercise, e.attempted.length.toDouble(), light: e.intent == 'light'); }
  }
  final days = s.profile?.daysPerWeek ?? 3;
  final targets = {for (final grp in muscleGroups) grp: g.targetFor(grp, days)};
  final last = <String, DateTime?>{for (final grp in muscleGroups) grp: null};
  for (final e in MuscleMap(s).lastWorked().entries) {
    final grp = muscleGroup(e.key);
    if (e.value != null && (last[grp] == null || e.value!.isAfter(last[grp]!))) last[grp] = e.value;
  }
  return Share(sets, targets, last);
}

/// Add [n] sets of [ex] to a share tally.
void addShare(Map<String, double> sets, Exercise ex, double n, {bool light = false}) {
  if (n <= 0) return;
  final share = light ? 0.5 : 1.0;
  final primary = primaryGroups(ex);
  final secondary = {for (final m in ex.secondary) muscleGroup(m)}..removeAll(primary);
  for (final grp in primary) { sets[grp] = (sets[grp] ?? 0) + n * share; }
  for (final grp in secondary) { sets[grp] = (sets[grp] ?? 0) + n * 0.5 * share; }
}

/// How many lifting workouts in a row, latest first, have worked [group] with [exId]: the run the practised pick has had.
int runOf(AppState s, String group, String exId) {
  var run = 0;
  for (final x in s.sessions.reversed) {
    if (x.type != 'lift') continue;
    final here = x.exercises.where((e) => e.attempted.isNotEmpty && primaryGroups(e.exercise).contains(group)).toList();
    if (here.isEmpty) continue;
    if (here.any((e) => e.exId == exId)) { run++; } else { break; }
  }
  return run;
}

/// Exercises the builder may choose for a muscle group here: that group among the primary muscles, doable with the
/// equipment, not paused for pain, not in [exclude].
List<Exercise> candidatesFor(AppState s, String group, Iterable<String> equipment, Iterable<String> exclude, DateTime now) {
  final ex = exclude.toSet();
  final pausedMuscles = pausedMusclesAt(s, now);
  return exercises.where((e) =>
      primaryGroups(e).contains(group) && available(e, equipment) && !ex.contains(e.id) &&
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
String whyLine({required String group, required bool ready, required int band, required int emphasis, String? preference, bool fresh = false, bool asked = false}) {
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

/// The emphasis a group should move to after being asked for by hand [askedMuscleTimes] times in [askedMuscleDays] days:
/// the line is said once per group. Returns the groups to say it for.
List<String> moreSuggestions(AppState s, DateTime now) {
  final p = s.plan!;
  final since = now.subtract(const Duration(days: askedMuscleDays));
  final counts = <String, int>{};
  for (final a in p.asked) { if (!a.at.isBefore(since)) counts[a.group] = (counts[a.group] ?? 0) + 1; }
  return [for (final e in counts.entries) if (e.value >= askedMuscleTimes && s.goal!.emphasisOf(e.key) < 1 && !p.moreSuggested.contains(e.key)) e.key];
}

/// When each muscle group was worked last, from the muscle map.
Map<String, DateTime?> lastWorkedByGroup(AppState s) => shareOver(s, DateTime.now()).lastWorked;

/// Days since a group was worked, or null.
int? daysSinceWorked(Share share, String group, DateTime now) => share.lastWorked[group] == null ? null : daysAgo(share.lastWorked[group]!, now);
