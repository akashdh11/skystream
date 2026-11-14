// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Latvian (`lv`).
class AppLocalizationsLv extends AppLocalizations {
  AppLocalizationsLv([String locale = 'lv']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => 'Latviešu';

  @override
  String get addonHealthChecking => 'Checking add-on…';

  @override
  String addonHealthWorking(int ms) {
    return 'Working · $ms ms';
  }

  @override
  String get addonHealthUnavailable => 'Unavailable';

  @override
  String get home => 'Sākums';

  @override
  String get search => 'Meklēt';

  @override
  String get explore => 'Izpētīt';

  @override
  String get exploreAnime => 'Pārlūkot anime';

  @override
  String get exploreMovies => 'Pārlūkot filmas';

  @override
  String get library => 'Bibliotēka';

  @override
  String get settings => 'Iestatījumi';

  @override
  String get extensions => 'Paplašinājumi';

  @override
  String get updateAvailable => 'Pieejams atjauninājums';

  @override
  String get retry => 'Mēģināt vēlreiz';

  @override
  String get factoryReset => 'Rūpnīcas iestatījumi';

  @override
  String get startupError => 'Startēšanas kļūda';

  @override
  String get general => 'Vispārīgi';

  @override
  String get appTheme => 'Lietotnes motīvs';

  @override
  String get recordWatchHistory => 'Ierakstīt skatīšanās vēsturi';

  @override
  String get fullScreenMode => 'Pilnekrāna režīms';

  @override
  String get fullScreenModeSubtitle => 'Pārslēdzas uz TV saskarni';

  @override
  String get defaultHomeScreen => 'Noklusējuma sākuma ekrāns';

  @override
  String get titlePosition => 'Nosaukuma novietojums';

  @override
  String get titlePositionBelowPoster => 'Zem plakāta';

  @override
  String get titlePositionInsidePoster => 'Uz plakāta';

  @override
  String get player => 'Atskaņotājs';

  @override
  String get defaultPlayer => 'Noklusējuma atskaņotājs';

  @override
  String get leftGesture => 'Kreisais žests';

  @override
  String get rightGesture => 'Labais žests';

  @override
  String get doubleTapToSeek => 'Dubultskāriens, lai meklētu';

  @override
  String get swipeToSeek => 'Pārvilkt, lai meklētu';

  @override
  String get seekDuration => 'Meklēšanas ilgums';

  @override
  String get defaultResizeMode => 'Noklusējuma izmēru maiņas režīms';

  @override
  String get hardwareDecoding => 'Aparatūras dekodēšana';

  @override
  String get network => 'Tīkls';

  @override
  String get dnsOverHttps => 'DNS caur HTTPS';

  @override
  String get dohProvider => 'DoH pakalpojumu sniedzējs';

  @override
  String get githubProxy => 'GitHub starpniekserveris';

  @override
  String get githubProxySubtitle =>
      'Novirzīt paplašinājumu lejupielādes caur jsDelivr, lai apietu interneta pakalpojumu sniedzēja bloķēšanu.';

  @override
  String get manageExtensions => 'Pārvaldīt paplašinājumus';

  @override
  String get appData => 'Lietotnes dati';

  @override
  String get resetDataKeepExtensions =>
      'Atiestatīt datus (saglabāt paplašinājumus)';

  @override
  String get developer => 'Izstrādātājs';

  @override
  String get developerOptions => 'Izstrādātāja opcijas';

  @override
  String get about => 'Par lietotni';

  @override
  String get version => 'Versija';

  @override
  String get openSourceLicences => 'Open-source licences';

  @override
  String get openSourceLicencesSubtitle =>
      'SkyStream is free software under the GNU GPL v3';

  @override
  String get appLegalese =>
      'Copyright © 2025–2026 SkyStream contributors.\nSkyStream is free software: you can redistribute it and modify it under the terms of the GNU General Public License, version 3. It comes with ABSOLUTELY NO WARRANTY. Its source code is at github.com/akashdh11/skystream.';

  @override
  String get enabled => 'Iespējots';

  @override
  String get disabled => 'Atspējots';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'Pievienojieties mūsu serverim';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'Pievienojieties mūsu kanālam';

  @override
  String developedBy(String name) {
    return 'Developed by $name';
  }

  @override
  String get system => 'Sistēmas';

  @override
  String get dark => 'Tumšs';

  @override
  String get light => 'Gaišs';

  @override
  String get later => 'Vēlāk';

  @override
  String get updateNow => 'Atjaunināt tagad';

  @override
  String get save => 'Saglabāt';

  @override
  String get cancel => 'Atcelt';

  @override
  String get close => 'Aizvērt';

  @override
  String get delete => 'Dzēst';

  @override
  String get viewDetails => 'Skatīt informāciju';

  @override
  String get clearAll => 'Notīrīt visu';

  @override
  String get clearAllHistory => 'Notīrīt skatīšanās vēsturi';

  @override
  String get all => 'Visi';

  @override
  String get none => 'Neviens';

  @override
  String get confirmDownload => 'Apstiprināt lejupielādi';

  @override
  String get downloadNow => 'Lejupielādēt tagad';

  @override
  String get selectSource => 'Izvēlēties avotu';

  @override
  String get downloadUnavailable => 'Nav pieejams';

  @override
  String get selectAnotherSource => 'Izvēlēties citu';

  @override
  String get watchHistoryCleared => 'Skatīšanās vēsture notīrīta';

  @override
  String get downloadingUpdate => 'Lejupielādē atjauninājumu...';

  @override
  String errorPrefix(String message) {
    return 'Kļūda: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'Pieejams atjauninājums: $tag';
  }

  @override
  String get selectProviderToStart =>
      'Izvēlieties pakalpojumu sniedzēju, lai sāktu';

  @override
  String get tapExtensionIcon => 'Pieskarieties paplašinājuma ikonai stūrī';

  @override
  String get continueWatching => 'Turpināt skatīties';

  @override
  String get noInternetConnection => 'Nav interneta savienojuma';

  @override
  String get siteNotReachable => 'Lapa nav sasniedzama';

  @override
  String get checkConnectionOrDownloads =>
      'Pārbaudiet savu savienojumu vai skatiet lejupielādes.';

  @override
  String get tryVpnOrConnection =>
      'Izmēģiniet VPN vai pārbaudiet interneta savienojumu.';

  @override
  String errorDetails(String error) {
    return 'Kļūdas informācija: $error';
  }

  @override
  String get goToDownloads => 'Doties uz lejupielādēm';

  @override
  String get selectProvider => 'Izvēlēties pakalpojumu sniedzēju';

  @override
  String get searchHint => 'Meklēt filmas, seriālus...';

  @override
  String get searchFavoriteContent => 'Meklējiet savu iecienītāko saturu';

  @override
  String get pressSearchOrEnter => 'Nospiediet Meklēt vai Enter, lai sāktu';

  @override
  String get recentSearches => 'Recent searches';

  @override
  String removeFromSearchHistory(String query) {
    return 'Remove $query from search history';
  }

  @override
  String get noResultsFound => 'Nekas netika atrasts.';

  @override
  String get couldNotLoadTrending => 'Neizdevās ielādēt tendences';

  @override
  String get popularMovies => 'Populāras filmas';

  @override
  String get popularTVShows => 'Populāri seriāli';

  @override
  String get newMovies => 'Jaunas filmas';

  @override
  String get newTVShows => 'Jauni seriāli';

  @override
  String get featuredMovies => 'Iesaka filmas';

  @override
  String get featuredTVShows => 'Iesaka seriālus';

  @override
  String get lastVideosTVShows => 'Pēdējie video';

  @override
  String get downloads => 'Lejupielādes';

  @override
  String get bookmarks => 'Grāmatzīmes';

  @override
  String get noDownloadsYet => 'Vēl nav lejupielāžu';

  @override
  String episodesCount(int count, int done) {
    return '$count sērijas • $done pabeigtas';
  }

  @override
  String get deleteAllEpisodes => 'Dzēst visas sērijas';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return 'Vai tiešām vēlaties dzēst visas $count sērijas no \"$title\" un to failus?';
  }

