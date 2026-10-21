// Builds today's workout: selection picks the muscles and an exercise for each (SELECTION.md); the list is built once at
// normal and fitted to the minutes by three calibrations (exercises, sets, pushes: the fewest, the ideal, the most);
// energy turns the dials on it (hard: the next level, and room to grow to the most; easy: lighter, fewer exercises at
// full sets). WORKOUT.md and section 7 of APPLICATION.md.
import 'dart:math';

import '../data/index.dart';
import '../data/library.dart';
import '../data/model.dart';
import 'ladder.dart';
import 'muscle_map.dart';
import 'person.dart';
import 'selection.dart';

const intentLight = 'light';
const intentWorking = 'working';
const intentExtra = 'extra';
const intentLabel = {intentLight: 'light', intentWorking: 'working', intentExtra: 'extra set'};

const changeSeconds = 60.0;      // walking to the next exercise and setting up
const warmupSetsSeconds = 120.0; // two warm-up sets on a loaded hard exercise
/// The warm-up block choices, in minutes; 0 is none.
const warmupChoices = [0, 3, 5, 8];
/// With no time limit the window is open: the count decides, not the minutes.
const _openWindow = 600 * 60.0;

/// Expire pain pauses. An exercise comes back on its own, one rung down.
void expirePauses(AppState s, DateTime now) {
  final p = s.plan!;
  final expired = p.paused.entries.where((e) => !now.isBefore(e.value)).map((e) => e.key).toList();
  for (final id in expired) {
    final ex = exerciseById[id];
    final st = s.ex[id];
    if (ex != null && st != null) {
      st.rung = max(ex.loaded ? floorRung(s, ex, st) : 0, st.rung - 1);
      st.topRun = 0;
      st.shortRun = 0;
    }
    p.paused.remove(id);
  }
}

/// Rung and difficulty decay for every exercise not practised for the decay period. Never below where it started.
void applyDecay(AppState s, DateTime now) {
  final weeks = s.settings.decayWeeks;
  if (weeks <= 0) return;
  for (final entry in s.ex.entries) {
    final st = entry.value;
    if (st.lastDoneAt == null) continue;
    final periods = daysBetween(st.lastDoneAt!, now) ~/ (weeks * 7);
    if (periods <= st.decayPeriodsApplied) continue;
    for (var i = st.decayPeriodsApplied; i < periods; i++) {
      if (st.rung > st.startRung) {
        st.rung--;
        st.decayedBy++;
      }
    }
    st.costUp = 1;
    st.decayPeriodsApplied = periods;
    st.topRun = 0;
    st.shortRun = 0;
  }
}

/// Defaults for the two questions: from the last workout, the learning window, and the calendar.
/// [busyShare] is how much of the awake window today's events take, 0 to 1; a busy day shortens the default and a
/// heavy one also makes it easy, by the thresholds in the settings. Never the user's choice.
({Energy energy, int minutes, String? busy}) defaultsFor(AppState s, DateTime now, {double? busyShare}) {
  final p = s.plan!;
  var energy = p.energyDefault;
  final ps = personState(s, now);
  if (ps.state == PersonState.away) energy = Energy.easy;
  var minutes = clampMinutes(p.timeDefault);
  String? busy;
  final st = s.settings;
  if (busyShare != null && st.calendar && st.busyAdjust) {
    final pct = busyShare * 100;
    if (pct >= st.busyEasy) { minutes = min(minutes, busyDayMinutes); energy = Energy.easy; busy = 'easy'; }
    else if (pct >= st.busyShort) { minutes = min(minutes, busyDayMinutes); busy = 'short'; }
  }
  return (energy: energy, minutes: minutes, busy: busy);
}

/// A movement day is due when the goal's count of lifting workouts has gone by since the last one: cardio and mobility
/// take turns. Null when a lifting workout is next.
String? moveDue(AppState s) {
  final every = s.goal?.moveEvery ?? 0;
  if (every <= 0) return null;
  var lifts = 0;
  Session? lastMove;
  for (final x in s.sessions.reversed) {
    if (x.type == 'move') { lastMove = x; break; }
    lifts++;
  }
  if (lifts < every) return null;
  return lastMove?.kind == 'cardio' ? 'mobility' : 'cardio';
}

