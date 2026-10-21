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
import 'muscle_plan.dart';
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
  _Selection(this.s, this.now, this.current, this.rhythm, this.equipment, {this.muscleSeed, this.exerciseSeed, this.avoid = const {}, Iterable<String>? forced})
      : withPlan = current,
        actives = [for (final m in trackedMuscles) if (s.goal!.tagOf(m) == MuscleTag.active || (forced?.contains(m) ?? false)) m],
        passives = [for (final m in trackedMuscles) if (s.goal!.tagOf(m) == MuscleTag.passive) m];
  final AppState s;
  /// Draw again's seeds (SELECTION.md, "Shuffling"): with [muscleSeed] the ready muscles are drawn weighted by overdue
  /// instead of taken in turn; with [exerciseSeed] a draw replaces practised and library rank. Each draw is fixed by
  /// the seed and the name, so the engine's repeated passes see the same order.
  final int? muscleSeed;
  final int? exerciseSeed;
  /// Today's excluded muscles: no candidate may have one among its primary muscles.
  final Set<String> avoid;
  /// The muscles that get places: the active ones, and any forced today. The passive ones steer exercise choice.
  final List<String> actives;
  final List<String> passives;
  /// How many places the workout has, for the size of the muscle draw's pool.
  int places = 4;
  final DateTime now;
  final StrainPoints current;
  final Rhythm rhythm;
  final Iterable<String> equipment;
  StrainPoints withPlan;
  /// The muscle an unrated exercise may take a turn for today, if any.
  String? exploreMuscle;

  /// Every primary muscle of [e] strain-free, counting today's plan so far.
  bool ready(Exercise e) => e.primary.every(withPlan.strainFree);

  /// The shade [e]'s most strained primary muscle sits at, with today's plan so far added.
  int shade(Exercise e) => withPlan.highestShade(e.primary);

  String? pref(Exercise e) => preferenceOf(s.ex[e.id], now);

  /// A draw from 0 to 1 fixed by [seed] and [key].
  double draw(String key, int seed) {
    var h = seed * 7919 + 17;
    for (final c in key.codeUnits) { h = (h * 31 + c) & 0x3fffffff; }
    return Random(h).nextDouble();
  }

  /// The passive muscles [e] works or helps, the most overdue first; what the exercise "helps".
  List<String> helpsOf(Exercise e) {
    final out = [for (final m in [...e.primary, ...e.secondary]) if (passives.contains(m) && !avoid.contains(m)) m]
      ..sort((a, b) => rhythm.helpedSinceOf(b).compareTo(rhythm.helpedSinceOf(a)));
    return out.take(2).toList();
  }

  /// How overdue the most overdue passive muscle [e] helps is.
  int helpScore(Exercise e) => helpsOf(e).fold(0, (a, m) => max(a, rhythm.helpedSinceOf(m)));

  /// Ready first, then the lowest shade, then liked, fine and unrated, not for me (an unrated one above fine when it is
  /// this muscle's turn for something new), then practised, then library rank.
  int compare(Exercise a, Exercise b, {String? muscle}) {
    return compareCover(a, b, muscle ?? '', const {}, const {});
  }

  /// Today's plan so far: the current strain points plus the strain points from workout of [plan].
  void plan(Iterable<({Exercise exercise, int sets, bool light})> plan) => withPlan = current.plus(strainPointsFromPlan(plan));

  void planSlots(Iterable<_Slot> slots) => plan([
        for (final x in slots) if (x.pick != null) (exercise: x.pick!, sets: x.sets == 0 ? 1 : x.sets, light: x.intent == intentLight),
      ]);

  /// The best exercise for a muscle: the user's pick for the slot, else the first by [compare]. A [forced] muscle that
  /// only has candidates working an excluded muscle too takes one of those rather than nothing.
  Exercise? bestFor(String muscle, Iterable<String> used, String? pref, {bool forced = false}) {
    var cands = candidatesFor(s, muscle, equipment, used, now, avoid: avoid);
    if (cands.isEmpty && forced) cands = candidatesFor(s, muscle, equipment, used, now);
    if (cands.isEmpty) return null;
    if (pref != null) {
      final p = cands.where((e) => e.id == pref).firstOrNull;
      if (p != null) return p;
    }
    cands.sort((a, b) => compare(a, b, muscle: muscle));
    return cands.first;
  }

  /// The order of exercises for a place (SELECTION.md, "Which exercise"): ready, then the lowest shade; not for me last;
  /// the most requirements still [waiting] covered, then the fewest already [covered] worked again; liked before fine
  /// and unrated (an unrated one above fine on its turn for something new); the most overdue passive muscle helped;
  /// then a draw with the exercise seed, else practised here, then library rank.
  int compareCover(Exercise a, Exercise b, String muscle, Set<String> waiting, Set<String> covered) {
    final ra = ready(a), rb = ready(b);
    if (ra != rb) return ra ? -1 : 1;
    final c = shade(a).compareTo(shade(b));
    if (c != 0) return c;
    final na = pref(a) == prefNo, nb = pref(b) == prefNo;
    if (na != nb) return na ? 1 : -1;
    int gain(Exercise e) => e.primary.where((m) => m != muscle && waiting.contains(m)).length;
    int overlap(Exercise e) => e.primary.where(covered.contains).length;
    final gn = gain(b).compareTo(gain(a));
    if (gn != 0) return gn;
    final ov = overlap(a).compareTo(overlap(b));
    if (ov != 0) return ov;
    final p = preferenceRank(pref(a)).compareTo(preferenceRank(pref(b)));
    if (p != 0) return p;
    final h = helpScore(b).compareTo(helpScore(a));
    if (h != 0) return h;
    if (muscle == exploreMuscle) {
      final freshA = pref(a) == null, freshB = pref(b) == null;
      if (freshA != freshB) return freshA ? -1 : 1;
    }
    if (exerciseSeed != null) return draw(a.id, exerciseSeed!).compareTo(draw(b.id, exerciseSeed!));
    final pa = _practised(s, a), pb = _practised(s, b);
    if (pa != pb) return pa ? -1 : 1;
    return a.rank.compareTo(b.rank);
  }

  /// The best exercise for [muscle] while a list of muscles is being covered (the engine): the user's pick for the
  /// place, else the first by [compareCover]. A [forced] muscle that only has candidates working an excluded muscle
  /// too takes one of those rather than nothing.
  Exercise? coverPick(String muscle, Set<String> waiting, Set<String> covered, Iterable<String> used, String? userPick, {bool forced = false}) {
    var cands = candidatesFor(s, muscle, equipment, used, now, avoid: avoid);
    if (cands.isEmpty && forced) cands = candidatesFor(s, muscle, equipment, used, now);
    if (cands.isEmpty) return null;
    if (userPick != null) {
      final p = cands.where((e) => e.id == userPick).firstOrNull;
      if (p != null) return p;
    }
    cands.sort((a, b) => compareCover(a, b, muscle, waiting, covered));
    return cands.first;
  }

  /// What an exercise brings to a place, for the swap sheet: what else it covers, the word, what it helps, new to you.
  String reasonFor(Exercise e, String muscle, Set<String> waiting, Set<String> covered) {
    final parts = <String>[];
    final covers = e.primary.where((m) => m != muscle && waiting.contains(m)).toList();
    if (covers.isNotEmpty) parts.add('also covers ${listWords(covers)}');
    final again = e.primary.where((m) => m != muscle && covered.contains(m)).toList();
    if (again.isNotEmpty) parts.add('works ${listWords(again)} again');
    final w = pref(e);
    if (w == prefLiked) parts.add('liked');
    if (w == prefNo) parts.add('not for me');
    final helps = helpsOf(e);
    if (helps.isNotEmpty) parts.add('helps ${listWords(helps)}');
    if (!_practised(s, e) && w == null) parts.add('new to you');
    if (!ready(e)) parts.add('carrying strain');
    return parts.join(' · ');
  }

  /// Muscles in the order selection takes them (SELECTION.md, "Whose turn it is"): those with a ready candidate first,
  /// then the most overdue, then more often, then the selection order. With the muscle seed, the ready ones in the
  /// pool (two workouts' worth) are drawn weighted toward the more overdue, and the rest follow in turn order.
  List<String> rankMuscles(Iterable<String> muscles, Map<String, Exercise> candidates) {
    final list = muscles.where(candidates.containsKey).toList();
    list.sort((a, b) {
      final ra = ready(candidates[a]!), rb = ready(candidates[b]!);
      if (ra != rb) return ra ? -1 : 1;
      final oa = rhythm.overdue(a), ob = rhythm.overdue(b);
      if ((oa - ob).abs() > 1e-9) return ob.compareTo(oa);
      final fa = rhythm.factor[a] ?? 1, fb = rhythm.factor[b] ?? 1;
      if (fa != fb) return fb.compareTo(fa);
      return selectionOrder.indexOf(a).compareTo(selectionOrder.indexOf(b));
    });
    final seed = muscleSeed;
    if (seed == null) return list;
    final readyOnes = list.where((m) => ready(candidates[m]!) && rhythm.due(m)).toList();
    final pool = readyOnes.take(2 * places).toList();
    final rest = list.where((m) => !pool.contains(m)).toList();
    // weighted sampling without replacement: an exponential key per muscle, the heavier the overdue the sooner
    double key(String m) => -log(1 - draw(m, seed) * 0.999999) / (rhythm.overdue(m) + 1);
    pool.sort((a, b) => key(a).compareTo(key(b)));
    return [...pool, ...rest];
  }
}

