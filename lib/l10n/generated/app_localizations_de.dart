// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => 'Deutsch';

  @override
  String get home => 'Startseite';

  @override
  String get search => 'Suche';

  @override
  String get explore => 'Erkunden';

  @override
  String get exploreAnime => 'Anime entdecken';

  @override
  String get exploreMovies => 'Filme entdecken';

  @override
  String get library => 'Bibliothek';

  @override
  String get settings => 'Einstellungen';

  @override
  String get extensions => 'Erweiterungen';

  @override
  String get updateAvailable => 'Update verfügbar';

  @override
  String get retry => 'Wiederholen';

  @override
  String get factoryReset => 'Werkseinstellung';

  @override
  String get startupError => 'Startfehler';

  @override
  String get general => 'Allgemein';

  @override
  String get appTheme => 'App-Design';

  @override
  String get recordWatchHistory => 'Verlauf speichern';

  @override
  String get defaultHomeScreen => 'Standard-Startbildschirm';

  @override
  String get titlePosition => 'Titelposition';

  @override
  String get titlePositionBelowPoster => 'Unter dem Poster';

  @override
  String get titlePositionInsidePoster => 'Im Poster';

  @override
  String get player => 'Player';

  @override
  String get defaultPlayer => 'Standard-Player';

  @override
  String get leftGesture => 'Linke Geste';

  @override
  String get rightGesture => 'Rechte Geste';

  @override
  String get doubleTapToSeek => 'Doppeltippen zum Suchen';

  @override
  String get swipeToSeek => 'Wischen zum Suchen';

  @override
  String get seekDuration => 'Sprungdauer';

  @override
  String get bufferDepth => 'Puffertiefe';

  @override
  String get defaultResizeMode => 'Standard-Anpassungsmodus';

  @override
  String get hardwareDecoding => 'Hardware-Dekodierung';

  @override
  String get network => 'Netzwerk';

  @override
  String get dnsOverHttps => 'DNS über HTTPS';

  @override
  String get dohProvider => 'DoH-Anbieter';

  @override
  String get githubProxy => 'GitHub-Proxy';

  @override
  String get githubProxySubtitle =>
      'Erweiterungs-Downloads über jsDelivr leiten, um Sperren des Anbieters zu umgehen.';

  @override
  String get manageExtensions => 'Erweiterungen verwalten';

  @override
  String get appData => 'App-Daten';

  @override
  String get resetDataKeepExtensions =>
      'Daten zurücksetzen (Erweiterungen behalten)';

  @override
  String get developer => 'Entwickler';

  @override
  String get developerOptions => 'Entwickleroptionen';

  @override
  String get about => 'Über';

  @override
  String get version => 'Version';

  @override
  String get enabled => 'Aktiviert';

  @override
  String get disabled => 'Deaktiviert';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'Tritt unserem Server bei';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'Tritt unserem Kanal bei';

  @override
  String developedBy(String name) {
    return 'Entwickelt von $name';
  }

  @override
  String get system => 'System';

  @override
  String get dark => 'Dunkel';

  @override
  String get light => 'Hell';

  @override
  String get later => 'Später';

  @override
  String get updateNow => 'Jetzt aktualisieren';

  @override
  String get save => 'Speichern';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get close => 'Schließen';

  @override
  String get delete => 'Löschen';

  @override
  String get viewDetails => 'Details anzeigen';

  @override
  String get clearAll => 'Alles löschen';

  @override
  String get clearAllHistory => 'Verlauf löschen';

  @override
  String get all => 'Alle';

  @override
  String get none => 'Keine';

  @override
  String get confirmDownload => 'Download bestätigen';

  @override
  String get downloadNow => 'Jetzt herunterladen';

  @override
  String get selectSource => 'Quelle auswählen';

  @override
  String get downloadUnavailable => 'Download nicht verfügbar';

  @override
  String get selectAnotherSource => 'Andere Quelle wählen';

  @override
  String get watchHistoryCleared => 'Verlauf gelöscht';

  @override
  String get downloadingUpdate => 'Update wird heruntergeladen...';

  @override
  String errorPrefix(String message) {
    return 'Fehler: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'Update verfügbar: $tag';
  }

  @override
  String get selectProviderToStart => 'Wähle einen Anbieter, um zu schauen';

  @override
  String get tapExtensionIcon => 'Tippe auf das Erweiterungssymbol in der Ecke';

  @override
  String get continueWatching => 'Weiter schauen';

  @override
  String get noInternetConnection => 'Keine Internetverbindung';

  @override
  String get siteNotReachable => 'Seite nicht erreichbar';

  @override
  String get checkConnectionOrDownloads =>
      'Prüfe deine Verbindung oder sieh dir deine Downloads an.';

  @override
  String get tryVpnOrConnection =>
      'Versuche es mit einem VPN oder prüfe deine Internetverbindung.';

  @override
  String errorDetails(String error) {
    return 'Fehlerdetails: $error';
  }

  @override
  String get goToDownloads => 'Zu den Downloads';

  @override
  String get selectProvider => 'Anbieter wählen';

  @override
  String get searchHint => 'Suche nach Filmen, Serien...';

  @override
  String get searchFavoriteContent => 'Suche nach deinen Favoriten';

  @override
  String get pressSearchOrEnter =>
      'Drücke die Suchtaste oder Enter, um zu starten';

  @override
  String get noResultsFound => 'Keine Ergebnisse gefunden.';

  @override
  String get couldNotLoadTrending => 'Trends konnten nicht geladen werden';

  @override
  String get popularMovies => 'Beliebte Filme';

  @override
  String get popularTVShows => 'Beliebte Serien';

  @override
  String get newMovies => 'Neue Filme';

  @override
  String get newTVShows => 'Neue Serien';

  @override
  String get featuredMovies => 'Empfohlene Filme';

  @override
  String get featuredTVShows => 'Empfohlene Serien';

  @override
  String get lastVideosTVShows => 'Letzte Serienvideos';

  @override
  String get downloads => 'Downloads';

  @override
  String get bookmarks => 'Lesezeichen';

  @override
  String get noDownloadsYet => 'Noch keine Downloads';

  @override
  String episodesCount(int count, int done) {
    return '$count Episoden • $done Fertig';
  }

  @override
  String get deleteAllEpisodes => 'Alle Episoden löschen';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return 'Möchtest du wirklich alle $count Episoden von \"$title\" und deren Dateien löschen?';
  }

  @override
  String get deleteAll => 'Alles löschen';

  @override
  String get completed => 'Abgeschlossen';

  @override
  String get statusQueued => 'Warteschlange...';

  @override
  String get statusDownloading => 'Wird heruntergeladen...';

  @override
  String get statusFinished => 'Fertig';

  @override
  String get statusFailed => 'Fehlgeschlagen';

  @override
  String get statusCanceled => 'Abgebrochen';

  @override
  String get statusPaused => 'Pausiert';

  @override
  String get statusWaiting => 'Warten...';

  @override
  String get fileNotFoundRemoving =>
      'Datei nicht gefunden. Eintrag wird entfernt.';

  @override
  String get fileNotFound => 'Datei nicht gefunden';

  @override
  String get deleteDownload => 'Download löschen';

  @override
  String get confirmDeleteDownload =>
      'Möchtest du diesen Download und die Datei wirklich löschen?';

  @override
  String get libraryEmpty => 'Deine Bibliothek ist leer';

  @override
  String get language => 'Sprache';

  @override
  String get english => 'Englisch';

  @override
  String get hindi => 'Hindi';

  @override
  String get kannada => 'Kannada';

  @override
  String get unknown => 'Unbekannt';

  @override
  String get recommended => 'Empfohlen';

  @override
  String get on => 'An';

  @override
  String get off => 'Aus';

  @override
  String get installRemoveProviders => 'Anbieter installieren oder entfernen';

  @override
  String get resetDataSubtitle =>
      'Einstellungen & Datenbank löschen, Plugins behalten';

  @override
  String get factoryResetSubtitle =>
      'Alle Daten, Einstellungen und Erweiterungen löschen';

  @override
  String get developerOptionsSubtitle => 'Debug-Tools & lokale Wiedergabe';

  @override
  String get loading => 'Lädt...';

  @override
  String get sec => 'Sek.';

  @override
  String get min => 'Min.';

  @override
  String get internalPlayer => 'Intern (VLC)';

  @override
  String get builtInPlayer => 'Integrierter Player';

  @override
  String get customNotSet => 'Benutzerdefiniert (nicht festgelegt)';

  @override
  String selectGesture(String side) {
    return '$side Geste wählen';
  }

  @override
  String get left => 'Links';

  @override
  String get right => 'Rechts';

  @override
  String get selectSeekDuration => 'Sprungdauer wählen';

  @override
  String get selectBufferDepth => 'Puffertiefe wählen';

  @override
  String get subtitleSettings => 'Untertitel-Einstellungen';

  @override
  String size(int size) {
    return 'Größe: $size';
  }

  @override
  String get background => 'Hintergrund';

  @override
  String get customDohUrlLabel => 'Benutzerdefinierte DoH-URL';

  @override
  String get enterCustomDohUrl => 'Eigene DoH-URL eingeben';

  @override
  String get chooseTheme => 'Design wählen';

  @override
  String get resetDataDialogTitle => 'Daten zurücksetzen?';

  @override
  String get resetDataDialogContent =>
      'Dies löscht Einstellungen, Favoriten und Verlauf. Deine installierten Erweiterungen bleiben erhalten.';

  @override
  String get factoryResetDialogTitle => 'Werkseinstellung?';

  @override
  String get factoryResetDialogContent =>
      'Dies löscht ALLES: Favoriten, Verlauf, Einstellungen und ALLE Erweiterungen. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get selectLanguage => 'Sprache wählen';

  @override
  String get synopsis => 'Handlung';

  @override
  String get noDescription => 'Keine Beschreibung verfügbar.';

  @override
  String get videoAlreadyDownloadedPrompt =>
      'Dieses Video wurde bereits heruntergeladen. Was möchtest du tun?';

  @override
  String get playNow => 'Jetzt abspielen';

  @override
  String get upNext => 'Als Nächstes';

  @override
  String get deleteDownloadPrompt => 'Download löschen?';

  @override
  String get deleteDownloadConfirmation =>
      'Möchtest du diese Datei wirklich löschen? Dies kann nicht rückgängig gemacht werden.';

  @override
  String get no => 'Nein';

  @override
  String get yesDelete => 'Ja, löschen';

  @override
  String get downloadPaused => 'Download pausiert';

  @override
  String get downloading => 'Wird heruntergeladen';

  @override
  String get speed => 'Geschwindigkeit';

  @override
  String get remaining => 'Verbleibend';

  @override
  String get resume => 'Fortsetzen';

  @override
  String get pause => 'Pause';

  @override
  String get torrentContent => 'Torrent-Inhalt';

  @override
  String get audioTracks => 'Tonspuren';

  @override
  String get noAudioTracks => 'Keine Tonspuren gefunden';

  @override
  String get subtitles => 'Untertitel';

  @override
  String get options => 'Optionen';

  @override
  String get noSubtitlesFound => 'Keine Untertitel gefunden';

  @override
  String get playbackSpeed => 'Wiedergabegeschwindigkeit';

  @override
  String get subtitleOptions => 'Untertitel-Optionen';

  @override
  String get hlsSubtitleWarning =>
      'Externe Untertitel werden vom aktuellen HLS-Player auf dieser Plattform nicht unterstützt.';

  @override
  String get loadFromDevice => 'Vom Gerät laden';

  @override
  String get syncDelay => 'Sync / Verzögerung';

  @override
  String get styleSettings => 'Stil-Einstellungen';

  @override
  String get searchOnline => 'Online suchen (Subtitle Search)';

  @override
  String get subtitleSync => 'Untertitel-Sync';

  @override
  String get subtitleDelayWarning =>
      'Untertitelverzögerung wird vom aktuellen Player nicht unterstützt.';

  @override
  String get resetDelay => 'Verzögerung zurücksetzen';

  @override
  String get subtitleStyles => 'Untertitel-Stile';

  @override
  String get resetToDefault => 'Zurücksetzen';

  @override
  String get fontSize => 'Schriftgröße';

  @override
  String get verticalPosition => 'Vertikale Position';

  @override
  String get textColor => 'Textfarbe';

  @override
  String get backgroundColor => 'Hintergrundfarbe';

  @override
  String get backgroundOpacity => 'Hintergrund-Deckkraft';

  @override
  String get subtitleSearch => 'Untertitelsuche';

  @override
  String get searchSubtitleNameHint => 'Untertitel suchen...';

  @override
  String get enterSearchSubtitlePrompt =>
      'Gib einen Namen ein, um Untertitel zu finden.';

  @override
  String get noSubtitleResults =>
      'Keine Ergebnisse gefunden. Versuche eine andere Suche.';

  @override
  String get downloadingApplyingSubtitle =>
      'Untertitel wird heruntergeladen & angewendet...';

  @override
  String get failedToDownloadSubtitle => 'Untertitel-Download fehlgeschlagen.';

  @override
  String get failedToLoadSubtitles =>
      'Untertitel konnten nicht geladen werden. Bitte erneut versuchen.';

  @override
  String get noReposFound => 'Keine Repositorys oder Plugins gefunden';

  @override
  String get downloadAllProviders => 'Alle herunterladen';

  @override
  String get removeRepository => 'Repository entfernen';

  @override
  String get addRepo => 'Repo hinzufügen';

  @override
  String get extensionsNotInRepos => 'Erweiterungen nicht in Repositorys';

  @override
  String get noLongerInRepo => 'Nicht mehr in einem Repository gelistet';

  @override
  String get addRepoToBrowse =>
      'Füge ein Repository hinzu, um Plugins zu durchsuchen';

  @override
  String get debugExtensions => 'Erweiterungen debuggen';

  @override
  String removeRepoConfirm(String repoName) {
    return '$repoName entfernen?';
  }

  @override
  String get removeRepoWarning =>
      'Dies entfernt das Repository und deinstalliert ALLE seine Plugins.';

  @override
  String get addRepository => 'Repository hinzufügen';

  @override
  String get repoUrlOrShortcode => 'Repository-URL oder Kurzcode';

  @override
  String get assetPlugin => 'Asset-Plugin';

  @override
  String get installed => 'Installiert';

  @override
  String get repositories => 'Repositories';

  @override
  String get noExtensionsInstalled => 'Keine Erweiterungen installiert';

  @override
  String get browseRepositoriesToInstall =>
      'Öffne den Tab „Repositories“, um Erweiterungen zu entdecken und zu installieren.';

  @override
  String get browseRepositories => 'Repositories durchsuchen';

  @override
  String get addRepoDescription =>
      'Füge eine Repository-URL oder einen Kurzcode hinzu, um Erweiterungs-Plugins zu entdecken und zu installieren.';

  @override
  String updateTo(String version) {
    return 'Update auf $version';
  }

  @override
  String get install => 'Installieren';

  @override
  String get error => 'Fehler';

  @override
  String get ok => 'OK';

  @override
  String pluginSettings(String pluginName) {
    return '$pluginName Einstellungen';
  }

  @override
  String get movies => 'Filme';

  @override
  String get series => 'Serien';

  @override
  String get anime => 'Anime';

  @override
  String get liveStreams => 'Live-Streams';

  @override
  String get debug => 'DEBUG';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Erweiterungen aktualisiert',
      one: '1 Erweiterung aktualisiert',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => 'Ungültige Navigation. Bitte zurückgehen.';

  @override
  String get startOver => 'Neustart';

  @override
  String get goBack => 'Zurück';

  @override
  String get resolving => 'Wird aufgelöst...';

  @override
  String get downloaded => 'Heruntergeladen';

  @override
  String get download => 'Download';

  @override
  String get debugOnlyFeature =>
      'Diese Funktion ist nur in Debug-Builds verfügbar';

  @override
  String get streamUrl => 'Stream-URL';

  @override
  String get play => 'Abspielen';

  @override
  String get verifyingSourceSize => 'Quelle & Größe werden geprüft...';

  @override
  String get fileSaveLocationNotification =>
      'Die Datei wird in deinem Download-Ordner gespeichert.';

  @override
  String get resumingPlayback => 'Wiedergabe wird fortgesetzt';

  @override
  String pausedAt(String time) {
    return 'Pausiert bei $time';
  }

  @override
  String resumesAutomatically(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wird automatisch in $count Sekunden fortgesetzt',
      one: 'Wird automatisch in 1 Sekunde fortgesetzt',
    );
    return '$_temp0';
  }

  @override
  String get resumeNow => 'Jetzt fortsetzen';

  @override
  String get playbackError => 'Wiedergabefehler';

  @override
  String get confirmClearHistory =>
      'Möchtest du wirklich alle Einträge aus deinem Verlauf löschen?';

  @override
  String seasonWithNumber(Object number) {
    return 'Staffel $number';
  }

  @override
  String get starting => 'Startet...';

  @override
  String percentWatched(int percent) {
    return '$percent% gesehen';
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
  String get debugTools => 'Debug-Tools';

  @override
  String get playLocalVideo => 'Lokale Videodatei abspielen';

  @override
  String get playLocalVideoSubtitle => 'Beliebiges Video vom Gerät abspielen';

  @override
  String get streamUrlSubtitle => 'Von Netzwerk-URL abspielen';

  @override
  String get streamTorrent => 'Torrent streamen';

  @override
  String get streamTorrentSubtitle =>
      'Lokale Torrent-Datei zum Abspielen wählen';

  @override
  String get loadPluginFromAssets => 'Plugin aus Assets laden';

  @override
  String get enterVideoUrlHint => 'Video-URL eingeben (http, magnet, etc.)';

  @override
  String get networkStream => 'Netzwerk-Stream';

  @override
  String removedFromHistory(String title) {
    return '$title aus Verlauf entfernt';
  }

  @override
  String get custom => 'Benutzerdefiniert';

  @override
  String get refreshingLiveStream => 'Live-Stream wird aktualisiert...';

  @override
  String get removeFromHistory => 'Aus Verlauf entfernen';

  @override
  String get live => 'LIVE';

  @override
  String get volume => 'Lautstärke';

  @override
  String get brightness => 'Helligkeit';

  @override
  String get fit => 'Passend';

  @override
  String get zoom => 'Zoom';

  @override
  String get stretch => 'Strecken';

  @override
  String titleWithParam(String title) {
    return 'Titel: $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'Quelle: $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'Größe: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'Fehler: $error. Interner Player wird verwendet.';
  }

  @override
  String playerNotDetected(String playerName) {
    return '$playerName nicht gefunden. Interner Player wird gestartet.';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return 'Staffel $number ($count Episoden)';
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
    return 'Quelle für $playerName wählen';
  }

  @override
  String get noPluginsInstalled => 'Keine Plugins installiert';

  @override
  String get noPluginsMessage =>
      'Installieren Sie Erweiterungen, um Inhalte zu durchsuchen und zu streamen.';

  @override
  String get goToExtensions => 'Zu den Erweiterungen gehen';

  @override
  String get availableSources => 'Verfügbare Quellen';

  @override
  String get seasons => 'Staffeln';

  @override
  String get episodes => 'Episoden';

  @override
  String get selectSourceToPlay =>
      'Bitte wähle oben eine Quelle zum Abspielen aus.';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Episoden',
      one: '1 Episode',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'Keine Episoden gefunden';

  @override
  String get local => 'Lokal';

  @override
  String get remote => 'Remote';

  @override
  String get torrent => 'Torrent';

  @override
  String get unlock => 'Entsperren';

  @override
  String get lock => 'Sperren';

  @override
  String get sources => 'Quellen';

  @override
  String get tracks => 'Spuren';

  @override
  String get content => 'Inhalt';

  @override
  String get stats => 'Stats';

  @override
  String get resize => 'Größe anpassen';

  @override
  String get next => 'Weiter';

  @override
  String get pip => 'PiP';

  @override
  String get rotate => 'Drehen';

  @override
  String get windowed => 'Fenstermodus';

  @override
  String get fullscreen => 'Vollbild';

  @override
  String get movieDetails => 'Film-Details';

  @override
  String get showDetails => 'Details anzeigen';

  @override
  String get tagline => 'Slogan';

  @override
  String get status => 'Status';

  @override
  String get releaseDate => 'Veröffentlichungsdatum';

  @override
  String get firstAirDate => 'Erstausstrahlung';

  @override
  String get originalLanguage => 'Originalsprache';

  @override
  String get originCountry => 'Ursprungsland';

  @override
  String get budgetLabel => 'Budget';

  @override
  String get revenueLabel => 'Einnahmen';

  @override
  String get paused => 'Pausiert';

  @override
  String get watched => 'Gesehen';

  @override
  String get watching => 'Schaut gerade';

  @override
  String get lastWatched => 'Zuletzt gesehen';

  @override
  String get movie => 'Film';

  @override
  String get tvShow => 'Serie';

  @override
  String get failedToLoadContent => 'Inhalt konnte nicht geladen werden';

  @override
  String get director => 'Regisseur';

  @override
  String get creator => 'Ersteller';

  @override
  String get showMore => 'Mehr anzeigen';

  @override
  String get showLess => 'Weniger anzeigen';

  @override
  String get viewAll => 'Alle anzeigen';

  @override
  String seasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Staffeln',
      one: '1 Staffel',
    );
    return '$_temp0';
  }

  @override
  String get noInternetError => 'Keine Internetverbindung';

  @override
  String get timeoutError => 'Zeitüberschreitung. Bitte erneut versuchen.';

  @override
  String get serverError => 'Serverfehler. Bitte später erneut versuchen.';

  @override
  String get contentNotFoundError => 'Inhalt nicht gefunden.';

  @override
  String get accessDeniedError => 'Zugriff verweigert. Zugangsdaten prüfen.';

  @override
  String get serviceUnavailableError =>
      'Server nicht erreichbar. Später erneut versuchen.';

  @override
  String get generalError =>
      'Etwas ist schiefgelaufen. Bitte erneut versuchen.';

  @override
  String get skip => 'Überspringen';

  @override
  String get skipIntro => 'Intro überspringen';

  @override
  String get skipOutro => 'Outro überspringen';

  @override
  String get skipRecap => 'Rückblick überspringen';

  @override
  String get goLive => 'Live gehen';

  @override
  String get dismiss => 'Schließen';

  @override
  String get nextUp => 'Als Nächstes';

  @override
  String sourceAttempt(int index, int total) {
    return 'Quelle $index von $total';
  }

  @override
  String get trying => 'Versuchen';

  @override
  String get failed => 'Fehlgeschlagen';

  @override
  String get selected => 'Ausgewählt';

  @override
  String get playing => 'Wiedergabe';

  @override
  String get pending => 'Ausstehend';

  @override
  String get openSubtitles => 'OpenSubtitles';

  @override
  String get subDl => 'SubDL';

  @override
  String get subSource => 'SubSource';

  @override
  String get wifiQualityPreference => 'Wi-Fi-Qualitätspräferenz';

  @override
  String get mobileQualityPreference => 'Mobilfunk-Qualitätspräferenz';

  @override
  String get anyNoPreference => 'Beliebig (keine Präferenz)';

  @override
  String get subtitleAccounts => 'Untertitel-Konten';

  @override
  String get accounts => 'Konten';

  @override
  String get notLoggedIn => 'Nicht angemeldet';

  @override
  String loggedInAs(String username) {
    return 'Angemeldet als $username';
  }

  @override
  String get apiKeyConfigured => 'API-Schlüssel konfiguriert';

  @override
  String get keyNotSet => 'Schlüssel nicht gesetzt';

  @override
  String get testConnection => 'Verbindung testen';

  @override
  String get connectedSuccessfully => 'Erfolgreich verbunden';

  @override
  String get connectionFailed => 'Verbindung fehlgeschlagen';

  @override
  String get username => 'Benutzername';

  @override
  String get password => 'Passwort';

  @override
  String get noAccountRegister => 'Noch kein Konto? Hier registrieren';

  @override
  String get apiKey => 'API-Schlüssel';

  @override
  String get email => 'E-Mail';

  @override
  String get fetchMyApiKey => 'Meinen API-Schlüssel abrufen';

  @override
  String get keyVerified => 'Schlüssel verifiziert';

  @override
  String get invalidApiKey => 'Ungültiger API-Schlüssel';

  @override
  String get openSubtitlesAuthSubtitle =>
      'Geben Sie Ihre Zugangsdaten für höhere Limits und werbefreie Untertitel ein.';

  @override
  String get subDlAuthSubtitle =>
      'Geben Sie Ihren SubDL API-Schlüssel direkt ein oder rufen Sie ihn über Ihre Zugangsdaten ab.';

  @override
  String get orFetchViaAccount => 'ODER ÜBER KONTO ABRUFEN';

  @override
  String get subSourceAuthSubtitle =>
      'SubSource funktioniert standardmäßig, Sie können jedoch einen offiziellen API-Schlüssel für bessere Zuverlässigkeit hinzufügen.';

  @override
  String get apiKeyOptionalOverride => 'API-Schlüssel (Optional)';

  @override
  String get enterKeyToOverrideDefault =>
      'Schlüssel eingeben, um Standard zu überschreiben';

  @override
  String get getApiKeyFromProfile =>
      'Holen Sie sich Ihren API-Schlüssel aus dem SubSource-Profil';

  @override
  String get qualityNotGuaranteed =>
      'Die Qualität wird nicht garantiert. Quellen werden nach Präferenz sortiert, hängen aber vom tatsächlichen Angebot des Anbieters ab.';

  @override
  String get keepSourcesOriginalOrder =>
      'Quellen in Originalreihenfolge beibehalten';

  @override
  String get openLink => 'Link öffnen';

  @override
  String get diagnostics => 'Diagnose';

  @override
  String get viewLogs => 'Protokolle anzeigen';

  @override
  String get viewLogsSubtitle => 'Anwendungsaktivität und Fehler anzeigen';

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
