/// Translating the app's subtitle preferences into libVLC's own scale.
///
/// Two renderers read these. libVLC draws the tracks inside a video, and takes
/// these settings when the player is created - otherwise it applies its own
/// default of `--freetype-rel-fontsize=16`, which is very large on a
/// full-screen video. Size, colours, the box, the outline and the lift it also
/// takes while the video plays ([subtitleLookFrom]); bold, the font, the text
/// opacity and the encoding only at creation. SkyStream draws subtitle files
/// itself, from the same numbers, so a file and an embedded track look alike.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:vlc_player/vlc_player.dart';

import '../../settings/presentation/player_settings_provider.dart';

/// VLC's relative font size is inverted and scale-free: the rendered height is
/// roughly `videoHeight / relativeFontSize`, so a smaller number produces
/// larger text. VLC's own presets run 20 (smaller) to 6 (largest), with 16 as
/// its default.
///
/// [PlayerSettings.subtitleSize] is a Flutter font size in logical pixels,
/// defaulting to 22. This numerator maps the two so the app default lands just
/// below VLC's default while still tracking the slider in the right direction.
/// It is a calibration, not a derivation.
const double _kRelativeSizeNumerator = 528;

/// libVLC's relative size for [size], the app's own font size: its inverted
/// scale, held to 8..60 - the whole number `--freetype-rel-fontsize` takes
/// when a player is created, and nothing else.
int relativeSizeFor(double size) =>
    size <= 0 ? 24 : (_kRelativeSizeNumerator / size).round().clamp(8, 60);

/// The same scale as [relativeSizeFor] before it is rounded and held at 8,
/// which is what both renderers draw from once a player exists.
///
/// Rounded, 42 of the 70 steps from 10 to 80 - all of them from 63 up - drew
/// the same text as the step before while the number moved. Unrounded, every
/// step is a size of its own: SkyStream's subtitles are drawn at it, and
/// libVLC's are scaled to it from whatever whole number the player was
/// created with ([subtitleLookFrom]). Held between 80's 6.6 and the 60
/// [relativeSizeFor] stops at.
double subtitleRelativeSize(double size) => size <= 0
    ? 24
    : (_kRelativeSizeNumerator / size).clamp(
        _kRelativeSizeNumerator / 80,
        60.0,
      );

/// Builds the engine-side subtitle style from the user's preferences: what a
/// player is created with.
VlcSubtitleStyle subtitleStyleFrom(PlayerSettings settings) {
  final background = Color(settings.subtitleBackgroundColor)
      .withValues(alpha: settings.subtitleBackgroundOpacity.clamp(0.0, 1.0));
  final encoding = settings.subtitleEncoding;

  return VlcSubtitleStyle(
    fontFamily: subtitleFontFamily(settings.subtitleFont),
    relativeFontSize: relativeSizeFor(settings.subtitleSize),
    // The text opacity takes the place of the stored colour's own alpha, as
    // the background's opacity does below; the package hands the alpha to
    // libVLC as `--freetype-opacity`.
    color: Color(settings.subtitleColor)
        .withValues(alpha: settings.subtitleTextOpacity.clamp(0.0, 1.0)),
    // Said only when on: off is libVLC's own default, so a player created
    // from settings nobody has touched is created exactly as before.
    bold: settings.subtitleBold ? true : null,
    // The stored colour's own alpha is discarded above, so opacity 0 is the
    // only way to ask for no box at all — and null, not a transparent colour,
    // is how VLC is told to draw none. The outline is drawn whatever the box:
    // it keeps white text legible over a bright scene with no box behind it,
    // unless the viewer asked for none.
    backgroundColor: background.a == 0 ? null : background,
    outlineColor: const Color(0xFF000000),
    outlineThickness: subtitleOutlineThickness(settings.subtitleOutline),
    encoding: encoding.isEmpty ? null : encoding,
  );
}

