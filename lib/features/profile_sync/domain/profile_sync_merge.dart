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
