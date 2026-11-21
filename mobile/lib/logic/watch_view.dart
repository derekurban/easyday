// What the watch shows, worked out on the phone. The phone is the source of truth: it sends the watch one small map
// whenever it changes, and the watch sends back taps. Every tap names the step it was made on, so a tap on a view the
// phone has already moved past (the phone was tapped too, or the message was slow) does nothing. docs/app/WATCH.md.
import '../data/model.dart';
import 'after.dart' show finishedToday;
import 'calibrate.dart' show isTestSet;
import 'workout.dart';

/// The version of the map. The watch shows "update the app" for a version it does not know.
const watchViewVersion = 1;

/// The workout Today would start, while Today is on screen: its name, one line of numbers, and whether Start can be
/// tapped from the wrist.
class WatchToday {
  const WatchToday({required this.name, required this.detail, this.start});
  final String name;
  final String detail;
  final void Function()? start;
}

/// The steps a tap can be made on, as a token. The workout screen's own steps, plus Today, the free-form list, a
/// movement day, the finish and nothing at all.
String watchStep(AppState s, {WatchToday? today}) {
  final x = s.active;
  if (x == null) return today == null ? 'idle' : 'today ${today.name}';
  if (x.reviewing) return 'review ${x.id}';
  if (x.endedAt != null) return 'done ${x.id}';
  if (x.type == 'move') return 'move ${x.id}';
  if (x.exercises.isEmpty) return 'feel ${x.id}';
  final items = workoutItems(x);
  final cur = currentItem(x) ?? items.first;
  if (!cur.lifting) return '${x.id} ${cur.key}';
  final lift = liftingSet(x, cur);
  if (lift != null) return '${x.id} lift ${lift.ex} ${lift.set}';
  final last = lastLogged(x, cur);
  return '${x.id} rest ${cur.key} ${last?.ex} ${last?.set}';
}

