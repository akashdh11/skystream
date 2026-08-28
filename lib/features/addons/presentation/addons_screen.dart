import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/addons/data/addon_client.dart';
import '../../../core/addons/data/addon_repository.dart';
import '../../../core/addons/models/addon_meta.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/cards_wrapper.dart';
import 'addon_providers.dart';
import 'widgets/addon_manage_view.dart';

import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/providers/device_info_provider.dart';
import '../../../core/utils/layout_constants.dart';
import '../../../core/utils/responsive_breakpoints.dart';
import '../../../shared/widgets/shimmer_placeholder.dart';
import '../../explore/presentation/view_all_screen.dart';
import '../../explore/presentation/widgets/explore_carousel.dart';
import '../../explore/presentation/widgets/media_horizontal_list.dart';

/// Stremio Add-ons settings destination — management and discovery.
class AddonsScreen extends ConsumerStatefulWidget {
  final int initialTab;
  final bool isEmbedded;

  const AddonsScreen({super.key, this.initialTab = 0, this.isEmbedded = false});

  @override
  ConsumerState<AddonsScreen> createState() => _AddonsScreenState();
}

class _AddonsScreenState extends ConsumerState<AddonsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTab.clamp(0, 1);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initial,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(deviceProfileProvider).asData?.value;
    final isTv = profile?.isTv == true || context.isTv;
    final isWidescreen = isTv || context.isTabletOrLarger;

    final content = Column(
      children: [
        // Inline header matching library and widescreen dashboard screens
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            height: LayoutConstants.dashboardHeaderHeight,
            padding: const EdgeInsets.symmetric(
              horizontal: LayoutConstants.dashboardContentPadding,
            ),
            child: Row(
              children: [
                Text(
                  'Stremio Add-ons',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                // Tab chips
                _buildTabChips(context),
              ],
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _tabController.index,
            children: const [AddonManageView(), _DiscoverTab()],
          ),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return content;
    }

    if (isWidescreen) {
      return Scaffold(backgroundColor: Colors.transparent, body: content);
    }

    // Mobile layout: Standard AppBar with TabBar
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stremio Add-ons'),
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'My add-ons', icon: Icon(Icons.extension_rounded)),
            Tab(text: 'Discover', icon: Icon(Icons.travel_explore_rounded)),
          ],
        ),
      ),
      body: IndexedStack(
        index: _tabController.index,
        children: const [AddonManageView(), _DiscoverTab()],
      ),
    );
  }

  Widget _buildTabChips(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TabChip(
              label: 'My add-ons',
              icon: Icons.extension_rounded,
              selected: _tabController.index == 0,
              onTap: () => _tabController.animateTo(0),
              theme: theme,
            ),
            const SizedBox(width: 8),
            _TabChip(
              label: 'Discover',
              icon: Icons.travel_explore_rounded,
              selected: _tabController.index == 1,
              onTap: () => _tabController.animateTo(1),
              theme: theme,
            ),
          ],
        );
      },
    );
  }
}

class _TabChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final ThemeData theme;

  const _TabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  @override
  State<_TabChip> createState() => _TabChipState();
}

