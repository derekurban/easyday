import 'package:easyday/data/library.dart';
import 'package:easyday/data/model.dart';
import 'package:easyday/logic/after.dart';
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

  test("the overall rating averages every rated exercise, and a first rating on a new one never reads as a change", () {
    final s = w.fresh(template: 'gym');
    final a = sc.play(s, [[10, 10, 10]]);
    finishSession(s, a, Finish(endRead: EndRead.none), a.endedAt!);
    final before = overallRating(s, w.t0)!;
    expect(before.change, isNull);
    final b = sc.play(s, [[12, 12, 12], [10, 10, 10]])..startedAt = w.t0.add(const Duration(days: 2));
    final after = overallRating(s, w.t0, plus: b)!;
    final squat = ratingHistory(s, a.exercises[0].exercise, w.t0, plus: b);
    expect(after.change, closeTo(squat.last.rating - squat.first.rating, 1e-6), reason: 'only the exercise rated before moves it');
  });
}
