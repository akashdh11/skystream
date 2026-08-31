import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../shared/widgets/thumbnail_error_placeholder.dart';
import '../../../../core/models/tmdb_details.dart';
import '../../../../core/storage/history_repository.dart';
import 'provider_search_section.dart';
import 'episode_picker_sheet.dart';
import '../../../sources/presentation/plugin_sources_sheet.dart';

/// Desktop hero: backdrop, gradients, and first column (logo, metadata, overview, sources).
/// [child] is the rest of the scroll content (seasons, cast, trailers, stats, etc.).
class TmdbDetailsDesktopHero extends ConsumerWidget {
  const TmdbDetailsDesktopHero({
    super.key,
    required this.data,
    required this.isMovie,
    required this.child,
    this.source,
  });

  final TmdbDetails data;
  final bool isMovie;
  final Widget child;
  final String? source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scaffoldColor = theme.scaffoldBackgroundColor;
    final textColor = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withValues(alpha: 0.7);

    final title = data.title;
    final overview = data.overview;
    final logoUrl = data.logoUrl;
    final runtime = data.runtime;
    final hours = runtime ~/ 60;
    final minutes = runtime % 60;
    final durationText = hours > 0 ? '${hours}H ${minutes}M' : '${minutes}M';
    final releaseDate = data.releaseDateFull;
    final year = releaseDate.isNotEmpty ? releaseDate.split('-')[0] : '';
    final rating = data.voteAverage.toStringAsFixed(1);
    final genreText = data.genresStr;
    final certification = data.certification;
    final director = data.director;
    final backdropImageUrl = data.backdropImageUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
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
              imageUrl: backdropImageUrl,
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              // Bound decoded bitmap; H29 makes desktop/TV fetch `original`
              // backdrops which can be 3840 px wide.
              memCacheWidth:
                  (MediaQuery.sizeOf(context).width *
                          MediaQuery.devicePixelRatioOf(context))
                      .round(),
              errorWidget: (_, _, _) =>
                  ThumbnailErrorPlaceholder(label: title, isBackdrop: true),
            ),
          ),
        ),
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
        Positioned.fill(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: MediaQuery.sizeOf(context).width * 0.6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (logoUrl != null)
                        CachedNetworkImage(
                          imageUrl: logoUrl,
                          height: 200,
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.contain,
                          placeholder: (_, _) => Text(
                            title,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                        )
                      else
                        Text(
                          title,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                      const SizedBox(height: 12),
                      Consumer(
                        builder: (context, ref, _) {
                          final historyRepo = ref.watch(
                            historyRepositoryProvider,
                          );
                          final pos = historyRepo.getPosition(
                            data.id.toString(),
                          );
                          final dur = historyRepo.getDuration(
                            data.id.toString(),
                          );

                          if (pos > 0 && dur > 0) {
                            final progress = (pos / dur).clamp(0.0, 1.0);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 400,
                                  height: 6,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: textColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: Colors.transparent,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "${(progress * 100).toInt()}% watched",
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildTmdbLogo(),
                          _buildTopBadge(
                            context,
                            source == 'anilist'
                                ? (isMovie ? "MOVIE" : "ANIME")
                                : (isMovie ? "MOVIE" : "TV SHOW"),
                          ),
                          if (year.isNotEmpty)
                            _buildIconInfo(
                              context,
                              Icons.calendar_today_rounded,
                              year,
                              textColor,
                            ),
                          _buildIconInfo(
                            context,
                            Icons.star_rounded,
                            rating,
                            const Color(0xFF01B4E4),
                          ),
                          if (durationText.isNotEmpty)
                            _buildIconInfo(
                              context,
                              Icons.timer_outlined,
                              durationText,
                              textColor,
                            ),
                          if (certification.isNotEmpty)
                            _buildBorderedInfo(
                              context,
                              certification,
                              textColor,
                            ),
                          if (director != "Unknown")
                            _buildIconInfo(
                              context,
                              isMovie
                                  ? Icons.movie_creation_outlined
                                  : Icons.person_outline,
                              isMovie
                                  ? "Director: $director"
                                  : "Creator: $director",
                              textColor,
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        overview,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        genreText,
                        style: TextStyle(
                          color: textSecondary.withValues(alpha: 0.5),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        constraints: const BoxConstraints(
                          maxWidth: 600,
                        ),
                        child: ProviderSearchSection(
                          query: title,
                          compact: true,
                          parentMediaType: isMovie ? 'movie' : 'tv',
                          tmdbId: data.tmdbId,
                          imdbId: data.imdbId,
                          onViewAll: () {
                            if (isMovie) {
                              PluginSourcesSheet.open(context, data);
                            } else {
                              EpisodePickerSheet.open(
                                context,
                                movieId: data.id,
                                seasons: data.seasons,
                                target: data,
                                source: source,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTmdbLogo() {
    final isAnilist = source == 'anilist';
    if (isAnilist) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF02A9FF).withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(6),
        child: SvgPicture.asset(
          'assets/images/anilist_icon.svg',
          fit: BoxFit.contain,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF01B4E4), // TMDB Blue
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        "TMDB",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildTopBadge(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildIconInfo(
    BuildContext context,
    IconData icon,
    String text,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.5)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color.withValues(alpha: 0.8),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBorderedInfo(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border.all(color: color.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color.withValues(alpha: 0.7),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
