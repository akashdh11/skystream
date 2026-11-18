import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/addons/data/addon_repository.dart';
import '../../../core/cloudstream/cloudstream_models.dart';
import '../../../core/cloudstream/cloudstream_repository.dart';
import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/extensions/extension_manager.dart';
import '../../../core/extensions/models/extension_plugin.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/nuvio/data/nuvio_repository.dart';
import '../../../core/storage/episode_watch_repository.dart';
import '../../../core/storage/extension_repository.dart';
import '../../../core/storage/library_repository.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../../../core/storage/settings_repository.dart';
import '../../../core/storage/storage_service.dart';
import '../../extensions/providers/extensions_controller.dart';
import '../../library/presentation/history_provider.dart';
import '../../library/presentation/library_provider.dart';
import '../domain/profile_sync_merge.dart';
import '../domain/profile_sync_payload.dart';
import '../profile_sync_hooks.dart';

class ProfileSyncState {
  final String serverUrl;
  final String? username;
  final bool isLoggedIn;
  final bool isSyncing;
  final bool autoSync;
  final int? lastSyncedAt;
  final String? lastError;

  const ProfileSyncState({
    this.serverUrl = '',
    this.username,
    this.isLoggedIn = false,
    this.isSyncing = false,
    this.autoSync = true,
    this.lastSyncedAt,
    this.lastError,
  });

  ProfileSyncState copyWith({
    String? serverUrl,
    String? username,
    bool? isLoggedIn,
    bool? isSyncing,
    bool? autoSync,
    int? lastSyncedAt,
    String? lastError,
    bool clearError = false,
    bool clearUsername = false,
  }) => ProfileSyncState(
    serverUrl: serverUrl ?? this.serverUrl,
    username: clearUsername ? null : (username ?? this.username),
    isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    isSyncing: isSyncing ?? this.isSyncing,
    autoSync: autoSync ?? this.autoSync,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    lastError: clearError ? null : (lastError ?? this.lastError),
  );
}

final profileSyncProvider =
    NotifierProvider<ProfileSyncNotifier, ProfileSyncState>(
      ProfileSyncNotifier.new,
    );

class ProfileSyncNotifier extends Notifier<ProfileSyncState> {
  static const _kServerUrlKey = 'profile_sync_server_url';
  static const _kUsernameKey = 'profile_sync_username';
  static const _kAutoSyncKey = 'profile_sync_auto';
  static const _kLastSyncedKey = 'profile_sync_last_ts';
  static const _kTokenKey = 'profile_sync_token';
  static const _kBaselineKey = 'profile_sync_baseline_v1';
  static const _kDeletedHistoryKey = 'profile_sync_deleted_history_v1';
  static const _kDeletedLibraryKey = 'profile_sync_deleted_library_v1';
  static const Duration _pollInterval = Duration(seconds: 45);
  static const int _tombstoneMaxAgeMs = 30 * 24 * 60 * 60 * 1000;

  Timer? _debounceTimer;
  Timer? _pollTimer;
  bool _applying = false;
  int? _lastRemoteUpdatedAt;

  @override
  ProfileSyncState build() {
    ref.keepAlive();
    final storage = ref.watch(storageServiceProvider);
    final serverUrl = storage.getString(_kServerUrlKey) ?? '';
    final username = storage.getString(_kUsernameKey);
    final autoSync =
        storage.getPlayerSetting<bool>(_kAutoSyncKey, defaultValue: true) ??
        true;
    final lastSynced = storage.getPlayerSetting<int>(_kLastSyncedKey);

    final hooks = ref.read(profileSyncHooksProvider);
    hooks.onLocalChange = scheduleQuickSync;
    ref.listen(episodeWatchRevisionProvider, (previous, next) {
      if (previous == null) return;
      scheduleQuickSync();
    });
    ref.onDispose(() {
      _debounceTimer?.cancel();
      _pollTimer?.cancel();
      if (hooks.onLocalChange == scheduleQuickSync) {
        hooks.onLocalChange = null;
      }
    });

    Future.microtask(_checkTokenAndInitialSync);

    return ProfileSyncState(
      serverUrl: serverUrl,
      username: username,
      autoSync: autoSync,
      lastSyncedAt: lastSynced,
    );
  }

