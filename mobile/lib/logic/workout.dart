// The workout as items on a strip (warm-up, each exercise, or one circuit or free-form block, cardio, stretching) and
// the two taps that move through it: the reps, which end a set, and I'm ready, which starts the next one. Lifting is the time from I'm
// ready to the reps; rest is everything else, setting up the next exercise included. An item runs from when it
// starts until the next one does. Section 5 of APPLICATION.md.
import 'dart:math';

import '../data/model.dart';
import 'after.dart';
import 'calibrate.dart' show isTestSet;
import 'ladder.dart';

enum ItemKind { warmup, exercise, circuit, free, cardio, stretch }

class WorkoutItem {
  const WorkoutItem(this.key, this.kind, {this.exercises = const [], this.minutes = 0});
  final String key;
  final ItemKind kind;
  final List<int> exercises;   // indexes into the session's exercises
  final int minutes;           // timed blocks: their length
  bool get lifting => kind == ItemKind.exercise || kind == ItemKind.circuit || kind == ItemKind.free;
}

typedef SetRef = ({int ex, int set});

/// The rest between rounds of a circuit, before the first exercise comes round again.
const roundRestSeconds = 90;

/// The items of a lifting workout, in order.
List<WorkoutItem> workoutItems(Session s) {
  final out = <WorkoutItem>[];
  if (s.warmupMinutes > 0) out.add(WorkoutItem('warmup', ItemKind.warmup, minutes: s.warmupMinutes));
  if (s.order != WorkoutOrder.sequence && s.exercises.length > 1) {
    final free = s.order == WorkoutOrder.free;
    out.add(WorkoutItem(free ? 'free' : 'circuit', free ? ItemKind.free : ItemKind.circuit, exercises: [for (var i = 0; i < s.exercises.length; i++) i]));
  } else {
    for (var i = 0; i < s.exercises.length; i++) { out.add(WorkoutItem('ex$i', ItemKind.exercise, exercises: [i])); }
  }
  if (s.cardioMinutes > 0) out.add(WorkoutItem('cardio', ItemKind.cardio, minutes: s.cardioMinutes));
  if (s.stretchMinutes > 0) out.add(WorkoutItem('stretch', ItemKind.stretch, minutes: s.stretchMinutes));
  return out;
}

SetLog setOf(Session s, SetRef r) => s.exercises[r.ex].sets[r.set];

/// The sets of a lifting item in the order they are done: the ones started so far in the order they were started, then
/// the rest as the order has them: all of one exercise and then the next (free form lists them so too), or round by
/// round in a circuit. Without a change of order or a free-form pick this is just the plan's order.
List<SetRef> setOrder(Session s, WorkoutItem item) => _order(s, item, item.exercises.where((i) => !s.skipped.contains(i)).toList());

List<SetRef> _order(Session s, WorkoutItem item, List<int> exercises) {
  if (!item.lifting) return const [];
  final rounds = exercises.fold(0, (a, i) => max(a, s.exercises[i].sets.length));
  final plan = item.kind == ItemKind.circuit
      ? [for (var r = 0; r < rounds; r++) for (final i in exercises) if (r < s.exercises[i].sets.length) (ex: i, set: r)]
      : [for (final i in exercises) for (var r = 0; r < s.exercises[i].sets.length; r++) (ex: i, set: r)];
  final pos = {for (var k = 0; k < plan.length; k++) plan[k]: k};
  DateTime? when(SetRef r) { final x = setOf(s, r); return x.start ?? x.at ?? (x.attempted ? DateTime(0) : null); }
  final started = [for (final r in plan) if (when(r) != null) r]
    ..sort((a, b) { final c = when(a)!.compareTo(when(b)!); return c != 0 ? c : pos[a]!.compareTo(pos[b]!); });
  final begun = started.toSet();
  return [...started, for (final r in plan) if (!begun.contains(r)) r];
}

/// The next set of one exercise: its first not yet done. Null when every set is in.
SetRef? nextSetOf(Session s, int ex) {
  final i = s.exercises[ex].sets.indexWhere((x) => !x.attempted);
  return i < 0 ? null : (ex: ex, set: i);
}

