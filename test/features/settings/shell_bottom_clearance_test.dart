/// How far a screen's scrollable content must clear the shell's bottom bar.
///
/// On a phone the shell paints its floating bottom bar over every route it
/// hosts — the tab screens and the routes pushed under them alike — and tells
/// the content about the bar by adding its height to the `MediaQuery`
/// padding. Each host then has to pay the bar back in as bottom padding
/// through `LayoutConstants.shellBottomContentPadding`. The tab screens did;
/// the routes pushed under the settings tab did not, and the last row of the
/// Accounts screen went behind the pill.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/core/providers/device_info_provider.dart';
import 'package:skystream/core/services/notification_service.dart';
import 'package:skystream/core/storage/secure_token_storage.dart';
import 'package:skystream/core/storage/settings_repository.dart';
import 'package:skystream/core/storage/storage_service.dart';
import 'package:skystream/core/theme/theme_provider.dart';
import 'package:skystream/features/library/presentation/library_provider.dart';
import 'package:skystream/features/library/presentation/library_state.dart';
import 'package:skystream/features/library/presentation/widgets/bookmarks_tab.dart';
import 'package:skystream/features/settings/presentation/account_settings_screen.dart';
import 'package:skystream/features/settings/presentation/app_version_provider.dart';
import 'package:skystream/features/settings/presentation/cache_provider.dart';
import 'package:skystream/features/settings/presentation/developer_options_screen.dart';
import 'package:skystream/features/settings/presentation/general_settings_provider.dart';
import 'package:skystream/features/settings/presentation/player_settings_provider.dart';
import 'package:skystream/features/settings/presentation/settings_screen.dart';
import 'package:skystream/features/tracking/presentation/tracking_auth_provider.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';

/// The bottom edge of the shell's bottom bar, expressed the way the shell
/// expresses it: added to the media padding. The helper floors at 100, so
/// 120 survives that floor and the assertion can name the exact number the
/// content must clear.
const double kShellBar = 120;

/// Enough of a repository to render a settings tree, and nothing that touches
/// a box.
class _QuietSettings extends SettingsRepository {
  _QuietSettings() : super(StorageService());

  @override
  bool isWatchHistoryEnabled() => true;

  @override
  String getDefaultHomeScreen() => '/home';

  @override
  bool isGithubProxyEnabled() => false;

  @override
  bool? getFullScreenMode() => false;

  @override
  Future<void> setFullScreenMode(bool enabled) async {}

  @override
  bool isAnimeSkipIntegrationEnabled() => false;

  @override
  bool isIntroDbIntegrationEnabled() => false;

  @override
  bool getDevLoadAssets() => false;
}

class _NoTokens extends SecureTokenStorage {
  _NoTokens() : super(StorageService());

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}
}

class _SignedOutTrackers extends TrackingAuth {
  @override
  Future<Map<String, bool>> build() async => const <String, bool>{
    'simkl': false,
    'trakt': false,
    'mal': false,
    'anilist': false,
  };
}

/// A library with bookmarks in it, so the grid branch is what renders.
class _FakeLibrary extends Library {
  _FakeLibrary() : super();

  @override
  LibraryState build() =>
      LibrarySuccess(<MultimediaItem>[
        for (var i = 0; i < 40; i++)
          MultimediaItem(
            title: 'Title $i',
            url: 'https://fake.test/$i',
            posterUrl: '',
            contentType: MultimediaContentType.movie,
          ),
      ]);
}

void main() {
  /// Pumps [screen] the way the mobile shell hosts it: full screen, with the
  /// bar's height riding on the media padding.
  Future<void> pump(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(_QuietSettings()),
          secureTokenStorageProvider.overrideWithValue(_NoTokens()),
          notificationServiceProvider.overrideWithValue(NotificationService()),
          trackingAuthProvider.overrideWith(_SignedOutTrackers.new),
          appThemeModeProvider.overrideWithValue(ThemeMode.dark),
          generalSettingsProvider.overrideWithValue(const GeneralSettings()),
          playerSettingsProvider.overrideWithBuild(
            (_, _) => const PlayerSettings(),
          ),
          deviceProfileProvider.overrideWith(
            (ref) => const DeviceProfile(isDesktopOS: true),
          ),
          appVersionProvider.overrideWith((ref) async => '1.0.0 +1'),
          cacheSizeProvider.overrideWith((ref) async => 0),
          libraryProvider.overrideWith(() => _FakeLibrary()),
        ],
        child: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(bottom: kShellBar)),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: screen,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// The bottom padding of the first [ListView] / [GridView] on screen.
  double bottomPadding(WidgetTester tester) {
    final listView = find.byType(ListView);
    if (listView.evaluate().isNotEmpty) {
      final padding = tester.widget<ListView>(listView.first).padding!;
      return (padding is EdgeInsets
              ? padding
              : padding.resolve(const TextDirection.ltr))
          .bottom;
    }
    final padding = tester.widget<GridView>(find.byType(GridView).first)
        .padding!;
    return (padding is EdgeInsets
            ? padding
            : padding.resolve(const TextDirection.ltr))
        .bottom;
  }

  // The standalone routes are what the shell pushes; the embedded variants
  // are hosted by whoever embeds them and are not the case on screen here.
  final screens = <String, Widget>{
    'Settings': const SettingsScreen(),
    'Player settings': const PlayerSettingsScreen(),
    'Accounts, Network & Downloads': const AccountSettingsScreen(),
    'Developer options': const DeveloperOptionsScreen(),
  };

  for (final (name, screen) in screens.entries) {
    testWidgets('$name clears the shell bottom bar', (tester) async {
      await pump(tester, screen);
      expect(
        bottomPadding(tester),
        kShellBar,
        reason:
            '$name scrolls behind the shell bottom bar: the bar rides on '
            'the media padding, so the list must pay it back as bottom '
            'padding',
      );
    });
  }

  testWidgets('the bookmarks grid clears the shell bottom bar',
      (tester) async {
    await pump(tester, const BookmarksTab());
    expect(
      bottomPadding(tester),
      kShellBar,
      reason: 'the bookmarks grid scrolls behind the shell bottom bar',
    );
  });
}
