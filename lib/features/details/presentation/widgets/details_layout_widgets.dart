import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:collection/collection.dart';
import '../downloaded_file_provider.dart';

import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/core/storage/history_repository.dart';
import 'package:skystream/core/utils/layout_constants.dart';
import 'package:skystream/shared/widgets/custom_widgets.dart';
import '../details_controller.dart';
import 'package:skystream/core/extensions/extension_manager.dart';
import 'package:skystream/core/services/download_service.dart';
import '../download_launcher.dart';
import 'download_progress_dialog.dart';
import 'download_management_dialog.dart';
import 'episode_card.dart';
import 'package:skystream/core/providers/device_info_provider.dart';
import 'package:skystream/core/utils/responsive_breakpoints.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';

class DetailsSeasonListWrapper extends ConsumerWidget {
  const DetailsSeasonListWrapper({super.key, required this.itemUrl});
  final String itemUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasonMap = ref.watch(
      detailsControllerProvider(itemUrl).select((s) => s.seasonMap),
    );
    if (seasonMap.keys.length <= 1) return const SizedBox.shrink();

    final selectedSeason = ref.watch(
      detailsControllerProvider(itemUrl).select((s) => s.selectedSeason),
    );
    final seasons = seasonMap.keys.toList()..sort();

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: seasons.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: LayoutConstants.spacingXs),
        itemBuilder: (context, index) {
          final s = seasons[index];
          final isSelected = s == selectedSeason;
          return FilterChip(
            label: Text(AppLocalizations.of(context)!.seasonWithNumber(s)),
            selected: isSelected,
            onSelected: (_) => ref
                .read(detailsControllerProvider(itemUrl).notifier)
                .setSeason(s),
            backgroundColor: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            labelStyle: TextStyle(
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class DetailsActionButtons extends HookConsumerWidget {
  final MultimediaItem item;
  final MultimediaItem? details;
  final String itemUrl;
  final bool vertical;

  const DetailsActionButtons({
    super.key,
    required this.item,
    required this.details,
    required this.itemUrl,
    this.vertical = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyRepo = ref.watch(historyRepositoryProvider);
    final targetEpisode = ref.watch(
      detailsControllerProvider(itemUrl).select((s) => s.targetEpisode),
    );
    final isLaunching = ref.watch(
      detailsControllerProvider(itemUrl).select((s) => s.isLaunching),
    );
    final isMovie = ref.watch(
      detailsControllerProvider(itemUrl).select((s) => s.isMovie),
    );
    final seasonMap = ref.watch(
      detailsControllerProvider(itemUrl).select((s) => s.seasonMap),
    );
    final isSingleSeason = seasonMap.keys.length <= 1;

    final playFocusNode = useFocusNode();
    final isTv = ref.watch(deviceProfileProvider).asData?.value.isTv ?? false;
    final isMobile = context.isMobile;

    final btnPadding = EdgeInsets.symmetric(
      vertical: isMobile
          ? LayoutConstants.spacingSm
          : LayoutConstants.spacingMd,
      horizontal: LayoutConstants.spacingMd,
    );

    final pos = targetEpisode != null
        ? historyRepo.getEpisodePosition(
            targetEpisode.url,
            mainUrl: item.url,
            season: targetEpisode.season,
            episode: targetEpisode.episode,
          )
        : historyRepo.getPosition(item.url);
    final dur = targetEpisode != null
        ? historyRepo.getEpisodeDuration(
            targetEpisode.url,
            mainUrl: item.url,
            season: targetEpisode.season,
            episode: targetEpisode.episode,
          )
        : historyRepo.getDuration(item.url);

    final l10n = AppLocalizations.of(context)!;
    final bool isResuming = pos > 5000;

    String playLabel = isResuming ? l10n.resume : l10n.play;
    if (targetEpisode != null && !isMovie) {
      if (isSingleSeason) {
        playLabel = l10n.playEpisodeOnly(playLabel, targetEpisode.episode);
      } else {
        playLabel = l10n.playEpisode(
          playLabel,
          targetEpisode.season,
          targetEpisode.episode,
        );
      }
    }

    final playBtn = CustomButton(
      isPrimary: true,
      focusNode: playFocusNode,
      autofocus: true,
      onPressed:
          (details != null &&
              details!.episodes != null &&
              details!.episodes!.isNotEmpty)
          ? () async {
              await ref
                  .read(detailsControllerProvider(item.url).notifier)
                  .handlePlayPress(context, details!);

              // Phase 10 Fix: TV Focus restoration on return from player
              if (context.mounted && isTv) {
                playFocusNode.requestFocus();
              }
            }
          : null,
      child: Padding(
        padding: btnPadding,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: isLaunching
              ? [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: LayoutConstants.spacingXs),
                  Text(AppLocalizations.of(context)!.resolving),
                ]
              : [
                  const Icon(Icons.play_arrow_rounded),
                  const SizedBox(width: LayoutConstants.spacingXs),
                  Text(playLabel),
                ],
        ),
      ),
    );

    // Download feature: only for single episode VOD content
    final isLivestream = item.contentType == MultimediaContentType.livestream;
    final showDownload =
        details?.episodes != null &&
        details?.episodes?.length == 1 &&
        !isLivestream;

    final episodeUrl = details?.episodes?.firstOrNull?.url ?? item.url;
    final activeDownloads = ref.watch(activeDownloadsProvider);
    final isDownloading = activeDownloads.contains(episodeUrl);
    final progressMap = ref.watch(downloadProgressProvider);
    final downloadProgressData =
        progressMap[episodeUrl] ?? progressMap[item.url];
    final downloadProgress = downloadProgressData?.progress ?? 0.0;

    final downloadedFile = ref.watch(downloadedFilesProvider)[episodeUrl];

    // Check for downloaded file on load
    useEffect(() {
      if (details != null && !isDownloading) {
        Future.microtask(() {
          ref
              .read(downloadedFilesProvider.notifier)
              .checkFile(
                details!,
                episode: details?.episodes?.firstWhereOrNull(
                  (e) => e.url == episodeUrl,
                ),
              );
        });
      }
      return null;
    }, [details, episodeUrl, isDownloading]);

    final downloadBtn = !showDownload
        ? const SizedBox.shrink()
        : downloadedFile != null
        ? CustomButton(
            isPrimary: false,
            isOutlined: true,
            onPressed: () {
              DownloadManagementDialog.show(
                context,
                details ?? item,
                downloadedFile,
                episode: details?.episodes?.firstWhereOrNull(
                  (e) => e.url == episodeUrl,
                ),
              );
            },
            child: Padding(
              padding: btnPadding,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.download_done_sharp, color: Colors.green),
                  const SizedBox(width: LayoutConstants.spacingXs),
                  Text(AppLocalizations.of(context)!.downloaded),
                ],
              ),
            ),
          )
        : CustomButton(
            isPrimary: false,
            isOutlined: true,
            onPressed: isDownloading
                ? () => DownloadProgressDialog.show(
                    context,
                    details?.title ?? item.title,
                    episodeUrl,
                  )
                : () {
                    ref
                        .read(downloadLauncherProvider)
                        .launch(
                          context,
                          details ?? item,
                          episodeUrl: episodeUrl,
                        );
                  },
            child: Padding(
              padding: btnPadding,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: isDownloading
                    ? [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              downloadProgressData?.status == TaskStatus.paused
                              ? Icon(
                                  Icons.pause_rounded,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : CircularProgressIndicator(
                                  value: downloadProgress > 0
                                      ? downloadProgress
                                      : null,
                                  strokeWidth: 2,
                                ),
                        ),
                        const SizedBox(width: LayoutConstants.spacingXs),
                        Text(
                          downloadProgressData?.status == TaskStatus.paused
                              ? AppLocalizations.of(context)!.paused
                              : downloadProgress > 0
                              ? '${(downloadProgress * 100).toInt()}%'
                              : AppLocalizations.of(context)!.starting,
                        ),
                      ]
                    : [
                        const Icon(Icons.download_rounded),
                        const SizedBox(width: LayoutConstants.spacingXs),
                        Text(AppLocalizations.of(context)!.download),
                      ],
              ),
            ),
          );

    Widget progressWidget = const SizedBox.shrink();
    if (pos > 0 && dur > 0 && !isLivestream) {
      final progress = (pos / dur).clamp(0.0, 1.0);
      progressWidget = Padding(
        padding: const EdgeInsets.only(bottom: 16.0, left: 8.0, right: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(100), // Stadium style
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.history_toggle_off_rounded,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  "${AppLocalizations.of(context)!.percentWatched((progress * 100).toInt())}${!isMovie && targetEpisode != null ? (isSingleSeason ? ' • E${targetEpisode.episode}' : ' • S${targetEpisode.season} E${targetEpisode.episode}') : ''}",
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final actionRow = showDownload
        ? IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: playBtn),
                const SizedBox(width: LayoutConstants.spacingSm),
                Expanded(child: downloadBtn),
              ],
            ),
          )
        : playBtn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        progressWidget,
        actionRow,
      ],
    );
  }
}

