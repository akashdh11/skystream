// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => 'Español';

  @override
  String get addonHealthChecking => 'Checking add-on…';

  @override
  String addonHealthWorking(int ms) {
    return 'Working · $ms ms';
  }

  @override
  String get addonHealthUnavailable => 'Unavailable';

  @override
  String get home => 'Inicio';

  @override
  String get search => 'Buscar';

  @override
  String get explore => 'Explorar';

  @override
  String get exploreAnime => 'Explorar anime';

  @override
  String get exploreMovies => 'Explorar películas';

  @override
  String get library => 'Biblioteca';

  @override
  String get settings => 'Ajustes';

  @override
  String get extensions => 'Extensiones';

  @override
  String get updateAvailable => 'Actualización disponible';

  @override
  String get retry => 'Reintentar';

  @override
  String get factoryReset => 'Restablecimiento de fábrica';

  @override
  String get startupError => 'Error de inicio';

  @override
  String get general => 'General';

  @override
  String get appTheme => 'Tema de la aplicación';

  @override
  String get recordWatchHistory => 'Historial de visualización';

  @override
  String get fullScreenMode => 'Pantalla completa';

  @override
  String get fullScreenModeSubtitle => 'Cambia a la vista de TV';

  @override
  String get defaultHomeScreen => 'Pantalla de inicio predeterminada';

  @override
  String get titlePosition => 'Posición del título';

  @override
  String get titlePositionBelowPoster => 'Debajo del póster';

  @override
  String get titlePositionInsidePoster => 'Dentro del póster';

  @override
  String get player => 'Reproductor';

  @override
  String get defaultPlayer => 'Reproductor predeterminado';

  @override
  String get leftGesture => 'Gesto izquierdo';

  @override
  String get rightGesture => 'Gesto derecho';

  @override
  String get doubleTapToSeek => 'Doble toque para buscar';

  @override
  String get swipeToSeek => 'Deslizar para buscar';

  @override
  String get seekDuration => 'Duración de búsqueda';

  @override
  String get defaultResizeMode => 'Modo de escalado predeterminado';

  @override
  String get hardwareDecoding => 'Decodificación por hardware';

  @override
  String get network => 'Red';

  @override
  String get dnsOverHttps => 'DNS sobre HTTPS';

  @override
  String get dohProvider => 'Proveedor DoH';

  @override
  String get githubProxy => 'Proxy de GitHub';

  @override
  String get githubProxySubtitle =>
      'Enruta las descargas de extensiones a través de jsDelivr para evitar bloqueos del proveedor.';

  @override
  String get manageExtensions => 'Gestionar extensiones';

  @override
  String get appData => 'Datos de la aplicación';

  @override
  String get resetDataKeepExtensions =>
      'Restablecer datos (mantener extensiones)';

  @override
  String get developer => 'Desarrollador';

  @override
  String get developerOptions => 'Opciones de desarrollador';

  @override
  String get about => 'Acerca de';

  @override
  String get version => 'Versión';

  @override
  String get enabled => 'Activado';

  @override
  String get disabled => 'Desactivado';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'Únete a nuestro servidor';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'Únete a nuestro canal';

  @override
  String developedBy(String name) {
    return 'Desarrollado por $name';
  }

  @override
  String get system => 'Sistema';

  @override
  String get dark => 'Oscuro';

  @override
  String get light => 'Claro';

  @override
  String get later => 'Más tarde';

  @override
  String get updateNow => 'Actualizar ahora';

  @override
  String get save => 'Guardar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get close => 'Cerrar';

  @override
  String get delete => 'Eliminar';

  @override
  String get viewDetails => 'Ver detalles';

  @override
  String get clearAll => 'Limpiar todo';

  @override
  String get clearAllHistory => 'Limpiar todo el historial';

  @override
  String get all => 'Todo';

  @override
  String get none => 'Ninguno';

  @override
  String get confirmDownload => 'Confirmar descarga';

  @override
  String get downloadNow => 'Descargar ahora';

  @override
  String get selectSource => 'Seleccionar fuente';

  @override
  String get downloadUnavailable => 'Descarga no disponible';

  @override
  String get selectAnotherSource => 'Seleccionar otra fuente';

  @override
  String get watchHistoryCleared => 'Historial de visualización limpiado';

  @override
  String get downloadingUpdate => 'Descargando actualización...';

  @override
  String errorPrefix(String message) {
    return 'Error: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'Actualización disponible: $tag';
  }

  @override
  String get selectProviderToStart => 'Selecciona un proveedor para empezar';

  @override
  String get tapExtensionIcon => 'Toca el icono de la extensión en la esquina';

  @override
  String get continueWatching => 'Continuar viendo';

  @override
  String get noInternetConnection => 'Sin conexión a Internet';

  @override
  String get siteNotReachable => 'Sitio no accesible';

  @override
  String get checkConnectionOrDownloads =>
      'Comprueba tu conexión o mira tus contenidos descargados.';

  @override
  String get tryVpnOrConnection =>
      'Intenta acceder con una VPN o comprueba tu conexión a Internet.';

  @override
  String errorDetails(String error) {
    return 'Detalles del error: $error';
  }

  @override
  String get goToDownloads => 'Ir a descargas';

  @override
  String get selectProvider => 'Seleccionar proveedor';

  @override
  String get searchHint => 'Buscar películas, series...';

  @override
  String get searchFavoriteContent => 'Busca tu contenido favorito';

  @override
  String get pressSearchOrEnter => 'Pulsa Buscar o Enter para empezar';

  @override
  String get recentSearches => 'Recent searches';

  @override
  String removeFromSearchHistory(String query) {
    return 'Remove $query from search history';
  }

  @override
  String get noResultsFound => 'No se encontraron resultados.';

  @override
  String get couldNotLoadTrending => 'No se pudieron cargar las tendencias';

  @override
  String get popularMovies => 'Películas populares';

  @override
  String get popularTVShows => 'Series populares';

  @override
  String get newMovies => 'Películas nuevas';

  @override
  String get newTVShows => 'Series nuevas';

  @override
  String get featuredMovies => 'Películas destacadas';

  @override
  String get featuredTVShows => 'Series destacadas';

  @override
  String get lastVideosTVShows => 'Últimas series';

  @override
  String get downloads => 'Descargas';

  @override
  String get bookmarks => 'Marcadores';

  @override
  String get noDownloadsYet => 'Aún no hay descargas';

  @override
  String episodesCount(int count, int done) {
    return '$count Episodios • $done Terminados';
  }

  @override
  String get deleteAllEpisodes => 'Eliminar todos los episodios';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return '¿Estás seguro de que quieres eliminar los $count episodios de \"$title\" y sus archivos?';
  }

  @override
  String get deleteAll => 'Eliminar todo';

  @override
  String get completed => 'Completado';

  @override
  String get statusQueued => 'En cola...';

  @override
  String get statusDownloading => 'Descargando...';

  @override
  String get statusFinished => 'Finalizado';

  @override
  String get statusFailed => 'Fallido';

  @override
  String get statusCanceled => 'Cancelado';

  @override
  String get statusPaused => 'Pausado';

  @override
  String get statusWaiting => 'Esperando...';

  @override
  String get fileNotFoundRemoving =>
      'Archivo no encontrado. Eliminando registro.';

  @override
  String get fileNotFound => 'Archivo no encontrado';

  @override
  String get deleteDownload => 'Eliminar descarga';

  @override
  String get confirmDeleteDownload =>
      '¿Estás seguro de que quieres eliminar esta descarga y su archivo?';

  @override
  String get libraryEmpty => 'Tu biblioteca está vacía';

  @override
  String get language => 'Idioma';

  @override
  String get english => 'Inglés';

  @override
  String get hindi => 'Hindi';

  @override
  String get kannada => 'Kannada';

  @override
  String get unknown => 'Desconocido';

  @override
  String get recommended => 'Recomendado';

  @override
  String get on => 'Encendido';

  @override
  String get off => 'Apagado';

  @override
  String get installRemoveProviders => 'Instalar o eliminar proveedores';

  @override
  String get resetDataSubtitle =>
      'Limpiar ajustes y base de datos, mantener plugins';

  @override
  String get factoryResetSubtitle =>
      'Eliminar todos los datos, ajustes y extensiones';

  @override
  String get developerOptionsSubtitle =>
      'Herramientas de depuración y reproducción local';

  @override
  String get loading => 'Cargando...';

  @override
  String get sec => 'seg';

  @override
  String get min => 'min';

  @override
  String playerRewindSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Retroceder $count segundos',
      one: 'Retroceder 1 segundo',
    );
    return '$_temp0';
  }

  @override
  String playerForwardSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Avanzar $count segundos',
      one: 'Avanzar 1 segundo',
    );
    return '$_temp0';
  }

  @override
  String get internalPlayer => 'Interno (VLC)';

  @override
  String get builtInPlayer => 'Reproductor integrado';

  @override
  String get customNotSet => 'Personalizado (no establecido)';

  @override
  String selectGesture(String side) {
    return 'Seleccionar gesto $side';
  }

  @override
  String get left => 'Izquierdo';

  @override
  String get right => 'Derecho';

  @override
  String get selectSeekDuration => 'Seleccionar duración de búsqueda';

  @override
  String get subtitleSettings => 'Ajustes de subtítulos';

  @override
  String size(int size) {
    return 'Tamaño: $size';
  }

  @override
  String get background => 'Fondo';

  @override
  String get customDohUrlLabel => 'URL DoH personalizada';

  @override
  String get enterCustomDohUrl => 'Introduce tu propia URL DoH';

  @override
  String get chooseTheme => 'Elegir tema';

  @override
  String get resetDataDialogTitle => '¿Restablecer datos?';

  @override
  String get resetDataDialogContent =>
      'Esto borrará Ajustes, Favoritos e Historial. Tus extensiones instaladas NO se eliminarán.';

  @override
  String get factoryResetDialogTitle => '¿Restablecimiento de fábrica?';

  @override
  String get factoryResetDialogContent =>
      'Esto eliminará TODO: Favoritos, Historial, Ajustes y TODAS las extensiones. No se puede deshacer.';

  @override
  String get selectLanguage => 'Seleccionar idioma';

  @override
  String get synopsis => 'Sinopsis';

  @override
  String get noDescription => 'Sin descripción disponible.';

  @override
  String get videoAlreadyDownloadedPrompt =>
      'Este vídeo ya está descargado. ¿Qué prefieres hacer?';

  @override
  String get playNow => 'Reproducir ahora';

  @override
  String get upNext => 'A continuación';

  @override
  String get deleteDownloadPrompt => '¿Eliminar descarga?';

  @override
  String get deleteDownloadConfirmation =>
      '¿Estás seguro de que quieres eliminar este archivo? No se puede deshacer.';

  @override
  String get no => 'No';

  @override
  String get yesDelete => 'Sí, eliminar';

  @override
  String get downloadPaused => 'Descarga pausada';

  @override
  String get downloading => 'Descargando';

  @override
  String get speed => 'Velocidad';

  @override
  String get remaining => 'Restante';

  @override
  String get resume => 'Reanudar';

  @override
  String get pause => 'Pausa';

  @override
  String get torrentContent => 'Contenido del Torrent';

  @override
  String get audioTracks => 'Pistas de audio';

  @override
  String get noAudioTracks => 'No se encontraron pistas de audio';

  @override
  String get subtitles => 'Subtítulos';

  @override
  String get options => 'Opciones';

  @override
  String get noSubtitlesFound => 'No se encontraron subtítulos';

  @override
  String get playbackSpeed => 'Velocidad de reproducción';

  @override
  String get subtitleOptions => 'Opciones de subtítulos';

  @override
  String get hlsSubtitleWarning =>
      'Los subtítulos externos no son compatibles con el reproductor HLS activo en esta plataforma.';

  @override
  String get loadFromDevice => 'Cargar desde dispositivo';

  @override
  String get syncDelay => 'Sincronización / Retraso';

  @override
  String get styleSettings => 'Ajustes de estilo';

  @override
  String get searchOnline => 'Buscar en línea (Subtitle Search)';

  @override
  String get subtitleSync => 'Sincronización de subtítulos';

  @override
  String get subtitleDelayWarning =>
      'El retraso de subtítulos no es compatible con el motor de reproducción activo.';

  @override
  String get resetDelay => 'Restablecer retraso';

  @override
  String get subtitleStyles => 'Estilos de subtítulos';

  @override
  String get resetToDefault => 'Restablecer';

  @override
  String get fontSize => 'Tamaño de fuente';

  @override
  String get verticalPosition => 'Posición vertical';

  @override
  String get textColor => 'Color del texto';

  @override
  String get backgroundColor => 'Color de fondo';

  @override
  String get backgroundOpacity => 'Opacidad de fondo';

  @override
  String get subtitleSearch => 'Búsqueda de subtítulos';

  @override
  String get searchSubtitleNameHint => 'Buscar subtítulo...';

  @override
  String get enterSearchSubtitlePrompt =>
      'Introduce un nombre para buscar subtítulos.';

  @override
  String get noSubtitleResults =>
      'No se encontraron resultados. Prueba otra consulta.';

  @override
  String get downloadingApplyingSubtitle =>
      'Descargando y aplicando subtítulo...';

  @override
  String get failedToDownloadSubtitle => 'Error al descargar el subtítulo.';

  @override
  String get failedToLoadSubtitles =>
      'Error al cargar los subtítulos. Inténtalo de nuevo.';

  @override
  String get noReposFound => 'No se encontraron repositorios ni plugins';

  @override
  String get downloadAllProviders => 'Descargar todo';

  @override
  String get removeRepository => 'Eliminar repositorio';

  @override
  String get addRepo => 'Añadir repositorio';

  @override
  String get extensionsNotInRepos => 'Extensiones fuera de repositorios';

  @override
  String get noLongerInRepo => 'Ya no figura en ningún repositorio';

  @override
  String get addRepoToBrowse =>
      'Añade un repositorio para ver y actualizar plugins';

  @override
  String get debugExtensions => 'Depurar extensiones';

  @override
  String removeRepoConfirm(String repoName) {
    return '¿Eliminar $repoName?';
  }

  @override
  String get removeRepoWarning =>
      'Esto eliminará el repositorio y desinstalará TODOS sus plugins.';

  @override
  String get addRepository => 'Añadir repositorio';

  @override
  String get repoUrlOrShortcode => 'URL del repositorio o Código corto';

  @override
  String get assetPlugin => 'Plugin de recursos';

  @override
  String get installed => 'Instalado';

  @override
  String get repositories => 'Repositorios';

  @override
  String get noExtensionsInstalled => 'No hay extensiones instaladas';

  @override
  String get browseRepositoriesToInstall =>
      'Abre la pestaña Repositorios para descubrir e instalar extensiones.';

  @override
  String get browseRepositories => 'Explorar repositorios';

  @override
  String get addRepoDescription =>
      'Añade la URL de un repositorio o un código corto para descubrir e instalar complementos.';

  @override
  String updateTo(String version) {
    return 'Actualizar a $version';
  }

  @override
  String get install => 'Instalar';

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
  String get error => 'Error';

  @override
  String get ok => 'Aceptar';

  @override
  String pluginSettings(String pluginName) {
    return 'Ajustes de $pluginName';
  }

  @override
  String get movies => 'Películas';

  @override
  String get series => 'Series';

  @override
  String get anime => 'Anime';

  @override
  String get liveStreams => 'Streams en vivo';

  @override
  String get debug => 'DEPURAR';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count extensiones actualizadas',
      one: '1 extensión actualizada',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation =>
      'Navegación no válida. Por favor, vuelve atrás.';

  @override
  String get startOver => 'Empezar de nuevo';

  @override
  String get goBack => 'Atrás';

  @override
  String get restartApp => 'Reiniciar la aplicación';

  @override
  String get resolving => 'Resolviendo...';

  @override
  String get downloaded => 'Descargado';

  @override
  String get download => 'Descargar';

  @override
  String get debugOnlyFeature =>
      'Esta función solo está disponible en versiones de depuración';

  @override
  String get streamUrl => 'URL de transmisión';

  @override
  String get play => 'Reproducir';

  @override
  String get verifyingSourceSize => 'Verificando fuente y tamaño...';

  @override
  String get fileSaveLocationNotification =>
      'El archivo se guardará en tu carpeta de descargas.';

  @override
  String get resumingPlayback => 'Reanudando reproducción';

  @override
  String pausedAt(String time) {
    return 'Pausado en $time';
  }

  @override
  String resumesAutomatically(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se reanuda automáticamente en $count segundos',
      one: 'Se reanuda automáticamente en 1 segundo',
    );
    return '$_temp0';
  }

  @override
  String get resumeNow => 'Reanudar ahora';

  @override
  String get playbackError => 'Error de reproducción';

  @override
  String get confirmClearHistory =>
      '¿Estás seguro de que quieres eliminar todos los elementos del historial?';

  @override
  String seasonWithNumber(Object number) {
    return 'Temporada $number';
  }

  @override
  String get starting => 'Iniciando...';

  @override
  String percentWatched(int percent) {
    return '$percent% visto';
  }

  @override
  String get sub => 'Sub';

  @override
  String get dub => 'Dob';

  @override
  String playEpisode(String label, Object season, Object episode) {
    return '$label T$season E$episode';
  }

  @override
  String playEpisodeOnly(String label, int episode) {
    return '$label E$episode';
  }

  @override
  String get debugTools => 'Herramientas de depuración';

  @override
  String get playLocalVideo => 'Reproducir archivo de vídeo local';

  @override
  String get playLocalVideoSubtitle =>
      'Reproducir cualquier vídeo del dispositivo';

  @override
  String get streamUrlSubtitle => 'Reproducir desde URL';

  @override
  String get streamTorrent => 'Transmitir torrent';

  @override
  String get streamTorrentSubtitle => 'Seleccionar un archivo torrent local';

  @override
  String get loadPluginFromAssets => 'Cargar plugin desde activos';

  @override
  String get enterVideoUrlHint =>
      'Introduce la URL del vídeo (http, magnet, etc.)';

  @override
  String get networkStream => 'Transmisión de red';

  @override
  String removedFromHistory(String title) {
    return 'Eliminado $title del historial';
  }

  @override
  String get custom => 'Personalizado';

  @override
  String get refreshingLiveStream => 'Refrescando transmisión en vivo...';

  @override
  String get removeFromHistory => 'Eliminar del historial';

  @override
  String get live => 'DIRECTO';

  @override
  String get volume => 'Volumen';

  @override
  String get decrease => 'Decrease';

  @override
  String get increase => 'Increase';

  @override
  String get brightness => 'Brillo';

  @override
  String get fit => 'Ajustar';

  @override
  String get zoom => 'Zoom';

  @override
  String get stretch => 'Estirar';

  @override
  String titleWithParam(String title) {
    return 'Título: $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'Fuente: $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'Tamaño: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'Error: $error. Usando reproductor interno.';
  }

  @override
  String externalPlayerCannotSendHeaders(String playerName, String headers) {
    return '$playerName cannot send $headers. Using internal player.';
  }

  @override
  String playerNotDetected(String playerName) {
    return '$playerName no detectado. Iniciando reproductor interno.';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return 'Temporada $number ($count Episodios)';
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
    return 'Seleccionar fuente para $playerName';
  }

  @override
  String get noPluginsInstalled => 'No hay plugins instalados';

  @override
  String get noPluginsMessage =>
      'Instala extensiones para navegar y transmitir contenido.';

  @override
  String get goToExtensions => 'Ir a extensiones';

  @override
  String get availableSources => 'Fuentes disponibles';

  @override
  String get seasons => 'Temporadas';

  @override
  String get episodes => 'Episodios';

  @override
  String get selectSourceToPlay =>
      'Selecciona una fuente arriba para reproducir.';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Episodios',
      one: '1 Episodio',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'No se encontraron episodios';

  @override
  String get local => 'Local';

  @override
  String get remote => 'Remoto';

  @override
  String get torrent => 'Torrent';

  @override
  String get unlock => 'Desbloquear';

  @override
  String get lock => 'Bloquear';

  @override
  String get sources => 'Fuentes';

  @override
  String get tracks => 'Pistas';

  @override
  String get content => 'Contenido';

  @override
  String get stats => 'Estadísticas';

  @override
  String get resize => 'Redimensionar';

  @override
  String get next => 'Siguiente';

  @override
  String get previous => 'Previous';

  @override
  String get pip => 'PiP';

  @override
  String get rotate => 'Rotar';

  @override
  String get windowed => 'Ventana';

  @override
  String get fullscreen => 'Pantalla completa';

  @override
  String get movieDetails => 'Detalles de la película';

  @override
  String get showDetails => 'Ver detalles';

  @override
  String get tagline => 'Eslogan';

  @override
  String get status => 'Estado';

  @override
  String get releaseDate => 'Fecha de estreno';

  @override
  String get firstAirDate => 'Fecha de primera emisión';

  @override
  String get originalLanguage => 'Idioma original';

  @override
  String get originCountry => 'País de origen';

  @override
  String get budgetLabel => 'Presupuesto';

  @override
  String get revenueLabel => 'Recaudación';

  @override
  String get paused => 'Pausado';

  @override
  String get watched => 'Visto';

  @override
  String get watching => 'Viendo';

  @override
  String get lastWatched => 'Visto recientemente';

  @override
  String get movie => 'Película';

  @override
  String get tvShow => 'Serie TV';

  @override
  String get failedToLoadContent => 'Error al cargar contenido';

  @override
  String get director => 'Director';

  @override
  String get creator => 'Creador';

  @override
  String get showMore => 'Ver más';

  @override
  String get showLess => 'Ver menos';

  @override
  String get viewAll => 'Ver todo';

  @override
  String seasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Temporadas',
      one: '1 Temporada',
    );
    return '$_temp0';
  }

  @override
  String get noInternetError => 'Sin conexión a Internet';

  @override
  String get timeoutError => 'Tiempo de espera agotado. Inténtalo de nuevo.';

  @override
  String get serverError => 'Error del servidor. Inténtalo de nuevo más tarde.';

  @override
  String get contentNotFoundError => 'Contenido no encontrado.';

  @override
  String get accessDeniedError => 'Acceso denegado. Revisa tus credenciales.';

  @override
  String get serviceUnavailableError =>
      'Servidor no disponible. Reinténtalo más tarde.';

  @override
  String get generalError => 'Algo salió mal. Por favor, inténtalo de nuevo.';

  @override
  String get skip => 'Omitir';

  @override
  String get skipIntro => 'Saltar intro';

  @override
  String get skipOutro => 'Saltar créditos';

  @override
  String get skipRecap => 'Saltar resumen';

  @override
  String get goLive => 'En directo';

  @override
  String get dismiss => 'Cerrar';

  @override
  String get nextUp => 'Siguiente';

  @override
  String sourceAttempt(int index, int total) {
    return 'Fuente $index de $total';
  }

  @override
  String get trying => 'Intentando';

  @override
  String get failed => 'Fallido';

  @override
  String get selected => 'Seleccionado';

  @override
  String get playing => 'Reproduciendo';

  @override
  String get pending => 'Pendiente';

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
  String get mobileQualityPreference => 'Preferencia de calidad móvil';

  @override
  String get anyNoPreference => 'Cualquiera (sin preferencia)';

  @override
  String get subtitleAccounts => 'Cuentas de subtítulos';

  @override
  String get accounts => 'Cuentas';

  @override
  String get notLoggedIn => 'No ha iniciado sesión';

  @override
  String loggedInAs(String username) {
    return 'Sesión iniciada como $username';
  }

  @override
  String get apiKeyConfigured => 'Clave API configurada';

  @override
  String get keyNotSet => 'Clave no establecida';

  @override
  String get testConnection => 'Probar conexión';

  @override
  String get connectedSuccessfully => 'Conectado con éxito';

  @override
  String get connectionFailed => 'Error de conexión';

  @override
  String get username => 'Nombre de usuario';

  @override
  String get password => 'Contraseña';

  @override
  String get noAccountRegister => '¿No tienes cuenta? Registrate aquí';

  @override
  String get apiKey => 'Clave API';

  @override
  String get email => 'Correo electrónico';

  @override
  String get fetchMyApiKey => 'Obtener mi clave API';

  @override
  String get keyVerified => 'Clave verificada';

  @override
  String get invalidApiKey => 'Clave API no válida';

  @override
  String get openSubtitlesAuthSubtitle =>
      'Ingrese sus credenciales para límites más altos y subtítulos sin anuncios.';

  @override
  String get subDlAuthSubtitle =>
      'Ingrese su clave API de SubDL directamente o extráigala usando sus credenciales.';

  @override
  String get orFetchViaAccount => 'O OBTENER VÍA CUENTA';

  @override
  String get subSourceAuthSubtitle =>
      'SubSource funciona por defecto, pero puede añadir una clave API oficial para mejorar la fiabilidad.';

  @override
  String get apiKeyOptionalOverride => 'Clave API (Opcional)';

  @override
  String get enterKeyToOverrideDefault =>
      'Ingrese clave para anular el valor por defecto';

  @override
  String get getApiKeyFromProfile =>
      'Obtenga su clave API del perfil de SubSource';

  @override
  String get qualityNotGuaranteed =>
      'La calidad no está garantizada. Las fuentes se ordenan por preferencia, pero dependen de lo que ofrece el proveedor.';

  @override
  String get keepSourcesOriginalOrder =>
      'Mantener orden original de las fuentes';

  @override
  String get openLink => 'Abrir enlace';

  @override
  String get diagnostics => 'Diagnósticos';

  @override
  String get viewLogs => 'Ver registros';

  @override
  String get viewLogsSubtitle => 'Ver actividad y errores de la aplicación';

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
  String get sourcesSearching => 'Buscando en los scrapers…';

  @override
  String get sourcesEmptyFiltered => 'Ningún enlace coincide con los filtros.';

  @override
  String get sourcesEmptyNoTmdbId =>
      'Este título no tiene ID de TMDB. Introdúcelo con \'Search manually\'.';

  @override
  String get sourcesEmptyNoScrapers =>
      'No hay scrapers activos. Añade uno en \'Nuvio Plugins\'.';

  @override
  String get sourcesEmptyAllFailed =>
      'Todos los scrapers fallaron. Comprueba tu conexión o actualízalos.';

  @override
  String sourcesEmptySomeFailed(int failed, int total) {
    return 'No se encontraron enlaces. Fallaron $failed de $total scrapers.';
  }

  @override
  String get sourcesEmptyNothingFound =>
      'Ninguno de tus scrapers tiene este título.';

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
