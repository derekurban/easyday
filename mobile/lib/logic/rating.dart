// Strength rating: one number per lift that goes up as the user gets stronger, whatever mix of weight, version and reps
// got them there, and a rank from it. Grounded in how strong people really are, like a chess rating. Explored in the
// playground; nothing else reads it yet.
//
// Who the user is compared with: half everyone, half people who train, so neither a newcomer nor a seasoned lifter is
// put off. Lifters come from real strength standards (strengthlevel.com, from logged lifts, by sex and bodyweight): five
// tiers, stronger than 5, 20, 50, 80 and 95 % of lifters, read as a normal spread of log strength. Everyone else is the
// same spread centred a little under the lifters' 5 % mark, about where "untrained" standards put a healthy adult who
// has never trained. The two are mixed half and half.
//
// The rating is the user's place in that mix on a chess-like scale: 1200 is the middle, and each 350 points is one
// standard deviation, so 1550 is stronger than about 84 % and 850 than about 16 %. It works for any day's sets: they
// are worth what the judging reads (load x (1 + reps/30), averaged). Ranks are bands of 200 points.
//
// Standards are for adults 20 to 39; older or younger, they are scaled the way masters lifting adjusts for age. Lifts
// with a kilogram standard scale it from the standard's bodyweight to the user's. Push-ups and pull-ups have standards in
// reps of the full version; every version is turned into those reps by its share of bodyweight. An exercise with no
// standard yet borrows the squat's spacing from its own beginner start, and says it is estimated.
//
// Like Elo, the rating is the app's belief and each workout is evidence: the first workout sets it outright (a strong
// lifter starts high), then it moves part of the way to each day's performance, further while the exercise is new, and a
// day that does not count against the user (easy, low energy, light, hurt) can lift it but never lower it.
import 'dart:math';

import '../data/library.dart';
import '../data/model.dart';
import 'ladder.dart';
import 'score.dart';

enum Sex { man, woman }

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

/// A lift's standard: the five lifter tiers as a one-rep max in kilograms at a reference bodyweight, or as reps of one
/// version.
class Standard {
  const Standard.kg({required this.man, required this.woman, this.manKg = 80, this.womanKg = 65}) : version = null;
  const Standard.reps({required this.version, required this.man, required this.woman}) : manKg = 0, womanKg = 0;
  final List<double> man, woman;
  final double manKg, womanKg; // the bodyweights the kilograms are for
  final String? version;       // reps of this version; under one is written as a negative: the reps short of one
  bool get reps => version != null;
}

/// From strengthlevel.com, November 2026: the bodyweight tables at 80 kg (men) and 65 kg (women); stronger than 5, 20, 50,
/// 80 and 95 % of lifters.
const standards = <String, Standard>{
  'bb_squat': Standard.kg(man: [75, 101, 132, 168, 206], woman: [35, 53, 76, 104, 134]),
  'bb_bench': Standard.kg(man: [56, 75, 98, 124, 151], woman: [20.5, 33.5, 50, 70, 92]),
  'bb_row': Standard.kg(man: [48, 66, 88, 114, 141], woman: [19, 30, 44, 62, 80]),
  // a bodyweight row has no standard of its own: read as a barbell row of its share of the user's weight
  'inverted_row': Standard.kg(man: [48, 66, 88, 114, 141], woman: [19, 30, 44, 62, 80]),
  'pushup': Standard.reps(version: 'Push-ups', man: [5, 19, 39, 62, 87], woman: [-3, 7, 18, 31, 47]),
  'pullup': Standard.reps(version: 'Pull-ups', man: [-3, 7, 13, 21, 30], woman: [-8, -3, 6, 12, 19]),
};

/// Strength across bodyweights grows slower than the weight: the standards' own tables run close to this power.
const _bodyweightPower = 0.8;

/// Where everyone else is centred, against the lifters' 5 % mark: "untrained" standards put a healthy adult who has
/// never trained a little under it.
const _untrained = 0.85;

