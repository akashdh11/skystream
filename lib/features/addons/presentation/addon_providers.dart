import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/addons/data/addon_client.dart';
import '../../../core/addons/data/addon_repository.dart';
import '../../../core/addons/data/builtin_addons.dart';
import '../../../core/addons/models/addon_manifest.dart';
import '../../../core/addons/models/addon_meta.dart';

part 'addon_providers.g.dart';

/// A catalog the Catalogs tab can render as a row.
class BrowsableCatalog {
  final ManagedAddon addon;
  final AddonCatalog catalog;

  const BrowsableCatalog({required this.addon, required this.catalog});

  String get title {
    // Only the two canonical types get a pretty suffix; unusually typed
    // catalogs (CNCVerse-style 'other'/'tv' rows) already carry their type
    // in the server-provided name — "$name · other" reads as a duplication.
    return switch (catalog.type) {
      'series' => '${catalog.name} · Series',
      'movie' => '${catalog.name} · Movies',
      _ => catalog.name,
    };
  }

  String get subtitle => addon.displayName;
  String get key => '${addon.manifestUrl}|${catalog.key}';
}

/// Every browsable catalog of every enabled add-on — derived from the stored
/// manifests, so it costs no network at all.
///
/// Rows fetch their own items when they scroll into view
/// ([addonCatalogItems]); a catalog add-on that publishes 40 rows therefore
/// costs 3-4 requests on open instead of 40.
@riverpod
List<BrowsableCatalog> browsableCatalogs(Ref ref) {
  final addons = ref.watch(addonRepositoryProvider).enabled;

  final out = <BrowsableCatalog>[];
  for (final addon in addons) {
    final manifest = addon.manifest;
    if (manifest == null || !manifest.hasResource('catalog')) continue;
    for (final catalog in manifest.catalogs) {
      if (catalog.requiresSearch || catalog.requiresOtherExtra) continue;
      out.add(BrowsableCatalog(addon: addon, catalog: catalog));
    }
  }
  return out;
}

/// Outcome of one catalog row. Errors are carried rather than swallowed —
/// a row that silently disappears is impossible to debug from the UI.
class AddonCatalogResult {
  final List<AddonMetaPreview> items;
  final String? error;

  const AddonCatalogResult({this.items = const [], this.error});

  bool get isEmpty => items.isEmpty;
  bool get failed => error != null;
}

/// Items of a single catalog row. Cached by the client for 15 minutes.
@riverpod
Future<AddonCatalogResult> addonCatalogItems(
  Ref ref,
  String addonUrl,
  String type,
  String id, {
  String? genre,
}) async {
  final addons = ref.watch(addonRepositoryProvider).addons;
  ManagedAddon? addon;
  for (final candidate in addons) {
    if (candidate.manifestUrl == addonUrl) addon = candidate;
  }
  addon ??= addonUrl == BuiltInAddons.cinemetaUrl
      ? BuiltInAddons.cinemeta
      : null;
  if (addon == null) {
    return const AddonCatalogResult(error: 'Add-on is no longer installed.');
  }

  try {
    final items = await ref
        .watch(addonClientProvider)
        .catalog(
          addon,
          type: type,
          id: id,
          extra: genre == null ? null : {'genre': genre},
        )
        .timeout(const Duration(seconds: 20));
    return AddonCatalogResult(items: items);
  } on TimeoutException {
    return const AddonCatalogResult(error: 'Timed out');
  } catch (error) {
    return AddonCatalogResult(error: error.toString());
  }
}

/// Search across every catalog that advertises `search`, with Cinemeta as a
/// fallback when no installed add-on can search.
@riverpod
Future<List<AddonMetaPreview>> addonSearch(Ref ref, String query) async {
  final trimmed = query.trim();
  if (trimmed.length < 2) return const [];

  final addons = ref.watch(addonRepositoryProvider).enabled;
  final client = ref.watch(addonClientProvider);

  final searchable = <MapEntry<ManagedAddon, AddonCatalog>>[];
  for (final addon in addons) {
    final manifest = addon.manifest;
    if (manifest == null || !manifest.hasResource('catalog')) continue;
    for (final catalog in manifest.catalogs) {
      if (catalog.supportsSearch) searchable.add(MapEntry(addon, catalog));
    }
  }
  if (searchable.isEmpty) {
    for (final catalog in BuiltInAddons.cinemeta.manifest!.catalogs) {
      if (catalog.supportsSearch) {
        searchable.add(MapEntry(BuiltInAddons.cinemeta, catalog));
      }
    }
  }

  final results = await Future.wait([
    for (final entry in searchable)
      () async {
        try {
          return await client
              .catalog(
                entry.key,
                type: entry.value.type,
                id: entry.value.id,
                extra: {'search': trimmed},
              )
              .timeout(const Duration(seconds: 12));
        } catch (_) {
          return const <AddonMetaPreview>[];
        }
      }(),
  ]);

  final seen = <String>{};
  final out = <AddonMetaPreview>[];
  for (final list in results) {
    for (final item in list) {
      if (seen.add('${item.type}:${item.id}')) out.add(item);
    }
  }
  return out;
}

