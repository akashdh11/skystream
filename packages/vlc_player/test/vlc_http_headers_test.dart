import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_player/vlc_player.dart';

void main() {
  group('vlcHeaderOptions', () {
    // The regression this file exists for: the package used to emit
    // ':http-header=Name: Value', an option that does not exist in any
    // libVLC 3.x build, so every header was silently discarded.
    test('never emits the non-existent http-header option', () {
      final options = vlcHeaderOptions({
        'User-Agent': 'Mozilla/5.0',
        'Referer': 'https://example.com/',
        'Cookie': 'session=abc',
        'Authorization': 'Bearer tok',
        'Origin': 'https://example.com',
        'X-Custom': 'v',
      });

      expect(options.any((o) => o.contains('http-header')), isFalse);
      for (final option in options) {
        expect(
          option,
          anyOf(startsWith(':http-user-agent='), startsWith(':http-referrer=')),
          reason: 'only options libVLC actually registers may be emitted',
        );
      }
    });

    test('maps User-Agent and Referer to the options libVLC registers', () {
      expect(
        vlcHeaderOptions({
          'User-Agent': 'Mozilla/5.0',
          'Referer': 'https://example.com/',
        }),
        <String>[
          ':http-user-agent=Mozilla/5.0',
          ':http-referrer=https://example.com/',
        ],
      );
    });

    test('matches header names case-insensitively', () {
      expect(vlcHeaderOptions({'user-agent': 'UA'}), <String>[
        ':http-user-agent=UA',
      ]);
      expect(vlcHeaderOptions({'REFERER': 'R'}), <String>[':http-referrer=R']);
    });

    test('accepts the two-r spelling callers often use', () {
      expect(vlcHeaderOptions({'Referrer': 'R'}), <String>[':http-referrer=R']);
    });

    test('drops blank values and CR/LF, which would corrupt later options', () {
      expect(vlcHeaderOptions({'User-Agent': ''}), isEmpty);
      expect(vlcHeaderOptions({'User-Agent': 'a\r\nb'}), isEmpty);
      expect(vlcHeaderOptions({'Referer': 'x\ny'}), isEmpty);
    });

    test('emits nothing for headers libVLC cannot express', () {
      expect(
        vlcHeaderOptions({
          'Cookie': 'session=abc',
          'Authorization': 'Bearer tok',
        }),
        isEmpty,
      );
    });
  });

  group('unsupportedVlcHeaders', () {
    test('names exactly what will not reach the network', () {
      expect(
        unsupportedVlcHeaders({
          'User-Agent': 'UA',
          'Referer': 'R',
          'Cookie': 'session=abc',
          'Authorization': 'Bearer tok',
        }),
        <String>['Cookie', 'Authorization'],
      );
    });

    test('is empty when every header can be transmitted', () {
      expect(
        unsupportedVlcHeaders({'User-Agent': 'UA', 'Referer': 'R'}),
        isEmpty,
      );
    });

    test('preserves the caller original casing so logs are recognisable', () {
      expect(unsupportedVlcHeaders({'X-Api-Key': 'k'}), <String>['X-Api-Key']);
    });
  });
}
