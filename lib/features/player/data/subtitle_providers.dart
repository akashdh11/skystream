import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../domain/entity/subtitle_model.dart';

class OpenSubtitlesProvider extends SubtitleProvider {
  final Dio _dio;
  final String? _apiKey;
  static const String baseUrl = "https://api.opensubtitles.com/api/v1";
  static const String _defaultApiKey = "uyBLgFD17MgrYmA0gSXoKllMJBelOYj2";
  static const String _userAgent = "SkyStream v2.2.1";

  // Auth state
  final String? _username;
  final String? _password;
  String? _token;
  DateTime? _tokenExpiry;

  OpenSubtitlesProvider(
    this._dio, {
    String? username,
    String? password,
    String? apiKey,
  }) : _username = username,
       _password = password,
       _apiKey = apiKey;

  String get _effectiveApiKey =>
      (_apiKey != null && _apiKey!.isNotEmpty) ? _apiKey! : _defaultApiKey;

  Future<void> _loginIfNeeded() async {
    if (_username == null ||
        _username.isEmpty ||
        _password == null ||
        _password!.isEmpty) {
      if (kDebugMode) {
        print("[OpenSubtitles] Skipping login: Credentials not set.");
      }
      return;
    }

    // Token is valid for 24 hours. We re-login if it's missing or expiring in < 5 mins.
    if (_token != null &&
        _tokenExpiry != null &&
        _tokenExpiry!.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      return;
    }

    try {
      final response = await _dio.post<dynamic>(
        "$baseUrl/login",
        data: {'username': _username, 'password': _password},
        options: Options(
          headers: {
            ...SubtitleProvider.commonHeaders,
            'user-agent': _userAgent,
            'Content-Type': 'application/json',
            'Api-Key': _effectiveApiKey,
          },
        ),
      );

      if (response.data != null && response.data['token'] != null) {
        _token = response.data?['token'] as String?;
        _tokenExpiry = DateTime.now().add(
          const Duration(hours: 23),
        ); // OS tokens last 24h
        if (kDebugMode) {
          print(
            "[OpenSubtitles] Auth Success. Token: ${_token?.substring(0, 10)}...",
          );
        }
      }
    } catch (e) {
      if (e is DioException) {
        final errorBody = e.response?.data;
        if (kDebugMode) {
          print("[OpenSubtitles] Login failed: ${e.message}");
          if (errorBody != null) {
            print("[OpenSubtitles] Error body: $errorBody");
          }
        }
      } else if (kDebugMode) {
        print("[OpenSubtitles] Login error: $e");
      }
    }
  }

  /// Verifies if the credentials are valid by performing a login.
  Future<bool> verifyCredentials() async {
    if (_username == null ||
        _username.isEmpty ||
        _password == null ||
        _password!.isEmpty) {
      return false;
    }
    if (kDebugMode) {
      final keyType = (_apiKey != null && _apiKey!.isNotEmpty)
          ? "User"
          : "Default";
      final maskedKey = _effectiveApiKey.length > 5
          ? "${_effectiveApiKey.substring(0, 5)}..."
          : _effectiveApiKey;
      print(
        "[OpenSubtitles] Verifying Credentials (Mode: $keyType) for: $_username (Key: $maskedKey)",
      );
    }
    try {
      final response = await _dio.post<dynamic>(
        "$baseUrl/login",
        data: {'username': _username, 'password': _password},
        options: Options(
          headers: {
            ...SubtitleProvider.commonHeaders,
            'user-agent': _userAgent,
            'Content-Type': 'application/json',
            'Api-Key': _effectiveApiKey,
          },
        ),
      );
      return response.data != null && response.data['token'] != null;
    } catch (e) {
      return false;
    }
  }

  @override
  String get name => "OpenSubtitles";

  @override
  String get idPrefix => "opensubtitles";

