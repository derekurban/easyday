import io, glob
def patch(path, pairs):
    t = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert old in t, (path, old[:70])
        t = t.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(t)

# global rename: costInPlay -> difficultyInPlay; SessionExercise.cost -> .difficulty in UI
for p in glob.glob('lib/**/*.dart', recursive=True) + glob.glob('test/*.dart'):
    t = io.open(p, encoding='utf-8').read()
    t2 = t.replace('costInPlay(', 'difficultyInPlay(')
    if t2 != t:
        io.open(p, 'w', encoding='utf-8', newline='\n').write(t2)

# ---------------- after.dart
patch('lib/logic/after.dart', [
("""    _learnBudgets(s, session, lines);""", """    _learnSpare(s, session, lines);"""),
("""        if (st.ceilingRun >= 3 && difficultyInPlay(ex, st) > 1) {
          st.costDown++;
          st.ceilingRun = 0;
          lines.add('${ex.name} is the medium thing now: cost drops to ${difficultyInPlay(ex, st)}.');""",
 """        if (st.ceilingRun >= 3 && difficultyInPlay(ex, st) > 1) {
          st.costDown++;
          st.ceilingRun = 0;
          lines.add('${ex.name} counts as ${difficultyLabel[difficultyInPlay(ex, st)]} now: three bests in a row at the top.');"""),
])
t = io.open('lib/logic/after.dart', encoding='utf-8').read()
start = t.index('/// The effort budgets learn from the feel tap')
end = t.index('/// The energy and time defaults')
new = '''/// Spare minutes learn from the feel tap: two "too much" in the last four workouts turn "more exercises" into cardio;
/// two "easy" turn cardio back into more exercises. A tap after a plain stop does not count. Nothing is asked per set.
void _learnSpare(AppState s, Session session, List<String> lines) {
  if (session.feel == null || session.stopReason == StopReason.none) return;
  final g = s.goal!;
  final recent = [...s.sessions.reversed.where((x) => x.type == 'lift' && x.stopReason != StopReason.none).take(3), session];
  final tooMuch = recent.where((x) => x.feel == Feel.tooMuch).length;
  final easy = recent.where((x) => x.feel == Feel.easy).length;
  // only the tap that completes a pair moves the setting, so the same two taps never count twice
  if (tooMuch >= 2 && session.feel == Feel.tooMuch && g.spare == Spare.exercises) {
    g.spare = Spare.cardio;
    lines.add('Spare minutes go to cardio from now on, not more exercises. Too much twice recently.');
  } else if (easy >= 2 && session.feel == Feel.easy && g.spare == Spare.cardio) {
    g.spare = Spare.exercises;
    lines.add('Spare minutes add exercises again. Easy twice recently.');
  }
}

'''
t = t[:start] + new + t[end:]
io.open('lib/logic/after.dart', 'w', encoding='utf-8', newline='\n').write(t)

# ---------------- catalog.dart: nothing beyond the rename

# ---------------- exercise_card.dart
patch('lib/ui/exercise_card.dart', [
("    final cost = difficultyInPlay(ex, st);\n", "    final difficulty = difficultyInPlay(ex, st);\n    final expr = expressionFor(s, ex);\n    final range = rangeFor(s, ex, expr);\n"),
("    final base = st.costOverride ?? ex.cost;\n", "    final base = st.costOverride ?? ex.difficulty;\n"),
("            Expanded(child: StatTile(label: 'Level', value: rungLabel(s, ex, st, st.rung), icon: LucideIcons.circleDot)),",
 "            Expanded(child: StatTile(label: 'Level', value: rungLabel(s, ex, st, st.rung), hint: ex.loaded ? 'for ${range.lo} to ${range.hi} · max about ${fmtKg(s, maxFor(s, ex, st, st.rung))}' : null, icon: LucideIcons.circleDot)),"),
("              : ex.loaded ? 'Steps of ${fmtKg(s, stepKg(s, ex))}. Tap a level to make it yours.' : 'Tap a level to make it yours.',",
 "              : ex.loaded ? 'Each level is about ${fmtKg(s, stepKg(s, ex))} more at these reps. Heavier and fewer or lighter and more is the same level; the weight follows the reps. Tap a level to make it yours.' : 'Tap a level to make it yours.',"),
("        const SectionHeader('Cost', icon: LucideIcons.flame),", "        const SectionHeader('Difficulty', icon: LucideIcons.flame),"),
("              Row(children: [CostDots(cost, size: 10), const SizedBox(width: 10), Text('$cost of 5', style: t.titleMedium)]),",
 "              Row(children: [CostDots(difficulty, size: 10), const SizedBox(width: 10), Text(difficultyLabel[difficulty]!, style: t.titleMedium)]),"),
("            IconButton.outlined(onPressed: base > 1 ? () => store.update((_) => st.costOverride = base - 1) : null, icon: const Icon(LucideIcons.minus), tooltip: 'Lower cost'),",
 "            IconButton.outlined(onPressed: base > 1 ? () => store.update((_) => st.costOverride = base - 1) : null, icon: const Icon(LucideIcons.minus), tooltip: 'Easier'),"),
("            IconButton.outlined(onPressed: base < 5 ? () => store.update((_) => st.costOverride = base + 1) : null, icon: const Icon(LucideIcons.plus), tooltip: 'Raise cost'),",
 "            IconButton.outlined(onPressed: base < 3 ? () => store.update((_) => st.costOverride = base + 1) : null, icon: const Icon(LucideIcons.plus), tooltip: 'Harder'),"),
("          Text('How much a hard set takes out of the whole body. Energy spends its effort budget in it, and the rep range follows it: cost 4 and 5 train in the heavy range.', style: t.bodySmall),",
 "          Text('How much one hard set takes out of the whole body. Hard exercises get the reps you like; easier ones get more reps and less weight. A hard day pushes the hardest ones first.', style: t.bodySmall),"),
("    parts.add(st.costOverride == null ? 'default ${ex.cost}' : 'your override ${st.costOverride}');",
 "    parts.add(st.costOverride == null ? 'library default' : 'your override');"),
])

