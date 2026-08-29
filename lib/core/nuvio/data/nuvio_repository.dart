import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../network/dio_client_provider.dart';
import '../models/nuvio_models.dart';
import 'nuvio_code_store.dart';

part 'nuvio_repository.g.dart';

class NuvioState {
  final List<NuvioRepo> repos;
  final bool enabled;
  final bool isLoading;

  /// Check every repository's manifest on launch, the way Nuvio does — this is
  /// how a plugin the developer bumped to a new version reaches the user.
  final bool autoUpdate;

  const NuvioState({
    this.repos = const [],
    this.enabled = true,
    this.isLoading = true,
    this.autoUpdate = true,
  });

  List<({NuvioRepo repo, NuvioScraperInfo scraper})> get activeScrapers => [
    if (enabled)
      for (final repo in repos)
        for (final scraper in repo.enabledScrapers)
          if (scraper.isSupportedOn(NuvioRepository.platformName))
            (repo: repo, scraper: scraper),
  ];

  /// Scrapers whose version changed on the most recent refresh.
  Set<String> get recentlyUpdatedScraperIds => {
    for (final repo in repos) ...?repo.lastUpdate?.changedScraperIds,
  };

  int get pendingUpdateCount => repos.fold(
    0,
    (total, repo) => total + (repo.lastUpdate?.changeCount ?? 0),
  );

  NuvioState copyWith({
    List<NuvioRepo>? repos,
    bool? enabled,
    bool? isLoading,
    bool? autoUpdate,
  }) => NuvioState(
    repos: repos ?? this.repos,
    enabled: enabled ?? this.enabled,
    isLoading: isLoading ?? this.isLoading,
    autoUpdate: autoUpdate ?? this.autoUpdate,
  );
}

/// Stores Nuvio plugin repositories and the scraper code they publish.
///
/// This sits next to — not inside — the SkyStream plugin system: both are
/// "plugins", both feed the same sources sheet, but they speak different
/// protocols and are managed separately.
@Riverpod(keepAlive: true)
class NuvioRepository extends _$NuvioRepository {
  static const String _reposKey = 'nuvio_repos_v1';
  static const String _enabledKey = 'nuvio_enabled_v1';
  static const String _autoUpdateKey = 'nuvio_auto_update_v1';
  static const String _codePrefix = 'nuvio_code_';
  static const String _settingsPrefix = 'nuvio_scraper_settings_';

  /// How long after the last check a launch triggers a new one.
  static const Duration autoUpdateInterval = Duration(hours: 6);

