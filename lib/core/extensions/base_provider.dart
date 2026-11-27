import 'package:dio/dio.dart';
import '../domain/entity/multimedia_item.dart';

enum ProviderType { movie, series, anime, livestream, other }

abstract class SkyStreamProvider {
  /// Unique Package Name (from plugin.json)
  String get packageName;

  /// Display Name
  String get name;
  String get mainUrl;
  String get version;
  List<String> get languages;
  Set<ProviderType> get supportedTypes;
  bool get hasSearch => true;
  bool get isDebug => packageName.endsWith('.debug');

  /// What a bot check met by this extension's requests is filed under, so
  /// screens can tell whose it is. Null when its requests can't be told
  /// apart.
  String? get checkSource => null;

  /// Cancel any pending JS eval for this provider so the queue isn't blocked
  /// by a stale IIFE load after the triggering search was abandoned.
  /// The provider resets itself so the next search retries cleanly.
  void cancelInit() {}

  // Key methods providers must implement
  Future<List<MultimediaItem>> search(String query, {CancelToken? cancelToken});
  // Returns categorized content (Section Name -> Items)
  Future<Map<String, List<MultimediaItem>>> getHome();

  /// Page [page] (1-based) of the home row titled [section], one of
  /// [getHome]'s keys, for the row's full list. Null when this provider can't
  /// page its home rows: the list then shows only what home has.
  Future<HomeSectionPage?> getHomeSection(String section, int page) async =>
      null;
  Future<MultimediaItem> getDetails(String url);

  // Returns list of video streams (urls)
  Future<List<StreamResult>> loadStreams(String url);
}

/// One page of a home row: its items, and whether a page follows.
class HomeSectionPage {
  const HomeSectionPage({required this.items, required this.hasNext});

  final List<MultimediaItem> items;
  final bool hasNext;
}

/// A provider's own full-screen screen (a game an extension opens on Play) took the person's Play and left nothing to
/// play after it: the player leaves quietly instead of saying no streams were found (Phase 7c's §4).
class ExtensionScreenEnded implements Exception {
  const ExtensionScreenEnded();

  @override
  String toString() => 'The extension showed its own screen instead of links.';
}
