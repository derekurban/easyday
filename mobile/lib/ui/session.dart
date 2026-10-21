// During: a strip of the whole workout, the item under way, and one thing to do at a time. A set starts lifting; the
// reps end it and the guide says rest; I'm ready starts the next. Then the time it took, set time and rest, and closure.
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/library.dart';
import '../data/model.dart';
import '../integrations.dart';
import '../logic/after.dart';
import '../logic/builder.dart';
import '../logic/calendar.dart';
import '../logic/ladder.dart';
import '../logic/selection.dart';
import '../logic/workout.dart';
import 'app.dart';
import 'motion.dart';
import 'stage_art.dart';
import 'theme.dart';
import 'widgets.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});
  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  bool finishing = false;     // the feel question is showing
  Finish? pendingFinish;      // stop reason chosen, waiting for feel
  String? note;               // after finishSession: the one line
  List<Exercise>? toRate;     // first-time exercises still to get a word, shown before the log
  int? effort;
  bool editing = false;       // the reps reopened to correct the last set
  Duration _hold = Duration.zero; // how long the next I'm ready waits, so a quick second tap cannot skip what comes
  String _holdCaption = '';
  DateTime? _lockedUntil;     // the strip ignores taps while a step is still settling in
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _resume());
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// A workout started before the strip existed has no item under way: start its first one now.
  void _resume() {
    if (!mounted) return;
    final store = context.store;
    final x = store.state.active;
    if (x != null && x.type == 'lift' && x.exercises.isNotEmpty && x.itemStarts.isEmpty) store.update((_) => ready(x, store.now));
  }

  /// Every second: the clock moves and the rest timer (when it is on) starts the next set.
  void _onTick() {
    if (!mounted) return;
    final store = context.store;
    final x = store.state.active;
    if (x == null || note != null || finishing || x.pausedAt != null) return;
    if (x.type != 'lift') { if (x.kind == 'cardio') setState(() {}); return; } // the cardio stopwatch
    final cur = currentItem(x);
    final now = store.now;
    if (cur != null) {
      if (store.state.settings.restAuto && cur.lifting && !editing) {
        final due = restDue(x, cur);
        if (due != null && !now.isBefore(due)) { store.update((_) => ready(x, due)); return; }
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final session = store.state.active!;
    if (note != null) return (toRate ?? const []).isNotEmpty ? _rate(context) : _done(context, note!);
    if (finishing) return _feel(context, session);
    if (session.type == 'move') return _move(context, session);
    if (session.exercises.isEmpty) return _feel(context, session);
    final paused = session.pausedAt != null;
    final now = session.pausedAt ?? store.now;
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final items = workoutItems(session);
    final cur = currentItem(session) ?? items.first;
    final curIdx = items.indexWhere((x) => x.key == cur.key);
    final elapsed = session.startedAt == null ? 0.0 : now.difference(session.startedAt!).inSeconds.toDouble();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 8,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: paused ? 'Resume' : 'Pause',
            onPressed: () => _pause(context, session, !paused),
            icon: Icon(paused ? LucideIcons.play : LucideIcons.pause, size: 18, color: du.inkSecondary),
          ),
          Text(paused ? '${mmss(elapsed)} paused' : mmss(elapsed), style: t.titleMedium?.copyWith(color: du.inkSecondary, fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
        actions: [
          TextButton.icon(onPressed: () => _stop(context, session), icon: const Icon(LucideIcons.square, size: 14), label: const Text('End')),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 2, 16, 12), child: _strip(context, session, items, curIdx, now)),
        Expanded(child: Stack(children: [
          Positioned.fill(child: IgnorePointer(ignoring: paused, child: AnimatedOpacity(
            duration: m(context, durSlow),
            opacity: paused ? 0.18 : 1,
            child: PageSwitcher(
              index: curIdx,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                children: cur.lifting ? _liftBody(context, session, items, cur, now) : _blockBody(context, session, items, cur, now),
              ),
            ),
          ))),
          if (paused) Positioned.fill(child: _pausedNote(context)),
        ])),
        _dock(context, session, items, cur),
      ]),
    );
  }

  void _pause(BuildContext context, Session x, bool pause) {
    final store = context.store;
    HapticFeedback.lightImpact();
    store.update((_) => pause ? pauseWorkout(x, store.now) : resumeWorkout(x, store.now));
    if (!pause) _lock(const Duration(milliseconds: 600));
    setState(() {});
  }

  Widget _pausedNote(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Center(child: Pop(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(shape: BoxShape.circle, color: du.accentSubtle, border: Border.all(color: du.accentLine, width: 0.6)),
        child: Icon(LucideIcons.pause, size: 32, color: du.accentStrong),
      ),
      const SizedBox(height: 16),
      Text('Paused', style: t.headlineLarge),
      const SizedBox(height: 6),
      Text('The clock, the set and the rest all wait for you.', style: t.bodyMedium?.copyWith(color: du.inkSecondary), textAlign: TextAlign.center),
    ]))));
  }

  void _lock(Duration d) => _lockedUntil = DateTime.now().add(d);
  bool get _locked => _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);

  // ---- the strip ----

  String _short(Session x, WorkoutItem it) => switch (it.kind) {
        ItemKind.warmup => 'Warm-up',
        ItemKind.exercise => _shortName(x.exercises[it.exercises.single].exercise.name),
        ItemKind.circuit => 'Circuit',
        ItemKind.cardio => 'Cardio',
        ItemKind.stretch => 'Stretch',
      };

  String _name(Session x, WorkoutItem it) => switch (it.kind) {
        ItemKind.warmup => 'Warm-up',
        ItemKind.exercise => x.exercises[it.exercises.single].exercise.name,
        ItemKind.circuit => 'Circuit',
        ItemKind.cardio => 'Cardio',
        ItemKind.stretch => 'Stretching',
      };

  /// An exercise's name for the strip: without the equipment word that starts so many of them.
  static String _shortName(String name) {
    const gear = {'barbell', 'dumbbell', 'dumbbells', 'kettlebell', 'cable', 'machine', 'band', 'smith', 'ez-bar', 'ez', 'trap-bar', 'landmine', 'weighted', 'ring', 'rings', 'suspension'};
    final words = name.split(' ');
    var i = 0;
    while (i < words.length - 1 && gear.contains(words[i].toLowerCase())) { i++; }
    final rest = words.sublist(i).join(' ');
    return rest[0].toUpperCase() + rest.substring(1);
  }

  /// The strip: a thin block for every set and every timed part, with gaps between the parts. The part under way stands
  /// taller; resting, the gap after the last set opens a little and holds a dot. No clock: nothing hurries anyone.
  Widget _strip(BuildContext context, Session x, List<WorkoutItem> items, int curIdx, DateTime now) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final view = stripView(x);
    final cur = items[curIdx];
    final label = view.between ? 'Resting' : _nowName(x, cur);
    final upNext = _nextName(x, items, curIdx);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) => _tapStrip(context, x, items, curIdx, view, d.localPosition.dx),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(height: 12, child: LayoutBuilder(builder: (context, c) {
          final geo = _stripGeometry(view, c.maxWidth);
          final bl = view.blocks;
          Color fill(StripBlock b) => switch (b.state) {
                BlockState.done => du.accentLine,
                BlockState.skipped => du.sunk,
                BlockState.now => du.accentStrong,
                BlockState.ahead => du.line,
              };
          return Stack(clipBehavior: Clip.none, children: [
            for (var i = 0; i < bl.length; i++)
              AnimatedPositioned(
                key: ValueKey('b$i'),
                duration: m(context, durSlow), curve: easeOut,
                left: geo.left[i], width: geo.width[i],
                top: bl[i].state == BlockState.now ? 2 : 4, height: bl[i].state == BlockState.now ? 8 : 4,
                child: AnimatedContainer(
                  duration: m(context, durBase),
                  decoration: BoxDecoration(color: fill(bl[i]), borderRadius: BorderRadius.circular(4)),
                ),
              ),
            if (view.between)
              Positioned(left: geo.gapLeft + geo.gapWidth / 2 - 3, top: 3, width: 6, height: 6, child: DecoratedBox(decoration: BoxDecoration(color: du.accentStrong, shape: BoxShape.circle))),
          ]);
        })),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelMedium?.copyWith(letterSpacing: 0, color: du.accentText, fontWeight: FontWeight.w600))),
          if (upNext != null) ...[
            const SizedBox(width: 12),
            Expanded(child: Text('Next: $upNext', textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelMedium?.copyWith(letterSpacing: 0, color: du.inkTertiary))),
          ],
        ]),
      ]),
    );
  }

  /// The exercise under way, or the one being rested from (in a circuit, the one up next), or the timed part.
  String _nowName(Session x, WorkoutItem cur) {
    if (!cur.lifting) return _short(x, cur);
    final r = liftingSet(x, cur) ?? (cur.kind == ItemKind.circuit ? nextSet(x, cur) : null) ?? lastLogged(x, cur) ?? nextSet(x, cur);
    return r == null ? _short(x, cur) : _shortName(x.exercises[r.ex].exercise.name);
  }

  /// What comes next: the exercise of the next set (this one again, or the next in a circuit), else the next part.
  String? _nextName(Session x, List<WorkoutItem> items, int curIdx) {
    final cur = items[curIdx];
    if (cur.lifting) {
      final order = setOrder(x, cur);
      final lift = liftingSet(x, cur);
      final i = lift == null ? -1 : order.indexOf(lift);
      final n = lift == null ? nextSet(x, cur) : (i + 1 < order.length ? order[i + 1] : null);
      if (n != null) {
        return _shortName(x.exercises[n.ex].exercise.name);
      }
    }
    return curIdx + 1 < items.length ? _short(x, items[curIdx + 1]) : null;
  }

  /// Where each block sits: sets of one exercise 2 px apart, different parts 7 px apart, and the gap being rested in
  /// opened to 16 px for its dot.
  static ({List<double> left, List<double> width, double gapLeft, double gapWidth}) _stripGeometry(StripView view, double w) {
    final bl = view.blocks;
    const restGap = 16.0;
    double gapAfter(int i) => view.between && i == view.at ? restGap : bl[i].item == bl[i + 1].item ? 2.0 : 7.0;
    final lead = view.between && view.at < 0 ? restGap : 0.0;
    var gaps = lead;
    for (var i = 0; i < bl.length - 1; i++) { gaps += gapAfter(i); }
    final trail = view.between && view.at == bl.length - 1 ? restGap : 0.0;
    gaps += trail;
    final total = bl.fold(0.0, (a, b) => a + max(1.0, b.weight));
    final unit = max(0.0, w - gaps) / max(1.0, total);
    final left = <double>[], width = <double>[];
    var x = lead;
    var gapLeft = 0.0, gapWidth = restGap;
    for (var i = 0; i < bl.length; i++) {
      left.add(x);
      width.add(max(1.0, bl[i].weight) * unit);
      x += width.last;
      if (view.between && i == view.at) gapLeft = x;
      if (i < bl.length - 1) x += gapAfter(i);
    }
    if (view.between && view.at < 0) { gapLeft = 0; gapWidth = lead; }
    return (left: left, width: width, gapLeft: gapLeft, gapWidth: gapWidth);
  }

  /// A tap on a later part of the strip offers to go there.
  void _tapStrip(BuildContext context, Session x, List<WorkoutItem> items, int curIdx, StripView view, double dx) {
    if (_locked || x.pausedAt != null) return;
    final w = MediaQuery.sizeOf(context).width - 32; // the strip's padding
    final geo = _stripGeometry(view, w);
    for (var i = 0; i < view.blocks.length; i++) {
      if (dx < geo.left[i] + geo.width[i] + 3) {
        final to = items.indexWhere((it) => it.key == view.blocks[i].item);
        if (to > curIdx) _jump(context, x, items, curIdx, to);
        return;
      }
    }
  }

  Future<void> _jump(BuildContext context, Session x, List<WorkoutItem> items, int curIdx, int to) async {
    final passed = [for (var k = curIdx + 1; k < to; k++) _name(x, items[k])];
    final store = context.store;
    final go = await showSheet<bool>(context, ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 16), children: [
      SheetHeader('Go to ${_name(x, items[to]).toLowerCase()}?', subtitle: passed.isEmpty ? 'The rest of this one is left as it is.' : '${passed.join(', ')} ${passed.length == 1 ? 'is' : 'are'} skipped. Nothing skipped is judged.', icon: LucideIcons.skipForward),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
        Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay'))),
        const SizedBox(width: 8),
        Expanded(child: FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Go'))),
      ])),
    ]));
    if (go == true && mounted) {
      store.update((_) => jumpTo(x, items[to].key, store.now));
      setState(() => editing = false);
    }
  }

  // ---- what to do now ----

  List<Widget> _liftBody(BuildContext context, Session x, List<WorkoutItem> items, WorkoutItem cur, DateTime now) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final lift = liftingSet(x, cur);
    if (lift == null) return _restBody(context, x, items, cur);
    final e = x.exercises[lift.ex];
    final circuit = cur.kind == ItemKind.circuit;
    // a version of a bodyweight exercise is its name; a loaded one is the exercise and its weight
    final title = e.exercise.ladder != null ? e.rungLabel : e.exercise.name;
    final weight = _weightOf(e);
    final seconds = e.exercise.repLabel == 'seconds';
    return [
      Text(title, style: t.headlineLarge),
      const SizedBox(height: 8),
      Row(children: [
        Icon(LucideIcons.target, size: 16, color: du.inkSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text('${e.lo} to ${e.hi} ${seconds ? 'seconds' : 'reps'}${e.exercise.perSide ? ' a side' : ''}', style: t.titleMedium)),
        if (weight != null) Text(weight, style: t.titleMedium?.copyWith(color: du.accentText, fontWeight: FontWeight.w600)),
      ]),
      if (circuit) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${cur.exercises.map((i) => x.exercises[i].exercise.name).join(' → ')}, then rest and go again.', style: t.labelSmall)),
      const SizedBox(height: 16),
      StageArt(stage: stageOf(e.exercise.type)),
      const SizedBox(height: 24),
      HowToSteps(howAt(e.exercise, e.rung)),
    ];
  }

  /// A loaded exercise's weight; null for a bodyweight version, whose name says it all.
  String? _weightOf(SessionExercise e) => e.exercise.ladder != null || e.rungLabel == e.exercise.name ? null : e.rungLabel;

  /// Resting: the title says so, the picture is the breath, and under it the recent performance, a row of small
  /// tiles, one for each exercise worked so far, the one just rested from first.
  List<Widget> _restBody(BuildContext context, Session x, List<WorkoutItem> items, WorkoutItem cur) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final now = context.store.now;
    // every exercise with a set in, the most recent first
    DateTime lastAt(SessionExercise e) => e.sets.where((s) => s.attempted && s.at != null).fold(DateTime(0), (a, s) => s.at!.isAfter(a) ? s.at! : a);
    final worked = [for (final e in x.exercises) if (e.attempted.isNotEmpty) e]..sort((a, b) => lastAt(b).compareTo(lastAt(a)));
    return [
      Text('Rest', style: t.headlineLarge),
      const SizedBox(height: 16),
      const StageArt(stage: Stage.rest),
      if (worked.isNotEmpty) ...[
        const SizedBox(height: 24),
        Row(children: [
          Icon(LucideIcons.activity, size: 16, color: du.inkSecondary),
          const SizedBox(width: 8),
          Text('Recent performance', style: t.labelLarge?.copyWith(color: du.inkSecondary)),
        ]),
        const SizedBox(height: 12),
        SizedBox(height: 138, child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: worked.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) => _performanceTile(context, worked[i], now, latest: i == 0),
        )),
      ],
    ];
  }

  /// One exercise's sets so far: its name, the sets done, the reps (or seconds) of each, the weight, and the average
  /// time a set took. The most recent one is outlined in green.
  Widget _performanceTile(BuildContext context, SessionExercise e, DateTime now, {bool latest = false}) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final done = e.sets.where((s) => s.attempted).toList();
    final avg = done.isEmpty ? 0.0 : done.fold(0.0, (a, s) => a + liftSeconds(e, s, now)) / done.length;
    final seconds = e.exercise.repLabel == 'seconds';
    Widget line(IconData icon, String text) => Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [
          Icon(icon, size: 13, color: du.inkTertiary),
          const SizedBox(width: 6),
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelSmall?.copyWith(letterSpacing: 0, color: du.inkSecondary))),
        ]));
    return Container(
      width: 168,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: du.sunk,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: latest ? du.accentStrong : du.line, width: latest ? 1.5 : 0.6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(e.exercise.ladder != null ? e.rungLabel : e.exercise.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelLarge),
      const SizedBox(height: 6),
      Text([for (final s in done) '${s.reps}'].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis,
          style: t.titleLarge?.copyWith(color: du.accentText, fontFeatures: const [FontFeature.tabularFigures()])),
      const Spacer(),
      line(LucideIcons.listChecks, '${done.length} of ${e.sets.length} sets${seconds ? ', seconds' : ''}'),
      line(LucideIcons.dumbbell, _weightOf(e) ?? 'Bodyweight'),
      line(LucideIcons.timer, 'About ${mmss(avg)} a set'),
    ]));
  }

  List<Widget> _blockBody(BuildContext context, Session x, List<WorkoutItem> items, WorkoutItem cur, DateTime now) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final routine = switch (cur.kind) {
      ItemKind.warmup => routines['reset']!,
      ItemKind.stretch => _lowerDay(x) ? routines['hips']! : routines['upper']!,
      _ => null,
    };
    final moves = <Move>[];
    if (routine != null) {
      var used = 0;
      for (final m in routine.moves) {
        if (moves.isNotEmpty && used >= cur.minutes * 60) break;
        moves.add(m);
        used += m.seconds;
      }
    }
    final stage = switch (cur.kind) { ItemKind.warmup => Stage.warmup, ItemKind.cardio => Stage.cardio, _ => Stage.stretching };
    return [
      Text(_name(x, cur), style: t.headlineLarge),
      const SizedBox(height: 8),
      Row(children: [
        Icon(LucideIcons.target, size: 16, color: du.inkSecondary),
        const SizedBox(width: 8),
        Text('About ${cur.minutes} minutes', style: t.titleMedium),
      ]),
      const SizedBox(height: 16),
      StageArt(stage: stage),
      const SizedBox(height: 24),
      if (moves.isNotEmpty)
        Panel(padding: EdgeInsets.zero, child: Column(children: [
          for (var i = 0; i < moves.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(dense: true, leading: Icon(LucideIcons.stretchHorizontal, size: 18, color: du.inkTertiary), title: Text(moves[i].n), subtitle: Text('${moves[i].seconds} seconds')),
          ],
        ])),
      if (cur.kind == ItemKind.cardio)
        Text(cardioFor(x.locationId == null ? const [] : context.store.state.location(x.locationId)?.equipment ?? const []).map((c) => c.name).take(3).join(', '), style: t.bodyMedium?.copyWith(color: du.inkSecondary)),
    ];
  }

  bool _lowerDay(Session x) => x.exercises.any((e) => e.exercise.primary.any((m) => const {'quads', 'glutes', 'hamstrings', 'calves'}.contains(m)));

  // ---- the dock: the reps, or I'm ready ----

  String _readyLabel(Session x, List<WorkoutItem> items, WorkoutItem cur) {
    if (cur.lifting) {
      final n = nextSet(x, cur), last = lastLogged(x, cur);
      if (n != null) {
        if (last == null) return "I'm ready · ${x.exercises[n.ex].exercise.name.toLowerCase()}";
        if (n.ex == last.ex) return "I'm ready · set ${x.exercises[n.ex].attempted.length + 1}";
        if (cur.kind == ItemKind.circuit && n.set > last.set) return "I'm ready · round ${n.set + 1}";
        return "I'm ready · ${x.exercises[n.ex].exercise.name.toLowerCase()}";
      }
    }
    final i = items.indexWhere((it) => it.key == cur.key);
    return i + 1 >= items.length ? 'Finish' : "I'm ready · ${_name(x, items[i + 1]).toLowerCase()}";
  }

  Widget _dock(BuildContext context, Session x, List<WorkoutItem> items, WorkoutItem cur) {
    final du = context.du;
    final paused = x.pausedAt != null;
    final picking = !paused && cur.lifting && (liftingSet(x, cur) != null || (editing && lastLogged(x, cur) != null));
    final Widget child;
    if (paused) {
      child = KeyedSubtree(key: const ValueKey('paused'), child: SizedBox(width: double.infinity, height: 60, child: FilledButton.icon(
        onPressed: () => _pause(context, x, false), icon: const Icon(LucideIcons.play, size: 18), label: const Text('Resume'))));
    } else if (picking) {
      final r = (liftingSet(x, cur) ?? lastLogged(x, cur))!;
      child = KeyedSubtree(key: ValueKey('reps ${r.ex} ${r.set} $editing'), child: _repsWheel(context, x, cur));
    } else if (cur.kind == ItemKind.cardio && x.itemStarts[cur.key] != null) {
      final hold = _hold;
      _hold = Duration.zero;
      child = KeyedSubtree(key: ValueKey('watch ${cur.key}'), child: _stopwatch(context,
        seconds: (x.pausedAt ?? context.store.now).difference(x.itemStarts[cur.key]!).inSeconds,
        label: _readyLabel(x, items, cur),
        hold: hold,
        onDone: (minutes) {
          context.store.update((_) => x.cardioDone = minutes);
          _ready(context, x);
        },
      ));
    } else {
      final last = cur.lifting ? lastLogged(x, cur) : null;
      final hold = _hold;
      _hold = Duration.zero; // spent on this button; a rebuild of the same one does not wait again
      final button = _HoldButton(
        key: ValueKey('ready ${cur.key} ${last?.ex} ${last?.set}'),
        label: _readyLabel(x, items, cur),
        caption: _holdCaption,
        hold: m(context, hold),
        onPressed: () => _ready(context, x),
      );
      child = last == null
          ? button
          : Column(key: ValueKey('ready+fix ${cur.key} ${last.ex} ${last.set}'), mainAxisSize: MainAxisSize.min, children: [
              Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                onPressed: () => setState(() => editing = true),
                icon: const Icon(LucideIcons.pencil, size: 14),
                label: const Text('Fix the last set'),
              )),
              const SizedBox(height: 2),
              button,
            ]);
    }
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 14 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(color: du.bg, border: Border(top: BorderSide(color: du.line, width: 0.6))),
      child: AnimatedSwitcher(
        duration: m(context, durSlow),
        switchInCurve: easeSettle,
        switchOutCurve: easeOut,
        transitionBuilder: (child, a) => FadeTransition(opacity: a, child: SizeTransition(sizeFactor: a, axisAlignment: 1, child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(a), child: child))),
        child: child,
      ),
    );
  }

  /// The reps on a wheel: scroll to the number, then log it. It opens on the last set's reps, or the top of the range.
  Widget _repsWheel(BuildContext context, Session x, WorkoutItem cur) {
    final lift = liftingSet(x, cur);
    final r = (lift ?? lastLogged(x, cur))!;
    final e = x.exercises[r.ex];
    final seconds = e.exercise.repLabel == 'seconds';
    final step = seconds && e.hi - e.lo > 12 ? 5 : 1;
    final top = e.hi + step * max(6, (e.hi - e.lo) ~/ step);
    final values = <int>[for (var v = 0; v <= top; v += step) v];
    final before = lift == null ? setOf(x, r).reps : [for (final s in e.sets) if (s.attempted) s.reps!].lastOrNull;
    final start = before ?? e.hi;
    var initial = 0;
    for (var i = 0; i < values.length; i++) { if ((values[i] - start).abs() < (values[initial] - start).abs()) initial = i; }
    final unit = seconds ? 'seconds' : 'reps';
    return _RepWheel(
      title: lift == null ? 'Fix that set' : seconds ? 'How many seconds did you hold?' : 'How many reps did you get?',
      values: values, initial: initial, lo: e.lo, hi: e.hi, unit: unit,
      action: lift == null ? 'Save' : 'Log',
      onLog: (v) => _logReps(context, x, v),
      onCancel: lift == null ? () => setState(() => editing = false) : null,
    );
  }

  /// Cardio's stopwatch: the time so far counting up, the one clock in a workout that is the work itself, and the
  /// button that ends it, logging the minutes (rounded, at least one). Nothing is judged.
  Widget _stopwatch(BuildContext context, {required int seconds, required String label, Duration hold = Duration.zero, required ValueChanged<int> onDone}) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final s = max(0, seconds);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Cardio time', style: t.labelMedium, textAlign: TextAlign.center),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(LucideIcons.timer, size: 22, color: du.accentText),
        const SizedBox(width: 8),
        Text(mmss(s.toDouble()), style: t.displayLarge?.copyWith(fontSize: 40, color: du.ink, fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
      const SizedBox(height: 10),
      _HoldButton(key: const ValueKey('watch done'), label: label, caption: _holdCaption, hold: m(context, hold), onPressed: () {
        HapticFeedback.mediumImpact();
        onDone(max(1, (s / 60).round()));
      }),
    ]);
  }

  void _logReps(BuildContext context, Session x, int reps) {
    final store = context.store;
    final fixing = editing;
    HapticFeedback.mediumImpact();
    store.update((_) => enterReps(x, reps, store.now));
    setState(() {
      editing = false;
      if (!fixing) { _hold = const Duration(milliseconds: 2400); _holdCaption = 'Take a breather'; }
    });
    _lock(const Duration(milliseconds: 2400));
  }

  void _ready(BuildContext context, Session x) {
    final store = context.store;
    var more = true;
    HapticFeedback.lightImpact();
    store.update((_) => more = ready(x, store.now));
    setState(() {
      editing = false;
      if (!more) finishing = true;
      _hold = const Duration(milliseconds: 1600);
      _holdCaption = 'Get set';
    });
    _lock(const Duration(milliseconds: 1600));
  }

  Widget _splitBar(BuildContext context, double lifting, double rest, {bool key = true}) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final share = context.store.state.settings.timeAsShare;
    final total = lifting + rest;
    String amount(double v) => share ? '${total <= 0 ? 0 : (v / total * 100).round()} %' : mmss(v);
    Widget swatch(Color c) => Container(width: 9, height: 9, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(borderRadius: BorderRadius.circular(3), child: SizedBox(height: 8, child: Row(children: [
        if (lifting >= 1 || rest < 1) Expanded(flex: max(1, (lifting * 10).round()), child: Container(color: du.accentStrong)),
        if (lifting >= 1 && rest >= 1) const SizedBox(width: 2),
        if (rest >= 1) Expanded(flex: max(1, (rest * 10).round()), child: Container(color: du.accentLine)),
      ]))),
      if (key) Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [
        swatch(du.accentStrong), const SizedBox(width: 5), Text('Set time ${amount(lifting)}', style: t.labelSmall?.copyWith(color: du.inkSecondary, letterSpacing: 0)),
        const SizedBox(width: 14),
        swatch(du.accentLine), const SizedBox(width: 5), Text('Rest ${amount(rest)}', style: t.labelSmall?.copyWith(color: du.inkSecondary, letterSpacing: 0)),
      ])),
    ]);
  }

  // ---- ending ----

  Future<void> _stop(BuildContext context, Session session) async {
    final idx = currentExercise(session) ?? 0;
    final reason = await showSheet<StopReason>(context, ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 16), children: [
      const SheetHeader('End the workout?', subtitle: 'What you have done is kept either way.', icon: LucideIcons.square),
      ListTile(leading: const IconBadge(LucideIcons.hand, size: 40), title: const Text('Just stop'), subtitle: const Text('No reason needed. Nothing is judged and nothing changes.'), onTap: () => Navigator.pop(context, StopReason.none)),
      ListTile(leading: const IconBadge(LucideIcons.batteryLow, size: 40), title: const Text('Out of energy'), subtitle: const Text('Levels hold. Tomorrow defaults a little easier.'), onTap: () => Navigator.pop(context, StopReason.energy)),
      ListTile(leading: const IconBadge(LucideIcons.clock, size: 40), title: const Text('Out of time'), subtitle: const Text('Levels hold. The minutes you had become the default.'), onTap: () => Navigator.pop(context, StopReason.time)),
      ListTile(leading: const IconBadge(LucideIcons.bandage, size: 40), title: const Text('Something hurts'), subtitle: const Text('This exercise and similar ones rest for a week.'), onTap: () => Navigator.pop(context, StopReason.pain)),
    ]));
    if (reason == null || !context.mounted) return;
    if (reason == StopReason.none) { _finish(context, session, null, stop: Finish(stopReason: StopReason.none, stopAt: idx)); return; }
    setState(() { pendingFinish = Finish(stopReason: reason, stopAt: idx); finishing = true; });
  }

  Widget _feel(BuildContext context, Session session) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final options = [
      (Feel.easy, LucideIcons.feather, 'Easy', 'Twice in a row and spare minutes add exercises again. A first-time level steps up at once.'),
      (Feel.right, LucideIcons.check, 'About right', 'Nothing changes. The sets are read as they were.'),
      (Feel.tooMuch, LucideIcons.flame, 'Too much', 'Levels are read as they were. Twice in a row and spare minutes go to cardio instead of more exercises.'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('How was it?'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Optional. One tap, or skip.', style: t.bodyMedium?.copyWith(color: du.inkSecondary)),
          const SizedBox(height: 20),
          for (var i = 0; i < options.length; i++)
            Reveal(delay: Duration(milliseconds: 50 * i), child: OptionCard(icon: options[i].$2, title: options[i].$3, blurb: options[i].$4, selected: false, onTap: () => _finish(context, session, options[i].$1), trailing: const SizedBox.shrink())),
          Center(child: TextButton(onPressed: () => _finish(context, session, null), child: const Text('Skip'))),
        ],
      ),
    );
  }

  void _finish(BuildContext context, Session session, Feel? feel, {Finish? stop}) {
    final store = context.store;
    final p = stop ?? pendingFinish;
    final f = Finish(feel: feel, stopReason: p?.stopReason, stopAt: p?.stopAt, effort: effort);
    resumeWorkout(session, store.now); // ended while paused: the pause is not workout time
    finishSession(store.state, session, f, store.now);
    note = session.note;
    toRate = firstTimers(store.state, session);
    store.state.active = session; // keep the screen until Done is tapped
    setState(() {});
    _autoTrack(store.state, session);
  }

  /// Something new today: one row per first-time exercise, a word each, skippable (SELECTION.md).
  Widget _rate(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final store = context.store;
    final list = toRate!;
    return Scaffold(
      appBar: AppBar(title: Text(list.length == 1 ? 'Something new today' : 'New today'), automaticallyImplyLeading: false),
      body: Column(children: [
        Expanded(child: ListView(padding: const EdgeInsets.all(20), children: [
          Text('One tap each, or skip. Liked goes first for its muscle; not for me is picked only when nothing else fits.', style: t.bodyMedium?.copyWith(color: du.inkSecondary)),
          const SizedBox(height: 16),
          for (var i = 0; i < list.length; i++)
            Reveal(delay: Duration(milliseconds: 50 * i), child: Padding(padding: const EdgeInsets.only(bottom: 10), child: Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [IconBadge(exerciseIcon(list[i]), size: 36), const SizedBox(width: 10), Expanded(child: Text(list[i].name, style: t.titleMedium))]),
              const SizedBox(height: 8),
              ChoiceRow<String>(
                value: store.state.ex[list[i].id]?.preference ?? '',
                options: {prefLiked: preferenceLabel[prefLiked]!, prefFine: preferenceLabel[prefFine]!, prefNo: preferenceLabel[prefNo]!},
                icons: const {prefLiked: LucideIcons.heart, prefFine: LucideIcons.check, prefNo: LucideIcons.thumbsDown},
                onChanged: (v) => store.update((x) => ensureState(x, list[i]).preference = v),
              ),
            ])))),
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), child: SizedBox(width: double.infinity, height: 56, child: FilledButton.icon(
          onPressed: () => setState(() => toRate = []), icon: const Icon(LucideIcons.chevronRight, size: 18), label: const Text('Continue')))),
      ]),
    );
  }

  /// With auto-track on, a workout that started is written to the calendar from start to end. Never one that did not.
  Future<void> _autoTrack(AppState s, Session session) async {
    final st = s.settings;
    if (!st.calendar || !st.autoTrack || session.startedAt == null || session.endedAt == null) return;
    final text = workoutEventText(s, session, (e) => e.rungLabel);
    final id = await CalendarBridge.writeEvent(calendarId: st.calendarId, eventId: session.calendarEventId, begin: session.startedAt!.subtract(Duration(seconds: session.pausedSeconds)), end: session.endedAt!, title: text.title, description: text.description);
    if (id != null && mounted) context.store.update((_) => session.calendarEventId = id);
  }

  /// Logged: the one line, the time it took against the plan, and where it went: lifting and rest.
  Widget _done(BuildContext context, String line) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final store = context.store;
    final session = store.state.active!;
    final end = session.endedAt ?? store.now;
    final total = session.startedAt == null ? 0.0 : end.difference(session.startedAt!).inSeconds.toDouble();
    final lift = session.type == 'lift';
    final items = lift ? workoutItems(session).where((it) => session.itemStarts.containsKey(it.key)).toList() : const <WorkoutItem>[];
    final split = workoutSplit(session, end);
    final skipped = [for (final i in session.skipped) if (i < session.exercises.length) session.exercises[i].exercise.name];
    final longest = items.fold(1.0, (a, it) => max(a, itemEnd(session, it, end).difference(session.itemStarts[it.key]!).inSeconds.toDouble()));
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(24, 24, 24, 16), children: [
            Center(child: Pop(child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(shape: BoxShape.circle, color: du.accentSubtle, border: Border.all(color: du.accentLine, width: 0.6)),
              child: Icon(LucideIcons.check, size: 40, color: du.accentStrong),
            ))),
            const SizedBox(height: 16),
            Reveal(delay: const Duration(milliseconds: 120), child: Text('Logged.', style: t.headlineLarge, textAlign: TextAlign.center)),
            const SizedBox(height: 8),
            Reveal(delay: const Duration(milliseconds: 200), child: Text(line, style: t.bodyLarge, textAlign: TextAlign.center)),
            if (total >= 60) ...[
              const SizedBox(height: 20),
              Text(mmss(total), style: t.displayLarge?.copyWith(fontSize: 44), textAlign: TextAlign.center),
              if (lift && session.estMinutes > 0) Text('planned about ${session.estMinutes} min', style: t.bodySmall, textAlign: TextAlign.center),
            ],
            if (items.any((it) => it.lifting)) ...[
              const SizedBox(height: 18),
              Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('On exercises', style: t.labelMedium),
                const SizedBox(height: 8),
                _splitBar(context, split.lifting, split.rest),
              ])),
            ],
            if (items.isNotEmpty) ...[
              const SizedBox(height: 18),
              const SectionHeader('Where the time went', icon: LucideIcons.timer),
              Panel(padding: const EdgeInsets.fromLTRB(16, 6, 16, 6), child: Column(children: [
                for (final it in items) () {
                  final secs = itemEnd(session, it, end).difference(session.itemStarts[it.key]!).inSeconds.toDouble();
                  final sp = it.lifting ? itemSplit(session, it, end) : null;
                  final planned = it.kind == ItemKind.exercise ? plannedSeconds(session.exercises[it.exercises.single]) : null;
                  return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Expanded(child: Text(_name(session, it), style: t.bodyMedium)), Text(mmss(secs), style: t.titleMedium)]),
                    const SizedBox(height: 6),
                    if (sp != null) _splitBar(context, sp.lifting, sp.rest, key: false)
                    else ClipRRect(borderRadius: BorderRadius.circular(3), child: SizedBox(height: 6, child: Row(children: [
                      Expanded(flex: max(1, (secs / longest * 100).round()), child: Container(color: du.accentLine)),
                      Expanded(flex: max(0, 100 - (secs / longest * 100).round()), child: const SizedBox()),
                    ]))),
                    if (sp != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(
                      '${_amounts(store.state, sp.lifting, sp.rest)}${planned != null ? ' · planned ${max(1, (planned / 60).round())} min' : ''}', style: t.labelSmall?.copyWith(letterSpacing: 0))),
                  ]));
                }(),
              ])),
            ],
            if (skipped.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Skipped: ${skipped.join(', ')}. Not judged.', style: t.bodySmall)),
          ])),
          Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 16), child: SizedBox(width: double.infinity, height: 56, child: FilledButton.icon(
            onPressed: () { store.update((s) => s.active = null); }, icon: const Icon(LucideIcons.check, size: 18), label: const Text('Done')))),
        ]),
      ),
    );
  }

  String _amounts(AppState s, double lifting, double rest) {
    final total = lifting + rest;
    String a(double v) => s.settings.timeAsShare ? '${total <= 0 ? 0 : (v / total * 100).round()} %' : mmss(v);
    return 'set time ${a(lifting)} · rest ${a(rest)}';
  }

  Widget _move(BuildContext context, Session session) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final store = context.store;
    final isCardio = session.kind == 'cardio';
    final r = isCardio ? null : routines[session.routine]!;
    return Scaffold(
      appBar: AppBar(title: Text(session.name), actions: [TextButton.icon(onPressed: () => store.update((s) => s.active = null), icon: const Icon(LucideIcons.x, size: 16), label: const Text('Cancel'))]),
      body: Column(children: [
        Expanded(child: ListView(padding: const EdgeInsets.all(20), children: [
          Row(children: [IconBadge(moveIcon(session.kind), accent: true, size: 48), const SizedBox(width: 12), Expanded(child: Text(isCardio ? cardio.firstWhere((c) => c.id == session.cardio, orElse: () => cardio.last).name : r!.name, style: t.headlineLarge))]),
          const SizedBox(height: 8),
          if (isCardio) ...[
            Text('${session.minutes} minutes at a pace you could talk through. Nothing counts down.', style: t.bodyMedium?.copyWith(color: du.inkSecondary)),
            const SizedBox(height: 24),
            const SectionHeader('How hard did it feel', icon: LucideIcons.gauge),
            ChoiceRow<int>(value: effort ?? 2, options: const {1: 'Light', 2: 'Steady', 3: 'Hard'}, icons: const {1: LucideIcons.feather, 2: LucideIcons.activity, 3: LucideIcons.flame}, onChanged: (v) => setState(() => effort = v)),
          ] else ...[
            Text('About ${(r!.seconds / 60).ceil()} minutes, each move for its own time. Breathe.', style: t.bodyMedium?.copyWith(color: du.inkSecondary)),
            const SizedBox(height: 12),
            for (var i = 0; i < r.moves.length; i++)
              ListTile(contentPadding: EdgeInsets.zero, leading: const IconBadge(LucideIcons.stretchHorizontal, size: 36), title: Text(r.moves[i].n), subtitle: Text('${r.moves[i].seconds} seconds. ${r.moves[i].how}')),
          ],
        ])),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(color: du.bg, border: Border(top: BorderSide(color: du.line, width: 0.6))),
          child: isCardio
              ? _stopwatch(context, seconds: session.startedAt == null ? 0 : store.now.difference(session.startedAt!).inSeconds, label: 'Done', onDone: (minutes) {
                  store.update((_) => session.cardioDone = minutes);
                  _finish(context, session, null);
                })
              : SizedBox(width: double.infinity, height: 56, child: FilledButton.icon(onPressed: () => _finish(context, session, null), icon: const Icon(LucideIcons.check, size: 20), label: const Text('Done'))),
        ),
      ]),
    );
  }
}

