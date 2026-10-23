# Muscle tag rows as the shared row shape: the tag word at the right, two facts under the name, no paragraph.
def rw(p, fn):
    b = open(p, 'rb').read(); s = b.decode('utf-8'); crlf = '\r\n' in s
    s2 = fn(s.replace('\r\n', '\n'))
    if crlf: s2 = s2.replace('\n', '\r\n')
    open(p, 'wb').write(s2.encode('utf-8'))

def f(s):
    old_imports = "import 'theme.dart';\n"
    s = s.replace(old_imports, "import 'theme.dart';\nimport 'widgets.dart';\n", 1)
    i = s.index("  Widget _row(BuildContext context, String mus, Rhythm? r, Forecast? f, bool forecasting) {")
    j = s.index("  Future<void> _sheet(", i)
    new = '''  Widget _row(BuildContext context, String mus, Rhythm? r, Forecast? f, bool forecasting) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final tag = widget.goal.tagOf(mus);
    return Row1(
      icon: muscleTagIcon(tag),
      muted: tag == MuscleTag.ignored,
      title: Text(muscleTitle(mus)),
      subtitle: _line(mus, r, f, forecasting),
      dense: true,
      trailing: Text(muscleTagLabel[tag]!.toLowerCase(), style: t.labelSmall?.copyWith(color: tag == MuscleTag.active ? du.accentText : du.inkTertiary)),
      onTap: () => _sheet(context, mus, r, f),
    );
  }

'''
    s = s[:i] + new + s[j:]
    # the assumptions line: a fact under the rows, not a sentence above them
    s = s.replace('''          if (fc != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(
            'Next 12 workouts · ${s.profile!.daysPerWeek} days a week · ${s.location(s.lastLocationId)?.name ?? 'usual location'} · every set completed.', style: t.bodySmall)),
          for (final mus in trackedMuscles) _row(context, mus, rhythm, f, fc != null),
''', '''          for (final mus in trackedMuscles) _row(context, mus, rhythm, f, fc != null),
          if (fc != null) Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 6), child: Fact(
            'The next 12 workouts · ${s.profile!.daysPerWeek} days a week · ${s.location(s.lastLocationId)?.name ?? 'usual location'}', icon: LucideIcons.telescope)),
''')
    # shorter lines: the forecast first, then the clock
    s = s.replace("        final ahead = f != null ? f.everyText(mus) : forecasting ? 'working it out…' : 'in turn';", "        final ahead = f != null ? f.everyText(mus) : forecasting ? '…' : 'in turn';")
    return s

rw('lib/ui/muscle_tags.dart', f)
print('ok')
