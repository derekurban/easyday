// MuscleFigure: the rendered body figures from muscle-map/assets (male or female, front and back), with muscles
// highlighted by dataset group. The base render is drawn as it is; each highlighted plate's traced surface
// (muscle-map/pipeline/outlines.py) is filled with the moss accent, multiplied over the render so the plate keeps its
// shading, at one of three opacities by which third of 0 to 1 the group's strength falls in (a main muscle at 1 gets
// the full accent, a helping one at 0.5 the middle step, a faded recency the lightest). Tap a plate and every plate of
// its group is outlined in blue along the same traced edges, with a tooltip over the figure naming it (and whatever
// detail the caller adds). Fills and outlines are vector paths, so they stay crisp at any size and under the full
// screen's pinch zoom. An expand button opens that full screen. The id maps (used for taps) follow
// app/js/muscle-map.js and docs/muscle-mapping.md.
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'app.dart';
import 'motion.dart';
import 'theme.dart';

/// A workout's main muscles come in at 1, its helping ones at 0.5.
const primaryStrength = 1.0;
const secondaryStrength = 0.5;

/// The fill: the design system's light-theme accent (oklch 0.48 0.085 138), laid over the plate at one of three
/// opacities, so a strength reads as one of three clear steps rather than a fade. The figure is the same light gray in
/// both themes, so the accent is fixed rather than a theme token (the dark-theme accent is too pale on gray plates).
/// Selection is a blue the rest of the app never uses, so it cannot be mistaken for a fill.
const muscleAccent = Color(0xFF456938);
const muscleSelect = Color(0xFF2F7BE5);
/// The plate gray the swatches sit on, the figure's typical plate brightness.
const musclePlate = Color(0xFFBEBEBE);
/// The steps' opacities, weakest first.
const muscleSteps = [1 / 3, 2 / 3, 1.0];

/// What the fill multiplies the render by: the accent over the plates' typical gray (182), so a plate of that gray
/// comes out exactly the accent at full strength and darker or lighter parts of it keep their shading.
final muscleMultiply = Color.from(
  alpha: 1, red: (muscleAccent.r * 255 / 182).clamp(0.0, 1.0), green: (muscleAccent.g * 255 / 182).clamp(0.0, 1.0), blue: (muscleAccent.b * 255 / 182).clamp(0.0, 1.0));

/// The selection outline's width in logical pixels, whatever the size or zoom.
const muscleOutlineWidth = 2.0;

/// The opacity a strength draws at: nothing at 0, then the step whose third of the range it falls in.
double muscleStepOpacity(double strength) {
  if (strength <= 0) return 0;
  return muscleSteps[(strength.clamp(0.0, 1.0) * muscleSteps.length).ceil().clamp(1, muscleSteps.length) - 1];
}

/// One figure, ready to draw: the render, the box around the body it is drawn through, each plate's traced surface as
/// a path in that box's coordinates, and the id map cropped to the box for taps.
class MuscleMapData {
  MuscleMapData({required this.w, required this.h, required this.x0, required this.y0, required this.base, required this.plate,
      required this.plateDataset, required this.plateMuscle, required this.paths});
  final int w, h;                   // cropped size
  final int x0, y0;                 // the crop's corner in the asset
  final ui.Image base;              // the whole asset image
  final Uint8List plate;            // plate id per cropped pixel
  final List<String?> plateDataset; // plate id -> dataset group
  final List<String?> plateMuscle;  // plate id -> muscle name
  final Map<int, ui.Path> paths;    // plate id -> traced surface, cropped coordinates

  Rect get crop => Rect.fromLTWH(x0.toDouble(), y0.toDouble(), w.toDouble(), h.toDouble());

  /// The plates of a dataset group, or just [plate] when it has no group.
  Set<int> groupPlates(int plate) {
    final g = plateDataset[plate];
    if (g == null) return {plate};
    return {for (var id = 1; id < 256; id++) if (plateDataset[id] == g) id};
  }

  /// The box around [plates]' surfaces, in cropped coordinates, or null when none is traced.
  Rect? bounds(Iterable<int> plates) {
    Rect? r;
    for (final id in plates) {
      final b = paths[id]?.getBounds();
      if (b != null) r = r == null ? b : r.expandToInclude(b);
    }
    return r;
  }
}

