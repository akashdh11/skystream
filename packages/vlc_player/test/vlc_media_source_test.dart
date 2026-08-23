import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_player/vlc_player.dart';

void main() {
  group('VlcMediaSource', () {
    test('keeps immutable snapshots of headers and media options', () {
      final headers = <String, String>{'Authorization': 'Bearer one'};
      final options = <String>[':network-caching=1000'];
      final source = VlcMediaSource(
        uri: Uri.parse('https://example.com/video.mp4'),
        httpHeaders: headers,
        mediaOptions: options,
        startPosition: const Duration(seconds: 12),
      );

      headers['Authorization'] = 'Bearer two';
      options.add(':file-caching=1000');

      expect(source.uri, Uri.parse('https://example.com/video.mp4'));
      expect(source.httpHeaders, <String, String>{
        'Authorization': 'Bearer one',
      });
      expect(source.mediaOptions, <String>[':network-caching=1000']);
      expect(source.startPosition, const Duration(seconds: 12));
      expect(
        () => source.httpHeaders['X-Test'] = 'value',
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => source.mediaOptions.add(':no-video-title-show'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('rejects empty uri', () {
      expect(() => VlcMediaSource(uri: Uri()), throwsA(isA<ArgumentError>()));
    });

    test('rejects negative start position', () {
      expect(
        () => VlcMediaSource(
          uri: Uri.parse('https://example.com/video.mp4'),
          startPosition: const Duration(milliseconds: -1),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('compares by value', () {
      final first = VlcMediaSource(
        uri: Uri.parse('https://example.com/video.mp4'),
        httpHeaders: const <String, String>{
          'Authorization': 'Bearer one',
          'X-Trace': 'abc',
        },
        mediaOptions: const <String>[':network-caching=1000'],
        startPosition: const Duration(seconds: 3),
      );
      final second = VlcMediaSource(
        uri: Uri.parse('https://example.com/video.mp4'),
        httpHeaders: const <String, String>{
          'X-Trace': 'abc',
          'Authorization': 'Bearer one',
        },
        mediaOptions: const <String>[':network-caching=1000'],
        startPosition: const Duration(seconds: 3),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('formats source details for diagnostics', () {
      final source = VlcMediaSource(
        uri: Uri.parse('https://example.com/video.mp4'),
        httpHeaders: const <String, String>{'Authorization': 'Bearer token'},
        mediaOptions: const <String>[':network-caching=1000'],
        startPosition: const Duration(seconds: 3),
      );

      expect(
        source.toString(),
        'VlcMediaSource(uri: https://example.com/video.mp4, '
        'httpHeaders: {Authorization: Bearer token}, '
        'mediaOptions: [:network-caching=1000], '
        'startPosition: 0:00:03.000000)',
      );
    });
  });
}