class _Slot {
  _Slot(this.slot, this.muscle, this.priority);
  final String slot;
  final String muscle;
  final int priority;   // the order selection took it: lower gets the work first and loses it last
  Exercise? pick;
  String intent = intentWorking;
  int sets = 0;
  bool asked = false;   // the user asked for this muscle by hand
  bool forced = false;  // asked for while still carrying strain
  bool explored = false; // an unrated exercise took its turn here
  List<String> covers = const [];  // other requirements this pick covered
  List<String> helps = const [];   // passive muscles this pick helps
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
      for (final cand in _rankedMuscles(s, slots, used, blocked, sel)) {
        final sl = _Slot('${cand.muscle}x${added + 1}', cand.muscle, 100 + added)..pick = cand.exercise..intent = intentWorking..sets = sets;
        if (_seconds(s, sl) <= secsLeft) { next = sl; break; }
      }
    }
    if (next == null) break;
    slots.add(next);
    added++;
  }
}

/// The muscles in the order selection takes them, each with its exercise: untaken muscles while one of them is
/// ready and behind, otherwise any muscle; a muscle already in the plan takes a second exercise only then.
List<({String muscle, Exercise exercise})> _rankedMuscles(AppState s, List<_Slot> slots, List<String> used, Set<String> blocked, _Selection sel) {
  final taken = _covered(slots);
  final best = <String, Exercise>{};
  for (final mus in sel.actives) {
    if (blocked.contains(mus)) continue;
    final e = sel.bestFor(mus, used, null);
    if (e != null) best[mus] = e;
  }
  if (best.isEmpty) return const [];
  final untaken = best.keys.where((g) => !taken.contains(g));
  final pool = untaken.any((g) => sel.ready(best[g]!)) ? untaken : best.keys;
  return [for (final g in sel.rankMuscles(pool, best)) (muscle: g, exercise: best[g]!)];
}

