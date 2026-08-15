import 'dart:async';
import 'dart:io';
import 'package:background_downloader/background_downloader.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skystream/core/utils/image_fallbacks.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/services/download_service.dart';
import '../../../../core/utils/layout_constants.dart';
import '../../../details/presentation/playback_launcher.dart';
import '../downloads_provider.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/file_size_formatter.dart';
import '../../../../shared/widgets/loading_indicator.dart';

class DownloadsTab extends ConsumerStatefulWidget {
  const DownloadsTab({super.key});

  @override
  ConsumerState<DownloadsTab> createState() => _DownloadsTabState();
}

class _DownloadsTabState extends ConsumerState<DownloadsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final downloadsAsync = ref.watch(downloadsProvider);
    final activeProgress = ref.watch(downloadProgressProvider);
    final l10n = AppLocalizations.of(context)!;

    return downloadsAsync.when(
      data: (downloads) {
        if (downloads.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.download_for_offline_outlined,
                  size: 64,
                  color: Theme.of(context).dividerColor,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.noDownloadsYet,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          );
        }

        // Grouping logic
        final Map<String, List<DownloadItem>> grouped = {};
        final List<String> keys = [];

        for (final item in downloads) {
          final String key = item.item.tmdbId?.toString() ?? item.item.title;
          if (!grouped.containsKey(key)) {
            keys.add(key);
            grouped[key] = [];
          }
          grouped[key]!.add(item);
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: keys.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final key = keys[index];
            final groupItems = grouped[key]!;

            if (groupItems.length == 1) {
              final download = groupItems.first;
              final trackingUrl = download.task.metaData;
              final progressData = activeProgress[trackingUrl];
              final double displayProgress =
                  progressData?.progress ?? download.progress;
              final TaskStatus displayStatus =
                  progressData?.status ?? download.status;

              return _DownloadItemTile(
                item: download,
                progress: displayProgress,
                status: displayStatus,
                progressData: progressData,
              );
            } else {
              return _GroupedDownloadTile(
                items: groupItems,
                activeProgress: activeProgress,
              );
            }
          },
        );
      },
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (err, stack) =>
          Center(child: Text(l10n.errorPrefix(err.toString()))),
    );
  }
}

class _GroupedDownloadTile extends ConsumerWidget {
  final List<DownloadItem> items;
  final Map<String, DownloadProgressData> activeProgress;

