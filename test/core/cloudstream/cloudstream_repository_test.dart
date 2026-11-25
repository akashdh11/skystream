/// CloudStream repositories against a fake network: what is fetched, what is kept when a fetch
/// fails, how repository links are read, where the list is saved, and what happens to
/// repositories a plugin (MegaRepo's) adds - including ones the user removed.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cs3_engine/cs3_engine.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skystream/core/cloudstream/cloudstream_engine.dart';
import 'package:skystream/core/cloudstream/cloudstream_models.dart';
import 'package:skystream/core/cloudstream/cloudstream_provider.dart';
import 'package:skystream/core/cloudstream/cloudstream_repository.dart';
import 'package:skystream/core/cloudstream/extension_notices.dart';
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/core/extensions/providers.dart';
import 'package:skystream/core/extensions/services/repository_service.dart';
import 'package:skystream/core/extensions/base_provider.dart';
import 'package:skystream/core/extensions/extension_manager.dart';
import 'package:skystream/core/network/dio_client_provider.dart';
import 'package:skystream/core/storage/settings_repository.dart';
import 'package:skystream/features/settings/presentation/app_version_provider.dart';

const _repoUrl = 'https://repo.test/repo.json';
const _otherUrl = 'https://other.test/repo.json';

/// Serves two repositories, each with one plugin list and its plugin's file; [failLists] makes
/// plugin lists fail.
class _FakeRepos implements HttpClientAdapter {
  bool failLists = false;
  final List<String> requested = [];

  /// The version of Alpha the repositories offer.
  int version = 2;

  /// Set: plugin downloads wait for it.
  Completer<void>? holdDownloads;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final url = options.uri.toString();
    requested.add(url);
    final host = options.uri.host;
    if (host == 'web.test') {
      // A login page or a bot check where a repository was (git.disroot.org's for FStream, 2026-10-08).
      return ResponseBody.fromString('<!doctype html><html><head><title>Sign in</title></head></html>', 200);
    }
    if (host == 'cutt.ly') {
      // The shortener knows one code, in lower case: its codes are case-sensitive.
      return options.uri.path == '/megarepo'
          ? ResponseBody.fromString('', 302, headers: {'location': ['https://repo.test/repo.json']})
          : ResponseBody.fromString('not found', 404);
    }
    if (url.endsWith('/repo.json')) {
      return ResponseBody.fromString(
        jsonEncode({'name': 'Repo $host', 'manifestVersion': 1, 'pluginLists': ['https://$host/plugins.json']}),
        200,
      );
    }
    if (url.endsWith('/plugins.json')) {
      if (failLists) return ResponseBody.fromString('down', 500);
      return ResponseBody.fromString(
        jsonEncode([
          {'internalName': 'Alpha', 'name': 'Alpha', 'url': 'https://$host/Alpha.cs3', 'version': version},
        ]),
        200,
      );
    }
    if (url.endsWith('.cs3')) {
      await holdDownloads?.future;
      return ResponseBody.fromString('plugin v$version', 200);
    }
    return ResponseBody.fromString('not found', 404);
  }

  @override
  void close({bool force = false}) {}
}

/// No JS plugins, but the real handling of other extension systems' providers.
class _NoopExtensionManager extends ExtensionManager {
  @override
  List<SkyStreamProvider> build() => const <SkyStreamProvider>[];
}

/// An engine host whose events the test sends, and that notes the plugins it is asked to load;
/// nothing ever starts.
class _FakeHost extends CloudStreamEngineHost {
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final loaded = <({String path, String? pluginUrl})>[];

  /// What a load registers.
  List<Map<String, Object?>> providers = const [];

  /// Loads fail, as the engine's do for a plugin it can't run.
  bool failing = false;

  /// Called as a reload starts: a test switches CloudStream off at that moment.
  void Function()? onReload;

  // While switched off, loads are refused as the real host refuses them.

  @override
  Future<Map<String, dynamic>> reload(String path, {String? pluginUrl}) async {
    onReload?.call();
    if (switchedOff) return super.reload(path, pluginUrl: pluginUrl);
    loaded.add((path: path, pluginUrl: pluginUrl));
    if (failing) throw Cs3EngineException('java.lang.NoSuchFieldError', 'Companion');
    return {'providers': providers};
  }

  @override
  Future<Map<String, dynamic>> ensureLoaded(String path, {String? pluginUrl}) async {
    if (switchedOff) return super.ensureLoaded(path, pluginUrl: pluginUrl);
    loaded.add((path: path, pluginUrl: pluginUrl));
    if (ensureFails case final error?) throw error;
    final answer = {'providers': providers, 'hasSettings': true};
    announce(path, answer);
    return answer;
  }

