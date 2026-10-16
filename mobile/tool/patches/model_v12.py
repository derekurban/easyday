import re
p='lib/data/model.dart'
s=open(p,encoding='utf-8').read()

# ---- Settings
a=s.index('/// The six settings of section 9.')
b=s.index('/// What spare minutes are for')
new_settings='''/// The settings of section 9, plus the three integrations and their own settings.
class Settings {
  int stepUp = 1;        // sessions at the top before a rung steps up (1 to 5)
  int stepDown = 2;      // sessions below the bottom before a rung steps down (1 to 5)
  int decayWeeks = 3;    // weeks before an unused rung decays (2 to 8, 0 = off)
  int daysAway = 7;      // days away before easy is the default (5 to 21)
  int painRestDays = 7;  // days a pattern rests after pain (3 to 28)
  // integrations, each off until the user turns it on and grants the permission
  bool notify = false;
  int notifyHour = 18;   // daily reminder hour, 0 to 23
  bool calendar = false;
  int awakeStart = 8 * 60;   // the awake window, minutes of the day
  int awakeEnd = 22 * 60;
  bool busyAdjust = true;    // a busy day makes a lighter day
  int busyShort = 50;        // busy share of the awake window that shortens the default, 30 to 90
  int busyEasy = 70;         // busy share that also makes the default easy, busyShort to 100
  bool autoTrack = false;    // write finished workouts to the calendar
  String? calendarId;        // the calendar to write to; null is the phone's primary
  bool location = false;
  bool circuit = false;  // last chosen workout mode
  ExerciseIndex index = ExerciseIndex.muscle;  // how the library is grouped for browsing

  Map<String, dynamic> toJson() => {
        'stepUp': stepUp, 'stepDown': stepDown, 'decayWeeks': decayWeeks, 'daysAway': daysAway, 'painRestDays': painRestDays,
        'notify': notify, 'notifyHour': notifyHour, 'calendar': calendar, 'awakeStart': awakeStart, 'awakeEnd': awakeEnd,
        'busyAdjust': busyAdjust, 'busyShort': busyShort, 'busyEasy': busyEasy, 'autoTrack': autoTrack, 'calendarId': calendarId,
        'location': location, 'circuit': circuit, 'index': _e(index),
      };
  static Settings fromJson(Map<String, dynamic> j) => Settings()
    ..stepUp = j['stepUp'] ?? 1
    ..stepDown = j['stepDown'] ?? 2
    ..decayWeeks = j['decayWeeks'] ?? 3
    ..daysAway = j['daysAway'] ?? 7
    ..painRestDays = j['painRestDays'] ?? 7
    ..notify = j['notify'] ?? false
    ..notifyHour = j['notifyHour'] ?? 18
    ..calendar = j['calendar'] ?? false
    ..awakeStart = j['awakeStart'] ?? 8 * 60
    ..awakeEnd = j['awakeEnd'] ?? 22 * 60
    ..busyAdjust = j['busyAdjust'] ?? true
    ..busyShort = j['busyShort'] ?? 50
    ..busyEasy = j['busyEasy'] ?? 70
    ..autoTrack = j['autoTrack'] ?? false
    ..calendarId = j['calendarId']
    ..location = j['location'] ?? false
    ..circuit = j['circuit'] ?? false
    ..index = _p(ExerciseIndex.values, j['index'], ExerciseIndex.muscle);
}

'''
s=s[:a]+new_settings+s[b:]

# ---- constants
s=s.replace('''const defaultWorkingSets = 3;
const defaultExtras = 2;
const defaultCardioPct = 15;
const defaultStretchPct = 10;
const maxExercisesMin = 1;
const maxExercisesMax = 10;
''','''const defaultCardioPct = 15;
const defaultStretchPct = 10;
/// The ranges of the three calibrations.
const exercisesMin = 1, exercisesMax = 10;
const setsMin = 1, setsMax = 6;
const pushesMin = 0, pushesMax = 10;
''')

