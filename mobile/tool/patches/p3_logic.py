import io

def patch(path, pairs):
    s = io.open(path, encoding='utf-8').read()
    for a, b in pairs:
        assert a in s, (path, a[:70])
        s = s.replace(a, b)
    io.open(path, 'w', encoding='utf-8').write(s)
    print(path, 'ok')

patch('lib/logic/after.dart', [
("""  final judged = session.energy != Energy.easy &&
      session.stopReason != StopReason.energy && session.stopReason != StopReason.time && session.feel != Feel.tooMuch;""",
"""  final judged = session.energy != Energy.easy &&
      session.stopReason != StopReason.energy && session.stopReason != StopReason.time && session.stopReason != StopReason.none && session.feel != Feel.tooMuch;"""),
("""    if (session.stopReason == StopReason.pain && session.stopAt == idx) continue;""",
"""    if (session.stopReason == StopReason.pain && session.stopAt == idx) continue;
    if (session.skipped.contains(idx)) continue;"""),
("""    } else if (session.stopReason == StopReason.time) {
      lines.add('Stopped for time. Rungs hold; next time defaults shorter.');
    } else if (session.feel == Feel.tooMuch) {
      lines.add('Too much today. Rungs hold.');
    }
    return;""",
"""    } else if (session.stopReason == StopReason.time) {
      lines.add('Stopped for time. Levels hold; next time defaults shorter.');
    } else if (session.stopReason == StopReason.none) {
      lines.add('Stopped. Nothing changes; what you did still counts.');
    } else if (session.feel == Feel.tooMuch) {
      lines.add('Too much today. Levels hold.');
    }
    return;"""),
("Easy day logged. Rungs never move on an easy day.", "Easy day logged. Levels never move on an easy day."),
("Stopped for energy. Rungs hold; tomorrow defaults a little easier.", "Stopped for energy. Levels hold; tomorrow defaults a little easier."),
("ups.add('${ex.name} steps up next time: you hit ${e.hi} on every set.');", "ups.add('${ex.name} levels up next time: you hit ${e.hi} on every set.');"),
("downs.add('${ex.name} steps down next time: ${_reps(e)}.');", "downs.add('${ex.name} drops a level next time: ${_reps(e)}.');"),
("stays.add('${ex.name}: top of the range, ${s.settings.stepUp - st.topRun} more to step up.');", "stays.add('${ex.name}: top of the range, ${s.settings.stepUp - st.topRun} more to level up.');"),
("ups.add('${ex.name}: new best, $total total at the top of the ladder.');", "ups.add('${ex.name}: new best, $total total at the top of the progression.');"),
("""/// Seconds per set per exercise, learned from the gap between one set tap and the next. Weighted toward recent sessions.
void _learnTiming(AppState s, Session session) {
  const alpha = 0.3;
  for (final e in session.exercises) {""",
"""/// Seconds per set per exercise, learned from the gap between one set tap and the next. Weighted toward recent workouts.
/// In a circuit the previous tap belongs to another exercise, so each gap is credited to the exercise whose set ended it.
void _learnTiming(AppState s, Session session) {
  const alpha = 0.3;
  if (session.circuit) {
    final taps = <(DateTime, String)>[];
    for (final e in session.exercises) {
      for (final x in e.sets) { if (x.attempted && x.at != null) taps.add((x.at!, e.exId)); }
    }
    taps.sort((a, b) => a.$1.compareTo(b.$1));
    for (var i = 1; i < taps.length; i++) {
      final st = s.ex[taps[i].$2];
      if (st == null) continue;
      final gap = taps[i].$1.difference(taps[i - 1].$1).inSeconds.toDouble().clamp(20.0, 600.0);
      st.secPerSet = st.secPerSet * (1 - alpha) + gap * alpha;
    }
    return;
  }
  for (final e in session.exercises) {"""),
("""void _learnDefaults(AppState s, Session session, DateTime now, List<String> lines) {
  final plan = s.plan!;
  final recent = [...s.sessions.reversed.take(3), session];""",
"""void _learnDefaults(AppState s, Session session, DateTime now, List<String> lines) {
  final plan = s.plan!;
  if (session.stopReason == StopReason.none) return; // a plain stop teaches nothing
  final recent = [...s.sessions.reversed.take(3), session];"""),
("""      lines.insert(0, '${patternName(pattern)} rests for ${s.settings.painRestDays} days, then comes back one rung down.');""",
"""      lines.insert(0, '${session.exercises[f.stopAt!].exercise.name} and similar moves rest for ${s.settings.painRestDays} days, then come back one level down.');"""),
("""    lines.add(session.kind == 'cardio' ? 'Movement counts. Next up: the next lifting day.' : 'Mobility done. Next up: the next lifting day.');""",
"""    lines.add(session.kind == 'cardio' ? 'Movement counts. The next workout is ready tomorrow.' : 'Mobility done. The next workout is ready tomorrow.');"""),
("""/// Rung trend per pattern over the last 30 days: net rung change across the exercises of the pattern.
Map<String, int> rungTrend(AppState s, DateTime now) {
  final out = <String, int>{};
  final since = now.subtract(const Duration(days: 30));
  for (final x in s.sessions) {
    if (x.type != 'lift' || x.endedAt == null || x.endedAt!.isBefore(since)) continue;
    for (final e in x.exercises) {
      final st = s.ex[e.exId];
      if (st == null || e.edited) continue;
      // compare the rung used then with the rung now; only the earliest appearance per exercise counts
      out.putIfAbsent('${e.pattern}|${e.exId}', () => st.rung - e.rung);
    }
  }
  final byPattern = <String, int>{};
  for (final entry in out.entries) {
    final pattern = entry.key.split('|').first;
    byPattern[pattern] = (byPattern[pattern] ?? 0) + entry.value;
  }
  return byPattern;
}""",
"""/// Level trend per exercise over the last 30 days: the level now against the level at the earliest appearance.
Map<String, int> levelTrend(AppState s, DateTime now) {
  final out = <String, int>{};
  final since = now.subtract(const Duration(days: 30));
  for (final x in s.sessions) {
    if (x.type != 'lift' || x.endedAt == null || x.endedAt!.isBefore(since)) continue;
    for (final e in x.exercises) {
      final st = s.ex[e.exId];
      if (st == null || e.edited || e.attempted.isEmpty) continue;
      out.putIfAbsent(e.exId, () => st.rung - e.rung);
    }
  }
  return out;
}

/// True when a workout was finished on this calendar day.
bool finishedToday(AppState s, DateTime now) {
  final last = s.lastSession;
  if (last?.endedAt == null) return false;
  final a = last!.endedAt!;
  return a.year == now.year && a.month == now.month && a.day == now.day;
}

/// True when the user asked for another workout today after finishing one.
bool continuedToday(AppState s, DateTime now) {
  final c = s.plan?.continuedOn;
  return c != null && c.year == now.year && c.month == now.month && c.day == now.day;
}"""),
])

