// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Belarusian (`be`).
class AppLocalizationsBe extends AppLocalizations {
  AppLocalizationsBe([String locale = 'be']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => 'Беларуская';

  @override
  String get addonHealthChecking => 'Checking add-on…';

  @override
  String addonHealthWorking(int ms) {
    return 'Working · $ms ms';
  }

  @override
  String get addonHealthUnavailable => 'Unavailable';

  @override
  String get home => 'Галоўная';

  @override
  String get search => 'Пошук';

  @override
  String get explore => 'Даследаваць';

  @override
  String get exploreAnime => 'Агляд анімэ';

  @override
  String get exploreMovies => 'Агляд фільмаў';

  @override
  String get library => 'Бібліятэка';

  @override
  String get settings => 'Налады';

  @override
  String get extensions => 'Пашырэнні';

  @override
  String get updateAvailable => 'Даступна абнаўленне';

  @override
  String get retry => 'Паўтарыць';

  @override
  String get factoryReset => 'Скід да заводскіх налад';

  @override
  String get startupError => 'Памылка запуску';

  @override
  String get general => 'Агульныя';

  @override
  String get appTheme => 'Тэма праграмы';

  @override
  String get recordWatchHistory => 'Запісваць гісторыю праглядаў';

  @override
  String get fullScreenMode => 'На ўвесь экран';

  @override
  String get fullScreenModeSubtitle => 'Пераключае на тэлевізійны інтэрфейс';

  @override
  String get defaultHomeScreen => 'Галоўны экран па змаўчанні';

  @override
  String get titlePosition => 'Пазіцыя назвы';

  @override
  String get titlePositionBelowPoster => 'Пад пастарам';

  @override
  String get titlePositionInsidePoster => 'Унутры пастара';

  @override
  String get player => 'Плэер';

  @override
  String get defaultPlayer => 'Плэер па змаўчанні';

  @override
  String get leftGesture => 'Левы жэст';

  @override
  String get rightGesture => 'Правы жэст';

  @override
  String get doubleTapToSeek => 'Двайная заклаца для перамоткі';

  @override
  String get swipeToSeek => 'Жэст для перамоткі';

  @override
  String get seekDuration => 'Працягласць перамоткі';

  @override
  String get defaultResizeMode => 'Рэжым маштабавання па змаўчанні';

  @override
  String get hardwareDecoding => 'Апаратнае дэкадаванне';

  @override
  String get network => 'Сетка';

  @override
  String get dnsOverHttps => 'DNS праз HTTPS';

  @override
  String get dohProvider => 'Провайдэр DoH';

  @override
  String get githubProxy => 'Проксі GitHub';

  @override
  String get githubProxySubtitle =>
      'Накіроўваць спампоўку пашырэнняў праз jsDelivr, каб абыйсці блакіроўкі правайдара.';

  @override
  String get manageExtensions => 'Кіраванне пашырэннямі';

  @override
  String get appData => 'Даныя праграмы';

  @override
  String get resetDataKeepExtensions => 'Скінуць даныя (захаваць пашырэнні)';

  @override
  String get developer => 'Распрацоўшчык';

  @override
  String get developerOptions => 'Опцыі распрацоўшчыка';

  @override
  String get about => 'Пра праграму';

  @override
  String get version => 'Версія';

  @override
  String get enabled => 'Уключана';

  @override
  String get disabled => 'Выключана';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'Далучайцеся да нашага сервера';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'Далучайцеся да нашага канала';

  @override
  String developedBy(String name) {
    return 'Developed by $name';
  }

  @override
  String get system => 'Сістэмная';

  @override
  String get dark => 'Цёмная';

  @override
  String get light => 'Светлая';

  @override
  String get later => 'Пазней';

  @override
  String get updateNow => 'Абнавіць зараз';

  @override
  String get save => 'Захаваць';

  @override
  String get cancel => 'Адмена';

  @override
  String get close => 'Закрыць';

  @override
  String get delete => 'Выдаліць';

  @override
  String get viewDetails => 'Падрабязнасці';

  @override
  String get clearAll => 'Ачысціць усё';

  @override
  String get clearAllHistory => 'Ачысціць усю гісторыю';

  @override
  String get all => 'Усе';

  @override
  String get none => 'Няма';

  @override
  String get confirmDownload => 'Пацвердзіць загрузку';

  @override
  String get downloadNow => 'Загрузіць зараз';

  @override
  String get selectSource => 'Выбраць крыніцу';

  @override
  String get downloadUnavailable => 'Загрузка недаступная';

  @override
  String get selectAnotherSource => 'Выбраць іншую крыніцу';

  @override
  String get watchHistoryCleared => 'Гісторыя праглядаў ачышчана';

  @override
  String get downloadingUpdate => 'Загрузка абнаўлення...';

  @override
  String errorPrefix(String message) {
    return 'Памылка: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'Даступна абнаўленне: $tag';
  }

  @override
  String get selectProviderToStart => 'Выберыце правайдэра, каб пачаць';

  @override
  String get tapExtensionIcon => 'Націсніце на значок пашырэння ў куце';

  @override
  String get continueWatching => 'Працягнуць прагляд';

  @override
  String get noInternetConnection => 'Няма падключэння да інтэрнэту';

  @override
  String get siteNotReachable => 'Сайт недаступны';

  @override
  String get checkConnectionOrDownloads =>
      'Праверце падключэнне або паглядзіце загрузкі.';

  @override
  String get tryVpnOrConnection => 'Паспрабуйце VPN або праверце інтэрнэт.';

  @override
  String errorDetails(String error) {
    return 'Дэталі памылкі: $error';
  }

  @override
  String get goToDownloads => 'Перайсці да загрузак';

  @override
  String get selectProvider => 'Выбраць правайдэра';

  @override
  String get searchHint => 'Пошук фільмаў, серыялаў...';

  @override
  String get searchFavoriteContent => 'Шукайце любімы кантэнт';

  @override
  String get pressSearchOrEnter => 'Націсніце Пошук або Enter, каб пачаць';

  @override
  String get recentSearches => 'Recent searches';

  @override
  String removeFromSearchHistory(String query) {
    return 'Remove $query from search history';
  }

  @override
  String get noResultsFound => 'Вынікаў не знойдзено.';

  @override
  String get couldNotLoadTrending => 'Не ўдалося загрузіць папулярнае';

  @override
  String get popularMovies => 'Папулярныя фільмы';

  @override
  String get popularTVShows => 'Папулярныя серыялы';

  @override
  String get newMovies => 'Новыя фільмы';

  @override
  String get newTVShows => 'Новыя серыялы';

  @override
  String get featuredMovies => 'Рэкамендаваныя фільмы';

  @override
  String get featuredTVShows => 'Рэкамендаваныя серыялы';

  @override
  String get lastVideosTVShows => 'Апошнія серыялы';

  @override
  String get downloads => 'Загрузкі';

  @override
  String get bookmarks => 'Закладкі';

  @override
  String get noDownloadsYet => 'Загрузак пакуль няма';

  @override
  String episodesCount(int count, int done) {
    return 'Эпізодаў: $count • Скончана: $done';
  }

  @override
  String get deleteAllEpisodes => 'Выдаліць усе эпізоды';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return 'Вы сапраўды хочаце выдаліць усе $count эпізоды \"$title\" і іх файлы?';
  }