  @override
  Future<List<OnlineSubtitle>> search({
    required String query,
    String? imdbId,
    int? tmdbId,
    int? season,
    int? episode,
    String? language,
    CancelToken? cancelToken,
  }) async {
    if (kDebugMode) {
      final keyType = (_apiKey != null && _apiKey!.isNotEmpty)
          ? "User"
          : "Default";
      final maskedKey = _effectiveApiKey.length > 5
          ? "${_effectiveApiKey.substring(0, 5)}..."
          : _effectiveApiKey;
      print(
        "[OpenSubtitles] Search (Mode: $keyType): query=$query, imdb=$imdbId, lang=$language (Key: $maskedKey, Agent: $_userAgent)",
      );
    }
    try {
      final String langTag = language ?? "en";

      // Build query parameters
      final Map<String, dynamic> params = {'languages': langTag};

      if (imdbId != null) {
        params['imdb_id'] = imdbId.replaceAll('tt', '');
      } else if (tmdbId != null) {
        params['tmdb_id'] = tmdbId;
      } else {
        params['query'] = query;
      }

      if (season != null && season > 0) params['season_number'] = season;
      if (episode != null && episode > 0) params['episode_number'] = episode;

      await _loginIfNeeded();

      final Map<String, String> headers = {
        ...SubtitleProvider.commonHeaders,
        'user-agent': _userAgent,
        'Api-Key': _effectiveApiKey,
      };

      if (_token != null) {
        headers['Authorization'] = 'Bearer $_token';
      }

      try {
        final response = await _dio.get<dynamic>(
          "$baseUrl/subtitles",
          queryParameters: params,
          cancelToken: cancelToken,
          options: Options(headers: headers),
        );

        if (response.data == null || response.data['data'] == null) return [];

        final List<dynamic> results = response.data['data'] as List;
        if (kDebugMode) {
          debugPrint("[OpenSubtitles] Found ${results.length} results.");
        }

        return results.map((dynamic item) {
          final attr = (item as Map)['attributes'] as Map<String, dynamic>;
          final files = attr['files'] as List;
          final file = files.isNotEmpty ? files.first as Map : null;
          final featureDetails = attr['feature_details'] as Map?;

          final name =
              (attr['release'] as String?) ??
              (featureDetails?['title'] as String?) ??
              (featureDetails?['movie_name'] as String?) ??
              query;

          return OnlineSubtitle(
            id: file != null
                ? file['file_id'].toString()
                : item['id'].toString(),
            name: name,
            language: (attr['language'] as String?) ?? langTag,
            source: this.name,
            downloadUrl: "", // Requires getDownloadUrl
            isHearingImpaired: (attr['hearing_impaired'] as bool?) ?? false,
            metadata: {'file_id': file != null ? file['file_id'] : null},
          );
        }).toList();
      } on DioException catch (e) {
        // If 401/403, our token might be invalid. Clear and retry once.
        if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
          if (kDebugMode) {
            print(
              "[OpenSubtitles] Auth Error (${e.response?.statusCode}): ${e.response?.data}. Retrying with fresh login...",
            );
          }
          _token = null;
          _tokenExpiry = null;
          await _loginIfNeeded();

          // Refresh headers with new token
          final Map<String, String> retryHeaders = {
            ...SubtitleProvider.commonHeaders,
            'user-agent': _userAgent,
            'Api-Key': _effectiveApiKey,
          };
          if (_token != null) {
            retryHeaders['Authorization'] = 'Bearer $_token';
          }

          final retryResponse = await _dio.get<dynamic>(
            "$baseUrl/subtitles",
            queryParameters: params,
            cancelToken: cancelToken,
            options: Options(headers: retryHeaders),
          );

          if (retryResponse.data == null ||
              retryResponse.data['data'] == null) {
            return [];
          }

          final List<dynamic> results = retryResponse.data['data'] as List;
          return results.map((dynamic item) {
            final attr = (item as Map)['attributes'] as Map<String, dynamic>;
            final files = attr['files'] as List;
            final file = files.isNotEmpty ? files.first as Map : null;
            return OnlineSubtitle(
              id: file != null
                  ? file['file_id'].toString()
                  : item['id'].toString(),
              name: (attr['release'] as String?) ?? query,
              language: (attr['language'] as String?) ?? langTag,
              source: name,
              downloadUrl: "",
              isHearingImpaired: (attr['hearing_impaired'] as bool?) ?? false,
              metadata: {'file_id': file != null ? file['file_id'] : null},
            );
          }).toList();
        }
        rethrow;
      }
    } catch (e) {
      if (e is! DioException || e.type != DioExceptionType.cancel) {
        if (kDebugMode) print("OpenSubtitles search failed: $e");
      }
      return [];
    }
  }

  @override
  Future<String?> getDownloadUrl(OnlineSubtitle subtitle) async {
    final fileId = subtitle.metadata?['file_id'];
    if (fileId == null) return null;

    try {
      await _loginIfNeeded();
      final Map<String, String> headers = {
        ...SubtitleProvider.commonHeaders,
        'user-agent': _userAgent,
        'Content-Type': 'application/json',
        'Api-Key': _effectiveApiKey,
      };
      if (_token != null) {
        headers['Authorization'] = 'Bearer $_token';
      }

      final response = await _dio.post<dynamic>(
        "$baseUrl/download",
        data: {'file_id': fileId},
        options: Options(headers: headers),
      );

      if (response.data != null && response.data?['link'] != null) {
        return response.data?['link'] as String?;
      }
    } catch (e) {
      if (kDebugMode) print("OpenSubtitles download failed: $e");
    }
    return null;
  }

  @override
  Map<String, String> getDownloadHeaders(OnlineSubtitle subtitle) {
    // OpenSubtitles download links are CDN URLs that don't need auth headers
    return SubtitleProvider.commonHeaders;
  }
}

