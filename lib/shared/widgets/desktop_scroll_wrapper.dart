import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/responsive_breakpoints.dart';
import '../../core/providers/device_info_provider.dart';

class DesktopScrollWrapper extends ConsumerStatefulWidget {
  final Widget child;
  final ScrollController controller;
  final double scrollAmount;
  final Future<void> Function()? onScrollLeft;
  final Future<void> Function()? onScrollRight;

  /// Whether to show navigation buttons. If null, defaults to true on desktop platforms.
  final bool? showButtons;

  /// Whether to use compact styling (smaller buttons/padding).
  final bool isCompact;

  const DesktopScrollWrapper({
    super.key,
    required this.child,
    required this.controller,
    this.scrollAmount = 300.0,
    this.onScrollLeft,
    this.onScrollRight,
    this.showButtons,
    this.isCompact = false,
  });

  @override
  ConsumerState<DesktopScrollWrapper> createState() =>
      _DesktopScrollWrapperState();
}

class _DesktopScrollWrapperState extends ConsumerState<DesktopScrollWrapper> {
  bool _showLeft = false;
  bool _showRight = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateArrows);
    // Initial check after build
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
  }

  @override
  void didUpdateWidget(DesktopScrollWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_updateArrows);
      widget.controller.addListener(_updateArrows);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateArrows);
    super.dispose();
  }

  void _updateArrows() {
    if (!widget.controller.hasClients) return;

    final position = widget.controller.position;
    final showLeft = position.pixels > 1.0;
    final showRight = position.maxScrollExtent > 1.0 &&
        position.pixels < (position.maxScrollExtent - 1.0);

    if (showLeft != _showLeft || showRight != _showRight) {
      if (mounted) {
        setState(() {
          _showLeft = showLeft;
          _showRight = showRight;
        });
      }
    }
  }

  void _scroll(bool right) {
    if (right && widget.onScrollRight != null) {
      widget.onScrollRight!();
      return;
    }
    if (!right && widget.onScrollLeft != null) {
      widget.onScrollLeft!();
      return;
    }

    if (!widget.controller.hasClients) return;

    final current = widget.controller.offset;
    final target = right
        ? current + widget.scrollAmount
        : current - widget.scrollAmount;

    widget.controller.animateTo(
      target.clamp(0.0, widget.controller.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  bool get _shouldShowButtons {
    // If running on a TV, always hide buttons (D-pad is used instead).
    // We use the profile provider for the most accurate detection.
    final profile = ref.watch(deviceProfileProvider).asData?.value;
    if (profile?.isTv == true) return false;

    // Fallback heuristic if provider is loading
    if (context.isTv) return false;

    // If explicitly set, use that value
    if (widget.showButtons != null) return widget.showButtons!;
    // Default: show on desktop platforms only
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());

    final childWithListener = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _updateArrows();
        return false;
      },
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (notification) {
          _updateArrows();
          return false;
        },
        child: widget.child,
      ),
    );

    // Only show buttons if enabled
    if (!_shouldShowButtons) {
      return childWithListener;
    }

    return Stack(
      children: [
        childWithListener,

        // Left Button
        if (_showLeft)
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _ScrollButton(
                icon: Icons.chevron_left,
                isCompact: widget.isCompact,
                onTap: () => _scroll(false),
              ),
            ),
          ),

        // Right Button
        if (_showRight)
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: _ScrollButton(
                icon: Icons.chevron_right,
                isCompact: widget.isCompact,
                onTap: () => _scroll(true),
              ),
            ),
          ),
      ],
    );
  }
}

class _ScrollButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isCompact;

  const _ScrollButton({
    required this.icon,
    required this.onTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Material(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(isCompact ? 4.0 : 8.0),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.onSurface,
              size: isCompact ? 20 : 24,
            ),
          ),
        ),
      ),
    );
  }
}
