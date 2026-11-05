import 'package:easyday/data/library.dart';
import 'package:easyday/data/model.dart';
import 'package:easyday/logic/after.dart';
import 'package:easyday/logic/ladder.dart';
import 'package:easyday/logic/score.dart';
import 'package:easyday/logic/workout.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workout_test.dart' as w;

/// A workout played through the workout logic: [reps] per exercise, each set [lift] s, [rest] s before the next.
Session play(AppState s, List<List<int>> reps, {int lift = 35, int rest = 90, int? endAfter, int minutes = 45, Map<int, int> change = const {}}) {
  final x = w.build(s, warmup: 0, minutes: minutes);
  for (final e in x.exercises) { ensureState(s, e.exercise)..appearances = 3..calibrating = false; e.calibrating = false; }
  // the user moving the weight mid-workout, as the drawer does: + heavier, - lighter, in plate steps
  for (final c in change.entries) { changeLevel(s, x, c.key, kg: x.exercises[c.key].loadKg! + c.value * stepKg(s, x.exercises[c.key].exercise)); }
  startWorkout(s, x, w.t0);
  var t = w.t0;
  for (var i = 0; i < x.exercises.length && i < reps.length; i++) {
    for (final r in reps[i]) {
      t = t.add(Duration(seconds: lift));
      enterReps(x, r, t);
      t = t.add(Duration(seconds: rest));
      ready(x, t);
    }
  }
  endWorkout(x, endAfter == null ? t : w.t0.add(Duration(minutes: endAfter)));
  return x;
}

