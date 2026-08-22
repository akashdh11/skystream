import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/tmdb_details.dart';
import 'package:intl/intl.dart';
import '../../../../core/storage/history_repository.dart';
import '../../../../core/utils/responsive_breakpoints.dart';
import '../data/tmdb_details_provider.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';

import 'widgets/tmdb_details_desktop_hero.dart';
import 'widgets/provider_search_section.dart';
import 'widgets/tmdb_details_stats_section.dart';
import 'widgets/movie_cast_list.dart';
import '../data/lightweight_details_provider.dart';
import 'widgets/movie_trailers_carousel.dart';
import 'widgets/movie_production_companies.dart';
import 'widgets/movie_seasons_list.dart';
import 'widgets/episode_picker_sheet.dart';
import '../../sources/presentation/plugin_sources_sheet.dart';
import '../../../../shared/widgets/thumbnail_error_placeholder.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';

class TmdbMovieDetailsScreen extends ConsumerStatefulWidget {
  final int movieId;
  final String mediaType; // 'movie' or 'tv'
  final String? heroTag;
  final String? placeholderPoster;
  final String? source;

  const TmdbMovieDetailsScreen({
    super.key,
    required this.movieId,
    this.mediaType = 'movie',
    this.heroTag,
    this.placeholderPoster,
    this.source,
  });

  @override
  ConsumerState<TmdbMovieDetailsScreen> createState() =>
      _TmdbMovieDetailsScreenState();
}

