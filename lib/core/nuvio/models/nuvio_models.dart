/// Models for Nuvio-style scraper plugins.
///
/// Nuvio (github.com/NuvioMedia/NuvioMobile) ships "plugins" that are JS
/// scrapers listed in a manifest:
///
/// ```json
/// { "name": "My plugins", "version": "1.0.0",
///   "scrapers": [ { "id": "x", "name": "X", "version": "1.0.0",
///                   "filename": "x.js", "supportedTypes": ["movie","tv"] } ] }
/// ```
///
/// Each scraper file exports `getStreams(tmdbId, mediaType, season, episode)`
/// and returns a list of link objects. SkyStream runs them alongside its own
/// plugins so both systems contribute links to the same sheet.
library;

import '../../domain/entity/multimedia_item.dart';

class NuvioScraperInfo {
  final String id;
  final String name;
  final String description;
  final String version;
  final String filename;
  final String author;
  final List<String> supportedTypes;
  final bool manifestEnabled;
  final String? logo;
  final List<String> contentLanguage;

  /// The scraper exposes `onSettings()` and expects the host to show a form
  /// and hand the values back in `SCRAPER_SETTINGS`. 54 of the 61 providers in
  /// All-in-One-Nuvio set this.
  final bool hasSettings;

  /// Container formats the scraper produces (`mp4`, `mkv`, `m3u8`, `torrent`).
  final List<String> formats;

  /// Manifest hint: the provider only returns a couple of links / low quality.
  final bool limited;

  /// Platform gating, exactly like Nuvio's `isSupportedOnCurrentPlatform`.
  final List<String> supportedPlatforms;
  final List<String> disabledPlatforms;

  const NuvioScraperInfo({
    required this.id,
    required this.name,
    required this.version,
    required this.filename,
    this.description = '',
    this.author = '',
    this.supportedTypes = const ['movie', 'tv'],
    this.manifestEnabled = true,
    this.logo,
    this.contentLanguage = const [],
    this.hasSettings = false,
    this.formats = const [],
    this.limited = false,
    this.supportedPlatforms = const [],
    this.disabledPlatforms = const [],
  });

