// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => 'Polski';

  @override
  String get addonHealthChecking => 'Checking add-on…';

  @override
  String addonHealthWorking(int ms) {
    return 'Working · $ms ms';
  }

  @override
  String get addonHealthUnavailable => 'Unavailable';

  @override
  String get home => 'Główna';

  @override
  String get search => 'Szukaj';

  @override
  String get explore => 'Eksploruj';

  @override
  String get exploreAnime => 'Przeglądaj anime';

  @override
  String get exploreMovies => 'Przeglądaj filmy';

  @override
  String get library => 'Biblioteka';

  @override
  String get settings => 'Ustawienia';

  @override
  String get extensions => 'Rozszerzenia';

  @override
  String get updateAvailable => 'Dostępna aktualizacja';

  @override
  String get retry => 'Ponów';

  @override
  String get factoryReset => 'Przywracanie ustawień fabrycznych';

  @override
  String get startupError => 'Błąd uruchamiania';

  @override
  String get general => 'Ogólne';

  @override
  String get appTheme => 'Motyw aplikacji';

  @override
  String get recordWatchHistory => 'Zapisuj historię oglądania';

  @override
  String get fullScreenMode => 'Pełny ekran';

  @override
  String get fullScreenModeSubtitle => 'Przełącza na interfejs telewizyjny';

  @override
  String get defaultHomeScreen => 'Domyślny ekran główny';

  @override
  String get titlePosition => 'Pozycja tytułu';

  @override
  String get titlePositionBelowPoster => 'Pod plakatem';

  @override
  String get titlePositionInsidePoster => 'Na plakacie';

  @override
  String get player => 'Odtwarzacz';

  @override
  String get defaultPlayer => 'Domyślny odtwarzacz';

  @override
  String get leftGesture => 'Gest lewy';

  @override
  String get rightGesture => 'Gest prawy';

  @override
  String get doubleTapToSeek => 'Podwójne dotknięcie, aby przewinąć';

  @override
  String get swipeToSeek => 'Przesunięcie, aby przewinąć';

  @override
  String get seekDuration => 'Czas przewijania';

  @override
  String get defaultResizeMode => 'Domyślny tryb zmiany rozmiaru';

  @override
  String get hardwareDecoding => 'Dekodowanie sprzętowe';

  @override
  String get network => 'Sieć';

  @override
  String get dnsOverHttps => 'DNS przez HTTPS';

  @override
  String get dohProvider => 'Dostawca DoH';

  @override
  String get githubProxy => 'Proxy GitHuba';

  @override
  String get githubProxySubtitle =>
      'Kieruj pobieranie rozszerzeń przez jsDelivr, aby ominąć blokady dostawcy internetu.';

  @override
  String get manageExtensions => 'Zarządzaj rozszerzeniami';

  @override
  String get appData => 'Dane aplikacji';

  @override
  String get resetDataKeepExtensions => 'Resetuj dane (zachowaj rozszerzenia)';

  @override
  String get developer => 'Deweloper';

  @override
  String get developerOptions => 'Opcje programistyczne';

  @override
  String get about => 'O aplikacji';

  @override
  String get version => 'Wersja';

  @override
  String get enabled => 'Włączone';

  @override
  String get disabled => 'Wyłączone';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'Dołącz do naszego serwera';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'Dołącz do naszego kanału';

  @override
  String developedBy(String name) {
    return 'Developed by $name';
  }

  @override
  String get system => 'Systemowy';

  @override
  String get dark => 'Ciemny';

  @override
  String get light => 'Jasny';

  @override
  String get later => 'Później';

  @override
  String get updateNow => 'Aktualizuj teraz';

  @override
  String get save => 'Zapisz';

  @override
  String get cancel => 'Anuluj';

  @override
  String get close => 'Zamknij';

  @override
  String get delete => 'Usuń';

  @override
  String get viewDetails => 'Pokaż szczegóły';

  @override
  String get clearAll => 'Wyczyść wszystko';

  @override
  String get clearAllHistory => 'Wyczyść historię';

  @override
  String get all => 'Wszystkie';

  @override
  String get none => 'Brak';

  @override
  String get confirmDownload => 'Potwierdź pobieranie';

  @override
  String get downloadNow => 'Pobierz teraz';

  @override
  String get selectSource => 'Wybierz źródło';

  @override
  String get downloadUnavailable => 'Niedostępne';

  @override
  String get selectAnotherSource => 'Wybierz inne';

  @override
  String get watchHistoryCleared => 'Historia oglądania wyczyszczona';

  @override
  String get downloadingUpdate => 'Pobieranie aktualizacji...';

  @override
  String errorPrefix(String message) {
    return 'Błąd: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'Dostępna aktualizacja: $tag';
  }

  @override
  String get selectProviderToStart => 'Wybierz dostawcę, aby rozpocząć';

  @override
  String get tapExtensionIcon => 'Dotknij ikony rozszerzenia w rogu';

  @override
  String get continueWatching => 'Kontynuuj oglądanie';

  @override
  String get noInternetConnection => 'Brak połączenia z Internetem';

  @override
  String get siteNotReachable => 'Strona nieosiągalna';

  @override
  String get checkConnectionOrDownloads =>
      'Sprawdź połączenie lub zobacz pobrane pliki.';

  @override
  String get tryVpnOrConnection => 'Spróbuj użyć VPN lub sprawdź połączenie.';

  @override
  String errorDetails(String error) {
    return 'Szczegóły błędu: $error';
  }

  @override
  String get goToDownloads => 'Idź do pobranych';

  @override
  String get selectProvider => 'Wybierz dostawcę';

  @override
  String get searchHint => 'Szukaj filmów, seriali...';

  @override
  String get searchFavoriteContent => 'Szukaj ulubionych treści';

  @override
  String get pressSearchOrEnter => 'Naciśnij Szukaj lub Enter, aby zacząć';

  @override
  String get recentSearches => 'Recent searches';

  @override
  String removeFromSearchHistory(String query) {
    return 'Remove $query from search history';
  }

  @override
  String get noResultsFound => 'Nie znaleziono wyników.';

  @override
  String get couldNotLoadTrending => 'Nie udało się załadować trendów';

  @override
  String get popularMovies => 'Popularne filmy';

  @override
  String get popularTVShows => 'Popularne seriale';

  @override
  String get newMovies => 'Nowe filmy';

  @override
  String get newTVShows => 'Nowe seriale';

  @override
  String get featuredMovies => 'Polecane filmy';

  @override
  String get featuredTVShows => 'Polecane seriale';

  @override
  String get lastVideosTVShows => 'Ostatnie wideo';

  @override
  String get downloads => 'Pobrane';

  @override
  String get bookmarks => 'Zakładki';

  @override
  String get noDownloadsYet => 'Brak pobranych plików';

  @override
  String episodesCount(int count, int done) {
    return '$count odcinków • $done obejrzanych';
  }

  @override
  String get deleteAllEpisodes => 'Usuń wszystkie odcinki';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return 'Czy na pewno chcesz usunąć wszystkie $count odcinki serialu \"$title\" wraz z plikami?';
  }

  @override
  String get deleteAll => 'Usuń wszystko';

  @override
  String get completed => 'Zakończono';

  @override
  String get statusQueued => 'W kolejce...';

  @override
  String get statusDownloading => 'Pobieranie...';

  @override
  String get statusFinished => 'Zakończono';

  @override
  String get statusFailed => 'Niepowodzenie';

  @override
  String get statusCanceled => 'Anulowano';

  @override
  String get statusPaused => 'Wstrzymano';

  @override
  String get statusWaiting => 'Oczekiwanie...';

  @override
  String get fileNotFoundRemoving => 'Nie znaleziono pliku. Usuwanie wpisu.';

  @override
  String get fileNotFound => 'Nie znaleziono pliku';

  @override
  String get deleteDownload => 'Usuń pobrany plik';

  @override
  String get confirmDeleteDownload => 'Czy na pewno chcesz usunąć ten plik?';

  @override
  String get libraryEmpty => 'Twoja biblioteka jest pusta';

  @override
  String get language => 'Język';

  @override
  String get english => 'Angielski';

  @override
  String get hindi => 'Hindi';

  @override
  String get kannada => 'Kannada';

  @override
  String get unknown => 'Nieznany';

  @override
  String get recommended => 'Polecane';

  @override
  String get on => 'Wł.';

  @override
  String get off => 'Wył.';

  @override
  String get installRemoveProviders => 'Instaluj/usuń dostawców';

  @override
  String get resetDataSubtitle => 'Wyczyść ustawienia i bazę, zachowaj wtyczki';

  @override
  String get factoryResetSubtitle =>
      'Usuń wszystkie dane, ustawienia i rozszerzenia';

  @override
  String get developerOptionsSubtitle => 'Narzędzia programistyczne';

  @override
  String get loading => 'Ładowanie...';

  @override
  String get sec => 'sek';

  @override
  String get min => 'min';

  @override
  String playerRewindSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Do tyłu o $count sekundy',
      many: 'Do tyłu o $count sekund',
      few: 'Do tyłu o $count sekundy',
      one: 'Do tyłu o $count sekundę',
    );
    return '$_temp0';
  }

  @override
  String playerForwardSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Do przodu o $count sekundy',
      many: 'Do przodu o $count sekund',
      few: 'Do przodu o $count sekundy',
      one: 'Do przodu o $count sekundę',
    );
    return '$_temp0';
  }

  @override
  String get internalPlayer => 'Wewnętrzny (VLC)';

  @override
  String get builtInPlayer => 'Wbudowany odtwarzacz';

  @override
  String get customNotSet => 'Własny (nieustawiony)';

  @override
  String selectGesture(String side) {
    return 'Wybierz gest ($side)';
  }

  @override
  String get left => 'lewy';

  @override
  String get right => 'prawy';

  @override
  String get selectSeekDuration => 'Wybierz czas przewijania';

  @override
  String get subtitleSettings => 'Ustawienia napisów';

  @override
  String size(int size) {
    return 'Rozmiar: $size';
  }

  @override
  String get background => 'Tło';

  @override
  String get customDohUrlLabel => 'Własny URL DoH';

  @override
  String get enterCustomDohUrl => 'Wprowadź własny URL DoH';

  @override
  String get chooseTheme => 'Wybierz motyw';

  @override
  String get resetDataDialogTitle => 'Resetować dane?';

  @override
  String get resetDataDialogContent =>
      'To wyczyści Ustawienia, Ulubione i Historię. Rozszerzenia NIE zostaną usunięte.';

  @override
  String get factoryResetDialogTitle => 'Reset fabryczny?';

  @override
  String get factoryResetDialogContent =>
      'To usunie WSZYSTKO. Tej operacji nie można cofnąć.';

  @override
  String get selectLanguage => 'Wybierz język';

  @override
  String get synopsis => 'Opis';

  @override
  String get noDescription => 'Brak opisu.';

  @override
  String get videoAlreadyDownloadedPrompt =>
      'To wideo zostało już pobrane. Co chcesz zrobić?';

  @override
  String get playNow => 'Odtwórz teraz';

  @override
  String get upNext => 'Dalej';

  @override
  String get deleteDownloadPrompt => 'Usunąć pobrany plik?';

  @override
  String get deleteDownloadConfirmation =>
      'Czy na pewno? Usunięcie pliku jest nieodwracalne.';

  @override
  String get no => 'Nie';

  @override
  String get yesDelete => 'Tak, usuń';

  @override
  String get downloadPaused => 'Pobieranie wstrzymane';

  @override
  String get downloading => 'Pobieranie';

  @override
  String get speed => 'Prędkość';

  @override
  String get remaining => 'Pozostało';

  @override
  String get resume => 'Wznów';

  @override
  String get pause => 'Pauza';

  @override
  String get torrentContent => 'Treść torrenta';

  @override
  String get audioTracks => 'Ścieżki dźwiękowe';

  @override
  String get noAudioTracks => 'Nie znaleziono ścieżek dźwiękowych';

  @override
  String get subtitles => 'Napisy';

  @override
  String get options => 'Opcje';

  @override
  String get noSubtitlesFound => 'Nie znaleziono napisów';

  @override
  String get playbackSpeed => 'Prędkość odtwarzania';

  @override
  String get subtitleOptions => 'Opcje napisów';

  @override
  String get hlsSubtitleWarning =>
      'Zewnętrzne napisy nie są obsługiwane dla HLS na tej platformie.';

  @override
  String get loadFromDevice => 'Wczytaj z urządzenia';

  @override
  String get syncDelay => 'Synchronizacja / Opóźnienie';

  @override
  String get styleSettings => 'Ustawienia stylu';

  @override
  String get searchOnline => 'Szukaj online';

  @override
  String get subtitleSync => 'Synch. napisów';

  @override
  String get subtitleDelayWarning =>
      'Opóźnienie napisów nie jest obsługiwane przez obecny odtwarzacz.';

  @override
  String get resetDelay => 'Resetuj opóźnienie';

  @override
  String get subtitleStyles => 'Style napisów';

  @override
  String get resetToDefault => 'Domyślne';

  @override
  String get fontSize => 'Rozmiar czcionki';

  @override
  String get verticalPosition => 'Pozycja pionowa';

  @override
  String get textColor => 'Kolor tekstu';

  @override
  String get backgroundColor => 'Kolor tła';

  @override
  String get backgroundOpacity => 'Przezroczystość tła';

  @override
  String get subtitleSearch => 'Szukaj napisów';

  @override
  String get searchSubtitleNameHint => 'Nazwa napisów...';

  @override
  String get enterSearchSubtitlePrompt => 'Wprowadź nazwę, aby szukać napisów.';

  @override
  String get noSubtitleResults => 'Brak wyników.';

  @override
  String get downloadingApplyingSubtitle => 'Pobieranie i nakładanie...';

  @override
  String get failedToDownloadSubtitle => 'Błąd pobierania napisów.';

  @override
  String get failedToLoadSubtitles => 'Błąd wczytywania napisów.';

  @override
  String get noReposFound => 'Nie znaleziono repozytoriów';

  @override
  String get downloadAllProviders => 'Pobierz wszystko';

  @override
  String get removeRepository => 'Usuń repozytorium';

  @override
  String get addRepo => 'Dodaj repozytorium';

  @override
  String get extensionsNotInRepos => 'Rozszerzenia spoza repo';

  @override
  String get noLongerInRepo => 'Nie ma już na liście';

  @override
  String get addRepoToBrowse => 'Dodaj repozytorium, aby przeglądać';

  @override
  String get debugExtensions => 'Debugowanie rozszerzeń';

  @override
  String removeRepoConfirm(String repoName) {
    return 'Usunąć $repoName?';
  }

  @override
  String get removeRepoWarning =>
      'To usunie repozytorium i wszystkie jego wtyczki.';

  @override
  String get addRepository => 'Dodaj repozytorium';

  @override
  String get repoUrlOrShortcode => 'URL lub krótki kod';

  @override
  String get assetPlugin => 'Wtyczka wbudowana';

  @override
  String get installed => 'Zainstalowano';

  @override
  String get repositories => 'Repozytoria';

  @override
  String get noExtensionsInstalled => 'Brak zainstalowanych rozszerzeń';

  @override
  String get browseRepositoriesToInstall =>
      'Otwórz kartę Repozytoria, aby znaleźć i zainstalować rozszerzenia.';

  @override
  String get browseRepositories => 'Przeglądaj repozytoria';

  @override
  String get addRepoDescription =>
      'Dodaj adres URL repozytorium lub krótki kod, aby znaleźć i zainstalować wtyczki rozszerzeń.';

  @override
  String updateTo(String version) {
    return 'Aktualizuj do $version';
  }

  @override
  String get install => 'Instaluj';

  @override
  String get discoverSearchHint => 'Search community add-ons';

  @override
  String get discoverClearSearch => 'Clear';

  @override
  String get discoverNeedsWebSetup =>
      'Needs quick setup on the add-on\'s website';

  @override
  String get discoverOpenSetup => 'Set up on the add-on website';

  @override
  String get error => 'Błąd';

  @override
  String get ok => 'OK';

  @override
  String pluginSettings(String pluginName) {
    return 'Ustawienia $pluginName';
  }

  @override
  String get movies => 'Filmy';

  @override
  String get series => 'Seriale';

  @override
  String get anime => 'Anime';

  @override
  String get liveStreams => 'Na żywo';

  @override
  String get debug => 'DEBUG';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rozszerzeń zaktualizowanych',
      many: '$count rozszerzeń zaktualizowanych',
      few: '$count rozszerzenia zaktualizowane',
      one: '1 rozszerzenie zaktualizowane',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => 'Nieprawidłowa nawigacja.';

  @override
  String get startOver => 'Zacznij od nowa';

  @override
  String get goBack => 'Wstecz';

  @override
  String get restartApp => 'Uruchom ponownie aplikację';

  @override
  String get resolving => 'Rozwiązywanie...';

  @override
  String get downloaded => 'Pobrano';

  @override
  String get download => 'Pobierz';

  @override
  String get debugOnlyFeature => 'Tylko dla wersji debug';

  @override
  String get streamUrl => 'URL strumienia';

  @override
  String get play => 'Odtwórz';

  @override
  String get verifyingSourceSize => 'Weryfikacja...';

  @override
  String get fileSaveLocationNotification =>
      'Plik zostanie zapisany w folderze Pobrane.';

  @override
  String get resumingPlayback => 'Wznawianie';

  @override
  String pausedAt(String time) {
    return 'Wstrzymano na $time';
  }

  @override
  String resumesAutomatically(int count) {
    return 'Automatycznie za $count sek';
  }

  @override
  String get resumeNow => 'Wznów teraz';

  @override
  String get playbackError => 'Błąd odtwarzania';

  @override
  String get confirmClearHistory => 'Wyczuścić historię?';

  @override
  String seasonWithNumber(Object number) {
    return 'Sezon $number';
  }

  @override
  String get starting => 'Uruchamianie...';

  @override
  String percentWatched(int percent) {
    return '$percent% obejrzano';
  }

  @override
  String get sub => 'Nap';

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
  String get debugTools => 'Narzędzia debugowania';

  @override
  String get playLocalVideo => 'Lokalne wideo';

  @override
  String get playLocalVideoSubtitle => 'Odtwórz plik z urządzenia';

  @override
  String get streamUrlSubtitle => 'Odtwórz z URL';

  @override
  String get streamTorrent => 'Strumień torrent';

  @override
  String get streamTorrentSubtitle => 'Wybierz plik torrent';

  @override
  String get loadPluginFromAssets => 'Wczytaj z zasobów';

  @override
  String get enterVideoUrlHint => 'URL wideo';

  @override
  String get networkStream => 'Strumień sieciowy';

  @override
  String removedFromHistory(String title) {
    return 'Usunięto: $title';
  }

  @override
  String get custom => 'Własne';

  @override
  String get refreshingLiveStream => 'Odświeżanie...';

  @override
  String get removeFromHistory => 'Usuń z historii';

  @override
  String get live => 'NA ŻYWO';

  @override
  String get volume => 'Głośność';

  @override
  String get decrease => 'Decrease';

  @override
  String get increase => 'Increase';

  @override
  String get brightness => 'Jasność';

  @override
  String get fit => 'Dopasuj';

  @override
  String get zoom => 'Powiększ';

  @override
  String get stretch => 'Rozciągnij';

  @override
  String titleWithParam(String title) {
    return 'Tytuł: $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'Źródło: $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'Rozmiar: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'Błąd: $error. Odtwarzacz wewnętrzny.';
  }

  @override
  String externalPlayerCannotSendHeaders(String playerName, String headers) {
    return '$playerName cannot send $headers. Using internal player.';
  }

  @override
  String playerNotDetected(String playerName) {
    return '$playerName nie został znaleziony.';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return 'Sezon $number ($count odc.)';
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
    return 'Źródło dla $playerName';
  }

  @override
  String get noPluginsInstalled => 'Brak zainstalowanych wtyczek';

  @override
  String get noPluginsMessage =>
      'Zainstaluj rozszerzenia, aby przeglądać i przesyłać strumieniowo treści.';

  @override
  String get goToExtensions => 'Przejdź do rozszerzeń';

  @override
  String get availableSources => 'Dostępne źródła';

  @override
  String get seasons => 'Sezony';

  @override
  String get episodes => 'Odcinki';

  @override
  String get selectSourceToPlay => 'Wybierz źródło, aby odtworzyć.';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count odcinków',
      many: '$count odcinków',
      few: '$count odcinki',
      one: '1 odcinek',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'Brak odcinków';

  @override
  String get local => 'Lokalne';

  @override
  String get remote => 'Zdalne';

  @override
  String get torrent => 'Torrent';

  @override
  String get unlock => 'Odblokuj';

  @override
  String get lock => 'Zablokuj';

  @override
  String get sources => 'Źródła';

  @override
  String get tracks => 'Ścieżki';

  @override
  String get content => 'Treść';

  @override
  String get stats => 'Statystyki';

  @override
  String get resize => 'Rozmiar';

  @override
  String get next => 'Następny';

  @override
  String get previous => 'Previous';

  @override
  String get pip => 'PiP';

  @override
  String get rotate => 'Obróć';

  @override
  String get windowed => 'Okno';

  @override
  String get fullscreen => 'Pełny ekran';

  @override
  String get movieDetails => 'Szczegóły';

  @override
  String get showDetails => 'Pokaż szczegóły';

  @override
  String get tagline => 'Hasło';

  @override
  String get status => 'Status';

  @override
  String get releaseDate => 'Data wydania';

  @override
  String get firstAirDate => 'Data pierwszej emisji';

  @override
  String get originalLanguage => 'Język oryginalny';

  @override
  String get originCountry => 'Kraj pochodzenia';

  @override
  String get budgetLabel => 'Budżet';

  @override
  String get revenueLabel => ' Przychód';

  @override
  String get paused => 'Wstrzymano';

  @override
  String get watched => 'Obejrzano';

  @override
  String get watching => 'Oglądane';

  @override
  String get lastWatched => 'Ostatnio';

  @override
  String get movie => 'Film';

  @override
  String get tvShow => 'Serial';

  @override
  String get failedToLoadContent => 'Błąd ładowania';

  @override
  String get director => 'Reżyser';

  @override
  String get creator => 'Twórca';

  @override
  String get showMore => 'Więcej';

  @override
  String get showLess => 'Mniej';

  @override
  String get viewAll => 'Wszystkie';

  @override
  String seasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sezonów',
      many: '$count sezonów',
      few: '$count sezony',
      one: '1 sezon',
    );
    return '$_temp0';
  }

  @override
  String get noInternetError => 'Brak Internetu';

  @override
  String get timeoutError => 'Upłynął czas.';

  @override
  String get serverError => 'Błąd serwera.';

  @override
  String get contentNotFoundError => 'Nie znaleziono.';

  @override
  String get accessDeniedError => 'Odmowa dostępu.';

  @override
  String get serviceUnavailableError => 'Usługa niedostępna.';

  @override
  String get generalError => 'Błąd.';

  @override
  String get skip => 'Pomiń';

  @override
  String get skipIntro => 'Pomiń intro';

  @override
  String get skipOutro => 'Pomiń napisy';

  @override
  String get skipRecap => 'Pomiń streszczenie';

  @override
  String get goLive => 'Na żywo';

  @override
  String get dismiss => 'Zamknij';

  @override
  String get nextUp => 'Następnie';

  @override
  String sourceAttempt(int index, int total) {
    return 'Próba $index z $total';
  }

  @override
  String get trying => 'Próba';

  @override
  String get failed => 'Nieudane';

  @override
  String get selected => 'Wybrano';

  @override
  String get playing => 'Odtwarzanie';

  @override
  String get pending => 'Oczekiwanie';

  @override
  String get openSubtitles => 'OpenSubtitles';

  @override
  String get subDl => 'SubDL';

  @override
  String get subSource => 'SubSource';

  @override
  String get unmeteredQualityPreference => 'Wi-Fi & Wired Quality Preference';

  @override
  String get playerNotOnThisDevice => 'Not offered on this device';

  @override
  String get mobileQualityPreference => 'Preferencja jakości mobilnej';

  @override
  String get anyNoPreference => 'Bez preferencji';

  @override
  String get subtitleAccounts => 'Konta napisów';

  @override
  String get accounts => 'Konta';

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
  String get testConnection => 'Testuj połączenie';

  @override
  String get connectedSuccessfully => 'Połączono pomyślnie';

  @override
  String get connectionFailed => 'Połączenie nieudane';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get noAccountRegister => 'Don\'t have an account? Register here';

  @override
  String get apiKey => 'Klucz API';

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
  String get diagnostics => 'Diagnostyka';

  @override
  String get viewLogs => 'Zobacz logi';

  @override
  String get viewLogsSubtitle => 'Zobacz aktywność aplikacji i błędy';

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
  String get showPlaybackSpeed => 'Playback speed button';

  @override
  String get showEpisodes => 'Episodes button';

  @override
  String get playerNoProviderSelected => 'No provider selected.';

  @override
  String get playerNothingToPlay => 'Nothing to play.';

  @override
  String playerCouldNotLoadSources(String error) {
    return 'Could not load sources: $error';
  }

  @override
  String get playerResolutionCancelled => 'Cancelled.';

  @override
  String get playerNoStreamsFound => 'No streams found.';

  @override
  String get playerDrmWidevine =>
      'This channel uses Widevine DRM, which needs a licence module this player does not have.';

  @override
  String get playerDrmPlayReady =>
      'This channel uses PlayReady DRM, which needs a licence module this player does not have.';

  @override
  String get playerDrmLicenceServer =>
      'This channel needs a decryption key from a licence server, and the server did not provide a usable one.';

  @override
  String get playerDrmUnknown =>
      'This channel is encrypted and no usable decryption key was provided.';

  @override
  String playerPlaybackFailed(String error) {
    return 'Playback failed: $error';
  }

  @override
  String playerNoSourcesPlayable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'None of the $count sources would play.',
      one: 'The only source would not play.',
    );
    return '$_temp0';
  }

  @override
  String playerNoSourcesPlayableWithReason(int count, String reason) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'None of the $count sources would play - $reason',
      one: 'The only source would not play - $reason',
    );
    return '$_temp0';
  }

  @override
  String get playerPreparingTorrent => 'Preparing torrent…';

  @override
  String get playerReasonTorrentNotPrepared => 'torrent could not be prepared';

  @override
  String get playerReasonNoPlayableAddress => 'source has no playable address';

  @override
  String get playerReasonLiveFeedDropped => 'live feed dropped repeatedly';

  @override
  String get playerReasonStreamEndedEarly => 'stream ended before its duration';

  @override
  String get playerReasonPlaybackError => 'playback error';

  @override
  String get playerReasonSourceStoppedResponding =>
      'the source stopped responding';

  @override
  String get playerReasonSourceNeverStarted => 'the source never started';

  @override
  String get playerReasonNetworkDropped => 'the network dropped';

  @override
  String get playerReasonSkipped => 'you skipped this source';

  @override
  String get playerSkipSource => 'Skip source';

  @override
  String get playerSourceReachable => 'Reachable';

  @override
  String get playerReasonStreamEndedBeforePlaying =>
      'stream ended before it played';

  @override
  String playerFinished(String title) {
    return 'You\'ve finished $title';
  }

  @override
  String get playerReconnecting => 'Reconnecting…';

  @override
  String get playerSpeedNormal => 'Normal';

  @override
  String get torrentStats => 'Torrent stats';

  @override
  String get original => 'Original';

  @override
  String playerCouldNotReadTracks(String error) {
    return 'Could not read tracks: $error';
  }

  @override
  String playerTrackNumber(int id) {
    return 'Track $id';
  }

  @override
  String get subtitleDelay => 'Subtitle delay';

  @override
  String get playerSourceRestoredPrevious =>
      'That source would not play. Restored the previous one.';

  @override
  String get playerTorrentFileNotReady =>
      'That file is not ready to stream yet.';

  @override
  String get torrentFiles => 'Torrent files';

  @override
  String get audio => 'Audio';

  @override
  String get noAudioTracksReported => 'No audio tracks reported';

  @override
  String get loadSubtitleFile => 'Load subtitle file';

  @override
  String get searchSubtitlesOnline => 'Search online';

  @override
  String get searchOnlineSubtitles => 'Search online subtitles';

  @override
  String get subtitleLanguage => 'Subtitle language';

  @override
  String get subtitleDownloadFailed =>
      'That subtitle could not be downloaded. Try another result.';

  @override
  String subtitleSearchFailed(String error) {
    return 'Search failed: $error';
  }

  @override
  String get subtitleSearchPrompt =>
      'Search for a title to find subtitles for it.';

  @override
  String get noSubtitlesFoundTryAnother =>
      'No subtitles found. Try a different title or language.';

  @override
  String get seedsPeers => 'Seeds / Peers';

  @override
  String get subtitleAppearanceNote =>
      'The engine draws subtitles, so it is handed these when playback starts — a change applies to the next video.';

  @override
  String get textSize => 'Text size';

  @override
  String get subtitleTextColour => 'Text colour';

  @override
  String get resetSubtitleAppearance => 'Reset subtitle appearance';

  @override
  String get resetSubtitleAppearanceSubtitle => 'Back to white text at size 22';

  @override
  String get subtitlePreviewSample => 'The quick brown fox';

  @override
  String subtitleBackgroundSummary(String color, int percent) {
    return '$color · $percent%';
  }

  @override
  String get opacityOff => 'Opacity: off';

  @override
  String opacityPercent(int percent) {
    return 'Opacity: $percent%';
  }

  @override
  String get colorWhite => 'White';

  @override
  String get colorYellow => 'Yellow';

  @override
  String get colorCyan => 'Cyan';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorMagenta => 'Magenta';

  @override
  String get colorRed => 'Red';

  @override
  String get colorBlack => 'Black';

  @override
  String get colorDarkGrey => 'Dark grey';

  @override
  String get playerNowPlaying => 'Now playing';

  @override
  String get playerQualityFilterDropped =>
      'Nothing matched your quality preference, so every source is listed.';

  @override
  String playerSeeders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seeders',
      one: '1 seeder',
    );
    return '$_temp0';
  }

  @override
  String get playerFiles => 'Files';

  @override
  String playerSeasonEpisode(int season, int episode) {
    return 'S$season E$episode';
  }

  @override
  String playerEpisodeNumber(int episode) {
    return 'E$episode';
  }

  @override
  String playerRuntimeMinutes(int count) {
    return '$count min';
  }

  @override
  String get audioDelay => 'Audio delay';

  @override
  String get subtitleSearchTitleFallback =>
      'Nothing matched this title\'s ID. Showing title matches instead.';

  @override
  String get subtitleSearchSeasonFallback =>
      'No subtitles for this episode. These are for the whole season, so check the episode number in the file name.';

  @override
  String get sourcesSearching => 'Przeszukiwanie scraperów…';

  @override
  String get sourcesEmptyFiltered => 'Żaden link nie pasuje do filtrów.';

  @override
  String get sourcesEmptyNoTmdbId =>
      'Brak identyfikatora TMDB dla tego tytułu. Podaj go przez \'Search manually\'.';

  @override
  String get sourcesEmptyNoScrapers =>
      'Brak włączonych scraperów. Dodaj w \'Nuvio Plugins\'.';

  @override
  String get sourcesEmptyAllFailed =>
      'Wszystkie scrapery zawiodły. Sprawdź połączenie lub je zaktualizuj.';

  @override
  String sourcesEmptySomeFailed(int failed, int total) {
    return 'Nie znaleziono linków. Zawiodło $failed z $total scraperów.';
  }

  @override
  String get sourcesEmptyNothingFound =>
      'Żaden z twoich scraperów nie ma tego tytułu.';

  @override
  String get subtitleDefault => 'Subtitles by default';

  @override
  String get subtitleDefaultAuto => 'Auto';

  @override
  String get subtitleDefaultAutoDetail =>
      'A video starts with the subtitle its source selects, preferring your subtitle language when the source offers it.';

  @override
  String get subtitleDefaultOffDetail =>
      'A video starts with no subtitle. You can still turn one on from the Subtitles menu in the player.';

  @override
  String get networkBuffer => 'Network buffer';

  @override
  String get networkBufferSubtitle =>
      'How much of a stream to hold in memory. A larger buffer makes seeking smoother and rides out a shaky connection, at the cost of memory.';

  @override
  String get selectNetworkBuffer => 'Select network buffer';

  @override
  String playerGettingLinks(String plugin) {
    return 'Getting links from $plugin…';
  }

  @override
  String get playerSourceChecking => 'Checking…';

  @override
  String get playerSourceOpening => 'Opening…';

  @override
  String get playerSourceNotChecked => 'Not checked';

  @override
  String get playerReasonNoAnswer => 'no answer from the link';

  @override
  String get playerSourceUnplayable => 'Unplayable';

  @override
  String get nuvioPlugins => 'Nuvio plugins';

  @override
  String get nuvioSearchForStreams => 'Search for streams';

  @override
  String get nuvioChooseEpisode => 'Choose an episode';

  @override
  String nuvioScraperCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scrapers',
      one: '1 scraper',
    );
    return '$_temp0';
  }

  @override
  String get stremioAddons => 'Stremio add-ons';

  @override
  String get stremioSearchAddons => 'Search Stremio add-ons';

  @override
  String stremioSearchAddonsForEpisode(int season, int episode) {
    return 'Search add-ons: S$season E$episode';
  }

  @override
  String stremioAddonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count add-ons',
      one: '1 add-on',
    );
    return '$_temp0';
  }

  @override
  String get addonSourcesSearchTooltip => 'Search links';

  @override
  String get addonSourcesCloseSearchTooltip => 'Close search';

  @override
  String get addonSourcesSearchHint => 'Add-on, provider, quality…';

  @override
  String get addonSourcesNoMatchFilter =>
      'No links match. Clear search or try \"All\".';

  @override
  String get addonManageSearchHint => 'Search installed add-ons…';

  @override
  String addonManageNoMatch(String query) {
    return 'No installed add-on matches \"$query\".';
  }
}
