import 'dart:convert';

class ProfileSyncPayload {
  static const String kMetaPackageName = '__skystream_sync_meta__';

  final int version;
  final int updatedAt;
  final List<Map<String, dynamic>> history;
  final Map<String, bool> episodeOverrides;
  final List<Map<String, dynamic>> library;
  final List<String> skystreamRepos;
  final List<Map<String, String>> skystreamPlugins;
  final List<String> cloudstreamRepos;
  final List<Map<String, String>> cloudstreamPlugins;
  final List<String> nuvioRepos;
  final List<String> stremioAddons;
  final bool replaceExtensions;
  final String? activeProviderId;
  final Map<String, Map<String, List<String>>> nuvioRepoSettings;
  final Map<String, bool> stremioAddonStates;
  final List<String> deletedHistoryKeys;
  final Map<String, int> deletedHistoryTimestamps;
  final List<String> deletedLibraryUrls;
  final bool replaceHistory;
  final bool replaceLibrary;

  const ProfileSyncPayload({
    this.version = 1,
    required this.updatedAt,
    this.history = const [],
    this.episodeOverrides = const {},
    this.library = const [],
    this.skystreamRepos = const [],
    this.skystreamPlugins = const [],
    this.cloudstreamRepos = const [],
    this.cloudstreamPlugins = const [],
    this.nuvioRepos = const [],
    this.stremioAddons = const [],
    this.replaceExtensions = false,
    this.activeProviderId,
    this.nuvioRepoSettings = const {},
    this.stremioAddonStates = const {},
    this.deletedHistoryKeys = const [],
    this.deletedHistoryTimestamps = const {},
    this.deletedLibraryUrls = const [],
    this.replaceHistory = false,
    this.replaceLibrary = false,
  });

  List<String> get effectiveDeletedHistoryKeys => deletedHistoryKeys.isNotEmpty
      ? deletedHistoryKeys
      : deletedHistoryTimestamps.keys.toList(growable: false);

  bool get _hasMetaFields =>
      (activeProviderId != null && activeProviderId!.isNotEmpty) ||
      nuvioRepoSettings.isNotEmpty ||
      stremioAddonStates.isNotEmpty ||
      effectiveDeletedHistoryKeys.isNotEmpty ||
      deletedHistoryTimestamps.isNotEmpty ||
      deletedLibraryUrls.isNotEmpty;

  Map<String, dynamic> toJson() {
    final plugins = [
      for (final plugin in skystreamPlugins)
        if (plugin['packageName'] != kMetaPackageName)
          Map<String, String>.from(plugin),
    ];
    if (_hasMetaFields) {
      plugins.add({
        'packageName': kMetaPackageName,
        if (activeProviderId != null && activeProviderId!.isNotEmpty)
          'activeProviderId': activeProviderId!,
        if (nuvioRepoSettings.isNotEmpty)
          'nuvioRepoSettings': jsonEncode(nuvioRepoSettings),
        if (stremioAddonStates.isNotEmpty)
          'stremioAddonStates': jsonEncode(stremioAddonStates),
        if (effectiveDeletedHistoryKeys.isNotEmpty)
          'deletedHistoryKeys': jsonEncode(effectiveDeletedHistoryKeys),
        if (deletedHistoryTimestamps.isNotEmpty)
          'deletedHistoryTimestamps': jsonEncode(deletedHistoryTimestamps),
        if (deletedLibraryUrls.isNotEmpty)
          'deletedLibraryUrls': jsonEncode(deletedLibraryUrls),
      });
    }

    return {
      'version': version,
      'updatedAt': updatedAt,
      'history': history,
      'episodeOverrides': episodeOverrides,
      'library': library,
      'skystreamRepos': skystreamRepos,
      'skystreamPlugins': plugins,
      'cloudstreamRepos': cloudstreamRepos,
      'cloudstreamPlugins': cloudstreamPlugins,
      'nuvioRepos': nuvioRepos,
      'stremioAddons': stremioAddons,
      'replaceExtensions': replaceExtensions,
      if (activeProviderId != null) 'activeProviderId': activeProviderId,
      if (nuvioRepoSettings.isNotEmpty) 'nuvioRepoSettings': nuvioRepoSettings,
      if (stremioAddonStates.isNotEmpty)
        'stremioAddonStates': stremioAddonStates,
      if (effectiveDeletedHistoryKeys.isNotEmpty)
        'deletedHistoryKeys': effectiveDeletedHistoryKeys,
      if (deletedHistoryTimestamps.isNotEmpty)
        'deletedHistoryTimestamps': deletedHistoryTimestamps,
      if (deletedLibraryUrls.isNotEmpty)
        'deletedLibraryUrls': deletedLibraryUrls,
      if (replaceHistory) 'replaceHistory': replaceHistory,
      if (replaceLibrary) 'replaceLibrary': replaceLibrary,
    };
  }

