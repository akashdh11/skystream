import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/secure_token_storage.dart';
import '../../../core/storage/settings_repository.dart';
import '../../../core/storage/storage_service.dart'
    show kOsPasswordKey, kSubDlPasswordKey;
import '../../player/domain/network_buffer.dart';
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

/// Whether a video starts with a subtitle showing.
///
/// A default, not a lock. [off] decides only what the player does with media
/// it has just opened by itself; the Subtitles menu keeps working exactly as
/// it does today, and a track the viewer picks there stays picked for as long
/// as that media is playing.
///
/// Applied per opened media, which is what "by default" has to mean here:
/// every failover, recovery, rendition step-down, live reconnect and episode
/// advance hands libVLC brand-new media that re-selects a subtitle on its own,
/// so the default is re-applied to each. See `VlcPlayerScreen`'s
/// `_applySubtitleDefault` for the whole rule.
enum SubtitleDefault {
  /// Today's behaviour, unchanged: whatever the source and libVLC select is
  /// what plays, including the preferred-language side-car match in
  /// `preferredSubtitleIndex`.
  auto,

  /// Media starts with no subtitle selected.
  off,
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

  /// Whether a newly opened video starts with a subtitle showing.
  /// [SubtitleDefault.auto] is what every install did before this setting
  /// existed, so an upgrade changes nothing.
  final SubtitleDefault subtitleDefault;

  final bool hardwareDecoding;
  final String?
  preferredPlayer; // null = internal, 'vlc' / 'mpv' etc. = external

  /// Quality to prefer when on Wi-Fi. Defaults to [kDefaultWifiQuality]
  /// (1080p), not 4K — see that constant for why.
  final QualityPreference wifiQuality;

  /// Quality to prefer when on mobile data. Default: 1080p.
  final QualityPreference mobileQuality;

  /// Controls whether streams below/above the quality preference are hidden.
  /// Default: [QualityFilterMode.any] (sort only, no filtering).
  final QualityFilterMode qualityFilterMode;

  /// How much of a network stream to hold in memory, in megabytes.
  ///
  /// Read-ahead, not latency. It feeds libVLC's prefetch buffer, which sits
  /// under the demuxer and holds a window either side of the read point, so a
  /// seek inside that window costs nothing and a stuttering connection has
  /// something to draw on. Deliberately not wired to `--network-caching`: that
  /// is output latency, and a large value there is what made a newly selected
  /// audio track silent for a full minute.
  ///
  /// Megabytes rather than minutes because libVLC sizes this in bytes and
  /// never in time. Converting from minutes needed a guess at the bitrate and
  /// a cap for the memory, and the two together made most of the choices
  /// identical - four different durations all landing on the same buffer.
  /// The number chosen here is the number reserved.
  ///
  /// Null means nobody has chosen, and the device picks - see
  /// `defaultNetworkBufferMb`. Stored as null rather than as a resolved figure
  /// so the answer follows the hardware if the same account is restored onto a
  /// different device.
  final int? networkBufferMb;

  /// Maximum volume the player allows, as a percentage (100–200).
  /// mpv can amplify beyond the source level; 100 disables the boost.
  final int maxVolumePercent;

  /// When true, the progress-bar time header shows the remaining time
  /// (e.g. "-1:23:45 / 2:00:00") instead of the elapsed time. Sticky
  /// across sessions because users who prefer one view almost always
  /// want it always.
  final bool showRemainingTime;

