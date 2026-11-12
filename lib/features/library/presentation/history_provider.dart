import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/storage/history_repository.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../profile_sync/profile_sync_hooks.dart';
import '../../settings/presentation/general_settings_provider.dart';

export '../../../../core/storage/history_repository.dart' show HistoryItem;

part 'history_provider.g.dart';

@Riverpod(keepAlive: true)
class WatchHistory extends _$WatchHistory {
  @override
  List<HistoryItem> build() {
    final repository = ref.watch(historyRepositoryProvider);
    return repository.getWatchHistory();
  }

  void refresh() {
    // The writes before a refresh are awaited, and the provider can be disposed meanwhile
    // (the app closing while the player saves its position).
    if (!ref.mounted) return;
    final repository = ref.read(historyRepositoryProvider);
    state = repository.getWatchHistory();
  }

  Future<void> clearAllHistory() async {
    final repository = ref.read(historyRepositoryProvider);
    await repository.clearAllHistory();
    refresh();
  }

  Future<void> removeFromHistory(String url) async {
    final repository = ref.read(historyRepositoryProvider);
    await repository.removeFromHistory(url);
    refresh();
    _scheduleProfileSync();
  }

  Future<void> updateHistoryItemTimestampAndPosition(
    HistoryItem item,
    int timestamp,
    int position,
  ) async {
    final repository = ref.read(historyRepositoryProvider);
    await repository.updateHistoryItemTimestampAndPosition(
      item,
      timestamp,
      position,
    );
    refresh();
    _scheduleProfileSync();
  }

  Future<void> saveProgress(
    MultimediaItem item,
    int position,
    int duration, {
    String? lastStreamUrl,
    String? lastEpisodeUrl,
    int? season,
    int? episode,
    String? episodeTitle,
    String? episodePosterUrl,
  }) async {
    final enabled = ref.read(generalSettingsProvider).watchHistoryEnabled;
    if (!enabled) return;

    // For livestreams, we don't save progress but we still want it in history
    final isLivestream = item.contentType == MultimediaContentType.livestream;
    final finalPosition = isLivestream ? 0 : position;
    final finalDuration = isLivestream ? 0 : duration;

    final repository = ref.read(historyRepositoryProvider);
    await repository.saveProgress(
      item,
      finalPosition,
      finalDuration,
      lastStreamUrl: lastStreamUrl,
      lastEpisodeUrl: lastEpisodeUrl,
      season: season,
      episode: episode,
      episodeTitle: episodeTitle,
      episodePosterUrl: episodePosterUrl,
    );
    refresh();
    _scheduleProfileSync();
  }

  void _scheduleProfileSync() {
    ref.read(profileSyncHooksProvider).onLocalChange?.call();
  }
}
