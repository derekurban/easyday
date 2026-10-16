// The rotation: lifting items interleaved with movement items according to the goal.
import '../data/library.dart';
import '../data/model.dart';

List<RotationEntry> buildRotation(GoalConfig goal, int daysPerWeek) {
  final count = daysPerWeek <= 2 ? 2 : daysPerWeek == 3 ? 3 : 4;
  final lifts = liftItems.take(count).map((it) => RotationEntry(
      type: 'lift', name: it.name, focus: it.focus, patterns: it.patterns.take(goal.exercises.ideal).toList()));
  final rotation = <RotationEntry>[];
  var i = 0;
  for (final l in lifts) {
    rotation.add(l);
    if (goal.moveEvery > 0 && (i + 1) % goal.moveEvery == 0) rotation.add(i % 2 == 0 ? moveCardio() : moveMobility());
    i++;
  }
  return rotation;
}

RotationEntry moveCardio() => RotationEntry(type: 'move', kind: 'cardio', name: 'Move day');
RotationEntry moveMobility() => RotationEntry(type: 'move', kind: 'mobility', name: 'Mobility day', routine: 'reset');

void initPlan(AppState s) {
  s.plan = Plan(rotation: buildRotation(s.goal!, s.profile!.daysPerWeek));
}

void rebuildRotation(AppState s) {
  final p = s.plan!;
  p.rotation = buildRotation(s.goal!, s.profile!.daysPerWeek);
  p.index = p.index % p.rotation.length;
}
