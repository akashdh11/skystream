import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/addons/data/addon_repository.dart';
import '../../../core/cloudstream/cloudstream_models.dart';
import '../../../core/cloudstream/cloudstream_repository.dart';
import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/extensions/models/extension_plugin.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/nuvio/data/nuvio_repository.dart';
import '../../../core/storage/episode_watch_repository.dart';
import '../../../core/storage/library_repository.dart';
import '../../../core/storage/secure_token_storage.dart';
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

  Timer? _debounceTimer;
  bool _applying = false;

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

    ref.read(profileSyncHooksProvider).onLocalChange = scheduleQuickSync;
    ref.listen(episodeWatchRevisionProvider, (previous, next) {
      if (previous == null) return;
      scheduleQuickSync();
    });
    ref.onDispose(() {
      _debounceTimer?.cancel();
      final hooks = ref.read(profileSyncHooksProvider);
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

  Future<void> _checkTokenAndInitialSync() async {
    final token = await ref.read(secureTokenStorageProvider).read(_kTokenKey);
    if (!ref.mounted) return;
    if (token == null || token.isEmpty) return;
    state = state.copyWith(isLoggedIn: true);
    if (state.autoSync) {
      unawaited(syncNow(installMissingExtensions: true));
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
      await ref.read(secureTokenStorageProvider).write(_kTokenKey, token);

      state = state.copyWith(
        serverUrl: cleanUrl,
        username: signedInAs,
        isLoggedIn: true,
        isSyncing: false,
      );
      return syncNow(installMissingExtensions: true);
    } catch (error) {
      talker.error('[ProfileSync] Login failed', error);
      state = state.copyWith(isSyncing: false, lastError: _errorMessage(error));
      return false;
    }
  }

  Future<void> logout() async {
    _debounceTimer?.cancel();
    await ref.read(secureTokenStorageProvider).delete(_kTokenKey);
    await ref.read(storageServiceProvider).remove(_kUsernameKey);
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
  }

  /// Pushes a few seconds after playback or a bookmark change so a pause
  /// does not open a request on every position tick.
  void scheduleQuickSync() {
    if (_applying || !state.isLoggedIn || !state.autoSync) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 3), () {
      if (state.isSyncing) {
        scheduleQuickSync();
        return;
      }
      unawaited(syncNow(installMissingExtensions: false));
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
    final skystreamRepos = [
      for (final repository in extensionState.repositories) repository.url,
    ];
    final skystreamPlugins = [
      for (final plugin in extensionState.installedPlugins)
        {
          'packageName': plugin.packageName,
          'repositoryUrl': plugin.repositoryUrl ?? '',
        },
    ];

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
    final nuvioRepos = [
      for (final repository in ref.read(nuvioRepositoryProvider).repos)
        repository.manifestUrl,
    ];

    final addons = ref.read(addonRepositoryProvider.notifier);
    if (ref.read(addonRepositoryProvider).isLoading) {
      await addons.load();
    }
    final stremioAddons = [
      for (final addon in ref.read(addonRepositoryProvider).addons)
        addon.manifestUrl,
    ];

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
    );
  }

  Future<bool> syncNow({bool installMissingExtensions = true}) async {
    if (!state.isLoggedIn || state.isSyncing || state.serverUrl.isEmpty) {
      return false;
    }
    final token = await ref.read(secureTokenStorageProvider).read(_kTokenKey);
    if (token == null || token.isEmpty) return false;

    state = state.copyWith(isSyncing: true, clearError: true);
    try {
      final localPayload = await collectLocalProfile();
      final response = await ref
          .read(dioClientProvider)
          .post<Map<String, dynamic>>(
            '${state.serverUrl}/v1/profile/sync',
            data: localPayload.toJson(),
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );
      final body = response.data;
      if (body != null) {
        await applyRemoteProfile(
          ProfileSyncPayload.fromJson(body),
          installMissingExtensions: installMissingExtensions,
        );
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      await ref
          .read(storageServiceProvider)
          .setPlayerSetting(_kLastSyncedKey, now);
      if (!ref.mounted) return true;
      state = state.copyWith(isSyncing: false, lastSyncedAt: now);
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
  }) async {
    _applying = true;
    try {
      final storage = ref.read(storageServiceProvider);
      final toWrite = newerHistoryEntries(
        local: storage.getAllHistoryEntries(),
        remote: remote.history,
      );
      if (toWrite.isNotEmpty) {
        await storage.restoreHistoryEntries(toWrite);
        ref.read(watchHistoryProvider.notifier).refresh();
      }

      await ref
          .read(episodeWatchRepositoryProvider)
          .mergeOverrides(remote.episodeOverrides);

      final library = ref.read(libraryRepositoryProvider);
      var libraryChanged = false;
      for (final raw in remote.library) {
        try {
          final item = MultimediaItem.fromJson(raw);
          if (item.url.isEmpty || library.isInLibrary(item.url)) continue;
          await library.addToLibrary(item);
          libraryChanged = true;
        } catch (error) {
          talker.warning('[ProfileSync] skipped a library item: $error');
        }
      }
      if (libraryChanged) {
        ref.read(libraryProvider.notifier).refresh();
      }

      if (!installMissingExtensions) return;
      await _installMissingExtensions(remote);
    } finally {
      _applying = false;
    }
  }

  Future<void> _installMissingExtensions(ProfileSyncPayload remote) async {
    final extensions = ref.read(extensionsControllerProvider.notifier);
    await extensions.ensureInitialized();
    var extensionState = ref.read(extensionsControllerProvider);
    for (final url in remote.skystreamRepos) {
      if (url.isEmpty) continue;
      if (extensionState.repositories.any(
        (repository) => repository.url == url,
      )) {
        continue;
      }
      try {
        await extensions.addRepository(url);
      } catch (error) {
        talker.warning('[ProfileSync] SkyStream repo $url: $error');
      }
      extensionState = ref.read(extensionsControllerProvider);
    }
    for (final saved in remote.skystreamPlugins) {
      final packageName = saved['packageName'];
      if (packageName == null || packageName.isEmpty) continue;
      if (extensionState.installedPlugins.any(
        (plugin) => plugin.packageName == packageName,
      )) {
        continue;
      }
      final candidate = _findSkyPlugin(
        extensionState.availablePlugins,
        packageName,
      );
      if (candidate == null) continue;
      try {
        await extensions.installPlugin(candidate);
      } catch (error) {
        talker.warning('[ProfileSync] SkyStream plugin $packageName: $error');
      }
      extensionState = ref.read(extensionsControllerProvider);
    }

    final cloudstream = ref.read(cloudStreamRepositoryProvider.notifier);
    if (ref.read(cloudStreamRepositoryProvider).isLoading) {
      await cloudstream.load();
    }
    var cloudstreamState = ref.read(cloudStreamRepositoryProvider);
    for (final url in remote.cloudstreamRepos) {
      if (url.isEmpty) continue;
      if (cloudstreamState.repositories.any(
        (repository) => repository.url == url,
      )) {
        continue;
      }
      try {
        await cloudstream.addRepository(url);
      } catch (error) {
        talker.warning('[ProfileSync] CloudStream repo $url: $error');
      }
      cloudstreamState = ref.read(cloudStreamRepositoryProvider);
    }
    if (cloudstreamState.enabled) {
      for (final saved in remote.cloudstreamPlugins) {
        final internalName = saved['internalName'];
        final repositoryUrl = saved['repositoryUrl'];
        if (internalName == null ||
            internalName.isEmpty ||
            repositoryUrl == null ||
            repositoryUrl.isEmpty) {
          continue;
        }
        final alreadyInstalled = cloudstreamState.installed.any(
          (plugin) =>
              plugin.info.internalName == internalName &&
              plugin.info.repositoryUrl == repositoryUrl,
        );
        if (alreadyInstalled) continue;
        CsPluginInfo? found;
        for (final repository in cloudstreamState.repositories) {
          for (final plugin in repository.plugins) {
            if (plugin.internalName == internalName &&
                (repository.url == repositoryUrl ||
                    plugin.repositoryUrl == repositoryUrl)) {
              found = plugin;
              break;
            }
          }
          if (found != null) break;
        }
        if (found == null) continue;
        try {
          await cloudstream.install(found);
        } catch (error) {
          talker.warning(
            '[ProfileSync] CloudStream plugin $internalName: $error',
          );
        }
        cloudstreamState = ref.read(cloudStreamRepositoryProvider);
      }
    }

    final nuvio = ref.read(nuvioRepositoryProvider.notifier);
    if (ref.read(nuvioRepositoryProvider).isLoading) {
      await nuvio.load();
    }
    var nuvioState = ref.read(nuvioRepositoryProvider);
    for (final url in remote.nuvioRepos) {
      if (url.isEmpty) continue;
      if (nuvioState.repos.any((repository) => repository.manifestUrl == url)) {
        continue;
      }
      try {
        await nuvio.addRepository(url);
      } catch (error) {
        talker.warning('[ProfileSync] Nuvio repo $url: $error');
      }
      nuvioState = ref.read(nuvioRepositoryProvider);
    }

    final addons = ref.read(addonRepositoryProvider.notifier);
    if (ref.read(addonRepositoryProvider).isLoading) await addons.load();
    for (final url in remote.stremioAddons) {
      if (url.isEmpty || addons.isInstalled(url)) continue;
      try {
        await addons.install(url);
      } catch (error) {
        talker.warning('[ProfileSync] Stremio add-on $url: $error');
      }
    }
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] is String)
        return data['error'] as String;
      return error.message ?? 'Sync failed';
    }
    return '$error';
  }
}

ExtensionPlugin? _findSkyPlugin(
  Map<String, List<ExtensionPlugin>> available,
  String packageName,
) {
  for (final plugins in available.values) {
    for (final plugin in plugins) {
      if (plugin.packageName == packageName) return plugin;
    }
  }
  return null;
}
