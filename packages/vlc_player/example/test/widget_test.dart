import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_player_example/main.dart';
import 'package:vlc_player_example/src/player_example_view.dart';

void main() {
  testWidgets('example app renders without a platform view', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(showPlayer: false));

    expect(find.text('vlc_player example'), findsOneWidget);
    expect(find.text('Video file'), findsOneWidget);
    expect(find.text('HLS stream'), findsOneWidget);
    expect(find.text('Full player'), findsOneWidget);

    await tester.tap(find.text('Video file'));
    await tester.pumpAndSettle();
    expect(find.text('MP4 sample video'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('HLS stream'));
    await tester.pumpAndSettle();
    expect(find.text('M3U8 sample stream'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Full player'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.stay_current_landscape), findsOneWidget);
  });

  testWidgets('example pages forward VLC player options', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MyApp(showPlayer: false, playerOptions: <String>['--aout=dummy']),
    );

    await tester.tap(find.byKey(const ValueKey<String>('video-example-tile')));
    await tester.pumpAndSettle();

    final page = tester.widget<PlayerExampleView>(
      find.byType(PlayerExampleView),
    );
    expect(page.controller.options, <String>['--aout=dummy']);
  });

  testWidgets('desktop orientation control only updates local state', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final platformCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call);
          return null;
        });

    try {
      await tester.pumpWidget(const MyApp(showPlayer: false));
      await tester.tap(
        find.byKey(const ValueKey<String>('full-player-example-tile')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('full-player-orientation-button')),
      );
      await tester.pump();

      expect(find.byIcon(Icons.stay_current_portrait), findsOneWidget);
      expect(
        platformCalls.where(
          (call) => call.method == 'SystemChrome.setPreferredOrientations',
        ),
        isEmpty,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    }
  });
}
