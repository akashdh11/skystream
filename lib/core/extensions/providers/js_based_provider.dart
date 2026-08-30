import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:dio/dio.dart';

import '../../domain/entity/multimedia_item.dart';
import '../base_provider.dart';
import '../engine/js_engine.dart';
import '../engine/js_bytecode_compiler.dart';
import '../models/extension_plugin.dart';
import '../../services/local_proxy_service.dart';
import '../../logger/app_logger.dart';

// Top-level function for compute() isolate
Map<String, List<MultimediaItem>> _parseHomeResults(dynamic result) {
  final map = <String, List<MultimediaItem>>{};
  if (result is Map) {
    result.forEach((key, value) {
      if (value is List) {
        map[key.toString()] = value
            .map(
              (e) => MultimediaItem.fromJson(
                Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
              ),
            )
            .toList();
      }
    });
  }
  return map;
}

// Top-level function for compute() isolate
List<MultimediaItem> _parseSearchResults(dynamic result) {
  if (result is List) {
    return result
        .map(
          (e) => MultimediaItem.fromJson(
            Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
          ),
        )
        .toList();
  }
  return [];
}

// ── Concurrency safety helpers (audit PR-07) ──────────────────────────────

/// Max items kept in parallel for plugin-returned URL fanout (audit M23).
/// A plugin that returns 100 stream URLs would otherwise launch 100
/// concurrent compute() + LocalProxyService calls; this caps the burst.
const int _kStreamFanoutConcurrency = 8;

/// Hard ceiling on per-call result count returned from a plugin (audit
/// M25). A malicious plugin returning a 1 M-entry list would otherwise
/// pump the whole thing across the isolate boundary to compute().
const int _kMaxResultListLength = 5000;

/// Hard ceiling on stream URLs a single loadStreams call may yield.
const int _kMaxStreamsPerCall = 200;

/// Processes [items] in chunks of [concurrency] in parallel, preserving
/// input order. Each chunk awaits before the next starts. Simpler than a
/// full Semaphore and good enough for our O(10–100) item bursts.
Future<List<R>> _processInChunks<T, R>(
  Iterable<T> items,
  int concurrency,
  Future<R> Function(T item) work,
) async {
  final list = items.toList(growable: false);
  final results = List<R?>.filled(list.length, null);
  for (var i = 0; i < list.length; i += concurrency) {
    final end = (i + concurrency).clamp(0, list.length);
    final chunk = <Future<void>>[];
    for (var j = i; j < end; j++) {
      final idx = j;
      chunk.add(work(list[idx]).then((r) => results[idx] = r));
    }
    await Future.wait(chunk);
  }
  return results.cast<R>();
}

class JsBasedProvider extends SkyStreamProvider {
  static const int _iifeWrapperVersion = 2;

  final JsEngineService _jsEngine;
  final String _scriptPath;
  String get scriptPath => _scriptPath;
  // Unique package identifier
  final String _packageName;
  @override
  String get packageName => _packageName;

  final String? _namespace;
  String? get namespace => _namespace; // Expose namespace
  final String? _forcedName;
  final String? _providerId;
  // Scopes JS getPreference/setPreference — sub-providers share parent's namespace
  final String _jsPackageName;

  Future<void>? _initFuture;
  final String? _customBaseUrl;

  // Per-plugin invocation lock — serializes calls into THIS plugin's exported
  // functions so concurrent invocations (e.g. search + getHome in parallel)
  // can't race on plugin-local closure state. The shared JS runtime is
  // single-threaded but async-yields between bridge calls; without this
  // lock, two `search()` calls could interleave at every `await fetch(...)`
  // point and clobber each other's local variables. Audit PR-07.
  Future<void>? _invokeLock;

