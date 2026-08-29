import 'dart:async';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/tmdb_config.dart';
import '../../network/dio_client_provider.dart';

part 'nuvio_tmdb.g.dart';

/// TMDB key used by the Nuvio tab and handed to Nuvio scrapers.
///
/// Nuvio plugins are addressed by TMDB id and most of them call TMDB directly,
/// so they need a key of their own. It is kept separate from the app-wide TMDB
/// key (Settings → General) and falls back to it when left empty.
@Riverpod(keepAlive: true)
class NuvioTmdbKey extends _$NuvioTmdbKey {
  static const String _prefsKey = 'nuvio_tmdb_api_key';

  @override
  String build() {
    Future.microtask(_load);
    return '';
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey) ?? '';
      state = saved;
      TmdbConfig.setNuvioApiKey(saved);
    } catch (_) {
      state = '';
    }
  }

  Future<void> set(String key) async {
    state = key.trim();
    TmdbConfig.setNuvioApiKey(state);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (state.isEmpty) {
        await prefs.remove(_prefsKey);
      } else {
        await prefs.setString(_prefsKey, state);
      }
    } catch (_) {
      // Session-only fallback.
    }
  }
}

/// The key actually used: the Nuvio one when set, otherwise the app's.
@Riverpod(keepAlive: true)
String effectiveNuvioTmdbKey(Ref ref) {
  final own = ref.watch(nuvioTmdbKeyProvider);
  return own.isNotEmpty ? own : TmdbConfig.apiKey;
}

class NuvioEpisode {
  final int season;
  final int episode;
  final String name;
  final String? overview;
  final String? stillUrl;

  const NuvioEpisode({
    required this.season,
    required this.episode,
    required this.name,
    this.overview,
    this.stillUrl,
  });
}

@Riverpod(keepAlive: true)
NuvioTmdbService nuvioTmdbService(Ref ref) => NuvioTmdbService(
  ref.watch(dioClientProvider),
  () => ref.read(effectiveNuvioTmdbKeyProvider),
);

/// TMDB helper for Nuvio scrapers — IMDB ID resolution and season/episode lists.
class NuvioTmdbService {
  NuvioTmdbService(this._dio, this._key);

  final Dio _dio;
  final String Function() _key;

  static const String _base = 'https://api.themoviedb.org/3';

  bool get hasKey => _key().isNotEmpty;

  final Map<String, String> _imdbToTmdb = {};

  /// Nuvio scrapers expect a numeric TMDB id. When all we have is an IMDb id
  /// (add-on catalogues, Trakt imports, Stremio-style ids) resolve it the same
  /// way Nuvio does — `/find/{imdb}` — and remember the answer.
  Future<String?> tmdbIdForImdbId(String imdbId, {required String type}) async {
    final trimmed = imdbId.trim();
    if (!trimmed.startsWith('tt')) return trimmed;
    final cacheKey = '$trimmed|$type';
    final cached = _imdbToTmdb[cacheKey];
    if (cached != null) return cached;

    final key = _key();
    if (key.isEmpty) return null;

    final response = await _dio.get<dynamic>(
      '$_base/find/$trimmed',
      queryParameters: {'api_key': key, 'external_source': 'imdb_id'},
      options: Options(
        receiveTimeout: const Duration(seconds: 15),
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    final data = response.data;
    if (data is! Map) return null;
    final bucket = type == 'tv' ? 'tv_results' : 'movie_results';
    final results = data[bucket] is List && (data[bucket] as List).isNotEmpty
        ? data[bucket] as List
        : (data['movie_results'] is List &&
                  (data['movie_results'] as List).isNotEmpty
              ? data['movie_results'] as List
              : data['tv_results'] as List? ?? const []);
    if (results.isEmpty) return null;
    final first = results.first;
    if (first is! Map) return null;
    final id = first['id']?.toString();
    if (id == null || id.isEmpty) return null;
    _imdbToTmdb[cacheKey] = id;
    return id;
  }

  /// Season numbers of a show (specials excluded).
  Future<List<int>> seasons(int tmdbId) async {
    final key = _key();
    if (key.isEmpty) return const [];
    final response = await _dio.get<dynamic>(
      '$_base/tv/$tmdbId',
      queryParameters: {'api_key': key},
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    final data = response.data;
    if (data is! Map) return const [];
    final seasons = data['seasons'];
    if (seasons is! List) return const [];
    final out = <int>[];
    for (final entry in seasons) {
      if (entry is! Map) continue;
      final number = (entry['season_number'] as num?)?.toInt();
      if (number != null && number > 0) out.add(number);
    }
    out.sort();
    return out;
  }

  Future<List<NuvioEpisode>> episodes(int tmdbId, int season) async {
    final key = _key();
    if (key.isEmpty) return const [];
    final response = await _dio.get<dynamic>(
      '$_base/tv/$tmdbId/season/$season',
      queryParameters: {'api_key': key},
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    final data = response.data;
    if (data is! Map) return const [];
    final episodes = data['episodes'];
    if (episodes is! List) return const [];

    final out = <NuvioEpisode>[];
    for (final entry in episodes) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final number = (map['episode_number'] as num?)?.toInt();
      if (number == null) continue;
      final still = map['still_path'] as String?;
      out.add(
        NuvioEpisode(
          season: season,
          episode: number,
          name: (map['name'] as String?) ?? 'Episode $number',
          overview: map['overview'] as String?,
          stillUrl: still == null
              ? null
              : 'https://image.tmdb.org/t/p/w300$still',
        ),
      );
    }
    return out;
  }

  /// Confirms a key works, so the field can show a result immediately.
  Future<bool> verify(String key) async {
    if (key.trim().isEmpty) return false;
    final response = await _dio.get<dynamic>(
      '$_base/configuration',
      queryParameters: {'api_key': key.trim()},
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return response.statusCode == 200;
  }
}

class NuvioTmdbException implements Exception {
  final String message;
  const NuvioTmdbException(this.message);
  @override
  String toString() => message;
}
