import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/addons/data/addon_stream_service.dart';
import '../../../core/addons/models/addon_meta.dart';
import 'addon_providers.dart';
import 'addon_sources_sheet.dart';

/// Detail page for an add-on catalog entry. Metadata comes from a `meta`
/// add-on, playback from `stream` add-ons — no plugin is consulted.
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
  int? _season;

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
      body: metaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _message(context, error.toString()),
        data: (meta) {
          if (meta == null) {
            return _message(
              context,
              'No installed add-on could describe this title. Install a '
              'metadata add-on such as Cinemeta.',
            );
          }
          return _body(context, meta);
        },
      ),
    );
  }

  Widget _message(BuildContext context, String text) {
    return SafeArea(
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(text, textAlign: TextAlign.center),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: IconButton.filledTonal(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, AddonMeta meta) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final item = meta.toMultimediaItem();
    final seasons = meta.seasons;
    final activeSeason = _season ?? (seasons.isEmpty ? 1 : seasons.first);
    final episodes = meta.episodesForSeason(activeSeason);

    AddonStreamRequest requestFor({AddonVideo? video}) => AddonStreamRequest(
      type: meta.isSeries ? 'series' : 'movie',
      contentId: meta.id,
      videoId: video?.id,
      season: video?.season,
      episode: video?.episode,
      imdbId: meta.imdbId,
    );

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 250,
          pinned: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (meta.background != null)
                  CachedNetworkImage(
                    imageUrl: meta.background!,
                    fit: BoxFit.cover,
                    memCacheWidth: 1080,
                    errorWidget: (_, _, _) =>
                        ColoredBox(color: cs.surfaceContainerHighest),
                  )
                else
                  ColoredBox(color: cs.surfaceContainerHighest),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        cs.surface.withValues(alpha: 0.95),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (meta.releaseInfo != null)
                      Text(meta.releaseInfo!, style: theme.textTheme.bodySmall),
                    if (meta.imdbRating != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            meta.imdbRating!,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    if (meta.runtime != null)
                      Text(meta.runtime!, style: theme.textTheme.bodySmall),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.tertiary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        meta.addonName.isEmpty ? 'ADD-ON' : meta.addonName,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: cs.tertiary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (meta.videos.isEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => AddonSourcesSheet.open(
                        context,
                        item: item,
                        request: requestFor(),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Play from add-ons'),
                    ),
                  ),
                if (meta.description != null) ...[
                  const SizedBox(height: 16),
                  Text(meta.description!, style: theme.textTheme.bodyMedium),
                ],
                if (meta.genres.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final genre in meta.genres)
                        Chip(
                          label: Text(genre),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
                if (seasons.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: seasons.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final season = seasons[index];
                        return ChoiceChip(
                          label: Text('Season $season'),
                          selected: season == activeSeason,
                          onSelected: (_) => setState(() => _season = season),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (episodes.isNotEmpty)
          SliverList.builder(
            itemCount: episodes.length,
            itemBuilder: (context, index) {
              final video = episodes[index];
              final episode = video.toEpisode();
              return ListTile(
                leading: video.thumbnail == null
                    ? const Icon(Icons.play_circle_outline_rounded)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: video.thumbnail!,
                          width: 70,
                          height: 42,
                          fit: BoxFit.cover,
                          memCacheWidth: 220,
                          errorWidget: (_, _, _) =>
                              const Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
                title: Text(
                  'E${video.episode ?? index + 1} · ${video.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: video.released == null
                    ? null
                    : Text(
                        video.released!.split('T').first,
                        style: theme.textTheme.labelSmall,
                      ),
                trailing: const Icon(Icons.play_arrow_rounded),
                onTap: () => AddonSourcesSheet.open(
                  context,
                  item: item,
                  request: requestFor(video: video),
                  episode: episode,
                  playlist: meta.videos,
                ),
              );
            },
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 90)),
      ],
    );
  }
}
