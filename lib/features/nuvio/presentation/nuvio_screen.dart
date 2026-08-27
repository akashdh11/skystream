import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nuvio/data/nuvio_tmdb.dart';
import '../../../shared/widgets/cards_wrapper.dart';
import 'nuvio_plugins_view.dart';
import 'nuvio_sources_sheet.dart';

/// Nuvio destination.
///
/// Everything Nuvio needs in one place: the TMDB key its scrapers use, the
/// plugin repositories, and a browser that plays through those plugins.
class NuvioScreen extends ConsumerStatefulWidget {
  const NuvioScreen({super.key});

  @override
  ConsumerState<NuvioScreen> createState() => _NuvioScreenState();
}

class _NuvioScreenState extends ConsumerState<NuvioScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Nuvio'),
          bottom: TabBar(
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicatorColor: theme.colorScheme.primary,
            tabs: const [
              Tab(text: 'Browse'),
              Tab(text: 'Plugins'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _BrowseTab(
              query: _query,
              controller: _searchController,
              onQueryChanged: _onQueryChanged,
            ),
            const _PluginsTab(),
          ],
        ),
      ),
    );
  }
}

/// TMDB-powered browser. Tapping a title asks the installed Nuvio scrapers
/// for links.
class _BrowseTab extends ConsumerStatefulWidget {
  final String query;
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;

  const _BrowseTab({
    required this.query,
    required this.controller,
    required this.onQueryChanged,
  });

  @override
  ConsumerState<_BrowseTab> createState() => _BrowseTabState();
}

class _BrowseTabState extends ConsumerState<_BrowseTab> {
  @override
  Widget build(BuildContext context) {
    final key = ref.watch(effectiveNuvioTmdbKeyProvider);
    final theme = Theme.of(context);

    if (key.isEmpty) {
      return const _NeedsKeyHint();
    }

    if (widget.query.length >= 2) {
      return Column(
        children: [
          _searchField(),
          Expanded(child: _SearchGrid(query: widget.query)),
        ],
      );
    }

    return Column(
      children: [
        _searchField(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              _Row(
                title: 'Trending movies',
                load: (service) => service.trendingMovies(),
              ),
              _Row(
                title: 'Trending series',
                load: (service) => service.trendingSeries(),
              ),
              _Row(
                title: 'Popular movies',
                load: (service) => service.popularMovies(),
              ),
              _Row(
                title: 'Popular series',
                load: (service) => service.popularSeries(),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Playback uses your installed Nuvio plugins',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _searchField() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: TextField(
      controller: widget.controller,
      onChanged: widget.onQueryChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search movies & series…',
        prefixIcon: const Icon(Icons.search_rounded),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        isDense: true,
      ),
    ),
  );
}

class _NeedsKeyHint extends StatelessWidget {
  const _NeedsKeyHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.key_rounded, size: 52, color: theme.colorScheme.primary),
            const SizedBox(height: 14),
            Text('TMDB API key needed', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Nuvio plugins look titles up by TMDB id. Add a key in the '
              'Plugins tab — it is free from themoviedb.org.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends ConsumerStatefulWidget {
  final String title;
  final Future<List<NuvioTitle>> Function(NuvioTmdbService service) load;

  const _Row({required this.title, required this.load});

  @override
  ConsumerState<_Row> createState() => _RowState();
}

class _RowState extends ConsumerState<_Row> {
  late Future<List<NuvioTitle>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load(ref.read(nuvioTmdbServiceProvider));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<List<NuvioTitle>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(height: 120);
        }
        final items = snapshot.data ?? const <NuvioTitle>[];
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                widget.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(
              height: 214,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                addAutomaticKeepAlives: false,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) =>
                    NuvioPosterCard(title: items[index]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SearchGrid extends ConsumerStatefulWidget {
  final String query;
  const _SearchGrid({required this.query});

  @override
  ConsumerState<_SearchGrid> createState() => _SearchGridState();
}

class _SearchGridState extends ConsumerState<_SearchGrid> {
  late Future<List<NuvioTitle>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(nuvioTmdbServiceProvider).search(widget.query);
  }

  @override
  void didUpdateWidget(_SearchGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _future = ref.read(nuvioTmdbServiceProvider).search(widget.query);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<NuvioTitle>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Search failed: ${snapshot.error}'));
        }
        final items = snapshot.data ?? const <NuvioTitle>[];
        if (items.isEmpty) return const Center(child: Text('Nothing found.'));

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 140,
            childAspectRatio: 0.55,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) =>
              NuvioPosterCard(title: items[index], width: double.infinity),
        );
      },
    );
  }
}

class NuvioPosterCard extends ConsumerWidget {
  final NuvioTitle title;
  final double width;

  const NuvioPosterCard({super.key, required this.title, this.width = 124});

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    if (!title.isSeries) {
      await NuvioSourcesSheet.open(context, title: title);
      return;
    }

