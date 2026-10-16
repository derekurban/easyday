import io, re
def patch(path, pairs):
    t = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert old in t, (path, old[:70])
        t = t.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(t)

# ---------------- model.dart
patch('lib/data/model.dart', [
("const expressionRange = {Expression.heavy: RepRange(4, 6), Expression.middle: RepRange(8, 12), Expression.light: RepRange(12, 15)};",
 "const expressionRange = {Expression.heavy: RepRange(4, 7), Expression.middle: RepRange(8, 12), Expression.light: RepRange(13, 18)};\n/// An easy day's weight, as a share of the usual. Fixed for now; tunable later (IDEAS.md).\nconst easyShare = 0.85;"),
("""    this.workingSets = defaultWorkingSets, this.extras = defaultExtras, this.spare = Spare.exercises,
    this.cardioPct = defaultCardioPct, this.stretchPct = defaultStretchPct,
  });""",
 """    this.workingSets = defaultWorkingSets, this.extras = defaultExtras, this.spare = Spare.exercises,
    this.cardioPct = defaultCardioPct, this.stretchPct = defaultStretchPct, this.mixed = false,
  });"""),
("""  Expression reps;       // the reps the goal likes; the weight follows from the level""",
 """  Expression reps;       // the reps the goal likes; the weight follows from the level
  bool mixed;            // the Mixed program: heavy and middle alternate by workout"""),
("""  int extras;            // exercises given a level-up set on a hard day, 1 to 5; 0 means all""",
 """  int extras;            // exercises trained at the next level on a hard day, 1 to 5; 0 means all"""),
("""    return g != null && g.reps == reps && g.lifts == lifts && g.moveEvery == moveEvery &&
        workingSets == defaultWorkingSets && extras == defaultExtras && spare == Spare.exercises &&""",
 """    return g != null && g.reps == reps && !mixed && g.lifts == lifts && g.moveEvery == moveEvery &&
        workingSets == defaultWorkingSets && extras == defaultExtras && spare == Spare.exercises &&"""),
("""        'workingSets': workingSets, 'extras': extras, 'spare': _e(spare), 'cardioPct': cardioPct, 'stretchPct': stretchPct,
      };""",
 """        'workingSets': workingSets, 'extras': extras, 'spare': _e(spare), 'cardioPct': cardioPct, 'stretchPct': stretchPct, 'mixed': mixed,
      };"""),
("""      cardioPct: j['cardioPct'] ?? defaultCardioPct, stretchPct: j['stretchPct'] ?? defaultStretchPct,
    );
  }
}""",
 """      cardioPct: j['cardioPct'] ?? defaultCardioPct, stretchPct: j['stretchPct'] ?? defaultStretchPct, mixed: j['mixed'] ?? false,
    );
  }
}"""),
("""  int? costOverride;      // difficulty override 1 to 3, set on the card""",
 """  int? costOverride;      // difficulty override 1 to 3, set on the card
  Expression? band;       // reps override for this exercise, set on the card; null follows the goal"""),
("""        'lastWorkingAt': _ms(lastWorkingAt),
      };""",
 """        'lastWorkingAt': _ms(lastWorkingAt), 'band': band == null ? null : _e(band!),
      };"""),
("""    ..lastWorkingAt = _d(j['lastWorkingAt']);
}""",
 """    ..lastWorkingAt = _d(j['lastWorkingAt'])
    ..band = j['band'] == null ? null : _p(Expression.values, j['band'], Expression.middle);
}"""),
("""  double relative = 1; // today's work against the user's usual (the working level): 0.6 lighter, 1 usual, 1.33 a set more
  int? pushRung;       // the push set: the last set, at the next level. Reach pushTarget and the level is yours today.
  String? pushLabel;
  int? pushTarget;

  bool isPush(int i) => pushRung != null && i == sets.length - 1;
  int targetAt(int i) => isPush(i) ? pushTarget! : target;""",
 """  double relative = 1; // today's work against the user's usual (the working level): 0.6 lighter, 1 usual, 1.1 the next level
  bool nextLevel = false; // a hard day: every set at the next level. Reach the floor on every working set and it is yours today.
  double? usualLoadKg; // loaded exercises: the weight at the user's level in today's reps, so a set can be read by its worth"""),
("""        'atCeiling': atCeiling, 'bestTotal': bestTotal, 'difficulty': difficulty, 'expression': _e(expression), 'loadKg': loadKg, 'relative': relative,
        'pushRung': pushRung, 'pushLabel': pushLabel, 'pushTarget': pushTarget, 'secPerSet': secPerSet, 'sets': sets.map((s) => s.toJson()).toList(),""",
 """        'atCeiling': atCeiling, 'bestTotal': bestTotal, 'difficulty': difficulty, 'expression': _e(expression), 'loadKg': loadKg, 'relative': relative,
        'nextLevel': nextLevel, 'usualLoadKg': usualLoadKg, 'secPerSet': secPerSet, 'sets': sets.map((s) => s.toJson()).toList(),"""),
("""      )..relative = (j['relative'] as num?)?.toDouble() ?? 1
        ..pushRung = j['pushRung']
        ..pushLabel = j['pushLabel']
        ..pushTarget = j['pushTarget'];
}""",
 """      )..relative = (j['relative'] as num?)?.toDouble() ?? 1
        ..nextLevel = j['nextLevel'] ?? false
        ..usualLoadKg = (j['usualLoadKg'] as num?)?.toDouble();
}"""),
("""  int pushes = 0;        // exercises given an extra set today
  bool noRoomToPush = false; // hard was picked but no extra set fit the minutes""",
 """  int pushes = 0;        // exercises trained at the next level today"""),
("""        'stretchMinutes': stretchMinutes, 'spareMinutes': spareMinutes, 'relative': relative, 'pushes': pushes, 'noRoomToPush': noRoomToPush,""",
 """        'stretchMinutes': stretchMinutes, 'spareMinutes': spareMinutes, 'relative': relative, 'pushes': pushes,"""),
("""      ..pushes = j['pushes'] ?? 0
      ..noRoomToPush = j['noRoomToPush'] ?? false""",
 """      ..pushes = j['pushes'] ?? 0"""),
])

