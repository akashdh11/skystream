/// Typed configuration that compiles to libVLC command-line options.
///
/// The controller accepts a raw `List<String> options`, which is flexible but
/// pushes every caller into hand-writing VLC option strings, remembering their
/// exact spelling, and re-deriving the same defaults. Everything in this file
/// is a typed, documented stand-in for that: build a [VlcPlayerConfig], call
/// [VlcPlayerConfig.toOptions], and pass the result.
///
/// Nothing here is app-specific — these are plain VLC concepts, so the same
/// config works for any host application.
///
/// Raw options remain fully supported and are never removed; a config is
/// merged with, not a replacement for, [VlcPlayerConfig.extraOptions].
library;

import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

/// Hardware-accelerated decoding preference, mapped to `--avcodec-hw`.
enum VlcHardwareAcceleration {
  /// Let VLC pick a hardware decoder if one is available (`any`).
  automatic,

  /// Force software decoding (`none`).
  ///
  /// Useful as a fallback after a hardware decoder has failed for the current
  /// session — some low-end decoders fail only on specific codec profiles.
  disabled,

  /// Leave the option unset and use whatever the platform build defaults to.
  platformDefault,
}

/// How aggressively the decoder may skip work when it falls behind.
///
/// Maps to `--avcodec-skiploopfilter` / `--avcodec-skip-frame`. Raising this
/// trades picture quality for the ability to keep up on a weak CPU, which is
/// the usual trade on low-end set-top boxes.
enum VlcDecodeThrift {
  /// Decode everything. Best quality.
  none,

  /// Skip the loop filter on non-reference frames. Small quality cost.
  light,

  /// Skip the loop filter on non-keyframes and drop non-reference frames.
  aggressive,
}

/// Which rendition an adaptive (HLS/DASH) stream should start on.
enum VlcAdaptiveLogic {
  /// Estimate available bandwidth and adapt (VLC default).
  rate,

  /// Always pick the lowest rendition. Fastest start, lowest quality.
  lowest,

  /// Always pick the highest rendition.
  highest;

  String get _value => switch (this) {
    VlcAdaptiveLogic.rate => 'rate',
    VlcAdaptiveLogic.lowest => 'lowest',
    VlcAdaptiveLogic.highest => 'highest',
  };
}

/// Network and HTTP behaviour.
@immutable
class VlcNetworkConfig {
  const VlcNetworkConfig({
    this.networkCaching,
    this.liveCaching,
    this.fileCaching,
    this.userAgent,
    this.referer,
    this.adaptiveLogic,
    this.adaptiveMaxHeight,
  });

  /// Buffer held for network streams, in milliseconds (`--network-caching`).
  ///
  /// VLC's default is 1000. Raise it on unreliable connections at the cost of
  /// start-up latency; lower it for snappier seeks on a good connection.
  final int? networkCaching;

  /// Buffer held for live streams, in milliseconds (`--live-caching`).
  final int? liveCaching;

  /// Buffer held for local files, in milliseconds (`--file-caching`).
  final int? fileCaching;

  /// Default `User-Agent` for HTTP media (`--http-user-agent`).
  ///
  /// Per-source headers on `VlcMediaSource.httpHeaders` take precedence; this
  /// is the fallback for sources that do not carry one. Many CDNs reject the
  /// stock libVLC agent, so setting a browser agent here is a common need.
  final String? userAgent;

  /// Default `Referer` for HTTP media (`--http-referrer`).
  final String? referer;

  /// Rendition-selection strategy for HLS/DASH (`--adaptive-logic`).
  final VlcAdaptiveLogic? adaptiveLogic;

  /// Cap on adaptive rendition height, e.g. 1080 (`--adaptive-maxheight`).
  ///
  /// Pinning this below the panel resolution is an effective way to keep a
  /// weak device from selecting a rendition it cannot decode.
  final int? adaptiveMaxHeight;

