import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/features/player/domain/entity/subtitle_model.dart';
import 'package:skystream/features/player/domain/stream_resolver.dart';
import 'package:skystream/features/player/domain/subtitle_search_target.dart';
import 'package:skystream/features/player/presentation/subtitle_search_provider.dart';
import 'package:skystream/features/player/presentation/vlc/panel/player_anchored_list.dart';
import 'package:skystream/features/player/presentation/vlc/panel/player_episodes_tab.dart';
import 'package:skystream/features/player/presentation/vlc/panel/player_files_tab.dart';
import 'package:skystream/features/player/presentation/vlc/panel/player_panel.dart';
import 'package:skystream/features/player/presentation/vlc/panel/player_panel_metrics.dart';
import 'package:skystream/features/player/presentation/vlc/panel/player_panel_row.dart';
import 'package:skystream/features/player/presentation/vlc/panel/player_panel_shell.dart';
import 'package:skystream/features/player/presentation/vlc/panel/player_sources_tab.dart';
import 'package:skystream/features/player/presentation/vlc/panel/player_subtitle_search_page.dart';
import 'package:skystream/features/player/presentation/vlc/torrent_file_sheet.dart';
import 'package:skystream/features/player/presentation/widgets/hotstar_player_style.dart';
import 'package:skystream/features/settings/presentation/player_settings_provider.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';
import 'package:vlc_player/vlc_player.dart';

import 'fake_vlc_engine.dart';

/// The panel is the one thing on this screen a viewer *navigates* rather than
/// glances at, so what is pinned here is navigation: focus enters it, focus
/// comes back out to where it started, Back closes the panel and not the
/// player, and each row is exactly one stop on the way down. The rest - badges,
/// the now-playing marker, the shape it takes - is what the sheets it replaces
/// could not show at all.
const Size _tv = Size(2560, 1440);
const Size _phone = Size(390, 844);

/// A 1080p television at the density Android TV actually reports: 960x540 dp,
/// which is where a panel list is short enough that "built" and "on screen"
/// stop being the same thing.
const Size _googleTv = Size(960, 540);

/// A snapshot that moves nothing but keeps the controller's stall watchdog
/// unarmed: a playing snapshot leaves a 1 s timer pending, and flutter_test
/// checks pending timers before any tear-down runs.
const Map<String, Object?> _paused = <String, Object?>{'state': 'paused'};

/// Delivers the fake's current state to the controller and draws the frame
/// that follows it - what a native's forced snapshot after a track call does.
Future<void> _sync(WidgetTester tester, FakeVlcEngine engine) async {
  await engine.emit(_paused);
  await tester.pump();
}

/// Presses DOWN until the delay stepper holds focus. The stepper is the last
/// stop on both track tabs; anything else is what the panel walked through
/// on the way.
Future<void> _focusStepper(WidgetTester tester) async {
  for (var i = 0; i < 10 && !_stepperFocused(); i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
  }
  expect(_stepperFocused(), isTrue, reason: 'the stepper is reachable');
}

/// The `delay` argument (microseconds) of the last [method] call the engine
/// saw, or null when it never was.
int? _lastDelay(FakeVlcEngine engine, String method) {
  final calls = engine.callsTo(method);
  if (calls.isEmpty) return null;
  return (calls.last.arguments as Map<Object?, Object?>)['delay'] as int?;
}

/// Walks the render tree for an opacity or filter layer covering more than
/// 40 % of a television - the kind that is re-surfaced on every repaint over
/// a platform view and blacks the video out.
void _expectNoLargeEffectLayer(WidgetTester tester) {
  const privateFilters = <String>{
    '_ColorFilterRenderObject',
    '_ImageFilterRenderObject',
  };
  final offenders = <RenderBox>[];
  void visit(RenderObject node) {
    if (node is RenderAnimatedOpacity ||
        node is RenderOpacity ||
        node is RenderBackdropFilter ||
        node is RenderShaderMask ||
        privateFilters.contains(node.runtimeType.toString())) {
      final box = node as RenderBox;
      final bounds = box.paintBounds;
      if ((bounds.width * bounds.height) / (_tv.width * _tv.height) > 0.4) {
        offenders.add(box);
      }
    }
    node.visitChildren(visit);
  }

  visit(tester.binding.rootElement!.renderObject!);

  expect(
    offenders,
    isEmpty,
    reason:
        'the panel is composited over a platform view: an opacity or '
        'filter layer this large is re-surfaced on every repaint and '
        'blacks the video out. It slides in; it does not fade.',
  );
}

/// Drives a focused delay stepper through every way it can be moved and
/// checks what reached the engine and what came back on screen: a press is a
/// fine 100 ms step, a repeat (the key held) a coarse 500 ms one, the read-out
/// is milliseconds under a second and seconds above it, and Select resets.
Future<void> _exerciseDelayStepper(
  WidgetTester tester,
  FakeVlcEngine engine,
  String method,
) async {
  const ms = Duration.microsecondsPerMillisecond;

  // The row fires the engine call unawaited; a frame lets it reach the fake.
  Future<void> press(Future<bool> Function() send) async {
    await send();
    await tester.pump();
  }

  await press(() => tester.sendKeyEvent(LogicalKeyboardKey.arrowRight));
  expect(_lastDelay(engine, method), 100 * ms, reason: 'a press is fine');
  await _sync(tester, engine);
  expect(find.text('+100ms'), findsOneWidget);

  // A held key: one down, then repeats. Each repeat is a coarse step on top
  // of whatever the engine has echoed back by then.
  await press(() => tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight));
  expect(_lastDelay(engine, method), 200 * ms);
  await _sync(tester, engine);
  await press(() => tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight));
  expect(_lastDelay(engine, method), 700 * ms, reason: 'a repeat is coarse');
  await _sync(tester, engine);
  expect(find.text('+700ms'), findsOneWidget);
  await press(() => tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight));
  expect(_lastDelay(engine, method), 1200 * ms);
  await _sync(tester, engine);
  expect(find.text('+1.2s'), findsOneWidget, reason: 'seconds from 1 s up');
  await press(() => tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight));
  expect(_lastDelay(engine, method), 1200 * ms, reason: 'release is no step');

  await press(() => tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft));
  expect(_lastDelay(engine, method), 1100 * ms);
  await _sync(tester, engine);
  expect(find.text('+1.1s'), findsOneWidget);

  await press(() => tester.sendKeyEvent(LogicalKeyboardKey.select));
  expect(_lastDelay(engine, method), 0, reason: 'Select resets');
  await _sync(tester, engine);
  expect(find.text('+0ms'), findsOneWidget);

  await press(() => tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft));
  expect(_lastDelay(engine, method), -100 * ms);
  await _sync(tester, engine);
  expect(find.text('-100ms'), findsOneWidget);

  expect(
    _stepperFocused(),
    isTrue,
    reason: 'Left/Right never left the row, held or not',
  );
}

/// One engine track, in the shape the fake engine answers with.
Map<String, Object?> _track(int id, String name, {String? language}) =>
    <String, Object?>{'id': id, 'name': name, 'language': ?language};

/// A track-rich remux: ids that are also list positions, so a test can name
/// the row it expects to be focused by the id it switched on.
List<Map<String, Object?>> _manyTracks(int count, {String prefix = 'Sub'}) =>
    List<Map<String, Object?>>.generate(count, (i) => _track(i, '$prefix $i'));

List<StreamResult> _sources() => <StreamResult>[
  const StreamResult(
    url: 'https://a.test/one',
    source: '1080p · 2.13 GB · 👤 45',
    providerName: 'Torrentio',
  ),
  const StreamResult(
    url: 'https://b.test/two',
    source: '720p',
    providerName: 'Vidsrc',
  ),
  const StreamResult(
    url: 'https://c.test/three',
    source: 'Server 3',
    providerName: 'Upcloud',
  ),
];

/// Three sources over two tiers, with titles that are not their own badges:
/// `1080p` is a pill, a badge and part of a row label at once, and only a
/// distinct title lets a finder say which of the three it meant.
List<StreamResult> _tieredSources() => <StreamResult>[
  const StreamResult(
    url: 'https://a.test/alpha',
    source: 'Alpha 1080p',
    providerName: 'Torrentio',
  ),
  const StreamResult(
    url: 'https://b.test/bravo',
    source: 'Bravo 720p',
    providerName: 'Vidsrc',
  ),
  const StreamResult(
    url: 'https://c.test/charlie',
    source: 'Charlie 1080p',
    providerName: 'Upcloud',
  ),
];

Episode _episode(int number) => Episode(
  name: 'Episode $number',
  url: 'https://series.test/$number',
  season: 1,
  episode: number,
);

/// [count] plain sources, `Server 0` .. `Server n`, for the anchoring tests.
List<StreamResult> _manySources(int count) => List<StreamResult>.generate(
  count,
  (i) => StreamResult(
    url: 'https://many.test/$i',
    source: 'Server $i',
    providerName: 'Many',
  ),
);

/// Zero-padded names, so `Ep 01` is never a substring of `Ep 18`.
Episode _paddedEpisode(int number) => Episode(
  name: 'Ep ${number.toString().padLeft(2, '0')}',
  url: 'https://series.test/padded/$number',
  season: 1,
  episode: number,
);

/// Server ids 3, 7, 11, ... - the ids a filtered pack really has, none of them
/// a list position.
List<TorrentFile> _packFiles(int count) => List<TorrentFile>.generate(
  count,
  (i) => TorrentFile(
    index: 3 + 4 * i,
    name: 'Pack.S01E${(i + 1).toString().padLeft(2, '0')}.mkv',
    sizeBytes: 700 * 1024 * 1024,
  ),
);

/// The labels of the rows showing the selected tick, on screen or in the cache.
List<String> _selectedRows(WidgetTester tester) => tester
    .widgetList<PanelRow>(find.byType(PanelRow, skipOffstage: false))
    .where((row) => row.selected)
    .map((row) => row.label)
    .toList();

/// The rect of the row labelled [label], wherever the list has built it.
Rect _rowRect(WidgetTester tester, String label) =>
    tester.getRect(find.widgetWithText(PanelRow, label, skipOffstage: false));

/// The viewport of the one track list on screen. Found by [ListView] rather
/// than by [PanelAnchoredList] so the assertion is about the geometry and
/// survives whichever list widget the tab is built on.
Rect _trackListRect(WidgetTester tester) =>
    tester.getRect(find.byType(ListView));

/// The viewport of the one anchored list on screen.
Rect _listRect(WidgetTester tester) =>
    tester.getRect(find.byType(PanelAnchoredList));

/// Whether [inner] lies within [outer]. `Rect.contains` excludes the far
/// edges, which a full-width row always shares with its list.
bool _inside(Rect outer, Rect inner) =>
    inner.left >= outer.left - 0.01 &&
    inner.top >= outer.top - 0.01 &&
    inner.right <= outer.right + 0.01 &&
    inner.bottom <= outer.bottom + 0.01;

/// The accessibility label of whatever holds primary focus - a tab button's
/// label, when the strip has it.
String? _focusedSemanticsLabel() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context?.findAncestorWidgetOfExactType<Semantics>()?.properties.label;
}

/// The label of the row holding primary focus, or null when a row does not.
String? _focusedRow() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context?.findAncestorWidgetOfExactType<PanelRow>()?.label;
}

/// Whether the subtitle delay stepper holds primary focus.
bool _stepperFocused() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context?.findAncestorWidgetOfExactType<PanelStepperRow>() != null;
}

/// How many traversable focus stops sit inside [element].
int _focusStopsIn(Element element) {
  var stops = 0;
  void visit(Element child) {
    final widget = child.widget;
    if (widget is Focus && widget.canRequestFocus && !widget.skipTraversal) {
      stops++;
    }
    child.visitChildren(visit);
  }

  element.visitChildren(visit);
  return stops;
}

/// The font size the one [Text] reading [data] was given.
double _textSize(WidgetTester tester, String data) =>
    tester.widget<Text>(find.text(data)).style!.fontSize!;

/// The colour the one [PanelBadge] reading [data] paints its word in.
Color _badgeColour(WidgetTester tester, String data) => tester
    .widget<Text>(
      find.descendant(
        of: find.widgetWithText(PanelBadge, data, skipOffstage: false),
        matching: find.text(data, skipOffstage: false),
      ),
    )
    .style!
    .color!;

/// The rendered size of the one [Icon] of [icon].
double _iconSize(WidgetTester tester, IconData icon) =>
    tester.widget<Icon>(find.byIcon(icon)).size!;

/// The box a remote actually lands on: the innermost [Focus] around [finder].
/// Used for the private tab and close buttons, which a test cannot name.
Rect _focusBox(WidgetTester tester, Finder finder) => tester.getRect(
  find.ancestor(of: finder, matching: find.byType(Focus)).first,
);

