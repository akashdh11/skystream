import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'hotstar_player_style.dart';

/// A softly diffused glass surface for the bottom control groups.
/// The backdrop alone is desaturated; labels and glyphs stay crisp.
class PlayerMattePill extends StatelessWidget {
  const PlayerMattePill({super.key, required this.child});

  final Widget child;

  static const surface = Color(0x38181C20);
  static const focusInk = HotstarPlayerStyle.accent;

  // Keep most of the scene's colour and brightness beneath the diffusion.
  // A light charcoal tint and fine grain soften the glass without hiding it.
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

  static bool contains(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MatteControls>() != null;

  @override
  Widget build(BuildContext context) {
    return _MatteControls(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: _filter,
          // The bar fades inside an opacity layer. Replacing its backdrop
          // avoids blending the filtered image twice during that fade.
          blendMode: BlendMode.src,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(999),
            ),
            child: CustomPaint(
              painter: const _MatteGrain(),
              child: Padding(padding: const EdgeInsets.all(3), child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _MatteControls extends InheritedWidget {
  const _MatteControls({required super.child});

  @override
  bool updateShouldNotify(_MatteControls oldWidget) => false;
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
