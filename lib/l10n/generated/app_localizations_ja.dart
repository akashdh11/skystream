// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'SkyStream';

  @override
  String get languageName => '日本語';

  @override
  String get home => 'ホーム';

  @override
  String get search => '検索';

  @override
  String get explore => '探索';

  @override
  String get exploreAnime => 'アニメを探す';

  @override
  String get exploreMovies => '映画を探す';

  @override
  String get library => 'ライブラリ';

  @override
  String get settings => '設定';

  @override
  String get extensions => '拡張機能';

  @override
  String get updateAvailable => 'アップデートがあります';

  @override
  String get retry => '再試行';

  @override
  String get factoryReset => '初期化';

  @override
  String get startupError => '起動エラー';

  @override
  String get general => '全般';

  @override
  String get appTheme => 'アプリのテーマ';

  @override
  String get recordWatchHistory => '視聴履歴を記録する';

  @override
  String get defaultHomeScreen => 'デフォルトのホーム画面';

  @override
  String get titlePosition => 'タイトルの位置';

  @override
  String get titlePositionBelowPoster => 'ポスターの下';

  @override
  String get titlePositionInsidePoster => 'ポスター内';

  @override
  String get player => 'プレイヤー';

  @override
  String get defaultPlayer => 'デフォルトのプレイヤー';

  @override
  String get leftGesture => '左側のジェスチャー';

  @override
  String get rightGesture => '右側のジェスチャー';

  @override
  String get doubleTapToSeek => 'ダブルタップでスキップ';

  @override
  String get swipeToSeek => 'スワイプでスキップ';

  @override
  String get seekDuration => 'スキップ秒数';

  @override
  String get bufferDepth => 'バッファの深さ';

  @override
  String get defaultResizeMode => 'デフォルトの画面モード';

  @override
  String get hardwareDecoding => 'ハードウェア・デコーディング';

  @override
  String get network => 'ネットワーク';

  @override
  String get dnsOverHttps => 'DNS over HTTPS';

  @override
  String get dohProvider => 'DoH プロバイダー';

  @override
  String get githubProxy => 'GitHub プロキシ';

  @override
  String get githubProxySubtitle =>
      '拡張機能のダウンロードを jsDelivr 経由にして ISP のブロックを回避します。';

  @override
  String get manageExtensions => '拡張機能の管理';

  @override
  String get appData => 'アプリのデータ';

  @override
  String get resetDataKeepExtensions => 'データをリセット（拡張機能は保持）';

  @override
  String get developer => '開発者';

  @override
  String get developerOptions => '開発者向けオプション';

  @override
  String get about => 'アプリについて';

  @override
  String get version => 'バージョン';

  @override
  String get enabled => '有効';

  @override
  String get disabled => '無効';

  @override
  String get discord => 'Discord';

  @override
  String get discordSubtitle => 'サーバーに参加する';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramSubtitle => 'チャンネルに参加する';

  @override
  String developedBy(String name) {
    return '$name によって開発されました';
  }

  @override
  String get system => 'システム';

  @override
  String get dark => 'ダーク';

  @override
  String get light => 'ライト';

  @override
  String get later => '後で';

  @override
  String get updateNow => '今すぐアップデート';

  @override
  String get save => '保存';

  @override
  String get cancel => 'キャンセル';

  @override
  String get close => '閉じる';

  @override
  String get delete => '削除';

  @override
  String get viewDetails => '詳細を表示';

  @override
  String get clearAll => 'すべてクリア';

  @override
  String get clearAllHistory => '視聴履歴をクリア';

  @override
  String get all => 'すべて';

  @override
  String get none => 'なし';

  @override
  String get confirmDownload => 'ダウンロードの確認';

  @override
  String get downloadNow => '今すぐダウンロード';

  @override
  String get selectSource => 'ソースを選択';

  @override
  String get downloadUnavailable => 'ダウンロード不可';

  @override
  String get selectAnotherSource => '別のソースを選択';

  @override
  String get watchHistoryCleared => '視聴履歴をクリアしました';

  @override
  String get downloadingUpdate => 'アップデートをダウンロード中...';

  @override
  String errorPrefix(String message) {
    return 'エラー: $message';
  }

  @override
  String updateAvailableTag(String tag) {
    return 'アップデートがあります: $tag';
  }

  @override
  String get selectProviderToStart => '開始するにはプロバイダーを選択してください';

  @override
  String get tapExtensionIcon => '隅にある拡張機能アイコンをタップしてください';

  @override
  String get continueWatching => '続きから見る';

  @override
  String get noInternetConnection => 'インターネットに接続されていません';

  @override
  String get siteNotReachable => 'サイトにアクセスできません';

  @override
  String get checkConnectionOrDownloads => '接続を確認するか、ダウンロードしたコンテンツを確認してください。';

  @override
  String get tryVpnOrConnection => 'VPNを試すか、インターネット接続を確認してください。';

  @override
  String errorDetails(String error) {
    return 'エラーの詳細: $error';
  }

  @override
  String get goToDownloads => 'ダウンロード一覧へ';

  @override
  String get selectProvider => 'プロバイダーを選択';

  @override
  String get searchHint => '映画、ドラマを検索...';

  @override
  String get searchFavoriteContent => 'お気に入りのコンテンツを検索';

  @override
  String get pressSearchOrEnter => '検索キーまたはEnterを押して開始';

  @override
  String get noResultsFound => '結果が見つかりませんでした。';

  @override
  String get couldNotLoadTrending => 'トレンドを読み込めませんでした';

  @override
  String get popularMovies => '人気の映画';

  @override
  String get popularTVShows => '人気のドラマ';

  @override
  String get newMovies => '新作映画';

  @override
  String get newTVShows => '新作ドラマ';

  @override
  String get featuredMovies => '注目の映画';

  @override
  String get featuredTVShows => '注目のドラマ';

  @override
  String get lastVideosTVShows => '最新のドラマ';

  @override
  String get downloads => 'ダウンロード';

  @override
  String get bookmarks => 'ブックマーク';

  @override
  String get noDownloadsYet => 'ダウンロードはありません';

  @override
  String episodesCount(int count, int done) {
    return '$count エピソード • $done 完了';
  }

  @override
  String get deleteAllEpisodes => 'すべてのエピソードを削除';

  @override
  String confirmDeleteAllEpisodes(int count, String title) {
    return '「$title」の全 $count エピソードとファイルを削除してもよろしいですか？';
  }

  @override
  String get deleteAll => 'すべて削除';

  @override
  String get completed => '完了';

  @override
  String get statusQueued => '待機中...';

  @override
  String get statusDownloading => 'ダウンロード中...';

  @override
  String get statusFinished => '完了';

  @override
  String get statusFailed => '失敗';

  @override
  String get statusCanceled => 'キャンセル済み';

  @override
  String get statusPaused => '一時停止';

  @override
  String get statusWaiting => '待機中...';

  @override
  String get fileNotFoundRemoving => 'ファイルが見つかりません。履歴を削除しています。';

  @override
  String get fileNotFound => 'ファイルが見つかりません';

  @override
  String get deleteDownload => 'ダウンロードを削除';

  @override
  String get confirmDeleteDownload => 'このダウンロードとファイルを削除してもよろしいですか？';

  @override
  String get libraryEmpty => 'ライブラリが空です';

  @override
  String get language => '言語';

  @override
  String get english => '英語';

  @override
  String get hindi => 'ヒンディー語';

  @override
  String get kannada => 'カンナダ語';

  @override
  String get unknown => '不明';

  @override
  String get recommended => 'おすすめ';

  @override
  String get on => 'オン';

  @override
  String get off => 'オフ';

  @override
  String get installRemoveProviders => 'プロバイダーのインストール/削除';

  @override
  String get resetDataSubtitle => '設定とデータベースをクリア（プラグインは保持）';

  @override
  String get factoryResetSubtitle => 'すべてのデータ、設定、拡張機能を削除';

  @override
  String get developerOptionsSubtitle => 'デバッグツールとローカル再生';

  @override
  String get loading => '読み込み中...';

  @override
  String get sec => '秒';

  @override
  String get min => '分';

  @override
  String get internalPlayer => '内部プレイヤー (media_kit)';

  @override
  String get builtInPlayer => '内蔵プレイヤー';

  @override
  String get customNotSet => 'カスタム（未設定）';

  @override
  String selectGesture(String side) {
    return '$side のジェスチャーを選択';
  }

  @override
  String get left => '左';

  @override
  String get right => '右';

  @override
  String get selectSeekDuration => 'スキップ秒数を選択';

  @override
  String get selectBufferDepth => 'バッファの深さを選択';

  @override
  String get subtitleSettings => '字幕の設定';

  @override
  String size(int size) {
    return 'サイズ: $size';
  }

  @override
  String get background => '背景';

  @override
  String get customDohUrlLabel => 'カスタム DoH URL';

  @override
  String get enterCustomDohUrl => '独自の DoH URL を入力してください';

  @override
  String get chooseTheme => 'テーマを選択';

  @override
  String get resetDataDialogTitle => 'データをリセットしますか？';

  @override
  String get resetDataDialogContent =>
      '設定、お気に入り、履歴をクリアします。インストール済みの拡張機能は削除されません。';

  @override
  String get factoryResetDialogTitle => '初期化しますか？';

  @override
  String get factoryResetDialogContent =>
      'お気に入り、履歴、設定、すべての拡張機能を含むすべてのデータを削除します。この操作は取り消せません。';

  @override
  String get selectLanguage => '言語を選択';

  @override
  String get synopsis => 'あらすじ';

  @override
  String get noDescription => '説明はありません。';

  @override
  String get videoAlreadyDownloadedPrompt => 'この動画はすでにダウンロードされています。どうしますか？';

  @override
  String get playNow => '今すぐ再生';

  @override
  String get upNext => '次のエピソード';

  @override
  String get deleteDownloadPrompt => 'ダウンロードを削除しますか？';

  @override
  String get deleteDownloadConfirmation => 'このファイルを削除してもよろしいですか？この操作は取り消せません。';

  @override
  String get no => 'いいえ';

  @override
  String get yesDelete => 'はい、削除する';

  @override
  String get downloadPaused => 'ダウンロードを一時停止しました';

  @override
  String get downloading => 'ダウンロード中';

  @override
  String get speed => '速度';

  @override
  String get remaining => '残り';

  @override
  String get resume => '再開';

  @override
  String get pause => '一時停止';

  @override
  String get torrentContent => 'トレントの内容';

  @override
  String get audioTracks => '音声トラック';

  @override
  String get noAudioTracks => '音声トラックが見つかりませんでした';

  @override
  String get subtitles => '字幕';

  @override
  String get options => 'オプション';

  @override
  String get noSubtitlesFound => '字幕トラックが見つかりませんでした';

  @override
  String get playbackSpeed => '再生速度';

  @override
  String get subtitleOptions => '字幕のオプション';

  @override
  String get hlsSubtitleWarning => 'このプラットフォームのHLSプレイヤーでは外部字幕ファイルはサポートされていません。';

  @override
  String get loadFromDevice => 'デバイスから読み込む';

  @override
  String get syncDelay => '同期 / 遅延';

  @override
  String get styleSettings => 'スタイル設定';

  @override
  String get searchOnline => 'オンラインで検索（字幕検索）';

  @override
  String get subtitleSync => '字幕の同期';

  @override
  String get subtitleDelayWarning => '有効な再生エンジンは字幕の遅延をサポートしていません。';

  @override
  String get resetDelay => '遅延をリセット';

  @override
  String get subtitleStyles => '字幕のスタイル';

  @override
  String get mediaKitStylingWarning => '字幕のスタイル設定は現在 media_kit プレイヤーでのみ利用可能です。';

  @override
  String get resetToDefault => 'デフォルトに戻す';

  @override
  String get fontSize => '文字サイズ';

  @override
  String get verticalPosition => '垂直位置';

  @override
  String get textColor => '文字色';

  @override
  String get backgroundColor => '背景色';

  @override
  String get backgroundOpacity => '背景の不透明度';

  @override
  String get subtitleSearch => '字幕検索';

  @override
  String get searchSubtitleNameHint => '字幕名を入力...';

  @override
  String get enterSearchSubtitlePrompt => '検索する字幕名を入力してください。';

  @override
  String get noSubtitleResults => '結果が見つかりませんでした。別の言葉で検索してください。';

  @override
  String get downloadingApplyingSubtitle => '字幕をダウンロードして適用中...';

  @override
  String get failedToDownloadSubtitle => '字幕のダウンロードに失敗しました。';

  @override
  String get failedToLoadSubtitles => '字幕の読み込みに失敗しました。もう一度お試しください。';

  @override
  String get noReposFound => 'リポジトリまたはプラグインが見つかりませんでした';

  @override
  String get downloadAllProviders => 'すべてダウンロード';

  @override
  String get removeRepository => 'リポジトリを削除';

  @override
  String get addRepo => 'リポジトリを追加';

  @override
  String get extensionsNotInRepos => 'リポジトリ外の拡張機能';

  @override
  String get noLongerInRepo => 'リポジトリにリストされていません';

  @override
  String get addRepoToBrowse => 'プラグインを閲覧、更新するにはリポジトリを追加してください';

  @override
  String get debugExtensions => '拡張機能のデバッグ';

  @override
  String removeRepoConfirm(String repoName) {
    return '$repoName を削除しますか？';
  }

  @override
  String get removeRepoWarning => 'これによりリポジトリが削除され、含まれるすべてのプラグインがアンインストールされます。';

  @override
  String get addRepository => 'リポジトリの追加';

  @override
  String get repoUrlOrShortcode => 'リポジトリのURLまたはショートコード';

  @override
  String get assetPlugin => 'アセットプラグイン';

  @override
  String get installed => 'インストール済み';

  @override
  String get repositories => 'リポジトリ';

  @override
  String get noExtensionsInstalled => '拡張機能がインストールされていません';

  @override
  String get browseRepositoriesToInstall => '「リポジトリ」タブから拡張機能を探してインストールできます。';

  @override
  String get browseRepositories => 'リポジトリを見る';

  @override
  String get addRepoDescription =>
      'リポジトリの URL またはショートコードを追加して、拡張プラグインを探してインストールします。';

  @override
  String updateTo(String version) {
    return '$version に更新';
  }

  @override
  String get install => 'インストール';

  @override
  String get error => 'エラー';

  @override
  String get ok => 'OK';

  @override
  String pluginSettings(String pluginName) {
    return '$pluginName の設定';
  }

  @override
  String get movies => '映画';

  @override
  String get series => 'シリーズ';

  @override
  String get anime => 'アニメ';

  @override
  String get liveStreams => 'ライブ配信';

  @override
  String get debug => 'デバッグ';

  @override
  String extensionsUpdated(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個の拡張機能を更新しました',
    );
    return '$_temp0';
  }

  @override
  String get invalidNavigation => '無効なナビゲーションです。戻ってください。';

  @override
  String get startOver => '最初からやり直す';

  @override
  String get goBack => '戻る';

  @override
  String get resolving => '解決中...';

  @override
  String get downloaded => 'ダウンロード済み';

  @override
  String get download => 'ダウンロード';

  @override
  String get debugOnlyFeature => 'この機能はデバッグビルドでのみ利用可能です';

  @override
  String get streamUrl => 'ストリームURL';

  @override
  String get play => '再生';

  @override
  String get verifyingSourceSize => 'ソースとサイズを確認中...';

  @override
  String get fileSaveLocationNotification => 'ファイルはダウンロードフォルダに保存されます。';

  @override
  String get resumingPlayback => '再生を再開中';

  @override
  String pausedAt(String time) {
    return '$time で一時停止';
  }

  @override
  String resumesAutomatically(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 秒後に自動的に再開します',
    );
    return '$_temp0';
  }

  @override
  String get resumeNow => '今すぐ再開';

  @override
  String get playbackError => '再生エラー';

  @override
  String get confirmClearHistory => '視聴履歴のすべての項目を削除してもよろしいですか？';

  @override
  String seasonWithNumber(Object number) {
    return 'シーズン $number';
  }

  @override
  String get starting => '開始中...';

  @override
  String percentWatched(int percent) {
    return '$percent% 視聴済み';
  }

  @override
  String get sub => '字幕';

  @override
  String get dub => '吹替';

  @override
  String playEpisode(String label, Object season, Object episode) {
    return '$label 第$season期 第$episode話';
  }

  @override
  String playEpisodeOnly(String label, int episode) {
    return '$label E$episode';
  }

  @override
  String get debugTools => 'デバッグツール';

  @override
  String get playLocalVideo => 'ローカル動画ファイルを再生';

  @override
  String get playLocalVideoSubtitle => 'デバイス内の動画を再生';

  @override
  String get streamUrlSubtitle => 'ネットワークURLから再生';

  @override
  String get streamTorrent => 'トレントをストリーム再生';

  @override
  String get streamTorrentSubtitle => '再生するトレントファイルを選択';

  @override
  String get loadPluginFromAssets => 'アセットからプラグインを読み込む';

  @override
  String get enterVideoUrlHint => '動画URLを入力 (http, magnetなど)';

  @override
  String get networkStream => 'ネットワークストリーム';

  @override
  String removedFromHistory(String title) {
    return '履歴から「$title」を削除しました';
  }

  @override
  String get custom => 'カスタム';

  @override
  String get refreshingLiveStream => 'ライブ配信を更新中...';

  @override
  String get removeFromHistory => '履歴から削除';

  @override
  String get live => 'ライブ';

  @override
  String get volume => '音量';

  @override
  String get brightness => '明るさ';

  @override
  String get fit => 'フィット';

  @override
  String get zoom => 'ズーム';

  @override
  String get stretch => 'ストレッチ';

  @override
  String titleWithParam(String title) {
    return 'タイトル: $title';
  }

  @override
  String sourceWithParam(String source) {
    return 'ソース: $source';
  }

  @override
  String sizeWithParam(String size) {
    return 'サイズ: $size';
  }

  @override
  String usingInternalPlayerError(String error) {
    return 'エラー: $error. 内部プレイヤーを使用中。';
  }

  @override
  String playerNotDetected(String playerName) {
    return '$playerName が見つかりません。内部プレイヤーを起動します。';
  }

  @override
  String seasonWithEpisodes(Object number, int count) {
    return 'シーズン $number ($count エピソード)';
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
    return '$playerName のソースを選択';
  }

  @override
  String get noPluginsInstalled => 'プラグインがインストールされていません';

  @override
  String get noPluginsMessage => 'コンテンツの閲覧とストリーミングのために拡張機能をインストールしてください。';

  @override
  String get goToExtensions => '拡張機能へ移動';

  @override
  String get availableSources => '利用可能なソース';

  @override
  String get seasons => 'シーズン';

  @override
  String get episodes => 'エピソード';

  @override
  String get selectSourceToPlay => '上の「利用可能なソース」から再生するソースを選択してください。';

  @override
  String episodeCountOnly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count エピソード',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodesFound => 'エピソードが見つかりませんでした';

  @override
  String get local => 'ローカル';

  @override
  String get remote => 'リモート';

  @override
  String get torrent => 'トレント';

  @override
  String get unlock => 'アンロック';

  @override
  String get lock => 'ロック';

  @override
  String get sources => 'ソース';

  @override
  String get tracks => 'トラック';

  @override
  String get content => 'コンテンツ';

  @override
  String get stats => 'ステータス';

  @override
  String get resize => 'リサイズ';

  @override
  String get next => '次へ';

  @override
  String get pip => 'PiP';

  @override
  String get rotate => '回転';

  @override
  String get windowed => 'ウィンドウ';

  @override
  String get fullscreen => '全画面';

  @override
  String get movieDetails => '映画の詳細';

  @override
  String get showDetails => '詳細を表示';

  @override
  String get tagline => 'キャッチコピー';

  @override
  String get status => 'ステータス';

  @override
  String get releaseDate => '公開日';

  @override
  String get firstAirDate => '初回放送日';

  @override
  String get originalLanguage => '元の言語';

  @override
  String get originCountry => '製作国';

  @override
  String get budgetLabel => '予算';

  @override
  String get revenueLabel => '興行収入';

  @override
  String get paused => '停止中';

  @override
  String get watched => '視聴済み';

  @override
  String get watching => '視聴中';

  @override
  String get lastWatched => '後の視聴';

  @override
  String get movie => '映画';

  @override
  String get tvShow => 'ドラマ';

  @override
  String get failedToLoadContent => '読み込みに失敗しました';

  @override
  String get director => '監督';

  @override
  String get creator => 'クリエイター';

  @override
  String get showMore => 'もっと見る';

  @override
  String get showLess => '折りたたむ';

  @override
  String get viewAll => 'すべて表示';

  @override
  String seasonsCount(int count) {
    return '$count シーズン';
  }

  @override
  String get noInternetError => 'ネット未接続';

  @override
  String get timeoutError => 'タイムアウト。再試行してください。';

  @override
  String get serverError => 'サーバエラー。後でやり直してください。';

  @override
  String get contentNotFoundError => '見つかりませんでした。';

  @override
  String get accessDeniedError => '拒否されました。設定を確認してください。';

  @override
  String get serviceUnavailableError => 'サーバを利用できません。';

  @override
  String get generalError => '問題が発生しました。';

  @override
  String get skip => 'スキップ';

  @override
  String get skipIntro => 'オープニングをスキップ';

  @override
  String get skipOutro => 'エンディングをスキップ';

  @override
  String get skipRecap => 'あらすじをスキップ';

  @override
  String get goLive => 'ライブへ移動';

  @override
  String get dismiss => '閉じる';

  @override
  String get nextUp => '次のエピソード';

  @override
  String sourceAttempt(int index, int total) {
    return 'ソース $index / $total';
  }

  @override
  String get trying => '試行中';

  @override
  String get failed => '失敗';

  @override
  String get selected => '選択済み';

  @override
  String get playing => '再生中';

  @override
  String get pending => '保留中';

  @override
  String get openSubtitles => 'OpenSubtitles';

  @override
  String get subDl => 'SubDL';

  @override
  String get subSource => 'SubSource';

  @override
  String get wifiQualityPreference => 'Wi-Fi 画質設定';

  @override
  String get mobileQualityPreference => 'モバイルデータ通信 画質設定';

  @override
  String get anyNoPreference => '指定なし';

  @override
  String get subtitleAccounts => '字幕アカウント';

  @override
  String get accounts => 'アカウント';

  @override
  String get notLoggedIn => 'ログインしていません';

  @override
  String loggedInAs(String username) {
    return '$username としてログイン中';
  }

  @override
  String get apiKeyConfigured => 'API キー設定済み';

  @override
  String get keyNotSet => 'キーが設定されていません';

  @override
  String get testConnection => '接続テスト';

  @override
  String get connectedSuccessfully => '接続に成功しました';

  @override
  String get connectionFailed => '接続に失敗しました';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get noAccountRegister => 'アカウントをお持ちでないですか？ こちらで登録';

  @override
  String get apiKey => 'API キー';

  @override
  String get email => 'Email';

  @override
  String get fetchMyApiKey => 'API キーを取得';

  @override
  String get keyVerified => 'キーを確認しました';

  @override
  String get invalidApiKey => '無効な API キー';

  @override
  String get openSubtitlesAuthSubtitle =>
      'より高い制限と広告なしの字幕を利用するには、アカウント情報を入力してください。';

  @override
  String get subDlAuthSubtitle =>
      'SubDL API キーを直接入力するか、以下のアカウント情報を使用して取得してください。';

  @override
  String get orFetchViaAccount => 'またはアカウント経由で取得';

  @override
  String get subSourceAuthSubtitle =>
      'SubSource は設定なしで使用できますが、信頼性を高めるために個人の API キーを追加できます。';

  @override
  String get apiKeyOptionalOverride => 'API キー (オプション)';

  @override
  String get enterKeyToOverrideDefault => 'デフォルトを上書きするキーを入力';

  @override
  String get getApiKeyFromProfile => 'SubSource プロフィールから API キーを取得';

  @override
  String get qualityNotGuaranteed =>
      '画質は保証されません。ソースは好み順に並べられますが、再生はプロバイダーの提供状況によります。';

  @override
  String get keepSourcesOriginalOrder => 'ソースの元の順序を維持する';

  @override
  String get openLink => 'リンクを開く';

  @override
  String get diagnostics => '診断';

  @override
  String get viewLogs => 'ログを表示';

  @override
  String get viewLogsSubtitle => 'アプリのアクティビティとエラーを表示';

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
