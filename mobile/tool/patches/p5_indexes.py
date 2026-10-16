import io, re, os
def patch(path, pairs):
    t = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert old in t, (path, old[:60])
        t = t.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(t)

# model.dart: Settings.index, drop AppState.custom
patch('lib/data/model.dart', [
    ("import 'library.dart';\n", "import 'index.dart';\nimport 'library.dart';\n"),
    ("  bool circuit = false;  // last chosen workout mode\n",
     "  bool circuit = false;  // last chosen workout mode\n  ExerciseIndex index = ExerciseIndex.muscle;  // how the library is grouped for browsing\n"),
    ("'location': location, 'circuit': circuit,\n", "'location': location, 'circuit': circuit, 'index': _e(index),\n"),
    ("    ..circuit = j['circuit'] ?? false;\n", "    ..circuit = j['circuit'] ?? false\n    ..index = _p(ExerciseIndex.values, j['index'], ExerciseIndex.muscle);\n"),
    ("  List<Exercise> custom = [];    // exercises the user made\n", ""),
    ("        'custom': custom.map((e) => e.toJson()).toList(),\n", ""),
    ("    final custom = ((j['custom'] ?? []) as List).map((e) => Exercise.fromJson(e)).toList();\n    setCustomExercises(custom);\n    final s = AppState()\n      ..custom = custom\n",
     "    final s = AppState()\n"),
])

# library.dart: drop custom field, JSON, registry
patch('lib/data/library.dart', [
    ("this.ladder, this.bwRange, this.custom = false,\n", "this.ladder, this.bwRange,\n"),
    ("""  /// Made by the user in the app.
  final bool custom;

  bool get loaded => ladder == null;

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'pattern': pattern, 'needs': needs, 'cost': cost, 'rank': rank, 'primary': primary, 'secondary': secondary, 'how': how,
        'startKg': startKg, 'stepKg': stepKg, 'each': each, 'repLabel': repLabel, 'ladder': ladder?.toJson(),
        'bwRange': bwRange == null ? null : [bwRange!.lo, bwRange!.hi],
      };
  static Exercise fromJson(Map<String, dynamic> j) => Exercise(
        id: j['id'], name: j['name'], pattern: j['pattern'], needs: (j['needs'] as List).map((n) => List<String>.from(n)).toList(), cost: j['cost'], rank: j['rank'] ?? 99,
        primary: List<String>.from(j['primary'] ?? []), secondary: List<String>.from(j['secondary'] ?? []), how: j['how'] ?? '',
        startKg: j['startKg'] == null ? null : (j['startKg'] as List).map((x) => (x as num).toDouble()).toList(), stepKg: (j['stepKg'] as num?)?.toDouble(),
        each: j['each'] ?? false, repLabel: j['repLabel'] ?? 'reps', ladder: j['ladder'] == null ? null : Ladder.fromJson(j['ladder']),
        bwRange: j['bwRange'] == null ? null : RepRange(j['bwRange'][0], j['bwRange'][1]), custom: true,
      );
}
""", """  bool get loaded => ladder == null;
}
"""),
    ("""/// Exercises the user made in the app. Set from the store on load and whenever they change.
List<Exercise> _custom = const [];
Map<String, Exercise> _byId = {for (final e in _builtIn) e.id: e};

List<Exercise> get builtInExercises => _builtIn;
List<Exercise> get customExercises => _custom;
List<Exercise> get exercises => [..._builtIn, ..._custom];
Map<String, Exercise> get exerciseById => _byId;

void setCustomExercises(List<Exercise> list) {
  _custom = List.unmodifiable(list);
  _byId = {for (final e in _builtIn) e.id: e, for (final e in _custom) e.id: e};
}
""", """final List<Exercise> exercises = List.unmodifiable(_builtIn);
final Map<String, Exercise> exerciseById = {for (final e in _builtIn) e.id: e};
"""),
])

patch('lib/data/store.dart', [("    state = AppState();\n    setCustomExercises(const []);\n", "    state = AppState();\n")])
patch('lib/ui/widgets.dart', [("IconData exerciseIcon(Exercise e) => e.custom ? LucideIcons.pencil : e.loaded", "IconData exerciseIcon(Exercise e) => e.loaded")])

# tests: drop the custom group and setUp
t = io.open('test/features_test.dart', encoding='utf-8').read()
t = t.replace("  setUp(() => setCustomExercises(const []));\n\n", "")
t = re.sub(r"  group\('custom exercises', \{.*?\n  \}\);\n\n", "", t, flags=re.S)
t = t.replace("import 'dart:convert';\n\n", "")
io.open('test/features_test.dart', 'w', encoding='utf-8', newline='\n').write(t)
os.remove('lib/ui/custom_exercise.dart')
print('ok')
