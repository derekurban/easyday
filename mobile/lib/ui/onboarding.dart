// Onboarding (UI.md): five pages, one question each. How it works; the goal as a template; about you (experience and
// days a week); where you train as a template; units. Everything can be changed later in Settings. The first page can
// instead restore data copied from another install.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/library.dart';
import '../data/model.dart';
import 'app.dart';
import 'how.dart';
import 'motion.dart';
import 'settings.dart';
import 'theme.dart';
import 'widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int step = 0;
  bool forward = true;
  final goal = GoalConfig.fromTemplate(goals['muscle']!);
  String experience = 'some';
  int days = 3;
  final location = Location(id: 'l0', name: templates.first.name, template: templates.first.id, equipment: templates.first.equipment.toList());
  String units = 'kg';
  final scroll = ScrollController();

  void _go(int to) {
    HapticFeedback.selectionClick();
    setState(() { forward = to > step; step = to; });
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  void _fillLocation(LocationTemplate x) => setState(() => location
    ..name = x.name
    ..template = x.id
    ..equipment = x.equipment.toList());

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final pages = <({String title, String blurb, Widget body})>[
      (title: 'How it works', blurb: 'Six things, then you never think about programming again.', body: const HowItWorks(compact: true)),
      (title: 'What are you after?', blurb: 'A template sets the reps, the sets and the movement days. Change any of it later in Settings.', body: Column(children: [
        for (final tpl in goals.values)
          OptionCard(icon: goalIcon(tpl.id), title: tpl.name, blurb: tpl.blurb, detail: tpl.explain.join(' · '), selected: goal.template == tpl.id, onTap: () => setState(() { goal.fill(tpl); goal.name = tpl.name; })),
      ])),
      (title: 'About you', blurb: 'Only to pick a careful first level and set the pace. Both correct themselves in a workout or two.', body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Subhead('How much have you trained?', icon: LucideIcons.sprout),
        const SizedBox(height: 10),
        for (final e in experiences) OptionCard(icon: experienceIcon(e.id), title: e.name, blurb: e.blurb, selected: experience == e.id, onTap: () => setState(() => experience = e.id)),
        const SizedBox(height: 10),
        const Subhead('Days a week, roughly', icon: LucideIcons.calendarDays),
        ChoiceRow<int>(value: days, options: const {1: '1', 2: '2', 3: '3', 4: '4', 5: '5', 6: '6'}, onChanged: (v) => setState(() => days = v)),
        const QuietLine('There are no fixed days. Whenever you come back, a workout is waiting.', icon: LucideIcons.info),
      ])),
      (title: 'Where do you train?', blurb: 'Equipment decides which exercises fit. Tick exactly what is there later in Settings, and add more places.', body: Column(children: [
        for (final x in templates)
          OptionCard(icon: locationIcon(x.id), title: x.name, blurb: x.equipment.isEmpty ? 'Bodyweight only' : '${x.equipment.length} item${x.equipment.length == 1 ? '' : 's'}', selected: location.template == x.id, onTap: () => _fillLocation(x)),
      ])),
      (title: 'Kilograms or pounds?', blurb: 'Steps and labels follow your choice.', body: Column(children: [
        OptionCard(icon: LucideIcons.weight, title: 'Kilograms', blurb: 'Steps of 2.5 kg on a bar, 2 kg on dumbbells.', selected: units == 'kg', onTap: () => setState(() => units = 'kg')),
        OptionCard(icon: LucideIcons.scale, title: 'Pounds', blurb: 'Steps of 5 lb on a bar, 5 lb on dumbbells.', selected: units == 'lb', onTap: () => setState(() => units = 'lb')),
      ])),
    ];
    final p = pages[step];
    final last = step == pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(children: [
              for (var i = 0; i < pages.length; i++)
                Expanded(child: Padding(padding: EdgeInsets.only(right: i == pages.length - 1 ? 0 : 4), child: Meter(i <= step ? 1 : 0, height: 3))),
            ]),
          ),
          Expanded(
            child: PageSwitcher(
              index: step,
              forward: forward,
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
                children: [
                  Text(p.title, style: t.headlineLarge),
                  const SizedBox(height: 8),
                  Text(p.blurb, style: t.bodyMedium?.copyWith(color: du.inkSecondary)),
                  const SizedBox(height: 24),
                  p.body,
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(color: du.bg, border: Border(top: BorderSide(color: du.line, width: 0.6))),
            child: Row(children: [
              if (step > 0) OutlinedButton.icon(onPressed: () => _go(step - 1), icon: const Icon(LucideIcons.chevronLeft, size: 18), label: const Text('Back'))
              else TextButton.icon(onPressed: _restore, icon: const Icon(LucideIcons.clipboardPaste, size: 18), label: const Text('Restore copied data')),
              const Spacer(),
              FilledButton.icon(
                onPressed: last ? _finish : () => _go(step + 1),
                icon: Icon(last ? LucideIcons.play : LucideIcons.chevronRight, size: 18),
                iconAlignment: IconAlignment.end,
                label: Text(last ? 'Start' : 'Next'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  /// Restoring skips the rest of onboarding. The settings screen is not up to ask for permissions, so whatever the copy
  /// had on is named for turning back on there.
  Future<void> _restore() async {
    final messenger = ScaffoldMessenger.of(context);
    final want = await restoreCopiedData(context);
    if (want == null) return;
    final off = [if (want.notify) 'the reminder', if (want.calendar || want.autoTrack) 'the calendar', if (want.location) 'position'];
    final list = off.length < 2 ? off.join() : '${off.sublist(0, off.length - 1).join(', ')} and ${off.last}';
    messenger.showSnackBar(SnackBar(content: Text(off.isEmpty ? 'Restored.' : 'Restored. Turn $list back on in Settings.')));
  }

  void _finish() {
    final store = context.store;
    HapticFeedback.lightImpact();
    store.update((s) {
      s.profile = Profile(experience: experience, daysPerWeek: days, createdAt: store.now);
      s.goal = goal;
      location.id = s.nextId('l');
      s.locations = [location];
      s.lastLocationId = location.id;
      s.units = units;
      s.seenHow = true;
      s.plan = Plan();
    });
  }
}
