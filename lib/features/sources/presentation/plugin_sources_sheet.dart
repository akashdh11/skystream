import 'dart:async';
import 'dart:ui' as ui;

import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/network/link_probe_service.dart';
import '../../../core/nuvio/data/nuvio_stream_service.dart';
import '../../../core/nuvio/models/nuvio_models.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/download_service.dart';
import '../../../core/utils/source_text.dart';
import 'source_sheet_widgets.dart';

/// Nuvio-powered sources sheet used from Explore / TMDB details.
///
/// Runs scraper repositories in Nuvio's format on background isolates with
/// `getStreams(tmdbId, mediaType, season, episode)`.
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
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) =>
          PluginSourcesSheet(target: target, episode: episode, mode: mode),
    );
  }

  @override
  ConsumerState<PluginSourcesSheet> createState() => _PluginSourcesSheetState();
}

/// One row wrapping a resolved Nuvio scraper link.
class _Row {
  final NuvioStreamResult nuvio;

  const _Row(this.nuvio);

  String get url => nuvio.url;

  String get providerName => nuvio.scraperName;

  /// Consistent detail line: size, language, seeders, and stream name.
  String get detail => buildSourceDetail([
    nuvio.size,
    nuvio.language,
    nuvio.seeders == null ? null : '${nuvio.seeders} seeds',
    nuvio.name ?? nuvio.title,
  ], fallback: providerName);

  Map<String, String>? get headers => nuvio.headers;

  bool get isTorrent => nuvio.isTorrent;

  bool get canDownload => url.startsWith('http') && !isTorrent;

  static final RegExp _res = RegExp(
    r'(\d{3,4})\s*[pi]\b',
    caseSensitive: false,
  );
  static final RegExp _uhd = RegExp(r'\b(4k|uhd|2160)\b', caseSensitive: false);

  int get qualityScore {
    final text = '${nuvio.quality ?? ''} ${nuvio.title} ${nuvio.url}';
    if (_uhd.hasMatch(text)) return 2160;
    final match = _res.firstMatch(text);
    return match == null ? 0 : (int.tryParse(match.group(1)!) ?? 0);
  }

  String get qualityLabel {
    final score = qualityScore;
    if (score >= 2160) return '4K';
    if (score > 0) return '${score}p';
    final quality = nuvio.quality?.trim();
    return (quality == null || quality.isEmpty) ? 'Auto' : quality;
  }

  bool get isHdr => RegExp(
    r'\b(hdr10\+?|hdr|dolby\s*vision|dovi)\b',
    caseSensitive: false,
  ).hasMatch('${nuvio.quality ?? ''} ${nuvio.title}');

  String get key => 'nuvio:${nuvio.scraperId}:${nuvio.url}';

  StreamResult toStreamResult() => nuvio.toStreamResult();
}

class _PluginSourcesSheetState extends ConsumerState<PluginSourcesSheet> {
  StreamSubscription<NuvioProgress>? _nuvioSub;

  NuvioProgress _nuvioResult = const NuvioProgress(isLoading: true);
  bool _showDiagnostics = false;

  final Map<String, LinkProbeResult> _probes = {};
  final Set<String> _probing = {};

  /// Title / TMDB id the user typed in "Search manually".
  String? _titleOverride;
  String? _tmdbOverride;
  final Set<String> _providerFilter = {};
  bool _hdOnly = false;
  bool _verifiedOnly = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startNuvio();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _nuvioSub?.cancel();
    super.dispose();
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

