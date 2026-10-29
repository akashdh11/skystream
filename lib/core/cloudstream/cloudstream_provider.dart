import 'dart:convert';

import 'package:cs3_engine/cs3_engine.dart';
import 'package:dio/dio.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:flutter/foundation.dart';

import '../domain/entity/multimedia_item.dart';
import '../extensions/base_provider.dart';
import '../logger/app_logger.dart';
import '../services/ani_zip_service.dart';
import '../services/local_proxy_service.dart';
import '../utils/stream_quality_sorter.dart' show labelStatesQuality;
import 'cloudstream_engine.dart';
import 'cloudstream_models.dart';

/// One CloudStream provider (a plugin's `MainAPI`) as a SkyStream provider, so home, search,
/// details, the player and downloads use it like any other.
///
/// Built from what the plugin registered at install time; the engine only starts, and the
/// plugin only loads, when the provider is first used.
class CloudStreamProvider extends SkyStreamProvider {
  CloudStreamProvider({
    required this.plugin,
    required this.pluginKey,
    required this.info,
    required CloudStreamEngineHost host,
    Future<void> Function()? prepareLinks,
    AniZipService? aniZip,
  }) : _host = host,
       _prepareLinks = prepareLinks,
       _aniZip = aniZip;

  /// Every CloudStream provider id starts with this, which is how the UI tells them apart.
  static const String idPrefix = 'cs3:';

  /// `cs3:<plugin key>/<provider name>`. The key (see [CloudStreamRepository.keyOf]) includes the
  /// repository: two repositories can offer plugins with the same internal name (forks).
  static String idFor(String pluginKey, String providerName) => '$idPrefix$pluginKey/$providerName';

  static bool isCloudStreamId(String? id) => id != null && id.startsWith(idPrefix);

  final CsInstalledPlugin plugin;
  final String pluginKey;
  final CsProviderInfo info;
  final CloudStreamEngineHost _host;

  /// Run before links are fetched: loads the plugins whose link extractors they may need.
  final Future<void> Function()? _prepareLinks;

  /// Fills in episode titles and stills the extension left out, by the AniList or MAL id it gives.
  final AniZipService? _aniZip;

  /// Home page sections fetched at once; each is a network call in the plugin.
  static const int _homeConcurrency = 4;

  @override
  String get packageName => idFor(pluginKey, info.name);

  @override
  String get name => info.name;

  @override
  String get mainUrl => info.mainUrl;

  @override
  String get checkSource => packageName;

  @override
  String get version => '${plugin.info.version}';

  @override
  List<String> get languages => [if (info.lang != null && info.lang!.isNotEmpty) info.lang!];

  @override
  Set<ProviderType> get supportedTypes {
    final types = {for (final t in info.types) _providerType(t)};
    return types.isEmpty ? {ProviderType.other} : types;
  }

  /// The plugin's display name, for the CloudStream badge.
  String get pluginName => plugin.info.name;

  String get _pluginPath => plugin.filePath;

  /// Runs [call] with the plugin loaded; see [CloudStreamEngineHost.run]. [kind] is the provider
  /// call it makes.
  Future<Map<String, dynamic>> _call(
    Future<Map<String, dynamic>> Function(Cs3Engine engine) call, {
    String kind = 'call',
  }) => _host.run(_pluginPath, call, kind: kind, provider: packageName, mainUrl: mainUrl, pluginUrl: plugin.info.url);

  @override
  Future<List<MultimediaItem>> search(String query, {CancelToken? cancelToken}) async {
    try {
      final result = await _call((e) => e.search(name, query, plugin: _pluginPath), kind: 'search');
      return [for (final item in _list(result['items'])) _item(item)];
    } catch (error) {
      talker.warning('[CloudStream] $name search failed: $error');
      return const [];
    }
  }

