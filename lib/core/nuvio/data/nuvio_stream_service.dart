import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/nuvio_models.dart';
import 'nuvio_repository.dart';
import 'nuvio_runtime.dart';
import 'nuvio_tmdb.dart';

part 'nuvio_stream_service.g.dart';

@Riverpod(keepAlive: true)
NuvioStreamService nuvioStreamService(Ref ref) => NuvioStreamService(ref);

enum NuvioScraperOutcome { pending, running, links, empty, failed, unsupported }

class NuvioScraperStatus {
  final String scraperName;
  final NuvioScraperOutcome outcome;
  final int linkCount;
  final String? message;

  const NuvioScraperStatus({
    required this.scraperName,
    required this.outcome,
    this.linkCount = 0,
    this.message,
  });

  String get addonLabel => scraperName;
}

class NuvioProgress {
  final List<NuvioStreamResult> streams;
  final List<NuvioScraperStatus> statuses;
  final int completedCount;
  final int totalCount;
  final bool isLoading;

  const NuvioProgress({
    this.streams = const [],
    this.statuses = const [],
    this.completedCount = 0,
    this.totalCount = 0,
    this.isLoading = false,
  });

  bool get hasWork => totalCount > 0;
}

/// Bounded, self-pruning store of scraper answers.
///
/// A cache entry is one scraper's answer for one episode, and the key carries
/// the scraper id, the title, the season, the episode and a hash of that
/// scraper's settings. A session that browses a show for an hour mints a fresh
/// key per episode per scraper and nothing ever removed the expired ones, so
/// the map only grew - for the life of the process, holding every stream URL,
/// title and header map it had ever seen. Entries past [ttl] go on the next
/// write and the newest [maxEntries] survive, the same shape
/// `LocalProxyService._playlists` uses.
@visibleForTesting
class NuvioResultCache {
  NuvioResultCache({
    this.maxEntries = 120,
    this.ttl = NuvioStreamService.cacheTtl,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Roughly a dozen scrapers across ten episodes: enough that paging back to
  /// an episode watched earlier in the session still hits, small enough that
  /// the whole map is bounded by something the user can point at.
  final int maxEntries;
  final Duration ttl;
  final DateTime Function() _clock;

  final Map<String, _CacheEntry> _entries = {};

  int get length => _entries.length;

  void clear() => _entries.clear();

  /// The fresh results for [key], or null. A hit is moved to the young end so
  /// eviction drops what is genuinely least recently *used*, not merely
  /// least recently written.
  List<NuvioStreamResult>? lookup(String key) {
    final entry = _entries.remove(key);
    if (entry == null) return null;
    if (_clock().difference(entry.createdAt) >= ttl) return null;
    _entries[key] = entry;
    return entry.results;
  }

  void store(String key, List<NuvioStreamResult> results) {
    final now = _clock();
    _entries.removeWhere((_, entry) => now.difference(entry.createdAt) >= ttl);
    _entries.remove(key);
    while (_entries.length >= maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    _entries[key] = _CacheEntry(results, now);
  }
}

class _CacheEntry {
  _CacheEntry(this.results, this.createdAt);
  final List<NuvioStreamResult> results;
  final DateTime createdAt;
}

/// Runs every enabled Nuvio scraper for one title and streams results back as
/// they arrive, mirroring how the SkyStream plugin aggregator behaves so both
/// systems can feed one list.
class NuvioStreamService {
  NuvioStreamService(this._ref);

  final Ref _ref;

  /// Nuvio itself launches every scraper at once. Plugins now run on worker
  /// isolates, so eight in flight is real parallelism rather than eight jobs
  /// fighting over the UI thread — a 60-scraper repository finishes in about
  /// the time the slowest handful take, without stuttering the app.
  static const int maxConcurrent = 8;

  /// Repeat visits to the same episode shouldn't re-run 60 scrapers.
  static const Duration cacheTtl = Duration(minutes: 10);

  final NuvioResultCache _cache = NuvioResultCache();

  void clearCache() => _cache.clear();

  /// Nuvio plugins are written against a *numeric TMDB id*. Feeding them an
  /// `tt…` or `tmdb:123` id is the difference between a provider answering and
  /// silently returning nothing, so normalise (and convert) first.
  Future<String> _normalizeId(String rawId, String type) async {
    var id = rawId.trim();
    if (id.isEmpty) return id;
    if (id.startsWith('tmdb:')) id = id.substring(5);
    if (id.startsWith('tmdb/')) id = id.substring(5);
    id = id.split('/').first;
    // Stremio-style "tt1234:1:2" ids.
    final colon = id.indexOf(':');
    if (colon > 0) id = id.substring(0, colon);
    if (!id.startsWith('tt')) return id;

    try {
      final resolved = await _ref
          .read(nuvioTmdbServiceProvider)
          .tmdbIdForImdbId(id, type: type);
      if (resolved != null && resolved.isNotEmpty) return resolved;
    } catch (error) {
      if (kDebugMode) debugPrint('[Nuvio] imdb→tmdb failed for $id: $error');
    }
    return id;
  }

  Stream<NuvioProgress> resolve({
    required String tmdbId,
    required String mediaType,
    int? season,
    int? episode,
  }) async* {
    final repository = _ref.read(nuvioRepositoryProvider.notifier);
    var state = _ref.read(nuvioRepositoryProvider);
    if (state.isLoading) {
      await repository.load();
      state = _ref.read(nuvioRepositoryProvider);
    }

    final type = NuvioScraperInfo.normalizeType(mediaType);
    final targets = state.activeScrapers
        .where((entry) => entry.scraper.supportsType(type))
        .toList();

    if (tmdbId.trim().isEmpty || targets.isEmpty) {
      yield const NuvioProgress(isLoading: false);
      return;
    }

    final resolvedId = await _normalizeId(tmdbId, type);

    final runtime = _ref.read(nuvioRuntimeProvider);
    final streams = <NuvioStreamResult>[];
    final seen = <String>{};
    final statuses = <String, NuvioScraperStatus>{
      for (final entry in targets)
        entry.scraper.id: NuvioScraperStatus(
          scraperName: entry.scraper.name,
          outcome: NuvioScraperOutcome.pending,
        ),
    };
    var completed = 0;

    final updates = StreamController<NuvioProgress>();
    // Closing the sheet must stop the remaining scrapers instead of leaving
    // ten QuickJS contexts running in the background.
    var cancelled = false;
    updates.onCancel = () => cancelled = true;

    NuvioProgress snapshot({bool loading = true}) => NuvioProgress(
      streams: List.of(streams),
      statuses: statuses.values.toList(),
      completedCount: completed,
      totalCount: targets.length,
      isLoading: loading,
    );

    String cacheKey(String scraperId, [Object? settingsStamp]) =>
        '$scraperId|$resolvedId|$type|${season ?? ''}|${episode ?? ''}'
        '|${settingsStamp ?? ''}';

    void publish(String scraperId, String name, List<NuvioStreamResult> found) {
      var added = 0;
      for (final result in found) {
        // Encode both halves: a raw `|` inside the url (or the scraper id)
        // could otherwise split the key into someone else's id|url pair and
        // the second link would be deduped away as a duplicate.
        if (!seen.add(
          '${Uri.encodeComponent(scraperId)}|${Uri.encodeComponent(result.url)}',
        )) continue;
        streams.add(result);
        added++;
      }
      statuses[scraperId] = NuvioScraperStatus(
        scraperName: name,
        outcome: added > 0
            ? NuvioScraperOutcome.links
            : NuvioScraperOutcome.empty,
        linkCount: added,
        message: added > 0 ? null : 'no links',
      );
    }

    Future<void> runOne(
      ({NuvioRepo repo, NuvioScraperInfo scraper}) entry,
    ) async {
      if (cancelled) return;
      final scraper = entry.scraper;
      // Settings change what a scraper returns, so they are part of the
      // cache identity — saving a new debrid key invalidates old results.
      final settings = scraper.hasSettings
          ? await repository.scraperSettings(scraper.id)
          : const <String, dynamic>{};
      final key = cacheKey(
        scraper.id,
        '${scraper.version}|${settings.isEmpty ? '' : jsonEncode(settings)}',
      );
      final cached = _cache.lookup(key);
      if (cached != null) {
        publish(scraper.id, scraper.name, cached);
        completed++;
        if (!updates.isClosed) updates.add(snapshot());
        return;
      }

      statuses[scraper.id] = NuvioScraperStatus(
        scraperName: scraper.name,
        outcome: NuvioScraperOutcome.running,
      );
      if (!updates.isClosed) updates.add(snapshot());

      try {
        final code = await repository.codeFor(entry.repo, scraper);
        // Whatever the user filled into the scraper's own settings form
        // (debrid keys, language, quality caps) travels with every run, the
        // way Nuvio passes SCRAPER_SETTINGS.
        final results = await runtime.run(
          code: code,
          scraperId: scraper.id,
          scraperName: scraper.name,
          tmdbId: resolvedId,
          mediaType: type,
          season: season,
          episode: episode,
          settings: settings,
        );
        _cache.store(key, results);
        publish(scraper.id, scraper.name, results);
      } on NuvioRuntimeException catch (error) {
        statuses[scraper.id] = NuvioScraperStatus(
          scraperName: scraper.name,
          outcome: NuvioScraperOutcome.failed,
          message: error.message,
        );
      } catch (error) {
        if (kDebugMode) debugPrint('[Nuvio] ${scraper.name}: $error');
        statuses[scraper.id] = NuvioScraperStatus(
          scraperName: scraper.name,
          outcome: NuvioScraperOutcome.failed,
          message: error.toString(),
        );
      } finally {
        completed++;
        if (!updates.isClosed) updates.add(snapshot());
      }
    }

    unawaited(() async {
      final queue = List.of(targets);
      final workers = List.generate(
        targets.length < maxConcurrent ? targets.length : maxConcurrent,
        (_) => Future(() async {
          while (queue.isNotEmpty && !cancelled) {
            await runOne(queue.removeAt(0));
          }
        }),
      );
      await Future.wait(workers);
      if (!updates.isClosed) await updates.close();
    }());

    yield snapshot();
    yield* updates.stream;
    yield snapshot(loading: false);
  }
}