# ---------------- ladder.dart
patch('lib/logic/ladder.dart', [
("""/// The expression an exercise trains in by default: the goal's reps, shifted lighter for easier exercises.
Expression expressionFor(AppState s, Exercise ex) => s.goal!.expressionFor(ex.difficulty);

/// One expression lighter: more reps, less weight. The level does not move.
Expression lighter(Expression e) => Expression.values[min(e.index + 1, Expression.values.length - 1)];""",
 """/// The reps an exercise trains in: the card's override if set; else the goal's reps (heavy and middle alternating by
/// workout on the Mixed program), shifted lighter for easier exercises.
Expression expressionFor(AppState s, Exercise ex, {int liftIndex = 0}) {
  final override = s.ex[ex.id]?.band;
  if (override != null) return override;
  final g = s.goal!;
  final base = g.mixed ? (liftIndex.isEven ? Expression.heavy : Expression.middle) : g.reps;
  return Expression.values[(base.index + (3 - ex.difficulty)).clamp(0, 2)];
}

/// What a set is worth, read at the user's usual weight: the reps it would be at that weight. The same
/// percent-of-max table that defines the expressions (Epley: max = weight x (1 + reps / 30)).
double repsEquivalent(int reps, double kg, double usualKg) => 30 * (kg * (1 + reps / 30) / usualKg - 1);"""),
])

