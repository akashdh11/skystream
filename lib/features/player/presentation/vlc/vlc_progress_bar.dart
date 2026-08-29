import 'package:flutter/material.dart';
import 'package:vlc_player/vlc_player.dart';

import '../../../skip/data/skip_service.dart';
import '../widgets/player_stream_widgets.dart';

/// The seek bar for the VLC engine.
///
/// Deliberately thin: it holds only the drag position, and renders through the
/// shared [PlayerScrubber]. Nothing here decides what the chrome looks like, so
/// the VLC overlay cannot drift from the media_kit one — there is one scrubber
/// implementation and both engines feed it.
///
/// It listens to the controller directly rather than through Riverpod, so a
/// position tick rebuilds this widget and nothing above it.
class VlcProgressBar extends StatefulWidget {
  const VlcProgressBar({
    required this.controller,
    this.isTv = false,
    this.isLive = false,
    this.skipSegments = const <SkipSegment>[],
    this.focusNode,
    this.onArrowUp,
    this.onSeekStart,
    super.key,
  });

  final VlcPlayerController controller;
  final bool isTv;

  /// Decided by the app from the item and URL, not by the engine.
  ///
  /// libVLC derives its own `isLive` as "no duration and not seekable", which
  /// is false for any live stream with a DVR window - SUN NXT reports a
  /// three-hour `timeShiftBufferDepth` and is seekable, so the engine calls it
  /// VOD and the bar renders a three-hour timeline with an absolute position
  /// inside it. The app knows better from the manifest and the content type.
  final bool isLive;

  /// Painted as bands on the track so the viewer can see an intro coming.
  final List<SkipSegment> skipSegments;
  final FocusNode? focusNode;
  final VoidCallback? onArrowUp;

  /// Called when a drag begins, so the overlay can hold its chrome open.
  final VoidCallback? onSeekStart;

  @override
  State<VlcProgressBar> createState() => _VlcProgressBarState();
}

class _VlcProgressBarState extends State<VlcProgressBar> {
  /// Set only while the user is dragging. The engine keeps reporting its own
  /// position during a scrub, and showing that would fight the thumb.
  Duration? _dragTo;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VlcPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final duration = value.duration;
        // A live stream has no meaningful end, and libVLC reports isSeekable
        // false for most of them - the scrubber shows the LIVE pill instead.
        final isLive =
            widget.isLive || value.isLive || duration <= Duration.zero;
        final canSeek = value.isSeekable && duration > Duration.zero;

        return PlayerScrubber(
          position: _dragTo ?? value.position,
          duration: duration,
          // libVLC reports buffering as a 0..100 percentage of the current
          // fill operation, not of the media, and it sits at 100 during steady
          // playback. Treating that as "buffered ahead" would paint the whole
          // track, so the buffer band stays empty until there is a real figure.
          bufferRatio: 0,
          canSeek: canSeek,
          isLive: isLive,
          skipSegments: widget.skipSegments,
          focusNode: widget.focusNode,
          onArrowUp: widget.onArrowUp,
          onChangeStart: (ms) {
            widget.onSeekStart?.call();
            setState(() => _dragTo = Duration(milliseconds: ms.round()));
          },
          onChanged: (ms) =>
              setState(() => _dragTo = Duration(milliseconds: ms.round())),
          onChangeEnd: (ms) {
            widget.controller.seekTo(Duration(milliseconds: ms.round()));
            setState(() => _dragTo = null);
          },
        );
      },
    );
  }
}
