"""The builder's step 2 becomes an engine: muscle requirements, then exercises that cover them. CRLF kept."""
import pathlib, sys

p = pathlib.Path(__file__).resolve().parents[2] / 'lib/logic/builder.dart'
b = p.read_bytes()
crlf = b'\r\n' in b
s = b.decode('utf-8').replace('\r\n', '\n')

def sub(old, new):
    global s
    if old not in s:
        sys.exit(f'not found: {old[:80]!r}')
    s = s.replace(old, new, 1)

# ---- the selection: a seed with stable draws, and the cover pick
sub("""  _Selection(this.s, this.now, this.current, this.share, this.equipment, {int? shuffle, this.avoid = const {}})
      : withPlan = current, rng = shuffle == null ? null : Random(shuffle);
  final AppState s;
  /// When set, muscles are drawn at random among the ready ones (Draw again) instead of by share.
  final Random? rng;""", """  _Selection(this.s, this.now, this.current, this.share, this.equipment, {this.seed, this.avoid = const {}}) : withPlan = current;
  final AppState s;
  /// When set (Draw again), muscles are drawn at random among the ready ones instead of by share, and exercises at
  /// random instead of by practised and library rank. Each draw is fixed by the seed and the name, so the engine's
  /// repeated passes see the same order.
  final int? seed;""")
sub("""  String? pref(Exercise e) => preferenceOf(s.ex[e.id], now);
""", """  String? pref(Exercise e) => preferenceOf(s.ex[e.id], now);

  /// A draw from 0 to 1 fixed by the seed and [key].
  double draw(String key) {
    var h = (seed ?? 0) * 7919 + 17;
    for (final c in key.codeUnits) { h = (h * 31 + c) & 0x3fffffff; }
    return Random(h).nextDouble();
  }
""")
sub("""    if (rng != null) {
      final draw = {for (final mus in list) mus: rng!.nextDouble()};
      list.sort((a, b) {
        final ra = ready(candidates[a]!), rb = ready(candidates[b]!);
        if (ra != rb) return ra ? -1 : 1;
        return draw[a]!.compareTo(draw[b]!);
      });
      return list;
    }""", """    if (seed != null) {
      list.sort((a, b) {
        final ra = ready(candidates[a]!), rb = ready(candidates[b]!);
        if (ra != rb) return ra ? -1 : 1;
        return draw(a).compareTo(draw(b));
      });
      return list;
    }""")
sub("""  /// Muscles in the order selection takes them:""", """  /// The best exercise for [muscle] while a list of muscles is being covered (the engine): ready first; not for me only
  /// when nothing else will do; then the one working the most muscles still [waiting] as main muscles; then the one
  /// working the fewest already [covered], so no muscle is worked twice when it can be helped; then [compare]'s order,
  /// with Draw again's seed in place of practised and library rank. A [forced] muscle that only has candidates working
  /// an excluded muscle too takes one of those rather than nothing.
  Exercise? coverPick(String muscle, Set<String> waiting, Set<String> covered, Iterable<String> used, String? userPick, {bool forced = false}) {
    var cands = candidatesFor(s, muscle, equipment, used, now, avoid: avoid);
    if (cands.isEmpty && forced) cands = candidatesFor(s, muscle, equipment, used, now);
    if (cands.isEmpty) return null;
    if (userPick != null) {
      final p = cands.where((e) => e.id == userPick).firstOrNull;
      if (p != null) return p;
    }
    int gain(Exercise e) => e.primary.where(waiting.contains).length;
    int overlap(Exercise e) => e.primary.where(covered.contains).length;
    cands.sort((a, b) {
      final ra = ready(a), rb = ready(b);
      if (ra != rb) return ra ? -1 : 1;
      final na = pref(a) == prefNo, nb = pref(b) == prefNo;
      if (na != nb) return na ? 1 : -1;
      final gn = gain(b).compareTo(gain(a));
      if (gn != 0) return gn;
      final ov = overlap(a).compareTo(overlap(b));
      if (ov != 0) return ov;
      final c = shade(a).compareTo(shade(b));
      if (c != 0) return c;
      final p = _prefRank(a, muscle).compareTo(_prefRank(b, muscle));
      if (p != 0) return p;
      if (seed != null) return draw(a.id).compareTo(draw(b.id));
      final pa = _practised(s, a), pb = _practised(s, b);
      if (pa != pb) return pa ? -1 : 1;
      return a.rank.compareTo(b.rank);
    });
    return cands.first;
  }

  /// Muscles in the order selection takes them:""")

# ---- growth counts a muscle as taken when the list works it as a main muscle
sub("""  final taken = slots.map((x) => x.muscle).toSet();""", """  final taken = _covered(slots);""")

