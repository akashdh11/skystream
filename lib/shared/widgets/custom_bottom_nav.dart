import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const double height = 64;

  /// The pill's offset from the screen bottom (matching 4c-app convention).
  static double bottomInsetFor(BuildContext context) =>
      math.max(MediaQuery.viewPaddingOf(context).bottom - 8, 12);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final destinations = <_BottomNavDestination>[
      _BottomNavDestination(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: localizations.home,
      ),
      _BottomNavDestination(
        icon: Icons.search_outlined,
        selectedIcon: Icons.search,
        label: localizations.search,
      ),
      _BottomNavDestination(
        icon: Icons.explore_outlined,
        selectedIcon: Icons.explore,
        label: localizations.explore,
      ),
      _BottomNavDestination(
        icon: Icons.video_library_outlined,
        selectedIcon: Icons.video_library,
        label: localizations.library,
      ),
      _BottomNavDestination(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: localizations.settings,
      ),
    ];

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final count = destinations.length;

    // Sliding highlight indicator
    final highlight = AnimatedAlign(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: count <= 1
          ? Alignment.center
          : Alignment(-1 + 2 * (currentIndex / (count - 1)), 0),
      child: FractionallySizedBox(
        widthFactor: count == 0 ? 1 : 1 / count,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular((height - 12) / 2),
              color: colorScheme.primary.withValues(alpha: 0.15),
            ),
          ),
        ),
      ),
    );

    final tabs = <Widget>[
      for (final (i, d) in destinations.indexed)
        Expanded(
          child: _NavTabCell(
            destination: d,
            isSelected: i == currentIndex,
            onTap: () {
              HapticFeedback.selectionClick();
              onTap(i);
            },
          ),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth = constraints.maxWidth.clamp(0.0, 420.0);
        return Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: Container(
            width: fullWidth,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              border: Border.all(
                color: isDark
                    ? theme.dividerColor.withValues(alpha: 0.3)
                    : colorScheme.outline.withValues(alpha: 0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(height / 2),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  height: height,
                  color: colorScheme.surface.withValues(alpha: 0.8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      highlight,
                      Row(children: tabs),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavTabCell extends StatefulWidget {
  final _BottomNavDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavTabCell({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavTabCell> createState() => _NavTabCellState();
}

class _NavTabCellState extends State<_NavTabCell> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: widget.destination.label,
      child: Tooltip(
        message: widget.destination.label,
        child: Focus(
          onFocusChange: (focused) => setState(() => _isFocused = focused),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: _isFocused
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: colorScheme.primary, width: 2.0),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  )
                : null,
            child: InkWell(
              borderRadius: BorderRadius.circular(26),
              focusColor: Colors.transparent,
              hoverColor: colorScheme.primary.withValues(alpha: 0.08),
              onTap: widget.onTap,
              child: Center(
                child: Icon(
                  widget.isSelected
                      ? widget.destination.selectedIcon
                      : widget.destination.icon,
                  color: widget.isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _BottomNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
