/// Pumps the real [VlcPlayerScreen] over a mocked engine.
///
/// The screen is a hub, so standing it up means answering for the engine
/// channel, connectivity, the wakelock and storage at once; that plumbing
/// lives here.
///
/// Rules every screen test has to respect:
///  * A playing controller keeps a 1 s stall watchdog armed, and flutter_test
///    checks for pending timers before `addTearDown` runs. A test that ends
///    in healthy playback must emit a paused snapshot
///    (`sendEvent(tester, snapshot(state: 'paused'))`) or unmount the screen
///    in-body with `tester.pumpWidget(const SizedBox())`.
///  * Back on a remote is `tester.sendKeyEvent(LogicalKeyboardKey.goBack,
///    platform: 'android', physicalKey: PhysicalKeyboardKey.escape)`:
///    flutter_test has no physical key on file for Go Back and no Windows key
///    code for it; Android's table has both, and the controls only ever read
///    the logical key.
///  * `settle()`, never `pumpAndSettle`, once the screen has reached the
///    playing stage: the overlay's spinner is deliberately endless.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/core/extensions/extension_manager.dart';
import 'package:skystream/core/services/download_service.dart';
import 'package:skystream/core/storage/episode_watch_repository.dart';
import 'package:skystream/core/storage/history_repository.dart';
import 'package:skystream/core/storage/settings_repository.dart';
import 'package:skystream/core/storage/storage_service.dart';
import 'package:skystream/core/providers/device_info_provider.dart';
import 'package:skystream/features/library/presentation/history_provider.dart';
import 'package:skystream/features/player/presentation/vlc/side_car_fetch.dart';
import 'package:skystream/features/player/presentation/vlc/vlc_player_screen.dart';
import 'package:skystream/features/player/presentation/vlc/vlc_player_controls.dart';
import 'package:skystream/features/settings/presentation/player_settings_provider.dart';
import 'package:skystream/features/tracking/data/sync_manager.dart';
import 'package:skystream/features/tracking/data/tracking_service.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';

import 'fake_vlc_engine.dart';

const MethodChannel vlcChannel = MethodChannel('vlc_player');
const MethodChannel pipChannel = MethodChannel(
  'dev.akash.skystream.player/pip',
);

/// The texture path names its own view: `create` answers with the id, so a
/// test knows which event channel to speak on. The platform-view path takes
/// its id from Flutter's process-wide registry, which the screen has nowhere
/// to publish, so no test could reach that engine.
final TargetPlatformVariant texturePlatform = TargetPlatformVariant.only(
  TargetPlatform.windows,
);
const int viewId = 1;
const EventChannel engineEvents = EventChannel('vlc_player/events/$viewId');

/// The quality filter asks whether the device is on Wi-Fi, and the screen
/// watches for the network coming back. Both go through connectivity_plus,
/// which never answers in a test unless it is told to.
const MethodChannel connectivityChannel = MethodChannel(
  'dev.fluttercommunity.plus/connectivity',
);
const EventChannel connectivityStatus = EventChannel(
  'dev.fluttercommunity.plus/connectivity_status',
);

/// Answered because the wakelock is taken from unawaited futures - see
/// pip_engine_continuity_test for the same guard.
const String wakelockToggle =
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle';
final ByteData? wakelockReply = const StandardMessageCodec().encodeMessage(
  <Object?>[null],
);

/// A 1080p television at the density Android TV reports: a 1920x1080 panel at
/// devicePixelRatio 2, so 960x540 logical dp - half the layout budget a naive
/// 1920x1080-at-dpr-1 harness would hand out.
const Size googleTvSize = Size(960, 540);

/// The size every screen test runs at. This is [googleTvSize]: the harness
/// sets `devicePixelRatio = 1`, so the number here is logical dp directly.
const Size tvSize = googleTvSize;

/// Resume lookup and progress writing both end in Hive; this answers empty
/// and swallows the writes instead of standing a storage stack up.
class NoHistory extends HistoryRepository {
  NoHistory() : super(StorageService());

  @override
  List<HistoryItem> getWatchHistory() => const <HistoryItem>[];

  @override
  int getPosition(String url) => 0;

  @override
  int getDuration(String url) => 0;

  @override
  int getEpisodePosition(
    String url, {
    String? mainUrl,
    int? season,
    int? episode,
  }) => 0;

  @override
  int getEpisodeDuration(
    String url, {
    String? mainUrl,
    int? season,
    int? episode,
  }) => 0;

  @override
  Future<void> saveProgress(
    MultimediaItem item,
    int position,
    int duration, {
    String? lastStreamUrl,
    String? lastEpisodeUrl,
    int? season,
    int? episode,
    String? episodeTitle,
    String? episodePosterUrl,
  }) async {}
}

/// Advancing an episode and recording a livestream both write Continue
/// Watching through the notifier rather than the repository, and the real one
/// reads the settings store first.
class MuteWatchHistory extends WatchHistory {
  @override
  List<HistoryItem> build() => const <HistoryItem>[];