class MuscleRenderer {
  static final _maps = <String, Future<MuscleMapData>>{};
  static Future<Map<String, dynamic>>? _outlines;

  static Future<MuscleMapData> map(String key) => _maps.putIfAbsent(key, () => _load(key));

  static Future<MuscleMapData> _load(String key) async {
    final meta = jsonDecode(await rootBundle.loadString('assets/muscle/flat.json')) as Map<String, dynamic>;
    final plates = (meta['maps'][key]['plates'] as List).cast<Map<String, dynamic>>();
    final dataset = List<String?>.filled(256, null), muscle = List<String?>.filled(256, null);
    for (final p in plates) { dataset[p['id'] as int] = p['group'] as String?; muscle[p['id'] as int] = p['muscle'] as String?; }
    // the render is drawn from Flutter's own decode (correct alpha); its raw pixels only find the crop
    final base = await _image('assets/muscle/$key.png');
    final baseRaw = (await base.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer.asUint8List();
    final idsImage = await _image('assets/muscle/${key}_ids.png');
    final ids = (await idsImage.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    idsImage.dispose();
    final crop = await compute(_prepare, _PrepareArgs(base.width, base.height, baseRaw, ids));
    _outlines ??= rootBundle.loadString('assets/muscle/outlines.json').then((s) => jsonDecode(s) as Map<String, dynamic>);
    final traced = ((await _outlines)!['maps'][key]['plates'] as Map<String, dynamic>);
    final paths = <int, ui.Path>{
      for (final e in traced.entries) int.parse(e.key): _path((e.value as List).cast<List>(), -crop.x0.toDouble(), -crop.y0.toDouble()),
    };
    return MuscleMapData(w: crop.w, h: crop.h, x0: crop.x0, y0: crop.y0, base: base, plate: crop.plate, plateDataset: dataset, plateMuscle: muscle, paths: paths);
  }

  static Future<ui.Image> _image(String asset) async {
    final bytes = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }

  /// A plate's polygons as one smooth closed path: quadratic curves through the midpoints of the traced edges, each
  /// traced point the control between them, so the outline has no corners at any zoom.
  static ui.Path _path(List<List> polygons, double dx, double dy) {
    final path = ui.Path()..fillType = ui.PathFillType.evenOdd;
    for (final flat in polygons) {
      final n = flat.length ~/ 2;
      if (n < 3) continue;
      Offset p(int i) => Offset((flat[(i % n) * 2] as num).toDouble() + dx, (flat[(i % n) * 2 + 1] as num).toDouble() + dy);
      Offset mid(Offset a, Offset b) => (a + b) / 2;
      final start = mid(p(n - 1), p(0));
      path.moveTo(start.dx, start.dy);
      for (var i = 0; i < n; i++) {
        final c = p(i), e = mid(c, p(i + 1));
        path.quadraticBezierTo(c.dx, c.dy, e.dx, e.dy);
      }
      path.close();
    }
    return path;
  }
}

class _PrepareArgs {
  const _PrepareArgs(this.w, this.h, this.base, this.ids);
  final int w, h;
  final Uint8List base, ids;
}

class _Crop {
  const _Crop(this.x0, this.y0, this.w, this.h, this.plate);
  final int x0, y0, w, h;
  final Uint8List plate;
}

/// The box around the body (with a small margin) and the id map cropped to it. Runs in an isolate once per map.
_Crop _prepare(_PrepareArgs a) {
  var x0 = a.w, y0 = a.h, x1 = 0, y1 = 0;
  for (var y = 0; y < a.h; y++) {
    for (var x = 0; x < a.w; x++) {
      if (a.base[(y * a.w + x) * 4 + 3] > 0) { if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
    }
  }
  x0 = (x0 - 8).clamp(0, a.w - 1); y0 = (y0 - 8).clamp(0, a.h - 1); x1 = (x1 + 8).clamp(0, a.w - 1); y1 = (y1 + 8).clamp(0, a.h - 1);
  final w = x1 - x0 + 1, h = y1 - y0 + 1;
  final plate = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) { plate[y * w + x] = a.ids[((y + y0) * a.w + (x + x0)) * 4]; }
  }
  return _Crop(x0, y0, w, h, plate);
}

/// Draws one figure into its box: the render scaled to fit, the highlighted plates filled, the selected ones outlined.
/// [zoom] is the full screen's pinch scale, so the outline keeps its width on screen.
class _FigurePainter extends CustomPainter {
  _FigurePainter(this.m, this.opacity, this.selected, this.zoom) : super(repaint: zoom);
  final MuscleMapData m;
  final Map<int, double> opacity;   // plate id -> fill opacity
  final Set<int> selected;
  final ValueListenable<double>? zoom;

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width / m.w, size.height / m.h);
    final dx = (size.width - m.w * s) / 2, dy = (size.height - m.h * s) / 2;
    final z = zoom?.value ?? 1.0;
    // mipmapped bilinear when shrinking, bicubic when the render is enlarged (full screen, pinch zoom)
    final quality = s * z > 1 ? FilterQuality.high : FilterQuality.medium;
    canvas.drawImageRect(m.base, m.crop, Rect.fromLTWH(dx, dy, m.w * s, m.h * s), Paint()..filterQuality = quality);
    final dst = Rect.fromLTWH(dx, dy, m.w * s, m.h * s);
    // Paths are scaled into the box's coordinates rather than through a canvas transform.
    final toBox = Float64List.fromList([s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, dx, dy, 0, 1]);
    // Each highlighted plate: clip to its path and draw the render again through a modulate filter of the multiply
    // colour at the step's opacity. Over the render already there that comes out render × (1 − o·(1 − c)), a
    // multiply that keeps the plate's shading, done as plain source-over drawing (BlendMode.multiply reads the
    // framebuffer back, which Impeller on GLES does through a blurred, offset copy; an image shader there ignored
    // its matrix).
    final fill = Paint()..filterQuality = quality;
    for (final e in opacity.entries) {
      final path = m.paths[e.key];
      if (path == null || e.value <= 0) continue;
      fill.colorFilter = ColorFilter.mode(muscleMultiply.withValues(alpha: e.value), BlendMode.modulate);
      canvas.save();
      canvas.clipPath(path.transform(toBox));
      canvas.drawImageRect(m.base, m.crop, dst, fill);
      canvas.restore();
    }
    if (selected.isNotEmpty) {
      final edge = Paint()
        ..style = PaintingStyle.stroke..strokeWidth = muscleOutlineWidth / z..color = muscleSelect
        ..strokeJoin = StrokeJoin.round..isAntiAlias = true;
      for (final id in selected) {
        final path = m.paths[id];
        if (path != null) canvas.drawPath(path.transform(toBox), edge);
      }
    }
  }

  @override
  bool shouldRepaint(_FigurePainter old) =>
      old.m != m || old.zoom != zoom || !mapEquals(old.opacity, opacity) || !setEquals(old.selected, selected);
}