/// The default on a busy day.
const busyDayMinutes = 25;
/// The ideal list filling no more than this share of the window makes a long day: room to grow to the most.
const longWindowShare = 0.5;

bool _practised(AppState s, Exercise e) => (s.ex[e.id]?.appearances ?? 0) > 0;
int _difficulty(AppState s, Exercise e) => difficultyInPlay(e, s.ex[e.id]);

/// Everything selection reads while a list is being built: the current strain points and today's plan so far, the share
/// ledger, the user's words, and the equipment here.
class _Selection {
  _Selection(this.s, this.now, this.current, this.share, this.equipment) : withPlan = current;
  final AppState s;
  final DateTime now;
  final StrainPoints current;
  final Share share;
  final Iterable<String> equipment;
  StrainPoints withPlan;
  /// The group an unrated exercise may take a turn for today, if any.
  String? exploreGroup;

  /// Every primary muscle of [e] strain-free, counting today's plan so far.
  bool ready(Exercise e) => e.primary.every(withPlan.strainFree);

  /// The shade [e]'s most strained primary muscle sits at, with today's plan so far added.
  int shade(Exercise e) => withPlan.highestShade(e.primary);

  String? pref(Exercise e) => preferenceOf(s.ex[e.id], now);

  /// Ready first, then the lowest shade, then liked, fine and unrated, not for me (an unrated one above fine when it is
  /// this group's turn for something new), then practised, then library rank.
  int compare(Exercise a, Exercise b, {String? group}) {
    final ra = ready(a), rb = ready(b);
    if (ra != rb) return ra ? -1 : 1;
    final c = shade(a).compareTo(shade(b));
    if (c != 0) return c;
    final p = _prefRank(a, group).compareTo(_prefRank(b, group));
    if (p != 0) return p;
    final pa = _practised(s, a), pb = _practised(s, b);
    if (pa != pb) return pa ? -1 : 1;
    return a.rank.compareTo(b.rank);
  }

  double _prefRank(Exercise e, String? group) {
    final p = pref(e);
    if (p == null && group != null && group == exploreGroup) return 0.5;
    return preferenceRank(p).toDouble();
  }

  /// Today's plan so far: the current strain points plus the strain points from workout of [plan].
  void plan(Iterable<({Exercise exercise, int sets, bool light})> plan) => withPlan = current.plus(strainPointsFromPlan(plan));

  void planSlots(Iterable<_Slot> slots) => plan([
        for (final x in slots) if (x.pick != null) (exercise: x.pick!, sets: x.sets == 0 ? 1 : x.sets, light: x.intent == intentLight),
      ]);

  /// The best exercise for a group: the user's pick for the slot, else the first by [compare].
  Exercise? bestFor(String group, Iterable<String> used, String? pref) {
    final cands = candidatesFor(s, group, equipment, used, now);
    if (cands.isEmpty) return null;
    if (pref != null) {
      final p = cands.where((e) => e.id == pref).firstOrNull;
      if (p != null) return p;
    }
    cands.sort((a, b) => compare(a, b, group: group));
    return cands.first;
  }

  /// Groups in the order selection takes them: those with a ready candidate first, then the lowest band, more emphasis,
  /// the furthest behind, the longest waiting, the index order. [candidates] gives the best exercise per group.
  List<String> rankGroups(Iterable<String> groups, Map<String, Exercise> candidates) {
    final g = s.goal!;
    final list = groups.where(candidates.containsKey).toList();
    int key(String grp) => (ready(candidates[grp]!) ? 0 : 1) * 100 + share.band(grp) * 10 + (1 - g.emphasisOf(grp));
    list.sort((a, b) {
      final k = key(a).compareTo(key(b));
      if (k != 0) return k;
      final d = share.deficit(b).compareTo(share.deficit(a));
      if (d != 0) return d;
      final la = share.lastWorked[a], lb = share.lastWorked[b];
      if (la == null && lb != null) return -1;
      if (lb == null && la != null) return 1;
      if (la != null && lb != null && la != lb) return la.compareTo(lb);
      return selectionOrder.indexOf(a).compareTo(selectionOrder.indexOf(b));
    });
    return list;
  }
}