/// The muscles [slots] work as a main muscle.
Set<String> _covered(Iterable<_Slot> slots) => {for (final x in slots) ...x.pick!.primary};

/// The exercises that cover [req], the most important muscle first: each muscle no exercise chosen so far works as a
/// main muscle gets the best exercise for it by [_Selection.coverPick], which prefers one that works other waiting
/// muscles too. A muscle covered on the way takes no place of its own. A place is keyed by the muscle it was taken for.
List<_Slot> _cover(List<String> req, Set<String> forced, _Selection sel, Map<String, String> picks) {
  final slots = <_Slot>[];
  final covered = <String>{};
  // A hand-picked exercise owns its place even if another exercise could cover its muscle.
  for (final entry in picks.entries) {
    final m = entry.key.replaceFirst(RegExp(r'[0-9x]+$'), '');
    if (!req.contains(m)) continue;
    sel.planSlots(slots);
    final pick = sel.bestFor(m, slots.map((x) => x.pick!.id), entry.value, forced: forced.contains(m));
    if (pick == null || pick.id != entry.value) continue;
    slots.add(_Slot(entry.key, m, slots.length)..pick = pick..asked = forced.contains(m)..helps = sel.helpsOf(pick));
    covered.addAll(pick.primary);
  }
  for (final m in req) {
    if (covered.contains(m)) continue;
    sel.planSlots(slots);
    final key = '${m}1';
    final waiting = {for (final r in req) if (!covered.contains(r)) r};
    final f = forced.contains(m);
    final pick = sel.coverPick(m, waiting, covered, [for (final x in slots) x.pick!.id], picks[key], forced: f);
    if (pick == null) continue;
    slots.add(_Slot(key, m, slots.length)
      ..pick = pick..asked = f..forced = f && !sel.ready(pick)
      ..covers = [for (final c in pick.primary) if (c != m && waiting.contains(c)) c]
      ..helps = sel.helpsOf(pick));
    covered.addAll(pick.primary);
  }
  return slots;
}

