import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../network/dio_client_provider.dart';
import '../models/addon_manifest.dart';
import '../models/addon_meta.dart';
import '../models/addon_stream_source.dart';

part 'addon_client.g.dart';

@Riverpod(keepAlive: true)
AddonClient addonClient(Ref ref) => AddonClient(ref.watch(dioClientProvider));

class AddonException implements Exception {
  final String message;
  const AddonException(this.message);
  @override
  String toString() => message;
}

/// TTL cache with single-flight coalescing.
///
/// Add-on endpoints are pure GETs, so caching them is what makes the tab feel
/// instant on revisits; coalescing means ten widgets asking for the same
/// catalog issue exactly one request.
class _Cache {
  final Map<String, _Entry> _entries = {};
  final Map<String, Future<Object?>> _inFlight = {};
  static const int _maxEntries = 120;

  T? read<T>(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (entry.expiresAt.isBefore(DateTime.now())) {
      _entries.remove(key);
      return null;
    }
    final value = entry.value;
    return value is T ? value : null;
  }

  Future<T> run<T>(String key, Duration ttl, Future<T> Function() task) async {
    final cached = read<T>(key);
    if (cached != null) return cached;

    final pending = _inFlight[key];
    if (pending != null) {
      final value = await pending;
      if (value is T) return value;
    }

    final future = task();
    _inFlight[key] = future;
    try {
      final value = await future;
      if (_entries.length >= _maxEntries) {
        for (final k in _entries.keys.take(_maxEntries ~/ 4).toList()) {
          _entries.remove(k);
        }
      }
      _entries[key] = _Entry(value, DateTime.now().add(ttl));
      return value;
    } finally {
      _inFlight.remove(key)?.ignore();
    }
  }

  void invalidatePrefix(String prefix) =>
      _entries.removeWhere((key, _) => key.startsWith(prefix));

  void clear() => _entries.clear();
}

class _Entry {
  final Object? value;
  final DateTime expiresAt;
  const _Entry(this.value, this.expiresAt);
}

/// Community add-on entry from Stremio's public collection.
class CommunityAddon {
  final String transportUrl;
  final AddonManifest manifest;
  const CommunityAddon({required this.transportUrl, required this.manifest});
}

/// HTTP layer for the Stremio add-on protocol.
class AddonClient {
  AddonClient(this._dio);

  final Dio _dio;
  final _Cache _cache = _Cache();

  static const Duration manifestTtl = Duration(hours: 6);
  static const Duration catalogTtl = Duration(minutes: 15);
  static const Duration metaTtl = Duration(minutes: 45);
  static const Duration streamTtl = Duration(minutes: 5);
  static const Duration subtitleTtl = Duration(minutes: 30);

  static const Duration _fast = Duration(seconds: 12);
  static const Duration _slow = Duration(seconds: 20);

  Options _options(Duration timeout) => Options(
    receiveTimeout: timeout,
    sendTimeout: timeout,
    headers: const {'Accept': 'application/json'},
    validateStatus: (status) => status != null && status < 500,
  );

