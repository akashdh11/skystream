/// Stremio add-on manifest model + transport URL handling.
///
/// Modelled on how NuvioMobile and ARVIO talk to add-ons:
/// * the manifest URL's **query string is preserved** — configurable add-ons
///   (Torrentio, Comet, MediaFusion…) carry their configuration there, and
///   dropping it makes every resource call fail;
/// * `resources` may be plain strings *or* objects, and object resources
///   inherit the manifest-level `types` / `idPrefixes` when they omit them.
library;

class AddonExtraProperty {
  final String name;
  final bool isRequired;
  final List<String> options;
  final int? optionsLimit;

  const AddonExtraProperty({
    required this.name,
    this.isRequired = false,
    this.options = const [],
    this.optionsLimit,
  });

  factory AddonExtraProperty.fromJson(Map<String, dynamic> json) {
    return AddonExtraProperty(
      name: (json['name'] as String?) ?? '',
      isRequired: (json['isRequired'] as bool?) ?? false,
      options: _stringList(json['options']),
      optionsLimit: (json['optionsLimit'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'isRequired': isRequired,
    'options': options,
    if (optionsLimit != null) 'optionsLimit': optionsLimit,
  };
}

class AddonCatalog {
  final String type;
  final String id;
  final String name;
  final List<AddonExtraProperty> extra;

  const AddonCatalog({
    required this.type,
    required this.id,
    required this.name,
    this.extra = const [],
  });

  factory AddonCatalog.fromJson(Map<String, dynamic> json) {
    final extras = <AddonExtraProperty>[];
    final raw = json['extra'];
    if (raw is List) {
      for (final entry in raw) {
        if (entry is Map) {
          final parsed = AddonExtraProperty.fromJson(
            Map<String, dynamic>.from(entry),
          );
          if (parsed.name.isNotEmpty) extras.add(parsed);
        }
      }
    }
    // Legacy manifests: extraSupported / extraRequired string lists.
    final supported = _stringList(json['extraSupported']);
    final required = _stringList(json['extraRequired']);
    for (final name in {...supported, ...required}) {
      if (extras.any((e) => e.name == name)) continue;
      extras.add(
        AddonExtraProperty(name: name, isRequired: required.contains(name)),
      );
    }

    final id = (json['id'] as String?) ?? '';
    final type = (json['type'] as String?) ?? '';
    final name = (json['name'] as String?) ?? '';
    return AddonCatalog(
      type: type,
      id: id,
      name: name.isEmpty ? id : name,
      extra: extras,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'name': name,
    'extra': extra.map((e) => e.toJson()).toList(),
  };

  bool get supportsSearch => extra.any((e) => e.name == 'search');

  /// Catalogs that only answer with `search=` are not browsable rows.
  bool get requiresSearch =>
      extra.any((e) => e.name == 'search' && e.isRequired);

  bool get requiresOtherExtra =>
      extra.any((e) => e.isRequired && e.name != 'search' && e.name != 'skip');

  bool get supportsSkip => extra.any((e) => e.name == 'skip');

  /// Genre options a catalog advertises, used for the filter chips.
  List<String> get genres {
    for (final property in extra) {
      if (property.name == 'genre') return property.options;
    }
    return const [];
  }

  String get key => '$type/$id';
}

class AddonResource {
  final String name;
  final List<String> types;
  final List<String> idPrefixes;

  const AddonResource({
    required this.name,
    this.types = const [],
    this.idPrefixes = const [],
  });

  factory AddonResource.fromDynamic(
    dynamic raw, {
    required List<String> defaultTypes,
    required List<String> defaultPrefixes,
  }) {
    if (raw is String) {
      return AddonResource(
        name: raw,
        types: defaultTypes,
        idPrefixes: defaultPrefixes,
      );
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final types = _stringList(map['types']);
      final prefixes = _stringList(map['idPrefixes']);
      return AddonResource(
        name: (map['name'] as String?) ?? '',
        types: types.isEmpty ? defaultTypes : types,
        idPrefixes: prefixes.isEmpty ? defaultPrefixes : prefixes,
      );
    }
    return const AddonResource(name: '');
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'types': types,
    'idPrefixes': idPrefixes,
  };
}

class AddonBehaviorHints {
  final bool configurable;
  final bool configurationRequired;
  final bool adult;
  final bool p2p;

  const AddonBehaviorHints({
    this.configurable = false,
    this.configurationRequired = false,
    this.adult = false,
    this.p2p = false,
  });

  factory AddonBehaviorHints.fromJson(Map<String, dynamic> json) {
    return AddonBehaviorHints(
      configurable: (json['configurable'] as bool?) ?? false,
      configurationRequired: (json['configurationRequired'] as bool?) ?? false,
      adult: (json['adult'] as bool?) ?? false,
      p2p: (json['p2p'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'configurable': configurable,
    'configurationRequired': configurationRequired,
    'adult': adult,
    'p2p': p2p,
  };
}

class AddonManifest {
  final String id;
  final String name;
  final String description;
  final String version;
  final String? logoUrl;
  final List<AddonResource> resources;
  final List<String> types;
  final List<String> idPrefixes;
  final List<AddonCatalog> catalogs;
  final AddonBehaviorHints behaviorHints;

  const AddonManifest({
    required this.id,
    required this.name,
    required this.version,
    this.description = '',
    this.logoUrl,
    this.resources = const [],
    this.types = const [],
    this.idPrefixes = const [],
    this.catalogs = const [],
    this.behaviorHints = const AddonBehaviorHints(),
  });

  factory AddonManifest.fromJson(Map<String, dynamic> json) {
    final defaultTypes = _stringList(json['types']);
    final defaultPrefixes = _stringList(json['idPrefixes']);

    final resources = <AddonResource>[];
    final rawResources = json['resources'];
    if (rawResources is List) {
      for (final entry in rawResources) {
        final parsed = AddonResource.fromDynamic(
          entry,
          defaultTypes: defaultTypes,
          defaultPrefixes: defaultPrefixes,
        );
        if (parsed.name.isNotEmpty) resources.add(parsed);
      }
    }

    final catalogs = <AddonCatalog>[];
    final rawCatalogs = json['catalogs'];
    if (rawCatalogs is List) {
      for (final entry in rawCatalogs) {
        if (entry is Map) {
          final catalog = AddonCatalog.fromJson(
            Map<String, dynamic>.from(entry),
          );
          if (catalog.type.isNotEmpty && catalog.id.isNotEmpty) {
            catalogs.add(catalog);
          }
        }
      }
    }

    final hints = json['behaviorHints'];
    return AddonManifest(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Add-on',
      version: (json['version'] as String?) ?? '0.0.0',
      description: (json['description'] as String?) ?? '',
      logoUrl: json['logo'] as String?,
      resources: resources,
      types: defaultTypes,
      idPrefixes: defaultPrefixes,
      catalogs: catalogs,
      behaviorHints: hints is Map
          ? AddonBehaviorHints.fromJson(Map<String, dynamic>.from(hints))
          : const AddonBehaviorHints(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'version': version,
    'description': description,
    'logo': logoUrl,
    'resources': resources.map((r) => r.toJson()).toList(),
    'types': types,
    'idPrefixes': idPrefixes,
    'catalogs': catalogs.map((c) => c.toJson()).toList(),
    'behaviorHints': behaviorHints.toJson(),
  };

  bool hasResource(String resource) => resources.any((r) => r.name == resource);

  AddonResource? resource(String name) {
    for (final r in resources) {
      if (r.name == name) return r;
    }
    return null;
  }

  /// Type aliases, following ARVIO: add-ons are inconsistent about whether a
  /// show is `series`, `tv` or `show`.
  static List<String> typeAliases(String type) {
    final normalized = type.toLowerCase();
    if (normalized == 'series' || normalized == 'tv' || normalized == 'show') {
      return const ['series', 'tv', 'show'];
    }
    if (normalized == 'movie' || normalized == 'film') {
      return const ['movie', 'film'];
    }
    return [normalized];
  }

  /// Types this add-on will actually be asked for, given a requested type.
  ///
  /// Priority: the resource's own `types` (the spec's narrowing), then the
  /// manifest-level `types` as a fallback, and finally — when the manifest
  /// declares nothing at all — the requested type anyway. Under-declared
  /// manifests are extremely common, and one wasted request beats an empty
  /// screen.
  List<String> requestTypesFor(String resource, String requested) {
    final aliases = typeAliases(requested);

    List<String> matching(Iterable<String> declared) {
      final set = declared.map((t) => t.toLowerCase()).toSet()
        ..removeWhere((t) => t.isEmpty);
      if (set.isEmpty) return const [];
      return aliases.where(set.contains).toList();
    }

    final resourceTypes = this.resource(resource)?.types ?? const <String>[];
    final fromResource = matching(resourceTypes);
    if (fromResource.isNotEmpty) return fromResource;

    final fromManifest = matching(types);
    if (fromManifest.isNotEmpty) return fromManifest;

    // Nothing declared anywhere -> ask with the canonical alias.
    if (resourceTypes.isEmpty && types.isEmpty) return [aliases.first];
    return const [];
  }

  /// `idPrefixes` gate, matching either `prefix` or `prefix:`.
  bool supportsId(String resource, String id) {
    final prefixes = <String>{
      ...idPrefixes,
      ...?this.resource(resource)?.idPrefixes,
    }..removeWhere((p) => p.trim().isEmpty);
    if (prefixes.isEmpty) return true;

    final lower = id.toLowerCase();
    return prefixes.any((prefix) {
      final p = prefix.toLowerCase();
      return lower.startsWith(p) ||
          (!p.endsWith(':') && lower.startsWith('$p:'));
    });
  }
}

/// An add-on as the user manages it: URL + parsed manifest + local state.
class ManagedAddon {
  final String manifestUrl;
  final AddonManifest? manifest;
  final bool enabled;
  final String? errorMessage;
  final DateTime addedAt;

  const ManagedAddon({
    required this.manifestUrl,
    this.manifest,
    this.enabled = true,
    this.errorMessage,
    required this.addedAt,
  });

  String get id =>
      manifest?.id.isNotEmpty ?? false ? manifest!.id : manifestUrl;

  String get displayName =>
      manifest?.name ?? Uri.tryParse(manifestUrl)?.host ?? 'Add-on';

  bool get isActive => enabled && manifest != null;

  ManagedAddon copyWith({
    String? manifestUrl,
    AddonManifest? manifest,
    bool? enabled,
    String? errorMessage,
    bool clearError = false,
    DateTime? addedAt,
  }) {
    return ManagedAddon(
      manifestUrl: manifestUrl ?? this.manifestUrl,
      manifest: manifest ?? this.manifest,
      enabled: enabled ?? this.enabled,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'manifestUrl': manifestUrl,
    'manifest': manifest?.toJson(),
    'enabled': enabled,
    'addedAt': addedAt.toIso8601String(),
  };

  static ManagedAddon? fromJson(Map<String, dynamic> json) {
    final url = json['manifestUrl'] as String?;
    if (url == null || url.isEmpty) return null;
    final rawManifest = json['manifest'];
    return ManagedAddon(
      manifestUrl: url,
      manifest: rawManifest is Map
          ? AddonManifest.fromJson(Map<String, dynamic>.from(rawManifest))
          : null,
      enabled: (json['enabled'] as bool?) ?? true,
      addedAt:
          DateTime.tryParse((json['addedAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

/// URL helpers. The query string of a manifest URL is part of the add-on's
/// configuration and must survive into every resource request.
class AddonTransport {
  const AddonTransport._();

  /// Accepts bare hosts, `stremio://` links and deep configuration URLs.
  static String normalizeManifestUrl(String rawUrl) {
    var trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return trimmed;

    if (trimmed.startsWith('stremio://')) {
      trimmed = 'https://${trimmed.substring('stremio://'.length)}';
    } else if (!trimmed.startsWith('http://') &&
        !trimmed.startsWith('https://')) {
      trimmed = 'https://$trimmed';
    }

    final withoutFragment = trimmed.split('#').first;
    final queryIndex = withoutFragment.indexOf('?');
    var path = queryIndex >= 0
        ? withoutFragment.substring(0, queryIndex)
        : withoutFragment;
    final query = queryIndex >= 0
        ? withoutFragment.substring(queryIndex + 1)
        : '';

    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (!path.endsWith('/manifest.json')) {
      path = '$path/manifest.json';
    }
    return query.isEmpty ? path : '$path?$query';
  }

  static String baseUrl(String manifestUrl) {
    final path = manifestUrl.split('?').first;
    const suffix = '/manifest.json';
    return path.endsWith(suffix)
        ? path.substring(0, path.length - suffix.length)
        : path;
  }

  static String _query(String manifestUrl) {
    final index = manifestUrl.indexOf('?');
    return index < 0 ? '' : manifestUrl.substring(index + 1);
  }

  /// `{base}/{resource}/{type}/{id}.json[/{extra}]?{original query}`
  static String resourceUrl(
    String manifestUrl, {
    required String resource,
    required String type,
    required String id,
    Map<String, String>? extra,
  }) {
    final base = baseUrl(manifestUrl);
    final query = _query(manifestUrl);
    final encodedId = Uri.encodeComponent(id);

    final buffer = StringBuffer('$base/$resource/$type/$encodedId');
    if (extra != null && extra.isNotEmpty) {
      final parts = <String>[];
      extra.forEach((key, value) {
        if (value.isEmpty) return;
        parts.add('$key=${Uri.encodeComponent(value)}');
      });
      if (parts.isNotEmpty) buffer.write('/${parts.join('&')}');
    }
    buffer.write('.json');
    if (query.isNotEmpty) buffer.write('?$query');
    return buffer.toString();
  }

  static bool looksValid(String rawUrl) {
    final uri = Uri.tryParse(normalizeManifestUrl(rawUrl));
    return uri != null && uri.hasAuthority && uri.host.contains('.');
  }
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return const [];
  final out = <String>[];
  for (final entry in raw) {
    if (entry is String && entry.trim().isNotEmpty) out.add(entry.trim());
  }
  return out;
}
