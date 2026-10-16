p='lib/ui/today.dart'
s=open(p,encoding='utf-8').read()

a=s.index('  @override\n  Widget build(BuildContext context) {')
b=s.index('  Widget _doneForToday(')
build='''  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final s = store.state;
    final now = store.now;
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final defaults = defaultsFor(s, now, busyShare: day?.busyShare);
    final e = energy ?? defaults.energy;
    final mins = minutes ?? defaults.minutes;
    final loc = s.location(locationId ?? nearbyId);
    final item = s.plan!.rotation[s.plan!.index];
    final ps = personState(s, now);
    final nudge = nudgeFor(s, now);

    if (finishedToday(s, now) && !continuedToday(s, now)) return _doneForToday(context, s, now);

    final opts = BuildOptions(
      energy: e, minutes: mins, locationId: loc?.id, picks: picks, rungOverrides: rungOverrides, moveKind: moveKind, routine: routine, cardio: cardioId,
      energyChosen: energy != null && energy != defaults.energy, timeChosen: minutes != null && minutes != defaults.minutes, circuit: s.settings.circuit,
    );
    final session = buildSession(s, opts, now);
    final est = estimateMinutes(session);
    final setCount = session.exercises.fold(0, (a, x) => a + x.sets.length);
    final fingerprint = '${session.type}|${session.exercises.map((x) => '${x.exId}:${x.sets.length}:${x.rung}').join(',')}|${session.cardioMinutes}|${session.stretchMinutes}|${session.spareMinutes}';
    final worked = recentWork(s, now);
    final targets = plannedTargets(session);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          TextButton.icon(
            onPressed: () => _pickLocation(context),
            icon: Icon(locationId == null && nearbyId != null && loc?.id == nearbyId ? LucideIcons.locate : locationIcon(loc?.template ?? 'none'), size: 18),
            label: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 200), child: Text(loc?.name ?? 'No location', overflow: TextOverflow.ellipsis)),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          children: [
            if (nudge != null && dismissedNudge != nudge)
              Reveal(child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Panel(
                  sunk: true,
                  padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                  child: Row(children: [
                    Icon(LucideIcons.sunrise, size: 20, color: du.accentText),
                    const SizedBox(width: 10),
                    Expanded(child: Text(nudge, style: t.bodyMedium)),
                    IconButton(onPressed: () { store.update((x) => x.person.nudgeDismissed = true); setState(() => dismissedNudge = nudge); }, icon: const Icon(LucideIcons.x, size: 18), tooltip: 'Dismiss'),
                  ]),
                ),
              )),
            Reveal(
              key: ValueKey(fingerprint),
              offset: 8,
              child: Panel(
                padding: EdgeInsets.zero,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Row(children: [
                      IconBadge(session.type == 'lift' ? LucideIcons.dumbbell : moveIcon(session.kind), accent: true),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(session.name, style: t.titleLarge),
                        Text(session.type == 'lift'
                            ? '${session.exercises.length} exercise${session.exercises.length == 1 ? '' : 's'} · $setCount sets · about $est min · ${_usualText(session)}'
                            : (session.kind == 'cardio' ? 'easy pace, your minutes' : 'a few minutes each'), style: t.bodySmall),
                      ])),
                    ]),
                  ),
                  if (session.type == 'lift' && session.exercises.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        BodyMap(fill: worked, outline: targets.keys.toSet(), height: 150),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          for (final line in _whyLines(targets, worked, s, now))
                            Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(line, style: t.bodySmall?.copyWith(color: du.ink))),
                          Text('Outlined: today. Filled: worked lately, fading over $muscleFadeDays days.', style: t.labelSmall),
                        ])),
                      ]),
                    ),
                  ],
                  const Divider(),
                  if (session.type == 'lift') ...[
                    for (var i = 0; i < session.exercises.length; i++) _exerciseRow(context, session, i),
                    if (session.cardioMinutes > 0 || session.stretchMinutes > 0 || session.spareMinutes > 0)
                      Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 14), child: Row(children: [
                        Icon(LucideIcons.footprints, size: 14, color: du.inkTertiary), const SizedBox(width: 6),
                        Expanded(child: Text([
                          if (session.cardioMinutes > 0) 'then ${session.cardioMinutes} min cardio',
                          if (session.stretchMinutes > 0) '${session.cardioMinutes > 0 ? 'and ' : 'then '}${session.stretchMinutes} min stretching',
                          if (session.spareMinutes > 0) '${session.spareMinutes} min to spare, no rush',
                        ].join(', '), style: t.bodySmall)),
                      ])),
                    if (session.exercises.isEmpty) const ListTile(leading: IconBadge(LucideIcons.circleOff, size: 36), title: Text('Nothing fits here'), subtitle: Text('Add equipment to this location, or switch to a movement workout.')),
                  ] else
                    _moveBody(context, session),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            if (s.settings.calendar) _calendarLine(context, mins),
            Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [
              Icon(ps.state == PersonState.active ? LucideIcons.circleCheck : ps.state == PersonState.atRisk ? LucideIcons.hourglass : LucideIcons.sunrise, size: 14, color: du.inkTertiary),
              const SizedBox(width: 6),
              Expanded(child: Text(_stateLine(ps), style: t.bodySmall?.copyWith(color: du.inkTertiary))),
            ])),
          ],
        )),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(color: du.bg, border: Border(top: BorderSide(color: du.line, width: 0.6))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              SizedBox(width: 56, child: Text('Energy', style: t.labelMedium)),
              Expanded(child: Segmented<Energy>(value: e, options: {for (final v in Energy.values) v: energyLabel[v]!}, icons: {for (final v in Energy.values) v: energyIcon(v)}, onChanged: (v) => setState(() => energy = v))),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              SizedBox(width: 56, child: Text('Time', style: t.labelMedium)),
              Expanded(child: SliderTheme(
                data: SliderTheme.of(context).copyWith(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9), overlayShape: const RoundSliderOverlayShape(overlayRadius: 18)),
                child: Slider(
                  value: mins.toDouble(), min: minutesMin.toDouble(), max: minutesMax.toDouble(), divisions: (minutesMax - minutesMin) ~/ minutesStep,
                  label: '$mins min', semanticFormatterCallback: (v) => '${v.round()} minutes',
                  onChanged: (v) => setState(() => minutes = clampMinutes(v.round())),
                ),
              )),
              SizedBox(width: 56, child: Text('$mins min', style: t.titleMedium?.copyWith(color: du.accentText), textAlign: TextAlign.right)),
            ]),
            if (defaults.busy != null && (minutes == null || (defaults.busy == 'easy' && energy == null)))
              Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
                Icon(LucideIcons.calendarDays, size: 13, color: du.accentText), const SizedBox(width: 6),
                Expanded(child: Text('Calendar ${day!.busyPct} % full today, so ${defaults.busy == 'easy' ? 'easy and ' : ''}$busyDayMinutes minutes by default.', style: t.labelSmall?.copyWith(color: du.accentText))),
              ])),
            Row(children: [
              if (session.type == 'lift')
                IconButton.outlined(onPressed: () => setState(() { picks = shufflePicks(s, session, loc?.equipment ?? const [], Random()); rungOverrides = {}; }), icon: const Icon(LucideIcons.shuffle, size: 20), tooltip: 'Reshuffle the exercises'),
              if (moveKind != null && item.type == 'lift')
                IconButton.outlined(onPressed: () => setState(() => moveKind = null), icon: const Icon(LucideIcons.dumbbell, size: 20), tooltip: 'Lift instead')
              else
                IconButton.outlined(onPressed: () => _moveSheet(context, loc), icon: Icon(moveIcon('cardio'), size: 20), tooltip: moveKind != null || item.type == 'move' ? 'Change movement' : 'Move instead'),
              if (session.type == 'lift' && session.exercises.length > 1)
                IconButton.outlined(onPressed: () => store.update((x) => x.settings.circuit = !x.settings.circuit), isSelected: s.settings.circuit, icon: const Icon(LucideIcons.repeat, size: 20), tooltip: s.settings.circuit ? 'Circuit: one set of each, round and round' : 'Straight sets. Tap for circuit'),
              const SizedBox(width: 8),
              Expanded(child: SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: session.type == 'lift' && session.exercises.isEmpty ? null : () => _start(context, session),
                  icon: const Icon(LucideIcons.play, size: 20),
                  label: Text('Start · ${session.name}', overflow: TextOverflow.ellipsis),
                ),
              )),
            ]),
          ]),
        ),
      ]),
    );
  }

  /// Why these exercises: what today targets, and which of those are fresh or still worked from the last days.
  List<String> _whyLines(Map<String, double> targets, Map<String, double> worked, AppState s, DateTime now) {
    final hit = targets.entries.where((x) => x.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    if (hit.isEmpty) return const [];
    String names(Iterable<String> xs) {
      final l = xs.map((x) => x.toLowerCase()).toList();
      return l.length <= 1 ? l.join() : '${l.sublist(0, l.length - 1).join(', ')} and ${l.last}';
    }
    final main = hit.where((x) => x.value >= 0.5).map((x) => x.key).toList();
    final out = <String>['Works ${names(main.isEmpty ? hit.take(3).map((x) => x.key) : main)}.'];
    final last = lastWorked(s);
    final fresh = hit.map((x) => x.key).where((g) => (worked[g] ?? 0) < 0.2).toList();
    final tired = hit.map((x) => x.key).where((g) => (worked[g] ?? 0) >= 0.5).toList();
    if (fresh.isNotEmpty) out.add('${names(fresh).replaceRange(0, 1, names(fresh)[0].toUpperCase())} ${fresh.length == 1 ? 'is' : 'are'} fresh.');
    if (tired.isNotEmpty) out.add('${names(tired).replaceRange(0, 1, names(tired)[0].toUpperCase())} ${tired.length == 1 ? 'was' : 'were'} worked ${agoText(last[tired.first], now)}.');
    return out;
  }

'''
s=s[:a]+build+s[b:]