class _TmdbMovieDetailsScreenState
    extends ConsumerState<TmdbMovieDetailsScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;
  bool _isDescriptionExpanded = false;
  late ScrollController _scrollController;
  final ValueNotifier<bool> _showAppBarTitle = ValueNotifier<bool>(false);
  final ValueNotifier<double> _titleOpacity = ValueNotifier<double>(0.0);
  final ValueNotifier<double> _contentOpacity = ValueNotifier<double>(1.0);
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0.0);

  late final ScrollController _castScrollController;
  late final ScrollController _trailerScrollController;

  late final ScrollController _episodeScrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _castScrollController = ScrollController();
    _trailerScrollController = ScrollController();

    _episodeScrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _castScrollController.dispose();
    _trailerScrollController.dispose();

    _episodeScrollController.dispose();
    _showAppBarTitle.dispose();
    _titleOpacity.dispose();
    _contentOpacity.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;

    final show = offset > 450;
    if (show != _showAppBarTitle.value) {
      _showAppBarTitle.value = show;
    }

    final newTitleOpacity = ((offset - 300) / 100).clamp(0.0, 1.0);
    if (newTitleOpacity != _titleOpacity.value) {
      _titleOpacity.value = newTitleOpacity;
    }

    final newContentOpacity = (1.0 - (offset / 300)).clamp(0.0, 1.0);
    if (newContentOpacity != _contentOpacity.value) {
      _contentOpacity.value = newContentOpacity;
    }

    _scrollOffset.value = offset;
  }

  /// Movies open the sources sheet straight away; a series asks which episode
  /// first. The button used to be rendered only `if (isMovie)`, so every
  /// series poster looked like it had no plugin playback at all.
  void _openPluginSources(TmdbDetails data, bool isMovie) {
    if (isMovie) {
      PluginSourcesSheet.open(context, data);
      return;
    }
    final seasons = data.seasons;
    EpisodePickerSheet.open(
      context,
      movieId: widget.movieId,
      seasons: seasons,
      target: data,
      source: widget.source,
    );
  }

  @override
  Widget build(BuildContext context) {
    final params = MovieDetailsParams(
      widget.movieId,
      widget.mediaType,
      source: widget.source,
    );
    final detailsAsync = ref.watch(tmdbDetailsProvider(params));
    final fastDetailsAsync = ref.watch(lightweightDetailsProvider(params));

    // Prioritize full data, but use fast data if full is still loading
    final data = detailsAsync.asData?.value ?? fastDetailsAsync.asData?.value;
    final isHeavyLoading = detailsAsync.isLoading;
    final hasAnyData = data != null;

    final content = hasAnyData
        ? (context.isDesktop
              ? _buildDesktopLayout(data, isHeavyLoading)
              : _buildMobileLayout(data, isHeavyLoading))
        : detailsAsync.when(
            skipLoadingOnReload: false,
            skipLoadingOnRefresh: false,
            data: (data) => const SizedBox.shrink(), // Handled by hasAnyData
            loading: () {
              final isMovie = widget.mediaType == 'movie';
              return Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: const BackButton(),
                ),
                body: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerPlaceholder.rectangular(
                        height: 200,
                        width: double.infinity,
                        borderRadius: 12,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          _buildTmdbLogo(),
                          const SizedBox(width: 12),
                          _buildTopBadge(
                            context,
                            isMovie
                                ? l10n.movie.toUpperCase()
                                : l10n.tvShow.toUpperCase(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ShimmerPlaceholder.rectangular(
                        height: 30,
                        width: 250,
                        borderRadius: 6,
                      ),
                      const SizedBox(height: 16),
                      ShimmerPlaceholder.rectangular(
                        height: 100,
                        width: double.infinity,
                        borderRadius: 12,
                      ),
                    ],
                  ),
                ),
              );
            },
            error: (e, st) => Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: const BackButton(),
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.failedToLoadContent,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () =>
                          ref.invalidate(tmdbDetailsProvider(params)),
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
            ),
          );

    final scaffold = Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: content,
    );

    return scaffold;
  }

  Widget _buildDesktopLayout(TmdbDetails data, bool isHeavyLoading) {
    final isMovie = widget.mediaType == 'movie';
    final seasons = data.seasons;
    final cast = data.tmdbCast;
    final trailers = data.tmdbTrailers;
    final productionCompanies = data.productionCompanies;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scaffoldColor = theme.scaffoldBackgroundColor;
    final textColor = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withValues(alpha: 0.7);

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
          style: IconButton.styleFrom(
            backgroundColor: isDark ? Colors.black45 : Colors.white54,
            foregroundColor: textColor,
          ),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: TmdbDetailsDesktopHero(
        data: data,
        isMovie: isMovie,
        source: widget.source,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 60),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FilledButton.icon(
                onPressed: () => _openPluginSources(data, isMovie),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Play from plugins'),
              ),
            ),
            if (!isMovie) ...[
              MovieSeasonsList(
                movieId: widget.movieId,
                seasons: seasons,
                textColor: textColor,
                source: widget.source,
                title: data.title,
                posterUrl: data.posterUrl,
                bannerUrl: data.bannerUrl,
                overview: data.overview,
                releaseDateFull: data.releaseDateFull,
                imdbId: data.imdbId,
              ),
            ],
            if (isHeavyLoading || cast.isNotEmpty) ...[
              MovieCastList(
                cast: cast,
                isLoading: isHeavyLoading,
                textColor: textColor,
                textSecondary: textSecondary,
              ),
            ],
            if (isHeavyLoading || trailers.isNotEmpty) ...[
              MovieTrailersCarousel(
                trailers: trailers,
                isLoading: isHeavyLoading,
                textColor: textColor,
              ),
            ],
            if (isHeavyLoading || productionCompanies.isNotEmpty) ...[
              MovieProductionCompanies(
                productionCompanies: productionCompanies,
                isLoading: isHeavyLoading,
                textColor: textColor,
                textSecondary: textSecondary,
              ),
            ],
            TmdbDetailsStatsSection(data: data, isMovie: isMovie),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(TmdbDetails data, bool isHeavyLoading) {
    final isMovie = widget.mediaType == 'movie';

    final backdropImageUrl = data.backdropImageUrl;
    final title = data.title;
    final overview = data.overview;

    final tagline = data.tagline;
    final runtime = data.runtime;
    final releaseDate = data.releaseDateFull;
    final status = data.tmdbStatus;
    final budget = data.budget;
    final genres = data.genres;
    final cast = data.tmdbCast;
    final productionCompanies = data.productionCompanies;
    final trailers = data.tmdbTrailers;

    final hours = runtime ~/ 60;
    final minutes = runtime % 60;
    final durationText = hours > 0 ? '${hours}H ${minutes}M' : '${minutes}M';
    final year = releaseDate.isNotEmpty ? releaseDate.split('-')[0] : '';
    final rating = data.voteAverage.toStringAsFixed(1);

    final certification = data.certification;
    final director = data.director;
    final logoUrl = data.logoUrl;

    // The expanded hero is designed for portrait. In landscape phones
    // (~360 dp tall) a 550 dp expanded header overflows the entire screen,
    // forcing the user to scroll past nothing-but-AppBar before reaching
    // any content. Clamp by orientation: portrait keeps the original
    // 550 dp; landscape uses ~80% of available height, bounded so the
    // hero stays meaningful on tiny screens and doesn't dominate on tall
    // foldables.
    final mq = MediaQuery.sizeOf(context);
    final isLandscape = mq.width > mq.height;
    final double expandedHeaderHeight = isLandscape
        ? (mq.height * 0.80).clamp(220.0, 400.0)
        : 550.0;

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverAppBar(
          expandedHeight: expandedHeaderHeight,
          pinned: true,
          backgroundColor: Theme.of(
            context,
          ).scaffoldBackgroundColor, // Theme aware
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.1),
              radius: 18,
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                onPressed: () => context.pop(),
              ),
            ),
          ),
          title: ValueListenableBuilder<double>(
            valueListenable: _titleOpacity,
            builder: (context, opacity, child) {
              if (opacity <= 0) return const SizedBox.shrink();
              return Opacity(
                opacity: opacity,
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: 1.0,
                  ),
                ),
              );
            },
          ),
          centerTitle: false,
          flexibleSpace: FlexibleSpaceBar(
            background: ValueListenableBuilder<double>(
              valueListenable: _scrollOffset,
              builder: (context, offset, child) {
                final contentOffset = -offset * 0.4;
                final parallaxOffset = -offset * 0.1;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Transform.translate(
                      offset: Offset(0, parallaxOffset),
                      child: CachedNetworkImage(
                        imageUrl: backdropImageUrl,
                        fit: BoxFit.cover,
                        // Bound the decoded bitmap to display pixels. After
                        // H29, TV / desktop fetches `original`-size backdrops
                        // (~3840 px on 4K) — decoding at source would cost
                        // ~33 MB per image and starve the image cache.
                        memCacheWidth:
                            (MediaQuery.sizeOf(context).width *
                                    MediaQuery.devicePixelRatioOf(context))
                                .round(),
                        placeholder: (context, url) => Container(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                        ),
                        errorWidget: (_, _, _) => ThumbnailErrorPlaceholder(
                          label: title,
                          isBackdrop: true,
                        ),
                      ),
                    ),
                    // 1. Legibility Scrim: Fixed dark-tinted overlay at the bottom of the backdrop
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.65),
                          ],
                          stops: const [0.4, 1.0],
                        ),
                      ),
                    ),
                    // 2. Blend-into-page transition: Theme-aware eased fade to surface
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Theme.of(
                              context,
                            ).scaffoldBackgroundColor.withValues(alpha: 0.0),
                            Theme.of(
                              context,
                            ).scaffoldBackgroundColor.withValues(alpha: 0.15),
                            Theme.of(
                              context,
                            ).scaffoldBackgroundColor.withValues(alpha: 0.45),
                            Theme.of(
                              context,
                            ).scaffoldBackgroundColor.withValues(alpha: 0.8),
                            Theme.of(context).scaffoldBackgroundColor,
                          ],
                          stops: const [0.0, 0.5, 0.75, 0.9, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 20,
                      child: ValueListenableBuilder<double>(
                        valueListenable: _contentOpacity,
                        builder: (context, opacity, child) {
                          return Transform.translate(
                            offset: Offset(0, contentOffset),
                            child: Opacity(
                              opacity: opacity,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (logoUrl != null) ...[
                                    if (logoUrl.toLowerCase().endsWith('.svg'))
                                      SvgPicture.network(
                                        logoUrl,
                                        width: 280,
                                        height: 120,
                                        fit: BoxFit.contain,
                                        placeholderBuilder: (_) => Text(
                                          title.toUpperCase(),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                            fontSize: 40,
                                            fontFamily: 'RobotoCondensed',
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      )
                                    else
                                      CachedNetworkImage(
                                        imageUrl: logoUrl,
                                        width: 280,
                                        height: 120,
                                        fit: BoxFit.contain,
                                        alignment: Alignment.center,
                                        errorWidget: (_, _, _) => Text(
                                          title.toUpperCase(),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                            fontSize: 40,
                                            fontFamily: 'RobotoCondensed',
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ),
                                  ] else
                                    Text(
                                      title.toUpperCase(),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        fontSize: 40,
                                        fontFamily: 'RobotoCondensed',
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Text(
                                    genres.isNotEmpty
                                        ? genres.take(3).join(' • ')
                                        : (isMovie ? 'Movie' : 'TV Show'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        // 2. Metadata, Synopsis, Cast, Production, Trailers, Details
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cross-plugin stream launcher + provider results
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: FilledButton.icon(
                    onPressed: () => _openPluginSources(data, isMovie),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Play from plugins'),
                  ),
                ),
                ProviderSearchSection(
                  query: title,
                  parentMediaType: isMovie ? 'movie' : 'tv',
                  tmdbId: data.tmdbId,
                  imdbId: data.imdbId,
                ),
                const SizedBox(height: 16),
                Consumer(
                  builder: (context, ref, _) {
                    final historyRepo = ref.watch(historyRepositoryProvider);
                    final pos = historyRepo.getPosition(data.id.toString());
                    final dur = historyRepo.getDuration(data.id.toString());

                    if (pos > 0 && dur > 0) {
                      final progress = (pos / dur).clamp(0.0, 1.0);
                      final theme = Theme.of(context);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              height: 6,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.1,
                                ),
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
                              l10n.percentWatched((progress * 100).toInt()),
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 8),

                // Metadata Row: [TMDB] MOVIE/TV  2026  1H 56M  [PG-13]
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildTmdbLogo(),
                    _buildTopBadge(
                      context,
                      widget.source == 'anilist'
                          ? (isMovie ? "MOVIE" : "ANIME")
                          : (isMovie
                                ? l10n.movie.toUpperCase()
                                : l10n.tvShow.toUpperCase()),
                    ),
                    _buildIconInfo(context, Icons.calendar_today_rounded, year),
                    _buildIconInfo(
                      context,
                      Icons.star_rounded,
                      rating,
                      iconColor: const Color(0xFF01B4E4),
                    ),
                    if (runtime > 0)
                      _buildIconInfo(
                        context,
                        Icons.timer_outlined,
                        durationText,
                      ),
                    if (certification.isNotEmpty)
                      _buildBorderedInfo(context, certification),
                    if (!isMovie && data.seasons.isNotEmpty)
                      _buildIconInfo(
                        context,
                        Icons.layers_rounded,
                        l10n.seasonsCount(data.seasons.length),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Director / Creator
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 15,
                    ),
                    children: [
                      TextSpan(
                        text: isMovie
                            ? "${l10n.director}: "
                            : "${l10n.creator}: ",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      TextSpan(text: director),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Synopsis with Expansion
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        overview,
                        maxLines: _isDescriptionExpanded ? null : 3,
                        overflow: _isDescriptionExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.8),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      if (overview.length > 150)
                        GestureDetector(
                          onTap: () => setState(
                            () => _isDescriptionExpanded =
                                !_isDescriptionExpanded,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              children: [
                                Text(
                                  _isDescriptionExpanded
                                      ? l10n.showLess
                                      : l10n.showMore,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Icon(
                                  _isDescriptionExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Cast Section
                if (isHeavyLoading || cast.isNotEmpty) ...[
                  MovieCastList(cast: cast, isLoading: isHeavyLoading),
                ],

                // Production Section
                if (isHeavyLoading || productionCompanies.isNotEmpty) ...[
                  MovieProductionCompanies(
                    productionCompanies: productionCompanies,
                    isLoading: isHeavyLoading,
                  ),
                ],

                // Trailers Section
                if (isHeavyLoading || trailers.isNotEmpty) ...[
                  MovieTrailersCarousel(
                    trailers: trailers,
                    isLoading: isHeavyLoading,
                  ),
                ],

                if (!isMovie &&
                    (isHeavyLoading || data.seasons.isNotEmpty)) ...[
                  MovieSeasonsList(
                    movieId: widget.movieId,
                    seasons: data.seasons,
                    source: widget.source,
                    title: data.title,
                    posterUrl: data.posterUrl,
                    bannerUrl: data.bannerUrl,
                    overview: data.overview,
                    releaseDateFull: data.releaseDateFull,
                    imdbId: data.imdbId,
                  ),
                ],

                // Movie Details Table
                Text(
                  isMovie
                      ? l10n.movieDetails.toUpperCase()
                      : l10n.showDetails.toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 16),
                if (tagline.isNotEmpty)
                  _buildDetailRow(l10n.tagline, "\"$tagline\""),
                _buildDetailRow(l10n.status, status),
                _buildDetailRow(
                  isMovie ? l10n.releaseDate : l10n.firstAirDate,
                  () {
                    final parsed = DateTime.tryParse(releaseDate);
                    if (parsed != null) {
                      return DateFormat('MMMM d, yyyy').format(parsed);
                    }
                    return releaseDate.isNotEmpty ? releaseDate : l10n.unknown;
                  }(),
                ),
                if (budget > 0)
                  _buildDetailRow(
                    l10n.budgetLabel,
                    NumberFormat.currency(
                      symbol: '\$',
                      decimalDigits: 0,
                    ).format(budget),
                  ),
                _buildDetailRow(l10n.originCountry, data.originCountry),
                _buildDetailRow(l10n.originalLanguage, data.originalLanguage),

                const SizedBox(height: 32),

                // Safe Area padding

                // Safe Area padding
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTmdbLogo() {
    final isAnilist = widget.source == 'anilist';
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
        Text(
          text,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.8),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBorderedInfo(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
