// Shared controls. Each one matches the shape of the data it edits: a band for a range, chips for a handful of
// discrete values, a slider for a continuous one, cards for a pick, a track for a ladder. The small pieces every
// screen is built from (UI.md): a sentence-case section header, a fact line under a title, numbered steps, an
// accordion of moves, the plan strip.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/library.dart';
import '../data/model.dart';
import 'motion.dart';
import 'theme.dart';

// ---------- icons for the domain

IconData patternIcon(String pattern) => switch (pattern) {
      'squat' => LucideIcons.personStanding,
      'hinge' => LucideIcons.moveVertical,
      'push' => LucideIcons.arrowUp,
      'pull' => LucideIcons.arrowDown,
      'core' => LucideIcons.target,
      'carry' => LucideIcons.package,
      'arms' => LucideIcons.bicepsFlexed,
      'shoulders' => LucideIcons.mountain,
      'legs' => LucideIcons.footprints,
      _ => LucideIcons.dumbbell,
    };

/// Loaded exercises get a weight, bodyweight ones a figure, the user's own a pencil.
IconData exerciseIcon(Exercise e) => e.loaded ? LucideIcons.weight : LucideIcons.personStanding;

IconData goalIcon(String template) => switch (template) {
      'strength' => LucideIcons.dumbbell,
      'muscle' => LucideIcons.bicepsFlexed,
      'fit' => LucideIcons.heartPulse,
      'feel' => LucideIcons.smile,
      _ => LucideIcons.slidersHorizontal,
    };

IconData experienceIcon(String id) => switch (id) { 'new' => LucideIcons.sprout, 'some' => LucideIcons.leaf, _ => LucideIcons.treePine };

IconData locationIcon(String template) => switch (template) {
      'gym' => LucideIcons.building2,
      'hotel' => LucideIcons.hotel,
      'none' => LucideIcons.circleOff,
      'custom' => LucideIcons.mapPin,
      _ => LucideIcons.house,
    };

IconData equipmentGroupIcon(String name) => switch (name) {
      'Free weights' => LucideIcons.dumbbell,
      'Stations' => LucideIcons.layoutGrid,
      'Machines' => LucideIcons.settings,
      'Loading gear' => LucideIcons.backpack,
      'Small gear' => LucideIcons.cable,
      _ => LucideIcons.bike,
    };

IconData energyIcon(Energy e) => switch (e) { Energy.easy => LucideIcons.batteryLow, Energy.normal => LucideIcons.batteryMedium, Energy.hard => LucideIcons.batteryFull };
IconData moveIcon(String? kind) => kind == 'cardio' ? LucideIcons.footprints : LucideIcons.stretchHorizontal;

// ---------- small building blocks

/// A section's name: an icon and a sentence-case label in secondary ink, with room below it. The one header style
/// every screen uses.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.icon, this.trailing, this.marker});
  final String text;
  final IconData? icon;
  final Widget? trailing;
  /// A small mark right after the label, such as the dot for a waiting update.
  final Widget? marker;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(children: [
        if (icon != null) ...[Icon(icon, size: 16, color: du.inkSecondary), const SizedBox(width: 8)],
        Expanded(child: Row(children: [
          Flexible(child: Text(text, style: t.labelLarge?.copyWith(color: du.inkSecondary))),
          if (marker != null) ...[const SizedBox(width: 6), marker!],
        ])),
        ?trailing,
      ]),
    );
  }
}

/// The same header without the room around it, for inside a card or a list.
class Subhead extends StatelessWidget {
  const Subhead(this.text, {super.key, this.icon});
  final String text;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Row(children: [
      if (icon != null) ...[Icon(icon, size: 16, color: du.inkSecondary), const SizedBox(width: 8)],
      Expanded(child: Text(text, style: t.labelLarge?.copyWith(color: du.inkSecondary))),
    ]);
  }
}

