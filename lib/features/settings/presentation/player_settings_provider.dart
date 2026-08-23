import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/storage/settings_repository.dart';
import '../../player/data/subtitle_providers.dart';
import '../../../core/network/dio_client_provider.dart';

part 'player_settings_provider.g.dart';

enum PlayerGesture { brightness, volume, none }

/// Preferred playback quality tier. Plugins don't guarantee a specific
/// quality but sources are sorted so the preferred tier is tried first.
/// Default Wi-Fi quality ceiling for users who have never opened the setting.
///
/// Was 4K. media_kit sizes its render target to the *source* resolution — the
/// `videoParams` listener pushes the decoded width/height straight into
/// SetSize/SetSurfaceSize and AndroidVideoController.setSize() throws
/// UnsupportedError, so there is no in-app escape once a 4K stream is chosen.
/// A 3840x2160 buffer is ~33 MB per frame, filled twice (render + composite),
/// on every device including 1 GB TV sticks.
///
/// 1080p matches the existing mobile default and is a ceiling, not a floor:
/// anyone who wants 4K can still select it, and an explicit stored choice is
/// never overwritten — this only changes what happens when nothing was chosen.
const QualityPreference kDefaultWifiQuality = QualityPreference.q1080;

enum QualityPreference {
  any, // no preference — keep original order
  q360, // 360p
  q480, // 480p / SD
  q720, // 720p / HD
  q1080, // 1080p / FHD
  q4k, // 4K / UHD / 2160p
}

/// Controls how the quality preference threshold is applied when streams are loaded.
enum QualityFilterMode {
  any, // Sort only — show everything (current behaviour)
  atOrAbove, // Hide sources strictly below the preferred quality tier
  atOrBelow, // Hide sources strictly above the preferred tier (data-saver mode)
}

/// How HDR (HDR10 / HDR10+ / HLG / Dolby Vision) content is rendered.
///
/// Only applies to the internal mpv/libmpv engine — the video_view engines
/// (ExoPlayer / AVPlayer) manage HDR themselves and ignore these.
enum HdrMode {
  /// Let mpv decide (current behaviour, no explicit properties set).
  auto,

  /// Forward HDR metadata to the display so a real HDR panel switches into
  /// HDR mode. Best on TVs/phones with genuine HDR support.
  passthrough,

  /// Tone-map HDR down to SDR. Fixes the washed-out / grey look HDR files
  /// get on SDR panels.
  toneMapSdr,
}

/// Tone-mapping curve used when [HdrMode.toneMapSdr] is active.
enum ToneMapCurve { auto, spline, bt2390, bt2446a, hable, mobius, reinhard }

extension ToneMapCurveX on ToneMapCurve {
  /// mpv's `tone-mapping` property value.
  String get mpvValue => switch (this) {
    ToneMapCurve.auto => 'auto',
    ToneMapCurve.spline => 'spline',
    ToneMapCurve.bt2390 => 'bt.2390',
    ToneMapCurve.bt2446a => 'bt.2446a',
    ToneMapCurve.hable => 'hable',
    ToneMapCurve.mobius => 'mobius',
    ToneMapCurve.reinhard => 'reinhard',
  };

  String get label => switch (this) {
    ToneMapCurve.auto => 'Auto (recommended)',
    ToneMapCurve.spline => 'Spline — balanced',
    ToneMapCurve.bt2390 => 'BT.2390 — reference',
    ToneMapCurve.bt2446a => 'BT.2446a — bright scenes',
    ToneMapCurve.hable => 'Hable — filmic',
    ToneMapCurve.mobius => 'Mobius — preserves mid-tones',
    ToneMapCurve.reinhard => 'Reinhard — soft highlights',
  };
}

class PlayerSettings {
  final PlayerGesture leftGesture;
  final PlayerGesture rightGesture;
  final bool doubleTapEnabled;
  final bool swipeSeekEnabled;
  final int seekDuration;
  final String defaultResizeMode;
  final double subtitleSize;
  final int subtitleColor;
  final int subtitleBackgroundColor;
  final double subtitleBackgroundOpacity;
  final bool hardwareDecoding;
  final String?
  preferredPlayer; // null = internal, 'vlc' / 'mpv' etc. = external
  final int readaheadSeconds;
  final double subtitlePosition;

  // New subtitle appearance properties
  final double? subFixedTextSize;
  final int? subTypeface;
  final String? subTypefaceFilePath;
  final int subEdgeType;
  final double? subEdgeSize;
  final double? subBackgroundRadius;
  final int subElevation;
  final bool subRemoveBloat;
  final bool subRemoveCaptions;
  final bool subUpperCase;
  final bool subBold;
  final bool subItalic;
  final int subForegroundColor;
  final int subBackgroundColor;
  final int subEdgeColor;
  final double subBackgroundOpacity;
  final int? subAlignment;

  /// Quality to prefer when on Wi-Fi. Default: 4K (best available).
  final QualityPreference wifiQuality;

  /// Quality to prefer when on mobile data. Default: 1080p.
  final QualityPreference mobileQuality;

  /// Controls whether streams below/above the quality preference are hidden.
  /// Default: [QualityFilterMode.any] (sort only, no filtering).
  final QualityFilterMode qualityFilterMode;

