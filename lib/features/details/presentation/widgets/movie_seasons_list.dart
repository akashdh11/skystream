import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/utils/image_fallbacks.dart';
import '../../../../shared/widgets/cards_wrapper.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../../../../shared/widgets/thumbnail_error_placeholder.dart';
import '../../../../shared/widgets/desktop_scroll_wrapper.dart';
import '../../../../core/utils/responsive_breakpoints.dart';
import '../../../../core/models/tmdb_details.dart';
import '../tmdb_details_controller.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../sources/presentation/plugin_sources_sheet.dart';

class MovieSeasonsList extends ConsumerStatefulWidget {
  final int movieId;
  final List<TmdbSeason> seasons;
  final Color? textColor;
  final String? source;
  final String title;
  final String? posterUrl;
  final String? bannerUrl;
  final String? overview;
  final String? releaseDateFull;
  final String? imdbId;

  const MovieSeasonsList({
    super.key,
    required this.movieId,
    required this.seasons,
    this.textColor,
    this.source,
    this.title = '',
    this.posterUrl,
    this.bannerUrl,
    this.overview,
    this.releaseDateFull,
    this.imdbId,
  });

  @override
  ConsumerState<MovieSeasonsList> createState() => _MovieSeasonsListState();
}

class _MovieSeasonsListState extends ConsumerState<MovieSeasonsList> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _episodesScrollController = ScrollController();
  final FocusNode _seasonDropdownFocusNode = FocusNode();
  final FocusNode _rangeDropdownFocusNode = FocusNode();
  int _selectedRangeIndex = 0;

  @override
  void dispose() {
    _seasonDropdownFocusNode.dispose();
    _rangeDropdownFocusNode.dispose();
    _scrollController.dispose();
    _episodesScrollController.dispose();
    super.dispose();
  }

  Widget _buildTmdbLogo(BuildContext context) {
    final isAnilist = widget.source == 'anilist';
    if (isAnilist) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: const Color(0xFF02A9FF).withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(4),
        child: SvgPicture.asset(
          'assets/images/anilist_icon.svg',
          fit: BoxFit.contain,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0d253f),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        AppLocalizations.of(context)!.tmdb,
        style: const TextStyle(
          color: Color(0xFF90cea1),
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.seasons.isEmpty) return const SizedBox.shrink();

    final isDesktop = context.isDesktop;

    if (isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppLocalizations.of(context)!.episodes,
                style: TextStyle(
                  color: widget.textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 20),
              ListenableBuilder(
                listenable: _seasonDropdownFocusNode,
                builder: (context, _) {
                  final isFocused = _seasonDropdownFocusNode.hasFocus;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: isFocused
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            )
                          : null,
                    ),
                    child: Consumer(
                      builder: (context, ref, _) {
                        return DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            focusNode: _seasonDropdownFocusNode,
                            value: ref
                                .watch(
                                  tmdbDetailsControllerProvider(
                                    widget.movieId,
                                    source: widget.source,
                                  ),
                                )
                                .selectedSeason,
                            dropdownColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainer,
                            style: TextStyle(color: widget.textColor),
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: widget.textColor,
                            ),
                            items: widget.seasons.map<DropdownMenuItem<int>>((s) {
                              final num = s.seasonNumber;
                              final count = s.episodeCount;
                              return DropdownMenuItem(
                                value: num,
                                child: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.seasonWithEpisodes(num, count),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedRangeIndex = 0;
                                });
                                ref
                                    .read(
                                      tmdbDetailsControllerProvider(
                                        widget.movieId,
                                        source: widget.source,
                                      ).notifier,
                                    )
                                    .fetchEpisodes(val, source: widget.source);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDesktopEpisodesList(context),
          const SizedBox(height: 50),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.seasons,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: ListView.separated(
              clipBehavior: Clip.none,
              scrollDirection: Axis.horizontal,
              itemCount: widget.seasons.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final season = widget.seasons[index];
                final seasonNum = season.seasonNumber;

                return Consumer(
                  builder: (context, ref, _) {
                    final isSelected =
                        ref
                            .watch(
                              tmdbDetailsControllerProvider(
                                widget.movieId,
                                source: widget.source,
                              ),
                            )
                            .selectedSeason ==
                        seasonNum;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedRangeIndex = 0;
                        });
                        ref
                            .read(
                              tmdbDetailsControllerProvider(
                                widget.movieId,
                                source: widget.source,
                              ).notifier,
                            )
                            .fetchEpisodes(seasonNum, source: widget.source);
                      },
                      child: Container(
                        width: 120,
                        decoration: BoxDecoration(
                          border: isSelected
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                )
                              : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CachedNetworkImage(
                                  imageUrl: season.posterImageUrl ?? '',
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorWidget: (_, _, _) =>
                                      ThumbnailErrorPlaceholder(
                                        label: season.name,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              season.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: widget.textColor,
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            Text(
                              AppLocalizations.of(
                                context,
                              )!.episodeCountOnly(season.episodeCount),
                              style: TextStyle(
                                color: widget.textColor?.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          _buildMobileEpisodesList(context),
          const SizedBox(height: 32),
        ],
      );
    }
  }

  Widget _buildDesktopEpisodesList(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        if (ref
                .watch(
                  tmdbDetailsControllerProvider(
                    widget.movieId,
                    source: widget.source,
                  ),
                )
                .episodesFuture ==
            null) {
          return const SizedBox.shrink();
        }

        return FutureBuilder<Map<String, dynamic>?>(
          future: ref
              .watch(
                tmdbDetailsControllerProvider(
                  widget.movieId,
                  source: widget.source,
                ),
              )
              .episodesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: AppLoadingIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const SizedBox.shrink();
            }
            final episodes = List<Map<String, dynamic>>.from(
              (snapshot.data!['episodes'] as List?) ?? const <dynamic>[],
            );
            if (episodes.isEmpty) return const SizedBox.shrink();

            return SizedBox(
              height: 240,
              child: DesktopScrollWrapper(
                controller: _scrollController,
                child: ListView.separated(
                  clipBehavior: Clip.none,
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: episodes.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 20),
                  itemBuilder: (context, index) {
                    final ep = episodes[index];
                    final imageUrl = AppImageFallbacks.tmdbStill(
                      ep['still_path'] as String?,
                      label: (ep['name'] as String?) ?? 'Episode',
                    );
                    final voteAverage =
                        (ep['vote_average'] as num?)?.toDouble() ?? 0.0;
                    final runtime = ep['runtime'] as int? ?? 0;
                    final hours = runtime ~/ 60;
                    final minutes = runtime % 60;
                    final runtimeText = hours > 0
                        ? '${hours}h ${minutes}m'
                        : '${minutes}m';

                    return CardsWrapper(
                      onTap: () {
                        final controller = ref.read(
                          tmdbDetailsControllerProvider(
                            widget.movieId,
                            source: widget.source,
                          ),
                        );
                        final target = MultimediaItem(
                          title: widget.title,
                          url: '',
                          posterUrl: widget.posterUrl ?? '',
                          bannerUrl: widget.bannerUrl,
                          description: widget.overview,
                          contentType: MultimediaContentType.series,
                          year: int.tryParse(
                            (widget.releaseDateFull ?? '').split('-').first,
                          ),
                          tmdbId: widget.movieId,
                          imdbId: widget.imdbId,
                        );
                        final episode = Episode(
                          name: (ep['name'] as String?) ?? 'Episode',
                          url: '',
                          season: controller.selectedSeason,
                          episode: (ep['episode_number'] as int?) ?? 0,
                        );
                        PluginSourcesSheet.open(
                          context,
                          target,
                          episode: episode,
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 300,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: CachedNetworkImage(
                                imageUrl: imageUrl ?? '',
                                fit: BoxFit.cover,
                                width: double.infinity,
                                // TMDB still source is w500 — already matches
                                // 300 dp card × ~2 DPR. Let CNI decode native.
                                placeholder: (context, url) =>
                                    ShimmerPlaceholder.rectangular(
                                      borderRadius: 8,
                                    ),
                                errorWidget: (_, _, _) =>
                                    ThumbnailErrorPlaceholder(
                                      label:
                                          (ep['name'] as String?) ?? 'Episode',
                                    ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "E${ep['episode_number']} • ${ep['name']}",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      _buildTmdbLogo(context),
                                      const SizedBox(width: 8),
                                      Text(
                                        voteAverage.toStringAsFixed(1),
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      if (runtime > 0)
                                        Text(
                                          runtimeText,
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.7),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    (ep['overview'] as String?) ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMobileEpisodesList(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        if (ref
                .watch(
                  tmdbDetailsControllerProvider(
                    widget.movieId,
                    source: widget.source,
                  ),
                )
                .episodesFuture ==
            null) {
          return const SizedBox.shrink();
        }

        return FutureBuilder<Map<String, dynamic>?>(
          future: ref
              .watch(
                tmdbDetailsControllerProvider(
                  widget.movieId,
                  source: widget.source,
                ),
              )
              .episodesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: AppLoadingIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const SizedBox.shrink();
            }
            final episodes = List<Map<String, dynamic>>.from(
              (snapshot.data!['episodes'] as List?) ?? const <dynamic>[],
            );
            if (episodes.isEmpty) return const SizedBox.shrink();

            const int batchSize = 10;
            final int totalEpisodes = episodes.length;
            final int batchCount = (totalEpisodes / batchSize).ceil();

            if (_selectedRangeIndex >= batchCount) {
              _selectedRangeIndex = 0;
            }

            final int start = _selectedRangeIndex * batchSize;
            final int end = (start + batchSize).clamp(0, totalEpisodes);
            final displayedEpisodes = episodes.sublist(start, end);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.episodes,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (batchCount > 1)
                      ListenableBuilder(
                        listenable: _rangeDropdownFocusNode,
                        builder: (context, _) {
                          final isFocused = _rangeDropdownFocusNode.hasFocus;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(8),
                              border: isFocused
                                  ? Border.all(
                                      color: Theme.of(context).colorScheme.primary,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                focusNode: _rangeDropdownFocusNode,
                                value: _selectedRangeIndex,
                                dropdownColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainer,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                items: List.generate(batchCount, (index) {
                                  final rangeStart = index * batchSize + 1;
                                  final rangeEnd = ((index + 1) * batchSize).clamp(
                                    1,
                                    totalEpisodes,
                                  );
                                  return DropdownMenuItem(
                                    value: index,
                                    child: Text("$rangeStart-$rangeEnd"),
                                  );
                                }),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedRangeIndex = val;
                                    });
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayedEpisodes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final ep = displayedEpisodes[index];
                    final imageUrl = AppImageFallbacks.tmdbStill(
                      ep['still_path'] as String?,
                      label: (ep['name'] as String?) ?? 'Episode',
                    );
                    final voteAverage =
                        (ep['vote_average'] as num?)?.toDouble() ?? 0.0;
                    final runtime = (ep['runtime'] as int?) ?? 0;
                    final hours = runtime ~/ 60;
                    final minutes = runtime % 60;
                    final runtimeText = hours > 0
                        ? '${hours}h ${minutes}m'
                        : '${minutes}m';

                    return CardsWrapper(
                      onTap: () {
                        final controller = ref.read(
                          tmdbDetailsControllerProvider(
                            widget.movieId,
                            source: widget.source,
                          ),
                        );
                        final target = MultimediaItem(
                          title: widget.title,
                          url: '',
                          posterUrl: widget.posterUrl ?? '',
                          bannerUrl: widget.bannerUrl,
                          description: widget.overview,
                          contentType: MultimediaContentType.series,
                          year: int.tryParse(
                            (widget.releaseDateFull ?? '').split('-').first,
                          ),
                          tmdbId: widget.movieId,
                          imdbId: widget.imdbId,
                        );
                        final episode = Episode(
                          name: (ep['name'] as String?) ?? 'Episode',
                          url: '',
                          season: controller.selectedSeason,
                          episode: (ep['episode_number'] as int?) ?? 0,
                        );
                        PluginSourcesSheet.open(
                          context,
                          target,
                          episode: episode,
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: imageUrl ?? '',
                                width: 120,
                                height: 68,
                                // Skip memCacheWidth — source w500 already
                                // matches 120 dp × ~3 DPR ~ 360 px target.
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) =>
                                    ThumbnailErrorPlaceholder(
                                      label:
                                          (ep['name'] as String?) ?? 'Episode',
                                      iconSize: 24,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${ep['episode_number']}. ${ep['name']}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      _buildTmdbLogo(context),
                                      const SizedBox(width: 8),
                                      Text(
                                        voteAverage.toStringAsFixed(1),
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      if (runtime > 0)
                                        Text(
                                          runtimeText,
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.7),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    (ep['overview'] as String?) ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
