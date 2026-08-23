import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_player/vlc_player.dart';

void main() {
  group('VlcPlayerError', () {
    test('parses map payloads', () {
      final error = VlcPlayerError.fromMap(<Object?, Object?>{
        'code': 'track_not_found',
        'message': 'Missing track',
        'details': <String, Object?>{'id': 3},
      });

      expect(error.code, VlcPlayerErrorCode.trackNotFound);
      expect(error.message, 'Missing track');
      expect(error.details, <String, Object?>{'id': 3});
      expect(error.description, 'Missing track');
    });

    test('ignores malformed map code and message fields', () {
      final error = VlcPlayerError.fromMap(<Object?, Object?>{
        'code': 7,
        'message': Object(),
        'details': <String, Object?>{'raw': true},
      });

      expect(error.code, VlcPlayerErrorCode.playbackError);
      expect(error.message, isNull);
      expect(error.details, <String, Object?>{'raw': true});
      expect(error.description, VlcPlayerErrorCode.playbackError);
    });

    test('parses platform exceptions', () {
      final error = VlcPlayerError.fromPlatformException(
        PlatformException(
          code: VlcPlayerErrorCode.playerNotFound,
          message: 'No player',
          details: 7,
        ),
      );

      expect(error.code, VlcPlayerErrorCode.playerNotFound);
      expect(error.message, 'No player');
      expect(error.details, 7);
    });

    test('compares structured details by value', () {
      const first = VlcPlayerError(
        code: VlcPlayerErrorCode.playbackError,
        message: 'Playback failed',
        details: <String, Object?>{
          'viewId': 3,
          'source': <String>['one.mp4', 'two.mp4'],
          'native': <String, Object?>{'code': -1},
        },
      );
      const second = VlcPlayerError(
        code: VlcPlayerErrorCode.playbackError,
        message: 'Playback failed',
        details: <String, Object?>{
          'native': <String, Object?>{'code': -1},
          'source': <String>['one.mp4', 'two.mp4'],
          'viewId': 3,
        },
      );
      const changed = VlcPlayerError(
        code: VlcPlayerErrorCode.playbackError,
        message: 'Playback failed',
        details: <String, Object?>{
          'viewId': 3,
          'source': <String>['one.mp4'],
          'native': <String, Object?>{'code': -1},
        },
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(changed));
    });

    test('compares list details deeply', () {
      const first = VlcPlayerError(
        code: VlcPlayerErrorCode.playbackError,
        details: <Object?>[
          'playlist',
          <String, Object?>{'index': 1},
        ],
      );
      const second = VlcPlayerError(
        code: VlcPlayerErrorCode.playbackError,
        details: <Object?>[
          'playlist',
          <String, Object?>{'index': 1},
        ],
      );
      const changed = VlcPlayerError(
        code: VlcPlayerErrorCode.playbackError,
        details: <Object?>[
          'playlist',
          <String, Object?>{'index': 2},
        ],
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(changed));
    });

    test('formats debug descriptions with and without messages', () {
      const bare = VlcPlayerError(code: VlcPlayerErrorCode.disposed);
      const empty = VlcPlayerError(
        code: VlcPlayerErrorCode.disposed,
        message: '',
      );
      const described = VlcPlayerError(
        code: VlcPlayerErrorCode.createFailed,
        message: 'Unable to create player',
      );

      expect(bare.toString(), 'VlcPlayerError(disposed)');
      expect(empty.toString(), 'VlcPlayerError(disposed)');
      expect(
        described.toString(),
        'VlcPlayerError(create_failed, Unable to create player)',
      );
    });
  });

  group('VlcPlayerException', () {
    test('exposes code, message, and details', () {
      const exception = VlcPlayerException(
        VlcPlayerError(
          code: VlcPlayerErrorCode.invalidArgs,
          message: 'Invalid argument',
          details: 'speed',
        ),
      );

      expect(exception.code, VlcPlayerErrorCode.invalidArgs);
      expect(exception.message, 'Invalid argument');
      expect(exception.details, 'speed');
      expect(exception.toString(), contains('Invalid argument'));
    });

    test('wraps platform exceptions', () {
      final exception = VlcPlayerException.fromPlatformException(
        PlatformException(
          code: VlcPlayerErrorCode.createFailed,
          message: 'Native create failed',
          details: <String, Object?>{'viewId': 4},
        ),
      );

      expect(exception.code, VlcPlayerErrorCode.createFailed);
      expect(exception.message, 'Native create failed');
      expect(exception.details, <String, Object?>{'viewId': 4});
    });
  });
}
