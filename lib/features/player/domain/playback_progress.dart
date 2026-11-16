/// Reading and writing "where was I" for one playback session.
///
/// Engine-agnostic on purpose: it takes a [ProgressSample] and never touches a
/// player. That matters more here than elsewhere, because **the engine's own
/// reported position is not safe to read at the moments progress most needs
/// saving**.
///
/// On libVLC, `setSource`, `stop()` and end-of-media each push a snapshot with
/// `position = 0`. Worse, `VlcPlayerValue.fromEvent` merges into the previous
/// value, so in the window between `setMedia()` returning and the first
/// snapshot arriving, `controller.value` still describes the *previous* media —
/// long enough to write the old episode's position under the new episode's key.
/// The old media_kit path had the same shape of bug through `state.useExoPlayer`
/// reading an idle handle and persisting a zero.
///
/// The answer to both is the same and is why [ProgressSample] carries a
/// [ProgressSample.token]: sample only while playback is actually running,
/// stamp the sample with the session it belongs to, and write the last good
/// sample rather than asking the engine at teardown.
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/storage/history_repository.dart';
import '../../library/presentation/history_provider.dart';
import '../../tracking/data/sync_manager.dart';
import '../../tracking/domain/sync_progress_item.dart';
import 'stream_resolver.dart' show ProviderReader;

/// Shorter than this and there is nothing worth resuming — and a value this
/// small usually means the engine has not determined the real duration yet.
const Duration kMinResumableDuration = Duration(seconds: 30);

/// How long a cross-device resume lookup may delay playback starting.
///
/// It runs before the engine is handed the media, so this is dead time the
/// user watches a spinner for. Past it, the local resume point wins.
const Duration _kSyncedResumeBudget = Duration(seconds: 3);

/// Treated as finished. Matches the old controller's `progressPercent >= 90`.
const double kCompletedFraction = 0.90;

/// A position/duration pair known to belong to one specific media session.
@immutable
class ProgressSample {
  const ProgressSample({
    required this.position,
    required this.duration,
    required this.token,
  });

  final Duration position;
  final Duration duration;

  /// The playback session this was measured during. A sample whose token no
  /// longer matches the live session describes different media and must be
  /// discarded rather than written.
  final int token;

  /// Long enough to be real, and actually started.
  bool get isWritable =>
      duration >= kMinResumableDuration && position > Duration.zero;

  /// Position as a fraction of duration, clamped — a stream that overruns its
  /// reported duration should read as finished, not as 103%.
  double get fraction {
    final total = duration.inMilliseconds;
    if (total <= 0) return 0;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  bool get isComplete => fraction >= kCompletedFraction;
}

/// Where a session should start, resolved once before the engine is handed the
/// media so there is no seek to schedule and nothing to race.
@immutable
class ResumePoint {
  const ResumePoint({required this.position, required this.total});

  final Duration position;

