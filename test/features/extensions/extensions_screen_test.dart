import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skystream/features/extensions/screens/extensions_screen.dart';
import 'package:skystream/features/extensions/providers/extensions_controller.dart';
import 'package:skystream/core/extensions/extension_manager.dart';
import 'package:skystream/core/extensions/models/extension_plugin.dart';
import 'package:skystream/core/extensions/models/extension_repository.dart';
import 'package:skystream/core/extensions/base_provider.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';

class MockExtensionsController extends ExtensionsController {
  final ExtensionsState initialState;
  MockExtensionsController(this.initialState);

  @override
  ExtensionsState build() => initialState;

  @override
  Future<void> ensureInitialized() async {}
}

class MockExtensionManager extends ExtensionManager {
  @override
  List<SkyStreamProvider> build() => [];

  @override
  List<PluginSubProvider> getProvidersForPlugin(ExtensionPlugin plugin) => [];

  @override
  Future<List<PluginSettingDefinition>> getSettingsForPlugin(
    ExtensionPlugin plugin,
  ) async => [];
}

void main() {
  testWidgets(
    'ExtensionsScreen displays 2 tabs and guided empty state when no plugins installed',
    (WidgetTester tester) async {
      final emptyState = ExtensionsSuccess(
        repositories: [
          ExtensionRepository(
            name: 'Test Repo',
            url: 'https://example.com/repo.json',
            pluginLists: [],
          ),
        ],
        installedPlugins: [],
        availablePlugins: {},
        availableUpdates: {},
        installingPlugins: {},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            extensionsControllerProvider.overrideWith(
              () => MockExtensionsController(emptyState),
            ),
            extensionManagerProvider.overrideWith(() => MockExtensionManager()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ExtensionsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // TabBar should be present with 2 tabs by default
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('Installed'), findsOneWidget);
      expect(find.text('Repositories'), findsOneWidget);

      // Installed tab should present guided empty state
      expect(find.text('No Extensions Installed'), findsOneWidget);
      expect(find.text('Browse Repositories'), findsOneWidget);

      // Tapping 'Browse Repositories' button switches to Repositories tab
      await tester.tap(find.text('Browse Repositories'));
      await tester.pumpAndSettle();

      // Repositories content should now be visible
      expect(find.text('Test Repo'), findsOneWidget);
    },
  );

  testWidgets(
    'ExtensionsScreen displays Installed plugin list when extensions installed',
    (WidgetTester tester) async {
      final installedState = ExtensionsSuccess(
        repositories: [
          ExtensionRepository(
            name: 'Test Repo',
            url: 'https://example.com/repo.json',
            pluginLists: [],
          ),
        ],
        installedPlugins: [
          ExtensionPlugin(
            name: 'Installed Plugin',
            version: 1,
            packageName: 'com.example.plugin',
            repositoryId: 'test_repo',
            sourceUrl: 'https://example.com/plugin.js',
          ),
        ],
        availablePlugins: {},
        availableUpdates: {},
        installingPlugins: {},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            extensionsControllerProvider.overrideWith(
              () => MockExtensionsController(installedState),
            ),
            extensionManagerProvider.overrideWith(() => MockExtensionManager()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ExtensionsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // TabBar should be present with 2 tabs
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('Installed'), findsOneWidget);
      expect(find.text('Repositories'), findsOneWidget);

      // Installed plugin list should display the installed plugin exactly once
      expect(find.text('Installed Plugin'), findsOneWidget);
    },
  );
}
