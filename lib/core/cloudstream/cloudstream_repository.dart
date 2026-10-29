import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cs3_engine/cs3_engine.dart';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../extensions/extension_manager.dart';
import '../extensions/providers.dart';
import '../logger/app_logger.dart';
import '../models/extension_update_report.dart';
import '../network/dio_client_provider.dart';
import '../services/ani_zip_service.dart';
import '../../features/settings/presentation/app_version_provider.dart';
import 'cloudstream_engine.dart';
import 'cloudstream_models.dart';
import 'cloudstream_provider.dart';
import 'extension_notices.dart';
import 'extension_ui/extension_ui_session.dart';

part 'cloudstream_repository.g.dart';

/// A screen the engine opened by itself, for a window the person waits on, with its extension's name.
typedef WaitingScreen = ({ExtensionUiSession session, String name});

class CloudStreamState {
  const CloudStreamState({
    this.enabled = true,
    this.isLoading = true,
    this.repositories = const [],
    this.installed = const [],
    this.busy = const {},
    this.applying = const {},
    this.popups = const {},
  });

  /// The global switch: off hides every CloudStream provider without uninstalling anything.
  final bool enabled;
  final bool isLoading;
  final List<CsRepository> repositories;
  final List<CsInstalledPlugin> installed;

  /// Plugins being installed, updated or removed, by [CloudStreamRepository.keyOf].
  final Set<String> busy;

  /// Plugins whose settings are being applied (loaded afresh), by [CloudStreamRepository.keyOf].
  final Set<String> applying;

  /// Each extension's kept pop-ups' titles, newest first, by [CloudStreamRepository.pathKey]: its Support button.
  final Map<String, List<String>> popups;

  /// [plugin]'s kept pop-ups' titles, newest first: its Support button shows while there are any.
  List<String> popupsFor(CsInstalledPlugin plugin) =>
      popups[CloudStreamRepository.pathKey(plugin.filePath)] ?? const [];

  CsInstalledPlugin? installedFor(CsPluginInfo plugin) {
    final key = CloudStreamRepository.keyOf(plugin);
    for (final p in installed) {
      if (CloudStreamRepository.keyOf(p.info) == key) return p;
    }
    return null;
  }

  /// The repository's current entry for an installed plugin, when it offers a newer version.
  CsPluginInfo? updateFor(CsInstalledPlugin plugin) {
    for (final repo in repositories) {
      if (repo.url != plugin.info.repositoryUrl) continue;
      for (final offered in repo.plugins) {
        if (offered.internalName == plugin.info.internalName && offered.version > plugin.info.version) return offered;
      }
    }
    return null;
  }

  CloudStreamState copyWith({
    bool? enabled,
    bool? isLoading,
    List<CsRepository>? repositories,
    List<CsInstalledPlugin>? installed,
    Set<String>? busy,
    Set<String>? applying,
    Map<String, List<String>>? popups,
  }) => CloudStreamState(
    enabled: enabled ?? this.enabled,
    isLoading: isLoading ?? this.isLoading,
    repositories: repositories ?? this.repositories,
    installed: installed ?? this.installed,
    busy: busy ?? this.busy,
    applying: applying ?? this.applying,
    popups: popups ?? this.popups,
  );
}

/// CloudStream extension repositories and installed plugins.
///
/// Like Nuvio and Stremio, this sits beside SkyStream's own plugin system and is managed
/// separately. Unlike them, its providers join SkyStream's provider list, so their home pages,
/// search, details and streams go through the same screens as SkyStream plugins.
@Riverpod(keepAlive: true)
class CloudStreamRepository extends _$CloudStreamRepository {
  static const String _source = 'cloudstream';
  static const String _enabledKey = 'cloudstream_enabled_v1';

  /// Home's provider as CloudStream was switched off, one of CloudStream's: see [setEnabled].
  static const String _homeKey = 'cloudstream_home_provider_v1';

  /// The repository URLs the user removed, so a plugin that adds repositories (MegaRepo's) does
  /// not bring them back - as SkyStream's collections do not.
  static const String removedReposKey = 'cloudstream_removed_repos_v1';

  /// Where repositories were kept before `repositories.json`: SharedPreferences rewrites all it
  /// holds on every change, and a catalogue of hundreds of plugins is large.
  static const String _legacyReposKey = 'cloudstream_repos_v1';

  /// Repository manifests fetched at once.
  static const int _fetchConcurrency = 4;

  /// Plugins add repositories one after another (MegaRepo's reads each manifest in turn); the ones
  /// added are announced once none has come for this long. Each shows in the list as it comes;
  /// only the toast waits. A repository on a new host can take MegaRepo's plugin seconds on iOS
  /// (the TLS handshake runs in an interpreter), and a shorter wait splits the toast in two.
  static const Duration _announceAfter = Duration(seconds: 10);

