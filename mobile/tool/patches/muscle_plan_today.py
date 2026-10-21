"""Today moves to MusclePlan (select-then-assign picker, shuffle or manual); the tests follow. CRLF kept."""
import pathlib, sys

root = pathlib.Path(__file__).resolve().parents[2]

def patch(rel, pairs, crlf=None):
    p = root / rel
    b = p.read_bytes()
    had = b'\r\n' in b if crlf is None else crlf
    s = b.decode('utf-8').replace('\r\n', '\n')
    for old, new in pairs:
        if old not in s:
            sys.exit(f'{rel}: not found: {old[:70]!r}')
        s = s.replace(old, new, 1)
    if had:
        s = s.replace('\n', '\r\n')
    p.write_bytes(s.encode('utf-8'))
    return s

PANEL = '''  /// The muscles panel: a small figure painted like the picker (forced primary, chosen secondary, excluded dark), and
  /// what today works, forces and leaves out. Tap to open the picker.
  Widget _musclesPanel(BuildContext context, AppState s, DateTime now, Session session, MusclePlan plan) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final working = <String>[];
    for (final e in session.exercises) { if (!working.contains(e.muscle)) working.add(e.muscle); }
    final tint = muscleFills(plan.states, chosen: working.toSet(), primary: du.accentStrong);
    final forced = plan.forced;
    final excluded = groupsIn(plan.states, MuscleState.excluded);
    String lower(Iterable<String> xs) => listWords(xs.map((g) => g.toLowerCase()));
    return Panel(
      onTap: () => _pickMuscles(context),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(children: [
        MuscleFigure(highlight: const {}, tint: tint, height: 92, interactive: false),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(plan.manual ? 'MUSCLES · MANUAL' : 'MUSCLES · SHUFFLE', style: t.labelSmall),
          const SizedBox(height: 3),
          Text(working.isEmpty ? 'Nothing to work.' : 'Working ${lower(working)}.', style: t.bodyMedium),
          if (forced.isNotEmpty) Text('Forced: ${lower(forced)}.', style: t.bodySmall?.copyWith(color: du.accentText)),
          if (!plan.manual) Text(excluded.isEmpty ? 'Every muscle available.' : 'Excluded: ${lower(excluded)}.', style: t.bodySmall),
          const SizedBox(height: 3),
          Text(musclePlan == null ? 'Tap to change' : 'Changed today · tap to change', style: t.labelSmall?.copyWith(color: du.accentText)),
        ])),
        Icon(LucideIcons.chevronRight, size: 18, color: du.inkTertiary),
      ]),
    );
  }

  Future<void> _pickMuscles(BuildContext context) async {
    final store = context.store;
    final r = await Navigator.of(context).push<MusclePlan>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => MusclePickerScreen(
        plan: _musclePlan(store.state, store.now),
        preview: (p) => buildSession(store.state, _options(store.state, store.now, plan: p), store.now),
      ),
    ));
    if (r == null || !mounted) return;
    // the muscles changed, so the slots did: the plan's edits start over
    setState(() { musclePlan = r; picks = {}; rungOverrides = {}; order = []; leftOut = {}; });
  }

'''

today = root / 'lib/ui/today.dart'
s = today.read_bytes().decode('utf-8').replace('\r\n', '\n')
a = s.index('  /// The muscles panel:')
b = s.index('  // ---------- the plan')
s = s[:a] + PANEL + s[b:]
today.write_bytes(s.replace('\n', '\r\n').encode('utf-8'))

