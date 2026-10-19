// What happens after a workout, in order: person state and decay, the progression per exercise against its working
// level, the timing model, the budgets and defaults for next time, then one line to the human. Section 8 of APPLICATION.md.
import 'dart:math';

import '../data/library.dart';
import '../data/model.dart';
import 'builder.dart' show changeSeconds, warmupSetsSeconds;
import 'ladder.dart';
import 'person.dart';
import 'selection.dart';
import 'workout.dart';

class Finish {
  Finish({this.feel, this.stopReason, this.stopAt, this.effort});
  final Feel? feel;
  final StopReason? stopReason;
  final int? stopAt;
  final int? effort;
}

/// Start: record the moment and keep the session as active.
void startSession(AppState s, Session session, DateTime now) {
  session.id = s.nextId('s');
  session.startedAt = now;
  s.active = session;
}

/// Log one set. reps == target means hit the top. Returns the set index logged.
int logSet(Session session, int exIdx, int reps, DateTime now) {
  final e = session.exercises[exIdx];
  final i = e.sets.indexWhere((x) => !x.attempted);
  if (i < 0) return -1;
  e.sets[i].reps = reps;
  e.sets[i].at = now;
  return i;
}

/// Undo the last logged set of an exercise.
void undoSet(Session session, int exIdx) {
  final e = session.exercises[exIdx];
  for (var i = e.sets.length - 1; i >= 0; i--) {
    if (e.sets[i].attempted) { e.sets[i].reps = null; e.sets[i].at = null; return; }
  }
}

String _reps(Iterable<SetLog> sets) => sets.where((x) => x.attempted).map((x) => x.reps).join(', ');

/// Finish: write history, judge each exercise, update timing, budgets, defaults, and the note.
void finishSession(AppState s, Session session, Finish f, DateTime now) {
  session.endedAt = now;
  session.feel = f.feel;
  session.stopReason = f.stopReason;
  session.stopAt = f.stopAt;
  session.effort = f.effort;
  final lines = <String>[];

  if (session.type == 'lift') {
    _judge(s, session, now, lines);
    _learnTiming(s, session);
    if (f.stopReason == StopReason.pain && f.stopAt != null && f.stopAt! < session.exercises.length) {
      final ex = session.exercises[f.stopAt!].exercise;
      s.plan!.paused[ex.id] = now.add(Duration(days: s.settings.painRestDays));
      lines.insert(0, '${ex.name} and its muscles rest for ${s.settings.painRestDays} days, then it comes back one level down.');
    }
    _learnSpare(s, session, lines);
    _learnAsked(s, session, now, lines);
  } else {
    lines.add(session.kind == 'cardio' ? 'Movement counts. The next workout is ready tomorrow.' : 'Mobility done. The next workout is ready tomorrow.');
  }

  _learnDefaults(s, session, now, lines);
  session.note = lines.isEmpty ? 'Logged. Nothing changes yet.' : lines.first;
  s.sessions.add(session);
  s.active = null;
  s.lastLocationId = session.locationId ?? s.lastLocationId;
}

/// The muscles the user asked for by hand: remembered, and after three asks in two weeks one line suggests more
/// emphasis for the group. Never a change.
void _learnAsked(AppState s, Session session, DateTime now, List<String> lines) {
  final p = s.plan!;
  for (final e in session.exercises) {
    if (e.asked && e.attempted.isNotEmpty) p.asked.add((group: e.muscle, at: now));
  }
  p.asked.removeWhere((a) => daysBetween(a.at, now) > askedMuscleDays * 2);
  for (final grp in moreSuggestions(s, now)) {
    p.moreSuggested.add(grp);
    lines.add('You keep asking for ${grp.toLowerCase()}. Set it to more in Settings → Goal if you like.');
  }
}

/// The verdict for one exercise, read against its working level. Intent is never an input. WORKOUT.md, "Judging".
enum Verdict { neutral, hit, stepNow, hold, miss }

Verdict verdictFor(SessionExercise e, StopReason? stop, int stopAt, int idx) {
  if (!e.atWorkingLevel) return Verdict.neutral;
  final working = e.sets.take(e.workingSets).toList();
  if (working.any((x) => !x.attempted)) {
    // the working sets were cut short
    return stop == StopReason.energy && stopAt == idx ? Verdict.miss : Verdict.neutral;
  }
  if (e.nextLevel) {
    // a hard day: the floor on every set at the next level means it is yours. Otherwise a version attempt is neutral,
    // and a loaded attempt is read below by what each set was worth at the usual weight.
    if (working.every((x) => x.reps! >= e.lo)) return Verdict.stepNow;
    if (!e.exercise.loaded) return Verdict.neutral;
  }
  double worth(SetLog x) => e.loadKg != null && e.usualLoadKg != null && e.usualLoadKg! > 0 && e.loadKg != e.usualLoadKg
      ? repsEquivalent(x.reps!, e.loadKg!, e.usualLoadKg!)
      : x.reps!.toDouble();
  if (working.any((x) => worth(x) < e.lo)) return Verdict.miss;
  if (working.every((x) => worth(x) >= e.hi)) return Verdict.hit;
  return Verdict.hold;
}

