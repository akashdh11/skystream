import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_player/vlc_player.dart';

void main() {
  group('VlcMediaStats', () {
    test('parses native stats payloads', () {
      final stats = VlcMediaStats.fromMap(<Object?, Object?>{
        'available': true,
        'readBytes': 1024.9,
        'inputBitrate': 1.25,
        'demuxReadBytes': 2048,
        'demuxBitrate': 2,
        'demuxCorrupted': 3,
        'demuxDiscontinuity': 4,
        'decodedVideo': 5,
        'decodedAudio': 6,
        'displayedPictures': 7,
        'lostPictures': 8,
        'playedAudioBuffers': 9,
        'lostAudioBuffers': 10,
        'sentPackets': 11,
        'sentBytes': 12,
        'sendBitrate': 3.5,
      });

      expect(stats.isAvailable, isTrue);
      expect(stats.readBytes, 1024);
      expect(stats.inputBitrate, 1.25);
      expect(stats.demuxReadBytes, 2048);
      expect(stats.demuxBitrate, 2.0);
      expect(stats.demuxCorrupted, 3);
      expect(stats.demuxDiscontinuity, 4);
      expect(stats.decodedVideo, 5);
      expect(stats.decodedAudio, 6);
      expect(stats.displayedPictures, 7);
      expect(stats.lostPictures, 8);
      expect(stats.playedAudioBuffers, 9);
      expect(stats.lostAudioBuffers, 10);
      expect(stats.sentPackets, 11);
      expect(stats.sentBytes, 12);
      expect(stats.sendBitrate, 3.5);
    });

    test('ignores malformed fields without throwing', () {
      final stats = VlcMediaStats.fromMap(<Object?, Object?>{
        'available': 'yes',
        'readBytes': double.nan,
        'inputBitrate': Object(),
        'demuxReadBytes': double.infinity,
        'demuxBitrate': <String>[],
      });

      expect(stats, const VlcMediaStats());
    });

    test('compares stats by value', () {
      const first = VlcMediaStats(
        isAvailable: true,
        readBytes: 10,
        inputBitrate: 1.5,
      );
      const second = VlcMediaStats(
        isAvailable: true,
        readBytes: 10,
        inputBitrate: 1.5,
      );
      const changed = VlcMediaStats(isAvailable: true, readBytes: 11);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(changed));
    });
  });
}
