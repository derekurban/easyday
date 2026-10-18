// MuscleFigure: the rendered body figures from muscle-map/assets (male or female, front and back), with muscles
// highlighted by dataset group. The base render keeps its own shading; plates are tinted with the moss accent at one
// of three opacities, by which third of 0 to 1 the group's strength falls in (a main muscle at 1 gets the full accent,
// a helping one at 0.5 the middle step, a faded recency the lightest). Tap a plate
// and every plate of its group is outlined in blue, with a tooltip over the figure naming it (and whatever detail the
// caller adds). An expand button opens the same figure full screen with pinch zoom. Rendering happens in an isolate,
// downsampled to about the display size so it stays crisp, and is cached per distinct request. The id maps follow
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

/// The opacity a strength draws at: nothing at 0, then the step whose third of the range it falls in.
double muscleStepOpacity(double strength) {
  if (strength <= 0) return 0;
  return muscleSteps[(strength.clamp(0.0, 1.0) * muscleSteps.length).ceil().clamp(1, muscleSteps.length) - 1];
}

class MuscleMapData {
  MuscleMapData({required this.w, required this.h, required this.base, required this.plate, required this.tint, required this.plateDataset, required this.plateMuscle});
  final int w, h;                  // cropped size
  final Uint8List base;            // RGBA, straight alpha
  final Uint8List plate;           // plate id per pixel
  final Uint8List tint;            // tint mask 0..255 per pixel
  final List<String?> plateDataset; // plate id -> dataset group
  final List<String?> plateMuscle;  // plate id -> muscle name

  /// The plates of a dataset group, or just [plate] when it has no group.
  Set<int> groupPlates(int plate) {
    final g = plateDataset[plate];
    if (g == null) return {plate};
    return {for (var id = 1; id < 256; id++) if (plateDataset[id] == g) id};
  }
}

class MuscleRenderer {
  static final _maps = <String, Future<MuscleMapData>>{};
  static final _images = <String, Future<ui.Image>>{};
  static final _order = <String>[];

  static Future<MuscleMapData> map(String key) => _maps.putIfAbsent(key, () => _load(key));

  static Future<MuscleMapData> _load(String key) async {
    final meta = jsonDecode(await rootBundle.loadString('assets/muscle/flat.json')) as Map<String, dynamic>;
    final plates = (meta['maps'][key]['plates'] as List).cast<Map<String, dynamic>>();
    final dataset = List<String?>.filled(256, null), muscle = List<String?>.filled(256, null);
    for (final p in plates) { dataset[p['id'] as int] = p['group'] as String?; muscle[p['id'] as int] = p['muscle'] as String?; }
    final base = await _decode('assets/muscle/$key.png', ui.ImageByteFormat.rawStraightRgba);
    final ids = await _decode('assets/muscle/${key}_ids.png', ui.ImageByteFormat.rawRgba);
    return compute(_prepare, _PrepareArgs(base.$1, base.$2, base.$3, ids.$3, dataset, muscle));
  }

  static Future<(int, int, Uint8List)> _decode(String asset, ui.ImageByteFormat fmt) async {
    final bytes = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: fmt);
    final out = (frame.image.width, frame.image.height, data!.buffer.asUint8List());
    frame.image.dispose();
    return out;
  }

  static int _factor(MuscleMapData m, double targetPx) => max(1, (m.h / max(1.0, targetPx * 1.5)).floor());

  /// A highlighted figure, downsampled so its height is about [targetPx] physical pixels. [highlight] is dataset
  /// group -> strength 0..1. Cached by request.
  static Future<ui.Image> render(String key, Map<String, double> highlight, {required double targetPx}) {
    final hk = (highlight.entries.where((e) => e.value > 0).map((e) => '${e.key}${muscleStepOpacity(e.value).toStringAsFixed(2)}').toList()..sort()).join(',');
    return _cached('fill|$key|$hk|${targetPx.round()}|${muscleAccent.toARGB32()}', () async {
      final m = await map(key);
      final f = _factor(m, targetPx);
      final pixels = await compute(_tint, _TintArgs(m.w, m.h, m.base, m.plate, m.tint, m.plateDataset, highlight, f));
      return _image(pixels, m.w ~/ f, m.h ~/ f);
    });
  }

  /// A transparent overlay with a blue edge inside each of [plates], matching [render] at the same [targetPx].
  static Future<ui.Image> outline(String key, Set<int> plates, {required double targetPx}) {
    final pk = (plates.toList()..sort()).join(',');
    return _cached('edge|$key|$pk|${targetPx.round()}|${muscleSelect.toARGB32()}', () async {
      final m = await map(key);
      final f = _factor(m, targetPx);
      final edge = max(3, (m.h / targetPx * 5).round());
      final pixels = await compute(_outline, _OutlineArgs(m.w, m.h, m.base, m.plate, Uint8List.fromList([for (var id = 0; id < 256; id++) plates.contains(id) ? 1 : 0]), muscleSelect.toARGB32(), edge, f));
      return _image(pixels, m.w ~/ f, m.h ~/ f);
    });
  }

  static Future<ui.Image> _cached(String ck, Future<ui.Image> Function() make) {
    final hit = _images[ck];
    if (hit != null) return hit;
    final fut = make();
    _images[ck] = fut;
    _order.add(ck);
    if (_order.length > 32) { final old = _order.removeAt(0); _images.remove(old)?.then((img) => img.dispose()); }
    return fut;
  }

  static Future<ui.Image> _image(Uint8List pixels, int w, int h) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(pixels, w, h, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }
}

