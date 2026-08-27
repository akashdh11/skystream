import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nuvio/data/nuvio_repository.dart';
import '../../../core/nuvio/data/nuvio_runtime.dart';
import '../../../core/nuvio/data/nuvio_stream_service.dart';
import '../../../core/nuvio/models/nuvio_models.dart';
import 'nuvio_scraper_settings_dialog.dart';

/// Manage Nuvio-format plugin repositories.
///
/// Mirrors what NuvioMobile's plugin settings screen does: every repository is
/// re-checked so versions published by the developer arrive on their own, each
/// scraper shows its own version (and what it moved from), scrapers with
/// `hasSettings` get their own form, and any scraper can be test-run.
class NuvioPluginsView extends ConsumerStatefulWidget {
  const NuvioPluginsView({super.key});

  @override
  ConsumerState<NuvioPluginsView> createState() => _NuvioPluginsViewState();
}

class _NuvioPluginsViewState extends ConsumerState<NuvioPluginsView> {
  bool _busy = false;
  bool _checking = false;

  Future<void> _addRepository() async {
    // Captured before the dialog await so the context isn't used across gaps.
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Nuvio plugin repository'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste the plugin manifest URL (the JSON listing "scrapers"). '
              'A bare host works too.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: 'https://example.com/plugins/manifest.json',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Paste',
                  icon: const Icon(Icons.content_paste_rounded),
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    final text = data?.text;
                    if (text != null) controller.text = text.trim();
                  },
                ),
              ),
              onSubmitted: (value) =>
                  Navigator.pop(dialogContext, value.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (url == null || url.isEmpty) return;

    setState(() => _busy = true);
    try {
      final repo = await ref
          .read(nuvioRepositoryProvider.notifier)
          .addRepository(url);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Added ${repo.displayName} '
            '${repo.manifest?.version ?? ''} · '
            '${repo.manifest?.scrapers.length ?? 0} plugins',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkForUpdates() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _checking = true);
    try {
      final changes = await ref
          .read(nuvioRepositoryProvider.notifier)
          .refreshAll();
      // New plugin code means old results are stale.
      ref.read(nuvioStreamServiceProvider).clearCache();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            changes == 0
                ? 'All Nuvio plugins are up to date'
                : '$changes plugin${changes == 1 ? '' : 's'} updated',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nuvioRepositoryProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.extension_rounded, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nuvio plugins',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Switch(
                      value: state.enabled,
                      onChanged: (value) => unawaited(
                        ref
                            .read(nuvioRepositoryProvider.notifier)
                            .setEnabled(value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Scraper plugins in Nuvio\'s format. Their links appear in '
                  'the same sources sheet as SkyStream plugins, tagged NUVIO.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => unawaited(_addRepository()),
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_link_rounded),
                      label: const Text('Add repository'),
                    ),
                    if (state.repos.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: _checking
                            ? null
                            : () => unawaited(_checkForUpdates()),
                        icon: _checking
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.system_update_alt_rounded),
                        label: Text(
                          _checking ? 'Checking…' : 'Check for updates',
                        ),
                      ),
                  ],
                ),
                if (state.repos.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: state.autoUpdate,
                    onChanged: (value) => unawaited(
                      ref
                          .read(nuvioRepositoryProvider.notifier)
                          .setAutoUpdate(value),
                    ),
                    title: Text(
                      'Update plugins automatically',
                      style: theme.textTheme.bodyMedium,
                    ),
                    subtitle: Text(
                      'Checks each repository on launch (at most every '
                      '${NuvioRepository.autoUpdateInterval.inHours} h) and '
                      'downloads the versions the developer published.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (state.isLoading && state.repos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!state.isLoading && state.repos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
            child: Text(
              'No Nuvio repositories yet. Add one and its scrapers will start '
              'contributing links to Explore playback.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        for (final repo in state.repos) _RepoCard(repo: repo),
      ],
    );
  }
}

