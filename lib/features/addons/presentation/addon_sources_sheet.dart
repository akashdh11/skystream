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
import '../../../core/services/download_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/focus/app_focus.dart';
import '../../details/presentation/playback_launcher.dart';
import '../../settings/presentation/player_settings_provider.dart';
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
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.65),
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

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _searchOpen = false;
  String _searchQuery = '';

  /// Whether the sheet was opened to download rather than to play. It is fixed
  /// for the lifetime of the sheet — both actions sit on every row, so the mode
  /// only picks the default action and hides links that cannot be saved.
  bool get _downloadMode => widget.mode == SourcesMode.download;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_start()));
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchController.clear();
        _searchQuery = '';
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  void _applyProviderFilter(String name, {required bool selected}) {
    setState(() {
      if (selected) {
        _searchQuery = name;
        _searchController.value = TextEditingValue(
          text: name,
          selection: TextSelection.collapsed(offset: name.length),
        );
      } else {
        _searchQuery = '';
        _searchController.clear();
      }
    });
  }

  Widget _headerAction({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
      ),
      child: IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.standard,
        icon: Icon(icon, size: kSourceSheetHeaderIcon, color: color),
        onPressed: onPressed,
      ),
    );
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
        if (_downloadMode && (!s.isDirect || s.url == null)) {
          return false;
        }
        if (!s.matchesQuery(_searchQuery)) return false;
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

    // Which player opens this is a setting, so it is the launcher's call, not
    // the sheet's. Resolved here rather than inside the launcher because the
    // sheet is about to pop and a cold settings box would otherwise finish
    // loading after its context is gone.
    final launcher = ref.read(playbackLauncherProvider);
    await ref.read(playerSettingsProvider.future);
    if (!mounted) return;

    Navigator.of(context).pop();
    unawaited(
      launcher.playResolved(
        context,
        item: widget.item,
        videoUrl: converter.videoUrlFor(
          contentId: widget.request.contentId,
          videoId: widget.request.videoId,
        ),
        episode: converter.episodeFor(widget.episode, widget.request.videoId),
        streams: streams,
      ),
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
      ..writeln(
        'id candidates: ${widget.request.idCandidates.join(', ')}'
        '${widget.request.imdbId == null ? '' : ' (imdb ${widget.request.imdbId})'}'
        '${widget.request.title == null ? '' : ' · title lookup on'}',
      )
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
    final glass = GlassPalette.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: glass.ink.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: glass.ink.withValues(alpha: 0.08)),
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
                    color: glass.ink,
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
                              AddonQueryOutcome.links => cs.primary,
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

  Widget _topPickLabel(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
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
    );
  }

  Widget _readyToPlayLabel(int count) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Row(
        children: [
          Icon(Icons.play_circle_outline_rounded, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            'Ready to play ($count)',
            style: TextStyle(
              color: cs.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
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
    final glass = GlassPalette.of(context);
    final l10n = AppLocalizations.of(context)!;
    final episode = widget.episode;
    final subtitleText = episode != null
        ? 'S${episode.season} · E${episode.episode} ${episode.name}'
        : (_result.isLoading
              ? 'Asking add-ons… ${_result.completedCount}/${_result.totalCount}'
              : '${_result.streams.length} links from ${_result.respondedCount} add-on(s)');
    final visible = _visible;

    final topPick = visible.isNotEmpty ? visible.first : null;
    final remainingReady = visible.length > 1
        ? visible.sublist(1)
        : <AddonStreamSource>[];
    // The list is built lazily, so its sections have to be counted up front:
    // two slots for the top pick (its label and its card), then one label
    // ahead of everything else.
    final rowCount =
        (topPick == null ? 0 : 2) +
        (remainingReady.isEmpty ? 0 : 1 + remainingReady.length);

    // Dynamic Capsule: Centered floating glass island.
    // Clean Hyprland-inspired blur: sigmaX: 18, alpha: 0.80, 1px white/12 border, zero colored glow.
    return GlassSheetScaffold(
      title: 'Stremio Sources',
      subtitle: subtitleText,
      actions: [
        _headerAction(
          tooltip: _searchOpen
              ? l10n.addonSourcesCloseSearchTooltip
              : l10n.addonSourcesSearchTooltip,
          icon: _searchOpen ? Icons.search_off_rounded : Icons.search_rounded,
          onPressed: _toggleSearch,
          color: cs.primary,
        ),
        _headerAction(
          tooltip: 'Refresh',
          icon: Icons.refresh_rounded,
          onPressed: () => unawaited(_start(forceRefresh: true)),
          color: cs.primary,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Telemetry Status Strip
          Padding(
            padding: const EdgeInsets.fromLTRB(
              kSourceSheetGutter,
              4,
              kSourceSheetGutter,
              4,
            ),
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
                          : _result.completedCount / _result.totalCount,
                      minHeight: 2.5,
                      backgroundColor: glass.ink.withValues(alpha: 0.1),
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
                    onPressed: () =>
                        setState(() => _showDetails = !_showDetails),
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
              padding: const EdgeInsets.fromLTRB(
                kSourceSheetGutter,
                0,
                kSourceSheetGutter,
                4,
              ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: kSourceSheetGutter,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: SourceFilterChip(
                    text: '1080p+',
                    selected: _hdOnly,
                    outline: glass.tint(0.15),
                    onSelected: (value) => setState(() => _hdOnly = value),
                  ),
                ),
                for (final filter in _KindFilter.values)
                  if (filter == _KindFilter.all ||
                      _result.streams.any(filter.matches))
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: SourceFilterChip(
                        text: filter.label,
                        selected: _kind == filter,
                        outline: glass.tint(0.15),
                        onSelected: (_) => setState(() => _kind = filter),
                      ),
                    ),
              ],
            ),
          ),

          if (_searchOpen) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                kSourceSheetGutter,
                6,
                kSourceSheetGutter,
                0,
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.discoverClearSearch,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: _clearSearch,
                        ),
                  hintText: l10n.addonSourcesSearchHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            if (_result.streams.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: kSourceSheetGutter,
                    ),
                    children: [
                      for (final name in addonStreamProviderLabels(
                        _result.streams,
                      ))
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: SourceFilterChip(
                            text: name,
                            selected:
                                _searchQuery.trim().toLowerCase() ==
                                name.toLowerCase(),
                            outline: glass.tint(0.15),
                            onSelected: (selected) =>
                                _applyProviderFilter(name, selected: selected),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],

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
                              style: theme.textTheme.bodyMedium?.copyWith(
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
                                      ? l10n.addonSourcesNoMatchFilter
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
                                      onPressed: () =>
                                          unawaited(_start(forceRefresh: true)),
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
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      kSourceSheetGutter,
                      4,
                      kSourceSheetGutter,
                      16,
                    ),
                    itemCount: rowCount,
                    itemBuilder: (context, index) {
                      if (topPick != null) {
                        if (index == 0) return _topPickLabel(cs);
                        if (index == 1) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SourceRow(
                              stream: topPick,
                              isBest: true,
                              autofocus: true,
                              downloadMode: _downloadMode,
                              onPlay: () => unawaited(_play(topPick)),
                              onDownload: () => unawaited(_download(topPick)),
                            ),
                          );
                        }
                      }

                      // Past the top pick: one label, then the rest.
                      var slot = index - (topPick == null ? 0 : 2);
                      if (slot == 0) {
                        return _readyToPlayLabel(remainingReady.length);
                      }
                      slot -= 1;

                      final stream = remainingReady[slot];
                      return Padding(
                        padding: EdgeInsets.only(top: slot == 0 ? 0 : 6),
                        child: _SourceRow(
                          stream: stream,
                          isBest: false,
                          autofocus: topPick == null && slot == 0,
                          downloadMode: _downloadMode,
                          onPlay: () => unawaited(_play(stream)),
                          onDownload: () => unawaited(_download(stream)),
                        ),
                      );
                    },
                  ),
          ),
        ],
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
    final glass = GlassPalette.of(context);
    final stream = widget.stream;
    final isBest = widget.isBest;
    final downloadMode = widget.downloadMode;
    final onPlay = widget.onPlay;
    final onDownload = widget.onDownload;

    final size = stream.sizeLabel;

    return DpadFocusable(
      focusNode: _cardFocusNode,
      autofocus: widget.autofocus,
      onSelect: downloadMode && stream.isDirect ? onDownload : onPlay,
      // Play lives inside the card's own rect, so it can never clear the
      // `centre.dx >= target.right` test native RIGHT traversal applies — this
      // one hop stays hand-rolled. The primary-focus guard stops it firing
      // again for a RIGHT that bubbled up from Download, which has nowhere
      // further to go.
      onDirection: (direction) {
        if (direction != TraversalDirection.right ||
            !_cardFocusNode.hasPrimaryFocus) {
          return false;
        }
        _playFocusNode.requestFocus();
        return true;
      },
      child: const SizedBox.shrink(),
      builder: (context, state, _) {
        final isFocused = showFocusIndicator(context, state.focused);
        return GlassRow(
          focused: isFocused,
          accented: isBest,
          onTap: downloadMode && stream.isDirect ? onDownload : onPlay,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top row: Premium quality badge (left top) + tags, size, and seeders
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        QualityBadge(resolution: stream.qualityLabel),
                        SourceTag(
                          text: 'STREMIO',
                          container: cs.primaryContainer,
                          onContainer: cs.onPrimaryContainer,
                        ),
                        if (stream.isHdr)
                          SourceTag(
                            text: 'HDR',
                            container: cs.tertiaryContainer,
                            onContainer: cs.onTertiaryContainer,
                          ),
                        if (stream.isTorrent)
                          SourceTag(
                            text: 'TORRENT',
                            container: cs.secondaryContainer,
                            onContainer: cs.onSecondaryContainer,
                          ),
                        if (stream.isCachedDebrid)
                          SourceTag(
                            text: 'CACHED',
                            container: cs.tertiaryContainer,
                            onContainer: cs.onTertiaryContainer,
                          ),
                        if (stream.isExternal)
                          SourceTag(
                            text: 'OPENS APP',
                            container: cs.surfaceContainerHighest,
                            onContainer: cs.onSurfaceVariant,
                          ),
                        if (size != null)
                          Text(
                            size,
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (stream.seeders != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Add-on · provider (Nuvio-style: which add-on, which source
              // inside it). Quality lives in the badge above so it is never
              // missing from the row.
              Text(
                stream.headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: glass.ink,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),

              // Stream's own label + description from the add-on.
              Text(
                stream.subtitleLine,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),

              // Bottom row: Empty space on the left, Play and Download buttons on the bottom right corner
              SourceCardActions(
                cardFocusNode: _cardFocusNode,
                child: Row(
                  children: [
                    const Spacer(),
                    DpadSourceButton(
                      focusNode: _playFocusNode,
                      icon: stream.isExternal
                          ? Icons.open_in_new_rounded
                          : Icons.play_arrow_rounded,
                      label: stream.isExternal ? 'Open' : 'Play',
                      isPrimary: true,
                      tooltip: stream.isExternal ? 'Open' : 'Play',
                      onPressed: onPlay,
                      onDirection: (direction) {
                        // Back out to the card the same way we came in.
                        if (direction == TraversalDirection.left) {
                          _cardFocusNode.requestFocus();
                          return true;
                        }
                        if (direction == TraversalDirection.right) {
                          // Consumed either way: with a download chip beside
                          // it focus moves there, and without one Play is the
                          // row's last control. See the Download handler for
                          // why being last has to be stated.
                          if (stream.isDirect) {
                            _downloadFocusNode.requestFocus();
                          }
                          return true;
                        }
                        return false;
                      },
                    ),
                    const SizedBox(width: 8),
                    DpadSourceButton(
                      focusNode: _downloadFocusNode,
                      icon: Icons.download_rounded,
                      label: 'Download now',
                      isPrimary: false,
                      tooltip: stream.isDirect
                          ? 'Download now'
                          : 'Torrent sources cannot be downloaded',
                      onPressed: stream.isDirect ? onDownload : null,
                      onDirection: (direction) {
                        switch (direction) {
                          case TraversalDirection.left:
                            _playFocusNode.requestFocus();
                            return true;
                          case TraversalDirection.right:
                            // Download is the row's last control, so RIGHT
                            // stays put - and says so, instead of falling
                            // through to the default policy and trusting that
                            // nothing sits to the right. Flutter keeps a
                            // candidate whose CENTRE passes this chip's right
                            // edge, so the header's buttons become targets the
                            // moment they move.
                            return true;
                          case TraversalDirection.up:
                          case TraversalDirection.down:
                            return false;
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
