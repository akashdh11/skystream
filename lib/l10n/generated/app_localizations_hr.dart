// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Croatian (`hr`).
class AppLocalizationsHr extends AppLocalizations {
  AppLocalizationsHr([String locale = 'hr']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => 'Hrvatski';

  @override
  String get home => 'Početna';

  @override
  String get search => 'Pretraživanje';

  @override
  String get explore => 'Istraži';

  @override
  String get exploreAnime => 'Istraži anime';

  @override
  String get exploreMovies => 'Istraži filmove';

  @override
  String get library => 'Knjižnica';

  @override
  String get settings => 'Postavke';

  @override
  String get extensions => 'Proširenja';

  @override
  String get updateAvailable => 'Dostupno ažuriranje';

  @override
  String get retry => 'Pokušaj ponovno';

  @override
  String get factoryReset => 'Vraćanje na tvorničke postavke';

  @override
  String get startupError => 'Pogreška pri pokretanju';

  @override
  String get general => 'Opće';

  @override
  String get appTheme => 'Tema aplikacije';

  @override
  String get recordWatchHistory => 'Snimaj povijest gledanja';

  @override
  String get defaultHomeScreen => 'Zadani početni zaslon';

  @override
  String get titlePosition => 'Položaj naslova';

  @override
  String get titlePositionBelowPoster => 'Ispod plakata';

  @override
  String get titlePositionInsidePoster => 'Na plakatu';

  @override
  String get player => 'Reproduktor';

  @override
  String get defaultPlayer => 'Zadani reproduktor';

  @override
  String get leftGesture => 'Lijeva gesta';

  @override
  String get rightGesture => 'Desna gesta';

  @override
  String get doubleTapToSeek => 'Dvaput dodirnite za traženje';

  @override
  String get swipeToSeek => 'Povucite za traženje';

  @override
  String get seekDuration => 'Trajanje traženja';

  @override
  String get bufferDepth => 'Dubina međuspremnika';

  @override
  String get defaultResizeMode => 'Zadani način promjene veličine';

  @override
  String get hardwareDecoding => 'Hardversko dekodiranje';

  @override
  String get network => 'Mreža';

  @override
  String get dnsOverHttps => 'DNS preko HTTPS-a';

  @override
  String get dohProvider => 'DoH pružatelj';

  @override
  String get githubProxy => 'GitHub proxy';

  @override
  String get githubProxySubtitle =>
      'Preusmjeri preuzimanja proširenja preko jsDelivra radi zaobilaženja blokada pružatelja.';

  @override
  String get manageExtensions => 'Upravljanje proširenjima';

  @override
  String get appData => 'Podaci aplikacije';

  @override
  String get resetDataKeepExtensions => 'Resetiraj podatke (zadrži proširenja)';

  @override
  String get developer => 'Razvijatelj';

  @override
  String get developerOptions => 'Opcije za razvijatelje';

  @override
  String get about => 'O aplikaciji';

  @override
  String get version => 'Verzija';

  @override
  String get enabled => 'Omogućeno';

  @override
  String get disabled => 'Onemogućeno';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'Pridružite se našem poslužitelju';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'Pridružite se našem kanalu';

  @override
  String developedBy(String name) {
    return 'Developed by $name';
  }

  @override
  String get system => 'Sustav';

  @override
  String get dark => 'Tamno';

  @override
  String get light => 'Svijetlo';

  @override
  String get later => 'Kasnije';

  @override
  String get updateNow => 'Ažuriraj sada';

  @override
  String get save => 'Spremi';

  @override
  String get cancel => 'Odustani';

  @override
  String get close => 'Zatvori';

  @override
  String get delete => 'Izbriši';

  @override
  String get viewDetails => 'Vidi detalje';

  @override
  String get clearAll => 'Očisti sve';

  @override
  String get clearAllHistory => 'Očisti povijest';

  @override
  String get all => 'Sve';

  @override
  String get none => 'Nijedan';

  @override
  String get confirmDownload => 'Potvrdi preuzimanje';

  @override
  String get downloadNow => 'Preuzmi sada';

  @override
  String get selectSource => 'Odaberi izvor';

  @override
  String get downloadUnavailable => 'Nedostupno';

  @override
  String get selectAnotherSource => 'Odaberi drugi';

  @override
  String get watchHistoryCleared => 'Povijest gledanja očišćena';

  @override
  String get downloadingUpdate => 'Preuzimanje ažuriranja...';

  @override
  String errorPrefix(String message) {
    return 'Pogreška: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'Dostupno ažuriranje: $tag';
  }

  @override
  String get selectProviderToStart => 'Odaberite pružatelja za početak';

  @override
  String get tapExtensionIcon => 'Dodirnite ikonu proširenja u kutu';

  @override
  String get continueWatching => 'Nastavi gledati';

  @override
  String get noInternetConnection => 'Nema internetske veze';

  @override
  String get siteNotReachable => 'Stranica nije dostupna';

  @override
  String get checkConnectionOrDownloads =>
      'Provjerite vezu ili pogledajte preuzimanja.';

  @override
  String get tryVpnOrConnection => 'Pokušajte s VPN-om ili provjerite vezu.';

  @override
  String errorDetails(String error) {
    return 'Detalji pogreške: $error';
  }

  @override
  String get goToDownloads => 'Idi na preuzimanja';

  @override
  String get selectProvider => 'Odaberi pružatelja';

  @override
  String get searchHint => 'Traži filmove, serije...';

  @override
  String get searchFavoriteContent => 'Pretražite omiljeni sadržaj';

  @override
  String get pressSearchOrEnter => 'Pritisnite Pretraživanje ili Enter';

  @override
  String get noResultsFound => 'Nema rezultata.';

  @override
  String get couldNotLoadTrending => 'Neuspjelo učitavanje trendova';

  @override
  String get popularMovies => 'Popularni filmovi';

  @override
  String get popularTVShows => 'Popularne serije';

  @override
  String get newMovies => 'Novi filmovi';

  @override
  String get newTVShows => 'Nove serije';

  @override
  String get featuredMovies => 'Izdvojeni filmovi';

  @override
  String get featuredTVShows => 'Izdvojene serije';

  @override
  String get lastVideosTVShows => 'Zadnji videozapisi';

  @override
  String get downloads => 'Preuzimanja';

  @override
  String get bookmarks => 'Oznake';

  @override
  String get noDownloadsYet => 'Još nema preuzimanja';

  @override
  String episodesCount(int count, int done) {
    return '$count epizoda • $done dovršeno';
  }

  @override
  String get deleteAllEpisodes => 'Izbriši sve epizode';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return 'Jeste li sigurni da želite izbrisati svih $count epizoda serije \"$title\"?';
  }

