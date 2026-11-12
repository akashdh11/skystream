import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/logger/app_logger.dart';
import '../../../../core/storage/history_repository.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../explore/data/explore_tmdb_provider.dart';
import '../domain/sync_progress_item.dart';
import '../domain/sync_ids.dart';
import 'simkl_service.dart';
import 'sync_outbox.dart';
import 'trakt_service.dart';
import 'anilist_service.dart';
import 'mal_service.dart';
import 'tracking_service.dart';
import '../../library/presentation/history_provider.dart';

part 'sync_manager.g.dart';

class SyncManager {
  final List<TrackingService> _services;

  /// Durability for the terminal writes. Null in tests and in any context
  /// without storage, in which case the terminal writes behave exactly as the
  /// ephemeral ones do: one attempt, best effort.
  final SyncOutbox? _outbox;

  SyncManager(this._services, {SyncOutbox? outbox}) : _outbox = outbox {
    if (outbox != null) unawaited(outbox.start(dispatch));
  }

  // Cache resolved IDs for the duration of a playback session
  Map<String, String>? _cachedIds;
  String? _cachedItemUrl;

  /// Returns all tracking services that the user is currently logged into
  Future<List<TrackingService>> getActiveServices() async {
    final active = <TrackingService>[];
    for (final service in _services) {
      if (await service.isLoggedIn) {
        active.add(service);
      }
    }
    return active;
  }

  /// Resolve IDs for the given item across all services. Uses cache if available.
  ///
  /// Only a *successful* lookup is cached. Caching an empty result meant one
  /// offline resolution poisoned the whole session — and, now that terminal
  /// writes are replayed from the outbox, it would also mean a retry hours
  /// later still had no MAL/AniList id to address the title with.
  Future<Map<String, String>> _resolveIds(MultimediaItem item) async {
    if (_cachedItemUrl == item.url && _cachedIds != null) {
      return _cachedIds!;
    }

    final ids = Map<String, String>.from(item.syncData ?? {});

    // Simkl is only asked for ids when that account is signed in. A device
    // that only uses the self-hosted profile sync never calls it.
    final active = await getActiveServices();
    SimklService? simkl;
    for (final service in active) {
      if (service is SimklService) {
        simkl = service;
        break;
      }
    }
    if (simkl == null) return ids;

    // We primarily use Simkl for resolving cross-platform IDs because its API is the most comprehensive
    var resolvedRemotely = false;
    try {
      final resolved = await simkl.syncIds(item);
      // Fills the gaps only: the title's own MAL and AniList ids name its
      // season, Simkl's (looked up by IMDb or TMDB id) the series.
      ids.addAll(withLookedUpIds(item.syncData, resolved));
      resolvedRemotely = resolved.isNotEmpty;
    } catch (e) {
      // Ignore
    }

    if (resolvedRemotely) {
      _cachedIds = ids;
      _cachedItemUrl = item.url;
    }
    return ids;
  }

  /// Clears the cached IDs, typically called when starting a new media item
  void clearCache() {
    _cachedIds = null;
    _cachedItemUrl = null;
  }

  bool _shouldSkipSync(MultimediaItem item) {
    if (item.contentType == MultimediaContentType.livestream) {
      return true;
    }
    final hasNoIds =
        item.imdbId == null &&
        item.tmdbId == null &&
        (item.syncData == null || item.syncData!.isEmpty);
    return hasNoIds;
  }

  /// MAL and AniList can only address a title by their own numeric id. When
  /// [_resolveIds] could not produce one they are not *owed* the write at all,
  /// and counting them as a failure would keep an outbox entry alive that
  /// nothing could ever satisfy.
  static const Set<String> _idBoundServices = {'mal', 'anilist'};

  bool _isOwed(TrackingService service, Map<String, String> resolvedIds) =>
      !_idBoundServices.contains(service.idPrefix) ||
      resolvedIds[service.idPrefix] != null;