void _judge(AppState s, Session session, DateTime now, List<String> lines) {
  final ups = <String>[], downs = <String>[], stays = <String>[];
  var anyWorking = false;
  for (var idx = 0; idx < session.exercises.length; idx++) {
    final e = session.exercises[idx];
    final ex = e.exercise;
    final st = ensureState(s, ex);
    final attempted = e.attempted.toList();
    if (attempted.isEmpty) continue;
    st.appearances++;
    st.lastDoneAt = now;
    st.decayPeriodsApplied = 0;
    st.swappedOut = 0;
    if (session.skipped.contains(idx)) continue;
    if (session.stopReason == StopReason.pain && session.stopAt == idx) continue;
    if (e.edited && e.rung != st.rung) continue; // today's rung was edited but not saved: nothing to judge against
    if (e.atWorkingLevel) { st.lastWorkingAt = now; anyWorking = true; }
    final total = attempted.fold(0, (a, x) => a + x.reps!);

    if (e.atCeiling && e.atWorkingLevel) {
      // the range is open upward: the target is beating the best total
      if (total > st.bestTotal) {
        st.bestTotal = total;
        st.ceilingRun++;
        if (st.ceilingRun >= 3 && difficultyInPlay(ex, st) > 1) {
          st.costDown++;
          st.ceilingRun = 0;
          lines.add('${ex.name} counts as ${difficultyLabel[difficultyInPlay(ex, st)]} now: three bests in a row at the top.');
        } else {
          ups.add('${ex.name}: new best, $total total at the top of the progression.');
        }
      } else {
        st.ceilingRun = 0;
        stays.add('${ex.name} stays: $total total, best is ${st.bestTotal}.');
      }
      st.calibrating = false;
      continue;
    }

    var v = verdictFor(e, session.stopReason, session.stopAt ?? -1, idx);
    if (v == Verdict.miss && session.stopReason == StopReason.none) v = Verdict.neutral; // a plain stop carries no penalty
    if (v == Verdict.neutral) continue;
    if (total > st.bestTotal) st.bestTotal = total;
    switch (v) {
      case Verdict.hit:
      case Verdict.stepNow:
        st.topRun++;
        st.shortRun = 0;
        final stepNow = v == Verdict.stepNow || st.topRun >= s.settings.stepUp || (st.calibrating && session.feel == Feel.easy) || st.decayedBy > 0;
        if (stepNow) {
          st.rung++;
          st.topRun = 0;
          st.bestTotal = 0;
          if (st.decayedBy > 0) st.decayedBy--;
          st.costUp = 0;
          if (v == Verdict.stepNow) {
            // a level earned today leads the note
            ups.insert(0, '${ex.name} levels up now: ${e.rungLabel} is yours, ${_reps(e.sets)}.');
          } else {
            ups.add('${ex.name} levels up next time: ${e.hi} or more on every set.');
          }
        } else {
          stays.add('${ex.name}: top of the range, ${s.settings.stepUp - st.topRun} more to level up.');
        }
      case Verdict.miss:
        st.shortRun++;
        st.topRun = 0;
        final cut = e.sets.take(e.workingSets).any((x) => !x.attempted);
        if (st.shortRun >= s.settings.stepDown) {
          st.rung = max(ex.loaded ? floorRung(s, ex, st) : 0, st.rung - 1);
          st.shortRun = 0;
          st.bestTotal = 0;
          downs.add('${ex.name} drops a level next time: ${cut ? 'cut short' : _reps(e.sets)}.');
        } else {
          stays.add('${ex.name}: ${cut ? 'cut short, counts as a miss' : 'short of the floor (${_reps(e.sets)})'}. ${s.settings.stepDown - st.shortRun} more and it drops a level.');
        }
      case Verdict.hold:
        st.topRun = 0;
        stays.add('${ex.name} holds: ${_reps(e.sets)}${e.nextLevel ? ' at the next level, worth your level' : ''}. In range.');
      case Verdict.neutral:
        break;
    }
    st.calibrating = false;
  }
  if (!anyWorking) {
    if (session.stopReason == StopReason.none) {
      lines.add('Stopped. Nothing changes; what you did still counts.');
    } else if (session.energy == Energy.easy) {
      lines.add('Easy day logged. Nothing was at its working level, so levels hold.');
    } else {
      lines.add('Logged. Nothing was at its working level, so levels hold.');
    }
    return;
  }
  if (session.stopReason == StopReason.none && ups.isEmpty && downs.isEmpty && stays.isEmpty) {
    lines.add('Stopped. Nothing changes; what you did still counts.');
    return;
  }
  lines.addAll([...ups, ...downs, ...stays]);
  if (lines.isEmpty) {
    lines.add(switch (session.stopReason) {
      StopReason.energy => 'Stopped for energy. Levels hold; tomorrow defaults a little easier.',
      StopReason.time => 'Stopped for time. Levels hold; next time defaults shorter.',
      StopReason.none => 'Stopped. Nothing changes; what you did still counts.',
      _ => 'Logged. Levels hold.',
    });
  }
}

