// Goal editor: the user's own goal in plain words. Templates and programs are suggestions that fill it. Rep bands are a
// list, each tagged with the difficulties it applies to; the exercises, sets and hard-day pushes are three-point
// calibrations (the fewest, the ideal, the most); then spare minutes, cardio and stretching, movement days.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/index.dart';
import '../data/library.dart';
import '../data/model.dart';
import 'app.dart';
import 'motion.dart';
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
      return Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(editing ? 'Rep range' : 'Add a rep range', style: t.titleMedium),
        const SizedBox(height: 4),
        Text('Under the floor says lower the weight; the top or more says go up. The weight follows the band, so the level never changes with this.', style: t.bodySmall),
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
        Text('A difficulty with several ranges cycles through them by workout.', style: t.bodySmall),
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
    final du = context.du;
    final program = g.program;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: nameCtl,
        decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(LucideIcons.pencil, size: 18)),
        onChanged: (v) => _set((x) => x.name = v.trim().isEmpty ? 'My goal' : v.trim()),
      ),
      const SizedBox(height: 12),
      Text('Fill from a template', style: t.labelMedium),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final tpl in goals.values)
          Tooltip(message: tpl.explain.join(' · '), child: ActionChip(avatar: Icon(goalIcon(tpl.id), size: 16), label: Text(tpl.name), onPressed: () => _fill(tpl))),
      ]),
      const SizedBox(height: 4),
      Text('A template sets everything below. Change what you like after.', style: t.bodySmall),
      const SizedBox(height: 16),
      const SectionHeader('Rep ranges', icon: LucideIcons.repeat),
      Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < g.bands.length; i++)
          Pressable(
            onTap: () => _editBand(context, i),
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
              const IconBadge(LucideIcons.repeat, size: 32),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${rangeText(g.bands[i].range)} reps', style: t.bodyLarge),
                Text('${[3, 2, 1].where(g.bands[i].difficulties.contains).map((d) => difficultyName[d]!.toLowerCase()).join(', ')} exercises${_cycles(g, i)}', style: t.bodySmall),
              ])),
              Icon(LucideIcons.chevronRight, size: 18, color: du.inkTertiary),
            ])),
          ),
        if (g.bands.length < maxBands)
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => _editBand(context, g.bands.length), icon: const Icon(LucideIcons.plus, size: 16), label: const Text('Add a rep range'))),
        const SizedBox(height: 4),
        Text('${program != null ? '${programLabel[program]!}, from the template. ' : ''}Tap a range to change its reps or which exercises it applies to. Same strength either way: the weight follows the reps.', style: t.bodySmall),
      ])),
      const SizedBox(height: 16),
      const SectionHeader('A workout plans', icon: LucideIcons.layers),
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
        Text('Reach the floor of the range on every set at the next level and it is your level that day.', style: t.bodySmall),
        const SizedBox(height: 6),
        ChoiceRow<Spare>(label: 'Spare minutes go to', value: g.spare, options: {for (final v in Spare.values) v: spareLabel[v]!}, hint: 'Once the planned exercises fit. Growth to the most needs this on more exercises. The feel tap after a workout can flip this for you.', onChanged: (v) => _set((x) => x.spare = v)),
      ])),
      const SizedBox(height: 16),
      const SectionHeader('Cardio and stretching', icon: LucideIcons.footprints),
      Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ValueSlider(label: 'Cardio', value: g.cardioPct, min: 0, max: 50, step: 5, icon: LucideIcons.footprints, display: (v) => v == 0 ? 'none' : '$v % of every workout', onChanged: (v) => _set((x) => x.cardioPct = v)),
        ValueSlider(label: 'Stretching', value: g.stretchPct, min: 0, max: 30, step: 5, icon: LucideIcons.stretchHorizontal, display: (v) => v == 0 ? 'none' : '$v % of every workout', onChanged: (v) => _set((x) => x.stretchPct = v)),
        Text('Reserved at the end of every workout, stretching last. Cardio also takes any minutes the strength exercises leave.', style: t.bodySmall),
        const SizedBox(height: 10),
        ChoiceRow<int>(
          label: 'A cardio or stretching day after every',
          value: g.moveEvery, options: const {0: 'never', 1: '1', 2: '2', 3: '3', 4: '4', 5: '5', 6: '6'},
          hint: 'strength workouts', onChanged: (v) => _set((x) => x.moveEvery = v),
        ),
      ])),
      const SizedBox(height: 16),
      const SectionHeader('Muscles over the week', icon: LucideIcons.personStanding),
      Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ValueSlider(label: 'Look back', value: g.lookBackDays, min: lookBackMin, max: lookBackMax, step: 1, icon: LucideIcons.calendarDays, display: (v) => '$v days', onChanged: (v) => _set((x) => x.lookBackDays = v)),
        ValueSlider(label: 'Sets per muscle', value: g.targetSets(widget.daysPerWeek), min: setsTargetMin, max: setsTargetMax, step: 1, icon: LucideIcons.repeat, display: (v) => '$v sets${g.setsTarget == null ? ', from your days a week' : ''}', onChanged: (v) => _set((x) => x.setsTarget = v)),
        Text('Each muscle aims for this many sets over the look-back. A main muscle counts a set, a helper half. The workout goes to the muscles that are ready and furthest behind.', style: t.bodySmall),
        const SizedBox(height: 10),
        ChoiceRow<Explore>(label: 'Try new exercises', value: g.explore, options: {for (final v in Explore.values) v: exploreLabel[v]!}, hint: 'How often an exercise you have not rated takes a turn from a practised one: one in ${exploreRun[g.explore]} appearances, in the last place, never on a hard day.', onChanged: (v) => _set((x) => x.explore = v)),
        const Divider(height: 16),
        Text('Emphasis', style: t.labelMedium),
        Text('More keeps a muscle behind for longer, so it is picked more often and goes first. Less is half, never none.', style: t.bodySmall),
        const SizedBox(height: 6),
        for (final grp in trackedMuscles)
          Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
            SizedBox(width: 120, child: Text(muscleTitle(grp), style: t.bodyMedium)),
            Expanded(child: Segmented<int>(value: g.emphasisOf(grp), options: {for (final e in const [-1, 0, 1]) e: emphasisLabel[e]!}, onChanged: (v) => _set((x) => x.setEmphasis(grp, v)))),
          ])),
      ])),
      const SizedBox(height: 8),
      Row(children: [
        Icon(LucideIcons.shield, size: 14, color: du.inkTertiary),
        const SizedBox(width: 6),
        Expanded(child: Text('Exercises keep their levels whatever you change here. Changes apply from the next workout.', style: t.bodySmall)),
      ]),
    ]);
  }
}
