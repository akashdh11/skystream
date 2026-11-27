import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart'
    show ProviderListenable;
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/core/extensions/base_provider.dart';
import 'package:skystream/core/extensions/extension_manager.dart';
import 'package:skystream/features/library/presentation/history_provider.dart';
import 'package:skystream/features/player/domain/stream_resolver.dart';
import 'package:skystream/features/settings/presentation/player_settings_provider.dart';

/// A provider reader backed by a fixed table, so the resolver can be exercised
/// without a container. Reading anything not listed is a failure rather than a
/// null, which keeps the tests honest about what the resolver actually touches.
ProviderReader readerOf(List<(Object, Object?)> entries) {
  return <T>(ProviderListenable<T> provider) {
    for (final (key, value) in entries) {
      if (identical(key, provider)) return value as T;
    }
    throw StateError('resolver read an unstubbed provider: $provider');
  };
}

MultimediaItem itemWith({String? provider}) => MultimediaItem(
  title: 'Test Movie',
  url: 'https://example.com/title/1',
  posterUrl: '',
  provider: provider,
);

StreamResult streamAt(String url, String source) =>
    StreamResult(url: url, source: source, providerName: 'Plugin');

/// A plugin that hands back a fixed list. The interface is small enough to
/// satisfy outright, which keeps the fake honest about what the resolver calls.
class FakePlugin implements SkyStreamProvider {
  FakePlugin(this.streams);

  final List<StreamResult> streams;

  @override
  Future<List<StreamResult>> loadStreams(String url) async => streams;

  @override
  String get packageName => 'com.skystream.fake';
  @override
  String get name => 'Fake';
  @override
  String get mainUrl => 'https://fake.test';
  @override
  String get version => '1.0.0';
  @override
  List<String> get languages => const ['en'];
  @override
  Set<ProviderType> get supportedTypes => const {ProviderType.movie};
  @override
  bool get hasSearch => false;
  @override
  bool get isDebug => false;
  @override
  String? get checkSource => null;
  @override
  void cancelInit() {}
  @override
  Future<List<MultimediaItem>> search(
    String query, {
    CancelToken? cancelToken,
  }) async => const [];
  @override
  Future<Map<String, List<MultimediaItem>>> getHome() async => const {};
  @override
  Future<HomeSectionPage?> getHomeSection(String section, int page) async =>
      null;
  @override
  Future<MultimediaItem> getDetails(String url) async =>
      throw UnimplementedError();
}

/// A provider whose links went to its own full-screen screen (a game).
class _ScreenPlugin extends FakePlugin {
  _ScreenPlugin() : super(const []);

  @override
  Future<List<StreamResult>> loadStreams(String url) async => throw const ExtensionScreenEnded();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final defaults = <(Object, Object?)>[
    (activeProviderProvider, null),
    (playerSettingsProvider, const AsyncValue<PlayerSettings>.data(
      PlayerSettings(),
    )),
    (watchHistoryProvider, const <HistoryItem>[]),
  ];