class _Slot {
  _Slot(this.slot, this.group, this.priority);
  final String slot;
  final String group;
  final int priority;   // the order selection took it: lower gets the work first and loses it last
  Exercise? pick;
  String intent = intentWorking;
  int sets = 0;
  bool asked = false;   // the user asked for this muscle by hand
  bool forced = false;  // asked for while still carrying strain
  bool explored = false; // an unrated exercise took its turn here
}

double _seconds(AppState s, _Slot sl) {
  final st = ensureState(s, sl.pick!);
  var secs = st.secPerSet * sl.sets + changeSeconds;
  if (sl.pick!.loaded && _difficulty(s, sl.pick!) >= 3) secs += warmupSetsSeconds;
  return secs;
}
double _totalSeconds(AppState s, List<_Slot> slots) => slots.fold(0.0, (a, x) => a + _seconds(s, x));

/// The working turns on an easy day: the exercises that have waited longest, ties by priority.
int _waitedLongest(AppState s, _Slot a, _Slot b) {
  final la = s.ex[a.pick!.id]?.lastWorkingAt, lb = s.ex[b.pick!.id]?.lastWorkingAt;
  if (la == null && lb != null) return -1;
  if (lb == null && la != null) return 1;
  if (la != null && lb != null && la != lb) return la.compareTo(lb);
  return a.priority.compareTo(b.priority);
}

/// The dials for one energy, on a list that is already built and fitted. The list never changes here.
/// [pushes] is how many exercises train at the next level on a hard day. A first appearance is never pushed.
void _turnDials(AppState s, List<_Slot> slots, Energy energy, GoalConfig g, int pushes) {
  switch (energy) {
    case Energy.easy:
      for (final sl in slots) { sl.intent = intentLight; }
      // two working turns, among the easy and medium exercises only, the longest-waiting first. Hard ones stay light.
      final eligible = slots.where((x) => _difficulty(s, x.pick!) <= 2).toList()..sort((a, b) => _waitedLongest(s, a, b));
      for (final sl in eligible.take(2)) { sl.intent = intentWorking; }
    case Energy.normal:
      break;
    case Energy.hard:
      // the hardest practised exercises train at the next level, every set: the same sets, one step heavier
      final byDifficulty = slots.where((x) => _practised(s, x.pick!)).toList()
        ..sort((a, b) { final c = _difficulty(s, b.pick!).compareTo(_difficulty(s, a.pick!)); return c != 0 ? c : a.priority.compareTo(b.priority); });
      for (final sl in byDifficulty.take(pushes)) { sl.intent = intentExtra; }
  }
}

/// Fit the minutes: exercises down to the fewest (light ones first, then the last on the list), then sets down to
/// the fewest (the exercise with the most sets first, the last on the list among equals), and only when the minutes
/// cannot hold even that, below the fewest. Returns the slots dropped, so growth can bring them back if room appears.
List<_Slot> _fitTime(AppState s, List<_Slot> slots, double window, GoalConfig g) {
  final dropped = <_Slot>[];
  void drop(_Slot victim) { slots.remove(victim); dropped.insert(0, victim); }
  for (var guard = 0; guard < 80 && _totalSeconds(s, slots) > window; guard++) {
    final byPriority = slots.toList()..sort((a, b) => b.priority.compareTo(a.priority));
    if (slots.length > g.exercises.min) { drop(byPriority.where((x) => x.intent == intentLight).firstOrNull ?? byPriority.first); continue; }
    final shrinkable = byPriority.where((x) => x.sets > g.sets.min).toList()..sort((a, b) => b.sets.compareTo(a.sets));
    if (shrinkable.isNotEmpty) { shrinkable.first.sets--; continue; }
    if (slots.length > 1) { drop(byPriority.first); continue; }
    if (slots.single.sets > 1) { slots.single.sets--; continue; }
    break;
  }
  return dropped;
}

