// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => 'Русский';

  @override
  String get home => 'Главная';

  @override
  String get search => 'Поиск';

  @override
  String get explore => 'Обзор';

  @override
  String get exploreAnime => 'Обзор аниме';

  @override
  String get exploreMovies => 'Обзор фильмов';

  @override
  String get library => 'Библиотека';

  @override
  String get settings => 'Настройки';

  @override
  String get extensions => 'Расширения';

  @override
  String get updateAvailable => 'Доступно обновление';

  @override
  String get retry => 'Повторить';

  @override
  String get factoryReset => 'Сброс к заводским настройкам';

  @override
  String get startupError => 'Ошибка запуска';

  @override
  String get general => 'Общие';

  @override
  String get appTheme => 'Тема приложения';

  @override
  String get recordWatchHistory => 'Записывать историю просмотров';

  @override
  String get defaultHomeScreen => 'Главный экран по умолчанию';

  @override
  String get titlePosition => 'Положение названия';

  @override
  String get titlePositionBelowPoster => 'Под постером';

  @override
  String get titlePositionInsidePoster => 'На постере';

  @override
  String get player => 'Плеер';

  @override
  String get defaultPlayer => 'Плеер по умолчанию';

  @override
  String get leftGesture => 'Левый жест';

  @override
  String get rightGesture => 'Правый жест';

  @override
  String get doubleTapToSeek => 'Двойное касание для перемотки';

  @override
  String get swipeToSeek => 'Свайп для перемотки';

  @override
  String get seekDuration => 'Длительность перемотки';

  @override
  String get bufferDepth => 'Глубина буфера';

  @override
  String get defaultResizeMode => 'Режим масштабирования по умолчанию';

  @override
  String get hardwareDecoding => 'Аппаратное декодирование';

  @override
  String get network => 'Сеть';

  @override
  String get dnsOverHttps => 'DNS через HTTPS';

  @override
  String get dohProvider => 'Провайдер DoH';

  @override
  String get githubProxy => 'Прокси GitHub';

  @override
  String get githubProxySubtitle =>
      'Направлять загрузку расширений через jsDelivr, чтобы обойти блокировки провайдера.';

  @override
  String get manageExtensions => 'Управление расширениями';

  @override
  String get appData => 'Данные приложения';

  @override
  String get resetDataKeepExtensions => 'Сброс данных (сохранить расширения)';

  @override
  String get developer => 'Разработчик';

  @override
  String get developerOptions => 'Параметры разработчика';

  @override
  String get about => 'О приложении';

  @override
  String get version => 'Версия';

  @override
  String get enabled => 'Включено';

  @override
  String get disabled => 'Выключено';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'Присоединяйтесь к нашему серверу';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'Присоединяйтесь к нашему каналу';

  @override
  String developedBy(String name) {
    return 'Разработано $name';
  }

  @override
  String get system => 'Система';

  @override
  String get dark => 'Темная';

  @override
  String get light => 'Светлая';

  @override
  String get later => 'Позже';

  @override
  String get updateNow => 'Обновить сейчас';

  @override
  String get save => 'Сохранить';

  @override
  String get cancel => 'Отмена';

  @override
  String get close => 'Закрыть';

  @override
  String get delete => 'Удалить';

  @override
  String get viewDetails => 'Подробнее';

  @override
  String get clearAll => 'Очистить все';

  @override
  String get clearAllHistory => 'Очистить всю историю';

  @override
  String get all => 'Все';

  @override
  String get none => 'Ничего';

  @override
  String get confirmDownload => 'Подтверждение скачивания';

  @override
  String get downloadNow => 'Скачать сейчас';

  @override
  String get selectSource => 'Выберите источник';

  @override
  String get downloadUnavailable => 'Недоступно';

  @override
  String get selectAnotherSource => 'Выбрать другой';

  @override
  String get watchHistoryCleared => 'История просмотров очищена';

  @override
  String get downloadingUpdate => 'Загрузка обновления...';

  @override
  String errorPrefix(String message) {
    return 'Ошибка: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'Доступно обновление: $tag';
  }

  @override
  String get selectProviderToStart =>
      'Выберите провайдера, чтобы начать просмотр';

  @override
  String get tapExtensionIcon => 'Нажмите на иконку расширения в углу';

  @override
  String get continueWatching => 'Продолжить просмотр';

  @override
  String get noInternetConnection => 'Нет подключения к интернету';

  @override
  String get siteNotReachable => 'Сайт недоступен';

  @override
  String get checkConnectionOrDownloads =>
      'Проверьте соединение или посмотрите скачанный контент.';

  @override
  String get tryVpnOrConnection =>
      'Попробуйте использовать VPN или проверьте соединение.';

  @override
  String errorDetails(String error) {
    return 'Детали ошибки: $error';
  }

  @override
  String get goToDownloads => 'Перейти к загрузкам';

  @override
  String get selectProvider => 'Выберите провайдера';

  @override
  String get searchHint => 'Поиск фильмов, сериалов...';

  @override
  String get searchFavoriteContent => 'Поиск любимого контента';

  @override
  String get pressSearchOrEnter => 'Нажмите на поиск или Enter, чтобы начать';

  @override
  String get noResultsFound => 'Ничего не найдено.';

  @override
  String get couldNotLoadTrending => 'Не удалось загрузить тренды';

  @override
  String get popularMovies => 'Популярные фильмы';

  @override
  String get popularTVShows => 'Популярные сериалы';

  @override
  String get newMovies => 'Новые фильмы';

  @override
  String get newTVShows => 'Новые сериалы';

  @override
  String get featuredMovies => 'Рекомендуемые фильмы';

  @override
  String get featuredTVShows => 'Рекомендуемые сериалы';

  @override
  String get lastVideosTVShows => 'Последние сериалы';

  @override
  String get downloads => 'Загрузки';

  @override
  String get bookmarks => 'Закладки';

  @override
  String get noDownloadsYet => 'Загрузок пока нет';

  @override
  String episodesCount(int count, int done) {
    return '$count серий • $done просмотрено';
  }

  @override
  String get deleteAllEpisodes => 'Удалить все серии';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return 'Вы уверены, что хотите удалить все серии ($count) «$title» и их файлы?';
  }

  @override
  String get deleteAll => 'Удалить все';

  @override
  String get completed => 'Завершено';

  @override
  String get statusQueued => 'В очереди...';

  @override
  String get statusDownloading => 'Загрузка...';

  @override
  String get statusFinished => 'Завершено';

  @override
  String get statusFailed => 'Ошибка';

  @override
  String get statusCanceled => 'Отменено';

  @override
  String get statusPaused => 'Приостановлено';

  @override
  String get statusWaiting => 'Ожидание...';

  @override
  String get fileNotFoundRemoving =>
      'Файл не найден на диске. Удаление записи.';

  @override
  String get fileNotFound => 'Файл не найден';

  @override
  String get deleteDownload => 'Удалить загрузку';

  @override
  String get confirmDeleteDownload =>
      'Вы уверены, что хотите удалить эту загрузку?';

  @override
  String get libraryEmpty => 'Ваша библиотека пуста';

  @override
  String get language => 'Язык';

  @override
  String get english => 'Английский';

  @override
  String get hindi => 'Хинди';

  @override
  String get kannada => 'Каннада';

  @override
  String get unknown => 'Неизвестно';

  @override
  String get recommended => 'Рекомендуемое';

  @override
  String get on => 'Вкл';

  @override
  String get off => 'Выкл';

  @override
  String get installRemoveProviders => 'Установка и удаление провайдеров';

  @override
  String get resetDataSubtitle => 'Очистить настройки и БД, сохранить плагины';

  @override
  String get factoryResetSubtitle =>
      'Удалить все данные, настройки и расширения';

  @override
  String get developerOptionsSubtitle =>
      'Инструменты отладки и локальное воспроизведение';

  @override
  String get loading => 'Загрузка...';

  @override
  String get sec => 'сек';

  @override
  String get min => 'мин';

  @override
  String get internalPlayer => 'Внутренний (media_kit)';

  @override
  String get builtInPlayer => 'Встроенный плеер';

  @override
  String get customNotSet => 'Пользовательский (не задан)';

  @override
  String selectGesture(String side) {
    return 'Выберите жест ($side)';
  }

  @override
  String get left => 'слева';

  @override
  String get right => 'справа';

  @override
  String get selectSeekDuration => 'Выберите длительность перемотки';

  @override
  String get selectBufferDepth => 'Выберите глубину буфера';

  @override
  String get subtitleSettings => 'Настройки субтитров';

  @override
  String size(int size) {
    return 'Размер: $size';
  }

  @override
  String get background => 'Фон';

  @override
  String get customDohUrlLabel => 'Свой DoH URL';

  @override
  String get enterCustomDohUrl => 'Введите свой DoH URL';

  @override
  String get chooseTheme => 'Выберите тему';

  @override
  String get resetDataDialogTitle => 'Сбросить данные?';

  @override
  String get resetDataDialogContent =>
      'Это удалит настройки, избранное и историю. Установленные расширения НЕ будут удалены.';

  @override
  String get factoryResetDialogTitle => 'Заводской сброс?';

  @override
  String get factoryResetDialogContent =>
      'Это удалит ВСЕ: избранное, историю, настройки и ВСЕ расширения. Это действие нельзя отменить.';

  @override
  String get selectLanguage => 'Выберите язык';

  @override
  String get synopsis => 'Синопсис';

  @override
  String get noDescription => 'Описание отсутствует.';

  @override
  String get videoAlreadyDownloadedPrompt =>
      'Это видео уже скачано. Что вы хотите сделать?';

  @override
  String get playNow => 'Смотреть сейчас';

  @override
  String get upNext => 'Далее';

  @override
  String get deleteDownloadPrompt => 'Удалить загрузку?';

  @override
  String get deleteDownloadConfirmation =>
      'Вы уверены, что хотите удалить этот файл? Это действие нельзя отменить.';

  @override
  String get no => 'Нет';

  @override
  String get yesDelete => 'Да, удалить';

  @override
  String get downloadPaused => 'Загрузка приостановлена';

  @override
  String get downloading => 'Загрузка';

  @override
  String get speed => 'Скорость';

  @override
  String get remaining => 'Осталось';

  @override
  String get resume => 'Продолжить';

  @override
  String get pause => 'Пауза';

  @override
  String get torrentContent => 'Содержимое торрента';

  @override
  String get audioTracks => 'Аудиодорожки';

  @override
  String get noAudioTracks => 'Аудиодорожки не найдены';

  @override
  String get subtitles => 'Субтитры';

  @override
  String get options => 'Опции';

  @override
  String get noSubtitlesFound => 'Субтитры не найдены';

  @override
  String get playbackSpeed => 'Скорость воспроизведения';

  @override
  String get subtitleOptions => 'Настройки субтитров';

  @override
  String get hlsSubtitleWarning =>
      'Внешние субтитры не поддерживаются для HLS на этой платформе.';

  @override
  String get loadFromDevice => 'Загрузить с устройства';

  @override
  String get syncDelay => 'Синхронизация / Задержка';

  @override
  String get styleSettings => 'Настройки стиля';

  @override
  String get searchOnline => 'Поиск онлайн (поиск субтитров)';

  @override
  String get subtitleSync => 'Синхронизация субтитров';

  @override
  String get subtitleDelayWarning =>
      'Задержка субтитров не поддерживается текущим плеером.';

  @override
  String get resetDelay => 'Сбросить задержку';

  @override
  String get subtitleStyles => 'Стили субтитров';

  @override
  String get mediaKitStylingWarning =>
      'Стилизация субтитров доступна только в плеере media_kit.';

  @override
  String get resetToDefault => 'Сбросить по умолчанию';

  @override
  String get fontSize => 'Размер шрифта';

  @override
  String get verticalPosition => 'Вертикальная позиция';

  @override
  String get textColor => 'Цвет текста';

  @override
  String get backgroundColor => 'Цвет фона';

  @override
  String get backgroundOpacity => 'Прозрачность фона';

  @override
  String get subtitleSearch => 'Поиск субтитров';

  @override
  String get searchSubtitleNameHint => 'Название субтитров...';

  @override
  String get enterSearchSubtitlePrompt =>
      'Введите название для поиска субтитров.';

  @override
  String get noSubtitleResults => 'Результатов не найдено.';

  @override
  String get downloadingApplyingSubtitle =>
      'Загрузка и применение субтитров...';

  @override
  String get failedToDownloadSubtitle => 'Не удалось скачать субтитры.';

  @override
  String get failedToLoadSubtitles =>
      'Не удалось загрузить субтитры. Попробуйте еще раз.';

  @override
  String get noReposFound => 'Репозитории или плагины не найдены';

  @override
  String get downloadAllProviders => 'Скачать все';

  @override
  String get removeRepository => 'Удалить репозиторий';

  @override
  String get addRepo => 'Добавить репозиторий';

  @override
  String get extensionsNotInRepos => 'Расширения не из репозиториев';

  @override
  String get noLongerInRepo => 'Больше не значится ни в одном репозитории';

  @override
  String get addRepoToBrowse => 'Добавьте репозиторий для просмотра плагинов';

  @override
  String get debugExtensions => 'Отладка расширений';

  @override
  String removeRepoConfirm(String repoName) {
    return 'Удалить $repoName?';
  }

  @override
  String get removeRepoWarning => 'Это удалит репозиторий и ВСЕ его плагины.';

  @override
  String get addRepository => 'Добавить репозиторий';

  @override
  String get repoUrlOrShortcode => 'URL репозитория или короткий код';

  @override
  String get assetPlugin => 'Встроенный плагин';

  @override
  String get installed => 'Установлено';

  @override
  String get repositories => 'Репозитории';

  @override
  String get noExtensionsInstalled => 'Расширения не установлены';

  @override
  String get browseRepositoriesToInstall =>
      'Откройте вкладку «Репозитории», чтобы найти и установить расширения.';

  @override
  String get browseRepositories => 'Обзор репозиториев';

  @override
  String get addRepoDescription =>
      'Добавьте URL репозитория или короткий код, чтобы найти и установить плагины расширений.';

  @override
  String updateTo(String version) {
    return 'Обновить до $version';
  }

  @override
  String get install => 'Установить';

  @override
  String get error => 'Ошибка';

  @override
  String get ok => 'ОК';

  @override
  String pluginSettings(String pluginName) {
    return 'Настройки $pluginName';
  }

  @override
  String get movies => 'Фильмы';

  @override
  String get series => 'Сериалы';

  @override
  String get anime => 'Аниме';

  @override
  String get liveStreams => 'Прямые трансляции';

  @override
  String get debug => 'ОТЛАДКА';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Обновлено $count расширений',
      few: 'Обновлено $count расширения',
      one: 'Обновлено 1 расширение',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => 'Неверная навигация.';

  @override
  String get startOver => 'Начать сначала';

  @override
  String get goBack => 'Назад';

  @override
  String get resolving => 'Разрешение ссылок...';

  @override
  String get downloaded => 'Скачано';

  @override
  String get download => 'Скачать';

  @override
  String get debugOnlyFeature => 'Только для дебаг-сборок';

  @override
  String get streamUrl => 'URL потока';

  @override
  String get play => 'Смотреть';

  @override
  String get verifyingSourceSize => 'Проверка источника и размера...';

  @override
  String get fileSaveLocationNotification =>
      'Файл будет сохранен в папку «Загрузки».';

  @override
  String get resumingPlayback => 'Возобновление воспроизведения';

  @override
  String pausedAt(String time) {
    return 'Пауза на $time';
  }

  @override
  String resumesAutomatically(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Автоматическое возобновление через $count секунд',
      few: 'Автоматическое возобновление через $count секунды',
      one: 'Автоматическое возобновление через 1 секунду',
    );
    return '$_temp0';
  }

  @override
  String get resumeNow => 'Возобновить сейчас';

  @override
  String get playbackError => 'Ошибка воспроизведения';

  @override
  String get confirmClearHistory => 'Вы уверены, что хотите очистить историю?';

  @override
  String seasonWithNumber(Object number) {
    return 'Сезон $number';
  }

  @override
  String get starting => 'Запуск...';

  @override
  String percentWatched(int percent) {
    return 'просмотрено $percent%';
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
  String get debugTools => 'Инструменты отладки';

  @override
  String get playLocalVideo => 'Локальное видео';

  @override
  String get playLocalVideoSubtitle => 'Воспроизвести файл с устройства';

  @override
  String get streamUrlSubtitle => 'Воспроизвести из сети (URL)';

  @override
  String get streamTorrent => 'Торрент-поток';

  @override
  String get streamTorrentSubtitle => 'Выберите торрент-файл';

  @override
  String get loadPluginFromAssets => 'Загрузить плагин из ресурсов';

  @override
  String get enterVideoUrlHint => 'Введите URL видео (http, magnet и т. д.)';

  @override
  String get networkStream => 'Сетевой поток';

  @override
  String removedFromHistory(String title) {
    return 'Удалено из истории: $title';
  }

  @override
  String get custom => 'Свой';

  @override
  String get refreshingLiveStream => 'Обновление трансляции...';

  @override
  String get removeFromHistory => 'Удалить из истории';

  @override
  String get live => 'ПРЯМОЙ ЭФИР';

  @override
  String get volume => 'Громкость';

  @override
  String get brightness => 'Яркость';

  @override
  String get fit => 'Заполнение';

  @override
  String get zoom => 'Зум';

  @override
  String get stretch => 'Растянуть';

  @override
  String titleWithParam(String title) {
    return 'Название: $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'Источник: $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'Размер: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'Ошибка: $error. Используется внутренний плеер.';
  }

  @override
  String playerNotDetected(String playerName) {
    return '$playerName не найден.';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return 'Сезон $number ($count серий)';
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
    return 'Источник для $playerName';
  }

  @override
  String get noPluginsInstalled => 'Нет установленных плагинов';

  @override
  String get noPluginsMessage =>
      'Установите расширения для просмотра и трансляции контента.';

  @override
  String get goToExtensions => 'Перейти к расширениям';

  @override
  String get availableSources => 'Доступные источники';

  @override
  String get seasons => 'Сезоны';

  @override
  String get episodes => 'Серии';

  @override
  String get selectSourceToPlay => 'Выберите источник из списка выше.';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count серий',
      few: '$count серии',
      one: '1 серия',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'Серии не найдены';

  @override
  String get local => 'Локальное';

  @override
  String get remote => 'Удаленное';

  @override
  String get torrent => 'Торрент';

  @override
  String get unlock => 'Разблокировать';

  @override
  String get lock => 'Блокировка';

  @override
  String get sources => 'Источники';

  @override
  String get tracks => 'Дорожки';

  @override
  String get content => 'Контент';

  @override
  String get stats => 'Статистика';

  @override
  String get resize => 'Размер';

  @override
  String get next => 'След.';

  @override
  String get pip => 'Картинка в картинке';

  @override
  String get rotate => 'Поворот';

  @override
  String get windowed => 'В окне';

  @override
  String get fullscreen => 'На весь экран';

  @override
  String get movieDetails => 'О фильме';

  @override
  String get showDetails => 'Показать детали';

  @override
  String get tagline => 'Слоган';

  @override
  String get status => 'Статус';

  @override
  String get releaseDate => 'Дата выхода';

  @override
  String get firstAirDate => 'Первый выход';

  @override
  String get originalLanguage => 'Язык оригинала';

  @override
  String get originCountry => 'Страна';

  @override
  String get budgetLabel => 'Бюджет';

  @override
  String get revenueLabel => 'Сборы';

  @override
  String get paused => 'Пауза';

  @override
  String get watched => 'Просмотрено';

  @override
  String get watching => 'Просмотр';

  @override
  String get lastWatched => 'Последний просмотр';

  @override
  String get movie => 'Фильм';

  @override
  String get tvShow => 'Сериал';

  @override
  String get failedToLoadContent => 'Ошибка загрузки';

  @override
  String get director => 'Режиссер';

  @override
  String get creator => 'Создатель';

  @override
  String get showMore => 'Показать больше';

  @override
  String get showLess => 'Показать меньше';

  @override
  String get viewAll => 'Все';

  @override
  String seasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сезонов',
      few: '$count сезона',
      one: '1 сезон',
    );
    return '$_temp0';
  }

  @override
  String get noInternetError => 'Нет интернета';

  @override
  String get timeoutError => 'Время ожидания истекло.';

  @override
  String get serverError => 'Ошибка сервера.';

  @override
  String get contentNotFoundError => 'Не найдено.';

  @override
  String get accessDeniedError => 'Доступ запрещен.';

  @override
  String get serviceUnavailableError => 'Сервис недоступен.';

  @override
  String get generalError => 'Произошла ошибка.';

  @override
  String get skip => 'Пропустить';

  @override
  String get skipIntro => 'Пропустить заставку';

  @override
  String get skipOutro => 'Пропустить титры';

  @override
  String get skipRecap => 'Пропустить краткий обзор';

  @override
  String get goLive => 'В эфир';

  @override
  String get dismiss => 'Закрыть';

  @override
  String get nextUp => 'Далее';

  @override
  String sourceAttempt(int index, int total) {
    return 'Источник $index из $total';
  }

  @override
  String get trying => 'Пробуем';

  @override
  String get failed => 'Ошибка';

  @override
  String get selected => 'Выбрано';

  @override
  String get playing => 'Играет';

  @override
  String get pending => 'Ожидание';

  @override
  String get openSubtitles => 'OpenSubtitles';

  @override
  String get subDl => 'SubDL';

  @override
  String get subSource => 'SubSource';

  @override
  String get wifiQualityPreference => 'Качество при Wi-Fi';

  @override
  String get mobileQualityPreference => 'Качество при мобильной сети';

  @override
  String get anyNoPreference => 'Любое (без предпочтений)';

  @override
  String get subtitleAccounts => 'Аккаунты субтитров';

  @override
  String get accounts => 'Аккаунты';

  @override
  String get notLoggedIn => 'Вход не выполнен';

  @override
  String loggedInAs(String username) {
    return 'Вы вошли как $username';
  }

  @override
  String get apiKeyConfigured => 'API-ключ настроен';

  @override
  String get keyNotSet => 'Ключ не установлен';

  @override
  String get testConnection => 'Проверить соединение';

  @override
  String get connectedSuccessfully => 'Успешно подключено';

  @override
  String get connectionFailed => 'Ошибка подключения';

  @override
  String get username => 'Имя пользователя';

  @override
  String get password => 'Пароль';

  @override
  String get noAccountRegister => 'Нет аккаунта? Зарегистрируйтесь здесь';

  @override
  String get apiKey => 'API-ключ';

  @override
  String get email => 'Электронная почта';

  @override
  String get fetchMyApiKey => 'Получить мой API-ключ';

  @override
  String get keyVerified => 'Ключ проверен';

  @override
  String get invalidApiKey => 'Неверный API-ключ';

  @override
  String get openSubtitlesAuthSubtitle =>
      'Введите данные своего аккаунта для увеличения лимитов и отключения рекламы.';

  @override
  String get subDlAuthSubtitle =>
      'Введите ключ SubDL API напрямую или получите его, используя данные своего аккаунта ниже.';

  @override
  String get orFetchViaAccount => 'ИЛИ ПОЛУЧИТЬ ЧЕРЕЗ АККАУНТ';

  @override
  String get subSourceAuthSubtitle =>
      'SubSource работает из коробки, но вы можете добавить личный API-ключ для повышения надежности.';

  @override
  String get apiKeyOptionalOverride => 'API-ключ (необязательно)';

  @override
  String get enterKeyToOverrideDefault =>
      'Введите ключ для переопределения стандартного';

  @override
  String get getApiKeyFromProfile => 'Получите API-ключ в профиле SubSource';

  @override
  String get qualityNotGuaranteed =>
      'Качество не гарантируется. Источники сортируются по предпочтению, но воспроизведение зависит от того, что предлагает провайдер.';

  @override
  String get keepSourcesOriginalOrder =>
      'Сохранять оригинальный порядок источников';

  @override
  String get openLink => 'Открыть ссылку';

  @override
  String get diagnostics => 'Диагностика';

  @override
  String get viewLogs => 'Просмотр журналов';

  @override
  String get viewLogsSubtitle => 'Просмотр активности и ошибок приложения';

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