/// The fact line under a title: an icon, a sentence in the title's second size, and at the right the number that
/// matters most, in accent.
class FactLine extends StatelessWidget {
  const FactLine(this.text, {super.key, this.icon, this.trailing, this.good = false});
  final String text;
  final IconData? icon;
  final String? trailing;
  /// The line itself in accent: something done, something earned.
  final bool good;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Row(children: [
      if (icon != null) ...[Icon(icon, size: 16, color: good ? du.accentText : du.inkSecondary), const SizedBox(width: 8)],
      Expanded(child: Text(text, style: t.titleMedium?.copyWith(color: good ? du.accentText : null))),
      if (trailing != null) ...[
        const SizedBox(width: 12),
        Text(trailing!, style: t.titleMedium?.copyWith(color: du.accentText, fontWeight: FontWeight.w600)),
      ],
    ]);
  }
}

/// A small fact: an icon and a few words. A row of them sits under a tile's title.
class Fact extends StatelessWidget {
  const Fact(this.text, {super.key, this.icon, this.accent = false});
  final String text;
  final IconData? icon;
  final bool accent;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: 13, color: accent ? du.accentText : du.inkTertiary), const SizedBox(width: 5)],
      Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelSmall?.copyWith(letterSpacing: 0, color: accent ? du.accentText : du.inkSecondary))),
    ]);
  }
}

/// A row of facts that wraps.
class Facts extends StatelessWidget {
  const Facts(this.facts, {super.key});
  final List<Widget> facts;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 14, runSpacing: 4, children: facts);
}

/// The one quiet line worth saying under a section: a small icon and a sentence in secondary ink.
class QuietLine extends StatelessWidget {
  const QuietLine(this.text, {super.key, this.icon, this.accent = false});
  final String text;
  final IconData? icon;
  final bool accent;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (icon != null) ...[Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 14, color: accent ? du.accentText : du.inkTertiary)), const SizedBox(width: 6)],
      Expanded(child: Text(text, style: t.bodySmall?.copyWith(color: accent ? du.accentText : null))),
    ]);
  }
}

/// A step's number in a small tinted circle.
class StepNumber extends StatelessWidget {
  const StepNumber(this.n, {super.key, this.size = 24});
  final int n;
  final double size;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Container(
      width: size, height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: du.accentSubtle, shape: BoxShape.circle, border: Border.all(color: du.accentLine, width: 0.6)),
      child: Text('$n', style: (size < 24 ? t.labelSmall : t.labelMedium)?.copyWith(color: du.accentText, letterSpacing: 0)),
    );
  }
}

/// A how-to as numbered steps: the text split at its sentences, one step each, under a "How to do it" header.
class HowToSteps extends StatelessWidget {
  const HowToSteps(this.text, {super.key, this.header = 'How to do it'});
  final String text;
  final String? header;

  static List<String> split(String text) =>
      text.trim().split(RegExp(r'(?<=[.!?])\s+(?=[A-Z])')).map((x) => x.trim()).where((x) => x.isNotEmpty).toList();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final steps = split(text);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (header != null) ...[Subhead(header!, icon: LucideIcons.bookOpen), const SizedBox(height: 12)],
      for (var i = 0; i < steps.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            StepNumber(i + 1),
            const SizedBox(width: 12),
            Expanded(child: Padding(padding: const EdgeInsets.only(top: 2), child: Text(steps[i], style: t.bodyMedium))),
          ]),
        ),
    ]);
  }
}

/// An accordion of things to do: the moves of a warm-up or a stretch with their times, or the cardio a place offers
/// with what it needs. Tapping a row opens how to do it, as short numbered steps, and closes whichever was open.
class MoveList extends StatefulWidget {
  const MoveList(this.rows, {super.key, required this.icon});
  final List<({String name, String detail, String how})> rows;
  final IconData icon;
  @override
  State<MoveList> createState() => _MoveListState();
}