/// What a tap landed on.
class MuscleHit {
  const MuscleHit({required this.key, required this.plate, required this.muscle, required this.dataset});
  final String key;
  final int plate;
  final String muscle;
  final String dataset;   // '' for the one unmapped muscle
}

/// The figures side by side. [highlight] is dataset group -> strength: 1 primary, 0.5 secondary, or anything 0 to 1.
/// Tap a plate to outline its group and see a tooltip: the muscle, its group, and [detail] if the caller has one.
/// [keyLabels] names the steps under the figures, strongest first; [expandable] adds a button that opens [MuscleFigureScreen].
class MuscleFigure extends StatefulWidget {
  const MuscleFigure({
    super.key, required this.highlight, this.height = 170, this.sides = const ['front', 'back'], this.interactive = true,
    this.keyLabels, this.detail, this.onTap, this.tooltip = true, this.expandable = false, this.title, this.clearAfter = const Duration(seconds: 6),
    this.zoom,
  });
  final Map<String, double> highlight;
  final double height;
  final List<String> sides;
  final bool interactive;
  final List<String>? keyLabels;
  final String? Function(MuscleHit hit)? detail;
  final ValueChanged<MuscleHit?>? onTap;
  final bool tooltip;
  final bool expandable;
  final String? title;
  final Duration? clearAfter;
  /// The full screen's pinch scale, so outlines keep their width when zoomed.
  final ValueListenable<double>? zoom;

