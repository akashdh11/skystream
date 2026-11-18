import 'dart:math' as math;

/// Pure merge rules shared by the client and covered by unit tests.
/// The sync server applies the same rules in `sync-server/merge.js`.

int historyTimestamp(Map<String, dynamic> item) {
  final entry = item['entry'];
  if (entry is! Map) return 0;
  final timestamp = entry['timestamp'];
  if (timestamp is num) return timestamp.toInt();
  return 0;
}

String? historyKey(Map<String, dynamic> item) {
  final key = item['key'];
  return key is String && key.isNotEmpty ? key : null;
}

bool _sameEntry(Map<dynamic, dynamic> local, Map<dynamic, dynamic> remote) {
  if (local.length != remote.length) return false;
  for (final key in local.keys) {
    if (!remote.containsKey(key) || local[key] != remote[key]) return false;
  }
  return true;
}

bool _sameStringMap(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (b[key] != a[key]) return false;
  }
  return true;
}

/// Remote history rows the device should write.
///
/// A newer timestamp wins. An equal timestamp takes the remote row when the
/// entries differ, which is the row the server kept, so two devices do not
/// trade the same timestamp back and forth. An identical row is left alone.
List<Map<String, dynamic>> newerHistoryEntries({
  required List<Map<String, dynamic>> local,
  required List<Map<String, dynamic>> remote,
}) {
  final localEntries = <String, Map<dynamic, dynamic>>{};
  for (final item in local) {
    final key = historyKey(item);
    final entry = item['entry'];
    if (key == null || entry is! Map) continue;
    localEntries[key] = entry;
  }

  final newer = <Map<String, dynamic>>[];
  for (final item in remote) {
    final key = historyKey(item);
    final entry = item['entry'];
    if (key == null || entry is! Map) continue;
    final localEntry = localEntries[key];
    if (localEntry == null) {
      newer.add(item);
      continue;
    }
    final remoteTimestamp = historyTimestamp(item);
    final localTimestamp = historyTimestamp({'entry': localEntry});
    if (remoteTimestamp > localTimestamp ||
        (remoteTimestamp == localTimestamp && !_sameEntry(localEntry, entry))) {
      newer.add(item);
    }
  }
  return newer;
}

/// Incoming checkmarks replace stored ones. Keys only on one side are kept.
Map<String, bool> mergeEpisodeOverrides(
  Map<String, bool> local,
  Map<String, bool> incoming,
) {
  return {...local, ...incoming};
}

List<String> unionStrings(
  List<String> existing,
  List<String> incoming, {
  bool replace = false,
}) {
  if (replace) return List<String>.from(incoming);
  return {...existing, ...incoming}.toList();
}

List<Map<String, String>> unionByKey(
  List<Map<String, String>> existing,
  List<Map<String, String>> incoming,
  String? Function(Map<String, String> item) keyOf, {
  bool replace = false,
}) {
  if (replace) return List<Map<String, String>>.from(incoming);
  final merged = <String, Map<String, String>>{};
  for (final item in [...existing, ...incoming]) {
    final key = keyOf(item);
    if (key == null || key.isEmpty) continue;
    merged[key] = item;
  }
  return merged.values.toList();
}

class ThreeWayListDiff<T> {
  final List<T> merged;
  final List<T> toAddLocally;
  final List<String> toRemoveLocally;
  final bool hasLocalChanges;

  const ThreeWayListDiff({
    required this.merged,
    required this.toAddLocally,
    required this.toRemoveLocally,
    required this.hasLocalChanges,
  });
}

ThreeWayListDiff<String> mergeStringsThreeWay({
  required List<String>? baseline,
  required List<String> local,
  required List<String> remote,
}) {
  final localSet = local.toSet();
  final remoteSet = remote.toSet();
  if (baseline == null) {
    final merged = <String>{...remote, ...local}.toList();
    final toAddLocally = <String>[
      for (final item in remote)
        if (!localSet.contains(item)) item,
    ];
    return ThreeWayListDiff<String>(
      merged: merged,
      toAddLocally: toAddLocally,
      toRemoveLocally: const [],
      hasLocalChanges: local.any((item) => !remoteSet.contains(item)),
    );
  }

  final baselineSet = baseline.toSet();
  final removedLocally = baselineSet.difference(localSet);
  final removedRemotely = baselineSet.difference(remoteSet);

  final toAddLocally = <String>[
    for (final item in remote)
      if (!localSet.contains(item) && !removedLocally.contains(item)) item,
  ];
  final toRemoveLocally = <String>[
    for (final item in local)
      if (removedRemotely.contains(item)) item,
  ];
  final merged = <String>[
    for (final item in <String>{...remote, ...local})
      if (!removedLocally.contains(item) && !removedRemotely.contains(item))
        item,
  ];

  return ThreeWayListDiff<String>(
    merged: merged,
    toAddLocally: toAddLocally,
    toRemoveLocally: toRemoveLocally,
    hasLocalChanges:
        removedLocally.isNotEmpty ||
        local.any((item) => !baselineSet.contains(item)),
  );
}

