// Playground: staging builds only. The finish screen on sample workouts, each played through the real workout logic
// into its own throwaway data, so the kinds of day it reads (a first time, a level earned, stronger than last time, a
// low-energy day, an early end) can be opened and tried as often as wanted. Nothing here touches the user's data.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/library.dart';
import '../data/model.dart';
import '../data/store.dart';
import '../logic/after.dart';
import '../logic/builder.dart';
import '../logic/ladder.dart';
import '../logic/rating.dart';
import '../logic/score.dart';
import '../logic/workout.dart';
import 'app.dart';
import 'logged.dart';
import 'motion.dart';
import 'strength_lab.dart';
import 'theme.dart';
import 'widgets.dart';

typedef _Plan = List<List<int>> Function(Session x);

/// One sample: what it shows, and how its workout (and any earlier one) is played.
class _Sample {
  const _Sample(this.title, this.blurb, this.icon, this.today, {this.before, this.template = 'gym', this.minutes = 60, this.endAfter, this.heavierToday = false, this.fresh = false, this.change = const {}});
  final String title;
  final String blurb;
  final IconData icon;
  final _Plan today;
  final _Plan? before;      // an earlier workout, logged two days before, so today reads against it
  final String template;    // the place: gym, or home_full for bodyweight
  int get warmup => 5;      // every sample starts with a five-minute warm-up
  final int minutes;
  final int? endAfter;      // minutes in: ended early
  final bool heavierToday;  // the earlier workout's weights a step lighter
  final bool fresh;         // every exercise new (no appearances)
  final Map<int, int> change; // exercise index -> steps the user moved the weight or version mid-workout (+ heavier, - lighter)
}

List<int> _top(SessionExercise e) => List.filled(e.sets.length, e.hi);
List<int> _under(SessionExercise e, [int by = 2]) => List.filled(e.sets.length, e.hi - by);
List<int> _fade(SessionExercise e) => [for (var k = 0; k < e.sets.length; k++) e.hi - 2 * k];
List<List<int>> _all(Session x, List<int> Function(SessionExercise) f, [Map<int, List<int> Function(SessionExercise)> but = const {}]) =>
    [for (var i = 0; i < x.exercises.length; i++) (but[i] ?? f)(x.exercises[i])];

final _samples = <_Sample>[
  _Sample('Chose heavier, made it', 'Put a plate on the squat yourself and got every set.', LucideIcons.flame,
      (x) => _all(x, _under, {0: (e) => [e.lo + 1, e.lo + 1, e.lo]}),
      before: (x) => _all(x, _under), change: const {0: 1}),
  _Sample('Reached for more', 'Went two plates up on the squat; not there yet.', LucideIcons.mountain,
      (x) => _all(x, _under, {0: (e) => [e.lo - 1, e.lo - 2, e.lo - 3]}),
      before: (x) => _all(x, _under), change: const {0: 2}),
  _Sample('Fell short', 'An ordinary day, the reps under the range on most lifts.', LucideIcons.sprout,
      (x) => _all(x, (e) => _under(e, e.hi - e.lo + 2)), before: (x) => _all(x, _under)),
  _Sample('Eased off', 'Dropped the weight on the row partway; the rest held.', LucideIcons.feather,
      (x) => _all(x, _under), before: (x) => _all(x, _under), change: const {1: -1}),
  _Sample('First workout', 'Everything is new: levels found at once, and a face for each.', LucideIcons.sparkles, (x) => _all(x, _top), fresh: true),
  _Sample('One level up', 'Squat earns its step; the rest beat last time by a few reps.', LucideIcons.trendingUp,
      (x) => _all(x, _under, {0: _top, 1: (e) => _under(e, 1)}),
      before: (x) => _all(x, _under, {2: (e) => _under(e, 4)})),
  _Sample('Big day', 'Three levels at once, after a week of steady work.', LucideIcons.partyPopper, (x) => _all(x, _top),
      before: (x) => _all(x, _under)),
  _Sample('Heavier than last time', 'Same reps as last time, a plate heavier.', LucideIcons.dumbbell, (x) => _all(x, (e) => _under(e, 3)),
      before: (x) => _all(x, (e) => _under(e, 3)), heavierToday: true),
  _Sample('Steady day', 'Just like last time. Nothing up, nothing down.', LucideIcons.equal, (x) => _all(x, _under),
      before: (x) => _all(x, _under)),
  _Sample('Low-energy day', 'Finished, but every exercise faded.', LucideIcons.batteryLow, (x) => _all(x, _fade),
      before: (x) => _all(x, _under)),
  _Sample('Out of time', 'Two exercises in, the clock ran out.', LucideIcons.clock, (x) => [_top(x.exercises[0]), _top(x.exercises[1])],
      before: (x) => _all(x, _under), minutes: 60, endAfter: 45),
  _Sample('It has to ask', 'Ended early, and time and a fade both fit.', LucideIcons.circleHelp, (x) => [_top(x.exercises[0]), _fade(x.exercises[1])],
      before: (x) => _all(x, _under), endAfter: 44),
  _Sample('Bodyweight at home', 'Push-ups and friends: a harder version earned on each.', LucideIcons.house, (x) => _all(x, (e) => [e.hi + 8, e.hi + 8, e.hi + 7]),
      before: (x) => _all(x, _top), template: 'none'),
];