  /// Emits the `--…` options this config represents.
  List<String> toOptions() {
    return <String>[
      if (networkCaching != null) '--network-caching=$networkCaching',
      if (liveCaching != null) '--live-caching=$liveCaching',
      if (fileCaching != null) '--file-caching=$fileCaching',
      if (userAgent != null && userAgent!.isNotEmpty)
        '--http-user-agent=$userAgent',
      if (referer != null && referer!.isNotEmpty) '--http-referrer=$referer',
      if (adaptiveLogic != null) '--adaptive-logic=${adaptiveLogic!._value}',
      if (adaptiveMaxHeight != null) '--adaptive-maxheight=$adaptiveMaxHeight',
    ];
  }
}

/// Decoder behaviour.
@immutable
class VlcDecodingConfig {
  const VlcDecodingConfig({
    this.hardwareAcceleration = VlcHardwareAcceleration.platformDefault,
    this.decodeThrift = VlcDecodeThrift.none,
    this.dropLateFrames,
    this.threads,
  });

  /// Hardware decoding preference (`--avcodec-hw`).
  final VlcHardwareAcceleration hardwareAcceleration;

  /// How much decode work may be skipped when running behind.
  final VlcDecodeThrift decodeThrift;

  /// Whether to drop frames that arrive too late (`--drop-late-frames`).
  ///
  /// Leaving this null uses VLC's default (enabled). Disabling it favours
  /// completeness over smoothness.
  final bool? dropLateFrames;

  /// Decoder thread count (`--avcodec-threads`). 0 lets VLC choose.
  final int? threads;

  /// Emits the `--…` options this config represents.
  List<String> toOptions() {
    // --avcodec-skiploopfilter: 0 none, 1 non-ref, 2 bidir, 3 non-key, 4 all.
    // --avcodec-skip-frame:     0 none, 1 non-ref, 2 bidir, 3 non-key, 4 all.
    final (int loopFilter, int skipFrame) = switch (decodeThrift) {
      VlcDecodeThrift.none => (0, 0),
      VlcDecodeThrift.light => (1, 0),
      VlcDecodeThrift.aggressive => (3, 1),
    };

    return <String>[
      switch (hardwareAcceleration) {
        VlcHardwareAcceleration.automatic => '--avcodec-hw=any',
        VlcHardwareAcceleration.disabled => '--avcodec-hw=none',
        VlcHardwareAcceleration.platformDefault => '',
      },
      if (decodeThrift != VlcDecodeThrift.none) ...<String>[
        '--avcodec-skiploopfilter=$loopFilter',
        '--avcodec-skip-frame=$skipFrame',
      ],
      if (dropLateFrames != null)
        dropLateFrames! ? '--drop-late-frames' : '--no-drop-late-frames',
      if (threads != null) '--avcodec-threads=$threads',
    ]..removeWhere((option) => option.isEmpty);
  }
}

/// Where a subtitle sits on screen.
enum VlcSubtitleAlignment {
  left,
  center,
  right;

  /// `--freetype-text-align` value.
  String get _value => switch (this) {
    VlcSubtitleAlignment.left => 'left',
    VlcSubtitleAlignment.center => 'center',
    VlcSubtitleAlignment.right => 'right',
  };
}

/// Appearance of VLC-rendered subtitles.
///
/// Note that these are libVLC *instance* options: VLC 3.x cannot restyle
/// subtitles on an already-running player, so changing a style means creating
/// a new player. A host that needs live restyling should render subtitles
/// itself and leave VLC's renderer disabled.
@immutable
class VlcSubtitleStyle {
  const VlcSubtitleStyle({
    this.fontFamily,
    this.fontSize,
    this.relativeFontSize,
    this.color,
    this.bold,
    this.outlineColor,
    this.outlineThickness,
    this.shadowColor,
    this.shadowDistance,
    this.backgroundColor,
    this.marginPixels,
    this.alignment,
    this.autoDetectFiles,
  });