ThreeWayListDiff<Map<String, String>> mergeMapsThreeWay({
  required List<Map<String, String>>? baseline,
  required List<Map<String, String>> local,
  required List<Map<String, String>> remote,
  required String? Function(Map<String, String> item) keyOf,
}) {
  final localMap = <String, Map<String, String>>{};
  for (final item in local) {
    final key = keyOf(item);
    if (key != null && key.isNotEmpty) localMap[key] = item;
  }
  final remoteMap = <String, Map<String, String>>{};
  for (final item in remote) {
    final key = keyOf(item);
    if (key != null && key.isNotEmpty) remoteMap[key] = item;
  }

  if (baseline == null) {
    final merged = <String, Map<String, String>>{};
    final toAddLocally = <Map<String, String>>[];
    for (final entry in remoteMap.entries) {
      merged[entry.key] = entry.value;
      if (!localMap.containsKey(entry.key)) {
        toAddLocally.add(entry.value);
      }
    }
    for (final entry in localMap.entries) {
      merged[entry.key] = entry.value;
    }
    return ThreeWayListDiff<Map<String, String>>(
      merged: merged.values.toList(),
      toAddLocally: toAddLocally,
      toRemoveLocally: const [],
      hasLocalChanges: localMap.entries.any((e) {
        final r = remoteMap[e.key];
        return r == null || !_sameStringMap(e.value, r);
      }),
    );
  }

  final baseMap = <String, Map<String, String>>{};
  for (final item in baseline) {
    final key = keyOf(item);
    if (key != null && key.isNotEmpty) baseMap[key] = item;
  }

  final baseKeys = baseMap.keys.toSet();
  final localKeys = localMap.keys.toSet();
  final remoteKeys = remoteMap.keys.toSet();

  final removedLocally = baseKeys.difference(localKeys);
  final removedRemotely = baseKeys.difference(remoteKeys);

  final toAddLocally = <Map<String, String>>[];
  final toRemoveLocally = <String>[
    for (final key in localMap.keys)
      if (removedRemotely.contains(key)) key,
  ];

  final merged = <Map<String, String>>[];
  final allKeys = <String>{...remoteMap.keys, ...localMap.keys};
  var hasLocalChanges = removedLocally.isNotEmpty;

  for (final key in allKeys) {
    if (removedLocally.contains(key) || removedRemotely.contains(key)) {
      continue;
    }
    final l = localMap[key];
    final r = remoteMap[key];
    final b = baseMap[key];

    if (l == null && r != null) {
      merged.add(r);
      toAddLocally.add(r);
    } else if (r == null && l != null) {
      merged.add(l);
      hasLocalChanges = true;
    } else if (l != null && r != null) {
      final localChanged = b == null || !_sameStringMap(l, b);
      final remoteChanged = b != null && !_sameStringMap(r, b);
      if (localChanged) hasLocalChanges = true;
      if (!localChanged && remoteChanged) {
        merged.add(r);
        toAddLocally.add(r);
      } else {
        merged.add(l);
      }
    }
  }

  return ThreeWayListDiff<Map<String, String>>(
    merged: merged,
    toAddLocally: toAddLocally,
    toRemoveLocally: toRemoveLocally,
    hasLocalChanges: hasLocalChanges,
  );
}

