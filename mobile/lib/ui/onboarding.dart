// Onboarding: how it works, goal, experience, days per week, a location, units.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/library.dart';
import '../data/model.dart';
import '../logic/rotation.dart';
import 'app.dart';
import 'goal_editor.dart';
import 'how.dart';
import 'location_editor.dart';
import 'motion.dart';
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
    setState(() { forward = to > step; step = to; });
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final pages = <({String title, String blurb, Widget body})>[
      (title: 'How it works', blurb: 'Six things, then you never think about programming again.', body: const HowItWorks(compact: true)),
      (title: 'What are you after?', blurb: 'Your goal, in plain words. Fill it from a template if you like, then change anything, now or later.',
          body: GoalEditor(goal: goal, daysPerWeek: days, onChanged: (_) => setState(() {}))),
      (title: 'How much have you lifted?', blurb: 'Only used to pick a conservative first level on each exercise. It corrects itself in a workout or two.', body: Column(children: [
        for (final e in experiences) OptionCard(icon: experienceIcon(e.id), title: e.name, blurb: e.blurb, selected: experience == e.id, onTap: () => setState(() => experience = e.id)),
      ])),
      (title: 'How many days a week, roughly?', blurb: 'Sets the length of the rotation. There are no fixed days: whenever you come back, the next workout is waiting.', body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ChoiceRow<int>(value: days, options: const {1: '1', 2: '2', 3: '3', 4: '4', 5: '5', 6: '6'}, onChanged: (v) => setState(() => days = v)),
        const SizedBox(height: 8),
        Text('Your rotation', style: t.labelMedium),
        const SizedBox(height: 6),
        RotationPreview(buildRotation(goal, days)),
      ])),
      (title: 'Where do you train?', blurb: 'Name the place and tick what is there. A template fills the list; you can add more places later.',
          body: LocationEditor(location: location, showPosition: false, onChanged: () => setState(() {}))),
      (title: 'Kilograms or pounds?', blurb: 'Loads are stored in kilograms; steps and labels follow your choice.', body: Column(children: [
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(children: [
              for (var i = 0; i < pages.length; i++)
                Expanded(child: Padding(padding: const EdgeInsets.only(right: 4), child: Meter(i <= step ? 1 : 0, height: 3))),
            ]),
          ),
          Expanded(
            child: PageSwitcher(
              index: step,
              forward: forward,
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(color: du.bg, border: Border(top: BorderSide(color: du.line, width: 0.6))),
            child: Row(children: [
              if (step > 0) OutlinedButton.icon(onPressed: () => _go(step - 1), icon: const Icon(LucideIcons.chevronLeft, size: 18), label: const Text('Back')),
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

  void _finish() {
    final store = context.store;
    store.update((s) {
      s.profile = Profile(experience: experience, daysPerWeek: days, createdAt: store.now);
      s.goal = goal;
      location.id = s.nextId('l');
      s.locations = [location];
      s.lastLocationId = location.id;
      s.units = units;
      s.seenHow = true;
      initPlan(s);
    });
  }
}
