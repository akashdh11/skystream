import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:dio/dio.dart';

import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/models/tmdb_details.dart';
import '../../../core/services/ani_zip_service.dart';
import '../../../core/services/anilist_explore_service.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/logger/app_logger.dart';

part 'anilist_repository.g.dart';

@Riverpod(keepAlive: true)
AnilistExploreService anilistExploreService(Ref ref) {
  return AnilistExploreService(ref.watch(dioClientProvider));
}

@Riverpod(keepAlive: true)
AnilistRepository anilistRepository(Ref ref) {
  return AnilistRepository(
    ref.watch(anilistExploreServiceProvider),
    ref.watch(dioClientProvider),
  );
}

class AnilistSectionDefinition {
  final String title;
  final String query;
  final Map<String, dynamic> variables;

  const AnilistSectionDefinition({
    required this.title,
    required this.query,
    required this.variables,
  });
}

class AnilistRepository {
  final AnilistExploreService _service;
  final Dio _dio;
  static final _unescape = HtmlUnescape();
  final Map<int, String?> _fanartCache = {};
  final Map<int, String?> _logoCache = {};

  AnilistRepository(this._service, this._dio);

  Future<Map<String, String?>> getAnimeImages(int id) async {
    if (_logoCache.containsKey(id) && _fanartCache.containsKey(id)) {
      return {'logo': _logoCache[id], 'fanart': _fanartCache[id]};
    }
    String? logoUrl;
    String? fanartUrl;
    try {
      final aniZipResponse = await _dio.get<Map<String, dynamic>>(
        'https://api.ani.zip/mappings',
        queryParameters: {'anilist_id': id},
      );
      if (aniZipResponse.statusCode == 200 && aniZipResponse.data != null) {
        final aniZipData = aniZipResponse.data!;
        final imagesList = aniZipData['images'] as List?;
        if (imagesList != null) {
          for (final img in imagesList) {
            if (img is Map) {
              if (img['coverType'] == 'Clearlogo') {
                logoUrl = img['url'] as String?;
              } else if (img['coverType'] == 'Fanart') {
                fanartUrl = img['url'] as String?;
              }
            }
          }
        }
      }
    } catch (e) {
      talker.error('AnilistRepository: Failed to fetch anime images: $e');
    }
    _logoCache[id] = logoUrl;
    _fanartCache[id] = fanartUrl;
    return {'logo': logoUrl, 'fanart': fanartUrl};
  }

  static const String mediaFragment = '''
    id
    title {
      romaji
      english
      native
    }
    coverImage {
      extraLarge
      large
      medium
      color
    }
    bannerImage
    description
    season
    seasonYear
    format
    status
    episodes
    duration
    averageScore
    genres
    nextAiringEpisode {
      airingAt
      timeUntilAiring
      episode
    }
  ''';

  static final Map<String, AnilistSectionDefinition> sections = {
    'trending': const AnilistSectionDefinition(
      title: 'Trending right now',
      query:
          '''
        query (\$page: Int, \$perPage: Int, \$genre: String, \$seasonYear: Int, \$minScore: Int) {
          Page(page: \$page, perPage: \$perPage) {
            media(sort: TRENDING_DESC, type: ANIME, genre: \$genre, seasonYear: \$seasonYear, averageScore_greater: \$minScore) {
              $mediaFragment
            }
          }
        }
      ''',
      variables: {},
    ),
    'airedRecently': const AnilistSectionDefinition(
      title: 'Aired recently',
      query:
          '''
        query (\$page: Int, \$perPage: Int, \$genre: String, \$seasonYear: Int, \$minScore: Int) {
          Page(page: \$page, perPage: \$perPage) {
            media(sort: START_DATE_DESC, type: ANIME, status_in: [FINISHED, RELEASING], genre: \$genre, seasonYear: \$seasonYear, averageScore_greater: \$minScore) {
              $mediaFragment
            }
          }
        }
      ''',
      variables: {},
    ),
    'topSeason': const AnilistSectionDefinition(
      title: 'Top of the season',
      query:
          '''
        query (\$page: Int, \$perPage: Int, \$genre: String, \$seasonYear: Int, \$minScore: Int) {
          Page(page: \$page, perPage: \$perPage) {
            media(season: SUMMER, seasonYear: \$seasonYear, sort: SCORE_DESC, type: ANIME, genre: \$genre, averageScore_greater: \$minScore) {
              $mediaFragment
            }
          }
        }
      ''',
      variables: {'seasonYear': 2025},
    ),
    'bestLastSeason': const AnilistSectionDefinition(
      title: 'Best of last season',
      query:
          '''
        query (\$page: Int, \$perPage: Int, \$genre: String, \$seasonYear: Int, \$minScore: Int) {
          Page(page: \$page, perPage: \$perPage) {
            media(season: SPRING, seasonYear: \$seasonYear, sort: SCORE_DESC, type: ANIME, genre: \$genre, averageScore_greater: \$minScore) {
              $mediaFragment
            }
          }
        }
      ''',
      variables: {'seasonYear': 2025},
    ),
    'movies': const AnilistSectionDefinition(
      title: 'Movies',
      query:
          '''
        query (\$page: Int, \$perPage: Int, \$genre: String, \$seasonYear: Int, \$minScore: Int) {
          Page(page: \$page, perPage: \$perPage) {
            media(format: MOVIE, sort: SCORE_DESC, type: ANIME, genre: \$genre, seasonYear: \$seasonYear, averageScore_greater: \$minScore) {
              $mediaFragment
            }
          }
        }
      ''',
      variables: {},
    ),
    'comingSoon': const AnilistSectionDefinition(
      title: 'Coming soon',
      query:
          '''
        query (\$page: Int, \$perPage: Int, \$genre: String, \$seasonYear: Int, \$minScore: Int) {
          Page(page: \$page, perPage: \$perPage) {
            media(status: NOT_YET_RELEASED, sort: POPULARITY_DESC, type: ANIME, genre: \$genre, seasonYear: \$seasonYear, averageScore_greater: \$minScore) {
              $mediaFragment
            }
          }
        }
      ''',
      variables: {},
    ),
  };

