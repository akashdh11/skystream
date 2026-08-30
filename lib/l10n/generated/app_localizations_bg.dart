// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bulgarian (`bg`).
class AppLocalizationsBg extends AppLocalizations {
  AppLocalizationsBg([String locale = 'bg']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => 'Български';

  @override
  String get home => 'Начало';

  @override
  String get search => 'Търсене';

  @override
  String get explore => 'Разгледайте';

  @override
  String get exploreAnime => 'Разгледай аниме';

  @override
  String get exploreMovies => 'Разгледай филми';

  @override
  String get library => 'Библиотека';

  @override
  String get settings => 'Настройки';

  @override
  String get extensions => 'Разширения';

  @override
  String get updateAvailable => 'Налична актуализация';

  @override
  String get retry => 'Повторение';

  @override
  String get factoryReset => 'Фабрично нулиране';

  @override
  String get startupError => 'Грешка при стартиране';

  @override
  String get general => 'Общи';

  @override
  String get appTheme => 'Тема на приложението';

  @override
  String get recordWatchHistory => 'История на гледане';

  @override
  String get defaultHomeScreen => 'Начален екран по подразбиране';

  @override
  String get titlePosition => 'Позиция на заглавието';

  @override
  String get titlePositionBelowPoster => 'Под постера';

  @override
  String get titlePositionInsidePoster => 'Върху постера';

  @override
  String get player => 'Плейър';

  @override
  String get defaultPlayer => 'Плейър по подразбиране';

  @override
  String get leftGesture => 'Ляв жест';

  @override
  String get rightGesture => 'Десен жест';

  @override
  String get doubleTapToSeek => 'Двойно потупване за търсене';

  @override
  String get swipeToSeek => 'Плъзгане за търсене';

  @override
  String get seekDuration => 'Продължителност на търсене';

  @override
  String get bufferDepth => 'Дълбочина на буфера';

  @override
  String get defaultResizeMode => 'Режим на преоразмеряване';

  @override
  String get hardwareDecoding => 'Хардуерно декодиране';

  @override
  String get network => 'Мрежа';

  @override
  String get dnsOverHttps => 'DNS върху HTTPS';

  @override
  String get dohProvider => 'DoH доставчик';

  @override
  String get githubProxy => 'GitHub прокси';

  @override
  String get githubProxySubtitle =>
      'Насочвайте изтеглянията на разширения през jsDelivr, за да заобиколите блокировки от доставчика.';

  @override
  String get manageExtensions => 'Управление на разширения';

  @override
  String get appData => 'Данни на приложението';

  @override
  String get resetDataKeepExtensions =>
      'Нулиране на данни (запазване на разширения)';

  @override
  String get developer => 'Разработчик';

  @override
  String get developerOptions => 'Опции за разработчици';

  @override
  String get about => 'Относно';

  @override
  String get version => 'Версия';

  @override
  String get enabled => 'Активирано';

  @override
  String get disabled => 'Деактивирано';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'Присъединете се към нашия сървър';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'Присъединете се към нашия канал';

  @override
  String developedBy(String name) {
    return 'Developed by $name';
  }

  @override
  String get system => 'Системна';

  @override
  String get dark => 'Тъмна';

  @override
  String get light => 'Светла';

  @override
  String get later => 'По-късно';

  @override
  String get updateNow => 'Актуализирай сега';

  @override
  String get save => 'Запази';

  @override
  String get cancel => 'Отказ';

  @override
  String get close => 'Затвори';

  @override
  String get delete => 'Изтрий';

  @override
  String get viewDetails => 'Виж детайли';

  @override
  String get clearAll => 'Изчисти всичко';

  @override
  String get clearAllHistory => 'Изчисти историята';

  @override
  String get all => 'Всички';

  @override
  String get none => 'Нищо';

  @override
  String get confirmDownload => 'Потвърди изтеглянето';

  @override
  String get downloadNow => 'Изтегли сега';

  @override
  String get selectSource => 'Избери източник';

  @override
  String get downloadUnavailable => 'Недостъпно';

  @override
  String get selectAnotherSource => 'Избери друг';

  @override
  String get watchHistoryCleared => 'Историята е изчистена';

  @override
  String get downloadingUpdate => 'Изтегляне на актуализация...';

  @override
  String errorPrefix(String message) {
    return 'Грешка: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'Налична актуализация: $tag';
  }

  @override
  String get selectProviderToStart => 'Изберете доставчик, за да започнете';

  @override
  String get tapExtensionIcon => 'Докоснете иконата на разширението в ъгъла';

  @override
  String get continueWatching => 'Продължи гледането';

  @override
  String get noInternetConnection => 'Няма интернет връзка';

  @override
  String get siteNotReachable => 'Сайтът е недостъпен';

  @override
  String get checkConnectionOrDownloads =>
      'Проверете връзката си или вижте изтеглянията.';

  @override
  String get tryVpnOrConnection => 'Опитайте с VPN или проверете връзката си.';

  @override
  String errorDetails(String error) {
    return 'Детайли за грешката: $error';
  }

  @override
  String get goToDownloads => 'Към изтеглянията';

  @override
  String get selectProvider => 'Избери доставчик';

  @override
  String get searchHint => 'Търсене на филми, сериали...';

  @override
  String get searchFavoriteContent => 'Търсете любимо съдържание';

  @override
  String get pressSearchOrEnter => 'Натиснете Търсене или Enter за начало';

  @override
  String get noResultsFound => 'Няма намерени резултати.';

  @override
  String get couldNotLoadTrending => 'Трендовете не могат да бъдат заредени';

  @override
  String get popularMovies => 'Популярни филми';

  @override
  String get popularTVShows => 'Популярни сериали';

  @override
  String get newMovies => 'Нови филми';

  @override
  String get newTVShows => 'Нови сериали';

  @override
  String get featuredMovies => 'Препоръчани филми';

  @override
  String get featuredTVShows => 'Препоръчани сериали';

  @override
  String get lastVideosTVShows => 'Последни епизоди';

  @override
  String get downloads => 'Изтегляния';

  @override
  String get bookmarks => 'Отметки';

  @override
  String get noDownloadsYet => 'Все още няма изтегляния';

  @override
  String episodesCount(int count, int done) {
    return '$count епизода • $done завършени';
  }

  @override
  String get deleteAllEpisodes => 'Изтрий всички епизоди';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return 'Сигурни ли сте, че искате да изтриете всички $count епизода на \"$title\"?';
  }

