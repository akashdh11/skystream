import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';
import '../domain/entity/multimedia_item.dart';

part 'storage_service.g.dart';

@Riverpod(keepAlive: true)
StorageService storageService(Ref ref) {
  throw UnimplementedError('StorageService must be initialized');
}

class StorageService {
  late Box<dynamic> _libraryBox;
  late Box<dynamic> _settingsBox;
  late Box<dynamic> _extensionsBox;
  late Box<dynamic> _historyBox;

  static const String kLibraryBox = 'library_box';
  static const String kSettingsBox = 'settings_box';
  static const String kExtensionsBox = 'extension_data_box';
  static const String kDownloadMetadataBox = 'download_metadata_box';

  Future<void> init() async {
    final supportDir = await getApplicationSupportDirectory();
    Hive.init(supportDir.path);

    _libraryBox = await _safeOpenBox(kLibraryBox);
    _settingsBox = await _safeOpenBox(kSettingsBox);
    _extensionsBox = await _safeOpenBox(kExtensionsBox);
    await _safeOpenBox(
      kDownloadMetadataBox,
    ); // Open but no need to keep late reference if we use Hive.box()
    await initHistory();
  }

  Future<Box<dynamic>> _safeOpenBox(String boxName) async {
    try {
      return await Hive.openBox<dynamic>(boxName);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          "Error opening Hive box '$boxName': $e. Attempting recovery before deleting...",
        );
      }

      // Attempt to salvage any readable entries before wiping the box.
      final Map<dynamic, dynamic> salvaged = {};
      try {
        final recoveryBox = await Hive.openBox<dynamic>(
          boxName,
          crashRecovery: true,
        );
        for (var i = 0; i < recoveryBox.length; i++) {
          final key = recoveryBox.keyAt(i);
          salvaged[key] = recoveryBox.get(key);
        }
        await recoveryBox.close();
      } catch (_) {
        // Box is unreadable even with crash recovery — salvaged stays empty.
      }

      try {
        await Hive.deleteBoxFromDisk(boxName);
      } catch (_) {}

      final fresh = await Hive.openBox<dynamic>(boxName);

      // Re-insert recovered entries.
      if (salvaged.isNotEmpty) {
        await fresh.putAll(salvaged);
        if (kDebugMode) {
          debugPrint(
            "Hive box '$boxName': recovered ${salvaged.length} entries after corruption.",
          );
        }
      }

