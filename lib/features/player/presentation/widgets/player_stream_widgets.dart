import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:media_kit/media_kit.dart';
import 'package:video_view/video_view.dart' as vv;
import '../player_controller.dart';
import '../../../../shared/widgets/custom_widgets.dart';
import '../../../settings/presentation/player_settings_provider.dart';
import 'hotstar_player_style.dart';
import '../../../skip/data/skip_service.dart';

/// A self-contained progress bar widget that uses StreamBuilder to avoid
/// rebuilding the parent widget on every position update.
class PlayerProgressBar extends ConsumerStatefulWidget {
  final Player player;
  final vv.VideoController? videoViewController;
  final VoidCallback? onSeekStart;
  final VoidCallback? onSeekEnd;

  /// On TV the scrubber becomes a focusable element: D-pad Left/Right seek by
  /// the configured step and the thumb enlarges while focused. Off TV the
  /// slider stays pointer-only (it is reached by touch/mouse, not focus).
  final bool isTv;
  final FocusNode? focusNode;
  final VoidCallback? onArrowUp;
  final VoidCallback? onArrowDown;

  const PlayerProgressBar({
    super.key,
    required this.player,
    this.videoViewController,
    this.onSeekStart,
    this.onSeekEnd,
    this.isTv = false,
    this.focusNode,
    this.onArrowUp,
    this.onArrowDown,
  });