class SliverDetailsDesktopEpisodeGrid extends ConsumerWidget {
  final MultimediaItem parentItem;
  final String itemUrl;
  final bool isMovie;

  const SliverDetailsDesktopEpisodeGrid({
    super.key,
    required this.parentItem,
    required this.itemUrl,
    required this.isMovie,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isMovie) return const SliverToBoxAdapter(child: SizedBox.shrink());

    final detailsState = ref.watch(detailsControllerProvider(itemUrl));
    var episodes = detailsState.seasonMap[detailsState.selectedSeason] ?? [];

    if (episodes.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final hasDub = episodes.any((e) => e.dubStatus == DubStatus.dubbed);
    final hasSub = episodes.any((e) => e.dubStatus == DubStatus.subbed);
    final isMixed = hasDub && hasSub;

    // Apply Language Filter
    if (isMixed && detailsState.selectedDubStatus != DubStatus.none) {
      episodes = episodes
          .where((e) => e.dubStatus == detailsState.selectedDubStatus)
          .toList();
    }

    // Apply Batching (FIRST)
    const int batchSize = 20;
    final int start = detailsState.selectedRangeIndex * batchSize;
    final int end = (start + batchSize).clamp(0, episodes.length);
    List<Episode> displayedEpisodes = episodes.sublist(start, end);

    // Apply Sorting (SECOND - only on the batch)
    if (!detailsState.isAscending) {
      displayedEpisodes = displayedEpisodes.reversed.toList();
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: LayoutConstants.spacingMd),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 12,
              children: [
                Text(
                  AppLocalizations.of(context)!.episodes,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                DetailsEpisodeFilterBar(
                  itemUrl: itemUrl,
                  totalEpisodes: episodes.length,
                  batchSize: batchSize,
                ),
              ],
            ),
          ),
        ),
        SliverLayoutBuilder(
          builder: (context, constraints) {
            final double crossAxisExtent = constraints.crossAxisExtent;
            final int crossAxisCount = (crossAxisExtent / 480).ceil().clamp(
              1,
              5,
            );
            final int rowCount = (displayedEpisodes.length / crossAxisCount)
                .ceil();

            return SliverList.separated(
              itemCount: rowCount,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, rowIndex) {
                final int startIndex = rowIndex * crossAxisCount;
                final int endIndex = (startIndex + crossAxisCount).clamp(
                  0,
                  displayedEpisodes.length,
                );
                final rowEpisodes = displayedEpisodes.sublist(
                  startIndex,
                  endIndex,
                );

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < crossAxisCount; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: i == 0 ? 0 : 8,
                              right: i == crossAxisCount - 1 ? 0 : 8,
                            ),
                            child: i < rowEpisodes.length
                                ? EpisodeCard(
                                        episode: rowEpisodes[i],
                                        parentItem: parentItem,
                                      )
                                      as Widget
                                : const SizedBox.shrink(),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class SliverDetailsEpisodeList extends ConsumerWidget {
  final MultimediaItem parentItem;
  final String itemUrl;
  final bool isMovie;

  const SliverDetailsEpisodeList({
    super.key,
    required this.parentItem,
    required this.itemUrl,
    required this.isMovie,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isMovie) return const SliverToBoxAdapter(child: SizedBox.shrink());

    final detailsState = ref.watch(detailsControllerProvider(itemUrl));
    var episodes = detailsState.seasonMap[detailsState.selectedSeason] ?? [];

    if (episodes.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final hasDub = episodes.any((e) => e.dubStatus == DubStatus.dubbed);
    final hasSub = episodes.any((e) => e.dubStatus == DubStatus.subbed);
    final isMixed = hasDub && hasSub;

    // Apply Language Filter
    if (isMixed && detailsState.selectedDubStatus != DubStatus.none) {
      episodes = episodes
          .where((e) => e.dubStatus == detailsState.selectedDubStatus)
          .toList();
    }

    // Apply Batching (FIRST)
    const int batchSize = 20;
    final int start = detailsState.selectedRangeIndex * batchSize;
    final int end = (start + batchSize).clamp(0, episodes.length);
    List<Episode> displayedEpisodes = episodes.sublist(start, end);

    // Apply Sorting (SECOND - only on the batch)
    if (!detailsState.isAscending) {
      displayedEpisodes = displayedEpisodes.reversed.toList();
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: LayoutConstants.spacingMd),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 12,
              children: [
                Text(
                  AppLocalizations.of(context)!.episodes,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                DetailsEpisodeFilterBar(
                  itemUrl: itemUrl,
                  totalEpisodes: episodes.length,
                  batchSize: batchSize,
                ),
              ],
            ),
          ),
        ),
        SliverList.separated(
          itemCount: displayedEpisodes.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final ep = displayedEpisodes[index];
            return EpisodeCard(episode: ep, parentItem: parentItem) as Widget;
          },
        ),
      ],
    );
  }
}

