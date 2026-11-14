// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Modern Greek (`el`).
class AppLocalizationsEl extends AppLocalizations {
  AppLocalizationsEl([String locale = 'el']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => 'Ελληνικά';

  @override
  String get addonHealthChecking => 'Checking add-on…';

  @override
  String addonHealthWorking(int ms) {
    return 'Working · $ms ms';
  }

  @override
  String get addonHealthUnavailable => 'Unavailable';

  @override
  String get home => 'Αρχική';

  @override
  String get search => 'Αναζήτηση';

  @override
  String get explore => 'Εξερεύνηση';

  @override
  String get exploreAnime => 'Εξερεύνηση anime';

  @override
  String get exploreMovies => 'Εξερεύνηση ταινιών';

  @override
  String get library => 'Βιβλιοθήκη';

  @override
  String get settings => 'Ρυθμίσεις';

  @override
  String get extensions => 'Επεκτάσεις';

  @override
  String get updateAvailable => 'Διαθέσιμη ενημέρωση';

  @override
  String get retry => 'Δοκιμάστε ξανά';

  @override
  String get factoryReset => 'Επαναφορά εργοστασιακών ρυθμίσεων';

  @override
  String get startupError => 'Σφάλμα εκκίνησης';

  @override
  String get general => 'Γενικά';

  @override
  String get appTheme => 'Θέμα εφαρμογής';

  @override
  String get recordWatchHistory => 'Καταγραφή ιστορικού προβολών';

  @override
  String get fullScreenMode => 'Πλήρης οθόνη';

  @override
  String get fullScreenModeSubtitle => 'Μεταβαίνει στη διάταξη τηλεόρασης';

  @override
  String get defaultHomeScreen => 'Προεπιλεγμένη αρχική οθόνη';

  @override
  String get titlePosition => 'Θέση τίτλου';

  @override
  String get titlePositionBelowPoster => 'Κάτω από την αφίσα';

  @override
  String get titlePositionInsidePoster => 'Μέσα στην αφίσα';

  @override
  String get player => 'Πρόγραμμα αναπαραγωγής';

  @override
  String get defaultPlayer => 'Προεπιλεγμένο πρόγραμμα αναπαραγωγής';

  @override
  String get leftGesture => 'Αριστερή χειρονομία';

  @override
  String get rightGesture => 'Δεξιά χειρονομία';

  @override
  String get doubleTapToSeek => 'Διπλό πάτημα για αναζήτηση';

  @override
  String get swipeToSeek => 'Σύρετε για αναζήτηση';

  @override
  String get seekDuration => 'Διάρκεια αναζήτησης';

  @override
  String get defaultResizeMode => 'Προεπιλεγμένη λειτουργία μεγέθους';

  @override
  String get hardwareDecoding => 'Αποκωδικοποίηση υλικού';

  @override
  String get network => 'Δίκτυο';

  @override
  String get dnsOverHttps => 'DNS μέσω HTTPS';

  @override
  String get dohProvider => 'Πάροχος DoH';

  @override
  String get githubProxy => 'Διακομιστής μεσολάβησης GitHub';

  @override
  String get githubProxySubtitle =>
      'Δρομολόγηση των λήψεων επεκτάσεων μέσω jsDelivr για παράκαμψη αποκλεισμών του παρόχου.';

  @override
  String get manageExtensions => 'Διαχείριση επεκτάσεων';

  @override
  String get appData => 'Δεδομένα εφαρμογής';

  @override
  String get resetDataKeepExtensions =>
      'Επαναφορά δεδομένων (διατήρηση επεκτάσεων)';

  @override
  String get developer => 'Προγραμματιστής';

  @override
  String get developerOptions => 'Επιλογές προγραμματιστή';

  @override
  String get about => 'Σχετικά';

  @override
  String get version => 'Έκδοση';

  @override
  String get openSourceLicences => 'Open-source licences';

  @override
  String get openSourceLicencesSubtitle =>
      'SkyStream is free software under the GNU GPL v3';

  @override
  String get appLegalese =>
      'Copyright © 2025–2026 SkyStream contributors.\nSkyStream is free software: you can redistribute it and modify it under the terms of the GNU General Public License, version 3. It comes with ABSOLUTELY NO WARRANTY. Its source code is at github.com/akashdh11/skystream.';

  @override
  String get enabled => 'Ενεργοποιημένο';

  @override
  String get disabled => 'Απενεργοποιημένο';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'Μπείτε στον διακομιστή μας';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'Μπείτε στο κανάλι μας';

  @override
  String developedBy(String name) {
    return 'Developed by $name';
  }

  @override
  String get system => 'Σύστημα';

  @override
  String get dark => 'Σκούρο';

  @override
  String get light => 'Ανοιχτό';

  @override
  String get later => 'Αργότερα';

  @override
  String get updateNow => 'Ενημέρωση τώρα';

  @override
  String get save => 'Αποθήκευση';

  @override
  String get cancel => 'Ακύρωση';

  @override
  String get close => 'Κλείσιμο';

  @override
  String get delete => 'Διαγραφή';

  @override
  String get viewDetails => 'Προβολή λεπτομερειών';

  @override
  String get clearAll => 'Εκκαθάριση όλων';

  @override
  String get clearAllHistory => 'Εκκαθάριση ιστορικού προβολών';

  @override
  String get all => 'Όλα';

  @override
  String get none => 'Κανένα';

  @override
  String get confirmDownload => 'Επιβεβαίωση λήψης';

  @override
  String get downloadNow => 'Λήψη τώρα';

  @override
  String get selectSource => 'Επιλογή πηγής';

  @override
  String get downloadUnavailable => 'Η λήψη δεν είναι διαθέσιμη';

  @override
  String get selectAnotherSource => 'Επιλέξτε άλλη πηγή';

  @override
  String get watchHistoryCleared => 'Το ιστορικό προβολών εκκαθαρίστηκε';

  @override
  String get downloadingUpdate => 'Λήψη ενημέρωσης...';

  @override
  String errorPrefix(String message) {
    return 'Σφάλμα: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'Διαθέσιμη ενημέρωση: $tag';
  }

  @override
  String get selectProviderToStart => 'Επιλέξτε έναν πάροχο για να ξεκινήσετε';

  @override
  String get tapExtensionIcon => 'Πατήστε το εικονίδιο επέκτασης στη γωνία';

  @override
  String get continueWatching => 'Συνέχεια προβολής';

  @override
  String get noInternetConnection => 'Δεν υπάρχει σύνδεση στο διαδίκτυο';

  @override
  String get siteNotReachable => 'Ο ιστότοπος δεν είναι προσβάσιμος';

  @override
  String get checkConnectionOrDownloads =>
      'Ελέγξτε τη σύνδεσή σας ή δείτε τις λήψεις σας.';

  @override
  String get tryVpnOrConnection =>
      'Δοκιμάστε με VPN ή ελέγξτε τη σύνδεσή σας στο διαδίκτυο.';

  @override
  String errorDetails(String error) {
    return 'Λεπτομέρειες σφάλματος: $error';
  }

  @override
  String get goToDownloads => 'Μετάβαση στις λήψεις';

  @override
  String get selectProvider => 'Επιλογή παρόχου';

  @override
  String get searchHint => 'Αναζήτηση ταινιών, σειρών...';

  @override
  String get searchFavoriteContent => 'Αναζητήστε το αγαπημένο σας περιεχόμενο';

  @override
  String get pressSearchOrEnter =>
      'Πατήστε το πλήκτρο αναζήτησης ή Enter για να ξεκινήσετε';

  @override
  String get recentSearches => 'Recent searches';

  @override
  String removeFromSearchHistory(String query) {
    return 'Remove $query from search history';
  }

  @override
  String get noResultsFound => 'Δεν βρέθηκαν αποτελέσματα.';

  @override
  String get couldNotLoadTrending => 'Δεν ήταν δυνατή η φόρτωση των τάσεων';

  @override
  String get popularMovies => 'Δημοφιλείς ταινίες';

  @override
  String get popularTVShows => 'Δημοφιλείς σειρές';

  @override
  String get newMovies => 'Νέες ταινίες';

  @override
  String get newTVShows => 'Νέες σειρές';

  @override
  String get featuredMovies => 'Προτεινόμενες ταινίες';

  @override
  String get featuredTVShows => 'Προτεινόμενες σειρές';

  @override
  String get lastVideosTVShows => 'Τελευταία επεισόδια';

  @override
  String get downloads => 'Λήψεις';

  @override
  String get bookmarks => 'Σελιδοδείκτες';

  @override
  String get noDownloadsYet => 'Δεν υπάρχουν ακόμα λήψεις';

  @override
  String episodesCount(int count, int done) {
    return '$count επεισόδια • $done ολοκληρώθηκαν';
  }

  @override
  String get deleteAllEpisodes => 'Διαγραφή όλων των επεισοδίων';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return 'Είστε σίγουροι ότι θέλετε να διαγράψετε και τα $count επεισόδια του \"$title\" και τα αρχεία τους;';
  }

