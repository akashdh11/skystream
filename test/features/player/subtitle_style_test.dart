/// What the viewer's subtitle settings become for libVLC: the options a
/// player is created with, the look it takes while it plays, and the font
/// each platform names.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/features/player/domain/subtitle_style.dart';
import 'package:skystream/features/settings/presentation/player_settings_provider.dart';
import 'package:vlc_player/vlc_player.dart';

void main() {
  group('relativeSizeFor', () {
    test('is libVLC\'s inverted scale, held to 8..60', () {
      expect(relativeSizeFor(22), 24);
      expect(relativeSizeFor(44), 12);
      expect(relativeSizeFor(80), 8, reason: '6.6 is past the largest');
      expect(relativeSizeFor(5), 60, reason: '105.6 is past the smallest');
      expect(relativeSizeFor(0), 24, reason: 'no size is the default size');
    });
  });

  group('subtitleStyleFrom', () {
    test('a fresh install creates the player exactly as it always did', () {
      expect(subtitleStyleFrom(const PlayerSettings()).toOptions(), <String>[
        '--freetype-rel-fontsize=24',
        '--freetype-color=${0xFFFFFF}',
        '--freetype-opacity=255',
        '--freetype-outline-color=0',
        '--freetype-outline-opacity=255',
        '--freetype-outline-thickness=2',
        '--freetype-background-color=0',
        '--freetype-background-opacity=128',
      ]);
    });

    test('takes bold, the font, the text opacity and the encoding', () {
      final List<String> options = subtitleStyleFrom(
        const PlayerSettings(
          subtitleBold: true,
          subtitleFont: SubtitleFont.serif,
          subtitleTextOpacity: 0.5,
          subtitleEncoding: 'Windows-1251',
        ),
      ).toOptions();

      expect(
        options,
        containsAll(<String>[
          '--freetype-bold',
          '--freetype-font=${subtitleFontFamily(SubtitleFont.serif)}',
          '--freetype-opacity=128',
          '--subsdec-encoding=Windows-1251',
        ]),
      );
    });

    test('outlines at libVLC\'s own presets', () {
      int? thickness(SubtitleOutline outline) =>
          subtitleStyleFrom(PlayerSettings(subtitleOutline: outline))
              .outlineThickness;

      expect(thickness(SubtitleOutline.none), 0);
      expect(thickness(SubtitleOutline.thin), 2);
      expect(thickness(SubtitleOutline.normal), 4);
      expect(thickness(SubtitleOutline.thick), 6);
    });

    test('the text opacity replaces the stored colour\'s own alpha', () {
      final Color? colour = subtitleStyleFrom(
        const PlayerSettings(
          subtitleColor: 0x80FFEB3B,
          subtitleTextOpacity: 0.75,
        ),
      ).color;
      expect(colour?.toARGB32(), 0xBFFFEB3B);
    });
  });

  group('subtitleLookFrom', () {
    test('scales against the size the player was created with', () {
      // Created at 22, which is libVLC's 24; 44 is its 12: twice the size.
      expect(
        subtitleLookFrom(
          const PlayerSettings(subtitleSize: 44),
          createdRelativeSize: 24,
        ).textScale,
        200,
      );
      // Created at 44, its 12; 22 is half the size.
      expect(
        subtitleLookFrom(
          const PlayerSettings(subtitleSize: 22),
          createdRelativeSize: 12,
        ).textScale,
        50,
      );
      expect(
        subtitleLookFrom(
          const PlayerSettings(),
          createdRelativeSize: 24,
        ).textScale,
        100,
      );
    });

    test('the scale moves with every size step', () {
      // Created at 22, the default, the scale stays inside libVLC's 10..500
      // all the way from 10 to 80, so each step has to say something new.
      int scaleAt(int size) => subtitleLookFrom(
        PlayerSettings(subtitleSize: size.toDouble()),
        createdRelativeSize: 24,
      ).textScale;
      for (var size = 11; size <= 80; size++) {
        expect(scaleAt(size), greaterThan(scaleAt(size - 1)), reason: '$size');
      }
    });

    test('holds the scale to the 10..500 libVLC takes', () {
      // Created at the smallest size and asked for the largest: 750 %.
      expect(
        subtitleLookFrom(
          const PlayerSettings(subtitleSize: 80),
          createdRelativeSize: 60,
        ).textScale,
        500,
      );
      expect(
        subtitleLookFrom(
          const PlayerSettings(subtitleSize: 10),
          createdRelativeSize: 4,
        ).textScale,
        10,
      );
    });

    test('carries the colours, the box, the outline and the lift', () {
      final look = subtitleLookFrom(
        const PlayerSettings(
          subtitleColor: 0xFFFFEB3B,
          subtitleBackgroundColor: 0xFF303030,
          subtitleBackgroundOpacity: 0.8,
          subtitleOutline: SubtitleOutline.normal,
          subtitleRaise: 0.1,
        ),
        createdRelativeSize: 24,
      );

      expect(look.color, const Color(0xFFFFEB3B));
      expect(look.backgroundColor, const Color(0xFF303030));
      expect(look.backgroundOpacity, 204);
      expect(look.outlineThickness, 4);
      expect(look.raise, 0.1);
    });

    test('a box at zero opacity is no box, whatever its colour', () {
      expect(
        subtitleLookFrom(
          const PlayerSettings(
            subtitleBackgroundColor: 0xFFFFFFFF,
            subtitleBackgroundOpacity: 0,
          ),
          createdRelativeSize: 24,
        ).backgroundOpacity,
        0,
      );
    });

    test('leaves out what is fixed when the player is created', () {
      // libVLC keeps the text's opacity from creation, so a look that moved
      // with it would only ever be sent for nothing.
      const PlayerSettings plain = PlayerSettings();
      expect(
        subtitleLookFrom(
          plain.copyWith(
            subtitleTextOpacity: 0.5,
            subtitleBold: true,
            subtitleFont: SubtitleFont.monospace,
            subtitleEncoding: 'Windows-1251',
            subtitleColor: 0x80FFFFFF,
          ),
          createdRelativeSize: 24,
        ),
        subtitleLookFrom(plain, createdRelativeSize: 24),
      );
      // The stored background is transparent black: the look's is opaque,
      // its opacity a number of its own.
      expect(
        subtitleLookFrom(plain, createdRelativeSize: 24).backgroundColor,
        const Color(0xFF000000),
      );
    });
  });

  group('subtitleTargetY', () {
    test('is one fixed place above the area\'s bottom, whatever the picture', () {
      // A 16:9 picture on a 932x430 landscape phone: the lines sit 6% of
      // the frame above the area's bottom — the same low place for every
      // fit and zoom. No picture in it: the same area always reads the
      // same place.
      expect(subtitleTargetY(const Size(932, 430), 0), closeTo(404.2, 0.01));
      expect(subtitleTargetY(const Size(800, 400), 0), closeTo(376, 0.01));
    });

    test('the viewer\'s lift raises the fixed place', () {
      // The lift is a share of the frame, on top of the edge margin.
      expect(
        subtitleTargetY(const Size(932, 430), 0.2),
        closeTo(430 - 25.8 - 86, 0.01),
      );
    });
  });

  group('subtitleLookAnchored', () {
    // A 2:1 frame filling an 800x400 player: the picture is the screen, so
    // the anchored look is the plain one, lifted by the edge margin alone.
    const screen = Size(800, 400);
    const video = Size(1600, 800);

    VlcSubtitleLook anchored({
      PlayerSettings settings = const PlayerSettings(),
      Size area = screen,
      Size frame = video,
      VlcVideoFit fit = VlcVideoFit.contain,
      double pinchScale = 1.0,
    }) => subtitleLookAnchored(
      settings,
      createdRelativeSize: 24,
      screen: area,
      video: frame,
      fit: fit,
      pinchScale: pinchScale,
    );

    test('a picture that is the screen reads as the plain look', () {
      final look = anchored();
      expect(look.textScale, 100);
      expect(look.raise, closeTo(0.06, 1e-9));
    });

    test('a 16:9 picture on a landscape phone sits low, not a bar above it', () {
      // The target is the area's bottom edge now — a small fixed margin
      // above it — so the raise is the edge margin alone, the normal
      // Netflix place.
      final look = anchored(
        area: const Size(932, 430),
        frame: const Size(1920, 1080),
      );
      expect(look.textScale, 100);
      expect(look.raise, closeTo(0.06, 1e-9));
    });

    test('cover undoes the picture\'s enlargement', () {
      // A square frame covering the player is twice as tall on screen, so
      // the text halves and the lines climb nearly a third of the frame to
      // stay where they were.
      final look = anchored(frame: const Size(800, 800), fit: VlcVideoFit.cover);
      expect(look.textScale, 50);
      expect(look.raise, closeTo(0.28, 1e-9));
    });

    test('a pinch in undoes the zoom the same way', () {
      final look = anchored(pinchScale: 2.0);
      expect(look.textScale, 50);
      expect(look.raise, closeTo(0.28, 1e-9));
    });

    test('a pinch in or out lands the lines at the same place', () {
      // The report: zooming in or out moved the subtitles with the
      // picture. The target is the area's now, so the lines land at the
      // same screen y at 1.0x, 1.5x and 2.5x — and read the same size.
      const target = 400 - 400 * 0.06; // 376, the fixed place
      const targetSize = 400 / 24; // subtitleFontSize at this area
      for (final pinch in <double>[1.0, 1.5, 2.5]) {
        final look = anchored(pinchScale: pinch);
        // The picture on screen, as the look computes it: contain scales
        // the 1600x800 frame to the 800x400 screen (0.5), then the pinch
        // scales it about the screen's centre.
        final displayScaleY = 0.5 * pinch;
        final height = 800 * displayScaleY;
        final bottom = 200 + height / 2;
        final landed = bottom - look.raise * height;
        expect(landed, closeTo(target, 1.0), reason: 'pinch $pinch');
        final rendered = 800 / 24 * (look.textScale / 100) * displayScaleY;
        expect(rendered, closeTo(targetSize, 0.5), reason: 'pinch $pinch');
      }
    });

    test('a pinch out stops the lines at the picture\'s bottom edge', () {
      // Half size, the picture's bottom is above the fixed target — and
      // libVLC cannot draw below the frame, so the raise clamps at 0 and
      // the lines sit at the picture's bottom edge until the picture
      // covers the target again, rather than dropping to the area's
      // bottom. The size still undoes the zoom.
      final look = anchored(pinchScale: 0.5);
      expect(look.textScale, 200);
      expect(look.raise, 0.0);
    });

    test('the viewer\'s lift raises the anchor', () {
      final look = anchored(
        settings: const PlayerSettings(subtitleRaise: 0.2),
      );
      expect(look.textScale, 100);
      expect(look.raise, closeTo(0.26, 1e-9));
    });

    test('stretch reads as the plain look at the same size', () {
      final look = anchored(frame: const Size(800, 800), fit: VlcVideoFit.fill);
      expect(look.textScale, 100);
      expect(look.raise, closeTo(0.06, 1e-9));
    });

    test('an unknown size falls back to the plain look', () {
      expect(
        anchored(frame: Size.zero),
        subtitleLookFrom(const PlayerSettings(), createdRelativeSize: 24),
      );
      expect(
        anchored(area: Size.zero),
        subtitleLookFrom(const PlayerSettings(), createdRelativeSize: 24),
      );
    });
  });

  group('subtitleFontFamily', () {
    test('names a family each platform has, and none for the default', () {
      const families = <TargetPlatform, (String, String)>{
        TargetPlatform.android: ('serif', 'monospace'),
        TargetPlatform.iOS: ('Times New Roman', 'Menlo'),
        TargetPlatform.macOS: ('Times New Roman', 'Menlo'),
        TargetPlatform.windows: ('Times New Roman', 'Consolas'),
        TargetPlatform.linux: ('serif', 'monospace'),
      };
      for (final MapEntry(key: platform, value: (serif, monospace))
          in families.entries) {
        expect(
          subtitleFontFamily(SubtitleFont.serif, platform: platform),
          serif,
          reason: '$platform',
        );
        expect(
          subtitleFontFamily(SubtitleFont.monospace, platform: platform),
          monospace,
          reason: '$platform',
        );
        expect(
          subtitleFontFamily(SubtitleFont.standard, platform: platform),
          isNull,
          reason: '$platform',
        );
      }
    });

    test('reads the platform the app runs on', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        expect(subtitleFontFamily(SubtitleFont.monospace), 'Consolas');
        expect(
          subtitleStyleFrom(
            const PlayerSettings(subtitleFont: SubtitleFont.monospace),
          ).fontFamily,
          'Consolas',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
