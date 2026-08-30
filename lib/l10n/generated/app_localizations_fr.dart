// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => 'Français';

  @override
  String get home => 'Accueil';

  @override
  String get search => 'Recherche';

  @override
  String get explore => 'Explorer';

  @override
  String get exploreAnime => 'Explorer les animes';

  @override
  String get exploreMovies => 'Explorer les films';

  @override
  String get library => 'Bibliothèque';

  @override
  String get settings => 'Paramètres';

  @override
  String get extensions => 'Extensions';

  @override
  String get updateAvailable => 'Mise à jour disponible';

  @override
  String get retry => 'Réessayer';

  @override
  String get factoryReset => 'Réinitialisation d\'usine';

  @override
  String get startupError => 'Erreur de démarrage';

  @override
  String get general => 'Général';

  @override
  String get appTheme => 'Thème de l\'application';

  @override
  String get recordWatchHistory => 'Historique de lecture';

  @override
  String get defaultHomeScreen => 'Écran d\'accueil par défaut';

  @override
  String get titlePosition => 'Position du titre';

  @override
  String get titlePositionBelowPoster => 'Sous l\'affiche';

  @override
  String get titlePositionInsidePoster => 'Sur l\'affiche';

  @override
  String get player => 'Lecteur';

  @override
  String get defaultPlayer => 'Lecteur par défaut';

  @override
  String get leftGesture => 'Geste gauche';

  @override
  String get rightGesture => 'Geste droit';

  @override
  String get doubleTapToSeek => 'Double tape pour avancer/reculer';

  @override
  String get swipeToSeek => 'Glisser pour avancer/reculer';

  @override
  String get seekDuration => 'Durée de saut';

  @override
  String get bufferDepth => 'Profondeur du tampon';

  @override
  String get defaultResizeMode => 'Mode de redimensionnement par défaut';

  @override
  String get hardwareDecoding => 'Décodage matériel';

  @override
  String get network => 'Réseau';

  @override
  String get dnsOverHttps => 'DNS via HTTPS';

  @override
  String get dohProvider => 'Fournisseur DoH';

  @override
  String get githubProxy => 'Proxy GitHub';

  @override
  String get githubProxySubtitle =>
      'Faire transiter les téléchargements d\'extensions par jsDelivr pour contourner les blocages du FAI.';

  @override
  String get manageExtensions => 'Gérer les extensions';

  @override
  String get appData => 'Données de l\'application';

  @override
  String get resetDataKeepExtensions =>
      'Réinitialiser les données (conserver les extensions)';

  @override
  String get developer => 'Développeur';

  @override
  String get developerOptions => 'Options développeur';

  @override
  String get about => 'À propos';

  @override
  String get version => 'Version';

  @override
  String get enabled => 'Activé';

  @override
  String get disabled => 'Désactivé';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'Rejoignez notre serveur';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'Rejoignez notre chaîne';

  @override
  String developedBy(String name) {
    return 'Développé par $name';
  }

  @override
  String get system => 'Système';

  @override
  String get dark => 'Sombre';

  @override
  String get light => 'Clair';

  @override
  String get later => 'Plus tard';

  @override
  String get updateNow => 'Mettre à jour maintenant';

  @override
  String get save => 'Enregistrer';

  @override
  String get cancel => 'Annuler';

  @override
  String get close => 'Fermer';

  @override
  String get delete => 'Supprimer';

  @override
  String get viewDetails => 'Voir les détails';

  @override
  String get clearAll => 'Tout effacer';

  @override
  String get clearAllHistory => 'Effacer tout l\'historique';

  @override
  String get all => 'Tout';

  @override
  String get none => 'Aucun';

  @override
  String get confirmDownload => 'Confirmer le téléchargement';

  @override
  String get downloadNow => 'Télécharger maintenant';

  @override
  String get selectSource => 'Sélectionner la source';

  @override
  String get downloadUnavailable => 'Téléchargement indisponible';

  @override
  String get selectAnotherSource => 'Sélectionner une autre source';

  @override
  String get watchHistoryCleared => 'Historique de lecture effacé';

  @override
  String get downloadingUpdate => 'Téléchargement de la mise à jour...';

  @override
  String errorPrefix(String message) {
    return 'Erreur : $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'Mise à jour disponible : $tag';
  }

  @override
  String get selectProviderToStart =>
      'Sélectionnez un fournisseur pour commencer à regarder';

  @override
  String get tapExtensionIcon =>
      'Appuyez sur l\'icône de l\'extension dans le coin';

  @override
  String get continueWatching => 'Continuer à regarder';

  @override
  String get noInternetConnection => 'Pas de connexion Internet';

  @override
  String get siteNotReachable => 'Site inaccessible';

  @override
  String get checkConnectionOrDownloads =>
      'Vérifiez votre connexion ou consultez vos contenus téléchargés.';

  @override
  String get tryVpnOrConnection =>
      'Veuillez essayer d\'accéder au site avec un VPN ou vérifiez votre connexion Internet.';

  @override
  String errorDetails(String error) {
    return 'Détails de l\'erreur : $error';
  }

  @override
  String get goToDownloads => 'Aller aux téléchargements';

  @override
  String get selectProvider => 'Sélectionner le fournisseur';

  @override
  String get searchHint => 'Rechercher des films, séries...';

  @override
  String get searchFavoriteContent => 'Recherchez votre contenu préféré';

  @override
  String get pressSearchOrEnter =>
      'Appuyez sur la touche Recherche ou Entrée pour commencer';

  @override
  String get noResultsFound => 'Aucun résultat trouvé.';

  @override
  String get couldNotLoadTrending => 'Impossible de charger les tendances';

  @override
  String get popularMovies => 'Films populaires';

  @override
  String get popularTVShows => 'Séries populaires';

  @override
  String get newMovies => 'Nouveaux films';

  @override
  String get newTVShows => 'Nouvelles séries';

  @override
  String get featuredMovies => 'Films en vedette';

  @override
  String get featuredTVShows => 'Séries en vedette';

  @override
  String get lastVideosTVShows => 'Dernières séries';

  @override
  String get downloads => 'Téléchargements';

  @override
  String get bookmarks => 'Favoris';

  @override
  String get noDownloadsYet => 'Aucun téléchargement pour le moment';

  @override
  String episodesCount(int count, int done) {
    return '$count Épisodes • $done Terminés';
  }

  @override
  String get deleteAllEpisodes => 'Supprimer tous les épisodes';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return 'Êtes-vous sûr de vouloir supprimer les $count épisodes de \"$title\" et leurs fichiers ?';
  }

  @override
  String get deleteAll => 'Tout supprimer';

  @override
  String get completed => 'Terminé';

  @override
  String get statusQueued => 'En attente...';

  @override
  String get statusDownloading => 'Téléchargement...';

  @override
  String get statusFinished => 'Terminé';

  @override
  String get statusFailed => 'Échoué';

  @override
  String get statusCanceled => 'Annulé';

  @override
  String get statusPaused => 'En pause';

  @override
  String get statusWaiting => 'Attente...';

  @override
  String get fileNotFoundRemoving =>
      'Fichier introuvable sur le disque. Suppression de l\'enregistrement.';

  @override
  String get fileNotFound => 'Fichier introuvable';

  @override
  String get deleteDownload => 'Supprimer le téléchargement';

  @override
  String get confirmDeleteDownload =>
      'Êtes-vous sûr de vouloir supprimer ce téléchargement et son fichier ?';

  @override
  String get libraryEmpty => 'Votre bibliothèque est vide';

  @override
  String get language => 'Langue';

  @override
  String get english => 'Anglais';

  @override
  String get hindi => 'Hindi';

  @override
  String get kannada => 'Kannada';

  @override
  String get unknown => 'Inconnu';

  @override
  String get recommended => 'Recommandé';

  @override
  String get on => 'Allumé';

  @override
  String get off => 'Éteint';

  @override
  String get installRemoveProviders =>
      'Installer ou supprimer des fournisseurs';

  @override
  String get resetDataSubtitle =>
      'Effacer les paramètres et la base de données, garder les plugins';

  @override
  String get factoryResetSubtitle =>
      'Supprimer toutes les données, paramètres et extensions';

  @override
  String get developerOptionsSubtitle => 'Outils de débogage et lecture locale';

  @override
  String get loading => 'Chargement...';

  @override
  String get sec => 'sec';

  @override
  String get min => 'min';

  @override
  String get internalPlayer => 'Interne (VLC)';

  @override
  String get builtInPlayer => 'Lecteur intégré';

  @override
  String get customNotSet => 'Personnalisé (non défini)';

  @override
  String selectGesture(String side) {
    return 'Geste $side';
  }

  @override
  String get left => 'Gauche';

  @override
  String get right => 'Droit';

  @override
  String get selectSeekDuration => 'Durée de saut';

  @override
  String get selectBufferDepth => 'Profondeur du tampon';

  @override
  String get subtitleSettings => 'Paramètres des sous-titres';

  @override
  String size(int size) {
    return 'Taille : $size';
  }

  @override
  String get background => 'Arrière-plan';

  @override
  String get customDohUrlLabel => 'URL DoH personnalisée';

  @override
  String get enterCustomDohUrl => 'Entrez votre URL DoH';

  @override
  String get chooseTheme => 'Choisir le thème';

  @override
  String get resetDataDialogTitle => 'Réinitialiser les données ?';

  @override
  String get resetDataDialogContent =>
      'Cela effacera les paramètres, les favoris et l\'historique. Vos extensions installées ne seront PAS supprimées.';

  @override
  String get factoryResetDialogTitle => 'Réinitialisation d\'usine ?';

  @override
  String get factoryResetDialogContent =>
      'Cela supprimera TOUT : favoris, historique, paramètres et TOUTES les extensions. Cette action est irréversible.';

  @override
  String get selectLanguage => 'Choisir la langue';

  @override
  String get synopsis => 'Synopsis';

  @override
  String get noDescription => 'Aucune description disponible.';

  @override
  String get videoAlreadyDownloadedPrompt =>
      'Cette vidéo est déjà téléchargée. Que souhaitez-vous faire ?';

  @override
  String get playNow => 'Lire maintenant';

  @override
  String get upNext => 'À suivre';

  @override
  String get deleteDownloadPrompt => 'Supprimer le téléchargement ?';

  @override
  String get deleteDownloadConfirmation =>
      'Êtes-vous sûr de vouloir supprimer ce fichier ? Cette action est irréversible.';

  @override
  String get no => 'Non';

  @override
  String get yesDelete => 'Oui, supprimer';

  @override
  String get downloadPaused => 'Téléchargement en pause';

  @override
  String get downloading => 'Téléchargement';

  @override
  String get speed => 'Vitesse';

  @override
  String get remaining => 'Restant';

  @override
  String get resume => 'Reprendre';

  @override
  String get pause => 'Pause';

  @override
  String get torrentContent => 'Contenu Torrent';

  @override
  String get audioTracks => 'Pistes Audio';

  @override
  String get noAudioTracks => 'Aucune piste audio trouvée';

  @override
  String get subtitles => 'Sous-titres';

  @override
  String get options => 'Options';

  @override
  String get noSubtitlesFound => 'Aucune piste de sous-titres trouvée';

  @override
  String get playbackSpeed => 'Vitesse de lecture';

  @override
  String get subtitleOptions => 'Options de sous-titres';

  @override
  String get hlsSubtitleWarning =>
      'Les fichiers de sous-titres externes ne sont pas supportés par le lecteur HLS actuel sur cette plateforme.';

  @override
  String get loadFromDevice => 'Charger depuis l\'appareil';

  @override
  String get syncDelay => 'Sync / Délai';

  @override
  String get styleSettings => 'Paramètres de style';

  @override
  String get searchOnline => 'Rechercher en ligne (Subtitle Search)';

  @override
  String get subtitleSync => 'Synchronisation des sous-titres';

  @override
  String get subtitleDelayWarning =>
      'Le délai de sous-titres n\'est pas supporté par le moteur de lecture actuel.';

  @override
  String get resetDelay => 'Réinitialiser le délai';

  @override
  String get subtitleStyles => 'Styles de sous-titres';

  @override
  String get resetToDefault => 'Réinitialiser';

  @override
  String get fontSize => 'Taille de police';

  @override
  String get verticalPosition => 'Position verticale';

  @override
  String get textColor => 'Couleur du texte';

  @override
  String get backgroundColor => 'Couleur d\'arrière-plan';

  @override
  String get backgroundOpacity => 'Opacité d\'arrière-plan';

  @override
  String get subtitleSearch => 'Recherche de sous-titres';

  @override
  String get searchSubtitleNameHint => 'Rechercher un nom de sous-titre...';

  @override
  String get enterSearchSubtitlePrompt =>
      'Entrez un nom pour trouver des sous-titres.';

  @override
  String get noSubtitleResults =>
      'Aucun résultat trouvé. Essayez une autre requête.';

  @override
  String get downloadingApplyingSubtitle =>
      'Téléchargement et application du sous-titre...';

  @override
  String get failedToDownloadSubtitle =>
      'Échec du téléchargement du sous-titre.';

  @override
  String get failedToLoadSubtitles =>
      'Échec du chargement des sous-titres. Veuillez réessayer.';

  @override
  String get noReposFound => 'Aucun dépôt ou plugin trouvé';

  @override
  String get downloadAllProviders => 'Télécharger tout';

  @override
  String get removeRepository => 'Supprimer le dépôt';

  @override
  String get addRepo => 'Ajouter un dépôt';

  @override
  String get extensionsNotInRepos => 'Extensions hors dépôts';

  @override
  String get noLongerInRepo => 'Ne figure plus dans aucun dépôt';

  @override
  String get addRepoToBrowse =>
      'Ajoutez un dépôt pour parcourir et mettre à jour les plugins';

  @override
  String get debugExtensions => 'Débogage des extensions';

  @override
  String removeRepoConfirm(String repoName) {
    return 'Supprimer $repoName ?';
  }

  @override
  String get removeRepoWarning =>
      'Cela supprimera le dépôt et désinstallera TOUS ses plugins.';

  @override
  String get addRepository => 'Ajouter un dépôt';

  @override
  String get repoUrlOrShortcode => 'URL du dépôt ou Code court';

  @override
  String get assetPlugin => 'Plugin d\'asset';

  @override
  String get installed => 'Installé';

  @override
  String get repositories => 'Dépôts';

  @override
  String get noExtensionsInstalled => 'Aucune extension installée';

  @override
  String get browseRepositoriesToInstall =>
      'Ouvrez l\'onglet Dépôts pour découvrir et installer des extensions.';

  @override
  String get browseRepositories => 'Parcourir les dépôts';

  @override
  String get addRepoDescription =>
      'Ajoutez l\'URL d\'un dépôt ou un code court pour découvrir et installer des plugins d\'extension.';

  @override
  String updateTo(String version) {
    return 'Mettre à jour vers $version';
  }

  @override
  String get install => 'Installer';

  @override
  String get error => 'Erreur';

  @override
  String get ok => 'OK';

  @override
  String pluginSettings(String pluginName) {
    return 'Paramètres de $pluginName';
  }

  @override
  String get movies => 'Films';

  @override
  String get series => 'Séries';

  @override
  String get anime => 'Animes';

  @override
  String get liveStreams => 'Flux en direct';

  @override
  String get debug => 'DÉBOGAGE';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count extensions mises à jour',
      one: '1 extension mise à jour',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation =>
      'Navigation invalide. Veuillez revenir en arrière.';

  @override
  String get startOver => 'Recommencer';

  @override
  String get goBack => 'Retour';

  @override
  String get resolving => 'Résolution...';

  @override
  String get downloaded => 'Téléchargé';

  @override
  String get download => 'Télécharger';

  @override
  String get debugOnlyFeature =>
      'Cette fonctionnalité n\'est disponible que dans les builds de débogage';

  @override
  String get streamUrl => 'URL du flux';

  @override
  String get play => 'Lire';

  @override
  String get verifyingSourceSize =>
      'Vérification de la source et de la taille...';

  @override
  String get fileSaveLocationNotification =>
      'Le fichier sera enregistré dans votre dossier Téléchargements.';

  @override
  String get resumingPlayback => 'Reprise de la lecture';

  @override
  String pausedAt(String time) {
    return 'En pause à $time';
  }

  @override
  String resumesAutomatically(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Reprise automatique dans $count secondes',
      one: 'Reprise automatique dans 1 seconde',
    );
    return '$_temp0';
  }

  @override
  String get resumeNow => 'Reprendre maintenant';

  @override
  String get playbackError => 'Erreur de lecture';

  @override
  String get confirmClearHistory =>
      'Êtes-vous sûr de vouloir supprimer tous les éléments de votre historique ?';

  @override
  String seasonWithNumber(Object number) {
    return 'Saison $number';
  }

  @override
  String get starting => 'Démarrage...';

  @override
  String percentWatched(int percent) {
    return '$percent% visionné';
  }

  @override
  String get sub => 'Sub';

  @override
  String get dub => 'Dub';

  @override
  String playEpisode(String label, Object season, Object episode) {
    return '$label S$season E$episode';
  }

  @override
  String playEpisodeOnly(String label, int episode) {
    return '$label E$episode';
  }

  @override
  String get debugTools => 'Outils de débogage';

  @override
  String get playLocalVideo => 'Lire un fichier vidéo local';

  @override
  String get playLocalVideoSubtitle => 'Lire une vidéo depuis l\'appareil';

  @override
  String get streamUrlSubtitle => 'Lire depuis une URL réseau';

  @override
  String get streamTorrent => 'Lire un torrent';

  @override
  String get streamTorrentSubtitle => 'Sélectionner un fichier torrent local';

  @override
  String get loadPluginFromAssets => 'Charger un plugin depuis les assets';

  @override
  String get enterVideoUrlHint =>
      'Entrez l\'URL de la vidéo (http, magnet, etc.)';

  @override
  String get networkStream => 'Flux Réseau';

  @override
  String removedFromHistory(String title) {
    return '$title supprimé de l\'historique';
  }

  @override
  String get custom => 'Personnalisé';

  @override
  String get refreshingLiveStream => 'Rafraîchissement du flux direct...';

  @override
  String get removeFromHistory => 'Supprimer de l\'historique';

  @override
  String get live => 'DIRECT';

  @override
  String get volume => 'Volume';

  @override
  String get brightness => 'Luminosité';

  @override
  String get fit => 'Adapter';

  @override
  String get zoom => 'Zoom';

  @override
  String get stretch => 'Étirer';

  @override
  String titleWithParam(String title) {
    return 'Titre : $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'Source : $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'Taille : $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'Erreur : $error. Utilisation du lecteur interne.';
  }

  @override
  String playerNotDetected(String playerName) {
    return '$playerName non détecté. Démarrage du lecteur interne.';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return 'Saison $number ($count Épisodes)';
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
    return 'Sélectionner une source pour $playerName';
  }

  @override
  String get noPluginsInstalled => 'Aucun plugin installé';

  @override
  String get noPluginsMessage =>
      'Installez des extensions pour parcourir et diffuser du contenu.';

  @override
  String get goToExtensions => 'Aller aux extensions';

  @override
  String get availableSources => 'Sources disponibles';

  @override
  String get seasons => 'Saisons';

  @override
  String get episodes => 'Épisodes';

  @override
  String get selectSourceToPlay =>
      'Veuillez sélectionner une source ci-dessus pour lire.';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Épisodes',
      one: '1 Épisode',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'Aucun épisode trouvé';

  @override
  String get local => 'Local';

  @override
  String get remote => 'Distant';

  @override
  String get torrent => 'Torrent';

  @override
  String get unlock => 'Déverrouiller';

  @override
  String get lock => 'Verrouiller';

  @override
  String get sources => 'Sources';

  @override
  String get tracks => 'Pistes';

  @override
  String get content => 'Contenu';

  @override
  String get stats => 'Stats';

  @override
  String get resize => 'Redimensionner';

  @override
  String get next => 'Suivant';

  @override
  String get pip => 'PiP';

  @override
  String get rotate => 'Pivoter';

  @override
  String get windowed => 'Fenêtré';

  @override
  String get fullscreen => 'Plein écran';

  @override
  String get movieDetails => 'Détails du Film';

  @override
  String get showDetails => 'Voir Détails';

  @override
  String get tagline => 'Slogan';

  @override
  String get status => 'Statut';

  @override
  String get releaseDate => 'Date de Sortie';

  @override
  String get firstAirDate => 'Première Diffusion';

  @override
  String get originalLanguage => 'Langue Originale';

  @override
  String get originCountry => 'Pays d\'Origine';

  @override
  String get budgetLabel => 'Budget';

  @override
  String get revenueLabel => 'Revenu';

  @override
  String get paused => 'En pause';

  @override
  String get watched => 'Vu';

  @override
  String get watching => 'En cours';

  @override
  String get lastWatched => 'Dernière lecture';

  @override
  String get movie => 'Film';

  @override
  String get tvShow => 'Série TV';

  @override
  String get failedToLoadContent => 'Échec du chargement du contenu';

  @override
  String get director => 'Réalisateur';

  @override
  String get creator => 'Créateur';

  @override
  String get showMore => 'Voir plus';

  @override
  String get showLess => 'Voir moins';

  @override
  String get viewAll => 'Tout voir';

  @override
  String seasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Saisons',
      one: '1 Saison',
    );
    return '$_temp0';
  }

  @override
  String get noInternetError => 'Pas de connexion Internet';

  @override
  String get timeoutError => 'Délai d\'attente dépassé. Veuillez réessayer.';

  @override
  String get serverError => 'Erreur serveur. Veuillez réessayer plus tard.';

  @override
  String get contentNotFoundError => 'Contenu introuvable.';

  @override
  String get accessDeniedError => 'Accès refusé. Vérifiez vos identifiants.';

  @override
  String get serviceUnavailableError =>
      'Serveur indisponible. Réessayez plus tard.';

  @override
  String get generalError =>
      'Quelque chose s\'est mal passé. Veuillez réessayer.';

  @override
  String get skip => 'Passer';

  @override
  String get skipIntro => 'Passer l\'intro';

  @override
  String get skipOutro => 'Passer le générique';

  @override
  String get skipRecap => 'Passer le résumé';

  @override
  String get goLive => 'Direct';

  @override
  String get dismiss => 'Fermer';

  @override
  String get nextUp => 'Suivant';

  @override
  String sourceAttempt(int index, int total) {
    return 'Source $index sur $total';
  }

  @override
  String get trying => 'Essai';

  @override
  String get failed => 'Échoué';

  @override
  String get selected => 'Sélectionné';

  @override
  String get playing => 'Lecture';

  @override
  String get pending => 'En attente';

  @override
  String get openSubtitles => 'OpenSubtitles';

  @override
  String get subDl => 'SubDL';

  @override
  String get subSource => 'SubSource';

  @override
  String get wifiQualityPreference => 'Préférence de qualité Wi-Fi';

  @override
  String get mobileQualityPreference => 'Préférence de qualité mobile';

  @override
  String get anyNoPreference => 'Toutes (pas de préférence)';

  @override
  String get subtitleAccounts => 'Comptes de sous-titres';

  @override
  String get accounts => 'Comptes';

  @override
  String get notLoggedIn => 'Pas connecté';

  @override
  String loggedInAs(String username) {
    return 'Connecté en tant que $username';
  }

  @override
  String get apiKeyConfigured => 'Clé API configurée';

  @override
  String get keyNotSet => 'Clé non définie';

  @override
  String get testConnection => 'Tester la connexion';

  @override
  String get connectedSuccessfully => 'Connecté avec succès';

  @override
  String get connectionFailed => 'La connexion a échoué';

  @override
  String get username => 'Nom d\'utilisateur';

  @override
  String get password => 'Mot de passe';

  @override
  String get noAccountRegister => 'Pas de compte ? S\'inscrire ici';

  @override
  String get apiKey => 'Clé API';

  @override
  String get email => 'E-mail';

  @override
  String get fetchMyApiKey => 'Récupérer ma clé API';

  @override
  String get keyVerified => 'Clé vérifiée';

  @override
  String get invalidApiKey => 'Clé API invalide';

  @override
  String get openSubtitlesAuthSubtitle =>
      'Entrez vos identifiants pour des limites plus élevées et des sous-titres sans publicité.';

  @override
  String get subDlAuthSubtitle =>
      'Entrez votre clé API SubDL directement ou récupérez-la via vos identifiants.';

  @override
  String get orFetchViaAccount => 'OU RÉCUPÉRER VIA LE COMPTE';

  @override
  String get subSourceAuthSubtitle =>
      'SubSource fonctionne par défaut, mais vous pouvez ajouter une clé API officielle pour plus de fiabilité.';

  @override
  String get apiKeyOptionalOverride => 'Clé API (Optionnelle)';

  @override
  String get enterKeyToOverrideDefault =>
      'Entrez la clé pour remplacer le défaut';

  @override
  String get getApiKeyFromProfile =>
      'Obtenez votre clé API depusi le profil SubSource';

  @override
  String get qualityNotGuaranteed =>
      'La qualité n\'est pas garantie. Les sources sont triées par préférence mais dépendent de l\'offre du fournisseur.';

  @override
  String get keepSourcesOriginalOrder => 'Garder l\'ordre original des sources';

  @override
  String get openLink => 'Ouvrir le lien';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get viewLogs => 'Voir les journaux';

  @override
  String get viewLogsSubtitle =>
      'Afficher l\'activité et les erreurs de l\'application';

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
