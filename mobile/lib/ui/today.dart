// Today: two questions already answered, one workout, one start button. When today's workout is done, closure.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/library.dart';
import '../data/model.dart';
import '../integrations.dart';
import '../logic/after.dart';
import '../logic/builder.dart';
import '../logic/calendar.dart';
import '../logic/ladder.dart';
import '../logic/muscles.dart';
import '../logic/person.dart';
import 'app.dart';
import 'muscle_figure.dart';
import 'exercise_card.dart';
import 'how.dart';
import 'motion.dart';
import 'theme.dart';
import 'widgets.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});
  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  Energy? energy;
  int? minutes;
  String? locationId;
  Map<String, String> picks = {};
  Map<String, int> rungOverrides = {};
  String? moveKind;
  String? routine;
  String? cardioId;
  String? dismissedNudge;
  DayShape? day;           // today's calendar shape, when allowed
  String? nearbyId;        // the saved location nearest to the phone, when allowed
  bool contextLoaded = false;
  bool syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadContext());
  }

  Future<void> _loadContext() async {
    if (!mounted) return;
    final store = context.store;
    final st = store.state.settings;
    final locations = store.state.locations;
    DayShape? shape;
    String? near;
    if (st.calendar) { setState(() => syncing = true); shape = await CalendarSync.sync(store.state, store.now); }
    if (st.location) {
      final here = await LocationBridge.current();
      if (here != null) near = LocationBridge.nearest(locations, here)?.id;
    }
    if (!mounted) return;
    setState(() { day = shape; nearbyId = near; contextLoaded = true; syncing = false; });
  }

  @override
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
    final muscles = workoutMuscles(session);

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
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        MuscleFigure(highlight: muscles, height: 170, keyLabels: const ['main', 'helping'], expandable: true, title: session.name,
                            detail: (h) => _muscleDetail(session, h)),
                        const SizedBox(width: 14),
                        Expanded(child: Padding(padding: const EdgeInsets.only(top: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          for (final line in _whyLines(muscles))
                            Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(line, style: t.bodySmall?.copyWith(color: du.ink))),
                        ]))),
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
                          if (session.cardioMinutes > 0 || session.stretchMinutes > 0)
                            'then ${[if (session.cardioMinutes > 0) '${session.cardioMinutes} min cardio', if (session.stretchMinutes > 0) '${session.stretchMinutes} min stretching'].join(' and ')}',
                          if (session.spareMinutes > 0) '${session.spareMinutes} min to spare, no rush',
                        ].join(' · '), style: t.bodySmall)),
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
                IconButton.outlined(
                  onPressed: () => store.update((x) => x.settings.circuit = !x.settings.circuit), isSelected: s.settings.circuit,
                  style: IconButton.styleFrom(backgroundColor: s.settings.circuit ? du.accentSubtle : du.surface, foregroundColor: s.settings.circuit ? du.accentText : du.ink, side: BorderSide(color: s.settings.circuit ? du.accentStrong : du.line, width: s.settings.circuit ? 1.5 : 0.6)),
                  icon: const Icon(LucideIcons.repeat, size: 20), tooltip: s.settings.circuit ? 'Circuit: one set of each, round and round' : 'Straight sets. Tap for circuit',
                ),
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

  /// For a tapped muscle: which of today's exercises use it.
  String? _muscleDetail(Session x, MuscleHit h) {
    if (h.dataset.isEmpty) return null;
    final main = <String>[], helping = <String>[];
    for (final e in x.exercises) {
      if (e.exercise.primary.map(datasetGroupOf).contains(h.dataset)) { main.add(e.exercise.name); }
      else if (e.exercise.secondary.map(datasetGroupOf).contains(h.dataset)) { helping.add(e.exercise.name); }
    }
    if (main.isEmpty && helping.isEmpty) return 'Not worked today.';
    return [if (main.isNotEmpty) 'Main in ${main.join(', ')}.', if (helping.isNotEmpty) 'Helps in ${helping.join(', ')}.'].join(' ');
  }

  /// What the workout works: the main muscles, then the helping ones.
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

  Widget _doneForToday(BuildContext context, AppState s, DateTime now) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final store = context.store;
    final last = s.lastSession!;
    final sets = last.exercises.fold(0, (a, x) => a + x.attempted.length);
    final mins = last.elapsedMinutes;
    final next = s.plan!.rotation[s.plan!.index];
    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
        Center(child: Pop(child: Container(
          width: 88, height: 88,
          decoration: BoxDecoration(shape: BoxShape.circle, color: du.accentSubtle, border: Border.all(color: du.accentLine, width: 0.6)),
          child: Icon(LucideIcons.check, size: 44, color: du.accentStrong),
        ))),
        const SizedBox(height: 18),
        Reveal(delay: const Duration(milliseconds: 100), child: Text('Done for today.', style: t.headlineLarge, textAlign: TextAlign.center)),
        const SizedBox(height: 8),
        Reveal(delay: const Duration(milliseconds: 180), child: Text(last.note, style: t.bodyLarge?.copyWith(color: du.inkSecondary), textAlign: TextAlign.center)),
        const SizedBox(height: 24),
        Reveal(delay: const Duration(milliseconds: 260), child: Panel(child: Row(children: [
          Expanded(child: StatTile(label: 'Workout', value: last.name, icon: last.type == 'lift' ? LucideIcons.dumbbell : moveIcon(last.kind))),
          if (last.type == 'lift') Expanded(child: StatTile(label: 'Sets', value: '$sets', icon: LucideIcons.repeat)),
          if (mins != null && mins >= 1 && mins <= 240) Expanded(child: StatTile(label: 'Minutes', value: '$mins', icon: LucideIcons.timer)),
        ]))),
        const SizedBox(height: 24),
        Row(children: [
          Icon(LucideIcons.sunrise, size: 16, color: du.inkTertiary), const SizedBox(width: 8),
          Expanded(child: Text('${next.name} is ready tomorrow. Nothing is waiting for you tonight.', style: t.bodyMedium?.copyWith(color: du.inkSecondary))),
        ]),
        const SizedBox(height: 28),
        OutlinedButton.icon(onPressed: () => store.update((x) => x.plan!.continuedOn = now), icon: const Icon(LucideIcons.skipForward, size: 18), label: Text('Start ${next.name} anyway')),
        const SizedBox(height: 8),
        TextButton.icon(onPressed: () { store.update((x) => x.plan!.continuedOn = now); setState(() => moveKind = 'cardio'); }, icon: const Icon(LucideIcons.footprints, size: 18), label: const Text('Add a walk or mobility')),
      ]),
    );
  }

  String _usualText(Session session) {
    final r = session.relative;
    if (r > 1.05) {
      final names = session.exercises.where((e) => e.nextLevel).map((e) => e.exercise.name.toLowerCase()).toList();
      return 'the next level on ${names.length <= 2 ? names.join(' and ') : '${names.length} exercises'}';
    }
    if (r < 0.95) return '${(r * 20).round() * 5} % of your usual';
    return 'your usual';
  }

  String _stateLine(PersonView ps) {
    if (ps.last == null) return 'First workout. Everything starts conservative and corrects fast.';
    return '${stateLabel[ps.state]} · ${ps.daysSince == 0 ? 'trained today' : '${ps.daysSince} day${ps.daysSince == 1 ? '' : 's'} since the last workout'}';
  }

  Widget _exerciseRow(BuildContext context, Session session, int i) {
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
      subtitle: Text('$rung · ${e.sets.length} × ${e.atCeiling ? 'beat ${e.bestTotal} total' : '${e.lo} to ${e.hi}$unit'}${note != null ? '\n$note' : ''}'),
      isThreeLine: note != null,
      trailing: tag == null ? null : Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: e.nextLevel ? du.accentSubtle : du.sunk, borderRadius: BorderRadius.circular(999), border: Border.all(color: e.nextLevel ? du.accentLine : du.line, width: 0.6)),
        child: Text(tag, style: t.labelSmall?.copyWith(color: e.nextLevel ? du.accentText : du.inkSecondary, letterSpacing: 0)),
      ),
    );
  }

  Widget _moveBody(BuildContext context, Session session) {
    if (session.kind == 'cardio') {
      final c = cardio.firstWhere((x) => x.id == session.cardio, orElse: () => cardio.last);
      return ListTile(leading: const IconBadge(LucideIcons.footprints, size: 36), title: Text(c.name), subtitle: Text('${session.minutes} minutes at a pace you could talk through. One tap for effort at the end.'));
    }
    final r = routines[session.routine]!;
    return Column(children: [
      for (final mv in r.moves) ListTile(dense: true, leading: Icon(LucideIcons.stretchHorizontal, size: 18, color: context.du.inkTertiary), title: Text(mv.n), subtitle: Text('${r.seconds} seconds')),
    ]);
  }

  void _start(BuildContext context, Session session) {
    final store = context.store;
    store.update((s) => startSession(s, session, store.now));
    setState(() { picks = {}; rungOverrides = {}; moveKind = null; energy = null; minutes = null; });
  }

  /// The suggested slot and when the calendar was last read, with a tap to read it again.
  Widget _calendarLine(BuildContext context, int mins) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final store = context.store;
    final d = day;
    final slot = d == null ? null : suggestSlot(d, mins, store.now);
    final text = d == null
        ? (syncing ? 'Reading your calendar…' : 'Calendar not read. Check its permission in Settings.')
        : slot == null
            ? 'No free $mins minutes left in your day. Whatever you can is fine.'
            : 'A free slot at ${hhmm(slot.slot.start)}${slot.advisory ? ', though that is the edge of your day' : ''}.';
    return Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [
      Icon(LucideIcons.clock, size: 14, color: du.inkTertiary), const SizedBox(width: 6),
      Expanded(child: Text(text, style: t.bodySmall)),
      Pressable(onTap: syncing ? null : _loadContext, borderRadius: 999, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(LucideIcons.refreshCw, size: 12, color: du.accentText), const SizedBox(width: 4),
        Text(CalendarSync.agoText(DateTime.now()), style: t.labelSmall?.copyWith(color: du.accentText)),
      ]))),
    ]));
  }

  Future<void> _pickLocation(BuildContext context) async {
    final s = context.store.state;
    final current = s.location(locationId ?? nearbyId);
    final id = await showSheet<String>(context, ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 16), children: [
      const SheetHeader('Where are you?', icon: LucideIcons.mapPin),
      for (final l in s.locations)
        ListTile(
          leading: IconBadge(locationIcon(l.template), size: 36, accent: l.id == current?.id),
          title: Text(l.name), subtitle: Text('${l.equipment.isEmpty ? 'bodyweight only' : '${l.equipment.length} items'}${l.id == nearbyId ? ' · nearby' : ''}'),
          trailing: l.id == current?.id ? Icon(LucideIcons.check, color: context.du.accentStrong) : null,
          onTap: () => Navigator.pop(context, l.id),
        ),
    ]));
    if (id != null) setState(() { locationId = id; picks = {}; rungOverrides = {}; });
  }

  Future<void> _moveSheet(BuildContext context, Location? loc) async {
    final options = cardioFor(loc?.equipment ?? const []);
    final r = await showSheet<(String, String?)>(context, ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 16), children: [
      const SheetHeader('Move instead', subtitle: 'Cardio takes the minutes you set. Mobility takes what it takes.', icon: LucideIcons.footprints),
      const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 0), child: SectionHeader('Cardio')),
      for (final c in options) ListTile(leading: const IconBadge(LucideIcons.footprints, size: 36), title: Text(c.name), onTap: () => Navigator.pop(context, ('cardio', c.id))),
      const Padding(padding: EdgeInsets.fromLTRB(20, 12, 20, 0), child: SectionHeader('Mobility')),
      for (final x in routines.values) ListTile(leading: const IconBadge(LucideIcons.stretchHorizontal, size: 36), title: Text(x.name), subtitle: Text('${x.moves.length} moves · about ${(x.moves.length * x.seconds / 60).ceil()} min'), onTap: () => Navigator.pop(context, ('mobility', x.id))),
    ]));
    if (r == null) return;
    setState(() {
      moveKind = r.$1;
      if (r.$1 == 'cardio') {
        cardioId = r.$2;
      } else {
        routine = r.$2;
      }
    });
  }

  Future<void> _exerciseSheet(BuildContext context, Session session, int i) async {
    final store = context.store;
    final s = store.state;
    final e = session.exercises[i];
    final ex = e.exercise;
    final st = ensureState(s, ex);
    final loc = s.location(locationId ?? nearbyId);
    final equipmentHere = loc?.equipment ?? const <String>[];
    final alts = alternatives(s, session, i, equipmentHere);
    final ceiling = ceilingFor(ex, equipmentHere);
    var rung = e.rung;
    await showSheet<void>(context, StatefulBuilder(builder: (context, setSheet) {
      final t = Theme.of(context).textTheme;
      final du = context.du;
      final floor = ex.loaded ? floorRung(s, ex, st) : 0;
      return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(0, 0, 0, 20), children: [
        SheetHeader(ex.name, subtitle: '${difficultyLabel[e.difficulty]} · ${e.lo} to ${e.hi} ${ex.repLabel} · ${mmss(st.secPerSet)} per set', icon: exerciseIcon(ex)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeader("Today's level", icon: LucideIcons.circleDot),
            const Explain(levelExplainer),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Column(children: [
                Row(children: [
                  IconButton.outlined(onPressed: rung > floor ? () => setSheet(() => rung--) : null, icon: const Icon(LucideIcons.minus), tooltip: 'Level down'),
                  Expanded(child: AnimatedSwitcher(
                    duration: m(context, durBase),
                    transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.95, end: 1.0).animate(a), child: c)),
                    child: Column(key: ValueKey(rung), children: [
                      Text(rungLabel(s, ex, st, rung, e.range), style: t.titleMedium?.copyWith(color: rung == st.rung ? du.ink : du.accentText), textAlign: TextAlign.center),
                      Text(rungNote(ex, rung) ?? (rung == st.rung ? 'your level' : rung > st.rung ? '${rung - st.rung} up from your level' : '${st.rung - rung} down from your level'), style: t.bodySmall, textAlign: TextAlign.center),
                    ]),
                  )),
                  IconButton.outlined(onPressed: ceiling == null || rung < ceiling ? () => setSheet(() => rung++) : null, icon: const Icon(LucideIcons.plus), tooltip: 'Level up'),
                ]),
                const SizedBox(height: 8),
                AnimatedSwitcher(duration: m(context, durBase), child: Text(howAt(ex, rung), key: ValueKey('how$rung'), style: t.bodySmall)),
              ]),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: rung == e.rung ? null : () { setState(() => rungOverrides[e.slot] = rung); Navigator.pop(context); }, icon: const Icon(LucideIcons.calendarDays, size: 18), label: const Text('Just today'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: rung == st.rung ? null : () { store.update((x) => setRung(x, ex, rung)); setState(() => rungOverrides.remove(e.slot)); Navigator.pop(context); }, icon: const Icon(LucideIcons.save, size: 18), label: const Text('Save as my level'))),
            ]),
            const SizedBox(height: 20),
            if (alts.isNotEmpty) const SectionHeader('Swap for', icon: LucideIcons.replace),
          ]),
        ),
        for (final a in alts)
          ListTile(
            leading: IconBadge(exerciseIcon(a), size: 36),
            title: Text(a.name),
            subtitle: Text('${s.ex[a.id] != null ? rungLabel(s, a, s.ex[a.id]!, s.ex[a.id]!.rung) : 'not yet practised'} · ${difficultyLabel[difficultyInPlay(a, s.ex[a.id])]}'),
            trailing: Icon(LucideIcons.chevronRight, size: 18, color: du.inkTertiary),
            onTap: () { setState(() { picks[e.slot] = a.id; rungOverrides.remove(e.slot); }); Navigator.pop(context); },
          ),
        const SizedBox(height: 8),
        Center(child: TextButton.icon(onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseCardScreen(ex.id))); }, icon: const Icon(LucideIcons.bookOpen, size: 18), label: const Text('Open the exercise card'))),
      ]);
    }));
  }
}
