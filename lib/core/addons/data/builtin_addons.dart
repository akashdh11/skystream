import '../models/addon_manifest.dart';

/// Add-ons SkyStream can fall back to without the user installing anything.
///
/// Catalog-only add-ons are extremely common — the Streaming Catalogs add-on
/// (Netflix/Disney+/Prime rows), Trakt lists, RPDB catalogs — and none of them
/// implement `meta`. In Stremio those work because Cinemeta is always
/// installed. SkyStream keeps the same guarantee by consulting Cinemeta as a
/// fallback: still pure add-on protocol, just not something the user had to
/// add, and only used when no installed add-on can answer.
class BuiltInAddons {
  const BuiltInAddons._();

  static const String cinemetaUrl =
      'https://v3-cinemeta.strem.io/manifest.json';

  static final ManagedAddon cinemeta = ManagedAddon(
    manifestUrl: cinemetaUrl,
    addedAt: DateTime.fromMillisecondsSinceEpoch(0),
    manifest: const AddonManifest(
      id: 'com.linvo.cinemeta',
      name: 'Cinemeta',
      version: '3.0.14',
      description: 'Official movie & series metadata (built-in fallback)',
      types: ['movie', 'series'],
      idPrefixes: ['tt'],
      resources: [
        AddonResource(name: 'catalog', types: ['movie', 'series']),
        AddonResource(name: 'meta', types: ['movie', 'series']),
      ],
      catalogs: [
        AddonCatalog(
          type: 'movie',
          id: 'top',
          name: 'Popular movies',
          extra: [
            AddonExtraProperty(name: 'genre'),
            AddonExtraProperty(name: 'search'),
            AddonExtraProperty(name: 'skip'),
          ],
        ),
        AddonCatalog(
          type: 'series',
          id: 'top',
          name: 'Popular series',
          extra: [
            AddonExtraProperty(name: 'genre'),
            AddonExtraProperty(name: 'search'),
            AddonExtraProperty(name: 'skip'),
          ],
        ),
      ],
    ),
  );
}
