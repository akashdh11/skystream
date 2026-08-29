import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart'
    show ProviderListenable;
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/core/extensions/extension_manager.dart';
import 'package:skystream/features/library/presentation/history_provider.dart';
import 'package:skystream/features/player/domain/stream_resolver.dart';
import 'package:skystream/features/settings/presentation/player_settings_provider.dart';

/// A provider reader backed by a fixed table, so the resolver can be exercised
/// without a container. Reading anything not listed is a failure rather than a
/// null, which keeps the tests honest about what the resolver actually touches.
ProviderReader readerOf(List<(Object, Object?)> entries) {
  return <T>(ProviderListenable<T> provider) {
    for (final (key, value) in entries) {
      if (identical(key, provider)) return value as T;
    }
    throw StateError('resolver read an unstubbed provider: $provider');
  };
}

MultimediaItem itemWith({String? provider}) => MultimediaItem(
  title: 'Test Movie',
  url: 'https://example.com/title/1',
  posterUrl: '',
  provider: provider,
);

StreamResult streamAt(String url, String source) =>
    StreamResult(url: url, source: source, providerName: 'Plugin');

void main() {
  final defaults = <(Object, Object?)>[
    (activeProviderProvider, null),
    (playerSettingsProvider, const AsyncValue<PlayerSettings>.data(
      PlayerSettings(),
    )),
    (watchHistoryProvider, const <HistoryItem>[]),
  ];

  group('resolvePlayback', () {
    // The bug this whole file exists for: PlayerRouteExtra.videoUrl is a plugin
    // resolution token, and plugins are free to make it a JSON array. Phase 5
    // called Uri.parse on it and threw FormatException before playback began.
    test('a videoUrl that is not a URI resolves via the streams', () async {
      const token =
          '[{"source":"https://cdn.example/480.mp4","quality":"480p"},'
          '{"source":"https://cdn.example/720.mp4","quality":"720p"}]';

      final resolved = await resolvePlayback(
        read: readerOf(defaults),
        item: itemWith(),
        videoUrl: token,
        preloadedStreams: [
          streamAt('https://cdn.example/480.mp4', '480p'),
          streamAt('https://cdn.example/720.mp4', '720p'),
        ],
        probeCandidates: 0,
      );

      expect(resolved.streams, hasLength(2));
      expect(resolved.selected.url, isNot(token));
      expect(Uri.parse(resolved.selected.url).hasScheme, isTrue);
    });

    test('local playback needs no provider and no plugin call', () async {
      final resolved = await resolvePlayback(
        read: readerOf(defaults),
        item: itemWith(provider: 'Local'),
        videoUrl: '/Users/me/Movies/movie.mkv',
        probeCandidates: 0,
      );

      expect(resolved.streams, hasLength(1));
      expect(resolved.selected.url, '/Users/me/Movies/movie.mkv');
      expect(resolved.selected.source, 'Video');
    });

    test('a torrent resolves to a torrent stream rather than a plugin call',
        () async {
      final resolved = await resolvePlayback(
        read: readerOf(defaults),
        item: itemWith(),
        videoUrl: 'magnet:?xt=urn:btih:abc',
        probeCandidates: 0,
      );

      expect(resolved.selected.source, 'Torrent');
    });

    test('no provider and nothing preloaded fails with a message', () async {
      expect(
        () => resolvePlayback(
          read: readerOf(defaults),
          item: itemWith(),
          videoUrl: 'https://example.com/episode/1',
          probeCandidates: 0,
        ),
        throwsA(
          isA<StreamResolutionException>().having(
            (e) => e.message,
            'message',
            'No provider selected.',
          ),
        ),
      );
    });
  });

  group('isLiveSource', () {
    MultimediaItem itemOf(MultimediaContentType type) => MultimediaItem(
      title: 'T',
      url: 'https://example.com/t',
      posterUrl: '',
      contentType: type,
    );

    test('a livestream item is live whatever the url looks like', () {
      expect(
        isLiveSource(
          itemOf(MultimediaContentType.livestream),
          'https://cdn.example/channel.m3u8',
        ),
        isTrue,
      );
    });

    test('live protocols are live even on a movie item', () {
      for (final url in const [
        'rtmp://a/b',
        'rtsp://a/b',
        'mms://a/b',
        'udp://a/b',
        'rtp://a/b',
      ]) {
        expect(isLiveSource(itemOf(MultimediaContentType.movie), url), isTrue,
            reason: url);
      }
    });

    test('a plain http movie is not live', () {
      expect(
        isLiveSource(itemOf(MultimediaContentType.movie), 'https://a/b.mp4'),
        isFalse,
      );
    });

    // However the item is labelled, these are files and seek normally.
    test('torrents and local files are never live', () {
      final live = itemOf(MultimediaContentType.livestream);
      expect(isLiveSource(live, 'magnet:?xt=urn:btih:abc'), isFalse);
      expect(isLiveSource(live, 'https://a/b.torrent'), isFalse);
      expect(isLiveSource(live, '/Users/me/Movies/a.mkv'), isFalse);
    });

    test('an empty url falls back to the content type', () {
      expect(isLiveSource(itemOf(MultimediaContentType.livestream), ''), isTrue);
      expect(isLiveSource(itemOf(MultimediaContentType.movie), ''), isFalse);
    });
  });

  group('isTorrentSource', () {
    StreamResult s(String url, String source) =>
        StreamResult(url: url, source: source);

    test('magnet links and .torrent files need the torrent service', () {
      expect(isTorrentSource(s('magnet:?xt=urn:btih:abc', 'Torrent')), isTrue);
      expect(isTorrentSource(s('https://a/b.torrent', 'Torrent')), isTrue);
    });

    test('an ordinary http stream does not', () {
      expect(isTorrentSource(s('https://cdn.example/a.mp4', '1080p')), isFalse);
    });

    // A bare absolute path is normally a local file; only a torrent-sourced
    // one is a seeded file the service already knows about.
    test('a bare path counts only when the source says Torrent', () {
      expect(isTorrentSource(s('/downloads/movie.mkv', 'Torrent')), isTrue);
      expect(isTorrentSource(s('/Users/me/Movies/a.mkv', 'Video')), isFalse);
    });
  });
}
