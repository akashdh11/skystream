// A test's ProviderScope is its root scope; the rule only recognises one
// passed to runApp.
// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies

/// The screen lock, phone and tablet only.
///
/// A pocket, a lap or a child fires the same five screen-wide gestures a
/// viewer does: the chrome toggle, a ±10 s double-tap seek, a free horizontal
/// scrub, a vertical brightness or volume change, and a jump to 2x. The scrub
/// and the long-press are destructive and near-silent.
///
/// Locked, nothing the player owns answers a finger: not one of the five
/// gestures, not the centre play/pause, not the skip chip, and not the unlock
/// chip while it is faded out. Off touch the lock does not exist at all -
/// `VlcPlayerControls.locked` is null on a television and on a desktop, so
/// there is no padlock to render and no locked branch to reach.
///
/// Every other controls suite forces `isTv: true`, which is the build the lock
/// is absent from, so this file hosts its own phone profile.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/providers/device_info_provider.dart';
import 'package:skystream/features/player/presentation/vlc/player_rail.dart';
import 'package:skystream/features/player/presentation/vlc/vlc_player_controls.dart';
import 'package:skystream/features/player/presentation/widgets/player_control_components.dart'
    show
        PlayerActionButton,
        PlayerBottomBar,
        PlayerCenterPlayButton,
        PlayerTopBar;
import 'package:skystream/features/settings/presentation/player_settings_provider.dart';
import 'package:skystream/features/skip/data/skip_service.dart'
    show SkipSegment, SkipType;
import 'package:skystream/l10n/generated/app_localizations.dart';
import 'package:vlc_player/vlc_player.dart';

import 'fake_vlc_engine.dart';

/// A phone held sideways, which is what the player actually runs at on touch.
const Size _phone = Size(844, 390);
const Duration _hideAfter = Duration(seconds: 3);
const EventChannel _events = EventChannel('vlc_player/events/1');

/// One native snapshot, as the engine would send it.
///
/// Position 0 by default on purpose: the controller only arms its 1 s stall
/// watchdog once the clock has moved, and a test ending in healthy playback
/// with that timer pending fails flutter_test's pending-timer check.
Future<void> _snapshot(
  WidgetTester tester, {
  String state = 'playing',
  int position = 0,
  int duration = 30000,
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

Widget _host(Widget child, {required bool isTv, required bool isDesktopOS}) {
  return ProviderScope(
    overrides: [
      deviceProfileProvider.overrideWithValue(
        AsyncValue.data(DeviceProfile(isTv: isTv, isDesktopOS: isDesktopOS)),
      ),
      playerSettingsProvider.overrideWithBuild(
        (_, _) => const PlayerSettings(),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(fit: StackFit.expand, children: [child]),
      ),
    ),
  );
}

/// [desktop] sets both halves of what a desktop is, because the two are set
/// separately in production and only ever agree there: the device profile's
/// `isDesktopOS`, which is what the lock reads, and `onToggleFullscreen`.
/// [locked] null stands for "the screen offers no lock", which is what a
/// television and a desktop are handed.
Future<VlcPlayerController> _pump(
  WidgetTester tester, {
  bool isTv = false,
  bool desktop = false,
  ValueNotifier<bool>? locked,
  FakeVlcEngine? engine,
  List<SkipSegment> skipSegments = const <SkipSegment>[],
}) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final fake = engine ?? FakeVlcEngine();
  fake.install();
  // Tear-downs run last-in first-out: the controller goes first, while the
  // channel it sends `dispose` on still has a handler.
  addTearDown(fake.dispose);
  final controller = await fake.attach();
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    _host(
      VlcPlayerControls(
        controller: controller,
        title: 'The Body',
        subtitle: 'S5 E16',
        onBack: () {},
        onNextEpisode: () {},
        onToggleFullscreen: desktop ? () {} : null,
        skipSegments: skipSegments,
        locked: locked,
      ),
      isTv: isTv,
      isDesktopOS: desktop,
    ),
  );
  await tester.pump();
  // The hide clock refuses to fire until the engine reports playing.
  await _snapshot(tester);
  // The player starts hidden; reveal the controls before pressing the lock.
  await tester.sendKeyEvent(LogicalKeyboardKey.select);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
  return controller;
}

Future<AppLocalizations> _english() =>
    AppLocalizations.delegate.load(const Locale('en'));

