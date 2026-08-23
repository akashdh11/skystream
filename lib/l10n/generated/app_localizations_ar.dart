// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => 'العربية';

  @override
  String get home => 'الرئيسية';

  @override
  String get search => 'بحث';

  @override
  String get explore => 'استكشاف';

  @override
  String get exploreAnime => 'استكشاف الأنمي';

  @override
  String get exploreMovies => 'استكشاف الأفلام';

  @override
  String get library => 'المكتبة';

  @override
  String get settings => 'الإعدادات';

  @override
  String get extensions => 'الإضافات';

  @override
  String get updateAvailable => 'يتوفر تحديث';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get factoryReset => 'إعادة ضبط المصنع';

  @override
  String get startupError => 'خطأ في بدء التشغيل';

  @override
  String get general => 'عام';

  @override
  String get appTheme => 'مظهر التطبيق';

  @override
  String get recordWatchHistory => 'سجل المشاهدة';

  @override
  String get defaultHomeScreen => 'الشاشة الرئيسية الافتراضية';

  @override
  String get titlePosition => 'موضع العنوان';

  @override
  String get titlePositionBelowPoster => 'أسفل الملصق';

  @override
  String get titlePositionInsidePoster => 'داخل الملصق';

  @override
  String get player => 'المشغل';

  @override
  String get defaultPlayer => 'المشغل الافتراضي';

  @override
  String get leftGesture => 'إيماءة اليسار';

  @override
  String get rightGesture => 'إيماءة اليمين';

  @override
  String get doubleTapToSeek => 'النقر المزدوج للتقديم/التأخير';

  @override
  String get swipeToSeek => 'السحب للتقديم/التأخير';

  @override
  String get seekDuration => 'مدة القفز';

  @override
  String get bufferDepth => 'عمق التخزين المؤقت';

  @override
  String get defaultResizeMode => 'وضع تغيير الحجم الافتراضي';

  @override
  String get hardwareDecoding => 'فك ترميز العتاد';

  @override
  String get network => 'الشبكة';

  @override
  String get dnsOverHttps => 'DNS عبر HTTPS';

  @override
  String get dohProvider => 'مزود DoH';

  @override
  String get githubProxy => 'وكيل GitHub';

  @override
  String get githubProxySubtitle =>
      'توجيه تنزيلات الإضافات عبر jsDelivr لتجاوز حظر مزوّد الخدمة.';

  @override
  String get manageExtensions => 'إدارة الإضافات';

  @override
  String get appData => 'بيانات التطبيق';

  @override
  String get resetDataKeepExtensions =>
      'إعادة ضبط البيانات (مع الاحتفاظ بالإضافات)';

  @override
  String get developer => 'المطور';

  @override
  String get developerOptions => 'خيارات المطور';

  @override
  String get about => 'حول';

  @override
  String get version => 'الإصدار';

  @override
  String get enabled => 'مفعل';

  @override
  String get disabled => 'معطل';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'انضم إلى خادمنا';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'انضم إلى قناتنا';

  @override
  String developedBy(String name) {
    return 'تم التطوير بواسطة $name';
  }

  @override
  String get system => 'النظام';

  @override
  String get dark => 'داكن';

  @override
  String get light => 'فاتح';

  @override
  String get later => 'لاحقاً';

  @override
  String get updateNow => 'التحديث الآن';

  @override
  String get save => 'حفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get close => 'إغلاق';

  @override
  String get delete => 'حذف';

  @override
  String get viewDetails => 'عرض التفاصيل';

  @override
  String get clearAll => 'مسح الكل';

  @override
  String get clearAllHistory => 'مسح كل السجل';

  @override
  String get all => 'الكل';

  @override
  String get none => 'لا شيء';

  @override
  String get confirmDownload => 'تأكيد التنزيل';

  @override
  String get downloadNow => 'تنزيل الآن';

  @override
  String get selectSource => 'اختر المصدر';

  @override
  String get downloadUnavailable => 'التنزيل غير متاح';

  @override
  String get selectAnotherSource => 'اختر مصدراً آخر';

  @override
  String get watchHistoryCleared => 'تم مسح سجل المشاهدة';

  @override
  String get downloadingUpdate => 'جارٍ تنزيل التحديث...';

  @override
  String errorPrefix(String message) {
    return 'خطأ: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'التحديث متاح: $tag';
  }

  @override
  String get selectProviderToStart => 'اختر مزوداً لبدء المشاهدة';

  @override
  String get tapExtensionIcon => 'اضغط على أيقونة الإضافة في الزاوية';

  @override
  String get continueWatching => 'مواصلة المشاهدة';

  @override
  String get noInternetConnection => 'لا يوجد اتصال بالإنترنت';

  @override
  String get siteNotReachable => 'لا يمكن الوصول إلى الموقع';

  @override
  String get checkConnectionOrDownloads =>
      'تحقق من اتصالك أو شاهد المحتوى الذي قمت بتنزيله.';

  @override
  String get tryVpnOrConnection =>
      'يرجى محاولة الوصول إلى الموقع باستخدام VPN أو التحقق من اتصالك بالإنترنت.';

  @override
  String errorDetails(String error) {
    return 'تفاصيل الخطأ: $error';
  }

  @override
  String get goToDownloads => 'الانتقال إلى التنزيلات';

  @override
  String get selectProvider => 'اختر المزود';

  @override
  String get searchHint => 'ابحث عن أفلام وسلاسل...';

  @override
  String get searchFavoriteContent => 'ابحث عن محتواك المفضل';

  @override
  String get pressSearchOrEnter => 'اضغط على مفتاح البحث أو Enter للبدء';

  @override
  String get noResultsFound => 'لم يتم العثور على نتائج.';

  @override
  String get couldNotLoadTrending => 'تعذر تحميل العناصر الشائعة';

  @override
  String get popularMovies => 'أفلام شعبية';

  @override
  String get popularTVShows => 'مسلسلات تلفزيونية شعبية';

  @override
  String get newMovies => 'أفلام جديدة';

  @override
  String get newTVShows => 'مسلسلات تلفزيونية جديدة';

  @override
  String get featuredMovies => 'أفلام مختارة';

  @override
  String get featuredTVShows => 'مسلسلات تلفزيونية مختارة';

  @override
  String get lastVideosTVShows => 'آخر المسلسلات التلفزيونية';

  @override
  String get downloads => 'التنزيلات';

  @override
  String get bookmarks => 'الإشارات المرجعية';

  @override
  String get noDownloadsYet => 'لا توجد تنزيلات بعد';

  @override
  String episodesCount(int count, int done) {
    return '$count حلقة • $done اكتملت';
  }

  @override
  String get deleteAllEpisodes => 'حذف جميع الحلقات';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return 'هل أنت متأكد أنك تريد حذف جميع الحلقات الـ $count من \"$title\" وملفاتها؟';
  }

  @override
  String get deleteAll => 'حذف الكل';

  @override
  String get completed => 'مكتمل';

  @override
  String get statusQueued => 'في الانتظار...';

  @override
  String get statusDownloading => 'جارٍ التنزيل...';

  @override
  String get statusFinished => 'انتهى';

  @override
  String get statusFailed => 'فشل';

  @override
  String get statusCanceled => 'ملغى';

  @override
  String get statusPaused => 'متوقف مؤقتاً';

  @override
  String get statusWaiting => 'انتظار...';

  @override
  String get fileNotFoundRemoving =>
      'الملف غير موجود على القرص. جارٍ إزالة السجل.';

  @override
  String get fileNotFound => 'الملف غير موجود';

  @override
  String get deleteDownload => 'حذف التنزيل';

  @override
  String get confirmDeleteDownload =>
      'هل أنت متأكد أنك تريد حذف هذا التنزيل وملفه؟';

  @override
  String get libraryEmpty => 'مكتبتك فارغة';

  @override
  String get language => 'اللغة';

  @override
  String get english => 'الإنجليزية';

  @override
  String get hindi => 'الهندية';

  @override
  String get kannada => 'الكانادية';

  @override
  String get unknown => 'غير معروف';

  @override
  String get recommended => 'موصى به';

  @override
  String get on => 'تشغيل';

  @override
  String get off => 'إيقاف';

  @override
  String get installRemoveProviders => 'تثبيت أو إزالة المزودين';

  @override
  String get resetDataSubtitle =>
      'مسح الإعدادات وقاعدة البيانات، والحفاظ على الإضافات';

  @override
  String get factoryResetSubtitle => 'حذف جميع البيانات والإعدادات والإضافات';

  @override
  String get developerOptionsSubtitle => 'أدوات التصحيح والتشغيل المحلي';

  @override
  String get loading => 'جارٍ التحميل...';

  @override
  String get sec => 'ثانية';

  @override
  String get min => 'دقيقة';

  @override
  String get internalPlayer => 'مشغل داخلي (media_kit)';

  @override
  String get builtInPlayer => 'المشغل المدمج';

  @override
  String get customNotSet => 'مخصص (غير محدد)';

  @override
  String selectGesture(String side) {
    return 'اختر إيماءة $side';
  }

  @override
  String get left => 'اليسار';

  @override
  String get right => 'اليمين';

  @override
  String get selectSeekDuration => 'اختر مدة القفز';

  @override
  String get selectBufferDepth => 'اختر عمق التخزين المؤقت';

  @override
  String get subtitleSettings => 'إعدادات الترجمة';

  @override
  String size(int size) {
    return 'الحجم: $size';
  }

  @override
  String get background => 'الخلفية';

  @override
  String get customDohUrlLabel => 'رابط DoH مخصص';

  @override
  String get enterCustomDohUrl => 'أدخل رابط DoH الخاص بك';

  @override
  String get chooseTheme => 'اختر المظهر';

  @override
  String get resetDataDialogTitle => 'إعادة ضبط البيانات؟';

  @override
  String get resetDataDialogContent =>
      'سيؤدي هذا إلى مسح الإعدادات والمفضلات والسجل. لن يتم حذف إضافاتك المثبتة.';

  @override
  String get factoryResetDialogTitle => 'إعادة ضبط المصنع؟';

  @override
  String get factoryResetDialogContent =>
      'سيؤدي هذا إلى حذف كل شيء: المفضلات والسجل والإعدادات وجميع الإضافات. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get selectLanguage => 'اختر اللغة';

  @override
  String get synopsis => 'ملخص';

  @override
  String get noDescription => 'لا يوجد وصف متاح.';

  @override
  String get videoAlreadyDownloadedPrompt =>
      'هذا الفيديو تم تنزيله بالفعل. ماذا تريد أن تفعل؟';

  @override
  String get playNow => 'تشغيل الآن';

  @override
  String get upNext => 'التالي';

  @override
  String get deleteDownloadPrompt => 'حذف التنزيل؟';

  @override
  String get deleteDownloadConfirmation =>
      'هل أنت متأكد أنك تريد حذف هذا الملف؟ لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get no => 'لا';

  @override
  String get yesDelete => 'نعم، حذف';

  @override
  String get downloadPaused => 'التنزيل متوقف مؤقتاً';

  @override
  String get downloading => 'جارٍ التنزيل';

  @override
  String get speed => 'السرعة';

  @override
  String get remaining => 'المتبقي';

  @override
  String get resume => 'استئناف';

  @override
  String get pause => 'إيقاف مؤقت';

  @override
  String get torrentContent => 'محتوى تورنت';

  @override
  String get audioTracks => 'المسارات الصوتية';

  @override
  String get noAudioTracks => 'لم يتم العثور على مسارات صوتية';

  @override
  String get subtitles => 'الترجمات';

  @override
  String get options => 'خيارات';

  @override
  String get noSubtitlesFound => 'لم يتم العثور على مسارات ترجمة';

  @override
  String get playbackSpeed => 'سرعة التشغيل';

  @override
  String get subtitleOptions => 'خيارات الترجمة';

  @override
  String get hlsSubtitleWarning =>
      'ملفات الترجمة الخارجية غير مدعومة على مشغل HLS النشط على هذه المنصة.';

  @override
  String get loadFromDevice => 'تحميل من الجهاز';

  @override
  String get syncDelay => 'المزامنة / التأخير';

  @override
  String get styleSettings => 'إعدادات النمط';

  @override
  String get searchOnline => 'بحث عبر الإنترنت (بحث عن الترجمة)';

  @override
  String get subtitleSync => 'مزامنة الترجمة';

  @override
  String get subtitleDelayWarning =>
      'تأخير الترجمة غير مدعوم من قبل محرك التشغيل النشط.';

  @override
  String get resetDelay => 'إعادة ضبط التأخير';

  @override
  String get subtitleStyles => 'أنماط الترجمة';

  @override
  String get mediaKitStylingWarning =>
      'تنسيق الترجمة متاح فقط على مشغل media_kit حالياً.';

  @override
  String get resetToDefault => 'إعادة الضبط للافتراضي';

  @override
  String get fontSize => 'حجم الخط';

  @override
  String get verticalPosition => 'الموضع العمودي';

  @override
  String get textColor => 'لون النص';

  @override
  String get backgroundColor => 'لون الخلفية';

  @override
  String get backgroundOpacity => 'شفافية الخلفية';

  @override
  String get subtitleSearch => 'البحث عن الترجمة';

  @override
  String get searchSubtitleNameHint => 'ابحث عن اسم الترجمة...';

  @override
  String get enterSearchSubtitlePrompt =>
      'أدخل اسماً أو ابحث للعثور على الترجمة.';

  @override
  String get noSubtitleResults => 'لم يتم العثور على نتائج. جرب استعلاماً آخر.';

  @override
  String get downloadingApplyingSubtitle => 'جارٍ تنزيل وتطبيق الترجمة...';

  @override
  String get failedToDownloadSubtitle => 'فشل تنزيل الترجمة.';

  @override
  String get failedToLoadSubtitles =>
      'فشل تحميل الترجمة. يرجى المحاولة مرة أخرى.';

  @override
  String get noReposFound => 'لم يتم العثور على مستودعات أو إضافات';

  @override
  String get downloadAllProviders => 'تنزيل الكل';

  @override
  String get removeRepository => 'إزالة المستودع';

  @override
  String get addRepo => 'إضافة مستودع';

  @override
  String get extensionsNotInRepos => 'إضافات ليست في المستودعات';

  @override
  String get noLongerInRepo => 'لم يعد مدرجاً في أي مستودع';

  @override
  String get addRepoToBrowse => 'أضف مستودعاً لتصفح وتحديث الإضافات';

  @override
  String get debugExtensions => 'تصحيح الإضافات';

  @override
  String removeRepoConfirm(String repoName) {
    return 'إزالة $repoName؟';
  }

  @override
  String get removeRepoWarning =>
      'سيؤدي هذا إلى إزالة المستودع وإلغاء تثبيت جميع إضافاته.';

  @override
  String get addRepository => 'إضافة مستودع';

  @override
  String get repoUrlOrShortcode => 'رابط المستودع أو الرمز المختصر';

  @override
  String get assetPlugin => 'إضافة أصل';

  @override
  String get installed => 'مثبت';

  @override
  String get repositories => 'المستودعات';

  @override
  String get noExtensionsInstalled => 'لا توجد إضافات مثبتة';

  @override
  String get browseRepositoriesToInstall =>
      'تصفّح تبويب المستودعات لاكتشاف الإضافات وتثبيتها.';

  @override
  String get browseRepositories => 'تصفّح المستودعات';

  @override
  String get addRepoDescription =>
      'أضف رابط مستودع أو رمزًا مختصرًا لاكتشاف إضافات البرنامج وتثبيتها.';

  @override
  String updateTo(String version) {
    return 'التحديث إلى $version';
  }

  @override
  String get install => 'تثبيت';

  @override
  String get error => 'خطأ';

  @override
  String get ok => 'موافق';

  @override
  String pluginSettings(String pluginName) {
    return 'إعدادات $pluginName';
  }

  @override
  String get movies => 'الأفلام';

  @override
  String get series => 'المسلسلات';

  @override
  String get anime => 'الأنمي';

  @override
  String get liveStreams => 'البث المباشر';

  @override
  String get debug => 'تصحيح';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم تحديث $count إضافات',
      one: 'تم تحديث إضافة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => 'انتقال غير صالح. يرجى العودة.';

  @override
  String get startOver => 'البدء من جديد';

  @override
  String get goBack => 'العودة';

  @override
  String get resolving => 'جارٍ الحل...';

  @override
  String get downloaded => 'تم التنزيل';

  @override
  String get download => 'تنزيل';

  @override
  String get debugOnlyFeature => 'هذه الميزة متاحة فقط في إصدارات التصحيح';

  @override
  String get streamUrl => 'رابط البث';

  @override
  String get play => 'تشغيل';

  @override
  String get verifyingSourceSize => 'جارٍ التحقق من المصدر والحجم...';

  @override
  String get fileSaveLocationNotification =>
      'سيتم حفظ الملف في مجلد التنزيلات الخاص بك.';

  @override
  String get resumingPlayback => 'استئناف التشغيل';

  @override
  String pausedAt(String time) {
    return 'توقف عند $time';
  }

  @override
  String resumesAutomatically(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يستأنف تلقائياً خلال $count ثوانٍ',
      one: 'يستأنف تلقائياً خلال ثانية واحدة',
    );
    return '$_temp0';
  }

  @override
  String get resumeNow => 'استئناف الآن';

  @override
  String get playbackError => 'خطأ في التشغيل';

  @override
  String get confirmClearHistory =>
      'هل أنت متأكد أنك تريد إزالة جميع العناصر من سجل المشاهدة؟';

  @override
  String seasonWithNumber(Object number) {
    return 'الموسم $number';
  }

  @override
  String get starting => 'جارٍ البدء...';

  @override
  String percentWatched(int percent) {
    return '$percent% تمت مشاهدته';
  }

  @override
  String get sub => 'ترجمة';

  @override
  String get dub => 'دبلجة';

  @override
  String playEpisode(String label, Object season, Object episode) {
    return '$label م$season ح$episode';
  }

  @override
  String playEpisodeOnly(String label, int episode) {
    return '$label E$episode';
  }

  @override
  String get debugTools => 'أدوات التصحيح';

  @override
  String get playLocalVideo => 'تشغيل فيديو محلي';

  @override
  String get playLocalVideoSubtitle => 'تشغيل أي فيديو من الجهاز';

  @override
  String get streamUrlSubtitle => 'التشغيل من رابط شبكة';

  @override
  String get streamTorrent => 'بث تورنت';

  @override
  String get streamTorrentSubtitle => 'اختر ملف تورنت محلي للتشغيل';

  @override
  String get loadPluginFromAssets => 'تحميل الإضافة من الأصول';

  @override
  String get enterVideoUrlHint => 'أدخل رابط الفيديو (http, magnet, etc.)';

  @override
  String get networkStream => 'بث الشبكة';

  @override
  String removedFromHistory(String title) {
    return 'تمت إزالة $title من السجل';
  }

  @override
  String get custom => 'مخصص';

  @override
  String get refreshingLiveStream => 'جارٍ تحديث البث المباشر...';

  @override
  String get removeFromHistory => 'إزالة من السجل';

  @override
  String get live => 'مباشر';

  @override
  String get volume => 'الصوت';

  @override
  String get brightness => 'السطوع';

  @override
  String get fit => 'ملاءمة';

  @override
  String get zoom => 'تغيير الحجم والتركيز';

  @override
  String get stretch => 'تمطيط';

  @override
  String titleWithParam(String title) {
    return 'العنوان: $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'المصدر: $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'الحجم: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'خطأ: $error. يتم استخدام المشغل الداخلي.';
  }

  @override
  String playerNotDetected(String playerName) {
    return 'لم يتم اكتشاف $playerName. جارٍ بدء المشغل الداخلي.';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return 'الموسم $number ($count حلقة)';
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
    return 'اختر المصدر لـ $playerName';
  }

  @override
  String get noPluginsInstalled => 'لا توجد إضافات مثبتة';

  @override
  String get noPluginsMessage => 'قم بتثبيت الإضافات لتصفح وبث المحتوى.';

  @override
  String get goToExtensions => 'الذهاب إلى الإضافات';

  @override
  String get availableSources => 'المصادر المتاحة';

  @override
  String get seasons => 'المواسم';

  @override
  String get episodes => 'الحلقات';

  @override
  String get selectSourceToPlay =>
      'يرجى اختيار مصدر من \'المصادر المتاحة\' أعلاه للتشغيل.';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حلقات',
      one: 'حلقة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'لم يتم العثور على حلقات';

  @override
  String get local => 'محلي';

  @override
  String get remote => 'عن بعد';

  @override
  String get torrent => 'تورنت';

  @override
  String get unlock => 'فتح القفل';

  @override
  String get lock => 'قفل';

  @override
  String get sources => 'المصادر';

  @override
  String get tracks => 'المسارات';

  @override
  String get content => 'المحتوى';

  @override
  String get stats => 'الإحصائيات';

  @override
  String get resize => 'تغيير الحجم';

  @override
  String get next => 'التالي';

  @override
  String get pip => 'صورة داخل صورة';

  @override
  String get rotate => 'تدوير';

  @override
  String get windowed => 'نوافذ';

  @override
  String get fullscreen => 'ملء الشاشة';

  @override
  String get movieDetails => 'تفاصيل الفيلم';

  @override
  String get showDetails => 'عرض التفاصيل';

  @override
  String get tagline => 'شعار';

  @override
  String get status => 'الحالة';

  @override
  String get releaseDate => 'تاريخ الإصدار';

  @override
  String get firstAirDate => 'تاريخ أول عرض';

  @override
  String get originalLanguage => 'اللغة الأصلية';

  @override
  String get originCountry => 'بلد المنشأ';

  @override
  String get budgetLabel => 'الميزانية';

  @override
  String get revenueLabel => 'الإيرادات';

  @override
  String get paused => 'متوقف';

  @override
  String get watched => 'تمت مشاهدته';

  @override
  String get watching => 'مشاهدة الآن';

  @override
  String get lastWatched => 'آخر مشاهدة';

  @override
  String get movie => 'فيلم';

  @override
  String get tvShow => 'مسلسل تلفزيوني';

  @override
  String get failedToLoadContent => 'فشل تحميل المحتوى';

  @override
  String get director => 'المخرج';

  @override
  String get creator => 'المبتكر';

  @override
  String get showMore => 'عرض المزيد';

  @override
  String get showLess => 'عرض أقل';

  @override
  String get viewAll => 'عرض الكل';

  @override
  String seasonsCount(int count) {
    return '$count مواسم';
  }

  @override
  String get noInternetError => 'لا يوجد اتصال بالإنترنت';

  @override
  String get timeoutError => 'انتهت مهلة الطلب. يرجى المحاولة مرة أخرى.';

  @override
  String get serverError => 'خطأ في الخادم. يرجى المحاولة مرة أخرى لاحقاً.';

  @override
  String get contentNotFoundError => 'المحتوى غير موجود.';

  @override
  String get accessDeniedError =>
      'تم رفض الوصول. تحقق من بيانات الاعتماد الخاصة بك.';

  @override
  String get serviceUnavailableError =>
      'الخادم غير متاح. حاول مرة أخرى لاحقاً.';

  @override
  String get generalError => 'حدث خطأ ما. يرجى المحاولة مرة أخرى.';

  @override
  String get skip => 'تخطي';

  @override
  String get skipIntro => 'تخطي المقدمة';

  @override
  String get skipOutro => 'تخطي النهاية';

  @override
  String get skipRecap => 'تخطي الملخص';

  @override
  String get goLive => 'البث المباشر';

  @override
  String get dismiss => 'إغلاق';

  @override
  String get nextUp => 'التالي';

  @override
  String sourceAttempt(int index, int total) {
    return 'المصدر $index من $total';
  }

  @override
  String get trying => 'محاولة';

  @override
  String get failed => 'فشل';

  @override
  String get selected => 'مختار';

  @override
  String get playing => 'تشغيل';

  @override
  String get pending => 'قيد الانتظار';

  @override
  String get openSubtitles => 'OpenSubtitles';

  @override
  String get subDl => 'SubDL';

  @override
  String get subSource => 'SubSource';

  @override
  String get wifiQualityPreference => 'تفضيل جودة الواي فاي';

  @override
  String get mobileQualityPreference => 'تفضيل جودة الهاتف المحمول';

  @override
  String get anyNoPreference => 'أي نوع (لا يوجد تفضيل)';

  @override
  String get subtitleAccounts => 'حسابات الترجمة';

  @override
  String get accounts => 'الحسابات';

  @override
  String get notLoggedIn => 'غير مسجّل الدخول';

  @override
  String loggedInAs(String username) {
    return 'تم تسجيل الدخول باسم $username';
  }

  @override
  String get apiKeyConfigured => 'تم تكوين مفتاح API';

  @override
  String get keyNotSet => 'لم يتم تعيين المفتاح';

  @override
  String get testConnection => 'اختبار الاتصال';

  @override
  String get connectedSuccessfully => 'تم الاتصال بنجاح';

  @override
  String get connectionFailed => 'فشل الاتصال';

  @override
  String get username => 'اسم المستخدم';

  @override
  String get password => 'كلمة المرور';

  @override
  String get noAccountRegister => 'ليس لديك حساب؟ سجل هنا';

  @override
  String get apiKey => 'مفتاح API';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get fetchMyApiKey => 'جلب مفتاح API الخاص بي';

  @override
  String get keyVerified => 'تم التحقق من المفتاح';

  @override
  String get invalidApiKey => 'مفتاح API غير صالح';

  @override
  String get openSubtitlesAuthSubtitle =>
      'أدخل بيانات اعتماد حسابك للحصول على حدود أعلى وترجمات خالية من الإعلانات.';

  @override
  String get subDlAuthSubtitle =>
      'أدخل مفتاح SubDL API الخاص بك مباشرة، أو احصل عليه باستخدام بيانات اعتماد حسابك أدناه.';

  @override
  String get orFetchViaAccount => 'أو الجلب عبر الحساب';

  @override
  String get subSourceAuthSubtitle =>
      'يعمل SubSource تلقائياً، ولكن يمكنك إضافة مفتاح API رسمي شخصي لتجاوز الافتراضي للحصول على موثوقية أفضل.';

  @override
  String get apiKeyOptionalOverride => 'مفتاح API (تجاوز اختياري)';

  @override
  String get enterKeyToOverrideDefault => 'أدخل المفتاح لتجاوز الافتراضي';

  @override
  String get getApiKeyFromProfile =>
      'احصل على مفتاح API الخاص بك من ملف SubSource الشخصي';

  @override
  String get qualityNotGuaranteed =>
      'الجودة غير مضمونة. يتم فرز المصادر حسب التفضيل، ولكن التشغيل يعتمد على ما يقدمه المزود بالفعل.';

  @override
  String get keepSourcesOriginalOrder => 'الحفاظ على المصادر في ترتيبها الأصلي';

  @override
  String get openLink => 'فتح الرابط';

  @override
  String get diagnostics => 'التشخيصات';

  @override
  String get viewLogs => 'عرض السجلات';

  @override
  String get viewLogsSubtitle => 'عرض نشاط التطبيق والأخطاء';

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

