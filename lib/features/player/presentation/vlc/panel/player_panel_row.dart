/// The parts every side-panel tab is built out of.
///
/// One rule runs through all of them: **a row is one focus stop**. No focusable
/// Radio inside a focusable tile, no InkWell wrapping a button — on a remote
/// each extra node is an extra press that lands nowhere the viewer can see, and
/// that is exactly how the old sheets made a 40-source list unusable.
///
/// So a row is a [Focus] over a [GestureDetector]: focusable once, activated by
/// tap and by Select/Enter/Space/A, and moved between by native directional
/// traversal. Anything interactive *inside* a row (the stepper's -/+ and reset
/// buttons) sits under [ExcludeFocus] and is reachable by pointer only, with
/// the row itself taking Left/Right for the D-pad.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../l10n/generated/app_localizations.dart';
import '../../widgets/hotstar_player_style.dart';
import 'player_panel_metrics.dart';
import '../../../../../shared/focus/app_focus.dart';

/// Surface behind the whole panel: obsidian glass, 75 % opaque, so the video
/// reads through it.
///
/// Translucency is free here; a *blur* is not. Alpha is one more channel in a
/// fill the panel was painting anyway, while a [BackdropFilter] over a platform
/// view is a drawer-sized effect layer read back on every repaint. See the
/// header of player_panel_shell.dart, and the compositing rules in
/// vlc_player_controls.dart.
///
/// The number has to be read together with the route's barrier, which is drawn
/// behind the drawer as well as beside it: at a 45 % barrier this leaves about
/// 14 % of the picture coming through, which is the most the glass can take and
/// still hold its text. The worst case is a white frame, where a row's label
/// still measures 13:1 and its detail line 3.4:1 — and it is the detail line,
/// not the label, that sets the floor.
const Color kPanelSurface = Color(0xBF060608);

/// [kPanelSurface] with no glass in it, for the one place a colour has to be
/// blended down onto the surface rather than drawn over it.
///
/// A badge tint alpha-blended against a translucent base comes out translucent
/// too, and a chip that lets the picture through is a chip with no edge. This
/// is the same obsidian at full strength.
const Color _kPanelSurfaceOpaque = Color(0xFF060608);

/// Row background when focused. Solid rather than a scrim so it reads at a
/// distance on a television.
const Color _kRowFocused = Color(0xFF1E2530);
const Color _kRowSelected = Color(0x141F80E0);

/// How a row shows focus, selection and hover, in that order of precedence.
BoxDecoration panelRowDecoration({
  required bool focused,
  required bool selected,
  required bool hovered,
}) {
  return BoxDecoration(
    color: focused
        ? _kRowFocused
        : (hovered
              ? const Color(0xFF151A22)
              : (selected ? _kRowSelected : Colors.transparent)),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(
      // White, like every other focus ring in the app and in the chrome. The
      // accent stays the colour of *selection*, which a row can also be.
      color: focused ? HotstarPlayerStyle.focusRing : Colors.transparent,
      width: HotstarPlayerStyle.focusRingWidth,
    ),
  );
}

/// One selectable row: a label, an optional second line, badges down the right,
/// and an optional leading widget (an episode thumbnail, an action's icon).
class PanelRow extends StatefulWidget {
  const PanelRow({
    required this.label,
    required this.onTap,
    this.detail,
    this.badges = const <String>[],
    this.badgeIcon,
    this.badgeColor,
    this.neutralBadges = false,
    this.leading,
    this.icon,
    this.selected = false,
    this.selectedLabel,
    this.selectedLabelIcon,
    this.status,
    this.statusIcon,
    this.statusColor,
    this.outcome,
    this.outcomeIcon,
    this.outcomeColor,
    this.enabled = true,
    this.autofocus = false,
    this.trailing,
    this.focusNode,
    super.key,
  });

  final String label;

  /// Second line — provider, codec, air date. Absent rather than empty.
  final String? detail;

  /// Short chips: quality, size, seeders. Rendered right-aligned in order.
  final List<String> badges;
  final IconData? badgeIcon;
  final Color? badgeColor;

  /// Give metadata and statuses a single quiet treatment in dense lists.
  final bool neutralBadges;

  /// Episode thumbnail. Takes the place of [icon] when both are given.
  final Widget? leading;

  final IconData? icon;

