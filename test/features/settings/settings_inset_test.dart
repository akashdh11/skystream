/// How far a settings card sits from the edge of the screen.
///
/// [SettingsGroup] already insets itself - `spacingMd` on the title's padding
/// and the same again on the card's margin - so a host screen that adds its
/// own horizontal padding to the surrounding ListView pays for that inset
/// twice. Settings and Player settings did (32), Developer options did at a
/// different rate (24), and Accounts did not (16), so the four screens of one
/// settings tree disagreed about their own left edge.
///
/// The inset is measured off the rendered card rather than read back out of
/// the padding constants, so this stays true however the inset is arrived at.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/providers/device_info_provider.dart';
import 'package:skystream/core/services/notification_service.dart';
import 'package:skystream/core/storage/secure_token_storage.dart';
import 'package:skystream/core/storage/settings_repository.dart';
import 'package:skystream/core/storage/storage_service.dart';
import 'package:skystream/core/theme/theme_provider.dart';
import 'package:skystream/core/utils/layout_constants.dart';
import 'package:skystream/features/settings/presentation/account_settings_screen.dart';
import 'package:skystream/features/settings/presentation/app_version_provider.dart';
import 'package:skystream/features/settings/presentation/cache_provider.dart';
import 'package:skystream/features/settings/presentation/developer_options_screen.dart';
import 'package:skystream/features/settings/presentation/general_settings_provider.dart';
import 'package:skystream/features/settings/presentation/player_settings_provider.dart';
import 'package:skystream/features/settings/presentation/player_settings_screen.dart';
import 'package:skystream/features/settings/presentation/settings_screen.dart';
import 'package:skystream/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:skystream/features/tracking/presentation/tracking_auth_provider.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';

/// Enough of a repository to render a settings tree, and nothing that touches
/// a box: [StorageService] here is never initialised.
class _QuietSettings extends SettingsRepository {
  _QuietSettings() : super(StorageService());

  @override
  double? getUiScale() => null;

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

void main() {
  /// The painted edge of the card inside the first group on screen.
  ///
  /// The [DecoratedBox], not the [Container] that produces it: a Container
  /// with a margin lays out as padding wrapped around the decoration, so
  /// measuring the Container returns the outer edge and reports the margin as
  /// though it were not there.
  Finder firstCard() => find
      .descendant(
        of: find.byType(SettingsGroup).first,
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).borderRadius != null,
        ),
      )
      .first;

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
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: screen,
        ),
      ),
    );
    await tester.pump();
  }

  /// Every screen in the settings tree, named the way the app names them.
  final screens = <String, Widget>{
    'Settings': const SettingsScreen(),
    'Player settings': const PlayerSettingsScreen(),
    'Accounts, Network & Downloads': const AccountSettingsScreen(
      isEmbedded: true,
    ),
    'Developer options': const DeveloperOptionsScreen(),
  };

  screens.forEach((name, screen) {
    testWidgets('$name insets its cards by one step', (tester) async {
      await pump(tester, screen);

      expect(
        find.byType(SettingsGroup),
        findsWidgets,
        reason: '$name renders no settings group to measure',
      );
      expect(
        tester.getTopLeft(firstCard()).dx,
        LayoutConstants.spacingMd,
        reason:
            '$name pays for the inset twice: SettingsGroup already applies '
            'spacingMd, so the surrounding ListView must not apply it again',
      );
    });
  });

  testWidgets('all four agree, so the tree has one left edge', (tester) async {
    final measured = <String, double>{};
    for (final entry in screens.entries) {
      await pump(tester, entry.value);
      measured[entry.key] = tester.getTopLeft(firstCard()).dx;
    }

    expect(
      measured.values.toSet(),
      hasLength(1),
      reason:
          'the settings tree is one screen as far as a reader is concerned, '
          'and its cards must not shift sideways on the way in: $measured',
    );
  });
}