class DetailsEpisodeFilterBar extends ConsumerStatefulWidget {
  final String itemUrl;
  final int totalEpisodes;
  final int batchSize;

  const DetailsEpisodeFilterBar({
    super.key,
    required this.itemUrl,
    required this.totalEpisodes,
    required this.batchSize,
  });

  @override
  ConsumerState<DetailsEpisodeFilterBar> createState() =>
      _DetailsEpisodeFilterBarState();
}

class _DetailsEpisodeFilterBarState
    extends ConsumerState<DetailsEpisodeFilterBar> {
  final FocusNode _dropdownFocusNode = FocusNode();

  @override
  void dispose() {
    _dropdownFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailsState = ref.watch(detailsControllerProvider(widget.itemUrl));
    final int selectedIndex = detailsState.selectedRangeIndex;
    final bool isAscending = detailsState.isAscending;
    final DubStatus selectedDub = detailsState.selectedDubStatus;

    final allEpisodes =
        detailsState.seasonMap[detailsState.selectedSeason] ?? [];
    final hasDub = allEpisodes.any((e) => e.dubStatus == DubStatus.dubbed);
    final hasSub = allEpisodes.any((e) => e.dubStatus == DubStatus.subbed);
    final isMixed = hasDub && hasSub;

    final filteredEpisodes = (isMixed && selectedDub != DubStatus.none)
        ? allEpisodes.where((e) => e.dubStatus == selectedDub).toList()
        : allEpisodes;

    final int batchCount = (filteredEpisodes.length / widget.batchSize).ceil();

    return SizedBox(
      height: 40,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isMixed) ...[
            _buildLanguageToggle(context, selectedDub),
            const SizedBox(width: 8),
          ],
          if (filteredEpisodes.length > widget.batchSize) ...[
            ListenableBuilder(
              listenable: _dropdownFocusNode,
              builder: (context, _) {
                final isFocused = _dropdownFocusNode.hasFocus;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isFocused ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: DropdownButton<int>(
                      focusNode: _dropdownFocusNode,
                      value: selectedIndex,
                      dropdownColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHigh,
                      underline: const SizedBox(),
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      items: List.generate(batchCount, (index) {
                        final start = index * widget.batchSize + 1;
                        final end = ((index + 1) * widget.batchSize).clamp(
                          1,
                          filteredEpisodes.length,
                        );
                        return DropdownMenuItem(
                          value: index,
                          child: Text("$start-$end"),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) {
                          ref
                              .read(
                                detailsControllerProvider(
                                  widget.itemUrl,
                                ).notifier,
                              )
                              .setRangeIndex(val);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
          Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => ref
                    .read(detailsControllerProvider(widget.itemUrl).notifier)
                    .toggleSort(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Icons.swap_vert_rounded,
                    size: 22,
                    color: isAscending
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageToggle(BuildContext context, DubStatus selected) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LanguageButton(
            label: AppLocalizations.of(context)!.sub,
            isSelected: selected == DubStatus.subbed,
            onTap: () => ref
                .read(detailsControllerProvider(widget.itemUrl).notifier)
                .setDubStatus(DubStatus.subbed),
          ),
          const SizedBox(width: 4),
          _LanguageButton(
            label: AppLocalizations.of(context)!.dub,
            isSelected: selected == DubStatus.dubbed,
            onTap: () => ref
                .read(detailsControllerProvider(widget.itemUrl).notifier)
                .setDubStatus(DubStatus.dubbed),
          ),
        ],
      ),
    );
  }
}

class _LanguageButton extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_LanguageButton> createState() => _LanguageButtonState();
}

class _LanguageButtonState extends State<_LanguageButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 40 / 255)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isFocused
                  ? Colors.white
                  : (widget.isSelected
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 80 / 255)
                        : Colors.transparent),
              width: _isFocused ? 2 : 1,
            ),
          ),
          child: Text(
            widget.label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: widget.isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: widget.isSelected
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class DetailsChip extends StatelessWidget {
  final String label;

  const DetailsChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }
}