# ---- GoalConfig
a=s.index("/// The user's goal: started from a template")
b=s.index('class Profile {')
new_goal='''/// The user's goal: their own, filled from a template if they like, every knob in plain words. See WORKOUT.md.
class GoalConfig {
  GoalConfig({
    required this.template, required this.name, required List<Band> bands, required this.exercises, required this.sets, required this.pushes,
    required this.moveEvery, this.spare = Spare.exercises, this.cardioPct = defaultCardioPct, this.stretchPct = defaultStretchPct,
  }) : bands = [for (final b in bands) b.copy()];
  String template;       // the template it was last filled from, for the icon
  String name;
  List<Band> bands;      // rep bands, each tagged with the difficulties it applies to; several per difficulty cycle by workout
  Tri exercises;         // different exercises in a workout: the fewest, the ideal, the most (1 to 10)
  Tri sets;              // working sets: the fewest, the usual, the most (1 to 6); progress is the level rising, never the sets
  Tri pushes;            // exercises at the next level on a hard day: on a tight day, usually, on a long day (0 to 10)
  int moveEvery;         // a movement day after every N lifting days (0 = none)
  Spare spare;           // what spare minutes are for
  int cardioPct;         // share of every workout's minutes for cardio at the end
  int stretchPct;        // share for stretching, last

  /// The working set count: the usual.
  int get workingSets => sets.ideal;

  /// The bands for a difficulty, in list order.
  List<RepRange> rowFor(int difficulty) => [for (final b in bands) if (b.difficulties.contains(difficulty)) b.range];

  /// The rows per difficulty, easy first.
  Schemes get schemes => [for (var d = 1; d <= 3; d++) rowFor(d)];

  /// The band an exercise of this difficulty trains in on the nth lifting workout of the rotation. A difficulty with no
  /// band takes the nearest difficulty's, then the middle band.
  RepRange rangeForDifficulty(int difficulty, int liftIndex) {
    final d = difficulty.clamp(1, 3);
    for (final tryD in [d, d - 1, d + 1, d - 2, d + 2]) {
      if (tryD < 1 || tryD > 3) continue;
      final row = rowFor(tryD);
      if (row.isNotEmpty) return row[liftIndex % row.length];
    }
    return middleReps;
  }

  /// The named program these bands match, or null when edited by hand.
  String? get program => programBands.entries.where((e) => _sameBands(e.value(), bands)).map((e) => e.key).firstOrNull;

  static bool _sameBands(List<Band> a, List<Band> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) { if (a[i] != b[i]) return false; }
    return true;
  }

  static GoalConfig fromTemplate(Goal g) => GoalConfig(template: g.id, name: g.name, bands: g.bands(), exercises: g.exercises, sets: g.sets, pushes: g.pushes, moveEvery: g.moveEvery);

  /// Fill every knob from a template, keeping nothing.
  void fill(Goal g) {
    template = g.id;
    name = g.name;
    bands = g.bands();
    exercises = g.exercises;
    sets = g.sets;
    pushes = g.pushes;
    moveEvery = g.moveEvery;
    spare = Spare.exercises;
    cardioPct = defaultCardioPct;
    stretchPct = defaultStretchPct;
  }

  Map<String, dynamic> toJson() => {
        'template': template, 'name': name, 'bands': [for (final b in bands) {'r': _rr(b.range), 'd': b.difficulties.toList()..sort()}],
        'exercises': _tri(exercises), 'sets': _tri(sets), 'pushes': _tri(pushes), 'moveEvery': moveEvery,
        'spare': _e(spare), 'cardioPct': cardioPct, 'stretchPct': stretchPct,
      };
  static GoalConfig fromJson(Map<String, dynamic> j) {
    final tpl = goals[j['template']];
    List<Band> bands;
    if (j['bands'] != null) {
      bands = [for (final b in (j['bands'] as List)) Band(_pr(b['r']), List<int>.from(b['d']))];
    } else if (j['schemes'] != null) {
      bands = _bandsFromSchemes([for (final row in (j['schemes'] as List)) [for (final r in (row as List)) _pr(r)]]);
    } else if (j['reps'] != null && tpl == null) {
      // older data: one preset shifted lighter for easier exercises, or the mixed flag
      final base = _p(Expression.values, j['reps'], Expression.middle);
      bands = j['mixed'] == true ? mixedBands() : _bandsFromSchemes([for (var d = 1; d <= 3; d++) [expressionRange[Expression.values[(base.index + (3 - d)).clamp(0, 2)]]!]]);
    } else {
      bands = (tpl ?? goals['muscle']!).bands();
    }
    final t = tpl ?? goals['muscle']!;
    // older data held one number each: the most exercises, the working sets, the hard-day count (0 = all)
    final int? oldEx = j['maxExercises'] ?? j['lifts'] ?? (j['mains'] == null ? null : (j['mains'] ?? 3) + (j['accs'] ?? 1));
    final int? oldSets = j['workingSets'];
    final int? oldExtras = j['extras'];
    return GoalConfig(
      template: j['template'] ?? 'custom', name: j['name'] ?? 'My goal', bands: bands,
      exercises: j['exercises'] != null ? _ptri(j['exercises']).clampTo(exercisesMin, exercisesMax) : oldEx != null ? Tri(max(1, oldEx ~/ 2), oldEx, oldEx).clampTo(exercisesMin, exercisesMax) : t.exercises,
      sets: j['sets'] != null ? _ptri(j['sets']).clampTo(setsMin, setsMax) : oldSets != null ? Tri(max(1, oldSets - 1), oldSets, oldSets).clampTo(setsMin, setsMax) : t.sets,
      pushes: j['pushes'] != null ? _ptri(j['pushes']).clampTo(pushesMin, pushesMax) : oldExtras != null ? (oldExtras == 0 ? const Tri(2, 5, 10) : Tri(max(0, oldExtras - 1), oldExtras, oldExtras + 1)).clampTo(pushesMin, pushesMax) : t.pushes,
      moveEvery: j['moveEvery'] ?? t.moveEvery, spare: _p(Spare.values, j['spare'], Spare.exercises),
      cardioPct: j['cardioPct'] ?? defaultCardioPct, stretchPct: j['stretchPct'] ?? defaultStretchPct,
    );
  }

  /// Rows per difficulty into tagged bands: hard first, so a shared band keeps its cycle position on the hard row.
  static List<Band> _bandsFromSchemes(Schemes rows) {
    final out = <Band>[];
    for (var d = 3; d >= 1; d--) {
      if (d - 1 >= rows.length) continue;
      for (final r in rows[d - 1]) {
        final existing = out.where((b) => b.range == r).firstOrNull;
        if (existing != null) { existing.difficulties.add(d); } else { out.add(Band(r, [d])); }
      }
    }
    return out;
  }
}

List<int> _tri(Tri t) => [t.min, t.ideal, t.max];
Tri _ptri(dynamic v) => Tri(v[0], v[1], v[2]);

'''
s=s[:a]+new_goal+s[b:]
s=s.replace("import 'index.dart';","import 'dart:math';\n\nimport 'index.dart';",1)

