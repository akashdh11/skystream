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

import 'package:flutter/foundation.dart';

import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/storage/history_repository.dart';
import '../../library/presentation/history_provider.dart';
import 'stream_resolver.dart' show ProviderReader;


/// Shorter than this and there is nothing worth resuming — and a value this
/// small usually means the engine has not determined the real duration yet.
const Duration kMinResumableDuration = Duration(seconds: 30);

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

  final repo = read(historyRepositoryProvider);
  final isSeries =
      item.contentType == MultimediaContentType.series ||
      item.contentType == MultimediaContentType.anime;

  final int positionMs;
  final int durationMs;
  if (isSeries) {
    final url = episode?.url ?? videoUrl;
    positionMs = repo.getEpisodePosition(
      url,
      mainUrl: item.url,
      season: episode?.season,
      episode: episode?.episode,
    );
    durationMs = repo.getEpisodeDuration(
      url,
      mainUrl: item.url,
      season: episode?.season,
      episode: episode?.episode,
    );
  } else {
    positionMs = repo.getPosition(item.url);
    durationMs = repo.getDuration(item.url);
  }

  if (positionMs <= 0 || durationMs <= 0) return null;
  if (durationMs < kMinResumableDuration.inMilliseconds) return null;

  final fraction = positionMs / durationMs;
  // Near the start there is nothing to restore; near the end the user has
  // finished and wants the next thing, not the last 30 seconds again.
  if (fraction < 0.01 || fraction >= kCompletedFraction) return null;

  return ResumePoint(
    position: Duration(milliseconds: positionMs),
    total: Duration(milliseconds: durationMs),
  );
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
  /// per-tick listener does not hammer storage. Matches the old controller.
  static const double _writeThresholdFraction = 0.05;

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
  bool record(ProgressSample sample, {String? lastStreamUrl, bool force = false}) {
    if (sample.token != token) return false;
    if (item.contentType == MultimediaContentType.livestream) return false;
    if (!sample.isWritable) return false;

    if (!force) {
      final moved = (sample.position - _lastWritten).abs();
      final threshold =
          sample.duration.inMilliseconds * _writeThresholdFraction;
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
