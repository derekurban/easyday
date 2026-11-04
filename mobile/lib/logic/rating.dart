// Strength rating: one number per lift that goes up as the user gets stronger, whatever mix of weight, version and reps
// got them there, and a rank from it. Grounded in how strong people really are, like a chess rating.
//
// Who the user is compared with: a mix, three parts people who train to one part everyone, so the standards (which
// measure people who train) do most of the ranking and a newcomer is still not put off. People who train come from the strength standards in lib/data/standards.g.dart, built by
// mobile/tool/gen_standards.py from strengthlevel.com, Symmetric Strength and FitnessVolt (data/standards/README.md has
// the table): five tiers, the strength that beats 5, 20, 50, 80 and 95 % of them, for men and for women at bodyweights
// 10 kg apart. Their spread runs through all five tiers. Everyone else is a normal spread of log strength as wide as the
// lifters' middle tiers, centred two of those spreads under their median: a little under their 5 % mark, about 0.9 of
// it on the barbell lifts, where studies of untrained adults put them (push-ups higher). The same place on every lift,
// so the same place among lifters rates the same everywhere. The two are mixed 75 / 25 ([everyoneWeight]).
//
// The rating is the user's place in that mix on a chess-like scale: 1200 is the middle, and each 350 points is one
// standard deviation, so 1550 is stronger than about 84 % and 850 than about 16 %. It works for any day's sets: they
// are worth what the judging reads (load x (1 + reps/30), averaged). Ranks are bands of 200 points.
//
// Standards are for adults 20 to 39; older or younger, they are scaled the way masters lifting adjusts for age (the
// standards' own age tables agree). A bodyweight exercise's strength is its version's share of bodyweight x
// (1 + reps/30), so every version of it lands on its standard. An exercise with no standard page is estimated from its
// beginner start, spaced like the measured lifts for the same muscles, and says so.
//
// Like Elo, the rating is the app's belief and each workout is evidence: the first workout sets it outright (a strong
// lifter starts high), then it moves part of the way to each day's performance, further while the exercise is new, and a
// day that does not count against the user (easy, low energy, light, hurt) can lift it but never lower it.
import 'dart:math';

import '../data/library.dart';
import '../data/model.dart';
import 'ladder.dart';
import 'score.dart';

part '../data/standards.g.dart';

enum Sex { man, woman }

/// How much of the mix the user is ranked in is everyone; the rest is people who train. The standards measure people who
/// train; everyone is modelled from a few studies, so it counts for less.
const everyoneWeight = 0.25;

/// The middle of the scale, and the points in one standard deviation.
const ratingMiddle = 1200.0;
const ratingSpread = 350.0;

/// The ranks, from the bottom: each starts at its rating; Iron is everything under Bronze.
const ranks = <({String name, double from})>[
  (name: 'Iron', from: double.negativeInfinity),
  (name: 'Bronze', from: 800),
  (name: 'Silver', from: 1000),
  (name: 'Gold', from: 1200),
  (name: 'Platinum', from: 1400),
  (name: 'Diamond', from: 1600),
  (name: 'Champion', from: 1800),
];

/// What a standard stands on: lifts people logged, a model's tables only, a close cousin exercise's page, or no page
/// (estimated from the beginner start).
enum Basis { measured, modelled, proxy, estimated }

/// The tiers' places in the spread of people who train: stronger than 5, 20, 50, 80 and 95 % of them.
const tierZ = [-1.6449, -0.8416, 0.0, 0.8416, 1.6449];

/// A lift's standard: for each sex, rows of a bodyweight in kg and the five tiers there, in the exercise's strength (kg
/// for a loaded lift, share of bodyweight for a bodyweight one, both x (1 + reps/30)).
class Standard {
  const Standard(this.basis, {required this.man, required this.woman, this.everyone = -2, this.version, this.assist, this.from = ''});
  final Basis basis;
  final List<List<double>> man, woman;
  /// Where everyone else is centred, in the spread of the lifters' middle tiers from their median: -2 is a little under
  /// their 5 % mark (-1.645), where studies of untrained adults put them; the same on every lift unless one says otherwise.
  final double everyone;
  /// The version a reps standard counts ("Push-ups"), to say a rating in its reps.
  final String? version;
  /// For the assisted machine: the share of bodyweight the full version moves; the assist comes off bodyweight.
  final double? assist;
  /// The sources, in words.
  final String from;

