// The app's theme since the makeover (2026-11-16): a warm white page with white cards, or true black with near-black
// cards. Ink is the accent: links, selected things and marks are plain. The only colour is the sun (the one filled
// button, the muscles a workout works, the workout pictures) and the sky at the top of Today (sky.dart). Cards are
// round and have no ring, titles are heavy Albert Sans, everything else is Wix Madefor Text. Before the makeover the
// tokens were derekurban/design-system v0.1.0: true greys, a moss green accent, hairline rings.
import 'package:flutter/material.dart';

class Du extends ThemeExtension<Du> {
  const Du({
    required this.bg, required this.surface, required this.sunk, required this.line, required this.ink, required this.inkSecondary,
    required this.inkTertiary, required this.accentStrong, required this.accentText, required this.accentSubtle, required this.accentLine,
    required this.onAccent, required this.warning, required this.warningSubtle, required this.warningLine,
    required this.art, required this.artSoft, required this.artFaint, required this.segmentOn, required this.cardShadow,
  });
  final Color bg, surface, sunk, line, ink, inkSecondary, inkTertiary, accentStrong, accentText, accentSubtle, accentLine, onAccent;
  /// The workout pictures (stage_art.dart): the sun's orange, a softer and a faint tone of it.
  final Color art, artSoft, artFaint;
  /// The chosen segment of a segmented control, raised from its track.
  final Color segmentOn;
  /// What lifts a card off the page: a warm soft shadow in the light theme, nothing on black.
  final List<BoxShadow> cardShadow;
  /// The warning status: text and fill, a tinted surface, and its ring. Only for status, never decoration.
  final Color warning, warningSubtle, warningLine;

  static const light = Du(
    bg: Color(0xFFFBF8F3), surface: Color(0xFFFFFFFF), sunk: Color(0xFFF1EBE2), line: Color(0xFFE9E1D6),
    ink: Color(0xFF14110F), inkSecondary: Color(0xFF6B6058), inkTertiary: Color(0xFF7D7269),
    accentStrong: Color(0xFF14110F), accentText: Color(0xFF14110F), accentSubtle: Color(0xFFF3EEE7), accentLine: Color(0xFFD6CCBF), onAccent: Color(0xFFFFFFFF),
    warning: Color(0xFF8B590E), warningSubtle: Color(0xFFFCEDDE), warningLine: Color(0xFFDEB990),
    art: Color(0xFFEE8A45), artSoft: Color(0xFFF3C7A5), artFaint: Color(0xFFFBEADB), segmentOn: Color(0xFFFFFFFF),
    cardShadow: [BoxShadow(color: Color(0x0D503214), blurRadius: 2, offset: Offset(0, 1)), BoxShadow(color: Color(0x12503214), blurRadius: 16, offset: Offset(0, 6))],
  );
  static const dark = Du(
    bg: Color(0xFF000000), surface: Color(0xFF151416), sunk: Color(0xFF1E1D20), line: Color(0xFF2A282C),
    ink: Color(0xFFFFFFFF), inkSecondary: Color(0xFFA09CA3), inkTertiary: Color(0xFF8C8890),
    accentStrong: Color(0xFFFFFFFF), accentText: Color(0xFFFFFFFF), accentSubtle: Color(0xFF242326), accentLine: Color(0xFF3B393E), onAccent: Color(0xFF000000),
    warning: Color(0xFFC38B46), warningSubtle: Color(0xFF322210), warningLine: Color(0xFF5A4123),
    art: Color(0xFFF29450), artSoft: Color(0xFF6E4B33), artFaint: Color(0xFF2B2019), segmentOn: Color(0xFF2E2C30),
    cardShadow: [],
  );