  /// Toggles for individual player control-bar buttons. All default to
  /// visible. Options stays available for sources, tracks, and episodes.
  /// The episode toggle controls only the previous/next transport buttons.
  ///
  /// There is no rotate toggle: the manual rotate button went away when
  /// orientation started following the video's own shape, and a stored
  /// boolean for a button nobody draws is a preference that changes nothing.
  /// Old installs may still hold a `player_show_rotate` key in the Hive
  /// settings box; it is never read, and nothing enumerates that box, so it
  /// costs one unread boolean and needs no migration. The same goes for
  /// `player_readahead` and the five `player_hdr_*` / `player_tone_map` /
  /// `player_inverse_tone_map` keys: libVLC 3 has neither a read-ahead-in-
  /// seconds control nor mpv's tone mapping, so the settings that wrote them
  /// went away with the engine that could have honoured them.
  final bool showVolume;
  final bool showPip;
  final bool showResize;
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
    this.subtitleDefault = SubtitleDefault.auto,
    this.hardwareDecoding = true,
    this.preferredPlayer,
    this.wifiQuality = kDefaultWifiQuality,
    this.mobileQuality = QualityPreference.q1080,
    this.qualityFilterMode = QualityFilterMode.any,
    this.networkBufferMb,
    this.maxVolumePercent = 200,
    this.showRemainingTime = false,
    this.showVolume = true,
    this.showPip = true,
    this.showResize = true,
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
    SubtitleDefault? subtitleDefault,
    bool? hardwareDecoding,
    String? preferredPlayer,
    bool clearPreferredPlayer = false,
    QualityPreference? wifiQuality,
    QualityPreference? mobileQuality,
    QualityFilterMode? qualityFilterMode,
    int? networkBufferMb,
    int? maxVolumePercent,
    bool? showRemainingTime,
    bool? showVolume,
    bool? showPip,
    bool? showResize,
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
      subtitleDefault: subtitleDefault ?? this.subtitleDefault,
      hardwareDecoding: hardwareDecoding ?? this.hardwareDecoding,
      preferredPlayer: clearPreferredPlayer
          ? null
          : (preferredPlayer ?? this.preferredPlayer),
      wifiQuality: wifiQuality ?? this.wifiQuality,
      mobileQuality: mobileQuality ?? this.mobileQuality,
      qualityFilterMode: qualityFilterMode ?? this.qualityFilterMode,
      networkBufferMb: networkBufferMb ?? this.networkBufferMb,
      maxVolumePercent: maxVolumePercent ?? this.maxVolumePercent,
      showRemainingTime: showRemainingTime ?? this.showRemainingTime,
      showVolume: showVolume ?? this.showVolume,
      showPip: showPip ?? this.showPip,
      showResize: showResize ?? this.showResize,
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

  /// Whether OpenSubtitles can answer at all.
  ///
  /// Without a key the provider returns an empty list before it sends a
  /// request, so a stored [osUsername] is not evidence of a working account —
  /// nothing ever logged in with it. The same two candidates the provider
  /// itself weighs, in the same order.
  bool get hasOpenSubtitlesKey =>
      osApiKey.isNotEmpty || OpenSubtitlesProvider.buildTimeApiKey.isNotEmpty;
}

@Riverpod(keepAlive: true)
class PlayerSettingsNotifier extends _$PlayerSettingsNotifier {
  SettingsRepository get _repository => ref.read(settingsRepositoryProvider);

  /// Keychain (iOS/macOS) / Keystore (Android) / libsecret / Credentials API,
  /// with the one-shot migration out of the plaintext Hive box built in.
  ///
  /// The same store the OAuth tokens already use — deliberately not a second
  /// mechanism.
  SecureTokenStorage get _credentials => ref.read(secureTokenStorageProvider);

