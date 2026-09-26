import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/addons/models/addon_manifest.dart';
import 'package:skystream/features/addons/presentation/addon_providers.dart';

/// CNCVerse-style catalogs are typed `other`/`tv` and already carry the type
/// in their server-provided name ("MoviesDrive (other)"). Appending the row
/// suffix for them produced "MoviesDrive (other) · other", the duplication
/// the user reported; only the two canonical types keep the suffix.
void main() {
  group('BrowsableCatalog.title', () {
    BrowsableCatalog row(String type, String name) {
      final manifest = AddonManifest.fromJson({
        'id': 'test.catalogs',
        'name': 'Test Catalogs',
        'version': '1.0.0',
        'types': const ['movie', 'series', 'other', 'tv'],
        'resources': const ['catalog'],
        'catalogs': [
          {'type': type, 'id': 'c1', 'name': name},
        ],
      });
      final addon = ManagedAddon(
        manifestUrl: 'https://example.test/manifest.json',
        manifest: manifest,
        addedAt: DateTime(2024),
      );
      return BrowsableCatalog(addon: addon, catalog: manifest.catalogs.single);
    }

    test('movie and series keep their pretty suffix', () {
      expect(row('movie', 'Top').title, 'Top · Movies');
      expect(row('series', 'Top').title, 'Top · Series');
    });

    test('unusual types keep only the server-provided name', () {
      expect(row('other', 'MoviesDrive (other)').title, 'MoviesDrive (other)');
      expect(row('tv', 'Live Sports').title, 'Live Sports');
    });
  });
}