  MultimediaItem _mapMediaToMultimediaItem(
    Map<String, dynamic> media, {
    String? titleLang,
  }) {
    final titleObj = media['title'] as Map<String, dynamic>?;

    String title;
    if (titleLang == 'japanese' || titleLang == 'native') {
      title =
          (titleObj?['native'] ??
                  titleObj?['english'] ??
                  titleObj?['romaji'] ??
                  'Unknown Anime')
              as String;
    } else if (titleLang == 'romaji') {
      title =
          (titleObj?['romaji'] ??
                  titleObj?['english'] ??
                  titleObj?['native'] ??
                  'Unknown Anime')
              as String;
    } else {
      // Default: english
      title =
          (titleObj?['english'] ??
                  titleObj?['romaji'] ??
                  titleObj?['native'] ??
                  'Unknown Anime')
              as String;
    }

    final coverObj = media['coverImage'] as Map<String, dynamic>?;
    final posterUrl =
        (coverObj?['extraLarge'] ??
                coverObj?['large'] ??
                coverObj?['medium'] ??
                '')
            as String;
    final bannerUrl = (media['bannerImage'] ?? posterUrl) as String;

    final averageScore = (media['averageScore'] as num?)?.toDouble();
    final score = averageScore != null ? averageScore / 10.0 : null;

    final genres = (media['genres'] as List?)
        ?.map((g) => g.toString())
        .toList();
    final format = media['format'] as String?;
    final description = media['description'] as String?;

    final MultimediaContentType contentType = (format == 'MOVIE')
        ? MultimediaContentType.movie
        : MultimediaContentType.series;

    final statusStr = media['status'] as String?;
    ShowStatus status = ShowStatus.ongoing;
    if (statusStr == 'FINISHED') {
      status = ShowStatus.completed;
    } else if (statusStr == 'NOT_YET_RELEASED') {
      status = ShowStatus.upcoming;
    }

    NextAiring? nextAiring;
    final nextAiringObj = media['nextAiringEpisode'] as Map<String, dynamic>?;
    if (nextAiringObj != null) {
      nextAiring = NextAiring(
        episode: nextAiringObj['episode'] as int? ?? 0,
        unixTime: nextAiringObj['airingAt'] as int? ?? 0,
        season: 1,
      );
    }

    return MultimediaItem(
      title: title,
      url: 'anilist:${media['id']}',
      posterUrl: posterUrl,
      bannerUrl: bannerUrl,
      description: description,
      contentType: contentType,
      year: media['seasonYear'] as int?,
      score: score,
      status: status,
      tags: genres,
      tmdbId: media['id'] as int?,
      source: 'anilist',
      nextAiring: nextAiring,
    );
  }