  @override
  String get deleteAll => 'Изтрий всичко';

  @override
  String get completed => 'Завършено';

  @override
  String get statusQueued => 'В опашка...';

  @override
  String get statusDownloading => 'Изтегляне...';

  @override
  String get statusFinished => 'Завършено';

  @override
  String get statusFailed => 'Неуспешно';

  @override
  String get statusCanceled => 'Отказано';

  @override
  String get statusPaused => 'Пауза';

  @override
  String get statusWaiting => 'Изчакване...';

  @override
  String get fileNotFoundRemoving =>
      'Файлът не е намерен. Премахване на записа.';

  @override
  String get fileNotFound => 'Файлът не е намерен';

  @override
  String get deleteDownload => 'Изтрий изтеглянето';

  @override
  String get confirmDeleteDownload =>
      'Сигурни ли сте, че искате да изтриете това изтегляне?';

  @override
  String get libraryEmpty => 'Библиотеката е празна';

  @override
  String get language => 'Език';

  @override
  String get english => 'Английски';

  @override
  String get hindi => 'Хинди';

  @override
  String get kannada => 'Каннада';

  @override
  String get unknown => 'Неизвестен';

  @override
  String get recommended => 'Препоръчано';

  @override
  String get on => 'Вкл';

  @override
  String get off => 'Изкл';

  @override
  String get installRemoveProviders => 'Инсталирай/премахни доставчици';

  @override
  String get resetDataSubtitle => 'Изчисти натройки и БД, запази плъгини';

  @override
  String get factoryResetSubtitle =>
      'Изтрий всички данни, настройки и разширения';

  @override
  String get developerOptionsSubtitle => 'Инструменти за разработка';

  @override
  String get loading => 'Зареждане...';

  @override
  String get sec => 'сек';

  @override
  String get min => 'мин';

  @override
  String get internalPlayer => 'Вътрешен (VLC)';

  @override
  String get builtInPlayer => 'Вграден плейър';

  @override
  String get customNotSet => 'Персонализиран (не е зададен)';

  @override
  String selectGesture(String side) {
    return 'Избери жест ($side)';
  }

  @override
  String get left => 'ляв';

  @override
  String get right => 'десен';

  @override
  String get selectSeekDuration => 'Избери продължителност на търсене';

  @override
  String get selectBufferDepth => 'Избери дълбочина на буфера';

  @override
  String get subtitleSettings => 'Настройки на субтитри';

  @override
  String size(int size) {
    return 'Размер: $size';
  }

  @override
  String get background => 'Фон';

