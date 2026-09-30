// Test doubles expose what they recorded.
// ignore_for_file: riverpod_lint/avoid_public_notifier_properties

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/network/doh_service.dart';
import 'package:skystream/core/storage/settings_repository.dart';
import 'package:skystream/core/storage/storage_service.dart';
import 'package:skystream/core/providers/device_info_provider.dart';
import 'package:skystream/features/player/presentation/player_platform_service.dart';
import 'package:skystream/features/settings/presentation/player_settings_provider.dart';
import 'package:skystream/features/settings/presentation/widgets/settings_dialogs.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';

/// Keeps [playerSettingsProvider] off the on-disk repository: these tests are
/// about what the dialogs *offer*, not about what is stored.
class _StubPlayerSettings extends PlayerSettingsNotifier {
  @override
  Future<PlayerSettings> build() async => const PlayerSettings();
}

/// Records what a dialog asks the notifier for instead of writing it to Hive.
///
/// [_StubPlayerSettings] answers `build` and nothing else, so a setter called
/// on it reaches the real repository and the real box. These tests are about
/// the write the dialog issues, so the write is the thing that has to be
/// observable.
class _RecordingPlayerSettings extends PlayerSettingsNotifier {
  _RecordingPlayerSettings(this.initial, this.subtitleDefaults);

  final SubtitleDefault initial;
  final List<SubtitleDefault> subtitleDefaults;

  @override
  Future<PlayerSettings> build() async =>
      PlayerSettings(subtitleDefault: initial);

  /// Records only. Nothing in these tests watches the provider, so its state
  /// is still `AsyncLoading` when the tap lands and writing to it would throw
  /// where the real notifier - built by something that awaited it - would not.
  @override
  Future<void> setSubtitleDefault(SubtitleDefault value) async {
    subtitleDefaults.add(value);
  }
}

/// Keeps the DoH picker off SharedPreferences.
class _StubDoh extends DohSettingsNotifier {
  _StubDoh(this._value);

  final DohSettings _value;

  @override
  Future<DohSettings> build() async => _value;
}

