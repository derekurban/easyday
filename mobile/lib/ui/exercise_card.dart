// Exercise card: level, average time per set, best total, cost with override, the progression, and how to do it at this level.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/index.dart';
import '../data/library.dart';
import '../data/model.dart';
import '../logic/ladder.dart';
import '../logic/selection.dart';
import 'app.dart';
import 'how.dart';
import 'theme.dart';
import 'widgets.dart';

class ExerciseCardScreen extends StatelessWidget {
  const ExerciseCardScreen(this.exId, {super.key});
  final String exId;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final s = store.state;
    final ex = exerciseById[exId];
    if (ex == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('This exercise no longer exists.')));
    final st = ensureState(s, ex);
    final loc = s.location(s.lastLocationId);
    final equipmentHere = loc?.equipment ?? const <String>[];
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final difficulty = difficultyInPlay(ex, st);
    final range = todayRange(s, ex);
    final ladder = ladderView(s, ex, equipmentHere);
    final here = available(ex, equipmentHere);
    final base = st.costOverride ?? ex.difficulty;
    final works = muscleGroupsOf(ex);
    final ix = s.settings.index;

    return Scaffold(
      appBar: AppBar(title: Text(ex.name)),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [
        Row(children: [
          IconBadge(exerciseIcon(ex), accent: true),
          const SizedBox(width: 10),
          Expanded(child: Text('Works ${works.join(', ').toLowerCase()}${ix == ExerciseIndex.muscle ? '' : ' · ${indexLabel[ix]!.toLowerCase()}: ${indexGroup(ex, ix).toLowerCase()}'}', style: t.bodySmall)),
        ]),
        if (!here) Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [
          Icon(LucideIcons.circleOff, size: 14, color: du.accentText), const SizedBox(width: 6),
          Expanded(child: Text('Not available at ${loc?.name ?? 'this location'}.', style: t.bodySmall?.copyWith(color: du.accentText))),
        ])),
        const SizedBox(height: 16),
        Panel(child: Column(children: [
          Row(children: [
            Expanded(child: StatTile(label: 'Level', value: rungLabel(s, ex, st, st.rung), hint: ex.loaded ? 'for ${range.lo} to ${range.hi} · max about ${fmtKg(s, maxFor(s, ex, st, st.rung))}' : null, icon: LucideIcons.circleDot)),
            Expanded(child: StatTile(label: 'Per set', value: mmss(st.secPerSet), hint: st.appearances == 0 ? 'estimate until you log it' : 'learned from your taps', icon: LucideIcons.timer)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: StatTile(label: 'Best total', value: st.bestTotal == 0 ? '—' : '${st.bestTotal} ${ex.repLabel}', hint: 'at this level', icon: LucideIcons.trophy)),
            Expanded(child: StatTile(label: 'Workouts', value: '${st.appearances}', icon: LucideIcons.history)),
          ]),
        ])),
        const SizedBox(height: 20),
        const SectionHeader('How, at your level', icon: LucideIcons.bookOpen),
        Panel(sunk: true, child: Text(howAt(ex, st.rung), style: t.bodyLarge)),
        const SizedBox(height: 20),
        const SectionHeader('Progression', icon: LucideIcons.listOrdered),
        const Explain(progressionExplainer),
        Panel(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
          child: LadderTrack(rungs: ladder, onUse: (r) => store.update((x) => setRung(x, ex, r))),
        ),
        Padding(padding: const EdgeInsets.only(top: 8), child: Text(
          ex.ladder != null && ceilingFor(ex, equipmentHere) != null
              ? 'No loading gear here, so ${ex.ladder!.variants.last.name.toLowerCase()} is the top. There, the target becomes beating your best total. Tap a level to make it yours.'
              : ex.loaded ? 'Each level is about ${fmtKg(s, stepKg(s, ex))} more at these reps. Heavier and fewer or lighter and more is the same level; the weight follows the reps. Tap a level to make it yours.' : 'Tap a level to make it yours.',
          style: t.bodySmall,
        )),
        const SizedBox(height: 20),
        const SectionHeader('Reps', icon: LucideIcons.repeat),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ChoiceRow<String>(
            label: 'This exercise trains at',
            value: st.repsOverride == null ? 'goal' : (Expression.values.where((e) => expressionRange[e] == st.repsOverride).map((e) => e.name).firstOrNull ?? 'custom'),
            options: {'goal': 'Goal', for (final e in Expression.values) e.name: '${expressionLabel[e]} (${rangeText(expressionRange[e]!)})', if (st.repsOverride != null && !expressionRange.values.contains(st.repsOverride)) 'custom': rangeText(st.repsOverride!)},
            hint: '${range.lo} to ${range.hi} ${ex.repLabel} now. ${st.repsOverride == null ? 'Following the goal: its band for ${difficultyLabel[ex.difficulty]} exercises.' : 'Set here for this exercise.'} Same strength either way; the weight follows the reps.',
            onChanged: (v) => store.update((_) => st.repsOverride = v == 'goal' ? null : v == 'custom' ? st.repsOverride : expressionRange[Expression.values.byName(v)]),
          ),
        ])),
        const SizedBox(height: 20),
        const SectionHeader('Difficulty', icon: LucideIcons.flame),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [DifficultyTag(difficulty, large: true), const SizedBox(width: 10), Expanded(child: Text('one hard set takes ${difficulty == 3 ? 'a lot' : difficulty == 2 ? 'some' : 'a little'} out of the whole body', style: t.bodySmall))]),
              const SizedBox(height: 4),
              Text(_costLine(ex, st), style: t.bodySmall),
            ])),
            IconButton.outlined(onPressed: base > 1 ? () => store.update((_) => st.costOverride = base - 1) : null, icon: const Icon(LucideIcons.minus), tooltip: 'Easier'),
            const SizedBox(width: 4),
            IconButton.outlined(onPressed: base < 3 ? () => store.update((_) => st.costOverride = base + 1) : null, icon: const Icon(LucideIcons.plus), tooltip: 'Harder'),
          ]),
          const SizedBox(height: 6),
          Text('How much one hard set takes out of the whole body. Hard exercises get the reps you like; easier ones get more reps and less weight. A hard day pushes the hardest ones first.', style: t.bodySmall),
          if (st.costOverride != null) TextButton.icon(onPressed: () => store.update((_) => st.costOverride = null), icon: const Icon(LucideIcons.rotateCcw, size: 16), label: const Text('Back to the default')),
        ])),
        const SizedBox(height: 20),
        const SectionHeader('Your word', icon: LucideIcons.heart),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ChoiceRow<String>(
            label: 'This exercise is',
            value: st.preference ?? 'unrated',
            options: {'unrated': 'Unrated', prefLiked: preferenceLabel[prefLiked]!, prefFine: preferenceLabel[prefFine]!, prefNo: preferenceLabel[prefNo]!},
            hint: 'Liked goes first for its muscle; fine and unrated take their turn; not for me fills a place only when nothing else here is ready, and the plan says so. Never changes a level.'
                '${st.swappedOut > 0 ? ' Swapped out ${st.swappedOut} time${st.swappedOut == 1 ? '' : 's'} in a row.' : ''}'
                '${st.preference == null && st.likedUntil != null && store.now.isBefore(st.likedUntil!) ? ' Counts as liked for now: you picked it by hand.' : ''}',
            onChanged: (v) => store.update((_) { st.preference = v == 'unrated' ? null : v; st.swappedOut = 0; }),
          ),
        ])),
      ]),
    );
  }

  String _costLine(Exercise ex, st) {
    final parts = <String>[];
    parts.add(st.costOverride == null ? 'library default' : 'your override');
    if (st.costUp > 0) parts.add('+1 while unpractised');
    if (st.costDown > 0) parts.add('−${st.costDown} from clearing the top');
    return parts.join(' · ');
  }
}
