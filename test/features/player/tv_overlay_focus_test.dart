import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/core/services/download_service.dart';
import 'package:skystream/features/player/presentation/vlc/next_episode_countdown.dart';
import 'package:skystream/features/player/presentation/vlc/panel/player_panel.dart'
    show PlayerPanel;
import 'package:skystream/features/player/presentation/vlc/vlc_player_controls.dart';
import 'package:skystream/features/player/presentation/vlc/vlc_player_screen.dart';
import 'package:skystream/features/player/presentation/widgets/hotstar_player_style.dart';
import 'package:skystream/features/player/presentation/widgets/player_control_components.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';

import 'vlc_screen_harness.dart';

/// Where the remote is while an overlay is up, driven through the real screen.
///
/// This has to be a *screen* test. next_episode_countdown_test hosts the card
/// on its own, where the enclosing scope has no focused child and a plain
/// autofocus therefore lands - which is exactly why it stayed green while the
/// card was unreachable in the product. In the player the card is a sibling of
/// [VlcPlayerControls] in one Stack, and the controls guarantee the route
/// scope always has a focused child (a chrome button, or their key sink).
/// Flutter applies a pending autofocus only when `scope.focusedChild == null`
/// (focus_manager.dart, `_Autofocus.applyIfValid`), so the card's autofocus
/// was discarded on every appearance: on a television a 15-second destructive
/// auto-advance sat behind blind D-pad presses with no focus ring to aim at,
/// and the card's own Back-means-Cancel handler - which only runs when focus
/// is inside the card - never ran either.
void main() {
  setUp(installEngineMocks);
  tearDown(removeEngineMocks);

  Future<AppLocalizations> english() =>
      AppLocalizations.delegate.load(const Locale('en'));

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
    // A still, because the card is at its tallest with one and its height is
    // what the two clearance tests below are about - without one the card is
    // 38 dp shorter and would clear the top bar even with the clearance
    // deleted. It never resolves here (the binding answers every request with
    // a 400), so what renders is the card's own placeholder in a box that is
    // already laid out.
    posterUrl: 'https://example.com/e2.jpg',
    // Carried so the ten-foot geometry test can ask whether the card kept the
    // description, which is the first thing the phone layout drops.
    description: 'Buffy comes home to find her mother on the couch.',
  );

  /// A two-episode show that plays directly: `Remote` is the provider the
  /// resolver treats as already-playable, so no plugin is involved and the
  /// only thing this file has to stand up is playback itself.
  final show = MultimediaItem(
    title: 'Show',
    url: 'https://example.com/show',
    posterUrl: '',
    contentType: MultimediaContentType.series,
    episodes: [firstEpisode, nextEpisode],
    provider: 'Remote',
  );

  /// Drives the first episode to ten seconds from its end, which is inside the
  /// screen's 15-second lead-in and is what raises the card.
  ///
  /// Hands back a peek at the download service, which is the advance's own
  /// tell: the disk lookup is the first await of `_advance` and the service is
  /// built lazily the first time that runs, so null means no advance was ever
  /// started, and non-null means one started and is parked on the shut gate.
  Future<GatedDownloads? Function()> pumpToCredits(WidgetTester tester) async {
    GatedDownloads? downloads;
    await pumpPlayer(
      tester,
      item: show,
      episode: firstEpisode,
      videoUrl: firstEpisode.url,
      overrides: [
        downloadServiceProvider.overrideWith(
          (ref) => downloads = GatedDownloads(ref),
        ),
      ],
    );
    await sendFirstFrame(tester);
    await sendEvent(tester, snapshot(position: 1190000, duration: 1200000));
    await tester.pump();
    return () => downloads;
  }

  /// Back as a remote delivers its key half. The screen's own Back handling is
  /// driven by `popRoute`; this is the press reaching the focused node, which
  /// is what the card listens for.
  Future<void> sendBackKey(WidgetTester tester) => tester.sendKeyEvent(
    LogicalKeyboardKey.goBack,
    platform: 'android',
    physicalKey: PhysicalKeyboardKey.escape,
  );

  /// A game controller's Select. Android is the only platform whose tables
  /// carry BUTTON_A, and it is the platform that matters: a Shield remote, an
  /// Xbox or PlayStation pad, and any Android TV device reporting DPAD_CENTER
  /// as BUTTON_A all arrive here.
  Future<void> sendGameButtonA(WidgetTester tester) => tester.sendKeyEvent(
    LogicalKeyboardKey.gameButtonA,
    platform: 'android',
    physicalKey: PhysicalKeyboardKey.gameButtonA,
  );

  group('the up-next card on a television', () {
    testWidgets('takes the remote when it appears', variant: texturePlatform, (
      tester,
    ) async {
      await pumpToCredits(tester);
      final l10n = await english();

      expect(find.text(l10n.playNow), findsOneWidget);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        kPlayNextFocusLabel,
        reason: 'the card must own the remote, or the auto-advance is blind',
      );

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      'Back with the card up cancels it and the player stays',
      variant: texturePlatform,
      (tester) async {
        await pumpToCredits(tester);
        final l10n = await english();
        expect(find.text(l10n.playNow), findsOneWidget);

        await sendBackKey(tester);
        await tester.pump();

        expect(
          find.text(l10n.playNow),
          findsNothing,
          reason: 'Back inside the card means "no", not "hide the bars"',
        );
        expect(
          find.byType(VlcPlayerControls),
          findsOneWidget,
          reason: 'declining the advance must not leave the player',
        );
        expect(find.byType(VlcPlayerScreen), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'Cancel answers a game controller A',
      variant: texturePlatform,
      (tester) async {
        final downloads = await pumpToCredits(tester);
        final l10n = await english();

        // Down off Play now, the card's other control: the two actions are
        // stacked so each of them can hold a label the row clipped.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          kCancelFocusLabel,
        );

        await sendGameButtonA(tester);
        await tester.pump();

        expect(find.text(l10n.playNow), findsNothing);
        expect(find.byType(VlcPlayerControls), findsOneWidget);
        expect(downloads(), isNull, reason: 'Cancel must not start an advance');

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'Play now answers a game controller A',
      variant: texturePlatform,
      (tester) async {
        final downloads = await pumpToCredits(tester);
        final l10n = await english();
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          kPlayNextFocusLabel,
        );

        await sendGameButtonA(tester);
        await tester.pump();

        expect(
          find.text(l10n.playNow),
          findsNothing,
          reason: 'A on Play now takes the advance, exactly as Select does',
        );
        // The advance really started and is parked on the gated disk lookup,
        // rather than the card merely having been dismissed.
        expect(
          downloads(),
          isNotNull,
          reason: 'A on Play now must start the advance',
        );
        expect(find.byType(VlcPlayerScreen), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
      },
    );
  });

  group('the up-next card behind an open panel', () {
    /// Whether whatever holds focus is inside the panel, as
    /// screen_panel_test.dart asks it.
    bool focusInPanel() =>
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<PlayerPanel>() !=
        null;

    testWidgets(
      'leaves the remote in the panel, and takes it when the panel closes',
      variant: texturePlatform,
      (tester) async {
        await pumpPlayer(
          tester,
          item: show,
          episode: firstEpisode,
          videoUrl: firstEpisode.url,
        );
        await sendFirstFrame(tester);
        // Forty seconds out: outside the screen's 15 s lead-in, so the card is
        // not up yet and the panel opens over a bare player.
        await sendEvent(tester, snapshot(position: 1160000, duration: 1200000));
        await tester.pump();
        final l10n = await english();
        expect(find.byType(NextEpisodeCountdown), findsNothing);

        await tester.tap(find.byTooltip(l10n.options));
        await settle(tester);
        Focus.of(tester.element(find.text(l10n.episodes))).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await settle(tester);
        expect(find.byType(PlayerPanel), findsOneWidget);
        expect(focusInPanel(), isTrue);
        final inPanel = FocusManager.instance.primaryFocus;

        // Now cross into the lead-in with the panel still up.
        await sendEvent(tester, snapshot(position: 1190000, duration: 1200000));
        await tester.pump();
        expect(find.byType(NextEpisodeCountdown), findsOneWidget);
        expect(find.byType(PlayerPanel), findsOneWidget);
        expect(
          focusInPanel(),
          isTrue,
          reason:
              'a card raised under a modal must not take the remote out '
              'of it: the viewer is looking at the panel',
        );
        expect(FocusManager.instance.primaryFocus, same(inPanel));

        // And the D-pad still walks the panel rather than a control hidden
        // under the barrier.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(focusInPanel(), isTrue);
        expect(
          FocusManager.instance.primaryFocus,
          isNot(same(inPanel)),
          reason: 'the panel is still navigable with the card up behind it',
        );

        // Closing the panel is what hands the remote to the waiting card.
        await sendBack(tester);
        await settle(tester);
        expect(find.byType(PlayerPanel), findsNothing);
        expect(find.byType(NextEpisodeCountdown), findsOneWidget);
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          kPlayNextFocusLabel,
          reason:
              'the card was waiting behind the panel and must take the '
              'remote the moment the panel is out of the way',
        );

        await tester.pumpWidget(const SizedBox());
      },
    );
  });

  group('the up-next card on a 960x540 television', () {
    testWidgets('spends the ten-foot budget and clears the bottom bar', (
      tester,
    ) async {
      await pumpToCredits(tester);

      final card = tester.getRect(
        find
            .descendant(
              of: find.byType(NextEpisodeCountdown),
              matching: find.byType(FocusTraversalGroup),
            )
            .first,
      );
      expect(
        card.width,
        300,
        reason:
            'a 1080p TV reports 960x540 dp, whose shortestSide is under '
            'the 600 phone threshold - the TV must not take the phone card. '
            '300 rather than the old 460 because the width is now derived '
            'from the longest action label, which is Kannada at 227.5 dp: '
            'see next_episode_countdown.dart, _kTvWidth',
      );

      final bar = tester.getRect(find.byType(PlayerBottomBar));
      expect(
        card.overlaps(bar),
        isFalse,
        reason:
            'the card sits clear of the scrubber and the action row '
            'rather than over them',
      );
      expect(
        card.bottom,
        lessThanOrEqualTo(540 - HotstarPlayerStyle.bottomChromeHeight),
      );

      // The description is the first thing the phone card drops.
      expect(find.textContaining('on the couch'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    }, variant: texturePlatform);

    /// The other end of the same band, and the reason the card's height is
    /// capped at all: it shares its columns with the running title.
    ///
    /// `PlayerTopBar` puts the title in an `Expanded` with `maxLines: 1` and
    /// an ellipsis, so a real series title fills to the overscan inset at
    /// x = 912 - which is the card's right edge. Measured before the fix: the
    /// card was Rect.fromLTRB(640, 47, 912, 396) against a title of
    /// (138, 34, 912, 65), so the still ate the lower 18 dp of the title of
    /// the thing that was playing.
    testWidgets('and clears the running title above it', (tester) async {
      await pumpToCredits(tester);

      final card = tester.getRect(
        find
            .descendant(
              of: find.byType(NextEpisodeCountdown),
              matching: find.byType(FocusTraversalGroup),
            )
            .first,
      );
      final topBar = tester.getRect(find.byType(PlayerTopBar));
      // The slot, not the glyphs: a short fixture title paints a narrow
      // paragraph, while the Expanded it sits in runs the full 138..912 that a
      // real title ellipsises into. Measuring the slot is what makes this an
      // overlap test rather than an accident of a short string.
      //
      // Found structurally rather than through the title's own text: the bar
      // composes that out of the series, the numbering and the episode's name
      // now, so there is no one string to anchor on.
      final titleSlot = tester.getRect(
        find
            .descendant(
              of: find.byType(PlayerTopBar),
              matching: find.byType(Expanded),
            )
            .first,
      );

      expect(
        card.right,
        lessThanOrEqualTo(titleSlot.right),
        reason:
            'the card ends at or inside the title it shares its columns with. '
            'Not on the same number any more: the card answers to the trailing '
            'line - the overscan inset plus the optical inset the track and '
            'the utility row share - while the top bar\'s right edge is just '
            'where the title ellipsises, with no glyph of its own to line up',
      );
      expect(
        card.overlaps(titleSlot),
        isFalse,
        reason: 'the card may not cover the title of what is playing',
      );
      expect(
        card.overlaps(
          tester.getRect(find.textContaining('Show').hitTestable().first),
        ),
        isFalse,
        reason: 'nor the glyphs that are actually painted today',
      );
      expect(
        card.overlaps(topBar),
        isFalse,
        reason:
            'and clears the whole band rather than threading the title, so '
            'it does not have to know whether there is a subtitle above it',
      );
      expect(
        card.top,
        greaterThanOrEqualTo(topBar.bottom),
        reason: 'measured: the bar is 0..92 and the card starts at 92',
      );
      expect(
        card,
        const Rect.fromLTRB(
          612 - HotstarPlayerStyle.trackEndInset,
          92,
          912 - HotstarPlayerStyle.trackEndInset,
          540 - HotstarPlayerStyle.tvBottomChromeHeight - 12,
        ),
        reason:
            'the whole ten-foot geometry in one line, through the real '
            'screen: 300 dp wide between a 92 dp top bar and the clearance '
            'the ten-foot chrome token sets. Written against the token rather '
            'than against the number it happened to produce, which is how '
            'this drifted 5 dp *into* the television bar the last time the '
            'token moved',
      );
      // The clearance is a constant the card holds unconditionally, not a
      // reaction to the bars being up - the card can be raised with the chrome
      // hidden, and one that resized when the viewer tapped would be worse
      // than one that overlapped. next_episode_countdown_test hosts this card
      // with no chrome in the tree at all and measures the same 92.

      await tester.pumpWidget(const SizedBox());
    }, variant: texturePlatform);
  });
}
