import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AnimeLogoPainter extends CustomPainter {
  final Color color;

  AnimeLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * (15 / 66)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter;

    final path = Path()
      ..moveTo(size.width * (8 / 66), size.height * (8.05571 / 65))
      ..quadraticBezierTo(
        size.width * (54.9009 / 66),
        size.height * (18.1782 / 65),
        size.width * (57.8687 / 66),
        size.height * (30.062 / 65),
      )
      ..quadraticBezierTo(
        size.width * (9.05432 / 66),
        size.height * (57.4696 / 65),
        size.width * (9.05432 / 66),
        size.height * (57.4696 / 65),
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TmdbLogoPainter extends CustomPainter {
  final Color color;
  final Color textColor;

  TmdbLogoPainter({required this.color, this.textColor = Colors.black});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, h * 0.1, w, h * 0.8),
      Radius.circular(w * 0.22),
    );
    canvas.drawRRect(rrect, paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'TMDB',
        style: TextStyle(
          color: textColor,
          fontSize: h * 0.36,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((w - textPainter.width) / 2, (h - textPainter.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HoverBorderGradient extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double durationSeconds;
  final bool clockwise;
  final FocusNode? focusNode;

  const HoverBorderGradient({
    super.key,
    required this.child,
    required this.onTap,
    this.durationSeconds = 4.0,
    this.clockwise = true,
    this.focusNode,
  });

  @override
  State<HoverBorderGradient> createState() => _HoverBorderGradientState();
}

class _HoverBorderGradientState extends State<HoverBorderGradient>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  FocusNode? _focusNode;
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (widget.durationSeconds * 1000).toInt()),
    )..repeat();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode!.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode!.hasFocus;
      });
    }
  }

  @override
  void didUpdateWidget(covariant HoverBorderGradient oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode?.removeListener(_onFocusChange);
      if (oldWidget.focusNode == null) {
        _focusNode?.dispose();
      }
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode!.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    _focusNode?.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode?.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isActive = _isHovered || _isFocused;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.space) {
            widget.onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final angle =
                  _controller.value * 2 * math.pi * (widget.clockwise ? 1 : -1);

              final borderColors = isActive
                  ? [
                      const Color(0xFF3275F8),
                      const Color(0xFF3275F8).withValues(alpha: 0.5),
                      Colors.white.withValues(alpha: 0.8),
                      const Color(0xFF3275F8).withValues(alpha: 0.2),
                      Colors.transparent,
                      const Color(0xFF3275F8),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.8),
                      Colors.white.withValues(alpha: 0.2),
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.2),
                      Colors.white.withValues(alpha: 0.8),
                    ];

              return Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFF3275F8,
                            ).withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                      : [],
                  gradient: SweepGradient(
                    center: Alignment.center,
                    transform: GradientRotation(angle),
                    colors: borderColors,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    color: isDark ? Colors.black : Colors.white,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: widget.child,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
