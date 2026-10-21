"""Model and after-workout code per muscle: emphasis migrates from groups, asked entries are muscles. CRLF kept."""
import pathlib, sys

root = pathlib.Path(__file__).resolve().parents[2]

def patch(rel, pairs):
    p = root / rel
    b = p.read_bytes()
    crlf = b'\r\n' in b
    s = b.decode('utf-8').replace('\r\n', '\n')
    for old, new in pairs:
        if old not in s:
            sys.exit(f'{rel}: not found: {old[:80]!r}')
        s = s.replace(old, new, 1)
    if crlf:
        s = s.replace('\n', '\r\n')
    p.write_bytes(s.encode('utf-8'))

patch('lib/data/index.dart', [
    ("""/// The group a muscle folds onto, or 'Other' (the shins).
String muscleGroup(String muscle) => _muscleFold[muscle] ?? 'Other';
""", """/// The group a muscle folds onto, or 'Other' (the shins). Groups are for browsing the library; selection, its ledgers
/// and the muscle picker run on the muscles themselves.
String muscleGroup(String muscle) => _muscleFold[muscle] ?? 'Other';

/// The muscles that fold onto a group: how a setting saved per group spreads to its muscles.
List<String> musclesOfGroup(String group) => [for (final m in trackedMuscles) if (muscleGroup(m) == group) m];
"""),
])

patch('lib/data/model.dart', [
    ("""  int emphasisOf(String group) => emphasis[group] ?? 0;""", """  int emphasisOf(String muscle) => emphasis[muscle] ?? 0;"""),
    ("""  double targetFor(String group, int daysPerWeek) => targetSets(daysPerWeek) * emphasisShare[emphasisOf(group)]!;""",
     """  double targetFor(String muscle, int daysPerWeek) => targetSets(daysPerWeek) * emphasisShare[emphasisOf(muscle)]!;"""),
    ("""  void setEmphasis(String group, int v) {
    if (v == 0) { emphasis.remove(group); } else { emphasis[group] = v.clamp(-1, 1); }""",
     """  void setEmphasis(String muscle, int v) {
    if (v == 0) { emphasis.remove(muscle); } else { emphasis[muscle] = v.clamp(-1, 1); }"""),
    ("""      emphasis: (j['emphasis'] as Map? ?? {}).map((k, v) => MapEntry(k as String, (v as int).clamp(-1, 1)))..removeWhere((k, v) => v == 0 || !muscleGroups.contains(k)),""",
     """      emphasis: _emphasisFrom(j['emphasis'] as Map? ?? {}),"""),
    ("""/// The muscle group an exercise is filed under: its first primary muscle's. For older sessions that carried no muscle.
String _groupOf(String exId) {
  final ex = exerciseById[exId];
  return ex == null || ex.primary.isEmpty ? 'Other' : muscleGroup(ex.primary.first);
}""", """/// The muscle an exercise is filed under: its first primary muscle. For older sessions that carried no muscle.
String _groupOf(String exId) {
  final ex = exerciseById[exId];
  return ex == null || ex.primary.isEmpty ? 'other' : ex.primary.first;
}

/// Emphasis as saved: per muscle, or per group before selection ran on muscles, when a group's word spreads to each
/// of its muscles. A muscle's own word wins over its group's.
Map<String, int> _emphasisFrom(Map j) {
  final out = <String, int>{};
  for (final e in j.entries) {
    final v = (e.value as int).clamp(-1, 1);
    if (v == 0 || !muscleGroups.contains(e.key)) continue;
    for (final m in musclesOfGroup(e.key as String)) { out[m] = v; }
  }
  for (final e in j.entries) {
    final v = (e.value as int).clamp(-1, 1);
    if (trackedMuscles.contains(e.key)) { if (v == 0) { out.remove(e.key); } else { out[e.key as String] = v; } }
  }
  return out;
}"""),
    ("""  List<({String group, DateTime at})> asked = [];  // muscles asked for by hand, for the one line suggesting more emphasis
  List<String> moreSuggested = [];                 // groups that line has been said for""",
     """  List<({String muscle, DateTime at})> asked = [];  // muscles asked for by hand, for the one line suggesting more emphasis
  List<String> moreSuggested = [];                  // muscles that line has been said for"""),
    ("""        'asked': [for (final a in asked) {'g': a.group, 'at': _ms(a.at)}], 'moreSuggested': moreSuggested,""",
     """        'asked': [for (final a in asked) {'g': a.muscle, 'at': _ms(a.at)}], 'moreSuggested': moreSuggested,"""),
    ("""    ..asked = [for (final a in (j['asked'] as List? ?? [])) (group: a['g'] as String, at: _d(a['at'])!)]
    ..moreSuggested = List<String>.from(j['moreSuggested'] ?? []);""",
     """    // entries from before selection ran on muscles named groups: they are dropped, the window is two weeks anyway
    ..asked = [for (final a in (j['asked'] as List? ?? [])) if (trackedMuscles.contains(a['g'])) (muscle: a['g'] as String, at: _d(a['at'])!)]
    ..moreSuggested = [for (final m in List<String>.from(j['moreSuggested'] ?? [])) if (trackedMuscles.contains(m)) m];"""),
])

patch('lib/logic/selection.dart', [
    ("""  for (final a in p.asked) { if (!a.at.isBefore(since)) counts[a.group] = (counts[a.group] ?? 0) + 1; }""",
     """  for (final a in p.asked) { if (!a.at.isBefore(since)) counts[a.muscle] = (counts[a.muscle] ?? 0) + 1; }"""),
])

patch('lib/logic/after.dart', [
    ("""/// emphasis for the group. Never a change.""", """/// emphasis for the muscle. Never a change."""),
    ("""    if (e.asked && e.attempted.isNotEmpty) p.asked.add((group: e.muscle, at: now));""",
     """    if (e.asked && e.attempted.isNotEmpty) p.asked.add((muscle: e.muscle, at: now));"""),
    ("""  for (final grp in moreSuggestions(s, now)) {
    p.moreSuggested.add(grp);
    lines.add('You keep asking for ${grp.toLowerCase()}. Set it to more in Settings → Goal if you like.');""",
     """  for (final m in moreSuggestions(s, now)) {
    p.moreSuggested.add(m);
    lines.add('You keep asking for $m. Set it to more in Settings → Goal if you like.');"""),
])
print('ok')