  @override
  Future<Map<String, List<MultimediaItem>>> getHome() async {
    if (!info.hasMainPage) return const {};
    // One call per section, a few at a time: the engine walks a provider's sections one after
    // another when asked for all of them.
    final names = info.sections.isEmpty ? const <String?>[null] : info.sections.cast<String?>();
    final pages = List<Map<String, List<MultimediaItem>>>.filled(names.length, const {});
    Object? failure;
    var next = 0;
    Future<void> worker() async {
      while (next < names.length) {
        final index = next++;
        try {
          final result = await _call(
            (e) => e.mainPage(name, section: names[index], plugin: _pluginPath),
            kind: 'mainPage',
          );
          pages[index] = {
            for (final section in _list(result['sections']))
              if (section['error'] == null && _list(section['items']).isNotEmpty)
                // Home items carry no provider, like SkyStream plugins' (the carousel would print the
                // id); details falls back to the active provider, whose home this is.
                (section['name'] as String? ?? name): [
                  for (final item in _list(section['items'])) _item(item, stampProvider: false),
                ],
          };
        } catch (error) {
          failure = error;
          talker.warning('[CloudStream] $name home section ${names[index]} failed: $error');
        }
      }
    }

    await Future.wait([for (var i = 0; i < _homeConcurrency; i++) worker()]);
    final home = {for (final page in pages) ...page};
    // Nothing at all, and a failure: the home screen's error state (with retry), not a blank page.
    if (home.isEmpty && failure != null) throw failure!;
    return home;
  }

  @override
  Future<MultimediaItem> getDetails(String url) async {
    final result = await _call((e) => e.load(name, url, plugin: _pluginPath), kind: 'load');
    final item = details(result, url: url, packageName: packageName, providerName: name);
    final aniZip = _aniZip;
    final episodes = item.episodes;
    if (aniZip == null || item.contentType == MultimediaContentType.movie || episodes == null || episodes.isEmpty) {
      return item;
    }
    final anilistId = int.tryParse(item.syncData?['anilist'] ?? '');
    final malId = int.tryParse(item.syncData?['mal'] ?? '');
    if (anilistId == null && malId == null) return item;
    final found = await aniZip.episodes(anilistId: anilistId, malId: malId);
    return found.isEmpty ? item : item.copyWith(episodes: withAniZip(episodes, found));
  }

  /// [episodes] with what the extension left empty filled in from ani.zip: never what it gave. Only season 1, as an
  /// AniList entry is one season, and by episode number, which for long shows is absolute on both sides.
  @visibleForTesting
  static List<Episode> withAniZip(List<Episode> episodes, Map<int, AniZipEpisode> aniZip) => [
    for (final ep in episodes)
      if (ep.season != 1 || aniZip[ep.episode] == null)
        ep
      else
        _withAniZip(ep, aniZip[ep.episode]!),
  ];

  static Episode _withAniZip(Episode ep, AniZipEpisode z) {
    String? blank(String? value) => value == null || value.isEmpty ? null : value;
    return Episode(
      // 'Episode N' is what [_episode] names an episode the extension sent no name for.
      name: ep.name == 'Episode ${ep.episode}' ? z.title ?? ep.name : ep.name,
      url: ep.url,
      season: ep.season,
      episode: ep.episode,
      description: blank(ep.description) ?? z.overview,
      posterUrl: blank(ep.posterUrl) ?? z.image,
      headers: ep.headers,
      rating: ep.rating ?? z.rating,
      runtime: ep.runtime ?? z.runtime,
      airDate: ep.airDate ?? z.airDate,
      airedAt: ep.airedAt ?? z.airedAt,
      dubStatus: ep.dubStatus,
      playbackPolicy: ep.playbackPolicy,
      streams: ep.streams,
    );
  }

  static final _unescape = HtmlUnescape();

  /// DateTime's range, 100,000,000 days either side of 1970. A date beyond it (nanoseconds where milliseconds were
  /// meant) is dropped rather than failing the whole page.
  static const _maxDateMs = 8640000000000000;

