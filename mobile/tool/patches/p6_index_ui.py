import io
def patch(path, pairs):
    t = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert old in t, (path, old[:70])
        t = t.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(t)

# settings.dart: "Your exercises" -> "Exercises" with the index picker
patch('lib/ui/settings.dart', [
    ("import 'custom_exercise.dart';\n", "import 'catalog.dart';\n"),
    ("import '../data/library.dart';\n", "import '../data/index.dart';\nimport '../data/library.dart';\n"),
    ("""        const SectionHeader('Your exercises', icon: LucideIcons.pencil),
        Panel(padding: EdgeInsets.zero, child: Column(children: [
          for (final e in s.custom)
            ListTile(leading: IconBadge(exerciseIcon(e), size: 36), title: Text(e.name), subtitle: Text(e.loaded ? 'by weight, steps of ${e.stepKg} kg' : '${e.ladder!.variants.length} levels'), trailing: Icon(LucideIcons.chevronRight, size: 18, color: du.inkTertiary),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomExerciseScreen(existing: e)))),
          ListTile(leading: const IconBadge(LucideIcons.plus, size: 36), title: const Text('New exercise'), subtitle: const Text('Your own progression, your own how-to'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomExerciseScreen()))),
        ])),
""", """        const SectionHeader('Exercises', icon: LucideIcons.layers),
        Panel(padding: EdgeInsets.zero, child: Column(children: [
          ListTile(leading: const IconBadge(LucideIcons.layers, size: 36), title: const Text('Group by'), subtitle: Text('${indexLabel[st.index]}. ${indexBlurb[st.index]}'), trailing: Icon(LucideIcons.chevronRight, size: 18, color: du.inkTertiary),
              onTap: () => pickIndex(context)),
          ListTile(leading: const IconBadge(LucideIcons.bookOpen, size: 36), title: Text('${exercises.length} exercises'), subtitle: const Text('Built in. Loaded ones by weight, bodyweight ones by version.'), trailing: Icon(LucideIcons.chevronRight, size: 18, color: du.inkTertiary),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CatalogScreen()))),
        ])),
"""),
])

# exercise_card.dart: no edit/delete; a "works" line in muscle groups and the group under the current index
patch('lib/ui/exercise_card.dart', [
    ("import 'custom_exercise.dart';\n", ""),
    ("import '../data/library.dart';\n", "import '../data/index.dart';\nimport '../data/library.dart';\n"),
    ("    final muscles = [...ex.primary, ...ex.secondary.map((m) => m)];\n",
     "    final works = muscleGroupsOf(ex);\n    final ix = s.settings.index;\n"),
    ("""      appBar: AppBar(title: Text(ex.name), actions: [
        if (ex.custom) TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomExerciseScreen(existing: ex))), icon: const Icon(LucideIcons.pencil, size: 16), label: const Text('Edit')),
      ]),
""", "      appBar: AppBar(title: Text(ex.name)),\n"),
    ("          Expanded(child: Text(ex.custom ? 'Your exercise${muscles.isNotEmpty ? ' · ${muscles.join(', ')}' : ''}' : muscles.join(', '), style: t.bodySmall)),\n",
     "          Expanded(child: Text('Works ${works.join(', ').toLowerCase()}${ix == ExerciseIndex.muscle ? '' : ' · ${indexLabel[ix]!.toLowerCase()}: ${indexGroup(ex, ix).toLowerCase()}'}', style: t.bodySmall)),\n"),
    ("""        if (ex.custom) ...[
          const SizedBox(height: 24),
          Center(child: TextButton.icon(
            onPressed: () => _delete(context, ex),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            icon: const Icon(LucideIcons.trash2, size: 16), label: const Text('Delete this exercise'),
          )),
        ],
""", ""),
    ("""  Future<void> _delete(BuildContext context, Exercise ex) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text('Delete ${ex.name}?'),
      content: const Text('Its level and history go with it.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))],
    ));
    if (ok != true || !context.mounted) return;
    context.store.update((s) { s.custom.removeWhere((x) => x.id == ex.id); s.ex.remove(ex.id); setCustomExercises(s.custom); });
    Navigator.pop(context);
  }

""", ""),
])

