// Progress (UI.md): workouts per month and days active as facts, the strain muscle map with a strip per muscle, each
// muscle's rhythm, level growth per exercise with a page that shows it as weights and versions over time, and the
// recent workouts. Nothing that resets to zero.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/index.dart';
import '../data/library.dart';
import '../data/model.dart';
import '../logic/after.dart';
import '../logic/levels.dart';
import '../logic/muscle_map.dart';
import '../logic/person.dart';
import 'app.dart';
import 'muscle_figure.dart';
import 'catalog.dart';
import 'exercise_card.dart';
import 'motion.dart';
import 'muscle_tags.dart';
import 'strain_timeline.dart';
import 'theme.dart';
import 'widgets.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final s = store.state;
    final now = store.now;
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final months = sessionsPerMonth(s, now);
    final maxCount = months.fold(1, (a, mo) => mo.count > a ? mo.count : a);
    final trend = levelTrend(s, now);
    final ix = s.settings.index;
    final trendGroups = groupBy(trend.keys.where(exerciseById.containsKey).map((k) => exerciseById[k]!), ix,
        sort: (a, b) { final c = trend[b.id]!.compareTo(trend[a.id]!); return c != 0 ? c : a.name.compareTo(b.name); });
    final recent = s.sessions.reversed.take(8).toList();
    final muscleMap = MuscleMap(s);
    final current = muscleMap.currentStrainPoints(now);
    final last = muscleMap.lastWorked();
    const days = 14;
    final strip = muscleMap.strainPointsTimeline(now.subtract(const Duration(days: days - 1)), now);
    final g = s.goal!;
    final active = daysActiveThisMonth(s, now);
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        const SectionHeader('Workouts per month', icon: LucideIcons.calendarDays),
        Panel(child: SizedBox(
          height: 150,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < months.length; i++)
              Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('${months[i].count}', style: t.labelMedium),
                const SizedBox(height: 4),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: months[i].count / maxCount),
                  duration: m(context, durSlow + Duration(milliseconds: 40 * i)),
                  curve: easeSettle,
                  builder: (context, v, _) => Container(
                    height: 90 * v + 3, margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(color: months[i].count == 0 ? du.line : (i == months.length - 1 ? du.accentStrong : du.accentLine), borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(months[i].label, style: t.labelSmall?.copyWith(color: i == months.length - 1 ? du.accentText : null)),
              ])),
          ]),
        )),
        const SizedBox(height: 10),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Facts([
          Fact('$active day${active == 1 ? '' : 's'} active this month', icon: LucideIcons.circleCheck),
          Fact('${s.sessions.length} workout${s.sessions.length == 1 ? '' : 's'} all time', icon: LucideIcons.history),
        ])),
        const SizedBox(height: 24),
        SectionHeader('Muscle strain', icon: LucideIcons.personStanding, trailing: TextButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StrainTimelineScreen())),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          icon: const Icon(LucideIcons.history, size: 16),
          label: const Text('Timeline'),
        )),
        Panel(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 10), child: Row(children: [
            MuscleFigure(highlight: current.byMuscle, height: 150, keyLabels: const ['high strain', 'medium', 'low'], expandable: true, title: 'Muscle strain',
                detail: (h) => _muscleDetail(h, muscleMap, current, last, now)),
            const SizedBox(width: 16),
            Expanded(child: Text(_muscleSummary(current, muscleMap, now), style: t.bodyMedium)),
          ])),
          const Divider(),
          for (final g in trackedMuscles)
            Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 6), child: Row(children: [
              SizedBox(width: 116, child: Text(muscleTitle(g), style: t.bodySmall?.copyWith(color: du.ink), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Expanded(child: StrainStrip([for (final d in strip) d.points[g]], height: 12)),
              const SizedBox(width: 10),
              SizedBox(width: 78, child: Text(agoText(last[g], now), style: t.labelSmall?.copyWith(letterSpacing: 0, color: current.strainFree(g) ? null : du.ink), textAlign: TextAlign.right)),
            ])),
          Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 12), child: Row(children: [
            const SizedBox(width: 116),
            Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('$days days ago', style: t.labelSmall), Text('today', style: t.labelSmall)])),
            const SizedBox(width: 88),
          ])),
        ])),
        const SizedBox(height: 24),
        const SectionHeader('Rhythm', icon: LucideIcons.layers),
        Panel(padding: const EdgeInsets.symmetric(vertical: 4), child: MuscleTags(goal: g, onChanged: () => store.update((_) {}), figure: false)),
        const SizedBox(height: 24),
        SectionHeader('Levels, last 30 days', icon: LucideIcons.trendingUp, trailing: trendGroups.isEmpty ? null : const IndexButton()),
        Panel(padding: EdgeInsets.zero, clip: true, child: Column(children: [
          if (trendGroups.isEmpty) const Row1(icon: LucideIcons.hourglass, title: Text('Nothing yet'), subtitle: 'Levels move after normal and hard workouts.'),
          for (final g in trendGroups) ...[
            Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 2), child: Align(alignment: Alignment.centerLeft, child: Text(g.key, style: t.labelMedium))),
            for (final e in g.value) _levelRow(context, s, e, trend[e.id]!, now),
          ],
        ])),
        const SizedBox(height: 24),
        const SectionHeader('Recent workouts', icon: LucideIcons.history),
        Panel(padding: EdgeInsets.zero, clip: true, child: Column(children: [
          if (recent.isEmpty) const Row1(icon: LucideIcons.calendarDays, title: Text('No workouts yet')),
          for (var i = 0; i < recent.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Row1(
              icon: recent[i].type == 'lift' ? LucideIcons.dumbbell : moveIcon(recent[i].kind),
              title: Text(recent[i].name, overflow: TextOverflow.ellipsis),
              subtitle: '${_date(recent[i].endedAt)} · ${energyLabel[recent[i].energy]!.toLowerCase()} · ${recent[i].timeMinutes} min${recent[i].circuit ? ' · circuit' : ''}${recent[i].note.isEmpty ? '' : '\n${recent[i].note}'}',
              dense: true,
            ),
          ],
        ])),
      ]),
    );
  }

  Widget _levelRow(BuildContext context, AppState s, Exercise e, int delta, DateTime now) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final h = levelHistory(s, e);
    final since = now.subtract(const Duration(days: 30));
    final from = h.where((p) => !p.at.isBefore(since)).firstOrNull ?? (h.isEmpty ? null : h.first);
    final to = h.isEmpty ? null : h.last;
    final change = from == null || to == null ? null : from.rung == to.rung ? to.label : '${from.label} → ${to.label}';
    return Row1(
      icon: exerciseIcon(e),
      title: Text(e.name, overflow: TextOverflow.ellipsis),
      subtitle: change,
      dense: true,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(delta > 0 ? LucideIcons.arrowUpRight : delta < 0 ? LucideIcons.trendingDown : LucideIcons.minus, size: 16, color: delta > 0 ? du.accentText : du.inkSecondary),
        const SizedBox(width: 4),
        Text(delta > 0 ? '+$delta' : delta == 0 ? 'holding' : '$delta', style: t.labelLarge?.copyWith(color: delta > 0 ? du.accentText : du.inkSecondary)),
      ]),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseProgressScreen(e.id))),
    );
  }

  /// For a tapped muscle: its strain points now, the day it will be strain-free, and when it was last worked.
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
    return '${line.replaceRange(0, 1, line[0].toUpperCase())}.';
  }

  String _date(DateTime? d) => d == null ? '' : '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]}';
}

