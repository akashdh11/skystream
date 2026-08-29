import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/addons/data/addon_stream_service.dart';
import 'package:skystream/core/addons/models/addon_manifest.dart';
import 'package:skystream/core/addons/models/addon_meta.dart';
import 'package:skystream/core/addons/models/addon_stream_source.dart';

/// Regression tests built from the real payloads of the Streaming Catalogs
/// add-on (github.com/rleroi/Stremio-Streaming-Catalogs-Addon): a catalog-only
/// add-on whose configuration lives in a path segment.
void main() {
  const manifestJson = <String, dynamic>{
    'id': 'pw.ers.netflix-catalog',
    'logo': 'https://example.com/logo.png',
    'version': '1.1.1',
    'name': 'Streaming Catalogs',
    'description': 'Trending movies and series on Netflix, HBO Max…',
    'catalogs': [
      {'id': 'nfx', 'type': 'movie', 'name': 'Netflix'},
      {'id': 'nfx', 'type': 'series', 'name': 'Netflix'},
      {'id': 'dnp', 'type': 'movie', 'name': 'Disney+'},
    ],
    'resources': ['catalog'],
    'types': ['movie', 'series'],
    'idPrefixes': ['tt'],
    'behaviorHints': {'configurable': true},
  };

  // Trimmed copy of a real meta returned by its /catalog endpoint.
  const metaJson = <String, dynamic>{
    'imdb_id': 'tt9218128',
    'name': 'Gladiator II',
    'type': 'movie',
    'year': '2024',
    'moviedb_id': 558449,
    'poster': 'https://images.justwatch.com/poster/344681920/s332/img',
    'background':
        'https://images.metahub.space/background/medium/tt9218128/img',
    'id': 'tt9218128',
    'releaseInfo': '2024',
    'genres': ['Action', 'Drama'],
    'imdbRating': '6.5',
  };

  test('catalog-only manifest parses and its catalogs are browsable', () {
    final manifest = AddonManifest.fromJson(manifestJson);

    expect(manifest.hasResource('catalog'), isTrue);
    expect(manifest.hasResource('meta'), isFalse);
    expect(manifest.catalogs, hasLength(3));
    for (final catalog in manifest.catalogs) {
      expect(catalog.requiresSearch, isFalse);
      expect(catalog.requiresOtherExtra, isFalse);
    }
    expect(manifest.behaviorHints.configurable, isTrue);
  });

  test('configuration in a path segment survives into resource URLs', () {
    const configured =
        'https://host.example/bmZ4LGRucDo6dXM6MTcwMA==/manifest.json';
    expect(AddonTransport.normalizeManifestUrl(configured), configured);
    expect(
      AddonTransport.resourceUrl(
        configured,
        resource: 'catalog',
        type: 'movie',
        id: 'nfx',
      ),
      'https://host.example/bmZ4LGRucDo6dXM6MTcwMA==/catalog/movie/nfx.json',
    );
  });

  test('bare host and stremio:// links normalise to the same manifest', () {
    expect(
      AddonTransport.normalizeManifestUrl('host.example'),
      'https://host.example/manifest.json',
    );
    expect(
      AddonTransport.normalizeManifestUrl(
        'stremio://host.example/manifest.json',
      ),
      'https://host.example/manifest.json',
    );
  });

  test('its metas map onto poster tiles with playable IMDb ids', () {
    final preview = AddonMetaPreview.fromJson(
      metaJson,
      addonId: 'pw.ers.netflix-catalog',
      addonName: 'Streaming Catalogs',
    );

    expect(preview.id, 'tt9218128');
    expect(preview.name, 'Gladiator II');
    expect(preview.poster, isNotNull);
    expect(preview.year, 2024);
    expect(preview.imdbId, 'tt9218128');

    final item = preview.toMultimediaItem();
    expect(item.title, 'Gladiator II');
    expect(item.imdbId, 'tt9218128');
    expect(item.source, kAddonItemSource);
  });

  test('installed add-ons survive a storage round-trip', () {
    final original = ManagedAddon(
      manifestUrl: 'https://host.example/cfg/manifest.json',
      manifest: AddonManifest.fromJson(manifestJson),
      addedAt: DateTime.utc(2026),
    );

    final restored = ManagedAddon.fromJson(original.toJson());
    expect(restored, isNotNull);
    expect(restored!.manifestUrl, original.manifestUrl);
    expect(restored.manifest!.catalogs, hasLength(3));
    expect(restored.manifest!.hasResource('catalog'), isTrue);
    expect(restored.manifest!.idPrefixes, ['tt']);
    // String resources must still inherit the manifest-level types.
    expect(restored.manifest!.resource('catalog')!.types, ['movie', 'series']);
    expect(restored.enabled, isTrue);
  });

  test('it declares no stream resource, so it can never return links', () {
    final manifest = AddonManifest.fromJson(manifestJson);

    expect(manifest.hasResource('stream'), isFalse);
    // Nothing to ask: the stream service skips add-ons without the resource.
    expect(
      AddonStreamService.streamProvidersOf([
        ManagedAddon(
          manifestUrl: 'https://host.example/manifest.json',
          manifest: manifest,
          addedAt: DateTime.utc(2026),
        ),
      ]),
      isEmpty,
    );
  });

  test('deep-link streams (WatchHub style) are recognised, not dropped', () {
    final stream = AddonStreamSource.fromJson(
      const {
        'name': 'Amazon Video',
        'title': 'Rent, Buy',
        'externalUrl': 'https://app.primevideo.com/detail?gti=amzn1.dv.gti.x',
      },
      addonId: 'org.stremio.watchhub',
      addonName: 'WatchHub',
    );

    expect(stream.kind, AddonStreamKind.external);
    expect(stream.isExternal, isTrue);
    expect(stream.isPlayable, isFalse);
    expect(stream.launchUrl, startsWith('https://app.primevideo.com'));
  });

  test('YouTube streams resolve to a watch URL', () {
    final stream = AddonStreamSource.fromJson(
      const {'name': 'Trailer', 'ytId': 'abc123'},
      addonId: 'x',
      addonName: 'X',
    );
    expect(stream.isExternal, isTrue);
    expect(stream.launchUrl, 'https://www.youtube.com/watch?v=abc123');
  });
}
