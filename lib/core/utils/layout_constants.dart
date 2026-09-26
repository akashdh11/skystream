import 'package:flutter/widgets.dart';
/// Centralized spacing and layout values for consistent UI.
/// Use from details_screen, explore_carousel, and other layout code.
class LayoutConstants {
  LayoutConstants._();

  // Spacing
  static const double spacingXs = 8;
  static const double spacingSm = 12;
  static const double spacingMd = 16;
  static const double spacingLg = 24;

  // Details screen SliverAppBar
  static const double detailsExpandedHeightMobile = 400;
  static const double detailsExpandedHeightDesktop = 300;

  // Explore carousel: use same breakpoint as [ResponsiveBreakpoints.desktopBreakpoint]
  static const double exploreCarouselDesktopBreakpoint = 900;

  // Carousel hero aspect ratio (e.g. 16/9)
  static const double carouselHeroAspectRatio = 16 / 9;

  // Border Radius
  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const double radiusXl = 16;
  static const double radiusXxl = 24;
  static const double radiusPill = 50;

  // Content constraints
  static const double contentMaxWidth = 800;

  // Dashboard layout (widescreen)
  static const double sidebarWidthExpanded = 230;
  static const double sidebarWidthCompact = 80;
  static const double contentCardRadius = 24;
  static const double dashboardHeaderHeight = 56;
  static const double dashboardContentPadding = 24;

  /// Bottom padding so list content clears the floating bottom nav.
  ///
  /// Prefer [MediaQuery.padding.bottom] when [AppScaffold] has already inflated
  /// it for the shell; fall back to a safe minimum when it has not (e.g. a
  /// screen opened outside the shell).
  static double shellBottomContentPadding(
    BuildContext context, {
    double minimum = 100,
  }) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return bottom > minimum ? bottom : minimum;
  }

}
