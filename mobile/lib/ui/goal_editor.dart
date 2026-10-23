// Goal editor (UI.md): the user's own goal in plain words. A name, a template to fill from, the rep ranges (a list,
// each tagged with the difficulties it applies to), three bands (exercises, sets, hard-day pushes), spare minutes,
// cardio and stretching shares, movement days, and the muscles.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/library.dart';
import '../data/model.dart';
import 'app.dart';
import 'muscle_tags.dart';
import 'theme.dart';
import 'widgets.dart';

const difficultyName = {3: 'Hard', 2: 'Medium', 1: 'Easy'};

class GoalEditor extends StatefulWidget {
  const GoalEditor({super.key, required this.goal, required this.onChanged, this.daysPerWeek = 3});
  final GoalConfig goal;
  final ValueChanged<GoalConfig> onChanged;
  final int daysPerWeek;
  @override
  State<GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<GoalEditor> {
  late final nameCtl = TextEditingController(text: widget.goal.name);

  void _set(void Function(GoalConfig g) fn) {
    fn(widget.goal);
    widget.onChanged(widget.goal);
    setState(() {});
  }

  void _fill(Goal tpl) => _set((x) { x.fill(tpl); nameCtl.text = tpl.name; });

  Future<void> _editBand(BuildContext context, int i) async {
    final g = widget.goal;
    final editing = i < g.bands.length;
    var r = editing ? g.bands[i].range : middleReps;
    final tags = editing ? {...g.bands[i].difficulties} : <int>{3};
    final result = await showSheet<Band?>(context, StatefulBuilder(builder: (context, setSheet) {
      final t = Theme.of(context).textTheme;
      return Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(editing ? 'Rep range' : 'Add a rep range', style: t.titleLarge),
        const SizedBox(height: 4),
        const QuietLine('Under the floor says lower the weight; the top or more says go up.', icon: LucideIcons.info),
        const SizedBox(height: 12),
        RangeBand(label: rangeText(r), value: r, min: 1, max: 30, onChanged: (v) => setSheet(() => r = v)),
        const SizedBox(height: 4),
        Wrap(spacing: 8, children: [
          for (final e in Expression.values)
            ActionChip(label: Text('${expressionLabel[e]} ${rangeText(expressionRange[e]!)}'), onPressed: () => setSheet(() => r = expressionRange[e]!)),
        ]),
        const SizedBox(height: 14),
        Text('Applies to', style: t.bodyLarge),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          for (final d in [3, 2, 1])
            FilterChip(label: Text('${difficultyName[d]} exercises'), selected: tags.contains(d), onSelected: (v) => setSheet(() => v ? tags.add(d) : tags.remove(d))),
        ]),
        const SizedBox(height: 4),
        const QuietLine('A difficulty with several ranges cycles through them by workout.', icon: LucideIcons.info),
        const SizedBox(height: 14),
        Row(children: [
          if (editing)
            TextButton.icon(onPressed: () => Navigator.pop(context, Band(const RepRange(0, 0), const [])), icon: const Icon(LucideIcons.trash2, size: 16), label: const Text('Remove')),
          const Spacer(),
          FilledButton(onPressed: tags.isEmpty ? null : () => Navigator.pop(context, Band(r, tags)), child: const Text('Done')),
        ]),
      ]));
    }));
    if (result == null) return;
    _set((x) {
      if (result.range.lo == 0) { x.bands.removeAt(i); return; }
      if (editing) { x.bands[i] = result; } else { x.bands.add(result); }
    });
  }

  /// " · cycles with 8 to 12" when another range shares a difficulty with this one.
  String _cycles(GoalConfig g, int i) {
    final others = <String>{};
    for (final d in g.bands[i].difficulties) {
      for (var k = 0; k < g.bands.length; k++) { if (k != i && g.bands[k].difficulties.contains(d)) others.add(rangeText(g.bands[k].range)); }
    }
    return others.isEmpty ? '' : ' · cycles with ${others.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.goal;
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: nameCtl,
        decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(LucideIcons.pencil, size: 18)),
        onChanged: (v) => _set((x) => x.name = v.trim().isEmpty ? 'My goal' : v.trim()),
      ),
      const SizedBox(height: 14),
      Text('Fill from a template', style: t.labelMedium),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final tpl in goals.values)
          Tooltip(message: tpl.explain.join(' · '), child: ActionChip(avatar: Icon(goalIcon(tpl.id), size: 16), label: Text(tpl.name), onPressed: () => _fill(tpl))),
      ]),
      const SizedBox(height: 20),
      const SectionHeader('Rep ranges', icon: LucideIcons.repeat),
      Panel(padding: EdgeInsets.zero, clip: true, child: Column(children: [
        for (var i = 0; i < g.bands.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          Row1(
            icon: LucideIcons.repeat,
            title: Text('${rangeText(g.bands[i].range)} reps'),
            subtitle: '${[3, 2, 1].where(g.bands[i].difficulties.contains).map((d) => difficultyName[d]!.toLowerCase()).join(', ')} exercises${_cycles(g, i)}',
            onTap: () => _editBand(context, i),
          ),
        ],
        if (g.bands.length < maxBands) ...[
          const Divider(height: 1),
          Row1(icon: LucideIcons.plus, title: const Text('Add a rep range'), chevron: false, onTap: () => _editBand(context, g.bands.length)),
        ],
      ])),
      const SizedBox(height: 24),
      const SectionHeader('Each workout', icon: LucideIcons.layers),
      Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TriBand(
          label: 'Different exercises', icon: LucideIcons.layers, value: g.exercises, min: exercisesMin, max: exercisesMax,
          hints: (min: 'never fewer, unless the minutes cannot hold even that at the fewest sets', ideal: 'the sweet spot; a little fewer or more as the minutes allow', max: 'only on long workouts and hard days'),
          onChanged: (v) => _set((x) => x.exercises = v),
        ),
        const Divider(height: 16),
        TriBand(
          label: 'Working sets', icon: LucideIcons.repeat, value: g.sets, min: setsMin, max: setsMax,
          hints: (min: 'never fewer; a tight day drops exercises before sets', ideal: 'your usual; this is the working level that is judged', max: 'only on long workouts and hard days, after the exercises are in'),
          onChanged: (v) => _set((x) => x.sets = v),
        ),
        const Divider(height: 16),
        TriBand(
          label: 'Hard day: next level on', icon: LucideIcons.zap, value: g.pushes, min: pushesMin, max: pushesMax,
          hints: (min: 'on a tight day', ideal: 'on a usual hard day, hardest exercises first', max: 'on a long hard day'),
          onChanged: (v) => _set((x) => x.pushes = v),
        ),
        const Divider(height: 16),
        ChoiceRow<Spare>(label: 'Spare minutes go to', value: g.spare, options: {for (final v in Spare.values) v: spareLabel[v]!}, onChanged: (v) => _set((x) => x.spare = v)),
      ])),
      const SizedBox(height: 24),
      const SectionHeader('Cardio and stretching', icon: LucideIcons.footprints),
      Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ValueSlider(label: 'Cardio', value: g.cardioPct, min: 0, max: 50, step: 5, icon: LucideIcons.footprints, display: (v) => v == 0 ? 'none' : '$v % of every workout', onChanged: (v) => _set((x) => x.cardioPct = v)),
        ValueSlider(label: 'Stretching', value: g.stretchPct, min: 0, max: 30, step: 5, icon: LucideIcons.stretchHorizontal, display: (v) => v == 0 ? 'none' : '$v % of every workout', onChanged: (v) => _set((x) => x.stretchPct = v)),
        const Divider(height: 16),
        ValueSlider(
          label: 'A movement day after every', value: g.moveEvery, min: 0, max: 6, icon: LucideIcons.calendarDays,
          display: (v) => v == 0 ? 'never' : v == 1 ? 'workout' : '$v workouts', onChanged: (v) => _set((x) => x.moveEvery = v),
        ),
      ])),
      const SizedBox(height: 24),
      const SectionHeader('Muscles', icon: LucideIcons.personStanding),
      Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        MuscleTags(goal: g, onChanged: () => _set((_) {})),
        const Divider(height: 20),
        ChoiceRow<Explore>(label: 'Try new exercises', value: g.explore, options: {for (final v in Explore.values) v: exploreLabel[v]!}, onChanged: (v) => _set((x) => x.explore = v)),
      ])),
      const SizedBox(height: 12),
      const QuietLine('Levels stay where they are. Changes apply from the next workout.', icon: LucideIcons.shield),
    ]);
  }
}
