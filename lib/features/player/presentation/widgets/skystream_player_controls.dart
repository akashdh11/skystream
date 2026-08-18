import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:flutter/services.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:video_view/video_view.dart' as vv;
import '../../../../l10n/generated/app_localizations.dart';
import '../player_controller.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/models/torrent_status.dart';
import '../components/torrent_info_widget.dart';
import '../../../settings/presentation/player_settings_provider.dart';
import '../../../../core/providers/device_info_provider.dart';
import '../../../../core/utils/responsive_breakpoints.dart';
import 'player_stream_widgets.dart';
import 'player_control_components.dart';
import 'next_episode_overlay.dart';
import 'resume_prompt_overlay.dart';
import 'player_side_panel.dart';
import 'player_bottom_sheets.dart';
import 'player_loading_overlay.dart';
import 'player_osd_overlay.dart';
import 'skip_segment_overlay.dart';
import 'hotstar_player_style.dart';
import '../player_platform_service.dart';
import '../player_gesture_handler.dart';
import 'player_metadata_scrim.dart';

class SkyStreamPlayerControls extends ConsumerStatefulWidget {
  final Player player;
  final vv.VideoController? videoViewController;
  final String? title;
  final String? subtitle;
  final VoidCallback? onBackPointer;
  final List<StreamResult>? streams;
  final StreamResult? currentStream;

  final List<SubtitleFile>? externalSubtitles;
  final TorrentStatus? torrentStatus;
  final void Function(StreamResult)? onStreamSelected;
  final void Function(int)? onTorrentFileSelected;
  final void Function(BoxFit)? onResize;
  final void Function(bool)? onVisibilityChanged;

  /// Called when the chrome hides so the parent can return focus to its
  /// persistent root handler node (which lives outside the ExcludeFocus
  /// subtree). This is the single mechanism that keeps D-pad alive after the
  /// controls auto-hide — replacing the old `primaryFocus.unfocus()` dance.
  final VoidCallback? onRequestRootFocus;
  final String? backdropUrl;
  final String? logoUrl;

  const SkyStreamPlayerControls({
    super.key,
    required this.player,
    this.videoViewController,
    this.title,
    this.subtitle,
    this.onBackPointer,
    this.streams,
    this.currentStream,
    this.externalSubtitles,
    this.torrentStatus,
    this.onStreamSelected,
    this.onTorrentFileSelected,
    this.onResize,
    this.onVisibilityChanged,
    this.onRequestRootFocus,
    this.backdropUrl,
    this.logoUrl,
    this.isLoading = false,
  });

  final bool isLoading;

  @override
  ConsumerState<SkyStreamPlayerControls> createState() =>
      SkyStreamPlayerControlsState();
}

