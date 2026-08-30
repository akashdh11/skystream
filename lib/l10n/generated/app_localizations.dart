import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_as.dart';
import 'app_localizations_be.dart';
import 'app_localizations_bg.dart';
import 'app_localizations_bn.dart';
import 'app_localizations_cs.dart';
import 'app_localizations_de.dart';
import 'app_localizations_el.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_gu.dart';
import 'app_localizations_he.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_hr.dart';
import 'app_localizations_hu.dart';
import 'app_localizations_id.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_kn.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_lv.dart';
import 'app_localizations_mk.dart';
import 'app_localizations_ml.dart';
import 'app_localizations_mr.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_pa.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ro.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_sv.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_uk.dart';
import 'app_localizations_ur.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('ar', 'apc'),
    Locale('as'),
    Locale('be'),
    Locale('bg'),
    Locale('bn'),
    Locale('cs'),
    Locale('de'),
    Locale('el'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('gu'),
    Locale('he'),
    Locale('hi'),
    Locale('hr'),
    Locale('hu'),
    Locale('id'),
    Locale('it'),
    Locale('ja'),
    Locale('kn'),
    Locale('ko'),
    Locale('lv'),
    Locale('mk'),
    Locale('ml'),
    Locale('mr'),
    Locale('nl'),
    Locale('pa'),
    Locale('pl'),
    Locale('pt'),
    Locale('pt', 'BR'),
    Locale('ro'),
    Locale('ru'),
    Locale('sv'),
    Locale('ta'),
    Locale('te'),
    Locale('tr'),
    Locale('uk'),
    Locale('ur'),
    Locale('vi'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'SkyStream'**
  String get appTitle;

  /// No description provided for @languageName.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageName;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// No description provided for @exploreAnime.
  ///
  /// In en, this message translates to:
  /// **'Explore Anime'**
  String get exploreAnime;

  /// No description provided for @exploreMovies.
  ///
  /// In en, this message translates to:
  /// **'Explore Movies'**
  String get exploreMovies;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @extensions.
  ///
  /// In en, this message translates to:
  /// **'Extensions'**
  String get extensions;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update Available'**
  String get updateAvailable;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @factoryReset.
  ///
  /// In en, this message translates to:
  /// **'Factory Reset'**
  String get factoryReset;

  /// No description provided for @startupError.
  ///
  /// In en, this message translates to:
  /// **'Startup Error'**
  String get startupError;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @appTheme.
  ///
  /// In en, this message translates to:
  /// **'App Theme'**
  String get appTheme;

  /// No description provided for @recordWatchHistory.
  ///
  /// In en, this message translates to:
  /// **'Record Watch History'**
  String get recordWatchHistory;

  /// No description provided for @defaultHomeScreen.
  ///
  /// In en, this message translates to:
  /// **'Default Home Screen'**
  String get defaultHomeScreen;

  /// No description provided for @titlePosition.
  ///
  /// In en, this message translates to:
  /// **'Title Position'**
  String get titlePosition;

  /// No description provided for @titlePositionBelowPoster.
  ///
  /// In en, this message translates to:
  /// **'Below Poster'**
  String get titlePositionBelowPoster;

  /// No description provided for @titlePositionInsidePoster.
  ///
  /// In en, this message translates to:
  /// **'Inside Poster'**
  String get titlePositionInsidePoster;

  /// No description provided for @player.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get player;

  /// No description provided for @defaultPlayer.
  ///
  /// In en, this message translates to:
  /// **'Default Player'**
  String get defaultPlayer;

  /// No description provided for @leftGesture.
  ///
  /// In en, this message translates to:
  /// **'Left Gesture'**
  String get leftGesture;

  /// No description provided for @rightGesture.
  ///
  /// In en, this message translates to:
  /// **'Right Gesture'**
  String get rightGesture;

  /// No description provided for @doubleTapToSeek.
  ///
  /// In en, this message translates to:
  /// **'Double Tap to Seek'**
  String get doubleTapToSeek;

  /// No description provided for @swipeToSeek.
  ///
  /// In en, this message translates to:
  /// **'Swipe to Seek'**
  String get swipeToSeek;

  /// No description provided for @seekDuration.
  ///
  /// In en, this message translates to:
  /// **'Seek Duration'**
  String get seekDuration;

  /// No description provided for @bufferDepth.
  ///
  /// In en, this message translates to:
  /// **'Buffer depth'**
  String get bufferDepth;

  /// No description provided for @defaultResizeMode.
  ///
  /// In en, this message translates to:
  /// **'Default Resize Mode'**
  String get defaultResizeMode;

  /// No description provided for @hardwareDecoding.
  ///
  /// In en, this message translates to:
  /// **'Hardware Decoding'**
  String get hardwareDecoding;

  /// No description provided for @network.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get network;

  /// No description provided for @dnsOverHttps.
  ///
  /// In en, this message translates to:
  /// **'DNS over HTTPS'**
  String get dnsOverHttps;

  /// No description provided for @dohProvider.
  ///
  /// In en, this message translates to:
  /// **'DoH Provider'**
  String get dohProvider;

  /// No description provided for @githubProxy.
  ///
  /// In en, this message translates to:
  /// **'GitHub Proxy'**
  String get githubProxy;

  /// No description provided for @githubProxySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Route extension downloads through jsDelivr to bypass ISP blocks.'**
  String get githubProxySubtitle;

  /// No description provided for @manageExtensions.
  ///
  /// In en, this message translates to:
  /// **'Manage Extensions'**
  String get manageExtensions;

  /// No description provided for @appData.
  ///
  /// In en, this message translates to:
  /// **'App Data'**
  String get appData;

  /// No description provided for @resetDataKeepExtensions.
  ///
  /// In en, this message translates to:
  /// **'Reset Data (Keep Extensions)'**
  String get resetDataKeepExtensions;

  /// No description provided for @developer.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get developer;

  /// No description provided for @developerOptions.
  ///
  /// In en, this message translates to:
  /// **'Developer Options'**
  String get developerOptions;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @discord.
  ///
  /// In en, this message translates to:
  /// **'Discord'**
  String get discord;

  /// No description provided for @discordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join our server'**
  String get discordSubtitle;

  /// No description provided for @telegram.
  ///
  /// In en, this message translates to:
  /// **'Telegram'**
  String get telegram;

  /// No description provided for @telegramSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join our channel'**
  String get telegramSubtitle;

  /// No description provided for @developedBy.
  ///
  /// In en, this message translates to:
  /// **'Developed by {name}'**
  String developedBy(String name);

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get updateNow;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @clearAllHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear All History'**
  String get clearAllHistory;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @confirmDownload.
  ///
  /// In en, this message translates to:
  /// **'Confirm Download'**
  String get confirmDownload;

  /// No description provided for @downloadNow.
  ///
  /// In en, this message translates to:
  /// **'Download Now'**
  String get downloadNow;

  /// No description provided for @selectSource.
  ///
  /// In en, this message translates to:
  /// **'Select Source'**
  String get selectSource;

  /// No description provided for @downloadUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Download Unavailable'**
  String get downloadUnavailable;

  /// No description provided for @selectAnotherSource.
  ///
  /// In en, this message translates to:
  /// **'Select Another Source'**
  String get selectAnotherSource;

  /// No description provided for @watchHistoryCleared.
  ///
  /// In en, this message translates to:
  /// **'Watch history cleared'**
  String get watchHistoryCleared;

  /// No description provided for @downloadingUpdate.
  ///
  /// In en, this message translates to:
  /// **'Downloading update...'**
  String get downloadingUpdate;

  /// No description provided for @errorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorPrefix(String message);

  /// No description provided for @updateAvailableTag.
  ///
  /// In en, this message translates to:
  /// **'Update Available: {tag}'**
  String updateAvailableTag(String tag);

  /// No description provided for @selectProviderToStart.
  ///
  /// In en, this message translates to:
  /// **'Select a provider to start watching'**
  String get selectProviderToStart;

  /// No description provided for @tapExtensionIcon.
  ///
  /// In en, this message translates to:
  /// **'Tap the extension icon in the corner'**
  String get tapExtensionIcon;

  /// No description provided for @continueWatching.
  ///
  /// In en, this message translates to:
  /// **'Continue Watching'**
  String get continueWatching;

  /// No description provided for @noInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'No Internet Connection'**
  String get noInternetConnection;

  /// No description provided for @siteNotReachable.
  ///
  /// In en, this message translates to:
  /// **'Site Not Reachable'**
  String get siteNotReachable;

  /// No description provided for @checkConnectionOrDownloads.
  ///
  /// In en, this message translates to:
  /// **'Check your connection or view your downloaded content.'**
  String get checkConnectionOrDownloads;

  /// No description provided for @tryVpnOrConnection.
  ///
  /// In en, this message translates to:
  /// **'Please try accessing the site with a VPN or checking your internet connection.'**
  String get tryVpnOrConnection;

  /// No description provided for @errorDetails.
  ///
  /// In en, this message translates to:
  /// **'Error Details: {error}'**
  String errorDetails(String error);

  /// No description provided for @goToDownloads.
  ///
  /// In en, this message translates to:
  /// **'Go to Downloads'**
  String get goToDownloads;

  /// No description provided for @selectProvider.
  ///
  /// In en, this message translates to:
  /// **'Select Provider'**
  String get selectProvider;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search movies, series...'**
  String get searchHint;

  /// No description provided for @searchFavoriteContent.
  ///
  /// In en, this message translates to:
  /// **'Search for your favorite content'**
  String get searchFavoriteContent;

  /// No description provided for @pressSearchOrEnter.
  ///
  /// In en, this message translates to:
  /// **'Press the Search key or Enter to start'**
  String get pressSearchOrEnter;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found.'**
  String get noResultsFound;

  /// No description provided for @couldNotLoadTrending.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load trending items'**
  String get couldNotLoadTrending;

  /// No description provided for @popularMovies.
  ///
  /// In en, this message translates to:
  /// **'Popular Movies'**
  String get popularMovies;

  /// No description provided for @popularTVShows.
  ///
  /// In en, this message translates to:
  /// **'Popular TV Shows'**
  String get popularTVShows;

  /// No description provided for @newMovies.
  ///
  /// In en, this message translates to:
  /// **'New Movies'**
  String get newMovies;

  /// No description provided for @newTVShows.
  ///
  /// In en, this message translates to:
  /// **'New TV Shows'**
  String get newTVShows;

  /// No description provided for @featuredMovies.
  ///
  /// In en, this message translates to:
  /// **'Featured Movies'**
  String get featuredMovies;

  /// No description provided for @featuredTVShows.
  ///
  /// In en, this message translates to:
  /// **'Featured TV Shows'**
  String get featuredTVShows;

  /// No description provided for @lastVideosTVShows.
  ///
  /// In en, this message translates to:
  /// **'Last videos TV Shows'**
  String get lastVideosTVShows;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @bookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarks;

  /// No description provided for @noDownloadsYet.
  ///
  /// In en, this message translates to:
  /// **'No downloads yet'**
  String get noDownloadsYet;

  /// No description provided for @episodesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Episodes • {done} Done'**
  String episodesCount(int count, int done);

  /// No description provided for @deleteAllEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Delete All Episodes'**
  String get deleteAllEpisodes;

  /// No description provided for @confirmDeleteAllEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete all {count} episodes of \"{title}\" and their files?'**
  String confirmDeleteAllEpisodes(int count, String title);

  /// No description provided for @deleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete All'**
  String get deleteAll;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @statusQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued...'**
  String get statusQueued;

  /// No description provided for @statusDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get statusDownloading;

  /// No description provided for @statusFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get statusFinished;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// No description provided for @statusCanceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get statusCanceled;

  /// No description provided for @statusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get statusPaused;

  /// No description provided for @statusWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting...'**
  String get statusWaiting;

  /// No description provided for @fileNotFoundRemoving.
  ///
  /// In en, this message translates to:
  /// **'File not found on disk. Removing record.'**
  String get fileNotFoundRemoving;

  /// No description provided for @fileNotFound.
  ///
  /// In en, this message translates to:
  /// **'File not found'**
  String get fileNotFound;

  /// No description provided for @deleteDownload.
  ///
  /// In en, this message translates to:
  /// **'Delete Download'**
  String get deleteDownload;

  /// No description provided for @confirmDeleteDownload.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this download and its file?'**
  String get confirmDeleteDownload;

  /// No description provided for @libraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your library is empty'**
  String get libraryEmpty;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @hindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi (हिंदी)'**
  String get hindi;

  /// No description provided for @kannada.
  ///
  /// In en, this message translates to:
  /// **'Kannada (ಕನ್ನಡ)'**
  String get kannada;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @recommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get recommended;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @installRemoveProviders.
  ///
  /// In en, this message translates to:
  /// **'Install or remove providers'**
  String get installRemoveProviders;

  /// No description provided for @resetDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clear settings & database, keep plugin'**
  String get resetDataSubtitle;

  /// No description provided for @factoryResetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all data, settings, and extensions'**
  String get factoryResetSubtitle;

  /// No description provided for @developerOptionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Debug tools & local play'**
  String get developerOptionsSubtitle;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @sec.
  ///
  /// In en, this message translates to:
  /// **'sec'**
  String get sec;

  /// No description provided for @min.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get min;

  /// No description provided for @internalPlayer.
  ///
  /// In en, this message translates to:
  /// **'Internal (VLC)'**
  String get internalPlayer;

  /// No description provided for @builtInPlayer.
  ///
  /// In en, this message translates to:
  /// **'Built-in player'**
  String get builtInPlayer;

  /// No description provided for @customNotSet.
  ///
  /// In en, this message translates to:
  /// **'Custom (not set)'**
  String get customNotSet;

  /// No description provided for @selectGesture.
  ///
  /// In en, this message translates to:
  /// **'Select {side} Gesture'**
  String selectGesture(String side);

  /// No description provided for @left.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get left;

  /// No description provided for @right.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get right;

  /// No description provided for @selectSeekDuration.
  ///
  /// In en, this message translates to:
  /// **'Select Seek Duration'**
  String get selectSeekDuration;

  /// No description provided for @selectBufferDepth.
  ///
  /// In en, this message translates to:
  /// **'Select Buffer depth'**
  String get selectBufferDepth;

  /// No description provided for @subtitleSettings.
  ///
  /// In en, this message translates to:
  /// **'Subtitle Settings'**
  String get subtitleSettings;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size: {size}'**
  String size(int size);

  /// No description provided for @background.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get background;

  /// No description provided for @customDohUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Custom DoH URL'**
  String get customDohUrlLabel;

  /// No description provided for @enterCustomDohUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter your own DoH URL'**
  String get enterCustomDohUrl;

  /// No description provided for @chooseTheme.
  ///
  /// In en, this message translates to:
  /// **'Choose Theme'**
  String get chooseTheme;

  /// No description provided for @resetDataDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Data?'**
  String get resetDataDialogTitle;

  /// No description provided for @resetDataDialogContent.
  ///
  /// In en, this message translates to:
  /// **'This will clear Settings, Favorites, and History. Your installed Extensions will NOT be deleted.'**
  String get resetDataDialogContent;

  /// No description provided for @factoryResetDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Factory Reset?'**
  String get factoryResetDialogTitle;

  /// No description provided for @factoryResetDialogContent.
  ///
  /// In en, this message translates to:
  /// **'This will delete EVERYTHING: Favorites, History, Settings, and ALL Extensions. This cannot be undone.'**
  String get factoryResetDialogContent;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @synopsis.
  ///
  /// In en, this message translates to:
  /// **'Synopsis'**
  String get synopsis;

  /// No description provided for @noDescription.
  ///
  /// In en, this message translates to:
  /// **'No description available.'**
  String get noDescription;

  /// No description provided for @videoAlreadyDownloadedPrompt.
  ///
  /// In en, this message translates to:
  /// **'This video is already downloaded. What would you like to do?'**
  String get videoAlreadyDownloadedPrompt;

  /// No description provided for @playNow.
  ///
  /// In en, this message translates to:
  /// **'Play Now'**
  String get playNow;

  /// No description provided for @upNext.
  ///
  /// In en, this message translates to:
  /// **'Up Next'**
  String get upNext;

  /// No description provided for @deleteDownloadPrompt.
  ///
  /// In en, this message translates to:
  /// **'Delete Download?'**
  String get deleteDownloadPrompt;

  /// No description provided for @deleteDownloadConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this file? This cannot be undone.'**
  String get deleteDownloadConfirmation;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @yesDelete.
  ///
  /// In en, this message translates to:
  /// **'Yes, Delete'**
  String get yesDelete;

  /// No description provided for @downloadPaused.
  ///
  /// In en, this message translates to:
  /// **'Download Paused'**
  String get downloadPaused;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloading;

  /// No description provided for @speed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speed;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remaining;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @torrentContent.
  ///
  /// In en, this message translates to:
  /// **'Torrent Content'**
  String get torrentContent;

  /// No description provided for @audioTracks.
  ///
  /// In en, this message translates to:
  /// **'Audio Tracks'**
  String get audioTracks;

  /// No description provided for @noAudioTracks.
  ///
  /// In en, this message translates to:
  /// **'No audio tracks found'**
  String get noAudioTracks;

  /// No description provided for @subtitles.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get subtitles;

  /// No description provided for @options.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get options;

  /// No description provided for @noSubtitlesFound.
  ///
  /// In en, this message translates to:
  /// **'No subtitle tracks found'**
  String get noSubtitlesFound;

  /// No description provided for @playbackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback Speed'**
  String get playbackSpeed;

  /// No description provided for @subtitleOptions.
  ///
  /// In en, this message translates to:
  /// **'Subtitle Options'**
  String get subtitleOptions;

  /// No description provided for @hlsSubtitleWarning.
  ///
  /// In en, this message translates to:
  /// **'External subtitle files are not supported on the active HLS player on this platform.'**
  String get hlsSubtitleWarning;

  /// No description provided for @loadFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Load from Device'**
  String get loadFromDevice;

  /// No description provided for @syncDelay.
  ///
  /// In en, this message translates to:
  /// **'Sync / Delay'**
  String get syncDelay;

  /// No description provided for @styleSettings.
  ///
  /// In en, this message translates to:
  /// **'Style Settings'**
  String get styleSettings;

  /// No description provided for @searchOnline.
  ///
  /// In en, this message translates to:
  /// **'Search Online (Subtitle Search)'**
  String get searchOnline;

  /// No description provided for @subtitleSync.
  ///
  /// In en, this message translates to:
  /// **'Subtitle Sync'**
  String get subtitleSync;

  /// No description provided for @subtitleDelayWarning.
  ///
  /// In en, this message translates to:
  /// **'Subtitle delay is not supported by the active playback engine.'**
  String get subtitleDelayWarning;

  /// No description provided for @resetDelay.
  ///
  /// In en, this message translates to:
  /// **'Reset Delay'**
  String get resetDelay;

  /// No description provided for @subtitleStyles.
  ///
  /// In en, this message translates to:
  /// **'Subtitle Styles'**
  String get subtitleStyles;

  /// No description provided for @resetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get resetToDefault;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get fontSize;

  /// No description provided for @verticalPosition.
  ///
  /// In en, this message translates to:
  /// **'Vertical Position'**
  String get verticalPosition;

  /// No description provided for @textColor.
  ///
  /// In en, this message translates to:
  /// **'Text Color'**
  String get textColor;

  /// No description provided for @backgroundColor.
  ///
  /// In en, this message translates to:
  /// **'Background Color'**
  String get backgroundColor;

  /// No description provided for @backgroundOpacity.
  ///
  /// In en, this message translates to:
  /// **'Background Opacity'**
  String get backgroundOpacity;

  /// No description provided for @subtitleSearch.
  ///
  /// In en, this message translates to:
  /// **'Subtitle Search'**
  String get subtitleSearch;

  /// No description provided for @searchSubtitleNameHint.
  ///
  /// In en, this message translates to:
  /// **'Search subtitle name...'**
  String get searchSubtitleNameHint;

  /// No description provided for @enterSearchSubtitlePrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter a name or search to find subtitles.'**
  String get enterSearchSubtitlePrompt;

  /// No description provided for @noSubtitleResults.
  ///
  /// In en, this message translates to:
  /// **'No results found. Try another query.'**
  String get noSubtitleResults;

  /// No description provided for @downloadingApplyingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Downloading & applying subtitle...'**
  String get downloadingApplyingSubtitle;

  /// No description provided for @failedToDownloadSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Failed to download subtitle.'**
  String get failedToDownloadSubtitle;

  /// No description provided for @failedToLoadSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Failed to load subtitles. Please try again.'**
  String get failedToLoadSubtitles;

  /// No description provided for @noReposFound.
  ///
  /// In en, this message translates to:
  /// **'No repositories or plugins found'**
  String get noReposFound;

  /// No description provided for @downloadAllProviders.
  ///
  /// In en, this message translates to:
  /// **'Download All'**
  String get downloadAllProviders;

  /// No description provided for @removeRepository.
  ///
  /// In en, this message translates to:
  /// **'Remove Repository'**
  String get removeRepository;

  /// No description provided for @addRepo.
  ///
  /// In en, this message translates to:
  /// **'Add Repo'**
  String get addRepo;

  /// No description provided for @extensionsNotInRepos.
  ///
  /// In en, this message translates to:
  /// **'Extensions Not in Repositories'**
  String get extensionsNotInRepos;

  /// No description provided for @noLongerInRepo.
  ///
  /// In en, this message translates to:
  /// **'No longer listed in any repository'**
  String get noLongerInRepo;

  /// No description provided for @addRepoToBrowse.
  ///
  /// In en, this message translates to:
  /// **'Add a repository to browse and update plugins'**
  String get addRepoToBrowse;

  /// No description provided for @debugExtensions.
  ///
  /// In en, this message translates to:
  /// **'Debug Extensions'**
  String get debugExtensions;

  /// No description provided for @removeRepoConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {repoName}?'**
  String removeRepoConfirm(String repoName);

  /// No description provided for @removeRepoWarning.
  ///
  /// In en, this message translates to:
  /// **'This will remove the repository and uninstall ALL its plugin.'**
  String get removeRepoWarning;

  /// No description provided for @addRepository.
  ///
  /// In en, this message translates to:
  /// **'Add Repository'**
  String get addRepository;

  /// No description provided for @repoUrlOrShortcode.
  ///
  /// In en, this message translates to:
  /// **'Repository URL or Shortcode'**
  String get repoUrlOrShortcode;

  /// No description provided for @assetPlugin.
  ///
  /// In en, this message translates to:
  /// **'Asset Plugin'**
  String get assetPlugin;

  /// No description provided for @installed.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get installed;

  /// No description provided for @repositories.
  ///
  /// In en, this message translates to:
  /// **'Repositories'**
  String get repositories;

  /// No description provided for @noExtensionsInstalled.
  ///
  /// In en, this message translates to:
  /// **'No Extensions Installed'**
  String get noExtensionsInstalled;

  /// No description provided for @browseRepositoriesToInstall.
  ///
  /// In en, this message translates to:
  /// **'Browse the Repositories tab to discover and install extensions.'**
  String get browseRepositoriesToInstall;

  /// No description provided for @browseRepositories.
  ///
  /// In en, this message translates to:
  /// **'Browse Repositories'**
  String get browseRepositories;

  /// No description provided for @addRepoDescription.
  ///
  /// In en, this message translates to:
  /// **'Add a repository URL or shortcode to discover and install extension plugins.'**
  String get addRepoDescription;

  /// No description provided for @updateTo.
  ///
  /// In en, this message translates to:
  /// **'Update to {version}'**
  String updateTo(String version);

  /// No description provided for @install.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get install;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @pluginSettings.
  ///
  /// In en, this message translates to:
  /// **'{pluginName} Settings'**
  String pluginSettings(String pluginName);

  /// No description provided for @movies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get movies;

  /// No description provided for @series.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get series;

  /// No description provided for @anime.
  ///
  /// In en, this message translates to:
  /// **'Anime'**
  String get anime;

  /// No description provided for @liveStreams.
  ///
  /// In en, this message translates to:
  /// **'Live Streams'**
  String get liveStreams;

  /// No description provided for @debug.
  ///
  /// In en, this message translates to:
  /// **'DEBUG'**
  String get debug;

  /// No description provided for @extensionsUpdated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Updated 1 extension} other{Updated {count} extensions}}'**
  String extensionsUpdated(num count);

  /// No description provided for @invalidNavigation.
  ///
  /// In en, this message translates to:
  /// **'Invalid navigation. Please go back.'**
  String get invalidNavigation;

  /// No description provided for @startOver.
  ///
  /// In en, this message translates to:
  /// **'Start Over'**
  String get startOver;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// No description provided for @resolving.
  ///
  /// In en, this message translates to:
  /// **'Resolving...'**
  String get resolving;

  /// No description provided for @downloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloaded;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @debugOnlyFeature.
  ///
  /// In en, this message translates to:
  /// **'This feature is only available in Debug builds'**
  String get debugOnlyFeature;

  /// No description provided for @streamUrl.
  ///
  /// In en, this message translates to:
  /// **'Stream URL'**
  String get streamUrl;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @verifyingSourceSize.
  ///
  /// In en, this message translates to:
  /// **'Verifying source & size...'**
  String get verifyingSourceSize;

  /// No description provided for @fileSaveLocationNotification.
  ///
  /// In en, this message translates to:
  /// **'The file will be saved in your Downloads folder.'**
  String get fileSaveLocationNotification;

  /// No description provided for @resumingPlayback.
  ///
  /// In en, this message translates to:
  /// **'Resuming Playback'**
  String get resumingPlayback;

  /// No description provided for @pausedAt.
  ///
  /// In en, this message translates to:
  /// **'Paused at {time}'**
  String pausedAt(String time);

  /// No description provided for @resumesAutomatically.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Resumes automatically in 1 second} other{Resumes automatically in {count} seconds}}'**
  String resumesAutomatically(int count);

  /// No description provided for @resumeNow.
  ///
  /// In en, this message translates to:
  /// **'Resume Now'**
  String get resumeNow;

  /// No description provided for @playbackError.
  ///
  /// In en, this message translates to:
  /// **'Playback Error'**
  String get playbackError;

  /// No description provided for @confirmClearHistory.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove all items from your watch history?'**
  String get confirmClearHistory;

  /// No description provided for @seasonWithNumber.
  ///
  /// In en, this message translates to:
  /// **'Season {number}'**
  String seasonWithNumber(Object number);

  /// No description provided for @starting.
  ///
  /// In en, this message translates to:
  /// **'Starting...'**
  String get starting;

  /// No description provided for @percentWatched.
  ///
  /// In en, this message translates to:
  /// **'{percent}% watched'**
  String percentWatched(int percent);

  /// No description provided for @sub.
  ///
  /// In en, this message translates to:
  /// **'Sub'**
  String get sub;

  /// No description provided for @dub.
  ///
  /// In en, this message translates to:
  /// **'Dub'**
  String get dub;

  /// No description provided for @playEpisode.
  ///
  /// In en, this message translates to:
  /// **'{label} S{season} E{episode}'**
  String playEpisode(String label, Object season, Object episode);

  /// No description provided for @playEpisodeOnly.
  ///
  /// In en, this message translates to:
  /// **'{label} E{episode}'**
  String playEpisodeOnly(String label, int episode);

  /// No description provided for @debugTools.
  ///
  /// In en, this message translates to:
  /// **'Debug Tools'**
  String get debugTools;

  /// No description provided for @playLocalVideo.
  ///
  /// In en, this message translates to:
  /// **'Play local video file'**
  String get playLocalVideo;

  /// No description provided for @playLocalVideoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Play any video from device'**
  String get playLocalVideoSubtitle;

  /// No description provided for @streamUrlSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Play from network URL'**
  String get streamUrlSubtitle;

  /// No description provided for @streamTorrent.
  ///
  /// In en, this message translates to:
  /// **'Stream torrent'**
  String get streamTorrent;

  /// No description provided for @streamTorrentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select a local torrent file to play'**
  String get streamTorrentSubtitle;

  /// No description provided for @loadPluginFromAssets.
  ///
  /// In en, this message translates to:
  /// **'Load plugin from assets'**
  String get loadPluginFromAssets;

  /// No description provided for @enterVideoUrlHint.
  ///
  /// In en, this message translates to:
  /// **'Enter video URL (http, magnet, etc.)'**
  String get enterVideoUrlHint;

  /// No description provided for @networkStream.
  ///
  /// In en, this message translates to:
  /// **'Network Stream'**
  String get networkStream;

  /// No description provided for @removedFromHistory.
  ///
  /// In en, this message translates to:
  /// **'Removed {title} from history'**
  String removedFromHistory(String title);

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @refreshingLiveStream.
  ///
  /// In en, this message translates to:
  /// **'Refreshing live stream...'**
  String get refreshingLiveStream;

  /// No description provided for @removeFromHistory.
  ///
  /// In en, this message translates to:
  /// **'Remove from History'**
  String get removeFromHistory;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get live;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @brightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get brightness;

  /// No description provided for @fit.
  ///
  /// In en, this message translates to:
  /// **'Fit'**
  String get fit;

  /// No description provided for @zoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get zoom;

  /// No description provided for @stretch.
  ///
  /// In en, this message translates to:
  /// **'Stretch'**
  String get stretch;

  /// No description provided for @titleWithParam.
  ///
  /// In en, this message translates to:
  /// **'Title: {title}'**
  String titleWithParam(String title);

  /// No description provided for @sourceWithParam.
  ///
  /// In en, this message translates to:
  /// **'Source: {source}'**
  String sourceWithParam(String source);

  /// No description provided for @sizeWithParam.
  ///
  /// In en, this message translates to:
  /// **'Size: {size}'**
  String sizeWithParam(String size);

  /// No description provided for @usingInternalPlayerError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}. Using internal player.'**
  String usingInternalPlayerError(String error);

  /// No description provided for @playerNotDetected.
  ///
  /// In en, this message translates to:
  /// **'{playerName} not detected. Starting internal player.'**
  String playerNotDetected(String playerName);

  /// No description provided for @seasonWithEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Season {number} ({count} Episodes)'**
  String seasonWithEpisodes(Object number, int count);

  /// No description provided for @cloudflare.
  ///
  /// In en, this message translates to:
  /// **'Cloudflare'**
  String get cloudflare;

  /// No description provided for @google.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get google;

  /// No description provided for @adguard.
  ///
  /// In en, this message translates to:
  /// **'AdGuard'**
  String get adguard;

  /// No description provided for @dnsWatch.
  ///
  /// In en, this message translates to:
  /// **'DNS.Watch'**
  String get dnsWatch;

  /// No description provided for @quad9.
  ///
  /// In en, this message translates to:
  /// **'Quad9'**
  String get quad9;

  /// No description provided for @dnsSb.
  ///
  /// In en, this message translates to:
  /// **'DNS.SB'**
  String get dnsSb;

  /// No description provided for @canadianShield.
  ///
  /// In en, this message translates to:
  /// **'Canadian Shield'**
  String get canadianShield;

  /// No description provided for @tmdb.
  ///
  /// In en, this message translates to:
  /// **'TMDB'**
  String get tmdb;

  /// No description provided for @selectSourceForPlayer.
  ///
  /// In en, this message translates to:
  /// **'Select Source for {playerName}'**
  String selectSourceForPlayer(String playerName);

  /// No description provided for @noPluginsInstalled.
  ///
  /// In en, this message translates to:
  /// **'No plugins installed'**
  String get noPluginsInstalled;

  /// No description provided for @noPluginsMessage.
  ///
  /// In en, this message translates to:
  /// **'Install extensions to browse and stream content.'**
  String get noPluginsMessage;

  /// No description provided for @goToExtensions.
  ///
  /// In en, this message translates to:
  /// **'Go to Extensions'**
  String get goToExtensions;

  /// No description provided for @availableSources.
  ///
  /// In en, this message translates to:
  /// **'Available Sources'**
  String get availableSources;

  /// No description provided for @seasons.
  ///
  /// In en, this message translates to:
  /// **'Seasons'**
  String get seasons;

  /// No description provided for @episodes.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get episodes;

  /// No description provided for @selectSourceToPlay.
  ///
  /// In en, this message translates to:
  /// **'Please select a source from \'Available Sources\' above to play.'**
  String get selectSourceToPlay;

  /// No description provided for @episodeCountOnly.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Episode} other{{count} Episodes}}'**
  String episodeCountOnly(num count);

  /// No description provided for @noEpisodesFound.
  ///
  /// In en, this message translates to:
  /// **'No episodes found'**
  String get noEpisodesFound;

  /// No description provided for @local.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get local;

  /// No description provided for @remote.
  ///
  /// In en, this message translates to:
  /// **'Remote'**
  String get remote;

  /// No description provided for @torrent.
  ///
  /// In en, this message translates to:
  /// **'Torrent'**
  String get torrent;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @lock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get lock;

  /// No description provided for @sources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get sources;

  /// No description provided for @tracks.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get tracks;

  /// No description provided for @content.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get content;

  /// No description provided for @stats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get stats;

  /// No description provided for @resize.
  ///
  /// In en, this message translates to:
  /// **'Resize'**
  String get resize;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @pip.
  ///
  /// In en, this message translates to:
  /// **'PiP'**
  String get pip;

  /// No description provided for @rotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get rotate;

  /// No description provided for @windowed.
  ///
  /// In en, this message translates to:
  /// **'Windowed'**
  String get windowed;

  /// No description provided for @fullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get fullscreen;

  /// No description provided for @movieDetails.
  ///
  /// In en, this message translates to:
  /// **'Movie Details'**
  String get movieDetails;

  /// No description provided for @showDetails.
  ///
  /// In en, this message translates to:
  /// **'Show Details'**
  String get showDetails;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Tagline'**
  String get tagline;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @releaseDate.
  ///
  /// In en, this message translates to:
  /// **'Release Date'**
  String get releaseDate;

  /// No description provided for @firstAirDate.
  ///
  /// In en, this message translates to:
  /// **'First Air Date'**
  String get firstAirDate;

  /// No description provided for @originalLanguage.
  ///
  /// In en, this message translates to:
  /// **'Original Language'**
  String get originalLanguage;

  /// No description provided for @originCountry.
  ///
  /// In en, this message translates to:
  /// **'Origin Country'**
  String get originCountry;

  /// No description provided for @budgetLabel.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budgetLabel;

  /// No description provided for @revenueLabel.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revenueLabel;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// No description provided for @watched.
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get watched;

  /// No description provided for @watching.
  ///
  /// In en, this message translates to:
  /// **'Watching'**
  String get watching;

  /// No description provided for @lastWatched.
  ///
  /// In en, this message translates to:
  /// **'Last Watched'**
  String get lastWatched;

  /// No description provided for @movie.
  ///
  /// In en, this message translates to:
  /// **'Movie'**
  String get movie;

  /// No description provided for @tvShow.
  ///
  /// In en, this message translates to:
  /// **'TV Show'**
  String get tvShow;

  /// No description provided for @failedToLoadContent.
  ///
  /// In en, this message translates to:
  /// **'Failed to load content'**
  String get failedToLoadContent;

  /// No description provided for @director.
  ///
  /// In en, this message translates to:
  /// **'Director'**
  String get director;

  /// No description provided for @creator.
  ///
  /// In en, this message translates to:
  /// **'Creator'**
  String get creator;

  /// No description provided for @showMore.
  ///
  /// In en, this message translates to:
  /// **'Show More'**
  String get showMore;

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show Less'**
  String get showLess;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @seasonsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Seasons'**
  String seasonsCount(int count);

  /// No description provided for @noInternetError.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noInternetError;

  /// No description provided for @timeoutError.
  ///
  /// In en, this message translates to:
  /// **'Request timed out. Please try again.'**
  String get timeoutError;

  /// No description provided for @serverError.
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again later.'**
  String get serverError;

  /// No description provided for @contentNotFoundError.
  ///
  /// In en, this message translates to:
  /// **'Content not found.'**
  String get contentNotFoundError;

  /// No description provided for @accessDeniedError.
  ///
  /// In en, this message translates to:
  /// **'Access denied. Check your credentials.'**
  String get accessDeniedError;

  /// No description provided for @serviceUnavailableError.
  ///
  /// In en, this message translates to:
  /// **'Server is unavailable. Try again later.'**
  String get serviceUnavailableError;

  /// No description provided for @generalError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get generalError;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @skipIntro.
  ///
  /// In en, this message translates to:
  /// **'Skip Intro'**
  String get skipIntro;

  /// No description provided for @skipOutro.
  ///
  /// In en, this message translates to:
  /// **'Skip Outro'**
  String get skipOutro;

  /// No description provided for @skipRecap.
  ///
  /// In en, this message translates to:
  /// **'Skip Recap'**
  String get skipRecap;

  /// No description provided for @goLive.
  ///
  /// In en, this message translates to:
  /// **'Go Live'**
  String get goLive;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @nextUp.
  ///
  /// In en, this message translates to:
  /// **'Next Up'**
  String get nextUp;

  /// No description provided for @sourceAttempt.
  ///
  /// In en, this message translates to:
  /// **'Source {index} of {total}'**
  String sourceAttempt(int index, int total);

  /// No description provided for @trying.
  ///
  /// In en, this message translates to:
  /// **'Trying'**
  String get trying;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get selected;

  /// No description provided for @playing.
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get playing;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @openSubtitles.
  ///
  /// In en, this message translates to:
  /// **'OpenSubtitles'**
  String get openSubtitles;

  /// No description provided for @subDl.
  ///
  /// In en, this message translates to:
  /// **'SubDL'**
  String get subDl;

  /// No description provided for @subSource.
  ///
  /// In en, this message translates to:
  /// **'SubSource'**
  String get subSource;

  /// No description provided for @wifiQualityPreference.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi Quality Preference'**
  String get wifiQualityPreference;

  /// No description provided for @mobileQualityPreference.
  ///
  /// In en, this message translates to:
  /// **'Mobile Quality Preference'**
  String get mobileQualityPreference;

  /// No description provided for @anyNoPreference.
  ///
  /// In en, this message translates to:
  /// **'Any (no preference)'**
  String get anyNoPreference;

  /// No description provided for @subtitleAccounts.
  ///
  /// In en, this message translates to:
  /// **'Subtitle Accounts'**
  String get subtitleAccounts;

  /// No description provided for @accounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accounts;

  /// No description provided for @notLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not logged in'**
  String get notLoggedIn;

  /// No description provided for @loggedInAs.
  ///
  /// In en, this message translates to:
  /// **'Logged in as {username}'**
  String loggedInAs(String username);

  /// No description provided for @apiKeyConfigured.
  ///
  /// In en, this message translates to:
  /// **'API Key configured'**
  String get apiKeyConfigured;

  /// No description provided for @keyNotSet.
  ///
  /// In en, this message translates to:
  /// **'Key not set'**
  String get keyNotSet;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get testConnection;

  /// No description provided for @connectedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Connected Successfully'**
  String get connectedSuccessfully;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection Failed'**
  String get connectionFailed;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @noAccountRegister.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Register here'**
  String get noAccountRegister;

  /// No description provided for @apiKey.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get apiKey;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @fetchMyApiKey.
  ///
  /// In en, this message translates to:
  /// **'Fetch My API Key'**
  String get fetchMyApiKey;

  /// No description provided for @keyVerified.
  ///
  /// In en, this message translates to:
  /// **'Key Verified'**
  String get keyVerified;

  /// No description provided for @invalidApiKey.
  ///
  /// In en, this message translates to:
  /// **'Invalid API Key'**
  String get invalidApiKey;

  /// No description provided for @openSubtitlesAuthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your account credentials for higher limits and ad-free subtitles.'**
  String get openSubtitlesAuthSubtitle;

  /// No description provided for @subDlAuthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your SubDL API Key directly, or fetch it using your account credentials below.'**
  String get subDlAuthSubtitle;

  /// No description provided for @orFetchViaAccount.
  ///
  /// In en, this message translates to:
  /// **'OR FETCH VIA ACCOUNT'**
  String get orFetchViaAccount;

  /// No description provided for @subSourceAuthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'SubSource works out-of-the-box, but you can add a personal official API key to override the default for better reliability.'**
  String get subSourceAuthSubtitle;

  /// No description provided for @apiKeyOptionalOverride.
  ///
  /// In en, this message translates to:
  /// **'API Key (Optional Override)'**
  String get apiKeyOptionalOverride;

  /// No description provided for @enterKeyToOverrideDefault.
  ///
  /// In en, this message translates to:
  /// **'Enter key to override default'**
  String get enterKeyToOverrideDefault;

  /// No description provided for @getApiKeyFromProfile.
  ///
  /// In en, this message translates to:
  /// **'Get your API Key from SubSource Profile'**
  String get getApiKeyFromProfile;

  /// No description provided for @qualityNotGuaranteed.
  ///
  /// In en, this message translates to:
  /// **'Quality is not guaranteed. Sources are sorted by preference, but playback depends on what the provider actually offers.'**
  String get qualityNotGuaranteed;

  /// No description provided for @keepSourcesOriginalOrder.
  ///
  /// In en, this message translates to:
  /// **'Keep sources in original order'**
  String get keepSourcesOriginalOrder;

  /// No description provided for @openLink.
  ///
  /// In en, this message translates to:
  /// **'Open link'**
  String get openLink;

  /// No description provided for @diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnostics;

  /// No description provided for @viewLogs.
  ///
  /// In en, this message translates to:
  /// **'View Logs'**
  String get viewLogs;

  /// No description provided for @viewLogsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View application activity & errors'**
  String get viewLogsSubtitle;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear image and video cache'**
  String get clearCache;

  /// No description provided for @clearCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Frees up storage used by cached images and videos'**
  String get clearCacheSubtitle;

  /// No description provided for @clearCacheDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear cache?'**
  String get clearCacheDialogTitle;

  /// No description provided for @clearCacheDialogContent.
  ///
  /// In en, this message translates to:
  /// **'This will delete cached images and video files. Your settings, history, and extensions will not be affected.'**
  String get clearCacheDialogContent;

  /// No description provided for @clearCacheNow.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get clearCacheNow;

  /// No description provided for @cacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get cacheCleared;

  /// No description provided for @calculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating…'**
  String get calculating;

  /// No description provided for @playerControls.
  ///
  /// In en, this message translates to:
  /// **'Player Controls'**
  String get playerControls;

  /// No description provided for @playerControlsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show or hide player control buttons'**
  String get playerControlsSubtitle;

  /// No description provided for @showPip.
  ///
  /// In en, this message translates to:
  /// **'Picture-in-Picture button'**
  String get showPip;

  /// No description provided for @showResize.
  ///
  /// In en, this message translates to:
  /// **'Resize button'**
  String get showResize;

  /// No description provided for @showRotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate button'**
  String get showRotate;

  /// No description provided for @showPlaybackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed button'**
  String get showPlaybackSpeed;

  /// No description provided for @showEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Episodes button'**
  String get showEpisodes;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'as',
    'be',
    'bg',
    'bn',
    'cs',
    'de',
    'el',
    'en',
    'es',
    'fr',
    'gu',
    'he',
    'hi',
    'hr',
    'hu',
    'id',
    'it',
    'ja',
    'kn',
    'ko',
    'lv',
    'mk',
    'ml',
    'mr',
    'nl',
    'pa',
    'pl',
    'pt',
    'ro',
    'ru',
    'sv',
    'ta',
    'te',
    'tr',
    'uk',
    'ur',
    'vi',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'ar':
      {
        switch (locale.countryCode) {
          case 'apc':
            return AppLocalizationsArApc();
        }
        break;
      }
    case 'pt':
      {
        switch (locale.countryCode) {
          case 'BR':
            return AppLocalizationsPtBr();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'as':
      return AppLocalizationsAs();
    case 'be':
      return AppLocalizationsBe();
    case 'bg':
      return AppLocalizationsBg();
    case 'bn':
      return AppLocalizationsBn();
    case 'cs':
      return AppLocalizationsCs();
    case 'de':
      return AppLocalizationsDe();
    case 'el':
      return AppLocalizationsEl();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'gu':
      return AppLocalizationsGu();
    case 'he':
      return AppLocalizationsHe();
    case 'hi':
      return AppLocalizationsHi();
    case 'hr':
      return AppLocalizationsHr();
    case 'hu':
      return AppLocalizationsHu();
    case 'id':
      return AppLocalizationsId();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'kn':
      return AppLocalizationsKn();
    case 'ko':
      return AppLocalizationsKo();
    case 'lv':
      return AppLocalizationsLv();
    case 'mk':
      return AppLocalizationsMk();
    case 'ml':
      return AppLocalizationsMl();
    case 'mr':
      return AppLocalizationsMr();
    case 'nl':
      return AppLocalizationsNl();
    case 'pa':
      return AppLocalizationsPa();
    case 'pl':
      return AppLocalizationsPl();
    case 'pt':
      return AppLocalizationsPt();
    case 'ro':
      return AppLocalizationsRo();
    case 'ru':
      return AppLocalizationsRu();
    case 'sv':
      return AppLocalizationsSv();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
    case 'tr':
      return AppLocalizationsTr();
    case 'uk':
      return AppLocalizationsUk();
    case 'ur':
      return AppLocalizationsUr();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