  @override
  String get customDohUrlLabel => 'Персонализиран DoH URL';

  @override
  String get enterCustomDohUrl => 'Въведете ваш DoH URL';

  @override
  String get chooseTheme => 'Избери тема';

  @override
  String get resetDataDialogTitle => 'Нулиране на данни?';

  @override
  String get resetDataDialogContent =>
      'Това ще изчисти Настройки, Любими и История. Разширенията НЯМА да бъдат изтрити.';

  @override
  String get factoryResetDialogTitle => 'Фабрично нулиране?';

  @override
  String get factoryResetDialogContent =>
      'Това ще изтрие ВСИЧКО. Не може да бъде отменено.';

  @override
  String get selectLanguage => 'Избери език';

  @override
  String get synopsis => 'Синопсис';

  @override
  String get noDescription => 'Няма описание.';

  @override
  String get videoAlreadyDownloadedPrompt =>
      'Това видео вече е изтеглено. Какво искате да направите?';

  @override
  String get playNow => 'Гледай сега';

  @override
  String get upNext => 'Следва';

  @override
  String get deleteDownloadPrompt => 'Изтрий изтеглянето?';

  @override
  String get deleteDownloadConfirmation =>
      'Сигурни ли сте? Действието е необратимо.';

  @override
  String get no => 'Не';

  @override
  String get yesDelete => 'Да, изтрий';

  @override
  String get downloadPaused => 'Изтеглянето е на пауза';

  @override
  String get downloading => 'Изтегляне';

  @override
  String get speed => 'Скорост';

  @override
  String get remaining => 'Оставащо';

  @override
  String get resume => 'Продължи';

  @override
  String get pause => 'Пауза';

  @override
  String get torrentContent => 'Торент съдържание';

  @override
  String get audioTracks => 'Аудио записи';

  @override
  String get noAudioTracks => 'Няма аудио записи';

  @override
  String get subtitles => 'Субтитри';

  @override
  String get options => 'Опции';

  @override
  String get noSubtitlesFound => 'Няма субтитри';

  @override
  String get playbackSpeed => 'Скорост на възпроизвеждане';

  @override
  String get subtitleOptions => 'Опции за субтитри';

  @override
  String get hlsSubtitleWarning =>
      'Външни субтитри не се поддържат за HLS на тази платформа.';

  @override
  String get loadFromDevice => 'Зареди от устройството';

  @override
  String get syncDelay => 'Синхронизация / Закъснение';

  @override
  String get styleSettings => 'Настройки на стила';

  @override
  String get searchOnline => 'Търсене онлайн';

  @override
  String get subtitleSync => 'Синхронизация';

  @override
  String get subtitleDelayWarning =>
      'Закъснението не се поддържа от текущия плейър.';

  @override
  String get resetDelay => 'Нулирай закъснението';

  @override
  String get subtitleStyles => 'Стилове на субтитри';

  @override
  String get resetToDefault => 'По подразбиране';

  @override
  String get fontSize => 'Размер на шрифта';

  @override
  String get verticalPosition => 'Вертикална позиция';

  @override
  String get textColor => 'Цвят на текста';

  @override
  String get backgroundColor => 'Цвят на фона';

  @override
  String get backgroundOpacity => 'Прозрачност на фона';

  @override
  String get subtitleSearch => 'Търсене на субтитри';

  @override
  String get searchSubtitleNameHint => 'Име на субтитри...';

  @override
  String get enterSearchSubtitlePrompt => 'Въведете име за търсене.';

  @override
  String get noSubtitleResults => 'Няма резултати.';

  @override
  String get downloadingApplyingSubtitle => 'Изтегляне и прилагане...';

  @override
  String get failedToDownloadSubtitle => 'Грешка при изтегляне.';

  @override
  String get failedToLoadSubtitles => 'Грешка при зареждане.';

  @override
  String get noReposFound => 'Няма намерени хранилища';

  @override
  String get downloadAllProviders => 'Изтегли всички';

  @override
  String get removeRepository => 'Премахни хранилище';

  @override
  String get addRepo => 'Добави хранилище';

  @override
  String get extensionsNotInRepos => 'Разширения извън хранилищата';

  @override
  String get noLongerInRepo => 'Вече не е в списъка';

  @override
  String get addRepoToBrowse => 'Добавете хранилище за преглед';

  @override
  String get debugExtensions => 'Дебъг на разширения';

  @override
  String removeRepoConfirm(String repoName) {
    return 'Премахване на $repoName?';
  }

  @override
  String get removeRepoWarning => 'Това ще деинсталира ВСИЧКИ негови плъгини.';

