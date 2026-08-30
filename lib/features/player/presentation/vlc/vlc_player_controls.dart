import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vlc_player/vlc_player.dart';

import '../../../../core/providers/device_info_provider.dart';
import '../../../../core/models/torrent_status.dart';
import '../../../skip/data/skip_service.dart';
import '../../domain/skip_segments.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../widgets/player_control_components.dart';
import '../widgets/player_stream_widgets.dart' show PlayerBufferingIndicator;
import 'package:screen_brightness/screen_brightness.dart';

import 'player_rail.dart';
import 'player_value_selector.dart';
import 'vlc_progress_bar.dart';
import '../components/torrent_info_widget.dart';
import 'vlc_track_sheet.dart';

/// Chrome for the VLC engine — Phase 5b of the migration notes.
///
/// The design is not reimplemented here. [PlayerTopBar], [PlayerBottomBar],
/// [PlayerIconButton] and the shared scrubber are the same widgets the
/// media_kit overlay uses, so "no visual diff" holds by construction rather
/// than by inspection, and any future change to the design lands on both paths
/// at once.
///
/// What *is* rebuilt is the machinery, which is where the old overlay
/// (skystream_player_controls.dart, 1684 lines) went wrong:
///
///   * Its auto-hide timer is restarted from **16** separate call sites, so
///     chrome vanishes mid-interaction whenever a path forgets. Here one
///     Listener/Focus wrapper feeds every pointer and key event to a single
///     sink, and exactly one method restarts the timer.
///   * It hand-manages **6** FocusNodes and hand-routes D-pad Up out of the
///     scrubber. Here there are none: ordinary focusable widgets in reading
///     order, inside the same FocusTraversalGroup the old one already uses, let
///     native traversal do it.
///   * It reads playerControllerProvider **72** times, only 30 of them
///     filtered, so an unrelated state change rebuilds the whole overlay. Here
///     the only high-frequency value — position — is consumed by a
///     ValueListenableBuilder inside [VlcProgressBar], so a tick rebuilds the
///     scrubber and nothing else.
///
/// Buttons whose backend does not exist on this path yet are **absent, not
/// disabled**: PiP, cast, download, lock, rotate, fullscreen, torrent stats and
/// skip-segment. A missing feature should be obviously missing.
class VlcPlayerControls extends ConsumerStatefulWidget {
  const VlcPlayerControls({
    required this.controller,
    required this.title,
    this.subtitle,
    this.onBack,
    this.onNextEpisode,
    this.onOpenSources,
    this.onEnterPip,
    this.onToggleFullscreen,
    this.isFullscreen = false,
    this.isLive = false,
    this.torrentStatus,
    this.skipSegments = const <SkipSegment>[],
    super.key,
  });

  final VlcPlayerController controller;
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;

  /// Non-null only when a next episode exists.
  final VoidCallback? onNextEpisode;

  /// Non-null only when more than one source resolved.
  final VoidCallback? onOpenSources;

  /// Non-null only where picture-in-picture is actually available.
  final VoidCallback? onEnterPip;

  /// Desktop only; null elsewhere, where the window is already full screen.
  final VoidCallback? onToggleFullscreen;
  final bool isFullscreen;

  /// Whether this is a live stream, decided by the app rather than the engine.
  final bool isLive;

  /// Non-null only while a torrent is playing and being polled.
  final TorrentStatus? torrentStatus;

  /// Intro/outro bands, usually empty - both sources are opt-in.
  final List<SkipSegment> skipSegments;

  @override
  ConsumerState<VlcPlayerControls> createState() => _VlcPlayerControlsState();
}

class _VlcPlayerControlsState extends ConsumerState<VlcPlayerControls> {
  /// Matches the old overlay's timeout (skystream_player_controls.dart:689).
  static const Duration _hideAfter = Duration(seconds: 3);
  static const Duration _fade = Duration(milliseconds: 200);

  /// Matches the old player's double-tap step.
  static const Duration _seekStep = Duration(seconds: 10);

  bool _visible = true;
  Timer? _hideTimer;

