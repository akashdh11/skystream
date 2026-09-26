// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hungarian (`hu`).
class AppLocalizationsHu extends AppLocalizations {
  AppLocalizationsHu([String locale = 'hu']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => 'Magyar';

  @override
  String get addonHealthChecking => 'Checking add-on…';

  @override
  String addonHealthWorking(int ms) {
    return 'Working · $ms ms';
  }

  @override
  String get addonHealthUnavailable => 'Unavailable';

  @override
  String get home => 'Kezdőlap';

  @override
  String get search => 'Keresés';

  @override
  String get explore => 'Felfedezés';

  @override
  String get exploreAnime => 'Anime felfedezése';

  @override
  String get exploreMovies => 'Filmek felfedezése';

  @override
  String get library => 'Könyvtár';

  @override
  String get settings => 'Beállítások';

  @override
  String get extensions => 'Bővítmények';

  @override
  String get updateAvailable => 'Frissítés elérhető';

  @override
  String get retry => 'Újra';

  @override
  String get factoryReset => 'Gyári adatok visszaállítása';

  @override
  String get startupError => 'Indítási hiba';

  @override
  String get general => 'Általános';

  @override
  String get appTheme => 'Alkalmazás témája';

  @override
  String get recordWatchHistory => 'Megtekintési előzmények rögzítése';

  @override
  String get fullScreenMode => 'Teljes képernyő';

  @override
  String get fullScreenModeSubtitle => 'Átvált a TV-elrendezésre';

  @override
  String get defaultHomeScreen => 'Alapértelmezett kezdőképernyő';

  @override
  String get titlePosition => 'Cím helye';

  @override
  String get titlePositionBelowPoster => 'A poszter alatt';

  @override
  String get titlePositionInsidePoster => 'A poszteren';

  @override
  String get player => 'Lejátszó';

  @override
  String get defaultPlayer => 'Alapértelmezett lejátszó';

  @override
  String get leftGesture => 'Bal oldali gesztus';

  @override
  String get rightGesture => 'Jobb oldali gesztus';

  @override
  String get doubleTapToSeek => 'Dupla koppintás a kereséshez';

  @override
  String get swipeToSeek => 'Csúsztatás a kereséshez';

  @override
  String get seekDuration => 'Keresési időtartam';

  @override
  String get defaultResizeMode => 'Alapértelmezett méretezési mód';

  @override
  String get hardwareDecoding => 'Hardveres dekódolás';

  @override
  String get network => 'Hálózat';

  @override
  String get dnsOverHttps => 'DNS over HTTPS';

  @override
  String get dohProvider => 'DoH szolgáltató';

  @override
  String get githubProxy => 'GitHub proxy';

  @override
  String get githubProxySubtitle =>
      'A bővítmények letöltése a jsDelivren keresztül, a szolgáltatói tiltások megkerüléséhez.';

  @override
  String get manageExtensions => 'Bővítmények kezelése';

  @override
  String get appData => 'Alkalmazás adatai';

  @override
  String get resetDataKeepExtensions =>
      'Adatok törlése (bővítmények megtartása)';

  @override
  String get developer => 'Fejlesztő';

  @override
  String get developerOptions => 'Fejlesztői beállítások';

  @override
  String get about => 'Névjegy';

  @override
  String get version => 'Verzió';

  @override
  String get enabled => 'Engedélyezve';

  @override
  String get disabled => 'Letiltva';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'Csatlakozz a szerverünkhöz';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'Csatlakozz a csatornánkhoz';

  @override
  String developedBy(String name) {
    return 'Developed by $name';
  }

  @override
  String get system => 'Rendszer';

  @override
  String get dark => 'Sötét';

  @override
  String get light => 'Világos';

  @override
  String get later => 'Később';

  @override
  String get updateNow => 'Frissítés most';

  @override
  String get save => 'Mentés';

  @override
  String get cancel => 'Mégse';

  @override
  String get close => 'Bezárás';

  @override
  String get delete => 'Törlés';

  @override
  String get viewDetails => 'Részletek megtekintése';

  @override
  String get clearAll => 'Összes törlése';

  @override
  String get clearAllHistory => 'Előzmények törlése';

  @override
  String get all => 'Mind';

  @override
  String get none => 'Nincs';

  @override
  String get confirmDownload => 'Letöltés megerősítése';

  @override
  String get downloadNow => 'Letöltés most';

  @override
  String get selectSource => 'Forrás kiválasztása';

  @override
  String get downloadUnavailable => 'Nem elérhető';

  @override
  String get selectAnotherSource => 'Válasszon másikat';

  @override
  String get watchHistoryCleared => 'Megtekintési előzmények törölve';

  @override
  String get downloadingUpdate => 'Frissítés letöltése...';

  @override
  String errorPrefix(String message) {
    return 'Hiba: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'Frissítés elérhető: $tag';
  }

  @override
  String get selectProviderToStart => 'Válasszon szolgáltatót az indításhoz';

  @override
  String get tapExtensionIcon => 'Koppintson a bővítmény ikonra a sarokban';

  @override
  String get continueWatching => 'Folytatás';

  @override
  String get noInternetConnection => 'Nincs internetkapcsolat';

  @override
  String get siteNotReachable => 'Az oldal nem érhető el';

  @override
  String get checkConnectionOrDownloads =>
      'Ellenőrizze a kapcsolatot vagy nézze meg a letöltéseket.';

  @override
  String get tryVpnOrConnection =>
      'Próbálkozzon VPN-nel vagy ellenőrizze az internetet.';

  @override
  String errorDetails(String error) {
    return 'Hiba részletei: $error';
  }

  @override
  String get goToDownloads => 'Ugrás a letöltésekhez';

  @override
  String get selectProvider => 'Szolgáltató kiválasztása';

  @override
  String get searchHint => 'Filmek, sorozatok keresése...';

  @override
  String get searchFavoriteContent => 'Keressen a kedvenc tartalmai között';

  @override
  String get pressSearchOrEnter =>
      'A kezdéshez nyomja meg a keresést vagy az Entert';

  @override
  String get recentSearches => 'Recent searches';

  @override
  String removeFromSearchHistory(String query) {
    return 'Remove $query from search history';
  }

  @override
  String get noResultsFound => 'Nincs találat.';

  @override
  String get couldNotLoadTrending => 'Nem sikerült betölteni a trendeket';

  @override
  String get popularMovies => 'Népszerű filmek';

  @override
  String get popularTVShows => 'Népszerű sorozatok';

  @override
  String get newMovies => 'Új filmek';

  @override
  String get newTVShows => 'Új sorozatok';

  @override
  String get featuredMovies => 'Kiemelt filmek';

  @override
  String get featuredTVShows => 'Kiemelt sorozatok';

  @override
  String get lastVideosTVShows => 'Legutóbbi sorozatok';

  @override
  String get downloads => 'Letöltések';

  @override
  String get bookmarks => 'Könyvjelzők';

  @override
  String get noDownloadsYet => 'Még nincsenek letöltések';

  @override
  String episodesCount(int count, int done) {
    return '$count epizód • $done befejezve';
  }

  @override
  String get deleteAllEpisodes => 'Összes epizód törlése';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return 'Biztosan törölni szeretné a(z) \"$title\" összes ($count db) epizódját és fájlját?';
  }

