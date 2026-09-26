// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Azerbaijani (`az`).
class AppLocalizationsAz extends AppLocalizations {
  AppLocalizationsAz([String locale = 'az']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => 'Azərbaycan dili';

  @override
  String get addonHealthChecking => 'Checking add-on…';

  @override
  String addonHealthWorking(int ms) {
    return 'Working · $ms ms';
  }

  @override
  String get addonHealthUnavailable => 'Unavailable';

  @override
  String get home => 'Əsas səhifə';

  @override
  String get search => 'Axtarış';

  @override
  String get explore => 'Kəşf et';

  @override
  String get exploreAnime => 'Anime kəşf et';

  @override
  String get exploreMovies => 'Filmləri kəşf et';

  @override
  String get library => 'Kitabxana';

  @override
  String get settings => 'Parametrlər';

  @override
  String get extensions => 'Genişləndirmələr';

  @override
  String get updateAvailable => 'Yeniləmə mövcuddur';

  @override
  String get retry => 'Yenidən cəhd et';

  @override
  String get factoryReset => 'Zavod sıfırlaması';

  @override
  String get startupError => 'Başlanğıc xətası';

  @override
  String get general => 'Ümumi';

  @override
  String get appTheme => 'Tətbiq teması';

  @override
  String get recordWatchHistory => 'Baxış tarixçəsini yaz';

  @override
  String get fullScreenMode => 'Tam ekran';

  @override
  String get fullScreenModeSubtitle => 'TV görünüşünə keçir';

  @override
  String get defaultHomeScreen => 'Standart əsas ekran';

  @override
  String get titlePosition => 'Başlığın mövqeyi';

  @override
  String get titlePositionBelowPoster => 'Posterin altında';

  @override
  String get titlePositionInsidePoster => 'Posterin içində';

  @override
  String get player => 'Pleyer';

  @override
  String get defaultPlayer => 'Standart pleyer';

  @override
  String get leftGesture => 'Sol jest';

  @override
  String get rightGesture => 'Sağ jest';

  @override
  String get doubleTapToSeek => 'Sarımaq üçün iki dəfə toxun';

  @override
  String get swipeToSeek => 'Sarımaq üçün sürüşdür';

  @override
  String get seekDuration => 'Sarma müddəti';

  @override
  String get defaultResizeMode => 'Standart ölçü rejimi';

  @override
  String get hardwareDecoding => 'Aparat dekodlaşdırması';

  @override
  String get network => 'Şəbəkə';

  @override
  String get dnsOverHttps => 'HTTPS üzərindən DNS';

  @override
  String get dohProvider => 'DoH provayderi';

  @override
  String get githubProxy => 'GitHub proksisi';

  @override
  String get githubProxySubtitle =>
      'Provayder bloklarını keçmək üçün genişləndirmə endirmələrini jsDelivr üzərindən yönləndir.';

  @override
  String get manageExtensions => 'Genişləndirmələri idarə et';

  @override
  String get appData => 'Tətbiq məlumatları';

  @override
  String get resetDataKeepExtensions =>
      'Məlumatları sıfırla (genişləndirmələr qalsın)';

  @override
  String get developer => 'Tərtibatçı';

  @override
  String get developerOptions => 'Tərtibatçı seçimləri';

  @override
  String get about => 'Haqqında';

  @override
  String get version => 'Versiya';

  @override
  String get enabled => 'Aktivdir';

  @override
  String get disabled => 'Deaktiv';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'Serverimizə qoşul';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'Kanalımıza qoşul';

  @override
  String developedBy(String name) {
    return '$name tərəfindən hazırlanıb';
  }

  @override
  String get system => 'Sistem';

  @override
  String get dark => 'Tünd';

  @override
  String get light => 'Açıq';

  @override
  String get later => 'Sonra';

  @override
  String get updateNow => 'İndi yenilə';

  @override
  String get save => 'Yadda saxla';

  @override
  String get cancel => 'Ləğv et';

  @override
  String get close => 'Bağla';

  @override
  String get delete => 'Sil';

  @override
  String get viewDetails => 'Ətraflı bax';

  @override
  String get clearAll => 'Hamısını təmizlə';

  @override
  String get clearAllHistory => 'Bütün tarixçəni təmizlə';

  @override
  String get all => 'Hamısı';

  @override
  String get none => 'Yoxdur';

  @override
  String get confirmDownload => 'Endirməni təsdiqlə';

  @override
  String get downloadNow => 'İndi endir';

  @override
  String get selectSource => 'Mənbə seç';

  @override
  String get downloadUnavailable => 'Endirmə mümkün deyil';

  @override
  String get selectAnotherSource => 'Başqa mənbə seç';

  @override
  String get watchHistoryCleared => 'Baxış tarixçəsi təmizləndi';

  @override
  String get downloadingUpdate => 'Yeniləmə endirilir...';

  @override
  String errorPrefix(String message) {
    return 'Xəta: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'Yeniləmə mövcuddur: $tag';
  }

  @override
  String get selectProviderToStart => 'Baxmağa başlamaq üçün provayder seç';

  @override
  String get tapExtensionIcon => 'Küncdəki genişləndirmə ikonuna toxun';

  @override
  String get continueWatching => 'Baxışa davam et';

  @override
  String get noInternetConnection => 'İnternet əlaqəsi yoxdur';

  @override
  String get siteNotReachable => 'Sayt əlçatan deyil';

  @override
  String get checkConnectionOrDownloads =>
      'Əlaqəni yoxla və ya endirdiyin məzmuna bax.';

  @override
  String get tryVpnOrConnection =>
      'Zəhmət olmasa sayta VPN ilə daxil olmağa çalış və ya internet əlaqəni yoxla.';

  @override
  String errorDetails(String error) {
    return 'Xəta təfərrüatları: $error';
  }

  @override
  String get goToDownloads => 'Endirmələrə keç';

  @override
  String get selectProvider => 'Provayder seç';

  @override
  String get searchHint => 'Film, serial axtar...';

  @override
  String get searchFavoriteContent => 'Sevdiyin məzmunu axtar';

  @override
  String get pressSearchOrEnter =>
      'Başlamaq üçün Axtarış düyməsinə və ya Enter-ə bas';

  @override
  String get recentSearches => 'Recent searches';

  @override
  String removeFromSearchHistory(String query) {
    return 'Remove $query from search history';
  }

  @override
  String get noResultsFound => 'Nəticə tapılmadı.';

  @override
  String get couldNotLoadTrending => 'Trend elementlər yüklənmədi';

  @override
  String get popularMovies => 'Populyar filmlər';

  @override
  String get popularTVShows => 'Populyar seriallar';

  @override
  String get newMovies => 'Yeni filmlər';

  @override
  String get newTVShows => 'Yeni seriallar';

  @override
  String get featuredMovies => 'Seçilmiş filmlər';

  @override
  String get featuredTVShows => 'Seçilmiş seriallar';

  @override
  String get lastVideosTVShows => 'Serialların son videoları';

  @override
  String get downloads => 'Endirmələr';

  @override
  String get bookmarks => 'Əlfəcinlər';

  @override
  String get noDownloadsYet => 'Hələ endirmə yoxdur';

  @override
  String episodesCount(int count, int done) {
    return '$count epizod • $done hazır';
  }

  @override
  String get deleteAllEpisodes => 'Bütün epizodları sil';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return '\"$title\" serialının bütün $count epizodunu və onların fayllarını silmək istədiyinə əminsən?';
  }

