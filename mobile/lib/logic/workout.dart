// The workout as items on a strip (warm-up, each exercise or one circuit, cardio, stretching) and the two taps that
// move through it: the reps, which end a set, and I'm ready, which starts the next one. Lifting is the time from I'm
// ready to the reps; rest is everything else, setting up the next exercise included. An item runs from when it
// starts until the next one does. Section 5 of APPLICATION.md.
import 'dart:math';

import '../data/model.dart';
import 'after.dart';

enum ItemKind { warmup, exercise, circuit, cardio, stretch }

class WorkoutItem {
  const WorkoutItem(this.key, this.kind, {this.exercises = const [], this.minutes = 0});
  final String key;
  final ItemKind kind;
  final List<int> exercises;   // indexes into the session's exercises
  final int minutes;           // timed blocks: their length
  bool get lifting => kind == ItemKind.exercise || kind == ItemKind.circuit;
}

typedef SetRef = ({int ex, int set});

/// The rest between rounds of a circuit, before the first exercise comes round again.
const roundRestSeconds = 90;

/// The items of a lifting workout, in order.
List<WorkoutItem> workoutItems(Session s) {
  final out = <WorkoutItem>[];
  if (s.warmupMinutes > 0) out.add(WorkoutItem('warmup', ItemKind.warmup, minutes: s.warmupMinutes));
  if (s.circuit && s.exercises.length > 1) {
    out.add(WorkoutItem('circuit', ItemKind.circuit, exercises: [for (var i = 0; i < s.exercises.length; i++) i]));
  } else {
    for (var i = 0; i < s.exercises.length; i++) { out.add(WorkoutItem('ex$i', ItemKind.exercise, exercises: [i])); }
  }
  if (s.cardioMinutes > 0) out.add(WorkoutItem('cardio', ItemKind.cardio, minutes: s.cardioMinutes));
  if (s.stretchMinutes > 0) out.add(WorkoutItem('stretch', ItemKind.stretch, minutes: s.stretchMinutes));
  return out;
}

SetLog setOf(Session s, SetRef r) => s.exercises[r.ex].sets[r.set];

/// The sets of a lifting item in the order they are done: all of one exercise, or round by round in a circuit.
List<SetRef> setOrder(Session s, WorkoutItem item) {
  if (!item.lifting) return const [];
  final live = item.exercises.where((i) => !s.skipped.contains(i)).toList();
  final rounds = live.fold(0, (a, i) => max(a, s.exercises[i].sets.length));
  return [
    for (var r = 0; r < rounds; r++)
      for (final i in live) if (r < s.exercises[i].sets.length) (ex: i, set: r),
  ];
}

SetRef? nextSet(Session s, WorkoutItem item) => setOrder(s, item).where((r) => !setOf(s, r).attempted).firstOrNull;
SetRef? liftingSet(Session s, WorkoutItem item) => setOrder(s, item).where((r) => setOf(s, r).lifting).firstOrNull;
SetRef? lastLogged(Session s, WorkoutItem item) => setOrder(s, item).where((r) => setOf(s, r).attempted).lastOrNull;

/// The item under way: the one that started last. Null before the workout starts.
WorkoutItem? currentItem(Session s) {
  WorkoutItem? best;
  DateTime? at;
  for (final it in workoutItems(s)) {
    final t = s.itemStarts[it.key];
    if (t != null && (at == null || !t.isBefore(at))) { best = it; at = t; }
  }
  return best;
}

/// When an item ended: the next item's start, else the end of the workout, else now.
DateTime itemEnd(Session s, WorkoutItem item, DateTime now) {
  final start = s.itemStarts[item.key];
  DateTime? next;
  for (final t in s.itemStarts.values) {
    if (start != null && t.isAfter(start) && (next == null || t.isBefore(next))) next = t;
  }
  return next ?? s.endedAt ?? now;
}

void _enter(Session s, WorkoutItem item, DateTime now) {
  s.itemStarts[item.key] = now;
  if (item.lifting) {
    final n = nextSet(s, item);
    if (n != null) setOf(s, n).start = now;
  }
}

/// Start: the workout's clock and its first item. A lifting item starts lifting at once: Start, like I'm ready,
/// means the user is set to go.
void startWorkout(AppState state, Session s, DateTime now) {
  startSession(state, s, now);
  final items = workoutItems(s);
  if (items.isNotEmpty) _enter(s, items.first, now);
}

/// I'm ready: the next set of this item, or the next item. False when nothing is left, so the workout can finish.
bool ready(Session s, DateTime now) {
  final items = workoutItems(s);
  final cur = currentItem(s);
  if (cur == null) {
    if (items.isEmpty) return false;
    _enter(s, items.first, now);
    return true;
  }
  if (cur.lifting && liftingSet(s, cur) == null) {
    final n = nextSet(s, cur);
    if (n != null) { setOf(s, n).start = now; return true; }
  }
  final i = items.indexWhere((x) => x.key == cur.key);
  if (i + 1 >= items.length) return false;
  _leave(s, cur);
  _enter(s, items[i + 1], now);
  return true;
}