  @override
  String get deleteAll => 'Izbriši sve';

  @override
  String get completed => 'Dovršeno';

  @override
  String get statusQueued => 'U redu...';

  @override
  String get statusDownloading => 'Preuzimanje...';

  @override
  String get statusFinished => 'Završeno';

  @override
  String get statusFailed => 'Neuspjelo';

  @override
  String get statusCanceled => 'Otkazano';

  @override
  String get statusPaused => 'Pauzirano';

  @override
  String get statusWaiting => 'Čekanje...';

  @override
  String get fileNotFoundRemoving =>
      'Datoteka nije pronađena. Uklanjanje zapisa.';

  @override
  String get fileNotFound => 'Datoteka nije pronađena';

  @override
  String get deleteDownload => 'Izbriši preuzimanje';

  @override
  String get confirmDeleteDownload =>
      'Jeste li sigurni da želite izbrisati ovo preuzimanje?';

  @override
  String get libraryEmpty => 'Vaša knjižnica je prazna';

  @override
  String get language => 'Jezik';

  @override
  String get english => 'Engleski';

  @override
  String get hindi => 'Hindski';

  @override
  String get kannada => 'Kanada';

  @override
  String get unknown => 'Nepoznato';

  @override
  String get recommended => 'Preporučeno';

  @override
  String get on => 'Uključeno';