  /// The five tiers at a bodyweight: between rows in log-log, past the ends along the end rows.
  List<double> tiersAt(Sex sex, double bodyweight) {
    final rows = sex == Sex.man ? man : woman;
    if (rows.length == 1) return rows[0].sublist(1);
    var i = 1;
    while (i < rows.length - 1 && bodyweight > rows[i][0]) { i++; }
    final a = rows[i - 1], b = rows[i];
    final f = (log(bodyweight) - log(a[0])) / (log(b[0]) - log(a[0]));
    return [for (var k = 1; k <= 5; k++) exp(log(a[k]) + f * (log(b[k]) - log(a[k])))];
  }
}

/// For an exercise with no standard at all (every built-in strength exercise has one): the squat's spacing from its
/// beginner start.
const _borrowed = [1.0, 1.35, 1.76, 2.24, 2.75];

/// How much of an adult's peak strength is expected at an age: all of it from 20 to 39, a little less while still
/// growing, then the masters lifting age coefficients (McCulloch): about 0.885 at 50, 0.77 at 60, 0.64 at 70, 0.5 at 80.
double ageFactor(int age) {
  if (age < 20) return max(0.75, 1 - 0.025 * (20 - age));
  const points = [(40, 1.0), (50, 0.885), (60, 0.77), (70, 0.64), (80, 0.5), (90, 0.4)];
  if (age <= points.first.$1) return 1;
  for (var i = 1; i < points.length; i++) {
    final (a0, f0) = points[i - 1];
    final (a1, f1) = points[i];
    if (age <= a1) return f0 + (age - a0) / (a1 - a0) * (f1 - f0);
  }
  return points.last.$2;
}

double _phi(double z) => 0.5 * (1 + _erf(z / sqrt2));

// Abramowitz and Stegun 7.1.26: to about 1e-7, plenty here.
double _erf(double x) {
  final s = x < 0 ? -1.0 : 1.0;
  final a = x.abs();
  final t = 1 / (1 + 0.3275911 * a);
  final y = 1 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-a * a);
  return s * y;
}

/// The z for a share, by halving: the scale only needs it to a fraction of a point.
double _probit(double p) {
  var lo = -8.0, hi = 8.0;
  for (var i = 0; i < 60; i++) {
    final mid = (lo + hi) / 2;
    if (_phi(mid) < p) { lo = mid; } else { hi = mid; }
  }
  return (lo + hi) / 2;
}

/// Rates one lift for one person.
class Rater {
  Rater(this.ex, {required this.sex, required this.bodyweight, required this.age}) : standard = exerciseStandards[ex.id] ?? _fallback(ex) {
    final f = ageFactor(age);
    lifterTiers = [for (final x in standard.tiersAt(sex, bodyweight)) x * f];
    _logs = [for (final x in lifterTiers) log(x)];
    // everyone else: a normal spread as wide as the lifters' middle tiers (a small lift's Beginner and Elite marks are
    // noisy), centred [Standard.everyone] of those spreads from their median
    _sigma = (_logs[3] - _logs[1]) / (tierZ[3] - tierZ[1]);
    _muEveryone = _logs[2] + standard.everyone * _sigma;
  }

  static Standard _fallback(Exercise ex) {
    final start = ex.loaded ? startLoad(ex, 0) * epley(10) : versionShare(ex, ex.ladder!.start[0].clamp(0, ex.ladder!.variants.length - 1)) * epley(10);
    final row = [80.0, for (final m in _borrowed) start * m];
    return Standard(Basis.estimated, man: [row], woman: [row]);
  }

  final Exercise ex;
  final Sex sex;
  final double bodyweight;
  final int age;
  final Standard standard;
  /// The lifters' five tiers for this person, in this exercise's unit: stronger than 5, 20, 50, 80, 95 % of lifters.
  late final List<double> lifterTiers;
  late final List<double> _logs;
  late final double _sigma, _muEveryone;

  Basis get basis => standard.basis;

  /// Whether a standard grounds it, or it is estimated from the exercise's beginner start.
  bool get grounded => standard.basis != Basis.estimated;

  /// A level's load in this exercise's unit: kilograms, a version's share of bodyweight, or for the assisted machine
  /// (whose kilograms are [assistRefKg] less the assist) the full version's share of what is left of bodyweight.
  double load({double? kg, int? rung}) {
    if (ex.loaded) {
      final a = standard.assist;
      return a == null ? kg! : a * max(0.0, bodyweight - (assistRefKg - kg!)) / bodyweight;
    }
    return versionShare(ex, rung!);
  }

  /// The kilograms of a loaded exercise's load: [load] backwards.
  double kgFor(double load) {
    final a = standard.assist;
    return a == null ? load : assistRefKg - bodyweight + load * bodyweight / a;
  }