# ---------------- builder.dart
patch('lib/logic/builder.dart', [
("""/// Sets by intent. Light is a set fewer, never under two; extra is one more.
int setsFor(String intent, int workingSets) => switch (intent) { intentLight => max(2, workingSets - 1), intentExtra => workingSets + 1, _ => workingSets };""",
 """/// Sets by intent. Light is a set fewer, never under two; working and extra are the working sets.
int setsFor(String intent, int workingSets) => intent == intentLight ? max(2, workingSets - 1) : workingSets;"""),
("""/// The dials for one energy, on a list that is already built and fitted at normal. The list never changes here.
/// Returns how many extra sets were placed (hard) so the workout can say when none fit.
int _turnDials(AppState s, List<_Slot> slots, Energy energy, GoalConfig g, double window) {""",
 """/// The dials for one energy, on a list that is already built and fitted at normal. The list never changes here.
/// Returns how many exercises train at the next level (hard).
int _turnDials(AppState s, List<_Slot> slots, Energy energy, GoalConfig g) {"""),
("""      // one more set on the hardest, as many as the setting asks and the minutes allow. An extra that does not fit is skipped.
      final byDifficulty = slots.toList()..sort((a, b) { final c = _difficulty(s, b.pick!).compareTo(_difficulty(s, a.pick!)); return c != 0 ? c : a.priority.compareTo(b.priority); });
      final n = g.extras <= 0 ? byDifficulty.length : g.extras;
      var placed = 0;
      for (final sl in byDifficulty.take(n)) {
        final st = ensureState(s, sl.pick!);
        // no room: take it from the sets of a spare-minute exercise, last added first, never below one set and never dropped.
        // If even that is not enough, give the sets back and leave the push out.
        final taken = <_Slot>[];
        for (var guard = 0; guard < 12 && _totalSeconds(s, slots) + st.secPerSet > window; guard++) {
          final donor = slots.reversed.where((x) => x.slot.endsWith('x') && x.intent != intentExtra && x.sets > 1).firstOrNull;
          if (donor == null) break;
          donor.sets--;
          taken.add(donor);
        }
        if (_totalSeconds(s, slots) + st.secPerSet <= window) {
          sl.intent = intentExtra; sl.sets = setsFor(intentExtra, g.workingSets); placed++;
        } else {
          for (final d in taken) { d.sets++; }
        }
      }
      return placed;""",
 """      // the hardest exercises train at the next level, every set: the same sets and minutes, one step heavier
      final byDifficulty = slots.toList()..sort((a, b) { final c = _difficulty(s, b.pick!).compareTo(_difficulty(s, a.pick!)); return c != 0 ? c : a.priority.compareTo(b.priority); });
      final n = g.extras <= 0 ? byDifficulty.length : g.extras;
      for (final sl in byDifficulty.take(n)) { sl.intent = intentExtra; }
      return n.clamp(0, byDifficulty.length);"""),
("""    final light = byPriority.where((x) => x.intent == intentLight && x.sets > 1).firstOrNull;
    if (light != null) { light.sets--; continue; }
    final extra = byPriority.where((x) => x.intent == intentExtra).firstOrNull;
    if (extra != null) { extra.intent = intentWorking; extra.sets = setsFor(intentWorking, g.workingSets); continue; }
    if (slots.length > 1) {""",
 """    final light = byPriority.where((x) => x.intent == intentLight && x.sets > 1).firstOrNull;
    if (light != null) { light.sets--; continue; }
    if (slots.length > 1) {"""),
("""  // 4. the dials
  final pushes = _turnDials(s, slots, o.energy, g, window);""",
 """  // 4. the dials
  final pushes = _turnDials(s, slots, o.energy, g);
  final liftIndex = plan.rotation.take(plan.index).where((r) => r.type == 'lift').length;"""),
("""    final light = sl.intent == intentLight;
    final expr = light ? lighter(expressionFor(s, ex)) : expressionFor(s, ex);
    final range = rangeFor(s, ex, expr);
    var rung = effectiveRung(ex, st, equipment);
    final ceiling = atCeiling(ex, st, equipment);
    var lightened = false;
    // light on a bodyweight exercise is one version down for more reps; on a loaded one the lighter expression does it
    if (light && !ex.loaded) rung = max(0, rung - 1);
    if (lightenHard && difficulty >= 3 && !light) { rung = max(ex.loaded ? floorRung(s, ex, st) : 0, rung - 1); lightened = true; }
    var edited = false;
    if (o.rungOverrides.containsKey(sl.slot)) { rung = o.rungOverrides[sl.slot]!; edited = true; }
    int target;
    final ceilingToday = ceiling && rung == st.rung && !light;
    if (ceilingToday && st.bestTotal > 0) {
      target = max(range.lo, ((st.bestTotal + 1) / sl.sets).ceil());
    } else {
      target = light ? max(range.lo, range.hi - 2) : range.hi;
    }
    final load = ex.loaded ? loadFor(s, ex, st, rung, expr) : null;
    // today's work against the usual: sets against the working sets, times the weight share (or one version down), times the reserve
    var relative = sl.sets / g.workingSets;
    if (light) relative *= (ex.loaded ? expressionPct[expr]! / expressionPct[expressionFor(s, ex)]! : 0.85) * 0.9;
    // the push set: the next level, aim for the floor of the range; at the ceiling, the same level for two past the top
    int? pushRung;
    String? pushLabel;
    int? pushTarget;
    if (sl.intent == intentExtra) {
      final c = ceilingFor(ex, equipment);
      pushRung = c != null && rung >= c ? rung : rung + 1;
      pushLabel = rungLabel(s, ex, st, pushRung, expr);
      pushTarget = pushRung == rung ? range.hi + 2 : range.lo;
      relative *= 1.15;
    }
    out.add(SessionExercise(
      slot: sl.slot, exId: ex.id, pattern: sl.pattern, intent: sl.intent, workingSets: g.workingSets, rung: rung, rungLabel: rungLabel(s, ex, st, rung, expr),
      target: target, lo: range.lo, hi: range.hi, atCeiling: ceilingToday, bestTotal: st.bestTotal, difficulty: difficulty, expression: expr, loadKg: load,
      secPerSet: st.secPerSet, sets: List.generate(sl.sets, (_) => SetLog()), warmups: ex.loaded && difficulty >= 3 ? warmupsFor(s, ex, load!) : const [],
      edited: edited, lightened: lightened,
    )..relative = relative..pushRung = pushRung..pushLabel = pushLabel..pushTarget = pushTarget);
  }""",
 """    final light = sl.intent == intentLight;
    final expr = expressionFor(s, ex, liftIndex: liftIndex);
    final range = rangeFor(s, ex, expr);
    var rung = effectiveRung(ex, st, equipment);
    final c = ceilingFor(ex, equipment);
    var lightened = false;
    var nextLevel = false;
    // light on a bodyweight exercise is one version down; on a loaded one the weight is a share of the usual (below)
    if (light && !ex.loaded) rung = max(0, rung - 1);
    // hard: the next level on every set, unless this is the top version here
    if (sl.intent == intentExtra && !(c != null && rung >= c)) { rung += 1; nextLevel = true; }
    if (lightenHard && difficulty >= 3 && !light && !nextLevel) { rung = max(ex.loaded ? floorRung(s, ex, st) : 0, rung - 1); lightened = true; }
    var edited = false;
    if (o.rungOverrides.containsKey(sl.slot)) { rung = o.rungOverrides[sl.slot]!; edited = true; nextLevel = false; }
    final ceilingToday = c != null && st.rung >= c && rung == st.rung && !light;
    int target;
    if (ceilingToday && st.bestTotal > 0) {
      target = max(range.lo, ((st.bestTotal + 1) / sl.sets).ceil());
    } else {
      target = range.hi;
    }
    final usual = ex.loaded ? loadFor(s, ex, st, st.rung, expr) : null;
    var load = ex.loaded ? loadFor(s, ex, st, rung, expr) : null;
    if (light && ex.loaded) load = max(stepKg(s, ex), roundStep(usual! * easyShare, stepKg(s, ex)));
    final label = ex.loaded ? fmtKg(s, load!, each: ex.each) : rungLabel(s, ex, st, rung, expr);
    // today's work against the usual: sets against the working sets, times the weight share (or one version down), times the reserve
    var relative = sl.sets / g.workingSets;
    if (light) relative *= (ex.loaded ? easyShare : 0.85) * 0.9;
    if (nextLevel) relative *= 1.1;
    out.add(SessionExercise(
      slot: sl.slot, exId: ex.id, pattern: sl.pattern, intent: sl.intent, workingSets: g.workingSets, rung: rung, rungLabel: label,
      target: target, lo: range.lo, hi: range.hi, atCeiling: ceilingToday, bestTotal: st.bestTotal, difficulty: difficulty, expression: expr, loadKg: load,
      secPerSet: st.secPerSet, sets: List.generate(sl.sets, (_) => SetLog()), warmups: ex.loaded && difficulty >= 3 ? warmupsFor(s, ex, load!) : const [],
      edited: edited, lightened: lightened,
    )..relative = relative..nextLevel = nextLevel..usualLoadKg = usual);
  }"""),
("""  )..relative = relative..pushes = pushes..noRoomToPush = o.energy == Energy.hard && pushes == 0 && out.isNotEmpty;""",
 """  )..relative = relative..pushes = out.where((e) => e.nextLevel).length;"""),
])
t = io.open('lib/logic/builder.dart', encoding='utf-8').read()
t = t.replace("  final pushes = _turnDials(s, slots, o.energy, g);\n", "  _turnDials(s, slots, o.energy, g);\n")
io.open('lib/logic/builder.dart', 'w', encoding='utf-8', newline='\n').write(t)

