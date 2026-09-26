import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/addons/data/addon_client.dart';
import 'package:skystream/core/addons/models/addon_manifest.dart';
import 'package:skystream/features/addons/presentation/addon_providers.dart';

/// The Manage tab shows Nuvio-style Working/Unavailable badges via
/// [probeAddonsHealth]: every installed manifest is pinged concurrently and
/// one dead host must not hold the others' verdicts hostage.
void main() {
  AddonManifest sampleManifest(String id) => AddonManifest.fromJson({
    'id': id,
    'name': id,
    'version': '1.0.0',
    'types': const ['movie'],
    'resources': const ['catalog'],
  });

  ManagedAddon managed(String label) => ManagedAddon(
    manifestUrl: 'https://$label.example/manifest.json',
    manifest: sampleManifest('test.$label'),
    addedAt: DateTime(2024),
  );

  group('probeAddonsHealth', () {
    test(
      'fast answers are working with latency, throwers unavailable',
      () async {
        final results = await probeAddonsHealth(
          _FakeHealthClient({
            'up': () async => sampleManifest('test.up'),
            'down': () async =>
                throw const AddonException('manifest not valid'),
          }),
          [managed('up'), managed('down')],
        );

        final up = results['https://up.example/manifest.json']!;
        expect(up.status, AddonHealthStatus.working);
        expect(up.latencyMs, isNotNull);
        expect(up.message, isNull);

        final down = results['https://down.example/manifest.json']!;
        expect(down.status, AddonHealthStatus.unavailable);
        expect(down.message, contains('manifest not valid'));
        expect(down.latencyMs, isNull);
      },
    );

    test(
      'a hanging host degrades to unavailable within the probe timeout',
      () async {
        final results = await probeAddonsHealth(
          _FakeHealthClient({
            'hang': () => Future<AddonManifest>.delayed(
              const Duration(hours: 1),
              () => sampleManifest('test.hang'),
            ),
          }),
          [managed('hang')],
          timeout: const Duration(milliseconds: 300),
        );

        final hang = results['https://hang.example/manifest.json']!;
        expect(hang.status, AddonHealthStatus.unavailable);
        expect(hang.latencyMs, isNull);
        expect(hang.message, isNotNull);
      },
    );

    test(
      'every installed add-on gets a verdict — no key goes missing',
      () async {
        final results = await probeAddonsHealth(
          _FakeHealthClient({
            'a': () async => sampleManifest('test.a'),
            'b': () async => sampleManifest('test.b'),
            'c': () async => throw const AddonException('gone'),
          }),
          [managed('a'), managed('b'), managed('c')],
        );

        expect(results.keys, hasLength(3));
        expect(
          results.values.every(
            (h) =>
                h.latencyMs != null ||
                h.status == AddonHealthStatus.unavailable,
          ),
          isTrue,
        );
      },
    );
  });
}

typedef _ManifestHandler = Future<AddonManifest> Function();

class _FakeHealthClient extends AddonClient {
  _FakeHealthClient(this.handlers) : super(Dio());

  final Map<String, _ManifestHandler> handlers;

  @override
  Future<AddonManifest> fetchManifest(String url, {bool forceRefresh = false}) {
    final key = Uri.parse(url).host.split('.').first;
    final handler = handlers[key];
    if (handler == null) {
      throw const AddonException('no fake handler for this host');
    }
    return handler();
  }
}
