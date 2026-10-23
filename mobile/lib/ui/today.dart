// Today: the workout, ready to start (UI.md). The day's name from the muscles it works ("Back and biceps day"), one
// line of numbers, the body figure painted with today's muscles (tap it for the muscle picker), then the plan: the
// warm-up, each exercise with its level and sets, cardio and stretching, and the strip as the workout will show it.
// Tap a row to swap it, change today's level, move it or leave it out. Energy and time sit at the bottom, already
// answered, with one button: Start workout. When today's workout is done, closure.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'motion.dart';
import 'muscle_figure.dart';
import 'muscle_picker.dart';
import 'stage_art.dart';
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
  MusclePlan? musclePlan;
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

  /// Today's muscle plan: the user's, else the defaults from the strain of the moment.
  MusclePlan _musclePlan(AppState s, DateTime now) => musclePlan ?? MusclePlan(states: defaultMuscleStates(MuscleMap(s).currentStrainPoints(now), s.goal), order: trackedMuscles);

  /// Everything the builder needs, from today's answers, the muscle plan and the plan's edits. [asBuilt] leaves the
  /// edits out: the workout as the builder first made it.
  BuildOptions _options(AppState s, DateTime now, {MusclePlan? plan, bool asBuilt = false}) {
    final defaults = defaultsFor(s, now, busyShare: day?.busyShare);
    final g = s.goal!;
    final limit = s.settings.timeLimit;
    final n = (count ?? g.exercises.ideal).clamp(g.exercises.min, g.exercises.max);
    final loc = s.location(locationId ?? nearbyId);
    final p = plan ?? _musclePlan(s, now);
    // manual with no time limit: exactly the forced muscles, one exercise each
    final manualCount = max(1, min(p.forced.length, g.exercises.max));
    return BuildOptions(
      energy: energy ?? defaults.energy, minutes: minutes ?? defaults.minutes, locationId: loc?.id, moveKind: moveKind, routine: routine, cardio: cardioId,
      energyChosen: energy != null && energy != defaults.energy, timeChosen: minutes != null && minutes != defaults.minutes, circuit: s.settings.circuit,
      exerciseCount: limit ? null : p.manual ? manualCount : n, warmupMinutes: warmup ?? s.settings.warmup, skipCardio: skipCardio, skipStretch: skipStretch,
      muscles: p.forced, excluded: p.excluded, muscleSeed: p.muscleDraw, exerciseSeed: p.exerciseDraw, manual: p.manual, liftInstead: liftInstead, requirements: p.requirements,
      picks: asBuilt ? const {} : picks, rungOverrides: asBuilt ? const {} : rungOverrides, order: asBuilt ? const [] : order, leftOut: asBuilt ? const {} : leftOut,
    );
  }

  void _reset() => setState(() {
        moveKind = null; energy = null; minutes = null; count = null; liftInstead = false;
        musclePlan = null; picks = {}; rungOverrides = {}; order = []; leftOut = {}; warmup = null; skipCardio = false; skipStretch = false;
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
    final plan = _musclePlan(s, now);
    final empty = lift && session.exercises.isEmpty;

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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            Reveal(
              key: ValueKey(fingerprint),
              offset: 8,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // the day's name, its numbers, and the one line for the moment
                Text(empty ? 'Nothing to work' : session.name, style: t.headlineLarge, maxLines: 3, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                if (lift)
                  FactLine(
                    empty ? 'Choose muscles, or move instead' : '${session.exercises.length} exercise${session.exercises.length == 1 ? '' : 's'} · $setCount sets · about $est min',
                    icon: LucideIcons.dumbbell, trailing: empty ? null : _usualShort(session),
                  )
                else
                  FactLine(session.kind == 'cardio' ? 'About ${session.minutes} minutes' : 'About ${session.estMinutes} minutes', icon: LucideIcons.timer,
                      trailing: session.kind == 'cardio' ? 'easy pace' : null),
                if (nudge != null && dismissedNudge != nudge) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: QuietLine(nudge, icon: LucideIcons.sunrise, accent: true)),
                    IconButton(
                      onPressed: () { store.update((x) => x.person.nudgeDismissed = true); setState(() => dismissedNudge = nudge); },
                      icon: const Icon(LucideIcons.x, size: 16), tooltip: 'Dismiss', visualDensity: VisualDensity.compact,
                    ),
                  ]),
                ],
                const SizedBox(height: 16),
                // the picture: the body with today's muscles, or the kind of movement
                if (lift) _figureCard(context, s, now, session, plan) else StageArt(stage: session.kind == 'cardio' ? Stage.cardio : Stage.stretching),
                const SizedBox(height: 20),
                if (lift) ...[
                  SectionHeader('Plan', icon: LucideIcons.listChecks, trailing: Tooltip(message: 'Shuffle', child: TextButton.icon(
                    onPressed: session.exercises.isEmpty ? null : () => _shuffleSheet(context, plan),
                    icon: const Icon(LucideIcons.dices, size: 16), label: const Text('Shuffle'),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ))),
                  if (session.uncovered.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(bottom: 10), child: QuietLine('Not covered today: ${listWords(session.uncovered)}. More time, another exercise or other equipment would.', icon: LucideIcons.circleAlert, accent: true)),
                  if (empty)
                    Panel(padding: EdgeInsets.zero, child: Row1(
                      icon: LucideIcons.circleOff,
                      title: const Text('Nothing fits today'),
                      subtitle: plan.manual
                          ? 'Manual: only forced muscles are worked, and none is forced.'
                          : plan.excluded.length == trackedMuscles.length
                              ? 'Every muscle is excluded.'
                              : 'Nothing here works the muscles available. Try other equipment, other muscles, or move instead.',
                      onTap: () => _pickMuscles(context),
                    ))
                  else
                    _plan(context, s, session, est),
                ] else
                  _moveBody(context, session),
              ]),
            ),
            const SizedBox(height: 12),
            if (s.settings.calendar && limit) _calendarLine(context, mins),
            const SizedBox(height: 4),
            Center(child: lift
                ? TextButton.icon(onPressed: () => _moveSheet(context, loc), icon: const Icon(LucideIcons.footprints, size: 18), label: const Text('Walk or stretch instead'))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    TextButton.icon(onPressed: () => setState(() { moveKind = null; liftInstead = true; }), icon: const Icon(LucideIcons.dumbbell, size: 18), label: const Text('Lift instead')),
                    const SizedBox(width: 8),
                    TextButton.icon(onPressed: () => _moveSheet(context, loc), icon: Icon(moveIcon(session.kind), size: 18), label: const Text('Another')),
                  ])),
            const SizedBox(height: 8),
            Center(child: Text(_stateLine(ps), style: t.bodySmall?.copyWith(color: du.inkTertiary), textAlign: TextAlign.center)),
          ],
        )),
        _dock(context, s, session, e: e, mins: mins, n: n, limit: limit, defaults: defaults, est: est),
      ]),
    );
  }

  /// The two questions and the one button.
  Widget _dock(BuildContext context, AppState s, Session session, {required Energy e, required int mins, required int n, required bool limit, required ({Energy energy, int minutes, String? busy}) defaults, required int est}) {
    final store = context.store;
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final g = s.goal!;
    final lift = session.type == 'lift';
    final cardio = !lift && session.kind == 'cardio';
    final busyHint = limit && defaults.busy != null && (minutes == null || (defaults.busy == 'easy' && energy == null));
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(color: du.bg, border: Border(top: BorderSide(color: du.line, width: 0.6))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (lift) ...[
          Row(children: [
            SizedBox(width: 60, child: Text('Energy', style: t.labelMedium)),
            Expanded(child: Segmented<Energy>(value: e, options: {for (final v in Energy.values) v: energyLabel[v]!}, icons: {for (final v in Energy.values) v: energyIcon(v)}, onChanged: (v) { HapticFeedback.selectionClick(); setState(() => energy = v); })),
          ]),
          const SizedBox(height: 4),
        ],
        if (lift || cardio)
          SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9), overlayShape: const RoundSliderOverlayShape(overlayRadius: 18)),
            child: Row(children: [
              SizedBox(width: 60, child: Text('Time', style: t.labelMedium)),
              Expanded(child: limit || !lift
                  ? Slider(
                      key: const ValueKey('minutes'),
                      value: mins.toDouble(), min: minutesMin.toDouble(), max: minutesMax.toDouble(), divisions: (minutesMax - minutesMin) ~/ minutesStep,
                      label: '$mins min', semanticFormatterCallback: (v) => '${v.round()} minutes',
                      onChanged: (v) => setState(() => minutes = clampMinutes(v.round())),
                    )
                  : Slider(
                      key: const ValueKey('count'),
                      value: n.toDouble(), min: g.exercises.min.toDouble(), max: g.exercises.max.toDouble(),
                      divisions: g.exercises.max > g.exercises.min ? g.exercises.max - g.exercises.min : null,
                      label: '$n', semanticFormatterCallback: (v) => '${v.round()} exercises',
                      onChanged: g.exercises.max > g.exercises.min ? (v) => setState(() => count = v.round()) : null,
                    )),
              // the readout names the measure and, on a lift day, switches it: the minutes, or how many exercises
              lift
                  ? Tooltip(message: limit ? 'Pick how many exercises instead' : 'Fit to the minutes instead', child: Pressable(
                      borderRadius: 8,
                      onTap: () { HapticFeedback.selectionClick(); store.update((x) => x.settings.timeLimit = !limit); },
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6), child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(limit ? '$mins min' : '$n exercise${n == 1 ? '' : 's'}', style: t.titleMedium?.copyWith(color: du.accentText)),
                        const SizedBox(width: 3),
                        Icon(LucideIcons.chevronsUpDown, size: 14, color: du.accentText),
                      ])),
                    ))
                  : Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('$mins min', style: t.titleMedium?.copyWith(color: du.accentText))),
            ]),
          ),
        if (busyHint) Padding(padding: const EdgeInsets.only(bottom: 6), child: QuietLine('Calendar ${day!.busyPct} % full today, so ${defaults.busy == 'easy' ? 'easy and ' : ''}$busyDayMinutes minutes by default.', icon: LucideIcons.calendarDays, accent: true)),
        if (lift && !limit) Padding(padding: const EdgeInsets.only(bottom: 6), child: QuietLine('About $est min for $n exercises.', icon: LucideIcons.timer)),
        const SizedBox(height: 6),
        SizedBox(height: 56, child: FilledButton.icon(
          onPressed: lift && session.exercises.isEmpty ? null : () => lift ? _start(context, session) : _startMove(context, session),
          icon: const Icon(LucideIcons.play, size: 20),
          label: Text(lift ? 'Start workout' : 'Start ${session.name.toLowerCase()}', overflow: TextOverflow.ellipsis),
        )),
      ]),
    );
  }

  // ---------- the muscles

  /// The picture slot: the body figure painted like the picker (forced primary, chosen secondary, excluded dark), and
  /// under it what today works. Tap to open the picker.
  Widget _figureCard(BuildContext context, AppState s, DateTime now, Session session, MusclePlan plan) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final working = workedInOrder(session.exercises);
    final tint = muscleFills(plan.states, chosen: workedMuscles(session), primary: musclePrimary);
    final forced = plan.forced;
    String lower(Iterable<String> xs) => listWords(xs.map((g) => g.toLowerCase()));
    final caption = working.isEmpty
        ? (plan.manual ? 'Nothing forced' : 'Nothing to work')
        : 'Working ${lower(working)}${forced.isNotEmpty ? ' · ${lower(forced)} forced' : ''}';
    return Tooltip(message: 'Muscles', child: Material(color: Colors.transparent, child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _pickMuscles(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(color: du.sunk, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(height: stageArtHeight, child: Center(child: MuscleFigure(highlight: const {}, tint: tint, height: stageArtHeight, interactive: false))),
          const SizedBox(height: stageCaptionGap),
          Row(children: [
            Expanded(child: Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelLarge?.copyWith(color: du.inkSecondary))),
            const SizedBox(width: 12),
            Text(musclePlan == null ? 'Change' : 'Changed today', style: t.bodySmall?.copyWith(color: du.accentText)),
          ]),
        ]),
      ),
    )));
  }

  Future<void> _pickMuscles(BuildContext context) async {
    final store = context.store;
    final r = await Navigator.of(context).push<MusclePlan>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => MusclePickerScreen(
        plan: _musclePlan(store.state, store.now),
        preview: (p) => buildSession(store.state, _options(store.state, store.now, plan: p), store.now),
        drawMuscles: (p) => nextMuscleSeed(store.state, _options(store.state, store.now, plan: p), store.now),
      ),
    ));
    if (r == null || !mounted) return;
    setState(() { musclePlan = r; });
  }

  /// Shuffle (SELECTION.md): the exercises (the same muscles, the cover drawn again), the muscles (a different
  /// combination of what is due), Back to the draw before, or Reset to the plan's own pick.
  Future<void> _shuffleSheet(BuildContext context, MusclePlan plan) async {
    final store = context.store;
    final s = store.state;
    final now = store.now;
    final choice = await showSheet<String>(context, ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 16), children: [
      const SheetHeader('Shuffle', subtitle: 'A draw stays until you start or draw again. Forced muscles and your swaps hold.', icon: LucideIcons.shuffle),
      if (plan.lastDraw != null && (!plan.manual || plan.lastDraw == 'exercises'))
        ListTile(leading: const IconBadge(LucideIcons.repeat, size: 36), title: const Text('Draw again'), subtitle: Text('Shuffle ${plan.lastDraw} again.'), onTap: () => Navigator.pop(context, plan.lastDraw)),
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
      case 'exercises':
        final opts = _options(s, now, plan: p);
        final keep = buildSession(s, opts, now).requirements;
        p.draw(exercises: nextExerciseSeed(s, opts, now), keep: keep);
      case 'muscles': p.draw(muscles: nextMuscleSeed(s, _options(s, now, plan: p), now));
      case 'back': p.back();
      case 'reset': p.resetDraws();
    }
    HapticFeedback.selectionClick();
    final unchanged = p.muscleSeed == plan.muscleSeed && p.exerciseSeed == plan.exerciseSeed;
    setState(() { musclePlan = p; });
    if (unchanged && (choice == 'muscles' || choice == 'exercises')) {
      ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('No different draw fits these choices. Try swapping an exercise.')));
    }
  }

  // ---------- the plan

  Widget _plan(BuildContext context, AppState s, Session session, int est) {
    final store = context.store;
    final g = s.goal!;
    final items = workoutItems(session);
    final circuit = s.settings.circuit && session.exercises.length > 1;
    // the strip as the workout will show it: a block per set and per timed part
    final blocks = <({String item, bool set})>[
      for (final it in items)
        if (it.lifting) for (final _ in setOrder(session, it)) (item: it.key, set: true)
        else (item: it.key, set: false),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Panel(padding: EdgeInsets.zero, clip: true, child: Column(children: [
        Row1(icon: LucideIcons.flame, title: const Text('Warm-up'), subtitle: session.warmupMinutes == 0 ? 'None today' : null, value: session.warmupMinutes == 0 ? null : '${session.warmupMinutes} min', onTap: () => _warmupSheet(context, s)),
        const Divider(height: 1),
        for (var i = 0; i < session.exercises.length; i++) ...[
          _exerciseRow(context, session, i),
          const Divider(height: 1),
        ],
        if (g.cardioPct > 0 || session.cardioMinutes > 0) ...[
          Row1(icon: LucideIcons.footprints, title: const Text('Cardio'), subtitle: skipCardio ? 'Not today' : null, value: skipCardio ? null : '${session.cardioMinutes} min', onTap: () => _blockSheet(context, 'Cardio', skipCardio, (v) => skipCardio = v)),
          const Divider(height: 1),
        ],
        if (g.stretchPct > 0 || session.stretchMinutes > 0) ...[
          Row1(icon: LucideIcons.stretchHorizontal, title: const Text('Stretching'), subtitle: skipStretch ? 'Not today' : null, value: skipStretch ? null : '${session.stretchMinutes} min', onTap: () => _blockSheet(context, 'Stretching', skipStretch, (v) => skipStretch = v)),
          const Divider(height: 1),
        ],
        if (session.exercises.length > 1)
          Row1(icon: circuit ? LucideIcons.repeat : LucideIcons.listOrdered, title: Text(circuit ? 'Circuit' : 'One at a time'), onTap: () => _orderSheet(context, s)),
      ])),
      const SizedBox(height: 12),
      PlanStrip(blocks),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: Fact('About $est min · done around ${hhmm(store.now.add(Duration(minutes: est)))}', icon: LucideIcons.timer)),
        if (session.spareMinutes > 0) Fact('${session.spareMinutes} min to spare', icon: LucideIcons.wind),
      ]),
    ]);
  }

  void _start(BuildContext context, Session session) {
    final store = context.store;
    HapticFeedback.lightImpact();
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

  /// A plan row: the exercise, its level and sets, and a tag only when today differs from the usual.
  Widget _exerciseRow(BuildContext context, Session session, int i) {
    final e = session.exercises[i];
    final unit = e.exercise.repLabel == 'seconds' ? ' s' : '';
    final level = e.exercise.loaded ? e.rungLabel : e.rungLabel == e.exercise.name ? null : e.rungLabel;
    final sets = '${e.sets.length} × ${e.atCeiling ? 'beat ${e.bestTotal} total' : '${e.lo} to ${e.hi}$unit'}';
    final tag = e.nextLevel ? 'next level' : e.intent == intentLight ? (e.exercise.loaded ? '${(easyShare * 100).round()} %' : 'a version down') : e.lightened ? 'eased' : e.edited ? 'edited' : null;
    final word = context.store.state.ex[e.exId]?.preference == prefNo ? 'not for you' : e.fresh ? 'new' : e.asked ? 'forced' : null;
    return Row1(
      icon: exerciseIcon(e.exercise),
      title: Text(e.exercise.name, overflow: TextOverflow.ellipsis),
      tags: [if (tag != null) Tag(tag, accent: e.nextLevel), if (word != null) Tag(word, accent: word == 'new' || word == 'forced')],
      subtitle: level == null ? sets : '$level · $sets',
      value: '${max(1, (plannedSeconds(e) / 60).round())} min',
      onTap: () => _exerciseSheet(context, session, i),
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
          title: Text(m == 0 ? 'None' : '$m minutes'),
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
      ListTile(leading: const IconBadge(LucideIcons.circleOff, size: 36), title: const Text('Not today'), subtitle: const Text('The minutes go to the strength exercises instead.'), trailing: skipped ? Icon(LucideIcons.check, color: context.du.accentStrong) : null, onTap: () => Navigator.pop(context, true)),
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

  /// The exercise sheet: the exercise and its facts, why it is here, Up, Down and Skip, the level as the progression
  /// (tap a level for today, a link to make it yours), the swaps in recommended order, then the how-to at that level.
  Future<void> _exerciseSheet(BuildContext context, Session session, int i) async {
    final store = context.store;
    final s = store.state;
    final e = session.exercises[i];
    final ex = e.exercise;
    final st = ensureState(s, ex);
    final equipmentHere = s.location(session.locationId)?.equipment ?? const <String>[];
    final all = alternativesFor(s, session, i, equipmentHere, store.now, avoid: _musclePlan(s, store.now).excluded);
    final alts = all.where((a) => preferenceOf(s.ex[a.exercise.id], store.now) != prefNo).toList();
    final notForYou = all.where((a) => preferenceOf(s.ex[a.exercise.id], store.now) == prefNo).toList();
    var rung = e.rung;
    var showNotForYou = false;
    void choose(Exercise a) {
      store.update((x) { final target = ensureState(x, a); if (target.preference == null) target.likedUntil = store.now.add(const Duration(days: softLikeDays)); });
      setState(() {
        musclePlan = _musclePlan(s, store.now)..requirements = [...session.requirements];
        picks[e.slot] = a.id;
        rungOverrides.remove(e.slot);
      });
      Navigator.pop(context);
    }
    final unit = ex.repLabel == 'seconds' ? ' s' : '';
    await showSheet<void>(context, StatefulBuilder(builder: (context, setSheet) {
      final t = Theme.of(context).textTheme;
      final du = context.du;
      // a loaded level is a weight in its home reps, one plate step a level; a day with other reps shows its own weight too
      final home = ex.loaded ? homeRange(s, ex) : e.range;
      final ladder = ladderView(s, ex, equipmentHere);
      Widget alt(Alternative x) {
        final a = x.exercise;
        final ast = s.ex[a.id];
        return Row1(
          icon: exerciseIcon(a),
          title: Text(a.name),
          subtitle: '${ast != null ? rungLabel(s, a, ast, ast.rung) : 'not yet practised'} · ${difficultyLabel[difficultyInPlay(a, ast)]}${x.reason.isNotEmpty ? ' · ${x.reason}' : ''}',
          onTap: () => choose(a),
        );
      }
      return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(0, 0, 0, 20), children: [
        SheetHeader(ex.name, subtitle: '${e.exercise.loaded ? '${e.rungLabel} · ' : ''}${e.sets.length} × ${e.lo} to ${e.hi}$unit · about ${mmss(st.secPerSet)} a set', icon: exerciseIcon(ex)),
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 14), child: QuietLine(muscleTitle(e.why), icon: LucideIcons.info)),
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: Row(children: [
          if (session.exercises.length > 1) ...[
            Expanded(child: OutlinedButton.icon(onPressed: i == 0 ? null : () { _move(session, i, -1); Navigator.pop(context); }, icon: const Icon(LucideIcons.arrowUp, size: 18), label: const Text('Up'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: i == session.exercises.length - 1 ? null : () { _move(session, i, 1); Navigator.pop(context); }, icon: const Icon(LucideIcons.arrowDown, size: 18), label: const Text('Down'))),
            const SizedBox(width: 8),
          ],
          Expanded(child: OutlinedButton.icon(onPressed: () { setState(() => leftOut.add(e.slot)); Navigator.pop(context); }, icon: const Icon(LucideIcons.circleOff, size: 18), label: const Text('Skip'))),
        ])),
        if (st.swappedOut >= swapsBeforeAsking)
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), child: Panel(sunk: true, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('You keep swapping this one out. Still like it?', style: t.bodyMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final w in [prefLiked, prefFine, prefNo])
                ActionChip(label: Text(preferenceLabel[w]!), onPressed: () { store.update((_) { st.preference = w; st.swappedOut = 0; }); setSheet(() {}); }),
            ]),
          ]))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Subhead('Level today', icon: LucideIcons.circleDot),
            const SizedBox(height: 8),
            Panel(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
              child: LadderTrack(
                rungs: ladder, marked: rung,
                onUse: (r) { rung = r; setSheet(() {}); setState(() { if (r == e.rung) { rungOverrides.remove(e.slot); } else { rungOverrides[e.slot] = r; } }); },
              ),
            ),
            if (home != e.range) Padding(padding: const EdgeInsets.only(top: 8), child: QuietLine('${rungLabel(s, ex, st, rung, e.range)} today, for ${rangeText(e.range)} reps.', icon: LucideIcons.scale)),
            AnimatedSize(
              duration: m(context, durBase), curve: easeOut, alignment: Alignment.topLeft,
              child: rung == st.rung
                  ? const SizedBox(width: double.infinity)
                  : Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                      onPressed: () { HapticFeedback.lightImpact(); store.update((x) => setRung(x, ex, rung)); setState(() => rungOverrides.remove(e.slot)); setSheet(() {}); },
                      icon: const Icon(LucideIcons.save, size: 16), label: Text('Make ${rungLabel(s, ex, st, rung, home)} my level'),
                    )),
            ),
            const SizedBox(height: 16),
            if (alts.isNotEmpty || notForYou.isNotEmpty) Row(children: [
              const Expanded(child: Subhead('Swap for', icon: LucideIcons.replace)),
              if (alts.isNotEmpty) Text('recommended order', style: t.labelSmall?.copyWith(color: du.inkTertiary)),
            ]),
            const SizedBox(height: 4),
          ]),
        ),
        for (final a in alts) alt(a),
        if (notForYou.isNotEmpty) ...[
          Row1(
            icon: LucideIcons.thumbsDown,
            title: Text('Not for you (${notForYou.length})'),
            subtitle: 'Picked only when nothing else here fits.',
            trailing: Icon(showNotForYou ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 18, color: du.inkTertiary),
            chevron: false,
            onTap: () => setSheet(() => showNotForYou = !showNotForYou),
          ),
          if (showNotForYou) for (final a in notForYou) alt(a),
        ],
        Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), child: AnimatedSwitcher(duration: m(context, durBase), child: HowToSteps(howAt(ex, rung), key: ValueKey('how$rung')))),
        Center(child: TextButton.icon(onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseCardScreen(ex.id))); }, icon: const Icon(LucideIcons.bookOpen, size: 18), label: const Text('Open the exercise card'))),
      ]);
    }));
  }

  // ---------- the rest of Today

  Widget _doneForToday(BuildContext context, AppState s, DateTime now) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final store = context.store;
    final last = s.lastSession!;
    final sets = last.exercises.fold(0, (a, x) => a + x.attempted.length);
    final mins = last.elapsedMinutes;
    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
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
        Reveal(delay: const Duration(milliseconds: 260), child: Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(last.type == 'lift' ? LucideIcons.dumbbell : moveIcon(last.kind), size: 18, color: du.inkSecondary),
            const SizedBox(width: 10),
            Expanded(child: Text(last.name, style: t.titleMedium)),
          ]),
          const SizedBox(height: 8),
          Facts([
            if (last.type == 'lift') Fact('$sets sets', icon: LucideIcons.repeat),
            if (mins != null && mins >= 1 && mins <= 240) Fact('$mins min', icon: LucideIcons.timer),
            Fact(energyLabel[last.energy]!.toLowerCase(), icon: energyIcon(last.energy)),
          ]),
        ]))),
        const SizedBox(height: 16),
        const QuietLine('Your next workout is ready tomorrow, built from where your body is then.', icon: LucideIcons.sunrise),
        const SizedBox(height: 24),
        SizedBox(height: 56, child: OutlinedButton.icon(onPressed: () => store.update((x) => x.plan!.continuedOn = now), icon: const Icon(LucideIcons.skipForward, size: 18), label: const Text('Start another anyway'))),
        const SizedBox(height: 8),
        TextButton.icon(onPressed: () { store.update((x) => x.plan!.continuedOn = now); setState(() => moveKind = 'cardio'); }, icon: const Icon(LucideIcons.footprints, size: 18), label: const Text('Add a walk or a stretch')),
      ]),
    );
  }

  /// Today against the usual, short: "your usual", "60 % of usual", "next level".
  String _usualShort(Session session) {
    final r = session.relative;
    if (r > 1.05) return 'next level';
    if (r < 0.95) return '${(r * 20).round() * 5} % of usual';
    return 'your usual';
  }

  String _stateLine(PersonView ps) {
    if (ps.last == null) return 'Your first workout. It starts easy and corrects fast.';
    return ps.daysSince == 0 ? 'Trained today' : '${ps.daysSince} day${ps.daysSince == 1 ? '' : 's'} since the last workout';
  }

  /// A movement day: the cardio's how-to, or the routine's moves in an accordion.
  Widget _moveBody(BuildContext context, Session session) {
    if (session.kind == 'cardio') {
      final c = cardio.firstWhere((x) => x.id == session.cardio, orElse: () => cardio.last);
      final how = exerciseById[c.id]?.how ?? '';
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeader(c.name, icon: LucideIcons.footprints),
        if (how.isNotEmpty) HowToSteps(how, header: null) else const QuietLine('Anything that raises the pulse, at a pace you can talk at.'),
      ]);
    }
    final r = routines[session.routine]!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader('${r.moves.length} moves', icon: LucideIcons.stretchHorizontal),
      MoveList(routineRows(r), icon: LucideIcons.stretchHorizontal),
    ]);
  }

  void _startMove(BuildContext context, Session session) {
    final store = context.store;
    HapticFeedback.lightImpact();
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
      Expanded(child: QuietLine(text, icon: LucideIcons.clock)),
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
      const SheetHeader('Walk or stretch', subtitle: 'Cardio takes the minutes you set. A stretching routine takes what it takes.', icon: LucideIcons.footprints),
      const Padding(padding: EdgeInsets.fromLTRB(20, 4, 20, 0), child: Subhead('Cardio', icon: LucideIcons.footprints)),
      for (final c in options) ListTile(leading: const IconBadge(LucideIcons.footprints, size: 36), title: Text(c.name), subtitle: Text(cardioNeeds(c)), onTap: () => Navigator.pop(context, ('cardio', c.id))),
      const Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 0), child: Subhead('Stretching', icon: LucideIcons.stretchHorizontal)),
      for (final x in routines.values) ListTile(leading: const IconBadge(LucideIcons.stretchHorizontal, size: 36), title: Text(x.name), subtitle: Text('${x.moves.length} moves · about ${(x.seconds / 60).ceil()} min'), onTap: () => Navigator.pop(context, ('mobility', x.id))),
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