  Future<List<MultimediaItem>> fetchSection(
    String sectionKey, {
    int page = 1,
    int perPage = 20,
    String? genre,
    int? year,
    double? minRating,
    String? titleLang,
  }) async {
    final def = sections[sectionKey];
    if (def == null) return [];

    final variables = {'page': page, 'perPage': perPage, ...def.variables};
    if (genre != null) variables['genre'] = genre;
    if (year != null) variables['seasonYear'] = year;
    if (minRating != null) variables['minScore'] = (minRating * 10).toInt();

    final response = await _service.postGraphQL(
      def.query,
      variables: variables,
    );

    if (response == null) return [];
    try {
      final data = response['data'] as Map<String, dynamic>?;
      final pageObj = data?['Page'] as Map<String, dynamic>?;
      final mediaList = pageObj?['media'] as List?;
      if (mediaList == null) return [];

      return mediaList
          .map(
            (m) => _mapMediaToMultimediaItem(
              Map<String, dynamic>.from(m as Map),
              titleLang: titleLang,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<MultimediaItem>> searchAnime(
    String query, {
    int page = 1,
    int perPage = 20,
    String? titleLang,
  }) async {
    const searchGraphQL =
        '''
      query (\$search: String, \$page: Int, \$perPage: Int) {
        Page(page: \$page, perPage: \$perPage) {
          media(search: \$search, type: ANIME, sort: SEARCH_MATCH) {
            $mediaFragment
          }
        }
      }
    ''';

    final response = await _service.postGraphQL(
      searchGraphQL,
      variables: {'search': query, 'page': page, 'perPage': perPage},
    );

    if (response == null) return [];
    try {
      final data = response['data'] as Map<String, dynamic>?;
      final pageObj = data?['Page'] as Map<String, dynamic>?;
      final mediaList = pageObj?['media'] as List?;
      if (mediaList == null) return [];

      return mediaList
          .map(
            (m) => _mapMediaToMultimediaItem(
              Map<String, dynamic>.from(m as Map),
              titleLang: titleLang,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<TmdbDetails?> getAnimeDetails(int id) async {
    const detailsGraphQL = '''
      query (\$id: Int) {
        Media(id: \$id, type: ANIME) {
          id
          title {
            romaji
            english
            native
          }
          coverImage {
            extraLarge
            large
            medium
            color
          }
          bannerImage
          description
          season
          seasonYear
          startDate {
            year
            month
            day
          }
          format
          status
          episodes
          duration
          averageScore
          genres
          nextAiringEpisode {
            airingAt
            timeUntilAiring
            episode
          }
          studios(isMain: true) {
            nodes {
              id
              name
            }
          }
          trailer {
            id
            site
          }
          characters(sort: ROLE, perPage: 15) {
            edges {
              role
              node {
                id
                name {
                  full
                }
                image {
                  large
                }
              }
              voiceActors(language: JAPANESE) {
                id
                name {
                  full
                }
                image {
                  large
                }
              }
            }
          }
        }
      }
    ''';

    final response = await _service.postGraphQL(
      detailsGraphQL,
      variables: {'id': id},
    );

    if (response == null) return null;
    try {
      final data = response['data'] as Map<String, dynamic>?;
      final media = data?['Media'] as Map<String, dynamic>?;
      if (media == null) return null;

      final titleObj = media['title'] as Map<String, dynamic>?;
      final title =
          (titleObj?['english'] ??
                  titleObj?['romaji'] ??
                  titleObj?['native'] ??
                  'Unknown Anime')
              as String;

      final format = media['format'] as String?;
      final isMovie = format == 'MOVIE';
      final mediaType = isMovie ? 'movie' : 'tv';

      String? logoUrl;
      String? fanartUrl;
      int? resolvedTmdbId;
      String? resolvedImdbId;
      try {
        final aniZipResponse = await _dio.get<Map<String, dynamic>>(
          'https://api.ani.zip/mappings',
          queryParameters: {'anilist_id': id},
        );
        if (aniZipResponse.statusCode == 200 && aniZipResponse.data != null) {
          final aniZipData = aniZipResponse.data!;
          final mappings = aniZipData['mappings'] as Map<String, dynamic>?;
          if (mappings != null) {
            resolvedTmdbId = int.tryParse(
              mappings['themoviedb_id']?.toString() ?? '',
            );
            resolvedImdbId = mappings['imdb_id']?.toString();
          }
          final imagesList = aniZipData['images'] as List?;
          if (imagesList != null) {
            for (final img in imagesList) {
              if (img is Map) {
                if (img['coverType'] == 'Clearlogo') {
                  logoUrl = img['url'] as String?;
                } else if (img['coverType'] == 'Fanart') {
                  fanartUrl = img['url'] as String?;
                }
              }
            }
          }
        }
      } catch (e) {
        talker.error('AnilistRepository: Failed to fetch AniZip mappings: $e');
      }

      final coverObj = media['coverImage'] as Map<String, dynamic>?;
      final posterUrl =
          (coverObj?['extraLarge'] ??
                  coverObj?['large'] ??
                  coverObj?['medium'] ??
                  '')
              as String;
      final bannerUrl =
          (fanartUrl ?? media['bannerImage'] ?? posterUrl) as String;

      final averageScore = (media['averageScore'] as num?)?.toDouble() ?? 0.0;
      final score = averageScore / 10.0;

      final genresList =
          (media['genres'] as List?)?.map((g) => g.toString()).toList() ?? [];
      final genresStr = genresList.join(' | ');

      final nextAiringObj = media['nextAiringEpisode'] as Map<String, dynamic>?;
      int episodesCount = media['episodes'] as int? ?? 12;
      if (nextAiringObj != null) {
        final nextEp = nextAiringObj['episode'] as int?;
        if (nextEp != null && nextEp > 1) {
          episodesCount = nextEp - 1;
        }
      }
      final description = _cleanDescription(media['description'] as String?);

      // Airing schedule / next episode
      NextAiring? nextAiring;
      if (nextAiringObj != null) {
        nextAiring = NextAiring(
          episode: nextAiringObj['episode'] as int? ?? 0,
          unixTime: nextAiringObj['airingAt'] as int? ?? 0,
          season: 1,
        );
      }

      // Cast
      final cast = <TmdbCast>[];
      final charsObj = media['characters'] as Map<String, dynamic>?;
      if (charsObj != null) {
        final edges = charsObj['edges'] as List?;
        if (edges != null) {
          for (final edge in edges) {
            final characterNode = edge['node'] as Map<String, dynamic>?;
            if (characterNode == null) continue;
            final charName = characterNode['name']?['full'] as String? ?? '';
            final charImage = characterNode['image']?['large'] as String?;
            cast.add(
              TmdbCast(
                name: charName,
                character: edge['role'] as String? ?? '',
                profilePath: charImage,
              ),
            );
          }
        }
      }

      // Production Companies / Studios
      final productionCompanies = <TmdbProductionCompany>[];
      final studiosObj = media['studios'] as Map<String, dynamic>?;
      if (studiosObj != null) {
        final nodes = studiosObj['nodes'] as List?;
        if (nodes != null) {
          for (final node in nodes) {
            productionCompanies.add(
              TmdbProductionCompany(
                name: node['name'] as String? ?? '',
                logoPath: null,
              ),
            );
          }
        }
      }

      // Trailers
      final trailers = <TmdbVideo>[];
      final trailerObj = media['trailer'] as Map<String, dynamic>?;
      if (trailerObj != null &&
          trailerObj['site']?.toString().toLowerCase() == 'youtube') {
        trailers.add(
          TmdbVideo(
            key: trailerObj['id'] as String? ?? '',
            type: 'Trailer',
            name: 'Official Trailer',
          ),
        );
      }

      final startDateObj = media['startDate'] as Map<String, dynamic>?;
      final startYear = startDateObj?['year'] ?? media['seasonYear'] ?? 2025;
      final startMonth = startDateObj?['month'] ?? 1;
      final startDay = startDateObj?['day'] ?? 1;
      final date =
          '${startYear.toString().padLeft(4, '0')}-${startMonth.toString().padLeft(2, '0')}-${startDay.toString().padLeft(2, '0')}';

      return TmdbDetails(
        id: id,
        mediaType: mediaType,
        title: title,
        posterPath: posterUrl,
        backdropPath: bannerUrl,
        releaseDate: date,
        voteAverage: score,
        overview: description,
        logoUrl: logoUrl,
        genresStr: genresStr,
        runtime: media['duration'] as int? ?? 0,
        certification: 'PG-13',
        director: 'Unknown',
        seasons: isMovie
            ? []
            : [
                TmdbSeason(
                  seasonNumber: 1,
                  name: 'Season 1',
                  episodeCount: episodesCount,
                  posterPath: posterUrl,
                  airDate: date,
                ),
              ],
        tmdbCast: cast,
        genres: genresList,
        tmdbTrailers: trailers,
        productionCompanies: productionCompanies,
        tmdbStatus: media['status'] as String? ?? 'FINISHED',
        budget: 0,
        revenue: 0,
        tagline: '',
        originCountry: 'JP',
        originalLanguage: 'JA',
        releaseDateFull: date,
        source: 'anilist',
        nextAiring: nextAiring,
        tmdbId: resolvedTmdbId,
        imdbId: resolvedImdbId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAnimeEpisodes(int id) async {
    const episodesGraphQL = '''
      query (\$id: Int) {
        Media(id: \$id, type: ANIME) {
          episodes
          format
          averageScore
          title {
            romaji
            english
            native
          }
          nextAiringEpisode {
            episode
          }
          streamingEpisodes {
            title
            thumbnail
            url
            site
          }
        }
      }
    ''';

    final response = await _service.postGraphQL(
      episodesGraphQL,
      variables: {'id': id},
    );

    if (response == null) return null;
    try {
      final data = response['data'] as Map<String, dynamic>?;
      final media = data?['Media'] as Map<String, dynamic>?;
      if (media == null) return null;

      final titleObj = media['title'] as Map<String, dynamic>?;
      final title =
          (titleObj?['english'] ??
                  titleObj?['romaji'] ??
                  titleObj?['native'] ??
                  'Anime')
              as String;

      final averageScore = (media['averageScore'] as num?)?.toDouble() ?? 0.0;
      final voteAverage = averageScore / 10.0;

      // Fetch episodes from AniZip mapping API (providing titles, summaries, ratings, and stills)
      Map<int, AniZipEpisode>? aniZipEpisodes;
      try {
        final aniZipResponse = await _dio.get<Map<String, dynamic>>(
          'https://api.ani.zip/mappings',
          queryParameters: {'anilist_id': id},
        );
        if (aniZipResponse.statusCode == 200 && aniZipResponse.data != null) {
          aniZipEpisodes = parseAniZipEpisodes(aniZipResponse.data!);
        }
      } catch (e) {
        talker.error('AnilistRepository: Failed to fetch AniZip episodes: $e');
      }

      int count = media['episodes'] as int? ?? 12;
      final nextAiringObj = media['nextAiringEpisode'] as Map<String, dynamic>?;
      if (nextAiringObj != null) {
        final nextEp = nextAiringObj['episode'] as int?;
        if (nextEp != null && nextEp > 1) {
          count = nextEp - 1;
        }
      }

      // If count is null or 0, or we can check if there are more episode entries in AniZip
      if (aniZipEpisodes != null && aniZipEpisodes.isNotEmpty) {
        final maxKey = aniZipEpisodes.keys.reduce((a, b) => a > b ? a : b);
        if (maxKey > count) {
          count = maxKey;
        }
      }

      final streamingList = List<Map<String, dynamic>>.from(
        (media['streamingEpisodes'] as List?) ?? const <dynamic>[],
      );

      final episodes = List.generate(count, (index) {
        final epNum = index + 1;

        String epName = 'Episode $epNum';
        String? stillPath;
        double epVoteAverage = voteAverage;
        String epOverview = 'Watch episode $epNum of $title.';

        final epData = aniZipEpisodes?[epNum];
        if (epData != null) {
          epName = epData.title ?? epData.nativeTitle ?? epName;
          stillPath = epData.image;
          epVoteAverage = epData.rating ?? epVoteAverage;
          epOverview = epData.overview ?? epOverview;
        }

        // Fallback to streaming list if name is generic or still is missing
        if ((stillPath == null ||
                stillPath.isEmpty ||
                epName == 'Episode $epNum') &&
            index < streamingList.length) {
          final streamEp = streamingList[index];
          if (epName == 'Episode $epNum') {
            final titleStr = streamEp['title'] as String?;
            if (titleStr != null && titleStr.isNotEmpty) {
              epName = titleStr;
            }
          }
          if (stillPath == null || stillPath.isEmpty) {
            stillPath = streamEp['thumbnail'] as String?;
          }
        }

        return {
          'id': epNum,
          'episode_number': epNum,
          'name': epName,
          'season_number': 1,
          'still_path': stillPath,
          'vote_average': epVoteAverage,
          'overview': epOverview,
        };
      });

      return {'episodes': episodes};
    } catch (_) {
      return null;
    }
  }

  String _cleanDescription(String? raw) {
    if (raw == null) return '';
    final unescaped = _unescape.convert(raw);
    final withNewlines = unescaped
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</?p>', caseSensitive: false), '\n');
    return withNewlines.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  Future<String?> getAnimeLogo(int id) async {
    final images = await getAnimeImages(id);
    return images['logo'];
  }
}