/// The engine (SELECTION.md): the muscle requirements, then the exercises that meet them. The requirements start with
/// the forced muscles, in the user's order. Then one available muscle at a time joins, by the selection rules and
/// re-ranked against the list so far, for as long as the exercises covering every requirement number no more than
/// [limit]; each time the cover is worked out again from the start, so a later muscle can turn an earlier pick into
/// one exercise that works both. A muscle the list already works as a main muscle joins at no cost. Places still
/// free once nothing more fits go to a second exercise for the muscles, in the same order. Manual stops at the forced
/// muscles.
({List<String> req, List<_Slot> slots}) _engine(List<String> forcedList, Set<String> blocked, int limit, bool manual, _Selection sel, Map<String, String> picks, {List<String>? requirements}) {
  final forced = forcedList.toSet();
  final req = <String>{...forcedList, ...?requirements,
    for (final key in picks.keys) key.replaceFirst(RegExp(r'[0-9x]+$'), ''),
  }.where((m) => trackedMuscles.contains(m) && (!blocked.contains(m) || forced.contains(m))).toList();
  var slots = _cover(req, forced, sel, picks);
  if (manual || requirements != null) return (req: req, slots: slots);
  void freeRiders() {
    final covered = _covered(slots);
    for (final m in sel.actives) {
      if (covered.contains(m) && !req.contains(m) && !blocked.contains(m)) req.add(m);
    }
  }
  final tried = <String>{};
  for (var guard = 0; guard <= trackedMuscles.length; guard++) {
    freeRiders();
    if (slots.length >= limit) break;
    sel.planSlots(slots);
    final used = [for (final x in slots) x.pick!.id];
    final best = <String, Exercise>{};
    for (final m in sel.actives) {
      if (req.contains(m) || blocked.contains(m) || tried.contains(m)) continue;
      final e = sel.bestFor(m, used, null);
      if (e != null) best[m] = e;
    }
    String? added;
    for (final m in sel.rankMuscles(best.keys, best)) {
      final trial = _cover([...req, m], forced, sel, picks);
      if (trial.length <= limit && _covered(trial).contains(m)) { req.add(m); slots = trial; added = m; break; }
      tried.add(m);
    }
    if (added == null) break;
  }
  freeRiders();
  final counts = <String, int>{};
  for (var guard = 0; guard < 20 && slots.length < limit; guard++) {
    sel.planSlots(slots);
    final used = [for (final x in slots) x.pick!.id];
    final best = <String, Exercise>{};
    for (final m in req) {
      if (blocked.contains(m)) continue;
      final e = sel.bestFor(m, used, null);
      if (e != null) best[m] = e;
    }
    final ranked = sel.rankMuscles(best.keys, best);
    if (ranked.isEmpty) break;
    final m = ranked.first;
    counts[m] = (counts[m] ?? 1) + 1;
    final key = '$m${counts[m]}';
    final pick = picks.containsKey(key) ? (sel.bestFor(m, used, picks[key]) ?? best[m]!) : best[m]!;
    slots.add(_Slot(key, m, slots.length)..pick = pick..asked = forced.contains(m));
  }
  return (req: req, slots: slots);
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
    this.muscles = const [], this.excluded = const {}, this.leftOut = const {}, this.liftInstead = false, this.muscleSeed, this.exerciseSeed, this.manual = false, this.requirements,
  });

  BuildOptions copyWith({int? muscleSeed, int? exerciseSeed, bool clearSeeds = false, bool baseline = false}) => BuildOptions(
        energy: energy, minutes: minutes, locationId: locationId, picks: baseline ? const {} : picks, rungOverrides: rungOverrides, moveKind: moveKind, routine: routine,
        cardio: cardio, energyChosen: energyChosen, timeChosen: timeChosen, circuit: circuit, exerciseCount: exerciseCount, warmupMinutes: warmupMinutes,
        skipCardio: skipCardio, skipStretch: skipStretch, order: order, muscles: muscles, excluded: excluded, leftOut: leftOut, liftInstead: liftInstead,
        muscleSeed: clearSeeds ? null : muscleSeed ?? this.muscleSeed, exerciseSeed: clearSeeds || baseline ? null : exerciseSeed ?? this.exerciseSeed, manual: manual,
        requirements: baseline || muscleSeed != null ? null : requirements,
      );
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
  final List<String> muscles;               // muscles forced today (the muscle plan), strained or not, in the user's order
  final Set<String> excluded;               // muscles excluded today: never a place, and no exercise works one as a main muscle
  final int? muscleSeed;                    // Draw again, muscles: the ready muscles drawn weighted by overdue instead of in turn
  final int? exerciseSeed;                  // Draw again, exercises: a draw in place of practised and library rank
  final bool manual;                        // only the forced muscles: nothing else takes a place, not even spare minutes
  final List<String>? requirements;         // frozen when swapping or shuffling exercises; muscle shuffles clear it
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

  // 2. the engine (SELECTION.md): the muscles to work, then exercises whose main muscles cover them all. The forced
  //    muscles first, strained or not; then the ready muscles furthest behind their share, emphasis first, as many as
  //    the ideal number of exercises (or the count) can cover. A place the user left out today takes its muscle off the
  //    list and the count down by one. The last place may go to something new.
  final requirements = o.requirements ?? (o.exerciseSeed != null || o.picks.isNotEmpty
      ? buildSession(s, o.copyWith(baseline: true), now).requirements : null);
  final sel = _Selection(s, now, MuscleMap(s).currentStrainPoints(now), rhythmOver(s, now), equipment,
      muscleSeed: o.muscleSeed, exerciseSeed: o.exerciseSeed, avoid: o.excluded, forced: o.muscles);
  final ideal = count ?? g.exercises.ideal;
  sel.places = ideal;
  final blocked = <String>{...o.excluded, if (o.manual) ...trackedMuscles.where((m) => !o.muscles.contains(m))};
  final forcedAll = [for (final m in o.muscles) if (trackedMuscles.contains(m)) m];
  final outMuscles = <String>{};
  var outCount = 0;
  var built = (req: <String>[], slots: <_Slot>[]);
  for (var pass = 0; pass < 4; pass++) {
    final forcedNow = [for (final m in forcedAll) if (!outMuscles.contains(m)) m];
    final forcedCover = _cover(forcedNow, forcedNow.toSet(), sel, o.picks).length;
    final limit = max(0, max(ideal, min(forcedCover, g.exercises.max)) - outCount);
    built = _engine(forcedNow, blocked, limit, o.manual, sel, o.picks, requirements: requirements);
    final out = [for (final x in built.slots) if (o.leftOut.contains(x.slot)) x];
    if (out.isEmpty) break;
    for (final x in out) { blocked.add(x.muscle); outMuscles.add(x.muscle); }
    outCount += out.length;
  }
  final slots = [for (final x in built.slots) if (!o.leftOut.contains(x.slot)) x];
  final requiredSet = built.req.toSet();
  if (requirements != null) blocked.addAll(trackedMuscles.where((m) => !requiredSet.contains(m)));
  // the last place: when the practised pick for its muscle has had its run, an unrated one takes a turn, so long as it
  // still works every forced muscle the practised one did
  final explore = o.energy != Energy.hard;
  if (explore && ideal >= 1 && slots.length >= ideal) {
    final last = slots[ideal - 1];
    if (!last.asked && !o.picks.containsKey(last.slot) && _practised(s, last.pick!) && runOf(s, last.muscle, last.pick!.id) >= exploreRun[g.explore]!) {
      sel.planSlots(slots.where((x) => x != last));
      sel.exploreMuscle = last.muscle;
      final keep = last.pick!.primary.where(requiredSet.contains).toSet();
      final cands = candidatesFor(s, last.muscle, equipment, [for (final x in slots) x.pick!.id], now, avoid: o.excluded)
          .where((e) => keep.every(e.primary.contains)).toList()
        ..sort((a, b) => sel.compare(a, b, muscle: last.muscle));
      final fresh = cands.firstOrNull;
      if (fresh != null && !_practised(s, fresh) && sel.ready(fresh) == sel.ready(last.pick!)) { last.pick = fresh; last.explored = true; }
      sel.exploreMuscle = null;
    }
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
    if (!o.manual) _grow(s, slots, window, count, g.sets.ideal, dropped, blocked, sel);
  } else if (g.spare == Spare.exercises && !o.manual) {
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
    final e = g.oftenOf(b.muscle).compareTo(g.oftenOf(a.muscle));
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
      asked: sl.asked, ready: ex.primary.every(current.strainFree), due: sel.rhythm.dueText(sl.muscle), covers: sl.covers,
      preference: preferenceOf(st, now), helps: sl.helps, fresh: fresh, drawn: o.exerciseSeed != null || o.muscleSeed != null,
    );
    out.add(SessionExercise(
      slot: sl.slot, exId: ex.id, muscle: sl.muscle, intent: sl.intent, workingSets: min(sl.sets, g.sets.ideal), rung: rung, rungLabel: label,
      target: target, lo: range.lo, hi: range.hi, atCeiling: ceilingToday, bestTotal: st.bestTotal, difficulty: difficulty, loadKg: load,
      secPerSet: st.secPerSet, sets: List.generate(sl.sets, (_) => SetLog()), warmups: ex.loaded && difficulty >= 3 ? warmupsFor(s, ex, load!) : const [],
      edited: edited, lightened: lightened, why: why, fresh: fresh, asked: sl.asked,
    )..relative = relative..nextLevel = nextLevel..usualLoadKg = usual);
  }
  final weight = out.fold(0, (a, e) => a + e.difficulty);
  // Compute this after fitting time and energy: a truncated plan must not silently lose a requirement.
  final coveredNow = {for (final e in out) ...e.exercise.primary};
  // Ordinary automatic choices become requirements only once they fit. Explicit requirements from a
  // force, swap or draw remain promises even if the time budget cannot hold them.
  final promised = requirements != null ? requiredSet : <String>{
    ...forcedAll,
    for (final m in coveredNow) if (sel.actives.contains(m) && !blocked.contains(m)) m,
  };
  final uncovered = [for (final m in promised) if (!outMuscles.contains(m) && !coveredNow.contains(m)) m];
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
  )..relative = relative..pushes = out.where((e) => e.nextLevel).length..uncovered = uncovered
   ..requirements = [for (final m in promised) if (!outMuscles.contains(m)) m];
}

