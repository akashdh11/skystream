import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

import 'vlc_player_error.dart';

/// Playback lifecycle states reported by the native VLC player.
enum VlcPlaybackState {
  /// No media is loaded.
  idle,

  /// VLC is opening the current media.
  opening,

  /// VLC is buffering enough data to continue playback.
  buffering,

  /// Media is currently playing.
  playing,

  /// Media playback is paused.
  paused,

  /// Playback has been stopped.
  stopped,

  /// The current media reached the end.
  ended,

  /// The player is in an error state.
  error,
}

/// Immutable snapshot of the native player state.
///
/// Listen to `VlcPlayerController` to receive updated values as VLC emits
/// playback events.
@immutable
class VlcPlayerValue {
  /// Creates a player value snapshot.
  const VlcPlayerValue({
    this.state = VlcPlaybackState.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 100,
    this.playbackSpeed = 1,
    this.audioDelay = Duration.zero,
    this.subtitleDelay = Duration.zero,
    this.isReady = false,
    this.isSeekable = false,
    this.isLive = false,
    this.videoSize,
    this.bufferingProgress,
    this.error,
    this.errorDescription,
  });

  /// Current playback lifecycle state.
  final VlcPlaybackState state;

  /// Current playback position.
  final Duration position;

  /// Current media duration, or [Duration.zero] when unknown.
  final Duration duration;

  /// Current VLC volume.
  ///
  /// VLC volume is generally represented as `0..200`, where `100` is normal
  /// volume.
  final int volume;

  /// Current playback speed multiplier.
  final double playbackSpeed;

  /// Current audio playback delay.
  ///
  /// Positive values delay audio; negative values play audio earlier.
  final Duration audioDelay;

  /// Current subtitle display delay.
  ///
  /// Positive values delay subtitles; negative values show subtitles earlier.
  final Duration subtitleDelay;

  /// Whether the native player has reached a playable active or terminal state.
  final bool isReady;

  /// Whether VLC reports that the current media can seek.
  final bool isSeekable;

  /// Whether the current media looks like a live stream.
  final bool isLive;

  /// Decoded video size when VLC exposes it.
  final Size? videoSize;

  /// Normalized buffering progress from `0.0` to `1.0`, when available.
  final double? bufferingProgress;

  /// Structured playback error when [state] is [VlcPlaybackState.error].
  final VlcPlayerError? error;

  /// Human-readable playback error text when available.
  final String? errorDescription;

  /// Whether [state] is [VlcPlaybackState.playing].
  bool get isPlaying => state == VlcPlaybackState.playing;

  /// Whether [state] is [VlcPlaybackState.buffering].
  bool get isBuffering => state == VlcPlaybackState.buffering;

