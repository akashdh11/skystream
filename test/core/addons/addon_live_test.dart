@Tags(['live'])
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/addons/data/addon_client.dart';
import 'package:skystream/core/addons/models/addon_manifest.dart';

/// Live end-to-end check against the Streaming Catalogs add-on
/// (https://github.com/rleroi/Stremio-Streaming-Catalogs-Addon).
///
/// It is a catalog-only add-on with its configuration in a path segment, which
/// makes it the best real-world probe for the whole client: URL normalisation,
/// manifest parsing, catalog fetching and meta fallback.
///
/// Run with: flutter test --tags live test/core/addons/addon_live_test.dart
void main() {
  const host =
      'https://7a82163c306e-stremio-netflix-catalog-addon.baby-beamup.club';

  late AddonClient client;

  setUp(() {
    client = AddonClient(Dio());
  });

  test('installs from the bare host URL', () async {
    final manifest = await client.fetchManifest(host);
    expect(manifest.id, isNotEmpty);
    expect(manifest.hasResource('catalog'), isTrue);
    expect(manifest.catalogs, isNotEmpty);
  });

  test('installs from a configured URL and keeps the path config', () async {
    // "providers:rpdbKey:country:installedAt", base64 — what the add-on's own
    // configure page produces.
    const configured =
        '$host/bmZ4LGRucCxoYm06OnVzOjE3MDAwMDAwMDA=/manifest.json';
    final manifest = await client.fetchManifest(configured);
    expect(manifest.catalogs.map((c) => c.id), contains('dnp'));

    final url = AddonTransport.resourceUrl(
      configured,
      resource: 'catalog',
      type: 'movie',
      id: 'dnp',
    );
    expect(url, contains('/bmZ4LGRucCxoYm06OnVzOjE3MDAwMDAwMDA=/catalog/'));
  });

  test('catalog rows return usable posters', () async {
    final manifest = await client.fetchManifest(host);
    final addon = ManagedAddon(
      manifestUrl: AddonTransport.normalizeManifestUrl(host),
      manifest: manifest,
      addedAt: DateTime.now(),
    );

    final catalog = manifest.catalogs.first;
    final items = await client.catalog(
      addon,
      type: catalog.type,
      id: catalog.id,
    );

    expect(items, isNotEmpty);
    final first = items.first;
    expect(first.id, isNotEmpty);
    expect(first.name, isNotEmpty);
    expect(first.poster, isNotNull);
    // This add-on hands out IMDb ids, which is what stream add-ons need.
    expect(first.id.startsWith('tt'), isTrue);
  });

  test('metadata resolves through Cinemeta for its items', () async {
    final manifest = await client.fetchManifest(host);
    final addon = ManagedAddon(
      manifestUrl: AddonTransport.normalizeManifestUrl(host),
      manifest: manifest,
      addedAt: DateTime.now(),
    );
    final items = await client.catalog(addon, type: 'movie', id: 'nfx');
    expect(items, isNotEmpty);

    final cinemetaManifest = await client.fetchManifest(
      'https://v3-cinemeta.strem.io/manifest.json',
    );
    final cinemeta = ManagedAddon(
      manifestUrl: 'https://v3-cinemeta.strem.io/manifest.json',
      manifest: cinemetaManifest,
      addedAt: DateTime.now(),
    );

    final meta = await client.meta(cinemeta, type: 'movie', id: items.first.id);
    expect(meta, isNotNull);
    expect(meta!.name, isNotEmpty);
  });

  test(
    'it provides catalogs only — it can never return streaming links',
    () async {
      final manifest = await client.fetchManifest(host);
      expect(manifest.hasResource('catalog'), isTrue);
      expect(
        manifest.hasResource('stream'),
        isFalse,
        reason:
            'Streaming Catalogs is a catalog add-on: it lists what is on '
            'Netflix/Disney+/HBO but serves no playable links. Pair it with a '
            'stream add-on (Torrentio, MediaFusion, Comet) or WatchHub for '
            'deep links into the services.',
      );
    },
  );

  test('WatchHub supplies the streaming-service deep links instead', () async {
    final manifest = await client.fetchManifest(
      'https://watchhub.strem.io/manifest.json',
    );
    expect(manifest.hasResource('stream'), isTrue);

    final addon = ManagedAddon(
      manifestUrl: 'https://watchhub.strem.io/manifest.json',
      manifest: manifest,
      addedAt: DateTime.now(),
    );
    final streams = await client.streams(addon, type: 'movie', id: 'tt0111161');
    expect(streams, isNotEmpty);
    expect(streams.every((s) => s.isExternal), isTrue);
    expect(streams.first.launchUrl, isNotNull);
  });
}