  group('resolvePlayback', () {
    // The bug this whole file exists for: PlayerRouteExtra.videoUrl is a plugin
    // resolution token, and plugins are free to make it a JSON array. Phase 5
    // called Uri.parse on it and threw FormatException before playback began.
    test('a videoUrl that is not a URI resolves via the streams', () async {
      const token =
          '[{"source":"https://cdn.example/480.mp4","quality":"480p"},'
          '{"source":"https://cdn.example/720.mp4","quality":"720p"}]';

      final resolved = await resolvePlayback(
        read: readerOf(defaults),
        item: itemWith(),
        videoUrl: token,
        preloadedStreams: [
          streamAt('https://cdn.example/480.mp4', '480p'),
          streamAt('https://cdn.example/720.mp4', '720p'),
        ],
        probeCandidates: 0,
      );

      expect(resolved.streams, hasLength(2));
      expect(resolved.selected.url, isNot(token));
      expect(Uri.parse(resolved.selected.url).hasScheme, isTrue);
    });

    test('local playback needs no provider and no plugin call', () async {
      final resolved = await resolvePlayback(
        read: readerOf(defaults),
        item: itemWith(provider: 'Local'),
        videoUrl: '/Users/me/Movies/movie.mkv',
        probeCandidates: 0,
      );

      expect(resolved.streams, hasLength(1));
      expect(resolved.selected.url, '/Users/me/Movies/movie.mkv');
      expect(resolved.selected.source, 'Video');
    });

    test('a torrent resolves to a torrent stream rather than a plugin call',
        () async {
      final resolved = await resolvePlayback(
        read: readerOf(defaults),
        item: itemWith(),
        videoUrl: 'magnet:?xt=urn:btih:abc',
        probeCandidates: 0,
      );

      expect(resolved.selected.source, 'Torrent');
    });

    test('no provider and nothing preloaded fails with a message', () async {
      expect(
        () => resolvePlayback(
          read: readerOf(defaults),
          item: itemWith(),
          videoUrl: 'https://example.com/episode/1',
          probeCandidates: 0,
        ),
        throwsA(
          isA<StreamResolutionException>().having(
            (e) => e.message,
            'message',
            'No provider selected.',
          ),
        ),
      );
    });

    test(
      "a Play an extension's full-screen window took fails as extensionScreen, for the player to leave quietly",
      () async {
        expect(
          () => resolvePlayback(
            read: readerOf([(activeProviderProvider, _ScreenPlugin()), ...defaults]),
            item: itemWith(),
            videoUrl: 'https://example.com/episode/1',
            probeCandidates: 0,
          ),
          throwsA(
            isA<StreamResolutionException>().having(
              (e) => e.failure,
              'failure',
              StreamResolutionFailure.extensionScreen,
            ),
          ),
        );
      },
    );
  });

  // Both source sheets put the tapped row first and hand the whole list over.
  // Ranking that list again opens whatever the settings prefer instead of what
  // the viewer pressed.
  group('a hand-picked source', () {
    List<StreamResult> tapped720Beneath1080() => [
      streamAt('https://cdn.example/720.mp4', '720p · 1.2 GB · 40 seeds'),
      streamAt('https://cdn.example/1080.mp4', '1080p · 2.4 GB · 12 seeds'),
    ];

    ProviderReader readerWith(PlayerSettings settings, {
      List<HistoryItem> history = const [],
    }) => readerOf([
      (playerSettingsProvider, AsyncValue<PlayerSettings>.data(settings)),
      (watchHistoryProvider, history),
      ...defaults,
    ]);

    test('opens the tapped source, not the preferred tier', () async {
      final resolved = await resolvePlayback(
        read: readerWith(const PlayerSettings()),
        item: itemWith(),
        videoUrl: 'https://example.com/episode/1',
        preloadedStreams: tapped720Beneath1080(),
        probeCandidates: 0,
      );

      expect(resolved.index, 0);
      expect(resolved.selected.url, 'https://cdn.example/720.mp4');
    });

    // atOrAbove used to drop the tapped row out of the list altogether, so it
    // was not even reachable from the player's Sources tab afterwards.
    test('is not filtered out of its own candidate list', () async {
      final resolved = await resolvePlayback(
        read: readerWith(
          const PlayerSettings(qualityFilterMode: QualityFilterMode.atOrAbove),
        ),
        item: itemWith(),
        videoUrl: 'https://example.com/episode/1',
        preloadedStreams: tapped720Beneath1080(),
        probeCandidates: 0,
      );

      expect(resolved.streams.map((s) => s.url), [
        'https://cdn.example/720.mp4',
        'https://cdn.example/1080.mp4',
      ]);
      expect(resolved.qualityFilteredFallback, isFalse);
    });

    // Resuming on the last working source is for a list the resolver picked
    // from. A tap is more recent evidence than the last thing watched.
    test('outranks the source watch history remembers', () async {
      final resolved = await resolvePlayback(
        read: readerWith(
          const PlayerSettings(
            wifiQuality: QualityPreference.any,
            mobileQuality: QualityPreference.any,
          ),
          history: [
            HistoryItem(
              item: itemWith(),
              position: 60,
              duration: 3600,
              lastStreamUrl: 'https://cdn.example/1080.mp4',
              timestamp: 0,
            ),
          ],
        ),
        item: itemWith(),
        videoUrl: 'https://example.com/episode/1',
        preloadedStreams: tapped720Beneath1080(),
        probeCandidates: 0,
      );

      expect(resolved.selected.url, 'https://cdn.example/720.mp4');
    });
  });

