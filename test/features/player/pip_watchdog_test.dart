import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/features/player/presentation/vlc/vlc_player_controls.dart';
import 'package:skystream/features/player/presentation/widgets/player_control_components.dart'
    show PlayerActionButton;

import 'fake_vlc_engine.dart';
import 'vlc_screen_harness.dart';

/// A PiP start the system never answers must not freeze the player, and
/// leaving the app while a film plays must float it.
///
/// The bug this file holds shut: tapping the PiP button left the screen
/// unresponsive until the app was backgrounded and foregrounded again,
/// because the button set the "in PiP" flag before the native request went
/// out - which unmounts the whole controls subtree - and a start the system
/// silently dropped never sent the event that would clear it. And pressing
/// Home did nothing at all, because nothing asked for PiP on the way out
/// and the background policy paused the film instead.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The native side of the platform PiP channel: how many times the app
  /// asked to enter PiP. Answers true, which is a request gone out, not a
  /// window opened - the window opening, or failing to, is reported through
  /// the engine's `pictureInPicture` event.
  late List<MethodCall> pipCalls;

  setUp(() {
    installEngineMocks();
    pipCalls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      return null;
    });
    messenger.setMockMethodCallHandler(pipChannel, (call) async {
      pipCalls.add(call);
      if (call.method == 'enterPip') return true;
      return null;
    });
  });

  tearDown(() {
    removeEngineMocks();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    debugDefaultTargetPlatformOverride = null;
  });

  /// A phone playing a film, on the Android platform override: the PiP
  /// button only exists where the platform can do PiP, and the texture
  /// renderer is read once in initState, so switching the override after
  /// the screen has reached the playing stage cannot change the video path.
  /// The override itself marks nothing dirty, so the screen never re-reads
  /// the PiP gate on the next frame: the Rotate button is the rebuild that
  /// costs nothing - it flips the handset for this video and re-runs build,
  /// which is when the PiP button appears.
  Future<void> pumpPhonePlaying(WidgetTester tester) async {
    await pumpPlayer(tester, isTv: false);
    await sendFirstFrame(tester);
    expect(find.byType(VlcPlayerControls), findsOneWidget);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.tap(find.byTooltip('Rotate'));
    await tester.pump();
    expect(find.byTooltip('PiP'), findsOneWidget);
  }

  /// Keeps the film playing while the fake clock advances: one advancing
  /// position per 400 ms, which is also what keeps the stall watchdog quiet.
  Future<void> keepPlaying(WidgetTester tester, int steps) async {
    for (var i = 0; i < steps; i++) {
      await sendEvent(tester, snapshot(position: 1500 + (i + 1) * 1000));
    }
  }

  testWidgets(
    'a PiP attempt the system never answers takes the chrome back',
    variant: texturePlatform,
    (tester) async {
      await pumpPhonePlaying(tester);

      await tester.tap(find.byTooltip('PiP'));
      await tester.pump();
      expect(
        pipCalls.map((call) => call.method),
        <String>['enterPip'],
        reason: 'the button never asked the platform to open PiP',
      );
      expect(
        find.byType(VlcPlayerControls),
        findsNothing,
        reason: 'the chrome stayed up after the request went out',
      );

      // The window never opens and no event ever arrives: the film keeps
      // playing, past the five-second watchdog, and the chrome comes back.
      // Five seconds, not two: the native side's own three-second timeout
      // must report first, so the watchdog is only the backstop.
      await keepPlaying(tester, 13);
      await tester.pump();
      expect(
        find.byType(VlcPlayerControls),
        findsOneWidget,
        reason:
            'a silently dropped PiP start left the player with no touch '
            'handling at all',
      );

      // The watchdog also tells the viewer the attempt failed, and that
      // toast's own dismiss timer (three seconds) must run out before the
      // tree is disposed, or the test ends with a timer still pending.
      await tester.pump(const Duration(seconds: 4));

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a PiP window that opens keeps the chrome off',
    variant: texturePlatform,
    (tester) async {
      await pumpPhonePlaying(tester);

      await tester.tap(find.byTooltip('PiP'));
      await tester.pump();
      expect(find.byType(VlcPlayerControls), findsNothing);

      // The window opened: the engine says so, which stands the watchdog
      // down. The film keeps playing past five seconds and the chrome stays
      // off - the window, not the screen, is showing the film now.
      await sendEvent(tester, <String, Object?>{'pictureInPicture': true});
      await keepPlaying(tester, 13);
      await tester.pump();
      expect(
        find.byType(VlcPlayerControls),
        findsNothing,
        reason: 'the watchdog fired on a window that had opened fine',
      );

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'leaving the app while playing floats the video',
    variant: texturePlatform,
    (tester) async {
      await pumpPhonePlaying(tester);

      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      await tester.pump();
      expect(
        pipCalls.map((call) => call.method),
        <String>['enterPip'],
        reason: 'going Home never asked for PiP',
      );
      expect(
        find.byType(VlcPlayerControls),
        findsNothing,
        reason: 'the chrome stayed up after leaving the app',
      );

      // Coming back closes the attempt and brings the chrome with it.
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pump();
      expect(find.byType(VlcPlayerControls), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'on iOS, a transient inactive (Control Center) starts no PiP and keeps the lock',
    variant: texturePlatform,
    (tester) async {
      // iOS before pumping: the screen reads the platform in initState
      // and build (the PiP gate and the texture renderer), so the
      // override has to be in place before the screen is stood up.
      // Android keeps the `inactive` -> enterPip path (the test above);
      // iOS must not start PiP for a transient overlay, which re-frames
      // the video and clears the lock for a window that never opens.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final engine = FakeVlcEngine();
      installEngineMocks(engine: engine);
      await pumpPlayer(tester, isTv: false);
      await sendFirstFrame(tester);
      expect(find.byType(VlcPlayerControls), findsOneWidget);

      // The PiP button is only there where the platform can do PiP; the
      // Rotate tap re-runs build, which is when it appears (see
      // pumpPhonePlaying above).
      await tester.tap(find.byTooltip('Rotate'));
      await tester.pump();
      expect(find.byTooltip('PiP'), findsOneWidget);

      // Lock the player: the padlock, then the unlock chip in place of
      // the chrome.
      await tester.tap(find.byTooltip('Lock'));
      await tester.pump();
      expect(
        find.widgetWithText(PlayerActionButton, 'Unlock'),
        findsOneWidget,
        reason: 'the padlock did not lock the player',
      );

      // Control Center: a transient inactive. No PiP request goes out,
      // the lock stays engaged, and the chrome is not unmounted (the
      // video is not re-framed).
      engine.calls.clear();
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      await tester.pump();
      expect(
        engine.callsTo('startPictureInPicture'),
        isEmpty,
        reason: 'Control Center asked for PiP',
      );
      expect(find.byType(VlcPlayerControls), findsOneWidget);
      expect(
        find.widgetWithText(PlayerActionButton, 'Unlock'),
        findsOneWidget,
        reason: 'Control Center cleared the lock',
      );

      // Closing Control Center: still locked, and still no PiP request.
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pump();
      expect(
        find.widgetWithText(PlayerActionButton, 'Unlock'),
        findsOneWidget,
        reason: 'returning from Control Center cleared the lock',
      );
      expect(engine.callsTo('startPictureInPicture'), isEmpty);

      await tester.pumpWidget(const SizedBox());
    },
  );
}