  /// How HDR content is rendered. Default [HdrMode.auto] preserves the
  /// previous behaviour exactly (no HDR properties are written to mpv).
  final HdrMode hdrMode;

  /// Curve used when tone-mapping HDR to SDR.
  final ToneMapCurve toneMapCurve;

  /// Per-scene peak detection. Improves highlight detail on HDR sources but
  /// costs GPU time, so it's opt-out on weaker devices.
  final bool hdrComputePeak;

  /// Display peak luminance in nits. 0 = auto-detect from the display.
  final int hdrTargetPeak;

  /// Boosts SDR content into the HDR range. Off by default: it's an effect,
  /// not a correction, and it looks wrong on plenty of content.
  final bool inverseToneMapping;

  /// Maximum volume the player allows, as a percentage (100–200).
  /// mpv can amplify beyond the source level; 100 disables the boost.
  final int maxVolumePercent;

  /// When true, the progress-bar time header shows the remaining time
  /// (e.g. "-1:23:45 / 2:00:00") instead of the elapsed time. Sticky
  /// across sessions because users who prefer one view almost always
  /// want it always.
  final bool showRemainingTime;

  /// Default playback speed restored on every new playback session.
  /// 1.0 = normal. Stored as a double to support fractional values
  /// (1.25, 1.5, 1.75, 2.0). Capped at the engine's supported range
  /// at playback time (`maxPlaybackSpeed`).
  final double defaultPlaybackSpeed;

  /// Toggles for individual player control-bar buttons. All default to
  /// visible. Sources, Audio Tracks and Subtitles are intentionally not
  /// toggleable because they are essential.
  final bool showPip;
  final bool showResize;
  final bool showRotate;
  final bool showPlaybackSpeed;
  final bool showEpisodes;

  // Subtitle Accounts
  final String osUsername;
  final String osPassword;
  final String osApiKey;
  final String subdlEmail;
  final String subdlPassword;
  final String subdlApiKey;
  final String subsourceApiKey;

  const PlayerSettings({
    this.leftGesture = PlayerGesture.brightness,
    this.rightGesture = PlayerGesture.volume,
    this.doubleTapEnabled = true,
    this.swipeSeekEnabled = true,
    this.seekDuration = 10,
    this.defaultResizeMode = 'Fit',
    this.subtitleSize = 22.0,
    this.subtitleColor = 0xFFFFFFFF, // White
    this.subtitleBackgroundColor = 0x00000000, // Transparent
    this.subtitleBackgroundOpacity = 0.5, // Default opacity (50%)
    this.hardwareDecoding = true,
    this.preferredPlayer,
    this.readaheadSeconds = 180,
    this.subtitlePosition = 100.0,
    this.subFixedTextSize,
    this.subTypeface,
    this.subTypefaceFilePath,
    this.subEdgeType = 1,
    this.subEdgeSize,
    this.subBackgroundRadius,
    this.subElevation = 20,
    this.subRemoveBloat = true,
    this.subRemoveCaptions = false,
    this.subUpperCase = false,
    this.subBold = false,
    this.subItalic = false,
    this.subForegroundColor = 0xFFFFFFFF,
    this.subBackgroundColor = 0x00000000,
    this.subEdgeColor = 0xFF000000,
    this.subBackgroundOpacity = 0.5,
    this.subAlignment,
    this.wifiQuality = kDefaultWifiQuality,
    this.mobileQuality = QualityPreference.q1080,
    this.qualityFilterMode = QualityFilterMode.any,
    this.hdrMode = HdrMode.auto,
    this.toneMapCurve = ToneMapCurve.auto,
    this.hdrComputePeak = true,
    this.hdrTargetPeak = 0,
    this.inverseToneMapping = false,
    this.maxVolumePercent = 200,
    this.showRemainingTime = false,
    this.defaultPlaybackSpeed = 1.0,
    this.showPip = true,
    this.showResize = true,
    this.showRotate = true,
    this.showPlaybackSpeed = true,
    this.showEpisodes = true,
    this.osUsername = '',
    this.osPassword = '',
    this.osApiKey = '',
    this.subdlEmail = '',
    this.subdlPassword = '',
    this.subdlApiKey = '',
    this.subsourceApiKey = '',
  });