  @override
  String get deleteAll => 'Hamısını sil';

  @override
  String get completed => 'Tamamlandı';

  @override
  String get statusQueued => 'Növbədə...';

  @override
  String get statusDownloading => 'Endirilir...';

  @override
  String get statusFinished => 'Bitdi';

  @override
  String get statusFailed => 'Uğursuz';

  @override
  String get statusCanceled => 'Ləğv edildi';

  @override
  String get statusPaused => 'Dayandırıldı';

  @override
  String get statusWaiting => 'Gözlənilir...';

  @override
  String get fileNotFoundRemoving => 'Fayl diskdə tapılmadı. Qeyd silinir.';

  @override
  String get fileNotFound => 'Fayl tapılmadı';

  @override
  String get deleteDownload => 'Endirməni sil';

  @override
  String get confirmDeleteDownload =>
      'Bu endirməni və onun faylını silmək istədiyinə əminsən?';

  @override
  String get libraryEmpty => 'Kitabxanan boşdur';

  @override
  String get language => 'Dil';

  @override
  String get english => 'İngilis dili';

  @override
  String get hindi => 'Hind dili (हिंदी)';

  @override
  String get kannada => 'Kannada dili (ಕನ್ನಡ)';

  @override
  String get unknown => 'Naməlum';

  @override
  String get recommended => 'Tövsiyə olunur';