  /// Whether [state] is [VlcPlaybackState.error].
  bool get hasError => state == VlcPlaybackState.error;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is VlcPlayerValue &&
        other.state == state &&
        other.position == position &&
        other.duration == duration &&
        other.volume == volume &&
        other.playbackSpeed == playbackSpeed &&
        other.audioDelay == audioDelay &&
        other.subtitleDelay == subtitleDelay &&
        other.isReady == isReady &&
        other.isSeekable == isSeekable &&
        other.isLive == isLive &&
        other.videoSize == videoSize &&
        other.bufferingProgress == bufferingProgress &&
        other.error == error &&
        other.errorDescription == errorDescription;
  }

  @override
  int get hashCode => Object.hash(
    state,
    position,
    duration,
    volume,
    playbackSpeed,
    audioDelay,
    subtitleDelay,
    isReady,
    isSeekable,
    isLive,
    videoSize,
    bufferingProgress,
    error,
    errorDescription,
  );

  /// Returns a copy with selected fields replaced.
  ///
  /// Set [clearVideoSize], [clearBufferingProgress], or [clearError] to remove
  /// nullable values that would otherwise be preserved from the current value.
  VlcPlayerValue copyWith({
    VlcPlaybackState? state,
    Duration? position,
    Duration? duration,
    int? volume,
    double? playbackSpeed,
    Duration? audioDelay,
    Duration? subtitleDelay,
    bool? isReady,
    bool? isSeekable,
    bool? isLive,
    Size? videoSize,
    bool clearVideoSize = false,
    double? bufferingProgress,
    bool clearBufferingProgress = false,
    VlcPlayerError? error,
    String? errorDescription,
    bool clearError = false,
  }) {
    final nextError = clearError
        ? null
        : error ??
              (errorDescription == null
                  ? this.error
                  : VlcPlayerError(
                      code: VlcPlayerErrorCode.playbackError,
                      message: errorDescription,
                    ));
    final nextErrorDescription = clearError
        ? null
        : error != null
        ? error.message
        : errorDescription ?? this.errorDescription;
    return VlcPlayerValue(
      state: state ?? this.state,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      audioDelay: audioDelay ?? this.audioDelay,
      subtitleDelay: subtitleDelay ?? this.subtitleDelay,
      isReady: isReady ?? this.isReady,
      isSeekable: isSeekable ?? this.isSeekable,
      isLive: isLive ?? this.isLive,
      videoSize: clearVideoSize ? null : videoSize ?? this.videoSize,
      bufferingProgress: clearBufferingProgress
          ? null
          : bufferingProgress ?? this.bufferingProgress,
      error: nextError,
      errorDescription: nextErrorDescription,
    );
  }

  /// Converts a native event-channel payload into a player value.
  ///
  /// Unknown or malformed events leave [previous] unchanged.
  static VlcPlayerValue fromEvent(Object? event, VlcPlayerValue previous) {
    if (event is! Map) {
      return previous;
    }

    final state =
        _stateFromString(_stringValue(event['state'])) ?? previous.state;
    final hasVideoSize = event.containsKey('videoSize');
    final videoSize = hasVideoSize ? _sizeFromMap(event['videoSize']) : null;
    final hasBufferingProgress = event.containsKey('bufferingProgress');
    final bufferingProgress = hasBufferingProgress
        ? _normalizedProgress(event['bufferingProgress'])
        : null;
    final error = _errorFromEvent(event);

    return previous.copyWith(
      state: state,
      position: _durationFromMilliseconds(event['position']),
      duration: _durationFromMilliseconds(event['duration']),
      volume: _intValue(event['volume']),
      playbackSpeed: _doubleValue(event['playbackSpeed']),
      audioDelay: _durationFromMicroseconds(event['audioDelay']),
      subtitleDelay: _durationFromMicroseconds(event['subtitleDelay']),
      isReady: _boolValue(event['isReady']) ?? _isReadyState(state),
      isSeekable: _boolValue(event['isSeekable']),
      isLive: _boolValue(event['isLive']),
      videoSize: videoSize,
      clearVideoSize:
          (hasVideoSize && videoSize == null) || _clearsVideoSize(state),
      bufferingProgress: bufferingProgress,
      clearBufferingProgress:
          (hasBufferingProgress && bufferingProgress == null) ||
          state != VlcPlaybackState.buffering,
      error: error,
      errorDescription: error?.message,
      clearError: error == null,
    );
  }

  static Duration? _durationFromMilliseconds(Object? value) {
    if (value is! num || value < 0 || !value.isFinite) {
      return null;
    }
    return Duration(milliseconds: value.round());
  }

  static Duration? _durationFromMicroseconds(Object? value) {
    if (value is! num || !value.isFinite) {
      return null;
    }
    return Duration(microseconds: value.round());
  }

  static Size? _sizeFromMap(Object? value) {
    if (value is! Map) {
      return null;
    }
    final width = _doubleValue(value['width']);
    final height = _doubleValue(value['height']);
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return Size(width, height);
  }

  static double? _normalizedProgress(Object? value) {
    if (value is! num || !value.isFinite) {
      return null;
    }
    return value.toDouble().clamp(0.0, 1.0).toDouble();
  }

  static VlcPlayerError? _errorFromEvent(Map<Object?, Object?> event) {
    final rawError = event['error'];
    if (rawError is Map) {
      return VlcPlayerError.fromMap(rawError.cast<Object?, Object?>());
    }

    final code = _stringValue(event['errorCode']);
    final description = _stringValue(event['errorDescription']);
    if (code == null && description == null) {
      return null;
    }
    return VlcPlayerError(
      code: code ?? VlcPlayerErrorCode.playbackError,
      message: description,
      details: event['errorDetails'],
    );
  }

  static bool _isReadyState(VlcPlaybackState state) {
    return switch (state) {
      VlcPlaybackState.playing ||
      VlcPlaybackState.paused ||
      VlcPlaybackState.stopped ||
      VlcPlaybackState.ended => true,
      _ => false,
    };
  }

  static bool _clearsVideoSize(VlcPlaybackState state) {
    return switch (state) {
      VlcPlaybackState.idle ||
      VlcPlaybackState.opening ||
      VlcPlaybackState.error => true,
      _ => false,
    };
  }

  static String? _stringValue(Object? value) => value is String ? value : null;

  static int? _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num && value.isFinite) {
      return value.round();
    }
    return null;
  }

  static double? _doubleValue(Object? value) {
    if (value is! num || !value.isFinite) {
      return null;
    }
    return value.toDouble();
  }

  static bool? _boolValue(Object? value) => value is bool ? value : null;

  static VlcPlaybackState? _stateFromString(String? value) {
    return switch (value) {
      'idle' => VlcPlaybackState.idle,
      'opening' => VlcPlaybackState.opening,
      'buffering' => VlcPlaybackState.buffering,
      'playing' => VlcPlaybackState.playing,
      'paused' => VlcPlaybackState.paused,
      'stopped' => VlcPlaybackState.stopped,
      'ended' => VlcPlaybackState.ended,
      'error' => VlcPlaybackState.error,
      _ => null,
    };
  }
}
