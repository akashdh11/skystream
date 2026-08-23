import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_player/vlc_player.dart';

import 'vlc_method_channel_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VlcMethodChannelHarness harness;

  Map<String, Object?> playbackEvent({
    String state = 'playing',
    int position = 0,
    int duration = 30000,
    double? bufferingProgress,
  }) {
    final event = <String, Object?>{
      'state': state,
      'position': position,
      'duration': duration,
      'volume': 100,
      'playbackSpeed': 1.0,
      'isReady': true,
      'isSeekable': true,
      'isLive': false,
      'videoSize': <String, Object?>{'width': 640, 'height': 360},
    };
    if (bufferingProgress != null) {
      event['bufferingProgress'] = bufferingProgress;
    }
    return event;
  }

  setUp(() {
    harness = VlcMethodChannelHarness()..install();
  });

  tearDown(() {
    harness.dispose();
  });

  test('repeated native events keep listener notifications bounded', () async {
    final controller = VlcPlayerController();
    harness.mockEventChannel(41);
    await harness.attachController(controller, 41);

    var notifications = 0;
    controller.addListener(() {
      notifications += 1;
    });

    await harness.sendEvents(
      41,
      List<Map<String, Object?>>.generate(120, (index) {
        final position = (index ~/ 3) * 250;
        return playbackEvent(position: position);
      }),
    );

    expect(notifications, 40);

    controller.dispose();
  });

  test('event channel errors notify once for equivalent payloads', () async {
    final controller = VlcPlayerController();
    harness.mockEventChannel(42);
    await harness.attachController(controller, 42);

    var notifications = 0;
    controller.addListener(() {
      notifications += 1;
    });

    await harness.sendError(
      42,
      code: VlcPlayerErrorCode.playbackError,
      message: 'Decoder failed.',
      details: const <String, Object?>{'codec': 'h264'},
    );
    await harness.sendError(
      42,
      code: VlcPlayerErrorCode.playbackError,
      message: 'Decoder failed.',
      details: const <String, Object?>{'codec': 'h264'},
    );

    expect(notifications, 1);
    expect(controller.value.hasError, isTrue);
    expect(controller.value.errorDescription, 'Decoder failed.');

    controller.dispose();
  });

  test('negative event throttle intervals fail fast', () {
    expect(
      () => VlcPlayerController(
        eventThrottleInterval: const Duration(microseconds: -1),
      ),
      throwsArgumentError,
    );
  });

  test('default event delivery does not throttle progress updates', () async {
    final controller = VlcPlayerController();
    harness.mockEventChannel(43);
    await harness.attachController(controller, 43);

    var notifications = 0;
    controller.addListener(() {
      notifications += 1;
    });

    await harness.sendEvent(43, playbackEvent(position: 0));
    await harness.sendEvent(43, playbackEvent(position: 250));
    await harness.sendEvent(43, playbackEvent(position: 500));

    expect(notifications, 3);
    expect(controller.value.position, const Duration(milliseconds: 500));

    controller.dispose();
  });

  testWidgets('event throttling coalesces progress-only updates', (
    tester,
  ) async {
    final controller = VlcPlayerController(
      eventThrottleInterval: const Duration(milliseconds: 100),
    );
    harness.mockEventChannel(44);
    await harness.attachController(controller, 44);
    await harness.sendEvent(44, playbackEvent(position: 0));

    var notifications = 0;
    controller.addListener(() {
      notifications += 1;
    });

    await harness.sendEvents(44, <Map<String, Object?>>[
      playbackEvent(position: 250),
      playbackEvent(position: 500),
      playbackEvent(position: 750),
    ]);

    expect(notifications, 0);
    expect(controller.value.position, Duration.zero);

    await tester.pump(const Duration(milliseconds: 99));
    expect(notifications, 0);

    await tester.pump(const Duration(milliseconds: 1));
    expect(notifications, 1);
    expect(controller.value.position, const Duration(milliseconds: 750));

    controller.dispose();
  });

  testWidgets('critical events bypass throttling and cancel pending progress', (
    tester,
  ) async {
    final controller = VlcPlayerController(
      eventThrottleInterval: const Duration(milliseconds: 100),
    );
    harness.mockEventChannel(45);
    await harness.attachController(controller, 45);
    await harness.sendEvent(45, playbackEvent(position: 0));

    var notifications = 0;
    controller.addListener(() {
      notifications += 1;
    });

    await harness.sendEvent(45, playbackEvent(position: 250));
    expect(notifications, 0);

    await harness.sendEvent(45, <String, Object?>{'state': 'paused'});
    expect(notifications, 1);
    expect(controller.value.state, VlcPlaybackState.paused);
    expect(controller.value.position, const Duration(milliseconds: 250));

    await tester.pump(const Duration(milliseconds: 100));
    expect(notifications, 1);
    expect(controller.value.state, VlcPlaybackState.paused);

    controller.dispose();
  });

  testWidgets('event channel errors bypass throttling', (tester) async {
    final controller = VlcPlayerController(
      eventThrottleInterval: const Duration(milliseconds: 100),
    );
    harness.mockEventChannel(46);
    await harness.attachController(controller, 46);
    await harness.sendEvent(46, playbackEvent(position: 0));

    var notifications = 0;
    controller.addListener(() {
      notifications += 1;
    });

    await harness.sendEvent(46, playbackEvent(position: 250));
    expect(notifications, 0);

    await harness.sendError(
      46,
      code: VlcPlayerErrorCode.playbackError,
      message: 'Decoder failed.',
    );
    expect(notifications, 1);
    expect(controller.value.state, VlcPlaybackState.error);
    expect(controller.value.errorDescription, 'Decoder failed.');

    await tester.pump(const Duration(milliseconds: 100));
    expect(notifications, 1);
    expect(controller.value.state, VlcPlaybackState.error);

    controller.dispose();
  });

  testWidgets('dispose cancels pending throttled progress updates', (
    tester,
  ) async {
    final controller = VlcPlayerController(
      eventThrottleInterval: const Duration(milliseconds: 100),
    );
    harness.mockEventChannel(47);
    await harness.attachController(controller, 47);
    await harness.sendEvent(47, playbackEvent(position: 0));

    var notifications = 0;
    controller.addListener(() {
      notifications += 1;
    });

    await harness.sendEvent(47, playbackEvent(position: 250));
    controller.dispose();

    await tester.pump(const Duration(milliseconds: 100));
    expect(notifications, 0);
  });
}
