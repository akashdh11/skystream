import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:skystream/features/library/presentation/history_provider.dart';
import '../../../../core/domain/entity/multimedia_item.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skystream/core/router/app_router.dart';
import 'package:skystream/core/addons/models/addon_meta.dart' show kAddonItemSource;
import 'package:skystream/core/utils/image_fallbacks.dart';
import 'package:skystream/core/utils/layout_constants.dart';
import '../../../../core/extensions/extension_manager.dart';
import '../../../../shared/widgets/cards_wrapper.dart';
import '../../../../shared/widgets/loading_dialog.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';
import 'package:skystream/core/services/notification_service.dart';

class ContinueWatchingCard extends ConsumerStatefulWidget {
  final HistoryItem historyItem;
  final double width;
  final bool isLarge;

  const ContinueWatchingCard({
    super.key,
    required this.historyItem,
    this.width = 280,
    this.isLarge = false,
  });

  @override
  ConsumerState<ContinueWatchingCard> createState() =>
      _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends ConsumerState<ContinueWatchingCard> {
  bool _isHovered = false;

  static String _normalizeMatchKey(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static MultimediaItem? _pickBestLiveMatch(
    Iterable<MultimediaItem> candidates,
    MultimediaItem target,
  ) {
    final normalizedTarget = _normalizeMatchKey(target.title);
    if (normalizedTarget.isEmpty) return null;

    final exactTitleMatches = candidates.where(
      (candidate) =>
          candidate.contentType == MultimediaContentType.livestream &&
          _normalizeMatchKey(candidate.title) == normalizedTarget,
    );

    if (target.posterUrl.isNotEmpty) {
      final posterMatch = exactTitleMatches.firstWhereOrNull(
        (candidate) => candidate.posterUrl == target.posterUrl,
      );
      if (posterMatch != null) return posterMatch;
    }

    return exactTitleMatches.firstOrNull;
  }

  Future<MultimediaItem?> _resolveFreshLiveItem(
    WidgetRef ref,
    MultimediaItem item,
  ) async {
    final providerId = item.provider;
    if (providerId == null || providerId.isEmpty) return null;

    final manager = ref.read(extensionManagerProvider.notifier);
    final provider = manager.getAllProviders().firstWhereOrNull(
      (p) => p.packageName == providerId || p.name == providerId,
    );
    if (provider == null) return null;

    try {
      final results = await provider.search(item.title);
      final match = _pickBestLiveMatch(results, item);
      if (match != null) {
        return match.copyWith(provider: provider.packageName);
      }
    } catch (_) {}

    try {
      final homeSections = await provider.getHome();
      final flattened = homeSections.values.expand((items) => items);
      final match = _pickBestLiveMatch(flattened, item);
      if (match != null) {
        return match.copyWith(provider: provider.packageName);
      }
    } catch (_) {}

    return null;
  }

  String _formatDuration(int milliseconds) {
    if (milliseconds <= 0) return '00:00';
    final d = Duration(milliseconds: milliseconds);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      if (m > 0) return '${h}h ${m}m';
      return '${h}h';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.historyItem.item;
    final double progress = (widget.historyItem.duration > 0)
        ? (widget.historyItem.position / widget.historyItem.duration).clamp(
            0.0,
            1.0,
          )
        : 0.0;

    final isLivestream = item.contentType == MultimediaContentType.livestream;
    final isSeries = item.contentType == MultimediaContentType.series;
    final isAnime = item.contentType == MultimediaContentType.anime;
    final hasEpisodes = isSeries || isAnime;

    final imageUrl = hasEpisodes
        ? (widget.historyItem.episodePosterUrl ?? item.backdropImageUrl)
        : item.backdropImageUrl;
    final bannerUrl = AppImageFallbacks.poster(imageUrl, label: item.title);

    final episodeLabel =
        hasEpisodes &&
            widget.historyItem.season != null &&
            widget.historyItem.episode != null &&
            (widget.historyItem.season! > 0 || widget.historyItem.episode! > 0)
        ? "S${widget.historyItem.season} E${widget.historyItem.episode}${widget.historyItem.episodeTitle != null && widget.historyItem.episodeTitle!.isNotEmpty && !widget.historyItem.episodeTitle!.startsWith("Episode") ? " - ${widget.historyItem.episodeTitle}" : ""}"
        : null;

    return CardsWrapper(
      onTap: () async {
        if (isLivestream) {
          bool dialogDismissed = false;
          bool canceled = false;
          unawaited(
            LoadingDialog.show(
              context,
              message: AppLocalizations.of(context)!.refreshingLiveStream,
              onCancel: () {
                canceled = true;
                dialogDismissed = true;
              },
            ),
          );
          final refreshedItem = await _resolveFreshLiveItem(ref, item);
          if (!context.mounted || canceled) return;

          if (!dialogDismissed) {
            Navigator.of(context, rootNavigator: true).pop();
            dialogDismissed = true;
          }

          final liveItem = refreshedItem ?? item;
          if (!context.mounted || canceled) return;

          unawaited(
            PlayerRoute(
              $extra: PlayerRouteExtra(item: liveItem, videoUrl: liveItem.url),
            ).push<void>(context),
          );
          unawaited(
            ref.read(watchHistoryProvider.notifier).removeFromHistory(item.url),
          );
          return;
        }

        // Add-on content has no plugin behind it — reopen it in the add-on
        // stack, which knows how to resolve its streams.
        if (item.source == kAddonItemSource) {
          unawaited(
            AddonDetailRoute(
              type: item.contentType == MultimediaContentType.movie
                  ? 'movie'
                  : 'series',
              id: item.url,
            ).push<void>(context),
          );
          return;
        }

        unawaited(
          DetailsRoute(
            $extra: DetailsRouteExtra(item: item, autoPlay: true),
          ).push<void>(context),
        );
      },
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
                  leading: const Icon(Icons.info_outline),
                  title: Text(AppLocalizations.of(context)!.viewDetails),
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(
                      DetailsRoute(
                        $extra: DetailsRouteExtra(item: item),
                      ).push<void>(context),
                    );
                  },
                ),
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
                  onTap: () {
                    ref
                        .read(watchHistoryProvider.notifier)
                        .removeFromHistory(item.url);
                    Navigator.pop(context);
                    ref
                        .read(notificationServiceProvider)
                        .showSuccess(
                          AppLocalizations.of(
                            context,
                          )!.removedFromHistory(item.title),
                          title: 'Watch History',
                          icon: Icons.history_rounded,
                        );
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
      borderRadius: BorderRadius.circular(LayoutConstants.radiusLg),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: SizedBox(
          width: widget.width,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(LayoutConstants.radiusLg),
            child: Stack(
              children: [
                // Banner background
                Positioned.fill(
                  child: Container(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    child: bannerUrl != null
                        ? CachedNetworkImage(
                            imageUrl: bannerUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => const SizedBox.shrink(),
                            errorWidget: (_, _, _) => const SizedBox.shrink(),
                          )
                        : null,
                  ),
                ),

                // Dark overlay (full card) — 40% at rest, 60% on hover
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      color: Colors.black.withValues(
                        alpha: _isHovered ? 0.40 : 0.20,
                      ),
                    ),
                  ),
                ),

                // Bottom scrim gradient (from-black/80 to transparent)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 64,
                  child: IgnorePointer(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),

                // Duration badge (bottom-right)
                if (!isLivestream)
                  Positioned(
                    bottom: 10,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.70),
                        borderRadius: BorderRadius.circular(
                          LayoutConstants.radiusMd,
                        ),
                      ),
                      child: Text(
                        '${_formatDuration(widget.historyItem.position)} / ${_formatDuration(widget.historyItem.duration)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                // Progress bar (bottom edge)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: 4,
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  ),
                ),

                // Bottom info column
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 24, 12, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasEpisodes || isLivestream) ...[
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        if (isLivestream)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(
                                LayoutConstants.radiusSm,
                              ),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          )
                        else
                          Text(
                            episodeLabel ?? item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
