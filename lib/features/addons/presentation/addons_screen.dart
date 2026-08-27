import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/addons/data/addon_client.dart';
import '../../../core/addons/data/addon_repository.dart';
import '../../../core/addons/models/addon_meta.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/cards_wrapper.dart';
import 'addon_providers.dart';
import 'widgets/addon_manage_view.dart';

/// Add-ons destination — catalogs, management and discovery.
///
/// Everything here is served by installed Stremio add-ons; the plugin system
/// is never consulted.
class AddonsScreen extends ConsumerStatefulWidget {
  const AddonsScreen({super.key});

  @override
  ConsumerState<AddonsScreen> createState() => _AddonsScreenState();
}

class _AddonsScreenState extends ConsumerState<AddonsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add-ons'),
          bottom: TabBar(
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicatorColor: theme.colorScheme.primary,
            tabs: const [
              Tab(text: 'Catalogs'),
              Tab(text: 'My add-ons'),
              Tab(text: 'Discover'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _CatalogsTab(
              query: _query,
              controller: _searchController,
              onQueryChanged: _onQueryChanged,
            ),
            const AddonManageView(),
            const _DiscoverTab(),
          ],
        ),
      ),
    );
  }
}

class _CatalogsTab extends ConsumerWidget {
  final String query;
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;

