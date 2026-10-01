/// The Skip chip — the one control that lives *outside* the chrome.
///
/// Nothing tested it at all before this file, which is how two defects sat in
/// it: it answered "I am done with this episode" by seeking further into the
/// episode, and it stayed mounted, hit-testable and D-pad reachable underneath
/// the up-next card that is painted over the very same corner.
///
/// The focus half is the part a phone cannot show you. The chip is deliberately
/// not inside `player-chrome`, so it survives hidden bars — and that same fact
/// costs it the one rule the rest of the controls get for free: the bars coming
/// up must not take the remote off a chip that is holding it, which is what
/// every key press does, including the arrow that steered onto the chip. The
/// other half of the rule — where the remote goes when the chip *vanishes* —
/// turned out to be the framework's already, and the tests here say so and
/// guard it rather than claiming credit for it.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/providers/device_info_provider.dart';
import 'package:skystream/features/player/presentation/vlc/chrome_visibility_controller.dart';
import 'package:skystream/features/player/presentation/vlc/vlc_player_controls.dart';
import 'package:skystream/features/player/presentation/widgets/player_control_components.dart'
    show PlayerActionButton;
import 'package:skystream/features/settings/presentation/player_settings_provider.dart';
import 'package:skystream/features/skip/data/skip_service.dart'
    show SkipSegment, SkipType;
import 'package:skystream/l10n/generated/app_localizations.dart';
import 'package:vlc_player/vlc_player.dart';

import 'fake_vlc_engine.dart';

/// A 1080p television at the density Android TV reports, matching the shared
/// screen harness.
const Size _tv = Size(960, 540);
const EventChannel _events = EventChannel('vlc_player/events/1');

/// Twenty minutes, so a percentage of it is a round number of milliseconds.
const int _durationMs = 1200000;

/// An intro band well away from either end.
final SkipSegment _intro = SkipSegment(
  startTime: 60,
  endTime: 90,
  type: SkipType.intro,
);

final SkipSegment _recap = SkipSegment(
  startTime: 10,
  endTime: 40,
  type: SkipType.recap,
);

/// An outro that ends *before the file does* — the anime case the advance
/// exists for. The band ends at 1060 s of 1200 s, i.e. 88.3 %, which is short
/// of the 90 % completion line PlaybackTracker judges a session by.
final SkipSegment _outroWithTail = SkipSegment(
  startTime: 1000,
  endTime: 1060,
  type: SkipType.outro,
);

/// An outro that runs right up to the end, where the band itself is already
/// past the completion line.
final SkipSegment _outroToTheEnd = SkipSegment(
  startTime: 1150,
  endTime: 1195,
  type: SkipType.outro,
);

Future<AppLocalizations> _english() =>
    AppLocalizations.delegate.load(const Locale('en'));

/// One native snapshot, on the fake's own event channel.
Future<void> _snapshot(
  WidgetTester tester, {
  String state = 'playing',
  int position = 0,
  int duration = _durationMs,
}) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        _events.name,
        _events.codec.encodeSuccessEnvelope(<String, Object?>{
          'state': state,
          'position': position,
          'duration': duration,
          'volume': 100,
          'playbackSpeed': 1.0,
          'isReady': true,
          'isSeekable': true,
          'isLive': false,
        }),
        null,
      );
  await tester.pump();
}

/// Every seekTo the engine received, as the millisecond it was asked for.
List<int> _seeks(FakeVlcEngine engine) => engine
    .callsTo('seekTo')
    .map((call) => (call.arguments as Map)['position'] as int)
    .toList(growable: false);

/// The chip's own node. Owned and labelled by the controls' State, which is
/// what makes it nameable at all — [PlayerActionButton] is otherwise a `Focus`
/// over an `InkWell` and neither carries a label.
FocusNode _chip() => FocusManager.instance.rootScope.descendants.firstWhere(
  (node) => node.debugLabel == 'player-skip-chip',
);

