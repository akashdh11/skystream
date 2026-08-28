import 'package:flutter/material.dart';
import '../../../../core/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/utils/layout_constants.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../../../../shared/widgets/multimedia_card.dart';

import '../controllers/explore_search_controller.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../core/providers/device_info_provider.dart';
import '../../../../core/utils/responsive_breakpoints.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/addons/models/addon_meta.dart' show kAddonItemSource;
import '../../data/explore_mode_provider.dart';

class ExploreSearchDelegate extends SearchDelegate<void> {
  ExploreSearchDelegate()
    : super(
        searchFieldLabel: 'Search movies, tv shows...',
        searchFieldStyle: null,
      );

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        toolbarHeight: 70,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        border: InputBorder.none,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: theme.colorScheme.primary,
        selectionColor: theme.colorScheme.primary.withValues(alpha: 0.3),
      ),
      textTheme: theme.textTheme.copyWith(
        titleMedium: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 18,
        ),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
      const SizedBox(width: 8),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.isEmpty) return const SizedBox.shrink();

    return _SearchResultsGrid(query: query);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) return const SizedBox.shrink();

    return _SearchSuggestionsList(query: query);
  }
}

class _SearchSuggestionsList extends ConsumerStatefulWidget {
  final String query;

  const _SearchSuggestionsList({required this.query});

  @override
  ConsumerState<_SearchSuggestionsList> createState() =>
      _SearchSuggestionsListState();
}

class _SearchSuggestionsListState
    extends ConsumerState<_SearchSuggestionsList> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(exploreSearchControllerProvider.notifier)
          .onQueryChanged(widget.query);
    });
  }

  @override
  void didUpdateWidget(covariant _SearchSuggestionsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      Future.microtask(() {
        if (!context.mounted) return;
        ref
            .read(exploreSearchControllerProvider.notifier)
            .onQueryChanged(widget.query);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(exploreSearchControllerProvider);
    final isLoading = searchState.isLoading;
    final suggestions = searchState.suggestions;
    if (isLoading) {
      return Center(
        child: AppLoadingIndicator(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
        ),
      );
    }

    if (suggestions.isEmpty) {
      return Center(
        child: Text(
          'No results found',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final item = suggestions[index];
        final title = item.title;
        final year = item.releaseDate.split('-').first;
        final mediaType = item.mediaType;

        return Material(
          type: MaterialType.transparency,
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: item.thumbnailImageUrl,
                width: 40,
                height: 60,
                fit: BoxFit.cover,
                placeholder: (_, _) => ShimmerPlaceholder(borderRadius: 4),
              ),
            ),
            title: Text(
              title,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            subtitle: Text(
              '$mediaType ${year.isNotEmpty ? '($year)' : ''}',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            onTap: () {
              _navigateToItem(
                context,
                item,
                heroTag: 'search_${item.url}',
                isStremioMode:
                    ref.read(exploreModeProvider) == ExploreModeType.stremio,
              );
            },
          ),
        );
      },
    );
  }
}

void _navigateToItem(
  BuildContext context,
  MultimediaItem item, {
  String? heroTag,
  String? placeholderPoster,
  bool isStremioMode = false,
}) {
  final isAddon =
      item.source == kAddonItemSource ||
      item.url.startsWith('addon:') ||
      isStremioMode ||
      item.url.startsWith('tt') ||
      item.url.startsWith('kitsu:');

  if (isAddon) {
    final String type;
    final String id;
    final String? addonUrl;

    if (item.url.startsWith('addon:')) {
      final parts = item.url.split(':');
      type =
          parts.length >= 2
              ? parts[1]
              : (item.contentType == MultimediaContentType.series
                  ? 'series'
                  : 'movie');
      id = parts.length >= 3 ? parts[2] : item.url;
      addonUrl = parts.length > 3 ? parts.sublist(3).join(':') : null;
    } else {
      type =
          item.contentType == MultimediaContentType.series ? 'series' : 'movie';
      id = item.url;
      addonUrl = null;
    }

    AddonDetailRoute(
      type: type,
      id: id,
      addonUrl: addonUrl,
    ).push<void>(context);
    return;
  }

  TmdbDetailsRoute(
    movieId: item.id,
    mediaType: item.tmdbMediaType,
    heroTag: heroTag,
    placeholderPoster: placeholderPoster,
    source: item.source,
  ).push<void>(context);
}

class _SearchResultsGrid extends ConsumerStatefulWidget {
  final String query;

  const _SearchResultsGrid({required this.query});

  @override
  ConsumerState<_SearchResultsGrid> createState() => _SearchResultsGridState();
}

class _SearchResultsGridState extends ConsumerState<_SearchResultsGrid> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(exploreSearchControllerProvider.notifier)
          .fetchResults(widget.query);
    });
  }

  @override
  void didUpdateWidget(covariant _SearchResultsGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      Future.microtask(() {
        if (!context.mounted) return;
        ref
            .read(exploreSearchControllerProvider.notifier)
            .fetchResults(widget.query);
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(exploreSearchControllerProvider.notifier).fetchNextPage();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(exploreSearchControllerProvider);
    final isLoading = searchState.isLoading;
    final results = searchState.results;
    if (isLoading && results.isEmpty) {
      final screenWidth = MediaQuery.sizeOf(context).width;
      final isDesktop =
          screenWidth > LayoutConstants.exploreCarouselDesktopBreakpoint;
      final maxExtent = isDesktop ? 240.0 : 150.0;
      const childAspectRatio = 0.55;

      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxExtent,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 10,
        itemBuilder: (context, index) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: ShimmerPlaceholder(borderRadius: 12)),
              const SizedBox(height: 8),
              ShimmerPlaceholder.rectangular(height: 14, borderRadius: 4),
            ],
          );
        },
      );
    }

    if (results.isEmpty) {
      final profile = ref.watch(deviceProfileProvider).asData?.value;
      final isTv = profile?.isTv == true || context.isTv;
      final isWidescreen = isTv || context.isTabletOrLarger;
      final imageWidth = isWidescreen ? 320.0 : 200.0;
      final nativeFont = Theme.of(context).textTheme.bodyLarge?.fontFamily;

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No Results Found',
              style: TextStyle(
                fontFamily: nativeFont,
                fontSize: 16.0,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Image.asset(
              'assets/images/no_results.png',
              fit: BoxFit.contain,
              width: imageWidth,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop =
        screenWidth > LayoutConstants.exploreCarouselDesktopBreakpoint;
    final maxExtent = isDesktop ? 240.0 : 150.0;
    const childAspectRatio = 0.55;

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxExtent,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: results.length + (isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= results.length) {
          return ShimmerPlaceholder(borderRadius: 12);
        }

        final item = results[index];
        final imageUrl = item.posterImageUrl;
        final title = item.title;
        final id = item.id;
        final uniqueTag = 'search_result_${id != 0 ? id : item.url}_$index';

        return MultimediaCard(
          imageUrl: imageUrl,
          title: title,
          heroTag: uniqueTag,
          onTap: () {
            _navigateToItem(
              context,
              item,
              heroTag: uniqueTag,
              placeholderPoster: imageUrl,
              isStremioMode:
                  ref.read(exploreModeProvider) == ExploreModeType.stremio,
            );
          },
        );
      },
    );
  }
}