  Future<Map<String, dynamic>?> _getJson(
    String url, {
    Duration timeout = _fast,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<dynamic>(
      url,
      options: _options(timeout),
      cancelToken: cancelToken,
    );
    final status = response.statusCode ?? 0;
    // 404 is the protocol's "nothing for this id".
    if (status == 404) return null;
    if (status < 200 || status >= 300) {
      throw AddonException('HTTP $status from ${Uri.parse(url).host}');
    }

    var data = response.data;
    if (data is String) {
      final trimmed = data.trimLeft();
      if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
        throw const AddonException(
          'Add-on returned a non-JSON response (blocked or offline?).',
        );
      }
      try {
        data = jsonDecode(data);
      } catch (_) {
        throw const AddonException('Add-on returned malformed JSON.');
      }
    }
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  Future<AddonManifest> fetchManifest(
    String manifestUrl, {
    bool forceRefresh = false,
  }) async {
    final url = AddonTransport.normalizeManifestUrl(manifestUrl);
    final key = 'manifest:$url';
    if (forceRefresh) _cache.invalidatePrefix(key);

    return _cache.run(key, manifestTtl, () async {
      final json = await _getJson(url, timeout: _slow);
      if (json == null) {
        throw const AddonException('No manifest found at that URL.');
      }
      final manifest = AddonManifest.fromJson(json);
      if (manifest.id.isEmpty && manifest.resources.isEmpty) {
        throw const AddonException(
          'That URL does not look like a Stremio add-on manifest.',
        );
      }
      return manifest;
    });
  }

  Future<List<AddonMetaPreview>> catalog(
    ManagedAddon addon, {
    required String type,
    required String id,
    Map<String, String>? extra,
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) async {
    final url = AddonTransport.resourceUrl(
      addon.manifestUrl,
      resource: 'catalog',
      type: type,
      id: id,
      extra: extra,
    );
    if (forceRefresh) _cache.invalidatePrefix('catalog:$url');

    return _cache.run('catalog:$url', catalogTtl, () async {
      final json = await _getJson(url, cancelToken: cancelToken);
      final metas = json?['metas'];
      if (metas is! List) return const <AddonMetaPreview>[];
      final out = <AddonMetaPreview>[];
      for (final entry in metas) {
        if (entry is Map) {
          final preview = AddonMetaPreview.fromJson(
            Map<String, dynamic>.from(entry),
            addonId: addon.id,
            addonName: addon.displayName,
          );
          if (preview.id.isNotEmpty && preview.name.isNotEmpty) {
            out.add(preview);
          }
        }
      }
      return out;
    });
  }

  Future<AddonMeta?> meta(
    ManagedAddon addon, {
    required String type,
    required String id,
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) async {
    final url = AddonTransport.resourceUrl(
      addon.manifestUrl,
      resource: 'meta',
      type: type,
      id: id,
    );
    if (forceRefresh) _cache.invalidatePrefix('meta:$url');

    return _cache.run('meta:$url', metaTtl, () async {
      final json = await _getJson(url, cancelToken: cancelToken);
      final meta = json?['meta'];
      if (meta is! Map) return null;
      return AddonMeta.fromJson(
        Map<String, dynamic>.from(meta),
        addonId: addon.id,
        addonName: addon.displayName,
      );
    });
  }

  Future<List<AddonStreamSource>> streams(
    ManagedAddon addon, {
    required String type,
    required String id,
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) async {
    final url = AddonTransport.resourceUrl(
      addon.manifestUrl,
      resource: 'stream',
      type: type,
      id: id,
    );
    if (forceRefresh) _cache.invalidatePrefix('stream:$url');

    return _cache.run('stream:$url', streamTtl, () async {
      final json = await _getJson(
        url,
        timeout: _slow,
        cancelToken: cancelToken,
      );
      final streams = json?['streams'];
      if (streams is! List) return const <AddonStreamSource>[];
      final out = <AddonStreamSource>[];
      for (final entry in streams) {
        if (entry is Map) {
          final stream = AddonStreamSource.fromJson(
            Map<String, dynamic>.from(entry),
            addonId: addon.id,
            addonName: addon.displayName,
          );
          if (stream.kind != AddonStreamKind.unknown) out.add(stream);
        }
      }
      return out;
    });
  }

  Future<List<AddonSubtitleTrack>> subtitles(
    ManagedAddon addon, {
    required String type,
    required String id,
    Map<String, String>? extra,
    CancelToken? cancelToken,
  }) async {
    final url = AddonTransport.resourceUrl(
      addon.manifestUrl,
      resource: 'subtitles',
      type: type,
      id: id,
      extra: extra,
    );

    return _cache.run('subs:$url', subtitleTtl, () async {
      final json = await _getJson(url, cancelToken: cancelToken);
      final subs = json?['subtitles'];
      if (subs is! List) return const <AddonSubtitleTrack>[];
      final out = <AddonSubtitleTrack>[];
      for (var i = 0; i < subs.length; i++) {
        final entry = subs[i];
        if (entry is Map) {
          final sub = AddonSubtitleTrack.fromJson(
            Map<String, dynamic>.from(entry),
            addonName: addon.displayName,
            index: i,
          );
          if (sub != null) out.add(sub);
        }
      }
      return out;
    });
  }

  /// Stremio's official community collection, used by the Discover tab.
  Future<List<CommunityAddon>> communityAddons({
    bool forceRefresh = false,
  }) async {
    const key = 'community';
    if (forceRefresh) _cache.invalidatePrefix(key);

    return _cache.run(key, const Duration(hours: 3), () async {
      try {
        final response = await _dio.get<dynamic>(
          'https://api.strem.io/addonscollection.json',
          options: _options(_slow),
        );
        final data = response.data;
        if (data is! List) return const <CommunityAddon>[];
        final out = <CommunityAddon>[];
        for (final entry in data) {
          if (entry is! Map) continue;
          final map = Map<String, dynamic>.from(entry);
          final transportUrl = map['transportUrl'] as String?;
          final manifest = map['manifest'];
          if (transportUrl == null || manifest is! Map) continue;
          out.add(
            CommunityAddon(
              transportUrl: transportUrl,
              manifest: AddonManifest.fromJson(
                Map<String, dynamic>.from(manifest),
              ),
            ),
          );
        }
        return out;
      } catch (error) {
        if (kDebugMode) debugPrint('[AddonClient] community list: $error');
        return const <CommunityAddon>[];
      }
    });
  }

  void invalidate(ManagedAddon addon) {
    final base = AddonTransport.baseUrl(addon.manifestUrl);
    for (final prefix in const ['catalog:', 'meta:', 'stream:', 'subs:']) {
      _cache.invalidatePrefix('$prefix$base');
    }
  }

  void clearCache() => _cache.clear();
}