/// The translations for Arabic (`ar_apc`).
class AppLocalizationsArApc extends AppLocalizationsAr {
  AppLocalizationsArApc() : super('ar_apc');

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => 'العربية (الشامية)';

  @override
  String get home => 'الرئيسية';

  @override
  String get search => 'بحث';

  @override
  String get explore => 'استكشاف';

  @override
  String get exploreAnime => 'استكشاف الأنمي';

  @override
  String get exploreMovies => 'استكشاف الأفلام';

  @override
  String get library => 'المكتبة';

  @override
  String get settings => 'الإعدادات';

  @override
  String get extensions => 'الإضافات';

  @override
  String get updateAvailable => 'في تحديث جديد';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get factoryReset => 'إعادة ضبط المصنع';

  @override
  String get startupError => 'مشكلة بالتشغيل';

  @override
  String get general => 'عام';

  @override
  String get appTheme => 'ثيم التطبيق';

  @override
  String get recordWatchHistory => 'حفظ سجل المشاهدة';

  @override
  String get defaultHomeScreen => 'الشاشة الرئيسية الافتراضية';

  @override
  String get titlePosition => 'موضع العنوان';

  @override
  String get titlePositionBelowPoster => 'تحت الملصق';

  @override
  String get titlePositionInsidePoster => 'جوّا الملصق';

