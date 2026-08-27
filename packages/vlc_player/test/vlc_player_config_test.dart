import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_player/vlc_player.dart';

void main() {
  group('VlcNetworkConfig', () {
    test('emits nothing when every field is null', () {
      expect(const VlcNetworkConfig().toOptions(), isEmpty);
    });

    test('emits caching and HTTP identity options', () {
      const config = VlcNetworkConfig(
        networkCaching: 3000,
        liveCaching: 5000,
        fileCaching: 300,
        userAgent: 'Mozilla/5.0 (X11; Linux x86_64)',
        referer: 'https://example.test/',
      );
      expect(config.toOptions(), <String>[
        '--network-caching=3000',
        '--live-caching=5000',
        '--file-caching=300',
        '--http-user-agent=Mozilla/5.0 (X11; Linux x86_64)',
        '--http-referrer=https://example.test/',
      ]);
    });

    test('skips empty strings rather than emitting a valueless flag', () {
      const config = VlcNetworkConfig(userAgent: '', referer: '');
      expect(config.toOptions(), isEmpty);
    });

    test('emits adaptive rendition controls', () {
      const config = VlcNetworkConfig(
        adaptiveLogic: VlcAdaptiveLogic.lowest,
        adaptiveMaxHeight: 1080,
      );
      expect(config.toOptions(), <String>[
        '--adaptive-logic=lowest',
        '--adaptive-maxheight=1080',
      ]);
    });
  });

  group('VlcDecodingConfig', () {
    test('platformDefault leaves --avcodec-hw unset', () {
      const config = VlcDecodingConfig();
      expect(config.toOptions(), isEmpty);
    });

    test('maps hardware acceleration to --avcodec-hw', () {
      expect(
        const VlcDecodingConfig(
          hardwareAcceleration: VlcHardwareAcceleration.automatic,
        ).toOptions(),
        contains('--avcodec-hw=any'),
      );
      expect(
        const VlcDecodingConfig(
          hardwareAcceleration: VlcHardwareAcceleration.disabled,
        ).toOptions(),
        contains('--avcodec-hw=none'),
      );
    });

    test('decode thrift escalates the skip levels', () {
      expect(
        const VlcDecodingConfig(
          decodeThrift: VlcDecodeThrift.light,
        ).toOptions(),
        <String>['--avcodec-skiploopfilter=1', '--avcodec-skip-frame=0'],
      );
      expect(
        const VlcDecodingConfig(
          decodeThrift: VlcDecodeThrift.aggressive,
        ).toOptions(),
        <String>['--avcodec-skiploopfilter=3', '--avcodec-skip-frame=1'],
      );
    });

    test('drop-late-frames emits the negated flag when false', () {
      expect(
        const VlcDecodingConfig(dropLateFrames: false).toOptions(),
        contains('--no-drop-late-frames'),
      );
      expect(
        const VlcDecodingConfig(dropLateFrames: true).toOptions(),
        contains('--drop-late-frames'),
      );
    });

    test('never emits an empty option string', () {
      const config = VlcDecodingConfig(
        hardwareAcceleration: VlcHardwareAcceleration.platformDefault,
        decodeThrift: VlcDecodeThrift.aggressive,
        threads: 4,
      );
      expect(config.toOptions().any((o) => o.isEmpty), isFalse);
    });
  });

  group('VlcSubtitleStyle', () {
    test('splits a colour into VLC rgb + opacity pairs', () {
      const style = VlcSubtitleStyle(
        color: Color(0xCCFF8800),
        outlineColor: Color(0xFF000000),
      );
      expect(
        style.toOptions(),
        containsAll(<String>[
          '--freetype-color=${0xFF8800}',
          '--freetype-opacity=204',
          '--freetype-outline-color=0',
          '--freetype-outline-opacity=255',
        ]),
      );
    });

    test('emits the negated flag for false booleans', () {
      expect(
        const VlcSubtitleStyle(bold: false).toOptions(),
        contains('--no-freetype-bold'),
      );
      expect(
        const VlcSubtitleStyle(autoDetectFiles: false).toOptions(),
        contains('--no-sub-autodetect-file'),
      );
    });

    test('emits sizing, margin and alignment', () {
      const style = VlcSubtitleStyle(
        fontFamily: 'Roboto',
        relativeFontSize: 16,
        marginPixels: 40,
        alignment: VlcSubtitleAlignment.center,
        outlineThickness: 4,
      );
      expect(
        style.toOptions(),
        containsAll(<String>[
          '--freetype-font=Roboto',
          '--freetype-rel-fontsize=16',
          '--sub-margin=40',
          '--freetype-text-align=center',
          '--freetype-outline-thickness=4',
        ]),
      );
    });
  });

  group('VlcPlayerConfig', () {
    test('quiet and no-title are the defaults', () {
      expect(const VlcPlayerConfig().toOptions(), <String>[
        '--no-video-title-show',
        '--quiet',
      ]);
    });

    test('verbose replaces quiet', () {
      final options = const VlcPlayerConfig(verbose: true).toOptions();
      expect(options, contains('--verbose=2'));
      expect(options, isNot(contains('--quiet')));
    });

    test('extraOptions come last so they can override generated ones', () {
      final options = const VlcPlayerConfig(
        network: VlcNetworkConfig(networkCaching: 1000),
        extraOptions: <String>['--network-caching=9000'],
      ).toOptions();
      expect(options.last, '--network-caching=9000');
      expect(
        options.indexOf('--network-caching=1000'),
        lessThan(options.indexOf('--network-caching=9000')),
      );
    });

    test('composes every group in order', () {
      const config = VlcPlayerConfig(
        network: VlcNetworkConfig(networkCaching: 2000),
        decoding: VlcDecodingConfig(
          hardwareAcceleration: VlcHardwareAcceleration.automatic,
        ),
        subtitleStyle: VlcSubtitleStyle(relativeFontSize: 16),
      );
      expect(config.toOptions(), <String>[
        '--no-video-title-show',
        '--quiet',
        '--network-caching=2000',
        '--avcodec-hw=any',
        '--freetype-rel-fontsize=16',
      ]);
    });

    test('copyWith replaces only the named group', () {
      const base = VlcPlayerConfig(
        network: VlcNetworkConfig(networkCaching: 1000),
        verbose: true,
      );
      final next = base.copyWith(
        network: const VlcNetworkConfig(networkCaching: 4000),
      );
      expect(next.toOptions(), contains('--network-caching=4000'));
      expect(next.verbose, isTrue);
    });
  });

  group('controller integration', () {
    test('config expands into options, with raw options appended after', () {
      final controller = VlcPlayerController(
        config: const VlcPlayerConfig(
          network: VlcNetworkConfig(networkCaching: 2500),
        ),
        options: const <String>['--custom-flag'],
      );
      addTearDown(controller.dispose);

      expect(controller.options, <String>[
        '--no-video-title-show',
        '--quiet',
        '--network-caching=2500',
        '--custom-flag',
      ]);
    });

    test('omitting config keeps the raw options path untouched', () {
      final controller = VlcPlayerController(
        options: const <String>['--only-this'],
      );
      addTearDown(controller.dispose);
      expect(controller.options, <String>['--only-this']);
    });
  });

  group('VlcPlayerCapabilities', () {
    test('documents the limits a host would otherwise hard-code', () {
      expect(VlcPlayerCapabilities.maxVolumePercent, 200);
      expect(VlcPlayerCapabilities.supportsSubtitleDelay, isTrue);
      expect(VlcPlayerCapabilities.supportsExternalSubtitles, isTrue);
      // VLC 3.x fixes subtitle styling at instance creation, and has no
      // tone-mapping controls. Hosts must branch on these.
      expect(VlcPlayerCapabilities.supportsRuntimeSubtitleStyling, isFalse);
      expect(VlcPlayerCapabilities.supportsToneMapping, isFalse);
    });
  });
}
