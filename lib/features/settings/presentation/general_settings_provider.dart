import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/config/tmdb_config.dart';
import '../../../core/storage/settings_repository.dart';

part 'general_settings_provider.g.dart';

class GeneralSettings {
  final bool watchHistoryEnabled;
  final String defaultHomeScreen;
  final bool githubProxyEnabled;
  final bool alwaysOnTop;
  final String titlePosition;
  final String? downloadDirectory;
  final int downloadConcurrency;
  final int downloadChunks;

  /// User-supplied TMDB API key. Empty means "fall back to the build-time
  /// `--dart-define=TMDB_API_KEY` value" (which may itself be empty).
  final String tmdbApiKey;

  const GeneralSettings({
    this.watchHistoryEnabled = true,
    this.defaultHomeScreen = '/home',
    this.githubProxyEnabled = false,
    this.alwaysOnTop = false,
    this.titlePosition = 'below',
    this.downloadDirectory,
    this.downloadConcurrency = 3,
    this.downloadChunks = 1,
    this.tmdbApiKey = '',
  });

  GeneralSettings copyWith({
    bool? watchHistoryEnabled,
    String? defaultHomeScreen,
    bool? githubProxyEnabled,
    bool? alwaysOnTop,
    String? titlePosition,
    String? downloadDirectory,
    int? downloadConcurrency,
    int? downloadChunks,
    String? tmdbApiKey,
  }) {
    return GeneralSettings(
      watchHistoryEnabled: watchHistoryEnabled ?? this.watchHistoryEnabled,
      defaultHomeScreen: defaultHomeScreen ?? this.defaultHomeScreen,
      githubProxyEnabled: githubProxyEnabled ?? this.githubProxyEnabled,
      alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
      titlePosition: titlePosition ?? this.titlePosition,
      downloadDirectory: downloadDirectory ?? this.downloadDirectory,
      downloadConcurrency: downloadConcurrency ?? this.downloadConcurrency,
      downloadChunks: downloadChunks ?? this.downloadChunks,
      tmdbApiKey: tmdbApiKey ?? this.tmdbApiKey,
    );
  }
}

@Riverpod(keepAlive: true)
class GeneralSettingsNotifier extends _$GeneralSettingsNotifier {
  @override
  GeneralSettings build() {
    final repository = ref.watch(settingsRepositoryProvider);
    return GeneralSettings(
      watchHistoryEnabled: repository.isWatchHistoryEnabled(),
      defaultHomeScreen: repository.getDefaultHomeScreen(),
      githubProxyEnabled: repository.isGithubProxyEnabled(),
      alwaysOnTop: repository.isAlwaysOnTop(),
      titlePosition: repository.getTitlePosition(),
      downloadDirectory: repository.getDownloadDirectory(),
      downloadConcurrency: repository.getDownloadConcurrency(),
      downloadChunks: repository.getDownloadChunks(),
      tmdbApiKey: repository.getTmdbApiKey(),
    );
  }

  Future<void> setWatchHistoryEnabled(bool enabled) async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setWatchHistoryEnabled(enabled);
    state = state.copyWith(watchHistoryEnabled: enabled);
  }

  Future<void> setDefaultHomeScreen(String path) async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setDefaultHomeScreen(path);
    state = state.copyWith(defaultHomeScreen: path);
  }

  Future<void> setGithubProxyEnabled(bool enabled) async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setGithubProxyEnabled(enabled);
    state = state.copyWith(githubProxyEnabled: enabled);
  }

  Future<void> setAlwaysOnTop(bool enabled) async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setAlwaysOnTop(enabled);
    state = state.copyWith(alwaysOnTop: enabled);
  }

  Future<void> setTitlePosition(String position) async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setTitlePosition(position);
    state = state.copyWith(titlePosition: position);
  }

  Future<void> setDownloadDirectory(String? path) async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setDownloadDirectory(path);
    state = state.copyWith(downloadDirectory: path);
  }

  Future<void> setDownloadConcurrency(int value) async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setDownloadConcurrency(value);
    state = state.copyWith(downloadConcurrency: value);
  }

  /// Persists a user-supplied TMDB key and mirrors it into [TmdbConfig] so
  /// in-flight screens pick it up without an app restart. Passing an empty
  /// string clears the override and reverts to the build-time key.
  Future<void> setTmdbApiKey(String value) async {
    final trimmed = value.trim();
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setTmdbApiKey(trimmed);
    TmdbConfig.setUserApiKey(trimmed);
    state = state.copyWith(tmdbApiKey: trimmed);
  }

  Future<void> setDownloadChunks(int value) async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setDownloadChunks(value);
    state = state.copyWith(downloadChunks: value);
  }
}