# ---------------- after.dart: read every set by its worth
patch('lib/logic/after.dart', [
("""Verdict verdictFor(SessionExercise e, StopReason? stop, int stopAt, int idx) {
  if (!e.atWorkingLevel) return Verdict.neutral;
  final working = e.sets.take(e.workingSets).toList();
  if (working.any((x) => !x.attempted)) {
    // the working sets were cut short
    return stop == StopReason.energy && stopAt == idx ? Verdict.miss : Verdict.neutral;
  }
  if (working.any((x) => x.reps! < e.lo)) return Verdict.miss;
  if (working.every((x) => x.reps! >= e.hi)) {
    final extra = e.sets.skip(e.workingSets).where((x) => x.attempted).toList();
    final bar = e.pushTarget ?? e.hi;
    return extra.isNotEmpty && extra.first.reps! >= bar ? Verdict.stepNow : Verdict.hit;
  }
  return Verdict.hold;
}""",
 """Verdict verdictFor(SessionExercise e, StopReason? stop, int stopAt, int idx) {
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
}"""),
("""          if (v == Verdict.stepNow) {
            // a level earned today leads the note
            ups.insert(0, '${ex.name} levels up now: ${e.pushLabel != null ? 'you reached ${e.pushTarget} at ${e.pushLabel}' : 'working sets plus one, all at the top'}.');
          } else {
            ups.add('${ex.name} levels up next time: you hit ${e.hi} on every set.');
          }""",
 """          if (v == Verdict.stepNow) {
            // a level earned today leads the note
            ups.insert(0, '${ex.name} levels up now: ${e.rungLabel} is yours, ${_reps(e.sets)}.');
          } else {
            ups.add('${ex.name} levels up next time: ${e.hi} or more on every set.');
          }"""),
("""        stays.add('${ex.name} holds: ${_reps(e.sets)}. In range, not at the top.');""",
 """        stays.add('${ex.name} holds: ${_reps(e.sets)}${e.nextLevel ? ' at the next level, worth your level' : ''}. In range.');"""),
])