  const _CatalogsTab({
    required this.query,
    required this.controller,
    required this.onQueryChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addonRepositoryProvider);
    final theme = Theme.of(context);
    final catalogs = ref.watch(browsableCatalogsProvider);
    final hasStreamAddon = state.enabled.any(
      (a) => a.manifest?.hasResource('stream') ?? false,
    );

    if (!state.isLoading && state.enabled.isEmpty) {
      return const _EmptyHint(
        icon: Icons.dashboard_customize_outlined,
        title: 'No add-ons yet',
        message:
            'Open "My add-ons" and install Cinemeta for catalogs and Torrentio '
            'for streams — two taps and this tab fills up.',
      );
    }

    return Column(
      children: [
        if (!state.isLoading && !hasStreamAddon)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'None of your add-ons provide streams yet — install one '
                    '(e.g. Torrentio) to play anything.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: controller,
            onChanged: onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search your add-ons…',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: query.length >= 2
              ? _SearchResults(query: query)
              : catalogs.isEmpty
              ? const _EmptyHint(
                  icon: Icons.grid_view_rounded,
                  title: 'No catalogs',
                  message:
                      'None of your add-ons publish browsable catalogs. '
                      'Cinemeta or a streaming-catalogs add-on will fill this.',
                )
              // Rows are built lazily by the ListView, and each row only hits
              // the network when it scrolls into view — a 40-catalog add-on
              // therefore costs a handful of requests, not forty.
              : RefreshIndicator(
                  onRefresh: () async {
                    ref.read(addonClientProvider).clearCache();
                    for (final entry in catalogs) {
                      ref.invalidate(
                        addonCatalogItemsProvider(
                          entry.addon.manifestUrl,
                          entry.catalog.type,
                          entry.catalog.id,
                        ),
                      );
                    }
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: catalogs.length,
                    addAutomaticKeepAlives: false,
                    itemBuilder: (context, index) =>
                        _CatalogRow(entry: catalogs[index]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _CatalogRow extends ConsumerWidget {
  final BrowsableCatalog entry;
  const _CatalogRow({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(
      addonCatalogItemsProvider(
        entry.addon.manifestUrl,
        entry.catalog.type,
        entry.catalog.id,
      ),
    );

    return itemsAsync.when(
      // A placeholder keeps the scroll position stable while the row loads.
      loading: () => const SizedBox(height: 120),
      error: (error, _) => _RowProblem(
        title: entry.title,
        message: error.toString(),
        onRetry: () => ref.invalidate(
          addonCatalogItemsProvider(
            entry.addon.manifestUrl,
            entry.catalog.type,
            entry.catalog.id,
          ),
        ),
      ),
      data: (result) {
        // A failing row says so — silently disappearing rows are impossible
        // to diagnose from the UI.
        if (result.failed) {
          return _RowProblem(
            title: entry.title,
            message: result.error!,
            onRetry: () => ref.invalidate(
              addonCatalogItemsProvider(
                entry.addon.manifestUrl,
                entry.catalog.type,
                entry.catalog.id,
              ),
            ),
          );
        }
        final items = result.items;
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          entry.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => AddonCatalogRoute(
                      addonUrl: entry.addon.manifestUrl,
                      type: entry.catalog.type,
                      catalogId: entry.catalog.id,
                      title: entry.title,
                    ).push<void>(context),
                    child: const Text('See all'),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 214,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                addAutomaticKeepAlives: false,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) => AddonPosterCard(
                  item: items[i],
                  addonUrl: entry.addon.manifestUrl,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SearchResults extends ConsumerWidget {
  final String query;
  const _SearchResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(addonSearchProvider(query));

    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Search failed: $error')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('Nothing found in your add-ons.'));
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 140,
            childAspectRatio: 0.55,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => AddonPosterCard(
            item: items[index],
            addonUrl: null,
            width: double.infinity,
          ),
        );
      },
    );
  }
}

/// Poster tile for catalog rows, search results and the full catalog grid.
class AddonPosterCard extends StatelessWidget {
  final AddonMetaPreview item;
  final String? addonUrl;
  final double width;

  const AddonPosterCard({
    super.key,
    required this.item,
    required this.addonUrl,
    this.width = 124,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width == double.infinity ? null : width,
      // Same focusable card the rest of the app uses, so D-pad works on TV.
      child: CardsWrapper(
        borderRadius: BorderRadius.circular(12),
        onTap: () => AddonDetailRoute(
          type: item.type,
          id: item.id,
          addonUrl: addonUrl,
        ).push<void>(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: item.poster == null
                    ? ColoredBox(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Center(child: Icon(Icons.movie_outlined)),
                      )
                    : CachedNetworkImage(
                        imageUrl: item.poster!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        // Decoding at display size is the single biggest
                        // memory saving on poster-heavy screens.
                        memCacheWidth: 320,
                        fadeInDuration: const Duration(milliseconds: 120),
                        errorWidget: (_, _, _) => ColoredBox(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (item.releaseInfo != null)
              Text(
                item.releaseInfo!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverTab extends ConsumerWidget {
  const _DiscoverTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directoryAsync = ref.watch(communityAddonsProvider);
    final installed = ref.watch(addonRepositoryProvider).addons;
    final installedIds = installed.map((a) => a.id).toSet();

    return directoryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load the add-on directory: $error'),
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return const _EmptyHint(
            icon: Icons.travel_explore_rounded,
            title: 'Directory unavailable',
            message:
                'You can still paste a manifest URL in the "My add-ons" tab.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final isInstalled = installedIds.contains(entry.manifest.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: entry.manifest.logoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: entry.manifest.logoUrl!,
                          width: 38,
                          height: 38,
                          fit: BoxFit.cover,
                          memCacheWidth: 96,
                          errorWidget: (_, _, _) =>
                              const Icon(Icons.extension_rounded),
                        ),
                      )
                    : const Icon(Icons.extension_rounded),
                title: Text(entry.manifest.name),
                subtitle: Text(
                  entry.manifest.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: isInstalled
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                      )
                    : IconButton(
                        tooltip: 'Install',
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await ref
                                .read(addonRepositoryProvider.notifier)
                                .install(entry.transportUrl);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Installed ${entry.manifest.name}',
                                ),
                              ),
                            );
                          } catch (error) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Install failed: $error')),
                            );
                          }
                        },
                      ),
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyHint({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: theme.colorScheme.primary),
            const SizedBox(height: 14),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact "this row failed" strip with a retry, so a broken add-on is visible
/// instead of an empty screen.
class _RowProblem extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _RowProblem({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.errorContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, size: 18, color: cs.error),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
