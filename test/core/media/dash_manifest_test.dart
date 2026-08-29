import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/media/dash_manifest.dart';

void main() {
  // Shaped like the live SUN NXT manifest this was built against.
  const manifest = '''
<MPD type="dynamic" minimumUpdatePeriod="PT2S">
  <Period>
    <AdaptationSet mimeType="video/mp4">
      <Representation id="11" bandwidth="1499968">
        <SegmentTemplate timescale="25000"
          media="SunTVB_index_video_11_0_\$Number\$.mp4?m=1732249790"
          initialization="SunTVB_index_video_11_0_init.mp4?m=1732249790"
          startNumber="11329051"/>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>''';

  final manifestUrl = Uri.parse(
    'https://livestream1.example.com/abc123/SunTVB_index.mpd',
  );

  group('rewriteDashManifest', () {
    test('resolves relative templates against the manifest URL', () {
      final seen = <String>[];
      rewriteDashManifest(
        manifest: manifest,
        manifestUrl: manifestUrl,
        proxyUrlFor: (url, {required bool isInit}) {
          seen.add(url);
          return 'http://127.0.0.1:1/x';
        },
      );
      expect(seen, hasLength(2));
      expect(
        seen.every(
          (u) => u.startsWith('https://livestream1.example.com/abc123/'),
        ),
        isTrue,
      );
    });

    // The whole point: VLC substitutes the token textually before requesting a
    // segment, so if it survives as %24Number%24 the player silently never
    // asks for anything. The failure is silence, not an error.
    test('keeps the \$Number\$ token literal in the upstream URL', () {
      String? mediaUrl;
      rewriteDashManifest(
        manifest: manifest,
        manifestUrl: manifestUrl,
        proxyUrlFor: (url, {required bool isInit}) {
          if (!isInit) mediaUrl = url;
          return 'http://127.0.0.1:1/x';
        },
      );
      expect(mediaUrl, contains(r'$Number$'));
      expect(mediaUrl, isNot(contains('%24')));
    });

    test('flags the initialization attribute distinctly from media', () {
      final inits = <String>[];
      final medias = <String>[];
      rewriteDashManifest(
        manifest: manifest,
        manifestUrl: manifestUrl,
        proxyUrlFor: (url, {required bool isInit}) {
          (isInit ? inits : medias).add(url);
          return 'http://127.0.0.1:1/x';
        },
      );
      expect(inits, hasLength(1));
      expect(medias, hasLength(1));
      expect(inits.single, contains('init.mp4'));
      expect(medias.single, contains(r'$Number$'));
    });

    test('substitutes the replacement into the output and escapes it', () {
      final out = rewriteDashManifest(
        manifest: manifest,
        manifestUrl: manifestUrl,
        proxyUrlFor: (url, {required bool isInit}) =>
            'http://127.0.0.1:9/cenc?url=x&k=y',
      );
      // Ampersands must be escaped or the manifest stops being well-formed.
      expect(out, contains('&amp;k=y'));
      expect(out, isNot(contains('SunTVB_index_video_11_0_\$Number\$.mp4')));
    });

    test('honours an absolute BaseURL', () {
      const withBase = '''
<MPD><Period><BaseURL>https://cdn.example/live/</BaseURL>
<AdaptationSet><Representation>
<SegmentTemplate media="seg_\$Number\$.m4s" initialization="init.mp4"/>
</Representation></AdaptationSet></Period></MPD>''';
      final seen = <String>[];
      rewriteDashManifest(
        manifest: withBase,
        manifestUrl: manifestUrl,
        proxyUrlFor: (url, {required bool isInit}) {
          seen.add(url);
          return 'http://127.0.0.1:1/x';
        },
      );
      expect(seen.every((u) => u.startsWith('https://cdn.example/live/')), isTrue);
    });

    test('leaves a manifest with no segment templates untouched', () {
      const plain = '<MPD><Period/></MPD>';
      expect(
        rewriteDashManifest(
          manifest: plain,
          manifestUrl: manifestUrl,
          proxyUrlFor: (url, {required bool isInit}) => 'x',
        ),
        plain,
      );
    });
  });
}
