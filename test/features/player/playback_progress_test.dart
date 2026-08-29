import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/features/player/domain/playback_progress.dart';
import 'package:skystream/features/player/domain/stream_resolver.dart';

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

    test('never writes progress for a livestream', () {
      final recorder = recorderFor(MultimediaContentType.livestream);
      expect(recorder.record(sample(600000, 3600000)), isFalse);
    });

    test('is not complete until a write actually happens', () {
      final recorder = recorderFor(MultimediaContentType.movie);
      recorder.record(sample(3500000, 3600000, token: 6));
      expect(recorder.isCompleted, isFalse);
    });
  });
}
