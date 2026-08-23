import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vlc_player/vlc_player.dart';

/// Minimal chrome for the Phase 5 VLC player: back, title, play/pause, seek.
///
/// A fresh overlay rather than a reuse of `SkyStreamPlayerControls`, which is
/// not reusable here even in principle: it takes a non-nullable **media_kit**
/// `Player` (skystream_player_controls.dart:36, required at :61), reads
/// `playerControllerProvider` 72 times, and unconditionally mounts
/// TorrentInfoWidget, ResumePromptOverlay, NextEpisodeOverlay,
/// SkipSegmentOverlay, three PlayerSidePanels and PlayerMetadataScrim — every
/// one of which Phase 5 excludes.
///
/// No file the old screen imports is touched by this one, so the shipping path
/// cannot regress. Phase 5b rebuilds the real controls' machinery on top of
/// this shape; the visual design lands there, not here.
class VlcPlayerControls extends StatefulWidget {
  const VlcPlayerControls({
    required this.controller,
    required this.title,
    this.subtitle,
    this.onBack,
    super.key,
  });

  final VlcPlayerController controller;
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;

  @override
  State<VlcPlayerControls> createState() => _VlcPlayerControlsState();
}

class _VlcPlayerControlsState extends State<VlcPlayerControls> {
  static const Duration _hideAfter = Duration(seconds: 4);

  bool _visible = true;
  Timer? _hideTimer;
  double? _scrubTo;

  @override
  void initState() {
    super.initState();
    _restartHideTimer();
  }

  /// One place restarts the hide timer, and one thing calls it: the interaction
  /// sink below. The old controls poke an equivalent timer from fifteen
  /// separate call sites, which is why chrome there can vanish mid-interaction
  /// if a path forgets — see Phase 5b.
  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideAfter, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  void _onInteraction() {
    if (!_visible) setState(() => _visible = true);
    _restartHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    // A single Listener/Focus wrapper feeds every interaction to one sink,
    // instead of each control remembering to report itself.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onInteraction(),
      child: Focus(
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent) _onInteraction();
          return KeyEventResult.ignored;
        },
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !_visible,
            child: ExcludeFocus(
              excluding: !_visible,
              child: Column(
                children: [
                  _topBar(context),
                  const Spacer(),
                  _bottomBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              autofocus: true,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: widget.onBack,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  if (widget.subtitle != null)
                    Text(
                      widget.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  /// The only part that repaints on a position tick, so it is the only part in
  /// its own boundary — and it listens to the controller's ValueNotifier
  /// directly rather than going through Riverpod.
  Widget _bottomBar() {
    return RepaintBoundary(
      child: ColoredBox(
        color: Colors.black54,
        child: SafeArea(
          top: false,
          child: ValueListenableBuilder<VlcPlayerValue>(
            valueListenable: widget.controller,
            builder: (context, value, _) {
              final durationMs = value.duration.inMilliseconds.toDouble();
              final positionMs = value.position.inMilliseconds.toDouble();
              final seekable = value.isSeekable && durationMs > 0;
              return Row(
                children: [
                  IconButton(
                    icon: Icon(
                      value.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      _onInteraction();
                      value.isPlaying
                          ? widget.controller.pause()
                          : widget.controller.play();
                    },
                  ),
                  Text(
                    _fmt(value.position),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Expanded(
                    child: Slider(
                      value: (_scrubTo ?? positionMs).clamp(
                        0,
                        durationMs <= 0 ? 1 : durationMs,
                      ),
                      max: durationMs <= 0 ? 1 : durationMs,
                      onChanged: seekable
                          ? (v) {
                              _onInteraction();
                              setState(() => _scrubTo = v);
                            }
                          : null,
                      onChangeEnd: seekable
                          ? (v) {
                              widget.controller.seekTo(
                                Duration(milliseconds: v.round()),
                              );
                              setState(() => _scrubTo = null);
                            }
                          : null,
                    ),
                  ),
                  Text(
                    _fmt(value.duration),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(width: 8),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