/// The padlock in the bottom bar's left group, resolved by its tooltip - which
/// is also its semantics label.
Finder _padlock(AppLocalizations l10n) => find.byTooltip(l10n.lock);

/// The unlock chip. Resolved by its label rather than by its icon so it cannot
/// be confused with the padlock, which is a different widget entirely.
Finder _chip(AppLocalizations l10n) =>
    find.widgetWithText(PlayerActionButton, l10n.unlock);

/// Runs the chrome clock out and lets the frame that hides it settle.
Future<void> _letHide(WidgetTester tester) async {
  await tester.pump(_hideAfter);
  await tester.pump();
}

/// Every seekTo the engine received, as the millisecond it was asked for.
List<int> _seeks(FakeVlcEngine engine) => engine
    .callsTo('seekTo')
    .map((call) => (call.arguments as Map)['position'] as int)
    .toList(growable: false);

/// A tap that resolves through the screen-wide detector's double-tap
/// recogniser rather than in front of it.
Future<void> _tapAt(WidgetTester tester, Offset at) async {
  await tester.tapAt(at);
  await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
}

/// Presses a control and waits for the press to actually resolve.
///
/// A plain `pump()` is not enough anywhere in this tree: the bars sit inside
/// the controls' own gesture absorber, which registers a double-tap of its
/// own, and a double-tap recogniser holds the arena open until its timeout, so
/// a button's tap is delivered ~300 ms after the finger leaves.
Future<void> _press(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
}

/// Two taps close enough together to be one double-tap.
Future<void> _doubleTapAt(WidgetTester tester, Offset at) async {
  await tester.tapAt(at);
  await tester.pump(kDoubleTapMinTime);
  await tester.tapAt(at);
  await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
}