  /// A brief centred message - the resize mode, and later seek and speed.
  ///
  /// Lives here rather than in a provider because it is transient screen state
  /// with exactly one owner. The old player put its equivalent in a Riverpod
  /// notifier with its own timers, which is how it ended up with several
  /// things able to hide the chrome.
  String? _toast;
  Timer? _toastTimer;

  /// Torrent statistics are opt-in: useful when a stream is struggling,
  /// clutter the rest of the time.
  bool _showTorrentInfo = false;

  /// libVLC amplifies natively up to 200%, so boost costs nothing extra.
  static const int _maxVolume = 200;

  /// Which rail a vertical drag is driving, and the value it started from.
  /// Null when no drag is in progress.
  bool? _dragIsVolume;
  double _dragStart = 0;

  /// Mirrored so the rail can render without awaiting the platform on each
  /// frame. Brightness is an OS control; libVLC has no equivalent.
  double _brightness = 0.5;
  Timer? _railTimer;
  Widget? _rail;

  /// Speed to restore when a long-press boost ends. Null when not boosting.
  ///
  /// Read back from the engine rather than assumed to be 1.0, so a viewer who
  /// had already chosen 1.5x is returned to 1.5x and not silently reset.
  double? _speedBeforeBoost;

  @override
  void initState() {
    super.initState();
    // Armed, but the timer refuses to hide until playback actually starts, so
    // the bars stay up through resolution and buffering.
    _restartHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _toastTimer?.cancel();
    _railTimer?.cancel();
    super.dispose();
  }

  /// Keeps visible chrome alive. Every pointer and key event routes here, and
  /// nothing else touches the timer - that is why chrome cannot vanish
  /// mid-interaction the way the old overlay's fifteen call sites allowed.
  ///
  /// Deliberately does **not** reveal hidden chrome: a tap that dismisses the
  /// bars also produces a pointer-down, and if that re-showed them the bars
  /// could never be dismissed at all. Revealing is [_toggleChrome]'s job.
  void _poke() {
    if (!_visible) return;
    _restartHideTimer();
  }

  /// Shows or hides the chrome. The only thing a bare tap on the video does.
  void _toggleChrome() {
    setState(() => _visible = !_visible);
    if (_visible) _restartHideTimer();
  }

