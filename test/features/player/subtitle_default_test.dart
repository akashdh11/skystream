/// [SubtitleDefault], driven through the real screen over the real engine
/// fake, because the setting is not a field - it is a claim about what is on
/// screen once media has finished opening.
///
/// Two things draw subtitles: SkyStream, which reads the source's subtitle
/// files and draws them over the video, and libVLC, which draws the tracks
/// inside the video. What turns one on without anybody asking, each tested
/// here:
///
///  * Auto, choosing the source's file in the viewer's language, or failing
///    that a track inside the video in it, or failing that the source's last
///    file;
///  * libVLC choosing an EMBEDDED track for itself on the input thread, which
///    lands as a snapshot some time after `setMedia` returned;
///  * the same again on the next media, because a failover, a recovery and an
///    episode advance are each a fresh open.
///
/// And one thing must be able to turn one on: the viewer, from the Subtitles
/// tab, with nothing turning it back off again for that media.
///
/// A file on screen is found by its text - the harness serves every file as
/// one line reading the file's own name ([servedSubtitle]). A track inside
/// the video is read off [FakeVlcEngine.emit], the only snapshot carrying
/// `subtitleTrack`.
///
/// Harness rules apply - `settle`, never `pumpAndSettle`, and every test
/// unmounts in-body so no watchdog timer outlives it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/features/player/presentation/vlc/panel/player_panel.dart'
    show PlayerPanel;
import 'package:skystream/features/player/presentation/vlc/panel/player_panel_row.dart';
import 'package:skystream/features/settings/presentation/player_settings_provider.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';

import 'fake_vlc_engine.dart';
import 'vlc_screen_harness.dart';