  @override
  String get on => 'Açıq';

  @override
  String get off => 'Bağlı';

  @override
  String get installRemoveProviders => 'Provayderləri quraşdır və ya çıxar';

  @override
  String get resetDataSubtitle =>
      'Parametrləri və verilənlər bazasını təmizlə, plagini saxla';

  @override
  String get factoryResetSubtitle =>
      'Bütün məlumatları, parametrləri və genişləndirmələri sil';

  @override
  String get developerOptionsSubtitle => 'Sazlama alətləri və lokal oynatma';

  @override
  String get loading => 'Yüklənir...';

  @override
  String get sec => 'san';

  @override
  String get min => 'dəq';

  @override
  String playerRewindSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saniyə geri sar',
      one: '1 saniyə geri sar',
    );
    return '$_temp0';
  }

  @override
  String playerForwardSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saniyə irəli sar',
      one: '1 saniyə irəli sar',
    );
    return '$_temp0';
  }

  @override
  String get internalPlayer => 'Daxili (VLC)';

  @override
  String get builtInPlayer => 'Daxili pleyer';

  @override
  String get customNotSet => 'Fərdi (təyin edilməyib)';

  @override
  String selectGesture(String side) {
    return '$side jesti seç';
  }

  @override
  String get left => 'Sol';

  @override
  String get right => 'Sağ';

  @override
  String get selectSeekDuration => 'Sarma müddətini seç';

  @override
  String get subtitleSettings => 'Altyazı parametrləri';

  @override
  String size(int size) {
    return 'Ölçü: $size';
  }

  @override
  String get background => 'Fon';

  @override
  String get customDohUrlLabel => 'Fərdi DoH URL-i';

  @override
  String get enterCustomDohUrl => 'Öz DoH URL-ini daxil et';

  @override
  String get chooseTheme => 'Tema seç';

  @override
  String get resetDataDialogTitle => 'Məlumatlar sıfırlansın?';

  @override
  String get resetDataDialogContent =>
      'Bu, parametrləri, sevimliləri və tarixçəni təmizləyəcək. Quraşdırdığın genişləndirmələr SİLİNMƏYƏCƏK.';

  @override
  String get factoryResetDialogTitle => 'Zavod sıfırlaması?';

  @override
  String get factoryResetDialogContent =>
      'Bu, HƏR ŞEYİ siləcək: sevimlilər, tarixçə, parametrlər və BÜTÜN genişləndirmələr. Bunu geri qaytarmaq olmaz.';

  @override
  String get selectLanguage => 'Dil seç';

  @override
  String get synopsis => 'Qısa məzmun';

  @override
  String get noDescription => 'Təsvir yoxdur.';

  @override
  String get videoAlreadyDownloadedPrompt =>
      'Bu video artıq endirilib. Nə etmək istəyirsən?';

  @override
  String get playNow => 'İndi oynat';

  @override
  String get upNext => 'Növbəti';

  @override
  String get deleteDownloadPrompt => 'Endirmə silinsin?';

  @override
  String get deleteDownloadConfirmation =>
      'Bu faylı silmək istədiyinə əminsən? Bunu geri qaytarmaq olmaz.';

  @override
  String get no => 'Xeyr';

  @override
  String get yesDelete => 'Bəli, sil';

  @override
  String get downloadPaused => 'Endirmə dayandırıldı';

  @override
  String get downloading => 'Endirilir';

  @override
  String get speed => 'Sürət';

  @override
  String get remaining => 'Qalıb';

  @override
  String get resume => 'Davam et';

  @override
  String get pause => 'Fasilə';

  @override
  String get torrentContent => 'Torrent məzmunu';

  @override
  String get audioTracks => 'Audio treklər';

  @override
  String get noAudioTracks => 'Audio trek tapılmadı';

  @override
  String get subtitles => 'Altyazılar';

  @override
  String get options => 'Seçimlər';

  @override
  String get noSubtitlesFound => 'Altyazı treki tapılmadı';

  @override
  String get playbackSpeed => 'Oxutma sürəti';

  @override
  String get subtitleOptions => 'Altyazı seçimləri';

  @override
  String get hlsSubtitleWarning =>
      'Bu platformada aktiv HLS pleyeri xarici altyazı fayllarını dəstəkləmir.';

  @override
  String get loadFromDevice => 'Cihazdan yüklə';

  @override
  String get syncDelay => 'Sinxronlaşdırma / gecikmə';

  @override
  String get styleSettings => 'Üslub parametrləri';

  @override
  String get searchOnline => 'Onlayn axtar (altyazı axtarışı)';

  @override
  String get subtitleSync => 'Altyazı sinxronlaşdırması';

  @override
  String get subtitleDelayWarning =>
      'Aktiv oxutma mühərriki altyazı gecikməsini dəstəkləmir.';

  @override
  String get resetDelay => 'Gecikməni sıfırla';

  @override
  String get subtitleStyles => 'Altyazı üslubları';

  @override
  String get resetToDefault => 'Standarta qaytar';

  @override
  String get fontSize => 'Şrift ölçüsü';

  @override
  String get verticalPosition => 'Şaquli mövqe';

  @override
  String get textColor => 'Mətn rəngi';

  @override
  String get backgroundColor => 'Fon rəngi';

  @override
  String get backgroundOpacity => 'Fon şəffaflığı';

  @override
  String get subtitleSearch => 'Altyazı axtarışı';

  @override
  String get searchSubtitleNameHint => 'Altyazı adını axtar...';

  @override
  String get enterSearchSubtitlePrompt =>
      'Altyazı tapmaq üçün ad daxil et və ya axtar.';

  @override
  String get noSubtitleResults => 'Nəticə tapılmadı. Başqa sorğu yoxla.';

  @override
  String get downloadingApplyingSubtitle =>
      'Altyazı endirilir və tətbiq edilir...';

  @override
  String get failedToDownloadSubtitle => 'Altyazı endirilmədi.';

  @override
  String get failedToLoadSubtitles =>
      'Altyazılar yüklənmədi. Zəhmət olmasa yenidən cəhd et.';

  @override
  String get noReposFound => 'Repozitoriya və ya plagin tapılmadı';

  @override
  String get downloadAllProviders => 'Hamısını endir';

  @override
  String get removeRepository => 'Repozitoriyanı çıxar';

  @override
  String get addRepo => 'Repo əlavə et';

  @override
  String get extensionsNotInRepos =>
      'Repozitoriyalarda olmayan genişləndirmələr';

  @override
  String get noLongerInRepo => 'Artıq heç bir repozitoriyada göstərilmir';

  @override
  String get addRepoToBrowse =>
      'Plaginlərə baxmaq və onları yeniləmək üçün repozitoriya əlavə et';

  @override
  String get debugExtensions => 'Genişləndirmələri sazla';

  @override
  String removeRepoConfirm(String repoName) {
    return '$repoName çıxarılsın?';
  }

  @override
  String get removeRepoWarning =>
      'Bu, repozitoriyanı çıxaracaq və onun BÜTÜN plaginlərini siləcək.';

  @override
  String get addRepository => 'Repozitoriya əlavə et';

  @override
  String get repoUrlOrShortcode => 'Repozitoriya URL-i və ya qısa kodu';

  @override
  String get assetPlugin => 'Asset plagini';

  @override
  String get installed => 'Quraşdırılıb';

  @override
  String get repositories => 'Repozitoriyalar';

  @override
  String get noExtensionsInstalled => 'Quraşdırılmış genişləndirmə yoxdur';

  @override
  String get browseRepositoriesToInstall =>
      'Genişləndirmələri tapmaq və quraşdırmaq üçün Repozitoriyalar bölməsinə bax.';

  @override
  String get browseRepositories => 'Repozitoriyalara bax';

  @override
  String get addRepoDescription =>
      'Genişləndirmə plaginlərini tapmaq və quraşdırmaq üçün repozitoriya URL-i və ya qısa kodu əlavə et.';

  @override
  String updateTo(String version) {
    return '$version versiyasına yenilə';
  }

  @override
  String get install => 'Quraşdır';

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
  String get error => 'Xəta';

  @override
  String get ok => 'OK';

  @override
  String pluginSettings(String pluginName) {
    return '$pluginName parametrləri';
  }

  @override
  String get movies => 'Filmlər';

  @override
  String get series => 'Seriallar';

  @override
  String get anime => 'Anime';

  @override
  String get liveStreams => 'Canlı yayımlar';

  @override
  String get debug => 'SAZLAMA';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count genişləndirmə yeniləndi',
      one: '1 genişləndirmə yeniləndi',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation =>
      'Naviqasiya yanlışdır. Zəhmət olmasa geri qayıt.';

  @override
  String get startOver => 'Yenidən başla';

  @override
  String get goBack => 'Geri qayıt';

  @override
  String get restartApp => 'Tətbiqi yenidən başlat';

  @override
  String get resolving => 'Həll edilir...';

  @override
  String get downloaded => 'Endirilib';

  @override
  String get download => 'Endir';

  @override
  String get debugOnlyFeature =>
      'Bu funksiya yalnız sazlama buildlərində mövcuddur';

  @override
  String get streamUrl => 'Yayım URL-i';

  @override
  String get play => 'Oynat';

  @override
  String get verifyingSourceSize => 'Mənbə və ölçü yoxlanılır...';

  @override
  String get fileSaveLocationNotification =>
      'Fayl Endirmələr qovluğunda saxlanılacaq.';

  @override
  String get resumingPlayback => 'Oxutma davam etdirilir';

  @override
  String pausedAt(String time) {
    return '$time vaxtında dayandırılıb';
  }

  @override
  String resumesAutomatically(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saniyə sonra avtomatik davam edəcək',
      one: '1 saniyə sonra avtomatik davam edəcək',
    );
    return '$_temp0';
  }

  @override
  String get resumeNow => 'İndi davam et';

  @override
  String get playbackError => 'Oxutma xətası';

  @override
  String get confirmClearHistory =>
      'Baxış tarixçəndəki bütün elementləri silmək istədiyinə əminsən?';

  @override
  String seasonWithNumber(Object number) {
    return 'Mövsüm $number';
  }

  @override
  String get starting => 'Başlayır...';

  @override
  String percentWatched(int percent) {
    return '$percent% baxılıb';
  }

  @override
  String get sub => 'Altyazılı';

  @override
  String get dub => 'Dublyajlı';

  @override
  String playEpisode(String label, Object season, Object episode) {
    return '$label S$season E$episode';
  }

  @override
  String playEpisodeOnly(String label, int episode) {
    return '$label E$episode';
  }

  @override
  String get debugTools => 'Sazlama alətləri';

  @override
  String get playLocalVideo => 'Lokal video faylını oynat';

  @override
  String get playLocalVideoSubtitle => 'Cihazdakı istənilən videonu oynat';

  @override
  String get streamUrlSubtitle => 'Şəbəkə URL-indən oynat';

  @override
  String get streamTorrent => 'Torrenti yayımla';

  @override
  String get streamTorrentSubtitle => 'Oynatmaq üçün lokal torrent faylı seç';

  @override
  String get loadPluginFromAssets => 'Plagini asset-lərdən yüklə';

  @override
  String get enterVideoUrlHint => 'Video URL-ini daxil et (http, magnet və s.)';

  @override
  String get networkStream => 'Şəbəkə yayımı';

  @override
  String removedFromHistory(String title) {
    return '$title tarixçədən çıxarıldı';
  }

  @override
  String get custom => 'Fərdi';

  @override
  String get refreshingLiveStream => 'Canlı yayım yenilənir...';

  @override
  String get removeFromHistory => 'Tarixçədən çıxar';

  @override
  String get live => 'CANLI';

  @override
  String get volume => 'Səs';

  @override
  String get decrease => 'Decrease';

  @override
  String get increase => 'Increase';

  @override
  String get brightness => 'Parlaqlıq';

  @override
  String get fit => 'Sığdır';

  @override
  String get zoom => 'Yaxınlaşdır';

  @override
  String get stretch => 'Uzat';

  @override
  String titleWithParam(String title) {
    return 'Başlıq: $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'Mənbə: $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'Ölçü: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'Xəta: $error. Daxili pleyer işlədilir.';
  }

  @override
  String externalPlayerCannotSendHeaders(String playerName, String headers) {
    return '$playerName cannot send $headers. Using internal player.';
  }

  @override
  String playerNotDetected(String playerName) {
    return '$playerName tapılmadı. Daxili pleyer başladılır.';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return 'Mövsüm $number ($count epizod)';
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
    return '$playerName üçün mənbə seç';
  }

  @override
  String get noPluginsInstalled => 'Quraşdırılmış plagin yoxdur';

  @override
  String get noPluginsMessage =>
      'Məzmuna baxmaq və onu yayımlamaq üçün genişləndirmə quraşdır.';

  @override
  String get goToExtensions => 'Genişləndirmələrə keç';

  @override
  String get availableSources => 'Mövcud mənbələr';

  @override
  String get seasons => 'Mövsümlər';

  @override
  String get episodes => 'Epizodlar';

  @override
  String get selectSourceToPlay =>
      'Oynatmaq üçün yuxarıdakı \'Mövcud mənbələr\' bölməsindən mənbə seç.';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count epizod',
      one: '1 epizod',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'Epizod tapılmadı';

  @override
  String get local => 'Lokal';

  @override
  String get remote => 'Uzaq';

  @override
  String get torrent => 'Torrent';

  @override
  String get unlock => 'Kilidi aç';

  @override
  String get lock => 'Kilidlə';

  @override
  String get sources => 'Mənbələr';

  @override
  String get tracks => 'Treklər';

  @override
  String get content => 'Məzmun';

  @override
  String get stats => 'Statistika';

  @override
  String get resize => 'Ölçünü dəyiş';

  @override
  String get next => 'Növbəti';

  @override
  String get previous => 'Previous';

  @override
  String get pip => 'PiP';

  @override
  String get rotate => 'Döndər';

  @override
  String get windowed => 'Pəncərədə';

  @override
  String get fullscreen => 'Tam ekran';

  @override
  String get movieDetails => 'Film təfərrüatları';

  @override
  String get showDetails => 'Serial təfərrüatları';

  @override
  String get tagline => 'Şüar';

  @override
  String get status => 'Vəziyyət';

  @override
  String get releaseDate => 'Buraxılış tarixi';

  @override
  String get firstAirDate => 'İlk yayım tarixi';

  @override
  String get originalLanguage => 'Orijinal dil';

  @override
  String get originCountry => 'Mənşə ölkəsi';

  @override
  String get budgetLabel => 'Büdcə';

  @override
  String get revenueLabel => 'Gəlir';

  @override
  String get paused => 'Dayandırılıb';

  @override
  String get watched => 'Baxılıb';

  @override
  String get watching => 'Baxılır';

  @override
  String get lastWatched => 'Son baxılan';

  @override
  String get movie => 'Film';

  @override
  String get tvShow => 'Serial';

  @override
  String get failedToLoadContent => 'Məzmun yüklənmədi';

  @override
  String get director => 'Rejissor';

  @override
  String get creator => 'Yaradan';

  @override
  String get showMore => 'Daha çox göstər';

  @override
  String get showLess => 'Daha az göstər';

  @override
  String get viewAll => 'Hamısına bax';

  @override
  String seasonsCount(int count) {
    return '$count mövsüm';
  }

  @override
  String get noInternetError => 'İnternet əlaqəsi yoxdur';

  @override
  String get timeoutError =>
      'Sorğunun vaxtı bitdi. Zəhmət olmasa yenidən cəhd et.';

  @override
  String get serverError =>
      'Server xətası. Zəhmət olmasa bir az sonra yenidən cəhd et.';

  @override
  String get contentNotFoundError => 'Məzmun tapılmadı.';

  @override
  String get accessDeniedError =>
      'Giriş rədd edildi. Hesab məlumatlarını yoxla.';

  @override
  String get serviceUnavailableError =>
      'Server əlçatan deyil. Bir az sonra yenidən cəhd et.';

  @override
  String get generalError => 'Nəsə səhv getdi. Zəhmət olmasa yenidən cəhd et.';

  @override
  String get skip => 'Keç';

  @override
  String get skipIntro => 'İntronu keç';

  @override
  String get skipOutro => 'Sonluğu keç';

  @override
  String get skipRecap => 'Xülasəni keç';

  @override
  String get goLive => 'Canlıya keç';

  @override
  String get dismiss => 'Gizlət';

  @override
  String get nextUp => 'Sıradakı';

  @override
  String sourceAttempt(int index, int total) {
    return 'Mənbə $index/$total';
  }

  @override
  String get trying => 'Yoxlanılır';

  @override
  String get failed => 'Uğursuz';

  @override
  String get selected => 'Seçildi';

  @override
  String get playing => 'Oynadılır';

  @override
  String get pending => 'Gözləyir';

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
  String get mobileQualityPreference => 'Mobil keyfiyyət tərcihi';

  @override
  String get anyNoPreference => 'İstənilən (tərcih yoxdur)';

  @override
  String get subtitleAccounts => 'Altyazı hesabları';

  @override
  String get accounts => 'Hesablar';

  @override
  String get notLoggedIn => 'Daxil olunmayıb';

  @override
  String loggedInAs(String username) {
    return '$username kimi daxil olunub';
  }

  @override
  String get apiKeyConfigured => 'API açarı konfiqurasiya edilib';

  @override
  String get keyNotSet => 'Açar təyin edilməyib';

  @override
  String get testConnection => 'Əlaqəni yoxla';

  @override
  String get connectedSuccessfully => 'Uğurla qoşuldu';

  @override
  String get connectionFailed => 'Əlaqə alınmadı';

  @override
  String get username => 'İstifadəçi adı';

  @override
  String get password => 'Parol';

  @override
  String get noAccountRegister => 'Hesabın yoxdur? Buradan qeydiyyatdan keç';

  @override
  String get apiKey => 'API açarı';

  @override
  String get email => 'E-poçt';

  @override
  String get fetchMyApiKey => 'API açarımı gətir';

  @override
  String get keyVerified => 'Açar təsdiqləndi';

  @override
  String get invalidApiKey => 'API açarı yanlışdır';

  @override
  String get openSubtitlesAuthSubtitle =>
      'Daha yüksək limitlər və reklamsız altyazılar üçün hesab məlumatlarını daxil et.';

  @override
  String get subDlAuthSubtitle =>
      'SubDL API açarını birbaşa daxil et və ya aşağıdakı hesab məlumatları ilə onu gətir.';

  @override
  String get orFetchViaAccount => 'VƏ YA HESAB VASİTƏSİLƏ GƏTİR';

  @override
  String get subSourceAuthSubtitle =>
      'SubSource əlavə quraşdırma olmadan işləyir, lakin daha etibarlı olsun deyə standartı əvəz edən şəxsi rəsmi API açarı əlavə edə bilərsən.';

  @override
  String get apiKeyOptionalOverride => 'API açarı (istəyə bağlı əvəzləmə)';

  @override
  String get enterKeyToOverrideDefault =>
      'Standartı əvəz etmək üçün açar daxil et';

  @override
  String get getApiKeyFromProfile => 'API açarını SubSource profilindən götür';

  @override
  String get qualityNotGuaranteed =>
      'Keyfiyyətə zəmanət verilmir. Mənbələr tərcihə görə sıralanır, lakin oxutma provayderin həqiqətən təklif etdiyindən asılıdır.';

  @override
  String get keepSourcesOriginalOrder => 'Mənbələri orijinal sırada saxla';

  @override
  String get openLink => 'Keçidi aç';

  @override
  String get diagnostics => 'Diaqnostika';

  @override
  String get viewLogs => 'Loglara bax';

  @override
  String get viewLogsSubtitle => 'Tətbiqin fəaliyyətinə və xətalarına bax';

  @override
  String get clearCache => 'Şəkil və video keşini təmizlə';

  @override
  String get clearCacheSubtitle =>
      'Keşlənmiş şəkil və videoların tutduğu yaddaşı boşaldır';

  @override
  String get clearCacheDialogTitle => 'Keş təmizlənsin?';

  @override
  String get clearCacheDialogContent =>
      'Bu, keşlənmiş şəkil və video fayllarını siləcək. Parametrlərinə, tarixçənə və genişləndirmələrinə toxunulmayacaq.';

  @override
  String get clearCacheNow => 'Keşi təmizlə';

  @override
  String get cacheCleared => 'Keş təmizləndi';

  @override
  String get calculating => 'Hesablanır…';

  @override
  String get playerControls => 'Pleyer düymələri';

  @override
  String get playerControlsSubtitle =>
      'Pleyerin idarə düymələrini göstər və ya gizlət';

  @override
  String get showPip => 'Şəkil içində şəkil düyməsi';

  @override
  String get showResize => 'Ölçü düyməsi';

  @override
  String get showPlaybackSpeed => 'Oxutma sürəti düyməsi';

  @override
  String get showEpisodes => 'Epizodlar düyməsi';

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
  String get playerSourceReachable => 'Əlçatan';

  @override
  String get playerReasonStreamEndedBeforePlaying =>
      'stream ended before it played';

  @override
  String playerFinished(String title) {
    return '$title sona çatdı';
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
    return 'Treklər oxunmadı: $error';
  }

  @override
  String playerTrackNumber(int id) {
    return 'Trek $id';
  }

  @override
  String get subtitleDelay => 'Altyazı gecikməsi';

  @override
  String get playerSourceRestoredPrevious =>
      'That source would not play. Restored the previous one.';

  @override
  String get playerTorrentFileNotReady =>
      'That file is not ready to stream yet.';

  @override
  String get torrentFiles => 'Torrent faylları';

  @override
  String get audio => 'Audio';

  @override
  String get noAudioTracksReported => 'Audio trek bildirilmədi';

  @override
  String get loadSubtitleFile => 'Altyazı faylını yüklə';

  @override
  String get searchSubtitlesOnline => 'Onlayn axtar';

  @override
  String get searchOnlineSubtitles => 'Onlayn altyazı axtar';

  @override
  String get subtitleLanguage => 'Altyazı dili';

  @override
  String get subtitleDownloadFailed =>
      'Həmin altyazı endirilmədi. Başqa nəticəni yoxla.';

  @override
  String subtitleSearchFailed(String error) {
    return 'Axtarış alınmadı: $error';
  }

  @override
  String get subtitleSearchPrompt => 'Altyazı tapmaq üçün başlıq axtar.';

  @override
  String get noSubtitlesFoundTryAnother =>
      'Altyazı tapılmadı. Başqa başlıq və ya dil yoxla.';

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
  String get playerNowPlaying => 'İndi oynadılır';

  @override
  String get playerQualityFilterDropped =>
      'Keyfiyyət tərcihinə uyğun gələn olmadı, ona görə bütün mənbələr göstərilir.';

  @override
  String playerSeeders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sid',
      one: '1 sid',
    );
    return '$_temp0';
  }

  @override
  String get playerFiles => 'Fayllar';

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
    return '$count dəq';
  }

  @override
  String get audioDelay => 'Audio gecikməsi';

  @override
  String get subtitleSearchTitleFallback =>
      'Bu başlığın ID-sinə uyğun heç nə tapılmadı. Əvəzində başlığa uyğun nəticələr göstərilir.';

  @override
  String get subtitleSearchSeasonFallback =>
      'Bu epizod üçün altyazı yoxdur. Bunlar bütün mövsümə aiddir, ona görə fayl adındakı epizod nömrəsini yoxla.';

  @override
  String get sourcesSearching => 'Skreperlər axtarılır…';

  @override
  String get sourcesEmptyFiltered => 'Cari filtrlərə uyğun keçid yoxdur.';

  @override
  String get sourcesEmptyNoTmdbId =>
      'Bu başlıq üçün TMDB ID yoxdur. Daxil etmək üçün \'Search manually\' istifadə edin.';

  @override
  String get sourcesEmptyNoScrapers =>
      'Aktiv skreper yoxdur. \'Nuvio Plugins\' bölməsində əlavə edin.';

  @override
  String get sourcesEmptyAllFailed =>
      'Bütün skreperlər uğursuz oldu. Bağlantınızı yoxlayın və ya skreperləri yeniləyin.';

  @override
  String sourcesEmptySomeFailed(int failed, int total) {
    return 'Keçid tapılmadı. $total skreperdən $failed uğursuz oldu.';
  }

  @override
  String get sourcesEmptyNothingFound =>
      'Skreperlərinizin heç birində bu başlıq yoxdur.';

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