/// Provider for SubDL.com.
class SubDLProvider extends SubtitleProvider {
  final Dio _dio;
  static const String baseUrl = "https://api.subdl.com/api/v1/subtitles";
  static const String downloadBaseUrl = "https://dl.subdl.com";
  static const String authUrl = "https://apiold.subdl.com";
  String? _apiKey;
  String? _email;
  String? _password;

  SubDLProvider(this._dio, {String? apiKey, String? email, String? password})
    : _apiKey = apiKey,
      _email = email,
      _password = password;

  String? get searchApiKey => _apiKey;

  @override
  String get name => "SubDL";

  @override
  String get idPrefix => "subdl";

  @override
  Future<List<OnlineSubtitle>> search({
    required String query,
    String? imdbId,
    int? tmdbId,
    int? season,
    int? episode,
    String? language,
    CancelToken? cancelToken,
  }) async {
    try {
      if (_apiKey == null || _apiKey!.isEmpty) {
        if (kDebugMode) print("[SubDL] Skipping search: API Key not set.");
        return [];
      }

      final String langCode = language ?? "en";
      final Map<String, dynamic> params = {
        'api_key': _apiKey!,
        'languages': langCode,
      };

      if (imdbId != null) {
        params['imdb_id'] = imdbId.startsWith('tt') ? imdbId : 'tt$imdbId';
      } else if (tmdbId != null) {
        params['tmdb_id'] = tmdbId;
      } else {
        params['film_name'] = query;
      }

      if (season != null && season > 0) params['season_number'] = season;
      if (episode != null && episode > 0) params['episode_number'] = episode;

      if (kDebugMode) {
        final maskedKey = _apiKey!.length > 5
            ? "${_apiKey!.substring(0, 5)}..."
            : "None";
        print(
          "[SubDL] Search: query=$query, imdb=$imdbId, lang=$langCode (Key: $maskedKey)",
        );
      }

      final response = await _dio.get<dynamic>(
        baseUrl,
        queryParameters: params,
        cancelToken: cancelToken,
        options: Options(
          headers: SubtitleProvider.commonHeaders,
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.data == null || response.data['status'] != true) return [];

      final List<dynamic> data =
          (response.data['subtitles'] as List?) ?? const <dynamic>[];
      if (kDebugMode) debugPrint("[SubDL] Found ${data.length} results.");

      return data.map((dynamic item) {
        final map = item as Map<String, dynamic>;
        final String rawUrl = (map['url'] as String?) ?? "";
        // SubDL returns relative paths like /subtitle/123.zip
        // Must prepend the download CDN base URL
        final String fullUrl = rawUrl.isNotEmpty
            ? "$downloadBaseUrl${rawUrl.startsWith('/') ? rawUrl : '/$rawUrl'}"
            : "";
        return OnlineSubtitle(
          id: map['id'].toString(),
          name:
              (map['release_name'] as String?) ??
              (map['fileName'] as String?) ??
              query,
          language: (map['language'] as String?) ?? langCode,
          source: name,
          downloadUrl: fullUrl,
          isHearingImpaired: map['hi'] == 1,
          metadata: {'url': fullUrl},
        );
      }).toList();
    } catch (e) {
      if (e is! DioException || e.type != DioExceptionType.cancel) {
        if (kDebugMode) debugPrint("SubDL search error: $e");
      }
      return [];
    }
  }

  @override
  Future<String?> getDownloadUrl(OnlineSubtitle subtitle) async {
    return subtitle.metadata?['url'] as String?;
  }

  @override
  Map<String, String> getDownloadHeaders(OnlineSubtitle subtitle) {
    return SubtitleProvider.commonHeaders;
  }

  /// Verifies if the API key is valid by performing a dummy search.
  Future<bool> verifyKey() async {
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      try {
        final response = await _dio.get<dynamic>(
          baseUrl,
          queryParameters: {
            'api_key': _apiKey!,
            'film_name': 'Inception',
            'languages': 'en',
          },
          options: Options(headers: SubtitleProvider.commonHeaders),
        );
        final bool isValid =
            response.data != null && response.data?['status'] == true;
        if (kDebugMode && !isValid) {
          debugPrint(
            "[SubDL] Key Verification Failed: ${response.statusCode} - ${response.data}",
          );
        }
        return isValid;
      } catch (e) {
        if (kDebugMode) {
          if (e is DioException) {
            print(
              "[SubDL] Key Verification Error: ${e.response?.statusCode} - ${e.response?.data}",
            );
          } else {
            print("[SubDL] Key Verification Exception: $e");
          }
        }
        // Fall through to login if key fails
      }
    }

    if (_email != null && _password != null) {
      return (await login(_email!, _password!)).key != null;
    }

    return false;
  }

