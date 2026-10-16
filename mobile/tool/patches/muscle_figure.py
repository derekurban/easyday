import os
# ---- logic: dataset groups, workout muscles, recency by dataset group
p='lib/logic/muscles.dart'
s=open(p,encoding='utf-8').read()
s=s.replace('''/// A muscle group's work fades to nothing over this many days.''','''/// The muscle-map dataset's 17 groups folded onto the app's eleven. The shin (tibialis) has no group and never highlights.
const datasetToAppGroup = {
  'abdominals': 'Core', 'abductors': 'Glutes', 'adductors': 'Quads', 'biceps': 'Biceps', 'calves': 'Calves', 'chest': 'Chest',
  'forearms': 'Forearms', 'glutes': 'Glutes', 'hamstrings': 'Hamstrings', 'lats': 'Back', 'lower back': 'Core', 'middle back': 'Back',
  'quadriceps': 'Quads', 'shoulders': 'Shoulders', 'traps': 'Back', 'triceps': 'Triceps',
};

String? appGroupOf(String datasetGroup) => datasetToAppGroup[datasetGroup];

/// A library muscle name as the dataset spells it.
String datasetGroupOf(String libraryMuscle) => switch (libraryMuscle) { 'middleback' => 'middle back', 'lowerback' => 'lower back', _ => libraryMuscle };

/// The muscles a workout uses, by dataset group: the exercises' primary muscles strong, their secondary ones light.
Map<String, double> workoutMuscles(Session x) {
  final out = <String, double>{};
  if (x.type != 'lift') return out;
  for (final e in x.exercises) {
    for (final m in e.exercise.primary) { out[datasetGroupOf(m)] = 1.0; }
    for (final m in e.exercise.secondary) { final g = datasetGroupOf(m); out[g] = max(out[g] ?? 0, 0.5); }
  }
  return out;
}

/// An app-group map spread over the dataset groups it folds, for the figure.
Map<String, double> byDatasetGroup(Map<String, double> byApp) =>
    {for (final e in datasetToAppGroup.entries) if ((byApp[e.value] ?? 0) > 0) e.key: byApp[e.value]!};

/// A muscle group's work fades to nothing over this many days.''',1)
open(p,'w',encoding='utf-8').write(s)

# ---- today: the workout's muscles only
p='lib/ui/today.dart'
s=open(p,encoding='utf-8').read()
old="""    final worked = recentWork(s, now);
    final targets = plannedTargets(session);
"""
assert old in s
s=s.replace(old,"    final muscles = workoutMuscles(session);\n",1)
old="""                      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        BodyMap(fill: worked, outline: targets.keys.toSet(), height: 150),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          for (final line in _whyLines(targets, worked, s, now))
                            Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(line, style: t.bodySmall?.copyWith(color: du.ink))),
                          Text('Outlined: today. Filled: worked lately, fading over $muscleFadeDays days.', style: t.labelSmall),
                        ])),
                      ]),"""
new="""                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        MuscleFigure(highlight: muscles, height: 170, legend: 'Dark: the main muscles. Light: helping. Tap one to name it.'),
                        const SizedBox(width: 14),
                        Expanded(child: Padding(padding: const EdgeInsets.only(top: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          for (final line in _whyLines(muscles))
                            Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(line, style: t.bodySmall?.copyWith(color: du.ink))),
                        ]))),
                      ]),"""
assert old in s
s=s.replace(old,new,1)
a=s.index("  /// Why these exercises: what today targets")
b=s.index("  Widget _doneForToday(")
s=s[:a]+'''  /// What the workout works: the main muscles, then the helping ones.
  List<String> _whyLines(Map<String, double> muscles) {
    String names(Iterable<String> xs) {
      final l = xs.toList();
      return l.length <= 1 ? l.join() : '${l.sublist(0, l.length - 1).join(', ')} and ${l.last}';
    }
    final main = muscles.entries.where((e) => e.value >= primaryStrength).map((e) => e.key).toList();
    final helping = muscles.entries.where((e) => e.value < primaryStrength).map((e) => e.key).toList();
    return [
      if (main.isNotEmpty) 'Works ${names(main)}.',
      if (helping.isNotEmpty) 'Also ${names(helping)}.',
    ];
  }

'''+s[b:]
s=s.replace("import 'body_map.dart';","import 'muscle_figure.dart';",1)
open(p,'w',encoding='utf-8').write(s)

# ---- progress: recency on the figure
p='lib/ui/progress.dart'
s=open(p,encoding='utf-8').read()
s=s.replace("import 'body_map.dart';","import 'muscle_figure.dart';",1)
old="""            BodyMap(fill: worked, height: 180),"""
new="""            MuscleFigure(highlight: byDatasetGroup(worked), height: 190),"""
assert old in s
s=s.replace(old,new,1)
open(p,'w',encoding='utf-8').write(s)

# ---- tests
p='test/features_test.dart'
s=open(p,encoding='utf-8').read()
s=s.replace("import 'package:fitness/ui/body_map.dart';\n","")
old="""    test('the level history folds a hard day back"""
new="""    test('a workout highlights its exercises\\' primary muscles strong and secondary ones light, by dataset group', () {
      final s = fresh(template: 'gym');
      final session = buildSession(s, BuildOptions(energy: Energy.normal, minutes: 45), t0);
      final m = workoutMuscles(session);
      final first = session.exercises[0].exercise;
      expect(m[datasetGroupOf(first.primary.first)], primaryStrength);
      final secondaryOnly = session.exercises.expand((e) => e.exercise.secondary).map(datasetGroupOf).where((g) => !session.exercises.any((e) => e.exercise.primary.map(datasetGroupOf).contains(g)));
      for (final g in secondaryOnly) { expect(m[g], secondaryStrength, reason: g); }
      for (final g in m.keys) { expect(datasetToAppGroup.keys, contains(g), reason: g); }
      final spread = byDatasetGroup({'Back': 0.8, 'Core': 0.2});
      expect(spread['lats'], 0.8);
      expect(spread['traps'], 0.8);
      expect(spread['lower back'], 0.2);
      expect(spread.containsKey('chest'), isFalse);
    });

    test('the level history folds a hard day back"""
assert old in s
s=s.replace(old,new,1)
s=s.replace("import 'package:fitness/logic/muscles.dart';","import 'package:fitness/logic/muscles.dart';\nimport 'package:fitness/ui/muscle_figure.dart';",1)
open(p,'w',encoding='utf-8').write(s)

os.remove('lib/ui/body_map.dart')
print('ok')