  @override
  String get deleteAll => 'Dzēst visu';

  @override
  String get completed => 'Pabeigts';

  @override
  String get statusQueued => 'Rindā...';

  @override
  String get statusDownloading => 'Lejupielādē...';

  @override
  String get statusFinished => 'Pabeigts';

  @override
  String get statusFailed => 'Neizdevās';

  @override
  String get statusCanceled => 'Atcelts';

  @override
  String get statusPaused => 'Pauzēts';

  @override
  String get statusWaiting => 'Gaidīšana...';

  @override
  String get fileNotFoundRemoving =>
      'Fails netika atrasts. Ieraksts tiek dzēsts.';

  @override
  String get fileNotFound => 'Fails nav atrasts';

  @override
  String get deleteDownload => 'Dzēst lejupielādi';

  @override
  String get confirmDeleteDownload =>
      'Vai tiešām vēlaties dzēst šo lejupielādi?';

  @override
  String get libraryEmpty => 'Jūsu bibliotēka ir tukša';

  @override
  String get language => 'Valoda';

  @override
  String get english => 'Angļu';

  @override
  String get hindi => 'Hindi';

  @override
  String get kannada => 'Kannadu';

  @override
  String get unknown => 'Nezināms';

  @override
  String get recommended => 'Ieteicams';

  @override
  String get on => 'Ieslēgts';

  @override
  String get off => 'Izslēgts';

  @override
  String get installRemoveProviders =>
      'Instalēt vai noņemt pakalpojumu sniedzējus';

  @override
  String get resetDataSubtitle =>
      'Notīrīt iestatījumus un DB, saglabāt spraudņus';

  @override
  String get factoryResetSubtitle =>
      'Dzēst visus datus, iestatījumus un paplašinājumus';

  @override
  String get developerOptionsSubtitle =>
      'Atkļūdošanas rīki un lokālā atskaņošana';

  @override
  String get loading => 'Ielādē...';

  @override
  String get sec => 'sek.';

  @override
  String get min => 'min.';