# ---------------- session.dart
patch('lib/ui/session.dart', [
("""                  e.atCeiling
                      ? 'Top of the progression here. Beat ${e.bestTotal} total across ${e.sets.length} sets.'
                      : e.pushRung != null
                          ? 'Aim for ${e.target}$unit on ${e.workingSets} sets. Then a level-up set at ${e.pushLabel}: reach ${e.pushTarget}$unit and the level is yours today.'
                          : 'Aim for ${e.target}$unit every set. Range ${e.lo} to ${e.hi}. Hit the top on every set and the next level is yours.',""",
 """                  e.atCeiling
                      ? 'Top of the progression here. Beat ${e.bestTotal} total across ${e.sets.length} sets.'
                      : e.nextLevel
                          ? 'The next level. As many as you can with good form: reach ${e.lo}$unit on every set and ${e.rungLabel} is your level today.'
                          : e.intent == intentLight
                              ? 'Lighter today. ${e.lo} to ${e.hi}$unit is the range; nothing is judged.'
                              : 'As many as you can with good form. ${e.lo} to ${e.hi}$unit is the range: ${e.hi} or more on every set and the next level is yours.',"""),
("""                      color: e.sets[i].attempted ? (e.sets[i].reps! >= e.targetAt(i) ? du.accentSubtle : du.sunk) : du.surface,""",
 """                      color: e.sets[i].attempted ? (e.sets[i].reps! >= e.target ? du.accentSubtle : du.sunk) : du.surface,"""),
("""                        : e.isPush(i)
                            ? Column(mainAxisSize: MainAxisSize.min, children: [
                                Icon(LucideIcons.arrowUp, size: 16, color: i == nextSet && !skipped ? du.accentText : du.inkTertiary),
                                Text(i == nextSet && !skipped ? 'level up' : 'push', style: t.labelSmall?.copyWith(color: i == nextSet && !skipped ? du.accentText : du.inkTertiary)),
                              ])
                            : Text(i == nextSet && !skipped ? 'now' : '·', style: i == nextSet && !skipped ? t.labelMedium?.copyWith(color: du.accentText) : t.headlineMedium?.copyWith(color: du.inkTertiary)),""",
 """                        : Text(i == nextSet && !skipped ? 'now' : '·', style: i == nextSet && !skipped ? t.labelMedium?.copyWith(color: du.accentText) : t.headlineMedium?.copyWith(color: du.inkTertiary)),"""),
("""                              if (e.isPush(nextSet))
                                Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
                                  Icon(LucideIcons.arrowUp, size: 18, color: du.accentText), const SizedBox(width: 8),
                                  Expanded(child: Text('Level-up set: ${e.pushLabel}. Reach ${e.pushTarget}$unit and the level is yours today.', style: t.bodyLarge?.copyWith(color: du.accentText))),
                                ])),
                              SizedBox(height: 76, child: FilledButton.icon(
                                onPressed: () => _log(context, session, e.targetAt(nextSet)),
                                icon: Icon(e.isPush(nextSet) ? LucideIcons.arrowUp : LucideIcons.check, size: 26),
                                label: Text('Hit ${e.targetAt(nextSet)}$unit${e.isPush(nextSet) ? ' at ${e.pushLabel}' : ''}', style: t.headlineMedium?.copyWith(color: du.onAccent)),
                              )),""",
 """                              SizedBox(height: 76, child: FilledButton.icon(
                                onPressed: () => _log(context, session, e.target),
                                icon: Icon(e.nextLevel ? LucideIcons.arrowUp : LucideIcons.check, size: 26),
                                label: Text('${e.target}$unit or more', style: t.headlineMedium?.copyWith(color: du.onAccent)),
                              )),"""),
("""    final nextSet = e.sets.indexWhere((x) => !x.attempted);
    final target = nextSet < 0 ? e.target : e.targetAt(nextSet);""",
 """    final target = e.target;"""),
])
t = io.open('lib/ui/session.dart', encoding='utf-8').read()
t = t.replace("fewerValue = seconds ? ((e.targetAt(nextSet) - 5) ~/ 5) * 5 : e.targetAt(nextSet) - 1;", "fewerValue = seconds ? ((e.target - 5) ~/ 5) * 5 : e.target - 1;")
io.open('lib/ui/session.dart', 'w', encoding='utf-8', newline='\n').write(t)

# ---------------- today.dart
patch('lib/ui/today.dart', [
("""    if (session.noRoomToPush) return 'your usual; no room for a level-up set';
    if (r > 1.05) {
      final names = session.exercises.where((e) => e.pushRung != null).map((e) => e.exercise.name.toLowerCase()).toList();
      return 'your usual, plus a level-up try on ${names.length <= 2 ? names.join(' and ') : '${names.length} exercises'}';
    }""",
 """    if (r > 1.05) {
      final names = session.exercises.where((e) => e.nextLevel).map((e) => e.exercise.name.toLowerCase()).toList();
      return 'the next level on ${names.length <= 2 ? names.join(' and ') : '${names.length} exercises'}';
    }"""),
("""        '${e.pushRung != null ? '${e.workingSets} × ${e.lo} to ${e.hi}$unit, then a level-up set at ${e.pushLabel}' : '${e.sets.length} × ${e.atCeiling ? 'beat ${e.bestTotal} total' : '${e.lo} to ${e.hi}$unit, aim ${e.target}'}'}'""",
 """        '${e.sets.length} × ${e.atCeiling ? 'beat ${e.bestTotal} total' : '${e.lo} to ${e.hi}$unit'}${e.nextLevel ? ' · the next level' : e.intent == intentLight ? (e.exercise.loaded ? ' · ${(easyShare * 100).round()} % of usual' : ' · a version down') : ''}'"""),
("""        Text(e.intent == intentExtra ? 'level up' : e.intent == intentLight ? '${(e.relative * 20).round() * 5} %' : 'usual', style: t.labelSmall?.copyWith(color: du.inkTertiary)),""",
 """        Text(e.nextLevel ? 'next level' : e.intent == intentLight ? '${(e.relative * 20).round() * 5} %' : 'usual', style: t.labelSmall?.copyWith(color: du.inkTertiary)),"""),
("""        Energy.easy => weekAway ? 'A week away: easy is the default today. The same exercises at about 60 % of your usual: lighter weight, more reps, a set fewer. Two of the easier ones at full.' : 'The same exercises at about 60 % of your usual: lighter weight, more reps, a set fewer, nothing judged. Two of the easier ones at full.',
        Energy.normal => 'The same exercises at your usual: your weight, your sets, aim for the top. The work is what counts.',
        Energy.hard => 'The same exercises at your usual, then a level-up set on the hardest: the next level, aim for the floor of the range. Reach it and the level is yours today.',""",
 """        Energy.easy => weekAway ? 'A week away: easy is the default today. The same exercises, 15 % lighter (a version down for bodyweight), a set fewer, nothing judged. Two of the easier ones at full.' : 'The same exercises, 15 % lighter (a version down for bodyweight), a set fewer, nothing judged. Two of the easier ones at full.',
        Energy.normal => 'The same exercises at your level. As many reps as you can: the top of the range or more on every set and the next level is yours.',
        Energy.hard => 'The hardest exercises at the next level, every set: one step heavier, or the next version. Reach the floor of the range on every set and it is your level today.',"""),
])

