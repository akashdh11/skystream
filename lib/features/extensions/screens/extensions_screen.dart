import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/layout_constants.dart';
import '../../../core/extensions/models/extension_plugin.dart';
import '../../../core/extensions/models/extension_repository.dart';
import '../../../core/extensions/extension_manager.dart';
import '../../../shared/widgets/custom_widgets.dart';
import '../providers/extensions_controller.dart';
import 'plugin_settings_screen.dart';
import '../../../shared/widgets/loading_indicator.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';

class ExtensionsScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;

  const ExtensionsScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<ExtensionsScreen> createState() => _ExtensionsScreenState();
}

class _ExtensionsScreenState extends ConsumerState<ExtensionsScreen> {
  bool _didEnsureInit = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!_didEnsureInit) {
      _didEnsureInit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(extensionsControllerProvider.notifier).ensureInitialized();
      });
    }
    // Listen for errors
    ref.listen(extensionsControllerProvider, (previous, next) {
      if (next is ExtensionsError &&
          (previous is! ExtensionsError || previous.message != next.message)) {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.error),
            content: Text(next.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.ok),
              ),
            ],
          ),
        );
      }
    });

    final state = ref.watch(extensionsControllerProvider);

    if (widget.isEmbedded) {
      return switch (state) {
        ExtensionsLoading(repositories: []) =>
          const Center(child: AppLoadingIndicator()),
        _ => DefaultTabController(
            key: const ValueKey('installed_extensions_tab_controller'),
            length: 2,
            child: Builder(
              builder: (tabContext) => Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: LayoutConstants.dashboardContentPadding,
                    ),
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: TabBar(
                        indicatorSize: TabBarIndicatorSize.label,
                        indicatorWeight: 3,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                        labelColor: Theme.of(tabContext).colorScheme.primary,
                        unselectedLabelColor:
                            Theme.of(tabContext).colorScheme.onSurfaceVariant,
                        indicatorColor: Theme.of(tabContext).colorScheme.primary,
                        dividerColor: Theme.of(tabContext)
                            .dividerColor
                            .withValues(alpha: 0.2),
                        tabs: [
                          Tab(text: l10n.installed),
                          Tab(text: l10n.repositories),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: TabBarView(
                          children: [
                            _buildInstalledTab(tabContext, ref, state),
                            _buildRepositoriesTab(tabContext, ref, state),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      };
    }

    return switch (state) {
      ExtensionsLoading(repositories: []) => Scaffold(
          appBar: AppBar(title: Text(l10n.extensions)),
          body: const Center(child: AppLoadingIndicator()),
        ),
      _ => DefaultTabController(
          key: const ValueKey('installed_extensions_tab_controller'),
          length: 2,
          child: Builder(
            builder: (tabContext) => Scaffold(
              appBar: AppBar(
                title: Text(l10n.extensions),
                bottom: TabBar(
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                  labelColor: Theme.of(tabContext).colorScheme.primary,
                  unselectedLabelColor:
                      Theme.of(tabContext).colorScheme.onSurfaceVariant,
                  indicatorColor: Theme.of(tabContext).colorScheme.primary,
                  dividerColor:
                      Theme.of(tabContext).dividerColor.withValues(alpha: 0.2),
                  tabs: [
                    Tab(text: l10n.installed),
                    Tab(text: l10n.repositories),
                  ],
                ),
              ),
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: TabBarView(
                    children: [
                      _buildInstalledTab(tabContext, ref, state),
                      _buildRepositoriesTab(tabContext, ref, state),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    };
  }

  Widget _buildInstalledTab(
    BuildContext context,
    WidgetRef ref,
    ExtensionsState state,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final debugPlugins =
        state.installedPlugins.where((p) => p.isDebug).toList();
    final hasDebug = debugPlugins.isNotEmpty;

    final allAvailablePackageNames = state.availablePlugins.values
        .expand((list) => list)
        .map((p) => p.packageName)
        .toSet();

    final installedPlugins = state.installedPlugins
        .where((p) =>
            !p.isDebug &&
            (state.availablePlugins.isEmpty ||
                allAvailablePackageNames.contains(p.packageName)))
        .toList();

    final installedOnlyPlugins = state.installedPlugins
        .where(
          (p) =>
              !p.isDebug &&
              state.availablePlugins.isNotEmpty &&
              !allAvailablePackageNames.contains(p.packageName),
        )
        .toList();
    final hasInstalledOnly = installedOnlyPlugins.isNotEmpty;

    if (state.installedPlugins.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(LayoutConstants.spacingLg),
        children: [
          const SizedBox(height: LayoutConstants.spacingLg),
          _FocusableCard(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(LayoutConstants.spacingLg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.extension_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: LayoutConstants.spacingMd),
                  Text(
                    l10n.noExtensionsInstalled,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: LayoutConstants.spacingSm),
                  Text(
                    l10n.browseRepositoriesToInstall,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: LayoutConstants.spacingLg),
                  Builder(
                    builder: (btnContext) {
                      return FilledButton.icon(
                        icon: const Icon(Icons.explore_outlined),
                        label: Text(l10n.browseRepositories),
                        onPressed: () {
                          DefaultTabController.of(btnContext).animateTo(1);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding:
          const EdgeInsets.only(bottom: 100, top: LayoutConstants.spacingMd),
      addAutomaticKeepAlives: false,
      children: [
        if (hasDebug) _buildDebugSection(context, debugPlugins),
        _buildInstalledSection(context, ref, installedPlugins),
        if (hasInstalledOnly)
          _buildInstalledOnlySection(
            context,
            ref,
            installedOnlyPlugins,
            hasRepos: state.repositories.isNotEmpty,
          ),
      ],
    );
  }

  Widget _buildRepositoriesTab(
    BuildContext context,
    WidgetRef ref,
    ExtensionsState state,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final isEmpty = state.repositories.isEmpty;

    if (isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(LayoutConstants.spacingLg),
        children: [
          const SizedBox(height: LayoutConstants.spacingLg),
          _FocusableCard(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(LayoutConstants.spacingLg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.snippet_folder_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: LayoutConstants.spacingMd),
                  Text(
                    l10n.noReposFound,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: LayoutConstants.spacingSm),
                  Text(
                    l10n.addRepoDescription,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: LayoutConstants.spacingLg),
                  FilledButton.icon(
                    icon: const Icon(Icons.add_circle_outline),
                    label: Text(l10n.addRepository),
                    onPressed: () => _showAddRepoDialog(context, ref),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding:
          const EdgeInsets.only(bottom: 100, top: LayoutConstants.spacingMd),
      addAutomaticKeepAlives: false,
      itemCount: state.repositories.length + 1,
      itemBuilder: (context, index) {
        if (index < state.repositories.length) {
          final repo = state.repositories[index];
          final plugins = state.availablePlugins[repo.url] ?? [];
          return _buildRepositoryCard(
            context,
            ref,
            state,
            repo,
            plugins,
            l10n,
          );
        }

        // Add Repository Button (Always at the bottom of Repos tab)
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LayoutConstants.spacingMd,
            vertical: LayoutConstants.spacingSm,
          ),
          child: _FocusableCard(
            margin: EdgeInsets.zero,
            borderColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.3),
            child: ListTile(
              focusColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.15),
              leading: Icon(
                Icons.add_circle_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                l10n.addRepo,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => _showAddRepoDialog(context, ref),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstalledSection(
    BuildContext context,
    WidgetRef ref,
    List<ExtensionPlugin> plugins,
  ) {
    if (plugins.isEmpty) return const SizedBox.shrink();

    return _FocusableCard(
      margin: const EdgeInsets.symmetric(
        horizontal: LayoutConstants.spacingMd,
        vertical: LayoutConstants.spacingXs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LayoutConstants.spacingMd,
              vertical: LayoutConstants.spacingSm + 4,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: LayoutConstants.spacingSm),
                Text(
                  'Installed Extensions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
          for (int i = 0; i < plugins.length; i++) ...[
            _PluginTile(plugin: plugins[i]),
            if (i < plugins.length - 1)
              Divider(
                height: 1,
                indent: 56,
                endIndent: 16,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildInstalledOnlySection(
    BuildContext context,
    WidgetRef ref,
    List<ExtensionPlugin> plugins, {
    required bool hasRepos,
  }) {
    if (plugins.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return _FocusableCard(
      margin: const EdgeInsets.symmetric(
        horizontal: LayoutConstants.spacingMd,
        vertical: LayoutConstants.spacingXs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LayoutConstants.spacingMd,
              vertical: LayoutConstants.spacingSm + 4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.extension_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 22,
                    ),
                    const SizedBox(width: LayoutConstants.spacingSm),
                    Text(
                      l10n.extensionsNotInRepos,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  hasRepos ? l10n.noLongerInRepo : l10n.addRepoToBrowse,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
          for (int i = 0; i < plugins.length; i++) ...[
            _PluginTile(plugin: plugins[i]),
            if (i < plugins.length - 1)
              Divider(
                height: 1,
                indent: 56,
                endIndent: 16,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDebugSection(
    BuildContext context,
    List<ExtensionPlugin> debugPlugins,
  ) {
    if (debugPlugins.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return _FocusableCard(
      margin: const EdgeInsets.symmetric(
        horizontal: LayoutConstants.spacingMd,
        vertical: LayoutConstants.spacingXs,
      ),
      borderColor: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LayoutConstants.spacingMd,
              vertical: LayoutConstants.spacingSm + 4,
            ),
            child: Text(
              l10n.debugExtensions,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.tertiary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
          for (int i = 0; i < debugPlugins.length; i++) ...[
            _PluginTile(plugin: debugPlugins[i], isDebugSection: true),
            if (i < debugPlugins.length - 1)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              ),
          ],
        ],
      ),
    );
  }


  Widget _buildRepositoryCard(
    BuildContext context,
    WidgetRef ref,
    ExtensionsState state,
    ExtensionRepository repo,
    List<ExtensionPlugin> plugins,
    AppLocalizations l10n,
  ) {
    // True when every plugin in this repo is already installed (non-debug).
    final allInstalled =
        plugins.isNotEmpty &&
        plugins.every(
          (p) => state.installedPlugins.any(
            (i) => !i.isDebug && i.packageName == p.packageName,
          ),
        );

    final isRepoInstalling = plugins.any(
      (p) => state.installingPlugins.contains(p.packageName),
    );

    return _FocusableCard(
      margin: const EdgeInsets.only(
        bottom: LayoutConstants.spacingMd,
        left: LayoutConstants.spacingMd,
        right: LayoutConstants.spacingMd,
      ),
      child: ExpansionTile(
        key: PageStorageKey('repo_${repo.url}'),
        shape: const Border(),
        collapsedShape: const Border(),
        // Start collapsed — repos can be individually expanded.
        initiallyExpanded: false,
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        tilePadding: const EdgeInsets.symmetric(
          horizontal: LayoutConstants.spacingMd,
          vertical: LayoutConstants.spacingXs,
        ),
        // Embed description directly in the title so the buttons stay
        // vertically centred with the whole block and there is no extra
        // gap that the ExpansionTile subtitle property introduces.
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              repo.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (repo.description?.isNotEmpty ?? false) ...[
              const SizedBox(height: 2),
              Text(
                repo.description!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        children: [
          // Repository Actions (Download All / Delete) moved inside children
          // to prevent D-pad focus conflicts with the ExpansionTile header.
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LayoutConstants.spacingMd,
              vertical: LayoutConstants.spacingXs,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isRepoInstalling)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: AppLoadingIndicator(
                      constraints: BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                        maxWidth: 24,
                        maxHeight: 24,
                      ),
                    ),
                  )
                else ...[
                  // Download-all / all-installed indicator.
                  TextButton.icon(
                    icon: Icon(
                      allInstalled
                          ? Icons.check_circle_outline
                          : Icons.download,
                      color: allInstalled
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    label: Text(
                      allInstalled
                          ? 'All installed'
                          : l10n.downloadAllProviders,
                    ),
                    onPressed: allInstalled || plugins.isEmpty
                        ? null
                        : () {
                            final pluginsToInstall = plugins.where((p) {
                              final installed = state.installedPlugins
                                  .cast<ExtensionPlugin?>()
                                  .firstWhere(
                                    (inst) =>
                                        inst?.packageName == p.packageName,
                                    orElse: () => null,
                                  );
                              // Only install if it's missing or if we have a newer version
                              return installed == null ||
                                  p.version > installed.version;
                            }).toList();

                            if (pluginsToInstall.isNotEmpty) {
                              ref
                                  .read(extensionsControllerProvider.notifier)
                                  .installPlugins(pluginsToInstall);
                            }
                          },
                  ),
                  const SizedBox(width: LayoutConstants.spacingSm),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    label: Text(l10n.delete),
                    onPressed: () => _confirmDeleteRepo(context, ref, repo),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          ...plugins.asMap().entries.map((entry) {
            final isLast = entry.key == plugins.length - 1;
            return Column(
              children: [
                _PluginTile(plugin: entry.value),
                if (!isLast)
                  Divider(
                    height: 1,
                    indent: 56,
                    endIndent: 16,
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.5),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  void _confirmDeleteRepo(
    BuildContext context,
    WidgetRef ref,
    ExtensionRepository repo,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeRepoConfirm(repo.name)),
        content: Text(l10n.removeRepoWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(extensionsControllerProvider.notifier)
                  .removeRepository(repo.url);
              Navigator.of(context).pop();
            },
            child: Text(
              l10n.delete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    ).then((_) {
      if (context.mounted) {
        // Automatically handled by framework
      }
    });
  }

  void _showAddRepoDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        surfaceTintColor: Colors.transparent,
        title: Text(l10n.addRepository),
        content: CustomTextField(
          controller: controller,
          hintText: l10n.repoUrlOrShortcode,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              ref
                  .read(extensionsControllerProvider.notifier)
                  .addRepository(value);
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          CustomButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.cancel,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: LayoutConstants.spacingXs),
          CustomButton(
            isPrimary: true,
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref
                    .read(extensionsControllerProvider.notifier)
                    .addRepository(controller.text);
                Navigator.pop(context);
              }
            },
            child: Text(l10n.addRepo),
          ),
        ],
      ),
    ).then((_) {
      if (context.mounted) {
        // Automatically handled by framework
      }
    });
  }
}

// ---------------------------------------------------------------------------
// Plugin tile
// ---------------------------------------------------------------------------
class _PluginTile extends ConsumerStatefulWidget {
  final ExtensionPlugin plugin;
  final bool isDebugSection;

  const _PluginTile({required this.plugin, this.isDebugSection = false});

  @override
  ConsumerState<_PluginTile> createState() => _PluginTileState();
}

class _PluginTileState extends ConsumerState<_PluginTile> {
  final FocusNode _settingsFocusNode = FocusNode();
  Future<List<PluginSettingDefinition>>? _settingsFuture;
  String? _settingsFutureIdentity;

  String _settingsIdentity(ExtensionPlugin plugin) =>
      '${plugin.packageName}:${plugin.version}:${plugin.sourceUrl}';

  Future<List<PluginSettingDefinition>> _settingsFor(ExtensionPlugin plugin) {
    final identity = _settingsIdentity(plugin);
    if (_settingsFuture == null || _settingsFutureIdentity != identity) {
      _settingsFutureIdentity = identity;
      _settingsFuture = ref
          .read(extensionManagerProvider.notifier)
          .getSettingsForPlugin(plugin);
    }
    return _settingsFuture!;
  }

  @override
  void didUpdateWidget(covariant _PluginTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_settingsIdentity(oldWidget.plugin) !=
        _settingsIdentity(widget.plugin)) {
      _settingsFuture = null;
      _settingsFutureIdentity = null;
    }
  }

  @override
  void dispose() {
    _settingsFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (widget.isDebugSection) {
      return ListTile(
        leading: Container(
          padding: const EdgeInsets.all(LayoutConstants.spacingXs),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.tertiary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.bug_report,
            color: Theme.of(context).colorScheme.tertiary,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.plugin.name,
                style: const TextStyle(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: LayoutConstants.spacingXs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                l10n.debug,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          "v${widget.plugin.version} • ${l10n.assetPlugin}",
          style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
        ),
      );
    }

    final state = ref.watch(extensionsControllerProvider);

    final installedPlugin = state.installedPlugins
        .cast<ExtensionPlugin?>()
        .firstWhere((p) {
          if (p == null) return false;
          if (p.isDebug) return false;
          return p.packageName == widget.plugin.packageName;
        }, orElse: () => null);

    final isInstalled = installedPlugin != null;
    final updateAvailable = state.availableUpdates[widget.plugin.packageName];

    final isInstalling = state.installingPlugins.contains(
      widget.plugin.packageName,
    );

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.extension_outlined,
          color: Theme.of(context).colorScheme.primary,
          size: 22,
        ),
      ),
      title: Text(
        widget.plugin.name,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: _buildSubtitle(context, isInstalled, installedPlugin),
      trailing: isInstalling
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: AppLoadingIndicator(
                constraints: BoxConstraints(
                  minWidth: 24,
                  minHeight: 24,
                  maxWidth: 24,
                  maxHeight: 24,
                ),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Update button
                if (isInstalled && updateAvailable != null)
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.green),
                    tooltip: l10n.updateTo(updateAvailable.version.toString()),
                    onPressed: () {
                      ref
                          .read(extensionsControllerProvider.notifier)
                          .updatePlugin(updateAvailable);
                    },
                  ),

                // Settings button
                if (isInstalled)
                  FutureBuilder<List<PluginSettingDefinition>>(
                    future: _settingsFor(installedPlugin),
                    builder: (context, snapshot) {
                      final manifestSettings =
                          installedPlugin.manifest['settings'];
                      final hasManifestSettings =
                          manifestSettings is List &&
                          manifestSettings.isNotEmpty;
                      final hasScriptSettings =
                          snapshot.data?.isNotEmpty ?? false;
                      final declaresScriptSettings =
                          installedPlugin.manifest['hasSettings'] == true;
                      final hasDomains =
                          installedPlugin.domains?.isNotEmpty ?? false;
                      final hasStaticProviders =
                          installedPlugin.providers?.isNotEmpty ?? false;

                      final loadedProviders = ref.watch(
                        extensionManagerProvider,
                      );
                      final hasLoadedSubProviders = loadedProviders.any(
                        (provider) => provider.packageName.startsWith(
                          '${installedPlugin.packageName}::',
                        ),
                      );
                      final hasDynamicProviders = ref
                          .read(extensionManagerProvider.notifier)
                          .getProvidersForPlugin(installedPlugin)
                          .isNotEmpty;

                      final hasSettings =
                          hasManifestSettings ||
                          hasScriptSettings ||
                          declaresScriptSettings ||
                          hasDomains ||
                          hasStaticProviders ||
                          hasDynamicProviders ||
                          hasLoadedSubProviders;

                      if (!hasSettings) {
                        return const SizedBox.shrink();
                      }

                      return IconButton(
                        focusNode: _settingsFocusNode,
                        icon: const Icon(Icons.settings_outlined),
                        tooltip: l10n.settings,
                        onPressed: () async {
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (context) =>
                                  PluginSettingsScreen(plugin: installedPlugin),
                            ),
                          );
                          if (context.mounted) {
                            _settingsFocusNode.requestFocus();
                          }
                        },
                      );
                    },
                  ),

                // Install / delete button
                if (isInstalled)
                  IconButton(
                    icon: Icon(
                      Icons.delete,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    tooltip: l10n.delete,
                    onPressed: () {
                      ref
                          .read(extensionsControllerProvider.notifier)
                          .uninstallPlugin(installedPlugin);
                    },
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.download),
                    tooltip: l10n.install,
                    onPressed: () {
                      ref
                          .read(extensionsControllerProvider.notifier)
                          .installPlugin(widget.plugin);
                    },
                  ),
              ],
            ),
    );
  }

  /// Subtitle widget: description · version/authors line · language chips.
  Widget _buildSubtitle(
    BuildContext context,
    bool isInstalled,
    ExtensionPlugin? installedPlugin,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Description uses bodyMedium so it's comfortably readable.
    final descStyle = textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    // Version + authors line uses bodySmall.
    final metaStyle = textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    // Version from installed copy if present, otherwise from the catalog.
    final version =
        'v${isInstalled ? installedPlugin!.version : widget.plugin.version}';

    // Authors: up to 2, prefixed with "By".
    final authors = widget.plugin.authors.take(2).join(', ');

    final metaParts = [version, if (authors.isNotEmpty) 'By $authors'];
    final metaLine = metaParts.join(' • ');

    final desc = widget.plugin.description;
    final hasDesc = desc != null && desc.isNotEmpty;
    final hasLanguages = widget.plugin.languages.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasDesc)
          Text(
            desc,
            style: descStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 2),
        Text(
          metaLine,
          style: metaStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (hasLanguages) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: widget.plugin.languages.take(5).map((lang) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  lang.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _FocusableCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;

  const _FocusableCard({
    required this.child,
    this.margin,
    this.borderColor,
  });

  @override
  State<_FocusableCard> createState() => _FocusableCardState();
}

class _FocusableCardState extends State<_FocusableCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: widget.margin ?? const EdgeInsets.all(LayoutConstants.spacingMd),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isFocused
                ? theme.colorScheme.primary
                : (widget.borderColor ??
                    theme.dividerColor.withValues(alpha: 0.5)),
            width: _isFocused ? 2.0 : 1.0,
          ),
          boxShadow: _isFocused
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
        child: Material(
          color: Colors.transparent,
          child: widget.child,
        ),
      ),
    );
  }
}