  @override
  String get player => 'المشغل';

  @override
  String get defaultPlayer => 'المشغل الافتراضي';

  @override
  String get leftGesture => 'حركة اليسار';

  @override
  String get rightGesture => 'حركة اليمين';

  @override
  String get doubleTapToSeek => 'نقر مزدوج للتقديم/التأخير';

  @override
  String get swipeToSeek => 'سحب للتقديم/التأخير';

  @override
  String get seekDuration => 'مدة القفز';

  @override
  String get bufferDepth => 'عمق البفر';

  @override
  String get defaultResizeMode => 'وضع القياس الافتراضي';

  @override
  String get hardwareDecoding => 'فك التشفير العتادي';

  @override
  String get network => 'الشبكة';

  @override
  String get dnsOverHttps => 'DNS عبر HTTPS';

  @override
  String get dohProvider => 'مزود DoH';

  @override
  String get githubProxy => 'وكيل GitHub';

  @override
  String get githubProxySubtitle =>
      'مرّر تنزيلات الإضافات عبر jsDelivr لتخطي حظر مزوّد الإنترنت.';

  @override
  String get manageExtensions => 'إدارة الإضافات';

  @override
  String get appData => 'بيانات التطبيق';

  @override
  String get resetDataKeepExtensions => 'تصفير البيانات (خلي الإضافات)';

