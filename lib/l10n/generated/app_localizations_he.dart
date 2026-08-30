// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppLocalizationsHe extends AppLocalizations {
  AppLocalizationsHe([String locale = 'he']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => 'עברית';

  @override
  String get home => 'בית';

  @override
  String get search => 'חיפוש';

  @override
  String get explore => 'חקירה';

  @override
  String get exploreAnime => 'גילוי אנימה';

  @override
  String get exploreMovies => 'גילוי סרטים';

  @override
  String get library => 'ספרייה';

  @override
  String get settings => 'הגדרות';

  @override
  String get extensions => 'הרחבות';

  @override
  String get updateAvailable => 'עדכון זמין';

  @override
  String get retry => 'נסה שוב';

  @override
  String get factoryReset => 'איפוס יצרן';

  @override
  String get startupError => 'שגיאת הפעלה';

  @override
  String get general => 'כללי';

  @override
  String get appTheme => 'ערכת נושא';

  @override
  String get recordWatchHistory => 'תעד היסטוריית צפייה';

  @override
  String get defaultHomeScreen => 'מסך הבית המחדל';

  @override
  String get titlePosition => 'מיקום הכותרת';

  @override
  String get titlePositionBelowPoster => 'מתחת לפוסטר';

  @override
  String get titlePositionInsidePoster => 'בתוך הפוסטר';

  @override
  String get player => 'נגן';

  @override
  String get defaultPlayer => 'נגן ברירת מחדל';

  @override
  String get leftGesture => 'מחווה שמאלית';

  @override
  String get rightGesture => 'מחווה ימנית';

  @override
  String get doubleTapToSeek => 'הקשה כפולה לחיפוש';

  @override
  String get swipeToSeek => 'החלק לחיפוש';

  @override
  String get seekDuration => 'משך חיפוש';

  @override
  String get bufferDepth => 'עומק באפר';

  @override
  String get defaultResizeMode => 'מצב שינוי גודל ברירת מחדל';

  @override
  String get hardwareDecoding => 'פענוח חומרה';

  @override
  String get network => 'רשת';

  @override
  String get dnsOverHttps => 'DNS מעל HTTPS';

  @override
  String get dohProvider => 'ספק DoH';

  @override
  String get githubProxy => 'פרוקסי GitHub';

  @override
  String get githubProxySubtitle =>
      'ניתוב הורדות של הרחבות דרך jsDelivr כדי לעקוף חסימות של הספק.';

  @override
  String get manageExtensions => 'ניהול הרחבות';

  @override
  String get appData => 'נתוני אפליקציה';

  @override
  String get resetDataKeepExtensions => 'איפוס נתונים (שמור הרחבות)';

  @override
  String get developer => 'מפתח';

  @override
  String get developerOptions => 'אפשרויות מפתח';

  @override
  String get about => 'אודות';

  @override
  String get version => 'גרסה';

  @override
  String get enabled => 'מופעל';

  @override
  String get disabled => 'מושבת';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'הצטרפו לשרת שלנו';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'הצטרפו לערוץ שלנו';

  @override
  String developedBy(String name) {
    return 'Developed by $name';
  }

  @override
  String get system => 'מערכת';

  @override
  String get dark => 'כהה';

  @override
  String get light => 'בהיר';

  @override
  String get later => 'מאוחר יותר';

  @override
  String get updateNow => 'עדכן עכשיו';

  @override
  String get save => 'שמור';

  @override
  String get cancel => 'ביטול';

  @override
  String get close => 'סגור';

  @override
  String get delete => 'מחק';

  @override
  String get viewDetails => 'צפה בפרטים';

  @override
  String get clearAll => 'נקה הכל';

  @override
  String get clearAllHistory => 'נקה היסטוריה';

  @override
  String get all => 'הכל';

  @override
  String get none => 'ללא';

  @override
  String get confirmDownload => 'אשר הורדה';

  @override
  String get downloadNow => 'הורד עכשיו';

  @override
  String get selectSource => 'בחר מקור';

  @override
  String get downloadUnavailable => 'לא זמין';

  @override
  String get selectAnotherSource => 'בחר מקור אחר';

  @override
  String get watchHistoryCleared => 'היסטוריית צפייה נמחקה';

  @override
  String get downloadingUpdate => 'מוריד עדכון...';

  @override
  String errorPrefix(String message) {
    return 'שגיאה: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'עדכון זמין: $tag';
  }

  @override
  String get selectProviderToStart => 'בחר ספק כדי להתחיל';

  @override
  String get tapExtensionIcon => 'לחץ על סמל ההרחבה בפינה';

  @override
  String get continueWatching => 'המשך צפייה';

  @override
  String get noInternetConnection => 'אין חיבור לאינטרנט';

  @override
  String get siteNotReachable => 'האתר לא זמין';

  @override
  String get checkConnectionOrDownloads =>
      'בדוק את החיבור שלך או צפה בהורדות שלך.';

  @override
  String get tryVpnOrConnection => 'נסה להשתמש ב-VPN או בדוק את האינטרנט שלך.';

  @override
  String errorDetails(String error) {
    return 'פרטי שגיאה: $error';
  }

  @override
  String get goToDownloads => 'עבור להורדות';

  @override
  String get selectProvider => 'בחר ספק';

  @override
  String get searchHint => 'חפש סרטים, סדרות...';

  @override
  String get searchFavoriteContent => 'חפש את התוכן המועדף עליך';

  @override
  String get pressSearchOrEnter => 'לחץ על חיפוש או Enter להתחלה';

  @override
  String get noResultsFound => 'לא נמצאו תוצאות.';

  @override
  String get couldNotLoadTrending => 'לא ניתן לטעון מגמות';

  @override
  String get popularMovies => 'סרטים פופולריים';

  @override
  String get popularTVShows => 'סדרות פופולריות';

  @override
  String get newMovies => 'סרטים חדשים';

  @override
  String get newTVShows => 'סדרות חדשות';

  @override
  String get featuredMovies => 'סרטים מומלצים';

  @override
  String get featuredTVShows => 'סדרות מומלצות';

  @override
  String get lastVideosTVShows => 'פרקים אחרונים';

  @override
  String get downloads => 'הורדות';

  @override
  String get bookmarks => 'סימניות';

  @override
  String get noDownloadsYet => 'אין הורדות עדיין';

  @override
  String episodesCount(int count, int done) {
    return '$count פרקים • $done הושלמו';
  }

  @override
  String get deleteAllEpisodes => 'מחק את כל הפרקים';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return 'האם אתה בטוח שברצונך למחוק את כל $count הפרקים של \"$title\" ואת הקבצים שלהם?';
  }

  @override
  String get deleteAll => 'מחק הכל';

  @override
  String get completed => 'הושלם';

  @override
  String get statusQueued => 'בתור...';

  @override
  String get statusDownloading => 'מוריד...';

  @override
  String get statusFinished => 'הסתיים';

  @override
  String get statusFailed => 'נכשל';

  @override
  String get statusCanceled => 'בוטל';

  @override
  String get statusPaused => 'מושהה';

  @override
  String get statusWaiting => 'מחכה...';

  @override
  String get fileNotFoundRemoving => 'הקובץ לא נמצא. מוחק רשומה.';

  @override
  String get fileNotFound => 'הקובץ לא נמצא';

  @override
  String get deleteDownload => 'מחק הורדה';

  @override
  String get confirmDeleteDownload => 'האם אתה בטוח שברצונך למחוק הורדה זו?';

  @override
  String get libraryEmpty => 'הספרייה שלך ריקה';

  @override
  String get language => 'שפה';

  @override
  String get english => 'אנגלית';

  @override
  String get hindi => 'הינדי';

  @override
  String get kannada => 'קנאדה';

  @override
  String get unknown => 'לא ידוע';

  @override
  String get recommended => 'מומלץ';

  @override
  String get on => 'פעיל';

  @override
  String get off => 'כבוי';

  @override
  String get installRemoveProviders => 'התקן/הסר ספקים';

  @override
  String get resetDataSubtitle => 'נקה הגדרות ובסיס נתונים, שמור פלאגינים';

  @override
  String get factoryResetSubtitle => 'מחק את כל הנתונים, ההגדרות וההרחבות';

  @override
  String get developerOptionsSubtitle => 'כלי ניפוי שגיאות והפעלה מקומית';

  @override
  String get loading => 'טוען...';

  @override
  String get sec => 'שנ\'';

  @override
  String get min => 'דק\'';

  @override
  String get internalPlayer => 'נגן פנימי (VLC)';

  @override
  String get builtInPlayer => 'נגן מובנה';

  @override
  String get customNotSet => 'מותאם אישית (לא הוגדר)';

  @override
  String selectGesture(String side) {
    return 'בחר מחווה ($side)';
  }

  @override
  String get left => 'שמאלית';

  @override
  String get right => 'ימנית';

  @override
  String get selectSeekDuration => 'בחר משך חיפוש';

  @override
  String get selectBufferDepth => 'בחר עומק באפר';

  @override
  String get subtitleSettings => 'הגדרות כתוביות';

  @override
  String size(int size) {
    return 'גודל: $size';
  }

  @override
  String get background => 'רקע';

  @override
  String get customDohUrlLabel => 'כתובת DoH מותאמת אישית';

  @override
  String get enterCustomDohUrl => 'הזן כתובת DoH משלך';

  @override
  String get chooseTheme => 'בחר ערכת נושא';

  @override
  String get resetDataDialogTitle => 'לאפס נתונים?';

  @override
  String get resetDataDialogContent =>
      'זה ינקה הגדרות, מועדפים והיסטוריה. הרחבות מותקנות יישארו.';

  @override
  String get factoryResetDialogTitle => 'איפוס יצרן?';

  @override
  String get factoryResetDialogContent => 'זה ימחק הכל. לא ניתן לבטל פעולה זו.';

  @override
  String get selectLanguage => 'בחר שפה';

  @override
  String get synopsis => 'תקציר';

  @override
  String get noDescription => 'אין תיאור זמין.';

  @override
  String get videoAlreadyDownloadedPrompt =>
      'הווידאו הזה כבר הורד. מה ברצונך לעשות?';

  @override
  String get playNow => 'נגן עכשיו';

  @override
  String get upNext => 'הבא בתור';

  @override
  String get deleteDownloadPrompt => 'למחוק הורדה?';

  @override
  String get deleteDownloadConfirmation =>
      'האם אתה בטוח שברצונך למחוק קובץ זה? לא ניתן לבטל.';

  @override
  String get no => 'לא';

  @override
  String get yesDelete => 'כן, מחק';

  @override
  String get downloadPaused => 'הורדה הושהתה';

  @override
  String get downloading => 'מוריד';

  @override
  String get speed => 'מהירות';

  @override
  String get remaining => 'נותר';

  @override
  String get resume => 'המשך';

  @override
  String get pause => 'השהה';

  @override
  String get torrentContent => 'תוכן טורנט';

  @override
  String get audioTracks => 'רצועות שמע';

  @override
  String get noAudioTracks => 'לא נמצאו רצועות שמע';

  @override
  String get subtitles => 'כתוביות';

  @override
  String get options => 'אפשרויות';

  @override
  String get noSubtitlesFound => 'לא נמצאו כתוביות';

  @override
  String get playbackSpeed => 'מהירות הפעלה';

  @override
  String get subtitleOptions => 'אפשרויות כתוביות';

  @override
  String get hlsSubtitleWarning =>
      'כתוביות חיצוניות לא נתמכות ב-HLS בפלטפורמה זו.';

  @override
  String get loadFromDevice => 'טען מהמכשיר';

  @override
  String get syncDelay => 'סנכרון / השהיה';

  @override
  String get styleSettings => 'הגדרות סגנון';

  @override
  String get searchOnline => 'חפש אונליין';

  @override
  String get subtitleSync => 'סנכרון כתוביות';

  @override
  String get subtitleDelayWarning => 'השהיית כתוביות לא נתמכת בנגן הנוכחי.';

  @override
  String get resetDelay => 'אפס השהיה';

  @override
  String get subtitleStyles => 'סגנונות כתוביות';

  @override
  String get resetToDefault => 'חזור לברירת מחדל';

  @override
  String get fontSize => 'גודל גופן';

  @override
  String get verticalPosition => 'מיקום אנכי';

  @override
  String get textColor => 'צבע טקסט';

  @override
  String get backgroundColor => 'צבע רקע';

  @override
  String get backgroundOpacity => 'שקיפות רקע';

  @override
  String get subtitleSearch => 'חיפוש כתוביות';

  @override
  String get searchSubtitleNameHint => 'שם כתוביות...';

  @override
  String get enterSearchSubtitlePrompt => 'הזן שם לחיפוש כתוביות.';

  @override
  String get noSubtitleResults => 'לא נמצאו תוצאות.';

  @override
  String get downloadingApplyingSubtitle => 'מוריד ומחיל כתוביות...';

  @override
  String get failedToDownloadSubtitle => 'נכשלה הורדת כתוביות.';

  @override
  String get failedToLoadSubtitles => 'נכשלה טעינת כתוביות. נסה שוב.';

  @override
  String get noReposFound => 'לא נמצאו מאגרים או פלאגינים';

  @override
  String get downloadAllProviders => 'הורד הכל';

  @override
  String get removeRepository => 'הסר מאגר';

  @override
  String get addRepo => 'הוסף מאגר';

  @override
  String get extensionsNotInRepos => 'הרחבות לא מהמאגר';

  @override
  String get noLongerInRepo => 'לא רשום יותר במאגרים';

  @override
  String get addRepoToBrowse => 'הוסף מאגר כדי לצפות בפלאגינים';

  @override
  String get debugExtensions => 'ניפוי שגיאות הרחבות';

  @override
  String removeRepoConfirm(String repoName) {
    return 'להסיר את $repoName?';
  }

  @override
  String get removeRepoWarning => 'זה יסיר את המאגר ויסיר את כל הפלאגינים שלו.';

  @override
  String get addRepository => 'הוסף מאגר';

  @override
  String get repoUrlOrShortcode => 'כתובת מאגר או קוד קצר';

  @override
  String get assetPlugin => 'פלאגין מקומי';

  @override
  String get installed => 'מותקן';

  @override
  String get repositories => 'מאגרים';

  @override
  String get noExtensionsInstalled => 'לא מותקנות הרחבות';

  @override
  String get browseRepositoriesToInstall =>
      'פתחו את לשונית המאגרים כדי לגלות ולהתקין הרחבות.';

  @override
  String get browseRepositories => 'עיון במאגרים';

  @override
  String get addRepoDescription =>
      'הוסיפו כתובת URL של מאגר או קוד קצר כדי לגלות ולהתקין תוספי הרחבה.';

  @override
  String updateTo(String version) {
    return 'עדכן ל-$version';
  }

  @override
  String get install => 'התקן';

  @override
  String get error => 'שגיאה';

  @override
  String get ok => 'אישור';

  @override
  String pluginSettings(String pluginName) {
    return 'הגדרות $pluginName';
  }

  @override
  String get movies => 'סרטים';

  @override
  String get series => 'סדרות';

  @override
  String get anime => 'אנימה';

  @override
  String get liveStreams => 'שידורים חיים';

  @override
  String get debug => 'ניפוי שגיאות';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count הרחבות עודכנו',
      one: 'הרחבה אחת עודכנה',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => 'ניווט לא תקין.';

  @override
  String get startOver => 'התחל מחדש';

  @override
  String get goBack => 'חזור';

  @override
  String get resolving => 'מפענח קישורים...';

  @override
  String get downloaded => 'הורד';

  @override
  String get download => 'הורדה';

  @override
  String get debugOnlyFeature => 'תכונה זו זמינה רק בגרסאות פיתוח';

  @override
  String get streamUrl => 'כתובת הזרמה';

  @override
  String get play => 'נגן';

  @override
  String get verifyingSourceSize => 'מאמת מקור וגודל...';

  @override
  String get fileSaveLocationNotification => 'הקובץ יישמר בתיקיית ההורדות שלך.';

  @override
  String get resumingPlayback => 'מחדש הפעלה';

  @override
  String pausedAt(String time) {
    return 'הושהה ב-$time';
  }

  @override
  String resumesAutomatically(int count) {
    return 'יחודש אוטומטית בעוד $count שנ\'';
  }

  @override
  String get resumeNow => 'חדש עכשיו';

  @override
  String get playbackError => 'שגיאת הפעלה';

  @override
  String get confirmClearHistory => 'לנקות את כל ההיסטוריה?';

  @override
  String seasonWithNumber(Object number) {
    return 'עונה $number';
  }

  @override
  String get starting => 'מפעיל...';

  @override
  String percentWatched(int percent) {
    return '$percent% נצפו';
  }

  @override
  String get sub => 'תרגום';

  @override
  String get dub => 'דיבוב';

  @override
  String playEpisode(String label, Object season, Object episode) {
    return '$label ע$season פ$episode';
  }

  @override
  String playEpisodeOnly(String label, int episode) {
    return '$label E$episode';
  }

  @override
  String get debugTools => 'כלי ניפוי שגיאות';

  @override
  String get playLocalVideo => 'וידאו מקומי';

  @override
  String get playLocalVideoSubtitle => 'נגן קובץ מהמכשיר';

  @override
  String get streamUrlSubtitle => 'נגן מכתובת URL';

  @override
  String get streamTorrent => 'הזרם טורנט';

  @override
  String get streamTorrentSubtitle => 'בחר קובץ טורנט';

  @override
  String get loadPluginFromAssets => 'טען פלאגין מהנכסים';

  @override
  String get enterVideoUrlHint => 'הזן כתובת וידאו';

  @override
  String get networkStream => 'הזרמת רשת';

  @override
  String removedFromHistory(String title) {
    return 'הוסר מההיסטוריה: $title';
  }

  @override
  String get custom => 'מותאם אישית';

  @override
  String get refreshingLiveStream => 'מרענן שידור...';

  @override
  String get removeFromHistory => 'הסר מההיסטוריה';

  @override
  String get live => 'חי';

  @override
  String get volume => 'עוצמת שמע';

  @override
  String get brightness => 'בהירות';

  @override
  String get fit => 'התאמה';

  @override
  String get zoom => 'זום';

  @override
  String get stretch => 'מתיחה';

  @override
  String titleWithParam(String title) {
    return 'כותרת: $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'מקור: $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'גודל: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'שגיאה: $error. משתמש בנגן פנימי.';
  }

  @override
  String playerNotDetected(String playerName) {
    return '$playerName לא נמצא.';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return 'עונה $number ($count פרקים)';
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
    return 'מקור עבור $playerName';
  }

  @override
  String get noPluginsInstalled => 'אין פלאגינים מותקנים';

  @override
  String get noPluginsMessage => 'התקן הרחבות כדי לעיין ולהזרים תוכן.';

  @override
  String get goToExtensions => 'עבור להרחבות';

  @override
  String get availableSources => 'מקורות זמינים';

  @override
  String get seasons => 'עונות';

  @override
  String get episodes => 'פרקים';

  @override
  String get selectSourceToPlay => 'בחר מקור כדי להתחיל בצפייה.';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פרקים',
      one: 'פרק אחד',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'לא נמצאו פרקים';

  @override
  String get local => 'מקומי';

  @override
  String get remote => 'מרוחק';

  @override
  String get torrent => 'טורנט';

  @override
  String get unlock => 'שחרר נעילה';

  @override
  String get lock => 'נעל';

  @override
  String get sources => 'מקורות';

  @override
  String get tracks => 'רצועות';

  @override
  String get content => 'תוכן';

  @override
  String get stats => 'סטטיסטיקה';

  @override
  String get resize => 'גודל';

  @override
  String get next => 'הבא';

  @override
  String get pip => 'תמונה בתוך תמונה';

  @override
  String get rotate => 'סובב';

  @override
  String get windowed => 'חלון';

  @override
  String get fullscreen => 'מסך מלא';

  @override
  String get movieDetails => 'פרטי סרט';

  @override
  String get showDetails => 'צפה בפרטים';

  @override
  String get tagline => 'שורת מחץ';

  @override
  String get status => 'סטטוס';

  @override
  String get releaseDate => 'תאריך יציאה';

  @override
  String get firstAirDate => 'שידור ראשון';

  @override
  String get originalLanguage => 'שפה מקורית';

  @override
  String get originCountry => 'מדינת מקור';

  @override
  String get budgetLabel => 'תקציב';

  @override
  String get revenueLabel => 'הכנסות';

  @override
  String get paused => 'מושהה';

  @override
  String get watched => 'נצפה';

  @override
  String get watching => 'צופה';

  @override
  String get lastWatched => 'נצפה לאחרונה';

  @override
  String get movie => 'סרט';

  @override
  String get tvShow => 'סדרה';

  @override
  String get failedToLoadContent => 'נכשלה טעינת תוכן';

  @override
  String get director => 'במאי';

  @override
  String get creator => 'יוצר';

  @override
  String get showMore => 'עוד';

  @override
  String get showLess => 'פחות';

  @override
  String get viewAll => 'צפה בהכל';

  @override
  String seasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count עונות',
      one: 'עונה אחת',
    );
    return '$_temp0';
  }

  @override
  String get noInternetError => 'אין אינטרנט';

  @override
  String get timeoutError => 'זמן הבקשה פג.';

  @override
  String get serverError => 'שגיאת שרת.';

  @override
  String get contentNotFoundError => 'לא נמצא.';

  @override
  String get accessDeniedError => 'גישה נדחתה.';

  @override
  String get serviceUnavailableError => 'השירות לא זמין.';

  @override
  String get generalError => 'משהו השתבש.';

  @override
  String get skip => 'דלג';

  @override
  String get skipIntro => 'דלג על הפתיח';

  @override
  String get skipOutro => 'דלג על הסיום';

  @override
  String get skipRecap => 'דלג על התקציר';

  @override
  String get goLive => 'לשידור חי';

  @override
  String get dismiss => 'סגור';

  @override
  String get nextUp => 'הבא';

  @override
  String sourceAttempt(int index, int total) {
    return 'מקור $index מתוך $total';
  }

  @override
  String get trying => 'מנסה';

  @override
  String get failed => 'נכשל';

  @override
  String get selected => 'נבחר';

  @override
  String get playing => 'מנגן';

  @override
  String get pending => 'ממתין';

  @override
  String get openSubtitles => 'OpenSubtitles';

  @override
  String get subDl => 'SubDL';

  @override
  String get subSource => 'SubSource';

  @override
  String get wifiQualityPreference => 'העדפת איכות Wi-Fi';

  @override
  String get mobileQualityPreference => 'העדפת איכות נתונים ניידים';

  @override
  String get anyNoPreference => 'ללא העדפה';

  @override
  String get subtitleAccounts => 'חשבונות כתוביות';

  @override
  String get accounts => 'חשבונות';

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
  String get testConnection => 'בדיקת חיבור';

  @override
  String get connectedSuccessfully => 'מחובר בהצלחה';

  @override
  String get connectionFailed => 'החיבור נכשל';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get noAccountRegister => 'Don\'t have an account? Register here';

  @override
  String get apiKey => 'מפתח API';

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
  String get diagnostics => 'אבחון';

  @override
  String get viewLogs => 'הצגת יומנים';

  @override
  String get viewLogsSubtitle => 'הצגת פעילות האפליקציה ושגיאות';

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