/// Strain points over days, one cell a day, oldest first, each in its shade as the key draws it. [selected] outlines one.
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
                color: strainOpacity(values[i]) == 0 ? du.sunk : Color.lerp(musclePlate, strainRed, strainOpacity(values[i])),
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
}

/// One exercise's growth: where it started, where it is, and every step between, as the weights and versions the user
/// actually lifted.
class ExerciseProgressScreen extends StatelessWidget {
  const ExerciseProgressScreen(this.exId, {super.key});
  final String exId;
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final s = store.state;
    final ex = exerciseById[exId];
    if (ex == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('This exercise no longer exists.')));
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final h = levelHistory(s, ex);
    final first = h.isEmpty ? null : h.first;
    final nowP = h.isEmpty ? null : h.last;
    final ups = h.where((p) => p.stepped).length;
    final workouts = h.length - 1;
    return Scaffold(
      appBar: AppBar(actions: [
        TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseCardScreen(ex.id))), icon: const Icon(LucideIcons.bookOpen, size: 18), label: const Text('Card')),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
        Text(ex.name, style: t.headlineLarge),
        const SizedBox(height: 8),
        if (first == null || nowP == null) ...[
          const FactLine('Not practised yet', icon: LucideIcons.hourglass),
          const SizedBox(height: 8),
          const QuietLine('The first workout sets the starting level.', icon: LucideIcons.info),
        ] else ...[
          FactLine(growthText(ex, first, nowP).replaceRange(0, 1, growthText(ex, first, nowP)[0].toUpperCase()), icon: ups > 0 ? LucideIcons.trendingUp : LucideIcons.minus, good: ups > 0),
          const SizedBox(height: 8),
          Facts([
            Fact('Since ${_long(first.at)}', icon: LucideIcons.flag),
            Fact('$workouts workout${workouts == 1 ? '' : 's'}', icon: LucideIcons.history),
            Fact('$ups step${ups == 1 ? '' : 's'} up', icon: LucideIcons.arrowUpRight, accent: ups > 0),
            if (ex.loaded) Fact('Now for ${todayRangeText(s, ex)}', icon: LucideIcons.repeat),
          ]),
          const SizedBox(height: 16),
          Panel(child: SizedBox(height: 170, child: _LevelChart(h, du: du, text: t, loaded: ex.loaded))),
          const SizedBox(height: 24),
          const SectionHeader('Every workout', icon: LucideIcons.history),
          Panel(padding: EdgeInsets.zero, clip: true, child: Column(children: [
            for (var i = h.length - 2; i >= 0; i--)
              Row1(
                icon: h[i].stepped ? LucideIcons.arrowUpRight : LucideIcons.minus,
                title: Text(h[i].label, style: TextStyle(color: h[i].stepped ? du.accentText : du.ink)),
                subtitle: _long(h[i].at),
                dense: true,
                trailing: h[i].stepped ? Text('stepped up', style: t.labelSmall?.copyWith(color: du.accentText)) : null,
              ),
          ])),
        ],
      ]),
    );
  }

  String _long(DateTime d) => '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]}';
}

