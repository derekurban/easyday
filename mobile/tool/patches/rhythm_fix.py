"""Loose ends after the rhythm patches: defaultTag lives in index.dart, imports, settings copy, the tests. CRLF kept."""
import pathlib, sys

mobile = pathlib.Path(__file__).resolve().parents[2]

def load(rel):
    p = mobile / rel
    b = p.read_bytes()
    return p, (b'\r\n' in b), b.decode('utf-8').replace('\r\n', '\n')

def save(p, crlf, s):
    p.write_bytes((s.replace('\n', '\r\n') if crlf else s).encode('utf-8'))

def sub(s, old, new, name, count=1):
    if old not in s:
        sys.exit(f'{name}: not found: {old[:90]!r}')
    return s.replace(old, new, count)

# defaultTag moves to index.dart, which already imports the library
p, crlf, s = load('lib/data/library.dart')
start = "/// A muscle's tag by template (SELECTION.md)"
a = s.index(start); z = s.index("}\n", a) + 2
block = s[a:z]
s = s[:a] + s[z:]
s = s.replace("import 'index.dart';\n", "")
save(p, crlf, s)
p, crlf, s = load('lib/data/index.dart')
s = s.rstrip('\n') + '\n\n' + block
save(p, crlf, s)

p, crlf, s = load('lib/logic/after.dart')
if "import '../data/index.dart';" not in s:
    s = sub(s, "import '../data/library.dart';\n", "import '../data/index.dart';\nimport '../data/library.dart';\n", 'after')
save(p, crlf, s)

p, crlf, s = load('lib/ui/settings.dart')
s = sub(s, """hint: 'Seeds the sets each muscle group aims for over ${g.lookBackDays} days: ${g.targetSets(s.profile!.daysPerWeek)} now${g.setsTarget == null ? '' : ', set by hand in the goal'}.'""",
        """hint: 'There are no fixed days. This only sets the pace the forecast in your goal assumes.'""", 'settings')
save(p, crlf, s)

p, crlf, s = load('lib/ui/progress.dart')
s = sub(s, "    String n(double x) => x == x.roundToDouble() ? '${x.round()}' : x.toStringAsFixed(1);\n", "", 'progress')
s = sub(s, "import '../logic/selection.dart';\n", "", 'progress')
save(p, crlf, s)

p, crlf, s = load('lib/ui/goal_editor.dart')
s = sub(s, "import '../data/index.dart';\n", "", 'goal_editor')
save(p, crlf, s)

p, crlf, s = load('lib/ui/muscle_tags.dart')
s = sub(s, "import 'widgets.dart';\n", "", 'muscle_tags')
save(p, crlf, s)

# ---- the tests
p, crlf, s = load('test/features_test.dart')
s = sub(s, """      // the share ledger: a set to each main muscle, a half to each helper; behind under half the target
      final share = shareOver(s, day1);
      expect(share.of('quads'), 3);
      expect(share.band('quads'), 0);
      expect(share.band('biceps'), 0);
      expect(share.deficit('biceps'), greaterThan(share.deficit('quads')));""",
        """      // the rhythm: the quads were a main muscle last workout; the biceps only helped, so they are never worked and more overdue
      final rhythm = rhythmOver(s, day1);
      expect(rhythm.sinceOf('quads'), 0);
      expect(rhythm.neverWorked('biceps'), isTrue);
      expect(rhythm.overdue('biceps'), greaterThan(rhythm.overdue('quads')));""", 'features')
s = sub(s, """      // emphasis: more keeps a muscle behind for longer, so it is picked first among equals
      s.goal!.setEmphasis('calves', 1);
      expect(build(s).exercises.first.muscle, 'calves');
      s.goal!.setEmphasis('calves', 0);""",
        """      // more often: a muscle's turn is twice as overdue, so among muscles never worked it goes first
      s.goal!.setOften('calves', 1);
      expect(build(s).exercises.first.muscle, 'calves');
      s.goal!.setOften('calves', 0);""", 'features')
