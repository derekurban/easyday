# Today shows the strain muscle map of the planned workout, what is still carrying strain, and what sat out for it.
import pathlib


def edit(path, pairs):
    p = pathlib.Path(path)
    t = p.read_bytes().decode().replace('\r\n', '\n')
    for old, new in pairs:
        assert t.count(old) == 1, (path, old[:90])
        t = t.replace(old, new)
    p.write_bytes(t.replace('\n', '\r\n').encode())


edit('lib/ui/today.dart', [
    ("""import '../logic/muscles.dart';
""", """import '../logic/muscle_map.dart';
"""),
    ("""    final muscles = workoutMuscles(session);""", """    final muscleMap = MuscleMap(s);
    final planned = strainPointsFromWorkout(session, planned: true);
    final current = muscleMap.currentStrainPoints(now);"""),
    ("""                        MuscleFigure(highlight: muscles, height: 170, keyLabels: const ['main', 'helping'], expandable: true, title: session.name,
                            detail: (h) => _muscleDetail(session, h)),""",
     """                        MuscleFigure(highlight: planned.byMuscle, height: 170, keyLabels: const ['high strain', 'medium', 'low'], expandable: true,
                            title: session.name, detail: (h) => _muscleDetail(session, h, planned, current)),"""),
    ("""                          for (final line in _whyLines(s, now, muscles))""", """                          for (final line in _whyLines(s, now, session, muscleMap, current))"""),
    ("""  String? _muscleDetail(Session x, MuscleHit h) {
    final main = <String>[], helping = <String>[];
    for (final e in x.exercises) {
      if (e.exercise.primary.contains(h.name)) { main.add(e.exercise.name); }
      else if (e.exercise.secondary.contains(h.name)) { helping.add(e.exercise.name); }
    }
    if (main.isEmpty && helping.isEmpty) return 'Not worked today.';
    return [if (main.isNotEmpty) 'Main in ${main.join(', ')}.', if (helping.isNotEmpty) 'Helps in ${helping.join(', ')}.'].join(' ');
  }
""", """  /// For a tapped muscle: the strain points this workout gives it, which exercises use it, and what it carries now.
  String? _muscleDetail(Session x, MuscleHit h, StrainPoints planned, StrainPoints current) {
    final main = <String>[], helping = <String>[];
    for (final e in x.exercises) {
      if (e.exercise.primary.contains(h.name)) { main.add(e.exercise.name); }
      else if (e.exercise.secondary.contains(h.name)) { helping.add(e.exercise.name); }
    }
    final now = current.strainFree(h.name) ? 'Strain-free now.' : 'Carrying ${strainPointsText(current[h.name])} now.';
    if (main.isEmpty && helping.isEmpty) return 'Not worked today. $now';
    return [
      '${strainPointsText(planned[h.name])} strain points from this workout.',
      if (main.isNotEmpty) 'Main in ${main.join(', ')}.',
      if (helping.isNotEmpty) 'Helps in ${helping.join(', ')}.',
      now,
    ].join(' ');
  }
"""),
    ("""  /// What the workout works, the main muscles then the helping ones, and what has waited longest.
  List<String> _whyLines(AppState s, DateTime now, Map<String, double> muscles) {
    String names(Iterable<String> xs) {
      final l = xs.toList();
      return l.length <= 1 ? l.join() : '${l.sublist(0, l.length - 1).join(', ')} and ${l.last}';
    }
    final main = muscles.entries.where((e) => e.value >= primaryStrength).map((e) => e.key).toList();
    final helping = muscles.entries.where((e) => e.value < primaryStrength).map((e) => e.key).toList();
    // the muscle groups not worked for a week or more, and not in today's workout, longest first
    final todayGroups = muscles.keys.map(muscleGroup).toSet();
    final last = <String, DateTime>{};
    for (final e in lastWorked(s).entries) {""",
     """  /// What the workout works, the main muscles then the helping ones; which patterns sat out and what is still carrying
  /// strain; and what has waited longest.
  List<String> _whyLines(AppState s, DateTime now, Session session, MuscleMap muscleMap, StrainPoints current) {
    String names(Iterable<String> xs) {
      final l = xs.toList();
      return l.length <= 1 ? l.join() : '${l.sublist(0, l.length - 1).join(', ')} and ${l.last}';
    }
    final main = <String>[], helping = <String>[];
    for (final e in session.exercises) {
      for (final m in e.exercise.primary) { if (!main.contains(m)) main.add(m); }
    }
    for (final e in session.exercises) {
      for (final m in e.exercise.secondary) { if (!main.contains(m) && !helping.contains(m)) helping.add(m); }
    }
    // the most strained muscles, with the day each will be strain-free
    final strained = current.ranked().take(3).map((m) => '$m till ${dayText(muscleMap.strainFreeOn(m, now), now)}').toList();
    final satOut = session.satOut.keys.map(patternName).toList();
    // the muscle groups not worked for a week or more, and not in today's workout, longest first
    final todayGroups = [...main, ...helping].map(muscleGroup).toSet();
    final last = <String, DateTime>{};
    for (final e in muscleMap.lastWorked().entries) {"""),
    ("""      if (main.isNotEmpty) 'Works ${names(main)}.',
      if (helping.isNotEmpty) 'Also ${names(helping)}.',""",
     """      if (main.isNotEmpty) 'Works ${names(main)}.',
      if (helping.isNotEmpty) 'Also ${names(helping)}.',
      if (satOut.isNotEmpty) '${names(satOut)} ${satOut.length == 1 ? 'sits' : 'sit'} out: ${satOut.length == 1 ? 'its' : 'their'} muscles carry strain.',
      if (strained.isNotEmpty) 'Carrying strain: ${names(strained)}.',"""),
])