class _MoveListState extends State<MoveList> {
  int? _open;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Panel(padding: EdgeInsets.zero, child: Column(children: [
      for (var i = 0; i < widget.rows.length; i++) ...[
        if (i > 0) const Divider(height: 1),
        InkWell(
          onTap: widget.rows[i].how.isEmpty ? null : () { HapticFeedback.selectionClick(); setState(() => _open = _open == i ? null : i); },
          child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 12, 12), child: Row(children: [
            Icon(widget.icon, size: 18, color: _open == i ? du.accentText : du.inkTertiary),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.rows[i].name, style: t.bodyLarge),
              Text(widget.rows[i].detail, style: t.bodySmall),
            ])),
            if (widget.rows[i].how.isNotEmpty)
              AnimatedRotation(
                turns: _open == i ? 0.5 : 0,
                duration: m(context, durBase),
                child: Icon(LucideIcons.chevronDown, size: 18, color: du.inkSecondary),
              ),
          ])),
        ),
        AnimatedSize(
          duration: m(context, durSlow),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: _open != i
              ? const SizedBox(width: double.infinity)
              : Padding(padding: const EdgeInsets.fromLTRB(15, 0, 16, 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final (k, step) in HowToSteps.split(widget.rows[i].how).indexed)
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      StepNumber(k + 1, size: 20),
                      const SizedBox(width: 13),
                      Expanded(child: Text(step, style: t.bodyMedium?.copyWith(color: du.inkSecondary))),
                    ])),
                ])),
        ),
      ],
    ]));
  }
}

/// What a cardio option needs, in words: "No equipment", or "Needs a rower".
String cardioNeeds(Cardio c) {
  if (c.needs == null) return 'No equipment';
  final thing = (equipment[c.needs] ?? c.needs!).toLowerCase();
  return 'Needs ${'aeiou'.contains(thing[0]) ? 'an' : 'a'} $thing';
}

/// A routine's moves as rows for a [MoveList].
List<({String name, String detail, String how})> routineRows(Routine r) => [for (final mv in r.moves) (name: mv.n, detail: '${mv.seconds} seconds', how: mv.how)];

/// The workout as the strip will show it: a thin block for every set and every timed part, all the same width, sets
/// of one exercise 2 px apart and parts 7 px apart. Sets in the accent line, timed parts in the plain one.
class PlanStrip extends StatelessWidget {
  const PlanStrip(this.blocks, {super.key, this.height = 8});
  /// Each block's item key and whether it is a set.
  final List<({String item, bool set})> blocks;
  final double height;
  @override
  Widget build(BuildContext context) {
    final du = context.du;
    if (blocks.isEmpty) return SizedBox(height: height);
    return LayoutBuilder(builder: (context, c) {
      double gapAfter(int i) => i == blocks.length - 1 ? 0 : blocks[i].item == blocks[i + 1].item ? 2 : 7;
      var gaps = 0.0;
      for (var i = 0; i < blocks.length; i++) { gaps += gapAfter(i); }
      final unit = ((c.maxWidth - gaps) / blocks.length).clamp(1.0, c.maxWidth);
      return SizedBox(height: height, child: Row(children: [
        for (var i = 0; i < blocks.length; i++) ...[
          Container(width: unit, height: height, decoration: BoxDecoration(color: blocks[i].set ? du.accentLine : du.line, borderRadius: BorderRadius.circular(height / 2))),
          if (gapAfter(i) > 0) SizedBox(width: gapAfter(i)),
        ],
      ]));
    });
  }
}

/// A round tinted icon.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.size = 40, this.accent = false});
  final IconData icon;
  final double size;
  final bool accent;
  @override
  Widget build(BuildContext context) {
    final du = context.du;
    return AnimatedContainer(
      duration: m(context, durBase),
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: accent ? du.accentSubtle : du.sunk, border: Border.all(color: accent ? du.accentLine : du.line, width: 0.6)),
      child: Icon(icon, size: size * 0.5, color: accent ? du.accentText : du.inkSecondary),
    );
  }
}

/// One of a few: a card with an icon, a title, a blurb, and a selected ring. Tap to pick.
class OptionCard extends StatelessWidget {
  const OptionCard({super.key, required this.icon, required this.title, this.blurb, this.detail, required this.selected, required this.onTap, this.trailing});
  final IconData icon;
  final String title;
  final String? blurb;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: m(context, durBase),
        curve: easeOut,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: selected ? du.accentSubtle : du.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? du.accentStrong : du.line, width: selected ? 1.5 : 0.6),
        ),
        child: Row(children: [
          IconBadge(icon, accent: selected),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleMedium),
            if (blurb != null) Text(blurb!, style: t.bodySmall),
            if (detail != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(detail!, style: t.labelSmall)),
          ])),
          const SizedBox(width: 8),
          trailing ?? AnimatedSwitcher(
            duration: m(context, durBase),
            child: Icon(selected ? LucideIcons.circleCheck : LucideIcons.circle, key: ValueKey(selected), size: 22, color: selected ? du.accentStrong : du.line),
          ),
        ]),
      ),
    );
  }
}

