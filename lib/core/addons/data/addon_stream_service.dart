import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/addon_manifest.dart';
import '../models/addon_stream_source.dart';
import 'addon_client.dart';

part 'addon_stream_service.g.dart';

@Riverpod(keepAlive: true)
AddonStreamService addonStreamService(Ref ref) =>
    AddonStreamService(ref.watch(addonClientProvider));

/// Everything needed to ask add-ons for links to one movie/episode.
class AddonStreamRequest {
  /// `movie` or `series`.
  final String type;

  /// The id of the meta item the user opened (`tt0111161`, `kitsu:1376`…).
  final String contentId;

  /// The exact video id published by the meta add-on for an episode
  /// (`tt0944947:1:5`). Authoritative when present.
  final String? videoId;

  final int? season;
  final int? episode;
  final String? imdbId;
  final int? tmdbId;

  const AddonStreamRequest({
    required this.type,
    required this.contentId,
    this.videoId,
    this.season,
    this.episode,
    this.imdbId,
    this.tmdbId,
  });

  bool get isEpisode => season != null && episode != null;

  /// Ordered id candidates, following ARVIO's strategy: the add-on's own id
  /// first, then IMDb, then `tmdb:` — the first one that returns links wins.
  List<String> get idCandidates {
    final ids = <String>[];

    void add(String? value) {
      final v = value?.trim();
      if (v == null || v.isEmpty || ids.contains(v)) return;
      ids.add(v);
    }

    final base = contentId.split(':').first;

    if (isEpisode) {
      add(videoId);
      if (base.isNotEmpty) add('$base:$season:$episode');
      final imdb = imdbId ?? (base.startsWith('tt') ? base : null);
      if (imdb != null) add('$imdb:$season:$episode');
      if (tmdbId != null) add('tmdb:$tmdbId:$season:$episode');
    } else {
      add(contentId);
      add(imdbId);
      if (tmdbId != null) add('tmdb:$tmdbId');
    }
    return ids;
  }
}

enum AddonQueryOutcome { pending, links, empty, failed }

class AddonQueryStatus {
  final String addonName;
  final AddonQueryOutcome outcome;
  final int linkCount;
  final String? message;

  const AddonQueryStatus({
    required this.addonName,
    required this.outcome,
    this.linkCount = 0,
    this.message,
  });
}

class AddonStreamProgress {
  final List<AddonStreamSource> streams;
  final List<AddonQueryStatus> statuses;
  final int completedCount;
  final int totalCount;
  final bool isLoading;
  final String? error;

  const AddonStreamProgress({
    this.streams = const [],
    this.statuses = const [],
    this.completedCount = 0,
    this.totalCount = 0,
    this.isLoading = false,
    this.error,
  });

  double get progress =>
      totalCount == 0 ? 0 : (completedCount / totalCount).clamp(0.0, 1.0);

  int get respondedCount =>
      statuses.where((s) => s.outcome == AddonQueryOutcome.links).length;
}

/// Queries add-ons for streams. Add-on only — nothing in this file knows the
/// plugin/extension system exists.
class AddonStreamService {
  AddonStreamService(this._client);

  final AddonClient _client;

  static const int _maxConcurrent = 6;
  static const Duration _perRequestTimeout = Duration(seconds: 18);

  /// Add-ons that can answer a `/stream` request at all. Catalog-only add-ons
  /// (Streaming Catalogs, Trakt lists…) are never asked.
  static List<ManagedAddon> streamProvidersOf(List<ManagedAddon> addons) =>
      addons
          .where((a) => a.manifest?.hasResource('stream') ?? false)
          .toList(growable: false);

  static int _compare(AddonStreamSource a, AddonStreamSource b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return a.addonName.compareTo(b.addonName);
  }

  /// Emits a snapshot every time an add-on answers, so links appear as they
  /// arrive instead of after the slowest add-on.
  Stream<AddonStreamProgress> resolve({
    required List<ManagedAddon> addons,
    required AddonStreamRequest request,
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) async* {
    final providers = streamProvidersOf(addons);

    if (providers.isEmpty) {
      yield const AddonStreamProgress(
        error:
            'No installed add-on provides streams. Add one (for example '
            'Torrentio) from the "My add-ons" tab.',
      );
      return;
    }

    final ids = request.idCandidates;
    if (ids.isEmpty) {
      yield const AddonStreamProgress(
        error: 'This title has no id that add-ons can be queried with.',
      );
      return;
    }

    final streams = <AddonStreamSource>[];
    final seen = <String>{};
    final statuses = <String, AddonQueryStatus>{
      for (final addon in providers)
        addon.manifestUrl: AddonQueryStatus(
          addonName: addon.displayName,
          outcome: AddonQueryOutcome.pending,
        ),
    };
    var completed = 0;

    final updates = StreamController<AddonStreamProgress>();

    AddonStreamProgress snapshot({bool loading = true}) {
      streams.sort(_compare);
      return AddonStreamProgress(
        streams: List.of(streams),
        statuses: statuses.values.toList(),
        completedCount: completed,
        totalCount: providers.length,
        isLoading: loading,
      );
    }

    /// One add-on: try every (id, type) combination until something answers.
    Future<void> runOne(ManagedAddon addon) async {
      final manifest = addon.manifest!;
      String? lastError;
      var added = 0;
      var attempted = false;

      outer:
      for (final id in ids) {
        if (!manifest.supportsId('stream', id)) continue;
        for (final type in manifest.requestTypesFor('stream', request.type)) {
          attempted = true;
          try {
            final results = await _client
                .streams(
                  addon,
                  type: type,
                  id: id,
                  forceRefresh: forceRefresh,
                  cancelToken: cancelToken,
                )
                .timeout(_perRequestTimeout);
            if (results.isEmpty) continue;

            for (final stream in results) {
              if (!seen.add(stream.dedupeKey)) continue;
              streams.add(stream);
              added++;
            }
            break outer;
          } catch (error) {
            lastError = error is DioException
                ? (error.message ?? error.type.name)
                : error.toString();
            if (kDebugMode) {
              debugPrint(
                '[AddonStreamService] ${addon.displayName} $type/$id: $error',
              );
            }
          }
        }
      }

      statuses[addon.manifestUrl] = AddonQueryStatus(
        addonName: addon.displayName,
        outcome: added > 0
            ? AddonQueryOutcome.links
            : (lastError != null
                  ? AddonQueryOutcome.failed
                  : AddonQueryOutcome.empty),
        linkCount: added,
        message: added > 0
            ? null
            : (lastError ??
                  (attempted
                      ? 'no links for this title'
                      : 'does not handle this id/type')),
      );
      completed++;
      if (!updates.isClosed) updates.add(snapshot());
    }

    unawaited(() async {
      final queue = List<ManagedAddon>.of(providers);
      final workers = List.generate(
        providers.length < _maxConcurrent ? providers.length : _maxConcurrent,
        (_) => Future(() async {
          while (queue.isNotEmpty) {
            await runOne(queue.removeAt(0));
          }
        }),
      );
      await Future.wait(workers);
      if (!updates.isClosed) await updates.close();
    }());

    yield snapshot();
    yield* updates.stream;

    streams.sort(_compare);
    yield AddonStreamProgress(
      streams: streams,
      statuses: statuses.values.toList(),
      completedCount: completed,
      totalCount: providers.length,
      error: streams.isEmpty
          ? 'No add-on returned links for ${ids.first}.'
          : null,
    );
  }
}
