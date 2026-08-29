import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
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
  @override
  ViewAllState build(ViewAllCategory category) {
    ref.watch(languageProvider);
    ref.watch(exploreFilterProvider);
    return ViewAllState(category: category);
  }

  void init(List<MultimediaItem> initialItems) {
    if (state.items.isEmpty && state.page == 1) {
      // Provider content has no TMDB pagination — show only the initial items.
      final noMore = category == ViewAllCategory.providerContent;
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
          // Provider content is fully loaded at init — no pagination.
          state = state.copyWith(hasMore: false, isLoading: false);
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
      state = state.copyWith(isLoading: false);
    }
  }
}
