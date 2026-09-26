// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Marathi (`mr`).
class AppLocalizationsMr extends AppLocalizations {
  AppLocalizationsMr([String locale = 'mr']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => 'मराठी';

  @override
  String get addonHealthChecking => 'Checking add-on…';

  @override
  String addonHealthWorking(int ms) {
    return 'Working · $ms ms';
  }

  @override
  String get addonHealthUnavailable => 'Unavailable';

  @override
  String get home => 'मुख्यपृष्ठ';

  @override
  String get search => 'शोध';

  @override
  String get explore => 'शोध घ्या';

  @override
  String get exploreAnime => 'अ‍ॅनिमे शोधा';

  @override
  String get exploreMovies => 'चित्रपट शोधा';

  @override
  String get library => 'ग्रंथालय';

  @override
  String get settings => 'सेटिंग्ज';

  @override
  String get extensions => 'एक्सटेंशन्स';

  @override
  String get updateAvailable => 'अपडेट उपलब्ध आहे';

  @override
  String get retry => 'पुन्हा प्रयत्न करा';

  @override
  String get factoryReset => 'फॅक्टरी रिसेट';

  @override
  String get startupError => 'प्रारंभ त्रुटी';

  @override
  String get general => 'सामान्य';

  @override
  String get appTheme => 'अ‍ॅप थीम';

  @override
  String get recordWatchHistory => 'पाहिलेला इतिहास जतन करा';

  @override
  String get fullScreenMode => 'पूर्ण स्क्रीन';

  @override
  String get fullScreenModeSubtitle => 'टीव्ही लेआउटवर स्विच करते';

  @override
  String get defaultHomeScreen => 'डीफॉल्ट मुख्यपृष्ठ स्क्रीन';

  @override
  String get titlePosition => 'शीर्षकाचे स्थान';

  @override
  String get titlePositionBelowPoster => 'पोस्टरच्या खाली';

  @override
  String get titlePositionInsidePoster => 'पोस्टरमध्ये';

  @override
  String get player => 'प्लेअर';

  @override
  String get defaultPlayer => 'डीफॉल्ट प्लेअर';

  @override
  String get leftGesture => 'डावी हालचाल (Gesture)';

  @override
  String get rightGesture => 'उजवी हालचाल (Gesture)';

  @override
  String get doubleTapToSeek => 'शोधण्यासाठी दोनदा टॅप करा';

  @override
  String get swipeToSeek => 'शोधण्यासाठी स्वाइप करा';

  @override
  String get seekDuration => 'शोध कालावधी';

  @override
  String get defaultResizeMode => 'डीफॉल्ट रिसाइझ मोड';

  @override
  String get hardwareDecoding => 'हार्डवेअर डिकोडिंग';

  @override
  String get network => 'नेटवर्क';

  @override
  String get dnsOverHttps => 'HTTPS वर DNS';

  @override
  String get dohProvider => 'DoH प्रदाता';

  @override
  String get githubProxy => 'GitHub प्रॉक्सी';

  @override
  String get githubProxySubtitle =>
      'ISP अडथळे टाळण्यासाठी विस्तार डाउनलोड jsDelivr मार्गे पाठवा.';

  @override
  String get manageExtensions => 'एक्सटेंशन्स व्यवस्थापित करा';

  @override
  String get appData => 'अ‍ॅप डेटा';

  @override
  String get resetDataKeepExtensions => 'डेटा रिसेट करा (एक्सटेंशन्स ठेवा)';

  @override
  String get developer => 'डेव्हलपर';

  @override
  String get developerOptions => 'डेव्हलपर पर्याय';

  @override
  String get about => 'बद्दल';

  @override
  String get version => 'आवृत्ती';

  @override
  String get enabled => 'सक्षम';

  @override
  String get disabled => 'अक्षम';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'आमच्या सर्व्हरमध्ये सामील व्हा';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'आमच्या चॅनेलमध्ये सामील व्हा';

  @override
  String developedBy(String name) {
    return '$name द्वारे विकसित';
  }

  @override
  String get system => 'सिस्टम';

  @override
  String get dark => 'गडद';

  @override
  String get light => 'प्रकाशमय';

  @override
  String get later => 'नंतर';

  @override
  String get updateNow => 'आत्ता अपडेट करा';

  @override
  String get save => 'जतन करा';

  @override
  String get cancel => 'रद्द करा';

  @override
  String get close => 'बंद करा';

  @override
  String get delete => 'हटवा';

  @override
  String get viewDetails => 'तपशील पहा';

  @override
  String get clearAll => 'सर्व साफ करा';

  @override
  String get clearAllHistory => 'सर्व इतिहास साफ करा';

  @override
  String get all => 'सर्व';

  @override
  String get none => 'काहीही नाही';

  @override
  String get confirmDownload => 'डाउनलोडची पुष्टी करा';

  @override
  String get downloadNow => 'आत्ता डाउनलोड करा';

  @override
  String get selectSource => 'स्रोत निवडा';

  @override
  String get downloadUnavailable => 'डाउनलोड उपलब्ध नाही';

  @override
  String get selectAnotherSource => 'दुसरा स्रोत निवडा';

  @override
  String get watchHistoryCleared => 'इतिहास साफ केला';

  @override
  String get downloadingUpdate => 'अपडेट डाउनलोड होत आहे...';

  @override
  String errorPrefix(String message) {
    return 'त्रुटी: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'अपडेट उपलब्ध आहे: $tag';
  }

  @override
  String get selectProviderToStart => 'पाहणे सुरू करण्यासाठी प्रदाता निवडा';

  @override
  String get tapExtensionIcon => 'कोपऱ्यातील एक्सटेंशन चिन्हावर टॅप करा';

  @override
  String get continueWatching => 'पाहणे सुरू ठेवा';

  @override
  String get noInternetConnection => 'इंटरनेट कनेक्शन नाही';

  @override
  String get siteNotReachable => 'साइट पोहोचण्यायोग्य नाही';

  @override
  String get checkConnectionOrDownloads =>
      'तुमचे कनेक्शन तपासा किंवा तुमचे डाउनलोड केलेले साहित्य पहा.';

  @override
  String get tryVpnOrConnection =>
      'कृपया VPN वापरून साइट पहा किंवा तुमचे इंटरनेट कनेक्शन तपासा.';

  @override
  String errorDetails(String error) {
    return 'त्रुटी तपशील: $error';
  }

  @override
  String get goToDownloads => 'डाउनलोड्सवर जा';

  @override
  String get selectProvider => 'प्रदाता निवडा';

  @override
  String get searchHint => 'चित्रपट, मालिका शोधा...';

  @override
  String get searchFavoriteContent => 'तुमचे आवडते साहित्य शोधा';

  @override
  String get pressSearchOrEnter => 'सुरू करण्यासाठी सर्च की किंवा Enter दाबा';

  @override
  String get recentSearches => 'Recent searches';

  @override
  String removeFromSearchHistory(String query) {
    return 'Remove $query from search history';
  }

  @override
  String get noResultsFound => 'निकाल सापडले नाहीत.';

  @override
  String get couldNotLoadTrending => 'ट्रेंडिंग आयटम लोड करता आले नाहीत';

  @override
  String get popularMovies => 'लोकप्रिय चित्रपट';

  @override
  String get popularTVShows => 'लोकप्रिय टीव्ही शो';

  @override
  String get newMovies => 'नवीन चित्रपट';

  @override
  String get newTVShows => 'नवीन टीव्ही शो';

  @override
  String get featuredMovies => 'वैशिष्ट्यीकृत चित्रपट';

  @override
  String get featuredTVShows => 'वैशिष्ट्यीकृत टीव्ही शो';

  @override
  String get lastVideosTVShows => 'शेवटचे टीव्ही शो';

  @override
  String get downloads => 'डाउनलोड्स';

  @override
  String get bookmarks => 'बुकमार्क्स';

  @override
  String get noDownloadsYet => 'अद्याप कोणतेही डाउनलोड नाहीत';

  @override
  String episodesCount(int count, int done) {
    return '$count भाग • $done पूर्ण';
  }

  @override
  String get deleteAllEpisodes => 'सर्व भाग हटवा';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return 'तुम्हाला खात्री आहे की तुम्ही \"$title\" चे सर्व $count भाग आणि त्यांच्या फायली हटवू इच्छिता?';
  }

