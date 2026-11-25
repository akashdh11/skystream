import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'base_provider.dart';

import 'dart:io';
import 'engine/js_engine.dart';
import 'models/extension_plugin.dart';
import 'providers/js_based_provider.dart';
import 'services/plugin_storage_service.dart';
import 'providers.dart';
import '../storage/settings_repository.dart';
import '../storage/extension_repository.dart';
import '../logger/app_logger.dart';
import '../../features/profile_sync/profile_sync_hooks.dart';

part 'extension_manager.g.dart';

@Riverpod(keepAlive: true)
class ExtensionManager extends _$ExtensionManager {
  JsEngineService? _engine;
  PluginStorageService? _storageService;
  Future<void>? _syncLock;

  // Shared script read futures — one per plugin package. Sub-providers that
  // share the same JS file reuse the same Future so the file is read only once.
  final Map<String, Future<String?>> _pluginScriptFutures = {};
  final Map<String, List<PluginSubProvider>> _dynamicProvidersMap = {};
  final Map<String, List<PluginSettingDefinition>> _dynamicSettingsMap = {};
  final Map<String, JsBasedProvider> _settingsProviders = {};

  List<PluginSubProvider> getProvidersForPlugin(ExtensionPlugin plugin) {
    final dynamicList = _dynamicProvidersMap[plugin.packageName];
    if (dynamicList != null && dynamicList.isNotEmpty) {
      return dynamicList;
    }
    return plugin.providers ?? const [];
  }

  /// Returns settings declared by the plugin's optional JS
  /// `getSettings()` function. Static `settings` in the manifest are
  /// also accepted, with JS definitions taking precedence by key.
  Future<List<PluginSettingDefinition>> getSettingsForPlugin(
    ExtensionPlugin plugin,
  ) async {
    final cached = _dynamicSettingsMap[plugin.packageName];
    if (cached != null) return cached;

    final byKey = <String, PluginSettingDefinition>{};

    final manifestSettings = plugin.manifest['settings'];
    if (manifestSettings is List) {
      for (final raw
          in manifestSettings.take(100).whereType<Map<dynamic, dynamic>>()) {
        final setting = PluginSettingDefinition.fromJson(
          Map<String, dynamic>.from(raw),
        );
        if (setting.key.isNotEmpty) {
          byKey[setting.key] = setting;
        }
      }
    }

    try {
      JsBasedProvider? provider;
      final loaded = _firstLoadedProvider(plugin.packageName);
      if (loaded is JsBasedProvider) {
        provider = loaded;
      } else {
        provider = await _createSettingsProvider(plugin);
      }

      if (provider != null) {
        final scriptSettings = await provider.getSettings();
        for (final setting in scriptSettings) {
          byKey[setting.key] = setting;
        }
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'ExtensionManager: settings load failed for '
          '${plugin.packageName}: $error',
        );
      }
    }

