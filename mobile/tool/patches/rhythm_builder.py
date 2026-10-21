"""The builder on the rhythm: tags make the pool, turns rank it, two seeds shuffle, the cover order per SELECTION.md,
alternatives with reasons, uncovered forced muscles flagged. CRLF kept."""
import pathlib, sys

mobile = pathlib.Path(__file__).resolve().parents[2]
p = mobile / 'lib/logic/builder.dart'
b = p.read_bytes()
crlf = b'\r\n' in b
s = b.decode('utf-8').replace('\r\n', '\n')

def sub(old, new):
    global s
    if old not in s:
        sys.exit(f'builder: not found: {old[:90]!r}')
    s = s.replace(old, new, 1)

def between(start, end, new):
    """Replace from the start marker up to (not including) the end marker."""
    global s
    a = s.index(start); z = s.index(end, a)
    s = s[:a] + new + s[z:]

# ---- the selection: rhythm, tags, two seeds
sub("""  _Selection(this.s, this.now, this.current, this.share, this.equipment, {this.seed, this.avoid = const {}}) : withPlan = current;
  final AppState s;
  /// When set (Draw again), muscles are drawn at random among the ready ones instead of by share, and exercises at
  /// random instead of by practised and library rank. Each draw is fixed by the seed and the name, so the engine's
  /// repeated passes see the same order.
  final int? seed;
  /// Today's excluded muscles: no candidate may have one among its primary muscles.
  final Set<String> avoid;
  final DateTime now;
  final StrainPoints current;
  final Share share;
  final Iterable<String> equipment;""",
    """  _Selection(this.s, this.now, this.current, this.rhythm, this.equipment, {this.muscleSeed, this.exerciseSeed, this.avoid = const {}, Iterable<String>? forced})
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
  final Iterable<String> equipment;""")

sub("""  /// A draw from 0 to 1 fixed by the seed and [key].
  double draw(String key) {
    var h = (seed ?? 0) * 7919 + 17;
    for (final c in key.codeUnits) { h = (h * 31 + c) & 0x3fffffff; }
    return Random(h).nextDouble();
  }""", """  /// A draw from 0 to 1 fixed by [seed] and [key].
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
  int helpScore(Exercise e) => helpsOf(e).fold(0, (a, m) => max(a, rhythm.helpedSinceOf(m)));""")

between("  /// The best exercise for [muscle] while a list of muscles is being covered (the engine)",
        "  /// Muscles in the order selection takes them:",
        """  /// The order of exercises for a place (SELECTION.md, "Which exercise"): ready, then the lowest shade; not for me last;
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
    final p = _prefRank(a, muscle).compareTo(_prefRank(b, muscle));
    if (p != 0) return p;
    final h = helpScore(b).compareTo(helpScore(a));
    if (h != 0) return h;
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

""")

between("  /// Muscles in the order selection takes them:", "class _Slot {",
        """  /// Muscles in the order selection takes them (SELECTION.md, "Whose turn it is"): those with a ready candidate first,
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
    final readyOnes = list.where((m) => ready(candidates[m]!)).toList();
    final pool = readyOnes.take(2 * places).toList();
    final rest = list.where((m) => !pool.contains(m)).toList();
    // weighted sampling without replacement: an exponential key per muscle, the heavier the overdue the sooner
    double key(String m) => -log(1 - draw(m, seed) * 0.999999) / (rhythm.overdue(m) + 1);
    pool.sort((a, b) => key(a).compareTo(key(b)));
    return [...pool, ...rest];
  }
}

""")

# ---- the slot remembers what its pick brought
sub("""  bool explored = false; // an unrated exercise took its turn here
}""", """  bool explored = false; // an unrated exercise took its turn here
  List<String> covers = const [];  // other requirements this pick covered
  List<String> helps = const [];   // passive muscles this pick helps
}""")

# ---- the pool is the active muscles; untaken ready ones first
sub("""  for (final mus in trackedMuscles) {
    if (blocked.contains(mus)) continue;
    final e = sel.bestFor(mus, used, null);
    if (e != null) best[mus] = e;
  }
  if (best.isEmpty) return const [];
  final untaken = best.keys.where((g) => !taken.contains(g));
  final behindReady = untaken.any((g) => sel.ready(best[g]!) && sel.share.band(g) == 0);
  final pool = behindReady ? untaken : best.keys;""",
    """  for (final mus in sel.actives) {
    if (blocked.contains(mus)) continue;
    final e = sel.bestFor(mus, used, null);
    if (e != null) best[mus] = e;
  }
  if (best.isEmpty) return const [];
  final untaken = best.keys.where((g) => !taken.contains(g));
  final pool = untaken.any((g) => sel.ready(best[g]!)) ? untaken : best.keys;""")

# ---- the cover records what each pick brought
sub("""    final pick = sel.coverPick(m, waiting, covered, [for (final x in slots) x.pick!.id], picks[key], forced: f);
    if (pick == null) continue;
    slots.add(_Slot(key, m, slots.length)..pick = pick..asked = f..forced = f && !sel.ready(pick));
    covered.addAll(pick.primary);""",
    """    final pick = sel.coverPick(m, waiting, covered, [for (final x in slots) x.pick!.id], picks[key], forced: f);
    if (pick == null) continue;
    slots.add(_Slot(key, m, slots.length)
      ..pick = pick..asked = f..forced = f && !sel.ready(pick)
      ..covers = [for (final c in pick.primary) if (c != m && waiting.contains(c)) c]
      ..helps = sel.helpsOf(pick));
    covered.addAll(pick.primary);""")

