// Logged: the end of a lifting workout, before it counts. The app says what it read (how it ended, each exercise's
// average against its level) and anything dotted can be changed: a set opens the workout screen on it, a pill or the
// ending read changes in place. Done logs it. Replaces the stop question and the feel tap (docs/prototypes/after.html).
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/model.dart';
import '../logic/calibrate.dart';
import '../logic/ladder.dart';
import '../logic/rating.dart';
import '../logic/score.dart';
import '../logic/selection.dart';
import '../logic/workout.dart';
import 'app.dart';
import 'fresh.dart';
import 'palette.dart';
import 'edit_drawer.dart';
import 'motion.dart';
import 'rank.dart';
import 'theme.dart';
import 'widgets.dart';

class LoggedView extends StatefulWidget {
  const LoggedView({super.key, required this.session, required this.onDone, required this.onReopen});
  final Session session;
  final VoidCallback onDone;
  final VoidCallback onReopen;
  @override
  State<LoggedView> createState() => _LoggedViewState();
}

class _LoggedViewState extends State<LoggedView> {
  final _open = <String>{};
  final _painKey = GlobalKey(); // the pain panel, scrolled into view as it opens
  bool _details = false;
  ({List<int> ups, List<int> rows, bool early, bool celebrate})? _shape; // the finish's layout, fixed when it opens
  int? _headline; // the day's biggest moment: the first level earned, else the first push made good // the table and its drawer, behind Check or fix details
  void _toggle(String k) {
    HapticFeedback.selectionClick();
    setState(() => _open.contains(k) ? _open.remove(k) : _open.add(k));
    // what hurt opens below the fold: bring it up so its choices are not hidden behind Done
    if (k == 'pain' && _open.contains('pain')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _painKey.currentContext;
        if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 300), alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final store = context.store;
    final s = store.state;
    final x = widget.session;
    final w = readWorkout(s, x, store.now);
    final dotted = TextStyle(decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dotted, decorationColor: du.inkTertiary, decorationThickness: 2);
    final moments = momentsOf(s, x, w);
    _headline = moments.where((v) => v.moment == Moment.levelUp).firstOrNull?.index ?? moments.where((v) => v.moment == Moment.pushed).firstOrNull?.index;
    final tone = toneOf(moments, w);
    // the page's shape is fixed when it opens: what levelled up, the rows, whether it ended early, whether it
    // celebrates. Changes made here then animate inside their own card or row, and nothing else moves or replays.
    _shape ??= (
      ups: [for (final v in moments) if (v.moment == Moment.levelUp) v.index],
      rows: [for (final v in moments) if (v.moment != Moment.levelUp) v.index],
      early: !w.finished,
      celebrate: tone == Tone.celebrate,
    );
    final shape = _shape!;
    ExerciseMoment momentOf(int i) => moments.firstWhere((v) => v.index == i);
    final sets = x.exercises.fold(0, (a, e) => a + e.attempted.length);
    final done = x.exercises.where((e) => e.attempted.isNotEmpty).length;
    final minutes = max(1, (checkSeconds(x, store.now) / 60).round());
    final week = workoutsThisWeek(s, x);
    final overall = overallRating(s, store.now, plus: x);
    final page = _details
        ? Column(key: const ValueKey('details'), children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 4), child: Row(children: [
              IconButton(tooltip: 'Back', onPressed: () => setState(() => _details = false), icon: const Icon(LucideIcons.arrowLeft)),
              const SizedBox(width: 4),
              Expanded(child: Text('Details', style: t.titleLarge)),
              Text(mmss(checkSeconds(x, store.now).toDouble()), style: t.titleLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
              const SizedBox(width: 8),
            ])),
            Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), children: [
            if (!w.finished) ...[_endCard(context, x, w), const SizedBox(height: 12)],
            ..._did(context, x, w),
            const SizedBox(height: 4),
            if (_open.contains('pain')) _pain(context, x) else _quietLinks(context, dotted),
          ])),
          ])
        : Stack(key: const ValueKey('finish'), children: [
            ListView(padding: const EdgeInsets.fromLTRB(20, 36, 20, 16), children: [
              Center(child: _Badge(tone: tone)),
              const SizedBox(height: 20),
              Reveal(delay: const Duration(milliseconds: 150), child: AnimatedSwitcher(duration: m(context, durSlow),
                  child: Text(toneHeadline(tone, moments), key: ValueKey(toneHeadline(tone, moments)), style: t.headlineLarge, textAlign: TextAlign.center))),
              const SizedBox(height: 8),
              Reveal(delay: const Duration(milliseconds: 250), child: Text('$minutes min · $done ${done == 1 ? 'exercise' : 'exercises'} · $sets ${sets == 1 ? 'set' : 'sets'}',
                  style: t.bodyLarge?.copyWith(color: du.inkSecondary), textAlign: TextAlign.center)),
              if (week > 1) Reveal(delay: const Duration(milliseconds: 320), child: Padding(padding: const EdgeInsets.only(top: 4),
                  child: Text('Your ${_ordinal(week)} workout this week', style: t.bodyMedium?.copyWith(color: du.accentText), textAlign: TextAlign.center))),
              // the overall strength rating, and what today did to it
              if (overall != null) Reveal(delay: const Duration(milliseconds: 380), child: Padding(padding: const EdgeInsets.only(top: 12), child: _overall(context, overall))),
              const SizedBox(height: 28),
              for (final (k, i) in [...shape.ups, ...shape.rows].indexed) Padding(key: ValueKey('ex$i'), padding: const EdgeInsets.only(bottom: 10),
                  child: Reveal(delay: Duration(milliseconds: 400 + 90 * k), child: _tile(context, x, w, momentOf(i)))),
              if (shape.early) Padding(key: const ValueKey('end'), padding: const EdgeInsets.only(bottom: 10),
                  child: Reveal(delay: Duration(milliseconds: 400 + 90 * (shape.ups.length + shape.rows.length)), child: _endCard(context, x, w))),
              const SizedBox(height: 24),
              AnimatedSwitcher(duration: m(context, durSlow), child: Text(toneSignOff(tone), key: ValueKey(toneSignOff(tone)),
                  style: t.bodyMedium?.copyWith(color: du.inkSecondary), textAlign: TextAlign.center)),
            ]),
            if (shape.celebrate) const Positioned.fill(child: IgnorePointer(child: _Confetti())),
          ]);
    final button = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!_details) TextButton(
        onPressed: () { HapticFeedback.selectionClick(); setState(() => _details = true); },
        style: TextButton.styleFrom(foregroundColor: du.inkSecondary),
        child: const Text('Check or fix details'),
      ),
      SizedBox(height: 56, child: FilledButton.icon(onPressed: widget.onDone, icon: const Icon(LucideIcons.check, size: 18), label: const Text('Done'))),
    ]);
    // the system back on the details goes back to the finish
    return PopScope(canPop: false, onPopInvokedWithResult: (_, _) { if (_details) setState(() => _details = false); }, child: Scaffold(body: SafeArea(child: Column(children: [
      Expanded(child: AnimatedSwitcher(
        duration: m(context, durSlow),
        transitionBuilder: (child, a) => FadeTransition(opacity: a, child: SlideTransition(
            position: Tween(begin: Offset(child.key == const ValueKey('details') ? 0.08 : -0.08, 0), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child)),
        child: page,
      )),
      Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), child: button),
    ]))));
  }

  /// The overall strength rating as one centred line: its rank, the number, and the change today made, when it made one.
  /// A new overall rank, or the first one, pops in. Unranked until enough lifts have found their level: how many to go.
  Widget _overall(BuildContext context, OverallPoint o) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final rating = o.rating;
    if (o.stage == RankStage.unranked || rating == null) {
      return Text('Unranked · ${o.toGo} more ${o.toGo == 1 ? 'exercise' : 'exercises'} to calibrate for your first rank',
          style: t.bodyMedium?.copyWith(color: du.inkSecondary), textAlign: TextAlign.center);
    }
    final before = o.change == null ? null : rating - o.change!;
    final pop = o.firstRank || (before != null && rankOf(rating).index > rankOf(before).index);
    return Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 4, children: [
      pop
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: m(context, const Duration(milliseconds: 800)),
              curve: Curves.elasticOut,
              builder: (context, v, child) => Transform.scale(scale: v, child: child),
              child: RankBadge(rankOf(rating).index, provisional: o.stage == RankStage.provisional),
            )
          : RankBadge(rankOf(rating).index, provisional: o.stage == RankStage.provisional),
      const SizedBox(width: 10),
      Text('Strength ${rating.round()}', style: t.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
      if (before != null) ...[
        const SizedBox(width: 8),
        RatingDelta(rating: rating, before: before, withRank: false),
      ],
      if (o.firstRank) ...[
        const SizedBox(width: 8),
        Text('your first rank', style: t.bodyMedium?.copyWith(color: du.accentText)),
      ] else if (o.stage == RankStage.provisional) ...[
        const SizedBox(width: 8),
        Text('provisional', style: t.bodyMedium?.copyWith(color: du.inkSecondary)),
      ],
    ]);
  }

  static String _ordinal(int n) => switch (n % 100) {
        11 || 12 || 13 => '${n}th',
        _ => switch (n % 10) { 1 => '${n}st', 2 => '${n}nd', 3 => '${n}rd', _ => '${n}th' },
      };

  /// The colours for where an exercise goes next time: harder in the earned ink, easier in the calm one (the app taking
  /// it easy, not a warning), the same in quiet ink. From the palette in use (palette.dart).
  Color _callColor(BuildContext context, Call c) {
    final p = StatePalette.of(context);
    return switch (c) { Call.up => p.earnedInk.of(context), Call.down => p.gentleInk.of(context), Call.hold => context.du.inkSecondary };
  }

  /// The same, picked among the three: the accent, so it reads as chosen rather than switched off.
  Color _segColor(BuildContext context, Call c) => c == Call.hold ? context.du.accentText : _callColor(context, c);

  /// The row's mark: what happened today, unless next time moves, when it shows which way. It changes, in place, as the
  /// user changes where it lands.
  (IconData, Color) _markOf(BuildContext context, ExerciseMoment v, ExerciseRead r) {
    final du = context.du;
    final p = StatePalette.of(context);
    final up = p.earnedInk.of(context), easy = p.gentleInk.of(context);
    if (v.moment == Moment.hurt) return (LucideIcons.bandage, p.hurtInk.of(context));
    if (r.judged && r.call == Call.down) return (LucideIcons.arrowDown, easy);
    if (r.judged && r.call == Call.up && v.moment != Moment.pushed) return (LucideIcons.arrowUp, up);
    return switch (v.moment) {
      Moment.pushed => (LucideIcons.flame, p.pushInk.of(context)),
      Moment.levelUp => (LucideIcons.arrowUp, up),
      Moment.better => (LucideIcons.trendingUp, du.accentText),
      // reaching for more is effort, said in the push's colour; short of the range is the calm one
      Moment.reached => (LucideIcons.mountain, p.pushInk.of(context)),
      Moment.short => (LucideIcons.sprout, easy),
      Moment.eased => (LucideIcons.feather, easy),
      Moment.first => (LucideIcons.compass, freshInk(context)),
      _ => (LucideIcons.equal, du.inkSecondary),
    };
  }

  /// One exercise on the finish, in the one tile every exercise shares: a mark for what happened, a small label when it
  /// is a level earned or a first time, its name, the plain line, and at the right where it goes next time in a word
  /// (Harder, Same, Easier). A first time asks how the level was, with Right picked; Too light or Too heavy opens a
  /// wheel of levels to pick next time's, and the rating sits under it. A tap on any other tile opens the same three
  /// words to change it. A level earned fills the tile with the sweep; changed to Same, it turns plain in place.
  Widget _tile(BuildContext context, Session x, WorkoutRead w, ExerciseMoment v) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final store = context.store;
    final s = store.state;
    final r = w.exercises[v.index];
    final e = x.exercises[v.index];
    final ex = e.exercise;
    final st = ensureState(s, ex);
    final judged = r.judged && x.painAt != v.index;
    final first = judged && st.appearances == 0;
    final tested = e.sets.any((l) => l.test);
    // a level earned and the user's own push made good: the wins. How much colour they take is the finish's restraint
    // (palette.dart): the sweep fills every win, or only the day's headline, or none; the others wear an edge, or nothing
    final style = PaletteScope.finishOf(context);
    final stepped = judged && r.call == Call.up && v.moment != Moment.levelUp && v.moment != Moment.pushed && !first;
    final win = v.moment == Moment.levelUp || v.moment == Moment.pushed || stepped;
    final magic = win && (style == FinishColour.sweep || (style == FinishColour.oneMoment && v.index == _headline));
    final edged = win && !magic && style != FinishColour.marks;
    final kind = magic ? _Kind.magic : edged ? _Kind.edge : first && style != FinishColour.marks ? _Kind.first : _Kind.plain;
    // a win's own ink, for its label when its tile is not filled
    final winInk = v.moment == Moment.pushed ? StatePalette.of(context).pushInk.of(context) : StatePalette.of(context).earnedInk.of(context);
    // your own push in its sweep, a level earned in the earned one
    final sweep = v.moment == Moment.pushed ? StatePalette.of(context).push : StatePalette.of(context).earned;
    final open = _open.contains('v${v.index}');
    final dur = m(context, const Duration(milliseconds: 340));
    const white = Color(0xFFFFFFFF);
    // where it goes next time: the app's own read is kept as no choice at all
    void call(Call c, {int? next, String? feel}) {
      HapticFeedback.selectionClick();
      store.update((_) {
        e.call = c == r.auto && next == null ? null : c.name;
        e.next = next;
        e.feel = feel;
        e.reps = null;
      });
      setState(() {});
    }
    final eq = s.location(x.locationId)?.equipment ?? const <String>[];
    final level = ex.loaded ? fmtLoad(s, ex, e.loadKg ?? 0, equipment: eq) : 'it';
    // a first time: the levels on the side the user said, for the wheel
    final range = nextRange(s, x, e);
    List<(int, String)> side(Call c) => [
          if (c == Call.up) for (var k = st.rung + 1; k <= range.hi; k++) (k, rungLabel(s, ex, st, k, e.range, eq)),
          if (c == Call.down) for (var k = range.lo; k < st.rung; k++) (k, rungLabel(s, ex, st, k, e.range, eq)),
        ];
    final Widget mark;
    if (magic) {
      mark = _Twinkle(key: ValueKey(v.moment), icon: v.moment == Moment.pushed ? LucideIcons.flame : LucideIcons.sparkles);
    } else if (first && r.call == Call.hold) {
      mark = const _FirstMark(key: ValueKey('first'));
    } else {
      final (icon, fg) = _markOf(context, v, r);
      mark = Container(key: ValueKey(icon), width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: fg.withValues(alpha: 0.13)),
          child: Icon(icon, size: 18, color: fg));
    }
    // the rating through every logged workout and this one; nothing when this one does not rate (it hurt)
    final history = x.painAt == v.index ? const <RatedWorkout>[] : ratingHistory(s, ex, store.now, plus: x);
    final rated = history.isNotEmpty && history.last.at == (x.startedAt ?? store.now) ? history : const <RatedWorkout>[];
    final label = v.moment == Moment.pushed ? 'YOUR PUSH' : stepped ? 'STEPPING UP' : win ? 'LEVELLED UP' : first ? 'FIRST TIME' : null;
    final labelStyle = t.labelSmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w600, color: magic ? white.withValues(alpha: 0.88) : win ? winInk : white.withValues(alpha: 0.88));
    final p = StatePalette.of(context);
    // next time as a weight at the right: the level it lands on, an arrow and the step's colour when it moves. A tap opens
    // easier, the same and harder as pills; a first time without calibration sets keeps its question instead
    final chip = judged && !(first && !tested);
    final moving = r.call != Call.hold;
    final chipInk = r.call == Call.up ? winInk : r.call == Call.down ? p.gentleInk.of(context) : first ? freshInk(context) : du.inkSecondary;
    // at most a third of the tile, so a long version name never pushes the exercise's own name out
    final weightChip = !chip ? null : ConstrainedBox(constraints: const BoxConstraints(maxWidth: 132), child: Pressable(borderRadius: 999, onTap: () => _toggle('v${v.index}'), child: AnimatedContainer(
      duration: dur,
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: moving ? (magic ? white.withValues(alpha: 0.2) : chipInk.withValues(alpha: 0.12)) : Colors.transparent,
        border: Border.all(color: moving ? Colors.transparent : (magic ? white.withValues(alpha: 0.5) : du.line), width: 0.8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (moving) Icon(r.call == Call.up ? LucideIcons.arrowUp : LucideIcons.arrowDown, size: 14, color: magic ? white : chipInk),
        if (moving) const SizedBox(width: 4),
        // the new weight rolls up into place
        Flexible(child: AnimatedSwitcher(
          duration: dur,
          transitionBuilder: (c, a) => ClipRect(child: SlideTransition(position: Tween(begin: Offset(0, r.call == Call.down ? -0.8 : 0.8), end: Offset.zero).animate(a), child: FadeTransition(opacity: a, child: c))),
          child: Text(r.outcome, key: ValueKey(r.outcome), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(color: magic ? white : chipInk, fontWeight: FontWeight.w600)),
        )),
      ]),
    )));
    return _StepUp(up: judged && r.call == Call.up && !first, down: judged && r.call == Call.down, colors: sweep, calm: p.gentleInk.of(context), child: _frame(context, kind, sweep: sweep, onTap: chip ? () => _toggle('v${v.index}') : null, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnimatedSwitcher(duration: dur, transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)), child: mark),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AnimatedSize(duration: dur, curve: Curves.easeOutCubic, alignment: Alignment.topLeft, child: label == null
              ? const SizedBox(width: double.infinity)
              : Padding(padding: const EdgeInsets.only(bottom: 2), child: win
                  ? Text(label, style: labelStyle)
                  : _FreshText(child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(LucideIcons.sparkle, size: 11),
                      const SizedBox(width: 4),
                      Text(label, style: labelStyle),
                    ])))),
          AnimatedDefaultTextStyle(duration: dur, style: t.titleMedium!.copyWith(color: magic ? white : du.ink), child: Text(_title(x, r))),
          AnimatedSwitcher(
            duration: dur,
            layoutBuilder: (c, p) => Stack(alignment: Alignment.topLeft, children: [...p, ?c]),
            child: Text(v.text, key: ValueKey(v.text), style: t.bodyMedium?.copyWith(color: magic ? white.withValues(alpha: 0.9) : du.inkSecondary)),
          ),
        ])),
        // the word for next time only when next time moves, or the user chose it: Same on every row was noise. A first
        // time has none: its question (or its calibration) decides. Any other tile still opens the three words on a tap
        if (judged) Padding(padding: const EdgeInsets.only(left: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          ?weightChip,
          // how today moved the strength rating, only when it did
          // a level still being found, or found today, moves nothing worth a delta
          if (rated.length > 1 && rated[rated.length - 2].stage != LiftStage.calibrating) Padding(padding: const EdgeInsets.only(top: 4),
              child: RatingDelta(rating: rated.last.rating, before: rated[rated.length - 2].rating, onMagic: magic)),
        ])),
      ]),
      // calibration sets found the weight: the chip says it. Still looking: said once, the chip has where it starts
      if (first && tested && !calibratedToday(e)) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Still finding your weight',
          style: t.bodyMedium?.copyWith(color: freshInk(context), fontWeight: FontWeight.w600))),
      if (first && tested) _rating(context, st),
      // a first time: how the level was, Right unless the reps said plainly otherwise
      if (first && !tested) ...[
        _ask(context, ex.loaded ? 'How was $level?' : 'How was it?', _segments(context, [
          for (final (c, word) in [(Call.up, ex.loaded ? 'Too light' : 'Too easy'), (Call.hold, 'Right'), (Call.down, ex.loaded ? 'Too heavy' : 'Too hard')])
            if (r.levels.containsKey(c)) (word, null, r.call == c, _segColor(context, c), () => call(c, feel: c.name)),
        ])),
        if (r.call != Call.hold) KeyedSubtree(key: ValueKey('strip${r.call}'), child: _ask(context, 'Next time', _LevelStrip(
          values: side(r.call),
          initial: r.levels[r.call]!,
          color: _callColor(context, r.call),
          onChanged: (k) { store.update((_) { e.call = r.call.name; e.next = k; }); setState(() {}); },
        ))),
        _rating(context, st),
      ],
      // next time, opened from the chip or the tile: easier, the same, harder, as the take's pills
      if (open && chip) Padding(padding: const EdgeInsets.only(left: 52, top: 12), child: ChoicePills<Call>(
        label: 'Next time',
        value: r.call,
        onPick: (c) => call(c),
        options: [
          if (r.levels.containsKey(Call.down)) (value: Call.down, icon: LucideIcons.minus, word: 'Easier', color: magic ? white : p.gentleInk.of(context)),
          (value: Call.hold, icon: LucideIcons.equal, word: 'Same', color: magic ? white : du.accentText),
          if (r.levels.containsKey(Call.up)) (value: Call.up, icon: LucideIcons.plus, word: 'Harder', color: magic ? white : (v.moment == Moment.pushed ? p.pushInk : p.earnedInk).of(context)),
        ],
      )),
    ])));
  }

  /// The one frame every tile on the finish shares, so a level earned, a first time, an ordinary exercise and the early
  /// ending read as one family: the level-up sweep fills it, a first time draws its edge in the fresh colours over a
  /// faint wash, the rest are plain. It changes between them in one motion.
  Widget _frame(BuildContext context, _Kind kind, {required Widget child, VoidCallback? onTap, List<Color>? sweep}) {
    final du = context.du;
    final dur = m(context, const Duration(milliseconds: 380));
    const ease = Curves.easeOutCubic;
    final fresh = freshColorsOf(context);
    final magic = sweep ?? StatePalette.of(context).earned;
    final edge = switch (kind) { _Kind.magic || _Kind.edge => magic, _Kind.first => fresh, _Kind.plain => [du.line, du.line, du.line] };
    final fill = switch (kind) {
      _Kind.magic => du.surface.withValues(alpha: 0),
      _Kind.edge => Color.alphaBlend(magic[1].withValues(alpha: 0.04), du.surface),
      _Kind.first => Color.alphaBlend(fresh[1].withValues(alpha: 0.04), du.surface),
      _Kind.plain => du.surface,
    };
    final glow = switch (kind) {
      _Kind.magic => magic[1].withValues(alpha: 0.2),
      _Kind.edge => magic[1].withValues(alpha: 0.1),
      _Kind.first => fresh[1].withValues(alpha: 0.1),
      _Kind.plain => const Color(0x0F000000),
    };
    return Pressable(borderRadius: 14, onTap: onTap, child: AnimatedContainer(
      duration: dur,
      curve: ease,
      padding: EdgeInsets.all(switch (kind) { _Kind.magic => 0, _Kind.first || _Kind.edge => 1.4, _Kind.plain => 0.6 }),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(colors: edge, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: glow, blurRadius: kind == _Kind.plain ? 8 : 18, offset: const Offset(0, 2))],
      ),
      child: AnimatedContainer(
        duration: dur,
        curve: ease,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(13.4)),
        child: AnimatedSize(duration: dur, curve: ease, alignment: Alignment.topCenter, child: child),
      ),
    ));
  }

  /// A question inside a tile: a short line, then its choices, lined up under the tile's text.
  Widget _ask(BuildContext context, String question, Widget choices, {bool onMagic = false}) {
    final t = Theme.of(context).textTheme;
    return Padding(padding: const EdgeInsets.only(left: 52, top: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(question, style: t.labelMedium?.copyWith(color: onMagic ? const Color(0xFFFFFFFF).withValues(alpha: 0.88) : null)),
      const SizedBox(height: 6),
      choices,
    ]));
  }

  /// A row of equal segments, one picked: a word and, under it, what it means. The picked one fills in its own colour.
  /// [onMagic] draws them in white over the level-up sweep.
  Widget _segments(BuildContext context, List<(String, String?, bool, Color, VoidCallback)> options, {bool onMagic = false, Color? magicInk}) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    const white = Color(0xFFFFFFFF);
    final dur = m(context, durBase);
    return Row(children: [
      for (var k = 0; k < options.length; k++) ...[
        if (k > 0) const SizedBox(width: 6),
        Expanded(child: Builder(builder: (context) {
          final (word, sub, on, color, onTap) = options[k];
          final ink = onMagic ? (on ? magicInk ?? StatePalette.of(context).earned.first : white) : (on ? color : du.ink);
          return Pressable(borderRadius: 12, onTap: on ? () {} : onTap, child: AnimatedContainer(
            duration: dur,
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: sub == null ? 9 : 7),
            decoration: BoxDecoration(
              color: onMagic ? (on ? white : white.withValues(alpha: 0.16)) : (on ? color.withValues(alpha: 0.12) : du.bg),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: onMagic ? (on ? white : white.withValues(alpha: 0.4)) : (on ? color : du.line), width: on ? 1.5 : 0.6),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(word, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelLarge?.copyWith(color: ink, fontWeight: on ? FontWeight.w600 : null)),
              if (sub != null) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: t.labelSmall?.copyWith(color: onMagic ? ink.withValues(alpha: 0.85) : on ? color : du.inkSecondary)),
            ]),
          ));
        })),
      ],
    ]);
  }

  /// The user's take on a first-time exercise, which decides how often it comes up: a heart, a thumbs up, a thumbs
  /// down. The one picked opens into a pill with its word; picking another closes it and opens that one. Unrated reads
  /// as the thumbs up. Loving it or not wanting it says, in one line, what that does.
  Widget _rating(BuildContext context, ExerciseState st) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final store = context.store;
    final dur = m(context, const Duration(milliseconds: 300));
    const ease = Curves.easeOutCubic;
    const love = Color(0xFFE5484D);
    final effect = switch (st.preference) {
      prefLiked => 'It comes up first whenever it fits.',
      prefNo => 'It comes up only when nothing else fits.',
      _ => null,
    };
    return Padding(padding: const EdgeInsets.only(left: 52, top: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ChoicePills<String>(
        label: 'Your take',
        value: st.preference ?? prefFine,
        onPick: (v) { store.update((_) => st.preference = v); setState(() {}); },
        options: [
          (value: prefLiked, icon: LucideIcons.heart, word: 'Love it', color: love),
          (value: prefFine, icon: LucideIcons.thumbsUp, word: "It's fine", color: du.accentText),
          (value: prefNo, icon: LucideIcons.thumbsDown, word: 'Not for me', color: du.warning),
        ],
      ),
      AnimatedSize(duration: dur, curve: ease, alignment: Alignment.topLeft, child: effect == null
          ? const SizedBox(width: double.infinity)
          : Padding(padding: const EdgeInsets.only(top: 6), child: Text(effect, textAlign: TextAlign.right, style: t.bodySmall?.copyWith(color: du.inkSecondary)))),
    ]));
  }

  /// The two ways out that are not Done, kept quiet: something hurt, and back to the workout.
  Widget _quietLinks(BuildContext context, TextStyle dotted) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
      TextButton(onPressed: () => _toggle('pain'), style: TextButton.styleFrom(foregroundColor: du.inkSecondary),
          child: Text('Something hurt', style: t.bodySmall?.merge(dotted))),
      Text('·', style: t.bodySmall),
      TextButton(onPressed: widget.onReopen, style: TextButton.styleFrom(foregroundColor: du.inkSecondary),
          child: Text('Back to the workout', style: t.bodySmall?.merge(dotted))),
    ]);
  }

  /// When not every exercise in the plan got done: one tile asking what cut it short, on both pages, in the same frame
  /// as the exercises. No lines on what an answer changes: the app takes it from there quietly. The app's guess starts
  /// picked; a pick stays picked, and another changes it. Nothing at all when the whole plan was done.
  Widget _endCard(BuildContext context, Session x, WorkoutRead w) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final store = context.store;
    final chosen = endReadOf(x.endRead);
    final on = chosen ?? (w.guess == EndRead.time || w.guess == EndRead.energy ? w.guess : null);
    const options = [(EndRead.time, 'Out of time'), (EndRead.energy, 'Low energy'), (EndRead.none, 'No reason')];
    return _frame(context, _Kind.plain, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: du.inkSecondary.withValues(alpha: 0.13)),
            child: Icon(LucideIcons.flag, size: 18, color: du.inkSecondary)),
        const SizedBox(width: 12),
        Expanded(child: Text('You finished early', style: t.titleMedium)),
      ]),
      const SizedBox(height: 12),
      _segments(context, [
        for (final (value, label) in options) (label, null, value == on, du.accentText, () {
          HapticFeedback.selectionClick();
          store.update((_) => x.endRead = value.name);
          setState(() {});
        }),
      ]),
    ]));
  }

  // ---- the exercises, in three sections: to level up, first times, what you did ----

  /// The details: what was done, in the workout's order, with no words around it. A timed part (warm-up, cardio,
  /// stretching) is a line with its time; an exercise is a table, a line a set. A tap opens the edit drawer, on the set
  /// when a set was tapped. The ones never started are one small line at the end.
  List<Widget> _did(BuildContext context, Session x, WorkoutRead w) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final store = context.store;
    final s = store.state;
    final now = store.now;
    final eq = s.location(x.locationId)?.equipment ?? const <String>[];
    final notStarted = [for (final e in x.exercises) if (e.attempted.isEmpty) e.exercise.name];
    String time(int? v) => v == null ? '' : mmss(v.toDouble());
    String level(SessionExercise e, SetLog l) {
      final ex = e.exercise;
      return ex.loaded ? fmtLoad(s, ex, l.kg ?? e.loadKg ?? 0, equipment: eq) : rungLabel(s, ex, ensureState(s, ex), l.rung ?? e.rung, e.range, eq);
    }
    Widget cell(String text, {int flex = 1, TextAlign align = TextAlign.left, TextStyle? style}) =>
        Expanded(flex: flex, child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: align, style: style ?? t.bodyMedium));
    final quiet = t.bodyMedium?.copyWith(color: du.inkSecondary);

    // a timed part: its name and how long it took
    Widget timed(WorkoutItem it, String name, IconData icon) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Panel(padding: EdgeInsets.zero, child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => showItemEdit(context, x, it, name),
      child: Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 14), child: Row(children: [
        Icon(icon, size: 18, color: du.inkSecondary),
        const SizedBox(width: 10),
        Expanded(child: Text(name, style: t.titleMedium)),
        Text(time(itemSecondsOf(x, it, now)), style: t.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        const SizedBox(width: 4),
        Icon(LucideIcons.chevronRight, size: 16, color: du.inkTertiary),
      ])),
    )));

    // an exercise: a line a set
    Widget table(int i) {
      final e = x.exercises[i];
      final ex = e.exercise;
      final r = w.exercises[i];
      final sets = [for (var k = 0; k < e.sets.length; k++) if (e.sets[k].attempted) k];
      final showLevel = ex.loaded || {for (final k in sets) e.sets[k].rung ?? e.rung}.length > 1;
      return Padding(padding: const EdgeInsets.only(bottom: 10), child: Panel(padding: const EdgeInsets.fromLTRB(14, 10, 14, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(onTap: () => showExerciseEdit(context, x, i), borderRadius: BorderRadius.circular(10), child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
          Expanded(child: Text(_title(x, r), style: t.titleMedium)),
          Icon(LucideIcons.chevronRight, size: 16, color: du.inkTertiary),
        ]))),
        const SizedBox(height: 6),
        Row(children: [
          cell('Set', style: t.labelSmall),
          cell(ex.repLabel == 'seconds' ? 'Secs' : 'Reps', align: TextAlign.right, style: t.labelSmall),
          if (showLevel) cell(ex.loaded ? 'Weight' : 'Version', flex: 3, align: TextAlign.right, style: t.labelSmall),
          cell('Took', flex: 2, align: TextAlign.right, style: t.labelSmall),
          cell('Rest', flex: 2, align: TextAlign.right, style: t.labelSmall),
        ]),
        for (final k in sets) InkWell(onTap: () => showExerciseEdit(context, x, i, focus: k), child: Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [
          cell('${k + 1}', style: quiet),
          cell('${e.sets[k].reps}', align: TextAlign.right, style: t.titleMedium),
          if (showLevel) cell(level(e, e.sets[k]), flex: 3, align: TextAlign.right),
          cell(time(setSecondsOf(x, (ex: i, set: k))), flex: 2, align: TextAlign.right, style: quiet),
          cell(time(restAfterOf(x, (ex: i, set: k))), flex: 2, align: TextAlign.right, style: quiet),
        ]))),
      ])));
    }

    return [
      for (final it in workoutItems(x))
        if (!it.lifting) ...[
          if (x.itemStarts[it.key] != null && (itemSecondsOf(x, it, now) ?? 0) >= 30) timed(it, switch (it.kind) { ItemKind.warmup => 'Warm-up', ItemKind.cardio => 'Cardio', _ => 'Stretching' },
              switch (it.kind) { ItemKind.warmup => LucideIcons.flame, ItemKind.cardio => LucideIcons.heartPulse, _ => LucideIcons.stretchHorizontal }),
        ] else
          for (final i in it.exercises) if (x.exercises[i].attempted.isNotEmpty) table(i),
      if (notStarted.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 0), child: Text('Not started: ${notStarted.join(', ')}', style: t.bodySmall)),
    ];
  }

  /// The exercise's name: a bodyweight one by the version done.
  String _title(Session x, ExerciseRead r) {
    final s = context.store.state;
    final e = x.exercises[r.index];
    final ex = e.exercise;
    if (ex.ladder == null) return ex.name;
    final rungs = {for (final l in e.attempted) l.rung ?? e.rung};
    return rungs.length == 1 ? rungLabel(s, ex, ensureState(s, ex), rungs.first, e.range, s.location(x.locationId)?.equipment ?? const []) : e.rungLabel;
  }

  /// Something hurt: which exercise, then what that does, with a way back.
  Widget _pain(BuildContext context, Session x) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final store = context.store;
    final days = store.state.settings.painRestDays;
    final hurt = x.painAt;
    final done = [for (var i = 0; i < x.exercises.length; i++) if (x.exercises[i].attempted.isNotEmpty) i];
    String name(int i) => x.exercises[i].exercise.ladder != null ? x.exercises[i].rungLabel : x.exercises[i].exercise.name;
    return Container(
      key: _painKey,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: du.warningSubtle, borderRadius: BorderRadius.circular(14), border: Border.all(color: du.warningLine, width: 0.6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(hurt == null ? 'What hurt?' : 'Something hurt during ${name(hurt)}', style: t.titleMedium),
        if (hurt == null) ...[
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final i in done) _chip(context, name(i), () => store.update((_) => x.painAt = i)),
            _chip(context, 'Never mind', () => setState(() => _open.remove('pain'))),
          ]).withTop(8),
          Text('Pick the exercise. It and the muscles it works get $days days off, and today doesn\'t count against it.', style: t.bodySmall?.copyWith(color: du.ink)).withTop(8),
        ] else ...[
          Text('It and the muscles it works get $days days off. When it comes back, it starts one step easier. Today doesn\'t count against it.', style: t.bodySmall?.copyWith(color: du.ink)).withTop(6),
          Align(alignment: Alignment.centerLeft, child: _chip(context, 'Undo', () { store.update((_) => x.painAt = null); setState(() => _open.remove('pain')); })).withTop(8),
        ],
      ]),
    );
  }

  Widget _chip(BuildContext context, String text, VoidCallback onTap) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Pressable(borderRadius: 999, onTap: () { HapticFeedback.selectionClick(); onTap(); setState(() {}); }, child: Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(color: du.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: du.line, width: 0.6)),
      child: Text(text, style: t.labelLarge),
    ));
  }
}

