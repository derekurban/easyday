"""The screens on the rhythm: Today's shuffle sheet, why on every row, the uncovered line, the swap sheet with reasons;
the picker on tags and seeds; the goal editor's Muscles section; Progress's Rhythm panel. CRLF kept."""
import pathlib, sys

mobile = pathlib.Path(__file__).resolve().parents[2]

def load(rel):
    p = mobile / rel
    b = p.read_bytes()
    return p, (b'\r\n' in b), b.decode('utf-8').replace('\r\n', '\n')

def save(p, crlf, s):
    p.write_bytes((s.replace('\n', '\r\n') if crlf else s).encode('utf-8'))

def sub(s, old, new, name):
    if old not in s:
        sys.exit(f'{name}: not found: {old[:90]!r}')
    return s.replace(old, new, 1)

def between(s, start, end, new, name):
    if start not in s or end not in s:
        sys.exit(f'{name}: marker missing: {start[:60]!r} / {end[:60]!r}')
    a = s.index(start); z = s.index(end, a)
    return s[:a] + new + s[z:]

# ------------------------------------------------------------------ today
p, crlf, s = load('lib/ui/today.dart')
if "import 'package:flutter/services.dart';" not in s:
    s = sub(s, "import 'package:flutter/material.dart';\n", "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';\n", 'today')
s = sub(s, """                IconButton.outlined(
                  onPressed: session.exercises.isEmpty ? null : () => setState(() { picks = shufflePicks(s, session, loc?.equipment ?? const [], Random(), now, avoid: plan.excluded); rungOverrides = {}; order = []; leftOut = {}; }),
                  icon: const Icon(LucideIcons.shuffle, size: 20), tooltip: 'Reshuffle the exercises',
                ),""", """                IconButton.outlined(
                  onPressed: session.exercises.isEmpty ? null : () => _shuffleSheet(context, plan),
                  icon: const Icon(LucideIcons.shuffle, size: 20), tooltip: 'Shuffle',
                ),""", 'today')
s = sub(s, """      muscles: p.forced, excluded: p.excluded, shuffle: p.shuffle, manual: p.manual, liftInstead: liftInstead,""",
        """      muscles: p.forced, excluded: p.excluded, muscleSeed: p.muscleDraw, exerciseSeed: p.exerciseDraw, manual: p.manual, liftInstead: liftInstead,""", 'today')
s = sub(s, """MusclePlan(states: defaultMuscleStates(MuscleMap(s).currentStrainPoints(now)), order: trackedMuscles)""",
        """MusclePlan(states: defaultMuscleStates(MuscleMap(s).currentStrainPoints(now), s.goal), order: trackedMuscles)""", 'today')
s = sub(s, """      builder: (_) => MusclePickerScreen(
        plan: _musclePlan(store.state, store.now),
        preview: (p) => buildSession(store.state, _options(store.state, store.now, plan: p), store.now),
      ),""", """      builder: (_) => MusclePickerScreen(
        plan: _musclePlan(store.state, store.now),
        preview: (p) => buildSession(store.state, _options(store.state, store.now, plan: p), store.now),
        drawMuscles: (p) => nextMuscleSeed(store.state, _options(store.state, store.now, plan: p), store.now),
      ),""", 'today')
s = sub(s, """          Text(plan.manual ? 'MUSCLES · MANUAL' : 'MUSCLES · SHUFFLE', style: t.labelSmall),""",
        """          Text(plan.manual ? 'MUSCLES · MANUAL' : plan.drawn ? 'MUSCLES · DRAWN' : 'MUSCLES', style: t.labelSmall),""", 'today')
s = sub(s, """                  else
                    _plan(context, s, session, est),
                ],""", """                  else ...[
                    if (session.uncovered.isNotEmpty)
                      Padding(padding: const EdgeInsets.only(bottom: 10), child: _hint(context, LucideIcons.circleAlert, 'Nothing here works ${listWords(session.uncovered)} as a main muscle today.')),
                    _plan(context, s, session, est),
                  ],
                ],""", 'today')
s = sub(s, """    final t = Theme.of(context).textTheme;
    final note = rungNote(e.exercise, e.rung);""", """    final t = Theme.of(context).textTheme;
    final du = context.du;
    final note = rungNote(e.exercise, e.rung);""", 'today')
s = sub(s, """      subtitle: Text('${muscleTitle(listWords(e.exercise.primary))} · $rung · ${e.sets.length} × ${e.atCeiling ? 'beat ${e.bestTotal} total' : '${e.lo} to ${e.hi}$unit'}${note != null ? '\\n$note' : ''}'),
      isThreeLine: note != null,""", """      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${muscleTitle(listWords(e.exercise.primary))} · $rung · ${e.sets.length} × ${e.atCeiling ? 'beat ${e.bestTotal} total' : '${e.lo} to ${e.hi}$unit'}'),
        if (note != null) Text(note),
        Text(muscleTitle(e.why), style: t.labelSmall?.copyWith(color: du.inkTertiary, letterSpacing: 0)),
      ]),
      isThreeLine: true,""", 'today')