  @override
  Future<void> saveProgress(
    MultimediaItem item,
    int position,
    int duration, {
    String? lastStreamUrl,
    String? lastEpisodeUrl,
    int? season,
    int? episode,
    String? episodeTitle,
    String? episodePosterUrl,
  }) async {}

  /// End of media with no next episode clears the title out of Continue
  /// Watching through here.
  @override
  Future<void> removeFromHistory(String url) async {}
}

/// Every test that plays an episode to its duration reaches [PlaybackTracker]'s
/// terminal mark-watched. The real provider is built from
/// `storageServiceProvider`, which throws.
class QuietEpisodeWatch extends EpisodeWatchRepository {
  QuietEpisodeWatch() : super(StorageService(), NoHistory(), _nothingChanged);

  static void _nothingChanged() {}

  @override
  Future<void> setWatched(
    String mainUrl,
    Episode episode,
    bool watched,
  ) async {}

  /// Null is "no explicit override", which sends `isWatched` on to the history
  /// repository. Overridden because the real one reads the raw store.
  @override
  bool? getExplicitState(String mainUrl, Episode episode) => null;
}

/// Both skip-segment lookups read their switch from storage before doing
/// anything, and an episode always asks. Off, without a storage stack.
class QuietSettings extends SettingsRepository {
  QuietSettings() : super(StorageService());

  @override
  bool isIntroDbIntegrationEnabled() => false;

  @override
  bool isAnimeSkipIntegrationEnabled() => false;
}

/// A download lookup that waits to be let go.
///
/// The next-episode path looks on disk before it resolves anything, so holding
/// that lookup open is how a test sees the screen mid-advance.
class GatedDownloads extends DownloadService {
  GatedDownloads(super.ref);

  final Completer<void> gate = Completer<void>();

  @override
  Future<File?> getDownloadedFile(
    MultimediaItem item, {
    Episode? episode,
  }) async {
    await gate.future;
    return null;
  }
}

/// Answers for everything the screen talks to.
///
/// With no [engine], the player channel answers `create` and nothing else, and
/// the event stream is silent until a test speaks on it with [sendEvent]. With
/// one, the channel and the stream are the fake's, so track calls are answered
/// from its state and `engine.emit` stamps that state into every snapshot;
/// [sendEvent] still reaches it as long as the fake keeps the default [viewId].
void installEngineMocks({FakeVlcEngine? engine}) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  if (engine != null) {
    engine.install();
  } else {
    messenger.setMockMethodCallHandler(vlcChannel, (call) async {
      if (call.method == 'create') {
        return <String, Object?>{'viewId': viewId, 'textureId': viewId};
      }
      return null;
    });
    messenger.setMockStreamHandler(
      engineEvents,
      MockStreamHandler.inline(onListen: (arguments, sink) {}),
    );
  }
  messenger.setMockMessageHandler(
    wakelockToggle,
    (message) async => wakelockReply,
  );
  messenger.setMockMethodCallHandler(
    connectivityChannel,
    (call) async => <String>['wifi'],
  );
  messenger.setMockStreamHandler(
    connectivityStatus,
    MockStreamHandler.inline(onListen: (arguments, sink) {}),
  );
}

void removeEngineMocks() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(vlcChannel, null);
  messenger.setMockStreamHandler(engineEvents, null);
  messenger.setMockMessageHandler(wakelockToggle, null);
  messenger.setMockMethodCallHandler(pipChannel, null);
  messenger.setMockMethodCallHandler(connectivityChannel, null);
  messenger.setMockStreamHandler(connectivityStatus, null);
}

/// The overlay's spinner never stops, so `pumpAndSettle` cannot be used once
/// the screen has reached the playing stage. A fixed run of frames drives the
/// same async gaps.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// One native snapshot, shaped the way the engine sends it.
Map<String, Object?> snapshot({
  String state = 'playing',
  int position = 1500,
  int duration = 0,
}) => <String, Object?>{
  'state': state,
  'position': position,
  'duration': duration,
  'volume': 100,
  'playbackSpeed': 1.0,
  'isReady': true,
  'isSeekable': true,
  'isLive': false,
};

/// Delivers [event] and nothing more, for tests that need to look at the very
/// next frame.
Future<void> sendSnapshot(
  WidgetTester tester,
  Map<String, Object?> event,
) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    engineEvents.name,
    engineEvents.codec.encodeSuccessEnvelope(event),
    null,
  );
}

/// One engine event, as the native side would deliver it, pumped past the
/// controller's 250ms event throttle.
Future<void> sendEvent(WidgetTester tester, Map<String, Object?> event) async {
  await sendSnapshot(tester, event);
  await tester.pump(const Duration(milliseconds: 400));
}

/// The engine reports a position that has moved, which is the only thing the
/// screen accepts as proof that a frame exists.
/// [showControls] summons the initially hidden controls for tests that need
/// to interact with the bars. A native frame alone never reveals them.
Future<void> sendFirstFrame(
  WidgetTester tester, {
  bool showControls = false,
}) async {
  await sendEvent(tester, snapshot());
  if (showControls) await revealPlayerControls(tester);
}

