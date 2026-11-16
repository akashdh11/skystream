// Test doubles expose what they recorded.
// ignore_for_file: riverpod_lint/avoid_public_notifier_properties

import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/features/library/presentation/history_provider.dart';
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/features/player/domain/playback_progress.dart';
import 'package:skystream/core/storage/history_repository.dart';
import 'package:skystream/features/player/domain/stream_resolver.dart';
import 'package:skystream/features/tracking/domain/sync_progress_item.dart';

void main() {
  ProgressSample sample(int posMs, int durMs, {int token = 1}) => ProgressSample(
    position: Duration(milliseconds: posMs),
    duration: Duration(milliseconds: durMs),
    token: token,
  );

  group('ProgressSample', () {
    test('a stopped or freshly-swapped engine reports zero and is unwritable', () {
      // libVLC pushes position 0 on setSource, stop() and end-of-media. This
      // is the guard that stops a real position being overwritten with it.
      expect(sample(0, 3600000).isWritable, isFalse);
    });

    test('a duration too short to be real is unwritable', () {
      expect(sample(5000, 12000).isWritable, isFalse);
      expect(sample(5000, 30000).isWritable, isTrue);
    });

    test('fraction clamps a position that overruns its duration', () {
      expect(sample(4000000, 3600000).fraction, 1.0);
      expect(sample(1800000, 3600000).fraction, 0.5);
    });

    test('completion is 90 percent', () {
      expect(sample(3239000, 3600000).isComplete, isFalse);
      expect(sample(3240000, 3600000).isComplete, isTrue);
    });

    test('a zero duration never divides', () {
      expect(sample(1000, 0).fraction, 0);
      expect(sample(1000, 0).isComplete, isFalse);
    });
  });

  group('PlaybackProgressRecorder guards', () {
    // Every rejection below must short-circuit before Riverpod is touched, so
    // a reader that throws proves no write was attempted.
    T neverRead<T>(_) =>
        throw StateError('recorder attempted a write it should have refused');

    PlaybackProgressRecorder recorderFor(
      MultimediaContentType type, {
      ProviderReader? read,
    }) {
      return PlaybackProgressRecorder(
        read: read ?? neverRead,
        item: MultimediaItem(
          title: 'T',
          url: 'https://example.com/t',
          posterUrl: '',
          contentType: type,
        ),
        episode: null,
        videoUrl: 'https://example.com/t',
        token: 7,
      );
    }

    test('rejects a sample stamped with a different session', () {
      final recorder = recorderFor(MultimediaContentType.movie);
      // The exact hazard: after setMedia, the value still describes the
      // previous media. Writing it would file the old position under the new
      // episode key.
      expect(recorder.record(sample(600000, 3600000, token: 6)), isFalse);
    });

    test('rejects a zero position from a stopped engine', () {
      final recorder = recorderFor(MultimediaContentType.movie);
      expect(recorder.record(sample(0, 3600000)), isFalse);
    });

    test('rejects a duration too short to be real', () {
      final recorder = recorderFor(MultimediaContentType.movie);
      expect(recorder.record(sample(5000, 10000)), isFalse);
    });

    test('a long video is saved every 15 seconds, not every 5 percent', () {
      final stub = _StubHistory();
      final recorder = PlaybackProgressRecorder(
        read: <T>(_) => stub as T,
        item: MultimediaItem(
          title: 'T',
          url: 'https://example.com/t',
          posterUrl: '',
          contentType: MultimediaContentType.movie,
        ),
        episode: null,
        videoUrl: 'https://example.com/t',
        token: 1,
      );

      // 5% of an hour is 3 minutes. Fourteen seconds must not write.
      expect(recorder.record(sample(14000, 3600000)), isFalse);
      expect(stub.writes, 0);

      expect(recorder.record(sample(15000, 3600000)), isTrue);
      expect(stub.lastPosition, 15000);

      expect(recorder.record(sample(29999, 3600000)), isFalse);
      expect(recorder.record(sample(30000, 3600000)), isTrue);
      expect(stub.writes, 2);
    });

    test('a short video still waits for 5 percent', () {
      final stub = _StubHistory();
      final recorder = PlaybackProgressRecorder(
        read: <T>(_) => stub as T,
        item: MultimediaItem(
          title: 'T',
          url: 'https://example.com/t',
          posterUrl: '',
          contentType: MultimediaContentType.movie,
        ),
        episode: null,
        videoUrl: 'https://example.com/t',
        token: 1,
      );

      // 5% of 40 seconds is 2 seconds, under the 15-second cap.
      expect(recorder.record(sample(1999, 40000)), isFalse);
      expect(stub.writes, 0);
      expect(recorder.record(sample(2000, 40000)), isTrue);
      expect(stub.lastPosition, 2000);
    });

    test('never writes progress for a livestream', () {
      final recorder = recorderFor(MultimediaContentType.livestream);
      expect(recorder.record(sample(600000, 3600000)), isFalse);
    });

    test('stops writing once completion latches, so the rollover survives', () {
      // dispose() always forces a final write. Without this guard that write
      // would point Continue Watching back at the episode just finished,
      // undoing the roll-forward to the next one.
      final stub = _StubHistory();
      final recorder = PlaybackProgressRecorder(
        // The recorder reads exactly one provider; the cast fails loudly if
        // it ever reaches for something else.
        read: <T>(_) => stub as T,
        item: MultimediaItem(
          title: 'T',
          url: 'https://example.com/t',
          posterUrl: '',
          contentType: MultimediaContentType.movie,
        ),
        episode: null,
        videoUrl: 'https://example.com/t',
        token: 1, // matches the sample() helper's default
      );

      // Cross 90%: this write happens and latches completion.
      expect(recorder.record(sample(3400000, 3600000)), isTrue);
      expect(recorder.isCompleted, isTrue);
      expect(stub.writes, 1);

      // Everything after is refused, including the forced teardown flush.
      expect(recorder.record(sample(3500000, 3600000), force: true), isFalse);
      expect(recorder.record(sample(3000000, 3600000), force: true), isFalse);
      expect(stub.writes, 1);
    });

    test('is not complete until a write actually happens', () {
      final recorder = recorderFor(MultimediaContentType.movie);
      recorder.record(sample(3500000, 3600000, token: 6));
      expect(recorder.isCompleted, isFalse);
    });

    test('a rewind back below the line reopens the latch', () {
      // The latch stops a finished episode's row being written back over the
      // roll-forward. It must not also mean "this session never writes again":
      // a viewer who rewinds to the middle is watching it, and backing out
      // then should leave Continue Watching where they actually are.
      final stub = _StubHistory();
      final recorder = PlaybackProgressRecorder(
        read: <T>(_) => stub as T,
        item: MultimediaItem(
          title: 'T',
          url: 'https://example.com/t',
          posterUrl: '',
          contentType: MultimediaContentType.movie,
        ),
        episode: null,
        videoUrl: 'https://example.com/t',
        token: 1,
      );

      expect(recorder.record(sample(3400000, 3600000)), isTrue);
      expect(recorder.isCompleted, isTrue);

      // A live sample from before the line: position only moves backwards on
      // a seek, so this is the viewer rewinding.
      expect(recorder.record(sample(1800000, 3600000)), isTrue);
      expect(recorder.isCompleted, isFalse);
      expect(stub.lastPosition, 1800000);

      // And the teardown flush now lands, which is the point.
      expect(recorder.record(sample(1810000, 3600000), force: true), isTrue);
      expect(stub.lastPosition, 1810000);
    });

    test('a forced flush cannot reopen the latch on its own', () {
      // dispose() forces a write of whatever sample the screen last held, and
      // after an episode ends that sample can be anything. Only the live path
      // is allowed to un-finish an episode.
      final stub = _StubHistory();
      final recorder = PlaybackProgressRecorder(
        read: <T>(_) => stub as T,
        item: MultimediaItem(
          title: 'T',
          url: 'https://example.com/t',
          posterUrl: '',
          contentType: MultimediaContentType.movie,
        ),
        episode: null,
        videoUrl: 'https://example.com/t',
        token: 1,
      );

      expect(recorder.record(sample(3400000, 3600000)), isTrue);
      expect(recorder.record(sample(1800000, 3600000), force: true), isFalse);
      expect(recorder.isCompleted, isTrue);
      expect(stub.writes, 1);
    });
  });

  group('resolveResumePoint', () {
    final movie = MultimediaItem(
      title: 'Film',
      url: 'https://example.com/film',
      posterUrl: '',
      contentType: MultimediaContentType.movie,
      tmdbId: 42,
    );

    ProviderReader readerOf(_StubRepo repo, List<SyncProgressItem> synced) =>
        <T>(_) {
          if (repo is T) return repo as T;
          return Future<List<SyncProgressItem>>.value(synced) as T;
        };

    SyncProgressItem remote({
      required double percent,
      required DateTime pausedAt,
      String? tmdbId = '42',
      MultimediaContentType type = MultimediaContentType.movie,
      int? season,
      int? episode,
    }) => SyncProgressItem(
      title: 'Film',
      progressPercentage: percent,
      pausedAt: pausedAt,
      type: type,
      tmdbId: tmdbId,
      season: season,
      episode: episode,
    );

    test('prefers a newer remote position over the local one', () async {
      final repo = _StubRepo(
        positionMs: 600000, // 10 minutes here
        durationMs: 7200000,
        timestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
      );
      final resolved = await resolveResumePoint(
        read: readerOf(repo, [
          remote(percent: 50, pausedAt: DateTime(2026, 1, 2)),
        ]),
        item: movie,
        episode: null,
        videoUrl: movie.url,
      );
      expect(resolved?.position, const Duration(minutes: 60));
    });

    test('keeps the local position when this device wrote last', () async {
      final repo = _StubRepo(
        positionMs: 600000,
        durationMs: 7200000,
        timestamp: DateTime(2026, 1, 3).millisecondsSinceEpoch,
      );
      final resolved = await resolveResumePoint(
        read: readerOf(repo, [
          remote(percent: 50, pausedAt: DateTime(2026, 1, 2)),
        ]),
        item: movie,
        episode: null,
        videoUrl: movie.url,
      );
      expect(resolved?.position, const Duration(minutes: 10));
    });

    test('ignores a remote entry for a different title', () async {
      // Both sides carry a tmdbId, so the title fallback must never be reached.
      final repo = _StubRepo(
        positionMs: 600000,
        durationMs: 7200000,
        timestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
      );
      final resolved = await resolveResumePoint(
        read: readerOf(repo, [
          remote(
            percent: 50,
            pausedAt: DateTime(2026, 1, 2),
            tmdbId: '999',
          ),
        ]),
        item: movie,
        episode: null,
        videoUrl: movie.url,
      );
      expect(resolved?.position, const Duration(minutes: 10));
    });

    test('ignores a trivial remote position', () async {
      final repo = _StubRepo(
        positionMs: 600000,
        durationMs: 7200000,
        timestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
      );
      final resolved = await resolveResumePoint(
        read: readerOf(repo, [
          remote(percent: 2, pausedAt: DateTime(2026, 1, 2)),
        ]),
        item: movie,
        episode: null,
        videoUrl: movie.url,
      );
      expect(resolved?.position, const Duration(minutes: 10));
    });

    test('a newer remote that finished leaves nothing to resume', () async {
      final repo = _StubRepo(
        positionMs: 600000,
        durationMs: 7200000,
        timestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
      );
      final resolved = await resolveResumePoint(
        read: readerOf(repo, [
          remote(percent: 97, pausedAt: DateTime(2026, 1, 2)),
        ]),
        item: movie,
        episode: null,
        videoUrl: movie.url,
      );
      expect(resolved, isNull);
    });

    test('falls back to local when the tracker pull throws', () async {
      final repo = _StubRepo(
        positionMs: 600000,
        durationMs: 7200000,
        timestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
      );
      final resolved = await resolveResumePoint(
        read: <T>(_) {
          if (repo is T) return repo as T;
          return Future<List<SyncProgressItem>>.error(
                StateError('tracker down'),
              )
              as T;
        },
        item: movie,
        episode: null,
        videoUrl: movie.url,
      );
      expect(resolved?.position, const Duration(minutes: 10));
    });

    test('never consults trackers for a livestream', () async {
      final repo = _StubRepo(positionMs: 0, durationMs: 0, timestamp: 0);
      final resolved = await resolveResumePoint(
        read: <T>(_) {
          if (repo is T) return repo as T;
          throw StateError('a livestream asked a tracker for a position');
        },
        item: MultimediaItem(
          title: 'Channel',
          url: 'https://example.com/live',
          posterUrl: '',
          contentType: MultimediaContentType.livestream,
        ),
        episode: null,
        videoUrl: 'https://example.com/live',
      );
      expect(resolved, isNull);
    });
  });

  group('recordLivestream', () {
    PlaybackProgressRecorder recorderFor(
      MultimediaContentType type,
      ProviderReader read, {
      String? provider,
    }) {
      return PlaybackProgressRecorder(
        read: read,
        item: MultimediaItem(
          title: 'Channel',
          url: 'https://example.com/live.m3u8',
          posterUrl: '',
          contentType: type,
          provider: provider,
        ),
        episode: null,
        videoUrl: 'https://example.com/live.m3u8',
        token: 1,
      );
    }

    test('writes the channel to history with no position', () {
      // Continue Watching deletes a live entry the moment it is tapped and
      // relies on playback putting it back. record() cannot do it - a
      // livestream has no position - so this is the only path that can.
      final stub = _StubHistory();
      recorderFor(
        MultimediaContentType.livestream,
        <T>(_) => stub as T,
      ).recordLivestream();

      expect(stub.writes, 1);
      expect(stub.lastPosition, 0);
      expect(stub.lastDuration, 0);
    });

    test('substitutes a provider so the row is never filed under null', () {
      final stub = _StubHistory();
      recorderFor(
        MultimediaContentType.livestream,
        <T>(_) => stub as T,
      ).recordLivestream();

      expect(stub.lastItem?.provider, 'Unknown');
    });

    test('refuses anything that is not a livestream', () {
      // A reader that throws proves no write was attempted.
      T neverRead<T>(_) =>
          throw StateError('recordLivestream wrote for a non-livestream');
      expect(
        () => recorderFor(
          MultimediaContentType.movie,
          neverRead,
        ).recordLivestream(),
        returnsNormally,
      );
    });
  });
}