/// Grow the exercises into what is left, one at a time, up to [limit]: dropped ones first, then the next muscle by the
/// selection rules, only when its exercise fits the seconds left.
void _grow(AppState s, List<_Slot> slots, double window, int limit, int sets, List<_Slot> dropped, Set<String> blocked, _Selection sel) {
  var added = slots.where((x) => x.slot.endsWith('x')).length;
  for (var guard = 0; guard < 20 && slots.length < limit; guard++) {
    final secsLeft = window - _totalSeconds(s, slots);
    if (secsLeft <= 0) break;
    sel.planSlots(slots);
    _Slot? next;
    final back = dropped.where((d) => !slots.contains(d)).firstOrNull;
    if (back != null && _seconds(s, back) <= secsLeft) {
      next = back;
    } else {
      final used = slots.map((x) => x.pick!.id).toList();
      for (final cand in _rankedGroups(s, slots, used, blocked, sel)) {
        final sl = _Slot('${cand.group}x${added + 1}', cand.group, 100 + added)..pick = cand.exercise..intent = intentWorking..sets = sets;
        if (_seconds(s, sl) <= secsLeft) { next = sl; break; }
      }
    }
    if (next == null) break;
    slots.add(next);
    added++;
  }
}

/// The muscle groups in the order selection takes them, each with its exercise: untaken groups while one of them is
/// ready and behind, otherwise any group; a group already in the plan takes a second exercise only then.
List<({String group, Exercise exercise})> _rankedGroups(AppState s, List<_Slot> slots, List<String> used, Set<String> blocked, _Selection sel) {
  final taken = slots.map((x) => x.group).toSet();
  final best = <String, Exercise>{};
  for (final grp in muscleGroups) {
    if (blocked.contains(grp)) continue;
    final e = sel.bestFor(grp, used, null);
    if (e != null) best[grp] = e;
  }
  if (best.isEmpty) return const [];
  final untaken = best.keys.where((g) => !taken.contains(g));
  final behindReady = untaken.any((g) => sel.ready(best[g]!) && sel.share.band(g) == 0);
  final pool = behindReady ? untaken : best.keys;
  return [for (final g in sel.rankGroups(pool, best)) (group: g, exercise: best[g]!)];
}

/// Grow the sets into what is left, one set at a time round the list in priority order, up to [limit] each.
void _growSets(AppState s, List<_Slot> slots, double window, int limit) {
  final byPriority = slots.toList()..sort((a, b) => a.priority.compareTo(b.priority));
  for (var guard = 0; guard < 60; guard++) {
    var grew = false;
    for (final sl in byPriority) {
      if (sl.sets >= limit) continue;
      sl.sets++;
      if (_totalSeconds(s, slots) > window) { sl.sets--; return; }
      grew = true;
    }
    if (!grew) return;
  }
}

int _tier(String intent) => switch (intent) { intentExtra => 0, intentWorking => 1, _ => 2 };

class BuildOptions {
  BuildOptions({
    required this.energy, required this.minutes, this.locationId, this.picks = const {}, this.rungOverrides = const {},
    this.moveKind, this.routine, this.cardio, this.energyChosen = false, this.timeChosen = false, this.circuit = false,
    this.exerciseCount, this.warmupMinutes = 0, this.skipCardio = false, this.skipStretch = false, this.order = const [],
    this.muscles = const [], this.leftOut = const {}, this.liftInstead = false,
  });
  final Energy energy;
  final int minutes;
  /// No time limit: this many exercises at the ideal sets, and the minutes are whatever they take.
  final int? exerciseCount;
  final int warmupMinutes;                  // the warm-up block before the lifting, inside the minutes
  final bool skipCardio;                    // no cardio block today
  final bool skipStretch;                   // no stretching block today
  final List<String> order;                 // slots in the order the user arranged; the rest keep the builder's order after them
  final String? locationId;
  final Map<String, String> picks;          // slot -> exercise id
  final Map<String, int> rungOverrides;     // slot -> rung for today
  final List<String> muscles;               // muscle groups the user asked for by hand today, strained or not
  final Set<String> leftOut;                // slots the user left out today: the count drops by one
  final bool liftInstead;                   // lift today even though a movement day is due
  final String? moveKind;                   // swap to a movement session: cardio | mobility
  final String? routine;
  final String? cardio;
  final bool energyChosen;
  final bool timeChosen;
  final bool circuit;
}