  /// What the engine's `load` answer becomes: everything CloudStream's details page shows that SkyStream has a place
  /// for. Pure, so each field is tested without an engine. [url] is the one asked for, not the one the extension
  /// echoes: history and the details screen are keyed by it.
  @visibleForTesting
  static MultimediaItem details(
    Map<String, dynamic> result, {
    required String url,
    required String packageName,
    required String providerName,
    DateTime? now,
  }) {
    final type = _contentType(result['type'] as String?);
    final title = result['name'] as String? ?? '';
    final episodes = <Episode>[];

    final dataUrl = (result['dataUrl'] as String?)?.trim();
    final magnet = result['magnet'] as String? ?? result['torrent'] as String?;
    // A blank data URL is a film not out yet (CloudStream marks it coming soon): nothing to play.
    if (dataUrl != null && dataUrl.isNotEmpty) {
      episodes.add(Episode(name: title, url: _token(dataUrl), season: 1, episode: 1));
    } else if (magnet != null) {
      episodes.add(Episode(name: title, url: _token(magnet, torrent: true), season: 1, episode: 1));
    } else {
      final raw = _list(result['episodes']);
      for (var i = 0; i < raw.length; i++) {
        episodes.add(_episode(raw[i], i));
      }
    }

    final poster = _text(result['posterUrl']);
    final background = _text(result['backgroundPosterUrl']);
    final syncIds = <String, String>{
      for (final entry in ((result['syncIds'] as Map?) ?? const {}).entries) '${entry.key}': '${entry.value}',
    };
    final imdb = syncIds['imdb'];

    return MultimediaItem(
      title: title,
      url: url,
      // CloudStream shows the background when there is no poster.
      posterUrl: poster ?? background ?? '',
      bannerUrl: background,
      logoUrl: _text(result['logoUrl']),
      description: _decode(result['plot'] as String?),
      contentType: type,
      provider: packageName,
      headers: _stringMap(result['posterHeaders']),
      year: (result['year'] as num?)?.toInt(),
      score: (result['score'] as num?)?.toDouble(),
      duration: (result['duration'] as num?)?.toInt(),
      status: switch (result['showStatus']) {
        'Completed' => ShowStatus.completed,
        'Ongoing' => ShowStatus.ongoing,
        _ => ShowStatus.unknown,
      },
      tags: [...?(result['tags'] as List?)?.whereType<String>()],
      contentRating: _text(result['contentRating']),
      cast: [for (final actor in _list(result['actors'])) _actor(actor)],
      trailers: [
        for (final trailer in _list(result['trailers']))
          if (_text(trailer['url']) != null) _trailer(trailer),
      ],
      // CloudStream lists a title's recommendations from its own extension only, and a tap opens them with it.
      recommendations: [
        for (final rec in _list(result['recommendations']))
          if (rec['apiName'] == providerName && rec['url'] is String) _searchItem(rec, provider: packageName),
      ],
      syncData: syncIds.isEmpty ? null : syncIds,
      tmdbId: int.tryParse(syncIds['tmdb'] ?? ''),
      imdbId: imdb != null && RegExp(r'^tt\d{6,}$').hasMatch(imdb) ? imdb : null,
      nextAiring: _nextAiring(result['nextAiring'], now ?? DateTime.now()),
      comingSoon: result['comingSoon'] == true,
      seasonNames: [
        for (final season in _list(result['seasonNames']))
          if (season['season'] is num) SeasonName.fromJson(season),
      ],
      episodes: episodes,
    );
  }

  static Episode _episode(Map<String, dynamic> ep, int index) {
    final number = (ep['episode'] as num?)?.toInt() ?? index + 1;
    final name = (ep['name'] as String?)?.trim();
    final millis = (ep['date'] as num?)?.toInt();
    final airedAt =
        millis == null || millis.abs() > _maxDateMs ? null : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    return Episode(
      name: name != null && name.isNotEmpty ? _unescape.convert(name) : 'Episode $number',
      url: _token(ep['data'] as String),
      season: (ep['season'] as num?)?.toInt() ?? 1,
      episode: number,
      description: _decode(ep['description'] as String?),
      posterUrl: ep['posterUrl'] as String?,
      rating: (ep['score'] as num?)?.toDouble(),
      runtime: (ep['runTime'] as num?)?.toInt(),
      airedAt: airedAt,
      // The text the player's episode list shows.
      airDate: airedAt?.toIso8601String().substring(0, 10),
      dubStatus: switch ((ep['dub'] as String?)?.toLowerCase()) {
        'dubbed' => DubStatus.dubbed,
        'subbed' => DubStatus.subbed,
        _ => DubStatus.none,
      },
    );
  }