/// A handful of discrete values as chips. The shape for 1 to 6 of anything.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({super.key, required this.value, required this.options, required this.onChanged, this.label, this.hint, this.icons});
  final T value;
  final Map<T, String> options;
  final Map<T, IconData>? icons;
  final ValueChanged<T> onChanged;
  final String? label;
  final String? hint;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (label != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(label!, style: t.bodyLarge)),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in options.entries)
            Pressable(
              borderRadius: 999,
              onTap: () { HapticFeedback.selectionClick(); onChanged(e.key); },
              child: AnimatedContainer(
                duration: m(context, durBase),
                curve: easeOut,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: e.key == value ? du.accentSubtle : du.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: e.key == value ? du.accentStrong : du.line, width: e.key == value ? 1.5 : 0.6),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (icons?[e.key] != null) Padding(padding: const EdgeInsets.only(right: 6), child: Icon(icons![e.key], size: 16, color: e.key == value ? du.accentText : du.inkSecondary)),
                  Text(e.value, style: t.labelLarge?.copyWith(color: e.key == value ? du.accentText : du.ink)),
                ]),
              ),
            ),
        ]),
        if (hint != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(hint!, style: t.bodySmall)),
      ]),
    );
  }
}

/// A continuous number with a readout: minutes, days.
class ValueSlider extends StatelessWidget {
  const ValueSlider({super.key, required this.value, required this.min, required this.max, required this.onChanged, this.label, this.unit = '', this.step = 1, this.hint, this.display, this.icon});
  final int value;
  final int min;
  final int max;
  final int step;
  final String? label;
  final String unit;
  final String? hint;
  final IconData? icon;
  final String Function(int)? display;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final text = display?.call(value) ?? '$value$unit';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (icon != null) Padding(padding: const EdgeInsets.only(right: 8), child: Icon(icon, size: 18, color: du.inkSecondary)),
          if (label != null) Expanded(child: Text(label!, style: t.bodyLarge)),
          const SizedBox(width: 12),
          AnimatedSwitcher(
            duration: m(context, durFast),
            transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
            child: Text(text, key: ValueKey(text), style: t.titleMedium?.copyWith(color: du.accentText)),
          ),
        ]),
        Slider(
          value: value.toDouble(), min: min.toDouble(), max: max.toDouble(), divisions: (max - min) ~/ step,
          label: text, semanticFormatterCallback: (v) => display?.call(v.round()) ?? '${v.round()}$unit',
          onChanged: (v) => onChanged(((v / step).round() * step).clamp(min, max)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(display?.call(min) ?? '$min$unit', style: t.labelSmall),
            Text(display?.call(max) ?? '$max$unit', style: t.labelSmall),
          ]),
        ),
        if (hint != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(hint!, style: t.bodySmall)),
      ]),
    );
  }
}

/// A range of reps as one band with two thumbs: the shape of "8 to 12".
class RangeBand extends StatelessWidget {
  const RangeBand({super.key, required this.label, required this.value, required this.onChanged, this.min = 1, this.max = 30, this.unit = 'reps', this.hint});
  final String label;
  final RepRange value;
  final int min;
  final int max;
  final String unit;
  final String? hint;
  final ValueChanged<RepRange> onChanged;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final lo = value.lo.clamp(min, max - 1), hi = value.hi.clamp(lo + 1, max);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: t.bodyLarge)),
          Text('$lo to $hi $unit', style: t.titleMedium?.copyWith(color: du.accentText)),
        ]),
        RangeSlider(
          values: RangeValues(lo.toDouble(), hi.toDouble()), min: min.toDouble(), max: max.toDouble(), divisions: max - min,
          labels: RangeLabels('$lo', '$hi'),
          onChanged: (v) {
            var a = v.start.round(), b = v.end.round();
            if (b <= a) { if (a == lo) { b = a + 1; } else { a = b - 1; } }
            onChanged(RepRange(a.clamp(min, max - 1), b.clamp(a + 1, max)));
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('$min', style: t.labelSmall),
            Text(_band(lo, hi), style: t.labelSmall),
            Text('$max', style: t.labelSmall),
          ]),
        ),
        if (hint != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(hint!, style: t.bodySmall)),
      ]),
    );
  }

  String _band(int lo, int hi) {
    if (unit != 'reps') return '';
    if (hi <= 6) return 'strength';
    if (lo >= 12) return 'endurance';
    if (lo >= 8 || hi >= 12) return 'muscle';
    return 'strength and muscle';
  }
}

