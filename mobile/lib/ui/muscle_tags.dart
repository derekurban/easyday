// The muscles the user cares about (SELECTION.md, "What the user says"): a row per muscle with its tag (active, passive,
// ignored), how often for the active ones, and what the forecast says the rules will do for it; a sheet per muscle to
// change both; and the figure painted by tag. Used on Settings → Goal and on Progress.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/index.dart';
import '../data/model.dart';
import '../logic/forecast.dart';
import '../logic/selection.dart';
import 'app.dart';
import 'motion.dart';
import 'muscle_figure.dart';
import 'muscle_picker.dart';
import 'theme.dart';

IconData muscleTagIcon(MuscleTag t) => switch (t) { MuscleTag.active => LucideIcons.pin, MuscleTag.passive => LucideIcons.circleDashed, MuscleTag.ignored => LucideIcons.ban };

/// The figure's fills by tag: active in the primary green, passive at the secondary strength, ignored dark.
Map<String, Color> tagFills(GoalConfig g) => {
      for (final m in trackedMuscles)
        if (g.tagOf(m) == MuscleTag.active) m: musclePrimary
        else if (g.tagOf(m) == MuscleTag.passive) m: musclePrimary.withValues(alpha: muscleSecondaryAlpha)
        else m: muscleExcluded,
    };

/// The forecast off the main thread: the state as JSON, with [goal] in place of its own, run in an isolate.
Future<Forecast> forecastAsync(AppState s, DateTime now, GoalConfig goal) {
  final json = jsonEncode(s.toJson()..['goal'] = goal.toJson());
  return compute(_forecastFromJson, (json, now.millisecondsSinceEpoch));
}

Forecast _forecastFromJson((String, int) args) =>
    forecast(AppState.fromJson(jsonDecode(args.$1) as Map<String, dynamic>), DateTime.fromMillisecondsSinceEpoch(args.$2));

/// The rows, the sheet, and (when [figure]) the figure and the summary line. [goal] is edited in place; [onChanged]
/// says it was. The forecast runs when the store's state is complete enough (a profile, a plan, a location).
class MuscleTags extends StatefulWidget {
  const MuscleTags({super.key, required this.goal, required this.onChanged, this.figure = true});
  final GoalConfig goal;
  final VoidCallback onChanged;
  final bool figure;
  @override
  State<MuscleTags> createState() => _MuscleTagsState();
}

class _MuscleTagsState extends State<MuscleTags> {
  Future<Forecast>? future;
  String? futureKey;

  bool _canForecast(AppState s) => s.profile != null && s.plan != null && s.locations.isNotEmpty;

