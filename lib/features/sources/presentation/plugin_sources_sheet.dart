import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/link_probe_service.dart';
import '../../../core/utils/source_text.dart';
import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/extensions/extension_manager.dart';
import '../../../core/nuvio/data/nuvio_stream_service.dart';
import '../../../core/nuvio/models/nuvio_models.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/download_service.dart';
import '../../stream/data/stream_aggregator.dart';
import '../../stream/data/stream_browser_provider.dart'
    show streamAggregatorProvider;
import '../../stream/data/stream_source.dart';
import 'source_sheet_widgets.dart';

/// Plugin-powered sources sheet used from Explore / TMDB details.
///
/// Two plugin systems feed this one list:
/// * **SkyStream plugins** — the JS providers behind "Available Sources (BETA)"
/// * **Nuvio plugins** — scraper repositories in Nuvio's format, run on the
///   same device with `getStreams(tmdbId, mediaType, season, episode)`
///
/// Stremio add-ons are deliberately *not* here: they have their own tab, sheet
/// and pipeline.
class PluginSourcesSheet extends ConsumerStatefulWidget {
  final MultimediaItem target;
  final Episode? episode;
  final SourcesMode mode;

  const PluginSourcesSheet({
    super.key,
    required this.target,
    this.episode,
    this.mode = SourcesMode.play,
  });

  static Future<void> open(
    BuildContext context,
    MultimediaItem target, {
    Episode? episode,
    SourcesMode mode = SourcesMode.play,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          PluginSourcesSheet(target: target, episode: episode, mode: mode),
    );
  }

  @override
  ConsumerState<PluginSourcesSheet> createState() => _PluginSourcesSheetState();
}

/// One row: either a SkyStream plugin link or a Nuvio scraper link.
class _Row {
  final AggregatedStream? plugin;
  final NuvioStreamResult? nuvio;

  const _Row.fromPlugin(AggregatedStream this.plugin) : nuvio = null;
  const _Row.fromNuvio(NuvioStreamResult this.nuvio) : plugin = null;

  bool get isNuvio => nuvio != null;

  String get url => isNuvio ? nuvio!.url : plugin!.stream.url;

  String get providerName =>
      isNuvio ? nuvio!.scraperName : plugin!.providerName;

  /// One consistent line for both systems: quality-adjacent facts first, then
  /// whatever the provider called it, all cleaned the same way.
  String get detail => buildSourceDetail(
    isNuvio
        ? [
            nuvio!.size,
            nuvio!.language,
            nuvio!.seeders == null ? null : '${nuvio!.seeders} seeds',
            nuvio!.name ?? nuvio!.title,
          ]
        : [plugin!.stream.displaySource],
    fallback: providerName,
  );

  Map<String, String>? get headers =>
      isNuvio ? nuvio!.headers : plugin!.stream.headers;

  bool get isTorrent => isNuvio
      ? nuvio!.isTorrent
      : plugin!.stream.url.startsWith('magnet:');

  bool get canDownload => url.startsWith('http') && !isTorrent;

  static final RegExp _res = RegExp(r'(\d{3,4})\s*[pi]\b', caseSensitive: false);
  static final RegExp _uhd = RegExp(r'\b(4k|uhd|2160)\b', caseSensitive: false);

  int get qualityScore {
    if (!isNuvio) return plugin!.qualityScore;
    final text = '${nuvio!.quality ?? ''} ${nuvio!.title} ${nuvio!.url}';
    if (_uhd.hasMatch(text)) return 2160;
    final match = _res.firstMatch(text);
    return match == null ? 0 : (int.tryParse(match.group(1)!) ?? 0);
  }

  String get qualityLabel {
    if (!isNuvio) return plugin!.qualityLabel;
    final score = qualityScore;
    if (score >= 2160) return '4K';
    if (score > 0) return '${score}p';
    final quality = nuvio!.quality?.trim();
    return (quality == null || quality.isEmpty) ? 'Auto' : quality;
  }

  bool get isHdr => isNuvio
      ? RegExp(
          r'\b(hdr10\+?|hdr|dolby\s*vision|dovi)\b',
          caseSensitive: false,
        ).hasMatch('${nuvio!.quality ?? ''} ${nuvio!.title}')
      : plugin!.isHdr;

  String get key => isNuvio
      ? 'nuvio:${nuvio!.scraperId}:${nuvio!.url}'
      : 'plugin:${plugin!.providerId}:${plugin!.stream.url}';

