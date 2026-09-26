// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => 'বাংলা';

  @override
  String get addonHealthChecking => 'Checking add-on…';

  @override
  String addonHealthWorking(int ms) {
    return 'Working · $ms ms';
  }

  @override
  String get addonHealthUnavailable => 'Unavailable';

  @override
  String get home => 'হোম';

  @override
  String get search => 'অনুসন্ধান';

  @override
  String get explore => 'অন্বেষণ করুন';

  @override
  String get exploreAnime => 'অ্যানিমে অন্বেষণ';

  @override
  String get exploreMovies => 'সিনেমা অন্বেষণ';

  @override
  String get library => 'লাইব্রেরি';

  @override
  String get settings => 'সেটিংস';

  @override
  String get extensions => 'এক্সটেনশন';

  @override
  String get updateAvailable => 'আপডেট উপলব্ধ';

  @override
  String get retry => 'পুনরায় চেষ্টা করুন';

  @override
  String get factoryReset => 'ফ্যাক্টরি রিসেট';

  @override
  String get startupError => 'স্টার্টআপ ত্রুটি';

  @override
  String get general => 'সাধারণ';

  @override
  String get appTheme => 'অ্যাপ থিম';

  @override
  String get recordWatchHistory => 'দেখার ইতিহাস রেকর্ড করুন';

  @override
  String get fullScreenMode => 'ফুল স্ক্রিন';

  @override
  String get fullScreenModeSubtitle => 'টিভি লেআউটে পরিবর্তন করে';

  @override
  String get defaultHomeScreen => 'ডিফল্ট হোম স্ক্রিন';

  @override
  String get titlePosition => 'শিরোনামের অবস্থান';

  @override
  String get titlePositionBelowPoster => 'পোস্টারের নিচে';

  @override
  String get titlePositionInsidePoster => 'পোস্টারের ভিতরে';

  @override
  String get player => 'প্লেয়ার';

  @override
  String get defaultPlayer => 'ডিফল্ট প্লেয়ার';

  @override
  String get leftGesture => 'বাম জেসচার';

  @override
  String get rightGesture => 'ডান জেসচার';

  @override
  String get doubleTapToSeek => 'খুঁজতে ডবল ট্যাপ করুন';

  @override
  String get swipeToSeek => 'খুঁজতে সোয়াইপ করুন';

  @override
  String get seekDuration => 'সিক ডিউরেশন';

  @override
  String get defaultResizeMode => 'ডিফল্ট রিসাইজ মোড';

  @override
  String get hardwareDecoding => 'হার্ডওয়্যার ডিকোডিং';

  @override
  String get network => 'নেটওয়ার্ক';

  @override
  String get dnsOverHttps => 'DNS ওভার HTTPS';

  @override
  String get dohProvider => 'DoH প্রদানকারী';

  @override
  String get githubProxy => 'GitHub প্রক্সি';

  @override
  String get githubProxySubtitle =>
      'ISP ব্লক এড়াতে এক্সটেনশন ডাউনলোড jsDelivr-এর মাধ্যমে পাঠান।';

  @override
  String get manageExtensions => 'এক্সটেনশন পরিচালনা করুন';

  @override
  String get appData => 'অ্যাপ তথ্য';

  @override
  String get resetDataKeepExtensions => 'তথ্য রিসেট করুন (এক্সটেনশন রাখুন)';

  @override
  String get developer => 'ডেভেলপার';

  @override
  String get developerOptions => 'ডেভেলপার অপশন';

  @override
  String get about => 'সম্পর্কে';

  @override
  String get version => 'ভার্সন';

  @override
  String get enabled => 'সক্ষম';

  @override
  String get disabled => 'অক্ষম';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'আমাদের সার্ভারে যোগ দিন';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'আমাদের চ্যানেলে যোগ দিন';

  @override
  String developedBy(String name) {
    return '$name দ্বারা তৈরী';
  }

  @override
  String get system => 'সিস্টেম';

  @override
  String get dark => 'ডার্ক';

  @override
  String get light => 'লাইট';

  @override
  String get later => 'পরে';

  @override
  String get updateNow => 'এখনই আপডেট করুন';

  @override
  String get save => 'সংরক্ষণ করুন';

  @override
  String get cancel => 'বাতিল';

  @override
  String get close => 'বন্ধ করুন';

  @override
  String get delete => 'মুছে ফেলুন';

  @override
  String get viewDetails => 'বিস্তারিত দেখুন';

  @override
  String get clearAll => 'সব পরিষ্কার করুন';

  @override
  String get clearAllHistory => 'সব ইতিহাস পরিষ্কার করুন';

  @override
  String get all => 'সব';

  @override
  String get none => 'কিছুই না';

  @override
  String get confirmDownload => 'ডাউনলোড নিশ্চিত করুন';

  @override
  String get downloadNow => 'এখনই ডাউনলোড করুন';

  @override
  String get selectSource => 'উৎস নির্বাচন করুন';

  @override
  String get downloadUnavailable => 'ডাউনলোড উপলব্ধ নয়';

  @override
  String get selectAnotherSource => 'অন্য উৎস নির্বাচন করুন';

  @override
  String get watchHistoryCleared => 'দেখার ইতিহাস পরিষ্কার করা হয়েছে';

  @override
  String get downloadingUpdate => 'আপডেট ডাউনলোড হচ্ছে...';

  @override
  String errorPrefix(String message) {
    return 'ত্রুটি: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'আপডেট উপলব্ধ: $tag';
  }

  @override
  String get selectProviderToStart =>
      'দেখা শুরু করতে একটি প্রদানকারী নির্বাচন করুন';

  @override
  String get tapExtensionIcon => 'কোণায় এক্সটেনশন আইকনে ট্যাপ করুন';

  @override
  String get continueWatching => 'দেখা চালিয়ে যান';

  @override
  String get noInternetConnection => 'কোন ইন্টারনেট সংযোগ নেই';

  @override
  String get siteNotReachable => 'সাইটে পৌঁছানো যাচ্ছে না';

  @override
  String get checkConnectionOrDownloads =>
      'আপনার সংযোগ পরীক্ষা করুন বা আপনার ডাউনলোড করা সামগ্রী দেখুন।';

  @override
  String get tryVpnOrConnection =>
      'দয়া করে VPN দিয়ে সাইটে প্রবেশের চেষ্টা করুন বা আপনার ইন্টারনেট সংযোগ পরীক্ষা করুন।';

  @override
  String errorDetails(String error) {
    return 'ত্রুটির বিবরণ: $error';
  }

  @override
  String get goToDownloads => 'ডাউনলোডে যান';

  @override
  String get selectProvider => 'প্রদানকারী নির্বাচন করুন';

  @override
  String get searchHint => 'সিনেমা, সিরিজ অনুসন্ধান করুন...';

  @override
  String get searchFavoriteContent => 'আপনার প্রিয় কন্টেন্ট অনুসন্ধান করুন';

  @override
  String get pressSearchOrEnter => 'শুরু করতে সার্চ কী বা এন্টার টিপুন';

  @override
  String get recentSearches => 'Recent searches';

  @override
  String removeFromSearchHistory(String query) {
    return 'Remove $query from search history';
  }

  @override
  String get noResultsFound => 'কোন ফলাফল পাওয়া যায়নি।';

  @override
  String get couldNotLoadTrending => 'ট্রেন্ডিং আইটেম লোড করা যায়নি';

  @override
  String get popularMovies => 'জনপ্রিয় সিনেমা';

  @override
  String get popularTVShows => 'জনপ্রিয় টিভি শো';

  @override
  String get newMovies => 'নতুন সিনেমা';

  @override
  String get newTVShows => 'নতুন টিভি শো';

  @override
  String get featuredMovies => 'ফিচারড সিনেমা';

  @override
  String get featuredTVShows => 'ফিচারড টিভি শো';

  @override
  String get lastVideosTVShows => 'সর্বশেষ টিভি শো';

  @override
  String get downloads => 'ডাউনলোড';

  @override
  String get bookmarks => 'বুকমার্ক';

  @override
  String get noDownloadsYet => 'এখনো কোনো ডাউনলোড নেই';

  @override
  String episodesCount(int count, int done) {
    return '$count টি পর্ব • $done টি সম্পন্ন';
  }

  @override
  String get deleteAllEpisodes => 'সব পর্ব মুছে ফেলুন';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return 'আপনি কি নিশ্চিত যে আপনি \"$title\" এর সমস্ত $count টি পর্ব এবং তাদের ফাইল মুছে ফেলতে চান?';
  }

  @override
  String get deleteAll => 'সব মুছে ফেলুন';

  @override
  String get completed => 'সম্পন্ন';

  @override
  String get statusQueued => 'কিউতে আছে...';

  @override
  String get statusDownloading => 'ডাউনলোড হচ্ছে...';

  @override
  String get statusFinished => 'শেষ হয়েছে';

  @override
  String get statusFailed => 'ব্যর্থ হয়েছে';

  @override
  String get statusCanceled => 'বাতিল করা হয়েছে';

  @override
  String get statusPaused => 'বিরতি দেওয়া হয়েছে';

  @override
  String get statusWaiting => 'অপেক্ষা করছে...';

  @override
  String get fileNotFoundRemoving =>
      'ফাইল ডিস্কে পাওয়া যায়নি। রেকর্ড মুছে ফেলা হচ্ছে।';

  @override
  String get fileNotFound => 'ফাইল পাওয়া যায়নি';

  @override
  String get deleteDownload => 'ডাউনলোড মুছে ফেলুন';

  @override
  String get confirmDeleteDownload =>
      'আপনি কি নিশ্চিত যে আপনি এই ডাউনলোড এবং এর ফাইলটি মুছে ফেলতে চান?';

  @override
  String get libraryEmpty => 'আপনার লাইব্রেরি খালি';

  @override
  String get language => 'ভাষা';

  @override
  String get english => 'ইংরেজি';

  @override
  String get hindi => 'হিন্দি';

  @override
  String get kannada => 'কানাড়া';

  @override
  String get unknown => 'অজানা';

  @override
  String get recommended => 'প্রস্তাবিত';

  @override
  String get on => 'চালু';

  @override
  String get off => 'বন্ধ';

  @override
  String get installRemoveProviders => 'প্রদানকারী ইনস্টল বা অপসারণ করুন';

  @override
  String get resetDataSubtitle =>
      'সেটিংস এবং ডাটাবেস পরিষ্কার করুন, প্লাগইন রাখুন';

  @override
  String get factoryResetSubtitle =>
      'সমস্ত তথ্য, সেটিংস এবং এক্সটেনশন মুছে ফেলুন';

  @override
  String get developerOptionsSubtitle => 'ডিবাগ সরঞ্জাম এবং স্থানীয় প্লেব্যাক';

  @override
  String get loading => 'লোড হচ্ছে...';

  @override
  String get sec => 'সেকেন্ড';

  @override
  String get min => 'মিনিট';

  @override
  String playerRewindSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count সেকেন্ড পিছিয়ে যান',
      one: '1 সেকেন্ড পিছিয়ে যান',
    );
    return '$_temp0';
  }

  @override
  String playerForwardSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count সেকেন্ড এগিয়ে যান',
      one: '1 সেকেন্ড এগিয়ে যান',
    );
    return '$_temp0';
  }

  @override
  String get internalPlayer => 'অভ্যন্তরীণ প্লেয়ার (VLC)';

  @override
  String get builtInPlayer => 'বিল্ট-ইন প্লেয়ার';

  @override
  String get customNotSet => 'কাস্টম (সেট করা নেই)';

  @override
  String selectGesture(String side) {
    return '$side জেসচার নির্বাচন করুন';
  }

  @override
  String get left => 'বাম';

  @override
  String get right => 'ডান';

  @override
  String get selectSeekDuration => 'সিক ডিউরেশন নির্বাচন করুন';

  @override
  String get subtitleSettings => 'সাবটাইটেল সেটিংস';

  @override
  String size(int size) {
    return 'সাইজ: $size';
  }

  @override
  String get background => 'ব্যাকগ্রাউন্ড';

  @override
  String get customDohUrlLabel => 'কাস্টম DoH URL';

  @override
  String get enterCustomDohUrl => 'আপনার নিজস্ব DoH URL লিখুন';

  @override
  String get chooseTheme => 'থিম নির্বাচন করুন';

  @override
  String get resetDataDialogTitle => 'তথ্য রিসেট করবেন?';

  @override
  String get resetDataDialogContent =>
      'এটি সেটিংস, প্রিয় এবং ইতিহাস পরিষ্কার করবে। আপনার ইনস্টল করা এক্সটেনশনগুলি মুছে ফেলা হবে না।';

  @override
  String get factoryResetDialogTitle => 'ফ্যাক্টরি রিসেট করবেন?';

  @override
  String get factoryResetDialogContent =>
      'এটি সবকিছু মুছে ফেলবে: প্রিয়, ইতিহাস, সেটিংস এবং সমস্ত এক্সটেনশন। এটি পূর্বাবস্থায় ফেরানো যাবে না।';

  @override
  String get selectLanguage => 'ভাষা নির্বাচন করুন';

  @override
  String get synopsis => 'সারসংক্ষেপ';

  @override
  String get noDescription => 'কোন বিবরণ উপলব্ধ নেই।';

  @override
  String get videoAlreadyDownloadedPrompt =>
      'এই ভিডিওটি ইতিমধ্যে ডাউনলোড করা হয়েছে। আপনি কি করতে চান?';

  @override
  String get playNow => 'এখনই চালান';

  @override
  String get upNext => 'এরপরে';

  @override
  String get deleteDownloadPrompt => 'ডাউনলোড মুছে ফেলবেন?';

  @override
  String get deleteDownloadConfirmation =>
      'আপনি কি নিশ্চিত যে আপনি এই ফাইলটি মুছে ফেলতে চান? এটি পূর্বাবস্থায় ফেরানো যাবে না।';

  @override
  String get no => 'না';

  @override
  String get yesDelete => 'হ্যাঁ, মুছে ফেলুন';

  @override
  String get downloadPaused => 'ডাউনলোড স্থগিত';

  @override
  String get downloading => 'ডাউনলোড হচ্ছে';

  @override
  String get speed => 'গতি';

  @override
  String get remaining => 'অবশিষ্ট';

  @override
  String get resume => 'পুনরায় শুরু করুন';

  @override
  String get pause => 'বিরতি';

  @override
  String get torrentContent => 'টরেন্ট কন্টেন্ট';

  @override
  String get audioTracks => 'অডিও ট্র্যাক';

  @override
  String get noAudioTracks => 'কোন অডিও ট্র্যাক পাওয়া যায়নি';

  @override
  String get subtitles => 'সাবটাইটেল';

  @override
  String get options => 'বিকল্প';

  @override
  String get noSubtitlesFound => 'কোন সাবটাইটেল ট্র্যাক পাওয়া যায়নি';

  @override
  String get playbackSpeed => 'প্লেব্যাক স্পিড';

  @override
  String get subtitleOptions => 'সাবটাইটেল বিকল্প';

  @override
  String get hlsSubtitleWarning =>
      'এই প্ল্যাটফর্মে সক্রিয় HLS প্লেয়ারে বাহ্যিক সাবটাইটেল ফাইল সমর্থিত নয়।';

  @override
  String get loadFromDevice => 'ডিভাইস থেকে লোড করুন';

  @override
  String get syncDelay => 'সিঙ্ক / বিলম্ব';

  @override
  String get styleSettings => 'স্টাইল সেটিংস';

  @override
  String get searchOnline => 'অনলাইনে অনুসন্ধান করুন (সাবটাইটেল অনুসন্ধান)';

  @override
  String get subtitleSync => 'সাবটাইটেল সিঙ্ক';

  @override
  String get subtitleDelayWarning =>
      'সক্রিয় প্লেব্যাক ইঞ্জিন দ্বারা সাবটাইটেল বিলম্ব সমর্থিত নয়।';

  @override
  String get resetDelay => 'বিলম্ব রিসেট করুন';

  @override
  String get subtitleStyles => 'সাবটাইটেল স্টাইল';

  @override
  String get resetToDefault => 'ডিফল্টে রিসেট করুন';

  @override
  String get fontSize => 'ফন্ট সাইজ';

  @override
  String get verticalPosition => 'উল্লম্ব অবস্থান';

  @override
  String get textColor => 'টেক্সট কালার';

  @override
  String get backgroundColor => 'ব্যাকগ্রাউন্ড কালার';

  @override
  String get backgroundOpacity => 'ব্যাকগ্রাউন্ড অপাসিটি';

  @override
  String get subtitleSearch => 'সাবটাইটেল অনুসন্ধান';

  @override
  String get searchSubtitleNameHint => 'সাবটাইটেল নাম অনুসন্ধান করুন...';

  @override
  String get enterSearchSubtitlePrompt =>
      'সাবটাইটেল খুঁজে পেতে একটি নাম লিখুন বা অনুসন্ধান করুন।';

  @override
  String get noSubtitleResults =>
      'কোন ফলাফল পাওয়া যায়নি। অন্য একটি অনুসন্ধান চেষ্টা করুন।';

  @override
  String get downloadingApplyingSubtitle =>
      'সাবটাইটেল ডাউনলোড এবং প্রয়োগ করা হচ্ছে...';

  @override
  String get failedToDownloadSubtitle =>
      'সাবটাইটেল ডাউনলোড করতে ব্যর্থ হয়েছে।';

  @override
  String get failedToLoadSubtitles =>
      'সাবটাইটেল লোড করতে ব্যর্থ হয়েছে। দয়া করে পুনরায় চেষ্টা করুন।';

  @override
  String get noReposFound => 'কোন রিপোজিটরি বা প্লাগইন পাওয়া যায়নি';

  @override
  String get downloadAllProviders => 'সব ডাউনলোড করুন';

  @override
  String get removeRepository => 'রিপোজিটরি সরান';

  @override
  String get addRepo => 'রিপো যোগ করুন';

  @override
  String get extensionsNotInRepos => 'রিপোজিটরিতে নেই এমন এক্সটেনশন';

  @override
  String get noLongerInRepo => 'আর কোনো রিপোজিটরিতে তালিকাভুক্ত নেই';

  @override
  String get addRepoToBrowse =>
      'প্লাগইন ব্রাউজ এবং আপডেট করতে একটি রিপোজিটরি যোগ করুন';

  @override
  String get debugExtensions => 'ডিবাগ এক্সটেনশন';

  @override
  String removeRepoConfirm(String repoName) {
    return '$repoName সরাবেন?';
  }

  @override
  String get removeRepoWarning =>
      'এটি রিপোজিটরি সরিয়ে দেবে এবং এর সমস্ত প্লাগইন আনইনস্টল করবে।';

  @override
  String get addRepository => 'রিপোজিটরি যোগ করুন';

  @override
  String get repoUrlOrShortcode => 'রিপোজিটরি URL বা শর্টকোড';

  @override
  String get assetPlugin => 'অ্যাসেট প্লাগইন';

  @override
  String get installed => 'ইনস্টল করা';

  @override
  String get repositories => 'রিপোজিটরি';

  @override
  String get noExtensionsInstalled => 'কোনো এক্সটেনশন ইনস্টল করা নেই';

  @override
  String get browseRepositoriesToInstall =>
      'এক্সটেনশন খুঁজে ইনস্টল করতে রিপোজিটরি ট্যাব দেখুন।';

  @override
  String get browseRepositories => 'রিপোজিটরি ব্রাউজ করুন';

  @override
  String get addRepoDescription =>
      'এক্সটেনশন প্লাগইন খুঁজে ইনস্টল করতে একটি রিপোজিটরি URL বা শর্টকোড যোগ করুন।';

  @override
  String updateTo(String version) {
    return '$version-এ আপডেট করুন';
  }

  @override
  String get install => 'ইনস্টল করুন';

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
  String get error => 'ত্রুটি';

  @override
  String get ok => 'ঠিক আছে';

  @override
  String pluginSettings(String pluginName) {
    return '$pluginName সেটিংস';
  }

  @override
  String get movies => 'সিনেমা';

  @override
  String get series => 'সিরিজ';

  @override
  String get anime => 'অ্যানিমে';

  @override
  String get liveStreams => 'লাইভ স্ট্রিম';

  @override
  String get debug => 'ডিবাগ';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি এক্সটেনশন আপডেট করা হয়েছে',
      one: '১টি এক্সটেনশন আপডেট করা হয়েছে',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => 'অকার্যকর নেভিগেশন। দয়া করে ফিরে যান।';

  @override
  String get startOver => 'আবার শুরু করুন';

  @override
  String get goBack => 'ফিরে যান';

  @override
  String get restartApp => 'অ্যাপ রিস্টার্ট করুন';

  @override
  String get resolving => 'সমাধান করা হচ্ছে...';

  @override
  String get downloaded => 'ডাউনলোড করা হয়েছে';

  @override
  String get download => 'ডাউনলোড';

  @override
  String get debugOnlyFeature => 'এই বৈশিষ্ট্যটি শুধুমাত্র ডিবাগ বিল্ডে উপলব্ধ';

  @override
  String get streamUrl => 'স্ট্রিম URL';

  @override
  String get play => 'চালান';

  @override
  String get verifyingSourceSize => 'উৎস এবং সাইজ যাচাই করা হচ্ছে...';

  @override
  String get fileSaveLocationNotification =>
      'ফাইলটি আপনার ডাউনলোড ফোল্ডারে সংরক্ষিত হবে।';

  @override
  String get resumingPlayback => 'প্লেব্যাক পুনরায় শুরু হচ্ছে';

  @override
  String pausedAt(String time) {
    return '$time-এ বিরতি দেওয়া হয়েছে';
  }

  @override
  String resumesAutomatically(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count সেকেন্ডের মধ্যে স্বয়ংক্রিয়ভাবে শুরু হবে',
      one: '১ সেকেন্ডের মধ্যে স্বয়ংক্রিয়ভাবে শুরু হবে',
    );
    return '$_temp0';
  }

  @override
  String get resumeNow => 'এখনই শুরু করুন';

  @override
  String get playbackError => 'প্লেব্যাক ত্রুটি';

  @override
  String get confirmClearHistory =>
      'আপনি কি নিশ্চিত যে আপনি আপনার দেখার ইতিহাস থেকে সমস্ত আইটেম সরাতে চান?';

  @override
  String seasonWithNumber(Object number) {
    return 'সিজন $number';
  }

  @override
  String get starting => 'শুরু হচ্ছে...';

  @override
  String percentWatched(int percent) {
    return '$percent% দেখা হয়েছে';
  }

  @override
  String get sub => 'সাব';

  @override
  String get dub => 'ডাব';

  @override
  String playEpisode(String label, Object season, Object episode) {
    return '$label S$season E$episode';
  }

  @override
  String playEpisodeOnly(String label, int episode) {
    return '$label E$episode';
  }

  @override
  String get debugTools => 'ডিবাগ সরঞ্জাম';

  @override
  String get playLocalVideo => 'স্থানীয় ভিডিও ফাইল চালান';

  @override
  String get playLocalVideoSubtitle => 'ডিভাইস থেকে যেকোনো ভিডিও চালান';

  @override
  String get streamUrlSubtitle => 'নেটওয়ার্ক URL থেকে চালান';

  @override
  String get streamTorrent => 'টরেন্ট স্ট্রিম করুন';

  @override
  String get streamTorrentSubtitle =>
      'চালানোর জন্য একটি স্থানীয় টরেন্ট ফাইল নির্বাচন করুন';

  @override
  String get loadPluginFromAssets => 'অ্যাসেট থেকে প্লাগইন লোড করুন';

  @override
  String get enterVideoUrlHint => 'ভিডিও URL লিখুন (http, magnet ইত্যাদি)';

  @override
  String get networkStream => 'নেটওয়ার্ক স্ট্রিম';

  @override
  String removedFromHistory(String title) {
    return 'ইতিহাস থেকে $title সরানো হয়েছে';
  }

  @override
  String get custom => 'কাস্টম';

  @override
  String get refreshingLiveStream => 'লাইভ স্ট্রিম রিফ্রেশ হচ্ছে...';

  @override
  String get removeFromHistory => 'ইতিহাস থেকে সরান';

  @override
  String get live => 'লাইভ';

  @override
  String get volume => 'ভলিউম';

  @override
  String get decrease => 'Decrease';

  @override
  String get increase => 'Increase';

  @override
  String get brightness => 'ব্রাইটনেস';

  @override
  String get fit => 'ফিট';

  @override
  String get zoom => 'জুম';

  @override
  String get stretch => 'স্ট্রেচ';

  @override
  String titleWithParam(String title) {
    return 'শিরোনাম: $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'উৎস: $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'সাইজ: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'ত্রুটি: $error। অভ্যন্তরীণ প্লেয়ার ব্যবহার করা হচ্ছে।';
  }

  @override
  String externalPlayerCannotSendHeaders(String playerName, String headers) {
    return '$playerName cannot send $headers. Using internal player.';
  }

  @override
  String playerNotDetected(String playerName) {
    return '$playerName সনাক্ত করা যায়নি। অভ্যন্তরীণ প্লেয়ার শুরু হচ্ছে।';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return 'সিজন $number ($count টি পর্ব)';
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
    return '$playerName এর জন্য উৎস নির্বাচন করুন';
  }

  @override
  String get noPluginsInstalled => 'কোনো প্লাগইন ইনস্টল করা নেই';

  @override
  String get noPluginsMessage =>
      'কন্টেন্ট ব্রাউজ এবং স্ট্রিম করতে এক্সটেনশন ইনস্টল করুন।';

  @override
  String get goToExtensions => 'এক্সটেনশনে যান';

  @override
  String get availableSources => 'উপলব্ধ উৎস';

  @override
  String get seasons => 'সিজন';

  @override
  String get episodes => 'পর্ব';

  @override
  String get selectSourceToPlay =>
      'চালানোর জন্য উপরে \'উপলব্ধ উৎস\' থেকে একটি উৎস নির্বাচন করুন।';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি পর্ব',
      one: '১টি পর্ব',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'কোনো পর্ব পাওয়া যায়নি';

  @override
  String get local => 'স্থানীয়';

  @override
  String get remote => 'দূরবর্তী';

  @override
  String get torrent => 'টরেন্ট';

  @override
  String get unlock => 'আনলক';

  @override
  String get lock => 'লক';

  @override
  String get sources => 'উৎস';

  @override
  String get tracks => 'ট্র্যাক';

  @override
  String get content => 'কন্টেন্ট';

  @override
  String get stats => 'পরিসংখ্যান';

  @override
  String get resize => 'রিসাইজ';

  @override
  String get next => 'পরবর্তী';

  @override
  String get previous => 'Previous';

  @override
  String get pip => 'PiP';

  @override
  String get rotate => 'ঘোরান';

  @override
  String get windowed => 'উইন্ডোড';

  @override
  String get fullscreen => 'ফুল স্ক্রিন';

  @override
  String get movieDetails => 'সিনেমা বিস্তারিত';

  @override
  String get showDetails => 'বিস্তারিত দেখুন';

  @override
  String get tagline => 'ট্যাগলাইন';

  @override
  String get status => 'অবস্থা';

  @override
  String get releaseDate => 'মুক্তির তারিখ';

  @override
  String get firstAirDate => 'প্রথম সম্প্রচারের তারিখ';

  @override
  String get originalLanguage => 'মূল ভাষা';

  @override
  String get originCountry => 'উৎসের দেশ';

  @override
  String get budgetLabel => 'বাজেট';

  @override
  String get revenueLabel => 'রাজস্ব';

  @override
  String get paused => 'স্থগিত';

  @override
  String get watched => 'দেখা হয়েছে';

  @override
  String get watching => 'দেখছেন';

  @override
  String get lastWatched => 'সর্বশেষ দেখা';

  @override
  String get movie => 'সিনেমা';

  @override
  String get tvShow => 'টিভি শো';

  @override
  String get failedToLoadContent => 'কন্টেন্ট লোড করতে ব্যর্থ হয়েছে';

  @override
  String get director => 'পরিচালক';

  @override
  String get creator => 'স্রষ্টা';

  @override
  String get showMore => 'আরও দেখুন';

  @override
  String get showLess => 'কম দেখুন';

  @override
  String get viewAll => 'সব দেখুন';

  @override
  String seasonsCount(int count) {
    return '$count টি সিজন';
  }

  @override
  String get noInternetError => 'কোন ইন্টারনেট সংযোগ নেই';

  @override
  String get timeoutError => 'অনুরোধের সময় শেষ। দয়া করে পুনরায় চেষ্টা করুন।';

  @override
  String get serverError => 'সার্ভার ত্রুটি। দয়া করে পরে আবার চেষ্টা করুন।';

  @override
  String get contentNotFoundError => 'কন্টেন্ট পাওয়া যায়নি।';

  @override
  String get accessDeniedError =>
      'প্রবেশাধিকার অস্বীকার করা হয়েছে। আপনার শংসাপত্রগুলি পরীক্ষা করুন।';

  @override
  String get serviceUnavailableError =>
      'সার্ভার উপলব্ধ নেই। পরে আবার চেষ্টা করুন।';

  @override
  String get generalError => 'কিছু ভুল হয়েছে। দয়া করে আবার চেষ্টা করুন।';

  @override
  String get skip => 'এড়িয়ে যান';

  @override
  String get skipIntro => 'ইন্ট্রো এড়িয়ে যান';

  @override
  String get skipOutro => 'আউট্রো এড়িয়ে যান';

  @override
  String get skipRecap => 'রিক্যাপ এড়িয়ে যান';

  @override
  String get goLive => 'লাইভে যান';

  @override
  String get dismiss => 'বাতিল করুন';

  @override
  String get nextUp => 'পরবর্তী';

  @override
  String sourceAttempt(int index, int total) {
    return '$total এর মধ্যে $index উৎস';
  }

  @override
  String get trying => 'চেষ্টা করা হচ্ছে';

  @override
  String get failed => 'ব্যর্থ';

  @override
  String get selected => 'নির্বাচিত';

  @override
  String get playing => 'চলছে';

  @override
  String get pending => 'অপেক্ষমান';

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
  String get mobileQualityPreference => 'মোবাইল ডেটা মানের পছন্দ';

  @override
  String get anyNoPreference => 'যেকোনো (কোনো পছন্দ নেই)';

  @override
  String get subtitleAccounts => 'সাবটাইটেল অ্যাকাউন্ট';

  @override
  String get accounts => 'অ্যাকাউন্ট';

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
  String get testConnection => 'সংযোগ পরীক্ষা করুন';

  @override
  String get connectedSuccessfully => 'সফলভাবে সংযুক্ত';

  @override
  String get connectionFailed => 'সংযোগ ব্যর্থ হয়েছে';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get noAccountRegister => 'Don\'t have an account? Register here';

  @override
  String get apiKey => 'API কী';

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
  String get diagnostics => 'ডায়াগনস্টিকস';

  @override
  String get viewLogs => 'লগ দেখুন';

  @override
  String get viewLogsSubtitle => 'অ্যাপ্লিকেশন কার্যকলাপ এবং ত্রুটি দেখুন';

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
  String get sourcesSearching => 'স্ক্র্যাপার খোঁজা হচ্ছে…';

  @override
  String get sourcesEmptyFiltered =>
      'বর্তমান ফিল্টারের সাথে কোনো লিঙ্ক মেলেনি।';

  @override
  String get sourcesEmptyNoTmdbId =>
      'এই শিরোনামের TMDB আইডি নেই। \'Search manually\' দিয়ে একটি দিন।';

  @override
  String get sourcesEmptyNoScrapers =>
      'কোনো স্ক্র্যাপার চালু নেই। \'Nuvio Plugins\'-এ একটি যোগ করুন।';

  @override
  String get sourcesEmptyAllFailed =>
      'সব স্ক্র্যাপার ব্যর্থ হয়েছে। সংযোগ দেখুন বা স্ক্র্যাপার আপডেট করুন।';

  @override
  String sourcesEmptySomeFailed(int failed, int total) {
    return 'কোনো লিঙ্ক পাওয়া যায়নি। $totalটির মধ্যে $failedটি স্ক্র্যাপার ব্যর্থ।';
  }

  @override
  String get sourcesEmptyNothingFound =>
      'আপনার কোনো স্ক্র্যাপারে এই শিরোনাম নেই।';

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