  @override
  String get deleteAll => 'Διαγραφή όλων';

  @override
  String get completed => 'Ολοκληρώθηκε';

  @override
  String get statusQueued => 'Σε ουρά...';

  @override
  String get statusDownloading => 'Λήψη...';

  @override
  String get statusFinished => 'Ολοκληρώθηκε';

  @override
  String get statusFailed => 'Αποτυχία';

  @override
  String get statusCanceled => 'Ακυρώθηκε';

  @override
  String get statusPaused => 'Σε παύση';

  @override
  String get statusWaiting => 'Αναμονή...';

  @override
  String get fileNotFoundRemoving =>
      'Το αρχείο δεν βρέθηκε στον δίσκο. Διαγραφή εγγραφής.';

  @override
  String get fileNotFound => 'Το αρχείο δεν βρέθηκε';

  @override
  String get deleteDownload => 'Διαγραφή λήψης';

  @override
  String get confirmDeleteDownload =>
      'Είστε σίγουροι ότι θέλετε να διαγράψετε αυτήν τη λήψη και το αρχείο της;';

  @override
  String get libraryEmpty => 'Η βιβλιοθήκη σας είναι άδεια';

  @override
  String get language => 'Γλώσσα';

  @override
  String get english => 'Αγγλικά';

  @override
  String get hindi => 'Χίντι';