  Future<T> _serializedInvoke<T>(Future<T> Function() body) async {
    // Chain after the previous in-flight call.
    while (_invokeLock != null) {
      try {
        await _invokeLock;
      } catch (_) {
        // Predecessor failed — that's their problem; we still want to run.
      }
    }
    final c = Completer<void>();
    _invokeLock = c.future;
    try {
      return await body();
    } finally {
      // Only release if we're still the holder; defensive against weird
      // race shapes during hot-reload.
      if (identical(_invokeLock, c.future)) _invokeLock = null;
      c.complete();
    }
  }

  // Optional shared script loader injected by ExtensionManager to deduplicate
  // file reads across sub-providers that share the same JS file.
  final Future<String?> Function()? _scriptLoader;

  JsBasedProvider(
    this._jsEngine,
    this._scriptPath, {
    required String packageName,
    String? jsPackageName,
    String? namespace,
    String? forcedName,
    Map<String, dynamic>? manifest,
    String? customBaseUrl,
    String? providerId,
    Future<String?> Function()? scriptLoader,
  }) : _packageName = packageName,
       _jsPackageName = jsPackageName ?? packageName,
       _namespace = namespace,
       _forcedName = forcedName,
       _customBaseUrl = customBaseUrl,
       _providerId = providerId,
       _scriptLoader = scriptLoader {
    // Populate manifest immediately so name/version/languages/supportedTypes
    // are available before lazy JS evaluation runs.
    if (manifest != null && manifest.isNotEmpty) {
      _manifest = Map<String, dynamic>.from(manifest);
      if (customBaseUrl != null && customBaseUrl.isNotEmpty) {
        _manifest['baseUrl'] = customBaseUrl;
      }
    }
  }

  Future<void> _ensureReady() {
    _initFuture ??= _init();
    return _initFuture!;
  }

  Future<void> get waitForInit => _ensureReady();

  @override
  void cancelInit() {
    _jsEngine.cancelPendingForTag(_packageName);
    // _init() detects JsEvalCancelledException and resets _initFuture itself.
  }

  Map<String, dynamic> _manifest = {};
  String? _error;

  // Per-sub-provider bytecode path. Only valid for file-based (non-asset) plugins.
  String? get _qbcPath {
    if (_scriptPath.startsWith('assets/')) return null;
    final dir = _scriptPath.substring(0, _scriptPath.lastIndexOf('/') + 1);
    final safeId = (_namespace ?? _packageName).replaceAll(
      RegExp(r'[^a-zA-Z0-9_]'),
      '_',
    );
    return '$dir${safeId}_v$_iifeWrapperVersion.qbc';
  }

  // Wraps the raw plugin source in a namespaced IIFE with manifest + storage API.
  String _buildIife(String rawScript) {
    if (_namespace == null) return rawScript;
    final manifestJson = jsonEncode(_manifest);
    final providerIdLine = _providerId != null
        ? "manifest.providerId = ${jsonEncode(_providerId)};"
        : "";
    return """
          (function() {
              const manifest = $manifestJson;
              $providerIdLine

              const getPreference = (key) => {
                  return sendMessage('get_preference', JSON.stringify({ packageName: '$_jsPackageName', key: key }));
              };

              const setPreference = (key, value) => {
                  return sendMessage('set_preference', JSON.stringify({ packageName: '$_jsPackageName', key: key, value: value }));
              };

              globalThis.getPreference = getPreference;
              globalThis.setPreference = setPreference;

              var exports = (function() {
                  $rawScript

                  return {
                      getHome: (typeof getHome !== 'undefined') ? getHome : (typeof globalThis.getHome !== 'undefined' ? globalThis.getHome : undefined),
                      search: (typeof search !== 'undefined') ? search : (typeof globalThis.search !== 'undefined' ? globalThis.search : undefined),
                      load: (typeof load !== 'undefined') ? load : (typeof globalThis.load !== 'undefined' ? globalThis.load : undefined),
                      loadStreams: (typeof loadStreams !== 'undefined') ? loadStreams : (typeof globalThis.loadStreams !== 'undefined' ? globalThis.loadStreams : undefined),
                      getProviders: (typeof getProviders !== 'undefined') ? getProviders : (typeof globalThis.getProviders !== 'undefined' ? globalThis.getProviders : undefined),
                      getSettings: (typeof getSettings !== 'undefined') ? getSettings : (typeof globalThis.getSettings !== 'undefined' ? globalThis.getSettings : undefined),
                  };
              })();
              globalThis['$_namespace'] = exports;

              if (globalThis.getHome) delete globalThis.getHome;
              if (globalThis.search) delete globalThis.search;
              if (globalThis.load) delete globalThis.load;
              if (globalThis.loadStreams) delete globalThis.loadStreams;
              if (globalThis.getProviders) delete globalThis.getProviders;
              if (globalThis.getSettings) delete globalThis.getSettings;
          })();
          """;
  }