/// A button that arrives before it can be pressed: for [hold] it shows [caption] while it fills, then turns into
/// [label]. A quick second tap after the last step lands on nothing instead of skipping what comes next.
class _HoldButton extends StatefulWidget {
  const _HoldButton({super.key, required this.label, required this.caption, required this.hold, required this.onPressed});
  final String label;
  final String caption;
  final Duration hold;
  final VoidCallback onPressed;
  @override
  State<_HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<_HoldButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.hold > Duration.zero ? widget.hold : const Duration(milliseconds: 1));
    if (widget.hold > Duration.zero) {
      _c.forward().whenComplete(() { if (mounted) setState(() {}); });
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final ready = _c.isCompleted;
    return SizedBox(width: double.infinity, height: 60, child: AnimatedSwitcher(
      duration: m(context, durSlow),
      switchInCurve: easeSettle,
      switchOutCurve: easeOut,
      transitionBuilder: (child, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(a), child: child)),
      child: ready
          ? SizedBox.expand(key: const ValueKey('go'), child: FilledButton(onPressed: widget.onPressed, child: Text(widget.label, overflow: TextOverflow.ellipsis)))
          : ClipRRect(
              key: const ValueKey('hold'),
              borderRadius: BorderRadius.circular(12),
              child: Stack(fit: StackFit.expand, children: [
                ColoredBox(color: du.sunk),
                AnimatedBuilder(animation: _c, builder: (context, _) => Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(
                  widthFactor: Curves.easeInOut.transform(_c.value), heightFactor: 1, child: ColoredBox(color: du.accentSubtle)))),
                Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.wind, size: 18, color: du.accentText),
                  const SizedBox(width: 8),
                  Text(widget.caption, style: t.labelLarge?.copyWith(color: du.accentText)),
                ])),
              ]),
            ),
    ));
  }
}