/// Leaving an item: a set still under way is dropped, and an exercise never started is skipped, so it is not judged.
void _leave(Session s, WorkoutItem item) {
  if (!item.lifting) return;
  for (final r in setOrder(s, item)) { if (setOf(s, r).lifting) setOf(s, r).start = null; }
  for (final i in item.exercises) {
    if (s.exercises[i].attempted.isEmpty && !s.skipped.contains(i)) s.skipped.add(i);
  }
}

/// The reps: they finish the set under way. With none under way they correct the last set of this item.
void enterReps(Session s, int reps, DateTime now) {
  final cur = currentItem(s);
  if (cur == null || !cur.lifting) return;
  final r = liftingSet(s, cur);
  if (r != null) {
    final x = setOf(s, r);
    x.reps = reps;
    x.at = now;
    return;
  }
  final last = lastLogged(s, cur);
  if (last != null) setOf(s, last).reps = reps;
}

/// Jump ahead to a later item. The items passed over are skipped: none of their exercises is judged.
void jumpTo(Session s, String key, DateTime now) {
  final items = workoutItems(s);
  final cur = currentItem(s);
  final from = cur == null ? -1 : items.indexWhere((x) => x.key == cur.key);
  final to = items.indexWhere((x) => x.key == key);
  if (to <= from) return;
  if (cur != null) _leave(s, cur);
  for (var k = from + 1; k < to; k++) {
    for (final i in items[k].exercises) { if (!s.skipped.contains(i)) s.skipped.add(i); }
  }
  _enter(s, items[to], now);
}

/// The planned rest before the next set of a lifting item: the exercise's rest when it comes again, a round's rest when
/// a circuit goes round again. Null when the next set is a different exercise (time to set it up) or there is none.
int? plannedRest(Session s, WorkoutItem item) {
  final n = nextSet(s, item), last = lastLogged(s, item);
  if (n == null || last == null) return null;
  if (n.ex == last.ex) return restFor(s.exercises[n.ex].range);
  if (item.kind == ItemKind.circuit && n.set > last.set) return roundRestSeconds;
  return null;
}

/// When the planned rest runs out, for the rest timer setting. Null while lifting or when there is no planned rest.
DateTime? restDue(Session s, WorkoutItem item) {
  if (!item.lifting || liftingSet(s, item) != null) return null;
  final plan = plannedRest(s, item);
  final last = lastLogged(s, item);
  final at = last == null ? null : setOf(s, last).at;
  return plan == null || at == null ? null : at.add(Duration(seconds: plan));
}

/// When the rest under way began: the last reps, or the start of the item. Null while lifting.
DateTime? restSince(Session s, WorkoutItem item) {
  if (item.lifting && liftingSet(s, item) != null) return null;
  final last = lastLogged(s, item);
  return (last == null ? null : setOf(s, last).at) ?? s.itemStarts[item.key];
}

/// Seconds a set took to lift: from its start to the reps. A set logged without a start (older data) is priced at
/// three seconds a rep, or its seconds for a hold.
double liftSeconds(SessionExercise e, SetLog x, DateTime now) {
  if (x.lifting) return now.difference(x.start!).inMilliseconds / 1000;
  if (!x.attempted) return 0;
  if (x.start != null && x.at != null) return max(0, x.at!.difference(x.start!).inMilliseconds / 1000);
  return e.exercise.repLabel == 'seconds' ? x.reps!.toDouble() : 3.0 * x.reps!;
}

/// An item's time split into lifting and rest, in seconds.
({double lifting, double rest}) itemSplit(Session s, WorkoutItem item, DateTime now) {
  final start = s.itemStarts[item.key];
  if (start == null) return (lifting: 0, rest: 0);
  final total = max(0, itemEnd(s, item, now).difference(start).inMilliseconds / 1000).toDouble();
  var lifting = 0.0;
  for (final r in setOrder(s, item)) { lifting += liftSeconds(s.exercises[r.ex], setOf(s, r), now); }
  lifting = min(lifting, total);
  return (lifting: lifting, rest: total - lifting);
}

/// The whole workout's lifting and rest, over its lifting items.
({double lifting, double rest}) workoutSplit(Session s, DateTime now) {
  var l = 0.0, r = 0.0;
  for (final it in workoutItems(s)) {
    if (!it.lifting) continue;
    final x = itemSplit(s, it, now);
    l += x.lifting;
    r += x.rest;
  }
  return (lifting: l, rest: r);
}

/// The exercise the current item is about: the set under way, else the next set, else the last one logged.
int? currentExercise(Session s) {
  final cur = currentItem(s);
  if (cur == null || !cur.lifting) return null;
  return (liftingSet(s, cur) ?? lastLoggedOrNext(s, cur))?.ex;
}

SetRef? lastLoggedOrNext(Session s, WorkoutItem item) => lastLogged(s, item) ?? nextSet(s, item);
