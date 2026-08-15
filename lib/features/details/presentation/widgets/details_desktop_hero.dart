import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/utils/image_fallbacks.dart';
import '../../../../shared/widgets/thumbnail_error_placeholder.dart';
import '../../../../shared/widgets/expandable_text.dart';
import 'premium_details_widgets.dart';
import 'details_layout_widgets.dart';
import '../../../../core/services/notification_service.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';

/// Immersive desktop/TV hero for non-TMDB details.
///
/// Layout: full-viewport backdrop fading via gradients, with metadata
/// overlaid on the left ~55% of the screen. [child] renders below the
/// hero section (episodes, cast, trailers, recommendations).
class DetailsDesktopHero extends ConsumerWidget {
  const DetailsDesktopHero({
    super.key,
    required this.displayItem,
    required this.baseItem,
    required this.details,
    required this.detailsState,
    required this.isMovie,
    required this.itemUrl,
    required this.child,
  });

  /// The resolved item for display (details ?? widget.item).
  final MultimediaItem displayItem;

  /// The original item — used by [DetailsActionButtons] for URL matching.
  final MultimediaItem baseItem;

  /// Loaded details (nullable while loading).
  final MultimediaItem? details;

  /// Async state for loading/error indicators.
  final AsyncValue<MultimediaItem?> detailsState;

  final bool isMovie;
  final String itemUrl;

  /// Content rendered below the hero section (episodes, cast, etc.).
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scaffoldColor = theme.scaffoldBackgroundColor;
    final textColor = theme.colorScheme.onSurface;
    final textSecondary = textColor.withValues(alpha: 0.7);
    final l10n = AppLocalizations.of(context)!;

    final backdropUrl =
        AppImageFallbacks.optional(displayItem.bannerUrl) ??
        AppImageFallbacks.poster(
          displayItem.posterUrl,
          label: displayItem.title,
        ) ??
        '';

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Layer 1: Backdrop image with left-fade ShaderMask ──
        Positioned.fill(
          child: ShaderMask(
            shaderCallback: (rect) {
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  scaffoldColor,
                  scaffoldColor.withValues(alpha: 0.85),
                  scaffoldColor.withValues(alpha: 0.55),
                  scaffoldColor.withValues(alpha: 0.25),
                  scaffoldColor.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
              ).createShader(rect);
            },
            blendMode: BlendMode.dstOut,
            child: CachedNetworkImage(
              imageUrl: backdropUrl,
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              // Bound decoded bitmap; plugin-supplied backdrops are often
              // already at source resolution (no size negotiation), so a 4K
              // poster decoded at native size would burn ~33 MB.
              memCacheWidth:
                  (MediaQuery.sizeOf(context).width *
                          MediaQuery.devicePixelRatioOf(context))
                      .round(),
              errorWidget: (_, _, _) => ThumbnailErrorPlaceholder(
                label: displayItem.title,
                isBackdrop: true,
              ),
            ),
          ),
        ),

        // ── Layer 2: Left-to-right gradient overlay ──
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  scaffoldColor,
                  scaffoldColor.withValues(alpha: 0.85),
                  scaffoldColor.withValues(alpha: 0.55),
                  scaffoldColor.withValues(alpha: 0.25),
                  scaffoldColor.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
              ),
            ),
          ),
        ),

        // ── Layer 3: Bottom-to-top gradient (seamless transition) ──
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  scaffoldColor,
                  scaffoldColor.withValues(alpha: 0.85),
                  scaffoldColor.withValues(alpha: 0.55),
                  scaffoldColor.withValues(alpha: 0.25),
                  scaffoldColor.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.1, 0.2, 0.28, 0.35, 0.4],
              ),
            ),
          ),
        ),

        // ── Layer 4: Scrollable content ──
        Positioned.fill(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero content (constrained to left 55%) ──
                SizedBox(
                  width: MediaQuery.sizeOf(context).width * 0.55,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo or Title
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onLongPress: () => _copyAnimeTitle(context, ref),
                        child: displayItem.logoUrl != null
                            ? CachedNetworkImage(
                                imageUrl: displayItem.logoUrl!,
                                height: 200,
                                alignment: Alignment.centerLeft,
                                fit: BoxFit.contain,
                                placeholder: (_, _) => _buildTitle(textColor),
                                errorWidget: (_, _, _) =>
                                    _buildTitle(textColor),
                              )
                            : _buildTitle(textColor),
                      ),

                      const SizedBox(height: 16),

                      // Metadata bar (provider badge, type, year, rating, etc.)
                      MetadataBar(
                        item: displayItem,
                        isLoading: detailsState is AsyncLoading,
                      ),

                      const SizedBox(height: 20),

                      // Synopsis
                      ExpandableText(
                        text: displayItem.description ?? l10n.noDescription,
                        maxLines: 4,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),

                      // Next airing (for currently-airing shows)
                      if (displayItem.nextAiring != null) ...[
                        const SizedBox(height: 20),
                        NextAiringWidget(nextAiring: displayItem.nextAiring!),
                      ],

                      const SizedBox(height: 32),

                      // Action buttons (Play / Download)
                      // Constrained width so they don't stretch across
                      // the full hero area — looks better on wide screens.
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: DetailsActionButtons(
                          item: baseItem,
                          details: details,
                          itemUrl: itemUrl,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 60),

                // ── Content below hero (full width) ──
                child,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _copyAnimeTitle(BuildContext context, WidgetRef ref) async {
    await Clipboard.setData(ClipboardData(text: displayItem.title));
    await HapticFeedback.selectionClick();

    if (!context.mounted) {
      return;
    }

    ref.read(notificationServiceProvider).showSuccess(
      'Copied to clipboard',
      title: displayItem.title,
      icon: Icons.content_copy_rounded,
      duration: const Duration(milliseconds: 2200),
    );
  }

  Widget _buildTitle(Color textColor) {
    return Text(
      displayItem.title,
      style: TextStyle(
        color: textColor,
        fontSize: 56,
        fontWeight: FontWeight.bold,
        height: 1.1,
      ),
    );
  }
}
