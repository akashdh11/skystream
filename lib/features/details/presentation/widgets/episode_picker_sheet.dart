import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../sources/presentation/plugin_sources_sheet.dart';
import '../../../sources/presentation/source_sheet_widgets.dart';
import '../tmdb_details_controller.dart';

/// Season / episode picker for "Play from Nuvio plugins" on a series.
///
/// Movies open the sources sheet straight away; a series needs to know which
/// episode to look for, and previously the only way in was scrolling down to
/// the episode strip — which is why the button appeared to be missing on every
/// series poster.
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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
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
    final provider = tmdbDetailsControllerProvider(movieId, source: source);
    final state = ref.watch(provider);
    final numbers = _seasonNumbers;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: [
                  Icon(Icons.playlist_play_rounded, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose an episode',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          target.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: numbers.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final season = numbers[index];
                  final selected = state.selectedSeason == season;
                  return ChoiceChip(
                    label: Text('Season $season'),
                    selected: selected,
                    onSelected: (_) => ref
                        .read(provider.notifier)
                        .fetchEpisodes(season, source: source),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
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
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: episodes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final raw = episodes[index];
                      final number =
                          (raw['episode_number'] as num?)?.toInt() ?? index + 1;
                      final name = (raw['name'] as String?)?.trim();
                      return Material(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          autofocus: index == 0,
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            final episode = Episode(
                              name: name?.isNotEmpty == true
                                  ? name!
                                  : 'Episode $number',
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
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'E$number',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    name?.isNotEmpty == true
                                        ? name!
                                        : 'Episode $number',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: cs.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
