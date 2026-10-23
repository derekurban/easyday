// What an exercise works: the body figure with its primary muscles in the forced green and its secondary ones at the
// secondary strength (the muscle picker's colours), and beside it the two lists by name. Used on the exercise card and
// on Today's exercise sheet. An exercise tagged with no muscles (most cardio) shows nothing.
import 'package:flutter/material.dart';

import '../data/index.dart';
import '../data/library.dart';
import '../logic/selection.dart';
import 'muscle_figure.dart';
import 'muscle_picker.dart';
import 'theme.dart';

/// An exercise's secondary muscles without the ones it already counts as primary.
List<String> secondaryOnly(Exercise ex) => [for (final m in ex.secondary) if (!ex.primary.contains(m)) m];

/// The figure's fills for [ex]: primary in [musclePrimary], secondary at [muscleSecondaryAlpha].
Map<String, Color> exerciseMuscleFills(Exercise ex) => {
      for (final m in secondaryOnly(ex)) m: musclePrimary.withValues(alpha: muscleSecondaryAlpha),
      for (final m in ex.primary) m: musclePrimary,
    };

class ExerciseMuscles extends StatelessWidget {
  const ExerciseMuscles(this.ex, {super.key, this.height = 150});
  final Exercise ex;
  final double height;

  @override
  Widget build(BuildContext context) {
    final secondary = secondaryOnly(ex);
    return Row(children: [
      MuscleFigure(
        highlight: const {}, tint: exerciseMuscleFills(ex), height: height,
        detail: (h) => ex.primary.contains(h.name) ? 'primary' : secondary.contains(h.name) ? 'secondary' : 'not worked',
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (ex.primary.isNotEmpty) _list(context, Color.lerp(musclePlate, musclePrimary, 0.8)!, 'Primary', ex.primary),
        if (ex.primary.isNotEmpty && secondary.isNotEmpty) const SizedBox(height: 12),
        if (secondary.isNotEmpty) _list(context, Color.lerp(musclePlate, musclePrimary, muscleSecondaryAlpha)!, 'Secondary', secondary),
      ])),
    ]);
  }

  Widget _list(BuildContext context, Color swatch, String label, List<String> muscles) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: swatch, shape: BoxShape.circle, border: Border.all(color: du.line, width: 0.6))),
        const SizedBox(width: 6),
        Text(label, style: t.labelMedium?.copyWith(color: du.inkSecondary)),
      ]),
      const SizedBox(height: 2),
      Text(muscleTitle(listWords(muscles)), style: t.bodyMedium?.copyWith(color: du.ink)),
    ]);
  }
}