  /// Re-runs the search with a title or TMDB id the user types.
  Future<void> _searchManually() async {
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _ManualSearchDialog(
        initialText: _titleOverride ?? widget.target.title,
        hasOverride: _titleOverride != null || _tmdbOverride != null,
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
      _nuvioResult = const NuvioProgress(isLoading: true);
      _probes.clear();
      _probing.clear();
    });
    await _nuvioSub?.cancel();
    _startNuvio();
  }

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
          _scheduleProbes();
        }),
      );
    }
  }

  List<_Row> get _allRows {
    final rows = <_Row>[
      for (final stream in _nuvioResult.streams) _Row(stream),
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
    if (_verifiedOnly) {
      final probe = _probes[row.url];
      if (probe == null || !probe.reachable) return false;
    }
    return true;
  }).toList();

  bool get _isLoading => _nuvioResult.isLoading;

  void _play(_Row row) {
    final ordered = <_Row>[row, ..._visible.where((r) => r.key != row.key)];
    final streams = [for (final r in ordered) r.toStreamResult()];

    final item = widget.target;
    final episode = widget.episode;
    final videoUrl = widget.target.url.isNotEmpty
        ? widget.target.url
        : 'tmdb:${widget.target.tmdbId}';

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
    final item = widget.target;
    final episode = widget.episode;

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
        trackingUrl: row.url,
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
      if (started && mounted) unawaited(Navigator.of(context).maybePop());
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Download failed: $error')),
      );
    }
  }

  Widget _diagnosticsPanel(ThemeData theme, ColorScheme cs) {
    final statuses = _nuvioResult.statuses.toList()
      ..sort((a, b) => a.scraperName.compareTo(b.scraperName));
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
                  'Nuvio scrapers · ${statuses.length}',
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
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
      ..writeln('Nuvio sources diagnostics')
      ..writeln('title: ${widget.target.title} (tmdb ${widget.target.tmdbId})')
      ..writeln(
        'nuvio scrapers: ${_nuvioResult.streams.length} links, '
        '${_nuvioResult.completedCount}/${_nuvioResult.totalCount} done',
      );
    for (final status in _nuvioResult.statuses) {
      buffer.writeln(
        '- ${status.scraperName}: ${status.outcome.name}'
        '${status.outcome == NuvioScraperOutcome.links ? ' (${status.linkCount})' : ''}'
        '${status.message == null ? '' : ' — ${status.message}'}',
      );
    }
    return buffer.toString();
  }

  bool _showUnavailable = false;

  bool _isRowUnavailable(_Row row) {
    final probe = _probes[row.url];
    if (probe == null) return false;
    if (probe.reachable) return false;
    // Any probe that completed and is not reachable is unavailable (HTTP error, timeout, 404, etc.)
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final episode = widget.episode;

    final visible = _visible;
    final providers = _allRows.map((e) => e.providerName).toSet().toList()
      ..sort();
    final nuvioCount = _nuvioResult.streams.length;

    // Counts for subtitle
    final workingCount =
        _allRows.where((r) => _probes[r.url]?.reachable == true).length;
    final unavailableCount = _allRows.where(_isRowUnavailable).length;

    String subtitleText;
    if (workingCount > 0 || unavailableCount > 0) {
      subtitleText =
          '$workingCount working${unavailableCount > 0 ? ', $unavailableCount unavailable' : ''}';
    } else if (episode != null ||
        _titleOverride != null ||
        _tmdbOverride != null) {
      subtitleText = _titleOverride != null || _tmdbOverride != null
          ? 'Searching: "${_titleOverride ?? 'tmdb:$_tmdbOverride'}"'
          : 'S${episode!.season} · E${episode.episode} ${episode.name}';
    } else {
      subtitleText = _isLoading
          ? 'Searching scrapers… ${_nuvioResult.completedCount}/${_nuvioResult.totalCount}'
          : '$nuvioCount links found';
    }

    // Split visible rows into ready and unavailable
    final readyRows = <_Row>[];
    final unavailableRows = <_Row>[];
    for (final row in visible) {
      if (_isRowUnavailable(row)) {
        unavailableRows.add(row);
      } else {
        readyRows.add(row);
      }
    }

    final topPick = readyRows.isNotEmpty ? readyRows.first : null;
    final remainingReady = readyRows.length > 1 ? readyRows.sublist(1) : <_Row>[];

    // Dynamic Capsule: Centered floating glass island.
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      elevation: 0,
      child: Center(
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
                                  'Nuvio Sources',
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
                          // Accessibility Search Button: Icon in accent on accent-filled circle
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cs.primary.withValues(alpha: 0.15),
                            ),
                            child: IconButton(
                              tooltip: 'Search manually',
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                Icons.search_rounded,
                                size: 19,
                                color: cs.primary,
                              ),
                              onPressed: () => unawaited(_searchManually()),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Accessibility Close Button: Icon in danger, transparent bg, danger hover/tap
                          IconButton(
                            tooltip: 'Close',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: Color(0xFFEF4444),
                            ),
                            hoverColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                            highlightColor: const Color(0xFFEF4444).withValues(alpha: 0.2),
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
                              _isLoading
                                  ? 'Searching scrapers… '
                                        '${_nuvioResult.completedCount}/${_nuvioResult.totalCount}'
                                  : '$nuvioCount links found',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _isLoading ? cs.primary : cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_isLoading)
                            SizedBox(
                              width: 80,
                              child: LinearProgressIndicator(
                                value: _nuvioResult.totalCount == 0
                                    ? null
                                    : _nuvioResult.completedCount /
                                          _nuvioResult.totalCount,
                                minHeight: 2.5,
                                backgroundColor: Colors.white10,
                                valueColor: AlwaysStoppedAnimation(cs.primary),
                              ),
                            )
                          else if (_nuvioResult.hasWork)
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(50, 26),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => setState(
                                () => _showDiagnostics = !_showDiagnostics,
                              ),
                              child: Text(
                                _showDiagnostics ? 'Hide' : 'Details',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (_showDiagnostics) _diagnosticsPanel(theme, cs),

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
                              label: const Text('1080p+', style: TextStyle(fontSize: 11)),
                              selected: _hdOnly,
                              selectedColor: cs.primary,
                              labelStyle: TextStyle(
                                fontSize: 11,
                                color: _hdOnly ? cs.onPrimary : cs.onSurfaceVariant,
                                fontWeight: _hdOnly ? FontWeight.w700 : FontWeight.w500,
                              ),
                              side: BorderSide(
                                color: _hdOnly
                                    ? Colors.transparent
                                    : Colors.white.withValues(alpha: 0.15),
                                width: 1,
                              ),
                              backgroundColor: Colors.transparent,
                              onSelected: (value) => setState(() => _hdOnly = value),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              visualDensity: VisualDensity.compact,
                              label: const Text('Tested', style: TextStyle(fontSize: 11)),
                              selected: _verifiedOnly,
                              selectedColor: cs.primary,
                              labelStyle: TextStyle(
                                fontSize: 11,
                                color: _verifiedOnly ? cs.onPrimary : cs.onSurfaceVariant,
                                fontWeight: _verifiedOnly ? FontWeight.w700 : FontWeight.w500,
                              ),
                              side: BorderSide(
                                color: _verifiedOnly
                                    ? Colors.transparent
                                    : Colors.white.withValues(alpha: 0.15),
                                width: 1,
                              ),
                              backgroundColor: Colors.transparent,
                              onSelected: (value) =>
                                  setState(() => _verifiedOnly = value),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                          for (final provider in providers)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: FilterChip(
                                visualDensity: VisualDensity.compact,
                                label: Text(provider, style: const TextStyle(fontSize: 11)),
                                selected: _providerFilter.contains(provider),
                                selectedColor: cs.primary,
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  color: _providerFilter.contains(provider)
                                      ? cs.onPrimary
                                      : cs.onSurfaceVariant,
                                  fontWeight: _providerFilter.contains(provider)
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                                side: BorderSide(
                                  color: _providerFilter.contains(provider)
                                      ? Colors.transparent
                                      : Colors.white.withValues(alpha: 0.15),
                                  width: 1,
                                ),
                                backgroundColor: Colors.transparent,
                                onSelected: (value) => setState(() {
                                  if (value) {
                                    _providerFilter.add(provider);
                                  } else {
                                    _providerFilter.remove(provider);
                                  }
                                }),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Stream Source List (Structured with Top Pick, Ready, and Unavailable)
                    Expanded(
                      child: visible.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  _isLoading
                                      ? 'Searching active scrapers…'
                                      : (_allRows.isNotEmpty
                                          ? 'No links match the current filters.'
                                          : 'No links found. Verify scraper repos are installed.'),
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                              children: [
                                // Top Pick Highlighted Section
                                if (topPick != null) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(left: 2, bottom: 6),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: cs.primary.withValues(alpha: 0.16),
                                            borderRadius: BorderRadius.circular(4),
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
                                    row: topPick,
                                    probe: _probes[topPick.url],
                                    probing: _probing.contains(topPick.url),
                                    isBest: true,
                                    autofocus: true,
                                    onPlay: () => _play(topPick),
                                    onDownload: () => unawaited(_download(topPick)),
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // Remaining Ready to Play Section
                                if (remainingReady.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(left: 2, bottom: 6),
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
                                  for (int i = 0; i < remainingReady.length; i++) ...[
                                    if (i > 0) const SizedBox(height: 6),
                                    _SourceRow(
                                      row: remainingReady[i],
                                      probe: _probes[remainingReady[i].url],
                                      probing: _probing.contains(remainingReady[i].url),
                                      isBest: false,
                                      autofocus: topPick == null && i == 0,
                                      onPlay: () => _play(remainingReady[i]),
                                      onDownload: () =>
                                          unawaited(_download(remainingReady[i])),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                ],

                                // Unavailable Collapsed Section
                                if (unavailableRows.isNotEmpty) ...[
                                  DpadFocusable(
                                    onSelect: () => setState(
                                      () => _showUnavailable = !_showUnavailable,
                                    ),
                                    child: const SizedBox.shrink(),
                                    builder: (context, state, _) {
                                      final isFocused = state.focused;
                                      return Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isFocused
                                                ? Colors.white
                                                : Colors.transparent,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(8),
                                          onTap: () => setState(
                                            () => _showUnavailable = !_showUnavailable,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 6,
                                            ),
                                            child: Row(
                                              children: [
                                                Text(
                                                  '${unavailableRows.length} unavailable',
                                                  style: TextStyle(
                                                    color: cs.onSurfaceVariant,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                AnimatedRotation(
                                                  turns: _showUnavailable ? 0.5 : 0.0,
                                                  duration: const Duration(
                                                    milliseconds: 200,
                                                  ),
                                                  child: Icon(
                                                    Icons.keyboard_arrow_down_rounded,
                                                    size: 18,
                                                    color: cs.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  if (_showUnavailable) ...[
                                    const SizedBox(height: 6),
                                    for (int i = 0; i < unavailableRows.length; i++) ...[
                                      if (i > 0) const SizedBox(height: 6),
                                      Opacity(
                                        opacity: 0.55,
                                        child: _SourceRow(
                                          row: unavailableRows[i],
                                          probe: _probes[unavailableRows[i].url],
                                          probing: _probing.contains(unavailableRows[i].url),
                                          isBest: false,
                                          autofocus: false,
                                          onPlay: () => _play(unavailableRows[i]),
                                          onDownload: () =>
                                              unawaited(_download(unavailableRows[i])),
                                        ),
                                      ),
                                    ],
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
);
  }
}

/// DPad-navigable manual search dialog that allows moving seamlessly from
/// the text input down to the action buttons.
class _ManualSearchDialog extends StatefulWidget {
  final String initialText;
  final bool hasOverride;

  const _ManualSearchDialog({
    required this.initialText,
    required this.hasOverride,
  });

  @override
  State<_ManualSearchDialog> createState() => _ManualSearchDialogState();
}

class _ManualSearchDialogState extends State<_ManualSearchDialog> {
  late final TextEditingController _controller;
  late final FocusNode _textFocusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _textFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Search Nuvio scrapers manually'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Type a title or TMDB id (or tmdb:123) to re-point the Nuvio scrapers.',
          ),
          const SizedBox(height: 14),
          Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.arrowDown) {
                node.nextFocus();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: _controller,
              focusNode: _textFocusNode,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Title or TMDB id',
              ),
              onSubmitted: (text) => Navigator.pop(context, text.trim()),
            ),
          ),
        ],
      ),
      actions: [
        _DpadDialogButton(
          label: 'Cancel',
          onPressed: () => Navigator.pop(context),
          isPrimary: false,
        ),
        if (widget.hasOverride)
          _DpadDialogButton(
            label: 'Reset',
            onPressed: () => Navigator.pop(context, ''),
            isPrimary: false,
          ),
        _DpadDialogButton(
          label: 'Search',
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          isPrimary: true,
        ),
      ],
    );
  }
}

class _DpadDialogButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _DpadDialogButton({
    required this.label,
    required this.onPressed,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DpadFocusable(
      onSelect: onPressed,
      child: const SizedBox.shrink(),
      builder: (context, state, _) {
        final isFocused = state.focused;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isFocused ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          child: isPrimary
              ? FilledButton(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: isFocused ? cs.primary : null,
                  ),
                  child: Text(label),
                )
              : TextButton(
                  onPressed: onPressed,
                  style: TextButton.styleFrom(
                    backgroundColor: isFocused
                        ? cs.surfaceContainerHighest
                        : Colors.transparent,
                  ),
                  child: Text(label),
                ),
        );
      },
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
  final _Row row;
  final LinkProbeResult? probe;
  final bool probing;
  final bool isBest;
  final bool autofocus;
  final VoidCallback onPlay;
  final VoidCallback onDownload;

  const _SourceRow({
    required this.row,
    required this.probe,
    required this.probing,
    required this.isBest,
    required this.onPlay,
    required this.onDownload,
    this.autofocus = false,
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
    final row = widget.row;
    final probe = widget.probe;
    final probing = widget.probing;
    final isBest = widget.isBest;
    final onPlay = widget.onPlay;
    final onDownload = widget.onDownload;

    final resolution = probe?.resolutionLabel ?? row.qualityLabel;
    final size = probe?.sizeLabel ??
        (row.nuvio.size != null && row.nuvio.size!.trim().isNotEmpty
            ? row.nuvio.size!.trim()
            : null);

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
        onSelect: onPlay,
        child: const SizedBox.shrink(),
        builder: (context, state, _) {
          final isFocused = state.focused;
          return Material(
            color: isFocused
                ? const Color(0xFF242430)
                : const Color(0xFF16161D).withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onPlay,
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
                    // Top row: Premium quality badge (left top) + tags, size, seeders, and probe badge
                    Row(
                      children: [
                        _QualityBadge(resolution: resolution),
                        const SizedBox(width: 8),
                        if (row.isHdr) ...[
                          const SourceTag(
                            text: 'HDR',
                            color: Colors.deepPurpleAccent,
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (row.isTorrent) ...[
                          const SourceTag(text: 'P2P', color: Colors.teal),
                          const SizedBox(width: 6),
                        ],
                        if (size != null) ...[
                          Text(
                            size,
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (row.nuvio.seeders != null) ...[
                          Icon(
                            Icons.people_alt_outlined,
                            size: 12,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${row.nuvio.seeders}',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        const Spacer(),
                        ProbeBadge(
                          probe: probe,
                          probing: probing,
                          isPeerToPeer: row.isTorrent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Source name (starts from left, uses all horizontal space)
                    Text(
                      row.providerName,
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
                      row.detail,
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
                          icon: Icons.play_arrow_rounded,
                          label: 'Play',
                          isPrimary: true,
                          tooltip: 'Play',
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
                                  row.canDownload) {
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
                          tooltip: row.canDownload
                              ? 'Download now'
                              : 'Stream-only link',
                          onPressed: row.canDownload ? onDownload : null,
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