s = sub(s, """      // the squat has had two workouts in a row for the quads; with more emphasis and a high target the quads stay behind
      // and lead, so a one-exercise workout's only place is theirs
      s.goal!.setEmphasis('quads', 1);
      s.goal!.setsTarget = 30;""",
        """      // the squat has had two workouts in a row for the quads; with every other muscle ignored, a one-exercise workout's
      // only place is theirs
      for (final m in trackedMuscles) { if (m != 'quads') s.goal!.setTag(m, MuscleTag.ignored); }""", 'features')
s = sub(s, """      expect(g.lookBackDays, lookBackDefault);
      expect(g.setsTarget, isNull);
      expect(g.targetSets(3), 8);
      expect(g.targetFor('lats', 3), 8);
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
      expect(old.emphasis.keys.every(trackedMuscles.contains), isTrue);""",
        """      expect(g.often, isEmpty);
      expect(g.tagOf('lats'), MuscleTag.active);
      expect(g.tagOf('forearms'), MuscleTag.passive, reason: 'get stronger marks the big movers active');
      expect(g.tagOf('shins'), MuscleTag.ignored);
      g.setOften('lats', 1);
      g.setTag('forearms', MuscleTag.active);
      final back = GoalConfig.fromJson(jsonDecode(jsonEncode(g.toJson())));
      expect(back.oftenOf('lats'), 1);
      expect(back.tagOf('forearms'), MuscleTag.active);
      // emphasis, the old name for how often, saved per group before selection ran on muscles, spreads to the group's
      // muscles; a muscle's own word wins
      final old = GoalConfig.fromJson({...g.toJson(), 'often': null, 'emphasis': {'Back': 1, 'Core': -1, 'traps': 0}});
      expect(old.oftenOf('lats'), 1);
      expect(old.oftenOf('upper back'), 1);
      expect(old.oftenOf('traps'), 0);
      expect(old.oftenOf('abs'), -1);
      expect(old.oftenOf('lower back'), -1);
      expect(old.oftenOf('chest'), 0);
      expect(old.often.keys.every(trackedMuscles.contains), isTrue);""", 'features')
save(p, crlf, s)

p, crlf, s = load('test/logic_test.dart')
s = sub(s, "      s.goal!.setEmphasis('calves', 1);", "      s.goal!.setOften('calves', 1);", 'logic')
s = sub(s, """      final picks = shufflePicks(s, sess, s.locations.first.equipment, Random(1), t0);
      for (final e in sess.exercises) { expect(exerciseById[picks[e.slot]]!.primary, contains(e.muscle)); }""",
        """      // an exercise shuffle is the cover drawn again: the forced muscles stay covered, and something changes
      final o = BuildOptions(energy: Energy.normal, minutes: 45, muscles: const ['quads', 'glutes'], liftInstead: true);
      final before = buildSession(s, o, t0);
      final seed = nextExerciseSeed(s, o, t0);
      final drawn = buildSession(s, o.copyWith(exerciseSeed: seed), t0);
      expect({for (final e in drawn.exercises) ...e.exercise.primary}, containsAll(['quads', 'glutes']));
      expect({for (final e in drawn.exercises) e.exId}, isNot(equals({for (final e in before.exercises) e.exId})));""", 'logic')
save(p, crlf, s)

p, crlf, s = load('test/muscle_plan_test.dart')
for old, new in [("int? shuffle}", "int? muscleSeed}"), ("shuffle: shuffle", "muscleSeed: muscleSeed"), ("shuffle: 1", "muscleSeed: 1"),
                 ("shuffle: i", "muscleSeed: i"), ("plan.shuffle", "plan.muscleDraw"), ("plan.seed = 3", "plan.muscleSeed = 3")]:
    s = s.replace(old, new)
save(p, crlf, s)
print('ok')
