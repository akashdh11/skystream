import 'dart:async';

import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/addons/data/addon_repository.dart';
import '../../../../core/addons/data/debrid_service.dart';
import '../../../../core/addons/models/addon_manifest.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/text_input_dialog.dart';
import '../../../../shared/focus/app_focus.dart';
import '../addon_providers.dart';
import '../../../../core/utils/layout_constants.dart';

/// One-tap starter add-ons, matching the official Stremio apps: the two
/// official add-ons that work the moment they are installed — Cinemeta for
/// catalogs and metadata, OpenSubtitles v3 for subtitles. Everything else
/// lives in the community directory on the Discover tab.
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

/// The official add-ons, like the official Stremio client shows them. The
/// community add-ons (Torrentio, Comet, MediaFusion…) are intentionally not
/// repeated here — the Discover tab is their home.
const List<AddonPreset> kAddonPresets = [
  AddonPreset(
    name: 'Cinemeta',
    description: 'Official movie & series catalogs and metadata',
    url: 'https://v3-cinemeta.strem.io/manifest.json',
    icon: Icons.movie_filter_rounded,
  ),
  AddonPreset(
    name: 'OpenSubtitles v3',
    description: 'Subtitles in 60+ languages',
    url: 'https://opensubtitles-v3.strem.io/manifest.json',
    icon: Icons.subtitles_rounded,
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  Future<void> _refreshAll() async {
    // Re-fetch manifests and re-run the liveness badges together — a manual
    // refresh is the moment the user expects honest status, not a cache hit.
    await ref.read(addonRepositoryProvider.notifier).refreshAll();
    ref.invalidate(addonHealthProvider);
  }

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
    final url = await TextInputDialog.show(
      context,
      title: 'Add an add-on',
      message:
          'Paste a manifest URL. stremio:// links and configured URLs '
          '(with ?query settings) work too.',
      hintText: 'https://example.strem.io/manifest.json',
      keyboardType: TextInputType.url,
      confirmLabel: 'Install',
      showPasteButton: true,
      allowEmpty: true,
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
          _DpadDialogButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(dialogContext, false),
            isPrimary: false,
          ),
          _DpadDialogButton(
            label: 'Remove',
            onPressed: () => Navigator.pop(dialogContext, true),
            isPrimary: true,
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
    final healthAsync = ref.watch(addonHealthProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final healthByUrl = healthAsync.value ?? const <String, AddonHealth>{};
    // While the probe is running the tiles show "checking" — but the moment
    // the probe errored as a whole (should not happen, it is one map) the
    // badges simply hide rather than lying.
    final healthProbing = healthAsync.isLoading;
    final healthGone = healthAsync.hasError;
    final searching = _searchQuery.trim().isNotEmpty;
    final filtered = [
      for (final addon in state.addons)
        if (addon.matchesQuery(_searchQuery)) addon,
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        LayoutConstants.shellBottomContentPadding(context),
      ),
      children: [
        // Top Management Card
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.dashboard_customize_rounded, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Add-ons Management',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DpadFocusable(
                      onSelect: () => unawaited(_refreshAll()),
                      child: const SizedBox.shrink(),
                      builder: (context, focusState, _) {
                        final isFocused = focusState.focused;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isFocused
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: IconButton(
                            tooltip: 'Refresh manifests',
                            onPressed: () => unawaited(_refreshAll()),
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Add-ons provide catalogs, metadata, streams and subtitles. '
                  'The first enabled add-on that answers a query wins.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                DpadFocusable(
                  onSelect: () => unawaited(_showAddDialog()),
                  child: const SizedBox.shrink(),
                  builder: (context, focusState, _) {
                    final isFocused = focusState.focused;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFocused ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: FilledButton.icon(
                        onPressed: () => unawaited(_showAddDialog()),
                        icon: const Icon(Icons.add_link_rounded),
                        label: const Text('Add add-on URL'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Quick Add Section
        Text(
          'Quick Install',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in kAddonPresets)
              DpadFocusable(
                onSelect: _busy.contains(preset.url)
                    ? null
                    : () => unawaited(_install(preset.url, label: preset.name)),
                child: const SizedBox.shrink(),
                builder: (context, focusState, _) {
                  final isFocused = focusState.focused;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isFocused ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ActionChip(
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
                          : () => unawaited(
                              _install(preset.url, label: preset.name),
                            ),
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 20),

        // Debrid Account Section
        const _DebridCard(),
        const SizedBox(height: 20),

        // Installed Addons List
        Row(
          children: [
            Text(
              searching
                  ? 'Installed (${filtered.length}/${state.addons.length})'
                  : 'Installed (${state.addons.length})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (state.addons.isNotEmpty && !searching)
              Text(
                'Use 3-dot menu to reorder',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
          ],
        ),
        if (state.addons.length >= 2) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l10n.discoverClearSearch,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _clearSearch,
                    ),
              hintText: l10n.addonManageSearchHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
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
        if (!state.isLoading && state.addons.isNotEmpty && filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              l10n.addonManageNoMatch(_searchQuery),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        // Index into state.addons so reorder stays correct while searching
        // only hides rows (reorder actions are disabled while searching).
        for (int i = 0; i < state.addons.length; i++)
          if (state.addons[i].matchesQuery(_searchQuery))
            _AddonTile(
              key: ValueKey(state.addons[i].manifestUrl),
              addon: state.addons[i],
              index: i,
              isFirst: i == 0,
              isLast: i == state.addons.length - 1,
              health: healthGone
                  ? null
                  : healthByUrl[state.addons[i].manifestUrl],
              healthProbing: !healthGone && healthProbing,
              onToggle: (value) => unawaited(
                ref
                    .read(addonRepositoryProvider.notifier)
                    .setEnabled(state.addons[i].manifestUrl, value),
              ),
              onRemove: () => unawaited(_confirmRemove(state.addons[i])),
              onMoveUp: i > 0 && !searching
                  ? () => unawaited(
                      ref
                          .read(addonRepositoryProvider.notifier)
                          .reorder(i, i - 1),
                    )
                  : null,
              onMoveDown: i < state.addons.length - 1 && !searching
                  ? () => unawaited(
                      ref
                          .read(addonRepositoryProvider.notifier)
                          .reorder(i, i + 2),
                    )
                  : null,
              onConfigure: () async {
                final configureUrl = AddonTransport.baseUrl(
                  state.addons[i].manifestUrl,
                );
                final uri = Uri.tryParse('$configureUrl/configure');
                if (uri == null) return;
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
      ],
    );
  }
}

class _AddonTile extends StatefulWidget {
  final ManagedAddon addon;
  final int index;
  final bool isFirst;
  final bool isLast;

  /// Liveness verdict from [addonHealthProvider] — null while probing.
  final AddonHealth? health;
  final bool healthProbing;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRemove;
  final Future<void> Function() onConfigure;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const _AddonTile({
    super.key,
    required this.addon,
    required this.index,
    required this.isFirst,
    required this.isLast,
    required this.health,
    required this.healthProbing,
    required this.onToggle,
    required this.onRemove,
    required this.onConfigure,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  State<_AddonTile> createState() => _AddonTileState();
}

class _AddonTileState extends State<_AddonTile> {
  late final FocusNode _tileFocusNode;
  late final FocusNode _menuFocusNode;
  final GlobalKey<PopupMenuButtonState<String>> _popupMenuKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tileFocusNode = FocusNode();
    _menuFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _tileFocusNode.dispose();
    _menuFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final manifest = widget.addon.manifest;
    final resources =
        manifest?.resources.map((r) => r.name).toList() ?? const [];

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.arrowRight &&
            _tileFocusNode.hasFocus) {
          _menuFocusNode.requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: DpadFocusable(
        focusNode: _tileFocusNode,
        onSelect: () => widget.onToggle(!widget.addon.enabled),
        child: const SizedBox.shrink(),
        builder: (context, focusState, _) {
          final isTileFocused = focusState.focused && !_menuFocusNode.hasFocus;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isTileFocused ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
            child: Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
                child: Row(
                  children: [
                    // Reorder drag indicator on the far left
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        size: 22,
                      ),
                    ),
                    // Logo
                    if (manifest?.logoUrl != null &&
                        manifest!.logoUrl!.startsWith('http'))
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            manifest.logoUrl!,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            cacheWidth: 96,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.extension_rounded, size: 28),
                          ),
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(Icons.extension_rounded, size: 28),
                      ),
                    // Text and badges
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.addon.displayName}  v${manifest?.version ?? '?'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if ((manifest?.description ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                manifest!.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          if (widget.addon.errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                widget.addon.errorMessage!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.error,
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: _HealthBadge(
                                health: widget.health,
                                probing: widget.healthProbing,
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
                                    color: cs.primaryContainer.withValues(
                                      alpha: 0.6,
                                    ),
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
                    const SizedBox(width: 8),
                    // Actions: Switch and 3-dot popup menu
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: widget.addon.enabled,
                          onChanged: widget.onToggle,
                          thumbIcon: WidgetStateProperty.resolveWith<Icon?>((
                            states,
                          ) {
                            if (isTileFocused ||
                                states.contains(WidgetState.focused) ||
                                states.contains(WidgetState.hovered)) {
                              if (widget.addon.enabled) {
                                return const Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                );
                              } else {
                                return const Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                );
                              }
                            }
                            return null;
                          }),
                        ),
                        const SizedBox(width: 4),
                        Focus(
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent &&
                                event.logicalKey ==
                                    LogicalKeyboardKey.arrowLeft) {
                              _tileFocusNode.requestFocus();
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: DpadFocusable(
                            focusNode: _menuFocusNode,
                            onSelect: () =>
                                _popupMenuKey.currentState?.showButtonMenu(),
                            child: const SizedBox.shrink(),
                            builder: (context, menuFocusState, _) {
                              final isMenuFocused = menuFocusState.focused;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isMenuFocused
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: PopupMenuButton<String>(
                                  key: _popupMenuKey,
                                  icon: const Icon(Icons.more_vert_rounded),
                                  tooltip: 'Options',
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'move_up':
                                        widget.onMoveUp?.call();
                                      case 'move_down':
                                        widget.onMoveDown?.call();
                                      case 'configure':
                                        unawaited(widget.onConfigure());
                                      case 'remove':
                                        widget.onRemove();
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    if (manifest?.behaviorHints.configurable ??
                                        false)
                                      const PopupMenuItem(
                                        value: 'configure',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.open_in_browser_rounded,
                                              size: 20,
                                            ),
                                            SizedBox(width: 8),
                                            Text('Configure in browser'),
                                          ],
                                        ),
                                      ),
                                    if (widget.onMoveUp != null)
                                      const PopupMenuItem(
                                        value: 'move_up',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.arrow_upward_rounded,
                                              size: 20,
                                            ),
                                            SizedBox(width: 8),
                                            Text('Move up'),
                                          ],
                                        ),
                                      ),
                                    if (widget.onMoveDown != null)
                                      const PopupMenuItem(
                                        value: 'move_down',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.arrow_downward_rounded,
                                              size: 20,
                                            ),
                                            SizedBox(width: 8),
                                            Text('Move down'),
                                          ],
                                        ),
                                      ),
                                    const PopupMenuItem(
                                      value: 'remove',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.delete_outline_rounded,
                                            size: 20,
                                            color: Colors.redAccent,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Remove',
                                            style: TextStyle(
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
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

/// Floating D-pad friendly API key entry dialog
class _DebridApiKeyDialog extends StatefulWidget {
  final DebridProvider provider;
  final String initialKey;

  const _DebridApiKeyDialog({required this.provider, required this.initialKey});

  @override
  State<_DebridApiKeyDialog> createState() => _DebridApiKeyDialogState();
}

class _DebridApiKeyDialogState extends State<_DebridApiKeyDialog> {
  late final TextEditingController _controller;
  late final FocusNode _textFocusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialKey);
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
      title: Row(
        children: [
          const Icon(Icons.key_rounded),
          const SizedBox(width: 8),
          Text('${widget.provider.label} API Key'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paste your ${widget.provider.label} API key / token to enable instant debrid link resolving.',
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
              obscureText: true,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'API Key / Token',
                suffixIcon: IconButton(
                  tooltip: 'Paste from clipboard',
                  icon: const Icon(Icons.content_paste_rounded),
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    final text = data?.text;
                    if (text != null && mounted) {
                      _controller.text = text.trim();
                    }
                  },
                ),
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
        _DpadDialogButton(
          label: 'Paste',
          icon: Icons.content_paste_rounded,
          onPressed: () async {
            final data = await Clipboard.getData('text/plain');
            final text = data?.text;
            if (text != null && mounted) {
              _controller.text = text.trim();
            }
          },
          isPrimary: false,
        ),
        _DpadDialogButton(
          label: 'Save Key',
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          isPrimary: true,
        ),
      ],
    );
  }
}

/// Debrid account card.
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

  Future<void> _openApiKeyDialog() async {
    final key = await showDialog<String>(
      context: context,
      builder: (context) => _DebridApiKeyDialog(
        provider: _provider,
        initialKey: _keyController.text,
      ),
    );

    if (key != null && mounted) {
      setState(() {
        _keyController.text = key;
      });
      // Automatically connect if key provided
      if (key.isNotEmpty) {
        await _save();
      }
    }
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

    final hasKey = _keyController.text.isNotEmpty;

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
                    'Debrid Service (Optional)',
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
              'Play torrent results as instant direct links without peer-to-peer wait times.',
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
              const SizedBox(height: 12),
              DpadFocusable(
                onSelect: _openApiKeyDialog,
                child: const SizedBox.shrink(),
                builder: (context, focusState, _) {
                  final isFocused = focusState.focused;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isFocused ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: OutlinedButton.icon(
                      onPressed: _openApiKeyDialog,
                      icon: Icon(
                        hasKey
                            ? Icons.check_circle_outline_rounded
                            : Icons.key_rounded,
                        color: hasKey ? Colors.green : cs.primary,
                      ),
                      label: Text(
                        hasKey
                            ? 'API Key Configured (Tap to change)'
                            : 'Enter API Key',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: hasKey ? cs.onSurface : cs.primary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
            if (config.error != null) ...[
              const SizedBox(height: 8),
              Text(
                config.error!,
                style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                DpadFocusable(
                  onSelect: _saving ? null : () => unawaited(_save()),
                  child: const SizedBox.shrink(),
                  builder: (context, focusState, _) {
                    final isFocused = focusState.focused;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isFocused ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: FilledButton.icon(
                        onPressed: _saving ? null : () => unawaited(_save()),
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.link_rounded),
                        label: Text(
                          _provider == DebridProvider.none
                              ? 'Disable'
                              : 'Connect',
                        ),
                      ),
                    );
                  },
                ),
                if (config.isConfigured) ...[
                  const SizedBox(width: 10),
                  DpadFocusable(
                    onSelect: _saving
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
                    child: const SizedBox.shrink(),
                    builder: (context, focusState, _) {
                      final isFocused = focusState.focused;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isFocused
                                ? Colors.white
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: TextButton.icon(
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
                          icon: const Icon(
                            Icons.link_off_rounded,
                            color: Colors.redAccent,
                          ),
                          label: const Text(
                            'Disconnect',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      );
                    },
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

/// Small Nuvio-style liveness line for one installed add-on: coloured dot +
/// "Working · 340 ms" / "Unavailable" / "Checking add-on…". Every string runs
/// through AppLocalizations — the hardcoded-strings gate polices this file.
class _HealthBadge extends StatelessWidget {
  final AddonHealth? health;
  final bool probing;

  const _HealthBadge({required this.health, required this.probing});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final Color color;
    final IconData icon;
    final String label;
    final health = this.health;
    if (health == null) {
      if (!probing) return const SizedBox.shrink();
      color = cs.onSurfaceVariant;
      icon = Icons.hourglass_top_rounded;
      label = l10n.addonHealthChecking;
    } else {
      switch (health.status) {
        case AddonHealthStatus.working:
          color = const Color(0xFF4CAF50);
          icon = Icons.check_circle_rounded;
          label = l10n.addonHealthWorking(health.latencyMs ?? 0);
        case AddonHealthStatus.unavailable:
          color = cs.error;
          icon = Icons.error_rounded;
          label = l10n.addonHealthUnavailable;
      }
    }

    return Semantics(
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dpad dialog action button matching app's D-pad design
class _DpadDialogButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final IconData? icon;

  const _DpadDialogButton({
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DpadFocusable(
      onSelect: onPressed,
      child: const SizedBox.shrink(),
      builder: (context, state, _) {
        final isFocused = showFocusIndicator(context, state.focused);
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
              ? (icon != null
                    ? FilledButton.icon(
                        onPressed: onPressed,
                        icon: Icon(icon, size: 18),
                        label: Text(label),
                        style: FilledButton.styleFrom(
                          backgroundColor: isFocused ? cs.primary : null,
                        ),
                      )
                    : FilledButton(
                        onPressed: onPressed,
                        style: FilledButton.styleFrom(
                          backgroundColor: isFocused ? cs.primary : null,
                        ),
                        child: Text(label),
                      ))
              : (icon != null
                    ? TextButton.icon(
                        onPressed: onPressed,
                        icon: Icon(icon, size: 18),
                        label: Text(label),
                        style: TextButton.styleFrom(
                          backgroundColor: isFocused
                              ? cs.surfaceContainerHighest
                              : Colors.transparent,
                        ),
                      )
                    : TextButton(
                        onPressed: onPressed,
                        style: TextButton.styleFrom(
                          backgroundColor: isFocused
                              ? cs.surfaceContainerHighest
                              : Colors.transparent,
                        ),
                        child: Text(label),
                      )),
        );
      },
    );
  }
}
