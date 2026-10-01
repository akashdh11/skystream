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
import 'package:skystream/features/player/presentation/widgets/player_control_components.dart'
    show PlayerActionButton, PlayerBottomBar;
import 'package:skystream/l10n/generated/app_localizations.dart';

import 'vlc_screen_harness.dart';

/// What Back means on a television.
///
/// The bars up and the video playing, Back means "put the bars away": that is
/// the convention every TV player follows, the old player kept it
/// (38da335:player_screen.dart:587-597), and a viewer who has learned it
/// presses Back to clear the picture and expects the picture to still be
/// there. Only Back over bare video leaves.
///
/// Pausing makes no difference. A viewer who paused to read the seek bar is
/// still watching, and the pause exception this file used to pin - Back over
/// a paused picture leaving at once - meant the most ordinary press on a
/// television threw the session away. It is gone: the rule has one clause.
///
/// Some televisions deliver one press twice, as a key event and as a
/// `popRoute` in the same frame. The second delivery must not be the second
/// press.
void main() {
  setUp(installEngineMocks);
  tearDown(removeEngineMocks);

  /// Tells the screen the activity has entered or left picture-in-picture,
  /// over the same channel `MainActivity.onPictureInPictureModeChanged` uses.
  /// The screen registers the handler itself, in initState.
  Future<void> setPipMode(WidgetTester tester, bool inPip) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      pipChannel.name,
      pipChannel.codec.encodeMethodCall(MethodCall('pipModeChanged', inPip)),
      (_) {},
    );
    await tester.pump();
  }

  /// Read off the fades' targets, so it does not wait on the animation.
  Iterable<AnimatedOpacity> fades(WidgetTester tester) =>
      tester.widgetList<AnimatedOpacity>(
        find.descendant(
          of: find.byType(VlcPlayerControls),
          matching: find.byType(AnimatedOpacity),
        ),
      );

  void expectBarsShown(WidgetTester tester) {
    final targets = fades(tester);
    expect(targets, isNotEmpty);
    expect(targets.map((f) => f.opacity), everyElement(1.0));
  }

  void expectBarsHidden(WidgetTester tester, {required String reason}) {
    final targets = fades(tester);
    expect(targets, isNotEmpty);
    expect(targets.map((f) => f.opacity), everyElement(0.0), reason: reason);
  }

  group('Back on a television', () {
    testWidgets(
      'starts hidden until controller A summons the controls',
      variant: texturePlatform,
      (tester) async {
        await pumpPlayer(tester, pushed: true);
        await sendFirstFrame(tester);
        expectBarsHidden(tester, reason: 'playback starts without controls');
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          'player-key-sink',
        );

        await tester.sendKeyEvent(
          LogicalKeyboardKey.gameButtonA,
          platform: 'android',
          physicalKey: PhysicalKeyboardKey.gameButtonA,
        );
        await tester.pump();
        expectBarsShown(tester);
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          'player-play-pause',
        );

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'with the bars down, a Back key then popRoute leaves the player',
      variant: texturePlatform,
      (tester) async {
        // The sequence a real remote produces. The harness's sendBack only
        // ever sent the popRoute half, which is why the key half raising the
        // bars - and the pop then being swallowed as "hide the bars" - went
        // unseen.
        await pumpPlayer(tester, pushed: true);
        await sendFirstFrame(tester, showControls: true);
        await tester.pump(const Duration(seconds: 4));
        expectBarsHidden(tester, reason: 'the hide timer has run out');

        await tester.sendKeyEvent(
          LogicalKeyboardKey.goBack,
          // flutter_test has no physical key on file for Go Back, and no
          // Windows key code for it either; Android's table has both. The
          // controls only ever read the logical key.
          platform: 'android',
          physicalKey: PhysicalKeyboardKey.escape,
        );
        await tester.pump();
        expectBarsHidden(
          tester,
          reason: 'the key half of Back must not raise the bars',
        );

        await sendBack(tester);
        await tester.pump(const Duration(seconds: 1));
        expect(
          find.byType(VlcPlayerScreen),
          findsNothing,
          reason: 'bars were down, so Back means leave',
        );
      },
    );

    testWidgets(
      'with the bars up puts them away instead of leaving',
      variant: texturePlatform,
      (tester) async {
        await pumpPlayer(tester, pushed: true);
        await sendFirstFrame(tester, showControls: true);
        expectBarsShown(tester);

        await sendBack(tester);

        expect(
          find.byType(VlcPlayerScreen),
          findsOneWidget,
          reason: 'the viewer meant to clear the bars, not lose playback',
        );
        expectBarsHidden(tester, reason: 'the press was spent on the bars');

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'a second press over bare video leaves',
      variant: texturePlatform,
      (tester) async {
        await pumpPlayer(tester, pushed: true);
        await sendFirstFrame(tester, showControls: true);

        await sendBack(tester);
        // Past the window in which a second delivery is taken for an echo.
        await tester.pump(const Duration(milliseconds: 400));
        await sendBack(tester);
        // The pop transition.
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(VlcPlayerScreen), findsNothing);
      },
    );

    testWidgets(
      'one press delivered twice is still one press',
      variant: texturePlatform,
      (tester) async {
        await pumpPlayer(tester, pushed: true);
        await sendFirstFrame(tester, showControls: true);

        await sendBack(tester);
        await sendBack(tester);
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.byType(VlcPlayerScreen),
          findsOneWidget,
          reason: 'a key event and a popRoute for one press must not pop',
        );
        expectBarsHidden(tester, reason: 'the first delivery did its work');

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'over a paused picture the first Back hides the bars, the second leaves',
      variant: texturePlatform,
      (tester) async {
        // Pausing to study the seek bar is what a viewer does immediately
        // before pressing Back, so a pause exception here would spend that
        // press on the whole session. The chrome controller obliges: its
        // clock will not auto-hide over a still picture, but toggle() - the
        // viewer asking - hides while paused all the same.
        await pumpPlayer(tester, pushed: true);
        await sendFirstFrame(tester, showControls: true);
        await sendEvent(tester, snapshot(state: 'paused'));
        expectBarsShown(tester);

        await sendBack(tester);
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.byType(VlcPlayerScreen),
          findsOneWidget,
          reason:
              'a paused viewer is still watching; the bars go, not the '
              'session',
        );
        expectBarsHidden(
          tester,
          reason: 'the press was spent on the bars, paused or not',
        );

        await sendBack(tester);
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.byType(VlcPlayerScreen),
          findsNothing,
          reason: 'the bars are down now, so the next press means leave',
        );
      },
    );

    testWidgets(
      'one press delivered twice over a paused picture is still one press',
      variant: texturePlatform,
      (tester) async {
        // The echo swallow shares the paused path, so it has to be proved on
        // it: before this rule changed, the second delivery could not reach
        // the pop because the first never claimed the press.
        await pumpPlayer(tester, pushed: true);
        await sendFirstFrame(tester, showControls: true);
        await sendEvent(tester, snapshot(state: 'paused'));
        expectBarsShown(tester);

        await sendBack(tester);
        await sendBack(tester);
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.byType(VlcPlayerScreen),
          findsOneWidget,
          reason: 'a key event and a popRoute for one press must not pop',
        );
        expectBarsHidden(tester, reason: 'the first delivery did its work');

        await tester.pumpWidget(const SizedBox());
      },
    );
  });

  group('Back over the panel on a television', () {
    /// Opens the panel from the bottom bar's Options button, the way a
    /// remote does, and waits out the slide-in.
    Future<void> openPanel(WidgetTester tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.byTooltip(l10n.options));
      await settle(tester);
      expect(find.byType(PlayerPanel), findsOneWidget);
    }

    testWidgets(
      'Options opens the panel; Back closes the panel and not the player',
      variant: texturePlatform,
      (tester) async {
        // The panel is a route on top of the player, so the Navigator pops
        // it and the player is never consulted: one press, one thing closed.
        await pumpPlayer(tester, pushed: true);
        await sendFirstFrame(tester, showControls: true);
        await openPanel(tester);

        await sendBack(tester);
        await settle(tester);

        expect(find.byType(PlayerPanel), findsNothing);
        expect(
          find.byType(VlcPlayerScreen),
          findsOneWidget,
          reason: 'the press was spent on the panel',
        );
        expectBarsShown(tester);

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      "a second Back during the panel's exit transition hides the bars",
      variant: texturePlatform,
      (tester) async {
        // Mid-slide the panel's element is still mounted but its route is no
        // longer current, its hold on the chrome has been released and the
        // screen has forgotten its context. So the second press reaches the
        // player, finds the bars up and puts them away - it does not pop the
        // player out from under the closing panel.
        await pumpPlayer(tester, pushed: true);
        await sendFirstFrame(tester, showControls: true);
        await openPanel(tester);

        await sendBack(tester);
        await sendBack(tester);
        await settle(tester);

        expect(find.byType(PlayerPanel), findsNothing);
        expect(
          find.byType(VlcPlayerScreen),
          findsOneWidget,
          reason: 'the second press must not leave playback',
        );
        expectBarsHidden(tester, reason: 'the second press hid the bars');

        await tester.pumpWidget(const SizedBox());
      },
    );
  });

  /// Back on a locked screen, which is the half of the lock that lives here
  /// rather than in the controls.
  ///
  /// The flag is the *screen's* for exactly this reason. 38da335's lock kept
  /// its `_isLocked` in a widget State that the screen's Back handling could
  /// not see, so an edge swipe left the player while locked - on an Android
  /// phone, the one device the lock existed for. And the answer is two
  /// presses rather than a permanent swallow, because on Android the Back
  /// gesture is *the* way out of a screen: a player that ignored it forever
  /// would read as hung, with the only escape a chip the viewer has already
  /// failed to find.
  group('Back on a locked phone', () {
    /// Locks through the padlock, the way a viewer does.
    ///
    /// `settle` rather than one pump: the bars are wrapped in the controls'
    /// gesture absorber, whose double-tap recogniser holds the arena open for
    /// its timeout, so a button press lands ~300 ms after the finger leaves.
    Future<void> lock(WidgetTester tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        find.byTooltip(l10n.lock),
        findsOneWidget,
        reason: 'the padlock is phone and tablet only, and this is a phone',
      );
      await tester.tap(find.byTooltip(l10n.lock));
      await settle(tester);
      expect(find.byType(PlayerBottomBar), findsNothing);
    }

    Future<Finder> chip() async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      return find.widgetWithText(PlayerActionButton, l10n.unlock);
    }

    testWidgets(
      'the first Back reveals the chip and does not pop; the second leaves',
      variant: texturePlatform,
      (tester) async {
        await pumpPlayer(tester, pushed: true, isTv: false);
        await sendFirstFrame(tester, showControls: true);
        await lock(tester);

        // Long enough for the chrome's own three-second clock to have taken
        // the chip away, so the poke below is doing real work rather than
        // looking at a chip that never left.
        await tester.pump(const Duration(seconds: 4));
        expect(
          tester.widget<AnimatedOpacity>(
            find.ancestor(
              of: await chip(),
              matching: find.byType(AnimatedOpacity),
            ),
          ).opacity,
          0.0,
          reason: 'the chip rides the same clock the bars do',
        );

        await sendBack(tester);
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          find.byType(VlcPlayerScreen),
          findsOneWidget,
          reason: 'a locked player does not leave on one press',
        );
        expect(
          tester.widget<AnimatedOpacity>(
            find.ancestor(
              of: await chip(),
              matching: find.byType(AnimatedOpacity),
            ),
          ).opacity,
          1.0,
          reason:
              'poke(), not keepAlive(): the press has to summon the chip, not '
              'merely keep an already-visible one alive',
        );

        // Inside the two-second window and past the 300 ms same-press echo.
        await sendBack(tester);
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.byType(VlcPlayerScreen),
          findsNothing,
          reason: 'a deliberate second press unlocks and leaves',
        );
      },
    );

    testWidgets(
      'one press delivered twice is still the first press',
      variant: texturePlatform,
      (tester) async {
        // The escape window is two seconds and some devices deliver one press
        // as a key event and a popRoute in the same frame. Without the
        // 300 ms echo guard the second delivery would read as the deliberate
        // second press and take the viewer straight out of a screen they had
        // just locked.
        await pumpPlayer(tester, pushed: true, isTv: false);
        await sendFirstFrame(tester, showControls: true);
        await lock(tester);

        await sendBack(tester);
        await sendBack(tester);
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.byType(VlcPlayerScreen),
          findsOneWidget,
          reason: 'the echo is the same press, not a confirmation',
        );
        expect(await chip(), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'unlocking with the chip ends the sequence the next lock would inherit',
      variant: texturePlatform,
      (tester) async {
        // The lock has two ways off - the screen's own paths, and the chip,
        // which writes the shared notifier itself - and the two-second escape
        // window has to close on both of them. Left armed by a chip unlock,
        // the first Back after a re-lock inside that window reads as the
        // second press of a sequence the viewer never started and pops the
        // player, instead of merely showing the chip again. That is the one
        // thing the lock promises cannot happen, so it is checked on the path
        // that used to skip the reset rather than only on the one that did it.
        await pumpPlayer(tester, pushed: true, isTv: false);
        await sendFirstFrame(tester, showControls: true);
        await lock(tester);

        // Locked and left alone, which is the state a real one is found in:
        // past the chrome's three seconds, so the press below is the one that
        // summons the chip rather than one that lands on an open bar.
        await tester.pump(const Duration(seconds: 4));

        // Spent on revealing the chip, and it arms the escape.
        await sendBack(tester);
        expect(
          find.byType(VlcPlayerScreen),
          findsOneWidget,
          reason: 'the first press never leaves',
        );

        // Off with the chip rather than with a second Back. Same destination,
        // different writer, and it is the writer that used to leave the timer
        // behind.
        await tester.tap(await chip());
        await settle(tester);
        expect(
          await chip(),
          findsNothing,
          reason:
              'the chip really did unlock, so the rest of this is about '
              'what it left behind',
        );

        // And straight back on, well inside the two seconds the Back above
        // opened. A viewer who unlocks to skim the seek bar and locks again is
        // doing exactly this.
        await lock(tester);

        await sendBack(tester);
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.byType(VlcPlayerScreen),
          findsOneWidget,
          reason:
              'the chip unlock closed the window, so this is a first '
              'press again and a first press never leaves',
        );
        expect(
          await chip(),
          findsOneWidget,
          reason: 'and what a first press does instead is show the chip',
        );

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'and Back works again the instant the chip is used',
      variant: texturePlatform,
      (tester) async {
        // The other timer the unlock has to take with it, and the smaller
        // half of the same hole. The Back that revealed the chip also armed
        // the 300 ms same-press echo; left running past an unlock it swallows
        // a real press on a player that is no longer locked, so a viewer who
        // unlocks and immediately changes their mind gets a dead gesture.
        // Nothing is pumped between the unlock and the press, which is what
        // puts it inside that window.
        await pumpPlayer(tester, pushed: true, isTv: false);
        await sendFirstFrame(tester, showControls: true);
        await lock(tester);
        await tester.pump(const Duration(seconds: 4));

        await sendBack(tester);
        await tester.tap(await chip());
        await tester.pump();
        expect(await chip(), findsNothing, reason: 'unlocked');

        await sendBack(tester);
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.byType(VlcPlayerScreen),
          findsNothing,
          reason:
              'an unlocked phone leaves on one press, and the echo of a '
              'press spent on a lock that is gone must not eat it',
        );
      },
    );

    testWidgets(
      'a lone press does not arm an escape that outlives it',
      variant: texturePlatform,
      (tester) async {
        // The lock is a lock, not a two-press countdown left running. A press
        // now and another one a minute later are two first presses.
        await pumpPlayer(tester, pushed: true, isTv: false);
        await sendFirstFrame(tester, showControls: true);
        await lock(tester);

        await sendBack(tester);
        await tester.pump(const Duration(seconds: 3));
        await sendBack(tester);
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.byType(VlcPlayerScreen),
          findsOneWidget,
          reason: 'the window had closed, so this was a first press again',
        );
        expect(await chip(), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'the lock clears on an episode advance',
      variant: texturePlatform,
      (tester) async {
        // The lock belongs to the picture that was on screen when it was set.
        // Every path that takes that picture away goes through
        // `_setSawFrames(false)` - a failover, a live reconnect, Start Over
        // and, as here, an advance - so that is the one place that clears it.
        // Left standing, a lock set on the last episode would greet the next
        // one with a chip over media nobody locked, set by a padlock inside
        // controls that have just been unmounted.
        //
        // Driven by the up-next countdown running out rather than by pressing
        // anything, so the assertion is about the advance itself and not about
        // which controls happen to be reachable while locked.
        final first = Episode(
          name: 'Ep 01',
          url: 'https://example.com/e1.mp4',
          season: 1,
          episode: 1,
        );
        final show = MultimediaItem(
          title: 'Show',
          url: 'https://example.com/show',
          posterUrl: '',
          contentType: MultimediaContentType.series,
          episodes: [
            first,
            Episode(
              name: 'Ep 02',
              url: 'https://example.com/e2.mp4',
              season: 1,
              episode: 2,
            ),
          ],
          provider: 'Remote',
        );
        await pumpPlayer(
          tester,
          item: show,
          episode: first,
          videoUrl: first.url,
          pushed: true,
          isTv: false,
          overrides: [
            // Held shut, so the advance parks on the disk lookup - which is
            // the first await *after* the flag this test is about is cleared.
            downloadServiceProvider.overrideWith(GatedDownloads.new),
          ],
        );
        await sendFirstFrame(tester, showControls: true);
        await lock(tester);

        // Inside the fifteen-second lead-in, where the up-next card would be
        // - and is not, because the lock withholds it along with every other
        // tap target on the screen. That is the subject of 'a locked screen
        // keeps the up-next card and the resume hint off' in
        // screen_ended_test.dart; here it is only the reason this test can no
        // longer drive the advance from the countdown.
        await sendEvent(tester, snapshot(position: 100000, duration: 120000));
        await sendEvent(tester, snapshot(position: 110000, duration: 120000));
        expect(find.byType(NextEpisodeCountdown), findsNothing);

        // So the episode is played out instead and the advance happens on end
        // of media, still with nothing pressed. The near-end position is what
        // makes that an ending rather than a truncated stream.
        await sendEvent(tester, snapshot(position: 119000, duration: 120000));
        await sendEvent(tester, snapshot(state: 'ended'));
        await settle(tester);
        expect(
          find.byType(VlcPlayerControls),
          findsNothing,
          reason: 'the outgoing picture is down while the next one opens',
        );

        await sendBack(tester);
        await tester.pump(const Duration(seconds: 1));
        expect(
          find.byType(VlcPlayerScreen),
          findsNothing,
          reason:
              'one press leaves: the lock went with the episode that set it',
        );
      },
    );

    testWidgets(
      'the lock clears when the media ends',
      variant: texturePlatform,
      (tester) async {
        // The ended card unmounts the entire controls subtree, and the unlock
        // chip goes with it. A lock left standing there is a lock with nothing
        // on screen to undo it - the trap the two-press escape would then be
        // the only way out of.
        await pumpPlayer(tester, pushed: true, isTv: false);
        await sendFirstFrame(tester, showControls: true);
        await lock(tester);

        // A real ending, numbers and all: an end of media with no duration
        // behind it is a truncated stream, which fails over instead of
        // carding.
        await sendEvent(tester, snapshot(position: 1199000, duration: 1200000));
        await sendEvent(tester, snapshot(state: 'ended'));
        await settle(tester);
        expect(
          find.byType(VlcPlayerControls),
          findsNothing,
          reason: 'the card replaces the controls rather than covering them',
        );

        await sendBack(tester);
        await tester.pump(const Duration(seconds: 1));
        expect(
          find.byType(VlcPlayerScreen),
          findsNothing,
          reason: 'one press leaves; nothing is left to swallow it',
        );
      },
    );

    testWidgets(
      'the lock clears when the last source dies for good',
      variant: texturePlatform,
      (tester) async {
        // The failed frame unmounts the whole controls subtree exactly as the
        // ended card does, so the unlock chip goes with it: a lock left
        // standing here is a lock with nothing on screen to undo it, on the
        // one screen a viewer most wants to leave. Worse than the card, in
        // fact - _lockedBack's only feedback is _chrome.poke(), and with no
        // bars mounted that paints nothing at all, so Back reads as broken.
        await pumpPlayer(tester, pushed: true, isTv: false);
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // One source, so the ladder is two same-source retries and then the
        // end of it. Each retry takes the picture down and clears the lock on
        // its own account, which is why the lock is set again over every
        // fresh frame: that is the state a viewer's screen is really in when
        // the third failure lands, and only the third goes to _fail.
        for (var round = 0; round < 3; round++) {
          await sendFirstFrame(tester, showControls: true);
          await lock(tester);
          await sendEvent(tester, snapshot(state: 'error'));
          await settle(tester);
        }

        expect(
          find.text(l10n.retry),
          findsOneWidget,
          reason: 'the failover ladder ran out and this is the failed frame',
        );
        expect(
          find.byType(VlcPlayerControls),
          findsNothing,
          reason: 'so the chip that undoes the lock is not on screen',
        );

        await sendBack(tester);
        await tester.pump(const Duration(seconds: 1));
        expect(
          find.byType(VlcPlayerScreen),
          findsNothing,
          reason:
              'one press leaves: the media the lock was protecting is gone, '
              'and a lock over a dead picture is a brick',
        );
      },
    );

    testWidgets(
      'the lock clears on picture-in-picture',
      variant: texturePlatform,
      (tester) async {
        // A locked PiP window is unrecoverable: the controls are not built in
        // PiP at all, so there is no chip in it and no gesture that would
        // reach one. Proved through Back rather than through a flag, because
        // Back is the only thing that can tell the two states apart from
        // outside.
        await pumpPlayer(tester, pushed: true, isTv: false);
        await sendFirstFrame(tester, showControls: true);
        await lock(tester);

        await setPipMode(tester, true);
        await setPipMode(tester, false);
        await settle(tester);

        expect(await chip(), findsNothing);
        expect(
          find.byType(PlayerBottomBar),
          findsOneWidget,
          reason: 'the bars are back, so the player is not locked',
        );

        await sendBack(tester);
        await tester.pump(const Duration(seconds: 1));
        expect(
          find.byType(VlcPlayerScreen),
          findsNothing,
          reason: 'one press leaves, because nothing swallowed it',
        );
      },
    );
  });

  testWidgets(
    'on a phone Back leaves with the bars up',
    variant: texturePlatform,
    (tester) async {
      // A phone has a tap to dismiss the bars with; Back there has always
      // meant leave, and a swipe that only cleared the chrome would read as
      // the gesture failing.
      await pumpPlayer(tester, pushed: true, isTv: false);
      await sendFirstFrame(tester, showControls: true);
      expectBarsShown(tester);

      await sendBack(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(VlcPlayerScreen), findsNothing);
    },
  );
}
