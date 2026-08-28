import 'dart:async';

import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../sources/presentation/source_sheet_widgets.dart';

/// Add-on sources sheet: play or download a title using **only** the links
/// returned by installed add-ons.
class AddonSourcesSheet extends ConsumerStatefulWidget {
  final MultimediaItem item;
  final AddonStreamRequest request;
  final Episode? episode;
  final SourcesMode mode;

  /// Full episode list, forwarded to the player for binge playback.
  final List<AddonVideo> playlist;

  const AddonSourcesSheet({
    super.key,
    required this.item,
    required this.request,
    this.episode,
    this.playlist = const [],
    this.mode = SourcesMode.play,
  });

  static Future<void> open(
    BuildContext context, {
    required MultimediaItem item,
    required AddonStreamRequest request,
    Episode? episode,
    List<AddonVideo> playlist = const [],
    SourcesMode mode = SourcesMode.play,
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
        mode: mode,
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
  late SourcesMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_start()));
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _start({bool forceRefresh = false}) async {
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
        if (_mode == SourcesMode.download && (!s.isDirect || s.url == null)) {
          return false;
        }
        return switch (_kind) {
          _KindFilter.all => true,
          _KindFilter.direct => s.isDirect,
          _KindFilter.torrent => s.isTorrent,
          _KindFilter.external => s.isExternal,
        };
      })
      .toList(growable: false);

  List<AddonStreamSource> get _playable =>
      _visible.where((s) => s.isPlayable).toList(growable: false);

  Future<void> _play(AddonStreamSource stream) async {
    if (stream.isExternal) {
      await _openExternally(stream);
      return;
    }

    final ordered = _playable;
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
      if (started && mounted) await Navigator.of(context).maybePop();
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Download failed: $error')),
      );
    }
  }

  String _diagnosticsReport() {
    final buffer = StringBuffer()
      ..writeln('Addon sources diagnostics')
      ..writeln('title: ${widget.item.title}')
      ..writeln('id candidates: ${widget.request.idCandidates.join(', ')}')
      ..writeln(
        'add-ons: ${_result.streams.length} links, '
        '${_result.completedCount}/${_result.totalCount} done',
      );
    for (final status in _result.statuses) {
      buffer.writeln(
        '- ${status.addonName}: ${status.outcome.name}'
        '${status.outcome == AddonQueryOutcome.links ? ' (${status.linkCount})' : ''}'
        '${status.message == null ? '' : ' — ${status.message}'}',
      );
    }
    return buffer.toString();
  }

  Widget _details(ThemeData theme, ColorScheme cs) {
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
          Row(
            children: [
              Expanded(
                child: Text(
                  'Add-on status · ${_result.statuses.length}',
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
          Text(
            'Tried ids: ${widget.request.idCandidates.join(', ')}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final status in _result.statuses)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          Icon(
                            switch (status.outcome) {
                              AddonQueryOutcome.links =>
                                Icons.check_circle_rounded,
                              AddonQueryOutcome.empty =>
                                Icons.remove_circle_outline,
                              AddonQueryOutcome.failed =>
                                Icons.error_outline_rounded,
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
            ),
          ),
        ],
      ),
    );
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
      initialChildSize: 0.85,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, scrollController) => DecoratedBox(
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
              title: 'Add-on Sources',
              subtitle: subtitle,
              trailing: const SourceTag(
                text: 'STREMIO',
                color: Color(0xFF7C6BF5),
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
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
                      width: 90,
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
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
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
            const SizedBox(height: 4),
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
                                        ? 'No links match this filter. Try "All".'
                                        : _result.error ??
                                              'No add-on returned links for this title. '
                                                  'Install a stream add-on such as Torrentio, '
                                                  'MediaFusion or WatchHub.',
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
                        downloadMode: _mode == SourcesMode.download,
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
}

class _DpadActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final FocusNode? focusNode;
  final KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent;

  const _DpadActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.focusNode,
    this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onPressed != null;

    if (!enabled) {
      return ExcludeFocus(
        child: IconButton(
          tooltip: tooltip,
          onPressed: null,
          icon: Icon(icon, color: cs.onSurface.withValues(alpha: 0.3)),
        ),
      );
    }

    final dpadButton = DpadFocusable(
      focusNode: focusNode,
      onSelect: onPressed,
      child: const SizedBox.shrink(),
      builder: (context, state, _) {
        final isFocused = state.focused;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFocused
                ? (color ?? cs.primary).withValues(alpha: 0.25)
                : Colors.transparent,
            border: Border.all(
              color: isFocused ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            icon: Icon(
              icon,
              color: isFocused ? Colors.white : (color ?? cs.onSurface),
            ),
          ),
        );
      },
    );

    if (onKeyEvent != null) {
      return Focus(onKeyEvent: onKeyEvent, child: dpadButton);
    }
    return dpadButton;
  }
}