  Future<void> _init() async {
    String? rawScript;
    try {
      if (_scriptLoader != null) {
        rawScript = await _scriptLoader();
      } else if (_scriptPath.startsWith('assets/')) {
        rawScript = await rootBundle.loadString(_scriptPath);
      } else {
        final file = File(_scriptPath);
        if (await file.exists()) rawScript = await file.readAsString();
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error reading JS script ($_scriptPath): $e");
      _error = "Read: $e";
    }

    if (rawScript == null) {
      _error = "Not found";
      return;
    }

    final script = _buildIife(rawScript);
    final qbc = _qbcPath;

    try {
      // Fast path: load pre-compiled bytecode when available and fresh.
      if (qbc != null && !await JsBytecodeCompiler.isStale(_scriptPath, qbc)) {
        final bytes = await File(qbc).readAsBytes();
        await _jsEngine.loadBytes(bytes, tag: _packageName);
        if (kDebugMode) {
          talker.debug("JsBasedProvider: Loaded bytecode for $_packageName");
        }
        return;
      }

      // Slow path: text eval, then compile bytecode in the background.
      await _jsEngine.loadScript(script, tag: _packageName);
      if (kDebugMode) {
        talker.debug("JsBasedProvider: Loaded script for $_packageName");
      }

      if (qbc != null) {
        // Fire-and-forget: compile bytecode for next launch.
        JsBytecodeCompiler.compile(script, qbc).ignore();
      }
    } on JsEvalCancelledException {
      // Search was cancelled before this IIFE ran. Reset so the next search
      // triggers a fresh _init() instead of replaying the cancelled future.
      _initFuture = null;
      _error = null;
      return;
    } catch (e) {
      _error = "Eval: $e";
      if (kDebugMode) {
        debugPrint(
          "JsBasedProvider: CRITICAL - Eval failed for $_packageName: $e",
        );
      }
    }
  }

  /// Called by ExtensionManager at install/update time to pre-compile bytecode.
  /// No-ops if bytecode is already fresh. Returns true if bytecode was written.
  Future<bool> precompile() async {
    final qbc = _qbcPath;
    if (qbc == null) return false;
    if (!await JsBytecodeCompiler.isStale(_scriptPath, qbc)) return false;
    String? rawScript;
    try {
      if (_scriptLoader != null) {
        rawScript = await _scriptLoader();
      } else {
        final file = File(_scriptPath);
        if (await file.exists()) rawScript = await file.readAsString();
      }
    } catch (_) {
      return false;
    }
    if (rawScript == null) return false;
    return JsBytecodeCompiler.compile(_buildIife(rawScript), qbc);
  }

  Future<void> deleteBytecode() async {
    final qbc = _qbcPath;
    if (qbc == null) return;
    try {
      final file = File(qbc);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  String _fn(String name) => _namespace != null ? '$_namespace.$name' : name;

  @override
  String get name {
    if (_forcedName != null) return _forcedName;
    if (_manifest['name'] != null) return _manifest['name'] as String;
    if (_error != null) return "Err: $_error";
    return "JS Extension";
  }

  // ... (rest of simple getters)
  @override
  String get mainUrl =>
      _customBaseUrl ?? (_manifest['baseUrl'] as String?) ?? "";

  @override
  String get version => (_manifest['version'] ?? 0).toString();

  @override
  List<String> get languages => _readManifestStringList(
    ['languages', 'language', 'lang'],
    fallback: const ['en'],
  );

  @override
  Set<ProviderType> get supportedTypes {
    final categories = _readManifestStringList([
      'categories',
      'tvTypes',
      'types',
    ]);
    if (categories.isEmpty) {
      return {ProviderType.movie};
    }

    final mapped = categories.map(_mapProviderType).toSet();
    if (mapped.isEmpty) {
      return {ProviderType.movie};
    }
    return mapped;
  }

  List<String> _readManifestStringList(
    List<String> keys, {
    List<String> fallback = const [],
  }) {
    for (final key in keys) {
      final value = _manifest[key];
      if (value is List) {
        final parsed = value.map((e) => e.toString()).toList();
        if (parsed.isNotEmpty) {
          return parsed;
        }
      }
      if (value is String && value.trim().isNotEmpty) {
        return [value];
      }
    }
    return fallback;
  }

  ProviderType _mapProviderType(String raw) {
    switch (raw.toLowerCase()) {
      case 'movie':
      case 'movies':
        return ProviderType.movie;
      case 'tv':
      case 'series':
      case 'tvseries':
      case 'tvshow':
      case 'tvshows':
        return ProviderType.series;
      case 'anime':
        return ProviderType.anime;
      case 'livetv':
      case 'iptv':
      case 'livestream':
        return ProviderType.livestream;
      default:
        return ProviderType.other;
    }
  }

  /// Calls the JS `getProviders()` export to fetch the live provider list.
  /// `invokeAsync` unwraps `{success:true, data:[...]}` automatically, so
  /// `result` is the raw List. Returns an empty list if not exported or on error.
  Future<List<PluginSubProvider>> getProviders() async {
    await _ensureReady();
    if (_error != null) return [];
    return _serializedInvoke(() async {
      try {
        final result = await _jsEngine.invokeAsync(_fn('getProviders'));
        if (result is List) {
          return result
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (e) => PluginSubProvider.fromJson(Map<String, dynamic>.from(e)),
              )
              .where((p) => p.id.isNotEmpty)
              .toList();
        }
        if (kDebugMode) {
          debugPrint(
            'JsBasedProvider: getProviders returned unexpected type: ${result.runtimeType}',
          );
        }
        return [];
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'JsBasedProvider: getProviders error for $_packageName: $e',
          );
        }
        return [];
      }
    });
  }