  @override
  ConsumerState<PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends ConsumerState<PlayerProgressBar> {
  double? _dragValue;
  late final FocusNode _scrubFocusNode;
  static const double _sliderTrackInset = 24;
  ProviderSubscription<int>? _streamIndexSub;

  // ValueNotifiers so position/duration updates don't setState the whole widget.
  final _vvPositionNotifier = ValueNotifier<int>(0);
  final _vvDurationNotifier = ValueNotifier<int>(0);

  /// Position, sampled down from mpv's raw rate.
  ///
  /// media_kit forwards every `time-pos` property change straight into
  /// `player.stream.position` with no throttling (media_kit real.dart:1564-1572),
  /// so on a 60 fps title this emits ~60 times a second. Each emission rebuilt
  /// the seek row. A progress bar cannot show more than a pixel of change per
  /// tick, so ~10 Hz is visually identical and cuts the rebuild rate by ~6x.
  Stream<Duration>? _throttledPosition;
  StreamSubscription<Duration>? _positionSub;
  StreamController<Duration>? _positionController;

  static const Duration _positionSampleInterval = Duration(milliseconds: 100);

  Stream<Duration> get _positionStream =>
      _throttledPosition ??= _makeThrottledPosition();

  Stream<Duration> _makeThrottledPosition() {
    final controller = StreamController<Duration>.broadcast(sync: true);
    _positionController = controller;
    DateTime last = DateTime.fromMillisecondsSinceEpoch(0);
    Duration? pending;
    Timer? flush;

    _positionSub = widget.player.stream.position.listen((p) {
      final now = DateTime.now();
      if (now.difference(last) >= _positionSampleInterval) {
        last = now;
        pending = null;
        flush?.cancel();
        flush = null;
        if (!controller.isClosed) controller.add(p);
        return;
      }
      // Inside the sample window: remember the newest value and make sure it
      // still lands, so the bar settles on the true position when playback
      // pauses or the stream goes quiet.
      pending = p;
      flush ??= Timer(_positionSampleInterval, () {
        flush = null;
        final value = pending;
        pending = null;
        if (value != null) {
          last = DateTime.now();
          if (!controller.isClosed) controller.add(value);
        }
      });
    });
    return controller.stream;
  }

  @override
  void initState() {
    super.initState();
    _scrubFocusNode = widget.focusNode ?? FocusNode(debugLabel: 'scrubber');
    widget.videoViewController?.position.addListener(_onVvPosition);
    widget.videoViewController?.mediaInfo.addListener(_onVvMediaInfo);
    _syncVideoViewProgress();
    _watchStreamChanges();
  }

  void _watchStreamChanges() {
    // `currentStreamIndex` ticks every time the active source changes
    // (source picker, quality switch, episode autoplay). Cheap int
    // comparison; no allocations.
    _streamIndexSub = ref.listenManual<int>(
      playerControllerProvider.select((s) => s.currentStreamIndex),
      (prev, next) {
        if (prev != null && prev != next && _dragValue != null && mounted) {
          setState(() => _dragValue = null);
        }
      },
    );
  }

  @override
  void didUpdateWidget(PlayerProgressBar old) {
    super.didUpdateWidget(old);
    if (old.videoViewController != widget.videoViewController) {
      old.videoViewController?.position.removeListener(_onVvPosition);
      old.videoViewController?.mediaInfo.removeListener(_onVvMediaInfo);
      widget.videoViewController?.position.addListener(_onVvPosition);
      widget.videoViewController?.mediaInfo.addListener(_onVvMediaInfo);
      _syncVideoViewProgress();
    }
  }

  void _syncVideoViewProgress() {
    _onVvPosition();
    _onVvMediaInfo();
  }

  void _onVvPosition() {
    _vvPositionNotifier.value = widget.videoViewController?.position.value ?? 0;
  }

  void _onVvMediaInfo() {
    _vvDurationNotifier.value =
        widget.videoViewController?.mediaInfo.value?.duration ?? 0;
  }

  @override
  void dispose() {
    widget.videoViewController?.position.removeListener(_onVvPosition);
    widget.videoViewController?.mediaInfo.removeListener(_onVvMediaInfo);
    _streamIndexSub?.close();
    unawaited(_positionSub?.cancel());
    unawaited(_positionController?.close());
    _vvPositionNotifier.dispose();
    _vvDurationNotifier.dispose();
    if (widget.focusNode == null) {
      _scrubFocusNode.dispose();
    }
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final absDuration = duration.abs();
    final hours = absDuration.inHours;
    final minutes = absDuration.inMinutes.remainder(60);
    final seconds = absDuration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatRemaining(Duration duration, Duration position) {
    final remaining = duration - position;
    final clamped = remaining.isNegative ? Duration.zero : remaining;
    return '-${_formatDuration(clamped)}';
  }

  Widget _buildTimeHeader({
    required bool isLive,
    required Duration duration,
    required Duration displayDuration,
  }) {
    if (isLive) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: _sliderTrackInset),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.45),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Colors.red, size: 7),
                SizedBox(width: 5),
                Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentText = _formatDuration(displayDuration);
    final remainingText = _formatRemaining(duration, displayDuration);
    final durationText = _formatDuration(duration);
    // Persisted across sessions — once a user toggles to remaining-time
    // they almost always want it always. Stored in PlayerSettings so it
    // survives episode change, source change, and app restart.
    final showRemaining =
        ref.watch(
          playerSettingsProvider.select(
            (s) => s.asData?.value.showRemainingTime,
          ),
        ) ??
        false;
    final label = showRemaining
        ? '$remainingText / $durationText'
        : '$currentText / $durationText';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _sliderTrackInset),
      child: Align(
        alignment: Alignment.centerLeft,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              ref
                  .read(playerSettingsProvider.notifier)
                  .setShowRemainingTime(!showRemaining);
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: const TextStyle(
                  color: HotstarPlayerStyle.primaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useExoPlayer = ref.watch(
      playerControllerProvider.select((s) => s.useExoPlayer),
    );
    final canSeek = ref.watch(
      playerControllerProvider.select((s) => s.canSeek),
    );

    final skipSegments = ref.watch(
      playerControllerProvider.select((s) => s.skipSegments),
    );

    _scrubFocusNode.canRequestFocus = widget.isTv && canSeek;
    _scrubFocusNode.skipTraversal = !(widget.isTv && canSeek);

    if (useExoPlayer && widget.videoViewController != null) {
      return _buildVideoViewBar(canSeek: canSeek, skipSegments: skipSegments);
    }
    return _buildMediaKitBar(canSeek: canSeek, skipSegments: skipSegments);
  }

  Widget _buildVideoViewBar({
    required bool canSeek,
    required List<SkipSegment> skipSegments,
  }) {
    final isLive = ref.watch(playerControllerProvider.select((s) => s.isLive));

    return ValueListenableBuilder<int>(
      valueListenable: _vvDurationNotifier,
      builder: (context, durationMs, _) {
        return ValueListenableBuilder<int>(
          valueListenable: _vvPositionNotifier,
          builder: (context, positionMs, _) {
            final durationMsD = durationMs.toDouble();
            final positionMsD = positionMs.toDouble();
            final displayValue = _dragValue ?? positionMsD;
            final displayDuration = Duration(
              milliseconds: (_dragValue ?? positionMsD).toInt(),
            );
            final duration = Duration(milliseconds: durationMs);

            return _buildRow(
              duration: duration,
              durationMs: durationMsD,
              displayValue: displayValue,
              displayDuration: displayDuration,
              bufferRatio: 0.0,
              canSeek: canSeek,
              onSeekEnd: (val) => ref
                  .read(playerControllerProvider.notifier)
                  .seekTo(Duration(milliseconds: val.toInt())),
              isLive: isLive,
              skipSegments: skipSegments,
            );
          },
        );
      },
    );
  }

  Widget _buildMediaKitBar({
    required bool canSeek,
    required List<SkipSegment> skipSegments,
  }) {
    final isLive = ref.watch(playerControllerProvider.select((s) => s.isLive));

    return StreamBuilder<Duration>(
      stream: widget.player.stream.duration,
      initialData: widget.player.state.duration,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;
        final durationMs = duration.inMilliseconds.toDouble();

        return StreamBuilder<Duration>(
          stream: _positionStream,
          initialData: widget.player.state.position,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final positionMs = position.inMilliseconds.toDouble();
            final displayValue = _dragValue ?? positionMs;
            final displayDuration = _dragValue != null
                ? Duration(milliseconds: _dragValue!.toInt())
                : position;

            return StreamBuilder<Duration>(
              stream: widget.player.stream.buffer,
              initialData: widget.player.state.buffer,
              builder: (context, bufferSnapshot) {
                final buffer = bufferSnapshot.data ?? Duration.zero;
                final bufferMs = buffer.inMilliseconds.toDouble();
                final bufferRatio = durationMs > 0
                    ? (bufferMs / durationMs).clamp(0.0, 1.0)
                    : 0.0;

                return _buildRow(
                  duration: duration,
                  durationMs: durationMs,
                  displayValue: displayValue,
                  displayDuration: displayDuration,
                  bufferRatio: bufferRatio,
                  canSeek: canSeek,
                  onSeekEnd: (val) => ref
                      .read(playerControllerProvider.notifier)
                      .seekTo(Duration(milliseconds: val.toInt())),
                  isLive: isLive,
                  skipSegments: skipSegments,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRow({
    required Duration duration,
    required double durationMs,
    required double displayValue,
    required Duration displayDuration,
    required double bufferRatio,
    required bool canSeek,
    required void Function(double val) onSeekEnd,
    required List<SkipSegment> skipSegments,
    bool isLive = false,
  }) {
    // Sizes to content (time row + the fixed-height track band) so it never
    // overflows its slot — no magic outer height.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimeHeader(
          isLive: isLive,
          duration: duration,
          displayDuration: displayDuration,
        ),
        SizedBox(
          height: 36,
          child: _buildSlider(
            durationMs: durationMs,
            displayValue: displayValue,
            canSeek: canSeek,
            onSeekEnd: onSeekEnd,
            bufferRatio: bufferRatio,
            skipSegments: skipSegments,
          ),
        ),
      ],
    );
  }

  Widget _buildSlider({
    required double durationMs,
    required double displayValue,
    required bool canSeek,
    required void Function(double val) onSeekEnd,
    required double bufferRatio,
    required List<SkipSegment> skipSegments,
  }) {
    final maxValue = durationMs > 0 ? durationMs : 1.0;
    return _SeekBar(
      value: displayValue.clamp(0, maxValue),
      min: 0.0,
      max: maxValue,
      step: 30 * 1000.0, // D-pad Left/Right jumps 30 seconds on the remote
      focusNode: _scrubFocusNode,
      onArrowUp: widget.onArrowUp,
      onArrowDown: widget.onArrowDown,
      canSeek: canSeek,
      bufferRatio: bufferRatio,
      skipSegments: skipSegments,
      onChanged: canSeek ? (val) => setState(() => _dragValue = val) : null,
      onChangeStart: canSeek
          ? (val) {
              widget.onSeekStart?.call();
              setState(() => _dragValue = val);
            }
          : null,
      onChangeEnd: canSeek
          ? (val) {
              onSeekEnd(val);
              widget.onSeekEnd?.call();
              setState(() => _dragValue = null);
            }
          : null,
    );
  }
}

class PlayerPlayPauseButton extends StatelessWidget {
  final Player player;
  final vv.VideoController? videoViewController;
  final bool isLoading;
  final bool isTv;
  final double size;
  final FocusNode? focusNode;
  final VoidCallback? onPressed;

  /// When false the button shows the play/pause icon even while buffering — the
  /// buffering state is surfaced by the centered [PlayerBufferingIndicator]
  /// instead. Used for the corner button on desktop/TV so the spinner isn't
  /// hidden away where it's easy to miss.
  final bool showBufferingSpinner;

  /// Optional circular fill behind the glyph (used for the big touch-center
  /// button so it reads as a tappable target over bright video).
  final Color? backgroundColor;

  const PlayerPlayPauseButton({
    super.key,
    required this.player,
    this.videoViewController,
    this.isLoading = false,
    this.isTv = false,
    this.size = 82,
    this.focusNode,
    this.onPressed,
    this.showBufferingSpinner = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final isBuffering =
            ref.watch(playerControllerProvider.select((s) => s.isBuffering)) &&
            showBufferingSpinner;
        final useExoPlayer = ref.watch(
          playerControllerProvider.select((s) => s.useExoPlayer),
        );

        if (useExoPlayer && videoViewController != null) {
          return ListenableBuilder(
            listenable: videoViewController!.playbackState,
            builder: (context, _) {
              final isPlaying =
                  videoViewController!.playbackState.value ==
                  vv.VideoControllerPlaybackState.playing;
              return _buildButton(
                isPlaying: isPlaying,
                isSpinning: isBuffering,
              );
            },
          );
        }

        return StreamBuilder<bool>(
          stream: player.stream.playing,
          initialData: player.state.playing,
          builder: (context, snapshot) {
            return _buildButton(
              isPlaying: snapshot.data ?? false,
              isSpinning: isBuffering,
            );
          },
        );
      },
    );
  }

  Widget _buildButton({required bool isPlaying, required bool isSpinning}) {
    return CustomButton(
      focusNode: focusNode,
      onPressed: onPressed ?? () => player.playOrPause(),
      showFocusHighlight: isTv,
      shape: const CircleBorder(),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: backgroundColor != null
            ? BoxDecoration(shape: BoxShape.circle, color: backgroundColor)
            : null,
        child: isSpinning
            ? const _PlayerSpinner()
            : Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: size * 0.88,
              ),
      ),
    );
  }
}