/// Pumps a single button that opens [open] with a real [WidgetRef].
Future<void> _pumpOpener(
  WidgetTester tester, {
  required void Function(BuildContext, WidgetRef) open,
  TargetPlatform platform = TargetPlatform.android,
  DeviceProfile profile = const DeviceProfile(),
  PlayerSettingsNotifier Function()? settings,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        deviceProfileProvider.overrideWithValue(AsyncValue.data(profile)),
        playerSettingsProvider.overrideWith(
          settings ?? _StubPlayerSettings.new,
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => open(context, ref),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// The title of the [ListTile] that currently owns the primary focus, or null
/// if focus is not inside a row.
String? _focusedRowTitle() {
  final BuildContext? context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return null;
  final ListTile? tile = context.findAncestorWidgetOfExactType<ListTile>();
  final Widget? title = tile?.title;
  return title is Text ? title.data : null;
}

void main() {
  // playerFormFactorOf() reads this global, and the Big Picture test in this
  // directory flips it. Leave it as we found it.
  setUp(() => fullScreenModeActive.value = false);
  tearDown(() => fullScreenModeActive.value = false);

  group(
    'showPlayerControlsDialog only offers buttons this device can draw',
    () {
      // Every row's label, in the order the dialog builds them.
      const String pip = 'Picture-in-Picture button';
      const String resize = 'Resize button';
      const String speed = 'Playback speed button';
      const String episodes = 'Previous / next episode buttons';
      const String volume = 'Volume button';

      /// The label the retired rotate switch carried. No device may offer it:
      /// the player draws no rotate button for it to hide.
      const String rotate = 'Rotate button';

      /// (case name, platform, profile, rows that must be offered).
      final cases = <(String, TargetPlatform, DeviceProfile, List<String>)>[
        (
          'Android phone — the only device that gets the PiP row',
          TargetPlatform.android,
          const DeviceProfile(),
          [volume, pip, resize, speed, episodes],
        ),
        (
          'Android tablet',
          TargetPlatform.android,
          const DeviceProfile(isTablet: true),
          [volume, pip, resize, speed, episodes],
        ),
        (
          'Android TV — nothing to shrink into',
          TargetPlatform.android,
          const DeviceProfile(isTv: true),
          [volume, resize, speed, episodes],
        ),
        (
          'iPhone — no OS-level PiP for us',
          TargetPlatform.iOS,
          const DeviceProfile(),
          [volume, resize, speed, episodes],
        ),
        (
          'iPad',
          TargetPlatform.iOS,
          const DeviceProfile(isTablet: true),
          [volume, resize, speed, episodes],
        ),
        (
          'macOS',
          TargetPlatform.macOS,
          const DeviceProfile(isDesktopOS: true),
          [volume, resize, speed, episodes],
        ),
        (
          'Windows',
          TargetPlatform.windows,
          const DeviceProfile(isDesktopOS: true),
          [volume, resize, speed, episodes],
        ),
        (
          'Linux',
          TargetPlatform.linux,
          const DeviceProfile(isDesktopOS: true),
          [volume, resize, speed, episodes],
        ),
      ];

      for (final (name, platform, profile, expected) in cases) {
        testWidgets(name, (tester) async {
          await _pumpOpener(
            tester,
            open: showPlayerControlsDialog,
            platform: platform,
            profile: profile,
          );

          expect(find.text('Player Controls'), findsOneWidget);
          for (final String label in <String>[
            volume,
            pip,
            resize,
            rotate,
            speed,
            episodes,
          ]) {
            expect(
              find.text(label),
              expected.contains(label) ? findsOneWidget : findsNothing,
              reason: '$label on $name',
            );
          }
          expect(find.byType(SwitchListTile), findsNWidgets(expected.length));
        });
      }

      testWidgets('Big Picture on a desktop is treated as the television it '
          'imitates', (tester) async {
        fullScreenModeActive.value = true;
        await _pumpOpener(
          tester,
          open: showPlayerControlsDialog,
          platform: TargetPlatform.android,
          profile: const DeviceProfile(),
        );
        expect(find.text(pip), findsNothing);
        expect(find.text(rotate), findsNothing);
      });

      test('the predicates are the player screen\'s own, spelled out', () {
        // PiP: Android, anywhere but a television.
        expect(
          playerCanShowPip(TargetPlatform.android, PlayerFormFactor.phone),
          isTrue,
        );
        expect(
          playerCanShowPip(TargetPlatform.android, PlayerFormFactor.tablet),
          isTrue,
        );
        expect(
          playerCanShowPip(TargetPlatform.android, PlayerFormFactor.tv),
          isFalse,
        );
        expect(
          playerCanShowPip(TargetPlatform.iOS, PlayerFormFactor.phone),
          isFalse,
        );
        expect(
          playerCanShowPip(TargetPlatform.macOS, PlayerFormFactor.desktop),
          isFalse,
        );

        // An unresolved device profile is "we do not know". PiP survives it
        // because the player's own `_pipAvailable` does: the callback is
        // non-null on Android until the profile says television.
        expect(
          playerCanShowPip(TargetPlatform.android, PlayerFormFactor.unknown),
          isTrue,
        );
      });

      testWidgets('the rotate row is gone on the two devices that used to '
          'get it', (tester) async {
        // An Android phone and an Android tablet were the shapes where the
        // retired predicate was true, so they are the shapes where a
        // resurrected row would show up first. The player builds no rotate
        // button on either any more (see
        // test/features/player/orientation_follows_video_test.dart), so a
        // switch here would move a stored boolean and change nothing.
        for (final DeviceProfile profile in <DeviceProfile>[
          const DeviceProfile(),
          const DeviceProfile(isTablet: true),
        ]) {
          await _pumpOpener(
            tester,
            open: showPlayerControlsDialog,
            platform: TargetPlatform.android,
            profile: profile,
          );
          expect(find.text(rotate), findsNothing);
          expect(find.byIcon(Icons.screen_rotation_rounded), findsNothing);
          expect(find.byType(SwitchListTile), findsNWidgets(5));
          await tester.tap(find.text('Close'));
          await tester.pumpAndSettle();
        }
      });
    },
  );

  group('a picker opens on the value that is already set', () {
    testWidgets('seek duration focuses the current row, not the first', (
      tester,
    ) async {
      await _pumpOpener(
        tester,
        open: (context, ref) => showDurationDialog(context, ref, 30),
      );

      expect(find.text('5 sec'), findsOneWidget, reason: 'row one is present');
      expect(_focusedRowTitle(), '30 sec');
    });

    testWidgets('resize focuses the current row', (tester) async {
      await _pumpOpener(
        tester,
        open: (context, ref) => showResizeDialog(context, ref, 'Stretch'),
      );
      expect(_focusedRowTitle(), 'Stretch');
    });

    testWidgets('theme focuses the current row', (tester) async {
      await _pumpOpener(
        tester,
        open: (context, ref) => showThemeDialog(context, ref, ThemeMode.light),
      );
      expect(_focusedRowTitle(), 'Light');
    });

    testWidgets('gesture focuses the current row', (tester) async {
      await _pumpOpener(
        tester,
        open: (context, ref) =>
            showGestureDialog(context, ref, true, PlayerGesture.none),
      );
      expect(_focusedRowTitle(), 'None');
    });

    testWidgets('a value with no matching row claims nothing, rather than '
        'letting two rows claim it', (tester) async {
      // 45 s is not one of the offered durations.
      await _pumpOpener(
        tester,
        open: (context, ref) => showDurationDialog(context, ref, 45),
      );
      expect(tester.takeException(), isNull);
      expect(_focusedRowTitle(), isNull);
    });

    testWidgets('a long picker scrolls the current row into view, not just '
        'focuses it off screen', (tester) async {
      // The language list is the app's longest picker by far: 43 rows of 56 dp
      // against an 800x600 dialog. Whichever locale is last is the one that
      // needs scrolling to.
      final Locale target = AppLocalizations.supportedLocales.last;
      final String targetLabel = (await AppLocalizations.delegate.load(
        target,
      )).languageName;
      final String firstLabel = (await AppLocalizations.delegate.load(
        AppLocalizations.supportedLocales.first,
      )).languageName;

      await _pumpOpener(
        tester,
        open: (context, ref) => showLanguageDialog(context, ref, target),
      );

      expect(_focusedRowTitle(), targetLabel);

      final Finder viewport = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Scrollable),
      );
      final Rect viewportRect = tester.getRect(viewport);
      final Rect rowRect = tester.getRect(
        find.ancestor(
          of: find.text(targetLabel),
          matching: find.byType(ListTile),
        ),
      );
      final Rect firstRowRect = tester.getRect(
        find.ancestor(
          of: find.text(firstLabel),
          matching: find.byType(ListTile),
        ),
      );

      // The list is genuinely taller than its viewport, or this proves nothing.
      expect(
        rowRect.bottom - firstRowRect.top,
        greaterThan(viewportRect.height),
        reason: 'picker must overflow for the scroll to matter',
      );
      expect(
        viewportRect.contains(rowRect.topLeft) &&
            viewportRect.contains(rowRect.bottomRight - const Offset(1, 1)),
        isTrue,
        reason: 'row $rowRect is not inside viewport $viewportRect',
      );
    });

    testWidgets('the DoH picker on Custom leaves the URL field the only '
        'claimant, so no scope has two', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dohSettingsProvider.overrideWith(
              () => _StubDoh(
                const DohSettings(
                  provider: DohProvider.custom,
                  customUrl: 'https://example.test/dns-query',
                ),
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  // Watched so the stub has resolved before the dialog's
                  // initState reads it.
                  ref.watch(dohSettingsProvider);
                  return TextButton(
                    onPressed: () => showDohProviderDialog(context, ref),
                    child: const Text('open'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_focusedRowTitle(), isNull, reason: 'no row may claim focus here');
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<EditableText>()
            ?.controller
            .text,
        'https://example.test/dns-query',
      );
    });

    testWidgets('the DoH picker on a plain provider focuses that row', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dohSettingsProvider.overrideWith(
              () => _StubDoh(const DohSettings(provider: DohProvider.quad9)),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  ref.watch(dohSettingsProvider);
                  return TextButton(
                    onPressed: () => showDohProviderDialog(context, ref),
                    child: const Text('open'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(_focusedRowTitle(), 'Quad9');
    });
  });

  /// The Subtitles-by-default picker.
  ///
  /// The row it opens from is a default for newly opened media, not a switch
  /// that takes the player's Subtitles menu away, and "Off" on its own reads
  /// exactly like the second thing. So the detail line under each choice is
  /// part of the control, not decoration, and is asserted here.
  group('showSubtitleDefaultDialog', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    Future<List<SubtitleDefault>> open(
      WidgetTester tester,
      SubtitleDefault current,
    ) async {
      final List<SubtitleDefault> chosen = <SubtitleDefault>[];
      await _pumpOpener(
        tester,
        settings: () => _RecordingPlayerSettings(current, chosen),
        open: (context, ref) =>
            showSubtitleDefaultDialog(context, ref, current),
      );
      return chosen;
    }

    testWidgets('offers both choices, each with what it means', (tester) async {
      await open(tester, SubtitleDefault.auto);

      expect(find.text(l10n.subtitleDefault), findsOneWidget);
      expect(find.text(l10n.subtitleDefaultAuto), findsOneWidget);
      expect(find.text(l10n.subtitleDefaultAutoDetail), findsOneWidget);
      expect(find.text(l10n.off), findsOneWidget);
      expect(
        find.text(l10n.subtitleDefaultOffDetail),
        findsOneWidget,
        reason:
            'without this line Off reads as "subtitles are disabled", which '
            'is not what it does',
      );
    });

    testWidgets('opens on the choice in force, so a remote lands on it', (
      tester,
    ) async {
      await open(tester, SubtitleDefault.off);

      expect(_focusedRowTitle(), l10n.off);
    });

    testWidgets('a pick reaches the setter and closes the dialog', (
      tester,
    ) async {
      final List<SubtitleDefault> chosen = await open(
        tester,
        SubtitleDefault.auto,
      );

      await tester.tap(find.text(l10n.subtitleDefaultOffDetail));
      await tester.pumpAndSettle();

      expect(chosen, <SubtitleDefault>[SubtitleDefault.off]);
      expect(find.text(l10n.subtitleDefaultAutoDetail), findsNothing);
    });
  });

  /// The OpenSubtitles sign-in.
  ///
  /// `OpenSubtitlesProvider` returns an empty list before it sends anything
  /// when it has no API key, and no shipped build supplies the build-time one,
  /// so the key the viewer pastes here is the only thing that turns the
  /// provider on. Until this field existed `osApiKey` could not be written
  /// from anywhere in the app.
  group('the OpenSubtitles dialog', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    Future<_RecordingOpenSubtitles> open(
      WidgetTester tester,
      PlayerSettings settings,
    ) async {
      final _RecordingOpenSubtitles notifier = _RecordingOpenSubtitles(
        settings,
      );
      await _pumpOpener(
        tester,
        settings: () => notifier,
        open: (context, ref) =>
            showOpenSubtitlesAuthDialog(context, ref, settings),
      );
      return notifier;
    }

    Finder fieldFor(String label) =>
        find.ancestor(of: find.text(label), matching: find.byType(TextField));

    testWidgets('Save carries the API key, not only the credentials', (
      tester,
    ) async {
      final _RecordingOpenSubtitles notifier = await open(
        tester,
        const PlayerSettings(),
      );

      await tester.enterText(fieldFor(l10n.apiKey), 'os-api-key');
      await tester.enterText(fieldFor(l10n.username), 'ada');
      await tester.enterText(fieldFor(l10n.password), 'hunter2');
      await tester.tap(find.text(l10n.save));
      await tester.pumpAndSettle();

      expect(notifier.saved, <List<String?>>[
        <String?>['ada', 'hunter2', 'os-api-key'],
      ]);
    });

    testWidgets('Test Connection tests the key that was just typed', (
      tester,
    ) async {
      final _RecordingOpenSubtitles notifier = await open(
        tester,
        const PlayerSettings(),
      );

      await tester.enterText(fieldFor(l10n.apiKey), 'os-api-key');
      await tester.enterText(fieldFor(l10n.username), 'ada');
      await tester.enterText(fieldFor(l10n.password), 'hunter2');
      await tester.tap(find.text(l10n.testConnection));
      await tester.pumpAndSettle();

      expect(notifier.verified, <List<String?>>[
        <String?>['ada', 'hunter2', 'os-api-key'],
      ]);
    });

    testWidgets('a stored key comes back into the field', (tester) async {
      await open(tester, const PlayerSettings(osApiKey: 'stored-key'));

      expect(
        tester.widget<TextField>(fieldFor(l10n.apiKey)).controller?.text,
        'stored-key',
      );
    });
  });

  /// "Reset Data (Keep Extensions)" promises to clear Settings, and the two
  /// subtitle account passwords are not in the box it empties - they are in
  /// the Keychain/Keystore. Left behind, the next launch reads the usernames
  /// as gone and draws "Not logged in" over passwords still on the device.
  testWidgets('Reset Data clears the account passwords with the box', (
    tester,
  ) async {
    final AppLocalizations l10n = await AppLocalizations.delegate.load(
      const Locale('en'),
    );
    final _RecordingReset repository = _RecordingReset();
    final _RecordingCredentialReset notifier = _RecordingCredentialReset();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repository),
          playerSettingsProvider.overrideWith(() => notifier),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showResetDataDialog(context, ref),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.resetDataKeepExtensions));
    await tester.pumpAndSettle();

    expect(repository.cleared, 1, reason: 'the box still has to go');
    expect(notifier.clears, 1);
  });

  // A stored player id this platform does not list - a build that dropped the
  // player, or a settings box carried over - matched no row, so the group
  // opened with nothing selected and Cancel put the same id back.
  group('showDefaultPlayerDialog always shows what is stored', () {
    testWidgets('a player this platform does not list still has a row', (
      tester,
    ) async {
      await _pumpOpener(
        tester,
        open: (context, ref) =>
            showDefaultPlayerDialog(context, ref, 'potplayer'),
      );

      // PotPlayer is Windows-only and the test host reports Android.
      expect(find.text('PotPlayer'), findsOneWidget);
      expect(
        find.text('Not offered on this device'),
        findsOneWidget,
        reason: 'a row with no explanation is worse than the missing one',
      );
      expect(_selectedRadioValues(tester), <String?>['potplayer']);
    });

    testWidgets('an id no build ever had is named as itself', (tester) async {
      await _pumpOpener(
        tester,
        open: (context, ref) =>
            showDefaultPlayerDialog(context, ref, 'some_retired_player'),
      );

      expect(find.text('some_retired_player'), findsOneWidget);
      expect(_selectedRadioValues(tester), <String?>['some_retired_player']);
    });

    testWidgets('a player this platform does list gets no extra row', (
      tester,
    ) async {
      await _pumpOpener(
        tester,
        open: (context, ref) =>
            showDefaultPlayerDialog(context, ref, 'mx_player'),
      );

      expect(find.text('Not offered on this device'), findsNothing);
      expect(_selectedRadioValues(tester), <String?>['mx_player']);
    });
  });
}

