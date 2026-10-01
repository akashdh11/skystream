import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';

import '../focus/app_focus.dart';
import 'matte_glass_pill.dart';

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
    final isDark = theme.brightness == Brightness.dark;

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
          child: SizedBox(
            width: fullWidth,
            height: height,
            child: MatteGlassPill(
              surfaceColor: isDark
                  ? MatteGlassPill.surface
                  : MatteGlassPill.lightSurface,
              child: Material(
                type: MaterialType.transparency,
                child: Row(children: tabs),
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
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: widget.destination.label,
      child: Tooltip(
        message: widget.destination.label,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          onFocusChange: (focused) => setState(() => _isFocused = focused),
          onHover: (hovered) => setState(() => _isHovered = hovered),
          onTap: widget.onTap,
          child: Center(
            child: Icon(
              widget.isSelected
                  ? widget.destination.selectedIcon
                  : widget.destination.icon,
              color:
                  widget.isSelected ||
                      _isHovered ||
                      showFocusIndicator(context, _isFocused)
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
              size: 24,
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
