p='lib/logic/builder.dart'
s=open(p,encoding='utf-8').read()

# header comment
s=s.replace('''// Builds today's workout: the list is built once at normal and fitted to the minutes; energy turns the dials on it
// (hard: the next level; easy: lighter, fewer exercises at full sets). WORKOUT.md and section 7 of APPLICATION.md.''',
'''// Builds today's workout: the list is built once at normal and fitted to the minutes by three calibrations (exercises,
// sets, pushes: the fewest, the ideal, the most); energy turns the dials on it (hard: the next level, and room to grow
// to the most; easy: lighter, fewer exercises at full sets). WORKOUT.md and section 7 of APPLICATION.md.''')

# defaults
a=s.index('/// Defaults for the two questions')
b=s.index('List<Exercise> candidates(')
s=s[:a]+'''/// Defaults for the two questions: from the last workout, the learning window, and the calendar.
/// [busyShare] is how much of the awake window today's events take, 0 to 1; a busy day shortens the default and a
/// heavy one also makes it easy, by the thresholds in the settings. Never the user's choice.
({Energy energy, int minutes, String? busy}) defaultsFor(AppState s, DateTime now, {double? busyShare}) {
  final p = s.plan!;
  var energy = p.energyDefault;
  final ps = personState(s, now);
  if (ps.state == PersonState.away) energy = Energy.easy;
  var minutes = clampMinutes(p.timeDefault);
  String? busy;
  final st = s.settings;
  if (busyShare != null && st.calendar && st.busyAdjust) {
    final pct = busyShare * 100;
    if (pct >= st.busyEasy) { minutes = min(minutes, busyDayMinutes); energy = Energy.easy; busy = 'easy'; }
    else if (pct >= st.busyShort) { minutes = min(minutes, busyDayMinutes); busy = 'short'; }
  }
  return (energy: energy, minutes: minutes, busy: busy);
}

/// The default on a busy day.
const busyDayMinutes = 25;
/// The ideal list filling no more than this share of the window makes a long day: room to grow to the most.
const longWindowShare = 0.5;

'''+s[b:]

# setsFor removal and fit/grow rewrite
a=s.index('/// Sets by intent: always the working sets.')
b=s.index('double _seconds(')
s=s[:a]+s[b:]

a=s.index('/// The dials for one energy')
b=s.index('int _tier(')
s=s[:a]+'''/// The dials for one energy, on a list that is already built and fitted. The list never changes here.
/// [pushes] is how many exercises train at the next level on a hard day.
void _turnDials(AppState s, List<_Slot> slots, Energy energy, GoalConfig g, int pushes) {
  switch (energy) {
    case Energy.easy:
      for (final sl in slots) { sl.intent = intentLight; }
      // two working turns, among the easy and medium exercises only, the longest-waiting first. Hard ones stay light.
      final eligible = slots.where((x) => _difficulty(s, x.pick!) <= 2).toList()..sort((a, b) => _waitedLongest(s, a, b));
      for (final sl in eligible.take(2)) { sl.intent = intentWorking; }
    case Energy.normal:
      break;
    case Energy.hard:
      // the hardest exercises train at the next level, every set: the same sets, one step heavier
      final byDifficulty = slots.toList()..sort((a, b) { final c = _difficulty(s, b.pick!).compareTo(_difficulty(s, a.pick!)); return c != 0 ? c : a.priority.compareTo(b.priority); });
      for (final sl in byDifficulty.take(pushes)) { sl.intent = intentExtra; }
  }
}

/// Fit the minutes: exercises down to the fewest (light ones first, then the last on the list), then sets down to
/// the fewest (the exercise with the most sets first, the last on the list among equals), and only when the minutes
/// cannot hold even that, below the fewest. Returns the patterns dropped, so growth can bring them back if room appears.
List<String> _fitTime(AppState s, List<_Slot> slots, double window, GoalConfig g) {
  final dropped = <String>[];
  void drop(_Slot victim) { slots.remove(victim); dropped.insert(0, victim.pattern); }
  for (var guard = 0; guard < 80 && _totalSeconds(s, slots) > window; guard++) {
    final byPriority = slots.toList()..sort((a, b) => b.priority.compareTo(a.priority));
    if (slots.length > g.exercises.min) { drop(byPriority.where((x) => x.intent == intentLight).firstOrNull ?? byPriority.first); continue; }
    final shrinkable = byPriority.where((x) => x.sets > g.sets.min).toList()..sort((a, b) => b.sets.compareTo(a.sets));
    if (shrinkable.isNotEmpty) { shrinkable.first.sets--; continue; }
    if (slots.length > 1) { drop(byPriority.first); continue; }
    if (slots.single.sets > 1) { slots.single.sets--; continue; }
    break;
  }
  return dropped;
}

/// Grow the exercises into what is left, one more pattern at a time, up to [limit]: dropped ones first, then the rest
/// of the rotation item, then the free patterns.
void _grow(AppState s, List<_Slot> slots, double window, int limit, int sets, Iterable<String> equipment,
    List<String> morePatterns, Map<String, DateTime> paused) {
  var added = slots.where((x) => x.slot.endsWith('x')).length;
  for (var guard = 0; guard < 20 && slots.length < limit; guard++) {
    final secsLeft = window - _totalSeconds(s, slots);
    if (secsLeft <= 0) break;
    final inPlay = slots.map((x) => x.pattern).toSet();
    final used = slots.map((x) => x.pick!.id).toList();
    _Slot? next;
    for (final pattern in [...morePatterns, ..._freePatterns]) {
      if (inPlay.contains(pattern) || paused.containsKey(pattern)) continue;
      final pick = _pickFor(s, pattern, equipment, used, null);
      if (pick == null) continue;
      final sl = _Slot('${pattern}x', pattern, 100 + added)..pick = pick..intent = intentWorking..sets = sets;
      if (_seconds(s, sl) <= secsLeft) { next = sl; break; }
    }
    if (next == null) break;
    slots.add(next);
    added++;
  }
}

/// Grow the sets into what is left, one set at a time round the list in priority order, up to [limit] each.
void _growSets(AppState s, List<_Slot> slots, double window, int limit) {
  final byPriority = slots.toList()..sort((a, b) => a.priority.compareTo(b.priority));
  for (var guard = 0; guard < 60; guard++) {
    var grew = false;
    for (final sl in byPriority) {
      if (sl.sets >= limit) continue;
      sl.sets++;
      if (_totalSeconds(s, slots) > window) { sl.sets--; return; }
      grew = true;
    }
    if (!grew) return;
  }
}

'''+s[b:]

