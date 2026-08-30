// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => '简体中文';

  @override
  String get home => '首页';

  @override
  String get search => '搜索';

  @override
  String get explore => '探索';

  @override
  String get exploreAnime => '探索动漫';

  @override
  String get exploreMovies => '探索电影';

  @override
  String get library => '媒体库';

  @override
  String get settings => '设置';

  @override
  String get extensions => '扩展';

  @override
  String get updateAvailable => '发现新版本';

  @override
  String get retry => '重试';

  @override
  String get factoryReset => '恢复出厂设置';

  @override
  String get startupError => '启动错误';

  @override
  String get general => '常规';

  @override
  String get appTheme => '应用主题';

  @override
  String get recordWatchHistory => '记录观看历史';

  @override
  String get defaultHomeScreen => '默认启动页';

  @override
  String get titlePosition => '标题位置';

  @override
  String get titlePositionBelowPoster => '海报下方';

  @override
  String get titlePositionInsidePoster => '海报内';

  @override
  String get player => '播放器';

  @override
  String get defaultPlayer => '默认播放器';

  @override
  String get leftGesture => '左侧手势';

  @override
  String get rightGesture => '右侧手势';

  @override
  String get doubleTapToSeek => '双击快进/快退';

  @override
  String get swipeToSeek => '滑动快进/快退';

  @override
  String get seekDuration => '快进/快退秒数';

  @override
  String get bufferDepth => '缓冲深度';

  @override
  String get defaultResizeMode => '默认填充模式';

  @override
  String get hardwareDecoding => '硬件解码';

  @override
  String get network => '网络';

  @override
  String get dnsOverHttps => 'DNS over HTTPS';

  @override
  String get dohProvider => 'DoH 供应商';

  @override
  String get githubProxy => 'GitHub 代理';

  @override
  String get githubProxySubtitle => '通过 jsDelivr 转发扩展下载，以绕过运营商封锁。';

  @override
  String get manageExtensions => '管理扩展';

  @override
  String get appData => '应用数据';

  @override
  String get resetDataKeepExtensions => '重置数据（保留扩展）';

  @override
  String get developer => '开发者';

  @override
  String get developerOptions => '开发者选项';

  @override
  String get about => '关于';

  @override
  String get version => '版本';

  @override
  String get enabled => '开启';

  @override
  String get disabled => '关闭';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => '加入我们的服务器';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => '加入我们的频道';

  @override
  String developedBy(String name) {
    return '由 $name 开发';
  }

  @override
  String get system => '跟随系统';

  @override
  String get dark => '深色';

  @override
  String get light => '浅色';

  @override
  String get later => '以后再说';

  @override
  String get updateNow => '立即更新';

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

  @override
  String get close => '关闭';

  @override
  String get delete => '删除';

  @override
  String get viewDetails => '查看详情';

  @override
  String get clearAll => '清除全部';

  @override
  String get clearAllHistory => '清除观看历史';

  @override
  String get all => '全部';

  @override
  String get none => '无';

  @override
  String get confirmDownload => '确认下载';

  @override
  String get downloadNow => '立即下载';

  @override
  String get selectSource => '选择来源';

  @override
  String get downloadUnavailable => '暂无可下载源';

  @override
  String get selectAnotherSource => '选择其他来源';

  @override
  String get watchHistoryCleared => '观看历史已清除';

  @override
  String get downloadingUpdate => '正在下载更新...';

  @override
  String errorPrefix(String message) {
    return '错误: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return '可用更新: $tag';
  }

  @override
  String get selectProviderToStart => '选择一个供应商以开始';

  @override
  String get tapExtensionIcon => '点击角落的扩展图标';

  @override
  String get continueWatching => '继续观看';

  @override
  String get noInternetConnection => '无网络连接';

  @override
  String get siteNotReachable => '无法访问该站点';

  @override
  String get checkConnectionOrDownloads => '请检查网络连接或查看已下载内容。';

  @override
  String get tryVpnOrConnection => '请尝试使用 VPN 或检查网络连接。';

  @override
  String errorDetails(String error) {
    return '错误详情: $error';
  }

  @override
  String get goToDownloads => '转到下载';

  @override
  String get selectProvider => '选择供应商';

  @override
  String get searchHint => '搜索电影、剧集...';

  @override
  String get searchFavoriteContent => '搜索你喜爱的内容';

  @override
  String get pressSearchOrEnter => '按下搜索键或回车开始';

  @override
  String get noResultsFound => '未找到结果。';

  @override
  String get couldNotLoadTrending => '无法加载热门趋势';

  @override
  String get popularMovies => '热门电影';

  @override
  String get popularTVShows => '热门剧集';

  @override
  String get newMovies => '最新电影';

  @override
  String get newTVShows => '最新剧集';

  @override
  String get featuredMovies => '精选电影';

  @override
  String get featuredTVShows => '精选剧集';

  @override
  String get lastVideosTVShows => '最新更新剧集';

  @override
  String get downloads => '下载';

  @override
  String get bookmarks => '收藏';

  @override
  String get noDownloadsYet => '暂无下载内容';

  @override
  String episodesCount(int count, int done) {
    return '$count 集 • 已看完 $done 集';
  }

  @override
  String get deleteAllEpisodes => '删除所有剧集';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return '确定要删除 \"$title\" 的所有 $count 集内容及文件吗？';
  }

  @override
  String get deleteAll => '删除全部';

  @override
  String get completed => '完成';

  @override
  String get statusQueued => '排队中...';

  @override
  String get statusDownloading => '下载中...';

  @override
  String get statusFinished => '已完成';

  @override
  String get statusFailed => '失败';

  @override
  String get statusCanceled => '已取消';

  @override
  String get statusPaused => '已暂停';

  @override
  String get statusWaiting => '等待中...';

  @override
  String get fileNotFoundRemoving => '未找到文件。正在移除记录。';

  @override
  String get fileNotFound => '未找到文件';

  @override
  String get deleteDownload => '删除下载';

  @override
  String get confirmDeleteDownload => '确定要删除此下载内容及文件吗？';

  @override
  String get libraryEmpty => '你的媒体库是空的';

  @override
  String get language => '语言';

  @override
  String get english => '英语';

  @override
  String get hindi => '印地语';

  @override
  String get kannada => '卡纳达语';

  @override
  String get unknown => '未知';

  @override
  String get recommended => '推荐';

  @override
  String get on => '开';

  @override
  String get off => '关';

  @override
  String get installRemoveProviders => '安装或移除供应商';

  @override
  String get resetDataSubtitle => '重置设置和数据库，保留插件';

  @override
  String get factoryResetSubtitle => '删除所有数据、设置和扩展';

  @override
  String get developerOptionsSubtitle => '调试工具与本地播放';

  @override
  String get loading => '加载中...';

  @override
  String get sec => '秒';

  @override
  String get min => '分';

  @override
  String get internalPlayer => '内置播放器 (VLC)';

  @override
  String get builtInPlayer => '内置播放器';

  @override
  String get customNotSet => '自定义（未设置）';

  @override
  String selectGesture(String side) {
    return '选择 $side 手势';
  }

  @override
  String get left => '左侧';

  @override
  String get right => '右侧';

  @override
  String get selectSeekDuration => '选择快进/快退秒数';

  @override
  String get selectBufferDepth => '选择缓冲深度';

  @override
  String get subtitleSettings => '字幕设置';

  @override
  String size(int size) {
    return '大小: $size';
  }

  @override
  String get background => '背景';

  @override
  String get customDohUrlLabel => '自定义 DoH 地址';

  @override
  String get enterCustomDohUrl => '输入你的 DoH URL';

  @override
  String get chooseTheme => '选择主题';

  @override
  String get resetDataDialogTitle => '重置数据？';

  @override
  String get resetDataDialogContent => '这将清除设置、收藏和历史。已安装的扩展不会被移除。';

  @override
  String get factoryResetDialogTitle => '恢复出厂设置？';

  @override
  String get factoryResetDialogContent => '这将删除所有内容：收藏、历史、设置及所有扩展。操作不可逆。';

  @override
  String get selectLanguage => '选择语言';

  @override
  String get synopsis => '剧情简介';

  @override
  String get noDescription => '暂无描述。';

  @override
  String get videoAlreadyDownloadedPrompt => '此视频已下载。你想如何操作？';

  @override
  String get playNow => '立即播放';

  @override
  String get upNext => '即将播放';

  @override
  String get deleteDownloadPrompt => '删除下载？';

  @override
  String get deleteDownloadConfirmation => '确定要删除此文件吗？操作不可逆。';

  @override
  String get no => '否';

  @override
  String get yesDelete => '是，删除';

  @override
  String get downloadPaused => '下载已暂停';

  @override
  String get downloading => '下载中';

  @override
  String get speed => '速度';

  @override
  String get remaining => '剩余';

  @override
  String get resume => '恢复';

  @override
  String get pause => '暂停';

  @override
  String get torrentContent => '种子内容';

  @override
  String get audioTracks => '音轨';

  @override
  String get noAudioTracks => '未找到音轨';

  @override
  String get subtitles => '字幕';

  @override
  String get options => '选项';

  @override
  String get noSubtitlesFound => '未找到字幕';

  @override
  String get playbackSpeed => '播放速度';

  @override
  String get subtitleOptions => '字幕选项';

  @override
  String get hlsSubtitleWarning => '此平台上的 HLS 播放器不支持外挂字幕。';

  @override
  String get loadFromDevice => '从设备加载';

  @override
  String get syncDelay => '同步 / 延迟';

  @override
  String get styleSettings => '样式设置';

  @override
  String get searchOnline => '在线搜索';

  @override
  String get subtitleSync => '字幕同步';

  @override
  String get subtitleDelayWarning => '当前播放引擎不支持字幕延迟设置。';

  @override
  String get resetDelay => '重置延迟';

  @override
  String get subtitleStyles => '字幕样式';

  @override
  String get resetToDefault => '恢复默认';

  @override
  String get fontSize => '字体大小';

  @override
  String get verticalPosition => '垂直位置';

  @override
  String get textColor => '文字颜色';

  @override
  String get backgroundColor => '背景颜色';

  @override
  String get backgroundOpacity => '背景不透明度';

  @override
  String get subtitleSearch => '搜索字幕';

  @override
  String get searchSubtitleNameHint => '字幕名称...';

  @override
  String get enterSearchSubtitlePrompt => '输入名称以搜索字幕。';

  @override
  String get noSubtitleResults => '未找到结果。请尝试其他词项。';

  @override
  String get downloadingApplyingSubtitle => '正在下载并应用字幕...';

  @override
  String get failedToDownloadSubtitle => '下载字幕失败。';

  @override
  String get failedToLoadSubtitles => '加载字幕失败。请重试。';

  @override
  String get noReposFound => '未找到存储库或插件';

  @override
  String get downloadAllProviders => '下载全部';

  @override
  String get removeRepository => '移除存储库';

  @override
  String get addRepo => '添加存储库';

  @override
  String get extensionsNotInRepos => '不在存储库中的扩展';

  @override
  String get noLongerInRepo => '不再存在于任何存储库中';

  @override
  String get addRepoToBrowse => '添加存储库以浏览和更新插件';

  @override
  String get debugExtensions => '调试扩展';

  @override
  String removeRepoConfirm(String repoName) {
    return '移除 $repoName？';
  }

  @override
  String get removeRepoWarning => '这将移除存储库并卸载其包含的所有插件。';

  @override
  String get addRepository => '添加存储库';

  @override
  String get repoUrlOrShortcode => '存储库地址或短代码';

  @override
  String get assetPlugin => '资源插件';

  @override
  String get installed => '已安装';

  @override
  String get repositories => '仓库';

  @override
  String get noExtensionsInstalled => '未安装扩展';

  @override
  String get browseRepositoriesToInstall => '打开“仓库”标签页，发现并安装扩展。';

  @override
  String get browseRepositories => '浏览仓库';

  @override
  String get addRepoDescription => '添加仓库 URL 或短代码，以发现并安装扩展插件。';

  @override
  String updateTo(String version) {
    return '更新至 $version';
  }

  @override
  String get install => '安装';

  @override
  String get error => '错误';

  @override
  String get ok => '确定';

  @override
  String pluginSettings(String pluginName) {
    return '$pluginName 设置';
  }

  @override
  String get movies => '电影';

  @override
  String get series => '剧集';

  @override
  String get anime => '动漫';

  @override
  String get liveStreams => '直播';

  @override
  String get debug => '调试';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个扩展已更新',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => '导航无效。请返回。';

  @override
  String get startOver => '重新开始';

  @override
  String get goBack => '返回';

  @override
  String get resolving => '解析中...';

  @override
  String get downloaded => '已下载';

  @override
  String get download => '下载';

  @override
  String get debugOnlyFeature => '此功能仅在调试版本中可用';

  @override
  String get streamUrl => '串流地址';

  @override
  String get play => '播放';

  @override
  String get verifyingSourceSize => '正在验证来源和大小...';

  @override
  String get fileSaveLocationNotification => '文件将保存到下载文件夹中。';

  @override
  String get resumingPlayback => '继续播放';

  @override
  String pausedAt(String time) {
    return '暂停于 $time';
  }

  @override
  String resumesAutomatically(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 秒后自动继续',
    );
    return '$_temp0';
  }

  @override
  String get resumeNow => '立即继续';

  @override
  String get playbackError => '播放错误';

  @override
  String get confirmClearHistory => '确定要清除所有观看历史吗？';

  @override
  String seasonWithNumber(Object number) {
    return '第 $number 季';
  }

  @override
  String get starting => '启动中...';

  @override
  String percentWatched(int percent) {
    return '已观看 $percent%';
  }

  @override
  String get sub => '中字';

  @override
  String get dub => '配音';

  @override
  String playEpisode(String label, Object season, Object episode) {
    return '$label S$season E$episode';
  }

  @override
  String playEpisodeOnly(String label, int episode) {
    return '$label E$episode';
  }

  @override
  String get debugTools => '调试工具';

  @override
  String get playLocalVideo => '播放本地视频';

  @override
  String get playLocalVideoSubtitle => '播放设备上的视频';

  @override
  String get streamUrlSubtitle => '播放网络地址';

  @override
  String get streamTorrent => '播放种子';

  @override
  String get streamTorrentSubtitle => '选择本地种子文件播放';

  @override
  String get loadPluginFromAssets => '从资源加载插件';

  @override
  String get enterVideoUrlHint => '输入视频地址 (http, magnet 等)';

  @override
  String get networkStream => '网络串流';

  @override
  String removedFromHistory(String title) {
    return '已从历史中移除 $title';
  }

  @override
  String get custom => '自定义';

  @override
  String get refreshingLiveStream => '刷新直播...';

  @override
  String get removeFromHistory => '从历史中移除';

  @override
  String get live => '直播';

  @override
  String get volume => '音量';

  @override
  String get brightness => '亮度';

  @override
  String get fit => '适应';

  @override
  String get zoom => '缩放';

  @override
  String get stretch => '拉伸';

  @override
  String titleWithParam(String title) {
    return '标题: $title';
  }

  @override
  String sourceWithParam(String source) {
    return '来源: $source';
  }

  @override
  String sizeWithParam(String size) {
    return '大小: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return '错误: $error。正在使用内置播放器。';
  }

  @override
  String playerNotDetected(String playerName) {
    return '未检测到 $playerName。正在启动内置播放器。';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return '第 $number 季 ($count 集)';
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
    return '为 $playerName 选择来源';
  }

  @override
  String get noPluginsInstalled => '未安装插件';

  @override
  String get noPluginsMessage => '安装扩展以浏览和流式传输内容。';

  @override
  String get goToExtensions => '前往扩展';

  @override
  String get availableSources => '可用来源';

  @override
  String get seasons => '季';

  @override
  String get episodes => '集';

  @override
  String get selectSourceToPlay => '请选择上方可用来源播放。';

  @override
  String episodeCountOnly(num count) {
    return '$count 集';
  }

  @override
  String get noEpisodesFound => '未找到剧集';

  @override
  String get local => '本地';

  @override
  String get remote => '远程';

  @override
  String get torrent => '种子';

  @override
  String get unlock => '解锁';

  @override
  String get lock => '锁定';

  @override
  String get sources => '来源';

  @override
  String get tracks => '轨道';

  @override
  String get content => '内容';

  @override
  String get stats => '统计';

  @override
  String get resize => '缩放';

  @override
  String get next => '下一个';

  @override
  String get pip => '画中画';

  @override
  String get rotate => '旋转';

  @override
  String get windowed => '窗口化';

  @override
  String get fullscreen => '全屏';

  @override
  String get movieDetails => '电影详情';

  @override
  String get showDetails => '查看详情';

  @override
  String get tagline => '宣传语';

  @override
  String get status => '状态';

  @override
  String get releaseDate => '上映日期';

  @override
  String get firstAirDate => '首播日期';

  @override
  String get originalLanguage => '原始语言';

  @override
  String get originCountry => '出品国家';

  @override
  String get budgetLabel => '预算';

  @override
  String get revenueLabel => '票房';

  @override
  String get paused => '暂停中';

  @override
  String get watched => '已观看';

  @override
  String get watching => '正在观看';

  @override
  String get lastWatched => '最后观看';

  @override
  String get movie => '电影';

  @override
  String get tvShow => '剧集';

  @override
  String get failedToLoadContent => '加载内容失败';

  @override
  String get director => '导演';

  @override
  String get creator => '主创';

  @override
  String get showMore => '展开';

  @override
  String get showLess => '收起';

  @override
  String get viewAll => '查看全部';

  @override
  String seasonsCount(int count) {
    return '$count 季';
  }

  @override
  String get noInternetError => '无网络连接';

  @override
  String get timeoutError => '请求超时。请重试。';

  @override
  String get serverError => '服务器错误。请稍后重试。';

  @override
  String get contentNotFoundError => '未找到内容。';

  @override
  String get accessDeniedError => '访问被拒绝。请检查凭据。';

  @override
  String get serviceUnavailableError => '服务器不可用。稍后重试。';

  @override
  String get generalError => '出了些问题。请重试。';

  @override
  String get skip => '跳过';

  @override
  String get skipIntro => '跳过片头';

  @override
  String get skipOutro => '跳过片尾';

  @override
  String get skipRecap => '跳过前情回顾';

  @override
  String get goLive => '进入直播';

  @override
  String get dismiss => '关闭';

  @override
  String get nextUp => '下一集';

  @override
  String sourceAttempt(int index, int total) {
    return '播放源 $index / $total';
  }

  @override
  String get trying => '重试中';

  @override
  String get failed => '失败';

  @override
  String get selected => '已选择';

  @override
  String get playing => '播放中';

  @override
  String get pending => '等待中';

  @override
  String get openSubtitles => 'OpenSubtitles';

  @override
  String get subDl => 'SubDL';

  @override
  String get subSource => 'SubSource';

  @override
  String get wifiQualityPreference => 'Wi-Fi 视频质量偏好';

  @override
  String get mobileQualityPreference => '移动网络视频质量偏好';

  @override
  String get anyNoPreference => '不限（无偏好）';

  @override
  String get subtitleAccounts => '字幕账户';

  @override
  String get accounts => '账户';

  @override
  String get notLoggedIn => '未登录';

  @override
  String loggedInAs(String username) {
    return '已登录为 $username';
  }

  @override
  String get apiKeyConfigured => 'API 密钥已配置';

  @override
  String get keyNotSet => '未设置密钥';

  @override
  String get testConnection => '测试连接';

  @override
  String get connectedSuccessfully => '连接成功';

  @override
  String get connectionFailed => '连接失败';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get noAccountRegister => '没有账户？在此注册';

  @override
  String get apiKey => 'API 密钥';

  @override
  String get email => '电子邮箱';

  @override
  String get fetchMyApiKey => '获取我的 API 密钥';

  @override
  String get keyVerified => '密钥已验证';

  @override
  String get invalidApiKey => '无效的 API 密钥';

  @override
  String get openSubtitlesAuthSubtitle => '输入您的账户凭据以获得更高限制和无广告字幕。';

  @override
  String get subDlAuthSubtitle => '直接输入您的 SubDL API 密钥，或者在下方使用您的账户凭据获取。';

  @override
  String get orFetchViaAccount => '或通过账户获取';

  @override
  String get subSourceAuthSubtitle => 'SubSource 开箱即用，但您可以添加个人官方 API 密钥以提高可靠性。';

  @override
  String get apiKeyOptionalOverride => 'API 密钥（可选覆盖）';

  @override
  String get enterKeyToOverrideDefault => '输入密钥以覆盖默认设置';

  @override
  String get getApiKeyFromProfile => '从 SubSource 个人资料获取您的 API 密钥';

  @override
  String get qualityNotGuaranteed => '不保证质量。来源按偏好排序，但播放取决于提供商实际提供的内容。';

  @override
  String get keepSourcesOriginalOrder => '保持来源原始顺序';

  @override
  String get openLink => '打开链接';

  @override
  String get diagnostics => '诊断';

  @override
  String get viewLogs => '查看日志';

  @override
  String get viewLogsSubtitle => '查看应用程序活动和错误';

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

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => '繁體中文';

  @override
  String get home => '首頁';

  @override
  String get search => '搜尋';

  @override
  String get explore => '探索';

  @override
  String get exploreAnime => '探索動畫';

  @override
  String get exploreMovies => '探索電影';

  @override
  String get library => '媒體庫';

  @override
  String get settings => '設定';

  @override
  String get extensions => '擴充功能';

  @override
  String get updateAvailable => '發現更新';

  @override
  String get retry => '重試';

  @override
  String get factoryReset => '恢復出廠設定';

  @override
  String get startupError => '啟動錯誤';

  @override
  String get general => '一般';

  @override
  String get appTheme => '應用程式主題';

  @override
  String get recordWatchHistory => '記錄觀看紀錄';

  @override
  String get defaultHomeScreen => '預設啟動畫面';

  @override
  String get titlePosition => '標題位置';

  @override
  String get titlePositionBelowPoster => '海報下方';

  @override
  String get titlePositionInsidePoster => '海報內';

  @override
  String get player => '播放器';

  @override
  String get defaultPlayer => '預設播放器';

  @override
  String get leftGesture => '左側手勢';

  @override
  String get rightGesture => '右側手势';

  @override
  String get doubleTapToSeek => '連點快進/快退';

  @override
  String get swipeToSeek => '滑動快進/快退';

  @override
  String get seekDuration => '快進/快退秒數';

  @override
  String get bufferDepth => '緩衝深度';

  @override
  String get defaultResizeMode => '預設填充模式';

  @override
  String get hardwareDecoding => '硬體解碼';

  @override
  String get network => '網路';

  @override
  String get dnsOverHttps => 'DNS over HTTPS';

  @override
  String get dohProvider => 'DoH 供應商';

  @override
  String get githubProxy => 'GitHub 代理';

  @override
  String get githubProxySubtitle => '透過 jsDelivr 轉送擴充功能下載，以繞過電信業者封鎖。';

  @override
  String get manageExtensions => '管理擴充功能';

  @override
  String get appData => '應用程式資料';

  @override
  String get resetDataKeepExtensions => '重置資料 (保留擴充功能)';

  @override
  String get developer => '開發者';

  @override
  String get developerOptions => '開發者選項';

  @override
  String get about => '關於';

  @override
  String get version => '版本';

  @override
  String get enabled => '啟用';

  @override
  String get disabled => '停用';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => '加入我們的伺服器';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => '加入我們的頻道';

  @override
  String developedBy(String name) {
    return '由 $name 開發';
  }

  @override
  String get system => '跟隨系統';

  @override
  String get dark => '深色';

  @override
  String get light => '淺色';

  @override
  String get later => '稍後再說';

  @override
  String get updateNow => '立即更新';

  @override
  String get save => '儲存';

  @override
  String get cancel => '取消';

  @override
  String get close => '關閉';

  @override
  String get delete => '刪除';

  @override
  String get viewDetails => '查看詳情';

  @override
  String get clearAll => '全部清除';

  @override
  String get clearAllHistory => '清除所有觀看紀錄';

  @override
  String get all => '全部';

  @override
  String get none => '無';

  @override
  String get confirmDownload => '確認下載';

  @override
  String get downloadNow => '立即下載';

  @override
  String get selectSource => '選擇來源';

  @override
  String get downloadUnavailable => '目前不可下載';

  @override
  String get selectAnotherSource => '選擇其他來源';

  @override
  String get watchHistoryCleared => '觀看紀錄已清除';

  @override
  String get downloadingUpdate => '正在下載更新...';

  @override
  String errorPrefix(String message) {
    return '錯誤: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return '可用更新: $tag';
  }

  @override
  String get selectProviderToStart => '選擇供應商以開始';

  @override
  String get tapExtensionIcon => '點擊角落的擴充功能圖示';

  @override
  String get continueWatching => '繼續觀看';

  @override
  String get noInternetConnection => '無網路連接';

  @override
  String get siteNotReachable => '無法存取該站點';

  @override
  String get checkConnectionOrDownloads => '請檢查網路連接或查看已下載影片。';

  @override
  String get tryVpnOrConnection => '請嘗試使用 VPN 或檢查網路連接。';

  @override
  String errorDetails(String error) {
    return '錯誤詳情: $error';
  }

  @override
  String get goToDownloads => '前往下載';

  @override
  String get selectProvider => '選擇供應商';

  @override
  String get searchHint => '搜尋電影、影集...';

  @override
  String get searchFavoriteContent => '搜尋您喜愛的內容';

  @override
  String get pressSearchOrEnter => '按下搜尋鍵或 Enter 開始';

  @override
  String get noResultsFound => '找不到結果。';

  @override
  String get couldNotLoadTrending => '無法載入熱門趨勢';

  @override
  String get popularMovies => '熱門電影';

  @override
  String get popularTVShows => '熱門影集';

  @override
  String get newMovies => '最新電影';

  @override
  String get newTVShows => '最新影集';

  @override
  String get featuredMovies => '精選電影';

  @override
  String get featuredTVShows => '精選影集';

  @override
  String get lastVideosTVShows => '最近更新影集';

  @override
  String get downloads => '下載內容';

  @override
  String get bookmarks => '我的收藏';

  @override
  String get noDownloadsYet => '尚無下載內容';

  @override
  String episodesCount(int count, int done) {
    return '$count 集 • 已看完 $done 集';
  }

  @override
  String get deleteAllEpisodes => '刪除所有集數';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return '確定要刪除「$title」的所有 $count 集內容以及檔案嗎？';
  }

  @override
  String get deleteAll => '全部刪除';

  @override
  String get completed => '完成';

  @override
  String get statusQueued => '排隊中...';

  @override
  String get statusDownloading => '下載中...';

  @override
  String get statusFinished => '已完成';

  @override
  String get statusFailed => '失敗';

  @override
  String get statusCanceled => '已取消';

  @override
  String get statusPaused => '已暫停';

  @override
  String get statusWaiting => '等待中...';

  @override
  String get fileNotFoundRemoving => '找不到檔案，正在移除紀錄。';

  @override
  String get fileNotFound => '找不到檔案';

  @override
  String get deleteDownload => '刪除下載';

  @override
  String get confirmDeleteDownload => '確定要刪除此下載內容以及檔案嗎？';

  @override
  String get libraryEmpty => '您的媒體庫是空的';

  @override
  String get language => '語言';

  @override
  String get english => '英語';

  @override
  String get hindi => '印地語';

  @override
  String get kannada => '卡納達語';

  @override
  String get unknown => '未知';

  @override
  String get recommended => '推薦';

  @override
  String get on => '開啟';

  @override
  String get off => '停用';

  @override
  String get installRemoveProviders => '安裝或移除供應商';

  @override
  String get resetDataSubtitle => '重置設定與資料庫，保留外掛程式';

  @override
  String get factoryResetSubtitle => '刪除所有資料、設定與擴充功能';

  @override
  String get developerOptionsSubtitle => '偵錯工具與區域播放';

  @override
  String get loading => '載入中...';

  @override
  String get sec => '秒';

  @override
  String get min => '分';

  @override
  String get internalPlayer => '內建播放器 (VLC)';

  @override
  String get builtInPlayer => '內建播放器';

  @override
  String get customNotSet => '自訂 (未設置)';

  @override
  String selectGesture(String side) {
    return '選擇 $side 手勢';
  }

  @override
  String get left => '左側';

  @override
  String get right => '右側';

  @override
  String get selectSeekDuration => '選擇快進/快退秒數';

  @override
  String get selectBufferDepth => '選擇緩衝深度';

  @override
  String get subtitleSettings => '字幕設定';

  @override
  String size(int size) {
    return '大小: $size';
  }

  @override
  String get background => '背景';

  @override
  String get customDohUrlLabel => '自訂 DoH 位址';

  @override
  String get enterCustomDohUrl => '輸入您的 DoH URL';

  @override
  String get chooseTheme => '選擇主題';

  @override
  String get resetDataDialogTitle => '重置資料？';

  @override
  String get resetDataDialogContent => '這將清除設定、收藏和歷史紀錄。已安裝的擴充功能不會被移除。';

  @override
  String get factoryResetDialogTitle => '恢復出廠設定？';

  @override
  String get factoryResetDialogContent => '這將刪除所有內容：收藏、歷史紀錄、設定及所有擴充功能。此操作不可逆。';

  @override
  String get selectLanguage => '選擇語言';

  @override
  String get synopsis => '劇情簡介';

  @override
  String get noDescription => '目前無描述。';

  @override
  String get videoAlreadyDownloadedPrompt => '此影片已下載，您想如何操作？';

  @override
  String get playNow => '立即播放';

  @override
  String get upNext => '即將播放';

  @override
  String get deleteDownloadPrompt => '刪除下載？';

  @override
  String get deleteDownloadConfirmation => '確定要刪除此檔案嗎？此操作不可逆。';

  @override
  String get no => '否';

  @override
  String get yesDelete => '是，刪除';

  @override
  String get downloadPaused => '下載已暫停';

  @override
  String get downloading => '下載中';

  @override
  String get speed => '速度';

  @override
  String get remaining => '剩餘時間';

  @override
  String get resume => '繼續';

  @override
  String get pause => '暫停';

  @override
  String get torrentContent => '種子內容';

  @override
  String get audioTracks => '音軌';

  @override
  String get noAudioTracks => '找不到音軌';

  @override
  String get subtitles => '字幕';

  @override
  String get options => '選項';

  @override
  String get noSubtitlesFound => '找不到字幕';

  @override
  String get playbackSpeed => '播放速度';

  @override
  String get subtitleOptions => '字幕選項';

  @override
  String get hlsSubtitleWarning => '在此平台上的 HLS 播放器不支援外掛字幕。';

  @override
  String get loadFromDevice => '從裝置載入';

  @override
  String get syncDelay => '同步 / 延遲';

  @override
  String get styleSettings => '樣式設定';

  @override
  String get searchOnline => '線上搜尋';

  @override
  String get subtitleSync => '字幕同步';

  @override
  String get subtitleDelayWarning => '目前的播放引擎不支援字幕延遲設定。';

  @override
  String get resetDelay => '重置延遲';

  @override
  String get subtitleStyles => '字幕樣式';

  @override
  String get resetToDefault => '恢復成預設';

  @override
  String get fontSize => '字體大小';

  @override
  String get verticalPosition => '垂直位置';

  @override
  String get textColor => '文字顏色';

  @override
  String get backgroundColor => '背景顏色';

  @override
  String get backgroundOpacity => '背景不透明度';

  @override
  String get subtitleSearch => '搜尋字幕';

  @override
  String get searchSubtitleNameHint => '字幕名稱...';

  @override
  String get enterSearchSubtitlePrompt => '輸入名稱以搜尋字幕。';

  @override
  String get noSubtitleResults => '找不到結果，請嘗試其他關鍵字。';

  @override
  String get downloadingApplyingSubtitle => '正在下載並套用字幕...';

  @override
  String get failedToDownloadSubtitle => '下載字幕失敗。';

  @override
  String get failedToLoadSubtitles => '載入字幕失敗，請重試。';

  @override
  String get noReposFound => '找不到存儲庫或外掛程式';

  @override
  String get downloadAllProviders => '下載全部';

  @override
  String get removeRepository => '移除存儲庫';

  @override
  String get addRepo => '新增存儲庫';

  @override
  String get extensionsNotInRepos => '不在存儲庫中的擴充功能';

  @override
  String get noLongerInRepo => '不再存在於任何存儲庫中';

  @override
  String get addRepoToBrowse => '新增存儲庫以瀏覽和更新外掛程式';

  @override
  String get debugExtensions => '偵錯擴充功能';

  @override
  String removeRepoConfirm(String repoName) {
    return '移除 $repoName？';
  }

  @override
  String get removeRepoWarning => '這將移除存儲庫並解除安裝其包含的所有外掛程式。';

  @override
  String get addRepository => '新增存儲庫';

  @override
  String get repoUrlOrShortcode => '存儲庫網址或簡碼';

  @override
  String get assetPlugin => '資源外掛程式';

  @override
  String get installed => '已完成安裝';

  @override
  String get repositories => '儲存庫';

  @override
  String get noExtensionsInstalled => '尚未安裝擴充功能';

  @override
  String get browseRepositoriesToInstall => '開啟「儲存庫」分頁，探索並安裝擴充功能。';

  @override
  String get browseRepositories => '瀏覽儲存庫';

  @override
  String get addRepoDescription => '新增儲存庫 URL 或短代碼，以探索並安裝擴充外掛。';

  @override
  String updateTo(String version) {
    return '更新至 $version';
  }

  @override
  String get install => '安裝';

  @override
  String get error => '錯誤';

  @override
  String get ok => '確定';

  @override
  String pluginSettings(String pluginName) {
    return '$pluginName 設定';
  }

  @override
  String get movies => '電影';

  @override
  String get series => '影集';

  @override
  String get anime => '動漫';

  @override
  String get liveStreams => '直播';

  @override
  String get debug => '偵錯';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個擴充功能已更新',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => '導覽無效，請返回。';

  @override
  String get startOver => '重新開始';

  @override
  String get goBack => '返回';

  @override
  String get resolving => '解析中...';

  @override
  String get downloaded => '已下載';

  @override
  String get download => '下載';

  @override
  String get debugOnlyFeature => '此功能僅在偵錯版本中可用';

  @override
  String get streamUrl => '串流網址';

  @override
  String get play => '播放';

  @override
  String get verifyingSourceSize => '正在驗證來源與大小...';

  @override
  String get fileSaveLocationNotification => '檔案將儲存至下載資料夾中。';

  @override
  String get resumingPlayback => '重新開始播放';

  @override
  String pausedAt(String time) {
    return '暫停於 $time';
  }

  @override
  String resumesAutomatically(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 秒後自動重新開始',
    );
    return '$_temp0';
  }

  @override
  String get resumeNow => '立即開始';

  @override
  String get playbackError => '播放錯誤';

  @override
  String get confirmClearHistory => '確定要清除所有觀看紀錄嗎？';

  @override
  String seasonWithNumber(Object number) {
    return '第 $number 季';
  }

  @override
  String get starting => '啟動中...';

  @override
  String percentWatched(int percent) {
    return '已觀看 $percent%';
  }

  @override
  String get sub => '中字';

  @override
  String get dub => '配音';

  @override
  String playEpisode(String label, Object season, Object episode) {
    return '$label S$season E$episode';
  }

  @override
  String playEpisodeOnly(String label, int episode) {
    return '$label E$episode';
  }

  @override
  String get debugTools => '偵錯工具';

  @override
  String get playLocalVideo => '播放區域影片';

  @override
  String get playLocalVideoSubtitle => '播放裝置上的影片';

  @override
  String get streamUrlSubtitle => '播放網路網址';

  @override
  String get streamTorrent => '播放種子';

  @override
  String get streamTorrentSubtitle => '選擇區域種子檔案播放';

  @override
  String get loadPluginFromAssets => '從資源載入外掛程式';

  @override
  String get enterVideoUrlHint => '輸入影片網址 (http, magnet 等)';

  @override
  String get networkStream => '網路串流';

  @override
  String removedFromHistory(String title) {
    return '已從歷史紀錄中移除 $title';
  }

  @override
  String get custom => '自訂';

  @override
  String get refreshingLiveStream => '重新整理直播...';

  @override
  String get removeFromHistory => '從歷史紀錄中移除';

  @override
  String get live => '直播';

  @override
  String get volume => '音量';

  @override
  String get brightness => '亮度';

  @override
  String get fit => '適應';

  @override
  String get zoom => '縮放';

  @override
  String get stretch => '拉伸';

  @override
  String titleWithParam(String title) {
    return '標題: $title';
  }

  @override
  String sourceWithParam(String source) {
    return '來源: $source';
  }

  @override
  String sizeWithParam(String size) {
    return '大小: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return '錯誤: $error，正在使用內建播放器。';
  }

  @override
  String playerNotDetected(String playerName) {
    return '未偵測到 $playerName，正在啟動內建播放器。';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return '第 $number 季 ($count 集)';
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
    return '為 $playerName 選擇來源';
  }

  @override
  String get noPluginsInstalled => '未安裝外掛程式';

  @override
  String get noPluginsMessage => '安裝擴充功能以瀏覽和串流內容。';

  @override
  String get goToExtensions => '前往擴充功能';

  @override
  String get availableSources => '可用來源';

  @override
  String get seasons => '季';

  @override
  String get episodes => '集';

  @override
  String get selectSourceToPlay => '請選擇上方可用來源播放。';

  @override
  String episodeCountOnly(num count) {
    return '$count 集';
  }

  @override
  String get noEpisodesFound => '找不到集數';

  @override
  String get local => '區域';

  @override
  String get remote => '遠端';

  @override
  String get torrent => '種子';

  @override
  String get unlock => '解鎖';

  @override
  String get lock => '鎖定';

  @override
  String get sources => '來源';

  @override
  String get tracks => '音軌/字幕軌';

  @override
  String get content => '内容';

  @override
  String get stats => '數據統計';

  @override
  String get resize => '縮放';

  @override
  String get next => '下一個';

  @override
  String get pip => '子母畫面';

  @override
  String get rotate => '旋轉';

  @override
  String get windowed => '視窗化';

  @override
  String get fullscreen => '全屏';

  @override
  String get movieDetails => '電影詳情';

  @override
  String get showDetails => '查看詳情';

  @override
  String get tagline => '宣傳語';

  @override
  String get status => '狀態';

  @override
  String get releaseDate => '上映日期';

  @override
  String get firstAirDate => '首播日期';

  @override
  String get originalLanguage => '原始語言';

  @override
  String get originCountry => '出品國家';

  @override
  String get budgetLabel => '預算';

  @override
  String get revenueLabel => '票房收入';

  @override
  String get paused => '暫停中';

  @override
  String get watched => '已觀看';

  @override
  String get watching => '正在觀看';

  @override
  String get lastWatched => '最後觀看';

  @override
  String get movie => '電影';

  @override
  String get tvShow => '影集';

  @override
  String get failedToLoadContent => '載入內容失敗';

  @override
  String get director => '導演';

  @override
  String get creator => '原創者';

  @override
  String get showMore => '展開';

  @override
  String get showLess => '收起';

  @override
  String get viewAll => '查看全部';

  @override
  String seasonsCount(int count) {
    return '$count 季';
  }

  @override
  String get noInternetError => '無網路連接';

  @override
  String get timeoutError => '連線逾時，請重試。';

  @override
  String get serverError => '伺服器錯誤，請稍後重試。';

  @override
  String get contentNotFoundError => '找不到內容。';

  @override
  String get accessDeniedError => '存取被拒絕，請檢查憑證。';

  @override
  String get serviceUnavailableError => '伺服器不可用，稍後重試。';

  @override
  String get generalError => '發生錯誤，請重試。';

  @override
  String get skip => '跳過';

  @override
  String get skipIntro => '略過片頭';

  @override
  String get skipOutro => '略過片尾';

  @override
  String get skipRecap => '略過前情提要';

  @override
  String get goLive => '進入直播';

  @override
  String get dismiss => '關閉';

  @override
  String get nextUp => '下一集';

  @override
  String sourceAttempt(int index, int total) {
    return '播放源 $index / $total';
  }

  @override
  String get trying => '重試中';

  @override
  String get failed => '失敗';

  @override
  String get selected => '已選擇';

  @override
  String get playing => '播放中';

  @override
  String get pending => '等待中';

  @override
  String get openSubtitles => 'OpenSubtitles';

  @override
  String get subDl => 'SubDL';

  @override
  String get subSource => 'SubSource';

  @override
  String get wifiQualityPreference => 'Wi-Fi 视频质量偏好';

  @override
  String get mobileQualityPreference => '移动网络视频质量偏好';

  @override
  String get anyNoPreference => '不限（无偏好）';

  @override
  String get subtitleAccounts => '字幕账户';

  @override
  String get accounts => '帳戶';

  @override
  String get notLoggedIn => '未登录';

  @override
  String loggedInAs(String username) {
    return '已登录为 $username';
  }

  @override
  String get apiKeyConfigured => 'API 密钥已配置';

  @override
  String get keyNotSet => '未设置密钥';

  @override
  String get testConnection => '测试连接';

  @override
  String get connectedSuccessfully => '连接成功';

  @override
  String get connectionFailed => '连接失败';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get noAccountRegister => '没有账户？在此注册';

  @override
  String get apiKey => 'API 密钥';

  @override
  String get email => '电子邮箱';

  @override
  String get fetchMyApiKey => '获取我的 API 密钥';

  @override
  String get keyVerified => '密钥已验证';

  @override
  String get invalidApiKey => '无效的 API 密钥';

  @override
  String get openSubtitlesAuthSubtitle => '输入您的账户凭据以获得更高限制和无广告字幕。';

  @override
  String get subDlAuthSubtitle => '直接输入您的 SubDL API 密钥，或者在下方使用您的账户凭据获取。';

  @override
  String get orFetchViaAccount => '或通过账户获取';

  @override
  String get subSourceAuthSubtitle => 'SubSource 开箱即用，但您可以添加个人官方 API 密钥以提高可靠性。';

  @override
  String get apiKeyOptionalOverride => 'API 密钥（可选覆盖）';

  @override
  String get enterKeyToOverrideDefault => '输入密钥以覆盖默认设置';

  @override
  String get getApiKeyFromProfile => '从 SubSource 个人资料获取您的 API 密钥';

  @override
  String get qualityNotGuaranteed => '不保证质量。来源按偏好排序，但播放取决于提供商实际提供的内容。';

  @override
  String get keepSourcesOriginalOrder => '保持来源原始顺序';

  @override
  String get openLink => '打开链接';

  @override
  String get diagnostics => '诊断';

  @override
  String get viewLogs => '查看日志';

  @override
  String get viewLogsSubtitle => '查看应用程序活动和错误';

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
