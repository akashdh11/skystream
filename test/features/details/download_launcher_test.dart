import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/core/logger/app_logger.dart';
import 'package:skystream/core/router/app_router.dart';
import 'package:skystream/core/services/download_service.dart';
import 'package:skystream/core/services/notification_service.dart';
import 'package:skystream/features/details/presentation/download_launcher.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';
import 'package:skystream/shared/widgets/loading_dialog.dart';
import 'package:skystream/core/extensions/extension_manager.dart';
import 'package:skystream/core/extensions/base_provider.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// "Download Now" used to be able to do nothing at all.
///
/// The confirm button's `onPressed` popped its dialog and then awaited
/// `startDownload` with no try/catch, and `startDownload` had none either.
/// `dir.create(recursive: true)` throws a FileSystemException whenever the
/// target is unwritable - the default outcome on Android 11+ once
/// All-files-access is declined - so the dialog closed and that was the end of
/// it: no progress row, no toast, no error, nothing in the log. The user taps
/// again and gets the same nothing, and the feature is simply broken from
/// where they are standing.
///
/// The `if (!started)` toast that was already there only ever covered `enqueue`
/// returning false, which is not the failure that happens.
void main() {
  late ProviderContainer container;
  late _StubDownloadService downloads;

  Future<void> pumpLauncher(
    WidgetTester tester, {
    Object? failure,
    bool enqueueSucceeds = true,
  }) async {
    container = ProviderContainer(
      overrides: [
        downloadServiceProvider.overrideWith(
          (Ref ref) => downloads = _StubDownloadService(
            ref,
            failure: failure,
            enqueueSucceeds: enqueueSucceeds,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    talker.cleanHistory();
    addTearDown(talker.cleanHistory);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );
  }

  /// Drives the real widget path: source verified, confirmation dialog shown,
  /// "Download Now" tapped.
  Future<void> tapDownloadNow(WidgetTester tester) async {
    final BuildContext context = tester.element(find.byType(Scaffold));
    unawaited(
      container
          .read(downloadLauncherProvider)
          .verifyAndDownload(context, _stream, _item, _item.url),
    );

    await tester.pump(); // verification dialog in
    await tester.pump(const Duration(milliseconds: 400)); // metadata + pop
    await tester.pump(const Duration(milliseconds: 400)); // confirm dialog in

    expect(
      find.text('Download Now'),
      findsOneWidget,
      reason: 'the confirmation dialog is the thing under test',
    );
    await tester.tap(find.text('Download Now'));
    await tester.pump(); // dialog pops, handler runs
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Toast timers are the service's, not the widget tree's, so they outlive
  /// the last pump and `flutter_test` fails the test on them.
  Future<void> drainToasts(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 6));

  testWidgets('a throwing startDownload becomes a visible error', (
    WidgetTester tester,
  ) async {
    await pumpLauncher(
      tester,
      failure: const FileSystemException(
        'Creation failed',
        '/storage/emulated/0/Download/Skystream',
      ),
    );

    await tapDownloadNow(tester);

    expect(downloads.startCalls, 1);
    final List<ToastItem> toasts = container
        .read(notificationServiceProvider)
        .toasts;
    expect(
      toasts,
      hasLength(1),
      reason: 'the dialog is already gone; a toast is all that is left',
    );
    expect(toasts.single.type, ToastType.error);
    expect(toasts.single.message, contains('FileSystemException'));
    expect(
      toasts.single.message,
      contains('/storage/emulated/0/Download/Skystream'),
      reason: 'the path is the one thing that tells the user what to fix',
    );

    expect(
      _text(talker),
      contains('DownloadLauncher: "Download Now" failed'),
      reason: 'and it has to be in /logs too, or we cannot answer them',
    );

    await drainToasts(tester);
  });

  testWidgets('the enqueue-returned-false path still reports', (
    WidgetTester tester,
  ) async {
    await pumpLauncher(tester, enqueueSucceeds: false);

    await tapDownloadNow(tester);

    final List<ToastItem> toasts = container
        .read(notificationServiceProvider)
        .toasts;
    expect(toasts, hasLength(1));
    expect(toasts.single.type, ToastType.error);
    expect(toasts.single.message, contains('Failed to start download'));

    await drainToasts(tester);
  });

  testWidgets('a download that starts says nothing', (
    WidgetTester tester,
  ) async {
    await pumpLauncher(tester);

    await tapDownloadNow(tester);

    expect(downloads.startCalls, 1);
    expect(container.read(notificationServiceProvider).toasts, isEmpty);
    expect(_text(talker), isNot(contains('Download Now')));

    await drainToasts(tester);
  });

  testWidgets('the source picker opens over the app\'s bottom bar from a tab', (
    WidgetTester tester,
  ) async {
    container = ProviderContainer(
      overrides: [activeProviderProvider.overrideWithValue(_OneLinkProvider())],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // A tab of its own under the app's bottom bar, as the app's tabs are.
          home: Scaffold(
            extendBody: true,
            body: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('title')),
              ),
            ),
            bottomNavigationBar: const ColoredBox(
              key: Key('bottom bar'),
              color: Color(0xFF2196F3),
              child: SizedBox(height: 64, width: double.infinity),
            ),
          ),
        ),
      ),
    );
    unawaited(
      container
          .read(downloadLauncherProvider)
          .launch(tester.element(find.text('title')), _item),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text(_stream.source), findsOneWidget);
    expect(
      find.byKey(const Key('bottom bar')).hitTestable(),
      findsNothing,
      reason: 'under the picker and its barrier',
    );
  });

  testWidgets(
    "Download on a game's title: as the game's call ends, only its own dialog goes, never the game's screen",
    (WidgetTester tester) async {
      // The game's links call is the game; its screen, still up as the call ends, is the extension's to close.
      final game = MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('game')));
      container = ProviderContainer(
        overrides: [
          activeProviderProvider.overrideWithValue(
            _GameProvider(() => unawaited(rootNavigatorKey.currentState!.push(game))),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: Text('title')),
          ),
        ),
      );
      unawaited(
        container
            .read(downloadLauncherProvider)
            .launch(
              tester.element(find.text('title')),
              MultimediaItem(title: 'Pokemon', url: 'https://ayu.test/pokemon', posterUrl: ''),
            ),
      );
      await tester.pumpAndSettle();
      expect(find.text('game'), findsOneWidget);
      expect(find.byType(LoadingDialog, skipOffstage: false), findsNothing);
      await drainToasts(tester);
    },
  );
}

