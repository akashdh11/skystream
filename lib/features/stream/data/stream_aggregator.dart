import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/extensions/base_provider.dart';
import '../../../core/extensions/extension_manager.dart';
import 'stream_source.dart';

class StreamAggregateResult {
  final List<AggregatedStream> streams;
  final List<String> searchedProviders;
  final List<String> readyProviders;

  /// Providers that finished (successfully or not). Used to drive a real
  /// progress bar instead of an indeterminate spinner.
  final int completedCount;
  final int totalCount;
  final bool isLoading;
  final String? error;

  const StreamAggregateResult({
    this.streams = const [],
    this.searchedProviders = const [],
    this.readyProviders = const [],
    this.completedCount = 0,
    this.totalCount = 0,
    this.isLoading = false,
    this.error,
  });

  double get progress =>
      totalCount == 0 ? 0 : (completedCount / totalCount).clamp(0.0, 1.0);

  StreamAggregateResult copyWith({
    List<AggregatedStream>? streams,
    List<String>? searchedProviders,
    List<String>? readyProviders,
    int? completedCount,
    int? totalCount,
    bool? isLoading,
    String? error,
  }) {
    return StreamAggregateResult(
      streams: streams ?? this.streams,
      searchedProviders: searchedProviders ?? this.searchedProviders,
      readyProviders: readyProviders ?? this.readyProviders,
      completedCount: completedCount ?? this.completedCount,
      totalCount: totalCount ?? this.totalCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Search every installed plugin for the exact TMDB movie/show, then resolve
/// streaming links for each matching provider. Matches are strict by TMDB/IMDb
/// ID when available, otherwise normalized title + media type + year.
class StreamAggregator {
  /// Plugins are queried concurrently, but not unboundedly — some plugins do
  /// heavy JS/webview work and firing 20 at once can starve the isolate on
  /// low-end devices.
  static const int _maxConcurrent = 4;

  /// A single plugin that hangs must not hold up the whole sheet.
  static const Duration _perProviderTimeout = Duration(seconds: 25);

  static double _titleSimilarity(String a, String b) {
    final wa = _words(a);
    final wb = _words(b);
    if (wa.isEmpty || wb.isEmpty) return 0;
    final intersection = wa.intersection(wb).length;
    final union = wa.union(wb).length;
    return union == 0 ? 0 : intersection / union;
  }

  static Set<String> _words(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 1)
        .toSet();
  }

  static bool _isCandidate(MultimediaItem target, MultimediaItem candidate) {
    final targetType = target.contentType;
    final candidateType = candidate.contentType;
    final typeMatches = targetType == MultimediaContentType.movie
        ? candidateType == MultimediaContentType.movie ||
              candidateType == MultimediaContentType.other
        : candidateType == MultimediaContentType.series ||
              candidateType == MultimediaContentType.anime ||
              candidateType == MultimediaContentType.other;
    if (!typeMatches) return false;

    if (target.tmdbId != null &&
        candidate.tmdbId != null &&
        target.tmdbId == candidate.tmdbId) {
      return true;
    }
    if (target.imdbId != null &&
        candidate.imdbId != null &&
        target.imdbId == candidate.imdbId) {
      return true;
    }

    final titleOk =
        candidate.title.trim().toLowerCase() ==
        target.title.trim().toLowerCase();
    if (!titleOk && _titleSimilarity(target.title, candidate.title) < 0.72) {
      return false;
    }

    if (target.year != null && candidate.year != null) {
      return (target.year! - candidate.year!).abs() <= 1;
    }
    return titleOk || _titleSimilarity(target.title, candidate.title) >= 0.85;
  }

  static MultimediaItem? _pickBest(
    MultimediaItem target,
    List<MultimediaItem> results,
  ) {
    MultimediaItem? exact;
    for (final item in results) {
      if (!_isCandidate(target, item)) continue;
      if (target.tmdbId != null && item.tmdbId == target.tmdbId) return item;
      if (target.imdbId != null && item.imdbId == target.imdbId) return item;
      exact ??= item;
      if (item.title.trim().toLowerCase() ==
          target.title.trim().toLowerCase()) {
        return item;
      }
    }
    return exact;
  }

  /// Best links first: resolution desc, then HDR, then adaptive manifests.
  static void _sortStreams(List<AggregatedStream> streams) {
    streams.sort((a, b) {
      final byQuality = b.qualityScore.compareTo(a.qualityScore);
      if (byQuality != 0) return byQuality;
      if (a.isHdr != b.isHdr) return a.isHdr ? -1 : 1;
      if (a.isAdaptive != b.isAdaptive) return a.isAdaptive ? -1 : 1;
      return a.providerName.compareTo(b.providerName);
    });
  }

  Stream<StreamAggregateResult> aggregateForMovie({
    required ExtensionManager manager,
    required MultimediaItem target,
  }) => _aggregate(manager: manager, target: target, episode: null);

  Stream<StreamAggregateResult> aggregateForEpisode({
    required ExtensionManager manager,
    required MultimediaItem target,
    required Episode episode,
  }) => _aggregate(manager: manager, target: target, episode: episode);

  Stream<StreamAggregateResult> _aggregate({
    required ExtensionManager manager,
    required MultimediaItem target,
    required Episode? episode,
  }) async* {
    final providers = manager.getAllProviders().where((p) {
      if (!p.hasSearch) return false;
      final liveOnly =
          p.supportedTypes.isNotEmpty &&
          p.supportedTypes.every((t) => t == ProviderType.livestream);
      return !liveOnly;
    }).toList();

    if (providers.isEmpty) {
      yield const StreamAggregateResult(
        error: 'No plugins installed. Install a plugin to see sources.',
      );
      return;
    }

    final streams = <AggregatedStream>[];
    final searched = <String>[];
    final ready = <String>[];
    final seen = <String>{};
    var completed = 0;

    // Emissions are pushed through a controller so that concurrent workers can
    // report progress the moment they finish, rather than in provider order.
    final updates = StreamController<StreamAggregateResult>();

    StreamAggregateResult snapshot({bool loading = true}) {
      _sortStreams(streams);
      return StreamAggregateResult(
        streams: List.of(streams),
        searchedProviders: List.of(searched),
        readyProviders: List.of(ready),
        completedCount: completed,
        totalCount: providers.length,
        isLoading: loading,
      );
    }

    Future<void> runOne(SkyStreamProvider provider) async {
      searched.add(provider.name);
      if (!updates.isClosed) updates.add(snapshot());

      try {
        final results = await provider
            .search(target.title)
            .timeout(_perProviderTimeout);
        final match = _pickBest(target, results);
        if (match == null) return;

        final details = await provider
            .getDetails(match.url)
            .timeout(_perProviderTimeout);

        final providerStreams = episode == null
            ? await provider
                  .loadStreams(details.url)
                  .timeout(_perProviderTimeout)
            : await _loadEpisodeStreams(
                provider,
                details,
                episode,
              ).timeout(_perProviderTimeout);

        if (providerStreams.isEmpty) return;
        ready.add(provider.name);

        for (final raw in providerStreams) {
          final tagged = raw.copyWith(
            providerName:
                raw.providerName == 'Unknown' || raw.providerName.isEmpty
                ? provider.name
                : raw.providerName,
            source: raw.source == 'Auto' ? 'Source' : raw.source,
          );
          final key = '${provider.packageName}:${tagged.url}:${tagged.source}';
          if (!seen.add(key)) continue;
          streams.add(
            AggregatedStream(
              providerId: provider.packageName,
              providerName: provider.name,
              itemUrl: details.url,
              episodeUrl: episode?.url ?? details.url,
              stream: tagged,
              detailedItem: details.copyWith(
                provider: provider.packageName,
                tmdbId: details.tmdbId ?? target.tmdbId,
                imdbId: details.imdbId ?? target.imdbId,
              ),
              episode: episode,
            ),
          );
        }
        if (!updates.isClosed) updates.add(snapshot());
      } catch (error) {
        // One bad plugin shouldn't sink the sheet; it just contributes nothing.
        if (kDebugMode) {
          debugPrint('[StreamAggregator] ${provider.name}: $error');
        }
      } finally {
        completed++;
        if (!updates.isClosed) updates.add(snapshot());
      }
    }

    // Fixed-size worker pool over the provider queue.
    unawaited(() async {
      final queue = List.of(providers);
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

    _sortStreams(streams);
    yield StreamAggregateResult(
      streams: streams,
      searchedProviders: searched,
      readyProviders: ready,
      completedCount: completed,
      totalCount: providers.length,
      isLoading: false,
      error: streams.isEmpty
          ? 'No streaming links found in installed plugins.'
          : null,
    );
  }

  Future<List<StreamResult>> _loadEpisodeStreams(
    SkyStreamProvider provider,
    MultimediaItem details,
    Episode episode,
  ) async {
    final episodes = details.episodes ?? const <Episode>[];
    Episode? target;
    for (final e in episodes) {
      if (e.url == episode.url ||
          (e.season == episode.season &&
              e.episode == episode.episode &&
              (e.name == episode.name || e.dubStatus == episode.dubStatus))) {
        target = e;
        break;
      }
    }
    target ??= episodes.isNotEmpty
        ? episodes.firstWhere(
            (e) => e.season == episode.season && e.episode == episode.episode,
            orElse: () => episode,
          )
        : episode;
    return provider.loadStreams(target.url);
  }
}
