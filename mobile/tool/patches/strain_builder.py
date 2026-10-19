# The builder picks exercises by strain points (MUSCLE_MAP.md): strain-free primary muscles first, the lowest shade with
# today's plan, then the usual order; a pattern with no strain-free exercise sits out for one that has.
import pathlib

p = pathlib.Path('lib/logic/builder.dart')
t = p.read_bytes().decode().replace('\r\n', '\n')


def rep(old, new):
    global t
    assert t.count(old) == 1, old[:80]
    t = t.replace(old, new)


rep("""import 'ladder.dart';
import 'person.dart';
""", """import 'ladder.dart';
import 'muscle_map.dart';
import 'person.dart';
""")

rep("""/// Practised first, then library rank.
int _usualOrder(AppState s, Exercise a, Exercise b) {
  final pa = _practised(s, a), pb = _practised(s, b);
  if (pa != pb) return pa ? -1 : 1;
  return a.rank.compareTo(b.rank);
}
""", """/// Practised first, then library rank.
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
""")

rep("""/// The exercise for a pattern: the user's pick, else the usual one. Energy plays no part.
Exercise? _pickFor(AppState s, String pattern, Iterable<String> equipment, Iterable<String> used, String? pref) {
  final cands = candidates(s, pattern, equipment, used);
  if (cands.isEmpty) return null;
  if (pref != null) {
    final p = cands.where((e) => e.id == pref).firstOrNull;
    if (p != null) return p;
  }
  cands.sort((a, b) => _usualOrder(s, a, b));
  return cands.first;
}
""", """/// The exercise for a pattern: the user's pick, else the one strain points put first. Energy plays no part.
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
""")

rep("""/// Grow the exercises into what is left, one more pattern at a time, up to [limit]: dropped ones first, then the rest
/// of the rotation item, then the free patterns.
void _grow(AppState s, List<_Slot> slots, double window, int limit, int sets, Iterable<String> equipment,
    List<String> morePatterns, Map<String, DateTime> paused) {
  var added = slots.where((x) => x.slot.endsWith('x')).length;
  for (var guard = 0; guard < 20 && slots.length < limit; guard++) {
    final secsLeft = window - _totalSeconds(s, slots);
    if (secsLeft <= 0) break;
    final inPlay = slots.map((x) => x.pattern).toSet();
    final used = slots.map((x) => x.pick!.id).toList();
    _Slot? next;
    for (final pattern in [...morePatterns, ..._freePatterns]) {
      if (inPlay.contains(pattern) || paused.containsKey(pattern)) continue;
      final pick = _pickFor(s, pattern, equipment, used, null);
      if (pick == null) continue;
      final sl = _Slot('${pattern}x', pattern, 100 + added)..pick = pick..intent = intentWorking..sets = sets;
      if (_seconds(s, sl) <= secsLeft) { next = sl; break; }
    }
    if (next == null) break;
    slots.add(next);
    added++;
  }
}
""", """/// Grow the exercises into what is left, one more pattern at a time, up to [limit]. Only patterns with an exercise whose
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
""")

rep("""  // 2. the pattern list, with paused patterns substituted, and an exercise for each
  final all = liftItems.where((it) => it.name == item.name).firstOrNull?.patterns ?? item.patterns;
  final listed = item.patterns.toList();
  String? free() => [..._freePatterns, ...all].where((a) => !listed.contains(a) && !plan.paused.containsKey(a) && candidates(s, a, equipment, const []).isNotEmpty).firstOrNull;
  final patternsToday = listed.map((p) => plan.paused.containsKey(p) ? free() : p).whereType<String>().toList();
  final slots = <_Slot>[];
  final counts = <String, int>{};
  final used = <String>[];
  for (var i = 0; i < patternsToday.length; i++) {
    final p = patternsToday[i];
    counts[p] = (counts[p] ?? 0) + 1;
    final sl = _Slot('$p${counts[p]}', p, i);
    sl.pick = _pickFor(s, p, equipment, used, o.picks[sl.slot]);
    if (sl.pick == null) continue;
    used.add(sl.pick!.id);
    slots.add(sl);
  }
""", """  // 2. the pattern list, with paused patterns substituted, and an exercise for each. A pattern none of whose exercises
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
""")

rep("""    _grow(s, slots, window, count, g.sets.ideal, equipment, [...dropped, ...all.where((p) => !patternsToday.contains(p))], plan.paused);""",
    """    _grow(s, slots, window, count, g.sets.ideal, equipment, [...dropped, ...all.where((p) => !patternsToday.contains(p))], plan.paused, strain);""")
rep("""    _grow(s, slots, window, g.exercises.ideal, g.sets.ideal, equipment, more, plan.paused);""",
    """    _grow(s, slots, window, g.exercises.ideal, g.sets.ideal, equipment, more, plan.paused, strain);""")
rep("""      _grow(s, slots, window, g.exercises.max, g.sets.ideal, equipment, more, plan.paused);""",
    """      _grow(s, slots, window, g.exercises.max, g.sets.ideal, equipment, more, plan.paused, strain);""")

rep("""  )..relative = relative..pushes = out.where((e) => e.nextLevel).length;
}""", """  )..relative = relative..pushes = out.where((e) => e.nextLevel).length..satOut = satOut;
}""")

rep("""/// Alternatives for one slot: same pattern, available here, not already in the session.
List<Exercise> alternatives(AppState s, Session session, int idx, Iterable<String> equipment) {
  final e = session.exercises[idx];
  return candidates(s, e.pattern, equipment, session.exercises.map((x) => x.exId))..sort((a, b) => _usualOrder(s, a, b));
}

/// Random fresh picks for every slot, from the top few alternatives.
Map<String, String> shufflePicks(AppState s, Session session, Iterable<String> equipment, Random rng) {
  final picks = <String, String>{};
  final used = <String>[];
  for (final e in session.exercises) {
    final alts = candidates(s, e.pattern, equipment, [...used, e.exId])..sort((a, b) => a.rank.compareTo(b.rank));""",
"""/// Alternatives for one slot: same pattern, available here, not already in the session; ordered by strain points the
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
    final alts = candidates(s, e.pattern, equipment, [...used, e.exId])..sort((a, b) => strain.compare(s, a, b));""")

p.write_bytes(t.replace('\n', '\r\n').encode())
