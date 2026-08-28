import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/layout_constants.dart';

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
            activeColor:
                widget.activeColor ??
                (_isFocused ? Theme.of(context).colorScheme.primary : null),
            inactiveColor: widget.inactiveColor,
          ),
        ),
      ),
    );
  }
}

/// A TextField widget that allows D-pad navigation out of the text field.
/// Up/Down D-pad navigates to other focusable elements instead of being trapped.
/// When keyboard OK is pressed, focus automatically moves to the next element.
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
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final key = event.logicalKey;

        // Use sequential focus traversal for D-pad Up/Down instead of spatial.
        // Spatial traversal (focusInDirection) is erratic in complex dialogs.
        if (key == LogicalKeyboardKey.arrowUp) {
          _focusNode.previousFocus();
          return KeyEventResult.handled;
        }

        if (key == LogicalKeyboardKey.arrowDown) {
          _focusNode.nextFocus();
          return KeyEventResult.handled;
        }

        // Let left/right pass through for text cursor navigation
        return KeyEventResult.ignored;
      },
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
  // Tracks whether focus was last driven by keyboard/D-pad (traditional) vs a
  // touch tap, so the focus ring only appears for directional navigation.
  FocusHighlightMode _highlightMode = FocusManager.instance.highlightMode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusListener = () {
      if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
    };
    _focusNode.addListener(_focusListener);
    FocusManager.instance.addHighlightModeListener(_onHighlightModeChange);
  }

  void _onHighlightModeChange(FocusHighlightMode mode) {
    if (mounted) setState(() => _highlightMode = mode);
  }

  @override
  void dispose() {
    // Always remove the listener; the node may be owned by the parent, in
    // which case it outlives this state and would otherwise hold a reference
    // to a disposed closure target.
    _focusNode.removeListener(_focusListener);
    FocusManager.instance.removeHighlightModeListener(_onHighlightModeChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    // Show the focus ring only when navigating by keyboard/remote — never for a
    // touch tap that incidentally moves focus to the button.
    final showHighlight =
        widget.showFocusHighlight &&
        _isFocused &&
        _highlightMode != FocusHighlightMode.touch;

    Widget core;
    if (widget.isPrimary) {
      core = FilledButton(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onPressed: widget.onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: showHighlight
              // On focus, brighten the primary fill so it pops against the dark
              // background and the white outline contrasts clearly.
              ? Color.lerp(primaryColor, Colors.white, 0.18)
              : (widget.backgroundColor ?? primaryColor),
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          disabledBackgroundColor: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.38),
          // No inner side on focus — the outer accent ring (below) is the
          // focus indicator. Mixing both produced double rings.
          side: BorderSide.none,
          shadowColor: Colors.transparent,
          shape: widget.shape,
          overlayColor: Colors.transparent,
        ),
        child: widget.child,
      );
    } else {
      core = TextButton(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onPressed: widget.onPressed,
        style: TextButton.styleFrom(
          backgroundColor: showHighlight
              // Fill the button on focus so a "grey" outlined button no longer
              // looks identical to its non-focused state.
              ? primaryColor.withValues(alpha: 0.28)
              : null,
          foregroundColor: _isFocused
              ? Theme.of(context).colorScheme.onSurface
              : Theme.of(context).colorScheme.onSurfaceVariant,
          disabledForegroundColor: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.38),
          side: widget.isOutlined
              ? BorderSide(color: Theme.of(context).colorScheme.outline)
              : BorderSide.none,
          shape: widget.shape,
          overlayColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        child: widget.child,
      );
    }

    // Outer focus ring — accent border + subtle glow.
    // Geometry mirrors the inner button's shape so the ring traces the
    // button correctly for circles, pills, and rounded rectangles.
    final shape = widget.shape;
    final BoxShape outerShape;
    final BorderRadius? outerBorderRadius;
    if (shape is CircleBorder) {
      outerShape = BoxShape.circle;
      outerBorderRadius = null;
    } else if (shape is StadiumBorder) {
      outerShape = BoxShape.rectangle;
      outerBorderRadius = BorderRadius.circular(999);
    } else if (shape is RoundedRectangleBorder) {
      outerShape = BoxShape.rectangle;
      final inner = shape.borderRadius;
      outerBorderRadius = inner is BorderRadius
          ? inner
          : BorderRadius.circular(12);
    } else {
      // No explicit shape → Material 3 buttons default to a pill (StadiumBorder),
      // so trace a fully-rounded ring rather than a squarish 12px corner.
      outerShape = BoxShape.rectangle;
      outerBorderRadius = BorderRadius.circular(999);
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        shape: outerShape,
        borderRadius: outerBorderRadius,
        // Accent ring + glow (the keyboard/D-pad focus cue).
        border: showHighlight
            ? Border.all(color: primaryColor, width: 2)
            : null,
        boxShadow: showHighlight
            ? [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.6),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: core,
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: _isFocused
              ? Border.all(color: cs.primary, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
        ),
        child: ExcludeFocus(
          child: Switch(
            value: widget.value,
            onChanged: widget.onChanged,
            thumbIcon: WidgetStateProperty.resolveWith((states) {
              if (_isFocused) {
                return Icon(
                  widget.value ? Icons.check_rounded : Icons.close_rounded,
                  size: 14,
                );
              }
              return null;
            }),
          ),
        ),
      ),
    );
  }
}