  static Actor _actor(Map<String, dynamic> actor) {
    final role = _text(actor['role']);
    final voice = actor['voiceActor'] is Map ? Map<String, dynamic>.from(actor['voiceActor'] as Map) : null;
    return Actor(
      name: actor['name'] as String? ?? '',
      image: _text(actor['image']),
      role: role ?? _text(actor['roleString']),
      roleIsEnum: role != null,
      voiceActor: voice == null ? null : Actor(name: voice['name'] as String? ?? '', image: _text(voice['image'])),
    );
  }

  static Trailer _trailer(Map<String, dynamic> trailer) {
    final referer = _text(trailer['referer']);
    final headers = _stringMap(trailer['headers']) ?? <String, String>{};
    if (referer != null && !headers.keys.any((k) => k.toLowerCase() == 'referer')) headers['Referer'] = referer;
    return Trailer(
      url: (trailer['url'] as String).trim(),
      raw: trailer['raw'] == true,
      referer: referer,
      headers: headers.isEmpty ? null : headers,
    );
  }

  /// Seconds, as CloudStream sends it; gone once it has passed, as CloudStream hides it.
  static NextAiring? _nextAiring(Object? value, DateTime now) {
    if (value is! Map) return null;
    final unixTime = (value['unixTime'] as num?)?.toInt();
    final episode = (value['episode'] as num?)?.toInt();
    if (unixTime == null || episode == null || unixTime.abs() > _maxDateMs ~/ 1000) return null;
    if (unixTime * 1000 <= now.millisecondsSinceEpoch) return null;
    return NextAiring(episode: episode, unixTime: unixTime, season: (value['season'] as num?)?.toInt());
  }

  static String? _text(Object? value) {
    final text = value is String ? value.trim() : null;
    return text == null || text.isEmpty ? null : text;
  }

  static String? _decode(String? text) => text == null ? null : _unescape.convert(text);

  static Map<String, String>? _stringMap(Object? value) {
    if (value is! Map || value.isEmpty) return null;
    return {for (final entry in value.entries) '${entry.key}': '${entry.value}'};
  }

  @override
  Future<List<StreamResult>> loadStreams(String url) async {
    final (:data, :torrent) = _decodeToken(url);
    if (torrent) return [StreamResult(url: data, source: 'Torrent', providerName: name)];

    await _prepareLinks?.call();
    final result = await _call((e) => e.loadLinks(name, data, plugin: _pluginPath), kind: 'loadLinks');
    // Its full-screen window (a game) took the Play, and left no links: nothing to play, and nothing went wrong.
    if (_list(result['links']).isEmpty && result['fullScreen'] == true) throw const ExtensionScreenEnded();
    final subtitles = await _subtitles(_list(result['subtitles']));
    return [
      for (final link in _list(result['links']))
        StreamResult(
          url: link['url'] as String,
          source: _label(link),
          providerName: name,
          quality: _adaptiveQuality(link),
          headers: _headers(link),
          subtitles: subtitles,
          drmKid: (link['drm'] as Map?)?['kid'] as String?,
          drmKey: (link['drm'] as Map?)?['key'] as String?,
          licenseUrl: (link['drm'] as Map?)?['licenseUrl'] as String?,
        ),
    ];
  }

  MultimediaItem _item(Map<String, dynamic> item, {bool stampProvider = true}) =>
      _searchItem(item, provider: stampProvider ? packageName : null);

  static MultimediaItem _searchItem(Map<String, dynamic> item, {String? provider}) => MultimediaItem(
    title: item['name'] as String? ?? '',
    url: item['url'] as String,
    posterUrl: item['posterUrl'] as String? ?? '',
    contentType: _contentType(item['type'] as String?),
    provider: provider,
    year: (item['year'] as num?)?.toInt(),
    headers: (item['posterHeaders'] as Map?)?.cast<String, String>(),
  );

  /// CloudStream episode data can be anything (a path, JSON...), and the player treats some
  /// strings (`/...`, `magnet:`) as playable already, so it travels wrapped.
  @visibleForTesting
  static String token(String data, {bool torrent = false}) => _token(data, torrent: torrent);

  @visibleForTesting
  static ({String data, bool torrent}) decodeToken(String token) => _decodeToken(token);

  @visibleForTesting
  static String label(Map<String, dynamic> link) => _label(link);