  PlayerSettings copyWith({
    PlayerGesture? leftGesture,
    PlayerGesture? rightGesture,
    bool? doubleTapEnabled,
    bool? swipeSeekEnabled,
    int? seekDuration,
    String? defaultResizeMode,
    double? subtitleSize,
    int? subtitleColor,
    int? subtitleBackgroundColor,
    double? subtitleBackgroundOpacity,
    bool? hardwareDecoding,
    String? preferredPlayer,
    bool clearPreferredPlayer = false,
    int? readaheadSeconds,
    double? subtitlePosition,
    double? Function()? subFixedTextSize,
    int? Function()? subTypeface,
    String? Function()? subTypefaceFilePath,
    int? subEdgeType,
    double? Function()? subEdgeSize,
    double? Function()? subBackgroundRadius,
    int? subElevation,
    bool? subRemoveBloat,
    bool? subRemoveCaptions,
    bool? subUpperCase,
    bool? subBold,
    bool? subItalic,
    int? subForegroundColor,
    int? subBackgroundColor,
    int? subEdgeColor,
    double? subBackgroundOpacity,
    int? Function()? subAlignment,
    QualityPreference? wifiQuality,
    QualityPreference? mobileQuality,
    QualityFilterMode? qualityFilterMode,
    HdrMode? hdrMode,
    ToneMapCurve? toneMapCurve,
    bool? hdrComputePeak,
    int? hdrTargetPeak,
    bool? inverseToneMapping,
    int? maxVolumePercent,
    bool? showRemainingTime,
    double? defaultPlaybackSpeed,
    bool? showPip,
    bool? showResize,
    bool? showRotate,
    bool? showPlaybackSpeed,
    bool? showEpisodes,
    String? osUsername,
    String? osPassword,
    String? osApiKey,
    String? subdlEmail,
    String? subdlPassword,
    String? subdlApiKey,
    String? subsourceApiKey,
  }) {
    return PlayerSettings(
      leftGesture: leftGesture ?? this.leftGesture,
      rightGesture: rightGesture ?? this.rightGesture,
      doubleTapEnabled: doubleTapEnabled ?? this.doubleTapEnabled,
      swipeSeekEnabled: swipeSeekEnabled ?? this.swipeSeekEnabled,
      seekDuration: seekDuration ?? this.seekDuration,
      defaultResizeMode: defaultResizeMode ?? this.defaultResizeMode,
      subtitleSize: subtitleSize ?? this.subtitleSize,
      subtitleColor: subtitleColor ?? this.subtitleColor,
      subtitleBackgroundColor:
          subtitleBackgroundColor ?? this.subtitleBackgroundColor,
      subtitleBackgroundOpacity:
          subtitleBackgroundOpacity ?? this.subtitleBackgroundOpacity,
      hardwareDecoding: hardwareDecoding ?? this.hardwareDecoding,
      preferredPlayer: clearPreferredPlayer
          ? null
          : (preferredPlayer ?? this.preferredPlayer),
      readaheadSeconds: readaheadSeconds ?? this.readaheadSeconds,
      subtitlePosition: subtitlePosition ?? this.subtitlePosition,
      subFixedTextSize: subFixedTextSize != null
          ? subFixedTextSize()
          : this.subFixedTextSize,
      subTypeface: subTypeface != null ? subTypeface() : this.subTypeface,
      subTypefaceFilePath: subTypefaceFilePath != null
          ? subTypefaceFilePath()
          : this.subTypefaceFilePath,
      subEdgeType: subEdgeType ?? this.subEdgeType,
      subEdgeSize: subEdgeSize != null ? subEdgeSize() : this.subEdgeSize,
      subBackgroundRadius: subBackgroundRadius != null
          ? subBackgroundRadius()
          : this.subBackgroundRadius,
      subElevation: subElevation ?? this.subElevation,
      subRemoveBloat: subRemoveBloat ?? this.subRemoveBloat,
      subRemoveCaptions: subRemoveCaptions ?? this.subRemoveCaptions,
      subUpperCase: subUpperCase ?? this.subUpperCase,
      subBold: subBold ?? this.subBold,
      subItalic: subItalic ?? this.subItalic,
      subForegroundColor: subForegroundColor ?? this.subForegroundColor,
      subBackgroundColor: subBackgroundColor ?? this.subBackgroundColor,
      subEdgeColor: subEdgeColor ?? this.subEdgeColor,
      subBackgroundOpacity: subBackgroundOpacity ?? this.subBackgroundOpacity,
      subAlignment: subAlignment != null ? subAlignment() : this.subAlignment,
      wifiQuality: wifiQuality ?? this.wifiQuality,
      mobileQuality: mobileQuality ?? this.mobileQuality,
      qualityFilterMode: qualityFilterMode ?? this.qualityFilterMode,
      hdrMode: hdrMode ?? this.hdrMode,
      toneMapCurve: toneMapCurve ?? this.toneMapCurve,
      hdrComputePeak: hdrComputePeak ?? this.hdrComputePeak,
      hdrTargetPeak: hdrTargetPeak ?? this.hdrTargetPeak,
      inverseToneMapping: inverseToneMapping ?? this.inverseToneMapping,
      maxVolumePercent: maxVolumePercent ?? this.maxVolumePercent,
      showRemainingTime: showRemainingTime ?? this.showRemainingTime,
      defaultPlaybackSpeed: defaultPlaybackSpeed ?? this.defaultPlaybackSpeed,
      showPip: showPip ?? this.showPip,
      showResize: showResize ?? this.showResize,
      showRotate: showRotate ?? this.showRotate,
      showPlaybackSpeed: showPlaybackSpeed ?? this.showPlaybackSpeed,
      showEpisodes: showEpisodes ?? this.showEpisodes,
      osUsername: osUsername ?? this.osUsername,
      osPassword: osPassword ?? this.osPassword,
      osApiKey: osApiKey ?? this.osApiKey,
      subdlEmail: subdlEmail ?? this.subdlEmail,
      subdlPassword: subdlPassword ?? this.subdlPassword,
      subdlApiKey: subdlApiKey ?? this.subdlApiKey,
      subsourceApiKey: subsourceApiKey ?? this.subsourceApiKey,
    );
  }
}

@Riverpod(keepAlive: true)
class PlayerSettingsNotifier extends _$PlayerSettingsNotifier {
  SettingsRepository get _repository => ref.read(settingsRepositoryProvider);