# ---- the engine
sub("""/// Grow the sets into what is left,""", """/// The muscles [slots] work as a main muscle.
Set<String> _covered(Iterable<_Slot> slots) => {for (final x in slots) ...x.pick!.primary};

/// The exercises that cover [req], the most important muscle first: each muscle no exercise chosen so far works as a
/// main muscle gets the best exercise for it by [_Selection.coverPick], which prefers one that works other waiting
/// muscles too. A muscle covered on the way takes no place of its own. A place is keyed by the muscle it was taken for.
List<_Slot> _cover(List<String> req, Set<String> forced, _Selection sel, Map<String, String> picks) {
  final slots = <_Slot>[];
  final covered = <String>{};
  for (final m in req) {
    if (covered.contains(m)) continue;
    sel.planSlots(slots);
    final key = '${m}1';
    final waiting = {for (final r in req) if (!covered.contains(r)) r};
    final f = forced.contains(m);
    final pick = sel.coverPick(m, waiting, covered, [for (final x in slots) x.pick!.id], picks[key], forced: f);
    if (pick == null) continue;
    slots.add(_Slot(key, m, slots.length)..pick = pick..asked = f..forced = f && !sel.ready(pick));
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
({List<String> req, List<_Slot> slots}) _engine(List<String> forcedList, Set<String> blocked, int limit, bool manual, _Selection sel, Map<String, String> picks) {
  final forced = forcedList.toSet();
  final req = [...forcedList];
  var slots = _cover(req, forced, sel, picks);
  if (manual) return (req: req, slots: slots);
  void freeRiders() {
    final covered = _covered(slots);
    for (final m in trackedMuscles) {
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
    for (final m in trackedMuscles) {
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

/// Grow the sets into what is left,""")

# ---- step 2 of building
a = s.index("  // 2. the muscles, then an exercise for each")
z = s.index("  // 3. the list is built once")
s = s[:a] + """  // 2. the engine (SELECTION.md): the muscles to work, then exercises whose main muscles cover them all. The forced
  //    muscles first, strained or not; then the ready muscles furthest behind their share, emphasis first, as many as
  //    the ideal number of exercises (or the count) can cover. A place the user left out today takes its muscle off the
  //    list and the count down by one. The last place may go to something new.
  final sel = _Selection(s, now, MuscleMap(s).currentStrainPoints(now), shareOver(s, now), equipment, seed: o.shuffle, avoid: o.excluded);
  final ideal = count ?? g.exercises.ideal;
  final blocked = <String>{...o.excluded, if (o.manual) ...trackedMuscles.where((m) => !o.muscles.contains(m))};
  final forcedAll = [for (final m in o.muscles) if (trackedMuscles.contains(m)) m];
  final outMuscles = <String>{};
  var outCount = 0;
  var built = (req: <String>[], slots: <_Slot>[]);
  for (var pass = 0; pass < 4; pass++) {
    final forcedNow = [for (final m in forcedAll) if (!outMuscles.contains(m)) m];
    final forcedCover = _cover(forcedNow, forcedNow.toSet(), sel, o.picks).length;
    final limit = max(0, max(ideal, min(forcedCover, g.exercises.max)) - outCount);
    built = _engine(forcedNow, blocked, limit, o.manual, sel, o.picks);
    final out = [for (final x in built.slots) if (o.leftOut.contains(x.slot)) x];
    if (out.isEmpty) break;
    for (final x in out) { blocked.add(x.muscle); outMuscles.add(x.muscle); }
    outCount += out.length;
  }
  final slots = [for (final x in built.slots) if (!o.leftOut.contains(x.slot)) x];
  final forcedSet = forcedAll.toSet();
  // the last place: when the practised pick for its muscle has had its run, an unrated one takes a turn, so long as it
  // still works every forced muscle the practised one did
  final explore = o.energy != Energy.hard;
  if (explore && ideal >= 1 && slots.length >= ideal) {
    final last = slots[ideal - 1];
    if (!last.asked && !o.picks.containsKey(last.slot) && _practised(s, last.pick!) && runOf(s, last.muscle, last.pick!.id) >= exploreRun[g.explore]!) {
      sel.planSlots(slots.where((x) => x != last));
      sel.exploreMuscle = last.muscle;
      final keep = last.pick!.primary.where(forcedSet.contains).toSet();
      final cands = candidatesFor(s, last.muscle, equipment, [for (final x in slots) x.pick!.id], now, avoid: o.excluded)
          .where((e) => keep.every(e.primary.contains)).toList()
        ..sort((a, b) => sel.compare(a, b, muscle: last.muscle));
      final fresh = cands.firstOrNull;
      if (fresh != null && !_practised(s, fresh) && sel.ready(fresh) == sel.ready(last.pick!)) { last.pick = fresh; last.explored = true; }
      sel.exploreMuscle = null;
    }
  }

""" + s[z:]

# ---- manual grows sets, never exercises
sub("""    _grow(s, slots, window, count, g.sets.ideal, dropped, blocked, sel);
  } else if (g.spare == Spare.exercises) {""", """    if (!o.manual) _grow(s, slots, window, count, g.sets.ideal, dropped, blocked, sel);
  } else if (g.spare == Spare.exercises && !o.manual) {""")

# ---- the name: every main muscle the exercises work, in order
sub("""String workoutName(List<SessionExercise> out) {
  final muscles = <String>[];
  for (final e in out) { if (!muscles.contains(e.muscle)) muscles.add(e.muscle); }
  return dayName(muscles);
}""", """String workoutName(List<SessionExercise> out) => dayName(workedInOrder(out));

/// Every muscle the exercises work as a main muscle, in the order they come up.
List<String> workedInOrder(Iterable<SessionExercise> out) {
  final muscles = <String>[];
  for (final e in out) {
    for (final m in e.exercise.primary) { if (!muscles.contains(m)) muscles.add(m); }
  }
  return muscles;
}""")
sub("""/// A workout's name: every muscle it works, in order, as a day:""", """/// A workout's name: every muscle it works as a main muscle, in order, as a day:""")

if crlf:
    s = s.replace('\n', '\r\n')
p.write_bytes(s.encode('utf-8'))
print('ok')