/// The squat's tiers as multiples of its lowest, for an exercise with no standard yet.
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
  Rater(this.ex, {required this.sex, required this.bodyweight, required this.age}) {
    final st = standards[ex.id];
    _standard = st;
    final List<double> tiers;
    if (st == null) {
      final start = ex.loaded ? startLoad(ex, 0) * epley(10) : versionShare(ex, ex.ladder!.start[0].clamp(0, ex.ladder!.variants.length - 1)) * epley(10);
      tiers = [for (final m in _borrowed) start * m];
    } else if (st.reps) {
      final share = versionShare(ex, max(0, ex.ladder!.variants.indexWhere((v) => v.name == st.version)));
      tiers = [for (final r in sex == Sex.man ? st.man : st.woman) share * epley(r.round())];
    } else {
      final ref = sex == Sex.man ? st.manKg : st.womanKg;
      final scale = pow(bodyweight / ref, _bodyweightPower).toDouble();
      tiers = [for (final kg in sex == Sex.man ? st.man : st.woman) kg * scale];
    }
    final f = ageFactor(age);
    lifterTiers = [for (final x in tiers) x * f];
    final logs = [for (final x in lifterTiers) log(x)];
    _mu = logs[2];
    _sigma = (logs[4] - logs[0]) / (2 * 1.6449);
    _muEveryone = log(lifterTiers[0] * _untrained);
  }

  final Exercise ex;
  final Sex sex;
  final double bodyweight;
  final int age;
  /// The lifters' five tiers for this person, in this exercise's unit: stronger than 5, 20, 50, 80, 95 % of lifters.
  late final List<double> lifterTiers;
  Standard? _standard;
  late final double _mu, _sigma, _muEveryone;

  /// Whether real standards ground it, or it is estimated from the exercise's beginner start.
  bool get grounded => _standard != null;

  /// A level's load in this exercise's unit: kilograms, a version's share of bodyweight, or for a bodyweight exercise
  /// read against a kilogram standard, its share of the user's weight in kilograms.
  double load({double? kg, int? rung}) {
    if (ex.loaded) return kg!;
    final share = versionShare(ex, rung!);
    return _standard != null && !_standard!.reps ? share * bodyweight : share;
  }

  /// The share of the mix (half everyone, half lifters) a strength is stronger than, 0 to 1.
  double share(double strength) {
    final x = log(max(strength, 1e-9));
    return 0.5 * _phi((x - _mu) / _sigma) + 0.5 * _phi((x - _muEveryone) / _sigma);
  }

  /// A strength as a rating: its place in the mix on the chess-like scale.
  double rating(double strength) => ratingMiddle + ratingSpread * _probit(share(strength).clamp(1e-12, 1 - 1e-12));

  /// A rating as a strength.
  double strength(double rating) {
    final want = _phi((rating - ratingMiddle) / ratingSpread);
    var lo = _muEveryone - 10 * _sigma, hi = _mu + 10 * _sigma;
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

// ---- the user's own ratings, from their logged workouts ----

/// The rater for the user: their build (the body figure), age and weight, or the usual guesses where not given.
Rater raterFor(AppState s, Exercise ex, DateTime now) {
  final sex = s.settings.figure == 'female' ? Sex.woman : Sex.man;
  return Rater(ex, sex: sex, bodyweight: s.profile?.bodyweightKg ?? (sex == Sex.man ? 80 : 65), age: s.profile?.ageAt(now) ?? 30);
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
  final perf = r.performance([for (final l in sets) (load: ex.loaded ? setLoad(s, e, l) : r.load(rung: l.rung ?? e.rung), reps: l.reps ?? 0)]);
  final end = endReadOf(x.endRead);
  final low = end == EndRead.energy || end == EndRead.low || x.stopReason == StopReason.energy;
  return (performance: perf, counts: x.energy != Energy.easy && e.atWorkingLevel && !low);
}

/// An exercise's rating through the user's logged workouts, oldest first, and [plus] (the workout on the finish screen,
/// not logged yet) at the end. Worked out from the history every time, so a change of age or weight reads it all again.
List<RatedWorkout> ratingHistory(AppState s, Exercise ex, DateTime now, {Session? plus}) {
  final r = raterFor(s, ex, now);
  final out = <RatedWorkout>[];
  final logged = [for (final x in s.sessions) if (x.startedAt != null && !identical(x, plus)) x]..sort((a, b) => a.startedAt!.compareTo(b.startedAt!));
  double? rating;
  for (final x in [...logged, ?plus]) {
    final i = x.exercises.indexWhere((e) => e.exId == ex.id && e.attempted.isNotEmpty);
    if (i < 0) continue;
    final p = workoutPerformance(s, x, i, r);
    if (p == null) continue;
    rating = nextRating(rating, p.performance, workoutsBefore: out.length, counts: p.counts);
    out.add((at: x.startedAt ?? now, performance: p.performance, rating: rating));
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
    final mid = roundStep(strength / epley(((range.lo + range.hi) / 2).round()), step);
    final out = <String>[];
    for (final kg in [mid + step, mid, mid - step]) {
      if (kg <= 0) continue;
      final reps = (30 * (strength / kg - 1)).round();
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
