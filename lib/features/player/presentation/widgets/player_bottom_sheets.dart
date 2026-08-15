import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/services/notification_service.dart';
import '../../../settings/presentation/player_settings_provider.dart';
import '../player_controller.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../shared/widgets/custom_widgets.dart';
import '../../../../shared/widgets/desktop_scroll_wrapper.dart';
import '../subtitle_search_provider.dart';
import '../../domain/entity/subtitle_model.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';
import 'hotstar_player_style.dart';
import '../../../../core/utils/stream_quality_sorter.dart';
import 'subtitle_sync_dialog.dart';
import 'subtitle_appearance_dialog.dart';

class _TrackDialogResult {
  final String? audioId;
  final String? subtitleId;
  final bool subtitleOff;
  final bool openSubtitleOptions;

  const _TrackDialogResult({
    this.audioId,
    this.subtitleId,
    this.subtitleOff = false,
  }) : openSubtitleOptions = false;
}

class _PlayerOptionsResult {
  final StreamResult? stream;
  final _TrackDialogResult? tracks;
  final bool openSubtitleOptions;

  const _PlayerOptionsResult({
    this.stream,
    this.tracks,
    this.openSubtitleOptions = false,
  });
}

class PlayerBottomSheets {
  static Future<void> showSourceSelection({
    required BuildContext context,
    required WidgetRef ref,
    required List<StreamResult>? streams,
    required StreamResult? currentStream,
    required Future<void> Function(StreamResult) onStreamSelected,
  }) async {
    final controller = ref.read(playerControllerProvider.notifier);
    final wasPlaying = controller.isPlaying;

    if (wasPlaying) await controller.pause();
    if (!context.mounted) return;
    final result = await _showPlayerOptionsDialog(
      context: context,
      ref: ref,
      streams: streams,
      currentStream: currentStream,
      initialTab: 0,
    );

    if (result?.openSubtitleOptions == true) {
      await _resumeIfNeeded(controller, wasPlaying);
      if (context.mounted) _showSubtitleOptions(context);
      return;
    }
    final selectedStream = result?.stream;
    if (selectedStream != null &&
        !_isSameStream(selectedStream, currentStream)) {
      await onStreamSelected(selectedStream);
      await _resumeIfNeeded(controller, wasPlaying);
      return;
    }

    if (result?.tracks != null) {
      await _applyTrackResult(controller, result!.tracks!);
    }
    await _resumeIfNeeded(controller, wasPlaying);
  }

  static bool _isSameStream(StreamResult? a, StreamResult? b) {
    return a != null && b != null && a.url == b.url && a.source == b.source;
  }

  static Future<void> _resumeIfNeeded(
    PlayerController controller,
    bool wasPlaying,
  ) async {
    if (wasPlaying) await controller.play();
  }

  static Future<void> _applyTrackResult(
    PlayerController controller,
    _TrackDialogResult result,
  ) async {
    final snapshot = controller.getTrackSelectionSnapshot();
    final originalAudioId = snapshot.audioTracks
        .firstWhereOrNull((track) => track.selected)
        ?.id;
    final originalSubtitleId = snapshot.subtitlesOffSelected
        ? null
        : snapshot.subtitleTracks
              .firstWhereOrNull((track) => track.selected)
              ?.id;

    if (result.audioId != null && result.audioId != originalAudioId) {
      await controller.selectAudioTrack(result.audioId!);
    }
    final nextSubtitleId = result.subtitleOff ? null : result.subtitleId;
    if (nextSubtitleId != originalSubtitleId ||
        result.subtitleOff != snapshot.subtitlesOffSelected) {
      await controller.selectSubtitleTrack(nextSubtitleId);
    }
  }

