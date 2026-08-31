import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/core/router/app_router.dart';
import 'package:skystream/features/explore/presentation/view_all_screen.dart';

void main() {
  group('RouteExtraCodec', () {
    const codec = RouteExtraCodec();

    test('roundtrips DetailsRouteExtra correctly', () {
      final original = DetailsRouteExtra(
        item: MultimediaItem(
          title: 'Inception',
          url: 'https://example.com/item/1',
          posterUrl: 'https://example.com/poster.jpg',
          provider: 'TestProvider',
          contentType: MultimediaContentType.movie,
        ),
        autoPlay: true,
      );

      final encoded = codec.encode(original);
      expect(encoded, isA<Map<String, dynamic>>());

      final decoded = codec.decode(encoded);
      expect(decoded, isA<DetailsRouteExtra>());
      final extra = decoded as DetailsRouteExtra;
      expect(extra.item.title, equals('Inception'));
      expect(extra.item.url, equals('https://example.com/item/1'));
      expect(extra.item.provider, equals('TestProvider'));
      expect(extra.item.contentType, equals(MultimediaContentType.movie));
      expect(extra.autoPlay, isTrue);
    });

    test('roundtrips PlayerRouteExtra with episode and preloadedStreams', () {
      final original = PlayerRouteExtra(
        item: MultimediaItem(
          title: 'Breaking Bad',
          url: 'https://example.com/series/1',
          posterUrl: 'https://example.com/bb.jpg',
          provider: 'TestProvider',
          contentType: MultimediaContentType.series,
        ),
        videoUrl: 'https://example.com/video.mp4',
        episode: Episode(
          name: 'Pilot',
          url: 'https://example.com/s1e1',
          season: 1,
          episode: 1,
        ),
        preloadedStreams: const [
          StreamResult(
            url: 'https://example.com/stream1.m3u8',
            source: '1080p HLS',
            providerName: 'ProviderA',
          ),
        ],
      );

      final encoded = codec.encode(original);
      expect(encoded, isA<Map<String, dynamic>>());

      final decoded = codec.decode(encoded);
      expect(decoded, isA<PlayerRouteExtra>());
      final extra = decoded as PlayerRouteExtra;
      expect(extra.item.title, equals('Breaking Bad'));
      expect(extra.videoUrl, equals('https://example.com/video.mp4'));
      expect(extra.episode?.name, equals('Pilot'));
      expect(extra.episode?.season, equals(1));
      expect(extra.episode?.episode, equals(1));
      expect(extra.preloadedStreams?.length, equals(1));
      expect(extra.preloadedStreams?.first.url, equals('https://example.com/stream1.m3u8'));
      expect(extra.preloadedStreams?.first.source, equals('1080p HLS'));
      expect(extra.preloadedStreams?.first.providerName, equals('ProviderA'));
    });

    test('roundtrips PlayerRouteExtra with null episode and null preloadedStreams', () {
      final original = PlayerRouteExtra(
        item: MultimediaItem(
          title: 'Movie',
          url: 'https://example.com/movie/1',
          posterUrl: '',
        ),
        videoUrl: 'https://example.com/movie.mp4',
      );

      final encoded = codec.encode(original);
      final decoded = codec.decode(encoded) as PlayerRouteExtra;
      expect(decoded.item.title, equals('Movie'));
      expect(decoded.videoUrl, equals('https://example.com/movie.mp4'));
      expect(decoded.episode, isNull);
      expect(decoded.preloadedStreams, isNull);
    });

    test('roundtrips ViewAllRouteExtra correctly', () {
      final original = ViewAllRouteExtra(
        title: 'Trending Movies',
        initialMediaList: [
          MultimediaItem(title: 'Movie 1', url: 'https://example.com/1', posterUrl: ''),
          MultimediaItem(title: 'Movie 2', url: 'https://example.com/2', posterUrl: ''),
        ],
        category: ViewAllCategory.popularMovies,
      );

      final encoded = codec.encode(original);
      final decoded = codec.decode(encoded) as ViewAllRouteExtra;
      expect(decoded.title, equals('Trending Movies'));
      expect(decoded.initialMediaList.length, equals(2));
      expect(decoded.initialMediaList[0].title, equals('Movie 1'));
      expect(decoded.initialMediaList[1].title, equals('Movie 2'));
      expect(decoded.category, equals(ViewAllCategory.popularMovies));
      expect(decoded.onTap, isNull);
    });

    test('passes through null and primitives unchanged', () {
      expect(codec.encode(null), isNull);
      expect(codec.decode(null), isNull);
      expect(codec.encode('plain_string'), equals('plain_string'));
      expect(codec.decode('plain_string'), equals('plain_string'));
      expect(codec.encode(123), equals(123));
      expect(codec.decode(123), equals(123));
    });
  });
}
