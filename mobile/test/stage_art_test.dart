import 'dart:ui' as ui;

import 'package:easyday/ui/stage_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every stage drawing, at every moment of its loop and on a narrow and a wide phone, stays inside its panel: drawn
/// with nothing clipped, no visible pixel lands outside it.
void main() {
  testWidgets('stage art stays inside its panel', (tester) async {
    const margin = 40;
    final problems = <String>[];
    await tester.runAsync(() async {
      for (final width in [300.0, 360.0]) {
        final size = Size(width, stageArtHeight);
        final w = width.toInt() + 2 * margin, h = stageArtHeight.toInt() + 2 * margin;
        for (final stage in Stage.values) {
          var worst = 0, at = 0.0;
          for (var f = 0; f < 60; f++) {
            final t = f / 60;
            final rec = ui.PictureRecorder();
            final canvas = Canvas(rec);
            canvas.translate(margin.toDouble(), margin.toDouble());
            debugPaintStage(canvas, size, stage, t);
            final image = await rec.endRecording().toImage(w, h);
            final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
            var out = 0;
            for (var y = 0; y < h; y++) {
              for (var x = 0; x < w; x++) {
                final inside = x >= margin - 1 && x <= margin + width + 1 && y >= margin - 1 && y <= margin + stageArtHeight + 1;
                if (!inside && bytes.getUint8((y * w + x) * 4 + 3) > 24) {
                  final d = [margin - 1 - x, x - (margin + width + 1), margin - 1 - y, y - (margin + stageArtHeight + 1)].reduce((a, b) => a > b ? a : b).ceil();
                  if (d > out) out = d;
                }
              }
            }
            if (out > worst) { worst = out; at = t; }
          }
          if (worst > 0) problems.add('${stage.name} at ${width.toInt()} wide: ${worst}px out at t=${at.toStringAsFixed(2)}');
        }
      }
    });
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
