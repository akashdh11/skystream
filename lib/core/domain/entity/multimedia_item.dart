import 'package:html_unescape/html_unescape.dart';
import 'package:collection/collection.dart';

import '../../config/tmdb_config.dart';

enum MultimediaContentType { movie, series, anime, livestream, other }

enum ShowStatus { completed, ongoing, upcoming }

enum DubStatus { none, dubbed, subbed }

class Actor {
  final String name;
  final String? image;
  final String? role;
  final Actor? voiceActor;

  Actor({required this.name, this.image, this.role, this.voiceActor});

  factory Actor.fromJson(Map<String, dynamic> json) {
    return Actor(
      name: (json['name'] as String?) ?? '',
      image: json['image'] as String?,
      role: (json['role'] as String?) ?? (json['roleString'] as String?),
      voiceActor: json['voiceActor'] != null
          ? Actor.fromJson(Map<String, dynamic>.from(json['voiceActor'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'image': image,
      'role': role,
      'voiceActor': voiceActor?.toJson(),
    };
  }
}

class Trailer {
  final String url;
  final Map<String, String>? headers;

  Trailer({required this.url, this.headers});

  factory Trailer.fromJson(Map<String, dynamic> json) {
    return Trailer(
      url: (json['url'] as String?) ?? (json['extractorUrl'] as String?) ?? '',
      headers: json['headers'] != null
          ? Map<String, String>.from(json['headers'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'url': url, 'headers': headers};
  }
}

class NextAiring {
  final int episode;
  final int unixTime;
  final int? season;

  NextAiring({required this.episode, required this.unixTime, this.season});

  factory NextAiring.fromJson(Map<String, dynamic> json) {
    return NextAiring(
      episode: (json['episode'] as int?) ?? 0,
      unixTime: (json['unixTime'] as int?) ?? 0,
      season: json['season'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'episode': episode, 'unixTime': unixTime, 'season': season};
  }
}

class MultimediaItem {
  static final _unescape = HtmlUnescape();
  final String title;
  final String url;
  final String posterUrl;
  final String? bannerUrl;
  final String? logoUrl;
  final String? description;
  final MultimediaContentType contentType;
  final List<Episode>? episodes;
  final String? provider;
  final Map<String, String>? headers;

  // New parity fields
  final int? year;
  final double? score;
  final int? duration;
  final ShowStatus status;
  final List<String>? tags;
  final String? contentRating;
  final List<Actor>? cast;
  final List<Trailer>? trailers;
  final List<MultimediaItem>? recommendations;
  final Map<String, String>? syncData;
  final String? playbackPolicy;
  final bool isAdult;
  final NextAiring? nextAiring;
  final List<StreamResult>? streams;

  final int? tmdbId;
  final String? imdbId;
  final String? source;

  MultimediaItem({
    required this.title,
    required this.url,
    required this.posterUrl,
    this.bannerUrl,
    this.logoUrl,
    this.description,
    this.contentType = MultimediaContentType.movie,
    List<Episode>? episodes,
    this.provider,
    this.headers,
    this.year,
    this.score,
    this.duration,
    this.status = ShowStatus.ongoing,
    this.tags,
    this.contentRating,
    this.cast,
    this.trailers,
    this.recommendations,
    this.syncData,
    this.playbackPolicy,
    this.isAdult = false,
    this.nextAiring,
    this.streams,
    this.tmdbId,
    this.imdbId,
    this.source,
  }) : episodes = episodes != null
           ? (List<Episode>.from(episodes)..sort((a, b) {
               if (a.season != b.season) return a.season.compareTo(b.season);
               return a.episode.compareTo(b.episode);
             }))
           : null;

  factory MultimediaItem.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('media_type') &&
        json.containsKey('vote_average') &&
        !json.containsKey('posterUrl')) {
      return MultimediaItem.fromTmdbJson(json);
    }
    final title = json['title'] != null
        ? _unescape.convert(json['title'] as String)
        : '';

    final String? typeStr =
        (json['type'] as String?) ?? (json['contentType'] as String?);
    final MultimediaContentType type = MultimediaItem.parseContentType(typeStr);

    return MultimediaItem(
      title: title,
      url: (json['url'] as String?) ?? '',
      posterUrl: (json['posterUrl'] as String?) ?? '',
      bannerUrl:
          (json['backgroundPosterUrl'] as String?) ??
          (json['bannerUrl'] as String?),
      logoUrl: json['logoUrl'] as String?,
      description: json['description'] != null
          ? _unescape.convert(json['description'] as String)
          : null,
      contentType: type,
      episodes: json['episodes'] != null
          ? (json['episodes'] as List)
                .map<Episode>(
                  (e) => Episode.fromJson(Map<String, dynamic>.from(e as Map)),
                )
                .toList()
          : null,
      streams: json['streams'] != null
          ? (json['streams'] as List)
                .map<StreamResult>(
                  (s) => StreamResult.fromJson(
                    Map<String, dynamic>.from(s as Map),
                  ),
                )
                .toList()
          : null,
      provider: json['provider'] as String?,
      headers: json['headers'] != null
          ? Map<String, String>.from(json['headers'] as Map)
          : null,
      year: json['year'] as int?,
      score: (json['score'] as num?)?.toDouble(),
      duration: json['duration'] as int?,
      status: _parseShowStatus(json['status'] ?? json['showStatus']),
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] as List)
          : null,
      cast: json['cast'] != null || json['actors'] != null
          ? ((json['cast'] ?? json['actors']) as List)
                .map<Actor>(
                  (a) => Actor.fromJson(Map<String, dynamic>.from(a as Map)),
                )
                .toList()
          : null,
      trailers: json['trailers'] != null
          ? (json['trailers'] as List)
                .map<Trailer>(
                  (t) => Trailer.fromJson(Map<String, dynamic>.from(t as Map)),
                )
                .toList()
          : null,
      recommendations: json['recommendations'] != null
          ? (json['recommendations'] as List)
                .map<MultimediaItem>(
                  (r) => MultimediaItem.fromJson(
                    Map<String, dynamic>.from(r as Map),
                  ),
                )
                .toList()
          : null,
      syncData: json['syncData'] != null
          ? Map<String, String>.from(json['syncData'] as Map)
          : null,
      playbackPolicy:
          (json['playbackPolicy'] as String?) ?? (json['vpnStatus'] as String?),
      isAdult: (json['isAdult'] as bool?) ?? false,
      nextAiring: json['nextAiring'] != null
          ? NextAiring.fromJson(
              Map<String, dynamic>.from(json['nextAiring'] as Map),
            )
          : null,
      tmdbId: json['tmdbId'] as int?,
      imdbId: json['imdbId'] as String?,
      source: json['source'] as String?,
    );
  }

  factory MultimediaItem.fromTmdbJson(Map<String, dynamic> json) {
    final String mTypeStr =
        (json['media_type'] as String?) ??
        (json['title'] != null ? 'movie' : 'tv');
    final title = _unescape.convert(
      (json['title'] as String?) ?? (json['name'] as String?) ?? 'Unknown',
    );
    final date =
        (json['release_date'] as String?) ??
        (json['first_air_date'] as String?) ??
        '';
    final year = int.tryParse(date.split('-').first);
    final posterPath = json['poster_path'] as String?;
    final backdropPath = json['backdrop_path'] as String?;

    // Using simple logic for now, we'll eventually use AppImageFallbacks once we unify more
    final posterUrl = posterPath != null
        ? '${TmdbConfig.posterSizeUrl}$posterPath'
        : '';
    final bannerUrl = backdropPath != null
        ? '${TmdbConfig.backdropSizeUrl}$backdropPath'
        : posterUrl;

    return MultimediaItem(
      title: title,
      url: '', // Needs detail resolving
      posterUrl: posterUrl,
      bannerUrl: bannerUrl,
      description: json['overview'] as String?,
      contentType: MultimediaItem.parseContentType(mTypeStr),
      year: year,
      score: (json['vote_average'] as num?)?.toDouble(),
      tmdbId: json['id'] as int?,
      imdbId: json['imdbId'] as String?,
    );
  }

  static ShowStatus _parseShowStatus(dynamic raw) {
    if (raw == null) return ShowStatus.ongoing;
    final str = raw.toString().toLowerCase();
    if (str.contains('completed')) return ShowStatus.completed;
    if (str.contains('upcoming') || str.contains('soon')) {
      return ShowStatus.upcoming;
    }
    return ShowStatus.ongoing;
  }

  static MultimediaContentType parseContentType(String? raw) {
    if (raw == null) return MultimediaContentType.movie;
    switch (raw.toLowerCase()) {
      case 'movie':
        return MultimediaContentType.movie;
      case 'series':
      case 'tvseries':
      case 'tv':
        return MultimediaContentType.series;
      case 'anime':
        return MultimediaContentType.anime;
      case 'livestream':
      case 'live':
      case 'iptv':
        return MultimediaContentType.livestream;
      default:
        return MultimediaContentType.other;
    }
  }

  // Compatibility getters for TmdbItem migration
  int get id => tmdbId ?? 0;
  String get mediaType {
    return contentType.name.toUpperCase();
  }

  String get tmdbMediaType =>
      contentType == MultimediaContentType.series ? 'tv' : 'movie';

  String get backdropImageUrl => bannerUrl ?? posterUrl;
  String get posterImageUrl => posterUrl;
  String get thumbnailImageUrl => posterUrl;
  String get releaseDate => year?.toString() ?? '';
  String get overview => description ?? '';
  double get voteAverage => score ?? 0.0;
  String get genresStr => tags?.join(' | ') ?? '';

  MultimediaItem copyWith({
    String? title,
    String? url,
    String? posterUrl,
    String? bannerUrl,
    String? logoUrl,
    String? description,
    MultimediaContentType? contentType,
    List<Episode>? episodes,
    String? provider,
    Map<String, String>? headers,
    int? year,
    double? score,
    int? duration,
    ShowStatus? status,
    List<String>? tags,
    String? contentRating,
    List<Actor>? cast,
    List<Trailer>? trailers,
    List<MultimediaItem>? recommendations,
    Map<String, String>? syncData,
    String? playbackPolicy,
    bool? isAdult,
    NextAiring? nextAiring,
    List<StreamResult>? streams,
    int? tmdbId,
    String? imdbId,
    String? source,
  }) {
    return MultimediaItem(
      title: title ?? this.title,
      url: url ?? this.url,
      posterUrl: posterUrl ?? this.posterUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      description: description ?? this.description,
      contentType: contentType ?? this.contentType,
      episodes: episodes ?? this.episodes,
      provider: provider ?? this.provider,
      headers: headers ?? this.headers,
      year: year ?? this.year,
      score: score ?? this.score,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      tags: tags ?? this.tags,
      contentRating: contentRating ?? this.contentRating,
      cast: cast ?? this.cast,
      trailers: trailers ?? this.trailers,
      recommendations: recommendations ?? this.recommendations,
      syncData: syncData ?? this.syncData,
      playbackPolicy: playbackPolicy ?? this.playbackPolicy,
      isAdult: isAdult ?? this.isAdult,
      nextAiring: nextAiring ?? this.nextAiring,
      streams: streams ?? this.streams,
      tmdbId: tmdbId ?? this.tmdbId,
      imdbId: imdbId ?? this.imdbId,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
      'posterUrl': posterUrl,
      'bannerUrl': bannerUrl,
      'logoUrl': logoUrl,
      'description': description,
      'type': contentType.name,
      'episodes': episodes?.map((e) => e.toJson()).toList(),
      'provider': provider,
      'headers': headers,
      'year': year,
      'score': score,
      'duration': duration,
      'status': status.name,
      'tags': tags,
      'contentRating': contentRating,
      'cast': cast?.map((a) => a.toJson()).toList(),
      'trailers': trailers?.map((t) => t.toJson()).toList(),
      'recommendations': recommendations?.map((r) => r.toJson()).toList(),
      'syncData': syncData,
      'playbackPolicy': playbackPolicy,
      'isAdult': isAdult,
      'nextAiring': nextAiring?.toJson(),
      'tmdbId': tmdbId,
      'imdbId': imdbId,
      'streams': streams?.map((s) => s.toJson()).toList(),
      'source': source,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MultimediaItem &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          title == other.title &&
          posterUrl == other.posterUrl &&
          provider == other.provider &&
          tmdbId == other.tmdbId &&
          imdbId == other.imdbId &&
          const MapEquality<String, String>().equals(syncData, other.syncData);

  @override
  int get hashCode =>
      url.hashCode ^
      title.hashCode ^
      posterUrl.hashCode ^
      (provider?.hashCode ?? 0) ^
      (tmdbId?.hashCode ?? 0) ^
      (imdbId?.hashCode ?? 0) ^
      const MapEquality<String, String>().hash(syncData);
}

class Episode {
  static final _unescape = HtmlUnescape();
  final String name;
  final String url;
  final int season;
  final int episode;
  final String? description;
  final String? posterUrl;
  final Map<String, String>? headers;

  // Parity fields
  final double? rating;
  final int? runtime;
  final String? airDate;
  final DubStatus dubStatus;
  final String? playbackPolicy;
  final List<StreamResult>? streams;

  Episode({
    required this.name,
    required this.url,
    this.season = 0,
    this.episode = 0,
    this.description,
    this.posterUrl,
    this.headers,
    this.rating,
    this.runtime,
    this.airDate,
    this.dubStatus = DubStatus.none,
    this.playbackPolicy,
    this.streams,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    final name = json['name'] != null
        ? _unescape.convert(json['name'] as String)
        : '';
    return Episode(
      name: name,
      url: (json['url'] as String?) ?? '',
      season: (json['season'] as int?) ?? 0,
      episode: (json['episode'] as int?) ?? 0,
      description: json['description'] != null
          ? _unescape.convert(json['description'] as String)
          : null,
      posterUrl: json['posterUrl'] as String?,
      headers: json['headers'] != null
          ? Map<String, String>.from(json['headers'] as Map)
          : null,
      rating: (json['rating'] as num?)?.toDouble(),
      runtime: (json['runtime'] as int?) ?? (json['duration'] as int?),
      airDate: json['airDate'] as String?,
      dubStatus: _parseDubStatus(json['dubStatus']),
      playbackPolicy:
          (json['playbackPolicy'] as String?) ?? (json['vpnStatus'] as String?),
      streams: json['streams'] != null
          ? (json['streams'] as List)
                .map<StreamResult>(
                  (s) => StreamResult.fromJson(
                    Map<String, dynamic>.from(s as Map),
                  ),
                )
                .toList()
          : null,
    );
  }

  static DubStatus _parseDubStatus(dynamic raw) {
    if (raw == null) return DubStatus.none;
    if (raw is DubStatus) return raw;
    final str = raw.toString().trim().toLowerCase();
    if (str == 'dub' || str == 'dubbed') return DubStatus.dubbed;
    if (str == 'sub' || str == 'subbed') return DubStatus.subbed;
    return DubStatus.none;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'season': season,
      'episode': episode,
      'description': description,
      'posterUrl': posterUrl,
      'headers': headers,
      'rating': rating,
      'runtime': runtime,
      'airDate': airDate,
      'dubStatus': dubStatus.name,
      'playbackPolicy': playbackPolicy,
      'streams': streams?.map((s) => s.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Episode &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          season == other.season &&
          episode == other.episode;

  @override
  int get hashCode => url.hashCode ^ season.hashCode ^ episode.hashCode;
}

class StreamResult {
  final String url;
  final String source;
  final Map<String, String>? headers;
  final List<SubtitleFile>? subtitles;
  final String? drmKid;
  final String? drmKey;
  final String? licenseUrl;

  const StreamResult({
    required this.url,
    required this.source,
    this.headers,
    this.subtitles,
    this.drmKid,
    this.drmKey,
    this.licenseUrl,
  });

  Map<String, dynamic> toJson() => {
    'url': url,
    'source': source,
    'headers': headers,
    'subtitles': subtitles?.map((x) => x.toJson()).toList(),
    'drmKid': drmKid,
    'drmKey': drmKey,
    'licenseUrl': licenseUrl,
  };

  factory StreamResult.fromJson(Map<String, dynamic> json) {
    return StreamResult(
      url: (json['url'] as String?) ?? '',
      source: (json['source'] as String?) ?? 'Unknown',
      headers: json['headers'] != null
          ? Map<String, String>.from(json['headers'] as Map)
          : null,
      subtitles: json['subtitles'] != null
          ? (json['subtitles'] as List)
                .map(
                  (x) => SubtitleFile.fromJson(
                    Map<String, dynamic>.from(x as Map),
                  ),
                )
                .toList()
          : null,
      drmKid: json['drmKid'] as String?,
      drmKey: json['drmKey'] as String?,
      licenseUrl: json['licenseUrl'] as String?,
    );
  }
}

class SubtitleFile {
  final String url;
  final String label;
  final String? lang;

  SubtitleFile({required this.url, required this.label, this.lang});

  Map<String, dynamic> toJson() => {'url': url, 'label': label, 'lang': lang};

  factory SubtitleFile.fromJson(Map<String, dynamic> json) {
    return SubtitleFile(
      url: (json['url'] as String?) ?? '',
      label: (json['label'] as String?) ?? 'Unknown',
      lang: json['lang'] as String?,
    );
  }
}