/// The map the watch shows. [now] is the phone's clock; [skewMs] is how far that clock is from real time (the
/// prototype's day shift), so the watch can run the workout's clock on its own.
Map<String, dynamic> watchView(AppState s, DateTime now, {WatchToday? today, int skewMs = 0}) {
  int ms(DateTime t) => t.millisecondsSinceEpoch;
  final base = <String, dynamic>{'v': watchViewVersion, 'step': watchStep(s, today: today), 'skew': skewMs, 'hold': s.settings.buttonWait};
  final x = s.active;
  if (x == null) {
    if (today != null) return {...base, 'phase': 'today', 'plan': {'name': today.name, 'detail': today.detail, 'canStart': today.start != null}};
    return {...base, 'phase': 'idle', 'line': finishedToday(s, now) ? 'Done for today' : 'Open Easyday to plan today'};
  }
  final session = <String, dynamic>{
    ...base, 'session': x.id, 'title': x.name, 'kind': x.type == 'move' ? (x.kind ?? 'move') : 'lift',
    if (x.startedAt != null) 'startedAt': ms(x.startedAt!), if (x.pausedAt != null) 'pausedAt': ms(x.pausedAt!),
    // the watch records while the workout is under way: not on the finish, and not once it is logged
    'record': x.startedAt != null && x.endedAt == null && !x.reviewing,
  };
  if (x.reviewing || x.endedAt != null) {
    return {...session, 'phase': x.reviewing ? 'review' : 'done', 'line': x.reviewing ? 'Wrap up on your phone' : 'Logged'};
  }
  if (x.type == 'move') {
    final cardio = x.kind == 'cardio';
    return {...session, 'phase': 'timed', 'timed': {'kind': cardio ? 'cardio' : 'stretch', 'name': x.name, 'minutes': x.minutes ?? x.estMinutes,
        if (x.startedAt != null) 'startedAt': ms(x.startedAt!), 'stopwatch': cardio, 'button': 'Done', 'op': 'moveDone'}};
  }
  if (x.exercises.isEmpty) return {...session, 'phase': 'review', 'line': 'Wrap up on your phone'};
  final items = workoutItems(x);
  final cur = currentItem(x) ?? items.first;
  final curIdx = items.indexWhere((it) => it.key == cur.key);
  final strip = stripView(x);
  final done = strip.blocks.where((b) => b.state == BlockState.done || b.state == BlockState.skipped).length;
  final withSteps = {...session, 'steps': {'done': done, 'total': strip.blocks.length, 'at': strip.at, 'between': strip.between}};
  if (!cur.lifting) {
    final started = x.itemStarts[cur.key];
    final cardio = cur.kind == ItemKind.cardio;
    return {...withSteps, 'phase': 'timed', 'timed': {'kind': cur.kind.name, 'name': itemName(x, cur), 'minutes': cur.minutes,
        if (started != null) 'startedAt': ms(started), 'stopwatch': cardio, 'button': readyLabel(x, items, cur), 'op': cardio ? 'cardio' : 'ready'}};
  }
  final lift = liftingSet(x, cur);
  if (lift != null) {
    final e = x.exercises[lift.ex];
    final test = isTestSet(e, lift.set);
    final values = repWheelValues(s, e, test: test);
    return {...withSteps, 'phase': 'lift', 'ex': {
      'index': lift.ex, 'name': e.exercise.name, if (_level(e) != null) 'level': _level(e),
      'set': lift.set + 1, 'sets': e.sets.length, 'lo': e.lo, 'hi': e.hi, 'unit': e.exercise.repLabel == 'seconds' ? 'seconds' : 'reps',
      'values': values, 'initial': repWheelStart(e, values, test: test), 'test': test, 'side': e.exercise.perSide,
    }};
  }
  if (cur.kind == ItemKind.free && freeChoices(x, cur).isNotEmpty) {
    return {...withSteps, 'phase': 'choose', 'choices': [
      for (final i in freeChoices(x, cur)) {
        'ex': i, 'name': shortExerciseName(x.exercises[i].exercise.name),
        'detail': ['Set ${x.exercises[i].attempted.length + 1} of ${x.exercises[i].sets.length}', ?_level(x.exercises[i])].join(' · '),
      },
    ], 'moveOn': moveOnLabel(x, items, cur)};
  }
  final last = lastLogged(x, cur);
  final lastSet = last == null ? null : setOf(x, last);
  final unit = last == null ? 'reps' : x.exercises[last.ex].exercise.repLabel == 'seconds' ? 'seconds' : 'reps';
  return {...withSteps, 'phase': 'rest', 'rest': {
    if (lastSet?.reps != null) 'last': '${lastSet!.reps} $unit', 'next': ?nextName(x, items, curIdx),
    'button': readyLabel(x, items, cur), 'op': 'ready',
  }};
}

/// The level beside the name: the weight of a loaded exercise, the version of a bodyweight one (whose name is its
/// exercise's), nothing when the label is only the name again.
String? _level(SessionExercise e) => e.rungLabel.isEmpty || e.rungLabel == e.exercise.name ? null : e.rungLabel;

/// The taps a watch can send, and which of them must be made on the step under way.
const watchOps = {'ready', 'log', 'pick', 'moveOn', 'cardio', 'moveDone', 'pause', 'resume', 'end', 'start', 'hello'};
const _stepBound = {'ready', 'log', 'pick', 'moveOn', 'cardio', 'moveDone', 'start'};

/// Whether a tap from the watch still applies: a known op, for the session under way, made on the step under way (the
/// ones that move a step on), and not older than [maxAge].
bool watchCommandApplies(AppState s, Map<String, dynamic> cmd, DateTime now, {WatchToday? today, Duration maxAge = const Duration(minutes: 2)}) {
  final op = cmd['op'];
  if (op is! String || !watchOps.contains(op)) return false;
  if (op == 'hello') return true;
  final at = cmd['at'];
  if (at is num && now.difference(DateTime.fromMillisecondsSinceEpoch(at.toInt())).abs() > maxAge) return false;
  if (_stepBound.contains(op) && cmd['step'] != watchStep(s, today: today)) return false;
  if (op == 'start') return s.active == null && today?.start != null;
  final x = s.active;
  if (x == null || (cmd['session'] != null && cmd['session'] != x.id)) return false;
  return true;
}
