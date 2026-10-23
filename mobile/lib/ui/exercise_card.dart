// Exercise card (UI.md): the name, what it works and its difficulty, the stage picture, the muscles it works on the
// figure (primary and secondary), the level as facts, how to do it as steps, the progression as a track, the reps it trains at, the difficulty with its override, and your word.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/index.dart';
import '../data/library.dart';
import '../data/model.dart';
import '../logic/ladder.dart';
import '../logic/selection.dart';
import 'app.dart';
import 'exercise_muscles.dart';
import 'stage_art.dart';
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
    final practised = st.appearances > 0;

    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
        Text(ex.name, style: t.headlineLarge),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: FactLine('Works ${works.join(', ').toLowerCase()}', icon: exerciseIcon(ex))),
          const SizedBox(width: 12),
          DifficultyTag(difficulty, large: true),
        ]),
        if (!ex.isStrength || ix != ExerciseIndex.muscle) Padding(padding: const EdgeInsets.only(top: 6), child: QuietLine(
          [if (!ex.isStrength) typeLabel[ex.type]!, if (ix != ExerciseIndex.muscle) '${indexLabel[ix]!}: ${indexGroup(ex, ix).toLowerCase()}'].join(' · '), icon: LucideIcons.layers)),
        if (!here) Padding(padding: const EdgeInsets.only(top: 6), child: QuietLine('Not available at ${loc?.name ?? 'this location'}.', icon: LucideIcons.circleOff, accent: true)),
        const SizedBox(height: 16),
        StageArt(stage: stageOf(ex.type)),
        const SizedBox(height: 24),
        if (ex.primary.isNotEmpty || ex.secondary.isNotEmpty) ...[
          const SectionHeader('Muscles', icon: LucideIcons.personStanding),
          Panel(child: ExerciseMuscles(ex)),
          const SizedBox(height: 24),
        ],
        const SectionHeader('Level', icon: LucideIcons.circleDot),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Expanded(child: Text(rungLabel(s, ex, st, st.rung), style: t.titleLarge?.copyWith(color: du.accentText))),
            if (ex.loaded) Text('for ${range.lo} to ${range.hi}', style: t.bodySmall),
          ]),
          const SizedBox(height: 8),
          Facts([
            Fact(practised ? 'About ${mmss(st.secPerSet)} a set' : 'About ${mmss(st.secPerSet)} a set, estimated', icon: LucideIcons.timer),
            Fact(st.bestTotal == 0 ? 'No best total yet' : 'Best ${st.bestTotal} ${ex.repLabel} at this level', icon: LucideIcons.trophy),
            Fact('${st.appearances} workout${st.appearances == 1 ? '' : 's'}', icon: LucideIcons.history),
            if (ex.loaded && !ex.assist) Fact('Max about ${fmtLoad(s, ex, maxFor(s, ex, st, st.rung))}', icon: LucideIcons.scale),
          ]),
        ])),
        const SizedBox(height: 24),
        HowToSteps(howAt(ex, st.rung)),
        const SizedBox(height: 12),
        const SectionHeader('Progression', icon: LucideIcons.listOrdered),
        Panel(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
          child: LadderTrack(rungs: ladder, onUse: (r) => store.update((x) => setRung(x, ex, r))),
        ),
        const SizedBox(height: 8),
        QuietLine(
          ex.ladder != null && ceilingFor(ex, equipmentHere) != null
              ? 'No loading gear here, so ${ex.ladder!.variants.last.name.toLowerCase()} is the top: there the target is beating your best total. Tap a level to make it yours.'
              : ex.loaded ? 'A level is ${ex.assist ? fmtLevelStep(s, ex) : '${fmtLevelStep(s, ex)} more'}. Tap one to make it yours.' : 'Tap a level to make it yours.',
          icon: LucideIcons.info,
        ),
        const SizedBox(height: 24),
        const SectionHeader('Reps', icon: LucideIcons.repeat),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ChoiceRow<String>(
            value: st.repsOverride == null ? 'goal' : (Expression.values.where((e) => expressionRange[e] == st.repsOverride).map((e) => e.name).firstOrNull ?? 'custom'),
            options: {
              'goal': 'Goal',
              for (final e in Expression.values) e.name: rangeText(expressionRange[e]!),
              if (st.repsOverride != null && !expressionRange.values.contains(st.repsOverride)) 'custom': rangeText(st.repsOverride!),
            },
            onChanged: (v) => store.update((_) => st.repsOverride = v == 'goal' ? null : v == 'custom' ? st.repsOverride : expressionRange[Expression.values.byName(v)]),
          ),
          QuietLine('${range.lo} to ${range.hi} ${ex.repLabel} now${st.repsOverride == null ? ', the goal\'s range for ${difficultyLabel[ex.difficulty]} exercises' : ', set here'}. The weight follows the reps.', icon: LucideIcons.info),
        ])),
        const SizedBox(height: 24),
        const SectionHeader('Difficulty', icon: LucideIcons.flame),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            DifficultyTag(difficulty, large: true),
            const SizedBox(width: 10),
            Expanded(child: Text('Takes ${difficulty == 3 ? 'a lot' : difficulty == 2 ? 'some' : 'a little'} out of the whole body', style: t.bodySmall)),
            IconButton.outlined(onPressed: base > 1 ? () => store.update((_) => st.costOverride = base - 1) : null, icon: const Icon(LucideIcons.minus), tooltip: 'Easier'),
            const SizedBox(width: 4),
            IconButton.outlined(onPressed: base < 3 ? () => store.update((_) => st.costOverride = base + 1) : null, icon: const Icon(LucideIcons.plus), tooltip: 'Harder'),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: QuietLine(_costLine(ex, st), icon: LucideIcons.info)),
            if (st.costOverride != null) TextButton.icon(onPressed: () => store.update((_) => st.costOverride = null), style: TextButton.styleFrom(visualDensity: VisualDensity.compact), icon: const Icon(LucideIcons.rotateCcw, size: 14), label: const Text('Default')),
          ]),
        ])),
        const SizedBox(height: 24),
        const SectionHeader('Your word', icon: LucideIcons.heart),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ChoiceRow<String>(
            value: st.preference ?? 'unrated',
            options: {'unrated': 'Unrated', prefLiked: preferenceLabel[prefLiked]!, prefFine: preferenceLabel[prefFine]!, prefNo: preferenceLabel[prefNo]!},
            icons: const {prefLiked: LucideIcons.heart, prefFine: LucideIcons.check, prefNo: LucideIcons.thumbsDown},
            onChanged: (v) => store.update((_) { st.preference = v == 'unrated' ? null : v; st.swappedOut = 0; }),
          ),
          QuietLine(
            st.swappedOut > 0
                ? 'Swapped out ${st.swappedOut} time${st.swappedOut == 1 ? '' : 's'} in a row.'
                : st.preference == null && st.likedUntil != null && store.now.isBefore(st.likedUntil!)
                    ? 'Counts as liked for now: you picked it by hand.'
                    : 'Liked goes first for its muscle. Not for me is picked only when nothing else fits.',
            icon: LucideIcons.info,
          ),
        ])),
      ]),
    );
  }

  String _costLine(Exercise ex, st) {
    final parts = <String>[];
    parts.add(st.costOverride == null ? 'Library default' : 'Your override');
    if (st.costUp > 0) parts.add('+1 while unpractised');
    if (st.costDown > 0) parts.add('−${st.costDown} from clearing the top');
    return parts.join(' · ');
  }
}
