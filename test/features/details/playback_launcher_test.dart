import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/core/extensions/base_provider.dart';
import 'package:skystream/core/extensions/extension_manager.dart';
import 'package:skystream/core/router/app_router.dart';
import 'package:skystream/core/services/download_service.dart';
import 'package:skystream/core/services/notification_service.dart';
import 'package:skystream/features/details/presentation/playback_launcher.dart';
import 'package:skystream/features/settings/presentation/player_settings_provider.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';
import 'package:skystream/shared/widgets/loading_dialog.dart';

/// Where an already-resolved link goes.
///
/// The source sheets hold a picked [StreamResult] and used to push the
/// built-in player themselves, so "Default Player" was honoured on the
/// details-screen route and nowhere else. Everything now goes through
/// [PlaybackLauncher.playResolved], which is the one place that reads the
/// setting — and the one place that can tell the user when the chosen player
/// cannot carry the request the source needs.
void main() {
  final MultimediaItem item = MultimediaItem(
    title: 'Test Movie',
    url: 'https://example.test/movie',
    posterUrl: '',
    contentType: MultimediaContentType.movie,
  );

  group('playResolved honours the Default Player setting', () {
    testWidgets('a details action cannot launch a second player', (
      tester,
    ) async {
      final harness = await _pump(tester);
      unawaited(
        harness.launcher.playResolved(
          harness.context,
          item: item,
          videoUrl: 'tmdb:603',
        ),
      );
      await tester.pumpAndSettle();
      final firstPush = harness.pushed;

      // The covered Details context stays mounted. Neither entry point should
      // resolve another stream or push another player if its button fires.
      await harness.launcher.play(harness.context, 'tmdb:604', baseItem: item);
      await harness.launcher.playResolved(
        harness.context,
        item: item,
        videoUrl: 'tmdb:604',
      );
      await tester.pumpAndSettle();
      expect(harness.pushed, same(firstPush));
      expect(harness.playerBuilds, 1);
    });

    testWidgets('no preference opens the built-in player, list intact', (
      tester,
    ) async {
      final _Harness harness = await _pump(tester);

      unawaited(
        harness.launcher.playResolved(
          harness.context,
          item: item,
          videoUrl: 'tmdb:603',
          streams: const <StreamResult>[
            StreamResult(url: 'https://cdn.test/a.mkv', source: 'alpha'),
            StreamResult(url: 'https://cdn.test/b.mkv', source: 'beta'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('player'), findsOneWidget);
      expect(harness.pushed!.videoUrl, 'tmdb:603');
      expect(
        harness.pushed!.preloadedStreams!.map((StreamResult s) => s.url),
        <String>['https://cdn.test/a.mkv', 'https://cdn.test/b.mkv'],
      );
      expect(harness.notifications.toasts, isEmpty);
    });

    testWidgets('a chosen player takes the hand-off instead of the route', (
      tester,
    ) async {
      final _Harness harness = await _pump(
        tester,
        preferredPlayer: 'mx_player',
      );

      unawaited(
        harness.launcher.playResolved(
          harness.context,
          item: item,
          videoUrl: 'tmdb:603',
          streams: const <StreamResult>[
            StreamResult(url: 'https://cdn.test/a.mkv', source: 'alpha'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // MX Player is an Android package and this is a desktop test host, so
      // the hand-off fails and falls back — but it was attempted, which is
      // what pushing PlayerRoute directly never did.
      expect(
        harness.notifications.toasts.single.message,
        contains('MX Player'),
      );
      expect(harness.notifications.toasts.single.message, contains('detected'));
      expect(find.text('player'), findsOneWidget);
      await _drainToasts(tester);
    });
  });

  group('headers the chosen player cannot carry', () {
    testWidgets('are reported before the hand-off, not dropped into it', (
      tester,
    ) async {
      // A widget test runs as Android, and the intent MainActivity.kt builds
      // has no slot for a header: a source bound to its Referer cannot be
      // played by any app we hand it to there.
      final _Harness harness = await _pump(
        tester,
        preferredPlayer: 'mx_player',
      );

      unawaited(
        harness.launcher.playResolved(
          harness.context,
          item: item,
          videoUrl: 'tmdb:603',
          streams: const <StreamResult>[
            StreamResult(
              url: 'https://cdn.test/a.mkv',
              source: 'alpha',
              headers: <String, String>{'Referer': 'https://origin.test/'},
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final ToastItem toast = harness.notifications.toasts.single;
      expect(toast.message, contains('MX Player cannot send Referer'));
      // Not "not detected": the player may well be installed. The reason the
      // user is back on the built-in one is the request, not the app.
      expect(toast.message, isNot(contains('detected')));

      expect(find.text('player'), findsOneWidget);
      expect(
        harness.pushed!.preloadedStreams!.single.url,
        'https://cdn.test/a.mkv',
      );
      await _drainToasts(tester);
    });

    testWidgets('a header the target can carry is not an obstacle', (
      tester,
    ) async {
      // mpv is launched from a command line on the desktop and takes every
      // field on it, so the same source is handed over rather than refused.
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final _Harness harness = await _pump(tester, preferredPlayer: 'mpv');

      unawaited(
        harness.launcher.playResolved(
          harness.context,
          item: item,
          videoUrl: 'tmdb:603',
          streams: const <StreamResult>[
            StreamResult(
              url: 'https://cdn.test/a.mkv',
              source: 'alpha',
              headers: <String, String>{'Referer': 'https://origin.test/'},
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      for (final ToastItem toast in harness.notifications.toasts) {
        expect(toast.message, isNot(contains('cannot send')));
      }
      await _drainToasts(tester);
      // Reset inline: a tearDown runs after the binding checks this.
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('no play entry point pushes the player behind the launcher', () {
    // The add-on sheet and the Continue Watching livestream tap have no
    // widget test of their own - the first needs four add-on services stood
    // up, the second a history repository - so the invariant is asserted
    // against the source: the route is the launcher's to push, because the
    // launcher is what reads "Default Player".
    const List<String> files = <String>[
      'lib/features/addons/presentation/addon_direct_play.dart',
      'lib/features/addons/presentation/addon_sources_sheet.dart',
      'lib/features/addons/presentation/widgets/addon_play_button.dart',
      'lib/features/home/presentation/widgets/continue_watching_card.dart',
      'lib/features/sources/presentation/plugin_sources_sheet.dart',
    ];

    for (final String path in files) {
      test(path, () {
        final File file = File(path);
        expect(file.existsSync(), isTrue, reason: 'run from the package root');
        // Comments may name it; only executable lines are scanned.
        final List<String> offending = <String>[];
        final List<String> lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          if (lines[i].trimLeft().startsWith('//')) continue;
          if (lines[i].contains('PlayerRoute')) {
            offending.add('$path:${i + 1}');
          }
        }
        expect(
          offending,
          isEmpty,
          reason:
              'pushing PlayerRoute here skips preferredPlayer; hand the '
              'resolved streams to PlaybackLauncher.playResolved instead',
        );
      });
    }
  });

  group('the source picker for a chosen player', () {
    // Home's Continue Watching card launches from inside the Home tab: the
    // picker has to come up over the app's bottom bar, as its dialogs do.
    testWidgets('opens over the app\'s bottom bar from inside a tab', (
      tester,
    ) async {
      final _Harness harness = await _pump(
        tester,
        preferredPlayer: 'mx_player',
        inTab: true,
        overrides: [
          activeProviderProvider.overrideWithValue(
            _ScreenProvider(
              links: const [
                StreamResult(url: 'https://cdn.test/a.mkv', source: 'alpha'),
                StreamResult(url: 'https://cdn.test/b.mkv', source: 'beta'),
              ],
            ),
          ),
          downloadServiceProvider.overrideWith((Ref ref) => _NoDownloads(ref)),
        ],
      );
      unawaited(
        harness.launcher.play(
          harness.context,
          'https://example.test/episode',
          baseItem: MultimediaItem(title: 'Show', url: '', posterUrl: ''),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('alpha'), findsOneWidget);
      expect(
        find.byKey(const Key('bottom bar')).hitTestable(),
        findsNothing,
        reason: 'under the picker and its barrier',
      );
    });
  });

  group("a Play an extension's own full-screen screen took", () {
    testWidgets('ends quietly with a chosen player too: no fallback to the built-in one, which would open it again', (
      tester,
    ) async {
      // Phase 7c's §4: the game played in its own screen during the links call.
      final _Harness harness = await _pump(
        tester,
        preferredPlayer: 'mx_player',
        overrides: [
          activeProviderProvider.overrideWithValue(_ScreenProvider()),
          downloadServiceProvider.overrideWith((Ref ref) => _NoDownloads(ref)),
        ],
      );
      unawaited(
        harness.launcher.play(
          harness.context,
          'cs3data:cG9rZW1vbg==',
          baseItem: MultimediaItem(title: 'Pokemon', url: '', posterUrl: ''),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('player'), findsNothing);
      expect(find.text('home'), findsOneWidget);
      expect(harness.notifications.toasts, isEmpty);
    });

    for (final outcome in ['ends quietly', 'answers links', 'fails']) {
      testWidgets('with a chosen player, a call that $outcome under the screen still up takes away its dialog only', (
        tester,
      ) async {
        // The screen is the extension's to close: a bare pop took it instead of the dialog under it.
        final game = MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('game')));
        late final _Harness harness;
        void shown() => unawaited(Navigator.of(harness.context, rootNavigator: true).push(game));
        harness = await _pump(
          tester,
          preferredPlayer: 'mx_player',
          overrides: [
            activeProviderProvider.overrideWithValue(switch (outcome) {
              'answers links' => _ScreenProvider(
                shown: shown,
                links: const [StreamResult(url: 'https://cdn.test/a.mkv', source: 'alpha')],
              ),
              'fails' => _ScreenProvider(shown: shown, error: Exception('boom')),
              _ => _ScreenProvider(shown: shown),
            }),
            downloadServiceProvider.overrideWith((Ref ref) => _NoDownloads(ref)),
          ],
        );
        unawaited(
          harness.launcher.play(
            harness.context,
            'cs3data:cG9rZW1vbg==',
            baseItem: MultimediaItem(title: 'Pokemon', url: '', posterUrl: ''),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('game', skipOffstage: false), findsOneWidget);
        expect(find.byType(LoadingDialog, skipOffstage: false), findsNothing);
        await _drainToasts(tester);
      });
    }
  });
}

/// Runs out the toast auto-dismiss timers, which live on the service rather
/// than on the tree and so outlive [WidgetTester.pumpAndSettle].
Future<void> _drainToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

class _Harness {
  _Harness(this.container, this.notifications);

  final ProviderContainer container;
  final NotificationService notifications;

  late final PlaybackLauncher launcher = container.read(
    playbackLauncherProvider,
  );

  late BuildContext context;
  PlayerRouteExtra? pushed;
  int playerBuilds = 0;
}

/// A two-route app: a home to launch from and a stand-in for the player, so
/// `PlayerRoute(...).push()` resolves without building the real screen.
///
/// [inTab] puts the home inside a shell with a bottom bar, as the app's tabs
/// are: the home's navigator is the tab's, not the app's.
Future<_Harness> _pump(
  WidgetTester tester, {
  String? preferredPlayer,
  List<Override> overrides = const <Override>[],
  bool inTab = false,
}) async {
  final NotificationService notifications = NotificationService();
  addTearDown(notifications.dispose);

  final ProviderContainer container = ProviderContainer(
    overrides: [
      notificationServiceProvider.overrideWithValue(notifications),
      playerSettingsProvider.overrideWithBuild(
        (_, _) => PlayerSettings(preferredPlayer: preferredPlayer),
      ),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);

  final _Harness harness = _Harness(container, notifications);

  final GoRoute home = GoRoute(
    path: '/',
    builder: (BuildContext context, GoRouterState state) {
      harness.context = context;
      return const Scaffold(body: Text('home'));
    },
  );
  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      if (inTab)
        ShellRoute(
          builder: (BuildContext context, GoRouterState state, Widget child) =>
              Scaffold(
                extendBody: true,
                body: child,
                bottomNavigationBar: const ColoredBox(
                  key: Key('bottom bar'),
                  color: Color(0xFF2196F3),
                  child: SizedBox(height: 64, width: double.infinity),
                ),
              ),
          routes: <RouteBase>[home],
        )
      else
        home,
      GoRoute(
        path: '/player',
        builder: (BuildContext context, GoRouterState state) {
          harness.playerBuilds++;
          harness.pushed = state.extra! as PlayerRouteExtra;
          return const Scaffold(body: Text('player'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}

/// A provider whose links went to its own full-screen screen (a game). [shown] puts that screen up, still there as the
/// call answers (the engine ends a screen 300 ms after its last window goes); the call then answers [links], throws
/// [error], or ends quietly.
class _ScreenProvider implements SkyStreamProvider {
  _ScreenProvider({this.shown, this.links, this.error});

  final void Function()? shown;
  final List<StreamResult>? links;
  final Object? error;

  @override
  Future<List<StreamResult>> loadStreams(String url) async {
    shown?.call();
    if (links case final links?) return links;
    throw error ?? const ExtensionScreenEnded();
  }

  @override
  String get packageName => 'cs3:ayu/Pokemon/Pokemon';
  @override
  String get name => 'Pokemon';
  @override
  String get mainUrl => 'https://ayu.test';
  @override
  String get version => '1';
  @override
  List<String> get languages => const ['en'];
  @override
  Set<ProviderType> get supportedTypes => const {ProviderType.other};
  @override
  bool get hasSearch => false;
  @override
  bool get isDebug => false;
  @override
  String? get checkSource => null;
  @override
  void cancelInit() {}
  @override
  Future<List<MultimediaItem>> search(String query, {CancelToken? cancelToken}) async => const [];
  @override
  Future<Map<String, List<MultimediaItem>>> getHome() async => const {};
  @override
  Future<HomeSectionPage?> getHomeSection(String section, int page) async =>
      null;
  @override
  Future<MultimediaItem> getDetails(String url) async => throw UnimplementedError();
}

/// Nothing is downloaded.
class _NoDownloads extends DownloadService {
  _NoDownloads(super.ref);

  @override
  Future<File?> getDownloadedFile(MultimediaItem item, {Episode? episode}) async => null;
}