  factory ProfileSyncPayload.fromJson(Map<String, dynamic> json) {
    final rawPlugins = _stringMapList(json['skystreamPlugins']);
    Map<String, String>? metaEntry;
    final cleanPlugins = <Map<String, String>>[];
    for (final plugin in rawPlugins) {
      if (plugin['packageName'] == kMetaPackageName) {
        metaEntry = plugin;
      } else {
        cleanPlugins.add(plugin);
      }
    }

    final rawActiveProviderId =
        json['activeProviderId'] as String? ?? metaEntry?['activeProviderId'];
    final activeProviderId =
        rawActiveProviderId != null && rawActiveProviderId.isNotEmpty
        ? rawActiveProviderId
        : null;

    final nuvioRepoSettings = _parseNuvioRepoSettings(
      json['nuvioRepoSettings'] ?? _tryJsonDecode(metaEntry?['nuvioRepoSettings']),
    );
    final stremioAddonStates = _parseBoolMap(
      json['stremioAddonStates'] ?? _tryJsonDecode(metaEntry?['stremioAddonStates']),
    );
    final deletedHistoryKeys = _stringList(
      json['deletedHistoryKeys'] ?? _tryJsonDecode(metaEntry?['deletedHistoryKeys']),
    );
    final deletedHistoryTimestamps = _parseIntMap(
      json['deletedHistoryTimestamps'] ??
          _tryJsonDecode(metaEntry?['deletedHistoryTimestamps']),
    );
    final updatedAt = (json['updatedAt'] as num?)?.toInt() ?? 0;
    for (final key in deletedHistoryKeys) {
      deletedHistoryTimestamps.putIfAbsent(key, () => updatedAt);
    }
    final deletedLibraryUrls = _stringList(
      json['deletedLibraryUrls'] ?? _tryJsonDecode(metaEntry?['deletedLibraryUrls']),
    );

    return ProfileSyncPayload(
      version: (json['version'] as num?)?.toInt() ?? 1,
      updatedAt: updatedAt,
      history: _mapList(json['history']),
      episodeOverrides: {
        for (final entry
            in ((json['episodeOverrides'] as Map?) ?? const {}).entries)
          '${entry.key}': entry.value == true,
      },
      library: _mapList(json['library']),
      skystreamRepos: _stringList(json['skystreamRepos']),
      skystreamPlugins: cleanPlugins,
      cloudstreamRepos: _stringList(json['cloudstreamRepos']),
      cloudstreamPlugins: _stringMapList(json['cloudstreamPlugins']),
      nuvioRepos: _stringList(json['nuvioRepos']),
      stremioAddons: _stringList(json['stremioAddons']),
      replaceExtensions: json['replaceExtensions'] == true,
      activeProviderId: activeProviderId,
      nuvioRepoSettings: nuvioRepoSettings,
      stremioAddonStates: stremioAddonStates,
      deletedHistoryKeys: deletedHistoryKeys,
      deletedHistoryTimestamps: deletedHistoryTimestamps,
      deletedLibraryUrls: deletedLibraryUrls,
      replaceHistory: json['replaceHistory'] == true,
      replaceLibrary: json['replaceLibrary'] == true,
    );
  }

  static Object? _tryJsonDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  static Map<String, Map<String, List<String>>> _parseNuvioRepoSettings(
    Object? raw,
  ) {
    if (raw is! Map) return const {};
    final result = <String, Map<String, List<String>>>{};
    for (final entry in raw.entries) {
      final url = '${entry.key}';
      final val = entry.value;
      if (url.isEmpty || val is! Map) continue;
      result[url] = {
        'disabled': _stringList(val['disabled']),
        'enabled': _stringList(val['enabled']),
      };
    }
    return result;
  }

  static Map<String, bool> _parseBoolMap(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries) '${entry.key}': entry.value == true,
    };
  }

  static Map<String, int> _parseIntMap(Object? raw) {
    if (raw is! Map) return <String, int>{};
    final out = <String, int>{};
    for (final entry in raw.entries) {
      final val = entry.value;
      if (val is num) out['${entry.key}'] = val.toInt();
    }
    return out;
  }

  static List<Map<String, dynamic>> _mapList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is Map) Map<String, dynamic>.from(entry),
    ];
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is String) entry,
    ];
  }

  static List<Map<String, String>> _stringMapList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is Map)
          {for (final pair in entry.entries) '${pair.key}': '${pair.value}'},
    ];
  }
}
