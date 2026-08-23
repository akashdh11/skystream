import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_view/video_view.dart' as vv;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/providers/device_info_provider.dart';
import '../../../../features/settings/presentation/player_settings_provider.dart';
import 'widgets/skystream_player_controls.dart';
import 'widgets/hotstar_player_style.dart';
import 'player_controller.dart';
import 'player_gesture_handler.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final MultimediaItem item;
  final String videoUrl;
  final Episode? episode;
  final List<StreamResult>? preloadedStreams;

  const PlayerScreen({
    super.key,
    required this.item,
    required this.videoUrl,
    this.episode,
    this.preloadedStreams,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with WidgetsBindingObserver {
  late final Player _player;
  late final VideoController _videoController; // media_kit renderer
  // video_view (ExoPlayer/AVPlayer). Null until a live stream actually needs
  // it — constructing it spins up an ExoPlayer, two SurfaceProducers and a
  // SubtitlePainter, which every VOD session used to pay for and never use.
  vv.VideoController? _videoViewController;

  /// Builds the video_view engine on first use and remembers it. Handed to
  /// PlayerController, which calls it only when it decides a stream needs the
  /// native live path.
  vv.VideoController _ensureVideoViewController() =>
      _videoViewController ??= vv.VideoController(autoPlay: true);

  final ValueNotifier<BoxFit> _videoFit = ValueNotifier(BoxFit.contain);
  // Mirrors SkyStreamPlayerControlsState._isVisible, fed by its
  // onVisibilityChanged callback. Starts false to match the child's
  // initial state; the child will push true once it decides controls
  // should be visible (immediately on TV; on duration-load elsewhere).
  // Used here for subtitle Y-offset computation and the TV back-to-hide
  // intercept in PopScope.
  final ValueNotifier<bool> _controlsVisible = ValueNotifier(false);

  final GlobalKey<SkyStreamPlayerControlsState> _controlsKeyFinal = GlobalKey();

  // The persistent root key handler. It always stays focusable (it is the
  // parent of the ExcludeFocus'd chrome), so when the controls hide we route
  // focus back here and the next remote/keyboard press is guaranteed to be
  // seen — the single mechanism that keeps D-pad alive after auto-hide.
  final FocusNode _rootFocusNode = FocusNode(debugLabel: 'player_root');

  // Some TVs deliver a single Back press through two channels (a goBack
  // KeyEvent *and* a route pop). This timestamp de-dupes them so one physical
  // press performs exactly one back action — see [_consumeBack].
  DateTime? _lastBackAt;

  bool _isTv = false;
  bool _isTablet = false;
  bool _wasPlayingBeforeBackground = false;
  bool _spaceHeldForSpeed = false;
  double? _speedBeforeSpaceHold;
  Timer? _spaceHoldTimer;

  bool _customFontLoaded = false;
  String? _lastLoadedFontPath;
  SubtitleViewConfiguration? _cachedSubtitleConfig;
  String? _cachedSubtitleKey;

  SubtitleViewConfiguration _getOrCreateSubtitleConfiguration(
    PlayerSettings settings,
  ) {
    final key =
        '${settings.subTypefaceFilePath}_${settings.subTypeface}_'
        '${settings.subFixedTextSize}_${settings.subtitleSize}_'
        '${settings.subForegroundColor}_${settings.subtitleColor}_'
        '${settings.subEdgeColor}_${settings.subEdgeSize}_'
        '${settings.subEdgeType}_${settings.subBackgroundColor}_'
        '${settings.subtitleBackgroundColor}_${settings.subBackgroundOpacity}_'
        '${settings.subBold}_${settings.subItalic}_${settings.subAlignment}_$_customFontLoaded';

    if (_cachedSubtitleConfig != null && _cachedSubtitleKey == key) {
      return _cachedSubtitleConfig!;
    }
    _cachedSubtitleKey = key;
    _cachedSubtitleConfig = _buildSubtitleConfiguration(settings);
    return _cachedSubtitleConfig!;
  }

  Future<void> _loadCustomFontIfNeeded(PlayerSettings settings) async {
    final path = settings.subTypefaceFilePath;
    if (path != null && path.isNotEmpty && path != _lastLoadedFontPath) {
      _lastLoadedFontPath = path;
      try {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final fontLoader = FontLoader('CustomSubtitleFont');
          fontLoader.addFont(Future.value(ByteData.sublistView(bytes)));
          await fontLoader.load();
          if (mounted) {
            setState(() {
              _customFontLoaded = true;
            });
          }
        }
      } catch (e) {
        debugPrint("Failed to load custom font in player: $e");
      }
    }
  }

  late final PlayerController _playerController;
  ProviderSubscription<AsyncValue<PlayerSettings>>? _settingsSub;

  @override
  void initState() {
    super.initState();
    MediaKit.ensureInitialized();
    WidgetsBinding.instance.addObserver(this);

    final deviceProfile = ref.read(deviceProfileProvider).asData?.value;
    _isTv = deviceProfile?.isTv ?? false;
    _isTablet = deviceProfile?.isTablet ?? false;

    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    WakelockPlus.enable();

    // Initialize player with larger buffer for torrent streaming
    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 128 * 1024 * 1024, // 128MB
      ),
    );

    // Increase network timeout to allow TorrServer to pre-buffer
    if (_player.platform is NativePlayer) {
      final native = _player.platform as NativePlayer;
      native.setProperty('network-timeout', '120');
      native.setProperty('force-seekable', 'yes');
      // Increase metadata probing depth to match VLC (resolves missing language tags)
      native.setProperty('demuxer-lavf-probesize', '33554432'); // 32MB
      // 30s covers the worst-case HLS segment duration; shorter values cause
      // mpv to miss video tracks in streams with 30s segments.
      native.setProperty('demuxer-lavf-analyzeduration', '30');
      // Enable verbose HLS/lavf logging in debug so variant selection and
      // segment fetch errors are visible in logcat.
      if (kDebugMode) {
        native.setProperty('msg-level', 'hls=v,lavf=v,ffmpeg/demuxer=v');
      }
      // Disable native MPV subtitle rendering on the video surface.
      // media_kit sets this at creation when libass=false, but MPV resets
      // it when a new file is opened. We re-assert it here and in
      // _applyPlaybackProperties / applySubtitleSettings as well.
      native.setProperty('sub-visibility', 'no');
    }
    _videoController = VideoController(_player);


    _settingsSub = ref.listenManual<AsyncValue<PlayerSettings>>(
      playerSettingsProvider,
      (_, next) {
        final settings = next.asData?.value;
        if (settings == null) return;
        if (settings.defaultResizeMode == "Zoom") {
          _videoFit.value = BoxFit.cover;
        } else if (settings.defaultResizeMode == "Stretch") {
          _videoFit.value = BoxFit.fill;
        }
        _loadCustomFontIfNeeded(settings);
      },
      fireImmediately: true,
    );

    _playerController = ref.read(playerControllerProvider.notifier);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playerController.init(
        player: _player,
        item: widget.item,
        videoUrl: widget.videoUrl,
        episode: widget.episode,
        preloadedStreams: widget.preloadedStreams,
        videoViewFactory: _ensureVideoViewController,
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Desktop platforms (Windows, macOS, Linux) do not have mobile OS background
    // restrictions or socket freezes when minimized/unfocused; users expect playback
    // to continue in the background on desktop.
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      _playerController.setAppBackgrounded(true);
      final ctrl = ref.read(playerControllerProvider);
      _wasPlayingBeforeBackground = ctrl.useExoPlayer
          ? _videoViewController?.playbackState.value ==
                vv.VideoControllerPlaybackState.playing
          : _player.state.playing;
      _playerController.saveProgress();
      _playerController.pause();

      // Tear down any in-flight space-hold speed boost. If the user is
      // holding space (2× speed) and the OS backgrounds the app, the
      // KeyUp event is lost — leaving the state machine stuck with
      // _spaceHeldForSpeed=true forever. Subsequent space taps would
      // see the wrong branch. Reset speed back to whatever the user had
      // before the hold so we resume at the right rate.
      _spaceHoldTimer?.cancel();
      _spaceHoldTimer = null;
      if (_spaceHeldForSpeed) {
        final previousSpeed = _speedBeforeSpaceHold ?? 1.0;
        _spaceHeldForSpeed = false;
        _speedBeforeSpaceHold = null;
        unawaited(_playerController.setPlaybackSpeed(previousSpeed));
      }
    } else if (state == AppLifecycleState.resumed) {
      _playerController.setAppBackgrounded(false);
      // Wakelock: re-acquire whenever the engine is currently playing on
      // resume — not just when WE auto-paused on background. External
      // play sources (media-session play from a notification, Bluetooth
      // headphones, Android Auto) can flip playing=true while the app
      // is backgrounded; the user then foregrounds the app to a playing
      // stream with NO wakelock, and the screen sleeps during playback.
      // (H-PLAYER-4)
      final ctrl = ref.read(playerControllerProvider);
      final isCurrentlyPlaying = ctrl.useExoPlayer
          ? _videoViewController?.playbackState.value ==
                vv.VideoControllerPlaybackState.playing
          : _player.state.playing;
      if (isCurrentlyPlaying) {
        WakelockPlus.enable();
      }

      // Only auto-play if we paused for backgrounding — don't override the
      // user's explicit pause-before-background intent.
      if (_wasPlayingBeforeBackground) {
        _wasPlayingBeforeBackground = false;
        WakelockPlus.enable();
        _playerController.play();
      }
    }
  }

  void _updateResizeMode(BoxFit mode) {
    if (mounted) _videoFit.value = mode;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // Restore the system UI FIRST, before any disposal that could throw and
    // skip this. immersiveSticky is set for all mobile in initState, so it
    // must always be cleared on exit (on FireTV, leaving it active also makes
    // the system swallow hardware back-button events).
    //
    // Use manual + all overlays rather than edgeToEdge: leaving immersiveSticky
    // for edgeToEdge does NOT reliably re-show the status/navigation bars on
    // Android, so the user returns to a normal screen with the status bar
    // still hidden. manual + SystemUiOverlay.values forces both bars back —
    // the expected default behaviour off the player.
    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
      if (!_isTv) {
        if (_isTablet) {
          SystemChrome.setPreferredOrientations([]);
        } else {
          SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        }
      }
    }

    _settingsSub?.close();

    // Restore the pre-space-hold rate BEFORE anything is torn down.
    //
    // This used to run at the end of dispose(), after `_player.dispose()` — a
    // use-after-dispose that called setRate() on a destroyed Player. It is not
    // dead code, so it cannot simply be deleted: PlayerController is
    // ref.keepAlive()'d, so `state.playbackSpeed` outlives this screen, and
    // leaving it at the temporary hold speed leaks 2x into the next playback.
    _spaceHoldTimer?.cancel();
    if (_spaceHeldForSpeed) {
      unawaited(_playerController.setPlaybackSpeed(_speedBeforeSpaceHold ?? 1.0));
      _spaceHeldForSpeed = false;
    }

    _playerController.disposeController();

    _player.dispose();
    _videoViewController?.dispose();
    _controlsVisible.dispose();
    _videoFit.dispose();
    _rootFocusNode.dispose();

    WakelockPlus.disable();

    // Restore brightness if the user adjusted it via the gesture handler.
    // Without this, exiting the player leaves the device at whatever dim
    // value the user set, until they manually adjust again (audit H4).
    // Idempotent and safe on platforms without an override active.
    unawaited(ScreenBrightness().resetApplicationScreenBrightness());
    if (!Platform.isAndroid && !Platform.isIOS) {
      try {
        windowManager.setFullScreen(false);
      } catch (e) {
        if (kDebugMode) debugPrint('PlayerScreen.dispose: $e');
      }
    }
    super.dispose();
  }

  bool _isPlayActivationKey(KeyEvent event) =>
      event.logicalKey == LogicalKeyboardKey.select ||
      event.logicalKey == LogicalKeyboardKey.enter ||
      event.logicalKey == LogicalKeyboardKey.mediaPlayPause;

  /// Root key handler. Deliberately small: when a control is focused it stays
  /// out of the way so native directional traversal + the focused control's
  /// own activation run; it only acts when *no* control is focused (controls
  /// hidden / video-only) or for global media shortcuts on desktop.
  ///
  /// `primaryFocus == node` means the root node itself holds focus — i.e. no
  /// chrome control is focused. This is how we tell "hidden / video-only" from
  /// "a button is focused" without any manual focus bookkeeping.
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    final rootHasFocus = FocusManager.instance.primaryFocus == node;

    // Escape (desktop/keyboard) → dismiss via the single guarded handler.
    // Hardware/remote Back is intentionally NOT handled here: on Android/TV it
    // is delivered reliably to PopScope (the navigation channel), and the
    // redundant goBack KeyEvent must stay unhandled so the two deliveries can't
    // both act and walk past a dismissal into exiting the player. Desktop has
    // no PopScope-back, so Escape is its dismissal key.
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      return _consumeBack() ? KeyEventResult.handled : KeyEventResult.ignored;
    }

    // Space-hold → 2× speed (non-TV). Only when no control is focused, so
    // Space still activates a focused button normally.
    if (!_isTv &&
        rootHasFocus &&
        event.logicalKey == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) {
        _spaceHoldTimer ??= Timer(const Duration(milliseconds: 260), () {
          if (!mounted || _spaceHeldForSpeed) return;
          _spaceHeldForSpeed = true;
          _speedBeforeSpaceHold = ref
              .read(playerControllerProvider)
              .playbackSpeed;
          unawaited(
            ref.read(playerControllerProvider.notifier).setPlaybackSpeed(2.0),
          );
          ref
              .read(playerGestureHandlerProvider.notifier)
              .showToast("2.0x", Icons.fast_forward_rounded);
        });
        return KeyEventResult.handled;
      }
      if (event is KeyRepeatEvent) {
        if (!_spaceHeldForSpeed) {
          _spaceHoldTimer?.cancel();
          _spaceHoldTimer = null;
          _spaceHeldForSpeed = true;
          _speedBeforeSpaceHold = ref
              .read(playerControllerProvider)
              .playbackSpeed;
          unawaited(
            ref.read(playerControllerProvider.notifier).setPlaybackSpeed(2.0),
          );
          ref
              .read(playerGestureHandlerProvider.notifier)
              .showToast("2.0x", Icons.fast_forward_rounded);
        }
        return KeyEventResult.handled;
      }
      if (event is KeyUpEvent) {
        _spaceHoldTimer?.cancel();
        _spaceHoldTimer = null;
        if (!_spaceHeldForSpeed) {
          _controlsKeyFinal.currentState?.togglePlayPause();
          _controlsKeyFinal.currentState?.onUserInteraction();
          return KeyEventResult.handled;
        }
        final previousSpeed = _speedBeforeSpaceHold ?? 1.0;
        _spaceHeldForSpeed = false;
        _speedBeforeSpaceHold = null;
        unawaited(
          ref
              .read(playerControllerProvider.notifier)
              .setPlaybackSpeed(previousSpeed),
        );
        ref
            .read(playerGestureHandlerProvider.notifier)
            .showToast(
              "${previousSpeed.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}x",
              Icons.play_arrow_rounded,
            );
        return KeyEventResult.handled;
      }
    }

    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    // A chrome control is focused: let it activate (select/enter/space via
    // Shortcuts + Material) and let arrows drive directional traversal. On
    // desktop we still honor the media convention of ←/→/↑/↓ seeking/volume.
    if (!rootHasFocus) {
      if (!_isTv) {
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _controlsKeyFinal.currentState?.triggerSeek(true);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _controlsKeyFinal.currentState?.triggerSeek(false);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _controlsKeyFinal.currentState?.changeVolume(0.05);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _controlsKeyFinal.currentState?.changeVolume(-0.05);
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    }

    // From here the root has focus — no control is focused (controls hidden
    // or video-only). On TV, if controls are visible, we recover focus.
    if (_isTv && _controlsVisible.value) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.arrowDown ||
          event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.arrowRight ||
          _isPlayActivationKey(event)) {
        _controlsKeyFinal.currentState?.showControls();
        return KeyEventResult.handled;
      }
    }

    if (_isTv && !_controlsVisible.value) {
      if (event.logicalKey == LogicalKeyboardKey.goBack ||
          event.logicalKey == LogicalKeyboardKey.escape) {
        return KeyEventResult.ignored;
      }
      // First press just wakes the chrome (focus lands on play/pause). It does
      // NOT toggle playback — pressing OK again, now that play/pause is focused,
      // is what pauses/plays. (Avoids the jarring "OK pauses then shows chrome".)
      _controlsKeyFinal.currentState?.showControls();
      return KeyEventResult.handled;
    }

    // Global media shortcuts (root-focused on any platform).
    if (_isPlayActivationKey(event)) {
      _controlsKeyFinal.currentState?.togglePlayPause();
      _controlsKeyFinal.currentState?.onUserInteraction();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyM) {
      _controlsKeyFinal.currentState?.toggleMute();
      _controlsKeyFinal.currentState?.onUserInteraction();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyZ) {
      _controlsKeyFinal.currentState?.cycleResize();
      _controlsKeyFinal.currentState?.onUserInteraction();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyF) {
      _controlsKeyFinal.currentState?.toggleFullscreen();
      _controlsKeyFinal.currentState?.onUserInteraction();
      return KeyEventResult.handled;
    }

    // TV with controls already visible but focus on root (rare/transient) —
    // leave arrows for traversal.
    if (_isTv) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _controlsKeyFinal.currentState?.changeVolume(0.05);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _controlsKeyFinal.currentState?.changeVolume(-0.05);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _controlsKeyFinal.currentState?.triggerSeek(true);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _controlsKeyFinal.currentState?.triggerSeek(false);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// The single Back-handling decision, shared by the root key handler and
  /// PopScope. Performs at most one dismissal — close the sources panel, else
  /// (on TV, while playing) hide the controls — and de-dupes the duplicate Back
  /// delivery within a short window. Returns true when the press was consumed
  /// (the caller must NOT exit); false when there's nothing left to dismiss.
  bool _consumeBack() {
    final now = DateTime.now();
    if (_lastBackAt != null &&
        now.difference(_lastBackAt!) < const Duration(milliseconds: 200)) {
      // Near-instant duplicate delivery of the same physical press — swallow
      // it. Short enough not to eat an intentional fast double-press.
      return true;
    }
    if (_controlsKeyFinal.currentState?.isFullscreen == true) {
      _lastBackAt = now;
      unawaited(_controlsKeyFinal.currentState?.toggleFullscreen());
      return true;
    }
    final s = ref.read(playerControllerProvider);
    if (s.showSourcesPanel || s.showEpisodeList || s.showContentPanel) {
      _lastBackAt = now;
      _controlsKeyFinal.currentState?.closeActivePanel();
      return true;
    }
    if (_isTv && _controlsVisible.value) {
      final isPlaying =
          ref.read(playerControllerProvider.select((s) => s.useExoPlayer))
          ? _videoViewController?.playbackState.value ==
                vv.VideoControllerPlaybackState.playing
          : _player.state.playing;
      if (isPlaying) {
        _lastBackAt = now;
        _controlsKeyFinal.currentState?.hideControls();
        return true;
      }
    }
    return false;
  }

  Future<void> _handleBack() async {
    if (!context.mounted) return;

    if (!Platform.isAndroid && !Platform.isIOS) {
      try {
        await windowManager.setFullScreen(false);
        await Future<void>.delayed(const Duration(seconds: 1));
      } catch (e) {
        if (kDebugMode) debugPrint('PlayerScreen._handleBack: $e');
      }
    }

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = ref.watch(
      playerControllerProvider.select((s) => s.errorMessage),
    );
    final isLoading = ref.watch(
      playerControllerProvider.select((s) => s.isLoading),
    );

    if (errorMessage != null) {
      return Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 56,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.playbackError,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        errorMessage,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        autofocus: true,
                        onPressed: _handleBack,
                        icon: const Icon(Icons.arrow_back),
                        label: Text(AppLocalizations.of(context)!.goBack),
                      ),
                    ],
                  ),
                ),
              ),
              // Top-left back button — always visible for iOS/desktop
              // where there may be no system back gesture.
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: AppLocalizations.of(context)!.goBack,
                  onPressed: _handleBack,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // Single guarded path (shared with the root key handler): close the
        // sources panel, else hide TV controls. Only exit when nothing is
        // left to dismiss. The de-dupe inside prevents the dual Back
        // delivery (KeyEvent + route-pop) from skipping a step into exit.
        if (_consumeBack()) return;
        await _handleBack();
      },
      child: Scaffold(
        body: Focus(
          focusNode: _rootFocusNode,
          autofocus: true,
          onKeyEvent: _handleKey,
          // Map the TV remote OK key (select) to ActivateIntent so the
          // focused control activates natively (Enter/Space/gameButtonA are
          // already mapped by WidgetsApp). When no control is focused this
          // bubbles up to the root handler instead.
          child: Shortcuts(
            shortcuts: const <ShortcutActivator, Intent>{
              SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
            },
            child: Stack(
              children: [
                RepaintBoundary(
                  child: ValueListenableBuilder<BoxFit>(
                    valueListenable: _videoFit,
                    builder: (_, fit, child) => Center(
                      // Phase 8: Switch engine based on stream type
                      child: Consumer(
                        builder: (context, ref, _) {
                          final useExoPlayer = ref.watch(
                            playerControllerProvider.select(
                              (s) => s.useExoPlayer,
                            ),
                          );
                          if (useExoPlayer) {
                            return vv.VideoView(
                              controller: _ensureVideoViewController(),
                              videoFit: fit,
                            );
                          }
                          return Video(
                            controller: _videoController,
                            fit: fit,
                            subtitleViewConfiguration:
                                const SubtitleViewConfiguration(
                                  visible: false,
                                  style: TextStyle(color: Colors.transparent),
                                ),
                            controls: (state) => const SizedBox.shrink(),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final useExoPlayer = ref.watch(
                      playerControllerProvider.select((s) => s.useExoPlayer),
                    );
                    if (useExoPlayer) {
                      return const SizedBox.shrink();
                    }

                    final subtitleSettings =
                        ref.watch(playerSettingsProvider).asData?.value ??
                        const PlayerSettings();

                    final baseHiddenOffset = _isTv ? 32.0 : 20.0;
                    final baseVisibleOffset = _isTv ? 96.0 : 84.0;

                    return ValueListenableBuilder<bool>(
                      valueListenable: _controlsVisible,
                      builder: (context, controlsVisible, _) {
                        final bottomOffset =
                            (controlsVisible
                                ? baseVisibleOffset
                                : baseHiddenOffset) +
                            subtitleSettings.subElevation.toDouble() +
                            ((100 - subtitleSettings.subtitlePosition) *
                                (MediaQuery.sizeOf(context).height * 0.008));

                        return AnimatedPositioned(
                          duration: HotstarPlayerStyle.controlFadeDuration,
                          curve: Curves.easeOutCubic,
                          bottom: bottomOffset,
                          left: 20,
                          right: 20,
                          child: IgnorePointer(
                            child: SubtitleView(
                              controller: _videoController,
                              configuration: _getOrCreateSubtitleConfiguration(
                                subtitleSettings,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                Positioned.fill(
                  child: RepaintBoundary(
                    child: SkyStreamPlayerControls(
                      key: _controlsKeyFinal,
                      isLoading: isLoading,
                      player: _player,
                      videoViewController: _videoViewController,
                      title: widget.item.title,
                      subtitle: ref
                          .read(playerControllerProvider)
                          .streamSubtitle,
                      backdropUrl: widget.item.backdropImageUrl,
                      logoUrl: widget.item.logoUrl,
                      onResize: _updateResizeMode,
                      onBackPointer: _handleBack,
                      onRequestRootFocus: () => _rootFocusNode.requestFocus(),
                      onVisibilityChanged: (v) {
                        if (mounted) {
                          _controlsVisible.value = v;
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  SubtitleViewConfiguration _buildSubtitleConfiguration(
    PlayerSettings settings,
  ) {
    // 1. Font family
    String? fontFamily;
    const List<String> builtInFonts = [
      'Normal (system sans-serif)',
      'Trebuchet MS',
      'Netflix Sans',
      'Google Sans',
      'Open Sans',
      'Futura',
      'Consolas',
      'Gotham',
      'Lucida Grande',
      'STIX General',
      'Times New Roman',
      'Verdana',
      'Ubuntu',
      'Comic Sans MS',
      'Poppins',
    ];

    if (settings.subTypefaceFilePath != null &&
        settings.subTypefaceFilePath!.isNotEmpty &&
        _customFontLoaded) {
      fontFamily = 'CustomSubtitleFont';
    } else if (settings.subTypeface != null &&
        settings.subTypeface! > 0 &&
        settings.subTypeface! < builtInFonts.length) {
      fontFamily = builtInFonts[settings.subTypeface!];
    }

    final fontSize = settings.subFixedTextSize ?? settings.subtitleSize;
    final fgColor = Color(
      settings.subForegroundColor != 0xFFFFFFFF
          ? settings.subForegroundColor
          : settings.subtitleColor,
    );

    final edgeColor = Color(settings.subEdgeColor);
    final edgeSize = settings.subEdgeSize ?? 2.5;

    List<Shadow>? shadows;
    switch (settings.subEdgeType) {
      case 0: // None
        shadows = null;
        break;
      case 1: // Outline
        shadows = [
          Shadow(offset: const Offset(-1.5, -1.5), color: edgeColor),
          Shadow(offset: const Offset(1.5, -1.5), color: edgeColor),
          Shadow(offset: const Offset(1.5, 1.5), color: edgeColor),
          Shadow(offset: const Offset(-1.5, 1.5), color: edgeColor),
          Shadow(offset: const Offset(0, -1.5), color: edgeColor),
          Shadow(offset: const Offset(0, 1.5), color: edgeColor),
          Shadow(offset: const Offset(-1.5, 0), color: edgeColor),
          Shadow(offset: const Offset(1.5, 0), color: edgeColor),
        ];
        break;
      case 2: // Raised
        shadows = [
          Shadow(
            offset: const Offset(-1, -1),
            color: edgeColor.withValues(alpha: 0.5),
          ),
          Shadow(
            offset: const Offset(1, 1),
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ];
        break;
      case 3: // Shadow / Drop Shadow
        shadows = [
          Shadow(
            offset: Offset(edgeSize, edgeSize),
            blurRadius: 2.0,
            color: edgeColor,
          ),
        ];
        break;
      case 4: // Uniform Drop Shadow
        shadows = [
          Shadow(offset: const Offset(1, 1), color: edgeColor),
          Shadow(
            offset: const Offset(2, 2),
            color: edgeColor.withValues(alpha: 0.5),
          ),
        ];
        break;
    }

    final bgColorValue = settings.subBackgroundColor != 0x00000000
        ? settings.subBackgroundColor
        : settings.subtitleBackgroundColor;
    final bgOpacity = settings.subBackgroundOpacity;
    final Color? backgroundColor =
        (bgColorValue != 0x00000000 && bgOpacity > 0.0)
        ? Color(bgColorValue).withValues(alpha: bgOpacity)
        : null;

    var baseStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: settings.subBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: settings.subItalic ? FontStyle.italic : FontStyle.normal,
      color: fgColor,
      backgroundColor: backgroundColor,
      shadows: shadows,
    );

    if (fontFamily != null) {
      switch (fontFamily.toLowerCase()) {
        case 'open sans':
          baseStyle = GoogleFonts.openSans(textStyle: baseStyle);
          break;
        case 'poppins':
          baseStyle = GoogleFonts.poppins(textStyle: baseStyle);
          break;
        case 'ubuntu':
          baseStyle = GoogleFonts.ubuntu(textStyle: baseStyle);
          break;
        default:
          baseStyle = baseStyle.copyWith(fontFamily: fontFamily);
          break;
      }
    }

    final alignmentCode = settings.subAlignment ?? 2;
    final textAlign = switch (alignmentCode) {
      1 || 4 || 7 => TextAlign.left,
      3 || 6 || 9 => TextAlign.right,
      _ => TextAlign.center,
    };

    return SubtitleViewConfiguration(
      visible: true,
      style: baseStyle,
      textAlign: textAlign,
      padding: EdgeInsets.zero,
    );
  }
}