    final service = ref.read(nuvioTmdbServiceProvider);
    final seasons = await service.seasons(title.tmdbId);
    if (!context.mounted) return;
    if (seasons.isEmpty) {
      await NuvioSourcesSheet.open(context, title: title);
      return;
    }
    await _showEpisodePicker(context, ref, seasons);
  }

  Future<void> _showEpisodePicker(
    BuildContext context,
    WidgetRef ref,
    List<int> seasons,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _EpisodePicker(title: title, seasons: seasons),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width == double.infinity ? null : width,
      child: CardsWrapper(
        borderRadius: BorderRadius.circular(12),
        onTap: () => unawaited(_open(context, ref)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: title.posterUrl == null
                    ? ColoredBox(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Center(child: Icon(Icons.movie_outlined)),
                      )
                    : CachedNetworkImage(
                        imageUrl: title.posterUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        memCacheWidth: 320,
                        errorWidget: (_, _, _) => ColoredBox(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              [
                if (title.year != null) title.year!,
                title.isSeries ? 'Series' : 'Movie',
              ].join(' · '),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EpisodePicker extends ConsumerStatefulWidget {
  final NuvioTitle title;
  final List<int> seasons;

  const _EpisodePicker({required this.title, required this.seasons});

  @override
  ConsumerState<_EpisodePicker> createState() => _EpisodePickerState();
}

class _EpisodePickerState extends ConsumerState<_EpisodePicker> {
  late int _season = widget.seasons.first;
  late Future<List<NuvioEpisode>> _future = _load();

  Future<List<NuvioEpisode>> _load() =>
      ref.read(nuvioTmdbServiceProvider).episodes(widget.title.tmdbId, _season);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
              itemCount: widget.seasons.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final season = widget.seasons[index];
                return ChoiceChip(
                  label: Text('Season $season'),
                  selected: season == _season,
                  onSelected: (_) => setState(() {
                    _season = season;
                    _future = _load();
                  }),
                );
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<NuvioEpisode>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final episodes = snapshot.data ?? const <NuvioEpisode>[];
                if (episodes.isEmpty) {
                  return const Center(child: Text('No episodes found.'));
                }
                return ListView.builder(
                  controller: controller,
                  itemCount: episodes.length,
                  itemBuilder: (context, index) {
                    final episode = episodes[index];
                    return ListTile(
                      leading: episode.stillUrl == null
                          ? const Icon(Icons.play_circle_outline_rounded)
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: CachedNetworkImage(
                                imageUrl: episode.stillUrl!,
                                width: 70,
                                height: 42,
                                fit: BoxFit.cover,
                                memCacheWidth: 220,
                                errorWidget: (_, _, _) =>
                                    const Icon(Icons.image_not_supported),
                              ),
                            ),
                      title: Text(
                        'E${episode.episode} · ${episode.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.play_arrow_rounded),
                      onTap: () {
                        Navigator.pop(context);
                        unawaited(
                          NuvioSourcesSheet.open(
                            context,
                            title: widget.title,
                            episode: episode,
                          ),
                        );
                      },
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

/// Plugins tab: the TMDB key for Nuvio + repository management.
class _PluginsTab extends ConsumerStatefulWidget {
  const _PluginsTab();

  @override
  ConsumerState<_PluginsTab> createState() => _PluginsTabState();
}

class _PluginsTabState extends ConsumerState<_PluginsTab> {
  final TextEditingController _keyController = TextEditingController();
  bool _seeded = false;
  bool _saving = false;
  String? _status;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _saveKey() async {
    setState(() {
      _saving = true;
      _status = null;
    });
    final key = _keyController.text.trim();
    try {
      final ok = key.isEmpty
          ? true
          : await ref.read(nuvioTmdbServiceProvider).verify(key);
      await ref.read(nuvioTmdbKeyProvider.notifier).set(key);
      if (!mounted) return;
      setState(() {
        _status = key.isEmpty
            ? 'Cleared — the app-wide TMDB key will be used.'
            : (ok ? 'Key saved and verified.' : 'Saved, but TMDB rejected it.');
      });
    } catch (error) {
      if (mounted) setState(() => _status = 'Could not verify: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storedKey = ref.watch(nuvioTmdbKeyProvider);
    final effective = ref.watch(effectiveNuvioTmdbKeyProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (!_seeded) {
      _seeded = true;
      _keyController.text = storedKey;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.key_rounded, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'TMDB API key (for Nuvio)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (effective.isNotEmpty)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Used by the Nuvio browser and passed to Nuvio plugins, '
                    'which look titles up by TMDB id. Separate from the app-wide '
                    'key in Settings — leave empty to reuse that one.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _keyController,
                    decoration: const InputDecoration(
                      labelText: 'TMDB API key',
                      hintText: 'v3 API key from themoviedb.org',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  if (_status != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _status!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _saving ? null : () => unawaited(_saveKey()),
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: const Text('Save key'),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Repository management lives right below the key it needs.
        const Expanded(child: NuvioPluginsView()),
      ],
    );
  }
}
