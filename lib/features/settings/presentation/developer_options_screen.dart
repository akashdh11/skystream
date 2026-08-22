import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import 'dart:async';

import '../../../shared/widgets/custom_widgets.dart';
import '../../extensions/providers/extensions_controller.dart';
import '../../../core/storage/settings_repository.dart';
import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/providers/device_info_provider.dart';
import '../../../core/router/app_router.dart';
import 'widgets/settings_widgets.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';
import '../../../core/services/notification_service.dart';

import 'package:flutter/foundation.dart';

class DeveloperOptionsScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;

  const DeveloperOptionsScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<DeveloperOptionsScreen> createState() =>
      _DeveloperOptionsScreenState();
}

class _DeveloperOptionsScreenState
    extends ConsumerState<DeveloperOptionsScreen> {
  bool _devLoadAssets = false;

  @override
  void initState() {
    super.initState();
    _devLoadAssets = ref.read(settingsRepositoryProvider).getDevLoadAssets();
  }

  @override
  Widget build(BuildContext context) {
    final deviceAsync = ref.watch(deviceProfileProvider);

    final l10n = AppLocalizations.of(context)!;
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.all(8),
          children: [
            SettingsGroup(
              title: l10n.debugTools,
              children: [
                SettingsTile(
                  icon: Icons.video_file_rounded,
                  title: l10n.playLocalVideo,
                  subtitle: l10n.playLocalVideoSubtitle,
                  onTap: () => _pickLocalVideo(context),
                ),
                SettingsTile(
                  icon: Icons.link_rounded,
                  title: l10n.streamUrl,
                  subtitle: l10n.streamUrlSubtitle,
                  onTap: () => _showStreamUrlDialog(
                    context,
                    deviceAsync.asData?.value.isTv ?? false,
                  ),
                ),
                SettingsTile(
                  icon: Icons.stream,
                  title: l10n.streamTorrent,
                  subtitle: l10n.streamTorrentSubtitle,
                  onTap: () => _pickTorrentFile(context),
                ),
                if (kDebugMode)
                  SettingsTile(
                    icon: Icons.folder_copy_rounded,
                    title: l10n.loadPluginFromAssets,
                    subtitle: _devLoadAssets ? l10n.enabled : l10n.disabled,
                    isLast: true,
                    trailing: Switch(
                      value: _devLoadAssets,
                      onChanged: (val) => _toggleAssetLoading(context, val),
                    ),
                    onTap: () => _toggleAssetLoading(context, !_devLoadAssets),
                  ),
              ],
            ),
            SettingsGroup(
              title: l10n.diagnostics,
              children: [
                SettingsTile(
                  icon: Icons.bug_report_rounded,
                  title: l10n.viewLogs,
                  subtitle: l10n.viewLogsSubtitle,
                  isLast: true,
                  onTap: () {
                    if (kDebugMode) {
                      unawaited(const AppLogsRoute().push<void>(context));
                    } else {
                      ref
                          .read(notificationServiceProvider)
                          .showInfo(
                            'Log tracking requires a debug build to work',
                            title: 'Developer Options',
                            icon: Icons.developer_mode_rounded,
                          );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.developerOptions)),
      body: content,
    );
  }

  Future<void> _toggleAssetLoading(BuildContext context, bool newValue) async {
    if (!kDebugMode) {
      ref
          .read(notificationServiceProvider)
          .showError(
            AppLocalizations.of(context)!.debugOnlyFeature,
            title: 'Developer Options',
            icon: Icons.developer_mode_rounded,
          );
      return;
    }

    Future<void> handleDevLoadAssetsChanged(bool? newValue) async {
      if (newValue == null) return;
      await ref.read(settingsRepositoryProvider).setDevLoadAssets(newValue);
      if (context.mounted) {
        setState(() {
          _devLoadAssets = newValue;
        });
      }
    }

    await handleDevLoadAssetsChanged(newValue);

    await ref
        .read(extensionsControllerProvider.notifier)
        .loadInstalledPlugins();
  }

  Future<void> _pickLocalVideo(BuildContext context) async {
    final result = await FilePicker.pickFiles(type: FileType.video);

    if (result != null && result.files.single.path != null && context.mounted) {
      final path = result.files.single.path!;
      final name = result.files.single.name;

      unawaited(
        PlayerRoute(
          $extra: PlayerRouteExtra(
            item: MultimediaItem(
              title: name,
              url: path,
              posterUrl: '',
              provider: AppLocalizations.of(context)!.local,
              episodes: [Episode(name: name, url: path, posterUrl: '')],
            ),
            videoUrl: path,
          ),
        ).push<void>(context),
      );
    }
  }

  void _showStreamUrlDialog(BuildContext context, bool isTv) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        surfaceTintColor: Colors.transparent,
        title: Text(l10n.streamUrl),
        content: CustomTextField(
          controller: controller,
          hintText: l10n.enterVideoUrlHint,
          autofocus: false, // Start focus on Play button
          textInputAction: TextInputAction.done,
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
          const SizedBox(width: 8),
          CustomButton(
            autofocus: true,
            isPrimary: true,

            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                String title = l10n.networkStream;
                try {
                  final uri = Uri.parse(url);
                  if (uri.pathSegments.isNotEmpty) {
                    title = uri.pathSegments.last;
                  }
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('DeveloperOptionsScreen: URI parse error: $e');
                  }
                }

                Navigator.pop(context);
                PlayerRoute(
                  $extra: PlayerRouteExtra(
                    item: MultimediaItem(
                      title: title,
                      url: url, // Unique URL for history
                      posterUrl: '',
                      provider: l10n.remote,
                      episodes: [Episode(name: title, url: url, posterUrl: '')],
                    ),
                    videoUrl: url,
                  ),
                ).push<void>(context);
              }
            },
            child: Text(l10n.play),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTorrentFile(BuildContext context) async {
    final result = await FilePicker.pickFiles(type: FileType.any);

    if (result != null && result.files.single.path != null && context.mounted) {
      final path = result.files.single.path!;
      final name = result.files.single.name;

      unawaited(
        PlayerRoute(
          $extra: PlayerRouteExtra(
            item: MultimediaItem(
              title: name,
              url: path,
              posterUrl: '',
              provider: AppLocalizations.of(context)!.torrent,
              episodes: [Episode(name: name, url: path, posterUrl: '')],
            ),
            videoUrl: path,
          ),
        ).push<void>(context),
      );
    }
  }
}
