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
  /// `movie`, `series`, `other`, `tv`, …
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

  /// Display title, used to resolve an IMDb id when the content id is an
  /// opaque scraper token (`cnc:…`) that returns empty `/stream` lists.
  final String? title;

  /// Release year hint for the Cinemeta title → IMDb lookup.
  final int? year;

  const AddonStreamRequest({
    required this.type,
    required this.contentId,
    this.videoId,
    this.season,
    this.episode,
    this.imdbId,
    this.tmdbId,
    this.title,
    this.year,
  });

  bool get isEpisode => season != null && episode != null;

  /// True when [contentId] is not a universal id (IMDb / TMDB / kitsu…) that
  /// every stream add-on understands — scraper bridges mint per-provider
  /// tokens that often 200 with an empty stream list.
  bool get hasOpaqueContentId {
    final id = contentId.trim().toLowerCase();
    if (id.isEmpty) return true;
    if (id.startsWith('tt') && RegExp(r'^tt\d').hasMatch(id)) return false;
    if (id.startsWith('tmdb:')) return false;
    if (id.startsWith('kitsu:')) return false;
    if (id.startsWith('mal:')) return false;
    if (id.startsWith('anidb:')) return false;
    if (id.startsWith('tvdb:')) return false;
    return true; // cnc:, provider-local, …
  }

  /// Ordered id candidates, following ARVIO's strategy with one fix:
  /// when the content id is a scraper token, put IMDb/TMDB FIRST so a single
  /// empty `cnc:…` answer does not burn the whole add-on budget before the
  /// id that actually has links is tried. (CNCVerse Multimovies: cnc empty
  /// in 3 s, tt30395619 → 88 links in ~27 s.)
  List<String> get idCandidates {
    final ids = <String>[];

    void add(String? value) {
      final v = value?.trim();
      if (v == null || v.isEmpty || ids.contains(v)) return;
      ids.add(v);
    }

    final base = contentId.split(':').first;
    final imdb = imdbId ?? (contentId.startsWith('tt') ? contentId.split(':').first : null);
    final opaque = hasOpaqueContentId;

    if (isEpisode) {
      if (opaque) {
        if (imdb != null) add('$imdb:$season:$episode');
        if (tmdbId != null) add('tmdb:$tmdbId:$season:$episode');
        add(videoId);
        add(contentId);
      } else {
        add(videoId);
        if (base.isNotEmpty) add('$base:$season:$episode');
        if (imdb != null) add('$imdb:$season:$episode');
        if (tmdbId != null) add('tmdb:$tmdbId:$season:$episode');
      }
    } else {
      if (opaque) {
        add(imdb);
        if (tmdbId != null) add('tmdb:$tmdbId');
        add(contentId);
      } else {
        add(contentId);
        add(imdb);
        if (tmdbId != null) add('tmdb:$tmdbId');
      }
    }
    return ids;
  }

  AddonStreamRequest copyWith({
    String? type,
    String? contentId,
    String? videoId,
    int? season,
    int? episode,
    String? imdbId,
    int? tmdbId,
    String? title,
    int? year,
  }) =>
      AddonStreamRequest(
        type: type ?? this.type,
        contentId: contentId ?? this.contentId,
        videoId: videoId ?? this.videoId,
        season: season ?? this.season,
        episode: episode ?? this.episode,
        imdbId: imdbId ?? this.imdbId,
        tmdbId: tmdbId ?? this.tmdbId,
        title: title ?? this.title,
        year: year ?? this.year,
      );
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
  AddonStreamService(
    this._client, {
    // CNCVerse live probes need ~22–27 s per /stream answer. Budget must
    // cover one successful scrape plus a short empty-id retry, without
    // letting a totally dead host hold a worker forever.
    Duration addonBudget = const Duration(seconds: 55),
    Duration requestTimeout = const Duration(seconds: 45),
  }) : _addonBudget = addonBudget,
       _requestTimeout = requestTimeout;

  final AddonClient _client;

  /// One request's ceiling. Matched to [AddonClient]'s stream receive
  /// timeout so Dio and the service agree; scraping bridges land in the
  /// low-to-mid 20 s range, empty/fast add-ons finish in under a second.
  final Duration _requestTimeout;

  /// Hard stop for everything ONE add-on may spend. Dead hosts used to chain
  /// id×alias timeouts (~160 s) and stall the queue; the budget abandons them
  /// so healthy add-ons keep answering.
  final Duration _addonBudget;

  /// Fan out every installed stream add-on at once. Partial results already
  /// stream into the sheet as each one answers — serialising them only made
  /// the slowest add-on gate everyone else. Cap is a safety net for users
  /// with huge collections; typical installs are well under it.
  static const int _maxConcurrent = 24;

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

    // Scraper-bridge titles often arrive with only a cnc: token. Resolve an
    // IMDb id from the title (Cinemeta, cached) so every stream add-on has a
    // universal id to answer — same path Stremio/Nuvio effectively take.
    var effective = request;
    if ((effective.imdbId == null || effective.imdbId!.isEmpty) &&
        effective.hasOpaqueContentId &&
        (effective.title != null && effective.title!.trim().isNotEmpty)) {
      try {
        final resolved = await _client.resolveImdbId(
          title: effective.title!,
          type: effective.type,
          year: effective.year,
          cancelToken: cancelToken,
        );
        if (resolved != null && resolved.isNotEmpty) {
          effective = effective.copyWith(imdbId: resolved);
          if (kDebugMode) {
            debugPrint(
              '[AddonStreamService] resolved IMDb $resolved '
              'for "${effective.title}"',
            );
          }
        }
      } catch (error) {
        if (kDebugMode) {
          debugPrint('[AddonStreamService] IMDb lookup failed: $error');
        }
      }
    }

    final ids = effective.idCandidates;
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

    Future<List<AddonStreamSource>> ask({
      required ManagedAddon addon,
      required String type,
      required String id,
      required Duration timeout,
    }) {
      return _client
          .streams(
            addon,
            type: type,
            id: id,
            forceRefresh: forceRefresh,
            cancelToken: cancelToken,
          )
          .timeout(timeout);
    }

    /// Try [types] for one id.
    ///
    /// The first (preferred) type is asked alone so a healthy add-on still
    /// costs exactly one request. Only if that comes back empty do the
    /// remaining aliases race in parallel — a CNCVerse `other` miss then
    /// discovers `movie` without waiting out every alias one-by-one.
    Future<List<AddonStreamSource>> typesForId({
      required ManagedAddon addon,
      required String id,
      required List<String> types,
      required Duration timeout,
    }) async {
      if (types.isEmpty) return const [];

      Object? lastError;

      try {
        final primary = await ask(
          addon: addon,
          type: types.first,
          id: id,
          timeout: timeout,
        );
        if (primary.isNotEmpty) return primary;
      } catch (error) {
        // A timeout/network error on the preferred type means the host is
        // struggling — racing aliases against the same dead socket only burns
        // the budget. Surface the failure and let the next id (or add-on)
        // take over.
        if (kDebugMode) {
          debugPrint(
            '[AddonStreamService] ${addon.displayName} '
            '${types.first}/$id: $error',
          );
        }
        throw error is Exception ? error : Exception('$error');
      }

      // Preferred type answered empty. Race the remaining aliases so a
      // CNCVerse-style `other` miss can still discover `movie` quickly.
      final rest = types.skip(1).toList(growable: false);
      if (rest.isEmpty) {
        return const [];
      }

      final completer = Completer<List<AddonStreamSource>>();
      var pending = rest.length;

      void finishEmpty() {
        if (!completer.isCompleted) {
          completer.complete(const <AddonStreamSource>[]);
        }
      }

      for (final type in rest) {
        unawaited(() async {
          try {
            final results = await ask(
              addon: addon,
              type: type,
              id: id,
              timeout: timeout,
            );
            if (results.isNotEmpty && !completer.isCompleted) {
              completer.complete(results);
              return;
            }
          } catch (error) {
            lastError = error;
            if (kDebugMode) {
              debugPrint(
                '[AddonStreamService] ${addon.displayName} $type/$id: $error',
              );
            }
          } finally {
            pending--;
            if (pending == 0) finishEmpty();
          }
        }());
      }

      final won = await completer.future;
      if (won.isEmpty && lastError != null) {
        final error = lastError!;
        throw error is Exception ? error : Exception('$error');
      }
      return won;
    }

    /// One add-on: walk id candidates in priority order. Stops at the first
    /// id that returns links, or when the per-add-on budget is spent.
    Future<void> runOne(ManagedAddon addon) async {
      final manifest = addon.manifest!;
      final stopwatch = Stopwatch()..start();
      String? lastError;
      var added = 0;
      var attempted = false;

      for (final id in ids) {
        if (!manifest.supportsId('stream', id)) continue;
        final types = manifest.requestTypesFor('stream', effective.type);
        if (types.isEmpty) continue;

        final remaining = _addonBudget - stopwatch.elapsed;
        if (remaining <= Duration.zero) {
          lastError ??= 'add-on is taking too long to answer';
          break;
        }
        attempted = true;
        final timeout = remaining < _requestTimeout
            ? remaining
            : _requestTimeout;

        try {
          final results = await typesForId(
            addon: addon,
            id: id,
            types: types,
            timeout: timeout,
          );
          if (results.isEmpty) continue;

          for (final stream in results) {
            if (!seen.add(stream.dedupeKey)) continue;
            streams.add(stream);
            added++;
          }
          break;
        } catch (error) {
          lastError = error is DioException
              ? (error.message ?? error.type.name)
              : error.toString();
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
      // Every stream add-on runs now (up to the cap). Links surface the
      // moment each one answers — the sheet never waits on the slowest
      // host before showing the fast ones.
      final queue = List<ManagedAddon>.of(providers);
      final workerCount =
          providers.length < _maxConcurrent ? providers.length : _maxConcurrent;
      final workers = List.generate(
        workerCount,
        (_) => Future(() async {
          while (true) {
            if (queue.isEmpty) return;
            final next = queue.removeAt(0);
            await runOne(next);
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
