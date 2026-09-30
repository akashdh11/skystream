import 'package:cached_network_image/cached_network_image.dart';
import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/utils/image_fallbacks.dart';
import '../../../sources/presentation/plugin_sources_sheet.dart';
import '../../../sources/presentation/source_sheet_widgets.dart';
import '../tmdb_details_controller.dart';
import '../../../../shared/focus/app_focus.dart';

/// Season / episode picker for "Search in Nuvio plugins" on a series.
///
/// A floating frosted glass dialog matching [PluginSourcesSheet].
class EpisodePickerSheet extends ConsumerWidget {
  final int movieId;
  final String? source;
  final List<dynamic> seasons;
  final MultimediaItem target;
  final SourcesMode mode;

  /// The screen that opened the picker. The sources sheet is shown from this
  /// context *after* the picker closes — using the picker's own (defunct)
  /// context would silently do nothing.
  final BuildContext hostContext;

  const EpisodePickerSheet({
    super.key,
    required this.movieId,
    required this.seasons,
    required this.target,
    required this.hostContext,
    this.source,
    this.mode = SourcesMode.play,
  });

  static Future<void> open(
    BuildContext context, {
    required int movieId,
    required List<dynamic> seasons,
    required MultimediaItem target,
    String? source,
    SourcesMode mode = SourcesMode.play,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.65),
      builder: (_) => EpisodePickerSheet(
        movieId: movieId,
        seasons: seasons,
        target: target,
        hostContext: context,
        source: source,
        mode: mode,
      ),
    );
  }

  /// Season numbers as published by TMDB, specials excluded.
  List<int> get _seasonNumbers {
    final numbers = <int>[];
    for (final season in seasons) {
      final value = season is Map ? season['season_number'] : null;
      final number = value is num ? value.toInt() : int.tryParse('$value');
      if (number != null && number > 0) numbers.add(number);
    }
    if (numbers.isEmpty) numbers.add(1);
    numbers.sort();
    return numbers;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final glass = GlassPalette.of(context);
    final provider = tmdbDetailsControllerProvider(movieId, source: source);
    final state = ref.watch(provider);
    final numbers = _seasonNumbers;

    return GlassSheetScaffold(
      title: 'Select Episode',
      subtitle: target.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Season Filter Chips Rail
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: kSourceSheetGutter,
              ),
              itemCount: numbers.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final season = numbers[index];
                final selected = state.selectedSeason == season;
                return SourceFilterChip(
                  text: 'Season $season',
                  selected: selected,
                  outline: glass.tint(0.15),
                  onSelected: (_) => ref
                      .read(provider.notifier)
                      .fetchEpisodes(season, source: source),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Episode List
          Expanded(
            child: FutureBuilder<Map<String, dynamic>?>(
              future: state.episodesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final episodes = List<Map<String, dynamic>>.from(
                  (snapshot.data?['episodes'] as List?) ?? const <dynamic>[],
                );
                if (episodes.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No episodes listed for this season.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    kSourceSheetGutter,
                    4,
                    kSourceSheetGutter,
                    16,
                  ),
                  itemCount: episodes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final raw = episodes[index];
                    final number =
                        (raw['episode_number'] as num?)?.toInt() ?? index + 1;
                    final name = (raw['name'] as String?)?.trim();
                    final displayTitle = name?.isNotEmpty == true
                        ? name!
                        : 'Episode $number';
                    final overview = (raw['overview'] as String?)?.trim() ?? '';
                    final imageUrl = AppImageFallbacks.tmdbStill(
                      raw['still_path'] as String?,
                      label: displayTitle,
                    );
                    final voteAverage =
                        (raw['vote_average'] as num?)?.toDouble() ?? 0.0;
                    final runtime = (raw['runtime'] as int?) ?? 0;
                    final hours = runtime ~/ 60;
                    final minutes = runtime % 60;
                    final runtimeText = hours > 0
                        ? '${hours}h ${minutes}m'
                        : '${minutes}m';

                    void selectEpisode() {
                      final episode = Episode(
                        name: displayTitle,
                        url: '',
                        season: state.selectedSeason,
                        episode: number,
                      );
                      Navigator.of(context).pop();
                      PluginSourcesSheet.open(
                        hostContext,
                        target,
                        episode: episode,
                        mode: mode,
                      );
                    }

                    return _EpisodeItemCard(
                      key: ValueKey('ep_${state.selectedSeason}_$number'),
                      number: number,
                      title: displayTitle,
                      overview: overview,
                      imageUrl: imageUrl,
                      voteAverage: voteAverage,
                      runtimeText: runtimeText,
                      autofocus: index == 0,
                      onSelect: selectEpisode,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Episode Card with smooth mouse hover expansion and D-Pad focus highlight,
/// matching the CardsWrapper interaction in SkyStream's details screen.
class _EpisodeItemCard extends StatefulWidget {
  final int number;
  final String title;
  final String overview;
  final String? imageUrl;
  final double voteAverage;
  final String runtimeText;
  final bool autofocus;
  final VoidCallback onSelect;

  const _EpisodeItemCard({
    super.key,
    required this.number,
    required this.title,
    required this.overview,
    required this.imageUrl,
    required this.voteAverage,
    required this.runtimeText,
    required this.autofocus,
    required this.onSelect,
  });

  @override
  State<_EpisodeItemCard> createState() => _EpisodeItemCardState();
}

class _EpisodeItemCardState extends State<_EpisodeItemCard> {
  bool _isHovered = false;

  void _setHovered(bool hovered) {
    if (_isHovered == hovered) return;
    setState(() => _isHovered = hovered);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final glass = GlassPalette.of(context);

    // The row is a hand-built button — a bare [InkWell] reports a tap action
    // but no role — and its own text supplies the label.
    return SourceActionSemantics(
      enabled: true,
      child: MouseRegion(
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        cursor: SystemMouseCursors.click,
        child: DpadFocusable(
          autofocus: widget.autofocus,
          onSelect: widget.onSelect,
          child: const SizedBox.shrink(),
          builder: (context, dpadState, _) {
            final isFocused = showFocusIndicator(context, dpadState.focused);
            return GlassRow(
              focused: isFocused,
              onTap: widget.onSelect,
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left-side episode thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 120,
                      height: 68,
                      child:
                          widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: widget.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, _) =>
                                  ColoredBox(color: glass.imageFill),
                              errorWidget: (_, _, _) => ColoredBox(
                                color: glass.imageFill,
                                child: Center(
                                  child: Icon(
                                    Icons.movie_outlined,
                                    size: 24,
                                    color: glass.mutedIcon,
                                  ),
                                ),
                              ),
                            )
                          : ColoredBox(
                              color: glass.imageFill,
                              child: Center(
                                child: Icon(
                                  Icons.movie_outlined,
                                  size: 24,
                                  color: glass.mutedIcon,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Details column (Title, [E# · Rating · Runtime], Overview)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: glass.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'E${widget.number}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: cs.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (widget.voteAverage > 0) ...[
                              Icon(
                                Icons.star_rounded,
                                size: 13,
                                // Same colour as the number beside it: the
                                // star is a label for that value, not a second
                                // thing to look at.
                                color: cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                widget.voteAverage.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            if (widget.runtimeText.isNotEmpty &&
                                widget.runtimeText != '0m')
                              Text(
                                widget.runtimeText,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        if (widget.overview.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            widget.overview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                              fontSize: 11,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Chevron arrow
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: _isHovered || isFocused
                        ? glass.ink
                        : cs.onSurfaceVariant,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
