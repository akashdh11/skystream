import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';
import 'package:skystream/core/utils/layout_constants.dart';

/// Global provider to track whether the D-pad/keyboard navigation mode is active.
/// This prevents cursor hover magnification from fighting with focus magnification,
/// especially during focus resets or Alt+Tab.
class DpadActiveNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool val) => state = val;
}

final isDpadActiveProvider = NotifierProvider<DpadActiveNotifier, bool>(
  DpadActiveNotifier.new,
);

/// Number of destinations rendered by [AppSidebar].
const int kSidebarDestinationCount = 5;

/// Piecewise linear mapping for the container size (distance -150 to 150 maps to 40 to 80 to 40)
double calculateContainerSize(double distance) {
  final d = distance.clamp(-150.0, 150.0);
  if (d < 0) {
    return 40.0 + 40.0 * (1.0 + d / 150.0);
  } else {
    return 80.0 - 40.0 * (d / 150.0);
  }
}

/// Piecewise linear mapping for the icon size (distance -150 to 150 maps to 20 to 40 to 20)
double calculateIconSize(double distance) {
  final d = distance.clamp(-150.0, 150.0);
  if (d < 0) {
    return 20.0 + 20.0 * (1.0 + d / 150.0);
  } else {
    return 40.0 - 20.0 * (d / 150.0);
  }
}