  @override
  String get deleteAll => 'Összes törlése';

  @override
  String get completed => 'Befejezve';

  @override
  String get statusQueued => 'Sorban áll...';

  @override
  String get statusDownloading => 'Letöltés...';

  @override
  String get statusFinished => 'Kész';

  @override
  String get statusFailed => 'Sikertelen';

  @override
  String get statusCanceled => 'Megszakítva';

  @override
  String get statusPaused => 'Szüneteltetve';

  @override
  String get statusWaiting => 'Várakozás...';

  @override
  String get fileNotFoundRemoving => 'A fájl nem található. Bejegyzés törlése.';

  @override
  String get fileNotFound => 'A fájl nem található';

  @override
  String get deleteDownload => 'Letöltés törlése';

  @override
  String get confirmDeleteDownload =>
      'Biztosan törölni szeretné ezt a letöltést?';

  @override
  String get libraryEmpty => 'A könyvtára üres';

  @override
  String get language => 'Nyelv';

  @override
  String get english => 'Angol';

  @override
  String get hindi => 'Hindi';

  @override
  String get kannada => 'Kannada';

  @override
  String get unknown => 'Ismeretlen';

  @override
  String get recommended => 'Ajánlott';

  @override
  String get on => 'Be';

  @override
  String get off => 'Ki';