  @override
  Du copyWith() => this;
  @override
  Du lerp(Du? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension DuContext on BuildContext {
  Du get du => Theme.of(this).extension<Du>()!;
}

/// The sun, top to bottom, and the ink that reads on it: the one filled button.
const sunGradient = [Color(0xFFFFE38C), Color(0xFFFDB582), Color(0xFFFB9A86)];
const onSun = Color(0xFF3A1A0C);
/// A card's corner, and a button's (a full pill at the heights the app uses).
const cardRadius = 24.0;
const buttonRadius = 28.0;

const titleFont = 'Albert Sans';
const bodyFont = 'Wix Madefor Text';

ThemeData buildTheme(Brightness b) {
  final du = b == Brightness.dark ? Du.dark : Du.light;
  final scheme = ColorScheme(
    brightness: b, primary: du.accentStrong, onPrimary: du.onAccent, secondary: du.accentText, onSecondary: du.onAccent,
    error: const Color(0xFFB3261E), onError: Colors.white, surface: du.surface, onSurface: du.ink,
    surfaceContainerHighest: du.sunk, outline: du.line, outlineVariant: du.line, primaryContainer: du.accentSubtle, onPrimaryContainer: du.accentText,
    onSurfaceVariant: du.inkSecondary, secondaryContainer: du.accentSubtle, onSecondaryContainer: du.accentText, tertiary: du.inkTertiary, onTertiary: du.bg,
  );
  final text = TextTheme(
    displayLarge: TextStyle(fontFamily: titleFont, fontSize: 56, height: 1.0, fontWeight: FontWeight.w300, letterSpacing: -1.8, color: du.ink),
    headlineLarge: TextStyle(fontFamily: titleFont, fontSize: 38, height: 1.1, fontWeight: FontWeight.w700, letterSpacing: -1.0, color: du.ink),
    headlineMedium: TextStyle(fontFamily: titleFont, fontSize: 24, height: 1.25, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: du.ink),
    titleLarge: TextStyle(fontFamily: titleFont, fontSize: 18, height: 1.33, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: du.ink),
    titleMedium: TextStyle(fontFamily: bodyFont, fontSize: 16, height: 1.4, fontWeight: FontWeight.w500, color: du.ink),
    bodyLarge: TextStyle(fontFamily: bodyFont, fontSize: 16, height: 1.5, fontWeight: FontWeight.w400, color: du.ink),
    bodyMedium: TextStyle(fontFamily: bodyFont, fontSize: 14, height: 1.5, fontWeight: FontWeight.w400, color: du.ink),
    bodySmall: TextStyle(fontFamily: bodyFont, fontSize: 13, height: 1.4, fontWeight: FontWeight.w400, color: du.inkSecondary),
    labelLarge: TextStyle(fontFamily: bodyFont, fontSize: 15, height: 1.2, fontWeight: FontWeight.w500, color: du.ink),
    labelMedium: TextStyle(fontFamily: bodyFont, fontSize: 13, height: 1.2, fontWeight: FontWeight.w500, color: du.inkSecondary),
    labelSmall: TextStyle(fontFamily: bodyFont, fontSize: 11, height: 1.2, fontWeight: FontWeight.w500, letterSpacing: 0.4, color: du.inkTertiary),
  );
  final hairline = BorderSide(color: du.line, width: 0.6);
  return ThemeData(
    useMaterial3: true, brightness: b, colorScheme: scheme, scaffoldBackgroundColor: du.bg, textTheme: text, fontFamily: bodyFont,
    extensions: [du], splashFactory: InkSparkle.splashFactory, visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(backgroundColor: du.bg, foregroundColor: du.ink, elevation: 0, scrolledUnderElevation: 0, centerTitle: false,
        titleTextStyle: text.headlineMedium),
    cardTheme: CardThemeData(color: du.surface, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius))),
    dividerTheme: DividerThemeData(color: du.line, thickness: 0.6, space: 0.6),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        backgroundColor: sunGradient.last, foregroundColor: onSun, disabledBackgroundColor: du.sunk, disabledForegroundColor: du.inkTertiary,
        minimumSize: const Size(64, 52), textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600), shadowColor: sunGradient.last,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius))).copyWith(
      // the sun is ink on the button's own material, so a press still ripples over it; a soft shadow in its colour by day
      elevation: WidgetStateProperty.resolveWith((st) => b == Brightness.dark || st.contains(WidgetState.disabled) ? 0 : st.contains(WidgetState.pressed) ? 1 : 3),
      backgroundBuilder: (context, states, child) => states.contains(WidgetState.disabled) ? child ?? const SizedBox.shrink()
          : Ink(decoration: BoxDecoration(borderRadius: BorderRadius.circular(buttonRadius),
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: sunGradient, stops: [0, 0.8, 1])), child: child),
    )),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        foregroundColor: du.ink, side: hairline, minimumSize: const Size(64, 52), textStyle: text.labelLarge, backgroundColor: du.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)))),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: du.accentText, textStyle: text.labelLarge, minimumSize: const Size(44, 44))),
    segmentedButtonTheme: SegmentedButtonThemeData(style: ButtonStyle(
      // a track with the chosen segment raised from it, no ring
      side: WidgetStatePropertyAll(BorderSide(color: du.sunk, width: 3)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      backgroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? du.segmentOn : du.sunk),
      foregroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? du.ink : du.inkSecondary),
      textStyle: WidgetStatePropertyAll(text.labelLarge), visualDensity: VisualDensity.standard,
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10, vertical: 14)),
    )),
    chipTheme: ChipThemeData(backgroundColor: du.surface, selectedColor: du.accentSubtle, side: hairline, labelStyle: text.labelMedium?.copyWith(color: du.ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), showCheckmark: false),
    listTileTheme: ListTileThemeData(contentPadding: const EdgeInsets.symmetric(horizontal: 16), titleTextStyle: text.bodyLarge, subtitleTextStyle: text.bodySmall, iconColor: du.inkSecondary),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: du.surface, surfaceTintColor: Colors.transparent, showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(buttonRadius)))),
    // the tab in use is told by its ink alone
    navigationBarTheme: NavigationBarThemeData(backgroundColor: du.surface, indicatorColor: Colors.transparent, elevation: 0, height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((st) => text.labelMedium?.copyWith(color: st.contains(WidgetState.selected) ? du.ink : du.inkSecondary, fontWeight: st.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500)),
        iconTheme: WidgetStateProperty.resolveWith((st) => IconThemeData(color: st.contains(WidgetState.selected) ? du.ink : du.inkSecondary, size: 22))),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: du.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: hairline),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: hairline),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: du.accentLine, width: 2))),
    sliderTheme: SliderThemeData(
      activeTrackColor: du.accentStrong, inactiveTrackColor: du.line, thumbColor: Colors.white, overlayColor: du.accentSubtle,
      trackHeight: 6, activeTickMarkColor: du.accentLine, inactiveTickMarkColor: du.line,
      valueIndicatorColor: du.ink, valueIndicatorTextStyle: text.labelLarge?.copyWith(color: du.bg), showValueIndicator: ShowValueIndicator.onDrag,
      rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 11), thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
      rangeTrackShape: const RoundedRectRangeSliderTrackShape(), trackShape: const RoundedRectSliderTrackShape(),
      rangeValueIndicatorShape: const PaddleRangeSliderValueIndicatorShape(), valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
    ),
    switchTheme: SwitchThemeData(thumbColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? du.onAccent : du.inkSecondary),
        trackColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? du.accentStrong : du.sunk), trackOutlineColor: WidgetStatePropertyAll(du.line)),
    snackBarTheme: SnackBarThemeData(backgroundColor: du.ink, contentTextStyle: text.bodyMedium?.copyWith(color: du.bg), behavior: SnackBarBehavior.floating),
    dialogTheme: DialogThemeData(backgroundColor: du.surface, surfaceTintColor: Colors.transparent, titleTextStyle: text.titleLarge, contentTextStyle: text.bodyMedium),
    // the birthday picker: the date in the main ink, not the grey Material gives its header
    datePickerTheme: DatePickerThemeData(backgroundColor: du.surface, surfaceTintColor: Colors.transparent, headerForegroundColor: du.ink,
        headerHelpStyle: text.labelMedium, headerHeadlineStyle: text.headlineLarge, dividerColor: du.line),
    iconTheme: IconThemeData(color: du.inkSecondary, size: 22),
  );
}

