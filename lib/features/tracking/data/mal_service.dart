import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'tracking_service.dart';
import '../domain/sync_progress_item.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/network/dio_client_provider.dart';
import '../../../../core/storage/secure_token_storage.dart';
import '../../../../core/config/sync_config.dart';

part 'mal_service.g.dart';

class MalService implements TrackingService {
  final Dio _dio;
  final SecureTokenStorage _storage;

  static const String _clientId = SyncConfig.malClientId;
  // MAL OAuth redirect — held in [SyncConfig.malRedirectUri] for parity with
  // the auth-URL builder in account_settings_screen.
  static const String _redirectUri = SyncConfig.malRedirectUri;

  static const String _kAccessTokenKey = 'mal_access_token';
  static const String _kRefreshTokenKey = 'mal_refresh_token';

  String? _accessToken;
  String? _refreshToken;
  Future<void>? _initFuture;

  // H32: serialize concurrent refresh attempts so multiple in-flight 401
  // responses don't fire parallel refresh calls (MAL rejects duplicates as
  // invalid_grant and burns the refresh token).
  Future<bool>? _refreshInFlight;

  MalService(this._dio, this._storage) {
    _initFuture = _initToken();
  }

  Future<void> _initToken() async {
    _accessToken = await _storage.read(_kAccessTokenKey);
    _refreshToken = await _storage.read(_kRefreshTokenKey);
  }

  Future<void> _ensureInit() async {
    if (_initFuture != null) {
      await _initFuture;
    }
  }

  @override
  String get name => 'MyAnimeList';

  @override
  String get idPrefix => 'mal';

  @override
  String get mainUrl => 'https://myanimelist.net';

  @override
  Future<bool> get isLoggedIn async {
    await _ensureInit();
    return _accessToken != null;
  }

