/// The side-car subtitle on screen: drawn by SkyStream over the video, not by
/// libVLC into it.
///
/// Laid out against the player area rather than the picture, so Zoom and
/// Stretch never move, scale or cut off a line - the fit changes the picture
/// under the text and nothing else. Sized and styled from the same numbers
/// the settings preview and libVLC use ([subtitleFontSize]), so a subtitle
/// file reads like a track inside the video, and follows a settings change at
/// once - bold, the font and the text opacity included, which libVLC only
/// takes when a player is created.
///
/// Timed off the controller's playback clock with the subtitle delay applied.
/// The engine reports its position a few times a second, and coarsely; the
/// clock runs on between reports and never steps back unless playback did.
/// One timer wakes the view at the next line's start or end, so a line lands
/// on its frame rather than up to half a second after it, and nothing is
/// rebuilt in between.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:vlc_player/vlc_player.dart';

import '../../../settings/presentation/player_settings_provider.dart';
import '../../domain/side_car_subtitles.dart';
import '../../domain/subtitle_cues.dart';
import '../../domain/subtitle_style.dart';

/// Space the text keeps from each side, as a share of the width.
const double _kSideMargin = 0.05;

/// The side-car subtitle on screen. Draws nothing while no side-car is on or
/// no line is due.
class SideCarSubtitleView extends StatefulWidget {
  const SideCarSubtitleView({
    required this.controller,
    required this.subtitles,
    required this.settings,
    super.key,
  });

  final VlcPlayerController controller;
  final SideCarSubtitles subtitles;
  final PlayerSettings settings;

  @override
  State<SideCarSubtitleView> createState() => _SideCarSubtitleViewState();
}

class _SideCarSubtitleViewState extends State<SideCarSubtitleView> {
  /// Wakes the view when the lines on screen next change.
  Timer? _wake;

  List<SubtitleCue> _shown = const [];

  @override
  void initState() {
    super.initState();
    _listen(widget.controller);
    widget.subtitles.addListener(_refresh);
    _refresh();
  }

  @override
  void didUpdateWidget(SideCarSubtitleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _stopListening(oldWidget.controller);
      _listen(widget.controller);
    }
    if (oldWidget.subtitles != widget.subtitles) {
      oldWidget.subtitles.removeListener(_refresh);
      widget.subtitles.addListener(_refresh);
    }
    _refresh();
  }

  @override
  void dispose() {
    _stopListening(widget.controller);
    widget.subtitles.removeListener(_refresh);
    _wake?.cancel();
    super.dispose();
  }

  // The clock for where playback is, the controller for the subtitle delay.
  void _listen(VlcPlayerController controller) {
    controller.addListener(_refresh);
    controller.playbackClock.addListener(_refresh);
  }

  void _stopListening(VlcPlayerController controller) {
    controller.removeListener(_refresh);
    controller.playbackClock.removeListener(_refresh);
  }

  void _refresh() {
    _wake?.cancel();
    _wake = null;
    if (!mounted) return;
    final clock = widget.controller.playbackClock;
    final delay = widget.controller.value.subtitleDelay;
    final timeline = widget.subtitles.timeline;
    // The position the file's times are read against: where playback is,
    // less the delay - a positive delay shows every line later.
    final at = clock.position - delay;
    final due = timeline.isEmpty ? const <SubtitleCue>[] : timeline.at(at);
    if (!listEquals(due, _shown)) setState(() => _shown = due);

    final next = timeline.nextChange(at);
    if (next == null) return;
    // Null while paused, or held until the engine reports again: then the
    // clock tells this view when it moves.
    final wait = clock.timeUntil(next + delay);
    if (wait == null) return;
    // A millisecond over, so the wake lands inside the new line, not on the
    // edge of the old one.
    _wake = Timer(wait + const Duration(milliseconds: 1), _refresh);
  }

  @override
  Widget build(BuildContext context) {
    if (_shown.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) => _lines(constraints.biggest),
        ),
      ),
    );
  }

  Widget _lines(Size area) {
    final style = subtitleStyleFrom(widget.settings);
    final fontSize = subtitleFontSize(widget.settings, area);
    final frame = subtitleFrameHeight(area);
    final margin = frame * kSubtitleEdgeMargin;
    final side = area.width * _kSideMargin;

    List<Widget> band(SubtitlePlacement placement) => [
      for (final cue in _shown)
        if (cue.placement == placement) _cue(cue, style, fontSize),
    ];

    // The lines' bottom edge: the same fixed target the embedded track is
    // anchored to — see [subtitleTargetY] — so a file and a track inside
    // the video sit at the same place. One fixed place, from the area
    // alone: a pinch never moves the lines, and never the bottom chrome,
    // so they never move when the controls show or hide. Bottom lines
    // only: a line placed at the top or the middle stays there.
    final bottomOffset =
        area.height - subtitleTargetY(area, widget.settings.subtitleRaise);

    // Where two lines are due together the earlier one keeps its place and
    // the later one stacks away from the edge, as libass lays them out.
    final bottom = band(SubtitlePlacement.bottom).reversed.toList();
    final middle = band(SubtitlePlacement.middle);
    final top = band(SubtitlePlacement.top);

    return Stack(
      children: [
        if (top.isNotEmpty)
          Positioned(top: margin, left: side, right: side, child: _column(top)),
        if (middle.isNotEmpty)
          Positioned.fill(
            left: side,
            right: side,
            child: Center(child: _column(middle)),
          ),
        if (bottom.isNotEmpty)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            bottom: bottomOffset,
            left: side,
            right: side,
            child: _column(bottom),
          ),
      ],
    );
  }

  Widget _column(List<Widget> cues) =>
      Column(mainAxisSize: MainAxisSize.min, children: cues);

  /// One cue: the text over its outline, in a box when the viewer asked for
  /// one - the preview's drawing, at the player's size.
  Widget _cue(SubtitleCue cue, VlcSubtitleStyle style, double fontSize) {
    final outline = subtitleOutlineWidth(widget.settings.subtitleOutline);
    final bold = widget.settings.subtitleBold;
    final direction = Bidi.detectRtlDirectionality(cue.text)
        ? TextDirection.rtl
        : TextDirection.ltr;
    final base = TextStyle(
      fontSize: fontSize,
      fontFamily: style.fontFamily,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
      height: 1.2,
    );

    Widget text(TextStyle paint) => Text.rich(
      TextSpan(
        style: base.merge(paint),
        children: [
          for (final span in cue.spans)
            TextSpan(
              text: span.text,
              style: TextStyle(
                fontStyle: span.italic ? FontStyle.italic : null,
                // Bold in the file stays bolder than the line around it.
                fontWeight: span.bold
                    ? (bold ? FontWeight.w900 : FontWeight.w800)
                    : null,
              ),
            ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: direction,
    );

    return Padding(
      padding: EdgeInsets.only(top: fontSize * 0.15),
      child: DecoratedBox(
        decoration: BoxDecoration(color: style.backgroundColor),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: fontSize * 0.3,
            vertical: fontSize * 0.05,
          ),
          child: Stack(
            children: [
              // A Text cannot outline its glyphs, so the outline is a stroked
              // copy underneath, as in the settings preview.
              if (outline > 0)
                text(
                  TextStyle(
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = outline
                      ..strokeJoin = StrokeJoin.round
                      ..color = style.outlineColor ?? const Color(0xFF000000),
                  ),
                ),
              text(TextStyle(color: style.color)),
            ],
          ),
        ),
      ),
    );
  }
}