  /// Called by controls that act *and* should keep the bars up.
  void _onInteraction() {
    if (!_visible) setState(() => _visible = true);
    _restartHideTimer();
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideAfter, () {
      if (!mounted) return;
      // Paused means the viewer is looking at something - a still frame, the
      // seek bar, the title. Hiding the chrome out from under them is the wrong
      // call, so wait and re-check rather than hiding on a schedule.
      if (!widget.controller.value.isPlaying) {
        _restartHideTimer();
        return;
      }
      setState(() => _visible = false);
    });
  }

  /// Held open while a menu owns the screen, then released.
  Future<void> _withChromeHeld(Future<void> Function() action) async {
    _hideTimer?.cancel();
    try {
      await action();
    } finally {
      if (mounted) _onInteraction();
    }
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _toastTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  /// Holds playback at double speed while the finger is down.
  ///
  /// Live streams are excluded: there is nothing ahead to race towards, and
  /// libVLC will simply drift off the live edge.
  void _startSpeedBoost() {
    if (widget.isLive || _speedBeforeBoost != null) return;
    final value = widget.controller.value;
    if (!value.isPlaying) return;
    _speedBeforeBoost = value.playbackSpeed;
    widget.controller.setPlaybackSpeed(2.0);
    _showToast('2x');
  }

  void _endSpeedBoost() {
    final previous = _speedBeforeBoost;
    if (previous == null) return;
    _speedBeforeBoost = null;
    widget.controller.setPlaybackSpeed(previous);
    _toastTimer?.cancel();
    if (mounted) setState(() => _toast = null);
  }

  /// Seeks by a fixed step, forward or back depending on which half was tapped.
  void _doubleTapSeek(double dx) {
    final width = context.size?.width ?? 0;
    if (width <= 0) return;
    _seekBy(dx >= width / 2 ? _seekStep : -_seekStep);
    _poke();
  }

  /// Trims a speed to the shortest exact label: 1, 1.5, 1.25.
  static String _formatSpeed(double speed) {
    final text = speed.toStringAsFixed(2);
    return text.endsWith('00')
        ? text.substring(0, text.length - 3)
        : (text.endsWith('0') ? text.substring(0, text.length - 1) : text);
  }

  /// Playback speed, applied instantly and not persisted.
  ///
  /// Deliberately session-scoped: a speed chosen for one talky episode should
  /// not silently apply to the next film, which is how the old player's
  /// persisted default surprised people.
  Future<void> _pickSpeed() async {
    const speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    final current = widget.controller.value.playbackSpeed;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final speed in speeds)
              ListTile(
                dense: true,
                selected: (speed - current).abs() < 0.01,
                selectedColor: Colors.white,
                leading: Icon(
                  (speed - current).abs() < 0.01
                      ? Icons.check_rounded
                      : Icons.speed,
                  color: Colors.white70,
                ),
                title: Text(
                  speed == 1.0 ? 'Normal' : '${_formatSpeed(speed)}x',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  widget.controller.setPlaybackSpeed(speed);
                  _showToast('${_formatSpeed(speed)}x');
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Volume to restore when unmuting.
  int? _volumeBeforeMute;

  void _nudgeVolume(int delta) =>
      _setVolume(widget.controller.value.volume + delta);

  /// Applies a volume and shows the same rail the drag gesture uses, so the
  /// two routes give identical feedback.
  void _setVolume(int volume) {
    final clamped = volume.clamp(0, _maxVolume);
    widget.controller.setVolume(clamped);
    _showRail(
      PlayerRail(
        icon: clamped == 0
            ? Icons.volume_off_rounded
            : (clamped > 100
                  ? Icons.volume_up_rounded
                  : Icons.volume_down_rounded),
        value: clamped / _maxVolume,
        label: '$clamped%',
        onLeft: false,
      ),
    );
    _railTimer?.cancel();
    _railTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _rail = null);
    });
  }

  /// The transient centred message. Always in the tree, empty when idle, so the
  /// Stack's child list never changes shape.
  Widget _toastOverlay() {
    final toast = _toast;
    if (toast == null) return const SizedBox.shrink();
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Text(
            toast,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  /// Starts a brightness (left half) or volume (right half) drag.
  ///
  /// The side is decided once, at the start, so a wandering finger cannot swap
  /// rails mid-gesture.
  Future<void> _railDragStart(DragStartDetails d) async {
    if (widget.onToggleFullscreen != null) return; // desktop: no touch rails
    final width = context.size?.width ?? 0;
    if (width <= 0) return;
    final isVolume = d.localPosition.dx >= width / 2;
    _dragIsVolume = isVolume;
    if (isVolume) {
      _dragStart = widget.controller.value.volume.toDouble();
    } else {
      try {
        _brightness = await ScreenBrightness().application;
      } catch (_) {
        // Unsupported on this platform; carry on from the mirrored value.
      }
      _dragStart = _brightness;
    }
  }

  /// A full screen height of travel covers the whole range, which is the
  /// proportion the old player used and feels neither twitchy nor sluggish.
  void _railDragUpdate(DragUpdateDetails d) {
    final isVolume = _dragIsVolume;
    if (isVolume == null) return;
    final height = context.size?.height ?? 0;
    if (height <= 0) return;

    final travel = -d.primaryDelta! / height;
    if (isVolume) {
      _dragStart = (_dragStart + travel * _maxVolume).clamp(0.0, _maxVolume * 1.0);
      final volume = _dragStart.round();
      widget.controller.setVolume(volume);
      _showRail(
        PlayerRail(
          icon: volume == 0
              ? Icons.volume_off_rounded
              : (volume > 100
                    ? Icons.volume_up_rounded
                    : Icons.volume_down_rounded),
          value: volume / _maxVolume,
          label: '$volume%',
          onLeft: false,
        ),
      );
    } else {
      _dragStart = (_dragStart + travel).clamp(0.0, 1.0);
      _brightness = _dragStart;
      unawaited(
        ScreenBrightness()
            .setApplicationScreenBrightness(_brightness)
            .catchError((_) {}),
      );
      _showRail(
        PlayerRail(
          icon: Icons.brightness_6_rounded,
          value: _brightness,
          label: '${(_brightness * 100).round()}%',
        ),
      );
    }
  }

  void _railDragEnd() {
    _dragIsVolume = null;
    _railTimer?.cancel();
    _railTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _rail = null);
    });
  }

  void _showRail(Widget rail) {
    _railTimer?.cancel();
    setState(() => _rail = rail);
  }

  /// Keyboard and remote shortcuts.
  ///
  /// Returns ignored for anything it does not claim, so directional keys keep
  /// reaching the focus system and native traversal moves between controls
  /// exactly as before. Only keys with no traversal meaning are handled here.
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Any key keeps the chrome alive, and summons it when hidden - on a remote
    // there is no tap to reveal it with.
    if (!_visible) {
      setState(() => _visible = true);
      _restartHideTimer();
    } else {
      _poke();
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.keyK) {
      widget.controller.value.isPlaying
          ? widget.controller.pause()
          : widget.controller.play();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPlay) {
      widget.controller.play();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPause) {
      widget.controller.pause();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyJ) {
      _seekBy(-_seekStep);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyL) {
      _seekBy(_seekStep);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF && widget.onToggleFullscreen != null) {
      widget.onToggleFullscreen!.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape &&
        widget.isFullscreen &&
        widget.onToggleFullscreen != null) {
      widget.onToggleFullscreen!.call();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.audioVolumeUp ||
        key == LogicalKeyboardKey.audioVolumeDown) {
      final up =
          key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.audioVolumeUp;
      // Up/Down are traversal keys when a control has focus, so only claim them
      // for volume when nothing is focused.
      final focusedNow = FocusManager.instance.primaryFocus;
      if (focusedNow == null || focusedNow == node) {
        _nudgeVolume(up ? 10 : -10);
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.keyM) {
      final current = widget.controller.value.volume;
      _setVolume(current == 0 ? (_volumeBeforeMute ?? 100) : 0);
      if (current != 0) _volumeBeforeMute = current;
      return KeyEventResult.handled;
    }

    // Left/Right seek only when no control holds focus. Otherwise they belong
    // to D-pad traversal along the button row, which must keep working.
    final focused = FocusManager.instance.primaryFocus;
    if (focused == null || focused == node) {
      if (key == LogicalKeyboardKey.arrowLeft) {
        _seekBy(-_seekStep);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        _seekBy(_seekStep);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  /// Seeks relative to the current position, clamped at both ends because
  /// seekTo rejects a negative position and overshooting the end would trip the
  /// end-of-media handler.
  void _seekBy(Duration delta) {
    final value = widget.controller.value;
    if (widget.isLive || !value.isSeekable) return;
    var target = value.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    final duration = value.duration;
    if (duration > Duration.zero && target > duration) target = duration;
    widget.controller.seekTo(target);
    _showToast(
      delta.isNegative ? '-${(-delta).inSeconds}s' : '+${delta.inSeconds}s',
    );
  }

  /// Stops taps and drags on the bars from reaching the screen-wide gesture
  /// layer beneath them.
  ///
  /// Without this the full-screen double-tap and long-press recognisers stay in
  /// the gesture arena while a button is pressed, so the button's own tap is
  /// delayed behind the double-tap timeout and reads as unresponsive. Deeper
  /// widgets - buttons, the scrubber - still win normally.
  Widget _absorbGestures(Widget child) => GestureDetector(
    onTap: () {},
    onDoubleTap: () {},
    onLongPress: () {},
    onVerticalDragStart: (_) {},
    onHorizontalDragStart: (_) {},
    child: child,
  );

  List<Widget> _leading(AppLocalizations l10n, {required bool isTv}) {
    return <Widget>[
      PlayerValueSelector<bool>(
        controller: widget.controller,
        selector: (v) => v.isPlaying,
        builder: (context, playing) {
          return PlayerIconButton(
            icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            tooltip: playing ? l10n.pause : l10n.play,
            isTv: isTv,
            iconSize: 40,
            onPressed: () {
              _onInteraction();
              playing ? widget.controller.pause() : widget.controller.play();
            },
          );
        },
      ),
      if (widget.onNextEpisode != null)
        PlayerIconButton(
          icon: Icons.skip_next_rounded,
          tooltip: l10n.next,
          isTv: isTv,
          onPressed: () {
            _onInteraction();
            widget.onNextEpisode!.call();
          },
        ),
    ];
  }

  List<Widget> _actions(AppLocalizations l10n, {required bool isTv}) {
    return <Widget>[
      if (widget.onOpenSources != null)
        PlayerIconButton(
          icon: Icons.source,
          tooltip: l10n.sources,
          isTv: isTv,
          onPressed: () {
            _onInteraction();
            widget.onOpenSources!.call();
          },
        ),
      PlayerIconButton(
        icon: Icons.subtitles_rounded,
        tooltip: l10n.subtitles,
        isTv: isTv,
        onPressed: () => unawaited(
          _withChromeHeld(
            () => VlcTrackSheet.show(context, widget.controller),
          ),
        ),
      ),
      // Speed is meaningless on a live edge, so the button is absent there
      // rather than present and inert.
      if (!widget.isLive)
        PlayerValueSelector<double>(
          controller: widget.controller,
          selector: (v) => v.playbackSpeed,
          builder: (context, speed) => PlayerIconButton(
            icon: Icons.speed,
            tooltip: '${_formatSpeed(speed)}x',
            isTv: isTv,
            highlight: speed != 1.0,
            onPressed: () => unawaited(_withChromeHeld(_pickSpeed)),
          ),
        ),
      if (widget.torrentStatus != null)
        PlayerIconButton(
          icon: Icons.info_outline,
          tooltip: 'Torrent stats',
          isTv: isTv,
          highlight: _showTorrentInfo,
          onPressed: () {
            _onInteraction();
            setState(() => _showTorrentInfo = !_showTorrentInfo);
          },
        ),
      if (widget.onEnterPip != null)
        PlayerIconButton(
          icon: Icons.picture_in_picture_alt_rounded,
          tooltip: l10n.pip,
          isTv: isTv,
          onPressed: widget.onEnterPip,
        ),
      if (widget.onToggleFullscreen != null)
        PlayerIconButton(
          icon: widget.isFullscreen
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
          tooltip: widget.isFullscreen ? l10n.windowed : l10n.fullscreen,
          isTv: isTv,
          onPressed: () {
            _onInteraction();
            widget.onToggleFullscreen!.call();
          },
        ),
      PlayerIconButton(
        icon: Icons.aspect_ratio_rounded,
        tooltip: l10n.resize,
        isTv: isTv,
        onPressed: () {
          _onInteraction();
          _cycleFit();
        },
      ),
    ];
  }

  /// The fork made fit changeable at runtime (FORK.md section 3), so this is a
  /// straight engine call with no Dart-side state to keep in sync.
  void _cycleFit() {
    const order = <VlcVideoFit>[
      VlcVideoFit.contain,
      VlcVideoFit.cover,
      VlcVideoFit.fill,
    ];
    final next = order[(order.indexOf(_fit) + 1) % order.length];
    setState(() => _fit = next);
    widget.controller.setFit(next);
    _showToast(_fitLabel(next));
  }

  static String _fitLabel(VlcVideoFit fit) => switch (fit) {
    VlcVideoFit.contain => 'Fit',
    VlcVideoFit.cover => 'Zoom',
    VlcVideoFit.fill => 'Stretch',
    VlcVideoFit.none => 'Original',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isTv = ref.watch(deviceProfileProvider).asData?.value.isTv ?? false;
    final isTouch = !isTv && (Platform.isAndroid || Platform.isIOS);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _poke(),
      child: Focus(
        onKeyEvent: _handleKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Bare tap on the video toggles the chrome. Sits below the bars,
            // which absorb their own gestures so buttons are never delayed
            // behind the double-tap timeout.
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _toggleChrome,
              // Desktop convention; on touch the same gesture seeks instead,
              // which is why the two are mutually exclusive.
              onDoubleTap: widget.onToggleFullscreen,
              onDoubleTapDown: widget.onToggleFullscreen == null
                  ? (d) => _doubleTapSeek(d.localPosition.dx)
                  : null,
              onVerticalDragStart: (d) => unawaited(_railDragStart(d)),
              onVerticalDragUpdate: _railDragUpdate,
              onVerticalDragEnd: (_) => _railDragEnd(),
              onVerticalDragCancel: _railDragEnd,
              onLongPressStart: (_) => _startSpeedBoost(),
              onLongPressEnd: (_) => _endSpeedBoost(),
              onLongPressCancel: _endSpeedBoost,
            ),
            // Buffering reads through even when the chrome is hidden.
            RepaintBoundary(
              child: PlayerValueSelector<bool>(
                controller: widget.controller,
                selector: (v) => v.state == VlcPlaybackState.buffering,
                builder: (context, buffering) => buffering
                    ? const PlayerBufferingIndicator()
                    : const SizedBox.shrink(),
              ),
            ),
            Positioned(
              top: MediaQuery.viewPaddingOf(context).top + 72,
              right: isTv ? 48 : 16,
              child: IgnorePointer(
                child: _showTorrentInfo && widget.torrentStatus != null
                    ? TorrentInfoWidget(status: widget.torrentStatus)
                    : const SizedBox.shrink(),
              ),
            ),
            // Toast reads through hidden chrome: resize and seek are reachable
            // by remote while the bars are down, and a silent change confuses.
            IgnorePointer(child: _toastOverlay()),
            _chrome(context, l10n, isTv: isTv, isTouch: isTouch),
            // Outside the chrome on purpose: an intro can start while the bars
            // are hidden, and putting the one time-limited control behind a tap
            // would defeat it.
            Align(
              alignment: Alignment.bottomRight,
              child: widget.skipSegments.isEmpty
                  ? const SizedBox.shrink()
                  : _skipButton(isTv: isTv),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chrome(
    BuildContext context,
    AppLocalizations l10n, {
    required bool isTv,
    required bool isTouch,
  }) {
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: ExcludeFocus(
        excluding: !_visible,
        child: IgnorePointer(
          ignoring: !_visible,
          child: RepaintBoundary(
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: _fade,
              child: Column(
                children: [
                  _absorbGestures(
                    PlayerTopBar(
                      title: widget.title,
                      subtitle: widget.subtitle,
                      onBack: widget.onBack,
                      isTv: isTv,
                    ),
                  ),
                  const Expanded(child: SizedBox.expand()),
                  _absorbGestures(
                    PlayerBottomBar(
                      isTv: isTv,
                      isTouch: isTouch,
                      // Its own boundary: the scrubber repaints on every
                      // position tick, and without this that tick would repaint
                      // the top bar, both scrims and every icon button.
                      progressBar: RepaintBoundary(
                        child: VlcProgressBar(
                          controller: widget.controller,
                          isTv: isTv,
                          isLive: widget.isLive,
                          skipSegments: widget.skipSegments,
                          onSeekStart: () => _hideTimer?.cancel(),
                        ),
                      ),
                      leading: _leading(l10n, isTv: isTv),
                      actions: _actions(l10n, isTv: isTv),
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

  /// Shown only while the position is genuinely inside a segment, so it appears
  /// and disappears on its own and never needs dismissing.
  Widget _skipButton({required bool isTv}) {
    return PlayerValueSelector<SkipSegment?>(
      controller: widget.controller,
      selector: (v) => segmentAt(widget.skipSegments, v.position),
      builder: (context, segment) {
        if (segment == null) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.only(
            right: isTv ? 48 : 24,
            bottom: _visible ? 132 : 48,
          ),
          child: PlayerActionButton(
            label: 'Skip ${segment.type.name}',
            icon: Icons.fast_forward_rounded,
            isTv: isTv,
            onTap: () {
              _onInteraction();
              widget.controller.seekTo(
                Duration(milliseconds: (segment.endTime * 1000).round()),
              );
            },
          ),
        );
      },
    );
  }

  VlcVideoFit _fit = VlcVideoFit.contain;
}