  @override
  String get developer => 'المطور';

  @override
  String get developerOptions => 'خيارات المطور';

  @override
  String get about => 'عن التطبيق';

  @override
  String get version => 'الإصدار';

  @override
  String get enabled => 'شغال';

  @override
  String get disabled => 'معطل';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'انضم لسيرفرنا';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'انضم لقناتنا';

  @override
  String developedBy(String name) {
    return 'تم التطوير بواسطة $name';
  }

  @override
  String get system => 'النظام';

  @override
  String get dark => 'ليلي';

  @override
  String get light => 'نهاري';

  @override
  String get later => 'بعدين';

  @override
  String get updateNow => 'حدث هلق';

  @override
  String get save => 'حفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get close => 'إغلاق';

  @override
  String get delete => 'حذف';

  @override
  String get viewDetails => 'عرض التفاصيل';

  @override
  String get clearAll => 'مسح الكل';

  @override
  String get clearAllHistory => 'مسح كل السجل';

  @override
  String get all => 'الكل';

  @override
  String get none => 'ولا شي';

  @override
  String get confirmDownload => 'تأكيد التحميل';

  @override
  String get downloadNow => 'حمل هلق';

  @override
  String get selectSource => 'اختار المصدر';

  @override
  String get downloadUnavailable => 'مو متاح';