bool _chipExists() => FocusManager.instance.rootScope.descendants.any(
  (node) => node.debugLabel == 'player-skip-chip',
);

FocusNode get _primary => FocusManager.instance.primaryFocus!;

/// The chip's label, or null when there is no chip. Scoped to
/// [PlayerActionButton] so the bottom bar's own Next button — a
/// [PlayerIconButton] with a tooltip — can never be mistaken for it.
String? _chipLabel(WidgetTester tester) {
  final buttons = tester.widgetList<PlayerActionButton>(
    find.byType(PlayerActionButton),
  );
  return buttons.isEmpty ? null : buttons.single.label;
}

IconData? _chipIcon(WidgetTester tester) {
  final buttons = tester.widgetList<PlayerActionButton>(
    find.byType(PlayerActionButton),
  );
  return buttons.isEmpty ? null : buttons.single.icon;
}

Future<VlcPlayerController> _pumpControls(
  WidgetTester tester, {
  required FakeVlcEngine engine,
  List<SkipSegment> skipSegments = const <SkipSegment>[],
  VoidCallback? onSkipOutro,
  bool promptVisible = false,
  ValueNotifier<bool>? prompt,
  bool isTv = true,
  ChromeVisibilityController? chrome,
  Locale? locale,
}) async {
  tester.view.physicalSize = _tv;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  engine.install();
  // Tear-downs run last-in first-out: the controller goes first, while the
  // channel it sends `dispose` on still has a handler.
  addTearDown(engine.dispose);
  final controller = await engine.attach();
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        deviceProfileProvider.overrideWithValue(
          AsyncValue.data(DeviceProfile(isTv: isTv)),
        ),
        playerSettingsProvider.overrideWithBuild(
          (_, _) => const PlayerSettings(),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: prompt ?? ValueNotifier<bool>(promptVisible),
                builder: (context, raised, _) => VlcPlayerControls(
                  controller: controller,
                  chrome: chrome,
                  title: 'The Body',
                  subtitle: 'S5 E16',
                  onBack: () {},
                  onNextEpisode: () {},
                  onOpenPanel: (_) async {},
                  skipSegments: skipSegments,
                  onSkipOutro: onSkipOutro,
                  promptVisible: raised,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  // Position 0 on purpose: the controller only arms its stall watchdog once
  // the clock has moved, and a test ending in healthy playback with that timer
  // pending fails flutter_test's pending-timer check.
  await _snapshot(tester);
  // Focus assertions start with visible controls, summoned by the viewer.
  await tester.sendKeyEvent(LogicalKeyboardKey.select);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVlcEngine engine;
  setUp(() => engine = FakeVlcEngine());

  group('the Skip chip appears with the band and names it', () {
    testWidgets('and not a moment before or after', (tester) async {
      await _pumpControls(tester, engine: engine, skipSegments: [_intro]);
      final l10n = await _english();

      expect(_chipLabel(tester), isNull, reason: 'before the band');

      await _snapshot(tester, position: 65000);
      expect(_chipLabel(tester), l10n.skipIntro);

      await _snapshot(tester, position: 95000);
      expect(_chipLabel(tester), isNull, reason: 'past the band');

      await _snapshot(tester, state: 'paused', position: 95000);
    });

    testWidgets('there is no chip at all with no segments', (tester) async {
      await _pumpControls(tester, engine: engine);

      await _snapshot(tester, position: 65000);

      expect(find.byType(PlayerActionButton), findsNothing);
      expect(_chipExists(), isFalse, reason: 'and no focus stop either');

      await _snapshot(tester, state: 'paused', position: 65000);
    });

    testWidgets('the label follows the band, not the button', (tester) async {
      await _pumpControls(tester, engine: engine, skipSegments: [_recap]);
      final l10n = await _english();

      await _snapshot(tester, position: 20000);

      expect(_chipLabel(tester), l10n.skipRecap);

      await _snapshot(tester, state: 'paused', position: 20000);
    });

    // The label is read out of the localisations rather than spelled in the
    // widget, which only a non-English locale can actually prove.
    testWidgets('and is localised, not a hard-coded word', (tester) async {
      await _pumpControls(
        tester,
        engine: engine,
        skipSegments: [_intro],
        locale: const Locale('hi'),
      );
      final hi = await AppLocalizations.delegate.load(const Locale('hi'));
      final en = await _english();

      await _snapshot(tester, position: 65000);

      expect(_chipLabel(tester), hi.skipIntro);
      expect(
        find.text(en.skipIntro),
        findsNothing,
        reason: 'the English string is nowhere on a Hindi screen',
      );

      await _snapshot(tester, state: 'paused', position: 65000);
    });
  });

  group('an intro or a recap is a seek and nothing else', () {
    testWidgets('the press lands on the end of the band', (tester) async {
      await _pumpControls(tester, engine: engine, skipSegments: [_intro]);

      await _snapshot(tester, position: 65000);
      await tester.tap(find.byType(PlayerActionButton));
      await tester.pump();

      expect(_seeks(engine), <int>[90000]);

      await _snapshot(tester, state: 'paused', position: 90000);
    });

    // An outro with nothing behind it - a film, or the last episode - keeps
    // the old behaviour exactly, because there is nowhere to advance to.
    testWidgets('so is an outro with no episode after it', (tester) async {
      await _pumpControls(
        tester,
        engine: engine,
        skipSegments: [_outroWithTail],
      );
      final l10n = await _english();

      await _snapshot(tester, position: 1010000);
      expect(_chipLabel(tester), l10n.skipOutro);
      expect(_chipIcon(tester), Icons.fast_forward_rounded);

      await tester.tap(find.byType(PlayerActionButton));
      await tester.pump();

      expect(_seeks(engine), <int>[1060000], reason: 'the end of the band');

      await _snapshot(tester, state: 'paused', position: 1060000);
    });
  });

  group('Skip Outro with an episode behind it', () {
    testWidgets('says Next, because that is what it now does', (tester) async {
      var advances = 0;
      await _pumpControls(
        tester,
        engine: engine,
        skipSegments: [_outroWithTail],
        onSkipOutro: () => advances++,
      );
      final l10n = await _english();

      await _snapshot(tester, position: 1010000);

      expect(_chipLabel(tester), l10n.next);
      expect(_chipIcon(tester), Icons.skip_next_rounded);

      await tester.tap(find.byType(PlayerActionButton));
      await tester.pump();

      expect(advances, 1, reason: 'exactly once, and to the screen');

      await _snapshot(tester, state: 'paused', position: 1140000);
    });

    // OWNER DECISION 7. PlaybackTracker judges a session complete from the
    // last sample taken *while playing*, and an outro band routinely starts
    // and ends before the 90 % line - this one ends at 88.3 %. Advancing from
    // inside it would report a scrobbleStop to Trakt and Simkl where the
    // viewer earned a play, against accounts this app cannot undo.
    testWidgets('seeks past the completion line before it hands over', (
      tester,
    ) async {
      await _pumpControls(
        tester,
        engine: engine,
        skipSegments: [_outroWithTail],
        onSkipOutro: () {},
      );

      await _snapshot(tester, position: 1010000);
      await tester.tap(find.byType(PlayerActionButton));
      await tester.pump();

      expect(_seeks(engine), <int>[
        1140000,
      ], reason: '95 % of 1200 s, not the band end at 1060 s');

      await _snapshot(tester, state: 'paused', position: 1140000);
    });

    // The floor is a floor, not a target: a band that already runs past the
    // line is honoured as it stands, so a press never seeks *backwards*.
    testWidgets('a band that already runs past the line is left alone', (
      tester,
    ) async {
      await _pumpControls(
        tester,
        engine: engine,
        skipSegments: [_outroToTheEnd],
        onSkipOutro: () {},
      );

      await _snapshot(tester, position: 1160000);
      await tester.tap(find.byType(PlayerActionButton));
      await tester.pump();

      expect(_seeks(engine), <int>[1195000], reason: 'the band end, later');

      await _snapshot(tester, state: 'paused', position: 1195000);
    });

    // An intro in the same list is still an ordinary skip: the advance is the
    // outro's meaning, not the chip's.
    testWidgets('an intro in the same list is untouched by it', (tester) async {
      var advances = 0;
      await _pumpControls(
        tester,
        engine: engine,
        skipSegments: [_intro, _outroWithTail],
        onSkipOutro: () => advances++,
      );
      final l10n = await _english();

      await _snapshot(tester, position: 65000);
      expect(_chipLabel(tester), l10n.skipIntro);

      await tester.tap(find.byType(PlayerActionButton));
      await tester.pump();

      expect(_seeks(engine), <int>[90000]);
      expect(advances, 0);

      await _snapshot(tester, state: 'paused', position: 90000);
    });
  });

  group('the corner belongs to one prompt at a time', () {
    testWidgets('a prompt takes the chip away outright, not merely under it', (
      tester,
    ) async {
      await _pumpControls(
        tester,
        engine: engine,
        skipSegments: [_outroWithTail],
        onSkipOutro: () {},
        promptVisible: true,
      );

      await _snapshot(tester, position: 1010000);

      expect(find.byType(PlayerActionButton), findsNothing);
      expect(
        _chipExists(),
        isFalse,
        reason: 'an invisible focus stop inside the card is the actual bug',
      );

      await _snapshot(tester, state: 'paused', position: 1010000);
    });

    // The remote is very likely ON the chip at this exact instant - the press
    // that raised the card is the press that was aimed at it - so where it
    // goes is part of the fix rather than a nicety.
    //
    // Nothing in this file arranges that, and the measurement is the reason:
    // the framework detaches the chip's node with
    // `UnfocusDisposition.previouslyFocusedChild`, so the enclosing scope
    // hands the remote back to the chrome control that had it before the
    // viewer steered onto the chip. What must never happen is the route scope
    // or the key sink, where `bare && _isTv && _isDirectional` swallows every
    // arrow. In the real player the up-next card then takes it from there,
    // through a focus scope and autofocus of its own; skip_outro_advance_test
    // pins that end of it.
    testWidgets('and the remote does not stay on a chip that has gone', (
      tester,
    ) async {
      final prompt = ValueNotifier<bool>(false);
      addTearDown(prompt.dispose);
      await _pumpControls(
        tester,
        engine: engine,
        skipSegments: [_outroWithTail],
        onSkipOutro: () {},
        prompt: prompt,
      );
      await _snapshot(tester, position: 1010000);
      _chip().requestFocus();
      await tester.pump();
      expect(_primary.debugLabel, 'player-skip-chip');

      // The screen raised the card, exactly as pressing the chip does.
      prompt.value = true;
      await tester.pump();
      await tester.pump();

      expect(_chipExists(), isFalse);
      expect(_primary, isNot(isA<FocusScopeNode>()));
      expect(
        _primary.debugLabel,
        'player-play-pause',
        reason: 'never the scope, and never the arrow-swallowing sink',
      );

      await _snapshot(tester, state: 'paused', position: 1010000);
    });
  });

  group('the chip and the remote', () {
    // A timed button that grabs the remote the instant an intro starts is
    // worse than one you steer to: the viewer's next press would skip.
    testWidgets('a chip that appears does not take the remote', (tester) async {
      await _pumpControls(tester, engine: engine, skipSegments: [_intro]);

      await _snapshot(tester, position: 65000);
      await tester.pump();

      expect(
        _chipExists(),
        isTrue,
        reason: 'the chip is there to be steered to',
      );
      expect(_primary.debugLabel, 'player-play-pause');

      await _snapshot(tester, state: 'paused', position: 65000);
    });

    // The band runs out on its own clock, with no press to blame, and takes
    // the focused chip with it. The framework's own
    // `UnfocusDisposition.previouslyFocusedChild` covers this - the scope
    // hands the remote back to the control that had it - so this test guards
    // rather than drives: it is the only thing that would notice if the chip
    // grew a scope, an ExcludeFocus or a node it disposed early, any of which
    // would drop the remote on the key sink with the bars still up, where
    // `bare && _isTv && _isDirectional` answers every arrow with `handled` and
    // poke() on visible chrome does not notify, so nothing runs to undo it.
    testWidgets('a band that ends under the remote hands it back to '
        'play/pause', (tester) async {
      await _pumpControls(tester, engine: engine, skipSegments: [_intro]);

      await _snapshot(tester, position: 65000);
      _chip().requestFocus();
      await tester.pump();
      expect(_primary.debugLabel, 'player-skip-chip');

      await _snapshot(tester, position: 95000);
      await tester.pump();

      expect(_chipExists(), isFalse, reason: 'the band is over');
      expect(_primary, isNot(isA<FocusScopeNode>()));
      expect(_primary.debugLabel, 'player-play-pause');

      await _snapshot(tester, state: 'paused', position: 95000);
    });

    // Off a television nothing autofocused before the chip, so there is no
    // previously focused child to go back to and the sink takes it. Which is
    // the right answer there: arrows on a keyboard are seek and volume, and
    // the sink is what makes them work.
    testWidgets('off a television the sink keeps it', (tester) async {
      await _pumpControls(
        tester,
        engine: engine,
        skipSegments: [_intro],
        isTv: false,
      );

      await _snapshot(tester, position: 65000);
      _chip().requestFocus();
      await tester.pump();
      expect(_primary.debugLabel, 'player-skip-chip');

      await _snapshot(tester, position: 95000);
      await tester.pump();

      expect(_primary.debugLabel, 'player-key-sink');

      await _snapshot(tester, state: 'paused', position: 95000);
    });

    // FAILS WITHOUT THE _restoreChromeFocus CLAUSE. Every key press pokes the
    // chrome, including the arrow that steered onto the chip; the bars coming
    // up then restored focus to play/pause a frame later, and the Select the
    // viewer had aimed at Skip paused the film instead.
    testWidgets('the bars coming up do not take the remote off the chip', (
      tester,
    ) async {
      final chrome = ChromeVisibilityController(isPlaying: () => true);
      await _pumpControls(
        tester,
        engine: engine,
        skipSegments: [_intro],
        chrome: chrome,
      );

      await _snapshot(tester, position: 65000);
      _chip().requestFocus();
      await tester.pump();
      expect(_primary.debugLabel, 'player-skip-chip');

      // The bars go down around the chip, which outlives them by design.
      chrome.toggle();
      await tester.pump();
      await tester.pump();
      expect(chrome.value, isFalse);
      expect(
        _primary.debugLabel,
        'player-skip-chip',
        reason: 'the chip is outside the chrome; hiding it changes nothing',
      );

      // And come back up, which is what the next press of any key does.
      chrome.poke();
      await tester.pump();
      await tester.pump();

      expect(chrome.value, isTrue);
      expect(_primary.debugLabel, 'player-skip-chip');

      await _snapshot(tester, state: 'paused', position: 65000);
      chrome.dispose();
    });

    // The other half of the same rule: with nothing focused outside the
    // chrome, the bars coming up still put the remote back on play/pause.
    testWidgets('but they do come back to play/pause when nothing is on the '
        'chip', (tester) async {
      final chrome = ChromeVisibilityController(isPlaying: () => true);
      await _pumpControls(
        tester,
        engine: engine,
        skipSegments: [_intro],
        chrome: chrome,
      );

      await _snapshot(tester, position: 65000);
      chrome.toggle();
      await tester.pump();
      await tester.pump();
      expect(_primary.debugLabel, isNot('player-skip-chip'));

      chrome.poke();
      await tester.pump();
      await tester.pump();

      expect(_primary.debugLabel, 'player-play-pause');

      await _snapshot(tester, state: 'paused', position: 65000);
      chrome.dispose();
    });
  });
}
