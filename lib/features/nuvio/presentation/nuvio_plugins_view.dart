import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nuvio/data/nuvio_repository.dart';
import '../../../core/nuvio/data/nuvio_runtime.dart';
import '../../../core/nuvio/data/nuvio_stream_service.dart';
import '../../../core/nuvio/models/nuvio_models.dart';
import '../../../core/utils/layout_constants.dart';
import '../../../shared/widgets/cards_wrapper.dart';
import '../../../shared/widgets/custom_widgets.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/text_input_dialog.dart';
import 'nuvio_scraper_settings_dialog.dart';
import '../../../shared/focus/app_focus.dart';

/// Manage Nuvio-format plugin repositories.
class NuvioPluginsView extends ConsumerStatefulWidget {
  const NuvioPluginsView({super.key});

  @override
  ConsumerState<NuvioPluginsView> createState() => _NuvioPluginsViewState();
}

class _NuvioPluginsViewState extends ConsumerState<NuvioPluginsView> {
  bool _busy = false;
  bool _checking = false;

  Future<void> _addRepository() async {
    final messenger = ScaffoldMessenger.of(context);
    final url = await TextInputDialog.show(
      context,
      title: 'Add Nuvio Repository',
      message: 'Paste the plugin manifest URL (the JSON listing "scrapers"). A bare host works too.',
      hintText: 'https://example.com/plugins/manifest.json',
      confirmLabel: 'Add',
      width: 480,
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
            'Added ${repo.displayName} ${repo.manifest?.version ?? ''} · ${repo.manifest?.scrapers.length ?? 0} plugins',
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

    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: ListView(
        padding: EdgeInsets.only(
          top: LayoutConstants.spacingMd,
          bottom: LayoutConstants.shellBottomContentPadding(context),
        ),
        addAutomaticKeepAlives: false,
        children: [
          _FocusableCard(
            margin: const EdgeInsets.symmetric(
              horizontal: LayoutConstants.spacingMd,
              vertical: LayoutConstants.spacingXs,
            ),
            child: Padding(
              padding: const EdgeInsets.all(LayoutConstants.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.extension_outlined,
                          color: cs.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: LayoutConstants.spacingSm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nuvio Scrapers',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cs.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'JS scrapers feed the Explore sources sheet alongside SkyStream plugins.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: LayoutConstants.spacingXs),
                      CustomSwitch(
                        value: state.enabled,
                        onChanged: (value) => unawaited(
                          ref
                              .read(nuvioRepositoryProvider.notifier)
                              .setEnabled(value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: LayoutConstants.spacingMd),
                  // Full width, or the Wrap shrink-wraps to its two buttons
                  // and `alignment: end` has nothing to align them within -
                  // the group stays at the left and only its internal order
                  // changes.
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      // Right-aligned, with the primary action furthest right.
                      // Every run of the Wrap is aligned, so this still reads
                      // correctly when the two buttons drop onto separate lines on
                      // a narrow window.
                      alignment: WrapAlignment.end,
                      spacing: LayoutConstants.spacingSm,
                      runSpacing: LayoutConstants.spacingXs,
                      children: [
                        if (state.repos.isNotEmpty)
                          CustomButton(
                            isOutlined: true,
                            onPressed: _checking
                                ? null
                                : () => unawaited(_checkForUpdates()),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_checking) ...[
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: AppLoadingIndicator(
                                      constraints: BoxConstraints(
                                        maxWidth: 16,
                                        maxHeight: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ] else ...[
                                  const Icon(Icons.refresh_rounded, size: 18),
                                  const SizedBox(width: 8),
                                ],
                                Text(_checking ? 'Checking…' : 'Check Updates'),
                              ],
                            ),
                          ),
                        CustomButton(
                          isPrimary: true,
                          onPressed: _busy
                              ? null
                              : () => unawaited(_addRepository()),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_busy) ...[
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: AppLoadingIndicator(
                                    constraints: BoxConstraints(
                                      maxWidth: 16,
                                      maxHeight: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ] else ...[
                                const Icon(Icons.add_circle_outline, size: 18),
                                const SizedBox(width: 8),
                              ],
                              const Text('Add Repository'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (state.repos.isNotEmpty) ...[
                    const SizedBox(height: LayoutConstants.spacingSm),
                    Divider(
                      height: 1,
                      color: theme.dividerColor.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: LayoutConstants.spacingXs),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Auto-update scrapers on launch',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Checks each repository (max once every ${NuvioRepository.autoUpdateInterval.inHours}h).',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CustomSwitch(
                          value: state.autoUpdate,
                          onChanged: (value) => unawaited(
                            ref
                                .read(nuvioRepositoryProvider.notifier)
                                .setAutoUpdate(value),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: LayoutConstants.spacingSm),

          if (state.isLoading && state.repos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: AppLoadingIndicator()),
            ),

          if (!state.isLoading && state.repos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LayoutConstants.spacingMd,
                vertical: LayoutConstants.spacingSm,
              ),
              child: _FocusableCard(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(LayoutConstants.spacingLg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.snippet_folder_outlined,
                        size: 48,
                        color: cs.primary,
                      ),
                      const SizedBox(height: LayoutConstants.spacingMd),
                      Text(
                        'No Nuvio Repositories Yet',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: LayoutConstants.spacingSm),
                      Text(
                        'Add a repository URL to load scrapers for stream extraction.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: LayoutConstants.spacingLg),
                      CustomButton(
                        isPrimary: true,
                        onPressed: () => unawaited(_addRepository()),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_circle_outline, size: 18),
                            SizedBox(width: 8),
                            Text('Add Repository'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          for (final repo in state.repos)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LayoutConstants.spacingMd,
                vertical: LayoutConstants.spacingXs,
              ),
              child: _RepoCard(repo: repo),
            ),
        ],
      ),
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
  /// Mirrors the tile's own expansion so [build] can draw the chevron.
  ///
  /// The tile's default trailing chevron is centred on the WHOLE title block -
  /// title plus the scrapers/checked/updated line under it - while anything
  /// put in `title` sits on the title's own line. The version badge was in
  /// `title`, so it and the chevron were on two different centres. Moving the
  /// badge into `trailing` puts them on one, which costs drawing the rotation
  /// here because a custom `trailing` replaces the animated one.
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

  void _confirmDeleteRepo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        surfaceTintColor: Colors.transparent,
        title: Text('Remove ${widget.repo.displayName}?'),
        content: const Text(
          'This will remove the repository and disable all its scraper plugins from source extraction.',
        ),
        actions: [
          CustomButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: LayoutConstants.spacingXs),
          CustomButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              unawaited(
                ref
                    .read(nuvioRepositoryProvider.notifier)
                    .removeRepository(widget.repo.manifestUrl),
              );
            },
            child: Text(
              'Remove',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
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

    return _FocusableCard(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        key: PageStorageKey('nuvio_repo_${repo.manifestUrl}'),
        shape: const Border(),
        collapsedShape: const Border(),
        initiallyExpanded: true,
        onExpansionChanged: (value) => setState(() => _expanded = value),
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        tilePadding: const EdgeInsets.symmetric(
          horizontal: LayoutConstants.spacingMd,
          vertical: LayoutConstants.spacingXs,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (manifest?.version != null)
              _Badge(text: 'v${manifest!.version}', color: cs.primary),
            if (repo.isRefreshing) ...[
              const SizedBox(width: LayoutConstants.spacingXs),
              const SizedBox(
                width: 14,
                height: 14,
                child: AppLoadingIndicator(
                  constraints: BoxConstraints(maxWidth: 14, maxHeight: 14),
                ),
              ),
            ],
            const SizedBox(width: LayoutConstants.spacingXs),
            AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.expand_more_rounded,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              repo.displayName,
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${scrapers.length} scrapers · checked ${_relativeTime(repo.lastCheckedAt)}'
              '${repo.lastUpdatedAt != null ? ' · updated ${_relativeTime(repo.lastUpdatedAt)}' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LayoutConstants.spacingMd,
              vertical: LayoutConstants.spacingXs,
            ),
            child: Row(
              children: [
                CustomButton(
                  onPressed: () => unawaited(
                    ref
                        .read(nuvioRepositoryProvider.notifier)
                        .setAllScrapersEnabled(repo.manifestUrl, true),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, size: 16),
                      SizedBox(width: 6),
                      Text('Enable all'),
                    ],
                  ),
                ),
                const SizedBox(width: LayoutConstants.spacingXs),
                CustomButton(
                  onPressed: () => unawaited(
                    ref
                        .read(nuvioRepositoryProvider.notifier)
                        .setAllScrapersEnabled(repo.manifestUrl, false),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cancel_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Disable all'),
                    ],
                  ),
                ),
                const Spacer(),
                _TvIconButton(
                  tooltip: 'Refresh Repository',
                  icon: Icons.refresh_rounded,
                  onPressed: repo.isRefreshing
                      ? null
                      : () => unawaited(_refresh()),
                ),
                _TvIconButton(
                  tooltip: 'Remove Repository',
                  icon: Icons.delete_outline,
                  color: cs.error,
                  onPressed: () => _confirmDeleteRepo(context),
                ),
              ],
            ),
          ),

          if (update != null && update.hasChanges)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LayoutConstants.spacingMd,
                vertical: LayoutConstants.spacingXs,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.new_releases_outlined,
                    size: 16,
                    color: cs.tertiary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      update.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.tertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (repo.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LayoutConstants.spacingMd,
                vertical: LayoutConstants.spacingXs,
              ),
              child: Text(
                repo.errorMessage!,
                style: theme.textTheme.labelSmall?.copyWith(color: cs.error),
              ),
            ),

          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.5)),

          for (int i = 0; i < scrapers.length; i++) ...[
            _ScraperTile(
              repo: repo,
              scraper: scrapers[i],
              justUpdated: changed.contains(scrapers[i].id),
              previousVersion: update?.updated
                  .where((entry) => entry.scraper.id == scrapers[i].id)
                  .map((entry) => entry.from)
                  .firstOrNull,
            ),
            if (i < scrapers.length - 1)
              Divider(
                height: 1,
                indent: 64,
                endIndent: LayoutConstants.spacingMd,
                color: theme.dividerColor.withValues(alpha: 0.5),
              ),
          ],
        ],
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

  static const String _testTmdbId = '603'; // The Matrix

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
            ? 'No streams returned for test title'
            : '${results.length} streams found · ${results.first.label}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _testResult = 'Test failed: $error');
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
        const SnackBar(
          content: Text('This scraper exposes no configuration options'),
        ),
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

    final typeChips = scraper.supportedTypes
        .map(NuvioScraperInfo.normalizeType)
        .toSet()
        .join(' / ');
    final languages = scraper.contentLanguage.take(3).join(', ');
    final formats = scraper.formats.take(3).join(' / ');

    final metaList = [
      if (typeChips.isNotEmpty) typeChips.toUpperCase(),
      if (languages.isNotEmpty) languages.toUpperCase(),
      if (formats.isNotEmpty) formats.toUpperCase(),
    ];

    final tile = ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: LayoutConstants.spacingMd,
        vertical: 4,
      ),
      leading: _ScraperLogo(url: scraper.logo, name: scraper.name),
      title: Row(
        children: [
          Flexible(
            child: Text(
              scraper.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: LayoutConstants.spacingXs),
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
            _Badge(text: 'unsupported', color: cs.error),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (metaList.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              metaList.join(' • '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
          if (_testResult != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _testResult!.startsWith('Test failed')
                    ? cs.errorContainer.withValues(alpha: 0.4)
                    : cs.secondaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _testResult!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _testResult!.startsWith('Test failed')
                      ? cs.error
                      : cs.onSecondaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (scraper.hasSettings)
            _TvIconButton(
              tooltip: '${scraper.name} Settings',
              icon: Icons.settings_outlined,
              onPressed: () => unawaited(_openSettings()),
            ),
          _TvIconButton(
            tooltip: 'Test Scraper',
            icon: Icons.play_circle_outline_rounded,
            customIcon: _testing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: AppLoadingIndicator(
                      constraints: BoxConstraints(maxWidth: 18, maxHeight: 18),
                    ),
                  )
                : null,
            onPressed: _testing ? null : () => unawaited(_test()),
          ),
          const SizedBox(width: 4),
          CustomSwitch(
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
    );

    return _FocusableRow(child: tile);
  }
}

class _TvIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final Widget? customIcon;

  const _TvIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.customIcon,
  });

  @override
  State<_TvIconButton> createState() => _TvIconButtonState();
}

class _TvIconButtonState extends State<_TvIconButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final enabled = widget.onPressed != null;
    final showFocus = showFocusIndicator(context, _isFocused);

    return Focus(
      canRequestFocus: enabled,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (!enabled) return KeyEventResult.ignored;
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onPressed!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Tooltip(
        message: widget.tooltip,
        child: AnimatedContainer(
          duration: AppFocus.duration,
          width: 38,
          height: 38,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // One neutral ring, and only when a focus indicator belongs on
            // screen. The accent fill, accent border and 12 dp accent halo
            // this replaces were three cues for one state.
            color: AppFocus.rowTint(context, focused: showFocus),
            border: AppFocus.border(context, focused: showFocus),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onPressed,
              child: Center(
                child:
                    widget.customIcon ??
                    Icon(
                      widget.icon,
                      size: 20,
                      color: showFocus
                          ? (widget.color ?? primary)
                          : (widget.color ?? cs.onSurfaceVariant),
                    ),
              ),
            ),
          ),
        ),
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
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        letter,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: cs.primary, fontWeight: FontWeight.bold),
      ),
    );