  @override
  Future<PlayerSettings> build() async {
    final storage = _repository;
    final l =
        storage.getPlayerSetting<String>(
          'player_gesture_left',
          defaultValue: 'brightness',
        ) ??
        'brightness';
    final r =
        storage.getPlayerSetting<String>(
          'player_gesture_right',
          defaultValue: 'volume',
        ) ??
        'volume';
    final dt =
        storage.getPlayerSetting<bool>(
          'player_double_tap',
          defaultValue: true,
        ) ??
        true;
    final dur =
        storage.getPlayerSetting<int>(
          'player_seek_duration',
          defaultValue: 10,
        ) ??
        10;
    final resize =
        storage.getPlayerSetting<String>(
          'player_default_resize',
          defaultValue: 'Fit',
        ) ??
        'Fit';
    final subSize =
        (storage.getPlayerSetting('player_sub_size') as num?)?.toDouble() ??
        22.0;
    final subColor =
        storage.getPlayerSetting<int>(
          'player_sub_color',
          defaultValue: 0xFFFFFFFF,
        ) ??
        0xFFFFFFFF;
    final subBg =
        (storage.getPlayerSetting('player_sub_bg') as num?)?.toInt() ??
        0x00000000;
    final subBgOpacity =
        (storage.getPlayerSetting('player_sub_bg_opacity') as num?)
            ?.toDouble() ??
        0.5;
    final prefPlayer = storage.getPlayerSetting<String>('player_preferred');
    final swipeSeek =
        storage.getPlayerSetting<bool>(
          'player_swipe_seek',
          defaultValue: true,
        ) ??
        true;
    final hwDec =
        storage.getPlayerSetting<bool>('player_hw_dec', defaultValue: true) ??
        true;
    final rSecons =
        storage.getPlayerSetting<int>('player_readahead', defaultValue: 180) ??
        180;
    final subPos =
        (storage.getPlayerSetting('player_sub_pos') as num?)?.toDouble() ??
        100.0;
    final wifiQ = _parseQuality(
      storage.getPlayerSetting<String>('player_wifi_quality'),
      kDefaultWifiQuality,
    );
    final mobileQ = _parseQuality(
      storage.getPlayerSetting<String>('player_mobile_quality'),
      QualityPreference.q1080,
    );
    final showRemaining =
        storage.getPlayerSetting<bool>(
          'player_show_remaining',
          defaultValue: false,
        ) ??
        false;
    final defaultSpeed =
        (storage.getPlayerSetting('player_default_speed') as num?)
            ?.toDouble() ??
        1.0;
    final osUser = storage.getPlayerSetting<String>('player_os_user') ?? '';
    final osPass = storage.getPlayerSetting<String>('player_os_pass') ?? '';
    final osKey = storage.getPlayerSetting<String>('player_os_key') ?? '';
    final dlEmail =
        storage.getPlayerSetting<String>('player_subdl_email') ?? '';
    final dlPass = storage.getPlayerSetting<String>('player_subdl_pass') ?? '';
    final dlKey = storage.getPlayerSetting<String>('player_subdl_key') ?? '';
    final ssKey = storage.getPlayerSetting<String>('player_ss_key') ?? '';
    final filterMode = _parseFilterMode(
      storage.getPlayerSetting<String>('player_quality_filter_mode'),
    );

    final subFixedTextSize =
        (storage.getPlayerSetting('player_sub_fixed_text_size') as num?)
            ?.toDouble();
    final subTypeface = storage.getPlayerSetting<int>('player_sub_typeface');
    final subTypefaceFilePath = storage.getPlayerSetting<String>(
      'player_sub_typeface_file_path',
    );
    final subEdgeType =
        storage.getPlayerSetting<int>(
          'player_sub_edge_type',
          defaultValue: 1,
        ) ??
        1;
    final subEdgeSize =
        (storage.getPlayerSetting('player_sub_edge_size') as num?)?.toDouble();
    final subBackgroundRadius =
        (storage.getPlayerSetting('player_sub_bg_radius') as num?)?.toDouble();
    final subElevation =
        storage.getPlayerSetting<int>(
          'player_sub_elevation',
          defaultValue: 20,
        ) ??
        20;
    final subRemoveBloat =
        storage.getPlayerSetting<bool>(
          'player_sub_remove_bloat',
          defaultValue: true,
        ) ??
        true;
    final subRemoveCaptions =
        storage.getPlayerSetting<bool>(
          'player_sub_remove_captions',
          defaultValue: false,
        ) ??
        false;
    final subUpperCase =
        storage.getPlayerSetting<bool>(
          'player_sub_uppercase',
          defaultValue: false,
        ) ??
        false;
    final subBold =
        storage.getPlayerSetting<bool>(
          'player_sub_bold',
          defaultValue: false,
        ) ??
        false;
    final subItalic =
        storage.getPlayerSetting<bool>(
          'player_sub_italic',
          defaultValue: false,
        ) ??
        false;
    final subForegroundColor =
        storage.getPlayerSetting<int>(
          'player_sub_foreground_color',
          defaultValue: 0xFFFFFFFF,
        ) ??
        0xFFFFFFFF;
    final subBackgroundColor =
        storage.getPlayerSetting<int>(
          'player_sub_background_color',
          defaultValue: 0x00000000,
        ) ??
        0x00000000;
    final subEdgeColor =
        storage.getPlayerSetting<int>(
          'player_sub_edge_color',
          defaultValue: 0xFF000000,
        ) ??
        0xFF000000;
    final subBackgroundOpacity =
        (storage.getPlayerSetting(
                  'player_sub_background_opacity',
                  defaultValue: 0.5,
                )
                as num?)
            ?.toDouble() ??
        0.5;
    final subAlignment = storage.getPlayerSetting<int>('player_sub_alignment');

    final showPip =
        storage.getPlayerSetting<bool>('player_show_pip', defaultValue: true) ??
        true;
    final showResize =
        storage.getPlayerSetting<bool>(
          'player_show_resize',
          defaultValue: true,
        ) ??
        true;
    final showRotate =
        storage.getPlayerSetting<bool>(
          'player_show_rotate',
          defaultValue: true,
        ) ??
        true;
    final showPlaybackSpeed =
        storage.getPlayerSetting<bool>(
          'player_show_playback_speed',
          defaultValue: true,
        ) ??
        true;
    final showEpisodes =
        storage.getPlayerSetting<bool>(
          'player_show_episodes',
          defaultValue: true,
        ) ??
        true;

    final hdrMode = HdrMode.values.firstWhere(
      (e) => e.name == storage.getPlayerSetting<String>('player_hdr_mode'),
      orElse: () => HdrMode.auto,
    );
    final toneMapCurve = ToneMapCurve.values.firstWhere(
      (e) => e.name == storage.getPlayerSetting<String>('player_tone_map'),
      orElse: () => ToneMapCurve.auto,
    );
    final hdrComputePeak =
        storage.getPlayerSetting<bool>(
          'player_hdr_compute_peak',
          defaultValue: true,
        ) ??
        true;
    final hdrTargetPeak =
        storage.getPlayerSetting<int>(
          'player_hdr_target_peak',
          defaultValue: 0,
        ) ??
        0;
    final inverseToneMapping =
        storage.getPlayerSetting<bool>(
          'player_inverse_tone_map',
          defaultValue: false,
        ) ??
        false;
    final maxVolumePercent =
        storage.getPlayerSetting<int>('player_max_volume', defaultValue: 200) ??
        200;

    return PlayerSettings(
      leftGesture: _parse(l),
      rightGesture: _parse(r),
      doubleTapEnabled: dt,
      swipeSeekEnabled: swipeSeek,
      seekDuration: dur,
      defaultResizeMode: resize,
      subtitleSize: subSize,
      subtitleColor: subColor,
      subtitleBackgroundColor: subBg,
      subtitleBackgroundOpacity: subBgOpacity,
      hardwareDecoding: hwDec,
      preferredPlayer: prefPlayer,
      readaheadSeconds: rSecons,
      subtitlePosition: subPos,
      subFixedTextSize: subFixedTextSize,
      subTypeface: subTypeface,
      subTypefaceFilePath: subTypefaceFilePath,
      subEdgeType: subEdgeType,
      subEdgeSize: subEdgeSize,
      subBackgroundRadius: subBackgroundRadius,
      subElevation: subElevation,
      subRemoveBloat: subRemoveBloat,
      subRemoveCaptions: subRemoveCaptions,
      subUpperCase: subUpperCase,
      subBold: subBold,
      subItalic: subItalic,
      subForegroundColor: subForegroundColor,
      subBackgroundColor: subBackgroundColor,
      subEdgeColor: subEdgeColor,
      subBackgroundOpacity: subBackgroundOpacity,
      subAlignment: subAlignment,
      wifiQuality: wifiQ,
      mobileQuality: mobileQ,
      qualityFilterMode: filterMode,
      hdrMode: hdrMode,
      toneMapCurve: toneMapCurve,
      hdrComputePeak: hdrComputePeak,
      hdrTargetPeak: hdrTargetPeak,
      inverseToneMapping: inverseToneMapping,
      maxVolumePercent: maxVolumePercent,
      showRemainingTime: showRemaining,
      defaultPlaybackSpeed: defaultSpeed,
      showPip: showPip,
      showResize: showResize,
      showRotate: showRotate,
      showPlaybackSpeed: showPlaybackSpeed,
      showEpisodes: showEpisodes,
      osUsername: osUser,
      osPassword: osPass,
      osApiKey: osKey,
      subdlEmail: dlEmail,
      subdlPassword: dlPass,
      subdlApiKey: dlKey,
      subsourceApiKey: ssKey,
    );
  }

