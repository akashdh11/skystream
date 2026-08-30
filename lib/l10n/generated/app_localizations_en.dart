// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => 'English';

  @override
  String get home => 'Home';

  @override
  String get search => 'Search';

  @override
  String get explore => 'Explore';

  @override
  String get exploreAnime => 'Explore Anime';

  @override
  String get exploreMovies => 'Explore Movies';

  @override
  String get library => 'Library';

  @override
  String get settings => 'Settings';

  @override
  String get extensions => 'Extensions';

  @override
  String get updateAvailable => 'Update Available';

  @override
  String get retry => 'Retry';

  @override
  String get factoryReset => 'Factory Reset';

  @override
  String get startupError => 'Startup Error';

  @override
  String get general => 'General';

  @override
  String get appTheme => 'App Theme';

  @override
  String get recordWatchHistory => 'Record Watch History';

  @override
  String get defaultHomeScreen => 'Default Home Screen';

  @override
  String get titlePosition => 'Title Position';

  @override
  String get titlePositionBelowPoster => 'Below Poster';

  @override
  String get titlePositionInsidePoster => 'Inside Poster';

  @override
  String get player => 'Player';

  @override
  String get defaultPlayer => 'Default Player';

  @override
  String get leftGesture => 'Left Gesture';

  @override
  String get rightGesture => 'Right Gesture';

  @override
  String get doubleTapToSeek => 'Double Tap to Seek';

  @override
  String get swipeToSeek => 'Swipe to Seek';

  @override
  String get seekDuration => 'Seek Duration';

  @override
  String get bufferDepth => 'Buffer depth';

  @override
  String get defaultResizeMode => 'Default Resize Mode';

  @override
  String get hardwareDecoding => 'Hardware Decoding';

  @override
  String get network => 'Network';

  @override
  String get dnsOverHttps => 'DNS over HTTPS';

  @override
  String get dohProvider => 'DoH Provider';

  @override
  String get githubProxy => 'GitHub Proxy';

  @override
  String get githubProxySubtitle =>
      'Route extension downloads through jsDelivr to bypass ISP blocks.';

  @override
  String get manageExtensions => 'Manage Extensions';

  @override
  String get appData => 'App Data';

  @override
  String get resetDataKeepExtensions => 'Reset Data (Keep Extensions)';

  @override
  String get developer => 'Developer';

  @override
  String get developerOptions => 'Developer Options';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get enabled => 'Enabled';

  @override
  String get disabled => 'Disabled';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'Join our server';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'Join our channel';

  @override
  String developedBy(String name) {
    return 'Developed by $name';
  }

  @override
  String get system => 'System';

  @override
  String get dark => 'Dark';

  @override
  String get light => 'Light';

  @override
  String get later => 'Later';

  @override
  String get updateNow => 'Update Now';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get delete => 'Delete';

  @override
  String get viewDetails => 'View Details';

  @override
  String get clearAll => 'Clear All';

  @override
  String get clearAllHistory => 'Clear All History';

  @override
  String get all => 'All';

  @override
  String get none => 'None';

  @override
  String get confirmDownload => 'Confirm Download';

  @override
  String get downloadNow => 'Download Now';

  @override
  String get selectSource => 'Select Source';

  @override
  String get downloadUnavailable => 'Download Unavailable';

  @override
  String get selectAnotherSource => 'Select Another Source';

  @override
  String get watchHistoryCleared => 'Watch history cleared';

  @override
  String get downloadingUpdate => 'Downloading update...';

  @override
  String errorPrefix(String message) {
    return 'Error: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'Update Available: $tag';
  }

  @override
  String get selectProviderToStart => 'Select a provider to start watching';

  @override
  String get tapExtensionIcon => 'Tap the extension icon in the corner';

  @override
  String get continueWatching => 'Continue Watching';

  @override
  String get noInternetConnection => 'No Internet Connection';

  @override
  String get siteNotReachable => 'Site Not Reachable';

  @override
  String get checkConnectionOrDownloads =>
      'Check your connection or view your downloaded content.';

  @override
  String get tryVpnOrConnection =>
      'Please try accessing the site with a VPN or checking your internet connection.';

  @override
  String errorDetails(String error) {
    return 'Error Details: $error';
  }

  @override
  String get goToDownloads => 'Go to Downloads';

  @override
  String get selectProvider => 'Select Provider';

  @override
  String get searchHint => 'Search movies, series...';

  @override
  String get searchFavoriteContent => 'Search for your favorite content';

  @override
  String get pressSearchOrEnter => 'Press the Search key or Enter to start';

  @override
  String get noResultsFound => 'No results found.';

  @override
  String get couldNotLoadTrending => 'Couldn\'t load trending items';

  @override
  String get popularMovies => 'Popular Movies';

  @override
  String get popularTVShows => 'Popular TV Shows';

  @override
  String get newMovies => 'New Movies';

  @override
  String get newTVShows => 'New TV Shows';

  @override
  String get featuredMovies => 'Featured Movies';

  @override
  String get featuredTVShows => 'Featured TV Shows';

  @override
  String get lastVideosTVShows => 'Last videos TV Shows';

  @override
  String get downloads => 'Downloads';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get noDownloadsYet => 'No downloads yet';

  @override
  String episodesCount(int count, int done) {
    return '$count Episodes • $done Done';
  }

  @override
  String get deleteAllEpisodes => 'Delete All Episodes';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return 'Are you sure you want to delete all $count episodes of \"$title\" and their files?';
  }

  @override
  String get deleteAll => 'Delete All';

  @override
  String get completed => 'Completed';

  @override
  String get statusQueued => 'Queued...';

  @override
  String get statusDownloading => 'Downloading...';

  @override
  String get statusFinished => 'Finished';

  @override
  String get statusFailed => 'Failed';

  @override
  String get statusCanceled => 'Canceled';

  @override
  String get statusPaused => 'Paused';

  @override
  String get statusWaiting => 'Waiting...';

  @override
  String get fileNotFoundRemoving => 'File not found on disk. Removing record.';

  @override
  String get fileNotFound => 'File not found';

  @override
  String get deleteDownload => 'Delete Download';

  @override
  String get confirmDeleteDownload =>
      'Are you sure you want to delete this download and its file?';

  @override
  String get libraryEmpty => 'Your library is empty';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get hindi => 'Hindi (हिंदी)';

  @override
  String get kannada => 'Kannada (ಕನ್ನಡ)';

  @override
  String get unknown => 'Unknown';

  @override
  String get recommended => 'Recommended';

  @override
  String get on => 'On';

  @override
  String get off => 'Off';

  @override
  String get installRemoveProviders => 'Install or remove providers';

  @override
  String get resetDataSubtitle => 'Clear settings & database, keep plugin';

  @override
  String get factoryResetSubtitle =>
      'Delete all data, settings, and extensions';

  @override
  String get developerOptionsSubtitle => 'Debug tools & local play';

  @override
  String get loading => 'Loading...';

  @override
  String get sec => 'sec';

  @override
  String get min => 'min';

  @override
  String get internalPlayer => 'Internal (VLC)';

  @override
  String get builtInPlayer => 'Built-in player';

  @override
  String get customNotSet => 'Custom (not set)';

  @override
  String selectGesture(String side) {
    return 'Select $side Gesture';
  }

  @override
  String get left => 'Left';

  @override
  String get right => 'Right';

  @override
  String get selectSeekDuration => 'Select Seek Duration';

  @override
  String get selectBufferDepth => 'Select Buffer depth';

  @override
  String get subtitleSettings => 'Subtitle Settings';

  @override
  String size(int size) {
    return 'Size: $size';
  }

  @override
  String get background => 'Background';

  @override
  String get customDohUrlLabel => 'Custom DoH URL';

  @override
  String get enterCustomDohUrl => 'Enter your own DoH URL';

  @override
  String get chooseTheme => 'Choose Theme';

  @override
  String get resetDataDialogTitle => 'Reset Data?';

  @override
  String get resetDataDialogContent =>
      'This will clear Settings, Favorites, and History. Your installed Extensions will NOT be deleted.';

  @override
  String get factoryResetDialogTitle => 'Factory Reset?';

  @override
  String get factoryResetDialogContent =>
      'This will delete EVERYTHING: Favorites, History, Settings, and ALL Extensions. This cannot be undone.';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get synopsis => 'Synopsis';

  @override
  String get noDescription => 'No description available.';

  @override
  String get videoAlreadyDownloadedPrompt =>
      'This video is already downloaded. What would you like to do?';

  @override
  String get playNow => 'Play Now';

  @override
  String get upNext => 'Up Next';

  @override
  String get deleteDownloadPrompt => 'Delete Download?';

  @override
  String get deleteDownloadConfirmation =>
      'Are you sure you want to delete this file? This cannot be undone.';

  @override
  String get no => 'No';

  @override
  String get yesDelete => 'Yes, Delete';

  @override
  String get downloadPaused => 'Download Paused';

  @override
  String get downloading => 'Downloading';

  @override
  String get speed => 'Speed';

  @override
  String get remaining => 'Remaining';

  @override
  String get resume => 'Resume';

  @override
  String get pause => 'Pause';

  @override
  String get torrentContent => 'Torrent Content';

  @override
  String get audioTracks => 'Audio Tracks';

  @override
  String get noAudioTracks => 'No audio tracks found';

  @override
  String get subtitles => 'Subtitles';

  @override
  String get options => 'Options';

  @override
  String get noSubtitlesFound => 'No subtitle tracks found';

  @override
  String get playbackSpeed => 'Playback Speed';

  @override
  String get subtitleOptions => 'Subtitle Options';

  @override
  String get hlsSubtitleWarning =>
      'External subtitle files are not supported on the active HLS player on this platform.';

  @override
  String get loadFromDevice => 'Load from Device';

  @override
  String get syncDelay => 'Sync / Delay';

  @override
  String get styleSettings => 'Style Settings';

  @override
  String get searchOnline => 'Search Online (Subtitle Search)';

  @override
  String get subtitleSync => 'Subtitle Sync';

  @override
  String get subtitleDelayWarning =>
      'Subtitle delay is not supported by the active playback engine.';

  @override
  String get resetDelay => 'Reset Delay';

  @override
  String get subtitleStyles => 'Subtitle Styles';

  @override
  String get resetToDefault => 'Reset to Default';

  @override
  String get fontSize => 'Font Size';

  @override
  String get verticalPosition => 'Vertical Position';

  @override
  String get textColor => 'Text Color';

  @override
  String get backgroundColor => 'Background Color';

  @override
  String get backgroundOpacity => 'Background Opacity';

  @override
  String get subtitleSearch => 'Subtitle Search';

  @override
  String get searchSubtitleNameHint => 'Search subtitle name...';

  @override
  String get enterSearchSubtitlePrompt =>
      'Enter a name or search to find subtitles.';

  @override
  String get noSubtitleResults => 'No results found. Try another query.';

  @override
  String get downloadingApplyingSubtitle =>
      'Downloading & applying subtitle...';

  @override
  String get failedToDownloadSubtitle => 'Failed to download subtitle.';

  @override
  String get failedToLoadSubtitles =>
      'Failed to load subtitles. Please try again.';

  @override
  String get noReposFound => 'No repositories or plugins found';

  @override
  String get downloadAllProviders => 'Download All';

  @override
  String get removeRepository => 'Remove Repository';

  @override
  String get addRepo => 'Add Repo';

  @override
  String get extensionsNotInRepos => 'Extensions Not in Repositories';

  @override
  String get noLongerInRepo => 'No longer listed in any repository';

  @override
  String get addRepoToBrowse => 'Add a repository to browse and update plugins';

  @override
  String get debugExtensions => 'Debug Extensions';

  @override
  String removeRepoConfirm(String repoName) {
    return 'Remove $repoName?';
  }

  @override
  String get removeRepoWarning =>
      'This will remove the repository and uninstall ALL its plugin.';

  @override
  String get addRepository => 'Add Repository';

  @override
  String get repoUrlOrShortcode => 'Repository URL or Shortcode';

  @override
  String get assetPlugin => 'Asset Plugin';

  @override
  String get installed => 'Installed';

  @override
  String get repositories => 'Repositories';

  @override
  String get noExtensionsInstalled => 'No Extensions Installed';

  @override
  String get browseRepositoriesToInstall =>
      'Browse the Repositories tab to discover and install extensions.';

  @override
  String get browseRepositories => 'Browse Repositories';

  @override
  String get addRepoDescription =>
      'Add a repository URL or shortcode to discover and install extension plugins.';

  @override
  String updateTo(String version) {
    return 'Update to $version';
  }

  @override
  String get install => 'Install';

  @override
  String get error => 'Error';

  @override
  String get ok => 'OK';

  @override
  String pluginSettings(String pluginName) {
    return '$pluginName Settings';
  }

  @override
  String get movies => 'Movies';

  @override
  String get series => 'Series';

  @override
  String get anime => 'Anime';

  @override
  String get liveStreams => 'Live Streams';

  @override
  String get debug => 'DEBUG';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Updated $count extensions',
      one: 'Updated 1 extension',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => 'Invalid navigation. Please go back.';

  @override
  String get startOver => 'Start Over';

  @override
  String get goBack => 'Go Back';

  @override
  String get resolving => 'Resolving...';

  @override
  String get downloaded => 'Downloaded';

  @override
  String get download => 'Download';

  @override
  String get debugOnlyFeature =>
      'This feature is only available in Debug builds';

  @override
  String get streamUrl => 'Stream URL';

  @override
  String get play => 'Play';

  @override
  String get verifyingSourceSize => 'Verifying source & size...';

  @override
  String get fileSaveLocationNotification =>
      'The file will be saved in your Downloads folder.';

  @override
  String get resumingPlayback => 'Resuming Playback';

  @override
  String pausedAt(String time) {
    return 'Paused at $time';
  }

  @override
  String resumesAutomatically(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Resumes automatically in $count seconds',
      one: 'Resumes automatically in 1 second',
    );
    return '$_temp0';
  }

  @override
  String get resumeNow => 'Resume Now';

  @override
  String get playbackError => 'Playback Error';

  @override
  String get confirmClearHistory =>
      'Are you sure you want to remove all items from your watch history?';

  @override
  String seasonWithNumber(Object number) {
    return 'Season $number';
  }

  @override
  String get starting => 'Starting...';

  @override
  String percentWatched(int percent) {
    return '$percent% watched';
  }

  @override
  String get sub => 'Sub';

  @override
  String get dub => 'Dub';

  @override
  String playEpisode(String label, Object season, Object episode) {
    return '$label S$season E$episode';
  }

  @override
  String playEpisodeOnly(String label, int episode) {
    return '$label E$episode';
  }

  @override
  String get debugTools => 'Debug Tools';

  @override
  String get playLocalVideo => 'Play local video file';

  @override
  String get playLocalVideoSubtitle => 'Play any video from device';

  @override
  String get streamUrlSubtitle => 'Play from network URL';

  @override
  String get streamTorrent => 'Stream torrent';

  @override
  String get streamTorrentSubtitle => 'Select a local torrent file to play';

  @override
  String get loadPluginFromAssets => 'Load plugin from assets';

  @override
  String get enterVideoUrlHint => 'Enter video URL (http, magnet, etc.)';

  @override
  String get networkStream => 'Network Stream';

  @override
  String removedFromHistory(String title) {
    return 'Removed $title from history';
  }

  @override
  String get custom => 'Custom';

  @override
  String get refreshingLiveStream => 'Refreshing live stream...';

  @override
  String get removeFromHistory => 'Remove from History';

  @override
  String get live => 'LIVE';

  @override
  String get volume => 'Volume';

  @override
  String get brightness => 'Brightness';

  @override
  String get fit => 'Fit';

  @override
  String get zoom => 'Zoom';

  @override
  String get stretch => 'Stretch';

  @override
  String titleWithParam(String title) {
    return 'Title: $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'Source: $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'Size: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'Error: $error. Using internal player.';
  }

  @override
  String playerNotDetected(String playerName) {
    return '$playerName not detected. Starting internal player.';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return 'Season $number ($count Episodes)';
  }

  @override
  String get cloudflare => 'Cloudflare';

  @override
  String get google => 'Google';

  @override
  String get adguard => 'AdGuard';

  @override
  String get dnsWatch => 'DNS.Watch';

  @override
  String get quad9 => 'Quad9';

  @override
  String get dnsSb => 'DNS.SB';

  @override
  String get canadianShield => 'Canadian Shield';

  @override
  String get tmdb => 'TMDB';

  @override
  String selectSourceForPlayer(String playerName) {
    return 'Select Source for $playerName';
  }

  @override
  String get noPluginsInstalled => 'No plugins installed';

  @override
  String get noPluginsMessage =>
      'Install extensions to browse and stream content.';

  @override
  String get goToExtensions => 'Go to Extensions';

  @override
  String get availableSources => 'Available Sources';

  @override
  String get seasons => 'Seasons';

  @override
  String get episodes => 'Episodes';

  @override
  String get selectSourceToPlay =>
      'Please select a source from \'Available Sources\' above to play.';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Episodes',
      one: '1 Episode',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'No episodes found';

  @override
  String get local => 'Local';

  @override
  String get remote => 'Remote';

  @override
  String get torrent => 'Torrent';

  @override
  String get unlock => 'Unlock';

  @override
  String get lock => 'Lock';

  @override
  String get sources => 'Sources';

  @override
  String get tracks => 'Tracks';

  @override
  String get content => 'Content';

  @override
  String get stats => 'Stats';

  @override
  String get resize => 'Resize';

  @override
  String get next => 'Next';

  @override
  String get pip => 'PiP';

  @override
  String get rotate => 'Rotate';

  @override
  String get windowed => 'Windowed';

  @override
  String get fullscreen => 'Fullscreen';

  @override
  String get movieDetails => 'Movie Details';

  @override
  String get showDetails => 'Show Details';

  @override
  String get tagline => 'Tagline';

  @override
  String get status => 'Status';

  @override
  String get releaseDate => 'Release Date';

  @override
  String get firstAirDate => 'First Air Date';

  @override
  String get originalLanguage => 'Original Language';

  @override
  String get originCountry => 'Origin Country';

  @override
  String get budgetLabel => 'Budget';

  @override
  String get revenueLabel => 'Revenue';

  @override
  String get paused => 'Paused';

  @override
  String get watched => 'Watched';

  @override
  String get watching => 'Watching';

  @override
  String get lastWatched => 'Last Watched';

  @override
  String get movie => 'Movie';

  @override
  String get tvShow => 'TV Show';

  @override
  String get failedToLoadContent => 'Failed to load content';

  @override
  String get director => 'Director';

  @override
  String get creator => 'Creator';

  @override
  String get showMore => 'Show More';

  @override
  String get showLess => 'Show Less';

  @override
  String get viewAll => 'View All';

  @override
  String seasonsCount(int count) {
    return '$count Seasons';
  }

  @override
  String get noInternetError => 'No internet connection';

  @override
  String get timeoutError => 'Request timed out. Please try again.';

  @override
  String get serverError => 'Server error. Please try again later.';

  @override
  String get contentNotFoundError => 'Content not found.';

  @override
  String get accessDeniedError => 'Access denied. Check your credentials.';

  @override
  String get serviceUnavailableError =>
      'Server is unavailable. Try again later.';

  @override
  String get generalError => 'Something went wrong. Please try again.';

  @override
  String get skip => 'Skip';

  @override
  String get skipIntro => 'Skip Intro';

  @override
  String get skipOutro => 'Skip Outro';

  @override
  String get skipRecap => 'Skip Recap';

  @override
  String get goLive => 'Go Live';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get nextUp => 'Next Up';

  @override
  String sourceAttempt(int index, int total) {
    return 'Source $index of $total';
  }

  @override
  String get trying => 'Trying';

  @override
  String get failed => 'Failed';

  @override
  String get selected => 'Selected';

  @override
  String get playing => 'Playing';

  @override
  String get pending => 'Pending';

  @override
  String get openSubtitles => 'OpenSubtitles';

  @override
  String get subDl => 'SubDL';

  @override
  String get subSource => 'SubSource';

  @override
  String get wifiQualityPreference => 'Wi-Fi Quality Preference';

  @override
  String get mobileQualityPreference => 'Mobile Quality Preference';

  @override
  String get anyNoPreference => 'Any (no preference)';

  @override
  String get subtitleAccounts => 'Subtitle Accounts';

  @override
  String get accounts => 'Accounts';

  @override
  String get notLoggedIn => 'Not logged in';

  @override
  String loggedInAs(String username) {
    return 'Logged in as $username';
  }

  @override
  String get apiKeyConfigured => 'API Key configured';

  @override
  String get keyNotSet => 'Key not set';

  @override
  String get testConnection => 'Test Connection';

  @override
  String get connectedSuccessfully => 'Connected Successfully';

  @override
  String get connectionFailed => 'Connection Failed';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get noAccountRegister => 'Don\'t have an account? Register here';

  @override
  String get apiKey => 'API Key';

  @override
  String get email => 'Email';

  @override
  String get fetchMyApiKey => 'Fetch My API Key';

  @override
  String get keyVerified => 'Key Verified';

  @override
  String get invalidApiKey => 'Invalid API Key';

  @override
  String get openSubtitlesAuthSubtitle =>
      'Enter your account credentials for higher limits and ad-free subtitles.';

  @override
  String get subDlAuthSubtitle =>
      'Enter your SubDL API Key directly, or fetch it using your account credentials below.';

  @override
  String get orFetchViaAccount => 'OR FETCH VIA ACCOUNT';

  @override
  String get subSourceAuthSubtitle =>
      'SubSource works out-of-the-box, but you can add a personal official API key to override the default for better reliability.';

  @override
  String get apiKeyOptionalOverride => 'API Key (Optional Override)';

  @override
  String get enterKeyToOverrideDefault => 'Enter key to override default';

  @override
  String get getApiKeyFromProfile => 'Get your API Key from SubSource Profile';

  @override
  String get qualityNotGuaranteed =>
      'Quality is not guaranteed. Sources are sorted by preference, but playback depends on what the provider actually offers.';

  @override
  String get keepSourcesOriginalOrder => 'Keep sources in original order';

  @override
  String get openLink => 'Open link';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get viewLogs => 'View Logs';

  @override
  String get viewLogsSubtitle => 'View application activity & errors';

  @override
  String get clearCache => 'Clear image and video cache';

  @override
  String get clearCacheSubtitle =>
      'Frees up storage used by cached images and videos';

  @override
  String get clearCacheDialogTitle => 'Clear cache?';

  @override
  String get clearCacheDialogContent =>
      'This will delete cached images and video files. Your settings, history, and extensions will not be affected.';

  @override
  String get clearCacheNow => 'Clear Cache';

  @override
  String get cacheCleared => 'Cache cleared';

  @override
  String get calculating => 'Calculating…';

  @override
  String get playerControls => 'Player Controls';

  @override
  String get playerControlsSubtitle => 'Show or hide player control buttons';

  @override
  String get showPip => 'Picture-in-Picture button';

  @override
  String get showResize => 'Resize button';

  @override
  String get showRotate => 'Rotate button';

  @override
  String get showPlaybackSpeed => 'Playback speed button';

  @override
  String get showEpisodes => 'Episodes button';
}
