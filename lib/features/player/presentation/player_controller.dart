import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:video_view/video_view.dart'
    show VideoController, SubtitleTrackConfig, VideoControllerPlaybackState;

import '../../../../core/logger/app_logger.dart';
import '../../../../core/services/download_service.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/extensions/base_provider.dart';
import '../../../../core/extensions/extension_manager.dart';
import '../../../../core/extensions/providers.dart';
import '../../../../core/models/torrent_status.dart';
import '../../../../core/storage/history_repository.dart';
import '../../../../core/storage/episode_watch_repository.dart';
import '../../library/presentation/history_provider.dart';
import '../../tracking/data/sync_manager.dart';
import '../../tracking/domain/sync_progress_item.dart';
import '../../../../core/providers/device_info_provider.dart';
import '../../../../core/utils/app_utils.dart';
import '../../settings/presentation/player_settings_provider.dart';
import '../../settings/presentation/general_settings_provider.dart';
import '../../../../core/services/local_proxy_service.dart';
import '../../../../core/network/http_defaults.dart';
import '../../../../core/utils/stream_quality_sorter.dart';
import '../../skip/data/intro_db_service.dart';
import '../../skip/data/anime_skip_service.dart';
import '../../skip/data/skip_service.dart';
import '../../../../core/storage/settings_repository.dart';

// Sentinel so copyWith can distinguish "not passed" from "explicitly null".
const Object _keep = Object();

enum PlaybackUiPhaseKind {
  idle,
  bootstrapping,
  fetchingSources,
  checkingSources,
  openingSource,
  switchingEngine,
  bufferingInitial,
  bufferingRuntime,
  switchingSource,
  reconnectingLive,
  loadingNextEpisode,
  manualSourcePick,
  error,
}

enum SourceAttemptStatus { pending, trying, failed, selected, playing }

class SourceAttemptEntry {
  final int index;
  final String label;
  final SourceAttemptStatus status;
  final bool isCurrent;

  const SourceAttemptEntry({
    required this.index,
    required this.label,
    this.status = SourceAttemptStatus.pending,
    this.isCurrent = false,
  });

  SourceAttemptEntry copyWith({
    int? index,
    String? label,
    SourceAttemptStatus? status,
    bool? isCurrent,
  }) {
    return SourceAttemptEntry(
      index: index ?? this.index,
      label: label ?? this.label,
      status: status ?? this.status,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }
}

class PlaybackUiPhase {
  final PlaybackUiPhaseKind kind;
  final String title;
  final String? subtitle;
  final String? detail;
  final bool fullscreenBlocking;
  final bool preserveCurrentFrame;
  final bool showGoLive;
  final int? attemptIndex;
  final int? attemptTotal;

  const PlaybackUiPhase({
    required this.kind,
    this.title = '',
    this.subtitle,
    this.detail,
    this.fullscreenBlocking = false,
    this.preserveCurrentFrame = false,
    this.showGoLive = false,
    this.attemptIndex,
    this.attemptTotal,
  });

  const PlaybackUiPhase.idle() : this(kind: PlaybackUiPhaseKind.idle);

  bool get showsInlineSourcePanel =>
      fullscreenBlocking &&
      const {
        PlaybackUiPhaseKind.checkingSources,
        PlaybackUiPhaseKind.openingSource,
        PlaybackUiPhaseKind.bufferingInitial,
        PlaybackUiPhaseKind.error,
      }.contains(kind);

  bool get allowsInlineSourceSelection => const {
    PlaybackUiPhaseKind.checkingSources,
    PlaybackUiPhaseKind.openingSource,
    PlaybackUiPhaseKind.bufferingInitial,
    PlaybackUiPhaseKind.manualSourcePick,
    PlaybackUiPhaseKind.error,
  }.contains(kind);

  bool get isIdle => kind == PlaybackUiPhaseKind.idle;

  PlaybackUiPhase copyWith({
    PlaybackUiPhaseKind? kind,
    Object? title = _keep,
    Object? subtitle = _keep,
    Object? detail = _keep,
    bool? fullscreenBlocking,
    bool? preserveCurrentFrame,
    bool? showGoLive,
    Object? attemptIndex = _keep,
    Object? attemptTotal = _keep,
  }) {
    return PlaybackUiPhase(
      kind: kind ?? this.kind,
      title: title == _keep ? this.title : title as String,
      subtitle: subtitle == _keep ? this.subtitle : subtitle as String?,
      detail: detail == _keep ? this.detail : detail as String?,
      fullscreenBlocking: fullscreenBlocking ?? this.fullscreenBlocking,
      preserveCurrentFrame: preserveCurrentFrame ?? this.preserveCurrentFrame,
      showGoLive: showGoLive ?? this.showGoLive,
      attemptIndex: attemptIndex == _keep
          ? this.attemptIndex
          : attemptIndex as int?,
      attemptTotal: attemptTotal == _keep
          ? this.attemptTotal
          : attemptTotal as int?,
    );
  }
}

class PlayerState {
  final String? errorMessage;
  final String playerTitle;
  final String? streamSubtitle;
  final List<StreamResult> streams;
  final int currentStreamIndex;
  final StreamResult? currentStream;
  final StreamResult? previousStream;
  final TorrentStatus? torrentStatus;
  final List<SubtitleFile> externalSubtitles;
  final bool showNextEpisodeOverlay;
  final String? nextEpisodeTitle;
  final String? nextEpisodePosterUrl;
  final double? nextEpisodeRating;
  final int? nextEpisodeNumber;
  final int? nextEpisodeSeason;
  final int? nextEpisodeRuntime;
  final String? nextEpisodeDescription;
  final bool isAdaptiveBufferingActive;
  final bool showEpisodeList;

  /// Whether the sources/audio/subtitles side panel is open. While open, the
  /// player chrome is hidden and auto-hide is suspended.
  final bool showSourcesPanel;

  /// Which tab the side panel should show: 0 = Sources, 1 = Audio, 2 = Subtitles.
  final int sourcesPanelTab;

  /// Whether the torrent content (file picker) side panel is open.
  final bool showContentPanel;
  final double playbackSpeed;
  final bool isLive;
  final double subtitleDelay;
  final String? imdbId;
  final int? tmdbId;

  /// Whether the active engine is video_view (ExoPlayer/AVPlayer) instead of media_kit.
  final bool useExoPlayer;
  final bool isSeekable;
  final PlaybackUiPhase uiPhase;
  final List<SourceAttemptEntry> sourceAttempts;
  final int? currentAttemptIndex;
  final int sourceSessionId;

  /// True when the quality filter was active but no streams matched — the
  /// Sources tab should show a fallback banner in this case.
  final bool qualityFilteredFallback;

  /// Non-null when a saved position was found; shows resume prompt instead of seeking silently.
  final int? resumePromptPosition;
  final double? resumePromptPercentage;
  final bool userSkippedOverlay;
  final List<SkipSegment> skipSegments;

  const PlayerState({
    this.errorMessage,
    this.playerTitle = '',
    this.streamSubtitle,
    this.streams = const [],
    this.currentStreamIndex = 0,
    this.currentStream,
    this.previousStream,
    this.torrentStatus,
    this.externalSubtitles = const [],
    this.showNextEpisodeOverlay = false,
    this.nextEpisodeTitle,
    this.nextEpisodePosterUrl,
    this.nextEpisodeRating,
    this.nextEpisodeNumber,
    this.nextEpisodeSeason,
    this.nextEpisodeRuntime,
    this.nextEpisodeDescription,
    this.isAdaptiveBufferingActive = false,
    this.showEpisodeList = false,
    this.showSourcesPanel = false,
    this.sourcesPanelTab = 0,
    this.showContentPanel = false,
    this.playbackSpeed = 1.0,
    this.isLive = false,
    this.isSeekable = false,
    this.subtitleDelay = 0.0,
    this.imdbId,
    this.tmdbId,
    this.useExoPlayer = false,
    this.uiPhase = const PlaybackUiPhase(
      kind: PlaybackUiPhaseKind.bootstrapping,
      fullscreenBlocking: true,
    ),
    this.sourceAttempts = const [],
    this.currentAttemptIndex,
    this.sourceSessionId = 0,
    this.qualityFilteredFallback = false,
    this.resumePromptPosition,
    this.resumePromptPercentage,
    this.userSkippedOverlay = false,
    this.skipSegments = const [],
  });

  // Derived from uiPhase — no separate field needed.
  bool get isLoading => const {
    PlaybackUiPhaseKind.bootstrapping,
    PlaybackUiPhaseKind.fetchingSources,
    PlaybackUiPhaseKind.checkingSources,
    PlaybackUiPhaseKind.openingSource,
    PlaybackUiPhaseKind.bufferingInitial,
  }.contains(uiPhase.kind);

  bool get isBuffering => uiPhase.kind == PlaybackUiPhaseKind.bufferingRuntime;

  bool get canSeek => !useExoPlayer || isSeekable;
  bool get supportsPlaybackSpeed => !isLive;
  double get maxPlaybackSpeed => useExoPlayer ? 2.0 : 3.0;
  bool get supportsVolumeBoost => !useExoPlayer;
  bool get supportsSubtitleDelay => !useExoPlayer;
  bool get supportsSubtitleStyling => !useExoPlayer;
  bool get supportsExternalSubtitleLoading =>
      !useExoPlayer || Platform.isAndroid;

  PlayerState copyWith({
    String? errorMessage,
    String? playerTitle,
    String? streamSubtitle,
    List<StreamResult>? streams,
    int? currentStreamIndex,
    StreamResult? currentStream,
    StreamResult? previousStream,
    Object? torrentStatus = _keep,
    List<SubtitleFile>? externalSubtitles,
    bool? showNextEpisodeOverlay,
    String? nextEpisodeTitle,
    String? nextEpisodePosterUrl,
    double? nextEpisodeRating,
    int? nextEpisodeNumber,
    int? nextEpisodeSeason,
    int? nextEpisodeRuntime,
    String? nextEpisodeDescription,
    bool? isAdaptiveBufferingActive,
    bool? showEpisodeList,
    bool? showSourcesPanel,
    int? sourcesPanelTab,
    bool? showContentPanel,
    double? playbackSpeed,
    bool? isLive,
    bool? isSeekable,
    double? subtitleDelay,
    String? imdbId,
    int? tmdbId,
    bool? useExoPlayer,
    PlaybackUiPhase? uiPhase,
    List<SourceAttemptEntry>? sourceAttempts,
    Object? currentAttemptIndex = _keep,
    int? sourceSessionId,
    bool? qualityFilteredFallback,
    Object? resumePromptPosition = _keep,
    Object? resumePromptPercentage = _keep,
    bool? userSkippedOverlay,
    List<SkipSegment>? skipSegments,
  }) {
    return PlayerState(
      errorMessage: errorMessage ?? this.errorMessage,
      playerTitle: playerTitle ?? this.playerTitle,
      streamSubtitle: streamSubtitle ?? this.streamSubtitle,
      streams: streams ?? this.streams,
      currentStreamIndex: currentStreamIndex ?? this.currentStreamIndex,
      currentStream: currentStream ?? this.currentStream,
      previousStream: previousStream ?? this.previousStream,
      torrentStatus: torrentStatus == _keep
          ? this.torrentStatus
          : torrentStatus as TorrentStatus?,
      externalSubtitles: externalSubtitles ?? this.externalSubtitles,
      showNextEpisodeOverlay:
          showNextEpisodeOverlay ?? this.showNextEpisodeOverlay,
      nextEpisodeTitle: nextEpisodeTitle ?? this.nextEpisodeTitle,
      nextEpisodePosterUrl: nextEpisodePosterUrl ?? this.nextEpisodePosterUrl,
      nextEpisodeRating: nextEpisodeRating ?? this.nextEpisodeRating,
      nextEpisodeNumber: nextEpisodeNumber ?? this.nextEpisodeNumber,
      nextEpisodeSeason: nextEpisodeSeason ?? this.nextEpisodeSeason,
      nextEpisodeRuntime: nextEpisodeRuntime ?? this.nextEpisodeRuntime,
      nextEpisodeDescription:
          nextEpisodeDescription ?? this.nextEpisodeDescription,
      isAdaptiveBufferingActive:
          isAdaptiveBufferingActive ?? this.isAdaptiveBufferingActive,
      showEpisodeList: showEpisodeList ?? this.showEpisodeList,
      showSourcesPanel: showSourcesPanel ?? this.showSourcesPanel,
      sourcesPanelTab: sourcesPanelTab ?? this.sourcesPanelTab,
      showContentPanel: showContentPanel ?? this.showContentPanel,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      isLive: isLive ?? this.isLive,
      isSeekable: isSeekable ?? this.isSeekable,
      subtitleDelay: subtitleDelay ?? this.subtitleDelay,
      imdbId: imdbId ?? this.imdbId,
      tmdbId: tmdbId ?? this.tmdbId,
      useExoPlayer: useExoPlayer ?? this.useExoPlayer,
      uiPhase: uiPhase ?? this.uiPhase,
      sourceAttempts: sourceAttempts ?? this.sourceAttempts,
      currentAttemptIndex: currentAttemptIndex == _keep
          ? this.currentAttemptIndex
          : currentAttemptIndex as int?,
      sourceSessionId: sourceSessionId ?? this.sourceSessionId,
      qualityFilteredFallback:
          qualityFilteredFallback ?? this.qualityFilteredFallback,
      resumePromptPosition: resumePromptPosition == _keep
          ? this.resumePromptPosition
          : resumePromptPosition as int?,
      resumePromptPercentage: resumePromptPercentage == _keep
          ? this.resumePromptPercentage
          : resumePromptPercentage as double?,
      userSkippedOverlay: userSkippedOverlay ?? this.userSkippedOverlay,
      skipSegments: skipSegments ?? this.skipSegments,
    );
  }
}

class PlayerTrackOption {
  final String id;
  final String label;
  final String? subtitle;
  final bool selected;

  const PlayerTrackOption({
    required this.id,
    required this.label,
    this.subtitle,
    this.selected = false,
  });
}

class PlayerTrackSelectionSnapshot {
  final List<PlayerTrackOption> audioTracks;
  final List<PlayerTrackOption> subtitleTracks;
  final bool subtitlesOffSelected;

  const PlayerTrackSelectionSnapshot({
    this.audioTracks = const [],
    this.subtitleTracks = const [],
    this.subtitlesOffSelected = true,
  });
}

class PlayerController extends Notifier<PlayerState> {
  late Player _player;
  VideoController? _videoViewController;
  late MultimediaItem _item;
  late String _videoUrl;
  Episode? _episode;
  Timer? _torrentPollTimer;
  bool _isPolling = false;
  bool _isInitialized = false;
  bool _isDisposed = false;

  bool _hasScrobbleStarted = false;
  bool _hasMarkedWatched = false;

  Player get player => _player;
  VideoController? get videoViewController => _videoViewController;
  bool get isDisposed => _isDisposed;
  PlayerState get currentState => state;
  List<SubtitleFile> get userAddedExternalSubtitles =>
      _userAddedExternalSubtitles;

  Set<String>? pendingVideoViewSubtitleIdsBeforeReload;
  bool selectNewestVideoViewSubtitleAfterReload = false;

  void updateState(PlayerState Function(PlayerState s) update) {
    state = update(state);
  }

  bool _isDashStreamUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.mpd') ||
        lower.contains('manifest.mpd') ||
        lower.contains('/dash/') ||
        lower.contains('format=mpd') ||
        lower.contains('type=mpd');
  }

  bool _streamRequiresNativeDrm(StreamResult stream) {
    return stream.drmKey != null ||
        stream.drmKid != null ||
        stream.licenseUrl != null;
  }

  bool _detectResolvedLiveState(String url) {
    return _item.contentType == MultimediaContentType.livestream ||
        _isLiveStream(url);
  }

  bool _canUseVideoViewForStream(
    String playUrl,
    StreamResult stream, {
    required bool isLive,
  }) {
    // Preserve the current product behavior: video_view is the native live path.
    if (_videoViewController == null || Platform.isLinux || !isLive) {
      return false;
    }

    // AVPlayer/Windows native backends do not handle DASH playback reliably here.
    // Check both the resolved URL and the original stream URL to catch proxied
    // or query-param-based MPD streams that lack a .mpd extension in the resolved URL.
    if ((Platform.isMacOS || Platform.isIOS || Platform.isWindows) &&
        (_isDashStreamUrl(playUrl) || _isDashStreamUrl(stream.url))) {
      return false;
    }

    // Only Android currently implements the video_view DRM path end-to-end.
    if (!Platform.isAndroid && _streamRequiresNativeDrm(stream)) {
      return false;
    }

    return true;
  }

  /// Build the header map handed to the player (mpv + video_view). Clones
  /// the plugin's headers so we never mutate the StreamResult, and injects a
  /// real browser User-Agent when the plugin didn't supply one — see
  /// http_defaults.dart for why this matters (resolve/playback identity
  /// match + per-platform libmpv default-UA divergence).
  Map<String, String> _buildPlaybackHeaders(StreamResult stream) {
    final headers = <String, String>{...?stream.headers};
    final hasUserAgent = headers.keys.any(
      (k) => k.toLowerCase() == 'user-agent',
    );
    if (!hasUserAgent) {
      headers['User-Agent'] = kDefaultBrowserUserAgent;
    }
    return headers;
  }

  bool get _videoViewSupportsMergedExternalSubtitles => Platform.isAndroid;

  // Track last saved position for threshold-based saving
  Duration _lastSavedPosition = Duration.zero;
  static const double _saveThresholdPercent = 0.05; // 5% of video

  // Subscriptions to prevent leaks
  StreamSubscription<dynamic>? _videoParamsSub;
  StreamSubscription<dynamic>? _errorSub;
  StreamSubscription<dynamic>? _playingSub;
  StreamSubscription<dynamic>? _positionSub;
  StreamSubscription<dynamic>? _durationSub;
  StreamSubscription<dynamic>? _bufferingSub;
  StreamSubscription<dynamic>? _completedSub;
  StreamSubscription<dynamic>? _rateSub;
  StreamSubscription<dynamic>? _logSub;
  StreamSubscription<dynamic>? _trackSub;

  // Stall Watchdog state
  Duration? _lastPosition;
  DateTime? _lastPositionUpdateTime;
  bool _isRecoveringFromStall = false;
  // Backstop timer for the stall-recovery flag. Primary path: clear the
  // flag in `_endStallRecovery()` immediately after `changeStream(...)`
  // completes. Backstop fires only if changeStream hangs longer than 10 s.
  // Without this, the flag was solely time-based — chained errors firing
  // at 9-s intervals would silently skip every other reconnect attempt
  // because the guard at the call sites bailed without scheduling a new
  // recovery (H-PLAYER-2).
  Timer? _stallRecoveryGuardTimer;

  final List<DateTime> _bufferDepletionTimes = [];
  Timer? _stallTimer;
  // Hide-debounce for the buffering overlay. Without this, a 250-350 ms
  // network blip would show the overlay (300 ms past the show-debounce)
  // then immediately hide it the moment buffering ends — visible flicker
  // (H-PLAYER-6). Keeping the overlay up for an extra ~200 ms after
  // buffering ends absorbs sub-second re-buffers without strobing.
  Timer? _bufferingHideTimer;

  /// Set [_isRecoveringFromStall] true, schedule a 10 s backstop clear,
  /// and run [perform]. If [perform] returns a Future, the flag clears as
  /// soon as the future completes (so a quick recovery doesn't block the
  /// next legitimate retry for 10 s). The backstop only fires if perform
  /// hangs (rare, but possible if changeStream gets wedged on a dead host).
  void _beginStallRecovery({Future<void>? perform}) {
    _isRecoveringFromStall = true;
    _stallRecoveryGuardTimer?.cancel();
    _stallRecoveryGuardTimer = Timer(const Duration(seconds: 10), () {
      _isRecoveringFromStall = false;
    });
    if (perform != null) {
      perform.whenComplete(() {
        _stallRecoveryGuardTimer?.cancel();
        _stallRecoveryGuardTimer = null;
        _isRecoveringFromStall = false;
      });
    }
  }

  int? _pendingResumeSeekPosition;
  double? _pendingResumeSeekPercentage;
  bool _isApplyingPendingResumeSeek = false;
  double _lastNonZeroVolumeLevel = 1.0;
  final List<SubtitleFile> _userAddedExternalSubtitles = [];
  bool _hasConfirmedPlaybackFrame = false;

  // RC1 — when a stream fails to start with a decode/codec error (common on
  // weak TV hardware decoders like FireTV's MediaCodec), we retry the same
  // source once with hardware decoding off. This flag forces `hwdec: no` in
  // _applyPlaybackProperties for the rest of the session. Reset only on a new
  // item (init), not per-source, because a broken HW decoder affects every
  // source equally.
  bool _forceSoftwareDecode = false;