  @override
  String get installRemoveProviders => 'Szolgáltatók telepítése/törlése';

  @override
  String get resetDataSubtitle =>
      'Beállítások és adatbázis törlése, bővítmények megtartása';

  @override
  String get factoryResetSubtitle =>
      'Összes adat, beállítás és bővítmény törlése';

  @override
  String get developerOptionsSubtitle =>
      'Hibakereső eszközök és helyi lejátszás';

  @override
  String get loading => 'Betöltés...';

  @override
  String get sec => 'mp';

  @override
  String get min => 'perc';

  @override
  String playerRewindSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vissza $count másodpercet',
      one: 'Vissza 1 másodpercet',
    );
    return '$_temp0';
  }

  @override
  String playerForwardSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Előre $count másodpercet',
      one: 'Előre 1 másodpercet',
    );
    return '$_temp0';
  }

  @override
  String get internalPlayer => 'Belső lejátszó (VLC)';

  @override
  String get builtInPlayer => 'Beépített lejátszó';

  @override
  String get customNotSet => 'Egyéni (nincs beállítva)';

  @override
  String selectGesture(String side) {
    return '$side gesztus kiválasztása';
  }

  @override
  String get left => 'bal oldali';

  @override
  String get right => 'jobb oldali';

  @override
  String get selectSeekDuration => 'Keresési időtartam kiválasztása';

  @override
  String get subtitleSettings => 'Felirat beállításai';

  @override
  String size(int size) {
    return 'Méret: $size';
  }

  @override
  String get background => 'Háttér';

  @override
  String get customDohUrlLabel => 'Egyéni DoH URL';

  @override
  String get enterCustomDohUrl => 'Adja meg saját DoH URL-címét';

  @override
  String get chooseTheme => 'Téma választása';

  @override
  String get resetDataDialogTitle => 'Adatok törlése?';

  @override
  String get resetDataDialogContent =>
      'Ez törli a beállításokat, a kedvenceket és az előzményeket. A telepített bővítmények megmaradnak.';

  @override
  String get factoryResetDialogTitle => 'Gyári adatok visszaállítása?';

  @override
  String get factoryResetDialogContent =>
      'Ez MINDENT töröl. Ezt a műveletet nem lehet visszavonni.';

  @override
  String get selectLanguage => 'Nyelv választása';

  @override
  String get synopsis => 'Szinopszis';

  @override
  String get noDescription => 'Nincs leírás.';

  @override
  String get videoAlreadyDownloadedPrompt =>
      'Ezt a videót már letöltötte. Mit szeretne tenni?';

  @override
  String get playNow => 'Lejátszás most';

  @override
  String get upNext => 'Következik';

  @override
  String get deleteDownloadPrompt => 'Letöltés törlése?';

  @override
  String get deleteDownloadConfirmation =>
      'Biztosan törölni szeretné ezt a fájlt? Ezt nem lehet visszavonni.';

  @override
  String get no => 'Nem';

  @override
  String get yesDelete => 'Igen, törlés';

  @override
  String get downloadPaused => 'Letöltés szüneteltetve';

  @override
  String get downloading => 'Letöltés';

  @override
  String get speed => 'Sebesség';

  @override
  String get remaining => 'Hátralévő';

  @override
  String get resume => 'Folytatás';

  @override
  String get pause => 'Szünet';

  @override
  String get torrentContent => 'Torrent tartalma';

  @override
  String get audioTracks => 'Hangsávok';

  @override
  String get noAudioTracks => 'Nem találhatók hangsávok';

  @override
  String get subtitles => 'Feliratok';

  @override
  String get options => 'Beállítások';

  @override
  String get noSubtitlesFound => 'Nem találhatók feliratok';

  @override
  String get playbackSpeed => 'Lejátszási sebesség';

  @override
  String get subtitleOptions => 'Felirat beállításai';

  @override
  String get hlsSubtitleWarning =>
      'Külső feliratok nem támogatottak HLS-nél ezen a platformon.';

  @override
  String get loadFromDevice => 'Betöltés az eszközről';

  @override
  String get syncDelay => 'Szinkron / Késleltetés';

  @override
  String get styleSettings => 'Stílus beállításai';

  @override
  String get searchOnline => 'Keresés online';

  @override
  String get subtitleSync => 'Felirat szinkronizálása';

  @override
  String get subtitleDelayWarning =>
      'A felirat késleltetése nem támogatott a jelenlegi lejátszóban.';

  @override
  String get resetDelay => 'Késleltetés alaphelyzetbe állítása';

  @override
  String get subtitleStyles => 'Felirat stílusok';

  @override
  String get resetToDefault => 'Alaphelyzet';

  @override
  String get fontSize => 'Betűméret';

  @override
  String get verticalPosition => 'Függőleges pozíció';

  @override
  String get textColor => 'Szövegszín';

  @override
  String get backgroundColor => 'Háttérszín';

  @override
  String get backgroundOpacity => 'Háttér átlátszósága';

  @override
  String get subtitleSearch => 'Felirat keresése';

  @override
  String get searchSubtitleNameHint => 'Felirat neve...';

  @override
  String get enterSearchSubtitlePrompt =>
      'Adja meg a nevet a felirat kereséséhez.';

  @override
  String get noSubtitleResults => 'Nincs találat.';

  @override
  String get downloadingApplyingSubtitle =>
      'Felirat letöltése és alkalmazása...';

  @override
  String get failedToDownloadSubtitle => 'Sikertelen felirat letöltés.';

  @override
  String get failedToLoadSubtitles =>
      'Sikertelen felirat betöltés. Próbálja újra.';

  @override
  String get noReposFound => 'Nem találhatók tárolók vagy bővítmények';

  @override
  String get downloadAllProviders => 'Összes letöltése';

  @override
  String get removeRepository => 'Tároló eltávolítása';

  @override
  String get addRepo => 'Tároló hozzáadása';

  @override
  String get extensionsNotInRepos => 'Nem tárolóban lévő bővítmények';

  @override
  String get noLongerInRepo => 'Már nem szerepel egyik tárolóban sem';

  @override
  String get addRepoToBrowse =>
      'Adjon hozzá egy tárolót a bővítmények böngészéséhez';

  @override
  String get debugExtensions => 'Bővítmények hibakeresése';

  @override
  String removeRepoConfirm(String repoName) {
    return 'Eltávolítja a(z) $repoName tárolót?';
  }

  @override
  String get removeRepoWarning =>
      'Ez eltávolítja a tárolót és MINDEN bővítményét törli.';

  @override
  String get addRepository => 'Tároló hozzáadása';

  @override
  String get repoUrlOrShortcode => 'Tároló URL vagy rövid kód';

  @override
  String get assetPlugin => 'Helyi bővítmény';

  @override
  String get installed => 'Telepítve';

  @override
  String get repositories => 'Tárolók';

  @override
  String get noExtensionsInstalled => 'Nincs telepített bővítmény';

  @override
  String get browseRepositoriesToInstall =>
      'Nyisd meg a Tárolók lapot bővítmények kereséséhez és telepítéséhez.';

  @override
  String get browseRepositories => 'Tárolók böngészése';

  @override
  String get addRepoDescription =>
      'Adj meg egy tároló URL-t vagy rövid kódot bővítmények kereséséhez és telepítéséhez.';

  @override
  String updateTo(String version) {
    return 'Frissítés erre: $version';
  }

  @override
  String get install => 'Telepítés';

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
  String get error => 'Hiba';

  @override
  String get ok => 'OK';

  @override
  String pluginSettings(String pluginName) {
    return '$pluginName beállításai';
  }

  @override
  String get movies => 'Filmek';

  @override
  String get series => 'Sorozatok';

  @override
  String get anime => 'Anime';

  @override
  String get liveStreams => 'Élő adások';

  @override
  String get debug => 'DEBUG';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bővítmény frissítve',
      one: '1 bővítmény frissítve',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => 'Érvénytelen navigáció.';

  @override
  String get startOver => 'Újrakezdés';

  @override
  String get goBack => 'Vissza';

  @override
  String get restartApp => 'Alkalmazás újraindítása';

  @override
  String get resolving => 'Feloldás...';

  @override
  String get downloaded => 'Letöltve';

  @override
  String get download => 'Letöltés';

  @override
  String get debugOnlyFeature => 'Csak hibakeresési módhoz';

  @override
  String get streamUrl => 'Stream URL';

  @override
  String get play => 'Lejátszás';

  @override
  String get verifyingSourceSize => 'Ellenőrzés...';

  @override
  String get fileSaveLocationNotification =>
      'A fájlt a letöltési mappába mentjük.';

  @override
  String get resumingPlayback => 'Lejátszás folytatása';

  @override
  String pausedAt(String time) {
    return 'Szüneteltetve: $time';
  }

  @override
  String resumesAutomatically(int count) {
    return 'Automatikus folytatás $count mp múlva';
  }

  @override
  String get resumeNow => 'Folytatás most';

  @override
  String get playbackError => 'Lejátszási hiba';

  @override
  String get confirmClearHistory => 'Minden előzményt töröl?';

  @override
  String seasonWithNumber(Object number) {
    return '$number. évad';
  }

  @override
  String get starting => 'Indítás...';

  @override
  String percentWatched(int percent) {
    return '$percent% megnézve';
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
  String get debugTools => 'Hibakereső eszközök';

  @override
  String get playLocalVideo => 'Helyi videó';

  @override
  String get playLocalVideoSubtitle => 'Fájl lejátszása az eszközről';

  @override
  String get streamUrlSubtitle => 'Lejátszás URL-ről';

  @override
  String get streamTorrent => 'Torrent lejátszása';

  @override
  String get streamTorrentSubtitle => 'Válasszon torrent fájlt';

  @override
  String get loadPluginFromAssets => 'Bővítmény betöltése';

  @override
  String get enterVideoUrlHint => 'Videó URL címe';

  @override
  String get networkStream => 'Hálózati stream';

  @override
  String removedFromHistory(String title) {
    return 'Törölve az előzményekből: $title';
  }

  @override
  String get custom => 'Egyéni';

  @override
  String get refreshingLiveStream => 'Frissítés...';

  @override
  String get removeFromHistory => 'Törlés az előzményekből';

  @override
  String get live => 'ÉLŐ';

  @override
  String get volume => 'Hangerő';

  @override
  String get decrease => 'Decrease';

  @override
  String get increase => 'Increase';

  @override
  String get brightness => 'Fényerő';

  @override
  String get fit => 'Illeszkedés';

  @override
  String get zoom => 'Nagyítás';

  @override
  String get stretch => 'Nyújtás';

  @override
  String titleWithParam(String title) {
    return 'Cím: $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'Forrás: $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'Méret: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'Hiba: $error. Belső lejátszó használata.';
  }

  @override
  String externalPlayerCannotSendHeaders(String playerName, String headers) {
    return '$playerName cannot send $headers. Using internal player.';
  }

  @override
  String playerNotDetected(String playerName) {
    return '$playerName nem található.';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return '$number. évad ($count ep.)';
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
    return 'Forrás kiválasztása ehhez: $playerName';
  }

  @override
  String get noPluginsInstalled => 'Nincsenek telepített bővítmények';

  @override
  String get noPluginsMessage =>
      'Telepítsen bővítményeket a tartalom böngészéséhez och streameléséhez.';

  @override
  String get goToExtensions => 'Ugrás a bővítményekhez';

  @override
  String get availableSources => 'Elérhető források';

  @override
  String get seasons => 'Évadok';

  @override
  String get episodes => 'Epizódok';

  @override
  String get selectSourceToPlay => 'Válasszon forrást a lejátszáshoz.';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count epizód',
      one: '1 epizód',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'Nem találhatók epizódok';

  @override
  String get local => 'Helyi';

  @override
  String get remote => 'Távoli';

  @override
  String get torrent => 'Torrent';

  @override
  String get unlock => 'Feloldás';

  @override
  String get lock => 'Zárolás';

  @override
  String get sources => 'Források';

  @override
  String get tracks => 'Számok';

  @override
  String get content => 'Tartalom';

  @override
  String get stats => 'Statisztika';

  @override
  String get resize => 'Méretezés';

  @override
  String get next => 'Következő';

  @override
  String get previous => 'Previous';

  @override
  String get pip => 'Kép a képben';

  @override
  String get rotate => 'Forgatás';

  @override
  String get windowed => 'Ablakos';

  @override
  String get fullscreen => 'Teljes képernyő';

  @override
  String get movieDetails => 'Részletek';

  @override
  String get showDetails => 'Részletek mutatása';

  @override
  String get tagline => 'Slogan';

  @override
  String get status => 'Állapot';

  @override
  String get releaseDate => 'Megjelenés';

  @override
  String get firstAirDate => 'Első adás';

  @override
  String get originalLanguage => 'Eredeti nyelv';

  @override
  String get originCountry => 'Származási ország';

  @override
  String get budgetLabel => 'Költségvetés';

  @override
  String get revenueLabel => 'Bevétel';

  @override
  String get paused => 'Szüneteltetve';

  @override
  String get watched => 'Megnézve';

  @override
  String get watching => 'Nézés';

  @override
  String get lastWatched => 'Utoljára';

  @override
  String get movie => 'Film';

  @override
  String get tvShow => 'Sorozat';

  @override
  String get failedToLoadContent => 'Sikertelen betöltés';

  @override
  String get director => 'Rendező';

  @override
  String get creator => 'Alkotó';

  @override
  String get showMore => 'Több';

  @override
  String get showLess => 'Kevesebb';

  @override
  String get viewAll => 'Összes mutatása';

  @override
  String seasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count évad',
      one: '1 évad',
    );
    return '$_temp0';
  }

  @override
  String get noInternetError => 'Nincs internet';

  @override
  String get timeoutError => 'Időtúllépés.';

  @override
  String get serverError => 'Szerverhiba.';

  @override
  String get contentNotFoundError => 'Nem található.';

  @override
  String get accessDeniedError => 'Hozzáférés megtagadva.';

  @override
  String get serviceUnavailableError => 'Szolgáltatás nem elérhető.';

  @override
  String get generalError => 'Hiba történt.';

  @override
  String get skip => 'Kihagyás';

  @override
  String get skipIntro => 'Főcím átugrása';

  @override
  String get skipOutro => 'Stáblista átugrása';

  @override
  String get skipRecap => 'Összefoglaló átugrása';

  @override
  String get goLive => 'Élő adás';

  @override
  String get dismiss => 'Bezárás';

  @override
  String get nextUp => 'Következő';

  @override
  String sourceAttempt(int index, int total) {
    return '$index. forrás / $total';
  }

  @override
  String get trying => 'Próbálkozás';

  @override
  String get failed => 'Sikertelen';

  @override
  String get selected => 'Kiválasztva';

  @override
  String get playing => 'Lejátszás';

  @override
  String get pending => 'Várakozás';

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
  String get mobileQualityPreference => 'Mobilhálózati minőségi preferencia';

  @override
  String get anyNoPreference => 'Nincs preferencia';

  @override
  String get subtitleAccounts => 'Felirat fiókok';

  @override
  String get accounts => 'Fiókok';

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
  String get testConnection => 'Kapcsolat tesztelése';

  @override
  String get connectedSuccessfully => 'Sikeres csatlakozás';

  @override
  String get connectionFailed => 'Sikertelen csatlakozás';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get noAccountRegister => 'Don\'t have an account? Register here';

  @override
  String get apiKey => 'API kulcs';

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
  String get diagnostics => 'Diagnosztika';

  @override
  String get viewLogs => 'Naplók megtekintése';

  @override
  String get viewLogsSubtitle => 'Alkalmazásaktivitás és hibák megtekintése';

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
  String get sourcesSearching => 'Keresés a scraperekben…';

  @override
  String get sourcesEmptyFiltered => 'Egyetlen link sem felel meg a szűrőknek.';

  @override
  String get sourcesEmptyNoTmdbId =>
      'Ehhez a címhez nincs TMDB azonosító. Adja meg a \'Search manually\' ponttal.';

  @override
  String get sourcesEmptyNoScrapers =>
      'Nincs engedélyezett scraper. Adjon hozzá egyet a \'Nuvio Plugins\' alatt.';

  @override
  String get sourcesEmptyAllFailed =>
      'Minden scraper hibázott. Ellenőrizze a kapcsolatot, vagy frissítse őket.';

  @override
  String sourcesEmptySomeFailed(int failed, int total) {
    return 'Nem található link. $total scraperből $failed hibázott.';
  }

  @override
  String get sourcesEmptyNothingFound =>
      'Egyik scraperében sincs meg ez a cím.';

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
