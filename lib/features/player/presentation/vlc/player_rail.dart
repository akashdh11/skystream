import 'package:flutter/material.dart';

import '../widgets/hotstar_player_style.dart';

/// The frameless brightness / volume indicator shown while dragging.
/// Gesture handling, engine updates and dismissal remain in the controls.
class PlayerRail extends StatelessWidget {
  const PlayerRail({
    required this.icon,
    required this.value,
    required this.semanticLabel,
    this.maxValue = 1,
    this.onLeft = true,
    super.key,
  }) : assert(maxValue >= 1);

  final IconData icon;

  /// 1 is normal full volume or full brightness. Volume may exceed 1.
  final double value;

  /// The user's volume ceiling, e.g. 1.5 for 150%. Brightness stays at 1.
  final double maxValue;

  /// Accessible name; the value is announced without a visible number.
  final String semanticLabel;

  /// Volume stays on the left and brightness on the right, independently of
  /// which configurable gesture edge the viewer uses.
  final bool onLeft;

  /// Orange marks amplified volume above the normal white fill.
  static const Color boostColor = Color(0xFFFF9800);

  @override
  Widget build(BuildContext context) {
    final level = value.clamp(0.0, maxValue);
    final normal = level.clamp(0.0, 1.0);
    final boost = maxValue > 1
        ? ((level - 1) / (maxValue - 1)).clamp(0.0, 1.0)
        : 0.0;

    return IgnorePointer(
      child: Semantics(
        label: semanticLabel,
        value: '${(level * 100).round()}%',
        child: ExcludeSemantics(
          child: Align(
            alignment: onLeft ? Alignment.centerLeft : Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(
                left: onLeft ? 28 : 0,
                right: onLeft ? 0 : 28,
              ),
              child: SizedBox(
                width: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      color: HotstarPlayerStyle.primaryText,
                      size: 20,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 5,
                      height: 120,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2.5),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(color: Color(0x33FFFFFF)),
                            _fill(normal, HotstarPlayerStyle.primaryText),
                            // A second pass over the full normal bar: unity
                            // stays full while orange shows boost headroom used.
                            if (boost > 0) _fill(boost, boostColor),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fill(double fraction, Color color) => Align(
    alignment: Alignment.bottomCenter,
    child: FractionallySizedBox(
      heightFactor: fraction,
      widthFactor: 1,
      child: ColoredBox(color: color),
    ),
  );
}