  @override
  String get off => 'Isključeno';

  @override
  String get installRemoveProviders => 'Instaliraj ili ukloni pružatelje';

  @override
  String get resetDataSubtitle => 'Očisti postavke i bazu, zadrži plagine';

  @override
  String get factoryResetSubtitle =>
      'Izbriši sve podatke, postavke i proširenja';

  @override
  String get developerOptionsSubtitle => 'Alati za otklanjanje pogrešaka';

  @override
  String get loading => 'Učitavanje...';

  @override
  String get sec => 'sek';

  @override
  String get min => 'min';

  @override
  String get internalPlayer => 'Interni (media_kit)';

  @override
  String get builtInPlayer => 'Ugrađeni reproduktor';

  @override
  String get customNotSet => 'Prilagođeno (nije postavljeno)';

  @override
  String selectGesture(String side) {
    return 'Odaberi $side gestu';
  }

  @override
  String get left => 'Lijevo';

  @override
  String get right => 'Desno';

  @override
  String get selectSeekDuration => 'Odaberi trajanje traženja';

  @override
  String get selectBufferDepth => 'Odaberi dubinu međuspremnika';

  @override
  String get subtitleSettings => 'Postavke titlova';

  @override
  String size(int size) {
    return 'Veličina: $size';
  }

  @override
  String get background => 'Pozadina';

  @override
  String get customDohUrlLabel => 'Prilagođeni DoH URL';

  @override
  String get enterCustomDohUrl => 'Unesite svoj DoH URL';

  @override
  String get chooseTheme => 'Odaberi temu';

  @override
  String get resetDataDialogTitle => 'Resetiraj podatke?';

  @override
  String get resetDataDialogContent =>
      'Ovo će očistiti Postavke, Omiljene i Povijest. Proširenja NEĆE biti izbrisana.';

  @override
  String get factoryResetDialogTitle => 'Tvornički reset?';

  @override
  String get factoryResetDialogContent =>
      'Ovo će izbrisati SVE. Akcija je nepovratna.';

  @override
  String get selectLanguage => 'Odaberi jezik';

  @override
  String get synopsis => 'Sinopsis';

  @override
  String get noDescription => 'Opis nije dostupan.';

  @override
  String get videoAlreadyDownloadedPrompt =>
      'Ovaj video je već preuzet. Što želite učiniti?';

  @override
  String get playNow => 'Gledaj sada';

  @override
  String get upNext => 'Slijedi';

  @override
  String get deleteDownloadPrompt => 'Izbrisati preuzimanje?';

  @override
  String get deleteDownloadConfirmation =>
      'Jeste li sigurni? Ovo se ne može poništiti.';

  @override
  String get no => 'Ne';

  @override
  String get yesDelete => 'Da, izbriši';

  @override
  String get downloadPaused => 'Preuzimanje pauzirano';

  @override
  String get downloading => 'Preuzimanje';

  @override
  String get speed => 'Brzina';

  @override
  String get remaining => 'Preostalo';

  @override
  String get resume => 'Nastavi';

  @override
  String get pause => 'Pauziraj';

  @override
  String get torrentContent => 'Sadržaj torrenta';

  @override
  String get audioTracks => 'Audio zapisi';

  @override
  String get noAudioTracks => 'Nisu pronađeni audio zapisi';

  @override
  String get subtitles => 'Titlovi';

  @override
  String get options => 'Opcije';

  @override
  String get noSubtitlesFound => 'Nisu pronađeni titlovi';

  @override
  String get playbackSpeed => 'Brzina reprodukcije';

  @override
  String get subtitleOptions => 'Opcije titlova';

  @override
  String get hlsSubtitleWarning =>
      'Vanjski titlovi nisu podržani na ovoj platformi uz HLS.';

  @override
  String get loadFromDevice => 'Učitaj s uređaja';