/// A number with its name over it, in sentence case. A few of these make a row.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.icon, this.hint});
  final String label;
  final String value;
  final String? hint;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        if (icon != null) Padding(padding: const EdgeInsets.only(right: 5), child: Icon(icon, size: 13, color: du.inkTertiary)),
        Flexible(child: Text(label, style: t.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
      const SizedBox(height: 4),
      Text(value, style: t.titleLarge),
      if (hint != null) Text(hint!, style: t.bodySmall),
    ]);
  }
}

/// The three energy answers as tiles with battery icons.
class EnergyPicker extends StatelessWidget {
  const EnergyPicker({super.key, required this.value, required this.onChanged});
  final Energy value;
  final ValueChanged<Energy> onChanged;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Row(children: [
      for (final e in Energy.values) ...[
        Expanded(child: Pressable(
          onTap: () => onChanged(e),
          borderRadius: 12,
          child: AnimatedContainer(
            duration: m(context, durBase),
            curve: easeOut,
            height: 72,
            decoration: BoxDecoration(
              color: e == value ? du.accentSubtle : du.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: e == value ? du.accentStrong : du.line, width: e == value ? 1.5 : 0.6),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(energyIcon(e), size: 22, color: e == value ? du.accentText : du.inkSecondary),
              const SizedBox(height: 4),
              Text(energyLabel[e]!, style: t.labelLarge?.copyWith(color: e == value ? du.accentText : du.ink)),
            ]),
          ),
        )),
        if (e != Energy.hard) const SizedBox(width: 8),
      ],
    ]);
  }
}

/// A vertical ladder: every rung as a dot on a track, reached ones filled, the current one ringed. [marked] is a second
/// rung to point out, with [markedWord] beside it: today's level while the saved one stays "you".
class LadderTrack extends StatelessWidget {
  const LadderTrack({super.key, required this.rungs, this.onUse, this.marked, this.markedWord = 'today', this.currentWord = 'you'});
  final List<({int rung, String label, String? note, bool current, bool reached})> rungs;
  final void Function(int rung)? onUse;
  final int? marked;
  final String markedWord;
  final String currentWord;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Column(children: [
      for (var i = rungs.length - 1; i >= 0; i--) ...[
        Builder(builder: (context) {
          final r = rungs[i];
          final top = i == rungs.length - 1, bottom = i == 0;
          final isMarked = marked != null && r.rung == marked;
          final word = isMarked && !r.current ? markedWord : r.current ? (marked == null || isMarked ? currentWord : currentWord) : null;
          return Pressable(
            onTap: onUse == null || (isMarked || (marked == null && r.current)) ? null : () { HapticFeedback.selectionClick(); onUse!(r.rung); },
            child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(width: 36, child: Column(children: [
                Expanded(child: Container(width: 2, color: top ? Colors.transparent : (r.reached ? du.accentLine : du.line))),
                AnimatedContainer(
                  duration: m(context, durBase),
                  width: r.current || isMarked ? 18 : 12, height: r.current || isMarked ? 18 : 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: r.current ? du.accentStrong : isMarked ? du.surface : r.reached ? du.accentLine : du.surface,
                    border: Border.all(color: r.current || isMarked ? du.accentStrong : r.reached ? du.accentLine : du.line, width: r.current || isMarked ? 3 : 1),
                  ),
                ),
                Expanded(child: Container(width: 2, color: bottom ? Colors.transparent : (r.reached ? du.accentLine : du.line))),
              ])),
              Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.label, style: r.current || isMarked ? t.titleMedium?.copyWith(color: du.accentText) : t.bodyMedium?.copyWith(color: r.reached ? du.ink : du.inkSecondary)),
                  if (r.note != null) Text(r.note!, style: t.bodySmall),
                ]),
              )),
              if (word != null)
                Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: Text(word, style: t.labelSmall?.copyWith(color: du.accentText))))
              else if (onUse != null)
                Padding(padding: const EdgeInsets.only(right: 4), child: Center(child: Icon(LucideIcons.chevronRight, size: 16, color: du.inkTertiary))),
            ])),
          );
        }),
      ],
    ]);
  }
}