/// The labels of the five tabs in [locale], in strip order.
Future<List<String>> _tabLabels(Locale locale) async {
  final l10n = await AppLocalizations.delegate.load(locale);
  return <String>[
    l10n.sources,
    l10n.audio,
    l10n.subtitles,
    l10n.episodes,
    l10n.playerFiles,
  ];
}

/// The top edge of the row labelled [label], for order assertions.
double _rowTop(WidgetTester tester, String label) =>
    tester.getTopLeft(find.widgetWithText(PanelRow, label)).dy;

/// The episode row whose composed label mentions [needle]. Episode labels are
/// built from the number and the name (`S1 E2 · Episode 2`), so a test that
/// means "the row for episode 2" cannot use the raw name as an exact match.
Finder _episodeRow(String needle) => find.byWidgetPredicate(
  (widget) => widget is PanelRow && widget.label.contains(needle),
  skipOffstage: false,
);

/// The progress bar painted across the foot of [needle]'s still, or null when
/// that row has none.
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

/// Whether [needle]'s still carries the 28 % black a seen episode is dimmed by
/// — the same value the details screen uses.
bool _rowDimmed(WidgetTester tester, String needle) => find
    .descendant(
      of: _episodeRow(needle),
      matching: find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == _kWatchedDim,
        skipOffstage: false,
      ),
    )
    .evaluate()
    .isNotEmpty;

/// The dim a seen episode's still carries. Duplicated from the tab on purpose:
/// a test that read the constant from the widget could not catch it changing.
const Color _kWatchedDim = Color(0x47000000);

/// The badge texts on [needle]'s row, in the order the wrap lays them out.
List<String> _rowBadges(WidgetTester tester, String needle) => tester
    .widgetList<PanelBadge>(
      find.descendant(
        of: _episodeRow(needle),
        matching: find.byType(PanelBadge, skipOffstage: false),
      ),
    )
    .map((badge) => badge.text)
    .toList();

/// Stands in for the subtitle providers behind the Search online sheet:
/// records what the notifier asked for and answers with one result, so the
/// notifier's fallback chain stops at the first pass.
class _RecordingSubtitleProvider extends SubtitleProvider {
  @override
  String get name => 'Fake';

  @override
  String get idPrefix => 'fake';

  final List<
    ({String query, String? imdbId, int? tmdbId, int? season, int? episode})
  >
  calls = [];

  @override
  Future<List<OnlineSubtitle>> search({
    required String query,
    String? imdbId,
    int? tmdbId,
    int? season,
    int? episode,
    String? language,
    CancelToken? cancelToken,
  }) async {
    calls.add((
      query: query,
      imdbId: imdbId,
      tmdbId: tmdbId,
      season: season,
      episode: episode,
    ));
    return const <OnlineSubtitle>[
      OnlineSubtitle(
        id: '1',
        name: 'The.Show.S02E05.srt',
        language: 'en',
        source: 'Fake',
        downloadUrl: '',
      ),
    ];
  }

  @override
  Future<String?> getDownloadUrl(OnlineSubtitle subtitle) async => null;
}

/// A page with one focusable control on it, standing in for the chrome button
/// the panel is opened from.
class _Host extends StatefulWidget {
  const _Host({required this.onOpen, super.key});

  final Future<void> Function(BuildContext context) onOpen;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final FocusNode opener = FocusNode(debugLabel: 'opener');

  @override
  void dispose() {
    opener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Focus(
          focusNode: opener,
          child: GestureDetector(
            onTap: () => widget.onOpen(context),
            child: const Text('sources'),
          ),
        ),
      ),
    );
  }
}

/// The host page must not animate: Flutter's own page transition wraps every
/// route in a window-sized [FadeTransition], and this file is measuring what
/// the *panel* adds.
class _NoPageTransition extends PageTransitionsBuilder {
  const _NoPageTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Opens the panel over a host page and returns the host's focus node, so a
  /// test can assert where focus went and where it came back to, alongside
  /// the notifier the panel is listening to, so a test can publish the way
  /// the screen does and watch the open panel follow.
  ///
  /// [engine] is the fake the controller is attached to; a test that needs
  /// tracks, or needs to change them after the panel is up, passes its own.
  /// The engine's state is delivered to the controller before the panel
  /// opens, as it would be mid-playback, unless [primed] is false - the case
  /// of fresh media whose first snapshot lands after the panel is already up.
  /// [settle] false stops after the first frame of the route, with the track
  /// lists still loading. [overrides] wraps the host in a ProviderScope - only
  /// the Search online page reads providers; the panel itself has no scope.
  Future<
    ({
      FocusNode opener,
      ValueNotifier<PanelData> data,
      VlcPlayerController controller,
    })
  >
  pumpPanel(
    WidgetTester tester, {
    Size size = _tv,
    bool isTv = true,
    bool focusOnOpen = true,
    PlayerPanelTab tab = PlayerPanelTab.sources,
    int currentSourceIndex = 0,
    List<StreamResult>? sources,
    Map<int, ProbeOutcome> probes = const <int, ProbeOutcome>{},
    Set<int> failedSources = const <int>{},
    bool qualityFilteredFallback = false,
    List<Episode> episodes = const <Episode>[],
    Episode? currentEpisode,
    EpisodeProgressLookup? episodeProgress,
    List<TorrentFile> files = const <TorrentFile>[],
    int? currentFileIndex,
    SubtitleSearchTarget? subtitleTarget,
    void Function(int index)? onPickSource,
    void Function(Episode episode)? onPickEpisode,
    void Function(TorrentFile file)? onPickFile,
    FakeVlcEngine? engine,
    bool primed = true,
    bool settle = true,
    List<Override>? overrides,
    Locale locale = const Locale('en'),
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final fake = engine ?? FakeVlcEngine();
    fake.install();
    // Tear-downs run last-in first-out: the controller goes first, while the
    // channel it sends `dispose` on still has a handler.
    addTearDown(fake.dispose);
    final controller = await fake.attach();
    addTearDown(controller.dispose);
    if (primed) await fake.emit(_paused);

    // What the screen publishes: one value, built once here from the named
    // parameters so the tests read like the panel's callers do.
    final data = ValueNotifier<PanelData>(
      PanelData(
        sources: sources ?? _sources(),
        currentSourceIndex: currentSourceIndex,
        probes: probes,
        failedSources: failedSources,
        qualityFilteredFallback: qualityFilteredFallback,
        episodes: episodes,
        currentEpisode: currentEpisode,
        files: files,
        currentFileIndex: currentFileIndex,
        subtitleTarget: subtitleTarget,
      ),
    );
    addTearDown(data.dispose);

    final hostKey = GlobalKey<_HostState>();
    Widget app = MaterialApp(
      locale: locale,
      theme: ThemeData(
        pageTransitionsTheme: PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            for (final platform in TargetPlatform.values)
              platform: const _NoPageTransition(),
          },
        ),
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Wraps the Navigator, so the panel's own route inherits it: the panel
      // is a PopupRoute and reads nothing from the page below it.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: _Host(
        key: hostKey,
        onOpen: (context) => showPlayerPanel(
          context,
          controller: controller,
          initialTab: tab,
          isTv: isTv,
          focusOnOpen: focusOnOpen,
          data: data,
          onPickSource: onPickSource ?? (_) {},
          onPickEpisode: onPickEpisode ?? (_) {},
          onPickFile: onPickFile ?? (_) {},
          episodeProgress: episodeProgress,
        ),
      ),
    );
    if (overrides != null) {
      app = ProviderScope(overrides: overrides, child: app);
    }
    await tester.pumpWidget(app);

    final opener = hostKey.currentState!.opener;
    opener.requestFocus();
    await tester.pump();
    expect(opener.hasPrimaryFocus, isTrue, reason: 'the opener starts focused');