# progress.dart: level trend grouped by the index
patch('lib/ui/progress.dart', [
    ("import '../data/library.dart';\n", "import '../data/index.dart';\nimport '../data/library.dart';\n"),
    ("import 'app.dart';\n", "import 'app.dart';\nimport 'catalog.dart';\n"),
    ("""    final trendRows = trend.entries.where((e) => exerciseById.containsKey(e.key)).toList()
      ..sort((a, b) { final c = b.value.compareTo(a.value); return c != 0 ? c : exerciseById[a.key]!.name.compareTo(exerciseById[b.key]!.name); });
""", """    final ix = s.settings.index;
    final trendGroups = groupBy(trend.keys.where(exerciseById.containsKey).map((k) => exerciseById[k]!), ix,
        sort: (a, b) { final c = trend[b.id]!.compareTo(trend[a.id]!); return c != 0 ? c : a.name.compareTo(b.name); });
"""),
    ("        const SectionHeader('Levels, last 30 days', icon: LucideIcons.trendingUp),\n",
     "        SectionHeader('Levels, last 30 days', icon: LucideIcons.trendingUp, trailing: trendGroups.isEmpty ? null : const IndexButton()),\n"),
    ("""          if (trendRows.isEmpty) const ListTile(leading: IconBadge(LucideIcons.hourglass, size: 36), title: Text('Nothing yet'), subtitle: Text('Levels move after normal and hard workouts.')),
          for (final row in trendRows)
            ListTile(
              leading: IconBadge(exerciseIcon(exerciseById[row.key]!), size: 36, accent: row.value > 0),
              title: Text(exerciseById[row.key]!.name),
              subtitle: Text('now: ${s.ex[row.key] == null ? '' : _label(s, row.key)}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(row.value > 0 ? LucideIcons.arrowUpRight : row.value < 0 ? LucideIcons.trendingDown : LucideIcons.minus, size: 16, color: row.value > 0 ? du.accentText : du.inkSecondary),
                const SizedBox(width: 6),
                Text(row.value > 0 ? '+${row.value} level${row.value == 1 ? '' : 's'}' : row.value == 0 ? 'holding' : '${row.value} level${row.value == -1 ? '' : 's'}',
                    style: t.titleMedium?.copyWith(color: row.value > 0 ? du.accentText : du.inkSecondary)),
              ]),
            ),
""", """          if (trendGroups.isEmpty) const ListTile(leading: IconBadge(LucideIcons.hourglass, size: 36), title: Text('Nothing yet'), subtitle: Text('Levels move after normal and hard workouts.')),
          for (final g in trendGroups) ...[
            Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Align(alignment: Alignment.centerLeft, child: Text(g.key, style: t.labelLarge?.copyWith(color: du.accentText)))),
            for (final e in g.value)
              ListTile(
                leading: IconBadge(exerciseIcon(e), size: 36, accent: trend[e.id]! > 0),
                title: Text(e.name),
                subtitle: Text('now: ${s.ex[e.id] == null ? '' : _label(s, e.id)}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(trend[e.id]! > 0 ? LucideIcons.arrowUpRight : trend[e.id]! < 0 ? LucideIcons.trendingDown : LucideIcons.minus, size: 16, color: trend[e.id]! > 0 ? du.accentText : du.inkSecondary),
                  const SizedBox(width: 6),
                  Text(trend[e.id]! > 0 ? '+${trend[e.id]} level${trend[e.id] == 1 ? '' : 's'}' : trend[e.id] == 0 ? 'holding' : '${trend[e.id]} level${trend[e.id] == -1 ? '' : 's'}',
                      style: t.titleMedium?.copyWith(color: trend[e.id]! > 0 ? du.accentText : du.inkSecondary)),
                ]),
              ),
          ],
"""),
])
print('ok')