  @override
  String get selectAnotherSource => 'اختار غيرو';

  @override
  String get watchHistoryCleared => 'تم مسح سجل المشاهدة';

  @override
  String get downloadingUpdate => 'عم يحمل التحديث...';

  @override
  String errorPrefix(String message) {
    return 'خطأ: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'في تحديث: $tag';
  }

  @override
  String get selectProviderToStart => 'اختار مزود لتبلش';

  @override
  String get tapExtensionIcon => 'اضغط على أيقونة الإضافة بالزاوية';

  @override
  String get continueWatching => 'كمل مشاهدة';

  @override
  String get noInternetConnection => 'ما في اتصال إنترنت';

  @override
  String get siteNotReachable => 'الموقع مو شغال';

  @override
  String get checkConnectionOrDownloads => 'تأكد من النت أو شوف التحميلات.';

  @override
  String get tryVpnOrConnection => 'جرب بروكسي/VPN أو تأكد من اتصالك.';

  @override
  String errorDetails(String error) {
    return 'تفاصيل الخطأ: $error';
  }

  @override
  String get goToDownloads => 'روح للتحميلات';

  @override
  String get selectProvider => 'اختار المزود';

  @override
  String get searchHint => 'دور على أفلام، مسلسلات...';

  @override
  String get searchFavoriteContent => 'دور على شغلاتك المفضلة';

  @override
  String get pressSearchOrEnter => 'اضغط بحث أو Enter لتبلش';

  @override
  String get noResultsFound => 'ما لقينا شي.';

  @override
  String get couldNotLoadTrending => 'ما قدرنا نحمل التريندات';

  @override
  String get popularMovies => 'أفلام مشهورة';

