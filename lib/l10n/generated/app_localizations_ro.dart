// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Romanian Moldavian Moldovan (`ro`).
class AppLocalizationsRo extends AppLocalizations {
  AppLocalizationsRo([String locale = 'ro']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => 'Română';

  @override
  String get home => 'Acasă';

  @override
  String get search => 'Căutare';

  @override
  String get explore => 'Explorează';

  @override
  String get exploreAnime => 'Explorează anime';

  @override
  String get exploreMovies => 'Explorează filme';

  @override
  String get library => 'Bibliotecă';

  @override
  String get settings => 'Setări';

  @override
  String get extensions => 'Extensii';

  @override
  String get updateAvailable => 'Actualizare disponibilă';

  @override
  String get retry => 'Reîncearcă';

  @override
  String get factoryReset => 'Resetare completă';

  @override
  String get startupError => 'Eroare de pornire';

  @override
  String get general => 'General';

  @override
  String get appTheme => 'Tema aplicației';

  @override
  String get recordWatchHistory => 'Înregistrează istoricul vizionărilor';

  @override
  String get defaultHomeScreen => 'Ecran principal implicit';

  @override
  String get titlePosition => 'Poziția titlului';

  @override
  String get titlePositionBelowPoster => 'Sub poster';

  @override
  String get titlePositionInsidePoster => 'Pe poster';

  @override
  String get player => 'Player';

  @override
  String get defaultPlayer => 'Player implicit';

  @override
  String get leftGesture => 'Gest stânga';

  @override
  String get rightGesture => 'Gest dreapta';

  @override
  String get doubleTapToSeek => 'Atingere dublă pentru derulare';

  @override
  String get swipeToSeek => 'Glisare pentru derulare';

  @override
  String get seekDuration => 'Durata derulării';

  @override
  String get bufferDepth => 'Adâncimea bufferului';

  @override
  String get defaultResizeMode => 'Mod de redimensionare implicit';

  @override
  String get hardwareDecoding => 'Decodare hardware';

  @override
  String get network => 'Rețea';

  @override
  String get dnsOverHttps => 'DNS prin HTTPS';

  @override
  String get dohProvider => 'Furnizor DoH';

  @override
  String get githubProxy => 'Proxy GitHub';

  @override
  String get githubProxySubtitle =>
      'Rutează descărcările de extensii prin jsDelivr pentru a ocoli blocajele furnizorului.';

  @override
  String get manageExtensions => 'Gestionare extensii';

  @override
  String get appData => 'Date aplicație';

  @override
  String get resetDataKeepExtensions => 'Resetare date (păstrează extensiile)';

  @override
  String get developer => 'Dezvoltator';

  @override
  String get developerOptions => 'Opțiuni dezvoltator';

  @override
  String get about => 'Despre';

  @override
  String get version => 'Versiune';

  @override
  String get enabled => 'Activat';

  @override
  String get disabled => 'Dezactivat';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'Alăturați-vă serverului nostru';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'Alăturați-vă canalului nostru';

  @override
  String developedBy(String name) {
    return 'Developed by $name';
  }

  @override
  String get system => 'Sistem';

  @override
  String get dark => 'Întunecat';

  @override
  String get light => 'Luminos';

  @override
  String get later => 'Mai târziu';

  @override
  String get updateNow => 'Actualizează acum';

  @override
  String get save => 'Salvează';

  @override
  String get cancel => 'Anulează';

  @override
  String get close => 'Închide';

  @override
  String get delete => 'Șterge';

  @override
  String get viewDetails => 'Vezi detalii';

  @override
  String get clearAll => 'Șterge tot';

  @override
  String get clearAllHistory => 'Șterge tot istoricul';

  @override
  String get all => 'Toate';

  @override
  String get none => 'Niciunul';

  @override
  String get confirmDownload => 'Confirmă descărcarea';

  @override
  String get downloadNow => 'Descarcă acum';

  @override
  String get selectSource => 'Selectează sursa';

  @override
  String get downloadUnavailable => 'Indisponibil';

  @override
  String get selectAnotherSource => 'Selectează alta';

  @override
  String get watchHistoryCleared => 'Istoricul vizionărilor a fost șters';

  @override
  String get downloadingUpdate => 'Se descarcă actualizarea...';

  @override
  String errorPrefix(String message) {
    return 'Eroare: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'Actualizare disponibilă: $tag';
  }

  @override
  String get selectProviderToStart => 'Selectează un furnizor pentru a începe';

  @override
  String get tapExtensionIcon => 'Atinge pictograma extensiei din colț';

  @override
  String get continueWatching => 'Continuă vizionarea';

  @override
  String get noInternetConnection => 'Fără conexiune la internet';

  @override
  String get siteNotReachable => 'Site-ul nu poate fi accesat';

  @override
  String get checkConnectionOrDownloads =>
      'Verifică conexiunea sau vizualizează conținutul descărcat.';

  @override
  String get tryVpnOrConnection =>
      'Încearcă să accesezi folosind un VPN sau verifică conexiunea.';

  @override
  String errorDetails(String error) {
    return 'Detalii eroare: $error';
  }

  @override
  String get goToDownloads => 'Mergi la descărcări';

  @override
  String get selectProvider => 'Selectează furnizorul';

  @override
  String get searchHint => 'Caută filme, seriale...';

  @override
  String get searchFavoriteContent => 'Caută conținutul preferat';

  @override
  String get pressSearchOrEnter =>
      'Apasă tasta Căutare sau Enter pentru a începe';

  @override
  String get noResultsFound => 'Nu s-au găsit rezultate.';

  @override
  String get couldNotLoadTrending => 'Nu s-au putut încărca tendințele';

  @override
  String get popularMovies => 'Filme populare';

  @override
  String get popularTVShows => 'Seriale populare';

  @override
  String get newMovies => 'Filme noi';

  @override
  String get newTVShows => 'Seriale noi';

  @override
  String get featuredMovies => 'Filme recomandate';

  @override
  String get featuredTVShows => 'Seriale recomandate';

  @override
  String get lastVideosTVShows => 'Ultimele videoclipuri';

  @override
  String get downloads => 'Descărcări';

  @override
  String get bookmarks => 'Favorite';

  @override
  String get noDownloadsYet => 'Nicio descărcare încă';

  @override
  String episodesCount(int count, int done) {
    return '$count Episoade • $done Finalizate';
  }

  @override
  String get deleteAllEpisodes => 'Șterge toate episoadele';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return 'Sigur dorești să ștergi toate cele $count episoade din „$title” și fișierele lor?';
  }

