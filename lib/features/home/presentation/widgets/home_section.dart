import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:skystream/core/utils/responsive_breakpoints.dart';
import 'package:skystream/core/router/app_router.dart';
import 'package:skystream/core/utils/image_fallbacks.dart';
import 'package:skystream/core/utils/layout_constants.dart';

import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../shared/widgets/desktop_scroll_wrapper.dart';
import '../../../../shared/widgets/multimedia_card.dart';

class HomeSection extends ConsumerStatefulWidget {
  final String title;
  final List<MultimediaItem> items;
  const HomeSection({super.key, required this.title, required this.items});

  @override
  ConsumerState<HomeSection> createState() => _HomeSectionState();
}

class _HomeSectionState extends ConsumerState<HomeSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final isLarge = context.isTabletOrLarger;

    final double totalHeight = isLarge ? 350.0 : 230.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            widget.title,
            style: isLarge
                ? Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)
                : Theme.of(context).textTheme.titleLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(
          height: totalHeight,
          child: DesktopScrollWrapper(
            controller: _scrollController,
            showButtons: isLarge, // Show nav buttons on both desktop and TV
            child: Builder(
              builder: (context) {
                final double cardWidth = isLarge ? 200.0 : 130.0;
                final double spacing = isLarge
                    ? LayoutConstants.spacingLg
                    : LayoutConstants.spacingSm;

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: LayoutConstants.spacingMd,
                    vertical: LayoutConstants.spacingXs,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.items.length,
                  itemExtent: cardWidth + spacing,
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    return Padding(
                      padding: EdgeInsets.only(right: spacing),
                      child: MultimediaCard(
                        key: ValueKey(item.url),
                        imageHeaders: item.headers,
                        imageUrl:
                            AppImageFallbacks.poster(
                              item.posterUrl,
                              label: item.title,
                            ) ??
                            '',
                        title: item.title,
                        heroTag: 'home_${item.url}_$index',
                        onTap: () =>
                            DetailsRoute($extra: DetailsRouteExtra(item: item))
                                .push<void>(context),
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
}
