import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/utils/image_utils.dart';
import '../../core/utils/responsive_breakpoints.dart';
import '../../features/settings/presentation/general_settings_provider.dart';
import 'cards_wrapper.dart';
import 'shimmer_placeholder.dart';
import 'thumbnail_error_placeholder.dart';

class MultimediaCard extends ConsumerWidget {
  final String? imageUrl;
  final String title;
  final VoidCallback onTap;
  final String heroTag;
  final bool isPortrait;
  final FocusNode? focusNode;

  /// Headers the poster request needs (e.g. a CloudStream plugin's `posterHeaders` such as a
  /// Referer). Without them hosts that check the Referer answer 403 and the card stays blank.
  final Map<String, String>? imageHeaders;

  const MultimediaCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.onTap,
    required this.heroTag,
    this.isPortrait = true,
    this.focusNode,
    this.imageHeaders,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = context.isDesktop;
    final cardWidth = isDesktop
        ? (isPortrait ? 200.0 : 300.0)
        : (isPortrait ? 130.0 : 200.0);

    final titlePosition = ref.watch(
      generalSettingsProvider.select((s) => s.titlePosition),
    );
    final isInside = titlePosition == 'inside';

    // LayoutBuilder, and above the Hero rather than inside it.
    //
    // Above the Hero because a hero flight animates its child's box from card
    // size to full-screen size; a LayoutBuilder inside would recompute the
    // decode bound on every frame of the flight, and every distinct
    // memCacheWidth is a distinct image-cache key, so the flight would decode
    // the poster afresh frame after frame.
    //
    // LayoutBuilder because `cardWidth` is only a request: a grid cell or a
    // rail with an itemExtent hands this card TIGHT constraints, the SizedBox
    // below is overridden, and the card is then painted at a width nobody
    // passed in. Bounding the decode to the width we were actually given is
    // the whole point, so it has to come from the constraints.
    final imageWidget = LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : cardWidth;
        return Hero(
          tag: heroTag,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: imageUrl ?? '',
              httpHeaders: imageHeaders,
              fit: BoxFit.cover,
              width: double.infinity,
              // Without this the source decodes whole: a `w780` TV/desktop
              // poster is 780x1170 = 3.65 MB of bitmap for a card painted
              // 400 px wide, and a plugin that serves a 2000x3000 poster is
              // 24 MB — half the 50 MB image cache for one card.
              memCacheWidth: ImageUtils.coverDecodeWidth(
                context,
                width: boxWidth,
                height: constraints.maxHeight,
                sourceAspectRatio: isPortrait
                    ? ImageUtils.posterAspectRatio
                    : ImageUtils.backdropAspectRatio,
              ),
              placeholder: (context, url) =>
                  ShimmerPlaceholder(borderRadius: 12),
              errorWidget: (_, _, _) => ThumbnailErrorPlaceholder(label: title),
            ),
          ),
        );
      },
    );

    final titleTextStyle = TextStyle(
      color: isInside
          ? Colors.white
          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
      fontSize: isDesktop ? 22 : 14,
      fontWeight: FontWeight.w500,
      shadows: isInside
          ? [
              const Shadow(
                color: Colors.black87,
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ]
          : null,
    );

    return RepaintBoundary(
      child: CardsWrapper(
        onTap: onTap,
        focusNode: focusNode,
        scaleFactor: 1.05,
        child: SizedBox(
          width: cardWidth,
          child: isInside
              ? _buildInsideMode(imageWidget, titleTextStyle)
              : _buildBelowMode(imageWidget, titleTextStyle),
        ),
      ),
    );
  }

  Widget _buildBelowMode(Widget imageWidget, TextStyle titleTextStyle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: imageWidget),
        const SizedBox(height: 8),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleTextStyle,
        ),
      ],
    );
  }

  Widget _buildInsideMode(Widget imageWidget, TextStyle titleTextStyle) {
    return Stack(
      children: [
        Positioned.fill(child: imageWidget),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
                stops: [0.0, 1.0],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: titleTextStyle,
            ),
          ),
        ),
      ],
    );
  }
}
