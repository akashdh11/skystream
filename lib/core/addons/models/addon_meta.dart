/// Catalog / meta objects from an add-on, plus adapters to the app's own
/// [MultimediaItem] so add-on content can reuse existing widgets.
library;

import '../../domain/entity/multimedia_item.dart';

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
  final String? runtime;

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
    this.runtime,
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
    final rawCast = json['cast'];
    if (rawCast is List) {
      for (final entry in rawCast) {
        if (entry is String && entry.trim().isNotEmpty) cast.add(entry);
      }
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
      runtime: json['runtime']?.toString(),
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
