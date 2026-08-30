import 'package:flutter/material.dart';

import '../widgets/hotstar_player_style.dart';

/// The vertical brightness / volume indicator shown while dragging.
///
/// Kept deliberately dumb: it renders a value someone else owns. The gesture
/// that changes it, the engine call and the timer that hides it all live in the
/// controls, so this cannot become a second owner of player state — which is
/// what the old player's gesture handler became.
class PlayerRail extends StatelessWidget {
  const PlayerRail({
    required this.icon,
    required this.value,
    required this.label,
    this.onLeft = true,
    super.key,
  });

  final IconData icon;

  /// 0..1 of the track, already normalised by the caller. Volume can exceed
  /// 100%, so this is the fraction of the *maximum*, not of 100%.
  final double value;

  /// Text shown above the track, e.g. `140%`.
  final String label;

  /// Brightness sits on the left, volume on the right, matching where the
  /// gesture started.
  final bool onLeft;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: onLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(
          left: onLeft ? 28 : 0,
          right: onLeft ? 0 : 28,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: HotstarPlayerStyle.primaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 6,
                  height: 132,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: value.clamp(0.0, 1.0),
                        widthFactor: 1,
                        child: const ColoredBox(
                          color: HotstarPlayerStyle.primaryText,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Icon(icon, color: HotstarPlayerStyle.primaryText, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