  // Bug 4 — provider stream URLs are usually short-lived signed links. After
  // a long pause the token expires; on resume the fetch 403/410s. We
  // re-resolve the SAME source once (fresh URL, same position) before falling
  // back to a different source. Reset on every confirmed playback frame so
  // each playback session gets one re-resolve attempt.
  bool _staleUrlReResolveAttempted = false;
  bool _suppressNextEpisodeDetection = false;
  bool _isNextEpisodeOverlayForced = false;
  bool _userDismissedOverlay = false;
  bool _manualSelectionPending = false;
  // Audio tracks that have already failed with decode errors for the current
  // stream. When one track fails, we try the next one before source-switching.
  final Set<String> _failedAudioTrackIds = {};
  // Last real audio track that was actively playing (mpv resets state.track.audio
  // to "no" before the error event fires, so we track it here via stream.track).
  String? _lastKnownAudioTrackId;
  DateTime? _audioFailoverLastTime;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isAppBackgrounded = false;
  int _midPlaybackRetryCount = 0;
  bool _isReconnectingCurrentStream = false;
  Timer? _midPlaybackRetryTimer;

  void setAppBackgrounded(bool backgrounded) {
    _isAppBackgrounded = backgrounded;
    if (kDebugMode) {
      debugPrint('[Player] App backgrounded state: $backgrounded');
    }
    if (!backgrounded &&
        _hasConfirmedPlaybackFrame &&
        state.uiPhase.kind == PlaybackUiPhaseKind.bufferingRuntime) {
      // Returning to foreground while in buffering/reconnecting state — kick reconnection immediately
      _midPlaybackRetryTimer?.cancel();
      unawaited(_triggerMidPlaybackReconnect());
    }
  }

  String _phaseTitle([String? fallback]) {
    if (state.playerTitle.isNotEmpty) return state.playerTitle;
    if (_isInitialized) return _item.title;
    return fallback ?? '';
  }

  String? _phaseSubtitle([String? fallback]) {
    return fallback ?? state.streamSubtitle;
  }

  PlaybackUiPhase _composeUiPhase({
    required PlaybackUiPhaseKind kind,
    String? title,
    String? subtitle,
    String? detail,
    bool? fullscreenBlocking,
    bool? preserveCurrentFrame,
    bool? showGoLive,
    int? attemptIndex,
    int? attemptTotal,
  }) {
    // Error phase always blocks — even after a frame was confirmed — so the
    // user sees a clear "all sources failed" screen and can navigate back.
    // All other phases never block once a frame has been confirmed.
    final bool effectiveFullscreenBlocking;
    if (kind == PlaybackUiPhaseKind.error) {
      effectiveFullscreenBlocking = fullscreenBlocking ?? true;
    } else if (_hasConfirmedPlaybackFrame) {
      effectiveFullscreenBlocking = false;
    } else if (state.userSkippedOverlay && kind != PlaybackUiPhaseKind.idle) {
      effectiveFullscreenBlocking = false;
    } else {
      effectiveFullscreenBlocking = fullscreenBlocking ?? true;
    }

    return PlaybackUiPhase(
      kind: kind,
      title: title ?? _phaseTitle(),
      subtitle: subtitle ?? _phaseSubtitle(),
      detail: detail,
      fullscreenBlocking: effectiveFullscreenBlocking,
      preserveCurrentFrame: preserveCurrentFrame ?? _hasConfirmedPlaybackFrame,
      showGoLive: showGoLive ?? false,
      attemptIndex: attemptIndex,
      attemptTotal: attemptTotal,
    );
  }

  void _setUiPhase(PlaybackUiPhase phase) {
    state = state.copyWith(uiPhase: phase);
  }

  void _setIdlePhase() {
    if (!state.uiPhase.isIdle) {
      state = state.copyWith(uiPhase: const PlaybackUiPhase.idle());
    }
  }

  void _enterStartupPhase({
    required PlaybackUiPhaseKind kind,
    String? title,
    String? subtitle,
    String? detail,
    int? attemptIndex,
    int? attemptTotal,
  }) {
    _setUiPhase(
      _composeUiPhase(
        kind: kind,
        title: title,
        subtitle: subtitle,
        detail: detail,
        fullscreenBlocking: true,
        preserveCurrentFrame: false,
        attemptIndex: attemptIndex,
        attemptTotal: attemptTotal,
      ),
    );
  }

  void _enterRuntimePhase({
    required PlaybackUiPhaseKind kind,
    String? title,
    String? subtitle,
    String? detail,
  }) {
    _setUiPhase(
      _composeUiPhase(
        kind: kind,
        title: title,
        subtitle: subtitle,
        detail: detail,
        fullscreenBlocking: false,
        preserveCurrentFrame: true,
      ),
    );
  }

  void _enterAllSourcesFailedPhase({String? detail}) {
    _setUiPhase(
      _composeUiPhase(
        kind: PlaybackUiPhaseKind.error,
        title: "Playback Error",
        subtitle: detail ?? "All sources failed.",
        detail:
            "None of the available sources could be played. "
            "Try again later",
        fullscreenBlocking: true,
        preserveCurrentFrame: true,
        attemptIndex: null,
        attemptTotal: null,
      ),
    );
  }

  int _beginSourceSession({bool resetAttempts = false}) {
    final nextSessionId = state.sourceSessionId + 1;
    _userDismissedOverlay = false;
    state = state.copyWith(
      sourceSessionId: nextSessionId,
      currentAttemptIndex: null,
      sourceAttempts: resetAttempts ? const [] : state.sourceAttempts,
      userSkippedOverlay: false,
    );
    return nextSessionId;
  }

  bool _isCurrentSourceSession(int sessionId) =>
      state.sourceSessionId == sessionId;

  void _setSourceAttemptsFromStreams(
    List<StreamResult> streams, {
    int? activeIndex,
    SourceAttemptStatus? activeStatus,
  }) {
    final attempts = <SourceAttemptEntry>[
      for (int i = 0; i < streams.length; i++)
        SourceAttemptEntry(
          index: i,
          label: streams[i].source,
          status: i == activeIndex
              ? (activeStatus ?? SourceAttemptStatus.pending)
              : SourceAttemptStatus.pending,
          isCurrent: i == activeIndex,
        ),
    ];
    state = state.copyWith(
      sourceAttempts: attempts,
      currentAttemptIndex: activeIndex,
    );
  }

  void _markSourceAttempt(
    int index,
    SourceAttemptStatus status, {
    bool isCurrent = true,
  }) {
    if (index < 0 || index >= state.sourceAttempts.length) return;

    final updated = [
      for (final entry in state.sourceAttempts)
        if (entry.index == index)
          entry.copyWith(status: status, isCurrent: isCurrent)
        else if (isCurrent)
          entry.copyWith(isCurrent: false)
        else
          entry,
    ];

    state = state.copyWith(
      sourceAttempts: updated,
      currentAttemptIndex: isCurrent
          ? index
          : (state.currentAttemptIndex == index
                ? null
                : state.currentAttemptIndex),
    );
  }

  void _confirmPlaybackStarted() {
    _hasConfirmedPlaybackFrame = true;
    _manualSelectionPending = false; // source played — no longer pending
    // A frame confirmed → this playback session is healthy. Re-arm the
    // one-shot stale-URL re-resolve so the NEXT expiry (e.g. after another
    // long pause) is also handled rather than falling straight to a
    // different source.
    _staleUrlReResolveAttempted = false;
    // Do NOT reset _suppressNextEpisodeDetection here. At the moment position
    // first exceeds zero, _player.state.duration may still hold the previous
    // episode's value (mpv resets it asynchronously). Resetting here would
    // cause the next-episode detection to see remaining ≈ 0 and show the
    // overlay for the newly loaded episode. It is reset in _setupDurationListener
    // once a valid non-zero duration for the new episode arrives.
    final currentAttemptIndex = state.currentAttemptIndex;
    if (currentAttemptIndex != null) {
      _markSourceAttempt(currentAttemptIndex, SourceAttemptStatus.playing);
    }
    state = state.copyWith(uiPhase: const PlaybackUiPhase.idle());
  }

  @override
  PlayerState build() {
    ref.keepAlive();
    // Safety net: if the provider is somehow disposed without
    // disposeController() being called, clean up subscriptions.
    ref.onDispose(() {
      _torrentPollTimer?.cancel();
      _stallTimer?.cancel();
      _videoParamsSub?.cancel();
      _errorSub?.cancel();
      _playingSub?.cancel();
      _positionSub?.cancel();
      _durationSub?.cancel();
      _bufferingSub?.cancel();
      _completedSub?.cancel();
      _rateSub?.cancel();
      _logSub?.cancel();
      _trackSub?.cancel();
      _connectivitySub?.cancel();
      _midPlaybackRetryTimer?.cancel();
    });
    return const PlayerState();
  }

  bool get isSeries =>
      _isInitialized &&
      (_item.contentType == MultimediaContentType.series ||
          _item.contentType == MultimediaContentType.anime);
  MultimediaItem? get multimediaItem => _isInitialized ? _item : null;
  String? get currentEpisodeUrl => _episode?.url ?? _videoUrl;
  Episode? get currentEpisode => _episode ?? _resolveCurrentEpisode();

