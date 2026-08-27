import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_js/flutter_js.dart';

import 'nuvio_crypto.dart';
import 'nuvio_dom.dart';
import 'nuvio_polyfill.dart';

/// Everything needed to run one scraper, in a shape that can be sent to
/// another isolate (plain values only).
class NuvioEngineRequest {
  final String code;
  final String scraperId;
  final String scraperName;
  final String tmdbId;
  final String mediaType;
  final int? season;
  final int? episode;
  final Map<String, dynamic> settings;
  final String tmdbKey;
  final int timeoutMs;

  /// `streams` runs `getStreams(...)`, `settings` runs `onSettings()`.
  final String mode;

  const NuvioEngineRequest({
    required this.code,
    required this.scraperId,
    required this.scraperName,
    this.tmdbId = '',
    this.mediaType = 'movie',
    this.season,
    this.episode,
    this.settings = const {},
    this.tmdbKey = '',
    this.timeoutMs = 60000,
    this.mode = 'streams',
  });

  Map<String, dynamic> toMap() => {
    'code': code,
    'scraperId': scraperId,
    'scraperName': scraperName,
    'tmdbId': tmdbId,
    'mediaType': mediaType,
    'season': season,
    'episode': episode,
    'settings': settings,
    'tmdbKey': tmdbKey,
    'timeoutMs': timeoutMs,
    'mode': mode,
  };

  static NuvioEngineRequest fromMap(Map<dynamic, dynamic> map) =>
      NuvioEngineRequest(
        code: map['code']?.toString() ?? '',
        scraperId: map['scraperId']?.toString() ?? '',
        scraperName: map['scraperName']?.toString() ?? '',
        tmdbId: map['tmdbId']?.toString() ?? '',
        mediaType: map['mediaType']?.toString() ?? 'movie',
        season: (map['season'] as num?)?.toInt(),
        episode: (map['episode'] as num?)?.toInt(),
        settings: map['settings'] is Map
            ? Map<String, dynamic>.from(map['settings'] as Map)
            : const {},
        tmdbKey: map['tmdbKey']?.toString() ?? '',
        timeoutMs: (map['timeoutMs'] as num?)?.toInt() ?? 60000,
        mode: map['mode']?.toString() ?? 'streams',
      );
}

