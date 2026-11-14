// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Macedonian (`mk`).
class AppLocalizationsMk extends AppLocalizations {
  AppLocalizationsMk([String locale = 'mk']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => 'Македонски';

  @override
  String get addonHealthChecking => 'Checking add-on…';

  @override
  String addonHealthWorking(int ms) {
    return 'Working · $ms ms';
  }

  @override
  String get addonHealthUnavailable => 'Unavailable';

  @override
  String get home => 'Почетна';

  @override
  String get search => 'Пребарај';

  @override
  String get explore => 'Истражувај';

  @override
  String get exploreAnime => 'Истражи аниме';

  @override
  String get exploreMovies => 'Истражи филмови';

  @override
  String get library => 'Библиотека';

  @override
  String get settings => 'Поставки';

  @override
  String get extensions => 'Екстензии';

  @override
  String get updateAvailable => 'Достапно ажурирање';

  @override
  String get retry => 'Обиди се повторно';

  @override
  String get factoryReset => 'Фабричко ресетирање';

  @override
  String get startupError => 'Грешка при стартување';

  @override
  String get general => 'Општо';

  @override
  String get appTheme => 'Тема на апликацијата';

  @override
  String get recordWatchHistory => 'Снимај историја на гледање';

  @override
  String get fullScreenMode => 'Цел екран';

  @override
  String get fullScreenModeSubtitle => 'Се префрла на телевизискиот интерфејс';

  @override
  String get defaultHomeScreen => 'Стандарден почетен екран';

  @override
  String get titlePosition => 'Позиција на насловот';

  @override
  String get titlePositionBelowPoster => 'Под постерот';

  @override
  String get titlePositionInsidePoster => 'Во постерот';

  @override
  String get player => 'Плеер';

  @override
  String get defaultPlayer => 'Стандарден плеер';

  @override
  String get leftGesture => 'Лев гест';

  @override
  String get rightGesture => 'Десен гест';

  @override
  String get doubleTapToSeek => 'Двојно допирање за пребарување';

  @override
  String get swipeToSeek => 'Повлекување за пребарување';

  @override
  String get seekDuration => 'Времетраење на пребарувањето';

  @override
  String get defaultResizeMode => 'Стандарден режим за големина';

  @override
  String get hardwareDecoding => 'Хардверско декодирање';

  @override
  String get network => 'Мрежа';

  @override
  String get dnsOverHttps => 'DNS преку HTTPS';

  @override
  String get dohProvider => 'DoH провајдер';

  @override
  String get githubProxy => 'GitHub прокси';

  @override
  String get githubProxySubtitle =>
      'Насочи ги преземањата на екстензии преку jsDelivr за да ги заобиколиш блокадите на операторот.';

  @override
  String get manageExtensions => 'Управување со екстензии';

  @override
  String get appData => 'Податоци на апликацијата';

  @override
  String get resetDataKeepExtensions => 'Ресетирај податоци (задржи екстензии)';

  @override
  String get developer => 'Програмер';

  @override
  String get developerOptions => 'Опции за програмери';

  @override
  String get about => 'За апликацијата';

  @override
  String get version => 'Верзија';

  @override
  String get openSourceLicences => 'Open-source licences';

  @override
  String get openSourceLicencesSubtitle =>
      'SkyStream is free software under the GNU GPL v3';

  @override
  String get appLegalese =>
      'Copyright © 2025–2026 SkyStream contributors.\nSkyStream is free software: you can redistribute it and modify it under the terms of the GNU General Public License, version 3. It comes with ABSOLUTELY NO WARRANTY. Its source code is at github.com/akashdh11/skystream.';

  @override
  String get enabled => 'Овозможено';

  @override
  String get disabled => 'Оневозможено';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'Приклучете се на нашиот сервер';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'Приклучете се на нашиот канал';

  @override
  String developedBy(String name) {
    return 'Developed by $name';
  }

  @override
  String get system => 'Системска';

  @override
  String get dark => 'Темна';

  @override
  String get light => 'Светла';

  @override
  String get later => 'Подоцна';

  @override
  String get updateNow => 'Ажурирај сега';

  @override
  String get save => 'Зачувај';

  @override
  String get cancel => 'Откажи';

  @override
  String get close => 'Затвори';

  @override
  String get delete => 'Избриши';

  @override
  String get viewDetails => 'Види детали';

  @override
  String get clearAll => 'Исчисти сè';

  @override
  String get clearAllHistory => 'Исчисти историја на гледање';

  @override
  String get all => 'Сите';

  @override
  String get none => 'Ништо';

  @override
  String get confirmDownload => 'Потврди преземање';

  @override
  String get downloadNow => 'Преземи сега';

  @override
  String get selectSource => 'Избери извор';

  @override
  String get downloadUnavailable => 'Недостапно';

  @override
  String get selectAnotherSource => 'Избери друг извор';

  @override
  String get watchHistoryCleared => 'Историјата на гледање е исчистена';

  @override
  String get downloadingUpdate => 'Преземање ажурирање...';

  @override
  String errorPrefix(String message) {
    return 'Грешка: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'Достапно ажурирање: $tag';
  }

  @override
  String get selectProviderToStart => 'Изберете провајдер за почеток';

  @override
  String get tapExtensionIcon => 'Допрете ја иконата за екстензија во аголот';

  @override
  String get continueWatching => 'Продолжи со гледање';

  @override
  String get noInternetConnection => 'Нема интернет врска';

  @override
  String get siteNotReachable => 'Сајтот е недостапен';

  @override
  String get checkConnectionOrDownloads =>
      'Проверете ја врската или погледнете ги преземањата.';

  @override
  String get tryVpnOrConnection =>
      'Обидете се со VPN или проверете ја врската.';

  @override
  String errorDetails(String error) {
    return 'Детали за грешката: $error';
  }

  @override
  String get goToDownloads => 'Оди до преземања';

  @override
  String get selectProvider => 'Избери провајдер';

  @override
  String get searchHint => 'Пребарај филмови, серии...';

  @override
  String get searchFavoriteContent => 'Пребарајте ја вашата омилена содржина';

  @override
  String get pressSearchOrEnter => 'Притиснете Пребарај или Enter за почеток';

  @override
  String get recentSearches => 'Recent searches';

  @override
  String removeFromSearchHistory(String query) {
    return 'Remove $query from search history';
  }

  @override
  String get noResultsFound => 'Нема пронајдени резултати.';

  @override
  String get couldNotLoadTrending => 'Не можеа да се вчитаат трендовите';

  @override
  String get popularMovies => 'Популарни филмови';

  @override
  String get popularTVShows => 'Популарни серии';

  @override
  String get newMovies => 'Нови филмови';

  @override
  String get newTVShows => 'Нови серии';

  @override
  String get featuredMovies => 'Препорачани филмови';

  @override
  String get featuredTVShows => 'Препорачани серии';

  @override
  String get lastVideosTVShows => 'Последни епизоди';

  @override
  String get downloads => 'Преземања';

  @override
  String get bookmarks => 'Обележувачи';

  @override
  String get noDownloadsYet => 'Сè уште нема преземања';

  @override
  String episodesCount(int count, int done) {
    return '$count епизоди • $done завршени';
  }

  @override
  String get deleteAllEpisodes => 'Избриши ги сите епизоди';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return 'Дали сте сигурни дека сакате да ги избришете сите $count епизоди на \"$title\" и нивните датотеки?';
  }