  /// Performs one fan-out of a terminal write and reports, per service,
  /// what actually landed.
  ///
  /// This is the outbox's [SyncSender]. Services listed in [alreadyDelivered]
  /// are skipped: Trakt's `scrobble/stop` is not idempotent, so re-sending a
  /// write it already accepted counts a second play.
  Future<SyncDispatchResult> dispatch(
    SyncOp op,
    MultimediaItem item,
    Episode? episode,
    double progress,
    Set<String> alreadyDelivered,
  ) async {
    const nothingToDo = SyncDispatchResult(
      delivered: <String>{},
      failed: <String>{},
    );
    if (_shouldSkipSync(item)) return nothingToDo;

    final active = await getActiveServices();
    if (active.isEmpty) return nothingToDo;

    final resolvedIds = await _resolveIds(item);

    final delivered = <String>{};
    final failed = <String>{};
    for (final service in active) {
      final prefix = service.idPrefix;
      if (alreadyDelivered.contains(prefix)) continue;
      if (!_isOwed(service, resolvedIds)) continue;
      try {
        final ok = switch (op) {
          SyncOp.markWatched => await service.markWatched(
            item,
            episode,
            resolvedIds: resolvedIds,
          ),
          SyncOp.scrobbleStop => await service.scrobbleStop(
            item,
            episode,
            progress,
            resolvedIds: resolvedIds,
          ),
        };
        (ok ? delivered : failed).add(prefix);
      } catch (e) {
        talker.error('${service.name}: ${op.name} threw', e);
        failed.add(prefix);
      }
    }
    return SyncDispatchResult(delivered: delivered, failed: failed);
  }

  /// Mark an episode or movie as watched across all active services.
  ///
  /// Durable: the write is persisted before it is attempted and replayed with
  /// backoff until every service that is owed it has confirmed. [sessionKey]
  /// is the caller's playback-session identity and is what keeps a repeat
  /// emission inside one session from being queued — and therefore counted —
  /// twice.
  Future<void> markWatched(
    MultimediaItem item,
    Episode? episode, {
    String? sessionKey,
  }) async {
    if (_shouldSkipSync(item)) return;
    final outbox = _outbox;
    if (outbox == null) {
      await dispatch(SyncOp.markWatched, item, episode, 1.0, const <String>{});
      return;
    }
    await outbox.enqueue(
      SyncOp.markWatched,
      item,
      episode,
      1.0,
      session: sessionKey,
    );
  }

  /// Scrobble start event.
  ///
  /// Deliberately *not* durable. A start says "the user is watching this right
  /// now"; replaying a stale one hours later would overwrite a newer state
  /// with a lie. Losing one costs nothing — the terminal event that follows is
  /// the one that carries the record.
  Future<void> scrobbleStart(
    MultimediaItem item,
    Episode? episode,
    double progress,
  ) async {
    if (_shouldSkipSync(item)) return;

    final active = await getActiveServices();
    if (active.isEmpty) return;

    final resolvedIds = await _resolveIds(item);

    for (final service in active) {
      try {
        await service.scrobbleStart(
          item,
          episode,
          progress,
          resolvedIds: resolvedIds,
        );
      } catch (e) {
        // Ignore failure
      }
    }
  }

  /// Scrobble pause event. Ephemeral for the same reason as [scrobbleStart].
  Future<void> scrobblePause(
    MultimediaItem item,
    Episode? episode,
    double progress,
  ) async {
    if (_shouldSkipSync(item)) return;

    final active = await getActiveServices();
    if (active.isEmpty) return;

    final resolvedIds = await _resolveIds(item);

    for (final service in active) {
      try {
        await service.scrobblePause(
          item,
          episode,
          progress,
          resolvedIds: resolvedIds,
        );
      } catch (e) {
        // Ignore failure
      }
    }
  }

  /// Scrobble stop event.
  ///
  /// Durable, like [markWatched] — a stop carries the resume point the user
  /// will come back to, and it is emitted at exactly the moment a phone is
  /// most likely to be handing over between networks. The progress travels
  /// inside the entry, so replaying it later still records the right point.
  Future<void> scrobbleStop(
    MultimediaItem item,
    Episode? episode,
    double progress, {
    String? sessionKey,
  }) async {
    if (_shouldSkipSync(item)) return;
    final outbox = _outbox;
    if (outbox == null) {
      await dispatch(SyncOp.scrobbleStop, item, episode, progress, const {});
      return;
    }
    await outbox.enqueue(
      SyncOp.scrobbleStop,
      item,
      episode,
      progress,
      session: sessionKey,
    );
  }

  /// Add item to "Plan to Watch" across all active services
  Future<void> addToPlanToWatch(MultimediaItem item) async {
    if (_shouldSkipSync(item)) return;

    final active = await getActiveServices();
    if (active.isEmpty) return;

    final resolvedIds = await _resolveIds(item);

    for (final service in active) {
      try {
        await service.addToPlanToWatch(item, resolvedIds: resolvedIds);
      } catch (e) {
        // Ignore failure
      }
    }
  }

  /// Remove playback progress item from services that support it (e.g. Trakt)
  Future<bool> removePlaybackProgress(SyncProgressItem item) async {
    if (item.id == null) return false;
    final active = await getActiveServices();
    bool success = false;
    for (final service in active) {
      try {
        final removed = await service.removePlaybackProgress(
          item.id.toString(),
        );
        if (removed) success = true;
      } catch (e) {
        // Ignore failure
      }
    }
    return success;
  }
}

