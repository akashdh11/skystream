import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/utils/source_text.dart';

/// The sources sheet mixes SkyStream plugin links with Nuvio scraper links.
/// Each system labels a link in its own style, which made one list read like
/// two. These are the real shapes seen from the installed repositories.
void main() {
  group('cleanSourceText', () {
    test('drops the zero-width padding providers use to force sort order', () {
      expect(
        cleanSourceText('\u200b\ufeff\u200b4KHDHub | 2160p | Dual-Audio'),
        '4KHDHub · 2160p · Dual-Audio',
      );
    });

    test('drops emoji', () {
      expect(
        cleanSourceText('🎬 Spider-Man ⚡ 2160p 💾 71.41GB'),
        'Spider-Man · 2160p · 71.41GB'.replaceAll(' · ', ' '),
      );
    });

    test('turns line breaks into one separator', () {
      expect(
        cleanSourceText('Movie title\n2160p | 71.41GB\n\nHDR10'),
        'Movie title · 2160p · 71.41GB · HDR10',
      );
    });

    test('collapses whitespace and trims separators', () {
      expect(cleanSourceText('  1080p    WEB-DL   '), '1080p WEB-DL');
      expect(cleanSourceText('| 720p |'), '720p');
    });

    test('null and empty are empty', () {
      expect(cleanSourceText(null), '');
      expect(cleanSourceText('   '), '');
    });
  });

  group('buildSourceDetail', () {
    test('joins the parts that carry information', () {
      expect(
        buildSourceDetail(['2.1 GB', 'en', '42 seeds', 'Provider 1080p']),
        '2.1 GB · en · 42 seeds · Provider 1080p',
      );
    });

    test('never repeats the same value twice', () {
      expect(buildSourceDetail(['1080p', '1080p']), '1080p');
      expect(buildSourceDetail(['1080p', '1080p WEB-DL']), '1080p WEB-DL');
    });

    test('skips empty parts', () {
      expect(buildSourceDetail([null, '', '  ', '4K']), '4K');
    });

    test('falls back when there is nothing to show', () {
      expect(
        buildSourceDetail([null, ''], fallback: 'MyProvider'),
        'MyProvider',
      );
    });

    test('a Nuvio row and a SkyStream row end up in the same style', () {
      final nuvio = buildSourceDetail([
        '71.41GB',
        'Hindi',
        null,
        '\u200b\u200b🎬 4KHDHub | 2160p | Dual-Audio',
      ]);
      final skystream = buildSourceDetail(['1080p WEB-DL x264 | SERVER 3']);
      expect(nuvio, '71.41GB · Hindi · 4KHDHub · 2160p · Dual-Audio');
      expect(skystream, '1080p WEB-DL x264 · SERVER 3');
      for (final label in [nuvio, skystream]) {
        expect(label.contains('|'), isFalse);
        expect(label.contains('\u200b'), isFalse);
        expect(label.contains('  '), isFalse);
      }
    });
  });
}