/// A bar that fills to a fraction, animated.
class Meter extends StatelessWidget {
  const Meter(this.fraction, {super.key, this.height = 6});
  final double fraction;
  final double height;
  @override
  Widget build(BuildContext context) {
    final du = context.du;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height, color: du.sunk,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: fraction.clamp(0, 1)),
          duration: m(context, durSlow),
          curve: easeSettle,
          builder: (context, v, _) => Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: v, child: Container(color: du.accentStrong))),
        ),
      ),
    );
  }
}

/// Inline info line for a term the user may not know.
class Explain extends StatelessWidget {
  const Explain(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 3, right: 6), child: Icon(LucideIcons.info, size: 14, color: du.inkTertiary)),
        Expanded(child: Text(text, style: t.bodySmall)),
      ]),
    );
  }
}

String minutesLabel(int v) => '$v min';

/// Today's work against the usual, as three bars: one lighter, two usual, three more. Relative, never a class.
class UsualMeter extends StatelessWidget {
  const UsualMeter(this.relative, {super.key, this.size = 6});
  final double relative;
  final double size;
  @override
  Widget build(BuildContext context) {
    final du = context.du;
    final filled = relative < 0.95 ? 1 : relative > 1.05 ? 3 : 2;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= 3; i++)
        Container(width: size * 1.6, height: size * (0.6 + 0.4 * i), margin: EdgeInsets.only(right: size * 0.4),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: i <= filled ? du.accentStrong : du.line)),
    ]);
  }
}

/// A small word in a pill beside a title: "next level", "new", "forced". Accent when it is good news.
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.accent = false});
  final String text;
  final bool accent;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: accent ? du.accentSubtle : du.sunk, borderRadius: BorderRadius.circular(999), border: Border.all(color: accent ? du.accentLine : du.line, width: 0.6)),
      child: Text(text, style: t.labelSmall?.copyWith(color: accent ? du.accentText : du.inkSecondary, letterSpacing: 0)),
    );
  }
}

/// A row in a list panel: a small icon, a title, one line under it, and at the right a value and a chevron. The one
/// row shape the plan, the settings and the catalog share.
class Row1 extends StatelessWidget {
  const Row1({super.key, this.icon, required this.title, this.subtitle, this.value, this.tags = const [], this.onTap, this.chevron = true, this.trailing, this.dense = false, this.muted = false});
  final IconData? icon;
  final Widget title;
  final String? subtitle;
  final String? value;
  final List<Widget> tags;
  final VoidCallback? onTap;
  final bool chevron;
  final Widget? trailing;
  final bool dense;
  final bool muted;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final body = Padding(
      padding: EdgeInsets.fromLTRB(16, dense ? 10 : 13, 12, dense ? 10 : 13),
      child: Row(children: [
        if (icon != null) ...[Icon(icon, size: 18, color: muted ? du.inkTertiary : du.inkSecondary), const SizedBox(width: 14)],
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: DefaultTextStyle(style: t.bodyLarge!.copyWith(color: muted ? du.inkSecondary : du.ink), child: title)),
            for (final tag in tags) ...[const SizedBox(width: 6), tag],
          ]),
          if (subtitle != null) Text(subtitle!, style: t.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
        ])),
        if (value != null) ...[const SizedBox(width: 12), Text(value!, style: t.bodySmall?.copyWith(color: du.inkSecondary))],
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        if (chevron && onTap != null) ...[const SizedBox(width: 4), Icon(LucideIcons.chevronRight, size: 18, color: du.inkTertiary)],
      ]),
    );
    if (onTap == null) return body;
    return InkWell(onTap: () { HapticFeedback.selectionClick(); onTap!(); }, child: body);
  }
}

