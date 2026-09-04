/// Catalog / meta objects from an add-on, plus adapters to the app's own
/// [MultimediaItem] so add-on content can reuse existing widgets.
library;

import '../../domain/entity/multimedia_item.dart';
import '../../models/tmdb_details.dart';

/// `MultimediaItem.source` marker for anything that came from an add-on.
const String kAddonItemSource = 'addon';

class AddonMetaPreview {
  final String id;
  final String type;
  final String name;
  final String? poster;
  final String? background;
  final String? logo;
  final String? description;
  final String? releaseInfo;
  final String? imdbRating;
  final List<String> genres;
  final String addonId;
  final String addonName;

  const AddonMetaPreview({
    required this.id,
    required this.type,
    required this.name,
    this.poster,
    this.background,
    this.logo,
    this.description,
    this.releaseInfo,
    this.imdbRating,
    this.genres = const [],
    this.addonId = '',
    this.addonName = '',
  });

  factory AddonMetaPreview.fromJson(
    Map<String, dynamic> json, {
    String addonId = '',
    String addonName = '',
  }) {
    final genres = <String>[];
    for (final key in const ['genres', 'genre']) {
      final raw = json[key];
      if (raw is List) {
        for (final entry in raw) {
          if (entry is String && entry.trim().isNotEmpty) genres.add(entry);
        }
      }
    }

    return AddonMetaPreview(
      id: (json['id'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'movie',
      name: (json['name'] as String?) ?? '',
      poster: json['poster'] as String?,
      background: json['background'] as String?,
      logo: json['logo'] as String?,
      description: json['description'] as String?,
      releaseInfo: json['releaseInfo']?.toString(),
      imdbRating: json['imdbRating']?.toString(),
      genres: genres,
      addonId: addonId,
      addonName: addonName,
    );
  }

  bool get isSeries => type == 'series' || type == 'tv' || type == 'show';

  int? get year {
    final info = releaseInfo;
    if (info == null) return null;
    final match = RegExp(r'(\d{4})').firstMatch(info);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  String? get imdbId => id.startsWith('tt') ? id.split(':').first : null;

  MultimediaItem toMultimediaItem() {
    return MultimediaItem(
      title: name,
      url: id,
      posterUrl: poster ?? '',
      bannerUrl: background,
      logoUrl: logo,
      description: description,
      contentType: isSeries
          ? MultimediaContentType.series
          : MultimediaContentType.movie,
      provider: addonName.isEmpty ? 'Add-on' : addonName,
      year: year,
      score: double.tryParse(imdbRating ?? ''),
      tags: genres.isEmpty ? null : genres,
      imdbId: imdbId,
      // Marks the item as add-on owned so Continue Watching reopens it in the
      // add-on stack instead of the plugin details screen.
      source: kAddonItemSource,
    );
  }
}

class AddonVideo {
  final String id;
  final String title;
  final int? season;
  final int? episode;
  final String? released;
  final String? thumbnail;
  final String? overview;

  const AddonVideo({
    required this.id,
    required this.title,
    this.season,
    this.episode,
    this.released,
    this.thumbnail,
    this.overview,
  });

  factory AddonVideo.fromJson(Map<String, dynamic> json) {
    final number =
        (json['episode'] as num?)?.toInt() ?? (json['number'] as num?)?.toInt();
    return AddonVideo(
      id: (json['id'] as String?) ?? '',
      title:
          (json['title'] as String?) ??
          (json['name'] as String?) ??
          (number != null ? 'Episode $number' : 'Video'),
      season: (json['season'] as num?)?.toInt(),
      episode: number,
      released:
          (json['released'] as String?) ?? (json['firstAired'] as String?),
      thumbnail: json['thumbnail'] as String?,
      overview:
          (json['overview'] as String?) ?? (json['description'] as String?),
    );
  }

  Episode toEpisode() => Episode(
    name: title,
    url: id,
    season: season ?? 0,
    episode: episode ?? 0,
    description: overview,
    posterUrl: thumbnail,
    airDate: released,
  );
}

class AddonMeta extends AddonMetaPreview {
  final List<AddonVideo> videos;
  final List<String> cast;
  final List<TmdbCast> castMembers;
  final List<TmdbVideo> trailers;
  final List<TmdbProductionCompany> productionCompanies;
  final List<String> directors;
  final List<String> writers;
  final String? runtime;
  final String? country;
  final String? awards;
  final int? moviedbId;

  const AddonMeta({
    required super.id,
    required super.type,
    required super.name,
    super.poster,
    super.background,
    super.logo,
    super.description,
    super.releaseInfo,
    super.imdbRating,
    super.genres,
    super.addonId,
    super.addonName,
    this.videos = const [],
    this.cast = const [],
    this.castMembers = const [],
    this.trailers = const [],
    this.productionCompanies = const [],
    this.directors = const [],
    this.writers = const [],
    this.runtime,
    this.country,
    this.awards,
    this.moviedbId,
  });

  factory AddonMeta.fromJson(
    Map<String, dynamic> json, {
    String addonId = '',
    String addonName = '',
  }) {
    final preview = AddonMetaPreview.fromJson(
      json,
      addonId: addonId,
      addonName: addonName,
    );

    final videos = <AddonVideo>[];
    final rawVideos = json['videos'];
    if (rawVideos is List) {
      for (final entry in rawVideos) {
        if (entry is Map) {
          final video = AddonVideo.fromJson(Map<String, dynamic>.from(entry));
          if (video.id.isNotEmpty) videos.add(video);
        }
      }
    }
    videos.sort((a, b) {
      final bySeason = (a.season ?? 0).compareTo(b.season ?? 0);
      if (bySeason != 0) return bySeason;
      return (a.episode ?? 0).compareTo(b.episode ?? 0);
    });

    final cast = <String>[];
    final castMembers = <TmdbCast>[];
    final seenCast = <String>{};

    void addCastMember(
      String name, {
      String character = '',
      String? profilePath,
    }) {
      final clean = name.trim();
      if (clean.isEmpty || !seenCast.add(clean.toLowerCase())) return;
      cast.add(clean);
      castMembers.add(TmdbCast(
        name: clean,
        character: character.trim(),
        profilePath: profilePath,
      ));
    }

    final rawCast = json['cast'] ?? json['app_cast'];
    if (rawCast is List) {
      for (final entry in rawCast) {
        if (entry is String) {
          addCastMember(entry);
        } else if (entry is Map) {
          final name = (entry['name'] as String?) ?? '';
          final character = (entry['character'] as String?) ?? '';
          final photo = (entry['profile_path'] ??
              entry['photo'] ??
              entry['avatar']) as String?;
          addCastMember(name, character: character, profilePath: photo);
        }
      }
    }

    final rawLinks = json['links'];
    if (rawLinks is List) {
      for (final link in rawLinks) {
        if (link is Map) {
          final cat = (link['category'] as String?)?.toLowerCase();
          final name = (link['name'] as String?) ?? '';
          if (cat == 'cast') {
            addCastMember(name);
          }
        }
      }
    }

    // Trailers parsing
    final trailers = <TmdbVideo>[];
    final seenTrailers = <String>{};

    void addTrailer(String? source, {String? type, String? name}) {
      if (source == null) return;
      var key = source.trim();
      if (key.isEmpty) return;
      if (key.contains('youtube.com/watch?v=')) {
        key = Uri.tryParse(key)?.queryParameters['v'] ?? key;
      } else if (key.contains('youtu.be/')) {
        key = key.split('youtu.be/').last.split('?').first;
      }
      if (key.isNotEmpty && seenTrailers.add(key)) {
        trailers.add(TmdbVideo(
          key: key,
          type: type ?? 'Trailer',
          name: name ?? 'Trailer',
        ));
      }
    }

    final rawTrailers = json['trailers'];
    if (rawTrailers is List) {
      for (final entry in rawTrailers) {
        if (entry is Map) {
          addTrailer(
            entry['source'] as String?,
            type: entry['type'] as String?,
            name: (entry['name'] ?? entry['title']) as String?,
          );
        } else if (entry is String) {
          addTrailer(entry);
        }
      }
    }

    final rawStreams = json['trailerStreams'];
    if (rawStreams is List) {
      for (final entry in rawStreams) {
        if (entry is Map) {
          addTrailer(
            (entry['ytId'] ?? entry['source']) as String?,
            type: 'Trailer',
            name: entry['title'] as String?,
          );
        }
      }
    }

    if (json['trailer'] is String) {
      addTrailer(json['trailer'] as String);
    }

    // Production companies parsing
    final productionCompanies = <TmdbProductionCompany>[];
    final seenCompanies = <String>{};

    void addCompany(String? name, {String? logoPath}) {
      if (name == null) return;
      final clean = name.trim();
      if (clean.isEmpty || !seenCompanies.add(clean.toLowerCase())) return;
      productionCompanies.add(TmdbProductionCompany(
        name: clean,
        logoPath: logoPath,
      ));
    }

    for (final key in const [
      'productionCompanies',
      'productionCompany',
      'production',
    ]) {
      final raw = json[key];
      if (raw is List) {
        for (final entry in raw) {
          if (entry is String) {
            addCompany(entry);
          } else if (entry is Map) {
            addCompany(
              entry['name'] as String?,
              logoPath: (entry['logo_path'] ?? entry['logo']) as String?,
            );
          }
        }
      } else if (raw is String) {
        for (final part in raw.split(',')) {
          addCompany(part);
        }
      }
    }

    // Directors parsing
    final directors = <String>[];
    final rawDirector = json['director'] ?? json['directors'];
    if (rawDirector is List) {
      for (final d in rawDirector) {
        if (d is String &&
            d.trim().isNotEmpty &&
            !directors.contains(d.trim())) {
          directors.add(d.trim());
        }
      }
    } else if (rawDirector is String && rawDirector.trim().isNotEmpty) {
      for (final part in rawDirector.split(',')) {
        final clean = part.trim();
        if (clean.isNotEmpty && !directors.contains(clean)) directors.add(clean);
      }
    }

    // Writers parsing
    final writers = <String>[];
    final rawWriter = json['writer'] ?? json['writers'];
    if (rawWriter is List) {
      for (final w in rawWriter) {
        if (w is String && w.trim().isNotEmpty && !writers.contains(w.trim())) {
          writers.add(w.trim());
        }
      }
    } else if (rawWriter is String && rawWriter.trim().isNotEmpty) {
      for (final part in rawWriter.split(',')) {
        final clean = part.trim();
        if (clean.isNotEmpty && !writers.contains(clean)) writers.add(clean);
      }
    }

    // Also parse directors/writers from links if empty
    final directorLinks = json['links'];
    if (directorLinks is List) {
      for (final link in directorLinks) {
        if (link is Map) {
          final cat = (link['category'] as String?)?.toLowerCase();
          final name = (link['name'] as String?) ?? '';
          if (name.isNotEmpty) {
            if ((cat == 'directors' || cat == 'director') &&
                !directors.contains(name)) {
              directors.add(name);
            } else if ((cat == 'writers' || cat == 'writer') &&
                !writers.contains(name)) {
              writers.add(name);
            }
          }
        }
      }
    }

    final country = json['country']?.toString();
    final awards = json['awards']?.toString();
    int? moviedbId = (json['moviedb_id'] as num?)?.toInt() ??
        (json['tmdb_id'] as num?)?.toInt();
    if (moviedbId == null && preview.id.startsWith('tmdb:')) {
      moviedbId = int.tryParse(preview.id.split(':').last);
    }

    return AddonMeta(
      id: preview.id,
      type: preview.type,
      name: preview.name,
      poster: preview.poster,
      background: preview.background,
      logo: preview.logo,
      description: preview.description,
      releaseInfo: preview.releaseInfo,
      imdbRating: preview.imdbRating,
      genres: preview.genres,
      addonId: addonId,
      addonName: addonName,
      videos: videos,
      cast: cast,
      castMembers: castMembers,
      trailers: trailers,
      productionCompanies: productionCompanies,
      directors: directors,
      writers: writers,
      runtime: json['runtime']?.toString(),
      country: country,
      awards: awards,
      moviedbId: moviedbId,
    );
  }

  @override
  MultimediaItem toMultimediaItem() {
    final base = super.toMultimediaItem();
    return base.copyWith(
      tmdbId: moviedbId ?? base.tmdbId,
      cast: castMembers.isNotEmpty
          ? castMembers
              .map((c) => Actor(
                    name: c.name,
                    role: c.character.isNotEmpty ? c.character : null,
                    image: c.profileImageUrl,
                  ))
              .toList()
          : base.cast,
      trailers: trailers.isNotEmpty
          ? trailers
              .map((t) => Trailer(
                    url: 'https://www.youtube.com/watch?v=${t.key}',
                  ))
              .toList()
          : base.trailers,
    );
  }

  List<int> get seasons {
    final set = <int>{};
    for (final video in videos) {
      final season = video.season;
      if (season != null && season > 0) set.add(season);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<AddonVideo> episodesForSeason(int season) =>
      videos.where((v) => (v.season ?? 0) == season).toList();
}

