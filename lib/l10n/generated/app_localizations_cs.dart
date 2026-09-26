// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class AppLocalizationsCs extends AppLocalizations {
  AppLocalizationsCs([String locale = 'cs']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => 'Čeština';

  @override
  String get addonHealthChecking => 'Checking add-on…';

  @override
  String addonHealthWorking(int ms) {
    return 'Working · $ms ms';
  }

  @override
  String get addonHealthUnavailable => 'Unavailable';

  @override
  String get home => 'Domů';

  @override
  String get search => 'Hledat';

  @override
  String get explore => 'Prozkoumat';

  @override
  String get exploreAnime => 'Prozkoumat anime';

  @override
  String get exploreMovies => 'Prozkoumat filmy';

  @override
  String get library => 'Knihovna';

  @override
  String get settings => 'Nastavení';

  @override
  String get extensions => 'Rozšíření';

  @override
  String get updateAvailable => 'Dostupná aktualizace';

  @override
  String get retry => 'Zkusit znovu';

  @override
  String get factoryReset => 'Tovární nastavení';

  @override
  String get startupError => 'Chyba při spuštění';

  @override
  String get general => 'Obecné';

  @override
  String get appTheme => 'Motiv aplikace';

  @override
  String get recordWatchHistory => 'Zaznamenávat historii sledování';

  @override
  String get fullScreenMode => 'Celá obrazovka';

  @override
  String get fullScreenModeSubtitle => 'Přepne na televizní rozhraní';

  @override
  String get defaultHomeScreen => 'Výchozí domovská obrazovka';

  @override
  String get titlePosition => 'Pozice názvu';

  @override
  String get titlePositionBelowPoster => 'Pod plakátem';

  @override
  String get titlePositionInsidePoster => 'Na plakátu';

  @override
  String get player => 'Přehrávač';

  @override
  String get defaultPlayer => 'Výchozí přehrávač';

  @override
  String get leftGesture => 'Levé gesto';

  @override
  String get rightGesture => 'Pravé gesto';

  @override
  String get doubleTapToSeek => 'Poklepáním posunout';

  @override
  String get swipeToSeek => 'Přejetím posunout';

  @override
  String get seekDuration => 'Délka posunu';

  @override
  String get defaultResizeMode => 'Výchozí režim velikosti';

  @override
  String get hardwareDecoding => 'Hardwarové dekódování';

  @override
  String get network => 'Síť';

  @override
  String get dnsOverHttps => 'DNS přes HTTPS';

  @override
  String get dohProvider => 'Poskytovatel DoH';

  @override
  String get githubProxy => 'Proxy GitHubu';

  @override
  String get githubProxySubtitle =>
      'Směrovat stahování rozšíření přes jsDelivr a obejít tak blokování poskytovatelem.';

  @override
  String get manageExtensions => 'Spravovat rozšíření';

  @override
  String get appData => 'Data aplikace';

  @override
  String get resetDataKeepExtensions => 'Resetovat data (ponechat rozšíření)';

  @override
  String get developer => 'Vývojář';

  @override
  String get developerOptions => 'Možnosti pro vývojáře';

  @override
  String get about => 'O aplikaci';

  @override
  String get version => 'Verze';

  @override
  String get enabled => 'Povoleno';

  @override
  String get disabled => 'Zakázáno';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'Připojte se k našemu serveru';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'Připojte se k našemu kanálu';

  @override
  String developedBy(String name) {
    return 'Developed by $name';
  }

  @override
  String get system => 'Systém';

  @override
  String get dark => 'Tmavý';

  @override
  String get light => 'Světlý';

  @override
  String get later => 'Později';

  @override
  String get updateNow => 'Aktualizovat nyní';

  @override
  String get save => 'Uložit';

  @override
  String get cancel => 'Zrušit';

  @override
  String get close => 'Zavřít';

  @override
  String get delete => 'Smazat';

  @override
  String get viewDetails => 'Zobrazit podrobnosti';

  @override
  String get clearAll => 'Vymazat vše';

  @override
  String get clearAllHistory => 'Vymazat historii';

  @override
  String get all => 'Vše';

  @override
  String get none => 'Nic';

  @override
  String get confirmDownload => 'Potvrdit stahování';

  @override
  String get downloadNow => 'Stáhnout nyní';

  @override
  String get selectSource => 'Vybrat zdroj';

  @override
  String get downloadUnavailable => 'Nedostupné';

  @override
  String get selectAnotherSource => 'Vybrat jiný zdroj';

  @override
  String get watchHistoryCleared => 'Historie sledování byla vymazána';

  @override
  String get downloadingUpdate => 'Stahování aktualizace...';

  @override
  String errorPrefix(String message) {
    return 'Chyba: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'Dostupná aktualizace: $tag';
  }

  @override
  String get selectProviderToStart => 'Vyberte poskytovatele a začněte';

  @override
  String get tapExtensionIcon => 'Klepněte na ikonu rozšíření v rohu';

  @override
  String get continueWatching => 'Pokračovat ve sledování';

  @override
  String get noInternetConnection => 'Žádné připojení k internetu';

  @override
  String get siteNotReachable => 'Stránka není dostupná';

  @override
  String get checkConnectionOrDownloads =>
      'Zkontrolujte připojení nebo své stažené soubory.';

  @override
  String get tryVpnOrConnection => 'Zkuste VPN nebo zkontrolujte připojení.';

  @override
  String errorDetails(String error) {
    return 'Podrobnosti o chybě: $error';
  }

  @override
  String get goToDownloads => 'Přejít ke stahování';

  @override
  String get selectProvider => 'Vybrat poskytovatele';

  @override
  String get searchHint => 'Hledat filmy, seriály...';

  @override
  String get searchFavoriteContent => 'Hledejte svůj oblíbený obsah';

  @override
  String get pressSearchOrEnter =>
      'Začněte stisknutím klávesy Hledat nebo Enter';

  @override
  String get recentSearches => 'Recent searches';

  @override
  String removeFromSearchHistory(String query) {
    return 'Remove $query from search history';
  }

  @override
  String get noResultsFound => 'Nebyly nalezeny žádné výsledky.';

  @override
  String get couldNotLoadTrending => 'Nepodařilo se načíst trendy';

  @override
  String get popularMovies => 'Populární filmy';

  @override
  String get popularTVShows => 'Populární seriály';

  @override
  String get newMovies => 'Nové filmy';

  @override
  String get newTVShows => 'Nové seriály';

  @override
  String get featuredMovies => 'Doporučené filmy';

  @override
  String get featuredTVShows => 'Doporučené seriály';

  @override
  String get lastVideosTVShows => 'Poslední videa';

  @override
  String get downloads => 'Stahování';

  @override
  String get bookmarks => 'Záložky';

  @override
  String get noDownloadsYet => 'Zatím žádná stažení';

  @override
  String episodesCount(int count, int done) {
    return '$count epizod • $done dokončeno';
  }

  @override
  String get deleteAllEpisodes => 'Smazat všechny epizody';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return 'Opravdu chcete smazat všech $count epizod balíčku \"$title\" a jejich soubory?';
  }

  @override
  String get deleteAll => 'Smazat vše';

  @override
  String get completed => 'Dokončeno';

  @override
  String get statusQueued => 'Ve frontě...';

  @override
  String get statusDownloading => 'Stahování...';

  @override
  String get statusFinished => 'Dokončeno';

  @override
  String get statusFailed => 'Selhalo';

  @override
  String get statusCanceled => 'Zrušeno';

  @override
  String get statusPaused => 'Pozastaveno';

  @override
  String get statusWaiting => 'Čekání...';

  @override
  String get fileNotFoundRemoving =>
      'Soubor nebyl nalezen. Odstranění záznamu.';

  @override
  String get fileNotFound => 'Soubor nebyl nalezen';

  @override
  String get deleteDownload => 'Smazat stažení';

  @override
  String get confirmDeleteDownload => 'Opravdu chcete smazat toto stažení?';

  @override
  String get libraryEmpty => 'Vaše knihovna je prázdná';

  @override
  String get language => 'Jazyk';

  @override
  String get english => 'Angličtina';

  @override
  String get hindi => 'Hindština';

  @override
  String get kannada => 'Kannadština';

  @override
  String get unknown => 'Neznámý';

  @override
  String get recommended => 'Doporučeno';

  @override
  String get on => 'Zap';

  @override
  String get off => 'Vyp';

  @override
  String get installRemoveProviders => 'Instalovat/odebrat poskytovatele';

  @override
  String get resetDataSubtitle => 'Vymazat nastavení a DB, ponechat pluginy';

  @override
  String get factoryResetSubtitle =>
      'Smazat všechna data, nastavení a rozšíření';

  @override
  String get developerOptionsSubtitle =>
      'Nástroje pro ladění a lokální přehrávání';

  @override
  String get loading => 'Načítání...';

  @override
  String get sec => 's';

  @override
  String get min => 'min';

  @override
  String playerRewindSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zpět o $count sekund',
      many: 'Zpět o $count sekundy',
      few: 'Zpět o $count sekundy',
      one: 'Zpět o $count sekundu',
    );
    return '$_temp0';
  }

  @override
  String playerForwardSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vpřed o $count sekund',
      many: 'Vpřed o $count sekundy',
      few: 'Vpřed o $count sekundy',
      one: 'Vpřed o $count sekundu',
    );
    return '$_temp0';
  }

  @override
  String get internalPlayer => 'Interní (VLC)';

  @override
  String get builtInPlayer => 'Vestavěný přehrávač';

  @override
  String get customNotSet => 'Vlastní (nenastaveno)';

  @override
  String selectGesture(String side) {
    return 'Vybrat $side gesto';
  }

  @override
  String get left => 'levé';

  @override
  String get right => 'pravé';

  @override
  String get selectSeekDuration => 'Vybrat délku posunu';

  @override
  String get subtitleSettings => 'Nastavení titulků';

  @override
  String size(int size) {
    return 'Velikost: $size';
  }

  @override
  String get background => 'Pozadí';

  @override
  String get customDohUrlLabel => 'Vlastní DoH URL';

  @override
  String get enterCustomDohUrl => 'Zadejte vlastní DoH URL';

  @override
  String get chooseTheme => 'Vybrat motiv';

  @override
  String get resetDataDialogTitle => 'Resetovat data?';

  @override
  String get resetDataDialogContent =>
      'Toto vymaže Nastavení, Oblíbené a Historii. Nainstalovaná rozšíření zůstanou.';

  @override
  String get factoryResetDialogTitle => 'Tovární nastavení?';

  @override
  String get factoryResetDialogContent =>
      'Toto smaže VŠE. Tuto akci nelze vrátit zpět.';

  @override
  String get selectLanguage => 'Vybrat jazyk';

  @override
  String get synopsis => 'Synopse';

  @override
  String get noDescription => 'Popis není k dispozici.';

  @override
  String get videoAlreadyDownloadedPrompt =>
      'Toto video je již staženo. Co chcete udělat?';

  @override
  String get playNow => 'Přehrát nyní';

  @override
  String get upNext => 'Následuje';

  @override
  String get deleteDownloadPrompt => 'Smazat stažení?';

  @override
  String get deleteDownloadConfirmation =>
      'Opravdu chcete odstranit tento soubor? Akci nelze vrátit zpět.';

  @override
  String get no => 'Ne';

  @override
  String get yesDelete => 'Ano, smazat';

  @override
  String get downloadPaused => 'Stahování pozastaveno';

  @override
  String get downloading => 'Stahování';

  @override
  String get speed => 'Rychlost';

  @override
  String get remaining => 'Zbývá';

  @override
  String get resume => 'Obnovit';

  @override
  String get pause => 'Pozastavit';

  @override
  String get torrentContent => 'Obsah torrentu';

  @override
  String get audioTracks => 'Zvukové stopy';

  @override
  String get noAudioTracks => 'Nenalezeny žádné zvukové stopy';

  @override
  String get subtitles => 'Titulky';

  @override
  String get options => 'Možnosti';

  @override
  String get noSubtitlesFound => 'Nenalezeny žádné titulky';

  @override
  String get playbackSpeed => 'Rychlost přehrávání';

  @override
  String get subtitleOptions => 'Možnosti titulků';

  @override
  String get hlsSubtitleWarning =>
      'Externí titulky nejsou na této platformě s HLS podporovány.';

  @override
  String get loadFromDevice => 'Načíst ze zařízení';

  @override
  String get syncDelay => 'Synchronizace / Zpoždění';

  @override
  String get styleSettings => 'Nastavení stylu';

  @override
  String get searchOnline => 'Hledat online';

  @override
  String get subtitleSync => 'Synchronizace titulků';

  @override
  String get subtitleDelayWarning =>
      'Zpoždění titulků není aktuálním přehrávačem podporováno.';

  @override
  String get resetDelay => 'Resetovat zpoždění';

  @override
  String get subtitleStyles => 'Styly titulků';

  @override
  String get resetToDefault => 'Obnovit výchozí';

  @override
  String get fontSize => 'Velikost písma';

  @override
  String get verticalPosition => 'Vertikální poloha';

  @override
  String get textColor => 'Barva textu';

  @override
  String get backgroundColor => 'Barva pozadí';

  @override
  String get backgroundOpacity => 'Průhlednost pozadí';

  @override
  String get subtitleSearch => 'Hledání titulků';

  @override
  String get searchSubtitleNameHint => 'Název titulků...';

  @override
  String get enterSearchSubtitlePrompt =>
      'Zadejte název pro vyhledání titulků.';

  @override
  String get noSubtitleResults => 'Žádné výsledky.';

  @override
  String get downloadingApplyingSubtitle => 'Stahování a aplikace titulků...';

  @override
  String get failedToDownloadSubtitle => 'Nepodařilo se stáhnout titulky.';

  @override
  String get failedToLoadSubtitles =>
      'Nepodařilo se načíst titulky. Zkuste to znovu.';

  @override
  String get noReposFound => 'Nebyla nalezena žádná úložiště';

  @override
  String get downloadAllProviders => 'Stáhnout vše';

  @override
  String get removeRepository => 'Odstranit úložiště';

  @override
  String get addRepo => 'Přidat úložiště';

  @override
  String get extensionsNotInRepos => 'Rozšíření mimo úložiště';

  @override
  String get noLongerInRepo => 'Již není v seznamu úložišť';

  @override
  String get addRepoToBrowse => 'Přidejte úložiště pro procházení pluginů';

  @override
  String get debugExtensions => 'Ladit rozšíření';

  @override
  String removeRepoConfirm(String repoName) {
    return 'Odstranit $repoName?';
  }

  @override
  String get removeRepoWarning => 'Toto odinstaluje VŠECHNY jeho pluginy.';

  @override
  String get addRepository => 'Přidat úložiště';

  @override
  String get repoUrlOrShortcode => 'URL úložiště nebo kód';

  @override
  String get assetPlugin => 'Plugin z aktiv';

  @override
  String get installed => 'Nainstalováno';

  @override
  String get repositories => 'Repozitáře';

  @override
  String get noExtensionsInstalled => 'Nejsou nainstalována žádná rozšíření';

  @override
  String get browseRepositoriesToInstall =>
      'Otevřete kartu Repozitáře a objevte a nainstalujte rozšíření.';

  @override
  String get browseRepositories => 'Procházet repozitáře';

  @override
  String get addRepoDescription =>
      'Přidejte URL repozitáře nebo zkrácený kód a objevte a nainstalujte pluginy rozšíření.';

  @override
  String updateTo(String version) {
    return 'Aktualizovat na $version';
  }

  @override
  String get install => 'Instalovat';

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
  String get error => 'Chyba';

  @override
  String get ok => 'OK';

  @override
  String pluginSettings(String pluginName) {
    return 'Nastavení $pluginName';
  }

  @override
  String get movies => 'Filmy';

  @override
  String get series => 'Seriály';

  @override
  String get anime => 'Anime';

  @override
  String get liveStreams => 'Živé přenosy';

  @override
  String get debug => 'LADĚNÍ';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aktualizováno $count rozšíření',
      few: 'Aktualizována $count rozšíření',
      one: 'Aktualizováno 1 rozšíření',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => 'Neplatná navigace.';

  @override
  String get startOver => 'Začít znovu';

  @override
  String get goBack => 'Zpět';

  @override
  String get restartApp => 'Restartovat aplikaci';

  @override
  String get resolving => 'Získávání odkazů...';

  @override
  String get downloaded => 'Staženo';

  @override
  String get download => 'Stáhnout';

  @override
  String get debugOnlyFeature => 'Pouze pro vývojové verze';

  @override
  String get streamUrl => 'URL streamu';

  @override
  String get play => 'Přehrát';

  @override
  String get verifyingSourceSize => 'Ověřování...';

  @override
  String get fileSaveLocationNotification =>
      'Soubor bude uložen do složky Stažené soubory.';

  @override
  String get resumingPlayback => 'Obnovování přehrávání';

  @override
  String pausedAt(String time) {
    return 'Pozastaveno v $time';
  }

  @override
  String resumesAutomatically(int count) {
    return 'Automaticky za $count s';
  }

  @override
  String get resumeNow => 'Obnovit nyní';

  @override
  String get playbackError => 'Chyba přehrávání';

  @override
  String get confirmClearHistory => 'Vymazat celou historii?';

  @override
  String seasonWithNumber(Object number) {
    return '$number. řada';
  }

  @override
  String get starting => 'Spouštění...';

  @override
  String percentWatched(int percent) {
    return '$percent% zhlédnuto';
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
  String get debugTools => 'Nástroje pro ladění';

  @override
  String get playLocalVideo => 'Místní video';

  @override
  String get playLocalVideoSubtitle => 'Přehrát soubor ze zařízení';

  @override
  String get streamUrlSubtitle => 'Přehrát z URL';

  @override
  String get streamTorrent => 'Streamovat torrent';

  @override
  String get streamTorrentSubtitle => 'Vyberte soubor torrentu';

  @override
  String get loadPluginFromAssets => 'Načíst plugin z aktiv';

  @override
  String get enterVideoUrlHint => 'URL videa';

  @override
  String get networkStream => 'Síťový stream';

  @override
  String removedFromHistory(String title) {
    return 'Odstraněno z historie: $title';
  }

  @override
  String get custom => 'Vlastní';

  @override
  String get refreshingLiveStream => 'Obnovování...';

  @override
  String get removeFromHistory => 'Odstranit z historie';

  @override
  String get live => 'ŽIVĚ';

  @override
  String get volume => 'Hlasitost';

  @override
  String get decrease => 'Decrease';

  @override
  String get increase => 'Increase';

  @override
  String get brightness => 'Jas';

  @override
  String get fit => 'Přizpůsobit';

  @override
  String get zoom => 'Přiblížit';

  @override
  String get stretch => 'Roztáhnout';

  @override
  String titleWithParam(String title) {
    return 'Název: $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'Zdroj: $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'Velikost: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'Chyba: $error. Použit interní přehrávač.';
  }

  @override
  String externalPlayerCannotSendHeaders(String playerName, String headers) {
    return '$playerName cannot send $headers. Using internal player.';
  }

  @override
  String playerNotDetected(String playerName) {
    return '$playerName nebyl nalezen.';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return '$number. řada ($count ep.)';
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
    return 'Zdroj pro $playerName';
  }

  @override
  String get noPluginsInstalled => 'Nejsou nainstalovány žádné pluginy';

  @override
  String get noPluginsMessage =>
      'Nainstalujte rozšíření pro procházení a streamování obsahu.';

  @override
  String get goToExtensions => 'Přejít na rozšíření';

  @override
  String get availableSources => 'Dostupné zdroje';

  @override
  String get seasons => 'Řady';

  @override
  String get episodes => 'Epizody';

  @override
  String get selectSourceToPlay => 'Vyberte zdroj k přehrání.';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count epizod',
      few: '$count epizody',
      one: '1 epizoda',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'Nenalezeny žádné epizody';

  @override
  String get local => 'Místní';

  @override
  String get remote => 'Vzdálený';

  @override
  String get torrent => 'Torrent';

  @override
  String get unlock => 'Odemknout';

  @override
  String get lock => 'Zamknout';

  @override
  String get sources => 'Zdroje';

  @override
  String get tracks => 'Stopy';

  @override
  String get content => 'Obsah';

  @override
  String get stats => 'Statistiky';

  @override
  String get resize => 'Velikost';

  @override
  String get next => 'Další';

  @override
  String get previous => 'Previous';

  @override
  String get pip => 'Obraz v obraze';

  @override
  String get rotate => 'Otočit';

  @override
  String get windowed => 'V okně';

  @override
  String get fullscreen => 'Celá obrazovka';

  @override
  String get movieDetails => 'Podrobnosti';

  @override
  String get showDetails => 'Zobrazit detaily';

  @override
  String get tagline => 'Slogan';

  @override
  String get status => 'Stav';

  @override
  String get releaseDate => 'Datum vydání';

  @override
  String get firstAirDate => 'První vysílání';

  @override
  String get originalLanguage => 'Původní jazyk';

  @override
  String get originCountry => 'Země původu';

  @override
  String get budgetLabel => 'Rozpočet';

  @override
  String get revenueLabel => 'Tržby';

  @override
  String get paused => 'Pozastaveno';

  @override
  String get watched => 'Zhlédnuto';

  @override
  String get watching => 'Sleduji';

  @override
  String get lastWatched => 'Naposledy';

  @override
  String get movie => 'Film';

  @override
  String get tvShow => 'Seriál';

  @override
  String get failedToLoadContent => 'Chyba při načítání';

  @override
  String get director => 'Režisér';

  @override
  String get creator => 'Tvůrce';

  @override
  String get showMore => 'Více';

  @override
  String get showLess => 'Méně';

  @override
  String get viewAll => 'Vše';

  @override
  String seasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count řad',
      few: '$count řady',
      one: '1 řada',
    );
    return '$_temp0';
  }

  @override
  String get noInternetError => 'Žádný internet';

  @override
  String get timeoutError => 'Čas vypršel.';

  @override
  String get serverError => 'Chyba serveru.';

  @override
  String get contentNotFoundError => 'Nenalezeno.';

  @override
  String get accessDeniedError => 'Přístup odepřen.';

  @override
  String get serviceUnavailableError => 'Služba není dostupná.';

  @override
  String get generalError => 'Chyba.';

  @override
  String get skip => 'Přeskočit';

  @override
  String get skipIntro => 'Přeskočit úvod';

  @override
  String get skipOutro => 'Přeskočit závěr';

  @override
  String get skipRecap => 'Přeskočit shrnutí';

  @override
  String get goLive => 'Živě';

  @override
  String get dismiss => 'Zavřít';

  @override
  String get nextUp => 'Další';

  @override
  String sourceAttempt(int index, int total) {
    return 'Pokus $index z $total';
  }

  @override
  String get trying => 'Zkoušení';

  @override
  String get failed => 'Selhalo';

  @override
  String get selected => 'Vybráno';

  @override
  String get playing => 'Přehrává se';

  @override
  String get pending => 'Čeká';

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
  String get mobileQualityPreference => 'Preference kvality mobilních dat';

  @override
  String get anyNoPreference => 'Žádná preference';

  @override
  String get subtitleAccounts => 'Účty titulků';

  @override
  String get accounts => 'Účty';

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
  String get testConnection => 'Testovat připojení';

  @override
  String get connectedSuccessfully => 'Připojeno úspěšně';

  @override
  String get connectionFailed => 'Připojení selhalo';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get noAccountRegister => 'Don\'t have an account? Register here';

  @override
  String get apiKey => 'API klíč';

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
  String get diagnostics => 'Diagnostika';

  @override
  String get viewLogs => 'Zobrazit logy';

  @override
  String get viewLogsSubtitle => 'Zobrazit aktivitu aplikace a chyby';

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
  String get sourcesSearching => 'Hledání ve scraperech…';

  @override
  String get sourcesEmptyFiltered => 'Žádný odkaz neodpovídá filtrům.';

  @override
  String get sourcesEmptyNoTmdbId =>
      'Tento titul nemá TMDB ID. Zadejte ho přes \'Search manually\'.';

  @override
  String get sourcesEmptyNoScrapers =>
      'Není zapnutý žádný scraper. Přidejte ho v \'Nuvio Plugins\'.';

  @override
  String get sourcesEmptyAllFailed =>
      'Všechny scrapery selhaly. Zkontrolujte připojení nebo je aktualizujte.';

  @override
  String sourcesEmptySomeFailed(int failed, int total) {
    return 'Nenalezeny žádné odkazy. Selhalo $failed z $total scraperů.';
  }

  @override
  String get sourcesEmptyNothingFound =>
      'Žádný z vašich scraperů tento titul nemá.';

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