  @override
  String get deleteAll => 'Избриши сè';

  @override
  String get completed => 'Завршено';

  @override
  String get statusQueued => 'Во редица...';

  @override
  String get statusDownloading => 'Преземање...';

  @override
  String get statusFinished => 'Завршено';

  @override
  String get statusFailed => 'Неуспешно';

  @override
  String get statusCanceled => 'Откажано';

  @override
  String get statusPaused => 'Паузирано';

  @override
  String get statusWaiting => 'Чекање...';

  @override
  String get fileNotFoundRemoving =>
      'Датотеката не е пронајдена. Се отстранува записот.';

  @override
  String get fileNotFound => 'Датотеката не е пронајдена';

  @override
  String get deleteDownload => 'Избриши преземање';

  @override
  String get confirmDeleteDownload =>
      'Дали сте сигурни дека сакате да го избришете ова преземање?';

  @override
  String get libraryEmpty => 'Библиотеката е празна';

  @override
  String get language => 'Јазик';

  @override
  String get english => 'Англиски';

  @override
  String get hindi => 'Хинди';

  @override
  String get kannada => 'Канада';

  @override
  String get unknown => 'Непознато';

  @override
  String get recommended => 'Препорачано';

  @override
  String get on => 'Вклучено';

  @override
  String get off => 'Исклучено';