# the exercise row: one line of numbers, a tag only when today differs from usual
a=s.index('  Widget _exerciseRow(BuildContext context, Session session, int i) {')
b=s.index('  Widget _moveBody(BuildContext context, Session session) {')
row='''  Widget _exerciseRow(BuildContext context, Session session, int i) {
    final e = session.exercises[i];
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final note = rungNote(e.exercise, e.rung);
    final unit = e.exercise.repLabel == 'seconds' ? ' s' : '';
    final rung = e.rungLabel == e.exercise.name ? 'standard' : e.rungLabel;
    final tag = e.nextLevel ? 'next level' : e.intent == intentLight ? (e.exercise.loaded ? '${(easyShare * 100).round()} %' : 'a version down') : e.lightened ? 'eased after a break' : e.edited ? 'edited' : null;
    return ListTile(
      onTap: () => _exerciseSheet(context, session, i),
      leading: IconBadge(exerciseIcon(e.exercise), size: 36),
      title: Text(e.exercise.name),
      subtitle: Text('$rung · ${e.sets.length} × ${e.atCeiling ? 'beat ${e.bestTotal} total' : '${e.lo} to ${e.hi}$unit'}${note != null ? '\\n$note' : ''}'),
      isThreeLine: note != null,
      trailing: tag == null ? null : Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: e.nextLevel ? du.accentSubtle : du.sunk, borderRadius: BorderRadius.circular(999), border: Border.all(color: e.nextLevel ? du.accentLine : du.line, width: 0.6)),
        child: Text(tag, style: t.labelSmall?.copyWith(color: e.nextLevel ? du.accentText : du.inkSecondary, letterSpacing: 0)),
      ),
    );
  }

'''
s=s[:a]+row+s[b:]

# drop the pill and the long energy hints
a=s.index('  Widget _pill(BuildContext context, IconData icon, String text) {')
b=s.index('  String _usualText(Session session) {')
s=s[:a]+s[b:]
a=s.index('  String _energyHint(Energy e, bool weekAway) => switch (e) {')
b=s.index('  String _stateLine(PersonView ps) {')
s=s[:a]+s[b:]

s=s.replace("import '../logic/ladder.dart';","import '../logic/ladder.dart';\nimport '../logic/muscles.dart';",1)
s=s.replace("import 'app.dart';","import 'app.dart';\nimport 'body_map.dart';",1)
open(p,'w',encoding='utf-8').write(s)
print('ok')
