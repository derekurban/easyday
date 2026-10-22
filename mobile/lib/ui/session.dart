// During: a strip of the whole workout, the item under way, and one thing to do at a time. A set starts lifting; the
// reps end it and it is rest; Start set 2 (or the next exercise) starts the next. Then the time it took, set time and rest, and closure.
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
  int? _view;                 // a block of the strip being looked at, back or ahead; null follows the step under way
  bool _viewForward = true;   // which way the last move went, so the body swipes the right way
  Duration _hold = Duration.zero; // how long the next button waits, so a quick second tap cannot skip what comes
  String? _heldStep;          // the set whose Log has already waited once: coming back to it, it does not wait again
  String _holdCaption = '';
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
    if (x.type != 'lift') { setState(() {}); return; } // the clock, and cardio's stopwatch
    final cur = currentItem(x);
    final now = store.now;
    if (cur != null) {
      if (store.state.settings.restAuto && cur.lifting) {
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
    final items = workoutItems(session);
    final cur = currentItem(session) ?? items.first;
    final curIdx = items.indexWhere((x) => x.key == cur.key);
    final elapsed = session.startedAt == null ? 0.0 : now.difference(session.startedAt!).inSeconds.toDouble();
    final view = stripView(session);
    final places = _places(view);
    final live = places.indexOf(-1);
    if (_view != null && !places.contains(_view)) _view = null;
    final at = _view == null ? live : places.indexOf(_view!);

    return Scaffold(
      appBar: _bar(context, session, paused: paused, elapsed: elapsed, endTip: 'End workout', onEnd: () => _stop(context, session)),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 2, 16, 16), child: _strip(context, session, items, curIdx, now, view, places)),
        // swipe the body to look back at what is done or ahead at what is coming
        Expanded(child: GestureDetector(
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v.abs() > 250) _browse(places, at, v < 0 ? 1 : -1);
          },
          child: StepSwiper(
            step: _view == null ? _step(session, cur) : 'view $_view',
            forward: _viewForward,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              children: _view != null
                  ? _viewBody(context, session, items, view.blocks[_view!], now)
                  : cur.lifting ? _liftBody(context, session, items, cur, now) : _blockBody(context, session, items, cur, now),
            ),
          ),
        )),
        _dock(context, session, items, cur, view, places, at, live),
      ]),
    );
  }

  /// The places to look at, in order: every block of the strip, with the step under way standing in for its block
  /// (resting, it sits between the set just done and the next). -1 marks the step under way.
  static List<int> _places(StripView v) {
    final out = <int>[];
    if (v.between && v.at < 0) out.add(-1);
    for (var i = 0; i < v.blocks.length; i++) {
      if (!v.between && i == v.at) { out.add(-1); continue; }
      out.add(i);
      if (v.between && i == v.at) out.add(-1);
    }
    return out;
  }

  /// Look one place back or ahead; reaching the step under way follows it again.
  void _browse(List<int> places, int at, int by) {
    final to = (at + by).clamp(0, places.length - 1);
    if (to == at) return;
    HapticFeedback.selectionClick();
    setState(() {
      _viewForward = by > 0;
      _view = places[to] == -1 ? null : places[to];
    });
  }

  void _backToNow(List<int> places) {
    if (_view == null) return;
    setState(() {
      _viewForward = places.indexOf(_view!) < places.indexOf(-1);
      _view = null;
    });
  }

  /// Which step the body shows, so moving on swipes: lifting a set, resting after one, or a timed part.
  static String _step(Session x, WorkoutItem cur) {
    if (!cur.lifting) return cur.key;
    final lift = liftingSet(x, cur);
    if (lift != null) return 'lift ${lift.ex} ${lift.set}';
    final last = lastLogged(x, cur);
    return 'rest ${cur.key} ${last?.ex} ${last?.set}';
  }

  void _pause(BuildContext context, Session x, bool pause) {
    final store = context.store;
    HapticFeedback.lightImpact();
    store.update((_) => pause ? pauseWorkout(x, store.now) : resumeWorkout(x, store.now));
    setState(() {});
  }


  /// The app bar of a workout under way: the clock and its pause button are one target, tap anywhere on them; and an
  /// X at the end.
  PreferredSizeWidget _bar(BuildContext context, Session x, {required bool paused, required double elapsed, required String endTip, required VoidCallback onEnd}) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 6,
      title: Tooltip(message: paused ? 'Resume' : 'Pause', child: Material(color: Colors.transparent, child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _pause(context, x, !paused),
        child: Padding(padding: const EdgeInsets.fromLTRB(10, 8, 14, 8), child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(paused ? LucideIcons.play : LucideIcons.pause, size: 18, color: du.inkSecondary),
          const SizedBox(width: 10),
          Text(paused ? '${mmss(elapsed)} paused' : mmss(elapsed), style: t.titleMedium?.copyWith(color: du.inkSecondary, fontFeatures: const [FontFeature.tabularFigures()])),
        ])),
      ))),
      actions: [
        IconButton(tooltip: endTip, onPressed: onEnd, icon: Icon(LucideIcons.x, size: 22, color: du.inkSecondary)),
        const SizedBox(width: 4),
      ],
    );
  }

  /// The dock's box: the band along the bottom that holds the one control.
  Widget _dockBox(BuildContext context, Widget child) {
    final du = context.du;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 14 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(color: du.bg, border: Border(top: BorderSide(color: du.line, width: 0.6))),
      child: child,
    );
  }

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
  Widget _strip(BuildContext context, Session x, List<WorkoutItem> items, int curIdx, DateTime now, StripView view, List<int> places) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final cur = items[curIdx];
    final label = _view != null ? _viewLabel(x, items, view.blocks[_view!]) : view.between ? 'Resting' : _nowName(x, cur);
    final upNext = _nextName(x, items, curIdx);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) => _tapStrip(context, view, places, d.localPosition.dx),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(height: 14, child: LayoutBuilder(builder: (context, c) {
          final geo = _stripGeometry(view, c.maxWidth);
          final bl = view.blocks;
          // done is a clear green short of the one under way; skipped is hollow, a ring with nothing in it
          final done = Color.lerp(du.accentLine, du.accentStrong, 0.5)!;
          BoxDecoration deco(StripBlock b, double r) => switch (b.state) {
                BlockState.done => BoxDecoration(color: done, borderRadius: BorderRadius.circular(r)),
                BlockState.skipped => BoxDecoration(border: Border.all(color: du.line, width: 1), borderRadius: BorderRadius.circular(r)),
                BlockState.now => BoxDecoration(color: du.accentStrong, borderRadius: BorderRadius.circular(r)),
                BlockState.ahead => BoxDecoration(color: du.line, borderRadius: BorderRadius.circular(r)),
              };
          // a block is 8 tall; the one under way 14; the one looked at keeps its own fill, 8 tall, inside a gap and a
          // bright outline that together come to the same 14
          return Stack(clipBehavior: Clip.none, children: [
            for (var i = 0; i < bl.length; i++)
              () {
                final tall = bl[i].state == BlockState.now || i == _view;
                final looked = i == _view;
                return AnimatedPositioned(
                  key: ValueKey('b$i'),
                  duration: m(context, durSlow), curve: easeOut,
                  left: geo.left[i], width: geo.width[i],
                  top: tall ? 0 : 3, height: tall ? 14 : 8,
                  child: AnimatedContainer(
                    duration: m(context, durBase),
                    padding: looked ? const EdgeInsets.all(1.5) : EdgeInsets.zero,
                    decoration: looked
                        ? BoxDecoration(borderRadius: BorderRadius.circular(7), border: Border.all(color: du.accentStrong, width: 1.5))
                        : deco(bl[i], 7),
                    child: looked ? DecoratedBox(decoration: deco(bl[i], 4)) : null,
                  ),
                );
              }(),
            if (view.between)
              Positioned(left: geo.gapLeft + geo.gapWidth / 2 - 3.5, top: 3.5, width: 7, height: 7, child: DecoratedBox(decoration: BoxDecoration(color: du.accentStrong, shape: BoxShape.circle))),
          ]);
        })),
        const SizedBox(height: stageCaptionGap),
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

  /// The block being looked at, by name, and whether it is done, skipped or still to come.
  String _viewLabel(Session x, List<WorkoutItem> items, StripBlock b) {
    final name = b.set != null ? _shortName(x.exercises[b.set!.ex].exercise.name) : _short(x, items.firstWhere((it) => it.key == b.item));
    final word = switch (b.state) { BlockState.done => 'done', BlockState.skipped => 'skipped', BlockState.ahead => 'coming up', BlockState.now => 'now' };
    return '$name · $word';
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

  /// Where each block sits: every block the same width, sets of one exercise 2 px apart, different parts 7 px apart,
  /// and the gap being rested in opened to 16 px for its dot.
  static ({List<double> left, List<double> width, double gapLeft, double gapWidth}) _stripGeometry(StripView view, double w) {
    final bl = view.blocks;
    const restGap = 16.0;
    double gapAfter(int i) => view.between && i == view.at ? restGap : bl[i].item == bl[i + 1].item ? 2.0 : 7.0;
    final lead = view.between && view.at < 0 ? restGap : 0.0;
    var gaps = lead;
    for (var i = 0; i < bl.length - 1; i++) { gaps += gapAfter(i); }
    final trail = view.between && view.at == bl.length - 1 ? restGap : 0.0;
    gaps += trail;
    final unit = max(0.0, w - gaps) / max(1, bl.length);
    final left = <double>[], width = <double>[];
    var x = lead;
    var gapLeft = 0.0, gapWidth = restGap;
    for (var i = 0; i < bl.length; i++) {
      left.add(x);
      width.add(unit);
      x += width.last;
      if (view.between && i == view.at) gapLeft = x;
      if (i < bl.length - 1) x += gapAfter(i);
    }
    if (view.between && view.at < 0) { gapLeft = 0; gapWidth = lead; }
    return (left: left, width: width, gapLeft: gapLeft, gapWidth: gapWidth);
  }

  /// A tap on a block of the strip looks at it; on the step under way it comes back to it.
  void _tapStrip(BuildContext context, StripView view, List<int> places, double dx) {
    final w = MediaQuery.sizeOf(context).width - 32; // the strip's padding
    final geo = _stripGeometry(view, w);
    for (var i = 0; i < view.blocks.length; i++) {
      if (dx < geo.left[i] + geo.width[i] + 3) {
        final target = places.indexOf(i);
        if (target < 0) { _backToNow(places); return; }
        final from = _view == null ? places.indexOf(-1) : places.indexOf(_view!);
        if (target == from) return;
        HapticFeedback.selectionClick();
        setState(() { _viewForward = target > from; _view = i; });
        return;
      }
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

  /// A step looked at, back or ahead: a set as its exercise with what happened to it (the reps when done), or a
  /// timed part as it is shown under way, with done or coming up.
  List<Widget> _viewBody(BuildContext context, Session x, List<WorkoutItem> items, StripBlock b, DateTime now) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    // under the title only the step's status: what was done, or skipped, or coming up; not the target or the minutes
    Widget status(IconData icon, String text, {bool good = false}) => Row(children: [
          Icon(icon, size: 16, color: good ? du.accentText : du.inkSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: t.titleMedium?.copyWith(color: good ? du.accentText : du.inkSecondary))),
        ]);
    final otherwise = b.state == BlockState.skipped ? status(LucideIcons.skipForward, 'Skipped') : status(LucideIcons.clock, 'Coming up');
    if (b.set == null) {
      final item = items.firstWhere((it) => it.key == b.item);
      final body = _blockBody(context, x, items, item, now);
      return [...body.take(2), b.state == BlockState.done ? status(LucideIcons.check, 'Done', good: true) : otherwise, ...body.skip(3)];
    }
    final r = b.set!;
    final e = x.exercises[r.ex];
    final log = setOf(x, r);
    final title = e.exercise.ladder != null ? e.rungLabel : e.exercise.name;
    final weight = _weightOf(e);
    final seconds = e.exercise.repLabel == 'seconds';
    final which = 'Set ${r.set + 1} of ${e.sets.length}';
    return [
      Text(title, style: t.headlineLarge),
      const SizedBox(height: 8),
      if (b.state == BlockState.done)
        Row(children: [
          Icon(LucideIcons.check, size: 16, color: du.accentText),
          const SizedBox(width: 8),
          Expanded(child: Text('$which · ${log.reps} ${seconds ? 'seconds' : log.reps == 1 ? 'rep' : 'reps'}', style: t.titleMedium?.copyWith(color: du.accentText))),
          if (weight != null) Text(weight, style: t.titleMedium?.copyWith(color: du.accentText, fontWeight: FontWeight.w600)),
        ])
      else if (b.state == BlockState.ahead && weight != null)
        // still to come: the weight to load on the right, as it will be shown under way
        Row(children: [
          Expanded(child: otherwise),
          Text(weight, style: t.titleMedium?.copyWith(color: du.accentText, fontWeight: FontWeight.w600)),
        ])
      else
        otherwise,
      const SizedBox(height: 16),
      StageArt(stage: stageOf(e.exercise.type)),
      const SizedBox(height: 24),
      HowToSteps(howAt(e.exercise, e.rung)),
    ];
  }

  /// A loaded exercise's weight; null for a bodyweight version, whose name says it all.
  String? _weightOf(SessionExercise e) => e.exercise.ladder != null || e.rungLabel == e.exercise.name ? null : e.rungLabel;

  /// Resting: the title says so, the picture is the breath, and under it the recent performance, a list of tiles,
  /// one for each exercise worked so far, the one just rested from first.
  List<Widget> _restBody(BuildContext context, Session x, List<WorkoutItem> items, WorkoutItem cur) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final now = context.store.now;
    // every exercise with a set in, the most recent first
    DateTime lastAt(SessionExercise e) => e.sets.where((s) => s.attempted && s.at != null).fold(DateTime(0), (a, s) => s.at!.isAfter(a) ? s.at! : a);
    final worked = [for (final e in x.exercises) if (e.attempted.isNotEmpty) e]..sort((a, b) => lastAt(b).compareTo(lastAt(a)));
    return [
      Text('Rest', style: t.headlineLarge),
      const SizedBox(height: 8),
      // one calm line in the slot the target row has while lifting, so the picture stays put between the two
      Text('Take a breath', style: t.titleMedium?.copyWith(color: du.inkSecondary)),
      const SizedBox(height: 16),
      const StageArt(stage: Stage.rest),
      if (worked.isNotEmpty) ...[
        const SizedBox(height: 24),
        const Subhead('Recent performance', icon: LucideIcons.activity),
        const SizedBox(height: 12),
        for (var i = 0; i < worked.length; i++)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: _performanceTile(context, worked[i], now, latest: i == 0)),
      ],
    ];
  }

  /// One exercise's sets so far: its name, the sets done, the reps (or seconds) of each, the weight, and the average
  /// time a set took. The most recent one has a green bar down its left edge.
  Widget _performanceTile(BuildContext context, SessionExercise e, DateTime now, {bool latest = false}) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final done = e.sets.where((s) => s.attempted).toList();
    final avg = done.isEmpty ? 0.0 : done.fold(0.0, (a, s) => a + liftSeconds(e, s, now)) / done.length;
    final seconds = e.exercise.repLabel == 'seconds';
    Widget fact(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: du.inkTertiary),
          const SizedBox(width: 5),
          Text(text, style: t.labelSmall?.copyWith(letterSpacing: 0, color: du.inkSecondary)),
        ]);
    final content = Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Expanded(child: Text(e.exercise.ladder != null ? e.rungLabel : e.exercise.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelLarge)),
          const SizedBox(width: 12),
          Text([for (final s in done) '${s.reps}'].join(' · '),
              style: t.titleMedium?.copyWith(color: du.accentText, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 14, runSpacing: 4, children: [
          fact(LucideIcons.listChecks, '${done.length} of ${e.sets.length} sets${seconds ? ', seconds' : ''}'),
          fact(LucideIcons.dumbbell, _weightOf(e) ?? 'Bodyweight'),
          fact(LucideIcons.timer, 'About ${mmss(avg)} a set'),
        ]),
      ]));
    // the most recent: a green bar down its left edge, inside the rounded corners
    return Panel(
      padding: EdgeInsets.zero,
      clip: true,
      child: SizedBox(width: double.infinity, child: latest ? Stack(children: [content, Positioned(left: 0, top: 0, bottom: 0, width: 4, child: ColoredBox(color: du.accentStrong))]) : content),
    );
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
        Icon(LucideIcons.timer, size: 16, color: du.inkSecondary),
        const SizedBox(width: 8),
        Text('About ${cur.minutes} minutes', style: t.titleMedium),
      ]),
      const SizedBox(height: 16),
      StageArt(stage: stage),
      const SizedBox(height: 24),
      if (moves.isNotEmpty)
        _MoveList([for (final mv in moves) (name: mv.n, detail: '${mv.seconds} seconds', how: mv.how)], icon: LucideIcons.stretchHorizontal, key: ValueKey('moves ${cur.key}')),
      // cardio: what this place offers, each opening to how to do it at a pace you can talk at
      if (cur.kind == ItemKind.cardio)
        _MoveList([
          for (final c in cardioFor(x.locationId == null ? const [] : context.store.state.location(x.locationId)?.equipment ?? const []))
            (name: c.name, detail: _needs(c), how: exerciseById[c.id]?.how ?? ''),
        ], icon: LucideIcons.heartPulse, key: ValueKey('cardio ${cur.key}')),
    ];
  }

  /// What a cardio option needs, in words: "No equipment", or "Needs a rower".
  static String _needs(Cardio c) {
    if (c.needs == null) return 'No equipment';
    final thing = (equipment[c.needs] ?? c.needs!).toLowerCase();
    return 'Needs ${'aeiou'.contains(thing[0]) ? 'an' : 'a'} $thing';
  }

  bool _lowerDay(Session x) => x.exercises.any((e) => e.exercise.primary.any((m) => const {'quads', 'glutes', 'hamstrings', 'calves'}.contains(m)));

  // ---- the dock: the reps, or the button to what comes next ----

  /// Every button that arrives after a step waits this long before it can be pressed.
  static const _wait = Duration(seconds: 3);

  /// The button to what comes next, named for what it does: Start set 2, Start bench press, Start round 2, Start
  /// cardio, or Finish workout when nothing is left.
  String _readyLabel(Session x, List<WorkoutItem> items, WorkoutItem cur) {
    String start(String what) => 'Start ${what[0].toLowerCase()}${what.substring(1)}';
    if (cur.lifting) {
      final n = nextSet(x, cur), last = lastLogged(x, cur);
      if (n != null) {
        if (last != null && n.ex == last.ex) return 'Start set ${x.exercises[n.ex].attempted.length + 1}';
        if (last != null && cur.kind == ItemKind.circuit && n.set > last.set) return 'Start round ${n.set + 1}';
        return start(_shortName(x.exercises[n.ex].exercise.name));
      }
    }
    final i = items.indexWhere((it) => it.key == cur.key);
    if (i + 1 >= items.length) return 'Finish workout';
    final next = items[i + 1];
    return start(next.kind == ItemKind.exercise ? _shortName(x.exercises[next.exercises.single].exercise.name) : _name(x, next));
  }

  Widget _dock(BuildContext context, Session x, List<WorkoutItem> items, WorkoutItem cur, StripView view, List<int> places, int at, int live) {
    final du = context.du;
    final paused = x.pausedAt != null;
    final Widget child;
    if (_view != null) {
      // looking back or ahead: a done set can be changed; anything else is only looked at
      final b = view.blocks[_view!];
      void back() => _backToNow(places);
      if (b.set != null && setOf(x, b.set!).attempted) {
        child = KeyedSubtree(key: ValueKey('change $_view'), child: _fixWheel(context, x, b.set!, back));
      } else {
        child = KeyedSubtree(key: ValueKey('look $_view'), child: SizedBox(width: double.infinity, height: 56,
            child: OutlinedButton.icon(onPressed: back, icon: const Icon(LucideIcons.undo2, size: 18), label: const Text('Return'))));
      }
    } else if (cur.lifting && liftingSet(x, cur) != null) {
      final r = liftingSet(x, cur)!;
      // Log waits once, as the set arrives, and not while paused
      final step = 'reps ${r.ex} ${r.set}';
      final hold = !paused && _heldStep != step ? _wait : Duration.zero;
      _heldStep = step;
      child = KeyedSubtree(key: ValueKey(step), child: _repsWheel(context, x, cur, enabled: !paused, hold: hold));
    } else if (cur.kind == ItemKind.cardio && x.itemStarts[cur.key] != null) {
      final hold = _hold;
      _hold = Duration.zero;
      child = KeyedSubtree(key: ValueKey('watch ${cur.key}'), child: _stopwatch(context,
        seconds: (x.pausedAt ?? context.store.now).difference(x.itemStarts[cur.key]!).inSeconds,
        label: _readyLabel(x, items, cur),
        hold: hold,
        enabled: !paused,
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
        label: paused ? 'Paused' : _readyLabel(x, items, cur),
        caption: _holdCaption,
        hold: m(context, hold),
        onPressed: paused ? null : () => _ready(context, x),
      );
      final lastBlock = last == null ? -1 : view.blocks.indexWhere((bl) => bl.set == last);
      child = lastBlock < 0
          ? KeyedSubtree(key: ValueKey('ready ${cur.key}'), child: button)
          : Column(key: ValueKey('ready+fix ${cur.key} ${last!.ex} ${last.set}'), mainAxisSize: MainAxisSize.min, children: [
              Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: du.inkSecondary),
                onPressed: () { HapticFeedback.selectionClick(); setState(() { _viewForward = false; _view = lastBlock; }); },
                icon: const Icon(LucideIcons.pencil, size: 14),
                label: const Text('Fix the last set'),
              )),
              const SizedBox(height: 2),
              button,
            ]);
    }
    // the height glides from one control to the next while the old fades into the new
    return _dockBox(context, AnimatedSize(
        duration: m(context, durSlow),
        curve: Curves.easeInOutCubic,
        alignment: Alignment.bottomCenter,
        child: AnimatedSwitcher(
          duration: m(context, durBase),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          layoutBuilder: (current, previous) => Stack(alignment: Alignment.bottomCenter, children: [
            for (final p in previous) Positioned(left: 0, right: 0, bottom: 0, child: p),
            ?current,
          ]),
          transitionBuilder: (child, a) => FadeTransition(opacity: a, child: child),
          child: child,
        ),
      ));
  }

  /// The numbers a wheel offers for an exercise: every rep, or every five seconds for a long hold.
  static List<int> _wheelValues(SessionExercise e) {
    final seconds = e.exercise.repLabel == 'seconds';
    final step = seconds && e.hi - e.lo > 12 ? 5 : 1;
    final top = e.hi + step * max(6, (e.hi - e.lo) ~/ step);
    return [for (var v = 0; v <= top; v += step) v];
  }

  static int _nearest(List<int> values, int to) {
    var best = 0;
    for (var i = 0; i < values.length; i++) { if ((values[i] - to).abs() < (values[best] - to).abs()) best = i; }
    return best;
  }

  /// The reps on a wheel: scroll to the number, then log it. It opens on the last set's reps, or the top of the range.
  Widget _repsWheel(BuildContext context, Session x, WorkoutItem cur, {bool enabled = true, Duration hold = Duration.zero}) {
    final r = liftingSet(x, cur)!;
    final e = x.exercises[r.ex];
    final seconds = e.exercise.repLabel == 'seconds';
    final values = _wheelValues(e);
    final before = [for (final s in e.sets) if (s.attempted) s.reps!].lastOrNull;
    return _RepWheel(
      title: seconds ? 'How many seconds did you hold?' : 'How many reps did you get?',
      values: values, initial: _nearest(values, before ?? e.hi), lo: e.lo, hi: e.hi, unit: seconds ? 'seconds' : 'reps',
      action: 'Log',
      enabled: enabled,
      hold: hold,
      onLog: (v) => _logReps(context, x, v),
    );
  }

  /// A done set on the wheel: every turn saves the new number at once; Return goes back to the step under way.
  Widget _fixWheel(BuildContext context, Session x, SetRef r, VoidCallback back) {
    final e = x.exercises[r.ex];
    final seconds = e.exercise.repLabel == 'seconds';
    final values = _wheelValues(e);
    return _RepWheel(
      title: seconds ? 'Update the previous hold time' : 'Update the previous rep count',
      values: values, initial: _nearest(values, setOf(x, r).reps ?? e.hi), lo: e.lo, hi: e.hi, unit: seconds ? 'seconds' : 'reps',
      action: 'Save',
      cancelLabel: 'Return',
      cancelIcon: LucideIcons.undo2,
      onCancel: back,
      onChanged: (v) {
        context.store.update((_) => fixSet(x, r, v));
        setState(() {});
      },
    );
  }

  /// Cardio's stopwatch: the time so far counting up, the one clock in a workout that is the work itself, and the
  /// button that ends it, logging the minutes (rounded, at least one). Nothing is judged.
  Widget _stopwatch(BuildContext context, {required int seconds, required String label, Duration hold = Duration.zero, bool enabled = true, required ValueChanged<int> onDone}) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final s = max(0, seconds);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Cardio time', style: t.labelMedium, textAlign: TextAlign.center),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(LucideIcons.timer, size: 22, color: du.accentText),
        const SizedBox(width: 8),
        Text(mmss(s.toDouble()), style: t.headlineLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
      const SizedBox(height: 10),
      _HoldButton(key: const ValueKey('watch done'), label: enabled ? label : 'Paused', caption: _holdCaption, hold: m(context, hold), onPressed: !enabled ? null : () {
        HapticFeedback.mediumImpact();
        onDone(max(1, (s / 60).round()));
      }),
    ]);
  }

  void _logReps(BuildContext context, Session x, int reps) {
    final store = context.store;
    HapticFeedback.mediumImpact();
    store.update((_) => enterReps(x, reps, store.now));
    setState(() {
      _viewForward = true;
      _hold = _wait;
      _holdCaption = 'Catch your breath';
    });
  }

  void _ready(BuildContext context, Session x) {
    final store = context.store;
    var more = true;
    HapticFeedback.lightImpact();
    store.update((_) => more = ready(x, store.now));
    setState(() {
      _viewForward = true;
      if (!more) finishing = true;
      _hold = _wait;
      _holdCaption = 'Settle in';
    });
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
          onPressed: () => setState(() => toRate = []), iconAlignment: IconAlignment.end, icon: const Icon(LucideIcons.chevronRight, size: 18), label: const Text('Continue')))),
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
              const Subhead('On exercises', icon: LucideIcons.activity),
              const SizedBox(height: 10),
              Panel(child: _splitBar(context, split.lifting, split.rest)),
            ],
            if (items.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Subhead('Where the time went', icon: LucideIcons.timer),
              const SizedBox(height: 10),
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

  /// A cardio or stretching day on its own: the same screen as a lift's timed part. The clock and its pause button,
  /// an X that leaves without logging, the title with about how long, the stage picture, then the cardio's how-to with
  /// a word on how hard it felt, or the moves in an accordion. The dock is the stopwatch, or Done.
  Widget _move(BuildContext context, Session session) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final store = context.store;
    final isCardio = session.kind == 'cardio';
    final r = isCardio ? null : routines[session.routine]!;
    final c = isCardio ? cardio.firstWhere((c) => c.id == session.cardio, orElse: () => cardio.last) : null;
    final paused = session.pausedAt != null;
    final now = session.pausedAt ?? store.now;
    final elapsed = session.startedAt == null ? 0.0 : now.difference(session.startedAt!).inSeconds.toDouble();
    final minutes = isCardio ? session.minutes ?? 0 : (r!.seconds / 60).ceil();
    final how = isCardio ? exerciseById[c!.id]?.how ?? '' : '';
    return Scaffold(
      appBar: _bar(context, session, paused: paused, elapsed: elapsed, endTip: 'Leave without logging', onEnd: () => store.update((s) => s.active = null)),
      body: Column(children: [
        Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 20), children: [
          Text(isCardio ? c!.name : r!.name, style: t.headlineLarge),
          const SizedBox(height: 8),
          Row(children: [
            Icon(LucideIcons.timer, size: 16, color: du.inkSecondary),
            const SizedBox(width: 8),
            Text('About $minutes minutes', style: t.titleMedium),
          ]),
          const SizedBox(height: 16),
          StageArt(stage: isCardio ? Stage.cardio : Stage.stretching),
          const SizedBox(height: 24),
          if (isCardio) ...[
            const Subhead('How hard did it feel', icon: LucideIcons.gauge),
            ChoiceRow<int>(value: effort ?? 2, options: const {1: 'Light', 2: 'Steady', 3: 'Hard'}, icons: const {1: LucideIcons.feather, 2: LucideIcons.activity, 3: LucideIcons.flame}, onChanged: (v) => setState(() => effort = v)),
            if (how.isNotEmpty) ...[const SizedBox(height: 16), HowToSteps(how)],
          ] else
            _MoveList([for (final mv in r!.moves) (name: mv.n, detail: '${mv.seconds} seconds', how: mv.how)], icon: LucideIcons.stretchHorizontal),
        ])),
        _dockBox(context, isCardio
            ? _stopwatch(context, seconds: now.difference(session.startedAt ?? now).inSeconds, label: 'Done', enabled: !paused, onDone: (minutes) {
                store.update((_) => session.cardioDone = minutes);
                _finish(context, session, null);
              })
            : SizedBox(width: double.infinity, height: 56, child: FilledButton.icon(
                onPressed: paused ? null : () => _finish(context, session, null), icon: const Icon(LucideIcons.check, size: 18), label: Text(paused ? 'Paused' : 'Done')))),
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
  final VoidCallback? onPressed; // null: shown but off, as while paused
  @override
  State<_HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<_HoldButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.hold > Duration.zero ? widget.hold : const Duration(milliseconds: 1));
    if (widget.hold > Duration.zero && widget.onPressed != null) {
      _c.forward().whenComplete(() { if (mounted) setState(() {}); });
    } else {
      _c.value = 1;
    }
  }

  @override
  void didUpdateWidget(_HoldButton old) {
    super.didUpdateWidget(old);
    // paused mid-wait: the wait is over, the button shows Paused, and resuming does not start it again
    if (widget.onPressed == null && !_c.isCompleted) { _c.stop(); _c.value = 1; }
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
    return SizedBox(width: double.infinity, height: 56, child: AnimatedSwitcher(
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
                  widthFactor: Curves.easeInOut.transform(_c.value), heightFactor: 1, child: ColoredBox(color: Color.lerp(du.accentSubtle, du.accentLine, 0.5)!)))),
                Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.wind, size: 18, color: du.accentText),
                  const SizedBox(width: 8),
                  Flexible(child: Text(widget.caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelLarge?.copyWith(color: du.accentText))),
                ]))),
              ]),
            ),
    ));
  }
}