  @override
  String get installRemoveProviders => 'Инсталирај или отстрани провајдери';

  @override
  String get resetDataSubtitle => 'Исчисти поставки и база, задржи приклучоци';

  @override
  String get factoryResetSubtitle =>
      'Избриши ги сите податоци, поставки и екстензии';

  @override
  String get developerOptionsSubtitle =>
      'Алатки за дебагирање и локално пуштање';

  @override
  String get loading => 'Вчитување...';

  @override
  String get sec => 'сек';

  @override
  String get min => 'мин';

  @override
  String playerRewindSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Назад $count секунди',
      one: 'Назад $count секунда',
    );
    return '$_temp0';
  }

  @override
  String playerForwardSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Напред $count секунди',
      one: 'Напред $count секунда',
    );
    return '$_temp0';
  }

  @override
  String get internalPlayer => 'Внатрешен (VLC)';

  @override
  String get builtInPlayer => 'Вграден плеер';

  @override
  String get customNotSet => 'Приспособено (не е поставено)';

  @override
  String selectGesture(String side) {
    return 'Избери $side гест';
  }

  @override
  String get left => 'лев';

  @override
  String get right => 'десен';

  @override
  String get selectSeekDuration => 'Избери времетраење на пребарувањето';

  @override
  String get subtitleSettings => 'Поставки за титлови';

  @override
  String size(int size) {
    return 'Големина: $size';
  }

  @override
  String get background => 'Позадина';

  @override
  String get customDohUrlLabel => 'Приспособен DoH URL';

  @override
  String get enterCustomDohUrl => 'Внесете ваш DoH URL';

  @override
  String get chooseTheme => 'Избери тема';

  @override
  String get resetDataDialogTitle => 'Ресетирање податоци?';

  @override
  String get resetDataDialogContent =>
      'Ова ќе ги исчисти Поставките, Омилените и Историјата. Инсталираните екстензии НЕМА да бидат избришани.';

  @override
  String get factoryResetDialogTitle => 'Фабричко ресетирање?';

  @override
  String get factoryResetDialogContent =>
      'Ова ќе избрише СÈ. Оваа акција е неповратна.';

  @override
  String get selectLanguage => 'Избери јазик';

  @override
  String get synopsis => 'Синопсис';

  @override
  String get noDescription => 'Нема достапен опис.';

  @override
  String get videoAlreadyDownloadedPrompt =>
      'Ова видео е веќе преземено. Што сакате да направите?';

  @override
  String get playNow => 'Гледај сега';

  @override
  String get upNext => 'Следно';

  @override
  String get deleteDownloadPrompt => 'Избриши преземање?';

  @override
  String get deleteDownloadConfirmation =>
      'Дали сте сигурни дека сакате да ја избришете оваа датотека? Ова не може да се врати.';

  @override
  String get no => 'Не';

  @override
  String get yesDelete => 'Да, избриши';

  @override
  String get downloadPaused => 'Преземањето е паузирано';

  @override
  String get downloading => 'Преземање';

  @override
  String get speed => 'Брзина';

  @override
  String get remaining => 'Преостанато';

  @override
  String get resume => 'Продолжи';

  @override
  String get pause => 'Пауза';

  @override
  String get torrentContent => 'Содржина на торент';

  @override
  String get audioTracks => 'Аудио записи';

  @override
  String get noAudioTracks => 'Не се пронајдени аудио записи';

  @override
  String get subtitles => 'Титлови';

  @override
  String get options => 'Опции';

  @override
  String get noSubtitlesFound => 'Не се пронајдени титлови';

  @override
  String get playbackSpeed => 'Брзина на репродукција';

  @override
  String get subtitleOptions => 'Опции за титлови';

  @override
  String get hlsSubtitleWarning =>
      'Надворешни титлови не се поддржани за HLS на оваа платформа.';

  @override
  String get loadFromDevice => 'Вчитај од уред';

  @override
  String get syncDelay => 'Синхронизација / Доцнење';

  @override
  String get styleSettings => 'Поставки за стил';

  @override
  String get searchOnline => 'Пребарај онлајн (пребарување титлови)';

  @override
  String get subtitleSync => 'Синхронизација на титлови';

  @override
  String get subtitleDelayWarning =>
      'Доцнењето на титловите не е поддржано од тековниот плеер.';

  @override
  String get resetDelay => 'Ресетирај доцнење';

  @override
  String get subtitleStyles => 'Стилови на титлови';

  @override
  String get resetToDefault => 'Врати на стандардно';

  @override
  String get fontSize => 'Големина на фонт';

  @override
  String get verticalPosition => 'Вертикална позиција';

  @override
  String get textColor => 'Боја на текст';

  @override
  String get backgroundColor => 'Боја на позадина';

  @override
  String get backgroundOpacity => 'Проѕирност на позадина';

  @override
  String get subtitleSearch => 'Пребарување титлови';

  @override
  String get searchSubtitleNameHint => 'Име на титл...';

  @override
  String get enterSearchSubtitlePrompt => 'Внесете име за пребарување титлови.';

  @override
  String get noSubtitleResults =>
      'Нема резултати. Обидете се со друго пребарување.';

  @override
  String get downloadingApplyingSubtitle => 'Преземање и применување титл...';

  @override
  String get failedToDownloadSubtitle => 'Неуспешно преземање титл.';

  @override
  String get failedToLoadSubtitles =>
      'Неуспешно вчитување титлови. Обидете се повторно.';

  @override
  String get noReposFound => 'Не се пронајдени репозиториуми или приклучоци';

  @override
  String get downloadAllProviders => 'Преземи ги сите';

  @override
  String get removeRepository => 'Отстрани репозиториум';

  @override
  String get addRepo => 'Додај репозиториум';

  @override
  String get extensionsNotInRepos => 'Екстензии надвор од репозиториуми';

  @override
  String get noLongerInRepo => 'Веќе не е на списокот во ниеден репозиториум';

  @override
  String get addRepoToBrowse => 'Додајте репозиториум за преглед на приклучоци';

  @override
  String get debugExtensions => 'Дебагирање екстензии';

  @override
  String removeRepoConfirm(String repoName) {
    return 'Отстранување на $repoName?';
  }

  @override
  String get removeRepoWarning =>
      'Ова ќе го отстрани репозиториумот и ќе ги деинсталира сите негови приклучоци.';

  @override
  String get addRepository => 'Додај репозиториум';

  @override
  String get repoUrlOrShortcode => 'URL на репозиториум или краток код';

  @override
  String get assetPlugin => 'Вграден приклучок';

  @override
  String get installed => 'Инсталирано';

  @override
  String get repositories => 'Складишта';

  @override
  String get noExtensionsInstalled => 'Нема инсталирани екстензии';

  @override
  String get browseRepositoriesToInstall =>
      'Отвори го јазичето „Складишта“ за да откриеш и инсталираш екстензии.';

  @override
  String get browseRepositories => 'Прегледај складишта';

  @override
  String get addRepoDescription =>
      'Додај URL на складиште или краток код за да откриеш и инсталираш приклучоци.';

  @override
  String updateTo(String version) {
    return 'Ажурирај на $version';
  }

  @override
  String get install => 'Инсталирај';

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
  String get error => 'Грешка';

  @override
  String get ok => 'ОК';

  @override
  String pluginSettings(String pluginName) {
    return 'Поставки за $pluginName';
  }

  @override
  String get movies => 'Филмови';

  @override
  String get series => 'Серии';

  @override
  String get anime => 'Аниме';

  @override
  String get liveStreams => 'Стримови во живо';

  @override
  String get debug => 'ДЕБАГИРАЊЕ';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count екстензии се ажурирани',
      one: '1 екстензија е ажурирана',
    );
    return '$_temp0';
  }

  @override
  String extensionsNewRepositories(int count, String source) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count нови складишта во $source',
      one: '$count ново складиште во $source',
    );
    return '$_temp0';
  }

  @override
  String extensionsNewPlugins(int count, String repository) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count нови приклучоци во $repository',
      one: '$count нов приклучок во $repository',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => 'Невалидна навигација. Ве молиме вратете се.';

  @override
  String get startOver => 'Почни од почеток';

  @override
  String get goBack => 'Назад';

  @override
  String get restartApp => 'Рестартирај ја апликацијата';

  @override
  String get resolving => 'Разрешување...';

  @override
  String get downloaded => 'Преземено';

  @override
  String get download => 'Преземи';

  @override
  String get debugOnlyFeature =>
      'Оваа функција е достапна само во дебаг верзии';

  @override
  String get streamUrl => 'URL на стрим';

  @override
  String get play => 'Пушти';

  @override
  String get verifyingSourceSize => 'Проверка на извор и големина...';

  @override
  String get fileSaveLocationNotification =>
      'Датотеката ќе биде зачувана во папката за преземања.';

  @override
  String get resumingPlayback => 'Продолжување со репродукција';

  @override
  String pausedAt(String time) {
    return 'Паузирано на $time';
  }

  @override
  String resumesAutomatically(int count) {
    return 'Автоматски ќе продолжи за $count сек';
  }

  @override
  String get resumeNow => 'Продолжи сега';

  @override
  String get playbackError => 'Грешка при репродукција';

  @override
  String get confirmClearHistory =>
      'Дали сте сигурни дека сакате да ја исчистите целата историја?';

  @override
  String seasonWithNumber(Object number) {
    return 'Сезона $number';
  }

  @override
  String get starting => 'Стартување...';

  @override
  String percentWatched(int percent) {
    return '$percent% изгледано';
  }

  @override
  String get sub => 'Титл';

  @override
  String get dub => 'Дуб';

  @override
  String playEpisode(String label, Object season, Object episode) {
    return '$label С$season Е$episode';
  }

  @override
  String playEpisodeOnly(String label, int episode) {
    return '$label E$episode';
  }

  @override
  String get debugTools => 'Алатки за дебагирање';

  @override
  String get playLocalVideo => 'Локално видео';

  @override
  String get playLocalVideoSubtitle => 'Пушти датотека од уред';

  @override
  String get streamUrlSubtitle => 'Пушти од мрежен URL';

  @override
  String get streamTorrent => 'Стримувај торент';

  @override
  String get streamTorrentSubtitle =>
      'Избери локална торент датотека за пуштање';

  @override
  String get loadPluginFromAssets => 'Вчитај приклучок од асети';

  @override
  String get enterVideoUrlHint => 'Внесете URL на видео (http, magnet итн.)';

  @override
  String get networkStream => 'Мрежен стрим';

  @override
  String removedFromHistory(String title) {
    return 'Отстрането од историја: $title';
  }

  @override
  String get custom => 'Приспособено';

  @override
  String get refreshingLiveStream => 'Освежување на стрим...';

  @override
  String get removeFromHistory => 'Отстрани од историја';

  @override
  String get live => 'ВО ЖИВО';

  @override
  String get volume => 'Јачина на звук';

  @override
  String get decrease => 'Decrease';

  @override
  String get increase => 'Increase';

  @override
  String get brightness => 'Осветленост';

  @override
  String get fit => 'Приспособи';

  @override
  String get zoom => 'Зум';

  @override
  String get stretch => 'Растегни';

  @override
  String titleWithParam(String title) {
    return 'Наслов: $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'Извор: $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'Големина: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'Грешка: $error. Се користи внатрешен плеер.';
  }

  @override
  String externalPlayerCannotSendHeaders(String playerName, String headers) {
    return '$playerName cannot send $headers. Using internal player.';
  }

  @override
  String playerNotDetected(String playerName) {
    return '$playerName не е пронајден. Се стартува внатрешниот плеер.';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return 'Сезона $number ($count епиз.)';
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
    return 'Извор за $playerName';
  }

  @override
  String get noPluginsInstalled => 'Нема инсталирано приклучоци';

  @override
  String get noPluginsMessage =>
      'Инсталирајте додатоци за прелистување и стримување содржини.';

  @override
  String get goToExtensions => 'Оди до додатоци';

  @override
  String get availableSources => 'Достапни извори';

  @override
  String get seasons => 'Сезони';

  @override
  String get episodes => 'Епизоди';

  @override
  String get selectSourceToPlay =>
      'Ве молиме изберете извор од листата погоре.';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count епизоди',
      one: '1 епизода',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'Не се пронајдени епизоди';

  @override
  String get local => 'Локално';

  @override
  String get remote => 'Далечинско';

  @override
  String get torrent => 'Торент';

  @override
  String get unlock => 'Отклучи';

  @override
  String get lock => 'Заклучи';

  @override
  String get sources => 'Извори';

  @override
  String get tracks => 'Записи';

  @override
  String get content => 'Содржина';

  @override
  String get stats => 'Статистика';

  @override
  String get resize => 'Големина';

  @override
  String get next => 'Следно';

  @override
  String get previous => 'Previous';

  @override
  String get pip => 'PiP';

  @override
  String get rotate => 'Ротирај';

  @override
  String get windowed => 'Прозорец';

  @override
  String get fullscreen => 'Цел екран';

  @override
  String get movieDetails => 'Детали за филмот';

  @override
  String get showDetails => 'Види детали';

  @override
  String get tagline => 'Таглајн';

  @override
  String get status => 'Статус';

  @override
  String get releaseDate => 'Датум на издавање';

  @override
  String get firstAirDate => 'Прво емитување';

  @override
  String get originalLanguage => 'Оригинален јазик';

  @override
  String get originCountry => 'Земја на потекло';

  @override
  String get budgetLabel => 'Буџет';

  @override
  String get revenueLabel => 'Приход';

  @override
  String get paused => 'Паузирано';

  @override
  String get watched => 'Изгледано';

  @override
  String get watching => 'Гледање';

  @override
  String get lastWatched => 'Последно гледано';

  @override
  String get movie => 'Филм';

  @override
  String get tvShow => 'Серија';

  @override
  String get failedToLoadContent => 'Неуспешно вчитување';

  @override
  String get director => 'Режисер';

  @override
  String get creator => 'Креатор';

  @override
  String get showMore => 'Повеќε';

  @override
  String get showLess => 'Помалку';

  @override
  String get viewAll => 'Види ги сите';

  @override
  String seasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сезони',
      one: '1 сезона',
    );
    return '$_temp0';
  }

  @override
  String get noInternetError => 'Нема интернет';

  @override
  String get timeoutError => 'Времето истече. Обидете се повторно.';

  @override
  String get serverError => 'Грешка на серверот. Обидете се подоцна.';

  @override
  String get contentNotFoundError => 'Не е пронајдено.';

  @override
  String get accessDeniedError => 'Пристапот е одбиен.';

  @override
  String get serviceUnavailableError => 'Услугата е недостапна.';

  @override
  String get generalError => 'Се појави проблем.';

  @override
  String get skip => 'Прескокни';

  @override
  String get skipIntro => 'Прескокни вовед';

  @override
  String get skipOutro => 'Прескокни крај';

  @override
  String get skipRecap => 'Прескокни резиме';

  @override
  String get goLive => 'Оди во живо';

  @override
  String get dismiss => 'Отфрли';

  @override
  String get nextUp => 'Следно';

  @override
  String sourceAttempt(int index, int total) {
    return 'Извор $index од $total';
  }

  @override
  String get trying => 'Се обидува';

  @override
  String get failed => 'Неуспешно';

  @override
  String get selected => 'Избрано';

  @override
  String get playing => 'Репродуцира';

  @override
  String get pending => 'Во исчекување';

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
  String get mobileQualityPreference => 'Преференца за мобилен квалитет';

  @override
  String get anyNoPreference => 'Било кој (без преференца)';

  @override
  String get subtitleAccounts => 'Сметки за превод';

  @override
  String get accounts => 'Сметки';

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
  String get testConnection => 'Тестирај ја врската';

  @override
  String get connectedSuccessfully => 'Успешно поврзано';

  @override
  String get connectionFailed => 'Поврзувањето не успеа';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get noAccountRegister => 'Don\'t have an account? Register here';

  @override
  String get apiKey => 'API клуч';

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
      'Квалитетот не е загарантиран. Изворите се подредуваат според оваа поставка, а стрим со повеќе квалитети се пушта во неа или во најблискиот понизок. Репродукцијата зависи од тоа што давателот навистина нуди.';

  @override
  String get keepSourcesOriginalOrder => 'Keep sources in original order';

  @override
  String get openLink => 'Open link';

  @override
  String get diagnostics => 'Дијагностика';

  @override
  String get viewLogs => 'Види дневници';

  @override
  String get viewLogsSubtitle => 'Види активност на апликацијата и грешки';

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
  String get showRotate => 'Копче за ротирање';

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
  String get sourcesSearching => 'Пребарување во скрејперите…';

  @override
  String get sourcesEmptyFiltered => 'Ниту една врска не одговара на филтрите.';

  @override
  String get sourcesEmptyNoTmdbId =>
      'Нема TMDB ID за овој наслов. Внесете го преку \'Search manually\'.';

  @override
  String get sourcesEmptyNoScrapers =>
      'Нема вклучени скрејпери. Додајте во \'Nuvio Plugins\'.';

  @override
  String get sourcesEmptyAllFailed =>
      'Сите скрејпери не успеаја. Проверете ја врската или ажурирајте ги.';

  @override
  String sourcesEmptySomeFailed(int failed, int total) {
    return 'Не се најдени врски. $failed од $total скрејпери не успеаја.';
  }

  @override
  String get sourcesEmptyNothingFound =>
      'Ниту еден од вашите скрејпери го нема овој наслов.';

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
  String get showStatusOngoing => 'Во тек';

  @override
  String get showStatusCompleted => 'Завршена';

  @override
  String get comingSoon => 'Наскоро';

  @override
  String episodeAirsOn(String date) {
    return 'Се емитува на $date';
  }

  @override
  String seasonNumberAndName(Object number, String name) {
    return 'Сезона $number: $name';
  }

  @override
  String castLine(String names) {
    return 'Актерска екипа: $names';
  }

  @override
  String get actorRoleMain => 'Главна';

  @override
  String get actorRoleSupporting => 'Споредна';

  @override
  String get actorRoleBackground => 'Епизодна';

  @override
  String get playerQuality => 'Квалитет';

  @override
  String get playerQualityAuto => 'Автоматски';

  @override
  String playerQualityAutoPlaying(String height) {
    return 'Автоматски · $height';
  }

  @override
  String get networkBufferAuto => 'Автоматски (препорачано)';

  @override
  String get networkBufferAutoHint =>
      'Големината се одредува за секое видео според неговата брзина на битови и меморијата на овој уред.';

  @override
  String get devQoeLog => 'QoE дневник';

  @override
  String get devQoeLogSubtitle =>
      'Ги запишува времињата на репродукција во дневникот на апликацијата';

  @override
  String get playerGoLive => 'Оди на во живо';

  @override
  String playerBehindLive(String time) {
    return '$time зад преносот во живо';
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