@riverpod
SyncManager syncManager(Ref ref) {
  // Kept alive: the manager owns the outbox, whose queue, in-flight guard and
  // backoff timer must outlive any single read. Rebuilding it per dispatch —
  // the tracker reads this provider on every event — would mean two drains
  // racing over the same persisted queue.
  ref.keepAlive();

  final outbox = SyncOutbox(
    // Resolved lazily: storageServiceProvider throws until StorageService.init
    // has run, and building the sync manager must not depend on that ordering.
    store: HiveSyncOutboxStore(() => ref.read(storageServiceProvider)),
    // A handover back onto a working network is the single best moment to
    // retry; the backoff timer is the fallback when the OS never reports one.
    onOnline: Connectivity().onConnectivityChanged.where(
      (results) =>
          results.isNotEmpty && !results.contains(ConnectivityResult.none),
    ),
  );
  ref.onDispose(outbox.dispose);

  return SyncManager([
    ref.watch(simklServiceProvider),
    ref.watch(traktServiceProvider),
    ref.watch(aniListServiceProvider),
    ref.watch(malServiceProvider),
  ], outbox: outbox);
}

@riverpod
Future<List<SyncProgressItem>> syncedProgress(Ref ref) async {
  final manager = ref.watch(syncManagerProvider);
  final storage = ref.watch(historyRepositoryProvider);

  final activeServices = await manager.getActiveServices();
  if (activeServices.isEmpty) return [];

  final List<SyncProgressItem> syncedItems = [];

  for (final service in activeServices) {
    try {
      final items = await service.pullPlaybackProgress();
      syncedItems.addAll(items);
    } catch (e) {
      talker.error('Failed to pull progress from ${service.name}', e);
    }
  }

  if (syncedItems.isEmpty) return [];

  final localHistory = storage.getWatchHistory();

  final filteredItems = syncedItems.where((syncItem) {
    final localMatch = localHistory.firstWhere(
      (local) {
        final localTmdb = local.item.tmdbId?.toString();
        final localImdb = local.item.imdbId;

        if (syncItem.tmdbId != null && localTmdb == syncItem.tmdbId) {
          return true;
        }
        if (syncItem.imdbId != null && localImdb == syncItem.imdbId) {
          return true;
        }
        if (local.item.title.toLowerCase() == syncItem.title.toLowerCase()) {
          return true;
        }

        return false;
      },
      orElse: () => HistoryItem(
        item: MultimediaItem(title: '', url: '', posterUrl: ''),
        position: 0,
        duration: 0,
        timestamp: 0,
      ),
    );

    if (localMatch.item.url.isEmpty) return true;

    final localDate = DateTime.fromMillisecondsSinceEpoch(localMatch.timestamp);
    if (localDate.isBefore(syncItem.pausedAt)) {
      final newPos = localMatch.duration > 0
          ? (localMatch.duration * syncItem.progressPercentage / 100).round()
          : 0;
      // Defer the cross-provider write to the next event-loop turn so this
      // provider's build finishes before watchHistoryProvider is notified.
      // Using Future<void>.delayed(Duration.zero) keeps us off the microtask
      // queue — a microtask scheduled from inside a provider's build runs
      // before the build completes, which can re-enter the same provider.
      Future<void>.delayed(Duration.zero, () {
        ref
            .read(watchHistoryProvider.notifier)
            .updateHistoryItemTimestampAndPosition(
              localMatch,
              syncItem.pausedAt.millisecondsSinceEpoch,
              newPos,
            );
      });
    }

    return false;
  }).toList();

  final Map<String, SyncProgressItem> uniqueItems = {};
  for (final item in filteredItems) {
    final key = item.tmdbId ?? item.imdbId ?? item.title;
    if (!uniqueItems.containsKey(key) ||
        item.pausedAt.isAfter(uniqueItems[key]!.pausedAt)) {
      uniqueItems[key] = item;
    }
  }

  final result = uniqueItems.values.toList();
  result.sort((a, b) => b.pausedAt.compareTo(a.pausedAt));

  // Fetch TMDB posters concurrently
  final tmdbService = ref.read(tmdbServiceProvider);
  final enrichedResult = await Future.wait(
    result.map((item) async {
      if (item.tmdbId == null) return item;
      try {
        final mediaType = item.type == MultimediaContentType.series
            ? 'tv'
            : 'movie';
        final details = await tmdbService.getDetailsForCarousel(
          int.parse(item.tmdbId!),
          mediaType,
        );
        if (details != null && details['poster_path'] != null) {
          return item.copyWith(posterUrl: details['poster_path'] as String);
        }
      } catch (_) {}
      return item;
    }),
  );

  return enrichedResult;
}
