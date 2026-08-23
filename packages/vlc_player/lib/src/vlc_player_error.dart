import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Stable error code strings used by [VlcPlayerError].
abstract final class VlcPlayerErrorCode {
  /// Invalid arguments were sent to the native player.
  static const String invalidArgs = 'invalid_args';

  /// A command targeted a player instance that no longer exists.
  static const String playerNotFound = 'player_not_found';

  /// Native player creation failed.
  static const String createFailed = 'create_failed';

  /// Loading a media source failed.
  static const String setSourceFailed = 'set_source_failed';

  /// The requested audio or subtitle track could not be found.
  static const String trackNotFound = 'track_not_found';

  /// Adding an external subtitle failed.
  static const String addSubtitleFailed = 'add_subtitle_failed';

  /// VLC reported a playback failure.
  static const String playbackError = 'playback_error';

  /// A command was sent after the native player had been disposed.
  static const String disposed = 'disposed';

  /// The native event channel reported an error.
  static const String eventChannelError = 'event_channel_error';
}

/// Structured player error information.
///
/// Native platform failures are converted to this type before being surfaced
/// through [VlcPlayerException] or `VlcPlayerValue.error`.
@immutable
class VlcPlayerError {
  /// Creates a player error with a stable [code].
  const VlcPlayerError({required this.code, this.message, this.details});

  /// Creates a player error from a native platform map.
  factory VlcPlayerError.fromMap(Map<Object?, Object?> map) {
    return VlcPlayerError(
      code: _stringValue(map['code']) ?? VlcPlayerErrorCode.playbackError,
      message: _stringValue(map['message']),
      details: map['details'],
    );
  }

  /// Creates a player error from a [PlatformException].
  factory VlcPlayerError.fromPlatformException(PlatformException error) {
    return VlcPlayerError(
      code: error.code,
      message: error.message,
      details: error.details,
    );
  }

  /// Stable machine-readable error code.
  final String code;

  /// Human-readable error message when provided by the native backend.
  final String? message;

  /// Additional platform-specific error details.
  final Object? details;

  /// User-facing description, falling back to [code] when [message] is absent.
  String get description => message ?? code;

  @override
  bool operator ==(Object other) {
    return other is VlcPlayerError &&
        other.code == code &&
        other.message == message &&
        _deepEquals(other.details, details);
  }

  @override
  int get hashCode => Object.hash(code, message, _deepHash(details));

  @override
  String toString() {
    final message = this.message;
    if (message == null || message.isEmpty) {
      return 'VlcPlayerError($code)';
    }
    return 'VlcPlayerError($code, $message)';
  }

  static String? _stringValue(Object? value) => value is String ? value : null;

  static bool _deepEquals(Object? first, Object? second) {
    if (identical(first, second)) {
      return true;
    }
    if (first is Map && second is Map) {
      if (first.length != second.length) {
        return false;
      }
      for (final key in first.keys) {
        if (!second.containsKey(key) || !_deepEquals(first[key], second[key])) {
          return false;
        }
      }
      return true;
    }
    if (first is List && second is List) {
      if (first.length != second.length) {
        return false;
      }
      for (var index = 0; index < first.length; index += 1) {
        if (!_deepEquals(first[index], second[index])) {
          return false;
        }
      }
      return true;
    }
    return first == second;
  }

  static int _deepHash(Object? value) {
    if (value is Map) {
      return Object.hashAllUnordered(
        value.entries.map(
          (entry) => Object.hash(entry.key, _deepHash(entry.value)),
        ),
      );
    }
    if (value is List) {
      return Object.hashAll(value.map(_deepHash));
    }
    return value.hashCode;
  }
}

/// Exception thrown when a native player command fails.
class VlcPlayerException implements Exception {
  /// Creates an exception from a structured [error].
  const VlcPlayerException(this.error);

  /// Converts a [PlatformException] into a [VlcPlayerException].
  factory VlcPlayerException.fromPlatformException(PlatformException error) {
    return VlcPlayerException(VlcPlayerError.fromPlatformException(error));
  }

  /// Structured player error.
  final VlcPlayerError error;

  /// Stable machine-readable error code.
  String get code => error.code;

  /// Human-readable error message when available.
  String? get message => error.message;

  /// Additional platform-specific error details.
  Object? get details => error.details;

  @override
  String toString() => 'VlcPlayerException(${error.description})';
}