  /// Where a strength sits among people who train, as a z: straight between the tiers in log strength, past them along
  /// the end ones.
  double _zLifters(double x) {
    var i = 1;
    while (i < 4 && x > _logs[i]) { i++; }
    return tierZ[i - 1] + (x - _logs[i - 1]) / (_logs[i] - _logs[i - 1]) * (tierZ[i] - tierZ[i - 1]);
  }

  /// The share of the mix (three parts lifters, one part everyone) a strength is stronger than, 0 to 1.
  double share(double strength) {
    final x = log(max(strength, 1e-9));
    return (1 - everyoneWeight) * _phi(_zLifters(x)) + everyoneWeight * _phi((x - _muEveryone) / _sigma);
  }

  /// A strength as a rating: its place in the mix on the chess-like scale.
  double rating(double strength) => ratingMiddle + ratingSpread * _probit(share(strength).clamp(1e-12, 1 - 1e-12));

  /// A rating as a strength.
  double strength(double rating) {
    final want = _phi((rating - ratingMiddle) / ratingSpread);
    var lo = min(_muEveryone, _logs[0]) - 10 * _sigma, hi = _logs[4] + 10 * _sigma;
    for (var i = 0; i < 60; i++) {
      final mid = (lo + hi) / 2;
      if (share(exp(mid)) < want) { lo = mid; } else { hi = mid; }
    }
    return exp((lo + hi) / 2);
  }

  double setRating(double load, int reps) => rating(load * epley(reps));

  /// A day's performance: its sets averaged the way the judging averages them, as a rating.
  double performance(List<({double load, int reps})> sets) => rating(sets.fold(0.0, (a, x) => a + x.load * epley(x.reps)) / sets.length);

  /// The reps a rating is worth at a load.
  double repsAt(double rating, double load) => 30 * (strength(rating) / load - 1);

  /// The share of people a rating is stronger than, in per cent.
  static double percentile(double rating) => 100 * _phi((rating - ratingMiddle) / ratingSpread);
}

/// The rank a rating is in, and how far through it (0 to 1; the top rank counts its first 200 points).
({String name, int index, double progress}) rankOf(double rating) {
  var i = 0;
  for (var k = 0; k < ranks.length; k++) { if (rating >= ranks[k].from) i = k; }
  final from = i == 0 ? ranks[1].from - 200 : ranks[i].from;
  return (name: ranks[i].name, index: i, progress: ((rating - from) / 200).clamp(0.0, 1.0));
}

/// How far the rating moves toward a day's performance: half the way for the first three workouts, then a quarter.
double ratingPull(int workoutsBefore) => workoutsBefore < 3 ? 0.5 : 0.25;

/// The rating after a workout: the first workout sets it outright; then part of the way to the day's performance. A day
/// that does not count can only lift it.
double nextRating(double? rating, double perf, {required int workoutsBefore, bool counts = true}) {
  if (rating == null) return perf;
  if (!counts && perf < rating) return rating;
  return rating + ratingPull(workoutsBefore) * (perf - rating);
}

/// Who a standard ranks against, in a sentence, for the ranks sheet.
String basisLine(Rater r) => switch (r.basis) {
      Basis.measured => 'Ranked mostly against people who train (and a quarter everyone), from lifts logged on ${r.standard.from}',
      Basis.modelled => "Ranked mostly against people who train (and a quarter everyone), from FitnessVolt's model tables",
      Basis.proxy => 'Ranked mostly against people who train (and a quarter everyone), read from a close cousin of this exercise',
      Basis.estimated => 'Estimated: no standard for this one yet, so its ranks come from where a beginner starts',
    };

// ---- the user's own ratings, from their logged workouts ----

/// The rater for the user on [at]: their build (the body figure), their age that day from their birth date, and their
/// weight, or the usual guesses where not given.
Rater raterFor(AppState s, Exercise ex, DateTime at) {
  final sex = s.settings.figure == 'female' ? Sex.woman : Sex.man;
  return Rater(ex, sex: sex, bodyweight: s.profile?.bodyweightKg ?? (sex == Sex.man ? 80 : 65), age: s.profile?.ageAt(at) ?? 30);
}

/// One workout's place in an exercise's rating: when, what the day's sets were worth, and the rating after it.
typedef RatedWorkout = ({DateTime at, double performance, double rating});

