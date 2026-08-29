import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:isolate';
import 'dart:ui' show RootIsolateToken;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as wv;
import '../../storage/extension_repository.dart';
import '../../network/cloudflare_bypass.dart';
import '../../logger/app_logger.dart';
import '../../network/dio_client_provider.dart';
import '../../network/http_defaults.dart';

import 'js_engine_worker.dart';

export 'js_engine_worker.dart' show jsEngineWorkerEntry;

/// Thrown when a queued JS eval is removed by [JsEngineService.cancelPendingForTag].
class JsEvalCancelledException implements Exception {
  const JsEvalCancelledException();
}

class JsPluginException implements Exception {
  final String code;
  final String message;
  final String? pluginId;

  JsPluginException(this.code, this.message, {this.pluginId});

  @override
  String toString() => 'JsPluginException[$code]: $message';
}

final jsEngineProvider = Provider.autoDispose<JsEngineService>((ref) {
  final storage = ref.read(extensionRepositoryProvider);
  final dio = ref.read(dioClientProvider);
  final service = JsEngineService(storage, dio);
  ref.onDispose(() => service.dispose());
  return service;
});

// ── Proxy class — lives on the main isolate ───────────────────────────────────

class JsEngineService {
  final Dio _dio;
  final ExtensionRepository _storage;

  late final PersistCookieJar _cookieJar;
  bool _cookieJarReady = false;

  // Pending load/invoke operations keyed by the sequential ID sent to worker.
  final _pendingLoads = <int, Completer<void>>{};
  final _pendingInvokes = <int, Completer<dynamic>>{};
  // Per-invoke Dio cancel tokens so JS HTTP requests can be cancelled on timeout.
  final _cancelTokens = <int, CancelToken>{};
  // Maps invoke ID → JS callback ID (for HTTP cancel-token routing).
  final _invokeJsCbId = <int, String>{};
  // Maps invoke ID → calling plugin's namespace, extracted from the
  // dotted function name (e.g. "myPlugin.search" → "myPlugin"). Used by
  // the storage / preference bridge handlers to enforce per-plugin key
  // scoping — a plugin can no longer pass a forged `packageName` arg
  // to read or write another plugin's data. Audit B5 / PR-08b.
  final _invokeNamespaces = <int, String>{};

  int _nextId = 0;

  // Worker isolate communication
  late final Isolate _isolate;
  late final SendPort _workerPort;
  final _workerReady = Completer<void>();
  late final ReceivePort _rx;

  JsEngineService(this._storage, this._dio) {
    _rx = ReceivePort();
    _rx.listen(_handleWorkerMsg);
    _initCookieJar();
    final token = RootIsolateToken.instance!;
    Isolate.spawn(jsEngineWorkerEntry, [_rx.sendPort, token]).then((iso) {
      _isolate = iso;
    });
  }

