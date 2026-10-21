// How it works, in plain words. Shown once in onboarding and always reachable from Settings.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'motion.dart';
import 'theme.dart';
import 'widgets.dart';

export 'widgets.dart' show Explain;

class HowItWorks extends StatelessWidget {
  const HowItWorks({super.key, this.compact = false});
  final bool compact;

  static const items = [
    (
      LucideIcons.listOrdered,
      'Every exercise has a progression',
      'A progression is the list of levels an exercise can get harder by. For a barbell or machine it is the next weight. For dumbbells, the next pair. '
          'For a bodyweight exercise it is the next version: wall push-ups, then incline, then knee, then full push-ups, and so on.',
    ),
    (
      LucideIcons.circleDot,
      'Your level is where you are on it',
      'The level is the step you are on right now: 40 kg, 14 kg dumbbells, or knee push-ups. The app picks it for you, shows it on every exercise, and changes the how-to to match.',
    ),
    (
      LucideIcons.trendingUp,
      'Hit the top of the range and the next level is yours',
      'Each set has a rep range, say 8 to 12. Aim for the top. Hit it on every set and next time you level up. '
          'Fall below the bottom a couple of times and it comes down one. Anything in between, it holds. You never choose weights.',
    ),
    (
      LucideIcons.batteryMedium,
      'Two questions describe a day',
      'How much energy you have decides what goes in the workout and how hard you push. How many minutes you have decides how many sets and exercises fit. '
          'Neither one ever moves a level.',
    ),
    (
      LucideIcons.timerOff,
      'Nothing is timed for you',
      'There are no rest timers. The app learns how long your sets take from your taps and uses that to make the minutes real.',
    ),
    (
      LucideIcons.sunrise,
      'One workout a day, and missing days is expected',
      'When a workout is done, that is the day. The next one is ready tomorrow. A level you have not used for a few weeks eases down one step and climbs straight back after one good workout.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < items.length; i++)
        Reveal(
          delay: Duration(milliseconds: 60 * i),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconBadge(items[i].$1, accent: true),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(items[i].$2, style: t.titleLarge),
                const SizedBox(height: 4),
                Text(items[i].$3, style: t.bodyMedium?.copyWith(color: du.inkSecondary)),
              ])),
            ]),
          ),
        ),
    ]);
    if (compact) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('How it works')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [body]),
    );
  }
}

const levelExplainer = 'Your level is the step you are on: the weight, the dumbbell pair, or the bodyweight version.';
const progressionExplainer = 'The progression is every level this exercise can get harder by. Hit the top of the rep range on every set and the next level is yours.';
