import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vlc_player/vlc_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/network/http_defaults.dart';
import '../../../../core/services/local_proxy_service.dart';
import '../../domain/playback_progress.dart';
import '../../domain/playback_tracker.dart';
import '../../domain/stream_resolver.dart';
import 'vlc_player_controls.dart';

/// Playback on the VLC engine.
///
/// Reached only when [VlcEngineEnabled] is on. The media_kit / video_view
/// screen is untouched and remains the default, so this cannot regress
/// shipping playback.
///
/// Built up over docs/PLAYER_MIGRATION.md phases 5 through 6.8: engine-owned
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controller = VlcPlayerController(
      autoPlay: true,
      // Native events are not throttled by default and position ticks are not
      // deduped, so every tick would rebuild the overlay and run the progress
      // listener. Four updates a second is plenty for a seek bar.
      eventThrottleInterval: const Duration(milliseconds: 250),
      config: const VlcPlayerConfig(
        network: VlcNetworkConfig(
          // Matches what the mpv path asks for on VOD. Live tuning is Phase 7.
          networkCaching: 3000,
          userAgent: kDefaultBrowserUserAgent,
        ),
      ),
    );

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
        read: ref.read,
        item: widget.item,
        videoUrl: widget.videoUrl,
        preloadedStreams: widget.preloadedStreams,
        isCancelled: () => _disposed,
      );
      if (_disposed) return;
      _resolved = resolved;

      _token++;
      final currentEpisode = _currentEpisode;
      _recorder = PlaybackProgressRecorder(
        read: ref.read,
        item: widget.item,
        episode: currentEpisode,
        videoUrl: widget.videoUrl,
        token: _token,
      );
      // One tracker for the whole screen, deliberately: failing over to another
      // source is still the same episode, so the watched latch must survive it.
      _tracker = PlaybackTracker(
        read: ref.read,
        item: widget.item,
        episode: currentEpisode,
        token: _token,
      );

      // Resolved from storage before the engine ever sees the media, and
      // applied as a start position rather than a seek. That removes the whole
      // question of when the engine is ready enough to seek — the old path
      // carried a pending-seek percentage and a readiness race to answer it.
      _initialResume = resumePointFor(
        read: ref.read,
        item: widget.item,
        episode: currentEpisode,
        videoUrl: widget.videoUrl,
      );

      _controller.addListener(_onPlaybackValue);
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
    if (stream.url.startsWith('magnet:') || stream.url.endsWith('.torrent')) {
      return _fail('Torrent playback is not on the VLC engine yet.');
    }
    if (stream.drmKey != null ||
        stream.drmKid != null ||
        stream.licenseUrl != null) {
      return _fail('DRM playback is not on the VLC engine yet.');
    }

    final uri = _playableUri(stream.url);
    if (uri == null) return _failAttempt('source has no playable address');

    final headers = playbackHeaders(stream);
    final mediaUri = await _deliverableUri(uri, headers);
    if (_disposed || generation != _generation) return;

    _lastStreamUrl = stream.url;
    await _controller.setMedia(
      VlcMediaSource(
        uri: mediaUri,
        httpHeaders: headers,
        startPosition: startAt,
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
      setState(() => _stage = _Stage.playing);
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
    final sample = _sample;
    if (sample != null &&
        sample.duration > Duration.zero &&
        sample.position < sample.duration - const Duration(seconds: 2)) {
      _failAttempt('stream ended before its duration');
    }
  }

  /// The episode this session is playing, resolved the way the old controller
  /// does: an explicitly passed episode wins, otherwise match the route's token
  /// against the series' own episode list.
  Episode? get _currentEpisode {
    if (widget.episode != null) return widget.episode;
    final type = widget.item.contentType;
    final isSeries =
        type == MultimediaContentType.series ||
        type == MultimediaContentType.anime;
    if (!isSeries) return null;
    return widget.item.episodes?.firstWhereOrNull(
      (e) => e.url == widget.videoUrl,
    );
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

    if (value.state == VlcPlaybackState.playing) {
      final sample = ProgressSample(
        position: value.position,
        duration: value.duration,
        token: _token,
      );
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
    // Order matters: dispose() stops the player, and a stopped libVLC reports
    // position zero. Write first, tear down second. finish() runs after the
    // local write and emits exactly one terminal tracking event.
    _flushProgress();
    _tracker?.finish();
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onPlaybackValue);
    _controller.dispose();
    WakelockPlus.disable();
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
        _Stage.resolving => _status(const CircularProgressIndicator()),
        _Stage.failed => _status(
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
            VlcPlayerControls(
              controller: _controller,
              title: widget.item.title,
              subtitle: widget.episode?.name,
              onBack: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      },
    );
  }

  /// Resolving and failed share one frame so that back is always reachable —
  /// on TV there is no gesture to fall back on.
  Widget _status(Widget child) {
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
