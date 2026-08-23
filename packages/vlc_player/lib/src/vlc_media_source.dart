import 'package:flutter/foundation.dart';

/// Describes one media item before it is loaded into VLC.
///
/// Use this instead of a bare [Uri] when the item needs request headers, VLC
/// media options, or an initial seek position. Supported URI schemes and
/// container/codec combinations are ultimately determined by the native VLC
/// build used on the target platform.
@immutable
class VlcMediaSource {
  /// Creates a media source for [uri].
  ///
  /// [uri] must be non-empty. [httpHeaders] are sent when VLC opens HTTP(S)
  /// media. [mediaOptions] are passed to VLC for this source only; use VLC
  /// option syntax such as `:network-caching=1200`. [startPosition] must be
  /// non-negative and is applied after the source is loaded when the platform
  /// backend supports seeking.
  VlcMediaSource({
    required this.uri,
    Map<String, String> httpHeaders = const <String, String>{},
    List<String> mediaOptions = const <String>[],
    this.startPosition = Duration.zero,
  }) : httpHeaders = Map<String, String>.unmodifiable(httpHeaders),
       mediaOptions = List<String>.unmodifiable(mediaOptions) {
    if (uri.toString().isEmpty) {
      throw ArgumentError.value(uri, 'uri', 'Must be non-empty.');
    }
    if (startPosition.isNegative) {
      throw ArgumentError.value(
        startPosition,
        'startPosition',
        'Must be non-negative.',
      );
    }
  }

  /// Media URI to load.
  final Uri uri;

  /// HTTP headers used when opening [uri].
  final Map<String, String> httpHeaders;

  /// VLC media options applied only to this source.
  final List<String> mediaOptions;

  /// Initial playback position requested after loading this source.
  final Duration startPosition;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VlcMediaSource &&
            other.uri == uri &&
            mapEquals(other.httpHeaders, httpHeaders) &&
            listEquals(other.mediaOptions, mediaOptions) &&
            other.startPosition == startPosition;
  }

  @override
  int get hashCode => Object.hash(
    uri,
    Object.hashAll(_sortedHeaderHashes),
    Object.hashAll(mediaOptions),
    startPosition,
  );

  Iterable<int> get _sortedHeaderHashes {
    final keys = httpHeaders.keys.toList()..sort();
    return keys.map((key) => Object.hash(key, httpHeaders[key]));
  }

  @override
  String toString() {
    return 'VlcMediaSource(uri: $uri, httpHeaders: $httpHeaders, '
        'mediaOptions: $mediaOptions, startPosition: $startPosition)';
  }
}
