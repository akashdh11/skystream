import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/features/addons/presentation/widgets/addon_manage_view.dart';

/// The Quick Install row shows the two official add-ons and nothing else —
/// the same short list the official Stremio apps lead with. Torrentio,
/// MediaFusion, Comet and the rest live one tab over in the Discover
/// directory alongside ~95 other community add-ons.
void main() {
  test('quick install offers exactly the two official add-ons', () {
    expect(kAddonPresets, hasLength(2));

    final byName = {for (final p in kAddonPresets) p.name: p.url};
    expect(byName, {
      'Cinemeta': 'https://v3-cinemeta.strem.io/manifest.json',
      'OpenSubtitles v3': 'https://opensubtitles-v3.strem.io/manifest.json',
    });
  });

  test('preset URLs are unique and well-formed', () {
    final urls = kAddonPresets.map((p) => p.url).toList();
    expect(urls.toSet(), hasLength(urls.length));
    for (final url in urls) {
      expect(url, startsWith('https://'));
      expect(url, endsWith('/manifest.json'));
    }
  });
}
