import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/addons/data/addon_client.dart';

/// The Discover tab renders Stremio's official community collection —
/// https://api.strem.io/addonscollection.json — exactly like the official
/// apps do. These tests pin the behaviours that broke it in the past:
///
/// * one junk entry must not sink the whole directory;
/// * duplicate ids from the server (community.trakt-tv really is doubled)
///   are folded, first occurrence wins;
/// * `configurationRequired` survives into the manifest, because that flag
///   drives the "Set up on website" affordance shown for half the directory;
/// * a network failure throws (so the UI can offer a retry) and is NOT
///   cached — it used to be swallowed into an empty list cached for 3h.
void main() {
  group('AddonClient.communityAddons', () {
    test(
      'parses entries and folds server-side duplicates by manifest id',
      () async {
        final adapter = _StubAdapter(
          payload: <Object?>[
            _entry(id: 'com.example.one', name: 'One'),
            _entry(id: 'com.example.one', name: 'One clone'),
            _entry(id: 'com.example.trakt-clone', name: 'Trakt Clone'),
            // Junk shapes the parser must survive.
            'not a map at all',
            {
              'transportUrl': '',
              'manifest': {'id': '', 'name': ''},
            },
            {
              'manifest': {'id': 'com.example.missing-url', 'name': 'No URL'},
            },
            {'transportUrl': 'https://x.example/manifest.json', 'manifest': 42},
            // One that must win over the junk around it.
            _entry(id: 'com.example.two', name: 'Two'),
          ],
        );
        final client = _client(adapter);

        final entries = await client.communityAddons();

        expect(entries.map((e) => e.manifest.id), [
          'com.example.one',
          'com.example.trakt-clone',
          'com.example.two',
        ], reason: 'exactly one of each id, in server order, junk skipped');
        expect(
          entries.first.manifest.name,
          'One',
          reason: 'the first server occurrence is the one that wins',
        );
      },
    );

    test('keeps configurationRequired from behaviorHints', () async {
      final adapter = _StubAdapter(
        payload: <Object?>[
          _entry(
            id: 'org.example.configurable',
            name: 'Configurable',
            behaviorHints: {
              'configurable': true,
              'configurationRequired': true,
            },
          ),
        ],
      );
      final client = _client(adapter);

      final entries = await client.communityAddons();

      expect(entries.single.manifest.behaviorHints.configurationRequired, true);
      expect(entries.single.manifest.behaviorHints.configurable, true);
    });

    test(
      'a failure throws, and is never cached as an empty directory',
      () async {
        final adapter = _StubAdapter(
          payload: <Object?>[_entry(id: 'org.example.alive', name: 'Alive')],
          failing: true,
        );
        final client = _client(adapter);

        await expectLater(client.communityAddons(), throwsA(anything));

        // Recovery must be immediate, not after a three-hour empty-list cache.
        adapter.failing = false;
        final entries = await client.communityAddons();
        expect(entries.single.manifest.id, 'org.example.alive');

        // …while a real result IS cached, so the TTL still does its job.
        adapter.requestCount = 0;
        await client.communityAddons();
        expect(adapter.requestCount, 0);
      },
    );

    test('a healthy response with no usable entries throws', () async {
      final adapter = _StubAdapter(payload: <Object?>['garbage']);
      final client = _client(adapter);

      expect(client.communityAddons(), throwsA(isA<AddonException>()));
    });

    test('hides p2p and pirate catalog add-ons — copyright risk', () async {
      // The live collection really ships entries like "Top Seeded Torrent
      // Catalogs"; Discover must never surface them, whatever the server
      // does. Everything else passes through untouched.
      final adapter = _StubAdapter(
        payload: <Object?>[
          _entry(id: 'com.stremio.opensubtitlesv3', name: 'OpenSubtitles v3'),
          _entry(
            id: 'org.tornet.catalogs',
            name: 'Torrent Catalogs',
            behaviorHints: {'p2p': true, 'configurable': false},
          ),
          _entry(id: 'io.strem.seeded', name: 'Top Seeded Torrent Catalogs'),
          _entry(id: 'club.magnet.indexer', name: 'Magnet Indexer'),
          _entry(
            id: 'com.example.p2p-flag',
            name: 'Innocent Name',
            behaviorHints: {'p2p': true},
          ),
          _entry(id: 'com.example.trakt-tv', name: 'Trakt Tv'),
        ],
      );
      final client = _client(adapter);

      final entries = await client.communityAddons();

      expect(
        entries.map((e) => e.manifest.id),
        ['com.stremio.opensubtitlesv3', 'com.example.trakt-tv'],
        reason:
            'p2p flag and torrent/pirate naming are dropped, safe '
            'entries (Trakt, OpenSubtitles) survive',
      );
    });
  });
}

Map<String, dynamic> _entry({
  required String id,
  required String name,
  Map<String, dynamic>? behaviorHints,
}) {
  return {
    'transportName': 'http',
    'transportUrl': 'https://example.com/$id/manifest.json',
    'manifest': {
      'id': id,
      'name': name,
      'version': '1.0.0',
      'description': 'Test add-on $name',
      'types': const ['movie'],
      'resources': const ['catalog'],
      'catalogs': const [
        {'type': 'movie', 'id': 'top', 'name': 'Top'},
      ],
      'behaviorHints': ?behaviorHints,
    },
  };
}

/// The add-on directory is the only endpoint the adapter answers.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({required this.payload, this.failing = false});

  dynamic payload;
  bool failing;
  var requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;
    if (failing) {
      throw DioException(requestOptions: options);
    }
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(payload)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

AddonClient _client(_StubAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return AddonClient(dio);
}