  void _startPollTimer() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      _pollInterval,
      (_) => unawaited(pollRemoteChanges()),
    );
  }

  Future<void> _checkTokenAndInitialSync() async {
    if (state.serverUrl.isEmpty) return;
    final token = await ref.read(secureTokenStorageProvider).read(_kTokenKey);
    if (!ref.mounted) return;
    if (token == null || token.isEmpty) return;
    state = state.copyWith(isLoggedIn: true);
    if (state.autoSync) {
      _startPollTimer();
      unawaited(syncNow(installMissingExtensions: true));
    }
  }

  void onAppResumed() {
    if (!state.isLoggedIn || !state.autoSync) return;
    unawaited(pollRemoteChanges(forceSyncIfNeverSynced: true));
  }

  Future<void> pollRemoteChanges({bool forceSyncIfNeverSynced = false}) async {
    if (!state.isLoggedIn ||
        !state.autoSync ||
        state.isSyncing ||
        state.serverUrl.isEmpty) {
      return;
    }
    final token = await ref.read(secureTokenStorageProvider).read(_kTokenKey);
    if (!ref.mounted || token == null || token.isEmpty) return;

    try {
      final remote = await _fetchRemoteProfile(token);
      if (!ref.mounted) return;
      final neverSynced = _lastRemoteUpdatedAt == null;
      final serverChanged =
          remote.updatedAt != 0 && remote.updatedAt != _lastRemoteUpdatedAt;
      if (serverChanged ||
          (neverSynced && (forceSyncIfNeverSynced || remote.updatedAt > 0))) {
        await syncNow(installMissingExtensions: true);
      }
    } catch (error) {
      talker.debug('[ProfileSync] poll skipped: $error');
    }
  }

  Future<bool> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final cleanUrl = serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (cleanUrl.isEmpty) {
      state = state.copyWith(isSyncing: false, lastError: 'Server URL required.');
      return false;
    }
    state = state.copyWith(
      serverUrl: cleanUrl,
      isSyncing: true,
      clearError: true,
    );
    try {
      final response = await ref
          .read(dioClientProvider)
          .post<Map<String, dynamic>>(
            '$cleanUrl/v1/auth/login',
            data: {'username': username.trim(), 'password': password},
          );
      final data = response.data;
      final token = data?['token'] as String?;
      if (token == null || token.isEmpty) {
        throw StateError('Server did not return an auth token.');
      }
      final signedInAs = (data?['username'] as String?) ?? username.trim();

      final storage = ref.read(storageServiceProvider);
      await storage.setString(_kServerUrlKey, cleanUrl);
      await storage.setString(_kUsernameKey, signedInAs);
      await storage.remove(_kBaselineKey);
      await storage.remove(_kDeletedHistoryKey);
      await storage.remove(_kDeletedLibraryKey);
      await ref.read(secureTokenStorageProvider).write(_kTokenKey, token);
      _lastRemoteUpdatedAt = null;
      _startPollTimer();

      state = state.copyWith(
        serverUrl: cleanUrl,
        username: signedInAs,
        isLoggedIn: true,
        isSyncing: false,
      );
      return await syncNow(installMissingExtensions: true);
    } catch (error) {
      talker.error('[ProfileSync] Login failed', error);
      state = state.copyWith(isSyncing: false, lastError: _errorMessage(error));
      return false;
    }
  }

  Future<void> logout() async {
    _debounceTimer?.cancel();
    _pollTimer?.cancel();
    _lastRemoteUpdatedAt = null;
    await ref.read(secureTokenStorageProvider).delete(_kTokenKey);
    final storage = ref.read(storageServiceProvider);
    await storage.remove(_kUsernameKey);
    await storage.remove(_kBaselineKey);
    await storage.remove(_kDeletedHistoryKey);
    await storage.remove(_kDeletedLibraryKey);
    state = state.copyWith(
      isLoggedIn: false,
      clearUsername: true,
      clearError: true,
    );
  }

  Future<void> setAutoSync(bool enabled) async {
    await ref
        .read(storageServiceProvider)
        .setPlayerSetting(_kAutoSyncKey, enabled);
    state = state.copyWith(autoSync: enabled);
    if (enabled && state.isLoggedIn) {
      _startPollTimer();
      unawaited(pollRemoteChanges(forceSyncIfNeverSynced: true));
    } else if (!enabled) {
      _pollTimer?.cancel();
    }
  }

  /// Pushes a few seconds after playback, bookmark, or extension changes so a
  /// burst does not open a request on every tick.
  void scheduleQuickSync() {
    if (_applying || !state.isLoggedIn || !state.autoSync) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 3), () {
      if (state.isSyncing) {
        scheduleQuickSync();
        return;
      }
      unawaited(syncNow(installMissingExtensions: true));
    });
  }

  Future<ProfileSyncPayload> collectLocalProfile() async {
    final storage = ref.read(storageServiceProvider);
    final history = storage.getAllHistoryEntries();
    final overrides = ref
        .read(episodeWatchRepositoryProvider)
        .exportOverrides();
    final library = ref
        .read(libraryRepositoryProvider)
        .getLibraryItems()
        .map((item) => item.toJson())
        .toList();

    final extensions = ref.read(extensionsControllerProvider.notifier);
    await extensions.ensureInitialized();
    final extensionState = ref.read(extensionsControllerProvider);
    final skystreamRepos = await extensions.persistedRepositoryUrls();

    final extensionManager = ref.read(extensionManagerProvider.notifier);
    final extensionRepo = ref.read(extensionRepositoryProvider);
    final settingsRepo = ref.read(settingsRepositoryProvider);

    final skystreamPlugins = <Map<String, String>>[];
    for (final plugin in extensionState.installedPlugins) {
      if (plugin.isDebug || plugin.sourceUrl.startsWith('assets/')) continue;
      final subProviders = extensionManager.getProvidersForPlugin(plugin);
      final disabledIds = <String>[
        for (final sub in subProviders)
          if (extensionRepo.getExtensionData(
                '${plugin.packageName}:_provider_enabled_${sub.id}',
              ) ==
              'false')
            sub.id,
      ]..sort();
      final customBaseUrl = settingsRepo.getCustomBaseUrl(plugin.packageName);
      skystreamPlugins.add({
        'packageName': plugin.packageName,
        'repositoryUrl': plugin.repositoryUrl ?? '',
        'url': plugin.sourceUrl,
        'name': plugin.name,
        'repositoryId': plugin.repositoryId,
        'version': '${plugin.version}',
        if (disabledIds.isNotEmpty)
          'disabledProviders': jsonEncode(disabledIds),
        if (customBaseUrl != null && customBaseUrl.isNotEmpty)
          'customBaseUrl': customBaseUrl,
      });
    }

    final cloudstream = ref.read(cloudStreamRepositoryProvider.notifier);
    if (ref.read(cloudStreamRepositoryProvider).isLoading) {
      await cloudstream.load();
    }
    final cloudstreamState = ref.read(cloudStreamRepositoryProvider);
    final cloudstreamRepos = [
      for (final repository in cloudstreamState.repositories) repository.url,
    ];
    final cloudstreamPlugins = [
      for (final plugin in cloudstreamState.installed)
        {
          'internalName': plugin.info.internalName,
          'name': plugin.info.name,
          'url': plugin.info.url,
          'repositoryUrl': plugin.info.repositoryUrl,
        },
    ];

    final nuvio = ref.read(nuvioRepositoryProvider.notifier);
    if (ref.read(nuvioRepositoryProvider).isLoading) {
      await nuvio.load();
    }
    final nuvioState = ref.read(nuvioRepositoryProvider);
    final nuvioRepos = [
      for (final repository in nuvioState.repos) repository.manifestUrl,
    ];
    final nuvioRepoSettings = <String, Map<String, List<String>>>{
      for (final repository in nuvioState.repos)
        if (repository.disabledScrapers.isNotEmpty ||
            repository.enabledOverrides.isNotEmpty)
          repository.manifestUrl: {
            'disabled': repository.disabledScrapers.toList()..sort(),
            'enabled': repository.enabledOverrides.toList()..sort(),
          },
    };

    final addons = ref.read(addonRepositoryProvider.notifier);
    if (ref.read(addonRepositoryProvider).isLoading) {
      await addons.load();
    }
    final addonState = ref.read(addonRepositoryProvider);
    final stremioAddons = [
      for (final addon in addonState.addons) addon.manifestUrl,
    ];
    final stremioAddonStates = <String, bool>{
      for (final addon in addonState.addons) addon.manifestUrl: addon.enabled,
    };

    final deletedHistory = _readDeletedHistory();
    final deletedLibrary = _readDeletedLibrary().toList()..sort();

    return ProfileSyncPayload(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      history: history,
      episodeOverrides: overrides,
      library: library,
      skystreamRepos: skystreamRepos,
      skystreamPlugins: skystreamPlugins,
      cloudstreamRepos: cloudstreamRepos,
      cloudstreamPlugins: cloudstreamPlugins,
      nuvioRepos: nuvioRepos,
      stremioAddons: stremioAddons,
      activeProviderId: settingsRepo.getActiveProviderId(),
      nuvioRepoSettings: nuvioRepoSettings,
      stremioAddonStates: stremioAddonStates,
      deletedHistoryKeys: deletedHistory.keys.toList(),
      deletedHistoryTimestamps: deletedHistory,
      deletedLibraryUrls: deletedLibrary,
    );
  }

  Future<ProfileSyncPayload> _fetchRemoteProfile(String token) async {
    try {
      final response = await ref
          .read(dioClientProvider)
          .get<Map<String, dynamic>>(
            '${state.serverUrl}/v1/profile',
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );
      final body = response.data;
      if (body == null) return const ProfileSyncPayload(updatedAt: 0);
      return ProfileSyncPayload.fromJson(body);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return const ProfileSyncPayload(updatedAt: 0);
      }
      rethrow;
    }
  }

  Future<bool> syncNow({bool installMissingExtensions = true}) async {
    if (!state.isLoggedIn || state.isSyncing || state.serverUrl.isEmpty) {
      return false;
    }
    final token = await ref.read(secureTokenStorageProvider).read(_kTokenKey);
    if (token == null || token.isEmpty) return false;

    state = state.copyWith(isSyncing: true, clearError: true);
    try {
      final baseline = _readBaseline();
      final remoteBefore = await _fetchRemoteProfile(token);
      final localPayload = await collectLocalProfile();
      final nowMillis = DateTime.now().millisecondsSinceEpoch;

      final historyDiff = mergeHistoryThreeWay(
        baseline: baseline?.history,
        local: localPayload.history,
        remote: remoteBefore.history,
        localDeletedTimestamps: _pruneDeletedHistory(
          localPayload.deletedHistoryTimestamps,
          nowMillis,
        ),
        remoteDeletedTimestamps: _pruneDeletedHistory(
          remoteBefore.deletedHistoryTimestamps,
          nowMillis,
        ),
        nowMillis: nowMillis,
      );

      final mergedEpisodes = _mergeEpisodeOverridesThreeWay(
        baseline: baseline?.episodeOverrides,
        local: localPayload.episodeOverrides,
        remote: remoteBefore.episodeOverrides,
      );

      final combinedDeletedLibrary = <String>{
        ...localPayload.deletedLibraryUrls,
        ...remoteBefore.deletedLibraryUrls,
      };
      final libraryDiff = mergeLibraryThreeWay(
        baseline: baseline?.library,
        local: localPayload.library,
        remote: remoteBefore.library,
        deletedUrls: combinedDeletedLibrary,
      );

      final updatedDeletedLibrary = <String>{
        ...combinedDeletedLibrary,
        if (baseline != null)
          for (final item in baseline.library)
            if (item['url'] is String &&
                !localPayload.library.any((l) => l['url'] == item['url']))
              item['url'] as String,
      };
      for (final item in libraryDiff.merged) {
        final url = item['url'];
        if (url is String) updatedDeletedLibrary.remove(url);
      }

      final skyReposDiff = mergeStringsThreeWay(
        baseline: baseline?.skystreamRepos,
        local: localPayload.skystreamRepos,
        remote: remoteBefore.skystreamRepos,
      );
      final skyPluginsDiff = mergeMapsThreeWay(
        baseline: baseline?.skystreamPlugins,
        local: localPayload.skystreamPlugins,
        remote: remoteBefore.skystreamPlugins,
        keyOf: (p) => p['packageName'],
      );
      final csReposDiff = mergeStringsThreeWay(
        baseline: baseline?.cloudstreamRepos,
        local: localPayload.cloudstreamRepos,
        remote: remoteBefore.cloudstreamRepos,
      );
      final csPluginsDiff = mergeMapsThreeWay(
        baseline: baseline?.cloudstreamPlugins,
        local: localPayload.cloudstreamPlugins,
        remote: remoteBefore.cloudstreamPlugins,
        keyOf: (p) => '${p['repositoryUrl'] ?? ''}::${p['internalName'] ?? ''}',
      );
      final nuvioReposDiff = mergeStringsThreeWay(
        baseline: baseline?.nuvioRepos,
        local: localPayload.nuvioRepos,
        remote: remoteBefore.nuvioRepos,
      );
      final stremioAddonsDiff = mergeStringsThreeWay(
        baseline: baseline?.stremioAddons,
        local: localPayload.stremioAddons,
        remote: remoteBefore.stremioAddons,
      );

      final mergedNuvioSettings = _mergeNuvioSettings(
        baseline: baseline?.nuvioRepoSettings,
        local: localPayload.nuvioRepoSettings,
        remote: remoteBefore.nuvioRepoSettings,
        activeRepos: nuvioReposDiff.merged,
      );
      final mergedStremioStates = _mergeStremioStates(
        baseline: baseline?.stremioAddonStates,
        local: localPayload.stremioAddonStates,
        remote: remoteBefore.stremioAddonStates,
        activeAddons: stremioAddonsDiff.merged,
      );
      final mergedActiveProviderId = _mergeActiveProviderId(
        baseline: baseline?.activeProviderId,
        local: localPayload.activeProviderId,
        remote: remoteBefore.activeProviderId,
      );

      final anyHistoryRemovedLocally = baseline != null &&
          baseline.history.any((item) {
            final key = historyKey(item);
            return key != null &&
                !localPayload.history.any((l) => historyKey(l) == key);
          });
      final anyLibraryRemovedLocally = baseline != null &&
          baseline.library.any((item) {
            final url = item['url'];
            return url is String &&
                !localPayload.library.any((l) => l['url'] == url);
          });
      final anyExtRemovedLocally = baseline != null &&
          (_hasLocalStringRemoval(
                baseline.skystreamRepos,
                localPayload.skystreamRepos,
              ) ||
              _hasLocalMapRemoval(
                baseline.skystreamPlugins,
                localPayload.skystreamPlugins,
                (p) => p['packageName'],
              ) ||
              _hasLocalStringRemoval(
                baseline.cloudstreamRepos,
                localPayload.cloudstreamRepos,
              ) ||
              _hasLocalMapRemoval(
                baseline.cloudstreamPlugins,
                localPayload.cloudstreamPlugins,
                (p) => '${p['repositoryUrl'] ?? ''}::${p['internalName'] ?? ''}',
              ) ||
              _hasLocalStringRemoval(
                baseline.nuvioRepos,
                localPayload.nuvioRepos,
              ) ||
              _hasLocalStringRemoval(
                baseline.stremioAddons,
                localPayload.stremioAddons,
              ));

      final outbound = ProfileSyncPayload(
        updatedAt: nowMillis,
        history: historyDiff.merged,
        episodeOverrides: mergedEpisodes,
        library: libraryDiff.merged,
        skystreamRepos: skyReposDiff.merged,
        skystreamPlugins: skyPluginsDiff.merged,
        cloudstreamRepos: csReposDiff.merged,
        cloudstreamPlugins: csPluginsDiff.merged,
        nuvioRepos: nuvioReposDiff.merged,
        stremioAddons: stremioAddonsDiff.merged,
        replaceExtensions: anyExtRemovedLocally,
        activeProviderId: mergedActiveProviderId,
        nuvioRepoSettings: mergedNuvioSettings,
        stremioAddonStates: mergedStremioStates,
        deletedHistoryKeys: historyDiff.deletedTimestamps.keys.toList(),
        deletedHistoryTimestamps: historyDiff.deletedTimestamps,
        deletedLibraryUrls: updatedDeletedLibrary.toList()..sort(),
        replaceHistory: anyHistoryRemovedLocally,
        replaceLibrary: anyLibraryRemovedLocally,
      );

      late final ProfileSyncPayload appliedRemote;
      if (_payloadDiffersFromRemote(outbound, remoteBefore)) {
        final response = await ref
            .read(dioClientProvider)
            .post<Map<String, dynamic>>(
              '${state.serverUrl}/v1/profile/sync',
              data: outbound.toJson(),
              options: Options(headers: {'Authorization': 'Bearer $token'}),
            );
        final body = response.data;
        appliedRemote = body != null
            ? ProfileSyncPayload.fromJson(body)
            : outbound;
      } else {
        appliedRemote = remoteBefore;
      }

      await _writeDeletedHistory(historyDiff.deletedTimestamps);
      await _writeDeletedLibrary(updatedDeletedLibrary);

      await applyRemoteProfile(
        appliedRemote,
        installMissingExtensions: installMissingExtensions,
        historyToWrite: historyDiff.toWriteLocally,
        historyKeysToDelete: historyDiff.toDeleteLocally,
        mergedEpisodeOverrides: mergedEpisodes,
        libraryToAdd: libraryDiff.toAddLocally,
        libraryUrlsToRemove: libraryDiff.toRemoveLocally,
        skyReposToAdd: skyReposDiff.toAddLocally,
        skyReposToRemove: skyReposDiff.toRemoveLocally,
        skyPluginsToApply: skyPluginsDiff.toAddLocally,
        skyPluginsToRemove: skyPluginsDiff.toRemoveLocally,
        csReposToAdd: csReposDiff.toAddLocally,
        csReposToRemove: csReposDiff.toRemoveLocally,
        csPluginsToApply: csPluginsDiff.toAddLocally,
        csPluginsToRemove: csPluginsDiff.toRemoveLocally,
        nuvioReposToAdd: nuvioReposDiff.toAddLocally,
        nuvioReposToRemove: nuvioReposDiff.toRemoveLocally,
        nuvioSettings: mergedNuvioSettings,
        stremioAddonsToAdd: stremioAddonsDiff.toAddLocally,
        stremioAddonsToRemove: stremioAddonsDiff.toRemoveLocally,
        stremioAddonStates: mergedStremioStates,
        targetActiveProviderId: mergedActiveProviderId,
        baseline: baseline,
      );

      final finalLocal = await collectLocalProfile();
      await _writeBaseline(finalLocal);
      _lastRemoteUpdatedAt = appliedRemote.updatedAt;

      final syncedNow = DateTime.now().millisecondsSinceEpoch;
      await ref
          .read(storageServiceProvider)
          .setPlayerSetting(_kLastSyncedKey, syncedNow);
      if (!ref.mounted) return true;
      state = state.copyWith(isSyncing: false, lastSyncedAt: syncedNow);
      return true;
    } catch (error) {
      talker.error('[ProfileSync] sync failed', error);
      if (ref.mounted) {
        state = state.copyWith(
          isSyncing: false,
          lastError: _errorMessage(error),
        );
      }
      return false;
    }
  }

  Future<void> applyRemoteProfile(
    ProfileSyncPayload remote, {
    required bool installMissingExtensions,
    List<Map<String, dynamic>>? historyToWrite,
    List<String>? historyKeysToDelete,
    Map<String, bool>? mergedEpisodeOverrides,
    List<Map<String, dynamic>>? libraryToAdd,
    List<String>? libraryUrlsToRemove,
    List<String>? skyReposToAdd,
    List<String>? skyReposToRemove,
    List<Map<String, String>>? skyPluginsToApply,
    List<String>? skyPluginsToRemove,
    List<String>? csReposToAdd,
    List<String>? csReposToRemove,
    List<Map<String, String>>? csPluginsToApply,
    List<String>? csPluginsToRemove,
    List<String>? nuvioReposToAdd,
    List<String>? nuvioReposToRemove,
    Map<String, Map<String, List<String>>>? nuvioSettings,
    List<String>? stremioAddonsToAdd,
    List<String>? stremioAddonsToRemove,
    Map<String, bool>? stremioAddonStates,
    String? targetActiveProviderId,
    ProfileSyncPayload? baseline,
  }) async {
    _applying = true;
    try {
      final storage = ref.read(storageServiceProvider);
      final toWrite =
          historyToWrite ??
          newerHistoryEntries(
            local: storage.getAllHistoryEntries(),
            remote: remote.history,
          );
      final toDelete = historyKeysToDelete ?? const <String>[];
      var historyChanged = false;
      if (toWrite.isNotEmpty) {
        await storage.restoreHistoryEntries(toWrite);
        historyChanged = true;
      }
      if (toDelete.isNotEmpty) {
        await storage.deleteHistoryKeys(toDelete);
        historyChanged = true;
      }
      if (historyChanged) {
        ref.read(watchHistoryProvider.notifier).refresh();
        final epChanged =
            toWrite.any((item) => (historyKey(item) ?? '').startsWith('EP_')) ||
            toDelete.any((key) => key.startsWith('EP_'));
        if (epChanged) {
          ref.read(episodeWatchRevisionProvider.notifier).bump();
        }
      }

      await ref
          .read(episodeWatchRepositoryProvider)
          .mergeOverrides(mergedEpisodeOverrides ?? remote.episodeOverrides);

      final library = ref.read(libraryRepositoryProvider);
      var libraryChanged = false;
      for (final raw in libraryToAdd ?? remote.library) {
        try {
          final item = MultimediaItem.fromJson(raw);
          if (item.url.isEmpty || library.isInLibrary(item.url)) continue;
          await library.addToLibrary(item);
          libraryChanged = true;
        } catch (error) {
          talker.warning('[ProfileSync] skipped a library item: $error');
        }
      }
      for (final url in libraryUrlsToRemove ?? const <String>[]) {
        if (url.isEmpty || !library.isInLibrary(url)) continue;
        await library.removeFromLibrary(url);
        libraryChanged = true;
      }
      if (libraryChanged) {
        ref.read(libraryProvider.notifier).refresh();
      }

      if (!installMissingExtensions) return;
      await _applyExtensionChanges(
        remote,
        skyReposToAdd: skyReposToAdd ?? remote.skystreamRepos,
        skyReposToRemove: skyReposToRemove ?? const [],
        skyPluginsToApply: skyPluginsToApply ?? remote.skystreamPlugins,
        skyPluginsToRemove: skyPluginsToRemove ?? const [],
        csReposToAdd: csReposToAdd ?? remote.cloudstreamRepos,
        csReposToRemove: csReposToRemove ?? const [],
        csPluginsToApply: csPluginsToApply ?? remote.cloudstreamPlugins,
        csPluginsToRemove: csPluginsToRemove ?? const [],
        nuvioReposToAdd: nuvioReposToAdd ?? remote.nuvioRepos,
        nuvioReposToRemove: nuvioReposToRemove ?? const [],
        nuvioSettings: nuvioSettings ?? remote.nuvioRepoSettings,
        stremioAddonsToAdd: stremioAddonsToAdd ?? remote.stremioAddons,
        stremioAddonsToRemove: stremioAddonsToRemove ?? const [],
        stremioAddonStates: stremioAddonStates ?? remote.stremioAddonStates,
        targetActiveProviderId: targetActiveProviderId ?? remote.activeProviderId,
        baseline: baseline,
      );
    } finally {
      _applying = false;
    }
  }

  Future<void> _applyExtensionChanges(
    ProfileSyncPayload remote, {
    required List<String> skyReposToAdd,
    required List<String> skyReposToRemove,
    required List<Map<String, String>> skyPluginsToApply,
    required List<String> skyPluginsToRemove,
    required List<String> csReposToAdd,
    required List<String> csReposToRemove,
    required List<Map<String, String>> csPluginsToApply,
    required List<String> csPluginsToRemove,
    required List<String> nuvioReposToAdd,
    required List<String> nuvioReposToRemove,
    required Map<String, Map<String, List<String>>> nuvioSettings,
    required List<String> stremioAddonsToAdd,
    required List<String> stremioAddonsToRemove,
    required Map<String, bool> stremioAddonStates,
    required String? targetActiveProviderId,
    required ProfileSyncPayload? baseline,
  }) async {
    // 1. SkyStream extensions & repos
    final extensions = ref.read(extensionsControllerProvider.notifier);
    await extensions.ensureInitialized();
    var extensionState = ref.read(extensionsControllerProvider);

    for (final packageName in skyPluginsToRemove) {
      final installed = extensionState.installedPlugins
          .where((p) => p.packageName == packageName)
          .firstOrNull;
      if (installed == null) continue;
      try {
        await extensions.uninstallPluginFromSync(installed);
      } catch (error) {
        talker.warning(
          '[ProfileSync] uninstall SkyStream plugin $packageName: $error',
        );
      }
      extensionState = ref.read(extensionsControllerProvider);
    }

    final skyRemovedSet = skyReposToRemove.toSet();
    for (final url in skyReposToRemove) {
      if (!extensionState.repositories.any((r) => r.url == url)) continue;
      try {
        await extensions.removeRepositoryFromSync(url);
      } catch (error) {
        talker.warning('[ProfileSync] remove SkyStream repo $url: $error');
      }
      extensionState = ref.read(extensionsControllerProvider);
    }

    final skyRepoQueue = <String>{
      for (final url in skyReposToAdd)
        if (url.isNotEmpty && !skyRemovedSet.contains(url)) url,
      for (final saved in skyPluginsToApply)
        if ((saved['repositoryUrl'] ?? '').isNotEmpty &&
            !skyRemovedSet.contains(saved['repositoryUrl']))
          saved['repositoryUrl']!,
    };
    for (final url in skyRepoQueue) {
      if (extensionState.repositories.any((r) => r.url == url)) continue;
      try {
        await extensions.addRepositoryFromSync(url);
      } catch (error) {
        talker.warning('[ProfileSync] SkyStream repo $url: $error');
      }
      extensionState = ref.read(extensionsControllerProvider);
    }

    // If a followed collection re-added a repository removed on another device,
    // remove it again so removal stays respected.
    for (final url in skyReposToRemove) {
      if (!extensionState.repositories.any((r) => r.url == url)) continue;
      try {
        await extensions.removeRepositoryFromSync(url);
      } catch (error) {
        talker.warning('[ProfileSync] cleanup SkyStream repo $url: $error');
      }
      extensionState = ref.read(extensionsControllerProvider);
    }

    var skyChanged = false;
    for (final saved in skyPluginsToApply) {
      final packageName = saved['packageName'];
      if (packageName == null || packageName.isEmpty) continue;
      var installed = extensionState.installedPlugins
          .where((plugin) => plugin.packageName == packageName)
          .firstOrNull;
      if (installed == null) {
        final candidate =
            _findSkyPlugin(
              extensionState.availablePlugins,
              packageName,
              repositoryUrl: saved['repositoryUrl'],
            ) ??
            _skyPluginFromSaved(saved);
        if (candidate == null) {
          talker.warning(
            '[ProfileSync] SkyStream plugin $packageName is not in a synced repository',
          );
          continue;
        }
        try {
          await extensions.installPluginFromSync(candidate);
          skyChanged = true;
        } catch (error) {
          talker.warning('[ProfileSync] SkyStream plugin $packageName: $error');
        }
        extensionState = ref.read(extensionsControllerProvider);
        installed = extensionState.installedPlugins
            .where((plugin) => plugin.packageName == packageName)
            .firstOrNull;
      }
      if (installed != null) {
        final updatedSettings = await _applySkyPluginSettings(installed, saved);
        if (updatedSettings) skyChanged = true;
      }
    }

    // Sync ExtensionManager immediately instead of waiting for the 500 ms UI
    // bridge debounce, so providers and activeProvider resolve right away.
    if (skyChanged ||
        skyPluginsToRemove.isNotEmpty ||
        (ref.read(extensionManagerProvider).isEmpty &&
            ref.read(extensionsControllerProvider).installedPlugins.isNotEmpty)) {
      await ref
          .read(extensionManagerProvider.notifier)
          .syncFromPlugins(ref.read(extensionsControllerProvider).installedPlugins);
    }

    // 2. CloudStream plugins & repos (install direct plugin downloads first!)
    final cloudstream = ref.read(cloudStreamRepositoryProvider.notifier);
    if (ref.read(cloudStreamRepositoryProvider).isLoading) {
      await cloudstream.load();
    }
    var cloudstreamState = ref.read(cloudStreamRepositoryProvider);

    final csRemoveKeys = csPluginsToRemove.toSet();
    for (final plugin in [...cloudstreamState.installed]) {
      final key =
          '${plugin.info.repositoryUrl}::${plugin.info.internalName}';
      if (!csRemoveKeys.contains(key)) continue;
      try {
        await cloudstream.uninstallFromSync(plugin);
      } catch (error) {
        talker.warning(
          '[ProfileSync] uninstall CloudStream ${plugin.info.internalName}: $error',
        );
      }
      cloudstreamState = ref.read(cloudStreamRepositoryProvider);
    }

    final csRemovedRepos = csReposToRemove.toSet();
    for (final url in csReposToRemove) {
      if (!cloudstreamState.repositories.any((r) => r.url == url)) continue;
      try {
        await cloudstream.removeRepositoryFromSync(url);
      } catch (error) {
        talker.warning('[ProfileSync] remove CloudStream repo $url: $error');
      }
      cloudstreamState = ref.read(cloudStreamRepositoryProvider);
    }

    final csPluginsNeedRepoLookup = <Map<String, String>>[];
    if (cloudstreamState.enabled) {
      for (final saved in csPluginsToApply) {
        final internalName = saved['internalName'];
        final repositoryUrl = saved['repositoryUrl'];
        if (internalName == null ||
            internalName.isEmpty ||
            repositoryUrl == null ||
            repositoryUrl.isEmpty) {
          continue;
        }
        if (cloudstreamState.installed.any(
          (plugin) =>
              plugin.info.internalName == internalName &&
              plugin.info.repositoryUrl == repositoryUrl,
        )) {
          continue;
        }
        final direct =
            _findCloudStreamInRepos(
              cloudstreamState.repositories,
              internalName,
              repositoryUrl,
            ) ??
            _cloudStreamPluginFromSaved(saved);
        if (direct == null) {
          csPluginsNeedRepoLookup.add(saved);
          continue;
        }
        try {
          await cloudstream.installFromSync(direct);
        } catch (error) {
          talker.warning(
            '[ProfileSync] CloudStream plugin $internalName: $error',
          );
        }
        cloudstreamState = ref.read(cloudStreamRepositoryProvider);
      }
    }

    final csRepoQueue = <String>{
      for (final url in csReposToAdd)
        if (url.isNotEmpty && !csRemovedRepos.contains(url)) url,
      for (final saved in csPluginsToApply)
        if ((saved['repositoryUrl'] ?? '').isNotEmpty &&
            !csRemovedRepos.contains(saved['repositoryUrl']))
          saved['repositoryUrl']!,
    };
    if (csRepoQueue.isNotEmpty) {
      await cloudstream.addRepositoriesFromSync(csRepoQueue);
      cloudstreamState = ref.read(cloudStreamRepositoryProvider);
    }

    if (cloudstreamState.enabled && csPluginsNeedRepoLookup.isNotEmpty) {
      for (final saved in csPluginsNeedRepoLookup) {
        final internalName = saved['internalName']!;
        final repositoryUrl = saved['repositoryUrl']!;
        if (cloudstreamState.installed.any(
          (plugin) =>
              plugin.info.internalName == internalName &&
              plugin.info.repositoryUrl == repositoryUrl,
        )) {
          continue;
        }
        final found = _findCloudStreamInRepos(
          cloudstreamState.repositories,
          internalName,
          repositoryUrl,
        );
        if (found == null) {
          talker.warning(
            '[ProfileSync] CloudStream plugin $internalName has no download',
          );
          continue;
        }
        try {
          await cloudstream.installFromSync(found);
        } catch (error) {
          talker.warning(
            '[ProfileSync] CloudStream plugin $internalName: $error',
          );
        }
        cloudstreamState = ref.read(cloudStreamRepositoryProvider);
      }
    }

    // 3. Nuvio repositories & scraper toggles
    final nuvio = ref.read(nuvioRepositoryProvider.notifier);
    if (ref.read(nuvioRepositoryProvider).isLoading) {
      await nuvio.load();
    }
    for (final url in nuvioReposToRemove) {
      try {
        await nuvio.removeRepositoryFromSync(url);
      } catch (error) {
        talker.warning('[ProfileSync] remove Nuvio repo $url: $error');
      }
    }
    if (nuvioReposToAdd.isNotEmpty) {
      await nuvio.addRepositoriesFromSync(
        nuvioReposToAdd,
        onError: (url, error) =>
            talker.warning('[ProfileSync] Nuvio repo $url: $error'),
      );
    }
    for (final repo in ref.read(nuvioRepositoryProvider).repos) {
      final synced = nuvioSettings[repo.manifestUrl];
      if (synced != null) {
        await nuvio.applySyncedScraperState(
          repo.manifestUrl,
          disabledScrapers: (synced['disabled'] ?? const []).toSet(),
          enabledOverrides: (synced['enabled'] ?? const []).toSet(),
        );
      } else if (baseline != null &&
          baseline.nuvioRepoSettings.containsKey(repo.manifestUrl) &&
          (repo.disabledScrapers.isNotEmpty ||
              repo.enabledOverrides.isNotEmpty)) {
        await nuvio.applySyncedScraperState(
          repo.manifestUrl,
          disabledScrapers: const {},
          enabledOverrides: const {},
        );
      }
    }

    // 4. Stremio add-ons & enabled toggles
    final addons = ref.read(addonRepositoryProvider.notifier);
    if (ref.read(addonRepositoryProvider).isLoading) {
      await addons.load();
    }
    for (final url in stremioAddonsToRemove) {
      try {
        await addons.removeFromSync(url);
      } catch (error) {
        talker.warning('[ProfileSync] remove Stremio add-on $url: $error');
      }
    }
    if (stremioAddonsToAdd.isNotEmpty) {
      await addons.installManyFromSync(
        stremioAddonsToAdd,
        onError: (url, error) =>
            talker.warning('[ProfileSync] Stremio add-on $url: $error'),
      );
    }
    for (final addon in ref.read(addonRepositoryProvider).addons) {
      final targetEnabled = stremioAddonStates[addon.manifestUrl];
      if (targetEnabled != null && addon.enabled != targetEnabled) {
        await addons.setEnabledFromSync(addon.manifestUrl, targetEnabled);
      }
    }

    // 5. Active provider resolution
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final manager = ref.read(extensionManagerProvider.notifier);
    if (targetActiveProviderId != null &&
        targetActiveProviderId.isNotEmpty &&
        manager.getProvider(targetActiveProviderId) != null) {
      if (settingsRepo.getActiveProviderId() != targetActiveProviderId) {
        await settingsRepo.setActiveProviderId(targetActiveProviderId);
      }
      ref.read(activeProviderProvider.notifier).reloadFromStorage();
    } else if (ref.read(activeProviderProvider) == null &&
        settingsRepo.getActiveProviderId() == null) {
      final availableProviders = ref.read(extensionManagerProvider);
      if (availableProviders.isNotEmpty) {
        await ref
            .read(activeProviderProvider.notifier)
            .setFromSync(availableProviders.first);
      }
    }
  }

  Future<bool> _applySkyPluginSettings(
    ExtensionPlugin installed,
    Map<String, String> saved,
  ) async {
    final extensionRepo = ref.read(extensionRepositoryProvider);
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final manager = ref.read(extensionManagerProvider.notifier);
    var changed = false;

    final rawDisabled = saved['disabledProviders'];
    final disabledSet = <String>{};
    if (rawDisabled != null && rawDisabled.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawDisabled);
        if (decoded is List) {
          for (final id in decoded) {
            if (id is String && id.isNotEmpty) disabledSet.add(id);
          }
        }
      } catch (_) {}
    }

    final subProviders = manager.getProvidersForPlugin(installed);
    final knownSubIds = <String>{
      for (final sub in subProviders) sub.id,
      ...disabledSet,
    };
    for (final subId in knownSubIds) {
      final key = '${installed.packageName}:_provider_enabled_$subId';
      final currentEnabled = extensionRepo.getExtensionData(key) != 'false';
      final desiredEnabled = !disabledSet.contains(subId);
      if (currentEnabled != desiredEnabled) {
        await extensionRepo.setExtensionData(
          key,
          desiredEnabled ? 'true' : 'false',
        );
        changed = true;
      }
    }

    final targetBaseUrl = saved['customBaseUrl'];
    final currentBaseUrl = settingsRepo.getCustomBaseUrl(installed.packageName);
    if ((targetBaseUrl ?? '') != (currentBaseUrl ?? '')) {
      await settingsRepo.setCustomBaseUrl(
        installed.packageName,
        (targetBaseUrl == null || targetBaseUrl.isEmpty) ? null : targetBaseUrl,
      );
      changed = true;
    }

    if (changed) {
      await manager.reloadPluginFromSync(installed);
    }
    return changed;
  }

  ProfileSyncPayload? _readBaseline() {
    final raw = ref.read(storageServiceProvider).getString(_kBaselineKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return ProfileSyncPayload.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeBaseline(ProfileSyncPayload payload) async {
    await ref
        .read(storageServiceProvider)
        .setString(_kBaselineKey, jsonEncode(payload.toJson()));
  }

  Map<String, int> _readDeletedHistory() {
    final raw = ref.read(storageServiceProvider).getString(_kDeletedHistoryKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is num) '${entry.key}': (entry.value as num).toInt(),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeDeletedHistory(Map<String, int> map) async {
    final storage = ref.read(storageServiceProvider);
    if (map.isEmpty) {
      await storage.remove(_kDeletedHistoryKey);
    } else {
      await storage.setString(_kDeletedHistoryKey, jsonEncode(map));
    }
  }

  Set<String> _readDeletedLibrary() {
    final raw = ref.read(storageServiceProvider).getString(_kDeletedLibraryKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return {};
      return {
        for (final entry in decoded)
          if (entry is String && entry.isNotEmpty) entry,
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeDeletedLibrary(Set<String> urls) async {
    final storage = ref.read(storageServiceProvider);
    if (urls.isEmpty) {
      await storage.remove(_kDeletedLibraryKey);
    } else {
      await storage.setString(
        _kDeletedLibraryKey,
        jsonEncode(urls.toList()..sort()),
      );
    }
  }

  static Map<String, int> _pruneDeletedHistory(
    Map<String, int> input,
    int nowMillis,
  ) {
    final out = <String, int>{};
    for (final entry in input.entries) {
      if (nowMillis - entry.value <= _tombstoneMaxAgeMs) {
        out[entry.key] = entry.value;
      }
    }
    return out;
  }

  static Map<String, bool> _mergeEpisodeOverridesThreeWay({
    required Map<String, bool>? baseline,
    required Map<String, bool> local,
    required Map<String, bool> remote,
  }) {
    if (baseline == null) {
      return {...remote, ...local};
    }
    final merged = Map<String, bool>.from(remote);
    for (final entry in local.entries) {
      final baseVal = baseline[entry.key];
      final remoteVal = remote[entry.key];
      if (baseVal != entry.value || remoteVal == null) {
        merged[entry.key] = entry.value;
      }
    }
    return merged;
  }

  static Map<String, Map<String, List<String>>> _mergeNuvioSettings({
    required Map<String, Map<String, List<String>>>? baseline,
    required Map<String, Map<String, List<String>>> local,
    required Map<String, Map<String, List<String>>> remote,
    required List<String> activeRepos,
  }) {
    bool sameRepoSettings(
      Map<String, List<String>>? a,
      Map<String, List<String>>? b,
    ) {
      final ad = a?['disabled'] ?? const <String>[];
      final ae = a?['enabled'] ?? const <String>[];
      final bd = b?['disabled'] ?? const <String>[];
      final be = b?['enabled'] ?? const <String>[];
      return listEquals(ad, bd) && listEquals(ae, be);
    }

    final merged = <String, Map<String, List<String>>>{};
    for (final url in activeRepos) {
      final l = local[url];
      final r = remote[url];
      final b = baseline?[url];
      Map<String, List<String>>? chosen;
      if (baseline == null) {
        chosen = (l != null && (l['disabled']!.isNotEmpty || l['enabled']!.isNotEmpty))
            ? l
            : r;
      } else {
        final localChanged = !sameRepoSettings(l, b);
        final remoteChanged = !sameRepoSettings(r, b);
        if (localChanged) {
          chosen = l;
        } else if (remoteChanged) {
          chosen = r;
        } else {
          chosen = l ?? r;
        }
      }
      if (chosen != null &&
          ((chosen['disabled']?.isNotEmpty ?? false) ||
              (chosen['enabled']?.isNotEmpty ?? false))) {
        merged[url] = {
          'disabled': List<String>.from(chosen['disabled'] ?? const []),
          'enabled': List<String>.from(chosen['enabled'] ?? const []),
        };
      }
    }
    return merged;
  }

  static Map<String, bool> _mergeStremioStates({
    required Map<String, bool>? baseline,
    required Map<String, bool> local,
    required Map<String, bool> remote,
    required List<String> activeAddons,
  }) {
    final merged = <String, bool>{};
    for (final url in activeAddons) {
      final l = local[url];
      final r = remote[url];
      final b = baseline?[url];
      if (baseline == null) {
        merged[url] = l ?? r ?? true;
      } else if (l != null && l != b) {
        merged[url] = l;
      } else if (r != null && r != b) {
        merged[url] = r;
      } else {
        merged[url] = l ?? r ?? true;
      }
    }
    return merged;
  }

  static String? _mergeActiveProviderId({
    required String? baseline,
    required String? local,
    required String? remote,
  }) {
    if (baseline == null) {
      return (local != null && local.isNotEmpty) ? local : remote;
    }
    if (local != baseline) return local;
    return remote ?? local;
  }

  static bool _hasLocalStringRemoval(List<String> base, List<String> local) {
    final localSet = local.toSet();
    return base.any((item) => !localSet.contains(item));
  }

  static bool _hasLocalMapRemoval(
    List<Map<String, String>> base,
    List<Map<String, String>> local,
    String? Function(Map<String, String>) keyOf,
  ) {
    final localKeys = {
      for (final item in local)
        if (keyOf(item) != null) keyOf(item)!,
    };
    return base.any((item) {
      final key = keyOf(item);
      return key != null && !localKeys.contains(key);
    });
  }

  static bool _payloadDiffersFromRemote(
    ProfileSyncPayload outbound,
    ProfileSyncPayload remote,
  ) {
    if ((outbound.activeProviderId ?? '') != (remote.activeProviderId ?? '')) {
      return true;
    }
    if (!listEquals(outbound.skystreamRepos, remote.skystreamRepos)) return true;
    if (!listEquals(outbound.cloudstreamRepos, remote.cloudstreamRepos)) {
      return true;
    }
    if (!listEquals(outbound.nuvioRepos, remote.nuvioRepos)) return true;
    if (!listEquals(outbound.stremioAddons, remote.stremioAddons)) return true;
    if (!_stringMapListEquals(outbound.skystreamPlugins, remote.skystreamPlugins)) {
      return true;
    }
    if (!_stringMapListEquals(
      outbound.cloudstreamPlugins,
      remote.cloudstreamPlugins,
    )) {
      return true;
    }
    if (!mapEquals(outbound.episodeOverrides, remote.episodeOverrides)) {
      return true;
    }
    if (!mapEquals(outbound.stremioAddonStates, remote.stremioAddonStates)) {
      return true;
    }
    if (!mapEquals(
      outbound.deletedHistoryTimestamps,
      remote.deletedHistoryTimestamps,
    )) {
      return true;
    }
    if (!listEquals(outbound.deletedLibraryUrls, remote.deletedLibraryUrls)) {
      return true;
    }
    if (!_nuvioSettingsEquals(
      outbound.nuvioRepoSettings,
      remote.nuvioRepoSettings,
    )) {
      return true;
    }
    if (outbound.library.length != remote.library.length) return true;
    final remoteLibUrls = {
      for (final item in remote.library)
        if (item['url'] is String) item['url'] as String,
    };
    if (outbound.library.any((item) => !remoteLibUrls.contains(item['url']))) {
      return true;
    }
    if (outbound.history.length != remote.history.length) return true;
    final remoteHistByKey = {
      for (final item in remote.history)
        if (historyKey(item) != null) historyKey(item)!: item,
    };
    for (final item in outbound.history) {
      final key = historyKey(item);
      if (key == null) continue;
      final r = remoteHistByKey[key];
      if (r == null) return true;
      if (historyTimestamp(item) != historyTimestamp(r)) return true;
      final le = item['entry'];
      final re = r['entry'];
      if (le is! Map || re is! Map || le.length != re.length) return true;
      for (final k in le.keys) {
        if (!re.containsKey(k) || le[k] != re[k]) return true;
      }
    }
    return false;
  }

  static bool _stringMapListEquals(
    List<Map<String, String>> a,
    List<Map<String, String>> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!mapEquals(a[i], b[i])) return false;
    }
    return true;
  }

  static bool _nuvioSettingsEquals(
    Map<String, Map<String, List<String>>> a,
    Map<String, Map<String, List<String>>> b,
  ) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null) return false;
      if (!listEquals(entry.value['disabled'], other['disabled'])) return false;
      if (!listEquals(entry.value['enabled'], other['enabled'])) return false;
    }
    return true;
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] is String) {
        return data['error'] as String;
      }
      return error.message ?? 'Sync failed';
    }
    return '$error';
  }
}

