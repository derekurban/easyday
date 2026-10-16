import os
# pubspec assets
p='pubspec.yaml'
s=open(p,encoding='utf-8').read()
if 'assets/muscle/' not in s:
    s=s.replace("  uses-material-design: true\n","  uses-material-design: true\n  assets:\n    - assets/muscle/\n",1)
open(p,'w',encoding='utf-8').write(s)

# settings: the figure
p='lib/data/model.dart'
s=open(p,encoding='utf-8').read()
s=s.replace("  ExerciseIndex index = ExerciseIndex.muscle;  // how the library is grouped for browsing\n",
            "  ExerciseIndex index = ExerciseIndex.muscle;  // how the library is grouped for browsing\n  String figure = 'male';    // the body map figure: male or female\n",1)
s=s.replace("        'location': location, 'circuit': circuit, 'index': _e(index),\n      };",
            "        'location': location, 'circuit': circuit, 'index': _e(index), 'figure': figure,\n      };",1)
s=s.replace("    ..index = _p(ExerciseIndex.values, j['index'], ExerciseIndex.muscle);\n}",
            "    ..index = _p(ExerciseIndex.values, j['index'], ExerciseIndex.muscle)\n    ..figure = j['figure'] == 'female' ? 'female' : 'male';\n}",1)
assert "figure = j['figure']" in s
open(p,'w',encoding='utf-8').write(s)

# settings UI: a figure choice in the Exercises panel
p='lib/ui/settings.dart'
s=open(p,encoding='utf-8').read()
old="""          ListTile(leading: const IconBadge(LucideIcons.bookOpen, size: 36), title: Text('${exercises.length} exercises'), subtitle: const Text('Built in. Loaded ones by weight, bodyweight ones by version.'), trailing: Icon(LucideIcons.chevronRight, size: 18, color: du.inkTertiary),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CatalogScreen()))),
        ])),"""
new="""          ListTile(leading: const IconBadge(LucideIcons.bookOpen, size: 36), title: Text('${exercises.length} exercises'), subtitle: const Text('Built in. Loaded ones by weight, bodyweight ones by version.'), trailing: Icon(LucideIcons.chevronRight, size: 18, color: du.inkTertiary),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CatalogScreen()))),
          const Divider(height: 8),
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: Row(children: [
            const IconBadge(LucideIcons.personStanding, size: 36),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Body map figure', style: t.bodyLarge),
              const SizedBox(height: 6),
              Segmented<String>(value: st.figure, options: const {'male': 'Male', 'female': 'Female'}, onChanged: (v) => store.update((_) => st.figure = v)),
            ])),
          ])),
        ])),"""
assert old in s
s=s.replace(old,new,1)
open(p,'w',encoding='utf-8').write(s)

# test: every plate group in the shipped maps folds onto an app group or is deliberately unmapped
p='test/features_test.dart'
s=open(p,encoding='utf-8').read()
s=s.replace("import 'dart:convert';\nimport 'dart:math';","import 'dart:convert';\nimport 'dart:io';\nimport 'dart:math';",1)
s=s.replace("import 'package:fitness/logic/muscles.dart';","import 'package:fitness/logic/muscles.dart';\nimport 'package:fitness/ui/body_map.dart';",1)
anchor="  group('calendar', () {"
new='''  group('body map', () {
    test('every plate group in the shipped maps folds onto an app group, or is the one deliberately unmapped muscle', () {
      final meta = jsonDecode(File('assets/muscle/flat.json').readAsStringSync()) as Map<String, dynamic>;
      for (final key in ['male_front', 'male_back', 'female_front', 'female_back']) {
        final plates = (meta['maps'][key]['plates'] as List).cast<Map<String, dynamic>>();
        expect(plates, isNotEmpty, reason: key);
        for (final p in plates) {
          final g = p['group'] as String?;
          if (g == null) { expect(p['muscle'], 'Tibialis anterior', reason: '$key plate ${p['id']}'); continue; }
          expect(muscleGroups, contains(appGroupOf(g)), reason: '$key: $g');
        }
      }
      expect(File('assets/muscle/male_front.png').existsSync(), isTrue);
      expect(File('assets/muscle/female_back_ids.png').existsSync(), isTrue);
    });
  });

'''
s=s.replace(anchor,new+anchor,1)
open(p,'w',encoding='utf-8').write(s)

# docs
root=os.path.join('..','docs','app')
p=os.path.join(root,'COVERAGE.md')
s=open(p,encoding='utf-8').read()
old="""As of 0.13.0 the muscle side is shown, not yet used to choose: a body map (front and back, the eleven
groups) filled by how worked each group is,"""
new="""As of 0.13.0 the muscle side is shown, not yet used to choose: the rendered body maps from `muscle-map/`
(male or female, a setting; front and back; the plates folded onto the eleven groups) tinted by how worked
each group is,"""
assert old in s
s=s.replace(old,new,1)
open(p,'w',encoding='utf-8').write(s)
print('ok')
