import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/features/profile_sync/domain/profile_sync_merge.dart';
import 'package:skystream/features/profile_sync/domain/profile_sync_payload.dart';

void main() {
  test('newer history wins per key, including episode rows', () {
    final newer = newerHistoryEntries(
      local: [
        {
          'key': 'show',
          'entry': {'timestamp': 10, 'position': 1},
        },
        {
          'key': 'EP_ep1',
          'entry': {'timestamp': 50, 'position': 9},
        },
      ],
      remote: [
        {
          'key': 'show',
          'entry': {'timestamp': 20, 'position': 5},
        },
        {
          'key': 'EP_ep1',
          'entry': {'timestamp': 40, 'position': 1},
        },
        {
          'key': 'movie',
          'entry': {'timestamp': 3, 'position': 2},
        },
      ],
    );

    expect(newer.map((item) => item['key']), ['show', 'movie']);
    expect((newer.first['entry'] as Map)['position'], 5);
  });

  test(
    'episode checkmarks union and an incoming value replaces the stored one',
    () {
      expect(
        mergeEpisodeOverrides({'a': true, 'b': false}, {'b': true, 'c': false}),
        {'a': true, 'b': true, 'c': false},
      );
    },
  );

  test('an equal timestamp takes the remote row, matching the server', () {
    final newer = newerHistoryEntries(
      local: [
        {
          'key': 'show',
          'entry': {'timestamp': 10, 'position': 4},
        },
      ],
      remote: [
        {
          'key': 'show',
          'entry': {'timestamp': 10, 'position': 1},
        },
      ],
    );
    expect((newer.single['entry'] as Map)['position'], 1);
  });

  test('plugin lists deduplicate by identity and incoming wins', () {
    final plugins = unionByKey(
      [
        {'packageName': 'com.a', 'repositoryUrl': 'https://old'},
      ],
      [
        {'packageName': 'com.a', 'repositoryUrl': 'https://new'},
        {'packageName': 'com.b', 'repositoryUrl': 'https://b'},
      ],
      (plugin) => plugin['packageName'],
    );

    expect(plugins, [
      {'packageName': 'com.a', 'repositoryUrl': 'https://new'},
      {'packageName': 'com.b', 'repositoryUrl': 'https://b'},
    ]);

    final replaced = unionByKey(
      plugins,
      [
        {'packageName': 'com.c', 'repositoryUrl': 'https://c'},
      ],
      (plugin) => plugin['packageName'],
      replace: true,
    );
    expect(replaced, [
      {'packageName': 'com.c', 'repositoryUrl': 'https://c'},
    ]);
  });

  test('addon urls union unless the device replaces the list', () {
    expect(
      unionStrings(
        ['https://addon.one/manifest.json'],
        ['https://addon.one/manifest.json', 'https://addon.two/manifest.json'],
      ),
      ['https://addon.one/manifest.json', 'https://addon.two/manifest.json'],
    );
    expect(
      unionStrings(
        ['https://addon.one/manifest.json'],
        ['https://addon.two/manifest.json'],
        replace: true,
      ),
      ['https://addon.two/manifest.json'],
    );
  });

  test('payload json keeps history, checkmarks, and plugin lists', () {
    const payload = ProfileSyncPayload(
      updatedAt: 42,
      history: [
        {
          'key': 'EP_ep1',
          'entry': {'timestamp': 7},
        },
      ],
      episodeOverrides: {'abc': true},
      skystreamPlugins: [
        {'packageName': 'com.a', 'repositoryUrl': 'https://repo'},
      ],
      stremioAddons: ['https://addon/manifest.json'],
    );

    final decoded = ProfileSyncPayload.fromJson(payload.toJson());
    expect(decoded.updatedAt, 42);
    expect(decoded.history.single['key'], 'EP_ep1');
    expect(decoded.episodeOverrides['abc'], isTrue);
    expect(decoded.skystreamPlugins.single['packageName'], 'com.a');
    expect(decoded.stremioAddons, ['https://addon/manifest.json']);
    expect(decoded.replaceExtensions, isFalse);
  });

  test('payload encodes activeProviderId, nuvioRepoSettings, stremioAddonStates, and tombstones via meta fallback', () {
    const payload = ProfileSyncPayload(
      updatedAt: 99,
      skystreamPlugins: [
        {'packageName': 'com.a', 'url': 'https://a.sky'},
      ],
      activeProviderId: 'com.a::sub1',
      nuvioRepoSettings: {
        'https://nuvio.repo/manifest.json': {
          'disabled': ['s1'],
          'enabled': ['s2'],
        },
      },
      stremioAddonStates: {'https://addon/manifest.json': false},
      deletedHistoryTimestamps: {'show': 88},
      deletedLibraryUrls: ['https://removed'],
    );

    final json = payload.toJson();
    // Emulate an older v1 server that strips unknown top-level keys and only
    // keeps skystreamPlugins.
    final v1ServerRoundTrip = {
      'version': json['version'],
      'updatedAt': json['updatedAt'],
      'skystreamPlugins': json['skystreamPlugins'],
    };

    final decoded = ProfileSyncPayload.fromJson(v1ServerRoundTrip);
    expect(decoded.skystreamPlugins, [
      {'packageName': 'com.a', 'url': 'https://a.sky'},
    ]);
    expect(decoded.activeProviderId, 'com.a::sub1');
    expect(decoded.nuvioRepoSettings['https://nuvio.repo/manifest.json'], {
      'disabled': ['s1'],
      'enabled': ['s2'],
    });
    expect(decoded.stremioAddonStates['https://addon/manifest.json'], isFalse);
    expect(decoded.deletedHistoryTimestamps['show'], 88);
    expect(decoded.deletedLibraryUrls, ['https://removed']);
  });

  test('mergeStringsThreeWay unions without baseline and propagates additions/removals with baseline', () {
    final firstSync = mergeStringsThreeWay(
      baseline: null,
      local: ['localOnly'],
      remote: ['remoteOnly'],
    );
    expect(firstSync.toAddLocally, ['remoteOnly']);
    expect(firstSync.toRemoveLocally, isEmpty);
    expect(firstSync.merged, ['remoteOnly', 'localOnly']);

    final deviceARemoves = mergeStringsThreeWay(
      baseline: ['a', 'b'],
      local: ['b'],
      remote: ['a', 'b', 'c'],
    );
    expect(deviceARemoves.toAddLocally, ['c']);
    expect(deviceARemoves.toRemoveLocally, isEmpty);
    expect(deviceARemoves.merged, ['b', 'c']);

    final deviceBObservesRemoval = mergeStringsThreeWay(
      baseline: ['a', 'b'],
      local: ['a', 'b'],
      remote: ['b', 'c'],
    );
    expect(deviceBObservesRemoval.toAddLocally, ['c']);
    expect(deviceBObservesRemoval.toRemoveLocally, ['a']);
    expect(deviceBObservesRemoval.merged, ['b', 'c']);
  });

  test('mergeMapsThreeWay propagates updates and removals by key', () {
    final diff = mergeMapsThreeWay(
      baseline: [
        {'packageName': 'com.a', 'customBaseUrl': 'https://v1'},
        {'packageName': 'com.b'},
      ],
      local: [
        {'packageName': 'com.a', 'customBaseUrl': 'https://v1'},
        {'packageName': 'com.b'},
      ],
      remote: [
        {'packageName': 'com.a', 'customBaseUrl': 'https://v2'},
        {'packageName': 'com.c', 'url': 'https://c.sky'},
      ],
      keyOf: (p) => p['packageName'],
    );

    expect(diff.toRemoveLocally, ['com.b']);
    expect(diff.toAddLocally, [
      {'packageName': 'com.a', 'customBaseUrl': 'https://v2'},
      {'packageName': 'com.c', 'url': 'https://c.sky'},
    ]);
    expect(diff.merged, [
      {'packageName': 'com.a', 'customBaseUrl': 'https://v2'},
      {'packageName': 'com.c', 'url': 'https://c.sky'},
    ]);
  });

  test('mergeHistoryThreeWay propagates deletions and revives on newer watch', () {
    final deleted = mergeHistoryThreeWay(
      baseline: [
        {'key': 'show', 'entry': {'timestamp': 100, 'position': 50}},
        {'key': 'keep', 'entry': {'timestamp': 100, 'position': 10}},
      ],
      local: [
        {'key': 'keep', 'entry': {'timestamp': 100, 'position': 10}},
      ],
      remote: [
        {'key': 'show', 'entry': {'timestamp': 100, 'position': 50}},
        {'key': 'keep', 'entry': {'timestamp': 100, 'position': 10}},
      ],
      localDeletedTimestamps: const {},
      remoteDeletedTimestamps: const {},
      nowMillis: 200,
    );

    expect(deleted.merged.map((e) => e['key']), ['keep']);
    expect(deleted.deletedTimestamps['show'], 200);

    // Other device receives tombstone and removes local stale row.
    final syncedToOther = mergeHistoryThreeWay(
      baseline: [
        {'key': 'show', 'entry': {'timestamp': 100, 'position': 50}},
      ],
      local: [
        {'key': 'show', 'entry': {'timestamp': 100, 'position': 50}},
      ],
      remote: const [],
      localDeletedTimestamps: const {},
      remoteDeletedTimestamps: deleted.deletedTimestamps,
      nowMillis: 250,
    );
    expect(syncedToOther.toDeleteLocally, ['show']);
    expect(syncedToOther.merged, isEmpty);

    // Watching again later (timestamp 300 > 200) revives the entry.
    final revived = mergeHistoryThreeWay(
      baseline: const [],
      local: [
        {'key': 'show', 'entry': {'timestamp': 300, 'position': 12}},
      ],
      remote: const [],
      localDeletedTimestamps: const {},
      remoteDeletedTimestamps: deleted.deletedTimestamps,
      nowMillis: 310,
    );
    expect(revived.merged.map((e) => e['key']), ['show']);
    expect(revived.deletedTimestamps.containsKey('show'), isFalse);
  });

  test('mergeLibraryThreeWay handles additions, removals, and re-bookmarking', () {
    final removed = mergeLibraryThreeWay(
      baseline: [
        {'url': 'https://a', 'title': 'A'},
        {'url': 'https://b', 'title': 'B'},
      ],
      local: [
        {'url': 'https://a', 'title': 'A'},
      ],
      remote: [
        {'url': 'https://a', 'title': 'A'},
        {'url': 'https://b', 'title': 'B'},
        {'url': 'https://c', 'title': 'C'},
      ],
    );
    expect(removed.merged.map((e) => e['url']), ['https://a', 'https://c']);
    expect(removed.toAddLocally.map((e) => e['url']), ['https://c']);

    final reAdded = mergeLibraryThreeWay(
      baseline: [
        {'url': 'https://a', 'title': 'A'},
      ],
      local: [
        {'url': 'https://a', 'title': 'A'},
        {'url': 'https://b', 'title': 'B'},
      ],
      remote: [
        {'url': 'https://a', 'title': 'A'},
      ],
      deletedUrls: const {'https://b'},
    );
    expect(reAdded.merged.map((e) => e['url']), ['https://a', 'https://b']);
  });
}