/// The single shared player spinner — used by the centered buffering indicator
/// and by the play/pause button so they look identical (they both appear in the
/// screen centre on touch).
class _PlayerSpinner extends StatelessWidget {
  const _PlayerSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 42,
      height: 42,
      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3.5),
    );
  }
}

class PlayerBufferingIndicator extends StatelessWidget {
  final bool isVisible;

  /// On touch the play/pause button lives in the screen centre and shows its
  /// own spinner, so this indicator is suppressed while the controls are
  /// visible. On desktop/TV the play/pause button is in the corner, so the
  /// centered indicator stays shown even with controls visible — otherwise a
  /// stall is easy to miss.
  final bool isTouch;

  const PlayerBufferingIndicator({
    super.key,
    this.isVisible = false,
    this.isTouch = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final isBuffering = ref.watch(
          playerControllerProvider.select((s) => s.isBuffering),
        );
        final isLoading = ref.watch(
          playerControllerProvider.select((s) => s.isLoading),
        );
        final userSkippedOverlay = ref.watch(
          playerControllerProvider.select((s) => s.userSkippedOverlay),
        );

        if (!isBuffering && !isLoading) return const SizedBox.shrink();
        // Touch + controls visible → the centered play/pause spinner covers it.
        if (isVisible && isTouch) return const SizedBox.shrink();
        // While the primary (blocking) loading overlay is up, defer to it.
        if (isLoading && !userSkippedOverlay) return const SizedBox.shrink();

        return const IgnorePointer(child: Center(child: _PlayerSpinner()));
      },
    );
  }
}

