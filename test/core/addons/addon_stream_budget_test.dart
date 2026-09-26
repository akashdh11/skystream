import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/addons/data/addon_client.dart';
import 'package:skystream/core/addons/data/addon_stream_service.dart';
import 'package:skystream/core/addons/models/addon_manifest.dart';
import 'package:skystream/core/addons/models/addon_stream_source.dart';

/// Speed guard for the add-on fallback walk.
///
/// One episode offers up to 4 id candidates per add-on (videoId, base:s:e,
/// imdb:s:e, tmdb:x:s:e), and a series add-on can declare up to 3 type
/// aliases, so the sequential (id x alias) chain can reach 12 requests.
/// Before the per-add-on budget existed, a hanging add-on could chain a
/// dozen request timeouts (~160 s at the old 18 s timeout) while holding
/// one of the worker slots — stalling every healthy add-on queued behind
/// it. These tests pin the cure: the SAME priority walk, abandoned once the
/// add-on has had its budget.
void main() {
  ManagedAddon streamAddon(String label) {
    final manifest = AddonManifest.fromJson({
      'id': 'test.$label',
      'name': label,
      'version': '1.0.0',
      'types': const ['series'],
      'resources': const [
        {
          'name': 'stream',
          'types': ['series', 'tv', 'show'],
        },
      ],
    });
    return ManagedAddon(
      manifestUrl: 'https://$label.example/manifest.json',
      manifest: manifest,
      addedAt: DateTime(2024),
    );
  }

  /// Four distinct id candidates — the maximum-length fallback walk.
  const request = AddonStreamRequest(
    type: 'series',
    contentId: 'kitsu:40724',
    videoId: 'kitsu:40724:1:3',
    season: 1,
    episode: 3,
    imdbId: 'tt5592146',
    tmdbId: 71446,
  );

  Future<AddonStreamProgress> runUntilDone(
    AddonStreamService service,
    List<ManagedAddon> addons,
  ) async {
    AddonStreamProgress? last;
    await for (final snapshot in service.resolve(
      addons: addons,
      request: request,
    )) {
      last = snapshot;
    }
    return last!;
  }

  group('per-add-on budget', () {
    test(
      'a hanging add-on is abandoned at the budget, not after the chain',
      () async {
        var requests = 0;
        final client = _FakeClient((addon, type, id) async {
          requests++;
          // Every request hangs: resolve only via the service's timeout.
          await Future<void>.delayed(const Duration(seconds: 3));
          return const <AddonStreamSource>[];
        });
        final service = AddonStreamService(
          client,
          addonBudget: const Duration(seconds: 2),
          requestTimeout: const Duration(milliseconds: 900),
        );

        final stopwatch = Stopwatch()..start();
        final last = await runUntilDone(service, [streamAddon('hang')]);
        stopwatch.stop();

        expect(
          requests,
          lessThanOrEqualTo(4),
          reason:
              'the full chain is 4 ids x 3 aliases = 12 requests; '
              'the budget must truncate it (2 s budget / 0.9 s timeout)',
        );
        expect(
          stopwatch.elapsed,
          lessThan(const Duration(seconds: 5)),
          reason: 'an unbudgeted chain of hanging requests takes ~11 s',
        );
        final status = last.statuses.single;
        expect(status.outcome, AddonQueryOutcome.failed);
      },
    );


    test('every stream add-on is asked, and fast ones are not gated by slow ones', () async {
      final started = <String>[];
      final client = _FakeClient((addon, type, id) async {
        started.add(addon.displayName);
        if (addon.displayName == 'slow') {
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
        return [
          AddonStreamSource.fromJson(
            {
              'name': addon.displayName,
              'url': 'https://files.example/${addon.displayName}.mp4',
            },
            addonId: addon.manifest?.id ?? addon.manifestUrl,
            addonName: addon.displayName,
          ),
        ];
      });
      final service = AddonStreamService(
        client,
        addonBudget: const Duration(seconds: 2),
        requestTimeout: const Duration(seconds: 1),
      );

      final snapshots = <AddonStreamProgress>[];
      await for (final snap in service.resolve(
        addons: [streamAddon('slow'), streamAddon('fast'), streamAddon('also')],
        request: request,
      )) {
        snapshots.add(snap);
      }

      // All three must have been asked — catalog-only filtering is the only skip.
      expect(started.toSet(), {'slow', 'fast', 'also'});
      final last = snapshots.last;
      expect(last.streams, hasLength(3));
      expect(
        last.statuses.where((s) => s.outcome == AddonQueryOutcome.links),
        hasLength(3),
      );
      // A partial snapshot with links must appear before the slow add-on finishes
      // the whole resolve — i.e. fast answers are not queued behind slow.
      final firstWithLinks = snapshots.indexWhere((s) => s.streams.isNotEmpty);
      expect(firstWithLinks, greaterThanOrEqualTo(0));
      expect(
        snapshots[firstWithLinks].completedCount,
        lessThan(3),
        reason: 'links must surface before every add-on has finished',
      );
    });


    test('a slow scraper (~22s) still lands inside the default budget', () async {
      // CNCVerse live /stream answers take 22–27 s. The old 18 s ceiling
      // turned every one of those into TimeoutException with 0 links.
      var requests = 0;
      final client = _FakeClient((addon, type, id) async {
        requests++;
        await Future<void>.delayed(const Duration(seconds: 22));
        return [
          AddonStreamSource.fromJson(
            const {
              'name': 'MovieBox 1080p',
              'url': 'https://files.example/mugen.mp4',
            },
            addonId: 'cnc',
            addonName: 'CNCVerse Bridge',
          ),
        ];
      });
      // Defaults: 45 s request / 55 s budget — must clear a 22 s scrape.
      final service = AddonStreamService(client);

      final last = await runUntilDone(service, [streamAddon('cnc')]);

      expect(requests, 1);
      expect(last.streams, hasLength(1));
      expect(last.statuses.single.outcome, AddonQueryOutcome.links);
      expect(last.error, isNull);
    });

    test('a healthy add-on still costs exactly one request', () async {
      var requests = 0;
      final client = _FakeClient((addon, type, id) async {
        requests++;
        return [
          AddonStreamSource.fromJson(
            const {
              'name': 'direct link',
              'url': 'https://files.example/video.mp4',
            },
            addonId: 'test.light',
            addonName: 'light',
          ),
        ];
      });
      final service = AddonStreamService(client);

      final last = await runUntilDone(service, [streamAddon('light')]);

      expect(
        requests,
        1,
        reason:
            'first-priority hit wins immediately — no alias spam '
            'against healthy add-ons',
      );
      expect(last.streams, hasLength(1));
      expect(last.statuses.single.outcome, AddonQueryOutcome.links);
      expect(last.error, isNull);
    });
  });
}

typedef _StreamsHandler = Future<List<AddonStreamSource>> Function(
  ManagedAddon addon,
  String type,
  String id,
);

class _FakeClient extends AddonClient {
  _FakeClient(this.handler) : super(Dio());

  final _StreamsHandler handler;

  @override
  Future<List<AddonStreamSource>> streams(
    ManagedAddon addon, {
    required String type,
    required String id,
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) => handler(addon, type, id);
}
