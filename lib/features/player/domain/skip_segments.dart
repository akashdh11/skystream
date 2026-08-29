/// Fetching intro/outro skip segments for the episode being played.
///
/// Engine-agnostic: it returns a sanitized [SkipSegment] list and never touches
/// a player. Both sources are crowdsourced and opt-in — neither is enabled by
/// default — so the common answer is an empty list, and every caller must treat
/// that as normal rather than as a failure.
library;

import 'package:flutter/foundation.dart';

import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/storage/settings_repository.dart';
import '../../skip/data/anime_skip_service.dart';
import '../../skip/data/intro_db_service.dart';
import '../../skip/data/skip_service.dart';
import 'stream_resolver.dart' show ProviderReader;

/// Reads intro/outro segments for [episode] of [item].
///
/// AnimeSkip *replaces* rather than appends to IntroDB's answer when it has
/// one: it is title-specific where IntroDB is crowd-averaged, so mixing the two
/// produces overlapping segments that fight each other.
///
/// Returns an empty list on any failure. A missing segment is a missing
/// convenience, never a reason to disturb playback.
Future<List<SkipSegment>> fetchSkipSegments({
  required ProviderReader read,
  required MultimediaItem item,
  required Episode episode,
  double? durationSeconds,
}) async {
  final settings = read(settingsRepositoryProvider);
  final season = episode.season > 0 ? episode.season : 1;
  final number = episode.episode > 0 ? episode.episode : 1;

  final segments = <SkipSegment>[];

  if (settings.isIntroDbIntegrationEnabled()) {
    try {
      segments.addAll(
        await read(introDbServiceProvider).getSkipSegments(
          tmdbId: item.tmdbId,
          imdbId: item.imdbId,
          season: season,
          episode: number,
          duration: durationSeconds?.round(),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('IntroDB skip lookup failed: $e');
    }
  }

  final anilistId = _anilistId(item);
  if (anilistId != null && settings.isAnimeSkipIntegrationEnabled()) {
    try {
      final anime = await read(animeSkipServiceProvider).getSkipSegments(
        anilistId: anilistId,
        season: season,
        episode: number,
        duration: durationSeconds?.round(),
      );
      if (anime.isNotEmpty) {
        // Title-specific data beats the crowd average outright.
        segments
          ..clear()
          ..addAll(anime);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('AnimeSkip lookup failed: $e');
    }
  }

  return SkipSegment.sanitize(segments, durationSec: durationSeconds);
}

/// The AniList id, if this title has one recorded under any of the three key
/// spellings plugins use.
int? _anilistId(MultimediaItem item) {
  final sync = item.syncData;
  if (sync == null) return null;
  final raw =
      sync['anilist'] ?? sync['anilistId'] ?? sync['anilist_id'];
  return raw == null ? null : int.tryParse(raw.toString());
}

/// The segment covering [position], if any.
///
/// Segments are sorted and non-overlapping after [SkipSegment.sanitize], so the
/// first match is the only match.
SkipSegment? segmentAt(List<SkipSegment> segments, Duration position) {
  final seconds = position.inMilliseconds / 1000.0;
  for (final segment in segments) {
    if (seconds >= segment.startTime && seconds < segment.endTime) {
      return segment;
    }
  }
  return null;
}