# ---------------- goal editor: the program and the next-level setting
patch('lib/ui/goal_editor.dart', [
("""          ..reps = tpl.reps
          ..lifts = tpl.lifts""",
 """          ..reps = tpl.reps
          ..mixed = false
          ..lifts = tpl.lifts"""),
("""          const SectionHeader('Reps you like', icon: LucideIcons.repeat),
          Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Segmented<Expression>(
              value: g.reps,
              options: {for (final e in Expression.values) e: expressionLabel[e]!},
              icons: const {Expression.heavy: LucideIcons.weight, Expression.middle: LucideIcons.equal, Expression.light: LucideIcons.feather},
              onChanged: (v) => _set((x) => x.reps = v),
            ),
            const SizedBox(height: 8),
            Text('${r.lo} to ${r.hi} reps on the hardest exercises; easier ones get more. Same strength either way: the weight follows the reps, and your level never changes with this.', style: t.bodySmall),
          ])),""",
 """          const SectionHeader('Program', icon: LucideIcons.repeat),
          Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ChoiceRow<String>(
              label: 'Reps',
              value: g.mixed ? 'mixed' : g.reps.name,
              options: const {'heavy': 'Strength', 'middle': 'Build', 'light': 'Endurance', 'mixed': 'Mixed'},
              hint: g.mixed
                  ? 'Heavy and middle alternate by workout: A and C at 4 to 7, B and D at 8 to 12. Same levels, different reps.'
                  : '${r.lo} to ${r.hi} reps on the hardest exercises; easier ones get more. Same strength either way: the weight follows the reps, and your level never changes with this. Any exercise can be set differently on its card.',
              onChanged: (v) => _set((x) { if (v == 'mixed') { x.mixed = true; x.reps = Expression.heavy; } else { x.mixed = false; x.reps = Expression.values.byName(v); } }),
            ),
          ])),"""),
("""            ChoiceRow<int>(label: 'Hard day level-up tries', value: g.extras, options: const {1: '1', 2: '2', 3: '3', 4: '4', 5: '5', 0: 'all'}, hint: 'How many exercises get a set at the next level on a hard day, hardest first. Reach the floor of the range and the level is yours that day.', onChanged: (v) => _set((x) => x.extras = v)),""",
 """            ChoiceRow<int>(label: 'Hard day: next level on', value: g.extras, options: const {1: '1', 2: '2', 3: '3', 4: '4', 5: '5', 0: 'all'}, hint: 'How many exercises train at the next level on a hard day, hardest first. Reach the floor of the range on every set and it is your level that day.', onChanged: (v) => _set((x) => x.extras = v)),"""),
])

# ---------------- exercise card: reps override
patch('lib/ui/exercise_card.dart', [
("""        const SectionHeader('Difficulty', icon: LucideIcons.flame),""",
 """        const SectionHeader('Reps', icon: LucideIcons.repeat),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ChoiceRow<String>(
            label: 'This exercise trains at',
            value: st.band?.name ?? 'goal',
            options: {'goal': 'Goal', for (final e in Expression.values) e.name: expressionLabel[e]!},
            hint: '${range.lo} to ${range.hi} ${ex.repLabel} now. ${st.band == null ? 'Following the goal: hard exercises get the reps it likes, easier ones get more.' : 'Set here for this exercise.'} Same strength either way; the weight follows the reps.',
            onChanged: (v) => store.update((_) => st.band = v == 'goal' ? null : Expression.values.byName(v)),
          ),
        ])),
        const SizedBox(height: 20),
        const SectionHeader('Difficulty', icon: LucideIcons.flame),"""),
])