  @override
  String playerRewindSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Atpakaļ par $count sekundēm',
      one: 'Atpakaļ par $count sekundi',
      zero: 'Atpakaļ par $count sekundēm',
    );
    return '$_temp0';
  }

  @override
  String playerForwardSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Uz priekšu par $count sekundēm',
      one: 'Uz priekšu par $count sekundi',
      zero: 'Uz priekšu par $count sekundēm',
    );
    return '$_temp0';
  }

  @override
  String get internalPlayer => 'Iekšējais (VLC)';

  @override
  String get builtInPlayer => 'Iebūvētais atskaņotājs';

  @override
  String get customNotSet => 'Pielāgots (nav iestatīts)';

  @override
  String selectGesture(String side) {
    return 'Izvēlēties $side žestu';
  }

  @override
  String get left => 'kreiso';

  @override
  String get right => 'labo';

  @override
  String get selectSeekDuration => 'Izvēlēties meklēšanas ilgumu';

  @override
  String get subtitleSettings => 'Subtitru iestatījumi';

  @override
  String size(int size) {
    return 'Izmērs: $size';
  }

  @override
  String get background => 'Fons';

  @override
  String get customDohUrlLabel => 'Pielāgota DoH URL';

  @override
  String get enterCustomDohUrl => 'Ievadiet savu DoH URL';

  @override
  String get chooseTheme => 'Izvēlēties motīvu';

  @override
  String get resetDataDialogTitle => 'Atiestatīt datus?';

  @override
  String get resetDataDialogContent =>
      'Tas notīrīs Iestatījumus, Izlasi un Vēsturi. Instalētie paplašinājumi NETIKS dzēsti.';

  @override
  String get factoryResetDialogTitle => 'Rūpnīcas atiestatīšana?';

  @override
  String get factoryResetDialogContent =>
      'Tas izdzēsīs VISU. Šo darbību nevar atsaukt.';

  @override
  String get selectLanguage => 'Izvēlēties valodu';

  @override
  String get synopsis => 'Sinopsis';

  @override
  String get noDescription => 'Apraksts nav pieejams.';

  @override
  String get videoAlreadyDownloadedPrompt =>
      'Šis video jau ir lejupielādēts. Ko vēlaties darīt?';

  @override
  String get playNow => 'Atskaņot tūlīt';

  @override
  String get upNext => 'Tālāk';

  @override
  String get deleteDownloadPrompt => 'Dzēst lejupielādi?';

  @override
  String get deleteDownloadConfirmation =>
      'Vai tiešām vēlaties dzēst šo failu? To nevar atsaukt.';

  @override
  String get no => 'Nē';

  @override
  String get yesDelete => 'Jā, dzēst';

  @override
  String get downloadPaused => 'Lejupielāde pauzēta';

  @override
  String get downloading => 'Lejupielādē';

  @override
  String get speed => 'Ātrums';

  @override
  String get remaining => 'Atlicis';

  @override
  String get resume => 'Atsākt';

  @override
  String get pause => 'Pauzēt';

  @override
  String get torrentContent => 'Torrenta saturs';

  @override
  String get audioTracks => 'Audio celiņi';

  @override
  String get noAudioTracks => 'Netika atrasti audio celiņi';

  @override
  String get subtitles => 'Subtitri';

  @override
  String get options => 'Opcijas';

  @override
  String get noSubtitlesFound => 'Netika atrasti subtitri';

  @override
  String get playbackSpeed => 'Atskaņošanas ātrums';

  @override
  String get subtitleOptions => 'Subtitru opcijas';

  @override
  String get hlsSubtitleWarning =>
      'Ārējie subtitri šajā platformā netiek atbalstīti HLS straumēm.';

  @override
  String get loadFromDevice => 'Ielādēt no ierīces';

  @override
  String get syncDelay => 'Sinhronizācija / Kavēšanās';

  @override
  String get styleSettings => 'Stila iestatījumi';

  @override
  String get searchOnline => 'Meklēt tiešsaistē (subtitru meklēšana)';

  @override
  String get subtitleSync => 'Subtitru sinhronizācija';

  @override
  String get subtitleDelayWarning =>
      'Subtitru kavēšanās netiek atbalstīta pašreizējā atskaņotājā.';

  @override
  String get resetDelay => 'Atiestatīt kavēšanos';

  @override
  String get subtitleStyles => 'Subtitru stili';

  @override
  String get resetToDefault => 'Atjaunot noklusējumu';

  @override
  String get fontSize => 'Fonta izmērs';

  @override
  String get verticalPosition => 'Vertikālā pozīcija';

  @override
  String get textColor => 'Teksta krāsa';

  @override
  String get backgroundColor => 'Fona krāsa';

  @override
  String get backgroundOpacity => 'Fona caurspīdīgums';

  @override
  String get subtitleSearch => 'Subtitru meklēšana';

  @override
  String get searchSubtitleNameHint => 'Subtitru nosaukums...';

  @override
  String get enterSearchSubtitlePrompt =>
      'Ievadiet nosaukumu, lai meklētu subtitrus.';

  @override
  String get noSubtitleResults => 'Rezultātu nav.';

  @override
  String get downloadingApplyingSubtitle => 'Lejupielādē un lieto subtitrus...';

  @override
  String get failedToDownloadSubtitle => 'Neizdevās lejupielādēt subtitrus.';

  @override
  String get failedToLoadSubtitles =>
      'Neizdevās ielādēt subtitrus. Mēģiniet vēlreiz.';

  @override
  String get noReposFound => 'Netika atrasti krātuves vai spraudņi';

  @override
  String get downloadAllProviders => 'Lejupielādēt visu';

  @override
  String get removeRepository => 'Noņemt krātuvi';

  @override
  String get addRepo => 'Pievienot krātuvi';

  @override
  String get extensionsNotInRepos => 'Paplašinājumi ārpus krātuvēm';

  @override
  String get noLongerInRepo => 'Vairs nav nevienā krātuvē';

  @override
  String get addRepoToBrowse => 'Pievienojiet krātuvi, lai pārlūkotu spraudņus';

  @override
  String get debugExtensions => 'Atkļūdot paplašinājumus';

  @override
  String removeRepoConfirm(String repoName) {
    return 'Vai noņemt $repoName?';
  }

  @override
  String get removeRepoWarning =>
      'Tas noņems krātuvi un atinstalēs visus tās spraudņus.';

  @override
  String get addRepository => 'Pievienot krātuvi';

  @override
  String get repoUrlOrShortcode => 'Krātuves URL vai īsais kods';

  @override
  String get assetPlugin => 'Aktīvu spraudnis';

  @override
  String get installed => 'Instalēts';

  @override
  String get repositories => 'Repozitoriji';

  @override
  String get noExtensionsInstalled => 'Nav instalētu paplašinājumu';

  @override
  String get browseRepositoriesToInstall =>
      'Atveriet cilni Repozitoriji, lai atrastu un instalētu paplašinājumus.';

  @override
  String get browseRepositories => 'Pārlūkot repozitorijus';

  @override
  String get addRepoDescription =>
      'Pievienojiet repozitorija URL vai īso kodu, lai atrastu un instalētu paplašinājumu spraudņus.';

  @override
  String updateTo(String version) {
    return 'Atjaunināt uz $version';
  }

  @override
  String get install => 'Instalēt';

  @override
  String get installFromThisRepository => 'Install from this repository';

  @override
  String installFromThisRepositoryTitle(String pluginName) {
    return 'Install $pluginName from this repository?';
  }

  @override
  String installFromThisRepositoryMessage(
    String source,
    String version,
    String repoName,
  ) {
    return 'The copy you have came from $source. This installs version $version from $repoName in its place, and from then on its updates come from $repoName only.';
  }

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
  String get error => 'Kļūda';

  @override
  String get ok => 'Labi';

  @override
  String pluginSettings(String pluginName) {
    return '$pluginName iestatījumi';
  }

  @override
  String get movies => 'Filmas';

  @override
  String get series => 'Seriāli';

  @override
  String get anime => 'Anime';

  @override
  String get liveStreams => 'Tiešraides';

  @override
  String get debug => 'DEBUG';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paplašinājumi atjaunināti',
      one: '1 paplašinājums atjaunināts',
    );
    return '$_temp0';
  }

  @override
  String extensionsNewRepositories(int count, String source) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$source: $count jauni repozitoriji',
      one: '$source: $count jauns repozitorijs',
    );
    return '$_temp0';
  }

  @override
  String extensionsNewPlugins(int count, String repository) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$repository: $count jauni spraudņi',
      one: '$repository: $count jauns spraudnis',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => 'Nederīga navigācija.';

  @override
  String get startOver => 'Sākt no jauna';

  @override
  String get goBack => 'Atpakaļ';

  @override
  String get restartApp => 'Restartēt lietotni';

  @override
  String get resolving => 'Atrisina...';

  @override
  String get downloaded => 'Lejupielādēts';

  @override
  String get download => 'Lejupielādēt';

  @override
  String get debugOnlyFeature => 'Tikai izstrādes versijām';

  @override
  String get streamUrl => 'Straumēšanas URL';

  @override
  String get play => 'Atskaņot';

  @override
  String get verifyingSourceSize => 'Pārbauda avotu un izmēru...';

  @override
  String get fileSaveLocationNotification =>
      'Fails tiks saglabāts lejupielāžu mapē.';

  @override
  String get resumingPlayback => 'Atsāk atskaņošanu';

  @override
  String pausedAt(String time) {
    return 'Pauzēts $time';
  }

  @override
  String resumesAutomatically(int count) {
    return 'Automātiski atsāks pēc $count sek.';
  }

  @override
  String get resumeNow => 'Atsākt tagad';

  @override
  String get playbackError => 'Atskaņošanas kļūda';

  @override
  String get confirmClearHistory => 'Notīrīt visu vēsturi?';

  @override
  String seasonWithNumber(Object number) {
    return '$number. sezona';
  }

  @override
  String get starting => 'Startēšana...';

  @override
  String percentWatched(int percent) {
    return '$percent% noskatīts';
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
  String get debugTools => 'Atkļūdošanas rīki';

  @override
  String get playLocalVideo => 'Lokāls video';

  @override
  String get playLocalVideoSubtitle => 'Atskaņot failu no ierīces';

  @override
  String get streamUrlSubtitle => 'Atskaņot no URL';

  @override
  String get streamTorrent => 'Straumēt torrentu';

  @override
  String get streamTorrentSubtitle => 'Izvēlēties torrenta failu';

  @override
  String get loadPluginFromAssets => 'Ielādēt spraudni no aktīviem';

  @override
  String get enterVideoUrlHint => 'Video URL';

  @override
  String get networkStream => 'Tīkla straume';

  @override
  String removedFromHistory(String title) {
    return 'Noņemts no vēstures: $title';
  }

  @override
  String get custom => 'Pielāgots';

  @override
  String get refreshingLiveStream => 'Atsvaidzina...';

  @override
  String get removeFromHistory => 'Noņemt no vēstures';

  @override
  String get live => 'TIEŠRAIDE';

  @override
  String get volume => 'Skaļums';

  @override
  String get decrease => 'Decrease';

  @override
  String get increase => 'Increase';

  @override
  String get brightness => 'Spilgtums';

  @override
  String get fit => 'Ietilpināt';

  @override
  String get zoom => 'Tuvināt';

  @override
  String get stretch => 'Izstiept';

  @override
  String titleWithParam(String title) {
    return 'Nosaukums: $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'Avots: $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'Izmērs: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'Kļūda: $error. Iekšējais atskaņotājs.';
  }

  @override
  String externalPlayerCannotSendHeaders(String playerName, String headers) {
    return '$playerName cannot send $headers. Using internal player.';
  }

  @override
  String playerNotDetected(String playerName) {
    return '$playerName nav atrasts.';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return '$number. sezona ($count sēr.)';
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
    return 'Avots priekš $playerName';
  }

  @override
  String get noPluginsInstalled => 'Nav instalētu spraudņu';

  @override
  String get noPluginsMessage =>
      'Instalējiet paplašinājumus, lai pārlūkotu un straumētu saturu.';

  @override
  String get goToExtensions => 'Doties uz paplašinājumiem';

  @override
  String get availableSources => 'Pieejamie avoti';

  @override
  String get seasons => 'Sezonas';

  @override
  String get episodes => 'Sērijas';

  @override
  String get selectSourceToPlay => 'Izvēlieties avotu, lai skatītos.';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sērijas',
      one: '1 sērija',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'Sērijas nav atrastas';

  @override
  String get local => 'Lokāls';

  @override
  String get remote => 'Attāls';

  @override
  String get torrent => 'Torrents';

  @override
  String get unlock => 'Atbloķēt';

  @override
  String get lock => 'Bloķēt';

  @override
  String get sources => 'Avoti';

  @override
  String get tracks => 'Celiņi';

  @override
  String get content => 'Saturs';

  @override
  String get stats => 'Statistika';

  @override
  String get resize => 'Izmērs';

  @override
  String get next => 'Nākamais';

  @override
  String get previous => 'Previous';

  @override
  String get pip => 'PiP';

  @override
  String get rotate => 'Pagriezt';

  @override
  String get windowed => 'Logā';

  @override
  String get fullscreen => 'Pilnekrāna';

  @override
  String get movieDetails => 'Sīkāka informācija';

  @override
  String get showDetails => 'Skatīt detaļas';

  @override
  String get tagline => 'Slogans';

  @override
  String get status => 'Statuss';

  @override
  String get releaseDate => 'Izdošanas datums';

  @override
  String get firstAirDate => 'Pirmā raide';

  @override
  String get originalLanguage => 'Oriģinālvaloda';

  @override
  String get originCountry => 'Izcelsmes valsts';

  @override
  String get budgetLabel => 'Budžets';

  @override
  String get revenueLabel => 'Ienākumi';

  @override
  String get paused => 'Pauzēts';

  @override
  String get watched => 'Noskatīts';

  @override
  String get watching => 'Skatās';

  @override
  String get lastWatched => 'Pēdējo reizi';

  @override
  String get movie => 'Filma';

  @override
  String get tvShow => 'Seriāls';

  @override
  String get failedToLoadContent => 'Neizdevās ielādēt';

  @override
  String get director => 'Režisors';

  @override
  String get creator => 'Autors';

  @override
  String get showMore => 'Vairāk';

  @override
  String get showLess => 'Mazāk';

  @override
  String get viewAll => 'Skatīt visu';

  @override
  String seasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sezonas',
      one: '1 sezona',
    );
    return '$_temp0';
  }

  @override
  String get noInternetError => 'Nav interneta';

  @override
  String get timeoutError => 'Laika ierobežojums.';

  @override
  String get serverError => 'Servera kļūda.';

  @override
  String get contentNotFoundError => 'Nav atrasts.';

  @override
  String get accessDeniedError => 'Piekļuve liegta.';

  @override
  String get serviceUnavailableError => 'Pakalpojums nav pieejams.';

  @override
  String get generalError => 'Kļūda.';

  @override
  String get skip => 'Izlaist';

  @override
  String get skipIntro => 'Izlaist ievadu';

  @override
  String get skipOutro => 'Izlaist noslēgumu';

  @override
  String get skipRecap => 'Izlaist kopsavilkumu';

  @override
  String get goLive => 'Tiešraide';

  @override
  String get dismiss => 'Aizvērt';

  @override
  String get nextUp => 'Nākamais';

  @override
  String sourceAttempt(int index, int total) {
    return 'Mēģinājums $index no $total';
  }

  @override
  String get trying => 'Mēģina';

  @override
  String get failed => 'Neizdevās';

  @override
  String get selected => 'Izvēlēts';

  @override
  String get playing => 'Atskaņo';

  @override
  String get pending => 'Gaidāms';

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
  String get mobileQualityPreference => 'Mobilo datu kvalitātes preference';

  @override
  String get anyNoPreference => 'Jebkura (bez preferences)';

  @override
  String get subtitleAccounts => 'Subtitru konti';

  @override
  String get accounts => 'Konti';

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
  String get testConnection => 'Pārbaudīt savienojumu';

  @override
  String get connectedSuccessfully => 'Savienojums veiksmīgs';

  @override
  String get connectionFailed => 'Savienojums neizdevās';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get noAccountRegister => 'Don\'t have an account? Register here';

  @override
  String get apiKey => 'API atslēga';

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
      'Kvalitāte netiek garantēta. Avoti tiek kārtoti pēc šīs preferences, un straume ar vairākām kvalitātēm tiek atskaņota šajā vai tuvākajā zemākajā. Atskaņošana ir atkarīga no tā, ko nodrošinātājs patiešām piedāvā.';

  @override
  String get keepSourcesOriginalOrder => 'Keep sources in original order';

  @override
  String get openLink => 'Open link';

  @override
  String get diagnostics => 'Diagnostika';

  @override
  String get viewLogs => 'Skatīt žurnālus';

  @override
  String get viewLogsSubtitle => 'Skatīt lietotnes darbību un kļūdas';

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
  String get showRotate => 'Pagriešanas poga';

  @override
  String get showPlaybackSpeed => 'Playback speed button';

  @override
  String get showVolume => 'Volume button';

  @override
  String get showEpisodeNavigation => 'Previous / next episode buttons';

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
  String playerTorrentPeers(
    int connected,
    int total,
    String speed,
    String loaded,
  ) {
    return '$connected/$total peers · $speed · $loaded loaded';
  }

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
  String get playerWaitingForNetwork => 'Waiting for network…';

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
      'Changes show at once. While a video plays, Subtitle style in the player\'s Subtitles tab changes them too.';

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
  String get subtitleStyle => 'Subtitle style';

  @override
  String subtitleStyleSummary(int size, String color) {
    return '$size · $color';
  }

  @override
  String get subtitleBackgroundOpacity => 'Background opacity';

  @override
  String get subtitleOutline => 'Outline';

  @override
  String get subtitleOutlineNone => 'None';

  @override
  String get subtitleOutlineThin => 'Thin';

  @override
  String get subtitleOutlineNormal => 'Normal';

  @override
  String get subtitleOutlineThick => 'Thick';

  @override
  String get subtitlePosition => 'Position';

  @override
  String get subtitlePositionBottom => 'Bottom';

  @override
  String subtitlePositionRaised(int percent) {
    return '+$percent%';
  }

  @override
  String get subtitleBold => 'Bold';

  @override
  String get subtitleFont => 'Font';

  @override
  String get subtitleFontDefault => 'Default';

  @override
  String get subtitleFontSerif => 'Serif';

  @override
  String get subtitleFontMonospace => 'Monospace';

  @override
  String get subtitleTextOpacity => 'Text opacity';

  @override
  String subtitlePercent(int percent) {
    return '$percent%';
  }

  @override
  String get subtitleEncoding => 'Encoding';

  @override
  String get subtitleEncodingAuto => 'Auto';

  @override
  String get subtitleEncodingCentralEuropean => 'Central European';

  @override
  String get subtitleEncodingCyrillic => 'Cyrillic';

  @override
  String get subtitleEncodingWestern => 'Western';

  @override
  String get subtitleEncodingGreek => 'Greek';

  @override
  String get subtitleEncodingTurkish => 'Turkish';

  @override
  String get subtitleEncodingHebrew => 'Hebrew';

  @override
  String get subtitleEncodingArabic => 'Arabic';

  @override
  String get subtitleEncodingBaltic => 'Baltic';

  @override
  String get subtitleEncodingVietnamese => 'Vietnamese';

  @override
  String get subtitleNextTime => 'Next time the player opens';

  @override
  String get subtitleNextTimeNote =>
      'These change subtitle files at once, and subtitles inside the video the next time the player opens.';

  @override
  String get resetSubtitleStyle => 'Reset subtitle style';

  @override
  String get stepperDecrease => 'Decrease';

  @override
  String get stepperIncrease => 'Increase';

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
  String get sourcesSearching => 'Meklē skrāperos…';

  @override
  String get sourcesEmptyFiltered =>
      'Neviena saite neatbilst pašreizējiem filtriem.';

  @override
  String get sourcesEmptyNoTmdbId =>
      'Šim nosaukumam nav TMDB ID. Ievadiet to ar \'Search manually\'.';

  @override
  String get sourcesEmptyNoScrapers =>
      'Nav ieslēgtu skrāperu. Pievienojiet to sadaļā \'Nuvio Plugins\'.';

  @override
  String get sourcesEmptyAllFailed =>
      'Visi skrāperi neizdevās. Pārbaudiet savienojumu vai atjauniniet tos.';

  @override
  String sourcesEmptySomeFailed(int failed, int total) {
    return 'Saites nav atrastas. Neizdevās $failed no $total skrāperiem.';
  }

  @override
  String get sourcesEmptyNothingFound =>
      'Nevienam no jūsu skrāperiem nav šī nosaukuma.';

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
  String get audioLanguage => 'Audio language';

  @override
  String get audioLanguageAuto => 'Auto';

  @override
  String get audioLanguageAutoDetail =>
      'A video starts with the audio its source selects.';

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
  String get playerSourceCannotSeek => 'Can\'t seek';

  @override
  String get playerSourceNotVideo => 'Not a video';

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

  @override
  String get cloudStream => 'CloudStream';

  @override
  String get searchTagSkyStream => 'SkyStream';

  @override
  String get searchTagStremio => 'Stremio';

  @override
  String get searchTagNuvio => 'Nuvio';

  @override
  String get searchNuvioSeriesFailed => 'Couldn\'t load this series\' episodes';

  @override
  String get cloudStreamExtensions => 'CloudStream Extensions';

  @override
  String get cloudStreamExtensionsSubtitle =>
      'Install and manage CloudStream (.cs3) extensions';

  @override
  String get cloudStreamOn =>
      'Providers from installed extensions appear on Home, in search and in the provider list.';

  @override
  String get cloudStreamOff =>
      'Off: no CloudStream extension is loaded, and their providers are hidden everywhere. Nothing is uninstalled.';

  @override
  String get cloudStreamCheckUpdates => 'Check Updates';

  @override
  String cloudStreamCheckUpdatesCount(int count) {
    return 'Check Updates ($count)';
  }

  @override
  String get cloudStreamChecking => 'Checking…';

  @override
  String get cloudStreamAddRepositoryTitle => 'Add CloudStream Repository';

  @override
  String get cloudStreamAddRepositoryMessage =>
      'Paste a repository URL (repo.json), a plugin list URL (plugins.json) or a cloudstreamrepo:// link, or enter a shortcode such as megarepo.';

  @override
  String get cloudStreamAdd => 'Add';

  @override
  String cloudStreamRepositoryAdded(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $name · $count extensions',
      one: 'Added $name · 1 extension',
    );
    return '$_temp0';
  }

  @override
  String cloudStreamCouldNotAdd(String error) {
    return 'Could not add repository: $error';
  }

  @override
  String get cloudStreamUpToDate => 'Everything is up to date';

  @override
  String cloudStreamUpdatesAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count updates available',
      one: '1 update available',
    );
    return '$_temp0';
  }

  @override
  String cloudStreamCouldNotCheck(String names) {
    return 'Could not check $names';
  }

  @override
  String cloudStreamCouldNotCheckRepository(String name, String error) {
    return 'Could not check $name: $error';
  }

  @override
  String get cloudStreamRemove => 'Remove';

  @override
  String cloudStreamCouldNotRemove(String name, String error) {
    return 'Could not remove $name: $error';
  }

  @override
  String get cloudStreamNoRepositories => 'No repositories yet';

  @override
  String cloudStreamRepositorySummary(int count, int installed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count extensions',
      one: '1 extension',
    );
    return '$_temp0 · $installed installed';
  }

  @override
  String get cloudStreamLastCheckFailed => 'last check failed';

  @override
  String get cloudStreamRefreshRepository => 'Refresh Repository';

  @override
  String cloudStreamProviders(String names) {
    return 'Providers: $names';
  }

  @override
  String cloudStreamCouldNotLoad(String error) {
    return 'Could not load: $error';
  }

  @override
  String get cloudStreamUpdate => 'Update';

  @override
  String get cloudStreamUninstall => 'Uninstall';

  @override
  String cloudStreamInstalled(String name) {
    return 'Installed $name';
  }

  @override
  String cloudStreamUpdated(String name) {
    return 'Updated $name';
  }

  @override
  String cloudStreamUninstalled(String name) {
    return 'Removed $name';
  }

  @override
  String cloudStreamInstalledNotLoading(String name, String error) {
    return '$name is installed, but it does not load: $error';
  }

  @override
  String cloudStreamFailed(String error) {
    return 'Failed: $error';
  }

  @override
  String get cloudStreamStatusDown => 'down';

  @override
  String get cloudStreamStatusSlow => 'slow';

  @override
  String get cloudStreamStatusBeta => 'beta';

  @override
  String get clearanceVerify => 'Verify';

  @override
  String checksCheckingAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Checking $count sites automatically…',
      one: 'Checking 1 site automatically…',
    );
    return '$_temp0';
  }

  @override
  String checksNeedYou(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sites need you',
      one: '1 site needs you',
    );
    return '$_temp0';
  }

  @override
  String checksCleared(int count) {
    return '$count cleared';
  }

  @override
  String checksChecking(int count) {
    return '$count checking';
  }

  @override
  String checksFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count couldn\'t be checked',
      one: '1 couldn\'t be checked',
    );
    return '$_temp0';
  }

  @override
  String checksOpening(String site) {
    return 'Opening $site\'s check…';
  }

  @override
  String get checksVerifyAll => 'Verify all';

  @override
  String get checksShow => 'Show the sites';

  @override
  String get checksHide => 'Hide the sites';

  @override
  String checkStateChecking(int seconds) {
    return 'Checking automatically… $seconds s';
  }

  @override
  String get checkStateNeedsYou => 'Needs a quick check from you';

  @override
  String checkStateOpening(int seconds) {
    return 'Opening the check… $seconds s';
  }

  @override
  String get checkStateCleared => 'Cleared';

  @override
  String get checkStateSearchingAgain => 'Cleared · searching again…';

  @override
  String get checkStateUnreachable => 'Couldn\'t reach the site';

  @override
  String get checkStateBlocked => 'Blocked by the site; try without a VPN';

  @override
  String checkStateSentElsewhere(String host) {
    return 'Sends the browser to $host; the extension may need updating';
  }

  @override
  String get checkStateStillNotCleared => 'Still not cleared';

  @override
  String get checkStateOutdated =>
      'Update Android System WebView to clear this site\'s check';

  @override
  String get checkStateTooOld =>
      'This device\'s browser is too old for this site\'s check';

  @override
  String get checkStateIneffective =>
      'The check passed, but this site still refuses SkyStream. Trying again in a few minutes.';

  @override
  String get checkStateKeepsAsking =>
      'This site keeps asking. Try later, or without a VPN.';

  @override
  String get checkUpdateWebView => 'Update';

  @override
  String get checkAskAgain => 'Ask again';

  @override
  String get checkQuietNote => 'Won\'t open by itself';

  @override
  String checkMovedFrom(String site) {
    return 'moved from $site';
  }

  @override
  String get checkCloudStreamExtension => 'A CloudStream extension';

  @override
  String checkLineChecking(String site, int seconds) {
    return 'Checking $site automatically… $seconds s';
  }

  @override
  String checkLineNeedsYou(String site) {
    return '$site needs a quick check';
  }

  @override
  String get extensionSheetCantShow =>
      'This part can\'t be shown in SkyStream yet.';

  @override
  String get extensionSheetClose => 'Close';

  @override
  String get extensionSheetForceClose => 'Force close';

  @override
  String get extensionSheetMore => 'More';

  @override
  String extensionSheetError(String error) {
    return 'The extension didn\'t take that: $error';
  }

  @override
  String get extensionCopied => 'Copied';

  @override
  String get extensionOpenLink => 'Open link';

  @override
  String get cloudStreamSettings => 'Settings';

  @override
  String get cloudStreamSettingsApplying => 'Applying settings…';

  @override
  String cloudStreamSettingsApplied(String name) {
    return '$name\'s settings applied';
  }

  @override
  String cloudStreamSettingsFailed(String name, String error) {
    return 'Couldn\'t open $name\'s settings: $error';
  }

  @override
  String cloudStreamSettingsApplyFailed(String name, String error) {
    return '$name\'s settings are saved, but it didn\'t reload: $error';
  }

  @override
  String get cloudStreamSupport => 'Support';

  @override
  String cloudStreamSupportFailed(String name, String error) {
    return 'Couldn\'t open $name\'s messages: $error';
  }

  @override
  String cloudStreamSettingsStopped(String name, String error) {
    return '$name\'s settings stopped: $error';
  }

  @override
  String get swipeAgainToBoost => 'Swipe up again to go past 100%';

  @override
  String get showStatusOngoing => 'Turpinās';

  @override
  String get showStatusCompleted => 'Pabeigts';

  @override
  String get comingSoon => 'Drīzumā';

  @override
  String episodeAirsOn(String date) {
    return 'Pārraide $date';
  }

  @override
  String seasonNumberAndName(Object number, String name) {
    return '$number. sezona: $name';
  }

  @override
  String castLine(String names) {
    return 'Lomās: $names';
  }

  @override
  String get actorRoleMain => 'Galvenā';

  @override
  String get actorRoleSupporting => 'Otrā plāna';

  @override
  String get actorRoleBackground => 'Epizodiskā';

  @override
  String get playerQuality => 'Kvalitāte';

  @override
  String get playerQualityAuto => 'Automātiski';

  @override
  String playerQualityAutoPlaying(String height) {
    return 'Automātiski · $height';
  }

  @override
  String get networkBufferAuto => 'Automātiski (ieteicams)';

  @override
  String get networkBufferAutoHint =>
      'Izmērs katram video tiek noteikts pēc tā bitu pārraides ātruma un šīs ierīces atmiņas.';

  @override
  String get devQoeLog => 'QoE žurnāls';

  @override
  String get devQoeLogSubtitle =>
      'Ieraksta atskaņošanas laikus lietotnes žurnālā';

  @override
  String get playerGoLive => 'Uz tiešraidi';

  @override
  String playerBehindLive(String time) {
    return '$time aiz tiešraides';
  }

  @override
  String get profileSyncTitle => 'SkyStream sync';

  @override
  String profileSyncConnected(String username, String host) {
    return 'Connected as $username ($host)';
  }

  @override
  String get profileSyncSignedOut =>
      'Not signed in. Sync extensions, watch history, and episodes across your devices.';

  @override
  String get profileSyncServerUrl => 'Server URL';

  @override
  String get profileSyncSignIn => 'Sign in';

  @override
  String get profileSyncSyncNow => 'Sync now';

  @override
  String get profileSyncSyncing => 'Syncing…';

  @override
  String get profileSyncAuto => 'Auto-sync';

  @override
  String get profileSyncAutoSubtitle =>
      'Send watch progress and episode checkmarks automatically';

  @override
  String get profileSyncDisconnect => 'Disconnect';

  @override
  String get profileSyncDisconnectBody =>
      'Stop syncing this device? Watch history already saved stays on this device and on the server.';

  @override
  String get profileSyncSynced => 'Sync finished';

  @override
  String get profileSyncFailed => 'Sync failed';

  @override
  String profileSyncLastSynced(String time) {
    return 'Last sync $time';
  }
}
