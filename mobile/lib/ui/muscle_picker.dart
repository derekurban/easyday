// The muscle picker: today's word on each muscle (logic/muscle_plan.dart), chosen on the body, one muscle per plate
// name, the same muscles selection and its ledgers run on. Tap muscles to select them (blue), then a pill says what the
// selected ones are today: forced, available or excluded. The figure shows the result the way a muscle map shows a
// workout: forced muscles in the primary green, available muscles the workout works mainly in the secondary green, the
// rest of the available ones plain, excluded ones very dark. Shuffle fills the places after the forced muscles from the
// available pool (Draw again draws anew); Manual works the forced muscles only. A stack of tabs at the bottom right
// switches between both figures, the front, the back, and a list: the muscles under Forced, Available and Excluded,
// each tile draggable up and down
// and between the three. Done hands the plan back to Today, which rebuilds the workout from it.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/index.dart';
import '../data/model.dart';
import '../logic/muscle_map.dart';
import '../logic/muscle_plan.dart';
import '../logic/selection.dart';
import 'app.dart';
import 'motion.dart';
import 'muscle_figure.dart';
import 'theme.dart';

/// An excluded muscle's fill: a very dark gray multiplied over the plate at nearly full strength.
const muscleExcluded = Color(0xF2303030);
/// The forced green: the light theme's accent in both themes, since the figure is the same light gray in both and the
/// dark theme's paler accent comes out too close to the secondary strength.
const musclePrimary = Color(0xFF456938);
/// The secondary strength: the primary colour at this alpha, for the available muscles the workout works mainly.
const muscleSecondaryAlpha = 0.45;

IconData muscleStateIcon(MuscleState s) => switch (s) { MuscleState.forced => LucideIcons.pin, MuscleState.available => LucideIcons.circleDashed, MuscleState.excluded => LucideIcons.ban };

/// The figure's fills from the states: forced in [primary], the available muscles in [chosen] at the secondary
/// strength, excluded very dark, the rest plain. Muscles in [selected] fill the selection blue instead.
Map<String, Color> muscleFills(Map<String, MuscleState> states, {required Set<String> chosen, required Color primary, Set<String> selected = const {}}) {
  final tint = <String, Color>{};
  for (final m in trackedMuscles) {
    final c = selected.contains(m)
        ? muscleSelect
        : switch (states[m]) {
            MuscleState.forced => primary,
            MuscleState.excluded => muscleExcluded,
            _ => chosen.contains(m) ? primary.withValues(alpha: muscleSecondaryAlpha) : null,
          };
    if (c != null) tint[m] = c;
  }
  return tint;
}

/// What a muscle looks like in the list: the plate gray under the same fill the figure gives it.
Color muscleSwatch(MuscleState? state, {required bool chosen, required Color primary}) => switch (state) {
      MuscleState.forced => Color.lerp(musclePlate, primary, 0.8)!,
      MuscleState.excluded => Color.lerp(musclePlate, const Color(0xFF303030), 0.9)!,
      _ => chosen ? Color.lerp(musclePlate, primary, muscleSecondaryAlpha)! : musclePlate,
    };

/// What a muscle's strain is in words: "ready", or "medium strain, strain-free Thursday".
String muscleStrainText(StrainPoints current, MuscleMap map, String muscle, DateTime now) {
  final shade = current.shade(muscle);
  if (shade == 0) return 'ready';
  return '${strainShadeLabels[strainShades - shade]} strain, strain-free ${dayText(map.strainFreeOn(muscle, now), now)}';
}

/// The muscles a built workout works mainly: every primary muscle of its exercises.
Set<String> workedMuscles(Session session) => {for (final e in session.exercises) ...e.exercise.primary};

class MusclePickerScreen extends StatefulWidget {
  const MusclePickerScreen({super.key, required this.plan, required this.preview, required this.drawMuscles});
  final MusclePlan plan;
  /// The workout the plan would build, for the figure's chosen muscles and the line above Done.
  final Session Function(MusclePlan plan) preview;
  /// The next muscle seed that changes the muscles worked (Draw again).
  final int Function(MusclePlan plan) drawMuscles;
  @override
  State<MusclePickerScreen> createState() => _MusclePickerScreenState();
}

class _MusclePickerScreenState extends State<MusclePickerScreen> {
  late MusclePlan plan = widget.plan.copy()..order.addAll([for (final m in trackedMuscles) if (!widget.plan.order.contains(m)) m]);
  final selected = <String>{};
  String view = 'both';

