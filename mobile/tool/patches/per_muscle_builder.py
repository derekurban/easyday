"""The builder selects per muscle: groups renamed to muscles, excluded muscles filter candidates, forced muscles fall back,
manual blocks the rest. CRLF kept."""
import pathlib, re, sys

p = pathlib.Path(__file__).resolve().parents[2] / 'lib/logic/builder.dart'
b = p.read_bytes()
crlf = b'\r\n' in b
s = b.decode('utf-8').replace('\r\n', '\n')

def sub(old, new):
    global s
    if old not in s:
        sys.exit(f'not found: {old[:80]!r}')
    s = s.replace(old, new, 1)

# whyLine no longer takes the group
sub("      group: sl.group, ready: ex.primary.every(current.strainFree),", "      ready: ex.primary.every(current.strainFree),")

# the rename, word by word
s = s.replace('muscle groups', 'muscles')
s = s.replace('muscle group', 'muscle')
s = re.sub(r'\bexploreGroup\b', 'exploreMuscle', s)
s = re.sub(r'\brankGroups\b', 'rankMuscles', s)
s = re.sub(r'\b_rankedGroups\b', '_rankedMuscles', s)
s = re.sub(r'\bmuscleGroups\b', 'trackedMuscles', s)
s = re.sub(r'\bgroups\b', 'muscles', s)
s = re.sub(r'\bgroup\b', 'muscle', s)
s = re.sub(r'\bgrp\b', 'mus', s)
s = s.replace('Groups in the order selection takes them', 'Muscles in the order selection takes them')

# the selection carries today's excluded muscles, and a forced muscle falls back to any candidate
sub("""  _Selection(this.s, this.now, this.current, this.share, this.equipment, {int? shuffle}) : withPlan = current, rng = shuffle == null ? null : Random(shuffle);
  final AppState s;
  /// When set, muscles are drawn at random among the ready ones (the Shuffle button) instead of by share.
  final Random? rng;""", """  _Selection(this.s, this.now, this.current, this.share, this.equipment, {int? shuffle, this.avoid = const {}})
      : withPlan = current, rng = shuffle == null ? null : Random(shuffle);
  final AppState s;
  /// When set, muscles are drawn at random among the ready ones (Draw again) instead of by share.
  final Random? rng;
  /// Today's excluded muscles: no candidate may have one among its primary muscles.
  final Set<String> avoid;""")
sub("""  /// The best exercise for a muscle: the user's pick for the slot, else the first by [compare].
  Exercise? bestFor(String muscle, Iterable<String> used, String? pref) {
    final cands = candidatesFor(s, muscle, equipment, used, now);
    if (cands.isEmpty) return null;""", """  /// The best exercise for a muscle: the user's pick for the slot, else the first by [compare]. A [forced] muscle that
  /// only has candidates working an excluded muscle too takes one of those rather than nothing.
  Exercise? bestFor(String muscle, Iterable<String> used, String? pref, {bool forced = false}) {
    var cands = candidatesFor(s, muscle, equipment, used, now, avoid: avoid);
    if (cands.isEmpty && forced) cands = candidatesFor(s, muscle, equipment, used, now);
    if (cands.isEmpty) return null;""")

# the options
sub("""    this.muscles = const [], this.excluded = const {}, this.leftOut = const {}, this.liftInstead = false, this.shuffle,
  });""", """    this.muscles = const [], this.excluded = const {}, this.leftOut = const {}, this.liftInstead = false, this.shuffle, this.manual = false,
  });""")
sub("""  final List<String> muscles;               // muscles forced today (the muscle plan), strained or not, in the user's order
  final Set<String> excluded;               // muscles excluded today: never picked, not even to fill spare minutes
  final int? shuffle;                       // a seed: the places after the forced muscles go to ready muscles at random, not by share""",
    """  final List<String> muscles;               // muscles forced today (the muscle plan), strained or not, in the user's order
  final Set<String> excluded;               // muscles excluded today: never a place, and no exercise works one as a main muscle
  final int? shuffle;                       // a seed: the places after the forced muscles go to ready muscles at random, not by share
  final bool manual;                        // only the forced muscles: nothing else takes a place, not even spare minutes""")

# building: the selection takes the excluded muscles; forced ones fall back; manual blocks the rest
sub("shareOver(s, now), equipment, shuffle: o.shuffle);", "shareOver(s, now), equipment, shuffle: o.shuffle, avoid: o.excluded);")
sub("""  final blocked = <String>{...o.excluded};""", """  final blocked = <String>{...o.excluded, if (o.manual) ...trackedMuscles.where((m) => !o.muscles.contains(m))};""")
sub("""    final pick = sel.bestFor(mus, used, o.picks[key]);
    if (pick == null) continue;""", """    final pick = sel.bestFor(mus, used, o.picks[key], forced: true);
    if (pick == null) continue;""")

# swaps and reshuffles keep clear of the excluded muscles
sub("""List<Exercise> alternatives(AppState s, Session session, int idx, Iterable<String> equipment, DateTime now) {""",
    """List<Exercise> alternatives(AppState s, Session session, int idx, Iterable<String> equipment, DateTime now, {Set<String> avoid = const {}}) {""")
sub("""  return candidatesFor(s, e.muscle, equipment, session.exercises.map((x) => x.exId), now)..sort((a, b) => sel.compare(a, b));""",
    """  return candidatesFor(s, e.muscle, equipment, session.exercises.map((x) => x.exId), now, avoid: avoid)..sort((a, b) => sel.compare(a, b));""")
sub("""Map<String, String> shufflePicks(AppState s, Session session, Iterable<String> equipment, Random rng, DateTime now) {""",
    """Map<String, String> shufflePicks(AppState s, Session session, Iterable<String> equipment, Random rng, DateTime now, {Set<String> avoid = const {}}) {""")
sub("""    final alts = candidatesFor(s, e.muscle, equipment, [...used, e.exId], now)..sort((a, b) => sel.compare(a, b));
    final ranked = (alts.isEmpty ? candidatesFor(s, e.muscle, equipment, used, now) : alts)""",
    """    final alts = candidatesFor(s, e.muscle, equipment, [...used, e.exId], now, avoid: avoid)..sort((a, b) => sel.compare(a, b));
    final ranked = (alts.isEmpty ? candidatesFor(s, e.muscle, equipment, used, now, avoid: avoid) : alts)""")

# the name
sub("""/// A workout's name: every muscle it works, in order, as a day: "Chest day", "Back and biceps day",
/// "Back, triceps and forearms day".""", """/// A workout's name: every muscle it works, in order, as a day: "Chest day", "Lats and biceps day",
/// "Upper back, triceps and forearms day".""")

if crlf:
    s = s.replace('\n', '\r\n')
p.write_bytes(s.encode('utf-8'))
print('ok')
