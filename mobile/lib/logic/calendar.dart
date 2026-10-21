// The shape of the user's day from their calendar: inside the awake window every minute is free, busy, or workout.
// Pure functions over events the bridge read; nothing here touches the phone. CALENDAR.md.
import 'dart:math';

import '../data/library.dart';
import '../data/model.dart';

class CalEvent {
  const CalEvent({required this.id, required this.begin, required this.end, this.allDay = false, this.declined = false, this.title = ''});
  final int id;
  final DateTime begin;
  final DateTime end;
  final bool allDay;
  final bool declined;
  final String title;
}

class Span {
  const Span(this.start, this.end);
  final DateTime start;
  final DateTime end;
  int get minutes => end.difference(start).inMinutes;
}

/// Today inside the awake window: busy, workout and free minutes, and the free gaps in order.
class DayShape {
  const DayShape({required this.window, required this.busy, required this.workout, required this.free, required this.gaps, required this.workouts});
  final Span window;
  final int busy;
  final int workout;
  final int free;
  final List<Span> gaps;
  final List<Span> workouts;
  double get busyShare => window.minutes == 0 ? 0 : busy / window.minutes;
  int get busyPct => (busyShare * 100).round();
}

/// Merge overlapping spans, in time order.
List<Span> mergeSpans(Iterable<Span> spans) {
  final sorted = spans.toList()..sort((a, b) => a.start.compareTo(b.start));
  final out = <Span>[];
  for (final sp in sorted) {
    if (sp.end.isBefore(sp.start) || sp.end == sp.start) continue;
    if (out.isNotEmpty && !sp.start.isAfter(out.last.end)) {
      final last = out.removeLast();
      out.add(Span(last.start, sp.end.isAfter(last.end) ? sp.end : last.end));
    } else {
      out.add(sp);
    }
  }
  return out;
}

Span _clip(Span s, Span to) {
  final a = s.start.isBefore(to.start) ? to.start : s.start;
  final b = s.end.isAfter(to.end) ? to.end : s.end;
  return Span(a, b.isBefore(a) ? a : b);
}

/// The awake window on [day], from the settings.
Span awakeWindow(Settings st, DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  return Span(d.add(Duration(minutes: st.awakeStart)), d.add(Duration(minutes: max(st.awakeStart + 60, st.awakeEnd))));
}

/// Read the day: timed, not declined events are busy; the app's own ([ourIds]) are workout; the rest of the window is
/// free. Busy and workout are counted after merging overlaps, so two meetings at once are one block of time.
DayShape shapeDay(List<CalEvent> events, Settings st, DateTime day, {Set<int> ourIds = const {}}) {
  final window = awakeWindow(st, day);
  final timed = events.where((e) => !e.allDay && !e.declined);
  final workouts = mergeSpans(timed.where((e) => ourIds.contains(e.id)).map((e) => _clip(Span(e.begin, e.end), window)));
  final busy = mergeSpans(timed.where((e) => !ourIds.contains(e.id)).map((e) => _clip(Span(e.begin, e.end), window)));
  final taken = mergeSpans([...busy, ...workouts]);
  final gaps = <Span>[];
  var cursor = window.start;
  for (final t in taken) {
    if (t.start.isAfter(cursor)) gaps.add(Span(cursor, t.start));
    if (t.end.isAfter(cursor)) cursor = t.end;
  }
  if (window.end.isAfter(cursor)) gaps.add(Span(cursor, window.end));
  final busyMin = busy.fold(0, (a, s) => a + s.minutes);
  final workoutMin = workouts.fold(0, (a, s) => a + s.minutes);
  return DayShape(window: window, busy: busyMin, workout: workoutMin, free: max(0, window.minutes - busyMin - workoutMin), gaps: gaps, workouts: workouts);
}

/// The hour after waking and the hour before sleep are offered only with an advisory.
const advisoryMinutes = 60;

/// The first free gap of at least [minutes], from [now] on, inside the awake window. The core hours first; the first
/// and last hour of the window only when nothing else is free, with [advisory] set. Null when the day has no room.
({Span slot, bool advisory})? suggestSlot(DayShape day, int minutes, DateTime now) {
  final core = Span(day.window.start.add(const Duration(minutes: advisoryMinutes)), day.window.end.subtract(const Duration(minutes: advisoryMinutes)));
  Span? firstFit(Span within) {
    for (final g in day.gaps) {
      final start = [g.start, within.start, now].reduce((a, b) => a.isAfter(b) ? a : b);
      final end = g.end.isAfter(within.end) ? within.end : g.end;
      if (end.difference(start).inMinutes >= minutes) return Span(start, start.add(Duration(minutes: minutes)));
    }
    return null;
  }
  final inCore = firstFit(core);
  if (inCore != null) return (slot: inCore, advisory: false);
  final anywhere = firstFit(day.window);
  if (anywhere != null) return (slot: anywhere, advisory: true);
  return null;
}

String hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
String minutesOfDay(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

/// The calendar event for a finished workout: the title and the description of what actually happened.
({String title, String description}) workoutEventText(AppState s, Session x, String Function(SessionExercise) levelOf) {
  final loc = s.location(x.locationId);
  final mins = x.elapsedMinutes ?? x.estMinutes;
  final title = '${x.name} · $mins min${loc == null ? '' : ' at ${loc.name}'}';
  final lines = <String>[];
  if (x.type == 'lift') {
    for (final e in x.exercises) {
      final reps = e.attempted.map((st) => st.reps).join(', ');
      lines.add('${e.exercise.name} · ${levelOf(e)} · ${reps.isEmpty ? 'not started' : reps}');
    }
  } else {
    lines.add(x.kind == 'cardio' ? 'Cardio, ${x.minutes} minutes' : 'Stretching: ${routines[x.routine]?.name ?? x.routine}');
  }
  if (x.note.isNotEmpty) lines.add(x.note);
  return (title: title, description: lines.join('\n'));
}
