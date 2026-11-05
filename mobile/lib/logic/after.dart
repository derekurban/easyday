// What happens after a workout, in order: person state and decay, the progression per exercise against its working
// level, the timing model, the budgets and defaults for next time, then one line to the human. Section 8 of APPLICATION.md.
import 'dart:math';

import '../data/index.dart';
import '../data/library.dart';
import '../data/model.dart';
import 'builder.dart' show changeSeconds, warmupSetsSeconds;
import 'calibrate.dart' show settleCalibration;
import 'ladder.dart';
import 'person.dart';
import 'score.dart';
import 'selection.dart';
import 'workout.dart';

class Finish {
  Finish({this.feel, this.stopReason, this.stopAt, this.effort, this.endRead, this.painAt});
  final EndRead? endRead; // how it ended, from Logged; without one the stop reason stands for it
  final int? painAt;      // the exercise that hurt, from Logged
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

/// Finish: write history, judge each exercise, update timing, budgets, defaults, and the note.
void finishSession(AppState s, Session session, Finish f, DateTime now) {
  session.endedAt = now;
  session.feel = f.feel;
  final end = f.endRead ?? switch (f.stopReason) { null => EndRead.normal, StopReason.time => EndRead.time, StopReason.none => EndRead.none, _ => EndRead.energy };
  session.endRead = end.name;
  session.painAt = f.painAt ?? (f.stopReason == StopReason.pain ? f.stopAt : null);
  session.reviewing = false;
  session.stopReason = f.stopReason ?? stopReasonOf(end);
  session.stopAt = f.stopAt;
  session.effort = f.effort;
  final lines = <String>[];

  if (session.type == 'lift') {
    _judge(s, session, now, lines);
    _learnTiming(s, session);
    final hurt = session.painAt;
    if (hurt != null && hurt < session.exercises.length) {
      final ex = session.exercises[hurt].exercise;
      s.plan!.paused[ex.id] = now.add(Duration(days: s.settings.painRestDays));
      lines.insert(0, '${ex.name} and its muscles rest for ${s.settings.painRestDays} days, then it comes back one level down.');
    }
    _learnSpare(s, session, lines);
    _learnAsked(s, session, now, lines);
  } else {
    lines.add(session.kind == 'cardio' ? 'Cardio counts. The next workout is ready tomorrow.' : 'Stretching done. The next workout is ready tomorrow.');
  }

  _learnDefaults(s, session, now, lines);
  session.note = lines.isEmpty ? 'Logged. Nothing changes yet.' : lines.first;
  s.sessions.add(session);
  s.active = null;
  s.lastLocationId = session.locationId ?? s.lastLocationId;
}

/// The muscles the user asked for by hand: remembered, and after three asks in two weeks one line suggests more
/// emphasis for the muscle. Never a change.
void _learnAsked(AppState s, Session session, DateTime now, List<String> lines) {
  final p = s.plan!;
  for (final e in session.exercises) {
    if (e.asked && e.attempted.isNotEmpty) p.asked.add((muscle: e.muscle, at: now));
  }
  p.asked.removeWhere((a) => daysBetween(a.at, now) > askedMuscleDays * 2);
  for (final m in moreSuggestions(s, now)) {
    p.moreSuggested.add(m);
    lines.add(s.goal!.tagOf(m) == MuscleTag.active
        ? 'You keep forcing $m. Set it to more often in Settings → Goal if you like.'
        : 'You keep forcing $m. Mark it active in Settings → Goal if you like.');
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
  // a version changed mid-workout: sets at another version than the plan's say nothing about the plan's
  if (!e.exercise.loaded && working.any((x) => (x.rung ?? e.asPlanned) != e.asPlanned)) return Verdict.neutral;
  // a set at least as heavy as the plan asked: the weight it was done at, written with its reps
  final planKg = e.plannedKg ?? e.loadKg;
  bool asHeavy(SetLog x) => planKg == null || (x.kg ?? planKg) >= planKg;
  if (e.nextLevel) {
    // a hard day: the floor on every set at the next level means it is yours. Otherwise a version attempt is neutral,
    // and a loaded attempt is read below by what each set was worth at the usual weight.
    if (working.every((x) => x.reps! >= e.lo && asHeavy(x))) return Verdict.stepNow;
    if (!e.exercise.loaded) return Verdict.neutral;
  }
  double worth(SetLog x) {
    final kg = x.kg ?? planKg;
    return kg != null && e.usualLoadKg != null && e.usualLoadKg! > 0 && kg != e.usualLoadKg ? repsEquivalent(x.reps!, kg, e.usualLoadKg!) : x.reps!.toDouble();
  }
  if (working.any((x) => worth(x) < e.lo)) return Verdict.miss;
  if (working.every((x) => worth(x) >= e.hi)) return Verdict.hit;
  return Verdict.hold;
}

/// Judge each exercise by its score (score.dart): the average set against this level's floor and the next level, with
/// any change the user made on Logged. The top of a progression with nothing above it is judged by its best total.
void _judge(AppState s, Session session, DateTime now, List<String> lines) {
  final w = readWorkout(s, session, now);
  final eq = s.location(session.locationId)?.equipment ?? const <String>[];
  final ups = <String>[], downs = <String>[];
  for (final r in w.exercises) {
    final e = session.exercises[r.index];
    final ex = e.exercise;
    if (e.attempted.isEmpty) continue;
    final st = ensureState(s, ex);
    final firstTime = st.appearances == 0;
    st.appearances++;
    st.lastDoneAt = now;
    st.decayPeriodsApplied = 0;
    st.swappedOut = 0;
    // calibration sets: the level they said, however the reps came in
    if (e.sets.any((l) => l.test)) settleCalibration(s, session, r.index);
    // calibrating: the rep band the user picked becomes this exercise's own; the weight follows the reps
    if (e.reps != null) st.repsOverride = expressionRange[Expression.values.byName(e.reps!)];
    if (!r.judged) continue;
    if (e.atWorkingLevel) st.lastWorkingAt = now;
    final total = e.total;
    if (r.ceiling) {
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
      }
      st.calibrating = false;
      continue;
    }
    if (total > st.bestTotal) st.bestTotal = total;
    switch (r.call) {
      case Call.up:
        st.rung = r.levels[Call.up] ?? st.rung + 1;
        st.topRun = 0;
        st.shortRun = 0;
        st.bestTotal = 0;
        st.costUp = 0;
        if (st.decayedBy > 0) st.decayedBy--;
        ups.add('${ex.name}: up to ${rungLabel(s, ex, st, st.rung, e.range, eq)} next time.');
      case Call.down:
        st.rung = r.levels[Call.down] ?? max(ex.loaded ? floorRung(s, ex, st) : 0, st.rung - 1);
        st.topRun = 0;
        st.shortRun = 0;
        st.bestTotal = 0;
        downs.add('${ex.name}: down to ${rungLabel(s, ex, st, st.rung, e.range, eq)} next time.');
      case Call.hold:
        // worth the next level but the setting asks for more in a row: one more toward it
        // a first time sets the starting point: it does not count toward one
        st.topRun = r.worthUp && !r.changed && !firstTime ? st.topRun + 1 : 0;
        // a short workout counts toward a step down only on a day read as normal, and not when the user said hold
        final counts = downsCount(w.end) && session.energy != Energy.easy && e.atWorkingLevel && !r.changed;
        if (r.short && counts) {
          st.shortRun++;
        } else if (!r.short) {
          st.shortRun = 0;
        }
    }
    // calibrating until a workout finds the level: reps over the top keep looking
    // (calibration sets look after it themselves, set by set)
    if (!e.sets.any((l) => l.test) && foundLevel(e)) st.calibrating = false;
  }
  lines.addAll([...ups, ...downs]);
  if (lines.isEmpty) lines.add(headline(s, session, w));
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
      out.putIfAbsent(e.exId, () => st.rung - e.asPlanned);
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