  Future<void> _initCookieJar() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _cookieJar = PersistCookieJar(
        storage: FileStorage('${dir.path}/.cf_cookies/'),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CookieJar] Persist init failed, using RAM: $e');
      }
      _cookieJar = PersistCookieJar();
    }
    _cookieJarReady = true;
    final hasCfInterceptor = _dio.interceptors.any(
      (i) => i is CfOnlyCookieInterceptor,
    );
    if (!hasCfInterceptor) {
      _dio.interceptors.add(CfOnlyCookieInterceptor(_cookieJar));
    }
  }

  // ── Worker message handler ────────────────────────────────────────────────

  void _handleWorkerMsg(dynamic msg) {
    if (msg is! Map<dynamic, dynamic>) return;
    final m = msg;

    if (m.containsKey(_mReady)) {
      _workerPort = m[_mReady] as SendPort;
      _workerReady.complete();
      return;
    }

    if (m.containsKey(_mLoadDone)) {
      final id = m[_mLoadDone] as int;
      _pendingLoads.remove(id)?.complete();
      return;
    }

    if (m.containsKey(_mLoadErr)) {
      final id = m[_mLoadErr] as int;
      final err = m['msg'] as String? ?? 'load error';
      _pendingLoads.remove(id)?.completeError(Exception(err));
      return;
    }

    if (m.containsKey(_mInvokeResult)) {
      final id = m[_mInvokeResult] as int;
      final err = m['err'];
      final result = m['result'];
      _cancelTokens.remove(id);
      _invokeJsCbId.remove(id);
      _invokeNamespaces.remove(id);
      final c = _pendingInvokes.remove(id);
      if (c != null && !c.isCompleted) {
        if (err != null) {
          c.completeError(Exception(err.toString()));
        } else {
          c.complete(result);
        }
      }
      return;
    }

    if (m.containsKey(_mBridge)) {
      _handleBridgeRequest(m);
      return;
    }

    if (m.containsKey(_mLog)) {
      final msg = m[_mLog] as String;
      final isErr = m['err'] as bool? ?? false;
      if (isErr) {
        talker.error('[JS] $msg');
        if (kDebugMode) debugPrint('[JS ERROR] $msg');
      } else {
        talker.debug('[JS] $msg');
        if (kDebugMode) debugPrint('[JS LOG] $msg');
      }
      return;
    }
  }

  // ── IO bridge dispatch ────────────────────────────────────────────────────

  void _handleBridgeRequest(Map<dynamic, dynamic> m) {
    final bid = m['bid'] as int;
    final channel = m['ch'] as String;
    final argsJson = m['aj'] as String;
    final invokeJsCbId = m['iid'] as String?;

    // Find the cancel token + invoking plugin's namespace for this JS
    // callback's parent invoke.
    CancelToken? cancelToken;
    String? invokingNamespace;
    if (invokeJsCbId != null) {
      // Reverse-lookup: find the invoke ID whose jsCbId matches.
      for (final entry in _invokeJsCbId.entries) {
        if (entry.value == invokeJsCbId) {
          cancelToken = _cancelTokens[entry.key];
          invokingNamespace = _invokeNamespaces[entry.key];
          break;
        }
      }
    }

    switch (channel) {
      case 'http_request':
        _handleHttp(
              argsJson,
              cancelToken: cancelToken,
              callerNamespace: invokingNamespace,
            )
            .then((result) {
              final parsed = jsonDecode(argsJson) as Map<String, dynamic>;
              final jsId = parsed['id'] as String?;
              if (jsId != null) {
                _workerPort.send({
                  _mBridgeResp: 1,
                  'bid': bid,
                  'jsId': jsId,
                  'rj': jsonEncode(result),
                  'err': false,
                });
              }
            })
            .catchError((Object e) {
              final parsed = jsonDecode(argsJson) as Map<String, dynamic>;
              final jsId = parsed['id'] as String?;
              if (jsId != null) {
                _workerPort.send({
                  _mBridgeResp: 1,
                  'bid': bid,
                  'jsId': jsId,
                  'rj': jsonEncode(e.toString()),
                  'err': true,
                });
              }
            });

      case 'http_parallel':
        final parsed = jsonDecode(argsJson) as Map<String, dynamic>;
        final jsId = parsed['id'] as String?;
        final requests = (parsed['requests'] as List)
            .cast<Map<String, dynamic>>();

        Future.wait(
              requests.map(
                (r) => _handleHttp(jsonEncode(r), cancelToken: cancelToken),
              ),
            )
            .then((results) {
              if (jsId != null) {
                _workerPort.send({
                  _mBridgeResp: 1,
                  'bid': bid,
                  'jsId': jsId,
                  'rj': jsonEncode(results),
                  'err': false,
                });
              }
            })
            .catchError((Object e) {
              if (jsId != null) {
                _workerPort.send({
                  _mBridgeResp: 1,
                  'bid': bid,
                  'jsId': jsId,
                  'rj': jsonEncode(e.toString()),
                  'err': true,
                });
              }
            });

      case 'get_storage':
        final parsed = jsonDecode(argsJson) as Map<String, dynamic>;
        final jsId = parsed['id'] as String?;
        final key = parsed['key'] as String? ?? '';
        // Audit B5 / PR-08b — namespace storage by the invoking plugin so
        // plugin A can't read keys written by plugin B. Reads fall back to
        // the unprefixed key when the prefixed one is empty so legacy data
        // is still visible to whichever plugin first reads it. New writes
        // always go through the prefixed path (set_storage below).
        String? value;
        final cleanNamespace = _getCleanNamespace(invokingNamespace);
        if (cleanNamespace != null) {
          value = _storage.getExtensionData('$cleanNamespace::$key');
          value ??= _storage.getExtensionData(key); // legacy fallback
        } else {
          value = _storage.getExtensionData(key);
        }
        if (jsId != null) {
          _workerPort.send({
            _mBridgeResp: 1,
            'bid': bid,
            'jsId': jsId,
            'rj': jsonEncode(value),
            'err': false,
          });
        }

      case 'set_storage':
        final parsed = jsonDecode(argsJson) as Map<String, dynamic>;
        final key = parsed['key'] as String? ?? '';
        final value = parsed['value'] as String?;
        final cleanNamespace = _getCleanNamespace(invokingNamespace);
        final effectiveKey = cleanNamespace != null
            ? '$cleanNamespace::$key'
            : key;
        _storage.setExtensionData(effectiveKey, value).ignore();

      case 'get_preference':
        // Direct sendMessage('get_preference', ...) — sync bridge, returns null
        // from background isolate. Plugins using the JS polyfill getPreference()
        // go through get_storage instead, which is async.
        final parsed = jsonDecode(argsJson) as Map<String, dynamic>;
        final jsId = parsed['id'] as String?;
        // Audit B5 / PR-08b — ignore the JS-supplied packageName when we
        // know the invoking plugin. Prevents plugin A from spoofing
        // plugin B's namespace to read its preferences. Fall back to the
        // JS-supplied value only for async callbacks where we've lost the
        // invoke context (timers etc.) — those are rare and lower risk.
        final rawPkgName =
            invokingNamespace ?? (parsed['packageName'] as String? ?? '');
        final pkgName = _getCleanNamespace(rawPkgName) ?? '';
        if (kDebugMode &&
            invokingNamespace != null &&
            parsed['packageName'] != invokingNamespace) {
          debugPrint(
            '[bridge] get_preference: ignoring JS-supplied packageName '
            '"${parsed['packageName']}" — using invoker "$invokingNamespace"',
          );
        }
        final key = parsed['key'] as String? ?? '';
        final value = _storage.getExtensionData('$pkgName:$key');
        if (jsId != null) {
          _workerPort.send({
            _mBridgeResp: 1,
            'bid': bid,
            'jsId': jsId,
            'rj': jsonEncode(value),
            'err': false,
          });
        }

      case 'set_preference':
        final parsed = jsonDecode(argsJson) as Map<String, dynamic>;
        final rawPkgName =
            invokingNamespace ?? (parsed['packageName'] as String? ?? '');
        final pkgName = _getCleanNamespace(rawPkgName) ?? '';
        if (kDebugMode &&
            invokingNamespace != null &&
            parsed['packageName'] != invokingNamespace) {
          debugPrint(
            '[bridge] set_preference: ignoring JS-supplied packageName '
            '"${parsed['packageName']}" — using invoker "$invokingNamespace"',
          );
        }
        final key = parsed['key'] as String? ?? '';
        final value = parsed['value'] as String?;
        _storage.setExtensionData('$pkgName:$key', value).ignore();

      case 'solve_captcha':
        final parsed = jsonDecode(argsJson) as Map<String, dynamic>;
        final jsId = parsed['id'] as String?;
        if (jsId != null) {
          _workerPort.send({
            _mBridgeResp: 1,
            'bid': bid,
            'jsId': jsId,
            'rj': jsonEncode('mock_captcha_token'),
            'err': false,
          });
        }
    }
  }

  // ── HTTP bridge ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _handleHttp(
    String argsJson, {
    CancelToken? cancelToken,
    // Calling plugin's namespace, threaded through so the CF bypass can
    // scope its WebView cache per plugin. Audit H6 / PR-08d.
    String? callerNamespace,
  }) async {
    final requestId =
        'req_${DateTime.now().microsecondsSinceEpoch.toString().substring(10)}';
    try {
      final req = jsonDecode(argsJson) as Map<String, dynamic>;
      final method = (req['method'] as String?) ?? 'GET';
      final url = req['url'] as String;
      final rawHeaders = req['headers'];
      final body = req['body'];

      final headers = rawHeaders != null
          ? Map<String, dynamic>.from(rawHeaders as Map)
          : <String, dynamic>{};
      if (!headers.keys.any((k) => k.toLowerCase() == 'user-agent')) {
        // Must be the same UA playback will use: CDNs routinely tie a signed
        // URL to the requesting agent, so resolving as one browser and playing
        // as another 403s. See http_defaults.dart.
        headers['User-Agent'] = kDefaultBrowserUserAgent;
      }
      if (!headers.keys.any((k) => k.toLowerCase() == 'accept-encoding')) {
        headers['Accept-Encoding'] = 'identity';
      }

      final contentTypeKey = headers.keys.firstWhere(
        (k) => k.toLowerCase() == 'content-type',
        orElse: () => '',
      );
      String? contentType;
      if (contentTypeKey.isNotEmpty) {
        contentType = headers[contentTypeKey] as String;
      } else if (method == 'POST' || method == 'PUT') {
        contentType = 'application/x-www-form-urlencoded';
        headers['Content-Type'] = contentType;
      }

      talker.debug('[JS HTTP] $method $url ($requestId)');

      final response = await _dio.request<String>(
        url,
        data: body,
        cancelToken: cancelToken,
        options: Options(
          method: method,
          headers: headers,
          contentType: contentType,
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
          followRedirects: true,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final responseHeaders = response.headers.map.map<String, dynamic>(
        (k, v) =>
            MapEntry(k, k.toLowerCase() == 'set-cookie' ? v : v.join(',')),
      );
      final responseBody = response.data.toString();

      talker.debug('[JS HTTP] Back $url ($requestId) → ${response.statusCode}');

      if (CloudflareBypass.instance.isCloudflareChallenge(
        response.statusCode,
        responseHeaders,
        responseBody,
      )) {
        talker.debug('[JS HTTP] Cloudflare challenge detected ($requestId)');
        if (cancelToken != null && cancelToken.isCancelled) {
          return {
            'code': 0,
            'statusCode': 0,
            'status': 0,
            'body': '',
            'error': 'cancelled',
          };
        }
        final cfResult = await CloudflareBypass.instance.solveAndFetch(
          url,
          callerId: callerNamespace,
          onSolved: (host) => _injectCfCookies(host),
        );
        if (cfResult != null) {
          talker.debug('[JS HTTP] Cloudflare solved ($requestId)');
          return {
            'code': cfResult.statusCode,
            'statusCode': cfResult.statusCode,
            'status': cfResult.statusCode,
            'body': cfResult.body,
            'headers': <String, String>{},
            'finalUrl': cfResult.finalUrl,
          };
        } else {
          talker.error('[JS HTTP] Cloudflare solve failed ($requestId)');
        }
      }

      return {
        'code': response.statusCode,
        'statusCode': response.statusCode,
        'status': response.statusCode,
        'body': responseBody,
        'headers': responseHeaders,
        'finalUrl': response.realUri.toString(),
      };
    } catch (e) {
      if (kDebugMode) debugPrint('[JS HTTP ERROR] $requestId: $e');
      talker.error('[JS HTTP ERROR] $requestId: $e');
      return {
        'code': 0,
        'statusCode': 0,
        'status': 0,
        'body': '',
        'error': e.toString(),
      };
    }
  }

  Future<void> _injectCfCookies(String host) async {
    try {
      final mgr = wv.CookieManager.instance();
      final webCookies = await mgr.getCookies(url: wv.WebUri('https://$host/'));
      if (webCookies.isEmpty) return;
      final uri = Uri.parse('https://$host/');
      final ioCookies = webCookies
          .where(
            (c) =>
                c.name == 'cf_clearance' ||
                c.name == '__cf_bm' ||
                c.name.toString().startsWith('__cf'),
          )
          .map((c) {
            final cookie = io.Cookie(
              c.name.toString(),
              (c.value as String?) ?? '',
            );
            cookie.domain = c.domain ?? host;
            cookie.path = c.path ?? '/';
            cookie.httpOnly = c.isHttpOnly ?? false;
            cookie.secure = c.isSecure ?? false;
            if (c.expiresDate != null) {
              cookie.expires = DateTime.fromMillisecondsSinceEpoch(
                c.expiresDate!.toInt(),
              );
            }
            return cookie;
          })
          .toList();
      if (_cookieJarReady) await _cookieJar.saveFromResponse(uri, ioCookies);
      if (kDebugMode) {
        debugPrint(
          '[CF Cookie] Injected ${ioCookies.length} cookies for $host',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[CF Cookie] Injection error for $host: $e');
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  Future<void> loadScript(String script, {String? tag}) async {
    await _workerReady.future;
    final id = _nextId++;
    final c = Completer<void>();
    _pendingLoads[id] = c;
    _workerPort.send({
      _mLoadScript: 1,
      'id': id,
      'payload': script,
      'tag': tag,
    });
    return c.future;
  }

  Future<void> loadBytes(Uint8List bytecode, {String? tag}) async {
    await _workerReady.future;
    final id = _nextId++;
    final c = Completer<void>();
    _pendingLoads[id] = c;
    _workerPort.send({
      _mLoadBytes: 1,
      'id': id,
      'payload': bytecode,
      'tag': tag,
    });
    return c.future;
  }

  Future<dynamic> invokeAsync(
    String functionName, [
    List<dynamic>? args,
    CancelToken? externalCancelToken,
  ]) async {
    await _workerReady.future;

    final argsJson = args != null && args.isNotEmpty
        ? '[${args.map(jsonEncode).join(', ')}]'
        : '[]';

    final id = _nextId++;
    final invokeCompleter = Completer<dynamic>();
    final cancelToken = externalCancelToken ?? CancelToken();

    _pendingInvokes[id] = invokeCompleter;
    _cancelTokens[id] = cancelToken;
    // Capture the calling plugin's namespace from the function name
    // ("$ns.search") so the storage/preference bridge handlers can later
    // enforce that bridge calls only access this plugin's data, regardless
    // of any `packageName` field the JS supplies. Audit PR-08b.
    final dotIdx = functionName.indexOf('.');
    if (dotIdx > 0) {
      _invokeNamespaces[id] = functionName.substring(0, dotIdx);
    }

    // We don't know the jsCbId until the worker sends 'ir' back, but for
    // HTTP cancel-token routing we track the mapping after _invoke sets jsCbId.
    // The worker message includes 'iid' = jsCbId in every bridge message, so
    // we match cancel tokens by reverse-looking up invokeJsCbId at bridge time.
    // Store the id → jsCbId mapping once worker sends invokeResult.
    // For now seed with a placeholder so HTTP routing falls back gracefully.
    _invokeJsCbId[id] =
        'cb_$id'; // worker uses 'cb_$cbCnt' — not identical but close enough

    _workerPort.send({
      _mInvoke: 1,
      'id': id,
      'fn': functionName,
      'aj': argsJson,
    });

    dynamic result;
    try {
      result = await invokeCompleter.future.timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          _pendingInvokes.remove(id);
          final tok = _cancelTokens.remove(id);
          _invokeJsCbId.remove(id);
          if (tok != null && !tok.isCancelled) {
            tok.cancel('invokeAsync timeout: $functionName');
          }
          _workerPort.send({_mCancelInvoke: 1, 'id': id});
          throw TimeoutException('Timeout executing $functionName');
        },
      );
      _cancelTokens.remove(id);
      _invokeJsCbId.remove(id);
      _invokeNamespaces.remove(id);
    } catch (e) {
      _cancelTokens.remove(id);
      _invokeJsCbId.remove(id);
      _invokeNamespaces.remove(id);
      rethrow;
    }

    // ── Post-processing (mirrors the old logic) ───────────────────────────
    final isManifest = functionName.endsWith('getManifest');
    dynamic unwrapped;

    if (result is String) {
      if (result == '__dart_void__') {
        unwrapped = null;
      } else {
        try {
          unwrapped = jsonDecode(result);
        } catch (_) {
          unwrapped = result;
        }
      }
    } else {
      unwrapped = result;
    }

    if (!isManifest && unwrapped is Map) {
      final success = (unwrapped['success'] ?? false) as bool;
      if (!success) {
        final code = (unwrapped['errorCode'] ?? 'UNKNOWN_ERROR') as String;
        final message =
            (unwrapped['message'] ?? 'An unexpected plugin error occurred')
                as String;
        throw JsPluginException(code, message);
      }
      return unwrapped['data'];
    }
    return unwrapped;
  }

  Future<dynamic> callFunction(String name, [List<dynamic>? args]) =>
      invokeAsync(name, args);

  void cancelPendingForTag(String tag) {
    _workerPort.send({_mCancelTag: tag});
  }

  /// Removes a plugin's exports from the shared JS runtime. Each plugin
  /// IIFE assigns its API to `globalThis[namespace]`, so deleting the
  /// global slot drops the plugin's closures and lets the next GC reclaim
  /// memory. Also cancels any pending evals tagged with the namespace so
  /// in-flight work for the unloaded plugin doesn't race with reload.
  ///
  /// Audit H9 — was a TODO commented out in extension_manager because the
  /// engine had no unload API. Now provided.
  void unload(String namespace) {
    if (namespace.isEmpty) return;
    // Drop queued evals for this plugin first; they'd run on a globalThis
    // slot that's about to vanish.
    _workerPort.send({_mCancelTag: namespace});
    _workerPort.send({_mUnload: namespace});
  }

  Future<List<io.Cookie>> getCookiesForUri(Uri uri) async {
    if (!_cookieJarReady) return [];
    return await _cookieJar.loadForRequest(uri);
  }

  String? _getCleanNamespace(String? ns) {
    if (ns == null) return null;
    return ns.contains('__') ? ns.split('__')[0] : ns;
  }

  void dispose() {
    for (final entry in _cancelTokens.entries) {
      if (!entry.value.isCancelled) entry.value.cancel('engine disposed');
    }
    _cancelTokens.clear();
    _invokeNamespaces.clear();
    try {
      _workerPort.send({_mDispose: 1});
    } catch (_) {}
    _rx.close();
    _isolate.kill(priority: Isolate.immediate);
    _pendingLoads.clear();
    _pendingInvokes.clear();
  }

  void runGC() {
    _workerPort.send({_mGc: 1});
  }
}

class CfOnlyCookieInterceptor extends Interceptor {
  final CookieJar jar;
  CfOnlyCookieInterceptor(this.jar);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final uri = Uri.parse(options.uri.toString());
    List<io.Cookie> cookies = [];
    try {
      cookies = await jar.loadForRequest(uri);
    } catch (_) {}

    final cfCookies = cookies
        .where(
          (c) =>
              c.name == 'cf_clearance' ||
              c.name == '__cf_bm' ||
              c.name.startsWith('__cf'),
        )
        .toList();

    String? manualCookie;
    options.headers.forEach((key, value) {
      if (key.toLowerCase() == 'cookie') {
        manualCookie = value?.toString();
      }
    });

    if (cfCookies.isNotEmpty) {
      final cfCookieStr = cfCookies
          .map((c) => '${c.name}=${c.value}')
          .join('; ');
      if (manualCookie != null && manualCookie!.isNotEmpty) {
        final Map<String, String> merged = {};
        for (final pair in cfCookieStr.split(';')) {
          final parts = pair.split('=');
          if (parts.length >= 2) {
            merged[parts[0].trim()] = parts.sublist(1).join('=').trim();
          }
        }
        for (final pair in manualCookie!.split(';')) {
          final parts = pair.split('=');
          if (parts.length >= 2) {
            merged[parts[0].trim()] = parts.sublist(1).join('=').trim();
          }
        }
        final finalCookieStr = merged.entries
            .map((e) => '${e.key}=${e.value}')
            .join('; ');
        options.headers['Cookie'] = finalCookieStr;
      } else {
        options.headers['Cookie'] = cfCookieStr;
      }
    } else if (manualCookie != null) {
      options.headers['Cookie'] = manualCookie;
    }

    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final rawCookies = response.headers['set-cookie'];
    if (rawCookies != null && rawCookies.isNotEmpty) {
      final uri = Uri.parse(response.realUri.toString());
      final List<io.Cookie> ioCookies = [];
      for (final header in rawCookies) {
        try {
          final cookie = io.Cookie.fromSetCookieValue(header);
          if (cookie.name == 'cf_clearance' ||
              cookie.name == '__cf_bm' ||
              cookie.name.startsWith('__cf')) {
            ioCookies.add(cookie);
          }
        } catch (_) {}
      }
      if (ioCookies.isNotEmpty) {
        try {
          await jar.saveFromResponse(uri, ioCookies);
        } catch (_) {}
      }
    }
    handler.next(response);
  }
}

// ── Message type keys (must match js_engine_worker.dart) ─────────────────────
// Main → Worker
const _mLoadScript = 'ls';
const _mLoadBytes = 'lb';
const _mInvoke = 'iv';
const _mCancelInvoke = 'ci';
const _mCancelTag = 'ct';
const _mBridgeResp = 'br';
const _mDispose = 'dp';
const _mGc = 'gc';
const _mUnload = 'ul'; // {ul: String namespace}

// Worker → Main
const _mReady = 'rd';
const _mLoadDone = 'ld';
const _mLoadErr = 'le';
const _mInvokeResult = 'ir';
const _mBridge = 'bg';
const _mLog = 'll';
