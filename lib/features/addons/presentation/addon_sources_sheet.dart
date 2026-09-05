import 'dart:async';
import 'dart:ui' as ui;

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
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
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
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                    color: Colors.white,
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
    final subtitleText = episode != null
        ? 'S${episode.season} · E${episode.episode} ${episode.name}'
        : (_result.isLoading
            ? 'Asking add-ons… ${_result.completedCount}/${_result.totalCount}'
            : '${_result.streams.length} links from ${_result.respondedCount} add-on(s)');
    final visible = _visible;

    final topPick = visible.isNotEmpty ? visible.first : null;
    final remainingReady =
        visible.length > 1 ? visible.sublist(1) : <AddonStreamSource>[];

    // Dynamic Capsule: Centered floating glass island.
    // Clean Hyprland-inspired blur: sigmaX: 18, alpha: 0.80, 1px white/12 border, zero colored glow.
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      elevation: 0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 580,
                    maxHeight: 680,
                  ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.50),
                  blurRadius: 50,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. LAYERED TRANSLUCENT OBSIDIAN/CHARCOAL BLACK BASE WITH BACKDROP BLUR
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 22.0, sigmaY: 22.0),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xA6060608), // Frosted glass obsidian tint (65% opacity)
                        ),
                      ),
                    ),
                  ),
                  // 4. FRESNEL EDGE HIGHLIGHTS WITH SOFT GRADIENT BLENDING
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ShaderMask(
                        shaderCallback: (rect) {
                          return const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.white,
                              Colors.white,
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.15, 0.85, 1.0],
                          ).createShader(rect);
                        },
                        blendMode: BlendMode.dstIn,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Main content
                  Positioned.fill(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    // Header Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 12, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Stremio Sources',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitleText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cs.primary.withValues(alpha: 0.15),
                            ),
                            child: IconButton(
                              tooltip: 'Refresh',
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                Icons.refresh_rounded,
                                size: 19,
                                color: cs.primary,
                              ),
                              onPressed: () =>
                                  unawaited(_start(forceRefresh: true)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: 'Close',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: Color(0xFFEF4444),
                            ),
                            hoverColor:
                                const Color(0xFFEF4444).withValues(alpha: 0.15),
                            highlightColor:
                                const Color(0xFFEF4444).withValues(alpha: 0.2),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),

                    // Telemetry Status Strip
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _result.isLoading
                                  ? 'Asking add-ons… '
                                        '${_result.completedCount}/${_result.totalCount}'
                                  : '${_result.streams.length} links from '
                                        '${_result.respondedCount} add-on(s)',
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
                              width: 80,
                              child: LinearProgressIndicator(
                                value: _result.totalCount == 0
                                    ? null
                                    : _result.completedCount /
                                          _result.totalCount,
                                minHeight: 2.5,
                                backgroundColor: Colors.white10,
                                valueColor: AlwaysStoppedAnimation(cs.primary),
                              ),
                            )
                          else if (_result.statuses.isNotEmpty)
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(50, 26),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => setState(
                                () => _showDetails = !_showDetails,
                              ),
                              child: Text(
                                _showDetails ? 'Hide' : 'Details',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (_debridStatus != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
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

                    // Filter Chips Rail
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              visualDensity: VisualDensity.compact,
                              label: const Text(
                                '1080p+',
                                style: TextStyle(fontSize: 11),
                              ),
                              selected: _hdOnly,
                              selectedColor: cs.primary,
                              labelStyle: TextStyle(
                                fontSize: 11,
                                color: _hdOnly
                                    ? cs.onPrimary
                                    : cs.onSurfaceVariant,
                                fontWeight: _hdOnly
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                              side: BorderSide(
                                color: _hdOnly
                                    ? Colors.transparent
                                    : Colors.white.withValues(alpha: 0.15),
                                width: 1,
                              ),
                              backgroundColor: Colors.transparent,
                              onSelected: (value) =>
                                  setState(() => _hdOnly = value),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                          for (final filter in _KindFilter.values)
                            if (filter == _KindFilter.all ||
                                _result.streams.any(filter.matches))
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: FilterChip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(
                                    filter.label,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  selected: _kind == filter,
                                  selectedColor: cs.primary,
                                  labelStyle: TextStyle(
                                    fontSize: 11,
                                    color: _kind == filter
                                        ? cs.onPrimary
                                        : cs.onSurfaceVariant,
                                    fontWeight: _kind == filter
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                  side: BorderSide(
                                    color: _kind == filter
                                        ? Colors.transparent
                                        : Colors.white.withValues(alpha: 0.15),
                                    width: 1,
                                  ),
                                  backgroundColor: Colors.transparent,
                                  onSelected: (value) =>
                                      setState(() => _kind = filter),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Stream Source List (Structured with Top Pick & Ready to play)
                    Expanded(
                      child: visible.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: _result.isLoading
                                    ? Text(
                                        'Asking active add-ons…',
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: cs.onSurfaceVariant,
                                            ),
                                      )
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
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
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
                                                icon: const Icon(
                                                  Icons.refresh_rounded,
                                                ),
                                                label: const Text('Retry'),
                                              ),
                                              OutlinedButton.icon(
                                                onPressed: () => setState(
                                                  () => _showDetails = true,
                                                ),
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
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                              children: [
                                // Top Pick Highlighted Section
                                if (topPick != null) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 2,
                                      bottom: 6,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: cs.primary.withValues(
                                              alpha: 0.16,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            'TOP PICK',
                                            style: TextStyle(
                                              color: cs.primary,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.6,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _SourceRow(
                                    stream: topPick,
                                    isBest: true,
                                    autofocus: true,
                                    downloadMode: _mode == SourcesMode.download,
                                    onPlay: () => unawaited(_play(topPick)),
                                    onDownload: () =>
                                        unawaited(_download(topPick)),
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // Remaining Ready to Play Section
                                if (remainingReady.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 2,
                                      bottom: 6,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.play_circle_outline_rounded,
                                          size: 14,
                                          color: Color(0xFF10B981),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Ready to play (${remainingReady.length})',
                                          style: const TextStyle(
                                            color: Color(0xFF10B981),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  for (
                                    int i = 0;
                                    i < remainingReady.length;
                                    i++
                                  ) ...[
                                    if (i > 0) const SizedBox(height: 6),
                                    _SourceRow(
                                      stream: remainingReady[i],
                                      isBest: false,
                                      autofocus: topPick == null && i == 0,
                                      downloadMode:
                                          _mode == SourcesMode.download,
                                      onPlay: () => unawaited(
                                        _play(remainingReady[i]),
                                      ),
                                      onDownload: () => unawaited(
                                        _download(remainingReady[i]),
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
),
),
),
),
);
  }
}

class _DpadSourceButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? tooltip;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final FocusNode? focusNode;
  final KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent;

  const _DpadSourceButton({
    required this.icon,
    required this.label,
    this.tooltip,
    required this.onPressed,
    this.isPrimary = false,
    this.focusNode,
    this.onKeyEvent,
  });

  @override
  State<_DpadSourceButton> createState() => _DpadSourceButtonState();
}

class _DpadSourceButtonState extends State<_DpadSourceButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    if (!enabled) {
      return ExcludeFocus(
        child: Tooltip(
          message: widget.tooltip ?? '',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                const SizedBox(width: 4),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final dpadButton = DpadFocusable(
      focusNode: widget.focusNode,
      onSelect: widget.onPressed,
      child: const SizedBox.shrink(),
      builder: (context, state, _) {
        final isFocused = state.focused;
        final highlight = isFocused || _isHovered;
        const hotstarAccent = Color(0xFF0A84FF);

        final Color bgColor;
        final Color borderColor;
        final Color contentColor;

        if (widget.isPrimary) {
          if (highlight) {
            bgColor = Colors.white;
            borderColor = Colors.white;
            contentColor = hotstarAccent;
          } else {
            bgColor = hotstarAccent;
            borderColor = hotstarAccent;
            contentColor = Colors.white;
          }
        } else {
          if (highlight) {
            bgColor = hotstarAccent.withValues(alpha: 0.20);
            borderColor = hotstarAccent;
            contentColor = Colors.white;
          } else {
            bgColor = Colors.white.withValues(alpha: 0.06);
            borderColor = Colors.white.withValues(alpha: 0.12);
            contentColor = Colors.white.withValues(alpha: 0.85);
          }
        }

        return Tooltip(
          message: widget.tooltip ?? widget.label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onHover: (hovered) {
                if (_isHovered != hovered) {
                  setState(() => _isHovered = hovered);
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: borderColor,
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      size: 14,
                      color: contentColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: contentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (widget.onKeyEvent != null) {
      return Focus(onKeyEvent: widget.onKeyEvent, child: dpadButton);
    }
    return dpadButton;
  }
}

/// Premium quality badge styled consistently with player UI badges.
class _QualityBadge extends StatelessWidget {
  final String resolution;

  const _QualityBadge({required this.resolution});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final res = resolution.toUpperCase();

    Color accentColor;
    if (res.contains('4K') || res.contains('2160') || res.contains('UHD')) {
      accentColor = const Color(0xFFFFB800);
    } else if (res.contains('1080')) {
      accentColor = const Color(0xFF38BDF8);
    } else if (res.contains('720')) {
      accentColor = const Color(0xFF34D399);
    } else {
      accentColor = cs.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: Text(
        resolution,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          color: accentColor,
          letterSpacing: 0.5,
        ),
      ),
    );
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
  bool _isHovered = false;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final stream = widget.stream;
    final isBest = widget.isBest;
    final downloadMode = widget.downloadMode;
    final onPlay = widget.onPlay;
    final onDownload = widget.onDownload;

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
                ? const Color(0xFF242430)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: downloadMode && stream.isDirect ? onDownload : onPlay,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onHover: (hovered) {
                if (_isHovered != hovered) {
                  setState(() => _isHovered = hovered);
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isFocused || _isHovered || isBest
                        ? cs.primary
                        : Colors.white.withValues(alpha: 0.08),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top row: Premium quality badge (left top) + tags, size, and seeders
                    Row(
                      children: [
                        _QualityBadge(resolution: stream.qualityLabel),
                        const SizedBox(width: 8),
                        const SourceTag(
                          text: 'STREMIO',
                          color: Color(0xFF7C6BF5),
                        ),
                        if (stream.isHdr) ...[
                          const SizedBox(width: 6),
                          const SourceTag(
                            text: 'HDR',
                            color: Colors.deepPurpleAccent,
                          ),
                        ],
                        if (stream.isTorrent) ...[
                          const SizedBox(width: 6),
                          SourceTag(text: 'TORRENT', color: cs.primary),
                        ],
                        if (stream.isCachedDebrid) ...[
                          const SizedBox(width: 6),
                          const SourceTag(
                            text: 'CACHED',
                            color: Colors.green,
                          ),
                        ],
                        if (stream.isExternal) ...[
                          const SizedBox(width: 6),
                          SourceTag(
                            text: 'OPENS APP',
                            color: cs.secondary,
                          ),
                        ],
                        if (size != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            size,
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (stream.seeders != null) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.people_alt_outlined,
                            size: 12,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${stream.seeders}',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Source name (starts from left, uses all horizontal space)
                    Text(
                      stream.addonName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Description (starts from left, uses horizontal space)
                    Text(
                      stream.subtitleLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Bottom row: Empty space on the left, Play and Download buttons on the bottom right corner
                    Row(
                      children: [
                        const Spacer(),
                        _DpadSourceButton(
                          focusNode: _playFocusNode,
                          icon: stream.isExternal
                              ? Icons.open_in_new_rounded
                              : Icons.play_arrow_rounded,
                          label: stream.isExternal ? 'Open' : 'Play',
                          isPrimary: true,
                          tooltip: stream.isExternal ? 'Open' : 'Play',
                          onPressed: onPlay,
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
                        const SizedBox(width: 8),
                        _DpadSourceButton(
                          focusNode: _downloadFocusNode,
                          icon: Icons.download_rounded,
                          label: 'Download now',
                          isPrimary: false,
                          tooltip: stream.isDirect
                              ? 'Download now'
                              : 'Torrent sources cannot be downloaded',
                          onPressed: stream.isDirect ? onDownload : null,
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent &&
                                event.logicalKey ==
                                    LogicalKeyboardKey.arrowLeft) {
                              _playFocusNode.requestFocus();
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                        ),
                      ],
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