/// Reveals controls as a viewer would and advances their fade off zero.
Future<void> revealPlayerControls(WidgetTester tester) async {
  final controls = tester.widget<VlcPlayerControls>(
    find.byType(VlcPlayerControls),
  );
  if (controls.chrome!.value) return;
  await tester.sendKeyEvent(
    LogicalKeyboardKey.select,
    platform: 'android',
    physicalKey: PhysicalKeyboardKey.enter,
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
}

/// Back as the system delivers it, which the framework turns into a `popRoute`
/// on the navigation channel for PopScope to catch.
Future<void> sendBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.navigation.name,
    SystemChannels.navigation.codec.encodeMethodCall(
      const MethodCall('popRoute'),
    ),
    (_) {},
  );
  await tester.pump();
}

/// Stands the screen up and drives it to the point where `setMedia` has been
/// called and the engine owes a frame.
///
/// [pushed] puts a page under the player so a pop has somewhere to go and a
/// test can see that it went; the default hosts it as `home`, where Back
/// would leave the app instead.
///
/// Subtitle files are served by [servedSubtitle] unless [overrides] brings
/// its own `sideCarFetchProvider`.
///
/// The sync manager is stood up with no tracking services unless [overrides]
/// brings its own: the real one watches four services none of this plumbing
/// answers for, so the scrobble a snapshot with a real length triggers would
/// throw straight out of the controller's notifyListeners.
///
/// [settings] is a parameter rather than something a caller puts in
/// [overrides] because the default below is unconditional: Riverpod rejects
/// the same provider overridden twice in one scope, so a test that brought its
/// own `playerSettingsProvider` would throw instead of taking effect.
Future<void> pumpPlayer(
  WidgetTester tester, {
  List<StreamResult>? preloadedStreams,
  MultimediaItem? item,
  Episode? episode,
  String? videoUrl,
  bool isTv = true,
  bool pushed = false,
  List<Override> overrides = const <Override>[],
  DeviceProfile? profile,
  PlayerSettings settings = const PlayerSettings(),
  Size panelPhysicalSize = tvSize,
  double panelDevicePixelRatio = 1,
}) async {
  // The panel arguments default to the harness size at density 1. They exist
  // for the one question that needs a real panel: the player reads the
  // physical height of the surface to decide how tall a rendition this device
  // may be handed, and 960x540 at density 1 is not a panel any device has.
  tester.view.physicalSize = panelPhysicalSize;
  tester.view.devicePixelRatio = panelDevicePixelRatio;
  addTearDown(tester.view.reset);

  final media =
      item ??
      MultimediaItem(
        title: 'Channel One',
        url: 'https://example.com/movie.mp4',
        posterUrl: '',
        // Direct only when there is nothing preloaded to prefer.
        provider: preloadedStreams == null ? 'Remote' : null,
      );
  final screen = VlcPlayerScreen(
    item: media,
    videoUrl: videoUrl ?? 'https://example.com/movie.mp4',
    episode: episode,
    preloadedStreams: preloadedStreams,
  );
  final navigator = GlobalKey<NavigatorState>();
  // Riverpod rejects the same provider overridden twice in one scope, so every
  // default below stands down when the caller brought its own.
  bool brought(Object provider) =>
      overrides.any((override) => override.origin == provider);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        deviceProfileProvider.overrideWithValue(
          AsyncValue.data(profile ?? DeviceProfile(isTv: isTv)),
        ),
        playerSettingsProvider.overrideWithBuild((_, _) => settings),
        // Nothing here goes near a plugin: either the item is direct or the
        // candidates are handed in already resolved.
        activeProviderProvider.overrideWithValue(null),
        if (!brought(historyRepositoryProvider))
          historyRepositoryProvider.overrideWithValue(NoHistory()),
        watchHistoryProvider.overrideWith(MuteWatchHistory.new),
        if (!brought(episodeWatchRepositoryProvider))
          episodeWatchRepositoryProvider.overrideWithValue(QuietEpisodeWatch()),
        if (!brought(settingsRepositoryProvider))
          settingsRepositoryProvider.overrideWithValue(QuietSettings()),
        if (!brought(syncManagerProvider))
          syncManagerProvider.overrideWithValue(
            SyncManager(const <TrackingService>[]),
          ),
        if (!brought(sideCarFetchProvider))
          sideCarFetchProvider.overrideWithValue(servedSubtitle),
        ...overrides,
      ],
      child: MaterialApp(
        navigatorKey: navigator,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: pushed ? const Scaffold(body: SizedBox.expand()) : screen,
      ),
    ),
  );
  if (pushed) {
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => screen),
      ),
    );
  }
  // Resolution, the resume lookup, setMedia and the texture attach are all
  // async gaps; so is the push transition.
  await settle(tester);
}

/// Every subtitle file the screen reads, served from memory: one line, the
/// file's own name, on screen for the first ten hours. A test tells which
/// file is showing by finding its name.
Future<List<int>?> servedSubtitle(
  Uri url,
  Map<String, String>? headers,
) async =>
    utf8.encode('1\n00:00:00,000 --> 10:00:00,000\n${url.pathSegments.last}\n');
