// Playground: the strength rating and rank on one lift, to understand them before anything else uses them
// (logic/rating.dart). Rated against a mix of everyone and people who train, for a build, age and bodyweight. A made-up lifter's history shows
// the rating over time; a workout to try shows what any mix of weight, version and reps is worth and where the rating
// would go; the levels sit as bands on the same scale, with the user as a line through them. Nothing here reads or
// writes the user's data.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/library.dart';
import '../data/model.dart';
import '../logic/ladder.dart';
import '../logic/rating.dart';
import '../logic/score.dart';
import 'motion.dart';
import 'rank.dart';
import 'theme.dart';
import 'widgets.dart';

/// One level of an exercise: what it is called and its load in the rater's unit.
typedef _Level = ({String name, double load});

/// A workout in the made-up history: a level (an index into the levels) and its sets' reps.
typedef _Day = ({int at, List<int> reps});

/// The exercises the lab offers, each with a made-up history: steps relative to where the lifter starts, and the reps.
const strengthLabExercises = <(String, List<(int, List<int>)>)>[
  ('bb_squat', [(0, [10, 10, 9]), (0, [12, 11, 10]), (1, [9, 9, 8]), (1, [11, 10, 10]), (1, [12, 12, 11]), (2, [8, 8, 7]), (2, [10, 9, 9]), (2, [11, 11, 10])]),
  ('bb_bench', [(0, [10, 9, 9]), (0, [11, 11, 10]), (1, [8, 8, 7]), (1, [9, 9, 8]), (1, [7, 6, 6]), (1, [10, 9, 9]), (2, [8, 7, 7])]),
  ('pushup', [(0, [10, 9, 9]), (0, [12, 11, 11]), (0, [15, 14, 13]), (1, [7, 6, 6]), (1, [8, 8, 7]), (1, [10, 9, 8])]),
  ('inverted_row', [(0, [9, 8, 8]), (0, [12, 11, 10]), (1, [8, 7, 7]), (1, [10, 9, 9]), (1, [12, 11, 11])]),
  ('pullup', [(0, [6, 5, 5]), (0, [8, 7, 6]), (1, [5, 4, 4]), (1, [6, 6, 5]), (2, [3, 3, 2])]),
];

/// Who the lab rates: the user's own build, age and weight to begin with (see [startLabPerson]), changeable in the lab.
final labPerson = ValueNotifier<({Sex sex, double bodyweight, int age})>((sex: Sex.man, bodyweight: 80, age: 30));
bool _labPersonSet = false;

/// Start the lab from the user's profile, once: their build, age and weight, or the usual guesses where not given.
void startLabPerson(AppState s, DateTime now) {
  if (_labPersonSet) return;
  _labPersonSet = true;
  final sex = s.settings.figure == 'female' ? Sex.woman : Sex.man;
  labPerson.value = (sex: sex, bodyweight: s.profile?.bodyweightKg ?? (sex == Sex.man ? 80 : 65), age: s.profile?.ageAt(now) ?? 30);
}

/// The lab's own little world: a user with some experience at a full gym, so ranges and loads read as usual.
AppState _sandbox() {
  final s = AppState()
    ..profile = Profile(experience: 'some', daysPerWeek: 3, createdAt: DateTime(2026))
    ..goal = GoalConfig.fromTemplate(goals['muscle']!);
  final tpl = templates.firstWhere((t) => t.id == 'gym');
  s.locations = [Location(id: 'l1', name: tpl.name, template: tpl.id, equipment: tpl.equipment.toList())];
  s.lastLocationId = 'l1';
  return s;
}

Rater _rater(Exercise ex) => Rater(ex, sex: labPerson.value.sex, bodyweight: labPerson.value.bodyweight, age: labPerson.value.age);