  @override
  String get deleteAll => 'Șterge tot';

  @override
  String get completed => 'Finalizat';

  @override
  String get statusQueued => 'În coadă...';

  @override
  String get statusDownloading => 'Se descarcă...';

  @override
  String get statusFinished => 'Finalizat';

  @override
  String get statusFailed => 'Eșuat';

  @override
  String get statusCanceled => 'Anulat';

  @override
  String get statusPaused => 'Pauzat';

  @override
  String get statusWaiting => 'În așteptare...';

  @override
  String get fileNotFoundRemoving =>
      'Fișierul nu a fost găsit. Se șterge înregistrarea.';

  @override
  String get fileNotFound => 'Fișierul nu a fost găsit';

  @override
  String get deleteDownload => 'Șterge descărcarea';

  @override
  String get confirmDeleteDownload =>
      'Sigur dorești să ștergi această descărcare?';

  @override
  String get libraryEmpty => 'Biblioteca ta este goală';

  @override
  String get language => 'Limbă';

  @override
  String get english => 'Engleză';

  @override
  String get hindi => 'Hindi';

  @override
  String get kannada => 'Kannada';

  @override
  String get unknown => 'Necunoscut';

  @override
  String get recommended => 'Recomandat';

  @override
  String get on => 'Pornit';