  Future<void> init({
    required Player player,
    required MultimediaItem item,
    required String videoUrl,
    Episode? episode,
    VideoController? videoViewController,
  }) async {
    state = const PlayerState(); // Resets all fields including errorMessage
    _isDisposed = false; // Reset disposal flag on re-initialization
    unawaited(_logSub?.cancel());
    _logSub = null;
    _hasConfirmedPlaybackFrame = false;
    _manualSelectionPending = false;
    _revertMessage = null;
    // New item — reset session-scoped recovery flags.
    _forceSoftwareDecode = false;
    _staleUrlReResolveAttempted = false;
    _isAppBackgrounded = false;
    _midPlaybackRetryCount = 0;
    _isReconnectingCurrentStream = false;
    _midPlaybackRetryTimer?.cancel();
    _midPlaybackRetryTimer = null;
    _player = player;
    _videoViewController = videoViewController;
    _videoUrl = videoUrl;
    _episode = episode;
    _pendingResumeSeekPosition = null;
    _isApplyingPendingResumeSeek = false;
    _userAddedExternalSubtitles.clear();
    pendingVideoViewSubtitleIdsBeforeReload = null;
    selectNewestVideoViewSubtitleAfterReload = false;
    _hasScrobbleStarted = false;
    _hasMarkedWatched = false;
    ref.read(syncManagerProvider).clearCache();

    _item = item;

    String initialTitle = item.title;
    // Resolve Episode Title if Series
    if (item.episodes != null && item.episodes!.isNotEmpty) {
      if (item.episodes!.length > 1) {
        try {
          final ep = item.episodes!.firstWhere(
            (e) => e.url == videoUrl,
            orElse: () => item.episodes!.first,
          );

          if (ep.url == videoUrl) {
            String epTitle = "";
            if (ep.season > 0 && ep.episode > 0) {
              epTitle = "S${ep.season}:E${ep.episode}";
            } else if (ep.episode > 0) {
              epTitle = "E${ep.episode}";
            }

            if (ep.name.isNotEmpty && ep.name != "Episode ${ep.episode}") {
              epTitle = "$epTitle - ${ep.name}";
            }

            if (epTitle.isNotEmpty) {
              if (epTitle.startsWith(" - ")) epTitle = epTitle.substring(3);
              initialTitle = "${item.title} $epTitle";
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('PlayerController.init: $e');
        }
      }
    }

    final imdbId =
        item.imdbId ?? item.syncData?['imdbId'] ?? item.syncData?['imdb_id'];
    final tmdbId = item.tmdbId;

    state = state.copyWith(
      playerTitle: initialTitle,
      streamSubtitle: "Searching for sources...",
      imdbId: imdbId,
      tmdbId: tmdbId,
    );
    _enterStartupPhase(
      kind: PlaybackUiPhaseKind.bootstrapping,
      detail: "Preparing playback...",
    );

    _setupEventDrivenProgressSaving();
    _setupErrorListener();
    _setupVideoParamsListener();
    _setupDurationListener();
    _setupBufferingMonitor();
    _setupRateListener();
    _setupVideoViewListeners();
    _setupConnectivityListener();

    state = state.copyWith(
      isLive:
          _item.contentType == MultimediaContentType.livestream ||
          _isLiveStream(_videoUrl),
    );

    _isInitialized = true;
    unawaited(_fetchAndLogSkipSegments());

    await _initStream();
    if (_isDisposed) return;
    await applySubtitleSettings();

    // Restore the persisted default playback speed for this session.
    // Skipped at 1.0× (engine default — no-op) and on live streams (rate
    // changes on a live source are usually ignored / fight back).
    final settings = ref.read(playerSettingsProvider).asData?.value;
    final defaultSpeed = settings?.defaultPlaybackSpeed ?? 1.0;
    if (defaultSpeed != 1.0 && !state.isLive) {
      await setPlaybackSpeed(defaultSpeed);
    }
  }

  Future<void> _fetchAndLogSkipSegments() async {
    if (_episode == null) return;
    if (state.isLive || _item.contentType == MultimediaContentType.livestream) {
      if (kDebugMode) {
        debugPrint(
          'Skip Segments: Bypassed lookup (livestreams are not supported)',
        );
      }
      return;
    }

    final hasNoIds =
        state.tmdbId == null &&
        state.imdbId == null &&
        _item.syncData?['anilist'] == null &&
        _item.syncData?['anilistId'] == null &&
        _item.syncData?['anilist_id'] == null;

    if (hasNoIds) {
      if (kDebugMode) {
        debugPrint(
          'Skip Segments: Bypassed lookup (no TMDB/IMDB/AniList IDs available)',
        );
      }
      return;
    }

    if (kDebugMode) {
      debugPrint('=============================================');
      debugPrint('SKIP SEGMENTS (IntroDB/AnimeSkip)');
    }

    final List<SkipSegment> allSegments = [];
    final int season = _episode!.season > 0 ? _episode!.season : 1;
    final int episodeNum = _episode!.episode > 0 ? _episode!.episode : 1;

    // 1. Fetch from IntroDB (for both Anime and Western TV Shows/Movies)
    final settingsRepo = ref.read(settingsRepositoryProvider);
    if (settingsRepo.isIntroDbIntegrationEnabled()) {
      try {
        final introDb = ref.read(introDbServiceProvider);
        final segments = await introDb.getSkipSegments(
          tmdbId: state.tmdbId,
          imdbId: state.imdbId,
          season: season,
          episode: episodeNum,
        );
        if (_isDisposed) return;
        if (segments.isNotEmpty) {
          allSegments.addAll(segments);
          if (kDebugMode) {
            debugPrint('IntroDB returned ${segments.length} segments:');
            for (final s in segments) {
              debugPrint('  - ${s.type.name}: ${s.startTime} -> ${s.endTime}');
            }
          }
        } else {
          if (kDebugMode) debugPrint('IntroDB returned 0 segments');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('IntroDB error: $e');
      }
    } else {
      if (kDebugMode) {
        debugPrint('IntroDB integration is disabled in settings.');
      }
    }

    if (_isDisposed) return;

    // 2. Check if the media is anime or animated to run AnimeSkip logic
    final isAnime =
        _item.contentType == MultimediaContentType.anime ||
        _item.syncData?['anilist'] != null ||
        _item.syncData?['anilistId'] != null ||
        _item.syncData?['anilist_id'] != null ||
        (_item.tags != null &&
            _item.tags!.any(
              (t) =>
                  t.toLowerCase() == 'anime' || t.toLowerCase() == 'animation',
            ));

    if (isAnime) {
      if (settingsRepo.isAnimeSkipIntegrationEnabled()) {
        try {
          final anilistId =
              _item.syncData?['anilist'] ??
              _item.syncData?['anilistId'] ??
              _item.syncData?['anilist_id'];

          if (_isDisposed) return;

          if (anilistId != null) {
            final animeSkip = ref.read(animeSkipServiceProvider);
            final segments = await animeSkip.getSkipSegments(
              anilistId: int.tryParse(anilistId.toString()),
              season: season,
              episode: episodeNum,
            );
            if (_isDisposed) return;
            if (segments.isNotEmpty) {
              // AnimeSkip data is richer and more accurate for anime. Disregard IntroDB.
              allSegments.clear();
              allSegments.addAll(segments);
              if (kDebugMode) {
                debugPrint('AnimeSkip returned ${segments.length} segments:');
                for (final s in segments) {
                  debugPrint(
                    '  - ${s.type.name}: ${s.startTime} -> ${s.endTime}',
                  );
                }
              }
            } else {
              if (kDebugMode) debugPrint('AnimeSkip returned 0 segments');
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('AnimeSkip error: $e');
        }
      } else {
        if (kDebugMode) {
          debugPrint('AnimeSkip integration is disabled in settings.');
        }
      }
    } else {
      if (kDebugMode) {
        debugPrint(
          'AnimeSkip: Bypassed lookup (media type is not anime/animated)',
        );
      }
    }
    if (kDebugMode) debugPrint('=============================================');

    if (allSegments.isNotEmpty && !_isDisposed) {
      // Sort segments by start time
      allSegments.sort((a, b) => a.startTime.compareTo(b.startTime));

      // Merge overlapping segments if needed, or simply assign them.
      // Usually, IntroDB is highly accurate but AnimeSkip provides more detailed segments.
      // For now, we'll store all of them, but UI might prioritize or filter duplicates.
      state = state.copyWith(skipSegments: allSegments);
    }
  }

  void _setupVideoViewListeners() {
    if (_videoViewController == null) return;

    _videoViewController!.mediaInfo.addListener(() {
      final info = _videoViewController!.mediaInfo.value;
      if (info != null) {
        final detectedIsLive =
            _item.contentType == MultimediaContentType.livestream
            ? true
            : info.isLive;
        if (info.isSeekable != state.isSeekable ||
            detectedIsLive != state.isLive) {
          state = state.copyWith(
            isSeekable: info.isSeekable,
            isLive: detectedIsLive,
          );
        }

        if (!_hasConfirmedPlaybackFrame &&
            (info.duration > 0 || info.isLive) &&
            state.uiPhase.kind == PlaybackUiPhaseKind.openingSource) {
          _enterStartupPhase(
            kind: PlaybackUiPhaseKind.bufferingInitial,
            detail: detectedIsLive
                ? "Connecting to live stream..."
                : "Buffering selected source...",
            attemptIndex: state.currentAttemptIndex == null
                ? null
                : state.currentAttemptIndex! + 1,
            attemptTotal: state.sourceAttempts.isEmpty
                ? null
                : state.sourceAttempts.length,
          );
        }

        // Re-enable next-episode detection once ExoPlayer reports a confirmed
        // non-zero duration (mirrors the media_kit _setupDurationListener fix).
        if ((info.duration > 0 || info.isLive) &&
            _suppressNextEpisodeDetection) {
          _suppressNextEpisodeDetection = false;
        }

        if (selectNewestVideoViewSubtitleAfterReload &&
            info.subtitleTracks.isNotEmpty) {
          final previousIds =
              pendingVideoViewSubtitleIdsBeforeReload ?? const <String>{};
          final newTrackId =
              info.subtitleTracks.keys.firstWhereOrNull(
                (id) => !previousIds.contains(id),
              ) ??
              info.subtitleTracks.keys.lastOrNull;
          if (newTrackId != null) {
            _videoViewController!.setShowSubtitle(true);
            _videoViewController!.setOverrideSubtitle(newTrackId);
          }
          pendingVideoViewSubtitleIdsBeforeReload = null;
          selectNewestVideoViewSubtitleAfterReload = false;
        }
      }
    });

    _videoViewController!.loading.addListener(() {
      final isLoading = _videoViewController!.loading.value;
      if (isLoading) {
        _handleBufferStall();
        // Buffering started — cancel any pending HIDE (we're back in
        // buffering state, the overlay should stay/come up). Schedule the
        // SHOW debounce; 400 ms swallows sub-half-second blips without
        // flashing the overlay (H-PLAYER-6).
        _bufferingHideTimer?.cancel();
        _stallTimer?.cancel();
        _stallTimer = Timer(const Duration(milliseconds: 400), () {
          if (_hasConfirmedPlaybackFrame) {
            _enterRuntimePhase(
              kind: PlaybackUiPhaseKind.bufferingRuntime,
              detail: state.isLive
                  ? "Reconnecting to live stream..."
                  : "Buffering playback...",
            );
          } else {
            _enterStartupPhase(
              kind: PlaybackUiPhaseKind.bufferingInitial,
              detail: state.isLive
                  ? "Connecting to live stream..."
                  : "Buffering selected source...",
              attemptIndex: state.currentAttemptIndex == null
                  ? null
                  : state.currentAttemptIndex! + 1,
              attemptTotal: state.sourceAttempts.isEmpty
                  ? null
                  : state.sourceAttempts.length,
            );
          }
        });
      } else {
        // Buffering ended — cancel the show timer first (in case the blip
        // ended within the 400 ms window, never show the overlay at all).
        _stallTimer?.cancel();
        // Then defer the hide by 200 ms so a rapid re-buffer doesn't
        // strobe the overlay off→on→off.
        if (_hasConfirmedPlaybackFrame &&
            state.uiPhase.kind == PlaybackUiPhaseKind.bufferingRuntime) {
          _bufferingHideTimer?.cancel();
          _bufferingHideTimer = Timer(const Duration(milliseconds: 200), () {
            if (state.uiPhase.kind == PlaybackUiPhaseKind.bufferingRuntime) {
              _setIdlePhase();
            }
          });
        }
      }
    });

    _videoViewController!.error.addListener(() {
      final error = _videoViewController!.error.value;
      if (error != null) {
        pendingVideoViewSubtitleIdsBeforeReload = null;
        selectNewestVideoViewSubtitleAfterReload = false;
        if (kDebugMode) debugPrint("VideoView Player Error: $error");
        if (_isAppBackgrounded) {
          if (kDebugMode) {
            debugPrint("VideoView: Ignoring transient error while backgrounded.");
          }
          return;
        }
        if (!_hasConfirmedPlaybackFrame ||
            (_videoViewController!.position.value) == 0) {
          // Error before playback confirmed — try next source.
          _markSourceAttempt(
            state.currentStreamIndex,
            SourceAttemptStatus.failed,
            isCurrent: false,
          );
          if (_manualSelectionPending) {
            _manualSelectionPending = false;
            revertToPreviousStream(
              "Selected source is not playable. Reverting back to previous source.",
            );
          } else {
            unawaited(retryNextStream(sourceSessionId: state.sourceSessionId));
          }
        } else {
          // Error during active playback.
          if (state.isLive && state.currentStream != null) {
            if (_isRecoveringFromStall) return; // already reconnecting
            if (kDebugMode) {
              debugPrint(
                "VideoView live stream error. Triggering reconnect...",
              );
            }
            _enterRuntimePhase(
              kind: PlaybackUiPhaseKind.reconnectingLive,
              detail: "Reconnecting to live stream...",
            );
            _beginStallRecovery(
              perform: changeStream(state.currentStream!, resetPosition: true),
            );
            return;
          }
          if (_isReconnectingCurrentStream) return;
          if (_midPlaybackRetryCount < 3 && state.currentStream != null) {
            _midPlaybackRetryCount++;
            unawaited(_triggerMidPlaybackReconnect());
            return;
          }
          _markSourceAttempt(
            state.currentStreamIndex,
            SourceAttemptStatus.failed,
            isCurrent: false,
          );
          _revertMessage =
              "Current source stopped unexpectedly. Trying next available source...";
          unawaited(retryNextStream(sourceSessionId: state.sourceSessionId));
        }
      }
    });

    _videoViewController!.playbackState.addListener(() {
      final playing =
          _videoViewController!.playbackState.value ==
          VideoControllerPlaybackState.playing;
      if (!playing) {
        saveProgress();
        // Bug 2 (ExoPlayer branch): clear buffering overlay on pause.
        // See media_kit branch in _setupEventDrivenProgressSaving for
        // rationale.
        _stallTimer?.cancel();
        _bufferingHideTimer?.cancel();
        if (state.uiPhase.kind == PlaybackUiPhaseKind.bufferingRuntime) {
          _setIdlePhase();
        }
      } else {
        // Do NOT call _confirmPlaybackStarted() here — ExoPlayer/AVPlayer fires
        // playbackState=playing when it starts buffering, before any frames arrive.
        // Confirmation happens via position listener (position > 0).
      }
    });

    _videoViewController!.finishedTimes.addListener(() {
      final completions = _videoViewController!.finishedTimes.value;
      if (completions > 0) {
        final isLive =
            _item.contentType == MultimediaContentType.livestream ||
            _isLiveStream(_videoUrl);
        if (isLive && state.currentStream != null) {
          _enterRuntimePhase(
            kind: PlaybackUiPhaseKind.reconnectingLive,
            detail: "Reconnecting to live stream...",
          );
          unawaited(changeStream(state.currentStream!, resetPosition: true));
        }
      }
    });

    _videoViewController!.position.addListener(() {
      if (!state.useExoPlayer) return;

      final posMs = _videoViewController!.position.value;
      final durationMs = _videoViewController!.mediaInfo.value?.duration ?? 0;

      if (posMs > 0 && !_hasConfirmedPlaybackFrame) {
        _confirmPlaybackStarted();
      }

      if (_midPlaybackRetryCount > 0 &&
          _videoViewController!.playbackState.value ==
              VideoControllerPlaybackState.playing) {
        _midPlaybackRetryCount = 0;
        _staleUrlReResolveAttempted = false;
        _isReconnectingCurrentStream = false;
        _midPlaybackRetryTimer?.cancel();
      }

      if (durationMs == 0) return;

      final currentPct = posMs / durationMs;
      final lastPct = _lastSavedPosition.inMilliseconds / durationMs;

      if ((currentPct - lastPct).abs() >= _saveThresholdPercent) {
        saveProgress();
        _lastSavedPosition = Duration(milliseconds: posMs);
      }

      if (!_suppressNextEpisodeDetection &&
          (_item.contentType == MultimediaContentType.series ||
              _item.contentType == MultimediaContentType.anime)) {
        final remainingSecs = (durationMs - posMs) / 1000;

        // Show next episode overlay if within last 15 seconds or video ended.
        // It persists until the user dismisses it or loads a new episode.
        if (remainingSecs <= 15.0) {
          final next = getNextEpisode();
          if (next != null) {
            if (!_userDismissedOverlay && !state.showNextEpisodeOverlay) {
              state = state.copyWith(
                showNextEpisodeOverlay: true,
                nextEpisodeTitle: next.name,
                nextEpisodePosterUrl: next.posterUrl,
                nextEpisodeRating: next.rating,
                nextEpisodeNumber: next.episode,
                nextEpisodeSeason: next.season,
                nextEpisodeRuntime: next.runtime,
                nextEpisodeDescription: next.description,
              );
            }
            // Ensure it persists if video completes and resets position
            _isNextEpisodeOverlayForced = true;
          }
          return;
        }

        if (remainingSecs > 15.0) {
          if (state.showNextEpisodeOverlay && !_isNextEpisodeOverlayForced) {
            state = state.copyWith(showNextEpisodeOverlay: false);
          }
        }
      }
    });
  }

  void forceNextEpisodeOverlay() {
    if (_item.contentType != MultimediaContentType.series &&
        _item.contentType != MultimediaContentType.anime) {
      return;
    }
    if (_userDismissedOverlay) return;

    final next = getNextEpisode();
    if (next != null) {
      _isNextEpisodeOverlayForced = true;
      state = state.copyWith(
        showNextEpisodeOverlay: true,
        nextEpisodeTitle: next.name,
        nextEpisodePosterUrl: next.posterUrl,
        nextEpisodeRating: next.rating,
        nextEpisodeNumber: next.episode,
        nextEpisodeSeason: next.season,
        nextEpisodeRuntime: next.runtime,
        nextEpisodeDescription: next.description,
      );
    }
  }

  void _setupRateListener() {
    _rateSub?.cancel();
    _rateSub = _player.stream.rate.listen((rate) {
      state = state.copyWith(playbackSpeed: rate);
    });
  }

  void _setupDurationListener() {
    _durationSub?.cancel();
    _durationSub = _player.stream.duration.listen((duration) {
      if (duration > Duration.zero) {
        // Retry whenever either pending field is set. The percentage-only
        // path (Trakt/Simkl synced progress) needs the duration to compute
        // the absolute ms; if the user taps Resume before duration arrives,
        // _flushPendingResumeSeek early-returns with the pending pct still
        // set. Without this check, the resume silently dropped — the user
        // saw playback start from 0 even though they tapped "Resume".
        if (_pendingResumeSeekPosition != null ||
            _pendingResumeSeekPercentage != null) {
          unawaited(_flushPendingResumeSeek());
        }
        // Safe point to re-enable next-episode detection: the new episode's
        // duration is now confirmed, so remaining-time calculations are valid.
        if (_suppressNextEpisodeDetection) {
          _suppressNextEpisodeDetection = false;
        }
      }
    });
  }

  void _setupVideoParamsListener() {
    // Intentionally empty: videoParams fires as soon as the container is parsed,
    // before any frames are rendered or position advances. Using it as a
    // confirmation trigger caused premature overlay dismissal → flickering retries.
    // Confirmation is handled solely by position > 0 (positionSub) and the
    // video_view position listener, which are reliable indicators of real playback.
    _videoParamsSub = _player.stream.videoParams.listen((_) {});
  }

  void _setupBufferingMonitor() {
    _bufferingSub?.cancel();
    _bufferingSub = _player.stream.buffering.listen((isBuffering) {
      if (isBuffering) {
        _handleBufferStall();
        // Cancel pending hide and arm the show debounce. See ExoPlayer
        // branch comment above for the 400 ms / 200 ms rationale.
        _bufferingHideTimer?.cancel();
        _stallTimer?.cancel();
        _stallTimer = Timer(const Duration(milliseconds: 400), () {
          if (_hasConfirmedPlaybackFrame) {
            _enterRuntimePhase(
              kind: PlaybackUiPhaseKind.bufferingRuntime,
              detail: state.isLive
                  ? "Reconnecting to live stream..."
                  : "Buffering playback...",
            );
          } else {
            _enterStartupPhase(
              kind: PlaybackUiPhaseKind.bufferingInitial,
              detail: state.isLive
                  ? "Connecting to live stream..."
                  : "Buffering selected source...",
              attemptIndex: state.currentAttemptIndex == null
                  ? null
                  : state.currentAttemptIndex! + 1,
              attemptTotal: state.sourceAttempts.isEmpty
                  ? null
                  : state.sourceAttempts.length,
            );
          }
        });
      } else {
        _stallTimer?.cancel();
        if (_hasConfirmedPlaybackFrame &&
            state.uiPhase.kind == PlaybackUiPhaseKind.bufferingRuntime) {
          _bufferingHideTimer?.cancel();
          _bufferingHideTimer = Timer(const Duration(milliseconds: 200), () {
            if (state.uiPhase.kind == PlaybackUiPhaseKind.bufferingRuntime) {
              _setIdlePhase();
            }
          });
        }
      }
    });
  }

  void _handleBufferStall() {
    if (!_hasConfirmedPlaybackFrame) {
      return; // ignore stalls during source health check
    }
    if (_isLiveStream(_videoUrl)) return;

    final now = DateTime.now();
    _bufferDepletionTimes.add(now);

    // Keep only stalls in the last 60 seconds
    _bufferDepletionTimes.removeWhere(
      (t) => now.difference(t) > const Duration(seconds: 60),
    );

    if (_bufferDepletionTimes.length >= 2 && !state.isAdaptiveBufferingActive) {
      if (kDebugMode) {
        debugPrint(
          "Multiple buffer stalls detected. Activating adaptive buffering.",
        );
      }
      state = state.copyWith(isAdaptiveBufferingActive: true);

      // Re-apply properties with aggressive buffering
      if (_player.platform is NativePlayer) {
        final settings = ref.read(playerSettingsProvider).asData?.value;
        final readahead = (settings?.readaheadSeconds ?? 180) * 2;
        final native = _player.platform as NativePlayer;
        // Double the readahead and cache for VOD if stalled
        if (_player.state.duration > Duration.zero) {
          native.setProperty('demuxer-readahead-secs', '$readahead');
          native.setProperty('cache-secs', '$readahead');
        }
      }
    }
  }

  void _setupErrorListener() {
    // Record the last real audio track so we know which one failed when the
    // error fires (mpv resets state.track.audio to "no" before the error
    // event propagates, making state.track.audio unreliable at error time).
    _trackSub?.cancel();
    _trackSub = _player.stream.track.listen((track) {
      final id = track.audio.id.toString();
      if (id != 'no' && id != 'auto') {
        _lastKnownAudioTrackId = id;
      }
    });

    _errorSub = _player.stream.error.listen((error) {
      if (kDebugMode) debugPrint("Player Error: $error");
      final errStr = error.toString().toLowerCase();
      if (errStr.contains("abort") ||
          errStr.contains("expected '='") ||
          errStr.contains("option syntax")) {
        return;
      }

      final isAudioDecodeError = error.toString().toLowerCase().contains(
        'decoding audio',
      );

      // Video decode errors (h264 hardware-accelerator failures, PPS/SPS state
      // loss after an audio track switch) are transient during active playback:
      // the decoder self-heals on the next keyframe. Restarting the entire
      // source would be far worse than letting the stall watchdog handle a
      // truly broken stream (position stuck for 5 s → watchdog calls play()).
      final isVideoDecodeError = error.toString().toLowerCase().contains(
        'decoding video',
      );
      if (isVideoDecodeError &&
          !state.isLive &&
          _hasConfirmedPlaybackFrame &&
          _player.state.position > Duration.zero) {
        if (kDebugMode) {
          debugPrint(
            '[Player] Ignoring transient video decode error during confirmed playback.',
          );
        }
        return;
      }

      // HE-AAC (AAC+SBR) streams trigger "Error decoding audio" because
      // FFmpeg initializes the codec in AAC-LC mode and then encounters SBR
      // extension data. Rather than switching the whole source, try each
      // audio rendition in turn — the next track is typically stereo AAC-LC
      // and decodes correctly (matches what the user gets by manually
      // switching the audio track in the UI).
      //
      // mpv resets state.track.audio to the "no" sentinel before the error
      // event fires, so we use _lastKnownAudioTrackId (recorded via
      // stream.track above) to identify which track actually failed.
      if (isAudioDecodeError && !state.isLive) {
        // Debounce: ignore duplicate errors within 500 ms.
        final now = DateTime.now();
        if (_audioFailoverLastTime != null &&
            now.difference(_audioFailoverLastTime!) <
                const Duration(milliseconds: 500)) {
          return;
        }
        _audioFailoverLastTime = now;

        if (_lastKnownAudioTrackId != null) {
          _failedAudioTrackIds.add(_lastKnownAudioTrackId!);
        } else {
          // stream.track hasn't fired yet (error came in before the first
          // track-change event). Mark the first real track as failed so we
          // don't loop back to it.
          final firstReal = _player.state.tracks.audio.firstWhereOrNull(
            (t) => t.id != 'no' && t.id != 'auto',
          );
          if (firstReal != null) {
            _failedAudioTrackIds.add(firstReal.id.toString());
          }
        }
        final nextTrack = _player.state.tracks.audio.firstWhereOrNull(
          (t) =>
              t.id != 'no' &&
              t.id != 'auto' &&
              !_failedAudioTrackIds.contains(t.id.toString()),
        );
        if (nextTrack != null) {
          if (kDebugMode) {
            debugPrint(
              '[Player] Audio decode error on track $_lastKnownAudioTrackId'
              ' — trying next: ${nextTrack.id} (${nextTrack.language})',
            );
          }
          _lastKnownAudioTrackId = nextTrack.id.toString();
          _player.setAudioTrack(nextTrack).catchError((_) {});
          return;
        }
        // All audio tracks exhausted. Disable audio rather than restarting
        // the entire source — video was playing correctly and a restart would
        // lose the playback position and show a spinner for no benefit.
        if (kDebugMode) {
          debugPrint(
            '[Player] All audio tracks failed — disabling audio to preserve video playback.',
          );
        }
        final noTrack = _player.state.tracks.audio.firstWhereOrNull(
          (t) => t.id == 'no',
        );
        if (noTrack != null) {
          _player.setAudioTrack(noTrack).catchError((_) {});
        }
        return;
      }

      if (!_hasConfirmedPlaybackFrame ||
          _player.state.position == Duration.zero) {
        // RC1: a source that fails to produce its first frame with a
        // decode/codec/hardware error is usually the hardware decoder
        // choking (FireTV MediaCodec rejecting a profile the phone
        // accepts). Before burning through every source, flip to software
        // decoding once and retry the SAME source. If it still fails,
        // _forceSoftwareDecode is already set so we fall through to the
        // next source.
        final errLower = error.toString().toLowerCase();
        final looksLikeDecodeFailure =
            errLower.contains('decod') ||
            errLower.contains('codec') ||
            errLower.contains('hwdec') ||
            errLower.contains('hardware') ||
            errLower.contains('mediacodec') ||
            errLower.contains('vo ') ||
            errLower.contains('video output');
        if (looksLikeDecodeFailure &&
            !_forceSoftwareDecode &&
            state.currentStream != null) {
          _forceSoftwareDecode = true;
          if (kDebugMode) {
            debugPrint(
              '[Player] Decode/HW error before first frame — retrying '
              'current source with software decoding.',
            );
          }
          unawaited(changeStream(state.currentStream!, resetPosition: true));
          return;
        }

        // Error before playback confirmed — try next source.
        _markSourceAttempt(
          state.currentStreamIndex,
          SourceAttemptStatus.failed,
          isCurrent: false,
        );
        if (_manualSelectionPending) {
          _manualSelectionPending = false;
          revertToPreviousStream("Selected source failed. Reverting...");
        } else {
          retryNextStream(sourceSessionId: state.sourceSessionId);
        }
      } else {
        // Error during active playback.
        if (_isAppBackgrounded) {
          if (kDebugMode) {
            debugPrint('[Player] Ignoring transient error while backgrounded.');
          }
          return;
        }
        if (state.isLive && state.currentStream != null) {
          if (_isRecoveringFromStall) return; // watchdog already reconnecting
          if (kDebugMode) {
            debugPrint("Live stream error. Triggering reconnect...");
          }
          _enterRuntimePhase(
            kind: PlaybackUiPhaseKind.reconnectingLive,
            detail: "Reconnecting to live stream...",
          );
          _beginStallRecovery(
            perform: changeStream(state.currentStream!, resetPosition: true),
          );
          return;
        }
        // During active playback, seamlessly reconnect/refresh the same source
        // up to 3 times before considering failover to a different source.
        if (_isReconnectingCurrentStream) return;
        if (_midPlaybackRetryCount < 3 && state.currentStream != null) {
          _midPlaybackRetryCount++;
          if (kDebugMode) {
            debugPrint(
              '[Player] Mid-playback error — attempting seamless reconnect ($_midPlaybackRetryCount/3).',
            );
          }
          unawaited(_triggerMidPlaybackReconnect());
          return;
        }

        _markSourceAttempt(
          state.currentStreamIndex,
          SourceAttemptStatus.failed,
          isCurrent: false,
        );
        _revertMessage =
            "Current source stopped unexpectedly. Trying next available source...";
        retryNextStream(sourceSessionId: state.sourceSessionId);
      }
    });
  }

  void _setupConnectivityListener() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isConnected = results.any(
        (r) => r != ConnectivityResult.none,
      );
      if (isConnected) {
        // If we were stalled / reconnecting during active playback, kick reconnection immediately
        if (_isReconnectingCurrentStream ||
            (_hasConfirmedPlaybackFrame &&
                state.uiPhase.kind == PlaybackUiPhaseKind.bufferingRuntime)) {
          if (kDebugMode) {
            debugPrint(
              '[Player] Network restored — triggering immediate stream reconnect.',
            );
          }
          _midPlaybackRetryTimer?.cancel();
          _triggerMidPlaybackReconnect();
        }
      }
    });
  }

  Future<void> _triggerMidPlaybackReconnect() async {
    if (state.currentStream == null || _isDisposed) return;
    if (_isReconnectingCurrentStream) return;
    _isReconnectingCurrentStream = true;

    // Check connectivity first
    bool hasConnection = true;
    try {
      final results = await Connectivity().checkConnectivity();
      hasConnection = results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      hasConnection = true;
    }

    if (!hasConnection) {
      if (kDebugMode) {
        debugPrint(
          '[Player] Device is offline — waiting for network reconnection.',
        );
      }
      _isReconnectingCurrentStream = false;
      _enterRuntimePhase(
        kind: PlaybackUiPhaseKind.bufferingRuntime,
        detail: "Waiting for network connection...",
      );
      return;
    }

    final oldPos = state.useExoPlayer
        ? Duration(milliseconds: _videoViewController?.position.value ?? 0)
        : _player.state.position;

    _enterRuntimePhase(
      kind: PlaybackUiPhaseKind.bufferingRuntime,
      detail: state.isLive
          ? "Reconnecting to live stream..."
          : "Reconnecting stream...",
    );

    try {
      final stream = state.currentStream!;
      final playUrl = await _resolveStreamUrl(stream);
      if (playUrl == null) throw Exception("Failed to re-resolve stream URL");
      if (_isDisposed) return;

      final headers = _buildPlaybackHeaders(stream);
      final resolvedIsLive = _detectResolvedLiveState(playUrl);
      final useVideoView = _canUseVideoViewForStream(
        playUrl,
        stream,
        isLive: resolvedIsLive,
      );

      await _applyPlaybackProperties(
        headers,
        stream,
        useVideoView: useVideoView,
      );
      if (_isDisposed) return;

      await _openResolvedStream(
        playUrl,
        stream,
        headers,
        useVideoView: useVideoView,
      );
      if (_isDisposed) return;

      if (oldPos > Duration.zero) {
        await _safeSeekTo(oldPos.inMilliseconds);
      }
      if (kDebugMode) {
        debugPrint(
          '[Player] Reconnect successful at position ${oldPos.inSeconds}s.',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[Player] Reconnect attempt $_midPlaybackRetryCount failed: $e',
        );
      }
      if (_midPlaybackRetryCount < 3) {
        final delaySeconds = 1 << _midPlaybackRetryCount; // 2s, 4s, 8s
        _midPlaybackRetryTimer?.cancel();
        _midPlaybackRetryTimer = Timer(Duration(seconds: delaySeconds), () {
          if (!_isDisposed && state.currentStream != null) {
            _midPlaybackRetryCount++;
            unawaited(_triggerMidPlaybackReconnect());
          }
        });
      } else {
        _isReconnectingCurrentStream = false;
        _markSourceAttempt(
          state.currentStreamIndex,
          SourceAttemptStatus.failed,
          isCurrent: false,
        );
        _revertMessage =
            "Current source stopped unexpectedly. Trying next available source...";
        unawaited(retryNextStream(sourceSessionId: state.sourceSessionId));
      }
      return;
    }
    _isReconnectingCurrentStream = false;
  }

  void skipLoadingOverlay() {
    state = state.copyWith(userSkippedOverlay: true);
    _setUiPhase(
      _composeUiPhase(kind: state.uiPhase.kind, fullscreenBlocking: false),
    );
  }

  void _setupEventDrivenProgressSaving() {
    _playingSub?.cancel();
    _playingSub = _player.stream.playing.listen((isPlaying) {
      if (!isPlaying) {
        saveProgress();
        _torrentPollTimer?.cancel();
        _torrentPollTimer = null;
        // Bug 2: clear any in-flight buffering overlay when the user
        // pauses. Without this, "seek → buffering starts → user pauses
        // before buffer fills" leaves the spinner stuck on top of a
        // paused video forever. The spinner is meaningful for an active
        // playback stall, not for an intentional pause — the next seek/
        // play will arm it again if needed.
        _stallTimer?.cancel();
        _bufferingHideTimer?.cancel();
        if (state.uiPhase.kind == PlaybackUiPhaseKind.bufferingRuntime) {
          _setIdlePhase();
        }
      } else {
        // Do NOT call _confirmPlaybackStarted() here — media_kit fires
        // playing=true as soon as open() is called, before any frames arrive.
        // Confirmation happens in _positionSub (position > 0) and
        // _setupVideoParamsListener (video dimensions received).
        if (state.torrentStatus != null && _torrentPollTimer == null) {
          startTorrentPolling();
        }
      }
    });

    _completedSub?.cancel();
    _completedSub = _player.stream.completed.listen((isCompleted) {
      if (isCompleted) {
        final isLive =
            _item.contentType == MultimediaContentType.livestream ||
            _isLiveStream(_videoUrl);
        if (isLive && state.currentStream != null) {
          if (kDebugMode) {
            debugPrint("Live stream reached EOF. Forcing auto-reconnect...");
          }
          _enterRuntimePhase(
            kind: PlaybackUiPhaseKind.reconnectingLive,
            detail: "Reconnecting to live stream...",
          );
          unawaited(changeStream(state.currentStream!, resetPosition: true));
        }
      }
    });

    _positionSub?.cancel();
    _positionSub = _player.stream.position.listen((pos) {
      if (pos.inMilliseconds > 0 && !_hasConfirmedPlaybackFrame) {
        _confirmPlaybackStarted();
      }

      final now = DateTime.now();

      // --- Stall Watchdog Logic ---
      if (_player.state.playing && !state.isBuffering && !state.isLoading) {
        if (_lastPosition != null && _lastPosition == pos) {
          final stallDuration = _lastPositionUpdateTime != null
              ? now.difference(_lastPositionUpdateTime!)
              : Duration.zero;

          if (stallDuration.inSeconds >= 5 && !_isRecoveringFromStall) {
            if (kDebugMode) {
              debugPrint(
                "Watchdog: Silent stall detected (5s). Kicking engine...",
              );
            }

            // Recovery: reconnect live streams from scratch; kick VOD.
            // For live we hand changeStream to the recovery helper so the
            // flag clears the instant the reconnect resolves. For VOD,
            // _player.play() is sync — fall back to the time-based backstop.
            if (state.isLive && state.currentStream != null) {
              _beginStallRecovery(
                perform: changeStream(
                  state.currentStream!,
                  resetPosition: true,
                ),
              );
            } else {
              _beginStallRecovery();
              _player.play();
            }
          }
        } else {
          _lastPosition = pos;
          _lastPositionUpdateTime = now;
          if (_midPlaybackRetryCount > 0) {
            _midPlaybackRetryCount = 0;
            _staleUrlReResolveAttempted = false;
            _isReconnectingCurrentStream = false;
            _midPlaybackRetryTimer?.cancel();
          }
        }
      } else {
        _lastPosition = pos;
        _lastPositionUpdateTime = now;
      }
      // -----------------------------

      final duration = _player.state.duration;
      if (duration == Duration.zero) return;

      final currentPct = pos.inMilliseconds / duration.inMilliseconds;
      final lastPct =
          _lastSavedPosition.inMilliseconds / duration.inMilliseconds;

      if ((currentPct - lastPct).abs() >= _saveThresholdPercent) {
        saveProgress();
        _lastSavedPosition = pos;
      }

      // Next Episode Detection (Series only, trigger 15s before end)
      if (!_suppressNextEpisodeDetection &&
          (_item.contentType == MultimediaContentType.series ||
              _item.contentType == MultimediaContentType.anime)) {
        final durationMs = duration.inMilliseconds;
        final posMs = pos.inMilliseconds;
        final remainingSecs = (durationMs - posMs) / 1000;

        // Show next episode overlay if within last 15 seconds or video ended.
        // It persists until the user dismisses it or loads a new episode.
        if (remainingSecs <= 15.0) {
          final next = getNextEpisode();
          if (next != null) {
            if (!_userDismissedOverlay && !state.showNextEpisodeOverlay) {
              state = state.copyWith(
                showNextEpisodeOverlay: true,
                nextEpisodeTitle: next.name,
                nextEpisodePosterUrl: next.posterUrl,
                nextEpisodeRating: next.rating,
                nextEpisodeNumber: next.episode,
                nextEpisodeSeason: next.season,
                nextEpisodeRuntime: next.runtime,
                nextEpisodeDescription: next.description,
              );
            }
            // Ensure it persists if video completes and resets position
            _isNextEpisodeOverlayForced = true;
          }
          return;
        }

        if (remainingSecs > 15.0) {
          if (state.showNextEpisodeOverlay && !_isNextEpisodeOverlayForced) {
            state = state.copyWith(showNextEpisodeOverlay: false);
          }
        }
      }
    });
  }

  Future<void> _initStream({
    PlaybackUiPhaseKind requestedPhaseKind =
        PlaybackUiPhaseKind.fetchingSources,
    bool forceNewSourceSession = true,
  }) async {
    // Any stream-level transition (new episode, source retry, manual
    // quality switch) should re-arm the next-episode overlay. Without
    // this, a dismiss near end-of-episode followed by a source retry
    // (which preserves position) leaves the overlay suppressed for the
    // remainder of that episode — the user has no way to advance until
    // playback naturally completes (H-PLAYER-7). The position listener
    // self-heals once `remainingSecs > 15`, but inside the narrow
    // last-15s window during a retry it would otherwise stay stuck.

    final sourceSessionId = forceNewSourceSession
        ? _beginSourceSession(resetAttempts: true)
        : state.sourceSessionId;

    String detail = "Fetching sources...";
    switch (requestedPhaseKind) {
      case PlaybackUiPhaseKind.loadingNextEpisode:
        // Enhancement: Use startup (blocking) phase so the screen goes dark
        // instead of showing controls over the previous episode's frame.
        _enterStartupPhase(
          kind: PlaybackUiPhaseKind.loadingNextEpisode,
          detail: "Loading next episode...",
        );
        break;
      case PlaybackUiPhaseKind.switchingSource:
        _enterRuntimePhase(
          kind: PlaybackUiPhaseKind.switchingSource,
          detail: "Switching source...",
        );
        break;
      case PlaybackUiPhaseKind.reconnectingLive:
        _enterRuntimePhase(
          kind: PlaybackUiPhaseKind.reconnectingLive,
          detail: "Reconnecting to live stream...",
        );
        break;
      default:
        if (_item.provider == 'Local' || AppUtils.isLocalFile(_videoUrl)) {
          detail = "Opening local file...";
        } else if (_item.provider == 'Torrent' ||
            _videoUrl.startsWith("magnet:") ||
            _videoUrl.endsWith(".torrent")) {
          detail = "Preparing torrent stream...";
        }
        _enterStartupPhase(kind: requestedPhaseKind, detail: detail);
    }

    state = state.copyWith(currentAttemptIndex: null);

    if (await _handleSpecialProviders()) return;

    final activeProvider = _resolveProvider();
    if (activeProvider == null) {
      state = state.copyWith(errorMessage: "No provider selected.");
      return;
    }

    try {
      if (_videoUrl.isNotEmpty) {
        state = state.copyWith(streamSubtitle: "Fetching sources...");
        if (await _handleFallbackTorrent()) return;

        final rawStreams = await activeProvider.loadStreams(_videoUrl);
        if (!_isCurrentSourceSession(sourceSessionId)) return;
        if (rawStreams.isNotEmpty) {
          // Filter then sort streams by quality preference based on network type.
          // Wi-Fi → wifiQuality, mobile/other → mobileQuality.
          // If the filter leaves nothing, falls back to all streams + sets
          // qualityFilteredFallback so the Sources tab can show a banner.
          final settings = ref.read(playerSettingsProvider).asData?.value;
          bool didFallback = false;
          final streams = settings == null
              ? rawStreams
              : await _processStreams(
                  rawStreams,
                  settings,
                  onFallback: (v) => didFallback = v,
                );
          if (!_isCurrentSourceSession(sourceSessionId)) return;

          final initialIndex = _findSavedStreamIndex(streams);
          state = state.copyWith(
            streams: streams,
            currentStreamIndex: initialIndex,
            qualityFilteredFallback: didFallback,
          );
          final checkCount = streams.length > 3 ? 3 : streams.length;

          // Issue 1: Mark ALL batch candidates as `trying` before parallel check,
          // so the UI shows the correct status for each source being checked.
          _setSourceAttemptsFromStreams(streams);
          if (checkCount > 1) {
            final batchIndices = {
              for (int i = 0; i < checkCount; i++)
                (initialIndex + i) % streams.length,
            };
            final updated = state.sourceAttempts
                .map(
                  (e) => batchIndices.contains(e.index)
                      ? e.copyWith(
                          status: SourceAttemptStatus.trying,
                          isCurrent: e.index == initialIndex,
                        )
                      : e,
                )
                .toList();
            state = state.copyWith(
              sourceAttempts: updated,
              currentAttemptIndex: initialIndex,
            );
          } else {
            _markSourceAttempt(initialIndex, SourceAttemptStatus.trying);
          }

          // Issue 2: No attemptIndex/attemptTotal during batch check —
          // "Source X of N" is meaningless when checking 3 at once.
          _enterStartupPhase(
            kind: PlaybackUiPhaseKind.checkingSources,
            detail: checkCount > 1
                ? "Checking $checkCount sources..."
                : "Preparing selected source...",
          );

          // PERFORMANCE: Parallel check the first few streams (health check)
          // This avoids waiting for a timeout on a dead stream if a working one is available
          final workingIndex = await _findFirstWorkingStream(
            streams,
            startIndex: initialIndex,
            limit: checkCount,
            sourceSessionId: sourceSessionId,
          );
          if (!_isCurrentSourceSession(sourceSessionId)) return;

          await loadStreamAtIndex(
            workingIndex,
            sourceSessionId: sourceSessionId,
          );
          return;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error loading streams: $e");
    }

    if (!_isCurrentSourceSession(sourceSessionId)) return;
    state = state.copyWith(errorMessage: "No streams found.");
  }

  Future<bool> _handleSpecialProviders() async {
    if (_item.provider == 'Remote' ||
        _item.provider == 'Local' ||
        _item.provider == 'Torrent' ||
        AppUtils.isLocalFile(_videoUrl)) {
      final isTorrent =
          _item.provider == 'Torrent' ||
          _videoUrl.startsWith("magnet:") ||
          _videoUrl.endsWith(".torrent");

      final stream = StreamResult(
        url: _videoUrl,
        source: isTorrent ? "Torrent" : "Video",
        headers: {},
      );

      state = state.copyWith(streams: [stream], currentStreamIndex: 0);
      _setSourceAttemptsFromStreams([stream], activeIndex: 0);
      await loadStreamAtIndex(0, sourceSessionId: state.sourceSessionId);
      return true;
    }
    return false;
  }

  Future<bool> _handleFallbackTorrent() async {
    if (_videoUrl.startsWith("magnet:") || _videoUrl.endsWith(".torrent")) {
      final stream = StreamResult(
        url: _videoUrl,
        source: "Torrent",
        headers: {},
      );
      state = state.copyWith(streams: [stream], currentStreamIndex: 0);
      _setSourceAttemptsFromStreams([stream], activeIndex: 0);
      await loadStreamAtIndex(0, sourceSessionId: state.sourceSessionId);
      return true;
    }
    return false;
  }

  SkyStreamProvider? _resolveProvider() {
    final activeState = ref.read(activeProviderProvider);
    final manager = ref.read(extensionManagerProvider.notifier);

    if (_item.provider != null) {
      try {
        final val = _item.provider!;
        return manager.getAllProviders().firstWhere(
          (p) => p.packageName == val || p.name == val,
        );
      } catch (e) {
        if (kDebugMode) debugPrint('PlayerController._resolveProvider: $e');
      }
    }
    return activeState;
  }

  int _findSavedStreamIndex(List<StreamResult> streams) {
    try {
      final historyRepo = ref.read(historyRepositoryProvider);
      final isSeries =
          (_item.contentType == MultimediaContentType.series ||
          _item.contentType == MultimediaContentType.anime);

      String? lastUrl;
      if (isSeries) {
        lastUrl = historyRepo.getLastStreamUrl(_item.url);
      }

      if (lastUrl == null) {
        final historyList = ref.read(watchHistoryProvider);
        final previousState = historyList.firstWhere(
          (h) => h.item.url == _item.url,
          orElse: () => HistoryItem(
            item: _item,
            position: 0,
            duration: 0,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        lastUrl = previousState.lastStreamUrl;
      }

      if (lastUrl != null) {
        final foundIndex = streams.indexWhere((s) => s.url == lastUrl);
        if (foundIndex != -1) return foundIndex;
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error checking saved stream quality: $e");
    }
    return 0;
  }

  Episode? _resolveCurrentEpisode() {
    if (_episode != null) return _episode;
    if (!isSeries) return null;
    return _item.episodes?.firstWhereOrNull((e) => e.url == _videoUrl);
  }

  /// Returns the effective list of episodes for playback and navigation.
  /// If the series has both subbed and dubbed episodes (mixed), it filters by
  /// the current episode's dub status. If unclassified or not mixed, all
  /// episodes are returned for linear playback.
  List<Episode>? getEffectiveEpisodes([Episode? currentEp]) {
    final episodes = _item.episodes;
    if (episodes == null || episodes.isEmpty) return null;
    if (!isSeries) return episodes;

    final hasSub = episodes.any((e) => e.dubStatus == DubStatus.subbed);
    final hasDub = episodes.any((e) => e.dubStatus == DubStatus.dubbed);
    final isMixed = hasSub && hasDub;

    final ep = currentEp ?? _episode ?? _resolveCurrentEpisode();
    if (isMixed && ep != null && ep.dubStatus != DubStatus.none) {
      final filtered =
          episodes.where((e) => e.dubStatus == ep.dubStatus).toList();
      if (filtered.isNotEmpty) return filtered;
    }
    return episodes;
  }

  /// Resolves the next episode for the current media item.
  Episode? getNextEpisode() {
    if (!isSeries) return null;
    final currentEp = _episode ?? _resolveCurrentEpisode();
    final episodes = getEffectiveEpisodes(currentEp);
    if (episodes == null || episodes.isEmpty) return null;

    int currentIndex = -1;
    if (currentEp != null) {
      currentIndex = episodes.indexWhere((e) => e.url == currentEp.url);
      if (currentIndex == -1 &&
          currentEp.season > 0 &&
          currentEp.episode > 0) {
        currentIndex = episodes.indexWhere(
          (e) =>
              e.season == currentEp.season && e.episode == currentEp.episode,
        );
      }
    }
    if (currentIndex == -1) {
      currentIndex = episodes.indexWhere((e) => e.url == _videoUrl);
    }

    if (currentIndex != -1 && currentIndex < episodes.length - 1) {
      return episodes[currentIndex + 1];
    }
    return null;
  }

  List<SubtitleFile> _effectiveExternalSubtitles(
    List<SubtitleFile>? streamSubtitles,
  ) {
    final merged = <SubtitleFile>[];
    final seenUrls = <String>{};

    for (final sub in [...?streamSubtitles, ..._userAddedExternalSubtitles]) {
      if (seenUrls.add(sub.url)) {
        merged.add(sub);
      }
    }

    return merged;
  }

  List<SubtitleTrackConfig> _buildSubtitleConfigs(
    List<SubtitleFile> subtitles,
  ) {
    return subtitles
        .map(
          (subtitle) => SubtitleTrackConfig(
            uri: subtitle.url,
            mimeType: subtitle.url.toLowerCase().endsWith('.vtt')
                ? 'text/vtt'
                : 'application/x-subrip',
            language: subtitle.lang ?? 'und',
          ),
        )
        .toList();
  }

  String _languageName(String code) {
    return code.trim();
  }

  String _formatTrackLabel({
    String? language,
    String? title,
    String? fallbackId,
  }) {
    final List<String> parts = [];
    if (language != null && language.trim().isNotEmpty) {
      parts.add(language.trim());
    }
    if (title != null && title.trim().isNotEmpty) {
      parts.add(title.trim());
    }

    if (parts.isNotEmpty) {
      return parts.join(' - ');
    }

    return fallbackId != null && fallbackId.trim().isNotEmpty
        ? (int.tryParse(fallbackId) != null
              ? 'Audio Track $fallbackId'
              : fallbackId)
        : 'Unknown Track';
  }

  String? _formatTechnicalSubtitle(dynamic track) {
    try {
      final List<String> techParts = [];

      // Extract raw technical tags from the track object (media_kit specific)
      // We use dynamic access as these fields exist in the runtime object but
      // may not be present in early/stub versions of the class.
      final String? codec = track.codec?.toString();
      final String? channels = track.channels?.toString();
      final dynamic samplerate = track.samplerate;

      if (codec != null && codec.isNotEmpty && codec != 'null') {
        techParts.add(codec.toUpperCase());
      }

      if (channels != null &&
          channels.isNotEmpty &&
          channels != 'null' &&
          channels != 'unknown') {
        techParts.add(channels);
      }

      if (samplerate != null && samplerate is num && samplerate > 0) {
        techParts.add(
          '${(samplerate / 1000).toStringAsFixed(1).replaceAll('.0', '')}kHz',
        );
      }

      if (techParts.isNotEmpty) {
        return techParts.join(' · ');
      }
    } catch (_) {
      // Fallback if specific fields are inaccessible
    }
    return null;
  }

  Future<void> _openResolvedStream(
    String playUrl,
    StreamResult stream,
    Map<String, String> headers, {
    required bool useVideoView,
  }) async {
    if (useVideoView) {
      // Pause media_kit so it stops consuming bandwidth while video_view plays.
      // (media_kit.open() will replace it if the user switches back.)
      if (!state.useExoPlayer) {
        await _player.pause();
      }

      String finalUrl = playUrl;
      if (finalUrl.contains('play.php') || finalUrl.contains('index.php')) {
        finalUrl = LocalProxyService.instance.getProxyUrl(
          finalUrl,
          headers: headers,
          forceM3u8Extension: true,
        );
        if (kDebugMode) {
          debugPrint("[PLAYER] Proxied non-standard HLS: $finalUrl");
        }
      }

      if (Platform.isWindows) {
        final scheme = Uri.tryParse(finalUrl)?.scheme ?? '';
        final lowerUrl = finalUrl.toLowerCase();
        final hasAdaptiveExtension =
            lowerUrl.contains('.m3u8') ||
            lowerUrl.contains('.mpd') ||
            lowerUrl.contains('.ism/manifest');
        if (hasAdaptiveExtension &&
            scheme != 'http' &&
            scheme != 'https' &&
            scheme != 'file') {
          throw Exception(
            'Unsupported URL scheme "$scheme" for native adaptive player on Windows',
          );
        }
      }

      final subs = state.externalSubtitles;
      if (subs.isNotEmpty && _videoViewSupportsMergedExternalSubtitles) {
        _videoViewController!.openWithSubtitles(
          finalUrl,
          headers: headers,
          subtitles: _buildSubtitleConfigs(subs),
          drmKey: stream.drmKey,
          drmKid: stream.drmKid,
        );
      } else {
        _videoViewController!.open(
          finalUrl,
          headers: headers,
          drmKey: stream.drmKey,
          drmKid: stream.drmKid,
        );
      }
      state = state.copyWith(useExoPlayer: true, isSeekable: false);
      _scheduleAutoSubtitleSelection();
      return;
    }

    // Close video_view before handing off to media_kit so ExoPlayer/AVPlayer
    // stops buffering and releases its surface while media_kit plays.
    if (state.useExoPlayer) {
      _videoViewController?.close();
    }

    _failedAudioTrackIds.clear();
    _lastKnownAudioTrackId = null;
    _audioFailoverLastTime = null;

    // FFmpeg's HLS demuxer opens audio rendition playlists as separate
    // AVFormatContext instances that do NOT inherit parent HTTP headers on any
    // platform. For HLS with cookie-auth audio renditions, we pre-process the
    // master playlist to keep only the DEFAULT audio track and proxy all URLs
    // through localhost (so the proxy injects cookies for every sub-request).
    // Keeping 1 audio track instead of 11 reduces probe time from ~27s to ~3s.
    String mediaKitUrl = playUrl;
    final lowerPlayUrl = playUrl.toLowerCase();
    final isHlsUrl =
        lowerPlayUrl.contains('.m3u8') ||
        (lowerPlayUrl.contains('/hls/') && !lowerPlayUrl.startsWith('file'));
    final lowerHdrs = headers.map((k, v) => MapEntry(k.toLowerCase(), v));
    if (isHlsUrl && lowerHdrs.containsKey('cookie')) {
      final cookieNames = lowerHdrs['cookie']!
          .split(';')
          .map((c) => c.trim().split('=').first.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final proxyOptions = ProxyOptions(
        mirrorHosts: const [],
        keepCookies: cookieNames,
      );
      final simplified = await _buildSimplifiedMasterPlaylist(
        playUrl,
        headers,
        proxyOptions,
      );
      if (simplified != null) {
        mediaKitUrl = LocalProxyService.instance.serveM3u8(simplified);
        if (kDebugMode) {
          debugPrint(
            '[PLAYER] Serving simplified HLS master (1 audio track): $mediaKitUrl',
          );
        }
      } else {
        // Fallback: full proxy if pre-fetch failed (e.g. network error)
        mediaKitUrl = LocalProxyService.instance.getProxyUrl(
          playUrl,
          headers: headers,
          options: proxyOptions,
        );
        if (kDebugMode) {
          debugPrint(
            '[PLAYER] Proxying HLS through localhost (master pre-fetch failed): $mediaKitUrl',
          );
        }
      }
    }

    await _player.open(Media(mediaKitUrl, httpHeaders: headers));
    state = state.copyWith(useExoPlayer: false, isSeekable: true);
    _scheduleAutoSubtitleSelection();
  }

  Future<void> seekTo(Duration position, {bool fast = false}) async {
    if (!state.canSeek) return;

    _isNextEpisodeOverlayForced = false;

    if (!_isApplyingPendingResumeSeek) {
      state = state.copyWith(
        resumePromptPosition: null,
        resumePromptPercentage: null,
      );
    }

    final clamped = position < Duration.zero ? Duration.zero : position;

    if (state.useExoPlayer && _videoViewController != null) {
      _videoViewController!.seekTo(clamped.inMilliseconds, fast: fast);
      return;
    }

    await _player.seek(clamped);
  }

  Future<void> seekRelative(Duration amount, {bool fast = false}) async {
    if (!state.canSeek) return;

    final currentPosition = state.useExoPlayer
        ? Duration(milliseconds: _videoViewController?.position.value ?? 0)
        : _player.state.position;

    await seekTo(currentPosition + amount, fast: fast);
  }

  Future<void> play() async {
    if (state.useExoPlayer && _videoViewController != null) {
      _videoViewController!.play();
    } else {
      await _player.play();
    }

    try {
      final int pos;
      final int dur;
      if (state.useExoPlayer && _videoViewController != null) {
        pos = _videoViewController!.position.value;
        dur = _videoViewController!.mediaInfo.value?.duration ?? 0;
      } else {
        pos = _player.state.position.inMilliseconds;
        dur = _player.state.duration.inMilliseconds;
      }
      final double progressDecimal = dur > 0 ? pos / dur : 0.0;
      if (_hasScrobbleStarted && !_hasMarkedWatched) {
        unawaited(
          ref
              .read(syncManagerProvider)
              .scrobbleStart(_item, _resolveCurrentEpisode(), progressDecimal)
              .catchError(
                (Object e) =>
                    talker.error('scrobbleStart (play resume) failed', e),
              ),
        );
      }
    } catch (_) {}
  }

  Future<void> pause() async {
    if (state.useExoPlayer && _videoViewController != null) {
      _videoViewController!.pause();
    } else {
      await _player.pause();
    }

    try {
      final int pos;
      final int dur;
      if (state.useExoPlayer && _videoViewController != null) {
        pos = _videoViewController!.position.value;
        dur = _videoViewController!.mediaInfo.value?.duration ?? 0;
      } else {
        pos = _player.state.position.inMilliseconds;
        dur = _player.state.duration.inMilliseconds;
      }
      final double progressDecimal = dur > 0 ? pos / dur : 0.0;
      if (_hasScrobbleStarted && !_hasMarkedWatched) {
        unawaited(
          ref
              .read(syncManagerProvider)
              .scrobblePause(_item, _resolveCurrentEpisode(), progressDecimal)
              .catchError(
                (Object e) => talker.error('scrobblePause failed', e),
              ),
        );
      }
    } catch (_) {}
  }

  bool get isPlaying {
    if (state.useExoPlayer && _videoViewController != null) {
      return _videoViewController!.playbackState.value ==
          VideoControllerPlaybackState.playing;
    }

    return _player.state.playing;
  }

  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  PlayerTrackSelectionSnapshot getTrackSelectionSnapshot() {
    if (state.useExoPlayer && _videoViewController != null) {
      final controller = _videoViewController!;
      final info = controller.mediaInfo.value;
      if (info == null) {
        return const PlayerTrackSelectionSnapshot();
      }

      final overrideAudio = controller.overrideAudio.value;
      final overrideSubtitle = controller.overrideSubtitle.value;
      final showSubtitle = controller.showSubtitle.value;

      final audioTracks = info.audioTracks.entries
          .map(
            (entry) => PlayerTrackOption(
              id: entry.key,
              label: _formatTrackLabel(
                language: entry.value.language,
                title: entry.value.title,
                fallbackId: entry.key,
              ),
              subtitle: entry.value.format,
              selected:
                  overrideAudio == entry.key ||
                  (overrideAudio == null && info.audioTracks.length == 1),
            ),
          )
          .toList();

      final subtitleTracks = info.subtitleTracks.entries
          .map(
            (entry) => PlayerTrackOption(
              id: entry.key,
              label: _formatTrackLabel(
                language: entry.value.language,
                title: entry.value.title,
                fallbackId: entry.key,
              ),
              subtitle: entry.value.format,
              selected: showSubtitle && overrideSubtitle == entry.key,
            ),
          )
          .toList();

      return PlayerTrackSelectionSnapshot(
        audioTracks: audioTracks,
        subtitleTracks: subtitleTracks,
        subtitlesOffSelected: !showSubtitle,
      );
    }

    final audioTracks = _player.state.tracks.audio
        .map(
          (track) => PlayerTrackOption(
            id: track.id,
            label: _formatTrackLabel(
              language: track.language,
              title: track.title,
              fallbackId: track.id,
            ),
            subtitle: _formatTechnicalSubtitle(track),
            selected: track == _player.state.track.audio,
          ),
        )
        .toList();

    final subtitleTracks = <PlayerTrackOption>[
      ...state.externalSubtitles.map(
        (subtitle) => PlayerTrackOption(
          id: 'external:${subtitle.url}',
          label: subtitle.label,
          subtitle: subtitle.lang != null
              ? _languageName(subtitle.lang!)
              : null,
          selected:
              _player.state.track.subtitle.id == subtitle.url ||
              _player.state.track.subtitle.id == 'external:${subtitle.url}',
        ),
      ),
      ..._buildEmbeddedSubtitleOptions(),
    ];

    return PlayerTrackSelectionSnapshot(
      audioTracks: audioTracks,
      subtitleTracks: subtitleTracks,
      subtitlesOffSelected: _player.state.track.subtitle == SubtitleTrack.no(),
    );
  }

  List<PlayerTrackOption> _buildEmbeddedSubtitleOptions() {
    final tracks = _player.state.tracks.subtitle;
    final options = <PlayerTrackOption>[];
    final seenIds = <String>{};
    for (final track in tracks) {
      final language = (track.language ?? '').toString().trim().toLowerCase();
      final id = language.isNotEmpty
          ? 'embedded:$language'
          : 'embedded:${track.id}';
      if (!seenIds.add(id)) continue;
      options.add(
        PlayerTrackOption(
          id: id,
          label: _subtitleTrackLabel(track),
          selected: track == _player.state.track.subtitle,
        ),
      );
    }
    return options;
  }

  String _subtitleTrackLabel(dynamic track) {
    final title = (track.title ?? '').toString().trim();
    final language = (track.language ?? '').toString().trim();
    if (title.isNotEmpty && language.isNotEmpty) {
      return '$title (${language.toLowerCase()})';
    }
    if (title.isNotEmpty) return title;
    if (language.isNotEmpty) return language.toUpperCase();
    final id = (track.id ?? '').toString().trim();
    return id.isNotEmpty ? id : 'Unknown';
  }

  Future<void> selectAudioTrack(String id) async {
    if (state.useExoPlayer && _videoViewController != null) {
      _videoViewController!.setOverrideAudio(id);
      return;
    }

    final track = _player.state.tracks.audio.firstWhereOrNull(
      (t) => t.id == id,
    );
    if (track != null) {
      await _player.setAudioTrack(track);
    }
  }

  Future<void> selectSubtitleTrack(String? id) async {
    if (state.useExoPlayer && _videoViewController != null) {
      if (id == null) {
        _videoViewController!.setShowSubtitle(false);
        if (_videoViewController!.overrideSubtitle.value != null) {
          _videoViewController!.setOverrideSubtitle(null);
        }
        return;
      }

      _videoViewController!.setShowSubtitle(true);
      _videoViewController!.setOverrideSubtitle(id);
      return;
    }

    if (id == null) {
      await _player.setSubtitleTrack(SubtitleTrack.no());
      return;
    }

    if (id.startsWith('external:')) {
      final url = id.substring('external:'.length);
      final subtitle = state.externalSubtitles.firstWhereOrNull(
        (sub) => sub.url == url,
      );
      if (subtitle != null) {
        await _player.setSubtitleTrack(
          SubtitleTrack.uri(
            subtitle.url,
            title: subtitle.label,
            language: subtitle.lang,
          ),
        );
      }
      return;
    }

    final embeddedKey = id.startsWith('embedded:')
        ? id.substring('embedded:'.length)
        : id;
    final track = _findEmbeddedSubtitleTrack(embeddedKey);
    if (track != null) {
      await _player.setSubtitleTrack(track);
    }
  }

  SubtitleTrack? _findEmbeddedSubtitleTrack(String key) {
    final tracks = _player.state.tracks.subtitle;
    if (tracks.isEmpty) return null;
    final byId = tracks.firstWhereOrNull((t) => t.id == key);
    if (byId != null) return byId;
    final lowerKey = key.toLowerCase();
    return tracks.firstWhereOrNull((t) {
      final lang = (t.language ?? '').toLowerCase();
      final title = (t.title ?? '').toLowerCase();
      return lang == lowerKey || title == lowerKey || title.contains(lowerKey);
    });
  }

  void _scheduleAutoSubtitleSelection() {
    if (state.useExoPlayer) {
      Future.delayed(const Duration(milliseconds: 800), () {
        unawaited(_autoSelectFirstSubtitleIfNeeded());
      });
      return;
    }
    StreamSubscription<dynamic>? sub;
    sub = _player.stream.track.listen((_) {
      sub?.cancel();
      unawaited(_autoSelectFirstSubtitleIfNeeded());
    });
    Future.delayed(const Duration(milliseconds: 2000), () {
      sub?.cancel();
      unawaited(_autoSelectFirstSubtitleIfNeeded());
    });
  }

  Future<void> _autoSelectFirstSubtitleIfNeeded() async {
    final currentId = state.useExoPlayer
        ? _videoViewController?.overrideSubtitle.value
        : _player.state.track.subtitle.id;
    final hasSelection =
        currentId != null && currentId != 'no' && currentId != 'auto';
    if (hasSelection) return;

    final external = state.externalSubtitles;
    if (external.isNotEmpty) {
      await selectSubtitleTrack('external:${external.first.url}');
      return;
    }

    if (!state.useExoPlayer) {
      final embedded = _player.state.tracks.subtitle;
      if (embedded.isNotEmpty) {
        await selectSubtitleTrack(embedded.first.id);
      }
    }
  }

  Future<bool> _isStreamCandidateHealthy(StreamResult stream) async {
    if (stream.url.startsWith("magnet:") ||
        stream.url.endsWith(".torrent") ||
        stream.url.startsWith("/")) {
      return true;
    }

    final uri = Uri.parse(stream.url);
    final headers = <String, String>{...?stream.headers};

    try {
      final resp = await http
          .head(uri, headers: headers)
          .timeout(const Duration(seconds: 3));
      if (resp.statusCode < 400) return true;
    } catch (_) {
      // Fall back to a ranged GET below.
    }

    final client = http.Client();
    try {
      final request = http.Request('GET', uri);
      request.headers.addAll(headers);
      request.headers.putIfAbsent('Range', () => 'bytes=0-0');
      final resp = await client
          .send(request)
          .timeout(const Duration(seconds: 3));
      final subscription = resp.stream.listen((_) {});
      await subscription.cancel();
      return resp.statusCode < 400 || resp.statusCode == 416;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  Future<void> loadStreamAtIndex(
    int index, {
    int? sourceSessionId,
    bool manualSelection = false,
    bool allowResumePrompt = true,
  }) async {
    if (index < 0 || index >= state.streams.length) return;
    if (sourceSessionId != null && !_isCurrentSourceSession(sourceSessionId)) {
      return;
    }

    final stream = state.streams[index];
    final rawProviderName =
        _item.provider ?? ref.read(activeProviderProvider)?.name ?? "Unknown";
    final providerName = _getProviderDisplayName(rawProviderName);
    final subtitles = _effectiveExternalSubtitles(stream.subtitles);
    final attemptTotal = state.sourceAttempts.isEmpty
        ? state.streams.length
        : state.sourceAttempts.length;
    _markSourceAttempt(
      index,
      manualSelection
          ? SourceAttemptStatus.selected
          : SourceAttemptStatus.trying,
    );
    _manualSelectionPending = manualSelection;

    // Issue 3: Detect torrent streams early so the overlay shows the correct detail
    // before _resolveStreamUrl is called (which internally resolves the torrent URL).
    final isTorrentStream =
        stream.url.startsWith("magnet:") ||
        stream.url.endsWith(".torrent") ||
        (stream.url.startsWith("/") && stream.source.contains("Torrent"));

    state = state.copyWith(
      currentStreamIndex: index,
      currentStream: stream,
      streamSubtitle: "$providerName - ${stream.source}",
      externalSubtitles: subtitles,
      isLive:
          _item.contentType == MultimediaContentType.livestream ||
          _isLiveStream(stream.url),
    );

    // Issue 1: Manual source selection after playback is confirmed should not
    // block the screen — use a non-blocking runtime phase so the current frame
    // stays visible while the new source opens.
    if (manualSelection && _hasConfirmedPlaybackFrame) {
      _enterRuntimePhase(
        kind: PlaybackUiPhaseKind.switchingSource,
        detail: "Switching to ${stream.source}...",
      );
    } else {
      _enterStartupPhase(
        kind: PlaybackUiPhaseKind.openingSource,
        detail: isTorrentStream
            ? "Initializing torrent engine..."
            : "Opening ${stream.source}...",
        attemptIndex: index + 1,
        attemptTotal: attemptTotal,
      );
    }

    try {
      final playUrl = await _resolveStreamUrl(stream);
      if (playUrl == null) throw Exception("Failed to resolve stream URL");
      if (sourceSessionId != null &&
          !_isCurrentSourceSession(sourceSessionId)) {
        return;
      }

      if (playUrl.contains("index=")) {
        startTorrentPolling(playUrl);
      } else {
        stopTorrentPolling();
      }

      final resolvedIsLive = _detectResolvedLiveState(playUrl);
      final useVideoView = _canUseVideoViewForStream(
        playUrl,
        stream,
        isLive: resolvedIsLive,
      );
      if (sourceSessionId != null &&
          !_isCurrentSourceSession(sourceSessionId)) {
        return;
      }
      state = state.copyWith(
        streamSubtitle: "$providerName - ${stream.source}",
        isLive: resolvedIsLive,
        isSeekable: !useVideoView,
      );
      if (state.useExoPlayer != useVideoView && _hasConfirmedPlaybackFrame) {
        _enterRuntimePhase(
          kind: PlaybackUiPhaseKind.switchingEngine,
          detail: "Optimizing playback...",
        );
      }

      final headers = _buildPlaybackHeaders(stream);
      await _applyPlaybackProperties(
        headers,
        stream,
        useVideoView: useVideoView,
      );
      if (sourceSessionId != null &&
          !_isCurrentSourceSession(sourceSessionId)) {
        return;
      }
      await _openResolvedStream(
        playUrl,
        stream,
        headers,
        useVideoView: useVideoView,
      );
      if (sourceSessionId != null &&
          !_isCurrentSourceSession(sourceSessionId)) {
        return;
      }
      _enterStartupPhase(
        kind: PlaybackUiPhaseKind.bufferingInitial,
        detail: resolvedIsLive
            ? "Connecting to live stream..."
            : "Buffering selected source...",
        attemptIndex: index + 1,
        attemptTotal: attemptTotal,
      );

      final historyRepo = ref.read(historyRepositoryProvider);
      final isSeries =
          (_item.contentType == MultimediaContentType.series ||
          _item.contentType == MultimediaContentType.anime);

      int savedPos = 0;
      if (isSeries) {
        final ep = _resolveCurrentEpisode();
        final historyEpisodeUrl = ep?.url ?? _videoUrl;
        savedPos = historyRepo.getEpisodePosition(
          historyEpisodeUrl,
          mainUrl: _item.url,
          season: ep?.season,
          episode: ep?.episode,
        );
      } else {
        savedPos = historyRepo.getPosition(_item.url);
      }

      int localTimestamp = 0;
      final allHistory = historyRepo.getWatchHistory();
      if (isSeries) {
        final ep = _resolveCurrentEpisode();
        final match = allHistory
            .where(
              (h) =>
                  h.item.url == _item.url &&
                  h.season == ep?.season &&
                  h.episode == ep?.episode,
            )
            .firstOrNull;
        if (match != null) localTimestamp = match.timestamp;
      } else {
        final match = allHistory
            .where((h) => h.item.url == _item.url)
            .firstOrNull;
        if (match != null) localTimestamp = match.timestamp;
      }

      double? syncedPct;
      int syncedTimestamp = 0;
      try {
        final syncedProgressList = await ref.read(
          syncedProgressProvider.future,
        );
        if (syncedProgressList.isNotEmpty) {
          SyncProgressItem? match;
          if (isSeries) {
            final ep = _resolveCurrentEpisode();
            match = syncedProgressList
                .where(
                  (p) =>
                      p.type == MultimediaContentType.series &&
                      p.season == ep?.season &&
                      p.episode == ep?.episode &&
                      (p.tmdbId == _item.tmdbId?.toString() ||
                          p.imdbId == _item.imdbId ||
                          p.title.toLowerCase() == _item.title.toLowerCase()),
                )
                .firstOrNull;
          } else {
            match = syncedProgressList
                .where(
                  (p) =>
                      p.type == MultimediaContentType.movie &&
                      (p.tmdbId == _item.tmdbId?.toString() ||
                          p.imdbId == _item.imdbId ||
                          p.title.toLowerCase() == _item.title.toLowerCase()),
                )
                .firstOrNull;
          }
          if (match != null && match.progressPercentage > 0) {
            syncedPct = match.progressPercentage;
            syncedTimestamp = match.pausedAt.millisecondsSinceEpoch;
          }
        }
      } catch (e) {
        debugPrint("Failed to load synced progress: $e");
      }

      // Don't prompt for trivial sync progress. A user who watched 5 seconds
      // of a 2-hour movie on another device gets a "Synced progress: 0%"
      // dialog with no way to choose Start Over — accidental taps Resume
      // the playback back to where they barely started. 5% mirrors the
      // local saveProgress write threshold.
      final hasMeaningfulSync = syncedPct != null && syncedPct >= 5.0;

      if (savedPos > 0 && hasMeaningfulSync) {
        if (syncedTimestamp > localTimestamp) {
          if (allowResumePrompt) {
            state = state.copyWith(resumePromptPercentage: syncedPct);
          } else {
            _pendingResumeSeekPercentage = syncedPct;
            unawaited(_flushPendingResumeSeek());
          }
        } else {
          if (allowResumePrompt) {
            state = state.copyWith(resumePromptPosition: savedPos);
          } else {
            _pendingResumeSeekPosition = savedPos;
            unawaited(_flushPendingResumeSeek());
          }
        }
      } else if (savedPos > 0) {
        if (allowResumePrompt) {
          state = state.copyWith(resumePromptPosition: savedPos);
        } else {
          _pendingResumeSeekPosition = savedPos;
          unawaited(_flushPendingResumeSeek());
        }
      } else if (hasMeaningfulSync) {
        if (allowResumePrompt) {
          state = state.copyWith(resumePromptPercentage: syncedPct);
        } else {
          _pendingResumeSeekPercentage = syncedPct;
          unawaited(_flushPendingResumeSeek());
        }
      }
    } catch (e) {
      if (sourceSessionId != null &&
          !_isCurrentSourceSession(sourceSessionId)) {
        return;
      }
      if (kDebugMode) debugPrint("Stream $index failed: $e");
      _markSourceAttempt(index, SourceAttemptStatus.failed, isCurrent: false);
      if (manualSelection) {
        // Issue 2: Don't show "all sources failed" for a manual pick — revert
        // silently to the previously playing source instead.
        revertToPreviousStream(
          "Selected source is not playable. Reverting back to previous source.",
        );
        return;
      }
      unawaited(retryNextStream(sourceSessionId: sourceSessionId));
    }
  }

  /// Called when the user taps "Resume" in the resume prompt overlay.
  Future<void> confirmResume() async {
    final pos = state.resumePromptPosition;
    final pct = state.resumePromptPercentage;
    state = state.copyWith(
      resumePromptPosition: null,
      resumePromptPercentage: null,
    );
    if ((pos != null && pos > 0) || (pct != null && pct > 0)) {
      _pendingResumeSeekPosition = pos;
      _pendingResumeSeekPercentage = pct;
      await _flushPendingResumeSeek();
    }
  }

  /// Called when the user taps "Start Over" or the prompt auto-dismisses.
  void dismissResumePrompt() {
    _pendingResumeSeekPosition = null;
    _pendingResumeSeekPercentage = null;
    state = state.copyWith(
      resumePromptPosition: null,
      resumePromptPercentage: null,
    );
  }

  /// Jumps back to the live edge. For DVR streams, seeks to the end of the
  /// known duration; for pure live streams, forces a full reconnect.
  Future<void> goLive() async {
    if (!state.isLive || state.currentStream == null) return;
    final dur = state.useExoPlayer
        ? Duration(
            milliseconds: _videoViewController?.mediaInfo.value?.duration ?? 0,
          )
        : _player.state.duration;
    if (dur > Duration.zero) {
      await seekTo(dur);
    } else {
      _enterRuntimePhase(
        kind: PlaybackUiPhaseKind.reconnectingLive,
        detail: "Reconnecting to live stream...",
      );
      unawaited(changeStream(state.currentStream!, resetPosition: true));
    }
  }

  Future<void> changeStream(
    StreamResult stream, {
    bool isRevert = false,
    bool resetPosition = false,
    bool manualSelection = false,
  }) async {
    final matchingIndex = state.streams.indexWhere(
      (candidate) =>
          candidate.url == stream.url && candidate.source == stream.source,
    );
    if (!isRevert) {
      state = state.copyWith(
        previousStream: state.currentStream,
        currentStreamIndex: matchingIndex == -1
            ? state.currentStreamIndex
            : matchingIndex,
      );
    }

    // Track that this is a user-initiated switch so the error listeners can
    // revert to the previous source instead of falling through to retryNextStream.
    if (manualSelection && !isRevert) {
      _manualSelectionPending = true;
    }

    final rawPName =
        _item.provider ?? ref.read(activeProviderProvider)?.name ?? 'Unknown';
    final pName = _getProviderDisplayName(rawPName);

    // Capture current position before we switch engines/streams.
    // Read from whichever engine is currently active.
    final oldPos = state.useExoPlayer
        ? Duration(milliseconds: _videoViewController?.position.value ?? 0)
        : _player.state.position;

    _enterRuntimePhase(
      kind: PlaybackUiPhaseKind.switchingSource,
      detail: "Switching to ${stream.source}...",
    );

    try {
      final playUrl = await _resolveStreamUrl(stream);
      if (playUrl == null) throw Exception("Failed to resolve stream URL");
      final subtitles = _effectiveExternalSubtitles(stream.subtitles);

      final resolvedIsLive = _detectResolvedLiveState(playUrl);
      final useVideoView = _canUseVideoViewForStream(
        playUrl,
        stream,
        isLive: resolvedIsLive,
      );
      if (state.useExoPlayer != useVideoView && _hasConfirmedPlaybackFrame) {
        _enterRuntimePhase(
          kind: PlaybackUiPhaseKind.switchingEngine,
          detail: "Optimizing playback...",
        );
      }
      state = state.copyWith(
        currentStream: stream,
        externalSubtitles: subtitles,
        isLive: resolvedIsLive,
        isSeekable: !useVideoView,
        streamSubtitle: "$pName - ${stream.source}",
      );

      if (playUrl.contains("index=")) {
        startTorrentPolling(playUrl);
      } else {
        stopTorrentPolling();
      }

      final headers = _buildPlaybackHeaders(stream);
      await _applyPlaybackProperties(
        headers,
        stream,
        useVideoView: useVideoView,
      );
      await _openResolvedStream(
        playUrl,
        stream,
        headers,
        useVideoView: useVideoView,
      );

      if (oldPos > Duration.zero && !resetPosition) {
        await _safeSeekTo(oldPos.inMilliseconds);
      } else if (resetPosition) {
        await seekTo(Duration.zero, fast: true);
      }
    } catch (e) {
      _manualSelectionPending = false;
      if (kDebugMode) debugPrint("Change stream failed: $e");
      if (isRevert) {
        state = state.copyWith(errorMessage: "Revert failed: $e");
      } else {
        revertToPreviousStream(
          "Could not switch to selected source. Reverting back to previous source.",
        );
      }
    }
  }

  Future<void> retryNextStream({int? sourceSessionId}) async {
    if (sourceSessionId != null && !_isCurrentSourceSession(sourceSessionId)) {
      return;
    }

    // Find the next index that isn't already failed
    int nextIndex = state.currentStreamIndex + 1;
    while (nextIndex < state.streams.length) {
      final attempt = state.sourceAttempts.firstWhereOrNull(
        (e) => e.index == nextIndex,
      );
      if (attempt == null || attempt.status != SourceAttemptStatus.failed) {
        break;
      }
      nextIndex++;
    }

    if (nextIndex < state.streams.length) {
      final nextAttempt = state.sourceAttempts.firstWhereOrNull(
        (e) => e.index == nextIndex,
      );
      // If nextIndex already passed the health check in a prior batch (status=trying),
      // reuse it directly — no need to re-check.
      final alreadyHealthChecked =
          nextAttempt?.status == SourceAttemptStatus.trying;

      // Whether any candidate beyond nextIndex has already been health-checked.
      final hasNextChecked = state.sourceAttempts.any(
        (e) => e.index > nextIndex && e.status != SourceAttemptStatus.pending,
      );

      int targetIndex = nextIndex;

      if (alreadyHealthChecked) {
        // Fast path: nextIndex was already confirmed healthy in the previous batch.
        // Show a counter (single source), no re-check needed.
        // Fix Q1: explicit empty subtitle so the old source name isn't shown.
        _enterStartupPhase(
          kind: PlaybackUiPhaseKind.checkingSources,
          subtitle: '',
          detail: "Source failed. Trying next source...",
          attemptIndex: nextIndex + 1,
          attemptTotal: state.sourceAttempts.isEmpty
              ? state.streams.length
              : state.sourceAttempts.length,
        );
      } else if (!hasNextChecked && state.streams.length > nextIndex + 1) {
        // Batch path: entering a new, unchecked window — run parallel health check.
        final checkCount = (state.streams.length - nextIndex) > 3
            ? 3
            : (state.streams.length - nextIndex);

        // Mark all batch candidates as `trying` BEFORE the parallel check so the
        // source list shows the correct status, and enter a counter-free phase so
        // "Source X of N" doesn't linger from the previous failed source.
        final batchIndices = {
          for (int i = 0; i < checkCount; i++)
            (nextIndex + i) % state.streams.length,
        };
        final updatedAttempts = state.sourceAttempts
            .map(
              (e) => batchIndices.contains(e.index)
                  ? e.copyWith(
                      status: SourceAttemptStatus.trying,
                      isCurrent: e.index == nextIndex,
                    )
                  : e,
            )
            .toList();
        state = state.copyWith(
          sourceAttempts: updatedAttempts,
          currentAttemptIndex: nextIndex,
          // Fix Q1: clear old source name so the subtitle doesn't show
          // the failed source during the parallel check.
          streamSubtitle: "Checking sources...",
        );
        _enterStartupPhase(
          kind: PlaybackUiPhaseKind.checkingSources,
          // No attemptIndex/attemptTotal: counter is meaningless for a batch.
          detail: "Checking $checkCount sources...",
        );

        targetIndex = await _findFirstWorkingStream(
          state.streams,
          startIndex: nextIndex,
          limit: checkCount,
          sourceSessionId: sourceSessionId,
        );
      } else {
        // Single next source (last in list, or all others already checked).
        _enterStartupPhase(
          kind: PlaybackUiPhaseKind.checkingSources,
          subtitle: '',
          detail: "Source failed. Trying next source...",
          attemptIndex: nextIndex + 1,
          attemptTotal: state.sourceAttempts.isEmpty
              ? state.streams.length
              : state.sourceAttempts.length,
        );
      }

      _markSourceAttempt(targetIndex, SourceAttemptStatus.trying);
      unawaited(
        loadStreamAtIndex(
          targetIndex,
          sourceSessionId: sourceSessionId,
          allowResumePrompt: false,
        ),
      );
    } else {
      // All sources exhausted — always show the blocking error overlay regardless
      // of whether playback had started. The overlay has a "Go Back" button.
      _enterAllSourcesFailedPhase();
    }
  }

  void revertToPreviousStream(String message) {
    if (state.previousStream == null) {
      // No previous stream to revert to — skip to the next available source.
      retryNextStream(sourceSessionId: state.sourceSessionId);
      return;
    }
    _revertMessage = message;
    changeStream(state.previousStream!, isRevert: true);
  }

  /// Consumed by the UI to show a one-time snackbar/toast. Null after read.
  String? _revertMessage;
  String? consumeRevertMessage() {
    final msg = _revertMessage;
    _revertMessage = null;
    return msg;
  }

  Future<void> onTorrentFileSelected(int index) async {
    _enterRuntimePhase(
      kind: PlaybackUiPhaseKind.switchingSource,
      detail: "Switching torrent file...",
    );
    try {
      final url = await ref
          .read(torrentServiceProvider)
          .getStreamUrlForFileIndex(index);
      if (url != null && state.currentStream != null) {
        String fileLabel = "Torrent File $index";
        try {
          final files =
              state.torrentStatus?.data['file_stats'] as List<dynamic>?;
          final file = files?.firstWhere(
            (f) => f['id'] == index,
            orElse: () => null,
          );
          if (file != null) {
            fileLabel = (file['path'] as String).split('/').last;
            state = state.copyWith(playerTitle: fileLabel);
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('PlayerController.onTorrentFileSelected: $e');
          }
        }

        final newStream = StreamResult(
          url: url,
          source: "Torrent ($fileLabel)",
          headers: {},
        );
        unawaited(changeStream(newStream, resetPosition: true));
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Failed to switch file: $e");
    }
  }

  /// Reset every per-episode state that would otherwise carry across an
  /// in-place episode swap (no `disposeController()` is called between
  /// episodes — only `_init` does the full reset). Without this, several
  /// landmines fire on auto-next or manual episode switch:
  ///
  /// - `_hasScrobbleStarted`/`_hasMarkedWatched` carry over → `scrobbleStart`
  ///   fires under the wrong episode's tracking record, or `markWatched`
  ///   refuses to fire on the new episode because the previous one was
  ///   already marked.
  /// - `_pendingResumeSeekPosition` carries over → the new episode seeks
  ///   to the *previous* episode's saved offset (potentially past its end).
  /// - `state.skipSegments` carries over → the old episode's intro/outro
  ///   skip button briefly flashes on the new episode's opening seconds
  ///   before the new segments load.
  /// - The sync manager's resolved-ID cache holds the previous item's IDs.
  void _resetPerEpisodeState() {
    _hasScrobbleStarted = false;
    _hasMarkedWatched = false;
    _pendingResumeSeekPosition = null;
    _isApplyingPendingResumeSeek = false;
    ref.read(syncManagerProvider).clearCache();
    if (state.skipSegments.isNotEmpty) {
      state = state.copyWith(skipSegments: const []);
    }
    unawaited(setSubtitleDelay(0.0));
  }

  Future<void> playNextEpisode() async {
    if (_item.contentType != MultimediaContentType.series &&
        _item.contentType != MultimediaContentType.anime) {
      return;
    }

    final nextEpisode = getNextEpisode();
    if (nextEpisode != null) {
      // Smart Next Episode: Check for downloaded version
      final downloadService = ref.read(downloadServiceProvider);
      final localFile = await downloadService.getDownloadedFile(
        _item,
        episode: nextEpisode,
      );

      final String finalUrl = localFile?.path ?? nextEpisode.url;
      final bool isLocal = localFile != null;

      // Save current episode's progress BEFORE updating _episode/_videoUrl.
      // pause() (below) triggers saveProgress() via _playingSub — if _episode
      // already points to nextEpisode at that point, the current position gets
      // written under the wrong episode's history key (classic off-by-one bug).
      saveProgress();
      await pause(); // _episode still = current ep here, so any triggered save is correct

      // NOW switch context to the next episode.
      _suppressNextEpisodeDetection = true;

      _hasConfirmedPlaybackFrame = false;
      _videoUrl = finalUrl;
      _episode = nextEpisode;
      _userAddedExternalSubtitles.clear();
      _resetPerEpisodeState();

      // Refetch intro/outro/recap (IntroDB / AnimeSkip) for the new episode.
      // _resetPerEpisodeState() cleared the previous episode's segments, so
      // without this the next episode has no skip data — the same call that
      // loadEpisode() already makes. _episode now points to nextEpisode.
      unawaited(_fetchAndLogSkipSegments());

      state = state.copyWith(
        playerTitle: "${_item.title} - ${nextEpisode.name}",
        showNextEpisodeOverlay: false,
        streamSubtitle: isLocal ? "Local - Downloaded" : "Fetching sources...",
      );

      await _initStream(
        requestedPhaseKind: PlaybackUiPhaseKind.loadingNextEpisode,
      );
    }
  }

  void dismissNextEpisodeOverlay() {
    _userDismissedOverlay = true;
    state = state.copyWith(showNextEpisodeOverlay: false);
  }

  void toggleEpisodeList() {
    state = state.copyWith(showEpisodeList: !state.showEpisodeList);
  }

  void openEpisodeList() {
    state = state.copyWith(showEpisodeList: true);
  }

  void closeEpisodeList() {
    if (!state.showEpisodeList) return;
    state = state.copyWith(showEpisodeList: false);
  }

  void openSourcesPanel({int tab = 0}) {
    state = state.copyWith(showSourcesPanel: true, sourcesPanelTab: tab);
  }

  void openContentPanel() {
    state = state.copyWith(showContentPanel: true);
  }

  void closeContentPanel() {
    if (!state.showContentPanel) return;
    state = state.copyWith(showContentPanel: false);
  }

  void closeSourcesPanel() {
    if (!state.showSourcesPanel) return;
    state = state.copyWith(showSourcesPanel: false);
  }

  Future<void> loadEpisode(Episode episode) async {
    if (state.isLoading) return; // guard: uiPhase-derived getter
    state = state.copyWith(showEpisodeList: false);

    // Save current episode's progress BEFORE changing _episode/_videoUrl,
    // so the history key written by pause()-triggered saves is correct.
    saveProgress();

    // Smart load: Check for downloaded version
    final downloadService = ref.read(downloadServiceProvider);
    final localFile = await downloadService.getDownloadedFile(
      _item,
      episode: episode,
    );

    final String finalUrl = localFile?.path ?? episode.url;
    final bool isLocal = localFile != null;

    // Pause while _episode/_videoUrl still point to the old episode.
    await pause();

    // NOW switch context to the selected episode.
    _episode = episode;
    _videoUrl = finalUrl;
    _hasConfirmedPlaybackFrame = false;
    _suppressNextEpisodeDetection = true;

    _userAddedExternalSubtitles.clear();
    _resetPerEpisodeState();

    unawaited(_fetchAndLogSkipSegments());

    state = state.copyWith(
      playerTitle: "${_item.title} - ${episode.name}",
      streamSubtitle: isLocal ? "Local - Downloaded" : "Fetching sources...",
    );

    await _initStream(
      requestedPhaseKind: PlaybackUiPhaseKind.loadingNextEpisode,
    );
  }

  void saveProgress() {
    try {
      // Read position/duration from whichever engine is currently active.
      final int pos;
      final int dur;
      if (state.useExoPlayer && _videoViewController != null) {
        pos = _videoViewController!.position.value;
        dur = _videoViewController!.mediaInfo.value?.duration ?? 0;
      } else {
        pos = _player.state.position.inMilliseconds;
        dur = _player.state.duration.inMilliseconds;
      }
      final isLivestream =
          _item.contentType == MultimediaContentType.livestream;

      // Livestreams: save to history without progress (position=0, duration=0)
      if (isLivestream) {
        final pId =
            _item.provider ??
            ref.read(activeProviderProvider)?.packageName ??
            'Unknown';
        final itemToSave = _item.copyWith(provider: pId);
        ref
            .read(watchHistoryProvider.notifier)
            .saveProgress(
              itemToSave,
              0,
              0,
              lastStreamUrl: null, // Don't save temporary links for livestreams
              lastEpisodeUrl: null,
            );
        return;
      }

      if (dur < 30000) return;

      final double progressPercent = (pos / dur) * 100;
      final double progressDecimal = pos / dur;
      final bool isSeries =
          (_item.contentType == MultimediaContentType.series ||
          _item.contentType == MultimediaContentType.anime);
      final currentEpisode = _resolveCurrentEpisode();
      final syncManager = ref.read(syncManagerProvider);

      // 1. Scrobble Start (remote only, once per playback)
      if (!_hasScrobbleStarted && pos > 0) {
        unawaited(
          syncManager
              .scrobbleStart(_item, currentEpisode, progressDecimal)
              .catchError(
                (Object e) => talker.error('scrobbleStart failed', e),
              ),
        );
        _hasScrobbleStarted = true;
      }

      // 2. Mark Watched (remote & local completion logic)
      if (progressPercent >= 90) {
        if (!_hasMarkedWatched) {
          if (isSeries && currentEpisode != null) {
            unawaited(
              ref
                  .read(episodeWatchRepositoryProvider)
                  .setWatched(_item.url, currentEpisode, true)
                  .catchError((Object error) {
                    talker.error('Failed to save local watched state', error);
                  }),
            );
          }

          unawaited(
            syncManager
                .markWatched(_item, currentEpisode)
                .catchError(
                  (Object e) => talker.error('markWatched failed', e),
                ),
          );
          _hasMarkedWatched = true;
        }

        final historyEnabled = ref
            .read(generalSettingsProvider)
            .watchHistoryEnabled;
        if (historyEnabled) {
          final historyNotifier = ref.read(watchHistoryProvider.notifier);
          final pId =
              _item.provider ??
              ref.read(activeProviderProvider)?.packageName ??
              'Unknown';
          final itemToSave = _item.copyWith(provider: pId);

          if (!isSeries) {
            historyNotifier.removeFromHistory(_item.url);
            return;
          } else if (currentEpisode != null) {
            final nextEpisode = getNextEpisode();
            if (nextEpisode != null) {
              // Save NEXT episode as current progress (reset to 0)
              historyNotifier.saveProgress(
                itemToSave,
                0,
                0,
                lastStreamUrl: null,
                lastEpisodeUrl: nextEpisode.url,
                season: nextEpisode.season,
                episode: nextEpisode.episode,
                episodeTitle: nextEpisode.name,
                episodePosterUrl: nextEpisode.posterUrl,
              );
              return;
            } else {
              // Last episode of the series completed
              historyNotifier.removeFromHistory(_item.url);
              return;
            }
          }
        }
      }

      // 3. Normal Local Progress Saving (controlled by settings)
      if (progressPercent > 5 || isSeries) {
        final historyEnabled = ref
            .read(generalSettingsProvider)
            .watchHistoryEnabled;
        if (historyEnabled) {
          final pId =
              _item.provider ??
              ref.read(activeProviderProvider)?.packageName ??
              'Unknown';
          final itemToSave = _item.copyWith(provider: pId);
          ref
              .read(watchHistoryProvider.notifier)
              .saveProgress(
                itemToSave,
                pos,
                dur,
                lastStreamUrl: state.currentStream?.url,
                lastEpisodeUrl: currentEpisode?.url ?? _videoUrl,
                season: currentEpisode?.season,
                episode: currentEpisode?.episode,
                episodeTitle: currentEpisode?.name,
                episodePosterUrl: currentEpisode?.posterUrl,
              );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("History save failed: $e");
    }
  }

  void startTorrentPolling([String? activeStreamUrl]) {
    _torrentPollTimer?.cancel();

    Future<void> poll() async {
      if (_isPolling) return;
      _isPolling = true;
      try {
        final status = await ref
            .read(torrentServiceProvider)
            .getCurrentStatus();
        if (status != null) {
          final urlToCheck = activeStreamUrl ?? state.currentStream?.url;
          if (urlToCheck?.contains("index=") ?? false) {
            try {
              final uri = Uri.parse(urlToCheck!);
              final indexStr = uri.queryParameters['index'];
              if (indexStr != null) {
                final index = int.tryParse(indexStr);
                final files = status.data['file_stats'] as List<dynamic>?;
                final file = files?.firstWhere(
                  (f) => f['id'] == index,
                  orElse: () => null,
                );
                if (file != null) {
                  final name = (file['path'] as String).split('/').last;
                  if (state.playerTitle != name) {
                    state = state.copyWith(playerTitle: name);
                  }
                }
              }
            } catch (e) {
              if (kDebugMode) {
                debugPrint('PlayerController.startTorrentPolling: $e');
              }
            }
          }
          state = state.copyWith(torrentStatus: status);
        }
      } finally {
        _isPolling = false;
      }
    }

    poll();
    _torrentPollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => poll(),
    );
  }

  void stopTorrentPolling() {
    _torrentPollTimer?.cancel();
    _torrentPollTimer = null;
    if (state.torrentStatus != null) {
      state = state.copyWith(torrentStatus: null);
    }
  }

  void disposeController() {
    _isDisposed = true;
    _torrentPollTimer?.cancel();
    _torrentPollTimer = null;
    _stallTimer?.cancel();
    _stallTimer = null;
    _bufferingHideTimer?.cancel();
    _bufferingHideTimer = null;
    _stallRecoveryGuardTimer?.cancel();
    _stallRecoveryGuardTimer = null;

    _videoParamsSub?.cancel();
    _errorSub?.cancel();
    _playingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferingSub?.cancel();
    _completedSub?.cancel();
    _rateSub?.cancel();
    _logSub?.cancel();
    // _trackSub was previously only cancelled in the ref.onDispose safety
    // net (line ~661). If the controller is disposed via this explicit path
    // it would leak the subscription — fixes audit finding H3.
    _trackSub?.cancel();
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _midPlaybackRetryTimer?.cancel();
    _midPlaybackRetryTimer = null;

    // Best-effort cleanup of subtitle temp files we wrote into the OS temp
    // dir. Don't await — the player has to close fast, and the next launch
    // will catch any leftovers. Fixes audit finding H5.
    unawaited(_cleanupSubtitleTempFiles());

    try {
      final int pos;
      final int dur;
      if (state.useExoPlayer && _videoViewController != null) {
        pos = _videoViewController!.position.value;
        dur = _videoViewController!.mediaInfo.value?.duration ?? 0;
      } else {
        pos = _player.state.position.inMilliseconds;
        dur = _player.state.duration.inMilliseconds;
      }
      final double progressDecimal = dur > 0 ? pos / dur : 0.0;
      if (_hasScrobbleStarted && !_hasMarkedWatched) {
        unawaited(
          ref
              .read(syncManagerProvider)
              .scrobbleStop(_item, _resolveCurrentEpisode(), progressDecimal)
              .catchError((Object e) => talker.error('scrobbleStop failed', e)),
        );
      }
    } catch (_) {}

    saveProgress();
    ref.read(torrentServiceProvider).stop();
    Future.microtask(() {
      state = const PlayerState();
    });
  }

  // Walks the OS temp dir and deletes any subtitle file the app's subtitle
  // download pipeline wrote (naming convention: `sub_*` or `temp_sub_*`).
  // Pattern-based rather than tracked-set-based because the search flow runs
  // in a separate provider and tracking handoff is fragile.
  Future<void> _cleanupSubtitleTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (!await tempDir.exists()) return;
      await for (final entity in tempDir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (name.startsWith('sub_') || name.startsWith('temp_sub_')) {
          try {
            await entity.delete();
          } catch (_) {
            // Another player session may already have deleted it. Ignore.
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[PlayerController] subtitle cleanup: $e');
    }
  }

  Future<int> _findFirstWorkingStream(
    List<StreamResult> streams, {
    required int startIndex,
    required int limit,
    int? sourceSessionId,
  }) async {
    if (streams.isEmpty) return 0;

    // Safety check for start index
    final int start = startIndex.clamp(0, streams.length - 1);

    // Extract candidates (circular if needed, though usually not)
    final candidates = <int>[];
    for (int i = 0; i < limit; i++) {
      final idx = (start + i) % streams.length;
      if (!candidates.contains(idx)) candidates.add(idx);
    }

    if (candidates.length <= 1) return start;

    try {
      if (sourceSessionId != null &&
          !_isCurrentSourceSession(sourceSessionId)) {
        return start;
      }
      if (kDebugMode) {
        debugPrint(
          "Starting parallel health check for ${candidates.length} streams",
        );
      }
      // Early-exit parallel check: all candidates start simultaneously, but we
      // resolve as soon as the highest-priority healthy result is available.
      // Example with [0,1,2]: if 0 passes → done immediately (don't wait for 1,2).
      // If 0 fails and 1 passes → done (don't wait for 2).
      // If 0 and 2 have results but 1 is still in flight → wait (1 outranks 2).
      final completer = Completer<int>();
      final results = <int, bool>{}; // idx → isHealthy

      for (final idx in candidates) {
        unawaited(
          _isStreamCandidateHealthy(streams[idx])
              .then((isHealthy) {
                if (completer.isCompleted) return;
                if (!isHealthy) {
                  _markSourceAttempt(
                    idx,
                    SourceAttemptStatus.failed,
                    isCurrent: false,
                  );
                }
                results[idx] = isHealthy;

                // Walk candidates in preference order; stop at the first one
                // whose result we have and which is healthy.
                for (final c in candidates) {
                  if (!results.containsKey(c)) {
                    break; // still waiting for a higher-priority one
                  }
                  if (results[c]!) {
                    if (kDebugMode) {
                      debugPrint("Stream $c is healthy (early-exit)");
                    }
                    completer.complete(c);
                    return;
                  }
                }
                // All results are in and all failed → fall back to start
                if (results.length == candidates.length &&
                    !completer.isCompleted) {
                  completer.complete(start);
                }
              })
              .catchError((_) {
                if (completer.isCompleted) return;
                results[idx] = false;
                _markSourceAttempt(
                  idx,
                  SourceAttemptStatus.failed,
                  isCurrent: false,
                );
                if (results.length == candidates.length) {
                  completer.complete(start);
                }
              }),
        );
      }

      final winner = await completer.future;
      if (sourceSessionId != null &&
          !_isCurrentSourceSession(sourceSessionId)) {
        return start;
      }
      return winner;
    } catch (e) {
      if (kDebugMode) debugPrint("Parallel check failed: $e");
    }

    return start; // Fallback to initial
  }

  Future<List<StreamResult>> _processStreams(
    List<StreamResult> streams,
    PlayerSettings settings, {
    void Function(bool)? onFallback,
  }) async {
    final onWifi = await isOnWifi();
    final preference = onWifi ? settings.wifiQuality : settings.mobileQuality;
    final filtered = filterStreamsByQuality(
      streams,
      preference,
      settings.qualityFilterMode,
      onFallback: onFallback,
    );
    return sortStreamsByQuality(filtered, preference);
  }

  String _getProviderDisplayName(String providerName) {
    try {
      final manager = ref.read(extensionManagerProvider.notifier);
      final p = manager.getAllProviders().firstWhere(
        (p) => p.packageName == providerName || p.name == providerName,
      );
      if (p.isDebug) return "${p.name} [DEBUG]";
      return p.name;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PlayerController._getProviderDisplayName: $e');
      }
    }
    return providerName;
  }

  Future<String?> _resolveStreamUrl(StreamResult stream) async {
    if (stream.url.startsWith("magnet:") ||
        stream.url.endsWith(".torrent") ||
        (stream.url.startsWith("/") && stream.source.contains("Torrent"))) {
      state = state.copyWith(streamSubtitle: "Initializing Torrent Engine...");
      final torrentUrl = await ref
          .read(torrentServiceProvider)
          .getStreamUrl(stream.url);
      if (torrentUrl != null) return torrentUrl;
      return null;
    }

    return AppUtils.normalizeUrl(stream.url);
  }

  /// Applies per-playback MPV properties (headers, cookies, DRM).
  Future<void> _applyPlaybackProperties(
    Map<String, String> headers,
    StreamResult stream, {
    required bool useVideoView,
  }) async {
    // Debug: log what DRM fields the stream has so failures are traceable.
    if (kDebugMode) {
      debugPrint(
        '[Player] Opening stream — url=${stream.url} '
        'source=${stream.source} '
        'isLive=${_isLiveStream(stream.url)} '
        'drmKid=${stream.drmKid} drmKey=${stream.drmKey} '
        'licenseUrl=${stream.licenseUrl}',
      );
      debugPrint('[Player] Headers for stream: $headers');
      // Enable mpv internal log for every stream so HLS variant selection
      // and segment fetch errors appear in logcat regardless of live/VOD.
      _logSub ??= _player.stream.log.listen((log) {
        // Always forward warn/error/fatal; also forward verbose hls/lavf lines
        // that match keywords useful for diagnosing auth / track selection issues.
        if (log.level == 'warn' ||
            log.level == 'error' ||
            log.level == 'fatal' ||
            log.text.contains('hls') ||
            log.text.contains('m3u8') ||
            log.text.contains('variant') ||
            log.text.contains('rendition') ||
            log.text.contains('opening') ||
            log.text.contains('Opening') ||
            log.text.contains('lavf') ||
            log.text.contains('audio') ||
            log.text.contains('video') ||
            log.text.contains('track') ||
            log.text.contains('stream') ||
            log.text.contains('codec') ||
            log.text.contains('403') ||
            log.text.contains('404') ||
            log.text.contains('401') ||
            log.text.contains('redirect') ||
            log.text.contains('cookie') ||
            log.text.contains('header') ||
            log.text.contains('http://') ||
            log.text.contains('https://')) {
          debugPrint('[MPV/${log.level}] ${log.text}');
        }
      });
    }

    if (_player.platform is NativePlayer) {
      final native = _player.platform as NativePlayer;

      final lowerHeaders = headers.map((k, v) => MapEntry(k.toLowerCase(), v));

      // Propagate ALL provided headers to MPV (Critical for cookies/auth)
      if (lowerHeaders.isNotEmpty) {
        final List<String> headerFields = [];
        lowerHeaders.forEach((key, value) {
          // FFmpeg/libavformat "headers" option standard is CRLF terminated strings.
          // Comma-separated list is also accepted by MPV but CRLF is more robust.
          headerFields.add('$key: $value');
        });

        if (headerFields.isNotEmpty) {
          // Join with \r\n and ensure it ends with \r\n
          final fields = '${headerFields.join('\r\n')}\r\n';
          if (kDebugMode) {
            debugPrint('Player: Setting http-header-fields: $fields');
          }
          await native.setProperty('http-header-fields', fields);
        }
      }

      // Also set dedicated properties for better compatibility
      if (lowerHeaders.containsKey('user-agent')) {
        await native.setProperty('user-agent', lowerHeaders['user-agent']!);
      }
      if (lowerHeaders.containsKey('referer')) {
        await native.setProperty('referrer', lowerHeaders['referer']!);
      }

      // 0. Hardware decoding preference
      // Use auto-copy on Windows: 'auto-copy' / 'd3d11va-copy' copies decoded
      // frames to a staging surface, completely preventing DXGI KeyedMutex
      // deadlocks and TDR crashes when the Flutter UI is restored after idle.
      // RC1: once a decode/codec failure has forced software decoding for this
      // session (weak TV decoder etc.), always use 'no' regardless of setting.
      final settings = ref.read(playerSettingsProvider).asData?.value;
      if (_forceSoftwareDecode) {
        await native.setProperty('hwdec', 'no');
      } else if (settings?.hardwareDecoding ?? true) {
        await native.setProperty(
          'hwdec',
          Platform.isWindows ? 'auto-copy' : 'auto',
        );
      } else {
        await native.setProperty('hwdec', 'no');
      }

      // RC3: disable TLS cert verification for VOD too (was previously only
      // set on the live path). The libmpv builds differ per platform — the
      // shinchiro Windows build and the bundled macOS build ship
      // differently-aged CA bundles, so a stream whose cert chain validates
      // on Windows can fail the TLS handshake on macOS. Disabling cert
      // verification removes that per-build divergence. This matches the
      // existing posture (live already did this; usesCleartextTraffic is on).
      await native.setProperty('tls-verify', 'no');

      // 1. Performance tuning & Anti-Looping
      await native.setProperty('cache', 'yes');

      // Accumulates demuxer-lavf-o options; applied as one combined call below
      // to prevent later additions (e.g. DRM key) from silently overwriting
      // earlier ones (e.g. live reconnect seg_max_retry).
      final demuxerLavfOpts = <String>[];

      // Propagate auth headers to lavf's internal HTTP client.
      // http-header-fields only covers mpv's stream layer; lavf's HLS demuxer
      // fetches EXT-X-MAP init segments, child playlists, and alternate audio
      // rendition playlists through its own HTTP context.
      //
      // We use 'headers=Cookie: VALUE\r\n' (not 'cookies=VALUE') because:
      // - cookies= is parsed as Set-Cookie syntax: 't_hash_t=A; ott=nf; hd=on'
      //   treats '; ott=nf' as a cookie attribute, so only 't_hash_t' is sent.
      //   The CDN needs the full cookie string including ott and hd.
      // - A single-header headers= entry with CRLF only at the END is safe from
      //   mpv's comma-list parser (embedded mid-value CRLF would split incorrectly).
      // - demuxer-lavf-o only supports ONE 'headers=' key (later overwrites earlier),
      //   so we pack only Cookie here; Referer is covered by http-header-fields for
      //   the top-level fetch and is less critical for CDN segment auth.
      if (lowerHeaders.containsKey('cookie')) {
        demuxerLavfOpts.add('headers=Cookie: ${lowerHeaders['cookie']!}\r\n');
      }

      final isLivePattern =
          _isLiveStream(stream.url) ||
          _item.contentType == MultimediaContentType.livestream;
      if (kDebugMode) {
        debugPrint(
          'Stream Type (isLivePattern): $isLivePattern, URL: ${stream.url}',
        );
      }
      if (isLivePattern) {
        // Live TV: small buffer to absorb network jitter, not the large VOD buffer
        await native.setProperty('demuxer-readahead-secs', '8');
        await native.setProperty('cache-secs', '8');
        await native.setProperty('cache', 'yes');
        await native.setProperty('cache-pause-initial', 'yes');
        await native.setProperty('cache-pause-wait', '2');

        // Network
        await native.setProperty('network-timeout', '30');
        await native.setProperty('tls-verify', 'no');

        // Reconnect
        await native.setProperty(
          'stream-lavf-o',
          'reconnect_on_network_error=1,reconnect_delay_max=5,reconnect_on_eof=1,reconnect_streamed=1',
        );

        // HLS/DASH segment retry — collected for combined application below.
        demuxerLavfOpts.add('seg_max_retry=5');

        // Playback
        await native.setProperty('framedrop', 'decoder');
        await native.setProperty('hr-seek-framedrop', 'yes');
        await native.setProperty(
          'hwdec',
          Platform.isWindows ? 'auto-copy' : 'auto-safe',
        );

        // H.264 resilience: wait for clean keyframe after reconnect
        await native.setProperty('vd-lavc-skiploopfilter', 'nonkey');
        await native.setProperty('vd-lavc-skipframe', 'nonref');
      } else {
        final settings = ref.read(playerSettingsProvider).asData?.value;
        final readahead = settings?.readaheadSeconds ?? 180;
        await native.setProperty('demuxer-readahead-secs', '$readahead');
        await native.setProperty('cache-secs', '$readahead');
        await native.setProperty('cache', 'yes');
        await native.setProperty('cache-pause', 'yes');
        await native.setProperty('cache-pause-wait', '2');
        await native.setProperty('network-timeout', '30');

        // Tell FFmpeg's HTTP stream handler to treat the connection as
        // byte-seekable and automatically reconnect on network switches or dropped sockets.
        await native.setProperty(
          'stream-lavf-o',
          'seekable=1,icy=0,reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,reconnect_delay_max=10',
        );
        await native.setProperty('force-seekable', 'yes');

        // Force mpv to select the highest-bandwidth HLS variant so it never
        // picks an audio-only rendition when the master playlist lists one first.
        await native.setProperty('hls-bitrate', 'max');

        // Allow segment URLs with any file extension (ts, mp4, m4s, no-ext…).
        // FFmpeg's HLS demuxer silently drops segments whose extension isn't on
        // its whitelist, causing audio-only playback when video segments use
        // non-standard extensions.
        demuxerLavfOpts.add('allowed_extensions=ALL');
        demuxerLavfOpts.add(
          'icy=0',
        ); // suppress Icy-MetaData:1 on segment fetches too
        demuxerLavfOpts.add('seg_max_retry=10');
        demuxerLavfOpts.add('reconnect_delay_max=10');

        // HLS manifests declare codec/language via EXT-X-MEDIA and EXT-X-MAP
        // tags, so FFmpeg doesn't need deep probing to detect streams. The
        // global 32MB/30s values cause ~27s delay when all audio renditions are
        // probed through the local proxy before video starts.
        final isHlsStream =
            stream.url.toLowerCase().contains('.m3u8') ||
            stream.url.toLowerCase().contains('/hls/');
        if (isHlsStream) {
          // 5 MB covers a full 1080p fMP4 video segment for codec detection.
          // 2 s per rendition keeps startup fast even with many audio tracks
          // (e.g. 11 tracks × 2 s ≈ 22 s worst-case; fast CDNs finish sooner).
          await native.setProperty('demuxer-lavf-probesize', '5242880'); // 5 MB
          await native.setProperty('demuxer-lavf-analyzeduration', '2'); // 2 s
        } else {
          await native.setProperty(
            'demuxer-lavf-probesize',
            '33554432',
          ); // 32MB
          await native.setProperty('demuxer-lavf-analyzeduration', '30'); // 30s
        }
      }

      // Adaptive demuxer cache based on device profile.
      // DASH streams on desktop and Windows playback are capped appropriately to prevent
      // memory fragmentation and GPU staging texture starvation over long playback sessions.
      final profile = ref.read(deviceProfileProvider).asData?.value;
      final isDashStream = _isDashStreamUrl(stream.url);
      String cacheSize = "512MiB"; // Default
      if (profile != null) {
        if (profile.isTv) {
          cacheSize = "128MiB"; // Less RAM on TVs
        } else if (profile.isDesktopOS || profile.isTablet) {
          cacheSize = isDashStream
              ? "256MiB"
              : (Platform.isWindows ? "256MiB" : "1GiB");
        }
      }

      await native.setProperty('demuxer-max-bytes', cacheSize);
      // Allow seeking back without re-fetching — proportional to device RAM
      final backCacheSize = profile?.isTv == true
          ? '64MiB'
          : (profile?.isDesktopOS == true || profile?.isTablet == true)
          ? (Platform.isWindows ? '128MiB' : '256MiB')
          : '128MiB';
      await native.setProperty('demuxer-max-back-bytes', backCacheSize);

      // 2. Resolve ClearKey Hex Keys
      String? keyHex = stream.drmKey;

      if (keyHex == null && stream.licenseUrl != null) {
        final extractedKeys = await _extractKeysFromLicenseUrl(
          stream.licenseUrl!,
          headers: stream.headers,
        );
        if (extractedKeys != null) {
          keyHex = extractedKeys['key'];
        }
      }

      if (keyHex != null) {
        // FFmpeg's DASH demuxer natively expects cenc_decryption_key.
        // It's usually the 32-character hex KEY.
        if (kDebugMode) {
          debugPrint(
            '[DRM] Injecting cenc_decryption_key via demuxer-lavf-o: $keyHex',
          );
        }

        if (!useVideoView) {
          // Collected into demuxerLavfOpts and applied below to prevent
          // overwriting live reconnect options (seg_max_retry) set earlier.
          demuxerLavfOpts.add('cenc_decryption_key=$keyHex');
        } else {
          // If using VideoView on Android, we'd pass DRM keys to the native side here.
        }
      }

      // 3. Apply all demuxer-lavf-o options in a single combined call.
      //    Multiple setProperty('demuxer-lavf-o', ...) calls overwrite each
      //    other; joining here ensures live and DRM settings coexist.
      if (demuxerLavfOpts.isNotEmpty) {
        await native.setProperty('demuxer-lavf-o', demuxerLavfOpts.join(','));
      }

      try {
        final tempDir = await getTemporaryDirectory();
        // Use p.join to produce a platform-correct path; on Windows the mixed
        // forward/back-slash path produced by string concatenation can confuse
        // libmpv's internal path parser.
        final cookieFile = File(p.join(tempDir.path, 'mpv_cookies.txt'));
        if (!await cookieFile.exists()) {
          await cookieFile.create();
        }
        await native.setProperty('cookies-file', cookieFile.path);

        // Set a writable cache dir so mpv can persist its seek-backward and
        // init-segment cache to disk. Without this, mpv logs "Failed to create
        // file cache" and must re-fetch EXT-X-MAP init segments every time they
        // are needed; if the CDN expires the init segment URL (404) before the
        // next re-fetch, audio/video stops (typically ~20 s into playback).
        await native.setProperty('cache-dir', tempDir.path);
      } catch (e) {
        if (kDebugMode) debugPrint('Failed to set cache-dir/cookies-file: $e');
      }

      // Re-assert: disable native MPV subtitle rendering on the video
      // surface. MPV resets sub-visibility when a new file is opened,
      // so we must set it again after every stream load.
      await native.setProperty('sub-visibility', 'no');
    }
  }

  /// Fetches [masterUrl], proxies all audio rendition URIs and variant stream
  /// URLs through localhost, and returns a rewritten playlist.
  ///
  /// Keeps up to [_kMaxProxiedAudioTracks] audio renditions. When there are
  /// more renditions than that limit, only the highest-priority ones are kept —
  /// which prevents FFmpeg from probing every rendition (11 tracks × ~5 s =
  /// 55 s startup delay).
  ///
  /// Priority scoring:
  ///   lang param match  +4   (e.g. URL has ?lang=eng → prefer LANGUAGE="en*")
  ///   DEFAULT=YES       +2
  ///   AUTOSELECT=YES    +1
  ///
  /// The top-ranked track is emitted first and forced to DEFAULT=YES so mpv
  /// selects it automatically. This prevents picking an HE-AAC/5.1 original-
  /// language track when the user requested a stereo AAC-LC dubbed track.
  ///
  /// Returns null if the master playlist can't be fetched.
  Future<String?> _buildSimplifiedMasterPlaylist(
    String masterUrl,
    Map<String, String> headers,
    ProxyOptions proxyOptions,
  ) async {
    // No hard limit on audio tracks — we proxy ALL renditions so auth cookies
    // reach every track. Probe time is controlled by demuxer-lavf-analyzeduration
    // (set to 2 s for HLS below); worst case N tracks × 2 s = manageable startup.

    try {
      final response = await http.get(Uri.parse(masterUrl), headers: headers);
      if (response.statusCode < 200 || response.statusCode >= 300) return null;

      final baseUri = Uri.parse(masterUrl);
      final lines = response.body.split('\n');

      // Extract the lang hint from the URL (e.g. ?lang=eng → 'eng').
      final langHint = baseUri.queryParameters['lang']?.toLowerCase();

      // Score every audio rendition line so we can rank them.
      final allAudio = <(String line, int score)>[];
      for (final line in lines) {
        final t = line.trim();
        if (!t.startsWith('#EXT-X-MEDIA:') || !t.contains('TYPE=AUDIO')) {
          continue;
        }
        int score = 0;
        if (t.contains('DEFAULT=YES')) score += 2;
        if (t.contains('AUTOSELECT=YES')) score += 1;
        if (langHint != null) {
          final m = RegExp(
            r'LANGUAGE="([^"]*)"',
            caseSensitive: false,
          ).firstMatch(t);
          if (m != null) {
            // Match across ISO 639-1/2 variants: 'eng' matches 'en' and vice-versa.
            final lang = m.group(1)!.toLowerCase();
            if (lang.startsWith(langHint) || langHint.startsWith(lang)) {
              score += 4;
            }
          }
        }
        allAudio.add((t, score));
      }

      // Sort descending by score; keep all (lang-preferred first, then DEFAULT)
      allAudio.sort((a, b) => b.$2.compareTo(a.$2));
      final kept = allAudio;

      // Rebuild the playlist, replacing audio lines in score-sorted order.
      final result = <String>[];
      int audioEmitted = 0;
      for (final line in lines) {
        final t = line.trim();

        if (t.startsWith('#EXT-X-MEDIA:') && t.contains('TYPE=AUDIO')) {
          if (audioEmitted < kept.length) {
            // Proxy the URI= attribute.
            var out = kept[audioEmitted].$1.replaceAllMapped(
              RegExp(r'URI="([^"]+)"'),
              (m) {
                final resolved = baseUri.resolve(m.group(1)!).toString();
                return 'URI="${LocalProxyService.instance.getProxyUrl(resolved, headers: headers, options: proxyOptions)}"';
              },
            );
            if (audioEmitted == 0) {
              // Top-ranked track must be DEFAULT so mpv picks it first.
              out = out.contains('DEFAULT=')
                  ? out.replaceFirst(RegExp(r'DEFAULT=\w+'), 'DEFAULT=YES')
                  : out.replaceFirst(
                      '#EXT-X-MEDIA:',
                      '#EXT-X-MEDIA:DEFAULT=YES,',
                    );
            } else {
              // Non-primary tracks must not override the top track as default.
              out = out.replaceFirst(RegExp(r'DEFAULT=YES'), 'DEFAULT=NO');
            }
            result.add(out);
            audioEmitted++;
          }
          // Any audio line beyond our limit is dropped.
          continue;
        }

        // Non-comment, non-empty lines are variant stream URLs — proxy them.
        if (t.isNotEmpty && !t.startsWith('#')) {
          final resolved = baseUri.resolve(t).toString();
          result.add(
            LocalProxyService.instance.getProxyUrl(
              resolved,
              headers: headers,
              options: proxyOptions,
            ),
          );
          continue;
        }

        result.add(line);
      }

      if (kDebugMode) {
        debugPrint(
          '[PLAYER] Simplified HLS master: kept ${kept.length}/${allAudio.length} audio tracks',
        );
      }
      return result.join('\n');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PLAYER] _buildSimplifiedMasterPlaylist error: $e');
      }
      return null;
    }
  }

  /// Fetches a ClearKey license from [licenseUrl] and returns the FIRST
  /// kid and key found as a map: {'kid': '...', 'key': '...'} in hex format.
  /// If the response is not parseable, returns null.
  Future<Map<String, String>?> _extractKeysFromLicenseUrl(
    String licenseUrl, {
    Map<String, String>? headers,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('[DRM] Fetching ClearKey license from $licenseUrl');
      }
      final response = await http.get(Uri.parse(licenseUrl), headers: headers);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (kDebugMode) {
          debugPrint('[DRM] License server returned ${response.statusCode}');
        }
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final keys = body['keys'] as List<dynamic>?;
      if (keys == null || keys.isEmpty) {
        if (kDebugMode) debugPrint('[DRM] No keys array in license response');
        return null;
      }

      // MPV's libdash only supports a single kid:key pair reliably via Laurl redirect.
      for (final entry in keys) {
        final kid = entry['kid'] as String?;
        final k = entry['k'] as String?;
        if (kid == null || k == null) continue;

        // Base64url → hex conversion.
        final kidHex = _base64UrlToHex(kid);
        final keyHex = _base64UrlToHex(k);
        if (kidHex != null && keyHex != null) {
          return {'kid': kidHex, 'key': keyHex};
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[DRM] Error fetching/parsing license: $e');
      return null;
    }
  }

  /// Converts a Base64url-encoded string to a lowercase hex string.
  String? _base64UrlToHex(String base64url) {
    try {
      // Add padding if needed.
      String padded = base64url;
      final rem = padded.length % 4;
      if (rem == 2) padded += '==';
      if (rem == 3) padded += '=';
      final bytes = base64Url.decode(padded);
      return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DRM] base64url decode failed for "$base64url": $e');
      }
      return null;
    }
  }

  bool _isLiveStream(String url) {
    if (url.isEmpty) return false;

    // Items explicitly marked as livestream in provider metadata
    if (_item.contentType == MultimediaContentType.livestream) return true;

    final lower = url.toLowerCase();

    // Torrents and local files are definitely VOD
    if (lower.startsWith('magnet:') ||
        lower.endsWith('.torrent') ||
        lower.startsWith('/')) {
      return false;
    }

    // Live protocols
    if (lower.startsWith('rtmp://') ||
        lower.startsWith('rtsp://') ||
        lower.startsWith('mms://') ||
        lower.startsWith('udp://') ||
        lower.startsWith('rtp://')) {
      return true;
    }

    // IPTV specific path/query patterns
    if (lower.contains('/live/') ||
        lower.contains('/iptv/') ||
        lower.contains('stream.m3u8') ||
        lower.contains('chunklist')) {
      return true;
    }

    // Xtream Codes API patterns
    if (lower.contains('type=m3u8') || lower.contains('output=m3u8')) {
      return true;
    }

    // Default to VOD for bandwidth protection
    return false;
  }

  Future<void> _safeSeekTo(int position) async {
    if (position <= 0) return;

    // ExoPlayer path: seek directly; no media_kit stream to wait on.
    if (state.useExoPlayer && _videoViewController != null) {
      try {
        _videoViewController!.seekTo(position);
      } catch (e) {
        if (kDebugMode) debugPrint("ExoPlayer seek failed: $e");
      }
      return;
    }

    // media_kit path: wait for duration to be known before seeking.
    try {
      var duration = _player.state.duration;
      if (duration == Duration.zero) {
        duration = await _player.stream.duration
            .firstWhere((d) => d != Duration.zero)
            .timeout(const Duration(seconds: 8));
      }

      final maxMs = duration.inMilliseconds;
      if (maxMs <= 0) return;

      final targetMs = position.clamp(0, maxMs);
      await _player.seek(Duration(milliseconds: targetMs));
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        debugPrint("Timeout waiting for duration: $e");
      }

      // Best-effort fallback: some streams can seek before duration is reported.
      try {
        await _player.seek(Duration(milliseconds: position));
      } catch (seekError) {
        if (kDebugMode) {
          debugPrint("Fallback seek failed: $seekError");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Seek failed: $e");
      }
    }
  }

  Future<void> _flushPendingResumeSeek() async {
    int? pos = _pendingResumeSeekPosition;
    final pct = _pendingResumeSeekPercentage;
    if (pos == null && pct != null) {
      final int dur = state.useExoPlayer
          ? _videoViewController?.mediaInfo.value?.duration ?? 0
          : _player.state.duration.inMilliseconds;
      if (dur > 0) {
        pos = (dur * (pct / 100.0)).toInt();
      }
    }

    if (pos == null || pos <= 0 || _isApplyingPendingResumeSeek) return;

    _isApplyingPendingResumeSeek = true;
    try {
      await _safeSeekTo(pos);
      _pendingResumeSeekPosition = null;
      _pendingResumeSeekPercentage = null;
    } finally {
      _isApplyingPendingResumeSeek = false;
    }
  }

  /// [persist] = true marks this as a user-driven speed change that should
  /// be remembered for the next playback session. Transient sites — the
  /// space-hold 2× boost and its revert — pass false so a momentary
  /// long-press doesn't permanently change the user's default speed.
  Future<void> setPlaybackSpeed(double rate, {bool persist = false}) async {
    final appliedRate = rate.clamp(0.5, state.maxPlaybackSpeed);

    if (state.useExoPlayer && _videoViewController != null) {
      _videoViewController!.setSpeed(appliedRate);
      state = state.copyWith(playbackSpeed: appliedRate);
    } else {
      await _player.setRate(appliedRate);
      state = state.copyWith(playbackSpeed: appliedRate);
    }

    if (persist) {
      unawaited(
        ref
            .read(playerSettingsProvider.notifier)
            .setDefaultPlaybackSpeed(appliedRate),
      );
    }
  }

  Future<void> setSubtitleDelay(double seconds) async {
    if (!state.supportsSubtitleDelay) return;

    final native = _player.platform;
    if (native is NativePlayer) {
      await native.setProperty('sub-delay', seconds.toString());
      state = state.copyWith(subtitleDelay: seconds);
    }
  }

  Future<void> applySubtitleSettings() async {
    if (_isDisposed || !state.supportsSubtitleStyling) return;

    final native = _player.platform;
    if (native is NativePlayer) {
      final settings =
          ref.read(playerSettingsProvider).asData?.value ??
          const PlayerSettings();

      // Colors are in MPV hex format (e.g. #AARRGGBB)
      String colorToMpvHex(int color, [double opacity = 1.0]) {
        final alpha =
            (opacity * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
        final rgb = color.toRadixString(16).padLeft(8, '0').substring(2);
        return '#$alpha$rgb';
      }

      // 1. Font Size
      final fontSize = settings.subFixedTextSize ?? settings.subtitleSize;
      await native.setProperty('sub-font-size', fontSize.toString());

      // 2. Font Family / Custom Typeface
      const List<String> builtInFonts = [
        'sans-serif',
        'Trebuchet MS',
        'Netflix Sans',
        'Google Sans',
        'Open Sans',
        'Futura',
        'Consolas',
        'Gotham',
        'Lucida Grande',
        'STIX General',
        'Times New Roman',
        'Verdana',
        'Ubuntu',
        'Comic Sans MS',
        'Poppins',
      ];

      if (settings.subTypefaceFilePath != null &&
          settings.subTypefaceFilePath!.isNotEmpty) {
        final file = File(settings.subTypefaceFilePath!);
        if (file.existsSync()) {
          await native.setProperty('sub-fonts-dir', file.parent.path);
          await native.setProperty(
            'sub-font',
            p.basenameWithoutExtension(file.path),
          );
        }
      } else if (settings.subTypeface != null &&
          settings.subTypeface! >= 0 &&
          settings.subTypeface! < builtInFonts.length) {
        await native.setProperty('sub-font', builtInFonts[settings.subTypeface!]);
      } else {
        await native.setProperty('sub-font', 'sans-serif');
      }

      // 3. Bold & Italic
      await native.setProperty('sub-bold', settings.subBold ? 'yes' : 'no');
      await native.setProperty('sub-italic', settings.subItalic ? 'yes' : 'no');

      // 4. Foreground Text Color
      final fgColor = settings.subForegroundColor != 0xFFFFFFFF
          ? settings.subForegroundColor
          : settings.subtitleColor;
      await native.setProperty('sub-color', colorToMpvHex(fgColor));

      // 5. Edge / Outline / Shadow
      final edgeColorHex = colorToMpvHex(settings.subEdgeColor);
      final edgeSize = settings.subEdgeSize ?? 2.5;

      switch (settings.subEdgeType) {
        case 0: // None
          await native.setProperty('sub-border-size', '0');
          await native.setProperty('sub-shadow-offset', '0');
          break;
        case 1: // Outline
          await native.setProperty('sub-border-size', edgeSize.toString());
          await native.setProperty('sub-border-color', edgeColorHex);
          await native.setProperty('sub-shadow-offset', '0');
          break;
        case 2: // Raised
          await native.setProperty('sub-border-size', '1');
          await native.setProperty('sub-border-color', edgeColorHex);
          await native.setProperty('sub-shadow-offset', '1.5');
          await native.setProperty('sub-shadow-color', edgeColorHex);
          break;
        case 3: // Shadow / Drop Shadow
          await native.setProperty('sub-border-size', '0');
          await native.setProperty('sub-shadow-offset', edgeSize.toString());
          await native.setProperty('sub-shadow-color', edgeColorHex);
          break;
        case 4: // Uniform Drop Shadow
          await native.setProperty('sub-border-size', '1');
          await native.setProperty('sub-border-color', edgeColorHex);
          await native.setProperty('sub-shadow-offset', '2.0');
          await native.setProperty('sub-shadow-color', edgeColorHex);
          break;
      }

      // 6. Background Color & Opacity
      final bgColor = settings.subBackgroundColor != 0x00000000
          ? settings.subBackgroundColor
          : settings.subtitleBackgroundColor;
      if (bgColor != 0x00000000 && settings.subBackgroundOpacity > 0.0) {
        await native.setProperty(
          'sub-back-color',
          colorToMpvHex(bgColor, settings.subBackgroundOpacity),
        );
      } else {
        await native.setProperty('sub-back-color', '#00000000');
      }

      // 7. Alignment
      final alignmentCode = settings.subAlignment ?? 2;
      final alignX = switch (alignmentCode) {
        1 || 4 || 7 => 'left',
        3 || 6 || 9 => 'right',
        _ => 'center',
      };
      final alignY = switch (alignmentCode) {
        7 || 8 || 9 => 'top',
        4 || 5 || 6 => 'center',
        _ => 'bottom',
      };
      await native.setProperty('sub-align-x', alignX);
      await native.setProperty('sub-align-y', alignY);

      // 8. Position & Margin
      final subPos = settings.subtitlePosition.clamp(0.0, 100.0).round();
      await native.setProperty('sub-pos', subPos.toString());
      await native.setProperty(
        'sub-margin-y',
        (settings.subElevation * 1.5).round().toString(),
      );

      // 9. ASS styling override & keep MPV direct painting disabled (handled by SubtitleViewConfiguration)
      await native.setProperty('sub-ass-override', 'yes');
      await native.setProperty('sub-visibility', 'no');
    }
  }

  Future<double> _getSystemVolumeLevel() async {
    try {
      return ((await FlutterVolumeController.getVolume()) ?? 0.5).clamp(
        0.0,
        1.0,
      );
    } catch (_) {
      return 0.5;
    }
  }

  double _getEngineVolumeLevel() {
    if (state.useExoPlayer && _videoViewController != null) {
      return _videoViewController!.volume.value.clamp(0.0, 1.0);
    }

    return (_player.state.volume / 100).clamp(0.0, 2.0);
  }

  Future<void> _setSystemVolumeLevel(double value) async {
    try {
      await FlutterVolumeController.setVolume(value.clamp(0.0, 1.0));
    } catch (_) {}
  }

  Future<void> _setEngineVolumeLevel(double value) async {
    if (state.useExoPlayer && _videoViewController != null) {
      _videoViewController!.setVolume(value.clamp(0.0, 1.0));
      return;
    }

    await _player.setVolume((value * 100).clamp(0.0, 200.0));
  }

  Future<double> getVolumeLevel() async {
    final systemVolume = await _getSystemVolumeLevel();
    final engineVolume = _getEngineVolumeLevel();
    final value = engineVolume > 1.0 ? engineVolume : systemVolume;
    if (value > 0) {
      _lastNonZeroVolumeLevel = value;
    }
    return value;
  }

  Future<double> setVolumeLevel(double value) async {
    final target = value.clamp(0.0, state.supportsVolumeBoost ? 2.0 : 1.0);

    if (target > 0) {
      _lastNonZeroVolumeLevel = target;
    }

    if (target > 1.0 && state.supportsVolumeBoost) {
      await _setSystemVolumeLevel(1.0);
      await _setEngineVolumeLevel(target);
      return target;
    }

    await _setEngineVolumeLevel(1.0);
    await _setSystemVolumeLevel(target);
    return target;
  }

  Future<double> changeVolume(double step) async {
    final current = await getVolumeLevel();
    final boostStep = state.supportsVolumeBoost && current >= 1.0
        ? step * 2
        : step;
    return setVolumeLevel(current + boostStep);
  }

  Future<double> toggleMute() async {
    final current = await getVolumeLevel();
    if (current > 0) {
      return setVolumeLevel(0.0);
    }

    return setVolumeLevel(_lastNonZeroVolumeLevel);
  }

  Future<void> loadExternalSubtitleFile({String? filePath}) async {
    if (state.useExoPlayer && !state.supportsExternalSubtitleLoading) {
      return;
    }

    String? path = filePath;
    if (path == null) {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'vtt', 'ass', 'ssa'],
      );
      if (result != null && result.files.single.path != null) {
        path = result.files.single.path!;
      }
    }

    if (path != null) {
      final ext = p.extension(path).toLowerCase().replaceAll('.', '');
      final baseName = p.basenameWithoutExtension(path).trim();
      final label = baseName.isNotEmpty ? baseName : "External ($ext)";
      final newSub = SubtitleFile(url: path, label: label, lang: "und");

      state = state.copyWith(
        externalSubtitles: _effectiveExternalSubtitles(
          state.currentStream?.subtitles,
        ),
      );

      if (!_userAddedExternalSubtitles.any((sub) => sub.url == newSub.url)) {
        _userAddedExternalSubtitles.add(newSub);
        state = state.copyWith(
          externalSubtitles: _effectiveExternalSubtitles(
            state.currentStream?.subtitles,
          ),
        );
      }

      if (state.useExoPlayer && state.currentStream != null) {
        pendingVideoViewSubtitleIdsBeforeReload = _videoViewController
            ?.mediaInfo
            .value
            ?.subtitleTracks
            .keys
            .toSet();
        selectNewestVideoViewSubtitleAfterReload =
            !(Platform.isMacOS || Platform.isIOS);

        await changeStream(state.currentStream!, resetPosition: false);

        if (!state.useExoPlayer) {
          pendingVideoViewSubtitleIdsBeforeReload = null;
          selectNewestVideoViewSubtitleAfterReload = false;
          await selectSubtitleTrack('external:${newSub.url}');
        }
        return;
      }

      await selectSubtitleTrack('external:${newSub.url}');
    }
  }
}

final playerControllerProvider =
    NotifierProvider.autoDispose<PlayerController, PlayerState>(
      PlayerController.new,
    );