  @override
  String get syncDelay => 'Sinkronizacija / Odgoda';

  @override
  String get styleSettings => 'Postavke stila';

  @override
  String get searchOnline => 'Pretraži online';

  @override
  String get subtitleSync => 'Sinkronizacija titlova';

  @override
  String get subtitleDelayWarning =>
      'Odgoda titlova nije podržana u trenutnom reproduktoru.';

  @override
  String get resetDelay => 'Resetiraj odgodu';

  @override
  String get subtitleStyles => 'Stilovi titlova';

  @override
  String get mediaKitStylingWarning =>
      'Stiliziranje titlova trenutno je dostupno samo za media_kit.';

  @override
  String get resetToDefault => 'Vrati na zadano';

  @override
  String get fontSize => 'Veličina fonta';

  @override
  String get verticalPosition => 'Vertikalna pozicija';

  @override
  String get textColor => 'Boja tekstu';

  @override
  String get backgroundColor => 'Boja pozadine';

  @override
  String get backgroundOpacity => 'Prozirnost pozadine';

  @override
  String get subtitleSearch => 'Pretraživanje titlova';

  @override
  String get searchSubtitleNameHint => 'Naziv titlova...';

  @override
  String get enterSearchSubtitlePrompt => 'Unesite naziv za pretraživanje.';

  @override
  String get noSubtitleResults => 'Nema rezultata.';

  @override
  String get downloadingApplyingSubtitle => 'Preuzimanje i primjena...';

  @override
  String get failedToDownloadSubtitle => 'Neuspjelo preuzimanje titlova.';

  @override
  String get failedToLoadSubtitles => 'Neuspjelo učitavanje titlova.';

  @override
  String get noReposFound => 'Nisu pronađena skladišta';

  @override
  String get downloadAllProviders => 'Preuzmi sve';

  @override
  String get removeRepository => 'Ukloni skladište';

  @override
  String get addRepo => 'Dodaj skladište';

  @override
  String get extensionsNotInRepos => 'Proširenja izvan skladišta';

  @override
  String get noLongerInRepo => 'Više nije na popisu';

  @override
  String get addRepoToBrowse => 'Dodajte skladište za pregled';

  @override
  String get debugExtensions => 'Otklanjanje pogrešaka';

  @override
  String removeRepoConfirm(String repoName) {
    return 'Ukloni $repoName?';
  }

  @override
  String get removeRepoWarning => 'Ovo će deinstalirati SVE njegove plagine.';

  @override
  String get addRepository => 'Dodaj skladište';

  @override
  String get repoUrlOrShortcode => 'URL ili kratki kod';

  @override
  String get assetPlugin => 'Ugrađeni plagin';

  @override
  String get installed => 'Instalirano';

  @override
  String get repositories => 'Repozitoriji';

  @override
  String get noExtensionsInstalled => 'Nema instaliranih proširenja';

  @override
  String get browseRepositoriesToInstall =>
      'Otvorite karticu Repozitoriji za pronalaženje i instaliranje proširenja.';

  @override
  String get browseRepositories => 'Pregledaj repozitorije';

  @override
  String get addRepoDescription =>
      'Dodajte URL repozitorija ili kratki kôd za pronalaženje i instaliranje dodataka.';

  @override
  String updateTo(String version) {
    return 'Ažuriraj na $version';
  }

  @override
  String get install => 'Instaliraj';

  @override
  String get error => 'Pogreška';

  @override
  String get ok => 'U redu';

  @override
  String pluginSettings(String pluginName) {
    return '$pluginName postavke';
  }

  @override
  String get movies => 'Filmovi';

  @override
  String get series => 'Serije';

  @override
  String get anime => 'Anime';

  @override
  String get liveStreams => 'Uživo';

  @override
  String get debug => 'DEBUG';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count proširenja ažurirano',
      few: '$count proširenja ažurirana',
      one: '1 proširenje ažurirano',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => 'Neispravna navigacija.';

