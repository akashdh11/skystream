import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/core/extensions/base_provider.dart';
import 'package:skystream/core/extensions/extension_manager.dart';
import 'package:skystream/core/extensions/providers.dart';
import 'package:skystream/core/models/torrent_status.dart';
import 'package:skystream/core/services/torrent_service.dart';
import 'package:skystream/core/services/download_service.dart';
import 'package:skystream/core/storage/episode_watch_repository.dart';
import 'package:skystream/core/storage/history_repository.dart';
import 'package:skystream/features/player/presentation/vlc/panel/player_episodes_tab.dart';
import 'package:skystream/features/player/presentation/vlc/panel/player_panel.dart'
    show PlayerPanel;
import 'package:skystream/features/player/presentation/vlc/panel/player_panel_row.dart';
import 'package:skystream/features/player/presentation/vlc/panel/player_sources_tab.dart';
import 'package:skystream/features/player/presentation/vlc/panel/player_tracks_tab.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';

import 'fake_vlc_engine.dart';
import 'package:skystream/features/player/domain/network_buffer.dart';
import 'package:skystream/features/settings/presentation/player_settings_provider.dart';

import 'vlc_screen_harness.dart';

/// The panel as the screen drives it: Options opens the panel and the viewer
/// selects a tab. A pick reaches the engine, and a failover updates the panel
/// that is already up. The panel's own behaviour is pinned in
/// player_panel_test.dart; this file is about the wiring between the two.
///
/// An episode advance under an open panel is the one moment every input the
/// panel reads changes media at once, so most of what is here is about that.
///
/// A probe is made slow with `runWithClient` and a client that holds its
/// requests. A dead candidate refuses the probe's ranged GET - the client
/// throws - and answers the HEAD it falls back to with a 4xx. A live one
/// answers like a media server, serving the range: a plain 200 to a ranged
/// request says the server ignores ranges, which the row calls "Can't seek",
/// and a body the probe reads is a stream under flutter_test's fake async.
///
/// History with a position and a length for named episode URLs, so the panel
/// has something real to read. Everything else answers zero, as [NoHistory].
class _SeededHistory extends NoHistory {
  _SeededHistory({required this.positions, required this.durations});

  final Map<String, int> positions;
  final Map<String, int> durations;

  @override
  int getEpisodePosition(
    String url, {
    String? mainUrl,
    int? season,
    int? episode,
  }) => positions[url] ?? 0;

  @override
  int getEpisodeDuration(
    String url, {
    String? mainUrl,
    int? season,
    int? episode,
  }) => durations[url] ?? 0;
}

/// Episodes marked watched by hand from the details screen. An explicit mark
/// is the answer `isWatched` returns before it looks at a position at all.
class _MarkedWatched extends QuietEpisodeWatch {
  _MarkedWatched(this.urls);

  final Set<String> urls;

  @override
  bool? getExplicitState(String mainUrl, Episode episode) =>
      urls.contains(episode.url) ? true : null;
}

/// The episode row whose composed label mentions [needle]. Episode labels are
/// built from the number and the name (`S1 E2 - Ep 02`), so a test that means
/// "the row for episode 2" cannot match on the raw name.
Finder _episodeRow(String needle) => find.byWidgetPredicate(
  (widget) => widget is PanelRow && widget.label.contains(needle),
  skipOffstage: false,
);

/// The value of the progress bar across the foot of [needle]'s still, or null
/// when that row has none.
double? _rowBar(WidgetTester tester, String needle) {
  final bars = tester
      .widgetList<LinearProgressIndicator>(
        find.descendant(
          of: _episodeRow(needle),
          matching: find.byType(LinearProgressIndicator, skipOffstage: false),
        ),
      )
      .toList();
  expect(bars.length, lessThanOrEqualTo(1), reason: 'one bar per row at most');
  return bars.isEmpty ? null : bars.single.value;
}