# Location: custom template
s=s.replace("class Location {\n  Location({required this.id, required this.name, required this.template, required this.equipment, this.lat, this.lng});",
"class Location {\n  Location({required this.id, required this.name, this.template = customLocation, required this.equipment, this.lat, this.lng});")
s=s.replace("  bool get hasPosition => lat != null && lng != null;\n  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'template': template, 'equipment': equipment, 'lat': lat, 'lng': lng};",
"  bool get hasPosition => lat != null && lng != null;\n  /// No fixed place: never picked by distance, the fallback when nothing is near.\n  bool get anywhere => !hasPosition;\n  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'template': template, 'equipment': equipment, 'lat': lat, 'lng': lng};")
s=s.replace("      id: j['id'], name: j['name'], template: j['template'], equipment: List<String>.from(j['equipment']),",
"      id: j['id'], name: j['name'], template: j['template'] ?? customLocation, equipment: List<String>.from(j['equipment']),")

# Session: calendar event id
s=s.replace("  String note = '';      // the one line to the human\n  bool swappedToMove = false;",
"  String note = '';      // the one line to the human\n  bool swappedToMove = false;\n  int? calendarEventId;  // the event auto-track wrote, so the calendar read can tell it from busy time")
s=s.replace("        'feel': feel == null ? null : _e(feel!), 'note': note, 'swappedToMove': swappedToMove, 'circuit': circuit, 'skipped': skipped,\n      };",
"        'feel': feel == null ? null : _e(feel!), 'note': note, 'swappedToMove': swappedToMove, 'circuit': circuit, 'skipped': skipped,\n        'calendarEventId': calendarEventId,\n      };")
s=s.replace("    ..note = j['note'] ?? ''\n    ..swappedToMove = j['swappedToMove'] ?? false;",
"    ..note = j['note'] ?? ''\n    ..swappedToMove = j['swappedToMove'] ?? false\n    ..calendarEventId = j['calendarEventId'];")
open(p,'w',encoding='utf-8').write(s)
print('ok')
