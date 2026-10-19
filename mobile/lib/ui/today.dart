// Today: the workout, ready to start. The day's name from the muscles it works ("Back and biceps day"), one line of
// numbers, then the plan itself: the warm-up, each exercise with its level, sets and minutes, cardio and stretching.
// Tap an exercise to swap it, change today's level, move it or leave it out; tap the muscles panel to change which
// muscle groups are excluded, available or forced (the muscle picker). Energy and time sit at the bottom, already
// answered, with Start. When today's workout is done, closure.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/index.dart';
import '../data/library.dart';
import '../data/model.dart';
import '../integrations.dart';
import '../logic/after.dart';
import '../logic/builder.dart';
import '../logic/calendar.dart';
import '../logic/ladder.dart';
import '../logic/muscle_map.dart';
import '../logic/muscle_plan.dart';
import '../logic/person.dart';
import '../logic/selection.dart';
import '../logic/workout.dart';
import 'app.dart';
import 'exercise_card.dart';
import 'how.dart';
import 'motion.dart';
import 'muscle_figure.dart';
import 'muscle_picker.dart';
import 'theme.dart';
import 'widgets.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});
  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  // today's answers
  Energy? energy;
  int? minutes;
  int? count;
  String? locationId;
  String? moveKind;
  String? routine;
  String? cardioId;
  bool liftInstead = false; // lift today even though a movement day is due
  // the muscle plan: null until the user has changed it, so the defaults follow the strain of the moment
  Map<String, MuscleState>? muscleStates;
  List<String> muscleOrder = [];
  // the plan's edits, by slot, for today
  Map<String, String> picks = {};
  Map<String, int> rungOverrides = {};
  List<String> order = [];
  Set<String> leftOut = {};
  int? warmup;
  bool skipCardio = false;
  bool skipStretch = false;

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

  /// Today's states for the eleven groups: the user's, else the defaults from the strain of the moment.
  Map<String, MuscleState> _states(AppState s, DateTime now) => muscleStates ?? defaultMuscleStates(MuscleMap(s).currentStrainPoints(now));

  /// Everything the builder needs, from today's answers, the muscle plan and the plan's edits. [asBuilt] leaves the
  /// edits out: the workout as the builder first made it.
  BuildOptions _options(AppState s, DateTime now, {Map<String, MuscleState>? states, List<String>? order, bool asBuilt = false}) {
    final defaults = defaultsFor(s, now, busyShare: day?.busyShare);
    final g = s.goal!;
    final limit = s.settings.timeLimit;
    final n = (count ?? g.exercises.ideal).clamp(g.exercises.min, g.exercises.max);
    final loc = s.location(locationId ?? nearbyId);
    final st = states ?? _states(s, now);
    final ord = order ?? muscleOrder;
    return BuildOptions(
      energy: energy ?? defaults.energy, minutes: minutes ?? defaults.minutes, locationId: loc?.id, moveKind: moveKind, routine: routine, cardio: cardioId,
      energyChosen: energy != null && energy != defaults.energy, timeChosen: minutes != null && minutes != defaults.minutes, circuit: s.settings.circuit,
      exerciseCount: limit ? null : n, warmupMinutes: warmup ?? s.settings.warmup, skipCardio: skipCardio, skipStretch: skipStretch,
      muscles: groupsIn(st, MuscleState.forced, ord), excluded: groupsIn(st, MuscleState.excluded).toSet(), liftInstead: liftInstead,
      picks: asBuilt ? const {} : picks, rungOverrides: asBuilt ? const {} : rungOverrides, order: asBuilt ? const [] : this.order, leftOut: asBuilt ? const {} : leftOut,
    );
  }

  void _reset() => setState(() {
        moveKind = null; energy = null; minutes = null; count = null; liftInstead = false;
        muscleStates = null; muscleOrder = []; picks = {}; rungOverrides = {}; order = []; leftOut = {}; warmup = null; skipCardio = false; skipStretch = false;
      });

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
    final ps = personState(s, now);
    final nudge = nudgeFor(s, now);

    if (finishedToday(s, now) && !continuedToday(s, now)) return _doneForToday(context, s, now);

    final opts = _options(s, now);
    final session = buildSession(s, opts, now);
    final est = estimateMinutes(session);
    final setCount = session.exercises.fold(0, (a, x) => a + x.sets.length);
    final fingerprint = '${session.type}|${session.name}|${session.exercises.map((x) => '${x.exId}:${x.sets.length}:${x.rung}').join(',')}';
    final lift = session.type == 'lift';
    final states = _states(s, now);
    final current = MuscleMap(s).currentStrainPoints(now);

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
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // the day's name and its numbers
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.only(top: 2), child: IconBadge(lift ? LucideIcons.dumbbell : moveIcon(session.kind), accent: true)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(lift && session.exercises.isEmpty ? 'Nothing to work' : session.name, style: t.headlineMedium),
                      const SizedBox(height: 2),
                      Text(lift
                          ? (session.exercises.isEmpty ? 'Choose muscles below, or move instead.' : '${session.exercises.length} exercise${session.exercises.length == 1 ? '' : 's'} · $setCount sets · about $est min · ${_usualText(session)}')
                          : (session.kind == 'cardio' ? 'easy pace, your minutes' : 'a few minutes each'), style: t.bodySmall),
                    ])),
                  ]),
                ),
                const SizedBox(height: 12),
                if (lift) ...[
                  _musclesPanel(context, s, now, session, states, current),
                  const SizedBox(height: 12),
                  if (session.exercises.isEmpty)
                    Panel(padding: EdgeInsets.zero, child: ListTile(
                      leading: const IconBadge(LucideIcons.circleOff, size: 36),
                      title: const Text('Nothing fits today'),
                      subtitle: Text(groupsIn(states, MuscleState.excluded).length == muscleGroups.length
                          ? 'Every muscle is excluded. Tap the muscles to make some available.'
                          : 'Nothing here works the muscles available. Add equipment to this location, change the muscles, or move instead.'),
                      trailing: Icon(LucideIcons.chevronRight, size: 18, color: du.inkTertiary),
                      onTap: () => _pickMuscles(context),
                    ))
                  else
                    _plan(context, s, session, est),
                ],
                if (!lift) Panel(padding: EdgeInsets.zero, child: _moveBody(context, session)),
              ]),
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
              if (!lift) ...[
                IconButton.outlined(onPressed: () => setState(() { moveKind = null; liftInstead = true; }), icon: const Icon(LucideIcons.dumbbell, size: 20), tooltip: 'Lift instead'),
                const SizedBox(width: 8),
                IconButton.outlined(onPressed: () => _moveSheet(context, loc), icon: Icon(moveIcon(session.kind), size: 20), tooltip: 'Change movement'),
              ] else ...[
                IconButton.outlined(onPressed: () => _moveSheet(context, loc), icon: Icon(moveIcon('cardio'), size: 20), tooltip: 'Move instead'),
                const SizedBox(width: 8),
                IconButton.outlined(onPressed: () => _pickMuscles(context), icon: const Icon(LucideIcons.personStanding, size: 20), tooltip: 'Muscles'),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: session.exercises.isEmpty ? null : () => setState(() { picks = shufflePicks(s, session, loc?.equipment ?? const [], Random(), now); rungOverrides = {}; order = []; leftOut = {}; }),
                  icon: const Icon(LucideIcons.shuffle, size: 20), tooltip: 'Reshuffle the exercises',
                ),
              ],
              const SizedBox(width: 8),
              Expanded(child: SizedBox(
                height: 52,
                child: lift
                    ? FilledButton.icon(
                        onPressed: session.exercises.isEmpty ? null : () => _start(context, session),
                        icon: const Icon(LucideIcons.play, size: 20),
                        label: const Text('Start'),
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

  // ---------- the muscles

  /// The muscles panel: a small figure painted like the picker, and what today works, forces and leaves out. Tap to open
  /// the picker.
  Widget _musclesPanel(BuildContext context, AppState s, DateTime now, Session session, Map<String, MuscleState> states, StrainPoints current) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final fills = muscleFills(states, current, du.accentStrong);
    final working = <String>[];
    for (final e in session.exercises) { if (!working.contains(e.muscle)) working.add(e.muscle); }
    final forced = groupsIn(states, MuscleState.forced, muscleOrder);
    final excluded = groupsIn(states, MuscleState.excluded);
    final strained = excluded.where((g) => groupShade(current, g) > 0).length;
    String lower(Iterable<String> xs) => listWords(xs.map((g) => g.toLowerCase()));
    return Panel(
      onTap: () => _pickMuscles(context),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(children: [
        MuscleFigure(highlight: fills.highlight, tint: fills.tint, height: 92, interactive: false),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('MUSCLES', style: t.labelSmall),
          const SizedBox(height: 3),
          Text(working.isEmpty ? 'Nothing to work.' : 'Working ${lower(working)}.', style: t.bodyMedium),
          if (forced.isNotEmpty) Text('Forced: ${lower(forced)}.', style: t.bodySmall?.copyWith(color: du.accentText)),
          Text(excluded.isEmpty
              ? 'Every muscle available.'
              : 'Excluded: ${lower(excluded)}${strained > 0 ? strained == excluded.length ? ', carrying strain' : ', $strained carrying strain' : ''}.', style: t.bodySmall),
          const SizedBox(height: 3),
          Text(muscleStates == null ? 'Tap to change' : 'Changed today · tap to change', style: t.labelSmall?.copyWith(color: du.accentText)),
        ])),
        Icon(LucideIcons.chevronRight, size: 18, color: du.inkTertiary),
      ]),
    );
  }

  Future<void> _pickMuscles(BuildContext context) async {
    final store = context.store;
    final r = await Navigator.of(context).push<(Map<String, MuscleState>, List<String>)>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => MusclePickerScreen(
        states: _states(store.state, store.now), order: muscleOrder,
        preview: (st, ord) => buildSession(store.state, _options(store.state, store.now, states: st, order: ord), store.now),
      ),
    ));
    if (r == null || !mounted) return;
    // the muscles changed, so the slots did: the plan's edits start over
    setState(() { muscleStates = r.$1; muscleOrder = r.$2; picks = {}; rungOverrides = {}; order = []; leftOut = {}; });
  }

  // ---------- the plan

  Widget _plan(BuildContext context, AppState s, Session session, int est) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final store = context.store;
    final g = s.goal!;
    final items = workoutItems(session);
    double planned(WorkoutItem it) => switch (it.kind) {
          ItemKind.exercise => plannedSeconds(session.exercises[it.exercises.single]),
          ItemKind.circuit => it.exercises.fold(0.0, (a, i) => a + plannedSeconds(session.exercises[i])),
          _ => it.minutes * 60.0,
        };
    final circuit = s.settings.circuit && session.exercises.length > 1;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Panel(padding: EdgeInsets.zero, child: Column(children: [
        _blockRow(context, LucideIcons.flame, 'Warm-up', session.warmupMinutes == 0 ? 'None' : '${session.warmupMinutes} minutes, easy', session.warmupMinutes, () => _warmupSheet(context, s)),
        const Divider(height: 1),
        for (var i = 0; i < session.exercises.length; i++) ...[
          _exerciseRow(context, session, i),
          const Divider(height: 1),
        ],
        if (g.cardioPct > 0 || session.cardioMinutes > 0) ...[
          _blockRow(context, LucideIcons.footprints, 'Cardio', skipCardio ? 'Not today' : 'An easy pace you could talk through', session.cardioMinutes, () => _blockSheet(context, 'Cardio', skipCardio, (v) => skipCardio = v)),
          const Divider(height: 1),
        ],
        if (g.stretchPct > 0 || session.stretchMinutes > 0) ...[
          _blockRow(context, LucideIcons.stretchHorizontal, 'Stretching', skipStretch ? 'Not today' : 'For the muscles you worked', session.stretchMinutes, () => _blockSheet(context, 'Stretching', skipStretch, (v) => skipStretch = v)),
          const Divider(height: 1),
        ],
        if (session.exercises.length > 1)
          ListTile(
            leading: IconBadge(circuit ? LucideIcons.repeat : LucideIcons.listOrdered, size: 36),
            title: Text(circuit ? 'Circuit' : 'One at a time'),
            subtitle: Text(circuit ? 'One set of each, round and round, with a rest between rounds.' : 'Every set of one exercise, then the next.'),
            trailing: Icon(LucideIcons.chevronRight, size: 18, color: du.inkTertiary),
            onTap: () => _orderSheet(context, s),
          ),
      ])),
      const SizedBox(height: 10),
      if (items.isNotEmpty)
        ClipRRect(borderRadius: BorderRadius.circular(4), child: SizedBox(height: 8, child: Row(children: [
          for (var i = 0; i < items.length; i++)
            Expanded(flex: max(1, planned(items[i]).round()), child: Container(
              margin: EdgeInsets.only(right: i == items.length - 1 ? 0 : 2),
              decoration: BoxDecoration(color: items[i].lifting ? (i.isEven ? du.accentStrong : du.accentText) : du.accentLine, borderRadius: BorderRadius.circular(3)),
            )),
        ]))),
      const SizedBox(height: 6),
      Text('About $est min, done around ${hhmm(store.now.add(Duration(minutes: est)))}. Each exercise\'s time includes its rest.${session.spareMinutes > 0 ? ' ${session.spareMinutes} min to spare, no rush.' : ''}', style: t.labelSmall),
      const SizedBox(height: 4),
      Text('Tap an exercise to swap it, move it, leave it out or change today\'s level.', style: t.bodySmall),
    ]);
  }

  void _start(BuildContext context, Session session) {
    final store = context.store;
    store.update((s) {
      if (warmup != null) s.settings.warmup = warmup!;
      // the exercises the builder put on the plan that were swapped out: their count in a row goes up
      if (picks.isNotEmpty) {
        final built = buildSession(s, _options(s, store.now, asBuilt: true), store.now);
        final chosen = session.exercises.map((e) => e.exId).toSet();
        noteSwappedOut(s, [for (final e in built.exercises) if (picks.containsKey(e.slot) && !chosen.contains(e.exId)) e.exId]);
      }
      startWorkout(s, session, store.now);
    });
    _reset();
  }

  Widget _tag(BuildContext context, String text, {bool accent = false}) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Padding(padding: const EdgeInsets.only(left: 6), child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: accent ? du.accentSubtle : du.sunk, borderRadius: BorderRadius.circular(999), border: Border.all(color: accent ? du.accentLine : du.line, width: 0.6)),
      child: Text(text, style: t.labelSmall?.copyWith(color: accent ? du.accentText : du.inkSecondary, letterSpacing: 0)),
    ));
  }

  Widget _blockRow(BuildContext context, IconData icon, String title, String subtitle, int minutes, VoidCallback onTap) {
    final t = Theme.of(context).textTheme;
    return ListTile(
      onTap: onTap,
      leading: IconBadge(icon, size: 36),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (minutes > 0) Text('$minutes min', style: t.bodySmall),
        const SizedBox(width: 4),
        Icon(LucideIcons.chevronRight, size: 18, color: context.du.inkTertiary),
      ]),
    );
  }

  Widget _exerciseRow(BuildContext context, Session session, int i) {
    final e = session.exercises[i];
    final t = Theme.of(context).textTheme;
    final note = rungNote(e.exercise, e.rung);
    final unit = e.exercise.repLabel == 'seconds' ? ' s' : '';
    final rung = e.rungLabel == e.exercise.name ? 'standard' : e.rungLabel;
    final tag = e.nextLevel ? 'next level' : e.intent == intentLight ? (e.exercise.loaded ? '${(easyShare * 100).round()} %' : 'a version down') : e.lightened ? 'eased after a break' : e.edited ? 'edited' : null;
    final word = context.store.state.ex[e.exId]?.preference == prefNo ? 'not for you' : e.fresh ? 'new' : e.asked ? 'forced' : null;
    return ListTile(
      onTap: () => _exerciseSheet(context, session, i),
      leading: IconBadge(exerciseIcon(e.exercise), size: 36),
      title: Row(children: [
        Flexible(child: Text(e.exercise.name, overflow: TextOverflow.ellipsis)),
        if (tag != null) _tag(context, tag, accent: e.nextLevel),
        if (word != null) _tag(context, word, accent: word == 'new' || word == 'forced'),
      ]),
      subtitle: Text('${e.muscle} · $rung · ${e.sets.length} × ${e.atCeiling ? 'beat ${e.bestTotal} total' : '${e.lo} to ${e.hi}$unit'}${note != null ? '\n$note' : ''}'),
      isThreeLine: note != null,
      trailing: Text('${max(1, (plannedSeconds(e) / 60).round())} min', style: t.bodySmall),
    );
  }

  /// Move an exercise one place up or down: the order is the user's from then on, for today.
  void _move(Session session, int i, int dir) {
    final slots = session.exercises.map((e) => e.slot).toList();
    final j = i + dir;
    if (j < 0 || j >= slots.length) return;
    final tmp = slots[i];
    slots[i] = slots[j];
    slots[j] = tmp;
    setState(() => order = slots);
  }

  Future<void> _warmupSheet(BuildContext context, AppState s) async {
    final current = warmup ?? s.settings.warmup;
    final v = await showSheet<int>(context, ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 16), children: [
      const SheetHeader('Warm-up', subtitle: 'A few easy minutes before the first exercise, inside your time.', icon: LucideIcons.flame),
      for (final m in warmupChoices)
        ListTile(
          leading: IconBadge(m == 0 ? LucideIcons.circleOff : LucideIcons.flame, size: 36, accent: m == current),
          title: Text(m == 0 ? 'None' : '$m minutes, easy'),
          subtitle: Text(m == 0 ? 'Straight into the first exercise.' : m >= 8 ? 'For cold mornings and stiff days.' : m >= 5 ? 'The usual.' : 'A few moves to get warm.'),
          trailing: m == current ? Icon(LucideIcons.check, color: context.du.accentStrong) : null,
          onTap: () => Navigator.pop(context, m),
        ),
    ]));
    if (v != null) setState(() => warmup = v);
  }

  Future<void> _blockSheet(BuildContext context, String title, bool skipped, void Function(bool) set) async {
    final v = await showSheet<bool>(context, ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 16), children: [
      SheetHeader(title, subtitle: 'Its share comes from your goal. Today only.', icon: title == 'Cardio' ? LucideIcons.footprints : LucideIcons.stretchHorizontal),
      ListTile(leading: const IconBadge(LucideIcons.check, size: 36), title: const Text('Keep it'), trailing: !skipped ? Icon(LucideIcons.check, color: context.du.accentStrong) : null, onTap: () => Navigator.pop(context, false)),
      ListTile(leading: const IconBadge(LucideIcons.circleOff, size: 36), title: const Text('Not today'), subtitle: const Text('The minutes go to the lifting instead, or to spare.'), trailing: skipped ? Icon(LucideIcons.check, color: context.du.accentStrong) : null, onTap: () => Navigator.pop(context, true)),
    ]));
    if (v != null) setState(() => set(v));
  }

  Future<void> _orderSheet(BuildContext context, AppState s) async {
    final store = context.store;
    final v = await showSheet<bool>(context, ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 16), children: [
      const SheetHeader('Order', icon: LucideIcons.repeat),
      ListTile(leading: const IconBadge(LucideIcons.listOrdered, size: 36), title: const Text('One at a time'), subtitle: const Text('Every set of one exercise, then the next.'),
          trailing: !s.settings.circuit ? Icon(LucideIcons.check, color: context.du.accentStrong) : null, onTap: () => Navigator.pop(context, false)),
      ListTile(leading: const IconBadge(LucideIcons.repeat, size: 36), title: const Text('Circuit'), subtitle: const Text('One set of each, round and round, with a rest between rounds.'),
          trailing: s.settings.circuit ? Icon(LucideIcons.check, color: context.du.accentStrong) : null, onTap: () => Navigator.pop(context, true)),
    ]));
    if (v != null) store.update((x) => x.settings.circuit = v);
  }

  Future<void> _exerciseSheet(BuildContext context, Session session, int i) async {
    final store = context.store;
    final s = store.state;
    final e = session.exercises[i];
    final ex = e.exercise;
    final st = ensureState(s, ex);
    final equipmentHere = s.location(session.locationId)?.equipment ?? const <String>[];
    final all = alternatives(s, session, i, equipmentHere, store.now);
    final alts = all.where((a) => preferenceOf(s.ex[a.id], store.now) != prefNo).toList();
    final notForYou = all.where((a) => preferenceOf(s.ex[a.id], store.now) == prefNo).toList();
    final ceiling = ceilingFor(ex, equipmentHere);
    var rung = e.rung;
    var showNotForYou = false;
    await showSheet<void>(context, StatefulBuilder(builder: (context, setSheet) {
      final t = Theme.of(context).textTheme;
      final du = context.du;
      final floor = ex.loaded ? floorRung(s, ex, st) : 0;
      Widget alt(Exercise a) {
        final ast = s.ex[a.id];
        final word = preferenceOf(ast, store.now);
        return ListTile(
          leading: IconBadge(exerciseIcon(a), size: 36),
          title: Text(a.name),
          subtitle: Text('${ast != null ? rungLabel(s, a, ast, ast.rung) : 'not yet practised'} · ${difficultyLabel[difficultyInPlay(a, ast)]}${word != null ? ' · ${preferenceLabel[word]!.toLowerCase()}' : ''}'),
          trailing: Icon(LucideIcons.chevronRight, size: 18, color: du.inkTertiary),
          onTap: () {
            // a manual pick of an unrated exercise counts as liked for a while; a rated one keeps its word
            store.update((x) { final target = ensureState(x, a); if (target.preference == null) target.likedUntil = store.now.add(const Duration(days: softLikeDays)); });
            setState(() {
              picks[e.slot] = a.id;
              rungOverrides.remove(e.slot);
            });
            Navigator.pop(context);
          },
        );
      }
      return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(0, 0, 0, 20), children: [
        SheetHeader(ex.name, subtitle: '${e.muscle} · ${difficultyLabel[e.difficulty]} · ${e.lo} to ${e.hi} ${ex.repLabel} · ${mmss(st.secPerSet)} per set', icon: exerciseIcon(ex)),
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 10), child: Text('Chosen because: ${e.why}.', style: t.bodySmall)),
        if (st.swappedOut >= swapsBeforeAsking)
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 12), child: Panel(sunk: true, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('You keep swapping this one out. Still like it?', style: t.bodyMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final w in [prefLiked, prefFine, prefNo])
                ActionChip(label: Text(preferenceLabel[w]!), onPressed: () { store.update((_) { st.preference = w; st.swappedOut = 0; }); setSheet(() {}); }),
            ]),
          ]))),
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 12), child: Row(children: [
          if (session.exercises.length > 1) ...[
            Expanded(child: OutlinedButton.icon(onPressed: i == 0 ? null : () { _move(session, i, -1); Navigator.pop(context); }, icon: const Icon(LucideIcons.arrowUp, size: 18), label: const Text('Up'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: i == session.exercises.length - 1 ? null : () { _move(session, i, 1); Navigator.pop(context); }, icon: const Icon(LucideIcons.arrowDown, size: 18), label: const Text('Down'))),
            const SizedBox(width: 8),
          ],
          Expanded(child: OutlinedButton.icon(onPressed: () { setState(() => leftOut.add(e.slot)); Navigator.pop(context); }, icon: const Icon(LucideIcons.circleOff, size: 18), label: const Text('Skip'))),
        ])),
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
            if (alts.isNotEmpty || notForYou.isNotEmpty) SectionHeader('Swap for', icon: LucideIcons.replace, trailing: alts.isEmpty ? null : Text('ready first, then liked', style: t.labelSmall)),
          ]),
        ),
        for (final a in alts) alt(a),
        if (notForYou.isNotEmpty) ...[
          ListTile(
            leading: const IconBadge(LucideIcons.thumbsDown, size: 36),
            title: Text('Not for you (${notForYou.length})'),
            subtitle: const Text('Picked only when nothing else here fits. Yours to choose anyway.'),
            trailing: Icon(showNotForYou ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 18, color: du.inkTertiary),
            onTap: () => setSheet(() => showNotForYou = !showNotForYou),
          ),
          if (showNotForYou) for (final a in notForYou) alt(a),
        ],
        const SizedBox(height: 8),
        Center(child: TextButton.icon(onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseCardScreen(ex.id))); }, icon: const Icon(LucideIcons.bookOpen, size: 18), label: const Text('Open the exercise card'))),
      ]);
    }));
  }

  // ---------- the rest of Today

  Widget _hint(BuildContext context, IconData icon, String text) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 13, color: du.accentText)), const SizedBox(width: 6),
      Expanded(child: Text(text, style: t.labelSmall?.copyWith(color: du.accentText))),
    ]));
  }

  Widget _doneForToday(BuildContext context, AppState s, DateTime now) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final store = context.store;
    final last = s.lastSession!;
    final sets = last.exercises.fold(0, (a, x) => a + x.attempted.length);
    final mins = last.elapsedMinutes;
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
          Expanded(child: Text('Your next workout is ready tomorrow, built from where your body is then. Nothing is waiting for you tonight.', style: t.bodyMedium?.copyWith(color: du.inkSecondary))),
        ]),
        const SizedBox(height: 28),
        OutlinedButton.icon(onPressed: () => store.update((x) => x.plan!.continuedOn = now), icon: const Icon(LucideIcons.skipForward, size: 18), label: const Text('Start another anyway')),
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

  void _startMove(BuildContext context, Session session) {
    final store = context.store;
    store.update((s) => startSession(s, session, store.now));
    _reset();
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
    if (id != null) setState(() { locationId = id; picks = {}; rungOverrides = {}; order = []; leftOut = {}; });
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
