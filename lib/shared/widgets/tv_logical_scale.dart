/// Gives a television more logical pixels to lay out in.
///
/// An Android TV reports about 960x540 dp whatever its panel is: a 1080p set
/// at density 2 and a 4K set at density 4 both land there, deliberately, so
/// one layout serves both. A desktop window of the same physical size reports
/// nearer 1800 dp. Nothing in this app scales itself up on a television - it
/// draws the same dp everywhere - but with half the canvas the same 36 dp
/// button covers twice the fraction of the screen, four posters fit across
/// instead of eight, and a hero title that fits one line on a laptop wraps.
///
/// This hands the tree [kTvLogicalWidth] dp of width and scales the result
/// back up to fill the panel, so the browsing UI breathes the way it does on a
/// desktop while every physical pixel is still used.
///
/// WHAT IT REPLACES. `main.dart` used to do this:
///
/// ```dart
/// MediaQuery(data: mq.copyWith(devicePixelRatio: 1.0), child: result)
/// ```
///
/// with a comment saying it clamped the density "for standard scaling". It
/// never did. Layout is in logical pixels and the dp-to-pixel mapping belongs
/// to the engine's `RenderView`; [MediaQueryData.devicePixelRatio] is a value
/// widgets *read*, not one that resizes anything. Its one real effect was on
/// `createLocalImageConfiguration`, which resolves asset variants off it - so
/// forcing 1.0 asked a 4K panel for 1x artwork.
///
/// NOT THE PLAYER. The video is an Android platform view by default
/// (`VlcPlayerConfig.defaultAndroidRenderer`, so libVLC keeps its hardware
/// decoder). Flutter sizes a platform view from its logical size and the
/// device pixel ratio, without folding in an ancestor transform, so a scaled
/// one is rendered at the pre-scale resolution and stretched: 4K video
/// upscaled from a 720-line surface. [TvLogicalScale] therefore asks
/// [playerRouteIsOnTop] and steps aside while the player is up - the player's
/// chrome has a ten-foot ramp of its own and wants none of this.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';

/// The width, in logical pixels, a television lays out in.
///
/// 1280 rather than the panel's own 960: a third more room, so a poster row
/// gains a card or two and the hero title stops wrapping, while everything
/// stays large enough to read from a sofa. Pushing it to 1440 would match a
/// laptop almost exactly and is a one-line change, but at that point the type
/// is sized for a desk rather than for a room.
const double kTvLogicalWidth = 1280;

/// Lays [child] out in [kTvLogicalWidth] dp and scales it to fill the view.
///
/// A pass-through unless [enabled]; the caller decides, because "is this a
/// television" is [DeviceProfile]'s answer and this widget has no business
/// asking it a second time.
class TvLogicalScale extends StatelessWidget {
  const TvLogicalScale({
    required this.enabled,
    required this.child,
    this.userScale = 1.0,
    this.logicalWidth = kTvLogicalWidth,
    this.router,
    super.key,
  });

  final bool enabled;

  /// The user-configured global UI scale multiplier (e.g. 0.85, 1.0, 1.15, 1.30).
  final double userScale;

  /// The width to lay out in. Overridable so a test can state one.
  final double logicalWidth;

  /// The router consulted for [playerRouteIsOnTop]. Null disables that check,
  /// which is what a test pumping this widget on its own wants.
  final GoRouter? router;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    // A width of zero happens for one frame on some embedders, and dividing by
    // it would hand the tree an infinite canvas.
    if (size.width <= 0) return child;

    // The video is a platform view and must be laid out at the panel's own
    // resolution; see this file's header.
    final router = this.router;
    if (router != null && playerRouteIsOnTop(router)) return child;

    // The base scale from the television layout rule if enabled, otherwise 1.0.
    final baseScale = (enabled && size.width < logicalWidth)
        ? size.width / logicalWidth
        : 1.0;

    final scale = baseScale * userScale;

    // Leave a screen that is at 1:1 scale alone.
    if ((scale - 1.0).abs() < 0.001) return child;

    final logical = size / scale;
    return MediaQuery(
      // Every inset is in the same logical pixels the size is, so each one has
      // to travel with it - a safe-area padding left at the panel's scale
      // would reserve three times the band it means.
      data: media.copyWith(
        size: logical,
        padding: media.padding / scale,
        viewPadding: media.viewPadding / scale,
        viewInsets: media.viewInsets / scale,
        systemGestureInsets: media.systemGestureInsets / scale,
        // A television's font scale is the set's, and the ten-foot ramp in
        // this app is already sized for the distance. Honouring both would
        // apply the room twice.
        textScaler: enabled ? TextScaler.noScaling : media.textScaler,
      ),
      // [FittedBox] rather than a bare [Transform]: the transform does not
      // constrain, and a [SizedBox] under one cannot shrink below the tight
      // constraints a route hands it - `BoxConstraints.enforce` clamps the
      // logical width straight back up to the panel's, which is how the first
      // attempt at this scaled an already-full-size tree and painted a third
      // of it off the edge.
      //
      // FittedBox lays its child out unbounded, so the [SizedBox] gets the
      // logical box it asks for, and then scales it to the constraints.
      // [BoxFit.fill] rather than `contain` only to absorb a sub-pixel
      // rounding difference: the logical size is the panel's divided by the
      // scale, so the two aspect ratios are the same and nothing is stretched.
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: logical.width,
          height: logical.height,
          child: child,
        ),
      ),
    );
  }
}