/// The values of every radio the dialog is currently showing as chosen.
List<String?> _selectedRadioValues(WidgetTester tester) {
  final RadioGroup<String?> group = tester.widget<RadioGroup<String?>>(
    find.byType(RadioGroup<String?>),
  );
  return tester
      .widgetList<Radio<String?>>(find.byType(Radio<String?>))
      .where((Radio<String?> r) => r.value == group.groupValue)
      .map((Radio<String?> r) => r.value)
      .toList();
}

/// Records what the reset button does instead of emptying the real box.
class _RecordingReset extends SettingsRepository {
  _RecordingReset() : super(StorageService());

  int cleared = 0;

  @override
  Future<void> clearPreferences({bool keepRepos = true}) async => cleared++;
}

/// Counts the secure-store wipe instead of reaching the Keychain.
class _RecordingCredentialReset extends PlayerSettingsNotifier {
  int clears = 0;

  @override
  FutureOr<PlayerSettings> build() => const PlayerSettings();

  @override
  Future<void> clearCredentials() async => clears++;
}

/// Records the two calls the OpenSubtitles dialog can make instead of writing
/// to Hive and the network.
class _RecordingOpenSubtitles extends PlayerSettingsNotifier {
  _RecordingOpenSubtitles(this.initial);

  final PlayerSettings initial;
  final List<List<String?>> saved = <List<String?>>[];
  final List<List<String?>> verified = <List<String?>>[];

  @override
  FutureOr<PlayerSettings> build() => initial;

  @override
  Future<void> setOpenSubtitlesCredentials(
    String user,
    String pass, [
    String? key,
  ]) async {
    saved.add(<String?>[user, pass, key]);
  }

  @override
  Future<bool> verifyOpenSubtitles(
    String user,
    String pass, [
    String? key,
  ]) async {
    verified.add(<String?>[user, pass, key]);
    return true;
  }
}