  /// Whether the repository last told the host CloudStream is switched off.
  bool switchedOff = false;

  /// The plugins unloaded.
  final unloaded = <String>[];

  @override
  void setSwitchedOff(bool off) {
    super.setSwitchedOff(off);
    switchedOff = off;
  }

  @override
  Future<void> unload(String path, {bool uninstalling = true}) async => unloaded.add(path);

  @override
  Stream<Map<String, dynamic>> get events => _events.stream;

  void send(Map<String, dynamic> event) => _events.add(event);

  @override
  Future<void> setRepositories(List<Map<String, Object?>> repositories) async {}

  final _loads = StreamController<({String path, Map<String, dynamic> answer})>.broadcast();
  final afresh = <String>[];

  @override
  Stream<({String path, Map<String, dynamic> answer})> get loads => _loads.stream;

  void announce(String path, Map<String, dynamic> answer) => _loads.add((path: path, answer: answer));

  @override
  Future<Map<String, dynamic>> reloadAfresh(String path, {String? pluginUrl}) async {
    if (switchedOff) return super.reloadAfresh(path, pluginUrl: pluginUrl);
    afresh.add(path);
    if (afreshFails case final error?) throw error;
    return {'providers': providers, 'hasSettings': true};
  }

  /// Set: loading afresh fails, after the engine let the old load go (as the engine does).
  Object? afreshFails;

  /// Set: a load fails.
  Object? ensureFails;
}

/// Home's provider, kept as the app's settings keep it.
class _Settings implements SettingsRepository {
  String? active;

  @override
  String? getActiveProviderId() => active;

  @override
  Future<void> setActiveProviderId(String? id) async => active = id;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A provider of another kind of extension, for Home.
class _OtherProvider extends SkyStreamProvider {
  @override
  String get packageName => 'other.provider';
  @override
  String get name => 'Other';
  @override
  String get mainUrl => 'https://other.provider';
  @override
  String get version => '1.0.0';
  @override
  List<String> get languages => const ['en'];
  @override
  Set<ProviderType> get supportedTypes => {ProviderType.movie};

  @override
  Future<List<MultimediaItem>> search(String query, {CancelToken? cancelToken}) => throw UnimplementedError();
  @override
  Future<Map<String, List<MultimediaItem>>> getHome() => throw UnimplementedError();
  @override
  Future<MultimediaItem> getDetails(String url) => throw UnimplementedError();
  @override
  Future<List<StreamResult>> loadStreams(String url) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory support;
  late _FakeRepos network;
  late _FakeHost host;

  setUp(() {
    support = Directory.systemTemp.createTempSync('cloudstream_repository_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => support.path,
    );
    network = _FakeRepos();
    host = _FakeHost();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (support.existsSync()) support.deleteSync(recursive: true);
  });