  /// The row the player is on now, or the track currently applied.
  final bool selected;

  /// What "selected" means here — `Now playing` for a source, nothing for a
  /// track, where the tick alone is the whole story.
  final String? selectedLabel;
  final IconData? selectedLabelIcon;

  /// Live state that is not selection: a probe result, a download marker.
  final String? status;
  final IconData? statusIcon;
  final Color? statusColor;

  /// A second live fact, drawn after [status] and never folded into it - a
  /// source that was reachable and then failed to play says both.
  final String? outcome;
  final IconData? outcomeIcon;
  final Color? outcomeColor;

  final bool enabled;

  /// Set on the row holding the current selection when the panel opens, so a
  /// D-pad lands on what it is about to change rather than on row one.
  final bool autofocus;

  final Widget? trailing;

  /// The row's focus stop, for a caller that has to hand focus back to this
  /// row later. A lazily-built list keeps a row's own node with its position,
  /// not with the row, so the node goes with the row that owns it when rows
  /// ahead of it come and go.
  final FocusNode? focusNode;

  final VoidCallback onTap;

  @override
  State<PanelRow> createState() => _PanelRowState();
}

class _PanelRowState extends State<PanelRow> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final detail = widget.detail;
    final metrics = PlayerPanelMetrics.of(context);
    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.label,
      child: Focus(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        canRequestFocus: enabled,
        onFocusChange: (value) => setState(() => _focused = value),
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.space ||
              key == LogicalKeyboardKey.gameButtonA) {
            if (enabled) widget.onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? widget.onTap : null,
            child: AnimatedContainer(
              duration: HotstarPlayerStyle.fastMotionDuration,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              padding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: metrics.rowVerticalPadding,
              ),
              decoration: panelRowDecoration(
                focused: enabled && showFocusIndicator(context, _focused),
                selected: widget.selected,
                hovered: enabled && _hovered,
              ),
              child: Row(
                children: [
                  _leading(metrics),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: enabled
                                ? HotstarPlayerStyle.primaryText
                                : metrics.mutedText,
                            fontSize: metrics.rowLabelSize,
                            height: 1.25,
                            fontWeight: widget.selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        if (detail != null && detail.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              detail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: metrics.mutedText,
                                fontSize: metrics.rowDetailSize,
                              ),
                            ),
                          ),
                        if (widget.badges.isNotEmpty ||
                            widget.status != null ||
                            widget.outcome != null ||
                            (widget.selected && widget.selectedLabel != null))
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: <Widget>[
                                if (widget.selected &&
                                    widget.selectedLabel != null)
                                  PanelBadge(
                                    text: widget.selectedLabel!,
                                    icon: widget.selectedLabelIcon,
                                    neutral: widget.neutralBadges,
                                    color: HotstarPlayerStyle.accent,
                                  ),
                                for (final badge in widget.badges)
                                  PanelBadge(
                                    text: badge,
                                    icon: widget.badgeIcon,
                                    color: widget.badgeColor,
                                    neutral: widget.neutralBadges,
                                  ),
                                if (widget.status != null)
                                  PanelBadge(
                                    text: widget.status!,
                                    icon: widget.statusIcon,
                                    neutral: widget.neutralBadges,
                                    color: widget.statusColor,
                                  ),
                                if (widget.outcome != null)
                                  PanelBadge(
                                    text: widget.outcome!,
                                    icon: widget.outcomeIcon,
                                    neutral: widget.neutralBadges,
                                    color: widget.outcomeColor,
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  ?widget.trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The tick sits where the icon would, so selected and unselected rows have
  /// their text starting in the same place and the list does not shuffle
  /// sideways as the selection moves.
  Widget _leading(PlayerPanelMetrics metrics) {
    final leading = widget.leading;
    if (leading != null) {
      return Padding(padding: const EdgeInsets.only(right: 10), child: leading);
    }
    return SizedBox(
      width: metrics.leadingSlotWidth,
      child: widget.selected
          ? Icon(
              Icons.check_rounded,
              size: metrics.iconSize,
              color: HotstarPlayerStyle.accent,
            )
          : (widget.icon == null
                ? null
                : Icon(
                    widget.icon,
                    size: metrics.iconSize,
                    color: widget.enabled
                        ? metrics.secondaryText
                        : metrics.mutedText,
                  )),
    );
  }
}

/// A small chip. Quality, size, seeders, probe state — anything short enough to
/// read at a glance from a sofa.
class PanelBadge extends StatelessWidget {
  const PanelBadge({
    required this.text,
    this.color,
    this.neutral = false,
    this.icon,
    super.key,
  });

  final String text;
  final Color? color;
  final bool neutral;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = neutral ? null : this.color;
    final metrics = PlayerPanelMetrics.of(context);
    final background = neutral
        ? const Color(0x0FFFFFFF)
        : HotstarPlayerStyle.panelElevated;
    final label = Text(
      text,
      style: TextStyle(
        color: color ?? metrics.secondaryText,
        fontSize: metrics.badgeSize,
        fontWeight: neutral ? FontWeight.w500 : FontWeight.w700,
        letterSpacing: neutral ? 0 : 0.2,
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color == null
            ? background
            : Color.alphaBlend(
                color.withValues(alpha: 0.18),
                _kPanelSurfaceOpaque,
              ),
        borderRadius: BorderRadius.circular(neutral ? 6 : 5),
        border: neutral
            ? null
            : Border.all(color: color ?? metrics.divider, width: 0.8),
      ),
      child: icon == null
          ? label
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    icon,
                    size: metrics.badgeSize + 2,
                    color:
                        this.color?.withValues(alpha: 0.8) ??
                        metrics.secondaryText,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(child: label),
              ],
            ),
    );
  }
}