# ---------------- session.dart
patch('lib/ui/session.dart', [
("                CostDots(e.cost),", "                CostDots(e.difficulty),"),
])

# ---------------- today.dart
patch('lib/ui/today.dart', [
("                      if (session.type == 'lift') Tooltip(message: 'Average cost of the workout', child: CostDots(_avgCost(session).round())),",
 "                      if (session.type == 'lift') Tooltip(message: 'Difficulty of the workout', child: CostDots(_avgCost(session).round())),"),
("  double _avgCost(Session session) => session.exercises.isEmpty ? 0 : session.exercises.fold(0, (a, e) => a + e.cost) / session.",
 "  double _avgCost(Session session) => session.exercises.isEmpty ? 0 : session.exercises.fold(0, (a, e) => a + e.difficulty) / session."),
("        '${e.sets.length} × ${e.atCeiling ? 'beat ${e.bestTotal} total' : 'aim ${e.target}$unit'}'",
 "        '${e.sets.length} × ${e.atCeiling ? 'beat ${e.bestTotal} total' : '${e.lo} to ${e.hi}$unit, aim ${e.target}'}'"),
("        CostDots(e.cost),\n", "        CostDots(e.difficulty),\n"),
("        SheetHeader(ex.name, subtitle: 'cost ${e.cost} · ${mmss(st.secPerSet)} per set', icon: exerciseIcon(ex)),",
 "        SheetHeader(ex.name, subtitle: '${difficultyLabel[e.difficulty]} · ${e.lo} to ${e.hi} ${ex.repLabel} · ${mmss(st.secPerSet)} per set', icon: exerciseIcon(ex)),"),
("                      Text(rungLabel(s, ex, st, rung), style: t.titleMedium?.copyWith(color: rung == st.rung ? du.ink : du.accentText), textAlign: TextAlign.center),",
 "                      Text(rungLabel(s, ex, st, rung, e.expression), style: t.titleMedium?.copyWith(color: rung == st.rung ? du.ink : du.accentText), textAlign: TextAlign.center),"),
("            subtitle: Text('${s.ex[a.id] != null ? rungLabel(s, a, s.ex[a.id]!, s.ex[a.id]!.rung) : 'not yet practised'} · cost ${difficultyInPlay(a, s.ex[a.id])}'),",
 "            subtitle: Text('${s.ex[a.id] != null ? rungLabel(s, a, s.ex[a.id]!, s.ex[a.id]!.rung) : 'not yet practised'} · ${difficultyLabel[difficultyInPlay(a, s.ex[a.id])]}'),"),
("""        Energy.easy => weekAway ? 'A week away: easy is the default today. Light everywhere, two exercises at your working level, nothing above cost 3.' : 'Light everywhere: one level down, two reps shy of the top. Two exercises at your working level, nothing above cost 3.',
        Energy.normal => 'Your working level on everything the budget allows. The work is what counts.',
        Energy.hard => 'An extra set on the costliest lift, your working level on the rest. Working sets plus one, all at the top, levels up today.',""",
 """        Energy.easy => weekAway ? 'A week away: easy is the default today. Lighter weight, more reps, a set fewer, nothing judged. Two exercises at full.' : 'Same exercises, lighter weight and more reps, a set fewer, nothing judged. Two exercises at full.',
        Energy.normal => 'Same exercises at your working level: your weight, your sets, aim for the top. The work is what counts.',
        Energy.hard => 'Same exercises, one more set on the hardest. Working sets plus one, all at the top, levels up today.',"""),
("""                    if (session.stretchMinutes > 0)
                      ListTile(leading: const IconBadge(LucideIcons.stretchHorizontal, size: 36), title: const Text('Then stretching'), subtitle: Text('${session.stretchMinutes} minutes to finish')),""",
 """                    if (session.stretchMinutes > 0)
                      ListTile(leading: const IconBadge(LucideIcons.stretchHorizontal, size: 36), title: const Text('Then stretching'), subtitle: Text('${session.stretchMinutes} minutes to finish')),
                    if (session.spareMinutes > 0)
                      ListTile(leading: const IconBadge(LucideIcons.coffee, size: 36), title: Text('${session.spareMinutes} minutes to spare'), subtitle: const Text('No rush. Rest longer between sets.')),"""),
("|${session.cardioMinutes}|${session.stretchMinutes}';", "|${session.cardioMinutes}|${session.stretchMinutes}|${session.spareMinutes}';"),
])

# ---------------- settings.dart summary
patch('lib/ui/settings.dart', [
("              Text('${s.goal!.bands[0]} reps on heavy lifts · ${s.goal!.bands[1]} medium · ${s.goal!.bands[2]} light', style: t.bodySmall),\n",
 "              Text('${expressionLabel[s.goal!.reps]!.toLowerCase()} reps · spare minutes: ${spareLabel[s.goal!.spare]!.toLowerCase()}', style: t.bodySmall),\n"),
])
print('ok')
