"""The picker, Today, the goal editor and Progress per muscle. CRLF kept where the file had it."""
import pathlib, re, sys

root = pathlib.Path(__file__).resolve().parents[2]

def patch(rel, pairs, regex=()):
    p = root / rel
    b = p.read_bytes()
    crlf = b'\r\n' in b
    s = b.decode('utf-8').replace('\r\n', '\n')
    for old, new in pairs:
        if old not in s:
            sys.exit(f'{rel}: not found: {old[:80]!r}')
        s = s.replace(old, new, 1)
    for pat, rep in regex:
        s = re.sub(pat, rep, s)
    if crlf:
        s = s.replace('\n', '\r\n')
    p.write_bytes(s.encode('utf-8'))

patch('lib/ui/muscle_picker.dart', [
    ("""// The muscle picker: today's word on each muscle group (logic/muscle_plan.dart), chosen on the body. Tap muscles to
// select them (blue, on both figures), then a pill says what the selected ones are today: forced, available or
// excluded. The figure shows the result the way a muscle map shows a workout: forced groups in the primary green,
// the available groups the workout chose in the secondary green, the rest of the available ones plain, excluded ones
// very dark. Shuffle fills the places after the forced groups from the available pool (the Shuffle button draws
// again); Manual works the forced groups only. A stack of tabs at the bottom right switches between both figures,
// the front, the back, and a list: the groups under Forced, Available and Excluded, each tile draggable up and down""",
     """// The muscle picker: today's word on each muscle (logic/muscle_plan.dart), chosen on the body, one muscle per plate
// name, the same muscles selection and its ledgers run on. Tap muscles to select them (blue), then a pill says what the
// selected ones are today: forced, available or excluded. The figure shows the result the way a muscle map shows a
// workout: forced muscles in the primary green, available muscles the workout works mainly in the secondary green, the
// rest of the available ones plain, excluded ones very dark. Shuffle fills the places after the forced muscles from the
// available pool (Draw again draws anew); Manual works the forced muscles only. A stack of tabs at the bottom right
// switches between both figures, the front, the back, and a list: the muscles under Forced, Available and Excluded,
// each tile draggable up and down"""),
    ("""/// An excluded group's fill""", """/// An excluded muscle's fill"""),
    ("""/// The secondary strength: the primary colour at this alpha, for the available groups the workout chose.""",
     """/// The secondary strength: the primary colour at this alpha, for the available muscles the workout works mainly."""),
    ("""/// The figure's fills from the states: forced in [primary], the available groups in [chosen] at the secondary
/// strength, excluded very dark, the rest plain. Groups in [selected] fill the selection blue instead.
Map<String, Color> muscleFills(Map<String, MuscleState> states, {required Set<String> chosen, required Color primary, Set<String> selected = const {}}) {
  final tint = <String, Color>{};
  for (final g in muscleGroups) {
    final c = selected.contains(g)
        ? muscleSelect
        : switch (states[g]) {
            MuscleState.forced => primary,
            MuscleState.excluded => muscleExcluded,
            _ => chosen.contains(g) ? primary.withValues(alpha: muscleSecondaryAlpha) : null,
          };
    if (c == null) continue;
    for (final m in musclesOf(g)) { tint[m] = c; }
  }
  return tint;
}""", """/// The figure's fills from the states: forced in [primary], the available muscles in [chosen] at the secondary
/// strength, excluded very dark, the rest plain. Muscles in [selected] fill the selection blue instead.
Map<String, Color> muscleFills(Map<String, MuscleState> states, {required Set<String> chosen, required Color primary, Set<String> selected = const {}}) {
  final tint = <String, Color>{};
  for (final m in trackedMuscles) {
    final c = selected.contains(m)
        ? muscleSelect
        : switch (states[m]) {
            MuscleState.forced => primary,
            MuscleState.excluded => muscleExcluded,
            _ => chosen.contains(m) ? primary.withValues(alpha: muscleSecondaryAlpha) : null,
          };
    if (c != null) tint[m] = c;
  }
  return tint;
}"""),
    ("""/// What a group looks like in the list""", """/// What a muscle looks like in the list"""),
    ("""/// What a group's strain is in words: "ready", or "medium strain, strain-free Thursday".
String groupStrainText(StrainPoints current, MuscleMap map, String group, DateTime now) {
  final shade = groupShade(current, group);
  if (shade == 0) return 'ready';
  var free = now;
  for (final m in musclesOf(group)) { final d = map.strainFreeOn(m, now); if (d.isAfter(free)) free = d; }
  return '${strainShadeLabels[strainShades - shade]} strain, strain-free ${dayText(free, now)}';
}

/// The groups a built workout works.
Set<String> workedGroups(Session session) => {for (final e in session.exercises) e.muscle};""",
     """/// What a muscle's strain is in words: "ready", or "medium strain, strain-free Thursday".
String muscleStrainText(StrainPoints current, MuscleMap map, String muscle, DateTime now) {
  final shade = current.shade(muscle);
  if (shade == 0) return 'ready';
  return '${strainShadeLabels[strainShades - shade]} strain, strain-free ${dayText(map.strainFreeOn(muscle, now), now)}';
}

/// The muscles a built workout works mainly: every primary muscle of its exercises.
Set<String> workedMuscles(Session session) => {for (final e in session.exercises) ...e.exercise.primary};"""),
    ("""  /// The workout the plan would build, for the figure's chosen groups and the line above Done.""",
     """  /// The workout the plan would build, for the figure's chosen muscles and the line above Done."""),
    ("""  late MusclePlan plan = widget.plan.copy()..order.addAll([for (final g in muscleGroups) if (!widget.plan.order.contains(g)) g]);""",
     """  late MusclePlan plan = widget.plan.copy()..order.addAll([for (final m in trackedMuscles) if (!widget.plan.order.contains(m)) m]);"""),
    ("""  void _toggle(String group) {""", """  void _toggle(String muscle) {"""),
    ("""    setState(() { if (!selected.remove(group)) selected.add(group); });""", """    setState(() { if (!selected.remove(muscle)) selected.add(muscle); });"""),
    ("""    final chosen = workedGroups(session);""", """    final chosen = workedMuscles(session);"""),
    ("""    final changed = muscleGroups.any((g) => plan.states[g] != defaults[g])""", """    final changed = trackedMuscles.any((m) => plan.states[m] != defaults[m])"""),
    ("""plan = MusclePlan(states: defaults, order: muscleGroups);""", """plan = MusclePlan(states: defaults, order: trackedMuscles);"""),
    ("""'${listWords(selected.toList())} selected'""", """'${muscleTitle(listWords(selected))} selected'"""),
    ("""          onTap: (h) { if (h != null && muscleGroups.contains(muscleGroup(h.name))) _toggle(muscleGroup(h.name)); },""",
     """          onTap: (h) { if (h != null && trackedMuscles.contains(h.name)) _toggle(h.name); },"""),
    ("""  /// The list: a header per state, the groups under each,""", """  /// The list: a header per state, the muscles under each,"""),
    ("""            title: Text(g, style:""", """            title: Text(muscleTitle(g), style:"""),
    ("""${groupStrainText(current, map, g, now)}""", """${muscleStrainText(current, map, g, now)}"""),
], regex=[(r'\bgroupsIn\b', 'musclesIn')])

