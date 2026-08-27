import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/tmdb_config.dart';
import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/services/tmdb_service.dart';
import 'stream_aggregator.dart';

/// Reuses the same [TmdbService] shape as Explore. Kept alive so switching
/// tabs doesn't refetch the catalogue on every visit.
final tmdbClientProvider = Provider<TmdbService>((ref) {
  return TmdbService(ref.watch(dioClientProvider));
});

final streamAggregatorProvider = Provider<StreamAggregator>((ref) {
  return StreamAggregator();
});

/// Thrown when the TMDB catalogue can't be loaded, with a message that tells
/// the user *why* instead of a bare "no results" dead end.
class StreamCatalogException implements Exception {
  final String message;
  const StreamCatalogException(this.message);
  @override
  String toString() => message;
}

enum StreamTab { movies, series }

class StreamBrowserState {
  final AsyncValue<List<MultimediaItem>> movies;
  final AsyncValue<List<MultimediaItem>> series;

  /// Search results are kept separate from the browse catalogue so clearing
  /// the query restores the previous grid instantly without a refetch.
  final AsyncValue<List<MultimediaItem>>? searchResults;
  final String query;
  final int tabIndex;

  const StreamBrowserState({
    this.movies = const AsyncLoading(),
    this.series = const AsyncLoading(),
    this.searchResults,
    this.query = '',
    this.tabIndex = 0,
  });

  bool get isSearching => query.trim().isNotEmpty;

  StreamBrowserState copyWith({
    AsyncValue<List<MultimediaItem>>? movies,
    AsyncValue<List<MultimediaItem>>? series,
    AsyncValue<List<MultimediaItem>>? searchResults,
    bool clearSearch = false,
    String? query,
    int? tabIndex,
  }) {
    return StreamBrowserState(
      movies: movies ?? this.movies,
      series: series ?? this.series,
      searchResults: clearSearch ? null : (searchResults ?? this.searchResults),
      query: query ?? this.query,
      tabIndex: tabIndex ?? this.tabIndex,
    );
  }
}

class StreamBrowserNotifier extends Notifier<StreamBrowserState> {
  Timer? _debounce;

  /// Guards against a slow early search overwriting a newer one.
  int _searchToken = 0;

  @override
  StreamBrowserState build() {
    ref.onDispose(() => _debounce?.cancel());
    // Kick off loading after build completes so we never mutate state while
    // the notifier is still initializing.
    Future.microtask(load);
    return const StreamBrowserState();
  }

  Future<void> load() async {
    // Fail loudly rather than rendering an empty grid: an unset key is a
    // build-configuration problem, and silently showing "no results" sent
    // people hunting for a bug in the wrong place.
    if (TmdbConfig.apiKey.isEmpty) {
      const err = StreamCatalogException(
        'No TMDB API key configured.\n\n'
        'Open Settings > General > TMDB API key and paste a free key '
        'from themoviedb.org to enable Stream.',
      );
      final trace = StackTrace.current;
      state = state.copyWith(
        movies: AsyncError(err, trace),
        series: AsyncError(err, trace),
      );
      return;
    }

    final service = ref.read(tmdbClientProvider);
    await Future.wait([_loadMovies(service), _loadSeries(service)]);
  }

  Future<void> refresh() async {
    state = state.copyWith(
      movies: const AsyncLoading(),
      series: const AsyncLoading(),
    );
    await load();
  }

  Future<void> _loadMovies(TmdbService service) async {
    try {
      final items = await service.getTrendingMovies();
      state = state.copyWith(
        movies: items.isEmpty
            ? AsyncError(
                const StreamCatalogException(
                  'TMDB returned no movies. Check your connection or API key.',
                ),
                StackTrace.current,
              )
            : AsyncData(items),
      );
    } catch (error, stack) {
      state = state.copyWith(movies: AsyncError(error, stack));
    }
  }

  Future<void> _loadSeries(TmdbService service) async {
    try {
      final items = await service.getPopularTV();
      state = state.copyWith(
        series: items.isEmpty
            ? AsyncError(
                const StreamCatalogException(
                  'TMDB returned no series. Check your connection or API key.',
                ),
                StackTrace.current,
              )
            : AsyncData(items),
      );
    } catch (error, stack) {
      state = state.copyWith(series: AsyncError(error, stack));
    }
  }

  /// Debounced so typing doesn't fire a request per keystroke.
  void search(String query) {
    state = state.copyWith(query: query);
    _debounce?.cancel();

    if (query.trim().isEmpty) {
      state = state.copyWith(clearSearch: true);
      return;
    }

    state = state.copyWith(searchResults: const AsyncLoading());
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _runSearch(query.trim());
    });
  }

  Future<void> _runSearch(String query) async {
    final token = ++_searchToken;
    try {
      final results = await ref
          .read(tmdbClientProvider)
          .multiSearch(query: query);

      // Only keep people-free, playable results.
      final filtered = results
          .where(
            (r) =>
                r.contentType == MultimediaContentType.movie ||
                r.contentType == MultimediaContentType.series ||
                r.contentType == MultimediaContentType.anime,
          )
          .toList();

      if (token != _searchToken) return;
      state = state.copyWith(searchResults: AsyncData(filtered));
    } catch (error, stack) {
      if (token != _searchToken) return;
      state = state.copyWith(searchResults: AsyncError(error, stack));
    }
  }

  void clearSearch() {
    _debounce?.cancel();
    _searchToken++;
    state = state.copyWith(query: '', clearSearch: true);
  }

  void setTab(int index) {
    if (index != state.tabIndex) state = state.copyWith(tabIndex: index);
  }
}

final streamBrowserProvider =
    NotifierProvider<StreamBrowserNotifier, StreamBrowserState>(
      StreamBrowserNotifier.new,
    );