/// A calibration as one band with three thumbs: the fewest, the ideal, the most. Grab any thumb and it follows the
/// finger; the ideal pushes the others along. A tap on the track brings the nearest thumb. While dragging, a line says
/// what that thumb means.
class TriBand extends StatefulWidget {
  const TriBand({super.key, required this.label, required this.value, required this.min, required this.max, required this.onChanged, this.icon, this.unit = '', this.hints, this.display});
  final String label;
  final Tri value;
  final int min;
  final int max;
  final IconData? icon;
  final String unit;
  final ValueChanged<Tri> onChanged;
  /// What each thumb means, shown while dragging it.
  final ({String min, String ideal, String max})? hints;
  final String Function(int)? display;
  @override
  State<TriBand> createState() => _TriBandState();
}

class _TriBandState extends State<TriBand> {
  int? active;        // 0 min, 1 ideal, 2 max
  double? dragValue;  // the active thumb's continuous value while dragging
  double grab = 0;    // finger to thumb offset in value units, so a grabbed thumb never jumps
  static const _pad = 16.0;

  String _d(int v) => widget.display?.call(v) ?? '$v${widget.unit}';
  double get _span => (widget.max - widget.min).toDouble();
  double _x(double v, double w) => _pad + (v - widget.min) / _span * (w - 2 * _pad);
  double _v(double x, double w) => (widget.min + (x - _pad) / (w - 2 * _pad) * _span).clamp(widget.min.toDouble(), widget.max.toDouble());

  void _start(double x, double w) {
    final t = widget.value;
    final xs = [_x(t.min.toDouble(), w), _x(t.ideal.toDouble(), w), _x(t.max.toDouble(), w)];
    var best = 1;
    var bestD = (xs[1] - x).abs();
    for (final i in [0, 2]) {
      final d = (xs[i] - x).abs();
      if (d < bestD - 0.5) { best = i; bestD = d; }
    }
    if (t.min == t.ideal && best == 0 && x > xs[0]) best = 1;
    if (t.max == t.ideal && best == 2 && x < xs[2]) best = 1;
    // grabbed: keep the offset; tapped elsewhere on the track: the thumb comes to the finger
    grab = bestD <= 28 ? _v(xs[best], w) - _v(x, w) : 0;
    setState(() { active = best; dragValue = _v(x, w) + grab; });
    _commit();
  }

  void _move(double x, double w) {
    setState(() => dragValue = (_v(x, w) + grab).clamp(widget.min.toDouble(), widget.max.toDouble()));
    _commit();
  }

  void _commit() {
    final v = dragValue!.round();
    final t = widget.value;
    final next = switch (active) { 0 => t.withMin(v), 2 => t.withMax(v), _ => t.withIdeal(v) };
    if (next != t) { HapticFeedback.selectionClick(); widget.onChanged(next); }
  }