  Future<void> setSubtitleAppearanceSettings(PlayerSettings newSettings) async {
    final storage = _repository;

    // Sync the legacy settings to match the new appearance settings
    final syncedSettings = newSettings.copyWith(
      subtitleSize: newSettings.subFixedTextSize ?? 22.0,
      subtitleColor: newSettings.subForegroundColor,
      subtitleBackgroundColor: newSettings.subBackgroundColor,
      subtitleBackgroundOpacity: newSettings.subBackgroundOpacity,
    );

    await storage.setPlayerSetting(
      'player_sub_fixed_text_size',
      syncedSettings.subFixedTextSize,
    );
    await storage.setPlayerSetting(
      'player_sub_typeface',
      syncedSettings.subTypeface,
    );
    await storage.setPlayerSetting(
      'player_sub_typeface_file_path',
      syncedSettings.subTypefaceFilePath,
    );
    await storage.setPlayerSetting(
      'player_sub_edge_type',
      syncedSettings.subEdgeType,
    );
    await storage.setPlayerSetting(
      'player_sub_edge_size',
      syncedSettings.subEdgeSize,
    );
    await storage.setPlayerSetting(
      'player_sub_bg_radius',
      syncedSettings.subBackgroundRadius,
    );
    await storage.setPlayerSetting(
      'player_sub_elevation',
      syncedSettings.subElevation,
    );
    await storage.setPlayerSetting(
      'player_sub_remove_bloat',
      syncedSettings.subRemoveBloat,
    );
    await storage.setPlayerSetting(
      'player_sub_remove_captions',
      syncedSettings.subRemoveCaptions,
    );
    await storage.setPlayerSetting(
      'player_sub_uppercase',
      syncedSettings.subUpperCase,
    );
    await storage.setPlayerSetting('player_sub_bold', syncedSettings.subBold);
    await storage.setPlayerSetting(
      'player_sub_italic',
      syncedSettings.subItalic,
    );
    await storage.setPlayerSetting(
      'player_sub_foreground_color',
      syncedSettings.subForegroundColor,
    );
    await storage.setPlayerSetting(
      'player_sub_background_color',
      syncedSettings.subBackgroundColor,
    );
    await storage.setPlayerSetting(
      'player_sub_edge_color',
      syncedSettings.subEdgeColor,
    );
    await storage.setPlayerSetting(
      'player_sub_background_opacity',
      syncedSettings.subBackgroundOpacity,
    );
    await storage.setPlayerSetting(
      'player_sub_alignment',
      syncedSettings.subAlignment,
    );

    // Persist legacy settings to database too
    await storage.setPlayerSetting(
      'player_sub_size',
      syncedSettings.subtitleSize,
    );
    await storage.setPlayerSetting(
      'player_sub_color',
      syncedSettings.subtitleColor,
    );
    await storage.setPlayerSetting(
      'player_sub_bg',
      syncedSettings.subtitleBackgroundColor,
    );
    await storage.setPlayerSetting(
      'player_sub_bg_opacity',
      syncedSettings.subtitleBackgroundOpacity,
    );

    state = AsyncData(syncedSettings);
  }

