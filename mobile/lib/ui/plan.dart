// Plan: the workout Today's answers made, laid out in order with its warm-up, cardio and stretching. Swap an
// exercise, change today's level, move it, pick the warm-up and the order, then Start: the clock starts here.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/library.dart';
import '../data/model.dart';
import '../logic/builder.dart';
import '../logic/calendar.dart';
import '../logic/ladder.dart';
import '../logic/selection.dart';
import '../logic/workout.dart';
import 'app.dart';
import 'exercise_card.dart';
import 'how.dart';
import 'motion.dart';
import 'theme.dart';
import 'widgets.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, required this.base});
  /// Today's answers: energy, the minutes or the count, the location.
  final BuildOptions base;
  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  Map<String, String> picks = {};
  Map<String, int> rungOverrides = {};
  List<String> order = [];
  Set<String> leftOut = {};
  int? warmup;
  bool skipCardio = false;
  bool skipStretch = false;

  BuildOptions _options(AppState s, {bool asBuilt = false}) {
    final b = widget.base;
    return BuildOptions(
      energy: b.energy, minutes: b.minutes, locationId: b.locationId, picks: asBuilt ? const {} : picks, rungOverrides: asBuilt ? const {} : rungOverrides,
      energyChosen: b.energyChosen, timeChosen: b.timeChosen, circuit: s.settings.circuit, exerciseCount: b.exerciseCount,
      warmupMinutes: warmup ?? s.settings.warmup, skipCardio: skipCardio, skipStretch: skipStretch, order: asBuilt ? const [] : order,
      muscles: b.muscles, leftOut: asBuilt ? const {} : leftOut, liftInstead: b.liftInstead,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final s = store.state;
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final session = buildSession(s, _options(s), store.now);
    final est = estimateMinutes(session);
    final loc = s.location(widget.base.locationId);
    final g = s.goal!;
    final items = workoutItems(session);
    double planned(WorkoutItem it) => switch (it.kind) {
          ItemKind.exercise => plannedSeconds(session.exercises[it.exercises.single]),
          ItemKind.circuit => it.exercises.fold(0.0, (a, i) => a + plannedSeconds(session.exercises[i])),
          _ => it.minutes * 60.0,
        };
    final circuit = s.settings.circuit && session.exercises.length > 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(session.name),
        actions: [
          IconButton(
            onPressed: session.exercises.isEmpty ? null : () => setState(() { picks = shufflePicks(s, session, loc?.equipment ?? const [], Random(), store.now); rungOverrides = {}; order = []; leftOut = {}; }),
            icon: const Icon(LucideIcons.shuffle, size: 20), tooltip: 'Reshuffle the exercises',
          ),
        ],
      ),
      body: Column(children: [
        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text('${energyLabel[session.energy]} · ${session.exercises.length} exercise${session.exercises.length == 1 ? '' : 's'} · about $est min · done around ${hhmm(store.now.add(Duration(minutes: est)))}', style: t.bodySmall),
            const SizedBox(height: 8),
            if (items.isNotEmpty)
              ClipRRect(borderRadius: BorderRadius.circular(4), child: SizedBox(height: 10, child: Row(children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(flex: max(1, planned(items[i]).round()), child: Container(
                    margin: EdgeInsets.only(right: i == items.length - 1 ? 0 : 2),
                    decoration: BoxDecoration(color: items[i].lifting ? (i.isEven ? du.accentStrong : du.accentText) : du.accentLine, borderRadius: BorderRadius.circular(3)),
                  )),
              ]))),
            const SizedBox(height: 6),
            Text("Each exercise's time includes its rest.", style: t.labelSmall),
            const SizedBox(height: 12),
            if (session.exercises.isEmpty)
              const Panel(child: ListTile(leading: IconBadge(LucideIcons.circleOff, size: 36), title: Text('Nothing fits here'), subtitle: Text('Add equipment to this location, or go back and move instead.')))
            else
              Panel(padding: EdgeInsets.zero, child: Column(children: [
                _blockRow(context, LucideIcons.flame, 'Warm-up', session.warmupMinutes == 0 ? 'None' : '${session.warmupMinutes} minutes, easy', session.warmupMinutes, () => _warmupSheet(context, s)),
                const Divider(height: 1),
                for (var i = 0; i < session.exercises.length; i++) ...[
                  _exerciseRow(context, session, i),
                  const Divider(height: 1),
                ],
                if (g.cardioPct > 0 || session.cardioMinutes > 0) ...[
                  _blockRow(context, LucideIcons.footprints, 'Cardio', skipCardio ? 'Not today' : 'An easy pace you could talk through', session.cardioMinutes, () => _blockSheet(context, 'Cardio', skipCardio, (v) => skipCardio = v)),
                  const Divider(height: 1),
                ],
                if (g.stretchPct > 0 || session.stretchMinutes > 0)
                  _blockRow(context, LucideIcons.stretchHorizontal, 'Stretching', skipStretch ? 'Not today' : 'For the muscles you worked', session.stretchMinutes, () => _blockSheet(context, 'Stretching', skipStretch, (v) => skipStretch = v)),
              ])),
            if (session.spareMinutes > 0) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${session.spareMinutes} min to spare, no rush.', style: t.bodySmall)),
            if (session.exercises.length > 1) ...[
              const SizedBox(height: 16),
              const SectionHeader('Order', icon: LucideIcons.repeat),
              Panel(padding: EdgeInsets.zero, child: ListTile(
                title: Text(circuit ? 'Circuit' : 'One at a time'),
                subtitle: Text(circuit ? 'One set of each, round and round, with a rest between rounds.' : 'Every set of one exercise, then the next.'),
                trailing: Icon(LucideIcons.chevronRight, size: 18, color: du.inkTertiary),
                onTap: () => _orderSheet(context, s),
              )),
            ],
            const SizedBox(height: 10),
            Text('Tap an exercise to swap it, move it or change today\'s level.', style: t.bodySmall),
          ],
        )),
        Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(color: du.bg, border: Border(top: BorderSide(color: du.line, width: 0.6))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: double.infinity, height: 56, child: FilledButton.icon(
              onPressed: session.exercises.isEmpty ? null : () => _start(context, session),
              icon: const Icon(LucideIcons.play, size: 20),
              label: const Text('Start'),
            )),
            const SizedBox(height: 6),
            Text('The clock starts now. Each exercise\'s time includes its rest.', style: t.labelSmall, textAlign: TextAlign.center),
          ]),
        ),
      ]),
    );
  }

  void _start(BuildContext context, Session session) {
    final store = context.store;
    store.update((s) {
      if (warmup != null) s.settings.warmup = warmup!;
      // the exercises the builder put on the plan that were swapped out: their count in a row goes up
      if (picks.isNotEmpty) {
        final built = buildSession(s, _options(s, asBuilt: true), store.now);
        final chosen = session.exercises.map((e) => e.exId).toSet();
        noteSwappedOut(s, [for (final e in built.exercises) if (picks.containsKey(e.slot) && !chosen.contains(e.exId)) e.exId]);
      }
      startWorkout(s, session, store.now);
    });
    Navigator.of(context).pop(true);
  }

  Widget _tag(BuildContext context, String text, {bool accent = false}) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Padding(padding: const EdgeInsets.only(left: 6), child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: accent ? du.accentSubtle : du.sunk, borderRadius: BorderRadius.circular(999), border: Border.all(color: accent ? du.accentLine : du.line, width: 0.6)),
      child: Text(text, style: t.labelSmall?.copyWith(color: accent ? du.accentText : du.inkSecondary, letterSpacing: 0)),
    ));
  }

  Widget _blockRow(BuildContext context, IconData icon, String title, String subtitle, int minutes, VoidCallback onTap) {
    final t = Theme.of(context).textTheme;
    return ListTile(
      onTap: onTap,
      leading: IconBadge(icon, size: 36),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (minutes > 0) Text('$minutes min', style: t.bodySmall),
        const SizedBox(width: 4),
        Icon(LucideIcons.chevronRight, size: 18, color: context.du.inkTertiary),
      ]),
    );
  }

  Widget _exerciseRow(BuildContext context, Session session, int i) {
    final e = session.exercises[i];
    final t = Theme.of(context).textTheme;
    final note = rungNote(e.exercise, e.rung);
    final unit = e.exercise.repLabel == 'seconds' ? ' s' : '';
    final rung = e.rungLabel == e.exercise.name ? 'standard' : e.rungLabel;
    final tag = e.nextLevel ? 'next level' : e.intent == intentLight ? (e.exercise.loaded ? '${(easyShare * 100).round()} %' : 'a version down') : e.lightened ? 'eased after a break' : e.edited ? 'edited' : null;
    final word = context.store.state.ex[e.exId]?.preference == prefNo ? 'not for you' : e.fresh ? 'new' : null;
    return ListTile(
      onTap: () => _exerciseSheet(context, session, i),
      leading: IconBadge(exerciseIcon(e.exercise), size: 36),
      title: Row(children: [
        Flexible(child: Text(e.exercise.name, overflow: TextOverflow.ellipsis)),
        if (tag != null) _tag(context, tag, accent: e.nextLevel),
        if (word != null) _tag(context, word, accent: word == 'new'),
      ]),
      subtitle: Text('${e.muscle} · $rung · ${e.sets.length} × ${e.atCeiling ? 'beat ${e.bestTotal} total' : '${e.lo} to ${e.hi}$unit'}${note != null ? '\n$note' : ''}'),
      isThreeLine: note != null,
      trailing: Text('${max(1, (plannedSeconds(e) / 60).round())} min', style: t.bodySmall),
    );
  }

  /// Move an exercise one place up or down: the order is the user's from then on, for today.
  void _move(Session session, int i, int dir) {
    final slots = session.exercises.map((e) => e.slot).toList();
    final j = i + dir;
    if (j < 0 || j >= slots.length) return;
    final tmp = slots[i];
    slots[i] = slots[j];
    slots[j] = tmp;
    setState(() => order = slots);
  }

  Future<void> _warmupSheet(BuildContext context, AppState s) async {
    final current = warmup ?? s.settings.warmup;
    final v = await showSheet<int>(context, ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 16), children: [
      const SheetHeader('Warm-up', subtitle: 'A few easy minutes before the first exercise, inside your time.', icon: LucideIcons.flame),
      for (final m in warmupChoices)
        ListTile(
          leading: IconBadge(m == 0 ? LucideIcons.circleOff : LucideIcons.flame, size: 36, accent: m == current),
          title: Text(m == 0 ? 'None' : '$m minutes, easy'),
          subtitle: Text(m == 0 ? 'Straight into the first exercise.' : m >= 8 ? 'For cold mornings and stiff days.' : m >= 5 ? 'The usual.' : 'A few moves to get warm.'),
          trailing: m == current ? Icon(LucideIcons.check, color: context.du.accentStrong) : null,
          onTap: () => Navigator.pop(context, m),
        ),
    ]));
    if (v != null) setState(() => warmup = v);
  }

  Future<void> _blockSheet(BuildContext context, String title, bool skipped, void Function(bool) set) async {
    final v = await showSheet<bool>(context, ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 16), children: [
      SheetHeader(title, subtitle: 'Its share comes from your goal. Today only.', icon: title == 'Cardio' ? LucideIcons.footprints : LucideIcons.stretchHorizontal),
      ListTile(leading: const IconBadge(LucideIcons.check, size: 36), title: const Text('Keep it'), trailing: !skipped ? Icon(LucideIcons.check, color: context.du.accentStrong) : null, onTap: () => Navigator.pop(context, false)),
      ListTile(leading: const IconBadge(LucideIcons.circleOff, size: 36), title: const Text('Not today'), subtitle: const Text('The minutes go to the lifting instead, or to spare.'), trailing: skipped ? Icon(LucideIcons.check, color: context.du.accentStrong) : null, onTap: () => Navigator.pop(context, true)),
    ]));
    if (v != null) setState(() => set(v));
  }

  Future<void> _orderSheet(BuildContext context, AppState s) async {
    final store = context.store;
    final v = await showSheet<bool>(context, ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 16), children: [
      const SheetHeader('Order', icon: LucideIcons.repeat),
      ListTile(leading: const IconBadge(LucideIcons.listOrdered, size: 36), title: const Text('One at a time'), subtitle: const Text('Every set of one exercise, then the next.'),
          trailing: !s.settings.circuit ? Icon(LucideIcons.check, color: context.du.accentStrong) : null, onTap: () => Navigator.pop(context, false)),
      ListTile(leading: const IconBadge(LucideIcons.repeat, size: 36), title: const Text('Circuit'), subtitle: const Text('One set of each, round and round, with a rest between rounds.'),
          trailing: s.settings.circuit ? Icon(LucideIcons.check, color: context.du.accentStrong) : null, onTap: () => Navigator.pop(context, true)),
    ]));
    if (v != null) store.update((x) => x.settings.circuit = v);
  }

  Future<void> _exerciseSheet(BuildContext context, Session session, int i) async {
    final store = context.store;
    final s = store.state;
    final e = session.exercises[i];
    final ex = e.exercise;
    final st = ensureState(s, ex);
    final equipmentHere = s.location(widget.base.locationId)?.equipment ?? const <String>[];
    final all = alternatives(s, session, i, equipmentHere, store.now);
    final alts = all.where((a) => preferenceOf(s.ex[a.id], store.now) != prefNo).toList();
    final notForYou = all.where((a) => preferenceOf(s.ex[a.id], store.now) == prefNo).toList();
    final ceiling = ceilingFor(ex, equipmentHere);
    var rung = e.rung;
    var showNotForYou = false;
    await showSheet<void>(context, StatefulBuilder(builder: (context, setSheet) {
      final t = Theme.of(context).textTheme;
      final du = context.du;
      final floor = ex.loaded ? floorRung(s, ex, st) : 0;
      Widget alt(Exercise a) {
        final ast = s.ex[a.id];
        final word = preferenceOf(ast, store.now);
        return ListTile(
          leading: IconBadge(exerciseIcon(a), size: 36),
          title: Text(a.name),
          subtitle: Text('${ast != null ? rungLabel(s, a, ast, ast.rung) : 'not yet practised'} · ${difficultyLabel[difficultyInPlay(a, ast)]}${word != null ? ' · ${preferenceLabel[word]!.toLowerCase()}' : ''}'),
          trailing: Icon(LucideIcons.chevronRight, size: 18, color: du.inkTertiary),
          onTap: () {
            // a manual pick of an unrated exercise counts as liked for a while; a rated one keeps its word
            store.update((x) { final target = ensureState(x, a); if (target.preference == null) target.likedUntil = store.now.add(const Duration(days: softLikeDays)); });
            setState(() {
              picks[e.slot] = a.id;
              rungOverrides.remove(e.slot);
            });
            Navigator.pop(context);
          },
        );
      }
      return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(0, 0, 0, 20), children: [
        SheetHeader(ex.name, subtitle: '${e.muscle} · ${difficultyLabel[e.difficulty]} · ${e.lo} to ${e.hi} ${ex.repLabel} · ${mmss(st.secPerSet)} per set', icon: exerciseIcon(ex)),
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 10), child: Text('Chosen because: ${e.why}.', style: t.bodySmall)),
        if (st.swappedOut >= swapsBeforeAsking)
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 12), child: Panel(sunk: true, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('You keep swapping this one out. Still like it?', style: t.bodyMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final w in [prefLiked, prefFine, prefNo])
                ActionChip(label: Text(preferenceLabel[w]!), onPressed: () { store.update((_) { st.preference = w; st.swappedOut = 0; }); setSheet(() {}); }),
            ]),
          ]))),
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 12), child: Row(children: [
          if (session.exercises.length > 1) ...[
            Expanded(child: OutlinedButton.icon(onPressed: i == 0 ? null : () { _move(session, i, -1); Navigator.pop(context); }, icon: const Icon(LucideIcons.arrowUp, size: 18), label: const Text('Up'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: i == session.exercises.length - 1 ? null : () { _move(session, i, 1); Navigator.pop(context); }, icon: const Icon(LucideIcons.arrowDown, size: 18), label: const Text('Down'))),
            const SizedBox(width: 8),
          ],
          Expanded(child: OutlinedButton.icon(onPressed: () { setState(() => leftOut.add(e.slot)); Navigator.pop(context); }, icon: const Icon(LucideIcons.circleOff, size: 18), label: const Text('Skip'))),
        ])),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeader("Today's level", icon: LucideIcons.circleDot),
            const Explain(levelExplainer),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Column(children: [
                Row(children: [
                  IconButton.outlined(onPressed: rung > floor ? () => setSheet(() => rung--) : null, icon: const Icon(LucideIcons.minus), tooltip: 'Level down'),
                  Expanded(child: AnimatedSwitcher(
                    duration: m(context, durBase),
                    transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.95, end: 1.0).animate(a), child: c)),
                    child: Column(key: ValueKey(rung), children: [
                      Text(rungLabel(s, ex, st, rung, e.range), style: t.titleMedium?.copyWith(color: rung == st.rung ? du.ink : du.accentText), textAlign: TextAlign.center),
                      Text(rungNote(ex, rung) ?? (rung == st.rung ? 'your level' : rung > st.rung ? '${rung - st.rung} up from your level' : '${st.rung - rung} down from your level'), style: t.bodySmall, textAlign: TextAlign.center),
                    ]),
                  )),
                  IconButton.outlined(onPressed: ceiling == null || rung < ceiling ? () => setSheet(() => rung++) : null, icon: const Icon(LucideIcons.plus), tooltip: 'Level up'),
                ]),
                const SizedBox(height: 8),
                AnimatedSwitcher(duration: m(context, durBase), child: Text(howAt(ex, rung), key: ValueKey('how$rung'), style: t.bodySmall)),
              ]),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: rung == e.rung ? null : () { setState(() => rungOverrides[e.slot] = rung); Navigator.pop(context); }, icon: const Icon(LucideIcons.calendarDays, size: 18), label: const Text('Just today'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: rung == st.rung ? null : () { store.update((x) => setRung(x, ex, rung)); setState(() => rungOverrides.remove(e.slot)); Navigator.pop(context); }, icon: const Icon(LucideIcons.save, size: 18), label: const Text('Save as my level'))),
            ]),
            const SizedBox(height: 20),
            if (alts.isNotEmpty || notForYou.isNotEmpty) SectionHeader('Swap for', icon: LucideIcons.replace, trailing: alts.isEmpty ? null : Text('ready first, then liked', style: t.labelSmall)),
          ]),
        ),
        for (final a in alts) alt(a),
        if (notForYou.isNotEmpty) ...[
          ListTile(
            leading: const IconBadge(LucideIcons.thumbsDown, size: 36),
            title: Text('Not for you (${notForYou.length})'),
            subtitle: const Text('Picked only when nothing else here fits. Yours to choose anyway.'),
            trailing: Icon(showNotForYou ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 18, color: du.inkTertiary),
            onTap: () => setSheet(() => showNotForYou = !showNotForYou),
          ),
          if (showNotForYou) for (final a in notForYou) alt(a),
        ],
        const SizedBox(height: 8),
        Center(child: TextButton.icon(onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseCardScreen(ex.id))); }, icon: const Icon(LucideIcons.bookOpen, size: 18), label: const Text('Open the exercise card'))),
      ]);
    }));
  }
}
