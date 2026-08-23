import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/extensions/extension_manager.dart';
import '../../../../core/extensions/base_provider.dart';
import '../../../../core/utils/image_fallbacks.dart';
import '../../../search/presentation/search_provider.dart';
import 'package:skystream/shared/widgets/multimedia_card.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../core/providers/device_info_provider.dart';
import '../../../../core/utils/responsive_breakpoints.dart';

class HomeSearchDelegate extends SearchDelegate<void> {
  final String? initialQuery;

  HomeSearchDelegate({this.initialQuery})
    : super(
        searchFieldLabel: 'Search movies, series...',
        searchFieldStyle: null,
      ) {
    if (initialQuery != null) {
      query = initialQuery!;
    }
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
    return _HomeSearchResults(query: query);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) return const SizedBox.shrink();
    return _HomeSearchSuggestions(
      query: query,
      onSelect: (val) {
        query = val;
        showResults(context);
      },
    );
  }
}

class _HomeSearchSuggestions extends ConsumerStatefulWidget {
  final String query;
  final void Function(String) onSelect;

  const _HomeSearchSuggestions({required this.query, required this.onSelect});

  @override
  ConsumerState<_HomeSearchSuggestions> createState() =>
      _HomeSearchSuggestionsState();
}

class _HomeSearchSuggestionsState
    extends ConsumerState<_HomeSearchSuggestions> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(searchSuggestionControllerProvider.notifier)
          .onQueryChanged(widget.query);
    });
  }

  @override
  void didUpdateWidget(covariant _HomeSearchSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      Future.microtask(() {
        if (!context.mounted) return;
        ref
            .read(searchSuggestionControllerProvider.notifier)
            .onQueryChanged(widget.query);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchSuggestionControllerProvider);
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
        final suggestion = suggestions[index];
        return Material(
          type: MaterialType.transparency,
          child: ListTile(
            leading: const Icon(Icons.search_rounded),
            title: Text(suggestion),
            trailing: IconButton(
              tooltip: 'Fill query',
              icon: const Icon(Icons.north_west_rounded),
              onPressed: () {
                widget.onSelect(suggestion);
              },
            ),
            onTap: () => widget.onSelect(suggestion),
          ),
        );
      },
    );
  }
}

class _HomeSearchResults extends ConsumerStatefulWidget {
  final String query;

  const _HomeSearchResults({required this.query});

  @override
  ConsumerState<_HomeSearchResults> createState() => _HomeSearchResultsState();
}

class _HomeSearchResultsState extends ConsumerState<_HomeSearchResults> {
  bool isLoading = true;
  ProviderSearchResult? result;

  @override
  void initState() {
    super.initState();
    _performSearch();
  }

  @override
  void didUpdateWidget(covariant _HomeSearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _performSearch();
    }
  }

  Future<void> _performSearch() async {
    setState(() {
      isLoading = true;
      result = null;
    });

    final SkyStreamProvider? provider = ref.read(activeProviderProvider);
    if (provider == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    try {
      final rawResults = await provider.search(widget.query);
      if (mounted) {
        setState(() {
          isLoading = false;
          result = ProviderSearchResult(
            providerId: provider.packageName,
            providerName: provider.name,
            results: rawResults.toList(),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: AppLoadingIndicator());
    }

    if (result == null || result!.results.isEmpty) {
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
              // Source is 1613x1929 — 11.9 MB decoded — for an illustration
              // shown at 320 logical px at most. 640 covers 2x density.
              cacheWidth: 640,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }

    final isLarge = MediaQuery.of(context).size.width > 600;
    final maxExtent = isLarge ? 200.0 : 130.0;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxExtent,
        childAspectRatio: 2 / 3.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: result!.results.length,
      itemBuilder: (context, index) {
        final item = result!.results[index];
        final uniqueTag = 'search_${result!.providerId}_${item.url}_$index';

        return MultimediaCard(
          key: ValueKey(item.url),
          imageUrl: AppImageFallbacks.poster(item.posterUrl, label: item.title),
          title: item.title,
          heroTag: uniqueTag,
          onTap: () => DetailsRoute(
            $extra: DetailsRouteExtra(item: item),
          ).push<void>(context),
        );
      },
    );
  }
}