  @override
  String get addRepository => 'Добави хранилище';

  @override
  String get repoUrlOrShortcode => 'URL или кратък код';

  @override
  String get assetPlugin => 'Вграден плъгин';

  @override
  String get installed => 'Инсталирано';

  @override
  String get repositories => 'Хранилища';

  @override
  String get noExtensionsInstalled => 'Няма инсталирани разширения';

  @override
  String get browseRepositoriesToInstall =>
      'Отворете раздела „Хранилища“, за да откриете и инсталирате разширения.';

  @override
  String get browseRepositories => 'Разгледай хранилищата';

  @override
  String get addRepoDescription =>
      'Добавете URL на хранилище или кратък код, за да откриете и инсталирате плъгини.';

  @override
  String updateTo(String version) {
    return 'Актуализирай до $version';
  }

  @override
  String get install => 'Инсталирай';

  @override
  String get error => 'Грешка';

  @override
  String get ok => 'ОК';

  @override
  String pluginSettings(String pluginName) {
    return 'Настройки на $pluginName';
  }

  @override
  String get movies => 'Филми';

  @override
  String get series => 'Сериали';

  @override
  String get anime => 'Аниме';

  @override
  String get liveStreams => 'На живо';

  @override
  String get debug => 'DEBUG';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count разширения са актуализирани',
      one: '1 разширение е актуализирано',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => 'Невалидна навигация.';

  @override
  String get startOver => 'Започни отначало';

  @override
  String get goBack => 'Назад';

  @override
  String get resolving => 'Разрешаване...';

  @override
  String get downloaded => 'Изтеглено';

  @override
  String get download => 'Изтегли';

  @override
  String get debugOnlyFeature => 'Само за дебъг';

  @override
  String get streamUrl => 'URL на стрийм';

  @override
  String get play => 'Пуснете';

  @override
  String get verifyingSourceSize => 'Проверка...';

  @override
  String get fileSaveLocationNotification =>
      'Ще бъде запазено в Папка Изтегляния.';

  @override
  String get resumingPlayback => 'Възобновяване';

  @override
  String pausedAt(String time) {
    return 'Пауза на $time';
  }

  @override
  String resumesAutomatically(int count) {
    return 'Автоматично след $count сек';
  }

  @override
  String get resumeNow => 'Възобнови сега';

  @override
  String get playbackError => 'Грешка при възпроизвеждане';

  @override
  String get confirmClearHistory => 'Изчистване на цялата история?';

  @override
  String seasonWithNumber(Object number) {
    return 'Сезон $number';
  }

  @override
  String get starting => 'Стартиране...';

  @override
  String percentWatched(int percent) {
    return '$percent% изгледани';
  }

  @override
  String get sub => 'Суб';

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
  String get debugTools => 'Инструменти за дебъг';

  @override
  String get playLocalVideo => 'Локално видео';

  @override
  String get playLocalVideoSubtitle => 'Пуснете файл от устройството';

  @override
  String get streamUrlSubtitle => 'Пуснете от URL';

  @override
  String get streamTorrent => 'Торент стрийм';

  @override
  String get streamTorrentSubtitle => 'Изберете торент файл';

  @override
  String get loadPluginFromAssets => 'Зареди от активите';

  @override
  String get enterVideoUrlHint => 'URL (http, magnet и т.н.)';

  @override
  String get networkStream => 'Мрежов стрийм';

  @override
  String removedFromHistory(String title) {
    return 'Премахнато: $title';
  }

  @override
  String get custom => 'Персонализирано';

  @override
  String get refreshingLiveStream => 'Опресняване...';

  @override
  String get removeFromHistory => 'Премахни от историята';

  @override
  String get live => 'НА ЖИВО';

  @override
  String get volume => 'Сила на звука';

  @override
  String get brightness => 'Яркост';

  @override
  String get fit => 'Побиране';

  @override
  String get zoom => 'Увеличение';

  @override
  String get stretch => 'Разтягане';

  @override
  String titleWithParam(String title) {
    return 'Заглавие: $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'Източник: $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'Размер: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'Грешка: $error. Използване на вътрешен плейър.';
  }

  @override
  String playerNotDetected(String playerName) {
    return '$playerName не е открит.';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return 'Сезон $number ($count еп.)';
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
    return 'Източник за $playerName';
  }

  @override
  String get noPluginsInstalled => 'Няма инсталирани плъгини';

  @override
  String get noPluginsMessage =>
      'Инсталирайте разширения за преглед и стрийминг на съдържание.';

