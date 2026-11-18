import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/extensions/models/extension_plugin.dart';
import '../../../../core/extensions/models/extension_repository.dart';
import '../../../../core/extensions/extension_manager.dart';
import '../../../../core/extensions/providers.dart';
import '../../../../core/extensions/services/repository_service.dart';
import '../../../core/models/extension_update_report.dart';
import '../../../core/storage/settings_repository.dart';
import '../../profile_sync/profile_sync_hooks.dart';

part 'extensions_controller.g.dart';

// State for the Extensions Screen (Sealed Class Hierarchy)
sealed class ExtensionsState {
  final List<ExtensionPlugin> installedPlugins;
  final List<ExtensionRepository> repositories;
  final Map<String, List<ExtensionPlugin>> availablePlugins; // Key: Repo URL
  final Map<String, ExtensionPlugin> availableUpdates; // Key: PackageID
  final Set<String> installingPlugins; // Key: PackageName

  const ExtensionsState({
    this.installedPlugins = const [],
    this.repositories = const [],
    this.availablePlugins = const {},
    this.availableUpdates = const {},
    this.installingPlugins = const {},
  });
}

final class ExtensionsLoading extends ExtensionsState {
  const ExtensionsLoading({
    super.installedPlugins,
    super.repositories,
    super.availablePlugins,
    super.availableUpdates,
    super.installingPlugins,
  });
}

final class ExtensionsSuccess extends ExtensionsState {
  const ExtensionsSuccess({
    required super.installedPlugins,
    required super.repositories,
    required super.availablePlugins,
    required super.availableUpdates,
    super.installingPlugins,
  });
}

final class ExtensionsError extends ExtensionsState {
  final String message;

  const ExtensionsError(
    this.message, {
    super.installedPlugins,
    super.repositories,
    super.availablePlugins,
    super.availableUpdates,
    super.installingPlugins,
  });
}

@Riverpod(keepAlive: true)
class ExtensionsController extends _$ExtensionsController {
  /// SharedPreferences key holding the repository URLs the user has added.
  static const String repoUrlsKey = 'extension_repo_urls';

  /// SharedPreferences key holding the collections the user follows - the
  /// repositories that list other repositories instead of plugins, like the
  /// one the "universe" shortcode adds - as JSON: each collection's URL to
  /// the repository URLs it listed when last read. A collection is not a
  /// repository the user sees, so it is kept apart from [repoUrlsKey].
  static const String collectionsKey = 'extension_collections';

  /// SharedPreferences key holding the repository URLs the user removed, so a
  /// collection that still lists one does not bring it back.
  static const String removedRepoUrlsKey = 'extension_removed_repo_urls';

  /// SharedPreferences key holding, as JSON, every plugin package name each
  /// repository has been seen to list: the record new plugins are told
  /// apart by.
  static const String seenPluginsKey = 'extension_seen_plugins';

  bool _initialized = false;

  /// The in-flight [ensureInitialized], so a second caller waits for it instead
  /// of reading [state] while [_init] has not finished.
  Future<void>? _initializing;

  /// Bumped when the installed list is being replaced from disk or by an
  /// install. A disk read that started earlier must not write the empty list
  /// it saw back over plugins a sync just installed.
  int _pluginListEpoch = 0;

  /// Whether a repository the user saved did not load at launch: it may be
  /// the one an older install came from, or another claiming that one's id,
  /// so [_updateFor] matches no install by id until the next launch.
  bool _savedRepositoryMissing = false;

  @override
  ExtensionsState build() {
    return const ExtensionsLoading();
  }

  /// Call once (e.g. from Extensions screen or app startup) to load plugins and repos.
  Future<void> ensureInitialized() {
    final pending = _initializing;
    if (pending != null) return pending;
    if (_initialized) return Future<void>.value();
    _initialized = true;
    final run = _init();
    _initializing = run;
    return run.whenComplete(() {
      if (identical(_initializing, run)) _initializing = null;
    });
  }

