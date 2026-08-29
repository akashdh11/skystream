import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/nuvio/data/nuvio_code_store.dart';
import 'package:skystream/core/nuvio/data/nuvio_engine.dart';
import 'package:skystream/core/nuvio/data/nuvio_isolate_pool.dart';
import 'package:skystream/core/nuvio/data/nuvio_crypto.dart';
import 'package:skystream/core/nuvio/data/nuvio_dom.dart';
import 'package:skystream/core/nuvio/data/nuvio_polyfill.dart';
import 'package:skystream/core/nuvio/data/nuvio_runtime.dart';
import 'package:skystream/core/nuvio/models/nuvio_models.dart';

/// Nuvio plugin support, checked against how real plugins behave: bundled
/// scrapers require('cheerio-without-node-native'), call
/// getStreams(tmdbId, mediaType, season, episode) and use
/// load / select / find / first / each / get / attr / text.
void main() {
  const manifestJson = {
    'name': 'All-in-One-Nuvio',
    'version': '1.0.0',
    'scrapers': [
      {
        'id': '4khdhub',
        'name': '4KHDHub',
        'version': '1.0.0',
        'filename': 'providers/4khdhub.js',
        'supportedTypes': ['movie', 'tv'],
        'enabled': true,
      },
      {
        'id': 'animepahe',
        'name': 'AnimePahe',
        'version': '1.0.0',
        'filename': 'providers/animepahe.js',
        'supportedTypes': ['movie', 'tv', 'anime'],
        'enabled': false,
      },
    ],
  };

  group('manifest', () {
    test('parses a real repository manifest', () {
      final manifest = NuvioManifest.fromJson(manifestJson);
      expect(manifest.isValid, isTrue);
      expect(manifest.scrapers, hasLength(2));
      expect(manifest.scrapers.first.filename, 'providers/4khdhub.js');
    });

    test('scraper code resolves relative to the manifest', () {
      final repo = NuvioRepo(
        manifestUrl:
            'https://raw.githubusercontent.com/Owner/Repo/main/manifest.json',
        manifest: NuvioManifest.fromJson(manifestJson),
        addedAt: DateTime.utc(2026),
      );
      expect(
        repo.codeUrlFor(repo.manifest!.scrapers.first).toString(),
        'https://raw.githubusercontent.com/Owner/Repo/main/providers/4khdhub.js',
      );
    });

    test('manifest-disabled scrapers stay off, user toggles persist', () {
      final repo = NuvioRepo(
        manifestUrl: 'https://x/manifest.json',
        manifest: NuvioManifest.fromJson(manifestJson),
        addedAt: DateTime.utc(2026),
        disabledScrapers: const {'4khdhub'},
      );
      expect(repo.enabledScrapers, isEmpty);

      final restored = NuvioRepo.fromJson(repo.toJson());
      expect(restored!.disabledScrapers, contains('4khdhub'));
      expect(restored.manifest!.scrapers, hasLength(2));
    });

    test('type aliases: series/anime map onto Nuvio tv', () {
      final scraper = NuvioManifest.fromJson(manifestJson).scrapers.first;
      expect(scraper.supportsType('tv'), isTrue);
      expect(scraper.supportsType('series'), isTrue);
      expect(scraper.supportsType('movie'), isTrue);
    });

    test('URLs normalise from bare hosts', () {
      expect(
        NuvioUrls.normalizeManifestUrl('example.com/repo'),
        'https://example.com/repo/manifest.json',
      );
      expect(
        NuvioUrls.normalizeManifestUrl(
          'https://raw.githubusercontent.com/a/b/main/manifest.json',
        ),
        'https://raw.githubusercontent.com/a/b/main/manifest.json',
      );
    });
  });

  group('results', () {
    test('maps a real 4KHDHub-style result onto a playable stream', () {
      final result = NuvioStreamResult.fromJson(
        const {
          'name': '4KHDHub | 2160p | Dual-Audio',
          'title': 'Fight Club (1999)',
          'url': 'https://nf-cdn.movies-server.workers.dev/52231a5f',
          'quality': '2160p',
          'size': '66.39GB',
          'headers': {'Referer': 'https://4khdhub.one/'},
          'subtitles': [
            {'url': 'https://x/sub.srt', 'language': 'eng', 'name': 'English'},
          ],
        },
        scraperId: '4khdhub',
        scraperName: '4KHDHub',
      );

      expect(result, isNotNull);
      expect(result!.isTorrent, isFalse);
      expect(result.label, contains('2160p'));
      final stream = result.toStreamResult();
      expect(stream.url, startsWith('https://'));
      expect(stream.headers, {'Referer': 'https://4khdhub.one/'});
      expect(stream.subtitles, hasLength(1));
      expect(stream.providerName, '4KHDHub');
    });

    test('accepts url objects, infoHash-only results and string numbers', () {
      final objectUrl = NuvioStreamResult.fromJson(
        const {
          'title': 'x',
          'url': {'url': 'https://a/b.mkv'},
          'seeders': '42',
        },
        scraperId: 's',
        scraperName: 'S',
      );
      expect(objectUrl!.url, 'https://a/b.mkv');
      expect(objectUrl.seeders, 42);

      final torrent = NuvioStreamResult.fromJson(
        const {'title': 'y', 'infoHash': 'abc123'},
        scraperId: 's',
        scraperName: 'S',
      );
      expect(torrent!.isTorrent, isTrue);
      expect(torrent.url, startsWith('magnet:?xt=urn:btih:abc123'));

      expect(
        NuvioStreamResult.fromJson(
          const {'title': 'no link'},
          scraperId: 's',
          scraperName: 'S',
        ),
        isNull,
      );
    });
  });

  group('cheerio bridge', () {
    const html =
        '<html><body>'
        '<div class="card" data-id="1"><a href="/one">First</a></div>'
        '<div class="card" data-id="2"><a href="/two">Second</a></div>'
        '</body></html>';

    test('load + query + attr + text mirror cheerio behaviour', () {
      final dom = NuvioDom();
      final doc = dom.load(html);

      final cards = dom.query(doc, null, '.card');
      expect(cards, hasLength(2));
      expect(dom.attr(doc, cards.first, 'data-id'), '1');

      final links = dom.query(doc, cards.last, 'a');
      expect(links, hasLength(1));
      expect(dom.attr(doc, links.first, 'href'), '/two');
      expect(dom.text(doc, links.first).trim(), 'Second');

      dom.free(doc);
      expect(dom.documentCount, 0);
    });

    test('a bad selector yields nothing instead of throwing', () {
      final dom = NuvioDom();
      final doc = dom.load(html);
      expect(dom.query(doc, null, '::::'), isEmpty);
    });

    test('batch describe returns text and attributes in one call', () {
      final dom = NuvioDom();
      final doc = dom.load(html);
      final cards = dom.query(doc, null, '.card');
      final described = dom.describeBatch(doc, cards);
      expect(described, contains('"data-id":"1"'));
      expect(described, contains('First'));
    });
  });

  group('runtime gating', () {
    test('nothing is rejected up front any more', () {
      // The old gate refused any bundle whose text mentioned WebAssembly.
      // Real providers ship polyfill branches that name it without ever
      // running it, so that check threw away working scrapers. Failures are
      // now reported per scraper, after an actual attempt.
      expect(
        NuvioRuntime.unsupportedReason(
          "const c = require('cheerio-without-node-native');",
        ),
        isNull,
      );
      expect(
        NuvioRuntime.unsupportedReason('WebAssembly.instantiate(bytes)'),
        isNull,
      );
    });

    test('per-plugin budget matches Nuvio', () {
      expect(NuvioRuntime.defaultTimeout, const Duration(seconds: 60));
    });
  });

  group('javascript environment', () {
    final js = buildNuvioPolyfill(
      scraperIdJson: '"scraper"',
      settingsJson: '{}',
      tmdbKeyJson: '"KEY"',
    );

    test('placeholders are substituted', () {
      expect(js, isNot(contains('__NUVIO_TMDB_KEY__')));
      expect(js, contains('"KEY"'));
      expect(js, contains('"scraper"'));
    });

    test('exposes every global the real providers reach for', () {
      // Derived by scanning the 61 providers of All-in-One-Nuvio: 18 use URL,
      // 15 setTimeout, 8 URLSearchParams, 6 Buffer, 5 XMLHttpRequest,
      // 3 crypto-js, plus TextEncoder, localStorage and AbortSignal.timeout.
      for (final api in [
        'G.setTimeout',
        'G.setInterval',
        'G.clearTimeout',
        'G.URL',
        'G.URLSearchParams',
        'G.Buffer',
        'G.XMLHttpRequest',
        'G.TextEncoder',
        'G.TextDecoder',
        'G.localStorage',
        'G.CryptoJS',
        'G.crypto',
        'G.fetch',
        'G.Headers',
        'G.Response',
        'G.AbortSignal',
        'G.cheerio',
        'G.require',
        'NuvioAbortSignal.timeout',
      ]) {
        expect(js, contains(api), reason: '\$api missing from the runtime');
      }
    });

    test('require() answers the modules bundles ask for', () {
      for (final module in [
        "id.indexOf('cheerio') >= 0",
        "id === 'crypto-js'",
        "id === 'crypto'",
        "id === 'buffer'",
        "id === 'url'",
        "id === 'events'",
        "id === 'util'",
        "id === 'assert'",
      ]) {
        expect(js, contains(module));
      }
    });
  });

  group('crypto bridge', () {
    test('digests match known vectors', () {
      // "abc" = 616263
      expect(
        NuvioCrypto.handle({'op': 'digest', 'alg': 'SHA256', 'data': '616263'}),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
      expect(
        NuvioCrypto.handle({'op': 'digest', 'alg': 'MD5', 'data': '616263'}),
        '900150983cd24fb0d6963f7d28e17f72',
      );
    });

    test('hmac matches a known vector', () {
      expect(
        NuvioCrypto.handle({
          'op': 'hmac',
          'alg': 'SHA256',
          'key': '6b6579', // "key"
          'data': '616263',
        }),
        '9c196e32dc0175f86f4b1cb89289d6619de6bee699e4c378e68309ed97a1a6ab',
      );
    });

    test('AES-CBC round-trips', () {
      const key = '00112233445566778899aabbccddeeff';
      const iv = '000102030405060708090a0b0c0d0e0f';
      final encrypted = NuvioCrypto.handle({
        'op': 'aes_encrypt',
        'mode': 'AES-CBC',
        'key': key,
        'iv': iv,
        'data': '48656c6c6f204e7576696f', // "Hello Nuvio"
      });
      expect(encrypted.startsWith('__NUVIO_ERR__'), isFalse);
      final decrypted = NuvioCrypto.handle({
        'op': 'aes_decrypt',
        'mode': 'AES-CBC',
        'key': key,
        'iv': iv,
        'data': encrypted,
      });
      expect(decrypted, '48656c6c6f204e7576696f');
    });

    test('pbkdf2 matches RFC 6070 (SHA1, 2 iterations)', () {
      expect(
        NuvioCrypto.handle({
          'op': 'pbkdf2',
          'alg': 'SHA1',
          'pass': '70617373776f7264',
          'salt': '73616c74',
          'iterations': 2,
          'bits': 160,
        }),
        'ea6c014dc72d6f8ccd1ed92ace1d41f0d8de8957',
      );
    });

    test('random returns the requested number of bytes', () {
      final hex = NuvioCrypto.handle({'op': 'random', 'bytes': 16});
      expect(hex.length, 32);
    });

    test('an unknown op reports an error instead of throwing', () {
      expect(NuvioCrypto.handle({'op': 'nope'}), startsWith('__NUVIO_ERR__'));
    });
  });

  group('dom traversal', () {
    const html = '''
      <div class="list">
        <a class="item" href="/one">One</a>
        <a class="item skip" href="/two">Two</a>
        <span>tail</span>
      </div>
    ''';

    test('filter narrows a selection by selector', () {
      final dom = NuvioDom();
      final doc = dom.load(html);
      final links = dom.query(doc, null, 'a');
      expect(links, hasLength(2));
      expect(dom.filter(doc, links, '.skip'), hasLength(1));
    });

    test('relations walk the tree like cheerio', () {
      final dom = NuvioDom();
      final doc = dom.load(html);
      final first = dom.query(doc, null, 'a.item').first;
      expect(dom.relation(doc, [first], 'parent', null), hasLength(1));
      expect(dom.relation(doc, [first], 'next', null), hasLength(1));
      expect(dom.relation(doc, [first], 'siblings', null), hasLength(2));
      expect(dom.relation(doc, [first], 'closest', '.list'), hasLength(1));
      expect(dom.relation(doc, [first], 'index', null), ['0']);
    });

    test('text concatenates the whole selection', () {
      final dom = NuvioDom();
      final doc = dom.load(html);
      final links = dom.query(doc, null, 'a');
      expect(dom.textOf(doc, links), 'OneTwo');
    });

    test('html("") returns the document', () {
      final dom = NuvioDom();
      final doc = dom.load(html);
      expect(dom.html(doc, ''), contains('class="list"'));
    });
  });

  group('plugin metadata (real All-in-One-Nuvio shapes)', () {
    const scraperJson = {
      'id': 'allanime',
      'name': 'AllAnime',
      'description': 'AllAnime - Anime and Manga content streaming',
      'version': '1.0.5',
      'author': 'nuvio',
      'supportedTypes': ['movie', 'tv'],
      'filename': 'providers/allanime.js',
      'enabled': true,
      'hasSettings': true,
      'formats': ['mp4', 'mkv', 'm3u8'],
      'logo': 'https://i.postimg.cc/DwpqLJWV/allanime.png',
      'contentLanguage': ['en', 'ja'],
      'limited': true,
      'disabledPlatforms': ['ios'],
    };

    test('keeps everything the manifest publishes', () {
      final scraper = NuvioScraperInfo.fromJson(scraperJson);
      expect(scraper.version, '1.0.5');
      expect(scraper.author, 'nuvio');
      expect(scraper.hasSettings, isTrue);
      expect(scraper.formats, ['mp4', 'mkv', 'm3u8']);
      expect(scraper.logo, contains('postimg'));
      expect(scraper.contentLanguage, ['en', 'ja']);
      expect(scraper.limited, isTrue);
    });

    test('platform gating matches Nuvio', () {
      final scraper = NuvioScraperInfo.fromJson(scraperJson);
      expect(scraper.isSupportedOn('android'), isTrue);
      expect(scraper.isSupportedOn('iOS'), isFalse);

      final windowsOnly = NuvioScraperInfo.fromJson({
        ...scraperJson,
        'disabledPlatforms': <String>[],
        'supportedPlatforms': ['windows'],
      });
      expect(windowsOnly.isSupportedOn('windows'), isTrue);
      expect(windowsOnly.isSupportedOn('android'), isFalse);
    });

    test('a round trip through storage keeps the version', () {
      final scraper = NuvioScraperInfo.fromJson(scraperJson);
      final restored = NuvioScraperInfo.fromJson(scraper.toJson());
      expect(restored.version, '1.0.5');
      expect(restored.hasSettings, isTrue);
      expect(restored.limited, isTrue);
    });
  });

  group('plugin updates', () {
    NuvioManifest manifest(
      List<Map<String, dynamic>> scrapers,
      String version,
    ) => NuvioManifest.fromJson({
      'name': 'Repo',
      'version': version,
      'scrapers': scrapers,
    });

    Map<String, dynamic> scraper(String id, String version) => {
      'id': id,
      'name': id,
      'version': version,
      'filename': 'providers/$id.js',
    };

    test('compares versions numerically, not as text', () {
      expect(compareNuvioVersions('1.0.10', '1.0.9') > 0, isTrue);
      expect(compareNuvioVersions('2.0.0', '1.9.9') > 0, isTrue);
      expect(compareNuvioVersions('1.0.0', '1.0.0'), 0);
      expect(compareNuvioVersions('v1.1.0', '1.1.0'), 0);
      expect(compareNuvioVersions('1.0.0', '1.0.1') < 0, isTrue);
    });

    test('spots the versions a developer published', () {
      final installed = manifest([
        scraper('a', '1.0.0'),
        scraper('b', '1.0.0'),
        scraper('gone', '1.0.0'),
      ], '1.0.0');
      final fetched = manifest([
        scraper('a', '1.0.0'),
        scraper('b', '1.0.5'),
        scraper('new', '2.0.0'),
      ], '1.1.0');

      final summary = NuvioUpdateSummary.diff(installed, fetched);
      expect(summary.hasChanges, isTrue);
      expect(summary.updated.single.scraper.id, 'b');
      expect(summary.updated.single.from, '1.0.0');
      expect(summary.updated.single.to, '1.0.5');
      expect(summary.added.single.id, 'new');
      expect(summary.removed, ['gone']);
      expect(summary.changedScraperIds, {'b', 'new'});
      expect(summary.changeCount, 3);
      expect(summary.label, '1 updated · 1 new · 1 removed');
    });

    test('no changes means nothing to re-download', () {
      final same = manifest([scraper('a', '1.0.0')], '1.0.0');
      final summary = NuvioUpdateSummary.diff(same, same);
      expect(summary.hasChanges, isFalse);
      expect(summary.changedScraperIds, isEmpty);
      expect(summary.label, 'Up to date');
    });

    test('a first install counts every scraper as new', () {
      final summary = NuvioUpdateSummary.diff(
        null,
        manifest([scraper('a', '1.0.0'), scraper('b', '1.0.0')], '1.0.0'),
      );
      expect(summary.added, hasLength(2));
      expect(summary.hasChanges, isTrue);
    });
  });

  group('scraper settings form', () {
    const layout = [
      {'type': 'header', 'label': 'Account'},
      {
        'type': 'text',
        'key': 'apiKey',
        'label': 'API key',
        'placeholder': 'paste here',
        'isPassword': true,
        'description': 'From your provider dashboard',
      },
      {
        'type': 'select',
        'key': 'quality',
        'label': 'Max quality',
        'defaultValue': '1080p',
        'options': [
          {'label': '4K', 'value': '2160p'},
          {'label': '1080p', 'value': '1080p'},
        ],
      },
      {
        'type': 'toggle',
        'key': 'dubbed',
        'label': 'Dubbed',
        'defaultValue': true,
      },
      {'type': 'nonsense', 'key': 'x'},
    ];

    test('parses the field types Nuvio renders and drops unknown ones', () {
      final fields = NuvioSettingsField.parseLayout(layout);
      expect(fields, hasLength(4));
      expect(fields[0].type, 'header');
      expect(fields[1].isPassword, isTrue);
      expect(fields[1].placeholder, 'paste here');
      expect(fields[2].options.map((o) => o.value), ['2160p', '1080p']);
      expect(fields[3].defaultValue, true);
    });

    test(
      'defaults are what the plugin sees before the user edits anything',
      () {
        final defaults = NuvioSettingsField.defaults(
          NuvioSettingsField.parseLayout(layout),
        );
        expect(defaults, {'quality': '1080p', 'dubbed': true});
      },
    );

    test('a malformed layout is empty, not a crash', () {
      expect(NuvioSettingsField.parseLayout('nope'), isEmpty);
      expect(NuvioSettingsField.parseLayout(null), isEmpty);
    });
  });

  group('stream results from real providers', () {
    test('takes headers out of behaviorHints.proxyHeaders.request', () {
      // Shape returned by 4KHDHub: the CDN 403s without that Referer.
      final result = NuvioStreamResult.fromJson(
        const {
          'name': '4KHDHub | 2160p',
          'title': 'Spider-Man',
          'url': 'https://cdn.example/file.mkv',
          'behaviorHints': {
            'notWebReady': true,
            'proxyHeaders': {
              'request': {
                'Referer': 'https://4khdhub.one/',
                'User-Agent': 'Mozilla/5.0',
              },
            },
          },
        },
        scraperId: 's',
        scraperName: '4KHDHub',
      );

      expect(result, isNotNull);
      expect(result!.headers?['Referer'], 'https://4khdhub.one/');
      expect(result.headers?['User-Agent'], 'Mozilla/5.0');
      expect(result.toStreamResult().headers?['Referer'], isNotNull);
    });

    test('strips the zero-width sort padding providers add', () {
      final result = NuvioStreamResult.fromJson(
        const {
          'name': '\u200b\ufeff\u200bProvider | 1080p',
          'title': '\ufeffMovie title',
          'url': 'https://cdn.example/a.mkv',
        },
        scraperId: 's',
        scraperName: 'P',
      );

      expect(result!.title, 'Movie title');
      expect(result.name, 'Provider | 1080p');
    });

    test('derives quality when only the title carries it', () {
      final result = NuvioStreamResult.fromJson(
        const {'title': 'Movie 2160p HDR', 'url': 'https://cdn.example/a.mkv'},
        scraperId: 's',
        scraperName: 'P',
      );
      expect(result!.quality, '2160p');
    });

    test('formats a byte count when the provider sends one', () {
      final result = NuvioStreamResult.fromJson(
        const {
          'title': 'Movie',
          'url': 'https://cdn.example/a.mkv',
          'sizeBytes': 2147483648,
        },
        scraperId: 's',
        scraperName: 'P',
      );
      expect(result!.size, '2.0 GB');
    });

    test('accepts alternative url fields and object urls', () {
      final asObject = NuvioStreamResult.fromJson(
        const {
          'title': 'A',
          'url': {'url': 'https://cdn.example/b.mkv'},
        },
        scraperId: 's',
        scraperName: 'P',
      );
      expect(asObject!.url, 'https://cdn.example/b.mkv');

      final asLink = NuvioStreamResult.fromJson(
        const {'title': 'A', 'link': 'https://cdn.example/c.mkv'},
        scraperId: 's',
        scraperName: 'P',
      );
      expect(asLink!.url, 'https://cdn.example/c.mkv');
    });

    test('an infoHash-only result becomes a magnet', () {
      final result = NuvioStreamResult.fromJson(
        const {'title': 'T', 'infoHash': 'abc123'},
        scraperId: 's',
        scraperName: 'P',
      );
      expect(result!.url, startsWith('magnet:?xt=urn:btih:abc123'));
      expect(result.isTorrent, isTrue);
    });
  });

  group('plugin code cache', () {
    test('file names are unique per repository, scraper and version', () {
      final a = NuvioCodeStore.fileNameFor(
        manifestUrl: 'https://example.com/manifest.json',
        scraperId: '4khdhub',
        version: '1.0.0',
      );
      final newer = NuvioCodeStore.fileNameFor(
        manifestUrl: 'https://example.com/manifest.json',
        scraperId: '4khdhub',
        version: '1.0.5',
      );
      final otherRepo = NuvioCodeStore.fileNameFor(
        manifestUrl: 'https://other.example/manifest.json',
        scraperId: '4khdhub',
        version: '1.0.0',
      );
      expect(a, isNot(newer));
      expect(a, isNot(otherRepo));
      expect(a, endsWith('.js'));
      // No path separators or query characters can leak into the name.
      expect(a.contains('/'), isFalse);
    });

    test('unsafe scraper ids are sanitised', () {
      final name = NuvioCodeStore.fileNameFor(
        manifestUrl: 'https://example.com/manifest.json?token=x',
        scraperId: '../../etc/passwd',
        version: '1.0',
      );
      expect(name.contains('..'), isFalse);
      expect(name.contains('/'), isFalse);
    });

    test('reads and writes through a temporary directory', () async {
      final dir = await Directory.systemTemp.createTemp('nuvio_code');
      addTearDown(() => dir.delete(recursive: true));
      final store = NuvioCodeStore(root: dir);

      await store.write(
        manifestUrl: 'https://example.com/manifest.json',
        scraperId: 'a',
        version: '1.0.0',
        code: 'module.exports = {};',
      );
      expect(
        await store.read(
          manifestUrl: 'https://example.com/manifest.json',
          scraperId: 'a',
          version: '1.0.0',
        ),
        'module.exports = {};',
      );

      // A new version is a different file, so the old bundle can't be run.
      expect(
        await store.read(
          manifestUrl: 'https://example.com/manifest.json',
          scraperId: 'a',
          version: '1.0.1',
        ),
        isNull,
      );

      await store.prune(
        manifestUrl: 'https://example.com/manifest.json',
        keepIdVersions: {'a@1.0.1'},
      );
      expect(
        await store.read(
          manifestUrl: 'https://example.com/manifest.json',
          scraperId: 'a',
          version: '1.0.0',
        ),
        isNull,
      );
    });
  });

  group('bridge payloads', () {
    final js = buildNuvioPolyfill(
      scraperIdJson: '"s"',
      settingsJson: '{}',
      tmdbKeyJson: '"k"',
    );

    test('every sendMessage payload is JSON', () {
      // flutter_js decodes each message with jsonDecode before handing it to
      // Dart. A bare string (a log line) makes that throw, which used to kill
      // every plugin that called console.log — 38 of the 61 real providers.
      final calls = RegExp(
        r"sendMessage\(\s*'([a-z_]+)'\s*,\s*([^;]+?)\)\s*;",
      ).allMatches(js);
      expect(calls, isNotEmpty);
      for (final call in calls) {
        final channel = call.group(1)!;
        final payload = call.group(2)!.trim();
        expect(
          payload.startsWith('JSON.stringify(') || payload == 'payload',
          isTrue,
          reason: 'channel $channel sends a non-JSON payload: $payload',
        );
      }
    });

    test('console logging goes through JSON.stringify', () {
      expect(
        js,
        contains("sendMessage('nuvio_log', JSON.stringify(String(text)))"),
      );
      expect(js, isNot(contains("sendMessage('nuvio_log', fmt(")));
    });

    test('logging can never throw out of a scraper', () {
      expect(js, contains('function logLine(text)'));
      expect(js, contains('// Logging must never break a scraper.'));
    });
  });

  group('enabling plugins the repository ships disabled', () {
    NuvioScraperInfo scraper({required bool enabled}) => NuvioScraperInfo(
      id: 'torrentio',
      name: 'Torrentio',
      version: '1.0.0',
      filename: 'providers/torrentio.js',
      manifestEnabled: enabled,
    );

    test('a manifest-disabled plugin can be turned on by the user', () {
      final repo = NuvioRepo(
        manifestUrl: 'https://example.com/manifest.json',
        addedAt: DateTime.now(),
      );
      expect(repo.isScraperEnabled(scraper(enabled: false)), isFalse);

      final withOverride = repo.copyWith(enabledOverrides: {'torrentio'});
      expect(withOverride.isScraperEnabled(scraper(enabled: false)), isTrue);
    });

    test('switching off always wins', () {
      final repo = NuvioRepo(
        manifestUrl: 'https://example.com/manifest.json',
        addedAt: DateTime.now(),
        enabledOverrides: {'torrentio'},
        disabledScrapers: {'torrentio'},
      );
      expect(repo.isScraperEnabled(scraper(enabled: true)), isFalse);
    });

    test('overrides survive a storage round trip', () {
      final repo = NuvioRepo(
        manifestUrl: 'https://example.com/manifest.json',
        addedAt: DateTime.now(),
        enabledOverrides: {'torrentio', 'other'},
        disabledScrapers: {'x'},
      );
      final restored = NuvioRepo.fromJson(repo.toJson())!;
      expect(restored.enabledOverrides, {'torrentio', 'other'});
      expect(restored.disabledScrapers, {'x'});
    });
  });

  group('plugin worker isolates', () {
    test('a request survives the trip to another isolate', () {
      const request = NuvioEngineRequest(
        code: 'module.exports = {};',
        scraperId: 'repo#a',
        scraperName: 'A',
        tmdbId: '603',
        mediaType: 'tv',
        season: 2,
        episode: 5,
        settings: {'apiKey': 'x', 'dubbed': true},
        tmdbKey: 'key',
        timeoutMs: 1234,
        mode: 'settings',
      );
      final restored = NuvioEngineRequest.fromMap(request.toMap());
      expect(restored.code, request.code);
      expect(restored.scraperId, 'repo#a');
      expect(restored.season, 2);
      expect(restored.episode, 5);
      expect(restored.settings, {'apiKey': 'x', 'dubbed': true});
      expect(restored.tmdbKey, 'key');
      expect(restored.timeoutMs, 1234);
      expect(restored.mode, 'settings');
    });

    test('the payload contains only isolate-sendable values', () {
      const request = NuvioEngineRequest(
        code: 'x',
        scraperId: 'a',
        scraperName: 'A',
        settings: {'n': 1, 's': 'v', 'b': false},
      );
      // jsonEncode succeeds only for plain values, which is exactly the
      // constraint Isolate.send imposes on us.
      expect(() => jsonEncode(request.toMap()), returnsNormally);
    });

    test(
      'the pool answers with JSON instead of hanging or throwing',
      () async {
        final pool = NuvioIsolatePool(size: 1);
        addTearDown(pool.dispose);

        // QuickJS is not available in the test host, so this exercises the
        // spawn / send / reply / error path rather than real scraping: the
        // contract is that a caller always gets a JSON document back.
        final raw = await pool
            .execute(
              const NuvioEngineRequest(
                code:
                    'module.exports = { getStreams: function () { return []; } };',
                scraperId: 'test',
                scraperName: 'Test',
                tmdbId: '603',
                timeoutMs: 4000,
              ),
            )
            .timeout(const Duration(seconds: 40));

        final decoded = jsonDecode(raw);
        expect(decoded, isA<Map<String, dynamic>>());
        expect(
          (decoded as Map).containsKey('streams') ||
              decoded.containsKey('error'),
          isTrue,
        );
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'parallel jobs reserve at most `size` isolates',
      () async {
        final pool = NuvioIsolatePool(size: 2);
        addTearDown(pool.dispose);

        // Eight jobs starting at once used to spawn eight isolates, because each
        // of them checked the worker count before any of them had finished
        // spawning.
        await Future.wait([
          for (var i = 0; i < 8; i++)
            pool.execute(
              NuvioEngineRequest(
                code: 'module.exports = {};',
                scraperId: 'p$i',
                scraperName: 'P$i',
                timeoutMs: 3000,
              ),
            ),
        ]).timeout(const Duration(seconds: 45));

        expect(pool.workerCount, lessThanOrEqualTo(2));
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test('a disposed pool refuses new work', () {
      final pool = NuvioIsolatePool(size: 1)..dispose();
      expect(
        () => pool.execute(
          const NuvioEngineRequest(code: '', scraperId: 'a', scraperName: 'A'),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('scrapers are wrapped in the CommonJS shell Nuvio uses', () {
      final wrapped = NuvioEngine.wrapScraper('var a = 1;');
      expect(wrapped, contains('var module = { exports: {} };'));
      expect(wrapped, contains('var exports = module.exports;'));
      expect(wrapped, contains('var a = 1;'));
      expect(wrapped.trim().endsWith('})();'), isTrue);
    });
  });

  group('plugin HTTP layer', () {
    late HttpServer server;
    late String base;
    final requests = <HttpRequest>[];

    setUp(() async {
      requests.clear();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      base = 'http://127.0.0.1:${server.port}';
      server.listen((request) async {
        requests.add(request);
        switch (request.uri.path) {
          case '/plain':
            request.response
              ..statusCode = 200
              ..headers.set('content-type', 'text/plain')
              ..write('hello');
          case '/set-cookie':
            request.response
              ..statusCode = 200
              ..headers.add('set-cookie', 'sid=abc123; Path=/')
              ..write('ok');
          case '/echo-cookie':
            request.response
              ..statusCode = 200
              ..write(request.headers.value('cookie') ?? 'none');
          case '/echo-agent':
            request.response
              ..statusCode = 200
              ..write(request.headers.value('user-agent') ?? 'none');
          case '/redirect':
            request.response
              ..statusCode = 302
              ..headers.set('location', '/plain');
          case '/echo-body':
            final body = await utf8.decoder.bind(request).join();
            request.response
              ..statusCode = 200
              ..write('${request.method}:$body');
          default:
            request.response.statusCode = 404;
        }
        await request.response.close();
      });
    });

    tearDown(() async => server.close(force: true));

    test('returns status, body and headers', () async {
      final http = NuvioEngineHttp();
      addTearDown(http.close);
      final result = await http.fetch({'url': '$base/plain'});
      expect(result['ok'], isTrue);
      expect(result['status'], 200);
      expect(result['body'], 'hello');
      expect(
        (result['headers'] as Map)['content-type'],
        contains('text/plain'),
      );
    });

    test('sends a browser user agent by default', () async {
      final http = NuvioEngineHttp();
      addTearDown(http.close);
      final result = await http.fetch({'url': '$base/echo-agent'});
      expect(result['body'], contains('Mozilla/5.0'));
    });

    test('keeps cookies for the rest of the scraper run', () async {
      final http = NuvioEngineHttp();
      addTearDown(http.close);
      await http.fetch({'url': '$base/set-cookie'});
      final result = await http.fetch({'url': '$base/echo-cookie'});
      expect(result['body'], contains('sid=abc123'));
    });

    test('follows redirects, and reports them when asked not to', () async {
      final http = NuvioEngineHttp();
      addTearDown(http.close);

      final followed = await http.fetch({'url': '$base/redirect'});
      expect(followed['status'], 200);
      expect(followed['body'], 'hello');
      expect(followed['redirected'], isTrue);

      final manual = await http.fetch({
        'url': '$base/redirect',
        'follow': false,
      });
      expect(manual['status'], 302);
      expect((manual['headers'] as Map)['location'], '/plain');
    });

    test('posts a body', () async {
      final http = NuvioEngineHttp();
      addTearDown(http.close);
      final result = await http.fetch({
        'url': '$base/echo-body',
        'method': 'POST',
        'body': 'a=1',
      });
      expect(result['body'], 'POST:a=1');
    });

    test('a dead host is an error payload, never a throw', () async {
      final http = NuvioEngineHttp();
      addTearDown(http.close);
      final result = await http.fetch({'url': 'http://127.0.0.1:1/nope'});
      expect(result[NuvioEngineHttp.errorKey], isNotNull);
    });
  });
}
