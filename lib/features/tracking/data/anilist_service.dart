import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'tracking_service.dart';
import '../domain/sync_progress_item.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/network/dio_client_provider.dart';
import '../../../../core/storage/secure_token_storage.dart';
import '../../../../core/config/sync_config.dart';

part 'anilist_service.g.dart';

class AniListService implements TrackingService {
  final Dio _dio;
  final SecureTokenStorage _storage;

  static const String _clientId = SyncConfig.anilistClientId;
  static const String _kAccessTokenKey = 'anilist_access_token';

  String? _accessToken;
  Future<void>? _initFuture;

  AniListService(this._dio, this._storage) {
    _initFuture = _initToken();
  }

  Future<void> _initToken() async {
    _accessToken = await _storage.read(_kAccessTokenKey);
  }

  Future<void> _ensureInit() async {
    if (_initFuture != null) {
      await _initFuture;
    }
  }

  @override
  String get name => 'AniList';

  @override
  String get idPrefix => 'anilist';

  @override
  String get mainUrl => 'https://anilist.co';

  @override
  Future<bool> get isLoggedIn async {
    await _ensureInit();
    return _accessToken != null;
  }

  @override
  Future<bool> login({
    Future<void> Function(String url, String code)? onDeviceCodeGenerated,
    Future<void> Function(String url)? onWebViewRequested,
    bool Function()? isCancelled,
  }) async {
    try {
      talker.debug('AniListService: Initiating OAuth Implicit Grant Flow..."');
      const authUrl =
          'https://anilist.co/api/v2/oauth/authorize'
          '?client_id=$_clientId'
          '&response_type=token';

      if (onWebViewRequested != null) {
        await onWebViewRequested(authUrl);
      }

      // The access token should have been saved by the callback handler
      // (see account_settings_screen.dart which calls saveToken)
      return _accessToken != null;
    } catch (e) {
      talker.error('AniListService: Login error', e);
      return false;
    }
  }

  /// Parse the redirect URL and extract + save the access token.
  /// AniList implicit grant returns the token in the URL fragment:
  /// https://anilist.co/api/v2/oauth/pin#access_token=...&token_type=Bearer&expires_in=...
  Future<bool> saveTokenFromRedirect(String redirectUrl) async {
    try {
      // The token is in the fragment (after #), not in query params
      String fragment = '';
      final hashIndex = redirectUrl.indexOf('#');
      if (hashIndex != -1) {
        fragment = redirectUrl.substring(hashIndex + 1);
      } else {
        // Fallback: try query params (some webview implementations may convert # to ?)
        final uri = Uri.parse(redirectUrl);
        if (uri.queryParameters.containsKey('access_token')) {
          fragment = uri.query;
        }
      }

      if (fragment.isEmpty) {
        talker.error('AniListService: No fragment found in redirect URL');
        return false;
      }

      // Parse fragment as query parameters
      final params = Uri.splitQueryString(fragment);
      final token = params['access_token'];

      if (token == null || token.isEmpty) {
        talker.error('AniListService: No access_token found in redirect');
        return false;
      }

      _accessToken = token;
      await _storage.write(_kAccessTokenKey, _accessToken!);
      talker.debug('AniListService: Token saved successfully');
      return true;
    } catch (e) {
      talker.error('AniListService: Failed to parse redirect URL', e);
      return false;
    }
  }

  @override
  Future<void> logout() async {
    talker.debug('AniListService: Logging out...');
    _accessToken = null;
    await _storage.delete(_kAccessTokenKey);
  }

  @override
  Future<List<MultimediaItem>> search(String query) async {
    if (_accessToken == null) return [];

    // GraphQL Search implementation
    return [];
  }

  @override
  Future<Map<String, String>> syncIds(MultimediaItem item) async {
    // AniList IDs usually resolved via Simkl or MAL-Sync
    return {};
  }

  Future<bool> _saveMediaListEntry(
    int anilistId, {
    String? status,
    int? progress,
  }) async {
    try {
      final variables = <String, dynamic>{'mediaId': anilistId};
      if (status != null) variables['status'] = status;
      if (progress != null) variables['progress'] = progress;

      final response = await _dio.post<dynamic>(
        'https://graphql.anilist.co',
        data: {
          'query': '''
            mutation (\$mediaId: Int, \$status: MediaListStatus, \$progress: Int) {
              SaveMediaListEntry(mediaId: \$mediaId, status: \$status, progress: \$progress) {
                id
                status
                progress
              }
            }
          ''',
          'variables': variables,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      // AniList returns 200 OK even when the GraphQL mutation has an
      // `errors` field (validation, permission, rate-limit). Treat that
      // as a failure so the user isn't silently ignored.
      final body = response.data;
      if (response.statusCode == 200 &&
          body is Map &&
          body['errors'] is List &&
          (body['errors'] as List).isNotEmpty) {
        talker.error(
          'AniListService: GraphQL errors on SaveMediaListEntry: ${body['errors']}',
        );
        return false;
      }
      talker.debug(
        'AniListService: SaveMediaListEntry success: ${response.statusCode}',
      );
      return response.statusCode == 200;
    } catch (e) {
      talker.error('AniListService: SaveMediaListEntry failed', e);
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
    final anilistIdStr = resolvedIds?['anilist'];
    if (anilistIdStr == null) return false;

    final anilistId = int.tryParse(anilistIdStr);
    if (anilistId == null) return false;

    if (item.contentType == MultimediaContentType.movie) {
      return _saveMediaListEntry(anilistId, status: 'COMPLETED');
    } else {
      // Episode.episode defaults to 0 and many plugins never populate it.
      // progress is an absolute overwrite, so a 0 here resets the user's
      // progress for the whole title rather than doing nothing.
      if (episode == null || episode.episode <= 0) return false;
      return _saveMediaListEntry(anilistId, progress: episode.episode);
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
    final anilistIdStr = resolvedIds?['anilist'];
    if (anilistIdStr == null) return false;

    final anilistId = int.tryParse(anilistIdStr);
    if (anilistId == null) return false;

    // Set status to CURRENT (Watching)
    return _saveMediaListEntry(anilistId, status: 'CURRENT');
  }

  @override
  Future<bool> scrobblePause(
    MultimediaItem item,
    Episode? episode,
    double progress, {
    Map<String, String>? resolvedIds,
  }) async {
    // No-op for AniList
    return true;
  }

  @override
  Future<bool> scrobbleStop(
    MultimediaItem item,
    Episode? episode,
    double progress, {
    Map<String, String>? resolvedIds,
  }) async {
    // No-op for AniList
    return true;
  }

  @override
  Future<bool> addToPlanToWatch(
    MultimediaItem item, {
    Map<String, String>? resolvedIds,
  }) async {
    if (_accessToken == null) return false;
    final anilistIdStr = resolvedIds?['anilist'];
    if (anilistIdStr == null) return false;

    final anilistId = int.tryParse(anilistIdStr);
    if (anilistId == null) return false;

    return _saveMediaListEntry(anilistId, status: 'PLANNING');
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
AniListService aniListService(Ref ref) {
  return AniListService(
    ref.watch(dioClientProvider),
    ref.watch(secureTokenStorageProvider),
  );
}