  @visibleForTesting
  static MultimediaContentType contentType(String? type) => _contentType(type);

  static String _token(String data, {bool torrent = false}) =>
      '${torrent ? 'cs3torrent' : 'cs3data'}:${base64Url.encode(utf8.encode(data))}';

  static ({String data, bool torrent}) _decodeToken(String token) {
    final colon = token.indexOf(':');
    final scheme = colon < 0 ? '' : token.substring(0, colon);
    if (scheme != 'cs3data' && scheme != 'cs3torrent') return (data: token, torrent: false);
    return (data: utf8.decode(base64Url.decode(token.substring(colon + 1))), torrent: scheme == 'cs3torrent');
  }

  /// "Server · 1080p". SkyStream reads the quality back from this label.
  static String _label(Map<String, dynamic> link) {
    final name = (link['name'] as String?)?.trim().isNotEmpty == true ? link['name'] as String : link['source'] as String? ?? 'Link';
    final quality = (link['quality'] as num?)?.toInt() ?? 0;
    // CloudStream's Qualities.Unknown is 400, and 0 or less means none.
    final known = quality > 0 && quality != 400 && !name.contains('${quality}p');
    return known ? '$name · ${quality}p' : name;
  }

  /// `0` - adaptive - for an HLS link with no quality of its own: CloudStream marks a master
  /// `Qualities.Unknown` (400) unless the extension says otherwise, and the player lists its
  /// qualities. Null for anything else: a known quality is in the label, and so is one the
  /// link's name states ("… 360p", "… HD"), which it is ranked by as before.
  static int? _adaptiveQuality(Map<String, dynamic> link) {
    final quality = (link['quality'] as num?)?.toInt() ?? 0;
    final known = quality > 0 && quality != 400;
    return !known && link['type'] == 'M3U8' && !labelStatesQuality(_label(link))
        ? 0
        : null;
  }

  static Map<String, String>? _headers(Map<String, dynamic> link) {
    final headers = <String, String>{...?(link['headers'] as Map?)?.map((k, v) => MapEntry('$k', '$v'))};
    final referer = link['referer'] as String?;
    if (referer != null && referer.isNotEmpty && !headers.keys.any((k) => k.toLowerCase() == 'referer')) {
      headers['Referer'] = referer;
    }
    return headers.isEmpty ? null : headers;
  }

  /// SkyStream's subtitles carry no headers, so ones that need them go through the local proxy.
  static Future<List<SubtitleFile>> _subtitles(List<Map<String, dynamic>> raw) async {
    final files = <SubtitleFile>[];
    for (final sub in raw) {
      var url = sub['url'] as String;
      final headers = (sub['headers'] as Map?)?.map((k, v) => MapEntry('$k', '$v'));
      if (headers != null && headers.isNotEmpty) {
        await LocalProxyService.instance.startServer();
        url = LocalProxyService.instance.getProxyUrl(url, headers: headers);
      }
      final lang = sub['lang'] as String? ?? 'Unknown';
      files.add(SubtitleFile(url: url, label: lang, lang: lang));
    }
    return files;
  }

  static List<Map<String, dynamic>> _list(Object? value) => [
    for (final entry in (value as List?) ?? const []) if (entry is Map) Map<String, dynamic>.from(entry),
  ];

  /// CloudStream `TvType` to SkyStream's content type.
  static MultimediaContentType _contentType(String? type) => switch (type) {
    'TvSeries' || 'Cartoon' || 'AsianDrama' || 'Documentary' => MultimediaContentType.series,
    'Anime' || 'OVA' => MultimediaContentType.anime,
    'Live' => MultimediaContentType.livestream,
    'Movie' || 'AnimeMovie' || 'Torrent' || 'NSFW' => MultimediaContentType.movie,
    _ => MultimediaContentType.other,
  };

  static ProviderType _providerType(String type) => switch (_contentType(type)) {
    MultimediaContentType.movie => ProviderType.movie,
    MultimediaContentType.series => ProviderType.series,
    MultimediaContentType.anime => ProviderType.anime,
    MultimediaContentType.livestream => ProviderType.livestream,
    MultimediaContentType.other => ProviderType.other,
  };
}