patch('lib/logic/builder.dart', [
("""/// Defaults for the two questions: from the last session, the learning window, and the calendar.
({Energy energy, int minutes}) defaultsFor(AppState s, DateTime now) {
  final p = s.plan!;
  var energy = p.energyDefault;
  final ps = personState(s, now);
  if (ps.state == PersonState.away) energy = Energy.easy;
  return (energy: energy, minutes: clampMinutes(p.timeDefault));
}""",
"""/// Defaults for the two questions: from the last workout, the learning window, and the calendar.
/// [busyMinutes] is today's calendar load; a packed day shortens the default.
({Energy energy, int minutes, bool packed}) defaultsFor(AppState s, DateTime now, {int? busyMinutes}) {
  final p = s.plan!;
  var energy = p.energyDefault;
  final ps = personState(s, now);
  if (ps.state == PersonState.away) energy = Energy.easy;
  var minutes = clampMinutes(p.timeDefault);
  var packed = false;
  if (busyMinutes != null && busyMinutes >= packedDayMinutes && minutes > packedDayDefault) { minutes = packedDayDefault; packed = true; }
  return (energy: energy, minutes: minutes, packed: packed);
}

/// A day with this much in the calendar counts as packed, and gets this default.
const packedDayMinutes = 6 * 60;
const packedDayDefault = 25;"""),
("""    this.moveKind, this.routine, this.cardio, this.energyChosen = false, this.timeChosen = false,
  });""", """    this.moveKind, this.routine, this.cardio, this.energyChosen = false, this.timeChosen = false, this.circuit = false,
  });"""),
("""  final bool energyChosen;
  final bool timeChosen;
}""", """  final bool energyChosen;
  final bool timeChosen;
  final bool circuit;
}"""),
("""    energyChosen: o.energyChosen, timeChosen: o.timeChosen, stateAtStart: ps.state, exercises: out,
    estMinutes: ((usedSeconds + (bonusCardio ?? 0) * 60) / 60).round(), bonusCardioMinutes: bonusCardio,
  );""", """    energyChosen: o.energyChosen, timeChosen: o.timeChosen, stateAtStart: ps.state, exercises: out,
    estMinutes: ((usedSeconds + (bonusCardio ?? 0) * 60) / 60).round(), bonusCardioMinutes: bonusCardio, circuit: o.circuit,
  );"""),
])
