import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'vlc_media_info.dart';
import 'vlc_media_source.dart';
import 'vlc_player_config.dart';
import 'vlc_media_stats.dart';
import 'vlc_player_controller_internals.dart';
import 'vlc_player_error.dart';
import 'vlc_player_value.dart';
import 'vlc_video_fit.dart';

/// Playlist repeat behavior used by `VlcPlayerController.setPlaylist`.
enum VlcPlaylistLoopMode {
  /// Stop at the beginning or end of the playlist.
  none,

  /// Repeat the current playlist item when it ends.
  loopOne,

  /// Wrap to the first or last item when advancing past an edge.
  loopAll,
}

/// Controls a `VlcPlayer` and exposes playback state.
///
/// A controller can be configured before it is attached to a widget. Calls to
/// [setMedia] or [setPlaylist] are remembered and applied when the native
/// player is created. Playback commands such as [play] and [pause] require the
/// controller to be attached to a `VlcPlayer`.
abstract class VlcPlayerController extends ValueNotifier<VlcPlayerValue> {
  /// Creates a controller.
  ///
  /// Use [mediaSource] when an initial media item should be applied when the
  /// native player is created.
  /// Prefer [config] over hand-written [options]: it is typed, documented, and
  /// spells the VLC flags for you. When both are given, [config] is expanded
  /// first and [options] appended, so a raw option always wins over the
  /// generated equivalent.
  factory VlcPlayerController({
    VlcMediaSource? mediaSource,
    bool autoPlay = false,
    VlcPlayerConfig? config,
    List<String> options = const <String>[],
    Duration? eventThrottleInterval,
  }) {
    return _VlcPlayerController(
      mediaSource: mediaSource,
      autoPlay: autoPlay,
      options: <String>[...?config?.toOptions(), ...options],
      eventThrottleInterval: eventThrottleInterval,
    );
  }

  VlcPlayerController._() : super(const VlcPlayerValue());

  /// Whether the initially configured media source should start playback
  /// immediately.
  bool get autoPlay;

  /// VLC instance options applied when the native player is created.
  List<String> get options;

  /// Optional interval used to coalesce progress-only native events.
  ///
  /// When set to a positive duration, updates that only change playback
  /// position, media duration, or buffering progress are delivered at most once
  /// per interval. State, readiness, track metadata, volume, speed, and errors
  /// still notify listeners immediately. The default `null` keeps every
  /// distinct native value update visible immediately.
  Duration? get eventThrottleInterval;

  /// Whether this controller is currently attached to a native player instance.
  bool get isAttached;

  /// Current playlist items, or an empty list when no playlist is active.
  List<VlcMediaSource> get playlist;

  /// Current playlist index, or `null` when no playlist is active.
  int? get playlistIndex;

  /// Current playlist loop mode.
  VlcPlaylistLoopMode get playlistLoopMode;

  /// Current media source, including a pending source set before attachment.
  VlcMediaSource? get currentMediaSource;

  /// Whether [next] can move to another item without wrapping.
  bool get hasNext;

  /// Whether [previous] can move to another item without wrapping.
  bool get hasPrevious;

  /// Loads a [VlcMediaSource].
  ///
  /// Use this when the item needs HTTP headers, VLC media options, or an
  /// initial seek position. This clears any active playlist.
  Future<void> setMedia(VlcMediaSource source, {bool autoPlay = false});

  /// Loads a playlist and selects [initialIndex].
  ///
  /// [sources] must be non-empty. When [autoAdvance] is true, the controller
  /// advances after VLC reports that the current item ended. [loopMode] controls
  /// repeat and wrap behavior.
  Future<void> setPlaylist(
    List<VlcMediaSource> sources, {
    int initialIndex = 0,
    bool autoPlay = false,
    bool autoAdvance = true,
    VlcPlaylistLoopMode loopMode = VlcPlaylistLoopMode.none,
  });