/// The levels of an exercise in order, up past Elite, and where the made-up history starts: the app's usual start for
/// someone with some experience.
(List<_Level>, int) _levelsOf(AppState s, Exercise ex, Rater r) {
  final List<_Level> levels;
  final int start;
  if (ex.loaded) {
    final step = stepKg(s, ex);
    final top = max(startLoad(ex, 2) * 2, r.lifterTiers.last / epley(5));
    levels = [for (var kg = step; kg <= top + 1e-6; kg += step) (name: fmtLoad(s, ex, kg), load: r.load(kg: kg))];
    start = max(0, levels.indexWhere((l) => l.load >= r.load(kg: startLoad(ex, 1)) - 1e-6));
  } else {
    final l = ex.ladder!;
    levels = [for (var i = 0; i < l.variants.length; i++) (name: l.variants[i].name, load: r.load(rung: i))];
    start = l.start[1].clamp(0, l.variants.length - 1);
  }
  return (levels, start);
}

/// Where the starting lifter's history ends on a lift.
double strengthLabRating(String id) {
  final s = _sandbox();
  final ex = exerciseById[id]!;
  final r = _rater(ex);
  final (levels, start) = _levelsOf(s, ex, r);
  return _ratings(r, levels, _script(id, start, levels.length)).last;
}

/// A short line of the rating for the playground's list: where the starting lifter's history ends, and its rank.
String strengthLabSummary(String id) {
  final r = _rater(exerciseById[id]!);
  final rating = strengthLabRating(id);
  return '${rating.round()} · ${rankOf(rating).name}${r.grounded ? '' : ' (estimated)'}';
}

List<_Day> _script(String id, int start, int count) => [
      for (final (step, reps) in strengthLabExercises.firstWhere((x) => x.$1 == id).$2) (at: (start + step).clamp(0, count - 1), reps: reps),
    ];

double _perf(Rater r, List<_Level> levels, _Day d) => r.performance([for (final n in d.reps) (load: levels[d.at].load, reps: n)]);

/// The rating after each workout of the history.
List<double> _ratings(Rater r, List<_Level> levels, List<_Day> days) {
  final out = <double>[];
  double? x;
  for (var i = 0; i < days.length; i++) {
    x = nextRating(x, _perf(r, levels, days[i]), workoutsBefore: i);
    out.add(x);
  }
  return out;
}

/// What a rating is worth, as reps at the levels around it: "10 × 40 kg · 8 × 42.5 kg". The ones nearest the middle
/// of the rep range, heaviest first; only 3 to 25 reps.
String _equalLine(Rater r, List<_Level> levels, double rating, RepRange range, {int max = 3}) {
  final mid = (range.lo + range.hi) / 2;
  final options = <(int, _Level, int)>[];
  for (var i = 0; i < levels.length; i++) {
    final reps = r.repsAt(rating, levels[i].load).round();
    if (reps >= 3 && reps <= 25) options.add((i, levels[i], reps));
  }
  options.sort((a, b) => (a.$3 - mid).abs().compareTo((b.$3 - mid).abs()));
  final picked = options.take(max).toList()..sort((a, b) => b.$1.compareTo(a.$1));
  return picked.map((o) => '${o.$3} × ${o.$2.name}').join(' · ');
}

class StrengthLabScreen extends StatefulWidget {
  const StrengthLabScreen({super.key, required this.exerciseId});
  final String exerciseId;
  @override
  State<StrengthLabScreen> createState() => _StrengthLabScreenState();
}