  /// Generate a PKCE code verifier (43-128 chars, URL-safe).
  ///
  /// MAL uniquely requires `code_challenge_method=plain` — they do not
  /// implement S256. The `plain` method is still valid PKCE per RFC 7636
  /// §4.2; the verifier is sent as-is and the server compares strings.
  /// Do not "upgrade" to S256 — MAL will reject it with `invalid_request`.
  String generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(64, (_) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '').substring(0, 64);
  }

  @override
  Future<bool> login({
    Future<void> Function(String url, String code)? onDeviceCodeGenerated,
    Future<void> Function(String url)? onWebViewRequested,
    bool Function()? isCancelled,
  }) async {
    try {
      talker.debug('MALService: Initiating OAuth PKCE Flow..."');

      final codeVerifier = generateCodeVerifier();

      final authUrl =
          'https://myanimelist.net/v1/oauth2/authorize'
          '?response_type=code'
          '&client_id=$_clientId'
          '&code_challenge=$codeVerifier'
          '&code_challenge_method=plain'
          '&redirect_uri=${Uri.encodeComponent(_redirectUri)}';

      if (onWebViewRequested != null) {
        await onWebViewRequested(authUrl);
      }

      // The auth code should have been exchanged by the callback handler
      // (see account_settings_screen.dart which calls exchangeCodeForToken)
      return _accessToken != null;
    } catch (e) {
      talker.error('MALService: Login error', e);
      return false;
    }
  }

  /// Exchange the authorization code for access + refresh tokens.
  /// Called from the UI after capturing the redirect URL.
  Future<bool> exchangeCodeForToken(
    String redirectUrl,
    String codeVerifier,
  ) async {
    try {
      final uri = Uri.parse(redirectUrl);
      final code = uri.queryParameters['code'];

      if (code == null || code.isEmpty) {
        talker.error('MALService: No auth code found in redirect URL');
        return false;
      }

      talker.debug('MALService: Exchanging auth code for token...');

      final requestData = <String, dynamic>{
        'client_id': _clientId,
        'grant_type': 'authorization_code',
        'code': code,
        'code_verifier': codeVerifier,
        'redirect_uri': _redirectUri,
      };

      if (SyncConfig.malClientSecret.isNotEmpty) {
        requestData['client_secret'] = SyncConfig.malClientSecret;
      }

      final response = await _dio.post<Map<String, dynamic>>(
        'https://myanimelist.net/v1/oauth2/token',
        data: requestData,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final data = response.data;
      if (data != null && data['access_token'] != null) {
        _accessToken = data['access_token'] as String;
        _refreshToken = data['refresh_token'] as String?;

        await _storage.write(_kAccessTokenKey, _accessToken!);
        if (_refreshToken != null) {
          await _storage.write(_kRefreshTokenKey, _refreshToken!);
        }

        talker.debug('MALService: Token exchange successful');
        return true;
      }

      talker.error('MALService: Token exchange returned no access_token');
      return false;
    } catch (e) {
      talker.error('MALService: Token exchange failed', e);
      return false;
    }
  }

  /// Refresh the access token using the stored refresh token.
  /// Serializes concurrent callers through [_refreshInFlight] so multiple
  /// 401s from parallel API calls don't burn the refresh token.
  Future<bool> _refreshAccessToken() {
    final existing = _refreshInFlight;
    if (existing != null) return existing;
    final fut = _doRefreshAccessToken();
    _refreshInFlight = fut;
    fut.whenComplete(() => _refreshInFlight = null);
    return fut;
  }

  Future<bool> _doRefreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      talker.debug('MALService: Refreshing access token...');

      final requestData = <String, dynamic>{
        'client_id': _clientId,
        'grant_type': 'refresh_token',
        'refresh_token': _refreshToken,
      };

      if (SyncConfig.malClientSecret.isNotEmpty) {
        requestData['client_secret'] = SyncConfig.malClientSecret;
      }

      final response = await _dio.post<Map<String, dynamic>>(
        'https://myanimelist.net/v1/oauth2/token',
        data: requestData,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final data = response.data;
      if (data != null && data['access_token'] != null) {
        _accessToken = data['access_token'] as String;
        _refreshToken = data['refresh_token'] as String? ?? _refreshToken;

        await _storage.write(_kAccessTokenKey, _accessToken!);
        if (_refreshToken != null) {
          await _storage.write(_kRefreshTokenKey, _refreshToken!);
        }

        talker.debug('MALService: Token refreshed successfully');
        return true;
      }
      return false;
    } catch (e) {
      talker.error('MALService: Token refresh failed', e);
      return false;
    }
  }

  @override
  Future<void> logout() async {
    talker.debug('MALService: Logging out...');
    _accessToken = null;
    _refreshToken = null;
    await _storage.delete(_kAccessTokenKey);
    await _storage.delete(_kRefreshTokenKey);
  }

  @override
  Future<List<MultimediaItem>> search(String query) async {
    if (_accessToken == null) return [];

    // Search implementation
    return [];
  }

  @override
  Future<Map<String, String>> syncIds(MultimediaItem item) async {
    // MAL API doesn't have a direct reverse lookup from IMDB/TMDB
    // We rely on Simkl or MAL-Sync database to resolve MAL IDs
    return {};
  }

  Future<bool> _updateListStatus(
    int malId, {
    String? status,
    int? numWatchedEpisodes,
    bool isRetry = false,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (status != null) data['status'] = status;
      if (numWatchedEpisodes != null) {
        data['num_watched_episodes'] = numWatchedEpisodes;
      }

      final response = await _dio.patch<dynamic>(
        'https://api.myanimelist.net/v2/anime/$malId/my_list_status',
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );

      talker.debug(
        'MALService: Update list status success: ${response.statusCode}',
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      // Auto-refresh on 401 Unauthorized
      if (!isRetry && e.response?.statusCode == 401) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          return _updateListStatus(
            malId,
            status: status,
            numWatchedEpisodes: numWatchedEpisodes,
            isRetry: true,
          );
        }
      }
      talker.error('MALService: Update list status failed', e);
      return false;
    } catch (e) {
      talker.error('MALService: Update list status failed', e);
      return false;
    }
  }

  @override
  Future<bool> markWatched(
    MultimediaItem item,
    Episode? episode, {
    Map<String, String>? resolvedIds,
  }) async {
    if (_accessToken == null) return false;
    final malIdStr = resolvedIds?['mal'];
    if (malIdStr == null) return false;

    final malId = int.tryParse(malIdStr);
    if (malId == null) return false;

    if (item.contentType == MultimediaContentType.movie) {
      return _updateListStatus(malId, status: 'completed');
    } else {
      // Episode.episode defaults to 0 and many plugins never populate it.
      // num_watched_episodes is an absolute overwrite, so a 0 here resets the
      // user's progress for the whole title rather than doing nothing.
      if (episode == null || episode.episode <= 0) return false;
      return _updateListStatus(malId, numWatchedEpisodes: episode.episode);
    }
  }

  @override
  Future<bool> scrobbleStart(
    MultimediaItem item,
    Episode? episode,
    double progress, {
    Map<String, String>? resolvedIds,
  }) async {
    if (_accessToken == null) return false;
    final malIdStr = resolvedIds?['mal'];
    if (malIdStr == null) return false;

    final malId = int.tryParse(malIdStr);
    if (malId == null) return false;

    // Set status to watching
    return _updateListStatus(malId, status: 'watching');
  }

  @override
  Future<bool> scrobblePause(
    MultimediaItem item,
    Episode? episode,
    double progress, {
    Map<String, String>? resolvedIds,
  }) async {
    // No-op for MAL
    return true;
  }

  @override
  Future<bool> scrobbleStop(
    MultimediaItem item,
    Episode? episode,
    double progress, {
    Map<String, String>? resolvedIds,
  }) async {
    // No-op for MAL
    return true;
  }

  @override
  Future<bool> addToPlanToWatch(
    MultimediaItem item, {
    Map<String, String>? resolvedIds,
  }) async {
    if (_accessToken == null) return false;
    final malIdStr = resolvedIds?['mal'];
    if (malIdStr == null) return false;

    final malId = int.tryParse(malIdStr);
    if (malId == null) return false;

    return _updateListStatus(malId, status: 'plan_to_watch');
  }

  @override
  Future<List<SyncProgressItem>> pullPlaybackProgress() async {
    return [];
  }

  @override
  Future<bool> removePlaybackProgress(String id) async {
    return false;
  }
}

@riverpod
MalService malService(Ref ref) {
  return MalService(
    ref.watch(dioClientProvider),
    ref.watch(secureTokenStorageProvider),
  );
}
