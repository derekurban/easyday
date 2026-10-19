// During: a strip of the whole workout, the item under way, and one thing to do at a time. A set starts lifting; the
// reps end it and the guide says rest; I'm ready starts the next. Then the time it took, lifting and rest, and closure.
import 'dart:async';
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
import '../logic/workout.dart';
import 'app.dart';
import 'motion.dart';
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
  int? effort;
  bool editing = false;       // the reps reopened to correct the last set
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

  /// Every second: the clocks move, the rest timer (when it is on) starts the next set, and the last block ends the
  /// workout when its minutes are up.
  void _onTick() {
    if (!mounted) return;
    final store = context.store;
    final x = store.state.active;
    if (x == null || x.type != 'lift' || note != null || finishing) return;
    final cur = currentItem(x);
    final now = store.now;
    if (cur != null) {
      if (store.state.settings.restAuto && cur.lifting && !editing) {
        final due = restDue(x, cur);
        if (due != null && !now.isBefore(due)) { store.update((_) => ready(x, due)); return; }
      }
      final items = workoutItems(x);
      if (cur.kind == ItemKind.stretch && items.last.key == cur.key && !now.isBefore(x.itemStarts[cur.key]!.add(Duration(minutes: cur.minutes)))) {
        setState(() => finishing = true);
        return;
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final session = store.state.active!;
    if (note != null) return _done(context, note!);
    if (finishing) return _feel(context, session);
    if (session.type == 'move') return _move(context, session);
    if (session.exercises.isEmpty) return _feel(context, session);
    final now = store.now;
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final items = workoutItems(session);
    final cur = currentItem(session) ?? items.first;
    final curIdx = items.indexWhere((x) => x.key == cur.key);
    final elapsed = session.startedAt == null ? 0.0 : now.difference(session.startedAt!).inSeconds.toDouble();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(children: [
          Icon(LucideIcons.clock, size: 16, color: du.inkSecondary),
          const SizedBox(width: 6),
          Text(mmss(elapsed), style: t.titleMedium?.copyWith(color: du.inkSecondary, fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
        actions: [TextButton.icon(onPressed: () => _stop(context, session), icon: const Icon(LucideIcons.square, size: 14), label: const Text('End'))],
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: _strip(context, session, items, curIdx, now)),
        Expanded(child: PageSwitcher(
          index: curIdx,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: cur.lifting ? _liftBody(context, session, items, cur, now) : _blockBody(context, session, items, cur, now),
          ),
        )),
        _dock(context, session, items, cur),
      ]),
    );
  }

  // ---- the strip ----

  double _planned(Session x, WorkoutItem it) => switch (it.kind) {
        ItemKind.exercise => plannedSeconds(x.exercises[it.exercises.single]),
        ItemKind.circuit => it.exercises.fold(0.0, (a, i) => a + plannedSeconds(x.exercises[i])) + roundRestSeconds * 2,
        _ => it.minutes * 60.0,
      };

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

  bool _skipped(Session x, WorkoutItem it) => it.lifting && it.exercises.every((i) => x.skipped.contains(i)) && x.itemStarts[it.key] == null;

  Widget _strip(BuildContext context, Session x, List<WorkoutItem> items, int curIdx, DateTime now) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final cur = items[curIdx];
    final lifting = cur.lifting && liftingSet(x, cur) != null;
    final start = x.itemStarts[cur.key];
    final progress = start == null ? 0.0 : (now.difference(start).inSeconds / max(1.0, _planned(x, cur))).clamp(0.0, 1.0);
    int flex(WorkoutItem it) => max(1, _planned(x, it).round());
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        for (var i = 0; i < items.length; i++)
          Expanded(flex: flex(items[i]), child: GestureDetector(
            onTap: i > curIdx ? () => _jump(context, x, items, curIdx, i) : null,
            child: AnimatedContainer(
              duration: m(context, durBase),
              height: 18,
              margin: EdgeInsets.only(right: i == items.length - 1 ? 0 : 3),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: i < curIdx ? (_skipped(x, items[i]) ? du.sunk : du.accentStrong) : i == curIdx ? du.accentLine : du.line,
                borderRadius: BorderRadius.circular(5),
                border: i == curIdx ? Border.all(color: du.accentStrong, width: 1.5) : null,
              ),
              child: i == curIdx
                  ? Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: progress, child: Container(color: lifting ? du.accentStrong : du.accentStrong.withValues(alpha: 0.45))))
                  : null,
            ),
          )),
      ]),
      const SizedBox(height: 5),
      Row(children: [
        for (var i = 0; i < items.length; i++)
          Expanded(flex: flex(items[i]), child: Padding(
            padding: EdgeInsets.only(right: i == items.length - 1 ? 0 : 3),
            child: Text(
              '${_short(x, items[i])}${i == curIdx && items[i].lifting ? (lifting ? ' · lifting' : ' · resting') : ''}',
              maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis,
              style: t.labelSmall?.copyWith(letterSpacing: 0, color: i == curIdx ? du.accentText : du.inkTertiary, fontWeight: i == curIdx ? FontWeight.w600 : null),
            ),
          )),
      ]),
    ]);
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

  Widget _guide(BuildContext context, {required bool work, required String title, required String sub, DateTime? since, int? plan, DateTime? now}) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final fg = work ? du.onAccent : du.ink;
    final secs = since == null || now == null ? null : max(0, now.difference(since).inSeconds).toDouble();
    return AnimatedContainer(
      duration: m(context, durBase),
      curve: easeOut,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: work ? du.accentStrong : du.sunk, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: t.titleLarge?.copyWith(color: fg)),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sub, style: t.bodySmall?.copyWith(color: work ? du.onAccent.withValues(alpha: 0.85) : du.inkSecondary)),
            if (plan != null && secs != null) Padding(padding: const EdgeInsets.only(top: 8), child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(height: 4, child: LinearProgressIndicator(value: (secs / plan).clamp(0.0, 1.0), backgroundColor: du.line, color: du.accentStrong)),
            )),
          ])),
          if (secs != null) Padding(padding: const EdgeInsets.only(left: 12), child: Text(mmss(secs), style: t.displayLarge?.copyWith(fontSize: 30, letterSpacing: -0.8, color: fg, fontFeatures: const [FontFeature.tabularFigures()]))),
        ]),
      ]),
    );
  }

  String _level(SessionExercise e) => e.rungLabel == e.exercise.name ? 'standard' : e.rungLabel;

  String _target(SessionExercise e) {
    final unit = e.exercise.repLabel == 'seconds' ? ' s' : ' reps';
    if (e.atCeiling) return 'Top of the progression: beat ${e.bestTotal} total across ${e.sets.length} sets';
    if (e.nextLevel) return 'The next level: ${e.lo}$unit on every set makes ${e.rungLabel} yours';
    if (e.intent == intentLight) return 'Lighter today: ${e.lo} to ${e.hi}$unit, nothing judged';
    return '${e.lo} to ${e.hi}$unit, as many as you can with good form';
  }

  String _nextExercise(Session x, SessionExercise e) {
    final w = e.warmups.isEmpty ? '' : '. Warm up ${e.warmups.map((w) => '${w.reps} × ${fmtKg(context.store.state, w.kg)}').join(', then ')}';
    return '${e.exercise.name.toLowerCase()}, ${_level(e)}$w';
  }

  String _nextItemLine(Session x, List<WorkoutItem> items, WorkoutItem cur) {
    final i = items.indexWhere((it) => it.key == cur.key);
    if (i + 1 >= items.length) return 'Finish when you\'ve caught your breath.';
    final n = items[i + 1];
    return switch (n.kind) {
      ItemKind.exercise => 'Next: ${_nextExercise(x, x.exercises[n.exercises.single])}.',
      ItemKind.circuit => 'Next: the circuit, ${n.exercises.map((k) => x.exercises[k].exercise.name.toLowerCase()).join(', ')}.',
      ItemKind.cardio => 'Next: cardio, ${n.minutes} minutes.',
      ItemKind.stretch => 'Next: stretching, ${n.minutes} minutes.',
      ItemKind.warmup => 'Next: the warm-up.',
    };
  }

  List<Widget> _liftBody(BuildContext context, Session x, List<WorkoutItem> items, WorkoutItem cur, DateTime now) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final store = context.store;
    final lift = liftingSet(x, cur), last = lastLogged(x, cur), next = nextSet(x, cur);
    final shown = (lift ?? last ?? next)!;
    final e = x.exercises[shown.ex];
    final circuit = cur.kind == ItemKind.circuit;
    final rounds = cur.exercises.fold(0, (a, i) => max(a, x.exercises[i].sets.length));
    final header = !circuit
        ? (lift != null ? 'Set ${e.attempted.length + 1} of ${e.sets.length}' : e.attempted.isNotEmpty ? 'Set ${e.attempted.length} of ${e.sets.length} done' : 'Set 1 of ${e.sets.length}')
        : lift != null
            ? 'Round ${lift.set + 1} of $rounds · ${cur.exercises.indexOf(lift.ex) + 1} of ${cur.exercises.length}'
            : last != null ? 'Round ${last.set + 1} of $rounds · ${cur.exercises.indexOf(last.ex) + 1} of ${cur.exercises.length} done' : 'Round 1 of $rounds';
    // the chips: this exercise's sets, or in a circuit this round across the exercises
    final round = (lift ?? last ?? next)!.set;
    final chips = <({SetLog log, bool now, bool tappable})>[
      if (!circuit)
        for (var k = 0; k < e.sets.length; k++) (log: e.sets[k], now: lift != null && lift.ex == shown.ex && lift.set == k, tappable: last != null && last.ex == shown.ex && last.set == k)
      else
        for (final i in cur.exercises)
          if (round < x.exercises[i].sets.length) (log: x.exercises[i].sets[round], now: lift != null && lift.ex == i && lift.set == round, tappable: last != null && last.ex == i && last.set == round),
    ];
    final plan = lift == null ? plannedRest(x, cur) : null;
    final settings = store.state.settings;
    String restSub() {
      if (plan != null) {
        final what = circuit && next!.set > last!.set ? 'round ${next.set + 1}' : 'set ${x.exercises[next!.ex].attempted.length + 1}';
        return settings.restAuto ? '${what[0].toUpperCase()}${what.substring(1)} starts by itself at ${mmss(plan.toDouble())}.' : 'About ${mmss(plan.toDouble())} is plenty before $what.';
      }
      if (next != null) return 'Next: ${_nextExercise(x, x.exercises[next.ex])}.';
      return "That's every set. ${_nextItemLine(x, items, cur)}";
    }
    final split = itemSplit(x, cur, now);
    return [
      Text(header, style: t.bodySmall),
      const SizedBox(height: 6),
      Text(e.exercise.name, style: t.headlineLarge),
      const SizedBox(height: 2),
      Text(_level(e), style: t.titleLarge?.copyWith(color: du.accentText)),
      const SizedBox(height: 14),
      Row(children: [
        for (var k = 0; k < chips.length; k++)
          Expanded(child: Padding(
            padding: EdgeInsets.only(right: k == chips.length - 1 ? 0 : 8),
            child: GestureDetector(
              onTap: chips[k].tappable && lift == null ? () => setState(() => editing = true) : null,
              child: AnimatedContainer(
                duration: m(context, durBase),
                curve: easeOut,
                height: 52, alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: chips[k].log.attempted ? du.accentSubtle : du.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: chips[k].now ? du.accentStrong : (chips[k].log.attempted ? du.accentLine : du.line), width: chips[k].now ? 2 : 0.6),
                ),
                child: chips[k].log.attempted
                    ? Text('${chips[k].log.reps}', style: t.headlineMedium?.copyWith(color: du.accentText))
                    : Text(chips[k].now ? 'now' : '·', style: chips[k].now ? t.labelMedium?.copyWith(color: du.accentText) : t.headlineMedium?.copyWith(color: du.inkTertiary)),
              ),
            ),
          )),
      ]),
      if (circuit) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${cur.exercises.map((i) => x.exercises[i].exercise.name).join(' → ')}, then rest and go again.', style: t.labelSmall)),
      if (lift != null)
        _guide(context, work: true, title: 'Go give it your best!', sub: _target(e), since: setOf(x, lift).start, now: now)
      else
        _guide(context, work: false, title: "Rest up and let us know when you're ready", sub: restSub(), since: restSince(x, cur), plan: plan, now: now),
      const SizedBox(height: 12),
      _splitBar(context, split.lifting, split.rest),
      const SizedBox(height: 16),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(LucideIcons.bookOpen, size: 14, color: du.inkTertiary),
        const SizedBox(width: 6),
        Expanded(child: Text(howAt(e.exercise, e.rung), style: t.bodySmall?.copyWith(color: du.inkSecondary))),
      ]),
    ];
  }

  List<Widget> _blockBody(BuildContext context, Session x, List<WorkoutItem> items, WorkoutItem cur, DateTime now) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final start = x.itemStarts[cur.key] ?? now;
    final left = max(0, start.add(Duration(minutes: cur.minutes)).difference(now).inSeconds).toDouble();
    final routine = switch (cur.kind) {
      ItemKind.warmup => routines['reset']!,
      ItemKind.stretch => _lowerDay(x) ? routines['hips']! : routines['upper']!,
      _ => null,
    };
    final moves = routine == null ? const <Move>[] : routine.moves.take(max(1, (cur.minutes * 60 / routine.seconds).ceil())).toList();
    final (title, sub) = switch (cur.kind) {
      ItemKind.warmup => ("Warm up, then let us know when you're ready", _nextItemLine(x, items, cur)),
      ItemKind.cardio => ('Keep it easy', 'A pace you could talk through. ${_nextItemLine(x, items, cur)}'),
      _ => ('Stretch it out', 'The workout ends when the timer does, or tap Finish.'),
    };
    return [
      Text('${_name(x, cur)} · ${cur.minutes} minutes', style: t.bodySmall),
      const SizedBox(height: 8),
      Text(mmss(left), style: t.displayLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
      _guide(context, work: false, title: title, sub: sub),
      const SizedBox(height: 16),
      if (moves.isNotEmpty)
        Panel(padding: EdgeInsets.zero, child: Column(children: [
          for (var i = 0; i < moves.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(dense: true, leading: Icon(LucideIcons.stretchHorizontal, size: 18, color: du.inkTertiary), title: Text(moves[i].n), subtitle: Text('${routine!.seconds} seconds')),
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
    final picking = cur.lifting && (liftingSet(x, cur) != null || (editing && lastLogged(x, cur) != null));
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 14 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(color: du.bg, border: Border(top: BorderSide(color: du.line, width: 0.6))),
      child: AnimatedSwitcher(
        duration: m(context, durBase),
        switchInCurve: easeSettle,
        switchOutCurve: easeOut,
        transitionBuilder: (child, a) => FadeTransition(opacity: a, child: SizeTransition(sizeFactor: a, axisAlignment: 1, child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(a), child: child))),
        child: picking
            ? KeyedSubtree(key: const ValueKey('reps'), child: _repsScale(context, x, cur))
            : KeyedSubtree(key: const ValueKey('ready'), child: SizedBox(width: double.infinity, height: 60, child: FilledButton(
                onPressed: () => _ready(context, x),
                child: Text(_readyLabel(x, items, cur), overflow: TextOverflow.ellipsis),
              ))),
      ),
    );
  }

  /// The reps: the range set for this exercise, one button for anything under it and one for anything over.
  Widget _repsScale(BuildContext context, Session x, WorkoutItem cur) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final lift = liftingSet(x, cur);
    final r = (lift ?? lastLogged(x, cur))!;
    final e = x.exercises[r.ex];
    final seconds = e.exercise.repLabel == 'seconds';
    final step = seconds && e.hi - e.lo > 12 ? 5 : 1;
    final values = <int>[for (var v = e.lo; v < e.hi; v += step) v, e.hi];
    final options = <(String, int)>[('< ${e.lo}', max(0, e.lo - step)), for (final v in values) ('$v', v), ('> ${e.hi}', e.hi + step)];
    final selected = lift == null ? setOf(x, r).reps : null;
    final perRow = options.length <= 8 ? options.length : (options.length / 2).ceil();
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(lift == null ? 'Fix that set: tap the right number' : seconds ? 'How many seconds did you hold?' : 'How many reps did you get?', style: t.labelMedium, textAlign: TextAlign.center),
      const SizedBox(height: 10),
      LayoutBuilder(builder: (context, c) {
        final w = (c.maxWidth - 6 * (perRow - 1)) / perRow;
        return Wrap(spacing: 6, runSpacing: 6, children: [
          for (final (label, v) in options)
            SizedBox(width: w, height: 52, child: v == selected
                ? FilledButton(style: FilledButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero), onPressed: () => _logReps(context, x, v), child: Text(label, style: t.titleMedium?.copyWith(color: du.onAccent)))
                : OutlinedButton(style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                    onPressed: () => _logReps(context, x, v),
                    child: Text(label, style: t.titleMedium?.copyWith(color: label.startsWith('<') || label.startsWith('>') ? du.inkSecondary : du.ink)))),
        ]);
      }),
      if (lift == null) TextButton(onPressed: () => setState(() => editing = false), child: const Text('Keep it as it was')),
    ]);
  }

  void _logReps(BuildContext context, Session x, int reps) {
    final store = context.store;
    store.update((_) => enterReps(x, reps, store.now));
    setState(() => editing = false);
  }

  void _ready(BuildContext context, Session x) {
    final store = context.store;
    var more = true;
    store.update((_) => more = ready(x, store.now));
    setState(() { editing = false; if (!more) finishing = true; });
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
        swatch(du.accentStrong), const SizedBox(width: 5), Text('Lifting ${amount(lifting)}', style: t.labelSmall?.copyWith(color: du.inkSecondary, letterSpacing: 0)),
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
    finishSession(store.state, session, f, store.now);
    note = session.note;
    store.state.active = session; // keep the screen until Done is tapped
    setState(() {});
    _autoTrack(store.state, session);
  }

  /// With auto-track on, a workout that started is written to the calendar from start to end. Never one that did not.
  Future<void> _autoTrack(AppState s, Session session) async {
    final st = s.settings;
    if (!st.calendar || !st.autoTrack || session.startedAt == null || session.endedAt == null) return;
    final text = workoutEventText(s, session, (e) => e.rungLabel);
    final id = await CalendarBridge.writeEvent(calendarId: st.calendarId, eventId: session.calendarEventId, begin: session.startedAt!, end: session.endedAt!, title: text.title, description: text.description);
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
    return 'lifting ${a(lifting)} · rest ${a(rest)}';
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
            Text('${r!.seconds} seconds each. Breathe.', style: t.bodyMedium?.copyWith(color: du.inkSecondary)),
            const SizedBox(height: 12),
            for (var i = 0; i < r.moves.length; i++)
              ListTile(contentPadding: EdgeInsets.zero, leading: const IconBadge(LucideIcons.stretchHorizontal, size: 36), title: Text(r.moves[i].n), subtitle: Text(r.moves[i].how)),
          ],
        ])),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(color: du.bg, border: Border(top: BorderSide(color: du.line, width: 0.6))),
          child: SizedBox(width: double.infinity, height: 56, child: FilledButton.icon(onPressed: () => _finish(context, session, null), icon: const Icon(LucideIcons.check, size: 20), label: const Text('Done'))),
        ),
      ]),
    );
  }
}
