import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../network/http_defaults.dart';

class ProxyOptions {
  final List<String> mirrorHosts;
  final List<String> keepCookies;
  final String? referer;

  ProxyOptions({
    this.mirrorHosts = const [],
    this.keepCookies = const [],
    this.referer,
  });

  factory ProxyOptions.fromJson(Map<String, dynamic> json) {
    return ProxyOptions(
      mirrorHosts:
          (json['mirrorHosts'] as List?)?.map((e) => e.toString()).toList() ??
          [],
      keepCookies:
          (json['keepCookies'] as List?)?.map((e) => e.toString()).toList() ??
          [],
      referer: json['referer']?.toString(),
    );
  }
}

class LocalProxyService {
  static final LocalProxyService _instance = LocalProxyService._internal();

  static LocalProxyService get instance => _instance;

  LocalProxyService._internal();

  HttpServer? _server;
  int _serverPort = 0;
  final Map<String, String> _playlists = {};

  static const int _maxPlaylists = 50;

  int get port => _serverPort;

  Future<void> startServer() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _serverPort = _server!.port;
      if (kDebugMode) {
        debugPrint("LocalProxyService: Started on port $_serverPort");
      }

      _server!.listen(_handleRequest);
    } catch (e) {
      if (kDebugMode) {
        debugPrint("LocalProxyService: Failed to start server: $e");
      }
    }
  }

  /// Stop the proxy and release the bound port. The proxy is a singleton
  /// reused across player sessions, so this is normally only called on app
  /// shutdown (audit B4 — port stays bound for the app lifetime otherwise,
  /// which only matters on desktop / long-running app processes).
  Future<void> shutdown() async {
    final server = _server;
    _server = null;
    _serverPort = 0;
    _playlists.clear();
    if (server != null) {
      try {
        await server.close(force: true);
        if (kDebugMode) debugPrint("LocalProxyService: shut down cleanly");
      } catch (e) {
        if (kDebugMode) debugPrint("LocalProxyService: shutdown error: $e");
      }
    }
  }

  /// Allow-list for incoming request schemes / hosts. We only serve to
  /// in-process media_kit (which connects to 127.0.0.1) — any request from
  /// another origin would mean a local web page is trying to scrape our
  /// stream URLs (audit B4). Returning false → 403 in the handler.
  bool _isAllowedOrigin(HttpRequest request) {
    // Only accept loopback connections at the socket level. The Dart
    // HttpServer is already bound to loopbackIPv4, but we double-check the
    // remote address here in case future code binds to anyAddress.
    final remote = request.connectionInfo?.remoteAddress;
    if (remote == null) return false;
    if (remote.isLoopback) return true;
    // Fail closed.
    return false;
  }

  /// Validates that a proxy `?url=...` parameter points at a network resource
  /// the proxy should fetch. Rejects `javascript:`, `file:`, `data:`, and
  /// anything that's not a syntactically valid http(s) URL. Audit B4.
  bool _isProxyableUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (!uri.hasScheme) return false;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;
    if (uri.host.isEmpty) return false;
    return true;
  }

  /// Stores a generated M3U8 content and returns the local URL to access it.
  String serveM3u8(String content) {
    if (_server == null) startServer(); // Ensure started

    // Evict oldest entries if at capacity
    while (_playlists.length >= _maxPlaylists) {
      _playlists.remove(_playlists.keys.first);
    }

    final uuid =
        "${DateTime.now().millisecondsSinceEpoch}_${(content.length % 1000)}";
    _playlists[uuid] = content;
    return "http://127.0.0.1:$_serverPort/$uuid.m3u8";
  }

  /// Returns a proxied URL for the given target URL, with optional sticky headers and options.
  String getProxyUrl(
    String targetUrl, {
    Map<String, String>? headers,
    ProxyOptions? options,
    bool forceM3u8Extension = false,
  }) {
    if (_server == null) startServer();
    final encoded = Uri.encodeComponent(targetUrl);
    String url = "http://127.0.0.1:$_serverPort/proxy?url=$encoded";

    if (headers != null && headers.isNotEmpty) {
      final headerJson = jsonEncode(headers);
      final headerB64 = base64Url.encode(utf8.encode(headerJson));
      url += "&h=$headerB64";
    }

    if (options != null) {
      final optJson = jsonEncode({
        'mirrorHosts': options.mirrorHosts,
        'keepCookies': options.keepCookies,
        'referer': options.referer,
      });
      final optB64 = base64Url.encode(utf8.encode(optJson));
      url += "&o=$optB64";
    }

    if (forceM3u8Extension) {
      url += "&extension=.m3u8";
    }

    return url;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      // Reject any non-loopback caller — defence-in-depth on top of the
      // loopback bind. Audit B4.
      if (!_isAllowedOrigin(request)) {
        request.response.statusCode = HttpStatus.forbidden;
        unawaited(request.response.close());
        return;
      }

      final path = request.uri.path;

      // PROXY HANDLER
      if (path == '/proxy') {
        await _handleProxyRequest(request);
        return;
      }

      // M3U8 HANDLER
      // Expected path: /<uuid>.m3u8
      if (path.length > 1 && path.endsWith('.m3u8')) {
        await _handlePlaylistRequest(request, path);
        return;
      }

      request.response.statusCode = HttpStatus.notFound;
      unawaited(request.response.close());
    } catch (e) {
      if (kDebugMode) debugPrint("LocalProxyService: Server Error: $e");
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        unawaited(request.response.close());
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'LocalProxyService._handleRequest: error response failed: $e',
          );
        }
      }
    }
  }

  Future<void> _handlePlaylistRequest(HttpRequest request, String path) async {
    final uuid = path.substring(1).replaceAll(".m3u8", "");
    if (_playlists.containsKey(uuid)) {
      final content = _playlists[uuid]!;
      request.response.headers.contentType = ContentType(
        "application",
        "vnd.apple.mpegurl",
        charset: "utf-8",
      );
      // Scope CORS to the local proxy origin. media_kit / video_view make
      // requests in-process; no legitimate cross-origin browser should be
      // hitting these URLs. Audit B4.
      request.response.headers.add(
        "Access-Control-Allow-Origin",
        "http://127.0.0.1:$_serverPort",
      );
      request.response.add(utf8.encode(content));
    } else {
      request.response.statusCode = HttpStatus.notFound;
    }
    unawaited(request.response.close());
  }

  Future<void> _handleProxyRequest(HttpRequest request) async {
    final targetUrl = request.uri.queryParameters['url'];
    if (targetUrl == null) {
      request.response.statusCode = HttpStatus.badRequest;
      unawaited(request.response.close());
      return;
    }

    // Scheme / shape validation — block file://, javascript:, data: and any
    // other non-network scheme that a malicious plugin could embed in a
    // stream URL it returns to us. Audit B4.
    if (!_isProxyableUrl(targetUrl)) {
      if (kDebugMode) {
        debugPrint("[PROXY] Rejecting non-proxyable URL: $targetUrl");
      }
      request.response.statusCode = HttpStatus.badRequest;
      unawaited(request.response.close());
      return;
    }

    if (kDebugMode) debugPrint("[PROXY] Incoming Request for: $targetUrl");

    final Map<String, String> stickyHeaders = {};
    final hBase64 = request.uri.queryParameters['h'];
    if (hBase64 != null) {
      try {
        final decoded = utf8.decode(base64Url.decode(hBase64));
        final Map<String, dynamic> map =
            jsonDecode(decoded) as Map<String, dynamic>;
        map.forEach((key, value) => stickyHeaders[key] = value.toString());
      } catch (e) {
        if (kDebugMode) {
          debugPrint("[PROXY] Failed to parse sticky headers: $e");
        }
      }
    }

    ProxyOptions? options;
    final oBase64 = request.uri.queryParameters['o'];
    if (oBase64 != null) {
      try {
        final decoded = utf8.decode(base64Url.decode(oBase64));
        options = ProxyOptions.fromJson(
          jsonDecode(decoded) as Map<String, dynamic>,
        );
      } catch (e) {
        if (kDebugMode) debugPrint("[PROXY] Failed to parse options: $e");
      }
    }

    // Check if this is an M3U8 request to handle Range headers and rewriting
    final isRequestM3u8 = targetUrl.toLowerCase().contains(".m3u8");

    final client = HttpClient();
    // Bound the upstream so a stuck CDN can't freeze the player UI
    // indefinitely (audit B4). Connection: 10 s, idle: 30 s. These cover
    // the long tail of slow but eventually-responsive providers without
    // hanging on truly dead hosts.
    client.connectionTimeout = const Duration(seconds: 10);
    client.idleTimeout = const Duration(seconds: 30);
    // For M3U8: autoUncompress=true so gzip-encoded playlists arrive as UTF-8
    // text we can parse and rewrite. Content-Length is stripped for M3U8
    // responses (body is rewritten, size changes).
    //
    // For binary video (MKV, MP4, TS): autoUncompress=false so Dart never
    // injects "Accept-Encoding: gzip" on the outgoing request. CDNs treat
    // gzip + Range as incompatible and return 200 (full file) instead of 206
    // (partial), which breaks seeking.
    client.autoUncompress = isRequestM3u8;
    client.badCertificateCallback = (cert, host, port) => true;

    try {
      final req = await client.getUrl(Uri.parse(targetUrl));

      // 1. Process incoming request headers first (Player headers)
      final Map<String, String> mergedCookies = {};
      request.headers.forEach((name, values) {
        final lowerName = name.toLowerCase();
        if (lowerName == 'cookie') {
          for (final v in values) {
            for (final pair in v.split(';')) {
              final parts = pair.split('=');
              if (parts.length >= 2) {
                mergedCookies[parts[0].trim()] = parts
                    .sublist(1)
                    .join('=')
                    .trim();
              }
            }
          }
        } else if (lowerName == 'range' && isRequestM3u8) {
          // debugPrint("[PROXY] Stripping Range header for M3U8 request to force status 200");
          // Skip Range header for M3U8 to ensure we get the full file for rewriting
        } else if (lowerName != 'host' &&
            lowerName != 'content-length' &&
            lowerName != 'connection' &&
            lowerName != 'accept-encoding' &&
            lowerName != 'referer' &&
            lowerName != 'user-agent' &&
            lowerName != 'icy-metadata') {
          for (final value in values) {
            req.headers.add(name, value);
          }
        }
      });

      // 2. Process Sticky Headers (Plugin headers - Priority)
      stickyHeaders.forEach((name, value) {
        final lowerName = name.toLowerCase();
        if (lowerName == 'cookie') {
          for (final pair in value.split(';')) {
            final parts = pair.split('=');
            if (parts.length >= 2) {
              mergedCookies[parts[0].trim()] = parts
                  .sublist(1)
                  .join('=')
                  .trim();
            }
          }
        } else {
          req.headers.set(name, value);
        }
      });

      // 3. Set Merged Cookies
      if (mergedCookies.isNotEmpty) {
        final cookieString = mergedCookies.entries
            .map((e) => "${e.key}=${e.value}")
            .join("; ");
        req.headers.set("Cookie", cookieString);
        // debugPrint("[PROXY] Final Cookie String: $cookieString");
      }

      // 4. Sanitize and Default Headers
      _applySanitizedHeaders(req, targetUrl, options);

      // Dart's HttpClient (autoUncompress=true) injects "Accept-Encoding: gzip"
      // on every outgoing request. CDNs treat gzip + Range as incompatible and
      // fall back to a 200 full-file response instead of 206, breaking seeks.
      req.headers.set('accept-encoding', 'identity');

      if (kDebugMode) {
        final rangeHeader = req.headers.value('range');
        if (rangeHeader != null) {
          debugPrint('[PROXY] Range request: $rangeHeader → $targetUrl');
          debugPrint(
            '[PROXY] accept-encoding: ${req.headers.value('accept-encoding')}',
          );
        }
      }
      final response = await _fetchWithRedirects(
        client,
        req,
        targetUrl,
        options,
      );
      if (kDebugMode) {
        final rangeHeader = req.headers.value('range');
        if (rangeHeader != null) {
          debugPrint(
            '[PROXY] CDN responded: ${response.statusCode}, content-range: ${response.headers.value('content-range')}',
          );
        }
        debugPrint(
          "[PROXY] Response Status: ${response.statusCode}, Content-Type: ${response.headers.contentType}",
        );
      }

      // Detect M3U8 BEFORE copying response headers. Rewriting expands all
      // segment/rendition URLs, so the rewritten body is much larger than the
      // original. If we copy Content-Length first and then try to remove it,
      // Dart's HttpResponse has already stored the value internally and still
      // enforces the limit — causing "Content size exceeds specified
      // contentLength" when we write the larger rewritten body.
      final isResponseM3u8 = _isM3u8(
        response.headers.contentType?.mimeType,
        targetUrl,
      );
      if (kDebugMode) {
        debugPrint("[PROXY] Detected isM3u8: $isResponseM3u8 for $targetUrl");
      }

      // Detect CDN edge gzip-decompression mismatch: some CDNs (e.g. Cloudflare
      // when origin storage is gzipped) reply to a Range request with status
      // 206, Transfer-Encoding: chunked, and a content-range header that
      // reports the COMPRESSED file size while the chunked body delivers the
      // DECOMPRESSED bytes. mpv/FFmpeg trusts the content-range total and
      // truncates reads at the bogus size, producing partial AAC/h264 frames
      // and decoder errors. Diagnostic: 206 + chunked + content-range without
      // content-length. In that case the response is effectively the full
      // file, so convert to 200 and drop the misleading content-range.
      final hasChunkedEncoding =
          response.headers
              .value('transfer-encoding')
              ?.toLowerCase()
              .contains('chunked') ==
          true;
      final hasContentRange = response.headers.value('content-range') != null;
      final hasContentLength = response.headers.value('content-length') != null;
      final misleadingContentRange =
          !isResponseM3u8 &&
          response.statusCode == 206 &&
          hasChunkedEncoding &&
          hasContentRange &&
          !hasContentLength;
      if (kDebugMode && misleadingContentRange) {
        debugPrint(
          '[PROXY] Detected CDN edge-decompression mismatch — converting '
          '206→200 and dropping content-range for $targetUrl',
        );
      }

      request.response.statusCode =
          (isResponseM3u8 &&
              (response.statusCode == 200 || response.statusCode == 206))
          ? 200
          : (misleadingContentRange ? 200 : response.statusCode);

      // Dart's autoUncompress=true decompresses gzip bodies but does NOT update
      // Content-Length (still shows compressed size) or remove Content-Encoding.
      // We must strip both for gzip responses so mpv doesn't double-decompress
      // and gets accurate size hints.
      //
      // For M3U8 responses the body is rewritten (URLs expanded), so
      // content-length is always wrong regardless of encoding.
      //
      // For plain binary responses (MKV, MP4, JPEG video segments, etc.) we
      // must forward content-length as-is: mpv relies on it to build the
      // byte-offset table for seeking. Stripping it makes mpv treat the stream
      // as "linear" and refuse backward seeks.
      final wasGzip =
          response.headers
              .value('content-encoding')
              ?.toLowerCase()
              .contains('gzip') ==
          true;
      response.headers.forEach((name, values) {
        final lowerName = name.toLowerCase();
        if (lowerName == 'access-control-allow-origin') return;
        if (lowerName == 'transfer-encoding') return;
        // Strip content-length when gzip (size changed after decompress) or M3U8
        // (body will be rewritten). Keep it for binary content so mpv can seek.
        if (lowerName == 'content-length' && (wasGzip || isResponseM3u8)) {
          return;
        }
        // Strip content-encoding only when we actually decompressed gzip.
        // Forwarding "Content-Encoding: gzip" with a plain body causes mpv to
        // attempt decompression and corrupt the data.
        if (lowerName == 'content-encoding' && wasGzip) return;
        // Drop the lying content-range from CDN edge-decompression mismatch.
        if (lowerName == 'content-range' && misleadingContentRange) return;
        for (final value in values) {
          request.response.headers.add(name, value);
        }
      });
      // Scope CORS to local proxy origin only — see _handlePlaylistRequest.
      request.response.headers.add(
        "Access-Control-Allow-Origin",
        "http://127.0.0.1:$_serverPort",
      );

      // Allow rewriting for 200 (OK) and 206 (Partial) if it's an M3U8
      if (isResponseM3u8 &&
          (response.statusCode == 200 || response.statusCode == 206)) {
        if (kDebugMode) {
          debugPrint("[PROXY] Triggering M3U8 rewrite for: $targetUrl");
        }
        request.response.headers.contentType = ContentType(
          "application",
          "vnd.apple.mpegurl",
          charset: "utf-8",
        );
        await _rewriteM3u8Response(
          response,
          request,
          targetUrl,
          stickyHeaders,
          options,
        );
      } else {
        // Pipe binary data (segments, keys, etc.)
        await response.pipe(request.response);
      }
    } catch (e) {
      if (kDebugMode) debugPrint("LocalProxyService: Proxy Request Error: $e");
      request.response.statusCode = HttpStatus.badGateway;
      await request.response.close();
    }
  }

  void _applySanitizedHeaders(
    HttpClientRequest req,
    String targetUrl,
    ProxyOptions? options,
  ) {
    // Default User-Agent if missing. Uses the app-wide browser identity rather
    // than an ExoPlayer string, so a proxied request looks like every other
    // request this app makes for the same stream.
    if (req.headers['User-Agent'] == null) {
      req.headers.set("User-Agent", kDefaultBrowserUserAgent);
    }

    // Default Referer if missing or proxy-based
    final existingReferer = req.headers['Referer']?.join("");
    if (existingReferer == null || existingReferer.contains("127.0.0.1")) {
      final uri = Uri.parse(targetUrl);
      final optReferer = options?.referer;
      if (optReferer != null) {
        req.headers.set("Referer", optReferer);
      } else {
        req.headers.set("Referer", "${uri.scheme}://${uri.host}/");
      }
    }

    // CLEANUP: If target is CDN, remove session cookies (Mirror's security requirement)
    // NOTE: For NetMirror, we actually WANT to keep cookies for their specific CDNs if possible,
    // as they sometimes validate both the 'in' param and the 't_hash_t' cookie.
    final targetUri = Uri.parse(targetUrl);
    bool isMirrorSite = false;
    if (options != null) {
      isMirrorSite = options.mirrorHosts.any(
        (host) => targetUri.host.contains(host),
      );
    }

    if (!isMirrorSite) {
      final currentCookies = req.headers['Cookie']?.join("; ") ?? "";
      if (options != null && options.keepCookies.isNotEmpty) {
        final filtered = currentCookies
            .split(';')
            .map((s) => s.trim())
            .where((s) {
              final key = s.split('=')[0];
              return options.keepCookies.contains(key);
            })
            .join("; ");
        if (filtered.isNotEmpty) {
          req.headers.set("Cookie", filtered);
        } else {
          req.headers.removeAll("Cookie");
        }
      } else {
        req.headers.removeAll("Cookie");
      }
    }

    // Default hd=on if keepCookies contains it
    if (options != null && options.keepCookies.contains("hd")) {
      final finalCookies = req.headers['Cookie']?.join("; ") ?? "";
      if (!finalCookies.contains("hd=on")) {
        if (finalCookies.isEmpty) {
          req.headers.set("Cookie", "hd=on");
        } else {
          req.headers.set("Cookie", "$finalCookies; hd=on");
        }
      }
    }
  }

  /// Manually follow redirects to ensure headers (Referer/User-Agent) are preserved
  Future<HttpClientResponse> _fetchWithRedirects(
    HttpClient client,
    HttpClientRequest initialRequest,
    String currentUrl,
    ProxyOptions? options,
  ) async {
    HttpClientRequest currentReq = initialRequest;
    currentReq.followRedirects = false; // We handle it

    int redirectCount = 0;
    const maxRedirects = 5;

    while (redirectCount < maxRedirects) {
      final response = await currentReq.close();

      if (response.statusCode == HttpStatus.movedPermanently ||
          response.statusCode == HttpStatus.found ||
          response.statusCode == HttpStatus.seeOther ||
          response.statusCode == HttpStatus.temporaryRedirect ||
          response.statusCode == HttpStatus.permanentRedirect) {
        final location = response.headers.value('location');
        if (location == null) return response;

        final nextUrl = Uri.parse(currentUrl).resolve(location).toString();
        redirectCount++;

        final nextReq = await client.getUrl(Uri.parse(nextUrl));
        nextReq.followRedirects = false;

        // PRESERVE CRITICAL HEADERS
        initialRequest.headers.forEach((name, values) {
          final lowerName = name.toLowerCase();
          if (lowerName != 'host' &&
              lowerName != 'content-length' &&
              lowerName != 'connection') {
            for (final v in values) {
              nextReq.headers.add(name, v);
            }
          }
        });

        // RE-APPLY SANITIZATION for the nextHop (especially cleaning cookies for CDNs)
        _applySanitizedHeaders(nextReq, nextUrl, options);

        currentReq = nextReq;
        currentUrl = nextUrl;
      } else {
        return response;
      }
    }

    throw Exception("Too many redirects");
  }

  bool _isM3u8(String? mimeType, String url) {
    final lowerUrl = url.toLowerCase();
    return (mimeType == "application/vnd.apple.mpegurl" ||
        mimeType == "application/x-mpegurl" ||
        mimeType == "audio/x-mpegurl" ||
        mimeType == "video/x-mpegurl" ||
        lowerUrl.contains(".m3u8") ||
        lowerUrl.contains(".m3u") ||
        lowerUrl.contains("play.php") ||
        lowerUrl.contains("index.php") ||
        lowerUrl.contains("playlist.php"));
  }

  Future<void> _rewriteM3u8Response(
    HttpClientResponse sourceResponse,
    HttpRequest clientRequest,
    String originalUrl,
    Map<String, String> stickyHeaders,
    ProxyOptions? options,
  ) async {
    final contentBytes = await sourceResponse.toList();
    final allBytes = contentBytes.expand((x) => x).toList();

    if (!_isValidM3u8(allBytes)) {
      // debugPrint("[PROXY] M3U8 Validation Failed for: $originalUrl");
      // Fallback to binary pipe
      clientRequest.response.add(allBytes);
      await clientRequest.response.close();
      return;
    }

    final content = utf8.decode(allBytes, allowMalformed: true);
    // debugPrint("[PROXY] Rewriting M3U8 content (${content.length} chars)");
    final baseUrl = Uri.parse(originalUrl);

    final rewritten = content
        .split('\n')
        .map((line) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) return line;

          if (trimmed.startsWith("#")) {
            if (trimmed.contains('URI="')) {
              return trimmed.replaceAllMapped(RegExp(r'URI="([^"]+)"'), (
                match,
              ) {
                final uri = match.group(1)!;
                final r = _rewriteUrl(uri, baseUrl, stickyHeaders, options);
                // debugPrint("[PROXY] Rewrote Tag URI: $uri");
                return 'URI="$r"';
              });
            }
            return line;
          }

          // Segment URL
          final r = _rewriteUrl(
            trimmed,
            baseUrl,
            stickyHeaders,
            options,
            isSegment: true,
          );
          // debugPrint("[PROXY] Rewrote Segment: $trimmed");
          return r;
        })
        .join('\n');

    clientRequest.response.add(utf8.encode(rewritten));
    await clientRequest.response.close();
    // debugPrint("[PROXY] M3U8 Rewrite Complete for: $originalUrl");
  }

  bool _isValidM3u8(List<int> bytes) {
    try {
      if (bytes.length > 4) {
        final content = utf8
            .decode(bytes.take(50).toList(), allowMalformed: true)
            .trim();
        if (kDebugMode) {
          debugPrint(
            "[PROXY] M3U8 Validation Check: '${content.substring(0, content.length > 10 ? 10 : content.length)}...'",
          );
        }
        return content.contains("#EXT");
      }
    } catch (e) {
      if (kDebugMode) debugPrint('LocalProxyService._isValidM3u8: $e');
    }
    return false;
  }

  String _rewriteUrl(
    String uri,
    Uri baseUrl,
    Map<String, String> stickyHeaders,
    ProxyOptions? options, {
    bool isSegment = false,
  }) {
    try {
      Uri resolved = baseUrl.resolve(uri);

      // Generic Mirror Security: If the resolved URL is relative (same host) OR on a mirror host
      // and has no query, it MUST inherit the query params from the parent playlist.
      bool isHostMatch = false;
      if (options != null) {
        isHostMatch = options.mirrorHosts.any(
          (host) => resolved.host.contains(host),
        );
      }

      if (resolved.query.isEmpty &&
          baseUrl.query.isNotEmpty &&
          (resolved.host == baseUrl.host || isHostMatch)) {
        resolved = resolved.replace(query: baseUrl.query);
      }
      final proxyUrl = getProxyUrl(
        resolved.toString(),
        headers: stickyHeaders,
        options: options,
      );
      // FFmpeg's HLS demuxer calls av_match_ext(url, allowed_extensions) on
      // segment URLs. It uses strrchr(url, '.') to extract the extension, so
      // the LAST dot in the full proxy URL string determines what extension
      // FFmpeg sees. Without this suffix the last dot lands inside the
      // percent-encoded CDN path (e.g. ...5795_000.js%3Fin%3D...&h=BASE64)
      // giving an extension like "js%3F..." which matches nothing.
      // Appending &_ext=.ts makes strrchr find ".ts" — which IS in FFmpeg's
      // default allowed_extensions whitelist. Audio rendition segments skip
      // this check (separate child AVFormatContext path), explaining why audio
      // worked but video was silently blocked.
      // The proxy ignores _ext; it only reads url/h/o query params.
      return isSegment ? '$proxyUrl&_ext=.ts' : proxyUrl;
    } catch (e) {
      return uri;
    }
  }
}