String _relativeTime(DateTime? time) {
  if (time == null) return 'never';
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

class _RepoCard extends ConsumerStatefulWidget {
  final NuvioRepo repo;
  const _RepoCard({required this.repo});

  @override
  ConsumerState<_RepoCard> createState() => _RepoCardState();
}

class _RepoCardState extends ConsumerState<_RepoCard> {
  bool _expanded = true;

  Future<void> _refresh() async {
    final messenger = ScaffoldMessenger.of(context);
    final summary = await ref
        .read(nuvioRepositoryProvider.notifier)
        .refreshRepository(widget.repo.manifestUrl, silent: true);
    ref.read(nuvioStreamServiceProvider).clearCache();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          summary == null
              ? 'Could not reach that repository'
              : (summary.hasChanges ? summary.label : 'Already up to date'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repo;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final manifest = repo.manifest;
    final scrapers = manifest?.scrapers ?? const <NuvioScraperInfo>[];
    final update = repo.lastUpdate;
    final changed = update?.changedScraperIds ?? const <String>{};

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              repo.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _Badge(
                            text: 'v${manifest?.version ?? '?'}',
                            color: cs.primary,
                          ),
                          if (repo.isRefreshing) ...[
                            const SizedBox(width: 6),
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${scrapers.length} plugins · checked '
                        '${_relativeTime(repo.lastCheckedAt)}'
                        '${repo.lastUpdatedAt != null ? ' · updated ${_relativeTime(repo.lastUpdatedAt)}' : ''}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Check this repository',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: repo.isRefreshing
                      ? null
                      : () => unawaited(_refresh()),
                ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => unawaited(
                    ref
                        .read(nuvioRepositoryProvider.notifier)
                        .removeRepository(repo.manifestUrl),
                  ),
                ),
              ],
            ),
            if (update != null && update.hasChanges)
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.new_releases_rounded,
                      size: 14,
                      color: cs.tertiary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        update.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.tertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (repo.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 6),
                child: Text(
                  repo.errorMessage!,
                  style: theme.textTheme.labelSmall?.copyWith(color: cs.error),
                ),
              ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                  label: Text(_expanded ? 'Hide plugins' : 'Show plugins'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => unawaited(
                    ref
                        .read(nuvioRepositoryProvider.notifier)
                        .setAllScrapersEnabled(repo.manifestUrl, true),
                  ),
                  child: const Text('Enable all'),
                ),
                TextButton(
                  onPressed: () => unawaited(
                    ref
                        .read(nuvioRepositoryProvider.notifier)
                        .setAllScrapersEnabled(repo.manifestUrl, false),
                  ),
                  child: const Text('Disable all'),
                ),
                const SizedBox(width: 4),
              ],
            ),
            if (_expanded)
              for (final scraper in scrapers)
                _ScraperTile(
                  repo: repo,
                  scraper: scraper,
                  justUpdated: changed.contains(scraper.id),
                  previousVersion: update?.updated
                      .where((entry) => entry.scraper.id == scraper.id)
                      .map((entry) => entry.from)
                      .firstOrNull,
                ),
          ],
        ),
      ),
    );
  }
}

class _ScraperTile extends ConsumerStatefulWidget {
  final NuvioRepo repo;
  final NuvioScraperInfo scraper;
  final bool justUpdated;
  final String? previousVersion;

  const _ScraperTile({
    required this.repo,
    required this.scraper,
    this.justUpdated = false,
    this.previousVersion,
  });

  @override
  ConsumerState<_ScraperTile> createState() => _ScraperTileState();
}

class _ScraperTileState extends ConsumerState<_ScraperTile> {
  bool _testing = false;
  String? _testResult;

