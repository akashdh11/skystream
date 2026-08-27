import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/addons/data/addon_repository.dart';
import '../../../../core/addons/data/debrid_service.dart';
import '../../../../core/addons/models/addon_manifest.dart';

/// One-tap starter add-ons: catalogs, streams and subtitles, so a fresh
/// install can be useful in three taps.
class AddonPreset {
  final String name;
  final String description;
  final String url;
  final IconData icon;

  const AddonPreset({
    required this.name,
    required this.description,
    required this.url,
    required this.icon,
  });
}

/// Curated starters. The mix matters: a catalog add-on to browse, a torrent
/// add-on for links, a deep-link add-on for the streaming services themselves,
/// and subtitles.
const List<AddonPreset> kAddonPresets = [
  AddonPreset(
    name: 'Cinemeta',
    description: 'Official movie & series catalogs and metadata',
    url: 'https://v3-cinemeta.strem.io/manifest.json',
    icon: Icons.movie_filter_rounded,
  ),
  AddonPreset(
    name: 'Torrentio',
    description: 'Torrent streams from public trackers',
    url: 'https://torrentio.strem.fun/manifest.json',
    icon: Icons.bolt_rounded,
  ),
  AddonPreset(
    name: 'OpenSubtitles v3',
    description: 'Subtitles in 60+ languages',
    url: 'https://opensubtitles-v3.strem.io/manifest.json',
    icon: Icons.subtitles_rounded,
  ),
  AddonPreset(
    name: 'WatchHub',
    description: 'Where to watch: Netflix, Prime, Plex… (opens the service)',
    url: 'https://watchhub.strem.io/manifest.json',
    icon: Icons.open_in_new_rounded,
  ),
  AddonPreset(
    name: 'MediaFusion',
    description: 'Streams from many sources, debrid-friendly',
    url: 'https://mediafusion.elfhosted.com/manifest.json',
    icon: Icons.hub_rounded,
  ),
  AddonPreset(
    name: 'Comet',
    description: 'Torrent + debrid streams',
    url: 'https://comet.elfhosted.com/manifest.json',
    icon: Icons.bolt_outlined,
  ),
  AddonPreset(
    name: 'Streaming Catalogs',
    description: 'Netflix, Disney+, HBO… catalogs (browse only, no streams)',
    url:
        'https://7a82163c306e-stremio-netflix-catalog-addon.baby-beamup.club/manifest.json',
    icon: Icons.grid_view_rounded,
  ),
];

/// Install / enable / reorder / remove add-ons.
class AddonManageView extends ConsumerStatefulWidget {
  const AddonManageView({super.key});

  @override
  ConsumerState<AddonManageView> createState() => _AddonManageViewState();
}

class _AddonManageViewState extends ConsumerState<AddonManageView> {
  final Set<String> _busy = {};

