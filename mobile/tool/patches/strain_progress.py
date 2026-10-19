# Progress shows the strain muscle map of current strain points, a strip per muscle in the three shades, and opens the
# strain points timeline.
import pathlib


def edit(path, pairs):
    p = pathlib.Path(path)
    t = p.read_bytes().decode().replace('\r\n', '\n')
    for old, new in pairs:
        assert t.count(old) == 1, (path, old[:90])
        t = t.replace(old, new)
    p.write_bytes(t.replace('\n', '\r\n').encode())


edit('lib/ui/progress.dart', [
    ("""import '../logic/muscles.dart';
""", """import '../logic/levels.dart';
import '../logic/muscle_map.dart';
import '../logic/person.dart';
"""),
    ("""import 'motion.dart';
""", """import 'motion.dart';
import 'strain_timeline.dart';
"""),
    ("""    final worked = recentWork(s, now);
    final last = lastWorked(s);
    const days = 14;""", """    final muscleMap = MuscleMap(s);
    final current = muscleMap.currentStrainPoints(now);
    final last = muscleMap.lastWorked();
    const days = 14;
    final strip = muscleMap.strainPointsTimeline(now.subtract(const Duration(days: days - 1)), now);"""),
    ("""        const SectionHeader('Muscles, last two weeks', icon: LucideIcons.personStanding),
        Panel(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 8), child: Row(children: [
            MuscleFigure(highlight: worked, height: 190, keyLabels: const ['worked hard', 'worked', 'fading'], expandable: true, title: 'Muscles, last two weeks',
                detail: (h) => _muscleDetail(h, worked, last, now)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_muscleSummary(worked, last, now), style: t.bodyMedium),
              const SizedBox(height: 8),
              Text('Filled by how much was done and how long ago, fading to nothing over $muscleFadeDays days. A faded muscle is ready for work.', style: t.bodySmall),
            ])),
          ])),
          const Divider(),
          for (final g in trackedMuscles)
            Padding(padding: const EdgeInsets.fromLTRB(16, 7, 16, 7), child: Row(children: [
              SizedBox(width: 120, child: Text(muscleTitle(g), style: t.bodyMedium)),
              Expanded(child: _Strip(dayStrip(s, g, now, days: days))),
              const SizedBox(width: 10),
              SizedBox(width: 78, child: Text(agoText(last[g], now), style: t.labelSmall?.copyWith(color: (worked[g] ?? 0) > 0 ? du.accentText : null), textAlign: TextAlign.right)),
            ])),""", """        SectionHeader('Muscle strain', icon: LucideIcons.personStanding, trailing: TextButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StrainTimelineScreen())),
          icon: const Icon(LucideIcons.history, size: 16),
          label: const Text('Timeline'),
        )),
        Panel(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 8), child: Row(children: [
            MuscleFigure(highlight: current.byMuscle, height: 190, keyLabels: const ['high strain', 'medium', 'low'], expandable: true, title: 'Muscle strain',
                detail: (h) => _muscleDetail(h, muscleMap, current, last, now)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_muscleSummary(current, muscleMap, now), style: t.bodyMedium),
              const SizedBox(height: 8),
              Text('Strain points: each set gives its main muscles 0.20 and its helpers 0.10, up to 1.00 a workout. A third comes off each day, one shade at a time.', style: t.bodySmall),
            ])),
          ])),
          const Divider(),
          for (final g in trackedMuscles)
            Padding(padding: const EdgeInsets.fromLTRB(16, 7, 16, 7), child: Row(children: [
              SizedBox(width: 120, child: Text(muscleTitle(g), style: t.bodyMedium)),
              Expanded(child: StrainStrip([for (final d in strip) d.points[g]])),
              const SizedBox(width: 10),
              SizedBox(width: 78, child: Text(agoText(last[g], now), style: t.labelSmall?.copyWith(color: current.strainFree(g) ? null : du.ink), textAlign: TextAlign.right)),
            ])),"""),
    ("""  /// For a tapped muscle: when it was last worked and how far that has faded.
  String? _muscleDetail(MuscleHit h, Map<String, double> worked, Map<String, DateTime?> last, DateTime now) {
    if (!last.containsKey(h.name)) return null;
    final at = last[h.name];
    if (at == null) return 'Not worked yet.';
    final w = worked[h.name] ?? 0;
    return 'Last worked ${agoText(at, now)}${w >= 0.5 ? ', still recovering' : w > 0 ? ', mostly faded' : ', ready for work'}.';
  }

  String _muscleSummary(Map<String, double> worked, Map<String, DateTime?> last, DateTime now) {
    final hot = worked.entries.where((x) => x.value >= 0.5).map((x) => x.key.toLowerCase()).toList();
    final ready = worked.entries.where((x) => x.value < 0.2).map((x) => x.key.toLowerCase()).toList();
    if (hot.isEmpty && ready.length == worked.length) return 'Everything is rested and ready.';
    final parts = <String>[];
    if (hot.isNotEmpty) parts.add('${hot.length <= 3 ? hot.join(', ') : '${hot.length} muscles'} worked lately');
    if (ready.isNotEmpty) parts.add('${ready.length <= 3 ? ready.join(', ') : '${ready.length} muscles'} ready for work');
    final line = parts.join('; ');
    return '${line.replaceRange(0, 1, line[0].toUpperCase())}.';""", """  /// For a tapped muscle: its strain points now, the day it will be strain-free, and when it was last worked.
  String? _muscleDetail(MuscleHit h, MuscleMap muscleMap, StrainPoints current, Map<String, DateTime?> last, DateTime now) {
    if (!last.containsKey(h.name)) return null;
    final at = last[h.name];
    if (at == null) return 'Not worked yet.';
    final strain = current.strainFree(h.name)
        ? 'Strain-free.'
        : '${strainPointsText(current[h.name])} strain points, strain-free ${dayText(muscleMap.strainFreeOn(h.name, now), now)}.';
    return '$strain Last worked ${agoText(at, now)}.';
  }

  /// The muscles carrying strain, most first, and how many are strain-free.
  String _muscleSummary(StrainPoints current, MuscleMap muscleMap, DateTime now) {
    if (current.isEmpty) return 'Every muscle is strain-free.';
    final strained = current.ranked();
    final free = trackedMuscles.length - strained.length;
    final names = strained.length <= 3 ? strained.join(', ') : '${strained.take(2).join(', ')} and ${strained.length - 2} more';
    final line = '$names carrying strain${free > 0 ? '; $free muscle${free == 1 ? '' : 's'} strain-free' : ''}';
    return '${line.replaceRange(0, 1, line[0].toUpperCase())}.';"""),
    ("""class _Strip extends StatelessWidget {
  const _Strip(this.values);
  final List<double> values;
  @override
  Widget build(BuildContext context) {
    final du = context.du;
    final top = values.fold(0.0, (a, v) => v > a ? v : a);
    return Row(children: [
      for (var i = 0; i < values.length; i++)
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              color: values[i] <= 0 ? du.sunk : Color.lerp(du.accentLine, du.accentStrong, top == 0 ? 0 : values[i] / top),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        )),
    ]);
  }
}""", """/// Strain points over days, one cell a day, oldest first, each in its shade of the strain red. [selected] outlines one.
class StrainStrip extends StatelessWidget {
  const StrainStrip(this.values, {super.key, this.height = 14, this.selected, this.marks = const {}});
  final List<double> values;
  final double height;
  final int? selected;
  /// Days with a workout, marked with a dot under the cell.
  final Set<int> marks;
  @override
  Widget build(BuildContext context) {
    final du = context.du;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < values.length; i++)
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              height: height,
              decoration: BoxDecoration(
                color: strainOpacity(values[i]) == 0 ? du.sunk : Color.lerp(du.sunk, strainRed, strainOpacity(values[i])),
                borderRadius: BorderRadius.circular(3),
                border: selected == i ? Border.all(color: du.ink, width: 1.5) : null,
              ),
            ),
            if (marks.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 4), child: Container(
                width: 4, height: 4,
                decoration: BoxDecoration(color: marks.contains(i) ? du.inkSecondary : Colors.transparent, shape: BoxShape.circle),
              )),
          ]),
        )),
    ]);
  }
}"""),
])
