import 'package:flutter/foundation.dart';

/// Lightweight track description returned by track-selection APIs.
///
/// The [id] value is the native VLC track identifier and should be passed back
/// to methods such as `setAudioTrack` and `setSubtitleTrack`.
class VlcTrackDescription {
  /// Creates a track description.
  const VlcTrackDescription({
    required this.id,
    required this.name,
    this.language,
  });

  /// Creates a track description from a native platform map.
  factory VlcTrackDescription.fromMap(Map<Object?, Object?> map) {
    return VlcTrackDescription(
      id: _intValue(map['id']) ?? -1,
      name: _stringValue(map['name']) ?? '',
      language: _stringValue(map['language']),
    );
  }

  /// Native VLC track identifier.
  final int id;

  /// Human-readable track name reported by VLC.
  final String name;

  /// Optional ISO language code or language label reported by VLC.
  final String? language;

  @override
  bool operator ==(Object other) {
    return other is VlcTrackDescription &&
        other.id == id &&
        other.name == name &&
        other.language == language;
  }

  @override
  int get hashCode => Object.hash(id, name, language);
}

/// Metadata and discovered track information for the current media.
///
/// Values are best-effort and depend on what VLC can discover from the current
/// container, stream, and platform backend.
class VlcMediaInfo {
  /// Creates media information.
  const VlcMediaInfo({
    this.title,
    this.artist,
    this.album,
    this.duration = Duration.zero,
    this.videoTracks = const <VlcMediaTrackInfo>[],
    this.audioTracks = const <VlcMediaTrackInfo>[],
    this.subtitleTracks = const <VlcMediaTrackInfo>[],
  });

  /// Creates media information from a native platform map.
  factory VlcMediaInfo.fromMap(Map<Object?, Object?> map) {
    return VlcMediaInfo(
      title: _stringValue(map['title']),
      artist: _stringValue(map['artist']),
      album: _stringValue(map['album']),
      duration: _durationFromMilliseconds(map['duration']),
      videoTracks: _tracksFrom(map['videoTracks']),
      audioTracks: _tracksFrom(map['audioTracks']),
      subtitleTracks: _tracksFrom(map['subtitleTracks']),
    );
  }

  /// Media title when available.
  final String? title;

  /// Media artist when available.
  final String? artist;

  /// Media album when available.
  final String? album;

  /// Media duration reported by VLC, or [Duration.zero] when unknown.
  final Duration duration;

  /// Video tracks discovered in the current media.
  final List<VlcMediaTrackInfo> videoTracks;

  /// Audio tracks discovered in the current media.
  final List<VlcMediaTrackInfo> audioTracks;

  /// Subtitle tracks discovered in the current media.
  final List<VlcMediaTrackInfo> subtitleTracks;

  static List<VlcMediaTrackInfo> _tracksFrom(Object? value) {
    if (value is! Iterable) {
      return const <VlcMediaTrackInfo>[];
    }
    return value
        .whereType<Map>()
        .map(
          (track) => VlcMediaTrackInfo.fromMap(track.cast<Object?, Object?>()),
        )
        .toList(growable: false);
  }

  @override
  bool operator ==(Object other) {
    return other is VlcMediaInfo &&
        other.title == title &&
        other.artist == artist &&
        other.album == album &&
        other.duration == duration &&
        listEquals(other.videoTracks, videoTracks) &&
        listEquals(other.audioTracks, audioTracks) &&
        listEquals(other.subtitleTracks, subtitleTracks);
  }

  @override
  int get hashCode => Object.hash(
    title,
    artist,
    album,
    duration,
    Object.hashAll(videoTracks),
    Object.hashAll(audioTracks),
    Object.hashAll(subtitleTracks),
  );
}

/// Detailed information for a discovered media track.
///
/// Not every backend or container exposes every field. Missing values are
/// represented as `null`.
class VlcMediaTrackInfo {
  /// Creates media track information.
  const VlcMediaTrackInfo({
    required this.type,
    this.codec,
    this.language,
    this.bitrate,
    this.width,
    this.height,
    this.channels,
    this.sampleRate,
  });

  /// Creates media track information from a native platform map.
  factory VlcMediaTrackInfo.fromMap(Map<Object?, Object?> map) {
    return VlcMediaTrackInfo(
      type: _stringValue(map['type']) ?? 'unknown',
      codec: _stringValue(map['codec']),
      language: _stringValue(map['language']),
      bitrate: _intValue(map['bitrate']),
      width: _intValue(map['width']),
      height: _intValue(map['height']),
      channels: _intValue(map['channels']),
      sampleRate: _intValue(map['sampleRate']),
    );
  }

  /// Track type such as `video`, `audio`, `subtitle`, or `unknown`.
  final String type;

  /// Codec name or identifier reported by VLC.
  final String? codec;

  /// Optional ISO language code or language label reported by VLC.
  final String? language;

  /// Track bitrate in bits per second when available.
  final int? bitrate;

  /// Video width in pixels when available.
  final int? width;

  /// Video height in pixels when available.
  final int? height;

  /// Audio channel count when available.
  final int? channels;

  /// Audio sample rate in hertz when available.
  final int? sampleRate;

  @override
  bool operator ==(Object other) {
    return other is VlcMediaTrackInfo &&
        other.type == type &&
        other.codec == codec &&
        other.language == language &&
        other.bitrate == bitrate &&
        other.width == width &&
        other.height == height &&
        other.channels == channels &&
        other.sampleRate == sampleRate;
  }

  @override
  int get hashCode => Object.hash(
    type,
    codec,
    language,
    bitrate,
    width,
    height,
    channels,
    sampleRate,
  );
}

Duration _durationFromMilliseconds(Object? value) {
  final milliseconds = _intValue(value);
  if (milliseconds == null || milliseconds < 0) {
    return Duration.zero;
  }
  return Duration(milliseconds: milliseconds);
}

String? _stringValue(Object? value) => value is String ? value : null;

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num && value.isFinite) {
    return value.toInt();
  }
  return null;
}