  @override
  String get off => 'Oprit';

  @override
  String get installRemoveProviders => 'Instalează sau elimină furnizori';

  @override
  String get resetDataSubtitle =>
      'Șterge setările și baza de date, păstrează plugin-urile';

  @override
  String get factoryResetSubtitle =>
      'Șterge toate datele, setările și extensiile';

  @override
  String get developerOptionsSubtitle =>
      'Instrumente de depanare și redare locală';

  @override
  String get loading => 'Se încarcă...';

  @override
  String get sec => 'sec';

  @override
  String get min => 'min';

  @override
  String get internalPlayer => 'Intern (media_kit)';

  @override
  String get builtInPlayer => 'Player încorporat';

  @override
  String get customNotSet => 'Personalizat (nesetat)';

  @override
  String selectGesture(String side) {
    return 'Selectează gest $side';
  }

  @override
  String get left => 'Stânga';

  @override
  String get right => 'Dreapta';

  @override
  String get selectSeekDuration => 'Selectează durata derulării';

  @override
  String get selectBufferDepth => 'Selectează adâncimea bufferului';

  @override
  String get subtitleSettings => 'Setări subtitrări';

  @override
  String size(int size) {
    return 'Dimensiune: $size';
  }

  @override
  String get background => 'Fundal';

  @override
  String get customDohUrlLabel => 'URL DoH personalizat';

  @override
  String get enterCustomDohUrl => 'Introdu propria URL DoH';

  @override
  String get chooseTheme => 'Alege tema';

  @override
  String get resetDataDialogTitle => 'Resetezi datele?';

  @override
  String get resetDataDialogContent =>
      'Această acțiune va șterge Setările, Favoritele și Istoricul. Extensiile instalate NU vor fi șterse.';

  @override
  String get factoryResetDialogTitle => 'Resetare completă?';

  @override
  String get factoryResetDialogContent =>
      'Această acțiune va șterge TOTUL. Acțiunea este ireversibilă.';

  @override
  String get selectLanguage => 'Selectează limba';

  @override
  String get synopsis => 'Sinopsis';

  @override
  String get noDescription => 'Nicio descriere disponibilă.';

  @override
  String get videoAlreadyDownloadedPrompt =>
      'Acest videoclip este deja descărcat. Ce dorești să faci?';

  @override
  String get playNow => 'Redă acum';

  @override
  String get upNext => 'Urmează';

  @override
  String get deleteDownloadPrompt => 'Ștergi descărcarea?';

  @override
  String get deleteDownloadConfirmation =>
      'Sigur dorești să ștergi acest fișier? Acțiunea este ireversibilă.';

  @override
  String get no => 'Nu';

  @override
  String get yesDelete => 'Da, șterge';

  @override
  String get downloadPaused => 'Descărcare pauzată';

  @override
  String get downloading => 'Se descarcă';

  @override
  String get speed => 'Viteză';

  @override
  String get remaining => 'Rămas';

  @override
  String get resume => 'Reluare';

  @override
  String get pause => 'Pauză';

  @override
  String get torrentContent => 'Conținut torrent';

  @override
  String get audioTracks => 'Piste audio';

  @override
  String get noAudioTracks => 'Nicio pistă audio găsită';

  @override
  String get subtitles => 'Subtitrări';

  @override
  String get options => 'Opțiuni';

  @override
  String get noSubtitlesFound => 'Nicio subtitrare găsită';

  @override
  String get playbackSpeed => 'Viteză de redare';

  @override
  String get subtitleOptions => 'Opțiuni subtitrare';

  @override
  String get hlsSubtitleWarning =>
      'Subtitrările externe nu sunt suportate pentru HLS pe această platformă.';

  @override
  String get loadFromDevice => 'Încarcă de pe dispozitiv';

  @override
  String get syncDelay => 'Sincronizare / Întârziere';

  @override
  String get styleSettings => 'Setări stil';

