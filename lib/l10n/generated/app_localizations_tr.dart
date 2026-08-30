// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => 'Türkçe';

  @override
  String get home => 'Ana Sayfa';

  @override
  String get search => 'Ara';

  @override
  String get explore => 'Keşfet';

  @override
  String get exploreAnime => 'Anime keşfet';

  @override
  String get exploreMovies => 'Film keşfet';

  @override
  String get library => 'Kütüphane';

  @override
  String get settings => 'Ayarlar';

  @override
  String get extensions => 'Eklentiler';

  @override
  String get updateAvailable => 'Güncelleme Mevcut';

  @override
  String get retry => 'Yeniden Dene';

  @override
  String get factoryReset => 'Fabrika Ayarlarına Sıfırla';

  @override
  String get startupError => 'Başlatma Hatası';

  @override
  String get general => 'Genel';

  @override
  String get appTheme => 'Uygulama Teması';

  @override
  String get recordWatchHistory => 'İzleme Geçmişini Kaydet';

  @override
  String get defaultHomeScreen => 'Varsayılan Ana Ekran';

  @override
  String get titlePosition => 'Başlık konumu';

  @override
  String get titlePositionBelowPoster => 'Afişin altında';

  @override
  String get titlePositionInsidePoster => 'Afişin içinde';

  @override
  String get player => 'Oynatıcı';

  @override
  String get defaultPlayer => 'Varsayılan Oynatıcı';

  @override
  String get leftGesture => 'Sol Hareket';

  @override
  String get rightGesture => 'Sağ Hareket';

  @override
  String get doubleTapToSeek => 'İleri/Geri Sarmak İçin Çift Tıkla';

  @override
  String get swipeToSeek => 'İleri/Geri Sarmak İçin Kaydır';

  @override
  String get seekDuration => 'Atlama Süresi';

  @override
  String get bufferDepth => 'Tampon Derinliği';

  @override
  String get defaultResizeMode => 'Varsayılan Boyutlandırma Modu';

  @override
  String get hardwareDecoding => 'Donanım Dekoderi';

  @override
  String get network => 'Ağ';

  @override
  String get dnsOverHttps => 'HTTPS üzerinden DNS (DoH)';

  @override
  String get dohProvider => 'DoH Sağlayıcısı';

  @override
  String get githubProxy => 'GitHub vekil sunucusu';

  @override
  String get githubProxySubtitle =>
      'Servis sağlayıcı engellerini aşmak için eklenti indirmelerini jsDelivr üzerinden yönlendir.';

  @override
  String get manageExtensions => 'Eklentileri Yönet';

  @override
  String get appData => 'Uygulama Verileri';

  @override
  String get resetDataKeepExtensions => 'Verileri Sıfırla (Eklentileri Koru)';

  @override
  String get developer => 'Geliştirici';

  @override
  String get developerOptions => 'Geliştirici Seçenekleri';

  @override
  String get about => 'Hakkında';

  @override
  String get version => 'Sürüm';

  @override
  String get enabled => 'Etkin';

  @override
  String get disabled => 'Devre Dışı';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'Sunucumuza katılın';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'Kanalımıza katılın';

  @override
  String developedBy(String name) {
    return '$name tarafından geliştirildi';
  }

  @override
  String get system => 'Sistem';

  @override
  String get dark => 'Karanlık';

  @override
  String get light => 'Aydınlık';

  @override
  String get later => 'Sonra';

  @override
  String get updateNow => 'Şimdi Güncelle';

  @override
  String get save => 'Kaydet';

  @override
  String get cancel => 'İptal';

  @override
  String get close => 'Kapat';

  @override
  String get delete => 'Sil';

  @override
  String get viewDetails => 'Detayları Görüntüle';

  @override
  String get clearAll => 'Tümünü Temizle';

  @override
  String get clearAllHistory => 'Geçmişi Temizle';

  @override
  String get all => 'Tümü';

  @override
  String get none => 'Hiçbiri';

  @override
  String get confirmDownload => 'İndirmeyi Onayla';

  @override
  String get downloadNow => 'Şimdi İndir';

  @override
  String get selectSource => 'Kaynak Seç';

  @override
  String get downloadUnavailable => 'İndirme Mevcut Değil';

  @override
  String get selectAnotherSource => 'Başka Bir Kaynak Seç';

  @override
  String get watchHistoryCleared => 'İzleme geçmişi temizlendi';

  @override
  String get downloadingUpdate => 'Güncelleme indiriliyor...';

  @override
  String errorPrefix(String message) {
    return 'Hata: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'Güncelleme Mevcut: $tag';
  }

  @override
  String get selectProviderToStart =>
      'İzlemeye başlamak için bir sağlayıcı seçin';

  @override
  String get tapExtensionIcon => 'Köşedeki eklenti simgesine dokunun';

  @override
  String get continueWatching => 'İzlemeye Devam Et';

  @override
  String get noInternetConnection => 'İnternet Bağlantısı Yok';

  @override
  String get siteNotReachable => 'Siteye Erişilemiyor';

  @override
  String get checkConnectionOrDownloads =>
      'Bağlantınızı kontrol edin veya indirilen içeriklerinizi görüntüleyin.';

  @override
  String get tryVpnOrConnection =>
      'Lütfen siteye VPN ile erişmeyi deneyin veya internet bağlantınızı kontrol edin.';

  @override
  String errorDetails(String error) {
    return 'Hata Detayları: $error';
  }

  @override
  String get goToDownloads => 'İndirilenlere Git';

  @override
  String get selectProvider => 'Sağlayıcı Seç';

  @override
  String get searchHint => 'Film, dizi ara...';

  @override
  String get searchFavoriteContent => 'Favori içeriğinizi arayın';

  @override
  String get pressSearchOrEnter =>
      'Başlamak için Ara tuşuna veya Enter\'a basın';

  @override
  String get noResultsFound => 'Sonuç bulunamadı.';

  @override
  String get couldNotLoadTrending => 'Trend olanlar yüklenemedi';

  @override
  String get popularMovies => 'Popüler Filmler';

  @override
  String get popularTVShows => 'Popüler Diziler';

  @override
  String get newMovies => 'Yeni Filmler';

  @override
  String get newTVShows => 'Yeni Diziler';

  @override
  String get featuredMovies => 'Öne Çıkan Filmler';

  @override
  String get featuredTVShows => 'Öne Çıkan Diziler';

  @override
  String get lastVideosTVShows => 'Son Diziler';

  @override
  String get downloads => 'İndirilenler';

  @override
  String get bookmarks => 'Yer İmleri';

  @override
  String get noDownloadsYet => 'Henüz indirme yok';

  @override
  String episodesCount(int count, int done) {
    return '$count Bölüm • $done Tamamlandı';
  }

  @override
  String get deleteAllEpisodes => 'Tüm Bölümleri Sil';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return '\"$title\" dizisinin tüm $count bölümünü ve dosyalarını silmek istediğinizden emin misiniz?';
  }

  @override
  String get deleteAll => 'Tümünü Sil';

  @override
  String get completed => 'Tamamlandı';

  @override
  String get statusQueued => 'Sırada...';

  @override
  String get statusDownloading => 'İndiriliyor...';

  @override
  String get statusFinished => 'Bitti';

  @override
  String get statusFailed => 'Başarısız';

  @override
  String get statusCanceled => 'İptal Edildi';

  @override
  String get statusPaused => 'Duraklatıldı';

  @override
  String get statusWaiting => 'Bekliyor...';

  @override
  String get fileNotFoundRemoving =>
      'Dosya diskte bulunamadı. Kayıt siliniyor.';

  @override
  String get fileNotFound => 'Dosya bulunamadı';

  @override
  String get deleteDownload => 'İndirmeyi Sil';

  @override
  String get confirmDeleteDownload =>
      'Bu indirmeyi ve dosyasını silmek istediğinizden emin misiniz?';

  @override
  String get libraryEmpty => 'Kütüphaneniz boş';

  @override
  String get language => 'Dil';

  @override
  String get english => 'İngilizce';

  @override
  String get hindi => 'Hintçe';

  @override
  String get kannada => 'Kannada';

  @override
  String get unknown => 'Bilinmiyor';

  @override
  String get recommended => 'Önerilen';

  @override
  String get on => 'Açık';

  @override
  String get off => 'Kapalı';

  @override
  String get installRemoveProviders => 'Sağlayıcıları kur veya kaldır';

  @override
  String get resetDataSubtitle =>
      'Ayarları ve veritabanını temizle, eklentileri koru';

  @override
  String get factoryResetSubtitle =>
      'Tüm verileri, ayarları ve eklentileri sil';

  @override
  String get developerOptionsSubtitle =>
      'Hata ayıklama araçları ve yerel oynatma';

  @override
  String get loading => 'Yükleniyor...';

  @override
  String get sec => 'sn';

  @override
  String get min => 'dk';

  @override
  String get internalPlayer => 'Dahili (VLC)';

  @override
  String get builtInPlayer => 'Yerleşik oynatıcı';

  @override
  String get customNotSet => 'Özel (ayarlanmadı)';

  @override
  String selectGesture(String side) {
    return '$side Hareketi Seç';
  }

  @override
  String get left => 'Sol';

  @override
  String get right => 'Sağ';

  @override
  String get selectSeekDuration => 'Atlama Süresini Seç';

  @override
  String get selectBufferDepth => 'Tampon Derinliğini Seç';

  @override
  String get subtitleSettings => 'Altyazı Ayarları';

  @override
  String size(int size) {
    return 'Boyut: $size';
  }

  @override
  String get background => 'Arka Plan';

  @override
  String get customDohUrlLabel => 'Özel DoH URL';

  @override
  String get enterCustomDohUrl => 'Kendi DoH URL\'nizi girin';

  @override
  String get chooseTheme => 'Tema Seç';

  @override
  String get resetDataDialogTitle => 'Verileri Sıfırla?';

  @override
  String get resetDataDialogContent =>
      'Bu işlem Ayarları, Favorileri ve Geçmişi temizleyecektir. Kurulu Eklentileriniz silinmeyecektir.';

  @override
  String get factoryResetDialogTitle => 'Fabrika Ayarlarına Sıfırla?';

  @override
  String get factoryResetDialogContent =>
      'Bu işlem HER ŞEYİ silecek: Favoriler, Geçmiş, Ayarlar ve TÜM Eklentiler. Bu işlem geri alınamaz.';

  @override
  String get selectLanguage => 'Dil Seç';

  @override
  String get synopsis => 'Özet';

  @override
  String get noDescription => 'Açıklama mevcut değil.';

  @override
  String get videoAlreadyDownloadedPrompt =>
      'Bu video zaten indirildi. Ne yapmak appliesiniz?';

  @override
  String get playNow => 'Şimdi Oynat';

  @override
  String get upNext => 'Sırada';

  @override
  String get deleteDownloadPrompt => 'İndirmeyi Sil?';

  @override
  String get deleteDownloadConfirmation =>
      'Bu dosyayı silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.';

  @override
  String get no => 'Hayır';

  @override
  String get yesDelete => 'Evet, Sil';

  @override
  String get downloadPaused => 'İndirme Duraklatıldı';

  @override
  String get downloading => 'İndiriliyor';

  @override
  String get speed => 'Hız';

  @override
  String get remaining => 'Kalan';

  @override
  String get resume => 'Devam Et';

  @override
  String get pause => 'Duraklat';

  @override
  String get torrentContent => 'Torrent İçeriği';

  @override
  String get audioTracks => 'Ses Rayları';

  @override
  String get noAudioTracks => 'Ses rayı bulunamadı';

  @override
  String get subtitles => 'Altyazılar';

  @override
  String get options => 'Seçenekler';

  @override
  String get noSubtitlesFound => 'Altyazı parçası bulunamadı';

  @override
  String get playbackSpeed => 'Oynatma Hızı';

  @override
  String get subtitleOptions => 'Altyazı Seçenekleri';

  @override
  String get hlsSubtitleWarning =>
      'Harici altyazı dosyaları bu platformdaki aktif HLS oynatıcısında desteklenmiyor.';

  @override
  String get loadFromDevice => 'Cihazdan Yükle';

  @override
  String get syncDelay => 'Senkronizasyon / Gecikme';

  @override
  String get styleSettings => 'Stil Ayarları';

  @override
  String get searchOnline => 'Çevrimiçi Ara (Altyazı Arama)';

  @override
  String get subtitleSync => 'Altyazı Senkronizasyonu';

  @override
  String get subtitleDelayWarning =>
      'Altyazı gecikmesi aktif oynatıcı tarafından desteklenmiyor.';

  @override
  String get resetDelay => 'Gecikmeyi Sıfırla';

  @override
  String get subtitleStyles => 'Altyazı Stilleri';

  @override
  String get resetToDefault => 'Varsayılana Sıfırla';

  @override
  String get fontSize => 'Yazı Tipi Boyutu';

  @override
  String get verticalPosition => 'Dikey Pozisyon';

  @override
  String get textColor => 'Metin Rengi';

  @override
  String get backgroundColor => 'Arka Plan Rengi';

  @override
  String get backgroundOpacity => 'Arka Plan Opaklığı';

  @override
  String get subtitleSearch => 'Altyazı Arama';

  @override
  String get searchSubtitleNameHint => 'Altyazı adı ara...';

  @override
  String get enterSearchSubtitlePrompt =>
      'Altyazı bulmak için bir isim girin veya arayın.';

  @override
  String get noSubtitleResults => 'Sonuç bulunamadı. Başka bir sorgu deneyin.';

  @override
  String get downloadingApplyingSubtitle =>
      'Altyazı indiriliyor ve uygulanıyor...';

  @override
  String get failedToDownloadSubtitle => 'Altyazı indirilemedi.';

  @override
  String get failedToLoadSubtitles =>
      'Altyazılar yüklenemedi. Lütfen tekrar deneyin.';

  @override
  String get noReposFound => 'Depo veya eklenti bulunamadı';

  @override
  String get downloadAllProviders => 'Tümünü indir';

  @override
  String get removeRepository => 'Depoyu Kaldır';

  @override
  String get addRepo => 'Depo Ekle';

  @override
  String get extensionsNotInRepos => 'Depolarda Olmayan Eklentiler';

  @override
  String get noLongerInRepo => 'Artık herhangi bir depoda listelenmiyor';

  @override
  String get addRepoToBrowse =>
      'Eklentilere göz atmak ve güncellemek için bir depo ekleyin';

  @override
  String get debugExtensions => 'Eklentileri Hata Ayıkla';

  @override
  String removeRepoConfirm(String repoName) {
    return '$repoName kaldırılsın mı?';
  }

  @override
  String get removeRepoWarning =>
      'bu işlem depoyu kaldıracak ve TÜM eklentilerini silecek.';

  @override
  String get addRepository => 'Depo Ekle';

  @override
  String get repoUrlOrShortcode => 'Depo URL\'si veya Kısa Kod';

  @override
  String get assetPlugin => 'Varlık Eklentisi';

  @override
  String get installed => 'Kurulu';

  @override
  String get repositories => 'Depolar';

  @override
  String get noExtensionsInstalled => 'Yüklü eklenti yok';

  @override
  String get browseRepositoriesToInstall =>
      'Eklentileri keşfetmek ve yüklemek için Depolar sekmesine göz atın.';

  @override
  String get browseRepositories => 'Depolara göz at';

  @override
  String get addRepoDescription =>
      'Eklenti eklerini keşfetmek ve yüklemek için bir depo URL\'si veya kısa kod ekleyin.';

  @override
  String updateTo(String version) {
    return '$version sürümüne güncelle';
  }

  @override
  String get install => 'Kur';

  @override
  String get error => 'Hata';

  @override
  String get ok => 'Tamam';

  @override
  String pluginSettings(String pluginName) {
    return '$pluginName Ayarları';
  }

  @override
  String get movies => 'Filmler';

  @override
  String get series => 'Diziler';

  @override
  String get anime => 'Anime';

  @override
  String get liveStreams => 'Canlı Yayınlar';

  @override
  String get debug => 'HATA AYIKLAMA';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eklenti güncellendi',
      one: '1 eklenti güncellendi',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => 'Geçersiz navigasyon. Lütfen geri gidin.';

  @override
  String get startOver => 'Yeniden Başla';

  @override
  String get goBack => 'Geri Dön';

  @override
  String get resolving => 'Çözümleniyor...';

  @override
  String get downloaded => 'İndirildi';

  @override
  String get download => 'İndir';

  @override
  String get debugOnlyFeature =>
      'Bu özellik sadece Hata Ayıklama yapılarında mevcuttur';

  @override
  String get streamUrl => 'Yayın URL\'si';

  @override
  String get play => 'Oynat';

  @override
  String get verifyingSourceSize => 'Kaynak ve boyut doğrulanıyor...';

  @override
  String get fileSaveLocationNotification =>
      'Dosya İndirilenler klasörünüze kaydedilecektir.';

  @override
  String get resumingPlayback => 'Oynatmaya Devam Ediliyor';

  @override
  String pausedAt(String time) {
    return '$time konumunda duraklatıldı';
  }

  @override
  String resumesAutomatically(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saniye içinde otomatik olarak devam edecek',
      one: '1 saniye içinde otomatik olarak devam edecek',
    );
    return '$_temp0';
  }

  @override
  String get resumeNow => 'Şimdi Devam Et';

  @override
  String get playbackError => 'Oynatma Hatası';

  @override
  String get confirmClearHistory =>
      'İzleme geçmişinden tüm öğeleri kaldırmak istediğinizden emin misiniz?';

  @override
  String seasonWithNumber(Object number) {
    return 'Sezon $number';
  }

  @override
  String get starting => 'Başlatılıyor...';

  @override
  String percentWatched(int percent) {
    return '%$percent izlendi';
  }

  @override
  String get sub => 'Altyazı';

  @override
  String get dub => 'Dublaj';

  @override
  String playEpisode(String label, Object season, Object episode) {
    return '$label S$season E$episode';
  }

  @override
  String playEpisodeOnly(String label, int episode) {
    return '$label E$episode';
  }

  @override
  String get debugTools => 'Hata Ayıklama Araçları';

  @override
  String get playLocalVideo => 'Yerel video dosyasını oynat';

  @override
  String get playLocalVideoSubtitle => 'Cihazdan herhangi bir videoyu oynat';

  @override
  String get streamUrlSubtitle => 'Ağ URL\'sinden oynat';

  @override
  String get streamTorrent => 'Torrent yayınla';

  @override
  String get streamTorrentSubtitle =>
      'Oynatmak için yerel bir torrent dosyası seçin';

  @override
  String get loadPluginFromAssets => 'Eklentiyi varlıklardan yükle';

  @override
  String get enterVideoUrlHint => 'Video URL\'sini girin (http, magnet, vb.)';

  @override
  String get networkStream => 'Ağ Yayını';

  @override
  String removedFromHistory(String title) {
    return '$title geçmişten kaldırıldı';
  }

  @override
  String get custom => 'Özel';

  @override
  String get refreshingLiveStream => 'Canlı yayın yenileniyor...';

  @override
  String get removeFromHistory => 'Geçmişten Kaldır';

  @override
  String get live => 'CANLI';

  @override
  String get volume => 'Ses';

  @override
  String get brightness => 'Parlaklık';

  @override
  String get fit => 'Sığdır';

  @override
  String get zoom => 'Yakınlaştır';

  @override
  String get stretch => 'Uzat';

  @override
  String titleWithParam(String title) {
    return 'Başlık: $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'Kaynak: $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'Boyut: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'Hata: $error. Dahili oynatıcı kullanılıyor.';
  }

  @override
  String playerNotDetected(String playerName) {
    return '$playerName algılanamadı. Dahili oynatıcı başlatılıyor.';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return 'Sezon $number ($count Bölüm)';
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
    return '$playerName için Kaynak Seç';
  }

  @override
  String get noPluginsInstalled => 'Eklenti kurulu değil';

  @override
  String get noPluginsMessage =>
      'İçeriğe göz atmak ve akış yapmak için uzantıları yükleyin.';

  @override
  String get goToExtensions => 'Uzantılara git';

  @override
  String get availableSources => 'Mevcut Kaynaklar';

  @override
  String get seasons => 'Sezonlar';

  @override
  String get episodes => 'Bölümler';

  @override
  String get selectSourceToPlay =>
      'Lütfen oynatmak için yukarıdaki \'Mevcut Kaynaklar\'dan bir kaynak seçin.';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Bölüm',
      one: '1 Bölüm',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'Bölüm bulunamadı';

  @override
  String get local => 'Yerel';

  @override
  String get remote => 'Uzak';

  @override
  String get torrent => 'Torrent';

  @override
  String get unlock => 'Kilidi Aç';

  @override
  String get lock => 'Kilitle';

  @override
  String get sources => 'Kaynaklar';

  @override
  String get tracks => 'İzler';

  @override
  String get content => 'İçerik';

  @override
  String get stats => 'İstatistikler';

  @override
  String get resize => 'Boyutlandır';

  @override
  String get next => 'Sonraki';

  @override
  String get pip => 'PiP';

  @override
  String get rotate => 'Döndür';

  @override
  String get windowed => 'Pencereli';

  @override
  String get fullscreen => 'Tam Ekran';

  @override
  String get movieDetails => 'Film Detayları';

  @override
  String get showDetails => 'Detayları Göster';

  @override
  String get tagline => 'Slogan';

  @override
  String get status => 'Durum';

  @override
  String get releaseDate => 'Yayın Tarihi';

  @override
  String get firstAirDate => 'İlk Bölüm Tarihi';

  @override
  String get originalLanguage => 'Orijinal Dil';

  @override
  String get originCountry => 'Menşei Ülke';

  @override
  String get budgetLabel => 'Bütçe';

  @override
  String get revenueLabel => 'Hasılat';

  @override
  String get paused => 'Duraklatıldı';

  @override
  String get watched => 'İzlendi';

  @override
  String get watching => 'İzleniyor';

  @override
  String get lastWatched => 'Son İzlenen';

  @override
  String get movie => 'Film';

  @override
  String get tvShow => 'Dizi';

  @override
  String get failedToLoadContent => 'İçerik yüklenemedi';

  @override
  String get director => 'Yönetmen';

  @override
  String get creator => 'Yaratıcı';

  @override
  String get showMore => 'Daha Fazla';

  @override
  String get showLess => 'Daha Az';

  @override
  String get viewAll => 'Tümünü Gör';

  @override
  String seasonsCount(int count) {
    return '$count Sezon';
  }

  @override
  String get noInternetError => 'İnternet bağlantısı yok';

  @override
  String get timeoutError =>
      'İstek zaman aşımına uğradı. Lütfen tekrar deneyin.';

  @override
  String get serverError => 'Sunucu hatası. Lütfen daha sonra tekrar deneyin.';

  @override
  String get contentNotFoundError => 'İçerik bulunamadı.';

  @override
  String get accessDeniedError =>
      'Erişim reddedildi. Bilgilerinizi kontrol edin.';

  @override
  String get serviceUnavailableError =>
      'Sunucu kullanılamıyor. Daha sonra tekrar deneyin.';

  @override
  String get generalError => 'Bir şeyler yanlış gitti. Lütfen tekrar deneyin.';

  @override
  String get skip => 'Atla';

  @override
  String get skipIntro => 'Girişi atla';

  @override
  String get skipOutro => 'Kapanışı atla';

  @override
  String get skipRecap => 'Özeti atla';

  @override
  String get goLive => 'Canlıya Geç';

  @override
  String get dismiss => 'Kapat';

  @override
  String get nextUp => 'Sıradaki';

  @override
  String sourceAttempt(int index, int total) {
    return 'Kaynak $index / $total';
  }

  @override
  String get trying => 'Deneniyor';

  @override
  String get failed => 'Başarısız';

  @override
  String get selected => 'Seçildi';

  @override
  String get playing => 'Oynatılıyor';

  @override
  String get pending => 'Bekliyor';

  @override
  String get openSubtitles => 'OpenSubtitles';

  @override
  String get subDl => 'SubDL';

  @override
  String get subSource => 'SubSource';

  @override
  String get wifiQualityPreference => 'Wi-Fi kalite tercihi';

  @override
  String get mobileQualityPreference => 'Mobil kalite tercihi';

  @override
  String get anyNoPreference => 'Fark etmez';

  @override
  String get subtitleAccounts => 'Altyazı hesapları';

  @override
  String get accounts => 'Hesaplar';

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
  String get testConnection => 'Bağlantıyı test et';

  @override
  String get connectedSuccessfully => 'Bağlantı başarılı';

  @override
  String get connectionFailed => 'Bağlantı başarısız';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get noAccountRegister => 'Don\'t have an account? Register here';

  @override
  String get apiKey => 'API anahtarı';

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
  String get diagnostics => 'Tanılama';

  @override
  String get viewLogs => 'Günlükleri görüntüle';

  @override
  String get viewLogsSubtitle => 'Uygulama etkinliğini ve hataları görüntüle';

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