  /// Font family name (`--freetype-font`).
  final String? fontFamily;

  /// Absolute size in pixels (`--freetype-fontsize`). 0 means auto.
  ///
  /// Prefer [relativeFontSize] — an absolute size that suits a phone is
  /// unreadable on a television.
  final int? fontSize;

  /// Size relative to video height (`--freetype-rel-fontsize`).
  ///
  /// VLC's own scale: smaller numbers mean larger text (20 is roughly
  /// "large", 16 "larger"). This scales correctly across form factors.
  final int? relativeFontSize;

  /// Text colour (`--freetype-color` + `--freetype-opacity`).
  final Color? color;

  /// Whether to embolden (`--freetype-bold`).
  final bool? bold;

  /// Outline colour (`--freetype-outline-color` + opacity).
  final Color? outlineColor;

  /// Outline thickness in pixels (`--freetype-outline-thickness`).
  final int? outlineThickness;

  /// Drop-shadow colour (`--freetype-shadow-color` + opacity).
  final Color? shadowColor;

  /// Drop-shadow distance (`--freetype-shadow-distance`).
  final int? shadowDistance;

  /// Box colour behind the text (`--freetype-background-color` + opacity).
  final Color? backgroundColor;

  /// Distance from the bottom of the video, in pixels (`--sub-margin`).
  final int? marginPixels;

  /// Horizontal alignment (`--freetype-text-align`).
  final VlcSubtitleAlignment? alignment;

  /// Whether VLC should auto-load sidecar subtitle files next to the media
  /// (`--sub-autodetect-file`).
  ///
  /// Hosts that manage their own subtitle list usually want this off, so VLC
  /// does not silently add tracks the host does not know about.
  final bool? autoDetectFiles;

  /// VLC colour options take a 24-bit integer; opacity is a separate 0-255.
  static int _rgb(Color color) {
    final int r = (color.r * 255.0).round() & 0xff;
    final int g = (color.g * 255.0).round() & 0xff;
    final int b = (color.b * 255.0).round() & 0xff;
    return (r << 16) | (g << 8) | b;
  }

  static int _alpha(Color color) => (color.a * 255.0).round() & 0xff;

  /// Emits the `--…` options this style represents.
  List<String> toOptions() {
    return <String>[
      if (fontFamily != null && fontFamily!.isNotEmpty)
        '--freetype-font=$fontFamily',
      if (fontSize != null) '--freetype-fontsize=$fontSize',
      if (relativeFontSize != null) '--freetype-rel-fontsize=$relativeFontSize',
      if (color != null) ...<String>[
        '--freetype-color=${_rgb(color!)}',
        '--freetype-opacity=${_alpha(color!)}',
      ],
      if (bold != null) bold! ? '--freetype-bold' : '--no-freetype-bold',
      if (outlineColor != null) ...<String>[
        '--freetype-outline-color=${_rgb(outlineColor!)}',
        '--freetype-outline-opacity=${_alpha(outlineColor!)}',
      ],
      if (outlineThickness != null)
        '--freetype-outline-thickness=$outlineThickness',
      if (shadowColor != null) ...<String>[
        '--freetype-shadow-color=${_rgb(shadowColor!)}',
        '--freetype-shadow-opacity=${_alpha(shadowColor!)}',
      ],
      if (shadowDistance != null) '--freetype-shadow-distance=$shadowDistance',
      if (backgroundColor != null) ...<String>[
        '--freetype-background-color=${_rgb(backgroundColor!)}',
        '--freetype-background-opacity=${_alpha(backgroundColor!)}',
      ],
      if (marginPixels != null) '--sub-margin=$marginPixels',
      if (alignment != null) '--freetype-text-align=${alignment!._value}',
      if (autoDetectFiles != null)
        autoDetectFiles! ? '--sub-autodetect-file' : '--no-sub-autodetect-file',
    ];
  }
}

