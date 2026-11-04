// The edit drawer: one exercise of a finished workout, every set laid out to change, from the check after a workout.
// Each set has its reps, its weight or version, how long it took and the rest after it, each on a stepper; at the top,
// where the exercise lands next time, read again as anything changes. Every change counts at once.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/model.dart';
import '../logic/ladder.dart';
import '../logic/score.dart';
import '../logic/workout.dart';
import 'app.dart';
import 'theme.dart';

/// Open the drawer on a timed part of [x] (warm-up, cardio, stretching): how long it took, on one stepper.
Future<void> showItemEdit(BuildContext context, Session x, WorkoutItem it, String name) => showSheet<void>(context, Builder(builder: (context) {
      final store = context.store;
      final secs = itemSecondsOf(x, it, store.now) ?? 0;
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 4),
        SheetHeader(name, subtitle: 'How long it took. What came after moves with it.', icon: LucideIcons.pencil),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _Stepper(label: 'Took', value: mmss(secs.toDouble()),
            onStep: (d) => store.update((_) => setItemSeconds(x, it, max(0, secs + 30 * d), store.now)))),
        Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom), child: SizedBox(height: 56, child: FilledButton(
            onPressed: () => Navigator.pop(context), child: const Text('Done')))),
      ]);
    }));

/// Open the drawer on exercise [i] of [x], with set [focus] marked when the user tapped one.
Future<void> showExerciseEdit(BuildContext context, Session x, int i, {int? focus}) =>
    showSheet<void>(context, _EditDrawer(session: x, index: i, focus: focus));

class _EditDrawer extends StatefulWidget {
  const _EditDrawer({required this.session, required this.index, this.focus});
  final Session session;
  final int index;
  final int? focus;
  @override
  State<_EditDrawer> createState() => _EditDrawerState();
}

class _EditDrawerState extends State<_EditDrawer> {
  final _focusKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // opened on a set: bring it into view
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _focusKey.currentContext;
      if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 250), alignment: 0.1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session, index = widget.index, focus = widget.focus;
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final store = context.store; // depends on the store: every change redraws the drawer
    final s = store.state;
    final x = session;
    final e = x.exercises[index];
    final ex = e.exercise;
    final done = [for (var k = 0; k < e.sets.length; k++) if (e.sets[k].attempted) k];
    final choices = levelChoices(s, x, index);
    final eq = s.location(x.locationId)?.equipment ?? const <String>[];
    final unit = ex.repLabel == 'seconds' ? 'Seconds' : 'Reps';
    String mmssInt(int v) => mmss(v.toDouble());

    int levelAt(SetLog l) {
      final i = ex.loaded
          ? choices.indexWhere((c) => c.kg != null && (c.kg! - (l.kg ?? e.loadKg ?? 0)).abs() < 1e-6)
          : choices.indexWhere((c) => c.rung == (l.rung ?? e.rung));
      return max(0, i);
    }

    Widget setCard(int k) {
      final ref = (ex: index, set: k);
      final l = e.sets[k];
      final at = levelAt(l);
      final took = setSecondsOf(x, ref), rest = restAfterOf(x, ref);
      final level = choices.isEmpty ? (ex.loaded ? fmtLoad(s, ex, l.kg ?? 0, equipment: eq) : rungLabel(s, ex, ensureState(s, ex), l.rung ?? e.rung, e.range, eq)) : choices[at].label;
      return Container(
        key: k == focus ? _focusKey : null,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: du.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: k == focus ? du.accentStrong : du.line, width: k == focus ? 1.5 : 0.6),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Set ${k + 1}', style: t.titleMedium),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _Stepper(label: unit, value: '${l.reps}', onStep: (d) => store.update((_) => fixSet(x, ref, max(0, l.reps! + d))))),
            const SizedBox(width: 10),
            Expanded(flex: ex.loaded ? 1 : 2, child: _Stepper(label: ex.loaded ? 'Weight' : 'Version', value: level, onStep: choices.length < 2 ? null : (d) {
              final c = choices[(at + d).clamp(0, choices.length - 1)];
              store.update((_) => fixSetLevel(s, x, ref, kg: c.kg, rung: c.rung));
            })),
          ]),
          if (took != null || rest != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: took == null ? const SizedBox() : _Stepper(label: 'Set took', value: mmssInt(took), onStep: (d) => store.update((_) => setSetSeconds(x, ref, max(5, took + 5 * d))))),
              const SizedBox(width: 10),
              Expanded(child: rest == null ? const SizedBox() : _Stepper(label: 'Rest after', value: mmssInt(rest), onStep: (d) => store.update((_) => setRestAfter(x, ref, max(0, rest + 15 * d))))),
            ]),
          ],
        ]),
      );
    }

    final height = MediaQuery.of(context).size.height * 0.85;
    return ConstrainedBox(constraints: BoxConstraints(maxHeight: height), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 4),
      SheetHeader(ex.ladder != null ? e.rungLabel : ex.name, subtitle: 'What you did. Changes count as you make them.', icon: LucideIcons.pencil),
      Flexible(child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), children: [
        for (final k in done) setCard(k),
      ])),
      Padding(padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + MediaQuery.of(context).padding.bottom), child: SizedBox(height: 56, child: FilledButton(
          onPressed: () => Navigator.pop(context), child: const Text('Done')))),
    ]));
  }
}

/// A labelled value with a step down and a step up on either side. No steps when [onStep] is null.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.value, this.onStep});
  final String label;
  final String value;
  final ValueChanged<int>? onStep;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    Widget step(IconData icon, int d) => IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onStep == null ? null : () { HapticFeedback.selectionClick(); onStep!(d); },
          icon: Icon(icon, size: 18),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: t.labelSmall),
      const SizedBox(height: 4),
      Container(
        decoration: BoxDecoration(color: du.sunk, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          step(LucideIcons.minus, -1),
          Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              style: t.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]))),
          step(LucideIcons.plus, 1),
        ]),
      ),
    ]);
  }
}