class SkyStreamPlayerControlsState
    extends ConsumerState<SkyStreamPlayerControls>
    with SingleTickerProviderStateMixin {
  bool _isVisible = false;
  bool _isIpad = false;
  bool _isTv = false;
  bool _isInPip = false;

  void togglePlayPause() => _togglePlay();

  bool _showTorrentInfo = false; // Changed from true
  Timer? _hideTimer;
  DateTime? _lastHoverTime;

  void _handleThrottledHover() {
    if (_panelOpen) return;
    final now = DateTime.now();
    if (_lastHoverTime != null &&
        now.difference(_lastHoverTime!).inMilliseconds < 80) {
      return;
    }
    _lastHoverTime = now;

    if (!_isVisible && mounted) {
      setState(() => _isVisible = true);
      widget.onVisibilityChanged?.call(true);
    }
    _startHideTimer();
  }

  // Metadata scrim (Netflix-style info panel on pause, TV/desktop only)
  final GlobalKey<PlayerMetadataScrimState> _metadataScrimKey = GlobalKey();
  bool _isLocked = false;

  // Seek animation state
  late AnimationController _seekAnimController;
  bool _isSeekingLeft = false;

  int _resizeMode = 0;
  bool _touchHeldForSpeed = false;
  double? _speedBeforeTouchHold;

  late bool _isPlaying;
  late Duration _position;
  late Duration _duration;

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  late final PlayerPlatformService _platformService;
  Offset? _tapPosition;
  Duration _animDuration = HotstarPlayerStyle.controlFadeDuration;
  bool _isFullscreen = false;
  bool get isFullscreen => _isFullscreen;
  // The single focus anchor: when the chrome (re)appears on TV we move focus
  // here (the bottom-row play/pause). Directional traversal handles every
  // other movement between controls — no other requestFocus calls exist.
  late final FocusNode _playFocusNode;
  late final FocusNode _backFocusNode;
  late final FocusNode _scrubFocusNode;
  late final FocusNode _resumeFocusNode;
  late final FocusNode _nextEpFocusNode;
  late final FocusNode _skipFocusNode;
  bool _isSkipActive = false;
  ProviderSubscription<dynamic>? _revertMessageSub;

  @override
  void initState() {
    super.initState();
    final deviceProfile = ref.read(deviceProfileProvider).asData?.value;
    _isTv = deviceProfile?.isTv ?? false;
    _isIpad = Platform.isIOS && (deviceProfile?.isTablet ?? false);

    _platformService = PlayerPlatformService();
    ref
        .read(playerGestureHandlerProvider.notifier)
        .init(
          getSettings: () async =>
              await ref.read(playerSettingsProvider.future),
          isTv: _isTv,
          isDesktop: Platform.isMacOS || Platform.isWindows || Platform.isLinux,
          getDuration: () => _duration,
          getPosition: () => _position,
          canSeek: () => ref.read(playerControllerProvider).canSeek,
          getMaxVolumeLevel: () =>
              ref.read(playerControllerProvider).supportsVolumeBoost
              ? 2.0
              : 1.0,
          onInteraction: () {
            if (!_isVisible) {
              setState(() => _isVisible = true);
              widget.onVisibilityChanged?.call(true);
            }
            _startHideTimer();
          },
          onHideControls: () {
            _cancelHideTimer();
            if (_isVisible && mounted) {
              setState(() => _isVisible = false);
              widget.onVisibilityChanged?.call(false);
            }
          },
          onSeekRelative: (amount) async {
            _seekRelative(amount);
          },
          onSeekTo: (position) =>
              ref.read(playerControllerProvider.notifier).seekTo(position),
          getVolumeLevel: () =>
              ref.read(playerControllerProvider.notifier).getVolumeLevel(),
          setVolumeLevel: (value) =>
              ref.read(playerControllerProvider.notifier).setVolumeLevel(value),
          onVolumeChange: (step) =>
              ref.read(playerControllerProvider.notifier).changeVolume(step),
          toggleMuteLevel: () =>
              ref.read(playerControllerProvider.notifier).toggleMute(),
          onDoubleTapAnimationStart: (isLeft, tapPos, seconds) {
            setState(() {
              _tapPosition = tapPos;
              _isSeekingLeft = isLeft;
            });
            _seekAnimController.forward(from: 0.0);
          },
        );

    _playFocusNode = FocusNode();
    _backFocusNode = FocusNode(debugLabel: 'back_button');
    _scrubFocusNode = FocusNode(debugLabel: 'controls_scrubber');
    _resumeFocusNode = FocusNode(debugLabel: 'resume_prompt');
    _nextEpFocusNode = FocusNode(debugLabel: 'next_episode_prompt');
    _skipFocusNode = FocusNode(debugLabel: 'skip_segment_prompt');
    try {
      FlutterVolumeController.updateShowSystemUI(false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint("VolumeUI Error: $e");
      }
    }
    _isPlaying = widget.player.state.playing;
    _position = widget.player.state.position;
    _duration = widget.player.state.duration;

    // OPTIMIZATION: Removed setState calls for position/buffering - now using StreamBuilder widgets
    // This reduces rebuilds from 60+/second to only when visibility/lock state changes
    _subscriptions.addAll([
      // Playing state: Only for timer/PiP sync, NOT for UI rebuilds (StreamBuilder handles that)
      widget.player.stream.playing.listen((val) {
        final oldPlaying = _isPlaying;
        _isPlaying = val; // Update local cache
        if (mounted) {
          setState(() {}); // Sync isPlaying to overlays (next ep countdown)
        }
        if (val) {
          _startHideTimer();
          // Playing → tell scrim to re-evaluate (will hide immediately).
          _metadataScrimKey.currentState?.resetSchedule();
        } else {
          _cancelHideTimer();
          // Paused → tell scrim to re-evaluate (will schedule 8s show).
          _metadataScrimKey.currentState?.resetSchedule();
        }

        // REBUILD: If we transition to playing but were stuck in loading UI, trigger rebuild
        if (mounted && val && !oldPlaying && _duration == Duration.zero) {
          setState(() {});
        }
        // Sync PiP state with Android
        if (Platform.isAndroid) {
          const MethodChannel(
            'dev.akash.skystream.player/pip',
          ).invokeMethod('setPipState', {'isPlaying': val});
        }
      }),
      // Position: No setState needed - StreamBuilder in PlayerProgressBar handles UI
      widget.player.stream.position.listen((val) {
        _position = val; // Update local cache for seek calculations
      }),
      // Duration: Only setState when transitioning from zero (to show controls)
      widget.player.stream.duration.listen((val) {
        final oldDuration = _duration;
        _duration = val; // Update local cache
        if (mounted && oldDuration == Duration.zero && val != Duration.zero) {
          setState(() {
            _isVisible = true;
          });
          // Notify parent so subtitle-position math and any other
          // parent-side visibility readers stay in sync. Previously the
          // parent's _controlsVisible notifier could diverge from this
          // local _isVisible until the first hide-timer fired.
          widget.onVisibilityChanged?.call(true);
          _startHideTimer();
        }
      }),
      widget.player.stream.width.listen((_) => _updateOrientation()),
      widget.player.stream.height.listen((_) => _updateOrientation()),
    ]);

    _seekAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // No addListener needed — AnimatedBuilder wraps the seek widget directly

    // Bridge video_view state into local cache so seek calculations and
    // the loading guard stay correct when ExoPlayer is active.
    widget.videoViewController?.position.addListener(_onVvPosition);
    widget.videoViewController?.playbackState.addListener(_onVvPlaybackState);
    widget.videoViewController?.mediaInfo.addListener(_onVvMediaInfo);
    widget.videoViewController?.videoSize.addListener(_updateOrientation);
    widget.videoViewController?.orientation.addListener(_updateOrientation);

    // PiP is phone/tablet-only — never register the handler on TV.
    if (Platform.isAndroid && !_isTv) {
      const MethodChannel(
        'dev.akash.skystream.player/pip',
      ).setMethodCallHandler((call) async {
        switch (call.method) {
          case 'pipModeChanged':
            if (mounted) {
              setState(() {
                _isInPip = call.arguments as bool;
              });
            }
            break;
          case 'play':
            unawaited(ref.read(playerControllerProvider.notifier).play());
            break;
          case 'pause':
            unawaited(ref.read(playerControllerProvider.notifier).pause());
            break;
          case 'seekForward':
            _seekRelative(const Duration(seconds: 10));
            break;
          case 'seekBackward':
            _seekRelative(const Duration(seconds: -10));
            break;
        }
      });
    }

    if (widget.streams != null && widget.streams!.isNotEmpty) {
      _isVisible = true;
    }
    // On TV, controls should be visible + focused on the play button as
    // soon as the player opens. Otherwise the user has to nudge ↑/↓ on
    // the remote first before the center button responds to select —
    // which is jarring on launch and breaks "press OK to start playing"
    // expectations (B-DPAD-1).
    if (_isTv) {
      _isVisible = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onVisibilityChanged?.call(true);
          _playFocusNode.requestFocus();
        }
      });
    }
    _startHideTimer();
    FocusManager.instance.addListener(_onFocusChange);

    // Surface revert-failure messages as a SnackBar whenever the controller
    // sets one (e.g., source switch failed → reverted to previous stream).
    _revertMessageSub = ref.listenManual(playerControllerProvider, (_, _) {
      final msg = ref
          .read(playerControllerProvider.notifier)
          .consumeRevertMessage();
      if (msg != null && mounted) {
        ref.read(notificationServiceProvider).showInfo(
          msg,
          title: 'Playback',
          icon: Icons.sync_problem_rounded,
        );
      }
    });
  }

  @override
  void didUpdateWidget(SkyStreamPlayerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    widget.videoViewController?.position.removeListener(_onVvPosition);
    widget.videoViewController?.playbackState.removeListener(
      _onVvPlaybackState,
    );
    widget.videoViewController?.mediaInfo.removeListener(_onVvMediaInfo);
    widget.videoViewController?.videoSize.removeListener(_updateOrientation);
    widget.videoViewController?.orientation.removeListener(_updateOrientation);
    if (_touchHeldForSpeed) {
      final previousSpeed = _speedBeforeTouchHold ?? 1.0;
      unawaited(
        ref
            .read(playerControllerProvider.notifier)
            .setPlaybackSpeed(previousSpeed),
      );
    }
    FocusManager.instance.removeListener(_onFocusChange);
    _revertMessageSub?.close();
    _playFocusNode.dispose();
    _backFocusNode.dispose();
    _scrubFocusNode.dispose();
    _resumeFocusNode.dispose();
    _nextEpFocusNode.dispose();
    _skipFocusNode.dispose();
    _hideTimer?.cancel();
    _seekAnimController.dispose();
    for (final s in _subscriptions) {
      s.cancel();
    }
    try {
      ScreenBrightness().resetApplicationScreenBrightness();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to reset brightness: $e');
      }
    }
    try {
      FlutterVolumeController.updateShowSystemUI(true);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to restore volume UI: $e');
    }
    SystemChrome.setPreferredOrientations([]); // Reset to system default
    // Clear the PiP method channel handler to prevent a stale handler from
    // accessing the disposed provider after the player exits.
    if (Platform.isAndroid && !_isTv) {
      const MethodChannel(
        'dev.akash.skystream.player/pip',
      ).setMethodCallHandler(null);
    }
    super.dispose();
  }

  void _updateOrientation() {
    final useExo = ref.read(
      playerControllerProvider.select((s) => s.useExoPlayer),
    );
    if (useExo && widget.videoViewController != null) {
      final size = widget.videoViewController!.videoSize.value;
      final orientation = widget.videoViewController!.orientation.value;

      if (size.width > 0 && size.height > 0) {
        // Swap dimensions if orientation is 90 or 270 degrees
        final isLandscape = orientation == 1 || orientation == 3;
        final w = isLandscape ? size.height : size.width;
        final h = isLandscape ? size.width : size.height;

        _platformService.updateOrientation(w.toInt(), h.toInt());
      }
    } else {
      _platformService.updateOrientation(
        widget.player.state.width,
        widget.player.state.height,
      );
    }
  }

  Future<void> _enterPip() async {
    await _platformService.enterPip(_isPlaying);
  }

  void _toggleOrientation() {
    _platformService.toggleOrientation(context);
  }

  Future<void> toggleFullscreen() async {
    final nowFullscreen = await _platformService.toggleFullscreen();
    if (mounted) {
      setState(() {
        _isFullscreen = nowFullscreen;
      });
    }
  }

  Future<void> _handleDoubleTap() async {
    if (_isLocked || _panelOpen) return;

    // Desktop Double Tap -> Toggle Fullscreen
    try {
      if (context.isDesktop &&
          (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
        unawaited(toggleFullscreen());
        return;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SkyStreamPlayerControls._handleDoubleTap: $e');
      }
    }

    if (widget.isLoading || _duration == Duration.zero) return;
    if (_tapPosition != null) {
      unawaited(
        ref
            .read(playerGestureHandlerProvider.notifier)
            .handleDoubleTap(_tapPosition!, MediaQuery.sizeOf(context).width),
      );
    }
  }

  void _startTouchSpeedHold() {
    if (_isLocked ||
        _panelOpen ||
        _isTv ||
        !(Platform.isAndroid || Platform.isIOS)) {
      return;
    }
    if (_touchHeldForSpeed) return;
    _touchHeldForSpeed = true;
    _speedBeforeTouchHold = ref.read(playerControllerProvider).playbackSpeed;
    unawaited(
      ref.read(playerControllerProvider.notifier).setPlaybackSpeed(2.0),
    );
    ref
        .read(playerGestureHandlerProvider.notifier)
        .showToast("2.0x", Icons.fast_forward_rounded);
  }

  void _endTouchSpeedHold() {
    if (!_touchHeldForSpeed) return;
    final previousSpeed = _speedBeforeTouchHold ?? 1.0;
    _touchHeldForSpeed = false;
    _speedBeforeTouchHold = null;
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
  }

  // ... (keeping other methods same)

  /// Hand focus back to the parent's persistent root handler node when the
  /// chrome hides. The chrome subtree is `ExcludeFocus`'d while hidden, so the
  /// previously-focused control can no longer receive keys; routing focus to
  /// the always-present root node guarantees the next remote/keyboard press is
  /// seen and re-shows the controls. Replaces the old `unfocus()` dance that
  /// dropped focus into an ancestor scope outside the handler's dispatch path.
  void _returnFocusToRoot() {
    widget.onRequestRootFocus?.call();
  }

  void _toggleVisibility() {
    _animDuration = const Duration(milliseconds: 300);
    setState(() {
      _isVisible = !_isVisible;
    });
    widget.onVisibilityChanged?.call(_isVisible);
    if (_isVisible) {
      _startHideTimer();
      if (_isTv) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isVisible) {
            _playFocusNode.requestFocus();
          }
        });
      }
    } else {
      _returnFocusToRoot();
    }
  }

  void hideControls() {
    if (mounted) {
      _hideTimer?.cancel();
      setState(() => _isVisible = false);
      widget.onVisibilityChanged?.call(false);
      _returnFocusToRoot();
      // Reschedule scrim visibility on auto-hide.
      _metadataScrimKey.currentState?.resetSchedule();
    }
  }

  /// Torrent status is passed via widget props from the parent rebuild.
  /// This method is retained for API compatibility but no longer forces a rebuild.
  void updateTorrentStatus(TorrentStatus status) {}

  void showControls() {
    if (mounted) {
      setState(() => _isVisible = true);
      widget.onVisibilityChanged?.call(true);
      _startHideTimer();
      // On TV, always restore focus to the play/pause button when controls
      // become visible — autofocus only fires once when the widget first mounts,
      // so after hide/show cycles we must request focus explicitly.
      if (_isTv) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isVisible) {
            _playFocusNode.requestFocus();
          }
        });
      }
    }
  }

  /// True while a side panel (sources/tracks or episodes) owns the screen. Used
  /// to suspend the chrome and its auto-hide timer so the panel isn't yanked out
  /// from under the user (req: no auto-hide while a side bar is active).
  bool get _panelOpen {
    final s = ref.read(playerControllerProvider);
    return s.showSourcesPanel || s.showEpisodeList || s.showContentPanel;
  }

  /// Hide the chrome and suspend auto-hide so a side panel can take over. The
  /// panel handles its own focus (its current/anchor row).
  void _enterPanelMode() {
    _cancelHideTimer();
    if (_isVisible) {
      setState(() => _isVisible = false);
      widget.onVisibilityChanged?.call(false);
    }
  }

  /// Open the sources/audio/subtitles side panel at [tab] (0=Sources, 1=Audio,
  /// 2=Subtitles).
  void openSourcesPanel(int tab) {
    _enterPanelMode();
    ref.read(playerControllerProvider.notifier).openSourcesPanel(tab: tab);
  }

  /// Open the episodes side panel.
  void openEpisodesPanel() {
    _enterPanelMode();
    ref.read(playerControllerProvider.notifier).openEpisodeList();
  }

  /// Open the torrent content (file picker) side panel.
  void openContentPanel() {
    _enterPanelMode();
    ref.read(playerControllerProvider.notifier).openContentPanel();
  }

  /// Close the sources panel and bring the chrome back with a fresh auto-hide.
  void closeSourcesPanel() {
    if (!ref.read(playerControllerProvider).showSourcesPanel) return;
    ref.read(playerControllerProvider.notifier).closeSourcesPanel();
    showControls();
  }

  /// Close the episodes panel and bring the chrome back with a fresh auto-hide.
  void closeEpisodesPanel() {
    if (!ref.read(playerControllerProvider).showEpisodeList) return;
    ref.read(playerControllerProvider.notifier).closeEpisodeList();
    showControls();
  }

  /// Close the content panel and bring the chrome back with a fresh auto-hide.
  void closeContentPanel() {
    if (!ref.read(playerControllerProvider).showContentPanel) return;
    ref.read(playerControllerProvider.notifier).closeContentPanel();
    showControls();
  }

  /// Close whichever side panel is open — the shared Back/dismiss entry point.
  void closeActivePanel() {
    closeSourcesPanel();
    closeEpisodesPanel();
    closeContentPanel();
  }

  void _onFocusChange() {
    if (_isVisible && mounted) {
      _startHideTimer();
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    // No point arming the timer if controls are already hidden — the timer's
    // body would no-op the setState anyway. Also never arm while the side
    // panel is open: it must stay until the user dismisses it.
    if (!_isVisible || _panelOpen) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() {
          _isVisible = false;
        });
        widget.onVisibilityChanged?.call(false);
        _returnFocusToRoot();
      }
    });
  }

  void onUserInteraction() {
    if (mounted) {
      if (_panelOpen) return; // panel owns the screen; don't surface chrome
      if (!_isVisible) {
        setState(() => _isVisible = true);
        widget.onVisibilityChanged?.call(true);
        // Controls were hidden and an action (OK / mute / resize) brought
        // them back — restore focus to the play button so the user has a
        // live anchor to navigate from. Without this, OK-while-hidden
        // showed the controls but left nothing focused, stranding D-pad.
        if (_isTv) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _isVisible) {
              _playFocusNode.requestFocus();
            }
          });
        }
      }
      _startHideTimer();
    }
  }

  /// Pure timer cancel. Previously this also force-showed the controls when
  /// they were hidden, which caused them to pop back up unexpectedly on every
  /// pause / buffer / stall / network blip (anywhere the playing-state flips
  /// to false). Cancelling the hide-timer and showing the controls are two
  /// separate concerns — keep them separate.
  void _cancelHideTimer() {
    _hideTimer?.cancel();
  }

  // --- video_view bridge listeners ---
  void _onVvPosition() {
    final ms = widget.videoViewController?.position.value ?? 0;
    _position = Duration(milliseconds: ms);
  }

  void _onVvPlaybackState() {
    final state = widget.videoViewController?.playbackState.value;
    final playing = state == vv.VideoControllerPlaybackState.playing;
    if (playing != _isPlaying) {
      _isPlaying = playing;
      if (mounted) {
        setState(() {}); // Sync isPlaying to overlays (next ep countdown)
      }
      if (playing) {
        _startHideTimer();
        _metadataScrimKey.currentState?.resetSchedule();
      } else {
        _cancelHideTimer();
        _metadataScrimKey.currentState?.resetSchedule();
      }
    }
  }

  void _onVvMediaInfo() {
    final info = widget.videoViewController?.mediaInfo.value;
    final ms = info?.duration ?? 0;
    final newDuration = Duration(milliseconds: ms);
    final oldDuration = _duration;
    _duration = newDuration;
    // Show controls when media loads (same logic as media_kit duration listener)
    if (mounted &&
        oldDuration == Duration.zero &&
        newDuration != Duration.zero) {
      setState(() => _isVisible = true);
      widget.onVisibilityChanged?.call(true);
      _startHideTimer();
    }

    if (widget.videoViewController != null) {
      final size = widget.videoViewController!.videoSize.value;
      if (size.width > 0 && size.height > 0) {
        _updateOrientation();
      }
    }
  }
  // ------------------------------------

  void _togglePlay() {
    unawaited(ref.read(playerControllerProvider.notifier).togglePlayPause());
  }

  void _seekRelative(Duration amount) {
    unawaited(ref.read(playerControllerProvider.notifier).seekRelative(amount));
    _startHideTimer();
  }

  void _toggleLock() {
    setState(() {
      _isLocked = !_isLocked;
      _isVisible = true;
    });
    // Always start the hide timer: when unlocked, controls auto-hide as normal;
    // when locked, only the unlock button is visible and should also auto-hide.
    _startHideTimer();
  }

  // Keyboard shortcut handlers
  void toggleMute() {
    ref.read(playerGestureHandlerProvider.notifier).toggleMute();
  }

  Future<void> changeVolume(double step) async {
    await ref.read(playerGestureHandlerProvider.notifier).changeVolume(step);
  }

  void triggerSeek(bool isLeft) {
    final width = MediaQuery.sizeOf(context).width;
    final settings =
        ref.read(playerSettingsProvider).asData?.value ??
        const PlayerSettings();
    final seconds = settings.seekDuration;

    setState(() {
      _isSeekingLeft = isLeft;
      // Set tap position for animation to appear on correct side
      _tapPosition = Offset(isLeft ? width * 0.25 : width * 0.75, 100);
    });
    _seekAnimController.forward(from: 0.0);

    _seekRelative(Duration(seconds: isLeft ? -seconds : seconds));
  }

  void cycleResize() {
    setState(() {
      _resizeMode = (_resizeMode + 1) % 3;

      final modes = [BoxFit.contain, BoxFit.cover, BoxFit.fill];
      final l10n = AppLocalizations.of(context)!;
      final labels = [l10n.fit, l10n.zoom, l10n.stretch];

      widget.onResize?.call(modes[_resizeMode]);
      ref
          .read(playerGestureHandlerProvider.notifier)
          .showToast(labels[_resizeMode], Icons.aspect_ratio);
    });
  }

  Future<void> _handleDragStart(DragStartDetails details) async {
    if (_isLocked || _panelOpen) return;
    final size = MediaQuery.sizeOf(context);
    await ref
        .read(playerGestureHandlerProvider.notifier)
        .handleDragStart(details, size.width, size.height);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_isLocked || _panelOpen) return;
    ref.read(playerGestureHandlerProvider.notifier).handleDragUpdate(details);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_isLocked || _panelOpen) return;
    ref.read(playerGestureHandlerProvider.notifier).handleDragEnd(details);
  }

  // Horizontal Seek
  Future<void> _handleHorizontalDragStart(DragStartDetails details) async {
    if (_isLocked || _panelOpen) return;
    final size = MediaQuery.sizeOf(context);
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    await ref
        .read(playerGestureHandlerProvider.notifier)
        .handleHorizontalDragStart(
          details,
          _isVisible,
          size.width,
          size.height,
          bottomPadding,
        );
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (_isLocked || _panelOpen) return;
    ref
        .read(playerGestureHandlerProvider.notifier)
        .handleHorizontalDragUpdate(details);
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (_isLocked || _panelOpen) return;
    ref
        .read(playerGestureHandlerProvider.notifier)
        .handleHorizontalDragEnd(details);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return "$hours:${twoDigits(minutes)}:${twoDigits(seconds)}";
    }
    return "$minutes:${twoDigits(seconds)}";
  }

  Widget _buildKickAnimation() {
    final seconds =
        ref.watch(playerSettingsProvider).asData?.value.seekDuration ?? 10;

    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _seekAnimController,
          curve: Curves.easeOutCubic,
        ),
      ),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.94, end: 1.0).animate(
          CurvedAnimation(parent: _seekAnimController, curve: Curves.easeOut),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isSeekingLeft)
              const Icon(
                Icons.keyboard_double_arrow_left_rounded,
                color: Colors.white,
                size: 34,
              ),
            Text(
              "$seconds",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 28,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            if (!_isSeekingLeft)
              const Icon(
                Icons.keyboard_double_arrow_right_rounded,
                color: Colors.white,
                size: 34,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch relevant player state selectively, falling back to props for initial frame
    final controllerTitle = ref.watch(
      playerControllerProvider.select((s) => s.playerTitle),
    );
    final title = controllerTitle.isEmpty
        ? (widget.title ?? "")
        : controllerTitle;

    final controllerSubtitle = ref.watch(
      playerControllerProvider.select((s) => s.streamSubtitle),
    );
    final subtitle = controllerSubtitle ?? widget.subtitle;
    final streams = ref.watch(
      playerControllerProvider.select((s) => s.streams),
    );
    final currentStream = ref.watch(
      playerControllerProvider.select((s) => s.currentStream),
    );
    final externalSubtitles = ref.watch(
      playerControllerProvider.select((s) => s.externalSubtitles),
    );
    final torrentStatus = ref.watch(
      playerControllerProvider.select((s) => s.torrentStatus),
    );
    final showNextEpOverlay = ref.watch(
      playerControllerProvider.select((s) => s.showNextEpisodeOverlay),
    );
    final nextEpTitle = ref.watch(
      playerControllerProvider.select((s) => s.nextEpisodeTitle),
    );
    final nextEpPosterUrl = ref.watch(
      playerControllerProvider.select((s) => s.nextEpisodePosterUrl),
    );
    final nextEpRating = ref.watch(
      playerControllerProvider.select((s) => s.nextEpisodeRating),
    );
    final nextEpNumber = ref.watch(
      playerControllerProvider.select((s) => s.nextEpisodeNumber),
    );
    final nextEpSeason = ref.watch(
      playerControllerProvider.select((s) => s.nextEpisodeSeason),
    );
    final nextEpRuntime = ref.watch(
      playerControllerProvider.select((s) => s.nextEpisodeRuntime),
    );
    final nextEpDescription = ref.watch(
      playerControllerProvider.select((s) => s.nextEpisodeDescription),
    );
    final resumePromptPosition = ref.watch(
      playerControllerProvider.select((s) => s.resumePromptPosition),
    );
    final resumePromptPercentage = ref.watch(
      playerControllerProvider.select((s) => s.resumePromptPercentage),
    );
    final showEpisodeList = ref.watch(
      playerControllerProvider.select((s) => s.showEpisodeList),
    );
    final supportsPlaybackSpeed = ref.watch(
      playerControllerProvider.select((s) => s.supportsPlaybackSpeed),
    );
    final playbackSpeed = ref.watch(
      playerControllerProvider.select((s) => s.playbackSpeed),
    );
    final maxPlaybackSpeed = ref.watch(
      playerControllerProvider.select((s) => s.maxPlaybackSpeed),
    );
    final isSeries = ref.read(playerControllerProvider.notifier).isSeries;
    final skipSegments = ref.watch(
      playerControllerProvider.select((s) => s.skipSegments),
    );
    final uiPhase = ref.watch(
      playerControllerProvider.select((s) => s.uiPhase),
    );
    final sourceAttempts = ref.watch(
      playerControllerProvider.select((s) => s.sourceAttempts),
    );
    // Guard against PiP or small window size
    final size = MediaQuery.sizeOf(context);
    final isSmallWindow = size.width < 300 || size.height < 200;

    if (_isInPip || isSmallWindow) return const SizedBox.shrink();

    if (uiPhase.fullscreenBlocking) {
      return _buildLoadingUI(phase: uiPhase, sourceAttempts: sourceAttempts);
    }

    return MouseRegion(
      // Keep the cursor visible while the side panel owns the screen — the
      // chrome is hidden then, but the panel still needs a pointer.
      cursor: (_isVisible || _panelOpen)
          ? SystemMouseCursors.basic
          : SystemMouseCursors.none,
      onEnter: (_) => _handleThrottledHover(),
      onHover: (_) => _handleThrottledHover(),
      onExit: (_) {
        // Mouse left the player area (e.g. moved to another window).
        // Start the hide timer so controls auto-hide after the timeout.
        if (_isPlaying) _startHideTimer();
      },
      child: GestureDetector(
        onVerticalDragStart: _handleDragStart,
        onVerticalDragUpdate: _handleDragUpdate,
        onVerticalDragEnd: _handleDragEnd,
        onHorizontalDragStart: _handleHorizontalDragStart,
        onHorizontalDragUpdate: _handleHorizontalDragUpdate,
        onHorizontalDragEnd: _handleHorizontalDragEnd,
        onDoubleTapDown: (d) => _tapPosition = d.globalPosition,
        onDoubleTap: _handleDoubleTap,
        onLongPressStart: (_) => _startTouchSpeedHold(),
        onLongPressEnd: (_) => _endTouchSpeedHold(),
        onLongPressCancel: _endTouchSpeedHold,
        child: GestureDetector(
          onTap: () {
            if (_panelOpen) return; // the panel's scrim owns dismiss taps
            final gestureState = ref.read(playerGestureHandlerProvider);
            if (gestureState.showOSD) {
              ref.read(playerGestureHandlerProvider.notifier).dismissOSD();
            }
            if (_isLocked) {
              setState(() => _isVisible = !_isVisible);
              widget.onVisibilityChanged?.call(_isVisible);
              if (_isVisible) _startHideTimer();
            } else {
              _toggleVisibility();
            }
          },
          behavior: HitTestBehavior.translucent,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.transparent,
            child: Stack(
              children: [
                // Locked state UI
                if (_isLocked)
                  _buildLockedUI()
                else
                  _buildUnlockedUI(
                    title: title,
                    subtitle: subtitle,
                    torrentStatus: torrentStatus,
                    streams: streams,
                    currentStream: currentStream,
                    externalSubtitles: externalSubtitles,
                    showEpisodeList: showEpisodeList,
                    isSeries: isSeries,
                    supportsPlaybackSpeed: supportsPlaybackSpeed,
                    playbackSpeed: playbackSpeed,
                    maxPlaybackSpeed: maxPlaybackSpeed,
                  ),

                // Touch play/pause — a screen-centered overlay (not inside the
                // chrome's shorter middle band) so it lines up vertically with
                // the OSD and seek animations. Fades with the chrome.
                if (!_isTv &&
                    (Platform.isAndroid || Platform.isIOS) &&
                    !_isLocked)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: !_isVisible,
                      child: AnimatedOpacity(
                        opacity: _isVisible ? 1.0 : 0.0,
                        duration: _animDuration,
                        child: Center(
                          child: PlayerPlayPauseButton(
                            player: widget.player,
                            videoViewController: widget.videoViewController,
                            isLoading: widget.isLoading,
                            isTv: _isTv,
                            size: 82,
                            backgroundColor: Colors.black.withValues(
                              alpha: 0.32,
                            ),
                            onPressed: _togglePlay,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Persistent buffering indicator. On touch it defers to the
                // centered play/pause spinner while controls are visible; on
                // desktop/TV (play/pause in the corner) it stays centered.
                PlayerBufferingIndicator(
                  isVisible: _isVisible,
                  isTouch: !_isTv && (Platform.isAndroid || Platform.isIOS),
                ),

                // Seek kick animation — a single Align (no nested Stack):
                // ~8% in from the seeking edge, ~45% down from the top.
                AnimatedBuilder(
                  animation: _seekAnimController,
                  builder: (context, _) {
                    if (!_seekAnimController.isAnimating) {
                      return const SizedBox.shrink();
                    }
                    return Align(
                      alignment: Alignment(_isSeekingLeft ? -0.84 : 0.84, 0.0),
                      child: _buildKickAnimation(),
                    );
                  },
                ),

                // OSD and volume overlay — only this subtree rebuilds on handler changes
                PlayerOSDVolumeOverlay(
                  getDuration: () => _duration,
                  formatDuration: _formatDuration,
                ),

                // Torrent stats card — top-right, toggled by the Stats action.
                // Responsive width, cleared below the top bar, and pointer-
                // transparent so it never blocks the player. Non-focusable.
                if (torrentStatus != null && _showTorrentInfo)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: SafeArea(
                        left: false,
                        right: false,
                        child: Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: EdgeInsets.only(
                              // Clear the top bar (back + title).
                              top: _isTv ? 88 : 68,
                              right: _isTv
                                  ? HotstarPlayerStyle.tvEdgeInset
                                  : (MediaQuery.viewPaddingOf(context).right >
                                            HotstarPlayerStyle.edgeInset
                                        ? MediaQuery.viewPaddingOf(
                                            context,
                                          ).right
                                        : HotstarPlayerStyle.edgeInset),
                              left: 12,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: (size.width * 0.36).clamp(
                                  240.0,
                                  360.0,
                                ),
                              ),
                              child: TorrentInfoWidget(status: torrentStatus),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Resume Prompt Button
                if (!widget.isLoading &&
                    _duration != Duration.zero &&
                    !_isLocked &&
                    (resumePromptPosition != null ||
                        resumePromptPercentage != null))
                  ResumePromptOverlay(
                    focusNode: _resumeFocusNode,
                    positionMs: resumePromptPosition,
                    percentage: resumePromptPercentage,
                    onResume: () => ref
                        .read(playerControllerProvider.notifier)
                        .confirmResume(),
                    onStartOver: () => ref
                        .read(playerControllerProvider.notifier)
                        .dismissResumePrompt(),
                    isTv: _isTv,
                  ),

                // Next Episode Card (Persistent when triggered)
                if (resumePromptPosition == null &&
                    resumePromptPercentage == null &&
                    showNextEpOverlay &&
                    nextEpTitle != null)
                  NextEpisodeOverlay(
                    focusNode: _nextEpFocusNode,
                    nextEpisodeTitle: nextEpTitle,
                    nextEpisodePosterUrl: nextEpPosterUrl,
                    nextEpisodeRating: nextEpRating,
                    nextEpisodeNumber: nextEpNumber,
                    nextEpisodeSeason: nextEpSeason,
                    nextEpisodeRuntime: nextEpRuntime,
                    nextEpisodeDescription: nextEpDescription,
                    onPlayNext: () => ref
                        .read(playerControllerProvider.notifier)
                        .playNextEpisode(),
                    onDismiss: () => ref
                        .read(playerControllerProvider.notifier)
                        .dismissNextEpisodeOverlay(),
                    isTv: _isTv,
                    isPlaying: _isPlaying,
                  ),

                // Skip Segment Overlay (Skip Intro / Skip Recap / Skip Outro)
                // Suppressed when Resume or Next Episode prompts are active
                // to avoid UI collisions and decision fatigue.
                if (resumePromptPosition == null &&
                    resumePromptPercentage == null &&
                    !showNextEpOverlay &&
                    skipSegments.isNotEmpty)
                  SkipSegmentOverlay(
                    focusNode: _skipFocusNode,
                    onActiveSegmentChanged: (active) {
                      if (mounted) {
                        setState(() {
                          _isSkipActive = active;
                        });
                      }
                    },
                    player: widget.player,
                    videoViewController: widget.videoViewController,
                    skipSegments: skipSegments,
                    isTv: _isTv,
                    controlsVisible: _isVisible,
                    onFocusReturned: () {
                      if (_isVisible) {
                        _playFocusNode.requestFocus();
                      } else {
                        _returnFocusToRoot();
                      }
                    },
                  ),

                // Episodes side drawer (series only) — same shell as the
                // sources panel, right-anchored. Topmost so it sits above the
                // chrome. Pure Row layout inside (no nested Stack).
                if (isSeries &&
                    ref
                            .read(playerControllerProvider.notifier)
                            .multimediaItem !=
                        null)
                  Positioned.fill(
                    child: PlayerSidePanel(
                      isVisible: showEpisodeList && !_isLocked,
                      isTv: _isTv,
                      onDismiss: closeEpisodesPanel,
                      child: PlayerEpisodesPanel(
                        item: ref
                            .read(playerControllerProvider.notifier)
                            .multimediaItem!,
                        isTv: _isTv,
                        onClose: closeEpisodesPanel,
                      ),
                    ),
                  ),

                // Torrent content (file picker) drawer — same shell.
                if (torrentStatus != null)
                  Positioned.fill(
                    child: PlayerSidePanel(
                      isVisible: ref.watch(
                        playerControllerProvider.select(
                          (s) => s.showContentPanel,
                        ),
                      ),
                      isTv: _isTv,
                      onDismiss: closeContentPanel,
                      child: PlayerContentPanel(
                        isTv: _isTv,
                        onFileSelected: (idx) => ref
                            .read(playerControllerProvider.notifier)
                            .onTorrentFileSelected(idx),
                        onClose: closeContentPanel,
                      ),
                    ),
                  ),

                // Netflix-style metadata scrim (TV / desktop only).
                // Sits over the paused video as a left-anchored gradient panel
                // with logo/title, meta line, and description. Appears after
                // 8 s of pause; hides on resume or dialog open.
                PlayerMetadataScrim(
                  key: _metadataScrimKey,
                  item: ref
                      .read(playerControllerProvider.notifier)
                      .multimediaItem,
                  episode: ref
                      .read(playerControllerProvider.notifier)
                      .currentEpisode,
                  isSeries: ref
                      .read(playerControllerProvider.notifier)
                      .isSeries,
                  isPaused: !_isPlaying,
                  isDialogOpen: _panelOpen,
                  controlsVisible: _isVisible,
                  isTv: _isTv,
                  onHidePlayerUI: hideControls,
                ),

                // Sources / Audio / Subtitles drawer — topmost so it sits above
                // the chrome. Pure Row layout inside (no nested Stack).
                Positioned.fill(
                  child: PlayerSidePanel(
                    isVisible: ref.watch(
                      playerControllerProvider.select(
                        (s) => s.showSourcesPanel,
                      ),
                    ),
                    isTv: _isTv,
                    onDismiss: closeSourcesPanel,
                    child: PlayerSourcesPanel(
                      player: widget.player,
                      videoViewController: widget.videoViewController,
                      isTv: _isTv,
                      onClose: closeSourcesPanel,
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool highlight = false,
    FocusNode? focusNode,
  }) {
    return PlayerActionButton(
      icon: icon,
      label: label,
      onTap: onTap,
      highlight: highlight,
      isTv: _isTv,
      focusNode: focusNode,
    );
  }

  Widget _buildLockedUI() {
    return ExcludeFocus(
      excluding: !_isVisible,
      child: IgnorePointer(
        ignoring: !_isVisible,
        child: AnimatedOpacity(
          opacity: _isVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 180),
          child: Center(
            child: _buildActionButton(
              icon: Icons.lock,
              label: AppLocalizations.of(context)!.unlock,
              onTap: _toggleLock,
              highlight: false,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnlockedUI({
    required String title,
    String? subtitle,
    TorrentStatus? torrentStatus,
    List<StreamResult>? streams,
    StreamResult? currentStream,
    List<SubtitleFile>? externalSubtitles,
    required bool showEpisodeList,
    required bool isSeries,
    required bool supportsPlaybackSpeed,
    required double playbackSpeed,
    required double maxPlaybackSpeed,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final isTouch = !_isTv && (Platform.isAndroid || Platform.isIOS);
    final isDesktop =
        Platform.isMacOS || Platform.isWindows || Platform.isLinux;

    // Playback placement: touch keeps the big thumb-reach triplet centered;
    // TV and desktop fold compact playback into the start of the controls row
    // (where the focus anchor lives).
    final playPause = PlayerPlayPauseButton(
      player: widget.player,
      videoViewController: widget.videoViewController,
      isLoading: widget.isLoading,
      isTv: _isTv,
      size: 52,
      focusNode: _playFocusNode,
      onPressed: _togglePlay,
      // Corner button (desktop/TV) — let the centered indicator show buffering.
      showBufferingSpinner: false,
    );

    // Left cluster: play/pause (non-touch), lock (touch only), next episode
    final leading = <Widget>[
      if (!isTouch) playPause,
      if (isTouch)
        PlayerIconButton(
          icon: _isLocked ? Icons.lock : Icons.lock_open,
          tooltip: _isLocked ? l10n.unlock : l10n.lock,
          onPressed: _toggleLock,
          isTv: _isTv,
          highlight: _isLocked,
        ),
      if (isSeries)
        PlayerIconButton(
          icon: Icons.skip_next_rounded,
          tooltip: l10n.next,
          onPressed: () =>
              ref.read(playerControllerProvider.notifier).playNextEpisode(),
          isTv: _isTv,
        ),
    ];

    final playerSettings =
        ref.watch(playerSettingsProvider).asData?.value ??
        const PlayerSettings();

    // Right-side icon-only buttons (same style as resize/fullscreen). Sources,
    // Audio and Subtitles all open the same side panel, each landing on its own
    // tab; the panel applies every choice instantly.
    final actions = <Widget>[
      PlayerIconButton(
        icon: Icons.source,
        tooltip: l10n.sources,
        onPressed: () => openSourcesPanel(0),
        isTv: _isTv,
      ),
      PlayerIconButton(
        icon: Icons.audiotrack_rounded,
        tooltip: l10n.audioTracks,
        onPressed: () => openSourcesPanel(1),
        isTv: _isTv,
      ),
      PlayerIconButton(
        icon: Icons.subtitles_rounded,
        tooltip: l10n.subtitles,
        onPressed: () => openSourcesPanel(2),
        isTv: _isTv,
      ),
      if (supportsPlaybackSpeed && playerSettings.showPlaybackSpeed)
        PlayerIconButton(
          icon: Icons.speed,
          tooltip:
              "${playbackSpeed.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '')}x",
          onPressed: () => PlayerBottomSheets.showSpeedSelection(
            context: context,
            currentSpeed: playbackSpeed,
            maxSpeed: maxPlaybackSpeed,
            onSpeedSelected: (s) => ref
                .read(playerControllerProvider.notifier)
                .setPlaybackSpeed(s, persist: true),
          ),
          isTv: _isTv,
        ),
      if (torrentStatus != null)
        PlayerIconButton(
          icon: Icons.folder,
          tooltip: l10n.content,
          onPressed: openContentPanel,
          isTv: _isTv,
        ),
      if (torrentStatus != null)
        PlayerIconButton(
          icon: Icons.info_outline,
          tooltip: l10n.stats,
          onPressed: () => setState(() => _showTorrentInfo = !_showTorrentInfo),
          isTv: _isTv,
          highlight: _showTorrentInfo,
        ),
      if (isTouch &&
          (Platform.isAndroid || (Platform.isIOS && !_isIpad)) &&
          playerSettings.showRotate)
        PlayerIconButton(
          icon: Icons.screen_rotation,
          tooltip: l10n.rotate,
          onPressed: _toggleOrientation,
          isTv: _isTv,
        ),
      if (isSeries && playerSettings.showEpisodes)
        PlayerIconButton(
          icon: Icons.playlist_play_rounded,
          tooltip: l10n.episodes,
          onPressed: openEpisodesPanel,
          isTv: _isTv,
        ),
      if (playerSettings.showResize)
        PlayerIconButton(
          icon: Icons.aspect_ratio_rounded,
          tooltip: l10n.resize,
          onPressed: cycleResize,
          isTv: _isTv,
        ),
      if (Platform.isAndroid && !_isTv && playerSettings.showPip)
        PlayerIconButton(
          icon: Icons.picture_in_picture_alt_rounded,
          tooltip: l10n.pip,
          onPressed: _enterPip,
          isTv: _isTv,
        ),
      if (isDesktop)
        PlayerIconButton(
          icon: _isFullscreen
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
          tooltip: _isFullscreen ? l10n.windowed : l10n.fullscreen,
          onPressed: toggleFullscreen,
          isTv: _isTv,
        ),
    ];

    // One overlay layer: a Column with top bar / center / bottom bar. No
    // Positioned, no magic offsets — each zone sizes to content and paints its
    // own scrim. ExcludeFocus + IgnorePointer gate interaction while hidden;
    // ReadingOrderTraversalPolicy gives geometric D-pad navigation so focus
    // can always reach a neighbouring control. The chrome is also fully gated
    // off while the sources side panel owns the screen.
    final chromeVisible = _isVisible && !_panelOpen;
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: ExcludeFocus(
        excluding: !chromeVisible,
        child: IgnorePointer(
          ignoring: !chromeVisible,
          child: RepaintBoundary(
            child: AnimatedOpacity(
              opacity: chromeVisible ? 1.0 : 0.0,
              duration: _animDuration,
              child: Column(
              children: [
                _absorbGestures(
                  PlayerTopBar(
                    title: title,
                    subtitle: subtitle,
                    onBack: widget.onBackPointer ?? () => context.pop(),
                    isTv: _isTv,
                    backFocusNode: _backFocusNode,
                  ),
                ),
                // Center zone stays empty: the touch play/pause is rendered as
                // a screen-centered overlay in the root Stack (build()) so it
                // lines up with the OSD / seek animations, instead of being
                // centered within this shorter middle band.
                const Expanded(child: SizedBox.expand()),
                _absorbGestures(
                  PlayerBottomBar(
                    isTv: _isTv,
                    isTouch: isTouch,
                    progressBar: PlayerProgressBar(
                      player: widget.player,
                      videoViewController: widget.videoViewController,
                      onSeekStart: _cancelHideTimer,
                      isTv: _isTv,
                      focusNode: _scrubFocusNode,
                      onArrowUp: () {
                        final resumePromptPosition = ref.read(
                          playerControllerProvider.select(
                            (s) => s.resumePromptPosition,
                          ),
                        );
                        final resumePromptPercentage = ref.read(
                          playerControllerProvider.select(
                            (s) => s.resumePromptPercentage,
                          ),
                        );
                        final showNextEpOverlay = ref.read(
                          playerControllerProvider.select(
                            (s) => s.showNextEpisodeOverlay,
                          ),
                        );
                        final nextEpTitle = ref.read(
                          playerControllerProvider.select(
                            (s) => s.nextEpisodeTitle,
                          ),
                        );

                        if (resumePromptPosition != null ||
                            resumePromptPercentage != null) {
                          _resumeFocusNode.requestFocus();
                        } else if (showNextEpOverlay && nextEpTitle != null) {
                          _nextEpFocusNode.requestFocus();
                        } else if (_isSkipActive) {
                          _skipFocusNode.requestFocus();
                        } else {
                          _backFocusNode.requestFocus();
                        }
                      },
                    ),
                    leading: leading,
                    actions: actions,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  /// Absorbs taps and drags over the chrome bars so interacting with the
  /// top/bottom bars doesn't bubble up to the screen-wide gesture handler
  /// (which would toggle visibility or fire brightness/volume swipes). Deeper
  /// widgets (slider, buttons) still win the gesture arena.
  Widget _absorbGestures(Widget child) {
    return GestureDetector(
      onTap: () {},
      onDoubleTap: () {},
      onVerticalDragStart: (_) {},
      onHorizontalDragStart: (_) {},
      child: child,
    );
  }

  Widget _buildLoadingUI({
    required PlaybackUiPhase phase,
    required List<SourceAttemptEntry> sourceAttempts,
  }) {
    final canSkip =
        phase.kind != PlaybackUiPhaseKind.bootstrapping &&
        phase.kind != PlaybackUiPhaseKind.fetchingSources &&
        phase.kind != PlaybackUiPhaseKind.error;

    return PlayerLoadingOverlay(
      onDoubleTap: _handleDoubleTap,
      onBack: widget.onBackPointer ?? () => context.pop(),
      phase: phase,
      sourceAttempts: sourceAttempts,
      backdropUrl: widget.backdropUrl,
      logoUrl: widget.logoUrl,
      isTv: _isTv,
      onSkip: canSkip
          ? () =>
                ref.read(playerControllerProvider.notifier).skipLoadingOverlay()
          : null,
      onGoLive: () => ref.read(playerControllerProvider.notifier).goLive(),
    );
  }
}