# ---------------- tests
patch('test/logic_test.dart', [
("""        // light: same level; loaded exercises go one expression lighter, bodyweight ones one version down for more reps
        if (e.exercise.loaded) {
          expect(e.rung, before[e.exId]);
          expect(e.expression, lighter(expressionFor(s, e.exercise)));
        } else {
          expect(e.rung, max(0, before[e.exId]! - 1));
        }
        expect(e.target, max(e.lo, e.hi - 2));
        expect(e.sets.length, lessThanOrEqualTo(max(2, s.goal!.workingSets - 1)));""",
 """        // light: same level; loaded exercises lift a share of the usual weight, bodyweight ones go one version down
        if (e.exercise.loaded) {
          expect(e.rung, before[e.exId]);
          expect(e.loadKg, lessThan(e.usualLoadKg!));
          expect(e.loadKg, closeTo(e.usualLoadKg! * easyShare, stepKg(s, e.exercise)));
        } else {
          expect(e.rung, max(0, before[e.exId]! - 1));
        }
        expect(e.sets.length, lessThanOrEqualTo(max(2, s.goal!.workingSets - 1)));"""),
("""      expect(sess.exercises.where((e) => e.difficulty == 3).every((e) => e.lo == 4 && e.hi == 6), isTrue);""",
 """      expect(sess.exercises.where((e) => e.difficulty == 3).every((e) => e.lo == 4 && e.hi == 7), isTrue);"""),
("""      for (final e in sess.exercises.where((e) => e.intent == intentLight)) {
        expect(e.target, max(e.lo, e.hi - 2));
        expect(e.sets.length, max(2, s.goal!.workingSets - 1));
      }""",
 """      for (final e in sess.exercises.where((e) => e.intent == intentLight)) {
        expect(e.sets.length, max(2, s.goal!.workingSets - 1));
      }"""),
("""    test('hard: one more set on the hardest exercise, more with the setting, and the gradient holds for the same minutes', () {
      final s = fresh(template: 'gym');
      practiseAll(s, secPerSet: 60);
      final sess = build(s, energy: Energy.hard, minutes: 60);
      final extras = sess.exercises.where((e) => e.intent == intentExtra).toList();
      expect(extras.length, s.goal!.extras);
      expect(extras.every((e) => e.sets.length == s.goal!.workingSets + 1 && e.pushRung == e.rung + 1 && e.pushTarget == e.lo), isTrue);
      expect(extras.first.difficulty, sess.exercises.map((e) => e.difficulty).reduce(max));
      expect(sess.exercises.first.intent, intentExtra);
      s.goal!.extras = 1;
      expect(build(s, energy: Energy.hard, minutes: 60).exercises.where((e) => e.intent == intentExtra).length, 1);""",
 """    test('hard: the hardest exercises at the next level on every set, more with the setting, and the gradient holds for the same minutes', () {
      final s = fresh(template: 'gym');
      practiseAll(s, secPerSet: 60);
      final sess = build(s, energy: Energy.hard, minutes: 60);
      final extras = sess.exercises.where((e) => e.intent == intentExtra).toList();
      expect(extras.length, s.goal!.extras);
      for (final e in extras) {
        expect(e.nextLevel, isTrue);
        expect(e.sets.length, s.goal!.workingSets);
        expect(e.rung, s.ex[e.exId]!.rung + 1);
        if (e.exercise.loaded) expect(e.loadKg, greaterThan(e.usualLoadKg!));
      }
      expect(extras.first.difficulty, sess.exercises.map((e) => e.difficulty).reduce(max));
      expect(sess.exercises.first.intent, intentExtra);
      expect(sess.pushes, extras.length);
      s.goal!.extras = 1;
      expect(build(s, energy: Energy.hard, minutes: 60).exercises.where((e) => e.intent == intentExtra).length, 1);"""),
])
t = io.open('test/logic_test.dart', encoding='utf-8').read()
# drop the two tests about room for a push
for name in ["hard says so when no extra set fits the minutes, instead of dropping an exercise", "a push that still does not fit gives the borrowed sets back"]:
    i = t.index("    test('" + name)
    j = t.index("    });\n", i) + len("    });\n")
    # swallow one following blank line
    if t[j:j+1] == "\n": j += 1
    t = t[:i] + t[j:]
t = t.replace("""      expect(rangeFor(s, ex, Expression.heavy).hi, lessThan(rangeFor(s, ex, Expression.light).lo));""",
"""      expect(rangeFor(s, ex, Expression.heavy).hi, lessThan(rangeFor(s, ex, Expression.light).lo));
      // the Mixed program alternates heavy and middle by workout; a card override wins over both
      s.goal!.mixed = true;
      expect(expressionFor(s, ex, liftIndex: 0), Expression.heavy);
      expect(expressionFor(s, ex, liftIndex: 1), Expression.middle);
      st.band = Expression.light;
      expect(expressionFor(s, ex, liftIndex: 0), Expression.light);
      st.band = null;
      s.goal!.mixed = false;""")
