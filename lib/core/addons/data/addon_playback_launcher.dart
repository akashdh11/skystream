import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/entity/multimedia_item.dart';
import '../models/addon_stream_source.dart';

part 'addon_playback_launcher.g.dart';

@Riverpod(keepAlive: true)
AddonStreamConverter addonStreamConverter(Ref ref) =>
    const AddonStreamConverter();

/// Maps add-on stream descriptors onto the app's own [StreamResult] model, so
/// add-on links can be played by the built-in player with every feature it
/// has — including its torrent handling, which understands magnet URLs.
class AddonStreamConverter {
  const AddonStreamConverter();

  /// [selected] is moved to the front so the built-in player starts on the
  /// row the user tapped, while the rest stay available in its Sources menu.
  List<StreamResult> toStreamResults(
    List<AddonStreamSource> sources, {
    AddonStreamSource? selected,
  }) {
    final ordered = <AddonStreamSource>[
      ?selected,
      ...sources.where((s) => s.dedupeKey != selected?.dedupeKey),
    ];

    final out = <StreamResult>[];
    for (final source in ordered) {
      final url = source.url ?? source.magnetUri;
      if (url == null || url.isEmpty) continue;
      out.add(
        StreamResult(
          url: url,
          source: describe(source),
          providerName: source.addonName,
          headers: source.proxyHeaders,
          subtitles: source.subtitles.isEmpty
              ? null
              : [
                  for (final sub in source.subtitles)
                    SubtitleFile(url: sub.url, label: sub.label, lang: sub.lang),
                ],
        ),
      );
    }
    return out;
  }

  /// Label shown in the player's Sources list.
  String describe(AddonStreamSource source) {
    final parts = <String>[
      source.qualityLabel,
      if (source.isHdr) 'HDR',
      if (source.isTorrent) 'Torrent',
      if (source.isCachedDebrid) 'Cached',
      if (source.sizeLabel != null) source.sizeLabel!,
      if (source.seeders != null) '${source.seeders} seeds',
    ];
    return parts.join(' · ');
  }

  /// Stable per-episode url the player uses for history and resume.
  String videoUrlFor({required String contentId, String? videoId}) =>
      videoId != null && videoId.isNotEmpty ? videoId : contentId;

  /// Episode wrapper carrying the add-on's own video id, so history entries
  /// line up with what the add-on will be asked for next time.
  Episode? episodeFor(Episode? episode, String? videoId) {
    if (episode == null) return null;
    if (videoId == null || videoId.isEmpty) return episode;
    return Episode(
      name: episode.name,
      url: videoId,
      season: episode.season,
      episode: episode.episode,
      description: episode.description,
      posterUrl: episode.posterUrl,
      airDate: episode.airDate,
    );
  }

  /// Debug helper: a compact JSON view of what will be handed to the player.
  String debugDump(List<StreamResult> streams) => jsonEncode([
    for (final stream in streams)
      {'source': stream.source, 'provider': stream.providerName},
  ]);
}
