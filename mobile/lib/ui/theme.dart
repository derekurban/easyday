// Design-system tokens (derekurban/design-system v0.1.0) as a Flutter theme: neutral surfaces, one green accent,
// hairline rings instead of borders, Albert Sans for titles and Wix Madefor Text for everything else.
import 'package:flutter/material.dart';

class Du extends ThemeExtension<Du> {
  const Du({
    required this.bg, required this.surface, required this.sunk, required this.line, required this.ink, required this.inkSecondary,
    required this.inkTertiary, required this.accentStrong, required this.accentText, required this.accentSubtle, required this.accentLine,
    required this.onAccent,
  });
  final Color bg, surface, sunk, line, ink, inkSecondary, inkTertiary, accentStrong, accentText, accentSubtle, accentLine, onAccent;

  static const light = Du(
    bg: Color(0xFFF6F6F6), surface: Color(0xFFFCFCFC), sunk: Color(0xFFEDEDED), line: Color(0xFFD4D4D4),
    ink: Color(0xFF1B1B1B), inkSecondary: Color(0xFF555555), inkTertiary: Color(0xFF696969),
    accentStrong: Color(0xFF456938), accentText: Color(0xFF426635), accentSubtle: Color(0xFFE6F3E2), accentLine: Color(0xFFAEC6A6), onAccent: Color(0xFFFAFAFA),
  );
  static const dark = Du(
    bg: Color(0xFF141414), surface: Color(0xFF1C1C1C), sunk: Color(0xFF080808), line: Color(0xFF383838),
    ink: Color(0xFFEEEEEE), inkSecondary: Color(0xFF9E9E9E), inkTertiary: Color(0xFF909090),
    accentStrong: Color(0xFF86AB7A), accentText: Color(0xFF87A87C), accentSubtle: Color(0xFF1E281A), accentLine: Color(0xFF394A34), onAccent: Color(0xFF1B1B1B),
  );

  @override
  Du copyWith() => this;
  @override
  Du lerp(Du? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension DuContext on BuildContext {
  Du get du => Theme.of(this).extension<Du>()!;
}

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
    headlineLarge: TextStyle(fontFamily: titleFont, fontSize: 40, height: 1.1, fontWeight: FontWeight.w500, letterSpacing: -1.1, color: du.ink),
    headlineMedium: TextStyle(fontFamily: titleFont, fontSize: 24, height: 1.25, fontWeight: FontWeight.w500, letterSpacing: -0.4, color: du.ink),
    titleLarge: TextStyle(fontFamily: titleFont, fontSize: 18, height: 1.33, fontWeight: FontWeight.w500, letterSpacing: -0.2, color: du.ink),
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
    cardTheme: CardThemeData(color: du.surface, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: hairline)),
    dividerTheme: DividerThemeData(color: du.line, thickness: 0.6, space: 0.6),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        backgroundColor: du.accentStrong, foregroundColor: du.onAccent, minimumSize: const Size(64, 52), textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        foregroundColor: du.ink, side: hairline, minimumSize: const Size(64, 52), textStyle: text.labelLarge, backgroundColor: du.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: du.accentText, textStyle: text.labelLarge, minimumSize: const Size(44, 44))),
    segmentedButtonTheme: SegmentedButtonThemeData(style: ButtonStyle(
      side: WidgetStatePropertyAll(hairline),
      backgroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? du.accentSubtle : du.surface),
      foregroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? du.accentText : du.ink),
      textStyle: WidgetStatePropertyAll(text.labelLarge), visualDensity: VisualDensity.standard,
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10, vertical: 14)),
    )),
    chipTheme: ChipThemeData(backgroundColor: du.surface, selectedColor: du.accentSubtle, side: hairline, labelStyle: text.labelMedium?.copyWith(color: du.ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), showCheckmark: false),
    listTileTheme: ListTileThemeData(contentPadding: const EdgeInsets.symmetric(horizontal: 16), titleTextStyle: text.bodyLarge, subtitleTextStyle: text.bodySmall, iconColor: du.inkSecondary),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: du.surface, surfaceTintColor: Colors.transparent, showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20)))),
    navigationBarTheme: NavigationBarThemeData(backgroundColor: du.surface, indicatorColor: du.accentSubtle, elevation: 0, height: 68,
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium), iconTheme: WidgetStateProperty.resolveWith((st) => IconThemeData(color: st.contains(WidgetState.selected) ? du.accentText : du.inkSecondary, size: 22))),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: du.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: hairline),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: hairline),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: du.accentLine, width: 2))),
    sliderTheme: SliderThemeData(
      activeTrackColor: du.accentStrong, inactiveTrackColor: du.sunk, thumbColor: du.accentStrong, overlayColor: du.accentSubtle,
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
    iconTheme: IconThemeData(color: du.inkSecondary, size: 22),
  );
}

/// A resting card: surface, hairline ring, soft lift.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.sunk = false});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool sunk;
  @override
  Widget build(BuildContext context) {
    final du = context.du;
    final box = Container(
      decoration: BoxDecoration(
        color: sunk ? du.sunk : du.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: du.line, width: 0.6),
        boxShadow: sunk ? null : const [BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)), BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) return box;
    return Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(14), onTap: onTap, child: box));
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
