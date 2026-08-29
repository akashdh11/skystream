import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/features/player/domain/skip_segments.dart';
import 'package:skystream/features/skip/data/skip_service.dart';

void main() {
  SkipSegment seg(double start, double end, [SkipType type = SkipType.intro]) =>
      SkipSegment(startTime: start, endTime: end, type: type);

  group('segmentAt', () {
    final segments = <SkipSegment>[
      seg(30, 90),
      seg(1200, 1260, SkipType.outro),
    ];

    test('finds the segment containing the position', () {
      expect(segmentAt(segments, const Duration(seconds: 45))?.type,
          SkipType.intro);
      expect(segmentAt(segments, const Duration(seconds: 1230))?.type,
          SkipType.outro);
    });

    test('is null between segments', () {
      expect(segmentAt(segments, const Duration(seconds: 600)), isNull);
    });

    // Half-open: start is inside, end is not, so the button disappears exactly
    // when the seek would become a no-op.
    test('includes the start instant and excludes the end instant', () {
      expect(segmentAt(segments, const Duration(seconds: 30)), isNotNull);
      expect(segmentAt(segments, const Duration(seconds: 90)), isNull);
      expect(segmentAt(segments, const Duration(seconds: 89)), isNotNull);
    });

    test('handles sub-second positions', () {
      expect(segmentAt(segments, const Duration(milliseconds: 29999)), isNull);
      expect(segmentAt(segments, const Duration(milliseconds: 30001)), isNotNull);
    });

    test('an empty list never matches', () {
      expect(segmentAt(const <SkipSegment>[], const Duration(seconds: 45)),
          isNull);
    });
  });
}
