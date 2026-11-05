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
// Like Elo, the rating is the app's belief and each workout is evidence, read from the day's best set. An exercise goes
// through three stages ([LiftStage]). Calibrating: its weight is still being found (calibration sets at the cap, or
// reps over the top), so a workout only lifts it, a floor. Calibrated: a calibration set ended under the cap (or, for
// older workouts and holds, the reps landed in the range), which sets it outright, so a strong lifter starts high.
// Settled: one more workout at that weight; from then it moves part of the way to each day's performance, further
// while it is new, and a day that does not count against the user (easy, low energy, light, hurt) can lift it but
// never lower it.
//
// The overall rating is the average of the lifts the user is actively training (done in the last [activeDays]):
// unranked until two have been calibrated, provisional (the calibrated ones) until five have settled, then the settled
// ones. It moves as fast as the average lift really does, so a good day moves it a few points while each lift moves
// more; a lift tried once never settles and never counts, and one dropped leaves it after [activeDays]. A rule that
// moved it by the average change of the day's lifts was tried and dropped: with each lift back every five workouts it
// counted the same progress five times over.
import 'dart:math';

import '../data/library.dart';
import '../data/model.dart';
import 'calibrate.dart';
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

  /// A day's performance: its best set, as a rating. The best and not the average: later sets are tired, and the
  /// standards are people's best efforts.
  double performance(List<({double load, int reps})> sets) => rating(sets.fold(0.0, (a, x) => max(a, x.load * epley(x.reps))));

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

/// Where an exercise is in finding the user's level: its weight still being found, found (one workout measured it), or
/// settled (a workout since confirmed it), when its changes are progress.
enum LiftStage { calibrating, calibrated, settled }

/// One workout's place in an exercise's rating: when, what the day's best set was worth, the rating after it, and the
/// stage the exercise was in by then.
typedef RatedWorkout = ({DateTime at, double performance, double rating, LiftStage stage});

/// What one workout's sets of an exercise were worth (the best set), and whether a lower one may count against the
/// user: not on an easy or low-energy day, a light exercise, or one that hurt, nor when every set reached the top of
/// the range (the user stopped where they were asked to: at least this much). Null when nothing was done or it hurt.
/// [skipCapped]: leave out calibration sets that reached the cap, which only said "at least".
({double performance, bool counts})? workoutPerformance(AppState s, Session x, int i, Rater r, {bool skipCapped = false}) {
  final e = x.exercises[i];
  var sets = e.attempted.toList();
  if (sets.isEmpty || x.painAt == i) return null;
  // once a calibration set has found the level, the ones at the cap before it only said "at least"
  if (skipCapped) sets = [for (final l in sets) if (!(l.test && (l.reps ?? 0) >= calibrationCap)) l];
  if (sets.isEmpty) return null;
  final ex = e.exercise;
  final perf = r.performance([for (final l in sets) (load: ex.loaded ? r.load(kg: setLoad(s, e, l)) : r.load(rung: l.rung ?? e.rung), reps: l.reps ?? 0)]);
  final end = endReadOf(x.endRead);
  final low = end == EndRead.energy || end == EndRead.low || x.stopReason == StopReason.energy;
  final atTop = !e.atCeiling && sets.every((l) => !l.test && (l.reps ?? 0) >= e.hi);
  return (performance: perf, counts: x.energy != Energy.easy && e.atWorkingLevel && !low && !atTop);
}