patch('lib/ui/today.dart', [
    ("""// muscle groups are excluded, available or forced (the muscle picker).""", """// muscles are excluded, available or forced (the muscle picker)."""),
    ("""order: muscleGroups);""", """order: trackedMuscles);"""),
    ("""                          : plan.excluded.length == muscleGroups.length""", """                          : plan.excluded.length == trackedMuscles.length"""),
    ("""    final tint = muscleFills(plan.states, chosen: working.toSet(), primary: du.accentStrong);""",
     """    final tint = muscleFills(plan.states, chosen: workedMuscles(session), primary: du.accentStrong);"""),
    ("""      muscles: p.forced, excluded: p.excluded, shuffle: p.shuffle, liftInstead: liftInstead,""",
     """      muscles: p.forced, excluded: p.excluded, shuffle: p.shuffle, manual: p.manual, liftInstead: liftInstead,"""),
    ("""picks = shufflePicks(s, session, loc?.equipment ?? const [], Random(), now);""",
     """picks = shufflePicks(s, session, loc?.equipment ?? const [], Random(), now, avoid: plan.excluded);"""),
    ("""    final all = alternatives(s, session, i, equipmentHere, store.now);""",
     """    final all = alternatives(s, session, i, equipmentHere, store.now, avoid: _musclePlan(s, store.now).excluded);"""),
    ("""      subtitle: Text('${e.muscle} · $rung""", """      subtitle: Text('${muscleTitle(e.muscle)} · $rung"""),
    ("""        SheetHeader(ex.name, subtitle: '${e.muscle} · """, """        SheetHeader(ex.name, subtitle: '${muscleTitle(e.muscle)} · """),
], regex=[(r'\bgroupsIn\b', 'musclesIn')])

patch('lib/ui/goal_editor.dart', [
    ("""ValueSlider(label: 'Sets per muscle group',""", """ValueSlider(label: 'Sets per muscle',"""),
    ("""Text('Each muscle group aims for this many sets over the look-back.""", """Text('Each muscle aims for this many sets over the look-back."""),
    ("""        for (final grp in muscleGroups)
          Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
            SizedBox(width: 104, child: Text(grp, style: t.bodyMedium)),""",
     """        for (final grp in trackedMuscles)
          Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
            SizedBox(width: 120, child: Text(muscleTitle(grp), style: t.bodyMedium)),"""),
])

patch('lib/ui/progress.dart', [
    ("""'Against ${g.targetSets(s.profile?.daysPerWeek ?? 3)} sets a group,""", """'Against ${g.targetSets(s.profile?.daysPerWeek ?? 3)} sets a muscle,"""),
    ("""          for (final grp in muscleGroups)
            Padding(padding: const EdgeInsets.fromLTRB(16, 5, 16, 5), child: Row(children: [
              SizedBox(width: 92, child: Text(grp, style: t.bodyMedium)),""",
     """          for (final grp in trackedMuscles)
            Padding(padding: const EdgeInsets.fromLTRB(16, 5, 16, 5), child: Row(children: [
              SizedBox(width: 112, child: Text(muscleTitle(grp), style: t.bodyMedium, overflow: TextOverflow.ellipsis)),"""),
])
print('ok')
