// Catalog: every exercise grouped by the chosen index, with its level and cost. Search, a few filters, tap for the card.
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
    final groups = groupBy(exercises.where(keep), ix);
    final shown = groups.fold(0, (n, g) => n + g.value.length);
    void toggle(_Filter f, bool v) => setState(() {
          if (v) { filters.add(f); if (f == _Filter.bodyweight) filters.remove(_Filter.loaded); if (f == _Filter.loaded) filters.remove(_Filter.bodyweight); } else { filters.remove(f); }
        });
    final rows = <Widget>[];
    for (final g in groups) {
      rows.add(Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 2), child: Row(children: [
        Text(g.key, style: t.labelLarge?.copyWith(color: du.accentText)),
        const SizedBox(width: 8),
        Text('${g.value.length}', style: t.labelSmall?.copyWith(color: du.inkTertiary)),
      ])));
      for (final e in g.value) {
        final st = s.ex[e.id];
        rows.add(ListTile(
          leading: IconBadge(exerciseIcon(e), size: 36, accent: st != null),
          title: Text(e.name),
          subtitle: Text(st == null ? (e.loaded ? 'by weight · not yet practised' : '${e.ladder!.variants.length} levels · not yet practised') : 'level: ${rungLabel(s, e, st, st.rung)}'),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            DifficultyTag(difficultyInPlay(e, st)),
            if (st != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(mmss(st.secPerSet), style: t.labelSmall)),
          ]),
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
            decoration: InputDecoration(hintText: 'Search ${exercises.length} exercises', prefixIcon: const Icon(LucideIcons.search, size: 18), isDense: true),
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

/// "Grouped by muscle group" with a sheet to pick another index. Writes the setting.
class IndexButton extends StatelessWidget {
  const IndexButton({super.key, this.onChanged});
  final VoidCallback? onChanged;
  @override
  Widget build(BuildContext context) {
    final ix = context.store.state.settings.index;
    return TextButton.icon(
      onPressed: () async { await pickIndex(context); onChanged?.call(); },
      icon: const Icon(LucideIcons.layers, size: 16),
      label: Text('By ${indexLabel[ix]!.toLowerCase()}'),
    );
  }
}

Future<void> pickIndex(BuildContext context) async {
  final store = context.store;
  final picked = await showSheet<ExerciseIndex>(context, Builder(builder: (context) {
    final t = Theme.of(context).textTheme;
    final current = store.state.settings.index;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 4), child: Text('Group exercises by', style: t.titleMedium)),
      Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text('Only the headings change. The workout is built the same way whichever you pick.', style: t.bodySmall)),
      for (final ix in ExerciseIndex.values)
        ListTile(
          leading: Icon(ix == current ? LucideIcons.circleCheck : LucideIcons.circle, size: 20),
          title: Text(indexLabel[ix]!), subtitle: Text(indexBlurb[ix]!),
          selected: ix == current,
          onTap: () => Navigator.pop(context, ix),
        ),
      const SizedBox(height: 12),
    ]);
  }));
  if (picked != null) store.update((s) => s.settings.index = picked);
}