Session buildSession(AppState s, BuildOptions o, DateTime now) {
  expirePauses(s, now);
  applyDecay(s, now);
  final g = s.goal!;
  final ps = personState(s, now);
  final loc = s.location(o.locationId);
  final equipment = loc?.equipment ?? const <String>[];
  const id = 'preview'; // the real id is assigned when the session starts
  final minutes = clampMinutes(o.minutes);

  final due = moveDue(s);
  if (o.moveKind != null || (due != null && !o.liftInstead)) {
    final kind = o.moveKind ?? due!;
    final routineId = o.routine ?? 'reset';
    final r = routines[routineId]!;
    return Session(
      id: id, type: 'move', kind: kind, name: kind == 'cardio' ? 'Cardio day' : r.name, locationId: loc?.id,
      energy: o.energy, timeMinutes: minutes, energyChosen: o.energyChosen, timeChosen: o.timeChosen, stateAtStart: ps.state,
      minutes: kind == 'cardio' ? minutes : null, routine: kind == 'mobility' ? routineId : null, cardio: kind == 'cardio' ? (o.cardio ?? 'any') : null,
      estMinutes: kind == 'cardio' ? minutes : (r.seconds / 60).ceil(),
    )..swappedToMove = due == null;
  }

  // 1. the window: the minutes, less the warm-up and the cardio and stretching shares. With no time limit the window
  //    is open and the count decides; cardio and stretching then keep their shares of whatever the lifting takes.
  final count = o.exerciseCount?.clamp(1, exercisesMax);
  final warmup = o.warmupMinutes.clamp(0, 30);
  var cardioMin = o.skipCardio ? 0 : (minutes * g.cardioPct / 100).round();
  var stretchMin = o.skipStretch ? 0 : (minutes * g.stretchPct / 100).round();
  final window = count != null ? _openWindow : max(0, minutes - cardioMin - stretchMin - warmup) * 60.0;

  // 2. the muscles, then an exercise for each (SELECTION.md). The user's own muscles first, strained or not; then the
  //    ready muscles furthest behind their share, emphasis first, as many as the ideal (or the count). One exercise per
  //    muscle until every ready muscle that is behind has one. The last place may go to something new.
  final sel = _Selection(s, now, MuscleMap(s).currentStrainPoints(now), shareOver(s, now), equipment);
  final ideal = count ?? g.exercises.ideal;
  final slots = <_Slot>[];
  final used = <String>[];
  final counts = <String, int>{};
  final blocked = <String>{};
  String slotKey(String grp) { counts[grp] = (counts[grp] ?? 0) + 1; return '$grp${counts[grp]}'; }
  for (final grp in o.muscles) {
    if (!muscleGroups.contains(grp)) continue;
    sel.planSlots(slots);
    final key = slotKey(grp);
    final pick = sel.bestFor(grp, used, o.picks[key]);
    if (pick == null) continue;
    final sl = _Slot(key, grp, slots.length)..pick = pick..asked = true..forced = !sel.ready(pick);
    if (o.leftOut.contains(key)) { blocked.add(grp); continue; }
    used.add(pick.id);
    slots.add(sl);
  }
  final explore = o.energy != Energy.hard;
  for (var guard = 0; guard < 20 && slots.length < max(ideal, min(slots.length, g.exercises.max)); guard++) {
    sel.planSlots(slots);
    sel.exploreGroup = null;
    final ranked = _rankedGroups(s, slots, used, blocked, sel);
    if (ranked.isEmpty) break;
    var next = ranked.first;
    var explored = false;
    // the last place: when the practised pick for this muscle has had its run, an unrated one takes a turn
    if (explore && slots.length == ideal - 1 && _practised(s, next.exercise) && runOf(s, next.group, next.exercise.id) >= exploreRun[g.explore]!) {
      sel.exploreGroup = next.group;
      final fresh = sel.bestFor(next.group, used, null);
      if (fresh != null && !_practised(s, fresh) && sel.ready(fresh) == sel.ready(next.exercise)) { next = (group: next.group, exercise: fresh); explored = true; }
      sel.exploreGroup = null;
    }
    final key = slotKey(next.group);
    final pick = o.picks.containsKey(key) ? (sel.bestFor(next.group, used, o.picks[key]) ?? next.exercise) : next.exercise;
    if (o.leftOut.contains(key)) { blocked.add(next.group); continue; }
    used.add(pick.id);
    slots.add(_Slot(key, next.group, slots.length)..pick = pick..explored = explored && pick.id == next.exercise.id);
  }

  // 3. the list is built once, at normal: the ideal sets everywhere, fitted to the minutes by the calibrations. A day is
  //    tight when the ideal list does not fit, long when it fills no more than half the window. Spare minutes grow the
  //    list back to the ideal; on a long day or a hard day, sets then exercises grow on to the most.
  for (final sl in slots) { sl.intent = intentWorking; sl.sets = g.sets.ideal; }
  final idealSeconds = _totalSeconds(s, slots);
  final dropped = _fitTime(s, slots, window, g);
  final tight = dropped.isNotEmpty || slots.any((x) => x.sets < g.sets.ideal);
  final longDay = count == null && !tight && idealSeconds <= window * longWindowShare;
  if (count != null) {
    // no time limit: exactly the count, the last on the list going first, then the same growth order as spare minutes
    while (slots.length > count) {
      final byPriority = slots.toList()..sort((a, b) => b.priority.compareTo(a.priority));
      slots.remove(byPriority.first);
      dropped.insert(0, byPriority.first);
    }
    _grow(s, slots, window, count, g.sets.ideal, dropped, blocked, sel);
  } else if (g.spare == Spare.exercises) {
    _grow(s, slots, window, max(g.exercises.ideal, slots.length), g.sets.ideal, dropped, blocked, sel);
    if (o.energy == Energy.hard || (longDay && o.energy != Energy.easy)) {
      _growSets(s, slots, window, g.sets.max);
      _grow(s, slots, window, g.exercises.max, g.sets.ideal, dropped, blocked, sel);
    }
  }
  // 4. the dials. A hard day pushes the fewest exercises when tight, the ideal usually, the most on a long day. An easy
  //    day keeps full sets and fewer exercises: the last light ones go until the lifting fits a smaller window, never
  //    below the fewest, so what is left is few exercises done properly rather than many done thinly.
  final pushes = (tight ? g.pushes.min : longDay ? g.pushes.max : g.pushes.ideal).clamp(0, slots.length);
  _turnDials(s, slots, o.energy, g, pushes);
  final listedAtNormal = slots.length;
  if (o.energy == Energy.easy && count == null) {
    final easyWindow = window * easyWindowShare;
    for (var guard = 0; guard < 20 && slots.length > max(1, g.exercises.min) && _totalSeconds(s, slots) > easyWindow; guard++) {
      final byPriority = slots.toList()..sort((a, b) => b.priority.compareTo(a.priority));
      final victim = byPriority.where((x) => x.intent == intentLight).firstOrNull ?? byPriority.first;
      slots.remove(victim);
    }
  }
  final liftIndex = s.sessions.where((x) => x.type == 'lift').length;
  final usedSeconds = _totalSeconds(s, slots);
  var spareMin = 0;
  if (count != null) {
    // cardio and stretching keep their shares of the whole, whatever the lifting takes
    final rest = 1 - (g.cardioPct + g.stretchPct) / 100;
    final whole = (usedSeconds / 60 + warmup) / (rest <= 0.2 ? 0.2 : rest);
    cardioMin = o.skipCardio ? 0 : (whole * g.cardioPct / 100).round();
    stretchMin = o.skipStretch ? 0 : (whole * g.stretchPct / 100).round();
  } else {
    final slack = ((window - usedSeconds) / 60).floor();
    if (slack > 0 && slots.isNotEmpty) {
      if (g.spare == Spare.rest || o.skipCardio) { spareMin = slack; } else { cardioMin += slack; }
    }
  }

  // 6. order: emphasised muscles first, where strength lands; then hardest first while the user is fresh; at the same
  //    difficulty, extra and working before light
  slots.sort((a, b) {
    final e = g.emphasisOf(b.group).compareTo(g.emphasisOf(a.group));
    if (e != 0) return e;
    final c = _difficulty(s, b.pick!).compareTo(_difficulty(s, a.pick!));
    if (c != 0) return c;
    final t = _tier(a.intent).compareTo(_tier(b.intent));
    return t != 0 ? t : a.priority.compareTo(b.priority);
  });

  // the exercise entries
  final lightenHard = ps.state == PersonState.away;
  final out = <SessionExercise>[];
  final current = sel.current;
  for (final sl in slots) {
    final ex = sl.pick!;
    final st = ensureState(s, ex);
    final difficulty = difficultyInPlay(ex, st);
    final light = sl.intent == intentLight;
    final range = todayRange(s, ex, liftIndex: liftIndex);
    var rung = effectiveRung(ex, st, equipment);
    final c = ceilingFor(ex, equipment);
    var lightened = false;
    var nextLevel = false;
    // light on a bodyweight exercise is one version down; on a loaded one the weight is a share of the usual (below)
    if (light && !ex.loaded) rung = max(0, rung - 1);
    // hard: the next level on every set, unless this is the top version here
    if (sl.intent == intentExtra && !(c != null && rung >= c)) { rung += 1; nextLevel = true; }
    if (lightenHard && difficulty >= 3 && !light && !nextLevel) { rung = max(ex.loaded ? floorRung(s, ex, st) : 0, rung - 1); lightened = true; }
    var edited = false;
    if (o.rungOverrides.containsKey(sl.slot)) { rung = o.rungOverrides[sl.slot]!; edited = true; nextLevel = false; }
    final ceilingToday = c != null && st.rung >= c && rung == st.rung && !light;
    int target;
    if (ceilingToday && st.bestTotal > 0) {
      target = max(range.lo, ((st.bestTotal + 1) / sl.sets).ceil());
    } else {
      target = range.hi;
    }
    final usual = ex.loaded ? loadFor(s, ex, st, st.rung, range) : null;
    var load = ex.loaded ? loadFor(s, ex, st, rung, range) : null;
    if (light && ex.loaded) load = max(stepKg(s, ex), roundStep(usual! * easyShare, stepKg(s, ex)));
    final label = ex.loaded ? fmtLoad(s, ex, load!, equipment: equipment) : rungLabel(s, ex, st, rung, range, equipment);
    // today's work against the usual: sets against the working sets, times the weight share (or one version down), times the reserve
    var relative = sl.sets / g.sets.ideal;
    if (light) relative *= (ex.loaded ? easyShare : 0.85) * 0.9;
    if (nextLevel) relative *= 1.1;
    final fresh = sl.explored;
    final why = whyLine(
      group: sl.group, ready: ex.primary.every(current.strainFree), band: sel.share.band(sl.group), emphasis: g.emphasisOf(sl.group),
      preference: preferenceOf(st, now), fresh: fresh, asked: sl.asked,
    );
    out.add(SessionExercise(
      slot: sl.slot, exId: ex.id, muscle: sl.group, intent: sl.intent, workingSets: min(sl.sets, g.sets.ideal), rung: rung, rungLabel: label,
      target: target, lo: range.lo, hi: range.hi, atCeiling: ceilingToday, bestTotal: st.bestTotal, difficulty: difficulty, loadKg: load,
      secPerSet: st.secPerSet, sets: List.generate(sl.sets, (_) => SetLog()), warmups: ex.loaded && difficulty >= 3 ? warmupsFor(s, ex, load!) : const [],
      edited: edited, lightened: lightened, why: why, fresh: fresh, asked: sl.asked,
    )..relative = relative..nextLevel = nextLevel..usualLoadKg = usual);
  }
  final weight = out.fold(0, (a, e) => a + e.difficulty);
  final relative = (weight == 0 ? 1.0 : out.fold(0.0, (a, e) => a + e.relative * e.difficulty) / weight) * (listedAtNormal == 0 ? 1 : out.length / listedAtNormal);
  // the user's own order, when they moved exercises on the plan
  if (o.order.isNotEmpty) {
    int rank(SessionExercise e) { final i = o.order.indexOf(e.slot); return i < 0 ? o.order.length : i; }
    final builderOrder = [...out];
    out.sort((a, b) { final c = rank(a).compareTo(rank(b)); return c != 0 ? c : builderOrder.indexOf(a).compareTo(builderOrder.indexOf(b)); });
  }

  return Session(
    id: id, type: 'lift', name: workoutName(out), locationId: loc?.id, energy: o.energy, timeMinutes: minutes,
    energyChosen: o.energyChosen, timeChosen: o.timeChosen, stateAtStart: ps.state, exercises: out,
    estMinutes: (usedSeconds / 60).round() + (out.isEmpty ? 0 : cardioMin + stretchMin + warmup), cardioMinutes: out.isEmpty ? 0 : cardioMin,
    stretchMinutes: out.isEmpty ? 0 : stretchMin, spareMinutes: spareMin, circuit: o.circuit, warmupMinutes: out.isEmpty ? 0 : warmup,
  )..relative = relative..pushes = out.where((e) => e.nextLevel).length;
}