class _TrackInterval {
  final double start;
  final double end;
  final bool isSkipSegment;

  _TrackInterval({
    required this.start,
    required this.end,
    required this.isSkipSegment,
  });
}

class _SeekBar extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final double step;
  final FocusNode? focusNode;
  final VoidCallback? onArrowUp;
  final VoidCallback? onArrowDown;
  final bool canSeek;
  final double bufferRatio;
  final List<SkipSegment> skipSegments;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;

  const _SeekBar({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    this.focusNode,
    this.onArrowUp,
    this.onArrowDown,
    required this.canSeek,
    required this.bufferRatio,
    required this.skipSegments,
    this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
  });

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  late final FocusNode _focusNode;
  bool _isFocused = false;
  bool _isDragging = false;
  Timer? _seekCommitTimer;
  late final VoidCallback _focusListener;

  bool _isTrackHovered = false;
  double _hoverX = 0.0;
  double? _lastDragValue;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusListener = () {
      if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
    };
    _focusNode.addListener(_focusListener);
  }

  @override
  void dispose() {
    _seekCommitTimer?.cancel();
    _focusNode.removeListener(_focusListener);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleDpadSeek(double newValue) {
    if (!_isDragging) {
      setState(() {
        _isDragging = true;
      });
      widget.onChangeStart?.call(newValue);
    }
    widget.onChanged?.call(newValue);

    _seekCommitTimer?.cancel();
    _seekCommitTimer = Timer(const Duration(milliseconds: 500), () {
      widget.onChangeEnd?.call(newValue);
      setState(() {
        _isDragging = false;
      });
    });
  }

  double _getValueFromOffset(double localX, double trackWidth) {
    if (trackWidth <= 0) return widget.min;
    final ratio = (localX / trackWidth).clamp(0.0, 1.0);
    return widget.min + ratio * (widget.max - widget.min);
  }

  String _formatDuration(double ms) {
    if (ms.isNaN || ms.isInfinite) return '0:00';
    final duration = Duration(milliseconds: ms.toInt());
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);
    final int seconds = duration.inSeconds.remainder(60);

    final String secondsStr = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      final String minutesStr = minutes.toString().padLeft(2, '0');
      return '$hours:$minutesStr:$secondsStr';
    } else {
      return '$minutes:$secondsStr';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      canRequestFocus: widget.canSeek,
      skipTraversal: !widget.canSeek,
      onKeyEvent: (node, event) {
        if (!widget.canSeek) return KeyEventResult.ignored;
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }

        final logicalKey = event.logicalKey;

        // Left arrow: decrease value
        if (logicalKey == LogicalKeyboardKey.arrowLeft) {
          final newValue = (widget.value - widget.step).clamp(
            widget.min,
            widget.max,
          );
          if (newValue != widget.value) {
            _handleDpadSeek(newValue);
          }
          return KeyEventResult.handled;
        }

        // Right arrow: increase value
        if (logicalKey == LogicalKeyboardKey.arrowRight) {
          final newValue = (widget.value + widget.step).clamp(
            widget.min,
            widget.max,
          );
          if (newValue != widget.value) {
            _handleDpadSeek(newValue);
          }
          return KeyEventResult.handled;
        }

        // Up arrow: move focus up
        if (logicalKey == LogicalKeyboardKey.arrowUp) {
          if (widget.onArrowUp != null) {
            widget.onArrowUp!();
            return KeyEventResult.handled;
          }
          final success = _focusNode.focusInDirection(TraversalDirection.up);
          if (!success) {
            _focusNode.previousFocus();
          }
          return KeyEventResult.handled;
        }

        // Down arrow: move focus down
        if (logicalKey == LogicalKeyboardKey.arrowDown) {
          if (widget.onArrowDown != null) {
            widget.onArrowDown!();
            return KeyEventResult.handled;
          }
          final success = _focusNode.focusInDirection(TraversalDirection.down);
          if (!success) {
            _focusNode.nextFocus();
          }
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: _isFocused
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : Border.all(color: Colors.transparent, width: 2),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: _isFocused ? 6.0 : 8.0,
          vertical: _isFocused ? 2.0 : 4.0,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth;
            final double ratio = (widget.max > widget.min)
                ? (widget.value - widget.min) / (widget.max - widget.min)
                : 0.0;
            final double progressWidth = (ratio * trackWidth).clamp(
              0.0,
              trackWidth,
            );

            // Calculate track intervals based on skip segments
            final List<_TrackInterval> intervals = [];
            if (widget.max <= widget.min || widget.skipSegments.isEmpty) {
              intervals.add(
                _TrackInterval(
                  start: 0.0,
                  end: trackWidth,
                  isSkipSegment: false,
                ),
              );
            } else {
              final List<_TrackInterval> rawIntervals = [];
              for (final seg in widget.skipSegments) {
                final double startMs = seg.startTime * 1000.0;
                final double endMs = seg.endTime * 1000.0;
                final double startRatio = (startMs / (widget.max - widget.min))
                    .clamp(0.0, 1.0);
                final double endRatio = (endMs / (widget.max - widget.min))
                    .clamp(0.0, 1.0);
                if (startRatio < endRatio) {
                  rawIntervals.add(
                    _TrackInterval(
                      start: startRatio * trackWidth,
                      end: endRatio * trackWidth,
                      isSkipSegment: true,
                    ),
                  );
                }
              }

              rawIntervals.sort((a, b) => a.start.compareTo(b.start));

              double currentX = 0.0;
              for (final seg in rawIntervals) {
                if (seg.start > currentX) {
                  intervals.add(
                    _TrackInterval(
                      start: currentX,
                      end: seg.start,
                      isSkipSegment: false,
                    ),
                  );
                }
                final double segStart = seg.start.clamp(currentX, trackWidth);
                final double segEnd = seg.end.clamp(segStart, trackWidth);
                if (segStart < segEnd) {
                  intervals.add(
                    _TrackInterval(
                      start: segStart,
                      end: segEnd,
                      isSkipSegment: true,
                    ),
                  );
                  currentX = segEnd;
                }
              }
              if (currentX < trackWidth) {
                intervals.add(
                  _TrackInterval(
                    start: currentX,
                    end: trackWidth,
                    isSkipSegment: false,
                  ),
                );
              }
            }

            // Adjust intervals to introduce a 2px visual gap (seam)
            final List<_TrackInterval> visualIntervals = [];
            for (final interval in intervals) {
              double start = interval.start;
              double end = interval.end;
              if (start > 0.0) {
                start += 1.0;
              }
              if (end < trackWidth) {
                end -= 1.0;
              }
              if (start < end) {
                visualIntervals.add(
                  _TrackInterval(
                    start: start,
                    end: end,
                    isSkipSegment: interval.isSkipSegment,
                  ),
                );
              }
            }

            // Precompute heights for each interval depending on hover position
            final List<double> intervalHeights = [];
            for (final interval in visualIntervals) {
              final bool isIntervalHovered =
                  (_isTrackHovered || _isDragging) &&
                  _hoverX >= interval.start &&
                  _hoverX <= interval.end;
              intervalHeights.add(isIntervalHovered ? 12.0 : 8.0);
            }

            // Thumb morphs if hovering anywhere on track or actively dragging
            final bool isMorphed = _isDragging || _isTrackHovered;

            final double thumbWidth;
            final double thumbHeight;
            final double thumbRadius;
            final double thumbOpacity;

            if (isMorphed) {
              thumbWidth = 3.0;
              thumbHeight = 18.0;
              thumbRadius = 2.0; // rounded-sm ≈ 2px
              thumbOpacity = 1.0;
            } else if (_isFocused) {
              thumbWidth = 14.0;
              thumbHeight = 14.0;
              thumbRadius = 7.0;
              thumbOpacity = 1.0;
            } else {
              thumbWidth = 10.0;
              thumbHeight = 10.0;
              thumbRadius = 5.0;
              thumbOpacity = 0.9;
            }

            return MouseRegion(
              onEnter: (_) {
                if (widget.canSeek) {
                  setState(() => _isTrackHovered = true);
                }
              },
              onExit: (_) {
                setState(() {
                  _isTrackHovered = false;
                  _hoverX = 0.0;
                });
              },
              onHover: (event) {
                if (widget.canSeek) {
                  setState(() => _hoverX = event.localPosition.dx);
                }
              },
              cursor: widget.canSeek
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: widget.canSeek
                    ? (details) {
                        setState(() {
                          _isDragging = true;
                          _hoverX = details.localPosition.dx;
                        });
                        final val = _getValueFromOffset(
                          details.localPosition.dx,
                          trackWidth,
                        );
                        _lastDragValue = val;
                        widget.onChangeStart?.call(val);
                      }
                    : null,
                onHorizontalDragUpdate: widget.canSeek
                    ? (details) {
                        setState(() {
                          _hoverX = details.localPosition.dx;
                        });
                        final val = _getValueFromOffset(
                          details.localPosition.dx,
                          trackWidth,
                        );
                        _lastDragValue = val;
                        widget.onChanged?.call(val);
                      }
                    : null,
                onHorizontalDragEnd: widget.canSeek
                    ? (details) {
                        setState(() {
                          _isDragging = false;
                        });
                        widget.onChangeEnd?.call(
                          _lastDragValue ?? widget.value,
                        );
                      }
                    : null,
                onTapDown: widget.canSeek
                    ? (details) {
                        final val = _getValueFromOffset(
                          details.localPosition.dx,
                          trackWidth,
                        );
                        widget.onChangeStart?.call(val);
                        widget.onChanged?.call(val);
                        widget.onChangeEnd?.call(val);
                      }
                    : null,
                child: Container(
                  height: 36.0,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    clipBehavior: Clip.none,
                    children: [
                      // 1. Track Background segments
                      for (int i = 0; i < visualIntervals.length; i++)
                        Positioned(
                          left: visualIntervals[i].start,
                          width:
                              visualIntervals[i].end - visualIntervals[i].start,
                          child: Align(
                            alignment: Alignment.center,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              curve: const Cubic(0.4, 0.0, 0.2, 1.0),
                              height: intervalHeights[i],
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4.0),
                                color: visualIntervals[i].isSkipSegment
                                    ? HotstarPlayerStyle.skipSegment.withValues(
                                        alpha: 0.35,
                                      )
                                    : const Color(
                                        0x4DCFDEF6,
                                      ), // rgba(207, 222, 246, 0.30)
                              ),
                            ),
                          ),
                        ),

                      // 2. Buffer progress segments
                      if (widget.bufferRatio > 0.0)
                        for (int i = 0; i < visualIntervals.length; i++)
                          _buildIntervalBuffer(
                            visualIntervals[i],
                            trackWidth,
                            intervalHeights[i],
                          ),

                      // 3. Played progress segments
                      for (int i = 0; i < visualIntervals.length; i++)
                        _buildIntervalProgress(
                          visualIntervals[i],
                          progressWidth,
                          intervalHeights[i],
                        ),

                      // 3.5 Hover Vertical Line (only when hovered and not dragging)
                      if (_isTrackHovered && !_isDragging)
                        (() {
                          final int hoveredIntervalIndex = visualIntervals
                              .indexWhere(
                                (interval) =>
                                    _hoverX >= interval.start &&
                                    _hoverX <= interval.end,
                              );
                          final double height = hoveredIntervalIndex != -1
                              ? intervalHeights[hoveredIntervalIndex]
                              : 8.0;

                          return Positioned(
                            left: _hoverX,
                            child: FractionalTranslation(
                              translation: const Offset(-0.5, 0.0),
                              child: Align(
                                alignment: Alignment.center,
                                child: Container(
                                  width: 1.5,
                                  height: height,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        }()),

                      // 3.6 Hover/Drag Timestamp Tooltip (visible on hover and during active drag)
                      if (_isTrackHovered || _isDragging)
                        (() {
                          final double tooltipPositionX =
                              (_isDragging && _hoverX == 0.0)
                              ? progressWidth
                              : _hoverX;

                          return Positioned(
                            left: tooltipPositionX.clamp(
                              20.0,
                              trackWidth - 20.0,
                            ),
                            top: -38.0, // Float higher above the seek bar
                            child: FractionalTranslation(
                              translation: const Offset(-0.5, 0.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10.0,
                                  vertical: 5.0,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xE61A1A1A,
                                  ), // rgba(26, 26, 26, 0.9) - dark grey
                                  borderRadius: BorderRadius.circular(
                                    16.0,
                                  ), // Pill shape
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    width: 0.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.25,
                                      ),
                                      blurRadius: 4.0,
                                      offset: const Offset(0.0, 2.0),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _formatDuration(
                                    _getValueFromOffset(
                                      tooltipPositionX,
                                      trackWidth,
                                    ),
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ], // Tabular/monospace figures
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }()),

                      // 4. Scrubber Thumb (centered horizontally at progressWidth)
                      if (widget.canSeek)
                        Positioned(
                          left: progressWidth,
                          child: FractionalTranslation(
                            translation: const Offset(-0.5, 0.0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              curve: const Cubic(0.4, 0.0, 0.2, 1.0),
                              width: thumbWidth,
                              height: thumbHeight,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                  alpha: thumbOpacity,
                                ),
                                borderRadius: BorderRadius.circular(
                                  thumbRadius,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildIntervalBuffer(
    _TrackInterval interval,
    double trackWidth,
    double height,
  ) {
    final double bufferX = widget.bufferRatio * trackWidth;
    final double intervalBufferWidth = (bufferX - interval.start).clamp(
      0.0,
      interval.end - interval.start,
    );
    if (intervalBufferWidth <= 0.0) return const SizedBox.shrink();
    return Positioned(
      left: interval.start,
      width: intervalBufferWidth,
      child: Align(
        alignment: Alignment.center,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: const Cubic(0.4, 0.0, 0.2, 1.0),
          height: height,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4.0),
            child: Container(color: Colors.white.withValues(alpha: 0.25)),
          ),
        ),
      ),
    );
  }

  Widget _buildIntervalProgress(
    _TrackInterval interval,
    double progressWidth,
    double height,
  ) {
    final double intervalProgressWidth = (progressWidth - interval.start).clamp(
      0.0,
      interval.end - interval.start,
    );
    if (intervalProgressWidth <= 0.0) return const SizedBox.shrink();
    return Positioned(
      left: interval.start,
      width: intervalProgressWidth,
      child: Align(
        alignment: Alignment.center,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: const Cubic(0.4, 0.0, 0.2, 1.0),
          height: height,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4.0),
            child: Container(
              color: interval.isSkipSegment
                  ? HotstarPlayerStyle.skipSegment
                  : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