extension on Widget {
  Widget withTop(double h) => Padding(padding: EdgeInsets.only(top: h), child: this);
}


/// Levels on a sideways wheel, for next time after a first go: the one in the window large in [color], a tap on another
/// turns to it.
class _LevelStrip extends StatefulWidget {
  const _LevelStrip({required this.values, required this.initial, required this.color, required this.onChanged});
  final List<(int, String)> values;
  final int initial; // a rung
  final Color color;
  final ValueChanged<int> onChanged;
  @override
  State<_LevelStrip> createState() => _LevelStripState();
}

class _LevelStripState extends State<_LevelStrip> {
  late final int _start = max(0, widget.values.indexWhere((v) => v.$1 == widget.initial));
  late final FixedExtentScrollController _ctl = FixedExtentScrollController(initialItem: _start);
  late int _sel = _start;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    // a weight is short, a version a few words
    final long = widget.values.any((v) => v.$2.length > 12);
    final extent = long ? 118.0 : 84.0;
    return SizedBox(height: 58, child: Stack(alignment: Alignment.center, children: [
      Container(width: extent, height: 58, decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: widget.color, width: 1.5))),
      ShaderMask(
        shaderCallback: (r) => const LinearGradient(colors: [Color(0x00000000), Color(0xFF000000), Color(0xFF000000), Color(0x00000000)], stops: [0, 0.2, 0.8, 1]).createShader(r),
        blendMode: BlendMode.dstIn,
        child: RotatedBox(quarterTurns: 3, child: ListWheelScrollView.useDelegate(
          controller: _ctl,
          itemExtent: extent,
          diameterRatio: 3,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (i) { HapticFeedback.selectionClick(); setState(() => _sel = i); widget.onChanged(widget.values[i].$1); },
          childDelegate: ListWheelChildBuilderDelegate(childCount: widget.values.length, builder: (context, i) {
            final on = i == _sel;
            return RotatedBox(quarterTurns: 1, child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _ctl.animateToItem(i, duration: m(context, durSlow), curve: easeOut),
              child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: AnimatedDefaultTextStyle(
                duration: m(context, durFast),
                style: (on ? t.titleMedium! : t.bodyMedium!).copyWith(color: on ? widget.color : du.inkSecondary,
                    fontWeight: on ? FontWeight.w600 : null, fontFeatures: const [FontFeature.tabularFigures()]),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                child: Text(widget.values[i].$2),
              ))),
            ));
          }),
        )),
      ),
    ]));
  }
}