  @override
  String get popularTVShows => 'مسلسلات مشهورة';

  @override
  String get newMovies => 'أفلام جديدة';

  @override
  String get newTVShows => 'مسلسلات جديدة';

  @override
  String get featuredMovies => 'أفلام مميزة';

  @override
  String get featuredTVShows => 'مسلسلات مميزة';

  @override
  String get lastVideosTVShows => 'آخر الحلقات';

  @override
  String get downloads => 'التحميلات';

  @override
  String get bookmarks => 'الإشارات';

  @override
  String get noDownloadsYet => 'لسه ما حملت شي';

  @override
  String episodesCount(int count, int done) {
    return '$count حلقة • خلصت $done';
  }

  @override
  String get deleteAllEpisodes => 'حذف كل الحلقات';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return 'متأكد بدك تحذف الـ $count حلقات من \"$title\" مع ملفاتهم؟';
  }

  @override
  String get deleteAll => 'حذف الكل';

  @override
  String get completed => 'تم';

  @override
  String get statusQueued => 'بالانتظار...';

  @override
  String get statusDownloading => 'عم يحمل...';

  @override
  String get statusFinished => 'خلص';

  @override
  String get statusFailed => 'فشل';

  @override
  String get statusCanceled => 'ملغي';

  @override
  String get statusPaused => 'موقف مؤقتاً';

  @override
  String get statusWaiting => 'ناطر...';

  @override
  String get fileNotFoundRemoving => 'الملف مو موجود. عم نمسح السجل.';

  @override
  String get fileNotFound => 'المنف مو موجود';

  @override
  String get deleteDownload => 'حذف التحميل';

  @override
  String get confirmDeleteDownload => 'متأكد بدك تحذف هاد التحميل؟';

  @override
  String get libraryEmpty => 'مكتبتك فاضية';

  @override
  String get language => 'اللغة';

  @override
  String get english => 'إنكليزي';

  @override
  String get hindi => 'هندي';

  @override
  String get kannada => 'كانادا';

  @override
  String get unknown => 'غير معروف';

  @override
  String get recommended => 'مقترح';

  @override
  String get on => 'شغال';

  @override
  String get off => 'مطفى';

  @override
  String get installRemoveProviders => 'تثبيت/حذف المزودين';

  @override
  String get resetDataSubtitle => 'مسح الإعدادات والداتا، وخلي الإضافات';

  @override
  String get factoryResetSubtitle => 'مسح كل شي: داتا، إعدادات، وإضافات';

  @override
  String get developerOptionsSubtitle => 'أدوات المطورين';

  @override
  String get loading => 'عم يحمل...';

  @override
  String get sec => 'ثانية';

  @override
  String get min => 'دقيقة';

  @override
  String get internalPlayer => 'داخلي (media_kit)';

  @override
  String get builtInPlayer => 'مشغل مدمج';

  @override
  String get customNotSet => 'مخصص (مو محدد)';

  @override
  String selectGesture(String side) {
    return 'اختار حركة ($side)';
  }

  @override
  String get left => 'يسار';

  @override
  String get right => 'يمين';

  @override
  String get selectSeekDuration => 'اختار مدة القفز';

  @override
  String get selectBufferDepth => 'اختار عمق البفر';

  @override
  String get subtitleSettings => 'إعدادات الترجمة';

  @override
  String size(int size) {
    return 'الحجم: $size';
  }

  @override
  String get background => 'الخلفية';

  @override
  String get customDohUrlLabel => 'رابط DoH مخصص';

  @override
  String get enterCustomDohUrl => 'حط رابط DoH تبعك';

  @override
  String get chooseTheme => 'اختار الثيم';

  @override
  String get resetDataDialogTitle => 'تصفير البيانات؟';

  @override
  String get resetDataDialogContent =>
      'هاد حيمسح الإعدادات، المفضلة، والسجل. الإضافات ما حتتمسح.';

  @override
  String get factoryResetDialogTitle => 'ضبط مصنع؟';

  @override
  String get factoryResetDialogContent =>
      'هاد حيمسح كل شي. ما بيمشي الحال ترجع بعدين.';

  @override
  String get selectLanguage => 'اختار اللغة';

  @override
  String get synopsis => 'القصة';

  @override
  String get noDescription => 'ما في وصف.';

  @override
  String get videoAlreadyDownloadedPrompt =>
      'هاد الفيديو محمل أصلاً. شو بدك تعمل؟';

  @override
  String get playNow => 'شغل هلق';

  @override
  String get upNext => 'اللي جاي';

  @override
  String get deleteDownloadPrompt => 'حذف التحميل؟';

  @override
  String get deleteDownloadConfirmation => 'متأكد؟ الحذف ما بيرجع.';

  @override
  String get no => 'لأ';

  @override
  String get yesDelete => 'إي، احذف';

  @override
  String get downloadPaused => 'التحميل موقف';

  @override
  String get downloading => 'عم يحمل';

  @override
  String get speed => 'السرعة';

  @override
  String get remaining => 'باقي';

  @override
  String get resume => 'كمل';

  @override
  String get pause => 'توقف';

  @override
  String get torrentContent => 'محتوى تورنت';

  @override
  String get audioTracks => 'مسارات الصوت';

  @override
  String get noAudioTracks => 'ما لقينا مسارات صوت';

  @override
  String get subtitles => 'الترجمة';

  @override
  String get options => 'خيارات';

  @override
  String get noSubtitlesFound => 'ما لقينا ترجمات';

  @override
  String get playbackSpeed => 'سرعة التشغيل';

  @override
  String get subtitleOptions => 'خيارات الترجمة';

  @override
  String get hlsSubtitleWarning =>
      'الترجمات الخارجية مو مدعومة للـ HLS على هاد الجهاز.';

  @override
  String get loadFromDevice => 'حمل من الجهاز';

  @override
  String get syncDelay => 'مزامنة / تأخير';

  @override
  String get styleSettings => 'إعدادات الستايل';

  @override
  String get searchOnline => 'بحث أونلاين';

  @override
  String get subtitleSync => 'مزامنة الترجمة';

  @override
  String get subtitleDelayWarning => 'تأخير الترجمة مو مدعوم بالمشغل الحالي.';

  @override
  String get resetDelay => 'تصفير التأخير';

  @override
  String get subtitleStyles => 'ستايلات الترجمة';

  @override
  String get mediaKitStylingWarning =>
      'تغيير ستايل الترجمة بس للـ media_kit حالياً.';

  @override
  String get resetToDefault => 'الافتراضي';

  @override
  String get fontSize => 'حجم الخط';

  @override
  String get verticalPosition => 'المكان العمودي';

  @override
  String get textColor => 'لون الخط';

  @override
  String get backgroundColor => 'لون الخلفية';

  @override
  String get backgroundOpacity => 'شفافية الخلفية';

  @override
  String get subtitleSearch => 'بحث عن ترجمة';

  @override
  String get searchSubtitleNameHint => 'اسم الترجمة...';

  @override
  String get enterSearchSubtitlePrompt => 'حط اسم لتدور على ترجمات.';

  @override
  String get noSubtitleResults => 'ما لقينا شي.';

  @override
  String get downloadingApplyingSubtitle => 'عم يحمل ويطبق الترجمة...';

  @override
  String get failedToDownloadSubtitle => 'فشل تحميل الترجمة.';

  @override
  String get failedToLoadSubtitles => 'فشل عرض الترجمة.';

  @override
  String get noReposFound => 'ما في مستودعات';

  @override
  String get downloadAllProviders => 'تحميل الكل';

  @override
  String get removeRepository => 'حذف المستودع';

  @override
  String get addRepo => 'إضافة مستودع';

  @override
  String get extensionsNotInRepos => 'إضافات مو بالمستودعات';

  @override
  String get noLongerInRepo => 'ما عاد موجود بالمستودع';

  @override
  String get addRepoToBrowse => 'ضيف مستودع لتتصفح';

  @override
  String get debugExtensions => 'ديباغ الإضافات';

  @override
  String removeRepoConfirm(String repoName) {
    return 'حذف $repoName؟';
  }

  @override
  String get removeRepoWarning => 'هاد حيحذف المستودع وكل إضافاته.';

  @override
  String get addRepository => 'إضافة مستودع';

  @override
  String get repoUrlOrShortcode => 'رابط أو كود قصير';

  @override
  String get assetPlugin => 'إضافة مدمجة';

  @override
  String get installed => 'مثبت';

  @override
  String get repositories => 'المستودعات';

  @override
  String get noExtensionsInstalled => 'ما في إضافات مثبتة';

  @override
  String get browseRepositoriesToInstall =>
      'افتح تبويب المستودعات لتلاقي إضافات وتثبتها.';

  @override
  String get browseRepositories => 'تصفّح المستودعات';

  @override
  String get addRepoDescription =>
      'ضيف رابط مستودع أو رمز مختصر لتلاقي إضافات وتثبتها.';

  @override
  String updateTo(String version) {
    return 'تحديث لـ $version';
  }

  @override
  String get install => 'تثبيت';

  @override
  String get error => 'خطأ';

  @override
  String get ok => 'تمام';

  @override
  String pluginSettings(String pluginName) {
    return 'إعدادات $pluginName';
  }

  @override
  String get movies => 'أفلام';

  @override
  String get series => 'مسلسلات';

  @override
  String get anime => 'أنمي';

  @override
  String get liveStreams => 'بث مباشر';

  @override
  String get debug => 'ديباغ';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تحدثوا $count إضافة',
      many: 'تحدثوا $count إضافة',
      few: 'تحدثوا $count إضافات',
      one: 'تحدثت إضافة وحدة',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => 'نقلة مو صحيحة.';

  @override
  String get startOver => 'عيد من الأول';

  @override
  String get goBack => 'رجوع';

  @override
  String get resolving => 'عم يفك الروابط...';

  @override
  String get downloaded => 'محمل';

  @override
  String get download => 'تحميل';

  @override
  String get debugOnlyFeature => 'بس لنسخ المطورين';

  @override
  String get streamUrl => 'رابط البث';

  @override
  String get play => 'شغل';

  @override
  String get verifyingSourceSize => 'عم يتأكد من الحجم...';

  @override
  String get fileSaveLocationNotification => 'الملف حينحفظ بالمجلدDownloads.';

  @override
  String get resumingPlayback => 'عم نكمل';

  @override
  String pausedAt(String time) {
    return 'توقف عند $time';
  }

  @override
  String resumesAutomatically(int count) {
    return 'حيكمل لحالو بعد $count ثانية';
  }

  @override
  String get resumeNow => 'كمل هلق';

  @override
  String get playbackError => 'خطأ بالتشغيل';

  @override
  String get confirmClearHistory => 'مسح السجل؟';

  @override
  String seasonWithNumber(Object number) {
    return 'الموسم $number';
  }

  @override
  String get starting => 'عم يبلش...';

  @override
  String percentWatched(int percent) {
    return 'شفت $percent%';
  }

  @override
  String get sub => 'مترجم';

  @override
  String get dub => 'مدبلج';

  @override
  String playEpisode(String label, Object season, Object episode) {
    return '$label م$season ح$episode';
  }

  @override
  String playEpisodeOnly(String label, int episode) {
    return '$label E$episode';
  }

  @override
  String get debugTools => 'أدوات الديباغ';

  @override
  String get playLocalVideo => 'فيديو من الجهاز';

  @override
  String get playLocalVideoSubtitle => 'شغل ملف من عندك';

  @override
  String get streamUrlSubtitle => 'شغل من رابط';

  @override
  String get streamTorrent => 'بث تورنت';

  @override
  String get streamTorrentSubtitle => 'اختار ملف تورنت';

  @override
  String get loadPluginFromAssets => 'حمل من الأصول';

  @override
  String get enterVideoUrlHint => 'رابط الفيديو';

  @override
  String get networkStream => 'بث شبكي';

  @override
  String removedFromHistory(String title) {
    return 'انحذف: $title';
  }

  @override
  String get custom => 'مخصص';

  @override
  String get refreshingLiveStream => 'عم يحدث...';

  @override
  String get removeFromHistory => 'حذف من السجل';

  @override
  String get live => 'مباشر';

  @override
  String get volume => 'الصوت';

  @override
  String get brightness => 'السطوع';

  @override
  String get fit => 'قياس';

  @override
  String get zoom => 'زووم';

  @override
  String get stretch => 'مط';

  @override
  String titleWithParam(String title) {
    return 'العنوان: $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'المصدر: $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'الحجم: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'خطأ: $error. مشغل داخلي.';
  }

  @override
  String playerNotDetected(String playerName) {
    return 'ما لقينا $playerName.';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return 'الموسم $number ($count حلقة)';
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
    return 'المصدر لـ $playerName';
  }

  @override
  String get noPluginsInstalled => 'ما في إضافات';

  @override
  String get noPluginsMessage => 'قم بتثبيت الإضافات لتصفح وبث المحتوى.';

  @override
  String get goToExtensions => 'الذهاب إلى الإضافات';

  @override
  String get availableSources => 'المصادر المتاحة';

  @override
  String get seasons => 'مواسم';

  @override
  String get episodes => 'حلقات';

  @override
  String get selectSourceToPlay => 'اختار مصدر لتشغل.';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حلقة',
      many: '$count حلقة',
      few: '$count حلقات',
      one: 'حلقة وحدة',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'ما في حلقات';

  @override
  String get local => 'محلي';

  @override
  String get remote => 'عن بعد';

  @override
  String get torrent => 'تورنت';

  @override
  String get unlock => 'فك القفل';

  @override
  String get lock => 'قفل';

  @override
  String get sources => 'مصادر';

  @override
  String get tracks => 'مسارات';

  @override
  String get content => 'محتوى';

  @override
  String get stats => 'إحصائيات';

  @override
  String get resize => 'تعديل القياس';

  @override
  String get next => 'التالي';

  @override
  String get pip => 'PiP';

  @override
  String get rotate => 'تدوير';

  @override
  String get windowed => 'نافذة';

  @override
  String get fullscreen => 'شاشة كاملة';

  @override
  String get movieDetails => 'التفاصيل';

  @override
  String get showDetails => 'عرض التفاصيل';

  @override
  String get tagline => 'شعار';

  @override
  String get status => 'الحالة';

  @override
  String get releaseDate => 'تاريخ الإصدار';

  @override
  String get firstAirDate => 'أول عرض';

  @override
  String get originalLanguage => 'اللغة الأصلية';

  @override
  String get originCountry => 'البلد';

  @override
  String get budgetLabel => 'الميزانية';

  @override
  String get revenueLabel => 'الأرباح';

  @override
  String get paused => 'موقف';

  @override
  String get watched => 'تمت المشاهدة';

  @override
  String get watching => 'جاري المشاهدة';

  @override
  String get lastWatched => 'آخر مشاهدة';

  @override
  String get movie => 'فيلم';

  @override
  String get tvShow => 'مسلسل';

  @override
  String get failedToLoadContent => 'فشل التحميل';

  @override
  String get director => 'المخرج';

  @override
  String get creator => 'المؤلف';

  @override
  String get showMore => 'أكثر';

  @override
  String get showLess => 'أقل';

  @override
  String get viewAll => 'الكل';

  @override
  String seasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count موسم',
      many: '$count موسم',
      few: '$count مواسم',
      one: 'موسم واحد',
    );
    return '$_temp0';
  }

  @override
  String get noInternetError => 'ما في نت';

  @override
  String get timeoutError => 'خلص الوقت.';

  @override
  String get serverError => 'خطأ بالسيرفر.';

  @override
  String get contentNotFoundError => 'مو موجود.';

  @override
  String get accessDeniedError => 'مرفوض.';

  @override
  String get serviceUnavailableError => 'الخدمة مو متاحة.';

  @override
  String get generalError => 'صار خطأ.';

  @override
  String get skip => 'تخطي';

  @override
  String get skipIntro => 'تخطي المقدمة';

  @override
  String get skipOutro => 'تخطي النهاية';

  @override
  String get skipRecap => 'تخطي الملخص';

  @override
  String get goLive => 'مباشر';

  @override
  String get dismiss => 'تجاهل';

  @override
  String get nextUp => 'التالي';

  @override
  String sourceAttempt(int index, int total) {
    return 'محاولة $index من $total';
  }

  @override
  String get trying => 'عم يجرب';

  @override
  String get failed => 'فشل';

  @override
  String get selected => 'مختار';

  @override
  String get playing => 'عم يشتغل';

  @override
  String get pending => 'ناطر';

  @override
  String get openSubtitles => 'OpenSubtitles';

  @override
  String get subDl => 'SubDL';

  @override
  String get subSource => 'SubSource';

  @override
  String get wifiQualityPreference => 'تفضيل جودة الواي فاي';

  @override
  String get mobileQualityPreference => 'تفضيل جودة الهاتف المحمول';

  @override
  String get anyNoPreference => 'أي نوع (لا يوجد تفضيل)';

  @override
  String get subtitleAccounts => 'حسابات الترجمة';

  @override
  String get accounts => 'الحسابات';

  @override
  String get notLoggedIn => 'غير مسجّل الدخول';

  @override
  String loggedInAs(String username) {
    return 'تم تسجيل الدخول باسم $username';
  }

  @override
  String get apiKeyConfigured => 'تم تكوين مفتاح API';

  @override
  String get keyNotSet => 'لم يتم تعيين المفتاح';

  @override
  String get testConnection => 'اختبار الاتصال';

  @override
  String get connectedSuccessfully => 'تم الاتصال بنجاح';

  @override
  String get connectionFailed => 'فشل الاتصال';

  @override
  String get username => 'اسم المستخدم';

  @override
  String get password => 'كلمة المرور';

  @override
  String get noAccountRegister => 'ليس لديك حساب؟ سجل هنا';

  @override
  String get apiKey => 'مفتاح API';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get fetchMyApiKey => 'جلب مفتاح API الخاص بي';

  @override
  String get keyVerified => 'تم التحقق من المفتاح';

  @override
  String get invalidApiKey => 'مفتاح API غير صالح';

  @override
  String get openSubtitlesAuthSubtitle =>
      'أدخل بيانات اعتماد حسابك للحصول على حدود أعلى وترجمات خالية من الإعلانات.';

  @override
  String get subDlAuthSubtitle =>
      'أدخل مفتاح SubDL API الخاص بك مباشرة، أو احصل عليه باستخدام بيانات اعتماد حسابك أدناه.';

  @override
  String get orFetchViaAccount => 'أو الجلب عبر الحساب';

  @override
  String get subSourceAuthSubtitle =>
      'يعمل SubSource تلقائياً، ولكن يمكنك إضافة مفتاح API رسمي شخصي لتجاوز الافتراضي للحصول على موثوقية أفضل.';

  @override
  String get apiKeyOptionalOverride => 'مفتاح API (تجاوز اختياري)';

  @override
  String get enterKeyToOverrideDefault => 'أدخل المفتاح لتجاوز الافتراضي';

  @override
  String get getApiKeyFromProfile =>
      'احصل على مفتاح API الخاص بك من ملف SubSource الشخصي';

  @override
  String get qualityNotGuaranteed =>
      'الجودة غير مضمونة. يتم فرز المصادر حسب التفضيل، ولكن التشغيل يعتمد على ما يقدمه المزود بالفعل.';

  @override
  String get keepSourcesOriginalOrder => 'الحفاظ على المصادر في ترتيبها الأصلي';

  @override
  String get openLink => 'فتح الرابط';

  @override
  String get diagnostics => 'التشخيصات';

  @override
  String get viewLogs => 'عرض السجلات';

  @override
  String get viewLogsSubtitle => 'عرض نشاط التطبيق والأخطاء';

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