  /// Resolves without an await so no consumer can observe an unresolved
  /// [PlayerSettings].
  ///
  /// The player is pushed straight from Continue Watching and from both source
  /// sheets, none of which wait for this provider; while `build` was async
  /// those routes built the player from `const PlayerSettings()` and the
  /// viewer's subtitle appearance, resize mode and decode preference were the
  /// factory defaults for the rest of the session. Every value here therefore
  /// comes out of the already-open Hive box. The two account passwords are the
  /// exception - they live in the platform secure store, which is a channel
  /// call - so they are folded in by [_loadAccountPasswords] when they arrive.
  @override
  FutureOr<PlayerSettings> build() {
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
    // Absent (a fresh install, or an upgrade from before this setting) and
    // unrecognised (a value written by a newer build, or a corrupted box) both
    // land on Auto, which is the behaviour every install already had.
    final subtitleDefault = SubtitleDefault.values.firstWhere(
      (e) =>
          e.name == storage.getPlayerSetting<String>('player_subtitle_default'),
      orElse: () => SubtitleDefault.auto,
    );
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
    final osUser = storage.getPlayerSetting<String>('player_os_user') ?? '';
    final osKey = storage.getPlayerSetting<String>('player_os_key') ?? '';
    final dlEmail =
        storage.getPlayerSetting<String>('player_subdl_email') ?? '';
    final dlKey = storage.getPlayerSetting<String>('player_subdl_key') ?? '';
    final ssKey = storage.getPlayerSetting<String>('player_ss_key') ?? '';
    final filterMode = _parseFilterMode(
      storage.getPlayerSetting<String>('player_quality_filter_mode'),
    );

    final showVolume =
        storage.getPlayerSetting<bool>(
          'player_show_volume',
          defaultValue: true,
        ) ??
        true;
    final showPip =
        storage.getPlayerSetting<bool>('player_show_pip', defaultValue: true) ??
        true;
    final showResize =
        storage.getPlayerSetting<bool>(
          'player_show_resize',
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

    // No defaultValue: an absent key has to stay absent, because null is what
    // "let the device decide" is stored as.
    final networkBufferMb = storage.getPlayerSetting<int>(
      'player_network_buffer_mb',
    );
    final maxVolumePercent =
        storage.getPlayerSetting<int>('player_max_volume', defaultValue: 200) ??
        200;

    _loadAccountPasswords();

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
      subtitleDefault: subtitleDefault,
      hardwareDecoding: hwDec,
      preferredPlayer: prefPlayer,
      wifiQuality: wifiQ,
      mobileQuality: mobileQ,
      qualityFilterMode: filterMode,
      networkBufferMb: networkBufferMb,
      maxVolumePercent: maxVolumePercent,
      showRemainingTime: showRemaining,
      showVolume: showVolume,
      showPip: showPip,
      showResize: showResize,
      showPlaybackSpeed: showPlaybackSpeed,
      showEpisodes: showEpisodes,
      osUsername: osUser,
      osApiKey: osKey,
      subdlEmail: dlEmail,
      subdlApiKey: dlKey,
      subsourceApiKey: ssKey,
    );
  }

  /// Folds the two subtitle account passwords in once the platform secure
  /// store answers.
  ///
  /// Reusable account passwords, not tokens, so they never touch the Hive
  /// settings box. [SecureTokenStorage.read] migrates a value an older build
  /// left in that box on first read and deletes the plaintext copy, so nothing
  /// is lost on upgrade. See [kOsPasswordKey].
  ///
  /// A sign-in that lands while the store is being read wins: it is the newer
  /// of the two, and it has already been written back.
  ///
  /// Nothing awaits this, so a store that cannot be read has to end here: an
  /// escaping error would be an unhandled one, and the rest of the settings
  /// have already been returned. The two rows then read as signed out, which
  /// is what an unreadable credential store means.
  Future<void> _loadAccountPasswords() async {
    final String osPass;
    final String dlPass;
    try {
      osPass = await _credentials.read(kOsPasswordKey) ?? '';
      dlPass = await _credentials.read(kSubDlPasswordKey) ?? '';
    } catch (_) {
      return;
    }
    if (osPass.isEmpty && dlPass.isEmpty) return;
    _update(
      (PlayerSettings current) => current.copyWith(
        osPassword: current.osPassword.isEmpty ? osPass : null,
        subdlPassword: current.subdlPassword.isEmpty ? dlPass : null,
      ),
    );
  }

  /// Applies [change] to the settings already in hand, or does nothing.
  ///
  /// `state.requireValue` throws whenever the state is not [AsyncData] - which
  /// a failed `build` leaves it as permanently - and every setter here is
  /// called fire-and-forget from a row's `onChanged`, so the throw would escape
  /// as an unhandled async error and lose the in-memory update after the write
  /// to Hive had already succeeded. The stored value is the durable one either
  /// way; this only decides whether the screen catches up before the next
  /// launch.
  ///
  /// Also the disposal guard for the writes that resume after an await.
  void _update(PlayerSettings Function(PlayerSettings) change) {
    if (!ref.mounted) return;
    final PlayerSettings? current = state.value;
    if (current == null) return;
    state = AsyncData(change(current));
  }

