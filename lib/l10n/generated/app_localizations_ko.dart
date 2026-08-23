// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => '한국어';

  @override
  String get home => '홈';

  @override
  String get search => '검색';

  @override
  String get explore => '탐색';

  @override
  String get exploreAnime => '애니메이션 탐색';

  @override
  String get exploreMovies => '영화 탐색';

  @override
  String get library => '라이브러리';

  @override
  String get settings => '설정';

  @override
  String get extensions => '확장 프로그램';

  @override
  String get updateAvailable => '업데이트 가능';

  @override
  String get retry => '재시도';

  @override
  String get factoryReset => '공장 초기화';

  @override
  String get startupError => '시작 오류';

  @override
  String get general => '일반';

  @override
  String get appTheme => '앱 테마';

  @override
  String get recordWatchHistory => '시청 기록 남기기';

  @override
  String get defaultHomeScreen => '기본 홈 화면';

  @override
  String get titlePosition => '제목 위치';

  @override
  String get titlePositionBelowPoster => '포스터 아래';

  @override
  String get titlePositionInsidePoster => '포스터 안';

  @override
  String get player => '플레이어';

  @override
  String get defaultPlayer => '기본 플레이어';

  @override
  String get leftGesture => '왼쪽 제스처';

  @override
  String get rightGesture => '오른쪽 제스처';

  @override
  String get doubleTapToSeek => '더블 탭하여 탐색';

  @override
  String get swipeToSeek => '스와이프하여 탐색';

  @override
  String get seekDuration => '탐색 시간';

  @override
  String get bufferDepth => '버퍼 깊이';

  @override
  String get defaultResizeMode => '기본 화면 크기 모드';

  @override
  String get hardwareDecoding => '하드웨어 디코딩';

  @override
  String get network => '네트워크';

  @override
  String get dnsOverHttps => 'DNS over HTTPS';

  @override
  String get dohProvider => 'DoH 제공자';

  @override
  String get githubProxy => 'GitHub 프록시';

  @override
  String get githubProxySubtitle =>
      'ISP 차단을 우회하도록 확장 프로그램 다운로드를 jsDelivr로 우회합니다.';

  @override
  String get manageExtensions => '확장 프로그램 관리';

  @override
  String get appData => '앱 데이터';

  @override
  String get resetDataKeepExtensions => '데이터 초기화 (확장 프로그램 유지)';

  @override
  String get developer => '개발자';

  @override
  String get developerOptions => '개발자 옵션';

  @override
  String get about => '정보';

  @override
  String get version => '버전';

  @override
  String get enabled => '활성화됨';

  @override
  String get disabled => '비활성화됨';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => '우리 서버에 참여하세요';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => '우리 채널에 참여하세요';

  @override
  String developedBy(String name) {
    return '$name 개발';
  }

  @override
  String get system => '시스템 설정';

  @override
  String get dark => '다크 모드';

  @override
  String get light => '라이트 모드';

  @override
  String get later => '나중에';

  @override
  String get updateNow => '지금 업데이트';

  @override
  String get save => '저장';

  @override
  String get cancel => '취소';

  @override
  String get close => '닫기';

  @override
  String get delete => '삭제';

  @override
  String get viewDetails => '상세 보기';

  @override
  String get clearAll => '모두 지우기';

  @override
  String get clearAllHistory => '시청 기록 지우기';

  @override
  String get all => '전체';

  @override
  String get none => '없음';

  @override
  String get confirmDownload => '다운로드 확인';

  @override
  String get downloadNow => '지금 다운로드';

  @override
  String get selectSource => '소스 선택';

  @override
  String get downloadUnavailable => '이용 불가';

  @override
  String get selectAnotherSource => '다른 소스 선택';

  @override
  String get watchHistoryCleared => '시청 기록이 삭제되었습니다';

  @override
  String get downloadingUpdate => '업데이트 다운로드 중...';

  @override
  String errorPrefix(String message) {
    return '오류: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return '업데이트 가능: $tag';
  }

  @override
  String get selectProviderToStart => '시작하려면 제공자를 선택하세요';

  @override
  String get tapExtensionIcon => '모퉁이에 있는 확장 프로그램 아이콘을 탭하세요';

  @override
  String get continueWatching => '계속 시청하기';

  @override
  String get noInternetConnection => '인터넷 연결 없음';

  @override
  String get siteNotReachable => '사이트에 연결할 수 없음';

  @override
  String get checkConnectionOrDownloads => '연결 상태를 확인하거나 다운로드 목록을 확인하세요.';

  @override
  String get tryVpnOrConnection => 'VPN을 시도하거나 인터넷 연결을 확인하세요.';

  @override
  String errorDetails(String error) {
    return '오류 상세 정보: $error';
  }

  @override
  String get goToDownloads => '다운로드로 이동';

  @override
  String get selectProvider => '제공자 선택';

  @override
  String get searchHint => '영화, 드라마 검색...';

  @override
  String get searchFavoriteContent => '좋아하는 콘텐츠를 검색하세요';

  @override
  String get pressSearchOrEnter => '검색 키 또는 Enter를 눌러 시작하세요';

  @override
  String get noResultsFound => '결과를 찾을 수 없습니다.';

  @override
  String get couldNotLoadTrending => '트렌드를 불러올 수 없습니다';

  @override
  String get popularMovies => '인기 영화';

  @override
  String get popularTVShows => '인기 드라마';

  @override
  String get newMovies => '최신 영화';

  @override
  String get newTVShows => '최신 드라마';

  @override
  String get featuredMovies => '추천 영화';

  @override
  String get featuredTVShows => '추천 드라마';

  @override
  String get lastVideosTVShows => '최근 업데이트';

  @override
  String get downloads => '다운로드';

  @override
  String get bookmarks => '즐겨찾기';

  @override
  String get noDownloadsYet => '다운로드한 콘텐츠가 없습니다';

  @override
  String episodesCount(int count, int done) {
    return '$count개의 에피소드 • $done개 완료';
  }

  @override
  String get deleteAllEpisodes => '모든 에피소드 삭제';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return '\"$title\"의 모든 에피소드($count개)와 파일을 삭제하시겠습니까?';
  }

  @override
  String get deleteAll => '모두 삭제';

  @override
  String get completed => '완료됨';

  @override
  String get statusQueued => '대기 중...';

  @override
  String get statusDownloading => '다운로드 중...';

  @override
  String get statusFinished => '완료';

  @override
  String get statusFailed => '실패';

  @override
  String get statusCanceled => '취소됨';

  @override
  String get statusPaused => '일시 중지됨';

  @override
  String get statusWaiting => '대기 중...';

  @override
  String get fileNotFoundRemoving => '파일을 찾을 수 없습니다. 기록을 제거합니다.';

  @override
  String get fileNotFound => '파일을 찾을 수 없음';

  @override
  String get deleteDownload => '다운로드 삭제';

  @override
  String get confirmDeleteDownload => '이 다운로드와 파일을 삭제하시겠습니까?';

  @override
  String get libraryEmpty => '라이브러리가 비어 있습니다';

  @override
  String get language => '언어';

  @override
  String get english => '영어';

  @override
  String get hindi => '힌디어';

  @override
  String get kannada => '칸나다어';

  @override
  String get unknown => '알 수 없음';

  @override
  String get recommended => '추천';

  @override
  String get on => '켜짐';

  @override
  String get off => '꺼짐';

  @override
  String get installRemoveProviders => '제공자 설치/제거';

  @override
  String get resetDataSubtitle => '설정 및 데이터베이스를 초기화합니다 (플러그인 유지)';

  @override
  String get factoryResetSubtitle => '모든 데이터, 설정, 확장 프로그램을 삭제합니다';

  @override
  String get developerOptionsSubtitle => '디버그 도구 및 로컬 재생';

  @override
  String get loading => '로딩 중...';

  @override
  String get sec => '초';

  @override
  String get min => '분';

  @override
  String get internalPlayer => '내부 플레이어 (media_kit)';

  @override
  String get builtInPlayer => '내장 플레이어';

  @override
  String get customNotSet => '사용자 정의 (설정되지 않음)';

  @override
  String selectGesture(String side) {
    return '$side 제스처 선택';
  }

  @override
  String get left => '왼쪽';

  @override
  String get right => '오른쪽';

  @override
  String get selectSeekDuration => '탐색 시간 선택';

  @override
  String get selectBufferDepth => '버퍼 깊이 선택';

  @override
  String get subtitleSettings => '자막 설정';

  @override
  String size(int size) {
    return '크기: $size';
  }

  @override
  String get background => '배경';

  @override
  String get customDohUrlLabel => '사용자 정의 DoH URL';

  @override
  String get enterCustomDohUrl => '자체 DoH URL을 입력하세요';

  @override
  String get chooseTheme => '테마 선택';

  @override
  String get resetDataDialogTitle => '데이터 초기화?';

  @override
  String get resetDataDialogContent =>
      '설정, 즐겨찾기, 시청 기록이 지워집니다. 설치된 확장 프로그램은 유지됩니다.';

  @override
  String get factoryResetDialogTitle => '공장 초기화?';

  @override
  String get factoryResetDialogContent =>
      '즐겨찾기, 기록, 설정, 모든 확장 프로그램을 포함한 모든 데이터가 삭제됩니다. 이 작업은 되돌릴 수 없습니다.';

  @override
  String get selectLanguage => '언어 선택';

  @override
  String get synopsis => '시놉시스';

  @override
  String get noDescription => '설명이 없습니다.';

  @override
  String get videoAlreadyDownloadedPrompt => '이 영상은 이미 다운로드되었습니다. 어떻게 하시겠습니까?';

  @override
  String get playNow => '지금 재생하기';

  @override
  String get upNext => '다음 화';

  @override
  String get deleteDownloadPrompt => '다운로드 삭제?';

  @override
  String get deleteDownloadConfirmation => '이 파일을 삭제하시겠습니까? 되돌릴 수 없습니다.';

  @override
  String get no => '아니요';

  @override
  String get yesDelete => '네, 삭제합니다';

  @override
  String get downloadPaused => '다운로드 일시 중지됨';

  @override
  String get downloading => '다운로드 중';

  @override
  String get speed => '속도';

  @override
  String get remaining => '남음';

  @override
  String get resume => '재개';

  @override
  String get pause => '일시 중지';

  @override
  String get torrentContent => '토렌트 내용';

  @override
  String get audioTracks => '오디오 트랙';

  @override
  String get noAudioTracks => '오디오 트랙을 찾을 수 없습니다';

  @override
  String get subtitles => '자막';

  @override
  String get options => '옵션';

  @override
  String get noSubtitlesFound => '자막을 찾을 수 없습니다';

  @override
  String get playbackSpeed => '재생 속도';

  @override
  String get subtitleOptions => '자막 옵션';

  @override
  String get hlsSubtitleWarning => '이 플랫폼의 HLS 플레이어에서는 외부 자막 파일을 지원하지 않습니다.';

  @override
  String get loadFromDevice => '기기에서 불러오기';

  @override
  String get syncDelay => '동기화 / 지연';

  @override
  String get styleSettings => '스타일 설정';

  @override
  String get searchOnline => '온라인 검색 (자막 검색)';

  @override
  String get subtitleSync => '자막 동기화';

  @override
  String get subtitleDelayWarning => '현재 플레이어 엔진이 자막 지연 설정을 지원하지 않습니다.';

  @override
  String get resetDelay => '지연 초기화';

  @override
  String get subtitleStyles => '자막 스타일';

  @override
  String get mediaKitStylingWarning => '자막 스타일 설정은 현재 media_kit 플레이어에서만 가능합니다.';

  @override
  String get resetToDefault => '기본값으로 복원';

  @override
  String get fontSize => '글자 크기';

  @override
  String get verticalPosition => '수직 위치';

  @override
  String get textColor => '글자 색상';

  @override
  String get backgroundColor => '배경 색상';

  @override
  String get backgroundOpacity => '배경 불투명도';

  @override
  String get subtitleSearch => '자막 검색';

  @override
  String get searchSubtitleNameHint => '자막 이름...';

  @override
  String get enterSearchSubtitlePrompt => '검색할 자막 이름을 입력하세요.';

  @override
  String get noSubtitleResults => '결과가 없습니다. 다른 검색어를 입력해 보세요.';

  @override
  String get downloadingApplyingSubtitle => '자막 다운로드 및 적용 중...';

  @override
  String get failedToDownloadSubtitle => '자막 다운로드 실패.';

  @override
  String get failedToLoadSubtitles => '자막 불러오기 실패. 다시 시도해 주세요.';

  @override
  String get noReposFound => '저장소나 플러그인을 찾을 수 없습니다';

  @override
  String get downloadAllProviders => '모두 다운로드';

  @override
  String get removeRepository => '저장소 제거';

  @override
  String get addRepo => '저장소 추가';

  @override
  String get extensionsNotInRepos => '저장소 외부의 확장 프로그램';

  @override
  String get noLongerInRepo => '더 이상 저장소 목록에 없음';

  @override
  String get addRepoToBrowse => '플러그인을 탐색하고 업데이트하려면 저장소를 추가하세요';

  @override
  String get debugExtensions => '확장 프로그램 디버그';

  @override
  String removeRepoConfirm(String repoName) {
    return '$repoName 저장소를 제거하시겠습니까?';
  }

  @override
  String get removeRepoWarning => '저장소가 제거되고 포함된 모든 플러그인이 삭제됩니다.';

  @override
  String get addRepository => '저장소 추가';

  @override
  String get repoUrlOrShortcode => '저장소 URL 또는 단축 코드';

  @override
  String get assetPlugin => '에셋 플러그인';

  @override
  String get installed => '설치됨';

  @override
  String get repositories => '저장소';

  @override
  String get noExtensionsInstalled => '설치된 확장 프로그램 없음';

  @override
  String get browseRepositoriesToInstall => '저장소 탭에서 확장 프로그램을 찾아 설치하세요.';

  @override
  String get browseRepositories => '저장소 둘러보기';

  @override
  String get addRepoDescription => '저장소 URL 또는 단축 코드를 추가해 확장 플러그인을 찾아 설치하세요.';

  @override
  String updateTo(String version) {
    return '$version 버전으로 업데이트';
  }

  @override
  String get install => '설치';

  @override
  String get error => '오류';

  @override
  String get ok => '확인';

  @override
  String pluginSettings(String pluginName) {
    return '$pluginName 설정';
  }

  @override
  String get movies => '영화';

  @override
  String get series => '드라마/시리즈';

  @override
  String get anime => '애니메이션';

  @override
  String get liveStreams => '실시간 스트리밍';

  @override
  String get debug => '디버그';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개의 확장 프로그램이 업데이트되었습니다',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => '잘못된 경로입니다. 뒤로 돌아가 주세요.';

  @override
  String get startOver => '처음부터 다시 시작';

  @override
  String get goBack => '뒤로 가기';

  @override
  String get resolving => '해석 중...';

  @override
  String get downloaded => '다운로드됨';

  @override
  String get download => '다운로드';

  @override
  String get debugOnlyFeature => '이 기능은 디버그 빌드에서만 사용할 수 있습니다';

  @override
  String get streamUrl => '스트림 URL';

  @override
  String get play => '재생';

  @override
  String get verifyingSourceSize => '소스 및 크기 확인 중...';

  @override
  String get fileSaveLocationNotification => '파일은 다운로드 폴더에 저장됩니다.';

  @override
  String get resumingPlayback => '이어서 재생 중';

  @override
  String pausedAt(String time) {
    return '$time에서 일시 중지됨';
  }

  @override
  String resumesAutomatically(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count초 후에 자동으로 재개됩니다',
    );
    return '$_temp0';
  }

  @override
  String get resumeNow => '지금 재개';

  @override
  String get playbackError => '재생 오류';

  @override
  String get confirmClearHistory => '모든 시청 기록을 삭제하시겠습니까?';

  @override
  String seasonWithNumber(Object number) {
    return '시즌 $number';
  }

  @override
  String get starting => '시작 중...';

  @override
  String percentWatched(int percent) {
    return '$percent% 시청함';
  }

  @override
  String get sub => '자막';

  @override
  String get dub => '더빙';

  @override
  String playEpisode(String label, Object season, Object episode) {
    return '$label S$season E$episode';
  }

  @override
  String playEpisodeOnly(String label, int episode) {
    return '$label E$episode';
  }

  @override
  String get debugTools => '디버그 도구';

  @override
  String get playLocalVideo => '로컬 비디오 재생';

  @override
  String get playLocalVideoSubtitle => '기기 내 파일 재생';

  @override
  String get streamUrlSubtitle => 'URL 입력하여 재생';

  @override
  String get streamTorrent => '토렌트 스트리밍';

  @override
  String get streamTorrentSubtitle => '토렌트 파일을 선택하여 재생';

  @override
  String get loadPluginFromAssets => '에셋에서 플러그인 로드';

  @override
  String get enterVideoUrlHint => '비디오 주소 입력 (http, magnet 등)';

  @override
  String get networkStream => '네트워크 스트림';

  @override
  String removedFromHistory(String title) {
    return '기록에서 \"$title\" 삭제됨';
  }

  @override
  String get custom => '사용자 정의';

  @override
  String get refreshingLiveStream => '실시간 스트림 새로고침 중...';

  @override
  String get removeFromHistory => '기록에서 삭제';

  @override
  String get live => '실시간';

  @override
  String get volume => '음량';

  @override
  String get brightness => '밝기';

  @override
  String get fit => '맞추기';

  @override
  String get zoom => '확대';

  @override
  String get stretch => '늘리기';

  @override
  String titleWithParam(String title) {
    return '제목: $title';
  }

  @override
  String sourceWithParam(String source) {
    return '소스: $source';
  }

  @override
  String sizeWithParam(String size) {
    return '크기: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return '오류: $error. 내부 플레이어를 사용합니다.';
  }

  @override
  String playerNotDetected(String playerName) {
    return '$playerName을(를) 찾을 수 없습니다. 내부 플레이어를 실행합니다.';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return '시즌 $number ($count개의 에피소드)';
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
    return '$playerName의 소스 선택';
  }

  @override
  String get noPluginsInstalled => '설치된 플러그인 없음';

  @override
  String get noPluginsMessage => '콘텐츠를 탐색하고 스트리밍하려면 확장 프로그램을 설치하세요.';

  @override
  String get goToExtensions => '확장 프로그램으로 이동';

  @override
  String get availableSources => '이용 가능한 소스';

  @override
  String get seasons => '시즌';

  @override
  String get episodes => '에피소드';

  @override
  String get selectSourceToPlay => '위에 이용 가능한 소스 중에서 시청할 곳을 선택하세요.';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개의 에피소드',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => '에피소드를 찾을 수 없습니다';

  @override
  String get local => '로컬';

  @override
  String get remote => '원격';

  @override
  String get torrent => '토렌트';

  @override
  String get unlock => '잠금 해제';

  @override
  String get lock => '잠금';

  @override
  String get sources => '소스';

  @override
  String get tracks => '트랙';

  @override
  String get content => '내용';

  @override
  String get stats => '통계';

  @override
  String get resize => '크기 조절';

  @override
  String get next => '다음';

  @override
  String get pip => 'PiP 모드';

  @override
  String get rotate => '회전';

  @override
  String get windowed => '창 모드';

  @override
  String get fullscreen => '전체 화면';

  @override
  String get movieDetails => '영화 정보';

  @override
  String get showDetails => '상세 정보';

  @override
  String get tagline => '태그라인';

  @override
  String get status => '상태';

  @override
  String get releaseDate => '개봉일';

  @override
  String get firstAirDate => '첫 방영일';

  @override
  String get originalLanguage => '원어';

  @override
  String get originCountry => '제작 국가';

  @override
  String get budgetLabel => '예산';

  @override
  String get revenueLabel => '수익';

  @override
  String get paused => '일시 정지';

  @override
  String get watched => '시청 완료';

  @override
  String get watching => '시청 중';

  @override
  String get lastWatched => '마지막 시청';

  @override
  String get movie => '영화';

  @override
  String get tvShow => '드라마';

  @override
  String get failedToLoadContent => '콘텐츠를 불러오지 못했습니다';

  @override
  String get director => '감독';

  @override
  String get creator => '제작자';

  @override
  String get showMore => '더 보기';

  @override
  String get showLess => '접기';

  @override
  String get viewAll => '전체 보기';

  @override
  String seasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개의 시즌',
    );
    return '$_temp0';
  }

  @override
  String get noInternetError => '인터넷 연결 끊김';

  @override
  String get timeoutError => '시간이 초과되었습니다. 다시 시도해 주세요.';

  @override
  String get serverError => '서버 오류. 나중에 다시 시도해 주세요.';

  @override
  String get contentNotFoundError => '찾을 수 없습니다.';

  @override
  String get accessDeniedError => '접근 권한이 없습니다.';

  @override
  String get serviceUnavailableError => '서버를 이용할 수 없습니다.';

  @override
  String get generalError => '문제가 발생했습니다.';

  @override
  String get skip => '건너뛰기';

  @override
  String get skipIntro => '오프닝 건너뛰기';

  @override
  String get skipOutro => '엔딩 건너뛰기';

  @override
  String get skipRecap => '줄거리 건너뛰기';

  @override
  String get goLive => '실시간 시청';

  @override
  String get dismiss => '닫기';

  @override
  String get nextUp => '다음 콘텐츠';

  @override
  String sourceAttempt(int index, int total) {
    return '$total개 소스 중 $index번째 시도';
  }

  @override
  String get trying => '시도 중';

  @override
  String get failed => '실패';

  @override
  String get selected => '선택됨';

  @override
  String get playing => '재생 중';

  @override
  String get pending => '대기 중';

  @override
  String get openSubtitles => 'OpenSubtitles';

  @override
  String get subDl => 'SubDL';

  @override
  String get subSource => 'SubSource';

  @override
  String get wifiQualityPreference => 'Wi-Fi 화질 설정';

  @override
  String get mobileQualityPreference => '모바일 데이터 화질 설정';

  @override
  String get anyNoPreference => '선택 안 함';

  @override
  String get subtitleAccounts => '자막 계정';

  @override
  String get accounts => '계정';

  @override
  String get notLoggedIn => '로그인되지 않음';

  @override
  String loggedInAs(String username) {
    return '$username(으)로 로그인됨';
  }

  @override
  String get apiKeyConfigured => 'API 키 설정됨';

  @override
  String get keyNotSet => '키가 설정되지 않음';

  @override
  String get testConnection => '연결 테스트';

  @override
  String get connectedSuccessfully => '연결 성공';

  @override
  String get connectionFailed => '연결 실패';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get noAccountRegister => '계정이 없으신가요? 여기서 등록하세요';

  @override
  String get apiKey => 'API 키';

  @override
  String get email => 'Email';

  @override
  String get fetchMyApiKey => '내 API 키 가져오기';

  @override
  String get keyVerified => '키 확인됨';

  @override
  String get invalidApiKey => '유효하지 않은 API 키';

  @override
  String get openSubtitlesAuthSubtitle =>
      '더 높은 제한과 광고 없는 자막을 이용하려면 계정 정보를 입력하세요.';

  @override
  String get subDlAuthSubtitle => 'SubDL API 키를 직접 입력하거나 아래 계정 정보를 사용하여 가져오세요.';

  @override
  String get orFetchViaAccount => '또는 계정을 통해 가져오기';

  @override
  String get subSourceAuthSubtitle =>
      'SubSource는 즉시 작동하지만, 더 나은 안정성을 위해 개인 API 키를 추가할 수 있습니다.';

  @override
  String get apiKeyOptionalOverride => 'API 키 (선택 사항)';

  @override
  String get enterKeyToOverrideDefault => '기본값을 무시할 키 입력';

  @override
  String get getApiKeyFromProfile => 'SubSource 프로필에서 API 키 가져오기';

  @override
  String get qualityNotGuaranteed =>
      '화질은 보장되지 않습니다. 소스는 기본 설정에 따라 정렬되지만 재생은 공급자에 따라 달라집니다.';

  @override
  String get keepSourcesOriginalOrder => '소스의 원래 순서 유지';

  @override
  String get openLink => '링크 열기';

  @override
  String get diagnostics => '진단';

  @override
  String get viewLogs => '로그 보기';

  @override
  String get viewLogsSubtitle => '앱 활동 및 오류 보기';

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
