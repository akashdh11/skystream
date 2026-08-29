// A compile-only smoke test.
//
// `flutter analyze` runs out of memory on this project in CI-sized sandboxes,
// and `flutter test` only compiles what the tests import — so a UI file with a
// missing import (a type that lives in a sibling file, say) compiled fine
// locally and only failed 15 minutes later in the Android build. Importing the
// screens here makes the test runner compile them, turning that class of
// mistake into an instant local failure.
import 'package:flutter_test/flutter_test.dart';

// Entry point: pulls in routing, shell, settings and everything they touch.
import 'package:skystream/main.dart' as app;

// Screens and sheets that the plugin/add-on work keeps changing.
import 'package:skystream/features/addons/presentation/addon_sources_sheet.dart';
import 'package:skystream/features/addons/presentation/addons_screen.dart';
import 'package:skystream/features/details/presentation/details_screen.dart';
import 'package:skystream/features/details/presentation/tmdb_movie_details_screen.dart';
import 'package:skystream/features/details/presentation/widgets/episode_picker_sheet.dart';
import 'package:skystream/features/details/presentation/widgets/movie_seasons_list.dart';
import 'package:skystream/features/extensions/screens/extensions_screen.dart';
import 'package:skystream/features/nuvio/presentation/nuvio_plugins_view.dart';
import 'package:skystream/features/nuvio/presentation/nuvio_scraper_settings_dialog.dart';
import 'package:skystream/features/player/presentation/player_screen.dart';
import 'package:skystream/features/sources/presentation/plugin_sources_sheet.dart';
import 'package:skystream/features/sources/presentation/source_sheet_widgets.dart';

void main() {
  test('every screen touched by plugin work still compiles', () {
    // Referencing the symbols keeps the imports (and therefore the
    // compilation) from being tree-shaken away by an over-eager analyzer.
    expect(app.main, isNotNull);
    expect(AddonSourcesSheet, isNotNull);
    expect(AddonsScreen, isNotNull);
    expect(DetailsScreen, isNotNull);
    expect(TmdbMovieDetailsScreen, isNotNull);
    expect(EpisodePickerSheet, isNotNull);
    expect(MovieSeasonsList, isNotNull);
    expect(ExtensionsScreen, isNotNull);
    expect(NuvioPluginsView, isNotNull);
    expect(NuvioScraperSettingsDialog, isNotNull);
    expect(PlayerScreen, isNotNull);
    expect(PluginSourcesSheet, isNotNull);
    expect(SourcesMode.play, isNotNull);
  });
}