  Future<void> setLeftGesture(PlayerGesture g) async {
    await _repository.setPlayerSetting('player_gesture_left', g.name);
    _update((PlayerSettings c) => c.copyWith(leftGesture: g));
  }

  Future<void> setRightGesture(PlayerGesture g) async {
    await _repository.setPlayerSetting('player_gesture_right', g.name);
    _update((PlayerSettings c) => c.copyWith(rightGesture: g));
  }

  Future<void> setDoubleTapEnabled(bool val) async {
    await _repository.setPlayerSetting('player_double_tap', val);
    _update((PlayerSettings c) => c.copyWith(doubleTapEnabled: val));
  }

  Future<void> setSwipeSeekEnabled(bool val) async {
    await _repository.setPlayerSetting('player_swipe_seek', val);
    _update((PlayerSettings c) => c.copyWith(swipeSeekEnabled: val));
  }

  Future<void> setSeekDuration(int seconds) async {
    await _repository.setPlayerSetting('player_seek_duration', seconds);
    _update((PlayerSettings c) => c.copyWith(seekDuration: seconds));
  }

  Future<void> setDefaultResizeMode(String mode) async {
    await _repository.setPlayerSetting('player_default_resize', mode);
    _update((PlayerSettings c) => c.copyWith(defaultResizeMode: mode));
  }

  /// Whether the next video the player opens starts with a subtitle showing.
  ///
  /// Takes effect on the next media the player opens, not on the one already
  /// on screen: the rule is applied while media is being handed to the engine.
  Future<void> setSubtitleDefault(SubtitleDefault value) async {
    await _repository.setPlayerSetting('player_subtitle_default', value.name);
    _update((PlayerSettings c) => c.copyWith(subtitleDefault: value));
  }

  Future<void> setHardwareDecoding(bool val) async {
    await _repository.setPlayerSetting('player_hw_dec', val);
    _update((PlayerSettings c) => c.copyWith(hardwareDecoding: val));
  }

  Future<void> setNetworkBufferMb(int megabytes) async {
    // The ends of [kNetworkBufferChoicesMb]. Clamped rather than validated so
    // a stored value from an older build - or a newer one - lands inside the
    // range this build actually offers.
    final clamped = megabytes.clamp(
      kNetworkBufferChoicesMb.first,
      kNetworkBufferChoicesMb.last,
    );
    await _repository.setPlayerSetting('player_network_buffer_mb', clamped);
    _update((PlayerSettings c) => c.copyWith(networkBufferMb: clamped));
  }

  Future<void> setMaxVolumePercent(int percent) async {
    final clamped = percent.clamp(100, 200);
    await _repository.setPlayerSetting('player_max_volume', clamped);
    _update((PlayerSettings c) => c.copyWith(maxVolumePercent: clamped));
  }

  Future<void> setShowVolume(bool val) async {
    await _repository.setPlayerSetting('player_show_volume', val);
    _update((PlayerSettings c) => c.copyWith(showVolume: val));
  }

  Future<void> setShowPip(bool val) async {
    await _repository.setPlayerSetting('player_show_pip', val);
    _update((PlayerSettings c) => c.copyWith(showPip: val));
  }

  Future<void> setShowResize(bool val) async {
    await _repository.setPlayerSetting('player_show_resize', val);
    _update((PlayerSettings c) => c.copyWith(showResize: val));
  }

  Future<void> setShowPlaybackSpeed(bool val) async {
    await _repository.setPlayerSetting('player_show_playback_speed', val);
    _update((PlayerSettings c) => c.copyWith(showPlaybackSpeed: val));
  }

  Future<void> setShowEpisodes(bool val) async {
    await _repository.setPlayerSetting('player_show_episodes', val);
    _update((PlayerSettings c) => c.copyWith(showEpisodes: val));
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
    _update(
      (PlayerSettings current) => current.copyWith(
        subtitleSize: size,
        subtitleColor: color,
        subtitleBackgroundColor: bg,
        subtitleBackgroundOpacity: opacity ?? current.subtitleBackgroundOpacity,
      ),
    );
  }