/// Free form: the exercises the user can pick from next, the ones with a set still to do, in the plan's order. One
/// skipped comes back if picked.
List<int> freeChoices(Session s, WorkoutItem item) => [for (final i in item.exercises) if (nextSetOf(s, i) != null) i];

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

/// Entering an item: a lifting one starts its next set at once, except free form, which waits for the user's pick.
void _enter(Session s, WorkoutItem item, DateTime now, {int? pick}) {
  s.itemStarts[item.key] = now;
  if (item.lifting) {
    final n = item.kind == ItemKind.free ? (pick == null ? null : nextSetOf(s, pick)) : nextSet(s, item);
    if (n != null) _startSet(s, n, now);
  }
}

void _startSet(Session s, SetRef r, DateTime now) {
  s.skipped.remove(r.ex);
  setOf(s, r).start = now;
}

/// Start: the workout's clock and its first item. A lifting item starts lifting at once: Start, like I'm ready,
/// means the user is set to go.
void startWorkout(AppState state, Session s, DateTime now) {
  startSession(state, s, now);
  final items = workoutItems(s);
  if (items.isNotEmpty) _enter(s, items.first, now);
}

/// I'm ready: the next set of this item, or the next item. False when nothing is left, so the workout can finish. In
/// free form [pick] is the exercise the user chose; without one the first with sets left comes next.
bool ready(Session s, DateTime now, {int? pick}) {
  final items = workoutItems(s);
  final cur = currentItem(s);
  if (cur == null) {
    if (items.isEmpty) return false;
    _enter(s, items.first, now, pick: pick);
    return true;
  }
  if (cur.lifting && liftingSet(s, cur) == null) {
    final free = cur.kind == ItemKind.free;
    final chosen = free && pick != null && cur.exercises.contains(pick) ? nextSetOf(s, pick) : null;
    final n = chosen ?? (free ? freeChoices(s, cur).map((i) => nextSetOf(s, i)!).firstOrNull : nextSet(s, cur));
    if (n != null) { _startSet(s, n, now); return true; }
  }
  final i = items.indexWhere((x) => x.key == cur.key);
  if (i + 1 >= items.length) return false;
  _leave(s, cur);
  _enter(s, items[i + 1], now, pick: pick);
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

/// The reps: they finish the set under way, at the weight or version the exercise is at now. With none under way they
/// correct the last set of this item.
void enterReps(Session s, int reps, DateTime now) {
  final cur = currentItem(s);
  if (cur == null || !cur.lifting) return;
  final r = liftingSet(s, cur);
  if (r != null) {
    final x = setOf(s, r), e = s.exercises[r.ex];
    x.reps = reps;
    x.at = now;
    x.rung = e.rung;
    x.kg = e.loadKg;
    x.test = isTestSet(e, r.set);
    return;
  }
  final last = lastLogged(s, cur);
  if (last != null) setOf(s, last).reps = reps;
}

/// Change a done set's reps afterwards, from looking back at it. A set not done is left alone.
void fixSet(Session s, SetRef r, int reps) {
  final x = setOf(s, r);
  if (x.attempted) x.reps = reps;
}

/// Change the weight (a loaded exercise) or the version (a bodyweight one) mid-workout. The set under way and the sets
/// still to come are done at it; the sets done keep their own. The plan's level is kept, for judging.
void changeLevel(AppState state, Session s, int i, {double? kg, int? rung}) {
  final e = s.exercises[i];
  final ex = e.exercise;
  final st = ensureState(state, ex);
  final eq = state.location(s.locationId)?.equipment ?? const <String>[];
  e.plannedRung ??= e.rung;
  e.plannedKg ??= e.loadKg;
  if (ex.loaded && kg != null) {
    e.loadKg = kg;
    e.rung = rungForLoad(state, ex, st, kg, e.range);
    e.rungLabel = fmtLoad(state, ex, kg, equipment: eq);
  } else if (!ex.loaded && rung != null) {
    e.rung = rung;
    e.rungLabel = rungLabel(state, ex, st, rung, e.range, eq);
  }
}

typedef LevelChoice = ({double? kg, int? rung, String short, String label});

/// What an exercise can change to mid-workout, for the wheel: a loaded one by plate steps around the planned weight, a
/// bodyweight one every version this place can do. [short] is what the wheel shows, [label] the weight as it is
/// written everywhere else ('60 kg per hand').
List<LevelChoice> levelChoices(AppState state, Session s, int i) {
  final e = s.exercises[i];
  final ex = e.exercise;
  final st = ensureState(state, ex);
  final eq = state.location(s.locationId)?.equipment ?? const <String>[];
  if (ex.loaded) {
    final step = stepKg(state, ex), floor = ex.platesAdded ? 0.0 : step;
    final center = e.plannedKg ?? e.loadKg ?? floor;
    final kgs = [for (var k = -15; k <= 15; k++) if (center + k * step >= floor - 1e-6) center + k * step];
    // the weight on now, when it is off this grid (a weight from before the unit changed): in its place
    final now = e.loadKg;
    if (now != null && !kgs.any((kg) => (kg - now).abs() < 1e-6)) kgs..add(now)..sort();
    return [
      for (final kg in kgs)
        (kg: kg, rung: null, short: _number(fmtLoad(state, ex, kg, equipment: eq)), label: fmtLoad(state, ex, kg, equipment: eq)),
    ];
  }
  final l = ex.ladder;
  if (l == null) return const [];
  final top = ceilingFor(ex, eq) ?? max(l.variants.length + 1, max(e.rung, st.rung) + 2);
  return [
    for (var r = 0; r <= top; r++)
      (kg: null, rung: r, short: rungLabel(state, ex, st, r, e.range, eq), label: rungLabel(state, ex, st, r, e.range, eq)),
  ];
}

/// A weight as the wheel shows it: the number alone ('62.5', '+10'), the bar when it is empty.
String _number(String label) {
  final n = RegExp(r'\+?\d+(\.\d+)?').firstMatch(label)?.group(0);
  return n ?? (label == 'empty bar' ? 'Bar' : '0');
}

/// Change how the exercises are gone through, mid-workout. Nothing done is lost and a set under way carries on. Into a
/// circuit or free form, the exercises become one block that began when the first of them did. Back to one at a time,
/// they line up in the order they were started, with the one under way (or just rested from) last of those, then the
/// rest in the plan's order, and each began when its first set did.
void changeOrder(Session s, WorkoutOrder to, DateTime now) {
  if (s.order == to) return;
  final inLifts = currentItem(s)?.lifting ?? false;
  final lifts = [for (final it in workoutItems(s)) if (it.lifting) it];
  final starts = [for (final it in lifts) ?s.itemStarts[it.key]];
  for (final it in lifts) { s.itemStarts.remove(it.key); }
  s.order = to;
  if (starts.isEmpty) return; // not reached yet: nothing to carry over
  final first = starts.reduce((a, b) => a.isBefore(b) ? a : b);
  if (to != WorkoutOrder.sequence || s.exercises.length < 2) {
    s.itemStarts[workoutItems(s).firstWhere((it) => it.lifting).key] = first;
    return;
  }
  final n = s.exercises.length, old = s.exercises;
  Iterable<DateTime> times(int i) => old[i].sets.map((x) => x.start ?? x.at).nonNulls;
  DateTime began(int i) => times(i).reduce((a, b) => a.isBefore(b) ? a : b);
  DateTime latest(int i) => times(i).reduce((a, b) => a.isAfter(b) ? a : b);
  final touched = [for (var i = 0; i < n; i++) if (times(i).isNotEmpty) i]..sort((a, b) => began(a).compareTo(began(b)));
  final under = [for (var i = 0; i < n; i++) if (old[i].sets.any((x) => x.lifting)) i].firstOrNull
      ?? (touched.isEmpty ? null : touched.reduce((a, b) => latest(a).isAfter(latest(b)) ? a : b));
  final perm = [
    for (var i = 0; i < n; i++) if (!touched.contains(i) && s.skipped.contains(i)) i, // passed over: behind, as skipped
    for (final i in touched) if (i != under && nextSetOf(s, i) == null) i,           // finished
    ?under,
    for (final i in touched) if (i != under && nextSetOf(s, i) != null) i,           // begun, still to finish: ahead
    for (var i = 0; i < n; i++) if (!touched.contains(i) && !s.skipped.contains(i)) i,
  ];
  s.exercises = [for (final i in perm) old[i]];
  s.skipped = [for (final i in s.skipped) perm.indexOf(i)];
  final upTo = under == null ? -1 : perm.indexOf(under);
  DateTime? last;
  for (var k = 0; k <= upTo; k++) {
    if (!touched.contains(perm[k])) continue;
    var t = began(perm[k]);
    if (last == null && first.isBefore(t)) t = first; // the first one keeps the block's start, rest before it included
    if (last != null && t.isBefore(last)) t = last;   // never before the one ahead of it, so the one under way is current
    s.itemStarts['ex$k'] = t;
    last = t;
  }
  if (inLifts && upTo < 0) {
    // free form still waiting for its first pick: one at a time starts the first exercise
    s.itemStarts['ex0'] = first;
    final r = nextSetOf(s, 0);
    if (r != null) _startSet(s, r, now);
  }
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
  if (item.kind == ItemKind.free) return null; // the user picks what comes next
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

// ---- pausing ----

/// Pause: the clocks stop here. Nothing moves until resumeWorkout.
void pauseWorkout(Session s, DateTime now) => s.pausedAt ??= now;

/// Resume: every time in the workout moves on by the pause, so the workout, its items, the set under way and the rest
/// all carry on where they stopped. pausedSeconds keeps the total, for the real start time.
void resumeWorkout(Session s, DateTime now) {
  final p = s.pausedAt;
  if (p == null) return;
  s.pausedAt = null;
  final d = now.difference(p);
  if (d <= Duration.zero) return;
  s.pausedSeconds += d.inSeconds;
  s.startedAt = s.startedAt?.add(d);
  s.itemStarts.updateAll((_, t) => t.add(d));
  for (final e in s.exercises) {
    for (final x in e.sets) {
      x.start = x.start?.add(d);
      x.at = x.at?.add(d);
    }
  }
}

// ---- the strip ----

enum BlockState { done, skipped, now, ahead }

/// One block of the strip: a set, or a timed item (warm-up, cardio, stretching). Every block is one step and takes the
/// same room: the strip shows how many steps, not how long each takes.
class StripBlock {
  const StripBlock(this.item, this.kind, this.state, {this.set});
  final String item;
  final ItemKind kind;
  final SetRef? set;
  final BlockState state;
}

/// The strip and where the user is on it: in block [at], or with [between] in the gap after it, resting.
class StripView {
  const StripView(this.blocks, this.at, {this.between = false});
  final List<StripBlock> blocks;
  final int at;
  final bool between;
}

StripView stripView(Session s) {
  final items = workoutItems(s);
  final cur = currentItem(s);
  final curIdx = cur == null ? -1 : items.indexWhere((x) => x.key == cur.key);
  final blocks = <StripBlock>[];
  var at = 0;
  var between = false;
  for (var k = 0; k < items.length; k++) {
    final it = items[k];
    if (!it.lifting) {
      final started = s.itemStarts[it.key] != null;
      final state = k == curIdx ? BlockState.now : k < curIdx ? (started ? BlockState.done : BlockState.skipped) : BlockState.ahead;
      if (k == curIdx) at = blocks.length;
      blocks.add(StripBlock(it.key, it.kind, state));
      continue;
    }
    final order = _order(s, it, it.exercises);
    for (final r in order) {
      final x = setOf(s, r);
      final state = x.lifting ? BlockState.now : x.attempted ? BlockState.done : k < curIdx || s.skipped.contains(r.ex) ? BlockState.skipped : BlockState.ahead;
      if (k == curIdx && x.lifting) at = blocks.length;
      blocks.add(StripBlock(it.key, it.kind, state, set: r));
    }
    if (k == curIdx && liftingSet(s, it) == null) {
      // resting: in the gap after the last set logged, or before the item's first block
      final last = lastLogged(s, it);
      final idx = last == null ? -1 : blocks.indexWhere((b) => b.set == last);
      at = idx >= 0 ? idx : blocks.length - order.length - 1;
      between = true;
    }
  }
  return StripView(blocks, at, between: between);
}
