// Motion tokens from the design system: three durations, ease out on entry, exits quicker than entrances.
// Every duration goes through [m] so reduced-motion settings collapse them to zero.
import 'package:flutter/material.dart';

const durFast = Duration(milliseconds: 120);
const durBase = Duration(milliseconds: 200);
const durSlow = Duration(milliseconds: 320);
const durExit = Duration(milliseconds: 120);
const easeOut = Cubic(0.2, 0.8, 0.2, 1);
const easeInOut = Cubic(0.65, 0, 0.35, 1);
const easeSettle = Cubic(0.16, 1, 0.3, 1);
const pressScale = 0.96;

Duration m(BuildContext context, Duration d) => MediaQuery.maybeDisableAnimationsOf(context) == true ? Duration.zero : d;

/// Fade and rise in when first built, or whenever [key] changes.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.delay = Duration.zero, this.offset = 12});
  final Widget child;
  final Duration delay;
  final double offset;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        key: key,
        tween: Tween(begin: 0, end: 1),
        duration: m(context, durSlow + delay),
        curve: Interval(delay.inMilliseconds / (durSlow + delay).inMilliseconds, 1, curve: easeSettle),
        builder: (context, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * offset), child: child)),
        child: child,
      );
}

/// Scale in with a settle: for a check mark or a number that just changed.
class Pop extends StatelessWidget {
  const Pop({super.key, required this.child, this.from = 0.6});
  final Widget child;
  final double from;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        key: key,
        tween: Tween(begin: from, end: 1),
        duration: m(context, durSlow),
        curve: easeSettle,
        builder: (context, t, child) => Transform.scale(scale: t, child: Opacity(opacity: t.clamp(0, 1), child: child)),
        child: child,
      );
}

/// Shrinks slightly while pressed. Wrap any card or tile that acts as a button.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.borderRadius = 14});
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: widget.onTap == null ? null : (_) => setState(() => down = true),
        onTapUp: widget.onTap == null ? null : (_) => setState(() => down = false),
        onTapCancel: widget.onTap == null ? null : () => setState(() => down = false),
        onTap: widget.onTap,
        child: AnimatedScale(scale: down ? pressScale : 1, duration: m(context, durFast), curve: easeOut, child: widget.child),
      );
}

/// Cross-fades and slides between children keyed by [index]: onboarding pages, exercise pages.
class PageSwitcher extends StatelessWidget {
  const PageSwitcher({super.key, required this.index, required this.child, this.forward = true});
  final int index;
  final Widget child;
  final bool forward;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: m(context, durSlow),
        reverseDuration: m(context, durExit),
        switchInCurve: easeSettle,
        switchOutCurve: easeOut,
        layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(position: Tween(begin: Offset(forward ? 0.06 : -0.06, 0), end: Offset.zero).animate(anim), child: child),
        ),
        child: KeyedSubtree(key: ValueKey(index), child: child),
      );
}
