import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_player/vlc_player.dart';

void main() {
  group('VlcTrackDescription', () {
    test('parses map payloads', () {
      final track = VlcTrackDescription.fromMap(<Object?, Object?>{
        'id': 2.9,
        'name': 'Stereo',
        'language': 'en',
      });

      expect(track.id, 2);
      expect(track.name, 'Stereo');
      expect(track.language, 'en');
    });

    test('ignores malformed map fields', () {
      final track = VlcTrackDescription.fromMap(<Object?, Object?>{
        'id': double.nan,
        'name': Object(),
        'language': <String>[],
      });

      expect(track.id, -1);
      expect(track.name, isEmpty);
      expect(track.language, isNull);
    });
  });

  group('VlcMediaInfo', () {
    test('parses metadata and track lists', () {
      final info = VlcMediaInfo.fromMap(<Object?, Object?>{
        'title': 'Clip',
        'artist': 'Artist',
        'album': 'Album',
        'duration': 1234.9,
        'videoTracks': <dynamic>[
          <String, Object?>{
            'type': 'video',
            'codec': 'h264',
            'width': 1920.9,
            'height': 1080,
          },
        ],
        'audioTracks': <dynamic>[
          <String, Object?>{
            'type': 'audio',
            'codec': 'mp4a',
            'language': 'en',
            'bitrate': 128000,
            'channels': 2,
            'sampleRate': 44100.9,
          },
        ],
        'subtitleTracks': <dynamic>[
          <String, Object?>{'type': 'subtitle', 'language': 'zh'},
        ],
      });

      expect(info.title, 'Clip');
      expect(info.artist, 'Artist');
      expect(info.album, 'Album');
      expect(info.duration, const Duration(milliseconds: 1234));
      expect(info.videoTracks.single.type, 'video');
      expect(info.videoTracks.single.codec, 'h264');
      expect(info.videoTracks.single.width, 1920);
      expect(info.videoTracks.single.height, 1080);
      expect(info.audioTracks.single.type, 'audio');
      expect(info.audioTracks.single.language, 'en');
      expect(info.audioTracks.single.bitrate, 128000);
      expect(info.audioTracks.single.channels, 2);
      expect(info.audioTracks.single.sampleRate, 44100);
      expect(info.subtitleTracks.single.type, 'subtitle');
      expect(info.subtitleTracks.single.language, 'zh');
    });

    test('ignores malformed metadata and track fields without throwing', () {
      final info = VlcMediaInfo.fromMap(<Object?, Object?>{
        'title': 7,
        'artist': Object(),
        'album': <String>[],
        'duration': double.infinity,
        'videoTracks': <dynamic>[
          'bad track',
          <String, Object?>{
            'type': 5,
            'codec': false,
            'language': Object(),
            'bitrate': 'fast',
            'width': double.nan,
            'height': 720.9,
            'channels': 2.2,
            'sampleRate': Object(),
          },
        ],
        'audioTracks': 'bad list',
        'subtitleTracks': <dynamic>[Object()],
      });

      expect(info.title, isNull);
      expect(info.artist, isNull);
      expect(info.album, isNull);
      expect(info.duration, Duration.zero);
      expect(info.audioTracks, isEmpty);
      expect(info.subtitleTracks, isEmpty);
      expect(info.videoTracks, hasLength(1));

      final video = info.videoTracks.single;
      expect(video.type, 'unknown');
      expect(video.codec, isNull);
      expect(video.language, isNull);
      expect(video.bitrate, isNull);
      expect(video.width, isNull);
      expect(video.height, 720);
      expect(video.channels, 2);
      expect(video.sampleRate, isNull);
    });

    test('compares media info and tracks by value', () {
      const first = VlcMediaInfo(
        title: 'Clip',
        artist: 'Artist',
        album: 'Album',
        duration: Duration(seconds: 12),
        videoTracks: <VlcMediaTrackInfo>[
          VlcMediaTrackInfo(
            type: 'video',
            codec: 'h264',
            width: 1920,
            height: 1080,
          ),
        ],
        audioTracks: <VlcMediaTrackInfo>[
          VlcMediaTrackInfo(
            type: 'audio',
            codec: 'mp4a',
            channels: 2,
            sampleRate: 48000,
          ),
        ],
      );
      const second = VlcMediaInfo(
        title: 'Clip',
        artist: 'Artist',
        album: 'Album',
        duration: Duration(seconds: 12),
        videoTracks: <VlcMediaTrackInfo>[
          VlcMediaTrackInfo(
            type: 'video',
            codec: 'h264',
            width: 1920,
            height: 1080,
          ),
        ],
        audioTracks: <VlcMediaTrackInfo>[
          VlcMediaTrackInfo(
            type: 'audio',
            codec: 'mp4a',
            channels: 2,
            sampleRate: 48000,
          ),
        ],
      );
      const changed = VlcMediaInfo(
        title: 'Clip',
        duration: Duration(seconds: 12),
        videoTracks: <VlcMediaTrackInfo>[
          VlcMediaTrackInfo(
            type: 'video',
            codec: 'h265',
            width: 1920,
            height: 1080,
          ),
        ],
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(changed));
      expect(first.videoTracks.single, second.videoTracks.single);
    });
  });
}