void main() {
  late FakeVlcEngine engine;

  setUp(() {
    engine = FakeVlcEngine();
    installEngineMocks(engine: engine);
  });
  tearDown(removeEngineMocks);

  Future<AppLocalizations> english() =>
      AppLocalizations.delegate.load(const Locale('en'));

  /// Bare paths, so the resolver's health probe answers without a socket.
  const streams = <StreamResult>[
    StreamResult(url: '/sources/alpha.mkv', source: 'Alpha', providerName: 'A'),
    StreamResult(url: '/sources/beta.mkv', source: 'Beta', providerName: 'B'),
    StreamResult(url: '/sources/gamma.mkv', source: 'Gamma', providerName: 'C'),
  ];

  /// The labels of the rows showing the tick.
  List<String> selectedRows(WidgetTester tester) => tester
      .widgetList<PanelRow>(find.byType(PanelRow, skipOffstage: false))
      .where((row) => row.selected)
      .map((row) => row.label)
      .toList();

  /// Opens the panel from the bottom bar, the way a remote does, and waits
  /// out the slide-in.
  Future<void> openFromBar(WidgetTester tester, String tooltip) async {
    final l10n = await english();
    await tester.tap(find.byTooltip(l10n.options));
    await settle(tester);
    await tester.tap(
      find.text(tooltip == l10n.audioTracks ? l10n.audio : tooltip),
    );
    await settle(tester);
    expect(find.byType(PlayerPanel), findsOneWidget);
  }

  /// Whether whatever holds focus is inside the panel.
  ///
  /// The alternative is the enclosing route scope, where focus lands when
  /// every row that could hold it unmounts. A remote cannot get out of that
  /// state, and the player's focus rules forbid it.
  bool focusInPanel() =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<PlayerPanel>() !=
      null;

  /// The labels of every source row the open panel is showing.
  List<String> sourceRows(WidgetTester tester) => tester
      .widgetList<PanelRow>(
        find.descendant(
          of: find.byType(PlayerSourcesTab, skipOffstage: false),
          matching: find.byType(PanelRow, skipOffstage: false),
        ),
      )
      .map((row) => row.label)
      .toList();

  /// A two-episode show whose first episode is handed in already resolved and
  /// whose second has to be resolved through a plugin. The episode swap is the
  /// one place the panel's inputs change media underneath it.
  final firstEpisode = Episode(
    name: 'Ep 01',
    url: 'https://example.com/e1.mp4',
    season: 1,
    episode: 1,
  );
  final nextEpisode = Episode(
    name: 'Ep 02',
    url: 'https://example.com/e2.mp4',
    season: 1,
    episode: 2,
  );
  final show = MultimediaItem(
    title: 'Show',
    url: 'https://example.com/show',
    posterUrl: '',
    contentType: MultimediaContentType.series,
    episodes: [firstEpisode, nextEpisode],
    // Matched by name against the plugins the extension manager lists, which
    // is how the next episode gets resolved at all.
    provider: _FakePlugin.pluginName,
  );

  /// The same three candidates over http, so that their health probe goes
  /// through the client the test installs and can be held in flight.
  const probedStreams = <StreamResult>[
    StreamResult(
      url: 'https://cdn.test/alpha.mkv',
      source: 'Alpha',
      providerName: 'A',
    ),
    StreamResult(
      url: 'https://cdn.test/beta.mkv',
      source: 'Beta',
      providerName: 'B',
    ),
    StreamResult(
      url: 'https://cdn.test/gamma.mkv',
      source: 'Gamma',
      providerName: 'C',
    ),
  ];

  /// What the plugin answers for the second episode. Bare paths again, so its
  /// probe needs no socket.
  const nextStreams = <StreamResult>[
    StreamResult(url: '/sources/delta.mkv', source: 'Delta', providerName: 'D'),
    StreamResult(
      url: '/sources/epsilon.mkv',
      source: 'Epsilon',
      providerName: 'E',
    ),
  ];

  /// The second episode's candidates over http, so that its probe is the one
  /// held in flight.
  const probedNextStreams = <StreamResult>[
    StreamResult(
      url: 'https://cdn.test/delta.mkv',
      source: 'Delta',
      providerName: 'D',
    ),
    StreamResult(
      url: 'https://cdn.test/epsilon.mkv',
      source: 'Epsilon',
      providerName: 'E',
    ),
  ];

  /// The show playing its first episode, with the disk lookup every advance
  /// opens with held shut so the advance can be looked at halfway through.
  ///
  /// Hands back a getter: the download service is built the first time the
  /// advance reads it, which is after this returns.
  Future<GatedDownloads Function()> pumpShow(
    WidgetTester tester, {
    List<StreamResult> episodeOne = streams,
    List<StreamResult> episodeTwo = nextStreams,
  }) async {
    late GatedDownloads downloads;
    await pumpPlayer(
      tester,
      item: show,
      episode: firstEpisode,
      videoUrl: firstEpisode.url,
      preloadedStreams: episodeOne,
      overrides: [
        downloadServiceProvider.overrideWith(
          (ref) => downloads = GatedDownloads(ref),
        ),
        extensionManagerProvider.overrideWith(
          () => _FakeExtensions(
            _FakePlugin(<String, List<StreamResult>>{
              nextEpisode.url: episodeTwo,
            }),
          ),
        ),
      ],
    );
    return () => downloads;
  }

  testWidgets(
    'an episode advance under an open panel drops the finished episode\'s '
    'sources instead of leaving them to be picked',
    variant: texturePlatform,
    (tester) async {
      final downloads = await pumpShow(tester);
      await sendFirstFrame(tester, showControls: true);
      final l10n = await english();

      await openFromBar(tester, l10n.sources);
      expect(sourceRows(tester), <String>['Alpha', 'Beta', 'Gamma']);
      expect(selectedRows(tester), <String>['Alpha']);

      // The episode runs out with the panel still up and the next one starts
      // resolving, which for a torrent takes minutes. The near-end position is
      // load-bearing: an ending with no numbers behind it is a truncated
      // stream, which the screen fails over rather than advancing on.
      await sendEvent(tester, snapshot(position: 1199000, duration: 1200000));
      await sendEvent(tester, snapshot(state: 'ended'));
      await settle(tester);

      expect(find.byType(PlayerPanel), findsOneWidget, reason: 'still up');
      expect(
        sourceRows(tester),
        isEmpty,
        reason:
            'the keep-previous rule is about a re-resolve of the same media. '
            'Kept across an advance it left the viewer reading the finished '
            'episode\'s source list, with no tick on it, and a pick there '
            'acted on media that is no longer playing',
      );
      expect(find.widgetWithText(PanelRow, 'Alpha'), findsNothing);
      expect(
        focusInPanel(),
        isTrue,
        reason:
            'the tab the viewer was on went away with the list, so the panel '
            'has to hand focus to the one that replaced it. Falling back to '
            'the route scope is the one state the player\'s focus rules '
            'forbid, and on a remote it is a dead panel',
      );

      // The new episode's own list arrives and the tab comes back with it, so
      // nothing is stranded: a remote has rows to land on again.
      downloads().gate.complete();
      await settle(tester);

      expect(find.byType(PlayerPanel), findsOneWidget, reason: 'still up');
      expect(sourceRows(tester), <String>['Delta', 'Epsilon']);
      expect(selectedRows(tester), <String>['Delta']);
      expect(focusInPanel(), isTrue, reason: 'and again when it comes back');

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a probe still in flight from the finished episode cannot chip the new '
    'episode\'s rows',
    variant: texturePlatform,
    (tester) async {
      // Alpha answers at once, so the first episode opens on it; Beta and
      // Gamma are held, which is what a real probe against a slow CDN does -
      // the resolve returns the moment the best candidate is known and the
      // losing probes keep running for seconds behind it.
      final held = Completer<void>();
      final client = MockClient((request) async {
        // Alpha, and the next episode's own two, answer at once.
        for (final instant in const <String>['alpha', 'delta', 'epsilon']) {
          if (request.url.path.contains(instant)) {
            return http.Response(
              '',
              206,
              headers: {
                'content-type': 'video/x-matroska',
                'content-range': 'bytes 0-1023/1048576',
              },
            );
          }
        }
        await held.future;
        // A refused ranged GET sends the probe on to a HEAD, and a 4xx there
        // is how a dead candidate reads on the wire.
        if (request.method == 'HEAD') return http.Response('', 404);
        throw http.ClientException('refused', request.url);
      });

      await http.runWithClient(() async {
        // The next episode's sources are real links, not bare paths: a path
        // is a local file the probe cannot look at, so its row would say
        // Unknown whatever a stray probe claimed - and prove nothing here.
        final downloads = await pumpShow(
          tester,
          episodeOne: probedStreams,
          episodeTwo: probedNextStreams,
        );
        await sendFirstFrame(tester, showControls: true);
        final l10n = await english();
        // The panel's own chips. The startup view behind it lists the same
        // sources while the next episode opens, with its own wording for the
        // row being opened.
        Finder inPanel(String text) => find.descendant(
          of: find.byType(PlayerSourcesTab),
          matching: find.text(text),
        );

        await openFromBar(tester, l10n.sources);
        expect(sourceRows(tester), <String>['Alpha', 'Beta', 'Gamma']);
        expect(
          find.text(l10n.playerSourceChecking),
          findsNWidgets(2),
          reason: 'Beta and Gamma are still being probed, which is the point',
        );

        // The episode ends under the open panel and the next one resolves.
        // Two candidates, both instantly healthy, so every chip on screen from
        // here is one this episode's own probe put there. The near-end
        // position is load-bearing: an ending with no numbers behind it is a
        // truncated stream, which the screen fails over rather than advancing
        // on.
        await sendEvent(tester, snapshot(position: 1199000, duration: 1200000));
        await sendEvent(tester, snapshot(state: 'ended'));
        downloads().gate.complete();
        await settle(tester);
        expect(sourceRows(tester), <String>['Delta', 'Epsilon']);
        expect(inPanel(l10n.playerSourceReachable), findsNWidgets(2));

        // Now the finished episode's probes answer. They are keyed by index
        // into a list that is not on screen any more.
        held.complete();
        await settle(tester);

        expect(
          find.text(l10n.unknown),
          findsNothing,
          reason:
              'a probe belongs to the resolve that asked for it. Index 1 of '
              'the previous episode\'s candidates is not index 1 of this '
              'one\'s, and marking it unreachable says the new source is dead',
        );
        expect(sourceRows(tester), <String>['Delta', 'Epsilon']);
        expect(inPanel(l10n.playerSourceReachable), findsNWidgets(2));

        await tester.pumpWidget(const SizedBox());
      }, () => client);
    },
  );

  testWidgets(
    'the next episode\'s own candidates hold the Sources tab through its '
    'probe, and a pick there plays that row',
    variant: texturePlatform,
    (tester) async {
      // The window that reaches both halves of the keep-previous rule: the
      // next episode's candidate list is known and its probe has not answered,
      // so the tab has rows for a remote to land on and nothing resolved
      // behind them to switch away from.
      final held = Completer<void>();
      final client = MockClient((request) async {
        await held.future;
        if (request.method == 'HEAD') return http.Response('', 404);
        throw http.ClientException('refused', request.url);
      });

      await http.runWithClient(() async {
        final downloads = await pumpShow(tester, episodeTwo: probedNextStreams);
        await sendFirstFrame(tester, showControls: true);
        final l10n = await english();

        await openFromBar(tester, l10n.sources);
        // A minute from the end, then end of media. An ending with no numbers
        // behind it is a truncated stream, which the screen fails over rather
        // than advancing on.
        await sendEvent(tester, snapshot(position: 1199000, duration: 1200000));
        await sendEvent(tester, snapshot(state: 'ended'));
        downloads().gate.complete();
        await settle(tester);

        expect(
          sourceRows(tester),
          <String>['Delta', 'Epsilon'],
          reason:
              'the candidates arrive before the resolution, and the list '
              'stands from then on. Emptied here, the focused row would '
              'unmount and nothing in the panel would hold focus',
        );
        expect(
          find.descendant(
            of: find.byType(PlayerSourcesTab),
            matching: find.text(l10n.playerSourceChecking),
          ),
          findsNWidgets(2),
          reason: 'the panel, not the startup view behind it listing the same',
        );
        expect(
          selectedRows(tester),
          isEmpty,
          reason: 'nothing is playing, so no row wears the tick',
        );
        final opened = engine.callsTo('setSource').length;

        await tester.tap(find.widgetWithText(PanelRow, 'Epsilon'));
        await settle(tester);

        // The list on screen is this resolve's own, so the row the viewer
        // chose means what it says: the check ends on it rather than the
        // press doing nothing until the probe decides for them.
        expect(
          engine.callsTo('setSource'),
          hasLength(opened + 1),
          reason: 'a pick during the check ends it on that row',
        );
        expect(
          (engine.callsTo('setSource').last.arguments as Map)['uri'],
          'https://cdn.test/epsilon.mkv',
        );

        // Let the resolve finish so no probe is left in flight.
        held.complete();
        await settle(tester);

        await tester.pumpWidget(const SizedBox());
      }, () => client);
    },
  );

  testWidgets(
    'the torrent server gets the buffer the viewer chose, split to keep some '
    'of it behind the playhead',
    variant: texturePlatform,
    (tester) async {
      // One number for both engines. libVLC takes it as a prefetch window and
      // TorrServer as its piece cache; the cache used to be a hard-coded
      // 64 MB, so the setting moved one engine and not the other.
      final torrents = _FakeTorrents();
      await pumpPlayer(
        tester,
        settings: const PlayerSettings(networkBufferMb: 256),
        overrides: [torrentServiceProvider.overrideWithValue(torrents)],
      );
      await sendFirstFrame(tester, showControls: true);

      expect(torrents.cacheMb, 256, reason: 'the chosen size, not a constant');
      expect(
        torrents.readAheadPercent,
        torrentReadAheadPercent(256),
        reason: 'and the split that leaves a backward window behind it',
      );
      // The remainder is the only backward buffer this player has anywhere:
      // libVLC 3's prefetch filter takes a size and decides the rest itself.
      final behindMb = 256 * (100 - torrents.readAheadPercent!) / 100;
      expect(
        behindMb,
        greaterThanOrEqualTo(8),
        reason: 'enough for the ten second step the seek controls take',
      );

      await sendEvent(tester, snapshot(state: 'paused'));
    },
  );

  testWidgets(
    'a hand-picked pack file drops season and episode from the subtitle '
    'search target',
    variant: texturePlatform,
    (tester) async {
      final torrents = _FakeTorrents();
      await pumpPlayer(
        tester,
        item: show,
        episode: firstEpisode,
        videoUrl: firstEpisode.url,
        preloadedStreams: const <StreamResult>[
          StreamResult(
            url: 'magnet:?xt=urn:btih:pack',
            source: 'Torrent Pack',
            providerName: 'T',
          ),
        ],
        overrides: [
          torrentServiceProvider.overrideWithValue(torrents),
          // The show names a plugin, so resolution asks the extension
          // manager for it - and the real one wants a JS engine.
          extensionManagerProvider.overrideWith(
            () => _FakeExtensions(
              _FakePlugin(const <String, List<StreamResult>>{}),
            ),
          ),
        ],
      );
      await sendFirstFrame(tester, showControls: true);
      final l10n = await english();

      // Opened first and left up: the file list arrives from the three-second
      // poll, and the bars would have hidden themselves by then.
      await openFromBar(tester, l10n.subtitles);
      var target = tester
          .widget<PlayerTracksTab>(find.byType(PlayerTracksTab))
          .target;
      expect(
        (target?.season, target?.episode),
        (1, 1),
        reason: 'the URL match says episode one is playing, and it is',
      );

      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.tap(find.text(l10n.playerFiles));
      await settle(tester);
      expect(find.widgetWithText(PanelRow, 'S01E02.mkv'), findsOneWidget);

      // The viewer picks the second file out of the pack by hand. What is
      // playing is now whatever that file is - not the episode the URL match
      // named - so a subtitle search scoped to S01E01 would be scoped to the
      // wrong episode.
      await tester.tap(find.widgetWithText(PanelRow, 'S01E02.mkv'));
      await settle(tester);
      expect(find.byType(PlayerPanel), findsNothing, reason: 'closed on pick');

      // The pick reopens the engine on the new file, so the chrome only comes
      // back once that file has produced a frame.
      await sendEvent(tester, snapshot(position: 2000));
      await settle(tester);

      await openFromBar(tester, l10n.subtitles);
      target = tester
          .widget<PlayerTracksTab>(find.byType(PlayerTracksTab))
          .target;
      expect(target?.title, 'Show', reason: 'the show is still the show');
      expect(
        (target?.season, target?.episode),
        (null, null),
        reason:
            'a hand-picked pack file may not be the episode the screen '
            'thinks is playing, so the search is scoped to the show rather '
            'than to an episode it cannot vouch for',
      );

      await tester.pumpWidget(const SizedBox());
    },
  );

  // A picture on screen is proof the check cannot beat: the source playing
  // reads reachable even where the probe never looked, as with a local file.
  testWidgets(
    'the source on screen never says it was not checked',
    variant: texturePlatform,
    (tester) async {
      await pumpPlayer(
        tester,
        preloadedStreams: const <StreamResult>[
          StreamResult(url: '/sources/alpha.mkv', source: 'Alpha'),
          StreamResult(url: '/sources/beta.mkv', source: 'Beta'),
        ],
      );
      await sendFirstFrame(tester, showControls: true);
      final l10n = await english();
      await openFromBar(tester, l10n.sources);

      Finder chipIn(String row, String text) => find.descendant(
        of: find.ancestor(of: find.text(row), matching: find.byType(PanelRow)),
        matching: find.text(text),
      );
      expect(chipIn('Alpha', l10n.playerSourceReachable), findsOneWidget);
      expect(chipIn('Alpha', l10n.playerSourceNotChecked), findsNothing);
      expect(
        chipIn('Beta', l10n.playerSourceNotChecked),
        findsOneWidget,
        reason: 'a local file nobody has played is still not checked',
      );

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Audio opens on Audio', variant: texturePlatform, (tester) async {
    await pumpPlayer(tester, preloadedStreams: streams);
    await sendFirstFrame(tester, showControls: true);
    final l10n = await english();

    await openFromBar(tester, l10n.audioTracks);

    expect(find.text(l10n.noAudioTracksReported), findsOneWidget);
    expect(find.byType(PlayerSourcesTab), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Episodes opens on Episodes', variant: texturePlatform, (
    tester,
  ) async {
    final episodes = List<Episode>.generate(
      3,
      (i) => Episode(
        name: 'Ep 0${i + 1}',
        url: 'https://example.com/e${i + 1}.mp4',
        season: 1,
        episode: i + 1,
      ),
    );
    final show = MultimediaItem(
      title: 'Show',
      url: 'https://example.com/show',
      posterUrl: '',
      contentType: MultimediaContentType.series,
      episodes: episodes,
      provider: 'Remote',
    );
    await pumpPlayer(
      tester,
      item: show,
      episode: episodes[1],
      videoUrl: episodes[1].url,
    );
    await sendFirstFrame(tester, showControls: true);
    final l10n = await english();

    await openFromBar(tester, l10n.episodes);

    expect(find.byType(PlayerEpisodesTab), findsOneWidget);
    expect(find.textContaining('Ep 01'), findsOneWidget);
    expect(find.textContaining('Ep 03'), findsOneWidget);
    expect(
      selectedRows(tester).single,
      contains('Ep 02'),
      reason: 'the episode playing carries the tick',
    );

    await tester.pumpWidget(const SizedBox());
  });

  // The only test that proves the panel's watched marks are wired up.
  // player_panel_test.dart hands `episodeProgress` straight to the widget, so
  // it passes whether or not anything in the app ever supplies one. The screen
  // is the only possible supplier: the panel has no ProviderScope of its own
  // to read the two stores from.
  testWidgets(
    'the Episodes tab reads the real stores through the screen',
    variant: texturePlatform,
    (tester) async {
      final episodes = List<Episode>.generate(
        3,
        (i) => Episode(
          name: 'Ep 0${i + 1}',
          url: 'https://example.com/e${i + 1}.mp4',
          season: 1,
          episode: i + 1,
        ),
      );
      final show = MultimediaItem(
        title: 'Show',
        url: 'https://example.com/show',
        posterUrl: '',
        contentType: MultimediaContentType.series,
        episodes: episodes,
        provider: 'Remote',
      );
      await pumpPlayer(
        tester,
        item: show,
        // Episode one plays, so neither seeded row is the current one - the
        // tab suppresses the bar and the dim on whatever is playing.
        episode: episodes[0],
        videoUrl: episodes[0].url,
        overrides: [
          historyRepositoryProvider.overrideWithValue(
            _SeededHistory(
              positions: <String, int>{episodes[1].url: 300000},
              durations: <String, int>{episodes[1].url: 1000000},
            ),
          ),
          episodeWatchRepositoryProvider.overrideWithValue(
            _MarkedWatched(<String>{episodes[2].url}),
          ),
        ],
      );
      await sendFirstFrame(tester, showControls: true);
      final l10n = await english();

      await openFromBar(tester, l10n.episodes);

      expect(
        _rowBar(tester, 'Ep 02'),
        moreOrLessEquals(0.3, epsilon: 0.001),
        reason: 'three tenths of a stored episode, read through the screen',
      );
      expect(_rowBar(tester, 'Ep 01'), isNull, reason: 'nothing stored');
      expect(
        _rowBar(tester, 'Ep 03'),
        isNull,
        reason: 'marked watched by hand outranks any position',
      );
      expect(
        find.descendant(
          of: _episodeRow('Ep 03'),
          matching: find.text(l10n.watched),
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'the Now playing tick follows a failover while the panel is open',
    variant: texturePlatform,
    (tester) async {
      await pumpPlayer(tester, preloadedStreams: streams);
      await sendFirstFrame(tester, showControls: true);
      final l10n = await english();

      await openFromBar(tester, l10n.sources);
      expect(selectedRows(tester), <String>['Alpha']);

      // The engine gives up on the source twice. The first error is a
      // same-source retry - it had produced frames - and the second, with no
      // frame since, walks the ladder to the next candidate. The panel is a
      // route above the screen and never re-opened; the tick has to come to
      // it.
      await sendEvent(tester, snapshot(state: 'error', position: 1600));
      await settle(tester);
      await sendEvent(tester, snapshot(state: 'error', position: 1700));
      await settle(tester);

      expect(find.byType(PlayerPanel), findsOneWidget, reason: 'still up');
      expect(selectedRows(tester), <String>['Beta']);

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a source pick from the panel reaches the engine and the panel closes',
    variant: texturePlatform,
    (tester) async {
      await pumpPlayer(tester, preloadedStreams: streams);
      await sendFirstFrame(tester, showControls: true);
      final l10n = await english();

      await openFromBar(tester, l10n.sources);
      final opened = engine.callsTo('setSource').length;

      await tester.tap(find.widgetWithText(PanelRow, 'Gamma'));
      await settle(tester);

      expect(find.byType(PlayerPanel), findsNothing, reason: 'closed first');
      final sources = engine.callsTo('setSource');
      expect(sources.length, opened + 1, reason: 'one open for the pick');
      expect(
        (sources.last.arguments as Map)['uri'].toString(),
        contains('gamma'),
      );

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'the failed stage takes the tick off, and re-picking the dead source '
    'retries instead of doing nothing',
    variant: texturePlatform,
    (tester) async {
      await pumpPlayer(tester, preloadedStreams: streams);
      await sendFirstFrame(tester, showControls: true);
      final l10n = await english();

      // Opened while the first source is playing, and left up: the panel is a
      // route above the screen, so the failure has to reach it. Opening it
      // from the failure frame instead cannot be exercised here - that frame
      // has no VlcPlayer, so PlayerPanel.initState asks a detached controller
      // for its track lists and the rejection fails the test.
      await openFromBar(tester, l10n.sources);
      expect(selectedRows(tester), <String>['Alpha']);

      // Every candidate dies. The first error is a same-source retry (Alpha
      // had produced frames); after that no attempt ever sees one, so each
      // error walks the ladder until it runs out and the screen fails.
      for (final position in <int>[1600, 1700, 1800, 1900, 2000, 2100]) {
        await sendEvent(tester, snapshot(state: 'error', position: position));
        await settle(tester);
      }
      expect(
        find.widgetWithText(FilledButton, l10n.retry),
        findsOneWidget,
        reason: 'the ladder ran out and the failure frame is behind the panel',
      );

      // Nothing is playing, so nothing may wear the tick: the candidate that
      // just died is still in _attemptIndex, and publishing it would badge a
      // dead source 'Now playing' and anchor the remote on it.
      expect(find.byType(PlayerSourcesTab), findsOneWidget, reason: 'still up');
      expect(
        selectedRows(tester),
        isEmpty,
        reason: 'no source is playing in the failed stage',
      );
      expect(find.text(l10n.playerNowPlaying), findsNothing);

      // Picking the candidate the ladder died on is a deliberate 'try that one
      // again', not a press that closes the panel and does nothing at all.
      await tester.tap(find.widgetWithText(PanelRow, 'Gamma'));
      await settle(tester);

      expect(find.byType(PlayerPanel), findsNothing, reason: 'closed first');
      expect(
        find.widgetWithText(FilledButton, l10n.retry),
        findsNothing,
        reason: 'the pick left the failed stage and opened the source again',
      );

      await tester.pumpWidget(const SizedBox());
    },
  );
}

/// A plugin that answers `loadStreams` from a table.
///
/// The next episode has no preloaded streams - they belong to the first one -
/// so without a plugin an advance can only resolve a direct URL, which is a
/// one-source list and no Sources tab at all.
class _FakePlugin extends SkyStreamProvider {
  _FakePlugin(this.streamsByUrl);

  static const String pluginName = 'Fake Plugin';

  final Map<String, List<StreamResult>> streamsByUrl;

  @override
  String get packageName => 'fake.plugin';
  @override
  String get name => pluginName;
  @override
  String get mainUrl => 'https://example.com';
  @override
  String get version => '1.0.0';
  @override
  List<String> get languages => const <String>['en'];
  @override
  Set<ProviderType> get supportedTypes => <ProviderType>{ProviderType.series};

  @override
  Future<List<MultimediaItem>> search(
    String query, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
  @override
  Future<Map<String, List<MultimediaItem>>> getHome() =>
      throw UnimplementedError();
  @override
  Future<MultimediaItem> getDetails(String url) => throw UnimplementedError();

  @override
  Future<List<StreamResult>> loadStreams(String url) async =>
      streamsByUrl[url] ?? const <StreamResult>[];
}

/// The extension manager with one plugin in it and no JS engine behind it.
class _FakeExtensions extends ExtensionManager {
  _FakeExtensions(this.plugin);

  final SkyStreamProvider plugin;

  @override
  List<SkyStreamProvider> build() => <SkyStreamProvider>[plugin];
}

/// A torrent server with one two-episode pack in it.
///
/// Implemented rather than extended: the real service is a singleton with a
/// private constructor, and standing one up would start a real server.
class _FakeTorrents implements TorrentService {
  /// What the player asked the server to hold, so a test can check that the
  /// viewer's buffer setting reaches both engines rather than just libVLC.
  int? cacheMb;
  int? readAheadPercent;

  @override
  Future<void> applyBufferSettings({
    required int cacheMb,
    required int readAheadPercent,
  }) async {
    this.cacheMb = cacheMb;
    this.readAheadPercent = readAheadPercent;
  }

  @override
  Future<TorrentStatus?> getCurrentStatus() async =>
      TorrentStatus.fromMap(<dynamic, dynamic>{
        'title': 'Pack',
        'stat_string': 'Seeding',
        'file_stats': <dynamic>[
          <dynamic, dynamic>{'id': 0, 'path': 'Pack/S01E01.mkv', 'length': 10},
          <dynamic, dynamic>{'id': 1, 'path': 'Pack/S01E02.mkv', 'length': 20},
        ],
      });

  @override
  Future<String?> getStreamUrl(String magnetLink) async =>
      'http://127.0.0.1:9/pack/0';

  @override
  Future<String?> getStreamUrlForFileIndex(int index) async =>
      'http://127.0.0.1:9/pack/$index';

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}
