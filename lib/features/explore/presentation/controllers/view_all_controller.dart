import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/extensions/base_provider.dart';
import '../../../../core/logger/app_logger.dart';
import '../../data/explore_tmdb_provider.dart';
import '../../data/explore_language_provider.dart';
import '../../data/explore_filter_provider.dart';
import '../view_all_screen.dart'; // for ViewAllCategory

part 'view_all_controller.g.dart';

class ViewAllState {
  final ViewAllCategory? category;
  final List<MultimediaItem> items;
  final int page;
  final bool isLoading;
  final bool hasMore;

  const ViewAllState({
    this.category,
    this.items = const [],
    this.page = 1,
    this.isLoading = false,
    this.hasMore = true,
  });

  ViewAllState copyWith({
    ViewAllCategory? category,
    List<MultimediaItem>? items,
    int? page,
    bool? isLoading,
    bool? hasMore,
  }) {
    return ViewAllState(
      category: category ?? this.category,
      items: items ?? this.items,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

@riverpod
class ViewAllController extends _$ViewAllController {
  /// Page N of a provider's home row, for [ViewAllCategory.providerContent];
  /// see [SkyStreamProvider.getHomeSection].
  Future<HomeSectionPage?> Function(int page)? _loadPage;

  /// The URLs listed so far: a provider's pages can overlap.
  final Set<String> _seen = {};

  @override
  ViewAllState build(ViewAllCategory category) {
    ref.watch(languageProvider);
    ref.watch(exploreFilterProvider);
    _seen.clear();
    return ViewAllState(category: category);
  }

  /// [loadPage] pages provider content; without it, provider content shows
  /// only [initialItems].
  void init(
    List<MultimediaItem> initialItems, {
    Future<HomeSectionPage?> Function(int page)? loadPage,
  }) {
    if (state.items.isEmpty && state.page == 1) {
      _loadPage = loadPage;
      _seen.addAll(initialItems.map((item) => item.url));
      final noMore =
          category == ViewAllCategory.providerContent && loadPage == null;
      state = state.copyWith(items: List.from(initialItems), hasMore: !noMore);
    }
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    try {
      final tmdbService = ref.read(tmdbServiceProvider);
      final lang = ref.read(languageProvider);
      final filters = ref.read(exploreFilterProvider);
      final bool isEmpty = state.items.isEmpty;
      final nextPage = isEmpty ? 1 : state.page + 1;
      List<MultimediaItem> newItems = [];

      switch (category) {
        case ViewAllCategory.popularMovies:
          newItems = await tmdbService.getPopularMovies(
            language: lang,
            genreId: filters.selectedGenre?.id,
            year: filters.selectedYear,
            minRating: filters.minRating,
            page: nextPage,
          );
          break;
        case ViewAllCategory.popularTV:
          newItems = await tmdbService.getPopularTV(
            language: lang,
            genreId: filters.selectedGenre?.id,
            year: filters.selectedYear,
            minRating: filters.minRating,
            page: nextPage,
          );
          break;
        case ViewAllCategory.nowPlayingMovies:
          newItems = await tmdbService.getNowPlayingMovies(
            language: lang,
            genreId: filters.selectedGenre?.id,
            year: filters.selectedYear,
            minRating: filters.minRating,
            page: nextPage,
          );
          break;
        case ViewAllCategory.onTheAirTV:
          newItems = await tmdbService.getOnTheAirTV(
            language: lang,
            genreId: filters.selectedGenre?.id,
            year: filters.selectedYear,
            minRating: filters.minRating,
            page: nextPage,
          );
          break;
        case ViewAllCategory.topRatedMovies:
          newItems = await tmdbService.getTopRated(
            language: lang,
            genreId: filters.selectedGenre?.id,
            year: filters.selectedYear,
            minRating: filters.minRating,
            page: nextPage,
          );
          break;
        case ViewAllCategory.topRatedTV:
          newItems = await tmdbService.getTopRatedTV(
            language: lang,
            genreId: filters.selectedGenre?.id,
            year: filters.selectedYear,
            minRating: filters.minRating,
            page: nextPage,
          );
          break;
        case ViewAllCategory.airingTodayTV:
          newItems = await tmdbService.getAiringTodayTV(
            language: lang,
            genreId: filters.selectedGenre?.id,
            year: filters.selectedYear,
            minRating: filters.minRating,
            page: nextPage,
          );
          break;
        case ViewAllCategory.trending:
          newItems = await tmdbService.getTrending(
            language: lang,
            genreId: filters.selectedGenre?.id,
            year: filters.selectedYear,
            minRating: filters.minRating,
            page: nextPage,
          );
          break;
        case ViewAllCategory.trendingTV:
          newItems = await tmdbService.getTrendingTV(
            language: lang,
            genreId: filters.selectedGenre?.id,
            year: filters.selectedYear,
            minRating: filters.minRating,
            page: nextPage,
          );
          break;
        case ViewAllCategory.providerContent:
          final page = await _loadPage?.call(nextPage);
          if (!ref.mounted) return;
          if (page == null) {
            // This provider can't page its home rows.
            state = state.copyWith(hasMore: false, isLoading: false);
            return;
          }
          final fresh = [
            for (final item in page.items)
              if (_seen.add(item.url)) item,
          ];
          state = state.copyWith(
            items: [...state.items, ...fresh],
            page: nextPage,
            isLoading: false,
            // A page with nothing new ends it too: a provider that ignores the
            // page number would repeat its first page forever.
            hasMore: page.hasNext && fresh.isNotEmpty,
          );
          return;
      }

      if (newItems.isEmpty) {
        state = state.copyWith(hasMore: false, isLoading: false);
      } else {
        state = state.copyWith(
          items: [...state.items, ...newItems],
          page: nextPage,
          isLoading: false,
        );
      }
    } catch (e) {
      if (!ref.mounted) return;
      if (category == ViewAllCategory.providerContent) {
        // Not asked again on every scroll; opening the list again retries.
        talker.warning('View all: loading page ${state.page + 1} failed: $e');
        state = state.copyWith(isLoading: false, hasMore: false);
        return;
      }
      state = state.copyWith(isLoading: false);
    }
  }
}
