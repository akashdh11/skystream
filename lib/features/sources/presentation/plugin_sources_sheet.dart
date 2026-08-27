import 'dart:async';

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

/// One row wrapping a resolved Nuvio scraper link.
class _Row {
  final NuvioStreamResult nuvio;

  const _Row(this.nuvio);

  String get url => nuvio.url;

  String get providerName => nuvio.scraperName;

  /// Consistent detail line: size, language, seeders, and stream name.
  String get detail => buildSourceDetail(
    [
      nuvio.size,
      nuvio.language,
      nuvio.seeders == null ? null : '${nuvio.seeders} seeds',
      nuvio.name ?? nuvio.title,
    ],
    fallback: providerName,
  );

  Map<String, String>? get headers => nuvio.headers;

  bool get isTorrent => nuvio.isTorrent;

  bool get canDownload => url.startsWith('http') && !isTorrent;

  static final RegExp _res = RegExp(r'(\d{3,4})\s*[pi]\b', caseSensitive: false);
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

  late SourcesMode _mode;

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
    _mode = widget.mode;
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
    if (_mode == SourcesMode.download && !row.canDownload) return false;
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

  /// Per-scraper outcome diagnostics.
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
          Row(
            children: [
              Expanded(
                child: Text(
                  'Nuvio scrapers · ${statuses.length}',
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
      initialChildSize: 0.85,
      minChildSize: 0.55,
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
                title: 'Nuvio Sources',
                subtitle: _titleOverride == null && _tmdbOverride == null
                    ? subtitle
                    : 'Searching for "${_titleOverride ?? 'tmdb:$_tmdbOverride'}"',
                trailing: const SourceTag(text: 'NUVIO', color: Colors.teal),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DpadFocusable(
                    onSelect: () => unawaited(_searchManually()),
                    child: const SizedBox.shrink(),
                    builder: (context, state, _) {
                      final isFocused = state.focused;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isFocused ? Colors.white : Colors.transparent,
                            width: 1.5,
                          ),
                          color: isFocused
                              ? cs.primary.withValues(alpha: 0.15)
                              : Colors.transparent,
                        ),
                        child: TextButton.icon(
                          onPressed: () => unawaited(_searchManually()),
                          icon: const Icon(Icons.search_rounded, size: 16),
                          label: Text(
                            _titleOverride == null && _tmdbOverride == null
                                ? 'Search with a different title'
                                : 'Change search title',
                          ),
                        ),
                      );
                    },
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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isLoading
                            ? 'Searching Nuvio scrapers… '
                                  '${_nuvioResult.completedCount}/${_nuvioResult.totalCount}'
                            : '$nuvioCount Nuvio links',
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
                          value: _nuvioResult.totalCount == 0
                              ? null
                              : _nuvioResult.completedCount /
                                    _nuvioResult.totalCount,
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )
                    else if (_nuvioResult.hasWork)
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
                              ? const Text('Searching active Nuvio scrapers…')
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
                                          : 'No links found for this title. '
                                                'Ensure active Nuvio scraper repositories are installed.',
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
      return Focus(
        onKeyEvent: onKeyEvent,
        child: dpadButton,
      );
    }
    return dpadButton;
  }
}

class _SourceRow extends StatefulWidget {
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
    return palette[widget.row.providerName.hashCode.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final row = widget.row;
    final probe = widget.probe;
    final probing = widget.probing;
    final isBest = widget.isBest;
    final downloadMode = widget.downloadMode;
    final onPlay = widget.onPlay;
    final onDownload = widget.onDownload;

    final letter = row.providerName.isEmpty
        ? '?'
        : row.providerName.substring(0, 1).toUpperCase();
    final resolution = probe?.resolutionLabel ?? row.qualityLabel;
    final size = probe?.sizeLabel;

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
        onSelect: downloadMode && row.canDownload ? onDownload : onPlay,
        child: const SizedBox.shrink(),
        builder: (context, state, _) {
        final isFocused = state.focused;
        return Material(
          color: isFocused
              ? cs.surfaceContainerHighest
              : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: downloadMode && row.canDownload ? onDownload : onPlay,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                              resolution,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SourceTag(
                              text: 'NUVIO',
                              color: cs.tertiary,
                            ),
                            if (row.isHdr)
                              SourceTag(text: 'HDR', color: cs.tertiary),
                            if (row.isTorrent)
                              SourceTag(text: 'TORRENT', color: cs.primary),
                            if (isBest)
                              SourceTag(text: 'BEST', color: cs.primary),
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
                            Flexible(
                              child: Text(
                                row.providerName,
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
                            const SizedBox(width: 8),
                            Flexible(
                              child: ProbeBadge(probe: probe, probing: probing),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  _DpadActionButton(
                    focusNode: _playFocusNode,
                    icon: Icons.play_arrow_rounded,
                    tooltip: 'Play',
                    onPressed: onPlay,
                    color: cs.primary,
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                          _cardFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
                            row.canDownload) {
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
                    tooltip: row.canDownload ? 'Download' : 'Stream-only link',
                    onPressed: row.canDownload ? onDownload : null,
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
