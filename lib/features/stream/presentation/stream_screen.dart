import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/providers/device_info_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/image_fallbacks.dart';
import '../../../core/utils/responsive_breakpoints.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/thumbnail_error_placeholder.dart';
import '../data/stream_browser_provider.dart';
import 'stream_source_picker.dart';

/// Cross-plugin browsing surface: TMDB catalogue + search, with every result
/// resolvable to links from all installed plugins.
class StreamScreen extends ConsumerStatefulWidget {
  const StreamScreen({super.key});

  @override
  ConsumerState<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends ConsumerState<StreamScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(streamBrowserProvider);
    final notifier = ref.read(streamBrowserProvider.notifier);
    final profile = ref.watch(deviceProfileProvider).asData?.value;
    final isWidescreen = profile?.isTv == true || context.isTabletOrLarger;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Aurora wash behind the content (design A).
          Positioned(
            top: -160,
            left: -80,
            right: -80,
            height: 420,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      cs.primary.withValues(alpha: 0.30),
                      cs.tertiary.withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _Header(
                  controller: _searchController,
                  query: state.query,
                  onChanged: notifier.search,
                  onClear: () {
                    _searchController.clear();
                    notifier.clearSearch();
                  },
                ),
                if (!state.isSearching)
                  _SegmentedTabs(
                    index: state.tabIndex,
                    onChanged: notifier.setTab,
                  ),
                const SizedBox(height: 4),
                Expanded(
                  child: state.isSearching
                      ? _MediaGrid(
                          itemsAsync:
                              state.searchResults ?? const AsyncLoading(),
                          isWidescreen: isWidescreen,
                          emptyLabel: 'No results for "${state.query}".',
                        )
                      : IndexedStack(
                          index: state.tabIndex,
                          children: [
                            _MediaGrid(
                              itemsAsync: state.movies,
                              isWidescreen: isWidescreen,
                              onRetry: notifier.refresh,
                            ),
                            _MediaGrid(
                              itemsAsync: state.series,
                              isWidescreen: isWidescreen,
                              onRetry: notifier.refresh,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted title + search field.
class _Header extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _Header({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stream',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search movies & series',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: onClear,
                          ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill segmented control (Movies / TV Shows).
class _SegmentedTabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _SegmentedTabs({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const labels = ['Movies', 'TV Shows'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: List.generate(labels.length, (i) {
            final selected = i == index;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? LinearGradient(
                            colors: [
                              cs.primary,
                              Color.lerp(cs.primary, cs.tertiary, 0.55) ??
                                  cs.primary,
                            ],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(19),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _MediaGrid extends ConsumerWidget {
  final AsyncValue<List<MultimediaItem>> itemsAsync;
  final bool isWidescreen;
  final String? emptyLabel;
  final Future<void> Function()? onRetry;

  const _MediaGrid({
    required this.itemsAsync,
    required this.isWidescreen,
    this.emptyLabel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return itemsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return _Message(
            icon: Icons.search_off_rounded,
            text: emptyLabel ?? 'Nothing to show yet.',
          );
        }
        final width = MediaQuery.sizeOf(context).width;
        final target = isWidescreen ? 200.0 : 170.0;
        final crossAxisCount = (width / target).floor().clamp(2, 8);

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.58,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) =>
              _StreamPosterCard(item: items[index]),
        );
      },
      loading: () => const Center(child: AppLoadingIndicator()),
      // Surfacing the real reason beats a blank grid — this is where the
      // "no TMDB results" dead end used to be.
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 44, color: cs.error),
              const SizedBox(height: 14),
              Text(
                error is StreamCatalogException
                    ? error.message
                    : 'Could not load from TMDB.\n$error',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 18),
                FilledButton.tonalIcon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Message({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreamPosterCard extends ConsumerWidget {
  final MultimediaItem item;
  const _StreamPosterCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isTv =
        item.contentType == MultimediaContentType.series ||
        item.contentType == MultimediaContentType.anime;
    final mediaType = isTv ? 'tv' : 'movie';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl:
                      AppImageFallbacks.poster(
                        item.posterUrl,
                        label: item.title,
                      ) ??
                      '',
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) =>
                      ThumbnailErrorPlaceholder(label: item.title),
                ),
                // Bottom scrim so the action row stays legible on light art.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 90,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.75),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (item.score != null && item.score! > 0)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: _Badge(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 12,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            item.score!.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: _Badge(
                    child: Text(
                      isTv ? 'TV' : 'MOVIE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                // Tapping the art opens details; the buttons below are the
                // fast path straight to sources.
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => TmdbDetailsRoute(
                        movieId: item.tmdbId ?? item.id,
                        mediaType: mediaType,
                        placeholderPoster: item.posterUrl,
                      ).push<void>(context),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 32,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              backgroundColor: cs.primary,
                            ),
                            onPressed: () =>
                                StreamSourcePicker.open(context, ref, item),
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 17,
                            ),
                            label: const Text(
                              'Play',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 32,
                        width: 32,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () =>
                                StreamSourcePicker.open(context, ref, item),
                            child: const Icon(
                              Icons.download_rounded,
                              size: 17,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (item.year != null)
          Text(
            '${item.year}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final Widget child;
  const _Badge({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(7),
      ),
      child: child,
    );
  }
}