/// A workout's name: every muscle it works as a main muscle, in order, as a day: "Chest day", "Lats and biceps day",
/// "Upper back, triceps and forearms day".
String workoutName(List<SessionExercise> out) => dayName(workedInOrder(out));

/// Every muscle the exercises work as a main muscle, in the order they come up.
List<String> workedInOrder(Iterable<SessionExercise> out) {
  final muscles = <String>[];
  for (final e in out) {
    for (final m in e.exercise.primary) { if (!muscles.contains(m)) muscles.add(m); }
  }
  return muscles;
}

/// Seconds one exercise is planned to take, rest after its sets included: what the plan shows beside it.
double plannedSeconds(SessionExercise e) => e.secPerSet * e.sets.length + changeSeconds + (e.warmups.isNotEmpty ? warmupSetsSeconds : 0);

/// Words for a relative load: how today compares with the usual working level.
String relativeLabel(double r) => r < 0.95 ? 'lighter' : r > 1.05 ? 'more' : 'usual';

/// An alternative for a place, with what it brings.
class Alternative {
  const Alternative(this.exercise, this.reason);
  final Exercise exercise;
  final String reason;
}

/// Alternatives for one place: the same muscle, available here, not already in the workout; in the cover's order
/// against the rest of the workout, each with its reason. The muscles only this place's exercise covers are what an
/// alternative is asked to keep covering. Not for me ones come last; the sheet lists them under their own heading.
List<Alternative> alternativesFor(AppState s, Session session, int idx, Iterable<String> equipment, DateTime now, {Set<String> avoid = const {}}) {
  final e = session.exercises[idx];
  final sel = _selectionBeside(s, session, idx, equipment, now);
  final covered = {for (var i = 0; i < session.exercises.length; i++) if (i != idx) ...session.exercises[i].exercise.primary};
  final waiting = {for (final m in e.exercise.primary) if (!covered.contains(m)) m};
  final cands = candidatesFor(s, e.muscle, equipment, session.exercises.map((x) => x.exId), now, avoid: avoid)
    ..sort((a, b) => sel.compareCover(a, b, e.muscle, waiting, covered));
  return [for (final a in cands) Alternative(a, sel.reasonFor(a, e.muscle, waiting, covered))];
}

