// Today: how you are and what that makes of today. Energy, and either the minutes you have or how many exercises,
// both already answered; the body map of what the workout works and what has waited; then Plan it. When today's
// workout is done, closure.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/index.dart';
import '../data/library.dart';
import '../data/model.dart';
import '../integrations.dart';
import '../logic/after.dart';
import '../logic/builder.dart';
import '../logic/calendar.dart';
import '../logic/muscles.dart';
import '../logic/person.dart';
import 'app.dart';
import 'muscle_figure.dart';
import 'motion.dart';
import 'plan.dart';
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
  int? count;
  String? locationId;
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
    final g = s.goal!;
    final limit = s.settings.timeLimit;
    final n = (count ?? g.exercises.ideal).clamp(g.exercises.min, g.exercises.max);
    final loc = s.location(locationId ?? nearbyId);
    final item = s.plan!.rotation[s.plan!.index];
    final ps = personState(s, now);
    final nudge = nudgeFor(s, now);

    if (finishedToday(s, now) && !continuedToday(s, now)) return _doneForToday(context, s, now);

    final opts = BuildOptions(
      energy: e, minutes: mins, locationId: loc?.id, moveKind: moveKind, routine: routine, cardio: cardioId,
      energyChosen: energy != null && energy != defaults.energy, timeChosen: minutes != null && minutes != defaults.minutes, circuit: s.settings.circuit,
      exerciseCount: limit ? null : n, warmupMinutes: s.settings.warmup,
    );
    final session = buildSession(s, opts, now);
    final est = estimateMinutes(session);
    final setCount = session.exercises.fold(0, (a, x) => a + x.sets.length);
    final fingerprint = '${session.type}|${session.exercises.map((x) => '${x.exId}:${x.sets.length}:${x.rung}').join(',')}';
    final muscles = workoutMuscles(session);
    final lift = session.type == 'lift';

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
                      IconBadge(lift ? LucideIcons.dumbbell : moveIcon(session.kind), accent: true),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(session.name, style: t.titleLarge),
                        Text(lift
                            ? '${session.exercises.length} exercise${session.exercises.length == 1 ? '' : 's'} · $setCount sets · about $est min · ${_usualText(session)}'
                            : (session.kind == 'cardio' ? 'easy pace, your minutes' : 'a few minutes each'), style: t.bodySmall),
                      ])),
                    ]),
                  ),
                  if (lift && session.exercises.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        MuscleFigure(highlight: muscles, height: 170, keyLabels: const ['main', 'helping'], expandable: true, title: session.name,
                            detail: (h) => _muscleDetail(session, h)),
                        const SizedBox(width: 14),
                        Expanded(child: Padding(padding: const EdgeInsets.only(top: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          for (final line in _whyLines(s, now, muscles))
                            Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(line, style: t.bodySmall?.copyWith(color: du.ink))),
                        ]))),
                      ]),
                    ),
                  if (lift && session.exercises.isEmpty)
                    const ListTile(leading: IconBadge(LucideIcons.circleOff, size: 36), title: Text('Nothing fits here'), subtitle: Text('Add equipment to this location, or move instead.')),
                  if (!lift) ...[const Divider(), _moveBody(context, session)],
                ]),
              ),
            ),
            const SizedBox(height: 10),
            if (s.settings.calendar && limit) _calendarLine(context, mins),
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
            const SizedBox(height: 2),
            Row(children: [
              SizedBox(width: 56, child: Text('Time', style: t.labelMedium)),
              Expanded(child: Text(limit ? 'Fit it to the minutes I have' : 'No limit, pick how many exercises', style: t.bodySmall)),
              Switch(value: limit, onChanged: (v) => store.update((x) => x.settings.timeLimit = v)),
            ]),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9), overlayShape: const RoundSliderOverlayShape(overlayRadius: 18)),
              child: limit
                  ? Row(key: const ValueKey('minutes'), children: [
                      Expanded(child: Slider(
                        value: mins.toDouble(), min: minutesMin.toDouble(), max: minutesMax.toDouble(), divisions: (minutesMax - minutesMin) ~/ minutesStep,
                        label: '$mins min', semanticFormatterCallback: (v) => '${v.round()} minutes',
                        onChanged: (v) => setState(() => minutes = clampMinutes(v.round())),
                      )),
                      SizedBox(width: 76, child: Text('$mins min', style: t.titleMedium?.copyWith(color: du.accentText), textAlign: TextAlign.right)),
                    ])
                  : Row(key: const ValueKey('count'), children: [
                      Expanded(child: Slider(
                        value: n.toDouble(), min: g.exercises.min.toDouble(), max: g.exercises.max.toDouble(),
                        divisions: g.exercises.max > g.exercises.min ? g.exercises.max - g.exercises.min : null,
                        label: '$n', semanticFormatterCallback: (v) => '${v.round()} exercises',
                        onChanged: g.exercises.max > g.exercises.min ? (v) => setState(() => count = v.round()) : null,
                      )),
                      SizedBox(width: 112, child: Text('$n exercise${n == 1 ? '' : 's'}', style: t.titleMedium?.copyWith(color: du.accentText), textAlign: TextAlign.right)),
                    ]),
            ),
            if (limit && defaults.busy != null && (minutes == null || (defaults.busy == 'easy' && energy == null)))
              _hint(context, LucideIcons.calendarDays, 'Calendar ${day!.busyPct} % full today, so ${defaults.busy == 'easy' ? 'easy and ' : ''}$busyDayMinutes minutes by default.'),
            if (!limit)
              _hint(context, LucideIcons.info, 'Your usual is ${g.exercises.ideal}, between ${g.exercises.min} and ${g.exercises.max} in Settings. About $est min.'),
            const SizedBox(height: 4),
            Row(children: [
              if (moveKind != null && item.type == 'lift')
                IconButton.outlined(onPressed: () => setState(() => moveKind = null), icon: const Icon(LucideIcons.dumbbell, size: 20), tooltip: 'Lift instead')
              else
                IconButton.outlined(onPressed: () => _moveSheet(context, loc), icon: Icon(moveIcon('cardio'), size: 20), tooltip: moveKind != null || item.type == 'move' ? 'Change movement' : 'Move instead'),
              const SizedBox(width: 8),
              Expanded(child: SizedBox(
                height: 52,
                child: lift
                    ? FilledButton.icon(
                        onPressed: session.exercises.isEmpty ? null : () => _plan(context, opts),
                        icon: const Icon(LucideIcons.chevronRight, size: 20), iconAlignment: IconAlignment.end,
                        label: const Text('Plan it'),
                      )
                    : FilledButton.icon(
                        onPressed: () => _startMove(context, session),
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

  Widget _hint(BuildContext context, IconData icon, String text) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 13, color: du.accentText)), const SizedBox(width: 6),
      Expanded(child: Text(text, style: t.labelSmall?.copyWith(color: du.accentText))),
    ]));
  }

  /// For a tapped muscle: which of today's exercises use it.
  String? _muscleDetail(Session x, MuscleHit h) {
    final main = <String>[], helping = <String>[];
    for (final e in x.exercises) {
      if (e.exercise.primary.contains(h.name)) { main.add(e.exercise.name); }
      else if (e.exercise.secondary.contains(h.name)) { helping.add(e.exercise.name); }
    }
    if (main.isEmpty && helping.isEmpty) return 'Not worked today.';
    return [if (main.isNotEmpty) 'Main in ${main.join(', ')}.', if (helping.isNotEmpty) 'Helps in ${helping.join(', ')}.'].join(' ');
  }

  /// What the workout works, the main muscles then the helping ones, and what has waited longest.
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
    for (final e in lastWorked(s).entries) {
      if (e.value == null) continue;
      final grp = muscleGroup(e.key);
      if (last[grp] == null || e.value!.isAfter(last[grp]!)) last[grp] = e.value!;
    }
    final waited = last.entries.where((e) => !todayGroups.contains(e.key) && daysAgo(e.value, now) >= 7).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return [
      if (main.isNotEmpty) 'Works ${names(main)}.',
      if (helping.isNotEmpty) 'Also ${names(helping)}.',
      if (waited.isNotEmpty) 'Not lately: ${waited.take(2).map((e) => '${e.key.toLowerCase()} ${daysAgo(e.value, now)} days').join(', ')}.',
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

  Future<void> _plan(BuildContext context, BuildOptions opts) async {
    final started = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => PlanScreen(base: opts)));
    if (started == true && mounted) setState(() { moveKind = null; energy = null; minutes = null; count = null; });
  }

  void _startMove(BuildContext context, Session session) {
    final store = context.store;
    store.update((s) => startSession(s, session, store.now));
    setState(() { moveKind = null; energy = null; minutes = null; count = null; });
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
    if (id != null) setState(() => locationId = id);
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
}
