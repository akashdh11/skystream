import 'package:flutter/material.dart';
import 'package:skystream/features/tracking/domain/sync_progress_item.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/shared/widgets/cards_wrapper.dart';
import 'package:skystream/shared/widgets/thumbnail_error_placeholder.dart';
import 'package:skystream/core/utils/image_fallbacks.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skystream/features/tracking/data/sync_manager.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';
import 'package:skystream/core/services/notification_service.dart';

class SyncedProgressCard extends ConsumerWidget {
  final SyncProgressItem item;
  final double width;
  final bool isLarge;
  final VoidCallback onTap;

  const SyncedProgressCard({
    super.key,
    required this.item,
    required this.width,
    required this.isLarge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CardsWrapper(
      onTap: onTap,
      onLongPress: () {
        showModalBottomSheet<void>(
          context: context,
          builder: (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    AppLocalizations.of(context)!.removeFromHistory,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () async {
                    final manager = ref.read(syncManagerProvider);
                    final success = await manager.removePlaybackProgress(item);
                    if (success && context.mounted) {
                      ref.invalidate(syncedProgressProvider);
                      ref
                          .read(notificationServiceProvider)
                          .showSuccess(
                            AppLocalizations.of(
                              context,
                            )!.removedFromHistory(item.title),
                            title: 'Watch Progress',
                            icon: Icons.history_rounded,
                          );
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: Text(AppLocalizations.of(context)!.cancel),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Container(
            width: width,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                AspectRatio(
                  aspectRatio: 2 / 3,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(12),
                    ),
                    child: CachedNetworkImage(
                      imageUrl:
                          AppImageFallbacks.tmdbPoster(
                            item.posterUrl,
                            label: item.title,
                          ) ??
                          '',
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: Theme.of(context).dividerColor),
                      errorWidget: (_, _, _) =>
                          ThumbnailErrorPlaceholder(label: item.title),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 0,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.cloud_sync,
                                    size: 10,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "SYNCED",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.type.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (item.type == MultimediaContentType.series &&
                            item.season != null &&
                            item.episode != null &&
                            (item.season! > 0 || item.episode! > 0))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Text(
                              "S${item.season} E${item.episode}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (item.progressPercentage / 100.0).clamp(
                              0.0,
                              1.0,
                            ),
                            minHeight: 4,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${item.progressPercentage.toStringAsFixed(0)}% watched',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (item.id != null)
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  focusNode: FocusNode(
                    canRequestFocus: false,
                    skipTraversal: true,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final manager = ref.read(syncManagerProvider);
                    final success = await manager.removePlaybackProgress(item);
                    if (success && context.mounted) {
                      ref.invalidate(syncedProgressProvider);
                      ref
                          .read(notificationServiceProvider)
                          .showSuccess(
                            AppLocalizations.of(
                              context,
                            )!.removedFromHistory(item.title),
                            title: 'Watch Progress',
                            icon: Icons.history_rounded,
                          );
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 16, color: Colors.white70),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