CsPluginInfo? _findCloudStreamInRepos(
  List<CsRepository> repositories,
  String internalName,
  String repositoryUrl,
) {
  for (final repository in repositories) {
    for (final plugin in repository.plugins) {
      if (plugin.internalName == internalName &&
          (repository.url == repositoryUrl ||
              plugin.repositoryUrl == repositoryUrl)) {
        return plugin;
      }
    }
  }
  return null;
}

/// The download recorded at sync time, used when the repository's current
/// list does not contain the plugin. The list is what an update comes from;
/// the saved URL is enough to put the plugin and its providers on this device.
CsPluginInfo? _cloudStreamPluginFromSaved(Map<String, String> saved) {
  final internalName = saved['internalName'];
  final url = saved['url'];
  final repositoryUrl = saved['repositoryUrl'];
  if (internalName == null ||
      internalName.isEmpty ||
      url == null ||
      url.isEmpty ||
      repositoryUrl == null ||
      repositoryUrl.isEmpty) {
    return null;
  }
  final name = saved['name'];
  return CsPluginInfo(
    internalName: internalName,
    name: name == null || name.isEmpty ? internalName : name,
    url: url,
    repositoryUrl: repositoryUrl,
  );
}

ExtensionPlugin? _skyPluginFromSaved(Map<String, String> saved) {
  final packageName = saved['packageName'];
  final sourceUrl = saved['url'];
  if (packageName == null ||
      packageName.isEmpty ||
      sourceUrl == null ||
      sourceUrl.isEmpty) {
    return null;
  }
  final name = saved['name'];
  final repositoryId = saved['repositoryId'];
  final repositoryUrl = saved['repositoryUrl'];
  final version = int.tryParse(saved['version'] ?? '') ?? 1;
  return ExtensionPlugin(
    packageName: packageName,
    name: name == null || name.isEmpty ? packageName : name,
    repositoryId:
        repositoryId == null || repositoryId.isEmpty ? 'UnknownRepo' : repositoryId,
    repositoryUrl:
        repositoryUrl == null || repositoryUrl.isEmpty ? null : repositoryUrl,
    sourceUrl: sourceUrl,
    version: version,
  );
}

ExtensionPlugin? _findSkyPlugin(
  Map<String, List<ExtensionPlugin>> available,
  String packageName, {
  String? repositoryUrl,
}) {
  if (repositoryUrl != null && repositoryUrl.isNotEmpty) {
    final fromRepo = available[repositoryUrl];
    if (fromRepo != null) {
      for (final plugin in fromRepo) {
        if (plugin.packageName == packageName) return plugin;
      }
    }
  }
  for (final plugins in available.values) {
    for (final plugin in plugins) {
      if (plugin.packageName == packageName) return plugin;
    }
  }
  return null;
}
