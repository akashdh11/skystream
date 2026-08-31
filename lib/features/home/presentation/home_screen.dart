import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_provider.dart';
import 'home_state.dart';
import 'package:skystream/features/home/presentation/widgets/continue_watching_section.dart';
import 'package:skystream/features/search/presentation/search_provider.dart';
import 'package:skystream/features/tracking/data/sync_manager.dart';
import 'package:skystream/features/tracking/domain/sync_progress_item.dart';
import 'package:skystream/features/home/presentation/widgets/synced_progress_section.dart';
import 'package:skystream/features/library/presentation/history_provider.dart';
import '../../settings/presentation/general_settings_provider.dart';
import '../../explore/presentation/widgets/explore_carousel.dart';
import '../../explore/presentation/widgets/media_horizontal_list.dart';
import '../../explore/presentation/view_all_screen.dart';
import '../../../shared/widgets/desktop_scroll_wrapper.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../extensions/providers/extensions_controller.dart';
import '../../../core/extensions/models/extension_plugin.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'package:skystream/core/extensions/extension_manager.dart';
import 'package:skystream/core/extensions/base_provider.dart';
import 'package:skystream/core/router/app_router.dart';
import 'delegates/home_search_delegate.dart';
import '../../../shared/widgets/cards_wrapper.dart';
import '../../../shared/widgets/custom_widgets.dart';
import '../../../shared/widgets/shimmer_placeholder.dart';
import '../../../../core/utils/layout_constants.dart';
import '../../../../core/utils/responsive_breakpoints.dart';
import '../../../../core/providers/device_info_provider.dart';
import 'dart:async';
import 'widgets/dashboard_header_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
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