/// Meta for one item: the add-on it came from first, then any other meta
/// add-on, then built-in Cinemeta for IMDb ids.
///
/// The fallback is what makes catalog-only add-ons (Streaming Catalogs, Trakt
/// lists, …) usable — they publish posters but no `meta` resource at all.
@riverpod
Future<AddonMeta?> addonMeta(
  Ref ref,
  String type,
  String id, {
  String? preferredAddonUrl,
}) async {
  final addons = ref.watch(addonRepositoryProvider).enabled;
  final client = ref.watch(addonClientProvider);

  final candidates = addons
      .where((a) => a.manifest?.hasResource('meta') ?? false)
      .toList();

  final ordered = <ManagedAddon>[
    ...candidates.where((a) => a.manifestUrl == preferredAddonUrl),
    ...candidates.where((a) => a.manifestUrl != preferredAddonUrl),
    if (id.startsWith('tt') &&
        !candidates.any((a) => a.manifestUrl == BuiltInAddons.cinemetaUrl))
      BuiltInAddons.cinemeta,
  ];

  for (final addon in ordered) {
    final manifest = addon.manifest!;
    if (!manifest.supportsId('meta', id)) continue;
    for (final requestType in manifest.requestTypesFor('meta', type)) {
      try {
        final meta = await client
            .meta(addon, type: requestType, id: id)
            .timeout(const Duration(seconds: 12));
        if (meta != null) return meta;
      } catch (_) {
        continue;
      }
    }
  }
  return null;
}

/// Stremio's community add-on directory (Discover tab).
@riverpod
Future<List<CommunityAddon>> communityAddons(Ref ref) {
  return ref.watch(addonClientProvider).communityAddons();
}

/// Outcome of one liveness probe, shown per add-on on the Manage tab — the
/// Nuvio "Working / Unavailable" convention, for Stremio add-ons.
enum AddonHealthStatus { working, unavailable }

class AddonHealth {
  final AddonHealthStatus status;

  /// Manifest round-trip time — only set when [status] is working.
  final int? latencyMs;

  /// Why the probe failed (timeout, HTTP error, …), for debugging.
  final String? message;

  const AddonHealth.working(this.latencyMs)
    : status = AddonHealthStatus.working,
      message = null;

  const AddonHealth.unavailable(this.message)
    : status = AddonHealthStatus.unavailable,
      latencyMs = null;
}

/// Ping every installed add-on's manifest concurrently. One dead host
/// cannot stall the others — the map is always complete within [timeout].
Future<Map<String, AddonHealth>> probeAddonsHealth(
  AddonClient client,
  List<ManagedAddon> addons, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  final results = await Future.wait([
    for (final addon in addons)
      () async {
        final stopwatch = Stopwatch()..start();
        try {
          await client
              .fetchManifest(addon.manifestUrl, forceRefresh: true)
              .timeout(timeout);
          return MapEntry(
            addon.manifestUrl,
            AddonHealth.working(stopwatch.elapsedMilliseconds),
          );
        } catch (error) {
          return MapEntry(
            addon.manifestUrl,
            AddonHealth.unavailable(
              error is AddonException ? error.message : error.toString(),
            ),
          );
        }
      }(),
  ]);
  return {for (final entry in results) entry.key: entry.value};
}

/// Liveness of every installed add-on, keyed by manifest URL. Re-probes
/// automatically when the installed list changes (install/remove/refresh).
@riverpod
Future<Map<String, AddonHealth>> addonHealth(Ref ref) {
  final addons = ref.watch(addonRepositoryProvider).addons;
  final client = ref.watch(addonClientProvider);
  if (addons.isEmpty) return Future.value(const {});
  return probeAddonsHealth(client, addons);
}