  @override
  String get startOver => 'Počni ponovno';

  @override
  String get goBack => 'Natrag';

  @override
  String get resolving => 'Rješavanje...';

  @override
  String get downloaded => 'Preuzeto';

  @override
  String get download => 'Preuzmi';

  @override
  String get debugOnlyFeature => 'Samo za razvojne verzije';

  @override
  String get streamUrl => 'URL streama';

  @override
  String get play => 'Reproduciraj';

  @override
  String get verifyingSourceSize => 'Provjera...';

  @override
  String get fileSaveLocationNotification =>
      'Datoteka će biti spremljena u mapu Preuzimanja.';

  @override
  String get resumingPlayback => 'Nastavak reprodukcije';

  @override
  String pausedAt(String time) {
    return 'Pauzirano na $time';
  }

  @override
  String resumesAutomatically(int count) {
    return 'Automatski za $count sek';
  }

  @override
  String get resumeNow => 'Nastavi sada';

  @override
  String get playbackError => 'Pogreška pri reprodukciji';

  @override
  String get confirmClearHistory => 'Očistiti cijelu povijest?';

  @override
  String seasonWithNumber(Object number) {
    return 'Sezona $number';
  }

  @override
  String get starting => 'Pokretanje...';

  @override
  String percentWatched(int percent) {
    return '$percent% pogledano';
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
  String get debugTools => 'Alati za otklanjanje pogrešaka';

  @override
  String get playLocalVideo => 'Lokalni video';

  @override
  String get playLocalVideoSubtitle => 'Pokreni s uređaja';

  @override
  String get streamUrlSubtitle => 'Pokreni s URL-a';

  @override
  String get streamTorrent => 'Streamaj torrent';

  @override
  String get streamTorrentSubtitle => 'Odaberite torrent datoteku';

  @override
  String get loadPluginFromAssets => 'Učitaj iz resursa';

  @override
  String get enterVideoUrlHint => 'URL videozapisa';

  @override
  String get networkStream => 'Mrežni stream';

  @override
  String removedFromHistory(String title) {
    return 'Uklonjeno: $title';
  }

  @override
  String get custom => 'Prilagođeno';

  @override
  String get refreshingLiveStream => 'Osvježavanje...';

  @override
  String get removeFromHistory => 'Ukloni iz povijesti';

  @override
  String get live => 'UŽIVO';

  @override
  String get volume => 'Glasnoća';

  @override
  String get brightness => 'Svjetlina';

  @override
  String get fit => 'Prilagodi';

  @override
  String get zoom => 'Uvećaj';

  @override
  String get stretch => 'Rastegni';

  @override
  String titleWithParam(String title) {
    return 'Naslov: $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'Izvor: $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'Veličina: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'Pogreška: $error. Interni reproduktor.';
  }

  @override
  String playerNotDetected(String playerName) {
    return '$playerName nije pronađen.';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return 'Sezona $number ($count ep.)';
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
    return 'Izvor za $playerName';
  }

  @override
  String get noPluginsInstalled => 'Nema instaliranih plagina';

  @override
  String get noPluginsMessage =>
      'Instalirajte proširenja za pregledavanje i strujanje sadržaja.';

  @override
  String get goToExtensions => 'Idi na proširenja';

  @override
  String get availableSources => 'Dostupni izvori';

  @override
  String get seasons => 'Sezone';

  @override
  String get episodes => 'Epizode';

  @override
  String get selectSourceToPlay => 'Odaberite izvor za gledanje.';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count epizoda',
      few: '$count epizode',
      one: '1 epizoda',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'Epizode nisu pronađene';

  @override
  String get local => 'Lokalno';

  @override
  String get remote => 'Udaljeno';

  @override
  String get torrent => 'Torrent';

  @override
  String get unlock => 'Otključaj';

  @override
  String get lock => 'Zaključaj';

  @override
  String get sources => 'Izvori';

  @override
  String get tracks => 'Zapisi';

  @override
  String get content => 'Sadržaj';

  @override
  String get stats => 'Statistika';

  @override
  String get resize => 'Veličina';

  @override
  String get next => 'Sljedeće';

  @override
  String get pip => 'PiP';

  @override
  String get rotate => 'Rotiraj';

  @override
  String get windowed => 'Prozor';

  @override
  String get fullscreen => 'Cijeli zaslon';

  @override
  String get movieDetails => 'Detalji';

  @override
  String get showDetails => 'Prikaži detalje';

  @override
  String get tagline => 'Slogan';

  @override
  String get status => 'Status';

  @override
  String get releaseDate => 'Datum izlaska';

  @override
  String get firstAirDate => 'Prvo emitiranje';

  @override
  String get originalLanguage => 'Izvorni jezik';

  @override
  String get originCountry => 'Zemlja podrijetla';

  @override
  String get budgetLabel => 'Proračun';

  @override
  String get revenueLabel => 'Prihod';

  @override
  String get paused => 'Pauzirano';

  @override
  String get watched => 'Pogledano';

  @override
  String get watching => 'Gledam';

  @override
  String get lastWatched => 'Zadnje';

  @override
  String get movie => 'Film';

  @override
  String get tvShow => 'Serija';

  @override
  String get failedToLoadContent => 'Neuspjelo učitavanje';

  @override
  String get director => 'Redatelj';

  @override
  String get creator => 'Autor';

  @override
  String get showMore => 'Više';

  @override
  String get showLess => 'Manje';

  @override
  String get viewAll => 'Vidi sve';

  @override
  String seasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sezona',
      few: '$count sezone',
      one: '1 sezona',
    );
    return '$_temp0';
  }

  @override
  String get noInternetError => 'Nema interneta';

  @override
  String get timeoutError => 'Vrijeme je isteklo.';

  @override
  String get serverError => 'Pogreška poslužitelja.';

  @override
  String get contentNotFoundError => 'Nije pronađeno.';

  @override
  String get accessDeniedError => 'Pristup odbijen.';

  @override
  String get serviceUnavailableError => 'Usluga nedostupna.';

  @override
  String get generalError => 'Greška.';

  @override
  String get skip => 'Preskoči';

  @override
  String get skipIntro => 'Preskoči uvod';

  @override
  String get skipOutro => 'Preskoči odjavnu špicu';

  @override
  String get skipRecap => 'Preskoči sažetak';

  @override
  String get goLive => 'Uživo';

  @override
  String get dismiss => 'Zatvori';

  @override
  String get nextUp => 'Sljedeće';

  @override
  String sourceAttempt(int index, int total) {
    return 'Pokušaj $index od $total';
  }

  @override
  String get trying => 'Pokušaj';

  @override
  String get failed => 'Neuspjelo';

  @override
  String get selected => 'Odabrano';

  @override
  String get playing => 'Reprodukcija';

  @override
  String get pending => 'Na čekanju';

  @override
  String get openSubtitles => 'OpenSubtitles';

  @override
  String get subDl => 'SubDL';

  @override
  String get subSource => 'SubSource';

  @override
  String get wifiQualityPreference => 'Kvaliteta na Wi-Fi mreži';

  @override
  String get mobileQualityPreference => 'Kvaliteta na mobilnoj mreži';

  @override
  String get anyNoPreference => 'Bez preferencije';

  @override
  String get subtitleAccounts => 'Računi za titlove';

  @override
  String get accounts => 'Računi';

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
  String get testConnection => 'Testiraj vezu';

  @override
  String get connectedSuccessfully => 'Uspješno povezano';

  @override
  String get connectionFailed => 'Povezivanje neuspješno';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get noAccountRegister => 'Don\'t have an account? Register here';

  @override
  String get apiKey => 'API ključ';

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
  String get diagnostics => 'Dijagnostika';

  @override
  String get viewLogs => 'Vidi zapisnike';

  @override
  String get viewLogsSubtitle => 'Vidi aktivnost aplikacije i pogreške';

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
