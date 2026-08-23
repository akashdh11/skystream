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
  String get bufferDepth => 'Глибина буфера';

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
  String get internalPlayer => 'Внутрішній (media_kit)';

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
  String get selectBufferDepth => 'Оберіть глибину буфера';

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
  String get mediaKitStylingWarning =>
      'Стилізація субтитрів доступна лише у плеєрі media_kit.';

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
  String get wifiQualityPreference => 'Якість через Wi-Fi';

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
  String get showRotate => 'Rotate button';

  @override
  String get showPlaybackSpeed => 'Playback speed button';

  @override
  String get showEpisodes => 'Episodes button';
}
