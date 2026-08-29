/// Turning a `PlayerRouteExtra` into something an engine can actually open.
///
/// This exists because `PlayerRouteExtra.videoUrl` is **not a URL**. It is an
/// opaque token handed to the active plugin's `loadStreams()`, and plugins are
/// free to put anything in it — an episode page, a `tmdb:` id, or a JSON array
/// of candidate sources. Phase 5's VlcPlayerScreen assumed it was a URI and
/// called `Uri.parse` on it, which threw a FormatException the first time a
/// real plugin stream was played:
///
///     [{"source":"https://…","quality":"480p"},{"source":…}]
///
/// Resolution is entirely engine-agnostic — it ends at a [StreamResult], and
/// nothing here knows or cares whether libVLC, libmpv or ExoPlayer opens it.
/// So it lives here rather than in either player, and both can share it.
///
/// The old PlayerController still has its own private copies of these steps
/// (`_handleSpecialProviders`, `_resolveProvider`, `_processStreams`,
/// `_findSavedStreamIndex`, `_findFirstWorkingStream`,
/// `_isStreamCandidateHealthy`). They are deliberately left alone: that
/// controller is deleted in Phase 8, and refactoring 5,000 lines of shipping
/// playback mid-migration buys nothing that deleting it will not.
library;

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart'
    show ProviderListenable;
import 'package:http/http.dart' as http;

import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/extensions/base_provider.dart';
import '../../../core/extensions/extension_manager.dart';
import '../../../core/extensions/providers.dart';
import '../../../core/storage/history_repository.dart';
import '../../../core/network/http_defaults.dart';
import '../../../core/utils/app_utils.dart';
import '../../../core/utils/stream_quality_sorter.dart';
import '../../library/presentation/history_provider.dart';
import '../../settings/presentation/player_settings_provider.dart';

/// Just enough of Riverpod to read providers. Both `Ref.read` and
/// `WidgetRef.read` satisfy this, so the resolver can be called from a
/// Notifier or straight from a widget without caring which it got.
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// A resolved, ordered candidate list plus the one to open first.
class ResolvedPlayback {
  const ResolvedPlayback({
    required this.streams,
    required this.index,
    this.qualityFilteredFallback = false,
  });

  /// Quality-filtered and sorted, best first. Never empty.
  final List<StreamResult> streams;

  /// Index into [streams] of the stream to play. Later indices are the
  /// failover order.
  final int index;

  /// The quality filter matched nothing and was dropped, so [streams] is
  /// unfiltered. Callers may want to say so.
  final bool qualityFilteredFallback;

  StreamResult get selected => streams[index];
}

/// The identity a stream must present on the network.
///
/// Shared so that every request about one stream looks like the same client.
/// A CDN that ties a signed URL to the requesting agent will 403 if the probe,
/// the licence fetch and the engine disagree — and libVLC's own default
/// User-Agent is rejected outright by many of them.
Map<String, String> playbackHeaders(StreamResult stream) {
  final headers = <String, String>{...?stream.headers};
  final hasUserAgent = headers.keys.any((k) => k.toLowerCase() == 'user-agent');
  if (!hasUserAgent) headers['User-Agent'] = kDefaultBrowserUserAgent;
  return headers;
}

/// Turns a resolved candidate into a URL an engine can actually open.
///
/// Only torrents need work: a `magnet:` link or a `.torrent` is not something
/// any player opens directly. The torrent service downloads and seeds it, then
/// serves it over loopback HTTP, and the engine plays that.
///
/// Engine-agnostic like the rest of this file - the result is a plain URL, and
/// the loopback hop means no headers are involved. Lifted out of
/// `PlayerController._resolveStreamUrl` so both engines share one
/// implementation rather than the VLC path growing a second copy.
///
/// Returns null when the torrent could not be prepared, which the caller should
/// surface rather than pass to the engine.
Future<String?> playableUrlFor({
  required ProviderReader read,
  required StreamResult stream,
}) async {
  if (isTorrentSource(stream)) {
    return read(torrentServiceProvider).getStreamUrl(stream.url);
  }
  return AppUtils.normalizeUrl(stream.url);
}

/// Whether this candidate has to go through the torrent service first.
///
/// The path check is deliberately narrowed by [StreamResult.source]: a bare
/// absolute path is normally a local file, and only a torrent-sourced one is a
/// seeded file the service already knows about.
bool isTorrentSource(StreamResult stream) =>
    stream.url.startsWith('magnet:') ||
    stream.url.endsWith('.torrent') ||
    (stream.url.startsWith('/') && stream.source.contains('Torrent'));