  @override
  String get deleteAll => 'सर्व हटवा';

  @override
  String get completed => 'पूर्ण झाले';

  @override
  String get statusQueued => 'रांगेत...';

  @override
  String get statusDownloading => 'डाउनलोड होत आहे...';

  @override
  String get statusFinished => 'पूर्ण झाले';

  @override
  String get statusFailed => 'अयशस्वी';

  @override
  String get statusCanceled => 'रद्द केले';

  @override
  String get statusPaused => 'थांबवले';

  @override
  String get statusWaiting => 'प्रतीक्षा करत आहे...';

  @override
  String get fileNotFoundRemoving =>
      'डिस्कवर फाइल आढळली नाही. रेकॉर्ड हटवत आहे.';

  @override
  String get fileNotFound => 'फाइल आढळली नाही';

  @override
  String get deleteDownload => 'डाउनलोड हटवा';

  @override
  String get confirmDeleteDownload =>
      'तुम्हाला खात्री आहे की तुम्ही हे डाउनलोड आणि त्याची फाइल हटवू इच्छिता?';

  @override
  String get libraryEmpty => 'तुमचे ग्रंथालय रिकामे आहे';

  @override
  String get language => 'भाषा';

  @override
  String get english => 'इंग्रजी';

  @override
  String get hindi => 'हिंदी';