/// Top-level VLC instance configuration.
///
/// Compose the groups you care about and pass `config.toOptions()` as the
/// controller's `options`. Groups left null contribute nothing, so VLC's own
/// defaults apply.
@immutable
class VlcPlayerConfig {
  const VlcPlayerConfig({
    this.network,
    this.decoding,
    this.subtitleStyle,
    this.showVideoTitle = false,
    this.verbose = false,
    this.extraOptions = const <String>[],
  });

  /// Network and HTTP behaviour.
  final VlcNetworkConfig? network;

  /// Decoder behaviour.
  final VlcDecodingConfig? decoding;

  /// Appearance of VLC-rendered subtitles.
  final VlcSubtitleStyle? subtitleStyle;

  /// Whether VLC overlays the media title when playback starts.
  ///
  /// Defaults to false: an embedded player almost always draws its own title,
  /// and VLC's overlay appears on top of it.
  final bool showVideoTitle;

  /// Whether to raise libVLC log verbosity. Defaults to quiet.
  final bool verbose;

  /// Raw options appended verbatim, after everything above.
  ///
  /// The escape hatch: anything this class does not model can still be passed,
  /// and because these come last they win over the generated options.
  final List<String> extraOptions;

  /// Builds the complete option list, in precedence order.
  List<String> toOptions() {
    return <String>[
      if (!showVideoTitle) '--no-video-title-show',
      if (verbose) '--verbose=2' else '--quiet',
      ...?network?.toOptions(),
      ...?decoding?.toOptions(),
      ...?subtitleStyle?.toOptions(),
      ...extraOptions,
    ];
  }

  /// Returns a copy with the given fields replaced.
  VlcPlayerConfig copyWith({
    VlcNetworkConfig? network,
    VlcDecodingConfig? decoding,
    VlcSubtitleStyle? subtitleStyle,
    bool? showVideoTitle,
    bool? verbose,
    List<String>? extraOptions,
  }) {
    return VlcPlayerConfig(
      network: network ?? this.network,
      decoding: decoding ?? this.decoding,
      subtitleStyle: subtitleStyle ?? this.subtitleStyle,
      showVideoTitle: showVideoTitle ?? this.showVideoTitle,
      verbose: verbose ?? this.verbose,
      extraOptions: extraOptions ?? this.extraOptions,
    );
  }
}

/// What a libVLC-backed player can and cannot do.
///
/// Hosts that support more than one playback engine tend to hard-code these
/// limits at the call site, which then drifts. Reading them from here keeps
/// the capability description next to the implementation it describes.
abstract final class VlcPlayerCapabilities {
  /// Highest volume accepted by `setVolume`, as a percentage.
  ///
  /// libVLC amplifies above 100%, unlike the platform-native players on most
  /// systems.
  static const int maxVolumePercent = 200;

  /// Whether the engine can offset subtitles against video.
  static const bool supportsSubtitleDelay = true;

  /// Whether the engine can offset audio against video.
  static const bool supportsAudioDelay = true;

  /// Whether the engine can load a subtitle file that is not in the container.
  static const bool supportsExternalSubtitles = true;

  /// Whether subtitle appearance can be changed while a player is running.
  ///
  /// False for VLC 3.x: styling is fixed at instance creation, so a host that
  /// offers live restyling must recreate the player or render its own
  /// subtitles. See [VlcSubtitleStyle].
  static const bool supportsRuntimeSubtitleStyling = false;

  /// Whether the engine reports HDR metadata or performs tone mapping.
  ///
  /// False: libVLC exposes no tone-mapping controls comparable to mpv's
  /// `vo_gpu`. A host with HDR settings should hide them for this engine.
  static const bool supportsToneMapping = false;

  /// Playback-rate bounds accepted by `setPlaybackSpeed`.
  static const double minPlaybackSpeed = 0.25;
  static const double maxPlaybackSpeed = 4.0;
}