/// The reps on a sideways wheel: the target range in ink, the rest faint, the one in the window large. Log arrives a
/// moment after the wheel does, so the tap that started the set cannot end it.
class _RepWheel extends StatefulWidget {
  const _RepWheel({required this.title, required this.values, required this.initial, required this.lo, required this.hi, required this.unit, required this.action, required this.onLog, this.onCancel});
  final String title;
  final List<int> values;
  final int initial;
  final int lo, hi;
  final String unit;
  final String action;
  final ValueChanged<int> onLog;
  final VoidCallback? onCancel;
  @override
  State<_RepWheel> createState() => _RepWheelState();
}

class _RepWheelState extends State<_RepWheel> {
  static const _extent = 58.0;
  late final FixedExtentScrollController _ctl = FixedExtentScrollController(initialItem: widget.initial);
  late int _sel = widget.initial;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final v = widget.values[_sel];
    final word = v != 1 ? widget.unit : const {'reps': 'rep', 'seconds': 'second', 'minutes': 'minute'}[widget.unit] ?? widget.unit;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(widget.title, style: t.labelMedium, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      SizedBox(height: 72, child: Stack(alignment: Alignment.center, children: [
        Container(width: _extent, height: 72, decoration: BoxDecoration(
          color: du.accentSubtle, borderRadius: BorderRadius.circular(14), border: Border.all(color: du.accentLine, width: 1))),
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(colors: [Color(0x00000000), Color(0xFF000000), Color(0xFF000000), Color(0x00000000)], stops: [0, 0.22, 0.78, 1]).createShader(r),
          blendMode: BlendMode.dstIn,
          child: RotatedBox(quarterTurns: 3, child: ListWheelScrollView.useDelegate(
            controller: _ctl,
            itemExtent: _extent,
            diameterRatio: 2.4,
            perspective: 0.004,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (i) { HapticFeedback.selectionClick(); setState(() => _sel = i); },
            childDelegate: ListWheelChildBuilderDelegate(childCount: widget.values.length, builder: (context, i) {
              final n = widget.values[i];
              final inRange = n >= widget.lo && n <= widget.hi;
              final on = i == _sel;
              return RotatedBox(quarterTurns: 1, child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _ctl.animateToItem(i, duration: m(context, durSlow), curve: easeOut),
                child: Center(child: AnimatedDefaultTextStyle(
                  duration: m(context, durFast),
                  style: (on ? t.headlineLarge : t.titleLarge)!.copyWith(
                    color: on ? du.accentText : inRange ? du.ink : du.inkTertiary,
                    fontFeatures: const [FontFeature.tabularFigures()]),
                  child: Text('$n'),
                )),
              ));
            }),
          )),
        ),
      ])),
      const SizedBox(height: 12),
      Row(children: [
        if (widget.onCancel != null) ...[
          Expanded(child: SizedBox(height: 60, child: OutlinedButton(onPressed: widget.onCancel, child: const Text('Keep it')))),
          const SizedBox(width: 8),
        ],
        Expanded(flex: 2, child: _HoldButton(
          key: ValueKey('log ${widget.action}'),
          label: '${widget.action} $v $word',
          caption: widget.action == 'Log' ? 'Lift first' : 'Pick the number',
          hold: m(context, const Duration(milliseconds: 900)),
          onPressed: () => widget.onLog(v),
        )),
      ]),
    ]);
  }
}