  /// Authenticats with SubDL using Email/Password and fetches the user's API key.

  Future<({String? key, String? error})> login(
    String email,
    String password,
  ) async {
    try {
      if (kDebugMode) print("[SubDL] Logging in for: $email");

      // 1. Post to login
      final loginResponse = await _dio.post<Map<String, dynamic>>(
        "$authUrl/login",
        data: {'email': email, 'password': password},
      );

      if (kDebugMode) {
        print("[SubDL] Login Status: ${loginResponse.statusCode}");
      }

      if (loginResponse.data == null || loginResponse.data?['token'] == null) {
        final errorMsg =
            loginResponse.data?['error'] ?? "Login failed. Check credentials.";
        if (kDebugMode) print("[SubDL] Auth failed: $errorMsg");
        return (key: null as String?, error: errorMsg as String?);
      }

      final String jwtToken = loginResponse.data?['token'] as String;

      // 2. Fetch API Key
      final apiResponse = await _dio.get<Map<String, dynamic>>(
        "$authUrl/user/userApi",
        options: Options(
          headers: {
            'Authorization': 'Bearer $jwtToken',
            'Accept': 'application/json',
          },
        ),
      );

      if (apiResponse.data != null && apiResponse.data?['api_key'] != null) {
        _apiKey = apiResponse.data?['api_key'] as String?;
        _email = email;
        _password = password;
        if (kDebugMode) {
          print(
            "[SubDL] Login Success: API Key fetched: ${_apiKey!.substring(0, 5)}...",
          );
        }
        return (key: _apiKey, error: null);
      }
    } catch (e) {
      if (kDebugMode) {
        if (e is DioException) {
          final msg =
              e.response?.data?['error'] ??
              "Network error: ${e.response?.statusCode}";
          print("[SubDL] Fetch error: $msg");
          return (key: null as String?, error: msg as String?);
        } else {
          print("[SubDL] Login exception: $e");
          return (key: null as String?, error: e.toString() as String?);
        }
      }
    }
    return (key: null as String?, error: "Authentication failed." as String?);
  }
}

/// Provider for SubSource.net.
/// Supports dual-mode: keyless (CloudStream style) and authenticated (v1).
class SubSourceProvider extends SubtitleProvider {
  final Dio _dio;
  static const String baseUrlV1 = "https://api.subsource.net/api/v1";
  static const String baseUrlKeyless = "https://api.subsource.net/api";
  final String? _apiKey;

  SubSourceProvider(this._dio, {String? apiKey}) : _apiKey = apiKey;

  @override
  String get name => "SubSource";

  @override
  String get idPrefix => "subsource";

  String _parseString(dynamic value, String defaultValue) {
    if (value == null) return defaultValue;
    if (value is String) return value;
    if (value is Iterable && value.isNotEmpty) return value.first.toString();
    return value.toString();
  }

