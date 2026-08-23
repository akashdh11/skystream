import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vlc_player/vlc_player.dart';
import 'package:vlc_player_example/main.dart';

import 'test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('example app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(showPlayer: false));

    expect(find.text('vlc_player example'), findsOneWidget);
    expect(find.text('Video file'), findsOneWidget);
    expect(find.text('HLS stream'), findsOneWidget);
    expect(find.text('Full player'), findsOneWidget);
  });

  testWidgets('example pages can be opened from the list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(showPlayer: false));

    await openExampleTile(tester, 'video-example-tile');
    expect(find.text('MP4 sample video'), findsOneWidget);

    await popRoute(tester, find.text('MP4 sample video'));
    await openExampleTile(tester, 'hls-example-tile');
    expect(find.text('M3U8 sample stream'), findsOneWidget);

    await popRoute(tester, find.text('M3U8 sample stream'));
    await openExampleTile(tester, 'full-player-example-tile');
    expect(
      find.byKey(const ValueKey<String>('full-player-play-pause-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('full-player-seek-slider')),
      findsOneWidget,
    );
  });

  testWidgets('native player view can be created', (WidgetTester tester) async {
    if (Platform.isLinux || Platform.isIOS) {
      // Linux libVLC core coverage lives in ctest; the GitHub Xvfb runner is
      // not stable enough for the real Flutter texture view. The iOS
      // simulator can hang while creating an empty native VLC view, so iOS
      // keeps coverage to app-level integration flows in CI.
      return;
    }

    final controller = VlcPlayerController(options: headlessPlayerOptions());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 180,
              child: VlcPlayer(controller: controller),
            ),
          ),
        ),
      ),
    );

    await pumpUntil(
      tester,
      () => controller.isAttached,
      description: 'native player attachment',
    );
    expect(controller.isAttached, isTrue);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpNavigation(tester);
  });

  testWidgets('full player orientation control updates the button state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(showPlayer: false));

    await openExampleTile(tester, 'full-player-example-tile');

    final orientationButton = tester.widget<IconButton>(
      find.byKey(const ValueKey<String>('full-player-orientation-button')),
    );
    orientationButton.onPressed!();
    await pumpNavigation(tester);

    expect(find.byIcon(Icons.stay_current_portrait), findsOneWidget);
  });
}