      return fresh;
    }
  }

  /// Helper to ensure keys do not exceed Hive's 255 char limit.
  /// Generates a stable hash for long URLs.
  String _getKey(String url) {
    if (url.length <= 250) return url;
    return md5.convert(utf8.encode(url)).toString();
  }

  // --- Library (Favorites) ---

  // We store items as JSON strings or Maps. Key is url.
  Future<void> addToLibrary(MultimediaItem item) async {
    // We assume item.url is unique enough for now
    await _libraryBox.put(_getKey(item.url), {
      'title': item.title,
      'url': item.url,
      'posterUrl': item.posterUrl,
      'bannerUrl': item.bannerUrl,
      'description': item.description,
      'type': item.contentType.name,
      'provider': item.provider,
    });
  }

  Future<void> removeFromLibrary(String url) async {
    await _libraryBox.delete(_getKey(url));
  }

  bool isInLibrary(String url) {
    return _libraryBox.containsKey(_getKey(url));
  }

  List<MultimediaItem> getLibraryItems() {
    final items = <MultimediaItem>[];
    for (var i = 0; i < _libraryBox.length; i++) {
      final key = _libraryBox.keyAt(i);
      final map = Map<String, dynamic>.from(_libraryBox.get(key) as Map);
      items.add(
        MultimediaItem(
          title: (map['title'] as String?) ?? '',
          url: (map['url'] as String?) ?? '',
          posterUrl: (map['posterUrl'] as String?) ?? '',
          bannerUrl: map['bannerUrl'] as String?,
          description: map['description'] as String?,
          contentType: MultimediaItem.parseContentType(
            (map['type'] as String?) ?? (map['contentType'] as String?),
          ),
          provider: map['provider'] as String?,
        ),
      );
    }
    return items;
  }

  // --- Settings ---

  Future<void> saveThemeMode(String mode) async {
    await _settingsBox.put('theme_mode', mode);
  }

  String? getThemeMode() {
    return _settingsBox.get('theme_mode') as String?;
  }

  // --- Sidebar State ---
  Future<void> setSidebarExpanded(bool expanded) async {
    await _settingsBox.put('sidebar_expanded', expanded);
  }

  bool? getSidebarExpanded() {
    return _settingsBox.get('sidebar_expanded') as bool?;
  }

  Future<void> setDefaultHomeScreen(String path) async {
    await _settingsBox.put('default_home_screen', path);
  }

  String getDefaultHomeScreen() {
    return _settingsBox.get('default_home_screen', defaultValue: '/home')
        as String;
  }

  Future<void> setDownloadDirectory(String? path) async {
    if (path == null || path.trim().isEmpty) {
      await _settingsBox.delete('download_directory');
    } else {
      await _settingsBox.put('download_directory', path);
    }
  }

  String? getDownloadDirectory() {
    return _settingsBox.get('download_directory') as String?;
  }

  Future<void> setDownloadConcurrency(int value) async {
    await _settingsBox.put('download_concurrency', value.clamp(1, 10));
  }

  int getDownloadConcurrency() {
    return (_settingsBox.get('download_concurrency', defaultValue: 3) as int)
        .clamp(1, 10);
  }

  Future<void> setDownloadChunks(int value) async {
    await _settingsBox.put('download_chunks', value.clamp(1, 8));
  }

  int getDownloadChunks() {
    return (_settingsBox.get('download_chunks', defaultValue: 1) as int).clamp(
      1,
      8,
    );
  }

  Future<void> setTitlePosition(String position) async {
    await _settingsBox.put('title_position', position);
  }

  String getTitlePosition() {
    return (_settingsBox.get('title_position', defaultValue: 'below')
            as String?) ??
        'below';
  }

  Future<void> setDevLoadAssets(bool enabled) async {
    await _settingsBox.put('dev_load_assets', enabled);
  }

  bool getDevLoadAssets() {
    return _settingsBox.get('dev_load_assets', defaultValue: false) as bool;
  }

  // --- Active Provider ---

  Future<void> setActiveProviderId(String? id) async {
    await _settingsBox.put('active_provider_id', id ?? '__NONE__');
  }

  String? getActiveProviderId() {
    final id = _settingsBox.get('active_provider_id') as String?;
    if (id == null || id == '__NONE__') return null;
    return id;
  }

  // --- Home Category Persistence ---

  Future<void> setHomeCategory(String? category) async {
    await _settingsBox.put('home_category_filter', category);
  }

  String? getHomeCategory() {
    return _settingsBox.get('home_category_filter') as String?;
  }

  // --- Extension Persistence ---

  Future<void> setExtensionData(String key, String? value) async {
    if (value == null) {
      await _extensionsBox.delete(key);
    } else {
      await _extensionsBox.put(key, value);
    }
  }

  String? getExtensionData(String key) {
    return _extensionsBox.get(key) as String?;
  }

  // --- Custom Plugin Overrides ---

  Future<void> setCustomBaseUrl(String packageName, String? url) async {
    final key = 'custom_base_url_$packageName';
    if (url == null) {
      await _settingsBox.delete(key);
    } else {
      await _settingsBox.put(key, url);
    }
  }

  String? getCustomBaseUrl(String packageName) {
    return _settingsBox.get('custom_base_url_$packageName') as String?;
  }

  // --- Language ---
  Future<void> setLanguage(String lang) async {
    await _settingsBox.put('language', lang);
  }

  String getLanguage() {
    return _settingsBox.get('language', defaultValue: 'en') as String;
  }

  Future<void> setExploreLanguage(String lang) async {
    await _settingsBox.put('explore_language', lang);
  }

  String getExploreLanguage() {
    return _settingsBox.get('explore_language', defaultValue: 'en-US')
        as String;
  }

  // --- Watch History Toggle ---
  Future<void> setWatchHistoryEnabled(bool enabled) async {
    await _settingsBox.put('watch_history_enabled', enabled);
  }

  bool isWatchHistoryEnabled() {
    return (_settingsBox.get('watch_history_enabled', defaultValue: true)
            as bool?) ??
        true;
  }

  // --- Window Settings ---
  Future<void> setAlwaysOnTop(bool enabled) async {
    await _settingsBox.put('always_on_top', enabled);
  }

  bool isAlwaysOnTop() {
    return (_settingsBox.get('always_on_top', defaultValue: false) as bool?) ??
        false;
  }

  // --- Network Settings ---
  Future<void> setGithubProxyEnabled(bool enabled) async {
    await _settingsBox.put('github_proxy_enabled', enabled);
  }

  bool isGithubProxyEnabled() {
    return (_settingsBox.get('github_proxy_enabled', defaultValue: false)
            as bool?) ??
        false;
  }

  // --- Integrations ---
  Future<void> setIntroDbIntegrationEnabled(bool enabled) async {
    await _settingsBox.put('introdb_integration_enabled', enabled);
  }

  bool isIntroDbIntegrationEnabled() {
    return (_settingsBox.get('introdb_integration_enabled', defaultValue: false)
            as bool?) ??
        false;
  }

  Future<void> setAnimeSkipIntegrationEnabled(bool enabled) async {
    await _settingsBox.put('animeskip_integration_enabled', enabled);
  }

  bool isAnimeSkipIntegrationEnabled() {
    return (_settingsBox.get(
              'animeskip_integration_enabled',
              defaultValue: false,
            )
            as bool?) ??
        false;
  }

  // --- Player Settings ---
  Future<void> setPlayerSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  T? getPlayerSetting<T>(String key, {T? defaultValue}) {
    return _settingsBox.get(key, defaultValue: defaultValue) as T?;
  }

  // --- General Key-Value ---
  Future<void> setString(String key, String? value) async {
    if (value == null) {
      await _settingsBox.delete(key);
    } else {
      await _settingsBox.put(key, value);
    }
  }

  String? getString(String key) {
    return _settingsBox.get(key) as String?;
  }

  Future<void> remove(String key) async {
    await _settingsBox.delete(key);
  }

  // --- Watch History ---

  static const String kHistoryBox = 'history_box';
  // Box late initialization is handled in init()
  List<Map<String, dynamic>>? _cachedHistory;
  bool _historyCacheDirty = true;

  Future<void> initHistory() async {
    _historyBox = await _safeOpenBox(kHistoryBox);
  }

  Future<void> saveProgress(
    MultimediaItem item,
    int positionMillis,
    int durationMillis, {
    String? lastStreamUrl,
    String? lastEpisodeUrl,
    int? season,
    int? episode,
    String? episodeTitle,
    String? episodePosterUrl,
  }) async {
    final entry = {
      'title': item.title,
      'url': item.url,
      'posterUrl': item.posterUrl,
      'bannerUrl': item.bannerUrl,
      'description': item.description,
      'contentType': item.contentType.name,
      'provider': item.provider,
      'tmdbId': item.tmdbId,
      'imdbId': item.imdbId,
      'position': positionMillis,
      'duration': durationMillis,
      'lastStreamUrl': lastStreamUrl,
      'lastEpisodeUrl': lastEpisodeUrl,
      'season': season,
      'episode': episode,
      'episodeTitle': episodeTitle,
      'episodePosterUrl': episodePosterUrl,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // Save main entry (keyed by series/movie URL)
    await _historyBox.put(_getKey(item.url), entry);

    // Save episode-specific progress for both series and anime.
    final isSeries =
        item.contentType == MultimediaContentType.series ||
        item.contentType == MultimediaContentType.anime;

    if (isSeries && lastEpisodeUrl != null) {
      final episodeKey = "EP_${_getKey(lastEpisodeUrl)}";
      await _historyBox.put(episodeKey, entry);
    }

    _historyCacheDirty = true;
  }

  Future<void> removeFromHistory(String url) async {
    final mainKey = _getKey(url);
    await _historyBox.delete(mainKey);

    // Cascade delete: find and remove all EP_ entries for this series
    final keysToDelete = <String>[];
    for (var i = 0; i < _historyBox.length; i++) {
      final key = _historyBox.keyAt(i) as String;
      if (key.startsWith("EP_")) {
        final entry = _historyBox.get(key);
        if (entry != null && entry['url'] == url) {
          keysToDelete.add(key);
        }
      }
    }

    for (final k in keysToDelete) {
      await _historyBox.delete(k);
    }

    _historyCacheDirty = true;
  }

  Future<void> updateHistoryItemTimestampAndPosition(
    String url,
    String? lastEpisodeUrl,
    int timestamp,
    int position,
  ) async {
    final mainKey = _getKey(url);
    final entry = _historyBox.get(mainKey);
    if (entry != null) {
      final updatedEntry = Map<String, dynamic>.from(entry as Map);
      updatedEntry['timestamp'] = timestamp;
      updatedEntry['position'] = position;
      await _historyBox.put(mainKey, updatedEntry);

      if (lastEpisodeUrl != null) {
        final episodeKey = "EP_${_getKey(lastEpisodeUrl)}";
        final epEntry = _historyBox.get(episodeKey);
        if (epEntry != null) {
          final updatedEpEntry = Map<String, dynamic>.from(epEntry as Map);
          updatedEpEntry['timestamp'] = timestamp;
          updatedEpEntry['position'] = position;
          await _historyBox.put(episodeKey, updatedEpEntry);
        }
      }
      _historyCacheDirty = true;
    }
  }

  Future<void> clearAllHistory() async {
    await _historyBox.clear();
    _historyCacheDirty = true;
  }

  List<Map<String, dynamic>> getWatchHistory() {
    if (!_historyCacheDirty && _cachedHistory != null) {
      return _cachedHistory!;
    }

    final items = <Map<String, dynamic>>[];
    for (var i = 0; i < _historyBox.length; i++) {
      final key = _historyBox.keyAt(i) as String;
      // Filter out episode-specific entries from the main history list
      if (key.startsWith("EP_")) continue;

      final map = Map<String, dynamic>.from(_historyBox.get(key) as Map);
      items.add(map);
    }
    // Sort by timestamp descending (newest first)
    items.sort(
      (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int),
    );

    _cachedHistory = items;
    _historyCacheDirty = false;
    return items;
  }

  int getPosition(String url) {
    // Check main entry first (movies use this)
    final key = _getKey(url);
    if (_historyBox.containsKey(key)) {
      final map = _historyBox.get(key) as Map;
      return (map['position'] as int?) ?? 0;
    }

    // Fallback to episode if applicable (for legacy or mixed lookups)
    final epKey = "EP_${_getKey(url)}";
    if (_historyBox.containsKey(epKey)) {
      final map = _historyBox.get(epKey) as Map;
      return (map['position'] as int?) ?? 0;
    }
    return 0;
  }

  int getEpisodePosition(
    String epUrl, {
    String? mainUrl,
    int? season,
    int? episode,
  }) {
    final epKey = "EP_${_getKey(epUrl)}";
    if (_historyBox.containsKey(epKey)) {
      final map = _historyBox.get(epKey) as Map;
      return (map['position'] as int?) ?? 0;
    }

    // Fallback: If we have season/episode info, look into the main item entry
    if (mainUrl != null && season != null && episode != null) {
      final mainKey = _getKey(mainUrl);
      if (_historyBox.containsKey(mainKey)) {
        final map = _historyBox.get(mainKey) as Map;
        if (map['season'] == season && map['episode'] == episode) {
          return (map['position'] as int?) ?? 0;
        }
      }
    }
    return 0;
  }

  int getDuration(String url) {
    final key = _getKey(url);
    if (_historyBox.containsKey(key)) {
      final map = _historyBox.get(key) as Map;
      return (map['duration'] as int?) ?? 0;
    }

    final epKey = "EP_${_getKey(url)}";
    if (_historyBox.containsKey(epKey)) {
      final map = _historyBox.get(epKey) as Map;
      return (map['duration'] as int?) ?? 0;
    }
    return 0;
  }

  int getEpisodeDuration(
    String epUrl, {
    String? mainUrl,
    int? season,
    int? episode,
  }) {
    final epKey = "EP_${_getKey(epUrl)}";
    if (_historyBox.containsKey(epKey)) {
      final map = _historyBox.get(epKey) as Map;
      return (map['duration'] as int?) ?? 0;
    }

    // Fallback: Look into main item entry
    if (mainUrl != null && season != null && episode != null) {
      final mainKey = _getKey(mainUrl);
      if (_historyBox.containsKey(mainKey)) {
        final map = _historyBox.get(mainKey) as Map;
        if (map['season'] == season && map['episode'] == episode) {
          return (map['duration'] as int?) ?? 0;
        }
      }
    }
    return 0;
  }

  String? getLastStreamUrl(String url) {
    final key = _getKey(url);
    if (_historyBox.containsKey(key)) {
      final map = _historyBox.get(key) as Map;
      return map['lastStreamUrl'] as String?;
    }
    return null;
  }

  String? getLastEpisodeUrl(String url) {
    final key = _getKey(url);
    if (_historyBox.containsKey(key)) {
      final map = _historyBox.get(key) as Map;
      return map['lastEpisodeUrl'] as String?;
    }
    return null;
  }

  static const String _kExtensionRepoUrls = 'extension_repo_urls';

  Future<void> clearPreferences({bool keepRepos = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // If keepRepos is true, preserve SkyStream extensions, Nuvio plugins, and Stremio addons
      List<String>? savedExtensionRepos;
      List<String>? savedDisabledExtensions;
      List<String>? savedPinnedExtensions;
      List<String>? savedNuvioRepos;
      bool? savedNuvioEnabled;
      bool? savedNuvioAutoUpdate;
      final savedNuvioSettings = <String, Object>{};
      List<String>? savedStremioAddons;

      if (keepRepos) {
        savedExtensionRepos = prefs.getStringList(_kExtensionRepoUrls);
        savedDisabledExtensions = prefs.getStringList('disabled_extensions');
        savedPinnedExtensions = prefs.getStringList('pinned_extensions');
        savedNuvioRepos = prefs.getStringList('nuvio_repos_v1');
        savedNuvioEnabled = prefs.getBool('nuvio_enabled_v1');
        savedNuvioAutoUpdate = prefs.getBool('nuvio_auto_update_v1');
        savedStremioAddons = prefs.getStringList('stremio_addons_v2');

        for (final key in prefs.getKeys()) {
          if (key.startsWith('nuvio_scraper_settings_')) {
            final val = prefs.get(key);
            if (val != null) savedNuvioSettings[key] = val;
          }
        }
      }

      await prefs.clear();

      if (keepRepos) {
        if (savedExtensionRepos != null) {
          await prefs.setStringList(_kExtensionRepoUrls, savedExtensionRepos);
        }
        if (savedDisabledExtensions != null) {
          await prefs.setStringList('disabled_extensions', savedDisabledExtensions);
        }
        if (savedPinnedExtensions != null) {
          await prefs.setStringList('pinned_extensions', savedPinnedExtensions);
        }
        if (savedNuvioRepos != null) {
          await prefs.setStringList('nuvio_repos_v1', savedNuvioRepos);
        }
        if (savedNuvioEnabled != null) {
          await prefs.setBool('nuvio_enabled_v1', savedNuvioEnabled);
        }
        if (savedNuvioAutoUpdate != null) {
          await prefs.setBool('nuvio_auto_update_v1', savedNuvioAutoUpdate);
        }
        if (savedStremioAddons != null) {
          await prefs.setStringList('stremio_addons_v2', savedStremioAddons);
        }
        for (final entry in savedNuvioSettings.entries) {
          final v = entry.value;
          if (v is String) {
            await prefs.setString(entry.key, v);
          } else if (v is bool) {
            await prefs.setBool(entry.key, v);
          } else if (v is int) {
            await prefs.setInt(entry.key, v);
          } else if (v is double) {
            await prefs.setDouble(entry.key, v);
          } else if (v is List<String>) {
            await prefs.setStringList(entry.key, v);
          }
        }
      }

      // Delete Hive Boxes (Library, History, Settings)
      try {
        if (_libraryBox.isOpen) await _libraryBox.close();
        await Hive.deleteBoxFromDisk(kLibraryBox);
      } catch (e) {
        if (kDebugMode) debugPrint('Error deleting library box: $e');
      }
      try {
        if (_settingsBox.isOpen) await _settingsBox.close();
        await Hive.deleteBoxFromDisk(kSettingsBox);
      } catch (e) {
        if (kDebugMode) debugPrint('Error deleting settings box: $e');
      }
      try {
        if (_historyBox.isOpen) await _historyBox.close();
        await Hive.deleteBoxFromDisk(kHistoryBox);
      } catch (e) {
        if (kDebugMode) debugPrint('Error deleting history box: $e');
      }

      // Only delete extension data box if NOT keeping extensions
      if (!keepRepos) {
        try {
          if (_extensionsBox.isOpen) await _extensionsBox.close();
          await Hive.deleteBoxFromDisk(kExtensionsBox);
        } catch (e) {
          if (kDebugMode) debugPrint('Error deleting extensions box: $e');
        }
      }
      // Clear Cache Manager (Images)
      try {
        await DefaultCacheManager().emptyCache();
      } catch (e) {
        if (kDebugMode) debugPrint("Error clearing cache manager: $e");
      }

      // Clear Temporary Directory (torrent cache, stream temp files)
      try {
        final tempDir = await getTemporaryDirectory();
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (e) {
        if (kDebugMode) debugPrint("Error clearing temp dir: $e");
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error clearing preferences: $e');
    }
  }

  Future<void> saveDownloadMetadata(
    String taskId,
    MultimediaItem item, {
    Episode? episode,
  }) async {
    final box = await Hive.openBox<dynamic>(kDownloadMetadataBox);
    await box.put(taskId, {
      'item': item.toJson(),
      'episode': episode?.toJson(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<Map<String, dynamic>?> getDownloadMetadata(String taskId) async {
    final box = await Hive.openBox<dynamic>(kDownloadMetadataBox);
    final data = box.get(taskId);
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> removeDownloadMetadata(String taskId) async {
    final box = await Hive.openBox<dynamic>(kDownloadMetadataBox);
    await box.delete(taskId);
  }

  Future<void> deleteAllData() async {
    try {
      final supportDir = await getApplicationSupportDirectory();

      // 1. Delete SkyStream Extensions Folder
      final extDir = Directory('${supportDir.path}/extensions');
      if (await extDir.exists()) {
        await extDir.delete(recursive: true);
      }

      // 2. Delete Nuvio Plugins Folder
      final nuvioDir = Directory('${supportDir.path}/nuvio_plugins');
      if (await nuvioDir.exists()) {
        await nuvioDir.delete(recursive: true);
      }

      // 3. Clear Preferences & Hive Boxes (including extensions)
      await clearPreferences(keepRepos: false);

      // 4. Clear Download Metadata
      try {
        await Hive.deleteBoxFromDisk(kDownloadMetadataBox);
      } catch (_) {}

      // 5. Clear Secure Storage (OAuth tokens, Debrid API keys)
      try {
        const secure = FlutterSecureStorage(aOptions: AndroidOptions());
        await secure.deleteAll();
      } catch (e) {
        if (kDebugMode) debugPrint('Error deleting secure storage: $e');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error deleting data: $e');
    }
  }

  Future<int> computeImageVideoCacheBytes() async {
    if (kIsWeb) return 0;
    var total = 0;
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await for (final entity in tempDir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File) {
            try {
              total += await entity.length();
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error computing cache size: $e');
    }
    return total;
  }

  Future<void> clearImageVideoCache() async {
    if (kIsWeb) return;
    try {
      await DefaultCacheManager().emptyCache();
    } catch (e) {
      if (kDebugMode) debugPrint('Error clearing image cache: $e');
    }
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error clearing temp dir: $e');
    }
  }
}