  /// Moves to the next playlist item.
  ///
  /// Returns `false` when there is no next item and [playlistLoopMode] is
  /// [VlcPlaylistLoopMode.none]. Throws [StateError] when no playlist is active.
  Future<bool> next({bool autoPlay = true});

  /// Moves to the previous playlist item.
  ///
  /// Returns `false` when there is no previous item and [playlistLoopMode] is
  /// [VlcPlaylistLoopMode.none]. Throws [StateError] when no playlist is active.
  Future<bool> previous({bool autoPlay = true});

  /// Loads the playlist item at [index].
  ///
  /// Throws [StateError] when no playlist is active.
  Future<void> jumpTo(int index, {bool autoPlay = true});

  /// Appends [source] to the active playlist.
  ///
  /// Throws [StateError] when no playlist is active.
  Future<void> addToPlaylist(VlcMediaSource source);

  /// Inserts [source] into the active playlist at [index].
  ///
  /// Throws [StateError] when no playlist is active.
  Future<void> insertIntoPlaylist(int index, VlcMediaSource source);

  /// Removes the playlist item at [index].
  ///
  /// Removing the current item loads the next valid item. If the removed item
  /// was the only item, playback stops and the playlist is cleared.
  Future<void> removeFromPlaylistAt(int index, {bool autoPlay = true});

  /// Clears the active playlist and stops playback when a player is attached.
  Future<void> clearPlaylist();

  /// Shuffles the active playlist.
  ///
  /// When [seed] is provided, the shuffle order is deterministic.
  Future<void> shufflePlaylist({int? seed});

  /// Starts or resumes playback.
  Future<void> play();

  /// Pauses playback.
  Future<void> pause();

  /// Stops playback.
  Future<void> stop();

  /// Seeks to [position].
  ///
  /// [position] must be non-negative.
  Future<void> seekTo(Duration position);

  /// Sets VLC volume.
  ///
  /// Values are clamped to VLC's `0..200` range.
  Future<void> setVolume(int volume);

  /// Sets playback speed.
  ///
  /// [speed] must be finite and greater than zero. `1.0` is normal speed.
  Future<void> setPlaybackSpeed(double speed);

  /// Changes how video is scaled inside the view, without recreating the
  /// native player. Called by `VlcPlayer` when its `fit` changes.
  Future<void> setFit(VlcVideoFit fit);

  /// Sets the audio playback delay.
  ///
  /// Positive values delay audio; negative values play audio earlier.
  Future<void> setAudioDelay(Duration delay);

  /// Sets the subtitle display delay.
  ///
  /// Positive values delay subtitles; negative values show subtitles earlier.
  Future<void> setSubtitleDelay(Duration delay);

  /// Captures the current video frame as PNG bytes.
  ///
  /// [width] and [height] must be positive when provided.
  Future<Uint8List> takeSnapshot({int? width, int? height});

  /// Returns selectable audio tracks for the current media.
  Future<List<VlcTrackDescription>> getAudioTracks();

  /// Selects an audio track by VLC track [id].
  ///
  /// Use an id returned by [getAudioTracks].
  Future<void> setAudioTrack(int id);

  /// Returns selectable embedded subtitle tracks for the current media.
  Future<List<VlcTrackDescription>> getSubtitleTracks();

  /// Selects an embedded subtitle track by VLC track [id].
  ///
  /// Use an id returned by [getSubtitleTracks].
  Future<void> setSubtitleTrack(int id);

  /// Disables subtitle rendering for the current media.
  Future<void> disableSubtitle();

  /// Adds and selects an external subtitle from [uri].
  ///
  /// [uri] can point to a local file or a remote subtitle URL supported by VLC.
  Future<void> addSubtitle(Uri uri);

  /// Returns metadata and discovered track details for the current media.
  Future<VlcMediaInfo> getMediaInfo();

  /// Returns runtime statistics for the current media session.
  Future<VlcMediaStats> getMediaStats();
}

const MethodChannel _methodChannel = MethodChannel('vlc_player');

