import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/tmdb_config.dart';
import '../../../core/utils/layout_constants.dart';
import '../../../core/utils/responsive_breakpoints.dart';
import '../../../core/providers/device_info_provider.dart';
import '../../../core/theme/theme_provider.dart';

import '../../../core/utils/stream_quality_sorter.dart';
import 'widgets/settings_widgets.dart';
import 'widgets/settings_dialogs.dart';
import 'player_settings_provider.dart';
import 'general_settings_provider.dart';
import 'app_version_provider.dart';
import 'account_settings_screen.dart';
import 'developer_options_screen.dart';
import '../../extensions/screens/extensions_screen.dart';

import 'package:skystream/l10n/generated/app_localizations.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/network/doh_service.dart';
import '../../../core/router/app_router.dart';
import 'cache_provider.dart';

enum SettingsCategory {
  general,
  player,
  accounts,
  extensions,
  developer,
  about,
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  SettingsCategory _selectedCategory = SettingsCategory.general;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(deviceProfileProvider).asData?.value;
    final isTv = profile?.isTv == true || context.isTv;
    final isWidescreen = isTv || context.isTabletOrLarger;

    if (isWidescreen) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            // Inline header matching other widescreen screens
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                height: LayoutConstants.dashboardHeaderHeight,
                padding: const EdgeInsets.symmetric(
                  horizontal: LayoutConstants.dashboardContentPadding,
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  AppLocalizations.of(context)!.settings,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(child: _buildDualPanelLayout(context, isTv)),
          ],
        ),
      );
    }

    // Mobile layout
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: _buildMobileSettingsList(context, isTv),
    );
  }

  Widget _buildDualPanelLayout(BuildContext context, bool isTv) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final categories = [
      (SettingsCategory.general, l10n.general, Icons.tune_rounded),
      (SettingsCategory.player, l10n.player, Icons.smart_display_rounded),
      (SettingsCategory.accounts, l10n.accounts, Icons.account_circle_rounded),
      (SettingsCategory.extensions, l10n.extensions, Icons.extension_rounded),
      (
        SettingsCategory.developer,
        l10n.developerOptions,
        Icons.developer_mode_rounded,
      ),
      (SettingsCategory.about, l10n.about, Icons.info_outline_rounded),
    ];

    final platform = theme.platform;
    final isDesktopOS =
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
    final isTouchDevice = !isTv && !isDesktopOS;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Side Navigation Rail / Sidebar
        SizedBox(
          width: 250,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: categories.map((cat) {
              final isSelected = _selectedCategory == cat.$1;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Material(
                  color: isSelected
                      ? theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.35,
                        )
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCategory = cat.$1;
                      });
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            cat.$3,
                            size: 22,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              cat.$2,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // Subtle vertical divider
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: theme.dividerColor.withValues(alpha: 0.15),
        ),
        // Right Detail Panel
        Expanded(
          child: FocusTraversalGroup(
            child: _buildCategoryContent(
              context,
              isTv,
              isTouchDevice,
              _selectedCategory,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryContent(
    BuildContext context,
    bool isTv,
    bool isTouchDevice,
    SettingsCategory category,
  ) {
    final versionAsync = ref.watch(appVersionProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final generalSettings = ref.watch(generalSettingsProvider);
    final playerSettings =
        ref.watch(playerSettingsProvider).asData?.value ??
        const PlayerSettings();
    final l10n = AppLocalizations.of(context)!;

    switch (category) {
      case SettingsCategory.general:
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                const SizedBox(height: LayoutConstants.spacingXs),
                _buildGeneralSettingsGroup(
                  context,
                  l10n,
                  themeMode,
                  generalSettings,
                ),
                const SizedBox(height: LayoutConstants.spacingLg),
                _buildLibrarySettingsGroup(context, l10n),
                const SizedBox(height: LayoutConstants.spacingLg),
                _buildDownloadsSettingsGroup(context, l10n, generalSettings),
                const SizedBox(height: LayoutConstants.spacingLg),
                _buildNetworkSettingsGroup(context, l10n, generalSettings),
                const SizedBox(height: LayoutConstants.spacingLg),
                _buildAppDataSettingsGroup(context, l10n),
              ],
            ),
          ),
        );

      case SettingsCategory.player:
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                const SizedBox(height: LayoutConstants.spacingXs),
                _buildPlayerSettingsGroup(
                  context,
                  l10n,
                  playerSettings,
                  isTouchDevice,
                ),
              ],
            ),
          ),
        );

      case SettingsCategory.accounts:
        return const AccountSettingsScreen(isEmbedded: true);

      case SettingsCategory.extensions:
        return const ExtensionsScreen(isEmbedded: true);

      case SettingsCategory.developer:
        return const DeveloperOptionsScreen(isEmbedded: true);

      case SettingsCategory.about:
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                const SizedBox(height: LayoutConstants.spacingXs),
                _buildAboutSettingsGroup(context, l10n, versionAsync),
              ],
            ),
          ),
        );
    }
  }

  Widget _buildMobileSettingsList(BuildContext context, bool isTv) {
    final versionAsync = ref.watch(appVersionProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final generalSettings = ref.watch(generalSettingsProvider);
    final playerSettings =
        ref.watch(playerSettingsProvider).asData?.value ??
        const PlayerSettings();
    final l10n = AppLocalizations.of(context)!;

    final platform = Theme.of(context).platform;
    final isDesktopOS =
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
    final isTouchDevice = !isTv && !isDesktopOS;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            const SizedBox(height: LayoutConstants.spacingXs),
            _buildGeneralSettingsGroup(
              context,
              l10n,
              themeMode,
              generalSettings,
            ),
            const SizedBox(height: LayoutConstants.spacingLg),
            _buildLibrarySettingsGroup(context, l10n),
            const SizedBox(height: LayoutConstants.spacingLg),
            _buildDownloadsSettingsGroup(context, l10n, generalSettings),
            const SizedBox(height: LayoutConstants.spacingLg),
            _buildPlayerSettingsGroup(
              context,
              l10n,
              playerSettings,
              isTouchDevice,
            ),
            const SizedBox(height: LayoutConstants.spacingLg),
            SettingsGroup(
              title: l10n.accounts,
              children: [
                SettingsTile(
                  icon: Icons.account_circle_rounded,
                  title: 'Manage Accounts',
                  subtitle: 'Configure Subtitles and Tracking Services',
                  isLast: true,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AccountSettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: LayoutConstants.spacingLg),
            _buildNetworkSettingsGroup(context, l10n, generalSettings),
            const SizedBox(height: LayoutConstants.spacingLg),
            SettingsGroup(
              title: l10n.extensions,
              children: [
                SettingsTile(
                  icon: Icons.extension_rounded,
                  title: l10n.manageExtensions,
                  subtitle: l10n.installRemoveProviders,
                  isLast: true,
                  onTap: () => const ExtensionsRoute().go(context),
                ),
              ],
            ),
            const SizedBox(height: LayoutConstants.spacingLg),
            _buildAppDataSettingsGroup(context, l10n),
            const SizedBox(height: LayoutConstants.spacingLg),
            SettingsGroup(
              title: l10n.developer,
              children: [
                SettingsTile(
                  icon: Icons.developer_mode_rounded,
                  title: l10n.developerOptions,
                  subtitle: l10n.developerOptionsSubtitle,
                  isLast: true,
                  onTap: () => const DeveloperOptionsRoute().go(context),
                ),
              ],
            ),
            const SizedBox(height: LayoutConstants.spacingLg),
            _buildAboutSettingsGroup(context, l10n, versionAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralSettingsGroup(
    BuildContext context,
    AppLocalizations l10n,
    ThemeMode themeMode,
    GeneralSettings generalSettings,
  ) {
    return SettingsGroup(
      title: l10n.general,
      children: [
        SettingsTile(
          icon: Icons.dark_mode_rounded,
          title: l10n.appTheme,
          subtitle: themeMode == ThemeMode.system
              ? l10n.system
              : (themeMode == ThemeMode.dark ? l10n.dark : l10n.light),
          onTap: () => showThemeDialog(context, ref, themeMode),
        ),
        SettingsTile(
          icon: Icons.history_rounded,
          title: l10n.recordWatchHistory,
          subtitle: generalSettings.watchHistoryEnabled
              ? l10n.enabled
              : l10n.disabled,
          trailing: Switch(
            value: generalSettings.watchHistoryEnabled,
            onChanged: (val) => ref
                .read(generalSettingsProvider.notifier)
                .setWatchHistoryEnabled(val),
          ),
          onTap: () => ref
              .read(generalSettingsProvider.notifier)
              .setWatchHistoryEnabled(!generalSettings.watchHistoryEnabled),
        ),
        SettingsTile(
          icon: Icons.vpn_key_rounded,
          title: 'TMDB API key',
          subtitle: generalSettings.tmdbApiKey.isNotEmpty
              ? 'Custom key saved'
              : (TmdbConfig.buildTimeApiKey.isNotEmpty
                    ? 'Using built-in key'
                    : 'Not set — Stream and Explore need this'),
          onTap: () => showTmdbApiKeyDialog(context, ref),
        ),
        SettingsTile(
          icon: Icons.home_rounded,
          title: l10n.defaultHomeScreen,
          subtitle: getHomeScreenLabel(generalSettings.defaultHomeScreen, l10n),
          onTap: () => showDefaultHomeScreenDialog(
            context,
            ref,
            generalSettings.defaultHomeScreen,
          ),
        ),
        SettingsTile(
          icon: Icons.title_rounded,
          title: l10n.titlePosition,
          subtitle: getTitlePositionLabel(generalSettings.titlePosition, l10n),
          onTap: () => showTitlePositionDialog(
            context,
            ref,
            generalSettings.titlePosition,
          ),
        ),
        SettingsTile(
          icon: Icons.translate_rounded,
          title: l10n.language,
          subtitle: l10n.languageName,
          isLast: true,
          onTap: () =>
              showLanguageDialog(context, ref, ref.read(localeProvider)),
        ),
      ],
    );
  }

  /// Library is no longer a navigation destination — its two screens live here.
  Widget _buildLibrarySettingsGroup(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return SettingsGroup(
      title: l10n.library,
      children: [
        SettingsTile(
          icon: Icons.download_rounded,
          title: l10n.downloads,
          subtitle: 'Manage and open your downloads',
          onTap: () => const LibraryRoute().push<void>(context),
        ),
        SettingsTile(
          icon: Icons.bookmark_rounded,
          title: 'Bookmarks',
          subtitle: 'Everything you saved to watch later',
          onTap: () => const LibraryRoute(tab: 1).push<void>(context),
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildDownloadsSettingsGroup(
    BuildContext context,
    AppLocalizations l10n,
    GeneralSettings generalSettings,
  ) {
    return SettingsGroup(
      title: l10n.downloads,
      children: [
        SettingsTile(
          icon: Icons.folder_copy_rounded,
          title: 'Download location',
          subtitle:
              generalSettings.downloadDirectory ?? 'System Downloads/Skystream',
          onTap: () =>
              showDownloadSettingsDialog(context, ref, generalSettings),
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildPlayerSettingsGroup(
    BuildContext context,
    AppLocalizations l10n,
    PlayerSettings playerSettings,
    bool isTouchDevice,
  ) {
    return SettingsGroup(
      title: l10n.player,
      children: [
        SettingsTile(
          icon: Icons.smart_display_rounded,
          title: l10n.defaultPlayer,
          subtitle: getPlayerDisplayName(playerSettings.preferredPlayer, l10n),
          onTap: () => showDefaultPlayerDialog(
            context,
            ref,
            playerSettings.preferredPlayer,
          ),
        ),
        if (isTouchDevice) ...[
          SettingsTile(
            icon: Icons.swipe_vertical_rounded,
            title: l10n.leftGesture,
            subtitle: getGestureLabel(playerSettings.leftGesture, l10n),
            onTap: () => showGestureDialog(
              context,
              ref,
              true,
              playerSettings.leftGesture,
            ),
          ),
          SettingsTile(
            icon: Icons.swipe_vertical_rounded,
            title: l10n.rightGesture,
            subtitle: getGestureLabel(playerSettings.rightGesture, l10n),
            onTap: () => showGestureDialog(
              context,
              ref,
              false,
              playerSettings.rightGesture,
            ),
          ),
          SettingsTile(
            icon: Icons.touch_app_rounded,
            title: l10n.doubleTapToSeek,
            subtitle: playerSettings.doubleTapEnabled
                ? l10n.enabled
                : l10n.disabled,
            trailing: Switch(
              value: playerSettings.doubleTapEnabled,
              onChanged: (val) => ref
                  .read(playerSettingsProvider.notifier)
                  .setDoubleTapEnabled(val),
            ),
            onTap: () => ref
                .read(playerSettingsProvider.notifier)
                .setDoubleTapEnabled(!playerSettings.doubleTapEnabled),
          ),
          SettingsTile(
            icon: Icons.swipe_rounded,
            title: l10n.swipeToSeek,
            subtitle: playerSettings.swipeSeekEnabled
                ? l10n.enabled
                : l10n.disabled,
            trailing: Switch(
              value: playerSettings.swipeSeekEnabled,
              onChanged: (val) => ref
                  .read(playerSettingsProvider.notifier)
                  .setSwipeSeekEnabled(val),
            ),
            onTap: () => ref
                .read(playerSettingsProvider.notifier)
                .setSwipeSeekEnabled(!playerSettings.swipeSeekEnabled),
          ),
        ],
        SettingsTile(
          icon: Icons.av_timer_rounded,
          title: l10n.seekDuration,
          subtitle: formatSeekDuration(playerSettings.seekDuration, l10n),
          onTap: () =>
              showDurationDialog(context, ref, playerSettings.seekDuration),
        ),
        SettingsTile(
          icon: Icons.timer_outlined,
          title: l10n.bufferDepth,
          subtitle: formatReadahead(playerSettings.readaheadSeconds, l10n),
          onTap: () => showReadaheadDialog(
            context,
            ref,
            playerSettings.readaheadSeconds,
          ),
        ),
        SettingsTile(
          icon: Icons.aspect_ratio_rounded,
          title: l10n.defaultResizeMode,
          subtitle: getResizeModeLabel(playerSettings.defaultResizeMode, l10n),
          onTap: () =>
              showResizeDialog(context, ref, playerSettings.defaultResizeMode),
        ),
        SettingsTile(
          icon: Icons.high_quality_rounded,
          title: l10n.hardwareDecoding,
          subtitle: playerSettings.hardwareDecoding
              ? '${l10n.enabled} (${l10n.recommended})'
              : l10n.disabled,
          trailing: Switch(
            value: playerSettings.hardwareDecoding,
            onChanged: (val) => ref
                .read(playerSettingsProvider.notifier)
                .setHardwareDecoding(val),
          ),
          onTap: () => ref
              .read(playerSettingsProvider.notifier)
              .setHardwareDecoding(!playerSettings.hardwareDecoding),
        ),
        SettingsTile(
          icon: Icons.hdr_on_rounded,
          title: 'HDR mode',
          subtitle: switch (playerSettings.hdrMode) {
            HdrMode.auto => 'Auto (let the player decide)',
            HdrMode.passthrough => 'HDR passthrough — for HDR displays',
            HdrMode.toneMapSdr => 'Tone-map to SDR — for SDR displays',
          },
          onTap: () => showHdrModeDialog(context, ref, playerSettings),
        ),
        if (playerSettings.hdrMode != HdrMode.auto) ...[
          if (playerSettings.hdrMode == HdrMode.toneMapSdr)
            SettingsTile(
              icon: Icons.tonality_rounded,
              title: 'Tone-mapping curve',
              subtitle: playerSettings.toneMapCurve.label,
              onTap: () => showToneMapDialog(context, ref, playerSettings),
            ),
          SettingsTile(
            icon: Icons.brightness_high_rounded,
            title: 'Display peak brightness',
            subtitle: playerSettings.hdrTargetPeak <= 0
                ? 'Auto-detect'
                : '${playerSettings.hdrTargetPeak} nits',
            onTap: () => showTargetPeakDialog(context, ref, playerSettings),
          ),
          SettingsTile(
            icon: Icons.auto_graph_rounded,
            title: 'Dynamic peak detection',
            subtitle: playerSettings.hdrComputePeak
                ? 'On — better highlights, more GPU'
                : 'Off — lighter on the GPU',
            trailing: Switch(
              value: playerSettings.hdrComputePeak,
              onChanged: (val) => ref
                  .read(playerSettingsProvider.notifier)
                  .setHdrComputePeak(val),
            ),
            onTap: () => ref
                .read(playerSettingsProvider.notifier)
                .setHdrComputePeak(!playerSettings.hdrComputePeak),
          ),
          if (playerSettings.hdrMode == HdrMode.toneMapSdr)
            SettingsTile(
              icon: Icons.wb_sunny_rounded,
              title: 'Boost SDR to HDR',
              subtitle: playerSettings.inverseToneMapping
                  ? 'On — expands SDR into HDR range'
                  : 'Off (recommended)',
              trailing: Switch(
                value: playerSettings.inverseToneMapping,
                onChanged: (val) => ref
                    .read(playerSettingsProvider.notifier)
                    .setInverseToneMapping(val),
              ),
              onTap: () => ref
                  .read(playerSettingsProvider.notifier)
                  .setInverseToneMapping(!playerSettings.inverseToneMapping),
            ),
        ],
        SettingsTile(
          icon: Icons.volume_up_rounded,
          title: 'Maximum volume',
          subtitle: playerSettings.maxVolumePercent <= 100
              ? '100% (no boost)'
              : '${playerSettings.maxVolumePercent}% — boost enabled',
          onTap: () => showMaxVolumeDialog(context, ref, playerSettings),
        ),
        SettingsTile(
          icon: Icons.wifi_rounded,
          title: l10n.wifiQualityPreference,
          subtitle: qualityPreferenceLabel(playerSettings.wifiQuality, l10n),
          onTap: () => showQualityDialog(
            context,
            ref,
            title: l10n.wifiQualityPreference,
            current: playerSettings.wifiQuality,
            onChanged: ref.read(playerSettingsProvider.notifier).setWifiQuality,
          ),
        ),
        SettingsTile(
          icon: Icons.signal_cellular_alt_rounded,
          title: l10n.mobileQualityPreference,
          subtitle: qualityPreferenceLabel(playerSettings.mobileQuality, l10n),
          onTap: () => showQualityDialog(
            context,
            ref,
            title: l10n.mobileQualityPreference,
            current: playerSettings.mobileQuality,
            onChanged: ref
                .read(playerSettingsProvider.notifier)
                .setMobileQuality,
          ),
        ),
        SettingsTile(
          icon: Icons.filter_list_rounded,
          title: 'Quality Filter Mode',
          subtitle: _qualityFilterModeLabel(playerSettings.qualityFilterMode),
          onTap: () => showQualityFilterModeDialog(
            context,
            ref,
            current: playerSettings.qualityFilterMode,
            onChanged: ref
                .read(playerSettingsProvider.notifier)
                .setQualityFilterMode,
          ),
        ),
        SettingsTile(
          icon: Icons.tune_rounded,
          title: l10n.playerControls,
          subtitle: l10n.playerControlsSubtitle,
          isLast: true,
          onTap: () => showPlayerControlsDialog(context, ref),
        ),
      ],
    );
  }

  Widget _buildNetworkSettingsGroup(
    BuildContext context,
    AppLocalizations l10n,
    GeneralSettings generalSettings,
  ) {
    return Builder(
      builder: (context) {
        final dohState =
            ref.watch(dohSettingsProvider).asData?.value ?? const DohSettings();
        return SettingsGroup(
          title: l10n.network,
          children: [
            SettingsTile(
              icon: Icons.dns_rounded,
              title: l10n.dnsOverHttps,
              subtitle: dohState.enabled
                  ? '${l10n.on} (${getDohProviderLabel(dohState.provider, dohState.customUrl, l10n)})'
                  : l10n.off,
              trailing: Switch(
                value: dohState.enabled,
                onChanged: (val) {
                  ref.read(dohSettingsProvider.notifier).setEnabled(val);
                },
              ),
              onTap: () {
                ref
                    .read(dohSettingsProvider.notifier)
                    .setEnabled(!dohState.enabled);
              },
            ),
            if (dohState.enabled)
              SettingsTile(
                icon: Icons.cloud_rounded,
                title: l10n.dohProvider,
                subtitle: getDohProviderLabel(
                  dohState.provider,
                  dohState.customUrl,
                  l10n,
                ),
                onTap: () => showDohProviderDialog(context, ref),
              ),
            SettingsTile(
              icon: Icons.alt_route_rounded,
              title: l10n.githubProxy,
              subtitle: l10n.githubProxySubtitle,
              trailing: Switch(
                value: generalSettings.githubProxyEnabled,
                onChanged: (val) {
                  ref
                      .read(generalSettingsProvider.notifier)
                      .setGithubProxyEnabled(val);
                },
              ),
              onTap: () {
                ref
                    .read(generalSettingsProvider.notifier)
                    .setGithubProxyEnabled(!generalSettings.githubProxyEnabled);
              },
              isLast: true,
            ),
          ],
        );
      },
    );
  }

  Widget _buildAppDataSettingsGroup(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return SettingsGroup(
      title: l10n.appData,
      children: [
        if (!kIsWeb)
          SettingsTile(
            icon: Icons.cleaning_services_rounded,
            title: l10n.clearCache,
            subtitle: ref
                .watch(cacheSizeProvider)
                .when(
                  data: (bytes) =>
                      '${l10n.clearCacheSubtitle} • ${_formatBytes(bytes)}',
                  loading: () => l10n.calculating,
                  error: (_, _) => l10n.clearCacheSubtitle,
                ),
            onTap: () => showClearCacheDialog(context, ref),
          ),
        SettingsTile(
          icon: Icons.restore_rounded,
          title: l10n.resetDataKeepExtensions,
          subtitle: l10n.resetDataSubtitle,
          onTap: () => showResetDataDialog(context, ref),
        ),
        SettingsTile(
          icon: Icons.delete_forever_rounded,
          title: l10n.factoryReset,
          subtitle: l10n.factoryResetSubtitle,
          isLast: true,
          onTap: () => showFactoryResetDialog(context, ref),
        ),
      ],
    );
  }

  Widget _buildAboutSettingsGroup(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<String> versionAsync,
  ) {
    return SettingsGroup(
      title: l10n.about,
      children: [
        SettingsTile(
          icon: Icons.person_outline_rounded,
          title: l10n.developer,
          subtitle: l10n.developedBy('Akash'),
          onTap: () => showDeveloperDialog(context),
        ),
        SettingsTile(
          icon: Icons.forum_outlined,
          title: l10n.discord,
          subtitle: l10n.discordSubtitle,
          onTap: () => launchUrl(
            Uri.parse('https://discord.gg/73XGA8Mxn9'),
            mode: LaunchMode.externalApplication,
          ),
        ),
        SettingsTile(
          icon: Icons.send_rounded,
          title: l10n.telegram,
          subtitle: l10n.telegramSubtitle,
          onTap: () => launchUrl(
            Uri.parse('https://t.me/+Ez5Vsv2pUUFjZmNl'),
            mode: LaunchMode.externalApplication,
          ),
        ),
        SettingsTile(
          icon: Icons.info_outline_rounded,
          title: l10n.version,
          subtitle: versionAsync.when(
            data: (v) => v,
            loading: () => l10n.loading,
            error: (err, stack) => l10n.unknown,
          ),
          trailing: const SizedBox.shrink(),
          isLast: true,
        ),
      ],
    );
  }
}

String _qualityFilterModeLabel(QualityFilterMode mode) {
  switch (mode) {
    case QualityFilterMode.any:
      return 'Show all (sort only)';
    case QualityFilterMode.atOrAbove:
      return 'Hide sources below preference';
    case QualityFilterMode.atOrBelow:
      return 'Hide sources above preference';
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }
  final value = unitIndex == 0
      ? size.toStringAsFixed(0)
      : size.toStringAsFixed(1);
  return '$value ${units[unitIndex]}';
}
