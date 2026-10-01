import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/features/player/presentation/vlc/chrome_visibility_controller.dart';

/// Driven under the widget-test binding purely for its fake clock: the
/// controller is plain Dart with a Timer, and `tester.pump(duration)` is the
/// one clock this package already depends on. No widgets are built.
const Duration _hideAfter = Duration(seconds: 3);
const Duration _tick = Duration(milliseconds: 1);

void main() {
  late bool playing;
  late int notifications;

  /// Built inside each test body, not in setUp: the controller arms its first
  /// timer in its constructor, and the fake clock exists only inside the body.
  ChromeVisibilityController armed({bool initiallyVisible = true}) {
    final chrome = ChromeVisibilityController(
      isPlaying: () => playing,
      hideAfter: _hideAfter,
      initiallyVisible: initiallyVisible,
    )..addListener(() => notifications++);
    addTearDown(chrome.dispose);
    return chrome;
  }

  setUp(() {
    playing = true;
    notifications = 0;
  });

  testWidgets('default controller starts hidden for immersion', (
    tester,
  ) async {
    final chrome = armed(initiallyVisible: false);
    expect(chrome.value, isFalse);
    expect(notifications, 0);
  });

  testWidgets('born visible and armed: hides once the delay runs out', (
    tester,
  ) async {
    final chrome = armed();
    expect(chrome.value, isTrue);
    await tester.pump(_hideAfter - _tick);
    expect(chrome.value, isTrue);
    await tester.pump(_tick);
    expect(chrome.value, isFalse);
    expect(notifications, 1);
  });

  testWidgets('never hides while paused, and hides once playback resumes', (
    tester,
  ) async {
    final chrome = armed();
    playing = false;
    await tester.pump(_hideAfter * 5);
    expect(chrome.value, isTrue, reason: 'paused viewers are looking');

    // The clock re-checks rather than hiding on a schedule, so resuming is
    // noticed within one more period.
    playing = true;
    await tester.pump(_hideAfter);
    expect(chrome.value, isFalse);
  });

  testWidgets('poke restarts the clock from now', (tester) async {
    final chrome = armed();
    await tester.pump(_hideAfter - _tick);
    chrome.poke();
    await tester.pump(_hideAfter - _tick);
    expect(chrome.value, isTrue, reason: 'the poke bought a full period');
    await tester.pump(_tick);
    expect(chrome.value, isFalse);
  });

  testWidgets('poke reveals hidden chrome and arms it', (tester) async {
    final chrome = armed();
    await tester.pump(_hideAfter);
    expect(chrome.value, isFalse);

    chrome.poke();
    expect(chrome.value, isTrue);
    await tester.pump(_hideAfter);
    expect(chrome.value, isFalse);
  });

  testWidgets('a hold pins the chrome; release re-arms it', (tester) async {
    final chrome = armed();
    chrome.poke(hold: true);
    await tester.pump(_hideAfter * 5);
    expect(chrome.value, isTrue, reason: 'held chrome does not hide');
    expect(chrome.isHeld, isTrue);

    chrome.release();
    expect(chrome.isHeld, isFalse);
    await tester.pump(_hideAfter - _tick);
    expect(chrome.value, isTrue, reason: 'release starts a fresh period');
    await tester.pump(_tick);
    expect(chrome.value, isFalse);
  });

  testWidgets('holds nest: the last release is the one that re-arms', (
    tester,
  ) async {
    final chrome = armed();
    chrome.poke(hold: true);
    chrome.poke(hold: true);
    chrome.release();
    await tester.pump(_hideAfter * 2);
    expect(chrome.value, isTrue, reason: 'one hold is still outstanding');

    chrome.release();
    await tester.pump(_hideAfter);
    expect(chrome.value, isFalse);
  });

  testWidgets('whileHeld holds for the life of the future', (tester) async {
    final chrome = armed();
    final sheet = chrome.whileHeld(() => Future<void>.delayed(_hideAfter * 3));

    await tester.pump(_hideAfter * 2);
    expect(chrome.value, isTrue, reason: 'the sheet is still open');

    await tester.pump(_hideAfter);
    await sheet;
    expect(chrome.isHeld, isFalse);
    await tester.pump(_hideAfter);
    expect(chrome.value, isFalse, reason: 'closing re-armed the clock');
  });

  testWidgets('toggle hides at once, even when paused, and reveals armed', (
    tester,
  ) async {
    final chrome = armed();
    playing = false;
    chrome.toggle();
    expect(
      chrome.value,
      isFalse,
      reason: 'an explicit tap is the viewer\'s choice',
    );

    chrome.toggle();
    expect(chrome.value, isTrue);
    playing = true;
    await tester.pump(_hideAfter);
    expect(chrome.value, isFalse);
  });

  testWidgets('toggle does not hide held chrome', (tester) async {
    final chrome = armed();
    chrome.poke(hold: true);
    chrome.toggle();
    expect(chrome.value, isTrue);
  });

  testWidgets('keepAlive restarts visible chrome but never reveals it', (
    tester,
  ) async {
    final chrome = armed();
    await tester.pump(_hideAfter - _tick);
    chrome.keepAlive();
    await tester.pump(_tick);
    expect(chrome.value, isTrue, reason: 'restarted');

    await tester.pump(_hideAfter);
    expect(chrome.value, isFalse);
    chrome.keepAlive();
    await tester.pump(_hideAfter);
    expect(chrome.value, isFalse, reason: 'a pointer-down must not re-show');
  });

  group('a screen reader keeps the bars up', () {
    /// The bit `MediaQuery.accessibleNavigationOf` reports, faked at the same
    /// place the real thing comes from: `PlatformDispatcher.accessibilityFeatures`.
    void screenReader(WidgetTester tester, {required bool on}) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(accessibleNavigation: on);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }

    testWidgets('the clock never arms while one is driving', (tester) async {
      screenReader(tester, on: true);

      // Exploration is swipes and flicks, which reach Flutter as no pointer
      // event at all: nothing here would ever be poked, so an armed clock
      // takes the bars - and with them every control in the accessibility
      // tree - out from under the person reading them.
      final chrome = armed();
      await tester.pump(_hideAfter * 5);
      expect(chrome.value, isTrue);
      expect(notifications, 0);

      // Reaching a control and using it must not arm one either.
      chrome.poke();
      chrome.keepAlive();
      await tester.pump(_hideAfter * 5);
      expect(chrome.value, isTrue);
    });

    testWidgets('turning one on mid-film disarms the clock already running', (
      tester,
    ) async {
      final chrome = armed();
      await tester.pump(_hideAfter - _tick);

      screenReader(tester, on: true);
      await tester.pump(_tick);
      expect(chrome.value, isTrue, reason: 'the armed clock declined to hide');

      await tester.pump(_hideAfter * 5);
      expect(chrome.value, isTrue, reason: 'and did not re-arm');
    });

    testWidgets('an explicit tap still dismisses them', (tester) async {
      screenReader(tester, on: true);

      // Hiding is the viewer's own choice here, and a second tap brings the
      // bars back - the same escape a sighted viewer has.
      final chrome = armed();
      chrome.toggle();
      expect(chrome.value, isFalse);
      chrome.toggle();
      expect(chrome.value, isTrue);
      await tester.pump(_hideAfter * 5);
      expect(chrome.value, isTrue);
    });

    testWidgets('turning one off hands the clock back', (tester) async {
      screenReader(tester, on: true);
      final chrome = armed();
      await tester.pump(_hideAfter * 2);
      expect(chrome.value, isTrue);

      screenReader(tester, on: false);
      chrome.poke();
      await tester.pump(_hideAfter);
      expect(chrome.value, isFalse, reason: 'ordinary behaviour is restored');
    });
  });

  testWidgets('notifies exactly once per visibility change', (tester) async {
    final chrome = armed();
    chrome.poke();
    chrome.poke();
    chrome.keepAlive();
    expect(notifications, 0, reason: 'visible stayed visible');

    await tester.pump(_hideAfter);
    expect(notifications, 1);

    chrome.poke();
    chrome.poke();
    expect(notifications, 2);

    await tester.pump(_hideAfter);
    expect(notifications, 3);
  });
}