  /// Calls the optional JS `getSettings()` export.
  ///
  /// The plugin may return either a list directly or
  /// `{ settings: [...] }`. Invalid definitions are ignored.
  Future<List<PluginSettingDefinition>> getSettings() async {
    await _ensureReady();
    if (_error != null) return const [];

    return _serializedInvoke(() async {
      try {
        final result = await _jsEngine.invokeAsync(_fn('getSettings'));
        final dynamic rawSettings = result is Map && result['settings'] is List
            ? result['settings']
            : result;

        if (rawSettings is! List) return const [];

        return rawSettings
            .take(100)
            .whereType<Map<dynamic, dynamic>>()
            .map(
              (raw) => PluginSettingDefinition.fromJson(
                Map<String, dynamic>.from(raw),
              ),
            )
            .where((setting) => setting.key.isNotEmpty)
            .toList(growable: false);
      } catch (error) {
        if (kDebugMode) {
          debugPrint(
            'JsBasedProvider: getSettings unavailable for '
            '$_packageName: $error',
          );
        }
        return const [];
      }
    });
  }

  @override
  Future<Map<String, List<MultimediaItem>>> getHome() async {
    await _ensureReady();
    if (_error != null) throw JsPluginException("INIT_ERROR", _error!);
    return _serializedInvoke(() async {
      try {
        final result = await _jsEngine.invokeAsync(_fn('getHome'));
        if (result is Map) {
          // Bound the per-section list size before crossing the isolate
          // boundary. Audit M25 — a plugin returning 100k items per section
          // would otherwise force compute() to serialise all of it.
          final bounded = <dynamic, dynamic>{};
          for (final entry in result.entries) {
            final v = entry.value;
            if (v is List && v.length > _kMaxResultListLength) {
              bounded[entry.key] = v.sublist(0, _kMaxResultListLength);
            } else {
              bounded[entry.key] = v;
            }
          }
          final map = await compute(_parseHomeResults, bounded);
          return map;
        }
        throw Exception("Extension returned invalid home data (not a map).");
      } on JsPluginException catch (e) {
        if (kDebugMode) debugPrint("JsPluginException in getHome: $e");
        talker.error("JsPluginException in getHome: $e");
        rethrow;
      } catch (e) {
        if (kDebugMode) debugPrint("Error in getHome: $e");
        talker.error("Error in getHome: $e");
        throw Exception("Failed to load home content: $e");
      }
    });
  }