class _PrepareArgs {
  const _PrepareArgs(this.w, this.h, this.base, this.ids, this.dataset, this.muscle);
  final int w, h;
  final Uint8List base, ids;
  final List<String?> dataset, muscle;
}

/// Crop to the figure and split the id map into plate and tint arrays. Runs in an isolate once per map.
MuscleMapData _prepare(_PrepareArgs a) {
  var x0 = a.w, y0 = a.h, x1 = 0, y1 = 0;
  for (var y = 0; y < a.h; y++) {
    for (var x = 0; x < a.w; x++) {
      if (a.base[(y * a.w + x) * 4 + 3] > 0) { if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
    }
  }
  x0 = (x0 - 8).clamp(0, a.w - 1); y0 = (y0 - 8).clamp(0, a.h - 1); x1 = (x1 + 8).clamp(0, a.w - 1); y1 = (y1 + 8).clamp(0, a.h - 1);
  final w = x1 - x0 + 1, h = y1 - y0 + 1;
  final base = Uint8List(w * h * 4), plate = Uint8List(w * h), tint = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final src = ((y + y0) * a.w + (x + x0)) * 4, dst = (y * w + x) * 4, i = y * w + x;
      base[dst] = a.base[src]; base[dst + 1] = a.base[src + 1]; base[dst + 2] = a.base[src + 2]; base[dst + 3] = a.base[src + 3];
      plate[i] = a.ids[src];
      tint[i] = (a.ids[src + 1] * a.base[src + 3]) ~/ 255;
    }
  }
  return MuscleMapData(w: w, h: h, base: base, plate: plate, tint: tint, plateDataset: a.dataset, plateMuscle: a.muscle);
}

class _TintArgs {
  const _TintArgs(this.w, this.h, this.base, this.plate, this.tint, this.plateDataset, this.highlight, this.factor);
  final int w, h;
  final Uint8List base, plate, tint;
  final List<String?> plateDataset;
  final Map<String, double> highlight;
  final int factor;
}

/// Tint the plates, then box-downsample by [factor]. Runs in an isolate per distinct request.
Uint8List _tint(_TintArgs a) {
  final w = a.w, h = a.h;
  final full = Uint8List.fromList(a.base);
  final opacity = List<double>.filled(256, 0);
  for (var id = 1; id < 256; id++) {
    final g = a.plateDataset[id];
    if (g != null) opacity[id] = muscleStepOpacity(a.highlight[g] ?? 0);
  }
  int ch(int c, int shift) => (c >> shift) & 255;
  final p = muscleAccent.toARGB32();
  final pr = ch(p, 16), pg = ch(p, 8), pb = ch(p, 0);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      final id = a.plate[i];
      if (id == 0) continue;
      final t = a.tint[i] / 255;
      if (t <= 0) continue;
      final o = opacity[id];
      if (o <= 0) continue;
      final k = i * 4;
      // the accent, shaded by the plate's own brightness, over the plate at the step's opacity
      final lum = (full[k] + full[k + 1] + full[k + 2]) / 3;
      final sh = (lum / 182).clamp(0.0, 1.12);
      final r = (pr * sh).clamp(0, 255).round();
      final g = (pg * sh).clamp(0, 255).round();
      final b = (pb * sh).clamp(0, 255).round();
      final alpha = t * o;
      full[k] = (full[k] + (r - full[k]) * alpha).round();
      full[k + 1] = (full[k + 1] + (g - full[k + 1]) * alpha).round();
      full[k + 2] = (full[k + 2] + (b - full[k + 2]) * alpha).round();
    }
  }
  return _downsample(full, w, h, a.factor);
}

class _OutlineArgs {
  const _OutlineArgs(this.w, this.h, this.base, this.plate, this.inGroup, this.color, this.edge, this.factor);
  final int w, h;
  final Uint8List base, plate, inGroup;
  final int color, edge, factor;
}

