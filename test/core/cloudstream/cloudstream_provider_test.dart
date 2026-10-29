/// A CloudStream provider's pure parts: how episode data travels through SkyStream, how links are
/// labelled, how CloudStream's types map to SkyStream's, and the provider ids.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cs3_engine/cs3_engine.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/cloudstream/cloudstream_engine.dart';
import 'package:skystream/core/cloudstream/cloudstream_models.dart';
import 'package:skystream/core/cloudstream/cloudstream_provider.dart';
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/core/extensions/base_provider.dart';
import 'package:skystream/core/services/ani_zip_service.dart';
import 'package:skystream/core/utils/stream_quality_sorter.dart';
import 'package:skystream/features/settings/presentation/player_settings_provider.dart';

void main() {
  group('episode tokens', () {
    test('carry any data there and back', () {
      for (final data in ['/watch/1', '{"id": 1, "ep": "ü 🎬"}', 'https://x.test/a?b=c&d=e', '']) {
        final token = CloudStreamProvider.token(data);
        expect(token, startsWith('cs3data:'));
        expect(CloudStreamProvider.decodeToken(token), (data: data, torrent: false));
      }
    });

    test('mark torrents', () {
      final token = CloudStreamProvider.token('magnet:?xt=urn:btih:abc', torrent: true);
      expect(token, startsWith('cs3torrent:'));
      expect(CloudStreamProvider.decodeToken(token), (data: 'magnet:?xt=urn:btih:abc', torrent: true));
    });

    test('leave anything else as it is', () {
      expect(CloudStreamProvider.decodeToken('https://x.test/1'), (data: 'https://x.test/1', torrent: false));
    });
  });

  group('link labels', () {
    test('add a known quality', () {
      expect(CloudStreamProvider.label({'name': 'Server', 'quality': 1080}), 'Server · 1080p');
    });

    test('leave out unknown qualities and ones already named', () {
      expect(CloudStreamProvider.label({'name': 'Server', 'quality': 400}), 'Server');
      expect(CloudStreamProvider.label({'name': 'Server', 'quality': 0}), 'Server');
      expect(CloudStreamProvider.label({'name': 'Server 720p', 'quality': 720}), 'Server 720p');
    });

    test('fall back to the source when there is no name', () {
      expect(CloudStreamProvider.label({'name': '  ', 'source': 'Mirror'}), 'Mirror');
      expect(CloudStreamProvider.label({}), 'Link');
    });
  });

  test('CloudStream types map to SkyStream content types', () {
    expect(CloudStreamProvider.contentType('TvSeries'), MultimediaContentType.series);
    expect(CloudStreamProvider.contentType('AsianDrama'), MultimediaContentType.series);
    expect(CloudStreamProvider.contentType('Anime'), MultimediaContentType.anime);
    expect(CloudStreamProvider.contentType('Live'), MultimediaContentType.livestream);
    expect(CloudStreamProvider.contentType('AnimeMovie'), MultimediaContentType.movie);
    expect(CloudStreamProvider.contentType('Others'), MultimediaContentType.other);
    expect(CloudStreamProvider.contentType(null), MultimediaContentType.other);
  });

  test('provider ids name the plugin, repository included, and are recognised', () {
    final id = CloudStreamProvider.idFor('0a1b2c3d4e/Megakino', 'Megakino');
    expect(id, 'cs3:0a1b2c3d4e/Megakino/Megakino');
    expect(CloudStreamProvider.isCloudStreamId(id), isTrue);
    expect(CloudStreamProvider.isCloudStreamId('com.example.plugin'), isFalse);
    expect(CloudStreamProvider.isCloudStreamId(null), isFalse);
  });

  group("a Play an extension's full-screen window took", () {
    CloudStreamProvider provider(Map<String, dynamic> answer) => CloudStreamProvider(
      plugin: const CsInstalledPlugin(
        info: CsPluginInfo(internalName: 'Pokemon', name: 'Pokemon', url: '', repositoryUrl: ''),
        filePath: '/plugins/Pokemon.cs3',
      ),
      pluginKey: 'ayu/Pokemon',
      info: const CsProviderInfo(name: 'Pokemon'),
      host: _AnsweringHost(answer),
    );

    test('ends quietly when it left no links', () {
      expect(
        provider({'links': <Object?>[], 'subtitles': <Object?>[], 'completed': true, 'fullScreen': true})
            .loadStreams(CloudStreamProvider.token('pokemon')),
        throwsA(isA<ExtensionScreenEnded>()),
      );
    });

    test('plays what it left otherwise, and an empty answer of no full-screen window stays empty', () async {
      final links = await provider({
        'links': [
          {'url': 'https://cdn.test/a.m3u8', 'name': 'A'},
        ],
        'fullScreen': true,
      }).loadStreams(CloudStreamProvider.token('x'));
      expect(links.single.url, 'https://cdn.test/a.m3u8');
      expect(await provider({'links': <Object?>[]}).loadStreams(CloudStreamProvider.token('x')), isEmpty);
    });
  });

  group('an HLS link with no quality of its own', () {
    CloudStreamProvider provider(Map<String, dynamic> answer) => CloudStreamProvider(
      plugin: const CsInstalledPlugin(
        info: CsPluginInfo(internalName: 'Arte', name: 'Arte', url: '', repositoryUrl: ''),
        filePath: '/plugins/Arte.cs3',
      ),
      pluginKey: 'german/Arte',
      info: const CsProviderInfo(name: 'Arte'),
      host: _AnsweringHost(answer),
    );

    test('is adaptive, so it ranks and plays as a master does', () async {
      final links = await provider({
        'links': [
          {'url': 'https://cdn.test/master.m3u8', 'name': 'Server', 'quality': 400, 'type': 'M3U8'},
          {'url': 'https://cdn.test/720.m3u8', 'name': 'Server', 'quality': 720, 'type': 'M3U8'},
          {'url': 'https://cdn.test/film.mp4', 'name': 'Server', 'quality': 400, 'type': 'VIDEO'},
        ],
      }).loadStreams(CloudStreamProvider.token('x'));
      expect([for (final link in links) link.quality], [0, null, null]);
      expect(links[1].source, 'Server · 720p', reason: 'a known quality is in the label, as before');
    });

    test('whose name states a quality keeps it, and ranks by it as before', () async {
      final links = await provider({
        'links': [
          {'url': 'https://cdn.test/360/index.m3u8', 'name': 'Vidplay 360p', 'quality': 400, 'type': 'M3U8'},
          {'url': 'https://cdn.test/hd/index.m3u8', 'name': 'Upcloud HD', 'quality': 400, 'type': 'M3U8'},
          {'url': 'https://cdn.test/720.mp4', 'name': 'Server', 'quality': 720, 'type': 'VIDEO'},
        ],
      }).loadStreams(CloudStreamProvider.token('x'));
      expect([for (final link in links) link.quality], [null, null, null]);
      expect(
        [for (final link in sortStreamsByQuality(links, QualityPreference.q1080)) link.source],
        ['Upcloud HD', 'Server · 720p', 'Vidplay 360p'],
        reason: 'not adaptive: a 360p playlist does not jump ahead of 720p',
      );
    });
  });

  group('details', () {
    // A title as the engine's `load` sends it (engine Mappers.loadResponse).
    Map<String, dynamic> anime() => {
      'name': 'Frieren',
      'url': 'https://ext.test/frieren',
      'type': 'Anime',
      'plot': 'A journey &amp; its end.',
      'posterUrl': 'https://img.test/poster.jpg',
      'backgroundPosterUrl': 'https://img.test/back.jpg',
      'year': 2023,
      'tags': ['Adventure', 'Fantasy'],
      'duration': 24,
      'score': 8.81,
      'contentRating': 'PG-13',
      'logoUrl': 'https://img.test/logo.png',
      'posterHeaders': {'Referer': 'https://ext.test/'},
      'comingSoon': false,
      'actors': [
        {
          'name': 'Frieren', 'image': 'https://img.test/f.jpg', 'role': 'Main', 'roleString': null,
          'voiceActor': {'name': 'Atsumi Tanezaki', 'image': 'https://img.test/va.jpg'},
        },
        {'name': 'Himmel', 'image': null, 'role': null, 'roleString': 'Hero', 'voiceActor': null},
      ],
      'trailers': [
        {
          'url': 'https://www.youtube.com/embed/tR8YH0G67Rk', 'referer': 'https://ext.test/', 'raw': false,
          'headers': <String, String>{},
        },
        {'url': '  ', 'referer': null, 'raw': false, 'headers': <String, String>{}},
      ],
      'recommendations': [
        {'name': 'Dungeon Meshi', 'url': 'https://ext.test/meshi', 'type': 'Anime', 'apiName': 'AnimeWorld'},
        {'name': 'Elsewhere', 'url': 'https://other.test/x', 'type': 'Anime', 'apiName': 'Another'},
      ],
      'syncIds': {'mal': '52991', 'anilist': '154587', 'imdb': 'tt22248376', 'tmdb': '209867'},
      'showStatus': 'Ongoing',
      'nextAiring': {'episode': 29, 'unixTime': 1900000000, 'season': 2},
      'seasonNames': [
        {'season': 1, 'name': 'First Arc', 'displaySeason': null},
        {'season': 2, 'name': 'Second Arc', 'displaySeason': 2},
      ],
      'episodes': [
        {
          'name': 'The Journey&#39;s End', 'season': 1, 'episode': 1, 'data': '/ep/1',
          'posterUrl': 'https://img.test/e1.jpg', 'description': 'Ten years &amp; more.', 'dub': 'Subbed', 'score': 8.2,
          'date': 1736002800000, 'runTime': 24,
        },
        {
          'name': null, 'season': 2, 'episode': 1, 'data': '/ep/2', 'posterUrl': null, 'description': null,
          'dub': 'Subbed', 'score': null, 'date': null, 'runTime': null,
        },
      ],
    };

    MultimediaItem map(Map<String, dynamic> result, {DateTime? now}) => CloudStreamProvider.details(
      result,
      url: 'https://ext.test/frieren',
      packageName: 'cs3:repo/AnimeWorld/AnimeWorld',
      providerName: 'AnimeWorld',
      now: now ?? DateTime.utc(2026, 10, 11),
    );

    test("carry everything CloudStream's page shows", () {
      final item = map(anime());
      expect(item.score, 8.81);
      expect(item.contentRating, 'PG-13');
      expect(item.logoUrl, 'https://img.test/logo.png');
      expect(item.headers, {'Referer': 'https://ext.test/'});
      expect(item.status, ShowStatus.ongoing);
      expect(item.tags, ['Adventure', 'Fantasy']);
      expect(item.comingSoon, isFalse);
      expect((item.nextAiring!.episode, item.nextAiring!.unixTime, item.nextAiring!.season), (29, 1900000000, 2));
      expect(
        item.seasonNames!.map((s) => (s.season, s.name, s.displaySeason)),
        [(1, 'First Arc', null), (2, 'Second Arc', 2)],
      );
      expect(item.syncData, {'mal': '52991', 'anilist': '154587', 'imdb': 'tt22248376', 'tmdb': '209867'});
      expect(item.tmdbId, 209867);
      expect(item.imdbId, 'tt22248376');
    });

    test('cast: an enum role, free text, and a voice actor', () {
      final cast = map(anime()).cast!;
      expect((cast.first.name, cast.first.role, cast.first.roleIsEnum), ('Frieren', 'Main', true));
      expect(cast.first.voiceActor!.name, 'Atsumi Tanezaki');
      expect((cast.last.role, cast.last.roleIsEnum, cast.last.image), ('Hero', false, null));
    });

    test('trailers keep their referer as a header, and a blank one is dropped', () {
      final trailer = map(anime()).trailers!.single;
      expect(trailer.url, 'https://www.youtube.com/embed/tR8YH0G67Rk');
      expect(trailer.referer, 'https://ext.test/');
      expect(trailer.headers, {'Referer': 'https://ext.test/'});
    });

    test("recommendations are this extension's only, opened with it", () {
      final recs = map(anime()).recommendations!;
      expect(recs.map((r) => r.title), ['Dungeon Meshi']);
      expect(recs.single.provider, 'cs3:repo/AnimeWorld/AnimeWorld');
    });

    test('HTML in the plot and episodes is decoded', () {
      final item = map(anime());
      expect(item.description, 'A journey & its end.');
      expect(item.episodes!.first.name, "The Journey's End");
      expect(item.episodes!.first.description, 'Ten years & more.');
    });

    test('episodes carry their rating, runtime and air date', () {
      final episodes = map(anime()).episodes!;
      expect(episodes.first.rating, 8.2);
      expect(episodes.first.runtime, 24);
      expect(episodes.first.airedAt, DateTime.fromMillisecondsSinceEpoch(1736002800000, isUtc: true));
      expect(episodes.first.airDate, '2025-01-04');
      expect(episodes.last.name, 'Episode 1');
      expect(episodes.last.airedAt, isNull);
    });

    test('a next airing already past is not shown', () {
      expect(map(anime(), now: DateTime.utc(2031)).nextAiring, isNull);
    });

    test('the poster falls back to the background', () {
      expect(map({...anime(), 'posterUrl': null}).posterUrl, 'https://img.test/back.jpg');
    });

    test('a film with a blank data URL is coming soon, with nothing to play', () {
      final item = map({'name': 'Soon', 'type': 'Movie', 'dataUrl': '', 'comingSoon': true});
      expect(item.comingSoon, isTrue);
      expect(item.episodes, isEmpty);
    });

    test('nothing said is nothing shown', () {
      final item = map({'name': 'Bare', 'type': 'Movie', 'dataUrl': '/play'});
      expect(item.score, isNull);
      expect(item.status, ShowStatus.unknown);
      expect(item.cast, isEmpty);
      expect(item.trailers, isEmpty);
      expect(item.recommendations, isEmpty);
      expect(item.syncData, isNull);
      expect((item.tmdbId, item.imdbId, item.nextAiring), (null, null, null));
      expect(item.episodes!.single.url, CloudStreamProvider.token('/play'));
    });

    test('a date beyond any calendar drops that date, not the page', () {
      // Nanoseconds where CloudStream wants milliseconds (and seconds): DateTime would throw.
      final item = map({
        ...anime(),
        'nextAiring': {'episode': 29, 'unixTime': 1736002800000000000, 'season': 2},
        'episodes': [
          {'name': 'E', 'season': 1, 'episode': 1, 'data': '/ep/1', 'date': 1736002800000000000, 'runTime': 24},
        ],
      });
      expect(item.nextAiring, isNull);
      expect((item.episodes!.single.airedAt, item.episodes!.single.airDate), (null, null));
      expect(item.episodes!.single.runtime, 24);
    });

    test('a malformed IMDb id is not promoted', () {
      expect(map({...anime(), 'syncIds': {'imdb': '22248376'}}).imdbId, isNull);
    });
  });

  group('ani.zip fills in what an extension left out', () {
    // Shaped like https://api.ani.zip/mappings?anilist_id=21, keyed by absolute episode number.
    final mapping = {
      'titles': {'en': 'One Piece'},
      'episodeCount': 1100,
      'episodes': {
        '1033': {
          'seasonNumber': 21,
          'episodeNumber': 142,
          'absoluteEpisodeNumber': 1033,
          'title': {
            'ja': '決着! ルフィ加速する覇王の拳[こぶし]',
            'en': 'The Conclusion! Luffy, Accelerating Fist of the Supreme King',
            'x-jat': 'Kecchaku! Luffy Kasoku Suru Haou no Kobushi',
          },
          'airDate': '2022-09-18',
          'airDateUtc': '2022-09-18T14:15:00Z',
          'runtime': 24,
          'overview': 'Sanji is forced to run with Zoro on his shoulder.',
          'image': 'https://artworks.thetvdb.com/banners/v4/episode/9234602/screencap/632795bf7d464.jpg',
          'episode': '1033',
          'length': 25,
          'rating': '8.67',
          'summary': 'A summary.',
        },
        '1034': {
          'title': {'en': 'Ani.zip title'},
          'image': 'https://artworks.thetvdb.com/1034.jpg',
          'overview': 'Ani.zip overview.',
        },
        'S1': {
          'title': {'en': 'A special'},
        },
      },
    };

    Map<String, dynamic> load(Map<String, dynamic> syncIds) => {
      'name': 'One Piece',
      'type': 'Anime',
      'syncIds': syncIds,
      'episodes': [
        {'data': '/ep/1033', 'episode': 1033},
        {'data': '/ep/1034', 'episode': 1034, 'name': 'Site title', 'posterUrl': 'https://site.test/1034.jpg'},
        {'data': '/ep/1099', 'episode': 1099},
      ],
    };

    Future<(List<Episode>, List<Uri>)> details(
      Map<String, dynamic> syncIds, {
      Future<ResponseBody> Function()? respond,
      Duration timeout = const Duration(seconds: 8),
    }) async {
      final adapter = _AniZipAdapter(
        respond ??
            () async => ResponseBody.fromString(
              jsonEncode(mapping),
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            ),
      );
      final provider = CloudStreamProvider(
        plugin: const CsInstalledPlugin(
          info: CsPluginInfo(internalName: 'AniKoto', name: 'AniKoto', url: '', repositoryUrl: ''),
          filePath: '/plugins/AniKoto.cs3',
        ),
        pluginKey: 'cncverse/AniKoto',
        info: const CsProviderInfo(name: 'AniKoto'),
        host: _AnsweringHost(load(syncIds)),
        aniZip: AniZipService(Dio()..httpClientAdapter = adapter, timeout: timeout),
      );
      final item = await provider.getDetails('https://anikototv.to/one-piece');
      return (item.episodes!, adapter.requests);
    }

    void expectUnchanged(List<Episode> episodes) {
      expect([for (final ep in episodes) ep.name], ['Episode 1033', 'Site title', 'Episode 1099']);
      expect([for (final ep in episodes) ep.posterUrl], [null, 'https://site.test/1034.jpg', null]);
      expect(episodes.first.description, isNull);
    }

    test('a missing name and thumbnail, and the rest of what the extension left empty', () async {
      final (episodes, requests) = await details({'anilist': '21', 'mal': '21'});
      expect(requests.single.queryParameters, {'anilist_id': '21'});
      final ep = episodes.firstWhere((ep) => ep.episode == 1033);
      expect(ep.name, 'The Conclusion! Luffy, Accelerating Fist of the Supreme King');
      expect(ep.posterUrl, 'https://artworks.thetvdb.com/banners/v4/episode/9234602/screencap/632795bf7d464.jpg');
      expect(ep.description, 'Sanji is forced to run with Zoro on his shoulder.');
      expect((ep.rating, ep.runtime), (8.67, 24));
      expect(ep.airDate, '2022-09-18');
      expect(ep.airedAt, DateTime.utc(2022, 9, 18, 14, 15));
      expect(ep.url, CloudStreamProvider.token('/ep/1033'));
    });

    test('never what the extension gave: its names and thumbnails stay', () async {
      final (episodes, _) = await details({'anilist': '21'});
      final ep = episodes.firstWhere((ep) => ep.episode == 1034);
      expect(ep.name, 'Site title');
      expect(ep.posterUrl, 'https://site.test/1034.jpg');
      expect(ep.description, 'Ani.zip overview.');
    });

    test('an episode ani.zip does not list stays as it is', () async {
      final (episodes, _) = await details({'anilist': '21'});
      final ep = episodes.firstWhere((ep) => ep.episode == 1099);
      expect((ep.name, ep.posterUrl, ep.description), ('Episode 1099', null, null));
    });

    test('is asked by MAL id when there is no AniList id, and not at all with neither', () async {
      expect((await details({'mal': '58567'})).$2.single.queryParameters, {'mal_id': '58567'});
      final (episodes, requests) = await details({'tmdb': '37854', 'imdb': 'tt0388629'});
      expect(requests, isEmpty);
      expectUnchanged(episodes);
    });

    test('an HTTP error or a timeout leaves the episodes as they were', () async {
      final (failed, _) = await details(
        {'anilist': '21'},
        respond: () async => ResponseBody.fromString('oops', 500),
      );
      expectUnchanged(failed);
      final (timedOut, _) = await details(
        {'anilist': '21'},
        respond: () => Completer<ResponseBody>().future,
        timeout: const Duration(milliseconds: 50),
      );
      expectUnchanged(timedOut);
    });

    test('only season 1, and no specials', () {
      final aniZip = parseAniZipEpisodes(mapping);
      expect(aniZip.keys, [1033, 1034]);
      final episodes = CloudStreamProvider.withAniZip([
        Episode(name: 'Episode 1033', url: 'a', season: 2, episode: 1033),
      ], aniZip);
      expect((episodes.single.name, episodes.single.posterUrl), ('Episode 1033', null));
    });
  });
}

/// Answers every request with [respond], and keeps what was asked.
class _AniZipAdapter implements HttpClientAdapter {
  _AniZipAdapter(this.respond);

  final Future<ResponseBody> Function() respond;
  final requests = <Uri>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    requests.add(options.uri);
    return respond();
  }

  @override
  void close({bool force = false}) {}
}

/// An engine host whose every call answers [answer].
class _AnsweringHost extends CloudStreamEngineHost {
  _AnsweringHost(this.answer);

  final Map<String, dynamic> answer;

  @override
  Future<T> run<T>(
    String path,
    Future<T> Function(Cs3Engine engine) call, {
    String kind = 'call',
    String? provider,
    String mainUrl = '',
    String? pluginUrl,
  }) async => answer as T;
}
