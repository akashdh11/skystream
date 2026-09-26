import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/external_player_service.dart';
import '../../../core/extensions/extension_manager.dart';
import '../../../core/extensions/base_provider.dart';
import '../../../core/extensions/providers.dart';
import '../../settings/presentation/player_settings_provider.dart';

import 'package:collection/collection.dart';

import 'details_controller.dart';
import '../../../core/services/download_service.dart';
import '../../../shared/widgets/loading_dialog.dart';
import '../../../core/utils/app_utils.dart';

import 'package:skystream/l10n/generated/app_localizations.dart';

import '../../../core/services/notification_service.dart';

part 'playback_launcher.g.dart';

@Riverpod(keepAlive: true)
PlaybackLauncher playbackLauncher(Ref ref) {
  return PlaybackLauncher(ref);
}

class PlaybackLauncher {
  final Ref _ref;

  PlaybackLauncher(this._ref);

  Future<void> play(
    BuildContext context,
    String url, {
    required MultimediaItem baseItem,
    MultimediaItem? detailedItem,
    Episode? episode,
  }) async {
    final settings = await _ref.read(playerSettingsProvider.future);
    if (!context.mounted) return;

    // Smart Intercept: Check if this item/episode is downloaded
    final itemToCheck = detailedItem ?? baseItem;
    final resolvedEpisode =
        episode ?? itemToCheck.episodes?.firstWhereOrNull((e) => e.url == url);
    final downloadService = _ref.read(downloadServiceProvider);
    final localFile = await downloadService.getDownloadedFile(
      itemToCheck,
      episode: resolvedEpisode,
    );
    if (!context.mounted) return;

    final String finalUrl = AppUtils.normalizeUrl(localFile?.path ?? url);

    if (settings.preferredPlayer != null) {
      if (baseItem.url.isNotEmpty) {
        _ref
            .read(detailsControllerProvider(baseItem.url).notifier)
            .setLaunching(true);
      }
      await _launchExternal(
        context,
        finalUrl,
        detailedItem ?? baseItem,
        settings.preferredPlayer!,
      ).whenComplete(() {
        if (baseItem.url.isNotEmpty) {
          _ref
              .read(detailsControllerProvider(baseItem.url).notifier)
              .setLaunching(false);
        }
      });
    } else {
      await _openInternal(
        context,
        detailedItem ?? baseItem,
        finalUrl,
        episode: resolvedEpisode,
      );
    }
  }

  /// Opens an already-resolved link in whichever player the user chose.
  ///
  /// [play] is for a URL that still has to go through a provider; this is for
  /// the source sheets, which have done that themselves. [streams] is the
  /// picker's list with the tapped row first: an external player only ever
  /// receives that first entry, the internal one keeps the rest as failover
  /// candidates. Callers with nothing resolved — a livestream whose item URL
  /// is the link — pass an empty list and a playable [videoUrl].
  Future<void> playResolved(
    BuildContext context, {
    required MultimediaItem item,
    required String videoUrl,
    Episode? episode,
    List<StreamResult> streams = const <StreamResult>[],
  }) async {
    // Read through the snapshot when the provider is already warm. Callers pop
    // themselves before handing over, and an await here would resume against a
    // context on its way out.
    final PlayerSettings settings =
        _ref.read(playerSettingsProvider).value ??
        await _ref.read(playerSettingsProvider.future);
    if (!context.mounted) return;

    final playerId = settings.preferredPlayer;
    if (playerId == null) {
      await _openInternal(
        context,
        item,
        videoUrl,
        episode: episode,
        preloadedStreams: streams,
      );
      return;
    }

    await _launchStream(
      context,
      streams.isEmpty
          ? StreamResult(url: videoUrl, source: 'Direct')
          : streams.first,
      item,
      videoUrl,
      playerId,
      episode: episode,
      preloadedStreams: streams,
    );
  }

  /// Hands [videoUrl] to the built-in player.
  ///
  /// Every fallback in this class ends here, so a stream list resolved once is
  /// not thrown away when the external hand-off is the thing that failed.
  Future<void> _openInternal(
    BuildContext context,
    MultimediaItem item,
    String videoUrl, {
    Episode? episode,
    List<StreamResult> preloadedStreams = const <StreamResult>[],
  }) {
    return PlayerRoute(
      $extra: PlayerRouteExtra(
        item: item,
        videoUrl: videoUrl,
        episode: episode,
        preloadedStreams: preloadedStreams.isEmpty ? null : preloadedStreams,
      ),
    ).push<void>(context);
  }