  @override
  Future<List<OnlineSubtitle>> search({
    required String query,
    String? imdbId,
    int? tmdbId,
    int? season,
    int? episode,
    String? language,
    CancelToken? cancelToken,
  }) async {
    // If API key is provided, use the v1 authenticated logic (Mode B)
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      return _searchV1(
        query: query,
        imdbId: imdbId,
        season: season,
        episode: episode,
        language: language,
        cancelToken: cancelToken,
      );
    }

    // Otherwise, use the keyless CloudStream-style logic (Mode A)
    return _searchKeyless(
      query: query,
      imdbId: imdbId,
      season: season,
      episode: episode,
      language: language,
      cancelToken: cancelToken,
    );
  }

  /// Original v1 implementation for authenticated users.
  Future<List<OnlineSubtitle>> _searchV1({
    required String query,
    String? imdbId,
    int? season,
    int? episode,
    String? language,
    CancelToken? cancelToken,
  }) async {
    if (kDebugMode) {
      final logKey = (_apiKey != null && _apiKey!.length > 5)
          ? "${_apiKey!.substring(0, 5)}..."
          : "None";
      print(
        "[SubSource V1] Search Start: query=$query, imdb=$imdbId (User Key: $logKey)",
      );
    }

    try {
      final Map<String, dynamic> searchParams = {};
      if (imdbId != null) {
        searchParams['searchType'] = 'imdb';
        searchParams['imdb'] = imdbId.startsWith('tt') ? imdbId : 'tt$imdbId';
      } else {
        searchParams['searchType'] = 'text';
        searchParams['q'] = query;
      }

      final searchResponse = await _dio.get<Map<String, dynamic>>(
        "$baseUrlV1/movies/search",
        queryParameters: searchParams,
        cancelToken: cancelToken,
        options: Options(
          headers: {...SubtitleProvider.commonHeaders, 'X-API-Key': _apiKey!},
        ),
      );

      if (searchResponse.data == null || searchResponse.data?['data'] == null) {
        return [];
      }
      final List<dynamic> movies = searchResponse.data?['data'] as List? ?? [];
      if (movies.isEmpty) return [];

      final movie = movies.first;
      final movieId = movie['movieId'] ?? movie['id'];

      final Map<String, dynamic> subParams = {'movieId': movieId};
      if (language != null) {
        subParams['language'] = _getLanguageFull(language);
      }

      final subsResponse = await _dio.get<Map<String, dynamic>>(
        "$baseUrlV1/subtitles",
        queryParameters: subParams,
        cancelToken: cancelToken,
        options: Options(
          headers: {...SubtitleProvider.commonHeaders, 'X-API-Key': _apiKey!},
        ),
      );

      final data = subsResponse.data?['data'];
      final List<dynamic> subs = (data is Map && data['results'] != null)
          ? data['results'] as List<dynamic>
          : (data is List ? data : const <dynamic>[]);

      final results = subs.map((s) {
        final subId = s['subtitleId'] ?? s['id'];
        final subName = _parseString(
          s['releaseInfo'] ?? s['release_name'] ?? s['file_name'],
          query,
        );
        final subLang = _parseString(s['language'], language ?? "Unknown");

        return OnlineSubtitle(
          id: subId.toString(),
          name: subName,
          language: subLang,
          source: name,
          downloadUrl: "$baseUrlV1/subtitles/$subId/download",
          isHearingImpaired: s['hearingImpaired'] == true || s['hi'] == 1,
          metadata: {'id': subId, 'mode': 'v1'},
        );
      }).toList();

      if (kDebugMode) {
        debugPrint("[SubSource V1] Found ${results.length} results.");
      }
      return results;
    } catch (e) {
      if (e is! DioException || e.type != DioExceptionType.cancel) {
        if (kDebugMode) print("[SubSource V1] Search error: $e");
      }
      return [];
    }
  }

  /// Keyless CloudStream-style implementation.
  Future<List<OnlineSubtitle>> _searchKeyless({
    required String query,
    String? imdbId,
    int? season,
    int? episode,
    String? language,
    CancelToken? cancelToken,
  }) async {
    // Improved over CloudStream: Allow fallback to title search if IMDb is null
    final String searchStr = imdbId ?? query;
    if (searchStr.isEmpty) {
      if (kDebugMode) {
        print(
          "[SubSource Keyless] Skipping search: Query or IMDb ID required.",
        );
      }
      return [];
    }

    if (kDebugMode) {
      final logMode = imdbId != null ? "IMDb" : "Title Fallback";
      print("[SubSource Keyless] Search Start: $searchStr (Mode: $logMode)");
    }

    try {
      final String imdbOrTitle = (imdbId != null)
          ? (imdbId.startsWith('tt') ? imdbId : 'tt$imdbId')
          : query;
      final String queryLang = _getLanguageFull(language ?? "en");

      // 1. Search for movie internal linkName
      final searchResponse = await _dio.post<Map<String, dynamic>>(
        "$baseUrlKeyless/searchMovie",
        data: {'query': imdbOrTitle},
        cancelToken: cancelToken,
        options: Options(
          headers: {
            ...SubtitleProvider.commonHeaders,
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36',
            'Referer': 'https://subsource.net/',
            'Origin': 'https://subsource.net/',
          },
        ),
      );

      if (searchResponse.data == null ||
          searchResponse.data?['success'] != true) {
        return [];
      }
      final List<dynamic> found = searchResponse.data?['found'] as List? ?? [];
      if (found.isEmpty) return [];

      final String linkName = (found.first['linkName'] as String?) ?? "";
      if (linkName.isEmpty) return [];

      // 2. Get movie subtitles
      final Map<String, dynamic> postData = {
        'langs': '[]',
        'movieName': linkName,
      };
      if (season != null && season > 0) {
        postData['season'] = "season-$season";
      }

      final movieResponse = await _dio.post<Map<String, dynamic>>(
        "$baseUrlKeyless/getMovie",
        data: postData,
        cancelToken: cancelToken,
        options: Options(
          headers: {
            ...SubtitleProvider.commonHeaders,
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36',
            'Referer': 'https://subsource.net/',
            'Origin': 'https://subsource.net/',
          },
        ),
      );

      if (movieResponse.data == null ||
          movieResponse.data?['success'] != true) {
        return [];
      }
      final List<dynamic> subs = movieResponse.data?['subs'] as List? ?? [];

      // API doesn't filter by episode/lang, so we filter manually like CloudStream
      final filteredSubs = subs.where((s) {
        final String lang = (s['lang'] ?? "").toString().toLowerCase();
        final String release = (s['releaseName'] ?? "").toString();

        final matchesLang = lang == queryLang.toLowerCase();
        if (episode != null && episode > 0) {
          final epTag = "E${episode.toString().padLeft(2, '0')}";
          return matchesLang && release.contains(epTag);
        }
        return matchesLang;
      }).toList();

      final results = filteredSubs.map((s) {
        final subId = s['subId'] ?? s['id'];
        return OnlineSubtitle(
          id: subId.toString(),
          name:
              (s['releaseName'] as String?) ??
              (s['file_name'] as String?) ??
              query,
          language: (s['lang'] as String?) ?? "Unknown",
          source: name,
          downloadUrl: "", // Requires getDownloadUrl for keyless
          isHearingImpaired: s['hi'] == 1,
          metadata: {
            'id': subId,
            'movie': linkName,
            'lang': s['lang'],
            'mode': 'keyless',
          },
        );
      }).toList();

      if (kDebugMode) {
        print("[SubSource Keyless] Found ${results.length} results.");
      }
      return results;
    } catch (e) {
      if (e is! DioException || e.type != DioExceptionType.cancel) {
        if (kDebugMode) print("[SubSource Keyless] Search error: $e");
      }
      return [];
    }
  }

  @override
  Future<String?> getDownloadUrl(OnlineSubtitle subtitle) async {
    final mode = subtitle.metadata?['mode'] ?? 'v1';
    final id = subtitle.metadata?['id'];

    if (mode == 'v1') {
      return subtitle.downloadUrl;
    }

    // Keyless Download Flow
    final movie = subtitle.metadata?['movie'];
    final lang = subtitle.metadata?['lang'];
    if (id == null || movie == null || lang == null) return null;

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        "$baseUrlKeyless/getSub",
        data: {'movie': movie, 'lang': lang, 'id': id},
        options: Options(
          headers: {
            ...SubtitleProvider.commonHeaders,
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36',
            'Referer': 'https://subsource.net/',
            'Origin': 'https://subsource.net/',
          },
        ),
      );

      if (response.data != null && response.data?['sub'] != null) {
        final String? token =
            response.data?['sub']?['downloadToken'] as String?;
        if (token != null) {
          return "$baseUrlKeyless/downloadSub/$token";
        }
      }
    } catch (e) {
      if (kDebugMode) print("[SubSource Keyless] Download failed: $e");
    }
    return null;
  }

  /// Browser-mimicking headers for keyless SubSource
  static const Map<String, String> _keylessBrowserHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36',
    'Referer': 'https://subsource.net/',
    'Origin': 'https://subsource.net/',
    'Accept': '*/*',
  };

  @override
  Map<String, String> getDownloadHeaders(OnlineSubtitle subtitle) {
    final mode = subtitle.metadata?['mode'] ?? 'v1';
    if (mode == 'keyless') {
      return _keylessBrowserHeaders;
    }
    // V1 mode needs the API key
    return {
      ...SubtitleProvider.commonHeaders,
      if (_apiKey != null && _apiKey!.isNotEmpty) 'X-API-Key': _apiKey!,
    };
  }

  /// Helper to convert language tag to full English name.
  String _getLanguageFull(String tag) {
    const Map<String, String> langMap = {
      'en': 'english',
      'hi': 'hindi',
      'te': 'telugu',
      'ta': 'tamil',
      'ml': 'malayalam',
      'kn': 'kannada',
      'bn': 'bengali',
      'mr': 'marathi',
      'gu': 'gujarati',
      'pa': 'punjabi',
      'ar': 'arabic',
      'as': 'assamese',
      'be': 'belarusian',
      'bg': 'bulgarian',
      'cs': 'czech',
      'de': 'german',
      'el': 'greek',
      'es': 'spanish',
      'fi': 'finnish',
      'fr': 'french',
      'he': 'hebrew',
      'hr': 'croatian',
      'hu': 'hungarian',
      'id': 'indonesian',
      'it': 'italian',
      'ja': 'japanese',
      'ko': 'korean',
      'lv': 'latvian',
      'mk': 'macedonian',
      'nl': 'dutch',
      'pl': 'polish',
      'pt': 'portuguese',
      'ro': 'romanian',
      'ru': 'russian',
      'sv': 'swedish',
      'tr': 'turkish',
      'uk': 'ukrainian',
      'ur': 'urdu',
      'vi': 'vietnamese',
      'zh': 'chinese',
    };
    return langMap[tag.toLowerCase()] ?? tag.toLowerCase();
  }

  /// Verifies if the API key is valid (for v1) or if the endpoint is reachable (for keyless).
  Future<bool> verifyKey() async {
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      if (kDebugMode) {
        final maskedKey = _apiKey!.length > 5
            ? "${_apiKey!.substring(0, 5)}..."
            : "None";
        print("[SubSource V1] Verifying User Key: $maskedKey");
      }
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          "$baseUrlV1/movies/search",
          queryParameters: {'searchType': 'text', 'q': 'Inception'},
          options: Options(
            headers: {...SubtitleProvider.commonHeaders, 'X-API-Key': _apiKey},
          ),
        );
        if (kDebugMode && response.statusCode != 200) {
          debugPrint(
            "[SubSource V1] Verification Failed: ${response.statusCode} - ${response.data}",
          );
        }
        return response.statusCode == 200;
      } catch (e) {
        if (kDebugMode) {
          if (e is DioException) {
            print(
              "[SubSource V1] Verification Error: ${e.response?.statusCode} - ${e.response?.data}",
            );
          } else {
            print("[SubSource V1] Verification Exception: $e");
          }
        }
        return false;
      }
    } else {
      // Keyless verification: Just a connectivity check to searchMovie
      if (kDebugMode) {
        print(
          "[SubSource Keyless] Verifying Connectivity (Mode: CloudStream-style)...",
        );
      }
      try {
        final response = await _dio.post<dynamic>(
          "$baseUrlKeyless/searchMovie",
          data: {'query': 'tt0133093'}, // The Matrix
          options: Options(
            headers: {
              ...SubtitleProvider.commonHeaders,
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36',
              'Referer': 'https://subsource.net/',
              'Origin': 'https://subsource.net/',
            },
          ),
        );
        return response.statusCode == 200;
      } catch (e) {
        return false;
      }
    }
  }
}