class _VlcPlayerController extends VlcPlayerController
    implements VlcPlayerControllerInternals {
  _VlcPlayerController({
    VlcMediaSource? mediaSource,
    this.autoPlay = false,
    List<String> options = const <String>[],
    this.eventThrottleInterval,
  }) : options = List<String>.unmodifiable(options),
       super._() {
    if (eventThrottleInterval case final interval? when interval.isNegative) {
      throw ArgumentError.value(
        eventThrottleInterval,
        'eventThrottleInterval',
        'Must not be negative.',
      );
    }
    _pendingMediaSource = mediaSource;
    _pendingAutoPlay = autoPlay;
  }

  @override
  final bool autoPlay;

  @override
  final List<String> options;

  @override
  final Duration? eventThrottleInterval;

  int? _viewId;
  int? _textureId;
  VlcMediaSource? _pendingMediaSource;
  bool _pendingAutoPlay = false;
  List<VlcMediaSource> _playlist = const <VlcMediaSource>[];
  int? _playlistIndex;
  bool _playlistAutoAdvance = false;
  VlcPlaylistLoopMode _playlistLoopMode = VlcPlaylistLoopMode.none;
  StreamSubscription<Object?>? _eventsSubscription;
  Timer? _eventThrottleTimer;
  VlcPlayerValue? _pendingThrottledValue;
  bool _isDisposed = false;

  @override
  bool get isAttached => _viewId != null;

  @override
  List<VlcMediaSource> get playlist => _playlist;

  @override
  int? get playlistIndex => _playlistIndex;

  @override
  VlcPlaylistLoopMode get playlistLoopMode => _playlistLoopMode;

  @override
  VlcMediaSource? get currentMediaSource => _pendingMediaSource;

  @override
  bool get hasNext => switch (_playlistIndex) {
    final int index => index + 1 < _playlist.length,
    null => false,
  };

  @override
  bool get hasPrevious => switch (_playlistIndex) {
    final int index => index > 0,
    null => false,
  };

  /// Attaches this controller to a platform-view player instance.
  @override
  Future<void> attach(int viewId) async {
    _ensureNotDisposed();
    if (_viewId == viewId) {
      return;
    }

    final oldViewId = _viewId;
    _viewId = null;
    _textureId = null;
    await _eventsSubscription?.cancel();
    _eventsSubscription = null;
    _cancelPendingThrottledValue();
    if (oldViewId != null) {
      await _disposeNativeView(oldViewId);
    }
    if (_isDisposed) {
      await _disposeNativeView(viewId);
      throw StateError('The controller has been disposed.');
    }

    _viewId = viewId;
    _eventsSubscription = EventChannel(
      'vlc_player/events/$viewId',
    ).receiveBroadcastStream().listen(_handleEvent, onError: _handleEventError);

    final pendingMediaSource = _pendingMediaSource;
    if (pendingMediaSource != null) {
      await _setMedia(pendingMediaSource, autoPlay: _pendingAutoPlay);
      _ensureNotDisposed();
    }
  }

  /// Attaches this controller to a texture-backed player instance.
  @override
  @internal
  Future<int> attachTexturePlayer() async {
    _ensureNotDisposed();

    final existingTextureId = _textureId;
    if (_viewId != null && existingTextureId != null) {
      return existingTextureId;
    }

    final oldViewId = _viewId;
    _viewId = null;
    _textureId = null;
    await _eventsSubscription?.cancel();
    _eventsSubscription = null;
    _cancelPendingThrottledValue();
    if (oldViewId != null) {
      await _disposeNativeView(oldViewId);
    }
    _ensureNotDisposed();

    final response = await _invokeNativeMap('create', <String, Object?>{
      'options': options,
    });
    final viewId = (response?['viewId'] as num?)?.toInt();
    final textureId = (response?['textureId'] as num?)?.toInt();
    if (viewId == null || textureId == null) {
      throw StateError('vlc_player texture creation returned invalid data.');
    }
    if (_isDisposed) {
      await _disposeNativeView(viewId);
      throw StateError('The controller has been disposed.');
    }

    _viewId = viewId;
    _textureId = textureId;
    _eventsSubscription = EventChannel(
      'vlc_player/events/$viewId',
    ).receiveBroadcastStream().listen(_handleEvent, onError: _handleEventError);

    final pendingMediaSource = _pendingMediaSource;
    if (pendingMediaSource != null) {
      await _setMedia(pendingMediaSource, autoPlay: _pendingAutoPlay);
      _ensureNotDisposed();
    }

    return textureId;
  }

  /// Detaches and disposes the native player instance, if one is attached.
  @override
  @internal
  Future<void> detach() async {
    final viewId = _viewId;
    _viewId = null;
    _textureId = null;
    await _eventsSubscription?.cancel();
    _eventsSubscription = null;
    _cancelPendingThrottledValue();
    if (viewId != null) {
      await _disposeNativeView(viewId);
    }
  }

  @override
  Future<void> setMedia(VlcMediaSource source, {bool autoPlay = false}) async {
    _ensureNotDisposed();
    final previousPlaylist = _playlist;
    final previousPlaylistIndex = _playlistIndex;
    final previousPlaylistAutoAdvance = _playlistAutoAdvance;
    final previousPlaylistLoopMode = _playlistLoopMode;
    final previousMediaSource = _pendingMediaSource;
    final previousAutoPlay = _pendingAutoPlay;
    _clearPlaylist();
    try {
      await _setMedia(source, autoPlay: autoPlay);
    } catch (_) {
      _playlist = previousPlaylist;
      _playlistIndex = previousPlaylistIndex;
      _playlistAutoAdvance = previousPlaylistAutoAdvance;
      _playlistLoopMode = previousPlaylistLoopMode;
      _pendingMediaSource = previousMediaSource;
      _pendingAutoPlay = previousAutoPlay;
      rethrow;
    }
  }

  @override
  Future<void> setPlaylist(
    List<VlcMediaSource> sources, {
    int initialIndex = 0,
    bool autoPlay = false,
    bool autoAdvance = true,
    VlcPlaylistLoopMode loopMode = VlcPlaylistLoopMode.none,
  }) async {
    _ensureNotDisposed();
    if (sources.isEmpty) {
      throw ArgumentError.value(sources, 'sources', 'Must be non-empty.');
    }
    RangeError.checkValidIndex(initialIndex, sources, 'initialIndex');

    final previousPlaylist = _playlist;
    final previousPlaylistIndex = _playlistIndex;
    final previousPlaylistAutoAdvance = _playlistAutoAdvance;
    final previousPlaylistLoopMode = _playlistLoopMode;
    final previousMediaSource = _pendingMediaSource;
    final previousAutoPlay = _pendingAutoPlay;
    _playlist = List<VlcMediaSource>.unmodifiable(sources);
    _playlistIndex = initialIndex;
    _playlistAutoAdvance = autoAdvance;
    _playlistLoopMode = loopMode;
    try {
      await _setMedia(_playlist[initialIndex], autoPlay: autoPlay);
    } catch (_) {
      _playlist = previousPlaylist;
      _playlistIndex = previousPlaylistIndex;
      _playlistAutoAdvance = previousPlaylistAutoAdvance;
      _playlistLoopMode = previousPlaylistLoopMode;
      _pendingMediaSource = previousMediaSource;
      _pendingAutoPlay = previousAutoPlay;
      rethrow;
    }
  }

  @override
  Future<bool> next({bool autoPlay = true}) {
    return _moveInPlaylist(1, autoPlay: autoPlay);
  }

  @override
  Future<bool> previous({bool autoPlay = true}) {
    return _moveInPlaylist(-1, autoPlay: autoPlay);
  }

  @override
  Future<void> jumpTo(int index, {bool autoPlay = true}) async {
    _ensureActivePlaylist();
    RangeError.checkValidIndex(index, _playlist, 'index');
    if (index == _playlistIndex) {
      return;
    }
    await _loadPlaylistIndex(index, autoPlay: autoPlay);
  }

  @override
  Future<void> addToPlaylist(VlcMediaSource source) {
    return insertIntoPlaylist(_playlist.length, source);
  }

  @override
  Future<void> insertIntoPlaylist(int index, VlcMediaSource source) async {
    _ensureActivePlaylist();
    RangeError.checkValueInInterval(index, 0, _playlist.length, 'index');
    final currentIndex = _playlistIndex!;
    final nextPlaylist = <VlcMediaSource>[..._playlist]..insert(index, source);
    _playlist = List<VlcMediaSource>.unmodifiable(nextPlaylist);
    if (index <= currentIndex) {
      _playlistIndex = currentIndex + 1;
    }
  }

  @override
  Future<void> removeFromPlaylistAt(int index, {bool autoPlay = true}) async {
    _ensureActivePlaylist();
    RangeError.checkValidIndex(index, _playlist, 'index');

    final previousPlaylist = _playlist;
    final previousPlaylistIndex = _playlistIndex;
    final previousMediaSource = _pendingMediaSource;
    final previousAutoPlay = _pendingAutoPlay;
    final currentIndex = previousPlaylistIndex!;
    final nextPlaylist = <VlcMediaSource>[..._playlist]..removeAt(index);

    if (nextPlaylist.isEmpty) {
      await _stopIfAttached();
      _clearPlaylist();
      _pendingMediaSource = null;
      _pendingAutoPlay = false;
      return;
    }

    _playlist = List<VlcMediaSource>.unmodifiable(nextPlaylist);
    if (index < currentIndex) {
      _playlistIndex = currentIndex - 1;
      return;
    }
    if (index > currentIndex) {
      _playlistIndex = currentIndex;
      return;
    }

    final nextIndex = math.min(index, nextPlaylist.length - 1);
    _playlistIndex = nextIndex;
    try {
      await _setMedia(_playlist[nextIndex], autoPlay: autoPlay);
    } catch (_) {
      _playlist = previousPlaylist;
      _playlistIndex = previousPlaylistIndex;
      _pendingMediaSource = previousMediaSource;
      _pendingAutoPlay = previousAutoPlay;
      rethrow;
    }
  }

  @override
  Future<void> clearPlaylist() async {
    _ensureNotDisposed();
    if (_playlistIndex == null) {
      return;
    }
    await _stopIfAttached();
    _clearPlaylist();
    _pendingMediaSource = null;
    _pendingAutoPlay = false;
  }

  @override
  Future<void> shufflePlaylist({int? seed}) async {
    _ensureActivePlaylist();
    final currentSource = currentMediaSource;
    final random = seed == null ? math.Random() : math.Random(seed);
    final nextPlaylist = <VlcMediaSource>[..._playlist]..shuffle(random);
    _playlist = List<VlcMediaSource>.unmodifiable(nextPlaylist);
    _playlistIndex = currentSource == null
        ? 0
        : _playlist
              .indexOf(currentSource)
              .clamp(0, _playlist.length - 1)
              .toInt();
  }

  Future<bool> _moveInPlaylist(int delta, {required bool autoPlay}) async {
    _ensureActivePlaylist();
    final index = _playlistIndex!;

    final nextIndex = index + delta;
    if (nextIndex < 0 || nextIndex >= _playlist.length) {
      if (_playlistLoopMode != VlcPlaylistLoopMode.loopAll) {
        return false;
      }
      return _loadPlaylistIndex(
        nextIndex < 0 ? _playlist.length - 1 : 0,
        autoPlay: autoPlay,
      );
    }

    return _loadPlaylistIndex(nextIndex, autoPlay: autoPlay);
  }

  Future<bool> _loadPlaylistIndex(
    int nextIndex, {
    required bool autoPlay,
  }) async {
    final index = _playlistIndex;
    if (index == null) {
      throw StateError('No playlist has been set.');
    }

    _playlistIndex = nextIndex;
    final previousMediaSource = _pendingMediaSource;
    final previousAutoPlay = _pendingAutoPlay;
    try {
      await _setMedia(_playlist[nextIndex], autoPlay: autoPlay);
    } catch (_) {
      _playlistIndex = index;
      _pendingMediaSource = previousMediaSource;
      _pendingAutoPlay = previousAutoPlay;
      rethrow;
    }
    return true;
  }

  Future<void> _setMedia(
    VlcMediaSource source, {
    required bool autoPlay,
  }) async {
    _ensureNotDisposed();
    _pendingMediaSource = source;
    _pendingAutoPlay = autoPlay;

    final viewId = _viewId;
    if (viewId == null) {
      return;
    }

    await _invokeNative<void>(
      'setSource',
      _sourceArguments(viewId, source, autoPlay: autoPlay),
    );
  }

  void _clearPlaylist() {
    _playlist = const <VlcMediaSource>[];
    _playlistIndex = null;
    _playlistAutoAdvance = false;
    _playlistLoopMode = VlcPlaylistLoopMode.none;
  }

  void _ensureActivePlaylist() {
    _ensureNotDisposed();
    if (_playlistIndex == null) {
      throw StateError('No playlist has been set.');
    }
  }

  @override
  Future<void> play() => _invoke('play');

  @override
  Future<void> pause() => _invoke('pause');

  @override
  Future<void> stop() => _invoke('stop');

  @override
  Future<void> seekTo(Duration position) {
    if (position.isNegative) {
      throw ArgumentError.value(position, 'position', 'Must be non-negative.');
    }
    return _invoke('seekTo', <String, Object?>{
      'position': position.inMilliseconds,
    });
  }

  @override
  Future<void> setVolume(int volume) {
    return _invoke('setVolume', <String, Object?>{
      'volume': volume.clamp(0, 200),
    });
  }

  @override
  Future<void> setPlaybackSpeed(double speed) {
    if (!speed.isFinite || speed <= 0) {
      throw ArgumentError.value(
        speed,
        'speed',
        'Must be finite and greater than zero.',
      );
    }
    return _invoke('setPlaybackSpeed', <String, Object?>{'speed': speed});
  }

  @override
  Future<void> setFit(VlcVideoFit fit) {
    return _invoke('setFit', <String, Object?>{'fit': fit.name});
  }

  @override
  Future<void> setAudioDelay(Duration delay) {
    return _invoke('setAudioDelay', <String, Object?>{
      'delay': delay.inMicroseconds,
    });
  }

  @override
  Future<void> setSubtitleDelay(Duration delay) {
    return _invoke('setSubtitleDelay', <String, Object?>{
      'delay': delay.inMicroseconds,
    });
  }

  @override
  Future<Uint8List> takeSnapshot({int? width, int? height}) async {
    if (width != null && width <= 0) {
      throw ArgumentError.value(width, 'width', 'Must be positive.');
    }
    if (height != null && height <= 0) {
      throw ArgumentError.value(height, 'height', 'Must be positive.');
    }
    final data = await _invokeFor<Uint8List>('takeSnapshot', <String, Object?>{
      'width': ?width,
      'height': ?height,
    });
    if (data == null || data.isEmpty) {
      throw StateError('vlc_player snapshot returned no image data.');
    }
    return data;
  }

  @override
  Future<List<VlcTrackDescription>> getAudioTracks() async {
    final tracks = await _invokeFor<List<Object?>>('getAudioTracks');
    return _trackDescriptionsFrom(tracks);
  }

  @override
  Future<void> setAudioTrack(int id) {
    if (id < 0) {
      throw ArgumentError.value(id, 'id', 'Must be non-negative.');
    }
    return _invoke('setAudioTrack', <String, Object?>{'id': id});
  }

  @override
  Future<List<VlcTrackDescription>> getSubtitleTracks() async {
    final tracks = await _invokeFor<List<Object?>>('getSubtitleTracks');
    return _trackDescriptionsFrom(tracks);
  }

  @override
  Future<void> setSubtitleTrack(int id) {
    if (id < 0) {
      throw ArgumentError.value(id, 'id', 'Must be non-negative.');
    }
    return _invoke('setSubtitleTrack', <String, Object?>{'id': id});
  }

  @override
  Future<void> disableSubtitle() => _invoke('disableSubtitle');

  @override
  Future<void> addSubtitle(Uri uri) {
    final value = uri.toString();
    if (value.isEmpty) {
      throw ArgumentError.value(uri, 'uri', 'Must be non-empty.');
    }
    return _invoke('addSubtitle', <String, Object?>{'uri': value});
  }

  @override
  Future<VlcMediaInfo> getMediaInfo() async {
    final info = await _invokeFor<Map<Object?, Object?>>('getMediaInfo');
    return VlcMediaInfo.fromMap(info ?? const <Object?, Object?>{});
  }

  @override
  Future<VlcMediaStats> getMediaStats() async {
    final stats = await _invokeFor<Map<Object?, Object?>>('getMediaStats');
    return VlcMediaStats.fromMap(stats ?? const <Object?, Object?>{});
  }

  Future<void> _invoke(String method, [Map<String, Object?>? arguments]) {
    return _invokeFor<void>(method, arguments);
  }

  Future<T?> _invokeFor<T>(String method, [Map<String, Object?>? arguments]) {
    return _invokeNative<T>(method, _attachedArguments(arguments));
  }

  Future<void> _stopIfAttached() {
    if (_viewId == null) {
      return Future<void>.value();
    }
    return _invoke('stop');
  }

  Map<String, Object?> _attachedArguments([Map<String, Object?>? arguments]) {
    _ensureNotDisposed();
    final viewId = _viewId;
    if (viewId == null) {
      throw StateError('The controller is not attached to a VlcPlayer.');
    }

    return <String, Object?>{'viewId': viewId, ...?arguments};
  }

  Map<String, Object?> _sourceArguments(
    int viewId,
    VlcMediaSource source, {
    required bool autoPlay,
  }) {
    return <String, Object?>{
      'viewId': viewId,
      'uri': source.uri.toString(),
      'autoPlay': autoPlay,
      'httpHeaders': source.httpHeaders,
      if (source.mediaOptions.isNotEmpty) 'mediaOptions': source.mediaOptions,
      if (source.startPosition > Duration.zero)
        'startPosition': source.startPosition.inMilliseconds,
    };
  }

  Future<T?> _invokeNative<T>(String method, Map<String, Object?> arguments) {
    return _mapPlatformException(
      () => _methodChannel.invokeMethod<T>(method, arguments),
    );
  }

  Future<Map<String, Object?>?> _invokeNativeMap(
    String method,
    Map<String, Object?> arguments,
  ) {
    return _mapPlatformException(
      () => _methodChannel.invokeMapMethod<String, Object?>(method, arguments),
    );
  }

  static Future<T> _mapPlatformException<T>(
    Future<T> Function() operation,
  ) async {
    try {
      return await operation();
    } on PlatformException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        VlcPlayerException.fromPlatformException(error),
        stackTrace,
      );
    }
  }

  static List<VlcTrackDescription> _trackDescriptionsFrom(Object? value) {
    if (value is! Iterable) {
      return const <VlcTrackDescription>[];
    }
    return value
        .whereType<Map>()
        .map(
          (track) =>
              VlcTrackDescription.fromMap(track.cast<Object?, Object?>()),
        )
        .toList(growable: false);
  }

  Future<void> _disposeNativeView(int viewId) {
    return _methodChannel.invokeMethod<void>('dispose', <String, Object?>{
      'viewId': viewId,
    });
  }

  void _handleEvent(Object? event) {
    if (_isDisposed) {
      return;
    }
    final previousValue = _pendingThrottledValue ?? value;
    final nextValue = VlcPlayerValue.fromEvent(event, previousValue);
    _setValueFromEvent(previousValue, nextValue);
    if (_playlistAutoAdvance &&
        previousValue.state != VlcPlaybackState.ended &&
        nextValue.state == VlcPlaybackState.ended) {
      if (_playlistLoopMode == VlcPlaylistLoopMode.loopOne) {
        final current = _pendingMediaSource;
        if (current != null) {
          _runAutoAdvance(_setMedia(current, autoPlay: true));
        }
      } else if (hasNext || _playlistLoopMode == VlcPlaylistLoopMode.loopAll) {
        _runAutoAdvance(next().then<void>((_) {}));
      }
    }
  }

  void _runAutoAdvance(Future<void> operation) {
    unawaited(
      operation.catchError((Object error, StackTrace stackTrace) {
        _handleAutoAdvanceError(error);
      }),
    );
  }

  void _handleAutoAdvanceError(Object error) {
    if (_isDisposed) {
      return;
    }
    final playerError = error is VlcPlayerException
        ? error.error
        : error is PlatformException
        ? VlcPlayerError.fromPlatformException(error)
        : VlcPlayerError(
            code: VlcPlayerErrorCode.playbackError,
            message: error.toString(),
          );
    _setPlayerError(playerError);
  }

  void _handleEventError(Object error) {
    if (_isDisposed) {
      return;
    }
    final playerError = error is PlatformException
        ? VlcPlayerError.fromPlatformException(error)
        : VlcPlayerError(
            code: VlcPlayerErrorCode.eventChannelError,
            message: error.toString(),
          );
    _setPlayerError(playerError);
  }

  void _setPlayerError(VlcPlayerError playerError) {
    _cancelPendingThrottledValue();
    value = value.copyWith(
      state: VlcPlaybackState.error,
      error: playerError,
      errorDescription: playerError.message,
    );
  }

  void _setValueFromEvent(
    VlcPlayerValue previousValue,
    VlcPlayerValue nextValue,
  ) {
    if (nextValue == previousValue) {
      return;
    }
    if (!_shouldThrottleEvent(previousValue, nextValue)) {
      _setValueImmediately(nextValue);
      return;
    }
    _pendingThrottledValue = nextValue;
    _eventThrottleTimer ??= Timer(eventThrottleInterval!, _flushThrottledValue);
  }

  bool _shouldThrottleEvent(
    VlcPlayerValue previousValue,
    VlcPlayerValue nextValue,
  ) {
    final interval = eventThrottleInterval;
    if (interval == null || interval.inMicroseconds == 0) {
      return false;
    }
    return previousValue.state == nextValue.state &&
        previousValue.volume == nextValue.volume &&
        previousValue.playbackSpeed == nextValue.playbackSpeed &&
        previousValue.audioDelay == nextValue.audioDelay &&
        previousValue.subtitleDelay == nextValue.subtitleDelay &&
        previousValue.isReady == nextValue.isReady &&
        previousValue.isSeekable == nextValue.isSeekable &&
        previousValue.isLive == nextValue.isLive &&
        previousValue.videoSize == nextValue.videoSize &&
        previousValue.error == nextValue.error &&
        previousValue.errorDescription == nextValue.errorDescription;
  }

  void _setValueImmediately(VlcPlayerValue nextValue) {
    _cancelPendingThrottledValue();
    value = nextValue;
  }

  void _flushThrottledValue() {
    final pendingValue = _pendingThrottledValue;
    _eventThrottleTimer = null;
    _pendingThrottledValue = null;
    if (!_isDisposed && pendingValue != null) {
      value = pendingValue;
    }
  }

  void _cancelPendingThrottledValue() {
    _eventThrottleTimer?.cancel();
    _eventThrottleTimer = null;
    _pendingThrottledValue = null;
  }

  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw StateError('The controller has been disposed.');
    }
  }

  /// Disposes the controller and releases the attached native player.
  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    final viewId = _viewId;
    _viewId = null;
    _textureId = null;
    _eventsSubscription?.cancel();
    _eventsSubscription = null;
    _cancelPendingThrottledValue();
    if (viewId != null) {
      unawaited(_disposeNativeView(viewId));
    }
    super.dispose();
  }
}