/// Counts writes without touching Hive. Only saveProgress is ever called.
class _StubHistory implements WatchHistory {
  int writes = 0;
  MultimediaItem? lastItem;
  int? lastPosition;
  int? lastDuration;

  @override
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
    writes++;
    lastItem = item;
    lastPosition = position;
    lastDuration = duration;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('not needed: ${invocation.memberName}');
}

/// One stored row, answering every lookup shape with the same numbers.
class _StubRepo implements HistoryRepository {
  _StubRepo({
    required this.positionMs,
    required this.durationMs,
    required this.timestamp,
  });

  final int positionMs;
  final int durationMs;
  final int timestamp;

  @override
  int getPosition(String url) => positionMs;

  @override
  int getDuration(String url) => durationMs;

  @override
  int getEpisodePosition(
    String url, {
    String? mainUrl,
    int? season,
    int? episode,
  }) => positionMs;

  @override
  int getEpisodeDuration(
    String url, {
    String? mainUrl,
    int? season,
    int? episode,
  }) => durationMs;

  @override
  List<HistoryItem> getWatchHistory() => [
    HistoryItem(
      item: MultimediaItem(
        title: 'Film',
        url: 'https://example.com/film',
        posterUrl: '',
      ),
      position: positionMs,
      duration: durationMs,
      timestamp: timestamp,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('not needed: ${invocation.memberName}');
}