  Future<void> _install(String url, {String? label}) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(url));
    try {
      final addon = await ref
          .read(addonRepositoryProvider.notifier)
          .install(url);
      messenger.showSnackBar(
        SnackBar(content: Text('Installed ${addon.displayName}')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not install ${label ?? url}: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(url));
    }
  }

  Future<void> _showAddDialog() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add an add-on'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste a manifest URL. stremio:// links and configured URLs '
              '(with ?query settings) work too.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: 'https://example.strem.io/manifest.json',
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
            child: const Text('Install'),
          ),
        ],
      ),
    );

    if (url != null && url.isNotEmpty) await _install(url);
  }

  Future<void> _confirmRemove(ManagedAddon addon) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${addon.displayName}?'),
        content: const Text(
          'Its catalogs, metadata and streams will no longer appear.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref
          .read(addonRepositoryProvider.notifier)
          .remove(addon.manifestUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addonRepositoryProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      itemCount: state.addons.length,
      onReorderItem: (oldIndex, newIndex) => unawaited(
        ref.read(addonRepositoryProvider.notifier).reorder(oldIndex, newIndex),
      ),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      Icon(
                        Icons.dashboard_customize_rounded,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Add-ons',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh manifests',
                        onPressed: () => unawaited(
                          ref
                              .read(addonRepositoryProvider.notifier)
                              .refreshAll(),
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add-ons provide catalogs, metadata, streams and subtitles. '
                    'Drag to reorder — the first add-on that answers wins.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => unawaited(_showAddDialog()),
                    icon: const Icon(Icons.add_link_rounded),
                    label: const Text('Add add-on URL'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Quick add',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in kAddonPresets)
                ActionChip(
                  avatar: _busy.contains(preset.url)
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(preset.icon, size: 18),
                  label: Text(preset.name),
                  tooltip: preset.description,
                  onPressed: _busy.contains(preset.url)
                      ? null
                      : () =>
                            unawaited(_install(preset.url, label: preset.name)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const SizedBox(height: 16),
          const _DebridCard(),
          const SizedBox(height: 20),
          Text(
            'Installed (${state.addons.length})',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (state.isLoading && state.addons.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!state.isLoading && state.addons.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Nothing installed yet. Cinemeta gives you catalogs, Torrentio '
                'gives you streams.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
      itemBuilder: (context, index) {
        final addon = state.addons[index];
        return _AddonTile(
          key: ValueKey(addon.manifestUrl),
          addon: addon,
          index: index,
          onToggle: (value) => unawaited(
            ref
                .read(addonRepositoryProvider.notifier)
                .setEnabled(addon.manifestUrl, value),
          ),
          onRemove: () => unawaited(_confirmRemove(addon)),
          onConfigure: () async {
            final configureUrl = AddonTransport.baseUrl(addon.manifestUrl);
            final uri = Uri.tryParse('$configureUrl/configure');
            if (uri == null) return;
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
        );
      },
    );
  }
}

class _AddonTile extends StatelessWidget {
  final ManagedAddon addon;
  final int index;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRemove;
  final Future<void> Function() onConfigure;

  const _AddonTile({
    super.key,
    required this.addon,
    required this.index,
    required this.onToggle,
    required this.onRemove,
    required this.onConfigure,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final manifest = addon.manifest;
    final resources =
        manifest?.resources.map((r) => r.name).toList() ?? const [];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            if (manifest?.logoUrl != null &&
                (manifest!.logoUrl!.startsWith('http')))
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    manifest.logoUrl!,
                    width: 34,
                    height: 34,
                    fit: BoxFit.cover,
                    cacheWidth: 96,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.extension_rounded, size: 28),
                  ),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(Icons.extension_rounded, size: 28),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${addon.displayName}  v${manifest?.version ?? '?'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if ((manifest?.description ?? '').isNotEmpty)
                    Text(
                      manifest!.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  if (addon.errorMessage != null)
                    Text(
                      addon.errorMessage!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.error,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final resource in resources)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            resource,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Switch(value: addon.enabled, onChanged: onToggle),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'remove':
                    onRemove();
                  case 'configure':
                    unawaited(onConfigure());
                }
              },
              itemBuilder: (context) => [
                if (manifest?.behaviorHints.configurable ?? false)
                  const PopupMenuItem(
                    value: 'configure',
                    child: Text('Configure in browser'),
                  ),
                const PopupMenuItem(value: 'remove', child: Text('Remove')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Debrid account card.
///
/// Add-ons that already embed a debrid token in their configured URL keep
/// working untouched; this is for everything else — it turns torrent results
/// into instant HTTPS links, and silently falls back to peer-to-peer streaming
/// when a torrent isn't cached.
class _DebridCard extends ConsumerStatefulWidget {
  const _DebridCard();

  @override
  ConsumerState<_DebridCard> createState() => _DebridCardState();
}

class _DebridCardState extends ConsumerState<_DebridCard> {
  final TextEditingController _keyController = TextEditingController();
  DebridProvider _provider = DebridProvider.none;
  bool _saving = false;
  bool _initialised = false;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final username = await ref
          .read(debridSettingsProvider.notifier)
          .save(_provider, _keyController.text);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _provider == DebridProvider.none
                ? 'Debrid disabled'
                : 'Connected to ${_provider.label}'
                      '${username == null ? '' : ' as $username'}',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Debrid error: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(debridSettingsProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Seed the fields once the stored config has loaded.
    if (!_initialised && !config.isLoading) {
      _initialised = true;
      _provider = config.provider;
      _keyController.text = config.apiKey;
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flash_on_rounded, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Debrid (optional)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (config.username != null)
                  Chip(
                    avatar: const Icon(Icons.check_rounded, size: 16),
                    label: Text(config.username!),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Play torrent results as instant direct links. Not cached? '
              'SkyStream falls back to peer-to-peer streaming automatically.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DebridProvider>(
              initialValue: _provider,
              decoration: const InputDecoration(
                labelText: 'Provider',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final provider in DebridProvider.values)
                  DropdownMenuItem(
                    value: provider,
                    child: Text(provider.label),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _provider = value ?? DebridProvider.none),
            ),
            if (_provider != DebridProvider.none) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _keyController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'API key',
                  hintText: 'Paste your API key',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
            if (config.error != null) ...[
              const SizedBox(height: 8),
              Text(
                config.error!,
                style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _saving ? null : () => unawaited(_save()),
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link_rounded),
                  label: Text(
                    _provider == DebridProvider.none ? 'Disable' : 'Connect',
                  ),
                ),
                if (config.isConfigured) ...[
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () async {
                            await ref
                                .read(debridSettingsProvider.notifier)
                                .clear();
                            if (!context.mounted) return;
                            setState(() {
                              _provider = DebridProvider.none;
                              _keyController.clear();
                            });
                          },
                    child: const Text('Remove'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