  /// Nuvio tests a provider against TMDB 603 (The Matrix).
  static const String _testTmdbId = '603';

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final repository = ref.read(nuvioRepositoryProvider.notifier);
    final runtime = ref.read(nuvioRuntimeProvider);
    try {
      final code = await repository.codeFor(widget.repo, widget.scraper);
      final settings = widget.scraper.hasSettings
          ? await repository.scraperSettings(widget.scraper.id)
          : const <String, dynamic>{};
      final type = widget.scraper.supportsType('movie') ? 'movie' : 'tv';
      final results = await runtime.run(
        code: code,
        scraperId: widget.scraper.id,
        scraperName: widget.scraper.name,
        tmdbId: _testTmdbId,
        mediaType: type,
        season: type == 'tv' ? 1 : null,
        episode: type == 'tv' ? 1 : null,
        settings: settings,
      );
      if (!mounted) return;
      setState(() {
        _testResult = results.isEmpty
            ? 'No links for the test title'
            : '${results.length} links · ${results.first.label}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _testResult = 'Failed: $error');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _openSettings() async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(nuvioRepositoryProvider.notifier);
    final runtime = ref.read(nuvioRuntimeProvider);
    List<NuvioSettingsField> layout;
    Map<String, dynamic> saved;
    try {
      final code = await repository.codeFor(widget.repo, widget.scraper);
      saved = await repository.scraperSettings(widget.scraper.id);
      layout = await runtime.settingsLayout(
        code: code,
        scraperId: widget.scraper.id,
        settings: saved,
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not read settings: $error')),
      );
      return;
    }
    if (!mounted) return;
    if (layout.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('This plugin exposes no settings')),
      );
      return;
    }

    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => NuvioScraperSettingsDialog(
        scraperName: widget.scraper.name,
        fields: layout,
        initialValues: saved,
      ),
    );
    if (values == null) return;
    await repository.saveScraperSettings(widget.scraper.id, values);
    ref.read(nuvioStreamServiceProvider).clearCache();
    messenger.showSnackBar(
      SnackBar(content: Text('${widget.scraper.name} settings saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scraper = widget.scraper;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final enabled = widget.repo.isScraperEnabled(scraper);
    final unsupported = !scraper.isSupportedOn(NuvioRepository.platformName);

    final chips = <String>[
      scraper.supportedTypes
          .map(NuvioScraperInfo.normalizeType)
          .toSet()
          .join('/'),
      if (scraper.contentLanguage.isNotEmpty)
        scraper.contentLanguage.take(3).join(', '),
      if (scraper.formats.isNotEmpty) scraper.formats.take(3).join('/'),
    ];

    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ScraperLogo(url: scraper.logo, name: scraper.name),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            scraper.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _Badge(
                          text: widget.previousVersion != null
                              ? '${widget.previousVersion} → v${scraper.version}'
                              : 'v${scraper.version}',
                          color: widget.justUpdated ? cs.tertiary : cs.outline,
                        ),
                        if (!scraper.manifestEnabled) ...[
                          const SizedBox(width: 4),
                          _Badge(text: 'off by default', color: cs.outline),
                        ],
                        if (scraper.limited) ...[
                          const SizedBox(width: 4),
                          _Badge(text: 'limited', color: cs.outline),
                        ],
                        if (unsupported) ...[
                          const SizedBox(width: 4),
                          _Badge(text: 'unsupported here', color: cs.error),
                        ],
                      ],
                    ),
                    Text(
                      chips.where((c) => c.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (scraper.hasSettings)
                IconButton(
                  tooltip: '${scraper.name} settings',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  onPressed: () => unawaited(_openSettings()),
                ),
              IconButton(
                tooltip: 'Test this plugin',
                visualDensity: VisualDensity.compact,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_circle_outline_rounded, size: 20),
                onPressed: _testing ? null : () => unawaited(_test()),
              ),
              Switch(
                // Repositories often publish torrent providers disabled. The
                // user can always turn one on; only a platform the plugin
                // cannot run on keeps the switch locked.
                value: enabled && !unsupported,
                onChanged: unsupported
                    ? null
                    : (value) => unawaited(
                        ref
                            .read(nuvioRepositoryProvider.notifier)
                            .setScraperEnabled(
                              widget.repo.manifestUrl,
                              scraper.id,
                              value,
                            ),
                      ),
              ),
            ],
          ),
          if (_testResult != null)
            Padding(
              padding: const EdgeInsets.only(left: 44, bottom: 6),
              child: Text(
                _testResult!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _testResult!.startsWith('Failed')
                      ? cs.error
                      : cs.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScraperLogo extends StatelessWidget {
  final String? url;
  final String name;
  const _ScraperLogo({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final letter = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    final fallback = Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(letter, style: Theme.of(context).textTheme.labelMedium),
    );
    final logo = url;
    if (logo == null || logo.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        logo,
        width: 28,
        height: 28,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: color, fontSize: 10),
      ),
    );
  }
}
