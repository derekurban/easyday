// The muscle picker: today's word on each muscle group (logic/muscle_plan.dart), chosen on the body. Every group is
// excluded, available or forced; a tap on a muscle cycles its group through the three. Excluded groups carrying
// strain keep their strain red, excluded strain-free ones go dim, forced ones go green, available ones stay plain.
// A stack of tabs at the bottom right switches between both figures, the front, the back, and a list: the groups
// under Forced, Available and Excluded, each tile draggable up and down and between the three. Done hands the
// states back to Today, which rebuilds the workout from them.
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

/// The dim an excluded, strain-free muscle is drawn in: a mid gray multiplied over the plate at about half strength.
const muscleDim = Color(0x8C7A7A7A);

IconData muscleStateIcon(MuscleState s) => switch (s) { MuscleState.forced => LucideIcons.pin, MuscleState.available => LucideIcons.circleDashed, MuscleState.excluded => LucideIcons.ban };

/// The fills for the figure from the states: muscle name -> strain points for the red (excluded groups only) and
/// muscle name -> tint (forced green, excluded strain-free dim). Available groups are left plain.
({Map<String, double> highlight, Map<String, Color> tint}) muscleFills(Map<String, MuscleState> states, StrainPoints current, Color forced) {
  final highlight = <String, double>{};
  final tint = <String, Color>{};
  for (final g in muscleGroups) {
    for (final m in musclesOf(g)) {
      switch (states[g]) {
        case MuscleState.forced:
          tint[m] = forced;
        case MuscleState.excluded:
          if (current.strainFree(m)) { tint[m] = muscleDim; } else { highlight[m] = current[m]; }
        default:
          break;
      }
    }
  }
  return (highlight: highlight, tint: tint);
}

/// What a group's strain is in words: "ready", or "medium strain, strain-free Thursday".
String groupStrainText(StrainPoints current, MuscleMap map, String group, DateTime now) {
  final shade = groupShade(current, group);
  if (shade == 0) return 'ready';
  var free = now;
  for (final m in musclesOf(group)) { final d = map.strainFreeOn(m, now); if (d.isAfter(free)) free = d; }
  return '${strainShadeLabels[strainShades - shade]} strain, strain-free ${dayText(free, now)}';
}

class MusclePickerScreen extends StatefulWidget {
  const MusclePickerScreen({super.key, required this.states, required this.order, required this.preview});
  final Map<String, MuscleState> states;
  /// The groups in the list's order, forced first.
  final List<String> order;
  /// The workout the states would build, for the line above Done.
  final Session Function(Map<String, MuscleState> states, List<String> order) preview;
  @override
  State<MusclePickerScreen> createState() => _MusclePickerScreenState();
}

class _MusclePickerScreenState extends State<MusclePickerScreen> {
  late Map<String, MuscleState> states = {...widget.states};
  late List<String> order = [...widget.order, for (final g in muscleGroups) if (!widget.order.contains(g)) g];
  String view = 'both';
  String? lastTapped;

  static const views = {'both': LucideIcons.columns2, 'front': LucideIcons.personStanding, 'back': LucideIcons.flipHorizontal2, 'list': LucideIcons.list};
  static const viewLabel = {'both': 'Both sides', 'front': 'Front', 'back': 'Back', 'list': 'List'};