  Future<void> resetSubtitleAppearanceSettings() async {
    final current = state.requireValue;
    final newState = current.copyWith(
      subFixedTextSize: () => null,
      subTypeface: () => null,
      subTypefaceFilePath: () => null,
      subEdgeType: 1,
      subEdgeSize: () => null,
      subBackgroundRadius: () => null,
      subElevation: 20,
      subRemoveBloat: true,
      subRemoveCaptions: false,
      subUpperCase: false,
      subBold: false,
      subItalic: false,
      subForegroundColor: 0xFFFFFFFF,
      subBackgroundColor: 0x00000000,
      subEdgeColor: 0xFF000000,
      subBackgroundOpacity: 0.5,
      subAlignment: () => null,
      // Reset legacy settings as well
      subtitleSize: 22.0,
      subtitleColor: 0xFFFFFFFF,
      subtitleBackgroundColor: 0x00000000,
      subtitleBackgroundOpacity: 0.5,
    );

    final storage = _repository;
    await storage.setPlayerSetting('player_sub_fixed_text_size', null);
    await storage.setPlayerSetting('player_sub_typeface', null);
    await storage.setPlayerSetting('player_sub_typeface_file_path', null);
    await storage.setPlayerSetting('player_sub_edge_type', 1);
    await storage.setPlayerSetting('player_sub_edge_size', null);
    await storage.setPlayerSetting('player_sub_bg_radius', null);
    await storage.setPlayerSetting('player_sub_elevation', 20);
    await storage.setPlayerSetting('player_sub_remove_bloat', true);
    await storage.setPlayerSetting('player_sub_remove_captions', false);
    await storage.setPlayerSetting('player_sub_uppercase', false);
    await storage.setPlayerSetting('player_sub_bold', false);
    await storage.setPlayerSetting('player_sub_italic', false);
    await storage.setPlayerSetting('player_sub_foreground_color', 0xFFFFFFFF);
    await storage.setPlayerSetting('player_sub_background_color', 0x00000000);
    await storage.setPlayerSetting('player_sub_edge_color', 0xFF000000);
    await storage.setPlayerSetting('player_sub_background_opacity', 0.5);
    await storage.setPlayerSetting('player_sub_alignment', null);

    // Reset legacy keys in storage too
    await storage.setPlayerSetting('player_sub_size', 22.0);
    await storage.setPlayerSetting('player_sub_color', 0xFFFFFFFF);
    await storage.setPlayerSetting('player_sub_bg', 0x00000000);
    await storage.setPlayerSetting('player_sub_bg_opacity', 0.5);

    state = AsyncData(newState);
  }

  Future<void> setLeftGesture(PlayerGesture g) async {
    await _repository.setPlayerSetting('player_gesture_left', g.name);
    state = AsyncData(state.requireValue.copyWith(leftGesture: g));
  }

  Future<void> setRightGesture(PlayerGesture g) async {
    await _repository.setPlayerSetting('player_gesture_right', g.name);
    state = AsyncData(state.requireValue.copyWith(rightGesture: g));
  }