/// The look libVLC's lines take while the video plays: see
/// `VlcPlayerController.setSubtitleLook`.
///
/// [createdRelativeSize] is the relative size the player was created with
/// ([relativeSizeFor] of the size in the settings it was created from): libVLC
/// scales its text as a percent of that, so twice the size is 200 whatever
/// the player started at. The size it scales to is unrounded
/// ([subtitleRelativeSize]), so libVLC's lines match SkyStream's at every
/// step, the player's first look included.
///
/// The text's opacity, bold and font are not here - they stay as the player
/// was created - and neither colour carries its stored alpha, so a look
/// changes only when something it carries does.
VlcSubtitleLook subtitleLookFrom(
  PlayerSettings settings, {
  required int createdRelativeSize,
}) {
  final scale =
      100 * createdRelativeSize / subtitleRelativeSize(settings.subtitleSize);
  return VlcSubtitleLook(
    textScale: scale.round().clamp(10, 500),
    color: _opaque(settings.subtitleColor),
    backgroundColor: _opaque(settings.subtitleBackgroundColor),
    // Zero is no box, the way the creation-time style says it with null.
    backgroundOpacity:
        (settings.subtitleBackgroundOpacity.clamp(0.0, 1.0) * 255).round(),
    outlineThickness: subtitleOutlineThickness(settings.subtitleOutline),
    raise: settings.subtitleRaise,
  );
}

Color _opaque(int argb) => Color(0xFF000000 | (argb & 0xFFFFFF));

/// Space between the subtitle lines and the edge of the player area, as a
/// share of the frame height. The side-car subtitle and the anchored
/// embedded look both measure from it, so a file and a track inside the
/// video sit at the same place.
const double kSubtitleEdgeMargin = 0.06;

/// The screen y (from the top of the player area) the subtitle lines'
/// bottom edge sits at, for a picture whose on-screen rect is [picture] in
/// an area [area] big: a small fixed margin above the picture's bottom
/// edge, plus the viewer's lift — the normal Netflix/YouTube place. The
/// margin is a share of the picture's own height, so it is the same low
/// place in every fit and at every pinch zoom. When the picture's bottom is
/// cropped below the area (cover zoom), the lines are kept on screen
/// instead: no lower than the edge margin above the area's bottom, so they
/// are never cut off. Fixed — it never follows the bottom chrome, so the
/// lines never move when the controls show or hide. (anchoring to the chrome height would float the lines a full bar
/// above the picture even with the controls down.)
double subtitleTargetY(Size area, Rect picture, double lift) {
  final margin = picture.height * kSubtitleEdgeMargin;
  final floor =
      area.height - subtitleFrameHeight(area) * kSubtitleEdgeMargin;
  final target =
      picture.bottom - margin - lift.clamp(0.0, 0.5) * picture.height;
  return math.min(target, floor);
}

/// The look libVLC's lines take when their place on screen is fixed, not
/// the picture's: the subtitle stays where the side-car one sits — just
/// above the picture's bottom edge — whatever the fit or the pinch zoom does
/// to the picture under it.
///
/// libVLC draws an embedded track's lines INTO the picture, at the bottom
/// of the decoded frame, so a fit that letterboxes the picture or a pinch
/// that scales it moves and scales the lines with it: in Zoom a line is
/// cut off below the screen, in Stretch the bar covers it, in Fit it sits
/// higher and smaller. The look is the only handle on those lines while
/// they play — `sub-text-scale` for their size and `sub-margin` (through
/// [VlcSubtitleLook.raise], a share of the picture's height) for how far
/// above the picture's bottom they sit — so this recomputes both from the
/// picture's place on screen, and the lines land in the same place the
/// side-car subtitle does, at the same size it draws.
///
/// [screen] is the player area, [video] the decoded frame, [fit] how the
/// picture is fitted into it, and [pinchScale] the pinch zoom over it (1.0
/// un-zoomed). The target is the picture's bottom edge, a small fixed
/// margin above it — see [subtitleTargetY] — never the bottom chrome, so
/// the lines never move when the controls show or hide. Where either size
/// is unknown, the unanchored look, which is what a player took before.
VlcSubtitleLook subtitleLookAnchored(
  PlayerSettings settings, {
  required int createdRelativeSize,
  required Size screen,
  required Size video,
  required VlcVideoFit fit,
  double pinchScale = 1.0,
}) {
  final base = subtitleLookFrom(
    settings,
    createdRelativeSize: createdRelativeSize,
  );
  if (screen.isEmpty || video.isEmpty) return base;
  // The picture on screen, centred, then pinched about the screen's centre
  // — the same transform the player's own zoom applies over it. The scale
  // is the FittedBox's: contain takes the smaller of the two ratios,
  // cover the larger, fill each of them, none no scaling at all. (Its
  // `destination` is the rect inside the widget, not the picture's scaled
  // size — for cover it is the widget itself, with the picture cropped
  // outside it — so the scale is worked out here instead.)
  final double scaleX;
  final double scaleY;
  switch (fit) {
    case VlcVideoFit.contain:
      final scale = math.min(
        screen.width / video.width,
        screen.height / video.height,
      );
      scaleX = scale;
      scaleY = scale;
    case VlcVideoFit.cover:
      final scale = math.max(
        screen.width / video.width,
        screen.height / video.height,
      );
      scaleX = scale;
      scaleY = scale;
    case VlcVideoFit.fill:
      scaleX = screen.width / video.width;
      scaleY = screen.height / video.height;
    case VlcVideoFit.none:
      scaleX = 1.0;
      scaleY = 1.0;
  }
  final zoom = pinchScale.isFinite && pinchScale > 0 ? pinchScale : 1.0;
  final displayed = Rect.fromCenter(
    center: screen.center(Offset.zero),
    width: video.width * scaleX * zoom,
    height: video.height * scaleY * zoom,
  );
  final displayScaleY = scaleY * zoom;
  if (displayScaleY <= 0) return base;
  // The size the side-car subtitle draws at in this area, so a track inside
  // the video reads the same size as a subtitle file: the picture's own
  // size, undone, is the text scale that lands it there.
  final targetSize = subtitleFontSize(settings, screen);
  final textScale =
      (100 * createdRelativeSize * targetSize /
              (video.height * displayScaleY))
          .round()
          .clamp(10, 500);
  // Where the lines land: just above the picture's bottom edge, not the
  // screen's — see [subtitleTargetY]. The chrome height is deliberately
  // not in it: anchoring to it would float the lines a full bar above
  // the picture even with the controls down.
  final targetY = subtitleTargetY(screen, displayed, settings.subtitleRaise);
  // How far above the picture's bottom the lines must sit to land there,
  // in the picture's own pixels, as a share of its height.
  final raise = ((displayed.bottom - targetY) / displayScaleY / video.height)
      .clamp(0.0, 0.5);
  return VlcSubtitleLook(
    textScale: textScale,
    color: base.color,
    backgroundColor: base.backgroundColor,
    backgroundOpacity: base.backgroundOpacity,
    outlineThickness: base.outlineThickness,
    raise: raise,
  );
}


