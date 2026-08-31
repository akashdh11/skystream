import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/layout_constants.dart';
import '../../../core/theme/theme_provider.dart';

import 'widgets/settings_widgets.dart';
import 'widgets/settings_dialogs.dart';
import 'general_settings_provider.dart';
import 'app_version_provider.dart';

import 'package:skystream/l10n/generated/app_localizations.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/router/app_router.dart';
import 'cache_provider.dart';

class SettingsScreen extends ConsumerWidget {
  final String? initialCategory;
  const SettingsScreen({super.key, this.initialCategory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    final versionAsync = ref.watch(appVersionProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final generalSettings = ref.watch(generalSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: LayoutConstants.spacingMd,
                vertical: LayoutConstants.spacingSm,
              ).copyWith(bottom: 100),
              children: [
              _buildGeneralSettingsGroup(
                context,
                ref,
                l10n,
                themeMode,
                generalSettings,
              ),
              const SizedBox(height: LayoutConstants.spacingLg),
              SettingsGroup(
                title: l10n.extensions,
                children: [
                  SettingsTile(
                    icon: Icons.extension_rounded,
                    title: 'SkyStream Providers',
                    subtitle: l10n.installRemoveProviders,
                    onTap: () => const ExtensionsRoute().go(context),
                  ),
                  SettingsTile(
                    icon: Icons.hub_rounded,
                    title: 'Nuvio Plugins',
                    subtitle: 'Manage and configure Nuvio scrapers',
                    onTap: () => const NuvioPluginsRoute().go(context),
                  ),
                  SettingsTile(
                    icon: Icons.dashboard_customize_rounded,
                    title: 'Stremio Add-ons',
                    subtitle: 'Manage and discover installed add-ons',
                    isLast: true,
                    onTap: () => const AddonsRoute().go(context),
                  ),
                ],
              ),
              const SizedBox(height: LayoutConstants.spacingLg),
              _buildAppDataSettingsGroup(context, ref, l10n),
              const SizedBox(height: LayoutConstants.spacingLg),
              _buildAboutSettingsGroup(context, l10n, versionAsync),
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildGeneralSettingsGroup(
    BuildContext context,
    WidgetRef ref,
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
          icon: Icons.translate_rounded,
          title: l10n.language,
          subtitle: l10n.languageName,
          onTap: () =>
              showLanguageDialog(context, ref, ref.read(localeProvider)),
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
          icon: Icons.play_circle_outline_rounded,
          title: l10n.player,
          subtitle: 'Default player, gestures, decoding & quality',
          onTap: () => const PlayerSettingsRoute().go(context),
        ),
        SettingsTile(
          icon: Icons.manage_accounts_rounded,
          title: '${l10n.accounts}, ${l10n.network} & ${l10n.downloads}',
          subtitle: 'Subtitles, tracking, network, DNS & downloads',
          isLast: true,
          onTap: () => const AccountSettingsRoute().go(context),
        ),
      ],
    );
  }

  Widget _buildAppDataSettingsGroup(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    return SettingsGroup(
      title: '${l10n.appData} & ${l10n.developer}',
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
          onTap: () => showFactoryResetDialog(context, ref),
        ),
        SettingsTile(
          icon: Icons.developer_mode_rounded,
          title: l10n.developerOptions,
          subtitle: l10n.developerOptionsSubtitle,
          isLast: true,
          onTap: () => const DeveloperOptionsRoute().go(context),
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
