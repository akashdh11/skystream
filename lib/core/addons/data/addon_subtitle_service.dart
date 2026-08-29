import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/addon_manifest.dart';
import '../models/addon_stream_source.dart';
import 'addon_client.dart';
import 'addon_stream_service.dart';

part 'addon_subtitle_service.g.dart';

@Riverpod(keepAlive: true)
AddonSubtitleService addonSubtitleService(Ref ref) =>
    AddonSubtitleService(ref.watch(addonClientProvider));

/// Subtitles from add-ons implementing the `subtitles` resource.
///
/// Like ARVIO, the public keyless OpenSubtitles v3 add-on is used as a
/// fallback when the user hasn't installed a subtitle add-on, so tracks are
/// available out of the box. Still 100% add-on protocol — no plugin involved.
class AddonSubtitleService {
  AddonSubtitleService(this._client);

  final AddonClient _client;

  static const Duration _timeout = Duration(seconds: 12);
  static const int _maxResults = 80;

  static final ManagedAddon _openSubtitles = ManagedAddon(
    manifestUrl: 'https://opensubtitles-v3.strem.io/manifest.json',
    addedAt: DateTime.fromMillisecondsSinceEpoch(0),
    manifest: const AddonManifest(
      id: 'org.stremio.opensubtitlesv3',
      name: 'OpenSubtitles',
      version: '1.0.0',
      types: ['movie', 'series'],
      idPrefixes: ['tt'],
      resources: [AddonResource(name: 'subtitles')],
    ),
  );

  Future<List<AddonSubtitleTrack>> fetch({
    required List<ManagedAddon> addons,
    required AddonStreamRequest request,
    int? videoSize,
    String? filename,
  }) async {
    final providers = addons
        .where((a) => a.manifest?.hasResource('subtitles') ?? false)
        .toList();
    if (!providers.any((a) => a.manifestUrl == _openSubtitles.manifestUrl)) {
      providers.add(_openSubtitles);
    }

    final ids = request.idCandidates;
    if (ids.isEmpty) return const [];

    final extra = <String, String>{
      if (videoSize != null && videoSize > 0) 'videoSize': '$videoSize',
      if (filename != null && filename.isNotEmpty) 'filename': filename,
    };

    Future<List<AddonSubtitleTrack>> ask(ManagedAddon addon) async {
      final manifest = addon.manifest;
      if (manifest == null) return const [];
      for (final id in ids) {
        if (!manifest.supportsId('subtitles', id)) continue;
        for (final type in manifest.requestTypesFor(
          'subtitles',
          request.type,
        )) {
          try {
            final subs = await _client
                .subtitles(
                  addon,
                  type: type,
                  id: id,
                  extra: extra.isEmpty ? null : extra,
                )
                .timeout(_timeout);
            if (subs.isNotEmpty) return subs;
          } catch (_) {
            // Try the next id/type combination.
          }
        }
      }
      return const [];
    }

    final batches = await Future.wait(providers.map(ask));

    final seen = <String>{};
    final out = <AddonSubtitleTrack>[];
    for (final batch in batches) {
      for (final sub in batch) {
        if (!seen.add('${sub.lang}|${sub.url}')) continue;
        out.add(sub);
        if (out.length >= _maxResults) break;
      }
    }
    out.sort((a, b) => a.label.compareTo(b.label));
    return out;
  }
}
