import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../network/dio_client_provider.dart';
import '../../storage/secure_token_storage.dart';

part 'debrid_service.g.dart';

/// Debrid providers SkyStream can unrestrict torrents through.
enum DebridProvider {
  none('None', ''),
  realDebrid('Real-Debrid', 'real-debrid'),
  allDebrid('AllDebrid', 'alldebrid');

  const DebridProvider(this.label, this.id);
  final String label;
  final String id;

  static DebridProvider fromId(String? id) {
    for (final provider in DebridProvider.values) {
      if (provider.id == id) return provider;
    }
    return DebridProvider.none;
  }
}

class DebridConfig {
  final DebridProvider provider;
  final String apiKey;
  final String? username;
  final bool isLoading;
  final String? error;

  const DebridConfig({
    this.provider = DebridProvider.none,
    this.apiKey = '',
    this.username,
    this.isLoading = true,
    this.error,
  });

  bool get isConfigured =>
      provider != DebridProvider.none && apiKey.trim().isNotEmpty;

  DebridConfig copyWith({
    DebridProvider? provider,
    String? apiKey,
    String? username,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearUsername = false,
  }) {
    return DebridConfig(
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      username: clearUsername ? null : (username ?? this.username),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Stores the debrid credentials in the platform secure store (Keychain /
/// Keystore / Credential Manager), like the tracker OAuth tokens.
@Riverpod(keepAlive: true)
class DebridSettings extends _$DebridSettings {
  static const String _providerKey = 'debrid_provider';
  static const String _apiKeyKey = 'debrid_api_key';
  static const String _usernameKey = 'debrid_username';

  @override
  DebridConfig build() {
    Future.microtask(load);
    return const DebridConfig();
  }

  Future<void> load() async {
    try {
      final storage = ref.read(secureTokenStorageProvider);
      final provider = DebridProvider.fromId(await storage.read(_providerKey));
      final apiKey = await storage.read(_apiKeyKey) ?? '';
      final username = await storage.read(_usernameKey);
      state = DebridConfig(
        provider: provider,
        apiKey: apiKey,
        username: username,
        isLoading: false,
      );
    } catch (error) {
      state = DebridConfig(isLoading: false, error: error.toString());
    }
  }

  /// Saves and verifies a key. Returns the account name on success.
  Future<String?> save(DebridProvider provider, String apiKey) async {
    final storage = ref.read(secureTokenStorageProvider);
    final trimmed = apiKey.trim();

    if (provider == DebridProvider.none || trimmed.isEmpty) {
      await clear();
      return null;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final username = await ref
          .read(debridServiceProvider)
          .verify(provider: provider, apiKey: trimmed);

      await storage.write(_providerKey, provider.id);
      await storage.write(_apiKeyKey, trimmed);
      if (username != null) await storage.write(_usernameKey, username);

      state = DebridConfig(
        provider: provider,
        apiKey: trimmed,
        username: username,
        isLoading: false,
      );
      return username;
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
      rethrow;
    }
  }

  Future<void> clear() async {
    final storage = ref.read(secureTokenStorageProvider);
    await storage.delete(_providerKey);
    await storage.delete(_apiKeyKey);
    await storage.delete(_usernameKey);
    state = const DebridConfig(isLoading: false);
  }
}

class DebridException implements Exception {
  final String message;
  const DebridException(this.message);
  @override
  String toString() => message;
}

/// A link that is ready to hand to the player.
class DebridLink {
  final String url;
  final String? filename;
  final int? sizeBytes;

  const DebridLink({required this.url, this.filename, this.sizeBytes});
}

@Riverpod(keepAlive: true)
DebridService debridService(Ref ref) => DebridService(ref);

/// Turns torrents into direct HTTPS links through the user's debrid account.
///
/// This is the client-side path: add-ons that already have a debrid key baked
/// into their configured URL keep returning ready links and never reach this
/// code. When they don't, a magnet can still be unrestricted here — which is
/// what makes 4K torrents start instantly instead of waiting for peers.
class DebridService {
  DebridService(this._ref);

  final Ref _ref;

  static const String _rdBase = 'https://api.real-debrid.com/rest/1.0';
  static const String _adBase = 'https://api.alldebrid.com/v4';
  static const Duration _timeout = Duration(seconds: 20);

  Dio get _dio => _ref.read(dioClientProvider);

  Options _options({Map<String, String>? headers}) => Options(
    headers: headers,
    receiveTimeout: _timeout,
    sendTimeout: _timeout,
    validateStatus: (status) => status != null && status < 500,
  );

  /// Confirms the key works and returns the account name.
  Future<String?> verify({
    required DebridProvider provider,
    required String apiKey,
  }) async {
    switch (provider) {
      case DebridProvider.realDebrid:
        final response = await _dio.get<dynamic>(
          '$_rdBase/user',
          options: _options(headers: {'Authorization': 'Bearer $apiKey'}),
        );
        final data = response.data;
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw const DebridException('Real-Debrid rejected that API key.');
        }
        if (data is Map) return data['username']?.toString();
        throw const DebridException('Unexpected Real-Debrid response.');

      case DebridProvider.allDebrid:
        final response = await _dio.get<dynamic>(
          '$_adBase/user',
          queryParameters: {'agent': 'skystream', 'apikey': apiKey},
          options: _options(),
        );
        final data = response.data;
        if (data is Map && data['status'] == 'success') {
          final user = (data['data'] as Map?)?['user'];
          if (user is Map) return user['username']?.toString();
          return null;
        }
        throw DebridException(
          _allDebridError(data) ?? 'AllDebrid rejected that API key.',
        );

      case DebridProvider.none:
        return null;
    }
  }

  static String? _allDebridError(dynamic data) {
    if (data is Map) {
      final error = data['error'];
      if (error is Map) return error['message']?.toString();
    }
    return null;
  }

  /// Picks the file a user actually wants out of a torrent: the largest video.
  /// Exposed for tests — season packs and sample files make this worth getting
  /// right.
  static int? pickBestFileId(
    List<Map<String, dynamic>> files, {
    String? preferredFilename,
  }) {
    const videoExtensions = [
      '.mkv',
      '.mp4',
      '.avi',
      '.mov',
      '.m4v',
      '.ts',
      '.webm',
    ];

    int? bestId;
    var bestSize = -1;

    for (final file in files) {
      final path = (file['path'] ?? file['filename'] ?? '').toString();
      final lower = path.toLowerCase();
      final id = (file['id'] as num?)?.toInt();
      final size = (file['bytes'] as num?)?.toInt() ?? 0;
      if (id == null) continue;
      if (!videoExtensions.any(lower.endsWith)) continue;
      if (lower.contains('sample')) continue;

      if (preferredFilename != null &&
          preferredFilename.isNotEmpty &&
          lower.endsWith(preferredFilename.toLowerCase())) {
        return id;
      }
      if (size > bestSize) {
        bestSize = size;
        bestId = id;
      }
    }
    return bestId;
  }

  /// Real-Debrid: add magnet → select the best file → wait for a cached
  /// torrent → unrestrict the resulting link.
  Future<DebridLink?> _resolveRealDebrid(
    String magnet,
    String apiKey, {
    String? preferredFilename,
    void Function(String status)? onStatus,
    Duration wait = const Duration(seconds: 25),
  }) async {
    final headers = {'Authorization': 'Bearer $apiKey'};

    onStatus?.call('Sending magnet to Real-Debrid…');
    final add = await _dio.post<dynamic>(
      '$_rdBase/torrents/addMagnet',
      data: FormData.fromMap({'magnet': magnet}),
      options: _options(headers: headers),
    );
    final addData = add.data;
    if (addData is! Map || addData['id'] == null) {
      throw const DebridException('Real-Debrid did not accept the magnet.');
    }
    final id = addData['id'].toString();

    onStatus?.call('Reading torrent contents…');
    final info = await _dio.get<dynamic>(
      '$_rdBase/torrents/info/$id',
      options: _options(headers: headers),
    );
    final files = <Map<String, dynamic>>[];
    final rawFiles = (info.data as Map?)?['files'];
    if (rawFiles is List) {
      for (final entry in rawFiles) {
        if (entry is Map) files.add(Map<String, dynamic>.from(entry));
      }
    }
    final fileId = pickBestFileId(files, preferredFilename: preferredFilename);

    await _dio.post<dynamic>(
      '$_rdBase/torrents/selectFiles/$id',
      data: FormData.fromMap({'files': fileId?.toString() ?? 'all'}),
      options: _options(headers: headers),
    );

    // Cached torrents flip to "downloaded" almost immediately; anything else
    // would mean waiting for Real-Debrid to fetch the whole file, so give up
    // and let the caller fall back to peer-to-peer streaming.
    final deadline = DateTime.now().add(wait);
    while (DateTime.now().isBefore(deadline)) {
      final poll = await _dio.get<dynamic>(
        '$_rdBase/torrents/info/$id',
        options: _options(headers: headers),
      );
      final data = poll.data;
      if (data is Map) {
        final status = data['status']?.toString() ?? '';
        final progress = (data['progress'] as num?)?.toDouble() ?? 0;
        if (status == 'downloaded') {
          final links = data['links'];
          if (links is List && links.isNotEmpty) {
            onStatus?.call('Unlocking direct link…');
            return _unrestrictRealDebrid(links.first.toString(), apiKey);
          }
        }
        if (status == 'magnet_error' ||
            status == 'error' ||
            status == 'virus' ||
            status == 'dead') {
          throw const DebridException(
            'Real-Debrid could not fetch this torrent.',
          );
        }
        onStatus?.call('Real-Debrid: $status ${progress.toStringAsFixed(0)}%');
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }

    // Not cached — leave the torrent in the account and fall back.
    return null;
  }

  Future<DebridLink?> _unrestrictRealDebrid(String link, String apiKey) async {
    final response = await _dio.post<dynamic>(
      '$_rdBase/unrestrict/link',
      data: FormData.fromMap({'link': link}),
      options: _options(headers: {'Authorization': 'Bearer $apiKey'}),
    );
    final data = response.data;
    if (data is Map && data['download'] != null) {
      return DebridLink(
        url: data['download'].toString(),
        filename: data['filename']?.toString(),
        sizeBytes: (data['filesize'] as num?)?.toInt(),
      );
    }
    return null;
  }

  /// AllDebrid: upload magnet → poll status → unlock the best link.
  Future<DebridLink?> _resolveAllDebrid(
    String magnet,
    String apiKey, {
    void Function(String status)? onStatus,
    Duration wait = const Duration(seconds: 25),
  }) async {
    final query = {'agent': 'skystream', 'apikey': apiKey};

    onStatus?.call('Sending magnet to AllDebrid…');
    final upload = await _dio.get<dynamic>(
      '$_adBase/magnet/upload',
      queryParameters: {...query, 'magnets[]': magnet},
      options: _options(),
    );
    final uploadData = upload.data;
    if (uploadData is! Map || uploadData['status'] != 'success') {
      throw DebridException(
        _allDebridError(uploadData) ?? 'AllDebrid did not accept the magnet.',
      );
    }
    final magnets = (uploadData['data'] as Map?)?['magnets'];
    final magnetId = magnets is List && magnets.isNotEmpty
        ? (magnets.first as Map)['id']?.toString()
        : null;
    if (magnetId == null) {
      throw const DebridException('AllDebrid returned no magnet id.');
    }

    final deadline = DateTime.now().add(wait);
    while (DateTime.now().isBefore(deadline)) {
      final status = await _dio.get<dynamic>(
        '$_adBase/magnet/status',
        queryParameters: {...query, 'id': magnetId},
        options: _options(),
      );
      final link = parseAllDebridReadyLink(status.data);
      if (link != null) {
        onStatus?.call('Unlocking direct link…');
        final unlock = await _dio.get<dynamic>(
          '$_adBase/link/unlock',
          queryParameters: {...query, 'link': link},
          options: _options(),
        );
        final data = unlock.data;
        if (data is Map && data['status'] == 'success') {
          final payload = data['data'];
          if (payload is Map && payload['link'] != null) {
            return DebridLink(
              url: payload['link'].toString(),
              filename: payload['filename']?.toString(),
              sizeBytes: (payload['filesize'] as num?)?.toInt(),
            );
          }
        }
        return null;
      }
      onStatus?.call('AllDebrid: preparing…');
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return null;
  }

  /// Extracts the largest ready video link from an AllDebrid status payload.
  /// Pure — unit tested.
  static String? parseAllDebridReadyLink(dynamic data) {
    if (data is! Map || data['status'] != 'success') return null;
    final magnets = (data['data'] as Map?)?['magnets'];
    final magnet = magnets is List
        ? (magnets.isEmpty ? null : magnets.first)
        : magnets;
    if (magnet is! Map) return null;
    if ((magnet['status']?.toString().toLowerCase() ?? '') != 'ready') {
      return null;
    }
    final links = magnet['links'];
    if (links is! List || links.isEmpty) return null;

    String? best;
    var bestSize = -1;
    for (final entry in links) {
      if (entry is! Map) continue;
      final link = entry['link']?.toString();
      if (link == null || link.isEmpty) continue;
      final size = (entry['size'] as num?)?.toInt() ?? 0;
      final name = (entry['filename'] ?? '').toString().toLowerCase();
      if (name.contains('sample')) continue;
      if (size > bestSize) {
        bestSize = size;
        best = link;
      }
    }
    return best;
  }

  /// Resolves a magnet into a direct link, or `null` when the torrent is not
  /// cached (the caller then falls back to peer-to-peer streaming).
  Future<DebridLink?> resolveMagnet(
    String magnet, {
    String? preferredFilename,
    void Function(String status)? onStatus,
  }) async {
    final config = _ref.read(debridSettingsProvider);
    if (!config.isConfigured) return null;

    try {
      switch (config.provider) {
        case DebridProvider.realDebrid:
          return await _resolveRealDebrid(
            magnet,
            config.apiKey,
            preferredFilename: preferredFilename,
            onStatus: onStatus,
          );
        case DebridProvider.allDebrid:
          return await _resolveAllDebrid(
            magnet,
            config.apiKey,
            onStatus: onStatus,
          );
        case DebridProvider.none:
          return null;
      }
    } catch (error) {
      if (kDebugMode) debugPrint('[DebridService] $error');
      rethrow;
    }
  }
}