/// libVLC's outline thickness for [outline], a percent of the glyph: its own
/// presets are 2, 4 and 6, and 2 is the outline every install had before
/// this was a setting.
int subtitleOutlineThickness(SubtitleOutline outline) => switch (outline) {
  SubtitleOutline.none => 0,
  SubtitleOutline.thin => 2,
  SubtitleOutline.normal => 4,
  SubtitleOutline.thick => 6,
};

/// The stroke SkyStream outlines its own subtitles with for [outline], in
/// logical pixels: thin is the 2 every install had before this was a setting,
/// and the heavier two step up from it.
double subtitleOutlineWidth(SubtitleOutline outline) => switch (outline) {
  SubtitleOutline.none => 0,
  SubtitleOutline.thin => 2,
  SubtitleOutline.normal => 3.5,
  SubtitleOutline.thick => 5,
};

/// The family both renderers draw [font] in on [platform] - the one the app
/// runs on unless told - or null for [SubtitleFont.standard], each renderer's
/// own. One table for both, so a subtitle file and a track inside the video
/// ask for the same family.
String? subtitleFontFamily(SubtitleFont font, {TargetPlatform? platform}) {
  final on = platform ?? defaultTargetPlatform;
  return switch (font) {
    SubtitleFont.standard => null,
    SubtitleFont.serif => switch (on) {
      TargetPlatform.iOS ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => 'Times New Roman',
      TargetPlatform.android ||
      TargetPlatform.linux ||
      TargetPlatform.fuchsia => 'serif',
    },
    SubtitleFont.monospace => switch (on) {
      TargetPlatform.iOS || TargetPlatform.macOS => 'Menlo',
      TargetPlatform.windows => 'Consolas',
      TargetPlatform.android ||
      TargetPlatform.linux ||
      TargetPlatform.fuchsia => 'monospace',
    },
  };
}

/// Height of the video frame subtitles are scaled against.
///
/// Playback is landscape, so the frame is as tall as the *short* edge of the
/// window no matter which way it is held. On a television the window is
/// already landscape and this is simply its height.
double subtitleFrameHeight(Size window) =>
    math.min(window.width, window.height);

/// The font size [settings] draw subtitles at in a player [area] big:
/// libVLC's rule - the frame height over the relative size - which
/// SkyStream's own subtitles follow too, at the unrounded relative size
/// ([subtitleRelativeSize]).
double subtitleFontSize(PlayerSettings settings, Size area) =>
    subtitleFrameHeight(area) / subtitleRelativeSize(settings.subtitleSize);