  // Ethernet-connected televisions and desktops are core targets, and asking
  // for Wi-Fi specifically served every one of them the mobile-data
  // preference.
  group('the network the preference is chosen for', () {
    const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');

    void connectedVia(String transport) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => call.method == 'check' ? <String>[transport] : null,
          );
    }

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    Future<String> sourceOpenedOn(String transport) async {
      connectedVia(transport);
      final resolved = await resolvePlayback(
        read: readerOf([
          (
            activeProviderProvider,
            FakePlugin([
              streamAt('https://cdn.example/1080.mp4', '1080p'),
              streamAt('https://cdn.example/480.mp4', '480p'),
            ]),
          ),
          (playerSettingsProvider, const AsyncValue<PlayerSettings>.data(
            PlayerSettings(
              wifiQuality: QualityPreference.q480,
              mobileQuality: QualityPreference.q1080,
            ),
          )),
          (watchHistoryProvider, const <HistoryItem>[]),
        ]),
        item: itemWith(),
        videoUrl: 'https://example.com/episode/1',
        probeCandidates: 0,
      );
      return resolved.selected.source;
    }

    test('a wired link takes the unmetered preference', () async {
      expect(await sourceOpenedOn('ethernet'), '480p');
    });

    test('wi-fi takes the unmetered preference', () async {
      expect(await sourceOpenedOn('wifi'), '480p');
    });