/// A workout's name: the first two muscles it works, "Back and chest".
String workoutName(List<SessionExercise> out) {
  final groups = <String>[];
  for (final e in out) { if (!groups.contains(e.muscle)) groups.add(e.muscle); }
  if (groups.isEmpty) return 'Workout';
  if (groups.length == 1) return groups.first;
  return '${groups[0]} and ${groups[1].toLowerCase()}';
}

/// Seconds one exercise is planned to take, rest after its sets included: what the plan shows beside it.
double plannedSeconds(SessionExercise e) => e.secPerSet * e.sets.length + changeSeconds + (e.warmups.isNotEmpty ? warmupSetsSeconds : 0);

/// Words for a relative load: how today compares with the usual working level.
String relativeLabel(double r) => r < 0.95 ? 'lighter' : r > 1.05 ? 'more' : 'usual';

/// Alternatives for one slot: the same muscle, available here, not already in the session; in selection's order against
/// the rest of the workout. Not for me ones come last; the sheet lists them under their own heading.
List<Exercise> alternatives(AppState s, Session session, int idx, Iterable<String> equipment, DateTime now) {
  final e = session.exercises[idx];
  final sel = _selectionBeside(s, session, idx, equipment, now);
  return candidatesFor(s, e.muscle, equipment, session.exercises.map((x) => x.exId), now)..sort((a, b) => sel.compare(a, b));
}