class DetailsProviderChip extends ConsumerWidget {
  final String providerName;

  const DetailsProviderChip({super.key, required this.providerName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool isDebug = false;
    String displayName = providerName;
    try {
      final manager = ref.read(extensionManagerProvider.notifier);
      final p = manager.getAllProviders().firstWhere(
        (p) => p.packageName == providerName || p.name == providerName,
      );
      displayName = p.name;
      if (p.isDebug) {
        isDebug = true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DetailsProviderChip.build: $e');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.extension_rounded,
            size: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            displayName.toUpperCase(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          if (isDebug) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'DEBUG',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Non-sliver desktop episode grid for use inside [DetailsDesktopHero]'s
/// [SingleChildScrollView]. Mirrors [SliverDetailsDesktopEpisodeGrid] but
/// uses [LayoutBuilder] + [Column] instead of sliver equivalents.
class DetailsDesktopEpisodeColumn extends ConsumerWidget {
  final MultimediaItem parentItem;
  final String itemUrl;
  final bool isMovie;

  const DetailsDesktopEpisodeColumn({
    super.key,
    required this.parentItem,
    required this.itemUrl,
    required this.isMovie,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isMovie) return const SizedBox.shrink();

    final detailsState = ref.watch(detailsControllerProvider(itemUrl));
    var episodes = detailsState.seasonMap[detailsState.selectedSeason] ?? [];

    if (episodes.isEmpty) return const SizedBox.shrink();

    final hasDub = episodes.any((e) => e.dubStatus == DubStatus.dubbed);
    final hasSub = episodes.any((e) => e.dubStatus == DubStatus.subbed);
    final isMixed = hasDub && hasSub;

    // Apply Language Filter
    if (isMixed && detailsState.selectedDubStatus != DubStatus.none) {
      episodes = episodes
          .where((e) => e.dubStatus == detailsState.selectedDubStatus)
          .toList();
    }

    // Apply Batching (FIRST)
    const int batchSize = 20;
    final int start = detailsState.selectedRangeIndex * batchSize;
    final int end = (start + batchSize).clamp(0, episodes.length);
    List<Episode> displayedEpisodes = episodes.sublist(start, end);

    // Apply Sorting (SECOND - only on the batch)
    if (!detailsState.isAscending) {
      displayedEpisodes = displayedEpisodes.reversed.toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: LayoutConstants.spacingMd),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 12,
            children: [
              Text(
                AppLocalizations.of(context)!.episodes,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              DetailsEpisodeFilterBar(
                itemUrl: itemUrl,
                totalEpisodes: episodes.length,
                batchSize: batchSize,
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final double crossAxisExtent = constraints.maxWidth;
            final int crossAxisCount = (crossAxisExtent / 480).ceil().clamp(
              1,
              5,
            );
            final int rowCount = (displayedEpisodes.length / crossAxisCount)
                .ceil();

            return Column(
              children: List.generate(rowCount, (rowIndex) {
                final int startIndex = rowIndex * crossAxisCount;
                final int endIndex = (startIndex + crossAxisCount).clamp(
                  0,
                  displayedEpisodes.length,
                );
                final rowEpisodes = displayedEpisodes.sublist(
                  startIndex,
                  endIndex,
                );

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: rowIndex < rowCount - 1 ? 16 : 0,
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < crossAxisCount; i++)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: i == 0 ? 0 : 8,
                                right: i == crossAxisCount - 1 ? 0 : 8,
                              ),
                              child: i < rowEpisodes.length
                                  ? EpisodeCard(
                                          episode: rowEpisodes[i],
                                          parentItem: parentItem,
                                        )
                                        as Widget
                                  : const SizedBox.shrink(),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}