({
  List<Map<String, dynamic>> merged,
  List<Map<String, dynamic>> toWriteLocally,
  List<String> toDeleteLocally,
  Map<String, int> deletedTimestamps,
})
mergeHistoryThreeWay({
  required List<Map<String, dynamic>>? baseline,
  required List<Map<String, dynamic>> local,
  required List<Map<String, dynamic>> remote,
  required Map<String, int> localDeletedTimestamps,
  required Map<String, int> remoteDeletedTimestamps,
  required int nowMillis,
}) {
  final deletedTimestamps = Map<String, int>.from(localDeletedTimestamps);
  for (final entry in remoteDeletedTimestamps.entries) {
    final prev = deletedTimestamps[entry.key] ?? 0;
    if (entry.value > prev) {
      deletedTimestamps[entry.key] = entry.value;
    }
  }

  final localMap = <String, Map<String, dynamic>>{};
  for (final item in local) {
    final key = historyKey(item);
    if (key != null && item['entry'] is Map) localMap[key] = item;
  }
  final remoteMap = <String, Map<String, dynamic>>{};
  for (final item in remote) {
    final key = historyKey(item);
    if (key != null && item['entry'] is Map) remoteMap[key] = item;
  }

  if (baseline != null) {
    for (final item in baseline) {
      final key = historyKey(item);
      if (key == null || localMap.containsKey(key)) continue;
      final baseTs = historyTimestamp(item);
      final prevDel = deletedTimestamps[key] ?? 0;
      deletedTimestamps[key] = math.max(
        prevDel,
        math.max(baseTs, nowMillis),
      );
    }
  }

  final merged = <Map<String, dynamic>>[];
  final toWriteLocally = <Map<String, dynamic>>[];
  final toDeleteLocally = <String>[];

  final allKeys = <String>{...remoteMap.keys, ...localMap.keys};
  for (final key in allKeys) {
    final localItem = localMap[key];
    final remoteItem = remoteMap[key];

    late final Map<String, dynamic> winner;
    if (localItem == null) {
      winner = remoteItem!;
    } else if (remoteItem == null) {
      winner = localItem;
    } else {
      final localTs = historyTimestamp(localItem);
      final remoteTs = historyTimestamp(remoteItem);
      if (remoteTs > localTs) {
        winner = remoteItem;
      } else if (localTs > remoteTs) {
        winner = localItem;
      } else {
        winner = _sameEntry(
          localItem['entry'] as Map,
          remoteItem['entry'] as Map,
        )
            ? localItem
            : remoteItem;
      }
    }

    final winnerTs = historyTimestamp(winner);
    final delTs = deletedTimestamps[key];
    if (delTs != null && winnerTs <= delTs) {
      if (localItem != null) toDeleteLocally.add(key);
      continue;
    }
    if (delTs != null && winnerTs > delTs) {
      deletedTimestamps.remove(key);
    }

    merged.add(winner);
    if (localItem == null) {
      toWriteLocally.add(winner);
    } else {
      final localTs = historyTimestamp(localItem);
      if (winnerTs > localTs ||
          (winnerTs == localTs &&
              !_sameEntry(
                localItem['entry'] as Map,
                winner['entry'] as Map,
              ))) {
        toWriteLocally.add(winner);
      }
    }
  }

  return (
    merged: merged,
    toWriteLocally: toWriteLocally,
    toDeleteLocally: toDeleteLocally,
    deletedTimestamps: deletedTimestamps,
  );
}

ThreeWayListDiff<Map<String, dynamic>> mergeLibraryThreeWay({
  required List<Map<String, dynamic>>? baseline,
  required List<Map<String, dynamic>> local,
  required List<Map<String, dynamic>> remote,
  Set<String> deletedUrls = const {},
}) {
  final localMap = <String, Map<String, dynamic>>{};
  for (final item in local) {
    final url = item['url'];
    if (url is String && url.isNotEmpty) localMap[url] = item;
  }
  final remoteMap = <String, Map<String, dynamic>>{};
  for (final item in remote) {
    final url = item['url'];
    if (url is String && url.isNotEmpty) remoteMap[url] = item;
  }
  final baseMap = <String, Map<String, dynamic>>{};
  if (baseline != null) {
    for (final item in baseline) {
      final url = item['url'];
      if (url is String && url.isNotEmpty) baseMap[url] = item;
    }
  }

  final baseUrls = baseMap.keys.toSet();
  final localUrls = localMap.keys.toSet();
  final remoteUrls = remoteMap.keys.toSet();

  final removedLocally = baseline == null
      ? <String>{}
      : baseUrls.difference(localUrls);
  final removedRemotely = baseline == null
      ? <String>{}
      : baseUrls.difference(remoteUrls);

  // A URL explicitly re-added locally since baseline should revive even if it
  // was previously in deletedUrls.
  final newlyAddedLocally = baseline == null
      ? <String>{}
      : localUrls.difference(baseUrls);
  final effectiveDeleted = <String>{
    ...removedLocally,
    ...removedRemotely,
    for (final url in deletedUrls)
      if (!newlyAddedLocally.contains(url)) url,
  };

  final toAddLocally = <Map<String, dynamic>>[
    for (final entry in remoteMap.entries)
      if (!localMap.containsKey(entry.key) &&
          !effectiveDeleted.contains(entry.key))
        entry.value,
  ];
  final toRemoveLocally = <String>[
    for (final url in localMap.keys)
      if (effectiveDeleted.contains(url) && !newlyAddedLocally.contains(url))
        url,
  ];

  final merged = <Map<String, dynamic>>[];
  final allUrls = <String>{...remoteMap.keys, ...localMap.keys};
  for (final url in allUrls) {
    if (effectiveDeleted.contains(url)) continue;
    merged.add(localMap[url] ?? remoteMap[url]!);
  }

  return ThreeWayListDiff<Map<String, dynamic>>(
    merged: merged,
    toAddLocally: toAddLocally,
    toRemoveLocally: toRemoveLocally,
    hasLocalChanges:
        removedLocally.isNotEmpty ||
        (baseline == null ? localMap.isNotEmpty : newlyAddedLocally.isNotEmpty),
  );
}
