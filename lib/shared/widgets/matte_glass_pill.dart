import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Softly diffused glass with fine matte grain and crisp foreground content.
class MatteGlassPill extends StatelessWidget {
  const MatteGlassPill({
    super.key,
    required this.child,
    this.surfaceColor = surface,
    this.blendMode = BlendMode.srcOver,
  });

  final Widget child;
  final Color surfaceColor;
  final BlendMode blendMode;

  static const surface = Color(0x38181C20);
  static const lightSurface = Color(0x38FFFFFF);

  // Keep most of the scene's colour and brightness beneath the diffusion.
  // A light tint and fine grain soften the glass without hiding it.
  static final ui.ImageFilter _filter = ui.ImageFilter.compose(
    outer: const ColorFilter.matrix(<double>[
      0.724,
      0.250,
      0.026,
      0,
      0,
      0.074,
      0.900,
      0.026,
      0,
      0,
      0.074,
      0.250,
      0.676,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]),
    inner: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
  );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: _filter,
        blendMode: blendMode,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: CustomPaint(
            painter: const _MatteGrain(),
            child: Padding(padding: const EdgeInsets.all(3), child: child),
          ),
        ),
      ),
    );
  }
}

/// Fixed fine grain: two batched draws, no animation or additional filter.
class _MatteGrain extends CustomPainter {
  const _MatteGrain();

  @override
  void paint(Canvas canvas, Size size) {
    final light = <Offset>[];
    final dark = <Offset>[];
    for (int y = 0; y < size.height.ceil(); y += 3) {
      for (int x = 0; x < size.width.ceil(); x += 3) {
        final hash = ((x * 73856093) ^ (y * 19349663)) & 255;
        final point = Offset(x + (hash & 3) * 0.5, y + (hash >> 2 & 3) * 0.5);
        (hash.isEven ? light : dark).add(point);
      }
    }
    canvas.drawPoints(
      ui.PointMode.points,
      light,
      Paint()
        ..color = const Color(0x06FFFFFF)
        ..strokeWidth = 0.6,
    );
    canvas.drawPoints(
      ui.PointMode.points,
      dark,
      Paint()
        ..color = const Color(0x06000000)
        ..strokeWidth = 0.6,
    );
  }

  @override
  bool shouldRepaint(_MatteGrain oldDelegate) => false;
}
