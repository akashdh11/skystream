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
  String get bufferDepth => 'Βάθος προσωρινής μνήμης';

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
  String get selectBufferDepth => 'Επιλογή βάθους προσωρινής μνήμης';

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
  String get invalidNavigation => 'Μη έγκυρη πλοήγηση. Παρακαλώ επιστρέψτε.';

  @override
  String get startOver => 'Ξεκινήστε από την αρχή';

  @override
  String get goBack => 'Επιστροφή';

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
  String get wifiQualityPreference => 'Προτίμηση ποιότητας Wi-Fi';

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
      'Quality is not guaranteed. Sources are sorted by preference, but playback depends on what the provider actually offers.';

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
  String get showRotate => 'Rotate button';

  @override
  String get showPlaybackSpeed => 'Playback speed button';

  @override
  String get showEpisodes => 'Episodes button';
}
