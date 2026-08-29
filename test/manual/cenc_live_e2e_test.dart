@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/services/local_proxy_service.dart';

const _mpd =
    'https://livestream1.sunnxt.com/05b5df1221764bca9867054c5e65ee62/SunTVB_IN_index.mpd';

void main() {
  test('proxy serves a decrypted DASH stream end to end', () async {
    final key = _unhex('ff823ddbe5625c35d3e93f0ed4520115');
    final kid = _unhex('6752015acf084572a08dfe21796f8b45');

    final proxy = LocalProxyService.instance;
    await proxy.startServer();
    final url = proxy.getDecryptingDashUrl(_mpd, key: key, keyId: kid);
    // ignore: avoid_print
    print('proxy manifest url: $url');

    final client = HttpClient();
    addTearDown(client.close);

    final manifest = utf8.decode(await _get(client, url), allowMalformed: true);
    // ignore: avoid_print
    print('manifest via proxy: ${manifest.length} chars');

    final media = RegExp(r'media="([^"]+)"').firstMatch(manifest)?.group(1);
    final init = RegExp(r'initialization="([^"]+)"').firstMatch(manifest)?.group(1);
    expect(init, isNotNull, reason: 'no initialization attribute survived');
    expect(media, isNotNull, reason: 'no media attribute survived');
    // ignore: avoid_print
    print('rewritten media: ${media!.substring(0, media.length.clamp(0, 110))}');
    expect(media, contains(r'$Number$'),
        reason: 'template token must stay literal or VLC never requests');

    final initBytes = await _get(client, init!.replaceAll('&amp;', '&'));
    // ignore: avoid_print
    print('init via proxy: ${initBytes.length} bytes, '
        'encv=${_has(initBytes, "encv")} avc1=${_has(initBytes, "avc1")}');
    expect(_has(initBytes, 'encv'), isFalse, reason: 'init still says encv');
    expect(_has(initBytes, 'avc1'), isTrue, reason: 'codec not restored');

    final start =
        int.parse(RegExp(r'startNumber="(\d+)"').firstMatch(manifest)!.group(1)!);
    // NB: r="..." must be anchored on whitespace, or it matches the tail of
    // startNumbe|r="..." and yields a nonsense segment number.
    final reps =
        int.parse(RegExp(r'\sr="(\d+)"').firstMatch(manifest)!.group(1)!);
    final n = start + reps - 1;
    final segBytes = await _get(
      client,
      media.replaceAll('&amp;', '&').replaceAll(r'$Number$', '$n'),
    );
    // ignore: avoid_print
    print('segment $n via proxy: ${segBytes.length} bytes');
    expect(segBytes.length, greaterThan(10000));

    File('/tmp/e2e_init.mp4').writeAsBytesSync(initBytes);
    File('/tmp/e2e_seg.m4s').writeAsBytesSync(segBytes);
  }, timeout: const Timeout(Duration(minutes: 2)));
}

bool _has(Uint8List d, String s) {
  final needle = s.codeUnits;
  outer:
  for (var i = 0; i + needle.length <= d.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (d[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}

Future<Uint8List> _get(HttpClient c, String url) async {
  final r = await (await c.getUrl(Uri.parse(url))).close();
  if (r.statusCode >= 400) throw StateError('HTTP ${r.statusCode} for $url');
  final b = BytesBuilder(copy: false);
  await for (final chunk in r) {
    b.add(chunk);
  }
  return b.takeBytes();
}

Uint8List _unhex(String s) {
  final o = Uint8List(s.length ~/ 2);
  for (var i = 0; i < o.length; i++) {
    o[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return o;
}