s = sub(s, """    final all = alternatives(s, session, i, equipmentHere, store.now, avoid: _musclePlan(s, store.now).excluded);
    final alts = all.where((a) => preferenceOf(s.ex[a.id], store.now) != prefNo).toList();
    final notForYou = all.where((a) => preferenceOf(s.ex[a.id], store.now) == prefNo).toList();""",
        """    final all = alternativesFor(s, session, i, equipmentHere, store.now, avoid: _musclePlan(s, store.now).excluded);
    final alts = all.where((a) => preferenceOf(s.ex[a.exercise.id], store.now) != prefNo).toList();
    final notForYou = all.where((a) => preferenceOf(s.ex[a.exercise.id], store.now) == prefNo).toList();""", 'today')
s = sub(s, """      Widget alt(Exercise a) {
        final ast = s.ex[a.id];
        final word = preferenceOf(ast, store.now);""", """      Widget alt(Alternative x) {
        final a = x.exercise;
        final ast = s.ex[a.id];""", 'today')
s = sub(s, """          subtitle: Text('${ast != null ? rungLabel(s, a, ast, ast.rung) : 'not yet practised'} · ${difficultyLabel[difficultyInPlay(a, ast)]}${word != null ? ' · ${preferenceLabel[word]!.toLowerCase()}' : ''}'),""",
        """          subtitle: Text('${ast != null ? rungLabel(s, a, ast, ast.rung) : 'not yet practised'} · ${difficultyLabel[difficultyInPlay(a, ast)]}${x.reason.isNotEmpty ? ' · ${x.reason}' : ''}'),""", 'today')
s = sub(s, """child: Text('Chosen because: ${e.why}.', style: t.bodySmall)),""", """child: Text('Why: ${muscleTitle(e.why)}.', style: t.bodySmall)),""", 'today')
s = sub(s, """trailing: alts.isEmpty ? null : Text('ready first, then liked', style: t.labelSmall)),""",
        """trailing: alts.isEmpty ? null : Text("in selection's order", style: t.labelSmall)),""", 'today')
s = sub(s, """  // ---------- the plan
""", """  /// Shuffle (SELECTION.md): the exercises (the same muscles, the cover drawn again), the muscles (a different
  /// combination of what is due), Back to the draw before, or Reset to the plan's own pick.
  Future<void> _shuffleSheet(BuildContext context, MusclePlan plan) async {
    final store = context.store;
    final s = store.state;
    final now = store.now;
    final choice = await showSheet<String>(context, ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 16), children: [
      const SheetHeader('Shuffle', subtitle: 'A draw stays until you start or draw again. Forced muscles and your swaps hold.', icon: LucideIcons.shuffle),
      ListTile(leading: const IconBadge(LucideIcons.dices, size: 36), title: const Text('Shuffle exercises'), subtitle: const Text('The same muscles, other exercises that cover them.'), onTap: () => Navigator.pop(context, 'exercises')),
      ListTile(
        leading: const IconBadge(LucideIcons.personStanding, size: 36), title: const Text('Shuffle muscles'), enabled: !plan.manual,
        subtitle: Text(plan.manual ? 'Not in manual: only the forced muscles are worked.' : 'A different combination of the muscles that are due.'),
        onTap: () => Navigator.pop(context, 'muscles'),
      ),
      if (plan.canGoBack) ListTile(leading: const IconBadge(LucideIcons.undo2, size: 36), title: const Text('Back'), subtitle: const Text('The draw before this one.'), onTap: () => Navigator.pop(context, 'back')),
      if (plan.drawn) ListTile(leading: const IconBadge(LucideIcons.rotateCcw, size: 36), title: const Text('Reset'), subtitle: const Text("The plan's own pick."), onTap: () => Navigator.pop(context, 'reset')),
    ]));
    if (choice == null || !mounted) return;
    final p = plan.copy();
    switch (choice) {
      case 'exercises': p.draw(exercises: nextExerciseSeed(s, _options(s, now, plan: p), now));
      case 'muscles': p.draw(muscles: nextMuscleSeed(s, _options(s, now, plan: p), now));
      case 'back': p.back();
      case 'reset': p.resetDraws();
    }
    HapticFeedback.selectionClick();
    // a draw moves the places, so the plan's edits start over
    setState(() { musclePlan = p; picks = {}; rungOverrides = {}; order = []; leftOut = {}; });
  }

  // ---------- the plan
""", 'today')
save(p, crlf, s)

# ------------------------------------------------------------------ the picker
p, crlf, s = load('lib/ui/muscle_picker.dart')
s = sub(s, """  const MusclePickerScreen({super.key, required this.plan, required this.preview});
  final MusclePlan plan;
  /// The workout the plan would build, for the figure's chosen muscles and the line above Done.
  final Session Function(MusclePlan plan) preview;""", """  const MusclePickerScreen({super.key, required this.plan, required this.preview, required this.drawMuscles});
  final MusclePlan plan;
  /// The workout the plan would build, for the figure's chosen muscles and the line above Done.
  final Session Function(MusclePlan plan) preview;
  /// The next muscle seed that changes the muscles worked (Draw again).
  final int Function(MusclePlan plan) drawMuscles;""", 'picker')
