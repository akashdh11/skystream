import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../services/torrent_service.dart';
import '../models/addon_stream_source.dart';
import 'debrid_service.dart';

part 'addon_playback_resolver.g.dart';

@Riverpod(keepAlive: true)
AddonPlaybackResolver addonPlaybackResolver(Ref ref) =>
    AddonPlaybackResolver(ref);

class ResolvedAddonPlayback {
  final String url;
  final Map<String, String>? headers;
  final bool viaTorrent;
  final bool viaDebrid;

  const ResolvedAddonPlayback({
    required this.url,
    this.headers,
    this.viaTorrent = false,
    this.viaDebrid = false,
  });
}

class AddonPlaybackException implements Exception {
  final String message;
  const AddonPlaybackException(this.message);
  @override
  String toString() => message;
}

/// Turns an add-on stream descriptor into something the player can open.
///
/// * `url`      → used as-is, with `behaviorHints.proxyHeaders`
/// * `infoHash` → magnet (with the add-on's trackers) handed to the bundled
///   torrent server, honouring `fileIdx` for season packs
/// * `ytId` / `externalUrl` → returned for the caller to open externally
class AddonPlaybackResolver {
  AddonPlaybackResolver(this._ref);

  /// Only used to reach the debrid settings/service — the torrent server is a
  /// plain singleton and needs no provider lookup.
  final Ref _ref;

  Future<ResolvedAddonPlayback> resolve(
    AddonStreamSource stream, {
    void Function(String status)? onStatus,
  }) async {
    switch (stream.kind) {
      case AddonStreamKind.direct:
        return ResolvedAddonPlayback(
          url: stream.url!,
          headers: stream.proxyHeaders,
        );

      case AddonStreamKind.torrent:
        final magnet = stream.magnetUri;
        if (magnet == null) {
          throw const AddonPlaybackException('Torrent link is incomplete.');
        }

        // A debrid account turns a torrent into an instant HTTPS link. If the
        // torrent isn't cached there (null) or the call fails, fall through to
        // peer-to-peer streaming rather than failing the playback.
        if (_ref.read(debridSettingsProvider).isConfigured) {
          try {
            final link = await _ref
                .read(debridServiceProvider)
                .resolveMagnet(
                  magnet,
                  preferredFilename: stream.filename,
                  onStatus: onStatus,
                );
            if (link != null) {
              return ResolvedAddonPlayback(url: link.url, viaDebrid: true);
            }
            onStatus?.call('Not cached on debrid — using peers…');
          } catch (error) {
            if (kDebugMode)
              debugPrint('[AddonPlaybackResolver] debrid: $error');
            onStatus?.call('Debrid unavailable — using peers…');
          }
        }

        onStatus?.call('Starting torrent engine…');
        final torrent = TorrentService();
        final playUrl = await torrent.getStreamUrl(magnet);
        if (playUrl == null) {
          throw const AddonPlaybackException(
            'Could not start the torrent stream. Try another source.',
          );
        }

        final fileIdx = stream.fileIdx;
        if (fileIdx != null && fileIdx >= 0) {
          onStatus?.call('Selecting file $fileIdx…');
          try {
            final indexed = await torrent.getStreamUrlForFileIndex(fileIdx);
            if (indexed != null && indexed.isNotEmpty) {
              return ResolvedAddonPlayback(url: indexed, viaTorrent: true);
            }
          } catch (error) {
            if (kDebugMode) {
              debugPrint('[AddonPlaybackResolver] fileIdx failed: $error');
            }
          }
        }
        return ResolvedAddonPlayback(url: playUrl, viaTorrent: true);

      case AddonStreamKind.youtube:
        return ResolvedAddonPlayback(
          url: 'https://www.youtube.com/watch?v=${stream.ytId}',
        );

      case AddonStreamKind.external:
        return ResolvedAddonPlayback(url: stream.externalUrl!);

      case AddonStreamKind.unknown:
        throw const AddonPlaybackException(
          'This source contains nothing playable.',
        );
    }
  }
}
