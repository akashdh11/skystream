class ProfileSyncPayload {
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
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'updatedAt': updatedAt,
    'history': history,
    'episodeOverrides': episodeOverrides,
    'library': library,
    'skystreamRepos': skystreamRepos,
    'skystreamPlugins': skystreamPlugins,
    'cloudstreamRepos': cloudstreamRepos,
    'cloudstreamPlugins': cloudstreamPlugins,
    'nuvioRepos': nuvioRepos,
    'stremioAddons': stremioAddons,
    'replaceExtensions': replaceExtensions,
  };

  factory ProfileSyncPayload.fromJson(Map<String, dynamic> json) {
    return ProfileSyncPayload(
      version: (json['version'] as num?)?.toInt() ?? 1,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      history: _mapList(json['history']),
      episodeOverrides: {
        for (final entry
            in ((json['episodeOverrides'] as Map?) ?? const {}).entries)
          '${entry.key}': entry.value == true,
      },
      library: _mapList(json['library']),
      skystreamRepos: _stringList(json['skystreamRepos']),
      skystreamPlugins: _stringMapList(json['skystreamPlugins']),
      cloudstreamRepos: _stringList(json['cloudstreamRepos']),
      cloudstreamPlugins: _stringMapList(json['cloudstreamPlugins']),
      nuvioRepos: _stringList(json['nuvioRepos']),
      stremioAddons: _stringList(json['stremioAddons']),
      replaceExtensions: json['replaceExtensions'] == true,
    );
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