  Future<void> _loaded = Future<void>.value();
  final _repositoriesFile = _JsonFile('repositories.json');
  final _installedFile = _JsonFile('installed.json');
  final _news = StreamController<ExtensionUpdateReport>.broadcast();
  final _notices = StreamController<ExtensionNotice>.broadcast();
  final _waiting = StreamController<WaitingScreen>.broadcast();
  final Map<String, List<String>> _added = {};
  final Set<String> _adding = {};
  Timer? _announce;
  Timer? _saveTimer;
  int _fetching = 0;
  final List<Completer<void>> _waitingToFetch = [];

  /// The providers last published, reused while their plugin is unchanged: a new instance for the
  /// active provider would make Home load again.
  final Map<String, CloudStreamProvider> _providers = {};

  /// The loads that learn which plugins have a settings screen; one at a time.
  Future<void>? _learning;

  /// Plugins whose load failed while learning: not tried again this run.
  final _learnFailed = <String>{};

  static List<CsProviderInfo> _providersIn(Map<String, dynamic> answer) => [
    for (final p in (answer['providers'] as List?) ?? const [])
      if (p is Map && p['error'] == null) CsProviderInfo.fromJson(Map<String, dynamic>.from(p)),
  ];

  static final Map<String, String> _slugs = {};

  /// Identifies a plugin across repositories: internal names are only unique within one.
  static String keyOf(CsPluginInfo plugin) => '${_slug(plugin.repositoryUrl)}/${plugin.internalName}';

  static String _slug(String url) => _slugs[url] ??= sha1.convert(utf8.encode(url)).toString().substring(0, 10);

  @override
  CloudStreamState build() {
    // A saved active provider that is a CloudStream one must survive the launch until [load]
    // has published the providers.
    ref.read(extensionManagerProvider.notifier).expectExternalSource(_source);
    _loaded = Future.microtask(load);
    final events = _host.events.listen(_onEngineEvent);
    final loads = _host.loads.listen(_noteLoad);
    ref.onDispose(() {
      unawaited(events.cancel());
      unawaited(loads.cancel());
      _announce?.cancel();
      _saveTimer?.cancel();
      unawaited(_news.close());
      unawaited(_notices.close());
      unawaited(_waiting.close());
    });
    return const CloudStreamState();
  }

  /// The repositories plugins added, announced once they stop arriving (see [_announceAfter]),
  /// under the name of the plugin that added them: MegaRepo's plugin adds every repository in
  /// CloudStream's community list when it loads.
  Stream<ExtensionUpdateReport> watchNews() => _news.stream;

  /// What extensions ask the system for that the app shows itself (toasts, copies, links: the engine on
  /// the desktops and iOS), as it happens.
  Stream<ExtensionNotice> watchNotices() => _notices.stream;

  /// Screens the engine opens by itself, for a window the person waits on (a title opening, its links): the
  /// app shows each in the sheet, and reloads nothing after.
  Stream<WaitingScreen> watchWaitingScreens() => _waiting.stream;

