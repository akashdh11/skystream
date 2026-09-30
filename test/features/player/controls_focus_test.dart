// A test's ProviderScope is its root scope; the rule only recognises one
// passed to runApp.
// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/providers/device_info_provider.dart';
import 'package:skystream/features/player/presentation/vlc/chrome_visibility_controller.dart';
import 'package:skystream/features/player/presentation/system_volume.dart';
import 'package:skystream/features/player/presentation/vlc/player_rail.dart';
import 'package:skystream/features/player/presentation/vlc/player_slider_dialog.dart';
import 'package:skystream/features/player/presentation/vlc/panel/player_panel.dart'
    show PlayerPanelTab;
import 'package:skystream/features/player/presentation/vlc/vlc_player_controls.dart';
import 'package:skystream/core/models/torrent_status.dart';
import 'package:skystream/features/player/presentation/components/torrent_info_widget.dart';
import 'package:skystream/features/skip/data/skip_service.dart'
    show SkipSegment, SkipType;
import 'package:skystream/features/player/presentation/vlc/transient_overlay.dart'
    show PlayerSeekBurst, PlayerToast;
import 'package:skystream/features/player/presentation/widgets/hotstar_player_style.dart';
import 'package:skystream/features/player/presentation/widgets/player_control_components.dart'
    show
        PlayerActionButton,
        PlayerActionStrip,
        PlayerBottomBar,
        PlayerCenterControls,
        PlayerCenterSeekButton,
        PlayerCenterPlayButton,
        PlayerIconButton;
import 'package:skystream/features/player/presentation/widgets/player_stream_widgets.dart'
    show PlayerBufferingIndicator, PlayerSeekBar, PlayerTimeLabel;
import 'package:skystream/features/player/presentation/player_platform_service.dart';
import 'package:skystream/features/settings/presentation/player_settings_provider.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';
import 'package:vlc_player/vlc_player.dart';

import 'fake_vlc_engine.dart';

/// The invariant this file holds: while the player is on screen, primary focus
/// is either a chrome control or the player's own key sink, never the route's
/// FocusScopeNode. A focused scope spends every arrow re-focusing itself, and
/// on a television there is no tap to recover by.
///
/// The desktop half holds the mouse contract: motion reveals, rest does not
/// re-arm, the bars never vanish under the cursor, and the cursor goes with
/// the chrome.
const Size _tv = Size(2560, 1440);

/// The handset the touch-only affordances exist for, and the same frame
/// controls_lock_test.dart renders its phone at.
const Size _phone = Size(844, 390);
const Duration _hideAfter = Duration(seconds: 3);
const EventChannel _events = EventChannel('vlc_player/events/1');

/// Every list button the bar can show, so a test that is not about them sees
/// them all.
const Set<PlayerPanelTab> _allTabs = <PlayerPanelTab>{
  PlayerPanelTab.sources,
  PlayerPanelTab.audio,
  PlayerPanelTab.subtitles,
  PlayerPanelTab.episodes,
  PlayerPanelTab.files,
};

/// A panel that opens and closes at once, so every list button renders in
/// tests that are about something else.
Future<void> _noPanel(PlayerPanelTab _) async {}

/// The hide timer refuses to fire until the engine reports playing, so every
/// test that waits for a hide starts by telling it so.
///
/// Position 0 on purpose: the controller only arms its stall watchdog once the
/// clock has moved, and a test ending in healthy playback with that timer
/// pending fails on flutter_test's pending-timer check.
Future<void> _play(WidgetTester tester) => _snapshot(tester);

/// One native snapshot, as the engine would send it. Sent on the fake's own
/// event channel, so it reaches the controller the fake attached.
Future<void> _snapshot(
  WidgetTester tester, {
  String state = 'playing',
  int position = 0,
  int duration = 30000,
  bool isSeekable = true,
}) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        _events.name,
        _events.codec.encodeSuccessEnvelope(<String, Object?>{
          'state': state,
          'position': position,
          'duration': duration,
          'volume': 100,
          'playbackSpeed': 1.0,
          'isReady': true,
          'isSeekable': isSeekable,
          'isLive': false,
        }),
        null,
      );
  await tester.pump();
}

/// Every seekTo the engine received, as the millisecond it was asked for.
List<int> _seeks(FakeVlcEngine engine) => engine
    .callsTo('seekTo')
    .map((call) => (call.arguments as Map)['position'] as int)
    .toList(growable: false);

/// Every setVolume the engine received, as the percentage it was asked for.
/// The fake never reports a volume back - its snapshot is a hardcoded 100 - so
/// what the widget asked for is the only truth available.
List<int> _volumes(FakeVlcEngine engine) => engine
    .callsTo('setVolume')
    .map((call) => (call.arguments as Map)['volume'] as int)
    .toList(growable: false);

/// Every setPlaybackSpeed the engine received, as the rate it was asked for.
List<double> _speeds(FakeVlcEngine engine) => engine
    .callsTo('setPlaybackSpeed')
    .map((call) => (call.arguments as Map)['speed'] as double)
    .toList(growable: false);

/// A game controller's shoulder button, down and up.
///
/// flutter_test resolves a key code per platform, and BUTTON_L1/R1 are in
/// Android's table.
Future<void> _shoulder(WidgetTester tester, LogicalKeyboardKey key) async {
  final forward = key == LogicalKeyboardKey.gameButtonRight1;
  await tester.sendKeyEvent(
    key,
    platform: 'android',
    physicalKey: forward
        ? PhysicalKeyboardKey.gameButtonRight1
        : PhysicalKeyboardKey.gameButtonLeft1,
  );
  await tester.pump();
}

Widget _host(
  Widget child, {
  required bool isTv,
  bool desktopProfile = false,
  PlayerSettings settings = const PlayerSettings(),
}) {
  return ProviderScope(
    overrides: [
      deviceProfileProvider.overrideWithValue(
        AsyncValue.data(
          DeviceProfile(isTv: isTv, isDesktopOS: desktopProfile),
        ),
      ),
      playerSettingsProvider.overrideWithBuild((_, _) => settings),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(fit: StackFit.expand, children: [child]),
      ),
    ),
  );
}

/// Pumps the controls. Desktop is whatever can toggle fullscreen.
///
/// [engine] is the fake the controller talks to; pass one to read its
/// `methods` back. [withoutPanel] stands in for `onOpenPanel: null`, which a
/// default parameter cannot express.
///
/// [size] is the viewport in logical pixels. Pass [_phone] for touch geometry
/// claims: a 2560x1440 frame has sixteen times a handset's pixel budget, so a
/// clearance measured only there holds for nudge values that would paint one
/// control on top of another on the device the feature is for.
Future<VlcPlayerController> _pumpControls(
  WidgetTester tester, {
  bool isTv = true,
  bool desktop = false,
  Future<void> Function(PlayerPanelTab tab) onOpenPanel = _noPanel,
  bool withoutPanel = false,
  Set<PlayerPanelTab> panelTabs = _allTabs,
  VoidCallback? onNextEpisode,
  VoidCallback? onPreviousEpisode,

  /// Stands in for "a film", which a default parameter cannot express: the
  /// harness gives `onNextEpisode` a callback when none is passed, the way
  /// [withoutPanel] stands in for `onOpenPanel: null`.
  bool withoutEpisodes = false,

  /// A phone gets these two and a television does not. Null by default.
  VoidCallback? onEnterPip,
  ValueNotifier<bool>? locked,
  ChromeVisibilityController? chrome,
  FakeVlcEngine? engine,
  PlayerSettings settings = const PlayerSettings(),
  bool isLive = false,
  SystemVolume? systemVolume,

  /// Whether the *device profile* says desktop, as opposed to [desktop], which
  /// only hands the controls an `onToggleFullscreen`. They agree on a real
  /// machine and are deliberately separate here: most of this file predates
  /// the distinction and reads the build-local flag, while anything that has
  /// to state which kind of device this is - the volume routing, the lock -
  /// reads the profile.
  bool desktopProfile = false,
  List<SkipSegment> skipSegments = const <SkipSegment>[],
  VoidCallback? onSkipOutro,
  TorrentStatus? torrentStatus,
  Size size = _tv,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final fake = engine ?? FakeVlcEngine();
  fake.install();
  // Tear-downs run last-in first-out: the controller goes first, while the
  // channel it sends `dispose` on still has a handler.
  addTearDown(fake.dispose);
  final controller = await fake.attach();
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    _host(
      VlcPlayerControls(
        controller: controller,
        chrome: chrome,
        title: 'The Body',
        subtitle: 'S5 E16',
        onBack: () {},
        onNextEpisode: withoutEpisodes ? null : (onNextEpisode ?? () {}),
        onPreviousEpisode: withoutEpisodes ? null : onPreviousEpisode,
        onOpenPanel: withoutPanel ? null : onOpenPanel,
        panelTabs: panelTabs,
        onEnterPip: onEnterPip,
        locked: locked,
        onToggleFullscreen: desktop ? () {} : null,
        isLive: isLive,
        systemVolumeFactory: systemVolume == null ? null : () => systemVolume,
        skipSegments: skipSegments,
        onSkipOutro: onSkipOutro,
        torrentStatus: torrentStatus,
      ),
      isTv: isTv,
      desktopProfile: desktopProfile,
      settings: settings,
    ),
  );
  await tester.pump();
  await _play(tester);
  return controller;
}

FocusNode get _primary => FocusManager.instance.primaryFocus!;

/// Resolved through the focus tree, not `Focus.of`: the nodes that matter are
/// the ones the controls file owns and labels.
FocusNode _byLabel(String label) => FocusManager.instance.rootScope.descendants
    .firstWhere((node) => node.debugLabel == label);

/// The focus node behind an icon button, via the InkWell's Focus that carries
/// the button's node.
FocusNode _button(WidgetTester tester, String tooltip) {
  return tester
      .widgetList<Focus>(
        find.descendant(
          of: find.byTooltip(tooltip),
          matching: find.byType(Focus),
        ),
      )
      .firstWhere((focus) => focus.focusNode != null)
      .focusNode!;
}

/// The seek bar's own focus node. The controls hand it none, so the bar makes
/// its own and labels it, which is the only way to name the one control here
/// that is not a button.
FocusNode _scrubber() => _byLabel('player-seek-bar');

bool _inChrome(FocusNode node) =>
    node.ancestors.any((n) => n.debugLabel == 'player-chrome');

/// The Skip chip's outer focus node, the one carrying its key handler.
///
/// [PlayerActionButton] is a [Focus] over an [InkWell] and InkWell makes a node
/// of its own, so the chip owns two. The wrapper is the first [Focus] inside
/// the button in tree order and is unlabelled, so it is matched by element
/// rather than by name.
FocusNode _skipChipNode(WidgetTester tester) {
  final Element wrapper = tester.element(
    find
        .descendant(
          of: find.ancestor(
            of: find.byIcon(Icons.fast_forward_rounded),
            matching: find.byType(PlayerActionButton),
          ),
          matching: find.byType(Focus),
        )
        .first,
  );
  return FocusManager.instance.rootScope.descendants.firstWhere(
    (node) => node.context == wrapper,
  );
}

/// Read off the fades' targets, so it does not wait on the animation.
Iterable<AnimatedOpacity> _fades(WidgetTester tester) =>
    tester.widgetList<AnimatedOpacity>(
      find.descendant(
        of: find.byType(VlcPlayerControls),
        matching: find.byType(AnimatedOpacity),
      ),
    );

void _expectShown(WidgetTester tester, {String? reason}) {
  final fades = _fades(tester);
  expect(fades, isNotEmpty);
  expect(fades.map((f) => f.opacity), everyElement(1.0), reason: reason);
}

void _expectHidden(WidgetTester tester, {String? reason}) {
  final fades = _fades(tester);
  expect(fades, isNotEmpty);
  expect(fades.map((f) => f.opacity), everyElement(0.0), reason: reason);
}

/// Taps a chrome button and lets the tap actually resolve.
///
/// A plain `tap(); pump();` is not enough anywhere in this player: the
/// screen-wide detector owns a double-tap (seek on touch, fullscreen on
/// desktop), so a button's own tap recogniser only wins the arena once that
/// one has timed out.
/// What holds primary focus, named the way a viewer would name it: a button's
/// tooltip, else its accessibility label, else the node's debug label.
String _focusedControl() {
  final context = FocusManager.instance.primaryFocus?.context;
  final tooltip = context?.findAncestorWidgetOfExactType<Tooltip>()?.message;
  if (tooltip != null) return tooltip;
  final label = context
      ?.findAncestorWidgetOfExactType<Semantics>()
      ?.properties
      .label;
  return label ?? '<${FocusManager.instance.primaryFocus?.debugLabel}>';
}

/// The platform's media volume, faked.
///
/// A handset routes the bottom of its scale through the system stream rather
/// than through libVLC, so on that form factor this - not `engine.callsTo
/// ('setVolume')` - is where the level a viewer chose actually lands.
class _FakeSystemVolume implements SystemVolume {
  _FakeSystemVolume();

  /// Starts at full, which is where the engine's own default of 100 % puts the
  /// joined level. A fake that started halfway would make every relative
  /// gesture in these tests start from a different place than it does on a
  /// device.
  double level = 1;
  final StreamController<double> _changes = StreamController<double>.broadcast();
  bool disposed = false;

  /// Every level this app has written, in order.
  final List<double> writes = <double>[];

  @override
  Future<double?> read() async => level;

  @override
  Future<void> write(double value) async {
    level = value;
    writes.add(value);
  }

  @override
  Stream<double> get changes => _changes.stream;

  /// The hardware rocker, which moves the stream with no call from the app.
  void rocker(double value) {
    level = value;
    _changes.add(value);
  }

  @override
  void dispose() {
    disposed = true;
    unawaited(_changes.close());
  }
}

Future<void> _tapControl(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
}