  const _GroupedDownloadTile({
    required this.items,
    required this.activeProgress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final firstItem = items.first;

    // Calculate overall progress or status
    final completedCount = items.where((i) {
      final status = activeProgress[i.task.metaData]?.status ?? i.status;
      return status == TaskStatus.complete;
    }).length;

    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LayoutConstants.radiusXl),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        tilePadding: const EdgeInsets.symmetric(
          horizontal: LayoutConstants.spacingMd,
          vertical: LayoutConstants.spacingXs,
        ),
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(LayoutConstants.radiusMd),
              child: CachedNetworkImage(
                imageUrl:
                    AppImageFallbacks.poster(
                      firstItem.item.posterUrl,
                      label: firstItem.item.title,
                    ) ??
                    '',
                width: 80,
                height: 120,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  width: 80,
                  height: 120,
                  color: theme.dividerColor,
                  child: const Icon(Icons.movie_outlined),
                ),
              ),
            ),
            const SizedBox(width: LayoutConstants.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firstItem.item.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.library_books_rounded,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.episodesCount(items.length, completedCount),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: LayoutConstants.spacingSm),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _confirmDeleteAll(context, ref),
              color: theme.colorScheme.error.withValues(alpha: 0.8),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        children: items.asMap().entries.map((entry) {
          final download = entry.value;
          final isLast = entry.key == items.length - 1;

          final trackingUrl = download.task.metaData;
          final progressData = activeProgress[trackingUrl];
          final double displayProgress =
              progressData?.progress ?? download.progress;
          final TaskStatus displayStatus =
              progressData?.status ?? download.status;

          return Column(
            children: [
              if (entry.key == 0)
                Divider(
                  height: 1,
                  color: theme.dividerColor.withValues(alpha: 0.4),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: LayoutConstants.spacingMd,
                  vertical: LayoutConstants.spacingSm,
                ),
                child: _DownloadItemTile(
                  item: download,
                  progress: displayProgress,
                  status: displayStatus,
                  progressData: progressData,
                  isInsideGroup: true,
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: LayoutConstants.spacingMd,
                  endIndent: LayoutConstants.spacingMd,
                  color: theme.dividerColor.withValues(alpha: 0.4),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _confirmDeleteAll(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteAllEpisodes),
        content: Text(
          l10n.confirmDeleteAllEpisodes(items.length, items.first.item.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(downloadsProvider.notifier).removeDownloads(items);
            },
            child: Text(
              l10n.deleteAll,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadItemTile extends ConsumerWidget {
  final DownloadItem item;
  final double progress;
  final TaskStatus status;
  final DownloadProgressData? progressData;
  final bool isInsideGroup;

  const _DownloadItemTile({
    required this.item,
    required this.progress,
    required this.status,
    this.progressData,
    this.isInsideGroup = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDone = status == TaskStatus.complete;
    final isWorking =
        status == TaskStatus.running || status == TaskStatus.enqueued;
    final isPaused = status == TaskStatus.paused;

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Poster
        ClipRRect(
          borderRadius: BorderRadius.circular(LayoutConstants.radiusMd),
          child: CachedNetworkImage(
            imageUrl:
                AppImageFallbacks.poster(
                  item.item.posterUrl,
                  label: item.item.title,
                ) ??
                '',
            width: 80,
            height: 120,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => Container(
              width: 80,
              height: 120,
              color: theme.dividerColor,
              child: const Icon(Icons.movie_outlined),
            ),
          ),
        ),
        const SizedBox(width: LayoutConstants.spacingMd),
        // Details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (isInsideGroup && item.episode != null)
                    ? 'S${item.episode!.season} E${item.episode!.episode}: ${item.episode!.name}'
                    : item.item.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (!isInsideGroup &&
                  item.episode != null &&
                  (item.item.contentType == MultimediaContentType.series ||
                      item.item.contentType ==
                          MultimediaContentType.anime)) ...[
                const SizedBox(height: 2),
                Text(
                  'S${item.episode!.season} E${item.episode!.episode}: ${item.episode!.name}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    isDone
                        ? Icons.check_circle_rounded
                        : Icons.download_rounded,
                    size: 14,
                    color: isDone
                        ? Colors.green
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isDone ? l10n.completed : _getStatusText(status, l10n),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDone
                          ? Colors.green
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: LayoutConstants.spacingSm),
              if (!isDone) ...[
                Row(
                  textDirection: TextDirection.ltr,
                  children: [
                    Expanded(
                      child: Text(
                        _downloadedSizeText(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.start,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: LayoutConstants.spacingSm),
                    Text(
                      '${(progress.clamp(0.0, 1.0) * 100).floor()}%',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(LayoutConstants.radiusSm),
                ),
                const SizedBox(height: 4),
                if (progressData != null && isWorking)
                  Text(
                    progressData!.speedString,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
              // Actions Row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isWorking)
                    IconButton(
                      icon: const Icon(Icons.pause_rounded),
                      onPressed: () => ref
                          .read(downloadsProvider.notifier)
                          .pauseDownload(item.task.taskId),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (isPaused)
                    IconButton(
                      icon: const Icon(Icons.play_arrow_rounded),
                      onPressed: () => ref
                          .read(downloadsProvider.notifier)
                          .resumeDownload(item.task.taskId),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (isDone)
                    IconButton(
                      icon: const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.green,
                      ),
                      onPressed: () => _playLocalFile(context, ref, l10n),
                      iconSize: 28,
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => _confirmDelete(context, ref, l10n),
                    color: theme.colorScheme.error.withValues(alpha: 0.8),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final tile = InkWell(
      onTap: isDone ? () => _playLocalFile(context, ref, l10n) : null,
      borderRadius: BorderRadius.circular(LayoutConstants.radiusLg),
      child: content,
    );

    if (isInsideGroup) {
      return tile;
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LayoutConstants.radiusXl),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(LayoutConstants.spacingMd),
        child: tile,
      ),
    );
  }

  String _downloadedSizeText() {
    final data = progressData;
    return formatDownloadSizePair(
      totalBytes: data?.totalSize ?? -1,
      progress: progress,
    );
  }

  String _getStatusText(TaskStatus status, AppLocalizations l10n) {
    switch (status) {
      case TaskStatus.enqueued:
        return l10n.statusQueued;
      case TaskStatus.running:
        return l10n.statusDownloading;
      case TaskStatus.complete:
        return l10n.statusFinished;
      case TaskStatus.failed:
        return l10n.statusFailed;
      case TaskStatus.canceled:
        return l10n.statusCanceled;
      case TaskStatus.paused:
        return l10n.statusPaused;
      default:
        return l10n.statusWaiting;
    }
  }

  Future<void> _playLocalFile(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final downloadService = ref.read(downloadServiceProvider);
    final File? file = await downloadService.getDownloadedFile(
      item.item,
      episode: item.episode,
    );

    if (file == null || !await file.exists()) {
      if (context.mounted) {
        ref.read(notificationServiceProvider).showError(
          l10n.fileNotFoundRemoving,
          title: 'Downloads',
          icon: Icons.folder_off_rounded,
        );
      }
      // Self-delete from DB
      await ref.read(downloadsProvider.notifier).removeDownload(item);
      return;
    }

    if (context.mounted) {
      unawaited(
        ref
            .read(playbackLauncherProvider)
            .play(
              context,
              file.path,
              baseItem: item.item,
              episode: item.episode,
            ),
      );
    }
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteDownload),
        content: Text(l10n.confirmDeleteDownload),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(downloadsProvider.notifier).removeDownload(item);
            },
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