  /// A plugin's path as both the engine's events and the installed list spell it: Windows takes either slash.
  static String pathKey(String path) => path.replaceAll(r'\', '/');

  /// [error] as a person reads it, without "Exception:" and the like.
  static String errorMessage(Object error) => switch (error) {
    DioException(:final message, :final type) => message ?? 'network error (${type.name})',
    Cs3EngineException(:final message) => message,
    _ => '$error'.replaceFirst(RegExp(r'^(Exception|FormatException|Bad state|TimeoutException): '), ''),
  };

  Dio get _dio => ref.read(dioClientProvider);
  CloudStreamEngineHost get _host => ref.read(cloudStreamEngineHostProvider);

  /// Shared by every CloudStream provider, so its cache is too.
  late final AniZipService _aniZip = AniZipService(_dio);

  Future<void> load() async {
    var next = const CloudStreamState(isLoading: false);
    try {
      final prefs = await SharedPreferences.getInstance();
      next = CloudStreamState(
        enabled: prefs.getBool(_enabledKey) ?? true,
        isLoading: false,
        repositories: await _readRepositories(prefs),
        installed: await _readInstalled(),
      );
    } catch (error) {
      talker.warning('[CloudStream] load failed: $error');
    }
    // Gone while reading (the app closing): nothing to show it to.
    if (!ref.mounted) return;
    state = next;
    // Off at launch: nothing loads, the engine isn't started.
    _host.setSwitchedOff(!state.enabled);
    _publish();
    _syncRepositories();
  }

  Future<List<CsRepository>> _readRepositories(SharedPreferences prefs) async {
    final legacy = prefs.getStringList(_legacyReposKey);
    if (legacy != null) {
      // Kept in preferences before: moved over once.
      final repos = _each([for (final entry in legacy) _tryDecode(entry)], CsRepository.fromJson);
      await _repositoriesFile.write(() => [for (final r in repos) r.toJson()]);
      await prefs.remove(_legacyReposKey);
      return repos;
    }
    return _each(await _repositoriesFile.read(), CsRepository.fromJson);
  }

  Future<List<CsInstalledPlugin>> _readInstalled() async {
    final root = (await CloudStreamPaths.root()).path;
    final installed = <CsInstalledPlugin>[];
    for (final plugin in _each(await _installedFile.read(), (json) => CsInstalledPlugin.fromJson(json, root))) {
      if (await File(plugin.filePath).exists()) installed.add(plugin);
    }
    return installed;
  }

  /// Each entry of [list] that reads; one that does not is skipped, not fatal to the rest.
  static List<T> _each<T>(Object? list, T Function(Map<String, dynamic> json) read) {
    final out = <T>[];
    for (final entry in list is List ? list : const <Object?>[]) {
      if (entry is! Map) continue;
      try {
        out.add(read(Map<String, dynamic>.from(entry)));
      } catch (error) {
        talker.warning('[CloudStream] skipped an entry that does not read: $error');
      }
    }
    return out;
  }

  static Object? _tryDecode(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  /// Hands the current providers to SkyStream's provider list (none while switched off).
  void _publish() {
    final next = <String, CloudStreamProvider>{};
    if (state.enabled) {
      for (final plugin in state.installed) {
        final key = keyOf(plugin.info);
        for (final info in plugin.providers) {
          final id = '$key|${plugin.info.version}|${plugin.filePath}|${info.name}';
          next[id] =
              _providers[id] ??
              CloudStreamProvider(
                plugin: plugin,
                pluginKey: key,
                info: info,
                host: _host,
                prepareLinks: _loadExtractorPlugins,
                aniZip: _aniZip,
              );
        }
      }
    }
    _providers
      ..clear()
      ..addAll(next);
    ref.read(extensionManagerProvider.notifier).setExternalProviders(_source, [...next.values]);
  }

  /// Switches CloudStream on or off: its screen's switch, the one for all its extensions. Off is not loaded: the
  /// engine host refuses every load from now on, the providers leave Home, search and the provider list, and every
  /// extension loaded this run is unloaded at once (its screens end, its kept pop-ups go with it), so none of
  /// their code runs on. On, the providers return, Home's with them if it was one of CloudStream's, and extensions
  /// load as they're used, as at launch.
  Future<void> setEnabled(bool value) async {
    await _loaded;
    final home = value || !ref.exists(activeProviderProvider) ? null : ref.read(activeProviderProvider);
    state = state.copyWith(enabled: value);
    _host.setSwitchedOff(!value);
    _publish();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    if (value) {
      await _giveHomeBack(prefs);
      return;
    }
    // Home's provider, if it's one of CloudStream's, leaves with them: noted to come back with them.
    if (home is CloudStreamProvider) await prefs.setString(_homeKey, home.packageName);
    for (final plugin in state.installed) {
      try {
        await _host.unload(plugin.filePath, uninstalling: false);
      } catch (error) {
        talker.warning('[CloudStream] unload ${plugin.info.name}: $error');
      }
    }
  }

  /// Gives Home back the provider it had as CloudStream was switched off, one of CloudStream's, unless the person
  /// chose another meanwhile or it's gone. Within a run Home picks it up again by itself, but a launch with
  /// CloudStream off, or another extension uninstalled meanwhile, clears it from Home.
  Future<void> _giveHomeBack(SharedPreferences prefs) async {
    final id = prefs.getString(_homeKey);
    if (id == null) return;
    await prefs.remove(_homeKey);
    if (ref.read(activeProviderProvider) != null) return;
    final provider = ref.read(extensionManagerProvider.notifier).getProvider(id);
    if (provider != null) await ref.read(activeProviderProvider.notifier).set(provider);
  }

  // ── Repositories ────────────────────────────────────────────────────────

  /// What the user entered as a repository: a URL (the scheme may be left out), a
  /// `cloudstreamrepo://` or `https://cs.repo/` link, or a CloudStream shortcode. Shortcodes are
  /// looked up online, like SkyStream's, so new ones work without an app update: `CODE` at
  /// cutt.ly and `!CODE` at py.md, where CloudStream looks them up.
  Future<String> resolveUrl(String input) async {
    final text = input.trim();
    if (text.isEmpty) throw Exception('Enter a repository URL or shortcode');
    final link = RegExp(r'^(cloudstreamrepo://|https://cs\.repo/\??)').firstMatch(text);
    if (link != null) {
      final url = text.substring(link.end);
      return _secure(url.startsWith(RegExp('https?://')) ? url : 'https://$url');
    }
    if (RegExp(r'^[a-zA-Z0-9!_-]+$').hasMatch(text)) {
      // As typed, then in lower case: codes are case-sensitive, and a television keyboard or a
      // phone's may capitalise the first letter.
      String shortLink(String code) => code.startsWith('!') ? 'https://py.md/${code.substring(1)}' : 'https://cutt.ly/$code';
      final lower = text.toLowerCase();
      return _secure(
        await ref.read(repositoryServiceProvider).resolveShortcode([shortLink(text), if (lower != text) shortLink(lower)]),
      );
    }
    return _secure(text.contains('://') ? text : 'https://$text');
  }

  /// Repositories, plugin lists and plugins are fetched over HTTPS only: a plugin is code the
  /// app runs, and plain HTTP would let anyone on the network swap it.
  static String _secure(String url) => url.startsWith('http://') ? 'https://${url.substring(7)}' : url;

  Future<CsRepository> addRepository(String input) async {
    await _loaded;
    final url = await resolveUrl(input);
    final existing = state.repositories.where((r) => r.url == url).firstOrNull;
    if (existing != null) return existing;
    final repo = await _fetchLimited(() => _fetchRepository(url));
    await _setRepositories([...state.repositories, repo]);
    // Added by hand: plugins that add repositories may offer it again.
    await _setRemoved(url, false);
    return repo;
  }

  /// Fetches [url]'s repository again; returns why that failed, if it did. A failure keeps the
  /// plugins it had and records the error.
  Future<String?> refreshRepository(String url, {bool save = true}) async {
    await _loaded;
    final current = state.repositories.where((r) => r.url == url).firstOrNull;
    if (current == null) return null;
    CsRepository updated;
    String? failure;
    try {
      updated = await _fetchLimited(() => _fetchRepository(url));
    } catch (error) {
      failure = errorMessage(error);
      updated = current.withError(failure);
    }
    // Looked up again: the list may have changed while the manifest loaded.
    final index = state.repositories.indexWhere((r) => r.url == url);
    if (index >= 0) await _setRepositories([...state.repositories]..[index] = updated, save: save);
    return failure;
  }

  /// Fetches every repository again (only those with installed plugins, with [installedOnly]), a
  /// few at a time, and saves once. Returns the names of those that failed.
  Future<List<String>> refreshAll({bool installedOnly = false}) async {
    await _loaded;
    final repos = [
      for (final repo in state.repositories)
        if (!installedOnly || state.installed.any((p) => p.info.repositoryUrl == repo.url)) repo,
    ];
    final failures = await Future.wait([for (final repo in repos) refreshRepository(repo.url, save: false)]);
    await _setRepositories(state.repositories);
    return [
      for (var i = 0; i < repos.length; i++)
        if (failures[i] != null) repos[i].name,
    ];
  }

  /// Removes the repository and uninstalls the plugins it provided. A plugin that adds
  /// repositories (MegaRepo's) does not bring it back.
  Future<void> removeRepository(String url) async {
    await _loaded;
    for (final plugin in state.installed.where((p) => p.info.repositoryUrl == url).toList()) {
      await uninstall(plugin);
    }
    await _setRepositories(state.repositories.where((r) => r.url != url).toList());
    await _setRemoved(url, true);
  }

  Future<void> _setRemoved(String url, bool removed) async {
    final prefs = await SharedPreferences.getInstance();
    final urls = {...?prefs.getStringList(removedReposKey)};
    if (removed ? urls.add(url) : urls.remove(url)) await prefs.setStringList(removedReposKey, urls.toList());
  }

  Future<CsRepository> _fetchRepository(String url) async {
    final json = await _getJson(url);
    if (json is List) {
      // A bare plugin list.
      return CsRepository(url: url, name: Uri.parse(url).host, plugins: _sorted(_parsePlugins(json, url)));
    }
    if (json is! Map) throw const FormatException('Not a CloudStream repository');
    final lists = [...?(json['pluginLists'] as List?)?.whereType<String>()];
    if (lists.isEmpty) throw const FormatException('The repository lists no plugins');
    final plugins = <CsPluginInfo>[];
    Object? failure;
    var read = 0;
    for (final list in lists) {
      try {
        final entries = await _getJson(list);
        if (entries is! List) throw const FormatException('Not a list of plugins');
        plugins.addAll(_parsePlugins(entries, url));
        read++;
      } catch (error) {
        failure = error;
        talker.warning('[CloudStream] plugin list $list failed: $error');
      }
    }
    // Not one list read: a failure, not a repository that suddenly offers nothing.
    if (read == 0) throw failure ?? const FormatException('The repository lists no plugins');
    return CsRepository(
      url: url,
      name: json['name'] as String? ?? Uri.parse(url).host,
      description: json['description'] as String?,
      iconUrl: json['iconUrl'] as String?,
      plugins: _sorted(plugins),
    );
  }

  static List<CsPluginInfo> _parsePlugins(List<dynamic> entries, String repositoryUrl) => [
    for (final entry in entries)
      if (entry is Map && entry['url'] is String && (entry['internalName'] ?? entry['name']) is String)
        CsPluginInfo.fromJson(Map<String, dynamic>.from(entry), repositoryUrl),
  ];

  static List<CsPluginInfo> _sorted(List<CsPluginInfo> plugins) =>
      plugins..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  Future<Object?> _getJson(String url) async {
    final response = await _dio.get<String>(_secure(url), options: Options(responseType: ResponseType.plain));
    final body = response.data ?? '';
    try {
      return jsonDecode(body);
    } on FormatException {
      // A login page or a bot check where a repository was (git.disroot.org's for FStream, 2026-10-08): said so,
      // not as the parser's error.
      if (body.trimLeft().startsWith('<')) {
        throw const FormatException('The address answered with a web page, not a repository');
      }
      rethrow;
    }
  }

  /// Replaces the repository list, hands it to the engine, and (with [save]) writes it.
  Future<void> _setRepositories(List<CsRepository> repos, {bool save = true}) async {
    state = state.copyWith(repositories: repos);
    _syncRepositories();
    if (save) await _saveRepositories();
  }

  Future<void> _saveRepositories() {
    _saveTimer?.cancel();
    return _repositoriesFile.write(() => [for (final r in state.repositories) r.toJson()]);
  }

  /// Saves the list a second after the last change: a plugin adding thirty repositories would
  /// otherwise write it thirty times. The screen shows each one at once regardless.
  void _saveSoon() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), () => unawaited(_saveRepositories()));
  }

  /// Hands the repository list to the engine, where plugins read it.
  void _syncRepositories() => unawaited(
    _host.setRepositories([
      for (final repo in state.repositories) {'url': repo.url, 'name': repo.name, 'iconUrl': repo.iconUrl},
    ]),
  );

  /// Runs [fetch] once fewer than [_fetchConcurrency] others are running: a refresh, or a plugin
  /// adding a whole list of repositories at once.
  Future<T> _fetchLimited<T>(Future<T> Function() fetch) async {
    if (_fetching < _fetchConcurrency) {
      _fetching++;
    } else {
      final turn = Completer<void>();
      _waitingToFetch.add(turn);
      // A finishing fetch hands over its place.
      await turn.future;
    }
    try {
      return await fetch();
    } finally {
      if (_waitingToFetch.isNotEmpty) {
        _waitingToFetch.removeAt(0).complete();
      } else {
        _fetching--;
      }
    }
  }

  // ── Plugins ─────────────────────────────────────────────────────────────

  /// Downloads [plugin] (replacing an installed version), loads it, and publishes its providers.
  /// A plugin that downloads but does not load is still installed, with [CsInstalledPlugin.loadError].
  ///
  /// A utility plugin (see [_isUtility]) does its work once it has loaded: the repositories
  /// MegaRepo's adds join the list as they arrive, and are announced through [watchNews].
  Future<CsInstalledPlugin> install(CsPluginInfo plugin) async {
    await _loaded;
    // Switched off, nothing loads, and an install would be left failed to load.
    if (!state.enabled) throw const CloudStreamSwitchedOff();
    final key = keyOf(plugin);
    _setBusy(key, true);
    try {
      final dir = await Directory(
        '${(await CloudStreamPaths.plugins()).path}/${_slug(plugin.repositoryUrl)}',
      ).create(recursive: true);
      final file = File('${dir.path}/${plugin.internalName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}.cs3');
      final part = File('${file.path}.part');
      await _dio.download(_secure(plugin.url).replaceAll(' ', '%20'), part.path);
      if (!state.enabled) {
        // Switched off while it downloaded: the version installed, if any, stays as it was.
        await part.delete();
        throw const CloudStreamSwitchedOff();
      }
      if (await file.exists()) {
        // An update. The loaded version holds its file open (Windows will not delete it), and
        // Android loads the file read-only, so it is replaced rather than rewritten.
        await _host.unload(file.path, uninstalling: false);
        await file.delete();
      }
      await part.rename(file.path);

      final CsInstalledPlugin installed;
      try {
        installed = await _load(plugin, file.path);
      } on CloudStreamSwitchedOff {
        // Switched off that very moment: a new install leaves nothing behind, and an update keeps the version
        // installed (its file holds the new one now, which the next update pass installs again).
        if (!state.installed.any((p) => p.filePath == file.path)) await file.delete();
        rethrow;
      }
      await _saveInstalled([
        for (final p in state.installed)
          if (keyOf(p.info) != key) p,
        installed,
      ]);
      return installed;
    } finally {
      _setBusy(key, false);
    }
  }

  Future<void> uninstall(CsInstalledPlugin plugin) async {
    await _loaded;
    final key = keyOf(plugin.info);
    _setBusy(key, true);
    try {
      try {
        await _host.unload(plugin.filePath);
      } catch (error) {
        talker.warning('[CloudStream] unload ${plugin.info.name}: $error');
      }
      final file = File(plugin.filePath);
      if (await file.exists()) await file.delete();
      await _saveInstalled([
        for (final p in state.installed)
          if (keyOf(p.info) != key) p,
      ]);
    } finally {
      _setBusy(key, false);
    }
  }

  /// Loads the plugin [info] at [path] on the engine, and says what it registered, or why it
  /// failed and under which app version.
  Future<CsInstalledPlugin> _load(CsPluginInfo info, String path) async {
    try {
      final loaded = await _host.reload(path, pluginUrl: info.url);
      return CsInstalledPlugin(
        info: info,
        filePath: path,
        providers: _providersIn(loaded),
        extractors: (loaded['extractors'] as num?)?.toInt() ?? 0,
        hasSettings: loaded['hasSettings'] as bool?,
      );
    } on CloudStreamSwitchedOff {
      // Nothing is wrong with the plugin: it loads once CloudStream is on.
      rethrow;
    } catch (error) {
      talker.warning('[CloudStream] ${info.name} failed to load: $error');
      return CsInstalledPlugin(
        info: info,
        filePath: path,
        loadError: errorMessage(error),
        loadErrorVersion: await ref.read(keptAppVersionProvider.future),
      );
    }
  }

  /// Plugins this app version hasn't tried to load since one failed: the engine comes with the app,
  /// and a newer one may run them (on 2026-10-03 it gained the CloudStream app classes eight of the
  /// surveyed extensions failed for). Each is tried once per version. Returns their keys.
  Future<Set<String>> _retryFailed() async {
    final version = await ref.read(keptAppVersionProvider.future);
    final retried = <String>{};
    for (final plugin in [...state.installed]) {
      if (plugin.loadError == null || plugin.loadErrorVersion == version) continue;
      final key = keyOf(plugin.info);
      final CsInstalledPlugin loaded;
      try {
        loaded = await _load(plugin.info, plugin.filePath);
      } on CloudStreamSwitchedOff {
        // Switched off meanwhile: the rest are tried at a later launch.
        break;
      }
      await _saveInstalled([
        for (final p in state.installed)
          if (keyOf(p.info) != key) p,
        loaded,
      ]);
      retried.add(key);
    }
    return retried;
  }

  /// A plugin that registers no provider and no link extractor: it works through what it does
  /// when it loads, like MegaRepo's. CloudStream loads every plugin at launch, so these run at
  /// launch too.
  static bool _isUtility(CsInstalledPlugin plugin) =>
      plugin.providers.isEmpty && plugin.extractors == 0 && plugin.loadError == null;

  /// Plugins that only register link extractors serve other plugins' links. CloudStream has every
  /// plugin loaded; here they are loaded before links are first fetched.
  Future<void> _loadExtractorPlugins() async {
    for (final plugin in state.installed) {
      if (plugin.providers.isNotEmpty || plugin.extractors == 0 || plugin.loadError != null) continue;
      try {
        await _host.ensureLoaded(plugin.filePath, pluginUrl: plugin.info.url);
      } catch (error) {
        talker.warning('[CloudStream] ${plugin.info.name} failed to load: $error');
      }
    }
  }

  /// What a load said about an installed plugin's settings screen, kept with it.
  void _noteLoad(({String path, Map<String, dynamic> answer}) load) {
    final hasSettings = load.answer['hasSettings'];
    if (hasSettings is! bool) return;
    final index = state.installed.indexWhere((p) => p.filePath == load.path);
    if (index < 0 || state.installed[index].hasSettings == hasSettings) return;
    final plugin = state.installed[index];
    unawaited(
      _saveInstalled([
        for (final p in state.installed)
          if (p.filePath != load.path) p,
        plugin.withSettings(hasSettings),
      ]),
    );
  }

  /// Finds out which installed plugins have a settings screen, for those not loaded since this app
  /// version: loads them one at a time ([_noteLoad] keeps what they say). Utility plugins (MegaRepo's)
  /// are left alone; loading them would do their work again. Only where an extension's screens can be
  /// drawn ([extensionScreensSupported]): elsewhere nothing would show the answer.
  Future<void> learnSettings() => _learning ??= _learnSettings().whenComplete(() => _learning = null);

  Future<void> _learnSettings() async {
    await _loaded;
    if (!state.enabled || !extensionScreensSupported) return;
    for (final plugin in [...state.installed]) {
      if (plugin.hasSettings != null || plugin.loadError != null || _isUtility(plugin)) continue;
      if (_learnFailed.contains(plugin.filePath)) continue;
      try {
        await _host.ensureLoaded(plugin.filePath, pluginUrl: plugin.info.url);
      } on CloudStreamSwitchedOff {
        // Switched off meanwhile: the rest are learned on a later visit.
        break;
      } catch (error) {
        _learnFailed.add(plugin.filePath);
        talker.warning('[CloudStream] ${plugin.info.name} failed to load: $error');
      }
    }
  }

  /// Loads [plugin] afresh once its settings screen closed with changes (or it asked to restart), so
  /// what it saved applies, and publishes what it registers now. Its providers are new instances, so a
  /// screen showing one of them loads again.
  Future<void> applySettings(CsInstalledPlugin plugin) async {
    final key = keyOf(plugin.info);
    // Marked at once: the row says so from the tap on.
    state = state.copyWith(applying: {...state.applying, key});
    try {
      await _loaded;
      Map<String, dynamic>? answer;
      (Object, StackTrace)? failure;
      try {
        answer = await _host.reloadAfresh(plugin.filePath, pluginUrl: plugin.info.url);
      } on CloudStreamSwitchedOff {
        // Nothing loaded and nothing changed: what its screen saved applies once CloudStream is on.
        rethrow;
      } catch (error, stack) {
        failure = (error, stack);
      }
      final current = state.installed.where((p) => keyOf(p.info) == key).firstOrNull ?? plugin;
      _providers.removeWhere((id, _) => id.startsWith('$key|'));
      await _saveInstalled([
        for (final p in state.installed)
          if (keyOf(p.info) != key) p,
        if (answer != null)
          CsInstalledPlugin(
            info: current.info,
            filePath: current.filePath,
            providers: _providersIn(answer),
            extractors: (answer['extractors'] as num?)?.toInt() ?? current.extractors,
            hasSettings: answer['hasSettings'] as bool? ?? current.hasSettings,
          )
        else
          // The engine let the old load go first: the plugin has failed to load, as any load that fails.
          CsInstalledPlugin(
            info: current.info,
            filePath: current.filePath,
            loadError: errorMessage(failure!.$1),
            loadErrorVersion: await ref.read(keptAppVersionProvider.future),
            hasSettings: current.hasSettings,
          ),
      ]);
      if (failure case (final error, final stack)) Error.throwWithStackTrace(error, stack);
    } finally {
      state = state.copyWith(applying: {...state.applying}..remove(key));
    }
  }

  /// The launch-time pass, beside SkyStream's own: brings installed plugins up to date from their
  /// repositories, and runs the utility plugins again as CloudStream's launch does (MegaRepo's
  /// then adds what is new to its list, announced through [watchNews]). Returns the plugins
  /// updated. Switched off or with nothing installed, it does nothing, and nothing starts the
  /// engine unless a plugin needs loading.
  Future<ExtensionUpdateReport> autoUpdate() async {
    await _loaded;
    if (!state.enabled || state.installed.isEmpty) return const ExtensionUpdateReport();
    await refreshAll(installedOnly: true);
    final updated = <String>{};
    for (final plugin in [...state.installed]) {
      final newer = state.updateFor(plugin);
      if (newer == null) continue;
      try {
        final installed = await install(newer);
        if (installed.loadError == null) updated.add(keyOf(newer));
      } catch (error) {
        talker.warning('[CloudStream] updating ${plugin.info.name} failed: $error');
      }
    }
    final retried = await _retryFailed();
    for (final plugin in state.installed.where(_isUtility)) {
      // Installing an update, or loading one that had failed, has run it already.
      if (updated.contains(keyOf(plugin.info)) || retried.contains(keyOf(plugin.info))) continue;
      // Loading an unchanged file again does nothing, so one loaded this session goes first.
      await _host.unload(plugin.filePath, uninstalling: false);
      try {
        await _host.ensureLoaded(plugin.filePath, pluginUrl: plugin.info.url);
      } catch (error) {
        talker.warning('[CloudStream] ${plugin.info.name} failed to load: $error');
      }
    }
    return ExtensionUpdateReport(
      updated: [
        for (final plugin in state.installed)
          if (updated.contains(keyOf(plugin.info))) plugin.info.name,
      ],
    );
  }

  void _onEngineEvent(Map<String, dynamic> event) {
    switch (event['event']) {
      case 'repositoryAdded' when event['url'] is String:
        unawaited(_addFromPlugin(event));
      case 'toast' || 'copy' || 'openUrl' when !_notices.isClosed:
        final link = event['event'] == 'openUrl';
        _notices.add(
          ExtensionNotice(
            switch (event['event']) {
              'toast' => ExtensionNoticeKind.toast,
              'copy' => ExtensionNoticeKind.copy,
              _ => ExtensionNoticeKind.link,
            },
            _pluginName(event['plugin'] as String?),
            '${link ? event['url'] : event['text']}',
            inScreen: event['session'] != null,
          ),
        );
      case 'popups' when event['plugin'] is String:
        final key = pathKey(event['plugin'] as String);
        final titles = [for (final title in (event['titles'] as List?) ?? const []) '$title'];
        state = state.copyWith(popups: {...state.popups, key: titles}..removeWhere((_, kept) => kept.isEmpty));
      case 'uiOpened' when event['session'] is num && event['plugin'] is String && !_waiting.isClosed:
        // Heard from now: the engine reads the screen's windows a moment after it says so.
        final plugin = event['plugin'] as String;
        _waiting.add((
          session: ExtensionUiSession.attach(HostUiApi(_host), (event['session'] as num).toInt(), plugin),
          name: _pluginName(plugin),
        ));
    }
  }

  /// A repository a plugin added joins the list as soon as its manifest loads, unless the user
  /// removed it or has it already. One that does not load is left for the plugin to offer again
  /// on the next launch.
  Future<void> _addFromPlugin(Map<String, dynamic> event) async {
    await _loaded;
    final url = _secure(event['url'] as String);
    final removed = (await SharedPreferences.getInstance()).getStringList(removedReposKey) ?? const [];
    if (removed.contains(url) || state.repositories.any((r) => r.url == url) || !_adding.add(url)) return;
    _announce?.cancel();
    try {
      final repo = await _fetchLimited(() => _fetchRepository(url));
      if (!state.repositories.any((r) => r.url == url)) {
        await _setRepositories([...state.repositories, repo], save: false);
        _saveSoon();
        (_added[_pluginName(event['plugin'] as String?)] ??= []).add(repo.name);
      }
    } catch (error) {
      talker.warning('[CloudStream] repository $url, added by a plugin, did not load: $error');
    } finally {
      _adding.remove(url);
      if (_adding.isEmpty) _announce = Timer(_announceAfter, _announceAdded);
    }
  }

  void _announceAdded() {
    if (_added.isEmpty || _news.isClosed) return;
    _news.add(ExtensionUpdateReport(newRepositories: {..._added}));
    _added.clear();
  }

  /// The name of the installed plugin at [path] (the engine's spelling of it), for the toast.
  String _pluginName(String? path) {
    final wanted = path?.replaceAll('\\', '/');
    for (final plugin in state.installed) {
      if (plugin.filePath.replaceAll('\\', '/') == wanted) return plugin.info.name;
    }
    return 'CloudStream';
  }

  void _setBusy(String key, bool busy) {
    state = state.copyWith(busy: busy ? {...state.busy, key} : ({...state.busy}..remove(key)));
  }

  Future<void> _saveInstalled(List<CsInstalledPlugin> installed) async {
    installed.sort((a, b) => a.info.name.toLowerCase().compareTo(b.info.name.toLowerCase()));
    state = state.copyWith(installed: installed);
    _publish();
    final root = (await CloudStreamPaths.root()).path;
    await _installedFile.write(() => [for (final p in state.installed) p.toJson(root)]);
  }
}

/// A JSON file in CloudStream's folder. Each write replaces it whole and atomically (a crash
/// mid-write cannot cut it short), writes go one at a time, and each writes what [write]'s
/// callback returns when it starts: the latest state, whatever order the saves came in.
class _JsonFile {
  _JsonFile(this.name);

  final String name;
  Future<void> _writing = Future<void>.value();

  Future<File> _file() async => File('${(await CloudStreamPaths.root()).path}/$name');

  /// The file's content, or null if there is none or it does not read.
  Future<Object?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      return jsonDecode(await file.readAsString());
    } catch (error) {
      talker.warning('[CloudStream] $name does not read: $error');
      return null;
    }
  }

  Future<void> write(Object? Function() content) => _writing = _writing.then((_) async {
    try {
      final file = await _file();
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(jsonEncode(content()), flush: true);
      await temp.rename(file.path);
    } catch (error) {
      talker.warning('[CloudStream] saving $name failed: $error');
    }
  });
}
