import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/core/services/download_service.dart';
import 'package:skystream/core/storage/history_repository.dart';
import 'package:skystream/features/player/presentation/vlc/ended_card.dart';
import 'package:skystream/features/player/presentation/vlc/next_episode_countdown.dart';
import 'package:skystream/features/player/presentation/vlc/panel/player_panel.dart'
    show PlayerPanel;
import 'package:skystream/features/player/presentation/vlc/resume_hint.dart';
import 'package:skystream/features/player/presentation/vlc/vlc_player_controls.dart';
import 'package:skystream/features/player/presentation/widgets/player_control_components.dart'
    show PlayerActionButton;
import 'package:skystream/features/player/presentation/vlc/vlc_player_screen.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';

import 'vlc_screen_harness.dart';

/// What the screen does when the media simply runs out.
///
/// The hole this closes fired on **every film** the app has ever played, and
/// on the last episode of every series: `_handleEnded` reached `_advance`,
/// `nextEpisodeFor` answered "nothing", and the method returned having changed
/// nothing on screen. The 3 s chrome clock had hidden the bars long before the
/// credits, so what a viewer was left with was a frozen last frame, no card,
/// no Replay, and - if they nudged the remote - a Play glyph whose press calls
/// `play()` on a player already at Ended.
///
/// Failures that merely *look* like an ending are deliberately not carded, and
/// two of the cases below say so: a dropped live feed and a truncated download
/// both land on the black opening overlay with a named reason, because telling
/// a viewer "you've finished" over a stream that broke is worse than silence.
void main() {
  setUp(installEngineMocks);
  tearDown(removeEngineMocks);

  Future<AppLocalizations> english() =>
      AppLocalizations.delegate.load(const Locale('en'));

  final film = MultimediaItem(
    title: 'The Matrix',
    url: 'https://example.com/matrix',
    posterUrl: '',
    provider: 'Remote',
  );

  final firstEpisode = Episode(
    name: 'Ep 01',
    url: 'https://example.com/e1.mp4',
    season: 1,
    episode: 1,
  );
  final lastEpisode = Episode(
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
    episodes: [firstEpisode, lastEpisode],
    provider: 'Remote',
  );

  /// A season list scraped without episode names, which is how plenty of
  /// plugins hand one back: the numbers are there and the names are not.
  final unnamed = Episode(
    name: '',
    url: 'https://example.com/u7.mp4',
    season: 2,
    episode: 7,
  );
  final unnamedNext = Episode(
    name: '',
    url: 'https://example.com/u8.mp4',
    season: 2,
    episode: 8,
  );
  final scraped = MultimediaItem(
    title: 'Long Series',
    url: 'https://example.com/long',
    posterUrl: '',
    contentType: MultimediaContentType.series,
    episodes: [unnamed, unnamedNext],
    provider: 'Remote',
  );

  /// The engine reports a real length and a position at the very end of it.
  ///
  /// Both halves matter. `_handleEnded` tells a finished film from a truncated
  /// download by the last good sample alone, and the sample is only written
  /// while the position is advancing - so a bare `ended` after `sendFirstFrame`
  /// would take the "ended before its duration" branch on the 1500 ms the
  /// first frame left behind.
  Future<void> playToTheEnd(WidgetTester tester) async {
    await sendEvent(tester, snapshot(position: 1199000, duration: 1200000));
    await sendEvent(tester, snapshot(state: 'ended'));
    await settle(tester);
  }

  /// Whether whatever holds focus is inside the panel, as
  /// screen_panel_test.dart and tv_overlay_focus_test.dart both ask it.
  bool focusInPanel() =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<PlayerPanel>() !=
      null;

  group('a film that runs out', () {
    testWidgets(
      'offers Start Over instead of a dead frame',
      variant: texturePlatform,
      (tester) async {
        await pumpPlayer(tester, item: film, videoUrl: film.url);
        await sendFirstFrame(tester);
        final l10n = await english();
        expect(find.byKey(endedCardKey), findsNothing);

        await playToTheEnd(tester);

        expect(find.byKey(endedCardKey), findsOneWidget);
        expect(find.text(l10n.playerFinished(film.title)), findsOneWidget);
        expect(find.text(l10n.startOver), findsOneWidget);
        expect(find.text(l10n.close), findsOneWidget);
        expect(
          find.byType(VlcPlayerControls),
          findsNothing,
          reason:
              'the controls are unmounted, not faded: their play button calls '
              'play() on a player at Ended, and its `autofocus: isTv` would be '
              'a second autofocus in the same route as the card\'s',
        );
        expect(
          find.byKey(openingOverlayKey),
          findsNothing,
          reason: 'nothing is opening; this is the end of the film',
        );
        expect(
          find.byType(VlcPlayerScreen),
          findsOneWidget,
          reason: 'the route is never popped on a timer',
        );

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'Start Over reopens it from the top',
      variant: texturePlatform,
      (tester) async {
        await pumpPlayer(tester, item: film, videoUrl: film.url);
        await sendFirstFrame(tester);
        final l10n = await english();
        await playToTheEnd(tester);
        expect(find.byKey(endedCardKey), findsOneWidget);

        await tester.tap(find.text(l10n.startOver));
        await tester.pump();

        expect(
          find.byKey(endedCardKey),
          findsNothing,
          reason: 'the card comes down in the same frame it is pressed in',
        );
        expect(
          find.byKey(openingOverlayKey),
          findsOneWidget,
          reason:
              'the finished picture comes down before the first await, or the '
              'whole re-resolve is spent on a frame the viewer has dismissed',
        );

        await settle(tester);
        expect(
          find.textContaining(l10n.sourceAttempt(1, 1)),
          findsOneWidget,
          reason: 'a fresh source attempt, not a play() on a player at Ended',
        );

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('Close leaves the player', variant: texturePlatform, (
      tester,
    ) async {
      await pumpPlayer(tester, item: film, videoUrl: film.url, pushed: true);
      await sendFirstFrame(tester);
      final l10n = await english();
      await playToTheEnd(tester);

      await tester.tap(find.text(l10n.close));
      await tester.pumpAndSettle();

      expect(find.byType(VlcPlayerScreen), findsNothing);
    });

    testWidgets(
      'Back over the card leaves, rather than putting bars away that are '
      'not there',
      variant: texturePlatform,
      (tester) async {
        await pumpPlayer(tester, item: film, videoUrl: film.url, pushed: true);
        await sendFirstFrame(tester);
        await playToTheEnd(tester);
        expect(find.byKey(endedCardKey), findsOneWidget);

        await sendBack(tester);
        await tester.pumpAndSettle();

        expect(
          find.byType(VlcPlayerScreen),
          findsNothing,
          reason:
              'the hide-chrome-first rule claims a paused press since the '
              'pause exception was removed, and `ended` is paused-looking. '
              'With the controls unmounted there is nothing to hide, so the '
              'press has to reach the pop',
        );
      },
    );

    testWidgets(
      'ending under an open panel leaves the remote in the panel, and takes '
      'it when the panel closes',
      variant: texturePlatform,
      (tester) async {
        await pumpPlayer(tester, item: film, videoUrl: film.url);
        await sendFirstFrame(tester);
        final l10n = await english();

        await tester.tap(find.byTooltip(l10n.options));
        await settle(tester);
        expect(find.byType(PlayerPanel), findsOneWidget);
        expect(focusInPanel(), isTrue);
        final inPanel = FocusManager.instance.primaryFocus;

        // The credits run out while the viewer is still reading the panel,
        // which on a television is exactly when a panel is most likely to be
        // up: the end of the media is the moment nobody is watching the
        // picture.
        await playToTheEnd(tester);

        expect(find.byKey(endedCardKey), findsOneWidget);
        expect(find.byType(PlayerPanel), findsOneWidget, reason: 'still up');
        expect(
          focusInPanel(),
          isTrue,
          reason:
              'the card mounts in the player route, underneath a PopupRoute '
              'that is still the current one. Taking the remote there puts it '
              'on a button the panel covers, and the next OK - aimed at a '
              'panel row - reopens the film from zero or leaves the player',
        );
        expect(FocusManager.instance.primaryFocus, same(inPanel));

        // Closing the panel is what hands the remote to the waiting card.
        await sendBack(tester);
        await settle(tester);

        expect(find.byType(PlayerPanel), findsNothing);
        expect(find.byKey(endedCardKey), findsOneWidget);
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          kEndedStartOverFocusLabel,
          reason:
              'the card was waiting behind the panel with nothing else on '
              'screen to focus, and must take the remote the moment the panel '
              'is out of the way',
        );

        await tester.pumpWidget(const SizedBox());
      },
    );
  });

  testWidgets(
    'a source that dies after the card is up does not bring it back',
    variant: texturePlatform,
    (tester) async {
      await pumpPlayer(tester, item: film, videoUrl: film.url);
      await sendFirstFrame(tester);
      await playToTheEnd(tester);
      expect(find.byKey(endedCardKey), findsOneWidget);

      // A straggler from the finished session - the engine reporting an error
      // after end of media - reaches the failover ladder, which reopens the
      // source that did produce frames. The card belongs to media that is no
      // longer the current attempt.
      await sendEvent(tester, snapshot(state: 'error'));
      await settle(tester);
      expect(find.byKey(endedCardKey), findsNothing);

      await sendFirstFrame(tester);

      expect(
        find.byKey(endedCardKey),
        findsNothing,
        reason:
            'every way back into playback goes through _openAttempt, and the '
            'card cleared there is why a reopened source does not come up '
            'under a card saying it has finished',
      );
      expect(find.byType(VlcPlayerControls), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    },
  );

  group('a series', () {
    /// The show playing [episode], with the disk lookup that opens every
    /// advance held shut so a test can see whether one was even started.
    ///
    /// Hands back a getter: the service is built the first time the advance
    /// reads it, so null means no advance ever ran.
    Future<GatedDownloads? Function()> pumpShow(
      WidgetTester tester,
      Episode episode,
    ) async {
      GatedDownloads? downloads;
      await pumpPlayer(
        tester,
        item: show,
        episode: episode,
        videoUrl: episode.url,
        overrides: [
          downloadServiceProvider.overrideWith(
            (ref) => downloads = GatedDownloads(ref),
          ),
        ],
      );
      await sendFirstFrame(tester);
      return () => downloads;
    }

    testWidgets('ends its last episode on the card', variant: texturePlatform, (
      tester,
    ) async {
      final downloads = await pumpShow(tester, lastEpisode);
      final l10n = await english();

      await playToTheEnd(tester);

      expect(find.byKey(endedCardKey), findsOneWidget);
      expect(
        find.text(l10n.playerFinished(show.title)),
        findsOneWidget,
        reason: 'a finale is the series finishing, so the series is named',
      );
      expect(find.byType(VlcPlayerControls), findsNothing);
      expect(downloads(), isNull, reason: 'there was nothing to advance to');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      'does not card a mid-series episode; it advances',
      variant: texturePlatform,
      (tester) async {
        final downloads = await pumpShow(tester, firstEpisode);
        final l10n = await english();

        await playToTheEnd(tester);

        expect(
          find.byKey(endedCardKey),
          findsNothing,
          reason:
              'the advance is running - a card here would sit over an episode '
              'that is loading, and _advance reporting `playing` for a '
              'transition already in flight is what prevents it',
        );
        expect(
          find.byKey(openingOverlayKey),
          findsOneWidget,
          reason: 'the next episode is resolving behind the overlay',
        );

        downloads()!.gate.complete();
        await settle(tester);
        expect(find.textContaining(l10n.sourceAttempt(1, 1)), findsOneWidget);
        expect(find.byKey(endedCardKey), findsNothing);

        await tester.pumpWidget(const SizedBox());
      },
    );
  });

  group('a declined next episode', () {
    /// Drives the first of two episodes to ten seconds from its end, which is
    /// inside the screen's 15 s lead-in and is what raises the up-next card,
    /// then presses Cancel on it.
    Future<GatedDownloads? Function()> declineTheAdvance(
      WidgetTester tester,
    ) async {
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

      final l10n = await english();
      expect(find.byType(NextEpisodeCountdown), findsOneWidget);
      await tester.tap(find.text(l10n.cancel));
      await tester.pump();
      expect(find.byType(NextEpisodeCountdown), findsNothing);
      return () => downloads;
    }

    testWidgets(
      'is not taken anyway when the credits run out',
      variant: texturePlatform,
      (tester) async {
        final downloads = await declineTheAdvance(tester);
        final l10n = await english();

        await playToTheEnd(tester);

        expect(
          downloads(),
          isNull,
          reason:
              'owner decision 2. Cancel used to buy fifteen seconds and '
              'nothing else: the episode ended and the advance took it '
              'anyway, which is the one outcome the button exists to prevent',
        );
        expect(find.byKey(endedCardKey), findsOneWidget);
        expect(
          find.text(l10n.playEpisode(l10n.next, 1, 2)),
          findsOneWidget,
          reason: 'a refusal is honoured, not punished: the binge is one press',
        );
        expect(
          find.text(l10n.playerFinished(firstEpisode.name)),
          findsOneWidget,
          reason:
              'the episode finished, not the series - "you have finished '
              'Show" after episode one would be a lie',
        );
        expect(find.byType(VlcPlayerControls), findsNothing);

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'is started by Next on the card, refusal and all',
      variant: texturePlatform,
      (tester) async {
        final downloads = await declineTheAdvance(tester);
        final l10n = await english();
        await playToTheEnd(tester);

        await tester.tap(find.text(l10n.playEpisode(l10n.next, 1, 2)));
        await tester.pump();

        expect(
          downloads(),
          isNotNull,
          reason:
              'pressing Next is the viewer changing their mind; the stale '
              'refusal must not veto it',
        );
        expect(find.byKey(endedCardKey), findsNothing);
        expect(find.byKey(openingOverlayKey), findsOneWidget);

        downloads()!.gate.complete();
        await settle(tester);
        expect(find.textContaining(l10n.sourceAttempt(1, 1)), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'names an unnamed episode by its number, never by the series',
      variant: texturePlatform,
      (tester) async {
        // The card says "You've finished <title>". With no episode name to
        // print, that title used to fall back to the series - so declining
        // the advance on episode seven of sixty claimed the whole series was
        // over. The numbers are always there when the name is not.
        GatedDownloads? downloads;
        await pumpPlayer(
          tester,
          item: scraped,
          episode: unnamed,
          videoUrl: unnamed.url,
          overrides: [
            downloadServiceProvider.overrideWith(
              (ref) => downloads = GatedDownloads(ref),
            ),
          ],
        );
        await sendFirstFrame(tester);
        final l10n = await english();

        await sendEvent(tester, snapshot(position: 1190000, duration: 1200000));
        await tester.pump();
        await tester.tap(find.text(l10n.cancel));
        await tester.pump();

        await playToTheEnd(tester);

        expect(find.byKey(endedCardKey), findsOneWidget);
        expect(downloads, isNull, reason: 'the refusal held');
        expect(
          find.text(l10n.playerFinished(l10n.playerSeasonEpisode(2, 7))),
          findsOneWidget,
          reason:
              'S2 E7 is what the episode panel calls this entry, and it is '
              'the truth: that episode finished',
        );
        expect(
          find.text(l10n.playerFinished(scraped.title)),
          findsNothing,
          reason:
              '"you have finished Long Series" after episode seven of sixty '
              'is the exact lie the named-episode branch exists to prevent',
        );

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'Start Over does not carry the refusal into the re-watch',
      variant: texturePlatform,
      (tester) async {
        // The refusal was made about the previous viewing. Left set, the
        // whole re-watch runs with the auto-advance silently off - no up-next
        // card in the last fifteen seconds - and ends on this same card
        // again, which is not what Start Over offers.
        await declineTheAdvance(tester);
        final l10n = await english();
        await playToTheEnd(tester);
        expect(find.byKey(endedCardKey), findsOneWidget);

        await tester.tap(find.text(l10n.startOver));
        await settle(tester);
        expect(find.textContaining(l10n.sourceAttempt(1, 1)), findsOneWidget);

        // The re-watch reaches its own last fifteen seconds.
        await sendFirstFrame(tester);
        await sendEvent(tester, snapshot(position: 1190000, duration: 1200000));
        await tester.pump();

        expect(
          find.byType(NextEpisodeCountdown),
          findsOneWidget,
          reason:
              'a fresh session, so the auto-advance is on: the refusal '
              'belonged to the run that ended on the card',
        );

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'never has both cards on screen at once',
      variant: texturePlatform,
      (tester) async {
        await declineTheAdvance(tester);
        await playToTheEnd(tester);

        expect(find.byKey(endedCardKey), findsOneWidget);
        expect(
          find.byType(NextEpisodeCountdown),
          findsNothing,
          reason:
              'the two are structurally exclusive - the up-next card lives '
              'inside the controls branch the ended card unmounts - and this '
              'is the one path that could reach both',
        );

        await tester.pumpWidget(const SizedBox());
      },
    );
  });

  /// The screen owns two overlays that sit outside the controls: the up-next
  /// card and the resume hint. Both are live tap targets, and the lock has to
  /// take them with the rest of the chrome - the controls already withhold the
  /// three they own the same way.
  group('a locked screen', () {
    /// Locks through the padlock, the way a viewer does - the same helper
    /// screen_back_test.dart uses, for the same reason: the gesture absorber's
    /// double-tap recogniser holds the arena open, so the press lands ~300 ms
    /// after the finger leaves.
    Future<void> lock(WidgetTester tester) async {
      final l10n = await english();
      expect(
        find.byTooltip(l10n.lock),
        findsOneWidget,
        reason: 'the padlock is phone and tablet only, and this is a phone',
      );
      await tester.tap(find.byTooltip(l10n.lock));
      await settle(tester);
    }

    Future<void> unlock(WidgetTester tester) async {
      final l10n = await english();
      await tester.tap(find.widgetWithText(PlayerActionButton, l10n.unlock));
      await settle(tester);
    }

    testWidgets(
      'keeps the up-next card off, and gives it back on unlock',
      variant: texturePlatform,
      (tester) async {
        // The worst fifteen seconds the lock has: a 300 dp card with two live
        // buttons, bottom-right, at the end of every episode of every binge.
        // A pocket press on Play now jumps the episode and loses the
        // position; one on Cancel ends the episode outright and takes the
        // lock off with it.
        GatedDownloads? downloads;
        await pumpPlayer(
          tester,
          item: show,
          episode: firstEpisode,
          videoUrl: firstEpisode.url,
          isTv: false,
          overrides: [
            downloadServiceProvider.overrideWith(
              (ref) => downloads = GatedDownloads(ref),
            ),
          ],
        );
        await sendFirstFrame(tester);
        final l10n = await english();
        await lock(tester);

        // Inside the fifteen-second lead-in, so the offer is made.
        await sendEvent(tester, snapshot(position: 1190000, duration: 1200000));
        await tester.pump();

        expect(
          find.byType(NextEpisodeCountdown),
          findsNothing,
          reason:
              'withheld, not merely ignored - the rule the controls follow '
              'for the three targets they own. A drawn button that does '
              'nothing reads as a broken player',
        );
        expect(find.text(l10n.playNow), findsNothing);
        expect(find.text(l10n.cancel), findsNothing);
        expect(
          downloads,
          isNull,
          reason: 'and nothing behind it decided an advance either',
        );

        await unlock(tester);

        expect(
          find.byType(NextEpisodeCountdown),
          findsOneWidget,
          reason:
              'the offer stands; it is the surface that was withheld, and it '
              'comes back off the same notifier the chip writes',
        );

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'keeps the resume hint off, and gives it back on unlock',
      variant: texturePlatform,
      (tester) async {
        // The other screen-level overlay, and its Start Over button throws
        // away the position the viewer resumed at.
        await pumpPlayer(
          tester,
          isTv: false,
          overrides: [
            historyRepositoryProvider.overrideWithValue(_ResumeAtHalfway()),
          ],
        );
        await sendFirstFrame(tester);
        expect(
          find.byType(ResumeHint),
          findsOneWidget,
          reason: 'ten minutes into a twenty-minute film were on disk',
        );

        await lock(tester);
        expect(find.byType(ResumeHint), findsNothing);

        await unlock(tester);
        expect(find.byType(ResumeHint), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
      },
    );
  });

  group('an ending that is really a failure', () {
    testWidgets(
      'a stream that stops short of its duration is not carded',
      variant: texturePlatform,
      (tester) async {
        await pumpPlayer(tester, item: film, videoUrl: film.url);
        await sendFirstFrame(tester);
        final l10n = await english();

        // Half a two-hour film, then end of media: a truncated download, not
        // an ending.
        await sendEvent(tester, snapshot(position: 600000, duration: 1200000));
        await sendEvent(tester, snapshot(state: 'ended'));
        await settle(tester);

        expect(
          find.byKey(endedCardKey),
          findsNothing,
          reason:
              '"You have finished" over a download that stopped halfway is a '
              'lie the viewer would act on',
        );
        expect(find.byKey(openingOverlayKey), findsOneWidget);
        expect(
          find.textContaining(l10n.playerReasonStreamEndedEarly),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'a source whose duration was never reported is not carded either',
      variant: texturePlatform,
      (tester) async {
        await pumpPlayer(tester, item: film, videoUrl: film.url);
        await sendFirstFrame(tester);
        final l10n = await english();

        // Ten minutes of a container libVLC never learned the length of - an
        // HLS manifest with no EXT-X-ENDLIST on a non-live item, an unindexed
        // MKV over HTTP, a torrent whose header never completed - and then
        // the socket drops. Every snapshot carries `duration: 0`, so no
        // progress sample is ever written: this is the case where the screen
        // cannot tell an ending from a truncation, and "cannot tell" is a
        // failure.
        await sendEvent(tester, snapshot(position: 300000, duration: 0));
        await sendEvent(tester, snapshot(position: 600000, duration: 0));
        await sendEvent(tester, snapshot(state: 'ended'));
        await settle(tester);

        expect(
          find.byKey(endedCardKey),
          findsNothing,
          reason:
              'a missing sample is not evidence of an ending. Carded, this '
              'tells a viewer whose stream dropped ten minutes in that the '
              'film finished',
        );
        expect(find.text(l10n.playerFinished(film.title)), findsNothing);
        expect(
          find.byKey(openingOverlayKey),
          findsOneWidget,
          reason: 'the failover ladder is trying the source again instead',
        );
        expect(
          find.textContaining(l10n.playerReasonStreamEndedEarly),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'a source that ends before it ever played is not carded',
      variant: texturePlatform,
      (tester) async {
        await pumpPlayer(tester, item: film, videoUrl: film.url);
        final l10n = await english();

        // No first frame at all, then end of media: a dead candidate, not a
        // watched film. Carding it would also skip an episode nobody saw.
        await sendEvent(tester, snapshot(state: 'ended'));
        await settle(tester);

        expect(find.byKey(endedCardKey), findsNothing);
        expect(
          find.text(
            l10n.playerNoSourcesPlayableWithReason(
              1,
              l10n.playerReasonStreamEndedBeforePlaying,
            ),
          ),
          findsOneWidget,
          reason:
              'it is the one direct source there is, so the failover ladder '
              'runs out and the screen says why, under Retry',
        );
        expect(find.text(l10n.retry), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
      },
    );
  });
}

/// Ten minutes into a twenty-minute film, on disk, so the screen resolves a
/// resume point and raises the hint on the first frame. [NoHistory] answers
/// zero to both, which is why no other screen test has ever seen the hint.
class _ResumeAtHalfway extends NoHistory {
  @override
  int getPosition(String url) => 600000;

  @override
  int getDuration(String url) => 1200000;
}