/// The samples' titles, in order, for the tests.
@visibleForTesting
List<String> get playgroundSampleTitles => [for (final p in _samples) p.title];

/// Play a sample into its own state: an earlier workout first when it has one, then today's, ended and waiting on the
/// finish screen.
Store _build(_Sample p) {
  final t0 = DateTime.now();
  final s = AppState()
    ..profile = Profile(experience: 'some', daysPerWeek: 3, createdAt: t0.subtract(const Duration(days: 30)))
    ..goal = GoalConfig.fromTemplate(goals['muscle']!);
  final tpl = templates.firstWhere((t) => t.id == p.template);
  s.locations = [Location(id: 'l1', name: tpl.name, template: tpl.id, equipment: tpl.equipment.toList())];
  s.lastLocationId = 'l1';
  s.plan = Plan();
  Session run(_Plan plan, DateTime at, int? endAfter, {Session? again}) {
    final x = again ?? buildSession(s, BuildOptions(energy: Energy.normal, minutes: p.minutes, warmupMinutes: p.warmup), at);
    if (!p.fresh && p.before == null) {
      for (final e in x.exercises) { ensureState(s, e.exercise)..appearances = 3..calibrating = false; }
    }
    // the user's own changes, as the weight drawer makes them: the plan's level is kept, the sets are done at the new one
    if (again != null || p.before == null) {
      for (final c in p.change.entries) {
        if (c.key >= x.exercises.length) continue;
        final e = x.exercises[c.key];
        if (e.exercise.loaded) {
          changeLevel(s, x, c.key, kg: (e.loadKg ?? 0) + c.value * stepKg(s, e.exercise));
        } else {
          changeLevel(s, x, c.key, rung: (e.rung + c.value).clamp(0, 99));
        }
      }
    }
    startWorkout(s, x, at);
    var t = at;
    if (p.warmup > 0) { t = t.add(Duration(minutes: p.warmup)); ready(x, t); }
    final want = plan(x);
    for (var i = 0; i < x.exercises.length && i < want.length; i++) {
      if (want[i].isEmpty) break;
      for (final r in want[i]) {
        t = t.add(const Duration(seconds: 40));
        enterReps(x, r < 0 ? 0 : r, t);
        t = t.add(const Duration(seconds: 90));
        ready(x, t);
      }
    }
    endWorkout(x, endAfter == null ? t : at.add(Duration(minutes: endAfter)));
    return x;
  }
  Session? earlier;
  if (p.before != null) {
    final x0 = run(p.before!, t0.subtract(const Duration(days: 2, hours: 1)), null);
    earlier = _fresh(x0); // today repeats the earlier workout's exercises, so there is a last time to read against
    if (p.heavierToday) {
      for (final e in x0.exercises) {
        if (!e.exercise.loaded) continue;
        final step = stepKg(s, e.exercise);
        for (final l in e.sets) { if (l.kg != null) l.kg = l.kg! - step; }
      }
    }
    finishSession(s, x0, Finish(endRead: EndRead.done), x0.endedAt!);
  }
  s.active = run(p.today, t0.subtract(const Duration(hours: 1)), p.endAfter, again: earlier);
  return Store(s, null, shiftClock: false);
}

