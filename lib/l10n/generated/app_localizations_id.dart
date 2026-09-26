// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => 'Bahasa Indonesia';

  @override
  String get addonHealthChecking => 'Checking add-on…';

  @override
  String addonHealthWorking(int ms) {
    return 'Working · $ms ms';
  }

  @override
  String get addonHealthUnavailable => 'Unavailable';

  @override
  String get home => 'Beranda';

  @override
  String get search => 'Cari';

  @override
  String get explore => 'Jelajahi';

  @override
  String get exploreAnime => 'Jelajahi Anime';

  @override
  String get exploreMovies => 'Jelajahi Film';

  @override
  String get library => 'Perpustakaan';

  @override
  String get settings => 'Pengaturan';

  @override
  String get extensions => 'Ekstensi';

  @override
  String get updateAvailable => 'Pembaruan Tersedia';

  @override
  String get retry => 'Coba Lagi';

  @override
  String get factoryReset => 'Reset Pabrik';

  @override
  String get startupError => 'Kesalahan Awal';

  @override
  String get general => 'Umum';

  @override
  String get appTheme => 'Tema Aplikasi';

  @override
  String get recordWatchHistory => 'Rekam Riwayat Tontonan';

  @override
  String get fullScreenMode => 'Layar Penuh';

  @override
  String get fullScreenModeSubtitle => 'Beralih ke tata letak TV';

  @override
  String get defaultHomeScreen => 'Layar Utama Default';

  @override
  String get titlePosition => 'Posisi Judul';

  @override
  String get titlePositionBelowPoster => 'Di Bawah Poster';

  @override
  String get titlePositionInsidePoster => 'Di Dalam Poster';

  @override
  String get player => 'Pemutar';

  @override
  String get defaultPlayer => 'Pemutar Default';

  @override
  String get leftGesture => 'Gestur Kiri';

  @override
  String get rightGesture => 'Gestur Kanan';

  @override
  String get doubleTapToSeek => 'Ketuk Dua Kali untuk Mencari';

  @override
  String get swipeToSeek => 'Geser untuk Mencari';

  @override
  String get seekDuration => 'Durasi Lompatan';

  @override
  String get defaultResizeMode => 'Mode Ukuran Default';

  @override
  String get hardwareDecoding => 'Dekode Perangkat Keras';

  @override
  String get network => 'Jaringan';

  @override
  String get dnsOverHttps => 'DNS melalui HTTPS';

  @override
  String get dohProvider => 'Penyedia DoH';

  @override
  String get githubProxy => 'Proksi GitHub';

  @override
  String get githubProxySubtitle =>
      'Alihkan unduhan ekstensi melalui jsDelivr untuk melewati pemblokiran ISP.';

  @override
  String get manageExtensions => 'Kelola Ekstensi';

  @override
  String get appData => 'Data Aplikasi';

  @override
  String get resetDataKeepExtensions => 'Reset Data (Simpan Ekstensi)';

  @override
  String get developer => 'Pengembang';

  @override
  String get developerOptions => 'Opsi Pengembang';

  @override
  String get about => 'Tentang';

  @override
  String get version => 'Versi';

  @override
  String get enabled => 'Aktif';

  @override
  String get disabled => 'Nonaktif';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'Bergabunglah dengan server kami';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'Bergabunglah dengan saluran kami';

  @override
  String developedBy(String name) {
    return 'Dikembangkan oleh $name';
  }

  @override
  String get system => 'Sistem';

  @override
  String get dark => 'Gelap';

  @override
  String get light => 'Terang';

  @override
  String get later => 'Nanti';

  @override
  String get updateNow => 'Perbarui Sekarang';

  @override
  String get save => 'Simpan';

  @override
  String get cancel => 'Batal';

  @override
  String get close => 'Tutup';

  @override
  String get delete => 'Hapus';

  @override
  String get viewDetails => 'Lihat Detail';

  @override
  String get clearAll => 'Hapus Semua';

  @override
  String get clearAllHistory => 'Hapus Semua Riwayat';

  @override
  String get all => 'Semua';

  @override
  String get none => 'Tidak ada';

  @override
  String get confirmDownload => 'Konfirmasi Unduhan';

  @override
  String get downloadNow => 'Unduh Sekarang';

  @override
  String get selectSource => 'Pilih Sumber';

  @override
  String get downloadUnavailable => 'Unduhan Tidak Tersedia';

  @override
  String get selectAnotherSource => 'Pilih Sumber Lain';

  @override
  String get watchHistoryCleared => 'Riwayat tontonan dihapus';

  @override
  String get downloadingUpdate => 'Mengunduh pembaruan...';

  @override
  String errorPrefix(String message) {
    return 'Kesalahan: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'Pembaruan Tersedia: $tag';
  }

  @override
  String get selectProviderToStart => 'Pilih penyedia untuk mulai menonton';

  @override
  String get tapExtensionIcon => 'Ketuk ikon ekstensi di pojok';

  @override
  String get continueWatching => 'Lanjutkan Menonton';

  @override
  String get noInternetConnection => 'Tidak ada Koneksi Internet';

  @override
  String get siteNotReachable => 'Situs Tidak Dapat Dijangkau';

  @override
  String get checkConnectionOrDownloads =>
      'Periksa koneksi Anda atau lihat konten yang Anda unduh.';

  @override
  String get tryVpnOrConnection =>
      'Cobalah mengakses situs dengan VPN atau periksa koneksi internet Anda.';

  @override
  String errorDetails(String error) {
    return 'Detail Kesalahan: $error';
  }

  @override
  String get goToDownloads => 'Ke Unduhan';

  @override
  String get selectProvider => 'Pilih Penyedia';

  @override
  String get searchHint => 'Cari film, serial...';

  @override
  String get searchFavoriteContent => 'Cari konten favorit Anda';

  @override
  String get pressSearchOrEnter => 'Tekan tombol Cari atau Enter untuk memulai';

  @override
  String get recentSearches => 'Recent searches';

  @override
  String removeFromSearchHistory(String query) {
    return 'Remove $query from search history';
  }

  @override
  String get noResultsFound => 'Tidak ditemukan hasil.';

  @override
  String get couldNotLoadTrending => 'Gagal memuat tren';

  @override
  String get popularMovies => 'Film Populer';

  @override
  String get popularTVShows => 'Acara TV Populer';

  @override
  String get newMovies => 'Film Baru';

  @override
  String get newTVShows => 'Acara TV Baru';

  @override
  String get featuredMovies => 'Film Unggulan';

  @override
  String get featuredTVShows => 'Acara TV Unggulan';

  @override
  String get lastVideosTVShows => 'Acara TV Video Terakhir';

  @override
  String get downloads => 'Unduhan';

  @override
  String get bookmarks => 'Penanda';

  @override
  String get noDownloadsYet => 'Belum ada unduhan';

  @override
  String episodesCount(int count, int done) {
    return '$count Episode • $done Selesai';
  }

  @override
  String get deleteAllEpisodes => 'Hapus Semua Episode';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return 'Anda yakin ingin menghapus semua $count episode dari \"$title\" beserta filenya?';
  }

  @override
  String get deleteAll => 'Hapus Semua';

  @override
  String get completed => 'Selesai';

  @override
  String get statusQueued => 'Dalam antrean...';

  @override
  String get statusDownloading => 'Mengunduh...';

  @override
  String get statusFinished => 'Selesai';

  @override
  String get statusFailed => 'Gagal';

  @override
  String get statusCanceled => 'Dibatalkan';

  @override
  String get statusPaused => 'Ditunda';

  @override
  String get statusWaiting => 'Menunggu...';

  @override
  String get fileNotFoundRemoving =>
      'File tidak ditemukan di disk. Menghapus catatan.';

  @override
  String get fileNotFound => 'File tidak ditemukan';

  @override
  String get deleteDownload => 'Hapus Unduhan';

  @override
  String get confirmDeleteDownload =>
      'Anda yakin ingin menghapus unduhan ini beserta filenya?';

  @override
  String get libraryEmpty => 'Perpustakaan Anda kosong';

  @override
  String get language => 'Bahasa';

  @override
  String get english => 'Inggris';

  @override
  String get hindi => 'Hindi';

  @override
  String get kannada => 'Kannada';

  @override
  String get unknown => 'Tidak Diketahui';

  @override
  String get recommended => 'Direkomendasikan';

  @override
  String get on => 'Aktif';

  @override
  String get off => 'Mati';

  @override
  String get installRemoveProviders => 'Pasang atau hapus penyedia';

  @override
  String get resetDataSubtitle =>
      'Bersihkan pengaturan & database, simpan plugin';

  @override
  String get factoryResetSubtitle =>
      'Hapus semua data, pengaturan, dan ekstensi';

  @override
  String get developerOptionsSubtitle => 'Alat debug & putar lokal';

  @override
  String get loading => 'Memuat...';

  @override
  String get sec => 'dtk';

  @override
  String get min => 'mnt';

  @override
  String playerRewindSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mundur $count detik',
    );
    return '$_temp0';
  }

  @override
  String playerForwardSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Maju $count detik',
    );
    return '$_temp0';
  }

  @override
  String get internalPlayer => 'Internal (VLC)';

  @override
  String get builtInPlayer => 'Pemutar bawaan';

  @override
  String get customNotSet => 'Kustom (belum diatur)';

  @override
  String selectGesture(String side) {
    return 'Pilih Gestur $side';
  }

  @override
  String get left => 'Kiri';

  @override
  String get right => 'Kanan';

  @override
  String get selectSeekDuration => 'Pilih Durasi Lompatan';

  @override
  String get subtitleSettings => 'Pengaturan Terjemahan';

  @override
  String size(int size) {
    return 'Ukuran: $size';
  }

  @override
  String get background => 'Latar Belakang';

  @override
  String get customDohUrlLabel => 'URL DoH Kustom';

  @override
  String get enterCustomDohUrl => 'Masukkan URL DoH Anda sendiri';

  @override
  String get chooseTheme => 'Pilih Tema';

  @override
  String get resetDataDialogTitle => 'Reset Data?';

  @override
  String get resetDataDialogContent =>
      'Ini akan membersihkan Pengaturan, Favorit, dan Riwayat. Ekstensi terinstal Anda TIDAK akan dihapus.';

  @override
  String get factoryResetDialogTitle => 'Reset Pabrik?';

  @override
  String get factoryResetDialogContent =>
      'Ini akan menghapus SEMUANYA: Favorit, Riwayat, Pengaturan, dan SEMUA Ekstensi. Ini tidak dapat dibatalkan.';

  @override
  String get selectLanguage => 'Pilih Bahasa';

  @override
  String get synopsis => 'Sinopsis';

  @override
  String get noDescription => 'Deskripsi tidak tersedia.';

  @override
  String get videoAlreadyDownloadedPrompt =>
      'Video ini sudah diunduh. Apa yang ingin Anda lakukan?';

  @override
  String get playNow => 'Putar Sekarang';

  @override
  String get upNext => 'Berikutnya';

  @override
  String get deleteDownloadPrompt => 'Hapus Unduhan?';

  @override
  String get deleteDownloadConfirmation =>
      'Anda yakin ingin menghapus file ini? Ini tidak dapat dibatalkan.';

  @override
  String get no => 'Tidak';

  @override
  String get yesDelete => 'Ya, Hapus';

  @override
  String get downloadPaused => 'Unduhan Ditunda';

  @override
  String get downloading => 'Mengunduh';

  @override
  String get speed => 'Kecepatan';

  @override
  String get remaining => 'Tersisa';

  @override
  String get resume => 'Lanjutkan';

  @override
  String get pause => 'Jeda';

  @override
  String get torrentContent => 'Konten Torrent';

  @override
  String get audioTracks => 'Trek Audio';

  @override
  String get noAudioTracks => 'Trek audio tidak ditemukan';

  @override
  String get subtitles => 'Terjemahan';

  @override
  String get options => 'Opsi';

  @override
  String get noSubtitlesFound => 'Trek terjemahan tidak ditemukan';

  @override
  String get playbackSpeed => 'Kecepatan Putar';

  @override
  String get subtitleOptions => 'Opsi Terjemahan';

  @override
  String get hlsSubtitleWarning =>
      'File terjemahan eksternal tidak didukung pada pemutar HLS aktif di platform ini.';

  @override
  String get loadFromDevice => 'Muat dari Perangkat';

  @override
  String get syncDelay => 'Sinkronisasi / Penundaan';

  @override
  String get styleSettings => 'Pengaturan Gaya';

  @override
  String get searchOnline => 'Cari Daring (Cari Terjemahan)';

  @override
  String get subtitleSync => 'Sinkronisasi Terjemahan';

  @override
  String get subtitleDelayWarning =>
      'Penundaan terjemahan tidak didukung oleh mesin pemutar aktif.';

  @override
  String get resetDelay => 'Reset Penundaan';

  @override
  String get subtitleStyles => 'Gaya Terjemahan';

  @override
  String get resetToDefault => 'Reset ke Default';

  @override
  String get fontSize => 'Ukuran Font';

  @override
  String get verticalPosition => 'Posisi Vertikal';

  @override
  String get textColor => 'Warna Teks';

  @override
  String get backgroundColor => 'Warna Latar Belakang';

  @override
  String get backgroundOpacity => 'Opasitas Latar Belakang';

  @override
  String get subtitleSearch => 'Cari Terjemahan';

  @override
  String get searchSubtitleNameHint => 'Cari nama terjemahan...';

  @override
  String get enterSearchSubtitlePrompt =>
      'Masukkan nama atau cari untuk menemukan terjemahan.';

  @override
  String get noSubtitleResults => 'Hasil tidak ditemukan. Coba kueri lain.';

  @override
  String get downloadingApplyingSubtitle =>
      'Mengunduh & menerapkan terjemahan...';

  @override
  String get failedToDownloadSubtitle => 'Gagal mengunduh terjemahan.';

  @override
  String get failedToLoadSubtitles =>
      'Gagal memuat terjemahan. Silakan coba lagi.';

  @override
  String get noReposFound => 'Repositori atau plugin tidak ditemukan';

  @override
  String get downloadAllProviders => 'Unduh semua';

  @override
  String get removeRepository => 'Hapus Repositori';

  @override
  String get addRepo => 'Tambah Repo';

  @override
  String get extensionsNotInRepos => 'Ekstensi Tidak di Repositori';

  @override
  String get noLongerInRepo => 'Tidak lagi terdaftar di repositori manapun';

  @override
  String get addRepoToBrowse =>
      'Tambah repositori untuk menjelajah dan memperbarui plugin';

  @override
  String get debugExtensions => 'Debug Ekstensi';

  @override
  String removeRepoConfirm(String repoName) {
    return 'Hapus $repoName?';
  }

  @override
  String get removeRepoWarning =>
      'Ini akan menghapus repositori dan mencopot SEMUA pluginnya.';

  @override
  String get addRepository => 'Tambah Repositori';

  @override
  String get repoUrlOrShortcode => 'URL Repositori atau Kode Pintas';

  @override
  String get assetPlugin => 'Plugin Aset';

  @override
  String get installed => 'Terinstal';

  @override
  String get repositories => 'Repositori';

  @override
  String get noExtensionsInstalled => 'Tidak Ada Ekstensi Terpasang';

  @override
  String get browseRepositoriesToInstall =>
      'Buka tab Repositori untuk menemukan dan memasang ekstensi.';

  @override
  String get browseRepositories => 'Jelajahi Repositori';

  @override
  String get addRepoDescription =>
      'Tambahkan URL repositori atau kode pendek untuk menemukan dan memasang plugin ekstensi.';

  @override
  String updateTo(String version) {
    return 'Perbarui ke $version';
  }

  @override
  String get install => 'Pasang';

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
  String get error => 'Kesalahan';

  @override
  String get ok => 'OKE';

  @override
  String pluginSettings(String pluginName) {
    return 'Pengaturan $pluginName';
  }

  @override
  String get movies => 'Film';

  @override
  String get series => 'Serial';

  @override
  String get anime => 'Anime';

  @override
  String get liveStreams => 'Siaran Langsung';

  @override
  String get debug => 'DEBUG';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ekstensi diperbarui',
      one: '1 ekstensi diperbarui',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => 'Navigasi tidak valid. Silakan kembali.';

  @override
  String get startOver => 'Mulai Lagi';

  @override
  String get goBack => 'Kembali';

  @override
  String get restartApp => 'Mulai Ulang Aplikasi';

  @override
  String get resolving => 'Mengurai...';

  @override
  String get downloaded => 'Diunduh';

  @override
  String get download => 'Unduh';

  @override
  String get debugOnlyFeature => 'Fitur ini hanya tersedia pada build Debug';

  @override
  String get streamUrl => 'URL Siaran';

  @override
  String get play => 'Putar';

  @override
  String get verifyingSourceSize => 'Memverifikasi sumber & ukuran...';

  @override
  String get fileSaveLocationNotification =>
      'File akan disimpan di folder Unduhan Anda.';

  @override
  String get resumingPlayback => 'Melanjutkan Pemutaran';

  @override
  String pausedAt(String time) {
    return 'Ditunda pada $time';
  }

  @override
  String resumesAutomatically(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Melanjutkan otomatis dalam $count detik',
      one: 'Melanjutkan otomatis dalam 1 detik',
    );
    return '$_temp0';
  }

  @override
  String get resumeNow => 'Lanjutkan Sekarang';

  @override
  String get playbackError => 'Kesalahan Pemutaran';

  @override
  String get confirmClearHistory =>
      'Anda yakin ingin menghapus semua item dari riwayat tontonan Anda?';

  @override
  String seasonWithNumber(Object number) {
    return 'Musim $number';
  }

  @override
  String get starting => 'Memulai...';

  @override
  String percentWatched(int percent) {
    return '$percent% ditonton';
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
  String get debugTools => 'Alat Debug';

  @override
  String get playLocalVideo => 'Putar file video lokal';

  @override
  String get playLocalVideoSubtitle => 'Putar video apapun dari perangkat';

  @override
  String get streamUrlSubtitle => 'Putar dari URL jaringan';

  @override
  String get streamTorrent => 'Siarkan torrent';

  @override
  String get streamTorrentSubtitle => 'Pilih file torrent lokal untuk diputar';

  @override
  String get loadPluginFromAssets => 'Muat plugin dari aset';

  @override
  String get enterVideoUrlHint => 'Masukkan URL video (http, magnet, dll.)';

  @override
  String get networkStream => 'Siaran Jaringan';

  @override
  String removedFromHistory(String title) {
    return 'Menghapus $title dari riwayat';
  }

  @override
  String get custom => 'Kustom';

  @override
  String get refreshingLiveStream => 'Menyegarkan siaran langsung...';

  @override
  String get removeFromHistory => 'Hapus dari Riwayat';

  @override
  String get live => 'LANGSUNG';

  @override
  String get volume => 'Volume';

  @override
  String get decrease => 'Decrease';

  @override
  String get increase => 'Increase';

  @override
  String get brightness => 'Kecerahan';

  @override
  String get fit => 'Pas';

  @override
  String get zoom => 'Perbesar';

  @override
  String get stretch => 'Regangkan';

  @override
  String titleWithParam(String title) {
    return 'Judul: $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'Sumber: $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'Ukuran: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'Kesalahan: $error. Menggunakan pemutar internal.';
  }

  @override
  String externalPlayerCannotSendHeaders(String playerName, String headers) {
    return '$playerName cannot send $headers. Using internal player.';
  }

  @override
  String playerNotDetected(String playerName) {
    return '$playerName tidak terdeteksi. Memulai pemutar internal.';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return 'Musim $number ($count Episode)';
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
    return 'Pilih Sumber untuk $playerName';
  }

  @override
  String get noPluginsInstalled => 'Tidak ada plugin terinstal';

  @override
  String get noPluginsMessage =>
      'Instal ekstensi untuk menelusuri dan mengalirkan konten.';

  @override
  String get goToExtensions => 'Buka Ekstensi';

  @override
  String get availableSources => 'Sumber Tersedia';

  @override
  String get seasons => 'Musim';

  @override
  String get episodes => 'Episode';

  @override
  String get selectSourceToPlay =>
      'Silakan pilih sumber dari \'Sumber Tersedia\' di atas untuk diputar.';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Episode',
      one: '1 Episode',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'Episode tidak ditemukan';

  @override
  String get local => 'Lokal';

  @override
  String get remote => 'Jarak Jauh';

  @override
  String get torrent => 'Torrent';

  @override
  String get unlock => 'Buka Kunci';

  @override
  String get lock => 'Kunci';

  @override
  String get sources => 'Sumber';

  @override
  String get tracks => 'Trek';

  @override
  String get content => 'Konten';

  @override
  String get stats => 'Statistik';

  @override
  String get resize => 'Ubah Ukuran';

  @override
  String get next => 'Berikutnya';

  @override
  String get previous => 'Previous';

  @override
  String get pip => 'PiP';

  @override
  String get rotate => 'Putar';

  @override
  String get windowed => 'Jendela';

  @override
  String get fullscreen => 'Layar Penuh';

  @override
  String get movieDetails => 'Detail Film';

  @override
  String get showDetails => 'Lihat Detail';

  @override
  String get tagline => 'Slogan';

  @override
  String get status => 'Status';

  @override
  String get releaseDate => 'Tanggal Rilis';

  @override
  String get firstAirDate => 'Tanggal Siaran Pertama';

  @override
  String get originalLanguage => 'Bahasa Asli';

  @override
  String get originCountry => 'Negara Asal';

  @override
  String get budgetLabel => 'Anggaran';

  @override
  String get revenueLabel => 'Pendapatan';

  @override
  String get paused => 'Ditunda';

  @override
  String get watched => 'Ditonton';

  @override
  String get watching => 'Sedang Menonton';

  @override
  String get lastWatched => 'Terakhir Ditonton';

  @override
  String get movie => 'Film';

  @override
  String get tvShow => 'Acara TV';

  @override
  String get failedToLoadContent => 'Gagal memuat konten';

  @override
  String get director => 'Sutradara';

  @override
  String get creator => 'Pembuat';

  @override
  String get showMore => 'Lihat Lebih Banyak';

  @override
  String get showLess => 'Lihat Lebih Sedikit';

  @override
  String get viewAll => 'Lihat Semua';

  @override
  String seasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Musim',
      one: '1 Musim',
    );
    return '$_temp0';
  }

  @override
  String get noInternetError => 'Tidak ada koneksi internet';

  @override
  String get timeoutError => 'Waktu permintaan habis. Silakan coba lagi.';

  @override
  String get serverError => 'Kesalahan server. Silakan coba lagi nanti.';

  @override
  String get contentNotFoundError => 'Konten tidak ditemukan.';

  @override
  String get accessDeniedError => 'Akses ditolak. Periksa kredensial Anda.';

  @override
  String get serviceUnavailableError =>
      'Server tidak tersedia. Coba lagi nanti.';

  @override
  String get generalError => 'Terjadi kesalahan. Silakan coba lagi.';

  @override
  String get skip => 'Lewati';

  @override
  String get skipIntro => 'Lewati Intro';

  @override
  String get skipOutro => 'Lewati Outro';

  @override
  String get skipRecap => 'Lewati Rekap';

  @override
  String get goLive => 'Siaran Langsung';

  @override
  String get dismiss => 'Tutup';

  @override
  String get nextUp => 'Berikutnya';

  @override
  String sourceAttempt(int index, int total) {
    return 'Sumber $index dari $total';
  }

  @override
  String get trying => 'Mencoba';

  @override
  String get failed => 'Gagal';

  @override
  String get selected => 'Dipilih';

  @override
  String get playing => 'Memutar';

  @override
  String get pending => 'Menunggu';

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
  String get mobileQualityPreference => 'Preferensi kualitas seluler';

  @override
  String get anyNoPreference => 'Tanpa preferensi';

  @override
  String get subtitleAccounts => 'Akun subtitle';

  @override
  String get accounts => 'Akun';

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
  String get testConnection => 'Tes koneksi';

  @override
  String get connectedSuccessfully => 'Berhasil terhubung';

  @override
  String get connectionFailed => 'Koneksi gagal';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get noAccountRegister => 'Don\'t have an account? Register here';

  @override
  String get apiKey => 'Kunci API';

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
  String get diagnostics => 'Diagnostik';

  @override
  String get viewLogs => 'Lihat log';

  @override
  String get viewLogsSubtitle => 'Lihat aktivitas aplikasi & kesalahan';

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
  String get sourcesSearching => 'Mencari di scraper…';

  @override
  String get sourcesEmptyFiltered =>
      'Tidak ada tautan yang cocok dengan filter.';

  @override
  String get sourcesEmptyNoTmdbId =>
      'Judul ini tidak punya ID TMDB. Masukkan lewat \'Search manually\'.';

  @override
  String get sourcesEmptyNoScrapers =>
      'Tidak ada scraper aktif. Tambahkan di \'Nuvio Plugins\'.';

  @override
  String get sourcesEmptyAllFailed =>
      'Semua scraper gagal. Periksa koneksi Anda atau perbarui scraper.';

  @override
  String sourcesEmptySomeFailed(int failed, int total) {
    return 'Tautan tidak ditemukan. $failed dari $total scraper gagal.';
  }

  @override
  String get sourcesEmptyNothingFound =>
      'Tidak ada scraper Anda yang punya judul ini.';

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