/// An exercise's rating through the user's logged workouts, oldest first, and [plus] (the workout on the finish screen,
/// not logged yet) at the end. Worked out from the history every time, so a change of birth date or weight reads it all
/// again. Each workout is rated at the age the user was that day.
List<RatedWorkout> ratingHistory(AppState s, Exercise ex, DateTime now, {Session? plus}) {
  final raters = <int?, Rater>{};
  final out = <RatedWorkout>[];
  final logged = [for (final x in s.sessions) if (x.startedAt != null && !identical(x, plus)) x]..sort((a, b) => a.startedAt!.compareTo(b.startedAt!));
  double? rating;
  var stage = LiftStage.calibrating;
  var since = 0; // workouts rated since the level was found
  for (final x in [...logged, ?plus]) {
    final i = x.exercises.indexWhere((e) => e.exId == ex.id && e.attempted.isNotEmpty);
    if (i < 0) continue;
    final e = x.exercises[i];
    final at = x.startedAt ?? now;
    final rater = raters.putIfAbsent(s.profile?.ageAt(at), () => raterFor(s, ex, at));
    final p = workoutPerformance(s, x, i, rater);
    if (p == null) continue;
    var perf = p.performance;
    if (stage == LiftStage.calibrating) {
      // calibration sets: found when one ended under the cap; older workouts and holds: when the reps landed in range
      final tested = e.sets.any((l) => l.test);
      final found = tested ? calibratedToday(e) : p.counts && foundLevel(e);
      if (found) {
        if (tested) perf = workoutPerformance(s, x, i, rater, skipCapped: true)?.performance ?? perf;
        rating = perf;
        stage = LiftStage.calibrated;
        since = 1;
      } else {
        // still finding it: the reps say at least this much
        rating = max(rating ?? perf, perf);
      }
    } else {
      rating = nextRating(rating, perf, workoutsBefore: since++, counts: p.counts);
      stage = LiftStage.settled;
    }
    out.add((at: at, performance: perf, rating: rating, stage: stage));
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

/// Calibrated lifts before the user has a first, provisional rank.
const calibratedToRank = 2;

/// Settled lifts before the rank stops being provisional.
const settledToLock = 5;

/// A lift counts toward the overall rating while it was done in this many days.
const activeDays = 42;

/// Where the user is in being ranked: not yet, a first read from the calibrated lifts, or ranked on the settled ones.
enum RankStage { unranked, provisional, ranked }

/// The overall rating after one workout. [rating]: null while unranked. [change]: what that workout's lifts did to it,
/// once ranked (null while provisional and when none of them moved; a lift joining does not count as a change).
/// [toGo]: unranked, the lifts still to calibrate; provisional, the lifts still to settle. [firstRank]: this workout
/// gave the first rank.
typedef OverallPoint = ({DateTime at, double? rating, double? change, RankStage stage, int toGo, bool firstRank});

/// The user's overall rating through their logged workouts and [plus] (the workout on the finish screen), oldest first:
/// at each workout, the average of the lifts done in the last [activeDays] (the measured ones, when any are), the
/// calibrated ones while provisional and the settled ones once ranked.
List<OverallPoint> overallHistory(AppState s, DateTime now, {Session? plus}) {
  final ids = <String>{
    for (final x in [...s.sessions, ?plus]) for (final e in x.exercises) if (e.attempted.isNotEmpty && e.exercise.isStrength && e.exercise.tracked) e.exId,
  };
  final byTime = <DateTime, List<(String, RatedWorkout)>>{};
  for (final id in ids) {
    for (final w in ratingHistory(s, exerciseById[id]!, now, plus: plus)) { (byTime[w.at] ??= []).add((id, w)); }
  }
  final measured = {for (final id in ids) id: raterFor(s, exerciseById[id]!, now).grounded};
  final latest = <String, RatedWorkout>{};
  final out = <OverallPoint>[];
  for (final at in byTime.keys.toList()..sort()) {
    final before = Map.of(latest);
    for (final (id, w) in byTime[at]!) { latest[id] = w; }
    final active = [for (final e in latest.entries) if (at.difference(e.value.at).inDays <= activeDays) e];
    final calibrated = [for (final e in active) if (e.value.stage != LiftStage.calibrating) e];
    final settled = [for (final e in active) if (e.value.stage == LiftStage.settled) e];
    final RankStage stage;
    final List<MapEntry<String, RatedWorkout>> pool;
    if (settled.length >= settledToLock) {
      stage = RankStage.ranked;
      pool = settled;
    } else if (calibrated.length >= calibratedToRank) {
      stage = RankStage.provisional;
      pool = calibrated;
    } else {
      stage = RankStage.unranked;
      pool = const [];
    }
    final firstRank = stage != RankStage.unranked && (out.isEmpty || out.last.stage == RankStage.unranked);
    if (stage == RankStage.unranked) {
      out.add((at: at, rating: null, change: null, stage: stage, toGo: calibratedToRank - calibrated.length, firstRank: false));
      continue;
    }
    final use = pool.any((e) => measured[e.key]!) ? [for (final e in pool) if (measured[e.key]!) e] : pool;
    final rating = use.fold(0.0, (a, e) => a + e.value.rating) / use.length;
    // ranked: today's lifts against their own last rating, over the lifts counted; a lift just joining moves nothing
    double? change;
    if (stage == RankStage.ranked && out.last.stage == RankStage.ranked) {
      var moved = 0.0;
      var any = false;
      for (final e in use) {
        final b = before[e.key];
        if (e.value.at == at && b != null && b.stage == LiftStage.settled) { moved += e.value.rating - b.rating; any = true; }
      }
      if (any) change = moved / use.length;
    }
    out.add((at: at, rating: rating, change: change, stage: stage, toGo: stage == RankStage.provisional ? settledToLock - settled.length : 0, firstRank: firstRank));
  }
  return out;
}

/// The user's overall rating now, with [plus] (the workout on the finish screen) counted in: the last point of
/// [overallHistory], whose change is what [plus] did to it. Null when nothing is rated.
OverallPoint? overallRating(AppState s, DateTime now, {Session? plus}) {
  final h = overallHistory(s, now, plus: plus);
  if (h.isEmpty) return null;
  final o = h.last;
  // without a workout on the finish screen there is no today to have moved it
  if (plus != null && o.at == (plus.startedAt ?? now)) return o;
  return (at: o.at, rating: o.rating, change: null, stage: o.stage, toGo: o.toGo, firstRank: false);
}

/// A lift the user is training now (done in the last [activeDays], its level found): its rating and stage, and what it
/// climbed in the last 30 days once settled (null without two settled workouts to compare).
typedef LiftStanding = ({String exId, double rating, LiftStage stage, double? climb});

/// The lifts the user is training now, strongest first, for Progress.
List<LiftStanding> standings(AppState s, DateTime now) {
  final out = <LiftStanding>[];
  final ids = <String>{for (final x in s.sessions) for (final e in x.exercises) if (e.attempted.isNotEmpty && e.exercise.isStrength && e.exercise.tracked) e.exId};
  final since = now.subtract(const Duration(days: 30));
  for (final id in ids) {
    final h = ratingHistory(s, exerciseById[id]!, now);
    if (h.isEmpty || h.last.stage == LiftStage.calibrating || now.difference(h.last.at).inDays > activeDays) continue;
    final settled = [for (final w in h) if (w.stage == LiftStage.settled) w];
    // from the last settled rating before the 30 days, else the first one inside them
    final base = settled.where((w) => !w.at.isAfter(since)).lastOrNull ?? settled.firstOrNull;
    final climb = base != null && settled.last.at.isAfter(base.at) ? settled.last.rating - base.rating : null;
    out.add((exId: id, rating: h.last.rating, stage: h.last.stage, climb: climb));
  }
  out.sort((a, b) => b.rating.compareTo(a.rating));
  return out;
}

/// The overall rating's line over time, for Progress: at each workout, the average of the lifts counted now (the ones
/// [overallRating] averages today), each at its rating then, or its first rating before it had one. So the line moves
/// only as those lifts did (a weaker lift settling later does not read as a drop), ends at today's number, and runs back
/// before the first rank. Empty while unranked.
List<({DateTime at, double rating})> overallLine(AppState s, DateTime now) {
  final o = overallRating(s, now);
  if (o == null || o.stage == RankStage.unranked) return const [];
  final counted = <String, List<RatedWorkout>>{};
  final ids = <String>{for (final x in s.sessions) for (final e in x.exercises) if (e.attempted.isNotEmpty && e.exercise.isStrength && e.exercise.tracked) e.exId};
  for (final id in ids) {
    final h = ratingHistory(s, exerciseById[id]!, now);
    if (h.isEmpty || o.at.difference(h.last.at).inDays > activeDays) continue;
    final ok = o.stage == RankStage.ranked ? h.last.stage == LiftStage.settled : h.last.stage != LiftStage.calibrating;
    if (ok) counted[id] = [for (final w in h) if (w.stage != LiftStage.calibrating) w];
  }
  final measured = counted.keys.where((id) => raterFor(s, exerciseById[id]!, now).grounded).toList();
  final use = measured.isNotEmpty ? measured : counted.keys.toList();
  if (use.isEmpty) return const [];
  final times = <DateTime>{for (final id in use) for (final w in counted[id]!) w.at}.toList()..sort();
  return [
    for (final at in times)
      (at: at, rating: use.fold(0.0, (a, id) {
        final h = counted[id]!;
        return a + (h.where((w) => !w.at.isAfter(at)).lastOrNull ?? h.first).rating;
      }) / use.length),
  ];
}