/// A step up on the finish is an event, a step down a quiet one (the Playground's tile lab, 2026-11-04). When next time
/// goes up, the tile's edge sweeps round once in the win's colours, a wash of them swells and fades, the tile pops a
/// little, sparks burst from the mark, with a firm haptic and a second tick as it lands; a step up the app earned
/// arrives the same way, without the haptics. Going down, a short mist wash and a light tick. Still when the system asks
/// for less motion.
class _StepUp extends StatefulWidget {
  const _StepUp({required this.up, required this.down, required this.colors, required this.calm, required this.child});
  final bool up, down;
  final List<Color> colors;
  final Color calm;
  final Widget child;
  @override
  State<_StepUp> createState() => _StepUpState();
}

class _StepUpState extends State<_StepUp> with TickerProviderStateMixin {
  late final AnimationController burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  late final AnimationController settle = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  bool get _still => MediaQuery.of(context).disableAnimations;

  @override
  void initState() {
    super.initState();
    if (widget.up) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted && !_still) burst.forward(from: 0); });
  }

  @override
  void didUpdateWidget(_StepUp old) {
    super.didUpdateWidget(old);
    if (widget.up && !old.up) {
      HapticFeedback.heavyImpact();
      Future<void>.delayed(const Duration(milliseconds: 420), () { if (mounted) HapticFeedback.lightImpact(); });
      if (!_still) burst.forward(from: 0);
    } else if (widget.down && !old.down) {
      HapticFeedback.lightImpact();
      if (!_still) settle.forward(from: 0);
    }
  }

  @override
  void dispose() {
    burst.dispose();
    settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([burst, settle]),
        child: widget.child,
        builder: (context, child) {
          final spin = burst.isAnimating ? burst.value : 0.0;
          final swell = sin(pi * spin);
          final calm = settle.isAnimating ? sin(pi * settle.value) : 0.0;
          return Transform.scale(scale: 1 + 0.025 * swell, child: Stack(clipBehavior: Clip.none, children: [
            child!,
            if (spin > 0 || calm > 0) Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _StepPainter(spin, swell, calm, widget.colors, widget.calm)))),
            // the sparks, from the mark at the tile's top left
            if (spin > 0) Positioned(left: -25, top: -25, width: 120, height: 120, child: IgnorePointer(child: CustomPaint(painter: _StepSparks(spin, widget.colors)))),
          ]));
        },
      );
}

