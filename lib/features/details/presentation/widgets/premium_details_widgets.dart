import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/core/utils/image_fallbacks.dart';
import 'package:skystream/shared/widgets/cards_wrapper.dart';
import 'package:skystream/shared/widgets/shimmer_placeholder.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:skystream/shared/widgets/thumbnail_error_placeholder.dart';
import 'package:skystream/core/utils/responsive_breakpoints.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'details_layout_widgets.dart';

class MetadataBar extends ConsumerWidget {
  final MultimediaItem item;
  final bool isLoading;
  const MetadataBar({super.key, required this.item, this.isLoading = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // theme and context used in helper methods
    final contentType = item.contentType;
    final showTypeBadge =
        !isLoading || (contentType != MultimediaContentType.movie);

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (item.provider != null && item.provider!.isNotEmpty)
          DetailsProviderChip(providerName: item.provider!),
        if (showTypeBadge)
          _buildBorderedInfo(
            context,
            contentType.name.toUpperCase(),
            color: Theme.of(context).colorScheme.primary,
            isFilled: true,
          )
        else
          ShimmerPlaceholder.rectangular(
            width: 60,
            height: 20,
            borderRadius: 4,
          ),

        if (item.year != null)
          _buildIconInfo(
            context,
            Icons.calendar_today_rounded,
            item.year.toString(),
          )
        else if (isLoading)
          ShimmerPlaceholder.rectangular(
            width: 60,
            height: 20,
            borderRadius: 4,
          ),

        if (item.contentRating != null)
          _buildBorderedInfo(context, item.contentRating!)
        else if (isLoading)
          ShimmerPlaceholder.rectangular(
            width: 60,
            height: 20,
            borderRadius: 4,
          ),

        if (item.duration != null)
          _buildIconInfo(context, Icons.timer_outlined, "${item.duration}m")
        else if (isLoading)
          ShimmerPlaceholder.rectangular(
            width: 60,
            height: 20,
            borderRadius: 4,
          ),

        if (item.score != null)
          _buildIconInfo(
            context,
            Icons.star_rounded,
            item.score!.toStringAsFixed(1),
            iconColor: const Color(0xFF01B4E4),
          )
        else if (isLoading)
          ShimmerPlaceholder.rectangular(
            width: 60,
            height: 20,
            borderRadius: 4,
          ),

        if (item.playbackPolicy != null && item.playbackPolicy != "none")
          _buildPlaybackBadge(context, item.playbackPolicy!),
        if (item.isAdult)
          _buildBorderedInfo(context, "18+", color: Colors.redAccent),
      ],
    );
  }

  Widget _buildInfoText(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildBorderedInfo(
    BuildContext context,
    String text, {
    Color? color,
    bool isFilled = false,
  }) {
    final theme = Theme.of(context);
    final themeColor = color ?? theme.colorScheme.onSurface;

    if (isFilled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: themeColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: themeColor.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: themeColor,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: themeColor.withValues(alpha: 0.7),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildIconInfo(
    BuildContext context,
    IconData icon,
    String text, {
    Color? iconColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color:
              iconColor ??
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 4),
        _buildInfoText(context, text),
      ],
    );
  }

  Widget _buildPlaybackBadge(BuildContext context, String policy) {
    final color = Theme.of(context).colorScheme.secondary;
    final label = policy;
    const icon = Icons.play_circle_outline_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class NextAiringWidget extends StatefulWidget {
  final NextAiring nextAiring;

  const NextAiringWidget({super.key, required this.nextAiring});

  @override
  State<NextAiringWidget> createState() => _NextAiringWidgetState();
}

class _NextAiringWidgetState extends State<NextAiringWidget> {
  Timer? _timer;
  late Duration _remaining;

  DateTime get _airingDate => DateTime.fromMillisecondsSinceEpoch(
    widget.nextAiring.unixTime * 1000,
    isUtc: true,
  );

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void didUpdateWidget(covariant NextAiringWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.nextAiring.unixTime != widget.nextAiring.unixTime) {
      _startCountdown();
    }
  }

  Duration _calculateRemaining() {
    final difference = _airingDate.difference(DateTime.now().toUtc());

    if (difference.isNegative) {
      return Duration.zero;
    }

    return difference;
  }

  void _startCountdown() {
    _timer?.cancel();
    _remaining = _calculateRemaining();

    if (_remaining == Duration.zero) {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = _calculateRemaining();

      if (!mounted) {
        return;
      }

      setState(() {
        _remaining = remaining;
      });

      if (remaining == Duration.zero) {
        _timer?.cancel();
      }
    });
  }

  String _formatCountdown(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24).toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (days > 0) {
      return '$days days  $hours:$minutes:$seconds';
    }

    return '$hours:$minutes:$seconds';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final season = widget.nextAiring.season;
    final episodeDescription = season == null
        ? 'Episode ${widget.nextAiring.episode}'
        : 'Episode ${widget.nextAiring.episode} of Season $season';

    final countdownText = _remaining == Duration.zero
        ? 'Airing now'
        : _formatCountdown(_remaining);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$episodeDescription in',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            countdownText,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class CastCarousel extends StatelessWidget {
  final List<Actor> cast;
  const CastCarousel({super.key, required this.cast});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            "Cast",
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cast.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final actor = cast[index];
              return SizedBox(
                width: 80,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundImage: actor.image != null
                          ? CachedNetworkImageProvider(actor.image!)
                          : null,
                      child: actor.image == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      actor.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (actor.role != null)
                      Text(
                        actor.role!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class TrailersSection extends StatelessWidget {
  final List<Trailer> trailers;
  const TrailersSection({super.key, required this.trailers});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            "Trailers & Extras",
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: trailers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final trailer = trailers[index];
              return CardsWrapper(
                onTap: () async {
                  final uri = Uri.tryParse(trailer.url);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
                  width: 240,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).colorScheme.surfaceContainer,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl:
                            "https://img.youtube.com/vi/${_extractYoutubeId(trailer.url)}/mqdefault.jpg",
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) =>
                            const Center(child: Icon(Icons.movie_rounded)),
                      ),
                      Container(
                        color: Colors.black26,
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "Trailer",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _extractYoutubeId(String url) {
    // Simple extraction for common patterns
    if (url.contains("v=")) return url.split("v=")[1].split("&")[0];
    if (url.contains("be/")) return url.split("be/")[1].split("?")[0];
    return "";
  }
}

class RecommendationsCarousel extends StatelessWidget {
  final List<MultimediaItem> items;
  final void Function(MultimediaItem) onItemTap;

  const RecommendationsCarousel({
    super.key,
    required this.items,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLarge = context.isDesktop || context.isTv;
    final cardWidth = isLarge ? 180.0 : 110.0;
    final listHeight = isLarge ? 310.0 : 180.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            "More Like This",
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: listHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return CardsWrapper(
                onTap: () => onItemTap(item),
                child: SizedBox(
                  width: cardWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl:
                                AppImageFallbacks.poster(
                                  item.posterUrl,
                                  label: item.title,
                                ) ??
                                '',
                            fit: BoxFit.cover,
                            width: cardWidth,
                            errorWidget: (_, _, _) =>
                                ThumbnailErrorPlaceholder(label: item.title),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: isLarge
                            ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              )
                            : Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
