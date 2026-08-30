// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => 'Tiếng Việt';

  @override
  String get home => 'Trang chủ';

  @override
  String get search => 'Tìm kiếm';

  @override
  String get explore => 'Khám phá';

  @override
  String get exploreAnime => 'Khám phá anime';

  @override
  String get exploreMovies => 'Khám phá phim';

  @override
  String get library => 'Thư viện';

  @override
  String get settings => 'Cài đặt';

  @override
  String get extensions => 'Tiện ích mở rộng';

  @override
  String get updateAvailable => 'Có bản cập nhật mới';

  @override
  String get retry => 'Thử lại';

  @override
  String get factoryReset => 'Khôi phục cài đặt gốc';

  @override
  String get startupError => 'Lỗi khởi động';

  @override
  String get general => 'Chung';

  @override
  String get appTheme => 'Chủ đề ứng dụng';

  @override
  String get recordWatchHistory => 'Lưu lịch sử xem';

  @override
  String get defaultHomeScreen => 'Màn hình chính mặc định';

  @override
  String get titlePosition => 'Vị trí tiêu đề';

  @override
  String get titlePositionBelowPoster => 'Dưới áp phích';

  @override
  String get titlePositionInsidePoster => 'Trong áp phích';

  @override
  String get player => 'Trình phát';

  @override
  String get defaultPlayer => 'Trình phát mặc định';

  @override
  String get leftGesture => 'Cử chỉ bên trái';

  @override
  String get rightGesture => 'Cử chỉ bên phải';

  @override
  String get doubleTapToSeek => 'Chạm hai lần để tua';

  @override
  String get swipeToSeek => 'Vuốt để tua';

  @override
  String get seekDuration => 'Thời gian tua';

  @override
  String get bufferDepth => 'Độ sâu bộ đệm';

  @override
  String get defaultResizeMode => 'Chế độ thu phóng mặc định';

  @override
  String get hardwareDecoding => 'Giải mã phần cứng';

  @override
  String get network => 'Mạng';

  @override
  String get dnsOverHttps => 'DNS qua HTTPS';

  @override
  String get dohProvider => 'Nhà cung cấp DoH';

  @override
  String get githubProxy => 'Proxy GitHub';

  @override
  String get githubProxySubtitle =>
      'Định tuyến tải xuống tiện ích mở rộng qua jsDelivr để vượt chặn của nhà mạng.';

  @override
  String get manageExtensions => 'Quản lý tiện ích';

  @override
  String get appData => 'Dữ liệu ứng dụng';

  @override
  String get resetDataKeepExtensions => 'Xóa dữ liệu (Giữ lại tiện ích)';

  @override
  String get developer => 'Nhà phát triển';

  @override
  String get developerOptions => 'Tùy chọn nhà phát triển';

  @override
  String get about => 'Giới thiệu';

  @override
  String get version => 'Phiên bản';

  @override
  String get enabled => 'Đã bật';

  @override
  String get disabled => 'Đã tắt';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'Tham gia máy chủ của chúng tôi';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'Tham gia kênh của chúng tôi';

  @override
  String developedBy(String name) {
    return 'Được phát triển bởi $name';
  }

  @override
  String get system => 'Hệ thống';

  @override
  String get dark => 'Tối';

  @override
  String get light => 'Sáng';

  @override
  String get later => 'Để sau';

  @override
  String get updateNow => 'Cập nhật ngay';

  @override
  String get save => 'Lưu';

  @override
  String get cancel => 'Hủy';

  @override
  String get close => 'Đóng';

  @override
  String get delete => 'Xóa';

  @override
  String get viewDetails => 'Xem chi tiết';

  @override
  String get clearAll => 'Xóa tất cả';

  @override
  String get clearAllHistory => 'Xóa lịch sử xem';

  @override
  String get all => 'Tất cả';

  @override
  String get none => 'Không có';

  @override
  String get confirmDownload => 'Xác nhận tải xuống';

  @override
  String get downloadNow => 'Tải ngay';

  @override
  String get selectSource => 'Chọn nguồn';

  @override
  String get downloadUnavailable => 'Không khả dụng';

  @override
  String get selectAnotherSource => 'Chọn nguồn khác';

  @override
  String get watchHistoryCleared => 'Đã xóa lịch sử xem';

  @override
  String get downloadingUpdate => 'Đang tải bản cập nhật...';

  @override
  String errorPrefix(String message) {
    return 'Lỗi: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'Có bản cập nhật: $tag';
  }

  @override
  String get selectProviderToStart => 'Chọn một nguồn để bắt đầu xem';

  @override
  String get tapExtensionIcon => 'Nhấn vào biểu tượng tiện ích ở góc';

  @override
  String get continueWatching => 'Tiếp tục xem';

  @override
  String get noInternetConnection => 'Không có kết nối Internet';

  @override
  String get siteNotReachable => 'Không thể truy cập trang web';

  @override
  String get checkConnectionOrDownloads =>
      'Kiểm tra kết nối hoặc xem nội dung đã tải xuống.';

  @override
  String get tryVpnOrConnection =>
      'Vui lòng thử sử dụng VPN hoặc kiểm tra kết nối mạng.';

  @override
  String errorDetails(String error) {
    return 'Chi tiết lỗi: $error';
  }

  @override
  String get goToDownloads => 'Đi đến phần tải xuống';

  @override
  String get selectProvider => 'Chọn nguồn cung cấp';

  @override
  String get searchHint => 'Tìm phim, chương trình...';

  @override
  String get searchFavoriteContent => 'Tìm kiếm nội dung yêu thích của bạn';

  @override
  String get pressSearchOrEnter => 'Nhấn phím Tìm kiếm hoặc Enter để bắt đầu';

  @override
  String get noResultsFound => 'Không tìm thấy kết quả.';

  @override
  String get couldNotLoadTrending => 'Không thể tải các mục xu hướng';

  @override
  String get popularMovies => 'Phim phổ biến';

  @override
  String get popularTVShows => 'Chương trình TV phổ biến';

  @override
  String get newMovies => 'Phim mới';

  @override
  String get newTVShows => 'Chương trình TV mới';

  @override
  String get featuredMovies => 'Phim nổi bật';

  @override
  String get featuredTVShows => 'Chương trình TV nổi bật';

  @override
  String get lastVideosTVShows => 'Chương trình TV mới nhất';

  @override
  String get downloads => 'Tải xuống';

  @override
  String get bookmarks => 'Đã lưu';

  @override
  String get noDownloadsYet => 'Chưa có nội dung tải xuống';

  @override
  String episodesCount(int count, int done) {
    return '$count Tập • Đã xem $done';
  }

  @override
  String get deleteAllEpisodes => 'Xóa tất cả các tập';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return 'Bạn có chắc chắn muốn xóa toàn bộ $count tập của \"$title\" và các tệp đính kèm không?';
  }

  @override
  String get deleteAll => 'Xóa tất cả';

  @override
  String get completed => 'Hoàn thành';

  @override
  String get statusQueued => 'Đang chờ hàng đợi...';

  @override
  String get statusDownloading => 'Đang tải xuống...';

  @override
  String get statusFinished => 'Đã xong';

  @override
  String get statusFailed => 'Thất bại';

  @override
  String get statusCanceled => 'Đã hủy';

  @override
  String get statusPaused => 'Đã tạm dừng';

  @override
  String get statusWaiting => 'Đang chờ...';

  @override
  String get fileNotFoundRemoving => 'Không tìm thấy tệp. Đang xóa bản ghi.';

  @override
  String get fileNotFound => 'Không tìm thấy tệp';

  @override
  String get deleteDownload => 'Xóa tải xuống';

  @override
  String get confirmDeleteDownload => 'Bạn có chắc muốn xóa tệp tải xuống này?';

  @override
  String get libraryEmpty => 'Thư viện của bạn đang trống';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get english => 'Tiếng Anh';

  @override
  String get hindi => 'Tiếng Hindi';

  @override
  String get kannada => 'Tiếng Kannada';

  @override
  String get unknown => 'Không xác định';

  @override
  String get recommended => 'Được đề xuất';

  @override
  String get on => 'Bật';

  @override
  String get off => 'Tắt';

  @override
  String get installRemoveProviders => 'Cài đặt hoặc xóa nguồn cung cấp';

  @override
  String get resetDataSubtitle => 'Xóa cài đặt & dữ liệu, giữ lại plugin';

  @override
  String get factoryResetSubtitle => 'Xóa toàn bộ dữ liệu, cài đặt và tiện ích';

  @override
  String get developerOptionsSubtitle => 'Công cụ gỡ lỗi & phát nội bộ';

  @override
  String get loading => 'Đang tải...';

  @override
  String get sec => 'giây';

  @override
  String get min => 'phút';

  @override
  String get internalPlayer => 'Trình phát nội bộ (VLC)';

  @override
  String get builtInPlayer => 'Trình phát tích hợp';

  @override
  String get customNotSet => 'Tùy chỉnh (chưa đặt)';

  @override
  String selectGesture(String side) {
    return 'Chọn cử chỉ bên $side';
  }

  @override
  String get left => 'trái';

  @override
  String get right => 'phải';

  @override
  String get selectSeekDuration => 'Chọn thời gian tua';

  @override
  String get selectBufferDepth => 'Chọn độ sâu bộ đệm';

  @override
  String get subtitleSettings => 'Cài đặt phụ đề';

  @override
  String size(int size) {
    return 'Kích thước: $size';
  }

  @override
  String get background => 'Nền';

  @override
  String get customDohUrlLabel => 'URL DoH tùy chỉnh';

  @override
  String get enterCustomDohUrl => 'Nhập URL DoH của riêng bạn';

  @override
  String get chooseTheme => 'Chọn chủ đề';

  @override
  String get resetDataDialogTitle => 'Xóa dữ liệu?';

  @override
  String get resetDataDialogContent =>
      'Thao tác này sẽ xóa các Cài đặt, Mục yêu thích và Lịch sử. Các Tiện ích đã cài đặt sẽ KHÔNG bị xóa.';

  @override
  String get factoryResetDialogTitle => 'Khôi phục cài đặt gốc?';

  @override
  String get factoryResetDialogContent =>
      'Thao tác này sẽ xóa TẤT CẢ: Mục yêu thích, Lịch sử, Cài đặt và toàn bộ Tiện ích. Thao tác này không thể hoàn tác.';

  @override
  String get selectLanguage => 'Chọn ngôn ngữ';

  @override
  String get synopsis => 'Nội dung tóm tắt';

  @override
  String get noDescription => 'Không có mô tả.';

  @override
  String get videoAlreadyDownloadedPrompt =>
      'Video này đã được tải xuống. Bạn muốn làm gì?';

  @override
  String get playNow => 'Phát ngay';

  @override
  String get upNext => 'Tiếp theo';

  @override
  String get deleteDownloadPrompt => 'Xóa tải xuống?';

  @override
  String get deleteDownloadConfirmation =>
      'Bạn có chắc muốn xóa tệp này không? Thao tác này không thể hoàn tác.';

  @override
  String get no => 'Không';

  @override
  String get yesDelete => 'Có, xóa ngay';

  @override
  String get downloadPaused => 'Đã tạm dừng tải xuống';

  @override
  String get downloading => 'Đang tải xuống';

  @override
  String get speed => 'Tốc độ';

  @override
  String get remaining => 'Còn lại';

  @override
  String get resume => 'Tiếp tục';

  @override
  String get pause => 'Tạm dừng';

  @override
  String get torrentContent => 'Nội dung Torrent';

  @override
  String get audioTracks => 'Kênh âm thanh';

  @override
  String get noAudioTracks => 'Không tìm thấy kênh âm thanh nào';

  @override
  String get subtitles => 'Phụ đề';

  @override
  String get options => 'Tùy chọn';

  @override
  String get noSubtitlesFound => 'Không tìm thấy phụ đề nào';

  @override
  String get playbackSpeed => 'Tốc độ phát';

  @override
  String get subtitleOptions => 'Tùy chọn phụ đề';

  @override
  String get hlsSubtitleWarning =>
      'Phụ đề ngoài không được hỗ trợ cho HLS trên nền tảng này.';

  @override
  String get loadFromDevice => 'Tải từ thiết bị';

  @override
  String get syncDelay => 'Đồng bộ / Độ trễ';

  @override
  String get styleSettings => 'Cài đặt kiểu dáng';

  @override
  String get searchOnline => 'Tìm kiếm trực tuyến (Tìm phụ đề)';

  @override
  String get subtitleSync => 'Đồng bộ phụ đề';

  @override
  String get subtitleDelayWarning =>
      'Độ trễ phụ đề không được hỗ trợ bởi trình phát hiện tại.';

  @override
  String get resetDelay => 'Đặt lại độ trễ';

  @override
  String get subtitleStyles => 'Kiểu phụ đề';

  @override
  String get resetToDefault => 'Đặt về mặc định';

  @override
  String get fontSize => 'Cỡ chữ';

  @override
  String get verticalPosition => 'Vị trí dọc';

  @override
  String get textColor => 'Màu chữ';

  @override
  String get backgroundColor => 'Màu nền';

  @override
  String get backgroundOpacity => 'Độ mờ của nền';

  @override
  String get subtitleSearch => 'Tìm kiếm phụ đề';

  @override
  String get searchSubtitleNameHint => 'Tên phụ đề...';

  @override
  String get enterSearchSubtitlePrompt => 'Nhập tên để tìm kiếm phụ đề.';

  @override
  String get noSubtitleResults => 'Không tìm thấy kết quả.';

  @override
  String get downloadingApplyingSubtitle => 'Đang tải và áp dụng phụ đề...';

  @override
  String get failedToDownloadSubtitle => 'Không thể tải phụ đề.';

  @override
  String get failedToLoadSubtitles => 'Không thể tải phụ đề. Vui lòng thử lại.';

  @override
  String get noReposFound => 'Không tìm thấy kho lưu trữ hoặc plugin nào';

  @override
  String get downloadAllProviders => 'Tải xuống tất cả';

  @override
  String get removeRepository => 'Xóa kho lưu trữ';

  @override
  String get addRepo => 'Thêm kho lưu trữ';

  @override
  String get extensionsNotInRepos => 'Tiện ích không nằm trong kho';

  @override
  String get noLongerInRepo => 'Không còn được liệt kê trong kho';

  @override
  String get addRepoToBrowse => 'Thêm kho lưu trữ để duyệt và cập nhật plugin';

  @override
  String get debugExtensions => 'Gỡ lỗi tiện ích';

  @override
  String removeRepoConfirm(String repoName) {
    return 'Xóa $repoName?';
  }

  @override
  String get removeRepoWarning =>
      'Thao tác này sẽ xóa kho lưu trữ và gỡ cài đặt TẤT CẢ các plugin trong đó.';

  @override
  String get addRepository => 'Thêm kho lưu trữ';

  @override
  String get repoUrlOrShortcode => 'URL kho lưu trữ hoặc Mã ngắn';

  @override
  String get assetPlugin => 'Plugin tích hợp';

  @override
  String get installed => 'Đã cài đặt';

  @override
  String get repositories => 'Kho lưu trữ';

  @override
  String get noExtensionsInstalled => 'Chưa cài tiện ích mở rộng nào';

  @override
  String get browseRepositoriesToInstall =>
      'Mở tab Kho lưu trữ để tìm và cài đặt tiện ích mở rộng.';

  @override
  String get browseRepositories => 'Duyệt kho lưu trữ';

  @override
  String get addRepoDescription =>
      'Thêm URL kho lưu trữ hoặc mã rút gọn để tìm và cài đặt plugin mở rộng.';

  @override
  String updateTo(String version) {
    return 'Cập nhật lên $version';
  }

  @override
  String get install => 'Cài đặt';

  @override
  String get error => 'Lỗi';

  @override
  String get ok => 'Xác nhận';

  @override
  String pluginSettings(String pluginName) {
    return 'Cài đặt cho $pluginName';
  }

  @override
  String get movies => 'Phim điện ảnh';

  @override
  String get series => 'Phim bộ';

  @override
  String get anime => 'Anime';

  @override
  String get liveStreams => 'Truyền hình trực tiếp';

  @override
  String get debug => 'GỠ LỖI';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đã cập nhật $count tiện ích mở rộng',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => 'Lối điều hướng không hợp lệ.';

  @override
  String get startOver => 'Bắt đầu lại';

  @override
  String get goBack => 'Quay lại';

  @override
  String get resolving => 'Đang giải quyết...';

  @override
  String get downloaded => 'Đã tải';

  @override
  String get download => 'Tải xuống';

  @override
  String get debugOnlyFeature => 'Tính năng này chỉ dành cho bản build gỡ lỗi';

  @override
  String get streamUrl => 'URL luồng';

  @override
  String get play => 'Phát';

  @override
  String get verifyingSourceSize => 'Đang xác minh nguồn & kích thước...';

  @override
  String get fileSaveLocationNotification =>
      'Tệp sẽ được lưu vào thư mục Tải xuống.';

  @override
  String get resumingPlayback => 'Đang tiếp tục phát';

  @override
  String pausedAt(String time) {
    return 'Tạm dừng tại $time';
  }

  @override
  String resumesAutomatically(int count) {
    return 'Tự động phát lại sau $count giây';
  }

  @override
  String get resumeNow => 'Phát ngay';

  @override
  String get playbackError => 'Lỗi phát nội dung';

  @override
  String get confirmClearHistory =>
      'Bạn có chắc muốn xóa toàn bộ lịch sử xem không?';

  @override
  String seasonWithNumber(Object number) {
    return 'Mùa $number';
  }

  @override
  String get starting => 'Đang khởi động...';

  @override
  String percentWatched(int percent) {
    return 'Đã xem $percent%';
  }

  @override
  String get sub => 'Phụ đề';

  @override
  String get dub => 'Lồng tiếng';

  @override
  String playEpisode(String label, Object season, Object episode) {
    return '$label M$season T$episode';
  }

  @override
  String playEpisodeOnly(String label, int episode) {
    return '$label E$episode';
  }

  @override
  String get debugTools => 'Công cụ gỡ lỗi';

  @override
  String get playLocalVideo => 'Phát video cục bộ';

  @override
  String get playLocalVideoSubtitle => 'Phát bất kỳ video nào từ thiết bị';

  @override
  String get streamUrlSubtitle => 'Phát từ URL mạng';

  @override
  String get streamTorrent => 'Phát torrent';

  @override
  String get streamTorrentSubtitle => 'Chọn tệp torrent cục bộ để phát';

  @override
  String get loadPluginFromAssets => 'Tải plugin từ tài nguyên';

  @override
  String get enterVideoUrlHint => 'Nhập URL video (http, magnet, v.v.)';

  @override
  String get networkStream => 'Luồng mạng';

  @override
  String removedFromHistory(String title) {
    return 'Đã xóa $title khỏi lịch sử';
  }

  @override
  String get custom => 'Tùy chỉnh';

  @override
  String get refreshingLiveStream => 'Đang làm mới luồng...';

  @override
  String get removeFromHistory => 'Xóa khỏi lịch sử';

  @override
  String get live => 'TRỰC TIẾP';

  @override
  String get volume => 'Âm lượng';

  @override
  String get brightness => 'Độ sáng';

  @override
  String get fit => 'Vừa vặn';

  @override
  String get zoom => 'Thu phóng';

  @override
  String get stretch => 'Kéo giãn';

  @override
  String titleWithParam(String title) {
    return 'Tiêu đề: $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'Nguồn: $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'Dung lượng: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'Lỗi: $error. Đang sử dụng trình phát nội bộ.';
  }

  @override
  String playerNotDetected(String playerName) {
    return 'Không tìm thấy $playerName. Đang khởi động trình phát nội bộ.';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return 'Mùa $number ($count tập)';
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
    return 'Chọn nguồn cho $playerName';
  }

  @override
  String get noPluginsInstalled => 'Chưa cài đặt plugin nào';

  @override
  String get noPluginsMessage =>
      'Cài đặt các tiện ích mở rộng để duyệt và phát trực tuyến nội dung.';

  @override
  String get goToExtensions => 'Đi tới các tiện ích mở rộng';

  @override
  String get availableSources => 'Nguồn khả dụng';

  @override
  String get seasons => 'Mùa';

  @override
  String get episodes => 'Tập';

  @override
  String get selectSourceToPlay =>
      'Vui lòng chọn một nguồn để phát từ danh sách trên.';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tập',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'Không tìm thấy tập nào';

  @override
  String get local => 'Nội bộ';

  @override
  String get remote => 'Từ xa';

  @override
  String get torrent => 'Torrent';

  @override
  String get unlock => 'Mở khóa';

  @override
  String get lock => 'Khóa';

  @override
  String get sources => 'Nguồn';

  @override
  String get tracks => 'Kênh';

  @override
  String get content => 'Nội dung';

  @override
  String get stats => 'Thống kê';

  @override
  String get resize => 'Thay đổi kích thước';

  @override
  String get next => 'Tiếp theo';

  @override
  String get pip => 'PiP';

  @override
  String get rotate => 'Xoay';

  @override
  String get windowed => 'Cửa sổ';

  @override
  String get fullscreen => 'Toàn màn hình';

  @override
  String get movieDetails => 'Chi tiết phim';

  @override
  String get showDetails => 'Hiển thị chi tiết';

  @override
  String get tagline => 'Khẩu hiệu';

  @override
  String get status => 'Trạng thái';

  @override
  String get releaseDate => 'Ngày phát hành';

  @override
  String get firstAirDate => 'Ngày phát sóng đầu tiên';

  @override
  String get originalLanguage => 'Ngôn ngữ gốc';

  @override
  String get originCountry => 'Quốc gia gốc';

  @override
  String get budgetLabel => 'Ngân sách';

  @override
  String get revenueLabel => 'Doanh thu';

  @override
  String get paused => 'Đã tạm dừng';

  @override
  String get watched => 'Đã xem';

  @override
  String get watching => 'Đang xem';

  @override
  String get lastWatched => 'Xem lần cuối';

  @override
  String get movie => 'Phim điện ảnh';

  @override
  String get tvShow => 'Chương trình TV';

  @override
  String get failedToLoadContent => 'Tải nội dung thất bại';

  @override
  String get director => 'Đạo diễn';

  @override
  String get creator => 'Người sáng tạo';

  @override
  String get showMore => 'Xem thêm';

  @override
  String get showLess => 'Thu gọn';

  @override
  String get viewAll => 'Xem tất cả';

  @override
  String seasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mùa',
    );
    return '$_temp0';
  }

  @override
  String get noInternetError => 'Không có Internet';

  @override
  String get timeoutError => 'Hết thời gian yêu cầu. Vui lòng thử lại.';

  @override
  String get serverError => 'Lỗi máy chủ. Vui lòng thử lại sau.';

  @override
  String get contentNotFoundError => 'Không tìm thấy nội dung.';

  @override
  String get accessDeniedError => 'Truy cập bị từ chối.';

  @override
  String get serviceUnavailableError => 'Máy chủ hiện không khả dụng.';

  @override
  String get generalError => 'Đã xảy ra lỗi.';

  @override
  String get skip => 'Bỏ qua';

  @override
  String get skipIntro => 'Bỏ qua giới thiệu';

  @override
  String get skipOutro => 'Bỏ qua kết thúc';

  @override
  String get skipRecap => 'Bỏ qua tóm tắt';

  @override
  String get goLive => 'Xem trực tiếp';

  @override
  String get dismiss => 'Bỏ qua';

  @override
  String get nextUp => 'Tiếp theo';

  @override
  String sourceAttempt(int index, int total) {
    return 'Nguồn $index trên $total';
  }

  @override
  String get trying => 'Đang thử';

  @override
  String get failed => 'Thất bại';

  @override
  String get selected => 'Đã chọn';

  @override
  String get playing => 'Đang phát';

  @override
  String get pending => 'Đang chờ';

  @override
  String get openSubtitles => 'OpenSubtitles';

  @override
  String get subDl => 'SubDL';

  @override
  String get subSource => 'SubSource';

  @override
  String get wifiQualityPreference => 'Ưu tiên chất lượng Wi-Fi';

  @override
  String get mobileQualityPreference => 'Ưu tiên chất lượng di động';

  @override
  String get anyNoPreference => 'Bất kỳ (không ưu tiên)';

  @override
  String get subtitleAccounts => 'Tài khoản phụ đề';

  @override
  String get accounts => 'Tài khoản';

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
  String get testConnection => 'Kiểm tra kết nối';

  @override
  String get connectedSuccessfully => 'Kết nối thành công';

  @override
  String get connectionFailed => 'Kết nối thất bại';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get noAccountRegister => 'Don\'t have an account? Register here';

  @override
  String get apiKey => 'Mã API';

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
  String get diagnostics => 'Chẩn đoán';

  @override
  String get viewLogs => 'Xem nhật ký';

  @override
  String get viewLogsSubtitle => 'Xem hoạt động và lỗi ứng dụng';

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