  @override
  String get deleteAll => 'Выдаліць усё';

  @override
  String get completed => 'Скончана';

  @override
  String get statusQueued => 'У чарзе...';

  @override
  String get statusDownloading => 'Загрузка...';

  @override
  String get statusFinished => 'Завершана';

  @override
  String get statusFailed => 'Памылка';

  @override
  String get statusCanceled => 'Адменена';

  @override
  String get statusPaused => 'Прыпынена';

  @override
  String get statusWaiting => 'Чаканне...';

  @override
  String get fileNotFoundRemoving => 'Файл не знойдзены. Выдаленне запісу.';

  @override
  String get fileNotFound => 'Файл не знойдзены';

  @override
  String get deleteDownload => 'Выдаліць загрузку';

  @override
  String get confirmDeleteDownload =>
      'Вы сапраўды хочаце выдаліць гэтую загрузку і яе файл?';

  @override
  String get libraryEmpty => 'Бібліятэка пустая';

  @override
  String get language => 'Мова';

  @override
  String get english => 'Англійская';

  @override
  String get hindi => 'Хіндзі';

  @override
  String get kannada => 'Канада';

  @override
  String get unknown => 'Невядома';

  @override
  String get recommended => 'Рэкамендавана';

  @override
  String get on => 'Укл';

