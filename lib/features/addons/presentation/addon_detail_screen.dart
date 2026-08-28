import 'package:cached_network_image/cached_network_image.dart';
import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/addons/data/addon_stream_service.dart';
import '../../../core/addons/models/addon_meta.dart';
import '../../../core/utils/responsive_breakpoints.dart';
import '../../../shared/widgets/cards_wrapper.dart';
import '../../../shared/widgets/desktop_scroll_wrapper.dart';
import '../../../shared/widgets/shimmer_placeholder.dart';
import '../../../shared/widgets/thumbnail_error_placeholder.dart';
import 'addon_providers.dart';
import 'addon_sources_sheet.dart';

/// Detail page for an add-on catalog entry, styled to match the TMDB Details Screen.
/// Metadata comes from a `meta` add-on, playback from `stream` add-ons.
class AddonDetailScreen extends ConsumerStatefulWidget {
  final String type;
  final String id;
  final String? addonUrl;

  const AddonDetailScreen({
    super.key,
    required this.type,
    required this.id,
    this.addonUrl,
  });

  @override
  ConsumerState<AddonDetailScreen> createState() => _AddonDetailScreenState();
}

class _AddonDetailScreenState extends ConsumerState<AddonDetailScreen> {
  int? _selectedSeason;
  int _selectedRangeIndex = 0;
  bool _isAscending = true;
  bool _isDescriptionExpanded = false;

