// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => 'Українська';

  @override
  String get addonHealthChecking => 'Checking add-on…';

  @override
  String addonHealthWorking(int ms) {
    return 'Working · $ms ms';
  }

  @override
  String get addonHealthUnavailable => 'Unavailable';

  @override
  String get home => 'Головна';

  @override
  String get search => 'Пошук';

  @override
  String get explore => 'Дослідити';

  @override
  String get exploreAnime => 'Огляд аніме';

  @override
  String get exploreMovies => 'Огляд фільмів';

  @override
  String get library => 'Бібліотека';

  @override
  String get settings => 'Налаштування';

  @override
  String get extensions => 'Розширення';

  @override
  String get updateAvailable => 'Доступне оновлення';

  @override
  String get retry => 'Повторити';

  @override
  String get factoryReset => 'Скидання до заводських налаштувань';

  @override
  String get startupError => 'Помилка запуску';

  @override
  String get general => 'Загальні';

  @override
  String get appTheme => 'Тема додатка';

  @override
  String get recordWatchHistory => 'Записувати історію переглядів';

  @override
  String get fullScreenMode => 'На весь екран';

  @override
  String get fullScreenModeSubtitle => 'Перемикає на телевізійний інтерфейс';

  @override
  String get defaultHomeScreen => 'Головний екран за замовчуванням';

  @override
  String get titlePosition => 'Розташування назви';

  @override
  String get titlePositionBelowPoster => 'Під постером';

  @override
  String get titlePositionInsidePoster => 'На постері';

  @override
  String get player => 'Плеєр';

  @override
  String get defaultPlayer => 'Плеєр за замовчуванням';

  @override
  String get leftGesture => 'Лівий жест';

  @override
  String get rightGesture => 'Правий жест';

  @override
  String get doubleTapToSeek => 'Подвійне натискання для перемотування';

  @override
  String get swipeToSeek => 'Свайп для перемотування';

  @override
  String get seekDuration => 'Тривалість перемотування';

  @override
  String get defaultResizeMode => 'Режим масштабування за замовчуванням';

  @override
  String get hardwareDecoding => 'Апаратне декодування';

  @override
  String get network => 'Мережа';

  @override
  String get dnsOverHttps => 'DNS через HTTPS';

  @override
  String get dohProvider => 'Провайдер DoH';

  @override
  String get githubProxy => 'Проксі GitHub';

  @override
  String get githubProxySubtitle =>
      'Спрямовувати завантаження розширень через jsDelivr, щоб обійти блокування провайдера.';

  @override
  String get manageExtensions => 'Керування розширеннями';

  @override
  String get appData => 'Дані додатка';

  @override
  String get resetDataKeepExtensions => 'Скинути дані (зберегти розширення)';

  @override
  String get developer => 'Розробник';

  @override
  String get developerOptions => 'Параметри розробника';

  @override
  String get about => 'Про додаток';

  @override
  String get version => 'Версія';

  @override
  String get enabled => 'Увімкнено';

  @override
  String get disabled => 'Вимкнено';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'Приєднуйтесь до нашого сервера';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'Приєднуйтесь до нашого каналу';

  @override
  String developedBy(String name) {
    return 'Розроблено $name';
  }

  @override
  String get system => 'Система';

  @override
  String get dark => 'Темна';

  @override
  String get light => 'Світла';

  @override
  String get later => 'Пізніше';

  @override
  String get updateNow => 'Оновити зараз';

  @override
  String get save => 'Зберегти';

  @override
  String get cancel => 'Скасувати';

  @override
  String get close => 'Закрити';

  @override
  String get delete => 'Видалити';

  @override
  String get viewDetails => 'Детальніше';

  @override
  String get clearAll => 'Очистити все';

  @override
  String get clearAllHistory => 'Очистити всю історію';

  @override
  String get all => 'Все';

  @override
  String get none => 'Нічого';

  @override
  String get confirmDownload => 'Підтвердження завантаження';

  @override
  String get downloadNow => 'Завантажити зараз';

  @override
  String get selectSource => 'Оберіть джерело';

  @override
  String get downloadUnavailable => 'Недоступно';

  @override
  String get selectAnotherSource => 'Обрати інше';

  @override
  String get watchHistoryCleared => 'Історію переглядів очищено';

  @override
  String get downloadingUpdate => 'Завантаження оновлення...';

  @override
  String errorPrefix(String message) {
    return 'Помилка: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'Доступне оновлення: $tag';
  }

  @override
  String get selectProviderToStart => 'Оберіть провайдера, щоб почати перегляд';

  @override
  String get tapExtensionIcon => 'Натисніть на іконку розширення у кутку';

  @override
  String get continueWatching => 'Продовжити перегляд';

  @override
  String get noInternetConnection => 'Немає підключення до Інтернету';

  @override
  String get siteNotReachable => 'Сайт недоступний';

  @override
  String get checkConnectionOrDownloads =>
      'Перевірте підключення або перегляньте завантажений контент.';

  @override
  String get tryVpnOrConnection =>
      'Спробуйте використовувати VPN або перевірте підключення.';

  @override
  String errorDetails(String error) {
    return 'Деталі помилки: $error';
  }

  @override
  String get goToDownloads => 'Перейти до завантажень';

  @override
  String get selectProvider => 'Оберіть провайдера';

  @override
  String get searchHint => 'Пошук фільмів, серіалів...';

  @override
  String get searchFavoriteContent => 'Пошук улюбленого контенту';

  @override
  String get pressSearchOrEnter => 'Натисніть на пошук або Enter, щоб почати';

  @override
  String get recentSearches => 'Recent searches';

  @override
  String removeFromSearchHistory(String query) {
    return 'Remove $query from search history';
  }

  @override
  String get noResultsFound => 'Нічого не знайдено.';

  @override
  String get couldNotLoadTrending => 'Не вдалося завантажити тренди';

  @override
  String get popularMovies => 'Популярні фільми';

  @override
  String get popularTVShows => 'Популярні серіали';

  @override
  String get newMovies => 'Нові фільми';

  @override
  String get newTVShows => 'Нові серіали';

  @override
  String get featuredMovies => 'Рекомендовані фільми';

  @override
  String get featuredTVShows => 'Рекомендовані серіали';

  @override
  String get lastVideosTVShows => 'Останні серіали';

  @override
  String get downloads => 'Завантаження';

  @override
  String get bookmarks => 'Закладки';

  @override
  String get noDownloadsYet => 'Завантажень поки немає';

  @override
  String episodesCount(int count, int done) {
    return '$count серій • $done переглянуто';
  }

  @override
  String get deleteAllEpisodes => 'Видалити всі серії';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return 'Ви впевнені, що хочете видалити всі серії ($count) «$title» та їхні файли?';
  }

  @override
  String get deleteAll => 'Видалити все';

  @override
  String get completed => 'Завершено';

  @override
  String get statusQueued => 'У черзі...';

  @override
  String get statusDownloading => 'Завантаження...';

  @override
  String get statusFinished => 'Завершено';

  @override
  String get statusFailed => 'Помилка';

  @override
  String get statusCanceled => 'Скасовано';

  @override
  String get statusPaused => 'Призупинено';

  @override
  String get statusWaiting => 'Очікування...';

  @override
  String get fileNotFoundRemoving =>
      'Файл не знайдено на диску. Видалення запису.';

  @override
  String get fileNotFound => 'Файл не знайдено';

  @override
  String get deleteDownload => 'Видалити завантаження';

  @override
  String get confirmDeleteDownload =>
      'Ви впевнені, що хочете видалити це завантаження?';

  @override
  String get libraryEmpty => 'Ваша бібліотека порожня';

  @override
  String get language => 'Мова';

  @override
  String get english => 'Англійська';

  @override
  String get hindi => 'Гінді';

  @override
  String get kannada => 'Каннада';

  @override
  String get unknown => 'Невідомо';

  @override
  String get recommended => 'Рекомендоване';

  @override
  String get on => 'Увімк.';

  @override
  String get off => 'Вимк.';

  @override
  String get installRemoveProviders => 'Встановлення та видалення провайдерів';

  @override
  String get resetDataSubtitle =>
      'Очистити налаштування та БД, зберегти плагіни';

  @override
  String get factoryResetSubtitle =>
      'Видалити всі дані, налаштування та розширення';

  @override
  String get developerOptionsSubtitle =>
      'Інструменти відладки та локальне відтворення';

  @override
  String get loading => 'Завантаження...';

  @override
  String get sec => 'сек';

  @override
  String get min => 'хв';

  @override
  String playerRewindSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Назад на $count секунди',
      many: 'Назад на $count секунд',
      few: 'Назад на $count секунди',
      one: 'Назад на $count секунду',
    );
    return '$_temp0';
  }

  @override
  String playerForwardSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Вперед на $count секунди',
      many: 'Вперед на $count секунд',
      few: 'Вперед на $count секунди',
      one: 'Вперед на $count секунду',
    );
    return '$_temp0';
  }

  @override
  String get internalPlayer => 'Внутрішній (VLC)';

  @override
  String get builtInPlayer => 'Вбудований плеєр';

  @override
  String get customNotSet => 'Користувацький (не задано)';

  @override
  String selectGesture(String side) {
    return 'Оберіть жест ($side)';
  }

  @override
  String get left => 'ліворуч';

  @override
  String get right => 'праворуч';

  @override
  String get selectSeekDuration => 'Оберіть тривалість перемотування';

  @override
  String get subtitleSettings => 'Налаштування субтитрів';

  @override
  String size(int size) {
    return 'Розмір: $size';
  }

  @override
  String get background => 'Фон';

  @override
  String get customDohUrlLabel => 'Свій DoH URL';

  @override
  String get enterCustomDohUrl => 'Введіть свій DoH URL';

  @override
  String get chooseTheme => 'Оберіть тему';

  @override
  String get resetDataDialogTitle => 'Скинути дані?';

  @override
  String get resetDataDialogContent =>
      'Це видалить налаштування, обране та історію. Встановлені розширення НЕ будуть видалені.';

  @override
  String get factoryResetDialogTitle => 'Заводське скидання?';

  @override
  String get factoryResetDialogContent =>
      'Це видалить ВСЕ: обране, історію, налаштування та ВСІ розширення. Цю дію неможливо скасувати.';

  @override
  String get selectLanguage => 'Оберіть мову';

  @override
  String get synopsis => 'Синопсис';

  @override
  String get noDescription => 'Опис відсутній.';

  @override
  String get videoAlreadyDownloadedPrompt =>
      'Це відео вже завантажено. Що ви хочете зробити?';

  @override
  String get playNow => 'Дивитися зараз';

  @override
  String get upNext => 'Далі';

  @override
  String get deleteDownloadPrompt => 'Видалити завантаження?';

  @override
  String get deleteDownloadConfirmation =>
      'Ви впевнені, що хочете видалити цей файл? Цю дію неможливо скасувати.';

  @override
  String get no => 'Ні';

  @override
  String get yesDelete => 'Так, видалити';

  @override
  String get downloadPaused => 'Завантаження призупинено';

  @override
  String get downloading => 'Завантаження';

  @override
  String get speed => 'Швидкість';

  @override
  String get remaining => 'Залишилося';

  @override
  String get resume => 'Продовжити';

  @override
  String get pause => 'Пауза';

  @override
  String get torrentContent => 'Вміст торрента';

  @override
  String get audioTracks => 'Аудіодоріжки';

  @override
  String get noAudioTracks => 'Аудіодоріжки не знайдено';

  @override
  String get subtitles => 'Субтитри';

  @override
  String get options => 'Опції';

  @override
  String get noSubtitlesFound => 'Субтитри не знайдено';

  @override
  String get playbackSpeed => 'Швидкість відтворення';

  @override
  String get subtitleOptions => 'Налаштування субтитрів';

  @override
  String get hlsSubtitleWarning =>
      'Зовнішні субтитри не підтримуються для HLS на цій платформі.';

  @override
  String get loadFromDevice => 'Завантажити з пристрою';

  @override
  String get syncDelay => 'Синхронізація / Затримка';

  @override
  String get styleSettings => 'Налаштування стилю';

  @override
  String get searchOnline => 'Пошук онлайн (пошук субтитрів)';

  @override
  String get subtitleSync => 'Синхронізація субтитрів';

  @override
  String get subtitleDelayWarning =>
      'Затримка субтитрів не підтримується поточним плеєром.';

  @override
  String get resetDelay => 'Скинути затримку';

  @override
  String get subtitleStyles => 'Стилі субтитрів';

  @override
  String get resetToDefault => 'Скинути за замовчуванням';

  @override
  String get fontSize => 'Розмір шрифту';

  @override
  String get verticalPosition => 'Вертикальна позиція';

  @override
  String get textColor => 'Колір тексту';

  @override
  String get backgroundColor => 'Колір фону';

  @override
  String get backgroundOpacity => 'Прозорість фону';

  @override
  String get subtitleSearch => 'Пошук субтитрів';

  @override
  String get searchSubtitleNameHint => 'Назва субтитрів...';

  @override
  String get enterSearchSubtitlePrompt => 'Введіть назву для пошуку субтитрів.';

  @override
  String get noSubtitleResults => 'Результатів не знайдено.';

  @override
  String get downloadingApplyingSubtitle =>
      'Завантаження та застосування субтитрів...';

  @override
  String get failedToDownloadSubtitle => 'Не вдалося завантажити субтитри.';

  @override
  String get failedToLoadSubtitles =>
      'Не вдалося завантажити субтитри. Спробуйте ще раз.';

  @override
  String get noReposFound => 'Репозиторії або плагіни не знайдено';

  @override
  String get downloadAllProviders => 'Завантажити все';

  @override
  String get removeRepository => 'Видалити репозиторій';

  @override
  String get addRepo => 'Додати репозиторій';

  @override
  String get extensionsNotInRepos => 'Розширення не з репозиторіїв';

  @override
  String get noLongerInRepo => 'Більше не значиться в жодному репозиторії';

  @override
  String get addRepoToBrowse => 'Додайте репозиторій для перегляду плагінів';

  @override
  String get debugExtensions => 'Відладка розширення';

  @override
  String removeRepoConfirm(String repoName) {
    return 'Видалити $repoName?';
  }

  @override
  String get removeRepoWarning =>
      'Це видалить репозиторій та ВСІ його плагіни.';

  @override
  String get addRepository => 'Додати репозиторій';

  @override
  String get repoUrlOrShortcode => 'URL репозиторія або короткий код';

  @override
  String get assetPlugin => 'Вбудований плагін';

  @override
  String get installed => 'Встановлено';

  @override
  String get repositories => 'Репозиторії';

  @override
  String get noExtensionsInstalled => 'Розширення не встановлено';

  @override
  String get browseRepositoriesToInstall =>
      'Відкрийте вкладку «Репозиторії», щоб знайти та встановити розширення.';

  @override
  String get browseRepositories => 'Огляд репозиторіїв';

  @override
  String get addRepoDescription =>
      'Додайте URL репозиторію або короткий код, щоб знайти та встановити плагіни розширень.';

  @override
  String updateTo(String version) {
    return 'Оновити до $version';
  }

  @override
  String get install => 'Встановити';

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
  String get error => 'Помилка';

  @override
  String get ok => 'ОК';

  @override
  String pluginSettings(String pluginName) {
    return 'Налаштування $pluginName';
  }

  @override
  String get movies => 'Фільми';

  @override
  String get series => 'Серіали';

  @override
  String get anime => 'Аніме';

  @override
  String get liveStreams => 'Прямі трансляції';

  @override
  String get debug => 'ВІДЛАДКА';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Оновлено $count розширень',
      few: 'Оновлено $count розширення',
      one: 'Оновлено 1 розширення',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => 'Невірна навігація.';

  @override
  String get startOver => 'Почати спочатку';

  @override
  String get goBack => 'Назад';

  @override
  String get restartApp => 'Перезапустити застосунок';

  @override
  String get resolving => 'Розв\'язання посилань...';

  @override
  String get downloaded => 'Завантажено';

  @override
  String get download => 'Завантажити';

  @override
  String get debugOnlyFeature => 'Тільки для дебаг-збірок';

  @override
  String get streamUrl => 'URL потоку';

  @override
  String get play => 'Дивитися';

  @override
  String get verifyingSourceSize => 'Перевірка джерела та розміру...';

  @override
  String get fileSaveLocationNotification =>
      'Файл буде збережено у папку «Завантаження».';

  @override
  String get resumingPlayback => 'Відновлення відтворення';

  @override
  String pausedAt(String time) {
    return 'Пауза на $time';
  }

  @override
  String resumesAutomatically(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Автоматическое восстановление через $count секунд',
      few: 'Автоматичне відновлення через $count секунди',
      one: 'Автоматичне відновлення через 1 секунду',
    );
    return '$_temp0';
  }

  @override
  String get resumeNow => 'Відновити зараз';

  @override
  String get playbackError => 'Помилка відтворення';

  @override
  String get confirmClearHistory => 'Ви впевнені, що хочете очистити історію?';

  @override
  String seasonWithNumber(Object number) {
    return 'Сезон $number';
  }

  @override
  String get starting => 'Запуск...';

  @override
  String percentWatched(int percent) {
    return 'переглянуто $percent%';
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
  String get debugTools => 'Інструменти відладки';

  @override
  String get playLocalVideo => 'Локальне відео';

  @override
  String get playLocalVideoSubtitle => 'Відтворити файл з пристрою';

  @override
  String get streamUrlSubtitle => 'Відтворити з мережі (URL)';

  @override
  String get streamTorrent => 'Торрент-потік';

  @override
  String get streamTorrentSubtitle => 'Оберіть торрент-файл';

  @override
  String get loadPluginFromAssets => 'Завантажити плагін з ресурсів';

  @override
  String get enterVideoUrlHint => 'Введіть URL відео (http, magnet тощо)';

  @override
  String get networkStream => 'Мережевий потік';

  @override
  String removedFromHistory(String title) {
    return 'Видалено з історії: $title';
  }

  @override
  String get custom => 'Свій';

  @override
  String get refreshingLiveStream => 'Оновлення трансляції...';

  @override
  String get removeFromHistory => 'Видалити з історії';

  @override
  String get live => 'ПРЯМИЙ ЕФІР';

  @override
  String get volume => 'Гучність';

  @override
  String get decrease => 'Decrease';

  @override
  String get increase => 'Increase';

  @override
  String get brightness => 'Яскравість';

  @override
  String get fit => 'Заповнення';

  @override
  String get zoom => 'Зум';

  @override
  String get stretch => 'Розтягнути';

  @override
  String titleWithParam(String title) {
    return 'Назва: $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'Джерело: $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'Розмір: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'Помилка: $error. Використовується внутрішній плеєр.';
  }

  @override
  String externalPlayerCannotSendHeaders(String playerName, String headers) {
    return '$playerName cannot send $headers. Using internal player.';
  }

  @override
  String playerNotDetected(String playerName) {
    return '$playerName не знайдено.';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return 'Сезон $number ($count серій)';
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
    return 'Джерело для $playerName';
  }

  @override
  String get noPluginsInstalled => 'Немає встановлених плагінів';

  @override
  String get noPluginsMessage =>
      'Встановіть розширення для перегляду та трансляції контенту.';

  @override
  String get goToExtensions => 'Перейти да розширень';

  @override
  String get availableSources => 'Доступні джерела';

  @override
  String get seasons => 'Сезони';

  @override
  String get episodes => 'Серії';

  @override
  String get selectSourceToPlay => 'Оберіть джерело зі списку вище.';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count серій',
      few: '$count серії',
      one: '1 серія',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'Серії не знайдено';

  @override
  String get local => 'Локальне';

  @override
  String get remote => 'Віддалене';

  @override
  String get torrent => 'Торрент';

  @override
  String get unlock => 'Розблокувати';

  @override
  String get lock => 'Блокування';

  @override
  String get sources => 'Джерела';

  @override
  String get tracks => 'Доріжки';

  @override
  String get content => 'Контент';

  @override
  String get stats => 'Статистика';

  @override
  String get resize => 'Розмір';

  @override
  String get next => 'Наст.';

  @override
  String get previous => 'Previous';

  @override
  String get pip => 'Картинка в картинці';

  @override
  String get rotate => 'Поворот';

  @override
  String get windowed => 'У вікні';

  @override
  String get fullscreen => 'На весь екран';

  @override
  String get movieDetails => 'Про фільм';

  @override
  String get showDetails => 'Показати деталі';

  @override
  String get tagline => 'Слоган';

  @override
  String get status => 'Статус';

  @override
  String get releaseDate => 'Дата виходу';

  @override
  String get firstAirDate => 'Перший вихід';

  @override
  String get originalLanguage => 'Мова оригіналу';

  @override
  String get originCountry => 'Країна';

  @override
  String get budgetLabel => 'Бюджет';

  @override
  String get revenueLabel => 'Збори';

  @override
  String get paused => 'Пауза';

  @override
  String get watched => 'Переглянуто';

  @override
  String get watching => 'Перегляд';

  @override
  String get lastWatched => 'Останній перегляд';

  @override
  String get movie => 'Фільм';

  @override
  String get tvShow => 'Серіал';

  @override
  String get failedToLoadContent => 'Помилка завантаження';

  @override
  String get director => 'Режисер';

  @override
  String get creator => 'Творець';

  @override
  String get showMore => 'Показати більше';

  @override
  String get showLess => 'Показати менше';

  @override
  String get viewAll => 'Все';

  @override
  String seasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сезонів',
      few: '$count сезони',
      one: '1 сезон',
    );
    return '$_temp0';
  }

  @override
  String get noInternetError => 'Немає інтернету';

  @override
  String get timeoutError => 'Час очікування вичерпано.';

  @override
  String get serverError => 'Помилка сервера.';

  @override
  String get contentNotFoundError => 'Не знайдено.';

  @override
  String get accessDeniedError => 'Доступ заборонено.';

  @override
  String get serviceUnavailableError => 'Сервіс недоступний.';

  @override
  String get generalError => 'Сталася помилка.';

  @override
  String get skip => 'Пропустити';

  @override
  String get skipIntro => 'Пропустити заставку';

  @override
  String get skipOutro => 'Пропустити титри';

  @override
  String get skipRecap => 'Пропустити огляд';

  @override
  String get goLive => 'В ефір';

  @override
  String get dismiss => 'Закрити';

  @override
  String get nextUp => 'Далі';

  @override
  String sourceAttempt(int index, int total) {
    return 'Джерело $index з $total';
  }

  @override
  String get trying => 'Пробуємо';

  @override
  String get failed => 'Помилка';

  @override
  String get selected => 'Обрано';

  @override
  String get playing => 'Грає';

  @override
  String get pending => 'Очікування';

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
  String get mobileQualityPreference => 'Якість через мобільну мережу';

  @override
  String get anyNoPreference => 'Без переваг';

  @override
  String get subtitleAccounts => 'Акаунти субтитрів';

  @override
  String get accounts => 'Облікові записи';

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
  String get testConnection => 'Перевірити з\'єднання';

  @override
  String get connectedSuccessfully => 'З\'єднано успішно';

  @override
  String get connectionFailed => 'З\'єднання не вдалося';

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
  String get diagnostics => 'Діагностика';

  @override
  String get viewLogs => 'Перегляд логів';

  @override
  String get viewLogsSubtitle => 'Перегляд активності програми та помилок';

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
  String get sourcesSearching => 'Пошук у скрейперах…';

  @override
  String get sourcesEmptyFiltered =>
      'Немає посилань, що відповідають фільтрам.';

  @override
  String get sourcesEmptyNoTmdbId =>
      'Для цієї назви немає TMDB ID. Введіть його через \'Search manually\'.';

  @override
  String get sourcesEmptyNoScrapers =>
      'Немає увімкнених скрейперів. Додайте в \'Nuvio Plugins\'.';

  @override
  String get sourcesEmptyAllFailed =>
      'Усі скрейпери не спрацювали. Перевірте з\'єднання або оновіть їх.';

  @override
  String sourcesEmptySomeFailed(int failed, int total) {
    return 'Посилань не знайдено. Не спрацювали $failed з $total скрейперів.';
  }

  @override
  String get sourcesEmptyNothingFound =>
      'Жоден із ваших скрейперів не має цієї назви.';

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
