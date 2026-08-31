import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/core/extensions/extension_manager.dart';
import 'package:skystream/core/utils/image_fallbacks.dart';
import 'package:skystream/features/search/presentation/search_provider.dart';
import '../../../../shared/widgets/cards_wrapper.dart';

import '../../../../shared/widgets/desktop_scroll_wrapper.dart';
import '../../../../core/utils/layout_constants.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../../../../shared/widgets/thumbnail_error_placeholder.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';

part 'provider_search_section.g.dart';

// Delegates to the shared searchAllProviders() function — no duplicated
// fan-out, mapping, or filtering logic.
@riverpod
Stream<SearchAggregateState> providerSearch(Ref ref, String query) {
  ref.watch(extensionManagerProvider);
  final manager = ref.read(extensionManagerProvider.notifier);

  var cancelled = false;
  ref.onDispose(() => cancelled = true);

  return searchAllProviders(
    ref,
    query,
    manager,
    filter: SearchFilter.content,
    isCancelled: () => cancelled,
  );
}

class ProviderSearchSection extends ConsumerStatefulWidget {
  final String query;
  final bool compact;
  final bool showHeader;
  final String? parentMediaType; // 'movie' or 'tv'
  final int? tmdbId;
  final String? imdbId;
  final VoidCallback? onViewAll;

  const ProviderSearchSection({
    super.key,
    required this.query,
    this.compact = false,
    this.showHeader = true,
    this.parentMediaType,
    this.tmdbId,
    this.imdbId,
    this.onViewAll,
  });

  @override
  ConsumerState<ProviderSearchSection> createState() =>
      _ProviderSearchSectionState();
}

class _ProviderSearchSectionState extends ConsumerState<ProviderSearchSection> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollBy(double offset) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + offset).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.query.isEmpty) return const SizedBox.shrink();

    final plugins = ref.watch(extensionManagerProvider);
    final searchAsync = ref.watch(providerSearchProvider(widget.query));

    Widget content;
    if (plugins.isEmpty) {
      content = Container(
        height: 140,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(LayoutConstants.spacingMd),
        child: Text(
          AppLocalizations.of(context)!.noPluginsInstalled,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      );
    } else {
      content = searchAsync.when(
        data: (state) {
          final allItems = <Map<String, dynamic>>[];
          for (final pResult in state.results) {
            for (final item in pResult.results) {
              allItems.add({
                'item': item,
                'providerName': pResult.providerName,
              });
            }
          }

          if (allItems.isEmpty) {
            if (state.isLoading) {
              return const SizedBox(
                height: 140,
                child: Center(
                  child: AppLoadingIndicator(
                    constraints: BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                      maxWidth: 24,
                      maxHeight: 24,
                    ),
                  ),
                ),
              );
            }
            return Container(
              height: 140,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(LayoutConstants.spacingMd),
              child: Text(
                AppLocalizations.of(context)!.noResultsFound,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            );
          }

          return RepaintBoundary(
            child: SizedBox(
              height: 140,
              child: DesktopScrollWrapper(
                controller: _scrollController,
                child: Scrollbar(
                  controller: _scrollController,
                  child: ListView.separated(
                    controller: _scrollController,
                    clipBehavior: Clip.none,
                    scrollDirection: Axis.horizontal,
                    padding: widget.compact
                        ? EdgeInsets.zero
                        : const EdgeInsets.symmetric(
                            horizontal: LayoutConstants.spacingMd,
                          ),
                    itemCount: allItems.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: LayoutConstants.spacingSm),
                    itemBuilder: (context, index) {
                      final data = allItems[index];
                      final item = data['item'] as MultimediaItem;
                      final providerName = data['providerName'] as String;

                      return CardsWrapper(
                      onTap: () {
                        // Enrich item with provider, content type, and metadata IDs before navigation
                        final enrichedItem = item.copyWith(
                          provider: providerName,
                          contentType: widget.parentMediaType != null
                              ? MultimediaItem.parseContentType(
                                  widget.parentMediaType,
                                )
                              : item.contentType,
                          tmdbId: widget.tmdbId ?? item.tmdbId,
                          imdbId: widget.imdbId ?? item.imdbId,
                        );
                        DetailsRoute(
                          $extra: DetailsRouteExtra(item: enrichedItem),
                        ).push<void>(context);
                      },
                      child: SizedBox(
                        width: 220,
                        child: Card(
                          elevation: 0,
                          margin: EdgeInsets.zero,
                          color: Theme.of(context).colorScheme.surface,
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 90,
                                height: double.infinity,
                                child: CachedNetworkImage(
                                  imageUrl:
                                      AppImageFallbacks.poster(
                                        item.posterUrl,
                                        label: item.title,
                                      ) ??
                                      '',
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) =>
                                      ShimmerPlaceholder(borderRadius: 8),
                                  errorWidget: (_, _, _) =>
                                      const ThumbnailErrorPlaceholder(),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        item.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          providerName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
        loading: () => const SizedBox(
          height: 140, // Fix 2: Force height for centering
          child: Center(
            child: AppLoadingIndicator(
              constraints: BoxConstraints(
                minWidth: 24,
                minHeight: 24,
                maxWidth: 24,
                maxHeight: 24,
              ),
            ),
          ),
        ),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(LayoutConstants.spacingMd),
          child: Text(
            AppLocalizations.of(context)!.errorPrefix(err.toString()),
          ),
        ),
      );
    }

    if (widget.compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showHeader) ...[
            _buildHeader(context),
            const SizedBox(height: 12),
          ],
          content,
        ],
      );
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 180),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: LayoutConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showHeader) ...[
            _buildHeader(context),
            const SizedBox(height: LayoutConstants.spacingSm),
          ],
          content,
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final padding = widget.compact
        ? EdgeInsets.zero
        : const EdgeInsets.symmetric(horizontal: LayoutConstants.spacingMd);

    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.extension,
                size: widget.compact ? 20 : 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.availableSources,
                style: TextStyle(
                  fontSize: widget.compact ? 18 : 14,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "BETA",
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeaderArrowButton(
                icon: Icons.arrow_back_ios_new,
                onTap: () => _scrollBy(-300),
              ),
              const SizedBox(width: 4),
              _HeaderArrowButton(
                icon: Icons.arrow_forward_ios,
                onTap: () => _scrollBy(300),
              ),
              if (widget.onViewAll != null) ...[
                const SizedBox(width: LayoutConstants.spacingXs),
                CardsWrapper(
                  scaleFactor: 1.05,
                  onTap: widget.onViewAll!,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: LayoutConstants.spacingSm,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.viewAll,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 10,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CardsWrapper(
      scaleFactor: 1.05,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 12, color: theme.colorScheme.onSurface),
      ),
    );
  }
}