List<Exercise> alternatives(AppState s, Session session, int idx, Iterable<String> equipment, DateTime now, {Set<String> avoid = const {}}) =>
    [for (final a in alternativesFor(s, session, idx, equipment, now, avoid: avoid)) a.exercise];

/// Selection for one place of a built workout: the current strain points, plus every other exercise's.
_Selection _selectionBeside(AppState s, Session session, int idx, Iterable<String> equipment, DateTime now) =>
    _Selection(s, now, MuscleMap(s).currentStrainPoints(now), rhythmOver(s, now), equipment)
      ..plan([
        for (var i = 0; i < session.exercises.length; i++)
          if (i != idx) (exercise: session.exercises[i].exercise, sets: session.exercises[i].sets.length, light: session.exercises[i].intent == intentLight),
      ]);

/// The next exercise seed that changes the workout: the cover run again with a draw in place of practised and library
/// rank, so coverage holds (SELECTION.md, "Shuffling"). Seeds that give the same exercises are skipped, a dozen at most.
int nextExerciseSeed(AppState s, BuildOptions o, DateTime now) {
  Set<String> ids(Session x) => {for (final e in x.exercises) e.exId};
  final before = buildSession(s, o, now);
  final current = ids(before);
  final keep = before.requirements.where((m) => !before.uncovered.contains(m)).toSet();
  var seed = o.exerciseSeed ?? 0;
  for (var i = 0; i < 12; i++) {
    seed++;
    final drawn = buildSession(s, o.copyWith(exerciseSeed: seed), now);
    final next = ids(drawn);
    final covered = workedInOrder(drawn.exercises).toSet();
    if (keep.every(covered.contains) && (next.length != current.length || !next.every(current.contains))) return seed;
  }
  return o.exerciseSeed ?? 0;
}

/// The next muscle seed that changes the muscles worked, a dozen tries at most.
int nextMuscleSeed(AppState s, BuildOptions o, DateTime now) {
  Set<String> worked(Session x) => {for (final e in x.exercises) ...e.exercise.primary};
  final current = worked(buildSession(s, o, now));
  var seed = o.muscleSeed ?? 0;
  for (var i = 0; i < 12; i++) {
    seed++;
    final next = worked(buildSession(s, o.copyWith(muscleSeed: seed), now));
    if (next.length != current.length || !next.every(current.contains)) return seed;
  }
  return o.muscleSeed ?? 0;
}

/// Estimated minutes for a session as planned: the warm-up, the lifting, then the cardio and stretching blocks.
int estimateMinutes(Session session) {
  if (session.type == 'move') return session.estMinutes;
  final secs = session.exercises.fold(0.0, (a, e) => a + plannedSeconds(e));
  return (secs / 60).round() + session.warmupMinutes + session.cardioMinutes + session.stretchMinutes;
}
