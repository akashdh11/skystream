import 'dart:async';

import '../domain/entity/multimedia_item.dart';
import 'package:dio/dio.dart';
import '../models/tmdb_genre.dart';
import '../config/tmdb_config.dart';
import '../logger/app_logger.dart';

class TmdbService {
  static final _yearRegex = RegExp(r'\b(19|20)\d{2}\b');
  static const _suggestionsCacheTtl = Duration(days: 1);
  static const _detailsCacheTtl = Duration(hours: 1);
  final Dio _dio;
  final Map<String, _SuggestionCacheEntry> _suggestionsCache = {};
  final Map<String, _CacheEntry<Map<String, dynamic>>> _seasonDetailsCache = {};
  final Map<String, _CacheEntry<Map<String, dynamic>>> _tvExtraCache = {};
  final Map<String, Future<Map<String, dynamic>?>> _inFlightRequests = {};

  TmdbService(Dio baseDio)
    : _dio = Dio(baseDio.options.copyWith(baseUrl: TmdbConfig.baseUrl)) {
    _dio.httpClientAdapter = baseDio.httpClientAdapter;
    _dio.interceptors.addAll(baseDio.interceptors);
  }

  Future<List<TmdbGenre>> getGenres({String language = 'en-US'}) async {
    if (TmdbConfig.apiKey.isEmpty) {
      talker.warning('TmdbService.getGenres: No TMDB API key configured');
      return [];
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/genre/movie/list',
        queryParameters: {'api_key': TmdbConfig.apiKey, 'language': language},
      );
      if (response.statusCode == 200 && response.data != null) {
        return (response.data!['genres'] as List)
            .map((dynamic i) => TmdbGenre.fromJson(i as Map<String, dynamic>))
            .toList();
      }
      talker.warning('TmdbService.getGenres: status ${response.statusCode}');
    } catch (e, st) {
      talker.error('TmdbService.getGenres failed', e, st);
    }
    return [];
  }

  Future<List<TmdbGenre>> getTvGenres({String language = 'en-US'}) async {
    if (TmdbConfig.apiKey.isEmpty) {
      talker.warning('TmdbService.getTvGenres: No TMDB API key configured');
      return [];
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/genre/tv/list',
        queryParameters: {'api_key': TmdbConfig.apiKey, 'language': language},
      );
      if (response.statusCode == 200 && response.data != null) {
        return (response.data!['genres'] as List)
            .map((dynamic i) => TmdbGenre.fromJson(i as Map<String, dynamic>))
            .toList();
      }
      talker.warning('TmdbService.getTvGenres: status ${response.statusCode}');
    } catch (e, st) {
      talker.error('TmdbService.getTvGenres failed', e, st);
    }
    return [];
  }

  /// Lightweight detail fetch for the hero carousel — only appends images,
  /// skipping credits/videos/translations to keep the call fast.
  Future<Map<String, dynamic>?> getDetailsForCarousel(
    int id,
    String mediaType, {
    String language = 'en-US',
  }) async {
    if (TmdbConfig.apiKey.isEmpty) return null;
    try {
      final langCode = language.split('-')[0];
      final response = await _dio.get<Map<String, dynamic>>(
        '/$mediaType/$id',
        queryParameters: {
          'api_key': TmdbConfig.apiKey,
          'language': 'en-US',
          'append_to_response': 'images',
          'include_image_language': '$langCode,null,en',
        },
      );
      if (response.statusCode == 200) return response.data;
      talker.warning(
        'TmdbService.getDetailsForCarousel: status ${response.statusCode} for $mediaType $id',
      );
    } catch (e, st) {
      talker.error(
        'TmdbService.getDetailsForCarousel failed for $mediaType $id',
        e,
        st,
      );
    }
    return null;
  }

  /// Returns a language-appropriate minimum vote count to avoid empty results
  /// for regional languages that have fewer TMDB entries.
  static int minVoteCount(String fullLanguageCode) {
    final iso = fullLanguageCode.split('-')[0].toLowerCase();
    const regional = {'kn', 'ml', 'bn', 'mr', 'pa', 'gu', 'or', 'as'};
    const major = {
      'hi',
      'ta',
      'te',
      'es',
      'fr',
      'de',
      'it',
      'ja',
      'ko',
      'ru',
      'pt',
      'zh',
      'tr',
      'ar',
      'pl',
      'nl',
      'sv',
    };
    if (iso == 'en') return 100;
    if (major.contains(iso)) return 25;
    if (regional.contains(iso)) return 10;
    return 25;
  }

  /// Shared pattern: use discover endpoint when filters are active, otherwise
  /// fall back to the simpler direct endpoint.
  Future<List<MultimediaItem>> _fetchWithFilterFallback({
    required String discoverPath,
    required String directPath,
    required String sortBy,
    String language = 'en-US',
    int? genreId,
    int? year,
    double? minRating,
    int page = 1,
    Map<String, dynamic>? additionalParams,
  }) async {
    final hasFilters =
        language != 'en-US' ||
        genreId != null ||
        year != null ||
        minRating != null;
    if (hasFilters) {
      return _getDiscoveryResults(
        discoverPath,
        language,
        sortBy,
        genreId: genreId,
        year: year,
        minRating: minRating,
        page: page,
        additionalParams: additionalParams,
      );
    }
    return _getResults(directPath, language: language, page: page);
  }

  Future<List<MultimediaItem>> getTrending({
    String language = 'en-US',
    int? genreId,
    int? year,
    double? minRating,
    int page = 1,
  }) => _fetchWithFilterFallback(
    discoverPath: '/discover/movie',
    directPath: '/trending/all/day',
    sortBy: 'popularity.desc',
    language: language,
    genreId: genreId,
    year: year,
    minRating: minRating,
    page: page,
  );

  Future<List<MultimediaItem>> getPopularMovies({
    String language = 'en-US',
    int? genreId,
    int? year,
    double? minRating,
    int page = 1,
  }) => _getDiscoveryResults(
    '/discover/movie',
    language,
    'popularity.desc',
    genreId: genreId,
    year: year,
    minRating: minRating,
    page: page,
  );

  Future<List<MultimediaItem>> getTopRated({
    String language = 'en-US',
    int? genreId,
    int? year,
    double? minRating,
    int page = 1,
  }) => _getDiscoveryResults(
    '/discover/movie',
    language,
    'vote_average.desc',
    genreId: genreId,
    year: year,
    minRating: minRating,
    page: page,
  );

  Future<List<MultimediaItem>> getNowPlayingMovies({
    String language = 'en-US',
    int? genreId,
    int? year,
    double? minRating,
    int page = 1,
  }) {
    final today = DateTime.now().toString().split(' ')[0];
    final extra = <String, dynamic>{'release_date.lte': today};
    if (genreId != null ||
        year != null ||
        minRating != null ||
        language != 'en-US') {
      return _getDiscoveryResults(
        '/discover/movie',
        language,
        'release_date.desc',
        genreId: genreId,
        year: year,
        minRating: minRating,
        page: page,
        additionalParams: extra,
      );
    }
    return _getResults('/movie/now_playing', language: language, page: page);
  }

  Future<List<MultimediaItem>> getTrendingMovies({
    String language = 'en-US',
    int? genreId,
    int? year,
    double? minRating,
    int page = 1,
  }) => _fetchWithFilterFallback(
    discoverPath: '/discover/movie',
    directPath: '/trending/movie/week',
    sortBy: 'popularity.desc',
    language: language,
    genreId: genreId,
    year: year,
    minRating: minRating,
    page: page,
  );

  Future<List<MultimediaItem>> getTrendingAllDay({
    String language = 'en-US',
    int? genreId,
    int? year,
    double? minRating,
    int page = 1,
  }) => _fetchWithFilterFallback(
    discoverPath: '/discover/movie',
    directPath: '/trending/all/day',
    sortBy: 'popularity.desc',
    language: language,
    genreId: genreId,
    year: year,
    minRating: minRating,
    page: page,
  );

  Future<List<MultimediaItem>> getTrendingTV({
    String language = 'en-US',
    int? genreId,
    int? year,
    double? minRating,
    int page = 1,
  }) => _fetchWithFilterFallback(
    discoverPath: '/discover/tv',
    directPath: '/trending/tv/week',
    sortBy: 'popularity.desc',
    language: language,
    genreId: genreId,
    year: year,
    minRating: minRating,
    page: page,
  );

  Future<List<MultimediaItem>> getOnTheAirTV({
    String language = 'en-US',
    int? genreId,
    int? year,
    double? minRating,
    int page = 1,
  }) => _fetchWithFilterFallback(
    discoverPath: '/discover/tv',
    directPath: '/tv/on_the_air',
    sortBy: 'popularity.desc',
    language: language,
    genreId: genreId,
    year: year,
    minRating: minRating,
    page: page,
  );

  Future<List<MultimediaItem>> getPopularTV({
    String language = 'en-US',
    int? genreId,
    int? year,
    double? minRating,
    int page = 1,
  }) => _getDiscoveryResults(
    '/discover/tv',
    language,
    'popularity.desc',
    genreId: genreId,
    year: year,
    minRating: minRating,
    page: page,
  );

  Future<List<MultimediaItem>> getTopRatedTV({
    String language = 'en-US',
    int? genreId,
    int? year,
    double? minRating,
    int page = 1,
  }) => _getDiscoveryResults(
    '/discover/tv',
    language,
    'vote_average.desc',
    genreId: genreId,
    year: year,
    minRating: minRating,
    page: page,
  );

  Future<List<MultimediaItem>> getAiringTodayTV({
    String language = 'en-US',
    int? genreId,
    int? year,
    double? minRating,
    int page = 1,
  }) => _fetchWithFilterFallback(
    discoverPath: '/discover/tv',
    directPath: '/tv/airing_today',
    sortBy: 'first_air_date.desc',
    language: language,
    genreId: genreId,
    year: year,
    minRating: minRating,
    page: page,
  );

  Future<List<MultimediaItem>> multiSearch({
    required String query,
    String language = 'en-US',
    int page = 1,
  }) async {
    // --- Advanced Search Parsing ---
    String cleanQuery = query;
    int? filterYear;
    String? filterLanguageCode;

    final yearMatch = _yearRegex.firstMatch(cleanQuery);
    if (yearMatch != null) {
      filterYear = int.tryParse(yearMatch.group(0)!);
      // Remove year from query to improve search relevance
      cleanQuery = cleanQuery
          .replaceAll(yearMatch.group(0)!, '')
          .replaceAll('()', '')
          .trim();
    }

    // 2. Extract Language (e.g., "Kannada", "Tamil")
    final languageMap = {
      'kannada': 'kn',
      'tamil': 'ta',
      'telugu': 'te',
      'hindi': 'hi',
      'malayalam': 'ml',
      'english': 'en',
      'korean': 'ko',
      'japanese': 'ja',
    };

    for (final key in languageMap.keys) {
      if (cleanQuery.toLowerCase().contains(key)) {
        filterLanguageCode = languageMap[key];
        // Remove language name using case-insensitive replace
        cleanQuery = cleanQuery
            .replaceAll(RegExp(key, caseSensitive: false), '')
            .trim();
        break; // Assume single language filter
      }
    }

    // If query became empty (e.g. user just typed "2023"), revert to original but keep filters
    if (cleanQuery.isEmpty) cleanQuery = query;

    // Clean up double spaces
    cleanQuery = cleanQuery.replaceAll(RegExp(r'\s+'), ' ');

    if (TmdbConfig.apiKey.isEmpty) return [];

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/search/multi',
        queryParameters: {
          'api_key': TmdbConfig.apiKey,
          'language': language,
          'query': cleanQuery,
          'page': page,
          'include_adult': false,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final rawResults = List<Map<String, dynamic>>.from(
          response.data!['results'] as List,
        );

        final List<Map<String, dynamic>> processedResults = [];

        // Process results to handle 'person' type and flatten 'known_for'
        for (final item in rawResults) {
          final mediaType = item['media_type'];

          if (mediaType == 'person') {
            // Hero Search: Extract movies from person's known_for
            if (item['known_for'] != null) {
              final knownFor = List<Map<String, dynamic>>.from(
                item['known_for'] as List,
              );
              for (final known in knownFor) {
                // known_for items often miss media_type, infer if possible or default to movie
                known['media_type'] ??= 'movie';
                processedResults.add(known);
              }
            }
          } else if (mediaType == 'movie' || mediaType == 'tv') {
            processedResults.add(item);
          }
        }
        final today = DateTime.now();

        final finalResults = processedResults.where((item) {
          final mediaType = item['media_type'];
          if (mediaType != 'movie' && mediaType != 'tv') return false;

          // --- Filter 1: Release Status (Existing logic) ---
          String? dateStr;
          if (mediaType == 'movie') {
            dateStr = item['release_date'] as String?;
          } else if (mediaType == 'tv') {
            dateStr = item['first_air_date'] as String?;
          }
          if (dateStr == null || dateStr.isEmpty) return false;

          // --- Filter 2: Year (New) ---
          if (filterYear != null) {
            try {
              final date = DateTime.parse(dateStr);
              // Allow +/- 1 year tolerance or exact match
              // Actually strict year match is better for "Mark 2025"
              if (date.year != filterYear) return false;
            } catch (_) {
              return false;
            }
          }

          // --- Filter 3: Language (New) ---
          if (filterLanguageCode != null) {
            final originalLang = item['original_language'];
            if (originalLang != filterLanguageCode) return false;
          }

          // Future date check
          try {
            final date = DateTime.parse(dateStr);
            return date.isBefore(today);
          } catch (e) {
            return false;
          }
        }).toList();

        // Deduplicate results based on ID (Person's known_for might duplicate direct search results)
        final seenParams = <String>{}; // unique key: id + type
        final uniqueResults = <Map<String, dynamic>>[];
        for (final item in finalResults) {
          final key = '${item['id']}_${item['media_type']}';
          if (!seenParams.contains(key)) {
            seenParams.add(key);
            uniqueResults.add(item);
          }
        }

        return uniqueResults
            .map((i) => MultimediaItem.fromTmdbJson(i))
            .toList();
      }
      talker.warning('TmdbService.multiSearch: status ${response.statusCode}');
    } catch (e, st) {
      talker.error('TmdbService.multiSearch failed for "$cleanQuery"', e, st);
    }
    return [];
  }

  /// Fetches search suggestions from TMDB multi-search.
  ///
  /// Returns title-only suggestions for movie/tv results, deduplicated and
  /// capped to 10 items.
  Future<List<String>> getSuggestions({
    required String query,
    String language = 'en-US',
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];
    if (TmdbConfig.apiKey.isEmpty) return [];

    final cacheKey = '${language.toLowerCase()}|${trimmed.toLowerCase()}';
    final cached = _suggestionsCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.cachedAt) < _suggestionsCacheTtl) {
      return cached.suggestions;
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/search/multi',
        queryParameters: {
          'api_key': TmdbConfig.apiKey,
          'query': trimmed,
          'language': language,
          'include_adult': false,
        },
      );

      if (response.statusCode != 200 || response.data == null) return [];

      final results = List<Map<String, dynamic>>.from(
        (response.data!['results'] as List?) ?? const <dynamic>[],
      );

      final seen = <String>{};
      final suggestions = <String>[];
      for (final item in results) {
        final mediaType = item['media_type']?.toString();
        if (mediaType != 'movie' && mediaType != 'tv') continue;

        final title = (item['title'] ?? item['name'])?.toString().trim();
        if (title == null || title.isEmpty) continue;

        if (seen.add(title)) {
          suggestions.add(title);
          if (suggestions.length == 10) break;
        }
      }

      _suggestionsCache[cacheKey] = _SuggestionCacheEntry(
        suggestions: suggestions,
        cachedAt: DateTime.now(),
      );

      return suggestions;
    } catch (e, st) {
      talker.error('TmdbService.getSuggestions failed for "$trimmed"', e, st);
      return [];
    }
  }

  Future<List<MultimediaItem>> _getDiscoveryResults(
    String path,
    String fullLanguageCode,
    String sortBy, {
    Map<String, dynamic>? additionalParams,
    int? genreId,
    int? year,
    double? minRating,
    int page = 1,
  }) async {
    final isoCode = fullLanguageCode.split('-')[0];
    final today = DateTime.now().toString().split(' ')[0];
    final isMovie = path.contains('movie');

    final query = <String, dynamic>{
      'api_key': TmdbConfig.apiKey,
      'language': 'en-US', // Always show titles in English per user request
      'sort_by': sortBy,
      'page': page,
      'include_null_first_air_dates': false,
      // Skip vote threshold for recency-sorted queries so new releases
      // (especially regional language films with few votes yet) show up.
      if (!sortBy.contains('release_date') &&
          !sortBy.contains('first_air_date'))
        'vote_count.gte': minVoteCount(fullLanguageCode),
      // Content Filter: Original Language
      if (fullLanguageCode != 'en-US') 'with_original_language': isoCode,
      // Content Filter: Released Only (Fix for user request)
      if (isMovie) 'release_date.lte': today,
      if (!isMovie) 'first_air_date.lte': today,
      ...?additionalParams,
    };

    // Add nullable filters
    if (genreId != null) query['with_genres'] = genreId;
    if (year != null) {
      query[isMovie ? 'primary_release_year' : 'first_air_date_year'] = year;
    }
    if (minRating != null) query['vote_average.gte'] = minRating;

    if (TmdbConfig.apiKey.isEmpty) {
      talker.warning(
        'TmdbService: No TMDB API key configured for discovery on $path',
      );
      return [];
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: query,
      );

      if (response.statusCode == 200 && response.data != null) {
        return (response.data!['results'] as List)
            .map((i) => MultimediaItem.fromTmdbJson(i as Map<String, dynamic>))
            .toList();
      }
      talker.warning(
        'TmdbService discovery on $path: status ${response.statusCode}',
      );
    } catch (e, st) {
      talker.error('TmdbService discovery failed on $path', e, st);
    }
    return [];
  }

  /// Helper to reduce boilerplate
  Future<List<MultimediaItem>> _getResults(
    String path, {
    String language = 'en-US',
    int page = 1,
  }) async {
    if (TmdbConfig.apiKey.isEmpty) {
      talker.warning('TmdbService: No TMDB API key configured for $path');
      return [];
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: {
          'api_key': TmdbConfig.apiKey,
          'language': language,
          'page': page,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return (response.data!['results'] as List)
            .map((i) => MultimediaItem.fromTmdbJson(i as Map<String, dynamic>))
            .toList();
      }
      talker.warning(
        'TmdbService request on $path: status ${response.statusCode}',
      );
    } catch (e, st) {
      talker.error('TmdbService request failed on $path', e, st);
    }
    return [];
  }

  Future<String?> getBestLogo(
    int id, {
    String language = 'en',
    String mediaType = 'movie',
  }) async {
    if (TmdbConfig.apiKey.isEmpty) return null;

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/$mediaType/$id/images',
        queryParameters: {
          'api_key': TmdbConfig.apiKey,
          'include_image_language': '$language,null,en',
        },
      );

      final data = response.data;
      if (response.statusCode == 200 && data != null) {
        final logos = List<Map<String, dynamic>>.from(
          (data['logos'] as List?) ?? const <dynamic>[],
        );
        return pickBestLogo(logos, language);
      }
      talker.warning(
        'TmdbService.getBestLogo: status ${response.statusCode} for $mediaType $id',
      );
    } catch (e, st) {
      talker.error('TmdbService.getBestLogo failed for $mediaType $id', e, st);
    }
    return null;
  }

  /// Reusable logic to pick the best logo from a list of TMDB logo objects.
  static String? pickBestLogo(
    List<Map<String, dynamic>> logos,
    String language,
  ) {
    if (logos.isEmpty) return null;

    // Normalize language (e.g., 'en-US' -> 'en')
    final langCode = language.split('-')[0];

    // Helper to find logo matching criteria
    Map<String, dynamic> findLogo(bool Function(Map<String, dynamic>) test) {
      return logos.firstWhere(test, orElse: () => {});
    }

    var bestLogo = <String, dynamic>{};

    // --- Priority 1: Exact Language Match (PNG > SVG) ---
    bestLogo = findLogo(
      (l) =>
          l['iso_639_1'] == langCode &&
          l['file_path'].toString().endsWith('.png'),
    );
    if (bestLogo.isEmpty) {
      bestLogo = findLogo(
        (l) =>
            l['iso_639_1'] == langCode &&
            l['file_path'].toString().endsWith('.svg'),
      );
    }

    // --- Priority 2: English (PNG > SVG) ---
    // Moved above Textless because usually we want a readable title if exact match fails
    if (bestLogo.isEmpty && langCode != 'en') {
      bestLogo = findLogo(
        (l) =>
            l['iso_639_1'] == 'en' &&
            l['file_path'].toString().endsWith('.png'),
      );
    }
    if (bestLogo.isEmpty && langCode != 'en') {
      bestLogo = findLogo(
        (l) =>
            l['iso_639_1'] == 'en' &&
            l['file_path'].toString().endsWith('.svg'),
      );
    }

    // --- Priority 3: International / Textless (iso_639_1 == null) (PNG > SVG) ---
    if (bestLogo.isEmpty) {
      bestLogo = findLogo(
        (l) =>
            l['iso_639_1'] == null &&
            l['file_path'].toString().endsWith('.png'),
      );
    }
    if (bestLogo.isEmpty) {
      bestLogo = findLogo(
        (l) =>
            l['iso_639_1'] == null &&
            l['file_path'].toString().endsWith('.svg'),
      );
    }

    // --- Priority 4: Any Wide PNG ---
    if (bestLogo.isEmpty) {
      bestLogo = findLogo((l) => (((l['aspect_ratio'] as num?) ?? 0) > 1));
    }

    // --- Fallback ---
    if (bestLogo.isEmpty) {
      bestLogo = logos.first;
    }

    if (bestLogo.isNotEmpty && bestLogo['file_path'] != null) {
      return '${TmdbConfig.imageBaseUrl}${bestLogo['file_path']}';
    }
    return null;
  }

  Future<Map<String, dynamic>?> getMovieDetails(
    int movieId, {
    String language = 'en-US',
  }) async {
    if (TmdbConfig.apiKey.isEmpty) return null;

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/movie/$movieId',
        queryParameters: {
          'api_key': TmdbConfig.apiKey,
          'language': language,
          'append_to_response': 'credits,release_dates',
        },
      );
      if (response.statusCode == 200) {
        return response.data;
      }
      talker.warning(
        'TmdbService.getMovieDetails: status ${response.statusCode} for $movieId',
      );
    } catch (e, st) {
      talker.error('TmdbService.getMovieDetails failed for $movieId', e, st);
    }
    return null;
  }

  Future<Map<String, dynamic>?> getMovieExtra(
    int movieId, {
    String language = 'en-US',
  }) async {
    if (TmdbConfig.apiKey.isEmpty) return null;

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/movie/$movieId',
        queryParameters: {
          'api_key': TmdbConfig.apiKey,
          'language': language,
          'append_to_response': 'videos,images,translations,external_ids',
          'include_image_language': '$language,null,en',
        },
      );
      if (response.statusCode == 200) {
        return response.data;
      }
      talker.warning(
        'TmdbService.getMovieExtra: status ${response.statusCode} for $movieId',
      );
    } catch (e, st) {
      talker.error('TmdbService.getMovieExtra failed for $movieId', e, st);
    }
    return null;
  }

  /// Helper to fetch specific credits if not using append_to_response
  Future<Map<String, dynamic>?> getCredits(
    int movieId, {
    String language = 'en-US',
  }) async {
    if (TmdbConfig.apiKey.isEmpty) return null;

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/movie/$movieId/credits',
        queryParameters: {'api_key': TmdbConfig.apiKey, 'language': language},
      );
      if (response.statusCode == 200) {
        return response.data;
      }
      talker.warning(
        'TmdbService.getCredits: status ${response.statusCode} for $movieId',
      );
    } catch (e, st) {
      talker.error('TmdbService.getCredits failed for $movieId', e, st);
    }
    return null;
  }

  Future<Map<String, dynamic>?> getTvDetails(
    int tvId, {
    String language = 'en-US',
  }) async {
    if (TmdbConfig.apiKey.isEmpty) return null;

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/tv/$tvId',
        queryParameters: {
          'api_key': TmdbConfig.apiKey,
          'language': language,
          'append_to_response': 'credits,content_ratings',
        },
      );
      if (response.statusCode == 200) {
        return response.data;
      }
      talker.warning(
        'TmdbService.getTvDetails: status ${response.statusCode} for $tvId',
      );
    } catch (e, st) {
      talker.error('TmdbService.getTvDetails failed for $tvId', e, st);
    }
    return null;
  }

  bool _isTransientError(dynamic e) {
    if (e is DioException) {
      final msg = e.error?.toString() ?? e.message ?? '';
      return e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError ||
          msg.contains('HandshakeException') ||
          msg.contains('SocketException') ||
          msg.contains('Connection terminated') ||
          msg.contains('ClientException');
    }
    return false;
  }

  Future<Map<String, dynamic>?> getTvExtra(
    int tvId, {
    String language = 'en-US',
  }) async {
    if (TmdbConfig.apiKey.isEmpty) return null;

    final cacheKey = '$tvId:$language';
    final cached = _tvExtraCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.cachedAt) < _detailsCacheTtl) {
      return cached.data;
    }

    if (_inFlightRequests.containsKey(cacheKey)) {
      return await _inFlightRequests[cacheKey];
    }

    final future = _fetchTvExtra(tvId, language: language, cacheKey: cacheKey);
    _inFlightRequests[cacheKey] = future;
    try {
      return await future;
    } finally {
      unawaited(_inFlightRequests.remove(cacheKey));
    }
  }

  Future<Map<String, dynamic>?> _fetchTvExtra(
    int tvId, {
    required String language,
    required String cacheKey,
  }) async {
    int attempts = 0;
    while (attempts < 3) {
      attempts++;
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          '/tv/$tvId',
          queryParameters: {
            'api_key': TmdbConfig.apiKey,
            'language': language,
            'append_to_response': 'videos,images,translations,external_ids',
            'include_image_language': '$language,null,en',
          },
        );
        if (response.statusCode == 200 && response.data != null) {
          _tvExtraCache[cacheKey] = _CacheEntry(response.data!, DateTime.now());
          return response.data;
        }
        talker.warning(
          'TmdbService.getTvExtra: status ${response.statusCode} for $tvId',
        );
        return null;
      } catch (e, st) {
        if (attempts < 3 && _isTransientError(e)) {
          await Future<void>.delayed(Duration(milliseconds: 300 * attempts));
          continue;
        }
        talker.error('TmdbService.getTvExtra failed for $tvId', e, st);
        break;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> getTvSeasonDetails(
    int tvId,
    int seasonNumber, {
    String language = 'en-US',
  }) async {
    if (TmdbConfig.apiKey.isEmpty) return null;

    final cacheKey = '$tvId:$seasonNumber:$language';
    final cached = _seasonDetailsCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.cachedAt) < _detailsCacheTtl) {
      return cached.data;
    }

    if (_inFlightRequests.containsKey(cacheKey)) {
      return await _inFlightRequests[cacheKey];
    }

    final future = _fetchTvSeasonDetails(
      tvId,
      seasonNumber,
      language: language,
      cacheKey: cacheKey,
    );
    _inFlightRequests[cacheKey] = future;
    try {
      return await future;
    } finally {
      unawaited(_inFlightRequests.remove(cacheKey));
    }
  }

  Future<Map<String, dynamic>?> _fetchTvSeasonDetails(
    int tvId,
    int seasonNumber, {
    required String language,
    required String cacheKey,
  }) async {
    int attempts = 0;
    while (attempts < 3) {
      attempts++;
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          '/tv/$tvId/season/$seasonNumber',
          queryParameters: {'api_key': TmdbConfig.apiKey, 'language': language},
        );
        if (response.statusCode == 200 && response.data != null) {
          _seasonDetailsCache[cacheKey] = _CacheEntry(
            response.data!,
            DateTime.now(),
          );
          return response.data;
        }
        talker.warning(
          'TmdbService.getTvSeasonDetails: status ${response.statusCode} for $tvId S$seasonNumber',
        );
        return null;
      } catch (e, st) {
        if (attempts < 3 && _isTransientError(e)) {
          await Future<void>.delayed(Duration(milliseconds: 300 * attempts));
          continue;
        }
        talker.error(
          'TmdbService.getTvSeasonDetails failed for $tvId S$seasonNumber',
          e,
          st,
        );
        break;
      }
    }
    return null;
  }
}

class _CacheEntry<T> {
  final T data;
  final DateTime cachedAt;

  const _CacheEntry(this.data, this.cachedAt);
}

class _SuggestionCacheEntry {
  final List<String> suggestions;
  final DateTime cachedAt;

  const _SuggestionCacheEntry({
    required this.suggestions,
    required this.cachedAt,
  });
}