    final result = byKey.values.toList(growable: false);
    _dynamicSettingsMap[plugin.packageName] = result;
    return result;
  }

  Future<JsBasedProvider?> _createSettingsProvider(
    ExtensionPlugin plugin,
  ) async {
    final cached = _settingsProviders[plugin.packageName];
    if (cached != null) return cached;
    if (_engine == null || _storageService == null) return null;

    final path = await _storageService!.getPluginJsPath(plugin);
    if (!path.startsWith('assets/') && !await File(path).exists()) {
      return null;
    }

    final baseNamespace = plugin.packageName.replaceAll(
      RegExp(r'[^a-zA-Z0-9]'),
      '_',
    );
    final customBaseUrl = ref
        .read(settingsRepositoryProvider)
        .getCustomBaseUrl(plugin.packageName);

    final provider = JsBasedProvider(
      _engine!,
      path,
      packageName: plugin.packageName,
      jsPackageName: plugin.packageName,
      namespace: '${baseNamespace}__settings',
      manifest: plugin.manifest,
      customBaseUrl: customBaseUrl,
    );
    _settingsProviders[plugin.packageName] = provider;
    return provider;
  }

  void _clearSettingsRuntime(String packageName) {
    _dynamicSettingsMap.remove(packageName);
    final provider = _settingsProviders.remove(packageName);
    final namespace = provider?.namespace;
    if (namespace != null && namespace.isNotEmpty) {
      _engine?.unload(namespace);
    }
  }

  void _clearPluginRuntime(String packageName) {
    _pluginScriptFutures.remove(packageName);
    _dynamicProvidersMap.remove(packageName);
    _clearSettingsRuntime(packageName);
  }

  @override
  List<SkyStreamProvider> build() {
    _engine = ref.watch(jsEngineProvider);
    _storageService = ref.watch(pluginStorageServiceProvider);
    return [];
  }

  /// Providers from other extension systems (CloudStream), by source. They sit beside the JS
  /// plugins' providers in [state] and are left alone by plugin syncs.
  final Map<String, List<SkyStreamProvider>> _externalProviders = {};

  /// Sources expected to report through [setExternalProviders] that have not yet.
  final Set<String> _pendingExternalSources = {};

  /// Declares that [source] will report its providers later. Until it does, a saved active
  /// provider that is missing is waited for rather than forgotten.
  void expectExternalSource(String source) {
    if (!_externalProviders.containsKey(source)) _pendingExternalSources.add(source);
  }

  /// Whether a source declared with [expectExternalSource] has not reported yet.
  bool hasPendingExternalSources() => _pendingExternalSources.isNotEmpty;

  /// Replaces [source]'s providers with [providers].
  void setExternalProviders(String source, List<SkyStreamProvider> providers) {
    final previous = {
      for (final p in _externalProviders[source] ?? const <SkyStreamProvider>[]) p.packageName,
    };
    _externalProviders[source] = List.unmodifiable(providers);
    _pendingExternalSources.remove(source);
    state = [
      ...state.where((p) => !previous.contains(p.packageName)),
      ...providers,
    ];
  }

  bool _isExternal(SkyStreamProvider provider) =>
      _externalProviders.values.any((list) => list.contains(provider));

  /// Called by the extensions feature when installed plugins change, so core
  /// stays independent of the feature.
  Future<void> syncFromPlugins(List<ExtensionPlugin> installed) async {
    await _syncPlugins(installed);
  }

  Future<void> _syncPlugins(List<ExtensionPlugin> installed) async {
    if (_engine == null || _storageService == null) return;

    // Only one sync runs at a time.
    final prevLock = _syncLock ?? Future.value();
    final completer = Completer<void>();
    _syncLock = completer.future;

    try {
      await prevLock;

      final activePackageName = ref
          .read(settingsRepositoryProvider)
          .getActiveProviderId();

      // For subproviders the stored ID is "parentPkg::SubId"; extract the parent
      // package name so sorting and priority loading target the right plugin.
      final String? activeParentPackageName = activePackageName == null
          ? null
          : (activePackageName.contains('::')
                ? activePackageName.substring(
                    0,
                    activePackageName.indexOf('::'),
                  )
                : activePackageName);

      // Sort plugins: Active first
      final sortedPlugins = List<ExtensionPlugin>.from(installed);
      if (activeParentPackageName != null) {
        sortedPlugins.sort((a, b) {
          if (a.packageName == activeParentPackageName) return -1;
          if (b.packageName == activeParentPackageName) return 1;
          return 0;
        });
      }

      // 1. Priority Load: Active Provider (if needs loading)
      if (activeParentPackageName != null) {
        try {
          final activePlugin = sortedPlugins.firstWhere(
            (p) => p.packageName == activeParentPackageName,
          );
          final existing = _hasLoadedProviders(activeParentPackageName);
          if (!existing) {
            final loaded = await _loadPlugin(activePlugin);
            // Insert all subproviders in one state update so the ActiveProvider
            // listener sees them all at once — adding one-at-a-time would fire
            // the listener before the target subprovider is present.
            if (loaded.isNotEmpty) {
              final newState = [...state];
              for (final p in loaded) {
                if (!newState.any((e) => e.packageName == p.packageName)) {
                  newState.add(p);
                }
              }
              state = newState;
            }
          }
        } catch (_) {
          // Active plugin not found in installed list, ignore
        }
      }

      // 2. The rest, three at a time.
      const batchSize = 3;

      for (int i = 0; i < sortedPlugins.length; i += batchSize) {
        final batch = sortedPlugins.skip(i).take(batchSize);
        final batchLoads = <Future<List<SkyStreamProvider>>>[];

        for (final plugin in batch) {
          final alreadyLoaded = _hasLoadedProviders(plugin.packageName);

          bool needsLoad = !alreadyLoaded;
          if (alreadyLoaded) {
            final existing = _firstLoadedProvider(plugin.packageName);
            if (existing != null &&
                plugin.version.toString() != existing.version) {
              _clearPluginRuntime(plugin.packageName);
              _removeProvidersForPackage(plugin.packageName);
              needsLoad = true;
            }
          }

          if (needsLoad && plugin.packageName != activeParentPackageName) {
            batchLoads.add(_loadPlugin(plugin));
          }
        }

        if (batchLoads.isNotEmpty) {
          final results = await Future.wait(batchLoads);
          final loadedInBatch = results.expand((l) => l).toList();
          if (loadedInBatch.isNotEmpty) {
            state = [...state, ...loadedInBatch];
          }
        }
      }

      // Unload Removed Plugins
      final installedPackageNames = installed.map((e) => e.packageName).toSet();

      final providersToRemove = <SkyStreamProvider>[];

      for (final provider in state) {
        if (_isExternal(provider)) continue;
        if (!_belongsToInstalled(provider.packageName, installedPackageNames)) {
          providersToRemove.add(provider);
        }
      }

      if (providersToRemove.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            "ExtensionManager: Unloading ${providersToRemove.length} providers",
          );
        }
        final newState = List<SkyStreamProvider>.from(state);
        for (final p in providersToRemove) {
          if (kDebugMode) {
            debugPrint(
              "ExtensionManager: Removing ${p.packageName} (${p.name})",
            );
          }
          newState.remove(p);
          if (p is JsBasedProvider) {
            final ns = p.namespace;
            if (ns != null && ns.isNotEmpty) {
              // Releases the plugin's globalThis slot and runs GC in the
              // worker isolate. The .qbc bytecode cache lives in the
              // per-plugin directory, which PluginStorageService already
              // clears on delete and on install.
              _engine?.unload(ns);
            }
          }
        }
        state = newState;
      }

      ref.read(pluginSyncCompleteProvider.notifier).set(true);
    } finally {
      if (!completer.isCompleted) completer.complete();
      if (_syncLock == completer.future) _syncLock = null;
    }
  }

  /// Reloads a plugin, picking up preference changes (domain switch, provider toggles).
  Future<void> reloadPlugin(ExtensionPlugin plugin) async {
    await reloadPluginFromSync(plugin);
    if (ref.mounted) {
      ref.read(profileSyncHooksProvider).onLocalChange?.call();
    }
  }

  /// Reloads a plugin without triggering profile sync.
  Future<void> reloadPluginFromSync(ExtensionPlugin plugin) async {
    if (_engine == null || _storageService == null) return;
    _clearPluginRuntime(plugin.packageName);
    _removeProvidersForPackage(plugin.packageName);
    final loaded = await _loadPlugin(plugin);
    for (final p in loaded) {
      _addProvider(p);
    }
  }

  void runGC() {
    _engine?.runGC();
  }

  Future<void> updateCustomBaseUrl(String packageName, String? url) async {
    final settings = ref.read(settingsRepositoryProvider);
    await settings.setCustomBaseUrl(packageName, url);
    if (ref.mounted) {
      ref.read(profileSyncHooksProvider).onLocalChange?.call();
    }
  }

  /// Returns true if the user has enabled this sub-provider (default: true).
  bool _isSubProviderEnabled(String packageName, String providerId) {
    final storage = ref.read(extensionRepositoryProvider);
    final saved = storage.getExtensionData(
      '$packageName:_provider_enabled_$providerId',
    );
    return saved == null || saved == 'true';
  }

  /// Registers shell providers for a plugin. JS is NOT evaluated here — it is
  /// loaded lazily on the first search/getHome/getDetails/loadStreams call.
  /// Sub-providers sharing the same JS file reuse one shared read Future so the
  /// file is only read from disk once regardless of how many sub-providers exist.
  ///
  /// Dynamic provider mode: when plugin.json has `"providers": []` (empty array),
  /// a bootstrap JsBasedProvider is created to call `getProviders()` and fetch
  /// the live list, then fan-out into sub-providers exactly like the static path.
  Future<List<SkyStreamProvider>> _loadPlugin(ExtensionPlugin plugin) async {
    if (_engine == null || _storageService == null) return [];
    try {
      // SHA-256 verification of plugin.js against meta.json's installSha256
      // is disabled; PluginStorageService.verifyIntegrity is kept intact for a
      // signed-plugin distribution mode. Uncomment the block below to enable.
      //
      // final integrityOk = await _storageService!.verifyIntegrity(plugin);
      // if (!integrityOk) {
      //   if (kDebugMode) {
      //     debugPrint(
      //       "ExtensionManager: REFUSING to load ${plugin.packageName} — "
      //       "plugin.js hash does not match meta.json installSha256. "
      //       "Re-install the plugin to clear the warning.",
      //     );
      //   }
      //   talker.error(
      //     "Plugin integrity check failed for ${plugin.packageName} — refusing to load.",
      //   );
      //   return [];
      // }

      final path = await _storageService!.getPluginJsPath(plugin);
      if (kDebugMode) {
        debugPrint("ExtensionManager: Registering lazy shells from: $path");
      }
      talker.debug("ExtensionManager: Registering lazy shells from: $path");

      if (!path.startsWith('assets/')) {
        if (!await File(path).exists()) {
          if (kDebugMode) {
            debugPrint("ExtensionManager: JS File does NOT exist at $path");
          }
          return [];
        }
      }

      // One shared file-read Future per plugin package. All sub-providers call
      // this closure; only the first call starts the read, the rest await it.
      Future<String?> sharedScriptLoader() {
        return _pluginScriptFutures.putIfAbsent(plugin.packageName, () async {
          try {
            if (path.startsWith('assets/')) {
              return await rootBundle.loadString(path);
            } else {
              return await File(path).readAsString();
            }
          } catch (e) {
            // Remove so a subsequent call can retry after a transient error.
            _pluginScriptFutures.remove(plugin.packageName)?.ignore();
            return null;
          }
        });
      }

      final baseNamespace = plugin.packageName.replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '_',
      );

      // ── Dynamic provider mode ─────────────────────────────────────────────
      // One bootstrap shell calls getProviders(), then the live list fans out
      // into namespaced sub-providers exactly like the static path. Bootstrap
      // and sub-providers share the same .qbc bytecode, so this costs no extra
      // JS evaluation over a static provider list.
      if (plugin.providers != null && plugin.providers!.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            "ExtensionManager: Dynamic providers mode for ${plugin.packageName}",
          );
        }
        talker.debug(
          "ExtensionManager: Dynamic providers mode for ${plugin.packageName}",
        );

        // Bootstrap shell — uses the plugin's own namespace so the bytecode
        // path is stable and shared with all sub-providers below.
        final bootstrap = JsBasedProvider(
          _engine!,
          path,
          packageName: plugin.packageName,
          namespace: '${baseNamespace}__bootstrap',
          manifest: plugin.manifest,
          scriptLoader: sharedScriptLoader,
        );

        // Precompile bytecode so subsequent sub-provider loads are instant.
        await bootstrap.precompile();

        // Fetch the live provider list. This triggers one loadBytes()/loadScript()
        // call — the same cost the first sub-provider would incur anyway.
        final dynamicProviders = await bootstrap.getProviders();

        if (dynamicProviders.isNotEmpty) {
          _dynamicProvidersMap[plugin.packageName] = dynamicProviders;
        } else {
          if (kDebugMode) {
            debugPrint(
              "ExtensionManager: getProviders() returned empty list for ${plugin.packageName}",
            );
          }
          talker.warning(
            "ExtensionManager: getProviders() returned empty list for ${plugin.packageName}",
          );
          return [];
        }

        if (kDebugMode) {
          debugPrint(
            "ExtensionManager: Got ${dynamicProviders.length} dynamic providers for ${plugin.packageName}",
          );
        }
        talker.debug(
          "ExtensionManager: Got ${dynamicProviders.length} dynamic providers for ${plugin.packageName}",
        );

        // Fan-out — identical structure to the static path below.
        final results = <SkyStreamProvider>[];
        for (final sub in dynamicProviders) {
          if (!_isSubProviderEnabled(plugin.packageName, sub.id)) continue;
          final subId = sub.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
          results.add(
            JsBasedProvider(
              _engine!,
              path,
              packageName: '${plugin.packageName}::${sub.id}',
              jsPackageName: plugin.packageName,
              namespace: '${baseNamespace}__$subId',
              forcedName: sub.name,
              manifest: plugin.manifest,
              customBaseUrl: sub.baseUrl,
              providerId: sub.baseUrl == null ? sub.id : null,
              scriptLoader: sharedScriptLoader,
            ),
          );
        }
        if (kDebugMode) {
          debugPrint(
            "ExtensionManager: Registered ${results.length} dynamic sub-providers for ${plugin.packageName}",
          );
        }
        // No-ops since bootstrap already compiled the .qbc for this path.
        for (final p in results) {
          if (p is JsBasedProvider) p.precompile().ignore();
        }
        return results;
      }

      // ── Static provider fan-out ───────────────────────────────────────────
      if (plugin.providers != null && plugin.providers!.isNotEmpty) {
        final results = <SkyStreamProvider>[];
        for (final sub in plugin.providers!) {
          if (!_isSubProviderEnabled(plugin.packageName, sub.id)) continue;
          final subId = sub.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
          results.add(
            JsBasedProvider(
              _engine!,
              path,
              packageName: '${plugin.packageName}::${sub.id}',
              jsPackageName: plugin.packageName,
              namespace: '${baseNamespace}__$subId',
              forcedName: sub.name,
              manifest: plugin.manifest,
              customBaseUrl: sub.baseUrl,
              providerId: sub.baseUrl == null ? sub.id : null,
              scriptLoader: sharedScriptLoader,
            ),
          );
        }
        if (kDebugMode) {
          debugPrint(
            "ExtensionManager: Registered ${results.length} lazy sub-providers for ${plugin.packageName}",
          );
        }
        // Pre-compile bytecode for each sub-provider (no-ops if already fresh).
        for (final p in results) {
          if (p is JsBasedProvider) p.precompile().ignore();
        }
        return results;
      }

      // ── Single provider shell ─────────────────────────────────────────────
      final settings = ref.read(settingsRepositoryProvider);
      final customBaseUrl = settings.getCustomBaseUrl(plugin.packageName);
      final provider = JsBasedProvider(
        _engine!,
        path,
        packageName: plugin.packageName,
        namespace: baseNamespace,
        manifest: plugin.manifest,
        customBaseUrl: customBaseUrl,
        scriptLoader: sharedScriptLoader,
      );
      if (kDebugMode) {
        debugPrint(
          "ExtensionManager: Registered lazy shell for ${plugin.packageName}",
        );
        talker.debug(
          "ExtensionManager: Registered lazy shell for ${plugin.packageName}",
        );
      }
      // Pre-compile bytecode (no-op if already fresh).
      provider.precompile().ignore();
      return [provider];
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Failed to register plugin ${plugin.name}: $e");
      }
      talker.error("Failed to register plugin ${plugin.name}: $e");
      return [];
    }
  }

  // ── Helper methods ────────────────────────────────────────────────────────

  /// True if any loaded provider belongs to [packageName] (direct or sub-provider).
  bool _hasLoadedProviders(String packageName) {
    return state.any(
      (p) =>
          p.packageName == packageName ||
          p.packageName.startsWith('$packageName::'),
    );
  }

  /// First loaded provider belonging to [packageName], or null.
  SkyStreamProvider? _firstLoadedProvider(String packageName) {
    try {
      return state.firstWhere(
        (p) =>
            p.packageName == packageName ||
            p.packageName.startsWith('$packageName::'),
      );
    } catch (_) {
      return null;
    }
  }

  /// Removes all loaded providers belonging to [packageName] from state.
  void _removeProvidersForPackage(String packageName) {
    state = state
        .where(
          (p) =>
              p.packageName != packageName &&
              !p.packageName.startsWith('$packageName::'),
        )
        .toList();
  }

  /// True if [providerPackageName] belongs to one of the installed packages.
  /// Handles synthetic sub-provider names (`parentPkg::subId`).
  bool _belongsToInstalled(
    String providerPackageName,
    Set<String> installedPackageNames,
  ) {
    if (installedPackageNames.contains(providerPackageName)) return true;
    final sep = providerPackageName.lastIndexOf('::');
    if (sep > 0) {
      return installedPackageNames.contains(
        providerPackageName.substring(0, sep),
      );
    }
    return false;
  }

  void _addProvider(SkyStreamProvider provider) {
    if (!state.any((p) => p.packageName == provider.packageName)) {
      if (kDebugMode) {
        debugPrint(
          "ExtensionManager: Adding provider to state: ${provider.name} (${provider.packageName})",
        );
      }
      state = [...state, provider];
    } else {
      if (kDebugMode) {
        debugPrint(
          "ExtensionManager: Provider ${provider.packageName} already in state.",
        );
      }
    }
  }

  List<SkyStreamProvider> getAllProviders() => state;

  SkyStreamProvider? getProvider(String packageName) {
    try {
      return state.firstWhere((p) => p.packageName == packageName);
    } catch (_) {
      return null;
    }
  }
}

