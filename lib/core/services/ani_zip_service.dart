import 'package:dio/dio.dart';

import '../logger/app_logger.dart';

/// One episode of an ani.zip mapping (`https://api.ani.zip/mappings`).
class AniZipEpisode {
  const AniZipEpisode({
    this.title,
    this.nativeTitle,
    this.image,
    this.overview,
    this.rating,
    this.runtime,
    this.airDate,
    this.airedAt,
  });

  /// English title, else the romanised one.
  final String? title;

  /// Japanese title.
  final String? nativeTitle;
  final String? image;

  /// The overview, else the summary.
  final String? overview;
  final double? rating;

  /// Minutes: `runtime`, else `length`.
  final int? runtime;

  /// `airDate` as ani.zip writes it (`2022-09-18`).
  final String? airDate;

  /// `airDateUtc`, in UTC.
  final DateTime? airedAt;
}

/// The episodes of an ani.zip mapping, keyed by episode number (absolute for long shows). Specials, whose keys are not
/// numbers (`S1`), are left out.
Map<int, AniZipEpisode> parseAniZipEpisodes(Map<String, dynamic> json) {
  final raw = json['episodes'];
  if (raw is! Map) return const {};
  String? text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;
  final out = <int, AniZipEpisode>{};
  for (final entry in raw.entries) {
    final number = int.tryParse('${entry.key}');
    final ep = entry.value;
    if (number == null || ep is! Map) continue;
    final title = ep['title'] is Map
        ? ep['title'] as Map
        : const <String, Object?>{};
    final rating = ep['rating'];
    final runtime = ep['runtime'] ?? ep['length'];
    out[number] = AniZipEpisode(
      title: text(title['en']) ?? text(title['x-jat']),
      nativeTitle: text(title['ja']),
      image: text(ep['image']),
      overview: text(ep['overview']) ?? text(ep['summary']),
      rating: switch (rating) {
        final num n => n.toDouble(),
        final String s => double.tryParse(s),
        _ => null,
      },
      runtime: runtime is num ? runtime.toInt() : null,
      airDate: text(ep['airDate']),
      airedAt: DateTime.tryParse(text(ep['airDateUtc']) ?? '')?.toUtc(),
    );
  }
  return out;
}

/// Fetches ani.zip episode data by AniList or MAL id, once per id for the session. Never throws: a failure or a
/// timeout is logged and answers no episodes.
class AniZipService {
  AniZipService(this._dio, {this.timeout = const Duration(seconds: 8)});

  final Dio _dio;
  final Duration timeout;
  final _cache = <String, Map<int, AniZipEpisode>>{};

  Future<Map<int, AniZipEpisode>> episodes({int? anilistId, int? malId}) async {
    final query = anilistId != null
        ? {'anilist_id': anilistId}
        : malId != null
        ? {'mal_id': malId}
        : null;
    if (query == null) return const {};
    final key = '${query.keys.single}:${query.values.single}';
    final cached = _cache[key];
    if (cached != null) return cached;
    try {
      final response = await _dio
          .get<Map<String, dynamic>>(
            'https://api.ani.zip/mappings',
            queryParameters: query,
          )
          .timeout(timeout);
      final data = response.data;
      if (data == null) return const {};
      return _cache[key] = parseAniZipEpisodes(data);
    } catch (error) {
      talker.warning('[AniZip] episodes for $key failed: $error');
      return const {};
    }
  }
}
