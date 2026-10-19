// The level history of one exercise, so progress can be felt as weights and versions rather than counted as levels.
// Pure functions over the state; nothing here changes a level.
import '../data/library.dart';
import '../data/model.dart';
import 'ladder.dart';

/// One point of an exercise's history: the user's level on that day, as the label they would have seen at today's reps.
class LevelPoint {
  const LevelPoint({required this.at, required this.rung, required this.label, this.kg, this.stepped = false});
  final DateTime at;
  final int rung;
  final String label;
  final double? kg;     // loaded: the weight at that level for today's reps
  final bool stepped;   // the level rose after this workout
}

/// The level of an exercise at every workout it appeared in, oldest first, then now. The level is the user's, not
/// the day's: a hard day's next level or an easy day's version down is folded back.
List<LevelPoint> levelHistory(AppState s, Exercise ex) {
  final st = s.ex[ex.id];
  if (st == null) return const [];
  final range = todayRange(s, ex);
  final out = <LevelPoint>[];
  for (final x in s.sessions) {
    if (x.type != 'lift' || x.endedAt == null) continue;
    for (final e in x.exercises) {
      if (e.exId != ex.id || e.attempted.isEmpty) continue;
      var rung = e.rung;
      if (e.nextLevel) rung -= 1;
      if (e.intent == 'light' && !ex.loaded) rung += 1;
      if (e.lightened) rung += 1;
      out.add(LevelPoint(at: x.endedAt!, rung: rung, label: rungLabel(s, ex, st, rung, range), kg: ex.loaded ? loadFor(s, ex, st, rung, range) : null));
    }
  }
  for (var i = 0; i < out.length - 1; i++) {
    if (out[i + 1].rung > out[i].rung) out[i] = LevelPoint(at: out[i].at, rung: out[i].rung, label: out[i].label, kg: out[i].kg, stepped: true);
  }
  final nowPoint = LevelPoint(at: DateTime.now(), rung: st.rung, label: rungLabel(s, ex, st, st.rung, range), kg: ex.loaded ? loadFor(s, ex, st, st.rung, range) : null);
  if (out.isNotEmpty && st.rung > out.last.rung) out[out.length - 1] = LevelPoint(at: out.last.at, rung: out.last.rung, label: out.last.label, kg: out.last.kg, stepped: true);
  out.add(nowPoint);
  return out;
}

/// The growth in words: "40 kg to 47.5 kg, 3 levels up, about 19 % more" or "knee push-ups to push-ups, 2 versions up".
String growthText(Exercise ex, LevelPoint from, LevelPoint to) {
  final d = to.rung - from.rung;
  if (d == 0) return 'holding at ${to.label}';
  final dir = d > 0 ? 'up' : 'down';
  final n = d.abs();
  if (ex.loaded && from.kg != null && to.kg != null && from.kg! > 0) {
    final pct = ((to.kg! / from.kg! - 1) * 100).round();
    return '${from.label} to ${to.label}: $n level${n == 1 ? '' : 's'} $dir, ${pct >= 0 ? '+' : ''}$pct %';
  }
  return '${from.label} to ${to.label}: $n version${n == 1 ? '' : 's'} $dir';
}