  Future<void> _init() async {
    final epoch = ++_pluginListEpoch;
    state = ExtensionsLoading(
      installedPlugins: state.installedPlugins,
      repositories: state.repositories,
      availablePlugins: state.availablePlugins,
      availableUpdates: state.availableUpdates,
      installingPlugins: state.installingPlugins,
    );
    try {
      final storageService = ref.read(pluginStorageServiceProvider);
      final repositoryService = ref.read(repositoryServiceProvider);

      // 1. Load Installed Plugins
      var plugins = await storageService.listInstalledPlugins();
      if (ref.read(settingsRepositoryProvider).getDevLoadAssets()) {
        final assetPlugins = await _loadAssetPlugins();
        plugins.addAll(assetPlugins);
      }

      // 2. Load Repositories.
      //
      // One repository per future rather than a serial loop: the manifest and
      // its plugin lists are independent per repo, and a user with five
      // repositories used to wait for five round trips end to end - on the
      // Extensions screen that is five spinner-seconds they watch.
      final prefs = await SharedPreferences.getInstance();
      final urls = prefs.getStringList(repoUrlsKey) ?? [];

      final fetched = await Future.wait(
        urls.map((url) => _loadRepo(url, repositoryService)),
      );
      _savedRepositoryMissing = fetched.contains(null);

      final repos = <ExtensionRepository>[];
      final available = <String, List<ExtensionPlugin>>{};
      // Rebuilt in the persisted order, which Future.wait preserves, so the
      // list the user sees does not reshuffle itself by network latency.
      for (final entry in fetched) {
        if (entry == null) continue;
        repos.add(entry.repo);
        available[entry.repo.url] = entry.plugins;
      }

      // If another disk read or install ran while _init() awaited the network,
      // re-read the installed plugins from disk so nothing installed meanwhile
      // is overwritten with the stale pre-network snapshot.
      if (epoch != _pluginListEpoch) {
        final latestDisk = await storageService.listInstalledPlugins();
        if (ref.read(settingsRepositoryProvider).getDevLoadAssets()) {
          latestDisk.addAll(await _loadAssetPlugins());
        }
        final merged = <String, ExtensionPlugin>{
          for (final p in latestDisk) p.packageName: p,
          for (final p in state.installedPlugins) p.packageName: p,
        };
        plugins = merged.values.toList();
      }

      if (!_savedRepositoryMissing) await _pinOlderInstalls(plugins, repos);

      if (!ref.mounted) return;
      // 3. Set Final State Once
      state = ExtensionsSuccess(
        installedPlugins: plugins,
        repositories: repos,
        availablePlugins: available,
        availableUpdates: state.availableUpdates,
        installingPlugins: state.installingPlugins,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = ExtensionsError(
        e.toString(),
        installedPlugins: state.installedPlugins,
        repositories: state.repositories,
        availablePlugins: state.availablePlugins,
        availableUpdates: state.availableUpdates,
        installingPlugins: state.installingPlugins,
      );
    }
  }

  void _notifySync() {
    if (ref.mounted) {
      ref.read(profileSyncHooksProvider).onLocalChange?.call();
    }
  }

  /// All persisted repository and collection URLs, including any whose
  /// manifests failed to load at launch.
  Future<List<String>> persistedRepositoryUrls() async {
    await ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    return <String>{
      ..._savedRepoUrls(prefs),
      ..._readUrlMap(prefs, collectionsKey).keys,
      for (final repo in state.repositories) repo.url,
    }.toList();
  }

  /// Gives each install from before installs kept their repository's address
  /// the address of the one repository in [repos] declaring its repository's
  /// id, in its install record, once: from then on that address alone
  /// updates it, and a repository taking the id later cannot step in. Only
  /// on a launch where every saved repository loaded, so none is missing that
  /// may declare the id too; with two declaring it, it is left as it is, and
  /// so is one whose id names no repository (see [_claimants]).
  Future<void> _pinOlderInstalls(
    List<ExtensionPlugin> plugins,
    List<ExtensionRepository> repos,
  ) async {
    final storage = ref.read(pluginStorageServiceProvider);
    for (var i = 0; i < plugins.length; i++) {
      final plugin = plugins[i];
      if (plugin.repositoryUrl != null) continue;
      final claimants = _claimants(plugin.repositoryId, repos);
      if (claimants.length != 1) continue;
      try {
        final pinned = await storage.pinRepositoryUrl(plugin, claimants.single);
        if (pinned != null) plugins[i] = pinned;
      } catch (e) {
        if (kDebugMode) debugPrint('Could not pin ${plugin.packageName}: $e');
      }
    }
  }

  /// The addresses of the repositories in [repos] that declare [repositoryId]
  /// as theirs, whether they list a given plugin or not. None for an id that
  /// names no repository ([ExtensionPlugin.isPlaceholderRepositoryId]): one
  /// declaring it as its own would be the claimant of every plugin installed
  /// from a file, say, or bundled with the app.
  static List<String> _claimants(
    String repositoryId,
    Iterable<ExtensionRepository> repos,
  ) => [
    if (!ExtensionPlugin.isPlaceholderRepositoryId(repositoryId))
      for (final repo in repos)
        if (repo.packageName == repositoryId) repo.url,
  ];

  /// Fetches one repository and its plugin lists, or null if it is
  /// unreachable or malformed. A bad repository must not take the others down
  /// with it, which is why the catch is here rather than around [Future.wait].
  Future<({ExtensionRepository repo, List<ExtensionPlugin> plugins})?>
  _loadRepo(String url, RepositoryService repositoryService) async {
    try {
      final repo = await repositoryService.fetchRepository(url);
      if (repo == null) return null;
      return (
        repo: repo,
        plugins: await repositoryService.getRepoPlugins(repo),
      );
    } catch (e) {
      if (kDebugMode) debugPrint("Failed to load persisted repo $url: $e");
      return null;
    }
  }

  Future<void> loadInstalledPlugins() async {
    final epoch = ++_pluginListEpoch;
    state = ExtensionsLoading(
      installedPlugins: state.installedPlugins,
      repositories: state.repositories,
      availablePlugins: state.availablePlugins,
      availableUpdates: state.availableUpdates,
      installingPlugins: state.installingPlugins,
    );
    try {
      final storageService = ref.read(pluginStorageServiceProvider);
      final plugins = await storageService.listInstalledPlugins();

      // Load Asset Plugins if enabled
      if (ref.read(settingsRepositoryProvider).getDevLoadAssets()) {
        final assetPlugins = await _loadAssetPlugins();
        if (kDebugMode) {
          debugPrint(
            "ExtensionsController: Loaded ${assetPlugins.length} asset plugins",
          );
        }
        plugins.addAll(assetPlugins);
      } else {
        if (kDebugMode) {
          debugPrint("ExtensionsController: Asset loading disabled");
        }
      }

      if (epoch != _pluginListEpoch) return;
      state = ExtensionsSuccess(
        installedPlugins: plugins,
        repositories: state.repositories,
        availablePlugins: state.availablePlugins,
        availableUpdates: state.availableUpdates,
        installingPlugins: state.installingPlugins,
      );
    } catch (e) {
      if (epoch != _pluginListEpoch) return;
      state = ExtensionsError(
        e.toString(),
        installedPlugins: state.installedPlugins,
        repositories: state.repositories,
        availablePlugins: state.availablePlugins,
        availableUpdates: state.availableUpdates,
        installingPlugins: state.installingPlugins,
      );
    }
  }

  Future<List<ExtensionPlugin>> _loadAssetPlugins() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets();

      // Find all .json manifest files. Each manifest.json represents a plugin.
      final manifestFiles = assets
          .where(
            (key) => key.startsWith('assets/plugins/') && key.endsWith('.json'),
          )
          .toList();

      final plugins = <ExtensionPlugin>[];

      for (final configFile in manifestFiles) {
        final content = await rootBundle.loadString(configFile);
        // The .js file is expected to have the same name as the .json file
        final jsFile = configFile.replaceFirst('.json', '.js');

        final plugin = _parseJsonManifest(content, jsFile);
        if (plugin != null) {
          plugins.add(plugin);
        }
      }
      return plugins;
    } catch (e) {
      if (kDebugMode) debugPrint("Error loading asset plugins: $e");
      return [];
    }
  }

  ExtensionPlugin? _parseJsonManifest(String content, String jsFilePath) {
    try {
      final json = Map<String, dynamic>.from(jsonDecode(content) as Map);

      // Dart 3 Pattern Matching for manifest extraction
      final (packageName, id) = (
        json['packageName'] as String?,
        json['id'] as String?,
      );

      if (packageName == null && id == null) {
        json['packageName'] = "local.asset.${jsFilePath.split('/').last}";
      }

      // Apply .debug suffix for asset plugins
      if (jsFilePath.startsWith('assets/')) {
        final currentPkg = (json['packageName'] ?? json['id']).toString();
        if (!currentPkg.endsWith('.debug')) {
          json['packageName'] = "$currentPkg.debug";
        }
      }

      // Important: The sourceUrl for the provider is the .js file
      json['url'] = jsFilePath;

      return ExtensionPlugin.fromJson(json, 'LocalAssets');
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error parsing json manifest for $jsFilePath: $e");
      }
      return null;
    }
  }

  /// The launch-time pass over the user's plugins, run on every launch and on
  /// any connection: reads each collection the user follows and adds the
  /// repositories it newly lists, notes the plugins that are new in each
  /// repository, and installs every update.
  ///
  /// Returns what changed, for the launch toasts. With no repositories and no
  /// collections there is nothing to check - nothing could ever be found - so
  /// it returns an empty report without a single request.
  ///
  /// It used to skip a launch within six hours of the last check, and any
  /// launch on a metered connection. Plugins scrape sites that change under
  /// them, and a stale one is the difference between a title playing and not,
  /// so neither is a reason to wait any more. The check is one manifest per
  /// repository and collection; downloads follow only for plugins whose
  /// version moved.
  Future<ExtensionUpdateReport> autoUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    if (_savedRepoUrls(prefs).isEmpty &&
        _readUrlMap(prefs, collectionsKey).isEmpty) {
      return const ExtensionUpdateReport();
    }

    await ensureInitialized();
    final newRepositories = await _followCollections();
    final newPlugins = await _findNewPlugins();
    await checkForUpdates();
    final updated = await installAvailableUpdates();
    return ExtensionUpdateReport(
      updated: updated,
      newRepositories: newRepositories,
      newPlugins: newPlugins,
    );
  }

  /// Reads every collection the user follows and adds the repositories it
  /// lists that the user does not have - apart from any the user removed.
  /// Returns the names of the repositories added, under their collection's
  /// name.
  ///
  /// A collection used to be read once, when it was added: a repository
  /// published into it afterwards never reached anyone who already had it.
  ///
  /// Quietly: a collection or repository that does not load is skipped for
  /// this launch and tried on the next, without raising the Extensions
  /// screen's error over whatever the user is doing.
  Future<Map<String, List<String>>> _followCollections() async {
    final prefs = await SharedPreferences.getInstance();
    final repositoryService = ref.read(repositoryServiceProvider);
    final added = <String, List<String>>{};

    for (final url in _readUrlMap(prefs, collectionsKey).keys) {
      final ExtensionRepository? collection;
      try {
        collection = await repositoryService.fetchRepository(url);
      } catch (e) {
        if (kDebugMode) debugPrint('Could not read collection $url: $e');
        continue;
      }
      if (collection == null || collection.includedRepos.isEmpty) continue;
      await _recordCollection(url, collection.includedRepos);

      // Read per collection, not once before the loop: an earlier turn may
      // have added repositories this one lists too, or followed a collection
      // it lists. A followed one is read on its own turn, or - followed just
      // now - had its repositories added along with it.
      final saved = _savedRepoUrls(prefs).toSet();
      final removed = _removedRepoUrls(prefs);
      final followed = _readUrlMap(prefs, collectionsKey);
      final fresh = <String>[
        for (final listed in collection.includedRepos)
          if (!saved.contains(listed) &&
              !removed.contains(listed) &&
              !followed.containsKey(listed))
            listed,
      ];
      if (fresh.isEmpty) continue;

      final before = <String>{for (final repo in state.repositories) repo.url};
      for (final listed in fresh) {
        await _addRepository(listed, <String>{url}, background: true);
      }
      final names = <String>[
        for (final repo in state.repositories)
          if (!before.contains(repo.url)) repo.name,
      ];
      if (names.isNotEmpty) {
        (added[collection.name] ??= <String>[]).addAll(names);
      }
    }
    return added;
  }

  /// The plugins each repository lists that no launch has seen it list
  /// before, under the repository's name - leaving out any already
  /// installed. Nothing is installed: which plugins to run is the user's
  /// call.
  ///
  /// A repository with nothing on record - on the first launch to look, or
  /// added since the last one - is only recorded. That is learning what is
  /// already there, not news: the user saw the repository arrive. And a
  /// record only ever grows, so a plugin list that fails to download for a
  /// launch does not make its plugins new again when it is back.
  Future<Map<String, List<String>>> _findNewPlugins() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = _readUrlMap(prefs, seenPluginsKey);
    final installed = <String>{
      for (final plugin in state.installedPlugins) plugin.packageName,
    };
    final found = <String, List<String>>{};

    for (final repo in state.repositories) {
      final listed = state.availablePlugins[repo.url];
      if (listed == null) continue;
      final before = seen[repo.url];
      final known = <String>{...?before};
      final names = <String>[];
      for (final plugin in listed) {
        final unseen = known.add(plugin.packageName);
        if (unseen &&
            before != null &&
            !installed.contains(plugin.packageName)) {
          names.add(plugin.name);
        }
      }
      seen[repo.url] = known.toList();
      if (names.isNotEmpty) (found[repo.name] ??= <String>[]).addAll(names);
    }

    // A repository the user removed takes its record with it.
    final saved = _savedRepoUrls(prefs).toSet();
    seen.removeWhere((url, _) => !saved.contains(url));
    await _writeUrlMap(prefs, seenPluginsKey, seen);
    return found;
  }

  /// Records that the user follows [url], and what it lists now.
  Future<void> _recordCollection(String url, List<String> listed) async {
    final prefs = await SharedPreferences.getInstance();
    final followed = _readUrlMap(prefs, collectionsKey);
    followed[url] = listed;
    await _writeUrlMap(prefs, collectionsKey, followed);
  }

  static List<String> _savedRepoUrls(SharedPreferences prefs) =>
      prefs.getStringList(repoUrlsKey) ?? const <String>[];

  static Set<String> _removedRepoUrls(SharedPreferences prefs) => <String>{
    ...?prefs.getStringList(removedRepoUrlsKey),
  };

  /// A map of URL to strings, stored as JSON under [key]; empty when there
  /// is none or it cannot be read.
  static Map<String, List<String>> _readUrlMap(
    SharedPreferences prefs,
    String key,
  ) {
    final raw = prefs.getString(key);
    if (raw == null) return <String, List<String>>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, List<String>>{};
      return <String, List<String>>{
        for (final entry in decoded.entries)
          if (entry.value is List)
            '${entry.key}': <String>[
              for (final value in entry.value as List)
                if (value is String) value,
            ],
      };
    } on FormatException {
      return <String, List<String>>{};
    }
  }

  static Future<void> _writeUrlMap(
    SharedPreferences prefs,
    String key,
    Map<String, List<String>> map,
  ) => prefs.setString(key, jsonEncode(map));

  /// Records which installed plugins have a newer version published, in
  /// [ExtensionsState.availableUpdates]. Installs nothing itself.
  ///
  /// Finding and installing are separate steps: [autoUpdate] calls
  /// [installAvailableUpdates] after this, and the Extensions screen's
  /// per-plugin update button renders off the same map for anything that did
  /// not go in.
  ///
  /// Returns the display names of the plugins with an update waiting.
  Future<List<String>> checkForUpdates() async {
    final updates = <String, ExtensionPlugin>{
      for (final installed in state.installedPlugins)
        installed.packageName: ?_updateFor(installed),
    };

    // Written even when empty, so a plugin the user has since updated by hand
    // stops advertising an update - but not when that would be a no-op state
    // churn, and not over an error state whose message is still on screen.
    final unchanged =
        updates.length == state.availableUpdates.length &&
        updates.keys.every(state.availableUpdates.containsKey);
    if (!unchanged && state is! ExtensionsError) {
      state = ExtensionsSuccess(
        installedPlugins: state.installedPlugins,
        repositories: state.repositories,
        availablePlugins: state.availablePlugins,
        availableUpdates: updates,
        installingPlugins: state.installingPlugins,
      );
    }

    return updates.values.map((plugin) => plugin.name).toList();
  }

  /// The newest version of [installed] that the repository it came from
  /// lists, when that is newer than what is installed.
  ///
  /// Only from that repository. Any repository can list a plugin under any
  /// name - and a repository a collection adds on its own is followed without
  /// anyone choosing it - so matching by name across all of them let one
  /// replace another's plugin with code of its own, which the launch-time
  /// update then installed. An install keeps the address it came from; one
  /// from before that is matched by its repository's id instead, and only
  /// while a single repository the user follows declares that id - listing
  /// the plugin or not, since an id is whatever a repository says it is, and
  /// counting only the ones that list it let a repository taking another's id
  /// step in whenever that one stopped listing the plugin. Never on a launch
  /// where a saved repository did not load, when the count is not known.
  ExtensionPlugin? _updateFor(ExtensionPlugin installed) {
    bool lists(ExtensionPlugin online) =>
        online.packageName == installed.packageName &&
        (installed.repositoryUrl != null ||
            online.repositoryId == installed.repositoryId);

    final from = installed.repositoryUrl;
    final List<String> sources;
    if (from != null) {
      sources = [
        for (final url in state.availablePlugins.keys)
          if (sameAddress(url, from)) url,
      ];
    } else {
      sources = _claimants(installed.repositoryId, state.repositories);
      if (_savedRepositoryMissing || sources.length != 1) return null;
    }

    ExtensionPlugin? newest;
    for (final online in sources.expand(
      (url) => state.availablePlugins[url] ?? const <ExtensionPlugin>[],
    )) {
      if (!lists(online) || online.version <= installed.version) continue;
      if (newest == null || online.version > newest.version) newest = online;
    }
    return newest;
  }

  /// Whether [a] and [b] are two spellings of one repository's address:
  /// scheme and host in any case, a default port written out or not, escapes
  /// in any case, with or without a trailing slash. Another scheme, port,
  /// path, query or fragment is another address.
  static bool sameAddress(String a, String b) {
    String key(String url) {
      final trimmed = url.trim().replaceAll(RegExp(r'/+$'), '');
      return Uri.tryParse(trimmed)?.toString() ?? trimmed;
    }

    return key(a) == key(b);
  }

  Future<void> addRepository(String url, {Set<String>? visitedUrls}) async {
    await _addRepository(url, visitedUrls ?? <String>{}, background: false);
    if (visitedUrls == null && state is! ExtensionsError) {
      _notifySync();
    }
  }

  Future<void> addRepositoryFromSync(String url) =>
      _addRepository(url, <String>{}, background: true);

  /// [background] is for additions nobody asked for in the moment - the
  /// repositories a collection newly lists, found on launch: a failure is
  /// logged and skipped instead of put on screen, and a repository the user
  /// has, or removed, is left as it is.
  ///
  /// A code the user enters is kept as the short link it was found at: later
  /// launches look that code up, and none of the other spellings a typed
  /// code is tried in, which anyone could register after it.
  Future<void> _addRepository(
    String url,
    Set<String> visitedUrls, {
    required bool background,
  }) async {
    // What the user entered, rather than what a collection listed.
    final entered = !background && visitedUrls.isEmpty;

    // Cycle Detection
    if (visitedUrls.contains(url)) {
      if (kDebugMode) {
        debugPrint("Recursion detected: skipping repeated repo $url");
      }
      return;
    }
    visitedUrls.add(url);

    state = ExtensionsLoading(
      installedPlugins: state.installedPlugins,
      repositories: state.repositories,
      availablePlugins: state.availablePlugins,
      availableUpdates: state.availableUpdates,
      installingPlugins: state.installingPlugins,
    );
    try {
      final repositoryService = ref.read(repositoryServiceProvider);
      final fetched = await repositoryService.fetchRepository(url);
      final shortLink = entered ? fetched?.shortLink : null;
      final repo = shortLink != null ? fetched?.withUrl(shortLink) : fetched;
      final address = shortLink ?? url;
      visitedUrls.add(address);
      if (repo != null) {
        // Handle Recursive Repositories (Megarepo)
        if (repo.includedRepos.isNotEmpty) {
          if (kDebugMode) {
            debugPrint(
              "Repo ${repo.name} contains ${repo.includedRepos.length} included repos",
            );
          }
          // Followed from now on: every launch reads it again, for the
          // repositories it lists later.
          await _recordCollection(address, repo.includedRepos);
          final prefs = await SharedPreferences.getInstance();
          for (final subRepoUrl in repo.includedRepos) {
            if (background &&
                (_savedRepoUrls(prefs).contains(subRepoUrl) ||
                    _removedRepoUrls(prefs).contains(subRepoUrl))) {
              continue;
            }
            await _addRepository(
              subRepoUrl,
              visitedUrls,
              background: background,
            );
          }

          // If the repo is PURELY a container (no plugin of its own),
          // do NOT add it to the list or persist it.
          if (repo.pluginLists.isEmpty) {
            state = ExtensionsSuccess(
              installedPlugins: state.installedPlugins,
              repositories: state.repositories,
              availablePlugins: state.availablePlugins,
              availableUpdates: state.availableUpdates,
              installingPlugins: state.installingPlugins,
            );
            return;
          }
        }

        final currentRepos = List<ExtensionRepository>.from(state.repositories);
        if (!currentRepos.any((element) => element.url == repo.url)) {
          currentRepos.add(repo);

          // Persist URL (Only top-level or unique ones)
          final prefs = await SharedPreferences.getInstance();
          final urls = prefs.getStringList(repoUrlsKey) ?? [];
          if (!urls.contains(address)) {
            urls.add(address);
            await prefs.setStringList(repoUrlsKey, urls);
          }
          // Added on purpose, so no longer one the user removed.
          final removed = prefs.getStringList(removedRepoUrlsKey);
          if (removed != null && removed.remove(address)) {
            await prefs.setStringList(removedRepoUrlsKey, removed);
          }
        }

        final plugins = await repositoryService.getRepoPlugins(repo);
        final currentAvailable = Map<String, List<ExtensionPlugin>>.from(
          state.availablePlugins,
        );
        currentAvailable[repo.url] = plugins;

        state = ExtensionsSuccess(
          repositories: currentRepos,
          availablePlugins: currentAvailable,
          installedPlugins: state.installedPlugins,
          availableUpdates: state.availableUpdates,
          installingPlugins: state.installingPlugins,
        );
      } else {
        if (kDebugMode) debugPrint("Failed to parse repository at $url");
        if (visitedUrls.length == 1 && !background) {
          state = ExtensionsError(
            "Failed to parse repository",
            installedPlugins: state.installedPlugins,
            repositories: state.repositories,
            availablePlugins: state.availablePlugins,
            availableUpdates: state.availableUpdates,
            installingPlugins: state.installingPlugins,
          );
        } else {
          state = ExtensionsSuccess(
            installedPlugins: state.installedPlugins,
            repositories: state.repositories,
            availablePlugins: state.availablePlugins,
            availableUpdates: state.availableUpdates,
            installingPlugins: state.installingPlugins,
          );
        }
      }
    } catch (e) {
      if (background) {
        if (kDebugMode) debugPrint('Could not add repository $url: $e');
        state = ExtensionsSuccess(
          installedPlugins: state.installedPlugins,
          repositories: state.repositories,
          availablePlugins: state.availablePlugins,
          availableUpdates: state.availableUpdates,
          installingPlugins: state.installingPlugins,
        );
        return;
      }
      state = ExtensionsError(
        e.toString(),
        installedPlugins: state.installedPlugins,
        repositories: state.repositories,
        availablePlugins: state.availablePlugins,
        availableUpdates: state.availableUpdates,
        installingPlugins: state.installingPlugins,
      );
    }
  }

  /// Removes the repository at [url] and uninstalls the plugins installed
  /// from it, as the confirmation dialog tells the user it will.
  Future<void> removeRepository(String url) async {
    await removeRepositoryFromSync(url);
    _notifySync();
  }

  Future<void> removeRepositoryFromSync(String url) async {
    try {
      final removed = state.repositories.where((r) => r.url == url).firstOrNull;
      final currentRepos = List<ExtensionRepository>.from(state.repositories);
      currentRepos.removeWhere((r) => r.url == url);

      final currentAvailable = Map<String, List<ExtensionPlugin>>.from(
        state.availablePlugins,
      );
      currentAvailable.remove(url);

      // Update State with Repo Removed. The installed list follows below,
      // once the repository's plugins are uninstalled.
      state = ExtensionsSuccess(
        installedPlugins: state.installedPlugins,
        repositories: currentRepos,
        availablePlugins: currentAvailable,
        availableUpdates: state.availableUpdates,
        installingPlugins: state.installingPlugins,
      );

      // Remove persistence
      final prefs = await SharedPreferences.getInstance();
      final urls = prefs.getStringList(repoUrlsKey) ?? [];
      urls.remove(url);
      await prefs.setStringList(repoUrlsKey, urls);
      await _rememberRemoval(prefs, url, urls);
      if (removed != null) {
        await _uninstallPluginsFrom(removed, remaining: currentRepos);
      }

      // Reload installed plugins to update the UI
      await loadInstalledPlugins();
    } catch (e) {
      state = ExtensionsError(
        "Failed to remove repository: $e",
        installedPlugins: state.installedPlugins,
        repositories: state.repositories,
        availablePlugins: state.availablePlugins,
        availableUpdates: state.availableUpdates,
        installingPlugins: state.installingPlugins,
      );
    }
  }

  /// Uninstalls every plugin installed from [repo], which an install records
  /// as the repository's id beside the plugin. Plugins installed from other
  /// repositories stay, even ones [repo] lists too - and so does everything
  /// when the same repository is still in [remaining] under another address,
  /// as a raw GitHub link and its jsDelivr mirror would be.
  ///
  /// A plugin that will not delete is left installed, where the user can see
  /// it and uninstall it; it does not keep the others.
  Future<void> _uninstallPluginsFrom(
    ExtensionRepository repo, {
    required List<ExtensionRepository> remaining,
  }) async {
    final repoId = repo.packageName;
    // An id that names no repository takes nothing: it is what every plugin
    // installed from a file, say, is recorded under.
    if (ExtensionPlugin.isPlaceholderRepositoryId(repoId) ||
        remaining.any((other) => other.packageName == repoId)) {
      return;
    }

    final storage = ref.read(pluginStorageServiceProvider);
    final gone = <String>{};
    for (final plugin in await storage.listInstalledPlugins()) {
      if (plugin.repositoryId != repoId) continue;
      try {
        await storage.deletePlugin(plugin);
        gone.add(plugin.packageName);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Could not uninstall ${plugin.packageName}: $e');
        }
      }
    }
    if (gone.isEmpty) return;

    // The installed list itself is re-read from disk by the caller.
    state = ExtensionsSuccess(
      installedPlugins: state.installedPlugins,
      repositories: state.repositories,
      availablePlugins: state.availablePlugins,
      availableUpdates: <String, ExtensionPlugin>{
        for (final entry in state.availableUpdates.entries)
          if (!gone.contains(entry.key)) entry.key: entry.value,
      },
      installingPlugins: state.installingPlugins,
    );
  }

  /// Notes that the user removed [url], so a collection that lists it does
  /// not bring it back, and stops following every collection that leaves
  /// with none of its repositories kept: the user has left it, and would
  /// otherwise have no way to stop its new repositories arriving. [saved] is
  /// the user's repositories after the removal.
  Future<void> _rememberRemoval(
    SharedPreferences prefs,
    String url,
    List<String> saved,
  ) async {
    final removed = prefs.getStringList(removedRepoUrlsKey) ?? <String>[];
    if (!removed.contains(url)) {
      removed.add(url);
      await prefs.setStringList(removedRepoUrlsKey, removed);
    }

    final followed = _readUrlMap(prefs, collectionsKey);
    final before = followed.length;
    // A collection inside another is kept by what it lists, and keeps its
    // parent while it is followed, so leaving one can leave the next.
    var gone = <String>{url};
    while (gone.isNotEmpty) {
      final left = <String>{
        for (final MapEntry(key: collection, value: listed) in followed.entries)
          if (listed.any(gone.contains) &&
              !listed.any(
                (entry) => saved.contains(entry) || followed.containsKey(entry),
              ))
            collection,
      };
      followed.removeWhere((collection, _) => left.contains(collection));
      gone = left;
    }
    if (followed.length != before) {
      await _writeUrlMap(prefs, collectionsKey, followed);
    }
  }

  Future<void> installPlugin(ExtensionPlugin plugin) async {
    await installPlugins([plugin]);
  }

  Future<void> installPluginFromSync(ExtensionPlugin plugin) async {
    await _installPlugins([plugin], quiet: false, notifySync: false);
  }

  /// Installs every update [checkForUpdates] recorded and returns the display
  /// names of the ones that went in.
  ///
  /// Plugins are kept current without a trip to the Extensions screen - the
  /// launch check calls this straight after finding them, and the user is
  /// told afterwards what changed - the way Nuvio scrapers already are.
  ///
  /// One plugin at a time, each on its own: [installPlugins] gives up on the
  /// whole batch at the first exception, and one plugin with a dead download
  /// must not keep the rest back. Quietly, too: a background update that
  /// fails leaves its entry in [ExtensionsState.availableUpdates] for the
  /// update button to retry, instead of raising the Extensions screen's error
  /// dialog over whatever the user is doing.
  Future<List<String>> installAvailableUpdates() async {
    final updated = <String>[];
    for (final plugin in state.availableUpdates.values.toList()) {
      await installPlugins([plugin], quiet: true);
      if (!state.availableUpdates.containsKey(plugin.packageName)) {
        updated.add(plugin.name);
      }
    }
    return updated;
  }

  /// [quiet] is for installs nobody asked for in the moment: a failure clears
  /// the spinner and leaves the plugin as it was, rather than putting the
  /// controller in [ExtensionsError].
  Future<void> installPlugins(
    List<ExtensionPlugin> plugins, {
    bool quiet = false,
  }) => _installPlugins(plugins, quiet: quiet, notifySync: !quiet);

  Future<void> _installPlugins(
    List<ExtensionPlugin> plugins, {
    required bool quiet,
    required bool notifySync,
  }) async {
    // An inventory read already in flight saw the list before this install.
    ++_pluginListEpoch;
    final newInstalling = Set<String>.from(state.installingPlugins);
    for (final p in plugins) {
      newInstalling.add(p.packageName);
    }

    state = ExtensionsSuccess(
      installedPlugins: state.installedPlugins,
      repositories: state.repositories,
      availablePlugins: state.availablePlugins,
      availableUpdates: state.availableUpdates,
      installingPlugins: newInstalling,
    );
    try {
      final repositoryService = ref.read(repositoryServiceProvider);
      final storageService = ref.read(pluginStorageServiceProvider);

      for (final plugin in plugins) {
        File? savedFile;

        // Standard HTTP Download
        savedFile = await repositoryService.downloadPlugin(plugin.sourceUrl);

        if (savedFile != null) {
          final installedPlugin = await storageService.installPlugin(
            savedFile.path,
            plugin.repositoryId,
            repositoryUrl: plugin.repositoryUrl,
            packageName: plugin.packageName,
          );
          final targetPlugin = installedPlugin ?? plugin;

          // Await ExtensionManager loading dynamic/static providers BEFORE stopping the spinner!
          try {
            await ref
                .read(extensionManagerProvider.notifier)
                .reloadPlugin(targetPlugin);
          } catch (e) {
            if (kDebugMode) {
              debugPrint("Error initializing plugin providers: $e");
            }
          }

          // Clear this plugin from availableUpdates
          final newUpdates = Map<String, ExtensionPlugin>.from(
            state.availableUpdates,
          )..remove(targetPlugin.packageName);

          final currentInstalling = Set<String>.from(state.installingPlugins)
            ..remove(targetPlugin.packageName);

          final newInstalled = List<ExtensionPlugin>.from(
            state.installedPlugins,
          );
          final existingIndex = newInstalled.indexWhere(
            (p) => p.packageName == targetPlugin.packageName,
          );
          if (existingIndex >= 0) {
            newInstalled[existingIndex] = targetPlugin;
          } else {
            newInstalled.add(targetPlugin);
          }

          state = ExtensionsSuccess(
            installedPlugins: newInstalled,
            repositories: state.repositories,
            availablePlugins: state.availablePlugins,
            availableUpdates: newUpdates,
            installingPlugins: currentInstalling,
          );

          if (await savedFile.exists()) {
            await savedFile.delete();
          }
        } else {
          // Download failed, remove from installing set
          final currentInstalling = Set<String>.from(state.installingPlugins)
            ..remove(plugin.packageName);
          state = ExtensionsSuccess(
            installedPlugins: state.installedPlugins,
            repositories: state.repositories,
            availablePlugins: state.availablePlugins,
            availableUpdates: state.availableUpdates,
            installingPlugins: currentInstalling,
          );
        }
      }
      await loadInstalledPlugins();
      if (notifySync) _notifySync();
    } catch (e) {
      final currentInstalling = Set<String>.from(state.installingPlugins);
      for (final p in plugins) {
        currentInstalling.remove(p.packageName);
      }
      if (quiet) {
        if (kDebugMode) debugPrint('Background plugin install failed: $e');
        state = ExtensionsSuccess(
          installedPlugins: state.installedPlugins,
          repositories: state.repositories,
          availablePlugins: state.availablePlugins,
          availableUpdates: state.availableUpdates,
          installingPlugins: currentInstalling,
        );
        return;
      }
      state = ExtensionsError(
        e.toString(),
        installedPlugins: state.installedPlugins,
        repositories: state.repositories,
        availablePlugins: state.availablePlugins,
        availableUpdates: state.availableUpdates,
        installingPlugins: currentInstalling,
      );
    }
  }

  Future<void> updatePlugin(ExtensionPlugin plugin) async {
    await installPlugin(plugin);
  }

  Future<void> uninstallPlugin(ExtensionPlugin plugin) async {
    await uninstallPluginFromSync(plugin);
    _notifySync();
  }

  Future<void> uninstallPluginFromSync(ExtensionPlugin plugin) async {
    final storageService = ref.read(pluginStorageServiceProvider);
    await storageService.deletePlugin(plugin);
    await loadInstalledPlugins();
  }
}