/// What one workout's sets of an exercise were worth, and whether a lower one may count against the user: not on an easy
/// or low-energy day, a light exercise, or one that hurt. Null when nothing was done or it hurt.
({double performance, bool counts})? workoutPerformance(AppState s, Session x, int i, Rater r) {
  final e = x.exercises[i];
  final sets = e.attempted.toList();
  if (sets.isEmpty || x.painAt == i) return null;
  final ex = e.exercise;
  final perf = r.performance([for (final l in sets) (load: ex.loaded ? r.load(kg: setLoad(s, e, l)) : r.load(rung: l.rung ?? e.rung), reps: l.reps ?? 0)]);
  final end = endReadOf(x.endRead);
  final low = end == EndRead.energy || end == EndRead.low || x.stopReason == StopReason.energy;
  return (performance: perf, counts: x.energy != Energy.easy && e.atWorkingLevel && !low);
}

/// An exercise's rating through the user's logged workouts, oldest first, and [plus] (the workout on the finish screen,
/// not logged yet) at the end. Worked out from the history every time, so a change of birth date or weight reads it all
/// again. Each workout is rated at the age the user was that day.
List<RatedWorkout> ratingHistory(AppState s, Exercise ex, DateTime now, {Session? plus}) {
  final raters = <int?, Rater>{};
  final out = <RatedWorkout>[];
  final logged = [for (final x in s.sessions) if (x.startedAt != null && !identical(x, plus)) x]..sort((a, b) => a.startedAt!.compareTo(b.startedAt!));
  double? rating;
  for (final x in [...logged, ?plus]) {
    final i = x.exercises.indexWhere((e) => e.exId == ex.id && e.attempted.isNotEmpty);
    if (i < 0) continue;
    final at = x.startedAt ?? now;
    final p = workoutPerformance(s, x, i, raters.putIfAbsent(s.profile?.ageAt(at), () => raterFor(s, ex, at)));
    if (p == null) continue;
    rating = nextRating(rating, p.performance, workoutsBefore: out.length, counts: p.counts);
    out.add((at: at, performance: p.performance, rating: rating));
  }
  return out;
}

/// What a rating is worth as lifts: for a loaded exercise, the weight it takes at the bottom, middle and top of the
/// range ("12 × 37.5 kg"); for a bodyweight one, the reps it takes at the versions around it. Heaviest first.
List<String> liftsAt(AppState s, Exercise ex, Rater r, double rating, RepRange range, Iterable<String> equipment) {
  final strength = r.strength(rating);
  if (ex.loaded) {
    final step = stepKg(s, ex);
    // three weights a step apart around the middle of the range, each with the reps it takes there
    final mid = roundStep(r.kgFor(strength / epley(((range.lo + range.hi) / 2).round())), step);
    final out = <String>[];
    for (final kg in [mid + step, mid, mid - step]) {
      if (kg <= 0) continue;
      final load = r.load(kg: kg);
      if (load <= 0) continue;
      final reps = (30 * (strength / load - 1)).round();
      if (reps >= 1) out.add('$reps × ${fmtLoad(s, ex, kg, equipment: equipment)}');
    }
    return out;
  }
  final l = ex.ladder!;
  final mid = (range.lo + range.hi) / 2;
  final options = <(int, String, int)>[];
  for (var i = 0; i < l.variants.length; i++) {
    final reps = r.repsAt(rating, r.load(rung: i)).round();
    if (reps >= 3 && reps <= 25) options.add((i, l.variants[i].name, reps));
  }
  options.sort((a, b) => (a.$3 - mid).abs().compareTo((b.$3 - mid).abs()));
  final picked = options.take(2).toList()..sort((a, b) => b.$1.compareTo(a.$1));
  return [for (final o in picked) '${o.$3} × ${o.$2}'];
}

/// The user's overall rating: every exercise they have a rating on, averaged, with [plus] (the workout on the finish
/// screen) counted in. The change is what [plus] moved it, over the exercises rated before it, so a first rating on a
/// new exercise never reads as a loss. Null when nothing is rated.
({double rating, double? change})? overallRating(AppState s, DateTime now, {Session? plus}) {
  final ids = <String>{
    for (final x in [...s.sessions, ?plus]) for (final e in x.exercises) if (e.attempted.isNotEmpty && e.exercise.isStrength && e.exercise.tracked) e.exId,
  };
  final latest = <double>[];
  var moved = 0.0, before = 0;
  for (final id in ids) {
    final h = ratingHistory(s, exerciseById[id]!, now, plus: plus);
    if (h.isEmpty) continue;
    latest.add(h.last.rating);
    final today = plus != null && h.last.at == (plus.startedAt ?? now);
    if (!today) {
      before++;
    } else if (h.length > 1) {
      before++;
      moved += h.last.rating - h[h.length - 2].rating;
    }
  }
  if (latest.isEmpty) return null;
  return (rating: latest.reduce((a, b) => a + b) / latest.length, change: plus == null || before == 0 ? null : moved / before);
}
