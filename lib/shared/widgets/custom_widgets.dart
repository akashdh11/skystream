import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/layout_constants.dart';
import '../focus/app_focus.dart';

/// A Slider widget that handles D-pad navigation properly on TV.
/// Left/Right D-pad adjusts the value, Up/Down D-pad navigates to other focusable elements.
class CustomSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final double step;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final Color? activeColor;
  final Color? inactiveColor;
  final FocusNode? focusNode;
  final VoidCallback? onArrowUp;
  final VoidCallback? onArrowDown;

  /// When false the slider is removed from focus traversal entirely (it can't be
  /// focused and doesn't intercept arrow keys). Use when the value is driven by
  /// external −/+ controls and the slider is just a visual indicator.
  final bool focusable;

  const CustomSlider({
    super.key,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.step = 1.0,
    this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.activeColor,
    this.inactiveColor,
    this.focusNode,
    this.onArrowUp,
    this.onArrowDown,
    this.focusable = true,
  });

  @override
  State<CustomSlider> createState() => _CustomSliderState();
}

class _CustomSliderState extends State<CustomSlider> {
  late final FocusNode _focusNode;
  bool _isFocused = false;
  bool _isDragging = false;
  Timer? _seekCommitTimer;
  late final VoidCallback _focusListener;

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
      _isDragging = true;
      widget.onChangeStart?.call(newValue);
    }
    widget.onChanged?.call(newValue);

    _seekCommitTimer?.cancel();
    _seekCommitTimer = Timer(const Duration(milliseconds: 500), () {
      widget.onChangeEnd?.call(newValue);
      _isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      canRequestFocus: widget.focusable,
      skipTraversal: !widget.focusable,
      onKeyEvent: (node, event) {
        if (!widget.focusable) return KeyEventResult.ignored;
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

        // Up arrow: move focus up — operate on our own node so traversal is
        // anchored to the slider and not to whatever happens to be the
        // enclosing FocusScope.
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
      child: Builder(
        builder: (context) {
          // The ring is for whoever is driving this with a remote or a
          // keyboard. A finger dragging the thumb focuses the slider too, and
          // a border appearing under the thumb mid-drag is noise.
          final show = showFocusIndicator(context, _isFocused);
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              // A transparent border of the same width in the other state, so
              // the track does not shift sideways as focus arrives.
              border:
                  AppFocus.border(context, focused: show) ??
                  Border.all(color: Colors.transparent, width: AppFocus.ringWidth),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: LayoutConstants.spacingXs,
              vertical: 4,
            ),
            child: ExcludeFocus(
              child: Slider(
                value: widget.value.clamp(widget.min, widget.max),
                min: widget.min,
                max: widget.max,
                divisions: widget.divisions,
                onChanged: widget.onChanged,
                onChangeStart: widget.onChangeStart,
                onChangeEnd: widget.onChangeEnd,
                activeColor: widget.activeColor,
                inactiveColor: widget.inactiveColor,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A TextField widget that leaves the D-pad entirely to text entry.
///
/// On Android TV the leanback IME needs all four arrow keys to walk its
/// letter grid while the field is focused, so this widget must not
/// intercept a single direction. The old up/down -> previous/next focus
/// dropped focus out of the field mid-word and stranded the remote user on
/// one letter of the keyboard. Focus moves out the normal way (the clear
/// button, the surrounding controls), and Enter / numpad-Enter submits
/// through [onSubmitted].
class CustomTextField extends StatefulWidget {
  final TextEditingController? controller;
  final InputDecoration? decoration;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? hintText;
  final bool obscureText;
  final TextInputType? keyboardType;

  const CustomTextField({
    super.key,
    this.controller,
    this.decoration,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      // No arrow handling at all. The leanback IME uses all four directions
      // to walk its letter grid while this field is focused, and returning
      // `handled` for up/down used to steal the key, move focus out of the
      // field and kill the keyboard mid-word. Left/right still reach the
      // text caret through the framework's own editing shortcuts, and
      // Enter / numpad-Enter submit through [CustomTextField.onSubmitted].
      onKeyEvent: (node, event) => KeyEventResult.ignored,
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Define consistent premium borders for the project
    final enabledBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: colorScheme.outline.withValues(alpha: 0.5),
        width: 1,
      ),
    );

    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colorScheme.primary, width: 2),
    );

    // Merge the provided decoration with our consistent styling
    final effectiveDecoration = (widget.decoration ?? const InputDecoration())
        .copyWith(
          hintText: widget.hintText ?? widget.decoration?.hintText,
          enabledBorder: widget.decoration?.enabledBorder ?? enabledBorder,
          focusedBorder: widget.decoration?.focusedBorder ?? focusedBorder,
          border: widget.decoration?.border ?? enabledBorder,
        );

    return TextField(
      focusNode: _focusNode,
      controller: widget.controller,
      decoration: effectiveDecoration,
      autofocus: widget.autofocus,
      textInputAction: widget.textInputAction ?? TextInputAction.done,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      onSubmitted: (value) {
        // Call user callback first — it may navigate away or close a host
        // dialog, so bail out if we got unmounted before moving focus.
        widget.onSubmitted?.call(value);
        if (mounted) {
          _focusNode.nextFocus();
        }
      },
    );
  }
}

/// A styled button for TV that shows focus state clearly with proper Material Design styling.
class CustomButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool autofocus;
  final bool isPrimary;
  final bool isOutlined;
  final FocusNode? focusNode;
  final Color? backgroundColor;
  final OutlinedBorder? shape;
  final bool showFocusHighlight;

  const CustomButton({
    super.key,
    required this.child,
    this.onPressed,
    this.autofocus = false,
    this.isPrimary = false,
    this.isOutlined = false,
    this.focusNode,
    this.backgroundColor,
    this.shape,
    this.showFocusHighlight = true,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  late FocusNode _focusNode;
  bool _isFocused = false;
  late final VoidCallback _focusListener;

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
    // Always remove the listener; the node may be owned by the parent, in
    // which case it outlives this state and would otherwise hold a reference
    // to a disposed closure target.
    _focusNode.removeListener(_focusListener);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // One ring, and only for whoever is driving the app without a pointer.
    // What used to be here was an accent border, an accent fill *and* a 24 dp
    // accent glow with 2 dp of spread - three cues for one state, and the one
    // the details page wore the moment it opened, on every platform.
    final show = showFocusIndicator(context, _isFocused);
    final side = AppFocus.side(context, focused: show);

    if (widget.isPrimary) {
      return FilledButton(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onPressed: widget.onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: widget.backgroundColor ?? colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: colorScheme.onSurface.withValues(
            alpha: 0.12,
          ),
          disabledForegroundColor: colorScheme.onSurface.withValues(
            alpha: 0.38,
          ),
          // Outside the pill: a near-white line inside an accent fill is
          // technically present and unreadable from a sofa, and on the page's
          // own background the same line reads at ten feet.
          side: widget.showFocusHighlight ? side : BorderSide.none,
          shadowColor: Colors.transparent,
          shape: widget.shape,
          overlayColor: Colors.transparent,
        ),
        child: widget.child,
      );
    }

    return TextButton(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onPressed: widget.onPressed,
      style: TextButton.styleFrom(
        // A flat button has no fill to put a ring against, so focus also
        // lifts the label to the full foreground colour and lays a neutral
        // wash behind it - the same wash every other focused row gets.
        backgroundColor: show
            ? AppFocus.rowTint(context, focused: true)
            : null,
        foregroundColor: show
            ? colorScheme.onSurface
            : colorScheme.onSurfaceVariant,
        disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
        side: widget.showFocusHighlight && show
            ? side
            : (widget.isOutlined
                  ? BorderSide(color: colorScheme.outline)
                  : BorderSide.none),
        shape: widget.shape,
        overlayColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      child: widget.child,
    );
  }
}

/// A Switch widget with clean D-pad focus border and thumb tick-mark icon.
class CustomSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final FocusNode? focusNode;
  final bool autofocus;

  const CustomSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  State<CustomSwitch> createState() => _CustomSwitchState();
}

class _CustomSwitchState extends State<CustomSwitch> {
  late FocusNode _focusNode;
  bool _isFocused = false;
  late final VoidCallback _focusListener;

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
  void didUpdateWidget(covariant CustomSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_focusListener);
      if (oldWidget.focusNode == null) _focusNode.dispose();
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_focusListener);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_focusListener);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;

    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      canRequestFocus: enabled,
      onKeyEvent: (node, event) {
        if (!enabled) return KeyEventResult.ignored;
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onChanged!(!widget.value);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final show = showFocusIndicator(context, _isFocused);
          return AnimatedContainer(
            duration: AppFocus.duration,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              // Same width in both states so the switch does not jump.
              border:
                  AppFocus.border(context, focused: show) ??
                  Border.all(color: Colors.transparent, width: AppFocus.ringWidth),
            ),
            child: ExcludeFocus(
              child: Switch(
                value: widget.value,
                onChanged: widget.onChanged,
                thumbIcon: WidgetStateProperty.resolveWith((states) {
                  if (show) {
                    return Icon(
                      widget.value ? Icons.check_rounded : Icons.close_rounded,
                      size: 14,
                    );
                  }
                  return null;
                }),
              ),
            ),
          );
        },
      ),
    );
  }
}
