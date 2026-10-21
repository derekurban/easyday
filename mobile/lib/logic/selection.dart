// Selection: which muscles a workout works and which exercise works each one. It starts from the user's tags (active,
// passive, ignored: data/model.dart MuscleTag), asks the muscle map whether each muscle is ready, takes the active
// muscles whose turn it is (the rhythm: strength workouts since each was last a main muscle, scaled by how often), and
// covers them with exercises the user likes. The clocks are worked out from logged sets every time, never stored. The
// muscles are the map's own (data/index.dart `trackedMuscles`), the same ones the muscle picker shows. SELECTION.md.
import '../data/index.dart';
import '../data/library.dart';
import '../data/model.dart';
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
/// A muscle forced by hand this many times in this many days earns one line suggesting a tag or more often.
const askedMuscleTimes = 3;
const askedMuscleDays = 14;
/// An active muscle not worked for this many strength workouts gets one line on Progress.
const forgottenAfterWorkouts = 12;

/// The order muscles take when nothing else separates them: the big movers first, so a first workout is squat, row,
/// bench and hinge rather than four small muscles.
const selectionOrder = [
  'quads', 'upper back', 'chest', 'hamstrings', 'lats', 'front shoulders', 'glutes', 'abs', 'side shoulders', 'triceps',
  'biceps', 'rear shoulders', 'calves', 'lower back', 'obliques', 'traps', 'forearms', 'outer hips', 'inner thighs', 'shins',
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

/// The rhythm: whose turn it is. Per muscle, how many strength workouts have finished since it was last worked
/// directly (a main muscle of an attempted exercise) and since it was last helped at all, with the dates; and the
/// factor how often gives it. A muscle never worked is as overdue as all the workouts so far, plus one, so it is never
/// behind one that has been worked.
class Rhythm {
  Rhythm({required this.workouts, required this.since, required this.helpedSince, required this.lastWorked, required this.lastHelped, required this.factor});
  final int workouts;
  final Map<String, int> since;
  final Map<String, int> helpedSince;
  final Map<String, DateTime?> lastWorked;
  final Map<String, DateTime?> lastHelped;
  final Map<String, double> factor;

  bool neverWorked(String m) => lastWorked[m] == null;
  int sinceOf(String m) => since[m] ?? workouts + 1;
  int helpedSinceOf(String m) => helpedSince[m] ?? workouts + 1;

  /// How overdue an active muscle's turn is: workouts since, doubled for more, halved for less.
  double overdue(String m) => sinceOf(m) * (factor[m] ?? 1);

  /// Whether a muscle's turn has come: as overdue as a plain turn, or never worked.
  bool due(String m) => neverWorked(m) || overdue(m) >= 1;

  /// Its clock in words: "never worked yet", "worked last workout", "last worked 4 workouts ago".
  String dueText(String m) {
    if (neverWorked(m)) return 'never worked yet';
    final n = sinceOf(m);
    if (n == 0) return 'worked last workout';
    return 'last worked ${n == 1 ? 'one workout' : '$n workouts'} ago';
  }

  String helpedText(String m) {
    if (lastHelped[m] == null) return 'never helped yet';
    final n = helpedSinceOf(m);
    if (n == 0) return 'helped last workout';
    return 'last helped ${n == 1 ? 'one workout' : '$n workouts'} ago';
  }
}

/// The rhythm now, from every finished strength workout up to [now], oldest first.
Rhythm rhythmOver(AppState s, DateTime now) {
  final g = s.goal!;
  final lifts = s.sessions.where((x) => x.type == 'lift' && x.endedAt != null && !x.endedAt!.isAfter(now)).toList()
    ..sort((a, b) => a.endedAt!.compareTo(b.endedAt!));
  final since = <String, int>{};
  final helpedSince = <String, int>{};
  final lastWorked = <String, DateTime?>{for (final m in trackedMuscles) m: null};
  final lastHelped = <String, DateTime?>{for (final m in trackedMuscles) m: null};
  for (var i = 0; i < lifts.length; i++) {
    final x = lifts[i];
    final after = lifts.length - 1 - i;
    for (final e in x.exercises) {
      if (e.attempted.isEmpty) continue;
      for (final m in e.exercise.primary) { since[m] = after; lastWorked[m] = x.endedAt; helpedSince[m] = after; lastHelped[m] = x.endedAt; }
      for (final m in e.exercise.secondary) { helpedSince[m] = after; lastHelped[m] = x.endedAt; }
    }
  }
  return Rhythm(
    workouts: lifts.length, since: since, helpedSince: helpedSince, lastWorked: lastWorked, lastHelped: lastHelped,
    factor: {for (final m in trackedMuscles) m: oftenFactor[g.oftenOf(m)]!},
  );
}

/// Exercises the builder may choose for a muscle here: strength exercises with that muscle among their primary
/// muscles, doable with the equipment, not paused for pain, not in [exclude], and with none of [avoid] (today's
/// excluded muscles) among their primary muscles. Power, stability, cardio and stretching entries are never picked
/// for a muscle (EXERCISES.md).
List<Exercise> candidatesFor(AppState s, String muscle, Iterable<String> equipment, Iterable<String> exclude, DateTime now, {Set<String> avoid = const {}}) {
  final ex = exclude.toSet();
  final pausedMuscles = pausedMusclesAt(s, now);
  return exercises.where((e) =>
      e.isStrength && e.primary.contains(muscle) && available(e, equipment) && !ex.contains(e.id) && !e.primary.any(avoid.contains) &&
      !s.plan!.paused.containsKey(e.id) && !e.primary.any(pausedMuscles.contains)).toList();
}

/// The muscles resting for pain: the primary muscles of every paused exercise.
Set<String> pausedMusclesAt(AppState s, DateTime now) => {
      for (final e in s.plan!.paused.entries) if (now.isBefore(e.value) && exerciseById[e.key] != null) ...exerciseById[e.key]!.primary,
    };

/// How many strength workouts in a row, latest first, have worked [muscle] with [exId]: the run the practised pick has had.
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

/// The one line on why an exercise was chosen, in words a person would say: whose turn, what else it covers, the word,
/// what it helps, and whether it is something new or a draw.
String whyLine({
  required bool asked, required bool ready, required String due, List<String> covers = const [], String? preference,
  List<String> helps = const [], bool fresh = false, bool drawn = false,
}) {
  final parts = <String>[];
  if (asked) parts.add('you asked for it');
  if (!ready) parts.add('still carrying strain');
  parts.add(due);
  if (covers.isNotEmpty) parts.add('also covers ${listWords(covers)}');
  if (preference == prefLiked) parts.add('you like it');
  if (preference == prefNo) parts.add('not for you, nothing else fits');
  if (helps.isNotEmpty) parts.add('helps ${listWords(helps)}');
  if (fresh) parts.add('something new to try');
  if (drawn) parts.add('drawn');
  return parts.join(' · ');
}

/// Words for a list: "chest", "lats and biceps", "lats, triceps and forearms".
String listWords(Iterable<String> xs) {
  final l = xs.toList();
  if (l.isEmpty) return '';
  if (l.length == 1) return l.single;
  return '${l.sublist(0, l.length - 1).join(', ')} and ${l.last}';
}

/// The muscles the user has forced by hand [askedMuscleTimes] times in [askedMuscleDays] days that could be a tag or
/// more often instead: the line is said once per muscle. Returns the muscles to say it for.
List<String> moreSuggestions(AppState s, DateTime now) {
  final p = s.plan!;
  final g = s.goal!;
  final since = now.subtract(const Duration(days: askedMuscleDays));
  final counts = <String, int>{};
  for (final a in p.asked) { if (!a.at.isBefore(since)) counts[a.muscle] = (counts[a.muscle] ?? 0) + 1; }
  return [
    for (final e in counts.entries)
      if (e.value >= askedMuscleTimes && !(g.tagOf(e.key) == MuscleTag.active && g.oftenOf(e.key) > 0) && !p.moreSuggested.contains(e.key)) e.key,
  ];
}

/// Days since a muscle was worked directly, or null.
int? daysSinceWorked(Rhythm r, String muscle, DateTime now) => r.lastWorked[muscle] == null ? null : daysAgo(r.lastWorked[muscle]!, now);