class _SourceRow extends StatefulWidget {
  final AddonStreamSource stream;
  final bool isBest;
  final bool autofocus;
  final bool downloadMode;
  final VoidCallback onPlay;
  final VoidCallback onDownload;

  const _SourceRow({
    required this.stream,
    required this.isBest,
    required this.onPlay,
    required this.onDownload,
    this.autofocus = false,
    this.downloadMode = false,
  });

  @override
  State<_SourceRow> createState() => _SourceRowState();
}

class _SourceRowState extends State<_SourceRow> {
  late final FocusNode _cardFocusNode;
  late final FocusNode _playFocusNode;
  late final FocusNode _downloadFocusNode;

  @override
  void initState() {
    super.initState();
    _cardFocusNode = FocusNode();
    _playFocusNode = FocusNode();
    _downloadFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _cardFocusNode.dispose();
    _playFocusNode.dispose();
    _downloadFocusNode.dispose();
    super.dispose();
  }

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
    return palette[widget.stream.addonName.hashCode.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final stream = widget.stream;
    final isBest = widget.isBest;
    final downloadMode = widget.downloadMode;
    final onPlay = widget.onPlay;
    final onDownload = widget.onDownload;

    final letter = stream.addonName.isEmpty
        ? '?'
        : stream.addonName.substring(0, 1).toUpperCase();
    final size = stream.sizeLabel;

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _playFocusNode.requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: DpadFocusable(
        focusNode: _cardFocusNode,
        autofocus: widget.autofocus,
        onSelect: downloadMode && stream.isDirect ? onDownload : onPlay,
        child: const SizedBox.shrink(),
        builder: (context, state, _) {
          final isFocused = state.focused;
          return Material(
            color: isFocused
                ? cs.surfaceContainerHighest
                : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: downloadMode && stream.isDirect ? onDownload : onPlay,
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isFocused
                        ? Colors.white
                        : (isBest
                            ? cs.primary.withValues(alpha: 0.8)
                            : Colors.transparent),
                    width: isFocused ? 2 : (isBest ? 1.5 : 0),
                  ),
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
                                stream.qualityLabel,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SourceTag(
                                text: 'STREMIO',
                                color: Color(0xFF7C6BF5),
                              ),
                              if (stream.isHdr)
                                SourceTag(text: 'HDR', color: cs.tertiary),
                              if (stream.isTorrent)
                                SourceTag(text: 'TORRENT', color: cs.primary),
                              if (stream.isCachedDebrid)
                                const SourceTag(
                                  text: 'CACHED',
                                  color: Colors.green,
                                ),
                              if (stream.isExternal)
                                SourceTag(
                                  text: 'OPENS APP',
                                  color: cs.secondary,
                                ),
                              if (isBest)
                                SourceTag(text: 'BEST', color: cs.primary),
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
                              Flexible(
                                child: Text(
                                  stream.addonName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
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
                    const SizedBox(width: 4),
                    _DpadActionButton(
                      focusNode: _playFocusNode,
                      icon: stream.isExternal
                          ? Icons.open_in_new_rounded
                          : Icons.play_arrow_rounded,
                      tooltip: stream.isExternal ? 'Open' : 'Play',
                      onPressed: onPlay,
                      color: cs.primary,
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent) {
                          if (event.logicalKey ==
                              LogicalKeyboardKey.arrowLeft) {
                            _cardFocusNode.requestFocus();
                            return KeyEventResult.handled;
                          }
                          if (event.logicalKey ==
                                  LogicalKeyboardKey.arrowRight &&
                              stream.isDirect) {
                            _downloadFocusNode.requestFocus();
                            return KeyEventResult.handled;
                          }
                        }
                        return KeyEventResult.ignored;
                      },
                    ),
                    _DpadActionButton(
                      focusNode: _downloadFocusNode,
                      icon: Icons.download_rounded,
                      tooltip: stream.isDirect
                          ? 'Download'
                          : 'Torrent sources cannot be downloaded',
                      onPressed: stream.isDirect ? onDownload : null,
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                          _playFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