    final logo = url;
    if (logo == null || logo.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        logo,
        width: 40,
        height: 40,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Dispatched by a [_FocusableRow] whenever it gains or loses focus.
///
/// The enclosing [_FocusableCard] listens so it can stay unlit while one of
/// its scraper rows is the thing the user is pointed at.
class _RowFocusNotification extends Notification {
  final Object row;
  final bool focused;

  _RowFocusNotification(this.row, this.focused);
}

/// The focus affordance for ONE scraper row.
///
/// Draws the app's shared card focus recipe ([CardFocusAffordance]) around a
/// single row and tells the enclosing [_FocusableCard] to stay quiet while it
/// does. Two departures from how [CardsWrapper] applies the same recipe:
///
/// The ring is painted behind the child, not in front of it as [CardsWrapper]
/// does; a row's child is text on a transparent [Material], so a foreground
/// layer would sit over the label it points at.
///
/// An opaque fill sits between the shadow and the row, because Flutter paints
/// a [BoxShadow] across the whole shape rather than just its rim, and without
/// something opaque in the middle it floods the row.
class _FocusableRow extends StatefulWidget {
  final Widget child;

  const _FocusableRow({required this.child});

  @override
  State<_FocusableRow> createState() => _FocusableRowState();
}

class _FocusableRowState extends State<_FocusableRow> {
  /// Tighter than the 16 dp card so the two curves stay roughly concentric
  /// once the row is inset by the ring's width.
  static const BorderRadius _radius = BorderRadius.all(Radius.circular(12));

  bool _isFocused = false;

  void _onFocusChange(bool focused) {
    setState(() => _isFocused = focused);
    _RowFocusNotification(this, focused).dispatch(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Focus(
      // Passive observer: the row is not a traversal stop, the buttons and the
      // switch inside it are, so hasFocus means one of those is focused.
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: _onFocusChange,
      child: Container(
        // The ring is stroke-aligned outside the row, so the row needs that
        // much clearance inside the card's antiAlias clip or the ring is
        // sliced off down both long edges.
        margin: const EdgeInsets.all(CardFocusAffordance.ringWidth),
        decoration: CardFocusAffordance.glow(
          borderRadius: _radius,
          focused: showFocusIndicator(context, _isFocused),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            // The colour the card already fills itself with, so this is
            // invisible until the glow needs something to hide behind.
            color: colorScheme.surface,
            borderRadius: _radius,
          ),
          child: Container(
            decoration: CardFocusAffordance.ring(
              context,
              borderRadius: _radius,
              focused: showFocusIndicator(context, _isFocused),
            ),
            // The row's own ink surface. A ListTile paints its splashes on the
            // nearest Material ancestor, and ink is painted before that
            // Material's child, so without this the two fills above would
            // swallow every splash the row draws.
            child: Material(
              type: MaterialType.transparency,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusableCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;

  const _FocusableCard({required this.child, this.margin});

  @override
  State<_FocusableCard> createState() => _FocusableCardState();
}

class _FocusableCardState extends State<_FocusableCard> {
  bool _isFocused = false;

  /// The [_FocusableRow] inside this card that currently owns the focus, if
  /// any. Identity rather than a counter, so the two notifications of a
  /// row-to-row move are order-independent.
  Object? _focusedRow;

  bool _onRowFocus(_RowFocusNotification notification) {
    setState(() {
      if (notification.focused) {
        _focusedRow = notification.row;
      } else if (identical(_focusedRow, notification.row)) {
        _focusedRow = null;
      }
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // The card lights up only for focus it owns itself, such as its
    // ExpansionTile header or a button in the repository action row. A focused
    // scraper row draws its own affordance instead.
    final highlight = _isFocused && _focusedRow == null;

    return NotificationListener<_RowFocusNotification>(
      onNotification: _onRowFocus,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (focused) => setState(() {
          _isFocused = focused;
          // A focused row can leave the tree (a repository collapses or is
          // removed) without sending its focus-lost notification, which would
          // otherwise mute this card for good.
          if (!focused) _focusedRow = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin:
              widget.margin ?? const EdgeInsets.all(LayoutConstants.spacingMd),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlight
                  ? theme.colorScheme.primary
                  : theme.dividerColor.withValues(alpha: 0.5),
              width: highlight ? 2.0 : 1.0,
            ),
            boxShadow: highlight
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(color: Colors.transparent, child: widget.child),
        ),
      ),
    );
  }
}