class _TabChipState extends State<_TabChip> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final isTraditional =
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    final showHighlight = _isFocused && isTraditional;
    final scale = showHighlight ? 1.04 : 1.0;

    return Focus(
      onFocusChange: (f) {
        if (mounted) setState(() => _isFocused = f);
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: widget.selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.15)
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
              borderRadius: BorderRadius.circular(LayoutConstants.radiusPill),
              border: showHighlight
                  ? Border.all(color: theme.colorScheme.primary, width: 2)
                  : (widget.selected
                        ? Border.all(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.3,
                            ),
                          )
                        : Border.all(color: Colors.transparent, width: 1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 16,
                  color: widget.selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: widget.selected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: widget.selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hides the platform scrollbar — replaced by a gradient edge hint.
class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class AddonCatalogsTabView extends ConsumerStatefulWidget {
  final ScrollController? scrollController;
  final FocusNode? firstActionFocusNode;
  final void Function(HeroCarouselController)? onControllerReady;

  const AddonCatalogsTabView({
    super.key,
    this.scrollController,
    this.firstActionFocusNode,
    this.onControllerReady,
  });

  @override
  ConsumerState<AddonCatalogsTabView> createState() =>
      _AddonCatalogsTabViewState();
}

class _AddonCatalogsTabViewState extends ConsumerState<AddonCatalogsTabView>
    with AutomaticKeepAliveClientMixin {
  late final ScrollController _scrollController;
  bool _createdInternalScrollController = false;
  final ValueNotifier<bool> _showBottomFade = ValueNotifier(false);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.scrollController != null) {
      _scrollController = widget.scrollController!;
    } else {
      _scrollController = ScrollController();
      _createdInternalScrollController = true;
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    if (_createdInternalScrollController) {
      _scrollController.dispose();
    }
    _showBottomFade.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final showFade = maxScroll > 0 && currentScroll < maxScroll - 10;
    if (showFade != _showBottomFade.value) {
      _showBottomFade.value = showFade;
    }
  }

  Widget _withGradientEdgeHint(Widget scrollView) {
    return Stack(
      children: [
        ScrollConfiguration(
          behavior: const _NoScrollbarBehavior(),
          child: scrollView,
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 48,
          child: ValueListenableBuilder<bool>(
            valueListenable: _showBottomFade,
            builder: (context, show, _) {
              if (!show) return const SizedBox.shrink();
              final surfaceColor = Theme.of(context).colorScheme.surface;
              return IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        surfaceColor.withValues(alpha: 0.0),
                        surfaceColor.withValues(alpha: 0.15),
                        surfaceColor.withValues(alpha: 0.45),
                        surfaceColor.withValues(alpha: 0.8),
                        surfaceColor,
                      ],
                      stops: const [0.0, 0.5, 0.75, 0.9, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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

    if (catalogs.isEmpty) {
      return const _EmptyHint(
        icon: Icons.grid_view_rounded,
        title: 'No catalogs',
        message:
            'None of your add-ons publish browsable catalogs. '
            'Cinemeta or a streaming-catalogs add-on will fill this.',
      );
    }

    final firstCatalog = catalogs.first;
    final listCatalogs = catalogs.length > 1
        ? catalogs.skip(1).toList()
        : catalogs;

    return _withGradientEdgeHint(
      RefreshIndicator(
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
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // 1. Hero Carousel from the top catalog
            SliverToBoxAdapter(
              child: _CatalogCarouselSection(
                catalog: firstCatalog,
                scrollController: _scrollController,
                onNavigateUp: () => widget.firstActionFocusNode?.requestFocus(),
                onControllerReady: widget.onControllerReady,
              ),
            ),

            // 2. Stream warning banner if no streaming add-on installed
            if (!state.isLoading && !hasStreamAddon)
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer.withValues(
                      alpha: 0.5,
                    ),
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
              ),

            // 3. Catalog Rows using MediaHorizontalList
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index >= listCatalogs.length) return null;
                return _CatalogRow(entry: listCatalogs[index]);
              }, childCount: listCatalogs.length),
            ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }
}

class _CatalogCarouselSection extends ConsumerWidget {
  final BrowsableCatalog catalog;
  final ScrollController scrollController;
  final VoidCallback? onNavigateUp;
  final void Function(HeroCarouselController)? onControllerReady;

  const _CatalogCarouselSection({
    required this.catalog,
    required this.scrollController,
    this.onNavigateUp,
    this.onControllerReady,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(
      addonCatalogItemsProvider(
        catalog.addon.manifestUrl,
        catalog.catalog.type,
        catalog.catalog.id,
      ),
    );

    return itemsAsync.when(
      loading: () => _buildCarouselShimmer(context),
      error: (_, _) => const SizedBox.shrink(),
      data: (result) {
        if (result.failed || result.items.isEmpty) {
          return const SizedBox.shrink();
        }
        final heroItems = result.items
            .where(
              (i) =>
                  (i.background != null && i.background!.isNotEmpty) ||
                  (i.poster != null && i.poster!.isNotEmpty),
            )
            .take(7)
            .toList();
        if (heroItems.isEmpty) return const SizedBox.shrink();

        final mediaList = heroItems.map((e) => e.toMultimediaItem()).toList();
        final previewMap = {for (final item in heroItems) item.id: item};

        return ExploreCarousel(
          movies: mediaList,
          scrollController: scrollController,
          onNavigateUp: onNavigateUp,
          onControllerReady: onControllerReady,
          onTap: (item) {
            final preview = previewMap[item.url];
            final type =
                preview?.type ??
                (item.contentType == MultimediaContentType.series
                    ? 'series'
                    : 'movie');
            AddonDetailRoute(
              type: type,
              id: item.url,
              addonUrl: catalog.addon.manifestUrl,
            ).push<void>(context);
          },
        );
      },
    );
  }
}

Widget _buildCarouselShimmer(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final heroHeight = size.height * 0.60;
  final isDesktop =
      size.width > LayoutConstants.exploreCarouselDesktopBreakpoint;

  if (isDesktop) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LayoutConstants.dashboardContentPadding,
        vertical: LayoutConstants.spacingSm,
      ),
      child: SizedBox(
        height: heroHeight,
        width: double.infinity,
        child: ShimmerPlaceholder(borderRadius: 18),
      ),
    );
  } else {
    return SizedBox(
      height: heroHeight,
      width: double.infinity,
      child: ShimmerPlaceholder.rectangular(
        width: double.infinity,
        height: heroHeight,
        borderRadius: 0,
      ),
    );
  }
}

Widget _buildListShimmer(BuildContext context) {
  final isDesktop = context.isDesktop;
  final cardWidth = isDesktop ? 200.0 : 130.0;
  final imageHeight = cardWidth / (2 / 3);
  final listHeight = imageHeight + 40.0;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: EdgeInsets.fromLTRB(
          isDesktop
              ? LayoutConstants.dashboardContentPadding
              : LayoutConstants.spacingMd,
          LayoutConstants.spacingLg,
          isDesktop
              ? LayoutConstants.dashboardContentPadding
              : LayoutConstants.spacingMd,
          LayoutConstants.spacingSm,
        ),
        child: ShimmerPlaceholder.rectangular(
          width: 150,
          height: 24,
          borderRadius: 4,
        ),
      ),
      const SizedBox(height: LayoutConstants.spacingMd),
      SizedBox(
        height: listHeight,
        child: ListView.separated(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop
                ? LayoutConstants.dashboardContentPadding
                : LayoutConstants.spacingMd,
          ),
          scrollDirection: Axis.horizontal,
          itemCount: 8,
          separatorBuilder: (_, _) => SizedBox(
            width: isDesktop
                ? LayoutConstants.spacingLg
                : LayoutConstants.spacingSm,
          ),
          itemBuilder: (context, index) {
            return ShimmerPlaceholder(borderRadius: 12);
          },
        ),
      ),
    ],
  );
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
      loading: () => _buildListShimmer(context),
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

        final mediaList = items.map((e) => e.toMultimediaItem()).toList();
        final previewMap = {for (final item in items) item.id: item};

        return MediaHorizontalList(
          title: entry.title,
          mediaList: mediaList,
          category: ViewAllCategory.providerContent,
          showViewAll: true,
          heroTagPrefix: 'addon_${entry.addon.id}_${entry.catalog.id}',
          onViewAll: () => AddonCatalogRoute(
            addonUrl: entry.addon.manifestUrl,
            type: entry.catalog.type,
            catalogId: entry.catalog.id,
            title: entry.title,
          ).push<void>(context),
          onTap: (mediaItem) {
            final preview = previewMap[mediaItem.url];
            final type =
                preview?.type ??
                (mediaItem.contentType == MultimediaContentType.series
                    ? 'series'
                    : 'movie');
            AddonDetailRoute(
              type: type,
              id: mediaItem.url,
              addonUrl: entry.addon.manifestUrl,
            ).push<void>(context);
          },
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
