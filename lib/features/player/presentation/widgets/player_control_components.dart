import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';

import '../../../../shared/widgets/custom_widgets.dart';
import 'hotstar_player_style.dart';
import 'player_activation.dart';
import 'player_matte_pill.dart';
import '../../../../shared/focus/app_focus.dart';

/// Top zone: back button + title/subtitle. Paints its own top scrim.
class PlayerTopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final bool isTv;
  final FocusNode? backFocusNode;

  const PlayerTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.isTv = false,
    this.backFocusNode,
  });

  /// The bar's padding inside the top safe area, which is also what places its
  /// back button. [PlayerBackButtonSlot] reads the same numbers, so Back does
  /// not move when the controls take over from a screen shown before the
  /// video.
  static EdgeInsets paddingOf(BuildContext context, {required bool isTv}) {
    final padding = MediaQuery.viewPaddingOf(context);
    final edge = isTv
        ? HotstarPlayerStyle.tvEdgeInset
        : HotstarPlayerStyle.edgeInset;
    final double leftPadding = isTv
        ? edge
        : (padding.left > edge ? padding.left : edge);
    final double rightPadding = isTv
        ? edge
        : (padding.right > edge ? padding.right : edge);
    return EdgeInsets.fromLTRB(leftPadding, 14, rightPadding, 24);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: HotstarPlayerStyle.topGradient),
      child: SafeArea(
        left: false,
        right: false,
        bottom: false,
        child: Padding(
          padding: paddingOf(context, isTv: isTv),
          child: Row(
            children: [
              PlayerBackButton(
                onPressed: onBack,
                isTv: isTv,
                focusNode: backFocusNode,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: HotstarPlayerStyle.secondaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      title,
                      style: TextStyle(
                        color: HotstarPlayerStyle.primaryText,
                        fontSize: isTv ? 22 : 18,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The player's back button: the glyph, size and focus treatment
/// [PlayerTopBar] gives it.
class PlayerBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isTv;
  final FocusNode? focusNode;

  /// {@macro flutter.widgets.Focus.autofocus}
  final bool autofocus;

  const PlayerBackButton({
    super.key,
    required this.onPressed,
    this.isTv = false,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return PlayerIconButton(
      icon: Icons.arrow_back_rounded,
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: onPressed,
      isTv: isTv,
      focusNode: focusNode,
      autofocus: autofocus,
      iconSize: isTv ? 34 : 30,
    );
  }
}

/// [PlayerBackButton] on its own, where [PlayerTopBar] puts it.
///
/// For the screens that stand in for the video before there is one -
/// resolving, opening and failed - so Back is in the same place before and
/// after the first frame. Fills its parent but hit-tests only the button, so
/// it can sit in a Stack above a layer that wants the rest of the surface.
class PlayerBackButtonSlot extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isTv;

  /// {@macro flutter.widgets.Focus.autofocus}
  final bool autofocus;

  const PlayerBackButtonSlot({
    super.key,
    required this.onPressed,
    this.isTv = false,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      left: false,
      right: false,
      bottom: false,
      child: Padding(
        padding: PlayerTopBar.paddingOf(context, isTv: isTv),
        // Start, not left: the bar is a Row, which puts Back on the right in
        // a right-to-left locale.
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: PlayerBackButton(
            onPressed: onPressed,
            isTv: isTv,
            autofocus: autofocus,
          ),
        ),
      ),
    );
  }
}

/// Bottom zone shell: scrubber row on top, then a single flat controls row —
/// [leading] (playback) pinned left and [actions] (everything else) filling
/// the rest, right-anchored. Paints its own scrim.
///
/// Neither layout branch may overflow and neither may hide a button. The fork
/// is whether the device can *move* a strip, which is to say whether it has a
/// pointer:
///
///  * Everything but a television gets a right-anchored scrolling strip with a
///    visible edge hint — one line tall at every width, dragged by finger on a
///    handset and by mouse or trackpad on a desktop (see [PlayerActionStrip],
///    which enables the pointer drag the default scroll behaviour withholds).
///  * A television gets a [Wrap], because a D-pad cannot drag anything: its
///    extra runs go above the first so nothing is clipped and every button is
///    still reachable by arrow.
///
/// Both branches render the same button list; the fork is a layout ramp, not a
/// capability gate.
///
/// The strip never gets a run of its own. Giving it one below a width
/// threshold rendered the bar as two runs, 112 dp tall, on the commonest
/// Android portrait width — chrome eating 48 dp of the video underneath it.
/// The [Wrap] has the same failure without a threshold to blame: on a narrow
/// desktop window ten buttons became five runs and a 284 dp bar that ran off
/// the bottom of a 330 dp viewport, taking the scrubber with it. One line is
/// also what keeps the transport group and the utility group on the same line
/// as each other, which two runs silently break — [Row] centres the short
/// child against the tall one.
///
/// Directional keys are left to [DirectionalFocusAction]: the buttons are
/// siblings in one [Row] inside one [FocusTraversalGroup], so geometric
/// traversal walks the row and stops at its ends.
/// [FocusNode.nextFocus]/[previousFocus] must not be used here — they operate
/// on the enclosing scope (the route), not the group, and wrap to the route's
/// first and last node.
class PlayerBottomBar extends StatelessWidget {
  final Widget progressBar;
  final List<Widget> leading;
  final List<Widget> actions;
  final bool isTv;

  /// Whether the [actions] scroll rather than wrap.
  ///
  /// True wherever a pointer can drag them, which is everywhere but a
  /// television. Picks a layout for the viewport, never which controls exist.
  final bool scrollingActions;

  /// The widest viewport still laid out as a portrait handset, in the logical
  /// pixels the bar's own [Padding] leaves it — a device width minus the two
  /// [HotstarPlayerStyle.edgeInset]s. It sits in the gap between the widest
  /// handset held upright (430 dp) and the narrowest one turned sideways
  /// (568 dp), so no device straddles it.
  ///
  /// This bar does not branch on it. Only `next_episode_countdown.dart` reads
  /// it, to decide how much room to leave above the bar; that reservation runs
  /// 48 dp generous on a portrait handset, which lifts the up-next card but
  /// cannot make it overlap the scrubber.
  static const double narrowTouchWidth = 520;

  const PlayerBottomBar({
    super.key,
    required this.progressBar,
    this.leading = const [],
    this.actions = const [],
    this.isTv = false,
    this.scrollingActions = false,
  });

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewPaddingOf(context);
    final edge = isTv
        ? HotstarPlayerStyle.tvEdgeInset
        : HotstarPlayerStyle.edgeInset;
    final double leftPadding = isTv
        ? edge
        : (padding.left > edge ? padding.left : edge);
    final double rightPadding = isTv
        ? edge
        : (padding.right > edge ? padding.right : edge);
    // A gradient is paint, not a compositing layer, so the scrim costs nothing
    // over the platform view. Without it a reveal on a bright scene puts white
    // glyphs on white.
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: HotstarPlayerStyle.bottomGradient,
      ),
      child: SafeArea(
        left: false,
        right: false,
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(leftPadding, 2, rightPadding, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              progressBar,
              FocusTraversalGroup(child: _controlsRow()),
            ],
          ),
        ),
      ),
    );
  }

  /// The one flat control line: the transport group pinned left, everything
  /// else filling the rest of the same line.
  ///
  /// The left group is always visible, never scrolled and never wrapped. The
  /// branches differ only in what the remainder does when the actions outgrow
  /// it, and neither may move the transport group off the bottom line.
  Widget _controlsRow() {
    // Sized to its own children rather than spread, so it is inflexible and
    // the remainder is exactly what [Expanded] hands the actions.
    final Widget transport = Row(
      mainAxisSize: MainAxisSize.min,
      children: leading,
    );

    return Row(
      children: [
        transport,
        if (leading.isNotEmpty && actions.isNotEmpty) const SizedBox(width: 8),
        Expanded(
          // Touch: one line, right-anchored, finger-scrolled, with an edge
          // hint. No [LayoutBuilder] and no width threshold — a threshold is
          // what produced the second run.
          child: actions.isEmpty
              ? const SizedBox.shrink()
              : Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: PlayerMattePill(
                    child: scrollingActions
                        ? PlayerActionStrip(actions: actions)
                        // A television has no pointer to drag a strip with, so overflow
                        // is laid out rather than scrolled: extra runs go above the
                        // first and the bar grows upwards.
                        : Wrap(
                            alignment: WrapAlignment.end,
                            runAlignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: actions,
                          ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// The action strip: right-anchored, scrollable by pointer, and visibly so.
///
/// Right-anchored means the overflow slides off the left edge, so the buttons
/// at the end of the list survive a squeeze and the ones at the start vanish.
/// A 360 dp portrait phone can leave this 70 dp of the bar's 320, so when —
/// and only when — content is hidden to the left, a scrim-to-clear gradient
/// with a chevron is painted over that edge. It is [IgnorePointer]: a hint,
/// not a control, and it must never eat the tap meant for the half-visible
/// button underneath it.
class PlayerActionStrip extends StatefulWidget {
  const PlayerActionStrip({super.key, required this.actions});

  final List<Widget> actions;

  /// Width of the painted edge hint. Also the amount of the outermost button
  /// it covers, which is why it is narrow and translucent rather than opaque.
  static const double hintWidth = 28;

  @override
  State<PlayerActionStrip> createState() => _PlayerActionStripState();
}

class _PlayerActionStripState extends State<PlayerActionStrip> {
  /// Whether anything is still hidden off the left edge.
  bool _more = false;

  /// Both notifications are listened to on purpose. [ScrollNotification]
  /// covers a finger moving the strip; [ScrollMetricsNotification] covers the
  /// cases where nothing scrolled but the answer changed anyway — first
  /// layout, a rotation, a button appearing or disappearing. Metrics arrive in
  /// a microtask after layout (`ScrollPosition.didUpdateScrollMetrics`), so
  /// setState from here is a legal frame request, not a build-time mutation.
  bool _update(ScrollMetrics metrics) {
    // Half a logical pixel: less than that is hidden by rounding rather than
    // by the viewport, and a hint painted for it would never go away.
    final bool more = metrics.maxScrollExtent - metrics.pixels > 0.5;
    if (more != _more && mounted) setState(() => _more = more);
    return false;
  }

  /// Drag devices, widened to include the two a desktop actually has.
  ///
  /// [MaterialScrollBehavior] allows a drag from touch and stylus only, on the
  /// reasoning that a desktop scrolls with a wheel. A horizontal strip is the
  /// case that breaks: [Scrollable] maps a wheel's `scrollDelta.dy` onto a
  /// vertical axis and reads `dx` for a horizontal one, so a plain mouse wheel
  /// moves this not at all. Without the drag, buttons off the left edge would
  /// be unreachable on the one device where this strip is new.
  static const Set<PointerDeviceKind> _dragDevices = <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _update(n.metrics),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => _update(n.metrics),
        child: Stack(
          children: [
            ScrollConfiguration(
              behavior: ScrollConfiguration.of(context)
                  .copyWith(dragDevices: _dragDevices, scrollbars: false),
              // Shrink to the button row when it fits; use the available
              // width when it overflows. The enclosing Align anchors the
              // whole pill at the trailing edge in either case.
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: widget.actions,
                ),
              ),
            ),
            if (_more)
              const Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: SizedBox(
                    width: PlayerActionStrip.hintWidth,
                    // Paint, not a layer: a gradient in a DecoratedBox costs
                    // nothing over the platform view, where an opacity or a
                    // blur would be one more IOSurface.
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Color(0xCC000000), Color(0x00000000)],
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Icon(
                          Icons.chevron_left_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact icon-only button for utilities (resize, PiP, fullscreen) and the
/// top-bar back button.
///
/// The accessible name is explicit because a [Tooltip] wrapped around a button
/// does not name it: [Tooltip] annotates with `SemanticsProperties.tooltip`
/// only, and [CustomButton]'s [TextButton] starts a semantics container
/// underneath, so the annotation cannot merge down onto the node that owns the
/// tap. An explicit [Semantics] supplies the name and a [MergeSemantics]
/// collapses name, button flag and tap action into one node. Asserted by
/// `test/features/player/player_semantics_test.dart`.
class PlayerIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isTv;
  final bool highlight;
  final FocusNode? focusNode;

  /// {@macro flutter.widgets.Focus.autofocus}
  final bool autofocus;

  /// Optional icon-size override (the tap target grows to match). Used by the
  /// top-bar back button so it reads at the same weight as the title.
  final double? iconSize;

  const PlayerIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isTv = false,
    this.highlight = false,
    this.focusNode,
    this.autofocus = false,
    this.iconSize,
  });

  @override
  State<PlayerIconButton> createState() => _PlayerIconButtonState();
}

class _PlayerIconButtonState extends State<PlayerIconButton> {
  bool _hovered = false;
  bool _focused = false;
  FocusNode? _ownedFocusNode;

  @override
  void dispose() {
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double glyph = widget.iconSize ?? (widget.isTv ? 28 : 26);
    final double box = glyph + (widget.isTv ? 20 : 18);
    final matte = PlayerMattePill.contains(context);
    final showFocus = showFocusIndicator(context, true);
    final matteForeground = WidgetStateProperty.resolveWith<Color>((states) {
      if (states.contains(WidgetState.disabled)) {
        return const Color(0x61FFFFFF);
      }
      if ((showFocus && states.contains(WidgetState.focused)) ||
          states.contains(WidgetState.hovered) ||
          widget.highlight) {
        return PlayerMattePill.focusInk;
      }
      return Colors.white;
    });

    Color iconColor;
    if (_hovered) {
      iconColor = HotstarPlayerStyle.accent;
    } else if (widget.highlight) {
      iconColor = HotstarPlayerStyle.accent;
    } else {
      iconColor = Colors.white;
    }

    return MergeSemantics(
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: Tooltip(
          message: widget.tooltip,
          decoration: HotstarPlayerStyle.tooltipDecoration,
          textStyle: Theme.of(context).textTheme.bodySmall?.merge(
            HotstarPlayerStyle.tooltipTextStyle,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          constraints: const BoxConstraints(minHeight: 28),
          preferBelow: false,
          verticalOffset: box / 2 + 8,
          // The button's declared box is its footprint. [CustomButton]
          // renders a Material 3 [TextButton], which brings
          // `minimumSize: Size(64, 40)` and 12 dp of padding a side; at 960 dp
          // television metrics that is 24 dp per button the control row does
          // not have. Zeroing it costs no touch target — the button's own
          // `_InputPadding` still pads to [kMinInteractiveDimension].
          child: TextButtonTheme(
            data: TextButtonThemeData(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
              ),
            ),
            child: MouseRegion(
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: matte
                  ? TextButton(
                      focusNode:
                          widget.focusNode ?? (_ownedFocusNode ??= FocusNode()),
                      autofocus: widget.autofocus,
                      onPressed: widget.onPressed,
                      onFocusChange: (focused) =>
                          setState(() => _focused = focused),
                      style: ButtonStyle(
                        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                        minimumSize: const WidgetStatePropertyAll(Size.zero),
                        shape: const WidgetStatePropertyAll(StadiumBorder()),
                        overlayColor: const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                        backgroundColor: const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                        shadowColor: const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                        foregroundColor: matteForeground,
                        iconColor: matteForeground,
                        side: const WidgetStatePropertyAll(BorderSide.none),
                      ),
                      child: SizedBox(
                        width: box,
                        height: box,
                        child: Icon(
                          widget.icon,
                          size: glyph,
                          // Update the glyph immediately when focus moves.
                          color: widget.onPressed == null
                              ? const Color(0x61FFFFFF)
                              : (showFocus && _focused) ||
                                    _hovered ||
                                    widget.highlight
                              ? PlayerMattePill.focusInk
                              : Colors.white,
                        ),
                      ),
                    )
                  : CustomButton(
                      onPressed: widget.onPressed,
                      showFocusHighlight: widget.isTv,
                      focusNode: widget.focusNode,
                      autofocus: widget.autofocus,
                      shape: const CircleBorder(),
                      child: SizedBox(
                        width: box,
                        height: box,
                        child: Icon(widget.icon, color: iconColor, size: glyph),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The big centred play/pause a phone or tablet expects over the video.
///
/// A second control, not a replacement: the bottom bar keeps its own
/// play/pause, whose node the chrome's focus machinery names.
///
/// Not a [CustomButton] and not a [Focus]: it holds no [FocusNode], so it is
/// not a traversal candidate and cannot compete for the autofocus the bottom
/// bar's play/pause owns on television. Built on touch only.
///
/// [HitTestBehavior.translucent] is load-bearing. The player's screen-wide
/// gesture detector is the first child of the same Stack and this glyph a
/// later one, so hit testing reaches the glyph first; opaque would stop
/// [RenderStack.defaultHitTestChildren] dead, keep the screen-wide detector
/// out of the gesture arena and kill swipe-to-seek and swipe-for-volume
/// started from the centre of the frame.
///
/// Translucent alone is not enough.
/// `RenderProxyBoxWithHitTestBehavior.hitTest` returns `hitTarget`, which is
/// true whenever a child was hit, and `RenderParagraph.hitTestSelf` returns
/// true unconditionally — so the [Icon] would make the detector answer "hit"
/// and the Stack would stop walking as if it were opaque. The disc is
/// therefore wrapped in an [IgnorePointer]: it is paint, and the gesture
/// belongs to the square around it.
///
/// The label is passed in because this file is not a localization boundary.
class PlayerCenterPlayButton extends StatelessWidget {
  /// Whether playback is running. A rebuffer counts as running, since the film
  /// resumes without a press.
  final bool playing;

  /// The localized "Play"/"Pause" the semantics layer announces.
  final String label;

  final VoidCallback onPressed;

  const PlayerCenterPlayButton({
    super.key,
    required this.playing,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // A phone gets the smaller disc; anything with a 600 dp short side is a
    // tablet held further away and takes the larger one.
    final double diameter = MediaQuery.sizeOf(context).shortestSide < 600
        ? 72
        : 88;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onPressed,
        child: IgnorePointer(
          child: SizedBox.square(
            dimension: diameter,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // A paint, not a layer: no opacity or filter here, so nothing
                // new is composited over the platform view.
                color: Colors.black.withValues(alpha: 0.34),
              ),
              // 0.52 keeps the glyph inside the disc; filling it reads as a
              // bare icon with a smudge behind it.
              child: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: diameter * 0.52,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the two seek glyphs flanking [PlayerCenterPlayButton].
///
/// Built like the disc and for the same reason: a [GestureDetector] that is
/// translucent, over an [IgnorePointer] that is only paint. An ordinary
/// [PlayerIconButton] here would be opaque, stop
/// [RenderStack.defaultHitTestChildren] dead and take the middle third of the
/// frame away from the screen-wide detector underneath - which is where
/// swipe-to-seek and swipe-for-volume are started.
///
/// No [FocusNode], again like the disc: this cluster is built on a handset
/// only, where nothing traverses, and a node here would compete for the
/// autofocus the bottom bar's play/pause owns.
class PlayerCenterSeekButton extends StatelessWidget {
  const PlayerCenterSeekButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;

  /// The localized name a screen reader announces. Passed in because this file
  /// is not a localization boundary.
  final String label;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onPressed,
        child: IgnorePointer(
          // 48 dp of target around a 30 dp glyph: the disc beside it is 72,
          // and these two are reached with the same thumb.
          child: SizedBox.square(
            dimension: 48,
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}

/// The handset's transport cluster: step back, play/pause, step forward.
///
/// Horizontally centred as a group, so the disc stays on the middle of the
/// frame and the two steps sit either side of it — the shape a thumb expects
/// and the one every phone player uses. The bottom bar keeps neither, which is
/// what leaves its left end to the episode buttons and the clock.
///
/// [onRewind] and [onForward] are null on a live edge, where a relative seek
/// does nothing; the disc is then centred alone.
class PlayerCenterControls extends StatelessWidget {
  const PlayerCenterControls({
    required this.playing,
    required this.playLabel,
    required this.onPlayPause,
    this.rewindIcon,
    this.forwardIcon,
    this.rewindLabel,
    this.forwardLabel,
    this.onRewind,
    this.onForward,
    super.key,
  });

  final bool playing;
  final String playLabel;
  final VoidCallback onPlayPause;

  final IconData? rewindIcon;
  final IconData? forwardIcon;
  final String? rewindLabel;
  final String? forwardLabel;
  final VoidCallback? onRewind;
  final VoidCallback? onForward;

  /// Between a step and the disc. Wide enough that a thumb aimed at one does
  /// not catch the other, and narrow enough that the three read as one group.
  static const double gap = 28;

  @override
  Widget build(BuildContext context) {
    final bool steps = onRewind != null && onForward != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (steps) ...<Widget>[
          PlayerCenterSeekButton(
            icon: rewindIcon!,
            label: rewindLabel!,
            onPressed: onRewind!,
          ),
          const SizedBox(width: gap),
        ],
        PlayerCenterPlayButton(
          playing: playing,
          label: playLabel,
          onPressed: onPlayPause,
        ),
        if (steps) ...<Widget>[
          const SizedBox(width: gap),
          PlayerCenterSeekButton(
            icon: forwardIcon!,
            label: forwardLabel!,
            onPressed: onForward!,
          ),
        ],
      ],
    );
  }
}

/// Labelled icon button for the controls row (Sources, Subtitles, Speed, …)
/// and for the Skip Intro/Outro chip. Activates on tap and, when focused, on
/// every key [isPlayerActivation] names — select, enter, space and a game
/// controller's A; directional navigation between buttons is handled natively
/// by the enclosing traversal group — this widget never moves focus itself.
class PlayerActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;
  final bool isTv;
  final FocusNode? focusNode;

  /// {@macro flutter.widgets.Focus.autofocus}
  final bool autofocus;

  const PlayerActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
    this.isTv = false,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  State<PlayerActionButton> createState() => _PlayerActionButtonState();
}

class _PlayerActionButtonState extends State<PlayerActionButton> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    // The ten-foot ramp: same shape, bigger numbers, matching the ramp
    // player_panel_metrics.dart applies and above the 14 sp floor it
    // documents. A 12 dp label with a 20 dp glyph is a squint from a sofa, and
    // the skip chip is the one control in the player on a clock.
    final double glyph = widget.isTv ? 26 : 20;
    final double labelSize = widget.isTv ? 18 : 12;
    final double minHeight = widget.isTv ? 52 : 44;
    final double horizontalPad = widget.isTv ? 16 : 12;

    // Focus only draws when the player is being driven without a pointer.
    // These chips sit over the video on a phone too, where a tap that happens
    // to leave focus behind should not leave a ring behind with it.
    final showFocus = showFocusIndicator(context, _focused);
    final showBg = (widget.highlight || showFocus || _pressed) && !_hovered;
    final color = (widget.highlight || _hovered || showFocus || _pressed)
        ? HotstarPlayerStyle.accent
        : Colors.white;
    final showFocusRing = showFocus;

    // [MergeSemantics], for the same reason [PlayerIconButton] carries one.
    // Without it the annotation above owns the name and the button flag while
    // the [InkWell] below owns the tap, so a reader stops on the row twice and
    // the stop that can be activated is not the one flagged as a button.
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: widget.highlight,
        label: widget.label,
        child: Focus(
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          onFocusChange: (value) => setState(() => _focused = value),
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (isPlayerActivation(event.logicalKey)) {
              widget.onTap();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() {
              _hovered = false;
              _pressed = false;
            }),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: widget.onTap,
                onHighlightChanged: _setPressed,
                borderRadius: BorderRadius.circular(8),
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                child: AnimatedContainer(
                  duration: HotstarPlayerStyle.fastMotionDuration,
                  constraints: BoxConstraints(minHeight: minHeight),
                  padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                  decoration: BoxDecoration(
                    color: showBg
                        ? HotstarPlayerStyle.accent.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    // A white ring, and no glow behind it. The accent halo
                    // that used to sit here was a second cue for the state
                    // the ring already states, and over a bright scene it
                    // read as a smear rather than as an outline.
                    border: showFocusRing
                        ? Border.all(
                            color: HotstarPlayerStyle.focusRing,
                            width: HotstarPlayerStyle.focusRingWidth,
                          )
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, color: color, size: glyph),
                      const SizedBox(width: 6),
                      // The [Semantics] above already carries this string.
                      // Once the subtree merges, an included Text makes the
                      // node read the label twice.
                      ExcludeSemantics(
                        child: Text(
                          widget.label,
                          style: TextStyle(
                            color: color,
                            fontSize: labelSize,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