/// Whether this source should be treated as live.
///
/// Mirrors the old controller's `_isLiveStream`: the item's own content type
/// wins, then the URL scheme. Torrents and local files are always VOD however
/// they are labelled.
///
/// Liveness changes buffering, seeking, progress writing and what end-of-media
/// means, so it is decided once from data both engines can see rather than
/// waiting for the engine to report it.
bool isLiveSource(MultimediaItem item, String url) {
  if (url.isEmpty) return item.contentType == MultimediaContentType.livestream;
  final lower = url.toLowerCase();
  if (lower.startsWith('magnet:') ||
      lower.endsWith('.torrent') ||
      lower.startsWith('/')) {
    return false;
  }
  if (item.contentType == MultimediaContentType.livestream) return true;
  return lower.startsWith('rtmp://') ||
      lower.startsWith('rtsp://') ||
      lower.startsWith('mms://') ||
      lower.startsWith('udp://') ||
      lower.startsWith('rtp://');
}

/// Resolution failed in a way worth showing the user.
class StreamResolutionException implements Exception {
  const StreamResolutionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Resolves [videoUrl] for [item] into playable streams.
///
/// [preloadedStreams] short-circuits the plugin call — the source sheets
/// aggregate across plugins before navigating and pass the result through.
///
/// [probeCandidates] health-checks that many of the top candidates in parallel
/// and returns the first healthy one, so a dead link fails over before the
/// engine ever sees it instead of spinning on a connect timeout. Pass 0 to
/// skip probing.
Future<ResolvedPlayback> resolvePlayback({
  required ProviderReader read,
  required MultimediaItem item,
  required String videoUrl,
  List<StreamResult>? preloadedStreams,
  int probeCandidates = 3,
  bool Function()? isCancelled,
}) async {
  final direct = _directStream(item, videoUrl);
  if (direct != null) {
    return ResolvedPlayback(streams: [direct], index: 0);
  }

  final preloaded = preloadedStreams ?? const <StreamResult>[];
  final provider = _resolveProvider(read, item);
  if (provider == null && preloaded.isEmpty) {
    throw const StreamResolutionException('No provider selected.');
  }
  if (videoUrl.isEmpty && preloaded.isEmpty) {
    throw const StreamResolutionException('Nothing to play.');
  }

  List<StreamResult> raw;
  if (preloaded.isNotEmpty) {
    raw = preloaded;
  } else {
    try {
      raw = await provider!.loadStreams(videoUrl);
    } catch (e) {
      throw StreamResolutionException('Could not load sources: $e');
    }
  }
  if (isCancelled?.call() ?? false) {
    throw const StreamResolutionException('Cancelled.');
  }
  if (raw.isEmpty) {
    throw const StreamResolutionException('No streams found.');
  }

  var didFallback = false;
  final settings = await _playerSettings(read);
  final streams = settings == null
      ? raw
      : await _byQuality(raw, settings, (v) => didFallback = v);
  if (streams.isEmpty) {
    throw const StreamResolutionException('No streams found.');
  }

  final saved = _savedStreamIndex(read, item, streams);
  final index = probeCandidates <= 1
      ? saved
      : await _firstHealthyStream(
          streams,
          startIndex: saved,
          limit: probeCandidates,
          isCancelled: isCancelled,
        );

  return ResolvedPlayback(
    streams: streams,
    index: index,
    qualityFilteredFallback: didFallback,
  );
}

/// Local files, remote casts and torrents are already playable and never go
/// through a plugin.
StreamResult? _directStream(MultimediaItem item, String videoUrl) {
  final isTorrent =
      item.provider == 'Torrent' ||
      videoUrl.startsWith('magnet:') ||
      videoUrl.endsWith('.torrent');
  final isDirect =
      item.provider == 'Remote' ||
      item.provider == 'Local' ||
      AppUtils.isLocalFile(videoUrl);

  if (!isTorrent && !isDirect) return null;
  return StreamResult(
    url: videoUrl,
    source: isTorrent ? 'Torrent' : 'Video',
    providerName: item.provider ?? 'Local',
    headers: const {},
  );
}

SkyStreamProvider? _resolveProvider(ProviderReader read, MultimediaItem item) {
  final active = read(activeProviderProvider);
  final wanted = item.provider;
  if (wanted != null) {
    final match = read(extensionManagerProvider.notifier)
        .getAllProviders()
        .firstWhereOrNull((p) => p.packageName == wanted || p.name == wanted);
    if (match != null) return match;
  }
  return active;
}

/// Settings can still be loading when playback starts. Silently skipping the
/// quality preference for that window would make the chosen source depend on
/// how warm the cache was, so wait for it instead.
Future<PlayerSettings?> _playerSettings(ProviderReader read) async {
  final snapshot = read(playerSettingsProvider);
  final data = snapshot.asData;
  if (data != null) return data.value;
  try {
    return await read(playerSettingsProvider.future);
  } catch (_) {
    return null;
  }
}

/// Wi-Fi → wifiQuality, mobile → mobileQuality. If the filter leaves nothing it
/// is dropped rather than failing playback, and [onFallback] reports that.
Future<List<StreamResult>> _byQuality(
  List<StreamResult> streams,
  PlayerSettings settings,
  void Function(bool) onFallback,
) async {
  final preference = await isOnWifi()
      ? settings.wifiQuality
      : settings.mobileQuality;
  final filtered = filterStreamsByQuality(
    streams,
    preference,
    settings.qualityFilterMode,
    onFallback: onFallback,
  );
  return sortStreamsByQuality(filtered, preference);
}

/// The source the user last watched this title on, so switching episodes keeps
/// the working provider instead of re-picking from scratch.
int _savedStreamIndex(
  ProviderReader read,
  MultimediaItem item,
  List<StreamResult> streams,
) {
  try {
    final isSeries =
        item.contentType == MultimediaContentType.series ||
        item.contentType == MultimediaContentType.anime;

    String? lastUrl;
    if (isSeries) {
      lastUrl = read(historyRepositoryProvider).getLastStreamUrl(item.url);
    }
    lastUrl ??= read(watchHistoryProvider)
        .firstWhereOrNull((h) => h.item.url == item.url)
        ?.lastStreamUrl;

    if (lastUrl != null) {
      final found = streams.indexWhere((s) => s.url == lastUrl);
      if (found != -1) return found;
    }
  } catch (e) {
    if (kDebugMode) debugPrint('resolvePlayback: saved stream lookup: $e');
  }
  return 0;
}

/// Probes the top [limit] candidates at once and resolves as soon as the
/// highest-priority healthy one is known — with [0,1,2], a healthy 0 returns
/// immediately rather than waiting on 1 and 2. Falls back to [startIndex] if
/// they all fail, so a wrong probe never blocks playback outright.
Future<int> _firstHealthyStream(
  List<StreamResult> streams, {
  required int startIndex,
  required int limit,
  bool Function()? isCancelled,
}) async {
  if (streams.isEmpty) return 0;
  final start = startIndex.clamp(0, streams.length - 1);

  final candidates = <int>[];
  for (var i = 0; i < limit; i++) {
    final idx = (start + i) % streams.length;
    if (!candidates.contains(idx)) candidates.add(idx);
  }
  if (candidates.length <= 1) return start;

  final completer = Completer<int>();
  final results = <int, bool>{};

  void record(int idx, bool healthy) {
    if (completer.isCompleted) return;
    results[idx] = healthy;
    for (final c in candidates) {
      if (!results.containsKey(c)) return; // a better one is still in flight
      if (results[c]!) {
        completer.complete(c);
        return;
      }
    }
    completer.complete(start); // everything failed
  }

  for (final idx in candidates) {
    unawaited(
      _isHealthy(streams[idx])
          .then((h) => record(idx, h))
          .catchError((_) => record(idx, false)),
    );
  }

  final winner = await completer.future;
  if (isCancelled?.call() ?? false) return start;
  return winner;
}

/// HEAD first, then a one-byte ranged GET for servers that reject HEAD.
Future<bool> _isHealthy(StreamResult stream) async {
  if (stream.url.startsWith('magnet:') ||
      stream.url.endsWith('.torrent') ||
      stream.url.startsWith('/')) {
    return true;
  }

  final uri = Uri.tryParse(stream.url);
  if (uri == null || !uri.hasScheme) return false;
  final headers = playbackHeaders(stream);

  try {
    final resp = await http
        .head(uri, headers: headers)
        .timeout(const Duration(seconds: 3));
    if (resp.statusCode < 400) return true;
  } catch (_) {
    // Fall through to the ranged GET.
  }

  final client = http.Client();
  try {
    final request = http.Request('GET', uri);
    request.headers.addAll(headers);
    request.headers.putIfAbsent('Range', () => 'bytes=0-0');
    final resp = await client.send(request).timeout(const Duration(seconds: 3));
    await resp.stream.listen((_) {}).cancel();
    return resp.statusCode < 400 || resp.statusCode == 416;
  } catch (_) {
    return false;
  } finally {
    client.close();
  }
}
