import io
p = 'lib/data/library.dart'
s = io.open(p, encoding='utf-8').read()
n0 = len(s)

def rep(a, b):
    global s
    assert a in s, a[:60]
    s = s.replace(a, b)

rep("""/// One notch on a bodyweight ladder.
class Variant {
  const Variant(this.name, [this.note]);
  final String name;
  final String? note;
}""", """/// One level of a bodyweight progression. [how] overrides the exercise description at this level.
class Variant {
  const Variant(this.name, [this.note, this.how]);
  final String name;
  final String? note;
  final String? how;
  Map<String, dynamic> toJson() => {'name': name, 'note': note, 'how': how};
  static Variant fromJson(Map<String, dynamic> j) => Variant(j['name'], j['note'], j['how']);
}""")

rep("""class Ladder {
  const Ladder(this.variants, {this.start = const [0, 1, 2], this.loadGear = const [], this.loadStep = 2.5});""",
"""class Ladder {
  const Ladder(this.variants, {this.start = const [0, 1, 2], this.loadGear = const [], this.loadStep = 2.5});
  Map<String, dynamic> toJson() => {'variants': variants.map((v) => v.toJson()).toList(), 'start': start, 'loadGear': loadGear, 'loadStep': loadStep};
  static Ladder fromJson(Map<String, dynamic> j) => Ladder((j['variants'] as List).map((v) => Variant.fromJson(v)).toList(),
      start: List<int>.from(j['start'] ?? [0, 1, 2]), loadGear: List<String>.from(j['loadGear'] ?? []), loadStep: (j['loadStep'] as num?)?.toDouble() ?? 2.5);""")

rep("""    this.startKg, this.stepKg, this.each = false, this.repLabel = 'reps', this.ladder, this.bwRange,
  });""", """    this.startKg, this.stepKg, this.each = false, this.repLabel = 'reps', this.ladder, this.bwRange, this.custom = false,
  });""")

rep("""  /// Bodyweight exercises: a sensible floor for the rep range when the goal's range is lower.
  final RepRange? bwRange;

  bool get loaded => ladder == null;
}""", """  /// Bodyweight exercises: a sensible floor for the rep range when the goal's range is lower.
  final RepRange? bwRange;
  /// Made by the user in the app.
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

/// How to perform an exercise at a given level: the level's own text, the library's per-level text, or the base
/// description with the level's note folded in.
String howAt(Exercise ex, int rung) {
  final l = ex.ladder;
  if (l == null || rung < 0) return ex.how;
  if (rung >= l.variants.length) return '${ex.how} Add load with ${l.loadGear.map((g) => equipment[g]!.toLowerCase()).join(' or ')}.';
  final v = l.variants[rung];
  if (v.how != null && v.how!.isNotEmpty) return v.how!;
  if (bandLadders.contains(ex.id)) return '${ex.how} ${bandLevels[rung.clamp(0, bandLevels.length - 1)]}';
  final table = levelHow[ex.id];
  final fromTable = table != null && rung < table.length ? table[rung] : null;
  if (fromTable != null) return fromTable;
  if (v.note != null && v.note!.isNotEmpty) {
    final n = v.note!;
    return '${ex.how} ${n[0].toUpperCase()}${n.substring(1)}${n.endsWith('.') ? '' : '.'}';
  }
  return ex.how;
}""")

rep("final List<Exercise> exercises = [\n  // ---------- push", "final List<Exercise> _builtIn = [\n  // ---------- push")

rep("""final Map<String, Exercise> exerciseById = {for (final e in exercises) e.id: e};""",
"""/// Exercises the user made in the app. Set from the store on load and whenever they change.
List<Exercise> _custom = const [];
Map<String, Exercise> _byId = {for (final e in _builtIn) e.id: e};

List<Exercise> get builtInExercises => _builtIn;
List<Exercise> get customExercises => _custom;
List<Exercise> get exercises => [..._builtIn, ..._custom];
Map<String, Exercise> get exerciseById => _byId;

void setCustomExercises(List<Exercise> list) {
  _custom = List.unmodifiable(list);
  _byId = {for (final e in _builtIn) e.id: e, for (final e in _custom) e.id: e};
}""")

rep("""const liftItems = [
  RotationItem(name: 'Day A', focus: 'squat first', mains: ['squat', 'push', 'pull'], accs: ['core']),
  RotationItem(name: 'Day B', focus: 'hinge first', mains: ['hinge', 'pull', 'push'], accs: ['carry', 'arms']),
  RotationItem(name: 'Day C', focus: 'squat and pull first', mains: ['squat', 'pull', 'push'], accs: ['shoulders', 'legs']),
  RotationItem(name: 'Day D', focus: 'hinge and push first', mains: ['hinge', 'push', 'pull'], accs: ['arms', 'core']),
];""", """const liftItems = [
  RotationItem(name: 'Workout A', focus: 'legs, chest, back', mains: ['squat', 'push', 'pull'], accs: ['core']),
  RotationItem(name: 'Workout B', focus: 'hips, back, chest', mains: ['hinge', 'pull', 'push'], accs: ['carry', 'arms']),
  RotationItem(name: 'Workout C', focus: 'legs, back, chest', mains: ['squat', 'pull', 'push'], accs: ['shoulders', 'legs']),
  RotationItem(name: 'Workout D', focus: 'hips, chest, back', mains: ['hinge', 'push', 'pull'], accs: ['arms', 'core']),
];""")

rep("// Exercise library, equipment, patterns, goals, ladders. Pure data and small pure helpers. No app state here.\n",
    "// Exercise library, equipment, patterns, goals, progressions. Pure data and small pure helpers.\nimport 'howto.dart';\n")

io.open(p, 'w', encoding='utf-8').write(s)
print('library ok', n0, '->', len(s))
