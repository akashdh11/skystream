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
}
