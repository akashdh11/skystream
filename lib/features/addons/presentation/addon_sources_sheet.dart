import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/addons/data/addon_playback_launcher.dart';
import '../../../core/addons/data/addon_repository.dart';
import '../../../core/addons/data/addon_stream_service.dart';
import '../../../core/addons/data/debrid_service.dart';
import '../../../core/addons/models/addon_meta.dart';
import '../../../core/addons/models/addon_stream_source.dart';
import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/download_service.dart';

/// Add-on sources sheet: play or download a title using **only** the links
/// returned by installed add-ons.
class AddonSourcesSheet extends ConsumerStatefulWidget {
  final MultimediaItem item;
  final AddonStreamRequest request;
  final Episode? episode;

  /// Full episode list, forwarded to the player for binge playback.
  final List<AddonVideo> playlist;

  const AddonSourcesSheet({
    super.key,
    required this.item,
    required this.request,
    this.episode,
    this.playlist = const [],
  });

  static Future<void> open(
    BuildContext context, {
    required MultimediaItem item,
    required AddonStreamRequest request,
    Episode? episode,
    List<AddonVideo> playlist = const [],
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddonSourcesSheet(
        item: item,
        request: request,
        episode: episode,
        playlist: playlist,
      ),
    );
  }

  @override
  ConsumerState<AddonSourcesSheet> createState() => _AddonSourcesSheetState();
}