s = sub(s, """    final defaults = defaultMuscleStates(current);
    final changed = trackedMuscles.any((m) => plan.states[m] != defaults[m]) || plan.manual || plan.seed > 0;""",
        """    final defaults = defaultMuscleStates(current, s.goal);
    final changed = trackedMuscles.any((m) => plan.states[m] != defaults[m]) || plan.manual || plan.drawn;""", 'picker')
s = sub(s, """            onPressed: plan.manual ? null : () { HapticFeedback.selectionClick(); setState(() => plan.seed++); },""",
        """            onPressed: plan.manual ? null : () { HapticFeedback.selectionClick(); setState(() => plan.draw(muscles: widget.drawMuscles(plan))); },""", 'picker')
s = sub(s, """${plan.seed > 0 ? ' Draw ${plan.seed}.' : ''}""", """${plan.muscleDraw != null ? ' Drawn.' : ''}""", 'picker')
s = sub(s, """    final share = shareOver(context.store.state, now);""", """    final rhythm = rhythmOver(context.store.state, now);""", 'picker')
s = sub(s, """_tile(context, i, it.group!, current, map, share, now, chosen, key:""", """_tile(context, i, it.group!, current, map, rhythm, now, chosen, key:""", 'picker')
s = sub(s, """  Widget _tile(BuildContext context, int index, String g, StrainPoints current, MuscleMap map, Share share, DateTime now, Set<String> chosen, {required Key key}) {""",
        """  /// A muscle's tag and clock in words: "active · last worked 4 workouts ago", "passive · helped last workout", "ignored".
  String _tagText(BuildContext context, String g, Rhythm r) {
    final goal = context.store.state.goal!;
    return switch (goal.tagOf(g)) {
      MuscleTag.active => 'active · ${r.dueText(g)}',
      MuscleTag.passive => 'passive · ${r.helpedText(g)}',
      MuscleTag.ignored => 'ignored',
    };
  }

  Widget _tile(BuildContext context, int index, String g, StrainPoints current, MuscleMap map, Rhythm rhythm, DateTime now, Set<String> chosen, {required Key key}) {""", 'picker')
s = sub(s, """            subtitle: Text('${worked ? 'in today\\'s workout · ' : ''}${muscleStrainText(current, map, g, now)} · ${share.bandWord(g)}'),""",
        """            subtitle: Text('${worked ? 'in today\\'s workout · ' : ''}${_tagText(context, g, rhythm)} · ${muscleStrainText(current, map, g, now)}'),""", 'picker')
save(p, crlf, s)

# ------------------------------------------------------------------ the goal editor
p, crlf, s = load('lib/ui/goal_editor.dart')
s = between(s, """      const SectionHeader('Muscles over the week', icon: LucideIcons.personStanding),""",
            """      const SizedBox(height: 8),
      Row(children: [
        Icon(LucideIcons.shield""", """      const SectionHeader('Muscles', icon: LucideIcons.personStanding),
      Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Active muscles get exercises of their own, each in turn: the more of them, the longer each waits. Passive ones are helped along the way and steer the choice of exercise. Ignored ones are not considered. The template set these; change any.', style: t.bodySmall),
        const SizedBox(height: 12),
        MuscleTags(goal: g, onChanged: () => _set((_) {})),
        const Divider(height: 20),
        ChoiceRow<Explore>(label: 'Try new exercises', value: g.explore, options: {for (final v in Explore.values) v: exploreLabel[v]!}, hint: 'How often an exercise you have not rated takes a turn from a practised one: one in ${exploreRun[g.explore]} appearances, in the last place, never on a hard day.', onChanged: (v) => _set((x) => x.explore = v)),
      ])),
""", 'goal_editor')
s = sub(s, "import 'motion.dart';\n", "import 'motion.dart';\nimport 'muscle_tags.dart';\n", 'goal_editor')
save(p, crlf, s)

# ------------------------------------------------------------------ progress
p, crlf, s = load('lib/ui/progress.dart')
s = between(s, """        SectionHeader('Sets per muscle, last ${g.lookBackDays} days', icon: LucideIcons.layers),""",
            """        SectionHeader('Levels, last 30 days'""", """        const SectionHeader('Rhythm', icon: LucideIcons.layers),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Whose turn it is: active muscles come round in turn, most overdue first, and the forecast says about how often. Tap a muscle to change its tag or how often.', style: t.bodySmall),
          const SizedBox(height: 6),
          MuscleTags(goal: g, onChanged: () => store.update((_) {}), figure: false),
        ])),
        const SizedBox(height: 20),
""", 'progress')
s = sub(s, """    final share = shareOver(s, now);
""", "", 'progress')
s = sub(s, "import 'motion.dart';\n", "import 'motion.dart';\nimport 'muscle_tags.dart';\n", 'progress')
save(p, crlf, s)
print('ok')