  /// The stored duration the position was recorded against, for display.
  final Duration total;
}

/// Reads the stored resume point for [item]/[episode], or null when there is
/// nothing worth resuming.
///
/// All three suppressions are read-side and deliberate. The old path had no
/// explicit near-end guard, which let a finished episode resume at ~90% forever
/// through the legacy `EP_` row.
ResumePoint? resumePointFor({
  required ProviderReader read,
  required MultimediaItem item,
  required Episode? episode,
  required String videoUrl,
}) {
  if (item.contentType == MultimediaContentType.livestream) return null;

  final stored = _storedProgress(
    read: read,
    item: item,
    episode: episode,
    videoUrl: videoUrl,
  );
  if (stored.positionMs <= 0 || stored.durationMs <= 0) return null;
  if (stored.durationMs < kMinResumableDuration.inMilliseconds) return null;

  return _resumeAt(stored.positionMs / stored.durationMs, stored.durationMs);
}

/// The position/duration pair this device has on disk, whatever shape of row
/// holds it. Series progress lives under a per-episode key, films under the
/// title's own.
({int positionMs, int durationMs}) _storedProgress({
  required ProviderReader read,
  required MultimediaItem item,
  required Episode? episode,
  required String videoUrl,
}) {
  final repo = read(historyRepositoryProvider);
  if (!_isSeries(item)) {
    return (
      positionMs: repo.getPosition(item.url),
      durationMs: repo.getDuration(item.url),
    );
  }
  final url = episode?.url ?? videoUrl;
  return (
    positionMs: repo.getEpisodePosition(
      url,
      mainUrl: item.url,
      season: episode?.season,
      episode: episode?.episode,
    ),
    durationMs: repo.getEpisodeDuration(
      url,
      mainUrl: item.url,
      season: episode?.season,
      episode: episode?.episode,
    ),
  );
}

/// Turns a fraction of [durationMs] into a resume point, applying the two
/// read-side suppressions shared by the local and the cross-device paths.
ResumePoint? _resumeAt(double fraction, int durationMs) {
  // Near the start there is nothing to restore; near the end the user has
  // finished and wants the next thing, not the last 30 seconds again.
  if (fraction < 0.01 || fraction >= kCompletedFraction) return null;
  return ResumePoint(
    position: Duration(milliseconds: (durationMs * fraction).round()),
    total: Duration(milliseconds: durationMs),
  );
}

/// How much remote progress is worth acting on.
///
/// Five seconds of a two-hour film on another device is an accidental tap, not
/// a place to resume from. Local writes are more frequent than this; a brief
/// play still should not pull resume to that device.
const double _kMinSyncedFraction = 0.05;

/// Resolves where to start, preferring whichever device wrote most recently.
///
/// [resumePointFor] only ever sees this device's Hive, so a viewer who paused
/// on the television and picked up their phone starts from scratch — even
/// though the app already pulls remote playback progress. `syncedProgress` had
/// no consumer outside the home dashboard; this is the old controller's
/// local-versus-synced comparison (player_controller.dart:3239-3316) put back.
///
/// Remote progress arrives as a bare percentage, so it is only usable when this
/// device has a stored duration to scale it against. Without one the local
/// answer stands rather than a guess being made.
Future<ResumePoint?> resolveResumePoint({
  required ProviderReader read,
  required MultimediaItem item,
  required Episode? episode,
  required String videoUrl,
}) async {
  final local = resumePointFor(
    read: read,
    item: item,
    episode: episode,
    videoUrl: videoUrl,
  );
  if (item.contentType == MultimediaContentType.livestream) return local;

  final List<SyncProgressItem> synced;
  try {
    // Every linked tracker is pulled sequentially here, and none of those
    // services sets a Dio timeout - so on a flaky connection this sat in front
    // of setMedia indefinitely, showing a spinner instead of the video. A
    // resume point is a convenience; the local one is already in hand.
    synced = await read(syncedProgressProvider.future)
        .timeout(_kSyncedResumeBudget, onTimeout: () => const []);
  } catch (e) {
    // Trackers are optional and the pull is a network call. A tracker being
    // down must not cost the viewer the position this device already knows.
    if (kDebugMode) debugPrint('resolveResumePoint: synced pull failed: $e');
    return local;
  }
  final remote = _syncedMatch(synced, item, episode);
  if (remote == null) return local;

  final fraction = remote.progressPercentage / 100;
  if (fraction < _kMinSyncedFraction) return local;

  final repo = read(historyRepositoryProvider);
  final localWrittenAt = repo
      .getWatchHistory()
      .firstWhereOrNull((h) => _sameRow(h, item, episode))
      ?.timestamp;
  if (localWrittenAt != null &&
      localWrittenAt >= remote.pausedAt.millisecondsSinceEpoch) {
    return local;
  }

  final durationMs = _storedProgress(
    read: read,
    item: item,
    episode: episode,
    videoUrl: videoUrl,
  ).durationMs;
  if (durationMs < kMinResumableDuration.inMilliseconds) return local;

  // Null rather than [local] when the remote says finished: the remote entry is
  // the newer of the two, so resuming this device's stale mid-point would drop
  // the viewer back into something they have already watched elsewhere.
  return _resumeAt(fraction, durationMs);
}

/// The remote entry describing this exact episode, or null.
///
/// Every arm requires the identifier it compares to be present on both sides.
/// The old controller wrote `p.tmdbId == _item.tmdbId?.toString()`, which is
/// true when neither has one — so an untagged local title matched the first
/// untagged remote entry and resumed at a stranger's position.
SyncProgressItem? _syncedMatch(
  List<SyncProgressItem> synced,
  MultimediaItem item,
  Episode? episode,
) {
  final isSeries = _isSeries(item);
  final tmdb = item.tmdbId?.toString();
  final imdb = item.imdbId;
  final title = item.title.toLowerCase();
  return synced.firstWhereOrNull((p) {
    // Trackers have no separate anime type; an anime item is a series to them.
    final wantType = isSeries
        ? MultimediaContentType.series
        : MultimediaContentType.movie;
    if (p.type != wantType) return false;
    if (isSeries &&
        (p.season != episode?.season || p.episode != episode?.episode)) {
      return false;
    }
    if (tmdb != null && p.tmdbId != null) return p.tmdbId == tmdb;
    if (imdb != null && p.imdbId != null) return p.imdbId == imdb;
    return p.title.toLowerCase() == title;
  });
}

/// Whether a history row is the one this session is writing to.
bool _sameRow(HistoryItem row, MultimediaItem item, Episode? episode) {
  if (row.item.url != item.url) return false;
  if (!_isSeries(item)) return true;
  return row.season == episode?.season && row.episode == episode?.episode;
}

bool _isSeries(MultimediaItem item) =>
    item.contentType == MultimediaContentType.series ||
    item.contentType == MultimediaContentType.anime;

/// Points Continue Watching at [next] after the previous episode finished.
///
/// **Deliberately preserves whatever progress [next] already has.** The old
/// path wrote position 0 / duration 0 here, and because `lastEpisodeUrl` is
/// non-null for a series, storage mirrors that same map into a second row keyed
/// by the next episode. Hive `put` is a full replace, so a viewer who had
/// already watched twenty minutes of the next episode lost it by finishing the
/// previous one.
///
/// Reading the stored values back and rewriting them keeps the card pointing at
/// the right episode without touching its position.
void rollForwardHistory({
  required ProviderReader read,
  required MultimediaItem item,
  required Episode next,
}) {
  final repo = read(historyRepositoryProvider);
  final positionMs = repo.getEpisodePosition(
    next.url,
    mainUrl: item.url,
    season: next.season,
    episode: next.episode,
  );
  final durationMs = repo.getEpisodeDuration(
    next.url,
    mainUrl: item.url,
    season: next.season,
    episode: next.episode,
  );

  read(watchHistoryProvider.notifier).saveProgress(
    item.copyWith(provider: item.provider ?? 'Unknown'),
    positionMs > 0 ? positionMs : 0,
    durationMs > 0 ? durationMs : 0,
    // The next episode's source is unknown until it resolves; leaving this null
    // makes the resolver pick fresh rather than reuse the finished episode's.
    lastStreamUrl: null,
    lastEpisodeUrl: next.url,
    season: next.season,
    episode: next.episode,
    episodeTitle: next.name,
    episodePosterUrl: next.posterUrl,
  );
}

/// Drops a finished title from Continue Watching.
///
/// Only safe when the caller *knows* the series ended — see
/// [NextEpisodeLookup.isFinalEpisode]. The underlying delete cascades across
/// every per-episode row for this title, so calling it because the current
/// episode merely could not be located erases the whole series' progress.
void clearFinishedFromHistory({
  required ProviderReader read,
  required MultimediaItem item,
}) {
  read(watchHistoryProvider.notifier).removeFromHistory(item.url);
}

/// Writes progress for one playback session.
///
/// Owns the write-rate limiting and every correctness guard, so callers only
/// have to supply honest samples.
class PlaybackProgressRecorder {
  PlaybackProgressRecorder({
    required this.read,
    required this.item,
    required this.episode,
    required this.videoUrl,
    required this.token,
  });

