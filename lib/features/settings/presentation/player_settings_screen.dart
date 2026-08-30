import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/device_info_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/layout_constants.dart';
import '../../../core/utils/responsive_breakpoints.dart';
import '../../../core/utils/stream_quality_sorter.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';
import 'player_settings_provider.dart';
import 'widgets/settings_dialogs.dart';
import 'widgets/settings_widgets.dart';

/// Sub-screen for configuring all video playback, gestures, display, HDR, and quality preferences.
class PlayerSettingsScreen extends ConsumerWidget {
  final bool isEmbedded;

  const PlayerSettingsScreen({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final profile = ref.watch(deviceProfileProvider).asData?.value;
    final isTv = profile?.isTv == true || context.isTv;

    final playerSettings =
        ref.watch(playerSettingsProvider).asData?.value ??
        const PlayerSettings();

    final platform = Theme.of(context).platform;
    final isDesktopOS =
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
    final isTouchDevice = !isTv && !isDesktopOS;

    final content = Center(
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
              SettingsGroup(
                title: l10n.player,
                children: [
                  SettingsTile(
                    icon: Icons.smart_display_rounded,
                    title: l10n.defaultPlayer,
                    subtitle: getPlayerDisplayName(
                      playerSettings.preferredPlayer,
                      l10n,
                    ),
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
                      subtitle: getGestureLabel(
                        playerSettings.leftGesture,
                        l10n,
                      ),
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
                      subtitle: getGestureLabel(
                        playerSettings.rightGesture,
                        l10n,
                      ),
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
                    subtitle: formatSeekDuration(
                      playerSettings.seekDuration,
                      l10n,
                    ),
                    onTap: () => showDurationDialog(
                      context,
                      ref,
                      playerSettings.seekDuration,
                    ),
                  ),
                  SettingsTile(
                    icon: Icons.timer_outlined,
                    title: l10n.bufferDepth,
                    subtitle: formatReadahead(
                      playerSettings.readaheadSeconds,
                      l10n,
                    ),
                    onTap: () => showReadaheadDialog(
                      context,
                      ref,
                      playerSettings.readaheadSeconds,
                    ),
                  ),
                  SettingsTile(
                    icon: Icons.aspect_ratio_rounded,
                    title: l10n.defaultResizeMode,
                    subtitle: getResizeModeLabel(
                      playerSettings.defaultResizeMode,
                      l10n,
                    ),
                    onTap: () => showResizeDialog(
                      context,
                      ref,
                      playerSettings.defaultResizeMode,
                    ),
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
                      HdrMode.passthrough =>
                        'HDR passthrough — for HDR displays',
                      HdrMode.toneMapSdr =>
                        'Tone-map to SDR — for SDR displays',
                    },
                    onTap: () =>
                        showHdrModeDialog(context, ref, playerSettings),
                  ),
                  if (playerSettings.hdrMode != HdrMode.auto) ...[
                    if (playerSettings.hdrMode == HdrMode.toneMapSdr)
                      SettingsTile(
                        icon: Icons.tonality_rounded,
                        title: 'Tone-mapping curve',
                        subtitle: playerSettings.toneMapCurve.label,
                        onTap: () =>
                            showToneMapDialog(context, ref, playerSettings),
                      ),
                    SettingsTile(
                      icon: Icons.brightness_high_rounded,
                      title: 'Display peak brightness',
                      subtitle: playerSettings.hdrTargetPeak <= 0
                          ? 'Auto-detect'
                          : '${playerSettings.hdrTargetPeak} nits',
                      onTap: () =>
                          showTargetPeakDialog(context, ref, playerSettings),
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
                            .setInverseToneMapping(
                              !playerSettings.inverseToneMapping,
                            ),
                      ),
                  ],
                  SettingsTile(
                    icon: Icons.volume_up_rounded,
                    title: 'Maximum volume',
                    subtitle: playerSettings.maxVolumePercent <= 100
                        ? '100% (no boost)'
                        : '${playerSettings.maxVolumePercent}% — boost enabled',
                    onTap: () =>
                        showMaxVolumeDialog(context, ref, playerSettings),
                  ),
                  SettingsTile(
                    icon: Icons.wifi_rounded,
                    title: l10n.wifiQualityPreference,
                    subtitle: qualityPreferenceLabel(
                      playerSettings.wifiQuality,
                      l10n,
                    ),
                    onTap: () => showQualityDialog(
                      context,
                      ref,
                      title: l10n.wifiQualityPreference,
                      current: playerSettings.wifiQuality,
                      onChanged: ref
                          .read(playerSettingsProvider.notifier)
                          .setWifiQuality,
                    ),
                  ),
                  SettingsTile(
                    icon: Icons.signal_cellular_alt_rounded,
                    title: l10n.mobileQualityPreference,
                    subtitle: qualityPreferenceLabel(
                      playerSettings.mobileQuality,
                      l10n,
                    ),
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
                    subtitle: _qualityFilterModeLabel(
                      playerSettings.qualityFilterMode,
                    ),
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
              ),
            ],
          ),
        ),
      ),
    );

    if (isEmbedded) {
      return content;
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
        title: Text(l10n.player),
      ),
      body: content,
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
