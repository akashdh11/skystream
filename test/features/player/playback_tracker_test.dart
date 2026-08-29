import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart'
    show ProviderListenable;
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/features/player/domain/playback_progress.dart';
import 'package:skystream/features/player/domain/playback_tracker.dart';
import 'package:skystream/features/tracking/data/sync_manager.dart';

/// Records dispatches instead of writing to anyone's account.
class _RecordingSync extends SyncManager {
  _RecordingSync() : super(const []);

  final List<String> calls = <String>[];

  @override
  Future<void> markWatched(MultimediaItem item, Episode? episode) async {
    calls.add('markWatched');
  }

  @override
  Future<void> scrobbleStart(
    MultimediaItem item,
    Episode? episode,
    double progress,
  ) async {
    calls.add('scrobbleStart');
  }

  @override
  Future<void> scrobblePause(
    MultimediaItem item,
    Episode? episode,
    double progress,
  ) async {
    calls.add('scrobblePause');
  }

  @override
  Future<void> scrobbleStop(
    MultimediaItem item,
    Episode? episode,
    double progress,
  ) async {
    calls.add('scrobbleStop');
  }
}

void main() {
  late _RecordingSync sync;

  // A series with no resolved episode touches only the sync provider on
  // completion, which keeps these tests free of storage fakes.
  final item = MultimediaItem(
    title: 'Show',
    url: 'https://example.com/show',
    posterUrl: '',
    contentType: MultimediaContentType.series,
  );

  T read<T>(ProviderListenable<T> provider) {
    if (identical(provider, syncManagerProvider)) return sync as T;
    throw StateError('tracker read an unexpected provider: $provider');
  }

  PlaybackTracker tracker() => PlaybackTracker(
    read: read,
    item: item,
    episode: null,
    token: 3,
  );

  ProgressSample at(int posMs, {int durMs = 3600000, int token = 3}) =>
      ProgressSample(
        position: Duration(milliseconds: posMs),
        duration: Duration(milliseconds: durMs),
        token: token,
      );

  setUp(() => sync = _RecordingSync());

  group('scrobble start', () {
    test('fires once, not once per sample', () {
      tracker()
        ..onPlaying(at(1000))
        ..onPlaying(at(2000))
        ..onPlaying(at(3000));
      expect(sync.calls, <String>['scrobbleStart']);
    });

    test('ignores samples from a superseded session', () {
      tracker().onPlaying(at(1000, token: 2));
      expect(sync.calls, isEmpty);
    });

    test('ignores a zero position from a stopped engine', () {
      tracker().onPlaying(at(0));
      expect(sync.calls, isEmpty);
    });
  });

  group('completion', () {
    test('will not mark watched on an unsettled duration', () {
      // A single sample past 90% proves nothing: VLC revises duration during
      // startup, so this ratio may be against a provisional value.
      tracker().onPlaying(at(3500000));
      expect(sync.calls, <String>['scrobbleStart']);
    });

    test('marks watched once the duration has settled', () {
      final t = tracker()
        ..onPlaying(at(1000))
        ..onPlaying(at(2000)) // duration now seen twice: settled
        ..onPlaying(at(3400000));
      expect(sync.calls, <String>['scrobbleStart', 'markWatched']);
      expect(t.markedWatched, isTrue);
    });

    test('marks watched exactly once however many samples cross the line', () {
      tracker()
        ..onPlaying(at(1000))
        ..onPlaying(at(2000))
        ..onPlaying(at(3400000))
        ..onPlaying(at(3500000))
        ..onPlaying(at(3590000));
      expect(sync.calls.where((c) => c == 'markWatched'), hasLength(1));
    });

    test('a revised duration restarts settling rather than marking', () {
      tracker()
        ..onPlaying(at(1000, durMs: 100000))
        ..onPlaying(at(95000, durMs: 3600000));
      expect(sync.calls, <String>['scrobbleStart']);
    });
  });

  group('terminal event', () {
    // The old path emits scrobbleStop at dispose and can then also emit
    // markWatched from saveProgress - two terminal events for one episode.
    test('markWatched suppresses the stop', () {
      final t = tracker()
        ..onPlaying(at(1000))
        ..onPlaying(at(2000))
        ..onPlaying(at(3400000));
      t.finish();
      expect(sync.calls, <String>['scrobbleStart', 'markWatched']);
    });

    test('an unfinished session stops instead', () {
      final t = tracker()
        ..onPlaying(at(1000))
        ..onPlaying(at(600000));
      t.finish();
      expect(sync.calls, <String>['scrobbleStart', 'scrobbleStop']);
    });

    test('finishing twice still emits one event', () {
      final t = tracker()
        ..onPlaying(at(1000))
        ..onPlaying(at(600000));
      t.finish();
      t.finish();
      expect(sync.calls.where((c) => c == 'scrobbleStop'), hasLength(1));
    });

    test('a session that never played emits nothing', () {
      tracker().finish();
      expect(sync.calls, isEmpty);
    });

    test('samples after finish are ignored', () {
      final t = tracker()..onPlaying(at(1000));
      t.finish();
      t.onPlaying(at(3500000));
      expect(sync.calls, <String>['scrobbleStart', 'scrobbleStop']);
    });
  });

  group('pause and resume', () {
    test('pause reports once, resume restarts', () {
      final t = tracker()..onPlaying(at(1000));
      t.onPaused();
      t.onPaused();
      t.onPlaying(at(2000));
      expect(sync.calls, <String>[
        'scrobbleStart',
        'scrobblePause',
        'scrobbleStart',
      ]);
    });

    test('a watched session stops scrobbling pauses', () {
      final t = tracker()
        ..onPlaying(at(1000))
        ..onPlaying(at(2000))
        ..onPlaying(at(3400000));
      t.onPaused();
      expect(sync.calls, <String>['scrobbleStart', 'markWatched']);
    });

    test('pause before anything played reports nothing', () {
      tracker().onPaused();
      expect(sync.calls, isEmpty);
    });
  });
}
