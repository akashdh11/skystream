import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart'
    show ProviderListenable;
import 'package:vlc_player/vlc_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/network/http_defaults.dart';
import '../../../../core/providers/device_info_provider.dart';
import '../../../settings/presentation/player_settings_provider.dart';
import '../../../../core/extensions/providers.dart';
import '../../../../core/models/torrent_status.dart';
import '../../../../core/services/local_proxy_service.dart';
import '../../domain/episode_navigator.dart';
import '../../../skip/data/skip_service.dart';
import '../../domain/clear_key.dart';
import '../../domain/playback_progress.dart';
import '../../domain/skip_segments.dart';
import '../../domain/playback_tracker.dart';
import '../../domain/stream_resolver.dart';
import '../../domain/subtitle_style.dart';
import '../player_platform_service.dart';
import 'vlc_player_controls.dart';

/// Playback on the VLC engine.
///
/// Built up over the migration notes phases 5 through 6.8: engine-owned
/// tracks, resolution of the route's plugin token into a real stream, headers
/// that libVLC can actually transmit, progress and resume, completion and
/// scrobbling, and source failover.
///
/// STILL OUT OF SCOPE, and not stubbed either — a missing feature should be
/// obviously missing rather than half-present: DRM, torrent, PiP, skip
/// segments, next-episode, gestures, playback speed and volume boost.
class VlcPlayerScreen extends ConsumerStatefulWidget {
  const VlcPlayerScreen({
    required this.item,
    required this.videoUrl,
    this.episode,
    this.preloadedStreams,
    super.key,
  });

  final MultimediaItem item;

  /// The plugin's resolution token, **not** a URL. See [resolvePlayback].
  final String videoUrl;

  final Episode? episode;

  /// Sources already aggregated by a source sheet. When present, no plugin
  /// call is made.
  final List<StreamResult>? preloadedStreams;

  @override
  ConsumerState<VlcPlayerScreen> createState() => _VlcPlayerScreenState();
}

enum _Stage { resolving, playing, failed }

/// How many times one source is re-opened before moving to the next. Only
/// applies to a source that actually produced frames — one that never played is
/// simply dead and gets no retries.
const int _kSameSourceRetries = 2;

/// How many times a live feed is reopened before giving up on that source.
/// Reset as soon as playback actually resumes, so an all-evening channel that
/// drops once an hour never exhausts it.
const int _kMaxLiveReconnects = 5;

/// Breathing room before reopening a dropped live feed. Without it a dead URL
/// ends instantly and the reopen becomes a hot loop.
const Duration _kLiveReconnectDelay = Duration(seconds: 2);