  @override
  String get searchOnline => 'Caută online (căutare subtitrări)';

  @override
  String get subtitleSync => 'Sincronizare subtitrare';

  @override
  String get subtitleDelayWarning =>
      'Întârzierea subtitrării nu este suportată de motorul de redare actual.';

  @override
  String get resetDelay => 'Resetează întârzierea';

  @override
  String get subtitleStyles => 'Stiluri subtitrare';

  @override
  String get mediaKitStylingWarning =>
      'Stilizarea subtitrărilor este disponibilă momentan doar pentru player-ul media_kit.';

  @override
  String get resetToDefault => 'Resetează la implicit';

  @override
  String get fontSize => 'Dimensiune font';

  @override
  String get verticalPosition => 'Poziție verticală';

  @override
  String get textColor => 'Culoare text';

  @override
  String get backgroundColor => 'Culoare fundal';

  @override
  String get backgroundOpacity => 'Opacitate fundal';

  @override
  String get subtitleSearch => 'Căutare subtitrare';

  @override
  String get searchSubtitleNameHint => 'Nume subtitrare...';

  @override
  String get enterSearchSubtitlePrompt =>
      'Introdu un nume pentru a căuta subtitrări.';

  @override
  String get noSubtitleResults => 'Niciun rezultat găsit.';

  @override
  String get downloadingApplyingSubtitle =>
      'Se descarcă și se aplică subtitrarea...';

  @override
  String get failedToDownloadSubtitle => 'Descărcarea subtitrării a eșuat.';

  @override
  String get failedToLoadSubtitles =>
      'Încărcarea subtitrărilor a eșuat. Încearcă din nou.';

  @override
  String get noReposFound => 'Nu s-au găsit depozite sau plugin-uri';

  @override
  String get downloadAllProviders => 'Descarcă tot';

  @override
  String get removeRepository => 'Elimină depozitul';

  @override
  String get addRepo => 'Adaugă depozit';

  @override
  String get extensionsNotInRepos => 'Extensii care nu sunt în depozite';

  @override
  String get noLongerInRepo => 'Nu mai apare în niciun depozit';

  @override
  String get addRepoToBrowse => 'Adaugă un depozit pentru a explora plugin-uri';

  @override
  String get debugExtensions => 'Depanare extensii';

  @override
  String removeRepoConfirm(String repoName) {
    return 'Elimini $repoName?';
  }

  @override
  String get removeRepoWarning =>
      'Această acțiune va elimina depozitul și va dezinstala TOATE plugin-urile sale.';

  @override
  String get addRepository => 'Adăugare depozit';

  @override
  String get repoUrlOrShortcode => 'URL depozit sau cod scurt';

  @override
  String get assetPlugin => 'Plugin activ';

  @override
  String get installed => 'Instalat';

  @override
  String get repositories => 'Depozite';

  @override
  String get noExtensionsInstalled => 'Nicio extensie instalată';

  @override
  String get browseRepositoriesToInstall =>
      'Deschide fila Depozite pentru a descoperi și instala extensii.';

  @override
  String get browseRepositories => 'Explorează depozitele';

  @override
  String get addRepoDescription =>
      'Adaugă URL-ul unui depozit sau un cod scurt pentru a descoperi și instala pluginuri de extensie.';

  @override
  String updateTo(String version) {
    return 'Actualizează la $version';
  }

  @override
  String get install => 'Instalează';

  @override
  String get error => 'Eroare';

  @override
  String get ok => 'OK';

  @override
  String pluginSettings(String pluginName) {
    return 'Setări $pluginName';
  }

  @override
  String get movies => 'Filme';

  @override
  String get series => 'Seriale';

  @override
  String get anime => 'Anime';

  @override
  String get liveStreams => 'Fluxuri live';

  @override
  String get debug => 'DEBUG';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de extensii actualizate',
      few: '$count extensii actualizate',
      one: '1 extensie actualizată',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => 'Navigare invalidă.';