  @override
  String get goToExtensions => 'Отидете на разширения';

  @override
  String get availableSources => 'Налични източници';

  @override
  String get seasons => 'Сезони';

  @override
  String get episodes => 'Епизоди';

  @override
  String get selectSourceToPlay => 'Изберете източник за възпроизвеждане.';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count епизода',
      one: '1 епизод',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'Няма открити епизоди';

  @override
  String get local => 'Локален';

  @override
  String get remote => ' отдалечен';

  @override
  String get torrent => 'Торент';

  @override
  String get unlock => 'Отключване';

  @override
  String get lock => 'Заключване';

  @override
  String get sources => 'Източници';

  @override
  String get tracks => 'Записи';

  @override
  String get content => 'Съдържание';

  @override
  String get stats => 'Статистика';

  @override
  String get resize => 'Размер';

  @override
  String get next => 'Следващ';

  @override
  String get pip => 'PiP';

  @override
  String get rotate => 'Завъртане';

  @override
  String get windowed => 'Прозорец';

  @override
  String get fullscreen => 'Цял екран';

  @override
  String get movieDetails => 'Детайли';

  @override
  String get showDetails => 'Виж още';

  @override
  String get tagline => 'Таглайн';

  @override
  String get status => 'Статус';

  @override
  String get releaseDate => 'Премиера';

  @override
  String get firstAirDate => 'Първо излъчване';

  @override
  String get originalLanguage => 'Оригинален език';

  @override
  String get originCountry => 'Държава';

  @override
  String get budgetLabel => 'Бюджет';

  @override
  String get revenueLabel => 'Приходи';

  @override
  String get paused => 'Пауза';

  @override
  String get watched => 'Гледано';

  @override
  String get watching => 'Гледане';

  @override
  String get lastWatched => 'Последно';

  @override
  String get movie => 'Филм';

  @override
  String get tvShow => 'Сериал';

  @override
  String get failedToLoadContent => 'Грешка при зареждане';

  @override
  String get director => 'Режисьор';

  @override
  String get creator => 'Създател';

  @override
  String get showMore => 'Още';

  @override
  String get showLess => 'По-малко';

  @override
  String get viewAll => 'Всички';

  @override
  String seasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сезона',
      one: '1 сезон',
    );
    return '$_temp0';
  }

  @override
  String get noInternetError => 'Няма интернет';

  @override
  String get timeoutError => 'Времето изтече.';

  @override
  String get serverError => 'Грешка в сървъра.';

  @override
  String get contentNotFoundError => 'Не е намерено.';

  @override
  String get accessDeniedError => 'Достъпът отказан.';

  @override
  String get serviceUnavailableError => 'Услугата е недостъпна.';

  @override
  String get generalError => 'Грешка.';

  @override
  String get skip => 'Пропусни';

  @override
  String get skipIntro => 'Пропусни началото';

  @override
  String get skipOutro => 'Пропусни финала';

  @override
  String get skipRecap => 'Пропусни резюмето';

  @override
  String get goLive => 'На живо';

  @override
  String get dismiss => 'Затвори';

  @override
  String get nextUp => 'Следва';

  @override
  String sourceAttempt(int index, int total) {
    return 'Опит $index от $total';
  }

  @override
  String get trying => 'Опитване';

  @override
  String get failed => 'Неуспешно';

  @override
  String get selected => 'Избрано';

  @override
  String get playing => 'Възпроизвеждане';

  @override
  String get pending => 'Изчакване';

  @override
  String get openSubtitles => 'OpenSubtitles';

  @override
  String get subDl => 'SubDL';

  @override
  String get subSource => 'SubSource';

  @override
  String get wifiQualityPreference => 'Предпочитание за качество при Wi-Fi';

  @override
  String get mobileQualityPreference =>
      'Предпочитание за качество при мобилни данни';

  @override
  String get anyNoPreference => 'Без предпочитание';

  @override
  String get subtitleAccounts => 'Акаунти за субтитри';

  @override
  String get accounts => 'Профили';

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
  String get testConnection => 'Тестване на връзката';

  @override
  String get connectedSuccessfully => 'Успешно свързване';

  @override
  String get connectionFailed => 'Връзката неуспешна';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get noAccountRegister => 'Don\'t have an account? Register here';

  @override
  String get apiKey => 'API ключ';

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
  String get diagnostics => 'Диагностика';

  @override
  String get viewLogs => 'Преглед на логове';

  @override
  String get viewLogsSubtitle =>
      'Преглед на активността на приложението и грешки';

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
