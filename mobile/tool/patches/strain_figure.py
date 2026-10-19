# The figure draws strain points: the design system's danger red at three fixed shades (MUSCLE_MAP.md).
import pathlib


def edit(path, pairs):
    p = pathlib.Path(path)
    t = p.read_bytes().decode().replace('\r\n', '\n')
    for old, new in pairs:
        assert t.count(old) == 1, (path, old[:90])
        t = t.replace(old, new)
    p.write_bytes(t.replace('\n', '\r\n').encode())


edit('lib/ui/muscle_figure.dart', [
    ("""// highlighted by their everyday names (data/index.dart `muscleNames`, each plate's `name` in flat.json). The base render is drawn as it is; each highlighted plate's fill shape
// (muscle-map/pipeline/outlines.py: the plate's traced edge grown a pixel into the dark groove around it) is filled
// with the moss accent, multiplied over the render so the plate keeps its shading, at one of three opacities by which
// third of 0 to 1 the group's strength falls in (a main muscle at 1 gets the full accent, a helping one at 0.5 the
// middle step, a faded recency the lightest). Tap a plate and every plate of that muscle, on both figures, fills blue
""", """// highlighted by their everyday names (data/index.dart `muscleNames`, each plate's `name` in flat.json). This is how the
// muscle map draws strain points (MUSCLE_MAP.md): the base render is drawn as it is; each strained plate's fill shape
// (muscle-map/pipeline/outlines.py: the plate's traced edge grown a pixel into the dark groove around it) is filled
// with the strain red, multiplied over the render so the plate keeps its shading, at the opacity of its shade: low,
// medium or high, each a third of 0.00 to 1.00. Tap a plate and every plate of that muscle, on both figures, fills blue
"""),
    ("""import '../data/index.dart';
import 'app.dart';
""", """import '../data/index.dart';
import '../logic/muscle_map.dart';
import 'app.dart';
"""),
    ("""/// A workout's main muscles come in at 1, its helping ones at 0.5.
const primaryStrength = 1.0;
const secondaryStrength = 0.5;

/// The fill: the design system's light-theme accent (oklch 0.48 0.085 138), laid over the plate at one of three
/// opacities, so a strength reads as one of three clear steps rather than a fade. The figure is the same light gray in
/// both themes, so the accent is fixed rather than a theme token (the dark-theme accent is too pale on gray plates).
/// Selection is a blue the rest of the app never uses, filled at full strength in place of a plate's step, so a tapped
/// group stands out from every fill.
const muscleAccent = Color(0xFF456938);
const muscleSelect = Color(0xFF2F7BE5);
/// The plate gray the swatches sit on, the figure's typical plate brightness.
const musclePlate = Color(0xFFBEBEBE);
/// The steps' opacities, weakest first.
const muscleSteps = [1 / 3, 2 / 3, 1.0];
""", """/// The strain red: the design system's light-theme danger (#AF3E30), laid over the plate at one of three opacities, so
/// strain points read as one of three clear shades rather than a fade, and a muscle visibly steps down one shade a day.
/// The figure is the same light gray in both themes, so the red is fixed rather than a theme token. Selection is a
/// blue the rest of the app never uses, filled at full strength in place of a plate's shade, so a tapped muscle stands
/// out from every fill.
const strainRed = Color(0xFFAF3E30);
const muscleSelect = Color(0xFF2F7BE5);
/// The plate gray the swatches sit on, the figure's typical plate brightness.
const musclePlate = Color(0xFFBEBEBE);
/// The shades' opacities, low first.
const strainShadeOpacity = [1 / 3, 2 / 3, 1.0];
"""),
    ("""final muscleMultiply = _overPlate(muscleAccent);""", """final strainMultiply = _overPlate(strainRed);"""),
    ("""/// The opacity a strength draws at: nothing at 0, then the step whose third of the range it falls in.
double muscleStepOpacity(double strength) {
  if (strength <= 0) return 0;
  return muscleSteps[(strength.clamp(0.0, 1.0) * muscleSteps.length).ceil().clamp(1, muscleSteps.length) - 1];
}
""", """/// The opacity strain points draw at: nothing when strain-free, then their shade's.
double strainOpacity(double points) {
  final shade = strainShade(points);
  return shade == 0 ? 0 : strainShadeOpacity[shade - 1];
}
"""),
    ("""/// Draws one figure into its box: the render scaled to fit, the highlighted plates filled with the accent, the
""", """/// Draws one figure into its box: the render scaled to fit, the strained plates filled with the strain red, the
"""),
    ("""  final Map<int, double> opacity;   // plate id -> fill opacity""", """  final Map<int, double> opacity;   // plate id -> fill opacity, by its shade"""),
    ("""      if (!selected.contains(e.key)) fillPlate(e.key, muscleMultiply, e.value);""", """      if (!selected.contains(e.key)) fillPlate(e.key, strainMultiply, e.value);"""),
    ("""/// The figures side by side. [highlight] is muscle name -> strength: 1 primary, 0.5 secondary, or anything 0 to 1.
/// Tap a plate to fill that muscle blue and see a tooltip: its name and [detail] if the caller has one.
/// [keyLabels] names the steps under the figures, strongest first; [expandable] adds a button that opens [MuscleFigureScreen].""",
     """/// The figures side by side. [highlight] is muscle name -> strain points, 0.00 to 1.00, drawn in their shades.
/// Tap a plate to fill that muscle blue and see a tooltip: its name and [detail] if the caller has one.
/// [keyLabels] names the shades under the figures, high first; [expandable] adds a button that opens [MuscleFigureScreen]."""),
    ("""    final opacity = <String, double>{for (final e in widget.highlight.entries) e.key: muscleStepOpacity(e.value)};""",
     """    final opacity = <String, double>{for (final e in widget.highlight.entries) e.key: strainOpacity(e.value)};"""),
    ("""/// The steps' swatches, strongest first, one per label: the accent over the plate gray at each step's opacity.""",
     """/// The shades' swatches, high first, one per label: the strain red over the plate gray at each shade's opacity."""),
    ("""    final steps = muscleSteps.reversed.toList();
    return Wrap(spacing: 12, runSpacing: 4, children: [
      for (var i = 0; i < labels.length && i < steps.length; i++) swatch(Color.lerp(musclePlate, muscleAccent, steps[i])!, labels[i]),""",
     """    final steps = strainShadeOpacity.reversed.toList();
    return Wrap(spacing: 12, runSpacing: 4, children: [
      for (var i = 0; i < labels.length && i < steps.length; i++) swatch(Color.lerp(musclePlate, strainRed, steps[i])!, labels[i]),"""),
])