class _VlcPlayerScreenState extends ConsumerState<VlcPlayerScreen>
    with WidgetsBindingObserver {
  /// The screen owns the controller, and its lifetime is exactly this State's.
  ///
  /// This is the ownership the migration plan calls for and the old player got
  /// wrong: PlayerController is ref.keepAlive()'d while PlayerScreen owns and
  /// disposes the actual Player, which is why per-session state leaked across
  /// episodes there. Starting correct is free; retrofitting it is not.
  late final VlcPlayerController _controller;

  _Stage _stage = _Stage.resolving;
  String _error = '';

  /// Shown under the spinner while opening, when there is something worth
  /// saying - a cold magnet link can take a long time to become playable.
  String _status = '';
  bool _disposed = false;

  PlaybackProgressRecorder? _recorder;
  PlaybackTracker? _tracker;

  /// The last position/duration pair observed while playback was actually
  /// running. Teardown writes this rather than asking the engine, because by
  /// then the engine reports zero — see playback_progress.dart.
  ProgressSample? _sample;

  /// Identifies this media session. Stamped onto every sample so a value that
  /// still describes the previous media cannot be written against this one.
  int _token = 0;

  /// The pre-resolution source URL, which is what the resolver's saved-source
  /// lookup matches on. Deliberately not the proxied URL.
  String? _lastStreamUrl;

  ResolvedPlayback? _resolved;
  ResumePoint? _initialResume;

  /// The episode currently playing. Mutable because advancing swaps media on
  /// this same State rather than pushing a new route.
  Episode? _episode;

  /// The plugin token for [_episode]. Starts as the route's, then follows.
  late String _videoUrl;

  /// Sources the route pre-aggregated. They belong to the FIRST episode only,
  /// so advancing must drop them or the next episode plays this one's streams.
  List<StreamResult>? _preloaded;

  /// One advance at a time. The engine's ended event, a retry and any future
  /// button can all land within the same second.
  bool _advancing = false;

  /// Cancellation token for the open chain. Bumped on every attempt, so a
  /// failover that completes late cannot overwrite a newer one.
  int _generation = 0;
  int _attemptIndex = 0;
  int _attemptRetries = 0;

  /// Edge detectors. `VlcPlayerValue` is level-triggered and the native error
  /// is sticky until the next setSource, so without these one dead source
  /// produces an unbounded failover storm.
  bool _sawError = false;
  bool _sawEnded = false;

  /// Decided from the item and URL at open time rather than from the engine,
  /// because it governs buffering and what end-of-media means.
  bool _isLive = false;

  /// Consecutive live reopen attempts that have not yet produced playback.
  int _liveReconnects = 0;

  /// The last position observed, used to tell real playback from a stuck state
  /// enum.
  Duration _lastSeenPosition = Duration.zero;

  /// Desktop window state, mirrored so the button icon can follow it.
  bool _isFullscreen = false;

  /// Whether this session ever started the torrent engine, so teardown only
  /// stops something it actually started.
  bool _startedTorrent = false;

  /// Intro/outro bands for the current episode. Usually empty: both sources
  /// are opt-in and off by default.
  List<SkipSegment> _skipSegments = const <SkipSegment>[];

  final PlayerPlatformService _platform = PlayerPlatformService();

  /// Live torrent statistics, polled only while a torrent is actually playing.
  TorrentStatus? _torrentStatus;
  Timer? _torrentPoll;

  /// Guards against a slow poll overlapping the next tick, which would queue
  /// requests against the torrent server rather than skipping a beat.
  bool _pollingTorrent = false;

  ProviderContainer? _container;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container = ProviderScope.containerOf(context, listen: false);
  }

  T _read<T>(ProviderListenable<T> provider) {
    final container = _container;
    if (container != null) {
      return container.read(provider);
    }
    return ref.read(provider);
  }

  @override
  void initState() {
    super.initState();
    _episode = widget.episode;
    _videoUrl = widget.videoUrl;
    _preloaded = widget.preloadedStreams;
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Subtitles are drawn by the engine, so the user's appearance settings have
    // to be supplied at construction. Without them VLC uses its own default
    // relative size of 16, which is enormous on a full-screen video.
    final settings =
        ref.read(playerSettingsProvider).asData?.value ?? const PlayerSettings();

    _controller = VlcPlayerController(
      autoPlay: true,
      // Native events are not throttled by default and position ticks are not
      // deduped, so every tick would rebuild the overlay and run the progress
      // listener. Four updates a second is plenty for a seek bar.
      eventThrottleInterval: const Duration(milliseconds: 250),
      config: VlcPlayerConfig(
        network: VlcNetworkConfig(
          // VOD default from user settings (buffer depth); a live source overrides it per-media in _openAttempt.
          networkCaching: settings.readaheadSeconds > 0
              ? (settings.readaheadSeconds * 1000).clamp(1000, 60000)
              : 3000,
          userAgent: kDefaultBrowserUserAgent,
          // The mpv path pins hls-bitrate=max because FFmpeg treats HLS variant
          // bitrate as metadata and never switches on it. libVLC does adapt, but
          // its estimator starts pessimistic and can sit on a low rendition for
          // a long stretch, so pin the highest for the same reason.
          adaptiveLogic: VlcAdaptiveLogic.highest,
        ),
        subtitleStyle: subtitleStyleFrom(settings),
        // The user's hardware-decoding preference. libVLC has no equivalent for
        // the tone-mapping settings that sat beside this one, but it does have
        // --avcodec-hw, so this switch is honoured rather than ignored.
        decoding: VlcDecodingConfig(
          hardwareAcceleration: settings.hardwareDecoding
              ? VlcHardwareAcceleration.automatic
              : VlcHardwareAcceleration.disabled,
        ),
      ),
      // Verified present in both shipped libVLC builds (VLCKit 3.7.3 and
      // libvlc-all 3.7.0) - see FORK.md section 8 for why option names are
      // checked against the binary rather than assumed.
      options: const <String>['--http-reconnect'],
    );

    _controller.addListener(_onPlaybackValue);
    unawaited(_start());
  }

  /// Resolve the candidate list, then open the best one.
  ///
  /// Everything that can fail is inside one try, and every failure lands on the
  /// same error state rather than an exception in initState — which is exactly
  /// how the JSON-token crash surfaced.
  Future<void> _start() async {
    try {
      final resolved = await resolvePlayback(
        read: _read,
        item: widget.item,
        videoUrl: _videoUrl,
        preloadedStreams: _preloaded,
        isCancelled: () => _disposed,
      );
      if (_disposed) return;
      _resolved = resolved;

      _token++;
      final currentEpisode = _currentEpisode;
      _recorder = PlaybackProgressRecorder(
        read: _read,
        item: widget.item,
        episode: currentEpisode,
        videoUrl: _videoUrl,
        token: _token,
      );
      // One tracker for the whole screen, deliberately: failing over to another
      // source is still the same episode, so the watched latch must survive it.
      _tracker = PlaybackTracker(
        read: _read,
        item: widget.item,
        episode: currentEpisode,
        token: _token,
      );

      // Resolved from storage before the engine ever sees the media, and
      // applied as a start position rather than a seek. That removes the whole
      // question of when the engine is ready enough to seek — the old path
      // carried a pending-seek percentage and a readiness race to answer it.
      _initialResume = resumePointFor(
        read: _read,
        item: widget.item,
        episode: currentEpisode,
        videoUrl: _videoUrl,
      );

      // Not awaited: both skip sources are network lookups against
      // crowdsourced databases, and playback must not wait on a convenience.
      unawaited(_loadSkipSegments(currentEpisode));

      await _openAttempt(
        resolved.index,
        startAt: _initialResume?.position ?? Duration.zero,
      );
    } catch (e) {
      _fail(e is StreamResolutionException ? e.message : 'Playback failed: $e');
    }
  }

  /// Opens one candidate.
  ///
  /// The generation counter is bumped first and re-checked after every await.
  /// Without it a failover triggered by a dying source can land after the user
  /// has already moved on, and hand the engine media nobody asked for.
  Future<void> _openAttempt(
    int index, {
    required Duration startAt,
    int retries = 0,
  }) async {
    final resolved = _resolved;
    if (resolved == null || _disposed) return;
    if (index < 0 || index >= resolved.streams.length) {
      return _fail(
        'None of the ${resolved.streams.length} sources would play.',
      );
    }

    final generation = ++_generation;
    _sawError = false;
    _sawEnded = false;
    _attemptIndex = index;
    _attemptRetries = retries;

    final stream = resolved.streams[index];

    // libVLC cannot decrypt CENC on any build we ship, so ClearKey content is
    // decrypted in the local proxy and handed to the engine as plaintext.
    // Anything we cannot key ourselves - a licence server, or a scheme other
    // than ClearKey - still has no path.
    final clearKey = clearKeyFor(stream);
    final obstacle = drmObstacleFor(stream);
    if (obstacle != null) return _fail(describeDrmObstacle(obstacle));

    // A torrent has to be prepared and seeded before anything can open it, and
    // that can take a while on a cold magnet - so say so rather than sitting on
    // a blank screen.
    final isTorrent = isTorrentSource(stream);
    if (isTorrent && mounted && _stage != _Stage.playing) {
      setState(() => _status = 'Preparing torrent…');
    }
    if (isTorrent && !_startedTorrent) {
      _startedTorrent = true;
      _startTorrentPolling();
    }
    final playable = await playableUrlFor(read: _read, stream: stream);
    if (_disposed || generation != _generation) return;
    if (playable == null) {
      return _failAttempt('torrent could not be prepared');
    }

    final uri = _playableUri(playable);
    if (uri == null) return _failAttempt('source has no playable address');

    final headers = playbackHeaders(stream);
    final mediaUri = clearKey != null
        ? await _decryptingUri(uri, headers, clearKey)
        : await _deliverableUri(uri, headers);
    if (_disposed || generation != _generation) return;

    _lastStreamUrl = stream.url;
    _isLive = isLiveSource(widget.item, stream.url);
    await _controller.setMedia(
      VlcMediaSource(
        uri: mediaUri,
        httpHeaders: headers,
        startPosition: startAt,
        // Live trades latency for jitter tolerance and never seeks, so it wants
        // a small live buffer rather than the large VOD readahead.
        mediaOptions: _isLive
            ? const <String>[':live-caching=3000', ':network-caching=3000']
            : const <String>[],
      ),
      autoPlay: true,
    );
    if (_disposed || generation != _generation) return;

    // Register the source's subtitles with the engine rather than tracking
    // them ourselves. VLC turns each into an ordinary subtitle track, so
    // getSubtitleTracks() returns one list containing both embedded and
    // external entries, with one kind of id.
    //
    // addSubtitle has no header channel at any layer, so a subtitle behind
    // the same protection as the video can only be reached by proxying it.
    final subtitlesNeedIdentity = stream.headers?.isNotEmpty ?? false;
    for (final sub in stream.subtitles ?? const <SubtitleFile>[]) {
      final subUri = _playableUri(sub.url);
      if (subUri == null) continue;
      final deliverable = subtitlesNeedIdentity
          ? await _proxied(subUri, headers)
          : subUri;
      if (_disposed || generation != _generation) return;
      unawaited(_controller.addSubtitle(deliverable));
    }

    if (!_disposed && _stage != _Stage.playing) {
      setState(() {
        _stage = _Stage.playing;
        _status = '';
      });
    }
  }

  /// The current candidate failed. Retry it, or move to the next one.
  ///
  /// Resumes from the last sample taken while playing rather than from
  /// `controller.value`, which `setMedia` has already zeroed by the time any
  /// retry runs — losing the user's position is the one thing failover must
  /// never do.
  void _failAttempt(String reason) {
    if (_disposed) return;
    final resolved = _resolved;
    if (resolved == null) return;

    final startAt = _controller.value.isLive
        ? Duration.zero
        : (_sample?.position ?? _initialResume?.position ?? Duration.zero);

    // A source that produced frames and then died is worth another try at the
    // same URL; one that never played at all is simply dead.
    final hadFrames = _sample != null;
    if (hadFrames && _attemptRetries < _kSameSourceRetries) {
      unawaited(
        _openAttempt(
          _attemptIndex,
          startAt: startAt,
          retries: _attemptRetries + 1,
        ),
      );
      return;
    }

    final next = _attemptIndex + 1;
    if (next >= resolved.streams.length) {
      return _fail(
        'None of the ${resolved.streams.length} sources would play.',
      );
    }
    unawaited(_openAttempt(next, startAt: startAt));
  }

  /// End-of-media is ambiguous: a finished film and a truncated download look
  /// identical to the engine. Only a position short of the duration
  /// distinguishes them.
  void _handleEnded() {
    if (_disposed) return;
    _flushProgress();

    // A live feed has no end. Reaching one means the stream dropped, so
    // reopening the same source is the right answer - advancing or failing over
    // to another source would abandon a channel that is merely interrupted.
    if (_isLive) {
      if (_liveReconnects >= _kMaxLiveReconnects) {
        // This source keeps dropping without ever coming back; try another.
        _liveReconnects = 0;
        _failAttempt('live feed dropped repeatedly');
        return;
      }
      _liveReconnects++;
      final generation = _generation;
      unawaited(
        Future<void>.delayed(_kLiveReconnectDelay).then((_) async {
          if (_disposed || generation != _generation) return;
          await _openAttempt(
            _attemptIndex,
            startAt: Duration.zero,
            retries: _attemptRetries,
          );
        }),
      );
      return;
    }

    final sample = _sample;
    if (sample != null &&
        sample.duration > Duration.zero &&
        sample.position < sample.duration - const Duration(seconds: 2)) {
      _failAttempt('stream ended before its duration');
      return;
    }
    unawaited(_advance());
  }

  /// Looks up intro/outro segments in the background.
  ///
  /// Never awaited by the open path: both sources are network lookups against
  /// crowdsourced databases, and playback must not wait on a convenience.
  Future<void> _loadSkipSegments(Episode? episode) async {
    if (episode == null) return;
    final token = _token;
    final segments = await fetchSkipSegments(
      read: _read,
      item: widget.item,
      episode: episode,
    );
    if (_disposed || token != _token || segments.isEmpty) return;
    setState(() => _skipSegments = segments);
  }

  /// Whether an episode follows this one. Recomputed rather than cached so it
  /// cannot go stale after an advance.
  bool get _hasNextEpisode =>
      nextEpisodeFor(
        item: widget.item,
        current: _currentEpisode,
        videoUrl: _videoUrl,
      ).next !=
      null;

  /// Polls the torrent server while a torrent is playing.
  ///
  /// Three seconds matches the old controller. The status is only meaningful
  /// while the engine is seeding, so polling starts with playback rather than
  /// with the screen, and stops with it.
  void _startTorrentPolling() {
    _torrentPoll?.cancel();
    _torrentPoll = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_disposed || _pollingTorrent) return;
      _pollingTorrent = true;
      try {
        final status = await _read(torrentServiceProvider).getCurrentStatus();
        if (!_disposed && mounted) setState(() => _torrentStatus = status);
      } catch (e) {
        if (kDebugMode) debugPrint('Torrent status poll failed: $e');
      } finally {
        _pollingTorrent = false;
      }
    });
  }

  /// Picture-in-picture is an Android activity mode; there is no equivalent on
  /// the other platforms this ships to, and it is meaningless on a television.
  bool get _pipAvailable =>
      Platform.isAndroid &&
      !(_read(deviceProfileProvider).asData?.value.isTv ?? false);

  /// Only a desktop window can change size; mobile and TV are already full
  /// screen, so the affordance is absent rather than inert.
  bool get _fullscreenAvailable =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  Future<void> _toggleFullscreen() async {
    final now = await _platform.toggleFullscreen();
    if (mounted && !_disposed) setState(() => _isFullscreen = now);
  }

  void _enterPip() {
    unawaited(_platform.enterPip(_controller.value.isPlaying));
  }

  /// Lets the viewer move off a source that plays but plays badly — failover
  /// only reacts to outright failure.
  void _openSourcePicker() {
    final resolved = _resolved;
    if (resolved == null) return;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFF141414),
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: resolved.streams.length,
            itemBuilder: (context, i) {
              final stream = resolved.streams[i];
              return ListTile(
                dense: true,
                selected: i == _attemptIndex,
                selectedColor: Colors.white,
                leading: Icon(
                  i == _attemptIndex
                      ? Icons.play_arrow_rounded
                      : Icons.source_outlined,
                  color: Colors.white70,
                ),
                title: Text(
                  stream.displaySource,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  if (i == _attemptIndex) return;
                  // Carry the position across, exactly as failover does.
                  unawaited(
                    _openAttempt(
                      i,
                      startAt: _controller.value.isLive
                          ? Duration.zero
                          : (_sample?.position ?? Duration.zero),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// Moves to the next episode in place, on this controller and this State.
  ///
  /// In place rather than a fresh route because the screen already owns its
  /// controller for the State's lifetime; pushing would tear down and rebuild
  /// the native view for no gain. The cost is that every per-episode field has
  /// to be reset by hand here — which is exactly the bookkeeping the old path
  /// got wrong, so the reset is a single block rather than scattered.
  Future<void> _advance() async {
    if (_disposed || _advancing) return;
    _advancing = true;
    try {
      final lookup = nextEpisodeFor(
        item: widget.item,
        current: _currentEpisode,
        videoUrl: _videoUrl,
      );

      // The outgoing episode's session ends first: finish() emits its single
      // terminal tracking event while the tracker still describes it.
      _tracker?.finish();

      final next = lookup.next;
      if (next == null) {
        // Only a located last episode means "finished". A current episode we
        // could not find in the list means "don't know", and deleting the
        // series on that would cascade across every per-episode row.
        if (lookup.isFinalEpisode) {
          clearFinishedFromHistory(read: _read, item: widget.item);
        }
        return;
      }

      rollForwardHistory(read: _read, item: widget.item, next: next);

      // Per-episode reset. _token, _recorder, _tracker and _initialResume are
      // rebuilt by _start(); _generation and the attempt/edge flags by
      // _openAttempt(). These four are the ones nothing else clears.
      _sample = null;
      _lastStreamUrl = null;
      _resolved = null;
      _preloaded = null; // route sources belong to the first episode only
      _skipSegments = const <SkipSegment>[]; // previous episode's intro/outro

      _episode = next;
      _videoUrl = next.url;
      if (mounted) setState(() {}); // title/subtitle follow the new episode

      await _start();
    } finally {
      _advancing = false;
    }
  }

  /// The episode this session is playing, resolved the way the old controller
  /// does: an explicitly passed episode wins, otherwise match the route's token
  /// against the series' own episode list.
  Episode? get _currentEpisode {
    if (_episode != null) return _episode;
    final type = widget.item.contentType;
    final isSeries =
        type == MultimediaContentType.series ||
        type == MultimediaContentType.anime;
    if (!isSeries) return null;
    return widget.item.episodes?.firstWhereOrNull((e) => e.url == _videoUrl);
  }

  /// Samples progress, and only while playback is genuinely running.
  ///
  /// Every other state lies: `stopped` and `ended` report position zero, and a
  /// value taken right after `setMedia` still carries the previous media's
  /// numbers because VlcPlayerValue merges into its predecessor.
  void _onPlaybackValue() {
    if (_disposed) return;
    final value = _controller.value;
    final recorder = _recorder;
    if (recorder == null) return;

    // Both of these are edges, not levels, and neither may run synchronously
    // inside the listener - failing over calls setMedia, which notifies again.
    if (value.state == VlcPlaybackState.error) {
      if (!_sawError) {
        _sawError = true;
        final reason = value.errorDescription ?? 'playback error';
        scheduleMicrotask(() => _failAttempt(reason));
      }
      return;
    }
    if (value.state == VlcPlaybackState.ended) {
      if (!_sawEnded) {
        _sawEnded = true;
        scheduleMicrotask(_handleEnded);
      }
      return;
    }

    // Advancing position is the only trustworthy sign of playback, so it - not
    // the state enum - decides whether this counts as progress. libVLC reports
    // `buffering` throughout healthy playback on some builds, and gating on the
    // enum meant progress, scrobbling and completion never fired at all.
    final advanced = value.position != _lastSeenPosition;
    _lastSeenPosition = value.position;
    final running =
        value.state != VlcPlaybackState.paused &&
        value.state != VlcPlaybackState.stopped &&
        (value.isPlaying || advanced);

    if (running) {
      final sample = ProgressSample(
        position: value.position,
        duration: value.duration,
        token: _token,
      );
      // Real playback: this source is alive, so the live reconnect budget is
      // restored rather than being consumed over the whole session.
      _liveReconnects = 0;
      if (!sample.isWritable) return;
      _sample = sample;
      recorder.record(sample, lastStreamUrl: _lastStreamUrl);
      _tracker?.onPlaying(sample);
      return;
    }

    // Pausing is the user's own save point, so flush past the rate limit.
    // `buffering` is a separate state, so this really is a user pause.
    if (value.state == VlcPlaybackState.paused) {
      _flushProgress();
      _tracker?.onPaused();
    }
  }

  /// Writes the last known-good sample, bypassing the rate limit.
  void _flushProgress() {
    final sample = _sample;
    final recorder = _recorder;
    if (sample == null || recorder == null) return;
    recorder.record(sample, lastStreamUrl: _lastStreamUrl, force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed || !mounted) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // The process may not come back. This is the last guaranteed chance.
      _flushProgress();
    }
  }

  void _fail(String message) {
    if (_disposed) return;
    setState(() {
      _stage = _Stage.failed;
      _error = message;
    });
  }

  /// Plugins hand back both real URLs and bare filesystem paths; only the
  /// former survive [Uri.parse].
  Uri? _playableUri(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('/') ||
        (Platform.isWindows && value.contains(':\\'))) {
      return Uri.file(value);
    }
    final uri = Uri.tryParse(value);
    return (uri != null && uri.hasScheme) ? uri : null;
  }

  /// Returns a URL libVLC can open while still presenting [headers].
  ///
  /// libVLC 3.x can transmit only User-Agent and Referer — there is no option
  /// for Cookie, Authorization, Origin or anything custom, so those headers
  /// cannot reach the server no matter how they are passed. When a stream needs
  /// one, the URL is handed to the local proxy instead, which re-injects the
  /// full set on the real request and across redirects. This is the same answer
  /// the mpv path reached, for the same reason.
  Future<Uri> _deliverableUri(Uri uri, Map<String, String> headers) async {
    if (!uri.scheme.startsWith('http')) return uri;
    if (unsupportedVlcHeaders(headers).isEmpty) return uri;
    return _proxied(uri, headers);
  }

  /// Routes an encrypted DASH manifest through the decrypting proxy.
  Future<Uri> _decryptingUri(
    Uri uri,
    Map<String, String> headers,
    ClearKey clearKey,
  ) async {
    await LocalProxyService.instance.startServer();
    return Uri.parse(
      LocalProxyService.instance.getDecryptingDashUrl(
        uri.toString(),
        key: clearKey.key,
        keyId: clearKey.keyId,
        headers: headers,
      ),
    );
  }

  Future<Uri> _proxied(Uri uri, Map<String, String> headers) async {
    if (!uri.scheme.startsWith('http')) return uri;
    // getProxyUrl starts the server without awaiting it, and the port is 0
    // until the bind completes - so a cold first call would build a URL
    // pointing at port 0. Start it explicitly first.
    await LocalProxyService.instance.startServer();
    return Uri.parse(
      LocalProxyService.instance.getProxyUrl(
        uri.toString(),
        headers: headers,
        // Without this the proxy strips Cookie outright
        // (local_proxy_service.dart:563), which would defeat the whole point
        // of routing through it. Keep exactly the cookies the source supplied.
        options: ProxyOptions(keepCookies: _cookieNames(headers)),
      ),
    );
  }

  List<String> _cookieNames(Map<String, String> headers) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() != 'cookie') continue;
      return entry.value
          .split(';')
          .map((pair) => pair.split('=').first.trim())
          .where((name) => name.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Order matters: dispose() stops the player, and a stopped libVLC reports
    // position zero. Write first, tear down second. finish() runs after the
    // local write and emits exactly one terminal tracking event.
    _flushProgress();
    _tracker?.finish();
    _disposed = true;
    _torrentPoll?.cancel();
    // A window left full screen after the video closes traps the user in a
    // chrome-less shell. Not gated on _isFullscreen: that only tracks the
    // toggles we issued, and is wrong whenever the OS window control was used
    // instead - which is exactly when this matters.
    unawaited(_platform.exitFullscreen());
    _controller.removeListener(_onPlaybackValue);
    _controller.dispose();
    // The torrent server seeds in the background; nothing else stops it.
    if (_startedTorrent) unawaited(_read(torrentServiceProvider).stop());
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: switch (_stage) {
        _Stage.resolving => _statusFrame(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              if (_status.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  _status,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ],
          ),
        ),
        _Stage.failed => _statusFrame(
          Text(
            _error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        _Stage.playing => Stack(
          fit: StackFit.expand,
          children: [
            VlcPlayer(controller: _controller),
            // The overlay gets its own layer so a chrome repaint never forces
            // the embedder to recomposite the video surface beneath it.
            RepaintBoundary(
              child: VlcPlayerControls(
              controller: _controller,
              title: widget.item.title,
              subtitle: _currentEpisode?.name,
              onBack: () => Navigator.of(context).maybePop(),
              // Both are null unless the thing they do is actually available,
              // so the overlay never renders a button that would do nothing.
              onNextEpisode: _hasNextEpisode ? () => unawaited(_advance()) : null,
              onOpenSources: (_resolved?.streams.length ?? 0) > 1
                  ? _openSourcePicker
                  : null,
              onEnterPip: _pipAvailable ? _enterPip : null,
              onToggleFullscreen: _fullscreenAvailable ? _toggleFullscreen : null,
              isFullscreen: _isFullscreen,
              isLive: _isLive,
              skipSegments: _skipSegments,
              torrentStatus: _torrentStatus,
              ),
            ),
          ],
        ),
      },
    );
  }

  /// Resolving and failed share one frame so that back is always reachable —
  /// on TV there is no gesture to fall back on.
  Widget _statusFrame(Widget child) {
    return SafeArea(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              autofocus: true,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Center(
            child: Padding(padding: const EdgeInsets.all(32), child: child),
          ),
        ],
      ),
    );
  }
}
