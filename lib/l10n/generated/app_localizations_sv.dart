// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class AppLocalizationsSv extends AppLocalizations {
  AppLocalizationsSv([String locale = 'sv']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => 'Svenska';

  @override
  String get home => 'Hem';

  @override
  String get search => 'Sök';

  @override
  String get explore => 'Utforska';

  @override
  String get exploreAnime => 'Utforska anime';

  @override
  String get exploreMovies => 'Utforska filmer';

  @override
  String get library => 'Bibliotek';

  @override
  String get settings => 'Inställningar';

  @override
  String get extensions => 'Tillägg';

  @override
  String get updateAvailable => 'Uppdatering tillgänglig';

  @override
  String get retry => 'Försök igen';

  @override
  String get factoryReset => 'Fabriksåterställning';

  @override
  String get startupError => 'Startfel';

  @override
  String get general => 'Allmänt';

  @override
  String get appTheme => 'App-tema';

  @override
  String get recordWatchHistory => 'Spara tittarhistorik';

  @override
  String get defaultHomeScreen => 'Standardhemskärm';

  @override
  String get titlePosition => 'Titelposition';

  @override
  String get titlePositionBelowPoster => 'Under affischen';

  @override
  String get titlePositionInsidePoster => 'På affischen';

  @override
  String get player => 'Spelare';

  @override
  String get defaultPlayer => 'Standardspelare';

  @override
  String get leftGesture => 'Vänster gest';

  @override
  String get rightGesture => 'Höger gest';

  @override
  String get doubleTapToSeek => 'Dubbelklicka för att spola';

  @override
  String get swipeToSeek => 'Svep för att spola';

  @override
  String get seekDuration => 'Spolningstid';

  @override
  String get bufferDepth => 'Buffertdjup';

  @override
  String get defaultResizeMode => 'Standardvisningsläge';

  @override
  String get hardwareDecoding => 'Hårdvaruavkodning';

  @override
  String get network => 'Nätverk';

  @override
  String get dnsOverHttps => 'DNS över HTTPS';

  @override
  String get dohProvider => 'DoH-leverantör';

  @override
  String get githubProxy => 'GitHub-proxy';

  @override
  String get githubProxySubtitle =>
      'Dirigera hämtningar av tillägg via jsDelivr för att kringgå operatörsblockeringar.';

  @override
  String get manageExtensions => 'Hantera tillägg';

  @override
  String get appData => 'Appdata';

  @override
  String get resetDataKeepExtensions => 'Återställ data (behåll tillägg)';

  @override
  String get developer => 'Utvecklare';

  @override
  String get developerOptions => 'Utvecklaralternativ';

  @override
  String get about => 'Om appen';

  @override
  String get version => 'Version';

  @override
  String get enabled => 'Aktiverad';

  @override
  String get disabled => 'Inaktiverad';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'Gå med i vår server';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'Gå med i vår kanal';

  @override
  String developedBy(String name) {
    return 'Developed by $name';
  }

  @override
  String get system => 'System';

  @override
  String get dark => 'Mörkt';

  @override
  String get light => 'Ljust';

  @override
  String get later => 'Senare';

  @override
  String get updateNow => 'Uppdatera nu';

  @override
  String get save => 'Spara';

  @override
  String get cancel => 'Avbryt';

  @override
  String get close => 'Stäng';

  @override
  String get delete => 'Radera';

  @override
  String get viewDetails => 'Visa detaljer';

  @override
  String get clearAll => 'Rensa allt';

  @override
  String get clearAllHistory => 'Rensa historik';

  @override
  String get all => 'Alla';

  @override
  String get none => 'Ingen';

  @override
  String get confirmDownload => 'Bekräfta nedladdning';

  @override
  String get downloadNow => 'Ladda ner nu';

  @override
  String get selectSource => 'Välj källa';

  @override
  String get downloadUnavailable => 'Ej tillgänglig';

  @override
  String get selectAnotherSource => 'Välj en annan';

  @override
  String get watchHistoryCleared => 'Tittarhistorik rensad';

  @override
  String get downloadingUpdate => 'Laddar ner uppdatering...';

  @override
  String errorPrefix(String message) {
    return 'Fel: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'Uppdatering tillgänglig: $tag';
  }

  @override
  String get selectProviderToStart => 'Välj en leverantör för att börja titta';

  @override
  String get tapExtensionIcon => 'Tryck på tilläggsikonen i hörnet';

  @override
  String get continueWatching => 'Fortsätt titta';

  @override
  String get noInternetConnection => 'Ingen internetanslutning';

  @override
  String get siteNotReachable => 'Sidan kan inte nås';

  @override
  String get checkConnectionOrDownloads =>
      'Kontrollera din anslutning eller se ditt nedladdade innehåll.';

  @override
  String get tryVpnOrConnection =>
      'Försök använda en VPN eller kontrollera din internetanslutning.';

  @override
  String errorDetails(String error) {
    return 'Feldetaljer: $error';
  }

  @override
  String get goToDownloads => 'Gå till nedladdningar';

  @override
  String get selectProvider => 'Välj leverantör';

  @override
  String get searchHint => 'Sök filmer, serier...';

  @override
  String get searchFavoriteContent => 'Sök efter ditt favoritinnehåll';

  @override
  String get pressSearchOrEnter => 'Tryck på Sök eller Enter för att börja';

  @override
  String get noResultsFound => 'Inga resultat hittades.';

  @override
  String get couldNotLoadTrending => 'Kunde inte ladda trender';

  @override
  String get popularMovies => 'Populära filmer';

  @override
  String get popularTVShows => 'Populära serier';

  @override
  String get newMovies => 'Nya filmer';

  @override
  String get newTVShows => 'Nya serier';

  @override
  String get featuredMovies => 'Utvalda filmer';

  @override
  String get featuredTVShows => 'Utvalda serier';

  @override
  String get lastVideosTVShows => 'Senaste serierna';

  @override
  String get downloads => 'Nedladdningar';

  @override
  String get bookmarks => 'Bokmärken';

  @override
  String get noDownloadsYet => 'Inga nedladdningar ännu';

  @override
  String episodesCount(int count, int done) {
    return '$count avsnitt • $done klara';
  }

  @override
  String get deleteAllEpisodes => 'Radera alla avsnitt';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return 'Är du säker på att du vill radera alla $count avsnitt av \"$title\" och deras filer?';
  }

  @override
  String get deleteAll => 'Radera alla';

  @override
  String get completed => 'Klar';

  @override
  String get statusQueued => 'I kö...';

  @override
  String get statusDownloading => 'Laddar ner...';

  @override
  String get statusFinished => 'Klar';

  @override
  String get statusFailed => 'Misslyckades';

  @override
  String get statusCanceled => 'Avbruten';

  @override
  String get statusPaused => 'Pausad';

  @override
  String get statusWaiting => 'Väntar...';

  @override
  String get fileNotFoundRemoving =>
      'Filen hittades inte på disken. Tar bort posten.';

  @override
  String get fileNotFound => 'Filen hittades inte';

  @override
  String get deleteDownload => 'Radera nedladdning';

  @override
  String get confirmDeleteDownload =>
      'Är du säker på att du vill radera denna nedladdning?';

  @override
  String get libraryEmpty => 'Ditt bibliotek är tomt';

  @override
  String get language => 'Språk';

  @override
  String get english => 'Engelska';

  @override
  String get hindi => 'Hindi';

  @override
  String get kannada => 'Kannada';

  @override
  String get unknown => 'Okänt';

  @override
  String get recommended => 'Rekommenderat';

  @override
  String get on => 'På';

  @override
  String get off => 'Av';

  @override
  String get installRemoveProviders => 'Installera eller ta bort leverantörer';

  @override
  String get resetDataSubtitle =>
      'Rensa inställningar och databas, behåll insticksfiler';

  @override
  String get factoryResetSubtitle =>
      'Radera all data, inställningar och tillägg';

  @override
  String get developerOptionsSubtitle =>
      'Felsökningsverktyg och lokal uppspelning';

  @override
  String get loading => 'Laddar...';

  @override
  String get sec => 'sek';

  @override
  String get min => 'min';

  @override
  String get internalPlayer => 'Intern (media_kit)';

  @override
  String get builtInPlayer => 'Inbyggd spelare';

  @override
  String get customNotSet => 'Anpassad (inte inställd)';

  @override
  String selectGesture(String side) {
    return 'Välj $side gest';
  }

  @override
  String get left => 'vänster';

  @override
  String get right => 'höger';

  @override
  String get selectSeekDuration => 'Välj spolningstid';

  @override
  String get selectBufferDepth => 'Välj buffertdjup';

  @override
  String get subtitleSettings => 'Undertextinställningar';

  @override
  String size(int size) {
    return 'Storlek: $size';
  }

  @override
  String get background => 'Bakgrund';

  @override
  String get customDohUrlLabel => 'Anpassad DoH-URL';

  @override
  String get enterCustomDohUrl => 'Ange din egen DoH-URL';

  @override
  String get chooseTheme => 'Välj tema';

  @override
  String get resetDataDialogTitle => 'Återställa data?';

  @override
  String get resetDataDialogContent =>
      'Detta rensar inställningar, favoriter och historik. Dina installerade tillägg kommer INTE raderas.';

  @override
  String get factoryResetDialogTitle => 'Fabriksåterställning?';

  @override
  String get factoryResetDialogContent =>
      'Detta raderar ALLT: favoriter, historik, inställningar och ALLA tillägg. Detta kan inte ångras.';

  @override
  String get selectLanguage => 'Välj språk';

  @override
  String get synopsis => 'Sammanfattning';

  @override
  String get noDescription => 'Ingen beskrivning tillgänglig.';

  @override
  String get videoAlreadyDownloadedPrompt =>
      'Denna video har redan laddats ner. Vad vill du göra?';

  @override
  String get playNow => 'Spela nu';

  @override
  String get upNext => 'Nästa';

  @override
  String get deleteDownloadPrompt => 'Radera nedladdning?';

  @override
  String get deleteDownloadConfirmation =>
      'Är du säker på att du vill radera denna fil? Detta kan inte ångras.';

  @override
  String get no => 'Nej';

  @override
  String get yesDelete => 'Ja, radera';

  @override
  String get downloadPaused => 'Nedladdning pausad';

  @override
  String get downloading => 'Laddar ner';

  @override
  String get speed => 'Hastighet';

  @override
  String get remaining => 'Återstår';

  @override
  String get resume => 'Fortsätt';

  @override
  String get pause => 'Pausa';

  @override
  String get torrentContent => 'Torrent-innehåll';

  @override
  String get audioTracks => 'Ljudspår';

  @override
  String get noAudioTracks => 'Inga ljudspår hittades';

  @override
  String get subtitles => 'Undertexter';

  @override
  String get options => 'Alternativ';

  @override
  String get noSubtitlesFound => 'Inga undertextspår hittades';

  @override
  String get playbackSpeed => 'Uppspelningshastighet';

  @override
  String get subtitleOptions => 'Alternativ för undertexter';

  @override
  String get hlsSubtitleWarning =>
      'Externa undertextfiler stöds inte för HLS på denna plattform.';

  @override
  String get loadFromDevice => 'Ladda från enhet';

  @override
  String get syncDelay => 'Synk / Fördröjning';

  @override
  String get styleSettings => 'Stilinställningar';

  @override
  String get searchOnline => 'Sök online (behåll undertexter)';

  @override
  String get subtitleSync => 'Undertextsynk';

  @override
  String get subtitleDelayWarning =>
      'Fördröjning av undertexter stöds inte av den nuvarande spelaren.';

  @override
  String get resetDelay => 'Återställ fördröjning';

  @override
  String get subtitleStyles => 'Undertextstilar';

  @override
  String get mediaKitStylingWarning =>
      'Stilinställningar för undertexter är för tillfället endast tillgängliga i media_kit-spelaren.';

  @override
  String get resetToDefault => 'Återställ till standard';

  @override
  String get fontSize => 'Textstorlek';

  @override
  String get verticalPosition => 'Vertikal position';

  @override
  String get textColor => 'Textfärg';

  @override
  String get backgroundColor => 'Bakgrundsfärg';

  @override
  String get backgroundOpacity => 'Bakgrundens opacitet';

  @override
  String get subtitleSearch => 'Sök efter undertexter';

  @override
  String get searchSubtitleNameHint => 'Sök undertextnamn...';

  @override
  String get enterSearchSubtitlePrompt =>
      'Ange ett namn för att söka efter undertexter.';

  @override
  String get noSubtitleResults => 'Inga resultat hittades.';

  @override
  String get downloadingApplyingSubtitle =>
      'Laddar ner och använder undertext...';

  @override
  String get failedToDownloadSubtitle => 'Kunde inte ladda ner undertext.';

  @override
  String get failedToLoadSubtitles =>
      'Kunde inte ladda undertexter. Försök igen.';

  @override
  String get noReposFound => 'Inga källor eller insticksfiler hittades';

  @override
  String get downloadAllProviders => 'Ladda ner alla';

  @override
  String get removeRepository => 'Ta bort källa';

  @override
  String get addRepo => 'Lägg till källa';

  @override
  String get extensionsNotInRepos => 'Tillägg som inte finns i källor';

  @override
  String get noLongerInRepo => 'Finns inte längre i någon källa';

  @override
  String get addRepoToBrowse =>
      'Lägg till en källa för att bläddra bland insticksfiler';

  @override
  String get debugExtensions => 'Felsök tillägg';

  @override
  String removeRepoConfirm(String repoName) {
    return 'Ta bort $repoName?';
  }

  @override
  String get removeRepoWarning =>
      'Detta tar bort källan och avinstallerar ALLA dess insticksfiler.';

  @override
  String get addRepository => 'Lägg till källa';

  @override
  String get repoUrlOrShortcode => 'Källans URL eller kortkod';

  @override
  String get assetPlugin => 'Inbyggd insticksfil';

  @override
  String get installed => 'Installerad';

  @override
  String get repositories => 'Utvecklingskataloger';

  @override
  String get noExtensionsInstalled => 'Inga tillägg installerade';

  @override
  String get browseRepositoriesToInstall =>
      'Öppna fliken Utvecklingskataloger för att hitta och installera tillägg.';

  @override
  String get browseRepositories => 'Bläddra bland kataloger';

  @override
  String get addRepoDescription =>
      'Lägg till en katalog-URL eller kortkod för att hitta och installera tilläggsplugin.';

  @override
  String updateTo(String version) {
    return 'Uppdatera till $version';
  }

  @override
  String get install => 'Installera';

  @override
  String get error => 'Fel';

  @override
  String get ok => 'OK';

  @override
  String pluginSettings(String pluginName) {
    return 'Inställningar för $pluginName';
  }

  @override
  String get movies => 'Filmer';

  @override
  String get series => 'Serier';

  @override
  String get anime => 'Anime';

  @override
  String get liveStreams => 'Livestreamar';

  @override
  String get debug => 'DEBUG';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tillägg uppdaterade',
      one: '1 tillägg uppdaterat',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => 'Ogiltig navigering.';

  @override
  String get startOver => 'Börja om';

  @override
  String get goBack => 'Gå tillbaka';

  @override
  String get resolving => 'Löser länkar...';

  @override
  String get downloaded => 'Nedladdad';

  @override
  String get download => 'Ladda ner';

  @override
  String get debugOnlyFeature => 'Endast för debug-versioner';

  @override
  String get streamUrl => 'Stream-URL';

  @override
  String get play => 'Spela';

  @override
  String get verifyingSourceSize => 'Verifierar källa och storlek...';

  @override
  String get fileSaveLocationNotification =>
      'Filen kommer att sparas i mappen Hämtade filer.';

  @override
  String get resumingPlayback => 'Återupptar uppspelning';

  @override
  String pausedAt(String time) {
    return 'Pausad vid $time';
  }

  @override
  String resumesAutomatically(int count) {
    return 'Återupptar automatiskt om $count sek';
  }

  @override
  String get resumeNow => 'Återuppta nu';

  @override
  String get playbackError => 'Uppspelningsfel';

  @override
  String get confirmClearHistory => 'Radera all historik?';

  @override
  String seasonWithNumber(Object number) {
    return 'Säsong $number';
  }

  @override
  String get starting => 'Startar...';

  @override
  String percentWatched(int percent) {
    return '$percent% tittat';
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
  String get debugTools => 'Felsökningsverktyg';

  @override
  String get playLocalVideo => 'Lokal video';

  @override
  String get playLocalVideoSubtitle => 'Spela fil från enhet';

  @override
  String get streamUrlSubtitle => 'Spela från nätverks-URL';

  @override
  String get streamTorrent => 'Stream torrent';

  @override
  String get streamTorrentSubtitle => 'Välj lokal torrent-fil';

  @override
  String get loadPluginFromAssets => 'Ladda insticksfil från tillgångar';

  @override
  String get enterVideoUrlHint => 'Ange video-URL (http, magnet etc.)';

  @override
  String get networkStream => 'Nätverksström';

  @override
  String removedFromHistory(String title) {
    return 'Tog bort från historik: $title';
  }

  @override
  String get custom => 'Anpassad';

  @override
  String get refreshingLiveStream => 'Uppdaterar livestream...';

  @override
  String get removeFromHistory => 'Ta bort från historik';

  @override
  String get live => 'LIVE';

  @override
  String get volume => 'Volym';

  @override
  String get brightness => 'Ljusstyrka';

  @override
  String get fit => 'Passa';

  @override
  String get zoom => 'Zooma';

  @override
  String get stretch => 'Sträck ut';

  @override
  String titleWithParam(String title) {
    return 'Titel: $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'Källa: $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'Storlek: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'Fel: $error. Använder intern spelare.';
  }

  @override
  String playerNotDetected(String playerName) {
    return '$playerName hittades inte.';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return 'Säsong $number ($count avsnitt)';
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
    return 'Källa för $playerName';
  }

  @override
  String get noPluginsInstalled => 'Inga insticksfiler installerade';

  @override
  String get noPluginsMessage =>
      'Installera tillägg för att bläddra och strömma innehåll.';

  @override
  String get goToExtensions => 'Gå till tillägg';

  @override
  String get availableSources => 'Tillgängliga källor';

  @override
  String get seasons => 'Säsonger';

  @override
  String get episodes => 'Avsnitt';

  @override
  String get selectSourceToPlay => 'Välj en källa att spela upp.';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count avsnitt',
      one: '1 avsnitt',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'Inga avsnitt hittades';

  @override
  String get local => 'Lokal';

  @override
  String get remote => 'Fjärr';

  @override
  String get torrent => 'Torrent';

  @override
  String get unlock => 'Lås upp';

  @override
  String get lock => 'Lås';

  @override
  String get sources => 'Källor';

  @override
  String get tracks => 'Spår';

  @override
  String get content => 'Innehåll';

  @override
  String get stats => 'Statistik';

  @override
  String get resize => 'Storlek';

  @override
  String get next => 'Nästa';

  @override
  String get pip => 'PiP';

  @override
  String get rotate => 'Rotera';

  @override
  String get windowed => 'Fönster';

  @override
  String get fullscreen => 'Helskärm';

  @override
  String get movieDetails => 'Filminformation';

  @override
  String get showDetails => 'Visa detaljer';

  @override
  String get tagline => 'Tagline';

  @override
  String get status => 'Status';

  @override
  String get releaseDate => 'Utgivningsdatum';

  @override
  String get firstAirDate => 'Sändes första gången';

  @override
  String get originalLanguage => 'Originalspråk';

  @override
  String get originCountry => 'Ursprungsland';

  @override
  String get budgetLabel => 'Budget';

  @override
  String get revenueLabel => 'Intäkt';

  @override
  String get paused => 'Pausad';

  @override
  String get watched => 'Sett';

  @override
  String get watching => 'Tittar';

  @override
  String get lastWatched => 'Senast sedda';

  @override
  String get movie => 'Film';

  @override
  String get tvShow => 'Serie';

  @override
  String get failedToLoadContent => 'Laddning misslyckades';

  @override
  String get director => 'Regissör';

  @override
  String get creator => 'Skapare';

  @override
  String get showMore => 'Visa mer';

  @override
  String get showLess => 'Visa mindre';

  @override
  String get viewAll => 'Visa alla';

  @override
  String seasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count säsonger',
      one: '1 säsong',
    );
    return '$_temp0';
  }

  @override
  String get noInternetError => 'Inget internet';

  @override
  String get timeoutError => 'Tiden gick ut.';

  @override
  String get serverError => 'Serverfel.';

  @override
  String get contentNotFoundError => 'Hittades inte.';

  @override
  String get accessDeniedError => 'Åtkomst nekad.';

  @override
  String get serviceUnavailableError => 'Tjänsten inte tillgänglig.';

  @override
  String get generalError => 'Ett fel uppstod.';

  @override
  String get skip => 'Hoppa över';

  @override
  String get skipIntro => 'Hoppa över intro';

  @override
  String get skipOutro => 'Hoppa över eftertexter';

  @override
  String get skipRecap => 'Hoppa över sammanfattning';

  @override
  String get goLive => 'Gå live';

  @override
  String get dismiss => 'Stäng';

  @override
  String get nextUp => 'Nästa';

  @override
  String sourceAttempt(int index, int total) {
    return 'Källa $index av $total';
  }

  @override
  String get trying => 'Försöker';

  @override
  String get failed => 'Misslyckades';

  @override
  String get selected => 'Vald';

  @override
  String get playing => 'Spelar';

  @override
  String get pending => 'Väntar';

  @override
  String get openSubtitles => 'OpenSubtitles';

  @override
  String get subDl => 'SubDL';

  @override
  String get subSource => 'SubSource';

  @override
  String get wifiQualityPreference => 'Kvalitetsinställning för Wi-Fi';

  @override
  String get mobileQualityPreference => 'Kvalitetsinställning för mobilnät';

  @override
  String get anyNoPreference => 'Inget val';

  @override
  String get subtitleAccounts => 'Undertextkonton';

  @override
  String get accounts => 'Konton';

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
  String get testConnection => 'Testa anslutning';

  @override
  String get connectedSuccessfully => 'Ansluten';

  @override
  String get connectionFailed => 'Anslutning misslyckades';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get noAccountRegister => 'Don\'t have an account? Register here';

  @override
  String get apiKey => 'API-nyckel';

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
  String get diagnostics => 'Diagnostik';

  @override
  String get viewLogs => 'Visa loggar';

  @override
  String get viewLogsSubtitle => 'Visa appaktivitet och fel';

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