  void _end() => setState(() { active = null; dragValue = null; });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final v = widget.value;
    final hints = widget.hints ?? (min: 'never fewer than this', ideal: 'the sweet spot', max: 'only on long workouts and hard days');
    final hint = switch (active) { 0 => 'At least ${_d(v.min)}: ${hints.min}.', 2 => 'Up to ${_d(v.max)}: ${hints.max}.', 1 => 'Ideally ${_d(v.ideal)}: ${hints.ideal}.', _ => null };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (widget.icon != null) Padding(padding: const EdgeInsets.only(right: 8), child: Icon(widget.icon, size: 18, color: du.inkSecondary)),
          Expanded(child: Text(widget.label, style: t.bodyLarge)),
          const SizedBox(width: 12),
          AnimatedSwitcher(
            duration: m(context, durFast),
            transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
            child: Text('${v.min} · ${v.ideal} · ${v.max}', key: ValueKey('${v.min}${v.ideal}${v.max}'), style: t.titleMedium?.copyWith(color: du.accentText)),
          ),
        ]),
        LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          final vals = [v.min.toDouble(), v.ideal.toDouble(), v.max.toDouble()];
          if (active != null && dragValue != null) {
            vals[active!] = dragValue!;
            if (active == 1) { if (vals[0] > vals[1]) vals[0] = vals[1]; if (vals[2] < vals[1]) vals[2] = vals[1]; }
            if (active == 0 && vals[1] < vals[0]) { vals[1] = vals[0]; if (vals[2] < vals[0]) vals[2] = vals[0]; }
            if (active == 2 && vals[1] > vals[2]) { vals[1] = vals[2]; if (vals[0] > vals[2]) vals[0] = vals[2]; }
          }
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onHorizontalDragStart: (d) => _start(d.localPosition.dx, w),
            onHorizontalDragUpdate: (d) => _move(d.localPosition.dx, w),
            onHorizontalDragEnd: (_) => _end(),
            onHorizontalDragCancel: _end,
            onTapDown: (d) => _start(d.localPosition.dx, w),
            onTapUp: (_) => _end(),
            onTapCancel: _end,
            child: SizedBox(
              height: 48,
              width: double.infinity,
              child: TweenAnimationBuilder<double>(
                // smooth the thumbs into place after a snap; while dragging the active one follows the finger exactly
                tween: Tween(end: vals[0] * 10000 + vals[1] * 100 + vals[2] / 10),
                duration: m(context, active == null ? durBase : Duration.zero),
                curve: easeOut,
                builder: (context, packed, _) {
                  final a = (packed / 10000).floorToDouble(), rem = packed - a * 10000;
                  final b = (rem / 100).floorToDouble(), cc = (rem - b * 100) * 10;
                  final draw = active != null ? vals : [a, b, cc];
                  return CustomPaint(painter: _TriPainter(
                    xMin: _x(draw[0], w), xIdeal: _x(draw[1], w), xMax: _x(draw[2], w), x0: _pad, x1: w - _pad,
                    line: du.line, fill: du.accentLine, strong: du.accentStrong, surface: du.surface, active: active,
                  ));
                },
              ),
            ),
          );
        }),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('at least ${_d(v.min)}', style: t.labelSmall?.copyWith(color: active == 0 ? du.accentText : null)),
            Text('ideally ${_d(v.ideal)}', style: t.labelSmall?.copyWith(color: active == 1 ? du.accentText : null)),
            Text('up to ${_d(v.max)}', style: t.labelSmall?.copyWith(color: active == 2 ? du.accentText : null)),
          ]),
        ),
        AnimatedSize(
          duration: m(context, durBase),
          curve: easeOut,
          alignment: Alignment.topLeft,
          child: hint == null ? const SizedBox(width: double.infinity) : Padding(padding: const EdgeInsets.only(top: 6), child: Text(hint, style: t.bodySmall?.copyWith(color: du.accentText))),
        ),
      ]),
    );
  }
}

class _TriPainter extends CustomPainter {
  _TriPainter({required this.xMin, required this.xIdeal, required this.xMax, required this.x0, required this.x1, required this.line, required this.fill, required this.strong, required this.surface, this.active});
  final double xMin, xIdeal, xMax, x0, x1;
  final Color line, fill, strong, surface;
  final int? active;
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final track = Paint()..color = line..strokeWidth = 6..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x0, y), Offset(x1, y), track);
    final band = Paint()..color = fill..strokeWidth = 6..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(xMin, y), Offset(xMax, y), band);
    void thumb(double x, double r, bool big, bool on) {
      if (on) canvas.drawCircle(Offset(x, y), r + 10, Paint()..color = strong.withValues(alpha: 0.14));
      canvas.drawCircle(Offset(x, y), r, Paint()..color = big ? strong : surface);
      if (!big) canvas.drawCircle(Offset(x, y), r, Paint()..color = strong..style = PaintingStyle.stroke..strokeWidth = 2.5);
    }
    thumb(xMin, 8, false, active == 0);
    thumb(xMax, 8, false, active == 2);
    thumb(xIdeal, 11, true, active == 1);
  }
  @override
  bool shouldRepaint(_TriPainter o) => o.xMin != xMin || o.xIdeal != xIdeal || o.xMax != xMax || o.active != active || o.x1 != x1;
}