class _StrengthLabScreenState extends State<StrengthLabScreen> {
  final s = _sandbox();
  late final Exercise ex = exerciseById[widget.exerciseId]!;
  late Rater r;
  late List<_Level> levels;
  late List<_Day> history;
  late int at;
  late List<int> reps;
  bool counts = true;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  /// Rebuild the rater, levels and history for the person and lifter picked, and try the history's last workout again.
  void _reset() {
    r = _rater(ex);
    final (l, start) = _levelsOf(s, ex, r);
    levels = l;
    history = _script(widget.exerciseId, start, levels.length);
    at = history.last.at;
    reps = [...history.last.reps];
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final range = homeRange(s, ex);
    final ratings = _ratings(r, levels, history);
    final perfs = [for (final d in history) _perf(r, levels, d)];
    final rating = ratings.last;
    final change = ratings.length > 1 ? rating - ratings[ratings.length - 2] : 0.0;
    final today = r.performance([for (final n in reps) (load: levels[at].load, reps: n)]);
    final after = nextRating(rating, today, workoutsBefore: history.length, counts: counts);
    final moved = after - rating;
    Color tone(double d) => d > 2 ? du.accentText : d < -2 ? du.warning : du.inkSecondary;
    String signed(double d) => d.round() == 0 ? '±0' : '${d > 0 ? '+' : '−'}${d.abs().round()}';
    final mine = levels.lastIndexWhere((l) => r.setRating(l.load, range.lo) <= rating);
    final cur = mine < 0 ? 0 : mine;
    final rank = rankOf(rating);
    final nextRank = rank.index + 1 < ranks.length ? ranks[rank.index + 1] : null;
    final person = labPerson.value;
    void setPerson(({Sex sex, double bodyweight, int age}) p) => setState(() { labPerson.value = p; _reset(); });

    return Scaffold(
      appBar: AppBar(title: Text(ex.name)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
        // who it is rated against
        SegmentedButton<Sex>(
          segments: const [ButtonSegment(value: Sex.man, label: Text('Male')), ButtonSegment(value: Sex.woman, label: Text('Female'))],
          selected: {person.sex},
          showSelectedIcon: false,
          onSelectionChanged: (x) => setPerson((sex: x.first, bodyweight: person.bodyweight, age: person.age)),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _Stepper(label: 'Age ${person.age}',
              onMinus: person.age > 14 ? () => setPerson((sex: person.sex, bodyweight: person.bodyweight, age: person.age - 1)) : null,
              onPlus: person.age < 90 ? () => setPerson((sex: person.sex, bodyweight: person.bodyweight, age: person.age + 1)) : null)),
          const SizedBox(width: 8),
          Expanded(child: _Stepper(label: '${person.bodyweight.round()} kg',
              onMinus: person.bodyweight > 40 ? () => setPerson((sex: person.sex, bodyweight: person.bodyweight - 1, age: person.age)) : null,
              onPlus: person.bodyweight < 160 ? () => setPerson((sex: person.sex, bodyweight: person.bodyweight + 1, age: person.age)) : null)),
        ]),
        const SizedBox(height: 12),
        // the rating, where it stands, and how it got here
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('STRENGTH', style: t.labelSmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w600, color: du.inkTertiary)),
          const SizedBox(height: 2),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text('${rating.round()}', style: t.displaySmall?.copyWith(fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
            const SizedBox(width: 10),
            Flexible(child: Text('${signed(change)} last workout', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(color: tone(change), fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            RankBadge(rank.index),
            const SizedBox(width: 8),
            Flexible(child: Text('stronger than ${Rater.percentile(rating).round()} % of people', style: t.titleSmall?.copyWith(color: du.inkSecondary))),
          ]),
          const SizedBox(height: 6),
          const SizedBox(height: 2),
          Text('About ${_equalLine(r, levels, rating, range)}', style: t.bodyMedium?.copyWith(color: du.inkSecondary)),
          const SizedBox(height: 12),
          RankProgress(rating: rating),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: Text(nextRank == null ? 'The top rank' : '${(nextRank.from - rating).ceil()} to ${nextRank.name}',
                style: t.bodySmall?.copyWith(color: du.inkSecondary))),
            TextButton(
              onPressed: () => showRanks(context, title: '${ex.name}: ranks', rating: rating, takes: (x) => _rankLift(x, range),
                  ratings: ratings, performances: perfs,
                  basis: '${basisLine(r)}: ${person.sex == Sex.man ? 'men' : 'women'} around ${person.bodyweight.round()} kg, adjusted to age ${person.age}.'),
              child: const Text('All ranks'),
            ),
          ]),
        ])),
        const SizedBox(height: 18),
        // a workout to try
        const Subhead('Try a workout', icon: LucideIcons.dumbbell),
        const SizedBox(height: 10),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            SizedBox(width: 72, child: Text(ex.loaded ? 'Weight' : 'Version', style: t.bodyMedium?.copyWith(color: du.inkSecondary))),
            Expanded(child: _Stepper(label: levels[at].name, onMinus: at > 0 ? () => setState(() => at--) : null, onPlus: at < levels.length - 1 ? () => setState(() => at++) : null)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            SizedBox(width: 72, child: Text('Reps', style: t.bodyMedium?.copyWith(color: du.inkSecondary))),
            for (var k = 0; k < reps.length; k++) ...[
              if (k > 0) const SizedBox(width: 6),
              Expanded(child: _Stepper(label: '${reps[k]}', onMinus: reps[k] > 1 ? () => setState(() => reps[k]--) : null, onPlus: reps[k] < 60 ? () => setState(() => reps[k]++) : null)),
            ],
          ]),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('A day that counts'),
            subtitle: const Text('Off: an easy or low-energy day, which can lift it but never lower it'),
            value: counts,
            onChanged: (v) => setState(() => counts = v),
          ),
          Divider(height: 20, color: du.line),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text('This workout', style: t.bodyLarge),
            const Spacer(),
            Text('${today.round()}', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
          Text(today > rating + 2 ? 'Stronger than your ${rating.round()}.' : today < rating - 2 ? 'Under your ${rating.round()}.' : 'Right at your ${rating.round()}.',
              style: t.bodyMedium?.copyWith(color: tone(today - rating))),
          const SizedBox(height: 10),
          AnimatedContainer(
            duration: m(context, durBase),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: tone(moved).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(moved > 0.5 ? LucideIcons.trendingUp : moved < -0.5 ? LucideIcons.trendingDown : LucideIcons.equal, size: 18, color: tone(moved)),
              const SizedBox(width: 10),
              Expanded(child: Text('Your strength would go from ${rating.round()} to ${after.round()} (${signed(moved)})', style: t.bodyMedium?.copyWith(color: du.ink))),
            ]),
          ),
          const SizedBox(height: 8),
          Text('Moves ${(ratingPull(history.length) * 100).round()} % of the way to a workout: half while it is new, a quarter once settled. The first workout sets it outright.',
              style: t.bodySmall?.copyWith(color: du.inkTertiary)),
        ])),
        const SizedBox(height: 18),
        // the levels on the same scale
        const Subhead('The levels on one scale', icon: LucideIcons.chartNoAxesGantt),
        const SizedBox(height: 4),
        Text('Each bar is a level, from ${range.lo} reps (left) to ${range.hi} (right). The line is you. Bars overlap: a few reps at the next level can be worth the same as more at this one.',
            style: t.bodySmall?.copyWith(color: du.inkSecondary)),
        const SizedBox(height: 10),
        Panel(child: _ladder(context, range, rating, today, cur)),
        const SizedBox(height: 18),
        // what moves it
        const Subhead('What moves it', icon: LucideIcons.calculator),
        const SizedBox(height: 10),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _fact(context, 'One more rep', r.setRating(levels[cur].load, 11) - r.setRating(levels[cur].load, 10)),
          if (cur + 1 < levels.length) _fact(context, ex.loaded ? 'One step heavier (${levels[cur + 1].name})' : 'The next version (${levels[cur + 1].name})',
              r.setRating(levels[cur + 1].load, 10) - r.setRating(levels[cur].load, 10)),
        ])),
      ]),
    );
  }

  /// What a rating takes on this lift: in the standard's own version for push-ups and pull-ups ("39 × Push-ups"), else
  /// as reps at the levels around it, or as one lift when it is past them all.
  String _rankLift(double rating, RepRange range) {
    final version = r.standard.version;
    final i = ex.ladder?.variants.indexWhere((v) => v.name == version) ?? -1;
    if (version != null && i >= 0) {
      final n = r.repsAt(rating, r.load(rung: i)).round();
      if (n >= 1) return '$n × $version';
    }
    final line = _equalLine(r, levels, rating, range, max: 2);
    if (line.isNotEmpty) return line;
    if (ex.loaded) return '${r.strength(rating).round()} kg once';
    final top = levels.length - 1;
    return '${r.repsAt(rating, levels[top].load).round()} × ${levels[top].name}';
  }

  Widget _key(BuildContext context, Color c, String text, {bool line = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: line ? 16 : 8, height: line ? 3 : 8, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.du.inkSecondary)),
      ]);

  Widget _fact(BuildContext context, String what, double points) {
    final t = Theme.of(context).textTheme;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
      Expanded(child: Text(what, style: t.bodyMedium)),
      Text('${points >= 0 ? '+' : '−'}${points.abs().round()}', style: t.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
    ]));
  }

  /// The levels near the user as bands on one axis, from the bottom of the range to the top, with the rating and the
  /// workout being tried as lines through them. A tap on a level tries it.
  Widget _ladder(BuildContext context, RepRange range, double rating, double today, int cur) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final reach = ex.loaded ? 3 : 2; // versions are big steps: fewer of them, so the bands stay readable
    final from = max(0, cur - reach), to = min(levels.length - 1, cur + reach);
    final shown = [for (var i = to; i >= from; i--) i];
    final lo = r.setRating(levels[from].load, range.lo) - 30, hi = r.setRating(levels[to].load, range.hi) + 30;
    final nameWidth = ex.loaded ? 70.0 : 118.0;
    return Column(children: [
      for (final i in shown) InkWell(
        onTap: () { HapticFeedback.selectionClick(); setState(() => at = i); },
        borderRadius: BorderRadius.circular(8),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [
          SizedBox(width: nameWidth, child: Text(levels[i].name, maxLines: 2, style: (i == cur ? t.labelLarge?.copyWith(fontWeight: FontWeight.w700) : t.labelMedium)?.copyWith(color: i == at ? du.accentText : null))),
          const SizedBox(width: 8),
          Expanded(child: SizedBox(height: 26, child: CustomPaint(painter: _BandPainter(
            lo: lo, hi: hi,
            from: r.setRating(levels[i].load, range.lo), to: r.setRating(levels[i].load, range.hi),
            you: rating, trying: i == at ? today : null,
            band: i == cur ? du.accentStrong.withValues(alpha: 0.35) : du.sunk, edge: i == cur ? du.accentStrong : du.line,
            youColor: du.ink, tryColor: const Color(0xFFC844E8),
          )))),
          SizedBox(width: 82, child: Text('${r.setRating(levels[i].load, range.lo).round()}–${r.setRating(levels[i].load, range.hi).round()}', textAlign: TextAlign.right,
              style: t.labelSmall?.copyWith(color: du.inkTertiary, fontFeatures: const [FontFeature.tabularFigures()]))),
        ])),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 14, runSpacing: 4, children: [
        _key(context, du.ink, 'you, ${rating.round()}', line: true),
        _key(context, const Color(0xFFC844E8), 'the workout you are trying', line: true),
      ]),
    ]);
  }
}

