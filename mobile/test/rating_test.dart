import 'dart:math';

import 'package:easyday/data/library.dart';
import 'package:easyday/data/model.dart';
import 'package:easyday/logic/after.dart';
import 'package:easyday/logic/calibrate.dart';
import 'package:easyday/logic/workout.dart';
import 'package:easyday/logic/ladder.dart';
import 'package:easyday/logic/rating.dart';
import 'package:easyday/logic/score.dart';
import 'package:flutter_test/flutter_test.dart';

import 'score_test.dart' as sc;
import 'workout_test.dart' as w;

void main() {
  final squat = exerciseById['bb_squat']!;
  final pushup = exerciseById['pushup']!;
  final pullup = exerciseById['pullup']!;
  Rater man({double bw = 80, int age = 30}) => Rater(squat, sex: Sex.man, bodyweight: bw, age: age);

  test('three parts lifters, one part everyone: an untrained adult is Bronze, a typical lifter Gold, an elite one Champion', () {
    final r = man();
    // studies put untrained adults at about 0.95 of the lifters' 5 % mark
    final untrained = r.rating(r.lifterTiers[0] * 0.95), median = r.rating(r.lifterTiers[2]), elite = r.rating(r.lifterTiers[4]);
    expect(untrained, closeTo(829, 15));
    expect(rankOf(untrained).name, 'Bronze');
    expect(median, closeTo(1306, 15));
    expect(rankOf(median).name, 'Gold');
    expect(elite, closeTo(1823, 20));
    expect(rankOf(elite).name, 'Champion');
    expect(Rater.percentile(1200), closeTo(50, 1e-6));
  });

  test('a strong lifter\'s first workout rates high at once, and any rating turns back into a lift', () {
    final r = man();
    expect(nextRating(null, r.performance([(load: 140, reps: 8), (load: 140, reps: 8)]), workoutsBefore: 0), greaterThan(1600));
    expect(r.strength(r.setRating(100, 10)), closeTo(100 * (1 + 10 / 30), 0.01));
    expect(r.repsAt(r.setRating(100, 10), 100), closeTo(10, 0.01));
    expect(r.setRating(105, 8), closeTo(r.setRating(100, 10), 15), reason: 'heavier for fewer reps: about the same');
  });

  test('age and weight ground it: the same lift rates higher at 60 than at 30, and lower for a heavier body', () {
    expect(man(age: 35).setRating(100, 10), closeTo(man(age: 30).setRating(100, 10), 1e-9), reason: 'no change from 20 to 39');
    expect(man(age: 60).setRating(100, 10), greaterThan(man(age: 30).setRating(100, 10) + 100));
    expect(man(bw: 100).setRating(100, 10), lessThan(man(bw: 70).setRating(100, 10)));
    expect(ageFactor(60), closeTo(0.77, 1e-9));
  });

  test('push-up versions land on the push-up standard, and the standard knows bodyweight', () {
    final r = Rater(pushup, sex: Sex.man, bodyweight: 80, age: 30);
    final full = pushup.ladder!.variants.indexWhere((v) => v.name == 'Push-ups');
    expect(r.setRating(r.load(rung: full + 1), 10), greaterThan(r.setRating(r.load(rung: full), 10)));
    // a heavier body does fewer push-ups, so the same 50 rate higher
    expect(Rater(pushup, sex: Sex.man, bodyweight: 110, age: 30).setRating(r.load(rung: full), 50), greaterThan(r.setRating(r.load(rung: full), 50)));
  });

  test('every strength exercise the app tracks has a standard, its tiers rising, at every bodyweight', () {
    for (final ex in builtInExercises.where((e) => e.isStrength && e.tracked)) {
      final st = exerciseStandards[ex.id];
      expect(st, isNotNull, reason: ex.id);
      for (final rows in [st!.man, st.woman]) {
        for (final row in rows) {
          for (var k = 2; k <= 5; k++) { expect(row[k], greaterThan(row[k - 1]), reason: '${ex.id} at ${row[0]} kg'); }
        }
      }
      expect(st.basis == Basis.estimated || st.from.isNotEmpty, isTrue, reason: '${ex.id} names its sources');
    }
    // the dumbbell curl is measured now; band curls are still estimated from their start
    expect(Rater(exerciseById['db_curl']!, sex: Sex.man, bodyweight: 80, age: 30).basis, Basis.measured);
    expect(Rater(exerciseById['band_curl']!, sex: Sex.man, bodyweight: 80, age: 30).grounded, isFalse);
  });

  test('one scale: the same place among lifters rates the same on every exercise', () {
    final squatR = Rater(squat, sex: Sex.woman, bodyweight: 70, age: 30);
    for (final ex in builtInExercises.where((e) => e.isStrength && e.tracked)) {
      final r = Rater(ex, sex: Sex.woman, bodyweight: 70, age: 30);
      if (r.standard.everyone != squatR.standard.everyone) continue;
      expect(r.rating(r.lifterTiers[2]), closeTo(squatR.rating(squatR.lifterTiers[2]), 1e-6), reason: '${ex.id}: the median');
      for (final k in [1, 3]) {
        expect(r.rating(r.lifterTiers[k]), closeTo(squatR.rating(squatR.lifterTiers[k]), 20), reason: '${ex.id}, tier $k: lifts spread a little unevenly');
      }
    }
  });

  test('the bodyweight tables read between rows, and the assisted machine is read on the pull-up standard', () {
    final st = exerciseStandards['bb_bench']!;
    final row = st.man.firstWhere((r) => r[0] == 80);
    expect(st.tiersAt(Sex.man, 80)[2], closeTo(row[3], 1e-9));
    expect(st.tiersAt(Sex.man, 85)[2], inInclusiveRange(row[3], st.man.firstWhere((r) => r[0] == 90)[3]));
    final assisted = Rater(exerciseById['assisted_pullup']!, sex: Sex.man, bodyweight: 80, age: 30);
    final pull = Rater(exerciseById['pullup']!, sex: Sex.man, bodyweight: 80, age: 30);
    final full = pullup.ladder!.variants.indexWhere((v) => v.name == 'Pull-ups');
    // no assist (the machine's load at assistRefKg) is a full pull-up; more assist rates lower
    expect(assisted.setRating(assisted.load(kg: assistRefKg), 8), closeTo(pull.setRating(pull.load(rung: full), 8), 1));
    expect(assisted.setRating(assisted.load(kg: assistRefKg - 30), 8), lessThan(assisted.setRating(assisted.load(kg: assistRefKg - 10), 8)));
    expect(assisted.kgFor(assisted.load(kg: 55)), closeTo(55, 1e-9));
  });

  test('the rating moves part of the way to a workout, and a day that does not count never lowers it', () {
    expect(nextRating(null, 1500, workoutsBefore: 0), 1500);
    expect(nextRating(1500, 1600, workoutsBefore: 1), 1550);
    expect(nextRating(1500, 1600, workoutsBefore: 5), 1525);
    expect(nextRating(1500, 1400, workoutsBefore: 5, counts: false), 1500);
  });

  test('the profile keeps the age and weight it is ranked by', () {
    final p = Profile(experience: 'some', daysPerWeek: 3, createdAt: DateTime(2026), birthDate: DateTime(1990, 6, 15), bodyweightKg: 82.5);
    final back = Profile.fromJson(p.toJson());
    expect(back.birthDate, DateTime(1990, 6, 15));
    expect(back.ageAt(DateTime(2026, 6, 14)), 35, reason: 'the day before the birthday');
    expect(back.ageAt(DateTime(2026, 6, 15)), 36, reason: 'on the birthday');
    expect(back.bodyweightKg, 82.5);
    expect(Profile.fromJson(Profile(experience: 'some', daysPerWeek: 3, createdAt: DateTime(2026)).toJson()).birthDate, isNull);
    // a profile saved with only a birth year reads as 1 January of it
    final old = Profile.fromJson({'experience': 'some', 'daysPerWeek': 3, 'createdAt': 0, 'birthYear': 1990});
    expect(old.birthDate, DateTime(1990));
    expect(old.ageAt(DateTime(2026, 11)), 36);
  });

  test("the user's rating comes from their logged workouts, and the one on the finish screen counts as the next", () {
    final s = w.fresh(template: 'gym')..profile!.birthDate = DateTime(1996, 5, 1)..profile!.bodyweightKg = 80;
    final a = sc.play(s, [[10, 10, 10]]);
    finishSession(s, a, Finish(endRead: EndRead.none), a.endedAt!);
    final ex = a.exercises[0].exercise;
    final one = ratingHistory(s, ex, w.t0);
    expect(one.length, 1);
    final b = sc.play(s, [[12, 12, 12]])..startedAt = w.t0.add(const Duration(days: 2));
    final two = ratingHistory(s, ex, w.t0, plus: b);
    expect(two.length, 2);
    expect(two.last.performance, greaterThan(two.first.performance));
    expect(two.last.rating, closeTo(one.last.rating + 0.5 * (two.last.performance - one.last.rating), 1e-6), reason: 'half the way while new');
  });

  test("an easy day never lowers the user's rating", () {
    final s = w.fresh(template: 'gym');
    final a = sc.play(s, [[12, 12, 12]]);
    finishSession(s, a, Finish(endRead: EndRead.none), a.endedAt!);
    final ex = a.exercises[0].exercise;
    final before = ratingHistory(s, ex, w.t0).last.rating;
    final b = sc.play(s, [[5, 5, 5]])..startedAt = w.t0.add(const Duration(days: 2))..energy = Energy.easy;
    expect(ratingHistory(s, ex, w.t0, plus: b).last.rating, before);
  });

  test('older workouts without calibration sets: reps over the top only lift the rating; the first in range sets it', () {
    final s = w.fresh(template: 'gym');
    final a = sc.play(s, [[25, 25, 25]]);
    finishSession(s, a, Finish(endRead: EndRead.none), a.endedAt!);
    final ex = a.exercises[0].exercise;
    expect(ratingHistory(s, ex, w.t0).single.stage, LiftStage.calibrating, reason: 'over the top: the weight is too light to say');
    final hi = a.exercises[0].hi + 1;
    final b = sc.play(s, [[hi, hi, hi]])..startedAt = w.t0.add(const Duration(days: 2));
    final two = ratingHistory(s, ex, w.t0, plus: b);
    expect(two.last.stage, LiftStage.calibrating);
    expect(two.last.rating, max(two.first.rating, two.last.performance), reason: 'a floor: it can only rise');
    finishSession(s, b, Finish(endRead: EndRead.none), b.endedAt!);
    final c = sc.play(s, [[10, 10, 10]])..startedAt = w.t0.add(const Duration(days: 4));
    final three = ratingHistory(s, ex, w.t0, plus: c);
    expect(three.last.stage, LiftStage.calibrated);
    expect(three.last.rating, three.last.performance, reason: 'the level found: set outright, not pulled');
    finishSession(s, c, Finish(endRead: EndRead.none), c.endedAt!);
    final d = sc.play(s, [[11, 11, 11]])..startedAt = w.t0.add(const Duration(days: 6));
    expect(ratingHistory(s, ex, w.t0, plus: d).last.stage, LiftStage.settled, reason: 'one more workout at the weight');
  });

  test('a rating reads the best set of the day, not the average', () {
    final s = w.fresh(template: 'gym');
    final a = sc.play(s, [[12, 8, 6]]);
    finishSession(s, a, Finish(endRead: EndRead.none), a.endedAt!);
    final e = a.exercises[0];
    final r = raterFor(s, e.exercise, w.t0);
    final kg = e.attempted.first.kg ?? e.loadKg!;
    expect(ratingHistory(s, e.exercise, w.t0).single.performance, closeTo(r.rating(r.load(kg: kg) * epley(12)), 1e-6));
  });

  // one logged workout of known lifts, [days] after the start, every set of each exercise at its reps
  Session day(AppState s, int days, List<int> reps) {
    final x = sc.play(s, [for (final r in reps) [r, r, r]], minutes: 90);
    final shift = Duration(days: days);
    x.startedAt = x.startedAt!.add(shift);
    finishSession(s, x, Finish(endRead: EndRead.none), x.endedAt!.add(shift));
    return x;
  }

  // a workout played from the start with calibration sets: the first sets of each exercise as many as the user can
  Session calibrate(AppState s, List<List<int>> reps, {int days = 0}) {
    final x = w.build(s, warmup: 0, minutes: 90);
    if (days == 0) { for (final e in x.exercises) { expect(e.calibrating, isTrue, reason: '${e.exercise.name} is new'); } }
    final at = w.t0.add(Duration(days: days));
    startWorkout(s, x, at);
    var t = at;
    for (var i = 0; i < x.exercises.length && i < reps.length; i++) {
      for (final r in reps[i]) {
        t = t.add(const Duration(seconds: 40));
        logReps(s, x, r, t);
        t = t.add(const Duration(seconds: 90));
        ready(x, t);
      }
    }
    endWorkout(x, t);
    return x;
  }

  test('a calibration set under the cap calibrates the exercise there and then; the sets after are working sets at its weight', () {
    final s = w.fresh(template: 'gym');
    final x = calibrate(s, [[14, 10, 10]]);
    final e = x.exercises[0];
    expect(e.sets[0].test, isTrue);
    expect(e.sets[1].test, isFalse, reason: 'found: the rest are working sets');
    final kg0 = e.sets[0].kg!, kg1 = e.sets[1].kg!;
    final step = stepKg(s, e.exercise);
    // the weight that 14 reps (and the one left in the tank) is worth in the middle of today's range, on the grid
    final worth = kg0 * epley(15) / epley(((e.lo + e.hi) / 2).round());
    expect(kg1, lessThanOrEqualTo(worth + step), reason: 'about what the set was worth');
    expect(kg1, greaterThan(kg0), reason: '14 reps in an ${e.lo} to ${e.hi} range: heavier');
    final st = s.ex[e.exId]!;
    expect(st.calibrating, isFalse);
    finishSession(s, x, Finish(endRead: EndRead.none), x.endedAt!);
    expect(loadFor(s, e.exercise, st, st.rung, e.range), closeTo(kg1, 1e-6), reason: 'the found weight is the level next time');
    final h = ratingHistory(s, e.exercise, w.t0);
    expect(h.single.stage, LiftStage.calibrated);
    final r = raterFor(s, e.exercise, w.t0);
    expect(h.single.rating, greaterThanOrEqualTo(r.rating(r.load(kg: kg0) * epley(14)) - 1e-6), reason: 'at least what the calibration set showed');
    expect(h.single.rating, lessThan(r.rating(r.load(kg: kg0) * epley(14 + leftInTheTank)) + 30), reason: 'the rep in the tank sets the weight, not the rating');
  });

  test('at the cap the next set is heavier and another calibration set; a newcomer jumps at most a quarter', () {
    final s = w.fresh(template: 'gym');
    final x = calibrate(s, [[calibrationCap, 9, 9]]);
    final e = x.exercises[0];
    expect(e.sets[0].test, isTrue);
    expect(e.sets[1].test, isTrue, reason: 'the cap said only "at least"');
    expect(e.sets[2].test, isFalse, reason: '9 reps found it');
    final kg0 = e.sets[0].kg!, kg1 = e.sets[1].kg!;
    expect(kg1, greaterThanOrEqualTo(kg0 * epley(calibrationCap + leftInTheTank) / epley(((e.lo + e.hi) / 2).round()) - stepKg(s, e.exercise)));
    final newcomer = w.fresh(template: 'gym')..profile!.experience = 'new';
    final y = calibrate(newcomer, [[calibrationCap, 9]]);
    expect(y.exercises[0].sets[1].kg!, lessThanOrEqualTo(y.exercises[0].sets[0].kg! * newcomerJump + 1e-6));
  });

  test('three calibration sets at the cap leave it calibrating, starting heavier next time', () {
    final s = w.fresh(template: 'gym');
    final x = calibrate(s, [[calibrationCap, calibrationCap, calibrationCap]]);
    final e = x.exercises[0];
    expect([for (final l in e.sets) l.test], [true, true, true]);
    expect(s.ex[e.exId]!.calibrating, isTrue);
    finishSession(s, x, Finish(endRead: EndRead.none), x.endedAt!);
    expect(ratingHistory(s, e.exercise, w.t0).single.stage, LiftStage.calibrating);
    expect(loadFor(s, e.exercise, s.ex[e.exId]!, s.ex[e.exId]!.rung, e.range), greaterThan(e.sets[2].kg!), reason: 'where the last set said');
  });

  test('a calibration set with nothing done goes lighter and tries again', () {
    final s = w.fresh(template: 'gym');
    final x = calibrate(s, [[0, 10, 10]]);
    final e = x.exercises[0];
    expect(e.sets[1].test, isTrue);
    expect(e.sets[1].kg!, lessThan(e.sets[0].kg!));
  });

  test('unranked until two lifts are calibrated, provisional until five have settled, then the average of the settled ones', () {
    final s = w.fresh(template: 'gym');
    final a = calibrate(s, [[12, 10, 10]]);
    final one = overallRating(s, w.t0, plus: a)!;
    if (a.exercises.length == 1) {
      expect(one.stage, RankStage.unranked);
      expect(one.toGo, 1);
    }
    finishSession(s, a, Finish(endRead: EndRead.none), a.endedAt!);
    // every lift found in its first workout, every workout after it the same reps
    OverallPoint? o;
    for (var d = 2; d < 60 && o?.stage != RankStage.ranked; d += 2) {
      final x = calibrate(s, [for (var k = 0; k < 6; k++) [12, 10, 10]], days: d);
      o = overallRating(s, w.t0, plus: x);
      if (o!.stage == RankStage.provisional) expect(o.rating, isNotNull);
      finishSession(s, x, Finish(endRead: EndRead.none), x.endedAt!);
    }
    final h = overallHistory(s, w.t0);
    expect(h.where((p) => p.firstRank).length, 1);
    final first = h.indexWhere((p) => p.stage != RankStage.unranked);
    expect(h[first].stage, RankStage.provisional);
    final at = h.indexWhere((p) => p.stage == RankStage.ranked);
    expect(at, greaterThan(first));
    // ranked: the average of the settled lifts done in the last six weeks
    final settled = <double>[];
    for (final id in {for (final x in s.sessions) for (final e in x.exercises) if (e.attempted.isNotEmpty) e.exId}) {
      final r = ratingHistory(s, exerciseById[id]!, w.t0).where((r) => !r.at.isAfter(h[at].at)).lastOrNull;
      if (r != null && r.stage == LiftStage.settled && h[at].at.difference(r.at).inDays <= activeDays && raterFor(s, exerciseById[id]!, r.at).grounded) settled.add(r.rating);
    }
    expect(settled, isNotEmpty);
    expect(h[at].rating, closeTo(settled.reduce((x, y) => x + y) / settled.length, 1e-6));
  });

  test("once ranked, a workout's change is its lifts' movement over every lift counted, and a lift unused for six weeks drops out", () {
    final s = w.fresh(template: 'gym');
    var d = 0;
    for (; d < 60 && overallRating(s, w.t0)?.stage != RankStage.ranked; d += 2) { day(s, d, [10, 10, 10, 10, 10, 10]); }
    expect(overallRating(s, w.t0)!.stage, RankStage.ranked);
    // a workout with a settled lift in it, a better day for it
    Session? x;
    OverallPoint? after;
    for (var k = 0; k < 10 && after?.change == null; k++, d += 2) {
      x = sc.play(s, [[14, 14, 14], [10, 10, 10]], minutes: 90);
      x.startedAt = x.startedAt!.add(Duration(days: d));
      after = overallRating(s, w.t0, plus: x);
      if (after!.change == null) finishSession(s, x, Finish(endRead: EndRead.none), x.endedAt!.add(Duration(days: d)));
    }
    expect(after!.change, isNotNull);
    // the change: the lifts counted that moved today, over every lift counted
    final h = overallHistory(s, w.t0, plus: x);
    final last = h.last, prev = h[h.length - 2];
    expect(after.change!, greaterThan(0));
    expect(after.change!.abs(), lessThan(30), reason: 'a few points: the day over every lift counted');
    expect(last.rating! - prev.rating!, closeTo(after.change!, 1e-6), reason: 'nothing joined or left today');
    // far later, only what was done lately counts
    final late = sc.play(s, [[10, 10, 10]]);
    late.startedAt = late.startedAt!.add(Duration(days: d + 200));
    final o = overallRating(s, w.t0, plus: late)!;
    expect(o.stage, isNot(RankStage.ranked), reason: 'one lift active is not enough to rank');
  });

  test("Progress's line ends at today's number and moves only as the lifts counted today did", () {
    final s = w.fresh(template: 'gym');
    for (var d = 0; d < 60 && overallRating(s, w.t0)?.stage != RankStage.ranked; d += 2) { day(s, d, [10, 10, 10, 10, 10, 10]); }
    // the same lifts, better and better
    for (var k = 0; k < 6; k++) { day(s, 70 + 2 * k, [11 + k ~/ 2, 11 + k ~/ 2, 11 + k ~/ 2, 11 + k ~/ 2, 11 + k ~/ 2, 11 + k ~/ 2]); }
    final line = overallLine(s, w.t0);
    expect(line, isNotEmpty);
    expect(line.last.rating, closeTo(overallRating(s, w.t0)!.rating!, 1e-6));
    for (var i = 1; i < line.length; i++) {
      expect(line[i].rating, greaterThanOrEqualTo(line[i - 1].rating - 1e-6), reason: 'no lift got weaker, so the line never falls');
    }
  });
}
