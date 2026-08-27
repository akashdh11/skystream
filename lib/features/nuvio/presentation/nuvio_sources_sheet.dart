import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/nuvio/data/nuvio_stream_service.dart';
import '../../../core/nuvio/data/nuvio_tmdb.dart';
import '../../../core/nuvio/models/nuvio_models.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/download_service.dart';

/// Sources sheet for the Nuvio tab: links come **only** from installed Nuvio
/// scrapers, and play through the app's built-in player with all its features.
class NuvioSourcesSheet extends ConsumerStatefulWidget {
  final NuvioTitle title;
  final NuvioEpisode? episode;

  const NuvioSourcesSheet({super.key, required this.title, this.episode});

  static Future<void> open(
    BuildContext context, {
    required NuvioTitle title,
    NuvioEpisode? episode,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NuvioSourcesSheet(title: title, episode: episode),
    );
  }

  @override
  ConsumerState<NuvioSourcesSheet> createState() => _NuvioSourcesSheetState();
}

class _NuvioSourcesSheetState extends ConsumerState<NuvioSourcesSheet> {
  StreamSubscription<NuvioProgress>? _sub;
  NuvioProgress _result = const NuvioProgress(isLoading: true);
  bool _disposed = false;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }

  void _start() {
    _sub?.cancel();
    setState(() => _result = const NuvioProgress(isLoading: true));
    _sub = ref
        .read(nuvioStreamServiceProvider)
        .resolve(
          tmdbId: widget.title.tmdbId.toString(),
          mediaType: widget.title.isSeries ? 'tv' : 'movie',
          season: widget.episode?.season,
          episode: widget.episode?.episode,
        )
        .listen((progress) {
          if (_disposed) return;
          setState(() => _result = progress);
        });
  }

  MultimediaItem get _item => MultimediaItem(
    title: widget.title.name,
    url: 'tmdb:${widget.title.tmdbId}',
    posterUrl: widget.title.posterUrl ?? '',
    bannerUrl: widget.title.backdropUrl,
    description: widget.title.overview,
    contentType: widget.title.isSeries
        ? MultimediaContentType.series
        : MultimediaContentType.movie,
    provider: 'Nuvio',
    year: int.tryParse(widget.title.year ?? ''),
    tmdbId: widget.title.tmdbId,
  );

  Episode? get _episode {
    final episode = widget.episode;
    if (episode == null) return null;
    return Episode(
      name: episode.name,
      url: 'tmdb:${widget.title.tmdbId}:${episode.season}:${episode.episode}',
      season: episode.season,
      episode: episode.episode,
      description: episode.overview,
      posterUrl: episode.stillUrl,
    );
  }

  void _play(NuvioStreamResult selected) {
    final ordered = <NuvioStreamResult>[
      selected,
      ..._result.streams.where((s) => s.url != selected.url),
    ];
    Navigator.of(context).pop();
    unawaited(
      PlayerRoute(
        $extra: PlayerRouteExtra(
          item: _item,
          videoUrl: _episode?.url ?? _item.url,
          episode: _episode,
          preloadedStreams: [for (final s in ordered) s.toStreamResult()],
        ),
      ).push<void>(context),
    );
  }

  Future<void> _download(NuvioStreamResult stream) async {
    final messenger = ScaffoldMessenger.of(context);
    if (stream.isTorrent || !stream.url.startsWith('http')) {
      messenger.showSnackBar(
        const SnackBar(content: Text('This source can only be streamed.')),
      );
      return;
    }

    final service = ref.read(downloadServiceProvider);
    final item = _item;
    final episode = _episode;
    try {
      final saveDir = await service.getDownloadPath(item, episode: episode);
      final clean = stream.url.split('?').first.toLowerCase();
      var extension = '.mp4';
      for (final ext in const ['.mp4', '.mkv', '.webm', '.avi', '.mov']) {
        if (clean.endsWith(ext)) extension = ext;
      }

      final String filename;
      if (episode != null) {
        final safe = episode.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
        filename = 'S${episode.season}-E${episode.episode} $safe$extension';
      } else {
        final safe = item.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
        filename = '$safe$extension';
      }

      final started = await service.startDownload(
        url: stream.url,
        filename: filename,
        directory: saveDir,
        item: item,
        episode: episode,
        trackingUrl: stream.url,
        headers: stream.headers,
      );

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            started
                ? 'Download started · ${stream.scraperName} · ${stream.quality ?? ''}'
                : 'Failed to start download. Check storage permissions.',
          ),
        ),
      );
      if (started && mounted) unawaited(Navigator.of(context).maybePop());
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Download failed: $error')),
      );
    }
  }

  /// A plain-text summary of what every scraper did — the fastest way to see
  /// why a title returned few links, and to share it.
  String _diagnosticsReport() {
    final buffer = StringBuffer()
      ..writeln('Nuvio diagnostics')
      ..writeln('title: ${widget.title.name} (tmdb ${widget.title.tmdbId})')
      ..writeln(
        'scrapers: ${_result.totalCount}, completed: ${_result.completedCount}, '
        'links: ${_result.streams.length}',
      );
    for (final status in _result.statuses) {
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
        ? widget.title.name
        : '${widget.title.name} • S${episode.season} E${episode.episode}';
    final streams = _result.streams;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.45,
      maxChildSize: 0.96,
      builder: (context, scrollController) => DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nuvio sources',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: _start,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _result.isLoading
                          ? 'Running scrapers… ${_result.completedCount}/${_result.totalCount}'
                          : '${streams.length} links from '
                                '${_result.statuses.where((s) => s.outcome == NuvioScraperOutcome.links).length} scrapers',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _result.isLoading
                            ? cs.primary
                            : cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_result.isLoading)
                    SizedBox(
                      width: 70,
                      child: LinearProgressIndicator(
                        value: _result.totalCount == 0
                            ? null
                            : _result.completedCount / _result.totalCount,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )
                  else
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _showDetails = !_showDetails),
                      icon: const Icon(Icons.info_outline_rounded, size: 16),
                      label: const Text('Details'),
                    ),
                ],
              ),
            ),
            if (_showDetails)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Per-plugin result',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: _diagnosticsReport()),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Diagnostics copied'),
                              ),
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
                            for (final status in _result.statuses)
                              Text(
                                '${status.addonLabel}: '
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
              ),
            Expanded(
              child: streams.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _result.isLoading
                              ? 'Asking your Nuvio scrapers…'
                              : _result.hasWork
                              ? 'No links found for this title.'
                              : 'No Nuvio scrapers are enabled. Add a plugin '
                                    'repository in the Plugins tab.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      itemCount: streams.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final stream = streams[index];
                        final canDownload =
                            !stream.isTorrent && stream.url.startsWith('http');
                        return Material(
                          color: cs.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: () => _play(stream),
                            autofocus: index == 0,
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          stream.quality?.trim().isNotEmpty ??
                                                  false
                                              ? stream.quality!
                                              : 'Auto',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        Text(
                                          stream.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: cs.onSurfaceVariant,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          [
                                            stream.scraperName,
                                            if (stream.size != null)
                                              stream.size!,
                                            if (stream.isTorrent) 'torrent',
                                          ].join(' · '),
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: cs.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Play',
                                    onPressed: () => _play(stream),
                                    icon: const Icon(Icons.play_arrow_rounded),
                                  ),
                                  IconButton(
                                    tooltip: canDownload
                                        ? 'Download'
                                        : 'Stream-only link',
                                    onPressed: canDownload
                                        ? () => unawaited(_download(stream))
                                        : null,
                                    icon: const Icon(Icons.download_rounded),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