  static const views = {'both': LucideIcons.columns2, 'front': LucideIcons.personStanding, 'back': LucideIcons.flipHorizontal2, 'list': LucideIcons.list};
  static const viewLabel = {'both': 'Both sides', 'front': 'Front', 'back': 'Back', 'list': 'List'};

  void _toggle(String muscle) {
    HapticFeedback.selectionClick();
    setState(() { if (!selected.remove(muscle)) selected.add(muscle); });
  }

  void _apply(MuscleState st) {
    HapticFeedback.lightImpact();
    setState(() { plan.set(selected, st); selected.clear(); });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final s = store.state;
    final now = store.now;
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final map = MuscleMap(s);
    final current = map.currentStrainPoints(now);
    final session = widget.preview(plan);
    final chosen = workedMuscles(session);
    final forced = plan.forced;
    final defaults = defaultMuscleStates(current, s.goal);
    final changed = trackedMuscles.any((m) => plan.states[m] != defaults[m]) || plan.manual || plan.drawn;
    // the state the selection shares, when it shares one
    final shared = selected.isEmpty ? null : selected.map((g) => plan.states[g]).toSet().singleOrNull;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(LucideIcons.x, size: 22), tooltip: 'Close'),
        title: const Text('Muscles'),
        actions: [
          if (changed) TextButton.icon(onPressed: () => setState(() { plan = MusclePlan(states: defaults, order: trackedMuscles); selected.clear(); }), icon: const Icon(LucideIcons.undo2, size: 16), label: const Text('Reset')),
        ],
      ),
      body: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // how the rest of the workout is filled
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0), child: Row(children: [
          Expanded(child: Segmented<bool>(
            value: plan.manual, options: const {false: 'Shuffle', true: 'Manual'}, icons: const {false: LucideIcons.shuffle, true: LucideIcons.pin},
            onChanged: (v) => setState(() { plan.manual = v; plan.resetDraws(); }),
          )),
          const SizedBox(width: 8),
          IconButton.outlined(
            onPressed: plan.manual ? null : () { HapticFeedback.selectionClick(); setState(() => plan.draw(muscles: widget.drawMuscles(plan))); },
            icon: const Icon(LucideIcons.dices, size: 20), tooltip: 'Draw again',
          ),
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 0), child: Text(
          plan.manual ? 'Only forced muscles are worked.' : 'Forced muscles first, then the workout is drawn from the available ones.${plan.muscleDraw != null ? ' Drawn.' : ''}',
          style: t.bodySmall,
        )),
        Expanded(child: Stack(children: [
          Positioned.fill(child: AnimatedSwitcher(
            duration: m(context, durBase),
            child: view == 'list' ? _list(context, current, map, now, chosen) : _figure(context, chosen),
          )),
          Positioned(right: 12, bottom: 12, child: _tabs(context)),
        ])),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(color: du.bg, border: Border(top: BorderSide(color: du.line, width: 0.6))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // the selection and the pills that set its state
            Row(children: [
              Expanded(child: AnimatedSwitcher(
                duration: m(context, durBase),
                layoutBuilder: _leftLayout,
                child: Text(
                  selected.isEmpty ? 'Tap muscles to select them, then say what they are today.' : '${muscleTitle(listWords(selected))} selected',
                  key: ValueKey(selected.isEmpty ? '' : selected.join()), style: t.bodySmall?.copyWith(color: selected.isEmpty ? null : muscleSelect),
                ),
              )),
              if (selected.isNotEmpty) TextButton(onPressed: () => setState(selected.clear), style: TextButton.styleFrom(minimumSize: const Size(44, 32), padding: const EdgeInsets.symmetric(horizontal: 8)), child: const Text('Clear')),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              for (final st in const [MuscleState.forced, MuscleState.available, MuscleState.excluded]) ...[
                Expanded(child: _pill(context, st, on: shared == st, enabled: selected.isNotEmpty)),
                if (st != MuscleState.excluded) const SizedBox(width: 8),
              ],
            ]),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: m(context, durBase),
              layoutBuilder: _leftLayout,
              child: Column(key: ValueKey('${session.name}${session.exercises.length}${session.estMinutes}'), crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(session.exercises.isEmpty ? 'Nothing to work' : session.name, style: t.titleLarge),
                Text(session.exercises.isEmpty
                    ? (plan.manual ? 'Force a muscle to work it.' : 'Every muscle is excluded, or nothing here fits. Make some available.')
                    : '${session.exercises.length} exercise${session.exercises.length == 1 ? '' : 's'} · about ${session.estMinutes} min${forced.isNotEmpty ? ' · ${listWords(forced.map((g) => g.toLowerCase()))} forced' : ''}', style: t.bodySmall),
              ]),
            ),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, height: 52, child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(plan),
              icon: const Icon(LucideIcons.check, size: 20),
              label: const Text('Done'),
            )),
          ]),
        ),
      ])),
    );
  }

  /// Switched text sits at the left, not the centre AnimatedSwitcher defaults to.
  static Widget _leftLayout(Widget? current, List<Widget> previous) => Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]);

  /// One of the three pills: sets the selected muscles to a state.
  Widget _pill(BuildContext context, MuscleState st, {required bool on, required bool enabled}) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final ink = !enabled ? du.inkTertiary : on ? du.accentText : du.ink;
    return Pressable(
      borderRadius: 999,
      onTap: enabled ? () => _apply(st) : null,
      child: AnimatedContainer(
        duration: m(context, durBase),
        height: 40,
        decoration: BoxDecoration(
          color: on ? du.accentSubtle : enabled ? du.surface : du.bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? du.accentStrong : du.line, width: on ? 1.5 : 0.6),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(muscleStateIcon(st), size: 15, color: ink),
          const SizedBox(width: 6),
          Flexible(child: Text(muscleStateLabel[st]!, overflow: TextOverflow.ellipsis, style: t.labelLarge?.copyWith(color: ink))),
        ]),
      ),
    );
  }

  /// The vertical stack of view tabs, bottom right.
  Widget _tabs(BuildContext context) {
    final du = context.du;
    return Container(
      decoration: BoxDecoration(
        color: du.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: du.line, width: 0.6),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(3),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final e in views.entries)
          Tooltip(message: viewLabel[e.key]!, child: Pressable(
            borderRadius: 9,
            onTap: () => setState(() => view = e.key),
            child: AnimatedContainer(
              duration: m(context, durBase),
              width: 40, height: 40,
              decoration: BoxDecoration(color: view == e.key ? du.accentSubtle : Colors.transparent, borderRadius: BorderRadius.circular(9)),
              child: Icon(e.value, size: 19, color: view == e.key ? du.accentText : du.inkSecondary),
            ),
          )),
      ]),
    );
  }

  Widget _figure(BuildContext context, Set<String> chosen) {
    final tint = muscleFills(plan.states, chosen: chosen, primary: musclePrimary, selected: selected);
    final sides = view == 'both' ? const ['front', 'back'] : [view];
    return LayoutBuilder(key: ValueKey(view), builder: (context, c) {
      final n = sides.length;
      final height = min(c.maxHeight - 48, (c.maxWidth - 32 - 4 * (n - 1)) / (0.5 * n)).clamp(160.0, 1200.0).toDouble();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Wrap(spacing: 12, runSpacing: 4, children: [
          _swatch(context, muscleSwatch(MuscleState.forced, chosen: true, primary: musclePrimary), 'Forced'),
          _swatch(context, muscleSwatch(MuscleState.available, chosen: true, primary: musclePrimary), 'Chosen'),
          _swatch(context, musclePlate, 'Available'),
          _swatch(context, muscleSwatch(MuscleState.excluded, chosen: false, primary: musclePrimary), 'Excluded'),
          _swatch(context, Color.lerp(musclePlate, muscleSelect, 0.85)!, 'Selected'),
        ])),
        Expanded(child: Center(child: MuscleFigure(
          key: ValueKey('fig$view'),
          highlight: const {}, tint: tint, sides: sides, height: height, selectable: false, tooltip: false,
          onTap: (h) { if (h != null && trackedMuscles.contains(h.name)) _toggle(h.name); },
        ))),
      ]);
    });
  }

  Widget _swatch(BuildContext context, Color c, String text) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: du.line, width: 0.6))),
      const SizedBox(width: 5),
      Text(text, style: t.labelSmall),
    ]);
  }

  /// The list: a header per state, the muscles under each, every tile draggable up or down and across the headers.
  /// A tap selects a tile, like a tap on the figure.
  Widget _list(BuildContext context, StrainPoints current, MuscleMap map, DateTime now, Set<String> chosen) {
    final rhythm = rhythmOver(context.store.state, now);
    const sections = [MuscleState.forced, MuscleState.available, MuscleState.excluded];
    // the flat list the reorderable view shows: headers and tiles, each with a key
    final items = <({MuscleState? header, String? group})>[];
    for (final st in sections) {
      items.add((header: st, group: null));
      for (final g in musclesIn(plan.states, st, plan.order)) { items.add((header: null, group: g)); }
    }
    return ReorderableListView.builder(
      key: const ValueKey('list'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 72),
      buildDefaultDragHandles: false,
      itemCount: items.length,
      proxyDecorator: (child, i, anim) => AnimatedBuilder(animation: anim, builder: (context, _) => Material(
        color: Colors.transparent, elevation: 6 * anim.value, shadowColor: Colors.black38, borderRadius: BorderRadius.circular(12), child: child,
      )),
      onReorder: (from, to) {
        if (items[from].group == null) return;
        if (to > from) to--;
        final moved = items.removeAt(from);
        items.insert(to, moved);
        // the header above where it landed says its new state; the tiles' order is the list's order from now on
        var st = sections.first;
        for (var i = to; i >= 0; i--) { if (items[i].header != null) { st = items[i].header!; break; } }
        setState(() {
          plan.states[moved.group!] = st;
          plan.order..clear()..addAll([for (final it in items) if (it.group != null) it.group!]);
        });
      },
      itemBuilder: (context, i) {
        final it = items[i];
        if (it.header != null) return _header(context, it.header!, musclesIn(plan.states, it.header!, plan.order).length, key: ValueKey('h${it.header}'));
        return _tile(context, i, it.group!, current, map, rhythm, now, chosen, key: ValueKey('g${it.group}'));
      },
    );
  }

  Widget _header(BuildContext context, MuscleState st, int count, {required Key key}) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final blurb = st == MuscleState.available && plan.manual ? 'Not worked when manual.' : muscleStateBlurb[st]!;
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
      child: Row(children: [
        Icon(muscleStateIcon(st), size: 14, color: st == MuscleState.forced ? du.accentText : du.inkTertiary),
        const SizedBox(width: 6),
        Text(muscleStateLabel[st]!.toUpperCase(), style: t.labelSmall?.copyWith(color: st == MuscleState.forced ? du.accentText : null)),
        const SizedBox(width: 8),
        Expanded(child: Text(count == 0 ? 'Drop a muscle here. $blurb' : blurb, style: t.labelSmall, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  /// A muscle's tag and clock in words: "active · last worked 4 workouts ago", "passive · helped last workout", "ignored".
  String _tagText(BuildContext context, String g, Rhythm r) {
    final goal = context.store.state.goal!;
    return switch (goal.tagOf(g)) {
      MuscleTag.active => 'active · ${r.dueText(g)}',
      MuscleTag.passive => 'passive · ${r.helpedText(g)}',
      MuscleTag.ignored => 'ignored',
    };
  }

  Widget _tile(BuildContext context, int index, String g, StrainPoints current, MuscleMap map, Rhythm rhythm, DateTime now, Set<String> chosen, {required Key key}) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final st = plan.states[g]!;
    final on = selected.contains(g);
    final fill = on ? Color.lerp(musclePlate, muscleSelect, 0.85)! : muscleSwatch(st, chosen: chosen.contains(g), primary: musclePrimary);
    final worked = st == MuscleState.forced || (st == MuscleState.available && chosen.contains(g));
    return ReorderableDelayedDragStartListener(
      key: key,
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: AnimatedContainer(
          duration: m(context, durBase),
          decoration: BoxDecoration(
            color: st == MuscleState.excluded ? du.sunk : du.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: on ? muscleSelect : du.line, width: on ? 1.5 : 0.6),
          ),
          child: ListTile(
            onTap: () => _toggle(g),
            contentPadding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
            leading: Container(width: 22, height: 22, decoration: BoxDecoration(color: fill, shape: BoxShape.circle, border: Border.all(color: du.line, width: 0.6))),
            title: Text(muscleTitle(g), style: t.bodyLarge?.copyWith(color: st == MuscleState.excluded ? du.inkSecondary : du.ink)),
            subtitle: Text('${worked ? 'in today\'s workout · ' : ''}${_tagText(context, g, rhythm)} · ${muscleStrainText(current, map, g, now)}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(muscleStateIcon(st), size: 16, color: st == MuscleState.forced ? du.accentText : du.inkTertiary),
              ReorderableDragStartListener(index: index, child: Padding(padding: const EdgeInsets.fromLTRB(10, 12, 8, 12), child: Icon(LucideIcons.gripVertical, size: 18, color: du.inkTertiary))),
            ]),
          ),
        ),
      ),
    );
  }
}