  @override
  String get startOver => 'Reîncepe';

  @override
  String get goBack => 'Înapoi';

  @override
  String get resolving => 'Se rezolvă...';

  @override
  String get downloaded => 'Descărcat';

  @override
  String get download => 'Descarcă';

  @override
  String get debugOnlyFeature =>
      'Această funcție este disponibilă doar în versiunile de depanare';

  @override
  String get streamUrl => 'URL flux';

  @override
  String get play => 'Redă';

  @override
  String get verifyingSourceSize => 'Se verifică sursa și dimensiunea...';

  @override
  String get fileSaveLocationNotification =>
      'Fișierul va fi salvat în folderul Descărcări.';

  @override
  String get resumingPlayback => 'Se reia redarea';

  @override
  String pausedAt(String time) {
    return 'Pauzat la $time';
  }

  @override
  String resumesAutomatically(int count) {
    return 'Se reia automat în $count secunde';
  }

  @override
  String get resumeNow => 'Reluare acum';

  @override
  String get playbackError => 'Eroare de redare';

  @override
  String get confirmClearHistory => 'Sigur dorești să ștergi tot istoricul?';

  @override
  String seasonWithNumber(Object number) {
    return 'Sezonul $number';
  }

  @override
  String get starting => 'Se pornește...';

  @override
  String percentWatched(int percent) {
    return '$percent% vizionat';
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
  String get debugTools => 'Instrumente depanare';

  @override
  String get playLocalVideo => 'Video local';

  @override
  String get playLocalVideoSubtitle => 'Redă fișier de pe dispozitiv';

  @override
  String get streamUrlSubtitle => 'Redă de la URL rețea';

  @override
  String get streamTorrent => 'Stream torrent';

  @override
  String get streamTorrentSubtitle => 'Selectează un fișier torrent';

  @override
  String get loadPluginFromAssets => 'Încarcă plugin din resurse';

  @override
  String get enterVideoUrlHint => 'Introdu URL-ul videoclipului';

  @override
  String get networkStream => 'Flux rețea';

  @override
  String removedFromHistory(String title) {
    return 'Eliminat din istoric: $title';
  }

  @override
  String get custom => 'Personalizat';

  @override
  String get refreshingLiveStream => 'Se reîmprospătează fluxul...';

  @override
  String get removeFromHistory => 'Elimină din istoric';

  @override
  String get live => 'LIVE';

  @override
  String get volume => 'Volum';

  @override
  String get brightness => 'Luminozitate';

  @override
  String get fit => 'Potrivire';

  @override
  String get zoom => 'Zoom';

  @override
  String get stretch => 'Întinde';

  @override
  String titleWithParam(String title) {
    return 'Titlu: $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'Sursă: $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'Dimensiune: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'Eroare: $error. Se folosește player-ul intern.';
  }

  @override
  String playerNotDetected(String playerName) {
    return '$playerName nu a fost detectat.';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return 'Sezonul $number ($count ep.)';
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
    return 'Sursă pentru $playerName';
  }

  @override
  String get noPluginsInstalled => 'Niciun plugin instalat';

  @override
  String get noPluginsMessage =>
      'Instalează extensii pentru a răsfoi și a transmite conținut.';

  @override
  String get goToExtensions => 'Mergi la extensii';

  @override
  String get availableSources => 'Surse disponibile';

  @override
  String get seasons => 'Sezoane';

  @override
  String get episodes => 'Episoade';

  @override
  String get selectSourceToPlay => 'Selectează o sursă pentru a reda.';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de episoade',
      few: '$count episoade',
      one: '1 episod',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'Nu s-au găsit episoade';

  @override
  String get local => 'Local';

  @override
  String get remote => 'La distanță';

  @override
  String get torrent => 'Torrent';

  @override
  String get unlock => 'Deblochează';

  @override
  String get lock => 'Blochează';

  @override
  String get sources => 'Surse';

  @override
  String get tracks => 'Piste';

  @override
  String get content => 'Conținut';

  @override
  String get stats => 'Statistici';

  @override
  String get resize => 'Dimensiune';

  @override
  String get next => 'Următorul';

  @override
  String get pip => 'PiP';

  @override
  String get rotate => 'Rotește';

  @override
  String get windowed => 'Fereastră';

  @override
  String get fullscreen => 'Ecran complet';

  @override
  String get movieDetails => 'Detalii';

  @override
  String get showDetails => 'Vezi detalii';

  @override
  String get tagline => 'Slogan';

  @override
  String get status => 'Stare';

  @override
  String get releaseDate => 'Data lansării';

  @override
  String get firstAirDate => 'Prima difuzare';

  @override
  String get originalLanguage => 'Limbă originală';

  @override
  String get originCountry => 'Țară de origine';

  @override
  String get budgetLabel => 'Buget';

  @override
  String get revenueLabel => 'Venituri';

  @override
  String get paused => 'Pauzat';

  @override
  String get watched => 'Vizionat';

  @override
  String get watching => 'Vizionare';

  @override
  String get lastWatched => 'Ultima vizionare';

  @override
  String get movie => 'Film';

  @override
  String get tvShow => 'Serial';

  @override
  String get failedToLoadContent => 'Încărcare eșuată';

  @override
  String get director => 'Regizor';

  @override
  String get creator => 'Creator';

  @override
  String get showMore => 'Mai mult';

  @override
  String get showLess => 'Mai puțin';

  @override
  String get viewAll => 'Vezi tot';

  @override
  String seasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de sezoane',
      few: '$count sezoane',
      one: '1 sezon',
    );
    return '$_temp0';
  }

  @override
  String get noInternetError => 'Fără internet';

  @override
  String get timeoutError => 'Timpul a expirat.';

  @override
  String get serverError => 'Eroare server.';

  @override
  String get contentNotFoundError => 'Negăsit.';

  @override
  String get accessDeniedError => 'Acces refuzat.';

  @override
  String get serviceUnavailableError => 'Serviciu indisponibil.';

  @override
  String get generalError => 'Eroare.';

  @override
  String get skip => 'Sari';

  @override
  String get skipIntro => 'Sari peste intro';

  @override
  String get skipOutro => 'Sari peste final';

  @override
  String get skipRecap => 'Sari peste rezumat';

  @override
  String get goLive => 'Direct';

  @override
  String get dismiss => 'Închide';

  @override
  String get nextUp => 'Urmează';

  @override
  String sourceAttempt(int index, int total) {
    return 'Sursa $index din $total';
  }

  @override
  String get trying => 'Se încearcă';

  @override
  String get failed => 'Eșuat';

  @override
  String get selected => 'Selectat';

  @override
  String get playing => 'Redare';

  @override
  String get pending => 'În așteptare';

  @override
  String get openSubtitles => 'OpenSubtitles';

  @override
  String get subDl => 'SubDL';

  @override
  String get subSource => 'SubSource';

  @override
  String get wifiQualityPreference => 'Preferință calitate Wi-Fi';

  @override
  String get mobileQualityPreference => 'Preferință calitate mobilă';

  @override
  String get anyNoPreference => 'Fără preferință';

  @override
  String get subtitleAccounts => 'Conturi de subtitrări';

  @override
  String get accounts => 'Conturi';

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
  String get testConnection => 'Testează conexiunea';

  @override
  String get connectedSuccessfully => 'Conectat cu succes';

  @override
  String get connectionFailed => 'Conexiune eșuată';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get noAccountRegister => 'Don\'t have an account? Register here';

  @override
  String get apiKey => 'Cheie API';

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
  String get diagnostics => 'Diagnostic';

  @override
  String get viewLogs => 'Vezi jurnalele';

  @override
  String get viewLogsSubtitle => 'Vezi activitatea și erorile aplicației';

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