  /// Value matched against a scraper's `supportedPlatforms` /
  /// `disabledPlatforms`, like Nuvio's `currentPluginPlatform()`.
  static String get platformName {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  /// Plugin code lives in files, not SharedPreferences — see [NuvioCodeStore].
  final NuvioCodeStore _codeStore = NuvioCodeStore();
  final Map<String, Map<String, dynamic>> _settingsCache = {};

  @override
  NuvioState build() {
    Future.microtask(load);
    return const NuvioState();
  }

  Dio get _dio => ref.read(dioClientProvider);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_reposKey) ?? const <String>[];
      final repos = <NuvioRepo>[];
      for (final entry in raw) {
        try {
          final decoded = jsonDecode(entry);
          if (decoded is Map) {
            final repo = NuvioRepo.fromJson(Map<String, dynamic>.from(decoded));
            if (repo != null) repos.add(repo);
          }
        } catch (_) {
          // Skip malformed entries.
        }
      }
      state = NuvioState(
        repos: repos,
        enabled: prefs.getBool(_enabledKey) ?? true,
        isLoading: false,
        autoUpdate: prefs.getBool(_autoUpdateKey) ?? true,
      );
      unawaited(autoUpdateIfDue());
    } catch (error) {
      if (kDebugMode) debugPrint('[Nuvio] load failed: $error');
      state = const NuvioState(repos: [], isLoading: false);
    }
  }

  Future<void> _persist(List<NuvioRepo> repos) async {
    state = state.copyWith(repos: repos, isLoading: false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _reposKey,
        repos.map((r) => jsonEncode(r.toJson())).toList(),
      );
    } catch (error) {
      if (kDebugMode) debugPrint('[Nuvio] persist failed: $error');
    }
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
    } catch (_) {
      // Session-only fallback.
    }
  }

  Future<NuvioManifest> fetchManifest(String url) async {
    final response = await _dio.get<dynamic>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        receiveTimeout: const Duration(seconds: 20),
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    if ((response.statusCode ?? 0) >= 400) {
      throw NuvioException(
        'HTTP ${response.statusCode} fetching the manifest.',
      );
    }
    final data = response.data;
    final decoded = data is String ? jsonDecode(data) : data;
    if (decoded is! Map) {
      throw const NuvioException('That URL did not return a JSON manifest.');
    }
    final manifest = NuvioManifest.fromJson(Map<String, dynamic>.from(decoded));
    if (!manifest.isValid) {
      throw const NuvioException(
        'Not a Nuvio plugin manifest (needs name, version and scrapers).',
      );
    }
    return manifest;
  }

  Future<NuvioRepo> addRepository(String rawUrl) async {
    final url = NuvioUrls.normalizeManifestUrl(rawUrl);
    if (url.isEmpty) throw const NuvioException('Enter a plugin manifest URL.');

    final manifest = await fetchManifest(url);
    final now = DateTime.now();
    final repo = NuvioRepo(
      manifestUrl: url,
      manifest: manifest,
      addedAt: now,
      lastCheckedAt: now,
      lastUpdatedAt: now,
    );

    final next = List<NuvioRepo>.of(state.repos);
    final existing = next.indexWhere((r) => r.manifestUrl == url);
    if (existing >= 0) {
      next[existing] = repo.copyWith(
        disabledScrapers: next[existing].disabledScrapers,
      );
    } else {
      next.add(repo);
    }
    await _persist(next);

    // Warm the code cache so the first playback isn't slowed by downloads.
    unawaited(prefetchCode(repo));
    return repo;
  }

  Future<void> removeRepository(String manifestUrl) async {
    final removed = state.repos.firstWhere(
      (r) => r.manifestUrl == manifestUrl,
      orElse: () =>
          NuvioRepo(manifestUrl: manifestUrl, addedAt: DateTime.now()),
    );
    await _persist(
      state.repos.where((r) => r.manifestUrl != manifestUrl).toList(),
    );
    await _codeStore.deleteRepository(manifestUrl);
    for (final scraper
        in removed.manifest?.scrapers ?? const <NuvioScraperInfo>[]) {
      await clearScraperSettings(scraper.id);
    }
    // Legacy: code used to be cached in SharedPreferences.
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().toList()) {
        if (key.startsWith('$_codePrefix$manifestUrl')) await prefs.remove(key);
      }
    } catch (_) {
      // Nothing to clean up.
    }
  }

  /// Turning a scraper on always wins — including for providers a repository
  /// ships disabled (torrent providers usually are), which previously could
  /// not be enabled at all.
  Future<void> setScraperEnabled(
    String manifestUrl,
    String scraperId,
    bool enabled,
  ) async {
    final next = [
      for (final repo in state.repos)
        if (repo.manifestUrl != manifestUrl)
          repo
        else
          repo.copyWith(
            disabledScrapers: {
              ...repo.disabledScrapers.where((id) => id != scraperId),
              if (!enabled) scraperId,
            },
            enabledOverrides: {
              ...repo.enabledOverrides.where((id) => id != scraperId),
              if (enabled) scraperId,
            },
          ),
    ];
    await _persist(next);
    if (enabled) {
      final repo = next.firstWhere((r) => r.manifestUrl == manifestUrl);
      final scraper = repo.manifest?.scrapers
          .where((s) => s.id == scraperId)
          .firstOrNull;
      if (scraper != null) {
        unawaited(codeFor(repo, scraper).catchError((Object _) => ''));
      }
    }
  }

  /// Bulk switch for a repository — "Enable all" / "Disable all".
  Future<void> setAllScrapersEnabled(String manifestUrl, bool enabled) async {
    final next = [
      for (final repo in state.repos)
        if (repo.manifestUrl != manifestUrl)
          repo
        else
          repo.copyWith(
            disabledScrapers: enabled
                ? const <String>{}
                : {
                    for (final scraper
                        in repo.manifest?.scrapers ??
                            const <NuvioScraperInfo>[])
                      scraper.id,
                  },
            enabledOverrides: enabled
                ? {
                    for (final scraper
                        in repo.manifest?.scrapers ??
                            const <NuvioScraperInfo>[])
                      scraper.id,
                  }
                : const <String>{},
          ),
    ];
    await _persist(next);
    if (enabled) {
      final repo = next.firstWhere((r) => r.manifestUrl == manifestUrl);
      unawaited(prefetchCode(repo));
    }
  }

  Future<void> setAutoUpdate(bool value) async {
    state = state.copyWith(autoUpdate: value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoUpdateKey, value);
    } catch (_) {
      // Session-only fallback.
    }
    if (value) unawaited(autoUpdateIfDue(force: true));
  }

  /// Launch-time update check, matching Nuvio's `initialize()`: every stored
  /// repository is re-fetched so a version the developer published upstream
  /// lands in the app without the user doing anything.
  Future<void> autoUpdateIfDue({bool force = false}) async {
    if (!state.autoUpdate || state.repos.isEmpty) return;
    final due = state.repos.where((repo) {
      final checked = repo.lastCheckedAt;
      return force ||
          checked == null ||
          DateTime.now().difference(checked) >= autoUpdateInterval;
    }).toList();
    if (due.isEmpty) return;
    for (final repo in due) {
      await refreshRepository(repo.manifestUrl, silent: true);
    }
  }

  /// Re-fetch one repository's manifest, work out what the developer changed,
  /// drop the cached code for anything whose version moved, and warm the new
  /// code so the next playback isn't slowed by downloads.
  Future<NuvioUpdateSummary?> refreshRepository(
    String manifestUrl, {
    bool silent = false,
  }) async {
    final index = state.repos.indexWhere((r) => r.manifestUrl == manifestUrl);
    if (index < 0) return null;

    void patch(NuvioRepo Function(NuvioRepo repo) update) {
      final next = List<NuvioRepo>.of(state.repos);
      final at = next.indexWhere((r) => r.manifestUrl == manifestUrl);
      if (at < 0) return;
      next[at] = update(next[at]);
      state = state.copyWith(repos: next);
    }

    patch((repo) => repo.copyWith(isRefreshing: true, clearError: true));

    try {
      final manifest = await fetchManifest(manifestUrl);
      final installed = state.repos
          .firstWhere((r) => r.manifestUrl == manifestUrl)
          .manifest;
      final summary = NuvioUpdateSummary.diff(installed, manifest);
      final now = DateTime.now();

      // A changed version means the cached file is stale: forget it so the
      // next run downloads the developer's new code.
      if (summary.changedScraperIds.isNotEmpty) {
        await _invalidateCode(manifestUrl, summary.changedScraperIds);
      }
      await _pruneCode(manifestUrl, manifest);

      patch(
        (repo) => repo.copyWith(
          manifest: manifest,
          isRefreshing: false,
          clearError: true,
          lastCheckedAt: now,
          lastUpdatedAt: summary.hasChanges ? now : repo.lastUpdatedAt,
          lastUpdate: summary,
          clearLastUpdate: !summary.hasChanges,
        ),
      );
      await _persist(state.repos);

      if (summary.changedScraperIds.isNotEmpty) {
        final repo = state.repos.firstWhere(
          (r) => r.manifestUrl == manifestUrl,
        );
        unawaited(prefetchCode(repo));
      }
      return summary;
    } catch (error) {
      patch(
        (repo) => repo.copyWith(
          isRefreshing: false,
          errorMessage: error.toString(),
          lastCheckedAt: DateTime.now(),
        ),
      );
      if (kDebugMode) debugPrint('[Nuvio] refresh $manifestUrl: $error');
      if (!silent) rethrow;
      return null;
    }
  }

  /// Check every repository. Returns how many plugins changed in total.
  Future<int> refreshAll() async {
    if (state.repos.isEmpty) return 0;
    var changes = 0;
    for (final repo in List<NuvioRepo>.of(state.repos)) {
      final summary = await refreshRepository(repo.manifestUrl, silent: true);
      changes += summary?.changeCount ?? 0;
    }
    return changes;
  }

  /// Drop cached code for the given scrapers (any version).
  Future<void> _invalidateCode(String manifestUrl, Set<String> scraperIds) =>
      _codeStore.deleteScrapers(
        manifestUrl: manifestUrl,
        scraperIds: scraperIds,
      );

  /// Remove code cached for versions (or scrapers) the manifest no longer
  /// lists, so an old bundle can never be run after an update.
  Future<void> _pruneCode(String manifestUrl, NuvioManifest manifest) =>
      _codeStore.prune(
        manifestUrl: manifestUrl,
        keepIdVersions: {
          for (final scraper in manifest.scrapers)
            '${scraper.id}@${scraper.version}',
        },
      );

  // --- per-scraper settings ------------------------------------------------

  /// Values saved from a scraper's `onSettings()` form. Handed to the plugin
  /// as `SCRAPER_SETTINGS` on every run, exactly like Nuvio.
  Future<Map<String, dynamic>> scraperSettings(String scraperId) async {
    final cached = _settingsCache[scraperId];
    if (cached != null) return cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_settingsPrefix$scraperId');
      if (raw == null || raw.isEmpty) return const {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final map = Map<String, dynamic>.from(decoded);
      _settingsCache[scraperId] = map;
      return map;
    } catch (_) {
      return const {};
    }
  }

  Future<void> saveScraperSettings(
    String scraperId,
    Map<String, dynamic> values,
  ) async {
    _settingsCache[scraperId] = values;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_settingsPrefix$scraperId', jsonEncode(values));
    } catch (error) {
      if (kDebugMode) debugPrint('[Nuvio] save settings $scraperId: $error');
    }
  }

  Future<void> clearScraperSettings(String scraperId) async {
    _settingsCache.remove(scraperId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_settingsPrefix$scraperId');
    } catch (_) {
      // Nothing to do.
    }
  }

  /// Scraper source, from the on-disk store → network.
  Future<String> codeFor(NuvioRepo repo, NuvioScraperInfo scraper) async {
    final cached = await _codeStore.read(
      manifestUrl: repo.manifestUrl,
      scraperId: scraper.id,
      version: scraper.version,
    );
    if (cached != null) return cached;

    final uri = repo.codeUrlFor(scraper);
    if (uri == null) {
      throw NuvioException('${scraper.name} has no usable file name.');
    }

    final response = await _dio.get<dynamic>(
      uri.toString(),
      options: Options(
        responseType: ResponseType.plain,
        receiveTimeout: const Duration(seconds: 25),
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    if ((response.statusCode ?? 0) >= 400) {
      throw NuvioException(
        'HTTP ${response.statusCode} downloading ${scraper.filename}.',
      );
    }
    final code = response.data is String
        ? response.data as String
        : jsonEncode(response.data);
    if (code.trim().isEmpty) {
      throw NuvioException('${scraper.name} returned an empty file.');
    }

    await _codeStore.write(
      manifestUrl: repo.manifestUrl,
      scraperId: scraper.id,
      version: scraper.version,
      code: code,
    );
    return code;
  }

  /// Bytes of plugin code cached on disk.
  Future<int> cachedCodeBytes() => _codeStore.usedBytes();

  Future<void> prefetchCode(NuvioRepo repo, {bool force = false}) async {
    for (final scraper in repo.enabledScrapers) {
      try {
        if (force) {
          await _codeStore.deleteScrapers(
            manifestUrl: repo.manifestUrl,
            scraperIds: {scraper.id},
          );
        }
        await codeFor(repo, scraper);
      } catch (error) {
        if (kDebugMode) debugPrint('[Nuvio] prefetch ${scraper.id}: $error');
      }
    }
  }
}

class NuvioException implements Exception {
  final String message;
  const NuvioException(this.message);
  @override
  String toString() => message;
}