/// Runs the clock out and lets the frame that hides the chrome settle,
/// including the focus microtasks and the mouse tracker's post-frame pass.
Future<void> _letHide(WidgetTester tester) async {
  await tester.pump(_hideAfter);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VlcPlayerControls focus on TV', () {
    testWidgets('the remote starts on play/pause', (tester) async {
      await _pumpControls(tester);
      expect(_primary.debugLabel, 'player-play-pause');
    });

    // The panel is a route of its own, so the chrome underneath it keeps
    // ticking. Without a hold the bars fade out behind it, their ExcludeFocus
    // makes the button that opened it unfocusable, and closing focuses nothing.
    testWidgets('an open panel takes the bars out of sight but keeps them', (
      tester,
    ) async {
      // Two different things, and the panel needs both. The bars are not
      // painted while it is up - they would sit half-lit under its barrier -
      // but the chrome is still *held*, which is what stops the clock and what
      // keeps the button that opened the panel focusable for the pop to hand
      // focus back to. The proof of the hold is that the bars are there the
      // instant the panel closes, with no poke to summon them.
      final panel = Completer<void>();
      await _pumpControls(tester, onOpenPanel: (_) => panel.future);

      // [_tapControl], not a bare `tap`: the screen-wide detector owns a
      // double-tap, so this button's own recogniser does not win the arena
      // until that one times out. `pumpAndSettle` used to stand in for the
      // wait by accident - the play/pause button's label was mid-colour-fade
      // from having just taken focus, and settling that fade ran the clock
      // past the timeout. The moment that fade stopped happening the tap
      // stopped landing, with nothing about this test to say why.
      await _tapControl(tester, find.byTooltip('Options'));
      await tester.pumpAndSettle();
      _expectHidden(tester, reason: 'out of sight behind the panel');

      // Well past the hide clock, and past the one re-arm _expire grants a
      // player it thinks is paused.
      await _letHide(tester);
      await _letHide(tester);
      await _letHide(tester);

      panel.complete();
      await tester.pumpAndSettle();
      _expectShown(
        tester,
        reason: 'the hold outlasted the clock, so they come straight back',
      );

      await _letHide(tester);
      await _letHide(tester);
      await _letHide(tester);
      _expectHidden(tester, reason: 'and the clock has them again');
    });

    testWidgets('hiding hands focus to the sink, never the route scope', (
      tester,
    ) async {
      await _pumpControls(tester);
      await _letHide(tester);

      _expectHidden(tester);
      expect(_primary, isNot(isA<FocusScopeNode>()));
      expect(_primary.debugLabel, 'player-key-sink');
    });

    testWidgets('Back does not summon hidden chrome', (tester) async {
      // Android delivers Back as a key first and a popRoute second. If the key
      // raised the bars, the screen's Back handler would find them up and put
      // them away instead of leaving. Back belongs to the screen.
      await _pumpControls(tester);
      await _letHide(tester);
      _expectHidden(tester);

      await tester.sendKeyEvent(
        LogicalKeyboardKey.goBack,
        // flutter_test has no physical key on file for Go Back, and no
        // Windows key code for it either; Android's table has both. The
        // controls only ever read the logical key.
        platform: 'android',
        physicalKey: PhysicalKeyboardKey.escape,
      );
      await tester.pump();

      _expectHidden(tester, reason: 'Back is not ours to react to');
    });

    testWidgets('select while hidden brings the chrome back on play/pause', (
      tester,
    ) async {
      await _pumpControls(tester);
      await _letHide(tester);
      _expectHidden(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();

      _expectShown(tester);
      expect(_primary.debugLabel, 'player-play-pause');
    });

    testWidgets('every arrow from play/pause stays on a chrome node', (
      tester,
    ) async {
      await _pumpControls(tester);

      for (final arrow in <LogicalKeyboardKey>[
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
      ]) {
        _byLabel('player-play-pause').requestFocus();
        await tester.pump();
        expect(_primary.debugLabel, 'player-play-pause');

        await tester.sendKeyEvent(arrow);
        await tester.pump();

        expect(
          _inChrome(_primary),
          isTrue,
          reason:
              '${arrow.keyLabel.isEmpty ? arrow.debugName : arrow.keyLabel} '
              'from play/pause landed on ${_primary.debugLabel}; the sink is '
              'not a traversal candidate and the scope is never focused',
        );
      }
    });

    // Key dispatch runs the focused node first and stops at the first widget
    // that claims the key, so a seek bar that answers Up and Down itself hides
    // them from the player's sink - the only thing that restarts the hide
    // clock.
    testWidgets('moving the D-pad off the scrubber restarts the hide clock', (
      tester,
    ) async {
      await _pumpControls(tester);
      _scrubber().requestFocus();
      await tester.pump();
      expect(_primary.debugLabel, 'player-seek-bar');

      // 200 ms short of the clock: the bars are about to go.
      await tester.pump(_hideAfter - const Duration(milliseconds: 200));
      _expectShown(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      _expectShown(
        tester,
        reason: 'the press that moved focus is a press; the clock restarts',
      );
      expect(_inChrome(_primary), isTrue);
    });

    // A press the bar cannot act on is not the bar's to swallow. At position 0
    // a Left step clamps to where the thumb already is, and reporting that dead
    // press handled means no poke and bars that time out under a live viewer.
    testWidgets('a clamped scrubber press seeks nothing but still pokes', (
      tester,
    ) async {
      final engine = FakeVlcEngine();
      await _pumpControls(tester, engine: engine);
      engine.calls.clear();
      _scrubber().requestFocus();
      await tester.pump();

      await tester.pump(_hideAfter - const Duration(milliseconds: 200));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(
        _seeks(engine),
        isEmpty,
        reason: 'playback is at 0; there is nothing to the left',
      );
      _expectShown(tester, reason: 'a dead press is still a press');
    });

    // The arrows off the scrubber are DirectionalFocusAction's, so the geometry
    // has to work: Up crosses the Expanded spacer between the two bars, and
    // Down crosses the FocusTraversalGroup boundary around the button row.
    testWidgets('every arrow from the scrubber stays on a chrome node, and '
        'Up and Down reach the bars', (tester) async {
      await _pumpControls(tester);

      for (final arrow in <LogicalKeyboardKey>[
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
      ]) {
        _scrubber().requestFocus();
        await tester.pump();
        expect(_primary.debugLabel, 'player-seek-bar');

        await tester.sendKeyEvent(arrow);
        await tester.pump();

        expect(
          _inChrome(_primary),
          isTrue,
          reason:
              '${arrow.keyLabel.isEmpty ? arrow.debugName : arrow.keyLabel} '
              'from the scrubber landed on ${_primary.debugLabel}',
        );
      }

      // The Right in the loop opened a burst; let it commit and let the
      // chain window that follows it close, so no timer outlives the test.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      await _snapshot(tester, state: 'paused');
    });

    // Each direction gets its own test on purpose: the directional policy
    // keeps a per-scope history so that reversing a move returns to where it
    // came from, and pressing Up then Down inside one test measures that
    // hysteresis rather than the geometry.
    testWidgets('Up walks play/pause to the scrubber and on to the top bar', (
      tester,
    ) async {
      await _pumpControls(tester);
      expect(_primary.debugLabel, 'player-play-pause');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(_primary.debugLabel, 'player-seek-bar');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(
        _primary,
        _button(tester, 'Back'),
        reason: 'the bars are a Column apart, with an Expanded between them',
      );
    });

    testWidgets('Down from the scrubber crosses into the button row', (
      tester,
    ) async {
      await _pumpControls(tester);
      final scrubber = _scrubber();
      scrubber.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(_primary, isNot(scrubber));
      expect(_inChrome(_primary), isTrue);
      expect(
        _primary.rect.top,
        greaterThanOrEqualTo(scrubber.rect.bottom),
        reason:
            'the row under the scrubber is its own FocusTraversalGroup; '
            'geometric traversal has to cross into it',
      );
    });

    // isTv is declared on VlcProgressBar and passed by the controls; it has to
    // be read as well.
    testWidgets('the scrubber is sized for a sofa on TV', (tester) async {
      // Still the taller of the two ramps. Both came down 10 dp when the row
      // was trimmed to the track and its thumb: the dead space under an 8 dp
      // track was reading as a gap between the scrubber and the controls.
      await _pumpControls(tester);
      expect(tester.getSize(find.byType(PlayerSeekBar)).height, 38);
    });

    testWidgets('a parked remote does not pin the chrome, and OK always '
        'brings it back on play/pause', (tester) async {
      await _pumpControls(tester);

      // Rest on Options. Focus alone must not hold the bars: on a
      // television focus is always on *some* control while the chrome is up,
      // so a hold-while-focused rule would mean the chrome never hides.
      final options = _button(tester, 'Options');
      options.requestFocus();
      await tester.pump();
      expect(_primary, options);

      await _letHide(tester);
      _expectHidden(
        tester,
        reason: 'static focus on a button must not keep the video covered',
      );
      expect(_primary.debugLabel, 'player-key-sink');

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      _expectShown(tester);
      expect(
        _primary.debugLabel,
        'player-play-pause',
        reason: 'the bars used to come back on whatever was focused when they '
            'went down. With the D-pad now driving the transport while they '
            'are hidden, OK is the one press that opens them, and where it '
            'lands has to be predictable rather than a memory of where the '
            'viewer was four minutes ago',
      );
    });

    // The remote's transport. With the bars down the D-pad IS the transport
    // rather than a way of summoning the bars: left and right step the film,
    // up and down walk the boost, and OK is the one key that opens the chrome.
    //
    // What this replaces could not step through a film at all. The press woke
    // the bars, focus landed on a control, and every arrow after it was
    // traversal - so seeking meant waiting for the bars to time out and then
    // spending another press waking them again.
    testWidgets('a hidden chrome makes left and right seek, not traverse', (
      tester,
    ) async {
      final engine = FakeVlcEngine();
      await _pumpControls(tester, engine: engine);
      await _snapshot(tester, position: 60000, duration: 300000);
      await _letHide(tester);
      _expectHidden(tester);
      engine.calls.clear();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(_seeks(engine), <int>[70000]);
      _expectHidden(
        tester,
        reason: 'raising the bars is what takes the next arrow away from '
            'seeking, so this press must not raise them',
      );
      expect(_primary.debugLabel, 'player-key-sink', reason: 'and not moved');
      expect(
        tester.widget<PlayerSeekBurst>(find.byType(PlayerSeekBurst)).seconds,
        10,
        reason: 'the readout is the feedback, in place of the bars',
      );

      // And again, which is the whole point: a second press steps on rather
      // than being spent on the chrome. Pressed straight after the first, it
      // reaches the engine once the presses stop.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(VlcPlayerController.seekMergeWindow);
      expect(_seeks(engine), <int>[70000, 80000]);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump(VlcPlayerController.seekMergeWindow);
      expect(_seeks(engine), <int>[70000, 80000, 70000]);

      await _snapshot(tester, state: 'paused', position: 70000);
    });

    testWidgets('and up and down walk the boost in 25s', (tester) async {
      final engine = FakeVlcEngine();
      await _pumpControls(tester, engine: engine);
      await _snapshot(tester, position: 60000, duration: 300000);
      await _letHide(tester);
      _expectHidden(tester);
      engine.calls.clear();

      // A television's in-app volume is boost only - the set owns everything
      // below unity - so the walk is 100 to 200 and four presses cover it.
      for (final int expected in <int>[125, 150, 175, 200]) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(_volumes(engine).last, expected);
      }

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(_volumes(engine).last, 200, reason: 'and stops at the ceiling');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(_volumes(engine).last, 175);

      _expectHidden(tester, reason: 'the rail says it, not the bars');
      await _snapshot(tester, state: 'paused', position: 60000);
    });

    testWidgets('a D-pad seek holds the chrome, then lets it go', (
      tester,
    ) async {
      await _pumpControls(tester);

      // Up from play/pause is the scrubber; Right on the scrubber seeks.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(_primary.debugLabel, isNot('player-play-pause'));
      expect(_inChrome(_primary), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      // The seek bar commits a burst 500 ms after the last press and only then
      // may the clock restart, so at the old timeout the bars are still up and
      // a little later they are not.
      await tester.pump(_hideAfter);
      _expectShown(tester, reason: 'the seek held the clock');
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      _expectHidden(tester, reason: 'the seek ended; the clock re-armed');
    });

    // The hold the bar takes on seek start is counted and release() is the only
    // thing that gives one back, so every way out of a burst has to reach one.
    // Here the media is reopened on the same controller mid-burst: the duration
    // drops to zero and the scrubber's end callback is nulled before the 500 ms
    // commit fires, so nothing below can report the end and the bar reports it
    // itself.
    testWidgets('a burst the bar can no longer commit still releases the '
        'chrome', (tester) async {
      final chrome = ChromeVisibilityController(isPlaying: () => true);
      await _pumpControls(tester, chrome: chrome);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(chrome.isHeld, isTrue, reason: 'the burst holds the chrome');

      // The screen reopened the media on the same controller: no length yet.
      await _snapshot(tester, duration: 0);
      // Past the burst's commit timer, which now has nothing to commit to.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(
        chrome.isHeld,
        isFalse,
        reason: 'the seek is gone; the hold cannot outlive it',
      );
      await _letHide(tester);
      _expectHidden(tester, reason: 'the clock re-armed');

      await _snapshot(tester, state: 'paused');
      chrome.dispose();
    });

    // The player can also leave with a burst still in flight. The chrome is the
    // screen's and outlives these controls, so a hold left behind pins the next
    // media's bars up.
    testWidgets('the controls going away mid-burst release the chrome', (
      tester,
    ) async {
      final chrome = ChromeVisibilityController(isPlaying: () => true);
      await _pumpControls(tester, chrome: chrome);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(chrome.isHeld, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());

      expect(
        chrome.isHeld,
        isFalse,
        reason: 'the hold went out with the controls that took it',
      );
      chrome.dispose();
    });
  });

  /// Coverage, as opposed to the containment the group above pins.
  ///
  /// "Every arrow stays on a chrome node" is satisfied by a bar where half the
  /// buttons are islands nothing reaches. What a remote actually needs is that
  /// every control is *on the way* to somewhere, and the bar is wide: on a
  /// television it renders up to fifteen focus stops across two rows and a
  /// scrubber.
  ///
  /// Each walk is one direction in its own test on purpose.
  /// [DirectionalFocusTraversalPolicyMixin] keeps a history per scope and a
  /// reversal pops it rather than moving geometrically, so a test that turns
  /// round mid-walk measures the backtracking and not the layout — which
  /// reads, very convincingly, as a bar whose right-hand half is unreachable.
  group('VlcPlayerControls D-pad coverage on TV', () {
    /// Presses [key] until focus stops moving, and returns everywhere it went.
    Future<List<String>> walk(
      WidgetTester tester,
      LogicalKeyboardKey key, {
      int limit = 20,
    }) async {
      _byLabel('player-play-pause').requestFocus();
      await tester.pump();
      final trail = <String>[_focusedControl()];
      for (var i = 0; i < limit; i++) {
        await tester.sendKeyEvent(key);
        await tester.pump();
        final next = _focusedControl();
        if (next == trail.last) break;
        trail.add(next);
      }
      return trail;
    }

    testWidgets('Right from play/pause reaches every utility button', (
      tester,
    ) async {
      await _pumpControls(tester, onEnterPip: () {});
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      final trail = await walk(tester, LogicalKeyboardKey.arrowRight);

      // The transport group and then the whole right-hand group, in the order
      // _actions builds it. The clock is between them and is not in the trail
      // on purpose: it is a read-out, holds no focus node and is not a stop on
      // the way anywhere.
      expect(trail, <String>[
        l10n.pause,
        l10n.next,
        l10n.options,
        l10n.volume,
        l10n.torrentFiles,
        '1x',
        l10n.pip,
        l10n.resize,
      ]);
    });

    testWidgets('Left from play/pause has nowhere to go and stays', (
      tester,
    ) async {
      // Play/pause is the left end of the bar now: the seek pair that used to
      // sit outside it is in the centre cluster on a handset and nowhere else.
      await _pumpControls(tester, onEnterPip: () {});
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      final trail = await walk(tester, LogicalKeyboardKey.arrowLeft);

      expect(trail, <String>[l10n.pause]);
    });

    testWidgets('Up from play/pause reaches the scrubber and then Back', (
      tester,
    ) async {
      await _pumpControls(tester, onEnterPip: () {});
      final back = MaterialLocalizations.of(
        tester.element(find.byType(VlcPlayerControls)),
      ).backButtonTooltip;

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      final trail = await walk(tester, LogicalKeyboardKey.arrowUp);

      expect(trail, <String>[l10n.pause, '<player-seek-bar>', back]);
    });

    testWidgets('the skip chip joins that column without displacing Back', (
      tester,
    ) async {
      // The chip lives outside the chrome, bottom-right, and appears while the
      // bars may already be up. It has to be one more stop on the way to Back,
      // not a replacement for it: an intro is exactly when a viewer reaches for
      // Back, and the chip is on a clock.
      await _pumpControls(
        tester,
        onEnterPip: () {},
        skipSegments: <SkipSegment>[
          SkipSegment(type: SkipType.intro, startTime: 0, endTime: 90),
        ],
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final back = MaterialLocalizations.of(
        tester.element(find.byType(VlcPlayerControls)),
      ).backButtonTooltip;

      final trail = await walk(tester, LogicalKeyboardKey.arrowUp);

      expect(trail, contains(l10n.skipIntro));
      expect(trail, contains(back));
      expect(
        trail.indexOf(l10n.skipIntro),
        lessThan(trail.indexOf(back)),
        reason: 'the chip sits below the top bar, so it is met first',
      );
    });
  });

  // Requirement: a remote reaches every control, including the ones inside the
  // two dialogs. They are the newest surface in the player and the only one a
  // viewer opens *from* a remote, so an unreachable chip there is a value that
  // cannot be chosen at all.
  //
  // The slider is deliberately not in these trails: on a television it is a
  // read-out (`CustomSlider.focusable` is false) and the two step buttons are
  // what adjusts it, so Up/Down are never trapped inside it.
  group('the value dialogs on a remote', () {
    /// Walks [keys] from wherever the dialog opened and returns everywhere
    /// focus went, the entry point included.
    Future<Set<String>> walkDialog(
      WidgetTester tester,
      List<LogicalKeyboardKey> keys,
    ) async {
      final seen = <String>{_focusedControl()};
      for (final key in keys) {
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
        seen.add(_focusedControl());
      }
      return seen;
    }

    /// Down to the step row, left to its far button, down into the presets and
    /// right along them. One turn per axis, because
    /// [DirectionalFocusTraversalPolicyMixin] pops its history on a reversal
    /// and a walk that doubles back measures the backtracking instead.
    const List<LogicalKeyboardKey> sweep = <LogicalKeyboardKey>[
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowRight,
    ];

    testWidgets('the speed dialog: every preset and both steps', (
      tester,
    ) async {
      await _pumpControls(tester, isTv: true);
      await _tapControl(tester, find.byTooltip('1x'));
      await tester.pumpAndSettle();

      // It opens on Close, which is the one control here that changes nothing.
      expect(_focusedControl(), 'Close');

      expect(await walkDialog(tester, sweep), <String>{
        'Close',
        'Decrease',
        'Increase',
        '0.5x',
        '1x',
        '1.25x',
        '1.5x',
        '2x',
      });

      await _snapshot(tester, state: 'paused');
    });

    testWidgets('the volume dialog: the same shape, its own values', (
      tester,
    ) async {
      await _pumpControls(tester, isTv: true);
      await _tapControl(tester, find.byTooltip('Volume'));
      await tester.pumpAndSettle();

      // 100 % is the floor on a television, not the middle: the remote's
      // volume keys belong to the set, so the app has no business attenuating
      // underneath them and the dialog is a boost control.
      expect(await walkDialog(tester, sweep), <String>{
        'Close',
        'Decrease',
        'Increase',
        '100%',
        '125%',
        '150%',
        '175%',
        '200%',
      });

      await _snapshot(tester, state: 'paused');
    });

    testWidgets('a preset row never takes a second line to walk', (
      tester,
    ) async {
      // The reason the presets are a row of equal columns rather than a Wrap:
      // five chips at their natural width overflow the dialog, and a second
      // run is a band Left and Right cannot cross.
      await _pumpControls(tester, isTv: true);
      await _tapControl(tester, find.byTooltip('Volume'));
      await tester.pumpAndSettle();

      final tops = <double>{
        for (final label in <String>['100%', '125%', '150%', '175%', '200%'])
          tester.getRect(
            find.descendant(
              of: find.byKey(kPlayerPresetRowKey),
              matching: find.text(label),
            ),
          ).top,
      };
      expect(tops, hasLength(1), reason: 'one run, so one arrow walks it');

      await _snapshot(tester, state: 'paused');
    });
  });

  // The scrubber's own insets, as opposed to the bar's. The control row under
  // it is icon glyphs, and a glyph does not fill its button: the track is held
  // off each edge by roughly what the ink beside it is, so the two read as one
  // column rather than as a bar that overhangs its controls.
  group('VlcPlayerControls track alignment', () {
    /// The painted track, which is the first [AnimatedContainer] the seek bar
    /// lays down - the full-width background segment.
    Rect track(WidgetTester tester) => tester
        .renderObjectList<RenderBox>(
          find.descendant(
            of: find.byType(PlayerSeekBar),
            matching: find.byType(AnimatedContainer),
          ),
        )
        .map((b) => b.localToGlobal(Offset.zero) & b.size)
        .first;

    /// Every glyph box in the bottom bar, left to right.
    List<Rect> glyphs(WidgetTester tester) =>
        tester
            .renderObjectList<RenderBox>(
              find.descendant(
                of: find.byType(PlayerBottomBar),
                matching: find.byType(Icon),
              ),
            )
            .map((b) => b.localToGlobal(Offset.zero) & b.size)
            .toList()
          ..sort((a, b) => a.left.compareTo(b.left));

    for (final (String name, bool isTv, bool desktop, Size size)
        in <(String, bool, bool, Size)>[
          ('a desktop window', false, true, const Size(1280, 720)),
          ('a television', true, false, const Size(960, 540)),
        ]) {
      testWidgets('the track sits inside the control row on $name', (
        tester,
      ) async {
        await _pumpControls(
          tester,
          isTv: isTv,
          desktop: desktop,
          onEnterPip: () {},
          size: size,
        );
        await _snapshot(tester, position: 65000, duration: 300000);

        final Rect bar = track(tester);
        final List<Rect> row = glyphs(tester);

        expect(
          bar.left,
          greaterThan(row.first.left),
          reason: 'the track starts inside the first control, not before it',
        );
        expect(
          bar.right,
          lessThan(row.last.right),
          reason: 'and ends inside the last one',
        );
        // The trailing inset is the smaller of the two: off a television the
        // utility glyph's 44 dp box is itself centred inside a 48 dp tap
        // target, which is two more dp of slack at that end than the leading
        // control has. A symmetric inset left a visible gap at the right.
        expect(
          size.width - bar.right,
          lessThanOrEqualTo(bar.left),
          reason: 'measured from each edge of the bar, right is never looser',
        );

        await tester.pump(const Duration(seconds: 2));
        await _snapshot(tester, state: 'paused', position: 65000);
      });
    }

    testWidgets('the track does not shift when the scrubber takes focus', (
      tester,
    ) async {
      // The focus ring is drawn at a fixed width whether or not it is visible,
      // because a transparent Border still takes its space. The padding used
      // to give that width back on focus, which slid the whole track 2 dp
      // sideways the moment a remote landed on it.
      await _pumpControls(tester, isTv: true);
      await _snapshot(tester, position: 65000, duration: 300000);

      final Rect resting = track(tester);
      _scrubber().requestFocus();
      await tester.pumpAndSettle();

      expect(track(tester), resting);

      await _snapshot(tester, state: 'paused', position: 65000);
    });
  });

  // The wiring between the routing and the three places a volume can be
  // changed from. The arithmetic is volume_routing_test's; this is about the
  // widget obeying it.
  group('VlcPlayerControls volume routing', () {
    testWidgets('a handset moves the system stream and leaves libVLC alone', (
      tester,
    ) async {
      final engine = FakeVlcEngine();
      final system = _FakeSystemVolume();
      await _pumpControls(
        tester,
        isTv: false,
        engine: engine,
        systemVolume: system,
      );

      await _tapControl(tester, find.byTooltip('Volume'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('50%'));
      await tester.pumpAndSettle();

      expect(system.writes.last, 0.5);
      expect(
        _volumes(engine).every((v) => v == 100),
        isTrue,
        reason: 'libVLC stays at unity for everything under it',
      );

      await tester.pump(const Duration(seconds: 1));
      await _snapshot(tester, state: 'paused');
    });

    testWidgets('and hands the boost to libVLC over a system already full', (
      tester,
    ) async {
      final engine = FakeVlcEngine();
      final system = _FakeSystemVolume();
      await _pumpControls(
        tester,
        isTv: false,
        engine: engine,
        systemVolume: system,
      );

      await _tapControl(tester, find.byTooltip('Volume'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('200%'));
      await tester.pumpAndSettle();

      expect(_volumes(engine).last, 200);
      expect(system.writes.last, 1.0, reason: 'pinned at full underneath it');

      await tester.pump(const Duration(seconds: 1));
      await _snapshot(tester, state: 'paused');
    });

    testWidgets('the rocker moves the readout without the app asking', (
      tester,
    ) async {
      // The whole reason the level cannot simply be remembered: on a handset
      // the hardware keys change the stream behind the player's back.
      final system = _FakeSystemVolume();
      await _pumpControls(tester, isTv: false, systemVolume: system);

      system.rocker(0.3);
      await tester.pumpAndSettle();

      expect(
        find.byType(PlayerRail),
        findsOneWidget,
        reason: 'and the player says so, the way every other route does',
      );
      expect(tester.widget<PlayerRail>(find.byType(PlayerRail)).value, 0.3);
      expect(find.text('30%'), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      await _snapshot(tester, state: 'paused');
    });

    testWidgets('a desktop never touches the system stream', (tester) async {
      final engine = FakeVlcEngine();
      final system = _FakeSystemVolume();
      await _pumpControls(
        tester,
        isTv: false,
        desktop: true,
        desktopProfile: true,
        engine: engine,
        systemVolume: system,
      );

      await _tapControl(tester, find.byTooltip('Volume'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('50%'));
      await tester.pumpAndSettle();

      expect(_volumes(engine).last, 50, reason: 'all of it is libVLC gain');
      expect(
        system.writes,
        isEmpty,
        reason: 'the machine has a mixer of its own and it stays its own',
      );

      await tester.pump(const Duration(seconds: 1));
      await _snapshot(tester, state: 'paused');
    });

    testWidgets('a television boosts and never attenuates', (tester) async {
      final engine = FakeVlcEngine();
      final system = _FakeSystemVolume();
      await _pumpControls(tester, isTv: true, engine: engine, systemVolume: system);

      // The keyboard step, downwards, from the floor.
      await tester.sendKeyEvent(LogicalKeyboardKey.audioVolumeDown);
      await tester.pump();

      expect(
        _volumes(engine).every((v) => v >= 100),
        isTrue,
        reason: 'the set owns everything under unity; the app only amplifies',
      );
      expect(system.writes, isEmpty, reason: 'and the remote owns the stream');

      await tester.pump(const Duration(seconds: 1));
      await _snapshot(tester, state: 'paused');
    });
  });

  group('VlcPlayerControls list buttons', () {
    // Options and Files share one callback and one panel. Each opens
    // its initial tab and holds the chrome for the panel's life, so the control
    // focus returns to is still there when the panel pops.
    for (final (String Function(AppLocalizations) tooltip, PlayerPanelTab tab)
        in <(String Function(AppLocalizations), PlayerPanelTab)>[
          ((l10n) => l10n.options, PlayerPanelTab.sources),
          ((l10n) => l10n.torrentFiles, PlayerPanelTab.files),
        ]) {
      testWidgets('${tab.name}: opens the panel on its tab and holds the '
          'chrome until it closes', (tester) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final panel = Completer<void>();
        final opened = <PlayerPanelTab>[];
        await _pumpControls(
          tester,
          onOpenPanel: (tab) {
            opened.add(tab);
            return panel.future;
          },
        );

        await tester.tap(find.byTooltip(tooltip(l10n)));
        // The screen-wide detector also owns a double-tap, so a single tap on
        // a button resolves only after that recogniser gives up.
        await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
        expect(opened, <PlayerPanelTab>[tab]);

        _expectHidden(tester, reason: 'out of sight behind the panel');
        await _letHide(tester);
        await _letHide(tester);

        panel.complete();
        await tester.pumpAndSettle();
        _expectShown(tester, reason: 'the hold outlasted the clock');

        await _letHide(tester);
        await _letHide(tester);
        _expectHidden(tester, reason: 'and the clock has them again');
      });
    }

    testWidgets('Options opens the panel; no sheet remains', (tester) async {
      // The panel is the one surface for every list, so Back and focus obey one
      // set of rules everywhere.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final opened = <PlayerPanelTab>[];
      await _pumpControls(tester, onOpenPanel: (tab) async => opened.add(tab));

      await tester.tap(find.byTooltip(l10n.options));
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
      await tester.pump();

      expect(find.byType(BottomSheet), findsNothing);
      expect(opened, <PlayerPanelTab>[PlayerPanelTab.sources]);
    });

    // Absent, not disabled: focus must never land on a control whose list
    // does not exist. One helper decides both the strip and the bar.
    testWidgets('no Episodes or Files button without those tabs', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pumpControls(
        tester,
        panelTabs: const <PlayerPanelTab>{
          PlayerPanelTab.sources,
          PlayerPanelTab.audio,
          PlayerPanelTab.subtitles,
        },
      );

      expect(find.byTooltip(l10n.episodes), findsNothing);
      expect(find.byTooltip(l10n.torrentFiles), findsNothing);
      expect(find.byTooltip(l10n.options), findsOneWidget);
    });

    testWidgets('Options opens Audio when Sources is unavailable', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final opened = <PlayerPanelTab>[];
      await _pumpControls(
        tester,
        onOpenPanel: (tab) async => opened.add(tab),
        panelTabs: const <PlayerPanelTab>{
          PlayerPanelTab.audio,
          PlayerPanelTab.subtitles,
        },
      );

      expect(find.byTooltip(l10n.sources), findsNothing);
      expect(find.byTooltip(l10n.audioTracks), findsNothing);
      expect(find.byTooltip(l10n.subtitles), findsNothing);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      await tester.tap(find.byTooltip(l10n.options));
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
      expect(opened, <PlayerPanelTab>[PlayerPanelTab.audio]);
    });

    testWidgets('hiding episode navigation keeps Options available', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pumpControls(
        tester,
        settings: const PlayerSettings(showEpisodes: false),
      );

      expect(find.byTooltip(l10n.episodes), findsNothing);
      expect(find.byTooltip(l10n.next), findsNothing);
      expect(find.byTooltip(l10n.options), findsOneWidget);
    });

    testWidgets('hiding Volume keeps Options and keyboard volume available', (
      tester,
    ) async {
      final engine = FakeVlcEngine();
      await _pumpControls(
        tester,
        engine: engine,
        isTv: false,
        desktopProfile: true,
        settings: const PlayerSettings(showVolume: false),
      );
      expect(find.byTooltip('Volume'), findsNothing);
      expect(find.byTooltip('Options'), findsOneWidget);
      engine.calls.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.pump();
      expect(_volumes(engine), [0]);
      await _snapshot(tester, state: 'paused');
    });

    testWidgets('episode navigation visibility does not gate the panel', (
      tester,
    ) async {
      final opened = <PlayerPanelTab>[];
      await _pumpControls(
        tester,
        settings: const PlayerSettings(showEpisodes: false),
        panelTabs: const {PlayerPanelTab.episodes},
        onOpenPanel: (tab) async => opened.add(tab),
      );
      await tester.tap(find.byTooltip('Options'));
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
      expect(opened, [PlayerPanelTab.episodes]);
    });

    testWidgets('with no panel to open there is no list button at all', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pumpControls(tester, withoutPanel: true);

      for (final tooltip in <String>[l10n.options, l10n.torrentFiles]) {
        expect(find.byTooltip(tooltip), findsNothing, reason: tooltip);
      }
      expect(find.byTooltip(l10n.pause), findsOneWidget);
    });
  });

  group('VlcPlayerControls with an injected chrome controller', () {
    // The screen drops the chrome on Back before it pops and holds it while a
    // panel is up, so the controls follow a controller they did not make - and
    // must not dispose it, since the screen outlives them across every failover
    // and episode advance.
    testWidgets('the bars follow it and it survives the controls', (
      tester,
    ) async {
      final chrome = ChromeVisibilityController(isPlaying: () => true);
      await _pumpControls(tester, chrome: chrome);
      _expectShown(tester);

      chrome.toggle();
      await tester.pump();
      _expectHidden(tester, reason: 'hidden from outside the controls');

      chrome.poke();
      await tester.pump();
      _expectShown(tester, reason: 'revealed from outside the controls');

      await tester.pumpWidget(const SizedBox.shrink());
      // A disposed notifier refuses new listeners; a live one takes them, and
      // its hide clock is still armed, so the screen that made it has to be the
      // one to stop it.
      expect(() => chrome.addListener(() {}), returnsNormally);
      expect(chrome.value, isTrue);
      chrome.dispose();
    });
  });

  group('VlcPlayerControls during a stall', () {
    // Off Android, libVLC keeps reporting `playing` through a rebuffer, so a
    // spinner keyed on the state never shows. The controller raises isStalled
    // from the position clock instead and the chrome has to read it. On Android
    // the engine does say `buffering` and playback resumes on its own, so the
    // glyph must keep offering pause rather than claim the player is stopped.
    testWidgets('a frozen clock shows the spinner; motion clears it', (
      tester,
    ) async {
      final controller = await _pumpControls(tester);
      await _snapshot(tester, position: 1000);
      await _snapshot(tester, position: 1000);
      expect(find.byType(PlayerBufferingIndicator), findsNothing);

      await tester.pump(controller.stallIndicatorDelay);
      expect(controller.value.isStalled, isTrue);
      expect(controller.value.isBuffering, isFalse);
      expect(
        find.byType(PlayerBufferingIndicator),
        findsOneWidget,
        reason: 'the spinner follows the stall, not the libVLC state',
      );

      await _snapshot(tester, position: 2000);
      expect(controller.value.isStalled, isFalse);
      expect(find.byType(PlayerBufferingIndicator), findsNothing);

      // A playing controller keeps its stall watchdog armed, and flutter_test
      // checks for pending timers before the harness's tearDown disposes it.
      // Pause parks the clock.
      await _snapshot(tester, state: 'paused', position: 2000);
    });

    testWidgets('a rebuffer keeps the pause glyph', (tester) async {
      await _pumpControls(tester);
      await _snapshot(tester, position: 1000);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // Same position as the last tick: an advancing one would be the
      // healthy-playback flap the value layer corrects back to `playing`.
      await _snapshot(tester, state: 'buffering', position: 1000);
      expect(find.byType(PlayerBufferingIndicator), findsOneWidget);
      expect(
        find.byIcon(Icons.pause_rounded),
        findsOneWidget,
        reason: 'playback will resume, so the button still offers pause',
      );
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);

      // The engine catches up: the spinner goes and the glyph never moved.
      await _snapshot(tester, position: 2000);
      expect(find.byType(PlayerBufferingIndicator), findsNothing);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // A playing controller keeps its stall watchdog armed, and flutter_test
      // checks for pending timers before the harness's tearDown disposes it.
      // Pause parks the clock.
      await _snapshot(tester, state: 'paused', position: 2000);
    });
  });

  group('VlcPlayerControls keyboard on desktop', () {
    testWidgets('the scrubber keeps its compact size off TV', (tester) async {
      await _pumpControls(tester, isTv: false, desktop: true);
      expect(tester.getSize(find.byType(PlayerSeekBar)).height, 26);
    });

    // Space is the activation key for whatever is focused. Claiming it as a
    // global play/pause toggle means Space on a focused Next button toggles
    // playback instead of pressing Next. K and the media keys stay global.
    testWidgets('Space presses the focused button, and toggles playback only '
        'from the sink', (tester) async {
      final engine = FakeVlcEngine();
      var nextPressed = 0;
      await _pumpControls(
        tester,
        isTv: false,
        desktop: true,
        onNextEpisode: () => nextPressed++,
        engine: engine,
      );
      engine.calls.clear();

      _button(tester, 'Next').requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(nextPressed, 1, reason: 'Space activates the focused button');
      expect(
        engine.methods.where((m) => m == 'play' || m == 'pause'),
        isEmpty,
        reason: 'playback was not touched',
      );

      _byLabel('player-key-sink').requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(
        engine.methods,
        contains('pause'),
        reason: 'bare Space toggles playback',
      );
      expect(nextPressed, 1);
    });

    // Space is both the bare play/pause toggle and the hold-to-2x key, the way
    // tap and long-press share the video surface: the down press claims the key
    // and commits to nothing, the first auto-repeat starts the boost, and the
    // release either gives the speed back or - never having repeated - is the
    // toggle. Toggling on the down press instead pauses the film under a viewer
    // who meant to skim, and it is still paused when they let go.
    testWidgets('holding Space runs at 2x, and the release gives it back', (
      tester,
    ) async {
      final engine = FakeVlcEngine();
      await _pumpControls(tester, isTv: false, desktop: true, engine: engine);
      _byLabel('player-key-sink').requestFocus();
      await tester.pump();
      engine.calls.clear();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(
        engine.methods,
        isEmpty,
        reason: 'the down press only claims the key; the release decides',
      );

      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(_speeds(engine), <double>[2.0]);
      expect(find.text('2x'), findsOneWidget);
      expect(
        engine.methods.where((m) => m == 'play' || m == 'pause'),
        isEmpty,
        reason: 'a hold is not a toggle',
      );

      // Idempotent: a key held down repeats many times over, and every
      // further repeat must be a poke and nothing else.
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(_speeds(engine), <double>[2.0]);

      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(_speeds(engine), <double>[
        2.0,
        1.0,
      ], reason: 'the release restores the speed the hold interrupted');
      expect(find.text('2x'), findsNothing);
      expect(
        engine.methods.where((m) => m == 'play' || m == 'pause'),
        isEmpty,
        reason: 'a release that ended a hold is not also a tap',
      );

      await _snapshot(tester, state: 'paused');
    });

    // The same guard the tap has, on the other two events. Space belongs to
    // whatever is focused, so a held Space on a focused button must repeat
    // that button and never touch the playback rate.
    testWidgets('holding Space on a focused button never boosts', (
      tester,
    ) async {
      final engine = FakeVlcEngine();
      var nextPressed = 0;
      await _pumpControls(
        tester,
        isTv: false,
        desktop: true,
        onNextEpisode: () => nextPressed++,
        engine: engine,
      );
      _button(tester, 'Next').requestFocus();
      await tester.pump();
      engine.calls.clear();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pump();
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(_speeds(engine), isEmpty, reason: 'Space belonged to the button');
      expect(
        engine.methods.where((m) => m == 'play' || m == 'pause'),
        isEmpty,
        reason: 'and the release is not a deferred toggle either',
      );
      expect(nextPressed, greaterThanOrEqualTo(1));

      await _snapshot(tester, state: 'paused');
    });
  });

  group('VlcPlayerControls wheel on desktop', () {
    /// One notch over [target]. The magnitude is whatever the platform sends
    /// and only the sign is portable, so these are deliberately round numbers
    /// rather than a real device's.
    /// The middle of the frame, which on a desktop window is video: there is
    /// no centre cluster there off touch.
    final Finder video = find.byType(VlcPlayerControls);

    Future<void> wheel(
      WidgetTester tester,
      Finder target, {
      double dy = 0,
      double dx = 0,
    }) async {
      final centre = tester.getCenter(target);
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      pointer.hover(centre);
      await tester.sendEventToBinding(
        pointer.scroll(Offset(dx, dy)),
      );
      await tester.pump();
    }

    testWidgets('the wheel over the video is volume, as it is in VLC', (
      tester,
    ) async {
      final engine = FakeVlcEngine();
      await _pumpControls(tester, isTv: false, desktop: true, engine: engine);

      await wheel(tester, video, dy: -1);
      expect(_volumes(engine).last, 105, reason: 'up is louder');

      await wheel(tester, video, dy: 1);
      expect(_volumes(engine).last, 100);

      await _snapshot(tester, state: 'paused');
    });

    testWidgets('shift turns that wheel into a seek', (tester) async {
      final engine = FakeVlcEngine();
      await _pumpControls(tester, isTv: false, desktop: true, engine: engine);
      await _snapshot(tester, position: 65000, duration: 300000);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await wheel(tester, video, dy: -1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

      expect(_seeks(engine), <int>[75000], reason: '65 s + one 10 s step');
      expect(_volumes(engine), isEmpty, reason: 'and the volume is untouched');

      await tester.pump(const Duration(seconds: 2));
      await _snapshot(tester, state: 'paused', position: 65000);
    });

    testWidgets('a horizontal scroll seeks without shift', (tester) async {
      // A trackpad's two-finger swipe sideways over a timeline means one
      // thing, so it does not need a modifier to say so.
      final engine = FakeVlcEngine();
      await _pumpControls(tester, isTv: false, desktop: true, engine: engine);
      await _snapshot(tester, position: 65000, duration: 300000);

      await wheel(tester, video, dx: 1);

      expect(_seeks(engine), <int>[75000], reason: 'right is forward');
      expect(_volumes(engine), isEmpty);

      await tester.pump(const Duration(seconds: 2));
      await _snapshot(tester, state: 'paused', position: 65000);
    });

    testWidgets('the wheel over the scrubber seeks, and the overlay does not '
        'take the same notch', (tester) async {
      // The resolver hands one pointer signal to one widget. Without it the
      // bar would seek and the overlay behind it would change the volume off
      // the same spin.
      final engine = FakeVlcEngine();
      await _pumpControls(tester, isTv: false, desktop: true, engine: engine);
      await _snapshot(tester, position: 65000, duration: 300000);

      await wheel(tester, find.byType(PlayerSeekBar), dy: -1);
      // The bar coalesces a spin the way it coalesces a held D-pad, so the
      // seek lands once the burst has settled rather than once per notch.
      await tester.pump(const Duration(milliseconds: 600));

      expect(_seeks(engine), <int>[75000]);
      expect(_volumes(engine), isEmpty, reason: 'the overlay stayed out of it');

      await tester.pump(const Duration(seconds: 2));
      await _snapshot(tester, state: 'paused', position: 65000);
    });

    testWidgets('a handset has no wheel handler at all', (tester) async {
      // Null rather than guarded inside: nothing is registered with the
      // resolver on a device that cannot produce a scroll.
      await _pumpControls(tester, isTv: false, desktop: false);

      final Listener outer = tester.widgetList<Listener>(
        find.descendant(
          of: find.byType(VlcPlayerControls),
          matching: find.byType(Listener),
        ),
      ).first;
      expect(outer.onPointerSignal, isNull);

      await _snapshot(tester, state: 'paused');
    });
  });

  group('VlcPlayerControls mouse on desktop', () {
    testWidgets('a moving mouse reveals hidden chrome; a resting one does '
        'not keep it up', (tester) async {
      await _pumpControls(tester, isTv: false, desktop: true);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      final centre = tester.getCenter(find.byType(VlcPlayerControls));
      await mouse.addPointer(location: centre);
      await tester.pump();

      // The cursor sits on the video the whole time the clock runs.
      await _letHide(tester);
      _expectHidden(tester, reason: 'a stationary cursor is not activity');

      await mouse.moveTo(centre + const Offset(40, 0));
      await tester.pump();
      _expectShown(tester);
    });

    testWidgets('the bars do not go while the mouse rests on them', (
      tester,
    ) async {
      await _pumpControls(tester, isTv: false, desktop: true);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(
        location: tester.getCenter(find.byTooltip('Pause')),
      );
      await tester.pump();

      await _letHide(tester);
      _expectShown(tester, reason: 'hovering a bar holds it');

      await mouse.moveTo(tester.getCenter(find.byType(VlcPlayerControls)));
      await tester.pump();
      await _letHide(tester);
      _expectHidden(tester, reason: 'leaving the bar re-arms the clock');
    });

    testWidgets('the cursor hides with the chrome and returns with it', (
      tester,
    ) async {
      final kinds = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.mouseCursor,
        (call) async {
          if (call.method == 'activateSystemCursor') {
            kinds.add(
              (call.arguments as Map<Object?, Object?>)['kind']! as String,
            );
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.mouseCursor,
          null,
        ),
      );

      await _pumpControls(tester, isTv: false, desktop: true);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      final centre = tester.getCenter(find.byType(VlcPlayerControls));
      await mouse.addPointer(location: centre);
      await tester.pump();
      expect(kinds.last, 'basic', reason: 'visible chrome defers the cursor');

      await _letHide(tester);
      _expectHidden(tester);
      expect(kinds.last, 'none');

      await mouse.moveTo(centre + const Offset(40, 0));
      await tester.pump();
      await tester.pump();
      _expectShown(tester);
      expect(kinds.last, 'basic');
    });

    // Flutter deliberately does not deliver MouseRegion.onExit when the region
    // is unmounted with the pointer still inside it, and the bar goes out from
    // under the cursor every time the controls leave. The chrome outlives them,
    // so a stranded hold pins the next media's bars up for good.
    testWidgets('the controls going away under the cursor give the hover '
        'hold back', (tester) async {
      final chrome = ChromeVisibilityController(isPlaying: () => true);
      await _pumpControls(tester, isTv: false, desktop: true, chrome: chrome);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(
        location: tester.getCenter(find.byTooltip('Pause')),
      );
      await tester.pump();
      expect(chrome.isHeld, isTrue, reason: 'hovering a bar holds the chrome');

      await tester.pumpWidget(const SizedBox.shrink());

      expect(
        chrome.isHeld,
        isFalse,
        reason: 'the hold went out with the bar that took it',
      );
      chrome.dispose();
    });

    // The hovered subtree can also go while the controls stay: hover exists
    // only where a window can toggle fullscreen, so withdrawing that affordance
    // takes the region out from under a pointer that is still there. The
    // release belongs to whatever owns the region.
    testWidgets('a hovered bar taken away on its own gives the hold back, '
        'and the clock re-arms', (tester) async {
      final chrome = ChromeVisibilityController(isPlaying: () => true);
      final controller = await _pumpControls(
        tester,
        isTv: false,
        desktop: true,
        chrome: chrome,
      );
      final state = tester.state(find.byType(VlcPlayerControls));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(
        location: tester.getCenter(find.byTooltip('Pause')),
      );
      await tester.pump();
      expect(chrome.isHeld, isTrue, reason: 'hovering a bar holds the chrome');

      await tester.pumpWidget(
        _host(
          VlcPlayerControls(
            controller: controller,
            chrome: chrome,
            title: 'The Body',
            subtitle: 'S5 E16',
            onBack: () {},
            onNextEpisode: () {},
            onOpenPanel: _noPanel,
            panelTabs: _allTabs,
            onToggleFullscreen: null,
          ),
          isTv: false,
        ),
      );
      await tester.pump();

      expect(
        tester.state(find.byType(VlcPlayerControls)),
        same(state),
        reason: 'only the hover region went; the controls are still here',
      );
      expect(
        chrome.isHeld,
        isFalse,
        reason: 'the hold cannot outlive the region that took it',
      );
      await _letHide(tester);
      _expectHidden(tester, reason: 'the clock re-armed');
      chrome.dispose();
    });
  });

  group('VlcPlayerControls relative seeks', () {
    // The engine's read-back of a seek arrives a snapshot later, so a second
    // step inside that window counts from the last target rather than from the
    // stale position it would otherwise undo. The window is as long as the
    // progress bar latches, stallIndicatorDelay + 500 ms; after it the base is
    // the controller's own position again.
    testWidgets('a second L before the engine answers counts from the first '
        'target, and from the truth once the window closes', (tester) async {
      final engine = FakeVlcEngine();
      final controller = await _pumpControls(
        tester,
        isTv: false,
        desktop: true,
        engine: engine,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      // The second reaches the engine once the presses stop.
      await tester.pump(VlcPlayerController.seekMergeWindow);
      expect(_seeks(engine), [10000, 20000], reason: 'chained, not undone');

      // No snapshot ever comes. Past the window the base is the controller
      // again, whose position is still 0: the truth, not a guess.
      await tester.pump(
        controller.stallIndicatorDelay + const Duration(milliseconds: 600),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pump();
      expect(_seeks(engine), [10000, 20000, 10000]);

      await _snapshot(tester, state: 'paused', position: 10000);
    });

    testWidgets('two double-taps on the right half accumulate', (tester) async {
      final engine = FakeVlcEngine();
      await _pumpControls(tester, isTv: false, engine: engine);
      final right =
          tester.getCenter(find.byType(VlcPlayerControls)) +
          const Offset(400, 0);

      // Every pointer-down arms the double-tap recogniser's 40 ms minimum-gap
      // countdown, which nothing cancels; the trailing pump lets it lapse so
      // the test does not end with it pending.
      Future<void> doubleTap() async {
        await tester.tapAt(right);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(right);
        await tester.pump(const Duration(milliseconds: 50));
      }

      await doubleTap();
      expect(_seeks(engine), [10000]);
      await doubleTap();
      // Too close behind the first to go at once: it reaches the engine when
      // the taps stop.
      await tester.pump(VlcPlayerController.seekMergeWindow);
      expect(_seeks(engine), [10000, 20000]);

      await _snapshot(tester, state: 'paused', position: 20000);
    });

    // A screen-centred pill says nothing about which half was tapped, so a
    // viewer who hit the wrong side gets a confirmation that looks exactly like
    // a correct one.
    testWidgets('a double-tap on the right half shows a forward burst, not '
        'the centre pill', (tester) async {
      final engine = FakeVlcEngine();
      await _pumpControls(tester, isTv: false, engine: engine);
      final centre = tester.getCenter(find.byType(VlcPlayerControls));
      final right = centre + const Offset(400, 0);

      Future<void> doubleTap(Offset at) async {
        await tester.tapAt(at);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(at);
        await tester.pump(const Duration(milliseconds: 50));
      }

      await doubleTap(right);
      expect(_seeks(engine), [10000]);
      expect(find.byType(PlayerToast), findsNothing, reason: 'no centre pill');
      final burst = tester.widget<PlayerSeekBurst>(
        find.byType(PlayerSeekBurst),
      );
      expect(burst.forward, isTrue, reason: 'the right half was tapped');
      expect(find.text('10s'), findsOneWidget);

      // Measured off the readout, not off PlayerSeekBurst: its outermost widget
      // is an Align, which takes the whole viewport and is centred by
      // definition.
      expect(
        tester.getCenter(find.text('10s')).dx,
        greaterThan(centre.dx),
        reason: 'the readout says which half fired by being on it',
      );
      // Nor on the centre play/pause, the other thing living in the middle of
      // a touch frame.
      expect(
        tester
            .getRect(find.byType(PlayerCenterPlayButton))
            .overlaps(tester.getRect(find.text('10s'))),
        isFalse,
        reason: 'the burst and the centre glyph must not sit on each other',
      );

      await doubleTap(right);
      expect(
        find.text('20s'),
        findsOneWidget,
        reason: 'the chain total, not the bare step',
      );
      expect(find.text('10s'), findsNothing);
      await tester.pump(VlcPlayerController.seekMergeWindow);
      expect(_seeks(engine), [10000, 20000]);

      await _snapshot(tester, state: 'paused', position: 20000);
    });

    testWidgets('and the left half gets a backward burst on its own side', (
      tester,
    ) async {
      final engine = FakeVlcEngine();
      await _pumpControls(tester, isTv: false, engine: engine);
      await _snapshot(tester, position: 30000, duration: 120000);
      final centre = tester.getCenter(find.byType(VlcPlayerControls));
      final left = centre - const Offset(400, 0);

      await tester.tapAt(left);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(left);
      await tester.pump(const Duration(milliseconds: 50));

      expect(_seeks(engine), [20000]);
      final burst = tester.widget<PlayerSeekBurst>(
        find.byType(PlayerSeekBurst),
      );
      expect(burst.forward, isFalse);
      expect(find.text('10s'), findsOneWidget);
      expect(
        tester.getCenter(find.text('10s')).dx,
        lessThan(centre.dx),
        reason: 'the readout says which half fired by being on it',
      );

      await _snapshot(tester, state: 'paused', position: 20000);
    });

    testWidgets('J and L read out the way every other seek does', (
      tester,
    ) async {
      final engine = FakeVlcEngine();
      await _pumpControls(tester, isTv: false, engine: engine);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pump();
      var burst = tester.widget<PlayerSeekBurst>(find.byType(PlayerSeekBurst));
      expect(burst.forward, isTrue);
      expect(burst.seconds, 10);
      expect(
        find.text('+10s'),
        findsNothing,
        reason: 'the centred pill is gone from seeking entirely',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.pump();
      burst = tester.widget<PlayerSeekBurst>(find.byType(PlayerSeekBurst));
      expect(burst.forward, isFalse, reason: 'drawn on the side it moved to');
      expect(burst.seconds, 0, reason: 'back to the start');

      // The J reaches the engine once the presses stop.
      await tester.pump(VlcPlayerController.seekMergeWindow);
      expect(_seeks(engine), [10000, 0]);
      await _snapshot(tester, state: 'paused');
    });

    // On a pad the shoulder buttons are the whole seek affordance. They route
    // through the same _seekBy as J and L rather than a parallel mechanism, so
    // they inherit the chain window and the readout.
    testWidgets(
      'LB and RB seek by the configured step and chain like J and L',
      (tester) async {
        final engine = FakeVlcEngine();
        await _pumpControls(tester, engine: engine);
        await _snapshot(tester, position: 10000);
        engine.calls.clear();

        await _shoulder(tester, LogicalKeyboardKey.gameButtonRight1);
        expect(_seeks(engine), <int>[20000]);

        // Still inside the window and no snapshot has come back: the second
        // press counts from the first target, exactly as a second L does. It
        // reaches the engine once the presses stop.
        await _shoulder(tester, LogicalKeyboardKey.gameButtonRight1);
        expect(
          tester.widget<PlayerSeekBurst>(find.byType(PlayerSeekBurst)).seconds,
          20,
          reason: 'the shared readout, counting the whole chain',
        );
        await tester.pump(VlcPlayerController.seekMergeWindow);
        expect(_seeks(engine), <int>[
          20000,
          30000,
        ], reason: 'chained, not undone');

        await _shoulder(tester, LogicalKeyboardKey.gameButtonLeft1);
        final back = tester.widget<PlayerSeekBurst>(
          find.byType(PlayerSeekBurst),
        );
        expect(back.forward, isFalse);
        // Signed in the direction of the press, which is [SeekBurst.seconds]'s
        // existing convention: the chain is still 10 s ahead of where it
        // started, and this press went the other way.
        expect(back.seconds, -10);
        await tester.pump(VlcPlayerController.seekMergeWindow);
        expect(_seeks(engine), <int>[20000, 30000, 20000]);

        await _snapshot(tester, state: 'paused', position: 20000);
      },
    );

    // A shoulder button has no traversal meaning and no activation meaning,
    // which is exactly why it is bound: unlike a bare arrow it does not have
    // to be given up to the focus system when a control is focused, and
    // unlike a bare arrow on television it is not spent revealing the chrome.
    testWidgets('a shoulder press seeks with a control focused, and the press '
        'that wakes the bars seeks too', (tester) async {
      final engine = FakeVlcEngine();
      await _pumpControls(tester, engine: engine);
      expect(_primary.debugLabel, 'player-play-pause');
      engine.calls.clear();

      await _shoulder(tester, LogicalKeyboardKey.gameButtonRight1);
      expect(_seeks(engine), <int>[
        10000,
      ], reason: 'the focused play/pause is not a traversal stop for LB/RB');
      expect(
        engine.methods.where((m) => m == 'play' || m == 'pause'),
        isEmpty,
        reason: 'the button under focus was not pressed',
      );

      // Past the chain window, so the second press counts from the engine's
      // position - still 0 - rather than from the first target.
      await _letHide(tester);
      _expectHidden(tester);

      await _shoulder(tester, LogicalKeyboardKey.gameButtonRight1);
      expect(
        _seeks(engine),
        <int>[10000, 10000],
        reason:
            'a bare arrow on TV is spent on the reveal; a shoulder button is '
            'unambiguous and seeks as well',
      );
      _expectShown(tester);

      await _snapshot(tester, state: 'paused', position: 10000);
    });

    // The scrubber is reachable throughout the chain window, and a click on the
    // track lands somewhere the chain knows nothing about that the engine will
    // not publish for a round trip. The next arrow must step on from the click,
    // not from the chain's stale target and not from the pre-click position.
    testWidgets('a scrubber commit inside the window re-bases the chain, and '
        'the readout counts from there', (tester) async {
      final engine = FakeVlcEngine();
      await _pumpControls(tester, isTv: false, desktop: true, engine: engine);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pump();
      expect(_seeks(engine), [10000]);
      expect(
        tester.widget<PlayerSeekBurst>(find.byType(PlayerSeekBurst)).seconds,
        10,
      );

      // A click near the head of the track, well inside the chain's window.
      final track = tester.getRect(find.byType(PlayerSeekBar));
      await tester.tapAt(Offset(track.left + 24, track.center.dy));
      // The screen-wide double-tap recogniser holds the arena open for its
      // 300 ms gap before the scrubber's tap can win it and commit. So soon
      // after the L, the click reaches the engine once the seeks stop.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(VlcPlayerController.seekMergeWindow);
      final clicked = _seeks(engine).last;
      expect(clicked, lessThan(5000), reason: 'the click is near the start');

      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pump();
      expect(
        tester.widget<PlayerSeekBurst>(find.byType(PlayerSeekBurst)).seconds,
        10,
        reason: 'the readout counts from the click too, not from the chain',
      );

      await tester.pump(VlcPlayerController.seekMergeWindow);
      expect(_seeks(engine), [
        10000,
        clicked,
        clicked + 10000,
      ], reason: 'the arrow steps on from the click, not from the old chain');

      await _snapshot(tester, state: 'paused', position: clicked + 10000);
    });

    testWidgets('a swipe on an unseekable input never seeks', (tester) async {
      final engine = FakeVlcEngine();
      await _pumpControls(tester, isTv: false, engine: engine);
      await _snapshot(tester, position: 1000, isSeekable: false);
      final centre = tester.getCenter(find.byType(VlcPlayerControls));

      // The 50 ms lets the double-tap recogniser's minimum-gap countdown,
      // armed by the pointer-down, lapse before the test ends.
      await tester.dragFrom(centre, const Offset(300, 0));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        engine.callsTo('seekTo'),
        isEmpty,
        reason: 'libVLC would drop the seek silently; better not to ask',
      );

      // The same swipe on a seekable one does seek, so the gate - not the
      // gesture arena - is what kept the first one quiet.
      await _snapshot(tester, position: 1000, isSeekable: true);
      await tester.dragFrom(centre, const Offset(300, 0));
      await tester.pump(const Duration(milliseconds: 50));
      expect(_seeks(engine), hasLength(1));
      expect(_seeks(engine).single, greaterThan(1000));

      await _snapshot(tester, state: 'paused', position: 1000);
    });
  });

  // Touch gets a centred play/pause. The alternative is a 40 px glyph in the
  // bottom-left corner beside the scrubber, with the largest and emptiest part
  // of the screen doing nothing but toggle the bars.
  group('VlcPlayerControls centre play/pause on touch', () {
    testWidgets('the touch build has one and the remote build does not', (
      tester,
    ) async {
      await _pumpControls(tester, isTv: false);
      expect(find.byType(PlayerCenterPlayButton), findsOneWidget);

      // No FocusNode anywhere inside it: it is not a traversal candidate, so
      // it cannot compete with the autofocus play/pause owns on television and
      // it cannot become an invisible stop in the middle of the frame.
      expect(
        find.descendant(
          of: find.byType(PlayerCenterPlayButton),
          matching: find.byType(Focus),
        ),
        findsNothing,
      );
    });

    testWidgets('television gets nothing in the middle of the frame', (
      tester,
    ) async {
      await _pumpControls(tester);
      expect(
        find.byType(PlayerCenterPlayButton),
        findsNothing,
        reason:
            'Select already toggles playback and play/pause already '
            'autofocuses; a control in the centre is pure downside on a remote',
      );
    });

    testWidgets('and neither does desktop, where the pointer is precise', (
      tester,
    ) async {
      await _pumpControls(tester, isTv: false, desktop: true);
      expect(find.byType(PlayerCenterPlayButton), findsNothing);
    });

    testWidgets('tapping it toggles playback and leaves focus on the sink', (
      tester,
    ) async {
      final engine = FakeVlcEngine();
      await _pumpControls(tester, isTv: false, engine: engine);

      await tester.tap(find.byType(PlayerCenterPlayButton));
      // The screen-wide detector owns a double-tap, so the single tap resolves
      // only once that recogniser gives up. The ~300 ms is kept deliberately:
      // escaping it needs an opaque hit test, which would kill swipe-seek from
      // dead centre.
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));

      expect(
        engine.callsTo('pause'),
        hasLength(1),
        reason: 'the glyph wins the arena over the chrome toggle beneath it',
      );
      _expectShown(tester, reason: 'a press on a control is not a hide');
      expect(
        _primary,
        same(_byLabel('player-key-sink')),
        reason: 'it takes no focus of its own; the sink still holds the keys',
      );

      await _snapshot(tester, state: 'paused');
    });

    testWidgets('one Tab lands on a chrome control, never on the glyph', (
      tester,
    ) async {
      await _pumpControls(tester, isTv: false);
      expect(_primary, same(_byLabel('player-key-sink')));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(
        _inChrome(_primary),
        isTrue,
        reason: 'traversal walks the bars, which is where the controls are',
      );
      expect(
        find.descendant(
          of: find.byType(PlayerCenterPlayButton),
          matching: find.byType(Focus),
        ),
        findsNothing,
        reason: 'there is no node here for Tab to have landed on',
      );

      await _snapshot(tester, state: 'paused');
    });

    // The glyph sits outside `_bars`, so nothing else withdraws it when the
    // chrome goes: without its own IgnorePointer it is an invisible 88 px
    // circle in the dead centre that eats the tap-to-reveal, which is the only
    // way back on a phone.
    testWidgets('with the bars down it is inert and the tap still reveals', (
      tester,
    ) async {
      final engine = FakeVlcEngine();
      await _pumpControls(tester, isTv: false, engine: engine);

      await _letHide(tester);
      _expectHidden(tester);

      await tester.tapAt(tester.getCenter(find.byType(VlcPlayerControls)));
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));

      expect(
        engine.callsTo('pause'),
        isEmpty,
        reason: 'an invisible glyph must not answer a tap',
      );
      _expectShown(tester, reason: 'the tap reached the chrome toggle beneath');

      await _snapshot(tester, state: 'paused');
    });

    // The toast is a later child of the same Stack as the glyph, so left
    // centred it paints unreadably on the disc. Hiding the glyph for the length
    // of a drag would be a setState at pointer rate, which the controls'
    // compositing contract forbids, so the toast moves instead - and only where
    // there is a glyph to move off.
    testWidgets('the toast is nudged clear of the glyph, not painted onto it', (
      tester,
    ) async {
      await _pumpControls(tester, isTv: false);
      final centre = tester.getCenter(find.byType(VlcPlayerControls));
      final glyph = tester.getRect(find.byType(PlayerCenterPlayButton));

      await tester.dragFrom(centre, const Offset(300, 0));
      await tester.pump();

      final message = find.descendant(
        of: find.byType(PlayerToast),
        matching: find.byType(Text),
      );
      expect(message, findsOneWidget);
      expect(
        tester.getRect(message).overlaps(glyph),
        isFalse,
        reason: 'the swipe readout is unreadable on top of the disc',
      );

      // The 50 ms lets the double-tap recogniser's minimum-gap countdown lapse.
      await tester.pump(const Duration(milliseconds: 50));
      await _snapshot(tester, state: 'paused', position: 1000);
    });

    testWidgets('and stays dead centre where there is no glyph to avoid', (
      tester,
    ) async {
      await _pumpControls(tester, isTv: false, desktop: true);
      expect(find.byType(PlayerCenterPlayButton), findsNothing);

      // Any toast will do; this one is the aspect-ratio label. A seek used to
      // be the convenient trigger here, but seeking now draws the side burst
      // rather than the centred pill, and the pill is what this measures.
      await _tapControl(tester, find.byTooltip('Resize'));
      await tester.pump();

      final message = find.descendant(
        of: find.byType(PlayerToast),
        matching: find.byType(Text),
      );
      expect(
        tester.getCenter(message).dy,
        moreOrLessEquals(
          tester.getCenter(find.byType(VlcPlayerControls)).dy,
          epsilon: 0.5,
        ),
      );

      await _snapshot(tester, state: 'paused');
    });

    // A rebuffer keeps offering pause, exactly as the bottom bar's copy does -
    // the film resumes without a press. A stall draws the spinner instead, and
    // the glyph collapses so the two never draw a disc around each other.
    testWidgets('a rebuffer keeps pause; a stall hands the centre to the '
        'spinner', (tester) async {
      final controller = await _pumpControls(tester, isTv: false);

      expect(
        tester
            .widget<PlayerCenterPlayButton>(find.byType(PlayerCenterPlayButton))
            .playing,
        isTrue,
      );

      // The controller raises isStalled from its own position clock: a frozen
      // position past the indicator delay is what the platforms that never
      // report `buffering` have to be caught by.
      await _snapshot(tester, position: 1000);
      await tester.pump(
        controller.stallIndicatorDelay + const Duration(milliseconds: 100),
      );
      expect(find.byType(PlayerBufferingIndicator), findsOneWidget);
      expect(
        find.byType(PlayerCenterPlayButton),
        findsNothing,
        reason: 'no disc drawn around the spinner',
      );

      await _snapshot(tester, state: 'paused', position: 1000);
    });
  });

  group('VlcPlayerControls in full screen mode', () {
    // The screen resolves its form factor through playerFormFactorOf, which
    // full screen mode widens to `tv`. A bar that read the raw hardware profile
    // instead would keep the phone layout inside a ten-foot screen.
    tearDown(() => fullScreenModeActive.value = false);

    // The proxy for "ten-foot" is the overscan inset the bar lays out to,
    // measured rather than read back: a television is held to `tvEdgeInset`
    // and every other device to `edgeInset`.
    //
    // Measured off the seek bar, which is the one thing inside the bar's
    // padding on every form factor. The rewind button used to stand here and
    // cannot any more: on a handset the transport pair is in the centre
    // cluster, and on a desktop window there is no pair at all.
    double leftInset(WidgetTester tester) =>
        tester.getRect(find.byType(PlayerSeekBar)).left;

    testWidgets('a non-TV device in full screen mode gets the ten-foot bar', (
      tester,
    ) async {
      fullScreenModeActive.value = true;
      await _pumpControls(tester, isTv: false);

      expect(
        leftInset(tester),
        HotstarPlayerStyle.tvEdgeInset,
        reason:
            'full screen mode must reach the same verdict the screen '
            'already reaches; 48 dp of overscan is what a television gets',
      );
    });

    testWidgets('and the same device without it does not', (tester) async {
      await _pumpControls(tester, isTv: false);

      expect(leftInset(tester), HotstarPlayerStyle.edgeInset);
    });

    // _showCenterGlyph is `!_isTv && !_isDesktop`, a separate read from the
    // build-local flag the inset pair above pins. One _pumpControls per test:
    // the tear-downs are LIFO around a single channel mock, so a second install
    // in the same test unregisters the first fake's handler.
    testWidgets('a touch device gets the centre glyph', (tester) async {
      await _pumpControls(tester, isTv: false);
      expect(find.byType(PlayerCenterPlayButton), findsOneWidget);
    });

    testWidgets('and the touch centre glyph goes away in full screen mode', (
      tester,
    ) async {
      fullScreenModeActive.value = true;
      await _pumpControls(tester, isTv: false);
      expect(
        find.byType(PlayerCenterPlayButton),
        findsNothing,
        reason:
            'in full screen mode the same device is a ten-foot one, and '
            'a remote steers around a glyph in the middle of the frame',
      );
    });
  });

  group('desktop key repeats', () {
    testWidgets('held volume arrows keep stepping and respect the ceiling', (
      tester,
    ) async {
      final engine = FakeVlcEngine();
      await _pumpControls(
        tester,
        isTv: false,
        desktop: true,
        desktopProfile: true,
        engine: engine,
        settings: const PlayerSettings(maxVolumePercent: 110),
      );
      _byLabel('player-key-sink').requestFocus();
      await tester.pump();
      engine.calls.clear();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
      expect(_volumes(engine), [105, 110, 110]);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
      expect(_volumes(engine).sublist(3), [105, 100]);
      await _snapshot(tester, state: 'paused');
    });

    for (final (key, targets) in [
      (LogicalKeyboardKey.arrowRight, [75000, 90000, 105000]),
      (LogicalKeyboardKey.arrowLeft, [45000, 30000, 15000]),
    ]) {
      testWidgets('held ${key.debugName} chains the configured seek step', (
        tester,
      ) async {
        final engine = FakeVlcEngine();
        await _pumpControls(
          tester,
          isTv: false,
          desktop: true,
          engine: engine,
          settings: const PlayerSettings(seekDuration: 15),
        );
        await _snapshot(tester, position: 60000, duration: 300000);
        _byLabel('player-key-sink').requestFocus();
        await tester.pump();
        engine.calls.clear();

        await tester.sendKeyDownEvent(key);
        await tester.pump(VlcPlayerController.seekMergeWindow);
        for (var i = 0; i < 2; i++) {
          await tester.sendKeyRepeatEvent(key);
          await tester.pump(VlcPlayerController.seekMergeWindow);
        }
        await tester.sendKeyUpEvent(key);
        await tester.pump(VlcPlayerController.seekMergeWindow);
        expect(_seeks(engine), targets);
        await _snapshot(tester, state: 'paused', position: targets.last);
      });
    }

    testWidgets('held mute stays a single toggle', (tester) async {
      final engine = FakeVlcEngine();
      await _pumpControls(
        tester,
        isTv: false,
        desktop: true,
        desktopProfile: true,
        engine: engine,
      );
      _byLabel('player-key-sink').requestFocus();
      await tester.pump();
      engine.calls.clear();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyM);
      await tester.pump();
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyM);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyM);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyM);
      await tester.pump();
      expect(_volumes(engine), [0]);
      await _snapshot(tester, state: 'paused');
    });

    testWidgets('held arrows on controls remain focus navigation', (
      tester,
    ) async {
      final engine = FakeVlcEngine();
      await _pumpControls(tester, isTv: false, desktop: true, engine: engine);
      _byLabel('player-play-pause').requestFocus();
      await tester.pump();
      engine.calls.clear();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      expect(_inChrome(_primary), isTrue);
      expect(_seeks(engine), isEmpty);
      expect(_volumes(engine), isEmpty);
      await _snapshot(tester, state: 'paused');
    });
  });

  group('VlcPlayerControls volume', () {
    // On Android the AudioVolumeUp/Down logical key *is* the hardware rocker,
    // and the embedder gives the framework first refusal:
    // FlutterView.dispatchKeyEvent returns true the moment
    // KeyboardManager.handleEvent says handled, so FrameLayout.dispatchKeyEvent
    // - and with it PhoneWindow's volume fallback and the system HUD - never
    // runs. Claiming the key would silence the rocker. Only a desktop
    // keyboard's volume keys are ours.
    testWidgets('the hardware rocker is handed back on Android and claimed on '
        'desktop', (tester) async {
      // Restored in the body, not in a tear-down: flutter_test verifies the
      // foundation debug variables between the body and the tear-downs.
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final engine = FakeVlcEngine();
      await _pumpControls(tester, isTv: false, engine: engine);

      final onAndroid = await tester.sendKeyEvent(
        LogicalKeyboardKey.audioVolumeUp,
      );
      await tester.pump();
      expect(
        onAndroid,
        isFalse,
        reason: 'ignored is what redispatches the press to the OS',
      );
      expect(
        _volumes(engine),
        isEmpty,
        reason: 'the phone changes the volume, not the player',
      );

      // The same key on a desktop keyboard is a media key like any other, and
      // there is no OS rail behind it to defer to.
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final onDesktop = await tester.sendKeyEvent(
        LogicalKeyboardKey.audioVolumeUp,
      );
      await tester.pump();
      expect(onDesktop, isTrue);
      expect(_volumes(engine), [105], reason: 'one 5% step up from 100');

      // Let the rail's own clock run out; nothing may be pending at the end.
      await tester.pump(const Duration(seconds: 1));
      await _snapshot(tester, state: 'paused');
      debugDefaultTargetPlatformOverride = null;
    });

    // The pre-mute level has to be whatever the viewer actually had, however
    // they got there: a rail drag never goes through the M branch, so a memory
    // written only there leaves unmute jumping to a hardcoded 100.
    testWidgets('M unmutes to the level the rail was dragged to, not 100', (
      tester,
    ) async {
      final engine = FakeVlcEngine();
      final system = _FakeSystemVolume();
      await _pumpControls(
        tester,
        isTv: false,
        engine: engine,
        systemVolume: system,
      );

      // The right half is the volume rail by default; a drag down lands
      // somewhere under unity. Where exactly does not matter - that M comes
      // back to exactly there does.
      //
      // Read off the system stream rather than the engine: this is a handset,
      // so everything under 100 % is the platform's media volume and libVLC
      // stays at unity. Attenuating in both would make the bottom of the scale
      // useless.
      final rect = tester.getRect(find.byType(VlcPlayerControls));
      await tester.dragFrom(
        Offset(rect.right - 200, rect.center.dy),
        const Offset(0, 400),
      );
      await tester.pump(const Duration(milliseconds: 600));
      final dragged = system.writes.last;
      expect(dragged, greaterThan(0.0));
      expect(dragged, lessThan(1.0), reason: 'the drag went down');
      expect(
        _volumes(engine).last,
        100,
        reason: 'and libVLC stayed at unity through all of it',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.pump();
      expect(system.writes.last, 0.0, reason: 'M mutes');

      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.pump();
      expect(
        system.writes.last,
        closeTo(dragged, 0.001),
        reason: 'unmuting returns to the dragged level, not to full',
      );

      await tester.pump(const Duration(seconds: 1));
      await _snapshot(tester, state: 'paused');
    });

    // Every other route into the player's own gain needs hardware a sofa does
    // not have: the AudioVolume keys are claimed on desktop only, the arrows
    // are spent revealing the chrome on television, M is a keyboard key and
    // the rail is a drag. The OSD picker is a remote's only way to the
    // 100-200% boost.
    testWidgets('the volume dialog reaches the boost above 100%', (
      tester,
    ) async {
      final engine = FakeVlcEngine();
      await _pumpControls(tester, engine: engine);

      await _tapControl(tester, find.byTooltip('Volume'));
      await tester.pumpAndSettle();

      expect(find.byType(PlayerSliderDialog), findsOneWidget);
      // The read-out is the level in force. Unique while it differs from every
      // preset label on screen, which at 100 % it does not - so the assertion
      // is on the dialog's own state rather than on a text finder.
      expect(
        tester.widget<PlayerSliderDialog>(find.byType(PlayerSliderDialog)).max,
        200,
        reason: 'ranged over the configured maximum, not clamped to 100',
      );

      // A preset, straight to the boost.
      await tester.tap(find.text('200%'));
      await tester.pumpAndSettle();
      expect(_volumes(engine), <int>[200]);

      // And the step button, which is what a remote adjusts with.
      await tester.tap(find.byTooltip('Decrease'));
      await tester.pumpAndSettle();
      expect(
        _volumes(engine),
        <int>[200, 195],
        reason: 'one press is the same 5 % the keyboard steps by',
      );

      await tester.pump(const Duration(seconds: 1));
      await _snapshot(tester, state: 'paused');
    });

    testWidgets('the speed dialog applies live and offers its presets', (
      tester,
    ) async {
      final engine = FakeVlcEngine();
      await _pumpControls(tester, engine: engine);

      await _tapControl(tester, find.byTooltip('1x'));
      await tester.pumpAndSettle();

      expect(find.byType(PlayerSliderDialog), findsOneWidget);
      final dialog = tester.widget<PlayerSliderDialog>(
        find.byType(PlayerSliderDialog),
      );
      expect(dialog.min, 0.25);
      expect(dialog.max, 3.0);
      expect(
        dialog.presets,
        <double>[0.5, 1.0, 1.25, 1.5, 2.0],
        reason: 'the five worth one press; the rest is the slider',
      );

      await tester.tap(find.text('1.5x'));
      await tester.pumpAndSettle();
      expect(_speeds(engine), <double>[1.5]);

      // 0.05 a press, which is finer than any preset - the point of having a
      // slider behind the chips at all.
      await tester.tap(find.byTooltip('Increase'));
      await tester.pumpAndSettle();
      expect(_speeds(engine), <double>[1.5, 1.55]);

      await tester.pump(const Duration(seconds: 1));
      await _snapshot(tester, state: 'paused');
    });

    // The volume button is on every platform. A desktop keyboard's
    // AudioVolumeUp/Down and the touch drag rail are not substitutes for it:
    // the rail carries volume only while the viewer's edge-gesture setting says
    // it does, so a phone with both edges set to brightness has no volume path
    // at all.
    //
    // Each case taps the button and takes the boost, so a build where the row
    // clipped it off screen fails here too.
    for (final (String device, bool isTv, bool desktop)
        in <(String, bool, bool)>[
          ('a television', true, false),
          ('a desktop window with its own fullscreen button', false, true),
          ('a handset, where the rail was said to be enough', false, false),
        ]) {
      testWidgets('the volume button, and the boost behind it, is on $device', (
        tester,
      ) async {
        final engine = FakeVlcEngine();
        await _pumpControls(
          tester,
          isTv: isTv,
          desktop: desktop,
          engine: engine,
        );

        expect(find.byTooltip('Volume'), findsOneWidget);
        expect(
          find.byTooltip('Volume').hitTestable(),
          findsOneWidget,
          reason: 'present is not enough; it has to be pressable',
        );

        await _tapControl(tester, find.byTooltip('Volume'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('200%'));
        await tester.pumpAndSettle();

        expect(_volumes(engine), <int>[
          200,
        ], reason: 'the 100-200% boost is reachable here, not just the button');

        await tester.pump(const Duration(seconds: 1));
        await _snapshot(tester, state: 'paused');
      });
    }
  });

  group('VlcPlayerControls bottom row', () {
    /// Every action button's tooltip, left to right, as the bar orders them.
    /// Off touch the actions live in the bar's [Wrap]; the leading transport
    /// group is outside it, which is what makes this the utility list.
    List<String> wrapTooltips(WidgetTester tester) => tester
        .widgetList<PlayerIconButton>(
          find.descendant(
            of: find.byType(Wrap),
            matching: find.byType(PlayerIconButton),
          ),
        )
        .map((b) => b.tooltip)
        .toList(growable: false);

    // The seek pair is in the centre cluster and nowhere else. Every other
    // form factor has a better step of its own - J/L and the arrows on a
    // desktop, the D-pad on the ten-foot scrubber - so a pair in the bar was
    // two buttons for something already covered.
    for (final (String device, bool isTv, bool desktop)
        in <(String, bool, bool)>[
          ('a television', true, false),
          ('a desktop window', false, true),
        ]) {
      testWidgets('$device has no seek pair in the bar', (tester) async {
        await _pumpControls(
          tester,
          isTv: isTv,
          desktop: desktop,
          settings: const PlayerSettings(seekDuration: 30),
        );
        await _snapshot(tester, position: 65000, duration: 300000);

        expect(find.byTooltip('Rewind 30 seconds'), findsNothing);
        expect(find.byTooltip('Forward 30 seconds'), findsNothing);
        expect(
          find.byType(PlayerCenterControls),
          findsNothing,
          reason: 'and no centre cluster either, off a handset',
        );

        await _snapshot(tester, state: 'paused', position: 65000);
      });
    }

    testWidgets('a television seeks with the D-pad on the scrubber instead', (
      tester,
    ) async {
      // What replaces the pair there, and why the ten-foot scrubber is drawn
      // at 48 dp: it is the seek surface on a television.
      final engine = FakeVlcEngine();
      await _pumpControls(
        tester,
        isTv: true,
        engine: engine,
        settings: const PlayerSettings(seekDuration: 30),
      );
      await _snapshot(tester, position: 65000, duration: 300000);

      _scrubber().requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 600));

      expect(_seeks(engine), <int>[95000], reason: '65 s + one 30 s step');

      await tester.pump(const Duration(seconds: 2));
      await _snapshot(tester, state: 'paused', position: 65000);
    });

    testWidgets('a desktop window trades the seek pair for the clock', (
      tester,
    ) async {
      final engine = FakeVlcEngine();
      await _pumpControls(
        tester,
        isTv: false,
        desktop: true,
        engine: engine,
        settings: const PlayerSettings(seekDuration: 30),
      );
      await _snapshot(tester, position: 65000, duration: 300000);

      expect(find.byTooltip('Rewind 30 seconds'), findsNothing);
      expect(find.byTooltip('Forward 30 seconds'), findsNothing);
      expect(find.byType(PlayerTimeLabel), findsOneWidget);
      expect(find.text('1:05 / 5:00'), findsOneWidget);

      // The clock reads out of the transport group, not from above the track:
      // its left edge is past play/pause, and it sits on the button row rather
      // than over the scrubber.
      final clock = tester.getRect(find.byType(PlayerTimeLabel));
      final playPause = tester.getRect(find.byTooltip('Pause'));
      final scrubber = tester.getRect(find.byType(PlayerSeekBar));
      expect(clock.left, greaterThan(playPause.right));
      expect(
        clock.center.dy,
        greaterThan(scrubber.bottom),
        reason: 'below the track, on the line the buttons are on',
      );

      // And the keyboard step the buttons used to carry is still there.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pump();
      expect(_seeks(engine), <int>[95000], reason: '65 s + one 30 s step');

      await tester.pump(const Duration(seconds: 2));
      await _snapshot(tester, state: 'paused', position: 65000);
    });

    testWidgets('a handset puts the seek pair in the centre, not the bar', (
      tester,
    ) async {
      final engine = FakeVlcEngine();
      await _pumpControls(
        tester,
        isTv: false,
        engine: engine,
        size: const Size(390, 844),
        withoutEpisodes: true,
        settings: const PlayerSettings(seekDuration: 30),
      );
      await _snapshot(tester, position: 65000, duration: 300000);

      // Not in the bar. The centre glyphs carry a semantics label rather than
      // a Tooltip - there is no pointer on a handset to hover one with - so a
      // tooltip finder is exactly the "is it in the bar" question.
      expect(find.byTooltip('Rewind 30 seconds'), findsNothing);
      expect(find.byTooltip('Forward 30 seconds'), findsNothing);
      expect(
        tester
            .widget<PlayerBottomBar>(find.byType(PlayerBottomBar))
            .leading
            .length,
        1,
        reason: 'a film, so the left end is the clock and nothing else',
      );

      // In the centre, either side of the disc, and they seek.
      final Finder cluster = find.byType(PlayerCenterControls);
      expect(cluster, findsOneWidget);
      final Finder back = find.bySemanticsLabel('Rewind 30 seconds');
      final Finder forward = find.bySemanticsLabel('Forward 30 seconds');
      final Rect disc = tester.getRect(find.byType(PlayerCenterPlayButton));
      expect(tester.getRect(back).right, lessThan(disc.left));
      expect(tester.getRect(forward).left, greaterThan(disc.right));
      expect(
        tester.getRect(cluster).center.dx,
        closeTo(390 / 2, 0.5),
        reason: 'the group is centred on the frame, disc and all',
      );

      // Through [_tapControl]: the cluster sits over the screen-wide
      // double-tap recogniser, so a bare tap is held until that timeout the
      // same way a bar button's is.
      await _tapControl(tester, forward);
      expect(_seeks(engine), <int>[95000], reason: '65 s + one 30 s step');
      await _tapControl(tester, back);
      // Tapped this soon after the first, it reaches the engine once the taps
      // stop.
      await tester.pump(VlcPlayerController.seekMergeWindow);
      expect(_seeks(engine), <int>[95000, 65000]);

      await tester.pump(const Duration(seconds: 2));
      await _snapshot(tester, state: 'paused', position: 65000);
    });

    testWidgets('a live handset centres the disc with no pair beside it', (
      tester,
    ) async {
      // [_seekBy] returns on a live edge, so a step there is a dead press and
      // the cluster renders the disc on its own.
      await _pumpControls(
        tester,
        isTv: false,
        isLive: true,
        size: const Size(390, 844),
      );

      expect(find.byType(PlayerCenterPlayButton), findsOneWidget);
      expect(find.byType(PlayerCenterSeekButton), findsNothing);
      expect(
        tester.getRect(find.byType(PlayerCenterControls)).center.dx,
        closeTo(390 / 2, 0.5),
        reason: 'and it is still centred, not offset by a missing neighbour',
      );

      await _snapshot(tester, state: 'paused');
    });

    testWidgets('the episode pair is in the bar, and only where it plays '
        'something', (tester) async {
      final pressed = <String>[];
      await _pumpControls(
        tester,
        isTv: true,
        onNextEpisode: () => pressed.add('next'),
        onPreviousEpisode: () => pressed.add('previous'),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      final PlayerBottomBar bar = tester.widget<PlayerBottomBar>(
        find.byType(PlayerBottomBar),
      );
      expect(
        bar.leading.length,
        4,
        reason: 'play/pause, previous, next, clock',
      );

      await _tapControl(tester, find.byTooltip(l10n.previous));
      await _tapControl(tester, find.byTooltip(l10n.next));
      expect(pressed, <String>['previous', 'next']);

      await _snapshot(tester, state: 'paused');
    });

    testWidgets('a film renders neither episode button', (tester) async {
      // Both are null on a film, so the bar's left end is the clock alone -
      // absent rather than disabled, which is this file's rule everywhere.
      await _pumpControls(tester, isTv: true, withoutEpisodes: true);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.byTooltip(l10n.next), findsNothing);
      expect(find.byTooltip(l10n.previous), findsNothing);

      await _snapshot(tester, state: 'paused');
    });

    // The accessibility label is the only name these two glyphs have anywhere:
    // they live in the centre cluster now, where there is no pointer to hover
    // a tooltip with, so the label is what a screen reader is given and the
    // only thing standing between a viewer and two anonymous chevrons.
    //
    // It names the action rather than a bare signed amount, and carries the
    // step as an ICU plural argument: `playerRewindSeconds` and
    // `playerForwardSeconds`. Two steps, neither the 10 s default, so a label
    // that hardcodes any single number - or drops the placeholder - fails at
    // one of them.
    for (final int step in <int>[5, 120]) {
      testWidgets('the centre pair says what it does, at a $step s step', (
        tester,
      ) async {
        await _pumpControls(
          tester,
          isTv: false,
          size: const Size(390, 844),
          settings: PlayerSettings(seekDuration: step),
        );
        await _snapshot(tester, position: 5000, duration: 300000);

        expect(
          find.bySemanticsLabel('Rewind $step seconds'),
          findsOneWidget,
          reason: 'the glyph is named for the action and the configured step',
        );
        expect(find.bySemanticsLabel('Forward $step seconds'), findsOneWidget);

        // And no signed amount survives anywhere a viewer can read one: a
        // build that kept the old label would still satisfy the finders above.
        final List<String> named = <String>[
          ...tester
              .widgetList<PlayerIconButton>(find.byType(PlayerIconButton))
              .map((PlayerIconButton b) => b.tooltip),
          ...tester
              .widgetList<PlayerCenterSeekButton>(
                find.byType(PlayerCenterSeekButton),
              )
              .map((PlayerCenterSeekButton b) => b.label),
        ];
        expect(
          named.where((String t) => t.startsWith('-') || t.startsWith('+')),
          isEmpty,
          reason: 'a signed amount is not a name: $named',
        );

        await _snapshot(tester, state: 'paused', position: 5000);
      });
    }

    // The centre pair is aimed at one half of the screen each, which is the
    // test the side-aware readout exists for - the same one the double tap
    // passes. They used to get the centred pill instead, so the button and
    // the gesture that do the identical thing said it two different ways.
    testWidgets('the centre pair reads out like a double tap', (tester) async {
      await _pumpControls(
        tester,
        isTv: false,
        size: const Size(390, 844),
        settings: const PlayerSettings(seekDuration: 10),
      );
      await _snapshot(tester, position: 60000, duration: 300000);
      expect(find.byType(PlayerSeekBurst), findsNothing);

      await _tapControl(tester, find.bySemanticsLabel('Forward 10 seconds'));
      await tester.pump();

      final burst = tester.widget<PlayerSeekBurst>(
        find.byType(PlayerSeekBurst),
      );
      expect(burst.forward, isTrue, reason: 'on the half it was pressed from');
      expect(burst.seconds, 10);
      // The icon and the number are the point; the ripple comes with them.
      expect(find.text('10s'), findsOneWidget);
      expect(
        find.byIcon(Icons.keyboard_double_arrow_right_rounded),
        findsOneWidget,
      );

      // A second press accumulates, exactly as a second double tap does.
      await _tapControl(tester, find.bySemanticsLabel('Forward 10 seconds'));
      await tester.pump();
      expect(
        tester.widget<PlayerSeekBurst>(find.byType(PlayerSeekBurst)).seconds,
        20,
      );

      // Merged with the first, the second press's seek is still waiting.
      await tester.pump(VlcPlayerController.seekMergeWindow);
      await _snapshot(tester, state: 'paused', position: 60000);
    });

    // A bare Row with a Spacer leaves Flex.clipBehavior at Clip.none, so a
    // button past the edge is painted outside the bar and left mounted and
    // focusable there. 480 dp is a legitimate desktop window: lib/main.dart
    // sets the minimum at 360x640.
    testWidgets('a 480 dp desktop window scrolls the row instead of growing '
        'the bar upwards', (tester) async {
      // What this replaces: the row used to be a [Wrap] off touch, and a
      // narrow desktop window sent it onto extra runs. At 440x330 with the
      // clock in the transport group that was five runs and a 284 dp bar
      // inside a 330 dp viewport - the scrubber pushed off the top of its own
      // chrome and the overlays anchored off it landing on the buttons.
      await _pumpControls(
        tester,
        isTv: false,
        desktop: true,
        onEnterPip: () {},
        size: const Size(480, 640),
      );

      expect(
        find.byType(PlayerActionStrip),
        findsOneWidget,
        reason: 'a desktop window has a pointer, so it scrolls',
      );
      expect(find.byType(Wrap), findsNothing);

      final Rect bar = tester.getRect(find.byType(PlayerBottomBar));
      final Rect row = tester.getRect(find.byType(PlayerActionStrip));
      expect(
        row.height,
        lessThan(64),
        reason: 'one control line, whatever will not fit on it',
      );
      expect(
        bar.height,
        lessThanOrEqualTo(
          HotstarPlayerStyle.bottomChromeHeightFor(isTv: false),
        ),
        reason: 'and the whole bar stays inside the clearance',
      );

      await _snapshot(tester, state: 'paused');
    });

    // The two groups are the left and right ends of one line, so they answer
    // to the same three lines: the scrubber's left edge, the scrubber's right
    // edge, and one horizontal centre. A [Wrap] that took a second run broke
    // the third silently - [Row] centres the short child against the tall one,
    // so the transport group ended up floating between two rows of icons.
    for (final (String name, bool isTv, bool desktop, Size size)
        in <(String, bool, bool, Size)>[
          ('a narrow desktop window', false, true, const Size(440, 330)),
          ('a wide desktop window', false, true, const Size(1280, 720)),
          ('a handset in landscape', false, false, const Size(844, 390)),
          ('a television', true, false, const Size(960, 540)),
        ]) {
      testWidgets('the bar squares up to the scrubber on $name', (
        tester,
      ) async {
        await _pumpControls(
          tester,
          isTv: isTv,
          desktop: desktop,
          onEnterPip: () {},
          size: size,
        );
        await _snapshot(tester, position: 65000, duration: 300000);

        final Rect seek = tester.getRect(find.byType(PlayerSeekBar));
        final Rect bar = tester.getRect(find.byType(PlayerBottomBar));
        // The leading edge of the transport group and the trailing edge of the
        // utility group, whichever buttons those happen to be: the seek pair
        // is absent on desktop and the fullscreen button on a television, so
        // naming them would make this a test about which buttons exist.
        // Below the track, so the top bar's Back button is out; and inside
        // the bar, so the utility buttons a narrow window has scrolled off the
        // left edge - which sit at negative x, still laid out - are out too.
        // Those are meant to be off screen; the question here is where the
        // ones on screen begin and end.
        final List<Rect> buttons = tester
            .widgetList<PlayerIconButton>(find.byType(PlayerIconButton))
            .map((b) => tester.getRect(find.byTooltip(b.tooltip)))
            .where((r) => r.top > seek.top && r.left >= bar.left - 0.01)
            .toList(growable: false);
        final double left = buttons
            .map((r) => r.left)
            .reduce((a, b) => a < b ? a : b);
        final double right = buttons
            .map((r) => r.right)
            .reduce((a, b) => a > b ? a : b);

        expect(
          left,
          seek.left,
          reason: 'the first control starts where the track starts',
        );
        expect(
          right,
          seek.right,
          reason: 'and the last one ends where the track ends',
        );
        expect(
          bar.height,
          lessThanOrEqualTo(
            HotstarPlayerStyle.bottomChromeHeightFor(isTv: isTv),
          ),
          reason:
              'the bottom bar fits inside the clearance every overlay is '
              'anchored off; raise the token rather than the overlays',
        );

        await tester.pump(const Duration(seconds: 2));
        await _snapshot(tester, state: 'paused', position: 65000);
      });
    }

    // The clock is the whole transport group on a handset - play/pause and the
    // seek pair are in the centre cluster there - so it is the one thing on
    // the line that has to supply its own optical inset. Measured against the
    // track rather than against a neighbouring button, because on this form
    // factor it has no neighbour.
    testWidgets('the clock starts where the track does on a handset', (
      tester,
    ) async {
      // A film, so nothing precedes the clock. With an episode pair in the
      // bar the first button supplies the inset and the clock rightly keeps
      // its small gap - the bug is only visible when the clock is alone.
      await _pumpControls(
        tester,
        isTv: false,
        onEnterPip: () {},
        size: _phone,
        withoutEpisodes: true,
      );
      await _snapshot(tester, position: 65000, duration: 300000);

      final Rect seek = tester.getRect(find.byType(PlayerSeekBar));
      final Rect clock = tester.getRect(find.byType(PlayerTimeLabel));

      expect(
        clock.left,
        moreOrLessEquals(seek.left + HotstarPlayerStyle.trackInset, epsilon: 0.5),
        reason: 'the clock used to carry the 8 dp gap it wears when it '
            'follows a button, and sat outside the column the track, the '
            'Back button and the utility row all line up in',
      );

      await _snapshot(tester, state: 'paused', position: 65000);
    });

    // The torrent card is the one overlay with no width of its own: its rows
    // are [Expanded] inside a [Row], so it lays out only against a constraint
    // the caller supplies. Pinned in a [Positioned] by two edges and nothing
    // else it is handed an unbounded width, the flex has nothing to divide,
    // and pressing the button that summons it does nothing at all.
    for (final (String name, bool isTv, Size size)
        in <(String, bool, Size)>[
          ('a handset', false, const Size(390, 844)),
          ('a television', true, const Size(960, 540)),
        ]) {
      testWidgets('the torrent card opens and is laid out on $name', (
        tester,
      ) async {
        await _pumpControls(
          tester,
          isTv: isTv,
          size: size,
          torrentStatus: TorrentStatus(
            title: 'Some.Release.2024.1080p',
            status: 'Downloading',
            downloadSpeed: 2500000,
            uploadSpeed: 100000,
            seeds: 12,
            peers: 34,
            totalSize: 4000000000,
            bytesRead: 1000000000,
            data: const <dynamic, dynamic>{},
          ),
        );
        await _snapshot(tester, position: 65000, duration: 300000);

        expect(
          find.byType(TorrentInfoWidget),
          findsNothing,
          reason: 'the card is a toggle, not permanent chrome',
        );

        await _tapControl(tester, find.byTooltip('Torrent stats'));
        // Not pumpAndSettle: the card's title is a marquee and never stops,
        // so settling it would hang rather than fail.
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(
          find.byType(TorrentInfoWidget),
          findsOneWidget,
          reason: 'pressing the button has to show the card',
        );

        // Laid out, not merely mounted: a card with no width is a card the
        // viewer cannot read.
        final Rect card = tester.getRect(find.byType(TorrentInfoWidget));
        expect(card.width, greaterThan(0));
        expect(card.width, lessThan(size.width));
        expect(card.height, greaterThan(0));
        expect(find.text('12 / 34'), findsOneWidget);

        // And in the corner it is anchored to. An unlaid-out box paints at the
        // origin, so "it opened" and "it opened where it should" are two
        // different claims and this is the second one.
        expect(
          card.right,
          moreOrLessEquals(
            size.width -
                (isTv
                    ? HotstarPlayerStyle.tvEdgeInset
                    : HotstarPlayerStyle.edgeInset),
            epsilon: 0.5,
          ),
          reason: 'the card hangs off the right edge, not the left',
        );
        expect(
          card.left,
          greaterThan(0),
          reason: 'flush against the left edge is what the broken layout did',
        );

        await _snapshot(tester, state: 'paused', position: 65000);

        // The card's title is a marquee and its pause between sweeps is a real
        // timer, so unmount and let the last one fire rather than ending the
        // test with it pending.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      });
    }

    // Requirement: the floating overlays answer to the same two vertical lines
    // the bar does. They are the screen's children, not the controls', so they
    // are measured here against a bar pumped at the same size - which is also
    // the only place that can catch one of them using a different edge token.
    for (final (String name, bool isTv, Size size)
        in <(String, bool, Size)>[
          ('a handset', false, const Size(390, 844)),
          ('a television', true, const Size(960, 540)),
        ]) {
      testWidgets('the floating overlays line up with the bar on $name', (
        tester,
      ) async {
        await _pumpControls(
          tester,
          isTv: isTv,
          onEnterPip: () {},
          size: size,
          skipSegments: <SkipSegment>[
            SkipSegment(type: SkipType.intro, startTime: 0, endTime: 90),
          ],
        );
        await _snapshot(tester, position: 5000, duration: 300000);

        // The skip chip is the controls' own right-hand overlay, and it
        // answers to the trailing line: the bar's edge inset plus the optical
        // one the track's far end and the last utility button share.
        final Rect chip = tester.getRect(find.byType(PlayerActionButton));
        expect(
          size.width - chip.right,
          HotstarPlayerStyle.trailingLineOf(isTv: isTv),
          reason: 'the chip stops on the same line as the track and the icons',
        );

        await tester.pump(const Duration(seconds: 2));
        await _snapshot(tester, state: 'paused', position: 5000);
      });
    }

    // Requirement: a remote reaches everything, including when a build has
    // fewer buttons than the full set. Most of the row is conditional - no
    // PiP off Android, no torrent pair off a torrent, no episodes on a film,
    // no speed on a live edge - and an arrow that walked a fixed list would
    // stop at the first gap.
    testWidgets('a stripped-down television bar is still walkable end to end', (
      tester,
    ) async {
      await _pumpControls(
        tester,
        isTv: true,
        isLive: true,
        withoutEpisodes: true,
        panelTabs: const <PlayerPanelTab>{
          PlayerPanelTab.audio,
          PlayerPanelTab.subtitles,
        },
        settings: const PlayerSettings(
          showResize: false,
          showPip: false,
          showPlaybackSpeed: false,
        ),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // What is left: play/pause - no seek pair, because a live edge cannot
      // step - and two utilities.
      final List<String> rendered = tester
          .widgetList<PlayerIconButton>(find.byType(PlayerIconButton))
          .map((b) => b.tooltip)
          .toList(growable: false);
      expect(rendered, contains(l10n.pause));
      expect(rendered, isNot(contains(l10n.next)));
      expect(rendered, isNot(contains(l10n.resize)));

      _byLabel('player-play-pause').requestFocus();
      await tester.pump();
      final trail = <String>[_focusedControl()];
      for (var i = 0; i < 12; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        final next = _focusedControl();
        if (next == trail.last) break;
        trail.add(next);
      }

      expect(trail, <String>[
        l10n.pause,
        l10n.options,
        l10n.volume,
      ], reason: 'every button that exists is on the way, and nothing else is');

      await _snapshot(tester, state: 'paused');
    });

    testWidgets('the utility group hugs the right edge when it fits', (
      tester,
    ) async {
      // `reverse: true` right-anchors the strip only while it overflows. With
      // room to spare the viewport lays the row out from its leading edge, and
      // on a 1280 dp window that left the whole group some 500 dp short of the
      // scrubber's end, in the middle of the bar. See [PlayerActionStrip].
      await _pumpControls(
        tester,
        isTv: false,
        desktop: true,
        onEnterPip: () {},
        size: const Size(1280, 720),
      );

      final Rect strip = tester.getRect(find.byType(PlayerActionStrip));
      // Fullscreen is last in the row on a desktop window - band three, hard
      // against the right edge.
      final Rect last = tester.getRect(find.byTooltip('Fullscreen'));
      expect(
        strip.width,
        greaterThan(last.width * 10),
        reason: 'this only measures anything while the row has room to spare',
      );
      expect(last.right, strip.right);

      await _snapshot(tester, state: 'paused');
    });

    // The row is right-anchored, so a squeeze eats it from the left and
    // whatever leads the list is what the viewer loses. A 360 dp portrait
    // handset is a real state: the app pins portrait for a portrait video.
    // The row reads in three bands: what a viewer reaches for without leaving
    // the film, then the rest, then the two that change the shape of the
    // picture. Pinned as an order rather than as a list of names, so a button
    // that does not exist on this build - PiP, the torrent pair, the lock -
    // takes itself out of the sequence without taking the test with it.
    testWidgets('the utility row reads in its three bands', (tester) async {
      await _pumpControls(tester, isTv: true, onEnterPip: () {});
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      final List<String> tooltips = wrapTooltips(tester);
      int at(String tooltip) {
        final index = tooltips.indexOf(tooltip);
        expect(index, isNot(-1), reason: '$tooltip is in the row at all');
        return index;
      }

      expect(
        <int>[at(l10n.options), at(l10n.volume)],
        <int>[0, 1],
        reason: 'band one leads, in this order; the full row is $tooltips',
      );
      expect(
        at(l10n.resize),
        greaterThan(at(l10n.torrentFiles)),
        reason: 'and the view settings come after the rest of band two',
      );
      expect(
        at(l10n.resize),
        tooltips.length - 1,
        reason:
            'resize is last on a television, which has no fullscreen button '
            'to put behind it',
      );

      await _snapshot(tester, state: 'paused');
    });

    // The touch strip is the one branch a widget test cannot reach through the
    // controls - `isTouch` is `Platform.isAndroid || Platform.isIOS`, false on
    // every test host - so it is measured on [PlayerBottomBar] directly.
    testWidgets('the touch strip says it scrolls, and only when it does', (
      tester,
    ) async {
      Widget host(double width, int buttons) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: width,
              child: PlayerBottomBar(
                scrollingActions: true,
                progressBar: const SizedBox(height: 8),
                leading: const [SizedBox(width: 120, height: 44)],
                actions: <Widget>[
                  for (int i = 0; i < buttons; i++)
                    PlayerIconButton(
                      icon: Icons.circle,
                      tooltip: 'a$i',
                      onPressed: () {},
                    ),
                ],
              ),
            ),
          ),
        ),
      );

      // Two buttons in 360 dp with a 120 dp leading group: room to spare.
      await tester.pumpWidget(host(360, 2));
      await tester.pump();
      expect(
        find.byIcon(Icons.chevron_left_rounded),
        findsNothing,
        reason: 'nothing is hidden, so nothing may claim it is',
      );

      // Twelve buttons force overflow even with short labels.
      await tester.pumpWidget(host(360, 12));
      await tester.pump();
      expect(
        find.byIcon(Icons.chevron_left_rounded),
        findsOneWidget,
        reason:
            'a right-anchored strip that overflows off the left edge with '
            'no fade, no chevron and no bounce is a strip nobody knows is '
            'there. The 120 dp leading here is a stand-in that only has to '
            'force an overflow; what a real handset leaves the strip is '
            'measured in the test below, against the real button lists',
      );

      // The hint is paint, never a target: a tap where it sits must still
      // reach the half-covered button underneath.
      final Rect hint = tester.getRect(find.byIcon(Icons.chevron_left_rounded));
      expect(tester.hitTestOnBinding(hint.center), isNotNull);
      expect(find.byType(IgnorePointer).evaluate().isNotEmpty, isTrue);

      // And it goes away once the viewer has scrolled to the far end.
      await tester.drag(find.byType(PlayerActionStrip), const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(
        find.byIcon(Icons.chevron_left_rounded),
        findsNothing,
        reason: 'scrolled to the left end there is nothing left to reveal',
      );
    });

    // The same squeeze against the real button lists rather than a stand-in
    // that might not squeeze at all. `leading` is five pinned buttons - rewind,
    // play/pause, forward, lock, next - measuring 250 dp, so on the commonest
    // Android portrait width the strip gets 70 dp of the bar's 320. It stays
    // one line that scrolls at every width rather than taking a run of its own
    // over the video; the run count itself is pinned in
    // control_strip_single_line_test.dart.
    //
    // Both halves of the geometry come off a really-pumped
    // [VlcPlayerControls]: the actions are its own widgets and the leading
    // group is a spacer of its measured width, which is the only part of it
    // this layout cares about. The buttons cannot be re-hosted, because the
    // play/pause carries the state's focus node, and a hardcoded width would
    // hide the very squeeze being measured. They are then re-rendered through
    // the touch branch, which `isTouch` would otherwise never let a test
    // reach.
    testWidgets('a portrait handset keeps the real control row on one line, '
        'and a landscape one is no taller', (tester) async {
      final locked = ValueNotifier<bool>(false);
      addTearDown(locked.dispose);
      await _pumpControls(
        tester,
        isTv: false,
        size: const Size(360, 800),
        locked: locked,
        onEnterPip: () {},
        onPreviousEpisode: () {},
      );

      final PlayerBottomBar built = tester.widget<PlayerBottomBar>(
        find.byType(PlayerBottomBar),
      );
      final List<Widget> actions = built.actions;
      // The pinned group whose width is what squeezes the strip. On a handset
      // that is the episode pair and the clock: the transport moved to the
      // middle of the frame, which is most of why a 360 dp line fits at all.
      expect(built.leading.length, 3);
      expect(
        find.byType(PlayerCenterControls),
        findsOneWidget,
        reason: 'and the transport it gave up is in the centre cluster',
      );
      expect(
        actions.length,
        greaterThanOrEqualTo(7),
        reason:
            'a torrent series renders seven utilities or more, which is what '
            'makes a 320 dp line overflow in the first place. The exact count '
            'moves as controls come and go - that the row really does '
            'overflow is asserted by the edge hint below, not by this floor',
      );

      // Measured, not assumed, and measured on the handset frame the bar will
      // actually be squeezed on.
      final Rect group = built.leading
          .map((w) => tester.getRect(find.byWidget(w)))
          .reduce((a, b) => a.expandToInclude(b));

      final Widget transport = SizedBox(
        width: group.width,
        height: group.height,
      );
      Future<void> renderTouchBar(double width) async {
        tester.view.physicalSize = Size(width, 800);
        await tester.pumpWidget(
          _host(
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: width,
                child: PlayerBottomBar(
                  scrollingActions: true,
                  progressBar: const SizedBox(height: 8),
                  leading: <Widget>[transport],
                  actions: actions,
                ),
              ),
            ),
            isTv: false,
          ),
        );
        await tester.pump();
      }

      await renderTouchBar(360);

      final Rect strip = tester.getRect(find.byType(PlayerActionStrip));
      // The whole utility list is on the one run the transport is on. Every
      // button's vertical centre, not just the strip's: a Wrap inside the
      // strip would keep the strip one box and still stack the buttons.
      final List<Rect> buttons = find
          .descendant(
            of: find.byType(PlayerActionStrip),
            matching: find.byType(PlayerIconButton),
          )
          .evaluate()
          .map((e) => e.renderObject! as RenderBox)
          .map((b) => b.localToGlobal(Offset.zero) & b.size)
          .toList();
      expect(buttons, hasLength(actions.length));
      final Set<double> centres = buttons.map((r) => r.center.dy).toSet();
      expect(
        centres,
        hasLength(1),
        reason:
            'the ${actions.length} utilities sit on ${centres.length} lines '
            'at $centres; a phone gets one line that scrolls',
      );

      // The transport group is what must not move: the strip sits beside it
      // on the same line, never above it, so the thumb keeps its play/pause
      // where it has always been and the bar does not grow over the video.
      final Rect transportRect = tester.getRect(find.byWidget(transport));
      expect(
        centres.single,
        moreOrLessEquals(transportRect.center.dy, epsilon: 0.5),
        reason:
            'the utilities at ${centres.single} are on a different line from '
            'the transport group at $transportRect',
      );
      expect(
        transportRect.left,
        lessThan(strip.left + 1),
        reason: 'and it stays pinned to the left edge, not centred',
      );

      // 70 dp of strip is honest only if it says so and the fling works: the
      // edge hint is paint over the left edge, and the first utility is the
      // one furthest off it.
      expect(
        find.byIcon(Icons.chevron_left_rounded),
        findsOneWidget,
        reason:
            '${actions.length} buttons do not fit ${strip.width} dp, and a '
            'strip that hides some has to keep saying so',
      );
      final String first = tester
          .widget<PlayerIconButton>(
            find
                .descendant(
                  of: find.byType(PlayerActionStrip),
                  matching: find.byType(PlayerIconButton),
                )
                .first,
          )
          .tooltip;
      expect(find.byTooltip(first).hitTestable(), findsNothing);
      await tester.drag(find.byType(PlayerActionStrip), const Offset(900, 0));
      await tester.pumpAndSettle();
      expect(
        find.byTooltip(first).hitTestable(),
        findsOneWidget,
        reason:
            '$first is off the left edge at rest, so the fling has to be '
            'able to bring it back',
      );

      // The portrait bar costs exactly what the landscape one costs.
      final double narrowHeight = tester
          .getSize(find.byType(PlayerBottomBar))
          .height;
      await renderTouchBar(844);
      final double wideHeight = tester
          .getSize(find.byType(PlayerBottomBar))
          .height;
      expect(
        wideHeight,
        narrowHeight,
        reason:
            'the bar is $wideHeight dp at 844 and $narrowHeight at 360; a '
            'portrait handset must not be charged a second run of chrome '
            'over the video',
      );
      final Rect wideStrip = tester.getRect(find.byType(PlayerActionStrip));
      expect(
        wideStrip.width,
        greaterThan(400),
        reason:
            'at 844 dp the strip keeps the whole remainder of the flat row, '
            'not a run of its own',
      );
    });

    // A bare [PlayerActionButton] has a `Colors.transparent` background until
    // it is focused, hovered or pressed, so over a bright frame the Skip chip
    // would be white glyphs on white; on television there is no hover to rescue
    // it and focus starts on play/pause. The chip is also the one control in
    // the player on a clock, so it has to be read at a glance from a sofa.
    for (final (String device, bool isTv, double fontSize, double minHeight)
        in <(String, bool, double, double)>[
          ('a television', true, 18.0, 52.0),
          ('a handset', false, 12.0, 44.0),
        ]) {
      testWidgets('the skip chip is a painted pill on $device, at that '
          "device's label size", (tester) async {
        await _pumpControls(
          tester,
          isTv: isTv,
          skipSegments: <SkipSegment>[
            SkipSegment(startTime: 0, endTime: 60, type: SkipType.intro),
          ],
        );
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        final Finder chip = find.widgetWithText(
          PlayerActionButton,
          l10n.skipIntro,
        );
        expect(chip, findsOneWidget);

        // The container, read off the render tree rather than assumed: the
        // nearest DecoratedBox above the chip has to be the opaque pill, not
        // the chrome's own translucent scrim.
        final Iterable<DecoratedBox> shells = tester.widgetList<DecoratedBox>(
          find.ancestor(of: chip, matching: find.byType(DecoratedBox)),
        );
        expect(
          shells,
          isNotEmpty,
          reason:
              'the chip lives outside the chrome and paints nothing behind '
              'itself, so with no container it is white glyphs on a bright '
              'frame',
        );
        final BoxDecoration pill = shells.first.decoration as BoxDecoration;
        expect(
          pill.color,
          const Color(0xB3000000),
          reason: 'the same fill the unlock chip has always had',
        );
        expect(
          pill.border,
          isNotNull,
          reason: 'and the same edge, so the pill has a boundary on white',
        );
        expect(pill.borderRadius, BorderRadius.circular(999));

        // A RenderParagraph probe, not the TextStyle the widget was handed:
        // this is the size that is actually painted.
        final RenderParagraph label = tester.renderObject<RenderParagraph>(
          find.text(l10n.skipIntro),
        );
        expect(
          label.text.style!.fontSize,
          fontSize,
          reason: 'a 12 dp label is unreadable across a living room',
        );
        expect(
          tester.getSize(chip).height,
          greaterThanOrEqualTo(minHeight),
          reason: 'and the pill grows with the label rather than clipping it',
        );

        await _snapshot(tester, state: 'paused');
      });
    }
  });

  // A D-pad "OK" is not one key: a Shield remote, a game pad and every Android
  // TV device whose HID layer reports DPAD_CENTER as BUTTON_A all send
  // gameButtonA. Nothing further up the tree rescues a miss - WidgetsApp binds
  // gameButtonA to an ActivateIntent but ships no ActivateAction to answer it,
  // and the chip's Focus sits above its InkWell, so the InkWell's own Actions
  // map is a descendant of the focused node and is never reached.
  group('VlcPlayerControls activation keys', () {
    final introSegment = <SkipSegment>[
      SkipSegment(startTime: 0, endTime: 60, type: SkipType.intro),
    ];

    testWidgets('the Skip chip activates on a game controller A', (
      tester,
    ) async {
      final engine = FakeVlcEngine();
      await _pumpControls(tester, engine: engine, skipSegments: introSegment);
      expect(find.byIcon(Icons.fast_forward_rounded), findsOneWidget);

      _skipChipNode(tester).requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(
        LogicalKeyboardKey.gameButtonA,
        // flutter_test resolves a key code per platform, and BUTTON_A is in
        // Android's table - which is the platform that has the controllers.
        platform: 'android',
        physicalKey: PhysicalKeyboardKey.gameButtonA,
      );
      await tester.pump();

      expect(_seeks(engine), <int>[60000]);

      // seekTo arms the controller's 1 s stall watchdog, and flutter_test
      // checks for pending timers before tear-downs run. Past the controller's
      // 250 ms event throttle first, or the paused snapshot that disarms it is
      // coalesced away.
      await tester.pump(const Duration(milliseconds: 400));
      await _snapshot(tester, state: 'paused');
    });

    testWidgets('the Skip chip still activates on Select', (tester) async {
      final engine = FakeVlcEngine();
      await _pumpControls(tester, engine: engine, skipSegments: introSegment);

      _skipChipNode(tester).requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();

      expect(_seeks(engine), <int>[60000]);

      // seekTo arms the controller's 1 s stall watchdog, and flutter_test
      // checks for pending timers before tear-downs run. Past the controller's
      // 250 ms event throttle first, or the paused snapshot that disarms it is
      // coalesced away.
      await tester.pump(const Duration(milliseconds: 400));
      await _snapshot(tester, state: 'paused');
    });
  });

  // The seek is what makes the advance safe. `PlaybackTracker.finish` judges
  // the session from the last sample taken while playing, and an outro band
  // routinely opens below `kCompletedFraction`, so handing over from inside one
  // records a `scrobbleStop` at roughly 0.88 on Trakt and Simkl and never
  // writes the local watched flag either.
  //
  // On a source libVLC reports as unseekable that seek cannot land, so the
  // chip is not offered at all. The whole band is below the line by
  // construction - `segmentAt` only answers inside the band and the advance
  // point is at or past the band's end - so there is no "already past it" case
  // for the press to fall through into.
  group('VlcPlayerControls Skip Outro on an unseekable source', () {
    // 20 s to 28 s of a 30 s media: inside the band the position is always
    // under the 28.5 s advance point (0.95 of the duration).
    final outroSegment = <SkipSegment>[
      SkipSegment(startTime: 20, endTime: 28, type: SkipType.outro),
    ];

    testWidgets('there is no Next chip to under-report with', (tester) async {
      var advances = 0;
      final engine = FakeVlcEngine();
      await _pumpControls(
        tester,
        engine: engine,
        skipSegments: outroSegment,
        onSkipOutro: () => advances++,
      );

      await _snapshot(tester, position: 21000, isSeekable: false);

      expect(
        find.byType(PlayerActionButton),
        findsNothing,
        reason:
            'the chip is the only PlayerActionButton in an unlocked '
            'build, and it cannot honour what it says here',
      );
      expect(
        advances,
        0,
        reason:
            'nothing can hand over from 0.70 of the media and have the '
            'episode recorded as watched',
      );
      expect(_seeks(engine), isEmpty);

      await _snapshot(
        tester,
        state: 'paused',
        position: 21000,
        isSeekable: false,
      );
    });

    testWidgets('and it comes back, and advances, the moment the engine '
        'reports the source seekable', (tester) async {
      var advances = 0;
      final engine = FakeVlcEngine();
      await _pumpControls(
        tester,
        engine: engine,
        skipSegments: outroSegment,
        onSkipOutro: () => advances++,
      );

      await _snapshot(tester, position: 21000, isSeekable: false);
      expect(find.byType(PlayerActionButton), findsNothing);

      // A torrent that has filled in its pieces is the everyday case. The flag
      // is not a throttled field, so this publishes on the spot.
      await _snapshot(tester, position: 21000, isSeekable: true);
      expect(
        find.byType(PlayerActionButton),
        findsOneWidget,
        reason: 'withheld, not withdrawn for the session',
      );
      expect(
        // Read off the chip rather than by icon: the bottom bar's own
        // next-episode button carries the same glyph.
        tester.widget<PlayerActionButton>(find.byType(PlayerActionButton)).icon,
        Icons.skip_next_rounded,
      );

      await tester.tap(find.byType(PlayerActionButton));
      await tester.pump();

      expect(
        _seeks(engine),
        <int>[28500],
        reason:
            '0.95 of the media, which is past kCompletedFraction, so the '
            'last sample the tracker sees is a completed one',
      );
      expect(advances, 1);

      await tester.pump(const Duration(milliseconds: 400));
      await _snapshot(tester, state: 'paused', position: 28500);
    });

    // The guard is on the advance, not on the chip: an intro is a pure seek,
    // and a dead press there costs a press, not a watch. Widening it would
    // take the chip away from every source the engine has not called seekable.
    testWidgets('an intro on the same stream keeps its chip', (tester) async {
      final engine = FakeVlcEngine();
      await _pumpControls(
        tester,
        engine: engine,
        skipSegments: <SkipSegment>[
          SkipSegment(startTime: 0, endTime: 60, type: SkipType.intro),
        ],
        onSkipOutro: () {},
      );

      await _snapshot(tester, position: 1000, isSeekable: false);

      expect(find.byIcon(Icons.fast_forward_rounded), findsOneWidget);

      await _snapshot(
        tester,
        state: 'paused',
        position: 1000,
        isSeekable: false,
      );
    });
  });

  // The same geometry claims at 844x390, where the numbers actually have to
  // work: the glyph is the compact 72 dp disc, and both readouts have to miss
  // it with tens of pixels to spare rather than the hundreds a 2560x1440 frame
  // gives them.
  group('VlcPlayerControls touch geometry on a phone', () {
    testWidgets('the centre glyph is the compact disc there', (tester) async {
      await _pumpControls(tester, isTv: false, size: _phone);

      expect(
        tester.getSize(find.byType(PlayerCenterPlayButton)),
        const Size(72, 72),
        reason:
            'under a 600 dp shortest side the disc is the 72 dp one, and '
            'it is the thing the toast and the burst are measured against',
      );

      await _snapshot(tester, state: 'paused');
    });

    testWidgets('the swipe toast is nudged clear of the glyph', (tester) async {
      await _pumpControls(tester, isTv: false, size: _phone);
      final centre = tester.getCenter(find.byType(VlcPlayerControls));
      final glyph = tester.getRect(find.byType(PlayerCenterPlayButton));

      await tester.dragFrom(centre, const Offset(200, 0));
      await tester.pump();

      final message = find.descendant(
        of: find.byType(PlayerToast),
        matching: find.byType(Text),
      );
      expect(message, findsOneWidget);
      final Rect toast = tester.getRect(message);
      expect(
        toast.overlaps(glyph),
        isFalse,
        reason:
            'on a 390 dp tall frame the nudge is worth about 66 px and '
            'the disc reaches 36 px above centre: a smaller nudge lands the '
            'swipe readout on the disc here while still clearing it on a '
            'television',
      );
      expect(
        toast.bottom,
        lessThan(glyph.top),
        reason: 'clear of it upwards, which is where the nudge points',
      );

      // The 50 ms lets the double-tap recogniser's minimum-gap countdown lapse.
      await tester.pump(const Duration(milliseconds: 50));
      await _snapshot(tester, state: 'paused', position: 1000);
    });

    testWidgets('the double-tap burst lands on its own half, clear of the '
        'glyph', (tester) async {
      final engine = FakeVlcEngine();
      await _pumpControls(tester, isTv: false, size: _phone, engine: engine);
      final centre = tester.getCenter(find.byType(VlcPlayerControls));
      final glyph = tester.getRect(find.byType(PlayerCenterPlayButton));
      final right = centre + const Offset(250, 0);

      await tester.tapAt(right);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(right);
      await tester.pump(const Duration(milliseconds: 50));

      expect(_seeks(engine), <int>[10000]);
      expect(find.text('10s'), findsOneWidget);
      expect(
        tester.getCenter(find.text('10s')).dx,
        greaterThan(centre.dx),
        reason: 'the readout says which half fired by being on it',
      );
      // The whole disc, not just the digits: the ripple is the part that would
      // wash over the play glyph, and here it is 0.44 of the shortest side
      // rather than the 176 dp cap a television takes. The Stack fills the
      // burst's SizedBox.square exactly and is the one unambiguous handle on
      // it, since Icon puts an ExcludeSemantics of its own inside.
      final Rect burst = tester.getRect(
        find.descendant(
          of: find.byType(PlayerSeekBurst),
          matching: find.byType(Stack),
        ),
      );
      expect(
        burst.overlaps(glyph),
        isFalse,
        reason:
            'a 171 dp burst pinned at 0.62 of a 844 dp frame clears a 72 '
            'dp centre disc by about 86 px; the television it was measured on '
            'has room for both several times over',
      );

      await _snapshot(tester, state: 'paused', position: 10000);
    });
  });
}