  StreamResult toStreamResult() => isNuvio
      ? nuvio!.toStreamResult()
      : plugin!.stream.copyWith(
          providerName: plugin!.providerName,
          source: plugin!.stream.source,
        );
}

class _PluginSourcesSheetState extends ConsumerState<PluginSourcesSheet> {
  StreamSubscription<StreamAggregateResult>? _pluginSub;
  StreamSubscription<NuvioProgress>? _nuvioSub;

  StreamAggregateResult _pluginResult = const StreamAggregateResult(
    isLoading: true,
  );
  NuvioProgress _nuvioResult = const NuvioProgress(isLoading: true);
  bool _showDiagnostics = false;

  final Map<String, LinkProbeResult> _probes = {};
  final Set<String> _probing = {};

  late SourcesMode _mode;
  /// Title / TMDB id the user typed in "Search manually", used instead of the
  /// TMDB metadata when a plugin lists the film under a different name.
  String? _titleOverride;
  String? _tmdbOverride;
  final Set<String> _providerFilter = {};
  bool _hdOnly = false;
  bool _verifiedOnly = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPlugins();
      _startNuvio();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _pluginSub?.cancel();
    _nuvioSub?.cancel();
    super.dispose();
  }

  MultimediaItem get _searchTarget => _titleOverride == null
      ? widget.target
      : widget.target.copyWith(title: _titleOverride);

  void _startPlugins() {
    final manager = ref.read(extensionManagerProvider.notifier);
    final aggregator = ref.read(streamAggregatorProvider);
    final target = _searchTarget;
    final stream = widget.episode == null
        ? aggregator.aggregateForMovie(manager: manager, target: target)
        : aggregator.aggregateForEpisode(
            manager: manager,
            target: target,
            episode: widget.episode!,
          );
    _pluginSub = stream.listen((result) {
      if (_disposed) return;
      setState(() => _pluginResult = result);
      _scheduleProbes();
    });
  }

  void _startNuvio() {
    final tmdbId = _tmdbOverride ?? widget.target.tmdbId?.toString() ?? '';
    if (tmdbId.isEmpty) {
      setState(() => _nuvioResult = const NuvioProgress(isLoading: false));
      return;
    }
    final isSeries =
        widget.episode != null ||
        widget.target.contentType == MultimediaContentType.series ||
        widget.target.contentType == MultimediaContentType.anime;

    _nuvioSub = ref
        .read(nuvioStreamServiceProvider)
        .resolve(
          tmdbId: tmdbId,
          mediaType: isSeries ? 'tv' : 'movie',
          season: widget.episode?.season,
          episode: widget.episode?.episode,
        )
        .listen((progress) {
          if (_disposed) return;
          setState(() => _nuvioResult = progress);
          _scheduleProbes();
        });
  }

  /// Re-runs the search with a title the user types.
  ///
  /// Plugins index films under their own names (regional titles, release
  /// names, "Part 2" vs "Chapter 2"), so the TMDB title can miss even when the
  /// plugin has the film. A pasted TMDB id or `tmdb:123` re-points the Nuvio
  /// scrapers as well.
  Future<void> _searchManually() async {
    final controller = TextEditingController(
      text: _titleOverride ?? widget.target.title,
    );
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Search plugins manually'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Type the title a plugin would use. A TMDB id (or tmdb:123) '
              'also re-points the Nuvio scrapers.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Title or TMDB id',
              ),
              onSubmitted: (text) => Navigator.pop(dialogContext, text.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          if (_titleOverride != null || _tmdbOverride != null)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, ''),
              child: const Text('Reset'),
            ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Search'),
          ),
        ],
      ),
    );
    if (value == null || !mounted) return;

    final tmdbMatch = RegExp(r'^(?:tmdb:)?(\d{2,9})$').firstMatch(value);
    setState(() {
      if (value.isEmpty) {
        _titleOverride = null;
        _tmdbOverride = null;
      } else if (tmdbMatch != null) {
        _tmdbOverride = tmdbMatch.group(1);
        _titleOverride = null;
      } else {
        _titleOverride = value;
        _tmdbOverride = null;
      }
      _pluginResult = const StreamAggregateResult(isLoading: true);
      _nuvioResult = const NuvioProgress(isLoading: true);
      _probes.clear();
      _probing.clear();
    });
    await _pluginSub?.cancel();
    await _nuvioSub?.cancel();
    _startPlugins();
    _startNuvio();
  }

  /// Link checking runs for **every** row, SkyStream and Nuvio alike — the
  /// old sixteen-row cap meant most of a long list never got a
  /// working/dead badge. Six at a time keeps it off the network's back.
  static const int _maxParallelProbes = 6;

  void _scheduleProbes() {
    final service = ref.read(linkProbeServiceProvider);
    for (final row in _allRows) {
      if (_probing.length >= _maxParallelProbes) return;
      final url = row.url;
      if (!url.startsWith('http')) continue;
      if (_probes.containsKey(url) || _probing.contains(url)) continue;
      _probing.add(url);
      unawaited(
        service.probe(url, headers: row.headers).then((result) {
          if (_disposed) return;
          setState(() {
            _probes[url] = result;
            _probing.remove(url);
          });
          // Free slot: keep working down the list.
          _scheduleProbes();
        }),
      );
    }
  }

  List<_Row> get _allRows {
    final rows = <_Row>[
      for (final stream in _pluginResult.streams) _Row.fromPlugin(stream),
      for (final stream in _nuvioResult.streams) _Row.fromNuvio(stream),
    ];
    rows.sort((a, b) {
      final byQuality = b.qualityScore.compareTo(a.qualityScore);
      if (byQuality != 0) return byQuality;
      if (a.isHdr != b.isHdr) return a.isHdr ? -1 : 1;
      return a.providerName.compareTo(b.providerName);
    });
    return rows;
  }

  List<_Row> get _visible => _allRows.where((row) {
    if (_providerFilter.isNotEmpty &&
        !_providerFilter.contains(row.providerName)) {
      return false;
    }
    if (_hdOnly && row.qualityScore < 1080) return false;
    if (_mode == SourcesMode.download && !row.canDownload) return false;
    if (_verifiedOnly) {
      final probe = _probes[row.url];
      if (probe == null || !probe.reachable) return false;
    }
    return true;
  }).toList();

  bool get _isLoading => _pluginResult.isLoading || _nuvioResult.isLoading;

  void _play(_Row row) {
    final ordered = <_Row>[row, ..._visible.where((r) => r.key != row.key)];
    final streams = [for (final r in ordered) r.toStreamResult()];

    final item = row.isNuvio
        ? widget.target
        : row.plugin!.detailedItem;
    final episode = row.isNuvio ? widget.episode : row.plugin!.episode;
    final videoUrl = row.isNuvio
        ? (widget.target.url.isNotEmpty
              ? widget.target.url
              : 'tmdb:${widget.target.tmdbId}')
        : row.plugin!.episodeUrl;

    Navigator.of(context).pop();
    unawaited(
      PlayerRoute(
        $extra: PlayerRouteExtra(
          item: item,
          videoUrl: videoUrl,
          episode: episode,
          preloadedStreams: streams,
        ),
      ).push<void>(context),
    );
  }

  Future<void> _download(_Row row) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!row.canDownload) {
      messenger.showSnackBar(
        const SnackBar(content: Text('This link can only be streamed.')),
      );
      return;
    }

    final service = ref.read(downloadServiceProvider);
    final item = row.isNuvio ? widget.target : row.plugin!.detailedItem;
    final episode = row.isNuvio ? widget.episode : row.plugin!.episode;

    try {
      final saveDir = await service.getDownloadPath(item, episode: episode);
      final extension = extensionForUrl(row.url);

      String filename;
      if (episode != null && item.contentType != MultimediaContentType.movie) {
        final safe = episode.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
        filename = 'S${episode.season}-E${episode.episode} $safe$extension';
      } else {
        final safe = item.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
        filename = '$safe$extension';
      }

      final started = await service.startDownload(
        url: row.url,
        filename: filename,
        directory: saveDir,
        item: item,
        episode: episode,
        trackingUrl: row.isNuvio ? row.url : row.plugin!.episodeUrl,
        headers: row.headers,
      );

      if (!mounted) return;
      final resolution = _probes[row.url]?.resolutionLabel ?? row.qualityLabel;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            started
                ? 'Download started · ${row.providerName} · $resolution'
                : 'Failed to start download. Check storage permissions.',
          ),
        ),
      );
      if (started && mounted) Navigator.of(context).maybePop();
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Download failed: $error')),
      );
    }
  }

  /// What each SkyStream plugin actually matched.
  ///
  /// Plugins search by title, so a wrong match is the usual reason a film has
  /// links that turn out to be a different film. Showing the matched title
  /// makes that visible — and "Search with a different title" fixes it.
  Map<String, String> get _skystreamMatches {
    final titles = <String, String>{};
    final counts = <String, int>{};
    for (final stream in _pluginResult.streams) {
      final provider = stream.providerName;
      counts[provider] = (counts[provider] ?? 0) + 1;
      final matched = stream.detailedItem.title.trim();
      if (matched.isNotEmpty) titles.putIfAbsent(provider, () => matched);
    }
    return {
      for (final provider in counts.keys)
        provider:
            '${titles[provider] ?? 'matched'} · ${counts[provider]} links',
    };
  }

  /// Per-plugin outcome, so "why did only three plugins answer?" has an
  /// answer in the app instead of needing a rebuild to find out.
  Widget _diagnosticsPanel(ThemeData theme, ColorScheme cs) {
    final statuses = _nuvioResult.statuses.toList()
      ..sort((a, b) => a.scraperName.compareTo(b.scraperName));
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_skystreamMatches.isNotEmpty) ...[
            Text(
              'SkyStream plugins · ${_skystreamMatches.length}',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            for (final entry in _skystreamMatches.entries)
              Text(
                '${entry.key}: ${entry.value}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  'Nuvio plugins · ${statuses.length}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _diagnosticsReport()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Diagnostics copied')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Copy'),
              ),
            ],
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final status in statuses)
                    Text(
                      '${status.scraperName}: '
                      '${status.outcome == NuvioScraperOutcome.links ? '${status.linkCount} links' : (status.message ?? status.outcome.name)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: status.outcome == NuvioScraperOutcome.failed
                            ? cs.error
                            : cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _diagnosticsReport() {
    final buffer = StringBuffer()
      ..writeln('SkyStream sources diagnostics')
      ..writeln('title: ${widget.target.title} (tmdb ${widget.target.tmdbId})')
      ..writeln(
        'skystream plugins: ${_pluginResult.streams.length} links, '
        '${_pluginResult.completedCount}/${_pluginResult.totalCount} done',
      )
      ..writeln(
        'nuvio plugins: ${_nuvioResult.streams.length} links, '
        '${_nuvioResult.completedCount}/${_nuvioResult.totalCount} done',
      );
    for (final entry in _skystreamMatches.entries) {
      buffer.writeln('- ${entry.key} matched ${entry.value}');
    }
    for (final status in _nuvioResult.statuses) {
      buffer.writeln(
        '- ${status.scraperName}: ${status.outcome.name}'
        '${status.outcome == NuvioScraperOutcome.links ? ' (${status.linkCount})' : ''}'
        '${status.message == null ? '' : ' — ${status.message}'}',
      );
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final episode = widget.episode;
    final subtitle = episode == null
        ? widget.target.title
        : '${widget.target.title} • S${episode.season} E${episode.episode}';

    final visible = _visible;
    final providers = _allRows.map((e) => e.providerName).toSet().toList()
      ..sort();
    final nuvioCount = _nuvioResult.streams.length;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SourceSheetHeader(
                title: 'Available Sources',
                subtitle: _titleOverride == null && _tmdbOverride == null
                    ? subtitle
                    : 'Searching for "${_titleOverride ?? 'tmdb:$_tmdbOverride'}"',
                trailing: const SourceTag(text: 'PLUGINS', color: Colors.teal),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => unawaited(_searchManually()),
                    icon: const Icon(Icons.search_rounded, size: 16),
                    label: Text(
                      _titleOverride == null && _tmdbOverride == null
                          ? 'Search with a different title'
                          : 'Change search title',
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SegmentedButton<SourcesMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: SourcesMode.play,
                      icon: Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text('Play'),
                    ),
                    ButtonSegment(
                      value: SourcesMode.download,
                      icon: Icon(Icons.download_rounded, size: 18),
                      label: Text('Download'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (value) =>
                      setState(() => _mode = value.first),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isLoading
                            ? 'Searching plugins… '
                                  '${_pluginResult.completedCount + _nuvioResult.completedCount}'
                                  '/${_pluginResult.totalCount + _nuvioResult.totalCount}'
                            : '${_allRows.length} links · '
                                  '${_pluginResult.streams.length} SkyStream · '
                                  '$nuvioCount Nuvio',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _isLoading ? cs.primary : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_isLoading)
                      SizedBox(
                        width: 90,
                        child: LinearProgressIndicator(
                          value:
                              (_pluginResult.totalCount +
                                      _nuvioResult.totalCount) ==
                                  0
                              ? null
                              : (_pluginResult.completedCount +
                                        _nuvioResult.completedCount) /
                                    (_pluginResult.totalCount +
                                        _nuvioResult.totalCount),
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )
                    else if (_nuvioResult.hasWork ||
                        _pluginResult.streams.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => setState(
                          () => _showDiagnostics = !_showDiagnostics,
                        ),
                        icon: const Icon(Icons.info_outline_rounded, size: 16),
                        label: const Text('Details'),
                      ),
                  ],
                ),
              ),
              if (_showDiagnostics) _diagnosticsPanel(theme, cs),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('1080p+'),
                        selected: _hdOnly,
                        onSelected: (value) => setState(() => _hdOnly = value),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: const Icon(Icons.verified_rounded, size: 16),
                        label: const Text('Tested'),
                        selected: _verifiedOnly,
                        onSelected: (value) =>
                            setState(() => _verifiedOnly = value),
                      ),
                    ),
                    for (final provider in providers)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(provider),
                          selected: _providerFilter.contains(provider),
                          onSelected: (value) => setState(() {
                            if (value) {
                              _providerFilter.add(provider);
                            } else {
                              _providerFilter.remove(provider);
                            }
                          }),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: visible.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: _isLoading
                              ? const Text('Searching installed plugins…')
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.cloud_off_outlined,
                                      size: 40,
                                      color: cs.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _allRows.isNotEmpty
                                          ? 'No links match the current filters.'
                                          : (_pluginResult.error ??
                                                'No links found for this title. '
                                                    'Install SkyStream plugins '
                                                    'or a Nuvio plugin '
                                                    'repository.'),
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final row = visible[index];
                          return _SourceRow(
                            row: row,
                            probe: _probes[row.url],
                            probing: _probing.contains(row.url),
                            isBest: index == 0,
                            autofocus: index == 0,
                            downloadMode: _mode == SourcesMode.download,
                            onPlay: () => _play(row),
                            onDownload: () => unawaited(_download(row)),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SourceRow extends StatelessWidget {
  final _Row row;
  final LinkProbeResult? probe;
  final bool probing;
  final bool isBest;
  final bool autofocus;
  final bool downloadMode;
  final VoidCallback onPlay;
  final VoidCallback onDownload;

  const _SourceRow({
    required this.row,
    required this.probe,
    required this.probing,
    required this.isBest,
    required this.downloadMode,
    required this.onPlay,
    required this.onDownload,
    this.autofocus = false,
  });

  Color _avatarColor() {
    const palette = [
      Color(0xFF7C6BF5),
      Color(0xFF4CAF50),
      Color(0xFFFF9800),
      Color(0xFF2196F3),
      Color(0xFF26C6DA),
      Color(0xFFEC407A),
      Color(0xFFFFC107),
    ];
    return palette[row.providerName.hashCode.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final letter = row.providerName.isEmpty
        ? '?'
        : row.providerName.substring(0, 1).toUpperCase();
    final resolution = probe?.resolutionLabel ?? row.qualityLabel;
    final size = probe?.sizeLabel;

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: downloadMode && row.canDownload ? onDownload : onPlay,
        autofocus: autofocus,
        focusColor: cs.primary.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: isBest
                ? Border.all(
                    color: cs.primary.withValues(alpha: 0.8),
                    width: 1.5,
                  )
                : null,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: _avatarColor(),
                child: Text(
                  letter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          resolution,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SourceTag(
                          text: row.isNuvio ? 'NUVIO' : 'SKYSTREAM',
                          color: row.isNuvio ? cs.tertiary : cs.secondary,
                        ),
                        if (row.isHdr)
                          SourceTag(text: 'HDR', color: cs.tertiary),
                        if (row.isTorrent)
                          SourceTag(text: 'TORRENT', color: cs.primary),
                        if (isBest) SourceTag(text: 'BEST', color: cs.primary),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      row.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          row.providerName,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        if (size != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            size,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        ProbeBadge(probe: probe, probing: probing),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Play',
                onPressed: onPlay,
                icon: const Icon(Icons.play_arrow_rounded),
              ),
              IconButton(
                tooltip: row.canDownload ? 'Download' : 'Stream-only link',
                onPressed: row.canDownload ? onDownload : null,
                icon: const Icon(Icons.download_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