/// Seconds per set per exercise, weighted toward recent workouts. A workout moved through with I'm ready teaches from
/// each item's whole time, rest and setting up included: less the change-over and any warm-up sets the plan prices on
/// their own, over the sets done. A circuit shares its time out by sets. Older workouts, with only the reps taps,
/// teach from the gap between one tap and the next.
void _learnTiming(AppState s, Session session) {
  const alpha = 0.3;
  if (session.itemStarts.isNotEmpty) {
    final end = session.endedAt ?? DateTime.now();
    for (final item in workoutItems(session)) {
      if (!item.lifting || !session.itemStarts.containsKey(item.key)) continue;
      final done = item.exercises.where((i) => session.exercises[i].attempted.isNotEmpty).toList();
      final sets = done.fold(0, (a, i) => a + session.exercises[i].attempted.length);
      if (sets == 0) continue;
      final secs = itemEnd(session, item, end).difference(session.itemStarts[item.key]!).inSeconds.toDouble();
      final overhead = done.fold(0.0, (a, i) => a + changeSeconds + (session.exercises[i].warmups.isNotEmpty ? warmupSetsSeconds : 0));
      final perSet = ((secs - overhead) / sets).clamp(20.0, 600.0);
      for (final i in done) {
        final st = s.ex[session.exercises[i].exId];
        if (st != null) st.secPerSet = st.secPerSet * (1 - alpha) + perSet * alpha;
      }
    }
    return;
  }
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
  for (final e in session.exercises) {
    final st = s.ex[e.exId];
    if (st == null) continue;
    final taps = e.sets.where((x) => x.attempted && x.at != null).map((x) => x.at!).toList();
    for (var i = 1; i < taps.length; i++) {
      final gap = taps[i].difference(taps[i - 1]).inSeconds.toDouble().clamp(20.0, 600.0);
      st.secPerSet = st.secPerSet * (1 - alpha) + gap * alpha;
    }
  }
}

/// Spare minutes learn from the feel tap: two "too much" in the last four workouts turn "more exercises" into cardio;
/// two "easy" turn cardio back into more exercises. A tap after a plain stop does not count. Nothing is asked per set.
void _learnSpare(AppState s, Session session, List<String> lines) {
  if (session.feel == null || session.stopReason == StopReason.none) return;
  final g = s.goal!;
  final recent = [...s.sessions.reversed.where((x) => x.type == 'lift' && x.stopReason != StopReason.none).take(3), session];
  final tooMuch = recent.where((x) => x.feel == Feel.tooMuch).length;
  final easy = recent.where((x) => x.feel == Feel.easy).length;
  // only the tap that completes a pair moves the setting, so the same two taps never count twice
  if (tooMuch >= 2 && session.feel == Feel.tooMuch && g.spare == Spare.exercises) {
    g.spare = Spare.cardio;
    lines.add('Spare minutes go to cardio from now on, not more exercises. Too much twice recently.');
  } else if (easy >= 2 && session.feel == Feel.easy && g.spare == Spare.cardio) {
    g.spare = Spare.exercises;
    lines.add('Spare minutes add exercises again. Easy twice recently.');
  }
}

/// The energy and time defaults: from this session, with one learning window of the last four sessions.
/// A time stop sets the default to the minutes the user actually had.
void _learnDefaults(AppState s, Session session, DateTime now, List<String> lines) {
  final plan = s.plan!;
  if (session.stopReason == StopReason.none) return; // a plain stop teaches nothing
  final recent = [...s.sessions.reversed.take(3), session];
  plan.energyDefault = session.energy;
  plan.timeDefault = session.timeMinutes;
  final energyStops = recent.where((x) => x.stopReason == StopReason.energy).length;
  if (energyStops >= 2 && plan.energyDefault != Energy.easy) {
    plan.energyDefault = Energy.easy;
    lines.add('Easy is the default for now: you ran out of energy twice recently.');
  }
  if (session.stopReason == StopReason.time) {
    final had = clampMinutes(max(minutesMin, session.elapsedMinutes ?? session.timeMinutes - 10));
    if (had < plan.timeDefault) {
      plan.timeDefault = had;
      lines.add('$had minutes is the default next time: that is what you had today.');
    }
  }
}

/// Sessions per month for the last n months, oldest first, as (label, count).
List<({String label, int count})> sessionsPerMonth(AppState s, DateTime now, {int months = 6}) {
  final out = <({String label, int count})>[];
  for (var i = months - 1; i >= 0; i--) {
    final m = DateTime(now.year, now.month - i, 1);
    final count = s.sessions.where((x) => x.endedAt != null && x.endedAt!.year == m.year && x.endedAt!.month == m.month).length;
    out.add((label: const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m.month - 1], count: count));
  }
  return out;
}

int daysActiveThisMonth(AppState s, DateTime now) {
  final days = <int>{};
  for (final x in s.sessions) {
    if (x.endedAt != null && x.endedAt!.year == now.year && x.endedAt!.month == now.month) days.add(x.endedAt!.day);
  }
  return days.length;
}

/// Level trend per exercise over the last 30 days: the level now against the level at the earliest appearance.
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
}
