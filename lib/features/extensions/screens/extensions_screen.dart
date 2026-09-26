import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/layout_constants.dart';
import '../../../core/extensions/models/extension_plugin.dart';
import '../../../core/extensions/models/extension_repository.dart';
import '../../../core/extensions/extension_manager.dart';
import '../providers/extensions_controller.dart';
import 'plugin_settings_dialog.dart';
import '../../../shared/widgets/cards_wrapper.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/text_input_dialog.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/focus/app_focus.dart';

import 'package:skystream/l10n/generated/app_localizations.dart';

class ExtensionsScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;

  const ExtensionsScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<ExtensionsScreen> createState() => _ExtensionsScreenState();
}

class _ExtensionsScreenState extends ConsumerState<ExtensionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _didEnsureInit = false;

  /// One key per tab, so a repair can search the page that is actually on
  /// screen.
  ///
  /// Keys rather than a [FocusScope] around each page, which is the obvious
  /// way to draw the line and the wrong one: a scope is also the boundary
  /// directional traversal works within, so a page wrapped in one would trap
  /// the remote inside it - no way back up to the tabs or the Back button.
  ///
  /// Searching the body as a whole is not good enough: during a tab change
  /// both pages are in the tree, and the first focusable in tree order belongs
  /// to the page being *left* - whose controls are disposed a beat later. The
  /// first version of this fix did exactly that and still ended up with
  /// nothing focused, which is the same dead end wearing a different hat.
  final List<GlobalKey> _tabKeys = <GlobalKey>[
    GlobalKey(debugLabel: 'extensions-tab-installed'),
    GlobalKey(debugLabel: 'extensions-tab-repositories'),
  ];

  /// Set when something inside a tab switches tabs, so the focus that switch
  /// is about to destroy can be put back. See [_showRepositoriesTab].
  bool _wantsBodyFocus = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSettled);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSettled);
    _tabController.dispose();
    super.dispose();
  }

  /// Shows the Repositories tab, and takes focus with it.
  ///
  /// The focus half is the point, and it is the fix for a dead end on a
  /// television. When the Installed tab is empty its only control is the
  /// button that calls this, so the node holding focus is the node switching
  /// tabs destroys - and Flutter drops primary focus when that happens
  /// without telling anybody. [FocusManager.primaryFocus] simply becomes
  /// null, no listener fires, and its `handleKeyMessage` returns early for
  /// every key that arrives afterwards. The screen stops answering the remote
  /// completely: no arrow key has anything left to move *from*.
  ///
  /// A viewer who came here to install their first repository - which is the
  /// only reason a fresh install sends them here - could not reach Add
  /// Repository at all, and the app read as locked.
  void _showRepositoriesTab() {
    _wantsBodyFocus = true;
    _tabController.animateTo(1);
  }

  /// Puts focus in the new tab once the old one has finished sliding away.
  void _handleTabSettled() {
    // The controller notifies twice per change: once as the slide starts and
    // once as it lands. Only the second is any use - during the first the
    // incoming page has not been laid out.
    if (_tabController.indexIsChanging || !_wantsBodyFocus) return;
    _wantsBodyFocus = false;

    _afterNextFrame(_focusFirstInSelectedTab);
  }

  /// The same repair, for the second way this screen throws focus away.
  ///
  /// Adding the first repository replaces the empty state - a single
  /// [FilledButton], which is what the viewer just pressed and what still
  /// holds focus - with the list of repositories. The button is disposed, and
  /// [FocusManager.primaryFocus] goes quietly to null exactly as it does on a
  /// tab change. Same dead end, one step further along the same journey: the
  /// viewer adds the repository they came for and the screen stops answering
  /// the remote at the moment it starts being useful.
  ///
  /// Unlike the tab case this one can simply ask whether focus was lost,
  /// because by the time this runs the old subtree is gone rather than
  /// lingering for a frame.
  void _restoreBodyFocusIfLost() {
    _afterNextFrame(() {
      if (!mounted) return;
      // A real, still-mounted node has it: nothing to repair.
      final primary = FocusManager.instance.primaryFocus;
      if (primary != null &&
          primary is! FocusScopeNode &&
          primary.context?.mounted == true) {
        return;
      }
      // Not while a dialog is up. Add Repository is a route of its own, and
      // pulling focus down to the page underneath would take the remote out
      // of the field the viewer is typing in.
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;
      _focusFirstInSelectedTab();
    });
  }

  /// Runs [action] once the tree has been rebuilt, and makes sure it runs.
  ///
  /// [SchedulerBinding.addPostFrameCallback] waits for a frame that something
  /// else asks for - it does not ask for one itself. The moment a tab
  /// animation finishes the app is idle and nothing is going to, so the repair
  /// below would sit there unrun until the viewer pressed a key, which is the
  /// one thing they cannot usefully do while focus is lost.
  void _afterNextFrame(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) => action());
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Focuses the first control on the tab that is currently selected.
  void _focusFirstInSelectedTab() {
    if (!mounted) return;
    final page = _tabKeys[_tabController.index].currentContext;
    if (page == null) return;
    for (final node in FocusScope.of(context).traversalDescendants) {
      if (!_isInside(node, page)) continue;
      node.requestFocus();
      return;
    }
  }

  /// Whether [node]'s element sits under [ancestor].
  static bool _isInside(FocusNode node, BuildContext ancestor) {
    final context = node.context;
    if (context == null || !context.mounted) return false;
    var found = false;
    context.visitAncestorElements((element) {
      if (element != ancestor) return true;
      found = true;
      return false;
    });
    return found;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!_didEnsureInit) {
      _didEnsureInit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(extensionsControllerProvider.notifier).ensureInitialized();
      });
    }
    ref.listen(extensionsControllerProvider, (previous, next) {
      // A state change can swap a tab's whole body - an empty state for a
      // list, or back again - and take the focused control with it.
      _restoreBodyFocusIfLost();
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

    final tabBar = TabBar(
      controller: _tabController,
      indicatorSize: TabBarIndicatorSize.label,
      indicatorWeight: 3,
      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 15,
      ),
      labelColor: Theme.of(context).colorScheme.primary,
      unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
      indicatorColor: Theme.of(context).colorScheme.primary,
      dividerColor: Theme.of(context).dividerColor.withValues(alpha: 0.2),
      tabs: [
        Tab(text: l10n.installed),
        Tab(text: l10n.repositories),
      ],
    );

    final tabView = TabBarView(
      controller: _tabController,
      children: [
        FocusTraversalGroup(
          key: _tabKeys[0],
          policy: ReadingOrderTraversalPolicy(),
          child: _buildInstalledTab(context, ref, state),
        ),
        FocusTraversalGroup(
          key: _tabKeys[1],
          policy: ReadingOrderTraversalPolicy(),
          child: _buildRepositoriesTab(context, ref, state),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: LayoutConstants.dashboardContentPadding,
            ),
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: tabBar,
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: tabView,
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              const SettingsRoute().go(context);
            }
          },
        ),
        title: const Text('SkyStream Providers'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: tabBar,
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: tabView,
        ),
      ),
    );
  }

  Widget _buildInstalledTab(
    BuildContext context,
    WidgetRef ref,
    ExtensionsState state,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (state is ExtensionsLoading && state.installedPlugins.isEmpty) {
      return const Center(child: AppLoadingIndicator());
    }

    final debugPlugins = state.installedPlugins
        .where((p) => p.isDebug)
        .toList();
    final hasDebug = debugPlugins.isNotEmpty;

    final allAvailablePackageNames = state.availablePlugins.values
        .expand((list) => list)
        .map((p) => p.packageName)
        .toSet();

    final installedPlugins = state.installedPlugins
        .where(
          (p) =>
              !p.isDebug &&
              (state.availablePlugins.isEmpty ||
                  allAvailablePackageNames.contains(p.packageName)),
        )
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
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: LayoutConstants.spacingSm),
                  Text(
                    l10n.browseRepositoriesToInstall,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: LayoutConstants.spacingLg),
                  FilledButton.icon(
                    icon: const Icon(Icons.explore_outlined),
                    label: Text(l10n.browseRepositories),
                    onPressed: _showRepositoriesTab,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.only(
        bottom: LayoutConstants.shellBottomContentPadding(context),
        top: LayoutConstants.spacingMd,
      ),
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
    if (state is ExtensionsLoading && state.repositories.isEmpty) {
      return const Center(child: AppLoadingIndicator());
    }
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
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: LayoutConstants.spacingSm),
                  Text(
                    l10n.addRepoDescription,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      padding: EdgeInsets.only(
        bottom: LayoutConstants.shellBottomContentPadding(context),
        top: LayoutConstants.spacingMd,
      ),
      addAutomaticKeepAlives: false,
      itemCount: state.repositories.length + 1,
      itemBuilder: (context, index) {
        if (index < state.repositories.length) {
          final repo = state.repositories[index];
          final plugins = state.availablePlugins[repo.url] ?? [];
          return _buildRepositoryCard(context, ref, state, repo, plugins, l10n);
        }

        // The extra item: an add-repository row pinned below the list.
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LayoutConstants.spacingMd,
            vertical: LayoutConstants.spacingSm,
          ),
          child: _FocusableCard(
            margin: EdgeInsets.zero,
            borderColor: Theme.of(context).colorScheme.primary
                .withValues(alpha: 0.3),
            // A card holding one row still hands the focus affordance to the
            // row, so this is marked like every other row in the list.
            child: _FocusableRow(
              child: ListTile(
                focusColor: Theme.of(context).colorScheme.primary
                    .withValues(alpha: 0.15),
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
      borderColor: Theme.of(context).colorScheme.tertiary
          .withValues(alpha: 0.5),
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
        initiallyExpanded: false,
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        tilePadding: const EdgeInsets.symmetric(
          horizontal: LayoutConstants.spacingMd,
          vertical: LayoutConstants.spacingXs,
        ),
        // The description sits in the title rather than in ExpansionTile's
        // subtitle, which adds a gap and shifts the buttons off centre.
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
          // The repository actions live in the children rather than the
          // header, where they would conflict with D-pad focus on the
          // ExpansionTile.
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
                    color: Theme.of(context).dividerColor
                        .withValues(alpha: 0.5),
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
    );
  }

  Future<void> _showAddRepoDialog(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final url = await TextInputDialog.show(
      context,
      title: l10n.addRepository,
      hintText: l10n.repoUrlOrShortcode,
      confirmLabel: l10n.addRepo,
    );
    if (url == null || url.isEmpty || !context.mounted) {
      // Cancelled. The opener may still have been swapped out underneath the
      // dialog, so check anyway - it is a no-op when focus is fine.
      _restoreBodyFocusIfLost();
      return;
    }
    unawaited(
      ref.read(extensionsControllerProvider.notifier).addRepository(url),
    );
    _restoreBodyFocusIfLost();
  }
}

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
      final tile = ListTile(
        leading: Container(
          padding: const EdgeInsets.all(LayoutConstants.spacingXs),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.tertiary
                .withValues(alpha: 0.1),
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
      return _FocusableRow(child: tile);
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

    final tile = ListTile(
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer
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
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w600),
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
                          await PluginSettingsDialog.open(
                            context,
                            installedPlugin,
                          );
                          // Back to the gear it came from, so a remote does
                          // not have to walk the list again.
                          if (context.mounted) {
                            _settingsFocusNode.requestFocus();
                          }
                        },
                      );
                    },
                  ),

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

    return _FocusableRow(child: tile);
  }

  /// Subtitle widget: description · version/authors line · language chips.
  Widget _buildSubtitle(
    BuildContext context,
    bool isInstalled,
    ExtensionPlugin? installedPlugin,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final descStyle = textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final metaStyle = textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    // The installed copy's version if there is one, otherwise the catalog's.
    final version =
        'v${isInstalled ? installedPlugin!.version : widget.plugin.version}';

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

/// Dispatched by a [_FocusableRow] whenever it gains or loses focus.
///
/// The enclosing [_FocusableCard] listens so it can stay unlit while one of
/// its rows is the thing the user is pointed at.
class _RowFocusNotification extends Notification {
  final Object row;
  final bool focused;

  _RowFocusNotification(this.row, this.focused);
}

/// The focus affordance for ONE row of a plugin list.
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
      // Passive observer: the row is not a traversal stop, the buttons inside
      // it are, so hasFocus means one of those controls is focused.
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
  final Color? borderColor;

  const _FocusableCard({required this.child, this.margin, this.borderColor});

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
    // ExpansionTile header. A focused row draws its own affordance instead.
    final highlight = _isFocused && _focusedRow == null;

    return NotificationListener<_RowFocusNotification>(
      onNotification: _onRowFocus,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (focused) => setState(() {
          _isFocused = focused;
          // A focused row can leave the tree (a repository collapses, a plugin
          // is uninstalled) without sending its focus-lost notification, which
          // would otherwise mute this card for good.
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
                  : (widget.borderColor ??
                        theme.dividerColor.withValues(alpha: 0.5)),
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
