// Ranks, wherever the strength rating shows (logic/rating.dart): a rank's colour and badge, the rating as a number
// with its change, and the rating over time as a chart with the ranks drawn across it.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../logic/rating.dart';
import 'motion.dart';
import 'theme.dart';

/// The colour of a rank, from iron grey to champion magenta.
Color rankColor(int i) => const [Color(0xFF7A7F87), Color(0xFFB0763C), Color(0xFF8E99A4), Color(0xFFC9971C), Color(0xFF2FA39A), Color(0xFF5B7CF0), Color(0xFFC844E8)][i];

const _rankIcons = [LucideIcons.anvil, LucideIcons.shield, LucideIcons.shieldHalf, LucideIcons.medal, LucideIcons.award, LucideIcons.gem, LucideIcons.crown];

/// A rank as a small badge: its icon and name in its colour. [onMagic] draws it in white over the level-up sweep.
class RankBadge extends StatelessWidget {
  const RankBadge(this.index, {super.key, this.onMagic = false, this.small = false});
  final int index;
  final bool onMagic;
  final bool small;
  @override
  Widget build(BuildContext context) {
    const white = Color(0xFFFFFFFF);
    final c = onMagic ? white : rankColor(index);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: small ? 3 : 5),
      decoration: BoxDecoration(
        color: onMagic ? white.withValues(alpha: 0.2) : c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.6)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_rankIcons[index], size: small ? 12 : 14, color: c),
        SizedBox(width: small ? 4 : 5),
        Text(ranks[index].name, style: (small ? Theme.of(context).textTheme.labelMedium : Theme.of(context).textTheme.labelLarge)?.copyWith(color: c, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// How a rating moved, small, and only when it did: an arrow and the points, or with a new rank, its badge popping in
/// once. Nothing for a first rating or no change. [onMagic] draws it in white over the level-up sweep.
class RatingDelta extends StatelessWidget {
  const RatingDelta({super.key, required this.rating, required this.before, this.onMagic = false, this.withRank = true});
  final double rating;
  final double? before;
  final bool onMagic;
  final bool withRank; // false where the rank already shows beside it
  @override
  Widget build(BuildContext context) {
    if (before == null || (rating - before!).round() == 0) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final du = context.du;
    const white = Color(0xFFFFFFFF);
    final change = rating - before!;
    final rank = rankOf(rating);
    final up = withRank && rank.index > rankOf(before!).index;
    final c = onMagic ? white : change > 0 ? du.accentText : du.warning;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (up) ...[
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: m(context, const Duration(milliseconds: 700)),
          curve: Curves.elasticOut,
          builder: (context, v, child) => Transform.scale(scale: v, child: child),
          child: RankBadge(rank.index, onMagic: onMagic, small: true),
        ),
        const SizedBox(width: 6),
      ],
      Icon(change > 0 ? LucideIcons.arrowUp : LucideIcons.arrowDown, size: 13, color: c),
      Text('${change.abs().round()}', style: t.labelMedium?.copyWith(color: c, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
    ]);
  }
}

/// The way from this rank to the next as one bar in the rank's colour, with the next rank at its end.
class RankProgress extends StatelessWidget {
  const RankProgress({super.key, required this.rating});
  final double rating;
  @override
  Widget build(BuildContext context) {
    final du = context.du;
    final t = Theme.of(context).textTheme;
    final rank = rankOf(rating);
    final top = rank.index == ranks.length - 1;
    final c = rankColor(rank.index);
    return Row(children: [
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(999), child: SizedBox(height: 8, child: Stack(children: [
        Container(color: du.sunk),
        FractionallySizedBox(widthFactor: top ? 1 : rank.progress, child: Container(color: c)),
      ])))),
      const SizedBox(width: 10),
      if (top) Text('top rank', style: t.labelMedium?.copyWith(color: c)) else RankBadge(rank.index + 1, small: true),
    ]);
  }
}

