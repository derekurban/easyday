"""The existing tests name muscles instead of groups. CRLF kept."""
import pathlib, sys

root = pathlib.Path(__file__).resolve().parents[2]

def patch(rel, pairs, everywhere=()):
    p = root / rel
    b = p.read_bytes()
    crlf = b'\r\n' in b
    s = b.decode('utf-8').replace('\r\n', '\n')
    for old, new in pairs:
        if old not in s:
            sys.exit(f'{rel}: not found: {old[:80]!r}')
        s = s.replace(old, new, 1)
    for old, new in everywhere:
        s = s.replace(old, new)
    if crlf:
        s = s.replace('\n', '\r\n')
    p.write_bytes(s.encode('utf-8'))

patch('test/features_test.dart', [
    ("""      expect(first.exercises.first.muscle, 'Quads', reason: 'nothing separates the groups yet: the big movers first');""",
     """      expect(first.exercises.first.muscle, 'quads', reason: 'nothing separates the muscles yet: the big movers first');"""),
    ("""      expect(first.exercises.map((e) => e.muscle), contains('Chest'));""", """      expect(first.exercises.map((e) => e.muscle), contains('chest'));"""),
    ("""      final chestFirst = first.exercises.firstWhere((e) => e.muscle == 'Chest');
      final picked = buildSession(s, BuildOptions(energy: Energy.normal, minutes: 45, muscles: const ['Chest'], picks: {'Chest1': chestFirst.exId}), day1);
      final chest = picked.exercises.firstWhere((e) => e.muscle == 'Chest');""",
     """      final chestFirst = first.exercises.firstWhere((e) => e.muscle == 'chest');
      final picked = buildSession(s, BuildOptions(energy: Energy.normal, minutes: 45, muscles: const ['chest'], picks: {'chest1': chestFirst.exId}), day1);
      final chest = picked.exercises.firstWhere((e) => e.muscle == 'chest');"""),
    ("""      // the share ledger: a set to each main muscle's group, a half to each helper's; behind under half the target
      final share = shareOver(s, day1);
      expect(share.of('Quads'), 3);
      expect(share.band('Quads'), 0);
      expect(share.band('Forearms'), 0);
      expect(share.deficit('Forearms'), greaterThan(share.deficit('Quads')));""",
     """      // the share ledger: a set to each main muscle, a half to each helper; behind under half the target
      final share = shareOver(s, day1);
      expect(share.of('quads'), 3);
      expect(share.band('quads'), 0);
      expect(share.band('forearms'), 0);
      expect(share.deficit('forearms'), greaterThan(share.deficit('quads')));"""),
    ("""      s.goal!.setEmphasis('Calves', 1);
      expect(build(s).exercises.first.muscle, 'Calves');
      s.goal!.setEmphasis('Calves', 0);""", """      s.goal!.setEmphasis('calves', 1);
      expect(build(s).exercises.first.muscle, 'calves');
      s.goal!.setEmphasis('calves', 0);"""),
    ("""      s.goal!.setEmphasis('Quads', 1);""", """      s.goal!.setEmphasis('quads', 1);"""),
    ("""      expect(next.exercises.single.muscle, 'Quads');""", """      expect(next.exercises.single.muscle, 'quads');"""),
    ("""      expect(g.targetFor('Back', 3), 8);
      g.setEmphasis('Back', 1);
      expect(g.targetFor('Back', 3), 12);
      final back = GoalConfig.fromJson(jsonDecode(jsonEncode(g.toJson())));
      expect(back.emphasisOf('Back'), 1);""", """      expect(g.targetFor('lats', 3), 8);
      g.setEmphasis('lats', 1);
      expect(g.targetFor('lats', 3), 12);
      final back = GoalConfig.fromJson(jsonDecode(jsonEncode(g.toJson())));
      expect(back.emphasisOf('lats'), 1);
      // emphasis saved per group before selection ran on muscles spreads to the group's muscles; a muscle's own word wins
      final old = GoalConfig.fromJson({...g.toJson(), 'emphasis': {'Back': 1, 'Core': -1, 'traps': 0}});
      expect(old.emphasisOf('lats'), 1);
      expect(old.emphasisOf('upper back'), 1);
      expect(old.emphasisOf('traps'), 0);
      expect(old.emphasisOf('abs'), -1);
      expect(old.emphasisOf('lower back'), -1);
      expect(old.emphasisOf('chest'), 0);
      expect(old.emphasis.keys.every(trackedMuscles.contains), isTrue);"""),
], everywhere=[
    ("primaryGroups(e).contains('Quads')", "e.primary.contains('quads')"),
    ("e.muscle == 'Quads'", "e.muscle == 'quads'"),
    ("muscles: const ['Quads']", "muscles: const ['quads']"),
])

patch('test/logic_test.dart', [
    ("""const quads = ['Quads'];
const chest = ['Chest'];""", """const quads = ['quads'];
const chest = ['chest'];"""),
    ("""      s.goal!.setEmphasis('Calves', 1);
      final sess = build(s, minutes: 60, muscles: const ['Calves']);
      expect(sess.exercises.first.muscle, 'Calves',""", """      s.goal!.setEmphasis('calves', 1);
      final sess = build(s, minutes: 60, muscles: const ['calves']);
      expect(sess.exercises.first.muscle, 'calves',"""),
    ("""      expect(alts.every((e) => primaryGroups(e).contains(sess.exercises[0].muscle)), isTrue);""",
     """      expect(alts.every((e) => e.primary.contains(sess.exercises[0].muscle)), isTrue);"""),
    ("""      for (final e in sess.exercises) { expect(primaryGroups(exerciseById[picks[e.slot]]!), contains(e.muscle)); }""",
     """      for (final e in sess.exercises) { expect(exerciseById[picks[e.slot]]!.primary, contains(e.muscle)); }"""),
])
print('ok')
