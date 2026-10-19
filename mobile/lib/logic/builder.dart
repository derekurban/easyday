// Builds today's workout: the list is built once at normal and fitted to the minutes by three calibrations (exercises,
// sets, pushes: the fewest, the ideal, the most); energy turns the dials on it (hard: the next level, and room to grow
// to the most; easy: lighter, fewer exercises at full sets). WORKOUT.md and section 7 of APPLICATION.md.
import 'dart:math';

import '../data/library.dart';
import '../data/model.dart';
import 'ladder.dart';
import 'muscle_map.dart';
import 'person.dart';

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
const _freePatterns = ['core', 'carry', 'arms', 'legs', 'shoulders'];

/// Expire pain pauses. A pattern comes back on its own, one rung down.
void expirePauses(AppState s, DateTime now) {
  final p = s.plan!;
  final expired = p.paused.entries.where((e) => !now.isBefore(e.value)).map((e) => e.key).toList();
  for (final pattern in expired) {
    for (final ex in exercises.where((e) => e.pattern == pattern)) {
      final st = s.ex[ex.id];
      if (st == null) continue;
      st.rung = max(ex.loaded ? floorRung(s, ex, st) : 0, st.rung - 1);
      st.topRun = 0;
      st.shortRun = 0;
    }
    p.paused.remove(pattern);
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

/// The default on a busy day.
const busyDayMinutes = 25;
/// The ideal list filling no more than this share of the window makes a long day: room to grow to the most.
const longWindowShare = 0.5;

List<Exercise> candidates(AppState s, String pattern, Iterable<String> equipment, Iterable<String> exclude) {
  final ex = exclude.toSet();
  return exercises.where((e) => e.pattern == pattern && available(e, equipment) && !ex.contains(e.id)).toList();
}

bool _practised(AppState s, Exercise e) => (s.ex[e.id]?.appearances ?? 0) > 0;
int _difficulty(AppState s, Exercise e) => difficultyInPlay(e, s.ex[e.id]);

/// Practised first, then library rank.
int _usualOrder(AppState s, Exercise a, Exercise b) {
  final pa = _practised(s, a), pb = _practised(s, b);
  if (pa != pb) return pa ? -1 : 1;
  return a.rank.compareTo(b.rank);
}

/// How strain points choose between exercises (MUSCLE_MAP.md): the current strain points, and today's plan so far.
class _Strain {
  _Strain(this.current) : withPlan = current;
  final StrainPoints current;
  StrainPoints withPlan;

  /// Every primary muscle of [e] strain-free.
  bool free(Exercise e) => e.primary.every(current.strainFree);

  /// The shade [e]'s most strained primary muscle sits at, with today's plan so far added.
  int shade(Exercise e) => withPlan.highestShade(e.primary);

  /// Strain-free primary muscles first, then the lowest shade with today's plan, then the usual order.
  int compare(AppState s, Exercise a, Exercise b) {
    final fa = free(a), fb = free(b);
    if (fa != fb) return fa ? -1 : 1;
    final c = shade(a).compareTo(shade(b));
    return c != 0 ? c : _usualOrder(s, a, b);
  }

  /// Today's plan so far: the current strain points plus the strain points from workout of [plan].
  void plan(Iterable<({Exercise exercise, int sets, bool light})> plan) => withPlan = current.plus(strainPointsFromPlan(plan));

  void planSlots(Iterable<_Slot> slots) => plan([
        for (final x in slots) if (x.pick != null) (exercise: x.pick!, sets: x.sets == 0 ? 1 : x.sets, light: x.intent == intentLight),
      ]);
}

class _Slot {
  _Slot(this.slot, this.pattern, this.priority);
  final String slot;
  final String pattern;
  final int priority;   // position in the goal's list: lower gets the work first and loses it last
  Exercise? pick;
  String intent = intentWorking;
  int sets = 0;
}

double _seconds(AppState s, _Slot sl) {
  final st = ensureState(s, sl.pick!);
  var secs = st.secPerSet * sl.sets + changeSeconds;
  if (sl.pick!.loaded && _difficulty(s, sl.pick!) >= 3) secs += warmupSetsSeconds;
  return secs;
}
double _totalSeconds(AppState s, List<_Slot> slots) => slots.fold(0.0, (a, x) => a + _seconds(s, x));

/// The exercise for a pattern: the user's pick, else the one strain points put first. Energy plays no part.
Exercise? _pickFor(AppState s, String pattern, Iterable<String> equipment, Iterable<String> used, String? pref, _Strain strain) {
  final cands = candidates(s, pattern, equipment, used);
  if (cands.isEmpty) return null;
  if (pref != null) {
    final p = cands.where((e) => e.id == pref).firstOrNull;
    if (p != null) return p;
  }
  cands.sort((a, b) => strain.compare(s, a, b));
  return cands.first;
}

/// The working turns on an easy day: the exercises that have waited longest, ties by priority.
int _waitedLongest(AppState s, _Slot a, _Slot b) {
  final la = s.ex[a.pick!.id]?.lastWorkingAt, lb = s.ex[b.pick!.id]?.lastWorkingAt;
  if (la == null && lb != null) return -1;
  if (lb == null && la != null) return 1;
  if (la != null && lb != null && la != lb) return la.compareTo(lb);
  return a.priority.compareTo(b.priority);
}

/// The dials for one energy, on a list that is already built and fitted. The list never changes here.
/// [pushes] is how many exercises train at the next level on a hard day.
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
      // the hardest exercises train at the next level, every set: the same sets, one step heavier
      final byDifficulty = slots.toList()..sort((a, b) { final c = _difficulty(s, b.pick!).compareTo(_difficulty(s, a.pick!)); return c != 0 ? c : a.priority.compareTo(b.priority); });
      for (final sl in byDifficulty.take(pushes)) { sl.intent = intentExtra; }
  }
}

