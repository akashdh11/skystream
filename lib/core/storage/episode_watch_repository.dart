import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entity/multimedia_item.dart';
import 'history_repository.dart';
import 'storage_service.dart';

final episodeWatchRevisionProvider =
    NotifierProvider<EpisodeWatchRevision, int>(EpisodeWatchRevision.new);

class EpisodeWatchRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() {
    state++;
  }
}

final episodeWatchRepositoryProvider = Provider<EpisodeWatchRepository>((ref) {
  return EpisodeWatchRepository(
    ref.watch(storageServiceProvider),
    ref.watch(historyRepositoryProvider),
    () => ref.read(episodeWatchRevisionProvider.notifier).bump(),
  );
});

class EpisodeWatchRepository {
  EpisodeWatchRepository(
    this._storageService,
    this._historyRepository,
    this._notifyChanged,
  );

  final StorageService _storageService;
  final HistoryRepository _historyRepository;
  final void Function() _notifyChanged;

  static const String _storageKey = 'episode_watch_overrides_v1';

  Map<String, bool>? _cachedOverrides;

  String _episodeKey(String mainUrl, Episode episode) {
    final stableEpisodeId = episode.episode > 0
        ? [episode.season, episode.episode, episode.dubStatus.name].join(':')
        : [episode.url, episode.name, episode.dubStatus.name].join(':');

    return sha256.convert(utf8.encode('$mainUrl|$stableEpisodeId')).toString();
  }

  Map<String, bool> _readOverrides() {
    final cached = _cachedOverrides;
    if (cached != null) {
      return cached;
    }

    final raw = _storageService.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return _cachedOverrides = <String, bool>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return _cachedOverrides = <String, bool>{};
      }

      return _cachedOverrides = decoded.map<String, bool>(
        (key, value) => MapEntry(key.toString(), value == true),
      );
    } catch (_) {
      return _cachedOverrides = <String, bool>{};
    }
  }

  Future<void> _persist(Map<String, bool> overrides) async {
    _cachedOverrides = overrides;
    await _storageService.setString(_storageKey, jsonEncode(overrides));
    _notifyChanged();
  }

  bool? getExplicitState(String mainUrl, Episode episode) {
    return _readOverrides()[_episodeKey(mainUrl, episode)];
  }

  bool isWatched(String mainUrl, Episode episode) {
    final explicit = getExplicitState(mainUrl, episode);
    if (explicit != null) {
      return explicit;
    }

    final position = _historyRepository.getEpisodePosition(
      episode.url,
      mainUrl: mainUrl,
      season: episode.season,
      episode: episode.episode,
    );
    final duration = _historyRepository.getEpisodeDuration(
      episode.url,
      mainUrl: mainUrl,
      season: episode.season,
      episode: episode.episode,
    );

    return duration > 0 && position / duration >= 0.90;
  }

  Future<void> setWatched(String mainUrl, Episode episode, bool watched) async {
    final overrides = Map<String, bool>.from(_readOverrides());
    overrides[_episodeKey(mainUrl, episode)] = watched;
    await _persist(overrides);
  }

  Map<String, bool> exportOverrides() {
    return Map<String, bool>.from(_readOverrides());
  }

  Future<void> mergeOverrides(Map<String, bool> incoming) async {
    if (incoming.isEmpty) return;
    final current = Map<String, bool>.from(_readOverrides());
    var changed = false;
    for (final entry in incoming.entries) {
      if (current[entry.key] == entry.value) continue;
      current[entry.key] = entry.value;
      changed = true;
    }
    if (changed) await _persist(current);
  }

  Future<void> setManyWatched(
    String mainUrl,
    Iterable<Episode> episodes,
    bool watched,
  ) async {
    final overrides = Map<String, bool>.from(_readOverrides());

    for (final episode in episodes) {
      overrides[_episodeKey(mainUrl, episode)] = watched;
    }

    await _persist(overrides);
  }
}