  final ScrollController _scrollController = ScrollController();
  final ScrollController _episodesScrollController = ScrollController();
  final ValueNotifier<bool> _showAppBarTitle = ValueNotifier<bool>(false);
  final ValueNotifier<double> _titleOpacity = ValueNotifier<double>(0.0);
  final ValueNotifier<double> _contentOpacity = ValueNotifier<double>(1.0);
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _episodesScrollController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final metaAsync = ref.watch(
      addonMetaProvider(
        widget.type,
        widget.id,
        preferredAddonUrl: widget.addonUrl,
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: metaAsync.when(
        loading: () => _buildLoadingState(context),
        error: (error, _) => _buildErrorState(context, error.toString()),
        data: (meta) {
          if (meta == null) {
            return _buildErrorState(
              context,
              'No installed add-on could describe this title. Install a '
              'metadata add-on such as Cinemeta.',
            );
          }
          return _buildBody(context, meta);
        },
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);
    final isMovie = widget.type.toLowerCase() == 'movie';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
              height: 220,
              width: double.infinity,
              borderRadius: 12,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildTopBadge(context, 'ADD-ON'),
                const SizedBox(width: 12),
                _buildTopBadge(context, isMovie ? 'MOVIE' : 'SERIES'),
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
  }

  Widget _buildErrorState(BuildContext context, String text) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 56,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => ref.invalidate(
                      addonMetaProvider(
                        widget.type,
                        widget.id,
                        preferredAddonUrl: widget.addonUrl,
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: CircleAvatar(
              backgroundColor: theme.colorScheme.onSurface.withValues(
                alpha: 0.1,
              ),
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: theme.colorScheme.onSurface,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, AddonMeta meta) {
    final isDesktop = context.isDesktop || context.isTabletOrLarger;
    if (isDesktop) {
      return _buildDesktopLayout(context, meta);
    }
    return _buildMobileLayout(context, meta);
  }

  Widget _buildDesktopLayout(BuildContext context, AddonMeta meta) {
    final theme = Theme.of(context);
    final scaffoldColor = theme.scaffoldBackgroundColor;
    final textColor = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withValues(alpha: 0.7);

    final title = meta.name;
    final overview = meta.description ?? '';
    final logoUrl = meta.logo;
    final backdropImageUrl = meta.background ?? meta.poster ?? '';
    final year = meta.releaseInfo ?? '';
    final rating = meta.imdbRating ?? '';
    final runtime = meta.runtime ?? '';
    final genreText = meta.genres.join(' • ');
    final hasEpisodes = meta.videos.isNotEmpty;
    final seasons = meta.seasons;

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: textColor.withValues(alpha: 0.1),
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: textColor, size: 20),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (backdropImageUrl.isNotEmpty)
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
                        if (logoUrl != null && logoUrl.isNotEmpty)
                          _buildLogoWidget(
                            logoUrl,
                            title,
                            textColor,
                            isDesktop: true,
                          )
                        else
                          Text(
                            title.toUpperCase(),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 48,
                              fontFamily: 'RobotoCondensed',
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildTopBadge(
                              context,
                              meta.addonName.isNotEmpty
                                  ? meta.addonName.toUpperCase()
                                  : 'ADD-ON',
                            ),
                            _buildTopBadge(
                              context,
                              meta.isSeries ? 'SERIES' : 'MOVIE',
                            ),
                            if (year.isNotEmpty)
                              _buildIconInfo(
                                context,
                                Icons.calendar_today_rounded,
                                year,
                              ),
                            if (rating.isNotEmpty)
                              _buildIconInfo(
                                context,
                                Icons.star_rounded,
                                rating,
                                iconColor: Colors.amber,
                              ),
                            if (runtime.isNotEmpty)
                              _buildIconInfo(
                                context,
                                Icons.timer_outlined,
                                runtime,
                              ),
                            if (seasons.isNotEmpty && seasons.length > 1)
                              _buildIconInfo(
                                context,
                                Icons.layers_rounded,
                                '${seasons.length} Seasons',
                              ),
                          ],
                        ),
                        if (overview.isNotEmpty) ...[
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
                        ],
                        if (genreText.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            genreText,
                            style: TextStyle(
                              color: textSecondary.withValues(alpha: 0.6),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        _buildPlayButton(context, meta),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (hasEpisodes) ...[
                    _buildSeasonsAndEpisodesSection(context, meta),
                    const SizedBox(height: 32),
                  ],
                  if (meta.cast.isNotEmpty) ...[
                    _buildCastSection(context, meta.cast),
                    const SizedBox(height: 32),
                  ],
                  _buildDetailsTable(context, meta),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, AddonMeta meta) {
    final theme = Theme.of(context);
    final backdropImageUrl = meta.background ?? meta.poster ?? '';
    final title = meta.name;
    final overview = meta.description ?? '';
    final logoUrl = meta.logo;
    final year = meta.releaseInfo ?? '';
    final rating = meta.imdbRating ?? '';
    final runtime = meta.runtime ?? '';
    final hasEpisodes = meta.videos.isNotEmpty;
    final seasons = meta.seasons;

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
          backgroundColor: theme.scaffoldBackgroundColor,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: theme.colorScheme.onSurface.withValues(
                alpha: 0.1,
              ),
              radius: 18,
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: theme.colorScheme.onSurface,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).maybePop(),
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
                    color: theme.colorScheme.onSurface,
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
                    if (backdropImageUrl.isNotEmpty)
                      Transform.translate(
                        offset: Offset(0, parallaxOffset),
                        child: CachedNetworkImage(
                          imageUrl: backdropImageUrl,
                          fit: BoxFit.cover,
                          memCacheWidth:
                              (MediaQuery.sizeOf(context).width *
                                      MediaQuery.devicePixelRatioOf(context))
                                  .round(),
                          placeholder: (context, url) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                          errorWidget: (_, _, _) => ThumbnailErrorPlaceholder(
                            label: title,
                            isBackdrop: true,
                          ),
                        ),
                      ),
                    // 1. Scrim
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
                    // 2. Blend-into-page gradient
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            theme.scaffoldBackgroundColor.withValues(
                              alpha: 0.0,
                            ),
                            theme.scaffoldBackgroundColor.withValues(
                              alpha: 0.15,
                            ),
                            theme.scaffoldBackgroundColor.withValues(
                              alpha: 0.45,
                            ),
                            theme.scaffoldBackgroundColor.withValues(
                              alpha: 0.8,
                            ),
                            theme.scaffoldBackgroundColor,
                          ],
                          stops: const [0.0, 0.5, 0.75, 0.9, 1.0],
                        ),
                      ),
                    ),
                    // 3. Logo/Title and Genres on header
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
                                  if (logoUrl != null && logoUrl.isNotEmpty)
                                    _buildLogoWidget(
                                      logoUrl,
                                      title,
                                      theme.colorScheme.onSurface,
                                      isDesktop: false,
                                    )
                                  else
                                    Text(
                                      title.toUpperCase(),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface,
                                        fontSize: 36,
                                        fontFamily: 'RobotoCondensed',
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Text(
                                    meta.genres.isNotEmpty
                                        ? meta.genres.take(3).join(' • ')
                                        : (meta.isSeries
                                              ? 'TV Series'
                                              : 'Movie'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface
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

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Play Button
                _buildPlayButton(context, meta),
                const SizedBox(height: 16),

                // Metadata Row: [ADD-ON] [MOVIE/SERIES] Year Rating Runtime Seasons
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildTopBadge(
                      context,
                      meta.addonName.isNotEmpty
                          ? meta.addonName.toUpperCase()
                          : 'ADD-ON',
                    ),
                    _buildTopBadge(context, meta.isSeries ? 'SERIES' : 'MOVIE'),
                    if (year.isNotEmpty)
                      _buildIconInfo(
                        context,
                        Icons.calendar_today_rounded,
                        year,
                      ),
                    if (rating.isNotEmpty)
                      _buildIconInfo(
                        context,
                        Icons.star_rounded,
                        rating,
                        iconColor: Colors.amber,
                      ),
                    if (runtime.isNotEmpty)
                      _buildIconInfo(context, Icons.timer_outlined, runtime),
                    if (seasons.isNotEmpty && seasons.length > 1)
                      _buildIconInfo(
                        context,
                        Icons.layers_rounded,
                        '${seasons.length} Seasons',
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // Synopsis with Expansion
                if (overview.isNotEmpty) ...[
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
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.8,
                            ),
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
                                        ? 'Show Less'
                                        : 'Show More',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Icon(
                                    _isDescriptionExpanded
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    color: theme.colorScheme.onSurface,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Episodes Section (shown whenever episodes are available)
                if (hasEpisodes) ...[
                  _buildSeasonsAndEpisodesSection(context, meta),
                  const SizedBox(height: 24),
                ],

                // Cast Section
                if (meta.cast.isNotEmpty) ...[
                  _buildCastSection(context, meta.cast),
                  const SizedBox(height: 24),
                ],

                // Details Table
                _buildDetailsTable(context, meta),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayButton(BuildContext context, AddonMeta meta) {
    final cs = Theme.of(context).colorScheme;
    final item = meta.toMultimediaItem();

    final seasons = meta.seasons;
    final activeSeason =
        _selectedSeason ?? (seasons.isEmpty ? 1 : seasons.first);
    final episodes = meta.episodesForSeason(activeSeason);
    final firstVideo = episodes.isNotEmpty ? episodes.first : null;

    AddonStreamRequest requestFor({AddonVideo? video}) => AddonStreamRequest(
      type: meta.isSeries ? 'series' : 'movie',
      contentId: meta.id,
      videoId: video?.id,
      season: video?.season,
      episode: video?.episode,
      imdbId: meta.imdbId,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DpadFocusable(
        onSelect: () => AddonSourcesSheet.open(
          context,
          item: item,
          request: requestFor(video: firstVideo),
          episode: firstVideo?.toEpisode(),
          playlist: meta.videos,
        ),
        child: const SizedBox.shrink(),
        builder: (context, state, _) {
          final isFocused = state.focused;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isFocused ? Colors.white : Colors.transparent,
                width: 2.0,
              ),
            ),
            child: FilledButton.icon(
              onPressed: () => AddonSourcesSheet.open(
                context,
                item: item,
                request: requestFor(video: firstVideo),
                episode: firstVideo?.toEpisode(),
                playlist: meta.videos,
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 24),
              label: Text(
                meta.videos.length > 1 && firstVideo != null
                    ? 'Play S${firstVideo.season ?? 1} E${firstVideo.episode ?? 1}'
                    : 'Play from add-ons',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: isFocused
                    ? cs.primary
                    : cs.primary.withValues(alpha: 0.9),
                foregroundColor: cs.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                elevation: isFocused ? 6 : 2,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogoWidget(
    String logoUrl,
    String fallbackTitle,
    Color textColor, {
    required bool isDesktop,
  }) {
    if (logoUrl.toLowerCase().endsWith('.svg')) {
      return SvgPicture.network(
        logoUrl,
        width: isDesktop ? 280 : 220,
        height: isDesktop ? 140 : 100,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => Text(
          fallbackTitle.toUpperCase(),
          style: TextStyle(
            color: textColor,
            fontSize: isDesktop ? 48 : 36,
            fontFamily: 'RobotoCondensed',
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: logoUrl,
      width: isDesktop ? 280 : 220,
      height: isDesktop ? 140 : 100,
      fit: BoxFit.contain,
      alignment: isDesktop ? Alignment.centerLeft : Alignment.center,
      errorWidget: (_, _, _) => Text(
        fallbackTitle.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: isDesktop ? 48 : 36,
          fontFamily: 'RobotoCondensed',
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildTopBadge(BuildContext context, String label) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: primary.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: primary,
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
    final theme = Theme.of(context);
    final color =
        iconColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.7);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCastSection(BuildContext context, List<String> cast) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CAST',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cast.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final actor = cast[index];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.2,
                      ),
                      child: Text(
                        actor.isNotEmpty ? actor[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      actor,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
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

  Widget _buildSeasonsAndEpisodesSection(BuildContext context, AddonMeta meta) {
    final theme = Theme.of(context);
    final seasons = meta.seasons;
    final activeSeason =
        _selectedSeason ?? (seasons.isEmpty ? 1 : seasons.first);
    final episodes = meta.episodesForSeason(activeSeason);
    final item = meta.toMultimediaItem();

    const int batchSize = 20;
    final int totalEpisodes = episodes.length;
    final int batchCount = (totalEpisodes / batchSize).ceil();

    if (_selectedRangeIndex >= batchCount) {
      _selectedRangeIndex = 0;
    }

    final int start = _selectedRangeIndex * batchSize;
    final int end = (start + batchSize).clamp(0, totalEpisodes);
    List<AddonVideo> displayedEpisodes = episodes.isNotEmpty
        ? episodes.sublist(start, end)
        : <AddonVideo>[];

    if (!_isAscending) {
      displayedEpisodes = displayedEpisodes.reversed.toList();
    }

    AddonStreamRequest requestFor(AddonVideo video) => AddonStreamRequest(
      type: meta.isSeries ? 'series' : 'movie',
      contentId: meta.id,
      videoId: video.id,
      season: video.season,
      episode: video.episode,
      imdbId: meta.imdbId,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Season selector (only shown if multiple seasons exist)
        if (seasons.length > 1) ...[
          Text(
            'SEASONS',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: seasons.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final season = seasons[index];
                final isSelected = season == activeSeason;
                return DpadFocusable(
                  onSelect: () {
                    setState(() {
                      _selectedSeason = season;
                      _selectedRangeIndex = 0;
                    });
                  },
                  child: const SizedBox.shrink(),
                  builder: (context, state, _) {
                    final isFocused = state.focused;
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isFocused
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ChoiceChip(
                        label: Text('Season $season'),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _selectedSeason = season;
                            _selectedRangeIndex = 0;
                          });
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Episodes Header + Range Dropdown (if episodes > 20) + Sort Order Toggle
        Row(
          children: [
            Text(
              'EPISODES',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(width: 14),
            if (batchCount > 1) ...[
              Focus(
                child: Builder(
                  builder: (context) {
                    final isFocused = Focus.of(context).hasFocus;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isFocused ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: DropdownButton<int>(
                          value: _selectedRangeIndex,
                          dropdownColor: theme.colorScheme.surfaceContainerHigh,
                          underline: const SizedBox(),
                          elevation: 4,
                          borderRadius: BorderRadius.circular(12),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          items: List.generate(batchCount, (index) {
                            final rangeStart = index * batchSize + 1;
                            final rangeEnd = ((index + 1) * batchSize).clamp(
                              1,
                              totalEpisodes,
                            );
                            return DropdownMenuItem(
                              value: index,
                              child: Text('$rangeStart-$rangeEnd'),
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
              ),
              const SizedBox(width: 8),
            ],
            Material(
              color: Colors.transparent,
              child: Ink(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    setState(() {
                      _isAscending = !_isAscending;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Icon(
                      Icons.swap_vert_rounded,
                      size: 22,
                      color: _isAscending
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // TMDB-Style Horizontal Episode Cards List
        if (displayedEpisodes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              'No episodes listed for this title.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          SizedBox(
            height: 240,
            child: DesktopScrollWrapper(
              controller: _episodesScrollController,
              child: ListView.separated(
                clipBehavior: Clip.none,
                controller: _episodesScrollController,
                scrollDirection: Axis.horizontal,
                itemCount: displayedEpisodes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final video = displayedEpisodes[index];
                  final episode = video.toEpisode();
                  final episodeNum = video.episode ?? (start + index + 1);
                  final episodeTitle = video.title.isNotEmpty
                      ? video.title
                      : 'Episode $episodeNum';

                  return CardsWrapper(
                    onTap: () => AddonSourcesSheet.open(
                      context,
                      item: item,
                      request: requestFor(video),
                      episode: episode,
                      playlist: meta.videos,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 290,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child:
                                video.thumbnail == null ||
                                    video.thumbnail!.isEmpty
                                ? Container(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    child: const Center(
                                      child: Icon(
                                        Icons.play_circle_outline_rounded,
                                        size: 36,
                                      ),
                                    ),
                                  )
                                : CachedNetworkImage(
                                    imageUrl: video.thumbnail!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    placeholder: (context, url) =>
                                        ShimmerPlaceholder.rectangular(
                                          borderRadius: 10,
                                        ),
                                    errorWidget: (_, _, _) =>
                                        ThumbnailErrorPlaceholder(
                                          label: episodeTitle,
                                        ),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'E$episodeNum • $episodeTitle',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        meta.addonName.isNotEmpty
                                            ? meta.addonName.toUpperCase()
                                            : 'ADD-ON',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (video.released != null &&
                                        video.released!.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        video.released!.split('T').first,
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.7),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (video.overview != null &&
                                    video.overview!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    video.overview!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
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
          ),
      ],
    );
  }

  Widget _buildDetailsTable(BuildContext context, AddonMeta meta) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          meta.isSeries ? 'SHOW DETAILS' : 'MOVIE DETAILS',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 16),
        _buildDetailRow('Type', meta.isSeries ? 'Series' : 'Movie', theme),
        if (meta.releaseInfo != null && meta.releaseInfo!.isNotEmpty)
          _buildDetailRow('Release', meta.releaseInfo!, theme),
        if (meta.runtime != null && meta.runtime!.isNotEmpty)
          _buildDetailRow('Runtime', meta.runtime!, theme),
        if (meta.addonName.isNotEmpty)
          _buildDetailRow('Add-on Source', meta.addonName, theme),
        if (meta.imdbId != null && meta.imdbId!.isNotEmpty)
          _buildDetailRow('IMDb ID', meta.imdbId!, theme),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
