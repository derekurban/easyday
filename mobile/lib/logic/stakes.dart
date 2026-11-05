// What today's workout could do to the ratings, for Today: each lift's rating and stage now, where a good day would
// take it, and the same for the overall rating. A good day is every set at the top of its range at the planned weight,
// or, where the rating already says the user does that, one rep more than it says; worked out on a copy of the plan,
// nothing is logged. A lift calibrating today has no good day yet: it finds its
// weight, and its first rating comes from that.
import 'dart:math';

import '../data/model.dart';
import 'rating.dart';

/// One lift of today's plan: its rating and stage now (null before it has any), the rating a good day would leave it
/// at (null while calibrating today), and whether it calibrates today.
typedef LiftStake = ({double? rating, LiftStage? stage, double? good, bool calibrating});

/// Today's stakes: one per exercise of the plan, in its order; the overall rating now; and what a good day would do to
/// it (null unless ranked, and when a good day moves nothing). [calibrating]: lifts that calibrate today.
typedef Stakes = ({List<LiftStake> lifts, OverallPoint? overall, double? goodChange, int calibrating});

Stakes stakesFor(AppState s, Session plan, DateTime now) {
  final good = Session.fromJson(plan.toJson())..startedAt = now..endedAt = now;
  for (final e in good.exercises) {
    if (e.calibrating) continue; // its sets stay empty: nothing to rate until it is found
    // the top of the range, or one rep past what the rating is worth at today's weight
    var reps = e.target;
    final ex = e.exercise;
    final rated = ex.isStrength && ex.tracked ? ratingHistory(s, ex, now).lastOrNull : null;
    if (rated != null) {
      final r = raterFor(s, ex, now);
      final load = ex.loaded ? r.load(kg: e.loadKg ?? 0) : r.load(rung: e.rung);
      if (load > 0) reps = max(reps, min(e.hi + 6, r.repsAt(rated.rating, load).floor() + 1));
    }
    for (final x in e.sets) {
      x.reps = reps;
      x.at = now;
      x.rung = e.rung;
      x.kg = e.loadKg;
    }
  }
  final lifts = <LiftStake>[];
  for (var i = 0; i < plan.exercises.length; i++) {
    final e = plan.exercises[i];
    final ex = e.exercise;
    if (!ex.isStrength || !ex.tracked) {
      lifts.add((rating: null, stage: null, good: null, calibrating: false));
      continue;
    }
    final h = ratingHistory(s, ex, now);
    final g = e.calibrating ? null : ratingHistory(s, ex, now, plus: good).lastOrNull;
    lifts.add((
      rating: h.lastOrNull?.rating,
      stage: h.lastOrNull?.stage,
      good: g != null && g.at == now ? g.rating : null,
      calibrating: e.calibrating,
    ));
  }
  final overall = overallRating(s, now);
  final after = overall?.stage == RankStage.ranked ? overallRating(s, now, plus: good) : null;
  return (lifts: lifts, overall: overall, goodChange: after?.change, calibrating: plan.exercises.where((e) => e.calibrating).length);
}