# buildSession steps 3-4
a=s.index('  // 3. the list is built once, at normal')
b=s.index('  final liftIndex = plan.rotation.take(plan.index)')
s=s[:a]+'''  // 3. the list is built once, at normal: the ideal sets everywhere, fitted to the minutes by the calibrations. A day is
  //    tight when the ideal list does not fit, long when it fills no more than half the window. Spare minutes grow the
  //    list back to the ideal; on a long day or a hard day, sets then exercises grow on to the most.
  for (final sl in slots) { sl.intent = intentWorking; sl.sets = g.sets.ideal; }
  final idealSeconds = _totalSeconds(s, slots);
  final dropped = _fitTime(s, slots, window, g);
  final tight = dropped.isNotEmpty || slots.any((x) => x.sets < g.sets.ideal);
  final longDay = !tight && idealSeconds <= window * longWindowShare;
  if (g.spare == Spare.exercises) {
    final more = [...dropped, ...all.where((p) => !patternsToday.contains(p))];
    _grow(s, slots, window, g.exercises.ideal, g.sets.ideal, equipment, more, plan.paused);
    if (longDay || o.energy == Energy.hard) {
      _growSets(s, slots, window, g.sets.max);
      _grow(s, slots, window, g.exercises.max, g.sets.ideal, equipment, more, plan.paused);
    }
  }
  // 4. the dials. A hard day pushes the fewest exercises when tight, the ideal usually, the most on a long day. An easy
  //    day keeps full sets and fewer exercises: the last light ones go until the lifting fits a smaller window, never
  //    below the fewest, so what is left is few exercises done properly rather than many done thinly.
  final pushes = (tight ? g.pushes.min : longDay ? g.pushes.max : g.pushes.ideal).clamp(0, slots.length);
  _turnDials(s, slots, o.energy, g, pushes);
  final listedAtNormal = slots.length;
  if (o.energy == Energy.easy) {
    final easyWindow = window * easyWindowShare;
    for (var guard = 0; guard < 20 && slots.length > max(1, g.exercises.min) && _totalSeconds(s, slots) > easyWindow; guard++) {
      final byPriority = slots.toList()..sort((a, b) => b.priority.compareTo(a.priority));
      final victim = byPriority.where((x) => x.intent == intentLight).firstOrNull ?? byPriority.first;
      slots.remove(victim);
    }
  }
'''+s[b:]

s=s.replace("    var relative = sl.sets / g.workingSets;","    var relative = sl.sets / g.sets.ideal;")
s=s.replace("      slot: sl.slot, exId: ex.id, pattern: sl.pattern, intent: sl.intent, workingSets: g.workingSets, rung: rung, rungLabel: label,",
"      slot: sl.slot, exId: ex.id, pattern: sl.pattern, intent: sl.intent, workingSets: min(sl.sets, g.sets.ideal), rung: rung, rungLabel: label,")
open(p,'w',encoding='utf-8').write(s)

p='lib/logic/rotation.dart'
s=open(p,encoding='utf-8').read()
s=s.replace("patterns: it.patterns.take(goal.maxExercises).toList()","patterns: it.patterns.take(goal.exercises.ideal).toList()")
open(p,'w',encoding='utf-8').write(s)
print('ok')