void main() {
  group('shares', () {
    test('push-up versions use the measured shares; knee to full needs 18 knee push-ups in a 6 to 10 range', () {
      final ex = exerciseById['pushup']!;
      expect(versionShare(ex, 2), 0.49);
      expect(versionShare(ex, 3), 0.64);
      final s = w.fresh(template: 'none');
      final x = w.build(s, warmup: 0);
      final e = x.exercises.firstWhere((e) => e.exId == 'pushup', orElse: () => x.exercises.first);
      if (e.exId != 'pushup') return;
      e..lo = 6..hi = 10..atCeiling = false;
      expect(repsToStepUp(s, e, rung: 2), 18);
    });

    test('a ladder with nothing measured steps by the estimate', () {
      final ex = exercises.firstWhere((e) => e.ladder != null && e.ladder!.variants.every((v) => !measuredShare.containsKey(v.name)));
      expect(versionShare(ex, 1) / versionShare(ex, 0), closeTo(estimatedStep, 1e-9));
    });
  });

  group('how it ended', () {
    test('every set done reads as finished; a fade of 15 % or more reads as a low-energy day', () {
      final s = w.fresh(template: 'gym');
      final done = play(s, [for (var i = 0; i < 8; i++) [12, 12, 12]]);
      expect(readWorkout(s, done, w.t0).guess, EndRead.done);
      final s2 = w.fresh(template: 'gym');
      final faded = play(s2, [for (var i = 0; i < 8; i++) [12, 10, 8]]);
      expect(readWorkout(s2, faded, w.t0).guess, EndRead.low);
    });

    test('ended early: the clock says time, a fade says energy, both ask', () {
      final s = w.fresh(template: 'gym');
      expect(readWorkout(s, play(s, [[12, 12, 12]], endAfter: 40), w.t0).guess, EndRead.time);
      final s2 = w.fresh(template: 'gym');
      expect(readWorkout(s2, play(s2, [[12, 9, 6]], endAfter: 10), w.t0).guess, EndRead.energy);
      final s3 = w.fresh(template: 'gym');
      expect(readWorkout(s3, play(s3, [[12, 9, 6]], endAfter: 40), w.t0).guess, EndRead.ask);
      final s4 = w.fresh(template: 'gym');
      expect(readWorkout(s4, play(s4, [[12, 12, 12]], endAfter: 10), w.t0).guess, EndRead.none);
    });

    test('the user\'s word wins, and an energy day steps nothing down', () {
      final s = w.fresh(template: 'gym');
      final x = play(s, [[3, 3, 3]], endAfter: 40);
      final st = s.ex[x.exercises[0].exId]!..shortRun = 1;
      x.endRead = EndRead.energy.name;
      final r = readWorkout(s, x, w.t0);
      expect(r.end, EndRead.energy);
      expect(r.exercises[0].short, isTrue);
      expect(r.exercises[0].auto, Call.hold);
      x.endRead = EndRead.time.name;
      expect(readWorkout(s, x, w.t0).exercises[0].auto, Call.down, reason: 'short twice on a normal day');
      expect(st.shortRun, 1);
    });
  });

  group('changing it on Logged', () {
    test('a pill change is what gets logged', () {
      final s = w.fresh(template: 'gym');
      final x = play(s, [for (var i = 0; i < 8; i++) [12, 12, 12]]);
      final e = x.exercises[0];
      final before = s.ex[e.exId]!.rung;
      expect(readWorkout(s, x, w.t0).exercises[0].auto, Call.up);
      e.call = Call.hold.name;
      finishSession(s, x, Finish(endRead: EndRead.done), x.endedAt!);
      expect(s.ex[e.exId]!.rung, before);
      expect(x.reviewing, isFalse);
    });

    test('a set said to take less moves everything after it, the end too; the rest after stays', () {
      final s = w.fresh(template: 'gym');
      final x = play(s, [[12, 12, 12], [12, 12, 12]]);
      const r = (ex: 0, set: 0);
      final end = x.endedAt!, rest = restAfterOf(x, r);
      expect(setSecondsOf(x, r), 35);
      setSetSeconds(x, r, 20);
      expect(setSecondsOf(x, r), 20);
      expect(restAfterOf(x, r), rest);
      expect(x.endedAt, end.subtract(const Duration(seconds: 15)));
      setRestAfter(x, r, 60);
      expect(restAfterOf(x, r), 60);
      expect(setSecondsOf(x, (ex: 0, set: 1)), 35, reason: 'the next set keeps its own time');
    });

    test('one set at another weight scores at that weight', () {
      final s = w.fresh(template: 'gym');
      final x = play(s, [[10, 10, 10]]);
      final e = x.exercises[0];
      final a = readWorkout(s, x, w.t0).exercises[0].avg;
      fixSetLevel(s, x, (ex: 0, set: 2), kg: e.loadKg! + 10);
      expect(readWorkout(s, x, w.t0).exercises[0].avg, greaterThan(a));
    });

    test('back to the workout counts the time on Logged as a pause', () {
      final s = w.fresh(template: 'gym');
      final x = play(s, [[12, 12, 12]], endAfter: 10);
      final start = x.startedAt!;
      reopenWorkout(x, x.endedAt!.add(const Duration(minutes: 5)));
      expect(x.reviewing, isFalse);
      expect(x.endedAt, isNull);
      expect(x.startedAt, start.add(const Duration(minutes: 5)));
    });

    test('a rest of nothing stays a rest of nothing, can be turned back up, and the set keeps its own time', () {
      final s = w.fresh(template: 'gym');
      final x = play(s, [[12, 12, 12]]);
      for (final r in [(ex: 0, set: 0), (ex: 0, set: 2)]) { // between sets, and the last set of the workout
        setRestAfter(x, r, 0);
        expect(restAfterOf(x, r), 0, reason: '$r');
        expect(setSecondsOf(x, r), 35, reason: '$r');
        setRestAfter(x, r, 30);
        expect(restAfterOf(x, r), 30, reason: '$r');
        expect(setSecondsOf(x, r), 35, reason: '$r');
      }
      expect(setSecondsOf(x, (ex: 0, set: 1)), 35, reason: 'the next set keeps its own time');
    });
  });

  group('what the finish says', () {
    // three exercises at the gym; the moments read against no history, so the plain ones are firsts
    List<int> at(int reps) => [reps, reps, reps];

    test('chose heavier and made every set: the push leads, and it celebrates', () {
      final s = w.fresh(template: 'gym');
      final x = play(s, [at(9), at(8), at(8)], change: const {0: 1});
      final m = momentsOf(s, x, readWorkout(s, x, w.t0));
      expect(m.first.moment, Moment.pushed);
      expect(m.first.text, startsWith('Went up to'));
      final tone = toneOf(m, readWorkout(s, x, w.t0));
      expect(tone, Tone.celebrate);
      expect(toneHeadline(tone, m), 'You went heavier, and made it.');
    });

    test('reached for more and fell short: encouraged, not read as a hard day', () {
      final s = w.fresh(template: 'gym');
      final x = play(s, [[5, 4, 3], at(8), at(8)], change: const {0: 2});
      final r = readWorkout(s, x, w.t0);
      final m = momentsOf(s, x, r);
      expect(m.first.moment, Moment.reached);
      expect(toneOf(m, r), Tone.encourage);
      expect(toneHeadline(Tone.encourage, m), 'You reached for more.');
    });

    test('eased off partway: said plainly, and the day stays calm', () {
      final s = w.fresh(template: 'gym');
      final x = play(s, [at(8), at(8), at(8)], change: const {1: -1});
      final m = momentsOf(s, x, readWorkout(s, x, w.t0));
      expect(m[1].moment, Moment.eased);
      expect(m[1].text, startsWith('Eased to'));
    });
  });

  group('finishing and calibrating', () {
    test('finished means every set of every planned exercise; leaving one out is finishing early', () {
      final s = w.fresh(template: 'gym');
      final x = play(s, [for (var i = 0; i < 8; i++) [12, 12, 12]]);
      expect(finishedPlan(x), isTrue);
      final s2 = w.fresh(template: 'gym');
      final y = play(s2, [[12, 12, 12]]);
      y.skipped.addAll([for (var i = 1; i < y.exercises.length; i++) i]);
      expect(finishedPlan(y), isFalse, reason: 'skipped on purpose still means the plan was not all done');
      expect(readWorkout(s2, y, w.t0).finished, isFalse);
    });

    test('a rep band picked while calibrating becomes the exercise\'s own when the workout is logged', () {
      final s = w.fresh(template: 'gym');
      final x = play(s, [[8, 8, 8]]);
      x.exercises[0].reps = 'heavy';
      finishSession(s, x, Finish(endRead: EndRead.none), x.endedAt!);
      expect(s.ex[x.exercises[0].exId]!.repsOverride, expressionRange[Expression.heavy]);
    });

    test('a first time is the right level, unless the reps say plainly otherwise', () {
      final s = w.fresh(template: 'gym');
      final x = play(s, [[12, 12, 12], [20, 20, 20], [3, 3, 3]]);
      for (final e in x.exercises) { ensureState(s, e.exercise)..appearances = 0..calibrating = true; }
      final r = readWorkout(s, x, w.t0);
      expect(r.exercises[0].call, Call.hold, reason: 'the top of the range on a first go: Right');
      expect(r.exercises[1].call, Call.up, reason: 'far past the range: Harder');
      expect(r.exercises[2].call, Call.down, reason: 'far under the range: Easier');
      expect(momentsOf(s, x, r).first.text, isNot(contains('Next time')), reason: "where it goes is the row's own word");
    });

    test('a level picked on the wheel is where it lands next time', () {
      final s = w.fresh(template: 'gym');
      final x = play(s, [[12, 12, 12]]);
      final e = x.exercises[0];
      final st = ensureState(s, e.exercise)..appearances = 0;
      final from = st.rung;
      e..call = 'up'..next = from + 3;
      final r = readWorkout(s, x, w.t0).exercises[0];
      expect(r.call, Call.up);
      expect(r.levels[Call.up], from + 3);
      expect(r.outcome, rungLabel(s, e.exercise, st, from + 3, e.range, s.location(x.locationId)?.equipment));
      finishSession(s, x, Finish(endRead: EndRead.none), x.endedAt!);
      expect(s.ex[e.exId]!.rung, from + 3);
    });
  });
}