  @override
  String get off => 'Выкл';

  @override
  String get installRemoveProviders => 'Усталяваць/выдаліць правайдэраў';

  @override
  String get resetDataSubtitle => 'Ачысціць налады і БД, захаваць плагіны';

  @override
  String get factoryResetSubtitle => 'Выдаліць усе даныя, налады і пашырэнні';

  @override
  String get developerOptionsSubtitle =>
      'Інструменты адладкі і лакальны прагляд';

  @override
  String get loading => 'Загрузка...';

  @override
  String get sec => 'с';

  @override
  String get min => 'мін';

  @override
  String playerRewindSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Назад на $count секунды',
      many: 'Назад на $count секунд',
      few: 'Назад на $count секунды',
      one: 'Назад на $count секунду',
    );
    return '$_temp0';
  }

  @override
  String playerForwardSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Наперад на $count секунды',
      many: 'Наперад на $count секунд',
      few: 'Наперад на $count секунды',
      one: 'Наперад на $count секунду',
    );
    return '$_temp0';
  }

  @override
  String get internalPlayer => 'Унутраны (VLC)';

  @override
  String get builtInPlayer => 'Убудаваны плэер';

  @override
  String get customNotSet => 'Іншае (не вызначана)';

  @override
  String selectGesture(String side) {
    return 'Выбраць жэст ($side)';
  }

  @override
  String get left => 'левы';

  @override
  String get right => 'правы';

  @override
  String get selectSeekDuration => 'Выбраць працягласць перамоткі';

  @override
  String get subtitleSettings => 'Налады субтытраў';

  @override
  String size(int size) {
    return 'Памер: $size';
  }

  @override
  String get background => 'Фон';

  @override
  String get customDohUrlLabel => 'Уласны DoH URL';

  @override
  String get enterCustomDohUrl => 'Увядзіце свой DoH URL';

  @override
  String get chooseTheme => 'Выбраць тэму';

  @override
  String get resetDataDialogTitle => 'Скінуць даныя?';

  @override
  String get resetDataDialogContent =>
      'Гэта выдаліць Налады, Выбранае і Гісторыю. Усталяваныя пашырэнні ЗАСТАНУЦЦА.';

  @override
  String get factoryResetDialogTitle => 'Скід да заводскіх налад?';

  @override
  String get factoryResetDialogContent =>
      'Гэта выдаліць УСЁ: Выбранае, Гісторыю, Налады і ЎСЕ пашырэнні. Нельга адмяніць.';

  @override
  String get selectLanguage => 'Выбраць мову';

  @override
  String get synopsis => 'Сінопсіс';

  @override
  String get noDescription => 'Апісанне адсутнічае.';

  @override
  String get videoAlreadyDownloadedPrompt =>
      'Відэа ўжо загружана. Што вы хочаце зрабіць?';

  @override
  String get playNow => 'Глядзець зараз';

  @override
  String get upNext => 'Далей';

  @override
  String get deleteDownloadPrompt => 'Выдаліць загрузку?';

  @override
  String get deleteDownloadConfirmation =>
      'Вы сапраўды хочаце выдаліць гэты файл? Нельга адмяніць.';

  @override
  String get no => 'Не';

  @override
  String get yesDelete => 'Так, выдаліць';

  @override
  String get downloadPaused => 'Загрузка прыпынена';

  @override
  String get downloading => 'Загрузка';

  @override
  String get speed => 'Скорасць';

  @override
  String get remaining => 'Засталося';

  @override
  String get resume => 'Працягнуць';

  @override
  String get pause => 'Паўза';

  @override
  String get torrentContent => 'Змест торэнта';

  @override
  String get audioTracks => 'Аўдыядарожкі';

  @override
  String get noAudioTracks => 'Аўдыядарожкі не знойдзены';

  @override
  String get subtitles => 'Субтытры';

  @override
  String get options => 'Опцыі';

  @override
  String get noSubtitlesFound => 'Субтытры не знойдзены';

  @override
  String get playbackSpeed => 'Скорасць прайгравання';

  @override
  String get subtitleOptions => 'Опцыі субтытраў';

  @override
  String get hlsSubtitleWarning =>
      'Знешнія субтытры не падтрымліваюцца актыўным HLS-плэерам на гэтай платформе.';

  @override
  String get loadFromDevice => 'Загрузіць з прылады';

  @override
  String get syncDelay => 'Сінхранізацыя / затрымка';

  @override
  String get styleSettings => 'Налады стылю';

  @override
  String get searchOnline => 'Шукаць онлайн';

  @override
  String get subtitleSync => 'Сінхранізацыя субтытраў';

  @override
  String get subtitleDelayWarning =>
      'Затрымка субтытраў не падтрымліваюцца актыўным рухавіком плэера.';

  @override
  String get resetDelay => 'Скінуць затрымку';

  @override
  String get subtitleStyles => 'Стылі субтытраў';

  @override
  String get resetToDefault => 'Па змаўчанні';

  @override
  String get fontSize => 'Памер шрыфта';

  @override
  String get verticalPosition => 'Вертыкальнае становішча';

  @override
  String get textColor => 'Колер тэксту';

  @override
  String get backgroundColor => 'Колер фону';

  @override
  String get backgroundOpacity => 'Празрыстасць фону';

  @override
  String get subtitleSearch => 'Пошук субтытраў';

  @override
  String get searchSubtitleNameHint => 'Назва субтытраў...';

  @override
  String get enterSearchSubtitlePrompt =>
      'Увядзіце назву для пошуку субтытраў.';

  @override
  String get noSubtitleResults => 'Вынікаў не знойдзено.';

  @override
  String get downloadingApplyingSubtitle =>
      'Загрузка і прымяненне субтытраў...';

  @override
  String get failedToDownloadSubtitle => 'Не ўдалося загрузіць субтытры.';

  @override
  String get failedToLoadSubtitles =>
      'Не ўдалося загрузіць субтытры. Паспрабуйце зноў.';

  @override
  String get noReposFound => 'Рэпазіторыі або плагіны не знойдзены';

  @override
  String get downloadAllProviders => 'Спампаваць усё';

  @override
  String get removeRepository => 'Выдаліць рэпазіторый';

  @override
  String get addRepo => 'Дадаць рэпазіторый';

  @override
  String get extensionsNotInRepos => 'Пашырэнні не з рэпазіторыяў';

  @override
  String get noLongerInRepo => 'Больш не значыцца ў рэпазіторыях';

  @override
  String get addRepoToBrowse => 'Дадайце рэпазіторый, каб бачыць плагіны';

  @override
  String get debugExtensions => 'Адладка пашырэнняў';

  @override
  String removeRepoConfirm(String repoName) {
    return 'Выдаліць $repoName?';
  }

  @override
  String get removeRepoWarning =>
      'Гэта выдаліць рэпазіторый і ЎСЕ яго плагіны.';

  @override
  String get addRepository => 'Дадаць рэпазіторый';

  @override
  String get repoUrlOrShortcode => 'URL рэпазіторыя або шорткод';

  @override
  String get assetPlugin => 'Убудаваны плагін';

  @override
  String get installed => 'Усталявана';

  @override
  String get repositories => 'Рэпазіторыі';

  @override
  String get noExtensionsInstalled => 'Пашырэнні не ўсталяваныя';

  @override
  String get browseRepositoriesToInstall =>
      'Адкрыйце ўкладку «Рэпазіторыі», каб знайсці і ўсталяваць пашырэнні.';

  @override
  String get browseRepositories => 'Агляд рэпазіторыяў';

  @override
  String get addRepoDescription =>
      'Дадайце URL рэпазіторыя або кароткі код, каб знайсці і ўсталяваць плагіны пашырэнняў.';

  @override
  String updateTo(String version) {
    return 'Абнавіць да $version';
  }

  @override
  String get install => 'Усталяваць';

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
  String get error => 'Памылка';

  @override
  String get ok => 'OK';

  @override
  String pluginSettings(String pluginName) {
    return 'Налады $pluginName';
  }

  @override
  String get movies => 'Фільмы';

  @override
  String get series => 'Серыялы';

  @override
  String get anime => 'Анімэ';

  @override
  String get liveStreams => 'Жывыя эфіры';

  @override
  String get debug => 'DEBUG';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count пашырэння абноўлена',
      many: '$count пашырэнняў абноўлена',
      few: '$count пашырэнні абноўлена',
      one: '1 пашырэнне абноўлена',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => 'Памылка навігацыі. Вярніцеся назад.';

  @override
  String get startOver => 'Пачаць спачатку';

  @override
  String get goBack => 'Назад';

  @override
  String get restartApp => 'Перазапусціць праграму';

  @override
  String get resolving => 'Пошук спасылак...';

  @override
  String get downloaded => 'Загружана';

  @override
  String get download => 'Спампаваць';

  @override
  String get debugOnlyFeature =>
      'Гэтая функцыя даступная толькі ў рэжыме адладкі';

  @override
  String get streamUrl => 'URL патоку';

  @override
  String get play => 'Глядзець';

  @override
  String get verifyingSourceSize => 'Праверка крыніцы і памеру...';

  @override
  String get fileSaveLocationNotification =>
      'Файл будзе захаваны ў папку загрузак.';

  @override
  String get resumingPlayback => 'Аднаўленне прайгравання';

  @override
  String pausedAt(String time) {
    return 'Прыпынена на $time';
  }

  @override
  String resumesAutomatically(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Аўтаматычны старт праз $count секунды',
      many: 'Аўтаматычны старт праз $count секунд',
      few: 'Аўтаматычны старт праз $count секунды',
      one: 'Аўтаматычны старт праз 1 секунду',
    );
    return '$_temp0';
  }

  @override
  String get resumeNow => 'Глядзець зараз';

  @override
  String get playbackError => 'Памылка прайгравання';

  @override
  String get confirmClearHistory => 'Вы сапраўды хочаце ачысціць усю гісторыю?';

  @override
  String seasonWithNumber(Object number) {
    return 'Сезон $number';
  }

  @override
  String get starting => 'Запуск...';

  @override
  String percentWatched(int percent) {
    return 'Прагледжана: $percent%';
  }

  @override
  String get sub => 'Суб';

  @override
  String get dub => 'Дуб';

  @override
  String playEpisode(String label, Object season, Object episode) {
    return '$label С$season Э$episode';
  }

  @override
  String playEpisodeOnly(String label, int episode) {
    return '$label E$episode';
  }

  @override
  String get debugTools => 'Інструменты адладкі';

  @override
  String get playLocalVideo => 'Лакальнае відэа';

  @override
  String get playLocalVideoSubtitle => 'Глядзець відэа з прылады';

  @override
  String get streamUrlSubtitle => 'Глядзець па URL';

  @override
  String get streamTorrent => 'Сторыміць торэнт';

  @override
  String get streamTorrentSubtitle => 'Выберыце торэнт-файл';

  @override
  String get loadPluginFromAssets => 'Загрузіць плагін з рэсурсаў';

  @override
  String get enterVideoUrlHint => 'URL відэа (http, magnet і г.д.)';

  @override
  String get networkStream => 'Сеткавы паток';

  @override
  String removedFromHistory(String title) {
    return 'Выдалена з гісторыі: $title';
  }

  @override
  String get custom => 'Уласнае';

  @override
  String get refreshingLiveStream => 'Абнаўленне эфіру...';

  @override
  String get removeFromHistory => 'Выдаліць з гісторыі';

  @override
  String get live => 'ЖЫВЫ ЭФІР';

  @override
  String get volume => 'Гучнасць';

  @override
  String get decrease => 'Decrease';

  @override
  String get increase => 'Increase';

  @override
  String get brightness => 'Яркасць';

  @override
  String get fit => 'Запоўніць';

  @override
  String get zoom => 'Зум';

  @override
  String get stretch => 'Расцягнуць';

  @override
  String titleWithParam(String title) {
    return 'Назва: $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'Крыніца: $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'Памер: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'Памылка: $error. Выкарыстоўваецца ўнутраны плэер.';
  }

  @override
  String externalPlayerCannotSendHeaders(String playerName, String headers) {
    return '$playerName cannot send $headers. Using internal player.';
  }

  @override
  String playerNotDetected(String playerName) {
    return '$playerName не знойдзены. Запуск унутранага плэера.';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return 'Сезон $number ($count эп.)';
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
    return 'Выбраць крыніцу для $playerName';
  }

  @override
  String get noPluginsInstalled => 'Няма ўсталяваных плагінаў';

  @override
  String get noPluginsMessage =>
      'Усталюйце пашырэнні для прагляду і трансляцыі кантэнту.';

  @override
  String get goToExtensions => 'Перайсці да пашырэнняў';

  @override
  String get availableSources => 'Даступныя крыніцы';

  @override
  String get seasons => 'Сезоны';

  @override
  String get episodes => 'Эпізоды';

  @override
  String get selectSourceToPlay =>
      'Выберыце крыніцу вышэй, каб пачаць прагляд.';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count эпізода',
      many: '$count эпізодаў',
      few: '$count эпізоды',
      one: '1 эпізод',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'Эпізоды не знойдзены';

  @override
  String get local => 'Лакальная';

  @override
  String get remote => 'Аддаленая';

  @override
  String get torrent => 'Торэнт';

  @override
  String get unlock => 'Разблакіраваць';

  @override
  String get lock => 'Заблакіраваць';

  @override
  String get sources => 'Крыніцы';

  @override
  String get tracks => 'Дарожкі';

  @override
  String get content => 'Кантэнт';

  @override
  String get stats => 'Статыстыка';

  @override
  String get resize => 'Памер';

  @override
  String get next => 'Наступны';

  @override
  String get previous => 'Previous';

  @override
  String get pip => 'PiP';

  @override
  String get rotate => 'Павярнуць';

  @override
  String get windowed => 'У акне';

  @override
  String get fullscreen => 'На ўвесь экран';

  @override
  String get movieDetails => 'Дэталі фільма';

  @override
  String get showDetails => 'Паказаць дэталі';

  @override
  String get tagline => 'Тэглайн';

  @override
  String get status => 'Статус';

  @override
  String get releaseDate => 'Дата выхаду';

  @override
  String get firstAirDate => 'Першы эфір';

  @override
  String get originalLanguage => 'Арыгінальная мова';

  @override
  String get originCountry => 'Краіна паходжання';

  @override
  String get budgetLabel => 'Бюджэт';

  @override
  String get revenueLabel => 'Зборы';

  @override
  String get paused => 'Прыпынена';

  @override
  String get watched => 'Прагледжана';

  @override
  String get watching => 'Гляджу';

  @override
  String get lastWatched => 'Апошні прагляд';

  @override
  String get movie => 'Фільм';

  @override
  String get tvShow => 'Серыял';

  @override
  String get failedToLoadContent => 'Не ўдалося загрузіць кантэнт';

  @override
  String get director => 'Рэжысёр';

  @override
  String get creator => 'Стваральнік';

  @override
  String get showMore => 'Больш';

  @override
  String get showLess => 'Менш';

  @override
  String get viewAll => 'Усе';

  @override
  String seasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сезона',
      many: '$count сезонаў',
      few: '$count сезоны',
      one: '1 сезон',
    );
    return '$_temp0';
  }

  @override
  String get noInternetError => 'Няма інтэрнэту';

  @override
  String get timeoutError => 'Час чакання выйшаў.';

  @override
  String get serverError => 'Памылка сервера.';

  @override
  String get contentNotFoundError => 'Кантэнт не знойдзены.';

  @override
  String get accessDeniedError => 'Доступ забаронены.';

  @override
  String get serviceUnavailableError => 'Сервіс недаступны.';

  @override
  String get generalError => 'Нешта пайшло не так.';

  @override
  String get skip => 'Прапусціць';

  @override
  String get skipIntro => 'Прапусціць уступ';

  @override
  String get skipOutro => 'Прапусціць канцоўку';

  @override
  String get skipRecap => 'Прапусціць агляд';

  @override
  String get goLive => 'У эфір';

  @override
  String get dismiss => 'Закрыць';

  @override
  String get nextUp => 'Далей';

  @override
  String sourceAttempt(int index, int total) {
    return 'Крыніца $index з $total';
  }

  @override
  String get trying => 'Спроба';

  @override
  String get failed => 'Памылка';

  @override
  String get selected => 'Выбрана';

  @override
  String get playing => 'Прайграванне';

  @override
  String get pending => 'Чакае';

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
  String get mobileQualityPreference => 'Перавага якасці мабільнай сувязі';

  @override
  String get anyNoPreference => 'Любая (без пераваг)';

  @override
  String get subtitleAccounts => 'Уліковыя запісы субцітраў';

  @override
  String get accounts => 'Уліковыя запісы';

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
  String get testConnection => 'Праверыць злучэнне';

  @override
  String get connectedSuccessfully => 'Злучэнне паспяхова ўстаноўлена';

  @override
  String get connectionFailed => 'Злучэнне не атрымалася';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get noAccountRegister => 'Don\'t have an account? Register here';

  @override
  String get apiKey => 'Ключ API';

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
  String get diagnostics => 'Дыягностыка';

  @override
  String get viewLogs => 'Прагляд логаў';

  @override
  String get viewLogsSubtitle => 'Праглядзець актыўнасць праграмы і памылкі';

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
  String get sourcesSearching => 'Пошук у скрэйперах…';

  @override
  String get sourcesEmptyFiltered =>
      'Няма спасылак, якія адпавядаюць фільтрам.';

  @override
  String get sourcesEmptyNoTmdbId =>
      'Няма TMDB ID для гэтай назвы. Увядзіце яго праз \'Search manually\'.';

  @override
  String get sourcesEmptyNoScrapers =>
      'Няма ўключаных скрэйпераў. Дадайце ў \'Nuvio Plugins\'.';

  @override
  String get sourcesEmptyAllFailed =>
      'Усе скрэйперы не спрацавалі. Праверце злучэнне або абнавіце скрэйперы.';

  @override
  String sourcesEmptySomeFailed(int failed, int total) {
    return 'Спасылак не знойдзена. Не спрацавалі $failed з $total скрэйпераў.';
  }

  @override
  String get sourcesEmptyNothingFound =>
      'Ні ў аднаго з вашых скрэйпераў няма гэтай назвы.';

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