/// The ceremony over the tile: a wash of the win's colours and the edge sweeping round; going down, a mist wash.
class _StepPainter extends CustomPainter {
  _StepPainter(this.spin, this.swell, this.calm, this.colors, this.mist);
  final double spin, swell, calm;
  final List<Color> colors;
  final Color mist;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    if (swell > 0) {
      canvas.drawRRect(rr, Paint()..color = colors[colors.length ~/ 2].withValues(alpha: 0.13 * swell));
      canvas.drawRRect(rr.deflate(0.8), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 + 1.6 * swell
        ..shader = SweepGradient(colors: [...colors, colors.first], transform: GradientRotation(2 * pi * Curves.easeOutCubic.transform(spin))).createShader(rect));
    }
    if (calm > 0) canvas.drawRRect(rr, Paint()..color = mist.withValues(alpha: 0.12 * calm));
  }

  @override
  bool shouldRepaint(_StepPainter old) => old.spin != spin || old.calm != calm;
}

/// Sparks thrown from the mark: twelve, out and fading, in the win's colours.
class _StepSparks extends CustomPainter {
  _StepSparks(this.t, this.colors);
  final double t;
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final c = size.center(Offset.zero);
    final e = Curves.easeOutCubic.transform(t);
    for (var k = 0; k < 12; k++) {
      final a = k * pi / 6 + (k.isEven ? 0.15 : -0.1);
      final r = 18 + (k.isEven ? 34 : 24) * e;
      canvas.drawCircle(c + Offset(cos(a), sin(a)) * r, (k.isEven ? 3.6 : 2.6) * (1 - t) + 0.6, Paint()..color = colors[k % colors.length].withValues(alpha: 1 - t * t));
    }
  }

  @override
  bool shouldRepaint(_StepSparks old) => old.t != t;
}

