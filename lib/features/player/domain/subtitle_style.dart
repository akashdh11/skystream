/// Translating the app's subtitle preferences into libVLC's own scale.
///
/// Subtitles are rendered by the engine, not by Flutter, so these settings only
/// take effect if they are handed to libVLC when the player is created. Until
/// they were, VLC used its own default of `--freetype-rel-fontsize=16`, which
/// is very large on a full-screen video and is what "the subtitles are enormous"
/// actually was.
library;

import 'package:flutter/material.dart';
import 'package:vlc_player/vlc_player.dart';

import '../../settings/presentation/player_settings_provider.dart';

/// VLC's relative font size is **inverted and scale-free**: the rendered height
/// is roughly `videoHeight / relativeFontSize`, so a *smaller* number produces
/// *larger* text. VLC's own presets run 20 (smaller) to 6 (largest), with 16 as
/// its default.
///
/// The app's [PlayerSettings.subtitleSize] is a Flutter font size in logical
/// pixels, defaulting to 22. This constant maps the two so that the app default
/// lands just below VLC's default — i.e. noticeably smaller than what shipped —
/// while still tracking the user's slider in the right direction.
///
/// It is a calibration, not a derivation. Anchoring it here with the reasoning
/// visible is better than an unexplained number inside a widget.
const double _kRelativeSizeNumerator = 528;

/// Builds the engine-side subtitle style from the user's preferences.
VlcSubtitleStyle subtitleStyleFrom(PlayerSettings settings) {
  final size = settings.subtitleSize;
  final relative = size <= 0
      ? 24
      : (_kRelativeSizeNumerator / size).round().clamp(8, 60);

  final background = Color(settings.subtitleBackgroundColor).withValues(
    alpha: settings.subtitleBackgroundOpacity.clamp(0.0, 1.0),
  );

  return VlcSubtitleStyle(
    relativeFontSize: relative,
    color: Color(settings.subtitleColor),
    // A fully transparent background is the app's default, and VLC draws no
    // box for it — but the outline is what keeps white text legible over a
    // bright scene, so it is always on.
    backgroundColor: background.a == 0 ? null : background,
    outlineColor: const Color(0xFF000000),
    outlineThickness: 2,
  );
}