  static Future<_PlayerOptionsResult?> _showPlayerOptionsDialog({
    required BuildContext context,
    required WidgetRef ref,
    List<StreamResult>? streams,
    StreamResult? currentStream,
    int initialTab = 0,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(playerControllerProvider.notifier);
    final snapshot = controller.getTrackSelectionSnapshot();
    final sourceOptions = streams ?? const <StreamResult>[];
    StreamResult? selectedStream = currentStream ?? sourceOptions.firstOrNull;
    final originalAudioId = snapshot.audioTracks
        .firstWhereOrNull((track) => track.selected)
        ?.id;
    final originalSubtitleId = snapshot.subtitlesOffSelected
        ? null
        : snapshot.subtitleTracks
              .firstWhereOrNull((track) => track.selected)
              ?.id;
    String? selectedAudioId = originalAudioId;
    String? selectedSubtitleId = originalSubtitleId;
    bool subtitlesOff = snapshot.subtitlesOffSelected;

    return showDialog<_PlayerOptionsResult>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final dialogSize = MediaQuery.sizeOf(context);
            final isCompact = dialogSize.shortestSide < 600;
            final dialogPadding = EdgeInsets.fromLTRB(
              isCompact ? 20 : 48,
              isCompact ? 12 : 18,
              isCompact ? 20 : 48,
              isCompact ? 14 : 22,
            );
            final tabTextStyle = TextStyle(
              fontSize: isCompact ? 15 : 18,
              fontWeight: FontWeight.w800,
            );
            final unselectedTabTextStyle = TextStyle(
              fontSize: isCompact ? 15 : 18,
              fontWeight: FontWeight.w700,
            );
            final sourceChanges =
                selectedStream != null &&
                !_isSameStream(selectedStream, currentStream);
            final trackChanges =
                !sourceChanges &&
                (selectedAudioId != originalAudioId ||
                    selectedSubtitleId != originalSubtitleId ||
                    subtitlesOff != snapshot.subtitlesOffSelected);
            final canApply = trackChanges || sourceChanges;

            return DefaultTabController(
              length: 2,
              initialIndex: initialTab.clamp(0, 1),
              child: Dialog.fullscreen(
                backgroundColor: HotstarPlayerStyle.background,
                child: SafeArea(
                  child: Padding(
                    padding: dialogPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TabBar(
                                isScrollable: true,
                                tabAlignment: TabAlignment.start,
                                indicatorColor: Colors.white,
                                indicatorWeight: 2,
                                dividerColor: HotstarPlayerStyle.divider,
                                labelColor: HotstarPlayerStyle.primaryText,
                                unselectedLabelColor:
                                    HotstarPlayerStyle.mutedText,
                                labelStyle: tabTextStyle,
                                unselectedLabelStyle: unselectedTabTextStyle,
                                tabs: [
                                  Tab(text: l10n.sources),
                                  const Tab(text: 'Audio & Subtitles'),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              color: Colors.white,
                              iconSize: 36,
                              icon: const Icon(Icons.close),
                              tooltip: l10n.cancel,
                              autofocus: true,
                            ),
                          ],
                        ),
                        SizedBox(height: isCompact ? 14 : 30),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _HotstarSourcesTab(
                                streams: sourceOptions,
                                selectedStream: selectedStream,
                                emptyText: l10n.noResultsFound,
                                qualityFilteredFallback: ref
                                    .read(playerControllerProvider)
                                    .qualityFilteredFallback,
                                onSelected: (stream) => setState(() {
                                  selectedStream = stream;
                                  if (!_isSameStream(stream, currentStream)) {
                                    selectedAudioId = originalAudioId;
                                    selectedSubtitleId = originalSubtitleId;
                                    subtitlesOff =
                                        snapshot.subtitlesOffSelected;
                                  }
                                }),
                              ),
                              sourceChanges
                                  ? const _PendingSourceTracksMessage()
                                  : _HotstarTracksTab(
                                      audioTitle: l10n.audioTracks,
                                      subtitlesTitle: l10n.subtitles,
                                      noAudioText: l10n.noAudioTracks,
                                      noSubtitlesText: l10n.noSubtitlesFound,
                                      offText: l10n.off,
                                      optionsTooltip: l10n.options,
                                      audioTracks: snapshot.audioTracks,
                                      subtitleTracks: snapshot.subtitleTracks,
                                      selectedAudioId: selectedAudioId,
                                      selectedSubtitleId: selectedSubtitleId,
                                      subtitlesOff: subtitlesOff,
                                      onAudioSelected: (id) =>
                                          setState(() => selectedAudioId = id),
                                      onSubtitleOff: () => setState(() {
                                        subtitlesOff = true;
                                        selectedSubtitleId = null;
                                      }),
                                      onSubtitleSelected: (id) => setState(() {
                                        subtitlesOff = false;
                                        selectedSubtitleId = id;
                                      }),
                                      onOptions: () => Navigator.pop(
                                        ctx,
                                        const _PlayerOptionsResult(
                                          openSubtitleOptions: true,
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: canApply
                                  ? HotstarPlayerStyle.accent
                                  : HotstarPlayerStyle.panelElevated,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  HotstarPlayerStyle.panelElevated,
                              disabledForegroundColor:
                                  HotstarPlayerStyle.mutedText,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            onPressed: canApply
                                ? () => Navigator.pop(
                                    ctx,
                                    _PlayerOptionsResult(
                                      stream: sourceChanges
                                          ? selectedStream
                                          : null,
                                      tracks: !sourceChanges && trackChanges
                                          ? _TrackDialogResult(
                                              audioId: selectedAudioId,
                                              subtitleId: selectedSubtitleId,
                                              subtitleOff: subtitlesOff,
                                            )
                                          : null,
                                    ),
                                  )
                                : null,
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Future<void> showTracksSelection({
    required BuildContext context,
    required WidgetRef ref,
    List<StreamResult>? streams,
    StreamResult? currentStream,
  }) async {
    final controller = ref.read(playerControllerProvider.notifier);
    final wasPlaying = controller.isPlaying;

    if (wasPlaying) await controller.pause();
    if (!context.mounted) return;

    final optionsResult = await _showPlayerOptionsDialog(
      context: context,
      ref: ref,
      streams: streams,
      currentStream: currentStream,
      initialTab: 1,
    );
    if (!context.mounted) return;
    final result = optionsResult?.tracks;

    if (optionsResult?.openSubtitleOptions == true ||
        result?.openSubtitleOptions == true) {
      await _resumeIfNeeded(controller, wasPlaying);
      if (context.mounted) _showSubtitleOptions(context);
      return;
    }

    if (optionsResult?.stream != null) {
      await controller.changeStream(
        optionsResult!.stream!,
        manualSelection: true,
      );
      await _resumeIfNeeded(controller, wasPlaying);
      return;
    }

    if (result == null) {
      await _resumeIfNeeded(controller, wasPlaying);
      return;
    }

    await _applyTrackResult(controller, result);
    await _resumeIfNeeded(controller, wasPlaying);
  }

  static void showSpeedSelection({
    required BuildContext context,
    required double currentSpeed,
    required double maxSpeed,
    required void Function(double) onSpeedSelected,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final sliderMax = maxSpeed < 3.0 ? maxSpeed : 3.0;
    final speeds = [
      0.25,
      1.0,
      1.25,
      1.5,
      2.0,
    ].where((speed) => speed <= sliderMax + 0.001).toList();
    final sliderDivisions = ((sliderMax - 0.25) / 0.05).round();
    double selectedSpeed = currentSpeed.clamp(0.25, sliderMax).toDouble();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            void setSpeed(double value) {
              final next = value.clamp(0.25, sliderMax).toDouble();
              setState(() => selectedSpeed = next);
              onSpeedSelected(next);
            }

            final size = MediaQuery.sizeOf(context);
            final isCompact = size.shortestSide < 600;
            final compactWidth = (size.width - 32)
                .clamp(280.0, 360.0)
                .toDouble();
            final maxWidth = size.width >= 900 ? 520.0 : compactWidth;
            final compactHeight = (size.height * (isCompact ? 0.58 : 0.68))
                .clamp(isCompact ? 260.0 : 340.0, isCompact ? 340.0 : 420.0)
                .toDouble();

            return Dialog(
              backgroundColor: HotstarPlayerStyle.background,
              insetPadding: EdgeInsets.symmetric(
                horizontal: isCompact ? 14 : 16,
                vertical: isCompact ? 16 : 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isCompact ? 14 : 20),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth,
                  maxHeight: compactHeight,
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    brightness: Brightness.dark,
                    colorScheme: const ColorScheme.dark(
                      primary: HotstarPlayerStyle.accent,
                      surface: HotstarPlayerStyle.background,
                      onSurface: HotstarPlayerStyle.primaryText,
                    ),
                    chipTheme: ChipThemeData(
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      selectedColor: HotstarPlayerStyle.accent.withValues(
                        alpha: 0.22,
                      ),
                      disabledColor: Colors.white.withValues(alpha: 0.04),
                      labelStyle: const TextStyle(
                        color: HotstarPlayerStyle.secondaryText,
                      ),
                      secondaryLabelStyle: const TextStyle(
                        color: HotstarPlayerStyle.primaryText,
                      ),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isCompact ? 16 : 24,
                      isCompact ? 12 : 18,
                      isCompact ? 16 : 24,
                      isCompact ? 16 : 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.playbackSpeed,
                                style: TextStyle(
                                  color: HotstarPlayerStyle.primaryText,
                                  fontSize: isCompact ? 15 : 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close),
                              color: HotstarPlayerStyle.secondaryText,
                              autofocus: true,
                            ),
                          ],
                        ),
                        SizedBox(height: isCompact ? 10 : 20),
                        Text(
                          _formatSpeed(selectedSpeed),
                          style: TextStyle(
                            color: HotstarPlayerStyle.primaryText,
                            fontSize: isCompact ? 23 : 28,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: isCompact ? 14 : 24),
                        Row(
                          children: [
                            _speedStepButton(
                              icon: Icons.remove,
                              onPressed: () => setSpeed(selectedSpeed - 0.1),
                              compact: isCompact,
                            ),
                            SizedBox(width: isCompact ? 10 : 18),
                            Expanded(
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: isCompact ? 10 : 18,
                                  activeTrackColor: Colors.white,
                                  inactiveTrackColor: Colors.white.withValues(
                                    alpha: 0.08,
                                  ),
                                  thumbColor: Colors.white,
                                  overlayColor: HotstarPlayerStyle.accent
                                      .withValues(alpha: 0.12),
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 4,
                                  ),
                                  trackShape:
                                      const RoundedRectSliderTrackShape(),
                                ),
                                child: CustomSlider(
                                  value: selectedSpeed,
                                  min: 0.25,
                                  max: sliderMax,
                                  step: 0.05,
                                  divisions: sliderDivisions > 0
                                      ? sliderDivisions
                                      : null,
                                  // Pure visual indicator on TV — the −/+
                                  // buttons adjust it. Keeping it out of focus
                                  // traversal means D-pad Up/Down isn't trapped
                                  // and moves between the buttons and presets.
                                  focusable: false,
                                  onChanged: setSpeed,
                                ),
                              ),
                            ),
                            SizedBox(width: isCompact ? 10 : 18),
                            _speedStepButton(
                              icon: Icons.add,
                              onPressed: () => setSpeed(selectedSpeed + 0.1),
                              compact: isCompact,
                            ),
                          ],
                        ),
                        SizedBox(height: isCompact ? 14 : 24),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: isCompact ? 7 : 10,
                          runSpacing: isCompact ? 7 : 10,
                          children: speeds.map((speed) {
                            final isSelected =
                                (selectedSpeed - speed).abs() < 0.01;
                            return _SpeedPresetChip(
                              speed: speed,
                              isSelected: isSelected,
                              isCompact: isCompact,
                              onTap: () => setSpeed(speed),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static String _formatSpeed(double speed) {
    return '${speed.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '')}x';
  }

  static Widget _speedStepButton({
    required IconData icon,
    required VoidCallback? onPressed,
    bool compact = false,
  }) {
    return _SpeedStepButton(icon: icon, onPressed: onPressed, compact: compact);
  }

  static Widget _fullscreenShell({
    required BuildContext context,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Dialog.fullscreen(
      backgroundColor: HotstarPlayerStyle.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(48, 18, 48, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    color: HotstarPlayerStyle.secondaryText,
                    iconSize: 34,
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: HotstarPlayerStyle.primaryText,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing else const SizedBox(width: 48),
                ],
              ),
              const Divider(color: HotstarPlayerStyle.divider, height: 28),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }

  /// Public entry point for the subtitle-options dialog (sync / styles /
  /// search / load external). Retained for callers that still want the legacy
  /// dialog; the sources side panel now inlines these controls instead.
  static void showSubtitleOptions(BuildContext context) =>
      _showSubtitleOptions(context);

  /// Public entry point for the online subtitle search dialog. The sources
  /// side panel's "Search online" row opens this directly (pending its own
  /// redesign).
  static void showSubtitleSearch(BuildContext context) =>
      _showSubtitleSearch(context);

  static void _showSubtitleOptions(BuildContext context) {
    final parentContext = context;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Consumer(
          builder: (dialogContext, ref, child) {
            final supportsExternalSubtitleLoading = ref.watch(
              playerControllerProvider.select(
                (s) => s.supportsExternalSubtitleLoading,
              ),
            );
            final l10n = AppLocalizations.of(dialogContext)!;

            Widget option({
              required IconData icon,
              required String label,
              required VoidCallback? onTap,
            }) {
              return InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        color: onTap == null
                            ? HotstarPlayerStyle.mutedText
                            : HotstarPlayerStyle.secondaryText,
                        size: 24,
                      ),
                      const SizedBox(width: 22),
                      Text(
                        label,
                        style: TextStyle(
                          color: onTap == null
                              ? HotstarPlayerStyle.mutedText
                              : HotstarPlayerStyle.primaryText,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Dialog.fullscreen(
              backgroundColor: HotstarPlayerStyle.background,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(48, 18, 48, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.subtitleOptions,
                              style: const TextStyle(
                                color: HotstarPlayerStyle.primaryText,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close),
                            color: Colors.white,
                            iconSize: 36,
                            tooltip: l10n.cancel,
                          ),
                        ],
                      ),
                      const Divider(
                        color: HotstarPlayerStyle.divider,
                        height: 28,
                      ),
                      if (!supportsExternalSubtitleLoading)
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Colors.orange,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.hlsSubtitleWarning,
                                  style: TextStyle(
                                    color: Colors.orange.shade200,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      option(
                        icon: Icons.file_open_outlined,
                        label: l10n.loadFromDevice,
                        onTap: !supportsExternalSubtitleLoading
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                ref
                                    .read(playerControllerProvider.notifier)
                                    .loadExternalSubtitleFile();
                              },
                      ),
                      option(
                        icon: Icons.sync,
                        label: l10n.syncDelay,
                        onTap: () {
                          Navigator.pop(ctx);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (parentContext.mounted) {
                              _showSubtitleSync(parentContext);
                            }
                          });
                        },
                      ),
                      option(
                        icon: Icons.style,
                        label: l10n.styleSettings,
                        onTap: () {
                          Navigator.pop(ctx);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (parentContext.mounted) {
                              _showSubtitleStyles(parentContext);
                            }
                          });
                        },
                      ),
                      option(
                        icon: Icons.search,
                        label: l10n.searchOnline,
                        onTap: !supportsExternalSubtitleLoading
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (parentContext.mounted) {
                                    _showSubtitleSearch(parentContext);
                                  }
                                });
                              },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static void _showSubtitleSync(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => Consumer(
          builder: (context, ref, child) {
            final controller = ref.read(playerControllerProvider.notifier);
            final wasPlaying = controller.isPlaying;
            return SubtitleSyncDialog(wasPlaying: wasPlaying);
          },
        ),
      ),
    );
  }

  static void _showSubtitleStyles(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => Consumer(
          builder: (context, ref, child) {
            final controller = ref.read(playerControllerProvider.notifier);
            final wasPlaying = controller.isPlaying;
            return SubtitleAppearanceDialog(wasPlaying: wasPlaying);
          },
        ),
        fullscreenDialog: true,
      ),
    );
  }

  static void _showSubtitleSearch(BuildContext context) {
    final TextEditingController queryController = TextEditingController();

    final scrollController = ScrollController();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final l10n = AppLocalizations.of(ctx)!;
        final dialogSize = MediaQuery.sizeOf(ctx);
        final isCompact = dialogSize.shortestSide < 600;
        final horizontalPadding = isCompact ? 20.0 : 48.0;
        return _fullscreenShell(
          context: ctx,
          title: l10n.searchOnline,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  12 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Consumer(
                  builder: (context, ref, child) {
                    final playerState = ref.read(playerControllerProvider);
                    final selectedLang = ref.read(subtitleLanguageProvider);

                    // Initial population and auto-search
                    if (queryController.text.isEmpty &&
                        playerState.playerTitle.isNotEmpty) {
                      queryController.text = playerState.playerTitle;
                      Future.microtask(() {
                        if (ref.read(subtitleSearchProvider) is! AsyncLoading) {
                          ref
                              .read(subtitleSearchProvider.notifier)
                              .search(
                                query: queryController.text,
                                imdbId: playerState.imdbId,
                                tmdbId: playerState.tmdbId,
                                language: selectedLang,
                              );
                        }
                      });
                    }

                    return TextField(
                      controller: queryController,
                      autofocus: true,
                      style: const TextStyle(
                        color: HotstarPlayerStyle.primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: l10n.searchSubtitleNameHint,
                        hintStyle: const TextStyle(
                          color: HotstarPlayerStyle.mutedText,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: HotstarPlayerStyle.secondaryText,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (queryController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  queryController.clear();
                                  final playerState = ref.read(
                                    playerControllerProvider,
                                  );
                                  final selectedLang = ref.read(
                                    subtitleLanguageProvider,
                                  );
                                  ref
                                      .read(subtitleSearchProvider.notifier)
                                      .search(
                                        query: "",
                                        imdbId: playerState.imdbId,
                                        tmdbId: playerState.tmdbId,
                                        language: selectedLang,
                                      );
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: () {
                                final playerState = ref.read(
                                  playerControllerProvider,
                                );
                                final selectedLang = ref.read(
                                  subtitleLanguageProvider,
                                );
                                ref
                                    .read(subtitleSearchProvider.notifier)
                                    .search(
                                      query: queryController.text,
                                      imdbId: playerState.imdbId,
                                      tmdbId: playerState.tmdbId,
                                      language: selectedLang,
                                    );
                              },
                            ),
                          ],
                        ),
                      ),
                      onSubmitted: (val) {
                        final playerState = ref.read(playerControllerProvider);
                        final selectedLang = ref.read(subtitleLanguageProvider);
                        ref
                            .read(subtitleSearchProvider.notifier)
                            .search(
                              query: val,
                              imdbId: playerState.imdbId,
                              tmdbId: playerState.tmdbId,
                              language: selectedLang,
                            );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Language Selector (Targeted Consumer)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Consumer(
                  builder: (context, ref, child) {
                    final selectedLang = ref.watch(subtitleLanguageProvider);
                    return DesktopScrollWrapper(
                      controller: scrollController,
                      isCompact: true,
                      child: SizedBox(
                        height: 40,
                        child: ListView.separated(
                          controller: scrollController,
                          padding: EdgeInsets.zero,
                          scrollDirection: Axis.horizontal,
                          itemCount: subtitleLanguages.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final entry = subtitleLanguages.entries.elementAt(
                              index,
                            );
                            final isSelected = entry.value == selectedLang;
                            return ChoiceChip(
                              label: Text(
                                entry.key,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? Colors.white
                                      : HotstarPlayerStyle.secondaryText,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  ref
                                      .read(subtitleLanguageProvider.notifier)
                                      .set(entry.value);
                                  final playerState = ref.read(
                                    playerControllerProvider,
                                  );
                                  ref
                                      .read(subtitleSearchProvider.notifier)
                                      .search(
                                        query: queryController.text,
                                        imdbId: playerState.imdbId,
                                        tmdbId: playerState.tmdbId,
                                        language: entry.value,
                                      );
                                }
                              },
                              selectedColor: HotstarPlayerStyle.accent,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.06,
                              ),
                              showCheckmark: false,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final searchState = ref.watch(subtitleSearchProvider);
                    return searchState.when(
                      data: (results) {
                        if (results == null) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.subtitles_rounded,
                                  size: 64,
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  l10n.enterSearchSubtitlePrompt,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final settings = ref
                            .watch(playerSettingsProvider)
                            .asData
                            ?.value;
                        final hasAnyCredentials =
                            settings != null &&
                            ((settings.osUsername.isNotEmpty &&
                                    settings.osPassword.isNotEmpty &&
                                    settings.osApiKey.isNotEmpty) ||
                                settings.subdlApiKey.isNotEmpty ||
                                settings.subsourceApiKey.isNotEmpty);

                        if (results.isEmpty) {
                          if (!hasAnyCredentials) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme
                                            .primaryContainer
                                            .withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.vpn_key_rounded,
                                        size: 48,
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Subtitle Accounts Not Configured',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: HotstarPlayerStyle.primaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Explorey requires your personal API keys for OpenSubtitles, SubDL, or SubSource.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: HotstarPlayerStyle.secondaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    FilledButton.icon(
                                      onPressed: () {
                                        Navigator.pop(ctx); // Close search
                                        // The user is already in the player, we'll suggest they go to main settings
                                        // or we can try to show the specific dialogs here if they were available.
                                        // For now, let's provide a clear toast or action.
                                        ref
                                            .read(notificationServiceProvider)
                                            .showInfo(
                                              'Go to App Settings > Player > Subtitle Accounts to configure.',
                                              title: 'Subtitles',
                                              icon: Icons.subtitles_rounded,
                                            );
                                      },
                                      icon: const Icon(
                                        Icons.settings_outlined,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'View Settings Instructions',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.subtitles_off_rounded,
                                  size: 64,
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  l10n.noSubtitleResults,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: results.length,
                          separatorBuilder: (_, _) => Divider(
                            color: theme.dividerColor.withValues(alpha: 0.05),
                            height: 1,
                            indent: 20,
                            endIndent: 20,
                          ),
                          itemBuilder: (context, index) {
                            final sub = results[index];
                            return _buildSubtitleCard(
                              context: context,
                              sub: sub,
                              onTap: () async {
                                ref
                                    .read(notificationServiceProvider)
                                    .showInfo(
                                      l10n.downloadingApplyingSubtitle,
                                      title: 'Subtitles',
                                      icon: Icons.subtitles_rounded,
                                    );

                                final path = await ref
                                    .read(subtitleSearchProvider.notifier)
                                    .downloadAndPrepare(sub);

                                if (path != null) {
                                  unawaited(
                                    ref
                                        .read(playerControllerProvider.notifier)
                                        .loadExternalSubtitleFile(
                                          filePath: path,
                                        ),
                                  );
                                  if (context.mounted) Navigator.pop(ctx);
                                } else {
                                  if (context.mounted) {
                                    ref
                                        .read(notificationServiceProvider)
                                        .showError(
                                          l10n.failedToDownloadSubtitle,
                                          title: 'Subtitles',
                                          icon: Icons.subtitles_off_rounded,
                                        );
                                  }
                                }
                              },
                            );
                          },
                        );
                      },
                      loading: () => _buildShimmerLoading(context),
                      error: (err, stack) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            l10n.failedToLoadSubtitles,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildShimmerLoading(BuildContext context) {
    final theme = Theme.of(context);
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
      highlightColor: theme.colorScheme.onSurface.withValues(alpha: 0.2),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 6,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 200,
                      height: 14,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 18,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 80,
                          height: 14,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildSubtitleCard({
    required BuildContext context,
    required OnlineSubtitle sub,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final sourceColor = sub.source.toLowerCase().contains("subsource")
        ? Colors.blueAccent
        : (sub.source.toLowerCase().contains("opensubtitles")
              ? Colors.orangeAccent
              : theme.colorScheme.primary);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sub.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: HotstarPlayerStyle.primaryText,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: sourceColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: sourceColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    sub.language.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      color: sourceColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  sub.source,
                  style: const TextStyle(
                    color: HotstarPlayerStyle.secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (sub.isHearingImpaired)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.hearing,
                      size: 16,
                      color: theme.hintColor.withValues(alpha: 0.5),
                    ),
                  ),
                Icon(
                  Icons.download_for_offline_outlined,
                  size: 20,
                  color: theme.hintColor.withValues(alpha: 0.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HotstarSourcesTab extends StatefulWidget {
  final List<StreamResult> streams;
  final StreamResult? selectedStream;
  final String emptyText;
  final ValueChanged<StreamResult> onSelected;
  final bool qualityFilteredFallback;

  const _HotstarSourcesTab({
    required this.streams,
    required this.selectedStream,
    required this.emptyText,
    required this.onSelected,
    this.qualityFilteredFallback = false,
  });

  @override
  State<_HotstarSourcesTab> createState() => _HotstarSourcesTabState();
}

class _HotstarSourcesTabState extends State<_HotstarSourcesTab> {
  /// The quality badge label the user has tapped to filter by, or null = show all.
  String? _activeFilter;

  /// Returns the quality badge label for a stream.
  String _badge(StreamResult s) => qualityBadgeLabel(s);

  /// Distinct quality tiers that appear in the stream list (smart: only present tiers).
  List<String> get _presentTiers {
    final seen = <String>{};
    final tiers = <String>[];
    for (final s in widget.streams) {
      final b = _badge(s);
      if (seen.add(b)) tiers.add(b);
    }
    // Sort in a sensible display order
    const order = ['4K', '1080p', '720p', '480p', '360p', 'Auto'];
    tiers.sort((a, b) {
      final ai = order.indexOf(a);
      final bi = order.indexOf(b);
      return (ai == -1 ? 99 : ai).compareTo(bi == -1 ? 99 : bi);
    });
    return tiers;
  }

  List<StreamResult> get _visibleStreams {
    if (_activeFilter == null) return widget.streams;
    return widget.streams.where((s) => _badge(s) == _activeFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.shortestSide < 600;

    if (widget.streams.isEmpty) {
      return Center(
        child: Text(
          widget.emptyText,
          style: const TextStyle(
            color: HotstarPlayerStyle.secondaryText,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final tiers = _presentTiers;
    final visible = _visibleStreams;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Fallback banner ─────────────────────────────────────────────────
        if (widget.qualityFilteredFallback)
          Container(
            margin: EdgeInsets.only(bottom: isCompact ? 10 : 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.filter_alt_off_rounded,
                  color: Colors.amber,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No sources matched your quality filter — showing all sources. '
                    'Try a different filter in Settings.',
                    style: TextStyle(
                      color: Colors.amber.shade200,
                      fontSize: isCompact ? 12 : 13,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // ── Quality filter chips ─────────────────────────────────────────────
        if (tiers.length > 1) ...[
          SizedBox(
            height: isCompact ? 34 : 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 8),
              itemCount: tiers.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final tier = tiers[i];
                final selected = _activeFilter == tier;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _activeFilter = selected ? null : tier),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? HotstarPlayerStyle.accent
                          : HotstarPlayerStyle.panelElevated,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? HotstarPlayerStyle.accent
                            : HotstarPlayerStyle.divider,
                      ),
                    ),
                    child: Text(
                      tier,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : HotstarPlayerStyle.secondaryText,
                        fontSize: isCompact ? 12 : 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: isCompact ? 10 : 16),
        ],

        // ── Stream list ──────────────────────────────────────────────────────
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.only(
              top: isCompact ? 2 : 4,
              right: isCompact ? 0 : 24,
            ),
            itemCount: visible.length,
            separatorBuilder: (_, _) => SizedBox(height: isCompact ? 8 : 18),
            itemBuilder: (context, index) {
              final stream = visible[index];
              final selected =
                  widget.selectedStream != null &&
                  widget.selectedStream!.url == stream.url &&
                  widget.selectedStream!.source == stream.source;
              final badge = _badge(stream);

              return _HotstarOptionRow(
                label: stream.source,
                metadata: selected ? 'Current source' : null,
                selected: selected,
                badge: badge != 'Auto' ? badge : null,
                onTap: () => widget.onSelected(stream),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PendingSourceTracksMessage extends StatelessWidget {
  const _PendingSourceTracksMessage();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.shortestSide < 600;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.graphic_eq_rounded,
              color: HotstarPlayerStyle.secondaryText,
              size: isCompact ? 34 : 42,
            ),
            SizedBox(height: isCompact ? 12 : 18),
            Text(
              'Apply the source first',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: HotstarPlayerStyle.primaryText,
                fontSize: isCompact ? 18 : 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: isCompact ? 8 : 10),
            Text(
              'Audio and subtitles are loaded separately for each source.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: HotstarPlayerStyle.mutedText,
                fontSize: isCompact ? 13 : 15,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HotstarTracksTab extends StatelessWidget {
  final String audioTitle;
  final String subtitlesTitle;
  final String noAudioText;
  final String noSubtitlesText;
  final String offText;
  final String optionsTooltip;
  final List<dynamic> audioTracks;
  final List<dynamic> subtitleTracks;
  final String? selectedAudioId;
  final String? selectedSubtitleId;
  final bool subtitlesOff;
  final ValueChanged<String> onAudioSelected;
  final ValueChanged<String> onSubtitleSelected;
  final VoidCallback onSubtitleOff;
  final VoidCallback onOptions;

  const _HotstarTracksTab({
    required this.audioTitle,
    required this.subtitlesTitle,
    required this.noAudioText,
    required this.noSubtitlesText,
    required this.offText,
    required this.optionsTooltip,
    required this.audioTracks,
    required this.subtitleTracks,
    required this.selectedAudioId,
    required this.selectedSubtitleId,
    required this.subtitlesOff,
    required this.onAudioSelected,
    required this.onSubtitleSelected,
    required this.onSubtitleOff,
    required this.onOptions,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.shortestSide < 600;
    final audioColumn = _HotstarOptionColumn(
      title: audioTitle.toUpperCase(),
      emptyText: noAudioText,
      children: audioTracks.map((track) {
        final id = track.id as String;
        return _HotstarOptionRow(
          label: track.label as String,
          metadata: track.subtitle as String?,
          selected: selectedAudioId == id,
          onTap: () => onAudioSelected(id),
        );
      }).toList(),
    );
    final subtitlesColumn = _HotstarOptionColumn(
      title: subtitlesTitle.toUpperCase(),
      emptyText: noSubtitlesText,
      action: IconButton(
        tooltip: optionsTooltip,
        onPressed: onOptions,
        color: HotstarPlayerStyle.secondaryText,
        icon: const Icon(Icons.settings_outlined),
      ),
      children: [
        _HotstarOptionRow(
          label: offText,
          selected: subtitlesOff,
          onTap: onSubtitleOff,
        ),
        ...subtitleTracks.map((track) {
          final id = track.id as String;
          return _HotstarOptionRow(
            label: track.label as String,
            metadata: track.subtitle as String?,
            selected: !subtitlesOff && selectedSubtitleId == id,
            onTap: () => onSubtitleSelected(id),
          );
        }),
      ],
    );

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: audioColumn),
          const Divider(color: HotstarPlayerStyle.divider, height: 18),
          Expanded(child: subtitlesColumn),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: audioColumn),
        Container(
          width: 1,
          height: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 40),
          color: HotstarPlayerStyle.divider,
        ),
        Expanded(child: subtitlesColumn),
      ],
    );
  }
}

class _HotstarOptionColumn extends StatelessWidget {
  final String title;
  final String emptyText;
  final List<Widget> children;
  final Widget? action;

  const _HotstarOptionColumn({
    required this.title,
    required this.emptyText,
    required this.children,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.shortestSide < 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: HotstarPlayerStyle.mutedText,
                  fontSize: isCompact ? 13 : 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: isCompact ? 1.0 : 1.8,
                ),
              ),
            ),
            ?action,
          ],
        ),
        SizedBox(height: isCompact ? 10 : 26),
        Expanded(
          child: children.isEmpty
              ? Text(
                  emptyText,
                  style: TextStyle(
                    color: HotstarPlayerStyle.mutedText,
                    fontSize: isCompact ? 14 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : ListView.separated(
                  itemCount: children.length,
                  separatorBuilder: (_, _) =>
                      SizedBox(height: isCompact ? 8 : 20),
                  itemBuilder: (_, index) => children[index],
                ),
        ),
      ],
    );
  }
}

class _HotstarOptionRow extends StatefulWidget {
  final String label;
  final String? metadata;
  final bool selected;
  final VoidCallback onTap;

  /// Optional quality badge shown as a small pill on the right (e.g. "1080p").
  final String? badge;

  const _HotstarOptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.metadata,
    this.badge,
  });

  @override
  State<_HotstarOptionRow> createState() => _HotstarOptionRowState();
}

class _HotstarOptionRowState extends State<_HotstarOptionRow> {
  bool _isFocused = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.shortestSide < 600;
    final showHighlight = _isHovered || _isFocused;

    return FocusableActionDetector(
      onShowFocusHighlight: (v) => setState(() => _isFocused = v),
      onShowHoverHighlight: (v) => setState(() => _isHovered = v),
      child: InkWell(
        onTap: widget.onTap,
        hoverColor: HotstarPlayerStyle.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        child: AnimatedScale(
          scale: _isFocused ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: HotstarPlayerStyle.fastMotionDuration,
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 8 : 12,
              vertical: isCompact ? 5 : 8,
            ),
            decoration: BoxDecoration(
              color: widget.selected
                  ? Colors.white.withValues(alpha: 0.04)
                  : (showHighlight
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.transparent),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _isFocused
                    ? HotstarPlayerStyle.accent
                    : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: HotstarPlayerStyle.accent.withValues(
                          alpha: 0.25,
                        ),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: isCompact ? 22 : 28,
                  child: widget.selected
                      ? const Icon(
                          Icons.check,
                          color: HotstarPlayerStyle.accent,
                          size: 22,
                        )
                      : null,
                ),
                SizedBox(width: isCompact ? 10 : 18),
                Flexible(
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      text: widget.label,
                      style: TextStyle(
                        color: widget.selected
                            ? HotstarPlayerStyle.primaryText
                            : HotstarPlayerStyle.mutedText,
                        fontSize: isCompact ? 15 : 18,
                        fontWeight: widget.selected
                            ? FontWeight.w800
                            : FontWeight.w700,
                      ),
                      children: [
                        if (widget.metadata != null &&
                            widget.metadata!.trim().isNotEmpty)
                          TextSpan(
                            text: '  ${widget.metadata!.trim()}',
                            style: TextStyle(
                              color: HotstarPlayerStyle.mutedText,
                              fontSize: isCompact ? 15 : 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (widget.badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: HotstarPlayerStyle.panelElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: HotstarPlayerStyle.divider,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      widget.badge!,
                      style: TextStyle(
                        color: HotstarPlayerStyle.secondaryText,
                        fontSize: isCompact ? 10 : 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeedPresetChip extends StatefulWidget {
  final double speed;
  final bool isSelected;
  final bool isCompact;
  final VoidCallback onTap;

  const _SpeedPresetChip({
    required this.speed,
    required this.isSelected,
    required this.isCompact,
    required this.onTap,
  });

  @override
  State<_SpeedPresetChip> createState() => _SpeedPresetChipState();
}

class _SpeedPresetChipState extends State<_SpeedPresetChip> {
  bool _isFocused = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final showHighlight = _isHovered || _isFocused;
    return FocusableActionDetector(
      onShowFocusHighlight: (v) => setState(() => _isFocused = v),
      onShowHoverHighlight: (v) => setState(() => _isHovered = v),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedScale(
          scale: _isFocused ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: HotstarPlayerStyle.fastMotionDuration,
            width: widget.isCompact ? 76 : 104,
            padding: EdgeInsets.symmetric(vertical: widget.isCompact ? 10 : 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? HotstarPlayerStyle.accent.withValues(alpha: 0.22)
                  : (showHighlight
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.06)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _isFocused
                    ? HotstarPlayerStyle.accent
                    : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: HotstarPlayerStyle.accent.withValues(
                          alpha: 0.25,
                        ),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              PlayerBottomSheets._formatSpeed(widget.speed),
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                color: widget.isSelected
                    ? HotstarPlayerStyle.primaryText
                    : HotstarPlayerStyle.secondaryText,
                fontSize: widget.isCompact ? 13 : 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeedStepButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool compact;

  const _SpeedStepButton({
    required this.icon,
    required this.onPressed,
    required this.compact,
  });

  @override
  State<_SpeedStepButton> createState() => _SpeedStepButtonState();
}

class _SpeedStepButtonState extends State<_SpeedStepButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onShowFocusHighlight: (v) => setState(() => _isFocused = v),
      child: AnimatedScale(
        scale: _isFocused ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: IconButton(
          onPressed: widget.onPressed,
          icon: Icon(widget.icon, size: widget.compact ? 20 : 24),
          color: HotstarPlayerStyle.primaryText,
          style: IconButton.styleFrom(
            backgroundColor: _isFocused
                ? HotstarPlayerStyle.accent.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.06),
            fixedSize: Size(widget.compact ? 42 : 56, widget.compact ? 42 : 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.compact ? 10 : 14),
              side: BorderSide(
                color: _isFocused
                    ? HotstarPlayerStyle.accent
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
