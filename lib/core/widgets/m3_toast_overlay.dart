import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skystream/core/router/app_router.dart';
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
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = ref.read(appRouterProvider);
    if (_router != router) {
      _router?.routerDelegate.removeListener(_onRouteChanged);
      _router = router;
      _router?.routerDelegate.addListener(_onRouteChanged);
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _onRouteChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final notificationService = ref.watch(notificationServiceProvider);
    final router = ref.watch(appRouterProvider);
    // Corner-anchored toasts are a size decision: under 720 dp there is no
    // corner worth aiming at, over it there is - on a desktop window, a
    // tablet or a television alike. The two device clauses that used to be
    // OR-ed in here could only ever disagree with the width in the one case
    // where the width was already right: a desktop window dragged narrow,
    // which got a corner treatment in a window with no room for one.
    final isWideLayout = MediaQuery.sizeOf(context).width >= 720;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!playerRouteIsOnTop(router))
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
                        alignment: isWideLayout
                            ? Alignment.bottomRight
                            : Alignment.bottomCenter,
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: isWideLayout ? 24 : 16,
                            right: isWideLayout ? 24 : 16,
                            bottom: isWideLayout ? 24 : 16,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 360,
                              minWidth: 160,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: isWideLayout
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
  /// What a screen reader gets from this card, and the only thing it will
  /// ever get: the card takes itself away after 3-4 s, so nobody can find it
  /// by exploration - it has to speak when it arrives. That is what a live
  /// region is for, and it is what the framework tells you to use here:
  /// `SemanticsService.announce` is deprecated in this SDK
  /// (semantics_service.dart:51) and Android deprecated the announcement
  /// event it maps to, because it clears TalkBack's speech queue mid-sentence.
  /// A live region is polite - it waits its turn - so a run of toasts reads as
  /// a queue rather than as an interruption of whatever the user is doing.
  ///
  /// The two [Text]s below are excluded so this node carries one label instead
  /// of spawning children the region itself cannot speak; '\n' is the join the
  /// framework itself uses when it merges labels.
  String get _announcement {
    final String? title = widget.item.title;
    return title == null || title.isEmpty
        ? widget.item.message
        : '$title\n${widget.item.message}';
  }

  /// Whether a mouse is inside the card, i.e. whether the dismiss timer is
  /// paused on our account. Which, not whether it was ever entered: an enter
  /// with no matching exit is exactly the leak [dispose] closes.
  bool _hovered = false;

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

  void _hoverStart() {
    if (_hovered) return;
    _hovered = true;
    widget.onHoverStart();
  }

  void _hoverEnd() {
    if (!_hovered) return;
    _hovered = false;
    widget.onHoverEnd();
  }

  @override
  void dispose() {
    // Flutter does not deliver [MouseRegion.onExit] when the region is
    // unmounted with the pointer still inside it (widgets/basic.dart: exit
    // "is __not__ triggered by ... this widget, which is being hovered by a
    // pointer, has disappeared"), and the documented mitigation is to call it
    // from dispose - the same reason _HoverChromeHoldState does
    // (vlc_player_controls.dart:2298). Without this, a card hovered as the
    // viewer opens the player - where the whole layer stands down - never
    // resumes its dismiss timer, so the toast is still in the queue when they
    // come back, permanently, with a live InkWell over the page eating the
    // clicks aimed beneath it.
    _hoverEnd();
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
      onEnter: (_) => _hoverStart(),
      onExit: (_) => _hoverEnd(),
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
                              child: Semantics(
                                container: true,
                                liveRegion: true,
                                label: _announcement,
                                child: ExcludeSemantics(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
