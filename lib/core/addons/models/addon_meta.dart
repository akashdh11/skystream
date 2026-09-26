/// Catalog / meta objects from an add-on, plus adapters to the app's own
/// [MultimediaItem] so add-on content can reuse existing widgets.
library;

import '../../domain/entity/multimedia_item.dart';
import '../../models/tmdb_details.dart';

/// `MultimediaItem.source` marker for anything that came from an add-on.
const String kAddonItemSource = 'addon';

/// An add-on manifest is third-party JSON, so a field's type is a suggestion:
/// ids come back as ints, episode numbers as strings, ratings as either. A
/// [TypeError] while parsing one is swallowed by the catalog and meta fetch
/// loops, which drops the whole add-on out of the list rather than the one bad
/// field, so every foreign value is read through these instead of cast.
String? _asString(Object? value) {
  if (value is String) return value;
  if (value is num) return '$value';
  return null;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.isFinite ? value.toInt() : null;
  if (value is String) {
    final text = value.trim();
    final whole = int.tryParse(text);
    if (whole != null) return whole;
    final fraction = double.tryParse(text);
    return fraction != null && fraction.isFinite ? fraction.toInt() : null;
  }
  return null;
}

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
  /// Explicit IMDb id from the meta payload (`imdb_id` / `imdbId`), when the
  /// add-on bothers to send one. Scraper bridges usually omit this — see
  /// [imdbId] which also falls back to a `tt…` primary id.
  final String? imdbIdField;
  final int? yearField;
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
    this.imdbIdField,
    this.yearField,
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
          final genre = _asString(entry)?.trim() ?? '';
          if (genre.isNotEmpty) genres.add(genre);
        }
      }
    }

    final explicitImdb = _asString(json['imdb_id']) ??
        _asString(json['imdbId']) ??
        _asString(json['imdb']);

    return AddonMetaPreview(
      id: _asString(json['id']) ?? '',
      type: _asString(json['type']) ?? 'movie',
      name: _asString(json['name']) ?? '',
      poster: _asString(json['poster']),
      background: _asString(json['background']),
      logo: _asString(json['logo']),
      description: _asString(json['description']),
      releaseInfo: _asString(json['releaseInfo']),
      imdbRating: _asString(json['imdbRating']),
      imdbIdField: explicitImdb,
      yearField: _asInt(json['year']),
      genres: genres,
      addonId: addonId,
      addonName: addonName,
    );
  }

  bool get isSeries => type == 'series' || type == 'tv' || type == 'show';

  /// Type string handed to `/stream/{type}/{id}` requests.
  ///
  /// Canonical Stremio types are `movie` / `series`. Scraping bridges
  /// (CNCVerse, MovieBox multi-provider manifests, …) publish catalogs as
  /// `other` or `tv` and only answer stream queries on those same types —
  /// rewriting them to `movie`/`series` yields empty link lists. Preserve
  /// whatever the meta declared; only fall back when the field is blank.
  String get streamRequestType {
    final t = type.trim().toLowerCase();
    if (t.isEmpty) return isSeries ? 'series' : 'movie';
    return t;
  }

  int? get year {
    if (yearField != null && yearField! > 1800 && yearField! < 2100) {
      return yearField;
    }
    final info = releaseInfo;
    if (info == null) return null;
    final match = RegExp(r'(\d{4})').firstMatch(info);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  String? get imdbId {
    final explicit = imdbIdField?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      final match = RegExp(r'(tt\d{5,})', caseSensitive: false).firstMatch(explicit);
      if (match != null) return match.group(1)!.toLowerCase();
      if (explicit.toLowerCase().startsWith('tt')) {
        return explicit.split(':').first.toLowerCase();
      }
    }
    if (id.startsWith('tt')) return id.split(':').first;
    return null;
  }

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
    final number = _asInt(json['episode']) ?? _asInt(json['number']);
    return AddonVideo(
      id: _asString(json['id']) ?? '',
      title:
          _asString(json['title']) ??
          _asString(json['name']) ??
          (number != null ? 'Episode $number' : 'Video'),
      season: _asInt(json['season']),
      episode: number,
      released: _asString(json['released']) ?? _asString(json['firstAired']),
      thumbnail: _asString(json['thumbnail']),
      overview: _asString(json['overview']) ?? _asString(json['description']),
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
    super.imdbIdField,
    super.yearField,
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
          final name = _asString(entry['name']) ?? '';
          final character = _asString(entry['character']) ?? '';
          final photo = _asString(
            entry['profile_path'] ?? entry['photo'] ?? entry['avatar'],
          );
          addCastMember(name, character: character, profilePath: photo);
        }
      }
    }

    final rawLinks = json['links'];
    if (rawLinks is List) {
      for (final link in rawLinks) {
        if (link is Map) {
          final cat = _asString(link['category'])?.toLowerCase();
          final name = _asString(link['name']) ?? '';
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
            _asString(entry['source']),
            type: _asString(entry['type']),
            name: _asString(entry['name'] ?? entry['title']),
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
            _asString(entry['ytId'] ?? entry['source']),
            type: 'Trailer',
            name: _asString(entry['title']),
          );
        }
      }
    }

    addTrailer(_asString(json['trailer']));

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
              _asString(entry['name']),
              logoPath: _asString(entry['logo_path'] ?? entry['logo']),
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
      for (final entry in rawDirector) {
        final clean = _asString(entry)?.trim() ?? '';
        if (clean.isNotEmpty && !directors.contains(clean)) {
          directors.add(clean);
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
      for (final entry in rawWriter) {
        final clean = _asString(entry)?.trim() ?? '';
        if (clean.isNotEmpty && !writers.contains(clean)) {
          writers.add(clean);
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
          final cat = _asString(link['category'])?.toLowerCase();
          final name = _asString(link['name']) ?? '';
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

    final country = _asString(json['country']);
    final awards = _asString(json['awards']);
    int? moviedbId = _asInt(json['moviedb_id']) ?? _asInt(json['tmdb_id']);
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
      imdbIdField: preview.imdbIdField,
      yearField: preview.yearField,
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
      runtime: _asString(json['runtime']),
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