void main() {
  late FakeVlcEngine engine;

  setUp(() {
    engine = FakeVlcEngine();
    installEngineMocks(engine: engine);
  });
  tearDown(removeEngineMocks);

  Future<AppLocalizations> english() =>
      AppLocalizations.delegate.load(const Locale('en'));

  const PlayerSettings auto = PlayerSettings();
  const PlayerSettings off = PlayerSettings(
    subtitleDefault: SubtitleDefault.off,
  );

  /// One healthy snapshot from the fake, past the screen's 250 ms throttle.
  ///
  /// This is the only thing in the harness that tells the screen which
  /// subtitle track is on, and the natives send one on every ordinary tick as
  /// well as on ESAdded.
  Future<void> tick(
    WidgetTester tester, [
    Map<String, Object?> partial = const <String, Object?>{},
  ]) async {
    await engine.emit(partial);
    await tester.pump(const Duration(milliseconds: 400));
  }

  SubtitleFile sub(String name, String lang) =>
      SubtitleFile(url: '/subs/$name.srt', label: name, lang: lang);

  /// A source carrying [subtitles], as a plugin would hand one over.
  ///
  /// Bare paths so the resolver's health probe answers without a socket.
  StreamResult source(String url, {List<SubtitleFile>? subtitles}) =>
      StreamResult(
        url: url,
        source: '1080p',
        providerName: url.split('/').last,
        subtitles: subtitles,
      );

  /// Whether SkyStream is drawing the file [name].srt.
  bool drawing(String name) => find.text('$name.srt').evaluate().isNotEmpty;

  /// The tracks inside the video, as the engine lists them - which it does
  /// once the demuxer has read them, well after the open.
  Future<void> embed(
    WidgetTester tester,
    List<Map<String, Object?>> tracks, {
    int active = -1,
  }) async {
    engine.subtitle = tracks;
    engine.activeSubtitleId = active;
    await engine.bumpTracks();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Opens the Subtitles tab from the control bar, the viewer's only route
  /// to a subtitle.
  Future<void> openSubtitles(WidgetTester tester) async {
    final l10n = await english();
    await revealPlayerControls(tester);
    await tester.tap(find.byTooltip(l10n.options));
    await settle(tester);
    expect(find.byType(PlayerPanel), findsOneWidget);
    await tester.tap(find.text(l10n.subtitles));
    await settle(tester);
  }

  group('Off', () {
    testWidgets('lists the source\'s files and draws none of them', (
      tester,
    ) async {
      await pumpPlayer(
        tester,
        preloadedStreams: <StreamResult>[
          source(
            '/sources/alpha.mkv',
            subtitles: <SubtitleFile>[
              sub('english', 'en'),
              sub('french', 'fr'),
            ],
          ),
        ],
        settings: off,
      );
      await tick(tester);

      expect(drawing('english'), isFalse);
      expect(drawing('french'), isFalse);
      expect(
        engine.methods,
        isNot(contains('addSubtitle')),
        reason: 'the files are SkyStream\'s to draw, not libVLC\'s',
      );

      await openSubtitles(tester);
      expect(
        find.widgetWithText(PanelRow, 'english'),
        findsOneWidget,
        reason: 'Off is a default: the viewer can still turn one on',
      );
      expect(find.widgetWithText(PanelRow, 'french'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    }, variant: texturePlatform);

    testWidgets('turns off an embedded track libVLC selected for itself', (
      tester,
    ) async {
      await pumpPlayer(
        tester,
        preloadedStreams: <StreamResult>[source('/sources/alpha.mkv')],
        settings: off,
      );

      // This is the input thread reaching the media's own subtitle ES after
      // the open, which is the only way an embedded track ever arrives.
      await embed(tester, const <Map<String, Object?>>[
        <String, Object?>{'id': 3, 'name': 'Track 3'},
      ], active: 3);

      expect(engine.activeSubtitleId, -1);

      await tester.pumpWidget(const SizedBox());
    }, variant: texturePlatform);

    testWidgets('sends one disable per media, not one per tick', (
      tester,
    ) async {
      await pumpPlayer(
        tester,
        preloadedStreams: <StreamResult>[source('/sources/alpha.mkv')],
        settings: off,
      );
      final int before = engine.callsTo('disableSubtitle').length;

      // An engine that keeps reporting the same selected track: a backend that
      // ignored the disable, or simply the next four snapshots before it took
      // effect. Restating a fact is not a second fact.
      engine.subtitle = const <Map<String, Object?>>[
        <String, Object?>{'id': 3, 'name': 'Track 3'},
      ];
      for (var i = 0; i < 4; i++) {
        engine.activeSubtitleId = 3;
        await tick(tester);
      }

      expect(
        engine.callsTo('disableSubtitle').length - before,
        1,
        reason:
            'applied once per media. A rule that fired on every tick could '
            'never let the viewer turn subtitles on at all',
      );

      await tester.pumpWidget(const SizedBox());
    }, variant: texturePlatform);

    testWidgets('lets a file the viewer picks stay on', (tester) async {
      await pumpPlayer(
        tester,
        preloadedStreams: <StreamResult>[
          source(
            '/sources/alpha.mkv',
            subtitles: <SubtitleFile>[
              sub('english', 'en'),
              sub('french', 'fr'),
            ],
          ),
        ],
        settings: off,
      );
      await tick(tester);
      expect(drawing('english'), isFalse, reason: 'started off, as asked');

      await openSubtitles(tester);
      await tester.tap(find.widgetWithText(PanelRow, 'english'));
      await settle(tester);

      expect(
        drawing('english'),
        isTrue,
        reason: 'Off is a default, not a lock: the menu still works',
      );
      final int disables = engine.callsTo('disableSubtitle').length;

      // Time passes with the pick in place. Nothing may take it away.
      for (var i = 0; i < 4; i++) {
        await tick(tester, <String, Object?>{'position': 3000 + i * 500});
      }
      expect(drawing('english'), isTrue);
      expect(
        engine.callsTo('disableSubtitle').length,
        disables,
        reason: 'the rule stood down when the panel opened and never returns',
      );

      await tester.pumpWidget(const SizedBox());
    }, variant: texturePlatform);

    testWidgets('starts the next source off again after a failover', (
      tester,
    ) async {
      await pumpPlayer(
        tester,
        preloadedStreams: <StreamResult>[
          source(
            '/sources/alpha.mkv',
            subtitles: <SubtitleFile>[sub('english', 'en')],
          ),
          source(
            '/sources/beta.mkv',
            subtitles: <SubtitleFile>[sub('spanish', 'es')],
          ),
        ],
        settings: off,
      );

      // Alpha dies before producing a frame, which is what makes this a
      // failover to another source rather than a retry of this one.
      await tick(tester, <String, Object?>{
        'state': 'error',
        'errorDescription': 'the socket closed',
      });
      await settle(tester);
      await tick(tester);

      expect(
        drawing('spanish'),
        isFalse,
        reason:
            'a failover nobody asked for must not switch subtitles on behind '
            'a viewer who set the default to Off',
      );
      expect(engine.activeSubtitleId, -1);

      await tester.pumpWidget(const SizedBox());
    }, variant: texturePlatform);

    testWidgets('carries a file the viewer picked across a recovery of the '
        'same source', (tester) async {
      await pumpPlayer(
        tester,
        preloadedStreams: <StreamResult>[
          source(
            '/sources/alpha.mkv',
            subtitles: <SubtitleFile>[sub('english', 'en')],
          ),
        ],
        settings: off,
      );
      await tick(tester);

      await openSubtitles(tester);
      await tester.tap(find.widgetWithText(PanelRow, 'english'));
      await settle(tester);
      expect(drawing('english'), isTrue);

      // The source drops after playing and is reopened: new media to libVLC,
      // the same film to the viewer, who was reading it. A reopen restores
      // the position, and what was on screen goes back with it - the way a
      // track inside the video is put back after one.
      await tick(tester, <String, Object?>{
        'state': 'error',
        'errorDescription': 'the socket closed',
      });
      await settle(tester);
      await tick(tester);

      expect(drawing('english'), isTrue);

      await tester.pumpWidget(const SizedBox());
    }, variant: texturePlatform);
  });

  group('Auto', () {
    testWidgets('draws the source\'s file in the viewer\'s language', (
      tester,
    ) async {
      await pumpPlayer(
        tester,
        preloadedStreams: <StreamResult>[
          source(
            '/sources/alpha.mkv',
            subtitles: <SubtitleFile>[
              sub('french', 'fr'),
              sub('english', 'en'),
            ],
          ),
        ],
        settings: auto,
      );
      await tick(tester);

      expect(drawing('english'), isTrue);
      expect(drawing('french'), isFalse);
      expect(engine.methods, isNot(contains('addSubtitle')));
      expect(
        engine.methods,
        isNot(contains('disableSubtitle')),
        reason: 'libVLC had nothing on, so there was nothing to turn off',
      );

      await tester.pumpWidget(const SizedBox());
    }, variant: texturePlatform);

    testWidgets('reads a file\'s language off its label when it declares '
        'none', (tester) async {
      await pumpPlayer(
        tester,
        preloadedStreams: <StreamResult>[
          source(
            '/sources/alpha.mkv',
            subtitles: <SubtitleFile>[
              SubtitleFile(url: '/subs/one.srt', label: 'Arabic'),
              SubtitleFile(url: '/subs/two.srt', label: 'English'),
              SubtitleFile(url: '/subs/three.srt', label: 'Hindi'),
            ],
          ),
        ],
        settings: auto,
      );
      await tick(tester);

      expect(drawing('two'), isTrue);
      expect(drawing('three'), isFalse);

      await tester.pumpWidget(const SizedBox());
    }, variant: texturePlatform);

    testWidgets('draws it after a failover as well', (tester) async {
      await pumpPlayer(
        tester,
        preloadedStreams: <StreamResult>[
          source('/sources/alpha.mkv'),
          source(
            '/sources/beta.mkv',
            subtitles: <SubtitleFile>[
              sub('english', 'en'),
              sub('french', 'fr'),
            ],
          ),
        ],
        settings: auto,
      );
      await tick(tester, <String, Object?>{
        'state': 'error',
        'errorDescription': 'the socket closed',
      });
      await settle(tester);
      await tick(tester);

      expect(drawing('english'), isTrue);
      expect(drawing('french'), isFalse);

      await tester.pumpWidget(const SizedBox());
    }, variant: texturePlatform);

    testWidgets('keeps an embedded track libVLC selected for itself', (
      tester,
    ) async {
      await pumpPlayer(
        tester,
        preloadedStreams: <StreamResult>[source('/sources/alpha.mkv')],
        settings: auto,
      );

      await embed(tester, const <Map<String, Object?>>[
        <String, Object?>{'id': 3, 'name': 'Track 3'},
      ], active: 3);
      await tick(tester);
      await tick(tester);

      expect(engine.activeSubtitleId, 3);
      expect(engine.methods, isNot(contains('disableSubtitle')));

      await tester.pumpWidget(const SizedBox());
    }, variant: texturePlatform);

    testWidgets('turns on the track inside the video that is in the viewer\'s '
        'language', (tester) async {
      await pumpPlayer(
        tester,
        preloadedStreams: <StreamResult>[source('/sources/alpha.mkv')],
        settings: auto,
      );

      // libVLC turns an embedded track on by itself only when the file flags
      // it as the default, so a film carrying English subtitles started
      // without them.
      await embed(tester, const <Map<String, Object?>>[
        <String, Object?>{'id': 3, 'name': 'Track 1 - [French]'},
        <String, Object?>{'id': 4, 'name': 'Track 2 - [English]'},
      ]);
      await tick(tester);
      await tick(tester);

      expect(engine.activeSubtitleId, 4);

      await tester.pumpWidget(const SizedBox());
    }, variant: texturePlatform);

    testWidgets('looks again when the video lists its subtitles after its '
        'audio', (tester) async {
      await pumpPlayer(
        tester,
        preloadedStreams: <StreamResult>[source('/sources/alpha.mkv')],
        settings: auto,
      );

      // A resumed MKV: the audio is listed and on before the demuxer has got
      // to the subtitles, so Auto's first look finds none.
      engine.audio = const <Map<String, Object?>>[
        <String, Object?>{'id': 1, 'name': 'Track 1 - [English]'},
      ];
      engine.activeAudioId = 1;
      await engine.bumpTracks();
      await tester.pump(const Duration(milliseconds: 400));
      await tick(tester);
      expect(engine.activeSubtitleId, -1);

      await embed(tester, const <Map<String, Object?>>[
        <String, Object?>{'id': 3, 'name': 'Track 2 - [French]'},
        <String, Object?>{'id': 4, 'name': 'Track 3 - [English]'},
      ]);
      await tick(tester);
      await tick(tester);

      expect(engine.activeSubtitleId, 4);

      await tester.pumpWidget(const SizedBox());
    }, variant: texturePlatform);

    testWidgets('prefers a full track to a forced one in the same language', (
      tester,
    ) async {
      await pumpPlayer(
        tester,
        preloadedStreams: <StreamResult>[source('/sources/alpha.mkv')],
        settings: auto,
      );

      await embed(tester, const <Map<String, Object?>>[
        <String, Object?>{'id': 3, 'name': 'Forced - [English]'},
        <String, Object?>{'id': 4, 'name': 'SDH - [English]'},
      ], active: 3);
      await tick(tester);
      await tick(tester);

      expect(engine.activeSubtitleId, 4);

      await tester.pumpWidget(const SizedBox());
    }, variant: texturePlatform);

    testWidgets('falls back to the source\'s last file when nothing is in the '
        'viewer\'s language', (tester) async {
      await pumpPlayer(
        tester,
        preloadedStreams: <StreamResult>[
          source(
            '/sources/alpha.mkv',
            subtitles: <SubtitleFile>[
              sub('french', 'fr'),
              sub('spanish', 'es'),
            ],
          ),
        ],
        settings: auto,
      );
      await tick(tester);
      await tick(tester);

      expect(
        drawing('spanish'),
        isTrue,
        reason: 'what Auto always showed when no file matched',
      );
      expect(drawing('french'), isFalse);

      await tester.pumpWidget(const SizedBox());
    }, variant: texturePlatform);

    testWidgets('falls back only once the video plays, so a track in the '
        'viewer\'s language listed before then still wins', (tester) async {
      await pumpPlayer(
        tester,
        preloadedStreams: <StreamResult>[
          source(
            '/sources/alpha.mkv',
            subtitles: <SubtitleFile>[
              sub('french', 'fr'),
              sub('spanish', 'es'),
            ],
          ),
        ],
        settings: auto,
      );

      // Still opening: the audio is listed and on, nothing has played and
      // the subtitles are not listed yet.
      engine.audio = const <Map<String, Object?>>[
        <String, Object?>{'id': 1, 'name': 'Track 1 - [English]'},
      ];
      engine.activeAudioId = 1;
      await engine.bumpTracks(<String, Object?>{'state': 'paused'});
      await tester.pump(const Duration(milliseconds: 400));
      expect(drawing('spanish'), isFalse);

      await embed(tester, const <Map<String, Object?>>[
        <String, Object?>{'id': 4, 'name': 'Track 2 - [English]'},
      ]);
      await tick(tester, <String, Object?>{'position': 3000});
      await tick(tester, <String, Object?>{'position': 4500});

      expect(engine.activeSubtitleId, 4);
      expect(drawing('spanish'), isFalse);
      expect(drawing('french'), isFalse);

      await tester.pumpWidget(const SizedBox());
    }, variant: texturePlatform);

    testWidgets('puts the track inside the video back after a reopen, even '
        'when the new media lists its subtitles after its audio', (
      tester,
    ) async {
      await pumpPlayer(
        tester,
        preloadedStreams: <StreamResult>[
          source('/sources/alpha.mkv'),
          source('/sources/beta.mkv'),
        ],
        settings: auto,
      );
      engine.audio = const <Map<String, Object?>>[
        <String, Object?>{'id': 1, 'name': 'Track 1 - [English]'},
      ];
      engine.activeAudioId = 1;
      await embed(tester, const <Map<String, Object?>>[
        <String, Object?>{'id': 4, 'name': 'Track 2 - [English]'},
      ]);
      await tick(tester);
      await tick(tester);
      expect(engine.activeSubtitleId, 4, reason: 'Auto turned it on');

      // The source drops and the media is opened again. The new media lists
      // its audio first, and its subtitles a moment later.
      await tick(tester, <String, Object?>{
        'state': 'error',
        'errorDescription': 'the socket closed',
      });
      await settle(tester);
      engine.subtitle = const <Map<String, Object?>>[];
      engine.activeSubtitleId = -1;
      await engine.bumpTracks(<String, Object?>{'state': 'paused'});
      await tester.pump(const Duration(milliseconds: 400));

      await embed(tester, const <Map<String, Object?>>[
        <String, Object?>{'id': 7, 'name': 'Track 2 - [English]'},
      ]);
      await tick(tester, <String, Object?>{'position': 3000});
      await tick(tester, <String, Object?>{'position': 4500});

      expect(
        engine.activeSubtitleId,
        7,
        reason: 'the viewer was reading English, and this media has it',
      );

      await tester.pumpWidget(const SizedBox());
    }, variant: texturePlatform);

    testWidgets('leaves alone what the viewer picked before the tracks were '
        'known', (tester) async {
      await pumpPlayer(
        tester,
        preloadedStreams: <StreamResult>[source('/sources/alpha.mkv')],
        settings: auto,
      );
      await tick(tester);
      await openSubtitles(tester);
      final int sets = engine.callsTo('setSubtitleTrack').length;

      await embed(tester, const <Map<String, Object?>>[
        <String, Object?>{'id': 4, 'name': 'Track 1 - [English]'},
      ]);
      await tick(tester);
      await tick(tester);

      expect(engine.callsTo('setSubtitleTrack').length, sets);
      expect(engine.activeSubtitleId, -1);

      await tester.pumpWidget(const SizedBox());
    }, variant: texturePlatform);
  });

  group('a file and a track inside the video', () {
    testWidgets('are never on together: libVLC\'s own goes off under a file', (
      tester,
    ) async {
      await pumpPlayer(
        tester,
        preloadedStreams: <StreamResult>[
          source(
            '/sources/alpha.mkv',
            subtitles: <SubtitleFile>[sub('english', 'en')],
          ),
        ],
        settings: auto,
      );
      await tick(tester);
      expect(drawing('english'), isTrue);

      // The media turns one of its own on, as it may at any time.
      await embed(tester, const <Map<String, Object?>>[
        <String, Object?>{'id': 3, 'name': 'Track 3'},
      ], active: 3);

      expect(engine.activeSubtitleId, -1);
      expect(drawing('english'), isTrue);

      await tester.pumpWidget(const SizedBox());
    }, variant: texturePlatform);

    testWidgets('picking the track inside the video takes the file off', (
      tester,
    ) async {
      await pumpPlayer(
        tester,
        preloadedStreams: <StreamResult>[
          source(
            '/sources/alpha.mkv',
            subtitles: <SubtitleFile>[sub('english', 'en')],
          ),
        ],
        settings: auto,
      );
      await tick(tester);
      await embed(tester, const <Map<String, Object?>>[
        <String, Object?>{'id': 3, 'name': 'Commentary'},
      ]);
      expect(drawing('english'), isTrue);

      await openSubtitles(tester);
      await tester.tap(find.widgetWithText(PanelRow, 'Commentary'));
      await settle(tester);
      await tick(tester);

      expect(engine.activeSubtitleId, 3);
      expect(drawing('english'), isFalse);

      // And it stays on: nothing is left believing a file is showing.
      await tick(tester);
      await tick(tester);
      expect(engine.activeSubtitleId, 3);

      await tester.pumpWidget(const SizedBox());
    }, variant: texturePlatform);

    testWidgets('Off takes whichever is on off', (tester) async {
      await pumpPlayer(
        tester,
        preloadedStreams: <StreamResult>[
          source(
            '/sources/alpha.mkv',
            subtitles: <SubtitleFile>[sub('english', 'en')],
          ),
        ],
        settings: auto,
      );
      await tick(tester);
      expect(drawing('english'), isTrue);
      final l10n = await english();

      await openSubtitles(tester);
      await tester.tap(find.widgetWithText(PanelRow, l10n.off));
      await settle(tester);

      expect(drawing('english'), isFalse);
      expect(engine.activeSubtitleId, -1);

      await tester.pumpWidget(const SizedBox());
    }, variant: texturePlatform);
  });
}
