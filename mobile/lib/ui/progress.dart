// Progress: workouts per month, the muscles worked lately and when, level growth per exercise with a page that shows
// it as weights and versions over time. Nothing that resets to zero.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/index.dart';
import '../data/library.dart';
import '../data/model.dart';
import '../logic/after.dart';
import '../logic/muscles.dart';
import 'app.dart';
import 'muscle_figure.dart';
import 'catalog.dart';
import 'exercise_card.dart';
import 'motion.dart';
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
    final worked = recentWork(s, now);
    final last = lastWorked(s);
    const days = 14;
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
        const SizedBox(height: 12),
        Panel(child: Row(children: [
          Expanded(child: StatTile(label: 'Days active this month', value: '${daysActiveThisMonth(s, now)}', icon: LucideIcons.circleCheck)),
          Expanded(child: StatTile(label: 'Workouts, all time', value: '${s.sessions.length}', icon: LucideIcons.history)),
        ])),
        const SizedBox(height: 20),
        const SectionHeader('Muscles, last two weeks', icon: LucideIcons.personStanding),
        Panel(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 8), child: Row(children: [
            MuscleFigure(highlight: byDatasetGroup(worked), height: 190, keyLabels: const ('worked lately', 'fading'), expandable: true, title: 'Muscles, last two weeks',
                detail: (h) => _muscleDetail(h, worked, last, now)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_muscleSummary(worked, last, now), style: t.bodyMedium),
              const SizedBox(height: 8),
              Text('Filled by how much was done and how long ago, fading to nothing over $muscleFadeDays days. A faded group is ready for work.', style: t.bodySmall),
            ])),
          ])),
          const Divider(),
          for (final g in muscleGroups)
            Padding(padding: const EdgeInsets.fromLTRB(16, 7, 16, 7), child: Row(children: [
              SizedBox(width: 92, child: Text(g, style: t.bodyMedium)),
              Expanded(child: _Strip(dayStrip(s, g, now, days: days))),
              const SizedBox(width: 10),
              SizedBox(width: 78, child: Text(agoText(last[g], now), style: t.labelSmall?.copyWith(color: (worked[g] ?? 0) > 0 ? du.accentText : null), textAlign: TextAlign.right)),
            ])),
          Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 12), child: Row(children: [
            const SizedBox(width: 92),
            Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('$days days ago', style: t.labelSmall), Text('today', style: t.labelSmall)])),
            const SizedBox(width: 88),
          ])),
        ])),
        const SizedBox(height: 20),
        SectionHeader('Levels, last 30 days', icon: LucideIcons.trendingUp, trailing: trendGroups.isEmpty ? null : const IndexButton()),
        Panel(padding: EdgeInsets.zero, child: Column(children: [
          if (trendGroups.isEmpty) const ListTile(leading: IconBadge(LucideIcons.hourglass, size: 36), title: Text('Nothing yet'), subtitle: Text('Levels move after normal and hard workouts.')),
          for (final g in trendGroups) ...[
            Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Align(alignment: Alignment.centerLeft, child: Text(g.key, style: t.labelLarge?.copyWith(color: du.accentText)))),
            for (final e in g.value) _levelRow(context, s, e, trend[e.id]!, now),
          ],
        ])),
        const SizedBox(height: 20),
        const SectionHeader('Recent workouts', icon: LucideIcons.history),
        Panel(padding: EdgeInsets.zero, child: Column(children: [
          if (recent.isEmpty) const ListTile(leading: IconBadge(LucideIcons.calendarDays, size: 36), title: Text('No workouts yet')),
          for (final x in recent)
            ListTile(
              leading: IconBadge(x.type == 'lift' ? LucideIcons.dumbbell : moveIcon(x.kind), size: 36),
              title: Text('${x.name} · ${energyLabel[x.energy]!.toLowerCase()} · ${x.timeMinutes} min${x.circuit ? ' · circuit' : ''}'),
              subtitle: Text('${_date(x.endedAt)} · ${x.note}'),
              isThreeLine: x.note.length > 40,
            ),
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
    final change = from == null || to == null ? '' : from.rung == to.rung ? to.label : '${from.label} → ${to.label}';
    return ListTile(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseProgressScreen(e.id))),
      leading: IconBadge(exerciseIcon(e), size: 36, accent: delta > 0),
      title: Text(e.name),
      subtitle: Text(change),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(delta > 0 ? LucideIcons.arrowUpRight : delta < 0 ? LucideIcons.trendingDown : LucideIcons.minus, size: 16, color: delta > 0 ? du.accentText : du.inkSecondary),
        const SizedBox(width: 4),
        Text(delta > 0 ? '+$delta' : delta == 0 ? 'holding' : '$delta', style: t.labelLarge?.copyWith(color: delta > 0 ? du.accentText : du.inkSecondary)),
        const SizedBox(width: 6),
        Icon(LucideIcons.chevronRight, size: 16, color: du.inkTertiary),
      ]),
    );
  }

  /// For a tapped muscle: when its group was last worked and how far that has faded.
  String? _muscleDetail(MuscleHit h, Map<String, double> worked, Map<String, DateTime?> last, DateTime now) {
    final g = appGroupOf(h.dataset);
    if (g == null) return null;
    final at = last[g];
    if (at == null) return '$g · not worked yet.';
    final w = worked[g] ?? 0;
    return '$g · last worked ${agoText(at, now)}${w >= 0.5 ? ', still recovering' : w > 0 ? ', mostly faded' : ', ready for work'}.';
  }

  String _muscleSummary(Map<String, double> worked, Map<String, DateTime?> last, DateTime now) {
    final hot = worked.entries.where((x) => x.value >= 0.5).map((x) => x.key.toLowerCase()).toList();
    final ready = worked.entries.where((x) => x.value < 0.2).map((x) => x.key.toLowerCase()).toList();
    if (hot.isEmpty && ready.length == worked.length) return 'Everything is rested and ready.';
    final parts = <String>[];
    if (hot.isNotEmpty) parts.add('${hot.length <= 3 ? hot.join(', ') : '${hot.length} groups'} worked lately');
    if (ready.isNotEmpty) parts.add('${ready.length <= 3 ? ready.join(', ') : '${ready.length} groups'} ready for work');
    final line = parts.join('; ');
    return '${line.replaceRange(0, 1, line[0].toUpperCase())}.';
  }

  String _date(DateTime? d) => d == null ? '' : '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]}';
}

