// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:skystream/core/providers/device_info_provider.dart';
import 'package:skystream/features/player/presentation/vlc/vlc_player_controls.dart';
import 'package:skystream/features/settings/presentation/player_settings_provider.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';
import 'package:skystream/shared/widgets/tv_logical_scale.dart';

import 'fake_vlc_engine.dart';

void main() {
  for (final scale in [1.0, 1.15]) {
    for (final loseFocus in [false, true]) {
      testWidgets('fullscreen resize keeps Space in player '
          '(scale=$scale, native focus loss=$loseFocus)', (tester) async {
        tester.view.physicalSize = const Size(1280, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final engine = FakeVlcEngine()..install();
        addTearDown(engine.dispose);
        final controller = await engine.attach();
        addTearDown(controller.dispose);
        final detailsFocus = FocusNode(debugLabel: 'details-play');
        addTearDown(detailsFocus.dispose);
        final promptFocus = FocusNode(debugLabel: 'player-prompt');
        addTearDown(promptFocus.dispose);
        final dialogFocus = FocusNode(debugLabel: 'player-dialog');
        addTearDown(dialogFocus.dispose);
        var launches = 0;
        var fullscreenRequests = 0;
        var promptPresses = 0;
        late GoRouter router;
        router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  focusNode: detailsFocus,
                  autofocus: true,
                  onPressed: () {
                    launches++;
                    unawaited(router.push<void>('/player'));
                  },
                  child: const Text('Play from details'),
                ),
              ),
            ),
            GoRoute(
              path: '/player',
              builder: (context, _) => Scaffold(
                body: Stack(
                  fit: StackFit.expand,
                  children: [
                    VlcPlayerControls(
                      controller: controller,
                      title: 'Movie',
                      onBack: router.pop,
                      onToggleFullscreen: () {
                        fullscreenRequests++;
                        // Simulate the focus escape seen after the native
                        // fullscreen transition in the reported log.
                        if (loseFocus) detailsFocus.requestFocus();
                      },
                    ),
                    Align(
                      alignment: Alignment.topCenter,
                      child: TextButton(
                        focusNode: promptFocus,
                        onPressed: () => promptPresses++,
                        child: const Text('Player prompt'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deviceProfileProvider.overrideWithValue(
                const AsyncValue.data(DeviceProfile(isDesktopOS: true)),
              ),
              playerSettingsProvider.overrideWithBuild(
                (_, _) => const PlayerSettings(),
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => TvLogicalScale(
                enabled: false,
                userScale: scale,
                router: router,
                child: child!,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Play from details'));
        await tester.pumpAndSettle();
        await engine.emit({'position': 0, 'duration': 30000});
        await tester.pump();
        final playerState = tester.state(find.byType(VlcPlayerControls));

        // Hidden controls are summoned explicitly under 14d5f1f0's policy.
        expect(
          find.byIcon(Icons.fullscreen_rounded).hitTestable(),
          findsNothing,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        await tester.tap(find.byIcon(Icons.fullscreen_rounded));
        await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
        expect(fullscreenRequests, 1);
        tester.view.physicalSize = const Size(1920, 1080);
        await tester.pumpAndSettle();

        expect(tester.state(find.byType(VlcPlayerControls)), same(playerState));
        expect(detailsFocus.hasFocus, isFalse);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(launches, 1);
        expect(router.state.uri.path, '/player');
        if (loseFocus) expect(engine.callsTo('pause'), hasLength(1));

        // Sibling player prompts and modal dialogs must retain their focus.
        promptFocus.requestFocus();
        await tester.pump();
        expect(promptFocus.hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(promptPresses, 1);
        expect(launches, 1);
        unawaited(
          showDialog<void>(
            context: tester.element(find.byType(VlcPlayerControls)),
            builder: (context) => Dialog(
              child: TextButton(
                focusNode: dialogFocus,
                autofocus: true,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close dialog'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(dialogFocus.hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        expect(launches, 1);

        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      });
    }
  }
}
