// During: the current exercise, its level, the top to aim for, two big taps. No timer. Straight sets or circuit.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/library.dart';
import '../data/model.dart';
import '../integrations.dart';
import '../logic/after.dart';
import '../logic/calendar.dart';
import '../logic/builder.dart';
import '../logic/ladder.dart';
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
  int idx = 0;
  bool forward = true;
  bool fewer = false;
  int? fewerValue;
  bool finishing = false;     // the feel question is showing
  Finish? pendingFinish;      // stop reason chosen, waiting for feel
  String? note;               // after finishSession: the one line
  int? effort;
  int? justLogged;            // set index that just got a tap, for the pop

  void _goTo(int i) => setState(() { forward = i >= idx; idx = i; fewer = false; justLogged = null; });

  /// The next exercise with a set still to do, starting after [from], wrapping round. Null when none.
  int? _nextOpen(Session session, int from) {
    final n = session.exercises.length;
    for (var k = 1; k <= n; k++) {
      final i = (from + k) % n;
      if (!session.exercises[i].done && !session.skipped.contains(i)) return i;
    }
    return null;
  }

  bool _allDone(Session session) => session.exercises.asMap().entries.every((e) => e.value.done || session.skipped.contains(e.key));

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final session = store.state.active!;
    if (note != null) return _done(context, note!);
    if (finishing) return _feel(context, session);
    if (session.type == 'move') return _move(context, session);
    if (session.exercises.isEmpty) return _feel(context, session);
    idx = idx.clamp(0, session.exercises.length - 1);
    final e = session.exercises[idx];
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final nextSet = e.sets.indexWhere((x) => !x.attempted);
    final skipped = session.skipped.contains(idx);
    final allDone = _allDone(session);
    final seconds = e.exercise.repLabel == 'seconds';
    final unit = seconds ? ' s' : '';
    final doneSets = session.exercises.fold(0, (a, x) => a + x.attempted.length);
    final totalSets = session.exercises.fold(0, (a, x) => a + x.sets.length);
    final nextOpen = _nextOpen(session, idx);
    final rounds = session.exercises.fold(0, (a, x) => x.sets.length > a ? x.sets.length : a);
    final header = session.circuit
        ? 'round ${(nextSet < 0 ? e.sets.length : nextSet) + 1} of $rounds · $doneSets of $totalSets sets'
        : '${idx + 1} of ${session.exercises.length} · $doneSets of $totalSets sets';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          for (var i = 0; i < session.exercises.length; i++)
            Expanded(child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: GestureDetector(onTap: () => _goTo(i), child: Meter(session.exercises[i].done ? 1 : session.exercises[i].attempted.length / session.exercises[i].sets.length, height: i == idx ? 6 : 4)),
            )),
          const SizedBox(width: 8),
        ]),
        leading: IconButton(onPressed: idx > 0 ? () => _goTo(idx - 1) : null, icon: const Icon(LucideIcons.chevronLeft), tooltip: 'Previous exercise'),
        actions: [
          IconButton(onPressed: idx < session.exercises.length - 1 ? () => _goTo(idx + 1) : null, icon: const Icon(LucideIcons.chevronRight), tooltip: 'Next exercise'),
          TextButton.icon(onPressed: () => _stop(context, session), icon: const Icon(LucideIcons.square, size: 14), label: const Text('End')),
        ],
      ),
      body: PageSwitcher(
        index: idx,
        forward: forward,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Row(children: [
              IconBadge(session.circuit ? LucideIcons.repeat : exerciseIcon(e.exercise), size: 32),
              const SizedBox(width: 8),
              Text(header, style: t.bodySmall),
            ]),
            const SizedBox(height: 10),
            Text(e.exercise.name, style: t.headlineLarge),
            const SizedBox(height: 4),
            Row(children: [
              Icon(LucideIcons.circleDot, size: 16, color: du.accentText),
              const SizedBox(width: 6),
              Expanded(child: Text(e.rungLabel == e.exercise.name ? 'standard' : e.rungLabel, style: t.titleLarge?.copyWith(color: du.accentText))),
            ]),
            const SizedBox(height: 14),
            Panel(
              sunk: true,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Icon(LucideIcons.target, size: 18, color: du.inkSecondary),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  e.atCeiling
                      ? 'Top of the progression here. Beat ${e.bestTotal} total across ${e.sets.length} sets.'
                      : e.nextLevel
                          ? 'The next level. As many as you can with good form: reach ${e.lo}$unit on every set and ${e.rungLabel} is your level today.'
                          : e.intent == intentLight
                              ? 'Lighter today. ${e.lo} to ${e.hi}$unit is the range; nothing is judged.'
                              : 'As many as you can with good form. ${e.lo} to ${e.hi}$unit is the range: ${e.hi} or more on every set and the next level is yours.',
                  style: t.bodyMedium,
                )),
                const SizedBox(width: 8),
                DifficultyTag(e.difficulty),
              ]),
            ),
            if (e.warmups.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(children: [
                  Icon(LucideIcons.flame, size: 14, color: du.inkTertiary),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Warm up: ${e.warmups.map((w) => '${w.reps} × ${fmtKg(store.state, w.kg)}').join(', then ')}. Not logged.', style: t.bodySmall)),
                ]),
              ),
            const SizedBox(height: 22),
            Row(children: [
              for (var i = 0; i < e.sets.length; i++)
                Expanded(child: Padding(
                  padding: EdgeInsets.only(right: i == e.sets.length - 1 ? 0 : 8),
                  child: AnimatedContainer(
                    duration: m(context, durBase),
                    curve: easeOut,
                    height: 60, alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: e.sets[i].attempted ? (e.sets[i].reps! >= e.target ? du.accentSubtle : du.sunk) : du.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: i == nextSet && !skipped ? du.accentStrong : (e.sets[i].attempted ? du.accentLine : du.line), width: i == nextSet && !skipped ? 2 : 0.6),
                    ),
                    child: e.sets[i].attempted
                        ? (justLogged == i
                            ? Pop(key: ValueKey('p$i'), child: Text('${e.sets[i].reps}', style: t.headlineMedium?.copyWith(color: du.accentText)))
                            : Text('${e.sets[i].reps}', style: t.headlineMedium?.copyWith(color: du.accentText)))
                        : Text(i == nextSet && !skipped ? 'now' : '·', style: i == nextSet && !skipped ? t.labelMedium?.copyWith(color: du.accentText) : t.headlineMedium?.copyWith(color: du.inkTertiary)),
                  ),
                )),
            ]),
            const SizedBox(height: 22),
            AnimatedSwitcher(
              duration: m(context, durBase),
              child: skipped
                  ? Column(key: const ValueKey('skipped'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [Icon(LucideIcons.skipForward, size: 20, color: du.inkSecondary), const SizedBox(width: 8), Expanded(child: Text('Skipped. Nothing is judged.', style: t.bodyLarge))]),
                      const SizedBox(height: 12),
                      _nextButton(context, session, nextOpen, allDone),
                      TextButton(onPressed: () { store.update((_) => session.skipped.remove(idx)); setState(() {}); }, child: const Text('Un-skip')),
                    ])
                  : nextSet < 0
                      ? Column(key: const ValueKey('done'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Row(children: [Icon(LucideIcons.circleCheck, size: 20, color: du.accentStrong), const SizedBox(width: 8), Text('Done with this one.', style: t.bodyLarge)]),
                          const SizedBox(height: 12),
                          _nextButton(context, session, nextOpen, allDone),
                        ])
                      : fewer
                          ? _fewerPicker(context, session, e, seconds)
                          : Column(key: const ValueKey('tap'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              SizedBox(height: 76, child: FilledButton.icon(
                                onPressed: () => _log(context, session, e.target),
                                icon: Icon(e.nextLevel ? LucideIcons.arrowUp : LucideIcons.check, size: 26),
                                label: Text('${e.target}$unit or more', style: t.headlineMedium?.copyWith(color: du.onAccent)),
                              )),
                              const SizedBox(height: 10),
                              SizedBox(height: 56, child: OutlinedButton.icon(onPressed: () => setState(() { fewer = true; fewerValue = seconds ? ((e.target - 5) ~/ 5) * 5 : e.target - 1; }), icon: const Icon(LucideIcons.minus, size: 18), label: Text(seconds ? 'Shorter' : 'Fewer'))),
                            ]),
            ),
            const SizedBox(height: 8),
            Row(children: [
              TextButton.icon(onPressed: e.attempted.isEmpty ? null : () { store.update((_) => undoSet(session, idx)); setState(() => justLogged = null); }, icon: const Icon(LucideIcons.undo2, size: 16), label: const Text('Undo')),
              const Spacer(),
              if (!skipped && nextSet >= 0)
                TextButton.icon(onPressed: () => _skip(context, session), icon: const Icon(LucideIcons.skipForward, size: 16), label: const Text('Skip this exercise')),
            ]),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(LucideIcons.bookOpen, size: 14, color: du.inkTertiary),
              const SizedBox(width: 6),
              Expanded(child: Text(howAt(e.exercise, e.rung), style: t.bodyMedium?.copyWith(color: du.inkSecondary))),
            ]),
            if (nextOpen != null && nextOpen != idx && nextSet >= 0 && !skipped)
              Padding(padding: const EdgeInsets.only(top: 16), child: Text('Up next: ${session.exercises[nextOpen].exercise.name}', style: t.labelMedium)),
          ],
        ),
      ),
    );
  }

  Widget _nextButton(BuildContext context, Session session, int? nextOpen, bool allDone) {
    if (allDone) {
      return SizedBox(height: 60, child: FilledButton.icon(onPressed: () => setState(() => finishing = true), icon: const Icon(LucideIcons.flag, size: 20), label: const Text('Finish the workout')));
    }
    if (nextOpen == null) return const SizedBox.shrink();
    return SizedBox(height: 60, child: FilledButton.icon(onPressed: () => _goTo(nextOpen), icon: const Icon(LucideIcons.chevronRight, size: 20), iconAlignment: IconAlignment.end, label: Text('Next: ${session.exercises[nextOpen].exercise.name}')));
  }

  Widget _fewerPicker(BuildContext context, Session session, SessionExercise e, bool seconds) {
    final target = e.target;
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final step = seconds ? 5 : 1;
    final max = (target - step).clamp(0, target);
    final v = (fewerValue ?? max).clamp(0, max);
    final inRange = v >= e.lo;
    return Column(key: const ValueKey('fewer'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(seconds ? 'How many seconds did you hold' : 'How many did you get', icon: LucideIcons.hand),
      Center(child: AnimatedSwitcher(
        duration: m(context, durFast),
        child: Text('$v${seconds ? ' s' : ''}', key: ValueKey(v), style: t.displayLarge?.copyWith(color: inRange ? du.accentText : du.ink)),
      )),
      Slider(
        value: v.toDouble(), min: 0, max: max.toDouble(), divisions: max ~/ step == 0 ? 1 : max ~/ step,
        label: '$v', semanticFormatterCallback: (x) => '${x.round()}${seconds ? ' seconds' : ' reps'}',
        onChanged: (x) => setState(() => fewerValue = ((x / step).round() * step).clamp(0, max)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('0', style: t.labelSmall), Text('${e.lo} is the bottom of the range', style: t.labelSmall), Text('$max', style: t.labelSmall)]),
      ),
      const SizedBox(height: 6),
      Text(inRange ? 'Inside the range. The level holds and reps keep building.' : 'Below the range. Twice in a row and the level comes down one.', style: t.bodySmall),
      const SizedBox(height: 10),
      SizedBox(height: 60, child: FilledButton.icon(onPressed: () => _log(context, session, v), icon: const Icon(LucideIcons.check, size: 20), label: Text('Log $v${seconds ? ' s' : ''}'))),
      TextButton.icon(onPressed: () => setState(() => fewer = false), icon: const Icon(LucideIcons.chevronLeft, size: 16), label: const Text('Back')),
    ]);
  }

  void _log(BuildContext context, Session session, int reps) {
    final store = context.store;
    late int logged;
    store.update((_) => logged = logSet(session, idx, reps, store.now));
    final e = session.exercises[idx];
    setState(() {
      fewer = false;
      justLogged = logged;
      if (_allDone(session)) {
        finishing = true;
      } else if (session.circuit || e.done) {
        final next = _nextOpen(session, idx);
        if (next != null && next != idx) {
          Future.delayed(m(context, const Duration(milliseconds: 650)), () { if (mounted && store.state.active == session) _goTo(next); });
        }
      }
    });
  }

  void _skip(BuildContext context, Session session) {
    final store = context.store;
    store.update((_) => session.skipped.add(idx));
    setState(() {
      if (_allDone(session)) { finishing = true; return; }
      final next = _nextOpen(session, idx);
      if (next != null) _goTo(next);
    });
  }

  Future<void> _stop(BuildContext context, Session session) async {
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
      appBar: AppBar(title: const Text('How was it?')),
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

  Widget _done(BuildContext context, String line) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final store = context.store;
    final session = store.state.active!;
    final mins = session.elapsedMinutes;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Spacer(),
            Center(child: Pop(child: Container(
              width: 88, height: 88,
              decoration: BoxDecoration(shape: BoxShape.circle, color: du.accentSubtle, border: Border.all(color: du.accentLine, width: 0.6)),
              child: Icon(LucideIcons.check, size: 44, color: du.accentStrong),
            ))),
            const SizedBox(height: 20),
            Reveal(delay: const Duration(milliseconds: 120), child: Text('Logged.', style: t.headlineLarge, textAlign: TextAlign.center)),
            const SizedBox(height: 10),
            Reveal(delay: const Duration(milliseconds: 200), child: Text(line, style: t.bodyLarge, textAlign: TextAlign.center)),
            if (mins != null && mins >= 1 && mins <= 240) Padding(padding: const EdgeInsets.only(top: 12), child: Text('$mins minutes', style: t.bodySmall, textAlign: TextAlign.center)),
            const Spacer(),
            SizedBox(height: 56, child: FilledButton.icon(onPressed: () { store.update((s) => s.active = null); }, icon: const Icon(LucideIcons.check, size: 18), label: const Text('Done'))),
          ]),
        ),
      ),
    );
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