/// Group label between sections of one tab.
class PanelSubheader extends StatelessWidget {
  const PanelSubheader({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final metrics = PlayerPanelMetrics.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: metrics.mutedText,
          fontSize: metrics.subheaderSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

/// How far one step of a [PanelStepperRow] should go.
///
/// A single press is [fine]; a key held down arrives as repeats and each one
/// is [coarse], so a viewer who wants to move a long way leans on the button
/// and one who wants to nudge taps it. Which durations those are is the row's
/// caller's business - the row only knows how the press arrived.
enum PanelStep { fine, coarse }

/// A value stepped with Left/Right while focused, and with the inline -/+ for
/// touch and mouse.
///
/// A slider is the wrong control for a remote: there is no thumb to grab and
/// every press is a guess at how far it moved. Steps are exact, repeatable and
/// say what they did - and a held key steps [PanelStep.coarse], so a two
/// second correction is a lean rather than twenty presses.
///
/// Every one of those affordances exists on a pointer too, because the sheet
/// this row replaced was a phone's only delay control and it stepped half a
/// second per tap. A finger held on -/+ repeats [PanelStep.coarse] exactly the
/// way a held key does, and [onReset] - the row's Select - is also a button
/// beside the value whenever there is something to reset, because a phone has
/// no Select to press.
class PanelStepperRow extends StatefulWidget {
  const PanelStepperRow({
    required this.label,
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
    this.onReset,
    this.autofocus = false,
    super.key,
  });

  final String label;
  final String value;

  /// One step down or up. [PanelStep.coarse] when the key is being held (a
  /// repeat event) or the inline button is, [PanelStep.fine] for a press and
  /// for a tap.
  final void Function(PanelStep step) onDecrease;
  final void Function(PanelStep step) onIncrease;

  /// Offered as the row's own activation: pressing Select on a stepper has
  /// nothing else useful to do, and hunting a separate Reset row with a D-pad
  /// is worse than both. Null means there is nothing to reset - the value is
  /// already at rest - and the pointer's reset button is not drawn at all.
  final VoidCallback? onReset;

  final bool autofocus;

  @override
  State<PanelStepperRow> createState() => _PanelStepperRowState();
}

class _PanelStepperRowState extends State<PanelStepperRow> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final reset = widget.onReset;
    final metrics = PlayerPanelMetrics.of(context);
    return Semantics(
      label: widget.label,
      value: widget.value,
      child: Focus(
        autofocus: widget.autofocus,
        onFocusChange: (value) => setState(() => _focused = value),
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }
          final key = event.logicalKey;
          // Left/Right are the whole point of this row, so it takes them before
          // the panel can read them as anything else - repeats included, so a
          // held key can never leak a coarse step into traversal. Up/Down fall
          // through to traversal.
          final step = event is KeyRepeatEvent
              ? PanelStep.coarse
              : PanelStep.fine;
          if (key == LogicalKeyboardKey.arrowLeft) {
            widget.onDecrease(step);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowRight) {
            widget.onIncrease(step);
            return KeyEventResult.handled;
          }
          // The same four activation keys every other stop in the panel takes
          // (PanelRow, the tab buttons, the close button): A is Select on a
          // game controller, and this row's Select is the reset.
          final onReset = widget.onReset;
          if (onReset != null &&
              event is KeyDownEvent &&
              (key == LogicalKeyboardKey.select ||
                  key == LogicalKeyboardKey.enter ||
                  key == LogicalKeyboardKey.space ||
                  key == LogicalKeyboardKey.gameButtonA)) {
            onReset();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: HotstarPlayerStyle.fastMotionDuration,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
            decoration: panelRowDecoration(
              focused: showFocusIndicator(context, _focused),
              selected: false,
              hovered: _hovered,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: HotstarPlayerStyle.primaryText,
                      fontSize: metrics.rowLabelSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // Not separately focusable: the row is one stop, and these are
                // the pointer's way in.
                ExcludeFocus(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StepButton(
                        icon: Icons.remove_rounded,
                        onStep: widget.onDecrease,
                      ),
                      SizedBox(
                        width: metrics.stepperValueWidth,
                        child: Text(
                          widget.value,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: HotstarPlayerStyle.primaryText,
                            fontSize: metrics.stepperValueSize,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                      _StepButton(
                        icon: Icons.add_rounded,
                        onStep: widget.onIncrease,
                      ),
                      // Only ever drawn with something to undo, so it is also
                      // the row's one hint that the value has been moved.
                      if (reset != null) _ResetButton(onTap: reset),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// How long a finger has to rest on -/+ before the button starts stepping by
/// itself, and how often it steps from then on.
///
/// This is a remote's key repeat, for the input a phone actually has: the same
/// [PanelStep.coarse], arrived at the same way - by leaning on the control
/// rather than by pressing it twenty times.
const Duration _kHoldRepeat = Duration(milliseconds: 400);

/// One of the stepper's inline -/+ buttons: a tap is [PanelStep.fine], a hold
/// repeats [PanelStep.coarse].
class _StepButton extends StatefulWidget {
  const _StepButton({required this.icon, required this.onStep});

  final IconData icon;
  final void Function(PanelStep step) onStep;

  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton> {
  Timer? _repeat;

  /// Whether the hold already stepped. A tap recognizer reports `onTap` on
  /// release however long the finger stayed down, so without this a hold would
  /// end with a stray fine step on top of the coarse ones.
  bool _repeated = false;

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  void _down() {
    _repeated = false;
    _repeat?.cancel();
    _repeat = Timer.periodic(_kHoldRepeat, (_) {
      _repeated = true;
      widget.onStep(PanelStep.coarse);
    });
  }

  /// Stops the repeat but leaves [_repeated] standing: `onTap` runs after this
  /// and is the one that has to know.
  void _up() => _repeat?.cancel();

  void _cancel() {
    _repeat?.cancel();
    _repeated = false;
  }

  void _tap() {
    if (_repeated) {
      _repeated = false;
      return;
    }
    widget.onStep(PanelStep.fine);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _down(),
      onTapUp: (_) => _up(),
      onTapCancel: _cancel,
      onTap: _tap,
      child: _StepIcon(icon: widget.icon),
    );
  }
}

/// The pointer's Select: what a remote does with Select on this row, for an
/// input that has no Select. Drawn only when there is something to reset.
class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: AppLocalizations.of(context)!.resetDelay,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: const _StepIcon(icon: Icons.restart_alt_rounded),
      ),
    );
  }
}

/// The glyph and the slop around it, shared so -/+ and reset are the same
/// size of target.
class _StepIcon extends StatelessWidget {
  const _StepIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final metrics = PlayerPanelMetrics.of(context);
    return Padding(
      padding: EdgeInsets.all(metrics.stepIconPadding),
      child: Icon(
        icon,
        size: metrics.iconSize,
        color: HotstarPlayerStyle.primaryText,
      ),
    );
  }
}

/// What a tab says when it has nothing to list.
class PanelEmpty extends StatelessWidget {
  const PanelEmpty({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final metrics = PlayerPanelMetrics.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
      child: Text(
        text,
        style: TextStyle(color: metrics.mutedText, fontSize: metrics.emptySize),
      ),
    );
  }
}