  final ProviderReader read;
  final MultimediaItem item;
  final Episode? episode;
  final String videoUrl;

  /// Session identity. Samples stamped with anything else are rejected.
  final int token;

  /// Only write again once the position has moved this much of the whole, so a
  /// per-tick listener does not hammer storage.
  static const double _writeThresholdFraction = 0.05;

  /// A long title's 5% is several minutes. Continue Watching and profile sync
  /// also write once the playhead has moved this far, whichever comes first.
  static const Duration _writeThresholdCap = Duration(seconds: 15);

  Duration _lastWritten = Duration.zero;

  bool get isSeries =>
      item.contentType == MultimediaContentType.series ||
      item.contentType == MultimediaContentType.anime;

  /// True once this session has been recorded as finished, so the caller can
  /// avoid re-running completion side effects. Set before any write is
  /// dispatched, never after.
  bool get isCompleted => _completed;
  bool _completed = false;

  /// Records [sample] if it is worth recording.
  ///
  /// [force] skips the rate limit — use it at pause, teardown and episode
  /// change, where this is the last chance to write.
  ///
  /// Returns true when a write was dispatched.
  bool record(
    ProgressSample sample, {
    String? lastStreamUrl,
    bool force = false,
  }) {
    if (sample.token != token) return false;
    if (item.contentType == MultimediaContentType.livestream) return false;
    if (!sample.isWritable) return false;

    // A live sample from behind the completion line is the viewer rewinding —
    // position only goes backwards on a seek — so the episode is being watched
    // again and its row is worth writing again.
    //
    // Only an unforced sample may reopen the latch, and that is the whole
    // distinction. force() is the teardown/pause flush of whatever [_sample]
    // the screen last held, which after completion still describes the finished
    // episode; letting that reopen the latch is exactly the bug the latch
    // exists for. A real rewind always announces itself on the live path first.
    if (_completed && !force && !sample.isComplete) _completed = false;

    // Once this episode is finished, Continue Watching has been rolled forward
    // to the next one. A later write - and dispose() always forces one - would
    // point the row back at the episode just completed.
    if (_completed) return false;

    if (!force) {
      final moved = (sample.position - _lastWritten).abs();
      final byFraction =
          sample.duration.inMilliseconds * _writeThresholdFraction;
      final cap = _writeThresholdCap.inMilliseconds.toDouble();
      final threshold = byFraction < cap ? byFraction : cap;
      if (moved.inMilliseconds < threshold) return false;
    }

    // A stream can report a position past its own duration; store the honest
    // ceiling rather than dropping the write.
    final position = sample.position > sample.duration
        ? sample.duration
        : sample.position;

    _lastWritten = position;
    if (sample.isComplete) _completed = true;

    final provider = item.provider ?? 'Unknown';
    final toSave = item.copyWith(provider: provider);

    read(watchHistoryProvider.notifier).saveProgress(
      toSave,
      position.inMilliseconds,
      sample.duration.inMilliseconds,
      lastStreamUrl: lastStreamUrl,
      // Series rows are keyed by episode as well as title; without this the
      // per-episode row is never written and resume falls back to the title.
      lastEpisodeUrl: isSeries ? (episode?.url ?? videoUrl) : null,
      season: episode?.season,
      episode: episode?.episode,
      episodeTitle: episode?.name,
      episodePosterUrl: episode?.posterUrl,
    );
    return true;
  }

  /// Records that a livestream was watched, without a position.
  void recordLivestream() {
    if (item.contentType != MultimediaContentType.livestream) return;
    final provider = item.provider ?? 'Unknown';
    read(watchHistoryProvider.notifier).saveProgress(
      item.copyWith(provider: provider),
      0,
      0,
      lastStreamUrl: null,
      lastEpisodeUrl: null,
    );
  }
}
