import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/addons/models/addon_manifest.dart';

void main() {
  test('matches display name, id, host and resource', () {
    final addon = ManagedAddon(
      manifestUrl: 'https://torrentio.strem.fun/manifest.json',
      addedAt: DateTime.utc(2024, 1, 1),
      manifest: const AddonManifest(
        id: 'com.stremio.torrentio',
        name: 'Torrentio',
        version: '1.0.0',
        description: 'Torrent streams',
        types: ['movie', 'series'],
        resources: [AddonResource(name: 'stream')],
      ),
    );
    expect(addon.matchesQuery(''), isTrue);
    expect(addon.matchesQuery('torrentio'), isTrue);
    expect(addon.matchesQuery('strem.fun'), isTrue);
    expect(addon.matchesQuery('stream'), isTrue);
    expect(addon.matchesQuery('cinemeta'), isFalse);
  });
}