// Tracks whether the initial active provider is still being resolved.
@Riverpod(keepAlive: true)
class ProviderResolutionLoading extends _$ProviderResolutionLoading {
  @override
  bool build() {
    return true;
  }

  void set(bool value) => state = value;
}

// Tracks whether the initial plugin sync has completed at least once.
@Riverpod(keepAlive: true)
class PluginSyncComplete extends _$PluginSyncComplete {
  @override
  bool build() {
    return false;
  }

  void set(bool value) => state = value;
}

@Riverpod(keepAlive: true)
class ActiveProvider extends _$ActiveProvider {
  String? _targetProviderId;
  bool _initialLoadDone = false;

  @override
  SkyStreamProvider? build() {
    // Safety net: when sync finishes but no further extensionManager state
    // change fires, check one final time for the target provider.
    ref.listen(pluginSyncCompleteProvider, (_, complete) {
      if (!complete || _targetProviderId == null || state != null) return;
      final p = ref
          .read(extensionManagerProvider.notifier)
          .getProvider(_targetProviderId!);
      if (p != null) {
        state = p;
        _targetProviderId = null;
        ref.read(providerResolutionLoadingProvider.notifier).set(false);
      } else if (!ref
          .read(extensionManagerProvider.notifier)
          .hasPendingExternalSources()) {
        // Full sync finished and provider is truly gone — clear stale setting.
        _targetProviderId = null;
        ref.read(settingsRepositoryProvider).setActiveProviderId(null);
        ref.read(providerResolutionLoadingProvider.notifier).set(false);
      }
    });

    ref.listen(extensionManagerProvider, (previous, next) {
      if (!_initialLoadDone) {
        _initialLoadDone = true;
        _loadFromStorage(next);
        return;
      }

      if (_targetProviderId != null && state == null) {
        final p = ref
            .read(extensionManagerProvider.notifier)
            .getProvider(_targetProviderId!);
        if (p != null) {
          state = p;
          _targetProviderId = null;
          ref.read(providerResolutionLoadingProvider.notifier).set(false);
        } else if (ref.read(pluginSyncCompleteProvider) &&
            !ref
                .read(extensionManagerProvider.notifier)
                .hasPendingExternalSources()) {
          // Full sync is done and the provider is still missing — it was
          // removed/uninstalled. Clear the stale setting.
          _targetProviderId = null;
          ref.read(settingsRepositoryProvider).setActiveProviderId(null);
          ref.read(providerResolutionLoadingProvider.notifier).set(false);
        }
        // Otherwise sync is still in progress — keep waiting.
      } else if (state != null) {
        final currentPackageName = state!.packageName;
        final found = next.where((p) => p.packageName == currentPackageName);

        if (found.isEmpty) {
          state = null;
          _targetProviderId = currentPackageName;
          ref.read(providerResolutionLoadingProvider.notifier).set(false);
        } else {
          final match = found.first;
          if (match != state) {
            state = match;
          }
        }
      }
    });

    // ref.listen only fires on changes, so a value extensionManager already
    // has when we subscribe never reaches the listener. Deferred to after
    // build because other providers cannot be modified during build.
    Future.microtask(() {
      _initialLoadDone = true;
      _loadFromStorage(ref.read(extensionManagerProvider));
    });

    return null;
  }

