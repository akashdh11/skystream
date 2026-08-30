// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => 'Italiano';

  @override
  String get home => 'Home';

  @override
  String get search => 'Cerca';

  @override
  String get explore => 'Esplora';

  @override
  String get exploreAnime => 'Esplora anime';

  @override
  String get exploreMovies => 'Esplora film';

  @override
  String get library => 'Libreria';

  @override
  String get settings => 'Impostazioni';

  @override
  String get extensions => 'Estensioni';

  @override
  String get updateAvailable => 'Aggiornamento disponibile';

  @override
  String get retry => 'Riprova';

  @override
  String get factoryReset => 'Ripristino di fabbrica';

  @override
  String get startupError => 'Errore di avvio';

  @override
  String get general => 'Generale';

  @override
  String get appTheme => 'Tema applicazione';

  @override
  String get recordWatchHistory => 'Registra cronologia';

  @override
  String get defaultHomeScreen => 'Schermata home predefinita';

  @override
  String get titlePosition => 'Posizione del titolo';

  @override
  String get titlePositionBelowPoster => 'Sotto il poster';

  @override
  String get titlePositionInsidePoster => 'Nel poster';

  @override
  String get player => 'Lettore';

  @override
  String get defaultPlayer => 'Lettore predefinito';

  @override
  String get leftGesture => 'Gesto sinistro';

  @override
  String get rightGesture => 'Gesto destro';

  @override
  String get doubleTapToSeek => 'Doppio tocco per cercare';

  @override
  String get swipeToSeek => 'Scorri per cercare';

  @override
  String get seekDuration => 'Durata salto';

  @override
  String get bufferDepth => 'Profondità buffer';

  @override
  String get defaultResizeMode => 'Ridimensionamento predefinito';

  @override
  String get hardwareDecoding => 'Decodifica hardware';

  @override
  String get network => 'Rete';

  @override
  String get dnsOverHttps => 'DNS su HTTPS';

  @override
  String get dohProvider => 'Provider DoH';

  @override
  String get githubProxy => 'Proxy GitHub';

  @override
  String get githubProxySubtitle =>
      'Instrada i download delle estensioni tramite jsDelivr per aggirare i blocchi dell\'operatore.';

  @override
  String get manageExtensions => 'Gestisci estensioni';

  @override
  String get appData => 'Dati applicazione';

  @override
  String get resetDataKeepExtensions => 'Ripristina dati (mantieni estensioni)';

  @override
  String get developer => 'Sviluppatore';

  @override
  String get developerOptions => 'Opzioni sviluppatore';

  @override
  String get about => 'Informazioni';

  @override
  String get version => 'Versione';

  @override
  String get enabled => 'Attivato';

  @override
  String get disabled => 'Disattivato';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'Unisciti al nostro server';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'Unisciti al nostro canale';

  @override
  String developedBy(String name) {
    return 'Sviluppato da $name';
  }

  @override
  String get system => 'Sistema';

  @override
  String get dark => 'Scuro';

  @override
  String get light => 'Chiaro';

  @override
  String get later => 'Più tardi';

  @override
  String get updateNow => 'Aggiorna ora';

  @override
  String get save => 'Salva';

  @override
  String get cancel => 'Annulla';

  @override
  String get close => 'Chiudi';

  @override
  String get delete => 'Elimina';

  @override
  String get viewDetails => 'Visualizza dettagli';

  @override
  String get clearAll => 'Cancella tutto';

  @override
  String get clearAllHistory => 'Cancella cronologia';

  @override
  String get all => 'Tutto';

  @override
  String get none => 'Nessuno';

  @override
  String get confirmDownload => 'Conferma download';

  @override
  String get downloadNow => 'Scarica ora';

  @override
  String get selectSource => 'Seleziona fonte';

  @override
  String get downloadUnavailable => 'Download non disponibile';

  @override
  String get selectAnotherSource => 'Seleziona un\'altra fonte';

  @override
  String get watchHistoryCleared => 'Cronologia cancellata';

  @override
  String get downloadingUpdate => 'Scaricamento aggiornamento...';

  @override
  String errorPrefix(String message) {
    return 'Errore: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'Aggiornamento disponibile: $tag';
  }

  @override
  String get selectProviderToStart => 'Seleziona un provider per iniziare';

  @override
  String get tapExtensionIcon => 'Tocca l\'icona dell\'estensione nell\'angolo';

  @override
  String get continueWatching => 'Continua a guardare';

  @override
  String get noInternetConnection => 'Nessuna connessione Internet';

  @override
  String get siteNotReachable => 'Sito non raggiungibile';

  @override
  String get checkConnectionOrDownloads =>
      'Controlla la connessione o guarda i contenuti scaricati.';

  @override
  String get tryVpnOrConnection =>
      'Prova ad accedere con una VPN o controlla la connessione.';

  @override
  String errorDetails(String error) {
    return 'Dettagli errore: $error';
  }

  @override
  String get goToDownloads => 'Vai ai download';

  @override
  String get selectProvider => 'Seleziona provider';

  @override
  String get searchHint => 'Cerca film, serie...';

  @override
  String get searchFavoriteContent => 'Cerca i tuoi contenuti preferiti';

  @override
  String get pressSearchOrEnter => 'Premi Cerca o Invio per iniziare';

  @override
  String get noResultsFound => 'Nessun risultato trovato.';

  @override
  String get couldNotLoadTrending => 'Impossibile caricare i trend';

  @override
  String get popularMovies => 'Film popolari';

  @override
  String get popularTVShows => 'Serie TV popolari';

  @override
  String get newMovies => 'Nuovi film';

  @override
  String get newTVShows => 'Nuove serie TV';

  @override
  String get featuredMovies => 'Film in evidenza';

  @override
  String get featuredTVShows => 'Serie TV in evidenza';

  @override
  String get lastVideosTVShows => 'Ultime serie TV';

  @override
  String get downloads => 'Download';

  @override
  String get bookmarks => 'Segnalibri';

  @override
  String get noDownloadsYet => 'Nessun download presente';

  @override
  String episodesCount(int count, int done) {
    return '$count Episodi • $done Completati';
  }

  @override
  String get deleteAllEpisodes => 'Elimina tutti gli episodi';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return 'Sei sicuro di voler eliminare tutti i $count episodi di \"$title\" e i relativi file?';
  }

  @override
  String get deleteAll => 'Elimina tutto';

  @override
  String get completed => 'Completato';

  @override
  String get statusQueued => 'In coda...';

  @override
  String get statusDownloading => 'Scaricamento...';

  @override
  String get statusFinished => 'Finito';

  @override
  String get statusFailed => 'Fallito';

  @override
  String get statusCanceled => 'Annullato';

  @override
  String get statusPaused => 'In pausa';

  @override
  String get statusWaiting => 'In attesa...';

  @override
  String get fileNotFoundRemoving =>
      'File non trovato sul disco. Rimozione record.';

  @override
  String get fileNotFound => 'File non trovato';

  @override
  String get deleteDownload => 'Elimina download';

  @override
  String get confirmDeleteDownload =>
      'Sei sicuro di voler eliminare questo download e il relativo file?';

  @override
  String get libraryEmpty => 'La tua libreria è vuota';

  @override
  String get language => 'Lingua';

  @override
  String get english => 'Inglese';

  @override
  String get hindi => 'Hindi';

  @override
  String get kannada => 'Kannada';

  @override
  String get unknown => 'Sconosciuto';

  @override
  String get recommended => 'Consigliato';

  @override
  String get on => 'ON';

  @override
  String get off => 'OFF';

  @override
  String get installRemoveProviders => 'Installa o rimuovi provider';

  @override
  String get resetDataSubtitle =>
      'Cancella impostazioni e database, mantieni plugin';

  @override
  String get factoryResetSubtitle =>
      'Elimina tutti i dati, impostazioni ed estensioni';

  @override
  String get developerOptionsSubtitle =>
      'Strumenti di debug e riproduzione locale';

  @override
  String get loading => 'Caricamento...';

  @override
  String get sec => 'sec';

  @override
  String get min => 'min';

  @override
  String get internalPlayer => 'Interno (VLC)';

  @override
  String get builtInPlayer => 'Lettore integrato';

  @override
  String get customNotSet => 'Personalizzato (non impostato)';

  @override
  String selectGesture(String side) {
    return 'Seleziona gesto $side';
  }

  @override
  String get left => 'Sinistra';

  @override
  String get right => 'Destra';

  @override
  String get selectSeekDuration => 'Durata salto';

  @override
  String get selectBufferDepth => 'Profondità buffer';

  @override
  String get subtitleSettings => 'Impostazioni sottotitoli';

  @override
  String size(int size) {
    return 'Dimensione: $size';
  }

  @override
  String get background => 'Sfondo';

  @override
  String get customDohUrlLabel => 'URL DoH personalizzato';

  @override
  String get enterCustomDohUrl => 'Inserisci il tuo URL DoH';

  @override
  String get chooseTheme => 'Scegli tema';

  @override
  String get resetDataDialogTitle => 'Ripristina dati?';

  @override
  String get resetDataDialogContent =>
      'Questo cancellerà Impostazioni, Preferiti e Cronologia. Le estensioni installate NON verranno eliminate.';

  @override
  String get factoryResetDialogTitle => 'Ripristino di fabbrica?';

  @override
  String get factoryResetDialogContent =>
      'Questo eliminerà TUTTO: Preferiti, Cronologia, Impostazioni e TUTTE le estensioni. L\'azione è irreversibile.';

  @override
  String get selectLanguage => 'Seleziona lingua';

  @override
  String get synopsis => 'Sinossi';

  @override
  String get noDescription => 'Nessuna descrizione disponibile.';

  @override
  String get videoAlreadyDownloadedPrompt =>
      'Questo video è già stato scaricato. Cosa vuoi fare?';

  @override
  String get playNow => 'Riproduci ora';

  @override
  String get upNext => 'In arrivo';

  @override
  String get deleteDownloadPrompt => 'Elimina download?';

  @override
  String get deleteDownloadConfirmation =>
      'Sei sicuro di voler eliminare questo file? L\'azione è irreversibile.';

  @override
  String get no => 'No';

  @override
  String get yesDelete => 'Sì, elimina';

  @override
  String get downloadPaused => 'Download in pausa';

  @override
  String get downloading => 'Scaricamento';

  @override
  String get speed => 'Velocità';

  @override
  String get remaining => 'Rimanente';

  @override
  String get resume => 'Riprendi';

  @override
  String get pause => 'Pausa';

  @override
  String get torrentContent => 'Contenuto Torrent';

  @override
  String get audioTracks => 'Tracce Audio';

  @override
  String get noAudioTracks => 'Nessuna traccia audio trovata';

  @override
  String get subtitles => 'Sottotitoli';

  @override
  String get options => 'Opzioni';

  @override
  String get noSubtitlesFound => 'Nessuna traccia sottotitoli trovata';

  @override
  String get playbackSpeed => 'Velocità di riproduzione';

  @override
  String get subtitleOptions => 'Opzioni sottotitoli';

  @override
  String get hlsSubtitleWarning =>
      'I sottotitoli esterni non sono supportati dal lettore HLS attivo su questa piattaforma.';

  @override
  String get loadFromDevice => 'Carica dal dispositivo';

  @override
  String get syncDelay => 'Sincronizzazione / Ritardo';

  @override
  String get styleSettings => 'Impostazioni stile';

  @override
  String get searchOnline => 'Cerca online (Subtitle Search)';

  @override
  String get subtitleSync => 'Sincronia sottotitoli';

  @override
  String get subtitleDelayWarning =>
      'Il ritardo sottotitoli non è supportato dal motore di riproduzione attuale.';

  @override
  String get resetDelay => 'Ripristina ritardo';

  @override
  String get subtitleStyles => 'Stili sottotitoli';

  @override
  String get resetToDefault => 'Ripristina predefiniti';

  @override
  String get fontSize => 'Dimensione carattere';

  @override
  String get verticalPosition => 'Posizione verticale';

  @override
  String get textColor => 'Colore testo';

  @override
  String get backgroundColor => 'Colore sfondo';

  @override
  String get backgroundOpacity => 'Opacità sfondo';

  @override
  String get subtitleSearch => 'Ricerca sottotitoli';

  @override
  String get searchSubtitleNameHint => 'Cerca nome sottotitolo...';

  @override
  String get enterSearchSubtitlePrompt =>
      'Inserisci un nome per trovare i sottotitoli.';

  @override
  String get noSubtitleResults =>
      'Nessun risultato trovato. Prova un\'altra ricerca.';

  @override
  String get downloadingApplyingSubtitle =>
      'Scaricamento e applicazione sottotitolo...';

  @override
  String get failedToDownloadSubtitle => 'Scaricamento sottotitolo fallito.';

  @override
  String get failedToLoadSubtitles =>
      'Caricamento sottotitoli fallito. Riprova.';

  @override
  String get noReposFound => 'Nessun repository o plugin trovato';

  @override
  String get downloadAllProviders => 'Scarica tutto';

  @override
  String get removeRepository => 'Rimuovi repository';

  @override
  String get addRepo => 'Aggiungi repository';

  @override
  String get extensionsNotInRepos => 'Estensioni non nei repository';

  @override
  String get noLongerInRepo => 'Non più presente in alcun repository';

  @override
  String get addRepoToBrowse =>
      'Aggiungi un repository per sfogliare e aggiornare i plugin';

  @override
  String get debugExtensions => 'Debug estensioni';

  @override
  String removeRepoConfirm(String repoName) {
    return 'Rimuovere $repoName?';
  }

  @override
  String get removeRepoWarning =>
      'Questo rimuoverà il repository e disinstallerà TUTTI i suoi plugin.';

  @override
  String get addRepository => 'Aggiungi repository';

  @override
  String get repoUrlOrShortcode => 'URL o Shortcode repository';

  @override
  String get assetPlugin => 'Plugin asset';

  @override
  String get installed => 'Installato';

  @override
  String get repositories => 'Repository';

  @override
  String get noExtensionsInstalled => 'Nessuna estensione installata';

  @override
  String get browseRepositoriesToInstall =>
      'Apri la scheda Repository per scoprire e installare estensioni.';

  @override
  String get browseRepositories => 'Sfoglia i repository';

  @override
  String get addRepoDescription =>
      'Aggiungi l\'URL di un repository o un codice breve per scoprire e installare plugin di estensione.';

  @override
  String updateTo(String version) {
    return 'Aggiorna a $version';
  }

  @override
  String get install => 'Installa';

  @override
  String get error => 'Errore';

  @override
  String get ok => 'OK';

  @override
  String pluginSettings(String pluginName) {
    return 'Impostazioni $pluginName';
  }

  @override
  String get movies => 'Film';

  @override
  String get series => 'Serie TV';

  @override
  String get anime => 'Anime';

  @override
  String get liveStreams => 'Dirette live';

  @override
  String get debug => 'DEBUG';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count estensioni aggiornate',
      one: '1 estensione aggiornata',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => 'Navigazione non valida. Torna indietro.';

  @override
  String get startOver => 'Ricomincia';

  @override
  String get goBack => 'Torna indietro';

  @override
  String get resolving => 'Risoluzione...';

  @override
  String get downloaded => 'Scaricato';

  @override
  String get download => 'Scarica';

  @override
  String get debugOnlyFeature =>
      'Questa funzione è disponibile solo nelle build di Debug';

  @override
  String get streamUrl => 'URL Streaming';

  @override
  String get play => 'Riproduci';

  @override
  String get verifyingSourceSize => 'Verifica fonte e dimensioni...';

  @override
  String get fileSaveLocationNotification =>
      'Il file verrà salvato nella cartella Download.';

  @override
  String get resumingPlayback => 'Ripresa riproduzione';

  @override
  String pausedAt(String time) {
    return 'In pausa a $time';
  }

  @override
  String resumesAutomatically(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ripresa automatica tra $count secondi',
      one: 'Ripresa automatica tra 1 secondo',
    );
    return '$_temp0';
  }

  @override
  String get resumeNow => 'Riprendi ora';

  @override
  String get playbackError => 'Errore riproduzione';

  @override
  String get confirmClearHistory =>
      'Sei sicuro di voler rimuovere tutti gli elementi dalla cronologia?';

  @override
  String seasonWithNumber(Object number) {
    return 'Stagione $number';
  }

  @override
  String get starting => 'Avvio...';

  @override
  String percentWatched(int percent) {
    return '$percent% guardato';
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
  String get debugTools => 'Strumenti debug';

  @override
  String get playLocalVideo => 'Riproduci file video locale';

  @override
  String get playLocalVideoSubtitle =>
      'Riproduci qualsiasi video dal dispositivo';

  @override
  String get streamUrlSubtitle => 'Riproduci da URL di rete';

  @override
  String get streamTorrent => 'Streaming torrent';

  @override
  String get streamTorrentSubtitle =>
      'Seleziona un file torrent locale per la riproduzione';

  @override
  String get loadPluginFromAssets => 'Carica plugin dagli asset';

  @override
  String get enterVideoUrlHint => 'Inserisci URL video (http, magnet, ecc.)';

  @override
  String get networkStream => 'Streaming di rete';

  @override
  String removedFromHistory(String title) {
    return '$title rimosso dalla cronologia';
  }

  @override
  String get custom => 'Personalizzato';

  @override
  String get refreshingLiveStream => 'Aggiornamento diretta live...';

  @override
  String get removeFromHistory => 'Rimuovi dalla cronologia';

  @override
  String get live => 'LIVE';

  @override
  String get volume => 'Volume';

  @override
  String get brightness => 'Luminosità';

  @override
  String get fit => 'Adatta';

  @override
  String get zoom => 'Zoom';

  @override
  String get stretch => 'Allunga';

  @override
  String titleWithParam(String title) {
    return 'Titolo: $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'Fonte: $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'Dimensione: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'Errore: $error. Utilizzo del lettore interno.';
  }

  @override
  String playerNotDetected(String playerName) {
    return '$playerName non rilevato. Avvio lettore interno.';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return 'Stagione $number ($count Episodi)';
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
    return 'Seleziona fonte per $playerName';
  }

  @override
  String get noPluginsInstalled => 'Nessun plugin installato';

  @override
  String get noPluginsMessage =>
      'Installa le estensioni per sfogliare e trasmettere contenuti.';

  @override
  String get goToExtensions => 'Vai alle estensioni';

  @override
  String get availableSources => 'Fonti disponibili';

  @override
  String get seasons => 'Stagioni';

  @override
  String get episodes => 'Episodi';

  @override
  String get selectSourceToPlay => 'Seleziona una fonte sopra per riprodurre.';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Episodi',
      one: '1 Episodio',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'Nessun episodio trovato';

  @override
  String get local => 'Locale';

  @override
  String get remote => 'Remoto';

  @override
  String get torrent => 'Torrent';

  @override
  String get unlock => 'Sblocca';

  @override
  String get lock => 'Blocca';

  @override
  String get sources => 'Fonti';

  @override
  String get tracks => 'Tracce';

  @override
  String get content => 'Contenuto';

  @override
  String get stats => 'Statistiche';

  @override
  String get resize => 'Ridimensiona';

  @override
  String get next => 'Successivo';

  @override
  String get pip => 'PiP';

  @override
  String get rotate => 'Ruota';

  @override
  String get windowed => 'Finestra';

  @override
  String get fullscreen => 'Schermo intero';

  @override
  String get movieDetails => 'Dettagli Film';

  @override
  String get showDetails => 'Mostra Dettagli';

  @override
  String get tagline => 'Tagline';

  @override
  String get status => 'Stato';

  @override
  String get releaseDate => 'Data d\'uscita';

  @override
  String get firstAirDate => 'Data prima messa in onda';

  @override
  String get originalLanguage => 'Lingua originale';

  @override
  String get originCountry => 'Paese d\'origine';

  @override
  String get budgetLabel => 'Budget';

  @override
  String get revenueLabel => 'Incasso';

  @override
  String get paused => 'In pausa';

  @override
  String get watched => 'Visto';

  @override
  String get watching => 'In visione';

  @override
  String get lastWatched => 'Ultima visione';

  @override
  String get movie => 'Film';

  @override
  String get tvShow => 'Serie TV';

  @override
  String get failedToLoadContent => 'Caricamento contenuti fallito';

  @override
  String get director => 'Regista';

  @override
  String get creator => 'Creatore';

  @override
  String get showMore => 'Mostra di più';

  @override
  String get showLess => 'Mostra meno';

  @override
  String get viewAll => 'Vedi tutto';

  @override
  String seasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stagioni',
      one: '1 Stagione',
    );
    return '$_temp0';
  }

  @override
  String get noInternetError => 'Nessuna connessione Internet';

  @override
  String get timeoutError => 'Richiesta scaduta. Riprova.';

  @override
  String get serverError => 'Errore del server. Riprova più tardi.';

  @override
  String get contentNotFoundError => 'Contenuto non trovato.';

  @override
  String get accessDeniedError =>
      'Accesso negato. Controlla le tue credenziali.';

  @override
  String get serviceUnavailableError =>
      'Server non disponibile. Riprova più tardi.';

  @override
  String get generalError => 'Si è verificato un errore. Per favore riprova.';

  @override
  String get skip => 'Salta';

  @override
  String get skipIntro => 'Salta introduzione';

  @override
  String get skipOutro => 'Salta finale';

  @override
  String get skipRecap => 'Salta riepilogo';

  @override
  String get goLive => 'Vai in diretta';

  @override
  String get dismiss => 'Chiudi';

  @override
  String get nextUp => 'Prossimo';

  @override
  String sourceAttempt(int index, int total) {
    return 'Fonte $index di $total';
  }

  @override
  String get trying => 'Tentativo';

  @override
  String get failed => 'Fallito';

  @override
  String get selected => 'Selezionato';

  @override
  String get playing => 'In riproduzione';

  @override
  String get pending => 'In attesa';

  @override
  String get openSubtitles => 'OpenSubtitles';

  @override
  String get subDl => 'SubDL';

  @override
  String get subSource => 'SubSource';

  @override
  String get wifiQualityPreference => 'Preferenza qualità Wi-Fi';

  @override
  String get mobileQualityPreference => 'Preferenza qualità mobile';

  @override
  String get anyNoPreference => 'Qualsiasi (nessuna preferenza)';

  @override
  String get subtitleAccounts => 'Account sottotitoli';

  @override
  String get accounts => 'Account';

  @override
  String get notLoggedIn => 'Accesso non effettuato';

  @override
  String loggedInAs(String username) {
    return 'Accesso effettuato come $username';
  }

  @override
  String get apiKeyConfigured => 'Chiave API configurata';

  @override
  String get keyNotSet => 'Chiave non impostata';

  @override
  String get testConnection => 'Testa connessione';

  @override
  String get connectedSuccessfully => 'Connesso con successo';

  @override
  String get connectionFailed => 'Connessione fallita';

  @override
  String get username => 'Nome utente';

  @override
  String get password => 'Password';

  @override
  String get noAccountRegister => 'Non hai un account? Registrati qui';

  @override
  String get apiKey => 'Chiave API';

  @override
  String get email => 'Email';

  @override
  String get fetchMyApiKey => 'Recupera la mia chiave API';

  @override
  String get keyVerified => 'Chiave verificata';

  @override
  String get invalidApiKey => 'Chiave API non valida';

  @override
  String get openSubtitlesAuthSubtitle =>
      'Inserisci le tue credenziali per limiti più elevati e sottotitoli senza pubblicità.';

  @override
  String get subDlAuthSubtitle =>
      'Inserisci direttamente la tua chiave API SubDL o recuperala inserendo le tue credenziali.';

  @override
  String get orFetchViaAccount => 'O RECUPERA TRAMITE ACCOUNT';

  @override
  String get subSourceAuthSubtitle =>
      'SubSource funziona normalmente, ma puoi aggiungere una chiave API ufficiale per maggiore affidabilità.';

  @override
  String get apiKeyOptionalOverride => 'Chiave API (Opzionale)';

  @override
  String get enterKeyToOverrideDefault =>
      'Inserisci chiave per sovrascrivere predefinita';

  @override
  String get getApiKeyFromProfile =>
      'Ottieni la tua chiave API dal profilo SubSource';

  @override
  String get qualityNotGuaranteed =>
      'La qualità non è garantita. Le fonti sono ordinate per preferenza, ma dipendono dall\'offerta effettiva del fornitore.';

  @override
  String get keepSourcesOriginalOrder =>
      'Mantieni l\'ordine originale delle fonti';

  @override
  String get openLink => 'Apri link';

  @override
  String get diagnostics => 'Diagnostica';

  @override
  String get viewLogs => 'Visualizza registri';

  @override
  String get viewLogsSubtitle =>
      'Visualizza attività ed errori dell\'applicazione';

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
