p='lib/ui/today.dart'
s=open(p,encoding='utf-8').read()
old="""                        MuscleFigure(highlight: muscles, height: 170, legend: 'Dark: the main muscles. Light: helping. Tap one to name it.'),"""
new="""                        MuscleFigure(highlight: muscles, height: 170, keyLabels: const ('main', 'helping'), expandable: true, title: session.name,
                            detail: (h) => _muscleDetail(session, h)),"""
assert old in s
s=s.replace(old,new,1)
old="""  /// What the workout works: the main muscles, then the helping ones."""
new="""  /// For a tapped muscle: which of today's exercises use it.
  String? _muscleDetail(Session x, MuscleHit h) {
    if (h.dataset.isEmpty) return null;
    final main = <String>[], helping = <String>[];
    for (final e in x.exercises) {
      if (e.exercise.primary.map(datasetGroupOf).contains(h.dataset)) { main.add(e.exercise.name); }
      else if (e.exercise.secondary.map(datasetGroupOf).contains(h.dataset)) { helping.add(e.exercise.name); }
    }
    if (main.isEmpty && helping.isEmpty) return 'Not worked today.';
    return [if (main.isNotEmpty) 'Main in ${main.join(', ')}.', if (helping.isNotEmpty) 'Helps in ${helping.join(', ')}.'].join(' ');
  }

  /// What the workout works: the main muscles, then the helping ones."""
assert old in s
s=s.replace(old,new,1)
open(p,'w',encoding='utf-8').write(s)

p='lib/ui/progress.dart'
s=open(p,encoding='utf-8').read()
old="""            MuscleFigure(highlight: byDatasetGroup(worked), height: 190),"""
new="""            MuscleFigure(highlight: byDatasetGroup(worked), height: 190, keyLabels: const ('worked lately', 'fading'), expandable: true, title: 'Muscles, last two weeks',
                detail: (h) => _muscleDetail(h, worked, last, now)),"""
assert old in s
s=s.replace(old,new,1)
old="""  String _muscleSummary(Map<String, double> worked, Map<String, DateTime?> last, DateTime now) {"""
new="""  /// For a tapped muscle: when its group was last worked and how far that has faded.
  String? _muscleDetail(MuscleHit h, Map<String, double> worked, Map<String, DateTime?> last, DateTime now) {
    final g = appGroupOf(h.dataset);
    if (g == null) return null;
    final at = last[g];
    if (at == null) return '$g · not worked yet.';
    final w = worked[g] ?? 0;
    return '$g · last worked ${agoText(at, now)}${w >= 0.5 ? ', still recovering' : w > 0 ? ', mostly faded' : ', ready for work'}.';
  }

  String _muscleSummary(Map<String, double> worked, Map<String, DateTime?> last, DateTime now) {"""
assert old in s
s=s.replace(old,new,1)
open(p,'w',encoding='utf-8').write(s)
print('ok')
