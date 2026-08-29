import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/extensions/extension_manager.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/download_service.dart';
import '../data/stream_aggregator.dart';
import '../data/stream_browser_provider.dart' show streamAggregatorProvider;
import '../data/stream_source.dart';

/// Bottom sheet listing every link found across all installed plugins for one
/// title/episode, each row playable *or* downloadable.
class StreamSourcePicker extends ConsumerStatefulWidget {
  final MultimediaItem target;
  final Episode? episode;
  const StreamSourcePicker({super.key, required this.target, this.episode});

  static Future<void> open(
    BuildContext context,
    WidgetRef ref,
    MultimediaItem target, {
    Episode? episode,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StreamSourcePicker(target: target, episode: episode),
    );
  }

  @override
  ConsumerState<StreamSourcePicker> createState() => _StreamSourcePickerState();
}

class _StreamSourcePickerState extends ConsumerState<StreamSourcePicker> {
  StreamSubscription<StreamAggregateResult>? _sub;
  StreamAggregateResult _result = const StreamAggregateResult(isLoading: true);

  /// Providers the user has filtered down to. Empty = show everything.
  final Set<String> _pluginFilter = {};
  bool _hdrOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _start() {
    final manager = ref.read(extensionManagerProvider.notifier);
    final aggregator = ref.read(streamAggregatorProvider);
    final stream = widget.episode == null
        ? aggregator.aggregateForMovie(manager: manager, target: widget.target)
        : aggregator.aggregateForEpisode(
            manager: manager,
            target: widget.target,
            episode: widget.episode!,
          );
    _sub = stream.listen((result) {
      if (mounted) setState(() => _result = result);
    });
  }

  List<AggregatedStream> get _visibleStreams {
    return _result.streams.where((s) {
      if (_hdrOnly && !s.isHdr) return false;
      if (_pluginFilter.isNotEmpty && !_pluginFilter.contains(s.providerName)) {
        return false;
      }
      return true;
    }).toList();
  }

  void _play(AggregatedStream source) {
    Navigator.pop(context);
    PlayerRoute(
      $extra: PlayerRouteExtra(
        item: source.detailedItem,
        videoUrl: source.episodeUrl,
        episode: source.episode,
        preloadedStreams: _result.streams
            .map(
              (e) => e.stream.copyWith(
                providerName: e.providerName,
                source: e.stream.source,
              ),
            )
            .toList(),
      ),
    ).push<void>(context);
  }

  /// Mirrors the filename/-path conventions used by the details screen's
  /// download launcher so Stream downloads land beside everything else.
  Future<void> _download(AggregatedStream source) async {
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(downloadServiceProvider);
    final item = source.detailedItem;
    final episode = source.episode;

    try {
      final saveDir = await service.getDownloadPath(item, episode: episode);
      final extension = _extensionFor(source.stream.url);

      String filename;
      if (episode != null && item.contentType != MultimediaContentType.movie) {
        final safe = episode.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
        filename = 'S${episode.season}-E${episode.episode} $safe$extension';
      } else {
        final safe = item.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
        filename = '$safe$extension';
      }

      final started = await service.startDownload(
        url: source.stream.url,
        filename: filename,
        directory: saveDir,
        item: item,
        episode: episode,
        trackingUrl: source.episodeUrl,
        headers: source.stream.headers,
      );

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            started
                ? 'Download started · ${source.providerName}'
                : 'Failed to start download. Check storage permissions.',
          ),
        ),
      );
      if (started) Navigator.of(context).maybePop();
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Download failed: $error')),
      );
    }
  }

  static String _extensionFor(String url) {
    final clean = url.split('?').first.toLowerCase();
    for (final ext in const ['.mp4', '.mkv', '.webm', '.avi', '.mov']) {
      if (clean.endsWith(ext)) return ext;
    }
    // HLS/DASH manifests are remuxed to mp4 by the downloader.
    return '.mp4';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final title = widget.episode == null
        ? widget.target.title
        : '${widget.target.title} • S${widget.episode!.season} E${widget.episode!.episode}';

    final visible = _visibleStreams;
    final plugins = _result.streams.map((e) => e.providerName).toSet().toList()
      ..sort();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Row(
                  children: [
                    if (widget.target.posterUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: widget.target.posterUrl,
                          width: 46,
                          height: 68,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => const SizedBox(
                            width: 46,
                            height: 68,
                            child: Icon(Icons.movie_outlined),
                          ),
                        ),
                      ),
                    if (widget.target.posterUrl.isNotEmpty)
                      const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available Sources',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            title,
                            maxLines: 2,
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

              // Live progress across plugins.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _result.isLoading
                                ? 'Searching plugins… ${_result.completedCount}/${_result.totalCount}'
                                : '${_result.streams.length} links from ${_result.readyProviders.length} plugins',
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
                            width: 90,
                            child: LinearProgressIndicator(
                              value: _result.progress == 0
                                  ? null
                                  : _result.progress,
                              minHeight: 4,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),

              // Filters — only worth showing once there's something to filter.
              if (plugins.length > 1 || _result.streams.any((s) => s.isHdr))
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      if (_result.streams.any((s) => s.isHdr))
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: const Text('HDR'),
                            selected: _hdrOnly,
                            onSelected: (v) => setState(() => _hdrOnly = v),
                          ),
                        ),
                      for (final p in plugins)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(p),
                            selected: _pluginFilter.contains(p),
                            onSelected: (v) => setState(() {
                              if (v) {
                                _pluginFilter.add(p);
                              } else {
                                _pluginFilter.remove(p);
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
                          child: _result.isLoading
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
                                      _result.streams.isNotEmpty
                                          ? 'No links match the current filters.'
                                          : (_result.error ??
                                                'No links found for this title in installed plugins.'),
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
                        itemBuilder: (context, index) => _SourceRow(
                          source: visible[index],
                          isBest: index == 0 && !_hdrOnly,
                          onPlay: () => _play(visible[index]),
                          onDownload: () => _download(visible[index]),
                        ),
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
  final AggregatedStream source;
  final bool isBest;
  final VoidCallback onPlay;
  final VoidCallback onDownload;

  const _SourceRow({
    required this.source,
    required this.isBest,
    required this.onPlay,
    required this.onDownload,
  });

  /// Stable per-plugin colour so the same plugin always reads the same.
  Color _avatarColor(ColorScheme cs) {
    const palette = [
      Color(0xFF7C6BF5),
      Color(0xFF4CAF50),
      Color(0xFFFF9800),
      Color(0xFF2196F3),
      Color(0xFF26C6DA),
      Color(0xFFEC407A),
      Color(0xFFFFC107),
    ];
    return palette[source.providerName.hashCode.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final letter = source.providerName.isEmpty
        ? '?'
        : source.providerName.characters.first.toUpperCase();

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPlay,
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
                backgroundColor: _avatarColor(cs),
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            source.qualityLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (source.isHdr) ...[
                          const SizedBox(width: 6),
                          _Tag(text: 'HDR', color: cs.tertiary),
                        ],
                        if (isBest) ...[
                          const SizedBox(width: 6),
                          _Tag(text: 'BEST', color: cs.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      source.providerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
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
                tooltip: 'Download',
                onPressed: onDownload,
                icon: const Icon(Icons.download_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