patch('lib/ui/today.dart', [
    ("""  // the muscle plan: null until the user has changed it, so the defaults follow the strain of the moment
  Map<String, MuscleState>? muscleStates;
  List<String> muscleOrder = [];
""", """  // the muscle plan: null until the user has changed it, so the defaults follow the strain of the moment
  MusclePlan? musclePlan;
"""),
    ("""  /// Today's states for the eleven groups: the user's, else the defaults from the strain of the moment.
  Map<String, MuscleState> _states(AppState s, DateTime now) => muscleStates ?? defaultMuscleStates(MuscleMap(s).currentStrainPoints(now));
""", """  /// Today's muscle plan: the user's, else the defaults from the strain of the moment.
  MusclePlan _musclePlan(AppState s, DateTime now) => musclePlan ?? MusclePlan(states: defaultMuscleStates(MuscleMap(s).currentStrainPoints(now)), order: muscleGroups);
"""),
    ("""  BuildOptions _options(AppState s, DateTime now, {Map<String, MuscleState>? states, List<String>? order, bool asBuilt = false}) {""",
     """  BuildOptions _options(AppState s, DateTime now, {MusclePlan? plan, bool asBuilt = false}) {"""),
    ("""    final st = states ?? _states(s, now);
    final ord = order ?? muscleOrder;
    return BuildOptions(""", """    final p = plan ?? _musclePlan(s, now);
    // manual with no time limit: exactly the forced muscles, one exercise each
    final manualCount = max(1, min(p.forced.length, g.exercises.max));
    return BuildOptions("""),
    ("""      exerciseCount: limit ? null : n, warmupMinutes""", """      exerciseCount: limit ? null : p.manual ? manualCount : n, warmupMinutes"""),
    ("""      muscles: groupsIn(st, MuscleState.forced, ord), excluded: groupsIn(st, MuscleState.excluded).toSet(), liftInstead: liftInstead,""",
     """      muscles: p.forced, excluded: p.excluded, shuffle: p.shuffle, liftInstead: liftInstead,"""),
    ("""        muscleStates = null; muscleOrder = []; picks = {};""", """        musclePlan = null; picks = {};"""),
    ("""    final states = _states(s, now);
    final current = MuscleMap(s).currentStrainPoints(now);
""", """    final plan = _musclePlan(s, now);
"""),
    ("""                  _musclesPanel(context, s, now, session, states, current),""", """                  _musclesPanel(context, s, now, session, plan),"""),
    ("""                      subtitle: Text(groupsIn(states, MuscleState.excluded).length == muscleGroups.length
                          ? 'Every muscle is excluded. Tap the muscles to make some available.'
                          : 'Nothing here works the muscles available. Add equipment to this location, change the muscles, or move instead.'),""",
     """                      subtitle: Text(plan.manual
                          ? 'Manual: only forced muscles are worked, and none is forced. Tap the muscles to force some.'
                          : plan.excluded.length == muscleGroups.length
                              ? 'Every muscle is excluded. Tap the muscles to make some available.'
                              : 'Nothing here works the muscles available. Add equipment to this location, change the muscles, or move instead.'),"""),
])

patch('test/muscle_plan_test.dart', [
    ("""    test('the tap cycle goes excluded, available, forced and round', () {
      expect(nextMuscleState(MuscleState.excluded), MuscleState.available);
      expect(nextMuscleState(MuscleState.available), MuscleState.forced);
      expect(nextMuscleState(MuscleState.forced), MuscleState.excluded);
    });""", """    test('a plan sets the selected groups, works only the forced ones when manual, and draws by seed when shuffled', () {
      final plan = MusclePlan(states: defaultMuscleStates(StrainPoints.none), order: muscleGroups);
      plan.set(['Chest', 'Back'], MuscleState.forced);
      plan.set(['Calves'], MuscleState.excluded);
      expect(plan.forced, ['Chest', 'Back']);
      expect(plan.excluded, {'Calves'});
      expect(plan.shuffle, isNull);
      plan.seed = 3;
      expect(plan.shuffle, 3);
      plan.manual = true;
      expect(plan.shuffle, isNull);
      expect(plan.excluded, muscleGroups.toSet().difference({'Chest', 'Back'}));
      final x = build(fresh(), t0, muscles: plan.forced, excluded: plan.excluded, minutes: 60);
      expect(groupsOf(x).toSet(), {'Chest', 'Back'});
    });

    test('a shuffle seed draws different ready groups, the same for the same seed', () {
      final s = fresh();
      final a = buildSession(s, BuildOptions(energy: Energy.normal, minutes: 60, shuffle: 1, liftInstead: true), t0);
      final b = buildSession(s, BuildOptions(energy: Energy.normal, minutes: 60, shuffle: 1, liftInstead: true), t0);
      expect(groupsOf(a), groupsOf(b));
      final draws = {for (var i = 1; i <= 8; i++) groupsOf(buildSession(s, BuildOptions(energy: Energy.normal, minutes: 60, shuffle: i, liftInstead: true), t0)).join()};
      expect(draws.length, greaterThan(1));
    });"""),
], crlf=False)
print('ok')