class _AddonSourcesSheetState extends ConsumerState<AddonSourcesSheet> {
  StreamSubscription<AddonStreamProgress>? _sub;
  AddonStreamProgress _result = const AddonStreamProgress(isLoading: true);
  bool _disposed = false;
  bool _showDetails = false;
  bool _hdOnly = false;
  _KindFilter _kind = _KindFilter.all;
  String? _debridStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_start()));
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _start({bool forceRefresh = false}) async {
    // The store loads from disk asynchronously — don't mistake a cold start
    // for "no add-ons installed".
    if (ref.read(addonRepositoryProvider).isLoading) {
      await ref.read(addonRepositoryProvider.notifier).load();
    }
    if (_disposed) return;

    setState(() => _result = const AddonStreamProgress(isLoading: true));
    await _sub?.cancel();
    _sub = ref
        .read(addonStreamServiceProvider)
        .resolve(
          addons: ref.read(addonRepositoryProvider).enabled,
          request: widget.request,
          forceRefresh: forceRefresh,
        )
        .listen((progress) {
          if (_disposed) return;
          setState(() => _result = progress);
        });
  }

  List<AddonStreamSource> get _visible => _result.streams
      .where((s) {
        if (_hdOnly && s.qualityScore < 1080) return false;
        return switch (_kind) {
          _KindFilter.all => true,
          _KindFilter.direct => s.isDirect,
          _KindFilter.torrent => s.isTorrent,
          _KindFilter.external => s.isExternal,
        };
      })
      .toList(growable: false);

  /// Rows that can actually be handed to a player (everything except deep
  /// links into other apps).
  List<AddonStreamSource> get _playable =>
      _visible.where((s) => s.isPlayable).toList(growable: false);

  /// Plays through the app's built-in player — quality filtering, source
  /// switching, subtitle and track menus, gestures, HDR, external-player
  /// hand-off, the seek/buffer watchdog, history and tracker sync. There is no
  /// second, weaker player any more: add-on streams get the same engine as
  /// everything else in the app.
  Future<void> _play(AddonStreamSource stream) async {
    // Deep links (WatchHub & friends) open the streaming service instead of
    // the player — that is the only thing those add-ons can do.
    if (stream.isExternal) {
      await _openExternally(stream);
      return;
    }

    final ordered = _playable;

    // With a debrid account configured, the chosen torrent becomes a direct
    // link before the player sees it. Not cached? The magnet is passed through
    // and the player's own torrent engine takes over.
    var selected = stream;
    if (stream.isTorrent && ref.read(debridSettingsProvider).isConfigured) {
      setState(() => _debridStatus = 'Checking debrid…');
      try {
        final link = await ref
            .read(debridServiceProvider)
            .resolveMagnet(
              stream.magnetUri ?? '',
              preferredFilename: stream.filename,
              onStatus: (status) {
                if (mounted) setState(() => _debridStatus = status);
              },
            );
        if (link != null) {
          selected = AddonStreamSource(
            addonId: stream.addonId,
            addonName: stream.addonName,
            url: link.url,
            name: stream.name,
            title: stream.title,
            description: stream.description,
            videoSize: link.sizeBytes ?? stream.videoSize,
            filename: link.filename ?? stream.filename,
            bingeGroup: stream.bingeGroup,
            subtitles: stream.subtitles,
          );
        }
      } catch (_) {
        // Fall through to the magnet.
      } finally {
        if (mounted) setState(() => _debridStatus = null);
      }
    }

    final converter = ref.read(addonStreamConverterProvider);
    final streams = converter.toStreamResults(ordered, selected: selected);
    if (!mounted) return;
    if (streams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This source has no playable link.')),
      );
      return;
    }

    Navigator.of(context).pop();
    unawaited(
      PlayerRoute(
        $extra: PlayerRouteExtra(
          item: widget.item,
          videoUrl: converter.videoUrlFor(
            contentId: widget.request.contentId,
            videoId: widget.request.videoId,
          ),
          episode: converter.episodeFor(widget.episode, widget.request.videoId),
          preloadedStreams: streams,
        ),
      ).push<void>(context),
    );
  }

  Future<void> _openExternally(AddonStreamSource stream) async {
    final messenger = ScaffoldMessenger.of(context);
    final target = stream.launchUrl;
    final uri = target == null ? null : Uri.tryParse(target);
    if (uri == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('This source has no usable link.')),
      );
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not open ${stream.headline}.')),
        );
      }
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Could not open: $error')));
    }
  }

  Future<void> _download(AddonStreamSource stream) async {
    final messenger = ScaffoldMessenger.of(context);
    final url = stream.url;
    if (url == null || !stream.isDirect) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Torrent sources stream only — press Play instead.'),
        ),
      );
      return;
    }

    final service = ref.read(downloadServiceProvider);
    final item = widget.item;
    final episode = widget.episode;

    try {
      final saveDir = await service.getDownloadPath(item, episode: episode);
      final clean = url.split('?').first.toLowerCase();
      var extension = '.mp4';
      for (final ext in const ['.mp4', '.mkv', '.webm', '.avi', '.mov']) {
        if (clean.endsWith(ext)) extension = ext;
      }

      final String filename;
      if (episode != null && item.contentType != MultimediaContentType.movie) {
        final safe = episode.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
        filename = 'S${episode.season}-E${episode.episode} $safe$extension';
      } else {
        final safe = item.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
        filename = '$safe$extension';
      }

      final started = await service.startDownload(
        url: url,
        filename: filename,
        directory: saveDir,
        item: item,
        episode: episode,
        trackingUrl: url,
        headers: stream.proxyHeaders,
      );

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            started
                ? 'Download started · ${stream.addonName} · ${stream.qualityLabel}'
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final episode = widget.episode;
    final subtitle = episode == null
        ? widget.item.title
        : '${widget.item.title} • S${episode.season} E${episode.episode}';
    final visible = _visible;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
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
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add-on sources',
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
                    onPressed: () => unawaited(_start(forceRefresh: true)),
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
                          ? 'Asking add-ons… ${_result.completedCount}/${_result.totalCount}'
                          : '${_result.streams.length} links from ${_result.respondedCount} add-on(s)',
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
                        value: _result.progress == 0 ? null : _result.progress,
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
            if (_debridStatus != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _debridStatus!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_showDetails) _details(theme, cs),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final filter in _KindFilter.values)
                    if (filter == _KindFilter.all ||
                        _result.streams.any(filter.matches))
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(filter.label),
                          selected: _kind == filter,
                          onSelected: (_) => setState(() => _kind = filter),
                        ),
                      ),
                  FilterChip(
                    label: const Text('1080p+'),
                    selected: _hdOnly,
                    onSelected: (value) => setState(() => _hdOnly = value),
                  ),
                ],
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _result.isLoading
                            ? const Text('Asking your add-ons…')
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
                                        ? 'No links match this filter. '
                                              'Try "All".'
                                        : _result.error ??
                                              'No add-on returned links for '
                                                  'this title. Install a '
                                                  'stream add-on such as '
                                                  'Torrentio, MediaFusion or '
                                                  'WatchHub.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      FilledButton.tonalIcon(
                                        onPressed: () => unawaited(
                                          _start(forceRefresh: true),
                                        ),
                                        icon: const Icon(Icons.refresh_rounded),
                                        label: const Text('Retry'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            setState(() => _showDetails = true),
                                        icon: const Icon(
                                          Icons.info_outline_rounded,
                                        ),
                                        label: const Text('Why?'),
                                      ),
                                    ],
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
                        stream: visible[index],
                        isBest: index == 0,
                        autofocus: index == 0,
                        onPlay: () => unawaited(_play(visible[index])),
                        onDownload: () => unawaited(_download(visible[index])),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _details(ThemeData theme, ColorScheme cs) {
    return Container(
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
          Text(
            'Tried ids: ${widget.request.idCandidates.join(', ')}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          for (final status in _result.statuses)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Icon(
                    switch (status.outcome) {
                      AddonQueryOutcome.links => Icons.check_circle_rounded,
                      AddonQueryOutcome.empty => Icons.remove_circle_outline,
                      AddonQueryOutcome.failed => Icons.error_outline_rounded,
                      AddonQueryOutcome.pending =>
                        Icons.hourglass_empty_rounded,
                    },
                    size: 13,
                    color: switch (status.outcome) {
                      AddonQueryOutcome.links => Colors.green,
                      AddonQueryOutcome.failed => cs.error,
                      _ => cs.onSurfaceVariant,
                    },
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      status.outcome == AddonQueryOutcome.links
                          ? '${status.addonName} · ${status.linkCount} links'
                          : '${status.addonName} · ${status.message ?? 'waiting…'}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  final AddonStreamSource stream;
  final bool isBest;
  final bool autofocus;
  final VoidCallback onPlay;
  final VoidCallback onDownload;

  const _SourceRow({
    required this.stream,
    required this.isBest,
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
    ];
    return palette[stream.addonName.hashCode.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final letter = stream.addonName.isEmpty
        ? '?'
        : stream.addonName.substring(0, 1).toUpperCase();
    final size = stream.sizeLabel;

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPlay,
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
                radius: 20,
                backgroundColor: _avatarColor(),
                child: Text(
                  letter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
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
                          stream.qualityLabel,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (stream.isHdr) _Tag(text: 'HDR', color: cs.tertiary),
                        if (stream.isTorrent)
                          _Tag(text: 'TORRENT', color: cs.primary),
                        if (stream.isCachedDebrid)
                          const _Tag(text: 'CACHED', color: Colors.green),
                        if (stream.isExternal)
                          _Tag(text: 'OPENS APP', color: cs.secondary),
                        if (isBest) _Tag(text: 'BEST', color: cs.primary),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stream.subtitleLine,
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
                          stream.addonName,
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
                        if (stream.seeders != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.people_alt_outlined,
                            size: 12,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${stream.seeders}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: stream.isExternal ? 'Open' : 'Play',
                onPressed: onPlay,
                icon: Icon(
                  stream.isExternal
                      ? Icons.open_in_new_rounded
                      : Icons.play_arrow_rounded,
                ),
              ),
              IconButton(
                tooltip: stream.isDirect
                    ? 'Download'
                    : 'Torrent sources cannot be downloaded',
                onPressed: stream.isDirect ? onDownload : null,
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

/// Source kinds a user can filter by.
enum _KindFilter {
  all('All'),
  direct('Direct'),
  torrent('Torrent'),
  external('Opens app');

  const _KindFilter(this.label);
  final String label;

  bool matches(AddonStreamSource stream) => switch (this) {
    _KindFilter.all => true,
    _KindFilter.direct => stream.isDirect,
    _KindFilter.torrent => stream.isTorrent,
    _KindFilter.external => stream.isExternal,
  };
}
