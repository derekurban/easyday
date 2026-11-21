// The heart rate the watch records during a workout, and what the finish reads from it: the average, the peak, the
// energy, and each set's peak. Samples arrive in batches, late and sometimes twice; they are kept in real time and laid
// on the workout's clock (which pauses move on) only when read. docs/app/WATCH.md.
import 'dart:math';

import '../data/model.dart';
import 'workout.dart';

/// The spacing kept between samples. The watch reads about one a second; one in five is plenty for the stats and keeps
/// a workout's samples to a few kilobytes.
const heartStepSeconds = 5;

/// Readings outside this are the sensor slipping, not a heart.
const heartFloor = 30, heartCeiling = 230;

/// How long after a set's reps its peak is still looked for: the heart keeps climbing for a little after the effort.
const setPeakAfterSeconds = 20;

/// Add a batch from the watch to [x]: (time, bpm) on the phone's clock. Kept in time order, one per [heartStepSeconds]
/// at most, only plausible readings. A batch sent twice changes nothing. [kcal] is the watch's running total.
void addHeart(Session x, List<(DateTime, int)> samples, {double? kcal, String? device}) {
  final h = x.heart ??= HeartLog();
  final all = [
    for (var i = 0; i < h.t.length; i++) (h.t[i], h.bpm[i]),
    for (final s in samples) if (s.$2 >= heartFloor && s.$2 <= heartCeiling) s,
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  final t = <DateTime>[], bpm = <int>[];
  for (final s in all) {
    if (t.isNotEmpty && s.$1.difference(t.last).inMilliseconds < heartStepSeconds * 1000) continue;
    t.add(s.$1);
    bpm.add(s.$2);
  }
  h.t = t;
  h.bpm = bpm;
  if (kcal != null && kcal > (h.kcal ?? 0)) h.kcal = kcal;
  if (device != null && device.isNotEmpty) h.device = device;
}

/// A real moment on the workout's clock: moved on by every pause that began after it, the way resuming moves the
/// workout's own times. Null inside a pause, or after the one under way began.
DateTime? onWorkoutClock(Session x, DateTime real) {
  if (x.pausedAt != null && !real.isBefore(x.pausedAt!)) return null;
  var t = real;
  for (final p in x.pauses) {
    final end = p.at.add(Duration(milliseconds: p.ms));
    if (!real.isBefore(p.at) && real.isBefore(end)) return null;
    if (p.at.isAfter(real)) t = t.add(Duration(milliseconds: p.ms));
  }
  return t;
}

typedef HeartPoint = ({DateTime t, int bpm});

/// The samples on the workout's clock, from its start to its end (or [now] while it is under way).
List<HeartPoint> heartPoints(Session x, {DateTime? now}) {
  final h = x.heart;
  final start = x.startedAt;
  if (h == null || start == null) return const [];
  final end = x.endedAt ?? now;
  final out = <HeartPoint>[];
  for (var i = 0; i < h.t.length; i++) {
    final t = onWorkoutClock(x, h.t[i]);
    if (t == null || t.isBefore(start) || (end != null && t.isAfter(end))) continue;
    out.add((t: t, bpm: h.bpm[i]));
  }
  return out;
}

class HeartSummary {
  const HeartSummary({required this.avg, required this.peak, required this.low, required this.kcal, required this.device, required this.points});
  final int avg, peak, low;
  final int? kcal;
  final String device;
  final List<HeartPoint> points;
}

/// What the finish says about the heart: null until there is half a minute of it.
HeartSummary? heartSummary(Session x, {DateTime? now}) {
  final pts = heartPoints(x, now: now);
  if (pts.length < 30 ~/ heartStepSeconds) return null;
  final sum = pts.fold(0, (a, p) => a + p.bpm);
  final kcal = x.heart?.kcal;
  return HeartSummary(
    avg: (sum / pts.length).round(), peak: pts.map((p) => p.bpm).reduce(max), low: pts.map((p) => p.bpm).reduce(min),
    kcal: kcal == null || kcal < 1 ? null : kcal.round(), device: x.heart?.device ?? '', points: pts,
  );
}

/// A set's peak: the highest reading from its start until [setPeakAfterSeconds] after its reps, never past the start of
/// the next thing. Null without readings in that time, or for a set not done.
int? setPeak(Session x, SetRef r, {List<HeartPoint>? points}) {
  final s = setOf(x, r);
  if (!s.attempted || s.at == null) return null;
  final from = s.start ?? s.at!.subtract(const Duration(seconds: 30));
  var to = s.at!.add(const Duration(seconds: setPeakAfterSeconds));
  // the next set of anything, or the next item, cuts it short
  for (final e in x.exercises) {
    for (final o in e.sets) {
      final st = o.start;
      if (st != null && st.isAfter(s.at!) && st.isBefore(to)) to = st;
    }
  }
  for (final st in x.itemStarts.values) {
    if (st.isAfter(s.at!) && st.isBefore(to)) to = st;
  }
  int? best;
  for (final p in points ?? heartPoints(x)) {
    if (p.t.isBefore(from) || p.t.isAfter(to)) continue;
    if (best == null || p.bpm > best) best = p.bpm;
  }
  return best;
}

/// An exercise's peak over all its sets.
int? exercisePeak(Session x, int ex, {List<HeartPoint>? points}) {
  final pts = points ?? heartPoints(x);
  int? best;
  for (var k = 0; k < x.exercises[ex].sets.length; k++) {
    final p = setPeak(x, (ex: ex, set: k), points: pts);
    if (p != null && (best == null || p > best)) best = p;
  }
  return best;
}

/// The one line the finish shows: 'Heart 118 avg · 156 peak · 320 kcal'.
String heartLine(HeartSummary h) => 'Heart ${h.avg} avg · ${h.peak} peak${h.kcal == null ? '' : ' · ${h.kcal} kcal'}';
