import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/addons/data/addon_client.dart';
import 'package:skystream/core/addons/data/addon_stream_service.dart';
import 'package:skystream/core/addons/models/addon_manifest.dart';
import 'package:skystream/core/addons/models/addon_meta.dart';
import 'package:skystream/core/addons/models/addon_stream_source.dart';

void main() {
  group('AddonMeta.imdbId', () {
    test('reads explicit imdb_id from scraper metas', () {
      final meta = AddonMeta.fromJson({
        'id': 'cnc:abc',
        'type': 'other',
        'name': 'Hashira Training',
        'imdb_id': 'tt30395619',
      });
      expect(meta.imdbId, 'tt30395619');
    });

    test('falls back to tt primary id', () {
      final meta = AddonMeta.fromJson({
        'id': 'tt0111161',
        'type': 'movie',
        'name': 'Shawshank',
      });
      expect(meta.imdbId, 'tt0111161');
    });
  });

  group('IMDb fallback for opaque scraper ids', () {
    ManagedAddon bridge() {
      final manifest = AddonManifest.fromJson(const {
        'id': 'cnc',
        'name': 'CNCVerse Bridge',
        'version': '1',
        'types': ['movie', 'series', 'other'],
        'resources': [
          {
            'name': 'stream',
            'types': ['movie', 'series', 'other'],
          },
        ],
      });
      return ManagedAddon(
        manifestUrl: 'https://cnc.example/manifest.json',
        manifest: manifest,
        addedAt: DateTime(2024),
      );
    }

    test('empty cnc answer still yields links via resolved IMDb', () async {
      final asked = <String>[];
      final client = _FakeClient(
        onStreams: (addon, type, id) async {
          asked.add('$type/$id');
          if (id.startsWith('cnc:')) return const [];
          if (id.startsWith('tt')) {
            return [
              AddonStreamSource.fromJson(
                const {
                  'name': 'CastleTv 1080p',
                  'url': 'https://cdn.example/hashira.mp4',
                },
                addonId: 'cnc',
                addonName: 'CNCVerse Bridge',
              ),
            ];
          }
          return const [];
        },
        onImdb: ({required title, type, year, cancelToken}) async => 'tt30395619',
      );

      final service = AddonStreamService(
        client,
        addonBudget: const Duration(seconds: 5),
        requestTimeout: const Duration(seconds: 3),
      );

      AddonStreamProgress? last;
      await for (final snap in service.resolve(
        addons: [bridge()],
        request: const AddonStreamRequest(
          type: 'other',
          contentId: 'cnc:TXVsdGltb3ZpZXM6OmZha2U=',
          title: 'Demon Slayer: Kimetsu no Yaiba -To the Hashira Training',
        ),
      )) {
        last = snap;
      }

      expect(last, isNotNull);
      expect(last!.streams, hasLength(1));
      expect(last.statuses.single.outcome, AddonQueryOutcome.links);
      // IMDb must be tried (and because opaque ordering puts it first, it is
      // the one that produces links — cnc may never be asked).
      expect(asked.any((a) => a.contains('tt30395619')), isTrue);
    });
  });
}

typedef _StreamsHandler = Future<List<AddonStreamSource>> Function(
  ManagedAddon addon,
  String type,
  String id,
);

typedef _ImdbHandler = Future<String?> Function({
  required String title,
  String? type,
  int? year,
  CancelToken? cancelToken,
});

class _FakeClient extends AddonClient {
  _FakeClient({required this.onStreams, required this.onImdb}) : super(Dio());

  final _StreamsHandler onStreams;
  final _ImdbHandler onImdb;

  @override
  Future<List<AddonStreamSource>> streams(
    ManagedAddon addon, {
    required String type,
    required String id,
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) =>
      onStreams(addon, type, id);

  @override
  Future<String?> resolveImdbId({
    required String title,
    String? type,
    int? year,
    CancelToken? cancelToken,
  }) =>
      onImdb(title: title, type: type, year: year, cancelToken: cancelToken);
}