  factory NuvioScraperInfo.fromJson(Map<String, dynamic> json) {
    final formats = _stringList(json['formats']).isEmpty
        ? _stringList(json['supportedFormats'])
        : _stringList(json['formats']);
    return NuvioScraperInfo(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      version: (json['version'] as String?)?.trim().isNotEmpty == true
          ? (json['version'] as String).trim()
          : '0.0.0',
      filename: (json['filename'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      author: (json['author'] as String?) ?? '',
      supportedTypes: _stringList(json['supportedTypes']).isEmpty
          ? const ['movie', 'tv']
          : _stringList(json['supportedTypes']),
      manifestEnabled: (json['enabled'] as bool?) ?? true,
      logo: json['logo'] as String?,
      contentLanguage: _stringList(json['contentLanguage']),
      hasSettings: (json['hasSettings'] as bool?) ?? false,
      formats: formats,
      limited: (json['limited'] as bool?) ?? false,
      supportedPlatforms: _stringList(json['supportedPlatforms']),
      disabledPlatforms: _stringList(json['disabledPlatforms']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'version': version,
    'filename': filename,
    'description': description,
    'author': author,
    'supportedTypes': supportedTypes,
    'enabled': manifestEnabled,
    'logo': logo,
    'contentLanguage': contentLanguage,
    'hasSettings': hasSettings,
    'formats': formats,
    'limited': limited,
    'supportedPlatforms': supportedPlatforms,
    'disabledPlatforms': disabledPlatforms,
  };

  /// Nuvio uses `movie` / `tv`; SkyStream and Stremio say `movie` / `series`.
  static String normalizeType(String type) {
    final t = type.toLowerCase();
    if (t == 'series' || t == 'show' || t == 'anime') return 'tv';
    if (t == 'film') return 'movie';
    return t;
  }

  bool supportsType(String type) {
    final wanted = normalizeType(type);
    return supportedTypes.map(normalizeType).contains(wanted);
  }

  /// Mirrors Nuvio: an empty `supportedPlatforms` means "everywhere", and
  /// `disabledPlatforms` always wins.
  bool isSupportedOn(String platform) {
    final p = platform.toLowerCase();
    if (disabledPlatforms.map((e) => e.toLowerCase()).contains(p)) return false;
    if (supportedPlatforms.isEmpty) return true;
    return supportedPlatforms.map((e) => e.toLowerCase()).contains(p);
  }
}

/// Sortable version compare (`1.0.10` > `1.0.9`, non-numeric parts compared
/// as text) used to decide whether the developer published an update.
int compareNuvioVersions(String a, String b) {
  List<String> parts(String v) =>
      v.trim().replaceAll(RegExp(r'^v'), '').split(RegExp(r'[.\-+]'));
  final left = parts(a);
  final right = parts(b);
  final length = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    final l = i < left.length ? left[i] : '0';
    final r = i < right.length ? right[i] : '0';
    final li = int.tryParse(l);
    final ri = int.tryParse(r);
    if (li != null && ri != null) {
      if (li != ri) return li.compareTo(ri);
    } else {
      final byText = l.compareTo(r);
      if (byText != 0) return byText;
    }
  }
  return 0;
}

/// What changed when a repository was refreshed — this is how a plugin update
/// published by its developer becomes visible in the app.
class NuvioUpdateSummary {
  final String? previousRepoVersion;
  final String? repoVersion;
  final List<NuvioScraperInfo> added;
  final List<({NuvioScraperInfo scraper, String from, String to})> updated;
  final List<String> removed;

  const NuvioUpdateSummary({
    this.previousRepoVersion,
    this.repoVersion,
    this.added = const [],
    this.updated = const [],
    this.removed = const [],
  });

  bool get hasChanges =>
      added.isNotEmpty ||
      updated.isNotEmpty ||
      removed.isNotEmpty ||
      (previousRepoVersion != null &&
          repoVersion != null &&
          previousRepoVersion != repoVersion);

  int get changeCount => added.length + updated.length + removed.length;

  /// Ids whose code must be re-downloaded.
  Set<String> get changedScraperIds => {
    for (final scraper in added) scraper.id,
    for (final entry in updated) entry.scraper.id,
  };

  String get label {
    if (!hasChanges) return 'Up to date';
    final parts = <String>[
      if (updated.isNotEmpty) '${updated.length} updated',
      if (added.isNotEmpty) '${added.length} new',
      if (removed.isNotEmpty) '${removed.length} removed',
    ];
    if (parts.isEmpty) return 'Repository version changed';
    return parts.join(' · ');
  }

  /// Diff of an installed manifest against the one just fetched.
  static NuvioUpdateSummary diff(
    NuvioManifest? installed,
    NuvioManifest fetched,
  ) {
    final before = {
      for (final scraper in installed?.scrapers ?? const <NuvioScraperInfo>[])
        scraper.id: scraper,
    };
    final added = <NuvioScraperInfo>[];
    final updated = <({NuvioScraperInfo scraper, String from, String to})>[];
    for (final scraper in fetched.scrapers) {
      final old = before[scraper.id];
      if (old == null) {
        added.add(scraper);
      } else if (compareNuvioVersions(scraper.version, old.version) != 0) {
        updated.add((scraper: scraper, from: old.version, to: scraper.version));
      }
    }
    final fetchedIds = {for (final s in fetched.scrapers) s.id};
    final removed = [
      for (final id in before.keys)
        if (!fetchedIds.contains(id)) id,
    ];
    return NuvioUpdateSummary(
      previousRepoVersion: installed?.version,
      repoVersion: fetched.version,
      added: added,
      updated: updated,
      removed: removed,
    );
  }
}

class NuvioManifest {
  final String name;
  final String version;
  final String description;
  final String? author;
  final List<NuvioScraperInfo> scrapers;

  const NuvioManifest({
    required this.name,
    required this.version,
    this.description = '',
    this.author,
    this.scrapers = const [],
  });

  factory NuvioManifest.fromJson(Map<String, dynamic> json) {
    final scrapers = <NuvioScraperInfo>[];
    final raw = json['scrapers'];
    if (raw is List) {
      for (final entry in raw) {
        if (entry is Map) {
          final scraper = NuvioScraperInfo.fromJson(
            Map<String, dynamic>.from(entry),
          );
          if (scraper.id.isNotEmpty && scraper.filename.isNotEmpty) {
            scrapers.add(scraper);
          }
        }
      }
    }
    return NuvioManifest(
      name: (json['name'] as String?) ?? '',
      version: (json['version'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      author: json['author'] as String?,
      scrapers: scrapers,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'version': version,
    'description': description,
    'author': author,
    'scrapers': scrapers.map((s) => s.toJson()).toList(),
  };

  bool get isValid =>
      name.trim().isNotEmpty &&
      version.trim().isNotEmpty &&
      scrapers.isNotEmpty;
}

/// A repository the user added, plus the scrapers it published.
class NuvioRepo {
  final String manifestUrl;
  final NuvioManifest? manifest;
  final DateTime addedAt;
  final String? errorMessage;

  /// Scraper ids the user switched off locally.
  final Set<String> disabledScrapers;

  /// Scraper ids the user switched **on** even though the manifest ships them
  /// disabled (repositories often publish torrent providers off by default).
  final Set<String> enabledOverrides;

  /// When the manifest was last fetched, and when that fetch actually brought
  /// something new. Both are what the UI shows as "checked 5m ago".
  final DateTime? lastCheckedAt;
  final DateTime? lastUpdatedAt;

  /// Transient: a refresh is in flight.
  final bool isRefreshing;

  /// Transient: what the last refresh changed, so the UI can say
  /// "3 updated · 1 new" and badge the scrapers that moved.
  final NuvioUpdateSummary? lastUpdate;

  const NuvioRepo({
    required this.manifestUrl,
    required this.addedAt,
    this.manifest,
    this.errorMessage,
    this.disabledScrapers = const {},
    this.enabledOverrides = const {},
    this.lastCheckedAt,
    this.lastUpdatedAt,
    this.isRefreshing = false,
    this.lastUpdate,
  });

  String get displayName =>
      manifest?.name ?? Uri.tryParse(manifestUrl)?.host ?? manifestUrl;

  bool isScraperEnabled(NuvioScraperInfo scraper) {
    if (disabledScrapers.contains(scraper.id)) return false;
    if (enabledOverrides.contains(scraper.id)) return true;
    return scraper.manifestEnabled;
  }

  List<NuvioScraperInfo> get enabledScrapers => [
    for (final scraper in manifest?.scrapers ?? const <NuvioScraperInfo>[])
      if (isScraperEnabled(scraper)) scraper,
  ];

  /// Scraper code lives next to the manifest.
  Uri? codeUrlFor(NuvioScraperInfo scraper) =>
      NuvioUrls.resolveCodeUrl(manifestUrl, scraper.filename);

  NuvioRepo copyWith({
    NuvioManifest? manifest,
    String? errorMessage,
    bool clearError = false,
    Set<String>? disabledScrapers,
    Set<String>? enabledOverrides,
    DateTime? lastCheckedAt,
    DateTime? lastUpdatedAt,
    bool? isRefreshing,
    NuvioUpdateSummary? lastUpdate,
    bool clearLastUpdate = false,
  }) {
    return NuvioRepo(
      manifestUrl: manifestUrl,
      addedAt: addedAt,
      manifest: manifest ?? this.manifest,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      disabledScrapers: disabledScrapers ?? this.disabledScrapers,
      enabledOverrides: enabledOverrides ?? this.enabledOverrides,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      lastUpdate: clearLastUpdate ? null : (lastUpdate ?? this.lastUpdate),
    );
  }

  Map<String, dynamic> toJson() => {
    'manifestUrl': manifestUrl,
    'addedAt': addedAt.toIso8601String(),
    'manifest': manifest?.toJson(),
    'disabled': disabledScrapers.toList(),
    'enabledOverrides': enabledOverrides.toList(),
    'lastCheckedAt': lastCheckedAt?.toIso8601String(),
    'lastUpdatedAt': lastUpdatedAt?.toIso8601String(),
  };

  static NuvioRepo? fromJson(Map<String, dynamic> json) {
    final url = json['manifestUrl'] as String?;
    if (url == null || url.isEmpty) return null;
    final rawManifest = json['manifest'];
    return NuvioRepo(
      manifestUrl: url,
      addedAt:
          DateTime.tryParse((json['addedAt'] as String?) ?? '') ??
          DateTime.now(),
      manifest: rawManifest is Map
          ? NuvioManifest.fromJson(Map<String, dynamic>.from(rawManifest))
          : null,
      disabledScrapers: {for (final id in _stringList(json['disabled'])) id},
      enabledOverrides: {
        for (final id in _stringList(json['enabledOverrides'])) id,
      },
      lastCheckedAt: DateTime.tryParse(
        (json['lastCheckedAt'] as String?) ?? '',
      ),
      lastUpdatedAt: DateTime.tryParse(
        (json['lastUpdatedAt'] as String?) ?? '',
      ),
    );
  }
}

/// One field of a scraper's `onSettings()` layout.
///
/// Nuvio renders `header`, `info`, `text`, `select` and `toggle`; the values
/// are saved per scraper and handed back to the plugin in `SCRAPER_SETTINGS`.
class NuvioSettingsField {
  final String type;
  final String key;
  final String label;
  final String? description;
  final String? placeholder;
  final bool isPassword;
  final dynamic defaultValue;
  final List<({String label, String value})> options;

  const NuvioSettingsField({
    required this.type,
    this.key = '',
    this.label = '',
    this.description,
    this.placeholder,
    this.isPassword = false,
    this.defaultValue,
    this.options = const [],
  });

  static NuvioSettingsField? fromJson(Map<String, dynamic> json) {
    final type = (json['type'] as String?)?.toLowerCase() ?? 'info';
    const known = {'header', 'info', 'text', 'select', 'toggle', 'number'};
    if (!known.contains(type)) return null;
    final options = <({String label, String value})>[];
    final rawOptions = json['options'];
    if (rawOptions is List) {
      for (final entry in rawOptions) {
        if (entry is Map) {
          final value = entry['value']?.toString() ?? '';
          if (value.isEmpty) continue;
          options.add((
            label: entry['label']?.toString() ?? value,
            value: value,
          ));
        } else if (entry is String) {
          options.add((label: entry, value: entry));
        }
      }
    }
    return NuvioSettingsField(
      type: type,
      // Real plugins use `key`, some also ship a snake_case `name` alias.
      key: (json['key'] ?? json['name'])?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      description: json['description']?.toString(),
      placeholder: json['placeholder']?.toString(),
      isPassword: (json['isPassword'] as bool?) ?? false,
      // Nuvio's dialog reads `defaultValue`, but every provider in
      // All-in-One-Nuvio writes `default` — accept both.
      defaultValue: json['defaultValue'] ?? json['default'],
      options: options,
    );
  }

  static List<NuvioSettingsField> parseLayout(dynamic raw) {
    if (raw is! List) return const [];
    final out = <NuvioSettingsField>[];
    for (final entry in raw) {
      if (entry is Map) {
        final field = NuvioSettingsField.fromJson(
          Map<String, dynamic>.from(entry),
        );
        if (field != null) out.add(field);
      }
    }
    return out;
  }

  /// Values the plugin should see before the user touches anything.
  static Map<String, dynamic> defaults(List<NuvioSettingsField> fields) => {
    for (final field in fields)
      if (field.key.isNotEmpty && field.defaultValue != null)
        field.key: field.defaultValue,
  };
}

/// One link produced by a Nuvio scraper.
class NuvioStreamResult {
  final String scraperId;
  final String scraperName;
  final String title;
  final String? name;
  final String url;
  final String? quality;
  final String? size;
  final String? language;
  final String? provider;
  final String? type;
  final int? seeders;
  final String? infoHash;
  final Map<String, String>? headers;
  final List<SubtitleFile> subtitles;

  const NuvioStreamResult({
    required this.scraperId,
    required this.scraperName,
    required this.title,
    required this.url,
    this.name,
    this.quality,
    this.size,
    this.language,
    this.provider,
    this.type,
    this.seeders,
    this.infoHash,
    this.headers,
    this.subtitles = const [],
  });

  /// Nuvio scrapers are loose about shapes: `url` can be a string or an
  /// object, headers can hide in `behaviorHints.proxyHeaders.request` (that is
  /// where 4KHDHub puts the Referer its CDN insists on), numbers arrive as
  /// strings, and several providers pad titles with zero-width characters to
  /// force their own sort order.
  static NuvioStreamResult? fromJson(
    Map<String, dynamic> json, {
    required String scraperId,
    required String scraperName,
  }) {
    String? url;
    for (final candidate in [
      json['url'],
      json['link'],
      json['stream'],
      json['file'],
      json['externalUrl'],
    ]) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        url = candidate.trim();
        break;
      }
      if (candidate is Map && candidate['url'] is String) {
        final nested = (candidate['url'] as String).trim();
        if (nested.isNotEmpty) {
          url = nested;
          break;
        }
      }
    }
    final behaviorHints = json['behaviorHints'] is Map
        ? Map<String, dynamic>.from(json['behaviorHints'] as Map)
        : const <String, dynamic>{};
    if (url == null || url.isEmpty) {
      final direct = behaviorHints['directUrl'] ?? behaviorHints['url'];
      if (direct is String && direct.trim().isNotEmpty) url = direct.trim();
    }

    final infoHash = (json['infoHash'] as String?)?.trim();
    if ((url == null || url.isEmpty) &&
        (infoHash == null || infoHash.isEmpty)) {
      return null;
    }

    Map<String, String>? readHeaders(dynamic raw) {
      if (raw is! Map) return null;
      final map = <String, String>{};
      raw.forEach((key, value) {
        if (key is String && value != null && value is! Map && value is! List) {
          map[key] = value.toString();
        }
      });
      return map.isEmpty ? null : map;
    }

    final proxyHeaders = behaviorHints['proxyHeaders'];
    final headers =
        readHeaders(json['headers']) ??
        readHeaders(proxyHeaders is Map ? proxyHeaders['request'] : null) ??
        readHeaders(behaviorHints['headers']) ??
        readHeaders(json['requestHeaders']);

    final subtitles = <SubtitleFile>[];
    final rawSubs = json['subtitles'];
    if (rawSubs is List) {
      for (final entry in rawSubs) {
        if (entry is! Map) continue;
        final subUrl = entry['url'];
        if (subUrl is! String || subUrl.isEmpty) continue;
        final lang = (entry['language'] ?? entry['lang'] ?? 'und').toString();
        subtitles.add(
          SubtitleFile(
            url: subUrl,
            label: (entry['name'] as String?) ?? lang,
            lang: lang,
          ),
        );
      }
    }

    final title = _clean(
      (json['title'] ?? json['name'] ?? scraperName).toString(),
    );
    final name = json['name'] == null ? null : _clean(json['name'].toString());
    final quality =
        _cleanOrNull(json['quality']?.toString()) ??
        _qualityFromText('$title ${name ?? ''}');
    final size =
        _cleanOrNull(json['size']?.toString()) ??
        _sizeFromBytes(json['sizeBytes'] ?? json['filesize'] ?? json['bytes']);

    return NuvioStreamResult(
      scraperId: scraperId,
      scraperName: scraperName,
      title: title,
      name: name,
      url: url ?? 'magnet:?xt=urn:btih:$infoHash',
      quality: quality,
      size: size,
      language: _cleanOrNull(json['language']?.toString()),
      provider: _cleanOrNull(json['provider']?.toString()),
      type: json['type']?.toString(),
      seeders: _asInt(json['seeders']),
      infoHash: infoHash,
      headers: headers,
      subtitles: subtitles,
    );
  }

  bool get isTorrent =>
      url.startsWith('magnet:') || (infoHash?.isNotEmpty ?? false);

  /// Label shown in the sources list / player.
  String get label {
    final parts = <String>[
      if (quality != null && quality!.trim().isNotEmpty) quality!.trim(),
      if (size != null && size!.trim().isNotEmpty) size!.trim(),
      if (language != null && language!.trim().isNotEmpty) language!.trim(),
      if (seeders != null) '${seeders!} seeds',
    ];
    if (parts.isEmpty) return title;
    return parts.join(' · ');
  }

  StreamResult toStreamResult() => StreamResult(
    url: url,
    source: label,
    providerName: provider?.trim().isNotEmpty ?? false
        ? '$scraperName · ${provider!.trim()}'
        : scraperName,
    headers: headers,
    subtitles: subtitles.isEmpty ? null : subtitles,
  );
}

class NuvioUrls {
  const NuvioUrls._();

  /// Accepts bare hosts and direct manifest links, like the add-on installer.
  static String normalizeManifestUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return url;
    if (url.startsWith('nuvio://')) {
      url = 'https://${url.substring('nuvio://'.length)}';
    } else if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    url = url.split('#').first;
    if (!url.split('?').first.toLowerCase().endsWith('.json')) {
      final base = url.split('?').first;
      final query = url.contains('?') ? url.substring(url.indexOf('?')) : '';
      final trimmed = base.endsWith('/')
          ? base.substring(0, base.length - 1)
          : base;
      url = '$trimmed/manifest.json$query';
    }
    return url;
  }

  /// `filename` may be a bare name, a relative path or an absolute URL.
  static Uri? resolveCodeUrl(String manifestUrl, String filename) {
    if (filename.trim().isEmpty) return null;
    final manifest = Uri.tryParse(manifestUrl);
    if (manifest == null) return null;
    return manifest.resolve(filename);
  }
}

/// Providers pad titles with zero-width characters (4KHDHub encodes a sort
/// key that way). They must not reach the UI.
String _clean(String value) =>
    value.replaceAll(RegExp(r'[\u200b-\u200f\ufeff]'), '').trim();

String? _cleanOrNull(String? value) {
  if (value == null) return null;
  final cleaned = _clean(value);
  return cleaned.isEmpty ? null : cleaned;
}

/// Some scrapers only put the resolution in the title; the sources sheet sorts
/// on quality, so pull it out.
String? _qualityFromText(String text) {
  final lower = text.toLowerCase();
  for (final entry in const [
    ('2160p', ['2160p', '4k', 'uhd']),
    ('1440p', ['1440p', '2k']),
    ('1080p', ['1080p', 'fhd']),
    ('720p', ['720p', 'hd']),
    ('480p', ['480p']),
    ('360p', ['360p']),
  ]) {
    for (final needle in entry.$2) {
      if (lower.contains(needle)) return entry.$1;
    }
  }
  return null;
}

String? _sizeFromBytes(dynamic raw) {
  final bytes = raw is num ? raw.toDouble() : double.tryParse('${raw ?? ''}');
  if (bytes == null || bytes <= 0) return null;
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
}

int? _asInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return const [];
  final out = <String>[];
  for (final entry in raw) {
    if (entry is String && entry.trim().isNotEmpty) out.add(entry.trim());
  }
  return out;
}
