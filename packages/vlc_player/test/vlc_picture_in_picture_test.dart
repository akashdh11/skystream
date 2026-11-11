import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_player/vlc_player.dart';

import 'vlc_method_channel_harness.dart';

/// Picture-in-picture holds the background pause off, and never strands the
/// viewer with a stopped film.
///
/// The bug this file holds shut: pressing Home while a film played paused
/// libVLC (the default `pause` policy) before any PiP window could open, so
/// no window ever appeared; and tapping the PiP button left the screen
/// unresponsive, because the attempt's answer never arrived and the pause
/// the attempt had held off was never applied either. The pause is deferred
/// to the end of the attempt, not dropped.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VlcMethodChannelHarness harness;

  setUp(() {
    // The native PiP opens, unless a test says otherwise.
    harness = VlcMethodChannelHarness()
      ..install(
        onCall: (call) async {
          if (call.method == 'create') return 1;
          if (call.method == 'startPictureInPicture') return true;
          return null;
        },
      );
  });

  tearDown(() async {
    // Leave the binding where every test expects to find it, or the next one
    // inherits a hidden app and AppLifecycleListener asserts on the sequence.
    await setAppLifecycleState(AppLifecycleState.resumed);
    harness.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  /// An attached controller reporting playback, which is the only state in
  /// which the policy has anything to do.
  Future<VlcPlayerController> playing() async {
    final controller = VlcPlayerController(
      config: const VlcPlayerConfig(
        backgroundPolicy: VlcBackgroundPolicy.pause,
      ),
    );
    harness.mockEventChannel(1);
    await harness.attachController(controller, 1);
    await harness.sendEvent(1, <String, Object?>{
      'state': 'playing',
      'position': 30000,
      'duration': 3600000,
      'isReady': true,
    });
    harness.calls.clear();
    return controller;
  }

  List<String> methodsOn(VlcMethodChannelHarness harness) =>
      harness.calls.map((call) => call.method).toList();

  /// A PiP start the native side answers by opening the window.
  Future<VlcPlayerController> attempting() async {
    final controller = await playing();
    expect(await controller.startPictureInPicture(), isTrue);
    harness.calls.clear();
    return controller;
  }

  group('a PiP attempt in flight', () {
    test('holds the background pause off until the attempt answers',
        () async {
      final controller = await attempting();
      addTearDown(controller.dispose);

      await setAppLifecycleState(AppLifecycleState.paused);
      expect(methodsOn(harness), isEmpty);

      // The window failed to open: the pause the attempt held off lands.
      await harness.sendEvent(1, {'pictureInPicture': false});
      expect(methodsOn(harness), <String>['pause']);
    });

    test('a native refusal is an ordinary background pause', () async {
      // Reinstall the mock so the native side refuses.
      harness.dispose();
      harness = VlcMethodChannelHarness()
        ..install(
          onCall: (call) async => call.method == 'create' ? 1 : false,
        );
      final controller = await playing();
      addTearDown(controller.dispose);
      expect(await controller.startPictureInPicture(), isFalse);
      harness.calls.clear();

      await setAppLifecycleState(AppLifecycleState.paused);
      expect(methodsOn(harness), <String>['pause']);
    });

    test('a stop while away applies the held-off pause', () async {
      final controller = await attempting();
      addTearDown(controller.dispose);
      await setAppLifecycleState(AppLifecycleState.paused);
      expect(methodsOn(harness), isEmpty);

      await controller.stopPictureInPicture();
      // The pause lands before the stop reaches the native side.
      expect(
        methodsOn(harness),
        <String>['pause', 'stopPictureInPicture'],
      );
    });
  });

  group('an open PiP window', () {
    test('holds the pause off while the window is up', () async {
      final controller = await attempting();
      addTearDown(controller.dispose);
      await harness.sendEvent(1, {'pictureInPicture': true});

      await setAppLifecycleState(AppLifecycleState.paused);
      expect(methodsOn(harness), isEmpty);

      // The window closed while the app was away: pause.
      await harness.sendEvent(1, {'pictureInPicture': false});
      expect(methodsOn(harness), <String>['pause']);
    });
  });

  group('a second PiP attempt after the first window closed', () {
    test('starts again and holds the pause off', () async {
      // The bug this holds shut: the native side tore the PiP controller
      // down when the first window closed, so a second Home swipe rebuilt
      // it too late and no window opened — works, fails, works, fails.
      // The controller must go out to native again, and the pause must
      // hold off for the second attempt exactly as it did for the first.
      final controller = await attempting();
      addTearDown(controller.dispose);
      // The first window opened, then the viewer came back.
      await harness.sendEvent(1, {'pictureInPicture': true});
      await harness.sendEvent(1, {'pictureInPicture': false});
      harness.calls.clear();

      expect(await controller.startPictureInPicture(), isTrue);
      expect(
        methodsOn(harness),
        <String>['startPictureInPicture'],
        reason: 'the second attempt never reached the native side',
      );

      await setAppLifecycleState(AppLifecycleState.paused);
      expect(methodsOn(harness), <String>['startPictureInPicture']);

      // And the second window failing to open lands the pause, as before.
      await harness.sendEvent(1, {'pictureInPicture': false});
      expect(
        methodsOn(harness),
        <String>['startPictureInPicture', 'pause'],
      );
    });
  });

  group('startPictureInPicture source rect', () {
    test('sends the video picture rect to native', () async {
      final controller = await playing();
      addTearDown(controller.dispose);
      // A 16:9 picture letterboxed in a portrait phone: the band the
      // viewer actually sees, which the window opens from.
      const rect = Rect.fromLTWH(0, 312, 390, 219);
      expect(await controller.startPictureInPicture(sourceRect: rect), isTrue);
      final call = harness.calls.singleWhere(
        (call) => call.method == 'startPictureInPicture',
      );
      // viewId rides along on every native call; the rect is the new part.
      expect(call.arguments, <String, Object?>{
        'viewId': 1,
        'x': 0.0,
        'y': 312.0,
        'width': 390.0,
        'height': 219.0,
      });
    });

    test('sends no rect when none is given', () async {
      final controller = await playing();
      addTearDown(controller.dispose);
      expect(await controller.startPictureInPicture(), isTrue);
      final call = harness.calls.singleWhere(
        (call) => call.method == 'startPictureInPicture',
      );
      expect(call.arguments, <String, Object?>{'viewId': 1});
    });
  });

  group('stopPictureInPicture', () {
    test('is best effort on a platform with no native stop', () async {
      // Android answers notImplemented: its PiP is an activity mode. A stop
      // must never surface as an error far from the call site.
      harness.dispose();
      harness = VlcMethodChannelHarness()
        ..install(
          onCall: (call) async {
            if (call.method == 'create') return 1;
            if (call.method == 'stopPictureInPicture') {
              throw MissingPluginException();
            }
            return null;
          },
        );
      final controller = await playing();
      addTearDown(controller.dispose);
      await expectLater(controller.stopPictureInPicture(), completes);
    });
  });

  group('setDurationCap', () {
    test('forwards the measured HLS length to native for the PiP window',
        () async {
      // The bug this holds shut: the app measures an HLS film's true
      // length off its own playlist (libVLC reports the longest
      // rendition, subtitle tracks included) and caps the in-app
      // timeline with it — but the PiP window never learned it, so it
      // read the film as a live stream (LIVE badge, no seek, a progress
      // line stuck at the start). The cap must reach the native side too.
      final controller = await playing();
      addTearDown(controller.dispose);
      harness.calls.clear();

      controller.setDurationCap(const Duration(minutes: 94, seconds: 17));
      // The forward is fire-and-forget; let it land.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final call = harness.calls.singleWhere(
        (call) => call.method == 'setDurationCap',
      );
      expect(call.arguments, <String, Object?>{
        'viewId': 1,
        'milliseconds': 5657000,
      });
    });

    test('clearing the cap clears it natively too', () async {
      final controller = await playing();
      addTearDown(controller.dispose);
      controller.setDurationCap(const Duration(minutes: 94, seconds: 17));
      harness.calls.clear();

      controller.setDurationCap(null);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final call = harness.calls.singleWhere(
        (call) => call.method == 'setDurationCap',
      );
      expect(call.arguments, <String, Object?>{
        'viewId': 1,
        'milliseconds': null,
      });
    });
  });
}