  @override
  Future<List<MultimediaItem>> search(
    String query, {
    CancelToken? cancelToken,
  }) async {
    await _ensureReady();
    if (_error != null) throw JsPluginException("INIT_ERROR", _error!);
    return _serializedInvoke(() async {
      try {
        final result = await _jsEngine.invokeAsync(_fn('search'), [
          query,
        ], cancelToken);
        if (result is List) {
          // Cap before compute() so a malicious plugin can't force the
          // isolate boundary to serialise an unbounded payload. Audit M25.
          final bounded = result.length > _kMaxResultListLength
              ? result.sublist(0, _kMaxResultListLength)
              : result;
          return await compute(_parseSearchResults, bounded);
        }
        return <MultimediaItem>[];
      } on JsPluginException catch (e) {
        if (kDebugMode) debugPrint("JsPluginException in search: $e");
        talker.error("JsPluginException in search: $e");
        rethrow;
      } catch (e) {
        if (kDebugMode) debugPrint("Error in search: $e");
        talker.error("Error in search: $e");
        return <MultimediaItem>[];
      }
    });
  }

  @override
  Future<MultimediaItem> getDetails(String url) async {
    await _ensureReady();
    if (_error != null) throw JsPluginException("INIT_ERROR", _error!);
    try {
      final result = await _jsEngine.invokeAsync(_fn('load'), [url]);
      if (result is Map) {
        final map = Map<String, dynamic>.from(result);
        if (map['url'] == null || map['url'].toString().isEmpty) {
          map['url'] = url;
        }
        return MultimediaItem.fromJson(map);
      }
      throw Exception("Extension returned invalid detail data.");
    } on JsPluginException catch (e) {
      if (kDebugMode) debugPrint("JsPluginException in getDetails: $e");
      talker.error("JsPluginException in getDetails: $e");
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint("Error in getDetails: $e");
      talker.error("Error in getDetails: $e");
      return MultimediaItem(title: "Error: $e", url: url, posterUrl: "");
    }
  }