# ---- the engine draws from the active muscles
s = s.replace("""    for (final m in trackedMuscles) {
      if (covered.contains(m) && !req.contains(m) && !blocked.contains(m)) req.add(m);""",
              """    for (final m in sel.actives) {
      if (covered.contains(m) && !req.contains(m) && !blocked.contains(m)) req.add(m);""")
sub("""    for (final m in trackedMuscles) {
      if (req.contains(m) || blocked.contains(m) || tried.contains(m)) continue;""",
    """    for (final m in sel.actives) {
      if (req.contains(m) || blocked.contains(m) || tried.contains(m)) continue;""")

# ---- the options
sub("""    this.muscles = const [], this.excluded = const {}, this.leftOut = const {}, this.liftInstead = false, this.shuffle, this.manual = false,
  });""", """    this.muscles = const [], this.excluded = const {}, this.leftOut = const {}, this.liftInstead = false, this.muscleSeed, this.exerciseSeed, this.manual = false,
  });

  BuildOptions copyWith({int? muscleSeed, int? exerciseSeed, bool clearSeeds = false}) => BuildOptions(
        energy: energy, minutes: minutes, locationId: locationId, picks: picks, rungOverrides: rungOverrides, moveKind: moveKind, routine: routine,
        cardio: cardio, energyChosen: energyChosen, timeChosen: timeChosen, circuit: circuit, exerciseCount: exerciseCount, warmupMinutes: warmupMinutes,
        skipCardio: skipCardio, skipStretch: skipStretch, order: order, muscles: muscles, excluded: excluded, leftOut: leftOut, liftInstead: liftInstead,
        muscleSeed: clearSeeds ? null : muscleSeed ?? this.muscleSeed, exerciseSeed: clearSeeds ? null : exerciseSeed ?? this.exerciseSeed, manual: manual,
      );""")
sub("""  final int? shuffle;                       // a seed: the places after the forced muscles go to ready muscles at random, not by share""",
    """  final int? muscleSeed;                    // Draw again, muscles: the ready muscles drawn weighted by overdue instead of in turn
  final int? exerciseSeed;                  // Draw again, exercises: a draw in place of practised and library rank""")

# ---- building
sub("""  final sel = _Selection(s, now, MuscleMap(s).currentStrainPoints(now), shareOver(s, now), equipment, seed: o.shuffle, avoid: o.excluded);
  final ideal = count ?? g.exercises.ideal;""",
    """  final sel = _Selection(s, now, MuscleMap(s).currentStrainPoints(now), rhythmOver(s, now), equipment,
      muscleSeed: o.muscleSeed, exerciseSeed: o.exerciseSeed, avoid: o.excluded, forced: o.muscles);
  final ideal = count ?? g.exercises.ideal;
  sel.places = ideal;""")
sub("""  final forcedSet = forcedAll.toSet();""", """  final forcedSet = forcedAll.toSet();
  // a forced muscle nothing here could cover, or that a swap uncovered: the plan says so
  final uncovered = [for (final m in forcedAll) if (!outMuscles.contains(m) && !slots.any((x) => x.pick!.primary.contains(m))) m];""")
sub("""    final e = g.emphasisOf(b.muscle).compareTo(g.emphasisOf(a.muscle));""", """    final e = g.oftenOf(b.muscle).compareTo(g.oftenOf(a.muscle));""")
sub("""    final why = whyLine(
      ready: ex.primary.every(current.strainFree), band: sel.share.band(sl.muscle), emphasis: g.emphasisOf(sl.muscle),
      preference: preferenceOf(st, now), fresh: fresh, asked: sl.asked,
    );""", """    final why = whyLine(
      asked: sl.asked, ready: ex.primary.every(current.strainFree), due: sel.rhythm.dueText(sl.muscle), covers: sl.covers,
      preference: preferenceOf(st, now), helps: sl.helps, fresh: fresh, drawn: o.exerciseSeed != null || o.muscleSeed != null,
    );""")
sub(""")..relative = relative..pushes = out.where((e) => e.nextLevel).length;""",
    """)..relative = relative..pushes = out.where((e) => e.nextLevel).length..uncovered = uncovered;""")

# ---- alternatives with reasons, the exercise shuffle by seed
between("/// Alternatives for one slot", "/// Estimated minutes for a session as planned",
        """/// An alternative for a place, with what it brings.
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
  final current = ids(buildSession(s, o, now));
  var seed = o.exerciseSeed ?? 0;
  for (var i = 0; i < 12; i++) {
    seed++;
    final next = ids(buildSession(s, o.copyWith(exerciseSeed: seed), now));
    if (next.length != current.length || !next.every(current.contains)) return seed;
  }
  return seed;
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
  return seed;
}

""")

if crlf:
    s = s.replace('\n', '\r\n')
p.write_bytes(s.encode('utf-8'))

# ---- the session carries the uncovered forced muscles, never saved
m = mobile / 'lib/data/model.dart'
b = m.read_bytes(); mc = b'\r\n' in b; t = b.decode('utf-8').replace('\r\n', '\n')
old = """  int? calendarEventId;  // the event auto-track wrote, so the calendar read can tell it from busy time
"""
new = """  int? calendarEventId;  // the event auto-track wrote, so the calendar read can tell it from busy time
  List<String> uncovered = [];  // forced muscles no exercise could cover today, or a swap uncovered; never saved
"""
if old not in t: sys.exit('model: calendarEventId not found')
t = t.replace(old, new, 1)
m.write_bytes((t.replace('\n', '\r\n') if mc else t).encode('utf-8'))
print('ok')