  Future<void> setDoubleTapEnabled(bool val) async {
    await _repository.setPlayerSetting('player_double_tap', val);
    state = AsyncData(state.requireValue.copyWith(doubleTapEnabled: val));
  }

  Future<void> setSwipeSeekEnabled(bool val) async {
    await _repository.setPlayerSetting('player_swipe_seek', val);
    state = AsyncData(state.requireValue.copyWith(swipeSeekEnabled: val));
  }

  Future<void> setSeekDuration(int seconds) async {
    await _repository.setPlayerSetting('player_seek_duration', seconds);
    state = AsyncData(state.requireValue.copyWith(seekDuration: seconds));
  }

  Future<void> setDefaultResizeMode(String mode) async {
    await _repository.setPlayerSetting('player_default_resize', mode);
    state = AsyncData(state.requireValue.copyWith(defaultResizeMode: mode));
  }

  Future<void> setHardwareDecoding(bool val) async {
    await _repository.setPlayerSetting('player_hw_dec', val);
    state = AsyncData(state.requireValue.copyWith(hardwareDecoding: val));
  }

  Future<void> setHdrMode(HdrMode mode) async {
    await _repository.setPlayerSetting('player_hdr_mode', mode.name);
    state = AsyncData(state.requireValue.copyWith(hdrMode: mode));
  }

  Future<void> setToneMapCurve(ToneMapCurve curve) async {
    await _repository.setPlayerSetting('player_tone_map', curve.name);
    state = AsyncData(state.requireValue.copyWith(toneMapCurve: curve));
  }

  Future<void> setHdrComputePeak(bool val) async {
    await _repository.setPlayerSetting('player_hdr_compute_peak', val);
    state = AsyncData(state.requireValue.copyWith(hdrComputePeak: val));
  }

  /// [nits] of 0 means auto-detect from the display.
  Future<void> setHdrTargetPeak(int nits) async {
    final clamped = nits <= 0 ? 0 : nits.clamp(100, 10000);
    await _repository.setPlayerSetting('player_hdr_target_peak', clamped);
    state = AsyncData(state.requireValue.copyWith(hdrTargetPeak: clamped));
  }

  Future<void> setInverseToneMapping(bool val) async {
    await _repository.setPlayerSetting('player_inverse_tone_map', val);
    state = AsyncData(state.requireValue.copyWith(inverseToneMapping: val));
  }

  Future<void> setMaxVolumePercent(int percent) async {
    final clamped = percent.clamp(100, 200);
    await _repository.setPlayerSetting('player_max_volume', clamped);
    state = AsyncData(state.requireValue.copyWith(maxVolumePercent: clamped));
  }

  Future<void> setShowPip(bool val) async {
    await _repository.setPlayerSetting('player_show_pip', val);
    state = AsyncData(state.requireValue.copyWith(showPip: val));
  }

  Future<void> setShowResize(bool val) async {
    await _repository.setPlayerSetting('player_show_resize', val);
    state = AsyncData(state.requireValue.copyWith(showResize: val));
  }

  Future<void> setShowRotate(bool val) async {
    await _repository.setPlayerSetting('player_show_rotate', val);
    state = AsyncData(state.requireValue.copyWith(showRotate: val));
  }

  Future<void> setShowPlaybackSpeed(bool val) async {
    await _repository.setPlayerSetting('player_show_playback_speed', val);
    state = AsyncData(state.requireValue.copyWith(showPlaybackSpeed: val));
  }

  Future<void> setShowEpisodes(bool val) async {
    await _repository.setPlayerSetting('player_show_episodes', val);
    state = AsyncData(state.requireValue.copyWith(showEpisodes: val));
  }

  Future<void> setSubtitleSettings(
    double size,
    int color,
    int bg, [
    double? opacity,
  ]) async {
    await _repository.setPlayerSetting('player_sub_size', size);
    await _repository.setPlayerSetting('player_sub_color', color);
    await _repository.setPlayerSetting('player_sub_bg', bg);
    if (opacity != null) {
      await _repository.setPlayerSetting('player_sub_bg_opacity', opacity);
    }
    state = AsyncData(
      state.requireValue.copyWith(
        subtitleSize: size,
        subtitleColor: color,
        subtitleBackgroundColor: bg,
        subtitleBackgroundOpacity:
            opacity ?? state.requireValue.subtitleBackgroundOpacity,
      ),
    );
  }

  Future<void> setPreferredPlayer(String? playerId) async {
    if (playerId == null) {
      await _repository.setPlayerSetting('player_preferred', null);
      state = AsyncData(
        state.requireValue.copyWith(clearPreferredPlayer: true),
      );
    } else {
      await _repository.setPlayerSetting('player_preferred', playerId);
      state = AsyncData(state.requireValue.copyWith(preferredPlayer: playerId));
    }
  }

  Future<void> setReadaheadSeconds(int seconds) async {
    await _repository.setPlayerSetting('player_readahead', seconds);
    state = AsyncData(state.requireValue.copyWith(readaheadSeconds: seconds));
  }

  Future<void> setSubtitlePosition(double pos) async {
    await _repository.setPlayerSetting('player_sub_pos', pos);
    state = AsyncData(state.requireValue.copyWith(subtitlePosition: pos));
  }