/// The reps on a sideways wheel: the target range in ink, the rest faint, the one in the window large. Log arrives a
/// moment after the wheel does, so the tap that started the set cannot end it.
class _RepWheel extends StatefulWidget {
  const _RepWheel({required this.title, required this.values, required this.initial, required this.lo, required this.hi, required this.unit, required this.action, this.onLog, this.onChanged, this.onCancel, this.cancelLabel = 'Keep it', this.cancelIcon, this.enabled = true, this.hold = Duration.zero});
  final String title;
  final List<int> values;
  final int initial;
  final int lo, hi;
  final String unit;
  final String action;
  final ValueChanged<int>? onLog;     // null: no Log button, the wheel saves as it turns through [onChanged]
  final ValueChanged<int>? onChanged;
  final VoidCallback? onCancel;
  final String cancelLabel;
  final IconData? cancelIcon;
  final bool enabled; // false while paused: the wheel turns, Log waits
  final Duration hold; // how long Log takes to arrive: only when the set has just begun
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
          color: du.accentSubtle, borderRadius: BorderRadius.circular(14), border: Border.all(color: du.accentLine, width: 1.5))),
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(colors: [Color(0x00000000), Color(0xFF000000), Color(0xFF000000), Color(0x00000000)], stops: [0, 0.22, 0.78, 1]).createShader(r),
          blendMode: BlendMode.dstIn,
          child: RotatedBox(quarterTurns: 3, child: ListWheelScrollView.useDelegate(
            controller: _ctl,
            itemExtent: _extent,
            diameterRatio: 2.4,
            perspective: 0.004,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (i) { HapticFeedback.selectionClick(); setState(() => _sel = i); widget.onChanged?.call(widget.values[i]); },
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
        if (widget.onCancel != null) Expanded(child: SizedBox(height: 56, child: widget.cancelIcon == null
            ? OutlinedButton(onPressed: widget.onCancel, child: Text(widget.cancelLabel, maxLines: 1, overflow: TextOverflow.ellipsis))
            : OutlinedButton.icon(onPressed: widget.onCancel, icon: Icon(widget.cancelIcon, size: 18), label: Text(widget.cancelLabel, maxLines: 1, overflow: TextOverflow.ellipsis)))),
        if (widget.onCancel != null && widget.onLog != null) const SizedBox(width: 8),
        if (widget.onLog != null) Expanded(flex: 2, child: _HoldButton(
          key: ValueKey('log ${widget.action}'),
          label: widget.enabled ? '${widget.action} $v $word' : 'Paused',
          caption: 'Do your set',
          hold: m(context, widget.hold),
          onPressed: widget.enabled ? () => widget.onLog!(v) : null,
        )),
      ]),
    ]);
  }
}