/// A resting card: surface, round corners, a soft lift by day. No ring.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.sunk = false, this.clip = false});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool sunk;
  final bool clip; // children stay inside the rounded corners
  @override
  Widget build(BuildContext context) {
    final du = context.du;
    final box = Container(
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: sunk ? du.sunk : du.surface,
        borderRadius: BorderRadius.circular(cardRadius),
        boxShadow: sunk ? null : du.cardShadow,
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) return box;
    return Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(cardRadius), onTap: onTap, child: box));
  }
}

/// Small uppercase label above a group.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
      );
}

/// Difficulty as a word in a small pill: easy, medium, hard. Hard is filled, medium tinted, easy plain.
class DifficultyTag extends StatelessWidget {
  const DifficultyTag(this.difficulty, {super.key, this.large = false});
  final int difficulty;
  final bool large;
  @override
  Widget build(BuildContext context) {
    final du = context.du;
    final t = Theme.of(context).textTheme;
    final d = difficulty.clamp(1, 3);
    final bg = d == 3 ? du.accentStrong : d == 2 ? du.accentSubtle : du.surface;
    final line = d == 3 ? du.accentStrong : d == 2 ? du.accentLine : du.line;
    final ink = d == 3 ? du.onAccent : d == 2 ? du.accentText : du.inkSecondary;
    const words = {1: 'easy', 2: 'medium', 3: 'hard'};
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 12 : 8, vertical: large ? 5 : 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: line, width: 0.6)),
      child: Text(words[d]!, style: (large ? t.labelLarge : t.labelSmall)?.copyWith(color: ink, letterSpacing: 0)),
    );
  }
}