/// A copy of a workout as it was planned, nothing done yet: the same exercises, levels and sets, ready to play again.
Session _fresh(Session done) {
  final x = Session.fromJson(jsonDecode(jsonEncode(done.toJson())) as Map<String, dynamic>)
    ..startedAt = null
    ..endedAt = null
    ..pausedAt = null
    ..pausedSeconds = 0
    ..itemStarts = {}
    ..skipped = []
    ..reviewing = false
    ..endRead = null
    ..painAt = null
    ..stopReason = null
    ..stopAt = null
    ..note = '';
  for (final e in x.exercises) {
    e.call = null;
    for (final l in e.sets) { l..reps = null..at = null..start = null..rung = null..kg = null; }
  }
  return x;
}

class PlaygroundScreen extends StatelessWidget {
  const PlaygroundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    startLabPerson(context.store.state, context.store.now);
    return Scaffold(
      appBar: AppBar(title: const Text('Playground')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        Text('Ideas to try before they reach the app. Nothing here touches your workouts or levels.',
            style: t.bodyMedium?.copyWith(color: du.inkSecondary)),
        const SizedBox(height: 16),
        const Subhead('Strength rating', icon: LucideIcons.gauge),
        const SizedBox(height: 10),
        // the lines follow who the lab rates against, set inside any exercise
        ValueListenableBuilder(valueListenable: labPerson, builder: (context, _, _) => Panel(padding: EdgeInsets.zero, clip: true, child: Column(children: [
          // the rank across every lift: the ratings averaged
          Builder(builder: (context) {
            final all = [for (final (id, _) in strengthLabExercises) strengthLabRating(id)];
            final mean = all.reduce((a, b) => a + b) / all.length;
            return ListTile(
              leading: IconBadge(LucideIcons.trophy, size: 38, accent: true),
              title: Text('Overall: ${rankOf(mean).name} · ${mean.round()}'),
              subtitle: const Text('The ratings of the lifts below, averaged: one rank for all of you'),
            );
          }),
          Divider(height: 1, color: du.line),
          for (var i = 0; i < strengthLabExercises.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 64, color: du.line),
            Builder(builder: (context) {
              final ex = exerciseById[strengthLabExercises[i].$1]!;
              return ListTile(
                leading: IconBadge(ex.loaded ? LucideIcons.dumbbell : LucideIcons.personStanding, size: 38),
                title: Text(ex.name),
                subtitle: Text(strengthLabSummary(ex.id)),
                trailing: Icon(LucideIcons.chevronRight, size: 18, color: du.inkTertiary),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => StrengthLabScreen(exerciseId: ex.id))),
              );
            }),
          ],
        ]))),
        const SizedBox(height: 20),
        _Collapsible(title: 'Finish screen', icon: LucideIcons.flag, child: Panel(padding: EdgeInsets.zero, clip: true, child: Column(children: [
          for (var i = 0; i < _samples.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 64, color: du.line),
            ListTile(
              leading: IconBadge(_samples[i].icon, size: 38),
              title: Text(_samples[i].title),
              subtitle: Text(_samples[i].blurb),
              trailing: Icon(LucideIcons.chevronRight, size: 18, color: du.inkTertiary),
              onTap: () => _open(context, _samples[i]),
            ),
          ],
        ]))),
      ]),
    );
  }

  /// The finish screen over its own sample data, with its own navigator so its drawers read the sample too.
  void _open(BuildContext context, _Sample p) {
    final store = _build(p);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (outer) => StoreScope(store: store, child: Navigator(
      onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => LoggedView(
        session: store.state.active!,
        onDone: () => Navigator.of(outer).pop(),
        onReopen: () {
          Navigator.of(outer).pop();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('In the app this goes back to the workout.')));
        },
      )),
    ))));
  }
}

/// A section that opens and closes under its heading: for what is kept to revisit, out of the way until then.
class _Collapsible extends StatefulWidget {
  const _Collapsible({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;
  @override
  State<_Collapsible> createState() => _CollapsibleState();
}

class _CollapsibleState extends State<_Collapsible> {
  bool open = false;
  @override
  Widget build(BuildContext context) {
    final du = context.du;
    final dur = m(context, durSlow);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => open = !open),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
          Expanded(child: Subhead(widget.title, icon: widget.icon)),
          AnimatedRotation(turns: open ? 0.5 : 0, duration: dur, child: Icon(LucideIcons.chevronDown, size: 18, color: du.inkTertiary)),
        ])),
      ),
      AnimatedSize(duration: dur, curve: Curves.easeOutCubic, alignment: Alignment.topCenter,
          child: open ? Padding(padding: const EdgeInsets.only(top: 8), child: widget.child) : const SizedBox(width: double.infinity)),
    ]);
  }
}
