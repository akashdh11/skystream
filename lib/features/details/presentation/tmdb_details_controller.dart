import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../explore/data/explore_language_provider.dart';
import '../../explore/data/explore_tmdb_provider.dart';
import '../../explore/data/anilist_repository.dart';

part 'tmdb_details_controller.g.dart';

class TmdbDetailsState {
  final int selectedSeason;
  final Future<Map<String, dynamic>?>? episodesFuture;

  const TmdbDetailsState({this.selectedSeason = 1, this.episodesFuture});

  TmdbDetailsState copyWith({
    int? selectedSeason,
    Future<Map<String, dynamic>?>? episodesFuture,
  }) {
    return TmdbDetailsState(
      selectedSeason: selectedSeason ?? this.selectedSeason,
      episodesFuture: episodesFuture ?? this.episodesFuture,
    );
  }
}

@riverpod
class TmdbDetailsController extends _$TmdbDetailsController {
  final Map<int, Future<Map<String, dynamic>?>> _seasonsCache = {};

  @override
  TmdbDetailsState build(int movieId, {String? source}) {
    if (source == 'anilist') {
      final future = ref
          .read(anilistRepositoryProvider)
          .getAnimeEpisodes(movieId);
      return TmdbDetailsState(selectedSeason: 1, episodesFuture: future);
    }
    // Watch language so we re-fetch if it changes
    final lang = ref.watch(languageProvider);

    _seasonsCache.clear();
    // Start fetching season 1 by default
    final future = ref
        .read(tmdbServiceProvider)
        .getTvSeasonDetails(movieId, 1, language: lang);
    _seasonsCache[1] = future;

    return TmdbDetailsState(selectedSeason: 1, episodesFuture: future);
  }

  Future<void> fetchEpisodes(int season, {String? source}) async {
    if (source == 'anilist') {
      return;
    }
    final lang = ref.read(languageProvider);

    final future = _seasonsCache[season] ??= ref
        .read(tmdbServiceProvider)
        .getTvSeasonDetails(movieId, season, language: lang);

    state = state.copyWith(selectedSeason: season, episodesFuture: future);
  }
}