/// What a tile on the finish is: a win filled with its sweep, a win with its edge, a first time, or the rest.
enum _Kind { plain, first, edge, magic }

/// Text or an icon painted in the first-time colours.
class _FreshText extends StatelessWidget {
  const _FreshText({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (b) => LinearGradient(colors: freshColorsOf(context)).createShader(b),
        child: child,
      );
}

/// The mark of a first time: a compass in the fresh colours that swings round once and settles, like finding a bearing.
/// Still when the system asks for less motion.
class _FirstMark extends StatelessWidget {
  const _FirstMark({super.key});
  @override
  Widget build(BuildContext context) {
    final c = freshColorsOf(context);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(
          colors: [for (final k in c) k.withValues(alpha: 0.16)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: -0.6, end: 0),
        duration: m(context, const Duration(milliseconds: 1400)),
        curve: Curves.elasticOut,
        builder: (context, v, child) => Transform.rotate(angle: v * pi, child: child),
        child: const _FreshText(child: Icon(LucideIcons.compass, size: 20)),
      ),
    );
  }
}

/// A star that twinkles on a level earned: a white sparkle in a soft disc, breathing slowly. Still when the system
/// asks for less motion.
class _Twinkle extends StatefulWidget {
  const _Twinkle({super.key, this.icon = LucideIcons.sparkles});
  final IconData icon;
  @override
  State<_Twinkle> createState() => _TwinkleState();
}

