import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/services/tmdb_service.dart';
import 'explore_language_provider.dart';
import 'explore_filter_provider.dart';
import 'explore_mode_provider.dart';

import '../../../core/network/dio_client_provider.dart';
import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/models/tmdb_genre.dart';

part 'explore_tmdb_provider.g.dart';

@Riverpod(keepAlive: true)
TmdbService tmdbService(Ref ref) {
  return TmdbService(ref.watch(dioClientProvider));
}

@Riverpod(keepAlive: true)
Future<List<TmdbGenre>> genres(Ref ref) async {
  final isAnime = ref.watch(exploreModeProvider) == ExploreModeType.anime;
  if (isAnime) {
    final animeGenres = [
      'Action',
      'Adventure',
      'Comedy',
      'Drama',
      'Ecchi',
      'Fantasy',
      'Horror',
      'Mahou Shoujo',
      'Mecha',
      'Music',
      'Mystery',
      'Psychological',
      'Romance',
      'Sci-Fi',
      'Slice of Life',
      'Sports',
      'Supernatural',
      'Thriller',
    ];
    return animeGenres
        .asMap()
        .entries
        .map((e) => TmdbGenre(id: e.key, name: e.value))
        .toList();
  }

  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final isEnglish = lang == 'en-US';

  final futures = [
    service.getGenres(language: lang),
    service.getTvGenres(language: lang),
    if (!isEnglish) service.getGenres(language: 'en-US'),
    if (!isEnglish) service.getTvGenres(language: 'en-US'),
  ];
  final results = await Future.wait(futures);

  final enFallback = <int, String>{};
  if (!isEnglish) {
    for (final g in [...results[2], ...results[3]]) {
      enFallback[g.id] = g.name;
    }
  }

  final seen = <int>{};
  final merged = <TmdbGenre>[];
  for (final g in [...results[0], ...results[1]]) {
    if (seen.add(g.id)) {
      final fallback = enFallback[g.id] ?? '';
      merged.add(g.name.isNotEmpty ? g : g.withName(fallback));
    }
  }
  merged.removeWhere((g) => g.name.isEmpty);
  merged.sort((a, b) => a.name.compareTo(b.name));
  return merged;
}

@riverpod
Future<List<MultimediaItem>> trendingMovies(Ref ref) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(exploreFilterProvider);
  return service.getTrending(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
}

@riverpod
Future<List<MultimediaItem>> popularMovies(Ref ref) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(exploreFilterProvider);
  return service.getPopularMovies(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
}

@riverpod
Future<List<MultimediaItem>> nowPlayingMovies(Ref ref) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(exploreFilterProvider);
  return service.getNowPlayingMovies(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
}

@riverpod
Future<List<MultimediaItem>> topRatedMovies(Ref ref) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(exploreFilterProvider);
  return service.getTopRated(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
}

@riverpod
Future<List<MultimediaItem>> trendingTV(Ref ref) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(exploreFilterProvider);
  return service.getTrendingTV(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
}

@riverpod
Future<List<MultimediaItem>> popularTV(Ref ref) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(exploreFilterProvider);
  return service.getPopularTV(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
}

@riverpod
Future<List<MultimediaItem>> topRatedTV(Ref ref) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(exploreFilterProvider);
  return service.getTopRatedTV(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
}

@riverpod
Future<List<MultimediaItem>> onTheAirTV(Ref ref) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(exploreFilterProvider);
  return service.getOnTheAirTV(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
}

@riverpod
Future<List<MultimediaItem>> airingTodayTV(Ref ref) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(exploreFilterProvider);
  return service.getAiringTodayTV(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
}

@riverpod
Future<List<MultimediaItem>> exploreHeroMovie(Ref ref) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(exploreFilterProvider);

  var trending = await service.getTrendingAllDay(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );

  final mediaItems = trending
      .where(
        (m) =>
            m.contentType == MultimediaContentType.movie ||
            m.contentType == MultimediaContentType.series,
      )
      .toList();

  if (mediaItems.length < 3 && lang != 'en-US') {
    trending = await service.getTrendingAllDay(language: 'en-US');
  }

  final topMovies = trending
      .where(
        (m) =>
            m.contentType == MultimediaContentType.movie ||
            m.contentType == MultimediaContentType.series,
      )
      .take(5)
      .toList();

  if (topMovies.isEmpty) return [];

  final svc = ref.read(tmdbServiceProvider);

  final enriched = await Future.wait(
    topMovies.map((movie) async {
      try {
        final tmdbType = movie.contentType == MultimediaContentType.series
            ? 'tv'
            : 'movie';
        final details = await svc.getDetailsForCarousel(
          movie.id,
          tmdbType,
          language: lang,
        );

        if (details == null) return movie;

        String? logoUrl;
        if (details['images'] != null) {
          final logos = List<Map<String, dynamic>>.from(
            ((details['images'] as Map<String, dynamic>)['logos'] as List?) ??
                const <dynamic>[],
          );
          logoUrl = TmdbService.pickBestLogo(logos, lang);
        }

        String? genresStr;
        if (details['genres'] != null) {
          genresStr = List<Map<String, dynamic>>.from(
            details['genres'] as List,
          ).take(3).map((g) => g['name']).join(' • ');
        }

        return movie.copyWith(
          logoUrl: logoUrl,
          tags: genresStr != null ? [genresStr] : null,
        );
      } catch (_) {
        return movie;
      }
    }),
  );

  return enriched;
}