  /// The width the two figures take at [height].
  static double widthFor(double height, {int sides = 2}) => height * 0.5 * sides + 4 * (sides - 1);

  @override
  State<MuscleFigure> createState() => _MuscleFigureState();
}

class _MuscleFigureState extends State<MuscleFigure> {
  MuscleHit? hit;
  Offset? anchor;                     // where the tap landed, in the row's coordinates
  Rect? avoid;                        // the outlined plates' box on the tapped side, in the row's coordinates
  var outlined = <String, Set<int>>{}; // per side key, the plates to edge
  Timer? clear;

  @override
  void dispose() { clear?.cancel(); super.dispose(); }

  Future<void> _tap(String key, Offset local, Size box, double rowOffset) async {
    final sex = context.store.state.settings.figure;
    final m = await MuscleRenderer.map(key);
    final scale = min(box.width / m.w, box.height / m.h);
    final dx = (box.width - m.w * scale) / 2, dy = (box.height - m.h * scale) / 2;
    final x = ((local.dx - dx) / scale).floor(), y = ((local.dy - dy) / scale).floor();
    MuscleHit? found;
    if (x >= 0 && y >= 0 && x < m.w && y < m.h) {
      // a tap on a groove still finds the nearest plate within a few pixels
      for (final r in [0, 6, 12]) {
        for (final o in [(0, 0), (r, 0), (-r, 0), (0, r), (0, -r)]) {
          final px = (x + o.$1).clamp(0, m.w - 1), py = (y + o.$2).clamp(0, m.h - 1);
          final id = m.plate[py * m.w + px];
          if (id != 0 && m.plateMuscle[id] != null) { found = MuscleHit(key: key, plate: id, muscle: m.plateMuscle[id]!, dataset: m.plateDataset[id] ?? ''); break; }
        }
        if (found != null) break;
      }
    }
    final same = found != null && hit != null && hit!.dataset == found.dataset && (found.dataset.isNotEmpty || hit!.plate == found.plate);
    final next = (found == null || same) ? null : found;
    final edges = <String, Set<int>>{};
    if (next != null) {
      for (final side in widget.sides) {
        final k = '${sex}_$side';
        final sm = await MuscleRenderer.map(k);
        edges[k] = next.dataset.isEmpty ? (k == key ? {next.plate} : <int>{}) : {for (var id = 1; id < 256; id++) if (sm.plateDataset[id] == next.dataset) id};
      }
    }
    Rect? box2;
    if (next != null) {
      // the box of the outlined plates on the tapped side, so the tooltip can keep clear of them
      final b = m.bounds(edges[key] ?? const <int>{});
      if (b != null) box2 = Rect.fromLTRB(dx + b.left * scale + rowOffset, dy + b.top * scale, dx + b.right * scale + rowOffset, dy + b.bottom * scale);
    }
    if (!mounted) return;
    setState(() { hit = next; outlined = edges; anchor = next == null ? null : Offset(local.dx + rowOffset, local.dy); avoid = box2; });
    widget.onTap?.call(hit);
    clear?.cancel();
    final after = widget.clearAfter;
    if (hit != null && after != null) clear = Timer(after, () { if (mounted) setState(() { hit = null; outlined = {}; anchor = null; avoid = null; }); });
  }

