// The muscle plan: day names, the defaults from strain, and what excluded, forced and manual do to a built workout.
// Everything runs per muscle, the map's own muscles, the same ones the ledgers count.
import 'package:easyday/data/index.dart';
import 'package:easyday/data/library.dart';
import 'package:easyday/data/model.dart';
import 'package:easyday/logic/after.dart';
import 'package:easyday/logic/builder.dart';
import 'package:easyday/logic/muscle_map.dart';
import 'package:easyday/logic/muscle_plan.dart';
import 'package:easyday/logic/selection.dart';
import 'package:flutter_test/flutter_test.dart';

final t0 = DateTime(2026, 10, 15, 9);

AppState fresh({String template = 'home_full'}) {
  final s = AppState()
    ..profile = Profile(experience: 'some', daysPerWeek: 3, createdAt: t0)
    ..goal = GoalConfig.fromTemplate(goals['muscle']!);
  final tpl = templates.firstWhere((t) => t.id == template);
  s.locations = [Location(id: 'l1', name: tpl.name, template: tpl.id, equipment: tpl.equipment.toList())];
  s.lastLocationId = 'l1';
  s.plan = Plan();
  return s;
}

Session build(AppState s, DateTime at, {List<String> muscles = const [], Set<String> excluded = const {}, int minutes = 45, bool manual = false, int? muscleSeed}) =>
    buildSession(s, BuildOptions(energy: Energy.normal, minutes: minutes, muscles: muscles, excluded: excluded, manual: manual, muscleSeed: muscleSeed, liftInstead: true), at);

/// Run a workout at the top of every range, so the muscles it works carry strain afterwards.
Session run(AppState s, DateTime at, {List<String> muscles = const []}) {
  final session = build(s, at, muscles: muscles);
  startSession(s, session, at);
  var clock = at;
  for (var i = 0; i < session.exercises.length; i++) {
    for (var k = 0; k < session.exercises[i].sets.length; k++) {
      clock = clock.add(const Duration(seconds: 120));
      logSet(session, i, session.exercises[i].target, clock);
    }
  }
  finishSession(s, session, Finish(feel: Feel.right), clock);
  return session;
}

/// The muscles a workout's places went to, in order.
List<String> placesOf(Session x) {
  final out = <String>[];
  for (final e in x.exercises) { if (!out.contains(e.muscle)) out.add(e.muscle); }
  return out;
}