class _TwinkleState extends State<_Twinkle> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) { _c.stop(); } else if (!_c.isAnimating) { _c.repeat(reverse: true); }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c, builder: (context, _) {
        final v = Curves.easeInOut.transform(_c.value);
        return Container(
          width: 40, height: 40,
          decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFFFFFF).withValues(alpha: 0.18 + 0.10 * v)),
          child: Transform.rotate(angle: 0.25 * v, child: Transform.scale(scale: 0.9 + 0.2 * v,
              child: Icon(widget.icon, size: 22, color: const Color(0xFFFFFFFF)))),
        );
      });
}

/// The badge at the top of the finish: a check in a ring that draws itself, in the accent, or in the level-up sweep
/// when a level was earned.
class _Badge extends StatefulWidget {
  const _Badge({required this.tone});
  final Tone tone;
  bool get magic => tone == Tone.celebrate;
  @override
  State<_Badge> createState() => _BadgeState();
}

class _BadgeState extends State<_Badge> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) { _c.value = 1; } else if (_c.value == 0 && !_c.isAnimating) { HapticFeedback.mediumImpact(); _c.forward(); }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final du = context.du;
    // celebrate in the level-up sweep; proud and encourage in a warm amber; the calm ones in the accent
    final warm = widget.tone == Tone.proud || widget.tone == Tone.encourage;
    final p = StatePalette.of(context);
    final colors = widget.magic ? p.earned : widget.tone == Tone.curious ? p.fresh
        : widget.tone == Tone.proud ? [p.pushInk.of(context), p.pushInk.of(context)]
        : warm ? [p.gentleInk.of(context), p.gentleInk.of(context)] : [du.accentStrong, du.accentStrong];
    final icon = switch (widget.tone) {
      Tone.celebrate => LucideIcons.sparkles,
      Tone.pleased => LucideIcons.trendingUp,
      Tone.proud => LucideIcons.heart,
      Tone.encourage => LucideIcons.sprout,
      Tone.brief => LucideIcons.timer,
      Tone.curious => LucideIcons.compass,
      Tone.steady => LucideIcons.check,
    };
    return AnimatedBuilder(animation: _c, builder: (context, _) {
      final ring = Curves.easeOutCubic.transform((_c.value / 0.7).clamp(0.0, 1.0));
      final pop = Curves.elasticOut.transform(((_c.value - 0.35) / 0.65).clamp(0.0, 1.0));
      return SizedBox(width: 108, height: 108, child: Stack(alignment: Alignment.center, children: [
        Container(width: 108, height: 108, decoration: BoxDecoration(shape: BoxShape.circle, color: colors[widget.magic ? 1 : 0].withValues(alpha: 0.10 * ring))),
        CustomPaint(size: const Size(96, 96), painter: _RingPainter(ring, colors)),
        Transform.scale(scale: pop, child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (b) => LinearGradient(colors: colors).createShader(b),
          child: Icon(icon, size: 44),
        )),
      ]));
    });
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.t, this.colors);
  final double t;
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(colors: [...colors, colors.first], transform: const GradientRotation(-pi / 2)).createShader(rect);
    canvas.drawArc(rect.deflate(3), -pi / 2, 2 * pi * t, false, p);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t;
}