  void _expand() {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      transitionDuration: m(context, durBase),
      reverseTransitionDuration: m(context, durBase),
      pageBuilder: (_, _, _) => MuscleFigureScreen(highlight: widget.highlight, sides: widget.sides, keyLabels: widget.keyLabels, detail: widget.detail, title: widget.title),
      transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final du = context.du;
    final sex = context.store.state.settings.figure;
    final box = Size(widget.height * 0.5, widget.height);
    final rowWidth = MuscleFigure.widthFor(widget.height, sides: widget.sides.length);
    final opacity = <String, double>{for (final e in widget.highlight.entries) e.key: muscleStepOpacity(e.value)};
    final detail = hit == null ? null : widget.detail?.call(hit!);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: rowWidth, height: box.height, child: Stack(clipBehavior: Clip.none, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < widget.sides.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Builder(builder: (context) {
              final key = '${sex}_${widget.sides[i]}';
              final edges = outlined[key] ?? const <int>{};
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: widget.interactive ? (d) => _tap(key, d.localPosition, box, i * (box.width + 4)) : null,
                child: SizedBox(
                  height: box.height,
                  width: box.width,
                  child: FutureBuilder<MuscleMapData>(
                    future: MuscleRenderer.map(key),
                    builder: (context, snap) {
                      final md = snap.data;
                      return AnimatedOpacity(
                        duration: m(context, durFast),
                        opacity: md == null ? 0 : 1,
                        child: md == null ? const SizedBox.expand() : CustomPaint(
                          size: box,
                          painter: _FigurePainter(md, {
                            for (var id = 1; id < 256; id++)
                              if ((opacity[md.plateDataset[id]] ?? 0) > 0) id: opacity[md.plateDataset[id]]!,
                          }, edges, widget.zoom),
                        ),
                      );
                    },
                  ),
                ),
              );
            }),
          ],
        ]),
        if (widget.expandable)
          Positioned(right: -6, top: -6, child: IconButton(
            onPressed: _expand, tooltip: 'Expand', icon: const Icon(LucideIcons.maximize2, size: 15),
            style: IconButton.styleFrom(foregroundColor: du.inkTertiary, backgroundColor: du.surface, minimumSize: const Size(30, 30), padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          )),
        if (widget.tooltip && hit != null && anchor != null)
          Positioned.fill(child: IgnorePointer(child: CustomSingleChildLayout(
            delegate: _TipLayout(anchor!, avoid ?? Rect.fromCenter(center: anchor!, width: 24, height: 24)),
            child: _Tip(hit: hit!, detail: detail),
          ))),
      ])),
      if (widget.keyLabels != null)
        Padding(padding: const EdgeInsets.only(top: 8), child: SizedBox(width: rowWidth, child: MuscleKey(labels: widget.keyLabels!))),
    ]);
  }
}

/// The steps' swatches, strongest first, one per label: the accent over the plate gray at each step's opacity.
class MuscleKey extends StatelessWidget {
  const MuscleKey({super.key, required this.labels});
  final List<String> labels;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    Widget swatch(Color c, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: du.line, width: 0.6))),
      const SizedBox(width: 5),
      Text(text, style: t.labelSmall),
    ]);
    final steps = muscleSteps.reversed.toList();
    return Wrap(spacing: 12, runSpacing: 4, children: [
      for (var i = 0; i < labels.length && i < steps.length; i++) swatch(Color.lerp(musclePlate, muscleAccent, steps[i])!, labels[i]),
    ]);
  }
}

/// Places the tooltip clear of the outlined plates: under them, else above, else beside; kept near the row, with a
/// little overflow allowed on the right where there is usually text, and almost none on the left.
class _TipLayout extends SingleChildLayoutDelegate {
  const _TipLayout(this.anchor, this.avoid);
  final Offset anchor;
  final Rect avoid;
  static const left = 10.0, right = 120.0, above = 24.0, gap = 8.0;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints c) => BoxConstraints(maxWidth: max(150, min(190, c.maxWidth + left + right)));
  @override
  Offset getPositionForChild(Size size, Size child) {
    double clampX(double x) => x.clamp(-left, max(-left, size.width + right - child.width)).toDouble();
    final x = clampX(anchor.dx - child.width / 2);
    if (avoid.bottom + gap + child.height <= size.height + gap) return Offset(x, avoid.bottom + gap);
    if (avoid.top - gap - child.height >= -above) return Offset(x, avoid.top - gap - child.height);
    final y = (anchor.dy - child.height / 2).clamp(-above, max(-above, size.height - child.height)).toDouble();
    final toRight = Offset(avoid.right + gap, y), toLeft = Offset(avoid.left - gap - child.width, y);
    final rightFits = toRight.dx + child.width <= size.width + right, leftFits = toLeft.dx >= -left;
    if (anchor.dx < size.width / 2) return rightFits ? toRight : leftFits ? toLeft : Offset(clampX(toRight.dx), y);
    return leftFits ? toLeft : rightFits ? toRight : Offset(clampX(toLeft.dx), y);
  }
  @override
  bool shouldRelayout(_TipLayout old) => old.anchor != anchor || old.avoid != avoid;
}

