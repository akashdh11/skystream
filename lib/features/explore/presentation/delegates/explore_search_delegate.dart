import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../../shared/widgets/cards_wrapper.dart';
import '../../data/explore_mode_provider.dart';

class ExploreSearchDelegate extends SearchDelegate<void> {
  final FocusNode _firstSuggestionFocusNode = FocusNode();
  final FocusNode _firstResultFocusNode = FocusNode();

  ExploreSearchDelegate()
    : super(
        searchFieldLabel: 'Search movies, tv shows...',
        searchFieldStyle: null,
      ) {
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final currentFocusWidget =
          FocusManager.instance.primaryFocus?.context?.widget;
      if (currentFocusWidget is EditableText) {
        if (_firstSuggestionFocusNode.canRequestFocus) {
          _firstSuggestionFocusNode.requestFocus();
          return true;
        } else if (_firstResultFocusNode.canRequestFocus) {
          _firstResultFocusNode.requestFocus();
          return true;
        }
      }
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _firstSuggestionFocusNode.dispose();
    _firstResultFocusNode.dispose();
    super.dispose();
  }

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

    return _SearchResultsGrid(
      query: query,
      firstItemFocusNode: _firstResultFocusNode,
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) return const SizedBox.shrink();

    return _SearchSuggestionsList(
      query: query,
      firstItemFocusNode: _firstSuggestionFocusNode,
    );
  }
}

class _SearchSuggestionsList extends ConsumerStatefulWidget {
  final String query;
  final FocusNode? firstItemFocusNode;

  const _SearchSuggestionsList({
    required this.query,
    this.firstItemFocusNode,
  });

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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final item = suggestions[index];
        final title = item.title;
        final year = item.releaseDate.split('-').first;
        final mediaType = item.mediaType;
        final posterUrl = item.thumbnailImageUrl.isNotEmpty
            ? item.thumbnailImageUrl
            : item.posterImageUrl;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: CardsWrapper(
            focusNode: index == 0 ? widget.firstItemFocusNode : null,
            scaleFactor: 1.02,
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              _navigateToItem(
                context,
                item,
                heroTag: 'search_${item.url}',
                isStremioMode:
                    ref.read(exploreModeProvider) == ExploreModeType.stremio,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.25,
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: posterUrl,
                      width: 52,
                      height: 76,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => ShimmerPlaceholder(borderRadius: 8),
                      errorWidget: (_, _, _) => Container(
                        width: 52,
                        height: 76,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: const Icon(Icons.movie_outlined, size: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (mediaType.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer
                                      .withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  mediaType.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSecondaryContainer,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (year.isNotEmpty)
                              Text(
                                year,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
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
  final FocusNode? firstItemFocusNode;

  const _SearchResultsGrid({
    required this.query,
    this.firstItemFocusNode,
  });

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
          focusNode: index == 0 ? widget.firstItemFocusNode : null,
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