io.open('test/logic_test.dart', 'w', encoding='utf-8', newline='\n').write(t)

patch('test/features_test.dart', [
("""    test('the level-up set: working sets at the top, then the floor at the next level, steps up now even with step-up at 3', () {
      final s = fresh()..settings.stepUp = 3;
      ensureState(s, exerciseById['bb_squat']!).appearances = 2;
      final session = startNormal(s, energy: Energy.hard);
      final i = session.exercises.indexWhere((e) => e.intent == intentExtra);
      final e = session.exercises[i];
      expect(e.sets.length, e.workingSets + 1);
      expect(e.pushRung, e.rung + 1);
      expect(e.pushTarget, e.lo);
      expect(e.pushLabel, isNot(e.rungLabel));
      final before = s.ex[e.exId]!.rung;
      var clock = t0;
      for (var k = 0; k < e.workingSets; k++) { clock = clock.add(const Duration(minutes: 2)); logSet(session, i, e.hi, clock); }
      logSet(session, i, e.pushTarget!, clock.add(const Duration(minutes: 2)));
      finishSession(s, session, Finish(), clock.add(const Duration(minutes: 3)));
      expect(s.ex[e.exId]!.rung, before + 1);
      expect(session.note, contains('levels up now'));
    });

    test('a level-up set that falls short is still a hit, counted once', () {
      final s = fresh()..settings.stepUp = 3;
      final session = startNormal(s, energy: Energy.hard);
      final i = session.exercises.indexWhere((e) => e.intent == intentExtra);
      final e = session.exercises[i];
      final before = s.ex[e.exId]!.rung;
      var clock = t0;
      for (var k = 0; k < e.workingSets; k++) { clock = clock.add(const Duration(minutes: 2)); logSet(session, i, e.hi, clock); }
      logSet(session, i, e.pushTarget! - 1, clock.add(const Duration(minutes: 2)));
      finishSession(s, session, Finish(), clock.add(const Duration(minutes: 3)));
      expect(s.ex[e.exId]!.rung, before);
      expect(s.ex[e.exId]!.topRun, 1);
    });""",
 """    test('hard: the floor on every set at the next level makes it yours today, even with step-up at 3', () {
      final s = fresh()..settings.stepUp = 3;
      ensureState(s, exerciseById['bb_squat']!).appearances = 2;
      final session = startNormal(s, energy: Energy.hard);
      final i = session.exercises.indexWhere((e) => e.intent == intentExtra);
      final e = session.exercises[i];
      expect(e.nextLevel, isTrue);
      expect(e.sets.length, e.workingSets);
      final before = s.ex[e.exId]!.rung;
      expect(e.rung, before + 1);
      var clock = t0;
      for (var k = 0; k < e.workingSets; k++) { clock = clock.add(const Duration(minutes: 2)); logSet(session, i, e.lo, clock); }
      finishSession(s, session, Finish(), clock.add(const Duration(minutes: 3)));
      expect(s.ex[e.exId]!.rung, before + 1);
      expect(session.note, contains('levels up now'));
    });

    test('one rep short at the next level is read by its worth: within the range at your level, so it holds', () {
      final s = fresh()..settings.stepUp = 3;
      final session = startNormal(s, energy: Energy.hard);
      final i = session.exercises.indexWhere((e) => e.intent == intentExtra && e.exercise.loaded);
      final e = session.exercises[i];
      final before = s.ex[e.exId]!.rung;
      final worth = repsEquivalent(e.lo - 1, e.loadKg!, e.usualLoadKg!);
      expect(worth, inInclusiveRange(e.lo.toDouble(), e.hi.toDouble()), reason: 'one short at ${e.loadKg} is worth $worth at ${e.usualLoadKg}');
      var clock = t0;
      for (var k = 0; k < e.workingSets; k++) { clock = clock.add(const Duration(minutes: 2)); logSet(session, i, e.lo - 1, clock); }
      finishSession(s, session, Finish(), clock.add(const Duration(minutes: 3)));
      expect(s.ex[e.exId]!.rung, before);
      expect(s.ex[e.exId]!.shortRun, 0);
      expect(s.ex[e.exId]!.topRun, 0);
      expect(session.note, contains('holds'));
    });

    test('an easy day lifts 85 % of the usual, a set fewer, and is neutral', () {
      final s = fresh();
      final session = startNormal(s, energy: Energy.easy);
      final e = session.exercises.firstWhere((x) => x.intent == intentLight && x.exercise.loaded);
      expect(e.rung, s.ex[e.exId]!.rung);
      expect(e.loadKg, closeTo(e.usualLoadKg! * easyShare, stepKg(s, e.exercise)));
      expect(e.sets.length, max(2, e.workingSets - 1));
      expect(e.atWorkingLevel, isFalse);
    });"""),
])
t = io.open('test/features_test.dart', encoding='utf-8').read()
if "import 'dart:math';" not in t:
    t = t.replace("import 'dart:convert';", "import 'dart:convert';\nimport 'dart:math';")
io.open('test/features_test.dart', 'w', encoding='utf-8', newline='\n').write(t)
print('ok')
