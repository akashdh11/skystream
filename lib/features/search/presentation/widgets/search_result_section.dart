import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../../cloudstream/presentation/cloudstream_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skystream/core/utils/responsive_breakpoints.dart';

import 'package:skystream/core/extensions/extension_manager.dart';
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/core/router/app_router.dart';
import 'package:skystream/core/utils/image_fallbacks.dart';
import 'package:skystream/shared/widgets/desktop_scroll_wrapper.dart';
import 'package:skystream/shared/widgets/multimedia_card.dart';

import '../search_sources.dart';
import 'search_source_tag.dart';
import 'stamp_in_label.dart';
import 'bouncy_entry_animation.dart';

class SearchResultSection extends ConsumerStatefulWidget {
  final String providerName;
  final String providerId;
  final List<MultimediaItem> results;
  final FocusNode? firstCardFocusNode;

  /// The system the section comes from, which its tag names.
  final SearchSourceKind kind;

  /// Opens the section's results in their own system's pages; without one,
  /// they open on the details page.
  final SearchSource? source;

  SearchResultSection({
    super.key,
    required this.providerName,
    required this.providerId,
    required this.results,
    this.firstCardFocusNode,
    SearchSourceKind? kind,
    this.source,
  }) : kind =
           kind ??
           (CloudStreamBadge.isCloudStream(providerId)
               ? SearchSourceKind.cloudstream
               : SearchSourceKind.skystream);

  @override
  ConsumerState<SearchResultSection> createState() =>
      _SearchResultSectionState();
}

class _SearchResultSectionState extends ConsumerState<SearchResultSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.results.isEmpty) return const SizedBox.shrink();

    final isLarge = context.isTabletOrLarger;
    // Matching MediaHorizontalList/ContinueWatchingSection dimensions
    final double listHeight = isLarge ? 350.0 : 230.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Blue Accent Style
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StampInLabel(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.providerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isLarge ? 24 : 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          _buildDebugTag(context, ref),
                          const SizedBox(width: 8),
                          SearchSourceTag(widget.kind),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: isLarge ? 30 : 20,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        SizedBox(
          height: listHeight,
          child: DesktopScrollWrapper(
            controller: _scrollController,
            child: Builder(
              builder: (context) {
                final double cardWidth = isLarge ? 200.0 : 130.0;
                final double spacing = isLarge ? 24.0 : 12.0;

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.results.length,
                  itemExtent: cardWidth + spacing,
                  clipBehavior: Clip.none,
                  itemBuilder: (context, rIndex) {
                    final item = widget.results[rIndex];
                    final uniqueTag =
                        'search_${widget.providerId}_${item.url}_$rIndex';

                    return Padding(
                      padding: EdgeInsets.only(right: spacing),
                      child: BouncyEntryAnimation(
                        delay: Duration(milliseconds: rIndex * 50),
                        child: MultimediaCard(
                          key: ValueKey(item.url),
                          imageHeaders: item.headers,
                          imageUrl: AppImageFallbacks.poster(
                            item.posterUrl,
                            label: item.title,
                          ),
                          title: item.title,
                          heroTag: uniqueTag,
                          focusNode: rIndex == 0
                              ? widget.firstCardFocusNode
                              : null,
                          onTap: () {
                            final source = widget.source;
                            if (source != null) {
                              unawaited(source.open(context, item));
                              return;
                            }
                            DetailsRoute(
                              $extra: DetailsRouteExtra(item: item),
                            ).push<void>(context);
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDebugTag(BuildContext context, WidgetRef ref) {
    bool isDebug = false;
    try {
      final manager = ref.read(extensionManagerProvider.notifier);
      final p = manager.getAllProviders().firstWhere(
        (p) => p.packageName == widget.providerId,
      );
      if (p.isDebug) {
        isDebug = true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SearchResultSection._buildDebugTag: $e');
    }

    if (!isDebug) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'DEBUG',
          style: TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