class _Tip extends StatelessWidget {
  const _Tip({required this.hit, this.detail});
  final MuscleHit hit;
  final String? detail;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Material(
      color: du.ink, elevation: 3, shadowColor: Colors.black38, borderRadius: BorderRadius.circular(10),
      child: Padding(padding: const EdgeInsets.fromLTRB(11, 8, 11, 9), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(hit.muscle, style: t.labelLarge?.copyWith(color: du.bg)),
        if (hit.dataset.isNotEmpty) Text(hit.dataset, style: t.labelSmall?.copyWith(color: du.bg.withValues(alpha: 0.7))),
        if (detail != null) Padding(padding: const EdgeInsets.only(top: 5), child: Text(detail!, style: t.bodySmall?.copyWith(color: du.bg))),
      ])),
    );
  }
}

/// The figure full screen: as large as the width allows, pinch to zoom, tap to outline a group, with the details in
/// a panel under it instead of a tooltip.
class MuscleFigureScreen extends StatefulWidget {
  const MuscleFigureScreen({super.key, required this.highlight, this.sides = const ['front', 'back'], this.keyLabels, this.detail, this.title});
  final Map<String, double> highlight;
  final List<String> sides;
  final List<String>? keyLabels;
  final String? Function(MuscleHit hit)? detail;
  final String? title;
  @override
  State<MuscleFigureScreen> createState() => _MuscleFigureScreenState();
}

class _MuscleFigureScreenState extends State<MuscleFigureScreen> {
  MuscleHit? hit;
  String view = 'both';
  final zoom = TransformationController();
  late final scale = ValueNotifier(1.0);

  @override
  void initState() {
    super.initState();
    zoom.addListener(() => scale.value = zoom.value.getMaxScaleOnAxis());
  }

  @override
  void dispose() { zoom.dispose(); scale.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final du = context.du;
    final t = Theme.of(context).textTheme;
    final detail = hit == null ? null : widget.detail?.call(hit!);
    return Scaffold(
      backgroundColor: du.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(widget.title ?? 'Muscles', style: t.titleLarge),
        actions: [IconButton(tooltip: 'Shrink', icon: const Icon(LucideIcons.minimize2, size: 20), onPressed: () => Navigator.of(context).pop())],
      ),
      body: SafeArea(child: LayoutBuilder(builder: (context, c) {
        final sides = view == 'both' ? widget.sides : [view];
        final n = sides.length;
        final height = min(c.maxHeight - 210, (c.maxWidth - 24 - 4 * (n - 1)) / (0.5 * n)).clamp(160.0, 1200.0).toDouble();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (widget.sides.length > 1)
            Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: Segmented<String>(
              value: view, options: {'both': 'Both', for (final side in widget.sides) side: side[0].toUpperCase() + side.substring(1)},
              onChanged: (v) => setState(() => view = v),
            )),
          Expanded(child: InteractiveViewer(
            transformationController: zoom, minScale: 1, maxScale: 5, clipBehavior: Clip.none,
            child: Center(child: MuscleFigure(
              key: ValueKey(view),
              highlight: widget.highlight, sides: sides, height: height, tooltip: false, clearAfter: null, zoom: scale,
              onTap: (h) => setState(() => hit = h),
            )),
          )),
          Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnimatedSwitcher(duration: m(context, durBase), child: Column(key: ValueKey(hit?.muscle), crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(hit?.muscle ?? 'Tap a muscle to name it', style: t.titleMedium),
              Text(hit == null ? 'Pinch to zoom. Tapping outlines every muscle in the group.' : (detail == null ? hit!.dataset : [if (hit!.dataset.isNotEmpty) hit!.dataset, detail].join(' · ')), style: t.bodySmall),
            ])),
            if (widget.keyLabels != null) ...[const SizedBox(height: 10), MuscleKey(labels: widget.keyLabels!)],
          ])),
        ]);
      })),
    );
  }
}
