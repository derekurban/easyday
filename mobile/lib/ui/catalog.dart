// Catalog: every exercise with levels (strength, power, stability) grouped by the chosen index. One line per
// exercise: the name, its level when practised, the difficulty word at the right. Search, a few filters, tap for the
// card. Stretches and cardio live in the stretching routines and the cardio choices.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/index.dart';
import '../data/library.dart';
import '../logic/ladder.dart';
import 'app.dart';
import 'exercise_card.dart';
import 'theme.dart';
import 'widgets.dart';

enum _Filter { here, practised, bodyweight, loaded }

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final filters = <_Filter>{_Filter.here};
  String query = '';

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final s = store.state;
    final ix = s.settings.index;
    final loc = s.location(s.lastLocationId);
    final have = loc?.equipment ?? const <String>[];
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final q = query.trim().toLowerCase();
    bool keep(Exercise e) {
      if (filters.contains(_Filter.here) && !available(e, have)) return false;
      if (filters.contains(_Filter.practised) && (s.ex[e.id]?.appearances ?? 0) == 0) return false;
      if (filters.contains(_Filter.bodyweight) && e.loaded) return false;
      if (filters.contains(_Filter.loaded) && !e.loaded) return false;
      if (q.isNotEmpty && !e.name.toLowerCase().contains(q) && !muscleGroupsOf(e).any((g) => g.toLowerCase().contains(q)) && !indexGroup(e, ix).toLowerCase().contains(q)) return false;
      return true;
    }
    final groups = groupBy(browsable.where(keep), ix);
    final shown = groups.fold(0, (n, g) => n + g.value.length);
    void toggle(_Filter f, bool v) => setState(() {
          if (v) { filters.add(f); if (f == _Filter.bodyweight) filters.remove(_Filter.loaded); if (f == _Filter.loaded) filters.remove(_Filter.bodyweight); } else { filters.remove(f); }
        });
    final rows = <Widget>[];
    for (final g in groups) {
      rows.add(Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 4), child: Row(children: [
        Text(g.key, style: t.labelLarge?.copyWith(color: du.inkSecondary)),
        const SizedBox(width: 8),
        Text('${g.value.length}', style: t.labelSmall?.copyWith(color: du.inkTertiary)),
      ])));
      for (final e in g.value) {
        final st = s.ex[e.id];
        final practised = st != null && st.appearances > 0;
        final type = e.isStrength || ix == ExerciseIndex.type ? null : typeLabel[e.type]!.toLowerCase();
        rows.add(Row1(
          icon: exerciseIcon(e),
          title: Text(e.name),
          subtitle: practised ? [rungLabel(s, e, st, st.rung), '${mmss(st.secPerSet)} a set', ?type].join(' · ') : type,
          trailing: DifficultyTag(difficultyInPlay(e, st)),
          chevron: false,
          dense: true,
          muted: !practised,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseCardScreen(e.id))),
        ));
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Exercises')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            decoration: InputDecoration(hintText: 'Search ${browsable.length} exercises', prefixIcon: const Icon(LucideIcons.search, size: 18), isDense: true),
            onChanged: (v) => setState(() => query = v),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            FilterChip(avatar: Icon(locationIcon(loc?.template ?? 'none'), size: 14), label: Text(loc == null ? 'Here' : 'At ${loc.name}'), selected: filters.contains(_Filter.here), onSelected: (v) => toggle(_Filter.here, v)),
            const SizedBox(width: 8),
            FilterChip(avatar: const Icon(LucideIcons.history, size: 14), label: const Text('Practised'), selected: filters.contains(_Filter.practised), onSelected: (v) => toggle(_Filter.practised, v)),
            const SizedBox(width: 8),
            FilterChip(avatar: const Icon(LucideIcons.personStanding, size: 14), label: const Text('Bodyweight'), selected: filters.contains(_Filter.bodyweight), onSelected: (v) => toggle(_Filter.bodyweight, v)),
            const SizedBox(width: 8),
            FilterChip(avatar: const Icon(LucideIcons.weight, size: 14), label: const Text('Weights'), selected: filters.contains(_Filter.loaded), onSelected: (v) => toggle(_Filter.loaded, v)),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 8, 0), child: Row(children: [
          Text('$shown shown', style: t.labelSmall),
          const Spacer(),
          IndexButton(onChanged: () => setState(() {})),
        ])),
        Expanded(child: rows.isEmpty
            ? Padding(padding: const EdgeInsets.all(24), child: Text('Nothing matches. Clear a filter or add equipment to ${loc?.name ?? 'this location'}.', style: t.bodySmall?.copyWith(color: du.inkSecondary)))
            : ListView(padding: const EdgeInsets.fromLTRB(0, 0, 0, 24), children: rows)),
      ]),
    );
  }
}

/// "By muscle group" with a sheet to pick another index. Writes the setting.
class IndexButton extends StatelessWidget {
  const IndexButton({super.key, this.onChanged});
  final VoidCallback? onChanged;
  @override
  Widget build(BuildContext context) {
    final ix = context.store.state.settings.index;
    return TextButton.icon(
      onPressed: () async { await pickIndex(context); onChanged?.call(); },
      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
      icon: const Icon(LucideIcons.layers, size: 16),
      label: Text('By ${indexLabel[ix]!.toLowerCase()}'),
    );
  }
}

Future<void> pickIndex(BuildContext context) async {
  final store = context.store;
  final picked = await showSheet<ExerciseIndex>(context, Builder(builder: (context) {
    final current = store.state.settings.index;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SheetHeader('Group exercises by', subtitle: 'Only the headings change.', icon: LucideIcons.layers),
      for (final ix in ExerciseIndex.values)
        ListTile(
          leading: Icon(ix == current ? LucideIcons.circleCheck : LucideIcons.circle, size: 20, color: ix == current ? context.du.accentStrong : context.du.line),
          title: Text(indexLabel[ix]!), subtitle: Text(indexBlurb[ix]!),
          selected: ix == current,
          onTap: () => Navigator.pop(context, ix),
        ),
      const SizedBox(height: 12),
    ]);
  }));
  if (picked != null) store.update((s) => s.settings.index = picked);
}