/// Every rank in a sheet, from the top: what each takes on this exercise and the share of people it beats, the user's
/// own marked; the rating over time above them when there is one; and who it is ranked against.
Future<void> showRanks(BuildContext context, {required String title, required double rating, required String Function(double) takes,
    List<double> ratings = const [], List<double> performances = const [], String? basis}) {
  return showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final mine = rankOf(rating).index;
    return SafeArea(child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
        Text(title, style: t.titleLarge),
        if (ratings.length > 1) ...[
          const SizedBox(height: 14),
          RatingChart(ratings: ratings, performances: performances, height: 120),
        ],
        const SizedBox(height: 12),
        for (var i = ranks.length - 1; i >= 0; i--) Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: i == mine ? rankColor(i).withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: i == mine ? rankColor(i) : const Color(0x00000000), width: 1.2),
          ),
          child: Row(children: [
            SizedBox(width: 118, child: Align(alignment: Alignment.centerLeft, child: Opacity(opacity: i <= mine ? 1 : 0.5, child: RankBadge(i)))),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(i == 0 ? 'Under 800' : '${ranks[i].from.round()}+ · beats ${Rater.percentile(ranks[i].from).round()} %', style: t.labelLarge),
              if (i > 0) Text(takes(ranks[i].from), style: t.bodySmall?.copyWith(color: du.inkSecondary)),
            ])),
            if (i == mine) Text('you', style: t.labelLarge?.copyWith(color: rankColor(i), fontWeight: FontWeight.w700)),
          ]),
        ),
        if (basis != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(basis, style: t.bodySmall?.copyWith(color: du.inkTertiary))),
      ]),
    ));
  });
}

/// The rating over time: a line for the rating, a dot for each workout's performance, the ranks dashed across.
class RatingChart extends StatelessWidget {
  const RatingChart({super.key, required this.ratings, required this.performances, this.height = 130});
  final List<double> ratings, performances;
  final double height;
  @override
  Widget build(BuildContext context) {
    final du = context.du;
    return SizedBox(height: height, child: CustomPaint(size: Size.infinite, painter: _ChartPainter(ratings, performances, du.accentStrong, du.inkTertiary, du.line,
        Theme.of(context).textTheme.labelSmall!.copyWith(color: du.inkTertiary))));
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.ratings, this.perfs, this.line, this.dot, this.grid, this.label);
  final List<double> ratings, perfs;
  final Color line, dot, grid;
  final TextStyle label;
  @override
  void paint(Canvas canvas, Size size) {
    final all = [...ratings, ...perfs];
    final lo = all.reduce(min) - 15, hi = all.reduce(max) + 15;
    const left = 36.0;
    final w = size.width - left - 6, h = size.height - 6;
    double x(int i) => left + (ratings.length == 1 ? w / 2 : i / (ratings.length - 1) * w);
    double y(double v) => 3 + (1 - (v - lo) / (hi - lo)) * h;
    final g = Paint()..color = grid..strokeWidth = 0.6;
    for (final v in [lo + 15, (lo + hi) / 2, hi - 15]) {
      canvas.drawLine(Offset(left, y(v)), Offset(size.width, y(v)), g);
      final tp = TextPainter(text: TextSpan(text: '${v.round()}', style: label), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(0, y(v) - tp.height / 2));
    }
    // the ranks inside the chart, dashed in their colours, named at the left of the plot
    for (var k = 1; k < ranks.length; k++) {
      final v = ranks[k].from;
      if (v < lo || v > hi) continue;
      final p = Paint()..color = rankColor(k).withValues(alpha: 0.7)..strokeWidth = 1.2;
      for (var xx = left; xx < size.width; xx += 8) { canvas.drawLine(Offset(xx, y(v)), Offset(min(xx + 4, size.width), y(v)), p); }
      final tp = TextPainter(text: TextSpan(text: ranks[k].name, style: label.copyWith(color: rankColor(k))), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(left + 4, y(v) - tp.height - 1));
    }
    final d = Paint()..color = dot;
    for (var i = 0; i < perfs.length; i++) { canvas.drawCircle(Offset(x(i), y(perfs[i])), 3.2, d); }
    final p = Path()..moveTo(x(0), y(ratings[0]));
    for (var i = 1; i < ratings.length; i++) { p.lineTo(x(i), y(ratings[i])); }
    canvas.drawPath(p, Paint()..color = line..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round);
    canvas.drawCircle(Offset(x(ratings.length - 1), y(ratings.last)), 5, Paint()..color = line);
  }

  @override
  bool shouldRepaint(_ChartPainter o) => o.ratings != ratings || o.line != line;
}