  @override
  String get kannada => 'Κανάντα';

  @override
  String get unknown => 'Άγνωστο';

  @override
  String get recommended => 'Προτεινόμενο';

  @override
  String get on => 'Ενεργό';

  @override
  String get off => 'Ανενεργό';

  @override
  String get installRemoveProviders => 'Εγκατάσταση ή αφαίρεση παρόχων';

  @override
  String get resetDataSubtitle =>
      'Εκκαθάριση ρυθμίσεων και βάσης, διατήρηση πρόσθετων';

  @override
  String get factoryResetSubtitle =>
      'Διαγραφή όλων των δεδομένων, ρυθμίσεων και επεκτάσεων';

  @override
  String get developerOptionsSubtitle =>
      'Εργαλεία αποσφαλμάτωσης και τοπική αναπαραγωγή';

  @override
  String get loading => 'Φόρτωση...';

  @override
  String get sec => 'δευτ.';

  @override
  String get min => 'λεπτά';

  @override
  String playerRewindSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Πίσω $count δευτερόλεπτα',
      one: 'Πίσω 1 δευτερόλεπτο',
    );
    return '$_temp0';
  }

  @override
  String playerForwardSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Μπροστά $count δευτερόλεπτα',
      one: 'Μπροστά 1 δευτερόλεπτο',
    );
    return '$_temp0';
  }

  @override
  String get internalPlayer => 'Εσωτερικό (VLC)';

  @override
  String get builtInPlayer => 'Ενσωματωμένο πρόγραμμα αναπαραγωγής';

  @override
  String get customNotSet => 'Προσαρμοσμένο (μη ορισμένο)';

  @override
  String selectGesture(String side) {
    return 'Επιλογή $side χειρονομίας';
  }

  @override
  String get left => 'αριστερή';

  @override
  String get right => 'δεξιά';

  @override
  String get selectSeekDuration => 'Επιλογή διάρκειας αναζήτησης';

  @override
  String get subtitleSettings => 'Ρυθμίσεις υπότιτλων';

  @override
  String size(int size) {
    return 'Μέγεθος: $size';
  }

  @override
  String get background => 'Φόντο';

  @override
  String get customDohUrlLabel => 'Προσαρμοσμένο DoH URL';

  @override
  String get enterCustomDohUrl => 'Εισαγάγετε το δικό σας DoH URL';

  @override
  String get chooseTheme => 'Επιλογή θέματος';

  @override
  String get resetDataDialogTitle => 'Επαναφορά δεδομένων;';

  @override
  String get resetDataDialogContent =>
      'Αυτό θα εκκαθαρίσει Ρυθμίσεις, Αγαπημένα και Ιστορικό. Οι εγκατεστημένες επεκτάσεις ΔΕΝ θα διαγραφούν.';

  @override
  String get factoryResetDialogTitle => 'Εργοστασιακή επαναφορά;';

  @override
  String get factoryResetDialogContent =>
      'Αυτό θα διαγράψει τα ΠΑΝΤΑ. Αυτή η ενέργεια δεν μπορεί να αναιρεθεί.';

  @override
  String get selectLanguage => 'Επιλογή γλώσσας';

  @override
  String get synopsis => 'Σύνοψη';

  @override
  String get noDescription => 'Δεν υπάρχει διαθέσιμη περιγραφή.';

  @override
  String get videoAlreadyDownloadedPrompt =>
      'Αυτό το βίντεο έχει ήδη ληφθεί. Τι θέλετε να κάνετε;';

  @override
  String get playNow => 'Προβολή τώρα';

  @override
  String get upNext => 'Ακολουθεί';

  @override
  String get deleteDownloadPrompt => 'Διαγραφή λήψης;';

  @override
  String get deleteDownloadConfirmation =>
      'Είστε σίγουροι ότι θέλετε να διαγράψετε αυτό το αρχείο; Αυτή η ενέργεια δεν μπορεί να αναιρεθεί.';

  @override
  String get no => 'Όχι';

  @override
  String get yesDelete => 'Ναι, διαγραφή';

  @override
  String get downloadPaused => 'Η λήψη τέθηκε σε παύση';

  @override
  String get downloading => 'Λήψη';

  @override
  String get speed => 'Ταχύτητα';

  @override
  String get remaining => 'Απομένει';

  @override
  String get resume => 'Συνέχεια';

  @override
  String get pause => 'Παύση';

  @override
  String get torrentContent => 'Περιεχόμενο Torrent';

  @override
  String get audioTracks => 'Κομμάτια ήχου';

  @override
  String get noAudioTracks => 'Δεν βρέθηκαν κομμάτια ήχου';

  @override
  String get subtitles => 'Υπότιτλοι';

  @override
  String get options => 'Επιλογές';

  @override
  String get noSubtitlesFound => 'Δεν βρέθηκαν υπότιτλοι';

  @override
  String get playbackSpeed => 'Ταχύτητα αναπαραγωγής';

  @override
  String get subtitleOptions => 'Επιλογές υπότιτλων';

  @override
  String get hlsSubtitleWarning =>
      'Οι εξωτερικοί υπότιτλοι δεν υποστηρίζονται για HLS σε αυτήν την πλατφόρμα.';

  @override
  String get loadFromDevice => 'Φόρτωση από τη συσκευή';

  @override
  String get syncDelay => 'Συγχρονισμός / Καθυστέρηση';

  @override
  String get styleSettings => 'Ρυθμίσεις στυλ';

  @override
  String get searchOnline => 'Αναζήτηση στο διαδίκτυο (αναζήτηση υπότιτλων)';

  @override
  String get subtitleSync => 'Συγχρονισμός υπότιτλων';

  @override
  String get subtitleDelayWarning =>
      'Η καθυστέρηση υπότιτλων δεν υποστηρίζεται από το τρέχον πρόγραμμα αναπαραγωγής.';

  @override
  String get resetDelay => 'Επαναφορά καθυστέρησης';

  @override
  String get subtitleStyles => 'Στυλ υπότιτλων';

  @override
  String get resetToDefault => 'Επαναφορά στις προεπιλογές';

  @override
  String get fontSize => 'Μέγεθος γραμματοσειράς';

  @override
  String get verticalPosition => 'Κάθετη θέση';

  @override
  String get textColor => 'Χρώμα κειμένου';

  @override
  String get backgroundColor => 'Χρώμα φόντου';

  @override
  String get backgroundOpacity => 'Διαφάνεια φόντου';

  @override
  String get subtitleSearch => 'Αναζήτηση υπότιτλων';

  @override
  String get searchSubtitleNameHint => 'Όνομα υπότιτλου...';

  @override
  String get enterSearchSubtitlePrompt =>
      'Εισαγάγετε ένα όνομα για αναζήτηση υπότιτλων.';

  @override
  String get noSubtitleResults =>
      'Δεν βρέθηκαν αποτελέσματα. Δοκιμάστε άλλη αναζήτηση.';

  @override
  String get downloadingApplyingSubtitle => 'Λήψη και εφαρμογή υπότιτλου...';

  @override
  String get failedToDownloadSubtitle => 'Αποτυχία λήψης υπότιτλου.';

  @override
  String get failedToLoadSubtitles =>
      'Αποτυχία φόρτωσης υπότιτλων. Δοκιμάστε ξανά.';

  @override
  String get noReposFound => 'Δεν βρέθηκαν αποθετήρια ή πρόσθετα';

  @override
  String get downloadAllProviders => 'Λήψη όλων';

  @override
  String get removeRepository => 'Αφαίρεση αποθετηρίου';

  @override
  String get addRepo => 'Προσθήκη αποθετηρίου';

  @override
  String get extensionsNotInRepos => 'Επεκτάσεις εκτός αποθετηρίων';

  @override
  String get noLongerInRepo => 'Δεν περιλαμβάνεται πλέον σε κανένα αποθετήριο';

  @override
  String get addRepoToBrowse =>
      'Προσθέστε ένα αποθετήριο για περιήγηση σε πρόσθετα';

  @override
  String get debugExtensions => 'Αποσφαλμάτωση επεκτάσεων';

  @override
  String removeRepoConfirm(String repoName) {
    return 'Αφαίρεση του $repoName;';
  }

  @override
  String get removeRepoWarning =>
      'Αυτό θα αφαιρέσει το αποθετήριο και θα απεγκαταστήσει όλα τα πρόσθετά του.';

  @override
  String get addRepository => 'Προσθήκη αποθετηρίου';

  @override
  String get repoUrlOrShortcode => 'URL αποθετηρίου ή σύντομος κωδικός';

  @override
  String get assetPlugin => 'Πρόσθετο πόρων';

  @override
  String get installed => 'Εγκαταστάθηκε';

  @override
  String get repositories => 'Αποθετήρια';

  @override
  String get noExtensionsInstalled => 'Δεν έχουν εγκατασταθεί επεκτάσεις';

  @override
  String get browseRepositoriesToInstall =>
      'Ανοίξτε την καρτέλα «Αποθετήρια» για να βρείτε και να εγκαταστήσετε επεκτάσεις.';

  @override
  String get browseRepositories => 'Περιήγηση αποθετηρίων';

  @override
  String get addRepoDescription =>
      'Προσθέστε ένα URL αποθετηρίου ή έναν σύντομο κωδικό για να βρείτε και να εγκαταστήσετε πρόσθετα.';

  @override
  String updateTo(String version) {
    return 'Ενημέρωση σε $version';
  }

  @override
  String get install => 'Εγκατάσταση';

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
  String get error => 'Σφάλμα';

  @override
  String get ok => 'OK';

  @override
  String pluginSettings(String pluginName) {
    return 'Ρυθμίσεις $pluginName';
  }

  @override
  String get movies => 'Ταινίες';

  @override
  String get series => 'Σειρές';

  @override
  String get anime => 'Anime';

  @override
  String get liveStreams => 'Ζωντανές ροές';

  @override
  String get debug => 'Αποσφαλμάτωση';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count επεκτάσεις ενημερώθηκαν',
      one: '1 επέκταση ενημερώθηκε',
    );
    return '$_temp0';
  }

  @override
  String extensionsNewRepositories(int count, String source) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count νέα αποθετήρια στο $source',
      one: 'Νέο αποθετήριο στο $source',
    );
    return '$_temp0';
  }

  @override
  String extensionsNewPlugins(int count, String repository) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count νέα πρόσθετα στο $repository',
      one: 'Νέο πρόσθετο στο $repository',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => 'Μη έγκυρη πλοήγηση. Παρακαλώ επιστρέψτε.';

  @override
  String get startOver => 'Ξεκινήστε από την αρχή';

  @override
  String get goBack => 'Επιστροφή';

  @override
  String get restartApp => 'Επανεκκίνηση εφαρμογής';

  @override
  String get resolving => 'Επίλυση...';

  @override
  String get downloaded => 'Λήφθηκε';

  @override
  String get download => 'Λήψη';

  @override
  String get debugOnlyFeature =>
      'Αυτή η λειτουργία είναι διαθέσιμη μόνο σε δοκιμαστικές εκδόσεις (debug)';

  @override
  String get streamUrl => 'URL ροής';

  @override
  String get play => 'Αναπαραγωγή';

  @override
  String get verifyingSourceSize => 'Επαλήθευση πηγής και μεγέθους...';

  @override
  String get fileSaveLocationNotification =>
      'Το αρχείο θα αποθηκευτεί στον φάκελο λήψεων.';

  @override
  String get resumingPlayback => 'Συνέχιση αναπαραγωγής';

  @override
  String pausedAt(String time) {
    return 'Σε παύση στο $time';
  }

  @override
  String resumesAutomatically(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Αυτόματη συνέχιση σε $count δευτερόλεπτα',
      one: 'Αυτόματη συνέχιση σε 1 δευτερόλεπτο',
    );
    return '$_temp0';
  }

  @override
  String get resumeNow => 'Συνέχιση τώρα';

  @override
  String get playbackError => 'Σφάλμα αναπαραγωγής';

  @override
  String get confirmClearHistory =>
      'Είστε σίγουροι ότι θέλετε να διαγράψετε όλο το ιστορικό προβολών;';

  @override
  String seasonWithNumber(Object number) {
    return 'Κύκλος $number';
  }

  @override
  String get starting => 'Εκκίνηση...';

  @override
  String percentWatched(int percent) {
    return '$percent% ολοκληρώθηκε';
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
  String get debugTools => 'Εργαλεία αποσφαλμάτωσης';

  @override
  String get playLocalVideo => 'Αναπαραγωγή τοπικού αρχείου βίντεο';

  @override
  String get playLocalVideoSubtitle =>
      'Αναπαραγωγή οποιουδήποτε βίντεο από τη συσκευή';

  @override
  String get streamUrlSubtitle => 'Αναπαραγωγή από URL δικτύου';

  @override
  String get streamTorrent => 'Ροή Torrent';

  @override
  String get streamTorrentSubtitle =>
      'Επιλέξτε ένα τοπικό αρχείο torrent για αναπαραγωγή';

  @override
  String get loadPluginFromAssets => 'Φόρτωση πρόσθετου από πόρους';

  @override
  String get enterVideoUrlHint => 'Εισαγάγετε URL βίντεο (http, magnet κ.λπ.)';

  @override
  String get networkStream => 'Ροή δικτύου';

  @override
  String removedFromHistory(String title) {
    return 'Αφαιρέθηκε από το ιστορικό: $title';
  }

  @override
  String get custom => 'Προσαρμοσμένο';

  @override
  String get refreshingLiveStream => 'Ανανέωση ζωντανής ροής...';

  @override
  String get removeFromHistory => 'Αφαίρεση από το ιστορικό';

  @override
  String get live => 'ΖΩΝΤΑΝΑ';

  @override
  String get volume => 'Ένταση';

  @override
  String get decrease => 'Decrease';

  @override
  String get increase => 'Increase';

  @override
  String get brightness => 'Φωτεινότητα';

  @override
  String get fit => 'Προσαρμογή';

  @override
  String get zoom => 'Ζουμ';

  @override
  String get stretch => 'Επέκταση';

  @override
  String titleWithParam(String title) {
    return 'Τίτλος: $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'Πηγή: $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'Μέγεθος: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'Σφάλμα: $error. Χρήση εσωτερικού προγράμματος αναπαραγωγής.';
  }

  @override
  String externalPlayerCannotSendHeaders(String playerName, String headers) {
    return '$playerName cannot send $headers. Using internal player.';
  }

  @override
  String playerNotDetected(String playerName) {
    return 'Ο $playerName δεν εντοπίστηκε. Εκκίνηση εσωτερικού προγράμματος αναπαραγωγής.';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return 'Κύκλος $number ($count επεισόδια)';
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
    return 'Επιλογή πηγής για $playerName';
  }

  @override
  String get noPluginsInstalled => 'Δεν υπάρχουν εγκατεστημένα πρόσθετα';

  @override
  String get noPluginsMessage =>
      'Εγκαταστήστε επεκτάσεις για περιήγηση και ροή περιεχομένου.';

  @override
  String get goToExtensions => 'Μετάβαση στις επεκτάσεις';

  @override
  String get availableSources => 'Διαθέσιμες πηγές';

  @override
  String get seasons => 'Κύκλοι';

  @override
  String get episodes => 'Επεισόδια';

  @override
  String get selectSourceToPlay =>
      'Παρακαλώ επιλέξτε μια πηγή από τις \'Διαθέσιμες πηγές\' παραπάνω.';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count επεισόδια',
      one: '1 επεισόδιο',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'Δεν βρέθηκαν επεισόδια';

  @override
  String get local => 'Τοπικό';

  @override
  String get remote => 'Απομακρυσμένο';

  @override
  String get torrent => 'Torrent';

  @override
  String get unlock => 'Ξεκλείδωμα';

  @override
  String get lock => 'Κλείδωμα';

  @override
  String get sources => 'Πηγές';

  @override
  String get tracks => 'Κομμάτια';

  @override
  String get content => 'Περιεχόμενο';

  @override
  String get stats => 'Στατιστικά';

  @override
  String get resize => 'Μέγεθος';

  @override
  String get next => 'Επόμενο';

  @override
  String get previous => 'Previous';

  @override
  String get pip => 'PiP';

  @override
  String get rotate => 'Περιστροφή';

  @override
  String get windowed => 'Σε παράθυρο';

  @override
  String get fullscreen => 'Πλήρης οθόνη';

  @override
  String get movieDetails => 'Λεπτομέρειες ταινίας';

  @override
  String get showDetails => 'Προβολή λεπτομερειών';

  @override
  String get tagline => 'Tagline';

  @override
  String get status => 'Κατάσταση';

  @override
  String get releaseDate => 'Ημερομηνία κυκλοφορίας';

  @override
  String get firstAirDate => 'Ημερομηνία πρώτης προβολής';

  @override
  String get originalLanguage => 'Πρωτότυπη γλώσσα';

  @override
  String get originCountry => 'Χώρα προέλευσης';

  @override
  String get budgetLabel => 'Προϋπολογισμός';

  @override
  String get revenueLabel => 'Έσοδα';

  @override
  String get paused => 'Σε παύση';

  @override
  String get watched => 'Ολοκληρώθηκε';

  @override
  String get watching => 'Προβάλλεται';

  @override
  String get lastWatched => 'Τελευταία προβολή';

  @override
  String get movie => 'Ταινία';

  @override
  String get tvShow => 'Σειρά';

  @override
  String get failedToLoadContent => 'Αποτυχία φόρτωσης περιεχομένου';

  @override
  String get director => 'Σκηνοθέτης';

  @override
  String get creator => 'Δημιουργός';

  @override
  String get showMore => 'Περισσότερα';

  @override
  String get showLess => 'Λιγότερα';

  @override
  String get viewAll => 'Προβολή όλων';

  @override
  String seasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count κύκλοι',
      one: '1 κύκλος',
    );
    return '$_temp0';
  }

  @override
  String get noInternetError => 'Δεν υπάρχει σύνδεση στο διαδίκτυο';

  @override
  String get timeoutError => 'Η αίτηση έληξε. Παρακαλώ δοκιμάστε ξανά.';

  @override
  String get serverError =>
      'Σφάλμα διακομιστή. Παρακαλώ δοκιμάστε ξανά αργότερα.';

  @override
  String get contentNotFoundError => 'Το περιεχόμενο δεν βρέθηκε.';

  @override
  String get accessDeniedError =>
      'Η πρόσβαση απορρίφθηκε. Ελέγξτε τα διαπιστευτήριά σας.';

  @override
  String get serviceUnavailableError => 'Ο διακομιστής δεν είναι διαθέσιμος.';

  @override
  String get generalError => 'Κάποιο πρόβλημα προέκυψε.';

  @override
  String get skip => 'Παράλειψη';

  @override
  String get skipIntro => 'Παράλειψη εισαγωγής';

  @override
  String get skipOutro => 'Παράλειψη τελικών τίτλων';

  @override
  String get skipRecap => 'Παράλειψη ανακεφαλαίωσης';

  @override
  String get goLive => 'Ζωντανά';

  @override
  String get dismiss => 'Απόρριψη';

  @override
  String get nextUp => 'Επόμενο';

  @override
  String sourceAttempt(int index, int total) {
    return 'Πηγή $index από $total';
  }

  @override
  String get trying => 'Δοκιμή';

  @override
  String get failed => 'Αποτυχία';

  @override
  String get selected => 'Επιλεγμένο';

  @override
  String get playing => 'Αναπαραγωγή';

  @override
  String get pending => 'Σε εκκρεμότητα';

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
  String get mobileQualityPreference => 'Προτίμηση ποιότητας κινητής';

  @override
  String get anyNoPreference => 'Καμία προτίμηση';

  @override
  String get subtitleAccounts => 'Λογαριασμοί υποτίτλων';

  @override
  String get accounts => 'Λογαριασμοί';

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
  String get testConnection => 'Δοκιμή σύνδεσης';

  @override
  String get connectedSuccessfully => 'Επιτυχής σύνδεση';

  @override
  String get connectionFailed => 'Αποτυχία σύνδεσης';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get noAccountRegister => 'Don\'t have an account? Register here';

  @override
  String get apiKey => 'Κλειδί API';

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
      'Η ποιότητα δεν είναι εγγυημένη. Οι πηγές ταξινομούνται με βάση αυτή την προτίμηση, και μια ροή με πολλές ποιότητες παίζει σε αυτήν ή στην πλησιέστερη χαμηλότερη. Η αναπαραγωγή εξαρτάται από το τι προσφέρει πραγματικά ο πάροχος.';

  @override
  String get keepSourcesOriginalOrder => 'Keep sources in original order';

  @override
  String get openLink => 'Open link';

  @override
  String get diagnostics => 'Διαγνωστικά';

  @override
  String get viewLogs => 'Προβολή αρχείων καταγραφής';

  @override
  String get viewLogsSubtitle =>
      'Προβολή δραστηριότητας και σφαλμάτων εφαρμογής';

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
  String get showRotate => 'Κουμπί περιστροφής';

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
  String get sourcesSearching => 'Αναζήτηση στα scrapers…';

  @override
  String get sourcesEmptyFiltered =>
      'Κανένας σύνδεσμος δεν ταιριάζει με τα φίλτρα.';

  @override
  String get sourcesEmptyNoTmdbId =>
      'Δεν υπάρχει TMDB ID για αυτόν τον τίτλο. Δώστε το με \'Search manually\'.';

  @override
  String get sourcesEmptyNoScrapers =>
      'Κανένα ενεργό scraper. Προσθέστε ένα στο \'Nuvio Plugins\'.';

  @override
  String get sourcesEmptyAllFailed =>
      'Όλα τα scrapers απέτυχαν. Ελέγξτε τη σύνδεσή σας ή ενημερώστε τα.';

  @override
  String sourcesEmptySomeFailed(int failed, int total) {
    return 'Δεν βρέθηκαν σύνδεσμοι. Απέτυχαν $failed από $total scrapers.';
  }

  @override
  String get sourcesEmptyNothingFound =>
      'Κανένα από τα scrapers σας δεν έχει αυτόν τον τίτλο.';

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
  String get showStatusOngoing => 'Σε εξέλιξη';

  @override
  String get showStatusCompleted => 'Ολοκληρώθηκε';

  @override
  String get comingSoon => 'Έρχεται σύντομα';

  @override
  String episodeAirsOn(String date) {
    return 'Προβολή στις $date';
  }

  @override
  String seasonNumberAndName(Object number, String name) {
    return 'Σεζόν $number: $name';
  }

  @override
  String castLine(String names) {
    return 'Ηθοποιοί: $names';
  }

  @override
  String get actorRoleMain => 'Πρωταγωνιστικός';

  @override
  String get actorRoleSupporting => 'Δευτερεύων';

  @override
  String get actorRoleBackground => 'Κομπάρσος';

  @override
  String get playerQuality => 'Ποιότητα';

  @override
  String get playerQualityAuto => 'Αυτόματο';

  @override
  String playerQualityAutoPlaying(String height) {
    return 'Αυτόματο · $height';
  }

  @override
  String get networkBufferAuto => 'Αυτόματο (προτείνεται)';

  @override
  String get networkBufferAutoHint =>
      'Προσαρμόζεται σε κάθε βίντεο με βάση τον ρυθμό bit του και τη μνήμη αυτής της συσκευής.';

  @override
  String get devQoeLog => 'Αρχείο καταγραφής QoE';

  @override
  String get devQoeLogSubtitle =>
      'Γράφει τους χρόνους αναπαραγωγής στο αρχείο καταγραφής της εφαρμογής';

  @override
  String get playerGoLive => 'Μετάβαση στο ζωντανό';

  @override
  String playerBehindLive(String time) {
    return '$time πίσω από το ζωντανό';
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