class _HomeScreenState extends ConsumerState<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _appBarOpacityNotifier = ValueNotifier<double>(0);
  final ValueNotifier<bool> _showBottomFade = ValueNotifier(false);
  final FocusNode _firstActionFocusNode = FocusNode();

  /// Carousel controller exposed by ExploreCarousel via [onControllerReady].
  /// Used by DashboardHeaderBar arrows.
  HeroCarouselController? _carouselController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  bool _isWidescreenForScroll() {
    final profile = ref.read(deviceProfileProvider).asData?.value;
    final isTv = profile?.isTv == true || context.isTv;
    return isTv || profile?.isLargeScreen == true || context.isTabletOrLarger;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    // Track gradient edge hint visibility — fades away near the bottom.
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final showFade = maxScroll > 0 && currentScroll < maxScroll - 10;
    if (showFade != _showBottomFade.value) {
      _showBottomFade.value = showFade;
    }

    // On widescreen there is no mobile AppBar (opacity notifier).
    // Skip all work to avoid per-frame overhead that
    // can stall the rendering pipeline during bounce / direction-change.
    if (_isWidescreenForScroll()) return;

    final opacity = (_scrollController.offset * 0.8 / 300).clamp(0.0, 1.0);
    if (opacity != _appBarOpacityNotifier.value) {
      _appBarOpacityNotifier.value = opacity;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _appBarOpacityNotifier.dispose();
    _showBottomFade.dispose();
    _firstActionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final homeDataAsync = ref.watch(homeDataProvider);
    final history = ref.watch(watchHistoryProvider);
    final syncedProgressAsync = ref.watch(syncedProgressProvider);
    final generalSettings = ref.watch(generalSettingsProvider);
    final l10n = AppLocalizations.of(context)!;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayStyle = isDark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    final profile = ref.watch(deviceProfileProvider).asData?.value;
    final isTv = profile?.isTv == true || context.isTv;
    // Use profile?.isLargeScreen so this matches AppScaffold's sidebar
    // decision even when the HomeScreen's context width is narrowed
    // by the sidebar (e.g. iPad portrait).
    final isWidescreen =
        isTv || profile?.isLargeScreen == true || context.isTabletOrLarger;

    // On widescreen: no AppBar, no FAB — we use the DashboardHeaderBar instead.
    // The header lives outside the scroll view in a plain Column so there is
    // no SliverPersistentHeader / pinned-header interaction with scroll
    // physics (which was causing scroll-direction-change jitter on iPad).
    if (isWidescreen) {
      return Scaffold(
        extendBodyBehindAppBar: false,
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: DashboardHeaderBar(
                searchFocusNode: _firstActionFocusNode,
                onShowProviderSelector: () =>
                    _showProviderSelector(context, ref),
                onPrevious: _carouselController != null
                    ? () => _carouselController!.previousPage()
                    : null,
                onNext: _carouselController != null
                    ? () => _carouselController!.nextPage()
                    : null,
              ),
            ),
            Expanded(
              child: _buildBody(
                context,
                homeDataAsync,
                history,
                generalSettings.watchHistoryEnabled,
                syncedProgressAsync,
                isWidescreen: true,
              ),
            ),
          ],
        ),
      );
    }

    // Mobile layout: existing AppBar + FAB
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        systemOverlayStyle: overlayStyle,
        forceMaterialTransparency: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ValueListenableBuilder<double>(
          valueListenable: _appBarOpacityNotifier,
          // Apply the fade via the color's alpha channel rather than an
          // Opacity widget. Opacity forces a saveLayer() every frame for as
          // long as the AppBar is in the tree (even at opacity 1.0), which
          // shows up on the perf overlay as a constant raster cost. Alpha
          // blending on a Container fill costs ~0.
          builder: (context, opacity, _) => Container(
            color: Theme.of(
              context,
            ).scaffoldBackgroundColor.withValues(alpha: opacity),
          ),
        ),
        title: Text(l10n.appTitle),
        actions: [
          // 1. Search Action Button
          Padding(
            padding: const EdgeInsets.only(right: LayoutConstants.spacingSm),
            child: CardsWrapper(
              focusNode: _firstActionFocusNode,
              onTap: () {
                unawaited(
                  showSearch<void>(
                    context: context,
                    delegate: HomeSearchDelegate(),
                    useRootNavigator: false,
                    maintainState: true,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(50),
              child: CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.1),
                radius: 18,
                child: Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 18,
                ),
              ),
            ),
          ),

          // 2. Provider / Extension Pill Selector (after Search button, using matching search button design)
          Consumer(
            builder: (context, ref, _) {
              final activeProvider = ref.watch(activeProviderProvider);
              final isDebug = activeProvider?.isDebug ?? false;
              return Padding(
                padding: const EdgeInsets.only(
                  right: LayoutConstants.spacingMd,
                ),
                child: CardsWrapper(
                  onTap: () => _showProviderSelector(context, ref),
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.extension,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          activeProvider?.name ?? l10n.none,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isDebug) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              l10n.debug,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _buildBody(
        context,
        homeDataAsync,
        history,
        generalSettings.watchHistoryEnabled,
        syncedProgressAsync,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    HomeState state,
    List<dynamic> history,
    bool watchHistoryEnabled,
    AsyncValue<List<SyncProgressItem>> syncedProgressAsync, {
    bool isWidescreen = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final isResolving = ref.watch(providerResolutionLoadingProvider);

    if (isResolving) {
      return Center(
        child: AppLoadingIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    if (ref.watch(activeProviderProvider) == null) {
      return _buildNoProviderState(context, l10n, isWidescreen: isWidescreen);
    }

    return switch (state) {
      HomeLoading() => _withGradientEdgeHint(
        CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(child: _buildCarouselShimmer(context)),
            SliverToBoxAdapter(child: _buildListShimmer(context)),
            SliverToBoxAdapter(child: _buildListShimmer(context)),
            SliverToBoxAdapter(child: _buildListShimmer(context)),
          ],
        ),
      ),
      HomeNoProvider() => _buildNoProviderState(
        context,
        l10n,
        isWidescreen: isWidescreen,
      ),
      HomeOffline() => _buildErrorState(context, l10n.noInternetError, ref),
      HomeError(:final message) => _buildErrorState(context, message, ref),
      HomeSuccess(:final data) => _withGradientEdgeHint(
        RefreshIndicator(
          onRefresh: () async => ref.read(homeDataProvider.notifier).fetch(),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              if (data.containsKey('Trending'))
                SliverToBoxAdapter(
                  child: ExploreCarousel(
                    movies: data['Trending']!.take(7).toList(),
                    scrollController: _scrollController,
                    onNavigateUp: () => _firstActionFocusNode.requestFocus(),
                    onControllerReady: (c) =>
                        setState(() => _carouselController = c),
                    onTap: (item) {
                      DetailsRoute(
                        $extra: DetailsRouteExtra(item: item),
                      ).push<void>(context);
                    },
                  ),
                )
              else if (data.isNotEmpty)
                SliverToBoxAdapter(
                  child: ExploreCarousel(
                    movies: data.values.first.take(7).toList(),
                    scrollController: _scrollController,
                    onNavigateUp: () => _firstActionFocusNode.requestFocus(),
                    onControllerReady: (c) =>
                        setState(() => _carouselController = c),
                    onTap: (item) {
                      DetailsRoute(
                        $extra: DetailsRouteExtra(item: item),
                      ).push<void>(context);
                    },
                  ),
                )
              else if (!isWidescreen)
                // No carousel — add top padding so content below doesn't
                // overlap with the transparent app bar (mobile only).
                SliverPadding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + kToolbarHeight,
                  ),
                ),

              if (watchHistoryEnabled && history.isNotEmpty)
                SliverToBoxAdapter(
                  child: ContinueWatchingSection(
                    title: l10n.continueWatching,
                    items: history.cast<HistoryItem>(),
                    topPadding: isWidescreen ? 0 : null,
                  ),
                ),

              if (syncedProgressAsync.asData?.value.isNotEmpty == true)
                SliverToBoxAdapter(
                  child: SyncedProgressSection(
                    title: 'Synced from Trakt',
                    items: syncedProgressAsync.asData!.value,
                    onItemTap: (item) {
                      // Pre-fill search query and navigate to Search tab
                      ref.read(searchQueryProvider.notifier).set(item.title);
                      const SearchRoute().go(context);
                    },
                  ),
                ),

              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final filteredEntries = data.entries
                        .where((e) => e.key != 'Trending')
                        .toList();
                    if (index >= filteredEntries.length) return null;
                    final entry = filteredEntries[index];
                    return MediaHorizontalList(
                      title: entry.key,
                      mediaList: entry.value,
                      category: ViewAllCategory.providerContent,
                      showViewAll: true,
                      onTap: (item) {
                        DetailsRoute(
                          $extra: DetailsRouteExtra(item: item),
                        ).push<void>(context);
                      },
                      heroTagPrefix: 'home',
                    );
                  },
                  childCount: data.entries
                      .where((e) => e.key != 'Trending')
                      .length,
                ),
              ),

              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          ),
        ),
      ),
    };
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
          height: 48, // Taller height for smoother blend
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

  Widget _buildNoProviderState(
    BuildContext context,
    AppLocalizations l10n, {
    bool isWidescreen = false,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.extension_off_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.selectProviderToStart,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (isWidescreen) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _showProviderSelector(context, ref),
              icon: const Icon(Icons.extension_rounded),
              label: const Text('Select Provider'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    LayoutConstants.radiusPill,
                  ),
                ),
              ),
            ),
          ] else
            Text(l10n.tapExtensionIcon),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final bool isOffline = error == l10n.noInternetError;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOffline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
              size: 80,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              isOffline ? l10n.noInternetConnection : l10n.siteNotReachable,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              isOffline
                  ? l10n.checkConnectionOrDownloads
                  : l10n.tryVpnOrConnection,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (!isOffline) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  l10n.errorDetails(error),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => ref.invalidate(homeDataProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.retry),
                ),
                ElevatedButton.icon(
                  onPressed: () => const LibraryRoute().push<void>(context),
                  icon: const Icon(Icons.download_for_offline_rounded),
                  label: Text(l10n.goToDownloads),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.secondaryContainer,
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showProviderSelector(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final extManager = ref.read(extensionManagerProvider.notifier);
    final activeProvider = ref.read(activeProviderProvider);
    final providers = List<SkyStreamProvider>.from(extManager.getAllProviders())
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (providers.isEmpty) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.noPluginsInstalled),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.extension_off_rounded,
                size: 56,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.noPluginsMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.close),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.extension, size: 18),
              label: Text(l10n.goToExtensions),
              onPressed: () {
                Navigator.pop(context);
                const ExtensionsRoute().push<void>(context);
              },
            ),
          ],
        ),
      );
      return;
    }

    final scrollController = ScrollController();
    final chipsScrollController = ScrollController();
    bool didInitialScroll = false;

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.selectProvider),
          contentPadding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
          content: SizedBox(
            width: 600,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final currentFilter = ref.watch(homeFilterProvider);
                    return DesktopScrollWrapper(
                      controller: chipsScrollController,
                      isCompact: true,
                      child: SingleChildScrollView(
                        controller: chipsScrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            FilterChip(
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              label: Text(l10n.all),
                              selected: currentFilter == null,
                              onSelected: (_) => ref
                                  .read(homeFilterProvider.notifier)
                                  .setFilter(null),
                            ),
                            const SizedBox(width: 8),
                            ...ProviderType.values
                                .where((t) => t != ProviderType.other)
                                .map((type) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      label: Text(
                                        _getLocalizedType(type, l10n),
                                      ),
                                      selected: currentFilter == type,
                                      onSelected: (_) => ref
                                          .read(homeFilterProvider.notifier)
                                          .setFilter(type),
                                    ),
                                  );
                                }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const Divider(),
                Flexible(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final filter = ref.watch(homeFilterProvider);
                      final extensionsState = ref.watch(
                        extensionsControllerProvider,
                      );
                      final installedPlugins = extensionsState.installedPlugins;

                      final filteredProviders = filter == null
                          ? providers
                          : providers
                                .where((p) => p.supportedTypes.contains(filter))
                                .toList();

                      // Auto-scroll to selected provider on initial show
                      int targetIndex = -1;
                      if (activeProvider == null) {
                        if (filter == null) {
                          targetIndex = 0;
                        }
                      } else {
                        final idx = filteredProviders.indexWhere(
                          (p) => p.packageName == activeProvider.packageName,
                        );
                        if (idx != -1) {
                          targetIndex = filter == null ? idx + 1 : idx;
                        } else {
                          targetIndex = 0;
                        }
                      }

                      // If still -1 (e.g. activeProvider == null and filter != null), focus first item
                      if (targetIndex == -1) targetIndex = 0;

                      if (!didInitialScroll && targetIndex != -1) {
                        didInitialScroll = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (scrollController.hasClients) {
                            final itemTop = targetIndex * 56.0;
                            final viewportHeight =
                                scrollController.position.viewportDimension;
                            const itemHeight = 56.0;
                            final offset =
                                itemTop -
                                (viewportHeight / 2) +
                                (itemHeight / 2);
                            final maxScroll =
                                scrollController.position.maxScrollExtent;
                            scrollController.jumpTo(
                              offset.clamp(0.0, maxScroll),
                            );
                          }
                        });
                      }

                      return RadioGroup<String?>(
                        groupValue: activeProvider?.packageName,
                        onChanged: (val) {
                          final selected = val == null
                              ? null
                              : providers.firstWhere(
                                  (p) => p.packageName == val,
                                );
                          ref
                              .read(activeProviderProvider.notifier)
                              .set(selected);
                          Navigator.pop(context);
                          ref.invalidate(homeDataProvider);
                        },
                        child: Material(
                          color: Colors.transparent,
                          clipBehavior: Clip.hardEdge,
                          child: ListView.builder(
                            controller: scrollController,
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount:
                                (filter == null ? 1 : 0) +
                                filteredProviders.length,
                            itemBuilder: (context, index) {
                              if (filter == null && index == 0) {
                                return SizedBox(
                                  height: 56.0,
                                  child: Center(
                                    child: ListTile(
                                      title: Text(l10n.none),
                                      leading: const Radio<String?>(
                                        value: null,
                                      ),
                                      autofocus: index == targetIndex,
                                      onTap: () {
                                        ref
                                            .read(
                                              activeProviderProvider.notifier,
                                            )
                                            .set(null);
                                        Navigator.pop(context);
                                        ref.invalidate(homeDataProvider);
                                      },
                                    ),
                                  ),
                                );
                              }

                              final p =
                                  filteredProviders[filter == null
                                      ? index - 1
                                      : index];
                              final isDebug = p.isDebug;
                              final isSubprovider = p.packageName.contains(
                                '::',
                              );
                              String pluginTag = '';
                              if (isSubprovider) {
                                final parentPackageName = p.packageName
                                    .substring(0, p.packageName.indexOf('::'));
                                final plugin = installedPlugins
                                    .cast<ExtensionPlugin?>()
                                    .firstWhere(
                                      (pl) =>
                                          pl?.packageName == parentPackageName,
                                      orElse: () => null,
                                    );
                                pluginTag = plugin?.name ?? parentPackageName;
                              }

                              return SizedBox(
                                height: 56.0,
                                child: Center(
                                  child: ListTile(
                                    autofocus: index == targetIndex,
                                    title: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            p.name,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isSubprovider) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            constraints: const BoxConstraints(
                                              maxWidth: 120,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.secondaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              pluginTag,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSecondaryContainer,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                        if (isDebug) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              l10n.debug,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    leading: Radio<String?>(
                                      value: p.packageName,
                                    ),
                                    onTap: () {
                                      ref
                                          .read(activeProviderProvider.notifier)
                                          .set(p);
                                      Navigator.pop(context);
                                      ref.invalidate(homeDataProvider);
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            CustomButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.close),
            ),
          ],
        );
      },
    ).then((_) {
      scrollController.dispose();
      chipsScrollController.dispose();
    });
  }

  String _getLocalizedType(ProviderType type, AppLocalizations l10n) {
    switch (type) {
      case ProviderType.movie:
        return l10n.movies;
      case ProviderType.series:
        return l10n.series;
      case ProviderType.anime:
        return l10n.anime;
      case ProviderType.livestream:
        return l10n.liveStreams;
      case ProviderType.other:
        return l10n.unknown;
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
        // Title Placeholder
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
        // List Placeholder
        SizedBox(
          height: listHeight,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop
                  ? LayoutConstants.dashboardContentPadding
                  : LayoutConstants.spacingMd,
            ),
            scrollDirection: Axis.horizontal,
            itemCount: 10,
            separatorBuilder: (_, _) => SizedBox(
              width: isDesktop
                  ? LayoutConstants.spacingLg
                  : LayoutConstants.spacingSm,
            ),
            itemBuilder: (context, index) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerPlaceholder.rectangular(
                    width: cardWidth,
                    height: imageHeight,
                    borderRadius: 12,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