  Future<void> _launchExternal(
    BuildContext context,
    String episodeDataUrl,
    MultimediaItem item,
    String playerId,
  ) async {
    // If it's a local file, we can skip stream resolution
    if (AppUtils.isLocalFile(episodeDataUrl)) {
      final stream = StreamResult(url: episodeDataUrl, source: 'Local');
      await _launchStream(context, stream, item, episodeDataUrl, playerId);
      return;
    }

    bool isCanceled = false;
    bool dialogDismissed = false;
    unawaited(
      LoadingDialog.show(
        context,
        message: AppLocalizations.of(context)!.resolving,
        onCancel: () {
          isCanceled = true;
          dialogDismissed = true;
        },
      ),
    );

    try {
      final manager = _ref.read(extensionManagerProvider.notifier);
      SkyStreamProvider? provider;
      if (item.provider != null) {
        try {
          final val = item.provider!;
          provider = manager.getAllProviders().firstWhere(
            (p) => p.packageName == val || p.name == val,
          );
        } catch (e) {
          if (kDebugMode) debugPrint('PlaybackLauncher.launch: $e');
        }
      }
      provider ??= _ref.read(activeProviderProvider);
      if (provider == null) throw Exception('No active provider');

      final streams = await provider.loadStreams(episodeDataUrl);
      if (isCanceled || !context.mounted) return;

      if (!dialogDismissed) {
        Navigator.of(context).pop(); // Dismiss loading dialog
        dialogDismissed = true;
      }

      if (streams.isEmpty) {
        final playerName =
            ExternalPlayerService.instance
                .getPlayerById(playerId)
                ?.displayName ??
            playerId;
        _ref
            .read(notificationServiceProvider)
            .showError(
              AppLocalizations.of(context)!.playerNotDetected(playerName),
              title: playerName,
              icon: Icons.play_circle_outline_rounded,
            );
        unawaited(_openInternal(context, item, episodeDataUrl));
        return;
      }

      if (streams.length == 1) {
        await _launchStream(
          context,
          streams.first,
          item,
          episodeDataUrl,
          playerId,
        );
      } else {
        if (item.url.isNotEmpty) {
          _ref
              .read(detailsControllerProvider(item.url).notifier)
              .setLaunching(false);
        }
        _showSourcePicker(context, streams, item, episodeDataUrl, playerId);
      }
    } catch (e) {
      if (!context.mounted) return;
      if (!isCanceled && !dialogDismissed) {
        Navigator.of(context).pop(); // Dismiss if still there
        dialogDismissed = true;
      }
      _ref
          .read(notificationServiceProvider)
          .showError(
            AppLocalizations.of(context)!
                .usingInternalPlayerError(e.toString()),
            title: 'Playback Fallback',
            icon: Icons.play_circle_outline_rounded,
          );
      unawaited(_openInternal(context, item, episodeDataUrl));
    }
  }

  Future<void> _launchStream(
    BuildContext context,
    StreamResult stream,
    MultimediaItem item,
    String episodeDataUrl,
    String playerId, {
    Episode? episode,
    List<StreamResult> preloadedStreams = const <StreamResult>[],
  }) async {
    final service = ExternalPlayerService.instance;
    final player = service.getPlayerById(playerId);
    final playerName = player?.displayName ?? playerId;

    // A scraped link that only answers to its Referer, User-Agent or Cookie
    // is not guaranteed to survive every hand-off: the desktop CLIs take
    // only what their flags admit, and the Android intent attaches the
    // headers as extras the receiving player may or may not honour. Say
    // what cannot be guaranteed here, before the hand-off — but warn only.
    // The setting names an external player, so that player still gets the
    // attempt; the built-in one takes over only if the launch fails.
    final dropped = player == null
        ? const <String>[]
        : service.unsupportedHeaders(player, stream.headers);
    if (dropped.isNotEmpty) {
      _ref
          .read(notificationServiceProvider)
          .showError(
            AppLocalizations.of(
              context,
            )!.externalPlayerCannotSendHeaders(playerName, dropped.join(', ')),
            title: playerName,
            icon: Icons.play_circle_outline_rounded,
          );
    }

    // Scrapers occasionally emit links padded with whitespace, and the URL
    // is the whole request the other app makes — it goes out trimmed.
    String playUrl = stream.url.trim();
    if (playUrl.startsWith("magnet:") ||
        playUrl.endsWith(".torrent") ||
        (playUrl.startsWith("/") && stream.source.contains("Torrent"))) {
      final torrentUrl = await _ref
          .read(torrentServiceProvider)
          .getStreamUrl(playUrl);
      if (torrentUrl != null) {
        playUrl = torrentUrl;
      }
    }

    final success = await service.launch(
      playUrl,
      headers: stream.headers,
      playerId: playerId,
      title: item.title,
    );

    if (!success && context.mounted) {
      // When the warning above already explained why the hand-off is
      // suspect, a second "not detected" toast would claim a different
      // reason for the same fallback — the silent one is the honest one.
      if (dropped.isEmpty) {
        _ref
            .read(notificationServiceProvider)
            .showError(
              AppLocalizations.of(context)!.playerNotDetected(playerName),
              title: playerName,
              icon: Icons.play_circle_outline_rounded,
            );
      }
      unawaited(
        _openInternal(
          context,
          item,
          episodeDataUrl,
          episode: episode,
          preloadedStreams: preloadedStreams,
        ),
      );
    }
  }

  void _showSourcePicker(
    BuildContext context,
    List<StreamResult> streams,
    MultimediaItem item,
    String episodeDataUrl,
    String playerId,
  ) {
    final playerName =
        ExternalPlayerService.instance.getPlayerById(playerId)?.displayName ??
        playerId;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  AppLocalizations.of(context)!
                      .selectSourceForPlayer(playerName),
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: streams.length,
                  itemBuilder: (context, index) {
                    final stream = streams[index];
                    final label = stream.source != 'Auto'
                        ? stream.source
                        : 'Source ${index + 1}';
                    final host = Uri.tryParse(stream.url)?.host ?? '';

                    return ListTile(
                      leading: const Icon(Icons.play_circle_outline),
                      title: Text(label),
                      subtitle: host.isNotEmpty ? Text(host) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        _launchStream(
                          context,
                          stream,
                          item,
                          episodeDataUrl,
                          playerId,
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