void main() {
  group('day names', () {
    test('one, two, three and more muscles; the first word takes the capital', () {
      expect(dayName(['chest']), 'Chest day');
      expect(dayName(['lats', 'biceps']), 'Lats and biceps day');
      expect(dayName(['upper back', 'triceps', 'forearms']), 'Upper back, triceps and forearms day');
      expect(dayName(['quads', 'lats', 'chest', 'hamstrings']), 'Quads, lats, chest and hamstrings day');
      expect(dayName([]), 'Workout');
    });

    test('a built workout is named for every muscle its exercises work as a main muscle, in order', () {
      final x = build(fresh(), t0);
      expect(x.name, dayName(workedInOrder(x.exercises)));
      expect(x.name, contains('glutes'), reason: 'the squat works them as a main muscle, though its place went to the quads');
      expect(x.name, endsWith(' day'));
      expect(placesOf(x).every(trackedMuscles.contains), isTrue, reason: 'places go to muscles, not groups');
    });
  });

  group('defaults from strain', () {
    test('nothing strained: every muscle available, nothing forced', () {
      final d = defaultMuscleStates(StrainPoints.none);
      expect(d.keys.toSet(), trackedMuscles.toSet());
      expect(d.values.every((v) => v == MuscleState.available), isTrue);
    });

    test('the muscles worked yesterday start excluded, one by one; three days on, everything is available again', () {
      final s = fresh();
      run(s, t0);
      final tomorrow = t0.add(const Duration(days: 1));
      final current = MuscleMap(s).currentStrainPoints(tomorrow);
      final d = defaultMuscleStates(current);
      for (final m in trackedMuscles) {
        expect(d[m], current.strainFree(m) ? MuscleState.available : MuscleState.excluded, reason: m);
      }
      expect(d.values.where((v) => v == MuscleState.excluded), isNotEmpty);
      expect(d.values.where((v) => v == MuscleState.available), isNotEmpty, reason: 'a muscle beside a worked one stays available');
      final later = defaultMuscleStates(MuscleMap(s).currentStrainPoints(t0.add(const Duration(days: 3))));
      expect(later.values.every((v) => v == MuscleState.available), isTrue);
    });

    test('a plan sets the selected muscles, and draws by seed only when shuffled', () {
      final plan = MusclePlan(states: defaultMuscleStates(StrainPoints.none), order: trackedMuscles);
      plan.set(['chest', 'lats'], MuscleState.forced);
      plan.set(['calves'], MuscleState.excluded);
      expect(plan.forced, ['chest', 'lats']);
      expect(plan.excluded, {'calves'});
      expect(plan.muscleDraw, isNull);
      plan.muscleSeed = 3;
      expect(plan.muscleDraw, 3);
      plan.manual = true;
      expect(plan.muscleDraw, isNull);
      expect(plan.excluded, {'calves'}, reason: 'manual leaves the rest out by blocking places, not by excluding them');
    });

    test('musclesIn keeps the list order given, then the map order', () {
      final states = {for (final m in trackedMuscles) m: MuscleState.available}..['calves'] = MuscleState.forced..['chest'] = MuscleState.forced;
      expect(musclesIn(states, MuscleState.forced), ['chest', 'calves']);
      expect(musclesIn(states, MuscleState.forced, ['calves', 'chest']), ['calves', 'chest']);
      expect(musclesIn(states, MuscleState.excluded), isEmpty);
    });
  });

  group('building from the states', () {
    test('an excluded muscle never takes a place, and no exercise works it as a main muscle', () {
      final s = fresh(template: 'gym');
      final before = build(s, t0, minutes: 60);
      final first = placesOf(before).first;
      final after = build(s, t0, excluded: {first}, minutes: 60);
      expect(placesOf(after), isNot(contains(first)));
      expect(after.exercises.every((e) => !e.exercise.primary.contains(first)), isTrue);
      expect(after.exercises, isNotEmpty);
      // glutes are a second main muscle of the squat: excluding them moves the quads to an exercise without them
      final noGlutes = build(s, t0, muscles: const ['quads'], excluded: const {'glutes'});
      final quads = noGlutes.exercises.firstWhere((e) => e.muscle == 'quads');
      expect(quads.exercise.primary, isNot(contains('glutes')));
    });

    test('a forced muscle is worked by an exercise with it as a main muscle; the builder still orders hardest first', () {
      final s = fresh(template: 'gym');
      final x = build(s, t0, muscles: const ['calves', 'rear shoulders']);
      expect(placesOf(x), containsAll(['calves', 'rear shoulders']));
      for (final e in x.exercises.where((e) => e.asked)) {
        expect(e.exercise.primary, contains(e.muscle));
      }
      expect(x.name, allOf(contains('calves'), contains('rear shoulders')));
    });

    test('a forced muscle whose exercises all work an excluded one too still gets one', () {
      final s = fresh(template: 'gym');
      final all = candidatesFor(s, 'inner thighs', s.locations.first.equipment, const [], t0);
      expect(all, isNotEmpty);
      // exclude every other main muscle those exercises have, and the inner thighs' only candidates are off limits
      final avoid = {for (final e in all) ...e.primary}..remove('inner thighs');
      final strict = candidatesFor(s, 'inner thighs', s.locations.first.equipment, const [], t0, avoid: {...avoid, 'inner thighs'});
      expect(strict, isEmpty);
      final x = build(s, t0, muscles: const ['inner thighs'], excluded: {...avoid});
      expect(placesOf(x), contains('inner thighs'));
    });

    test('a forced muscle still works while carrying strain, and the row says so', () {
      final s = fresh();
      final x = run(s, t0);
      final strained = placesOf(x).first;
      final next = build(s, t0.add(const Duration(days: 1)), muscles: [strained]);
      final row = next.exercises.firstWhere((e) => e.muscle == strained);
      expect(row.asked, isTrue);
      expect(row.why, contains('still carrying strain'));
    });

    test('manual works the forced muscles only, even with minutes to spare', () {
      final s = fresh(template: 'gym');
      final x = build(s, t0, muscles: const ['chest', 'calves'], manual: true, minutes: 90);
      expect(placesOf(x).toSet(), {'chest', 'calves'});
      // a pullover works the chest and the lats as main muscles, so forcing both takes one exercise
      final y = build(s, t0, muscles: const ['chest', 'lats'], manual: true, minutes: 90);
      expect(y.exercises.length, 1);
      expect(workedInOrder(y.exercises), containsAll(['chest', 'lats']));
    });

    test('a shuffle seed draws different ready muscles, the same for the same seed', () {
      final s = fresh();
      expect(placesOf(build(s, t0, minutes: 60, muscleSeed: 1)), placesOf(build(s, t0, minutes: 60, muscleSeed: 1)));
      final draws = {for (var i = 1; i <= 8; i++) placesOf(build(s, t0, minutes: 60, muscleSeed: i)).join()};
      expect(draws.length, greaterThan(1));
    });

    test('the engine: one exercise that works several forced muscles covers them all', () {
      final s = fresh(template: 'gym');
      final x = build(s, t0, muscles: const ['quads', 'glutes'], manual: true);
      expect(x.exercises.length, 1, reason: 'a squat works both');
      expect(x.exercises.single.exercise.primary, containsAll(['quads', 'glutes']));
      // the reviewed library tags most rows with the upper back and the lats: one row covers both
      final r = build(s, t0, muscles: const ['lats', 'upper back'], manual: true);
      expect(r.exercises.length, 1);
      expect(r.exercises.single.exercise.primary, containsAll(['lats', 'upper back']));
      // with nothing shared, each muscle takes its own
      final y = build(s, t0, muscles: const ['calves', 'biceps'], manual: true);
      expect(y.exercises.length, 2);
      expect(workedInOrder(y.exercises), containsAll(['calves', 'biceps']));
    });

    test('the engine prefers an exercise that covers another waiting muscle over working one twice', () {
      final s = fresh(template: 'gym');
      // chin-ups work the lats and the biceps; forcing both wants one chin-up, not a pulldown and a curl
      final x = build(s, t0, muscles: const ['lats', 'biceps'], manual: true);
      expect(x.exercises.map((e) => e.exId), ['chinup']);
      // and in shuffle every required muscle is worked, with no muscle given a second exercise while others wait
      final z = build(s, t0, muscles: const ['quads', 'glutes'], minutes: 60);
      final worked = workedInOrder(z.exercises);
      expect(worked, containsAll(['quads', 'glutes']));
      expect(z.exercises.where((e) => e.exercise.primary.contains('glutes')).length, 1, reason: 'the squat already works the glutes');
      expect(z.exercises.length, greaterThan(1), reason: 'the other places go to other muscles');
    });

    test('manual never repeats a muscle to fill the minutes', () {
      final s = fresh(template: 'gym');
      final x = build(s, t0, muscles: const ['calves', 'biceps'], manual: true, minutes: 90);
      expect(x.exercises.length, 2);
    });

    test('everything excluded builds nothing, with the name falling back', () {
      final x = build(fresh(), t0, excluded: trackedMuscles.toSet());
      expect(x.exercises, isEmpty);
      expect(x.name, 'Workout');
    });
  });
}
