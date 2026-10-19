// The muscle plan: day names, the defaults from strain, and what excluded and forced do to a built workout.
import 'package:easyday/data/index.dart';
import 'package:easyday/data/library.dart';
import 'package:easyday/data/model.dart';
import 'package:easyday/logic/after.dart';
import 'package:easyday/logic/builder.dart';
import 'package:easyday/logic/muscle_map.dart';
import 'package:easyday/logic/muscle_plan.dart';
import 'package:flutter_test/flutter_test.dart';

final t0 = DateTime(2026, 10, 15, 9);

AppState fresh() {
  final s = AppState()
    ..profile = Profile(experience: 'some', daysPerWeek: 3, createdAt: t0)
    ..goal = GoalConfig.fromTemplate(goals['muscle']!);
  final tpl = templates.firstWhere((t) => t.id == 'home_full');
  s.locations = [Location(id: 'l1', name: tpl.name, template: tpl.id, equipment: tpl.equipment.toList())];
  s.lastLocationId = 'l1';
  s.plan = Plan();
  return s;
}

Session build(AppState s, DateTime at, {List<String> muscles = const [], Set<String> excluded = const {}, int minutes = 45}) =>
    buildSession(s, BuildOptions(energy: Energy.normal, minutes: minutes, muscles: muscles, excluded: excluded, liftInstead: true), at);

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

List<String> groupsOf(Session x) {
  final out = <String>[];
  for (final e in x.exercises) { if (!out.contains(e.muscle)) out.add(e.muscle); }
  return out;
}

void main() {
  group('day names', () {
    test('one, two, three and more groups', () {
      expect(dayName(['Chest']), 'Chest day');
      expect(dayName(['Back', 'Biceps']), 'Back and biceps day');
      expect(dayName(['Back', 'Triceps', 'Forearms']), 'Back, triceps and forearms day');
      expect(dayName(['Quads', 'Back', 'Chest', 'Hamstrings']), 'Quads, back, chest and hamstrings day');
      expect(dayName([]), 'Workout');
    });

    test('a built workout is named for every group it works, in order', () {
      final x = build(fresh(), t0);
      expect(x.name, dayName(groupsOf(x)));
      expect(x.name, endsWith(' day'));
    });
  });

  group('defaults from strain', () {
    test('nothing strained: everything available, nothing forced', () {
      final d = defaultMuscleStates(StrainPoints.none);
      expect(d.length, muscleGroups.length);
      expect(d.values.every((v) => v == MuscleState.available), isTrue);
    });

    test('the groups worked yesterday start excluded; three days on, everything is available again', () {
      final s = fresh();
      final x = run(s, t0);
      final worked = groupsOf(x);
      final tomorrow = t0.add(const Duration(days: 1));
      final current = MuscleMap(s).currentStrainPoints(tomorrow);
      final d = defaultMuscleStates(current);
      for (final g in worked) {
        final shade = groupShade(current, g);
        expect(d[g], shade >= excludeFromShade ? MuscleState.excluded : MuscleState.available, reason: '$g at shade $shade');
      }
      expect(worked.every((g) => d[g] == MuscleState.excluded), isTrue, reason: 'three working sets leave low strain the next day');
      // three days on, every muscle is strain-free again
      final later = defaultMuscleStates(MuscleMap(s).currentStrainPoints(t0.add(const Duration(days: 3))));
      expect(later.values.every((v) => v == MuscleState.available), isTrue);
    });

    test('a plan sets the selected groups, works only the forced ones when manual, and draws by seed when shuffled', () {
      final plan = MusclePlan(states: defaultMuscleStates(StrainPoints.none), order: muscleGroups);
      plan.set(['Chest', 'Back'], MuscleState.forced);
      plan.set(['Calves'], MuscleState.excluded);
      expect(plan.forced, ['Chest', 'Back']);
      expect(plan.excluded, {'Calves'});
      expect(plan.shuffle, isNull);
      plan.seed = 3;
      expect(plan.shuffle, 3);
      plan.manual = true;
      expect(plan.shuffle, isNull);
      expect(plan.excluded, muscleGroups.toSet().difference({'Chest', 'Back'}));
      final x = build(fresh(), t0, muscles: plan.forced, excluded: plan.excluded, minutes: 60);
      expect(groupsOf(x).toSet(), {'Chest', 'Back'});
    });

    test('a shuffle seed draws different ready groups, the same for the same seed', () {
      final s = fresh();
      final a = buildSession(s, BuildOptions(energy: Energy.normal, minutes: 60, shuffle: 1, liftInstead: true), t0);
      final b = buildSession(s, BuildOptions(energy: Energy.normal, minutes: 60, shuffle: 1, liftInstead: true), t0);
      expect(groupsOf(a), groupsOf(b));
      final draws = {for (var i = 1; i <= 8; i++) groupsOf(buildSession(s, BuildOptions(energy: Energy.normal, minutes: 60, shuffle: i, liftInstead: true), t0)).join()};
      expect(draws.length, greaterThan(1));
    });
  });

  group('building from the states', () {
    test('an excluded group is never worked, not even for spare minutes', () {
      final s = fresh();
      final before = build(s, t0, minutes: 60);
      final first = groupsOf(before).first;
      final after = build(s, t0, excluded: {first}, minutes: 60);
      expect(groupsOf(after), isNot(contains(first)));
      expect(after.exercises, isNotEmpty);
    });

    test('a forced group is worked by an exercise with it as a main muscle, first in the list given', () {
      final s = fresh();
      final x = build(s, t0, muscles: const ['Calves', 'Forearms']);
      final groups = groupsOf(x);
      expect(groups, containsAll(['Calves', 'Forearms']));
      for (final e in x.exercises.where((e) => e.asked)) {
        expect(e.exercise.primary.map(muscleGroup), contains(e.muscle));
      }
      expect(x.name, contains('calves'));
    });

    test('a forced group still works while carrying strain, and the row says so', () {
      final s = fresh();
      final x = run(s, t0);
      final strained = groupsOf(x).first;
      final next = build(s, t0.add(const Duration(days: 1)), muscles: [strained]);
      final row = next.exercises.firstWhere((e) => e.muscle == strained);
      expect(row.asked, isTrue);
      expect(row.why, contains('still carrying strain'));
    });

    test('everything excluded builds nothing, with the name falling back', () {
      final x = build(fresh(), t0, excluded: muscleGroups.toSet());
      expect(x.exercises, isEmpty);
      expect(x.name, 'Workout');
    });

    test('groupsIn keeps the list order given, then the index order', () {
      final states = {for (final g in muscleGroups) g: MuscleState.available}..['Calves'] = MuscleState.forced..['Chest'] = MuscleState.forced;
      expect(groupsIn(states, MuscleState.forced), ['Chest', 'Calves']);
      expect(groupsIn(states, MuscleState.forced, ['Calves', 'Chest']), ['Calves', 'Chest']);
      expect(groupsIn(states, MuscleState.excluded), isEmpty);
    });
  });
}