/// A burst of confetti from the top of the screen, once, in the level-up colours. Nothing when the system asks for
/// less motion.
class _Confetti extends StatefulWidget {
  const _Confetti();
  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  final _bits = <({double x, double vx, double vy, double spin, double size, Color color, bool round})>[];

  void _make(List<Color> colors) {
    _bits.clear();
    final r = Random(7);
    for (var i = 0; i < 70; i++) {
      _bits.add((x: 0.5 + (r.nextDouble() - 0.5) * 0.3, vx: (r.nextDouble() - 0.5) * 1.6, vy: -0.6 - r.nextDouble() * 0.9,
          spin: (r.nextDouble() - 0.5) * 18, size: 5 + r.nextDouble() * 5, color: colors[i % colors.length], round: r.nextBool()));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _make(StatePalette.of(context).confetti);
    if (!MediaQuery.of(context).disableAnimations && _c.value == 0 && !_c.isAnimating) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c, builder: (context, _) =>
      _c.value == 0 || _c.isCompleted ? const SizedBox.shrink() : CustomPaint(painter: _ConfettiPainter(_c.value, _bits)));
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.bits);
  final double t;
  final List<({double x, double vx, double vy, double spin, double size, Color color, bool round})> bits;
  @override
  void paint(Canvas canvas, Size size) {
    final secs = t * 2.6;
    final fade = t < 0.75 ? 1.0 : (1 - (t - 0.75) / 0.25);
    for (final b in bits) {
      // thrown up from the badge, then falling with a little drag
      final x = (b.x + b.vx * secs * 0.35) * size.width;
      final y = size.height * 0.14 + (b.vy * secs + 0.9 * secs * secs) * size.height * 0.28;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(b.spin * secs);
      final p = Paint()..color = b.color.withValues(alpha: fade);
      if (b.round) {
        canvas.drawCircle(Offset.zero, b.size / 2, p);
      } else {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: b.size, height: b.size * 0.45), const Radius.circular(1)), p);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
