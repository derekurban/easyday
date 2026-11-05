// The colours of a workout's states: what the finish screen, the strip, the ranks and the tags paint with, in one
// place. The app's scheme is [emberDusk], chosen on 2026-11-04 in the Playground's colour lab from remixes of three
// Derek liked (Ember and mist, Night and fire, Soft light), every colour at a middle strength: the right colour for the
// right action. How much of the finish screen takes colour is [FinishColour], tried in the same lab. The brand stays fixed under every scheme: true-gray neutrals and the moss
// green accent, which means the user, their level and their progress. A scheme only decides the states around it.
import 'package:flutter/material.dart';

/// One colour as ink, for each theme: lighter on the dark surface, deeper on the light one, so text stays readable.
class InkPair {
  const InkPair(this.light, this.dark);
  final Color light, dark;
  Color of(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// A state's colour and why it is that colour, for the lab's sheet.
typedef StateWhy = ({String state, String why});

class StatePalette {
  const StatePalette({
    required this.name, required this.idea, required this.reasons,
    required this.earned, required this.earnedInk, required this.push, required this.pushInk,
    required this.fresh, required this.freshFill, required this.freshInk,
    required this.gentleInk, required this.hurtInk, required this.ranks, required this.confetti,
  });
  final String name;
  final String idea;              // the scheme in a line
  final List<StateWhy> reasons;   // each state, and why
  final List<Color> earned;       // a level the app earned for you: the sweep behind its tile and the big mark
  final InkPair earnedInk;        // Harder, the arrow up
  final List<Color> push;         // your own push made good: its sweep
  final InkPair pushInk;          // reaching for more, the flame
  final List<Color> fresh;        // finding out: the first time's sweep, the calibrating edge
  final Color freshFill;          // the strip's calibration set, a tag's ring
  final InkPair freshInk;         // "Calibrating", "Your weight"
  final InkPair gentleInk;        // going easy: Easier, eased off, short of the range, a rating down
  final InkPair hurtInk;          // something hurt
  final List<Color> ranks;        // Iron to Champion
  final List<Color> confetti;

  static StatePalette of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<PaletteScope>()?.palette ?? emberDusk;
}

/// The palette, and how much colour the finish takes, for everything under it.
class PaletteScope extends InheritedWidget {
  const PaletteScope({super.key, required this.palette, this.finish = FinishColour.edges, required super.child});
  final StatePalette palette;
  final FinishColour finish;
  /// How much colour the finish takes, under the nearest scope, else the app's own.
  static FinishColour finishOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<PaletteScope>()?.finish ?? FinishColour.edges;
  @override
  bool updateShouldNotify(PaletteScope old) => old.palette != palette || old.finish != finish;
}

/// How much of the finish screen takes colour. Colour marks the moments that matter, not every tile: Derek, 2026-11-04,
/// "be tasteful about when and where we include colour instead of making the whole app a rainbow". He chose [edges].
enum FinishColour {
  sweep('Full sweep', 'Every level earned and every push fills its tile with its sweep: what the app had.',
      'Loud and generous: on a good day the screen is a stack of colour, and no one moment stands out from the rest.'),
  oneMoment('One moment', 'Only the day\'s biggest moment fills its tile: a level earned, else your push. Other wins wear an edge.',
      'The day gets one headline, like a front page: colour where it means most, a thin edge and a coloured mark for the other wins, plain tiles for the rest.'),
  edges('Edges', 'No tile is filled: wins and first times wear a thin coloured edge, the badge at the top celebrates.',
      'The celebration moves to the badge and the confetti at the top; the tiles stay calm and readable, each win told by its edge, mark and label.'),
  marks('Marks only', 'Every tile plain: colour only in the mark, the small label and the word for next time.',
      'The quietest: the screen reads as a calm list, and colour is a small signal beside each line, never a surface.');
  const FinishColour(this.label, this.idea, this.why);
  final String label;
  final String idea;
  final String why;
}

/// The app's scheme: your effort ember, the app's reward a soft violet dusk, easy mist, finding out sea glass.
const emberDusk = StatePalette(
  name: 'Ember and dusk',
  idea: 'Your effort is ember, the app\'s reward is a soft violet dusk: two different feelings for two different things. Easy is mist.',
  reasons: [
    (state: 'A level earned', why: 'Soft violet into orchid and rose, from Night and fire but at half the volume: the app handing you a level, rarer and a little magical.'),
    (state: 'Your push', why: 'Ember, amber into terracotta: your own effort, warm and physical. Violet for what you are given, ember for what you did.'),
    (state: 'Finding out', why: 'Sea glass into sky: cool, clear, a lift being set up.'),
    (state: 'Going easy', why: 'Mist blue-grey: quiet, close to the greys.'),
    (state: 'Something hurt', why: 'A muted red, kept apart from the ember by its coolness and its own icon.'),
    (state: 'Ranks', why: 'Clear of violet, ember and teal: steel, ice, and crimson at the top.'),
  ],
  earned: [Color(0xFF8676CF), Color(0xFFA27AC0), Color(0xFFBF869E)],
  earnedInk: InkPair(Color(0xFF6B4FB8), Color(0xFFB9A6F0)),
  push: [Color(0xFFD08640), Color(0xFFC86A3A), Color(0xFFBC5F3C)],
  pushInk: InkPair(Color(0xFFA84A1F), Color(0xFFEE9A62)),
  fresh: [Color(0xFF4FAE9F), Color(0xFF3EA0B3), Color(0xFF5A8CC8)],
  freshFill: Color(0xFF3EA0B3),
  freshInk: InkPair(Color(0xFF1B6F80), Color(0xFF6CC6D6)),
  gentleInk: InkPair(Color(0xFF566E82), Color(0xFF9FB3C4)),
  hurtInk: InkPair(Color(0xFFB83A35), Color(0xFFE8807A)),
  ranks: [Color(0xFF7A7F87), Color(0xFFB0763C), Color(0xFF9CA6B0), Color(0xFFC9971C), Color(0xFFA9B3C2), Color(0xFF86C9EA), Color(0xFFC23A4C)],
  confetti: [Color(0xFF8676CF), Color(0xFFBF869E), Color(0xFFD08640), Color(0xFF86AB7A), Color(0xFF9FB3C4)],
);

/// The schemes the lab offers: the one chosen.
const palettes = <StatePalette>[emberDusk];
