import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skystream/core/utils/layout_constants.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';
import 'package:skystream/shared/widgets/cards_wrapper.dart';
import 'package:skystream/features/explore/presentation/delegates/explore_search_delegate.dart';
import 'package:skystream/features/explore/presentation/widgets/unified_filter_dialog.dart';
import 'package:skystream/features/explore/data/explore_filter_provider.dart';
import 'package:skystream/features/explore/data/explore_mode_provider.dart';
import 'package:skystream/features/explore/presentation/widgets/hover_border_gradient.dart';
import 'package:skystream/features/explore/presentation/widgets/explore_mode_selector_dialog.dart';
import 'dart:async';

/// A custom header bar for the explore screen in widescreen/desktop layout.
///
/// Contains: carousel prev/next arrows, capsule search, filter chip.
class ExploreHeaderBar extends ConsumerWidget {
  final FocusNode searchFocusNode;

  /// Called when the user taps the left arrow (carousel previous).
  final VoidCallback? onPrevious;

  /// Called when the user taps the right arrow (carousel next).
  final VoidCallback? onNext;

  const ExploreHeaderBar({
    super.key,
    required this.searchFocusNode,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final hasCarousel = onPrevious != null && onNext != null;

    return Container(
      height: LayoutConstants.dashboardHeaderHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: LayoutConstants.dashboardContentPadding,
      ),
      child: Row(
        children: [
          // Carousel prev / next arrows
          CardsWrapper(
            scaleFactor: 1.01,
            onTap: () => onPrevious?.call(),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_back_ios_new,
                size: 14,
                color: hasCarousel
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          const SizedBox(width: 4),
          CardsWrapper(
            scaleFactor: 1.01,
            onTap: () => onNext?.call(),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: hasCarousel
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
          ),

          const SizedBox(width: 16),

          CardsWrapper(
            scaleFactor: 1.01,
            onTap: () => showExploreModeSelectorDialog(context, ref),
            borderRadius: BorderRadius.circular(LayoutConstants.radiusPill),
            child: HoverBorderGradient(
              onTap: () => showExploreModeSelectorDialog(context, ref),
              child: Consumer(
                builder: (context, ref, _) {
                  final mode = ref.watch(exploreModeProvider);
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  final textColor = isDark ? Colors.white : Colors.black;

                  Widget iconWidget;
                  String labelText;

                  switch (mode) {
                    case ExploreModeType.movies:
                      iconWidget = Icon(
                        Icons.movie_outlined,
                        size: 14,
                        color: textColor,
                      );
                      labelText = l10n.exploreMovies;
                      break;
                    case ExploreModeType.anime:
                      iconWidget = SizedBox(
                        width: 14,
                        height: 14,
                        child: CustomPaint(
                          painter: AnimeLogoPainter(color: textColor),
                        ),
                      );
                      labelText = l10n.exploreAnime;
                      break;
                    case ExploreModeType.stremio:
                      iconWidget = Icon(
                        Icons.extension_outlined,
                        size: 14,
                        color: textColor,
                      );
                      labelText = 'Stremio Add-ons';
                      break;
                  }

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      iconWidget,
                      const SizedBox(width: 8),
                      Text(
                        labelText,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Capsule search bar
          Expanded(
            child: CardsWrapper(
              scaleFactor: 1.01,
              focusNode: searchFocusNode,
              onTap: () {
                unawaited(
                  showSearch<void>(
                    context: context,
                    delegate: ExploreSearchDelegate(),
                    useRootNavigator: false,
                    maintainState: true,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(LayoutConstants.radiusPill),
              child: Container(
                height: 38,
                constraints: const BoxConstraints(maxWidth: 500),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(
                    LayoutConstants.radiusPill,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${l10n.search}...',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),
          // Filter chip
          CardsWrapper(
            scaleFactor: 1.01,
            onTap: () {
              unawaited(
                showDialog<void>(
                  context: context,
                  builder: (context) => const UnifiedFilterDialog(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(50),
            child: Consumer(
              builder: (context, ref, _) {
                final filters = ref.watch(exploreFilterProvider);
                final hasActiveFilter =
                    filters.selectedGenre != null ||
                    filters.selectedYear != null ||
                    filters.minRating != null;

                return Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasActiveFilter
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.3,
                          ),
                  ),
                  child: Icon(
                    Icons.tune,
                    color: theme.colorScheme.onSurface,
                    size: 18,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
