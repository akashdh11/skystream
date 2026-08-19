import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skystream/core/providers/device_info_provider.dart';
import 'package:skystream/core/services/notification_service.dart';

/// Exact Material 3 Expressive animation curves & timings.
class ToastCurves {
  /// Main entrance pop-in curve: cubic-bezier(0.38, 1.21, 0.22, 1.00)
  /// Features an energetic, snappy pop-in with subtle overshoot settling into place.
  static const Curve expressiveDefaultSpatial = Cubic(0.38, 1.21, 0.22, 1.00);

  /// Fast snappy bounce for small icons/badges: cubic-bezier(0.42, 1.67, 0.21, 0.90)
  static const Curve expressiveFastSpatial = Cubic(0.42, 1.67, 0.21, 0.90);

  /// Exit / Dismiss curve: cubic-bezier(0.05, 0.70, 0.10, 1.00)
  /// Immediate smooth deceleration without bounce.
  static const Curve emphasizedDecel = Cubic(0.05, 0.70, 0.10, 1.00);
}

/// A global Material Design 3 Expressive Toast Overlay widget.
/// Renders stacked floating capsule / card toasts on Desktop, TV, and Mobile.
class M3ToastOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const M3ToastOverlay({super.key, required this.child});

  @override
  ConsumerState<M3ToastOverlay> createState() => _M3ToastOverlayState();
}

class _M3ToastOverlayState extends ConsumerState<M3ToastOverlay> {
  @override
  Widget build(BuildContext context) {
    final notificationService = ref.watch(notificationServiceProvider);
    final profile = ref.watch(deviceProfileProvider).asData?.value;
    final isDesktopOrTv =
        (profile?.isDesktopOS ?? false) ||
        (profile?.isTv ?? false) ||
        MediaQuery.sizeOf(context).width >= 720;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned.fill(
          child: ListenableBuilder(
            listenable: notificationService,
            builder: (context, _) {
              final toasts = notificationService.toasts;
              if (toasts.isEmpty) {
                return const SizedBox.shrink();
              }

              return IgnorePointer(
                ignoring: false,
                child: SafeArea(
                  child: Align(
                    alignment: isDesktopOrTv
                        ? Alignment.bottomRight
                        : Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: isDesktopOrTv ? 24 : 16,
                        right: isDesktopOrTv ? 24 : 16,
                        bottom: isDesktopOrTv ? 24 : 16,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 360,
                          minWidth: 160,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: isDesktopOrTv
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.center,
                          children: [
                            for (int i = 0; i < toasts.length; i++) ...[
                              if (i > 0) const SizedBox(height: 10),
                              _M3ToastCard(
                                key: ValueKey(toasts[i].id),
                                item: toasts[i],
                                onDismiss: () => notificationService
                                    .dismissToast(toasts[i].id),
                                onHoverStart: () => notificationService
                                    .pauseTimer(toasts[i].id),
                                onHoverEnd: () => notificationService
                                    .resumeTimer(toasts[i].id),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _M3ToastCard extends StatefulWidget {
  final ToastItem item;
  final VoidCallback onDismiss;
  final VoidCallback onHoverStart;
  final VoidCallback onHoverEnd;

  const _M3ToastCard({
    super.key,
    required this.item,
    required this.onDismiss,
    required this.onHoverStart,
    required this.onHoverEnd,
  });

  @override
  State<_M3ToastCard> createState() => _M3ToastCardState();
}

class _M3ToastCardState extends State<_M3ToastCard>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _iconBounceController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _iconScaleAnimation;

  bool _isExiting = false;

  @override
  void initState() {
    super.initState();

    // Entrance controller (420ms)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    // Icon bounce controller (300ms)
    _iconBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: ToastCurves.expressiveDefaultSpatial,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: ToastCurves.expressiveDefaultSpatial,
          ),
        );

    _iconScaleAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconBounceController,
        curve: ToastCurves.expressiveFastSpatial,
      ),
    );

    _entranceController.forward();
    _iconBounceController.forward();
  }

  Future<void> _handleDismiss() async {
    if (_isExiting) return;
    _isExiting = true;

    // Exit animation with emphasizedDecel (220ms)
    _entranceController.duration = const Duration(milliseconds: 220);
    await _entranceController.reverse();
    if (mounted) {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _iconBounceController.dispose();
    super.dispose();
  }

  Color _getPrimaryColor(ThemeData theme) {
    switch (widget.item.type) {
      case ToastType.success:
        return const Color(0xFF81C784); // M3 Success Mint / Emerald
      case ToastType.error:
        return const Color(0xFFFF8A80); // M3 Error Coral / Soft Red
      case ToastType.extension:
        return const Color(0xFFD0BCFF); // M3 Lilac / Extension Accent
      case ToastType.info:
        return theme.colorScheme.primary;
    }
  }

  IconData _getDefaultIcon() {
    switch (widget.item.type) {
      case ToastType.success:
        return Icons.check_circle_rounded;
      case ToastType.error:
        return Icons.error_outline_rounded;
      case ToastType.extension:
        return Icons.extension_rounded;
      case ToastType.info:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = _getPrimaryColor(theme);
    final iconData = widget.item.icon ?? _getDefaultIcon();

    // M3 dynamic tokens
    final surfaceColor = isDark
        ? const Color(0xD9211E29) // rgba(33, 30, 41, 0.85)
        : theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.92);

    final borderColor = isDark
        ? const Color(0x1FFFFFFF) // rgba(255, 255, 255, 0.12)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.40);

    return MouseRegion(
      onEnter: (_) => widget.onHoverStart(),
      onExit: (_) => widget.onHoverEnd(),
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _handleDismiss,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 160,
                    maxWidth: 360,
                  ),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: borderColor, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.35 : 0.15,
                        ),
                        blurRadius: 16,
                        spreadRadius: 0,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Primary Icon / Leading Widget with fast snappy bounce
                            ScaleTransition(
                              scale: _iconScaleAnimation,
                              child:
                                  widget.item.leading ??
                                  Icon(iconData, size: 22, color: primaryColor),
                            ),
                            const SizedBox(width: 12),

                            // Content (Title + Body / Subtitle)
                            Flexible(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.item.title != null &&
                                      widget.item.title!.isNotEmpty) ...[
                                    Text(
                                      widget.item.title!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark
                                            ? const Color(0xFFE6E1E5)
                                            : theme.colorScheme.onSurface,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.item.message,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark
                                            ? const Color(0xFFCAC4D0)
                                            : theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        height: 1.2,
                                      ),
                                    ),
                                  ] else ...[
                                    Text(
                                      widget.item.message,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark
                                            ? const Color(0xFFE6E1E5)
                                            : theme.colorScheme.onSurface,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Action button if available
                            if (widget.item.actionLabel != null &&
                                widget.item.onAction != null) ...[
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () {
                                  widget.item.onAction!();
                                  _handleDismiss();
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  foregroundColor: primaryColor,
                                ),
                                child: Text(
                                  widget.item.actionLabel!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
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