/// Selection for one slot of a built workout: the current strain points, plus every other exercise's.
_Selection _selectionBeside(AppState s, Session session, int idx, Iterable<String> equipment, DateTime now) =>
    _Selection(s, now, MuscleMap(s).currentStrainPoints(now), shareOver(s, now), equipment)
      ..plan([
        for (var i = 0; i < session.exercises.length; i++)
          if (i != idx) (exercise: session.exercises[i].exercise, sets: session.exercises[i].sets.length, light: session.exercises[i].intent == intentLight),
      ]);

/// Random fresh picks for every slot, from the top few alternatives by selection's order, never a not-for-me one.
Map<String, String> shufflePicks(AppState s, Session session, Iterable<String> equipment, Random rng, DateTime now) {
  final picks = <String, String>{};
  final used = <String>[];
  for (var i = 0; i < session.exercises.length; i++) {
    final e = session.exercises[i];
    final sel = _selectionBeside(s, session, i, equipment, now);
    final alts = candidatesFor(s, e.muscle, equipment, [...used, e.exId], now)..sort((a, b) => sel.compare(a, b));
    final ranked = (alts.isEmpty ? candidatesFor(s, e.muscle, equipment, used, now) : alts).where((x) => sel.pref(x) != prefNo).toList();
    final ready = ranked.where(sel.ready).toList();
    final pool = (ready.isEmpty ? ranked : ready).take(4).toList();
    final pick = pool.isEmpty ? e.exercise : pool[rng.nextInt(pool.length)];
    picks[e.slot] = pick.id;
    used.add(pick.id);
  }
  return picks;
}

/// Estimated minutes for a session as planned: the warm-up, the lifting, then the cardio and stretching blocks.
int estimateMinutes(Session session) {
  if (session.type == 'move') return session.estMinutes;
  final secs = session.exercises.fold(0.0, (a, e) => a + plannedSeconds(e));
  return (secs / 60).round() + session.warmupMinutes + session.cardioMinutes + session.stretchMinutes;
}