    await tester.tap(find.text('sources'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    return (opener: opener, data: data, controller: controller);
  }

  group('focus', () {
    testWidgets('opens onto the source that is playing, not row one', (
      tester,
    ) async {
      await pumpPanel(tester, currentSourceIndex: 1);

      expect(_focusedRow(), '720p');
    });

    testWidgets('opens on the first row when nothing is selected yet', (
      tester,
    ) async {
      // No source has been settled on (the failed stage). A remote must still
      // land on a row: focus nowhere is a panel that cannot be used at all.
      await pumpPanel(tester, currentSourceIndex: -1);
      expect(_focusedRow(), '1080p');
    });

    testWidgets('the subtitles tab opens focused on Off', (tester) async {
      // The engine reports no subtitle track on - `activeSubtitleTrackId` is
      // null - so Off is what is true, and it is both ticked and focused.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpPanel(tester, tab: PlayerPanelTab.subtitles);

      expect(_focusedRow(), l10n.off);
      expect(_selectedRows(tester), <String>[l10n.off]);
    });

    testWidgets('gives focus back to the control that opened it', (
      tester,
    ) async {
      final opener = (await pumpPanel(tester)).opener;
      expect(opener.hasPrimaryFocus, isFalse, reason: 'focus moved in');

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(PlayerPanel), findsNothing);
      expect(
        opener.hasPrimaryFocus,
        isTrue,
        reason: 'a remote that closes the panel must not be left nowhere',
      );
    });

    testWidgets('every row is one focus stop', (tester) async {
      await pumpPanel(tester);

      for (final element in find.byType(PanelRow).evaluate()) {
        var stops = 0;
        void visit(Element child) {
          final widget = child.widget;
          if (widget is Focus &&
              widget.canRequestFocus &&
              !widget.skipTraversal) {
            stops++;
          }
          child.visitChildren(visit);
        }

        element.visitChildren(visit);
        expect(
          stops,
          1,
          reason:
              'the row itself is the focus stop; anything focusable inside it '
              'is a second press that lands nowhere the viewer can see',
        );
      }
    });

    testWidgets('DOWN walks the rows one at a time', (tester) async {
      await pumpPanel(tester);

      final visited = <String?>[_focusedRow()];
      for (var i = 0; i < 2; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        visited.add(_focusedRow());
      }

      expect(visited, <String>['1080p', '720p', 'Server 3']);
    });

    testWidgets('UP reaches the tab strip, and the strip switches tabs', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        episodes: <Episode>[_episode(1), _episode(2)],
        currentEpisode: _episode(1),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(_focusedRow(), isNull, reason: 'focus left the list');

      // The strip is a plain Row of buttons: Right steps along it and Select
      // switches, with no horizontal Scrollable in between to swallow either.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      expect(find.text('1080p'), findsNothing, reason: 'the sources are gone');
      expect(
        find.byType(PlayerSourcesTab),
        findsNothing,
        reason: 'the strip switched the body without a tap',
      );
    });

    testWidgets('a tab is one focus stop and switches on Select', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpPanel(tester);

      await tester.tap(find.text(l10n.audio));
      await tester.pumpAndSettle();

      expect(find.text(l10n.noAudioTracksReported), findsOneWidget);
      expect(find.byType(PlayerSourcesTab), findsNothing);
    });
  });

  group('back', () {
    testWidgets('closes the panel and leaves the player', (tester) async {
      await pumpPanel(tester);
      expect(find.byType(PlayerPanel), findsOneWidget);

      // What Android's Back button actually delivers.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(PlayerPanel), findsNothing);
      expect(
        find.text('sources'),
        findsOneWidget,
        reason: 'one press closes the panel; it does not also exit playback',
      );
    });

    testWidgets('escape closes it too, for a desktop keyboard', (tester) async {
      await pumpPanel(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(PlayerPanel), findsNothing);
      expect(find.text('sources'), findsOneWidget, reason: 'the player stays');
    });
  });

  group('sources', () {
    testWidgets('shows quality, size and seeders, and marks what is playing', (
      tester,
    ) async {
      await pumpPanel(tester, currentSourceIndex: 0);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.widgetWithText(PanelBadge, '1080p'), findsOneWidget);
      expect(find.widgetWithText(PanelBadge, '2.1 GB'), findsOneWidget);
      expect(
        find.widgetWithText(PanelBadge, l10n.playerSeeders(45)),
        findsOneWidget,
      );
      expect(find.text('Torrentio'), findsOneWidget, reason: 'the provider');
      expect(
        find.widgetWithText(PanelBadge, l10n.playerNowPlaying),
        findsOneWidget,
        reason: 'exactly one row is the one playing',
      );
    });

    testWidgets('shows what the health probe found', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpPanel(
        tester,
        probes: const <int, ProbeOutcome>{
          0: ProbeOutcome.healthy,
          1: ProbeOutcome.unhealthy,
          2: ProbeOutcome.trying,
        },
      );

      expect(
        find.widgetWithText(PanelBadge, l10n.playerSourceReachable),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(PanelBadge, l10n.unknown),
        findsOneWidget,
        reason: 'a check that got no answer is not a source that failed',
      );
      expect(
        find.widgetWithText(PanelBadge, l10n.playerSourceChecking),
        findsOneWidget,
      );
      expect(find.widgetWithText(PanelBadge, l10n.playerSourceUnplayable), findsNothing);
    });

    // "Unknown" is the placeholder for a source whose plugin named no
    // provider - every JS plugin's is - and it was printed under every row.
    testWidgets('a source with no provider gets no provider line', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        sources: const <StreamResult>[
          StreamResult(url: 'https://a.test/one', source: 'HubCloud [1080p]'),
        ],
        currentSourceIndex: -1,
      );

      expect(find.text('Unknown'), findsNothing);
      expect(find.textContaining('HubCloud'), findsOneWidget);
    });

    // Not "Unknown", which reads as a verdict: these have simply not been
    // asked, and past the top three most of them never will be.
    testWidgets('says Not checked for a source nobody has checked', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpPanel(
        tester,
        probes: const <int, ProbeOutcome>{0: ProbeOutcome.healthy},
      );

      expect(
        find.widgetWithText(PanelBadge, l10n.playerSourceNotChecked),
        findsNWidgets(2),
        reason: 'the check only looks at the top three; the rest said nothing',
      );
      expect(find.widgetWithText(PanelBadge, l10n.unknown), findsNothing);
    });

    // Reachability and how playing went are separate facts, and the panel
    // shows both: a source that was reachable and then failed says so.
    testWidgets('a source that would not play still says what the check '
        'found', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpPanel(
        tester,
        currentSourceIndex: 0,
        probes: const <int, ProbeOutcome>{1: ProbeOutcome.healthy},
        failedSources: const <int>{1},
      );

      final second = find.ancestor(
        of: find.text('Vidsrc'),
        matching: find.byType(PanelRow),
      );
      expect(
        find.descendant(
          of: second,
          matching: find.widgetWithText(PanelBadge, l10n.playerSourceReachable),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: second,
          matching: find.widgetWithText(PanelBadge, l10n.playerSourceUnplayable),
        ),
        findsOneWidget,
      );
    });

    testWidgets('says why a source below the preference is in the list', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpPanel(tester, qualityFilteredFallback: true);

      expect(find.text(l10n.playerQualityFilterDropped), findsOneWidget);
    });

    testWidgets('a pick closes the panel and reports the index it chose', (
      tester,
    ) async {
      final picked = <int>[];
      await pumpPanel(tester, onPickSource: picked.add);

      await tester.tap(find.text('Server 3'));
      await tester.pumpAndSettle();

      expect(picked, <int>[2]);
      expect(find.byType(PlayerPanel), findsNothing);
    });
  });


  group('quality filter on a remote', () {
    /// What holds primary focus, as a pill label / row label / other.
    String? focused() {
      final row = _focusedRow();
      if (row != null) return 'row:$row';
      return _focusedSemanticsLabel();
    }

    Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
    }

    /// Walks the strip to the pill called [label] and leaves focus there.
    ///
    /// Which pill one press UP lands on is geometry - whichever sits nearest
    /// the row below - so a test that wants a particular one has to travel to
    /// it the way a viewer would, rather than assume an entry point.
    Future<void> focusPill(WidgetTester tester, String label) async {
      await press(tester, LogicalKeyboardKey.arrowUp);
      for (var i = 0; i < 8 && focused() != label; i++) {
        await press(tester, LogicalKeyboardKey.arrowLeft);
      }
      for (var i = 0; i < 8 && focused() != label; i++) {
        await press(tester, LogicalKeyboardKey.arrowRight);
      }
      expect(focused(), label, reason: 'the strip walks to $label');
    }

    testWidgets('UP from the list lands on the strip, not past it', (
      tester,
    ) async {
      // The strip sits between the rows and the tab bar, so one press UP has
      // to stop on it. Skipping it to the tabs would make the filter a
      // pointer-only control on the one device that has no pointer.
      await pumpPanel(tester, size: _googleTv, sources: _tieredSources());
      expect(_focusedRow(), 'Alpha 1080p', reason: 'opens on the playing row');

      await press(tester, LogicalKeyboardKey.arrowUp);

      expect(focused(), anyOf('1080p', '720p'));
    });

    testWidgets('every pill is reachable, wrapped onto two runs or not', (
      tester,
    ) async {
      // All six tiers at once. Whether they fit one run depends on the font
      // and the ramp - in the test font they do not - so what is pinned here
      // is not the shape of the strip but the property that survives either
      // shape: a remote can reach every pill. A run the D-pad cannot get to
      // is a filter that does not exist.
      const tiers = <String>['4K', '2K', '1080p', '720p', '480p', '360p'];
      await pumpPanel(
        tester,
        size: _googleTv,
        sources: <StreamResult>[
          for (final tier in tiers)
            StreamResult(
              url: 'https://x.test/$tier',
              source: 'Src $tier',
              providerName: 'P',
            ),
        ],
      );

      final seen = <String>{};
      void record() {
        final label = focused();
        if (label != null && tiers.contains(label)) seen.add(label);
      }

      // Into the strip, up through its runs, then along each of them.
      await press(tester, LogicalKeyboardKey.arrowUp);
      record();
      await press(tester, LogicalKeyboardKey.arrowUp);
      record();
      for (var i = 0; i < tiers.length + 2; i++) {
        await press(tester, LogicalKeyboardKey.arrowRight);
        record();
      }

      expect(
        seen,
        tiers.toSet(),
        reason: 'a pill no arrow reaches is a filter a remote cannot apply',
      );
    });

    testWidgets('the pill keeps focus when it narrows the list', (
      tester,
    ) async {
      // Otherwise the list, which autofocuses its anchor row on a television,
      // takes the remote away on the first press and choosing a second filter
      // means navigating back up to the strip every time.
      await pumpPanel(tester, size: _googleTv, sources: _tieredSources());
      await press(tester, LogicalKeyboardKey.arrowUp);
      final pill = focused();
      expect(pill, isNotNull);

      await press(tester, LogicalKeyboardKey.select);
      expect(focused(), pill, reason: 'applying a filter does not move focus');

      await press(tester, LogicalKeyboardKey.select);
      expect(focused(), pill, reason: 'and neither does clearing it');
    });

    testWidgets('a filter whose tier stops existing lets go of the list', (
      tester,
    ) async {
      // The data is live. When the last source of the filtered tier goes, so
      // does its pill - and a filter with no pill to undo it is an empty list
      // a remote cannot escape.
      final harness = await pumpPanel(
        tester,
        size: _googleTv,
        sources: _tieredSources(),
      );
      await focusPill(tester, '720p');
      await press(tester, LogicalKeyboardKey.select);
      expect(find.text('Alpha 1080p'), findsNothing, reason: 'filtered to 720p');

      harness.data.value = const PanelData(
        sources: <StreamResult>[
          StreamResult(
            url: 'https://a.test/alpha',
            source: 'Alpha 1080p',
            providerName: 'Torrentio',
          ),
          StreamResult(
            url: 'https://c.test/charlie',
            source: 'Charlie 1080p',
            providerName: 'Upcloud',
          ),
        ],
        currentSourceIndex: 0,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Alpha 1080p'),
        findsOneWidget,
        reason: 'the filter let go rather than hiding everything',
      );
      expect(find.text('Charlie 1080p'), findsOneWidget);
      expect(_focusedRow(), isNotNull, reason: 'and the remote is on a row');
    });

    testWidgets('the tab strip walks to the close button and stops', (
      tester,
    ) async {
      await pumpPanel(tester, size: _googleTv, sources: _tieredSources());
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final close = MaterialLocalizations.of(
        tester.element(find.byType(PlayerPanel)),
      ).closeButtonTooltip;

      // Rows -> strip -> tabs, then along the header and back.
      await press(tester, LogicalKeyboardKey.arrowUp);
      await press(tester, LogicalKeyboardKey.arrowUp);
      final trail = <String?>[focused()];
      for (var i = 0; i < 3; i++) {
        await press(tester, LogicalKeyboardKey.arrowRight);
        trail.add(focused());
      }
      expect(trail.last, close, reason: 'close is the end of the header');
      for (var i = 0; i < 4; i++) {
        await press(tester, LogicalKeyboardKey.arrowLeft);
      }
      expect(
        focused(),
        l10n.sources,
        reason: 'and the far end is the first tab, not a wrap-around',
      );
    });
  });

  group('quality filter', () {
    /// A pill, as opposed to the badge of the same name on the row below it.
    Finder pill(String tier) => find.descendant(
      of: find.byKey(kQualityFilterStripKey),
      matching: find.text(tier),
    );

    testWidgets('one pill per tier present, highest first', (tester) async {
      await pumpPanel(tester, sources: _tieredSources());

      // Two tiers over three sources, in _kTierOrder and not in the order the
      // resolver ranked them.
      final pills = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(kQualityFilterStripKey),
              matching: find.byType(Text),
            ),
          )
          .map((text) => text.data)
          .toList();
      expect(pills, <String>['1080p', '720p']);
    });

    testWidgets('a source of unknown quality gets no pill of its own', (
      tester,
    ) async {
      // `Server 3` parses as Auto, which is not a tier: it is in the list and
      // it is not in the strip.
      await pumpPanel(tester);

      expect(pill('1080p'), findsOneWidget);
      expect(pill('720p'), findsOneWidget);
      expect(find.text('Server 3'), findsOneWidget);
    });

    testWidgets('one tier is not a choice, so there is no strip', (
      tester,
    ) async {
      await pumpPanel(tester, sources: _manySources(3));

      expect(find.byKey(kQualityFilterStripKey), findsNothing);
    });

    testWidgets('a pill narrows the list and pressing it again restores it', (
      tester,
    ) async {
      await pumpPanel(tester, sources: _tieredSources());

      expect(find.text('Bravo 720p'), findsOneWidget);

      await tester.tap(pill('1080p'));
      await tester.pumpAndSettle();

      expect(find.text('Alpha 1080p'), findsOneWidget);
      expect(find.text('Charlie 1080p'), findsOneWidget);
      expect(
        find.text('Bravo 720p'),
        findsNothing,
        reason: 'the tier that was not asked for is gone',
      );

      await tester.tap(pill('1080p'));
      await tester.pumpAndSettle();

      expect(
        find.text('Bravo 720p'),
        findsOneWidget,
        reason: 'a filter is a toggle: the pill in force clears it',
      );
    });

    testWidgets('a filtered row still reports its own index', (tester) async {
      // The one thing the filter must not do. Every other input this tab
      // takes is keyed by position in the *unfiltered* list, so a row that
      // reported its position in the narrowed one would change the wrong
      // stream.
      final picked = <int>[];
      await pumpPanel(
        tester,
        sources: _tieredSources(),
        onPickSource: picked.add,
      );

      await tester.tap(pill('720p'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bravo 720p'));
      await tester.pumpAndSettle();

      expect(picked, <int>[1], reason: 'Bravo is index 1 of the whole list');
    });

    testWidgets('the tick follows the filter rather than the position', (
      tester,
    ) async {
      // Charlie is index 2 and the only row left once 1080p is asked for that
      // is not Alpha; under a filter it is at position 1, and reading the tick
      // off the position would move it onto Alpha.
      await pumpPanel(
        tester,
        sources: _tieredSources(),
        currentSourceIndex: 2,
      );

      await tester.tap(pill('1080p'));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final ticked = find.ancestor(
        of: find.text(l10n.playerNowPlaying),
        matching: find.byType(PanelRow),
      );
      expect(
        find.descendant(of: ticked, matching: find.text('Charlie 1080p')),
        findsOneWidget,
      );
    });

    testWidgets('the fallback banner goes once the viewer filters by hand', (
      tester,
    ) async {
      // The banner explains the list the resolver handed over. A list the
      // viewer has narrowed themselves is not that list.
      await pumpPanel(
        tester,
        sources: _tieredSources(),
        qualityFilteredFallback: true,
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.text(l10n.playerQualityFilterDropped), findsOneWidget);

      await tester.tap(pill('720p'));
      await tester.pumpAndSettle();

      expect(find.text(l10n.playerQualityFilterDropped), findsNothing);
    });
  });

  group('tab strip', () {
    testWidgets('three tabs take an equal share of the strip', (tester) async {
      await pumpPanel(tester);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      final centres = <double>[
        tester.getCenter(find.text(l10n.sources)).dx,
        tester.getCenter(find.text(l10n.audio)).dx,
        tester.getCenter(find.text(l10n.subtitles)).dx,
      ];
      expect(
        centres[1] - centres[0],
        closeTo(centres[2] - centres[1], 0.5),
        reason: 'equal columns, so the gaps between their centres are equal',
      );
    });
  });

  group('shape', () {
    test('a wide window sizes the drawer off the room beside it', () {
      // 34 % of what is left, floored and capped by the ramp. A television
      // pins to the floor; a 1280 dp window does not.
      expect(
        playerPanelWidthFor(
          const Size(2560, 1440),
          PlayerPanelMetrics.tv,
          edgeInset: PlayerPanelMetrics.tv.drawerEdgeInset,
        ),
        PlayerPanelMetrics.tv.drawerMaxWidth,
      );
      expect(
        playerPanelWidthFor(
          const Size(1280, 800),
          PlayerPanelMetrics.touch,
          edgeInset: 0,
        ),
        (1280 * 0.34).clamp(360.0, 480.0),
      );
    });

    test('a phone held upright still gets a drawer, sized off its width', () {
      // Not the sheet it used to get, and not 34 % either: a third of a 390 dp
      // handset is 133 dp, which would pin every phone to the ramp floor and
      // leave the proportion doing nothing.
      expect(
        playerPanelWidthFor(
          const Size(390, 844),
          PlayerPanelMetrics.touch,
          edgeInset: 0,
        ),
        390 * 0.8,
      );
      // And the narrow branch has a cap of its own, so a 600 dp tablet held
      // upright does not hand over 480 dp of picture.
      expect(
        playerPanelWidthFor(
          const Size(600, 960),
          PlayerPanelMetrics.touch,
          edgeInset: 0,
        ),
        380.0,
      );
    });

    testWidgets('the drawer is attached to the edge, and its contents are '
        'what clear the overscan band', (tester) async {
      await pumpPanel(tester);

      // A television. The surface reaches the screen's edges - a drawer held
      // off them is a drawer floating in the middle of the picture, with
      // video down both sides of it, which is what the inset used to produce
      // when it was applied to the panel instead of to its contents.
      const edge = HotstarPlayerStyle.tvEdgeInset;
      final panel = tester.getRect(find.byKey(kPlayerPanelSurfaceKey));
      expect(panel.right, _tv.width, reason: 'flush to the right edge');
      expect(panel.top, 0, reason: 'and to the top');
      expect(panel.bottom, _tv.height, reason: 'and to the bottom');
      expect(
        panel.width,
        lessThan(_tv.width / 2),
        reason: 'the picture it is describing stays on screen',
      );

      // What the set actually clips is the outer few per cent, so that is
      // where nothing a viewer needs may sit. The close button is the
      // right-most thing in the panel and the first to go.
      final close = tester.getRect(find.byTooltip('Close'));
      expect(
        _tv.width - close.right,
        greaterThanOrEqualTo(edge),
        reason: 'the close button stays out of the band a set clips',
      );
    });

    testWidgets('a drawer that is not a television is still flush to the '
        'edge', (tester) async {
      // The overscan inset is a television's alone. A half-width desktop
      // window has no unsafe band, and inset chrome there is a gap for
      // nothing.
      await pumpPanel(tester, size: const Size(1280, 800), isTv: false);

      final panel = tester.getRect(find.byKey(kPlayerPanelSurfaceKey));
      expect(panel.right, 1280);
      expect(panel.top, 0);
      expect(panel.bottom, 800);
      expect(
        panel.width,
        (1280 * 0.34).clamp(360.0, 480.0),
        reason: "the touch ramp's own arithmetic, unchanged",
      );
    });

    testWidgets('a narrow window gets the drawer too, not a sheet', (
      tester,
    ) async {
      await pumpPanel(tester, size: _phone, isTv: false);

      final panel = tester.getRect(find.byKey(kPlayerPanelSurfaceKey));
      expect(panel.right, _phone.width, reason: 'anchored right');
      expect(panel.top, 0);
      expect(panel.bottom, _phone.height, reason: 'full height, not 66 % of it');
      expect(
        panel.width,
        _phone.width * 0.8,
        reason: 'and the picture is still visible beside it',
      );
    });
  });

  group('television scale', () {
    /// Two episodes and two files, so all five tabs are in the strip - the
    /// worst case the arithmetic has to survive.
    Future<void> pumpFiveTabs(
      WidgetTester tester, {
      required Locale locale,
      Size size = _googleTv,
      bool isTv = true,
      TextScaler textScaler = TextScaler.noScaling,
    }) => pumpPanel(
      tester,
      size: size,
      isTv: isTv,
      locale: locale,
      textScaler: textScaler,
      focusOnOpen: isTv,
      episodes: <Episode>[_episode(1), _episode(2)],
      currentEpisode: _episode(1),
      files: _packFiles(2),
    );

    testWidgets('the drawer keeps the overscan band clear on a television', (
      tester,
    ) async {
      // 960x540 dp is what a 1080p set at dp 2.0 reports, and it is the size
      // where this is worst: the reading column is at its floor, so nothing
      // about the window is giving it room. Measured against MediaQuery, not
      // against a literal, so the assertion says "48 dp of screen".
      await pumpPanel(tester, size: _googleTv);
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      const edge = HotstarPlayerStyle.tvEdgeInset;

      final panel = tester.getRect(find.byKey(kPlayerPanelSurfaceKey));
      expect(
        panel.right,
        screen.width,
        reason: 'the surface is attached to the edge, not floating off it',
      );
      expect(panel.top, 0);
      expect(panel.bottom, screen.height);
      expect(
        panel.width,
        PlayerPanelMetrics.tv.drawerMinWidth + edge,
        reason:
            'the reading column at its ten-foot floor, plus the band it holds '
            'clear inside itself - so the column is as wide as it ever was',
      );

      // And what the band is for: the close button and the badges against
      // that edge are what a set clipping ~5 % takes first.
      expect(
        screen.width - tester.getRect(find.byTooltip('Close')).right,
        greaterThanOrEqualTo(edge),
      );
    });

    for (final locale in const <Locale>[
      Locale('en'),
      Locale('hi'),
      Locale('kn'),
    ]) {
      testWidgets('five tabs do not ellipsise at 960x540 in '
          '${locale.languageCode}', (tester) async {
        // The assertion that settles the arithmetic. A row of Expanded tabs
        // gave each of five about 62 dp, which cannot hold "Subtitles", let
        // alone the Kannada for it - and a tab strip a viewer has to guess at
        // is worse than one that wraps onto a second line.
        await pumpFiveTabs(tester, locale: locale);

        for (final label in await _tabLabels(locale)) {
          expect(find.text(label), findsOneWidget, reason: 'tab "$label"');
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label),
          );
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason: 'the tab label "$label" is cut off on a television',
          );
        }
      });
    }

    testWidgets('every stop in the strip is one focus target tall', (
      tester,
    ) async {
      // 48 dp is the smallest thing a viewer can aim a focus ring at and read
      // from a sofa. Before the ramp a row was ~45 dp and a tab ~38 dp.
      await pumpFiveTabs(tester, locale: const Locale('en'));

      for (final label in await _tabLabels(const Locale('en'))) {
        expect(
          _focusBox(tester, find.text(label)).height,
          greaterThanOrEqualTo(48),
          reason: 'tab "$label"',
        );
      }
      expect(
        _focusBox(tester, find.byIcon(Icons.close_rounded)).height,
        greaterThanOrEqualTo(48),
        reason: 'the close button',
      );
      for (final row in find.byType(PanelRow).evaluate()) {
        expect(
          (row.renderObject! as RenderBox).size.height,
          greaterThanOrEqualTo(48),
          reason: 'a panel row',
        );
      }
    });

    // The two halves of "TV-only by construction", measured in the SAME
    // window so the only variable is isTv. The four strings are one per rung
    // of the ramp: a row's label, its detail line, a badge and a tab.
    const desktop = Size(1280, 800);

    testWidgets('a drawer that is not a television keeps the phone scale', (
      tester,
    ) async {
      // Every number here was hard-coded in player_panel.dart or
      // player_panel_row.dart before the ramp existed, so this is the
      // no-op assertion for phone, tablet and desktop.
      await pumpPanel(tester, size: desktop, isTv: false, focusOnOpen: false);

      expect(_textSize(tester, 'Server 3'), 14, reason: 'row label');
      expect(_textSize(tester, 'Torrentio'), 12, reason: 'row detail');
      expect(_textSize(tester, '2.1 GB'), 10, reason: 'badge');
      expect(_textSize(tester, 'Sources'), 13, reason: 'tab');
    });

    testWidgets('the same drawer on a television is read from a sofa', (
      tester,
    ) async {
      await pumpPanel(tester, size: desktop);

      expect(_textSize(tester, 'Server 3'), 17, reason: 'row label');
      expect(_textSize(tester, 'Torrentio'), 14, reason: 'row detail');
      expect(_textSize(tester, '2.1 GB'), 13, reason: 'badge');
      expect(_textSize(tester, 'Sources'), 16, reason: 'tab');
    });

    test('the touch ramp is today\'s literals, field by field', () {
      // Pinned rather than trusted: this is what makes "phone, tablet and
      // desktop are a no-op" a fact. Every number here was hard-coded in
      // player_panel.dart or player_panel_row.dart before the ramp existed.
      const touch = PlayerPanelMetrics.touch;
      expect(touch.drawerMinWidth, 360);
      expect(touch.drawerMaxWidth, 480);
      expect(touch.drawerEdgeInset, 0);
      expect(touch.drawerVerticalInset, 0);
      expect(touch.rowLabelSize, 14);
      expect(touch.rowDetailSize, 12);
      expect(touch.rowVerticalPadding, 10);
      expect(touch.leadingSlotWidth, 30);
      expect(touch.iconSize, 20);
      expect(touch.badgeSize, 10);
      expect(touch.subheaderSize, 11);
      expect(touch.emptySize, 13);
      expect(touch.bannerTextSize, 11);
      expect(touch.bannerIconSize, 16);
      expect(touch.tabLabelSize, 13);
      expect(touch.tabVerticalPadding, 10);
      expect(touch.tabHorizontalPadding, 4);
      // The one field here that is not a pre-existing literal: the ramp's own
      // Wrap took away the floor five Expandeds used to give for free.
      expect(touch.tabMinWidth, 48);
      expect(touch.closeButtonPadding, 8);
      expect(touch.stepperValueWidth, 62);
      expect(touch.stepperValueSize, 13);
      expect(touch.stepIconPadding, 8);
      expect(touch.secondaryText, HotstarPlayerStyle.secondaryText);
      expect(touch.mutedText, HotstarPlayerStyle.mutedText);
      expect(touch.divider, HotstarPlayerStyle.divider);
    });

    test('the television ramp clears the ten-foot floor, badges excepted', () {
      const tv = PlayerPanelMetrics.tv;
      for (final size in <double>[
        tv.rowLabelSize,
        tv.rowDetailSize,
        tv.subheaderSize,
        tv.emptySize,
        tv.tabLabelSize,
        tv.stepperValueSize,
        tv.bannerTextSize,
      ]) {
        expect(size, greaterThanOrEqualTo(14), reason: 'ten-foot type floor');
      }
      expect(
        tv.badgeSize,
        13,
        reason:
            'the one documented exception: three badges and a Now-playing '
            'chip have to fit one line of a 460 dp drawer, and widening the '
            'drawer costs picture',
      );
      expect(
        tv.drawerEdgeInset,
        HotstarPlayerStyle.tvEdgeInset,
        reason: 'the app\'s own overscan token, not a second number',
      );
      expect(
        tv.secondaryText.a,
        greaterThan(HotstarPlayerStyle.secondaryText.a),
        reason: '65% white is a phone number against a set\'s picture modes',
      );
      expect(tv.mutedText.a, greaterThan(HotstarPlayerStyle.mutedText.a));
    });

    testWidgets('the fallback banner is on the ramp, not on its own literals', (
      tester,
    ) async {
      // The last panel descendant drawn from hard-coded numbers, and the one
      // it mattered most for: it is prose, it sits directly above the row the
      // remote lands on, and 11 sp is 22 physical pixels on a 1080p set.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpPanel(tester, size: _googleTv, qualityFilteredFallback: true);

      expect(
        _textSize(tester, l10n.playerQualityFilterDropped),
        PlayerPanelMetrics.tv.bannerTextSize,
        reason: 'the banner reads from the sofa like everything else',
      );
      expect(
        _textSize(tester, l10n.playerQualityFilterDropped),
        greaterThanOrEqualTo(14),
        reason: 'the ten-foot type floor, which the banner never cleared',
      );
      expect(
        _iconSize(tester, Icons.filter_alt_off_rounded),
        PlayerPanelMetrics.tv.bannerIconSize,
      );
    });

    testWidgets('the same banner on a phone is the 11 sp it always was', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpPanel(
        tester,
        size: _phone,
        isTv: false,
        focusOnOpen: false,
        qualityFilteredFallback: true,
      );

      expect(_textSize(tester, l10n.playerQualityFilterDropped), 11);
      expect(_iconSize(tester, Icons.filter_alt_off_rounded), 16);
    });

    testWidgets(
      'source statuses share the neutral badge text ramp',
      (tester) async {
        // Status stays explicit in the label, with consistent contrast on TV.
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        await pumpPanel(
          tester,
          size: _googleTv,
          probes: const <int, ProbeOutcome>{
            0: ProbeOutcome.healthy,
            1: ProbeOutcome.unhealthy,
            2: ProbeOutcome.trying,
          },
        );

        expect(
          _badgeColour(tester, l10n.playerSourceChecking),
          PlayerPanelMetrics.tv.secondaryText,
          reason:
              'the one badge that says "still looking" was the hardest to read '
              'on the set it was hardest to read on',
        );
        expect(
          _badgeColour(tester, l10n.playerSourceChecking).a,
          greaterThan(HotstarPlayerStyle.mutedText.a),
          reason: '45 % white is a phone number against a set\'s picture modes',
        );
        expect(
          _badgeColour(tester, l10n.playerSourceReachable),
          PlayerPanelMetrics.tv.secondaryText,
          reason: 'reachable uses the same neutral treatment',
        );
        expect(
          _badgeColour(tester, l10n.unknown),
          PlayerPanelMetrics.tv.secondaryText,
          reason: 'unknown stays readable without a separate warning colour',
        );
      },
    );

    // One case per ramp. The scale differs because the point is the same on
    // both: shrink the label until the narrowest tab's own word no longer
    // fills 48 dp, and check the strip still gives it 48 - while the widest
    // word, which does fill it, is left alone.
    for (final (name, size, isTv, scaler, widest)
        in <(String, Size, bool, double, String)>[
          ('a phone', _phone, false, 0.4, 'Subtitles'),
          ('a television', _googleTv, true, 0.25, 'Subtitles'),
        ]) {
      testWidgets('every stop in the strip is one focus target wide on $name', (
        tester,
      ) async {
        // The other half of "one focus target". A Wrap gives a tab exactly the
        // width of its word, and the real widths are nothing like this test
        // font's: `Files` is 37 dp of Roboto at the touch ramp's 13 sp where
        // the square-glyph placeholder makes it 74. Scaling the text down is
        // how a widget test sees the tab a phone actually renders.
        await pumpFiveTabs(
          tester,
          locale: const Locale('en'),
          size: size,
          isTv: isTv,
          textScaler: TextScaler.linear(scaler),
        );

        for (final label in await _tabLabels(const Locale('en'))) {
          expect(
            _focusBox(tester, find.text(label)).width,
            greaterThanOrEqualTo(48),
            reason:
                'tab "$label" is the whole tap target, and its neighbour is '
                '4 dp away',
          );
        }
        expect(
          _focusBox(tester, find.text(widest)).width,
          greaterThan(48),
          reason:
              'the floor is a floor: a word that needs more than 48 dp still '
              'gets it, which is what the Wrap is for',
        );
      });
    }

    testWidgets('nothing installs the ramp outside the panel', (tester) async {
      // A panel widget pumped on its own - the way the tab files\' own tests
      // build them - is the phone it always was.
      late PlayerPanelMetrics seen;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen = PlayerPanelMetrics.of(context);
            return const SizedBox();
          },
        ),
      );
      expect(identical(seen, PlayerPanelMetrics.touch), isTrue);
    });
  });

  group('compositing', () {
    testWidgets('puts no window-sized effect layer over the video', (
      tester,
    ) async {
      await pumpPanel(tester);

      _expectNoLargeEffectLayer(tester);
    });

    testWidgets('nor while the track list is still loading', (tester) async {
      // The Audio tab's first frame is a spinner inside the FutureBuilder,
      // and a spinner is the classic place an opacity layer creeps in.
      await pumpPanel(
        tester,
        tab: PlayerPanelTab.audio,
        settle: false,
        engine: FakeVlcEngine()
          ..audio = <Map<String, Object?>>[_track(1, 'Stereo')],
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      _expectNoLargeEffectLayer(tester);

      await tester.pumpAndSettle();
      expect(find.text('Stereo'), findsOneWidget);
      _expectNoLargeEffectLayer(tester);
    });
  });

  group('tracks', () {
    testWidgets('names a track the engine only numbered', (tester) async {
      final engine = FakeVlcEngine()
        ..audio = const <Map<String, Object?>>[
          <String, Object?>{'id': -1, 'name': 'Disable'},
          <String, Object?>{'id': 1, 'name': 'Track 1', 'language': 'eng'},
          <String, Object?>{'id': 2, 'name': ''},
        ]
        ..mediaInfo = const <String, Object?>{
          'audioTracks': <Map<String, Object?>>[
            <String, Object?>{
              'type': 'audio',
              'codec': 'ac3',
              'channels': 6,
              'bitrate': 448000,
            },
            <String, Object?>{
              'type': 'audio',
              'codec': 'aac',
              'language': 'jpn',
            },
          ],
        };

      await pumpPanel(tester, tab: PlayerPanelTab.audio, engine: engine);

      expect(find.text('English'), findsOneWidget);
      expect(find.text('AC3 · 5.1 · 448 kbps'), findsOneWidget);
      expect(find.text('Japanese'), findsOneWidget);
      expect(
        find.text('Disable'),
        findsNothing,
        reason: "libVLC's own pseudo-track is not a choice anybody makes here",
      );
    });

    testWidgets('subtitles offer Off, and it is one row', (tester) async {
      await pumpPanel(tester, tab: PlayerPanelTab.subtitles);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.widgetWithText(PanelRow, l10n.off), findsOneWidget);
      expect(find.text(l10n.loadSubtitleFile), findsOneWidget);
      expect(find.text(l10n.searchSubtitlesOnline), findsOneWidget);
      expect(
        find.text(l10n.subtitleDelay),
        findsOneWidget,
        reason: 'stepped, not dragged: a slider is unusable on a remote',
      );
    });

    testWidgets('Search online opens in the panel\'s place with what the '
        'screen knows, and searches by it on open', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final provider = _RecordingSubtitleProvider();
      SubtitleSearch.debugProviders = <SubtitleProvider>[provider];
      addTearDown(() => SubtitleSearch.debugProviders = null);
      const target = SubtitleSearchTarget(
        title: 'The Show',
        imdbId: 'tt0903747',
        tmdbId: 1396,
        season: 2,
        episode: 5,
      );

      final panel = await pumpPanel(
        tester,
        tab: PlayerPanelTab.subtitles,
        overrides: [
          playerSettingsProvider.overrideWithBuild(
            (_, _) => const PlayerSettings(),
          ),
        ],
      );
      // Published after open, the way the screen does once it knows.
      panel.data.value = panel.data.value.copyWith(subtitleTarget: target);
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.searchSubtitlesOnline));
      await tester.pumpAndSettle();

      expect(find.byType(SubtitleSearchPage), findsOneWidget);
      expect(
        find.byType(PlayerPanelShell),
        findsOneWidget,
        reason: 'a step inside the drawer, not a page over the picture',
      );
      expect(
        find.text(l10n.subtitles),
        findsNothing,
        reason: 'the tabs make way for the page until Back',
      );
      expect(provider.calls, hasLength(1), reason: 'no press needed');
      expect(provider.calls.single, (
        query: 'The Show',
        imdbId: 'tt0903747',
        tmdbId: 1396,
        season: 2,
        episode: 5,
      ));
      expect(
        find.widgetWithText(TextField, 'The Show'),
        findsOneWidget,
        reason: 'the field carries the bare title, not the episode',
      );
    });

    testWidgets('the subtitles tab lists Off, the engine tracks, Retry, Load '
        'file, Search online and the delay in that order', (tester) async {
      // The common case - picking a track that is already there - stays at
      // the top, where the thumb and the D-pad reach it first; the ways of
      // adding one come after, and the one adjustment last.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpPanel(
        tester,
        tab: PlayerPanelTab.subtitles,
        engine: FakeVlcEngine()
          ..subtitle = <Map<String, Object?>>[_track(1, 'English')],
      );

      final tops = <double>[
        _rowTop(tester, l10n.off),
        _rowTop(tester, 'English'),
        _rowTop(tester, l10n.retry),
        _rowTop(tester, l10n.loadSubtitleFile),
        _rowTop(tester, l10n.searchSubtitlesOnline),
        tester.getTopLeft(find.text(l10n.subtitleDelay)).dy,
      ];
      for (var i = 1; i < tops.length; i++) {
        expect(tops[i], greaterThan(tops[i - 1]), reason: 'row $i is below');
      }
    });

    testWidgets('the audio tab on TV opens ticked and focused on the track '
        'the engine says is playing, not row one', (tester) async {
      await pumpPanel(
        tester,
        tab: PlayerPanelTab.audio,
        engine: FakeVlcEngine()
          ..audio = <Map<String, Object?>>[
            _track(1, 'Stereo', language: 'eng'),
            _track(2, 'Commentary'),
          ]
          ..activeAudioId = 2,
      );

      expect(_focusedRow(), 'Commentary');
      expect(_selectedRows(tester), <String>['Commentary']);
    });

    testWidgets('an audio tab with no track reported lands on the first row, '
        'unticked', (tester) async {
      // A stream that has not announced its audio yet: the engine names no
      // track, so nothing is ticked - the tick never guesses - but a remote
      // must still land on a row rather than nothing at all.
      await pumpPanel(
        tester,
        tab: PlayerPanelTab.audio,
        engine: FakeVlcEngine()
          ..audio = <Map<String, Object?>>[
            _track(1, 'Stereo', language: 'eng'),
            _track(2, 'Commentary'),
          ],
      );

      expect(_focusedRow(), 'Stereo');
      expect(_selectedRows(tester), isEmpty);
    });

    testWidgets('an empty audio tab lands focus on Retry', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpPanel(tester, tab: PlayerPanelTab.audio);

      expect(find.text(l10n.noAudioTracksReported), findsOneWidget);
      expect(_focusedRow(), l10n.retry, reason: 'the only row there is');
    });

    testWidgets('the subtitles tab ticks and focuses the track that is on, '
        'and Off is neither', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpPanel(
        tester,
        tab: PlayerPanelTab.subtitles,
        engine: FakeVlcEngine()
          ..subtitle = <Map<String, Object?>>[
            _track(2, 'English'),
            _track(3, 'Spanish'),
          ]
          ..activeSubtitleId = 3,
      );

      expect(_focusedRow(), 'Spanish');
      expect(_selectedRows(tester), <String>['Spanish']);
      expect(
        tester
            .widget<PanelRow>(find.widgetWithText(PanelRow, l10n.off))
            .selected,
        isFalse,
      );
    });

    testWidgets('a tap asks the engine, and the tick waits for its answer', (
      tester,
    ) async {
      // No optimistic tick: the engine is the only source of what is on, so
      // a set it refuses can never leave a tick on a track that is not
      // playing. The natives snapshot straight after a set; the fake makes
      // that a separate step so the gap is visible.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final engine = FakeVlcEngine()
        ..subtitle = <Map<String, Object?>>[
          _track(2, 'English'),
          _track(3, 'Spanish'),
        ];
      await pumpPanel(tester, tab: PlayerPanelTab.subtitles, engine: engine);
      expect(_selectedRows(tester), <String>[l10n.off]);

      await tester.tap(find.widgetWithText(PanelRow, 'Spanish'));
      await tester.pump();

      final call = engine.callsTo('setSubtitleTrack').single;
      expect((call.arguments as Map<Object?, Object?>)['id'], 3);
      expect(engine.activeSubtitleId, 3, reason: 'the engine took it');
      expect(_selectedRows(tester), <String>[
        l10n.off,
      ], reason: 'nothing moves until the engine says so');

      await _sync(tester, engine);

      expect(_selectedRows(tester), <String>['Spanish']);

      // And Off is the same round trip in the other direction.
      await tester.tap(find.widgetWithText(PanelRow, l10n.off));
      await tester.pump();
      expect(engine.methods, contains('disableSubtitle'));
      expect(_selectedRows(tester), <String>['Spanish']);
      await _sync(tester, engine);
      expect(_selectedRows(tester), <String>[l10n.off]);
    });

    testWidgets('a value that lands after open moves the tick, not focus', (
      tester,
    ) async {
      // Fresh media: the panel is up before the engine's first snapshot. Focus
      // fell back to Off and stays there - Flutter applies an autofocus only
      // while nothing in the scope holds focus - while the tick goes to what
      // the engine then says is on.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final engine = FakeVlcEngine()
        ..subtitle = <Map<String, Object?>>[
          _track(2, 'English'),
          _track(3, 'Spanish'),
        ]
        ..activeSubtitleId = 3;
      await pumpPanel(
        tester,
        tab: PlayerPanelTab.subtitles,
        engine: engine,
        primed: false,
      );
      expect(_focusedRow(), l10n.off);
      expect(_selectedRows(tester), <String>[l10n.off]);
      final focused = FocusManager.instance.primaryFocus;

      await _sync(tester, engine);

      expect(_selectedRows(tester), <String>['Spanish']);
      expect(_focusedRow(), l10n.off);
      expect(FocusManager.instance.primaryFocus, same(focused));
    });

    testWidgets('the tick survives closing and reopening the panel', (
      tester,
    ) async {
      // The selection lives in the engine, not in the panel's State, so a
      // panel opened for the second time shows the same truth as the first.
      await pumpPanel(
        tester,
        tab: PlayerPanelTab.subtitles,
        engine: FakeVlcEngine()
          ..subtitle = <Map<String, Object?>>[
            _track(2, 'English'),
            _track(3, 'Spanish'),
          ]
          ..activeSubtitleId = 3,
      );
      expect(_selectedRows(tester), <String>['Spanish']);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(PlayerPanel), findsNothing);

      await tester.tap(find.text('sources'));
      await tester.pumpAndSettle();

      expect(_selectedRows(tester), <String>['Spanish']);
      expect(_focusedRow(), 'Spanish');
    });

    testWidgets('a track the engine announces late appears without Retry, '
        'and focus stays on the active row', (tester) async {
      // A side-car landing after the panel opened, a stream announcing its
      // audio late: the engine's revision moves, the panel re-reads the list,
      // and the rows re-anchor on the one that is playing.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final engine = FakeVlcEngine()
        ..audio = <Map<String, Object?>>[
          _track(1, 'Stereo'),
          _track(2, 'Commentary'),
        ]
        ..activeAudioId = 1;
      await pumpPanel(tester, tab: PlayerPanelTab.audio, engine: engine);
      expect(_focusedRow(), 'Stereo');
      expect(find.text('Director'), findsNothing);
      expect(engine.callsTo('getAudioTracks'), hasLength(1));

      engine.audio = <Map<String, Object?>>[
        ...engine.audio,
        _track(3, 'Director'),
      ];
      await engine.bumpTracks(_paused);
      await tester.pumpAndSettle();

      expect(find.text('Director'), findsOneWidget);
      expect(
        engine.callsTo('getAudioTracks'),
        hasLength(2),
        reason: 'the revision, not a Retry press, re-read the list',
      );
      expect(find.widgetWithText(PanelRow, l10n.retry), findsOneWidget);
      expect(_focusedRow(), 'Stereo');
      expect(_selectedRows(tester), <String>['Stereo']);
    });

    testWidgets('a position tick does not rebuild the list', (tester) async {
      // The controller notifies four times a second as playback advances.
      // The list draws from the active id and the revision alone, so the
      // very same ListView stays in the tree across a position-only snapshot
      // and is replaced only when the engine's answer changes.
      final engine = FakeVlcEngine()
        ..audio = <Map<String, Object?>>[
          _track(1, 'Stereo'),
          _track(2, 'Commentary'),
        ]
        ..activeAudioId = 1;
      await pumpPanel(tester, tab: PlayerPanelTab.audio, engine: engine);
      final before = tester.widget<ListView>(find.byType(ListView));

      await engine.emit(<String, Object?>{'state': 'paused', 'position': 2500});
      await tester.pump();
      expect(
        tester.widget<ListView>(find.byType(ListView)),
        same(before),
        reason: 'a progress tick is not a rebuild',
      );

      engine.activeAudioId = 2;
      await _sync(tester, engine);
      expect(
        tester.widget<ListView>(find.byType(ListView)),
        isNot(same(before)),
      );
      expect(_selectedRows(tester), <String>['Commentary']);
    });

    testWidgets('the audio delay stepper: Right +100 ms, held +500 ms, Select '
        'resets, and the read-out follows the engine', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final engine = FakeVlcEngine()
        ..audio = <Map<String, Object?>>[_track(1, 'Stereo')]
        ..activeAudioId = 1;
      await pumpPanel(tester, tab: PlayerPanelTab.audio, engine: engine);
      expect(find.text(l10n.audioDelay), findsOneWidget);
      expect(find.text('+0ms'), findsOneWidget);

      await _focusStepper(tester);
      await _exerciseDelayStepper(tester, engine, 'setAudioDelay');
    });

    testWidgets('the subtitle delay stepper steps the same way', (
      tester,
    ) async {
      final engine = FakeVlcEngine()
        ..subtitle = <Map<String, Object?>>[_track(2, 'English')]
        ..activeSubtitleId = 2;
      await pumpPanel(tester, tab: PlayerPanelTab.subtitles, engine: engine);
      expect(find.text('+0ms'), findsOneWidget);

      await _focusStepper(tester);
      await _exerciseDelayStepper(tester, engine, 'setSubtitleDelay');
    });

    testWidgets('the delay stepper resets on a game controller A too', (
      tester,
    ) async {
      // Every other stop in the panel takes A as Select - rows, tabs, the
      // close button. This row's Select *is* the reset, so a stepper that
      // ignored A would be the one control a gamepad could not zero.
      const ms = Duration.microsecondsPerMillisecond;
      final engine = FakeVlcEngine()
        ..subtitle = <Map<String, Object?>>[_track(2, 'English')]
        ..activeSubtitleId = 2
        ..subtitleDelayUs = 800 * ms;
      await pumpPanel(tester, tab: PlayerPanelTab.subtitles, engine: engine);
      expect(find.text('+800ms'), findsOneWidget);

      await _focusStepper(tester);
      await tester.sendKeyEvent(
        LogicalKeyboardKey.gameButtonA,
        platform: 'android',
      );
      await tester.pump();

      expect(_lastDelay(engine, 'setSubtitleDelay'), 0, reason: 'A resets');
      await _sync(tester, engine);
      expect(find.text('+0ms'), findsOneWidget);
      expect(_stepperFocused(), isTrue, reason: 'A did not move focus');
    });

    testWidgets('holding + steps coarse, the way a held key does', (
      tester,
    ) async {
      // A phone has no key to hold and the sheet this row replaced moved
      // 500 ms per tap, so a fine-only pointer would be twenty taps for the
      // two seconds a badly muxed subtitle usually needs.
      const ms = Duration.microsecondsPerMillisecond;
      final engine = FakeVlcEngine()
        ..subtitle = <Map<String, Object?>>[_track(2, 'English')]
        ..activeSubtitleId = 2;
      await pumpPanel(
        tester,
        size: _phone,
        isTv: false,
        focusOnOpen: false,
        tab: PlayerPanelTab.subtitles,
        engine: engine,
      );

      // A tap is still the fine step.
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      expect(_lastDelay(engine, 'setSubtitleDelay'), 100 * ms, reason: 'tap');
      await _sync(tester, engine);
      expect(find.text('+100ms'), findsOneWidget);

      // A finger left on the button repeats the coarse step, and each repeat
      // builds on the delay the engine has echoed back by then.
      final hold = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.add_rounded)),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        _lastDelay(engine, 'setSubtitleDelay'),
        600 * ms,
        reason: 'a hold is coarse',
      );
      await _sync(tester, engine);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_lastDelay(engine, 'setSubtitleDelay'), 1100 * ms);
      await _sync(tester, engine);
      expect(find.text('+1.1s'), findsOneWidget);

      // Letting go ends the hold and is not one more step on top of it.
      await hold.up();
      await tester.pump();
      expect(
        _lastDelay(engine, 'setSubtitleDelay'),
        1100 * ms,
        reason: 'the release that ends a hold is not a fine step too',
      );
      await _sync(tester, engine);
      expect(find.text('+1.1s'), findsOneWidget);
    });

    testWidgets('the reset button appears with a delay to undo and zeroes it', (
      tester,
    ) async {
      // Select resets, and a phone has no Select: without a button beside the
      // value a touch viewer can walk the delay away from zero and never get
      // it back.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final engine = FakeVlcEngine()
        ..subtitle = <Map<String, Object?>>[_track(2, 'English')]
        ..activeSubtitleId = 2;
      await pumpPanel(
        tester,
        size: _phone,
        isTv: false,
        focusOnOpen: false,
        tab: PlayerPanelTab.subtitles,
        engine: engine,
      );
      expect(find.text('+0ms'), findsOneWidget);
      expect(
        find.byTooltip(l10n.resetDelay),
        findsNothing,
        reason: 'nothing to reset at rest',
      );

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      await _sync(tester, engine);
      expect(find.text('+100ms'), findsOneWidget);
      expect(find.byTooltip(l10n.resetDelay), findsOneWidget);
      expect(
        _focusStopsIn(find.byType(PanelStepperRow).evaluate().single),
        1,
        reason: 'the reset button is the pointer\'s, not a D-pad stop',
      );

      await tester.tap(find.byTooltip(l10n.resetDelay));
      await tester.pump();
      expect(_lastDelay(engine, 'setSubtitleDelay'), 0);
      await _sync(tester, engine);
      expect(find.text('+0ms'), findsOneWidget);
      expect(
        find.byTooltip(l10n.resetDelay),
        findsNothing,
        reason: 'and it goes away again with nothing left to undo',
      );
    });

    testWidgets('off TV nothing is focused until the viewer asks', (
      tester,
    ) async {
      // A focus ring nobody asked for is just a mark on a phone's screen.
      await pumpPanel(
        tester,
        size: _phone,
        isTv: false,
        focusOnOpen: false,
        tab: PlayerPanelTab.subtitles,
        engine: FakeVlcEngine()
          ..subtitle = <Map<String, Object?>>[_track(1, 'English')],
      );

      expect(_focusedRow(), isNull);
      expect(_stepperFocused(), isFalse);
    });

    testWidgets('DOWN on the subtitles tab reaches Load and Search in order, '
        'and the stepper is one stop', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpPanel(
        tester,
        tab: PlayerPanelTab.subtitles,
        engine: FakeVlcEngine()
          ..subtitle = <Map<String, Object?>>[_track(1, 'English')],
      );
      expect(_focusedRow(), l10n.off);

      final visited = <String?>[];
      while (_focusedRow() != l10n.searchSubtitlesOnline) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        visited.add(_focusedRow());
        expect(visited.length, lessThan(8), reason: 'Search is reachable');
      }
      expect(
        visited,
        containsAllInOrder(<String>[
          'English',
          l10n.retry,
          l10n.loadSubtitleFile,
          l10n.searchSubtitlesOnline,
        ]),
      );

      // One more press lands on the stepper, and the stepper is a single
      // stop: its -/+ buttons are the pointer's way in, not the D-pad's.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(_stepperFocused(), isTrue);
      expect(
        _focusStopsIn(find.byType(PanelStepperRow).evaluate().single),
        1,
        reason:
            'anything focusable inside the stepper is a press that lands '
            'nowhere the viewer can see',
      );
    });

    testWidgets('Retry re-reads the engine and lands focus on a row again', (
      tester,
    ) async {
      // A track that showed up after the panel opened - a side-car still
      // being fetched - is only visible once the engine is asked again. The
      // reload unmounts every row, the focused one included, so the new list
      // has to take focus back or the remote is left on the route scope.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final engine = FakeVlcEngine()
        ..audio = <Map<String, Object?>>[_track(1, 'Stereo')];
      await pumpPanel(tester, tab: PlayerPanelTab.audio, engine: engine);
      expect(find.text('Commentary'), findsNothing);

      engine.audio = <Map<String, Object?>>[
        ...engine.audio,
        _track(2, 'Commentary'),
      ];
      await tester.tap(find.widgetWithText(PanelRow, l10n.retry));
      await tester.pumpAndSettle();

      expect(find.text('Commentary'), findsOneWidget);
      expect(_focusedRow(), isNotNull, reason: 'focus is back in the list');
    });

    testWidgets('Retry on a switched-to tab lands focus on a row too', (
      tester,
    ) async {
      // After a tab switch the rows deliberately do not autofocus - focus
      // belongs on the strip - but a Retry pressed from inside the list means
      // the viewer is in the list, and the reload must not strand them.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final engine = FakeVlcEngine()
        ..audio = <Map<String, Object?>>[_track(1, 'Stereo')];
      await pumpPanel(tester, tab: PlayerPanelTab.subtitles, engine: engine);

      await tester.tap(find.text(l10n.audio));
      await tester.pumpAndSettle();
      expect(find.text('Stereo'), findsOneWidget);
      expect(_focusedRow(), isNull, reason: 'a switch does not drag focus in');

      engine.audio = <Map<String, Object?>>[
        ...engine.audio,
        _track(2, 'Commentary'),
      ];
      await tester.tap(find.widgetWithText(PanelRow, l10n.retry));
      await tester.pumpAndSettle();

      expect(find.text('Commentary'), findsOneWidget);
      expect(
        _focusedRow(),
        isNotNull,
        reason: 'Retry must never leave focus on the route scope',
      );
    });
  });

  group('close button', () {
    testWidgets('responds to a game controller A like a row does', (
      tester,
    ) async {
      await pumpPanel(tester);

      Focus.of(tester.element(find.byIcon(Icons.close_rounded))).requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(
        LogicalKeyboardKey.gameButtonA,
        platform: 'android',
      );
      await tester.pumpAndSettle();

      expect(find.byType(PlayerPanel), findsNothing);
      expect(find.text('sources'), findsOneWidget, reason: 'the player stays');
    });
  });

  group('episodes', () {
    testWidgets('opens on the episode that is playing', (tester) async {
      await pumpPanel(
        tester,
        tab: PlayerPanelTab.episodes,
        episodes: <Episode>[_episode(1), _episode(2), _episode(3)],
        currentEpisode: _episode(2),
      );

      expect(_focusedRow(), contains('Episode 2'));
    });

    testWidgets('picking one closes the panel and reports it', (tester) async {
      final picked = <Episode>[];
      await pumpPanel(
        tester,
        tab: PlayerPanelTab.episodes,
        episodes: <Episode>[_episode(1), _episode(2)],
        currentEpisode: _episode(1),
        onPickEpisode: picked.add,
      );

      await tester.tap(find.textContaining('Episode 2'));
      await tester.pumpAndSettle();

      expect(picked.single.episode, 2);
      expect(find.byType(PlayerPanel), findsNothing);
    });
  });

  // Sixty rows of an anime are otherwise identical. What is pinned here is
  // that the panel answers "which of these have I seen" the way the details
  // screen already does for the same list — and that it asks the question
  // lazily, which is the only reason a 200-episode season is affordable.
  group('watched progress', () {
    /// Three episodes with [fractions] and [watched] applied by number.
    EpisodeProgressLookup lookup({
      Map<int, double> fractions = const <int, double>{},
      Set<int> watched = const <int>{},
    }) =>
        (episode) => EpisodeProgress(
          fraction: fractions[episode.episode] ?? 0,
          watched: watched.contains(episode.episode),
        );

    testWidgets('a part-watched episode paints a bar and an untouched one '
        'paints none', (tester) async {
      await pumpPanel(
        tester,
        tab: PlayerPanelTab.episodes,
        episodes: <Episode>[_episode(1), _episode(2), _episode(3)],
        currentEpisode: _episode(3),
        episodeProgress: lookup(fractions: const <int, double>{2: 0.42}),
      );

      expect(_rowBar(tester, 'Episode 2'), closeTo(0.42, 1e-9));
      expect(
        _rowBar(tester, 'Episode 1'),
        isNull,
        reason: 'nothing stored for it, so nothing to say about it',
      );
    });

    testWidgets('with no lookup at all the tab is exactly what it was', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        tab: PlayerPanelTab.episodes,
        episodes: <Episode>[_episode(1), _episode(2)],
        currentEpisode: _episode(1),
      );

      expect(
        find.byType(LinearProgressIndicator, skipOffstage: false),
        findsNothing,
      );
      expect(_rowDimmed(tester, 'Episode 2'), isFalse);
      expect(_rowBadges(tester, 'Episode 2'), isEmpty);
    });

    testWidgets('the dead band holds: 1 % is a false start and 99 % is done', (
      tester,
    ) async {
      // Below 2 % a sliver of bar reads as "you began this" when a wrong pick
      // or a stream that never played is all that happened; above 98 % a bar
      // is indistinguishable from full, and a full bar on a row that is not
      // marked watched reads as a bug.
      await pumpPanel(
        tester,
        tab: PlayerPanelTab.episodes,
        episodes: <Episode>[_episode(1), _episode(2), _episode(3), _episode(4)],
        currentEpisode: _episode(4),
        episodeProgress: lookup(
          fractions: const <int, double>{1: 0.01, 2: 0.03, 3: 0.99},
        ),
      );

      expect(_rowBar(tester, 'Episode 1'), isNull, reason: '1 % is nothing');
      expect(_rowBar(tester, 'Episode 2'), closeTo(0.03, 1e-9));
      expect(_rowBar(tester, 'Episode 3'), isNull, reason: '99 % is finished');
    });

    testWidgets('the row that is playing shows no bar and no dim, whatever '
        'the store says', (tester) async {
      // The recorder only writes on a 5 % threshold, so the stored position of
      // the episode on screen is always behind it. A stale half-bar under a
      // `Playing` badge is worse than no bar.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpPanel(
        tester,
        tab: PlayerPanelTab.episodes,
        episodes: <Episode>[_episode(1), _episode(2)],
        currentEpisode: _episode(2),
        episodeProgress: lookup(
          fractions: const <int, double>{1: 0.5, 2: 0.5},
          watched: const <int>{2},
        ),
      );

      expect(_rowBar(tester, 'Episode 2'), isNull);
      expect(_rowDimmed(tester, 'Episode 2'), isFalse);
      expect(
        _rowBar(tester, 'Episode 1'),
        closeTo(0.5, 1e-9),
        reason: 'the suppression is about the playing row, not the lookup',
      );
      // The chip is deliberately NOT suppressed: unlike a position it cannot
      // be stale, and on a re-watch it says something the play glyph does not.
      expect(_rowBadges(tester, 'Episode 2'), <String>[
        l10n.playing,
        l10n.watched,
      ]);
    });

    testWidgets('a watched episode is dimmed, chipped, and never barred', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpPanel(
        tester,
        tab: PlayerPanelTab.episodes,
        episodes: <Episode>[_episode(1), _episode(2)],
        currentEpisode: _episode(1),
        episodeProgress: lookup(
          // Marked by hand at 40 %, which is exactly the case the bar must
          // not contradict: the repository's answer wins over the position.
          fractions: const <int, double>{2: 0.4},
          watched: const <int>{2},
        ),
      );

      expect(_rowDimmed(tester, 'Episode 2'), isTrue);
      expect(_rowBadges(tester, 'Episode 2'), <String>[l10n.watched]);
      expect(
        _rowBar(tester, 'Episode 2'),
        isNull,
        reason: 'a watched episode never carries a partial bar as well',
      );
      expect(_rowDimmed(tester, 'Episode 1'), isFalse);
      expect(_rowBadges(tester, 'Episode 1'), <String>[
        l10n.playing,
      ], reason: 'the row playing keeps its own chip and gains nothing');
    });

    testWidgets('the Watched chip is localised, not a hard-coded word', (
      tester,
    ) async {
      final hi = await AppLocalizations.delegate.load(const Locale('hi'));
      await pumpPanel(
        tester,
        locale: const Locale('hi'),
        tab: PlayerPanelTab.episodes,
        episodes: <Episode>[_episode(1), _episode(2)],
        currentEpisode: _episode(1),
        episodeProgress: lookup(watched: const <int>{2}),
      );

      expect(hi.watched, isNot('Watched'), reason: 'the case is worth testing');
      expect(_rowBadges(tester, 'Episode 2'), contains(hi.watched));
      expect(find.text('Watched', skipOffstage: false), findsNothing);
    });

    testWidgets('on a television the Watched chip shares one line with the dub '
        'badge inside the drawer', (tester) async {
      // The chip joins the badge wrap on the one surface where the wrap is
      // already at ten-foot type inside a 460 dp drawer. If it pushed the
      // badges onto a second run the row would grow past the anchored list's
      // 84 dp seed on a list a remote scrolls, so it is measured rather than
      // assumed - and measured at 960x540 with W2.2's television ramp, not at
      // the phone scale where it would prove nothing.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final dubbed = <Episode>[
        for (var i = 1; i <= 2; i++)
          Episode(
            name: 'Episode $i',
            url: 'https://series.test/dubbed/$i',
            season: 1,
            episode: i,
            runtime: 42,
            airDate: '2024-01-0$i',
            dubStatus: DubStatus.dubbed,
          ),
      ];
      await pumpPanel(
        tester,
        tab: PlayerPanelTab.episodes,
        episodes: dubbed,
        currentEpisode: dubbed.first,
        episodeProgress: (episode) => const EpisodeProgress(watched: true),
      );

      final row = _episodeRow('Episode 2');
      final chips = find.descendant(
        of: row,
        matching: find.byType(PanelBadge, skipOffstage: false),
      );
      expect(_rowBadges(tester, 'Episode 2'), <String>[
        l10n.dub.toUpperCase(),
        l10n.watched,
      ]);
      final rects = chips
          .evaluate()
          .map((element) => tester.getRect(find.byWidget(element.widget)))
          .toList();
      expect(
        rects.map((rect) => rect.top).toSet(),
        hasLength(1),
        reason: 'one run: the chip did not wrap the badges onto a second line',
      );
      final drawer = tester.getRect(find.byKey(kPlayerPanelSurfaceKey));
      expect(
        rects.last.right,
        lessThan(drawer.right),
        reason: 'and it stays inside the drawer, overscan inset and all',
      );
      expect(
        tester.getRect(row.first).height,
        lessThan(2 * 84),
        reason: 'still one row, not two',
      );
    });

    testWidgets('a watched row is still exactly one focus stop', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        tab: PlayerPanelTab.episodes,
        episodes: <Episode>[_episode(1), _episode(2)],
        currentEpisode: _episode(1),
        episodeProgress: lookup(
          fractions: const <int, double>{2: 0.5},
          watched: const <int>{2},
        ),
      );

      expect(_focusStopsIn(_episodeRow('Episode 2').evaluate().single), 1);
    });

    // THE LOAD-BEARING ONES. Every call hashes the episode with SHA-256
    // (`EpisodeWatchRepository._episodeKey`) and reads history twice, so the
    // difference between asking per built row and filling a map is the
    // difference between a panel that opens and one that stutters on a 2016
    // television. If someone 'simplifies' this back onto PanelData, these are
    // the tests that say no.
    //
    // Counts are printed rather than only asserted, so the ceilings can be
    // re-derived when a row changes shape.
    testWidgets(
      'a 200-episode season opened at the top asks about a screenful',
      (tester) async {
        final asked = <int>[];
        final episodes = List<Episode>.generate(
          200,
          (i) => _paddedEpisode(i + 1),
        );
        await pumpPanel(
          tester,
          tab: PlayerPanelTab.episodes,
          episodes: episodes,
          currentEpisode: episodes.first,
          episodeProgress: (episode) {
            asked.add(episode.episode);
            return EpisodeProgress.none;
          },
        );

        debugPrint(
          'episodeProgress @anchor 0: ${asked.length} calls over '
          '${asked.toSet().length} distinct of 200',
        );
        expect(
          asked.toSet().length,
          lessThan(40),
          reason: 'the visible rows plus the 800 px cache, not the season',
        );
      },
    );

    testWidgets('a 200-episode season opened mid-list stops at the anchor, '
        'never the end', (tester) async {
      // SliverList lays out forward from index 0, so opening on episode 101
      // does walk the rows before it - that is the honest cost of a lazy list
      // and it is still bounded by the anchor. What must never happen is the
      // other 99 rows below being asked about, which is precisely what a
      // PanelData map would do.
      final asked = <int>[];
      final episodes = List<Episode>.generate(
        200,
        (i) => _paddedEpisode(i + 1),
      );
      await pumpPanel(
        tester,
        tab: PlayerPanelTab.episodes,
        episodes: episodes,
        currentEpisode: episodes[100],
        episodeProgress: (episode) {
          asked.add(episode.episode);
          return EpisodeProgress.none;
        },
      );

      final distinct = asked.toSet();
      debugPrint(
        'episodeProgress @anchor 100: ${asked.length} calls over '
        '${distinct.length} distinct of 200',
      );
      expect(distinct, contains(101), reason: 'the anchor row was built');
      expect(
        distinct.where((number) => number > 130),
        isEmpty,
        reason: 'nothing below the anchor and its cache is ever asked about',
      );
      expect(distinct.length, lessThan(150));
    });

    testWidgets('a republish re-asks about the mounted rows only', (
      tester,
    ) async {
      // The screen republishes PanelData on every probe answer and on a 3 s
      // torrent poll. Eagerly, each one would be 200 digests; lazily it is the
      // rows still mounted, and the walk to the anchor is not repeated because
      // the sliver keeps the children it already has.
      final asked = <int>[];
      final episodes = List<Episode>.generate(
        200,
        (i) => _paddedEpisode(i + 1),
      );
      final panel = await pumpPanel(
        tester,
        tab: PlayerPanelTab.episodes,
        episodes: episodes,
        currentEpisode: episodes[100],
        episodeProgress: (episode) {
          asked.add(episode.episode);
          return EpisodeProgress.none;
        },
      );

      asked.clear();
      panel.data.value = panel.data.value.copyWith(currentSourceIndex: 2);
      await tester.pumpAndSettle();

      debugPrint('episodeProgress on republish: ${asked.length} calls');
      expect(
        asked.length,
        lessThan(40),
        reason: 'a publish must not re-walk the season',
      );
    });
  });

  group('live data', () {
    testWidgets('probe outcomes update while the panel is open', (
      tester,
    ) async {
      // The probe keeps answering for seconds after playback starts, and a
      // viewer who opened Sources to see what it found should see it land
      // rather than the state of the race at the moment they pressed.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final panel = await pumpPanel(
        tester,
        probes: const <int, ProbeOutcome>{
          0: ProbeOutcome.healthy,
          1: ProbeOutcome.trying,
          2: ProbeOutcome.trying,
        },
      );
      expect(
        find.widgetWithText(PanelBadge, l10n.playerSourceChecking),
        findsNWidgets(2),
      );
      expect(
        find.widgetWithText(PanelBadge, l10n.unknown),
        findsNothing,
      );

      panel.data.value = panel.data.value.copyWith(
        probes: const <int, ProbeOutcome>{
          0: ProbeOutcome.healthy,
          1: ProbeOutcome.unhealthy,
          2: ProbeOutcome.healthy,
        },
      );
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(PanelBadge, l10n.unknown),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(PanelBadge, l10n.playerSourceChecking),
        findsNothing,
      );
      expect(
        find.widgetWithText(PanelBadge, l10n.playerSourceReachable),
        findsNWidgets(2),
      );
    });

    testWidgets('a live update does not move focus', (tester) async {
      // A failover under an open panel ticks a different row. It must not
      // drag the highlight there: the viewer is mid-way through choosing.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final panel = await pumpPanel(tester, currentSourceIndex: 1);
      expect(_focusedRow(), '720p');
      final focused = FocusManager.instance.primaryFocus;
      expect(focused, isNotNull);

      panel.data.value = panel.data.value.copyWith(
        currentSourceIndex: 2,
        probes: const <int, ProbeOutcome>{1: ProbeOutcome.unhealthy},
      );
      await tester.pumpAndSettle();

      expect(
        FocusManager.instance.primaryFocus,
        same(focused),
        reason: 'the very same node still holds focus',
      );
      expect(_focusedRow(), '720p');
      expect(
        find.descendant(
          of: find.widgetWithText(PanelRow, 'Server 3'),
          matching: find.widgetWithText(PanelBadge, l10n.playerNowPlaying),
        ),
        findsOneWidget,
        reason: 'the tick moved to the source now playing',
      );
    });

    testWidgets('the Now playing tick follows a failover', (tester) async {
      final panel = await pumpPanel(tester, currentSourceIndex: 0);
      expect(_selectedRows(tester), <String>['1080p']);

      panel.data.value = panel.data.value.copyWith(currentSourceIndex: 2);
      await tester.pumpAndSettle();

      expect(_selectedRows(tester), <String>['Server 3']);
    });

    testWidgets('sources emptied and refilled leave a row focused', (
      tester,
    ) async {
      // The screen never publishes an empty list mid re-resolve, but the panel
      // must survive one anyway: the tab goes, the first tab left takes over
      // as a fresh open, and when the list is back so is the viewer's tab -
      // with focus on a row at every step.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final panel = await pumpPanel(
        tester,
        engine: FakeVlcEngine()
          ..audio = <Map<String, Object?>>[_track(1, 'Stereo')],
      );
      expect(_focusedRow(), '1080p');

      panel.data.value = panel.data.value.copyWith(
        sources: const <StreamResult>[],
        currentSourceIndex: -1,
      );
      await tester.pumpAndSettle();

      expect(find.byType(PlayerSourcesTab), findsNothing);
      expect(find.text(l10n.sources), findsNothing, reason: 'no such tab');
      expect(find.text('Stereo'), findsOneWidget, reason: 'Audio took over');
      expect(_focusedRow(), 'Stereo', reason: 'a fresh open, not a switch');

      panel.data.value = panel.data.value.copyWith(
        sources: _sources(),
        currentSourceIndex: 0,
      );
      await tester.pumpAndSettle();

      expect(find.byType(PlayerSourcesTab), findsOneWidget);
      expect(
        FocusScope.of(tester.element(find.byType(PlayerPanel))).focusedChild,
        isNotNull,
      );
      expect(_focusedRow(), '1080p', reason: 'back on the tab it opened on');
    });

    testWidgets('the Files tab grows as the torrent lists more files', (
      tester,
    ) async {
      final panel = await pumpPanel(
        tester,
        tab: PlayerPanelTab.files,
        files: _packFiles(2),
        currentFileIndex: 3,
      );
      expect(find.byType(PlayerFilesTab), findsOneWidget);
      expect(find.byType(PanelRow, skipOffstage: false), findsNWidgets(2));

      panel.data.value = panel.data.value.copyWith(files: _packFiles(5));
      await tester.pumpAndSettle();

      expect(find.byType(PanelRow, skipOffstage: false), findsNWidgets(5));
      expect(_selectedRows(tester), <String>['Pack.S01E01.mkv']);
    });

    testWidgets('the Files tab vanishing shows the first tab, focused', (
      tester,
    ) async {
      // The torrent stopped under an open Files tab - the next episode is a
      // plain URL. No throw, the first tab left is shown, and on a remote a
      // row of it holds focus: the rows that did are gone.
      final panel = await pumpPanel(
        tester,
        tab: PlayerPanelTab.files,
        files: _packFiles(3),
        currentFileIndex: 7,
      );
      expect(_focusedRow(), 'Pack.S01E02.mkv');

      panel.data.value = panel.data.value.copyWith(
        files: const <TorrentFile>[],
        clearCurrentFileIndex: true,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(PlayerFilesTab), findsNothing);
      expect(find.byType(PlayerSourcesTab), findsOneWidget);
      expect(_focusedRow(), '1080p', reason: 'a PanelRow holds focus');
    });

    testWidgets('mutating the map the screen holds changes nothing', (
      tester,
    ) async {
      // What passing `probes: _probes` by reference used to do: the screen's
      // clear() emptied the chips under an open panel. A value is published
      // or it is not.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final probes = <int, ProbeOutcome>{0: ProbeOutcome.healthy};
      await pumpPanel(tester, probes: probes);
      expect(
        find.widgetWithText(PanelBadge, l10n.playerSourceReachable),
        findsOneWidget,
      );

      probes.clear();
      probes[1] = ProbeOutcome.unhealthy;
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.widgetWithText(PanelBadge, l10n.playerSourceReachable),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(PanelBadge, l10n.unknown),
        findsNothing,
      );
    });

    testWidgets('an equal value published again rebuilds nothing', (
      tester,
    ) async {
      // The torrent poll publishes every three seconds. Equality on the
      // value is what stops that reaching the panel when nothing changed.
      final panel = await pumpPanel(
        tester,
        probes: const <int, ProbeOutcome>{0: ProbeOutcome.healthy},
        episodes: <Episode>[_episode(1), _episode(2)],
        currentEpisode: _episode(1),
        files: _packFiles(2),
        currentFileIndex: 3,
      );
      var notifications = 0;
      panel.data.addListener(() => notifications++);
      final before = tester.widget<PlayerSourcesTab>(
        find.byType(PlayerSourcesTab),
      );

      final current = panel.data.value;
      panel.data.value = PanelData(
        sources: current.sources,
        currentSourceIndex: current.currentSourceIndex,
        // Fresh collections with the same contents, as the screen builds
        // them: a new map copy, a re-filtered episode list, a re-parsed pack.
        probes: Map<int, ProbeOutcome>.of(current.probes),
        episodes: <Episode>[_episode(1), _episode(2)],
        currentEpisode: _episode(1),
        files: _packFiles(2),
        currentFileIndex: 3,
      );
      await tester.pumpAndSettle();

      expect(notifications, 0);
      expect(
        tester.widget<PlayerSourcesTab>(find.byType(PlayerSourcesTab)),
        same(before),
        reason: 'the panel did not rebuild',
      );

      panel.data.value = current.copyWith(currentSourceIndex: 1);
      await tester.pumpAndSettle();
      expect(notifications, 1);
    });

    testWidgets('equality tells sources apart by identity', (tester) async {
      // StreamResult has no ==, and the screen holds one list per resolve.
      final a = _sources();
      final b = _sources();
      expect(PanelData(sources: a), PanelData(sources: a));
      expect(PanelData(sources: a), isNot(PanelData(sources: b)));
      expect(PanelData(sources: a).hashCode, PanelData(sources: a).hashCode);
      expect(
        PanelData(files: _packFiles(3)),
        PanelData(files: _packFiles(3)),
        reason: 'files compare by content: the poll re-parses them every tick',
      );
      expect(
        PanelData(files: _packFiles(3)),
        isNot(PanelData(files: _packFiles(4))),
      );
      expect(
        PanelData(files: _packFiles(3)).tabs,
        contains(PlayerPanelTab.files),
      );
      expect(PanelData.empty.tabs, <PlayerPanelTab>{
        PlayerPanelTab.audio,
        PlayerPanelTab.subtitles,
      });
    });
  });

  group('anchoring', () {
    const desktop = Size(1280, 800);

    testWidgets('a touch Sources list opens with the playing row mid-list', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpPanel(
        tester,
        size: desktop,
        isTv: false,
        focusOnOpen: false,
        sources: _manySources(40),
        currentSourceIndex: 30,
      );

      final playing = tester.getRect(
        find.ancestor(
          of: find.widgetWithText(PanelBadge, l10n.playerNowPlaying),
          matching: find.byType(PanelRow),
        ),
      );
      final list = _listRect(tester);
      expect(_inside(list, playing), isTrue, reason: 'on screen, not cached');
      expect(
        (playing.center.dy - list.center.dy).abs(),
        lessThanOrEqualTo(playing.height),
        reason: 'within one row of the centre',
      );
      expect(_focusedRow(), isNull, reason: 'a thumb asked for no focus');
    });

    testWidgets('a touch Episodes list opens on the playing episode', (
      tester,
    ) async {
      final episodes = List<Episode>.generate(24, (i) => _paddedEpisode(i + 1));
      await pumpPanel(
        tester,
        size: desktop,
        isTv: false,
        focusOnOpen: false,
        tab: PlayerPanelTab.episodes,
        episodes: episodes,
        currentEpisode: episodes[17],
      );

      expect(find.byType(PlayerEpisodesTab), findsOneWidget);
      expect(find.textContaining('Ep 18'), findsOneWidget, reason: 'visible');
      expect(
        find.textContaining('Ep 01'),
        findsNothing,
        reason: 'the list did not open at the top',
      );
    });

    testWidgets('on a television the focused row is fully on screen', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        sources: _manySources(40),
        currentSourceIndex: 30,
      );

      expect(_focusedRow(), 'Server 30');
      final row = _rowRect(tester, 'Server 30');
      expect(_inside(_listRect(tester), row), isTrue);
    });

    testWidgets('switching to Sources from the strip shows the playing row '
        'and leaves focus on the tab', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpPanel(
        tester,
        tab: PlayerPanelTab.subtitles,
        sources: _manySources(40),
        currentSourceIndex: 30,
      );
      expect(_focusedRow(), l10n.off);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(_focusedRow(), isNull, reason: 'on the strip');
      for (var i = 0; i < 4 && _focusedSemanticsLabel() != l10n.sources; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
      }
      expect(_focusedSemanticsLabel(), l10n.sources);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      expect(find.byType(PlayerSourcesTab), findsOneWidget);
      final playing = tester.getRect(
        find.ancestor(
          of: find.widgetWithText(PanelBadge, l10n.playerNowPlaying),
          matching: find.byType(PanelRow),
        ),
      );
      expect(_inside(_listRect(tester), playing), isTrue);
      expect(_focusedRow(), isNull, reason: 'a switch keeps focus on the tab');
      expect(_focusedSemanticsLabel(), l10n.sources);
    });

    testWidgets('the Files tab anchors on the playing file id, not position', (
      tester,
    ) async {
      final files = _packFiles(40);
      final playing = files[30]; // id 123
      await pumpPanel(
        tester,
        tab: PlayerPanelTab.files,
        files: files,
        currentFileIndex: playing.index,
      );

      expect(_focusedRow(), playing.name);
      expect(_selectedRows(tester), <String>[playing.name]);
      expect(
        _inside(_listRect(tester), _rowRect(tester, playing.name)),
        isTrue,
      );
    });

    testWidgets('the Subtitles tab opens on the active track even when it is '
        'far past the rows a lazy list builds', (tester) async {
      // A remux carrying thirty subtitle tracks on a 1080p television: the
      // active row is nowhere near the top, so nothing above it can stand in
      // for it. A list that only autofocuses rows its builder happened to run
      // leaves the panel with no focus at all here, and the first DOWN then
      // goes to the tab strip instead of into the list.
      await pumpPanel(
        tester,
        size: _googleTv,
        tab: PlayerPanelTab.subtitles,
        engine: FakeVlcEngine()
          ..subtitle = _manyTracks(30)
          ..activeSubtitleId = 25,
      );

      expect(_focusedRow(), 'Sub 25');
      expect(_selectedRows(tester), <String>['Sub 25']);
      expect(
        _inside(_trackListRect(tester), _rowRect(tester, 'Sub 25')),
        isTrue,
        reason: 'focused and on screen, not focused somewhere below the fold',
      );
    });

    testWidgets('a mid-list audio track is centred, not merely built', (
      tester,
    ) async {
      // Index 14 is inside the trailing cache, so it does get built and does
      // take focus - and without a scroll it sits well below the fold, where
      // the first DOWN teleports the list somewhere the viewer never chose.
      await pumpPanel(
        tester,
        size: _googleTv,
        tab: PlayerPanelTab.audio,
        engine: FakeVlcEngine()
          ..audio = _manyTracks(20, prefix: 'Aud')
          ..activeAudioId = 14,
      );

      expect(_focusedRow(), 'Aud 14');
      final row = _rowRect(tester, 'Aud 14');
      final list = _trackListRect(tester);
      expect(_inside(list, row), isTrue);
      expect(
        (row.center.dy - list.center.dy).abs(),
        lessThanOrEqualTo(row.height),
        reason: 'within one row of the centre, like every other panel list',
      );
    });
  });
}