/// An accordion of things to do: the moves of a warm-up or a stretch with their times, or the cardio a place offers
/// with what it needs. Tapping a row opens how to do it, as short numbered steps, and closes whichever was open.
class _MoveList extends StatefulWidget {
  const _MoveList(this.rows, {super.key, required this.icon});
  final List<({String name, String detail, String how})> rows;
  final IconData icon;
  @override
  State<_MoveList> createState() => _MoveListState();
}

class _MoveListState extends State<_MoveList> {
  int? _open;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Panel(padding: EdgeInsets.zero, child: Column(children: [
      for (var i = 0; i < widget.rows.length; i++) ...[
        if (i > 0) const Divider(height: 1),
        InkWell(
          onTap: () { HapticFeedback.selectionClick(); setState(() => _open = _open == i ? null : i); },
          child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 12, 12), child: Row(children: [
            Icon(widget.icon, size: 18, color: _open == i ? du.accentText : du.inkTertiary),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.rows[i].name, style: t.bodyLarge),
              Text(widget.rows[i].detail, style: t.bodySmall),
            ])),
            AnimatedRotation(
              turns: _open == i ? 0.5 : 0,
              duration: m(context, durBase),
              child: Icon(LucideIcons.chevronDown, size: 18, color: du.inkSecondary),
            ),
          ])),
        ),
        AnimatedSize(
          duration: m(context, durSlow),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: _open != i
              ? const SizedBox(width: double.infinity)
              : Padding(padding: const EdgeInsets.fromLTRB(15, 0, 16, 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final (k, step) in HowToSteps.split(widget.rows[i].how).indexed)
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      StepNumber(k + 1, size: 20),
                      const SizedBox(width: 13),
                      Expanded(child: Text(step, style: t.bodyMedium?.copyWith(color: du.inkSecondary))),
                    ])),
                ])),
        ),
      ],
    ]));
  }
}