/// A − value + stepper, small.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, this.onMinus, this.onPlus});
  final String label;
  final VoidCallback? onMinus, onPlus;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    Widget b(IconData i, VoidCallback? f) => InkResponse(onTap: f == null ? null : () { HapticFeedback.selectionClick(); f(); }, radius: 20,
        child: SizedBox(width: 30, height: 36, child: Icon(i, size: 16, color: f == null ? du.line : du.inkSecondary)));
    return Container(
      decoration: BoxDecoration(color: du.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: du.line, width: 0.6)),
      child: Row(children: [
        b(LucideIcons.minus, onMinus),
        Expanded(child: Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]))),
        b(LucideIcons.plus, onPlus),
      ]),
    );
  }
}

/// One level as a band on the shared axis, with the user's rating and the workout being tried as lines.
class _BandPainter extends CustomPainter {
  _BandPainter({required this.lo, required this.hi, required this.from, required this.to, required this.you, this.trying,
      required this.band, required this.edge, required this.youColor, required this.tryColor});
  final double lo, hi, from, to, you;
  final double? trying;
  final Color band, edge, youColor, tryColor;
  @override
  void paint(Canvas canvas, Size size) {
    double x(double v) => ((v - lo) / (hi - lo)).clamp(0.0, 1.0) * size.width;
    final r = RRect.fromRectAndRadius(Rect.fromLTRB(x(from), 6, x(to), size.height - 6), const Radius.circular(6));
    canvas.drawRRect(r, Paint()..color = band);
    canvas.drawRRect(r, Paint()..color = edge..style = PaintingStyle.stroke..strokeWidth = 1);
    canvas.drawLine(Offset(x(you), 0), Offset(x(you), size.height), Paint()..color = youColor..strokeWidth = 2);
    if (trying != null) {
      canvas.drawLine(Offset(x(trying!), 2), Offset(x(trying!), size.height - 2), Paint()..color = tryColor..strokeWidth = 2.5..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_BandPainter o) => o.you != you || o.trying != trying || o.band != band || o.from != from;
}