/// Runs one Nuvio plugin on QuickJS and returns the raw JSON document the
/// plugin produced (`{"streams":[…]}`, `{"layout":[…]}` or `{"error":"…"}`).
///
/// Deliberately free of Dio, Riverpod and anything that needs the root
/// isolate: the same code runs on the UI isolate and inside the worker
/// isolates of [NuvioIsolatePool]. HTTP goes through `dart:io`'s HttpClient
/// with a per-run cookie jar, which also isolates each scraper's session.
class NuvioEngine {
  static const int maxResponseChars = 8 * 1024 * 1024;
  static const String defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  /// Executes [request] and returns the JSON document produced by the plugin.
  static Future<String> execute(
    NuvioEngineRequest request, {
    void Function(String line)? onLog,
  }) async {
    final runtime = getJavascriptRuntime(
      xhr: false,
      extraArgs: {
        'stackSize': 4 * 1024 * 1024,
        // Several of these can be alive at once; 96 MB is far more than any
        // real bundle needs and keeps well clear of the per-process limit.
        'memoryLimit': 96 * 1024 * 1024,
      },
    );

    final completer = Completer<String>();
    final dom = NuvioDom();
    final http = NuvioEngineHttp();
    Timer? pump;
    // A response landing after the run finished must never touch a disposed
    // QuickJS context: that is a native use-after-free, not an exception.
    var disposed = false;

    void evalSafe(String script) {
      if (disposed) return;
      try {
        runtime.evaluate(script);
      } catch (error) {
        if (kDebugMode) debugPrint('[Nuvio] eval failed: $error');
      }
    }

    Map<String, dynamic> asMap(dynamic args) => args is Map
        ? Map<String, dynamic>.from(args)
        : jsonDecode(args.toString()) as Map<String, dynamic>;

    List<String> asIds(dynamic raw) => <String>[
      if (raw is List)
        for (final id in raw) id.toString(),
    ];

    try {
      runtime.onMessage('nuvio_result', (dynamic args) {
        if (!completer.isCompleted) {
          completer.complete(args is String ? args : jsonEncode(args));
        }
        return null;
      });

      runtime.onMessage('nuvio_log', (dynamic args) {
        final line = args is String ? args : jsonEncode(args);
        if (onLog != null) {
          onLog(line);
        } else if (kDebugMode) {
          debugPrint('[Nuvio:${request.scraperName}] $line');
        }
        return null;
      });

      runtime.onMessage(
        'nuvio_crypto',
        (dynamic args) => NuvioCrypto.handle(asMap(args)),
      );

      runtime.onMessage(
        'nuvio_dom_load',
        (dynamic args) => dom.load(asMap(args)['html']?.toString() ?? ''),
      );

      runtime.onMessage('nuvio_dom_query', (dynamic args) {
        final data = asMap(args);
        return jsonEncode(
          dom.query(
            data['doc']?.toString() ?? '',
            data['context']?.toString(),
            data['selector']?.toString() ?? '',
          ),
        );
      });

      runtime.onMessage('nuvio_dom_filter', (dynamic args) {
        final data = asMap(args);
        return jsonEncode(
          dom.filter(
            data['doc']?.toString() ?? '',
            asIds(data['nodes']),
            data['selector']?.toString() ?? '',
          ),
        );
      });

      runtime.onMessage('nuvio_dom_relation', (dynamic args) {
        final data = asMap(args);
        return jsonEncode(
          dom.relation(
            data['doc']?.toString() ?? '',
            asIds(data['nodes']),
            data['kind']?.toString() ?? '',
            data['selector']?.toString(),
          ),
        );
      });

      runtime.onMessage('nuvio_dom_describe', (dynamic args) {
        final data = asMap(args);
        return dom.describeBatch(
          data['doc']?.toString() ?? '',
          asIds(data['nodes']),
        );
      });

      runtime.onMessage('nuvio_dom_text', (dynamic args) {
        final data = asMap(args);
        return dom.textOf(data['doc']?.toString() ?? '', asIds(data['nodes']));
      });

      runtime.onMessage('nuvio_dom_html', (dynamic args) {
        final data = asMap(args);
        return dom.html(
          data['doc']?.toString() ?? '',
          data['node']?.toString() ?? '',
        );
      });

      runtime.onMessage('nuvio_dom_attr', (dynamic args) {
        final data = asMap(args);
        return dom.attr(
              data['doc']?.toString() ?? '',
              data['node']?.toString() ?? '',
              data['name']?.toString() ?? '',
            ) ??
            '';
      });

      runtime.onMessage('nuvio_fetch', (dynamic args) {
        final data = asMap(args);
        final id = data['id'];
        if (id == null) return null;
        unawaited(
          http.fetch(data).then((payload) {
            if (disposed) return;
            final failure = payload[NuvioEngineHttp.errorKey];
            if (failure != null) {
              evalSafe(
                'globalThis.__nuvio_settle(${jsonEncode(id.toString())}, null, '
                '${jsonEncode(failure.toString())})',
              );
            } else {
              evalSafe(
                'globalThis.__nuvio_settle(${jsonEncode(id.toString())}, '
                '${jsonEncode(payload)}, null)',
              );
            }
          }),
        );
        return null;
      });

      // Promise jobs and timers only advance when QuickJS is pumped. Jobs are
      // drained often; timers are checked every ~32 ms, which is plenty for
      // the retry/rate-limit sleeps scrapers use.
      var tickCounter = 0;
      pump = Timer.periodic(const Duration(milliseconds: 8), (_) {
        if (disposed) return;
        try {
          runtime.executePendingJob();
          if (++tickCounter % 4 == 0) {
            runtime.evaluate('__nuvio_tick && __nuvio_tick();');
          }
        } catch (_) {
          // A scraper throwing inside a microtask is its own problem.
        }
      });

      runtime.evaluate(
        buildNuvioPolyfill(
          scraperIdJson: jsonEncode(request.scraperId),
          settingsJson: jsonEncode(request.settings),
          tmdbKeyJson: jsonEncode(request.tmdbKey),
        ),
      );
      runtime.evaluate(wrapScraper(request.code));
      runtime.evaluate(
        request.mode == 'settings' ? settingsCall : _streamsCall(request),
      );

      return await completer.future.timeout(
        Duration(milliseconds: request.timeoutMs),
        onTimeout: () => jsonEncode({
          'error': 'Timed out after ${request.timeoutMs ~/ 1000}s',
        }),
      );
    } finally {
      pump?.cancel();
      disposed = true;
      http.close();
      dom.clear();
      try {
        runtime.dispose();
      } catch (_) {
        // Disposal races with in-flight jobs on some platforms; harmless.
      }
    }
  }

  /// Nuvio wraps every scraper in a CommonJS shell before calling into it.
  static String wrapScraper(String code) =>
      'var module = { exports: {} };\n'
      'var exports = module.exports;\n'
      '(function() {\n$code\n})();';

  static String _streamsCall(NuvioEngineRequest request) {
    final season = request.season?.toString() ?? 'undefined';
    final episode = request.episode?.toString() ?? 'undefined';
    return '''
      (async function () {
        try {
          var getStreams = (module.exports && module.exports.getStreams) ||
              globalThis.getStreams;
          if (!getStreams) {
            __nuvio_result(JSON.stringify({ error: 'getStreams not found' }));
            return;
          }
          var out = await getStreams(${jsonEncode(request.tmdbId)}, ${jsonEncode(request.mediaType)}, $season, $episode);
          __nuvio_result(JSON.stringify({ streams: out || [] }));
        } catch (e) {
          __nuvio_result(JSON.stringify({
            error: (e && e.message) ? e.message : String(e),
          }));
        }
      })();
    ''';
  }