  Future<Forecast>? _forecast(AppState s, DateTime now) {
    if (!_canForecast(s)) return null;
    final key = '${jsonEncode(s.toJson()..['goal'] = widget.goal.toJson())}|${now.year}-${now.month}-${now.day}';
    if (key != futureKey) { futureKey = key; future = forecastAsync(s, now, widget.goal); }
    return future;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final s = store.state;
    final now = store.now;
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final g = widget.goal;
    final rhythm = s.plan == null ? null : rhythmOver(s, now);
    final fc = _forecast(s, now);
    return FutureBuilder<Forecast>(
      future: fc,
      builder: (context, snap) {
        final f = snap.connectionState == ConnectionState.done ? snap.data : null;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (widget.figure) ...[
            Row(children: [
              MuscleFigure(highlight: const {}, tint: tagFills(g), height: 150, selectable: false, tooltip: false, onTap: (h) { if (h != null && trackedMuscles.contains(h.name)) _sheet(context, h.name, rhythm, f); }),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _swatch(context, musclePrimary, 'Active', '${g.activeMuscles.length}'),
                _swatch(context, Color.lerp(musclePlate, musclePrimary, muscleSecondaryAlpha)!, 'Passive', '${g.passiveMuscles.length}'),
                _swatch(context, Color.lerp(musclePlate, const Color(0xFF303030), 0.9)!, 'Ignored', '${trackedMuscles.length - g.activeMuscles.length - g.passiveMuscles.length}'),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: m(context, durBase),
                  child: Text(
                    fc == null ? 'Tap a muscle to change it.' : snap.hasError ? 'Forecast unavailable. Change a choice to retry.' : f == null ? 'Working out the rhythm…' : f.summary(g),
                    key: ValueKey(f == null ? '' : f.summary(g)), style: t.bodySmall?.copyWith(color: du.ink),
                  ),
                ),
              ])),
            ]),
            const SizedBox(height: 12),
          ],
          if (fc != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(
            'Next 12 workouts · ${s.profile!.daysPerWeek} days a week · ${s.location(s.lastLocationId)?.name ?? 'usual location'} · every set completed.', style: t.bodySmall)),
          for (final mus in trackedMuscles) _row(context, mus, rhythm, f, fc != null),
        ]);
      },
    );
  }

  Widget _swatch(BuildContext context, Color c, String label, String count) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: du.line, width: 0.6))),
      const SizedBox(width: 6),
      Text(label, style: t.labelMedium), const SizedBox(width: 6), Text(count, style: t.labelSmall),
    ]));
  }

  /// What the rules do for a muscle, in words: its clock now and the forecast ahead.
  String _line(String mus, Rhythm? r, Forecast? f, bool forecasting) {
    final g = widget.goal;
    switch (g.tagOf(mus)) {
      case MuscleTag.active:
        final often = g.oftenOf(mus) == 0 ? '' : '${oftenLabel[g.oftenOf(mus)]!.toLowerCase()} often · ';
        final ahead = f != null ? f.everyText(mus) : forecasting ? 'working it out…' : 'in turn';
        final recovery = g.oftenOf(mus) > 0 && (f?.recovering[mus] ?? 0) > 0 ? ' · recovery limits extra turns' : '';
        final missed = r != null && r.workouts >= forgottenAfterWorkouts && r.sinceOf(mus) >= forgottenAfterWorkouts
            ? ' · no direct work in the last $forgottenAfterWorkouts workouts' : '';
        return '$often$ahead${r != null ? ' · ${r.dueText(mus)}' : ''}$recovery$missed';
      case MuscleTag.passive:
        return f != null ? f.helpedByText(mus) : r != null ? r.helpedText(mus) : 'helped along the way';
      case MuscleTag.ignored:
        return 'not considered';
    }
  }

  Widget _row(BuildContext context, String mus, Rhythm? r, Forecast? f, bool forecasting) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final tag = widget.goal.tagOf(mus);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(muscleTagIcon(tag), size: 18, color: tag == MuscleTag.active ? du.accentText : du.inkTertiary),
      title: Text(muscleTitle(mus), style: t.bodyMedium?.copyWith(color: tag == MuscleTag.ignored ? du.inkTertiary : du.ink)),
      subtitle: Text('${muscleTagLabel[tag]} · ${_line(mus, r, f, forecasting)}', style: t.bodySmall),
      trailing: Icon(LucideIcons.chevronRight, size: 16, color: du.inkTertiary),
      onTap: () => _sheet(context, mus, r, f),
    );
  }

  Future<void> _sheet(BuildContext context, String mus, Rhythm? r, Forecast? f) async {
    final g = widget.goal;
    await showSheet<void>(context, StatefulBuilder(builder: (context, setSheet) {
      final t = Theme.of(context).textTheme;
      final tag = g.tagOf(mus);
      return FutureBuilder<Forecast>(future: _forecast(context.store.state, context.store.now), builder: (context, snap) {
        final latest = snap.connectionState == ConnectionState.done ? snap.data : null;
        return Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        SheetHeader(muscleTitle(mus), subtitle: _line(mus, r, latest, !snap.hasError && _canForecast(context.store.state)), icon: LucideIcons.personStanding),
        Segmented<MuscleTag>(
          value: tag, options: {for (final v in MuscleTag.values) v: muscleTagLabel[v]!}, icons: {for (final v in MuscleTag.values) v: muscleTagIcon(v)},
          onChanged: (v) { g.setTag(mus, v); widget.onChanged(); setSheet(() {}); setState(() {}); },
        ),
        const SizedBox(height: 6),
        Text(muscleTagBlurb[tag]!, style: t.bodySmall),
        if (tag == MuscleTag.active) ...[
          const SizedBox(height: 14),
          Text('How often', style: t.labelMedium),
          const SizedBox(height: 6),
          Segmented<int>(
            value: g.oftenOf(mus), options: {for (final e in const [-1, 0, 1]) e: oftenLabel[e]!},
            onChanged: (v) { g.setOften(mus, v); widget.onChanged(); setSheet(() {}); setState(() {}); },
          ),
          const SizedBox(height: 6),
          Text('Less is half as often as its turn, more twice. More cannot beat recovery: a muscle worked for three sets carries strain for two days.', style: t.bodySmall),
        ],
      ]));
      });
    }));
  }
}