/// A blue edge just inside the chosen plates, on a transparent image, then box-downsampled. Runs in an isolate.
Uint8List _outline(_OutlineArgs a) {
  final w = a.w, h = a.h, e = a.edge;
  final out = Uint8List(w * h * 4);
  int ch(int c, int shift) => (c >> shift) & 255;
  final r = ch(a.color, 16), g = ch(a.color, 8), b = ch(a.color, 0);
  bool inside(int x, int y) => x >= 0 && y >= 0 && x < w && y < h && a.inGroup[a.plate[y * w + x]] == 1;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      if (a.inGroup[a.plate[i]] == 0) continue;
      final edge = !inside(x - e, y) || !inside(x + e, y) || !inside(x, y - e) || !inside(x, y + e)
          || !inside(x - e ~/ 2, y - e ~/ 2) || !inside(x + e ~/ 2, y + e ~/ 2) || !inside(x - e ~/ 2, y + e ~/ 2) || !inside(x + e ~/ 2, y - e ~/ 2);
      if (!edge) continue;
      final k = i * 4;
      out[k] = r; out[k + 1] = g; out[k + 2] = b; out[k + 3] = a.base[k + 3];
    }
  }
  return _downsample(out, w, h, a.factor);
}

/// Alpha-weighted box downsample by [f].
Uint8List _downsample(Uint8List full, int w, int h, int f) {
  if (f <= 1) return full;
  final ow = w ~/ f, oh = h ~/ f;
  final out = Uint8List(ow * oh * 4);
  final n = f * f;
  for (var y = 0; y < oh; y++) {
    for (var x = 0; x < ow; x++) {
      var r = 0, g = 0, b = 0, al = 0;
      for (var dy = 0; dy < f; dy++) {
        var k = ((y * f + dy) * w + x * f) * 4;
        for (var dx = 0; dx < f; dx++) {
          final av = full[k + 3];
          r += full[k] * av; g += full[k + 1] * av; b += full[k + 2] * av; al += av;
          k += 4;
        }
      }
      final o = (y * ow + x) * 4;
      if (al > 0) { out[o] = r ~/ al; out[o + 1] = g ~/ al; out[o + 2] = b ~/ al; }
      out[o + 3] = al ~/ n;
    }
  }
  return out;
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
      final mask = Uint8List(256);
      for (final id in edges[key] ?? const <int>{}) { mask[id] = 1; }
      var bx0 = m.w, by0 = m.h, bx1 = -1, by1 = -1;
      for (var py = 0; py < m.h; py++) {
        final row = py * m.w;
        for (var px = 0; px < m.w; px++) {
          if (mask[m.plate[row + px]] == 0) continue;
          if (px < bx0) bx0 = px; if (px > bx1) bx1 = px; if (py < by0) by0 = py; if (py > by1) by1 = py;
        }
      }
      if (bx1 >= 0) box2 = Rect.fromLTRB(dx + bx0 * scale + rowOffset, dy + by0 * scale, dx + (bx1 + 1) * scale + rowOffset, dy + (by1 + 1) * scale);
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
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final box = Size(widget.height * 0.5, widget.height);
    final rowWidth = MuscleFigure.widthFor(widget.height, sides: widget.sides.length);
    final targetPx = widget.height * dpr;
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
                  child: Stack(fit: StackFit.expand, children: [
                    FutureBuilder<ui.Image>(
                      future: MuscleRenderer.render(key, widget.highlight, targetPx: targetPx),
                      builder: (context, snap) => AnimatedSwitcher(
                        duration: m(context, durFast),
                        child: snap.data == null
                            ? const SizedBox.expand()
                            : RawImage(key: ValueKey(snap.data), image: snap.data, fit: BoxFit.contain, filterQuality: FilterQuality.high),
                      ),
                    ),
                    if (edges.isNotEmpty)
                      FutureBuilder<ui.Image>(
                        future: MuscleRenderer.outline(key, edges, targetPx: targetPx),
                        builder: (context, snap) => AnimatedOpacity(
                          duration: m(context, durFast),
                          opacity: snap.data == null ? 0 : 1,
                          child: snap.data == null ? const SizedBox.expand() : RawImage(image: snap.data, fit: BoxFit.contain, filterQuality: FilterQuality.high),
                        ),
                      ),
                  ]),
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
            minScale: 1, maxScale: 5, clipBehavior: Clip.none,
            child: Center(child: MuscleFigure(
              key: ValueKey(view),
              highlight: widget.highlight, sides: sides, height: height, tooltip: false, clearAfter: null,
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