class AppSidebar extends ConsumerStatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onItemTapped;
  final List<FocusNode> focusNodes;

  const AppSidebar({
    super.key,
    required this.currentIndex,
    required this.onItemTapped,
    required this.focusNodes,
  });

  @override
  ConsumerState<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends ConsumerState<AppSidebar> {
  late final ValueNotifier<double> _mouseY;
  int? _focusedIndex;

  @override
  void initState() {
    super.initState();
    _mouseY = ValueNotifier(double.infinity);
    for (int i = 0; i < widget.focusNodes.length; i++) {
      widget.focusNodes[i].addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    _mouseY.dispose();
    for (int i = 0; i < widget.focusNodes.length; i++) {
      widget.focusNodes[i].removeListener(_onFocusChanged);
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(AppSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNodes != widget.focusNodes) {
      for (final node in oldWidget.focusNodes) {
        node.removeListener(_onFocusChanged);
      }
      for (final node in widget.focusNodes) {
        node.addListener(_onFocusChanged);
      }
    }
  }

  void _onFocusChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      int? currentFocused;
      for (int i = 0; i < widget.focusNodes.length; i++) {
        if (widget.focusNodes[i].hasFocus) {
          currentFocused = i;
          break;
        }
      }
      if (_focusedIndex != currentFocused) {
        setState(() {
          _focusedIndex = currentFocused;
          // If focus changed and mouse is not hovering, we are in D-pad mode!
          if (currentFocused != null && _mouseY.value == double.infinity) {
            ref
                .read<DpadActiveNotifier>(isDpadActiveProvider.notifier)
                .set(true);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Watch the global D-pad mode provider
    final isDpadMode = ref.watch<bool>(isDpadActiveProvider);

    final destinations = [
      (Icons.home_outlined, Icons.home, l10n.home),
      (Icons.search, Icons.search, l10n.search),
      (Icons.explore_outlined, Icons.explore, l10n.explore),
      (Icons.video_library_outlined, Icons.video_library, l10n.library),
      (Icons.settings_outlined, Icons.settings, l10n.settings),
    ];
    assert(
      destinations.length == kSidebarDestinationCount,
      'kSidebarDestinationCount must match the destinations list length',
    );
    assert(
      widget.focusNodes.length == destinations.length,
      'Sidebar focusNodes count must match destinations count',
    );

    // Fixed width container (w-16 -> 64px)
    const double dockWidth = 64.0;

    // Static unscaled Y coordinates of the item centers for calculating distance
    // Top padding = 16.0, Item base size = 40.0, Gap = 16.0
    const unscaledCenters = [36.0, 92.0, 148.0, 204.0, 260.0];

    // Outer container colors matching bg-gray-50 / dark:bg-neutral-900 verbatim
    final dockBgColor = isDark
        ? const Color(0xFF171717)
        : const Color(0xFFF9FAFB);
    final dockBorderColor = isDark
        ? const Color(0xFF262626)
        : const Color(0xFFE5E7EB);

    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.none,
      child: Container(
        width: LayoutConstants.sidebarWidthCompact, // 80.0
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        child: ValueListenableBuilder<double>(
          valueListenable: _mouseY,
          builder: (context, mouseYValue, child) {
            // 1. Calculate individual target sizes dynamically based on distance
            final itemSizes = List<double>.filled(destinations.length, 40.0);
            final iconSizes = List<double>.filled(destinations.length, 20.0);

            for (int i = 0; i < destinations.length; i++) {
              double distance = 150.0;
              if (mouseYValue != double.infinity) {
                distance = mouseYValue - unscaledCenters[i];
              } else if (_focusedIndex != null && isDpadMode) {
                final diff = (i - _focusedIndex!).abs();
                if (diff == 0) {
                  distance = 0.0;
                } else if (diff == 1) {
                  distance = 56.0; // Spacing matches unhovered column gap
                }
              }
              itemSizes[i] = calculateContainerSize(distance);
              iconSizes[i] = calculateIconSize(distance);
            }

            // 2. Calculate dynamic positioning (tops) and total dock height to avoid overlaps
            final tops = List<double>.filled(destinations.length, 0.0);
            tops[0] = 16.0; // Top padding
            for (int i = 1; i < destinations.length; i++) {
              tops[i] =
                  tops[i - 1] +
                  itemSizes[i - 1] +
                  16.0; // Dynamic height + 16.0px gap
            }
            final double dynamicDockHeight =
                tops[destinations.length - 1] +
                itemSizes[destinations.length - 1] +
                16.0;

            // The MouseRegion tracks coordinates only within the active size of the dock
            return MouseRegion(
              onHover: (event) {
                _mouseY.value = event.localPosition.dy;
                if (ref.read<bool>(isDpadActiveProvider)) {
                  ref
                      .read<DpadActiveNotifier>(isDpadActiveProvider.notifier)
                      .set(false);
                }
              },
              onExit: (_) {
                _mouseY.value = double.infinity;
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: const _AceternitySpringCurve(),
                width: dockWidth,
                height:
                    dynamicDockHeight, // Dynamic height scales on the spring curve!
                clipBehavior: Clip.none,
                decoration: BoxDecoration(
                  color: dockBgColor,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: dockBorderColor.withValues(alpha: 0.8),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.35 : 0.08,
                      ),
                      blurRadius: 16,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: List.generate(destinations.length, (i) {
                    final (outlinedIcon, filledIcon, label) = destinations[i];
                    final isSelected = widget.currentIndex == i;

                    return AnimatedPositioned(
                      key: ValueKey('dock_item_$i'),
                      duration: const Duration(milliseconds: 350),
                      curve: const _AceternitySpringCurve(),
                      left:
                          12.0, // Fixed left baseline anchors growth horizontally to the right
                      top: tops[i],
                      width: itemSizes[i],
                      height: itemSizes[i],
                      child: _SidebarDockItem(
                        focusNode: widget.focusNodes[i],
                        icon: isSelected ? filledIcon : outlinedIcon,
                        label: label,
                        isSelected: isSelected,
                        iconSize: iconSizes[i],
                        onTap: () => widget.onItemTapped(i),
                        index: i,
                        focusNodes: widget.focusNodes,
                        isDpadMode: isDpadMode,
                      ),
                    );
                  }),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SidebarDockItem extends ConsumerStatefulWidget {
  final FocusNode focusNode;
  final IconData icon;
  final String label;
  final bool isSelected;
  final double iconSize;
  final VoidCallback onTap;
  final int index;
  final List<FocusNode> focusNodes;
  final bool isDpadMode;

  const _SidebarDockItem({
    required this.focusNode,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.iconSize,
    required this.onTap,
    required this.index,
    required this.focusNodes,
    required this.isDpadMode,
  });

  @override
  ConsumerState<_SidebarDockItem> createState() => _SidebarDockItemState();
}

class _SidebarDockItemState extends ConsumerState<_SidebarDockItem> {
  bool _isFocused = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Background color of the items (bg-gray-200 / dark:bg-neutral-800 verbatim, no accent highlight)
    final itemBgColor = isDark
        ? const Color(0xFF262626)
        : const Color(0xFFE5E7EB);

    // Icon color of the items (high contrast in both dark and light modes)
    final iconColor = isDark ? Colors.white : const Color(0xFF171717);

    // Tooltip style color variables (bg-gray-100 / dark:bg-neutral-800 verbatim)
    final tooltipBgColor = isDark
        ? const Color(0xFF262626)
        : const Color(0xFFF3F4F6);
    final tooltipBorderColor = isDark
        ? const Color(0xFF171717)
        : const Color(0xFFE5E7EB);
    final tooltipTextColor = isDark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF374151);

    final showTooltip = _isHovered || (_isFocused && widget.isDpadMode);

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (focused) {
        setState(() => _isFocused = focused);
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          ref.read<DpadActiveNotifier>(isDpadActiveProvider.notifier).set(true);
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            if (event is KeyDownEvent) {
              widget.onTap();
            }
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            if (widget.index < widget.focusNodes.length - 1) {
              widget.focusNodes[widget.index + 1].requestFocus();
              return KeyEventResult.handled;
            }
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            if (widget.index > 0) {
              widget.focusNodes[widget.index - 1].requestFocus();
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _isHovered = true);
        },
        onExit: (_) {
          setState(() => _isHovered = false);
        },
        cursor: SystemMouseCursors.click,
        child: SizedBox.expand(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment
                .centerLeft, // Centered to the left edge of the animated positioned widget
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final size = constraints.maxHeight;
                        return Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            color: itemBgColor,
                            shape: BoxShape.circle,
                          ),
                          child: GestureDetector(
                            onTap: () {
                              widget.focusNode.requestFocus();
                              widget.onTap();
                            },
                            child: Container(
                              color: Colors.transparent,
                              alignment: Alignment.center,
                              child: TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 350),
                                curve: const _AceternitySpringCurve(),
                                tween: Tween<double>(end: widget.iconSize),
                                builder: (context, animatedIconSize, child) {
                                  return Icon(
                                    widget.icon,
                                    color: iconColor,
                                    size:
                                        animatedIconSize, // Dynamic font size animated on the spring curve
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(
                      width: 12.0,
                    ), // Constant gap of 12.0px between badge and tooltip!
                    IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: showTooltip ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOut,
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOut,
                          tween: Tween<double>(end: showTooltip ? 0.0 : 8.0),
                          builder: (context, xOffset, child) {
                            return Transform.translate(
                              offset: Offset(xOffset, 0.0),
                              child: child,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: tooltipBgColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: tooltipBorderColor,
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              widget.label,
                              style: TextStyle(
                                color: tooltipTextColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ),
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

/// Custom spring curve that solves the exact step-response equation of:
/// mass: 0.1, stiffness: 150, damping: 12
class _AceternitySpringCurve extends Curve {
  const _AceternitySpringCurve();

  @override
  double transformInternal(double t) {
    if (t == 0.0) return 0.0;
    if (t == 1.0) return 1.0;
    // Map normalized t [0, 1] to actual spring time (overdamped settling completes by 0.35s)
    final double actualT = t * 0.35;
    final double val =
        1.0 -
        1.15465359 * math.exp(-14.1742431 * actualT) +
        0.15465359 * math.exp(-105.8257569 * actualT);
    return val.clamp(0.0, 1.0);
  }
}