  Future<void> setSubtitleBackgroundOpacity(double val) async {
    await _repository.setPlayerSetting('player_sub_bg_opacity', val);
    state = AsyncData(
      state.requireValue.copyWith(subtitleBackgroundOpacity: val),
    );
  }

  Future<void> resetSubtitleSettings() async {
    final current = state.requireValue;
    final newState = current.copyWith(
      subtitleSize: 22.0,
      subtitleColor: 0xFFFFFFFF,
      subtitleBackgroundColor: 0x00000000,
      subtitleBackgroundOpacity: 0.5,
      subtitlePosition: 100.0,
    );

    await _repository.setPlayerSetting('player_sub_size', 22.0);
    await _repository.setPlayerSetting('player_sub_color', 0xFFFFFFFF);
    await _repository.setPlayerSetting('player_sub_bg', 0x00000000);
    await _repository.setPlayerSetting('player_sub_bg_opacity', 0.5);
    await _repository.setPlayerSetting('player_sub_pos', 100.0);

    state = AsyncData(newState);
  }

  Future<void> setWifiQuality(QualityPreference q) async {
    await _repository.setPlayerSetting('player_wifi_quality', q.name);
    state = AsyncData(state.requireValue.copyWith(wifiQuality: q));
  }

  Future<void> setMobileQuality(QualityPreference q) async {
    await _repository.setPlayerSetting('player_mobile_quality', q.name);
    state = AsyncData(state.requireValue.copyWith(mobileQuality: q));
  }

  Future<void> setQualityFilterMode(QualityFilterMode mode) async {
    await _repository.setPlayerSetting('player_quality_filter_mode', mode.name);
    state = AsyncData(state.requireValue.copyWith(qualityFilterMode: mode));
  }

  Future<void> setShowRemainingTime(bool val) async {
    await _repository.setPlayerSetting('player_show_remaining', val);
    state = AsyncData(state.requireValue.copyWith(showRemainingTime: val));
  }

  Future<void> setDefaultPlaybackSpeed(double speed) async {
    await _repository.setPlayerSetting('player_default_speed', speed);
    state = AsyncData(state.requireValue.copyWith(defaultPlaybackSpeed: speed));
  }

  Future<void> setOpenSubtitlesCredentials(
    String user,
    String pass, [
    String? key,
  ]) async {
    await _repository.setPlayerSetting('player_os_user', user);
    await _repository.setPlayerSetting('player_os_pass', pass);
    if (key != null) {
      await _repository.setPlayerSetting('player_os_key', key);
    }
    state = AsyncData(
      state.requireValue.copyWith(
        osUsername: user,
        osPassword: pass,
        osApiKey: key,
      ),
    );
  }

  Future<void> setSubDlAuth({
    required String apiKey,
    String? email,
    String? pass,
  }) async {
    await _repository.setPlayerSetting('player_subdl_key', apiKey);
    if (email != null) {
      await _repository.setPlayerSetting('player_subdl_email', email);
    }
    if (pass != null) {
      await _repository.setPlayerSetting('player_subdl_pass', pass);
    }

    state = AsyncData(
      state.requireValue.copyWith(
        subdlApiKey: apiKey,
        subdlEmail: email ?? state.requireValue.subdlEmail,
        subdlPassword: pass ?? state.requireValue.subdlPassword,
      ),
    );
  }

  Future<void> setSubDlApiKey(String key) async {
    await _repository.setPlayerSetting('player_subdl_key', key);
    state = AsyncData(state.requireValue.copyWith(subdlApiKey: key));
  }

  Future<void> setSubSourceApiKey(String key) async {
    await _repository.setPlayerSetting('player_ss_key', key);
    state = AsyncData(state.requireValue.copyWith(subsourceApiKey: key));
  }

  Future<bool> verifyOpenSubtitles(
    String user,
    String pass, [
    String? key,
  ]) async {
    final dio = ref.read(dioClientProvider);
    final provider = OpenSubtitlesProvider(
      dio,
      username: user,
      password: pass,
      apiKey: key,
    );
    return await provider.verifyCredentials();
  }

  Future<({String? key, String? error})> verifySubDl(
    String email,
    String pass,
  ) async {
    final dio = ref.read(dioClientProvider);
    final provider = SubDLProvider(dio, email: email, password: pass);
    return await provider.login(email, pass);
  }

  Future<bool> verifySubDlKey(String key) async {
    final dio = ref.read(dioClientProvider);
    final provider = SubDLProvider(dio, apiKey: key);
    return await provider.verifyKey();
  }

  Future<bool> verifySubSource(String key) async {
    final dio = ref.read(dioClientProvider);
    final provider = SubSourceProvider(dio, apiKey: key);
    return await provider.verifyKey();
  }

  PlayerGesture _parse(String s) {
    return PlayerGesture.values.firstWhere(
      (e) => e.name == s,
      orElse: () => PlayerGesture.none,
    );
  }

  QualityPreference _parseQuality(String? s, QualityPreference fallback) {
    if (s == null) return fallback;
    return QualityPreference.values.firstWhere(
      (e) => e.name == s,
      orElse: () => fallback,
    );
  }

  QualityFilterMode _parseFilterMode(String? s) {
    if (s == null) return QualityFilterMode.any;
    return QualityFilterMode.values.firstWhere(
      (e) => e.name == s,
      orElse: () => QualityFilterMode.any,
    );
  }
}