  void _cycle(String group) {
    HapticFeedback.selectionClick();
    setState(() { states[group] = nextMuscleState(states[group] ?? MuscleState.available); lastTapped = group; });
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
    final session = widget.preview(states, order);
    final forced = groupsIn(states, MuscleState.forced, order);
    final defaults = defaultMuscleStates(current);
    final changed = muscleGroups.any((g) => states[g] != defaults[g]);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(LucideIcons.x, size: 22), tooltip: 'Close'),
        title: const Text('Muscles'),
        actions: [
          if (changed) TextButton.icon(onPressed: () => setState(() { states = defaultMuscleStates(current); lastTapped = null; }), icon: const Icon(LucideIcons.undo2, size: 16), label: const Text('Reset')),
        ],
      ),
      body: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: Stack(children: [
          Positioned.fill(child: AnimatedSwitcher(
            duration: m(context, durBase),
            child: view == 'list' ? _list(context, current, map, now) : _figure(context, current, map, now),
          )),
          Positioned(right: 12, bottom: 12, child: _tabs(context)),
        ])),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(color: du.bg, border: Border(top: BorderSide(color: du.line, width: 0.6))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnimatedSwitcher(
              duration: m(context, durBase),
              child: Column(key: ValueKey('${session.name}${session.exercises.length}${session.estMinutes}'), crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(session.exercises.isEmpty ? 'Nothing to work' : session.name, style: t.titleLarge),
                Text(session.exercises.isEmpty
                    ? 'Every muscle is excluded, or nothing here fits. Tap a muscle to make it available.'
                    : '${session.exercises.length} exercise${session.exercises.length == 1 ? '' : 's'} · about ${session.estMinutes} min${forced.isNotEmpty ? ' · ${listWords(forced.map((g) => g.toLowerCase()))} forced' : ''}', style: t.bodySmall),
              ]),
            ),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, height: 52, child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pop((states, order)),
              icon: const Icon(LucideIcons.check, size: 20),
              label: const Text('Done'),
            )),
          ]),
        ),
      ])),
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

  Widget _figure(BuildContext context, StrainPoints current, MuscleMap map, DateTime now) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final fills = muscleFills(states, current, du.accentStrong);
    final sides = view == 'both' ? const ['front', 'back'] : [view];
    final tapped = lastTapped;
    return LayoutBuilder(key: ValueKey(view), builder: (context, c) {
      final n = sides.length;
      // the tabs take the bottom right corner: on one side the figure leaves them room, on both it sits above them
      final height = min(c.maxHeight - 112, (c.maxWidth - 32 - 4 * (n - 1)) / (0.5 * n)).clamp(160.0, 1200.0).toDouble();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0), child: Wrap(spacing: 12, runSpacing: 4, children: [
          _swatch(context, Color.lerp(musclePlate, du.accentStrong, 0.75)!, 'Forced'),
          _swatch(context, musclePlate, 'Available'),
          _swatch(context, Color.lerp(musclePlate, strainRed, 2 / 3)!, 'Excluded, strained'),
          _swatch(context, Color.lerp(musclePlate, const Color(0xFF7A7A7A), 0.55)!, 'Excluded, strain-free'),
        ])),
        Expanded(child: Center(child: MuscleFigure(
          key: ValueKey('fig$view'),
          highlight: fills.highlight, tint: fills.tint, sides: sides, height: height, selectable: false, tooltip: false,
          onTap: (h) { if (h != null && muscleGroups.contains(muscleGroup(h.name))) _cycle(muscleGroup(h.name)); },
        ))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 72, 8),
          child: AnimatedSwitcher(
            duration: m(context, durBase),
            child: tapped == null
                ? Text('Tap a muscle to cycle it: excluded, available, forced.', key: const ValueKey('hint'), style: t.bodySmall)
                : Row(key: ValueKey('$tapped${states[tapped]}'), children: [
                    Icon(muscleStateIcon(states[tapped]!), size: 14, color: states[tapped] == MuscleState.forced ? du.accentText : du.inkSecondary),
                    const SizedBox(width: 6),
                    Expanded(child: Text('$tapped: ${muscleStateLabel[states[tapped]]!.toLowerCase()} · ${groupStrainText(current, map, tapped, now)}', style: t.bodySmall?.copyWith(color: du.ink))),
                  ]),
          ),
        ),
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

  /// The list: a header per state, the groups under each, every tile draggable up or down and across the headers.
  Widget _list(BuildContext context, StrainPoints current, MuscleMap map, DateTime now) {
    final share = shareOver(context.store.state, now);
    const sections = [MuscleState.forced, MuscleState.available, MuscleState.excluded];
    // the flat list the reorderable view shows: headers and tiles, each with a key
    final items = <({MuscleState? header, String? group})>[];
    for (final st in sections) {
      items.add((header: st, group: null));
      for (final g in groupsIn(states, st, order)) { items.add((header: null, group: g)); }
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
          states[moved.group!] = st;
          order = [for (final it in items) if (it.group != null) it.group!];
          lastTapped = moved.group;
        });
      },
      itemBuilder: (context, i) {
        final it = items[i];
        if (it.header != null) return _header(context, it.header!, groupsIn(states, it.header!, order).length, key: ValueKey('h${it.header}'));
        return _tile(context, i, it.group!, current, map, share, now, key: ValueKey('g${it.group}'));
      },
    );
  }

  Widget _header(BuildContext context, MuscleState st, int count, {required Key key}) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
      child: Row(children: [
        Icon(muscleStateIcon(st), size: 14, color: st == MuscleState.forced ? du.accentText : du.inkTertiary),
        const SizedBox(width: 6),
        Text(muscleStateLabel[st]!.toUpperCase(), style: t.labelSmall?.copyWith(color: st == MuscleState.forced ? du.accentText : null)),
        const SizedBox(width: 8),
        Expanded(child: Text(count == 0 ? 'Drop a muscle here. ${muscleStateBlurb[st]}' : muscleStateBlurb[st]!, style: t.labelSmall, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Widget _tile(BuildContext context, int index, String g, StrainPoints current, MuscleMap map, Share share, DateTime now, {required Key key}) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final st = states[g]!;
    final shade = groupShade(current, g);
    final fill = switch (st) {
      MuscleState.forced => Color.lerp(musclePlate, du.accentStrong, 0.75)!,
      MuscleState.excluded => shade == 0 ? Color.lerp(musclePlate, const Color(0xFF7A7A7A), 0.55)! : Color.lerp(musclePlate, strainRed, strainShadeOpacity[shade - 1])!,
      MuscleState.available => musclePlate,
    };
    return ReorderableDelayedDragStartListener(
      key: key,
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Panel(
          padding: EdgeInsets.zero,
          sunk: st == MuscleState.excluded,
          child: ListTile(
            onTap: () => _cycle(g),
            contentPadding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
            leading: Container(width: 22, height: 22, decoration: BoxDecoration(color: fill, shape: BoxShape.circle, border: Border.all(color: du.line, width: 0.6))),
            title: Text(g, style: t.bodyLarge?.copyWith(color: st == MuscleState.excluded ? du.inkSecondary : du.ink)),
            subtitle: Text('${groupStrainText(current, map, g, now)} · ${share.bandWord(g)}'),
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