/// A band under the current position, so the skip chip is on screen.
List<SkipSegment> _segmentHere() => <SkipSegment>[
  SkipSegment(startTime: 0, endTime: 20, type: SkipType.intro),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the lock is absent off touch, by construction', () {
    testWidgets('a phone with a lock offered has a padlock', (tester) async {
      final locked = ValueNotifier(false);
      addTearDown(locked.dispose);
      await _pump(tester, locked: locked);

      expect(_padlock(await _english()), findsOneWidget);

      await _snapshot(tester, state: 'paused');
    });

    testWidgets('a television has none, even handed the notifier', (
      tester,
    ) async {
      // Two independent gates, and this exercises the second: the screen
      // passes null off `PlayerFormFactor.isTouch`, and the controls refuse
      // on top of that. A caller that got it wrong still gets nothing.
      final locked = ValueNotifier(false);
      addTearDown(locked.dispose);
      await _pump(tester, isTv: true, locked: locked);

      expect(
        _padlock(await _english()),
        findsNothing,
        reason: 'a remote has no accidental surface to lock against',
      );

      await _snapshot(tester, state: 'paused');
    });

    testWidgets('nor does a desktop, where the pointer is precise', (
      tester,
    ) async {
      // The lock reads the device profile, not `onToggleFullscreen`: dart:io
      // reports the host, so a screen-level test on a Mac would look like a
      // desktop whatever profile it overrode, and the lock would be
      // unreachable in every screen test. Both halves are set here because in
      // production they always agree.
      final locked = ValueNotifier(false);
      addTearDown(locked.dispose);
      await _pump(tester, desktop: true, locked: locked);

      expect(_padlock(await _english()), findsNothing);

      await _snapshot(tester, state: 'paused');
    });

    testWidgets('and a touch build offered no lock has no padlock either', (
      tester,
    ) async {
      // With `locked` null there is nothing to render from at all.
      await _pump(tester);

      expect(_padlock(await _english()), findsNothing);

      await _snapshot(tester, state: 'paused');
    });
  });

  group('locked', () {
    /// Locks through the padlock, the way a viewer does.
    Future<void> lock(WidgetTester tester) async {
      await _press(tester, _padlock(await _english()));
    }

    testWidgets('locking swallows every screen-wide gesture', (tester) async {
      // All five gestures the player owns are registered on one screen-wide
      // GestureDetector, and locking rebuilds that detector with a bare onTap.
      // Each is checked against what reached the engine, not against what is
      // on screen: a guard that merely hid the readout would leave the seek.
      final engine = FakeVlcEngine();
      final locked = ValueNotifier(false);
      addTearDown(locked.dispose);
      await _pump(tester, locked: locked, engine: engine);
      await _snapshot(tester, position: 5000);
      await lock(tester);
      expect(locked.value, isTrue);

      final rect = tester.getRect(find.byType(VlcPlayerControls));
      final centre = rect.center;
      final right = Offset(rect.left + rect.width * 0.8, rect.center.dy);

      // 1. The chrome toggle. The bars are not built at all while locked, so
      //    this asks the stronger question: nothing put them back.
      await _tapAt(tester, centre);
      expect(find.byType(PlayerTopBar), findsNothing);
      expect(find.byType(PlayerBottomBar), findsNothing);

      // 2. The double-tap seek.
      await _doubleTapAt(tester, right);
      expect(
        _seeks(engine),
        isEmpty,
        reason: 'a pocket must not move the film ten seconds',
      );

      // 3. The horizontal scrub - the most destructive of the five, because
      //    it is a free seek to anywhere in the file.
      await tester.dragFrom(centre, const Offset(300, 0));
      await tester.pump(const Duration(milliseconds: 50));
      expect(_seeks(engine), isEmpty, reason: 'nor a free scrub');

      // 4. The vertical rail. On the right half that is volume, which reaches
      //    the engine, so both the readout and the effect are checkable.
      await tester.dragFrom(right, const Offset(0, -100));
      await tester.pump(const Duration(milliseconds: 50));
      expect(engine.callsTo('setVolume'), isEmpty);
      expect(find.byType(PlayerRail), findsNothing);

      // 5. The long-press speed boost.
      await tester.longPressAt(centre);
      await tester.pump(const Duration(milliseconds: 50));
      expect(engine.callsTo('setPlaybackSpeed'), isEmpty);

      // And the centre play/pause, which is outside the bars and would
      // otherwise still be up and hit-testable whenever a poke revealed the
      // chrome.
      expect(find.byType(PlayerCenterPlayButton), findsNothing);
      expect(engine.callsTo('pause'), isEmpty);

      expect(locked.value, isTrue, reason: 'none of that unlocked anything');
      await _snapshot(tester, state: 'paused', position: 5000);
    });

    testWidgets('and every one of them fires when it is not locked', (
      tester,
    ) async {
      // The control for the test above: without it a typo in any of the five
      // gesture drivers would read as a green lock.
      final engine = FakeVlcEngine();
      final locked = ValueNotifier(false);
      addTearDown(locked.dispose);
      await _pump(tester, locked: locked, engine: engine);
      await _snapshot(tester, position: 5000);

      final rect = tester.getRect(find.byType(VlcPlayerControls));
      final centre = rect.center;
      final right = Offset(rect.left + rect.width * 0.8, rect.center.dy);

      await _doubleTapAt(tester, right);
      expect(_seeks(engine), isNotEmpty, reason: 'the double-tap seek works');

      // So soon after the double-tap, the scrub's seek is merged with it and
      // reaches the engine once the seeks stop - read at the end.
      await tester.dragFrom(centre, const Offset(300, 0));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.dragFrom(right, const Offset(0, -100));
      await tester.pump(const Duration(milliseconds: 50));
      expect(engine.callsTo('setVolume'), isNotEmpty);

      await tester.longPressAt(centre);
      await tester.pump(const Duration(milliseconds: 50));
      expect(engine.callsTo('setPlaybackSpeed'), isNotEmpty);

      expect(find.byType(PlayerCenterPlayButton), findsOneWidget);
      await tester.pump(VlcPlayerController.seekMergeWindow);
      expect(_seeks(engine), hasLength(greaterThan(1)), reason: 'the scrub');
      await _snapshot(tester, state: 'paused', position: 5000);
    });

    testWidgets('a tap while locked shows only the unlock chip', (
      tester,
    ) async {
      // A segment under the position, so the skip chip is on screen. It lives
      // outside the chrome gate, so hiding the bars does not take it away and
      // the lock has to withdraw it by name.
      final locked = ValueNotifier(false);
      addTearDown(locked.dispose);
      await _pump(tester, locked: locked, skipSegments: _segmentHere());
      final l10n = await _english();
      await _snapshot(tester, position: 5000);
      expect(
        find.widgetWithText(PlayerActionButton, l10n.skipIntro),
        findsOneWidget,
        reason: 'otherwise the assertion below proves nothing',
      );

      await lock(tester);
      await _letHide(tester);
      await _tapAt(tester, tester.getCenter(find.byType(VlcPlayerControls)));

      expect(_chip(l10n), findsOneWidget);
      expect(find.byType(PlayerTopBar), findsNothing);
      expect(find.byType(PlayerBottomBar), findsNothing);
      expect(
        find.widgetWithText(PlayerActionButton, l10n.skipIntro),
        findsNothing,
        reason: 'the skip chip is outside the chrome and would have survived',
      );

      await _snapshot(tester, state: 'paused', position: 5000);
    });

    testWidgets('the chip rides the chrome clock', (tester) async {
      // No second timer and no second opacity controller: the chip goes
      // through the same `_fading` the bars do, so it appears on a touch and
      // leaves on the same three seconds. Read off the fade's target so this
      // does not depend on the animation.
      final locked = ValueNotifier(false);
      addTearDown(locked.dispose);
      await _pump(tester, locked: locked);
      final l10n = await _english();
      await lock(tester);

      double opacity() => tester
          .widget<AnimatedOpacity>(
            find.ancestor(
              of: _chip(l10n),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity;

      expect(opacity(), 1.0, reason: 'the press that locked also poked');

      await _letHide(tester);
      expect(opacity(), 0.0);
      expect(locked.value, isTrue, reason: 'faded out is not unlocked');

      await _tapAt(tester, tester.getCenter(find.byType(VlcPlayerControls)));
      expect(opacity(), 1.0, reason: 'a touch brings the one control back');

      await _snapshot(tester, state: 'paused');
    });

    testWidgets('a faded-out chip does not answer a touch', (tester) async {
      // `AnimatedOpacity` at zero paints nothing and still hit-tests. Without
      // an IgnorePointer of its own the chip would be an invisible target at
      // the bottom of a locked screen for the first accidental contact to hit.
      final locked = ValueNotifier(false);
      addTearDown(locked.dispose);
      await _pump(tester, locked: locked);
      final l10n = await _english();
      await lock(tester);

      final at = tester.getCenter(_chip(l10n));
      await _letHide(tester);
      await _tapAt(tester, at);

      expect(
        locked.value,
        isTrue,
        reason: 'an invisible chip must not unlock the screen',
      );

      await _snapshot(tester, state: 'paused');
    });

    testWidgets('the chip gives the player back', (tester) async {
      final engine = FakeVlcEngine();
      final locked = ValueNotifier(false);
      addTearDown(locked.dispose);
      await _pump(tester, locked: locked, engine: engine);
      final l10n = await _english();
      await _snapshot(tester, position: 5000);
      await lock(tester);

      await _press(tester, _chip(l10n));

      expect(locked.value, isFalse);
      expect(_chip(l10n), findsNothing);
      expect(find.byType(PlayerBottomBar), findsOneWidget);
      expect(_padlock(l10n), findsOneWidget, reason: 'and can be locked again');

      // The gestures are back with it, which is the half a findsOneWidget
      // cannot see.
      await tester.dragFrom(
        tester.getCenter(find.byType(VlcPlayerControls)),
        const Offset(300, 0),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(_seeks(engine), isNotEmpty);

      await _snapshot(tester, state: 'paused', position: 5000);
    });

    testWidgets('the chip answers a game controller A', (tester) async {
      // The lock is touch-only, but the chip is a [PlayerActionButton] and
      // every player control that takes Select has to take a pad's A as well -
      // an Android phone with a controller paired sends it.
      final locked = ValueNotifier(false);
      addTearDown(locked.dispose);
      await _pump(tester, locked: locked);
      await lock(tester);

      // [PlayerActionButton] wraps an [InkWell] in a [Focus] and the InkWell
      // makes a node of its own, so the button owns two focus stops at
      // identical geometry. Either will do: the key handler lives on the outer
      // wrapper, and an event the focused node does not claim bubbles up to
      // it. Resolved from the icon upwards because neither node carries a
      // label.
      final node = Focus.of(tester.element(find.byIcon(Icons.lock_rounded)));
      node.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
      await tester.pump();

      expect(locked.value, isFalse);

      await _snapshot(tester, state: 'paused');
    });
  });
}