final MultimediaItem _item = MultimediaItem(
  title: 'A Movie',
  url: 'https://example.com/a-movie',
  posterUrl: '',
);

const StreamResult _stream = StreamResult(
  url: 'https://cdn.example.com/a-movie.mp4',
  source: 'Test Source',
);

class _StubDownloadService extends DownloadService {
  _StubDownloadService(
    super.ref, {
    required this.failure,
    required this.enqueueSucceeds,
  });

  final Object? failure;
  final bool enqueueSucceeds;
  int startCalls = 0;

  @override
  Future<DownloadMetadata?> getMetadata(
    String url, {
    Map<String, String>? headers,
  }) async => DownloadMetadata(size: 734003200, mimeType: 'video/mp4');

  @override
  Future<String> getDownloadPath(
    MultimediaItem? item, {
    Episode? episode,
    bool absolute = false,
  }) async => '/storage/emulated/0/Download/Skystream/A Movie';

  @override
  Future<bool> startDownload({
    required String url,
    required String filename,
    required String directory,
    required MultimediaItem item,
    Episode? episode,
    String? trackingUrl,
    Map<String, String>? headers,
  }) async {
    startCalls++;
    if (failure != null) throw failure!;
    return enqueueSucceeds;
  }
}

String _text(Talker logger) =>
    logger.history.map((TalkerData e) => e.generateTextMessage()).join('\n');

/// A provider whose links call answers one link.
class _OneLinkProvider extends _GameProvider {
  _OneLinkProvider() : super(() {});

  @override
  Future<List<StreamResult>> loadStreams(String url) async => const [_stream];
}

/// A game's provider: its links call puts the game's screen up ([shown]) and ends with it still there.
class _GameProvider implements SkyStreamProvider {
  _GameProvider(this.shown);

  final void Function() shown;

  @override
  Future<List<StreamResult>> loadStreams(String url) async {
    shown();
    throw const ExtensionScreenEnded();
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