  @override
  Future<List<StreamResult>> loadStreams(String url) async {
    await _ensureReady();
    if (_error != null) throw JsPluginException("INIT_ERROR", _error!);
    await LocalProxyService.instance.startServer();

    return _serializedInvoke(() async {
      try {
        final result = await _jsEngine.invokeAsync(_fn('loadStreams'), [url]);
        if (result is List) {
          // Cap the per-call result list. Audit M25 — a misbehaving plugin
          // could otherwise stream tens of thousands of entries through the
          // fanout below.
          final bounded = result.length > _kMaxStreamsPerCall
              ? result.sublist(0, _kMaxStreamsPerCall)
              : result;
          if (kDebugMode && result.length > _kMaxStreamsPerCall) {
            debugPrint(
              "[$_packageName] loadStreams returned ${result.length} entries — "
              "capping to $_kMaxStreamsPerCall (audit M25).",
            );
          }
          // Process in bounded-concurrency chunks. Audit M23 — was
          // unbounded Future.wait, allowing N parallel compute() spawns +
          // proxy fetches for an N-entry plugin response.
          return await _processInChunks(bounded, _kStreamFanoutConcurrency, (
            e,
          ) async {
            final map = Map<String, dynamic>.from(e as Map);
            String finalUrl = map['url'] as String;

            // MAGIC M3U8 HANDLING
            if (finalUrl.startsWith("magic_m3u8:")) {
              try {
                final base64Content = finalUrl.substring("magic_m3u8:".length);
                final m3u8Content = await compute(
                  _processMagicM3u8,
                  base64Content,
                );
                finalUrl = LocalProxyService.instance.serveM3u8(m3u8Content);
              } catch (err) {
                if (kDebugMode) debugPrint("Magic M3U8 Error: $err");
              }
            }
            // DIRECT PROXY URL HANDLING
            // If the URL starts with MAGIC_PROXY_v1/v2, it means we need to use a local proxy
            // to inject necessary headers into HLS segments.
            else if (finalUrl.startsWith("MAGIC_PROXY_v1") ||
                finalUrl.startsWith("MAGIC_PROXY:")) {
              try {
                final bool isV1 = finalUrl.startsWith("MAGIC_PROXY_v1");
                final b64Url = finalUrl.substring(
                  isV1 ? "MAGIC_PROXY_v1".length : "MAGIC_PROXY:".length,
                );
                final realUrlBytes = base64Decode(b64Url);
                final realUrl = utf8.decode(realUrlBytes);

                Map<String, String>? sticky = map['headers'] != null
                    ? Map<String, String>.from(map['headers'] as Map)
                    : null;

                if (mainUrl.isNotEmpty) {
                  try {
                    final baseUri = Uri.parse(mainUrl);
                    final jarCookies = await _jsEngine.getCookiesForUri(
                      baseUri,
                    );
                    if (jarCookies.isNotEmpty) {
                      final cookieHeader = jarCookies
                          .map((c) => '${c.name}=${c.value}')
                          .join('; ');
                      sticky ??= <String, String>{};
                      String? existingKey;
                      sticky.forEach((k, v) {
                        if (k.toLowerCase() == 'cookie') existingKey = k;
                      });
                      final existingCookie = existingKey != null
                          ? sticky[existingKey]
                          : null;
                      if (existingCookie != null && existingCookie.isNotEmpty) {
                        final Map<String, String> merged = {};
                        for (final pair in existingCookie.split(';')) {
                          final parts = pair.split('=');
                          if (parts.length >= 2) {
                            merged[parts[0].trim()] = parts
                                .sublist(1)
                                .join('=')
                                .trim();
                          }
                        }
                        for (final c in jarCookies) {
                          merged[c.name] = c.value;
                        }
                        sticky[existingKey!] = merged.entries
                            .map((e) => '${e.key}=${e.value}')
                            .join('; ');
                      } else {
                        sticky['Cookie'] = cookieHeader;
                      }
                    }
                  } catch (e) {
                    if (kDebugMode) {
                      debugPrint(
                        "Failed to copy cookies from JS engine jar to proxy headers: $e",
                      );
                    }
                  }
                }

                finalUrl = LocalProxyService.instance.getProxyUrl(
                  realUrl,
                  headers: sticky,
                );
              } catch (e) {
                if (kDebugMode) {
                  debugPrint("Error decoding MAGIC_PROXY_v1 url: $e");
                }
              }
            } else if (finalUrl.startsWith("MAGIC_PROXY_v2")) {
              try {
                final b64Json = finalUrl.substring("MAGIC_PROXY_v2".length);
                final jsonBytes = base64Decode(b64Json);
                final decodedJson = utf8.decode(jsonBytes);
                final Map<String, dynamic> config =
                    jsonDecode(decodedJson) as Map<String, dynamic>;

                final String realUrl = config['url'] as String;
                Map<String, String>? sticky = config['headers'] != null
                    ? Map<String, String>.from(config['headers'] as Map)
                    : (map['headers'] != null
                          ? Map<String, String>.from(map['headers'] as Map)
                          : null);

                if (mainUrl.isNotEmpty) {
                  try {
                    final baseUri = Uri.parse(mainUrl);
                    final jarCookies = await _jsEngine.getCookiesForUri(
                      baseUri,
                    );
                    if (jarCookies.isNotEmpty) {
                      final cookieHeader = jarCookies
                          .map((c) => '${c.name}=${c.value}')
                          .join('; ');
                      sticky ??= <String, String>{};
                      String? existingKey;
                      sticky.forEach((k, v) {
                        if (k.toLowerCase() == 'cookie') existingKey = k;
                      });
                      final existingCookie = existingKey != null
                          ? sticky[existingKey]
                          : null;
                      if (existingCookie != null && existingCookie.isNotEmpty) {
                        final Map<String, String> merged = {};
                        for (final pair in existingCookie.split(';')) {
                          final parts = pair.split('=');
                          if (parts.length >= 2) {
                            merged[parts[0].trim()] = parts
                                .sublist(1)
                                .join('=')
                                .trim();
                          }
                        }
                        for (final c in jarCookies) {
                          merged[c.name] = c.value;
                        }
                        sticky[existingKey!] = merged.entries
                            .map((e) => '${e.key}=${e.value}')
                            .join('; ');
                      } else {
                        sticky['Cookie'] = cookieHeader;
                      }
                    }
                  } catch (e) {
                    if (kDebugMode) {
                      debugPrint(
                        "Failed to copy cookies from JS engine jar to proxy headers: $e",
                      );
                    }
                  }
                }

                ProxyOptions? options;
                if (config['options'] != null) {
                  options = ProxyOptions.fromJson(
                    config['options'] as Map<String, dynamic>,
                  );
                }

                finalUrl = LocalProxyService.instance.getProxyUrl(
                  realUrl,
                  headers: sticky,
                  options: options,
                );
              } catch (e) {
                if (kDebugMode) {
                  debugPrint("Error decoding MAGIC_PROXY_v2 url: $e");
                }
              }
            }

            return StreamResult(
              url: finalUrl,
              source: (map['source'] as String?) ?? "Auto",
              headers: map['headers'] != null
                  ? Map<String, String>.from(map['headers'] as Map)
                  : null,
              subtitles: map['subtitles'] != null
                  ? (map['subtitles'] as List)
                        .map(
                          (s) => SubtitleFile.fromJson(
                            Map<String, dynamic>.from(s as Map),
                          ),
                        )
                        .toList()
                  : null,
              drmKid: map['drmKid'] as String?,
              drmKey: map['drmKey'] as String?,
              licenseUrl: map['licenseUrl'] as String?,
            );
          });
        }
        return [];
      } on JsPluginException catch (e) {
        if (kDebugMode) debugPrint("JsPluginException in loadStreams: $e");
        talker.error("JsPluginException in loadStreams: $e");
        rethrow;
      } catch (e) {
        if (kDebugMode) debugPrint("Error in loadStreams: $e");
        talker.error("Error in loadStreams: $e");
        return <StreamResult>[];
      }
    });
  }
}

// Global top-level function for compute() compatibility
String _processMagicM3u8(String base64Content) {
  final bytes = base64.decode(base64Content);
  final m3u8Content = utf8.decode(bytes);

  // Compatibility: Replace MAGIC_PROXY_v1 with real local proxy URLs
  // Note: We can't easily access LocalProxyService from here without passing it or its base URL,
  // but we can at least do the heavy regex work or return the clean string.
  // Actually, LocalProxyService is a singleton, so if it's initialized, it might work,
  // but it's better to keep Isolates pure.
  // For now, we perform the decoding and let the main thread handle the proxy mapping if needed,
  // or use the fact that it's a string replacement.

  return m3u8Content;
}