/// Fit the minutes: exercises down to the fewest (light ones first, then the last on the list), then sets down to
/// the fewest (the exercise with the most sets first, the last on the list among equals), and only when the minutes
/// cannot hold even that, below the fewest. Returns the patterns dropped, so growth can bring them back if room appears.
List<String> _fitTime(AppState s, List<_Slot> slots, double window, GoalConfig g) {
  final dropped = <String>[];
  void drop(_Slot victim) { slots.remove(victim); dropped.insert(0, victim.pattern); }
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

/// Grow the exercises into what is left, one more pattern at a time, up to [limit]. Only patterns with an exercise whose
/// primary muscles are strain-free: the one at the lowest shade with today's plan first, and among equals dropped ones
/// first, then the rest of the rotation item, then the free patterns.
void _grow(AppState s, List<_Slot> slots, double window, int limit, int sets, Iterable<String> equipment,
    List<String> morePatterns, Map<String, DateTime> paused, _Strain strain) {
  var added = slots.where((x) => x.slot.endsWith('x')).length;
  for (var guard = 0; guard < 20 && slots.length < limit; guard++) {
    final secsLeft = window - _totalSeconds(s, slots);
    if (secsLeft <= 0) break;
    final inPlay = slots.map((x) => x.pattern).toSet();
    final used = slots.map((x) => x.pick!.id).toList();
    strain.planSlots(slots);
    _Slot? next;
    var nextShade = strainShades + 1;
    for (final pattern in [...morePatterns, ..._freePatterns]) {
      if (inPlay.contains(pattern) || paused.containsKey(pattern)) continue;
      final pick = _pickFor(s, pattern, equipment, used, null, strain);
      if (pick == null || !strain.free(pick)) continue;
      final sl = _Slot('${pattern}x', pattern, 100 + added)..pick = pick..intent = intentWorking..sets = sets;
      final shade = strain.shade(pick);
      if (shade < nextShade && _seconds(s, sl) <= secsLeft) { next = sl; nextShade = shade; }
    }
    if (next == null) break;
    slots.add(next);
    added++;
  }
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
  final plan = s.plan!;
  final g = s.goal!;
  final item = plan.rotation[plan.index];
  final ps = personState(s, now);
  final loc = s.location(o.locationId);
  final equipment = loc?.equipment ?? const <String>[];
  const id = 'preview'; // the real id is assigned when the session starts
  final minutes = clampMinutes(o.minutes);

  if (o.moveKind != null || item.type == 'move') {
    final kind = o.moveKind ?? item.kind!;
    final routineId = o.routine ?? item.routine ?? 'reset';
    final r = routines[routineId]!;
    return Session(
      id: id, type: 'move', kind: kind, name: kind == 'cardio' ? 'Move day' : r.name, itemIndex: plan.index, locationId: loc?.id,
      energy: o.energy, timeMinutes: minutes, energyChosen: o.energyChosen, timeChosen: o.timeChosen, stateAtStart: ps.state,
      minutes: kind == 'cardio' ? minutes : null, routine: kind == 'mobility' ? routineId : null, cardio: kind == 'cardio' ? (o.cardio ?? 'any') : null,
      estMinutes: kind == 'cardio' ? minutes : (r.moves.length * r.seconds / 60).ceil(),
    )..swappedToMove = item.type == 'lift';
  }

  // 1. the window: the minutes, less the warm-up and the cardio and stretching shares. With no time limit the window
  //    is open and the count decides; cardio and stretching then keep their shares of whatever the lifting takes.
  final count = o.exerciseCount?.clamp(1, exercisesMax);
  final warmup = o.warmupMinutes.clamp(0, 30);
  var cardioMin = o.skipCardio ? 0 : (minutes * g.cardioPct / 100).round();
  var stretchMin = o.skipStretch ? 0 : (minutes * g.stretchPct / 100).round();
  final window = count != null ? _openWindow : max(0, minutes - cardioMin - stretchMin - warmup) * 60.0;

  // 2. the pattern list, with paused patterns substituted, and an exercise for each. A pattern none of whose exercises
  //    has strain-free primary muscles sits out for one that has, unless the user picked its exercise (MUSCLE_MAP.md).
  final strain = _Strain(MuscleMap(s).currentStrainPoints(now));
  final all = liftItems.where((it) => it.name == item.name).firstOrNull?.patterns ?? item.patterns;
  final listed = item.patterns.toList();
  bool strained(String p) { final c = candidates(s, p, equipment, const []); return c.isNotEmpty && !c.any(strain.free); }
  final taken = <String>{};
  String? free({bool strainFree = true}) => [..._freePatterns, ...all].where((a) => !listed.contains(a) && !taken.contains(a) &&
      !plan.paused.containsKey(a) && candidates(s, a, equipment, const []).isNotEmpty && (!strainFree || !strained(a))).firstOrNull;
  final patternsToday = <String>[];
  final satOut = <String, String>{};
  for (final p in listed) {
    String? instead;
    if (plan.paused.containsKey(p)) {
      instead = free() ?? free(strainFree: false);
      if (instead == null) continue;
    } else if (strained(p) && !o.picks.keys.any((k) => k.startsWith(p))) {
      instead = free();
      if (instead != null) satOut[p] = instead;
    }
    if (instead != null) taken.add(instead);
    patternsToday.add(instead ?? p);
  }
  final slots = <_Slot>[];
  final counts = <String, int>{};
  final used = <String>[];
  for (var i = 0; i < patternsToday.length; i++) {
    final p = patternsToday[i];
    counts[p] = (counts[p] ?? 0) + 1;
    final sl = _Slot('$p${counts[p]}', p, i);
    strain.planSlots(slots);
    sl.pick = _pickFor(s, p, equipment, used, o.picks[sl.slot], strain);
    if (sl.pick == null) continue;
    used.add(sl.pick!.id);
    slots.add(sl);
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
      dropped.insert(0, byPriority.first.pattern);
    }
    _grow(s, slots, window, count, g.sets.ideal, equipment, [...dropped, ...all.where((p) => !patternsToday.contains(p))], plan.paused, strain);
  } else if (g.spare == Spare.exercises) {
    final more = [...dropped, ...all.where((p) => !patternsToday.contains(p))];
    _grow(s, slots, window, g.exercises.ideal, g.sets.ideal, equipment, more, plan.paused, strain);
    if (o.energy == Energy.hard || (longDay && o.energy != Energy.easy)) {
      _growSets(s, slots, window, g.sets.max);
      _grow(s, slots, window, g.exercises.max, g.sets.ideal, equipment, more, plan.paused, strain);
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
  final liftIndex = plan.rotation.take(plan.index).where((r) => r.type == 'lift').length;
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

  // 6. order: hardest first while the user is fresh; at the same difficulty, extra and working before light
  slots.sort((a, b) {
    final c = _difficulty(s, b.pick!).compareTo(_difficulty(s, a.pick!));
    if (c != 0) return c;
    final t = _tier(a.intent).compareTo(_tier(b.intent));
    return t != 0 ? t : a.priority.compareTo(b.priority);
  });

  // the exercise entries
  final lightenHard = ps.state == PersonState.away;
  final out = <SessionExercise>[];
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
    final label = ex.loaded ? fmtKg(s, load!, each: ex.each) : rungLabel(s, ex, st, rung, range);
    // today's work against the usual: sets against the working sets, times the weight share (or one version down), times the reserve
    var relative = sl.sets / g.sets.ideal;
    if (light) relative *= (ex.loaded ? easyShare : 0.85) * 0.9;
    if (nextLevel) relative *= 1.1;
    out.add(SessionExercise(
      slot: sl.slot, exId: ex.id, pattern: sl.pattern, intent: sl.intent, workingSets: min(sl.sets, g.sets.ideal), rung: rung, rungLabel: label,
      target: target, lo: range.lo, hi: range.hi, atCeiling: ceilingToday, bestTotal: st.bestTotal, difficulty: difficulty, loadKg: load,
      secPerSet: st.secPerSet, sets: List.generate(sl.sets, (_) => SetLog()), warmups: ex.loaded && difficulty >= 3 ? warmupsFor(s, ex, load!) : const [],
      edited: edited, lightened: lightened,
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
    id: id, type: 'lift', name: item.name, itemIndex: plan.index, locationId: loc?.id, energy: o.energy, timeMinutes: minutes,
    energyChosen: o.energyChosen, timeChosen: o.timeChosen, stateAtStart: ps.state, exercises: out,
    estMinutes: (usedSeconds / 60).round() + (out.isEmpty ? 0 : cardioMin + stretchMin + warmup), cardioMinutes: out.isEmpty ? 0 : cardioMin,
    stretchMinutes: out.isEmpty ? 0 : stretchMin, spareMinutes: spareMin, circuit: o.circuit, warmupMinutes: out.isEmpty ? 0 : warmup,
  )..relative = relative..pushes = out.where((e) => e.nextLevel).length..satOut = satOut;
}

/// Seconds one exercise is planned to take, rest after its sets included: what the plan shows beside it.
double plannedSeconds(SessionExercise e) => e.secPerSet * e.sets.length + changeSeconds + (e.warmups.isNotEmpty ? warmupSetsSeconds : 0);

/// Words for a relative load: how today compares with the usual working level.
String relativeLabel(double r) => r < 0.95 ? 'lighter' : r > 1.05 ? 'more' : 'usual';

/// Alternatives for one slot: same pattern, available here, not already in the session; ordered by strain points the
/// way the builder orders them, against the rest of the workout.
List<Exercise> alternatives(AppState s, Session session, int idx, Iterable<String> equipment, DateTime now) {
  final e = session.exercises[idx];
  final strain = _strainBeside(s, session, idx, now);
  return candidates(s, e.pattern, equipment, session.exercises.map((x) => x.exId))..sort((a, b) => strain.compare(s, a, b));
}

/// Strain points for one slot of a built workout: the current strain points, plus every other exercise's.
_Strain _strainBeside(AppState s, Session session, int idx, DateTime now) => _Strain(MuscleMap(s).currentStrainPoints(now))
  ..plan([
    for (var i = 0; i < session.exercises.length; i++)
      if (i != idx) (exercise: session.exercises[i].exercise, sets: session.exercises[i].sets.length, light: session.exercises[i].intent == intentLight),
  ]);

/// Random fresh picks for every slot, from the top few alternatives by strain points.
Map<String, String> shufflePicks(AppState s, Session session, Iterable<String> equipment, Random rng, DateTime now) {
  final picks = <String, String>{};
  final used = <String>[];
  for (var i = 0; i < session.exercises.length; i++) {
    final e = session.exercises[i];
    final strain = _strainBeside(s, session, i, now);
    final alts = candidates(s, e.pattern, equipment, [...used, e.exId])..sort((a, b) => strain.compare(s, a, b));
    final ranked = alts.isEmpty ? candidates(s, e.pattern, equipment, used) : alts;
    final strainFree = ranked.where(strain.free).toList();
    final pool = (strainFree.isEmpty ? ranked : strainFree).take(4).toList();
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