  @override
  String get kannada => 'कन्नड';

  @override
  String get unknown => 'अज्ञात';

  @override
  String get recommended => 'शिफारस केलेले';

  @override
  String get on => 'सुरू';

  @override
  String get off => 'बंद';

  @override
  String get installRemoveProviders => 'प्रदाते स्थापित करा किंवा हटवा';

  @override
  String get resetDataSubtitle => 'सेटिंग्ज आणि डेटाबेस साफ करा, प्लगइन्स ठेवा';

  @override
  String get factoryResetSubtitle => 'सर्व डेटा, सेटिंग्ज आणि एक्सटेंशन्स हटवा';

  @override
  String get developerOptionsSubtitle => 'डीबग टूल्स आणि लोकल प्ले';

  @override
  String get loading => 'लोड होत आहे...';

  @override
  String get sec => 'सेकंद';

  @override
  String get min => 'मिनिट';

  @override
  String playerRewindSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सेकंद मागे जा',
      one: '1 सेकंद मागे जा',
    );
    return '$_temp0';
  }

  @override
  String playerForwardSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सेकंद पुढे जा',
      one: '1 सेकंद पुढे जा',
    );
    return '$_temp0';
  }

  @override
  String get internalPlayer => 'अंतर्गत प्लेअर (VLC)';

  @override
  String get builtInPlayer => 'बिल्ट-इन प्लेअर';

  @override
  String get customNotSet => 'सानुकूल (सेट नाही)';

  @override
  String selectGesture(String side) {
    return '$side हालचाल निवडा';
  }

  @override
  String get left => 'डावी';

  @override
  String get right => 'उजवी';

  @override
  String get selectSeekDuration => 'शोध कालावधी निवडा';

  @override
  String get subtitleSettings => 'उपशीर्षक (Subtitle) सेटिंग्ज';

  @override
  String size(int size) {
    return 'आकार: $size';
  }

  @override
  String get background => 'पार्श्वभूमी';

  @override
  String get customDohUrlLabel => 'सानुकूल DoH URL';

  @override
  String get enterCustomDohUrl => 'तुमचे स्वतःचे DoH URL प्रविष्ट करा';

  @override
  String get chooseTheme => 'थीम निवडा';

  @override
  String get resetDataDialogTitle => 'डेटा रिसेट करायचा?';

  @override
  String get resetDataDialogContent =>
      'यामुळे सेटिंग्ज, आवडी आणि इतिहास साफ होईल. तुमचे स्थापित एक्सटेंशन्स हटवले जाणार नाहीत.';

  @override
  String get factoryResetDialogTitle => 'फॅक्टरी रिसेट करायचा?';

  @override
  String get factoryResetDialogContent =>
      'यामुळे सर्व काही हटवले जाईल: आवडी, इतिहास, सेटिंग्ज आणि सर्व एक्सटेंशन्स. हे पूर्ववत केले जाऊ शकत नाही.';

  @override
  String get selectLanguage => 'भाषा निवडा';

  @override
  String get synopsis => 'सारांश';

  @override
  String get noDescription => 'वर्णन उपलब्ध नाही.';

  @override
  String get videoAlreadyDownloadedPrompt =>
      'हा व्हिडिओ आधीच डाउनलोड झाला आहे. आपण काय करू इच्छिता?';

  @override
  String get playNow => 'आत्ता पहा';

  @override
  String get upNext => 'पुढे';

  @override
  String get deleteDownloadPrompt => 'डाउनलोड हटवायचे?';

  @override
  String get deleteDownloadConfirmation =>
      'तुम्हाला खात्री आहे की तुम्ही ही फाइल हटवू इच्छिता? हे पूर्ववत केले जाऊ शकत नाही.';

  @override
  String get no => 'नाही';

  @override
  String get yesDelete => 'हो, हटवा';

  @override
  String get downloadPaused => 'डाउनलोड थांबवले';

  @override
  String get downloading => 'डाउनलोड होत आहे';

  @override
  String get speed => 'वेग';

  @override
  String get remaining => 'शिल्लक';

  @override
  String get resume => 'पुन्हा सुरू करा';

  @override
  String get pause => 'थांबवा';

  @override
  String get torrentContent => 'टॉरेंट साहित्य';

  @override
  String get audioTracks => 'ऑडिओ ट्रॅक';

  @override
  String get noAudioTracks => 'कोणतेही ऑडिओ ट्रॅक आढळले नाहीत';

  @override
  String get subtitles => 'उपशीर्षके';

  @override
  String get options => 'पर्याय';

  @override
  String get noSubtitlesFound => 'कोणतीही उपशीर्षके आढळली नाहीत';

  @override
  String get playbackSpeed => 'प्लेबॅक वेग';

  @override
  String get subtitleOptions => 'उपशीर्षक पर्याय';

  @override
  String get hlsSubtitleWarning =>
      'या प्लॅटफॉर्मवर सक्रिय HLS प्लेअरवर बाह्य उपशीर्षक फायली समर्थित नाहीत.';

  @override
  String get loadFromDevice => 'डिव्हाइसवरून लोड करा';

  @override
  String get syncDelay => 'सिंक / विलंब';

  @override
  String get styleSettings => 'स्टाईल सेटिंग्ज';

  @override
  String get searchOnline => 'ऑनलाइन शोधा (उपशीर्षक शोध)';

  @override
  String get subtitleSync => 'उपशीर्षक सिंक';

  @override
  String get subtitleDelayWarning =>
      'सक्रिय प्लेबॅक इंजिनद्वारे उपशीर्षक विलंब समर्थित नाही.';

  @override
  String get resetDelay => 'विलंब रिसेट करा';

  @override
  String get subtitleStyles => 'उपशीर्षक शैली';

  @override
  String get resetToDefault => 'डीफॉल्टवर रिसेट करा';

  @override
  String get fontSize => 'फॉन्ट आकार';

  @override
  String get verticalPosition => 'उभी स्थिती';

  @override
  String get textColor => 'मजकूर रंग';

  @override
  String get backgroundColor => 'पार्श्वभूमी रंग';

  @override
  String get backgroundOpacity => 'पार्श्वभूमी पारदर्शकता';

  @override
  String get subtitleSearch => 'उपशीर्षक शोध';

  @override
  String get searchSubtitleNameHint => 'उपशीर्षक नाव शोधा...';

  @override
  String get enterSearchSubtitlePrompt =>
      'उपशीर्षके शोधण्यासाठी नाव प्रविष्ट करा.';

  @override
  String get noSubtitleResults => 'निकाल सापडले नाहीत. दुसरा शोध करून पहा.';

  @override
  String get downloadingApplyingSubtitle =>
      'उपशीर्षक डाउनलोड आणि लागू करत आहे...';

  @override
  String get failedToDownloadSubtitle => 'उपशीर्षक डाउनलोड करणे अयशस्वी.';

  @override
  String get failedToLoadSubtitles =>
      'उपशीर्षके लोड करणे अयशस्वी. कृपया पुन्हा प्रयत्न करा.';

  @override
  String get noReposFound => 'कोणतेही रिपॉझिटरीज किंवा प्लगइन्स आढळले नाहीत';

  @override
  String get downloadAllProviders => 'सर्व डाउनलोड करा';

  @override
  String get removeRepository => 'रिपॉझिटरी हटवा';

  @override
  String get addRepo => 'रिपो जोडा';

  @override
  String get extensionsNotInRepos => 'रिपॉझिटरीजमध्ये नसलेली एक्सटेंशन्स';

  @override
  String get noLongerInRepo => 'आता कोणत्याही रिपॉझिटरीमध्ये सूचीबद्ध नाही';

  @override
  String get addRepoToBrowse =>
      'प्लगइन्स पाहण्यासाठी आणि अपडेट करण्यासाठी रिपॉझिटरी जोडा';

  @override
  String get debugExtensions => 'डीबग एक्सटेंशन्स';

  @override
  String removeRepoConfirm(String repoName) {
    return '$repoName हटवायचे?';
  }

  @override
  String get removeRepoWarning =>
      'यामुळे रिपॉझिटरी हटवली जाईल आणि त्याचे सर्व प्लगइन्स अनइन्स्टॉल होतील.';

  @override
  String get addRepository => 'रिपॉझिटरी जोडा';

  @override
  String get repoUrlOrShortcode => 'रिपॉझिटरी URL किंवा शॉर्टकोड';

  @override
  String get assetPlugin => 'अ‍ॅसेट प्लगइन';

  @override
  String get installed => 'संस्थापित';

  @override
  String get repositories => 'रिपॉझिटरीज';

  @override
  String get noExtensionsInstalled => 'कोणतेही विस्तार स्थापित नाहीत';

  @override
  String get browseRepositoriesToInstall =>
      'विस्तार शोधण्यासाठी आणि स्थापित करण्यासाठी रिपॉझिटरीज टॅब पहा.';

  @override
  String get browseRepositories => 'रिपॉझिटरीज ब्राउझ करा';

  @override
  String get addRepoDescription =>
      'विस्तार प्लगइन शोधण्यासाठी आणि स्थापित करण्यासाठी रिपॉझिटरी URL किंवा शॉर्टकोड जोडा.';

  @override
  String updateTo(String version) {
    return '$version वर अपडेट करा';
  }

  @override
  String get install => 'संस्थापित करा';

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
  String get error => 'त्रुटी';

  @override
  String get ok => 'ठीक आहे';

  @override
  String pluginSettings(String pluginName) {
    return '$pluginName सेटिंग्ज';
  }

  @override
  String get movies => 'चित्रपट';

  @override
  String get series => 'मालिका';

  @override
  String get anime => 'अ‍ॅनिम';

  @override
  String get liveStreams => 'थेट प्रवाह (Live)';

  @override
  String get debug => 'डीबग';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count एक्सटेंशन्स अपडेट केले',
      one: '1 एक्सटेंशन अपडेट केले',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => 'अवैध नेव्हिगेशन. कृपया परत जा.';

  @override
  String get startOver => 'पुन्हा सुरू करा';

  @override
  String get goBack => 'परत जा';

  @override
  String get restartApp => 'ॲप रीस्टार्ट करा';

  @override
  String get resolving => 'सोडवत आहे...';

  @override
  String get downloaded => 'डाउनलोड केले';

  @override
  String get download => 'डाउनलोड';

  @override
  String get debugOnlyFeature =>
      'हे वैशिष्ट्य केवळ डीबग बिल्ड्समध्ये उपलब्ध आहे';

  @override
  String get streamUrl => 'स्ट्रीम URL';

  @override
  String get play => 'सुरू करा';

  @override
  String get verifyingSourceSize => 'स्रोत आणि आकार सत्यापित करत आहे...';

  @override
  String get fileSaveLocationNotification =>
      'फाइल तुमच्या डाउनलोड्स फोल्डरमध्ये जतन केली जाईल.';

  @override
  String get resumingPlayback => 'पुन्हा सुरू होत आहे';

  @override
  String pausedAt(String time) {
    return '$time वर थांबवले';
  }

  @override
  String resumesAutomatically(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सेकंदात आपोआप सुरू होईल',
      one: '1 सेकंदात आपोआप सुरू होईल',
    );
    return '$_temp0';
  }

  @override
  String get resumeNow => 'आत्ता सुरू करा';

  @override
  String get playbackError => 'प्लेबॅक त्रुटी';

  @override
  String get confirmClearHistory =>
      'तुम्हाला खात्री आहे की तुम्ही इतिहासामधून सर्व आयटम हटवू इच्छिता?';

  @override
  String seasonWithNumber(Object number) {
    return 'सीझन $number';
  }

  @override
  String get starting => 'सुरू होत आहे...';

  @override
  String percentWatched(int percent) {
    return '$percent% पाहिले';
  }

  @override
  String get sub => 'सब';

  @override
  String get dub => 'डब';

  @override
  String playEpisode(String label, Object season, Object episode) {
    return '$label S$season E$episode';
  }

  @override
  String playEpisodeOnly(String label, int episode) {
    return '$label E$episode';
  }

  @override
  String get debugTools => 'डीबग टूल्स';

  @override
  String get playLocalVideo => 'स्थानिक व्हिडिओ फाइल सुरू करा';

  @override
  String get playLocalVideoSubtitle => 'साधनावरील कोणताही व्हिडिओ सुरू करा';

  @override
  String get streamUrlSubtitle => 'नेटवर्क URL वरून सुरू करा';

  @override
  String get streamTorrent => 'टॉरेंट स्ट्रीम करा';

  @override
  String get streamTorrentSubtitle =>
      'सुरू करण्यासाठी स्थानिक टॉरेंट फाइल निवडा';

  @override
  String get loadPluginFromAssets => 'अ‍ॅसेट्समधून प्लगइन लोड करा';

  @override
  String get enterVideoUrlHint => 'व्हिडिओ URL प्रविष्ट करा (http, magnet इ.)';

  @override
  String get networkStream => 'नेटवर्क स्ट्रीम';

  @override
  String removedFromHistory(String title) {
    return 'इतिहासामधून $title हटवले';
  }

  @override
  String get custom => 'सानुकूल';

  @override
  String get refreshingLiveStream => 'थेट प्रवाह रिफ्रेश होत आहे...';

  @override
  String get removeFromHistory => 'इतिहासामधून हटवा';

  @override
  String get live => 'थेट';

  @override
  String get volume => 'आवाज';

  @override
  String get decrease => 'Decrease';

  @override
  String get increase => 'Increase';

  @override
  String get brightness => 'ब्राइटनेस';

  @override
  String get fit => 'फिट';

  @override
  String get zoom => 'झूम';

  @override
  String get stretch => 'खेचा';

  @override
  String titleWithParam(String title) {
    return 'शीर्षक: $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'स्रोत: $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'आकार: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'त्रुटी: $error. अंतर्गत प्लेअर वापरला जात आहे.';
  }

  @override
  String externalPlayerCannotSendHeaders(String playerName, String headers) {
    return '$playerName cannot send $headers. Using internal player.';
  }

  @override
  String playerNotDetected(String playerName) {
    return '$playerName आढळला नाही. अंतर्गत प्लेअर सुरू होत आहे.';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return 'सीझन $number ($count भाग)';
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
    return '$playerName साठी स्रोत निवडा';
  }

  @override
  String get noPluginsInstalled => 'कोणतेही प्लगइन्स स्थापित नाहीत';

  @override
  String get noPluginsMessage =>
      'सामग्री ब्राउझ आणि प्रवाहित करण्यासाठी एक्सटेंशन स्थापित करा.';

  @override
  String get goToExtensions => 'एक्सटेंशनवर जा';

  @override
  String get availableSources => 'उपलब्ध स्रोत';

  @override
  String get seasons => 'सीझन';

  @override
  String get episodes => 'भाग';

  @override
  String get selectSourceToPlay =>
      'कृपया पाहण्यासाठी वरील \'उपलब्ध स्रोत\' मधून स्रोत निवडा.';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count भाग',
      one: '1 भाग',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'कोणतेही भाग आढळले नाहीत';

  @override
  String get local => 'स्थानिक';

  @override
  String get remote => 'रिमोट';

  @override
  String get torrent => 'टॉरेंट';

  @override
  String get unlock => 'अनलॉक';

  @override
  String get lock => 'लॉक';

  @override
  String get sources => 'स्रोत';

  @override
  String get tracks => 'ट्रॅक';

  @override
  String get content => 'साहित्य';

  @override
  String get stats => 'आकडेवारी';

  @override
  String get resize => 'आकार बदला';

  @override
  String get next => 'पुढील';

  @override
  String get previous => 'Previous';

  @override
  String get pip => 'PiP';

  @override
  String get rotate => 'फिरवा';

  @override
  String get windowed => 'विंडोड';

  @override
  String get fullscreen => 'पूर्ण स्क्रीन';

  @override
  String get movieDetails => 'चित्रपट तपशील';

  @override
  String get showDetails => 'तपशील पहा';

  @override
  String get tagline => 'टॅगलाईन';

  @override
  String get status => 'स्थिती';

  @override
  String get releaseDate => 'प्रकाशन तारीख';

  @override
  String get firstAirDate => 'पहिली प्रसारण तारीख';

  @override
  String get originalLanguage => 'मूळ भाषा';

  @override
  String get originCountry => 'मूळ देश';

  @override
  String get budgetLabel => 'बजेट';

  @override
  String get revenueLabel => 'उत्पन्न';

  @override
  String get paused => 'थांबवले';

  @override
  String get watched => 'पाहिले';

  @override
  String get watching => 'पाहत आहे';

  @override
  String get lastWatched => 'शेवटी पाहिलेले';

  @override
  String get movie => 'चित्रपट';

  @override
  String get tvShow => 'टीव्ही शो';

  @override
  String get failedToLoadContent => 'साहित्य लोड करण्यात अयशस्वी';

  @override
  String get director => 'दिग्दर्शक';

  @override
  String get creator => 'निर्माता';

  @override
  String get showMore => 'अधिक पहा';

  @override
  String get showLess => 'कमी पहा';

  @override
  String get viewAll => 'सर्व पहा';

  @override
  String seasonsCount(int count) {
    return '$count सीझन';
  }

  @override
  String get noInternetError => 'इंटरनेट कनेक्शन नाही';

  @override
  String get timeoutError => 'वेळ संपली. कृपया पुन्हा प्रयत्न करा.';

  @override
  String get serverError => 'सर्व्हर त्रुटी. कृपया थोड्या वेळाने प्रयत्न करा.';

  @override
  String get contentNotFoundError => 'साहित्य सापडले नाही.';

  @override
  String get accessDeniedError => 'प्रवेश नाकारला. तुमची माहिती तपासा.';

  @override
  String get serviceUnavailableError => 'सर्व्हर अनुपलब्ध आहे.';

  @override
  String get generalError => 'काहीतरी चूक झाली आहे.';

  @override
  String get skip => 'वगळा';

  @override
  String get skipIntro => 'प्रस्तावना वगळा';

  @override
  String get skipOutro => 'शेवट वगळा';

  @override
  String get skipRecap => 'सारांश वगळा';

  @override
  String get goLive => 'थेट सुरू करा';

  @override
  String get dismiss => 'काढून टाका';

  @override
  String get nextUp => 'पुढील';

  @override
  String sourceAttempt(int index, int total) {
    return '$total पैकी $index स्रोत';
  }

  @override
  String get trying => 'प्रयत्न करत आहे';

  @override
  String get failed => 'अयशस्वी';

  @override
  String get selected => 'निवडले';

  @override
  String get playing => 'सुरू आहे';

  @override
  String get pending => 'प्रलंबित';

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
  String get mobileQualityPreference => 'मोबाईल गुणवत्ता प्राधान्य';

  @override
  String get anyNoPreference => 'काहीही प्राधान्य नाही';

  @override
  String get subtitleAccounts => 'उपशीर्षक खाती';

  @override
  String get accounts => 'खाती';

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
  String get testConnection => 'कनेक्शन तपासा';

  @override
  String get connectedSuccessfully => 'यशस्वीरित्या जोडले गेले';

  @override
  String get connectionFailed => 'कनेक्शन अयशस्वी';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get noAccountRegister => 'Don\'t have an account? Register here';

  @override
  String get apiKey => 'API की';

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
  String get diagnostics => 'निदान (Diagnostics)';

  @override
  String get viewLogs => 'लॉग पहा';

  @override
  String get viewLogsSubtitle => 'अनुप्रयोग क्रियाकलाप आणि त्रुटी पहा';

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
  String get showPlaybackSpeed => 'Playback speed button';

  @override
  String get showEpisodes => 'Episodes button';

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
      'The engine draws subtitles, so it is handed these when playback starts — a change applies to the next video.';

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
  String get sourcesSearching => 'स्क्रॅपर शोधत आहे…';

  @override
  String get sourcesEmptyFiltered =>
      'सध्याच्या फिल्टरशी कोणतीही लिंक जुळत नाही.';

  @override
  String get sourcesEmptyNoTmdbId =>
      'या शीर्षकाची TMDB ID नाही. \'Search manually\' वापरून टाका.';

  @override
  String get sourcesEmptyNoScrapers =>
      'कोणताही स्क्रॅपर सुरू नाही. \'Nuvio Plugins\' मध्ये एक जोडा.';

  @override
  String get sourcesEmptyAllFailed =>
      'सर्व स्क्रॅपर अयशस्वी झाले. तुमचे कनेक्शन तपासा किंवा स्क्रॅपर अपडेट करा.';

  @override
  String sourcesEmptySomeFailed(int failed, int total) {
    return 'कोणतीही लिंक सापडली नाही. $total पैकी $failed स्क्रॅपर अयशस्वी.';
  }

  @override
  String get sourcesEmptyNothingFound =>
      'तुमच्या कोणत्याही स्क्रॅपरकडे हे शीर्षक नाही.';

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
}