  static const String settingsCall = '''
    (async function () {
      try {
        var onSettings = (module.exports && module.exports.onSettings) ||
            globalThis.onSettings;
        if (typeof onSettings !== 'function') {
          __nuvio_result(JSON.stringify({ layout: [] }));
          return;
        }
        var layout = await onSettings();
        __nuvio_result(JSON.stringify({ layout: layout || [] }));
      } catch (e) {
        __nuvio_result(JSON.stringify({
          error: (e && e.message) ? e.message : String(e),
        }));
      }
    })();
  ''';
}

/// The HTTP side of the plugin environment.
///
/// `dart:io` instead of Dio so it runs in a worker isolate, with cookies kept
/// per scraper run (several providers hand out a session cookie on the first
/// request and expect it back on the next one).
@visibleForTesting
class NuvioEngineHttp {
  NuvioEngineHttp();

  /// Key used to report a failure inside the payload map.
  static const String errorKey = '__nuvioError';

  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20)
    ..idleTimeout = const Duration(seconds: 15)
    ..autoUncompress = true
    ..badCertificateCallback = (_, _, _) => true;

  final Map<String, Map<String, String>> _cookies = {};
  var _closed = false;

  void close() {
    if (_closed) return;
    _closed = true;
    try {
      _client.close(force: true);
    } catch (_) {
      // Already gone.
    }
  }

  String cookieHeaderFor(Uri uri) {
    final jar = _cookies[uri.host];
    if (jar == null || jar.isEmpty) return '';
    return jar.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  void _storeCookies(Uri uri, HttpClientResponse response) {
    for (final cookie in response.cookies) {
      if (cookie.name.isEmpty) continue;
      (_cookies[uri.host] ??= {})[cookie.name] = cookie.value;
    }
  }

  /// Performs one plugin request. Never throws: a failure comes back as
  /// `{errorKey: message}` so the JS side can reject its promise.
  Future<Map<String, dynamic>> fetch(Map<String, dynamic> data) async {
    final rawUrl = data['url']?.toString() ?? '';
    final method = (data['method']?.toString() ?? 'GET').toUpperCase();
    final body = data['body']?.toString();
    final follow = data['follow'] != false;
    final headers = <String, String>{};
    final rawHeaders = data['headers'];
    if (rawHeaders is Map) {
      rawHeaders.forEach((key, value) {
        if (key is String && value != null) headers[key] = value.toString();
      });
    }

    Future<Map<String, dynamic>> doFetch({bool persistent = true}) async {
      var uri = Uri.parse(rawUrl);
      var redirects = 0;
      while (true) {
        if (_closed) return {errorKey: 'client closed'};
        final request = await _client.openUrl(method, uri);
        request.followRedirects = false;
        request.persistentConnection = persistent;
        if (!headers.keys.any((k) => k.toLowerCase() == 'user-agent')) {
          request.headers.set('user-agent', NuvioEngine.defaultUserAgent);
        }
        if (!headers.keys.any((k) => k.toLowerCase() == 'accept')) {
          request.headers.set('accept', '*/*');
        }
        headers.forEach((key, value) {
          try {
            request.headers.set(key, value);
          } catch (_) {
            // Some header names are rejected by dart:io; skip them.
          }
        });
        final cookieHeader = cookieHeaderFor(uri);
        if (cookieHeader.isNotEmpty &&
            !headers.keys.any((k) => k.toLowerCase() == 'cookie')) {
          request.headers.set('cookie', cookieHeader);
        }
        if (body != null && body.isNotEmpty && method != 'GET') {
          request.add(utf8.encode(body));
        }

        final response = await request.close().timeout(
          const Duration(seconds: 30),
        );
        _storeCookies(uri, response);

        final location = response.headers.value('location');
        final isRedirect =
            response.statusCode >= 300 &&
            response.statusCode < 400 &&
            location != null;
        if (isRedirect && follow && redirects < 5) {
          redirects++;
          unawaited(response.drain<void>().catchError((_) {}));
          uri = uri.resolve(location);
          continue;
        }

        var text = '';
        try {
          text = await response
              .transform(const Utf8Decoder(allowMalformed: true))
              .join()
              .timeout(const Duration(seconds: 30));
        } catch (_) {
          text = '';
        }
        if (text.length > NuvioEngine.maxResponseChars) {
          text = text.substring(0, NuvioEngine.maxResponseChars);
        }

        final responseHeaders = <String, String>{};
        response.headers.forEach((name, values) {
          if (values.isNotEmpty) {
            responseHeaders[name.toLowerCase()] = values.first;
          }
        });

        return {
          'ok': response.statusCode >= 200 && response.statusCode < 300,
          'status': response.statusCode,
          'statusText': response.reasonPhrase,
          'url': uri.toString(),
          'redirected': redirects > 0,
          'headers': responseHeaders,
          'body': text,
        };
      }
    }

    try {
      return await doFetch(persistent: true);
    } on HandshakeException {
      try {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return await doFetch(persistent: false);
      } catch (retryError) {
        return {errorKey: retryError.toString()};
      }
    } on SocketException {
      try {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return await doFetch(persistent: false);
      } catch (retryError) {
        return {errorKey: retryError.toString()};
      }
    } catch (error) {
      return {errorKey: error.toString()};
    }
  }
}
