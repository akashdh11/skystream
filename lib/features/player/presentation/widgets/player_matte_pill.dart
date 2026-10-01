import 'package:flutter/material.dart';
import 'package:skystream/shared/widgets/matte_glass_pill.dart';

import 'hotstar_player_style.dart';

/// The shared matte glass surface with the player's control styling.
class PlayerMattePill extends StatelessWidget {
  const PlayerMattePill({super.key, required this.child});

  final Widget child;

  static const surface = MatteGlassPill.surface;
  static const focusInk = HotstarPlayerStyle.accent;

  static bool contains(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MatteControls>() != null;

  @override
  Widget build(BuildContext context) {
    return _MatteControls(
      child: MatteGlassPill(
        // The bar fades inside an opacity layer. Replacing its backdrop
        // avoids blending the filtered image twice during that fade.
        blendMode: BlendMode.src,
        child: child,
      ),
    );
  }
}

class _MatteControls extends InheritedWidget {
  const _MatteControls({required super.child});

  @override
  bool updateShouldNotify(_MatteControls oldWidget) => false;
}
