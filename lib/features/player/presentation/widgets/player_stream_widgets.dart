import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/custom_widgets.dart';
import '../../../settings/presentation/player_settings_provider.dart';
import 'hotstar_player_style.dart';
import '../../../skip/data/skip_service.dart';

/// The scrubber row — time label above, seek bar below — driven entirely by
/// plain values.
///
/// Extracted so a second engine renders *the same widget* rather than a
/// lookalike. Phase 5b's "no visual diff" criterion is then satisfied by
/// construction: there is one implementation, and any future change to it
/// necessarily lands on both paths at once.
///
/// Deliberately knows nothing about media_kit, libVLC or Riverpod player state.
/// The one provider it touches is [playerSettingsProvider], for the persisted
/// elapsed/remaining toggle, which is a user preference rather than engine
/// state.
/// Horizontal inset that aligns the time label with the seek bar's track.
const double _kSliderTrackInset = 24;

String _formatClock(Duration duration) {
  final abs = duration.abs();
  final hours = abs.inHours;
  final minutes = abs.inMinutes.remainder(60);
  final seconds = abs.inSeconds.remainder(60);
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String _formatRemainingClock(Duration duration, Duration position) {
  final remaining = duration - position;
  return '-${_formatClock(remaining.isNegative ? Duration.zero : remaining)}';
}

class PlayerScrubber extends ConsumerWidget {
  const PlayerScrubber({
    super.key,
    required this.position,
    required this.duration,
    required this.bufferRatio,
    required this.canSeek,
    this.isLive = false,
    this.skipSegments = const <SkipSegment>[],
    this.focusNode,
    this.onArrowUp,
    this.onArrowDown,
    this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
  });

  /// What the label and thumb should show — the drag position while scrubbing,
  /// the playback position otherwise.
  final Duration position;
  final Duration duration;

  /// 0..1 of [duration] currently buffered.
  final double bufferRatio;

  final bool canSeek;
  final bool isLive;
  final List<SkipSegment> skipSegments;

  final FocusNode? focusNode;
  final VoidCallback? onArrowUp;
  final VoidCallback? onArrowDown;

  /// Milliseconds, matching [PlayerSeekBar]'s value space.
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final durationMs = duration.inMilliseconds.toDouble();
    final maxValue = durationMs > 0 ? durationMs : 1.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _timeHeader(context, ref),
        SizedBox(
          height: 36,
          child: PlayerSeekBar(
            value: position.inMilliseconds.toDouble().clamp(0, maxValue),
            min: 0.0,
            max: maxValue,
            step: 30 * 1000.0, // D-pad Left/Right jumps 30 seconds
            focusNode: focusNode,
            onArrowUp: onArrowUp,
            onArrowDown: onArrowDown,
            canSeek: canSeek,
            bufferRatio: bufferRatio,
            skipSegments: skipSegments,
            onChanged: canSeek ? onChanged : null,
            onChangeStart: canSeek ? onChangeStart : null,
            onChangeEnd: canSeek ? onChangeEnd : null,
          ),
        ),
      ],
    );
  }

  Widget _timeHeader(BuildContext context, WidgetRef ref) {
    if (isLive) return const _LivePill();

    final showRemaining =
        ref.watch(
          playerSettingsProvider.select(
            (s) => s.asData?.value.showRemainingTime,
          ),
        ) ??
        false;
    final label = showRemaining
        ? '${_formatRemainingClock(duration, position)} / ${_formatClock(duration)}'
        : '${_formatClock(position)} / ${_formatClock(duration)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kSliderTrackInset),
      child: Align(
        alignment: Alignment.centerLeft,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ref
                .read(playerSettingsProvider.notifier)
                .setShowRemainingTime(!showRemaining),
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
}

/// The red LIVE badge shown instead of a time label on a live stream.
class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kSliderTrackInset),
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

/// The centred buffering spinner.
///
/// Deliberately has no opinion about when it should appear: it used to read
/// three fields off the old player controller to decide, which meant the
/// decision lived in the wrong place and could disagree with the overlay
/// around it. The caller owns visibility now.
class PlayerBufferingIndicator extends StatelessWidget {
  const PlayerBufferingIndicator({super.key});

  @override
  Widget build(BuildContext context) =>
      const IgnorePointer(child: Center(child: _PlayerSpinner()));
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

class PlayerSeekBar extends StatefulWidget {
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

  const PlayerSeekBar({
    super.key,
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
  State<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<PlayerSeekBar> {
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
