import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vlc_player/vlc_player.dart';

import '../../../../core/providers/device_info_provider.dart';
import '../../../skip/data/skip_service.dart';
import '../../domain/skip_segments.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../widgets/player_control_components.dart';
import '../widgets/player_stream_widgets.dart' show PlayerBufferingIndicator;
import 'vlc_progress_bar.dart';
import 'vlc_track_sheet.dart';

/// Chrome for the VLC engine — Phase 5b of docs/PLAYER_MIGRATION.md.
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
    this.isLive = false,
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

  /// Whether this is a live stream, decided by the app rather than the engine.
  final bool isLive;

  /// Intro/outro bands, usually empty - both sources are opt-in.
  final List<SkipSegment> skipSegments;

  @override
  ConsumerState<VlcPlayerControls> createState() => _VlcPlayerControlsState();
}

class _VlcPlayerControlsState extends ConsumerState<VlcPlayerControls> {
  /// Matches the old overlay's timeout (skystream_player_controls.dart:689).
  static const Duration _hideAfter = Duration(seconds: 3);
  static const Duration _fade = Duration(milliseconds: 200);

  bool _visible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _restartHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  /// The single sink. Every interaction routes here; nothing else touches the
  /// timer. That is the whole reason chrome cannot vanish mid-interaction.
  void _onInteraction() {
    if (!_visible) setState(() => _visible = true);
    _restartHideTimer();
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideAfter, () {
      if (mounted) setState(() => _visible = false);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isTv = ref.watch(deviceProfileProvider).asData?.value.isTv ?? false;
    final isTouch = !isTv && (Platform.isAndroid || Platform.isIOS);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onInteraction(),
      child: Focus(
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent) _onInteraction();
          return KeyEventResult.ignored;
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Buffering reads through even when the chrome is hidden.
            Center(
              child: ValueListenableBuilder<VlcPlayerValue>(
                valueListenable: widget.controller,
                builder: (context, value, _) => Opacity(
                  opacity: value.state == VlcPlaybackState.buffering ? 1 : 0,
                  child: const PlayerBufferingIndicator(),
                ),
              ),
            ),
            _chrome(context, l10n, isTv: isTv, isTouch: isTouch),
            // Deliberately outside the chrome: an intro can start while the
            // bars are hidden, and hiding the one control that is time-limited
            // behind a tap would defeat it.
            if (widget.skipSegments.isNotEmpty)
              Align(
                alignment: Alignment.bottomRight,
                child: _skipButton(isTv: isTv),
              ),
          ],
        ),
      ),
    );
  }

  /// Shown only while the position is genuinely inside a segment, so it appears
  /// and disappears on its own and never needs dismissing.
  Widget _skipButton({required bool isTv}) {
    return ValueListenableBuilder<VlcPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final segment = segmentAt(widget.skipSegments, value.position);
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
                  PlayerTopBar(
                    title: widget.title,
                    subtitle: widget.subtitle,
                    onBack: widget.onBack,
                    isTv: isTv,
                  ),
                  const Expanded(child: SizedBox.expand()),
                  PlayerBottomBar(
                    isTv: isTv,
                    isTouch: isTouch,
                    // Its own boundary: the scrubber repaints on every position
                    // tick, and without this that tick would repaint the top
                    // bar, both scrims and every icon button.
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _leading(AppLocalizations l10n, {required bool isTv}) {
    return <Widget>[
      ValueListenableBuilder<VlcPlayerValue>(
        valueListenable: widget.controller,
        builder: (context, value, _) => PlayerIconButton(
          icon: value.isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          tooltip: value.isPlaying ? l10n.pause : l10n.play,
          isTv: isTv,
          iconSize: 40,
          onPressed: () {
            _onInteraction();
            value.isPlaying
                ? widget.controller.pause()
                : widget.controller.play();
          },
        ),
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
      if (widget.onEnterPip != null)
        PlayerIconButton(
          icon: Icons.picture_in_picture_alt_rounded,
          tooltip: l10n.pip,
          isTv: isTv,
          onPressed: widget.onEnterPip,
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
  }

  VlcVideoFit _fit = VlcVideoFit.contain;
}