    test('cellular takes the mobile preference', () async {
      expect(await sourceOpenedOn('mobile'), '1080p');
    });
  });

  // The probe is a parallel race that used to surface nothing at all while it
  // ran, so a five-source title spent the whole health check behind one
  // undifferentiated spinner. These callbacks are what the player narrates.
  group('probe reporting', () {
    /// A bare path is healthy without a socket; a schemeless token is refused
    /// without one either. Between them the whole probe runs offline.
    List<StreamResult> candidatesWithHealthyMiddle() => [
      streamAt('nothing-here-a', '1080p'),
      streamAt('/sources/b.mkv', '720p'),
      streamAt('nothing-here-c', '480p'),
    ];

    test('every candidate is announced before any of them settles', () async {
      final events = <String>[];
      List<StreamResult>? candidates;

      final resolved = await resolvePlayback(
        read: readerOf(defaults),
        item: itemWith(),
        videoUrl: 'https://example.com/episode/1',
        preloadedStreams: candidatesWithHealthyMiddle(),
        probeCandidates: 3,
        onCandidates: (streams) {
          candidates = streams;
          events.add('candidates:${streams.length}');
        },
        onProbe: (index, outcome) => events.add('$index:${outcome.name}'),
      );

      expect(candidates, hasLength(3));
      // The order matters as much as the contents: the list has to be known
      // before an index into it means anything, and the dispatch order is the
      // failover order.
      expect(events.take(4).toList(), <String>[
        'candidates:3',
        '0:trying',
        '1:trying',
        '2:trying',
      ]);

      final healthy = candidates!.indexWhere((s) => s.url == '/sources/b.mkv');
      expect(events, contains('$healthy:healthy'));
      for (var i = 0; i < candidates!.length; i++) {
        if (i == healthy) continue;
        expect(events, contains('$i:unhealthy'));
      }
      expect(resolved.index, healthy);
    });

    test(
      'the candidate list is reported even when nothing is probed',
      () async {
        List<StreamResult>? candidates;
        await resolvePlayback(
          read: readerOf(defaults),
          item: itemWith(provider: 'Local'),
          videoUrl: '/Users/me/Movies/movie.mkv',
          probeCandidates: 0,
          onCandidates: (streams) => candidates = streams,
        );

        expect(
          candidates,
          hasLength(1),
          reason: 'a direct stream is still a source the viewer can be shown',
        );
      },
    );

    // A row picked from the source list while the check runs is a choice the
    // viewer made: the race ends on it, even on a row the check would have
    // passed over.
    test('a row picked during the check ends it on exactly that row', () async {
      final settled = <int>[];
      final resolved = await resolvePlayback(
        read: readerOf(defaults),
        item: itemWith(),
        videoUrl: 'https://example.com/episode/1',
        preloadedStreams: candidatesWithHealthyMiddle(),
        probeCandidates: 3,
        onProbe: (index, outcome) {
          if (outcome != ProbeOutcome.trying) settled.add(index);
        },
        pick: Future<int>.value(2),
      );

      expect(
        resolved.index,
        2,
        reason: 'the check would have opened 1; the viewer asked for 2',
      );
      expect(
        settled,
        isNotEmpty,
        reason: 'the probes in flight still report what they find',
      );
    });
  });

  // The check used to look at the top three and stop. A dead one among them
  // was never replaced, and three dead ones opened the first of them anyway -
  // up to 25 s of stall - before failover walked the rest one at a time.
  group('the rolling check', () {
    StreamResult at(String name) =>
        StreamResult(url: 'https://cdn.test/$name.mkv', source: name);

    /// Answers each candidate by name: [dead] ones refuse both of the probe's
    /// requests, [held] ones wait on their completer and then answer, and
    /// everything else answers at once.
    MockClient answering({
      Set<String> dead = const <String>{},
      Map<String, Completer<void>> held = const <String, Completer<void>>{},
    }) => MockClient((request) async {
      final name = request.url.pathSegments.last.replaceAll('.mkv', '');
      await held[name]?.future;
      if (dead.contains(name)) {
        if (request.method == 'HEAD') return http.Response('', 404);
        throw http.ClientException('refused', request.url);
      }
      return http.Response('', 200);
    });

    Future<void> drain() async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('a candidate found dead is replaced by the next in line', () async {
      final b = Completer<void>();
      final dispatched = <int>[];
      await http.runWithClient(() async {
        final resolving = resolvePlayback(
          read: readerOf(defaults),
          item: itemWith(),
          videoUrl: 'https://example.com/episode/1',
          preloadedStreams: [at('a'), at('b'), at('c'), at('d')],
          onProbe: (index, outcome) {
            if (outcome == ProbeOutcome.trying) dispatched.add(index);
          },
        );
        await drain();
        expect(
          dispatched,
          contains(3),
          reason: 'a is dead, so d is checked in its place',
        );

        b.complete();
        final resolved = await resolving;
        expect(
          resolved.index,
          1,
          reason: 'b answers, and it outranks c and d',
        );
      }, () => answering(dead: {'a'}, held: {'b': b}));
    });

    test('when the first three are dead, the next three are checked and the '
        'first reachable opens', () async {
      final dispatched = <int>[];
      final resolved = await http.runWithClient(
        () => resolvePlayback(
          read: readerOf(defaults),
          item: itemWith(),
          videoUrl: 'https://example.com/episode/1',
          preloadedStreams: [
            at('a'),
            at('b'),
            at('c'),
            at('d'),
            at('e'),
            at('f'),
          ],
          onProbe: (index, outcome) {
            if (outcome == ProbeOutcome.trying) dispatched.add(index);
          },
        ),
        () => answering(dead: {'a', 'b', 'c', 'd'}),
      );

      expect(dispatched, containsAll(<int>[3, 4]));
      expect(resolved.index, 4, reason: 'e is the first that answers');
    });

    // The check is wrong about slow hosts, so all of them failing it is not
    // proof that none will play.
    test('when every candidate is dead, the preferred one opens anyway', () async {
      final resolved = await http.runWithClient(
        () => resolvePlayback(
          read: readerOf(defaults),
          item: itemWith(),
          videoUrl: 'https://example.com/episode/1',
          preloadedStreams: [at('a'), at('b'), at('c'), at('d')],
        ),
        () => answering(dead: {'a', 'b', 'c', 'd'}),
      );

      expect(resolved.index, 0);
    });

    // The check ends as soon as the best link is known, and links still being
    // checked answer after it. One of those found dead used to leave its slot
    // empty, so the list showed three verdicts and then nothing.
    test('a link found dead after the check settled is still replaced', () async {
      final b = Completer<void>();
      final dispatched = <int>[];
      await http.runWithClient(() async {
        final resolved = await resolvePlayback(
          read: readerOf(defaults),
          item: itemWith(),
          videoUrl: 'https://example.com/episode/1',
          preloadedStreams: [at('a'), at('b'), at('c'), at('d')],
          onProbe: (index, outcome) {
            if (outcome == ProbeOutcome.trying) dispatched.add(index);
          },
        );
        expect(resolved.index, 0, reason: 'a answered first');
        expect(dispatched, isNot(contains(3)));

        b.complete();
        await drain();
        expect(dispatched, contains(3), reason: 'b died, so d takes its place');
      }, () => answering(dead: {'b'}, held: {'b': b}));
    });

    test('and nothing more is checked once the caller abandons it', () async {
      final b = Completer<void>();
      final abandon = Completer<void>();
      final dispatched = <int>[];
      await http.runWithClient(() async {
        await resolvePlayback(
          read: readerOf(defaults),
          item: itemWith(),
          videoUrl: 'https://example.com/episode/1',
          preloadedStreams: [at('a'), at('b'), at('c'), at('d')],
          onProbe: (index, outcome) {
            if (outcome == ProbeOutcome.trying) dispatched.add(index);
          },
          abandon: abandon.future,
        );
        abandon.complete();
        await drain();

        b.complete();
        await drain();
        expect(dispatched, isNot(contains(3)));
      }, () => answering(dead: {'b'}, held: {'b': b}));
    });

    test('a web page is passed over like a dead link', () async {
      final outcomes = <int, ProbeOutcome>{};
      final resolved = await http.runWithClient(
        () => resolvePlayback(
          read: readerOf(defaults),
          item: itemWith(),
          videoUrl: 'https://example.com/episode/1',
          preloadedStreams: [at('a'), at('b')],
          onProbe: (index, outcome) => outcomes[index] = outcome,
        ),
        () => MockClient((request) async {
          if (request.url.path.endsWith('/a.mkv')) {
            return http.Response(
              '<!doctype html><html><body>Link Generator</body></html>',
              200,
              headers: {'content-type': 'text/html'},
            );
          }
          return http.Response(
            'x',
            206,
            headers: {'content-range': 'bytes 0-0/10'},
          );
        }),
      );

      expect(resolved.index, 1);
      expect(outcomes[0], ProbeOutcome.notVideo);
    });

    // Fifty dead links at up to six seconds a batch is minutes of spinner.
    test('the time limit opens the best found so far', () async {
      final slow = Completer<void>();
      final resolved = await http.runWithClient(
        () => resolvePlayback(
          read: readerOf(defaults),
          item: itemWith(),
          videoUrl: 'https://example.com/episode/1',
          preloadedStreams: [at('a'), at('b')],
          probeBudget: const Duration(milliseconds: 50),
        ),
        () => answering(held: {'a': slow}),
      );

      expect(
        resolved.index,
        1,
        reason: 'a has not answered, b has - no longer worth waiting on a',
      );
    });

    test('and the preferred one when nothing has answered', () async {
      final slow = Completer<void>();
      final resolved = await http.runWithClient(
        () => resolvePlayback(
          read: readerOf(defaults),
          item: itemWith(),
          videoUrl: 'https://example.com/episode/1',
          preloadedStreams: [at('a'), at('b')],
          probeBudget: const Duration(milliseconds: 50),
        ),
        () => answering(held: {'a': slow, 'b': slow}),
      );

      expect(resolved.index, 0);
    });
  });

  // The same check the race runs, for one source on its own: a link opened
  // outside the top three is checked while it opens.
  group('isReachable', () {
    const stream = StreamResult(url: 'https://cdn.test/a.mkv', source: 'A');

    test('is true for a source that answers', () async {
      final ok = await http.runWithClient(
        () => isReachable(stream),
        () => MockClient((_) async => http.Response('', 200)),
      );
      expect(ok, isTrue);
    });

    test('is false for one that refuses both requests', () async {
      final ok = await http.runWithClient(
        () => isReachable(stream),
        () => MockClient((request) async {
          if (request.method == 'HEAD') return http.Response('', 404);
          throw http.ClientException('refused', request.url);
        }),
      );
      expect(ok, isFalse);
    });

    test('is false for one that answers with a web page', () async {
      final ok = await http.runWithClient(
        () => isReachable(stream),
        () => MockClient(
          (_) async => http.Response(
            '<!DOCTYPE html><html><head></head></html>',
            200,
            headers: {'content-type': 'text/html'},
          ),
        ),
      );
      expect(ok, isFalse);
    });
  });

  // The check reads what answered, not only that something did. HubCloud's
  // 10Gbps buttons answer 200 with a link generator - a web page whose script
  // sends a browser on to the file - and a server that ignores byte ranges
  // plays a file only from its start: no seeking, and no resuming.
  group('what the check finds', () {
    const file = StreamResult(url: 'https://cdn.test/a.mkv', source: 'A');

    Future<ProbeOutcome> probe(
      StreamResult stream,
      Future<http.Response> Function(http.Request request) answer,
    ) =>
        http.runWithClient(() => probeSource(stream), () => MockClient(answer));

    test('a web page is not a video', () async {
      final outcome = await probe(
        file,
        (_) async => http.Response(
          '<!DOCTYPE html>\n<html lang="en"><head><title>HubCloud - Link '
          'Generator</title></head><body></body></html>',
          200,
          headers: {'content-type': 'text/html; charset=UTF-8'},
        ),
      );
      expect(outcome, ProbeOutcome.notVideo);
    });

    test('a playlist a script serves as a web page is a playlist', () async {
      final outcome = await probe(
        const StreamResult(url: 'https://cdn.test/live.php?id=7', source: 'A'),
        (_) async => http.Response(
          '#EXTM3U\n#EXT-X-VERSION:3\n#EXTINF:10,\nseg0.ts\n',
          200,
          headers: {'content-type': 'text/html; charset=UTF-8'},
        ),
      );
      expect(outcome, ProbeOutcome.healthy);
    });

    test('a file served in ranges can be sought in', () async {
      final outcome = await probe(
        file,
        (_) async => http.Response(
          'x',
          206,
          headers: {
            'content-type': 'video/x-matroska',
            'content-range': 'bytes 0-0/19986728180',
          },
        ),
      );
      expect(outcome, ProbeOutcome.healthy);
    });

    test(
      'a file whose server ignores ranges plays only from the start',
      () async {
        // video-downloads.googleusercontent.com: 200 and the whole file from
        // byte 0, whatever range is asked for.
        final outcome = await probe(
          file,
          (_) async => http.Response(
            'the first bytes of the file',
            200,
            headers: {'content-type': 'video/mkv'},
          ),
        );
        expect(outcome, ProbeOutcome.unseekable);
      },
    );

    // The buffer rule sizes a file from its length over its runtime (spec
    // 1.2), and the check is the one request that sees the length.
    test(
      'the size a ranged answer gives is kept for the buffer rule',
      () async {
        const sized = StreamResult(
          url: 'https://cdn.test/sized.mkv',
          source: 'A',
        );
        await probe(
          sized,
          (_) async => http.Response(
            'x',
            206,
            headers: {
              'content-type': 'video/x-matroska',
              'content-range': 'bytes 0-0/19986728180',
            },
          ),
        );
        expect(probedSizeOf(sized.url), 19986728180);
      },
    );

    test('so is the length of a server that sends the whole file', () async {
      const whole = StreamResult(
        url: 'https://cdn.test/whole.mkv',
        source: 'A',
      );
      await probe(
        whole,
        (_) async => http.Response(
          'the first bytes of the file',
          200,
          headers: {
            'content-type': 'video/mkv',
            'content-length': '7340032000',
          },
        ),
      );
      expect(probedSizeOf(whole.url), 7340032000);
    });

    test('a web page or a playlist leaves no size', () async {
      const page = StreamResult(url: 'https://cdn.test/page.mkv', source: 'A');
      await probe(
        page,
        (_) async => http.Response(
          '<!DOCTYPE html><html></html>',
          200,
          headers: {'content-type': 'text/html', 'content-length': '28'},
        ),
      );
      const list = StreamResult(
        url: 'https://cdn.test/sized.m3u8',
        source: 'A',
      );
      await probe(
        list,
        (_) async => http.Response(
          '#EXTM3U\n',
          200,
          headers: {
            'content-type': 'application/vnd.apple.mpegurl',
            'content-length': '8',
          },
        ),
      );
      expect((probedSizeOf(page.url), probedSizeOf(list.url)), (null, null));
    });

    test('a range with an unknown total says nothing', () {
      expect(fileSizeFromHeaders(206, {'content-range': 'bytes 0-0/*'}), null);
      expect(fileSizeFromHeaders(206, {'content-length': '1'}), null);
    });

    test('a playlist needs no ranges to be sought in', () async {
      final outcome = await probe(
        const StreamResult(url: 'https://cdn.test/a.m3u8', source: 'A'),
        (_) async => http.Response(
          '#EXTM3U\n',
          200,
          headers: {'content-type': 'application/vnd.apple.mpegurl'},
        ),
      );
      expect(outcome, ProbeOutcome.healthy);
    });

    test('a server that refuses the ranged request is asked plainly', () async {
      final outcome = await probe(file, (request) async {
        if (request.method == 'GET') {
          throw http.ClientException('reset', request.url);
        }
        return http.Response('', 200, headers: {'content-type': 'video/mp4'});
      });
      expect(outcome, ProbeOutcome.healthy);
    });
  });

  // The startup view names the plugin it is waiting on, and has to know when
  // there is none: a local file or a direct link is never handed to one.
  group('pluginFor', () {
    test('is the plugin resolution would ask', () {
      final plugin = FakePlugin(const []);
      final reader = readerOf([(activeProviderProvider, plugin), ...defaults]);

      expect(
        pluginFor(reader, itemWith(), 'https://example.com/episode/1'),
        same(plugin),
      );
    });

    test('is nobody for a local file or a torrent', () {
      final reader = readerOf(defaults);
      expect(
        pluginFor(reader, itemWith(provider: 'Local'), '/movies/a.mkv'),
        isNull,
      );
      expect(
        pluginFor(reader, itemWith(), 'magnet:?xt=urn:btih:abc'),
        isNull,
      );
    });
  });

  group('isLiveSource', () {
    MultimediaItem itemOf(MultimediaContentType type) => MultimediaItem(
      title: 'T',
      url: 'https://example.com/t',
      posterUrl: '',
      contentType: type,
    );

    test('a livestream item is live whatever the url looks like', () {
      expect(
        isLiveSource(
          itemOf(MultimediaContentType.livestream),
          'https://cdn.example/channel.m3u8',
        ),
        isTrue,
      );
    });

    test('live protocols are live even on a movie item', () {
      for (final url in const [
        'rtmp://a/b',
        'rtsp://a/b',
        'mms://a/b',
        'udp://a/b',
        'rtp://a/b',
      ]) {
        expect(isLiveSource(itemOf(MultimediaContentType.movie), url), isTrue,
            reason: url);
      }
    });

    test('a plain http movie is not live', () {
      expect(
        isLiveSource(itemOf(MultimediaContentType.movie), 'https://a/b.mp4'),
        isFalse,
      );
    });

    // However the item is labelled, these are files and seek normally.
    test('torrents and local files are never live', () {
      final live = itemOf(MultimediaContentType.livestream);
      expect(isLiveSource(live, 'magnet:?xt=urn:btih:abc'), isFalse);
      expect(isLiveSource(live, 'https://a/b.torrent'), isFalse);
      expect(isLiveSource(live, '/Users/me/Movies/a.mkv'), isFalse);
    });

    test('an empty url falls back to the content type', () {
      expect(isLiveSource(itemOf(MultimediaContentType.livestream), ''), isTrue);
      expect(isLiveSource(itemOf(MultimediaContentType.movie), ''), isFalse);
    });

    // Plugins routinely type an IPTV channel as `movie`, and believing them
    // costs live caching, the reconnect loop and a sane progress record.
    test('iptv url shapes are live even on a movie item', () {
      for (final url in const [
        'https://portal.example/live/user/pass/1234.m3u8',
        'https://portal.example/iptv/channel/9.ts',
        'https://edge.example/hls/stream.m3u8',
        'https://edge.example/app/chunklist_w1234567.m3u8',
        'https://portal.example/get.php?username=u&password=p&type=m3u8',
        'https://portal.example/get.php?username=u&password=p&output=m3u8',
      ]) {
        expect(
          isLiveSource(itemOf(MultimediaContentType.movie), url),
          isTrue,
          reason: url,
        );
      }
    });

    test('the url shapes are matched case-insensitively', () {
      expect(
        isLiveSource(
          itemOf(MultimediaContentType.movie),
          'https://Portal.example/LIVE/user/pass/1234.M3U8',
        ),
        isTrue,
      );
    });

    // The whole point of keeping the patterns narrow: an on-demand HLS ladder
    // is also .m3u8, and calling it live would break seeking and resume.
    test('ordinary hls vod stays vod', () {
      for (final url in const [
        'https://cdn.example/movies/inception/master.m3u8',
        'https://cdn.example/assets/1234/index.m3u8',
        'https://cdn.example/assets/1234/playlist.m3u8',
        'https://cdn.example/assets/1234/720p/prog_index.m3u8',
        'https://cdn.example/title.m3u8',
        'https://cdn.example/deliver.mp4?output=mp4',
      ]) {
        expect(
          isLiveSource(itemOf(MultimediaContentType.movie), url),
          isFalse,
          reason: url,
        );
      }
    });

    // A URL that names itself on-demand beats a shape we only guessed at:
    // Xtream serves VOD from /movie/ and /series/, and Wowza cuts on-demand
    // HLS into chunklists under /vod/.
    test('an explicit vod path outranks a live-looking url shape', () {
      for (final url in const [
        'https://host/vod/_definst_/mp4:a.mp4/chunklist_w1.m3u8',
        'https://portal.example/movie/user/pass/4567.mkv',
        'https://portal.example/series/user/pass/8910.mp4',
        'https://cdn.example/vod/hls/stream.m3u8',
      ]) {
        expect(
          isLiveSource(itemOf(MultimediaContentType.movie), url),
          isFalse,
          reason: url,
        );
      }
    });

    // The veto is a tie-breaker between guesses, not a licence to override the
    // plugin's own metadata.
    test('an explicit vod path does not override a livestream item', () {
      expect(
        isLiveSource(
          itemOf(MultimediaContentType.livestream),
          'https://cdn.example/vod/hls/stream.m3u8',
        ),
        isTrue,
      );
    });

    test('a local iptv-looking path is still vod', () {
      expect(
        isLiveSource(
          itemOf(MultimediaContentType.movie),
          '/Users/me/Movies/live/a.m3u8',
        ),
        isFalse,
      );
    });
  });

  group('isTorrentSource', () {
    StreamResult s(String url, String source) =>
        StreamResult(url: url, source: source);

    test('magnet links and .torrent files need the torrent service', () {
      expect(isTorrentSource(s('magnet:?xt=urn:btih:abc', 'Torrent')), isTrue);
      expect(isTorrentSource(s('https://a/b.torrent', 'Torrent')), isTrue);
    });

    test('an ordinary http stream does not', () {
      expect(isTorrentSource(s('https://cdn.example/a.mp4', '1080p')), isFalse);
    });

    // A bare absolute path is normally a local file; only a torrent-sourced
    // one is a seeded file the service already knows about.
    test('a bare path counts only when the source says Torrent', () {
      expect(isTorrentSource(s('/downloads/movie.mkv', 'Torrent')), isTrue);
      expect(isTorrentSource(s('/Users/me/Movies/a.mkv', 'Video')), isFalse);
    });
  });

  group('isUncheckableSource', () {
    test("covers a file TorrServer serves from a torrent it holds", () {
      // A pack file the viewer picked: its loopback address answers only
      // while that torrent is loaded, and a dead desktop server would read as
      // a network wait of five minutes.
      expect(
        isUncheckableSource(
          const StreamResult(
            url: 'http://127.0.0.1:8090/stream?link=abc&index=2&play',
            source: 'Torrent (S01E02.mkv)',
          ),
        ),
        isTrue,
      );
      expect(
        isUncheckableSource(
          const StreamResult(
            url: 'http://192.168.1.5:8090/stream?link=abc&index=2',
            source: 'LAN',
          ),
        ),
        isFalse,
        reason: "another machine's server is a server like any other",
      );
    });
  });
}
