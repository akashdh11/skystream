import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/features/player/domain/clear_key.dart';

void main() {
  StreamResult s({String? key, String? kid, String? licenseUrl}) => StreamResult(
    url: 'https://example.com/a.mpd',
    source: 'live',
    drmKey: key,
    drmKid: kid,
    licenseUrl: licenseUrl,
  );

  String hex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

  group('clearKeyFor', () {
    const kid = '6752015acf084572a08dfe21796f8b45';
    const key = 'ff823ddbe5625c35d3e93f0ed4520115';

    test('reads separate hex kid and key', () {
      final ck = clearKeyFor(s(kid: kid, key: key))!;
      expect(hex(ck.keyId), kid);
      expect(hex(ck.key), key);
    });

    // Several plugins pack both halves into one field.
    test('splits a combined kid:key value', () {
      final ck = clearKeyFor(s(key: '$kid:$key'))!;
      expect(hex(ck.keyId), kid);
      expect(hex(ck.key), key);
    });

    // A KID is often written in UUID form in manifests.
    test('tolerates a hyphenated UUID kid', () {
      final ck = clearKeyFor(
        s(kid: '6752015A-CF08-4572-A08D-FE21796F8B45', key: key),
      )!;
      expect(hex(ck.keyId), kid);
    });

    test('accepts base64url, which W3C JWK sources emit', () {
      final ck = clearKeyFor(s(kid: 'Z1IBWs8IRXKgjf4heW-LRQ', key: key))!;
      expect(hex(ck.keyId), kid);
    });

    test('is null when there is no key at all', () {
      expect(clearKeyFor(s()), isNull);
      expect(clearKeyFor(s(kid: kid)), isNull);
    });

    // Fetching from a licence server is a request we do not make; claiming
    // otherwise would show a black screen instead of an honest refusal.
    test('is null for licence-server DRM', () {
      expect(clearKeyFor(s(licenseUrl: 'https://drm.example/lic')), isNull);
    });

    // A wrong-length key would decrypt to noise rather than fail, so it must
    // be rejected here.
    test('rejects a value that is not 16 bytes', () {
      expect(clearKeyFor(s(kid: kid, key: 'abcd')), isNull);
      expect(clearKeyFor(s(kid: kid, key: '${key}ff')), isNull);
    });

    test('rejects non-hex rubbish', () {
      expect(clearKeyFor(s(kid: kid, key: 'z' * 32)), isNull);
    });
  });

  group('drmObstacleFor', () {
    const kid = '6752015acf084572a08dfe21796f8b45';
    const key = 'ff823ddbe5625c35d3e93f0ed4520115';

    test('is null when the stream is not encrypted', () {
      expect(drmObstacleFor(s()), isNull);
    });

    test('is null when we hold a usable ClearKey', () {
      expect(drmObstacleFor(s(kid: kid, key: key)), isNull);
    });

    // A real channel: Irdeto licence server, no key in the playlist. The old
    // path labelled this "ClearKey", POSTed to it, and got 405 - so naming the
    // scheme is what stops the next person chasing a phantom bug.
    test('names Widevine from the licence server URL', () {
      expect(
        drmObstacleFor(
          s(
            licenseUrl:
                'https://x.ott.irdeto.com/licenseServer/widevine/v1/y/license',
          ),
        ),
        DrmObstacle.widevine,
      );
    });

    test('names PlayReady', () {
      expect(
        drmObstacleFor(s(licenseUrl: 'https://x/playready/license')),
        DrmObstacle.playready,
      );
    });

    test('falls back to a generic licence server', () {
      expect(
        drmObstacleFor(s(licenseUrl: 'https://x/lic')),
        DrmObstacle.licenceServer,
      );
    });

    test('reports unknown when encrypted with no usable key and no server', () {
      expect(drmObstacleFor(s(kid: kid)), DrmObstacle.unknown);
    });

    test('every obstacle has a non-empty explanation', () {
      for (final o in DrmObstacle.values) {
        expect(describeDrmObstacle(o), isNotEmpty);
      }
    });
  });
}
