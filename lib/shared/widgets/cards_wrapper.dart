import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CardsWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double scaleFactor;
  final bool autoFocus;
  final BorderRadius? borderRadius;
  final FocusNode? focusNode;

  const CardsWrapper({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.scaleFactor = 1.03,
    this.autoFocus = false,
    this.borderRadius,
    this.focusNode,
  });

  @override
  State<CardsWrapper> createState() => _CardsWrapperState();
}

class _CardsWrapperState extends State<CardsWrapper>
    with SingleTickerProviderStateMixin {
  // Lazily-built. Hundreds of cards live offscreen in long rails and never
  // get focused or hovered — creating an AnimationController for each one
  // up front wastes vsync registrations and Tween allocations.
  AnimationController? _controller;
  Animation<double>? _scaleAnimation;
  bool _isFocused = false;
  bool _isHovered = false;
  late FocusNode _node;

  /// Whether the select/enter key is currently held down.
  bool _selectKeyDown = false;

  /// Set to true once the first KeyRepeatEvent fires (OS-level long press).
  bool _longPressTriggered = false;

  @override
  void initState() {
    super.initState();
    _node = widget.focusNode ?? FocusNode();

    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _node.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant CardsWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      if (oldWidget.focusNode == null) _node.dispose();
      _node = widget.focusNode ?? FocusNode();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    if (widget.focusNode == null) {
      _node.dispose();
    } else {
      if (widget.focusNode!.hasFocus) {
        widget.focusNode!.unfocus();
      }
    }
    super.dispose();
  }

  void _ensureController() {
    if (_controller != null) return;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(parent: _controller!, curve: Curves.easeInOut));
  }

  void _updateAnimation() {
    // In D-pad/keyboard mode the border+glow is the focus indicator; skip scale
    // to prevent edge items from overflowing the viewport.
    final isDpad =
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    final shouldScale = _isHovered || (_isFocused && !isDpad);
    if (shouldScale) {
      _ensureController();
      _controller!.forward();
    } else {
      _controller?.reverse();
    }
  }

  void _onFocusChange(bool hasFocus) {
    if (!hasFocus) {
      _selectKeyDown = false;
      _longPressTriggered = false;
    }
    setState(() {
      _isFocused = hasFocus;
    });
    _updateAnimation();
    if (hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ro = context.findRenderObject();
        if (ro is! RenderBox || !ro.hasSize || !ro.attached) return;
        const duration = Duration(milliseconds: 380);
        const curve = Curves.fastOutSlowIn;

        // Horizontal: always center the focused card inside its row so the
        // active card stays in the middle of the screen as the user walks
        // along the row.
        Scrollable.maybeOf(
          context,
          axis: Axis.horizontal,
        )?.position.ensureVisible(
          ro,
          alignment: 0.5,
          duration: duration,
          curve: curve,
        );

        // Vertical: only scroll if the row is actually clipped. Target the
        // horizontal parent scrollable row's RenderObject to prevent
        // horizontal animation coordinate mutations from fighting with
        // vertical scrolling, which causes screen jitter/jumping.
        final vScroll = Scrollable.maybeOf(context, axis: Axis.vertical);
        if (vScroll != null && vScroll.context.mounted) {
          final scrollBox = vScroll.context.findRenderObject();
          if (scrollBox is RenderBox && scrollBox.hasSize && scrollBox.attached) {
            final hScroll = Scrollable.maybeOf(context, axis: Axis.horizontal);
            final targetContext = (hScroll != null && hScroll.context.mounted)
                ? hScroll.context
                : context;
            final targetRo = targetContext.findRenderObject();
            if (targetRo is RenderBox && targetRo.hasSize && targetRo.attached) {
              try {
                final top = targetRo
                    .localToGlobal(Offset.zero, ancestor: scrollBox)
                    .dy;
                final bottom = top + targetRo.size.height;
                final viewportH = scrollBox.size.height;
                if (top < 0 || bottom > viewportH) {
                  vScroll.position.ensureVisible(
                    targetRo,
                    alignment: 0.5,
                    duration: duration,
                    curve: curve,
                  );
                }
              } catch (_) {}
            }
          }
        }
      });
    }
  }

  void _onHover(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });
    _updateAnimation();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      onFocusChange: _onFocusChange,
      onKeyEvent: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space) {
          if (event is KeyDownEvent) {
            if (widget.onLongPress == null) {
              // No long-press handler — fire tap immediately.
              widget.onTap();
              return KeyEventResult.handled;
            }
            // Start tracking the press; don't fire anything yet.
            _selectKeyDown = true;
            _longPressTriggered = false;
            return KeyEventResult.handled;
          } else if (event is KeyRepeatEvent) {
            // The OS fires KeyRepeatEvent after the platform key-repeat
            // delay (~500 ms). Treat the first repeat as a long press.
            if (_selectKeyDown &&
                !_longPressTriggered &&
                widget.onLongPress != null) {
              _longPressTriggered = true;
              widget.onLongPress!();
            }
            return KeyEventResult.handled;
          } else if (event is KeyUpEvent) {
            // Short press: no repeat was received before release → tap.
            if (_selectKeyDown && !_longPressTriggered) {
              widget.onTap();
            }
            _selectKeyDown = false;
            _longPressTriggered = false;
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) => _onHover(true),
        onExit: (_) => _onHover(false),
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: Builder(
            builder: (context) {
              final card = Container(
                decoration: BoxDecoration(
                  borderRadius:
                      widget.borderRadius ?? BorderRadius.circular(12),
                  border:
                      (_isFocused &&
                          FocusManager.instance.highlightMode ==
                              FocusHighlightMode.traditional)
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        )
                      : null,
                ),
                child: widget.child,
              );
              final animation = _scaleAnimation;
              if (animation == null) return card;
              return ScaleTransition(scale: animation, child: card);
            },
          ),
        ),
      ),
    );
  }
}