  Future<void> setPreferredPlayer(String? playerId) async {
    if (playerId == null) {
      await _repository.setPlayerSetting('player_preferred', null);
      _update(
        (PlayerSettings current) =>
            current.copyWith(clearPreferredPlayer: true),
      );
    } else {
      await _repository.setPlayerSetting('player_preferred', playerId);
      _update(
        (PlayerSettings current) => current.copyWith(preferredPlayer: playerId),
      );
    }
  }

  Future<void> setSubtitleBackgroundOpacity(double val) async {
    await _repository.setPlayerSetting('player_sub_bg_opacity', val);
    _update((PlayerSettings c) => c.copyWith(subtitleBackgroundOpacity: val));
  }

  Future<void> resetSubtitleSettings() async {
    await _repository.setPlayerSetting('player_sub_size', 22.0);
    await _repository.setPlayerSetting('player_sub_color', 0xFFFFFFFF);
    await _repository.setPlayerSetting('player_sub_bg', 0x00000000);
    await _repository.setPlayerSetting('player_sub_bg_opacity', 0.5);
    await _repository.setPlayerSetting('player_sub_pos', 100.0);

    _update(
      (PlayerSettings current) => current.copyWith(
        subtitleSize: 22.0,
        subtitleColor: 0xFFFFFFFF,
        subtitleBackgroundColor: 0x00000000,
        subtitleBackgroundOpacity: 0.5,
      ),
    );
  }

  Future<void> setWifiQuality(QualityPreference q) async {
    await _repository.setPlayerSetting('player_wifi_quality', q.name);
    _update((PlayerSettings c) => c.copyWith(wifiQuality: q));
  }

  Future<void> setMobileQuality(QualityPreference q) async {
    await _repository.setPlayerSetting('player_mobile_quality', q.name);
    _update((PlayerSettings c) => c.copyWith(mobileQuality: q));
  }

  Future<void> setQualityFilterMode(QualityFilterMode mode) async {
    await _repository.setPlayerSetting('player_quality_filter_mode', mode.name);
    _update((PlayerSettings c) => c.copyWith(qualityFilterMode: mode));
  }

  Future<void> setShowRemainingTime(bool val) async {
    await _repository.setPlayerSetting('player_show_remaining', val);
    _update((PlayerSettings c) => c.copyWith(showRemainingTime: val));
  }

  Future<void> setOpenSubtitlesCredentials(
    String user,
    String pass, [
    String? key,
  ]) async {
    await _repository.setPlayerSetting('player_os_user', user);
    // Secure store, and [SecureTokenStorage.write] clears any legacy plaintext
    // copy as it goes.
    await _credentials.write(kOsPasswordKey, pass);
    if (key != null) {
      await _repository.setPlayerSetting('player_os_key', key);
    }
    _update(
      (PlayerSettings current) =>
          current.copyWith(osUsername: user, osPassword: pass, osApiKey: key),
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
      await _credentials.write(kSubDlPasswordKey, pass);
    }

    _update(
      (PlayerSettings current) => current.copyWith(
        subdlApiKey: apiKey,
        subdlEmail: email ?? current.subdlEmail,
        subdlPassword: pass ?? current.subdlPassword,
      ),
    );
  }

  Future<void> setSubDlApiKey(String key) async {
    await _repository.setPlayerSetting('player_subdl_key', key);
    _update((PlayerSettings c) => c.copyWith(subdlApiKey: key));
  }

  Future<void> setSubSourceApiKey(String key) async {
    await _repository.setPlayerSetting('player_ss_key', key);
    _update((PlayerSettings c) => c.copyWith(subsourceApiKey: key));
  }

  /// Removes the two subtitle account passwords from the platform secure
  /// store.
  ///
  /// "Reset Data" empties the Hive box, which takes the usernames with it and
  /// leaves both rows reading "Not logged in" while the passwords are still on
  /// the device. Named keys only: the OAuth tokens share this store, and a
  /// reset that keeps extensions keeps those sessions too.
  Future<void> clearCredentials() async {
    await _credentials.delete(kOsPasswordKey);
    await _credentials.delete(kSubDlPasswordKey);
    _update(
      (PlayerSettings current) =>
          current.copyWith(osPassword: '', subdlPassword: ''),
    );
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