String todayRangeText(AppState s, Exercise ex) {
  final r = s.goal!.rangeForDifficulty(ex.difficulty, 0);
  return '${s.ex[ex.id]?.repsOverride?.lo ?? r.lo} to ${s.ex[ex.id]?.repsOverride?.hi ?? r.hi} reps';
}

/// A step line of the level over the workouts, the last point being now. Labels at the first, the last and each step.
class _LevelChart extends StatelessWidget {
  const _LevelChart(this.points, {required this.du, required this.text, required this.loaded});
  final List<LevelPoint> points;
  final Du du;
  final TextTheme text;
  final bool loaded;
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _LevelPainter(points, du, text), size: Size.infinite);
}

class _LevelPainter extends CustomPainter {
  _LevelPainter(this.points, this.du, this.text);
  final List<LevelPoint> points;
  final Du du;
  final TextTheme text;
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final rungs = points.map((p) => p.rung).toList();
    final lo = rungs.reduce((a, b) => a < b ? a : b), hi = rungs.reduce((a, b) => a > b ? a : b);
    final span = (hi - lo).clamp(1, 1 << 30);
    const top = 22.0, bottom = 24.0, left = 8.0, right = 8.0;
    final w = size.width - left - right, hgt = size.height - top - bottom;
    double x(int i) => points.length == 1 ? left + w / 2 : left + w * i / (points.length - 1);
    double y(int r) => top + hgt * (1 - (r - lo) / span);
    // grid lines at every level
    for (var r = lo; r <= hi; r++) {
      canvas.drawLine(Offset(left, y(r)), Offset(size.width - right, y(r)), Paint()..color = du.line.withValues(alpha: 0.6)..strokeWidth = 0.6);
    }
    final path = Path()..moveTo(x(0), y(points[0].rung));
    for (var i = 1; i < points.length; i++) {
      path.lineTo(x(i), y(points[i - 1].rung));
      path.lineTo(x(i), y(points[i].rung));
    }
    final fill = Path.from(path)..lineTo(x(points.length - 1), top + hgt)..lineTo(x(0), top + hgt)..close();
    canvas.drawPath(fill, Paint()..color = du.accentSubtle);
    canvas.drawPath(path, Paint()..color = du.accentStrong..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeJoin = StrokeJoin.round);
    for (var i = 0; i < points.length; i++) {
      final p = Offset(x(i), y(points[i].rung));
      final big = i == 0 || i == points.length - 1 || points[i - 1].rung != points[i].rung;
      canvas.drawCircle(p, big ? 5 : 3, Paint()..color = big ? du.accentStrong : du.surface);
      canvas.drawCircle(p, big ? 5 : 3, Paint()..color = du.accentStrong..style = PaintingStyle.stroke..strokeWidth = 1.5);
      if (big) {
        final tp = TextPainter(text: TextSpan(text: points[i].label, style: text.labelSmall?.copyWith(color: du.accentText)), textDirection: TextDirection.ltr)..layout();
        var dx = p.dx - tp.width / 2;
        dx = dx.clamp(0, size.width - tp.width);
        tp.paint(canvas, Offset(dx, p.dy - 8 - tp.height));
      }
    }
    void date(int i, TextAlign align) {
      final d = points[i].at;
      final s = i == points.length - 1 ? 'now' : '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]}';
      final tp = TextPainter(text: TextSpan(text: s, style: text.labelSmall), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(align == TextAlign.left ? left : size.width - right - tp.width, size.height - tp.height));
    }
    date(0, TextAlign.left);
    if (points.length > 1) date(points.length - 1, TextAlign.right);
  }
  @override
  bool shouldRepaint(_LevelPainter o) => o.points != points || o.du != du;
}