  ProviderContainer boot([Map<String, Object> prefs = const {}, _Settings? settings]) {
    SharedPreferences.setMockInitialValues(prefs);
    final container = ProviderContainer(
      overrides: [
        dioClientProvider.overrideWithValue(Dio()..httpClientAdapter = network),
        // Shortcodes are looked up through it; the real one reads the app's settings for its proxy.
        repositoryServiceProvider.overrideWithValue(RepositoryService(Dio()..httpClientAdapter = network)),
        extensionManagerProvider.overrideWith(_NoopExtensionManager.new),
        cloudStreamEngineHostProvider.overrideWithValue(host),
        keptAppVersionProvider.overrideWith((ref) async => '2.0.0 +5'),
        if (settings != null) settingsRepositoryProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// [boot], with Home's provider kept in [settings] and resolved as the app resolves it, the app's plugin sync done.
  ProviderContainer bootHome(_Settings settings, [Map<String, Object> prefs = const {}]) {
    final container = boot(prefs, settings);
    container.listen(activeProviderProvider, (_, _) {});
    container.read(pluginSyncCompleteProvider.notifier).set(true);
    return container;
  }

  /// Waits until a plugin's download has started.
  Future<void> downloading() async {
    while (!network.requested.any((url) => url.endsWith('.cs3'))) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  /// The plugin files on disk, parts included.
  List<File> pluginFiles() => [
    ...Directory('${support.path}/extensions/cloudstream/plugins').listSync(recursive: true).whereType<File>(),
  ];

  File savedRepositories() => File('${support.path}/extensions/cloudstream/repositories.json');

  test('a repository is fetched over HTTPS and saved to its file', () async {
    final container = boot();
    final repo = await container.read(cloudStreamRepositoryProvider.notifier).addRepository('http://repo.test/repo.json');

    expect(repo.url, _repoUrl);
    expect(repo.plugins.single.internalName, 'Alpha');
    expect(network.requested, everyElement(startsWith('https://')));
    final saved = jsonDecode(savedRepositories().readAsStringSync()) as List;
    expect((saved.single as Map)['url'], _repoUrl);
  });

  test('a refresh whose plugin lists all fail keeps the plugins it had', () async {
    final container = boot();
    final notifier = container.read(cloudStreamRepositoryProvider.notifier);
    await notifier.addRepository(_repoUrl);

    network.failLists = true;
    final failed = await notifier.refreshAll();

    final repo = container.read(cloudStreamRepositoryProvider).repositories.single;
    expect(failed, ['Repo repo.test']);
    expect(repo.plugins, hasLength(1), reason: 'a failed refresh emptied the repository');
    expect(repo.error, isNotNull);
  });

  test('repositories kept in preferences before move to the file, once', () async {
    const legacy = CsRepository(url: _repoUrl, name: 'Old');
    final container = boot({
      'cloudstream_repos_v1': [jsonEncode(legacy.toJson())],
    });
    container.read(cloudStreamRepositoryProvider);
    await container.read(cloudStreamRepositoryProvider.notifier).load();

    expect(container.read(cloudStreamRepositoryProvider).repositories.single.name, 'Old');
    expect((await SharedPreferences.getInstance()).getStringList('cloudstream_repos_v1'), isNull);
    expect(savedRepositories().existsSync(), isTrue);
  });

  test('an entry that does not read is skipped, not the whole list', () async {
    final root = Directory('${support.path}/extensions/cloudstream')..createSync(recursive: true);
    savedRepositories().writeAsStringSync(
      jsonEncode([
        {'name': 'no url'},
        const CsRepository(url: _repoUrl, name: 'Good').toJson(),
      ]),
    );
    expect(root.existsSync(), isTrue);
    final container = boot();
    container.read(cloudStreamRepositoryProvider);
    await container.read(cloudStreamRepositoryProvider.notifier).load();

    expect(container.read(cloudStreamRepositoryProvider).repositories.single.name, 'Good');
  });

  test('a load the provider is gone before it finishes leaves it alone', () async {
    final container = boot();
    container.read(cloudStreamRepositoryProvider);
    final loading = container.read(cloudStreamRepositoryProvider.notifier).load();
    container.dispose();
    await loading;
  });

  test('profile sync joining the launch read does not start a second one', () async {
    // build() schedules a read, and sync calls load() while that read is the
    // one still running. A second read finishes after sync has added
    // repositories and replaces them with the empty list it started with.
    CloudStreamRepository.debugLoadsStarted = 0;
    final container = boot();
    container.read(cloudStreamRepositoryProvider);
    final joined = container.read(cloudStreamRepositoryProvider.notifier).load();
    await Future<void>.delayed(Duration.zero);
    await joined;
    expect(CloudStreamRepository.debugLoadsStarted, 1);
  });

  test('repositories a plugin adds join the list, apart from ones the user removed', () async {
    final container = boot();
    final notifier = container.read(cloudStreamRepositoryProvider.notifier);
    await notifier.addRepository(_otherUrl);
    await notifier.removeRepository(_otherUrl);

    host.send({'event': 'repositoryAdded', 'url': _otherUrl, 'name': 'Other'});
    host.send({'event': 'repositoryAdded', 'url': 'http://repo.test/repo.json', 'name': 'Repo'});
    // Long enough for the added repository's manifest and plugin list to load.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final urls = [for (final r in container.read(cloudStreamRepositoryProvider).repositories) r.url];
    expect(urls, [_repoUrl]);
  });

  test('updates and installed plugins are told apart across repositories', () {
    final mine = CsPluginInfo.fromJson({'internalName': 'Alpha', 'name': 'Alpha', 'url': 'u', 'version': 1}, _repoUrl);
    final fork = CsPluginInfo.fromJson({'internalName': 'Alpha', 'name': 'Alpha', 'url': 'u', 'version': 9}, _otherUrl);
    final newer = CsPluginInfo.fromJson({'internalName': 'Alpha', 'name': 'Alpha', 'url': 'u', 'version': 2}, _repoUrl);
    final installed = CsInstalledPlugin(info: mine, filePath: '/x/Alpha.cs3');
    final state = CloudStreamState(
      installed: [installed],
      repositories: [
        CsRepository(url: _repoUrl, name: 'Mine', plugins: [newer]),
        CsRepository(url: _otherUrl, name: 'Fork', plugins: [fork]),
      ],
    );

    expect(CloudStreamRepository.keyOf(mine), isNot(CloudStreamRepository.keyOf(fork)));
    expect(state.installedFor(newer), same(installed));
    expect(state.installedFor(fork), isNull);
    expect(state.updateFor(installed), same(newer));
  });

  test('repository links and URLs are read as CloudStream reads them', () async {
    final notifier = boot().read(cloudStreamRepositoryProvider.notifier);
    const target = 'https://raw.githubusercontent.com/a/b/repo.json';
    expect(await notifier.resolveUrl('cloudstreamrepo://raw.githubusercontent.com/a/b/repo.json'), target);
    expect(await notifier.resolveUrl('https://cs.repo/?raw.githubusercontent.com/a/b/repo.json'), target);
    expect(await notifier.resolveUrl(' raw.githubusercontent.com/a/b/repo.json '), target);
    expect(await notifier.resolveUrl('http://raw.githubusercontent.com/a/b/repo.json'), target);
    expect(() => notifier.resolveUrl('  '), throwsA(isA<Exception>()));
  });

  // A television keyboard or a phone's may capitalise the first letter: "MegaRepo" found nothing.
  test('a shortcode typed with capitals is tried in lower case too', () async {
    final notifier = boot().read(cloudStreamRepositoryProvider.notifier);
    expect(await notifier.resolveUrl('MegaRepo'), 'https://repo.test/repo.json');
    expect(network.requested.where((url) => url.contains('cutt.ly')), [
      'https://cutt.ly/MegaRepo',
      'https://cutt.ly/megarepo',
    ]);
  });

  // ViStream registers nothing unless it was installed from its own repository.
  test('a plugin installed from a repository loads with the address it came from', () async {
    final notifier = boot().read(cloudStreamRepositoryProvider.notifier);
    final repo = await notifier.addRepository(_repoUrl);
    final installed = await notifier.install(repo.plugins.single);
    expect(host.loaded, [(path: installed.filePath, pluginUrl: 'https://repo.test/Alpha.cs3')]);
  });

  /// Saves [plugin] as installed, failed to load, as an install does.
  CsInstalledPlugin failedInstall(String name, {String? underVersion}) {
    final root = '${support.path}/extensions/cloudstream';
    final file = File('$root/plugins/x/$name.cs3')..createSync(recursive: true);
    final info = CsPluginInfo.fromJson({
      'internalName': name,
      'name': name,
      'url': 'https://repo.test/$name.cs3',
      'version': 2,
    }, _repoUrl);
    return CsInstalledPlugin(
      info: info,
      filePath: file.path,
      loadError: 'NoSuchFieldError: Companion',
      loadErrorVersion: underVersion,
    );
  }

  void saveInstalled(List<CsInstalledPlugin> plugins) {
    final root = '${support.path}/extensions/cloudstream';
    File('$root/installed.json').writeAsStringSync(jsonEncode([for (final p in plugins) p.toJson(root)]));
  }

  // The engine comes with the app: a plugin it couldn't load (CineStream, before the CloudStream app
  // classes it needed) may load under the next version, and is tried again once there.
  test('a plugin that failed to load is loaded again after the app updates', () async {
    final before = failedInstall('Alpha');
    saveInstalled([before]);
    host.providers = [
      {'name': 'Alpha', 'mainUrl': 'https://alpha.test'},
    ];
    final container = boot();
    await container.read(cloudStreamRepositoryProvider.notifier).autoUpdate();

    expect(host.loaded, [(path: before.filePath, pluginUrl: 'https://repo.test/Alpha.cs3')]);
    final after = container.read(cloudStreamRepositoryProvider).installed.single;
    expect(after.loadError, isNull);
    expect([for (final p in after.providers) p.name], ['Alpha']);
  });

  test('a plugin that failed under this version is not tried again, and a new failure is dated', () async {
    saveInstalled([failedInstall('Alpha', underVersion: '2.0.0 +5'), failedInstall('Beta', underVersion: '1.9.0 +4')]);
    host.failing = true;
    final container = boot();
    await container.read(cloudStreamRepositoryProvider.notifier).autoUpdate();

    expect([for (final l in host.loaded) l.path.split('/').last], ['Beta.cs3']);
    final installed = container.read(cloudStreamRepositoryProvider).installed;
    expect({for (final p in installed) p.info.name: p.loadErrorVersion}, {'Alpha': '2.0.0 +5', 'Beta': '2.0.0 +5'});
  });

  test('errors read without their exception prefixes', () {
    expect(CloudStreamRepository.errorMessage(Exception("That shortcode doesn't exist")), "That shortcode doesn't exist");
    expect(CloudStreamRepository.errorMessage(const FormatException('Not a CloudStream repository')), 'Not a CloudStream repository');
  });

  test("an address that answers with a web page (a login, a bot check) says so, not the parser's error", () async {
    final container = boot();
    await expectLater(
      container.read(cloudStreamRepositoryProvider.notifier).addRepository('https://web.test/repo.json'),
      throwsA(
        isA<FormatException>().having(
          CloudStreamRepository.errorMessage,
          'what the person reads',
          'The address answered with a web page, not a repository',
        ),
      ),
    );
  });

  Future<CsInstalledPlugin> installOne(ProviderContainer container) async {
    final notifier = container.read(cloudStreamRepositoryProvider.notifier);
    final repo = await notifier.addRepository(_repoUrl);
    host.providers = [
      {'name': 'Alpha'},
    ];
    return notifier.install(repo.plugins.single);
  }

  /// The CloudStream providers published to Home, search and the provider list, by name.
  List<String> published(ProviderContainer container) => [
    for (final p in container.read(extensionManagerProvider))
      if (p is CloudStreamProvider) p.info.name,
  ];

  test(
    'switched off, CloudStream unloads every extension and its providers leave; on again, nothing loads until used',
    () async {
      final container = boot();
      container.read(cloudStreamRepositoryProvider);
      final plugin = await installOne(container);
      final notifier = container.read(cloudStreamRepositoryProvider.notifier);
      host.loaded.clear();
      await notifier.setEnabled(false);
      expect(published(container), isEmpty);
      expect(host.switchedOff, isTrue);
      expect(host.unloaded, [plugin.filePath]);
      await notifier.setEnabled(true);
      expect(published(container), ['Alpha']);
      expect(host.switchedOff, isFalse);
      expect(host.loaded, isEmpty, reason: 'they load as they are used');
    },
  );

  test('switched off at launch, CloudStream has the host refuse every load from the start', () async {
    final root = '${support.path}/extensions/cloudstream';
    final file = File('$root/plugins/x/Alpha.cs3')..createSync(recursive: true);
    saveInstalled([
      CsInstalledPlugin(
        info: CsPluginInfo.fromJson({
          'internalName': 'Alpha',
          'name': 'Alpha',
          'url': 'https://repo.test/Alpha.cs3',
          'version': 2,
        }, _repoUrl),
        filePath: file.path,
        providers: const [CsProviderInfo(name: 'Alpha')],
      ),
    ]);
    final container = boot({'cloudstream_enabled_v1': false});
    await container.read(cloudStreamRepositoryProvider.notifier).load();
    expect(host.switchedOff, isTrue);
    expect(published(container), isEmpty);
  });

  // Switched off while an install, an update or a settings apply is under way (the update pass starts 15 s after
  // launch): the switch is no load failure, so nothing is saved as one, and nothing is left half done.

  test('switched off while an install downloads, nothing is installed, and Install works once on', () async {
    final container = boot();
    container.read(cloudStreamRepositoryProvider);
    final notifier = container.read(cloudStreamRepositoryProvider.notifier);
    final repo = await notifier.addRepository(_repoUrl);
    host.providers = [
      {'name': 'Alpha'},
    ];
    network.holdDownloads = Completer<void>();
    final installing = notifier.install(repo.plugins.single);
    await downloading();
    await notifier.setEnabled(false);
    network.holdDownloads!.complete();
    await expectLater(installing, throwsA(isA<CloudStreamSwitchedOff>()));
    expect(container.read(cloudStreamRepositoryProvider).installed, isEmpty);
    expect(pluginFiles(), isEmpty);
    await notifier.setEnabled(true);
    await notifier.install(repo.plugins.single);
    expect(published(container), ['Alpha']);
  });

  test('switched off while the update pass downloads an update, the installed version stays as it was', () async {
    final container = boot();
    container.read(cloudStreamRepositoryProvider);
    final notifier = container.read(cloudStreamRepositoryProvider.notifier);
    final v2 = await installOne(container);
    network.version = 3;
    network.requested.clear();
    network.holdDownloads = Completer<void>();
    final updating = notifier.autoUpdate();
    await downloading();
    await notifier.setEnabled(false);
    network.holdDownloads!.complete();
    await updating;
    await notifier.setEnabled(true);
    final kept = container.read(cloudStreamRepositoryProvider).installed.single;
    expect(kept.info.version, 2);
    expect(kept.loadError, isNull);
    expect(File(v2.filePath).readAsStringSync(), 'plugin v2');
    expect(published(container), ['Alpha']);
  });

  test('an install whose load is refused, CloudStream switched off that moment, leaves nothing behind', () async {
    final container = boot();
    container.read(cloudStreamRepositoryProvider);
    final notifier = container.read(cloudStreamRepositoryProvider.notifier);
    final repo = await notifier.addRepository(_repoUrl);
    host.onReload = () => host.setSwitchedOff(true);
    await expectLater(notifier.install(repo.plugins.single), throwsA(isA<CloudStreamSwitchedOff>()));
    expect(container.read(cloudStreamRepositoryProvider).installed, isEmpty);
    expect(pluginFiles(), isEmpty);
  });

  test('an update whose load is refused, CloudStream switched off that moment, keeps the version installed', () async {
    final container = boot();
    container.read(cloudStreamRepositoryProvider);
    final notifier = container.read(cloudStreamRepositoryProvider.notifier);
    final v2 = await installOne(container);
    network.version = 3;
    await notifier.refreshAll();
    final newer = container.read(cloudStreamRepositoryProvider).updateFor(v2)!;
    host.onReload = () => host.setSwitchedOff(true);
    await expectLater(notifier.install(newer), throwsA(isA<CloudStreamSwitchedOff>()));
    final kept = container.read(cloudStreamRepositoryProvider).installed.single;
    expect(kept.info.version, 2);
    expect(kept.loadError, isNull);
    expect([for (final p in kept.providers) p.name], ['Alpha']);
  });

  test('settings applied while CloudStream is switched off leave the plugin as it was', () async {
    final container = boot();
    container.read(cloudStreamRepositoryProvider);
    final plugin = await installOne(container);
    final notifier = container.read(cloudStreamRepositoryProvider.notifier);
    await notifier.setEnabled(false);
    await expectLater(notifier.applySettings(plugin), throwsA(isA<CloudStreamSwitchedOff>()));
    final kept = container.read(cloudStreamRepositoryProvider).installed.single;
    expect(kept.loadError, isNull);
    expect([for (final p in kept.providers) p.name], ['Alpha']);
    await notifier.setEnabled(true);
    expect(published(container), ['Alpha']);
  });

  test('a failed plugin the update pass retries as CloudStream is switched off is tried again later', () async {
    saveInstalled([failedInstall('Alpha')]);
    final container = boot();
    host.onReload = () => host.setSwitchedOff(true);
    await container.read(cloudStreamRepositoryProvider.notifier).autoUpdate();
    final kept = container.read(cloudStreamRepositoryProvider).installed.single;
    expect(kept.loadError, 'NoSuchFieldError: Companion');
    expect(kept.loadErrorVersion, isNull, reason: 'not marked failed under this version');
  });

  test('switched off while learning settings, the plugins left are learned on a later visit', () async {
    final container = boot();
    container.read(cloudStreamRepositoryProvider);
    final plugin = await installOne(container);
    final notifier = container.read(cloudStreamRepositoryProvider.notifier);
    host.loaded.clear();
    host.setSwitchedOff(true);
    await notifier.learnSettings();
    host.setSwitchedOff(false);
    await notifier.learnSettings();
    expect(host.loaded.map((l) => l.path), [plugin.filePath]);
  });

  // Home's provider, one of CloudStream's, comes back when CloudStream is switched on, whatever happened meanwhile
  // (the app relaunched, another extension uninstalled), unless the person chose another.

  /// Home on the provider [plugin] registered, as the person chose it.
  Future<CloudStreamProvider> homeOn(ProviderContainer container, CsInstalledPlugin plugin) async {
    final provider = container
        .read(extensionManagerProvider)
        .whereType<CloudStreamProvider>()
        .firstWhere((p) => p.plugin.filePath == plugin.filePath);
    await container.read(activeProviderProvider.notifier).set(provider);
    return provider;
  }

  test("Home's provider comes back when CloudStream is switched on, another extension uninstalled while off", () async {
    final container = bootHome(_Settings());
    final notifier = container.read(cloudStreamRepositoryProvider.notifier);
    host.providers = [
      {'name': 'Alpha'},
    ];
    final mine = await notifier.install((await notifier.addRepository(_repoUrl)).plugins.single);
    final other = await notifier.install((await notifier.addRepository(_otherUrl)).plugins.single);
    final home = await homeOn(container, mine);
    await notifier.setEnabled(false);
    await notifier.uninstall(other);
    await notifier.setEnabled(true);
    expect(container.read(activeProviderProvider)?.packageName, home.packageName);
  });

  test("Home's provider comes back when CloudStream is switched on after a launch with it off", () async {
    final settings = _Settings();
    final first = bootHome(settings);
    final home = await homeOn(first, await installOne(first));
    await first.read(cloudStreamRepositoryProvider.notifier).setEnabled(false);
    final prefs = await SharedPreferences.getInstance();
    final kept = {for (final key in prefs.getKeys()) key: prefs.get(key)!};
    first.dispose();

    final again = bootHome(settings, kept);
    final notifier = again.read(cloudStreamRepositoryProvider.notifier);
    await notifier.load();
    await Future<void>.delayed(Duration.zero);
    await notifier.setEnabled(true);
    expect(again.read(activeProviderProvider)?.packageName, home.packageName);
    expect(settings.active, home.packageName);
  });

  test('a provider the person chose for Home while CloudStream was off stays Home\'s once it is on', () async {
    final container = bootHome(_Settings());
    final notifier = container.read(cloudStreamRepositoryProvider.notifier);
    await homeOn(container, await installOne(container));
    await notifier.setEnabled(false);
    final other = _OtherProvider();
    container.read(extensionManagerProvider.notifier).setExternalProviders('other', [other]);
    await container.read(activeProviderProvider.notifier).set(other);
    await notifier.setEnabled(true);
    expect(container.read(activeProviderProvider), same(other));
  });

  test('a plugin learns from its loads whether it has a settings screen, and keeps it', () async {
    final container = boot();
    container.read(cloudStreamRepositoryProvider);
    final plugin = await installOne(container);
    host.announce(plugin.filePath, {'providers': host.providers, 'hasSettings': true});
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(container.read(cloudStreamRepositoryProvider).installed.single.hasSettings, isTrue);
    final saved = jsonDecode(File('${support.path}/extensions/cloudstream/installed.json').readAsStringSync()) as List;
    expect((saved.single as Map)['hasSettings'], isTrue);
  });

  test('learning settings loads only the plugins nobody has asked yet, one at a time', () async {
    final container = boot();
    container.read(cloudStreamRepositoryProvider);
    final plugin = await installOne(container);
    final notifier = container.read(cloudStreamRepositoryProvider.notifier);
    // An install's load says nothing about settings in this fake (reload), so it's unknown.
    expect(container.read(cloudStreamRepositoryProvider).installed.single.hasSettings, isNull);
    host.loaded.clear();
    await notifier.learnSettings();
    expect(host.loaded.map((l) => l.path), [plugin.filePath]);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    host.loaded.clear();
    await notifier.learnSettings();
    expect(host.loaded, isEmpty, reason: 'known now');
  });

  test('a plugin whose load fails while learning settings is tried once per run, not on every visit', () async {
    final container = boot();
    container.read(cloudStreamRepositoryProvider);
    final plugin = await installOne(container);
    final notifier = container.read(cloudStreamRepositoryProvider.notifier);
    host.loaded.clear();
    host.ensureFails = StateError('load() threw');
    await notifier.learnSettings();
    await notifier.learnSettings();
    expect(host.loaded.map((l) => l.path), [plugin.filePath]);
  });

  test("where no extension's screen can be drawn (Fuchsia), learning settings loads nothing", () async {
    final container = boot();
    container.read(cloudStreamRepositoryProvider);
    await installOne(container);
    final notifier = container.read(cloudStreamRepositoryProvider.notifier);
    host.loaded.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    try {
      await notifier.learnSettings();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
    expect(host.loaded, isEmpty);
  });

  test('on the desktops and iOS, learning settings loads the plugins too: their screens show there now', () async {
    final container = boot();
    container.read(cloudStreamRepositoryProvider);
    final plugin = await installOne(container);
    final notifier = container.read(cloudStreamRepositoryProvider.notifier);
    host.loaded.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await notifier.learnSettings();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
    expect(host.loaded.map((load) => load.path), [plugin.filePath]);
  });

  test(
    "an extension's toasts, copies and links are notices under its name; a link says whether its screen is open",
    () async {
      final container = boot();
      container.read(cloudStreamRepositoryProvider);
      final plugin = await installOne(container);
      final notices = <ExtensionNotice>[];
      final listening = container.read(cloudStreamRepositoryProvider.notifier).watchNotices().listen(notices.add);
      addTearDown(listening.cancel);
      host.send({'event': 'toast', 'text': 'Saved', 'plugin': plugin.filePath});
      host.send({'event': 'copy', 'text': 'abc', 'plugin': plugin.filePath, 'session': 3});
      host.send({'event': 'openUrl', 'url': 'https://example.com', 'plugin': plugin.filePath, 'session': 3});
      host.send({'event': 'openUrl', 'url': 'https://example.com/b'});
      await Future<void>.delayed(Duration.zero);
      expect(notices.map((n) => (n.kind, n.plugin, n.text, n.inScreen)), [
        (ExtensionNoticeKind.toast, 'Alpha', 'Saved', false),
        (ExtensionNoticeKind.copy, 'Alpha', 'abc', true),
        (ExtensionNoticeKind.link, 'Alpha', 'https://example.com', true),
        (ExtensionNoticeKind.link, 'CloudStream', 'https://example.com/b', false),
      ]);
    },
  );

  test("an extension's kept pop-ups follow the engine, by its path however slashed, for its Support button", () async {
    final container = boot();
    container.read(cloudStreamRepositoryProvider);
    final plugin = await installOne(container);
    host.send({
      'event': 'popups',
      'plugin': plugin.filePath.replaceAll('/', r'\'),
      'titles': ['Support us', 'News'],
    });
    await Future<void>.delayed(Duration.zero);
    expect(container.read(cloudStreamRepositoryProvider).popupsFor(plugin), ['Support us', 'News']);
    host.send({'event': 'popups', 'plugin': plugin.filePath, 'titles': <String>[]});
    await Future<void>.delayed(Duration.zero);
    expect(container.read(cloudStreamRepositoryProvider).popupsFor(plugin), isEmpty);
    expect(container.read(cloudStreamRepositoryProvider).popups, isEmpty, reason: 'none kept: nothing held');
  });

  test('a screen the engine opens by itself comes out as a session, named for its extension', () async {
    final container = boot();
    container.read(cloudStreamRepositoryProvider);
    final plugin = await installOne(container);
    final screens = <WaitingScreen>[];
    final listening = container.read(cloudStreamRepositoryProvider.notifier).watchWaitingScreens().listen(screens.add);
    addTearDown(listening.cancel);
    host.send({'event': 'uiOpened', 'session': 7, 'plugin': plugin.filePath, 'why': 'waiting'});
    await Future<void>.delayed(Duration.zero);
    host.send({
      'event': 'ui',
      'session': 7,
      'plugin': plugin.filePath,
      'windows': [
        {
          'id': 'w1',
          'kind': 'alert',
          'root': {'id': 1, 'kind': 'text', 'text': 'Pick a server'},
        },
      ],
    });
    await Future<void>.delayed(Duration.zero);
    expect(screens.single.name, 'Alpha');
    expect(screens.single.session.id, 7);
    expect(screens.single.session.windows.single.root.text, 'Pick a server');
    screens.single.session.dispose();
  });

  test(
    'settings whose reload fails leave the plugin failed to load, as any load that fails, and no providers',
    () async {
      final container = boot();
      container.read(cloudStreamRepositoryProvider);
      final plugin = await installOne(container);
      expect(container.read(extensionManagerProvider), hasLength(1));
      host.afreshFails = StateError('load() threw');
      final notifier = container.read(cloudStreamRepositoryProvider.notifier);
      await expectLater(notifier.applySettings(plugin), throwsStateError);
      final state = container.read(cloudStreamRepositoryProvider);
      expect(state.applying, isEmpty);
      expect(state.installed.single.loadError, 'load() threw');
      expect(state.installed.single.providers, isEmpty);
      expect(state.installed.single.hasSettings, plugin.hasSettings);
      expect(container.read(extensionManagerProvider), isEmpty, reason: "its old providers aren't loaded any more");
    },
  );

  test('applying settings loads the plugin afresh and publishes new provider instances', () async {
    final container = boot();
    container.read(cloudStreamRepositoryProvider);
    final plugin = await installOne(container);
    final before = container.read(extensionManagerProvider).single;
    host.providers = [
      {'name': 'Alpha'},
      {'name': 'Bravo'},
    ];
    final notifier = container.read(cloudStreamRepositoryProvider.notifier);
    final applying = notifier.applySettings(plugin);
    expect(container.read(cloudStreamRepositoryProvider).applying, contains(CloudStreamRepository.keyOf(plugin.info)));
    await applying;
    final state = container.read(cloudStreamRepositoryProvider);
    expect(state.applying, isEmpty);
    expect(state.installed.single.providers.map((p) => p.name), ['Alpha', 'Bravo']);
    expect(host.afresh, [plugin.filePath]);
    final after = container.read(extensionManagerProvider);
    expect(after, hasLength(2));
    expect(after.any((p) => identical(p, before)), isFalse, reason: 'a screen showing it loads again');
  });
}
