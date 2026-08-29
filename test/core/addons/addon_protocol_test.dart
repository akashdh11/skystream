import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/addons/data/addon_stream_service.dart';
import 'package:skystream/core/addons/data/debrid_service.dart';
import 'package:skystream/core/addons/models/addon_manifest.dart';
import 'package:skystream/core/addons/models/addon_stream_source.dart';

void main() {
  group('AddonTransport', () {
    test('normalises the shapes users actually paste', () {
      expect(
        AddonTransport.normalizeManifestUrl('torrentio.strem.fun'),
        'https://torrentio.strem.fun/manifest.json',
      );
      expect(
        AddonTransport.normalizeManifestUrl(
          'stremio://v3-cinemeta.strem.io/manifest.json',
        ),
        'https://v3-cinemeta.strem.io/manifest.json',
      );
      expect(
        AddonTransport.normalizeManifestUrl(
          'https://example.com/config/manifest.json/',
        ),
        'https://example.com/config/manifest.json',
      );
      expect(
        AddonTransport.normalizeManifestUrl('https://example.com/x#frag'),
        'https://example.com/x/manifest.json',
      );
    });

    test('keeps the configuration query string', () {
      const url = 'https://torrentio.strem.fun/manifest.json?providers=yts';
      expect(AddonTransport.normalizeManifestUrl(url), url);
      expect(AddonTransport.baseUrl(url), 'https://torrentio.strem.fun');

      final resource = AddonTransport.resourceUrl(
        url,
        resource: 'stream',
        type: 'series',
        id: 'tt0944947:1:5',
      );
      expect(
        resource,
        'https://torrentio.strem.fun/stream/series/tt0944947%3A1%3A5.json'
        '?providers=yts',
      );
    });

    test('appends extra props as a path segment before .json', () {
      final url = AddonTransport.resourceUrl(
        'https://v3-cinemeta.strem.io/manifest.json',
        resource: 'catalog',
        type: 'movie',
        id: 'top',
        extra: {'skip': '100', 'genre': 'Action'},
      );
      expect(
        url,
        'https://v3-cinemeta.strem.io/catalog/movie/top/skip=100&genre=Action.json',
      );
    });
  });

  group('AddonManifest', () {
    final manifest = AddonManifest.fromJson(const {
      'id': 'com.example.addon',
      'name': 'Example',
      'version': '1.0.0',
      'types': ['movie', 'series'],
      'idPrefixes': ['tt'],
      'resources': [
        'catalog',
        {
          'name': 'stream',
          'types': ['movie'],
        },
      ],
      'catalogs': [
        {
          'type': 'movie',
          'id': 'top',
          'name': 'Popular',
          'extra': [
            {'name': 'search', 'isRequired': false},
            {'name': 'skip'},
          ],
        },
        {
          'type': 'series',
          'id': 'search-only',
          'extra': [
            {'name': 'search', 'isRequired': true},
          ],
        },
      ],
    });

    test('parses string and object resources, inheriting defaults', () {
      expect(manifest.hasResource('catalog'), isTrue);
      expect(manifest.hasResource('stream'), isTrue);
      // String resource inherits the manifest-level types/prefixes…
      expect(manifest.resource('catalog')!.types, ['movie', 'series']);
      expect(manifest.resource('catalog')!.idPrefixes, ['tt']);
      // …object resource keeps its own narrowing.
      expect(manifest.resource('stream')!.types, ['movie']);
    });

    test('resource types narrow first, manifest types are the fallback', () {
      expect(manifest.requestTypesFor('catalog', 'series'), contains('series'));
      expect(manifest.requestTypesFor('stream', 'movie'), contains('movie'));
      // The stream resource is movie-only, but the manifest still claims
      // series, so we fall back to it rather than skipping the add-on.
      expect(manifest.requestTypesFor('stream', 'series'), contains('series'));
    });

    test('a resource that narrows against a silent manifest is respected', () {
      final narrow = AddonManifest.fromJson(const {
        'id': 'n',
        'name': 'N',
        'version': '1',
        'resources': [
          {
            'name': 'stream',
            'types': ['movie'],
          },
        ],
      });
      expect(narrow.requestTypesFor('stream', 'movie'), ['movie']);
      expect(narrow.requestTypesFor('stream', 'series'), isEmpty);
    });

    test('an add-on that declares no types is still asked', () {
      final loose = AddonManifest.fromJson(const {
        'id': 'x',
        'name': 'X',
        'version': '1',
        'resources': ['stream'],
      });
      expect(loose.requestTypesFor('stream', 'series'), ['series']);
      expect(loose.supportsId('stream', 'kitsu:42'), isTrue);
    });

    test('idPrefixes gate matches prefix and prefix:', () {
      expect(manifest.supportsId('stream', 'tt0111161'), isTrue);
      expect(manifest.supportsId('stream', 'kitsu:42'), isFalse);

      final tmdbAddon = AddonManifest.fromJson(const {
        'id': 'y',
        'name': 'Y',
        'version': '1',
        'idPrefixes': ['tmdb'],
        'resources': ['stream'],
      });
      expect(tmdbAddon.supportsId('stream', 'tmdb:1234'), isTrue);
    });

    test('search-only catalogs are not browsable rows', () {
      expect(manifest.catalogs.first.requiresSearch, isFalse);
      expect(manifest.catalogs.first.supportsSearch, isTrue);
      expect(manifest.catalogs.last.requiresSearch, isTrue);
    });
  });

  group('AddonStreamRequest id candidates', () {
    test('movie: add-on id first, then IMDb, then tmdb', () {
      const request = AddonStreamRequest(
        type: 'movie',
        contentId: 'kitsu:42',
        imdbId: 'tt0111161',
        tmdbId: 278,
      );
      expect(request.idCandidates, ['kitsu:42', 'tt0111161', 'tmdb:278']);
    });

    test('episode: the meta video id wins, then base:S:E, then fallbacks', () {
      const request = AddonStreamRequest(
        type: 'series',
        contentId: 'tt0944947',
        videoId: 'tt0944947:1:5',
        season: 1,
        episode: 5,
        tmdbId: 1399,
      );
      expect(request.idCandidates, ['tt0944947:1:5', 'tmdb:1399:1:5']);
    });

    test('non-IMDb series still gets an IMDb episode candidate', () {
      const request = AddonStreamRequest(
        type: 'series',
        contentId: 'kitsu:1376',
        season: 2,
        episode: 3,
        imdbId: 'tt2560140',
      );
      expect(request.idCandidates, ['kitsu:2:3', 'tt2560140:2:3']);
    });
  });

  group('AddonStreamSource', () {
    AddonStreamSource parse(Map<String, dynamic> json) =>
        AddonStreamSource.fromJson(json, addonId: 'a', addonName: 'Addon');

    test('reads direct links, including those hidden in behaviorHints', () {
      final stream = parse(const {
        'name': 'Server 1',
        'behaviorHints': {'directUrl': 'https://cdn.example/movie.mp4'},
      });
      expect(stream.kind, AddonStreamKind.direct);
      expect(stream.url, 'https://cdn.example/movie.mp4');
    });

    test('upgrades protocol-relative urls', () {
      final stream = parse(const {'url': '//cdn.example/a.mp4'});
      expect(stream.url, 'https://cdn.example/a.mp4');
    });

    test('builds a magnet with the add-on trackers', () {
      final stream = parse(const {
        'infoHash': 'ABC123',
        'fileIdx': 2,
        'sources': ['tracker:udp://tracker.one:80', 'dht:abc123'],
        'behaviorHints': {'filename': 'Movie.2019.mkv'},
      });
      expect(stream.kind, AddonStreamKind.torrent);
      expect(stream.infoHash, 'abc123');
      expect(stream.fileIdx, 2);
      expect(stream.magnetUri, contains('magnet:?xt=urn:btih:abc123'));
      expect(stream.magnetUri, contains('tracker.one'));
      expect(stream.magnetUri, isNot(contains('dht:')));
    });

    test('parses quality, HDR, size and seeders from free text', () {
      final stream = parse(const {
        'name': 'Torrentio 1080p',
        'title': 'Movie.2019.1080p.HDR.WEB-DL 👤 42 💾 2.4 GB',
        'infoHash': 'deadbeef',
      });
      expect(stream.qualityScore, 1080);
      expect(stream.qualityLabel, '1080p');
      expect(stream.isHdr, isTrue);
      expect(stream.seeders, 42);
      expect(stream.sizeLabel, isNotNull);
    });

    test('videoSize hint wins over parsed text', () {
      final stream = parse(const {
        'url': 'https://x/y.mkv',
        'title': '💾 1.0 GB',
        'behaviorHints': {'videoSize': 5368709120},
      });
      expect(stream.sizeBytes, 5368709120);
    });

    test('ranking puts resolution first and buries CAM rips', () {
      final direct1080 = parse(const {
        'url': 'https://x/a.mkv',
        'title': '1080p WEB-DL',
      });
      final torrent4k = parse(const {
        'infoHash': 'aa',
        'title': '2160p BluRay',
      });
      final direct720 = parse(const {
        'url': 'https://x/b.mkv',
        'title': '720p WEB',
      });
      final cachedDebrid4k = parse(const {
        'url': 'https://x/c.mkv',
        'name': '[RD+] 4K',
        'title': '2160p',
      });
      final cam = parse(const {'url': 'https://x/cam.mkv', 'title': 'CAM'});

      // Torrents are first-class: a 4K torrent outranks a 1080p direct link.
      expect(torrent4k.score, greaterThan(direct1080.score));
      // …but at equal resolution the instantly playable link wins.
      expect(cachedDebrid4k.score, greaterThan(torrent4k.score));
      expect(direct1080.score, greaterThan(direct720.score));
      expect(cam.score, lessThan(direct720.score));
      expect(cam.score, lessThan(0));
    });

    test('dedupe keys differ per file index', () {
      final a = parse(const {'infoHash': 'aa', 'fileIdx': 1, 'name': 'x'});
      final b = parse(const {'infoHash': 'aa', 'fileIdx': 2, 'name': 'x'});
      expect(a.dedupeKey, isNot(b.dedupeKey));
    });

    test('proxy headers are read from behaviorHints', () {
      final stream = parse(const {
        'url': 'https://x/a.mkv',
        'behaviorHints': {
          'proxyHeaders': {
            'request': {'Referer': 'https://site'},
          },
        },
      });
      expect(stream.proxyHeaders, {'Referer': 'https://site'});
    });
  });

  group('AddonSubtitleTrack', () {
    test('rejects non-http urls and prettifies languages', () {
      expect(
        AddonSubtitleTrack.fromJson(
          const {'url': 'ftp://x/a.srt', 'lang': 'eng'},
          addonName: 'A',
          index: 0,
        ),
        isNull,
      );

      final track = AddonSubtitleTrack.fromJson(
        const {'url': 'https://x/a.srt', 'lang': 'urd'},
        addonName: 'A',
        index: 0,
      );
      expect(track, isNotNull);
      expect(track!.label, 'Urdu');
    });
  });

  group('DebridService parsing', () {
    test('picks the largest video file, skipping samples and extras', () {
      final id = DebridService.pickBestFileId(const [
        {'id': 1, 'path': '/Show/readme.txt', 'bytes': 10},
        {'id': 2, 'path': '/Show/sample.mkv', 'bytes': 50000000},
        {'id': 3, 'path': '/Show/S01E01.mkv', 'bytes': 900000000},
        {'id': 4, 'path': '/Show/S01E02.mkv', 'bytes': 1900000000},
      ]);
      expect(id, 4);
    });

    test('honours a preferred filename from the add-on', () {
      final id = DebridService.pickBestFileId(const [
        {'id': 3, 'path': '/Show/S01E01.mkv', 'bytes': 900000000},
        {'id': 4, 'path': '/Show/S01E02.mkv', 'bytes': 1900000000},
      ], preferredFilename: 'S01E01.mkv');
      expect(id, 3);
    });

    test('returns null when a torrent holds no video', () {
      final id = DebridService.pickBestFileId(const [
        {'id': 1, 'path': '/pack/notes.nfo', 'bytes': 1000},
      ]);
      expect(id, isNull);
    });

    test('AllDebrid: only a ready magnet yields a link, biggest wins', () {
      expect(
        DebridService.parseAllDebridReadyLink(const {
          'status': 'success',
          'data': {
            'magnets': {
              'status': 'Downloading',
              'links': [
                {'link': 'https://a', 'size': 10},
              ],
            },
          },
        }),
        isNull,
      );

      expect(
        DebridService.parseAllDebridReadyLink(const {
          'status': 'success',
          'data': {
            'magnets': {
              'status': 'Ready',
              'links': [
                {'link': 'https://small', 'size': 100, 'filename': 'a.mkv'},
                {
                  'link': 'https://sample',
                  'size': 900,
                  'filename': 'sample.mkv',
                },
                {'link': 'https://big', 'size': 800, 'filename': 'b.mkv'},
              ],
            },
          },
        }),
        'https://big',
      );
    });

    test('AllDebrid: an error payload yields nothing', () {
      expect(
        DebridService.parseAllDebridReadyLink(const {
          'status': 'error',
          'error': {'message': 'bad key'},
        }),
        isNull,
      );
    });

    test('provider ids round-trip for storage', () {
      expect(DebridProvider.fromId('real-debrid'), DebridProvider.realDebrid);
      expect(DebridProvider.fromId('alldebrid'), DebridProvider.allDebrid);
      expect(DebridProvider.fromId(null), DebridProvider.none);
      expect(DebridProvider.fromId('nonsense'), DebridProvider.none);
    });
  });
}