  void _loadFromStorage(List<SkyStreamProvider> currentProviders) {
    final storage = ref.read(settingsRepositoryProvider);
    final id = storage.getActiveProviderId();

    if (id == null) {
      state = null;
      _targetProviderId = null;
      ref.read(providerResolutionLoadingProvider.notifier).set(false);
    } else {
      _targetProviderId = id;
      final p = ref.read(extensionManagerProvider.notifier).getProvider(id);
      if (p != null) {
        state = p;
        _targetProviderId = null;
        ref.read(providerResolutionLoadingProvider.notifier).set(false);
      } else {
        // Not loaded yet. _targetProviderId stays set so the listener picks it
        // up when extensionManagerProvider updates later, and loading stays
        // true until then.
        state = null;
      }
    }
  }

  /// Re-evaluates the stored active provider id against currently loaded
  /// providers (e.g., after profile sync installs plugins).
  void reloadFromStorage() {
    _loadFromStorage(ref.read(extensionManagerProvider));
  }

  Future<void> set(SkyStreamProvider? provider) async {
    await setFromSync(provider);
    if (ref.mounted) {
      ref.read(profileSyncHooksProvider).onLocalChange?.call();
    }
  }

  Future<void> setFromSync(SkyStreamProvider? provider) async {
    state = provider;
    _targetProviderId = null;
    ref.read(providerResolutionLoadingProvider.notifier).set(false);

    final storage = ref.read(settingsRepositoryProvider);
    await storage.setActiveProviderId(provider?.packageName);
  }
}
