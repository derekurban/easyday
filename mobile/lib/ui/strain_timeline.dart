// The strain points timeline (MUSCLE_MAP.md): the strain muscle map at the end of any of the last thirty days. Drag
// along the days or step through them; workout days are marked. Tap a muscle and the days show that muscle alone.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/index.dart';
import '../logic/muscle_map.dart';
import '../logic/person.dart';
import 'app.dart';
import 'muscle_figure.dart';
import 'progress.dart';
import 'theme.dart';
import 'widgets.dart';

class StrainTimelineScreen extends StatefulWidget {
  const StrainTimelineScreen({super.key});
  @override
  State<StrainTimelineScreen> createState() => _StrainTimelineScreenState();
}

class _StrainTimelineScreenState extends State<StrainTimelineScreen> {
  int? index;       // the day shown; null is today
  String? muscle;   // the muscle the days show, when one is tapped

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final now = store.now;
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final days = MuscleMap(store.state).strainPointsTimeline(now.subtract(const Duration(days: strainTimelineDays - 1)), now);
    final i = (index ?? days.length - 1).clamp(0, days.length - 1);
    final day = days[i];
    void go(int to) => setState(() => index = to.clamp(0, days.length - 1));
    // the days: the tapped muscle's strain points, or the most strained muscle's that day
    final values = [for (final d in days) muscle != null ? d.points[muscle!] : d.points.byMuscle.values.fold(0.0, max)];
    final marks = {for (var k = 0; k < days.length; k++) if (days[k].workouts.isNotEmpty) k};
    final strained = day.points.ranked();
    return Scaffold(
      appBar: AppBar(title: const Text('Strain points timeline')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            IconButton(onPressed: i > 0 ? () => go(i - 1) : null, tooltip: 'Day before', icon: const Icon(LucideIcons.chevronLeft, size: 20)),
            Expanded(child: Column(children: [
              Text(_dayTitle(day.day, now), style: t.titleMedium),
              Text(day.workouts.isEmpty ? 'No workout' : day.workouts.map((w) => w.session.name).join(', '), style: t.bodySmall),
            ])),
            IconButton(onPressed: i < days.length - 1 ? () => go(i + 1) : null, tooltip: 'Day after', icon: const Icon(LucideIcons.chevronRight, size: 20)),
          ]),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, c) => Center(child: MuscleFigure(
            highlight: day.points.byMuscle, height: min(340.0, c.maxWidth - 8), keyLabels: const ['high strain', 'medium', 'low'],
            clearAfter: null, onTap: (h) => setState(() => muscle = h?.name),
            detail: (h) => _detail(day, h.name),
          ))),
          const SizedBox(height: 16),
          Text(muscle == null ? 'Most strained muscle each day' : '${muscleTitle(muscle!)} each day', style: t.labelLarge),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, c) {
            int at(double x) => (x / c.maxWidth * days.length).floor().clamp(0, days.length - 1);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => go(at(d.localPosition.dx)),
              onHorizontalDragUpdate: (d) => go(at(d.localPosition.dx)),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: StrainStrip(values, height: 28, selected: i, marks: marks)),
            );
          }),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('$strainTimelineDays days ago', style: t.labelSmall),
            Text('today', style: t.labelSmall),
          ]),
        ])),
        const SizedBox(height: 20),
        const SectionHeader('That day', icon: LucideIcons.calendarDays),
        Panel(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final w in day.workouts)
            ListTile(
              leading: const IconBadge(LucideIcons.dumbbell, size: 36),
              title: Text(w.session.name),
              subtitle: Text('Added ${_list(w.points)}.'),
            ),
          if (day.workouts.isEmpty)
            const ListTile(leading: IconBadge(LucideIcons.moon, size: 36), title: Text('No workout'), subtitle: Text('A third of a point came off every muscle.')),
          const Divider(),
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 14), child: Text(
            strained.isEmpty ? 'Every muscle strain-free at the end of the day.' : 'At the end of the day: ${_list(day.points)}.',
            style: t.bodyMedium?.copyWith(color: du.ink),
          )),
        ])),
      ]),
    );
  }

  /// For a tapped muscle: its strain points at the end of the day, and what that day's workouts gave it.
  String _detail(StrainDay day, String m) {
    final added = day.workouts.fold(0.0, (a, w) => a + w.points[m]);
    final end = day.points.strainFree(m) ? 'Strain-free at the end of the day.' : '${strainPointsText(day.points[m])} strain points at the end of the day.';
    return added > 0 ? '$end ${strainPointsText(min(strainPointsMax, added))} from that day\'s workout.' : end;
  }

  /// Strain points as words, most first: "chest 0.60, quads 0.60 and 4 more".
  String _list(StrainPoints p) {
    final ranked = p.ranked();
    final shown = ranked.take(4).map((m) => '$m ${strainPointsText(p[m])}').toList();
    final more = ranked.length - shown.length;
    if (more > 0) return '${shown.join(', ')} and $more more';
    return shown.length <= 1 ? shown.join() : '${shown.sublist(0, shown.length - 1).join(', ')} and ${shown.last}';
  }

  String _dayTitle(DateTime day, DateTime now) {
    final d = daysAgo(day, now);
    if (d == 0) return 'Today';
    if (d == 1) return 'Yesterday';
    const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${names[day.weekday - 1]} ${day.day} ${months[day.month - 1]}';
  }
}