/// A row of days: a square per day, filled by how much that group was worked.
class _Strip extends StatelessWidget {
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
      appBar: AppBar(title: Text(ex.name), actions: [
        TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseCardScreen(ex.id))), icon: const Icon(LucideIcons.bookOpen, size: 18), label: const Text('Card')),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
        if (first == null || nowP == null)
          const Panel(child: Text('Not practised yet. The first workout sets the starting level.'))
        else ...[
          Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(growthText(ex, first, nowP).replaceRange(0, 1, growthText(ex, first, nowP)[0].toUpperCase()), style: t.titleLarge),
            const SizedBox(height: 4),
            Text('Since ${_long(first.at)} · $workouts workout${workouts == 1 ? '' : 's'} · $ups step${ups == 1 ? '' : 's'} up', style: t.bodySmall),
            const SizedBox(height: 16),
            SizedBox(height: 170, child: _LevelChart(h, du: du, text: t, loaded: ex.loaded)),
          ])),
          const SizedBox(height: 12),
          Panel(child: Row(children: [
            Expanded(child: StatTile(label: 'Started at', value: first.label, hint: _long(first.at), icon: LucideIcons.flag)),
            Expanded(child: StatTile(label: 'Now', value: nowP.label, hint: ex.loaded ? 'for ${todayRangeText(s, ex)}' : null, icon: LucideIcons.circleDot)),
          ])),
          const SizedBox(height: 20),
          const SectionHeader('Every workout', icon: LucideIcons.history),
          Panel(padding: EdgeInsets.zero, child: Column(children: [
            for (var i = h.length - 2; i >= 0; i--)
              ListTile(
                dense: true,
                leading: Icon(h[i].stepped ? LucideIcons.arrowUpRight : LucideIcons.minus, size: 18, color: h[i].stepped ? du.accentText : du.inkTertiary),
                title: Text(h[i].label, style: t.bodyMedium?.copyWith(color: h[i].stepped ? du.accentText : du.ink)),
                subtitle: Text(_long(h[i].at)),
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
