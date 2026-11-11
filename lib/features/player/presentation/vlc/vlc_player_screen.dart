import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show BytesBuilder, Uint8List;

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart'
    show CancelToken, Options, ResponseBody, ResponseType;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart'
    show ProviderListenable;
import 'package:vlc_player/vlc_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/addons/models/addon_meta.dart' show kAddonItemSource;
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/network/clearance/clearance.dart';
import '../../../../core/network/dio_client_provider.dart';
import '../../../../core/network/http_defaults.dart';
import '../../../../core/network/link_probe_service.dart' show hlsVariantsOf;
import '../../../../core/providers/device_info_provider.dart';
import '../../../../core/providers/device_memory.dart';
import '../../../settings/presentation/player_settings_provider.dart';
import '../../../../core/extensions/providers.dart';
import '../../../../core/models/tmdb_details.dart';
import '../../../../core/models/torrent_status.dart';
import '../../../../core/services/download_service.dart';
import '../../../../core/services/local_proxy_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/storage/episode_watch_repository.dart';
import '../../../../core/storage/history_repository.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../core/utils/file_size_formatter.dart';
import '../../../../core/utils/stream_quality_sorter.dart'
    show qualityPreferenceHeight;
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/check_line.dart';
import '../../domain/episode_navigator.dart';
import '../../../skip/data/skip_service.dart';
import '../../domain/clear_key.dart';
import '../../domain/hls_video_length.dart';
import '../../domain/hls_quality.dart' show qualityLadderOf;
import '../../domain/live_window.dart';
import '../../domain/media_options.dart';
import '../../domain/playback_progress.dart';
import '../../domain/buffered_ahead.dart';
import '../../../../core/logger/app_logger.dart';
import '../../domain/network_buffer.dart';
import '../../domain/smoothness.dart';
import '../../domain/track_memory.dart';
import '../../domain/playback_recovery.dart';
import '../../domain/qoe_log.dart';
import '../../domain/recovery_policy.dart';
import '../../domain/source_check.dart';
import '../../domain/side_car_subtitles.dart';
import '../../domain/skip_segments.dart';
import '../../domain/source_row_status.dart';
import '../../domain/playback_tracker.dart';
import '../../domain/stream_resolver.dart';
import '../../domain/subtitle_search_target.dart';
import '../../domain/subtitle_style.dart';
import '../../domain/track_language.dart';
import '../player_debug_flags.dart';
import '../player_platform_service.dart';
import '../subtitle_search_provider.dart' show subtitleLanguageProvider;
import 'chrome_visibility_controller.dart';
import 'ended_card.dart';
import 'next_episode_countdown.dart';
import 'player_startup_view.dart';
import 'panel/player_panel.dart';
import 'panel/player_panel_labels.dart' show sourceFactsOf;
import 'player_value_selector.dart';
import 'resume_hint.dart';
import 'side_car_fetch.dart';
import 'side_car_subtitle_view.dart';
import 'source_check_provider.dart';
import 'torrent_file_sheet.dart';
import 'vlc_player_controls.dart';

/// Playback on the VLC engine.
///
/// A hub: liveness, resume, failover, recovery, ClearKey, side-car subtitles
/// and the platform's PiP and orientation all live in files that can be tested
/// without an engine. What is left here is when to call them.
class VlcPlayerScreen extends ConsumerStatefulWidget {
  const VlcPlayerScreen({
    required this.item,
    required this.videoUrl,
    this.episode,
    this.preloadedStreams,
    super.key,
  });

  final MultimediaItem item;

  /// The plugin's resolution token, not a URL. See [resolvePlayback].
  final String videoUrl;

  final Episode? episode;

  /// Sources already aggregated by a source sheet. When present, no plugin
  /// call is made.
  final List<StreamResult>? preloadedStreams;

  @override
  ConsumerState<VlcPlayerScreen> createState() => _VlcPlayerScreenState();
}

enum _Stage { resolving, playing, failed }

/// What an end-of-media advance did, which is what the ended card answers.
///
/// The outgoing engine delivers a late `ended` while the next episode is
/// loading, so "an advance is in flight" and "nothing follows" must stay
/// distinct or a card is raised over an episode about to play.
enum _Advance {
  /// The next episode is loading, or an advance already in flight owns the
  /// transition. There is nothing to card.
  playing,

  /// Nothing follows: a film, or the last episode located in the list.
  finished,

  /// An episode follows, but the viewer declined it during the credits, so it
  /// was not started. The refusal is honoured and the card offers the episode
  /// back rather than the advance taking it anyway.
  declined,
}

/// How often the stall watchdog looks. One second is far finer than any of its
/// thresholds and costs nothing — the check is arithmetic on two counters.
const Duration _kWatchdogTick = Duration(seconds: 1);

/// How recently the source must have delivered bytes for a frozen picture to
/// count as a refill rather than a stall. See `_bytesArriving`.
const Duration _kArrivalWindow = Duration(seconds: 5);

/// How soon after a seek a stall must begin to count as that seek's refill.
const Duration _kAfterSeekSlack = Duration(seconds: 2);

/// How long after Back has put the bars away a second Back is taken for the
/// same press. Some televisions deliver one press twice — as a key event and
/// as a `popRoute` in the same frame — and without this the echo would pop the
/// route the first delivery had just decided to keep. Short enough not to eat
/// a deliberate second press.
const Duration _kBackEcho = Duration(milliseconds: 300);

/// How long a locked screen gives the viewer to confirm that Back really did
/// mean "leave", after the first press was spent revealing the unlock chip.
///
/// Longer than [_kBackEcho], so the same-press echo is always swallowed
/// inside it.
const Duration _kLockBackEscape = Duration(seconds: 2);

/// The opaque panel that covers the video between `setMedia` and the first
/// frame. Public because the invariant it stands for — that the viewer is
/// never shown a black rectangle with a seek bar over it — is worth a test.
const Key openingOverlayKey = Key('player-opening-overlay');

/// How far from the end the up-next card appears. Matches the card's own
/// countdown, so the offer and the advance land at roughly the same moment.
const Duration _kNextEpisodeLeadIn = Duration(seconds: 15);

/// How far libVLC's length for an HLS stream may run past the video's own
/// before it is capped. Audio tracks routinely outlast the picture by a
/// fraction of a second; anything past this is a playlist claiming more than
/// there is. Kept under the two seconds [_handleEnded] allows, so a length
/// left alone here cannot turn a real ending into a truncated one.
const Duration _kLengthSlack = Duration(seconds: 1);

/// How long measuring an HLS stream may wait on one playlist.
const Duration _kPlaylistTimeout = Duration(seconds: 8);

/// How much of an answer is read before deciding whether it is a playlist at
/// all, and the most of one that is read: a three-hour media playlist is
/// under 2 MB.
const int _kPlaylistHeadBytes = 64;
const int _kPlaylistMaxBytes = 4 << 20;

class _VlcPlayerScreenState extends ConsumerState<VlcPlayerScreen>
    with WidgetsBindingObserver, WindowListener {
  /// The screen owns the controller, and its lifetime is exactly this State's.
  late final VlcPlayerController _controller;

  /// Whether the bars are up. Owned here rather than by the controls: Back
  /// puts them away before it ever pops (see [_hideChromeForBack]), and they
  /// must outlive the controls, which come and go with [_sawFrames] across
  /// every failover and episode advance.
  late final ChromeVisibilityController _chrome;

  /// Armed when Back has just put the bars away; while it runs a second Back
  /// is the same press arriving again. A Timer rather than a timestamp so
  /// teardown can cancel it and the test clock can run it out.
  Timer? _backEcho;

  /// Whether the screen is locked against accidental touches.
  ///
  /// Owned here, not by [VlcPlayerControls]: Back is decided in [_handleBack]
  /// and has to be able to read this, and it outlives the controls, which are
  /// rebuilt on every failover and episode advance.
  ///
  /// Lent to the controls only on `PlayerFormFactor.isTouch`, so there is no
  /// padlock on a television or a desktop. Never written from here except to
  /// clear it; only the padlock sets it.
  final ValueNotifier<bool> _locked = ValueNotifier<bool>(false);

  /// How far ahead of the playhead the stream has been fetched, as a fraction
  /// of the media, for the seek bar's buffered band.
  ///
  /// A notifier rather than state: this moves on every stats sample and the
  /// bar is the only thing that cares, so rebuilding the chrome for it would
  /// undo the work that stopped a position tick repainting everything.
  final ValueNotifier<double> _bufferedFraction = ValueNotifier<double>(0);

  /// Turns the byte counters into the seek bar's buffered band, and keeps
  /// that estimate honest across seeks. All of the arithmetic lives in the
  /// domain layer, where it can be tested a sample at a time.
  final BufferedAheadEstimator _bufferedAhead = BufferedAheadEstimator();

  /// The window in which a second Back means "I really do want out".
  ///
  /// Armed by the first Back arriving on a locked screen, which is spent on
  /// revealing the unlock chip. Deliberately separate from [_backEcho]:
  /// merging them would make one press delivered twice read as an escape.
  Timer? _lockEscape;

  _Stage _stage = _Stage.resolving;

  /// Guards a row picked on the startup view against remote key-repeat; see
  /// [_pickFromStartup]. Held as a Timer so teardown can cancel it - a bare
  /// delayed future outlives the State.
  Timer? _pickCooldown;
  String _error = '';

  /// Shown under the spinner while opening, when there is something worth
  /// saying - a cold magnet link can take a long time to become playable.
  String _status = '';

  /// Why the last source was given up on, shown under the source line while
  /// the next one opens. Its own field rather than a write to [_status]:
  /// [_run] and the [_openAttempt] it calls run in one synchronous
  /// stretch, so the status line is overwritten before a frame is drawn.
  /// Cleared by the first frame.
  String? _failReason;
  bool _disposed = false;

  PlaybackProgressRecorder? _recorder;
  PlaybackTracker? _tracker;

  /// The last position/duration pair observed while playback was actually
  /// running. Teardown writes this rather than asking the engine, because by
  /// then the engine reports zero — see playback_progress.dart.
  ///
  /// Scoped to one attempt: a sample left over from the previous source would
  /// answer for the wrong media. Where to resume outlives the attempt and is
  /// kept in [_resumePosition].
  ProgressSample? _sample;

  /// Whether the current attempt has produced any playback at all.
  ///
  /// Distinct from `_sample != null`: a livestream reports no duration and a
  /// short clip is below the resumable threshold, so neither produces a sample
  /// despite playing.
  bool _sawFrames = false;

  /// Whether a same-source reopen is showing the last picture of the attempt
  /// before it (spec 2, *The reopen*: "the picture stays").
  ///
  /// Apart from [_sawFrames] on purpose. That one says this attempt has
  /// played, and the first-frame watch and the stall watchdog depend on it:
  /// kept true through a reopen, an open that never starts would never be
  /// given up on, and the nudge would seek a media still opening. What the
  /// screen shows asks [_pictureUp].
  bool _keptPicture = false;

  /// Whether a picture is on screen: this attempt's own, or one kept from the
  /// attempt before.
  bool get _pictureUp => _sawFrames || _keptPicture;

  /// Whether the media this attempt opened is HLS or DASH, which libVLC's
  /// adaptive module plays: no stall nudge, no rendition step-down for
  /// anything else.
  bool _adaptive = false;

  /// The VlcPlayer's key: moving it on mounts a new one, which makes a new
  /// native player. See [_checkFirstFrame].
  int _playerMount = 0;

  /// The attempt whose media has already been given a new VlcPlayer, once.
  int? _remountedFor;

  /// Whether the engine has been handed this attempt's media yet.
  ///
  /// Until it has, every tick describes the outgoing media: the engine keeps
  /// playing what it had through the download lookup, the resolve and the
  /// proxy handshake that precede `setMedia`. Such a tick means playback is
  /// alive and nothing more.
  bool _handedToEngine = false;

  /// Where playback should pick up: the last position actually observed, or
  /// the stored resume point until the first sample lands.
  ///
  /// Survives failover, because `setMedia` has already zeroed the controller's
  /// own position by the time a retry runs.
  Duration _resumePosition = Duration.zero;

  /// Identifies this media session. Stamped onto every sample so a value that
  /// still describes the previous media cannot be written against this one.
  int _token = 0;

  /// The pre-resolution source URL, which is what the resolver's saved-source
  /// lookup matches on. Deliberately not the proxied URL.
  String? _lastStreamUrl;

  ResolvedPlayback? _resolved;
  ResumePoint? _initialResume;

  /// The candidate list as soon as resolution knows it, which is well before
  /// it knows which one to open. Held apart from [_resolved] so there is
  /// something to show the viewer during that decision.
  List<StreamResult> _candidates = const <StreamResult>[];

  /// How each probed candidate is doing, in the order the probes were
  /// dispatched — which is also the failover order, so the first entry still
  /// reading `trying` is the source the player is waiting on.
  final Map<int, ProbeOutcome> _probes = <int, ProbeOutcome>{};

  /// Identifies the resolve in flight. Bumped by every [_start] and carried by
  /// the callbacks resolve hands out, so an answer from a superseded resolve is
  /// dropped rather than written.
  ///
  /// Late probes are real: the race reports candidates that answer after it is
  /// over, and [_candidates] and [_probes] are keyed by index into a list an
  /// episode advance may already have replaced.
  int _resolveGeneration = 0;

  /// The media the published source list describes.
  ///
  /// The keep-previous rule in [_publishPanelData] needs to tell a re-resolve
  /// of this episode from an advance to the next one.
  Object? _publishedSourcesMedia;

  /// Completed with a row the viewer picked while the health probe was still
  /// racing; the resolver ends the race on it. Null once resolution is past
  /// the race.
  Completer<int>? _pick;

  /// Completed when this screen stops waiting on the resolve in flight - it
  /// closed, or a new resolve replaced it - so the reachability check stops
  /// and nothing it armed outlives the screen.
  Completer<void>? _abandonResolve;

  /// Whether this resolve has yet to open anything. True from [_start] until
  /// it hands its choice to [_openAttempt]: in that window a pick has nothing
  /// to switch away from, so it becomes [_start]'s choice instead of racing it.
  bool _awaitingFirstOpen = true;

  /// A row picked after the race ended but before the first open began, for
  /// [_start] to open in place of the resolver's own choice.
  int? _pickedBeforeOpen;

  /// Rows that were opened this resolve and would not play, or stopped. Keyed
  /// the way [_candidates] is indexed, and cleared with it.
  final Set<int> _failedRows = <int>{};

  /// Rows that have shown a picture this resolve. A picture is proof of reach
  /// no probe can beat, so the source lists call these reachable whatever the
  /// probe said - or, for a torrent or a local file, could not say.
  final Set<int> _playedRows = <int>{};

  /// The plugin this resolve is asking, by its own name, for the startup view
  /// to say who it is waiting on. Null when no plugin is involved: a local
  /// file, a direct link, or sources a sheet already gathered.
  String? _pluginName;

  /// When the plugin was asked for links: a bot check met since is the one
  /// the startup view waits on.
  DateTime? _linksAskedAt;

  /// The bot checks the app meets, for the startup view's line.
  StreamSubscription<void>? _checkChanges;

  /// Counts the seconds of the check the links wait on, while it's tried.
  Timer? _checkTick;

  /// The episode currently playing. Mutable because advancing swaps media on
  /// this same State rather than pushing a new route.
  Episode? _episode;

  /// The plugin token for [_episode]. Starts as the route's, then follows.
  late String _videoUrl;

  /// Sources the route pre-aggregated. They belong to the FIRST episode only,
  /// so advancing must drop them or the next episode plays this one's streams.
  List<StreamResult>? _preloaded;

  /// One advance at a time. The engine's ended event, a retry and any future
  /// button can all land within the same second.
  bool _advancing = false;

  /// Cancellation token for the open chain. Bumped on every attempt, so a
  /// failover that completes late cannot overwrite a newer one.
  int _generation = 0;
  int _attemptIndex = 0;

  /// What recovery does next (spec 2, *What happens next*): the checks, the
  /// back-off, the waits, the budgets, the walk and the session cap. Told
  /// every resolve's candidates, every open, picture and move, and every
  /// failure with its sign.
  late final RecoveryPolicy _policy = RecoveryPolicy(
    resuming: () => _reopenTarget() > Duration.zero,
  );

  /// The one timer recovery asks for, at its next due time.
  Timer? _recoveryTimer;

  /// Moves on with every open and resolve, so a check's answer for one that
  /// has gone is dropped.
  int _checkGeneration = 0;

  /// Whether the failed source is parked over its picture: the same media
  /// set again, held, not told to play (plan note 1). Until the next open.
  bool _parked = false;

  /// Lets the display sleep at the end of a long wait; see
  /// [_keepAwakeThroughWait].
  Timer? _waitAwake;

  /// Whether this attempt opened paused, and waits for the viewer's play
  /// before it has anything to be late for.
  bool _awaitingPlay = false;

  /// The controller's pause requests when the last failure came in: a pause
  /// since then is the viewer's, and the reopen opens paused (decision 15).
  int _pauseRequestsAtFailure = 0;

  /// What the last failure said, for the start-up view's line when the
  /// reopen after it can't keep the picture.
  String _lastFailureDetail = '';

  /// Whether [SubtitleDefault.off] still applies to the media this attempt
  /// opened. Read the whole rule on [_applySubtitleDefault]; false for the
  /// entire life of the screen under [SubtitleDefault.auto], which is what
  /// makes Auto exactly what it was before the setting existed.
  bool _subtitlesOffPending = false;

  /// The subtitle id the Off rule last asked the engine to drop. A run of
  /// ticks still naming it is the same fact restated, not a second one to act
  /// on - without this the rule would re-send `disableSubtitle` four times a
  /// second at an engine that is ignoring it.
  int? _subtitleOffAsked;

  /// Whether the current attempt is a torrent, which is allowed far longer to
  /// produce its first frame — it is waiting on pieces, not on a socket.
  bool _attemptIsTorrent = false;

  /// When the current attempt's clocks started, and how long the position
  /// has stood still: the watchdog's whole input, on the wall clock (spec 2:
  /// "It counts wall-clock time, not ticks"). A minute the device slept
  /// counts as a minute, so a connection that died while a laptop slept is
  /// caught as it wakes; a clock correction while playback moves counts as
  /// nothing ([StallClock]).
  DateTime _attemptStartedAt = clock.now();
  final StallClock _stallClock = StallClock();

  /// How long the current attempt has been running, on the wall clock.
  Duration get _attemptAge => clock.now().difference(_attemptStartedAt);

  /// How long the position has stood still.
  Duration get _stalledFor => _stallClock.stalledFor;

  /// Set when the stall count starts again, until the next tick: that tick
  /// belongs to the video-health watchdog, as one where the position moved
  /// does.
  bool _stallRestarted = false;

  /// How long the current attempt has played, counted by the watchdog's tick
  /// while playback is expected: the buffered-ahead estimator's time base.
  /// Its rates are bytes per second of playback, and the minutes a pause
  /// adds to the wall clock would read as a skip.
  Duration _playingAge = Duration.zero;

  /// Watches for a picture frozen while the sound plays on (plan note 5).
  final StarvedVideoWatch _starved = StarvedVideoWatch();

  /// The current attempt's first-frame watch, from the open until its first
  /// picture (plan note 6), and the attempt it watches.
  FirstFrameWatch? _firstFrame;
  int _firstFrameGeneration = -1;

  /// Set while a sample for [_firstFrame] is in flight.
  bool _firstFrameSampling = false;

  /// Whether this attempt's media has run - playing or buffering - since it
  /// opened: a pause or a stop nobody asked for is an edge from running, never
  /// a state an open starts in.
  bool _ranSinceOpen = false;

  /// The controller's pause requests when playback last ran: a pause or a
  /// stop since with none asked for is a failure (spec 2, Detection).
  int _pauseRequestsWhenRunning = 0;

  /// Set once this attempt's stop nobody asked for has been reported.
  bool _stopReported = false;

  /// The highest watchdog rung already fired for the current stall, so each
  /// fires once. Cleared the moment the position moves.
  StallAction _lastStallAction = StallAction.none;
  Timer? _watchdog;

  /// This screen's QoE record: what each attempt did and when. See [QoeLog].
  late final QoeLog _qoe;

  /// Samples resident memory into [_qoe] every 10 s.
  Timer? _qoeMemory;

  /// What [_qoeObserve] and [_qoeSeekChanged] last saw, so they record edges
  /// rather than levels.
  bool _qoeStalled = false;
  bool _qoeTracksKnown = false;
  int? _qoeAudio;
  int? _qoeSubtitle;
  Duration? _qoeSeekTarget;
  int _qoeSeekRequests = 0;
  int? _qoeIndex;

  /// The tallest adaptive rendition this device may be handed.
  ///
  /// Seeded in [initState] — see [adaptiveMaxHeightFor] — and lowered a rung
  /// at a time when the decoder proves it cannot keep up under Auto. What a
  /// source opens with is [_renditionCap], which this bounds.
  late int _adaptiveMaxHeight;

  /// The seeded cap. It goes on the instance config, whose options are fixed
  /// at construction, so a cap that differs from it rides on the media.
  late final int _deviceAdaptiveMaxHeight;

  /// Whether this screen decodes in software since MediaCodec stopped
  /// producing pictures ([_retryInSoftware]). For the screen's life.
  bool _softwareRetry = false;

  /// The cap the media now playing was opened with - see [renditionCapFor]:
  /// the smaller of [_adaptiveMaxHeight] and the quality preference. What a
  /// step-down lowers from.
  late int _renditionCap;

  /// The quality preference's height when the media now playing was opened,
  /// or null for Any: Auto's cap until the next open reads the preference
  /// again.
  int? _preferenceHeightAtOpen;

  /// The read-ahead the open in progress asked for (spec 1.2): what the
  /// buffered band measures against.
  BufferPlan? _bufferPlan;

  /// The live HLS playlist this attempt opened, until its target duration is
  /// read ([_maybeReadLiveSegment]).
  ({Uri uri, Map<String, String> headers})? _liveMedia;

  /// A live HLS stream's target duration, which sets the stretch of its window
  /// the controls offer; null until read, and the window assumes 10 s.
  Duration? _liveSegment;

  /// A seek in a live window on its way ([_seekInLiveWindow]): the place in
  /// the stream's own timeline it means, how far behind live that is, and
  /// whether it was LIVE's.
  ({Duration target, Duration behind, Duration segment, bool toLive})?
  _liveSeek;

  /// The live delay the next open asks for, once, instead of
  /// [kLiveDelayMs]: a window seek libVLC didn't take reopens that far back.
  int? _nextLiveDelayMs;

  /// The quality the viewer picked in the Quality tab, as the cap it asks
  /// for, or null for Auto. Holds for the rest of this player session -
  /// failovers and the next episodes open under it too - and a step-down
  /// lowers it as it lowers Auto's.
  int? _qualityPick;

  /// The heights the HLS stream playing offers, tallest first, for the
  /// Quality tab; empty for anything else. See [_maybeReadQualityLadder].
  List<int> _qualityLadder = const <int>[];

  /// The source (its URL, before any proxy) [_qualityLadder] was read from
  /// or is being read from; null when none is.
  String? _qualityLadderOf;

  /// What this attempt's ladder would be read from: the address libVLC was
  /// given, its headers, and the source they open. Per attempt; null for
  /// media that is not HLS.
  ({Uri uri, Map<String, String> headers, String source})? _qualityMedia;

  /// The decoder counters when the current measurement window opened, and how
  /// much of the window has been covered so far.
  ///
  /// Deltas from here are what [videoHealthFor] reads, so the ragged first
  /// seconds after an open are the baseline rather than the evidence. Null
  /// until the first sample of an attempt lands.
  ({int displayed, int lost, int corrupted, int discontinuity, int decoded})?
  _videoBaseline;

  /// The last smoothness verdict logged, so a steady state is reported once
  /// rather than every window.
  PlaybackSmoothness _lastSmoothness = PlaybackSmoothness.unknown;
  Duration _videoWindow = Duration.zero;

  /// Whether a stats request is in flight, so a slow platform round trip
  /// cannot queue a second behind itself on the next tick.
  bool _statsInFlight = false;

  /// `readBytes` at the last stats sample, and when it was last seen to grow,
  /// on [_attemptAge]'s clock. What tells a frozen picture over a source that
  /// is still refilling from one over a source gone quiet - see
  /// [_bytesArriving].
  int? _arrivalReadBytes;
  Duration? _bytesArrivedAt;

  /// When the viewer last seeked, on [_attemptAge]'s clock: a stall that
  /// begins with one has a refill ahead of it - see [kStallNudgeAfterSeek].
  Duration? _lastSeekAt;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;

  /// Whether the network is metered: asked once as the screen opens, then
  /// kept current by connectivity events (spec 1.8), so an open reads a kept
  /// answer instead of asking the platform again.
  late Future<bool> _metered;

  /// The device's memory, read at the screen's start and again after each
  /// plan, for the next open: a read is a platform call, up to 0.14 s on the
  /// phone emulator, and no open should wait on one (spec 1.2: every open
  /// reads; it uses the reading taken since the last).
  late Future<DeviceMemory> _memory;

  /// Whether the app is on screen. A backgrounded player freezes its position
  /// legitimately, and recovering from that would reopen sources nobody is
  /// watching.
  bool _foreground = true;

  /// Android picture-in-picture, as the activity reports it.
  ///
  /// Drives the chrome as well as the watchdog: at PiP size the bars are an
  /// unreadable smear over most of the frame, so the window renders the video
  /// and nothing else.
  bool _inPip = false;

  /// A PiP start held as imminent, without a window yet.
  ///
  /// Set on iOS `inactive` (see [didChangeAppLifecycleState]) so the
  /// background pause holds off until the native side starts the window
  /// from `didEnterBackground` — or the app comes back. Cleared when the
  /// window opens or fails ([_onPictureInPicture]), when the button
  /// takes over ([_enterPip]), and on `resumed` when no window opened
  /// (Control Center). Without it a transient foreground interruption
  /// that never backgrounds the app would hold the pause off forever.
  bool _pipImminent = false;

  /// The PiP attempt's watchdog: how long the window has to open.
  ///
  /// [_enterPip] sets [_inPip] before the native request goes out, and the
  /// window unmounts the whole controls subtree while it is true. The native
  /// start only says the request went out - the window opening, or failing
  /// to, is reported through [_onPictureInPicture] - so a start the system
  /// silently drops (no window, no event) would leave the player with no
  /// touch handling at all until the app was backgrounded and foregrounded
  /// again. The watchdog takes the chrome back after this long with no
  /// confirmation, and closes the attempt.
  ///
  /// Five seconds, deliberately longer than the native side's own three:
  /// the native gate gives up at three seconds and reports the failure
  /// itself, so the watchdog only ever fires when no event arrived at all —
  /// and the two must never race to restore the chrome.
  Timer? _pipWatchdog;

  /// Which PiP attempt the watchdog belongs to, so a stale timer cannot
  /// undo a newer one.
  int _pipAttempt = 0;

  /// Whether the PiP attempt in flight came from the PiP button (true) or
  /// from leaving the app (false). Only a button tap gets a "didn't open"
  /// message: an auto-start that fails while the app is away is not something
  /// the viewer is looking at, and a message for it would land on the Home
  /// screen when they come back.
  bool _pipAttemptFromButton = false;

  /// Whether the window actually opened for the attempt in flight. A false
  /// `pictureInPicture` event with this still false means the start failed,
  /// not that the viewer closed a window — the two need different words.
  bool _pipWindowOpened = false;

  /// Mirrors the engine's playing flag so the PiP window's middle button can be
  /// re-sent only when it actually flips.
  bool _wasPlaying = false;

  /// Edge detectors. `VlcPlayerValue` is level-triggered and the native error
  /// is sticky until the next setSource, so without these one dead source
  /// produces an unbounded failover storm.
  bool _sawError = false;
  bool _sawEnded = false;

  /// Decided from the item and URL at open time rather than from the engine,
  /// because it governs buffering and what end-of-media means.
  bool _isLive = false;

  /// A livestream has no position worth sampling, so it is written to history
  /// once per session rather than on every tick.
  bool _recordedLivestream = false;

  /// The last position observed, used to tell real playback from a stuck state
  /// enum.
  Duration _lastSeenPosition = Duration.zero;

  /// Seeks the watchdog has already forgiven, so a new one can be spotted.
  int _seenSeekRequests = 0;

  /// The audio and subtitle the viewer was on, carried across a reopen.
  ///
  /// Scoped to the content, not the session: [_startEpisode] clears them,
  /// because the next episode's tracks are its own. Within one episode every
  /// reopen - a failover to another provider, a same-source recovery, a
  /// rendition step-down - is the same film, so the pick still means something.
  RememberedTrack? _rememberedAudio;
  RememberedTrack? _rememberedSubtitle;

  /// The audio track the viewer put on from the Audio tab, for this content.
  ///
  /// The one audio choice that is the viewer's own. [_rememberedAudio] is
  /// whatever was playing - the engine's default, a reopen's restore, the
  /// audio language setting's pick - and the setting outranks it on each
  /// media it opens; this outranks the setting wherever it goes back on
  /// ([_viewerAudioOutranks]), and the setting is what is left where it does
  /// not. Set only by a row the viewer picks ([_onAudioPicked]), never by
  /// opening the panel, and cleared with the content by [_startEpisode].
  RememberedTrack? _viewerAudio;

  /// The source [_viewerAudio] was picked on, by its URL: the copy of the
  /// film on which a pick that names no language still means a track.
  String? _viewerAudioCopy;

  /// The source of the media the engine was last handed, by its URL - what is
  /// playing, through the setup of the next attempt as well.
  String? _engineStreamUrl;

  /// Whether [_audioToRestore] is the viewer's own pick, and goes back on
  /// ahead of the audio language setting: the pick names its language, or
  /// this media is the very copy it was picked on. Elsewhere a pick that
  /// names none cannot be told - `Track 2` is any track at all on another
  /// copy - so the setting goes first, and the pick is only put back where
  /// the media lacks the language. Per attempt.
  bool _viewerAudioOutranks = false;

  /// What the media this attempt opened is put back on once it lists its
  /// audio: the viewer's own pick, or failing one whatever was playing as it
  /// opened. Taken per attempt, so that what this media plays meanwhile
  /// cannot overwrite it, and spent by the first look.
  RememberedTrack? _audioToRestore;

  /// The audio track this screen put on - or found on and kept - for the
  /// media this attempt opened ([_switchAudio]). Any other track playing is
  /// libVLC's own choice. Cleared per attempt.
  int? _audioPutOn;

  /// The audio language setting, while it still owes the media this attempt
  /// opened its look ([_pickPreferredAudio]). Armed per attempt, and spent
  /// once the media is on its track in the language or on the viewer's own
  /// pick - or the viewer picks one on it.
  String? _preferredAudioToPick;

  /// The track list revision the last look for [_preferredAudioToPick] read:
  /// the next look waits for the list to change, not for the next tick.
  int? _preferredAudioCheckedRevision;

  /// Set while a look for [_preferredAudioToPick] is in flight.
  bool _pickingPreferredAudio = false;

  /// The subtitle [_restoreTracks] came to put back and did not find: the new
  /// media had not listed it yet - a reopened MKV lists its audio first. It
  /// is looked for again on each change to the list ([_maybeRestoreSubtitle])
  /// until it is on, or until the viewer picks for themselves.
  RememberedTrack? _subtitleToRestore;

  /// The track list revision the last look for [_subtitleToRestore] read.
  int? _subtitleRestoreRevision;

  /// Set while a look for [_subtitleToRestore] is in flight.
  bool _restoringSubtitle = false;

  /// The ids the last snapshot reported, so a change can be spotted without
  /// asking the engine for its track list on every tick.
  int? _seenAudioTrackId;
  int? _seenSubtitleTrackId;

  /// Set by [_openAttempt], cleared once the picks have been put back.
  bool _restorePending = false;

  /// The subtitle files of what is playing - the source's and any the viewer
  /// added - which SkyStream draws itself rather than handing to libVLC. See
  /// [SideCarSubtitles].
  late final SideCarSubtitles _sideCars = SideCarSubtitles(
    fetch: (url, headers) => _read(sideCarFetchProvider)(url, headers),
    onUnreadable: _handSideCarToEngine,
    // Kept in step by [_onPlayerSettings], which reads the files already
    // fetched again when it changes.
    encoding:
        _read(playerSettingsProvider).asData?.value.subtitleEncoding ?? '',
  );

  /// Whether Auto still owes this media its look for a subtitle in the
  /// viewer's language among the tracks inside the video - see
  /// [_pickPreferredSubtitle]. Armed per attempt, spent once the video has
  /// published its tracks.
  bool _autoPickPending = false;

  /// Whether the viewer has opened the panel on this media, which is where
  /// every subtitle choice is made. Auto never overrides one.
  bool _viewerChoseSubtitle = false;

  /// What Auto last looked at: the track list's revision, and whether the
  /// media had begun to play. A change to either brings another look - see
  /// [_pickPreferredSubtitle].
  (int, bool)? _autoPickLook;

  /// Set while one of Auto's looks is in flight, so a revision that moves
  /// meanwhile does not start a second.
  bool _autoPicking = false;

  /// The last non-zero length the engine reported for this attempt.
  ///
  /// [_handleEnded] tells a finished film from a truncated one by numbers, and
  /// [_sample] is refused below [kMinResumableDuration] and never written for
  /// a source whose length libVLC never learned. Per attempt, and sticky
  /// within one: the engine reports zero again the moment it reaches the end.
  Duration _lastSeenDuration = Duration.zero;

  /// The address and headers libVLC was given for this attempt, kept when it
  /// is an HLS playlist whose real length may need reading - see
  /// [_checkReportedLength]. Per attempt.
  ({Uri uri, Map<String, String> headers})? _hlsMedia;

  /// Whether this attempt's video has been measured yet, and what it came to.
  bool _videoLengthAsked = false;
  Duration? _videoLength;

  /// This attempt's read of the playlist libVLC was given: asked for once,
  /// and shared by the length check and the Quality tab's ladder. Per attempt.
  ({Uri uri, Future<String?> playlist})? _openedPlaylist;

  /// Desktop window state, mirrored so the button icon can follow it.
  ///
  /// Written only from the window's own events and the seed read in
  /// [initState], never from our own toggle: the window is also moved by the
  /// app-wide F11 handler, the macOS green button and the Window menu.
  bool _isFullscreen = false;

  /// Whether the window has spoken for itself yet.
  ///
  /// The seed read issued during [initState] can complete after an event that
  /// has already moved the flag, so anything the window says outranks it.
  bool _windowSpoke = false;

  /// How the video is scaled, seeded once from the viewer's default resize
  /// mode and then left alone.
  ///
  /// Deliberately not reactive to the setting: a value that moved under the
  /// controls would overwrite whatever the viewer had just picked. Mutable
  /// because the resize button reports back through onFitChanged, and on the
  /// texture platforms this is the value that does the work.
  late VlcVideoFit _fit;

  /// Pinch-to-zoom scale on the video: two fingers scale the picture on top
  /// of [_fit], like MX Player / VLC, from 0.5x to 3.0x — so an inward pinch
  /// can also make the picture smaller than the screen fit. Reset to 1.0
  /// whenever a new media opens (see [_openAttempt] and [_park]).
  ///
  /// A notifier, not a plain double: the pinch is driven by the controls'
  /// gesture layer (see `VlcPlayerControls.videoScale`), and a ValueNotifier
  /// lets the `Transform` repaint on every update without rebuilding the
  /// whole screen out from under the gesture.
  final ValueNotifier<double> _videoScale = ValueNotifier<double>(1.0);

  /// The video widget's key, so the PiP source rect can be read off the
  /// picture itself: the system needs the video's real on-screen frame to
  /// open the window, and a 1x1 host is treated as not-displaying (see
  /// [_videoContentRect]). Attached to the [VlcPlayer] below through a
  /// [KeyedSubtree], so the player's own remount key is untouched.
  final GlobalKey _videoKey = GlobalKey();

  /// The source sheet's own context while it is open, so Back has something to
  /// close. Null whenever the video is the only thing on screen.
  BuildContext? _sheetContext;

  /// Whether this session ever started the torrent engine, so teardown only
  /// stops something it actually started.
  bool _startedTorrent = false;

  /// Whether [_handBack] has run: Back runs it as the route starts to leave,
  /// and [dispose] would otherwise ask again.
  bool _handedBack = false;

  /// Intro/outro bands for the current episode. Usually empty: both sources
  /// are opt-in and off by default.
  List<SkipSegment> _skipSegments = const <SkipSegment>[];

  final PlayerPlatformService _platform = PlayerPlatformService();

  /// The orientation policy this device wants. Derived in [build] from the
  /// device profile, which can still be resolving when playback starts;
  /// [PlayerFormFactor.unknown] makes every orientation call a no-op, so an
  /// early frame pins nothing and therefore needs nothing restored.
  PlayerFormFactor _form = PlayerFormFactor.unknown;

  /// The next episode, once playback is close enough to the end to offer it.
  /// Null whenever the card is not up.
  Episode? _nextEpisodeOffer;

  /// The viewer said no. One refusal per episode - re-offering the card three
  /// seconds later is the behaviour "cancel" exists to prevent. Honoured at
  /// end of media too: a declined episode does not start itself when the
  /// credits run out.
  bool _nextEpisodeDeclined = false;

  /// Why playback stopped with nothing playing after it, or null while it is
  /// still going. Non-null is what puts [EndedCard] up.
  ///
  /// Deliberately not a [_Stage]: switching on the stage swaps the Scaffold's
  /// child, and that would unmount the native view out from under the engine.
  EndedKind? _ended;

  /// Whether the start-over affordance is up, and whether this session has
  /// already had its turn. Shown once, on the first frame after a resume point
  /// was applied - not again after every failover.
  bool _showResumeHint = false;
  bool _resumeHintOffered = false;

  /// Live torrent statistics, polled only while a torrent is actually playing.
  TorrentStatus? _torrentStatus;
  Timer? _torrentPoll;

  /// Guards against a slow poll overlapping the next tick, which would queue
  /// requests against the torrent server rather than skipping a beat.
  bool _pollingTorrent = false;

  /// The torrent file the viewer picked, and its server-side id. The label
  /// replaces the title, because inside a season pack "Show S02" says nothing
  /// about which episode is on screen.
  String? _torrentFileLabel;
  int? _torrentFileIndex;

  /// What the side panel shows, published by [_publishPanelData] from every
  /// place one of its inputs changes, so a failover, a late probe or a torrent
  /// poll reaches an open panel in place. Screen-owned rather than a provider
  /// because none of its inputs lives in one.
  final ValueNotifier<PanelData> _panelData = ValueNotifier<PanelData>(
    PanelData.empty,
  );

  /// The viewer's player settings as they stand, for the panel's Subtitle
  /// style page, which reads no providers. Republished on every change - see
  /// [_onPlayerSettings].
  late final ValueNotifier<PlayerSettings> _playerSettings;

  /// libVLC's relative size the controller was created with: the look's text
  /// scale is a percent of it. With the controller, it stays for every source
  /// and episode this screen plays.
  late final int _createdRelativeSize;

  /// The look last handed to the controller - see [_restyleSubtitles].
  VlcSubtitleLook? _sentLook;

  /// The video size the anchored subtitle look was last computed from, so
  /// a new size — a new media, a rotation-aware size landing — re-anchors
  /// it without resending the same look on every tick.
  Size? _anchoredVideoSize;

  /// The pinch zoom's re-anchor, held back while the gesture runs: the
  /// scale reports at 60 fps, and a look per frame would cross the channel
  /// sixty times a second. So the lines are re-anchored at most once every
  /// 100 ms while the fingers move — enough for them to track the one
  /// fixed place on screen instead of scaling with the video — and once
  /// more when the picture settles.
  Timer? _subtitleReanchorTimer;

  /// When the embedded subtitles were last re-anchored, for the throttle
  /// in [_onVideoScaleChanged].
  DateTime? _lastSubtitleReanchor;

  ProviderContainer? _container;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container = ProviderScope.containerOf(context, listen: false);
    // Told again whenever the route comes back on top: a quiet end waits for
    // it (see [_leaveWhenOnTop]).
    if (_leaveOnTop) _leaveWhenOnTop();
    // A rotation reaches here through the media query, and it moves the
    // picture libVLC's subtitle lines are drawn into.
    _reanchorSubtitles();
  }

  /// Set once the Play ended quietly with a screen over the player: an
  /// extension's own full-screen screen (a game).
  var _leaveOnTop = false;

  /// Back to the title once the player is on top, with nothing said: the Play
  /// ended quietly because an extension's own full-screen screen (a game) took
  /// it (Phase 7c's §4). A screen still over the player stays until it goes:
  /// removing the player's page would take it too (Review Focus 1).
  void _leaveWhenOnTop() {
    _leaveOnTop = true;
    // A dependency: didChangeDependencies runs again once the route is current.
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive || !route.isCurrent) return;
    _leaveOnTop = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _disposed) return;
      final navigator = Navigator.of(context);
      if (!navigator.canPop()) return;
      _handBack();
      navigator.pop();
    });
  }

  T _read<T>(ProviderListenable<T> provider) {
    final container = _container;
    if (container != null) {
      return container.read(provider);
    }
    return ref.read(provider);
  }

  /// Strings, when there is still a tree to read them from.
  ///
  /// Nullable because most of this file runs from async continuations and
  /// engine callbacks that can outlive the route; the text they produce is
  /// never worth throwing over.
  ///
  /// [_container] doubles as "dependencies have been handed over": resolution
  /// starts in [initState] and its progress callbacks are free to answer
  /// before the first await, where reading an inherited widget is an
  /// assertion. Nothing is lost - [didChangeDependencies] puts the first line
  /// up.
  AppLocalizations? get _l10n => (!mounted || _disposed || _container == null)
      ? null
      : AppLocalizations.of(context);

  /// The shortest side of the surface the video will be shown on, in physical
  /// pixels, or 0 when that is not a ceiling worth applying.
  ///
  /// Shortest side because the player is landscape and `--adaptive-maxheight`
  /// names a height: a 2400x1080 handset and a 1920x1080 television both want
  /// 1080. Physical pixels because that is the unit a rendition compares
  /// against; logical dp on Android TV is half the panel.
  ///
  /// Zero on a desktop, where the window is resized and full-screened
  /// mid-playback, so its height at construction is not a ceiling on anything.
  ///
  /// Read off the implicit view rather than a `MediaQuery`, because the engine
  /// is constructed in [initState], where an inherited widget may not be
  /// depended on.
  int _panelHeightPx() {
    if (ref.read(deviceProfileProvider).asData?.value.isDesktopOS ?? false) {
      return 0;
    }
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    return view?.physicalSize.shortestSide.round() ?? 0;
  }

  @override
  void initState() {
    super.initState();
    // First, so the record starts with the screen and the device suite reads
    // this screen's log.
    _qoe = QoeLog(sink: (line) => talker.info(line));
    _episode = widget.episode;
    _videoUrl = widget.videoUrl;
    _preloaded = widget.preloadedStreams;
    _publishPanelData();
    // The lock is lent to the controls, so the screen is not the only thing
    // that writes it. Subscribed here so the off transition is owned in one
    // place no matter who made it - see [_onUnlocked].
    _locked.addListener(_onUnlocked);
    WidgetsBinding.instance.addObserver(this);
    // The desktop shell stacks its title bar over every route; over this one
    // that is a 48px bar on the back button and an invisible pointer-eating
    // strip the rest of the time. Raised for the whole life of the screen,
    // including the resolving and failed stages.
    setImmersiveRoute(active: true);
    // The window is the source of truth for full screen. Subscribed before
    // the seed read is issued so nothing that happens during its await is
    // missed - see [_windowSpoke] for which of the two wins.
    _platform.addWindowListener(this);
    unawaited(_seedFullscreen());
    // A bot check the links wait on shows on the startup view, and only
    // there: once a video plays, the checks met elsewhere redraw nothing.
    if (Clearance.instance.isReady) {
      _checkChanges = Clearance.instance.checks.changes.listen((_) {
        if (!mounted || _disposed || _stage != _Stage.resolving) return;
        setState(() {});
        _keepCheckTick();
      });
    }
    // Held for startup, then handed to playback - see [_syncPlayingState].
    // Resolving a cold magnet link can take minutes with nothing playing, and
    // a screen that sleeps through it never gets to the video.
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Subtitles are drawn by the engine, so the user's appearance settings have
    // to be supplied at construction. Without them VLC uses its own default
    // relative size of 16, which is enormous on a full-screen video.
    final settings =
        ref.read(playerSettingsProvider).asData?.value ??
        const PlayerSettings();
    _fit = _fitFromSettings(settings.defaultResizeMode);
    _deviceAdaptiveMaxHeight = _adaptiveMaxHeight = adaptiveMaxHeightFor(
      // Unresolved is not "capable": a cold deep link can beat the provider
      // here, and the conservative answer is the right one when nothing is
      // known.
      tier:
          ref.read(deviceProfileProvider).asData?.value.tier ??
          DeviceTier.standard,
      panelHeightPx: _panelHeightPx(),
      // What the silicon will do, not what the user asked for: the preference
      // below only reaches a decoder on Android, so Windows and Linux decode
      // in software however it is set and Darwin decodes on VideoToolbox
      // however it is set.
      hardwareDecode: hardwareDecodeAvailable(
        platform: defaultTargetPlatform,
        preference: settings.hardwareDecoding,
      ),
    );
    _renditionCap = _adaptiveMaxHeight;

    _controller = VlcPlayerController(
      autoPlay: true,
      // Native events are not throttled by default and position ticks are not
      // deduped, so every tick would rebuild the overlay and run the progress
      // listener. Four updates a second is plenty for a seek bar.
      eventThrottleInterval: const Duration(milliseconds: 250),
      config: VlcPlayerConfig(
        network: VlcNetworkConfig(
          // For anything that reaches libVLC without media options. Each
          // media carries its own interval, and its read-ahead from the
          // buffer rule: see playbackMediaOptions.
          networkCaching: kVodCachingMs,
          userAgent: kDefaultBrowserUserAgent,
          // HLS and DASH Auto follow the link: the highest rendition allowed
          // for three segments, then down as the buffer drains and up as it
          // fills. A Quality pick swaps in `highest` for its media. The
          // ceiling keeps a weak device off renditions it can't decode
          // either way.
          adaptiveLogic: VlcAdaptiveLogic.predictive,
          adaptiveMaxHeight: _adaptiveMaxHeight,
        ),
        subtitleStyle: subtitleStyleFrom(settings),
        // Off by default; see [PlayerDiagnostics].
        verbose: PlayerDiagnostics.verboseVlcLog,
      ),
      // Android's audio output and the desktops' frame conversion; the
      // hardware-decoding switch reaches Android's decoder per media (see
      // softwareDecodeFor).
      options: playerInstanceOptions(defaultTargetPlatform),
    );
    // The style above is fixed with the player. What libVLC can change while
    // it plays follows the settings from here, starting now - the lift has no
    // creation option of its own - and the controller hands the look to the
    // native player once it exists.
    _createdRelativeSize = relativeSizeFor(settings.subtitleSize);
    _playerSettings = ValueNotifier<PlayerSettings>(settings);
    _restyleSubtitles(settings);
    ref.listenManual<AsyncValue<PlayerSettings>>(
      playerSettingsProvider,
      (_, next) => _onPlayerSettings(next.asData?.value),
    );

    _controller.addListener(_onPlaybackValue);
    _sideCars.addListener(_onSideCars);
    _chrome = ChromeVisibilityController(
      isPlaying: () => _controller.value.isPlaying,
    );
    // The embedded subtitle lines sit at one fixed place on screen — the
    // area's bottom margin, see [subtitleLookAnchored] — so a pinch must
    // recompute the look, or the lines scale with the picture they are
    // drawn into. The chrome is not in it: the lines never move when the
    // controls show or hide, so the chrome needs no listener here.
    _videoScale.addListener(_onVideoScaleChanged);
    _watchdog = Timer.periodic(_kWatchdogTick, (_) {
      _checkFirstFrame();
      _checkStall();
    });
    _controller.pendingSeekTarget.addListener(_qoeSeekChanged);
    _controller.pendingSeekTarget.addListener(_onSeekSettled);
    _controller.pendingSeekTarget.addListener(_followSeekTarget);
    _qoeMemory = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _qoe.memory(ProcessInfo.currentRss ~/ (1 << 20)),
    );
    // Asked alongside the links rather than at each open: on a cold Android
    // emulator the platform took 1.3 s to answer.
    // One question for both: whether the network is metered, for the buffer
    // rule, and whether there is one at all, for recovery. Metered on any
    // error, the answer that can't spend data the viewer didn't agree to.
    final network = Connectivity().checkConnectivity();
    _metered = network.then(
      (results) => results.contains(ConnectivityResult.mobile),
      onError: (Object _) => true,
    );
    _memory = readDeviceMemory();
    _listenForConnectivity(network);
    _attachPip();
    unawaited(_start());
  }

  /// A player setting changed. The panel's copy follows, libVLC's lines do
  /// too when the change is one they show, and the subtitle files are read
  /// again in a new encoding.
  void _onPlayerSettings(PlayerSettings? settings) {
    if (settings == null || _disposed) return;
    _playerSettings.value = settings;
    _restyleSubtitles(settings);
    _sideCars.encoding = settings.subtitleEncoding;
  }

  /// Hands libVLC the look [settings] give its lines inside the video, when
  /// it is not the one they have: from their next line, and their lift at
  /// once. Subtitle files restyle by themselves, drawn from the settings.
  ///
  /// Best effort. An engine that cannot restyle answers false and keeps the
  /// look it was created with, and nothing about that is worth a word to the
  /// viewer; the controller keeps the look for a player created later.
  void _restyleSubtitles(PlayerSettings settings) {
    final look = _anchoredSubtitleLook(settings);
    if (look == _sentLook) return;
    // Hysteresis: the anchored raise is a double from on-screen
    // geometry, and exact equality would re-send it for sub-pixel
    // changes (a rotation settling, a size re-report) — a look whose
    // lift moved by a pixel or two, which is the shake the viewer
    // reported. Only send when the size changed or the lift moved by a
    // real amount (a hundredth of the picture's height); everything
    // else in the look comes from settings and is exact.
    final sent = _sentLook;
    if (sent != null &&
        look.textScale == sent.textScale &&
        look.color == sent.color &&
        look.backgroundColor == sent.backgroundColor &&
        look.backgroundOpacity == sent.backgroundOpacity &&
        look.outlineThickness == sent.outlineThickness &&
        (look.raise - sent.raise).abs() <= 0.01) {
      return;
    }
    _sentLook = look;
    unawaited(
      _controller.setSubtitleLook(look).catchError((Object _) => false),
    );
  }

  /// Re-anchors libVLC's subtitle lines to the screen after the picture
  /// moved under them: a fit change, a pinch, a rotation, a new video size.
  /// Nothing is sent when the look has not changed.
  void _reanchorSubtitles() {
    if (_disposed) return;
    _restyleSubtitles(_playerSettings.value);
  }

  /// A pinch reports at 60 fps while the fingers are down: the look is
  /// recomputed as the picture moves, throttled to once every 100 ms, so
  /// the embedded lines track the one fixed place on screen instead of
  /// scaling with the video — and once more when the picture settles.
  void _onVideoScaleChanged() {
    final now = DateTime.now();
    if (_lastSubtitleReanchor == null ||
        now.difference(_lastSubtitleReanchor!) >=
            const Duration(milliseconds: 100)) {
      _lastSubtitleReanchor = now;
      _reanchorSubtitles();
    }
    _subtitleReanchorTimer?.cancel();
    _subtitleReanchorTimer = Timer(
      const Duration(milliseconds: 150),
      _reanchorSubtitles,
    );
  }

  /// The look [settings] give libVLC's lines, anchored to one fixed place
  /// on screen: see [subtitleLookAnchored]. The geometry is only
  /// known once a picture is up — before that, and wherever it cannot be
  /// measured, the unanchored look, which is what a player took before.
  VlcSubtitleLook _anchoredSubtitleLook(PlayerSettings settings) {
    final plain = subtitleLookFrom(
      settings,
      createdRelativeSize: _createdRelativeSize,
    );
    if (_stage != _Stage.playing) return plain;
    final videoSize =
        _controller.value.displayVideoSize ?? _controller.value.videoSize;
    if (videoSize == null || videoSize.isEmpty) return plain;
    Size screen;
    try {
      screen = MediaQuery.sizeOf(context);
    } on Object {
      return plain;
    }
    if (screen.isEmpty) return plain;
    // Fixed target: the lines sit at one place — just above the area's
    // bottom edge — whatever the picture does under them, which the
    // viewer reported as the subtitle following the zoom. Anchoring to
    // the picture's bottom edge followed it up on a pinch-out; letting
    // the target follow the chrome made them jump every time the bars
    // showed or hid, which was the shaking. The chrome height is not in
    // the target at all, so the lines never move and never sit high.
    return subtitleLookAnchored(
      settings,
      createdRelativeSize: _createdRelativeSize,
      screen: screen,
      video: videoSize,
      fit: _fit,
      pinchScale: _videoScale.value,
    );
  }

  /// Wires the PiP window's transport buttons to the controller.
  ///
  /// The buttons Android draws under the shrunken video are broadcasts into
  /// `MainActivity`, forwarded over the channel; without a listener here they
  /// do nothing.
  ///
  /// Both callbacks arrive from the platform thread, hence the
  /// mounted/disposed guard before any setState.
  void _attachPip() {
    // iOS reports its PiP window through the controller, not the activity:
    // opened by the request in [_enterPip], closed by the window's own
    // button, or never opened at all when the device refuses.
    _controller.isPictureInPicture.addListener(_onPictureInPicture);
    _platform.attachPipListener(
      onAction: (action) => switch (action) {
        PipAction.play => unawaited(_controller.play()),
        PipAction.pause => unawaited(_controller.pause()),
        PipAction.seekForward => _seekRelative(
          PlayerPlatformService.pipSeekStep,
        ),
        PipAction.seekBackward => _seekRelative(
          -PlayerPlatformService.pipSeekStep,
        ),
      },
      onModeChanged: (inPip) {
        if (!mounted || _disposed || inPip == _inPip) return;
        // The other way into PiP: the user swiped home, or pressed the
        // system's own PiP control, and `_enterPip` never ran. Same reason -
        // a locked PiP window has no chip in it.
        if (inPip) _clearLock();
        setState(() => _inPip = inPip);
      },
    );
  }

  /// Seeks by [delta] from wherever playback is, for the PiP buttons.
  ///
  /// Clamped at both ends: a negative target is refused outright by libVLC,
  /// and overshooting the duration would trip the end-of-media handler and
  /// advance an episode the viewer only meant to skip forward in.
  ///
  /// Counted from the published position, unlike the controls' own arrows,
  /// which chain off their last target. No chain can straddle this:
  /// [VlcPlayerControls] is built only while `!_inPip`, so it is unmounted
  /// before a PiP window exists to press these buttons in.
  void _seekRelative(Duration delta) {
    final value = _controller.value;
    if (!value.isSeekable) return;
    // Over a held picture the engine reports the new media's 0: a press
    // steps from where the reopen is going.
    var target =
        (value.isPictureHeld
            ? _controller.pendingSeekTarget.value ?? value.position
            : value.position) +
        delta;
    if (target < Duration.zero) target = Duration.zero;
    if (value.duration > Duration.zero && target > value.duration) {
      target = value.duration;
    }
    unawaited(_controller.seekTo(target));
  }

  /// Where a reopen starts (spec 2, *The reopen*: "`pendingSeekTarget ?? last
  /// position`"): where playback is going - a seek on its way, or a held
  /// reopen's own start - or else where it last was. A live stream reopens at
  /// its live start; [_isLive] is the item's and the address's word, which a
  /// live window's length and seekability don't change.
  Duration _reopenTarget() => _isLive
      ? Duration.zero
      : _controller.pendingSeekTarget.value ?? _resumePosition;

  /// Keeps [_resumePosition] on every seek target as it is set: the
  /// controller drops a target the moment its media can no longer land - an
  /// error, an end - and recovery asks where to reopen after that.
  void _followSeekTarget() {
    final target = _controller.pendingSeekTarget.value;
    if (target == null || _isLive) return;
    _resumePosition = target;
  }

  /// Resolve the candidate list, then open the best one.
  ///
  /// Everything that can fail is inside one try, so every failure lands on the
  /// error state rather than as an exception out of initState.
  Future<void> _start() async {
    // Everything this run learns is stamped with this, so the previous run's
    // stragglers - a probe still in flight when the viewer advanced - can be
    // told apart from this one's answers and dropped.
    final generation = ++_resolveGeneration;
    // Whatever the last run learned describes the last run. A retry re-probes
    // and an episode advance resolves different media, and either one showing
    // the previous attempt list is worse than showing nothing.
    _forgetSources();
    _publishPanelData();
    _setFailReason(null);
    _awaitingFirstOpen = true;
    _pickedBeforeOpen = null;
    final pick = _pick = Completer<int>();
    _abandonPendingResolve();
    final abandon = _abandonResolve = Completer<void>();
    final currentEpisode = _currentEpisode;
    // Asked alongside the plugin rather than after it. Where to resume does
    // not depend on which source opens, and with trackers linked the lookup
    // can take its whole three-second budget - which used to be spent after
    // the probe, in front of setMedia, with nothing on screen moving.
    //
    // Its error handler is attached here, not where it is awaited: resolution
    // can outlast it, and a failure with no handler yet is an unhandled one. A
    // lookup that fails starts playback from the top rather than failing it.
    final resumeLookup =
        resolveResumePoint(
          read: _read,
          item: widget.item,
          episode: currentEpisode,
          videoUrl: _videoUrl,
        ).then<ResumePoint?>(
          (point) => point,
          onError: (Object e) {
            if (kDebugMode) debugPrint('resume lookup failed: $e');
            return null;
          },
        );
    try {
      // A Stremio item's next episode is asked of its add-on, which the
      // item names as its provider.
      _pluginName = _preloaded == null
          ? pluginFor(_read, widget.item, _videoUrl)?.name ??
                (widget.item.source == kAddonItemSource
                    ? widget.item.provider
                    : null)
          : null;
      _linksAskedAt = DateTime.now();
      // Plugin resolution is a network round trip and can be the longest part
      // of startup. The view narrates it from what [_onCandidates] and
      // [_onProbe] record, and a row picked during the probe race ends it.
      final resolved = await resolvePlayback(
        read: _read,
        item: widget.item,
        videoUrl: _videoUrl,
        preloadedStreams: _preloaded,
        isCancelled: () => _disposed,
        onCandidates: (streams) => _onCandidates(generation, streams),
        onProbe: (index, outcome) => _onProbe(generation, index, outcome),
        pick: pick.future,
        abandon: abandon.future,
      );
      if (_disposed) return;
      _resolved = resolved;
      // A new resolve: recovery learns the candidates, and what the race
      // found about them.
      _checkGeneration += 1;
      _policy.candidatesChanged([
        for (final stream in resolved.streams)
          RecoveryCandidate(
            authority: Uri.tryParse(stream.url)?.authority ?? '',
            checkable: !isUncheckableSource(stream),
          ),
      ]);
      for (final entry in _probes.entries) {
        if (entry.value != ProbeOutcome.trying) {
          _policy.probed(entry.key, entry.value);
        }
      }
      _publishPanelData();
      // The race is over. A pick from here on is held for the first open -
      // see [_pickSource].
      _pick = null;

      _token++;
      _recordedLivestream = false;
      _recorder = PlaybackProgressRecorder(
        read: _read,
        item: widget.item,
        episode: currentEpisode,
        videoUrl: _videoUrl,
        token: _token,
      );
      // One tracker for the whole screen, deliberately: failing over to another
      // source is still the same episode, so the watched latch must survive it.
      _tracker = PlaybackTracker(
        read: _read,
        item: widget.item,
        episode: currentEpisode,
        videoUrl: _videoUrl,
        token: _token,
      );

      // Applied as a start position rather than a seek, which removes the
      // question of when the engine is ready enough to seek.
      //
      // Awaited rather than read straight off Hive: whichever device wrote
      // last wins, so pausing on the television and picking up the phone
      // resumes rather than restarts. The lookup falls back to the local
      // answer on any tracker failure.
      _initialResume = await resumeLookup;
      if (_disposed) return;
      // From here the resume point belongs to the session rather than to the
      // stored history entry: every later attempt, failover or hand-picked,
      // starts from wherever playback actually got to.
      _resumePosition = _initialResume?.position ?? Duration.zero;
      // Per session. The hint belongs to the resume point resolved just above
      // and recovery's budgets to the media about to be opened, which
      // `candidatesChanged` started again; carrying either forward offers a
      // stale position or refuses to reconnect a feed that has not dropped.
      _resumeHintOffered = false;
      _showResumeHint = false;

      // Not awaited: both skip sources are network lookups against
      // crowdsourced databases, and playback must not wait on a convenience.
      unawaited(_loadSkipSegments(currentEpisode));

      // A row picked while the resume lookup was finishing is the viewer's
      // choice, and it outranks the resolver's. The resolver's is moved off a
      // source that cannot seek when there is a place to pick up from: it
      // would play from the top. Only the lookup knows that, and it answers
      // after the race.
      final first =
          _pickedBeforeOpen ??
          (_resumePosition > Duration.zero
              ? resumeSourceIndex(
                  preferred: resolved.index,
                  total: resolved.streams.length,
                  probes: _probes,
                )
              : resolved.index);
      _pickedBeforeOpen = null;
      _awaitingFirstOpen = false;
      await _openAttempt(first, startAt: _resumePosition);
    } catch (e) {
      // An extension's own full-screen screen (a game) took the Play and left
      // nothing to play: back to the title, with nothing said.
      if (e is StreamResolutionException && e.failure == StreamResolutionFailure.extensionScreen) {
        if (mounted && !_disposed) _leaveWhenOnTop();
        return;
      }
      final l10n = _l10n;
      _fail(switch ((e, l10n)) {
        (final StreamResolutionException f, final AppLocalizations t) =>
          describeStreamFailure(t, f),
        (final StreamResolutionException f, _) => f.message,
        (_, final AppLocalizations t) => t.playerPlaybackFailed('$e'),
        _ => 'Playback failed: $e',
      });
    }
  }

  void _abandonPendingResolve() {
    final abandon = _abandonResolve;
    if (abandon != null && !abandon.isCompleted) abandon.complete();
  }

  /// Drops everything the source list knew about the last resolve. Written
  /// without setState: [_start] runs from initState, and every caller that
  /// runs later rebuilds in the same stretch anyway.
  void _forgetSources() {
    _candidates = const <StreamResult>[];
    _probes.clear();
    _failedRows.clear();
    _playedRows.clear();
    _qualityLadder = const <int>[];
    _qualityLadderOf = null;
  }

  /// The candidate list, the moment resolution has one.
  ///
  /// Indices in [_probes] and in [ResolvedPlayback] are indices into this, so
  /// it is stored rather than counted: "Source 2 of 5" needs the 5, and the
  /// attempt list needs the names.
  void _onCandidates(int generation, List<StreamResult> streams) {
    if (_disposed || !mounted || generation != _resolveGeneration) return;
    setState(() {
      _candidates = streams;
      _publishPanelData();
    });
  }

  /// One probe answered.
  ///
  /// [generation] is the resolve that dispatched it, and an answer from any
  /// older one is dropped: the losing probes keep running for seconds after a
  /// resolve returns, and [index] means nothing once another resolve has
  /// replaced the list it indexes.
  void _onProbe(int generation, int index, ProbeOutcome outcome) {
    if (_disposed || !mounted || generation != _resolveGeneration) return;
    setState(() {
      _probes[index] = outcome;
      if (outcome != ProbeOutcome.trying) _policy.probed(index, outcome);
      _publishPanelData();
    });
  }

  /// Opens one candidate.
  ///
  /// The generation counter is bumped first and re-checked after every await.
  /// Without it a failover triggered by a dying source can land after the user
  /// has already moved on, and hand the engine media nobody asked for.
  ///
  /// [keepPicture] keeps the picture on screen through a same-source reopen,
  /// when one is up and the output can hold it (spec 2, *The reopen*), with
  /// [status] as the line over it; every other open puts the start-up view
  /// up, naming the source. [autoPlay] false opens it paused.
  ///
  /// [revertTo] is the source a trial pick interrupted: recovery goes back to
  /// it if the pick won't play.
  Future<void> _openAttempt(
    int index, {
    required Duration startAt,
    int? revertTo,
    String reason = 'first',
    bool keepPicture = false,
    bool autoPlay = true,
    String status = '',
  }) async {
    final resolved = _resolved;
    if (resolved == null || _disposed) return;
    if (index < 0 || index >= resolved.streams.length) {
      final total = resolved.streams.length;
      return _fail(
        _l10n?.playerNoSourcesPlayable(total) ??
            'None of the $total sources would play.',
      );
    }

    final generation = ++_generation;
    _sawError = false;
    _sawEnded = false;
    // Armed per attempt, because an attempt is what "a video" means to libVLC:
    // an episode advance, a failover, a recovery, a rendition step-down and a
    // live reconnect all hand it media that will select a subtitle for itself,
    // and one that does so behind a viewer who asked for none is the bug this
    // setting exists to fix. See [_applySubtitleDefault] for what that costs
    // and why it is the right trade.
    //
    // Read here rather than watched: a change made in Settings while a player
    // is open reaches the NEXT media this screen opens, never the one already
    // on screen.
    _subtitlesOffPending =
        _read(playerSettingsProvider).asData?.value.subtitleDefault ==
        SubtitleDefault.off;
    _subtitleOffAsked = null;
    // Auto picks only for media with nothing to put back: a track inside the
    // video that was on before this reopen is [_restoreTracks]' to restore,
    // and a subtitle file turned on over it would switch it off again.
    _autoPickPending = !_subtitlesOffPending && _rememberedSubtitle == null;
    _autoPickLook = null;
    _viewerChoseSubtitle = false;
    _subtitleToRestore = null;
    _subtitleRestoreRevision = null;
    // The audio language setting speaks for every media this screen opens, a
    // reopen included - see [_pickPreferredAudio]. A track the viewer picked
    // on this content outranks it wherever that track goes back on, and the
    // setting is the fallback where it does not. Read here for the reason the
    // subtitle default is: a change in Settings reaches the next media, not
    // the one on screen.
    final audioLanguage =
        _read(playerSettingsProvider).asData?.value.preferredAudioLanguage ??
        '';
    _preferredAudioToPick = audioLanguage.isNotEmpty ? audioLanguage : null;
    _preferredAudioCheckedRevision = null;
    _pickingPreferredAudio = false;
    _audioPutOn = null;
    // Whatever the viewer was listening to and reading goes back on once the
    // new media has published its tracks. A reopen restores the position; it
    // has no business also changing the language. Under the setting the audio
    // half is its look's to do: the viewer's own pick first where it can be
    // told on this media, and otherwise this goes back only where the media
    // lacks the language.
    _audioToRestore = _viewerAudio ?? _rememberedAudio;
    _viewerAudioOutranks = _viewerAudioTellableOn(resolved.streams[index].url);
    _restorePending =
        (_preferredAudioToPick == null && _audioToRestore != null) ||
        _rememberedSubtitle != null;
    // Every way back into playback goes through here - Start Over, a failover,
    // a hand-picked source - and none of them may leave the ended card up over
    // media that is opening.
    _ended = null;
    // The Quality tab's ladder is one source's. Another source's open takes
    // it down until that one's own is read; a reopen of this one - a pick, a
    // step-down, a recovery - keeps it, and a read still out for it lands.
    if (resolved.streams[index].url != _qualityLadderOf) {
      _qualityLadderOf = null;
      _qualityLadder = const <int>[];
    }
    // A rebuild of its own: the startup view's highlighted row, source line
    // and "Source n of m" all follow this, and nothing else in an open is
    // guaranteed to change the screen - a failover from a source that never
    // played changes no other state the build reads.
    setState(() {
      _attemptIndex = index;
      // Opened again - re-picked by the viewer - so its earlier failure no
      // longer describes it; the row reads as opening from here.
      _failedRows.remove(index);
    });
    // Published here, not only at open: this is the write the panel's
    // 'Now playing' tick follows through a failover or a trial revert.
    _publishPanelData();
    // Recovery's attempt: the open ends any recovery under way, and replaces
    // any park.
    _parked = false;
    _awaitingPlay = !autoPlay;
    // Every open keeps the display on until playback decides - Retry's and a
    // pick from the failed screen's too - except one opened paused, which
    // sleeps as a pause does.
    unawaited(autoPlay ? WakelockPlus.enable() : WakelockPlus.disable());
    _checkGeneration += 1;
    _policy.opened(
      source: index,
      live: isLiveSource(widget.item, resolved.streams[index].url),
      revertTo: revertTo,
    );
    _armRecoveryTimer();

    // The outgoing attempt's last position goes to history before it is
    // forgotten: the sample is cleared on the next line.
    _flushProgress();

    // Per attempt, not per session. "Did this source play" and the
    // end-of-media check both ask about this media, and a sample left behind
    // by the last one answers for the wrong one.
    _sample = null;
    _handedToEngine = false;
    // The picture stays through a same-source reopen that asks for it, when
    // one is up; set before the frame flag goes, so the lock - which belongs
    // to the picture - stays with it.
    final keep = keepPicture && _pictureUp;
    _setKeptPicture(keep);
    _setSawFrames(false);
    // Seeded with the start position rather than zero: the first value after
    // setMedia still carries the previous media's numbers, and treating that
    // as movement would both hide a stall and sample the wrong position.
    _lastSeenPosition = startAt;
    _lastSeenDuration = Duration.zero;
    _hlsMedia = null;
    _qualityMedia = null;
    _liveMedia = null;
    // A seek in the last media's live window ends with it: this open's
    // setMedia clears the controller's target, which [_onSeekSettled] would
    // otherwise take for a seek libVLC never took, and reopen at its distance.
    _liveSeek = null;
    _videoLengthAsked = false;
    _videoLength = null;
    _openedPlaylist = null;
    _startAttemptClock();

    final stream = resolved.streams[index];
    _qoeOpened(index, stream, startAt, reason, keptPicture: keep);

    // An open told not to play has nothing to be late for until the viewer
    // plays it.
    if (autoPlay) {
      _watchFirstFrame(
        generation,
        torrent: isTorrentSource(stream) || _torrentFileIndex != null,
      );
    }

    // The race only checked the top few. A source opened from past them -
    // picked by the viewer, or reached by failover - is checked now, while it
    // opens rather than in front of it, so its row says what it would have.
    if (!_probes.containsKey(index) && !isUncheckableSource(stream)) {
      _checkWhileOpening(index, stream);
    }

    // Which candidate is being tried is the startup view's to say - its pill,
    // its source line and its highlighted row all follow [_attemptIndex]. What
    // is left for the status line is anything unusual about this open, and a
    // line left over from the last one is not that. Over a kept picture it is
    // the pill, saying why the picture stands still: "Reconnecting…" after a
    // failure, nothing for a reopen the viewer or the screen chose.
    _setStatus(keep ? status : '');

    // libVLC cannot decrypt CENC on any build we ship, so ClearKey content is
    // decrypted in the local proxy and handed to the engine as plaintext.
    //
    // The key does not have to be in the playlist: the W3C ClearKey exchange
    // is a plain JSON request, so it is worth asking the licence server before
    // giving up. fetchClearKey answers inline keys without a round trip and
    // never throws, so this costs nothing on the ordinary path.
    final clearKey = await fetchClearKey(stream);
    if (_disposed || generation != _generation) return;
    if (clearKey == null) {
      // Widevine and PlayReady need a CDM this app does not have, and a
      // licence server that answered with nothing usable will answer the same
      // way again - so this candidate gets no retry, while the others may not
      // be encrypted at all.
      final obstacle = drmObstacleFor(stream);
      if (obstacle != null) {
        final l10n = _l10n;
        return _onFailure(
          FailureSign.unplayable,
          l10n == null ? 'DRM' : describeDrmObstacle(l10n, obstacle),
        );
      }
    }

    // A torrent has to be prepared and seeded before anything can open it, and
    // that can take a while on a cold magnet - so say so rather than sitting on
    // a blank screen.
    final isTorrent = isTorrentSource(stream);
    // A file picked out of a pack is served over plain http by the torrent
    // server, so isTorrentSource no longer sees it - but it still needs the
    // patient stall deadline while the piece cache fills.
    _attemptIsTorrent = isTorrent || _torrentFileIndex != null;
    if (isTorrent) {
      // Not the last torrent's numbers for up to three seconds.
      _torrentStatus = null;
      _setStatus(_l10n?.playerPreparingTorrent ?? '');
    }
    if (isTorrent && _torrentPoll == null) {
      _startedTorrent = true;
      _startTorrentPolling();
    }
    // A magnet's sizes reach the torrent server before it is added: its
    // write happens at its start, before the first add, and drops every
    // torrent it holds (spec 5). A pack file picked out of a loaded torrent
    // hands over nothing.
    BufferPlan? torrentPlan;
    if (isTorrent) {
      final metered = await _metered;
      if (_disposed || generation != _generation) return;
      final plan = await _planBuffer(
        stream,
        BufferMedia.torrent,
        metered: metered,
      );
      if (_disposed || generation != _generation) return;
      final cacheMb = plan.torrentCacheMb!;
      _read(torrentServiceProvider).bufferForNextStart(
        cacheMb: cacheMb,
        readAheadPercent: torrentReadAheadPercent(cacheMb),
      );
      torrentPlan = plan;
    }
    final playable = await playableUrlFor(read: _read, stream: stream);
    if (_disposed || generation != _generation) return;
    if (isTorrent) {
      _qoe.torrent(_read(torrentServiceProvider).takeStartSettings()?.toJson());
    }
    if (playable == null) {
      return _onFailure(
        FailureSign.unplayable,
        _l10n?.playerReasonTorrentNotPrepared ??
            'torrent could not be prepared',
      );
    }

    final uri = _playableUri(playable);
    if (uri == null) {
      return _onFailure(
        FailureSign.unplayable,
        _l10n?.playerReasonNoPlayableAddress ??
            'source has no playable address',
      );
    }

    final headers = playbackHeaders(stream);
    final mediaUri = clearKey != null
        ? await _decryptingUri(uri, headers, clearKey)
        : await _deliverableUri(uri, headers);
    if (_disposed || generation != _generation) return;
    _adaptive =
        looksLikeHls(mediaUri) || mediaUri.path.toLowerCase().endsWith('.mpd');

    // Auto's cap follows the quality preference in force now - mobile data's
    // on a metered link, Wi-Fi's otherwise, as source sorting decides it -
    // read at each open: a viewer who leaves Wi-Fi keeps what plays until
    // something opens the media again. A pick from the Quality tab
    // overrides it.
    final metered = await _metered;
    if (_disposed || generation != _generation) return;
    final settingsNow =
        _read(playerSettingsProvider).asData?.value ?? const PlayerSettings();
    final preference = metered
        ? settingsNow.mobileQuality
        : settingsNow.wifiQuality;
    _preferenceHeightAtOpen = qualityPreferenceHeight(preference);
    _renditionCap = renditionCapFor(
      deviceCap: _adaptiveMaxHeight,
      pick: _qualityPick,
      preferenceHeight: _preferenceHeightAtOpen,
    );

    // A segment length read from another source's playlist says nothing
    // about this one's; a reopen of this one keeps it.
    if (stream.url != _lastStreamUrl) _liveSegment = null;
    _lastStreamUrl = stream.url;
    // A new media starts un-zoomed (pinch-to-zoom).
    _videoScale.value = 1.0;
    _isLive = isLiveSource(widget.item, stream.url);
    final languageOption = _audioLanguageOption();
    // How far ahead this media reads (spec 1.2): from its bitrate, the
    // network, and the memory free now.
    final plan =
        torrentPlan ??
        await _planBuffer(stream, _bufferMediaFor(mediaUri), metered: metered);
    if (_disposed || generation != _generation) return;
    _bufferPlan = plan;
    final liveDelayMs =
        _nextLiveDelayMs ?? PlayerDiagnostics.liveDelayMs ?? kLiveDelayMs;
    _nextLiveDelayMs = null;
    _qoe.engine();
    await _controller.setMedia(
      VlcMediaSource(
        uri: mediaUri,
        httpHeaders: headers,
        startPosition: startAt,
        // Each media carries its own start threshold, buffer and decoder
        // choice: libvlc-android adds its own caching to a media that names
        // none. The rendition cap rides here whenever it is not the one the
        // player was created with: lowered by a step-down, a pick or the
        // quality preference. The audio language rides here whenever the
        // setting speaks for this media - see [_audioLanguageOption].
        mediaOptions: playbackMediaOptions(
          live: _isLive,
          plan: plan,
          renditionCap: _renditionCap != _deviceAdaptiveMaxHeight
              ? _renditionCap
              : null,
          qualityPicked: _qualityPick != null,
          softwareDecode:
              _softwareRetry ||
              softwareDecodeFor(
                platform: defaultTargetPlatform,
                hardwareDecoding:
                    (_read(playerSettingsProvider).asData?.value ??
                            const PlayerSettings())
                        .hardwareDecoding,
              ),
          languageOption: languageOption,
          liveDelayMs: liveDelayMs,
        ),
        // So the controller places a live HLS window itself: libVLC counts
        // its time from the join, and its window from the playlist it last
        // read.
        isLive: _isLive,
      ),
      autoPlay: autoPlay,
      keepPicture: keep,
    );
    if (_disposed || generation != _generation) return;
    // An output that couldn't hold - one that can't, or nothing there to hold
    // after all - shows the new media's opening: the start-up view covers it.
    if (keep && !_controller.value.isPictureHeld) _setKeptPicture(false);
    // From here every tick is this attempt's. Restarted here as well as above:
    // everything between the two is setup — torrent preparation, a proxy
    // handshake — and the deadline the watchdog enforces is on the engine
    // producing a frame, not on getting to setMedia.
    _handedToEngine = true;
    _engineStreamUrl = stream.url;
    _startAttemptClock();
    if (!_isLive && looksLikeHls(mediaUri)) {
      _hlsMedia = (uri: mediaUri, headers: headers);
    }
    if (_isLive && looksLikeHls(mediaUri)) {
      _liveMedia = (uri: mediaUri, headers: headers);
    }
    // What the Quality tab's ladder is read from once this media shows a
    // picture: the address libVLC was given, with its headers - an inline
    // playlist too - live as well as on demand.
    if (looksLikeHls(mediaUri) || stream.quality == 0) {
      _qualityMedia = (uri: mediaUri, headers: headers, source: stream.url);
    }

    // The source's subtitle files are read and drawn by SkyStream rather than
    // handed to libVLC, which drew them into the picture - so Zoom cut them
    // off - and could not open the ones behind a playlist or headers at all.
    // Listed here and fetched when first shown; see [SideCarSubtitles].
    //
    // Sent with the video's headers, as they were when libVLC had them
    // through the proxy: a source's subtitles sit behind the same checks as
    // its video. A local file has no use for them.
    final previousSideCar = _sideCars.active;
    final sideCars = _sideCars.replaceSourceTracks([
      for (final sub in stream.subtitles ?? const <SubtitleFile>[])
        if (_playableUri(sub.url) case final url?)
          (
            url: url,
            label: sub.label,
            language: sub.lang,
            headers: url.scheme.startsWith('http') ? headers : null,
          ),
    ]);
    // The file the viewer was reading before this reopen - a failover, a
    // recovery - goes back on, the way [_restoreTracks] puts back a track
    // inside the video. Having been reading it overrules the Off default for
    // this media already.
    final carried = previousSideCar?.origin == SideCarOrigin.source
        ? matchSideCar(sideCars, previousSideCar!)
        : null;
    if (carried != null) {
      _subtitlesOffPending = false;
      _autoPickPending = false;
      unawaited(_sideCars.select(carried, from: startAt));
    } else if (_autoPickPending && _sideCars.active == null) {
      // Auto: the source's file in the viewer's language, straight away. When
      // it ships none, the tracks inside the video are looked at once they
      // are known - see [_pickPreferredSubtitle].
      final preferred = preferredSubtitleIndex([
        for (final track in sideCars) track.languageCode,
      ], _read(subtitleLanguageProvider));
      if (preferred != null) {
        _autoPickPending = false;
        unawaited(_sideCars.select(sideCars[preferred], from: startAt));
      }
    }

    if (_stage != _Stage.playing) {
      setState(() => _stage = _Stage.playing);
      // The stage is an input to the published tick - see
      // [_publishPanelData] - and this is the only write that turns it
      // back on, so the tick would stay off after a recovery without it.
      _publishPanelData();
    }
  }

  /// Keeps the media this attempt opened from starting with a subtitle on,
  /// while the Subtitles setting says [SubtitleDefault.off].
  ///
  /// Three things select a subtitle without being asked, at three moments
  /// nothing on this side can order, which is why this is a standing rule on
  /// the tick rather than a single call in the open chain:
  ///
  ///  * Each side-car add. Every native hardcodes libVLC's select flag on, so
  ///    an add enables what it just added - disabling before the batch
  ///    achieves nothing, and [_openAttempt] disables after it.
  ///  * The same adds again, later. libVLC 3 queues an add-slave to the input
  ///    thread, so `addSubtitle` returns before the ES exists; and on the
  ///    first open of a session the controller has no engine yet and replays
  ///    the whole batch on attach, long after the open chain has finished.
  ///  * libVLC choosing an EMBEDDED track for itself as the media opens, on
  ///    that same thread.
  ///
  /// None of the three is observable except as a snapshot naming a track,
  /// which is this - and every native sends one on ESAdded as well as on the
  /// ordinary tick.
  ///
  /// The rule stands down for this media the moment the viewer opens the side
  /// panel ([_openPanel]), and that bound is the whole design. The Subtitles
  /// tab, the device file picker and the online search all live inside the
  /// panel and the panel has exactly one entry point, so until it has been
  /// opened the viewer has no way to select a subtitle at all: anything
  /// selected in that window is the media selecting for itself, and turning it
  /// off cannot be overruling anybody. From the moment it opens, nothing here
  /// touches the subtitle track again, so a pick stands.
  ///
  /// Bounding on the panel rather than on the first frame is deliberate. A
  /// frame proves the controls exist, not that the adds have landed: on a
  /// first open they land at attach, which can be either side of the first
  /// frame, and a rule that had already closed would let the side-car it was
  /// meant to catch stay on.
  ///
  /// What this deliberately does NOT do is remember a pick across media. A
  /// failover, a recovery, a rendition step-down and the next episode each
  /// re-arm it, and that media starts with subtitles off again.
  ///
  /// For the next episode that is right. For the other three it is a known
  /// wrong, recorded here rather than glossed: they reopen the same content
  /// with no user action, so a subtitle the viewer turned on by hand vanishes
  /// mid-episode. Auto is not symmetrical here either, and the argument that
  /// it is does not survive: Auto only overwrites a pick on a source that
  /// ships side-cars AND matches the preferred language, and a source with
  /// embedded subtitles alone - a direct MKV, a torrent, most debrid links -
  /// returns from the batch untouched and keeps the viewer's track. So Off is
  /// more forgetful than Auto exactly where it was claimed to match it.
  /// Fixing it means separating "new content" from "same content reopened",
  /// which the attempt generation does not currently distinguish.
  ///
  /// Known gap, accepted: a side-car that lands after the panel has been
  /// opened stays on. The viewer is looking at the subtitle list when it
  /// happens, which is the one moment they can undo it.
  ///
  /// The same rule keeps libVLC's own subtitle off while SkyStream draws a
  /// side-car: two subtitles on screen at once is never what anyone chose,
  /// and the media can put an embedded track on at any time - when its
  /// streams appear, after a seek, at an HLS discontinuity. Picking a track
  /// inside the video from the panel takes the side-car off first, so this
  /// never undoes that pick.
  void _applySubtitleDefault(VlcPlayerValue value) {
    if (!_subtitlesOffPending && _sideCars.active == null) return;
    final active = value.activeSubtitleTrackId;
    if (active == null) {
      // Nothing is selected, so the last request landed. Forget which id it
      // was: the latch exists only to stop one request per tick while it is in
      // flight, and holding a spent id means the same track being selected
      // again - an es-out reset, an HLS discontinuity, a seek - reads as a
      // request already made and is never turned off. That left subtitles on
      // under Off, permanently, with the rule silently retired.
      _subtitleOffAsked = null;
      return;
    }
    if (active == _subtitleOffAsked) return;
    _subtitleOffAsked = active;
    unawaited(_disableSubtitles());
  }

  /// Watches which tracks are on, and puts them back after a reopen.
  ///
  /// Two jobs, one tick, because both hang off the same two ids.
  ///
  /// REMEMBERING is lazy on purpose. Resolving an id to a language needs the
  /// engine's track list, which is a round trip, so it is only asked for when
  /// an id actually changes - a few times a session rather than four times a
  /// second. Whatever is playing is remembered, not only what the viewer
  /// chose: after a failover the thing to restore is the track they were
  /// hearing, whoever picked it.
  ///
  /// RESTORING waits for the new media to publish tracks. `setAudioTrack`
  /// before they exist is refused, and libVLC 3 queues an added slave to the
  /// input thread, so the list arrives some ticks after the open completes.
  /// A non-null active id is the proof that it has. The audio language
  /// setting's look waits on the same proof ([_maybePickPreferredAudio]).
  ///
  /// Neither job starts until the engine has been handed this attempt's media
  /// ([_handedToEngine]). Before then every tick describes the media on its
  /// way out - an episode advance plays the last one on through the whole of
  /// the next one's resolve - and what it says is not this media's to
  /// remember, restore or pick for.
  void _rememberTracks(VlcPlayerValue value) {
    if (!_handedToEngine) return;
    final audioId = value.activeAudioTrackId;
    final subtitleId = value.activeSubtitleTrackId;

    if (_restorePending) {
      // Nothing to match against yet.
      if (audioId == null && subtitleId == null) return;
      _restorePending = false;
      unawaited(_restoreTracks());
      return;
    }

    _maybePickPreferredAudio(value);
    if (audioId != _seenAudioTrackId) {
      _seenAudioTrackId = audioId;
      if (audioId != null) unawaited(_snapshotAudio(audioId));
    }
    if (subtitleId != _seenSubtitleTrackId) {
      _seenSubtitleTrackId = subtitleId;
      // A cleared subtitle is a choice too - "off" has to survive a reopen as
      // surely as a language does.
      _rememberedSubtitle = null;
      if (subtitleId != null) unawaited(_snapshotSubtitle(subtitleId));
    }
  }

  /// libVLC's `audio-language` option for the media this attempt opens, or
  /// null while the audio language setting is on Auto.
  ///
  /// With it libVLC selects the language's track itself as the media's
  /// streams are created - and again when they are recreated mid-stream -
  /// wherever the source declares which track is in it, so nothing is
  /// switched and nothing goes silent. It names, in the order the look puts
  /// them on, the language of the viewer's own pick where that goes back on
  /// ([_viewerAudioOutranks]), then the setting's - each by every code libVLC
  /// may file it under ([vlcLanguageCodes]). [_pickPreferredAudio] still looks
  /// once the tracks are listed, for the tracks whose language only their
  /// name tells.
  String? _audioLanguageOption() {
    final preferred = _preferredAudioToPick;
    if (preferred == null) return null;
    final codes = <String>{
      if (_viewerAudioOutranks) ...vlcLanguageCodes(_viewerAudio?.language),
      ...vlcLanguageCodes(preferred),
    };
    if (codes.isEmpty) return null;
    return ':audio-language=${codes.join(',')}';
  }

  /// Whether the viewer's own pick can be told among the tracks of the source
  /// [url] names: by the language it is in, or - for a pick that names none -
  /// on the very copy it was picked on, by its name and its number. See
  /// [_viewerAudioOutranks].
  bool _viewerAudioTellableOn(String? url) {
    final viewer = _viewerAudio;
    return viewer != null && (viewer.hasLanguage || _viewerAudioCopy == url);
  }

  /// Starts [_pickPreferredAudio] once the media has published its audio, and
  /// again on each change to the list until the setting has its answer.
  void _maybePickPreferredAudio(VlcPlayerValue value) {
    final preferred = _preferredAudioToPick;
    if (preferred == null ||
        value.activeAudioTrackId == null ||
        _pickingPreferredAudio ||
        _preferredAudioCheckedRevision == value.trackRevision) {
      return;
    }
    _preferredAudioCheckedRevision = value.trackRevision;
    _pickingPreferredAudio = true;
    final generation = _generation;
    unawaited(
      _pickPreferredAudio(preferred).whenComplete(() {
        // A newer attempt has a latch of its own.
        if (generation == _generation) _pickingPreferredAudio = false;
      }),
    );
  }

  /// The audio language setting's look at the media this attempt opened.
  ///
  /// A track the viewer picked on this content goes back on first, where it
  /// can be told on this media ([_viewerAudioOutranks]), and that spends the
  /// setting. A pick this media does not have leaves the setting to decide,
  /// as though nobody had picked.
  ///
  /// The media's track in the language goes on - unless the one playing is in
  /// it already, which stays: a source playing Hindi DD 5.1 is not moved to
  /// its Hindi 2.0. That spends the setting for this media, and the pick is
  /// not the viewer's: the next reopen asks the setting again rather than
  /// putting this track back by number, which on another provider's copy is
  /// another language.
  ///
  /// Media with no track in the language - not listed yet, or not at all - is
  /// put back on what was playing before this reopen if it has that, and is
  /// otherwise left on its own default. The setting goes on watching the list
  /// meanwhile: the language can still arrive late, as a resumed MKV's tracks
  /// do.
  ///
  /// A commentary or an audio description libVLC put on for itself is never
  /// left playing, though. Asked for a language ([_audioLanguageOption]) it
  /// takes the first track the source declares in it, commentary or film, so
  /// one playing is no sign anybody chose it: the film's own track in the
  /// language goes on instead, and where the language has nothing else, the
  /// first track that is the film - the media's own default, as near as the
  /// list can tell.
  Future<void> _pickPreferredAudio(String preferred) async {
    final generation = _generation;
    bool superseded() =>
        _disposed ||
        generation != _generation ||
        _preferredAudioToPick != preferred;
    try {
      final tracks = await _audioTracksWithLanguages();
      if (superseded()) return;
      if (_viewerAudioOutranks) {
        final viewers = matchRememberedTrack(tracks, _audioToRestore);
        if (viewers != null) {
          await _switchAudio(viewers.id);
          if (superseded()) return;
          _preferredAudioToPick = null;
          _audioToRestore = null;
          return;
        }
        _viewerAudioOutranks = false;
      }
      final active = _controller.value.activeAudioTrackId;
      final enginesCommentary =
          active != _audioPutOn &&
          tracks.any(
            (track) => track.id == active && isCommentaryOrDescription(track),
          );
      final match = findPreferredAudioTrack(
        tracks,
        preferred,
        activeId: enginesCommentary ? null : active,
      );
      if (match != null) {
        await _switchAudio(match.id);
        if (superseded()) return;
        // Spent once the engine has taken it: a refusal is looked at again
        // with the next change to the list.
        _preferredAudioToPick = null;
        _audioToRestore = null;
        return;
      }
      final carried = _audioToRestore;
      _audioToRestore = null;
      final back =
          matchRememberedTrack(tracks, carried) ??
          (enginesCommentary
              ? tracks
                    .where((track) => !isCommentaryOrDescription(track))
                    .firstOrNull
              : null);
      if (back != null) await _switchAudio(back.id);
    } on Object {
      // An engine that will not list or set keeps its own choice, which is
      // where the viewer would have been without the setting.
    }
  }

  /// Puts audio track [id] on, unless it is on already. Only selects: libVLC
  /// plays it one caching interval later, and nothing seeks (see the Tracks
  /// tab's `_setTrack`). Throws the engine's refusal.
  Future<void> _switchAudio(int id) async {
    _audioPutOn = id;
    if (id == _controller.value.activeAudioTrackId) return;
    await _controller.setAudioTrack(id);
  }

  /// The engine's audio tracks, each with the language it is in - which no
  /// native reports on the track itself - read off `getMediaInfo` and the
  /// track's name. See [withTrackLanguages].
  Future<List<VlcTrackDescription>> _audioTracksWithLanguages() async {
    final tracks = await _controller.getAudioTracks();
    List<VlcMediaTrackInfo> info = const [];
    try {
      info = (await _controller.getMediaInfo()).audioTracks;
    } on Object {
      // The names are often enough on their own: libVLC names a track
      // `Track 2 - [Hindi]`.
    }
    return withTrackLanguages(tracks, info);
  }

  /// The engine's subtitle tracks, each with the language it is in, read the
  /// way [_audioTracksWithLanguages] reads the audio: a subtitle carried to
  /// another provider's copy follows its language there, not its name or its
  /// number, which on that copy can be another language's.
  Future<List<VlcTrackDescription>> _subtitleTracksWithLanguages() async {
    final tracks = await _controller.getSubtitleTracks();
    List<VlcMediaTrackInfo> info = const [];
    try {
      info = (await _controller.getMediaInfo()).subtitleTracks;
    } on Object {
      // As for the audio: libVLC names a track `Track 3 - [English]`.
    }
    return withTrackLanguages(tracks, info);
  }

  /// The viewer picked [track] from the Audio tab - see [_viewerAudio].
  /// Reported before the engine is asked for it.
  ///
  /// It stands for the rest of this content: nothing still due to this media
  /// - the setting's look, a reopen's restore - may undo it, and each later
  /// reopen puts it back.
  ///
  /// A pick made while this attempt's media is still opening was made on the
  /// media on its way out - a panel left up over a failover lists that
  /// media's tracks until the new one has its own. Nothing has been heard of
  /// the new media yet, so the pick is carried to it as a reopen carries one,
  /// with the setting still its fallback, rather than leaving it with
  /// neither.
  void _onAudioPicked(VlcTrackDescription track) {
    if (_disposed) return;
    final pick = RememberedTrack.of(track);
    _viewerAudio = pick;
    _viewerAudioCopy = _engineStreamUrl;
    if (!_handedToEngine) {
      _audioToRestore = pick;
      _viewerAudioOutranks = _viewerAudioTellableOn(_attemptStreamUrl);
      if (_preferredAudioToPick == null) _restorePending = true;
      return;
    }
    _preferredAudioToPick = null;
    _audioToRestore = null;
  }

  /// The source this attempt opens, by its URL; null before there is one.
  String? get _attemptStreamUrl =>
      _resolved?.streams.elementAtOrNull(_attemptIndex)?.url;

  Future<void> _snapshotAudio(int id) async {
    final generation = _generation;
    try {
      final tracks = await _audioTracksWithLanguages();
      if (_disposed || generation != _generation) return;
      _rememberedAudio = RememberedTrack.of(
        tracks.where((t) => t.id == id).firstOrNull,
      );
    } on Object {
      // A list the engine will not produce is not worth failing an attempt
      // over; the pick simply is not carried this time.
    }
  }

  Future<void> _snapshotSubtitle(int id) async {
    final generation = _generation;
    try {
      final tracks = await _subtitleTracksWithLanguages();
      if (_disposed || generation != _generation) return;
      _rememberedSubtitle = RememberedTrack.of(
        tracks.where((t) => t.id == id).firstOrNull,
      );
    } on Object {
      // See above.
    }
  }

  /// Puts the remembered picks back on the media that has just opened.
  ///
  /// Each half is independent: a source that carries the right audio but not
  /// the right subtitle should still get the audio.
  Future<void> _restoreTracks() async {
    final generation = _generation;
    try {
      // Under the audio language setting the audio half is its look's.
      final audio = _preferredAudioToPick == null ? _audioToRestore : null;
      if (audio != null) {
        final match = matchRememberedTrack(
          await _audioTracksWithLanguages(),
          audio,
        );
        if (_disposed || generation != _generation) return;
        // Unless the viewer has picked meanwhile: theirs stands.
        if (_audioToRestore == audio) {
          _audioToRestore = null;
          if (match != null) await _switchAudio(match.id);
        }
      }

      final subtitle = _rememberedSubtitle;
      if (subtitle != null) {
        if (_disposed || generation != _generation) return;
        final match = matchRememberedTrack(
          await _subtitleTracksWithLanguages(),
          subtitle,
        );
        if (_disposed || generation != _generation) return;
        if (match != null) {
          // The viewer was reading subtitles, so the Off default has been
          // overruled for this media already; putting one back must not then
          // be undone by the standing rule.
          _subtitlesOffPending = false;
          await _controller.setSubtitleTrack(match.id);
        } else {
          // Most likely not listed yet: the audio being on is what brought
          // this look, and it can come before the subtitles are read. Looked
          // for again as the list fills in.
          _subtitleToRestore = subtitle;
          _subtitleRestoreRevision = _controller.value.trackRevision;
        }
      }
    } on Object {
      // A refusal leaves the engine's own choice, which is where a viewer
      // would have been without any of this.
    }
  }

  /// Looks again for the subtitle [_restoreTracks] could not find, once for
  /// each change to the track list.
  void _maybeRestoreSubtitle(VlcPlayerValue value) {
    final wanted = _subtitleToRestore;
    if (wanted == null || _restoringSubtitle) return;
    if (value.trackRevision == _subtitleRestoreRevision) return;
    _subtitleRestoreRevision = value.trackRevision;
    _restoringSubtitle = true;
    unawaited(
      _restoreSubtitle(wanted).whenComplete(() => _restoringSubtitle = false),
    );
  }

  /// Puts [wanted] on if the list now has it. Stands down for a newer media,
  /// for the viewer's own pick, and for a subtitle file on screen.
  Future<void> _restoreSubtitle(RememberedTrack wanted) async {
    final generation = _generation;
    bool superseded() =>
        _disposed ||
        generation != _generation ||
        _subtitleToRestore != wanted ||
        _viewerChoseSubtitle ||
        _sideCars.active != null;
    try {
      final tracks = await _subtitleTracksWithLanguages();
      if (superseded()) return;
      final match = matchRememberedTrack(tracks, wanted);
      if (match == null) return;
      _subtitleToRestore = null;
      // See [_restoreTracks].
      _subtitlesOffPending = false;
      await _controller.setSubtitleTrack(match.id);
    } on Object {
      // As in [_restoreTracks]: the engine's own choice stands.
    }
  }

  /// One `disableSubtitle`, with the engine's refusal absorbed.
  ///
  /// Never allowed to throw: on the open chain it sits between `setMedia` and
  /// the playing stage, and on the tick path it is unawaited, so a backend
  /// that will not answer would take the whole attempt down or reach the zone.
  /// A subtitle that would not turn off is a wrong default, not a dead player,
  /// and the viewer can still turn it off by hand.
  Future<void> _disableSubtitles() async {
    try {
      await _controller.disableSubtitle();
    } on Object {
      return;
    }
  }

  /// A side-car went on or off. On, libVLC's own subtitle goes off now
  /// rather than at the next tick - see [_applySubtitleDefault].
  void _onSideCars() {
    if (_disposed) return;
    if (_sideCars.active != null) _applySubtitleDefault(_controller.value);
  }

  /// Starts [_pickPreferredSubtitle] once the video has published tracks - an
  /// active track is the proof, as it is for [_rememberTracks] - or has begun
  /// to play without any; and again on each change to the list, and when it
  /// begins to play, until Auto has decided.
  void _maybePickPreferredSubtitle(VlcPlayerValue value) {
    if (!_autoPickPending || _autoPicking) return;
    if (value.activeAudioTrackId == null &&
        value.activeSubtitleTrackId == null &&
        !_sawFrames) {
      return;
    }
    final look = (value.trackRevision, _sawFrames);
    if (look == _autoPickLook) return;
    _autoPickLook = look;
    _autoPicking = true;
    unawaited(
      _pickPreferredSubtitle().whenComplete(() => _autoPicking = false),
    );
  }

  /// Auto's look at the tracks inside the video, for media whose side-cars
  /// had none in the viewer's language.
  ///
  /// A track in the viewer's language goes on - libVLC itself only turns one
  /// on when the file flags it as the default, so a film carrying English
  /// subtitles otherwise started without them. Failing that, the source's
  /// last side-car, which is what Auto always showed when nothing matched;
  /// and failing that, whatever the media chose for itself.
  ///
  /// Never over a viewer's own choice: opening the panel ends it, wherever it
  /// has got to.
  ///
  /// The list fills in as the demuxer reads the file - a resumed MKV lists
  /// its audio first and its subtitles after - so until the media plays,
  /// finding nothing in the viewer's language decides nothing: the next look
  /// comes with the next change to the list, or with the first picture.
  /// After that, with none of the source's files to fall back on, Auto goes
  /// on watching the list for a track in the viewer's language.
  Future<void> _pickPreferredSubtitle() async {
    final generation = _generation;
    bool superseded() =>
        _disposed ||
        generation != _generation ||
        _viewerChoseSubtitle ||
        _sideCars.active != null;
    final sources = _sideCars.tracks
        .where((track) => track.origin == SideCarOrigin.source)
        .toList();

    final preferred = languageCodeOf(_read(subtitleLanguageProvider));
    if (preferred != null) {
      try {
        final listed = await _controller.getSubtitleTracks();
        if (superseded()) return;
        List<VlcMediaTrackInfo> info = const [];
        try {
          info = (await _controller.getMediaInfo()).subtitleTracks;
        } on Object {
          // The description is often enough on its own: libVLC names a track
          // `Track 1 - [English]`.
        }
        if (superseded()) return;
        // Each with the language it is in, read as the audio is - see
        // [withTrackLanguages].
        final tracks = withTrackLanguages(listed, info);
        if (kDebugMode) {
          debugPrint(
            'Subtitles: Auto looks for $preferred in '
            '${tracks.map((t) => '${t.id}:${t.name}').toList()} '
            '(on: ${_controller.value.activeSubtitleTrackId})',
          );
        }
        final matches = [
          for (final track in tracks)
            if (languageCodeOf(track.language) == preferred) track,
        ];
        // A forced track carries only the lines in another language than
        // the film's, so a full one is the better answer where there is one.
        bool full(VlcTrackDescription track) =>
            !track.name.toLowerCase().contains('forced');
        final active = _controller.value.activeSubtitleTrackId;
        final best = matches.where(full).firstOrNull ?? matches.firstOrNull;
        if (best != null) {
          final activeIsFull = matches.any(
            (track) => track.id == active && full(track),
          );
          _autoPickPending = false;
          if (!activeIsFull && active != best.id) {
            await _controller.setSubtitleTrack(best.id);
          }
          return;
        }
      } on Object {
        // An engine that will not list or set is left to its own choice
        // below.
      }
    }
    if (superseded() || !_sawFrames || sources.isEmpty) return;
    _autoPickPending = false;
    if (_controller.value.activeSubtitleTrackId != null) return;
    unawaited(_sideCars.select(sources.last, from: _controller.value.position));
  }

  /// A side-car in a format SkyStream does not read - MicroDVD, VobSub, TTML
  /// - goes to libVLC, as every side-car once did. libVLC's add selects what
  /// it adds, and it arrives as one of the video's own tracks.
  void _handSideCarToEngine(SideCarTrack track) {
    unawaited(() async {
      try {
        final headers = track.headers;
        final uri = headers == null
            ? track.url
            : await _proxied(track.url, headers);
        if (_disposed) return;
        await _controller.addSubtitle(uri);
      } on Object {
        // Nothing more can show it.
      }
    }());
  }

  /// The attempt failed, noticed by [sign] (spec 2, *Detection*), and
  /// recovery decides what happens next. [detail] is today's message for it,
  /// which the viewer sees if it comes to a failover or the failed screen.
  void _onFailure(FailureSign sign, String detail) {
    if (_disposed || _resolved == null) return;
    final before = _policy.phase;
    final step = _policy.failed(sign, detail: detail);
    if (step is Carry && _policy.phase == before) {
      // Nothing new to recover: the check while opening has nowhere proven
      // to go, or this attempt's failure was already reported. A stalled
      // player that then errors is one failure, and its second report must
      // not move what the first one set, such as the viewer's pause.
      return;
    }
    // Recovery has the attempt now: nothing is opening for the first-frame
    // watch to judge.
    _firstFrame = null;
    final torrent = _torrentStatus;
    _qoe.error(
      detail,
      sign: sign.name,
      torrent: _attemptIsTorrent && torrent != null
          ? <String, Object?>{
              'peers': torrent.peers,
              'totalPeers': torrent.totalPeers,
              'loadedMb': torrent.loadedBytes ~/ (1 << 20),
            }
          : null,
    );
    _lastFailureDetail = detail;
    _pauseRequestsAtFailure = _controller.pauseRequests;
    // A source that failed is parked over its picture while recovery checks
    // and waits (plan note 1): its player is dead, or for a starved video
    // still playing sound the picture has lost. A stall keeps its player,
    // which libVLC may yet ride out.
    final recovering =
        _policy.phase != RecoveryPhase.watching &&
        _policy.phase != RecoveryPhase.gaveUp;
    // The failure's not-playing edge let the display sleep (see
    // [_syncPlayingState]), and recovery can wait minutes over the picture: a
    // phone that slept through "Waiting for network…" came back to sound on a
    // dark screen. The failed screen lets it sleep again ([_fail]).
    if (recovering) unawaited(WakelockPlus.enable());
    if (recovering && sign != FailureSign.stalled && _pictureUp) {
      unawaited(_park(keepPicture: sign != FailureSign.noPicture));
    }
    _run(step);
  }

  /// Parks the failed source (plan note 1): the same media again, at where
  /// the reopen will start, not told to play. libVLC opens no input until
  /// play, so it costs nothing; the dead or stalled player is released at
  /// once, off the platform thread; and one native hold keeps the picture
  /// through the wait and the reopen. [keepPicture] is false for a picture
  /// that went missing: there is none to keep, and the start-up view goes up
  /// saying why, as it does wherever the output can't hold.
  Future<void> _park({required bool keepPicture}) async {
    final source = _controller.currentMediaSource;
    final resolved = _resolved;
    if (source == null || resolved == null || _parked) return;
    _parked = true;
    // Under the start-up view's source line, wherever the picture can't be
    // kept; over a kept picture the pill says "Reconnecting…" instead.
    _setFailReason(
      '${sourceRowLabel(resolved.streams[_attemptIndex])} · '
      '$_lastFailureDetail',
    );
    _setKeptPicture(keepPicture);
    _setSawFrames(false);
    // The failed player can still be sending reports - a starved video plays
    // its sound on - and one already on its way, saying playing, would read as
    // the viewer's play of the parked media: none counts until the park has
    // handed the new media over, as an open's own setup does.
    _handedToEngine = false;
    // A parked reopen starts un-zoomed too (pinch-to-zoom).
    _videoScale.value = 1.0;
    try {
      await _controller.setMedia(
        VlcMediaSource(
          uri: source.uri,
          httpHeaders: source.httpHeaders,
          mediaOptions: source.mediaOptions,
          startPosition: _reopenTarget(),
          isLive: source.isLive,
        ),
        keepPicture: keepPicture,
      );
    } on Object {
      // A player that can't take media any more is the next open's problem.
      if (!_disposed && _parked) _handedToEngine = true;
      return;
    }
    if (_disposed || !_parked) return;
    // Every backend has sent the parked media's opening snapshot by now, and
    // dropped the failed player's: what follows is the parked media's.
    _handedToEngine = true;
    if (keepPicture && !_controller.value.isPictureHeld) {
      _setKeptPicture(false);
    }
  }

  /// Acts on what recovery asked for, then arms its next wake-up.
  void _run(RecoveryStep step) {
    if (_disposed) return;
    final resolved = _resolved;
    switch (step) {
      case Carry():
        break;
      case RunCheck(:final source):
        unawaited(_runCheck(source));
      case ReopenSource(:final source, :final live, :final keepPicture):
        _qoe.waitEnd();
        if (!keepPicture && resolved != null) {
          _setFailReason(
            '${sourceRowLabel(resolved.streams[source])} · '
            '$_lastFailureDetail',
          );
        }
        unawaited(
          _openAttempt(
            source,
            startAt: live ? Duration.zero : _reopenTarget(),
            reason: live ? 'reconnect' : 'retry',
            keepPicture: keepPicture,
            // A viewer who paused while it recovered finds it paused.
            autoPlay: _controller.pauseRequests == _pauseRequestsAtFailure,
            status: _l10n?.playerReconnecting ?? '',
          ),
        );
      case FailOverTo(:final source, :final detail, :final revert):
        _qoe.waitEnd();
        _failOverTo(source, detail, revert: revert);
      case WaitHere(:final label):
        _qoe.wait(
          label: label.name,
          positionMs: _reopenTarget().inMilliseconds,
        );
      case GiveUp(:final cause, :final detail):
        _qoe
          ..waitEnd()
          ..gaveUp(cause: cause.name);
        _giveUp(detail);
    }
    _syncRecoveryLabel();
    _armRecoveryTimer();
  }

  /// Checks [source]'s server for recovery and tells it what came back.
  Future<void> _runCheck(int source) async {
    final resolved = _resolved;
    if (resolved == null || source < 0 || source >= resolved.streams.length) {
      return;
    }
    final generation = _checkGeneration;
    CheckResult result;
    try {
      result = await _read(sourceCheckProvider)(resolved.streams[source]);
    } on Object {
      result = const CheckResult(
        kind: CheckClass.network,
        outcome: ProbeOutcome.unhealthy,
        fault: NetworkFault.other,
      );
    }
    if (_disposed || generation != _checkGeneration) return;
    _qoe.check(
      sourceIndex: source,
      kind: result.kind.name,
      status: result.status,
      fault: result.fault?.name,
      ms: result.elapsed.inMilliseconds,
    );
    _run(_policy.checked(source, result));
  }

  /// Moves to another source: the start-up view names it (spec 2: "The
  /// start-up view appears only for a failover to another source, where it
  /// shows which one").
  void _failOverTo(int index, String detail, {required bool revert}) {
    final resolved = _resolved;
    if (resolved == null) return;
    _markFailed(_attemptIndex);
    if (revert) {
      _notify(
        _l10n?.playerSourceRestoredPrevious ??
            'That source would not play. Restored the previous one.',
      );
    } else {
      // Failover is otherwise silent: the engine is quietly handed a
      // different URL behind a frame that has stopped moving. This says
      // why, until the next source produces a frame - naming the source it
      // is about, because the line above it names the next one.
      _setFailReason(
        '${sourceRowLabel(resolved.streams[_attemptIndex])} · $detail',
      );
    }
    unawaited(
      _openAttempt(
        index,
        startAt: _reopenTarget(),
        reason: revert ? 'revert' : 'failover',
      ),
    );
  }

  /// Recovery gave up: the failed screen, which still offers Retry.
  void _giveUp(String detail) {
    final resolved = _resolved;
    if (resolved == null) return;
    _markFailed(_attemptIndex);
    // Say what actually went wrong: a single-source channel refused for DRM
    // should name the scheme rather than just count to one.
    final total = resolved.streams.length;
    _fail(
      _l10n?.playerNoSourcesPlayableWithReason(total, detail) ??
          (total == 1
              ? detail
              : 'None of the $total sources would play - $detail'),
    );
  }

  /// Arms the one timer recovery asks for, at its next due time.
  void _armRecoveryTimer() {
    _keepAwakeThroughWait();
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
    final due = _policy.nextDue;
    if (due == null || _disposed) return;
    final wait = due.difference(clock.now());
    _recoveryTimer = Timer(wait.isNegative ? Duration.zero : wait, () {
      _recoveryTimer = null;
      if (!_disposed) _run(_policy.due());
    });
  }

  /// Lets the display sleep once a wait over the picture has lasted
  /// [kWaitKeepsAwakeFor]: a played source whose server never answers waits
  /// for ever (spec 2), and a phone left on "Reconnecting…" shouldn't stay lit
  /// all night. Its next playing edge takes the lock again.
  void _keepAwakeThroughWait() {
    if (_policy.label == RecoveryLabel.none) {
      _waitAwake?.cancel();
      _waitAwake = null;
      return;
    }
    _waitAwake ??= Timer(kWaitKeepsAwakeFor, () {
      if (_disposed || _policy.label == RecoveryLabel.none) return;
      unawaited(WakelockPlus.disable());
    });
  }

  /// The pill over the picture, from recovery's label. Nothing when it has no
  /// label: the open that follows a step sets its own line.
  void _syncRecoveryLabel() {
    final l10n = _l10n;
    if (l10n == null) return;
    switch (_policy.label) {
      case RecoveryLabel.reconnecting:
        _setStatus(l10n.playerReconnecting);
      case RecoveryLabel.waitingForNetwork:
        _setStatus(l10n.playerWaitingForNetwork);
      case RecoveryLabel.none:
        break;
    }
  }

  /// The startup view's row pick, for tests that need one with no panel open.
  @visibleForTesting
  void debugPickSource(int index) => _pickSource(index, onTrial: false);

  /// Runs the reachability check for [stream], opened without having been
  /// checked.
  ///
  /// Alongside the open, never in front of it: a pick is the viewer's choice
  /// and failover has already waited long enough. A "no" can still end the
  /// open - see [_abandonUnreachable] - but only on the terms set there.
  /// Stamped with the resolve it belongs to, like the race's own probes, so an
  /// answer that lands after the list has changed is dropped.
  void _checkWhileOpening(int index, StreamResult stream) {
    final generation = _resolveGeneration;
    final attempt = _generation;
    _onProbe(generation, index, ProbeOutcome.trying);
    unawaited(
      probeSource(stream).then(
        (outcome) {
          _onProbe(generation, index, outcome);
          if (!outcome.reached) _abandonUnreachable(attempt, index);
        },
        onError: (Object _) =>
            _onProbe(generation, index, ProbeOutcome.unhealthy),
      ),
    );
  }

  /// Gives up on the source at [index], which the check has just found
  /// unreachable while it opened, for one known to work.
  ///
  /// Only the open that asked, and only before it has a picture - a source on
  /// screen was reached, whatever the probe says. And only when there is
  /// somewhere proven to go: the session a hand-picked source interrupted, or
  /// a source the check vouched for. With neither, the open carries on,
  /// because the probe is wrong about slow hosts and its word alone must not
  /// end the only hope left.
  ///
  /// The row keeps its "unreachable" once this has run, so picking it again
  /// opens it with no check to overrule the viewer: they have seen the verdict
  /// and asked anyway.
  void _abandonUnreachable(int attempt, int index) {
    if (_disposed || attempt != _generation || _attemptIndex != index) return;
    // Recovery decides: only before the attempt's first picture, and only
    // with somewhere proven to go.
    _onFailure(
      FailureSign.unreachableWhileOpening,
      _l10n?.playerReasonNoAnswer ?? 'no answer from the link',
    );
  }

  /// Starts the first-frame watch for the attempt stamped [generation]:
  /// given up on after 30 s with no sign of progress, or 60 s whatever the
  /// progress; three minutes for a [torrent], waiting on pieces to seed (plan
  /// note 6). Judged on the watchdog's tick, whatever the engine reports: the
  /// stall watchdog stands down while the engine says paused, stopped or
  /// ended, and before the screen reaches its playing stage, and a source
  /// stuck in any of those said "Opening…" for minutes.
  void _watchFirstFrame(int generation, {required bool torrent}) {
    _firstFrameGeneration = generation;
    _firstFrame = FirstFrameWatch(torrent: torrent);
  }

  /// One tick of the first-frame watch.
  void _checkFirstFrame() {
    final watch = _firstFrame;
    if (watch == null || _disposed) return;
    if (_sawFrames || _firstFrameGeneration != _generation) {
      _firstFrame = null;
      return;
    }
    // Off screen, waiting for the viewer's play, or parked: the wait is
    // nobody's, and starts over rather than giving up on a source nobody is
    // watching.
    if (!_foreground || _inPip || _awaitingPlay || _parked) {
      watch.restart();
      return;
    }
    if (_handedToEngine && !_firstFrameSampling) {
      unawaited(_sampleOpening(watch));
    }
    if (watch.verdict == FirstFrameVerdict.wait) return;
    if (!_controller.isAttached && _remountedFor != _generation) {
      // The media never reached a native player: it waits, queued in the
      // controller, for one that never came (one iOS open in about sixty,
      // 2026-10-13). libVLC never had it, so the source has not failed: a new
      // VlcPlayer makes a new player, the media goes to it as it attaches, and
      // the watch starts again. A second miss runs the recovery below as ever.
      _qoe.error('no native player');
      _remountedFor = _generation;
      _setKeptPicture(false);
      setState(() => _playerMount += 1);
      watch.restart();
      return;
    }
    _firstFrame = null;
    _onFailure(
      FailureSign.neverStarted,
      _l10n?.playerReasonSourceNeverStarted ?? 'the source never started',
    );
  }

  /// Reads what the opening attempt has to show for itself into [watch].
  Future<void> _sampleOpening(FirstFrameWatch watch) async {
    _firstFrameSampling = true;
    VlcMediaStats? stats;
    try {
      stats = await _controller.getMediaStats();
    } on Object {
      stats = null;
    }
    _firstFrameSampling = false;
    if (_disposed || !identical(watch, _firstFrame)) return;
    final value = _controller.value;
    watch.sample(
      OpeningSample(
        state: value.state,
        prebuffer: value.bufferingProgress,
        readBytes: stats?.readBytes ?? 0,
        demuxReadBytes: stats?.demuxReadBytes ?? 0,
        decodedVideo: stats?.decodedVideo ?? 0,
        decodedAudio: stats?.decodedAudio ?? 0,
        startGated: value.isStartGated,
      ),
    );
  }

  /// Records that row [index] was opened and would not play, for the source
  /// lists to say so.
  void _markFailed(int index) {
    if (_disposed || !mounted) return;
    setState(() => _failedRows.add(index));
    _publishPanelData();
  }

  /// Starts both attempt clocks. Called when an attempt begins and again when
  /// the engine is finally handed media.
  void _startAttemptClock() {
    _attemptStartedAt = clock.now();
    _playingAge = Duration.zero;
    _stallClock.reset();
    _starved.reset();
    _ranSinceOpen = false;
    _stopReported = false;
    _resetStallClock();
    // The decoder counters belong to one media. A reopen resets them natively,
    // so a baseline taken from the outgoing media would read as a colossal
    // negative delta on the incoming one.
    _videoBaseline = null;
    _videoWindow = Duration.zero;
    // The seek correction describes the outgoing media's counters. The band's
    // rate baseline is left alone on purpose - see [noteMediaChanged].
    _bufferedAhead.noteMediaChanged();
    // So does the byte count, which restarts with the media.
    _arrivalReadBytes = null;
    _bytesArrivedAt = null;
    _lastSeekAt = null;
  }

  void _resetStallClock() {
    _stallClock.restart();
    _stallRestarted = true;
    _lastStallAction = StallAction.none;
  }

  /// The one thing that notices a source has gone quiet.
  ///
  /// libVLC parked on a half-open socket reports neither `error` nor `ended`;
  /// it sits in `buffering` indefinitely. So the trigger is an advancing
  /// position rather than the state enum, which reports `buffering` throughout
  /// healthy playback on some builds.
  ///
  /// Escalation is deliberately shallow: a nudge, then the failover ladder.
  void _checkStall() {
    if (_disposed || _stage != _Stage.playing) return;
    final value = _controller.value;
    // Recovery is under way: its own schedule runs, and a parked or
    // reopening source is not a stall.
    if (_policy.phase != RecoveryPhase.watching || _parked) {
      _resetStallClock();
      return;
    }

    // A frozen position is only a stall if playback was supposed to be
    // happening. A deliberate pause, a backgrounded app and PiP all freeze it
    // legitimately - and the clock restarts with them, so ten minutes paused
    // is not ten minutes stalled the instant play resumes.
    final playbackExpected =
        _foreground &&
        !_inPip &&
        value.state != VlcPlaybackState.paused &&
        value.state != VlcPlaybackState.stopped &&
        value.state != VlcPlaybackState.ended &&
        value.state != VlcPlaybackState.error;
    if (!playbackExpected) {
      // Clear the "Reconnecting" line here too: _resetStallClock zeroes the
      // action flag, so _onProgress would never see a recovery to clear it on.
      if (_lastStallAction != StallAction.none) _setStatus('');
      _resetStallClock();
      return;
    }
    // A seek freezes the reported position on purpose: the demuxer has to
    // reposition and refill before it reports anything at the new place, and
    // on a slow source that outlasts the recover threshold. Measured from
    // before the seek it reads as a dead source, and the recovery reopens the
    // media - which is why a skip forward could end with the duration blank,
    // the position at zero and every track back at the engine's own choice.
    // The window restarts instead, so a source that really cannot deliver
    // after a seek is still caught, just measured from the seek.
    final seeks = _controller.seekRequests;
    if (seeks != _seenSeekRequests) {
      _seenSeekRequests = seeks;
      _lastSeekAt = _attemptAge;
      // libVLC counts the jump as a demux discontinuity, which the
      // smoothness window would blame on the source: it starts again here.
      _videoBaseline = null;
      _videoWindow = Duration.zero;
      if (_lastStallAction != StallAction.none) _setStatus('');
      _resetStallClock();
      return;
    }

    _playingAge += _kWatchdogTick;

    // The position moved since the last tick, or the count started again
    // since: there is no stall to report, and this second belongs to the
    // other watchdog - the one that asks whether a picture came with the
    // sound. Exactly one of the two speaks per tick, which is what keeps them
    // from double-reporting the same second.
    final moved = _stallClock.tick(value.position);
    final restarted = _stallRestarted;
    _stallRestarted = false;
    if (moved || restarted) {
      _watchVideoHealth();
      return;
    }
    // A frozen clock ends the measurement window: the counters would keep
    // ticking over a stall that is not this device's fault and read as a
    // decode failure.
    _videoBaseline = null;
    _videoWindow = Duration.zero;

    // A source that has never shown a picture is the first-frame deadline's to
    // judge, on its own watch - see [_checkFirstFrame]. This one stands
    // down in exactly the states such a source gets stuck in.
    if (!_sawFrames) return;

    _watchArrival();
    // The stall began with a seek - allowing for the one report of the target
    // some backends make before the picture freezes - so it has its refill
    // ahead of it.
    final seekAt = _lastSeekAt;
    final afterSeek =
        seekAt != null &&
        _attemptAge - _stalledFor - seekAt <= _kAfterSeekSlack;
    final action = stallActionFor(
      stalledFor: _stalledFor,
      hadFrames: _sawFrames,
      lastAction: _lastStallAction,
      recoverAfter: _attemptIsTorrent
          ? kTorrentStallRecoverAfter
          : kStallRecoverAfter,
      arriving: _bytesArriving,
      afterSeek: afterSeek,
      // HLS and DASH get no nudge (plan note 3).
      adaptive: _adaptive,
    );
    switch (action) {
      case StallAction.none:
        return;
      case StallAction.nudge:
        _lastStallAction = action;
        // The spinner over the frozen frame is the controls' to draw, but
        // what is being done about it is only known here. Cleared by the next
        // movement - see [_onProgress].
        _setStatus(_l10n?.playerReconnecting ?? '');
        unawaited(_nudge(value));
      case StallAction.recover:
        _resetStallClock();
        _lastStallAction = StallAction.recover;
        _onFailure(
          FailureSign.stalled,
          _l10n?.playerReasonSourceStoppedResponding ??
              'the source stopped responding',
        );
    }
  }

  /// The other watchdog: whether a picture is arriving behind the sound.
  ///
  /// Runs only on ticks where the position moved, so it cannot duplicate the
  /// stall ladder above. Audio drives libVLC's clock, so a device
  /// software-decoding a rendition it cannot manage, and a vout that never
  /// opened at all, both look like flawless playback to every other signal.
  void _watchVideoHealth() {
    if (!_handedToEngine || _statsInFlight) return;
    // No picture is expected before the engine has produced one, and the
    // startup view is already saying so.
    if (!_sawFrames) return;
    _videoWindow += _kWatchdogTick;
    _statsInFlight = true;
    unawaited(_sampleVideoHealth());
  }

  /// Keeps the byte count current through a stall, when the video-health
  /// sampler stands down. Its answer is read on the next tick.
  void _watchArrival() {
    if (!_handedToEngine || _statsInFlight) return;
    _statsInFlight = true;
    unawaited(_sampleArrival());
  }

  Future<void> _sampleArrival() async {
    final generation = _generation;
    VlcMediaStats stats;
    try {
      stats = await _controller.getMediaStats();
    } on Object {
      _statsInFlight = false;
      return;
    }
    _statsInFlight = false;
    if (_disposed || generation != _generation) return;
    _noteArrival(stats);
  }

  void _noteArrival(VlcMediaStats stats) {
    if (!stats.isAvailable) return;
    // The demuxer's count for HLS and DASH: their segments come through
    // libVLC's adaptive module, and the input's own count is the playlist's.
    final bytes = arrivalBytesOf(stats, adaptive: _adaptive);
    final last = _arrivalReadBytes;
    _arrivalReadBytes = bytes;
    if (last != null && bytes > last) _bytesArrivedAt = _attemptAge;
  }

  /// Whether the source has delivered anything in the last few seconds.
  ///
  /// A frozen picture over a source still delivering is a refill - a seek
  /// fetching its keyframe run-up and a fresh buffer - not a source gone
  /// quiet, and nudging it throws the refill away. A few seconds rather than
  /// one tick, because bytes come in bursts. False where the engine has no
  /// counters, which leaves the ladder as it always was.
  bool get _bytesArriving {
    final at = _bytesArrivedAt;
    return at != null && _attemptAge - at <= _kArrivalWindow;
  }

  /// Says which side a stutter is coming from, once per change of verdict.
  ///
  /// "The video is not smooth" has two causes with opposite fixes: a decoder
  /// that cannot keep up wants a lower rendition, and a source arriving
  /// corrupt wants a different source. libVLC counts both, so the answer does
  /// not have to be guessed at from a description.
  ///
  /// Logged rather than shown. It is a diagnosis for whoever reads a report,
  /// and the player already acts on the half it can fix by itself - see
  /// [videoHealthFor] and the rendition step-down.
  void _reportSmoothness(
    VlcMediaStats stats,
    ({int displayed, int lost, int corrupted, int discontinuity, int decoded})
    baseline,
  ) {
    final displayed = stats.displayedPictures - baseline.displayed;
    final lost = stats.lostPictures - baseline.lost;
    final corrupted = stats.demuxCorrupted - baseline.corrupted;
    final discontinuity = stats.demuxDiscontinuity - baseline.discontinuity;

    final verdict = classifySmoothness(
      statsAvailable: stats.isAvailable,
      measuredFor: _videoWindow,
      displayed: displayed,
      lost: lost,
      corrupted: corrupted,
      discontinuity: discontinuity,
      decoded: stats.decodedVideo - baseline.decoded,
    );
    if (verdict == _lastSmoothness) return;
    _lastSmoothness = verdict;
    if (verdict == PlaybackSmoothness.unknown) return;

    final line = smoothnessReport(
      verdict,
      displayed: displayed,
      lost: lost,
      corrupted: corrupted,
      discontinuity: discontinuity,
    );
    if (verdict == PlaybackSmoothness.fine) {
      talker.info('Playback: $line');
    } else {
      talker.warning('Playback: $line');
    }
  }

  /// Turns one stats sample into the seek bar's buffered band.
  ///
  /// Rides the health sampler rather than polling on its own: the round trip
  /// is already being made once a second, and a second one for a cosmetic band
  /// would be a real cost on a weak device for no extra information.
  ///
  /// Cleared to nothing whenever the estimate cannot be trusted, so the band
  /// disappears instead of freezing at a stale width - a bar that keeps
  /// claiming a buffer through a stall is worse than one that admits it does
  /// not know.
  void _updateBufferedAhead(VlcMediaStats stats) {
    if (!stats.isAvailable) {
      _bufferedFraction.value = 0;
      return;
    }

    final value = _controller.value;
    // Where playback is going, not where the engine last said it was: every
    // backend goes on publishing the place a seek left until it takes, and
    // measured from there a step back looks like playback carrying on.
    final position = _controller.pendingSeekTarget.value ?? value.position;
    final fraction = bufferedFraction(
      position: position,
      duration: value.duration,
      ahead: _bufferedAhead.sample(
        readBytes: stats.readBytes,
        demuxReadBytes: stats.demuxReadBytes,
        position: position,
        at: _playingAge,
        // What tells the estimate a skip happened, so the bytes the skip
        // stranded stop being counted as buffer. See [BufferedAheadEstimator].
        seekRequests: _controller.seekRequests,
        speed: value.playbackSpeed,
        // The read-ahead libVLC was given for this media, which is all it can
        // hold; its own 16 MiB where the plan gave none.
        capacityBytes: (_bufferPlan?.ringMb ?? kRingFloorMb) * 1024 * 1024,
      ),
    );
    _bufferedFraction.value = fraction ?? 0;
  }

  /// One `getMediaStats` round trip, and what it means.
  Future<void> _sampleVideoHealth() async {
    final generation = _generation;
    VlcMediaStats stats;
    try {
      stats = await _controller.getMediaStats();
    } on Object {
      // A backend that will not answer is not evidence of anything, and the
      // flag must not stay raised: a detached controller throws on every call.
      _statsInFlight = false;
      return;
    }
    _statsInFlight = false;
    if (_disposed || generation != _generation) return;

    _updateBufferedAhead(stats);
    _noteArrival(stats);

    // A picture frozen while the sound plays on (plan note 5): on HLS and
    // DASH, where the video can starve alone. Recovery reopens where the
    // picture stopped, not at the sound's playhead (decision 5).
    final value = _controller.value;
    final starvedAt = _adaptive && value.videoSize != null && stats.isAvailable
        ? _starved.sample(
            decodedVideo: stats.decodedVideo,
            position: value.position,
            running:
                value.state == VlcPlaybackState.playing && !value.isStalled,
            remaining: value.duration > Duration.zero
                ? value.duration - value.position
                : null,
          )
        : null;
    if (starvedAt != null) {
      _videoBaseline = null;
      _videoWindow = Duration.zero;
      if (_controller.pendingSeekTarget.value == null) {
        _resumePosition = starvedAt;
      }
      _onFailure(
        FailureSign.videoStarved,
        _l10n?.playerReasonSourceStoppedResponding ??
            'the source stopped responding',
      );
      return;
    }

    final baseline = _videoBaseline;
    if (baseline == null) {
      // First reading of the window is the datum, never the verdict.
      _videoBaseline = (
        displayed: stats.displayedPictures,
        lost: stats.lostPictures,
        corrupted: stats.demuxCorrupted,
        discontinuity: stats.demuxDiscontinuity,
        decoded: stats.decodedVideo,
      );
      _videoWindow = Duration.zero;
      return;
    }

    _reportSmoothness(stats, baseline);

    final lost = stats.lostPictures - baseline.lost;
    final health = videoHealthFor(
      statsAvailable: stats.isAvailable,
      // Track info, not the vout, so this stays true for the very failure
      // being looked for: a video track that exists and is not reaching the
      // screen. False only for genuinely audio-only media.
      hasVideoTrack: _controller.value.videoSize != null,
      measuredFor: _videoWindow,
      displayed: stats.displayedPictures - baseline.displayed,
      lost: lost,
    );
    if (health == VideoHealth.ok) return;

    // Whatever happens next reopens or replaces the media, so the window that
    // produced this verdict is spent either way.
    _videoBaseline = null;
    _videoWindow = Duration.zero;
    switch (health) {
      case VideoHealth.ok:
        return;
      case VideoHealth.absent:
        // On Android this is how MediaCodec dying mid-play looks: one reopen
        // in software comes first. Not when the output dropped what the
        // decoder made (the surface stall): that is the ordinary way's.
        if (shouldRetryInSoftware(
          platform: defaultTargetPlatform,
          hardwareDecoding:
              (_read(playerSettingsProvider).asData?.value ??
                      const PlayerSettings())
                  .hardwareDecoding,
          alreadySoftware: _softwareRetry,
          lostInWindow: lost,
        )) {
          _retryInSoftware();
          return;
        }
        // Nothing has reached the screen for a whole window while the clock
        // ran. Handed to the ladder, which already knows how to reopen a
        // source once and when to move on.
        _onFailure(
          FailureSign.noPicture,
          _l10n?.playerReasonSourceNeverStarted ?? 'the source never started',
        );
      case VideoHealth.overwhelmed:
        _stepDownRendition();
    }
  }

  /// Asks for one rung less of the same stream and reopens where we are.
  ///
  /// Not a failover: the source is fine, the request was too big for this
  /// device, and its mirrors would be decoded by the same silicon.
  ///
  /// Bounded twice: [stepDownFrom] returns null at the floor, and the reopen
  /// carries the current retry count so it cannot refill the failover budget.
  void _stepDownRendition() {
    // `:adaptive-maxheight` means nothing to a progressive file: a reopen
    // would buy nothing, and on the emulators it was the one that landed next
    // to the outage (plan note 11).
    if (!_adaptive) return;
    // From the cap this media was opened with: Auto's - which the quality
    // preference can have set below the device's - or a pick's.
    final next = stepDownFrom(_renditionCap);
    // Already at the floor. Reopening on a loop is worse than the slideshow.
    if (next == null) return;
    if (_qualityPick != null) {
      // The pick comes down itself, so the Quality tab ticks what plays now.
      _qualityPick = next;
      _publishPanelData();
    } else {
      _adaptiveMaxHeight = next;
    }
    unawaited(
      _openAttempt(
        _attemptIndex,
        startAt: _reopenTarget(),
        reason: 'step-down',
        keepPicture: true,
      ),
    );
  }

  /// Reopens this source where it is, decoding in software, at the rendition
  /// a CPU can manage (spec 1.6): what MediaCodec dying mid-play gets instead
  /// of the same codec again and then a failover. Software for the rest of
  /// the screen's life; a second failure goes the ordinary way.
  void _retryInSoftware() {
    _softwareRetry = true;
    final cap = softwareRetryCap(
      tier:
          ref.read(deviceProfileProvider).asData?.value.tier ??
          DeviceTier.standard,
      panelHeightPx: _panelHeightPx(),
      currentCap: _adaptiveMaxHeight,
    );
    _adaptiveMaxHeight = cap;
    final pick = _qualityPick;
    if (pick != null && pick > cap) {
      // The pick comes down too, so the Quality tab ticks what plays now.
      _qualityPick = cap;
      _publishPanelData();
    }
    unawaited(
      _openAttempt(
        _attemptIndex,
        startAt: _reopenTarget(),
        reason: 'software',
        keepPicture: true,
      ),
    );
  }

  /// Re-issues the current position and resumes.
  ///
  /// A demuxer that dropped its request after a Range response it disliked
  /// starts a new one, and a stream the engine quietly parked simply resumes.
  /// Only the seek is conditional: a live feed has nowhere to seek to, so it
  /// gets the play() on its own.
  ///
  /// "Current" is where playback is meant to be: a seek still on its way wins
  /// over the published position, which every backend holds at the place the
  /// seek left until it lands. Re-seeking to that undid the viewer's skip.
  Future<void> _nudge(VlcPlayerValue value) async {
    final generation = _generation;
    final at = _controller.pendingSeekTarget.value ?? value.position;
    if (value.isSeekable && at > Duration.zero) {
      await _controller.seekTo(at);
      // Account for that seek before the next tick reads the counter. The
      // watchdog forgives a freeze the viewer asked for, and this one is its
      // own - left unclaimed it would clear the line it just put up and
      // restart the window it is trying to run down.
      _seenSeekRequests = _controller.seekRequests;
      if (_disposed || generation != _generation) return;
    }
    await _controller.play();
  }

  /// Tells recovery when the device's network goes and comes back (spec 2:
  /// "Check at once when connectivity changes"), starting from [first], the
  /// screen's one question at start. Every change also keeps [_metered]
  /// current, the way `isOnMeteredNetwork` reads it.
  ///
  /// A stall already ten seconds old when the network comes back is
  /// recovery's at once: the connection it waits on died with the network.
  void _listenForConnectivity(Future<List<ConnectivityResult>> first) {
    unawaited(
      first.then((results) {
        if (!_disposed) _run(_policy.connectivity(online: _isOnline(results)));
      }, onError: (Object _) {}),
    );
    _connectivity = Connectivity().onConnectivityChanged.listen((results) {
      _metered = Future<bool>.value(
        results.contains(ConnectivityResult.mobile),
      );
      if (_disposed) return;
      final online = _isOnline(results);
      _run(_policy.connectivity(online: online));
      if (online &&
          _stage == _Stage.playing &&
          _policy.phase == RecoveryPhase.watching &&
          _stalledFor >= kStallNudgeAfter) {
        _onFailure(
          FailureSign.stalled,
          _l10n?.playerReasonNetworkDropped ?? 'the network dropped',
        );
      }
    });
  }

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  /// End-of-media is ambiguous: a finished film and a truncated download look
  /// identical to the engine. Only a position short of the duration
  /// distinguishes them.
  void _handleEnded() {
    if (_disposed) return;
    _flushProgress();

    final l10n = _l10n;
    // A live feed has no end. Reaching one means the stream dropped:
    // recovery reconnects it through its live budget, keeping the picture.
    if (_isLive) {
      _onFailure(
        FailureSign.falseEnd,
        l10n?.playerReasonLiveFeedDropped ?? 'live feed dropped repeatedly',
      );
      return;
    }

    if (!_sawFrames) {
      // This source ended without ever producing a frame, so there is nothing
      // that could have finished. It is a dead candidate, not a watched
      // episode - advancing on it would skip an episode nobody saw.
      _onFailure(
        FailureSign.falseEnd,
        l10n?.playerReasonStreamEndedBeforePlaying ??
            'stream ended before it played',
      );
      return;
    }
    // The engine's own numbers when there is no sample. A missing sample is
    // not evidence of an ending: it is refused below [kMinResumableDuration]
    // and never written for a source whose length libVLC never reported.
    final sample = _sample;
    final duration = sample?.duration ?? _lastSeenDuration;
    final position = sample?.position ?? _lastSeenPosition;
    // Two ways to be a failure wearing an ending's clothes: see [isFalseEnd].
    if (isFalseEnd(position: position, duration: duration)) {
      _onFailure(
        FailureSign.falseEnd,
        l10n?.playerReasonStreamEndedEarly ??
            'stream ended before its duration',
      );
      return;
    }
    // The only place the card can be raised from. Everything above is a
    // failure dressed as an ending and lands on the startup view with a
    // named reason instead.
    unawaited(
      _advance(automatic: true).then((outcome) {
        if (outcome == _Advance.playing) return;
        _showEnded(
          outcome == _Advance.declined
              ? EndedKind.declinedNext
              : EndedKind.finished,
        );
      }),
    );
  }

  /// Looks up intro/outro segments in the background.
  ///
  /// Never awaited by the open path: both sources are network lookups against
  /// crowdsourced databases, and playback must not wait on a convenience.
  Future<void> _loadSkipSegments(Episode? episode) async {
    if (episode == null) return;
    final token = _token;
    final segments = await fetchSkipSegments(
      read: _read,
      item: widget.item,
      episode: episode,
    );
    if (_disposed || token != _token || segments.isEmpty) return;
    setState(() => _skipSegments = segments);
  }

  /// Whether an episode follows this one. Recomputed rather than cached so it
  /// cannot go stale after an advance.
  bool get _hasNextEpisode =>
      nextEpisodeFor(
        item: widget.item,
        current: _currentEpisode,
        videoUrl: _videoUrl,
      ).next !=
      null;

  /// What the top bar's title says.
  ///
  /// The whole of what is playing: the film's name, or the series with the
  /// episode inside it. The bar gives the title one line and ellipsises it, so
  /// the order is what survives a squeeze - the series first, because that is
  /// what a viewer is checking they are in, then the numbering, then the
  /// episode's own name, which is the part a phone loses and can afford to.
  ///
  /// A picked torrent file still wins outright: it is the one case where the
  /// item's own title is not what is on screen.
  String _chromeTitle(AppLocalizations l10n) {
    final file = _torrentFileLabel;
    if (file != null) return file;
    final item = widget.item.title;
    final episode = _currentEpisode;
    if (episode == null || !_isEpisodic) return item;

    final parts = <String>[item];
    // Numbering only where the plugin actually populated it; a great many hand
    // back zeroes, and `S0 E0` is worse than nothing.
    if (episode.season > 0 && episode.episode > 0) {
      parts.add(
        l10n.playerSeasonEpisode(episode.season, episode.episode),
      );
    }
    final name = episode.name.trim();
    // Dropped when it is the numbering again under another name, which is what
    // a list with no real episode titles hands back.
    if (name.isNotEmpty && name != item && !parts.contains(name)) {
      parts.add(name);
    }
    return parts.join(' · ');
  }

  /// What the top bar's subtitle says: the source the picture is coming from.
  ///
  /// The one fact about a session that is otherwise only visible by opening
  /// the panel, and the one a viewer wants when a stream is misbehaving. Null
  /// where nothing is playing yet or the plugin named no provider, and the bar
  /// then renders no second line at all rather than an empty one.
  String? _chromeSubtitle() {
    final data = _panelData.value;
    final index = data.currentSourceIndex;
    if (index < 0 || index >= data.sources.length) return null;
    final stream = data.sources[index];
    return sourceProvider(stream) ?? sourceFactsOf(stream).title;
  }

  /// The episode before this one, recomputed for the same reason.
  Episode? get _previousEpisode => previousEpisodeFor(
    item: widget.item,
    current: _currentEpisode,
    videoUrl: _videoUrl,
  );

  /// Polls the torrent server while a torrent is playing.
  ///
  /// The status is only meaningful while the engine is seeding, so polling
  /// starts with playback rather than with the screen, and stops with it.
  void _startTorrentPolling() {
    _torrentPoll?.cancel();
    _torrentPoll = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_disposed || _pollingTorrent) return;
      _pollingTorrent = true;
      try {
        final status = await _read(torrentServiceProvider).getCurrentStatus();
        if (!_disposed && mounted) {
          setState(() {
            _torrentStatus = status;
            // Equal file lists compare equal, so a poll that found nothing
            // new never reaches the panel.
            _publishPanelData();
          });
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Torrent status poll failed: $e');
      } finally {
        _pollingTorrent = false;
      }
    });
  }

  /// Picture-in-picture is an Android activity mode and, on iOS, a
  /// sample-buffer window fed from the VLC texture; it is meaningless on a
  /// television either way.
  ///
  /// The gate reads [defaultTargetPlatform] rather than `Platform.isIOS` /
  /// `isAndroid` because only the former can be overridden by a test (see
  /// [PlayerPlatformService.enterPip]); in production the two agree.
  bool get _pipAvailable =>
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) &&
      _form != PlayerFormFactor.tv;

  /// Only a desktop window can change size; mobile and TV are already full
  /// screen, so the affordance is absent rather than inert.
  bool get _fullscreenAvailable =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  /// Asks the window to flip. The answer arrives as [onWindowEnterFullScreen]
  /// or [onWindowLeaveFullScreen], the same way it does when the viewer uses
  /// F11 or the green button instead of this button.
  void _toggleFullscreen() => unawaited(_platform.toggleFullscreen());

  /// Picks up a window that was already full screen before the player opened.
  Future<void> _seedFullscreen() async {
    final full = await _platform.isFullscreen();
    if (_windowSpoke) return;
    _setFullscreen(full);
  }

  @override
  void onWindowEnterFullScreen() {
    _windowSpoke = true;
    _setFullscreen(true);
  }

  @override
  void onWindowLeaveFullScreen() {
    _windowSpoke = true;
    _setFullscreen(false);
  }

  void _setFullscreen(bool value) {
    if (!mounted || _disposed || value == _isFullscreen) return;
    setState(() => _isFullscreen = value);
  }

  /// The stored resize mode, which is a display string rather than an enum.
  ///
  /// Duplicated from the controls, which map the same setting for the same
  /// reason. Not shared because the two are on opposite sides of the widget's
  /// public API and there is nowhere for it to live that neither owns.
  static VlcVideoFit _fitFromSettings(String mode) =>
      switch (mode.toLowerCase()) {
        'zoom' => VlcVideoFit.cover,
        'stretch' => VlcVideoFit.fill,
        _ => VlcVideoFit.contain,
      };

  /// The video picture's on-screen rect, for the PiP source view.
  ///
  /// The system needs the picture's real frame to open the window: a 1x1
  /// host is treated as not-displaying and `startPictureInPicture` silently
  /// does nothing — no window, no failure callback. The [VlcPlayer] widget
  /// fills the screen, but the picture itself is letterboxed inside it
  /// (fit: contain), so the rect is the picture's, not the widget's: sized
  /// to the picture, the host never draws over the app UI below or above
  /// it either.
  ///
  /// Returns null when the picture cannot be measured (not laid out yet, or
  /// no size reported); [_pipSourceRect] falls back to the screen.
  Rect? _videoContentRect() {
    if (_stage != _Stage.playing) return null;
    try {
      final context = _videoKey.currentContext;
      if (context == null) return null;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize || box.size.isEmpty) return null;
      final transform = box.getTransformTo(null);
      final widgetRect =
          MatrixUtils.transformRect(transform, Offset.zero & box.size);
      if (widgetRect.isEmpty) return null;
      final videoSize =
          _controller.value.displayVideoSize ?? _controller.value.videoSize;
      if (videoSize == null || videoSize.isEmpty) return widgetRect;
      return _contentRectFor(widgetRect, videoSize, _fit);
    } catch (_) {
      // A render object that is not attached yet, or any other measurement
      // failure: the caller falls back to the screen rather than stranding
      // the window on a bad rect.
      return null;
    }
  }

  /// The picture inside [widgetRect], for [fit] and [videoSize].
  ///
  /// Pure, so it is unit-testable: contain letterboxes the picture to the
  /// widget's shape, centred; every other fit fills the widget bounds.
  static Rect _contentRectFor(
    Rect widgetRect,
    Size videoSize,
    VlcVideoFit fit,
  ) {
    if (fit != VlcVideoFit.contain || videoSize.isEmpty) {
      return widgetRect;
    }
    final videoAspect = videoSize.width / videoSize.height;
    final widgetAspect = widgetRect.width / widgetRect.height;
    if (videoAspect <= 0 || widgetAspect <= 0) return widgetRect;
    if (videoAspect > widgetAspect) {
      // Wider than the view: full width, black bars above and below.
      final height = widgetRect.width / videoAspect;
      final dy = (widgetRect.height - height) / 2;
      return Rect.fromLTWH(
        widgetRect.left,
        widgetRect.top + dy,
        widgetRect.width,
        height,
      );
    }
    // Taller than the view: full height, black bars at the sides.
    final width = widgetRect.height * videoAspect;
    final dx = (widgetRect.width - width) / 2;
    return Rect.fromLTWH(
      widgetRect.left + dx,
      widgetRect.top,
      width,
      widgetRect.height,
    );
  }

  /// The rect to hand native as the PiP source: the picture's, or the whole
  /// screen when the picture cannot be measured. The screen is always a
  /// real, visible frame, so a measurement failure degrades to a full-screen
  /// source rather than the 1x1 that never opened.
  Rect _pipSourceRect() {
    final content = _videoContentRect();
    if (content != null &&
        !content.isEmpty &&
        content.width > 0 &&
        content.height > 0) {
      return content;
    }
    final size = MediaQuery.sizeOf(context);
    return Rect.fromLTWH(0, 0, size.width, size.height);
  }

  Future<void> _enterPip({bool fromButton = false}) async {
    // The picture's on-screen rect, read before the chrome comes off: the
    // native window needs a real source frame to open from (see
    // [_videoContentRect]), and the video widget is still laid out here.
    final sourceRect = _pipSourceRect();
    _pipAttemptFromButton = fromButton;
    _pipWindowOpened = false;
    // A button tap supersedes any start held as imminent (see
    // [didChangeAppLifecycleState]): the request below sets the hold
    // itself, so the flag must not stay up past it.
    _pipImminent = false;
    if (kDebugMode) {
      debugPrint(
        'VlcPlayerScreen: PiP requested (fromButton: $fromButton, sourceRect: $sourceRect)',
      );
    }
    // Set here as well as from onModeChanged, so the watchdog stands down and
    // the chrome comes off in the same frame the request is made rather than a
    // platform round trip later. A PiP surface the user has walked away from
    // should not be reopening sources on its own.
    setState(() => _inPip = true);
    // A locked PiP window is unrecoverable: the controls are not built in PiP
    // at all, so there is no chip in it to press and no gesture that would
    // reach one. Cleared on the way in rather than on the way out, because the
    // window is drawn from this frame.
    _clearLock();
    final bool entered;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // iOS has no activity to enter: the VLC plugin opens the PiP window
      // itself, fed from the texture. False — not an error — when the device
      // cannot do PiP, and then no `pictureInPicture` event ever arrives.
      // The window opening and closing is reported back through
      // [_onPictureInPicture]. The picture's on-screen rect goes with the
      // request, so the system has a real source frame to open from.
      entered = await _controller
          .startPictureInPicture(sourceRect: sourceRect)
          .catchError((Object _) => false);
    } else {
      entered = await _platform.enterPip(
        _controller.value.isPlaying,
        // Shapes the window to the film. Read at the moment of the request
        // rather than remembered, because a failover or a next-episode start
        // can have changed it since the last size event.
        videoSize: _controller.value.videoSize,
      );
    }
    // Android answers false - not an error - when the user has PiP disabled
    // for the app, and then never sends onPictureInPictureModeChanged. Without
    // this the optimism above is permanent and the chrome never comes back.
    if (_disposed || !mounted || !_inPip) return;
    if (!entered) {
      if (kDebugMode) {
        debugPrint('VlcPlayerScreen: PiP refused by the native side');
      }
      if (fromButton) {
        // The native side refused outright (no PiP support, no picture):
        // say so, instead of the button silently doing nothing.
        ref
            .read(notificationServiceProvider)
            .showInfo(
              'Picture-in-picture isn\'t available for this video right now.',
              title: 'Picture-in-picture',
            );
      }
      setState(() => _inPip = false);
      return;
    }
    // The request went out; the window opening, or failing to, is reported
    // through [_onPictureInPicture]. If neither arrives, the watchdog takes
    // the chrome back (see [_armPipWatchdog]).
    _armPipWatchdog();
  }

  /// Arms the PiP watchdog for the attempt that just went out.
  ///
  /// The native start only says the request went out; the window opening, or
  /// failing to, is reported through [_onPictureInPicture]. If neither
  /// arrives, the player is left with its controls unmounted and no touch
  /// handling at all - the screen looks frozen until the app is
  /// backgrounded and foregrounded again. Five seconds is the backstop
  /// behind the native side's own three: the native gate gives up at three
  /// seconds and reports the failure itself, so this only fires when no
  /// event arrived at all - and the two must never race to restore the
  /// chrome.
  void _armPipWatchdog() {
    _pipWatchdog?.cancel();
    final attempt = ++_pipAttempt;
    _pipWatchdog = Timer(const Duration(seconds: 5), () {
      if (_disposed || !mounted || attempt != _pipAttempt) return;
      // The window opened after all, or the event is already on its way.
      if (_controller.isPictureInPicture.value || !_inPip) return;
      // The window never opened: close the attempt and take the chrome
      // back. The controller's stop also settles the pending flag, so a
      // background pause the attempt held off lands if the app is away.
      // No event arrived at all — the native side's own three-second
      // timeout should have reported first — so say so, instead of the
      // button silently doing nothing.
      if (kDebugMode) {
        debugPrint(
          'VlcPlayerScreen: PiP watchdog fired — the window never opened '
          '(possible: ${_controller.lastPipPossible}, error: ${_controller.lastPipError})',
        );
      }
      final fromButton = _pipAttemptFromButton;
      _pipAttemptFromButton = false;
      if (fromButton) {
        ref
            .read(notificationServiceProvider)
            .showInfo(
              'Picture-in-picture didn\'t open for this video.',
              title: 'Picture-in-picture',
            );
      }
      unawaited(_controller.stopPictureInPicture());
      if (mounted && !_disposed) setState(() => _inPip = false);
    });
  }

  /// The iOS PiP window opened or closed, reported through the controller.
  ///
  /// The same guard as the Android callback: the window can open without
  /// [_enterPip] — the viewer swiped home — or close itself, from its own
  /// button or by tapping it to come back. Either way a locked PiP window
  /// has no chip in it, so the lock clears on the way in.
  void _onPictureInPicture() {
    final inPip = _controller.isPictureInPicture.value;
    // The attempt's answer, whatever it is: the watchdog stands down,
    // and a start held as imminent (see [didChangeAppLifecycleState]) is
    // resolved too — the hold is now the open window's own, or the
    // attempt is over.
    _pipWatchdog?.cancel();
    _pipWatchdog = null;
    _pipImminent = false;
    if (!mounted || _disposed || inPip == _inPip) return;
    if (inPip) {
      _pipWindowOpened = true;
      _pipAttemptFromButton = false;
      _clearLock();
    } else if (_pipAttemptFromButton && !_pipWindowOpened) {
      // The window never opened: the attempt failed after the native side
      // had accepted it. A closed window reports the same event, but then
      // [_pipWindowOpened] is true and nothing is said. The native side's
      // failure, in its words, rides the event (`lastPipError`) with whether
      // a start would be accepted right now (`lastPipPossible`) — the debug
      // line, shown here so a silent button has a reason the viewer can
      // report.
      final error = _controller.lastPipError;
      if (kDebugMode) {
        debugPrint(
          'VlcPlayerScreen: PiP failed to open after the native side accepted it '
          '(possible: ${_controller.lastPipPossible}, error: $error)',
        );
      }
      _pipAttemptFromButton = false;
      ref
          .read(notificationServiceProvider)
          .showInfo(
            error == null || error.isEmpty
                ? 'Picture-in-picture didn\'t open for this video.'
                : 'Picture-in-picture didn\'t open: $error',
            title: 'Picture-in-picture',
          );
    }
    setState(() => _inPip = inPip);
  }

  /// Opens the side panel, on whichever of its tabs the caller asked for.
  ///
  /// One entry point for every list the player can put on screen: holding the
  /// chrome open, giving Back exactly one thing to close and handing focus
  /// back to the control that opened it are the same every time.
  ///
  /// The future is why this is not a `void`: the chrome has to be held open
  /// for as long as the panel is up, or the bars go down underneath it and the
  /// button focus returns to is no longer there. Callers hold it through
  /// `ChromeVisibilityController.whileHeld`.
  Future<void> _openPanel(PlayerPanelTab tab, {bool onTrial = true}) async {
    // Every route the viewer has to a subtitle track is behind this call, so
    // this is where "the media chose it" stops being the only explanation and
    // the subtitle default stands down for this media. On open, not on close:
    // a rule still live while the panel is up would undo the pick in the same
    // frame the viewer made it. See [_applySubtitleDefault].
    _subtitlesOffPending = false;
    // The same goes for Auto's pick: whatever the viewer does from here is
    // theirs. Not for the audio language setting: audio is only ever chosen
    // from a row, so it stands down when the viewer picks one
    // ([_onAudioPicked]), and a panel opened for anything else leaves it be.
    _viewerChoseSubtitle = true;
    _autoPickPending = false;
    _subtitleToRestore = null;
    final isTv = _form == PlayerFormFactor.tv;
    await showPlayerPanel(
      context,
      controller: _controller,
      sideCars: _sideCars,
      initialTab: tab,
      isTv: isTv,
      // A remote and a keyboard both need focus inside the panel to use it at
      // all. A thumb does not, and a focus ring nobody asked for is just a
      // mark on the screen.
      focusOnOpen: isTv || _form == PlayerFormFactor.desktop,
      // Live, not a snapshot: every fact the panel shows is republished from
      // the place it changes - see [_publishPanelData].
      data: _panelData,
      onPickSource: (index) => _pickSource(index, onTrial: onTrial),
      onPickQuality: _pickQuality,
      onPickEpisode: (episode) => unawaited(_pickEpisode(episode)),
      // The panel has no ProviderScope of its own, so the one question its
      // Episodes tab cannot answer - which of these have been seen - is
      // answered from here, one row at a time as the list builds them.
      episodeProgress: _episodeProgressFor,
      onPickFile: (file) => unawaited(_applyTorrentFile(file)),
      onAudioPicked: _onAudioPicked,
      // The settings, live, and the notifier to change them through: the
      // panel's Subtitle style page has no ProviderScope of its own to ask.
      subtitleStyle: SubtitleStyleBinding(
        settings: _playerSettings,
        notifier: () => _read(playerSettingsProvider.notifier),
      ),
      // Held so Back has something to close - see [_dismissOverlay].
      onOpened: (panelContext) => _sheetContext = panelContext,
    );
    _sheetContext = null;
  }

  /// How much of [episode] the viewer has already seen, for the panel's
  /// Episodes tab.
  ///
  /// Asked per row as the list builds it, never precomputed into a map: every
  /// call costs a SHA-256 over the episode key plus up to four store reads.
  /// See `EpisodeProgressLookup`.
  ///
  /// `isWatched` is asked first and short-circuits, because it is the only
  /// authority that honours an explicit mark from the details screen.
  /// `item.url` is the series key both stores are written under
  /// (playback_progress.dart).
  EpisodeProgress _episodeProgressFor(Episode episode) {
    final mainUrl = widget.item.url;
    if (_read(episodeWatchRepositoryProvider).isWatched(mainUrl, episode)) {
      return const EpisodeProgress(watched: true);
    }
    final history = _read(historyRepositoryProvider);
    final duration = history.getEpisodeDuration(
      episode.url,
      mainUrl: mainUrl,
      season: episode.season,
      episode: episode.episode,
    );
    if (duration <= 0) return EpisodeProgress.none;
    final position = history.getEpisodePosition(
      episode.url,
      mainUrl: mainUrl,
      season: episode.season,
      episode: episode.episode,
    );
    return EpisodeProgress(fraction: (position / duration).clamp(0.0, 1.0));
  }

  /// What "the same media" means to the panel: the episode being played and
  /// the URL this session was launched from.
  ///
  /// Both move together on an advance and neither moves on a re-resolve, a
  /// failover or a hand-picked source, which is exactly the distinction the
  /// keep-previous rule in [_publishPanelData] has to make.
  Object get _panelMedia => (_currentEpisode, _videoUrl);

  /// Publishes what the panel shows, from the fields as they stand now.
  ///
  /// Called from every mutation point of its inputs rather than from build:
  /// several of them are bare field writes with no frame behind them
  /// (`_attemptIndex` during a failover), and the panel is a route of its own
  /// that this screen's build does not reach. [PanelData]'s equality drops a
  /// publish that changed nothing, so calling it liberally costs no rebuilds.
  void _publishPanelData() {
    if (_disposed) return;
    final resolved = _resolved;
    final previous = _panelData.value;
    // Never hand an open panel an empty list mid re-resolve: on a television
    // the focused row would unmount and nothing would hold focus. Until the
    // candidates or the resolution exist, the last list stands with no tick.
    //
    // Only for the same media. An advance is not a re-resolve: unscoped, a
    // panel open across an episode ending would go on listing the finished
    // episode's sources, and picking one would act on media no longer playing.
    final media = _panelMedia;
    final carryOver = media == _publishedSourcesMedia;
    final sources =
        resolved?.streams ??
        (carryOver
            ? (_candidates.isNotEmpty ? _candidates : previous.sources)
            : const <StreamResult>[]);
    _publishedSourcesMedia = media;
    _panelData.value = PanelData(
      sources: sources,
      // -1 whenever nothing is playing, which is a re-resolve or the failed
      // stage: the candidate that just died is still in [_attemptIndex], and
      // publishing it would badge a dead source 'Now playing'.
      currentSourceIndex: (resolved == null || _stage == _Stage.failed)
          ? -1
          : _attemptIndex,
      // A copy, so a later _probes.clear() cannot empty the chips under an
      // open panel.
      probes: Map<int, ProbeOutcome>.unmodifiable(_probes),
      failedSources: Set<int>.unmodifiable(_failedRows),
      playedSources: Set<int>.unmodifiable(_playedRows),
      qualityFilteredFallback: resolved?.qualityFilteredFallback ?? false,
      // None while nothing plays: a failed stage has no stream to choose a
      // quality of.
      qualityLadder: _stage == _Stage.failed ? const <int>[] : _qualityLadder,
      qualityPick: _qualityPick,
      // The list the next arrow walks, filtered the same way, so what the
      // panel offers and what Next does can never disagree.
      episodes: effectiveEpisodes(widget.item, _currentEpisode),
      currentEpisode: _currentEpisode,
      files: torrentFilesOf(_torrentStatus),
      currentFileIndex: _torrentFileIndex,
      // The show title always; season and episode only when the file playing
      // is known to be that episode. A hand-picked pack file may not be the
      // one the URL match named (see [_currentEpisode]), so they are dropped
      // then rather than scoping the search to the wrong episode.
      subtitleTarget: SubtitleSearchTarget.of(
        widget.item,
        _torrentFileIndex != null ? null : _currentEpisode,
      ),
    );
  }

  /// Moves off a source that plays but plays badly - failover only reacts to
  /// outright failure.
  ///
  /// [onTrial] is false when the picker was opened from the failed stage: there
  /// is no working session behind it to put back, so a pick that will not play
  /// should walk the failover ladder like any other candidate.
  void _pickSource(int index, {required bool onTrial}) {
    if (_disposed) return;
    // Before this resolve has opened anything there is nothing to switch away
    // from, so a pick is this resolve's choice: it ends the probe race if the
    // race is still running, and [_start] opens it either way. Recorded as
    // well as sent, because a pick landing as the race finishes would
    // otherwise be completed into a race nobody is listening to any more.
    if (_awaitingFirstOpen) {
      // Only against this resolve's own list. Until the plugin answers, a list
      // on screen - the panel keeps the last one up through a re-resolve - is
      // the previous resolve's, and its row numbers mean nothing in the next.
      if (index < 0 || index >= _candidates.length) return;
      setState(() => _pickedBeforeOpen = index);
      final pick = _pick;
      if (pick != null && !pick.isCompleted) pick.complete(index);
      return;
    }
    // Picking the row already playing is a no-op - but in the failed stage
    // nothing is playing, and picking the candidate the ladder died on is a
    // deliberate 'try that one again'.
    if (index == _attemptIndex && _stage != _Stage.failed) return;
    if (_resolved == null) return;
    // Carry the position across, exactly as failover does, including before
    // the first sample lands.
    final at = _reopenTarget();
    // The pick is on trial: recovery remembers what it interrupted, so its
    // failure puts that back rather than taking the session down with it. A
    // hand-picked source otherwise deserves the full ladder rather than the
    // leftovers of the walk that already failed.
    if (!onTrial) _policy.reset();
    unawaited(
      _openAttempt(
        index,
        startAt: at,
        reason: 'pick',
        revertTo: onTrial ? _attemptIndex : null,
      ),
    );
  }

  /// A quality picked in the Quality tab: a height, or null for Auto.
  ///
  /// Holds for the rest of this player session. Reopens this source where it
  /// is, as a step-down does, when it changes the cap the media plays under;
  /// a pick of what Auto already plays at changes only the tick.
  void _pickQuality(int? height) {
    if (_disposed || _resolved == null || _stage != _Stage.playing) return;
    if (height == _qualityPick) return;
    _qualityPick = height;
    _publishPanelData();
    final cap = renditionCapFor(
      deviceCap: _adaptiveMaxHeight,
      pick: height,
      preferenceHeight: _preferenceHeightAtOpen,
    );
    if (cap == _renditionCap) return;
    unawaited(
      _openAttempt(
        _attemptIndex,
        startAt: _reopenTarget(),
        reason: 'quality',
        keepPicture: true,
      ),
    );
  }

  /// A row selected on the startup view.
  ///
  /// Never on trial: the view is only up while nothing is playing, so there is
  /// no session behind the pick to put back if it will not open, and it walks
  /// the failover ladder from there like any other source.
  void _pickFromStartup(int index) {
    if (_disposed || (_pickCooldown?.isActive ?? false)) return;
    // A remote repeats OK while it is held. Without this one long press on a
    // row whose source fails fast reopens it again and again.
    _pickCooldown = Timer(const Duration(milliseconds: 700), () {});
    _pickSource(index, onTrial: false);
  }

  /// Switches playback to another file inside the season-pack torrent.
  ///
  /// The pick replaces the current candidate rather than being appended, so
  /// the failover list stays a list of sources. It restarts at zero: a
  /// different file is different media.
  Future<void> _applyTorrentFile(TorrentFile picked) async {
    final resolved = _resolved;
    if (resolved == null || _disposed) return;
    if (picked.index == _torrentFileIndex) return;

    final url = await _read(torrentServiceProvider)
        .getStreamUrlForFileIndex(picked.index);
    if (_disposed) return;
    if (url == null) {
      _notify(
        _l10n?.playerTorrentFileNotReady ??
            'That file is not ready to stream yet.',
      );
      return;
    }

    final current = resolved.streams[_attemptIndex];
    final streams = [...resolved.streams];
    streams[_attemptIndex] = StreamResult(
      url: url,
      source: 'Torrent (${picked.name})',
      providerName: current.providerName,
    );
    setState(() {
      _resolved = ResolvedPlayback(
        streams: streams,
        index: _attemptIndex,
        qualityFilteredFallback: resolved.qualityFilteredFallback,
      );
      _torrentFileLabel = picked.name;
      _torrentFileIndex = picked.index;
      _publishPanelData();
    });
    // A deliberate switch, not a failure: the walk that led here is over.
    _policy
      ..candidatesChanged([
        for (final stream in streams)
          RecoveryCandidate(
            authority: Uri.tryParse(stream.url)?.authority ?? '',
            checkable: !isUncheckableSource(stream),
          ),
      ])
      ..reset();
    // Different media, so a rotate press made over the last file is spent.
    _platform.followVideo();
    await _openAttempt(_attemptIndex, startAt: Duration.zero, reason: 'pick');
  }

  /// Moves to the next episode in place, on this controller and this State.
  ///
  /// In place rather than a fresh route because the screen already owns its
  /// controller for the State's lifetime; pushing would tear down and rebuild
  /// the native view. The cost is that every per-episode field has to be reset
  /// by hand, so the reset is a single block rather than scattered.
  ///
  /// [automatic] marks the end-of-media caller, and is the only one a refusal
  /// applies to: pressing Next in the chrome or on the ended card is the
  /// viewer changing their mind.
  Future<_Advance> _advance({bool automatic = false}) async {
    // [_Advance.playing] rather than a refusal: a disposed screen has no card
    // to show, and an advance already in flight owns the transition - the
    // outgoing engine delivers its `ended` late, and that call must not raise
    // a card over the episode already loading.
    if (_disposed || _advancing) return _Advance.playing;
    _advancing = true;
    try {
      final lookup = nextEpisodeFor(
        item: widget.item,
        current: _currentEpisode,
        videoUrl: _videoUrl,
      );

      // The outgoing episode's session ends first: finish() emits its single
      // terminal tracking event while the tracker still describes it.
      _tracker?.finish();

      final next = lookup.next;
      if (next == null) {
        // Only a located last episode means "finished". A current episode we
        // could not find in the list means "don't know", and deleting the
        // series on that would cascade across every per-episode row.
        if (lookup.isFinalEpisode) {
          clearFinishedFromHistory(read: _read, item: widget.item);
        }
        return _Advance.finished;
      }

      // Cancel on the up-next card has to survive end of media: nothing is
      // rolled forward here, and the card offers the episode back, so a binge
      // is still one press away.
      if (automatic && _nextEpisodeDeclined) return _Advance.declined;

      rollForwardHistory(read: _read, item: widget.item, next: next);
      await _startEpisode(next);
      return _Advance.playing;
    } finally {
      _advancing = false;
    }
  }

  /// Goes back one episode.
  ///
  /// The mirror of [_advance] with the two things that only make sense going
  /// forwards left out: there is no ended card to raise, because the list
  /// running out backwards simply means the button was not rendered, and
  /// nothing is cleared from history - `clearFinishedFromHistory` is the
  /// series finishing, which is not what stepping back is.
  ///
  /// It does take the same [_advancing] latch. The two directions move the
  /// same engine to a different episode, and letting one start while the
  /// other is in flight is how a viewer ends up two episodes from where they
  /// pressed.
  Future<void> _goToPreviousEpisode() async {
    if (_disposed || _advancing) return;
    final previous = _previousEpisode;
    if (previous == null) return;
    _advancing = true;
    try {
      // The outgoing episode's session ends first, exactly as an advance ends
      // it: finish() emits its terminal tracking event while the tracker still
      // describes the episode it belongs to.
      _tracker?.finish();
      // Despite the name this only points the history row at the episode about
      // to play and reads back its own saved position, so it is the right call
      // in either direction.
      rollForwardHistory(read: _read, item: widget.item, next: previous);
      await _startEpisode(previous);
    } finally {
      _advancing = false;
    }
  }

  /// Raises the ended card, once.
  void _showEnded(EndedKind kind) {
    if (_disposed || !mounted || _ended == kind) return;
    // The card unmounts the whole controls subtree - see the build gate - and
    // the unlock chip goes with it, so a lock left standing here would have
    // nothing on screen to undo it.
    _clearLock();
    setState(() => _ended = kind);
  }

  /// Plays the finished media again, from the top.
  ///
  /// Through [_start] rather than `controller.play()`: whether libVLC 3
  /// restarts from Ended is an open question, and this sidesteps it. It is
  /// also the only path that mints a fresh token, recorder and tracker - which
  /// this session needs, because `finish()` has already fired - and that
  /// re-resolves a URL which may have expired during the credits. Starting at
  /// zero comes for free: `resolveResumePoint` returns null at or past
  /// `kCompletedFraction`.
  void _startOver() {
    if (_disposed) return;
    _sample = null;
    _handedToEngine = false;
    // The refusal was made about the previous viewing of this episode. Left
    // set, the whole re-watch runs with the auto-advance silently off. The
    // offer goes with it: it belongs to the run that just ended.
    _nextEpisodeDeclined = false;
    _nextEpisodeOffer = null;
    setState(() => _ended = null);
    _setKeptPicture(false);
    // The finished picture comes down here, before the first await, for the
    // reason [_startEpisode] drops it in the same place: the resolve and the
    // resume lookup can take seconds, and they would otherwise be spent on a
    // frozen last frame.
    _setSawFrames(false);
    _setStatus('');
    unawaited(_start());
  }

  /// Plays [next] because the viewer asked for it from the panel, rather than
  /// because the last one ended.
  ///
  /// Everything the advance does apart from choosing the episode, so the two
  /// cannot drift: the same history roll-forward, the same per-episode reset,
  /// the same look on disk for a downloaded copy.
  Future<void> _pickEpisode(Episode next) async {
    if (_disposed || _advancing || next == _currentEpisode) return;
    _advancing = true;
    try {
      // The outgoing episode's session ends first, exactly as it does when one
      // runs out: finish() emits its single terminal event while the tracker
      // still describes it.
      _tracker?.finish();
      rollForwardHistory(read: _read, item: widget.item, next: next);
      await _startEpisode(next);
    } finally {
      _advancing = false;
    }
  }

  /// Swaps this session onto [next] on the controller it already owns.
  Future<void> _startEpisode(Episode next) async {
    // Per-episode reset. _token, _recorder, _tracker and _initialResume are
    // rebuilt by _start(); _generation and the attempt/edge flags by
    // _openAttempt(). These four are the ones nothing else clears.
    _sample = null;
    _lastStreamUrl = null;
    _resolved = null;
    // Now rather than in _start(): the download lookup below can take a
    // moment, and the startup view is up through it listing whatever
    // sources it is given - which must not be the finished episode's.
    _forgetSources();
    _awaitingFirstOpen = true;
    _pickedBeforeOpen = null;
    // The next episode's tracks are its own; carrying the last one's pick over
    // would answer a question this viewer has not been asked yet.
    _rememberedAudio = null;
    _rememberedSubtitle = null;
    _viewerAudio = null;
    _viewerAudioCopy = null;
    _viewerAudioOutranks = false;
    _audioToRestore = null;
    _preferredAudioToPick = null;
    _seenAudioTrackId = null;
    _seenSubtitleTrackId = null;
    _restorePending = false;
    // A file the viewer added belonged to the last episode as much as the
    // source's did.
    _sideCars.clear();
    _preloaded = null; // route sources belong to the first episode only
    _skipSegments = const <SkipSegment>[]; // previous episode's intro/outro
    // Both offers belong to the episode that just ended. The refusal
    // especially: "not this time" must not silence the next episode's card.
    _nextEpisodeOffer = null;
    _nextEpisodeDeclined = false;
    // A card left standing over an episode that is loading would offer Start
    // Over on media nobody is watching any more.
    _ended = null;
    _showResumeHint = false;
    // The picked torrent file, and the pack it came from, belonged to the
    // finished episode. Left standing, a direct-HTTP next episode still
    // offers a file picker built from the old pack - and picking from it
    // overwrites a perfectly good candidate with the old torrent's URL.
    // _startedTorrent deliberately survives: dispose still has to stop the
    // engine this session started.
    _torrentFileLabel = null;
    _torrentFileIndex = null;
    _torrentStatus = null;
    _torrentPoll?.cancel();
    _torrentPoll = null;
    _publishPanelData();
    // A rotate press held the last episode; this one turns the handset to its
    // own shape again once that has settled.
    _platform.followVideo();

    // The outgoing episode's last picture comes down here, before the first
    // await, and not in _openAttempt where every other attempt drops it.
    // Everything between here and setMedia - the download lookup, the plugin
    // resolve, the resume lookup - can take seconds over a frozen frame.
    _handedToEngine = false;
    _setKeptPicture(false);
    _setSawFrames(false);
    _setStatus('');

    _episode = next;
    _publishPanelData();
    // A downloaded episode plays from disk, exactly as the details screen
    // does when it launches the first one.
    var nextUrl = next.url;
    try {
      final local = await _read(downloadServiceProvider)
          .getDownloadedFile(widget.item, episode: next);
      if (local != null) nextUrl = local.path;
    } catch (_) {
      // The lookup is a convenience; fall back to streaming.
    }
    if (_disposed) return;
    _videoUrl = AppUtils.normalizeUrl(nextUrl);
    _publishPanelData();
    if (mounted) setState(() {}); // title/subtitle follow the new episode

    await _start();
  }

  /// The episode this session is playing: an explicitly passed episode wins,
  /// otherwise match the route's token against the series' own episode list.
  Episode? get _currentEpisode {
    if (_episode != null) return _episode;
    final type = widget.item.contentType;
    final isSeries =
        type == MultimediaContentType.series ||
        type == MultimediaContentType.anime;
    if (!isSeries) return null;
    return widget.item.episodes?.firstWhereOrNull((e) => e.url == _videoUrl);
  }

  /// Samples progress, and only while playback is genuinely running.
  ///
  /// Every other state lies: `stopped` and `ended` report position zero, and a
  /// value taken right after `setMedia` still carries the previous media's
  /// numbers because VlcPlayerValue merges into its predecessor.
  void _onPlaybackValue() {
    if (_disposed) return;
    final value = _controller.value;
    // A new video size moves the picture libVLC draws its lines into — a
    // new media, a rotation-aware size landing — so the subtitle anchor
    // follows it.
    final videoSize = value.displayVideoSize ?? value.videoSize;
    if (videoSize != _anchoredVideoSize) {
      _anchoredVideoSize = videoSize;
      _reanchorSubtitles();
    }
    _syncPlayingState(value);
    _syncOrientation(value);
    _qoeObserve(value);
    // Ahead of every early return below: a subtitle the media selected for
    // itself is just as on during a stall, an error or the end of the file,
    // and the window this closes has to close on the same tick whatever the
    // state says.
    _applySubtitleDefault(value);
    _rememberTracks(value);
    _maybeRestoreSubtitle(value);
    _maybePickPreferredSubtitle(value);
    final recorder = _recorder;
    if (recorder == null) return;

    // A pause or a stop nobody asked for is a failure (spec 2, Detection):
    // macOS paused at the end of a dropped connection's buffer before Part 3
    // (VLCKit's --play-and-pause), and Android stops after an error. Asked
    // for, it isn't: the viewer's, the background policy's and the app's own
    // all count in pauseRequests, and the natives say when an audio
    // interruption paused them.
    // libVLC follows an end or an error with a stop: its input is gone. That
    // stop belongs to the end or the error, not a failure of its own; read as
    // one, a film's real end reopened its last seconds over the ended card.
    if (value.state == VlcPlaybackState.ended ||
        value.state == VlcPlaybackState.error) {
      _ranSinceOpen = false;
    }
    if (value.state == VlcPlaybackState.playing ||
        value.state == VlcPlaybackState.buffering) {
      _ranSinceOpen = true;
      _pauseRequestsWhenRunning = _controller.pauseRequests;
    } else if (_ranSinceOpen &&
        !_stopReported &&
        _handedToEngine &&
        !_parked &&
        _pictureUp &&
        _policy.phase == RecoveryPhase.watching &&
        isUnaskedStop(
          state: value.state,
          pauseRequests: _controller.pauseRequests,
          pauseRequestsWhenRunning: _pauseRequestsWhenRunning,
          interruption: value.interruption,
          foreground: _foreground,
        )) {
      _stopReported = true;
      final sample = _sample;
      final duration = sample?.duration ?? _lastSeenDuration;
      final position = sample?.position ?? _lastSeenPosition;
      if (value.state == VlcPlaybackState.paused &&
          !_isLive &&
          !isFalseEnd(position: position, duration: duration)) {
        // Paused at the real end: the end, the way libVLC says it on every
        // other platform (the backstop to FORK.md 32).
        if (!_sawEnded) {
          _sawEnded = true;
          scheduleMicrotask(_handleEnded);
        }
      } else {
        final sign = value.state == VlcPlaybackState.paused
            ? FailureSign.pausedUnasked
            : FailureSign.stoppedUnasked;
        scheduleMicrotask(
          () => _onFailure(
            sign,
            _l10n?.playerReasonSourceStoppedResponding ??
                'the source stopped responding',
          ),
        );
      }
      return;
    }

    final starting =
        value.state == VlcPlaybackState.buffering ||
        value.state == VlcPlaybackState.playing;
    if (_parked && _handedToEngine && starting) {
      // The viewer's play started the parked media: a new attempt of the same
      // source, which recovery watches like any other (decision 15), with an
      // attempt's own edges, clocks and checks - a second error of the same
      // kind, or a stale picture count, was the first attempt's.
      _parked = false;
      _sawError = false;
      _sawEnded = false;
      _checkGeneration += 1;
      _startAttemptClock();
      _qoe.waitEnd();
      final resolved = _resolved;
      if (resolved != null && _attemptIndex < resolved.streams.length) {
        _qoeOpened(
          _attemptIndex,
          resolved.streams[_attemptIndex],
          _controller.currentMediaSource?.startPosition ?? Duration.zero,
          'play',
          keptPicture: _keptPicture,
        );
      }
      _policy.opened(source: _attemptIndex, live: _isLive);
      _armRecoveryTimer();
      _syncRecoveryLabel();
      _watchFirstFrame(_generation, torrent: _attemptIsTorrent);
    } else if (_awaitingPlay && starting) {
      _awaitingPlay = false;
      _watchFirstFrame(_generation, torrent: _attemptIsTorrent);
    }

    // Both of these are edges, not levels, and neither may run synchronously
    // inside the listener - failing over calls setMedia, which notifies again.
    if (value.state == VlcPlaybackState.error) {
      if (!_sawError) {
        _sawError = true;
        final reason =
            value.errorDescription ??
            _l10n?.playerReasonPlaybackError ??
            'playback error';
        scheduleMicrotask(() => _onFailure(FailureSign.engineError, reason));
      }
      return;
    }
    if (value.state == VlcPlaybackState.ended) {
      if (!_sawEnded) {
        _sawEnded = true;
        scheduleMicrotask(_handleEnded);
      }
      return;
    }

    // Advancing position is the only trustworthy sign of playback, so it - not
    // the state enum - decides whether this counts as progress. libVLC reports
    // `buffering` throughout healthy playback on some builds, and gating on the
    // enum meant progress, scrobbling and completion never fired at all.
    //
    // Zero is never progress: it is libVLC saying the media has played nothing
    // yet, which is all it reports while a source opens. A resume seeds the
    // last position with its saved place, and the drop from there to zero read
    // as the position moving - the loading screen went, over a black screen,
    // before anything had been drawn.
    final advanced =
        value.position != _lastSeenPosition && value.position > Duration.zero;
    _lastSeenPosition = value.position;
    final running =
        value.state != VlcPlaybackState.paused &&
        value.state != VlcPlaybackState.stopped &&
        (value.isPlaying || advanced);

    if (running) {
      // The outgoing media is still playing through the setup of the next
      // attempt. Its ticks keep the watchdog quiet, but are not sampled: the
      // recorder and the resume point may already describe the next episode.
      if (!_handedToEngine) {
        if (advanced) _resetStallClock();
        return;
      }
      // Kept even when the sample below is refused: this is the only length
      // end-of-media has to judge by on a source too short to be resumable,
      // and the only proof that a source which reports none never had one.
      _checkReportedLength(value);
      if (value.duration > Duration.zero) _lastSeenDuration = value.duration;
      final sample = ProgressSample(
        position: value.position,
        duration: value.duration,
        token: _token,
      );
      if (advanced) _onProgress();

      // record() refuses a livestream because there is no position to store,
      // but Continue Watching still needs the row: the card deletes its entry
      // on tap and relies on playback putting it back.
      //
      // Gated on the content type rather than _isLive, which is also true for
      // a film served over rtsp:// - that still wants ordinary progress.
      if (!_recordedLivestream &&
          widget.item.contentType == MultimediaContentType.livestream) {
        _recordedLivestream = true;
        recorder.recordLivestream();
      }

      if (!sample.isWritable) return;
      _sample = sample;
      // A seek on its way is where playback is going; the sample is where it
      // was, and every backend holds that until the seek lands.
      if (_controller.pendingSeekTarget.value == null) {
        _resumePosition = sample.position;
      }
      recorder.record(sample, lastStreamUrl: _lastStreamUrl);
      _tracker?.onPlaying(sample);
      _maybeOfferNextEpisode(sample);
      return;
    }

    // Pausing is the user's own save point, so flush past the rate limit.
    // `buffering` is a separate state, so this really is a user pause.
    if (value.state == VlcPlaybackState.paused) {
      _flushProgress();
      _tracker?.onPaused();
    }
  }

  /// The position moved, which is the only proof that any of this is working.
  ///
  /// Two different clocks hang off it. The stall window restarts immediately —
  /// that is what stops the watchdog firing during healthy playback. The
  /// recovery budgets wait for a real stretch of playback first, because a
  /// source that plays three seconds after every reopen would otherwise refill
  /// them forever and never let failover reach a source that works.
  void _onProgress() {
    final firstFrame = !_sawFrames;
    // A picture held through a reopen is the same picture: the bars stay as
    // they are, and the hold has ended.
    final wasKept = _keptPicture;
    if (firstFrame) _setKeptPicture(false);
    // Read before the clock resets it: this is the only record that the
    // watchdog said anything.
    final nudged = _lastStallAction != StallAction.none;
    // Recovery hears every move: healthy playback refills its budgets, and a
    // stall libVLC rode out by itself ends its wait.
    final wasRecovering = _policy.phase != RecoveryPhase.watching;
    _policy.moved();
    if (firstFrame) _policy.pictured();
    final recovered = wasRecovering && _policy.phase == RecoveryPhase.watching;
    if (recovered) {
      _qoe.waitEnd();
      _armRecoveryTimer();
    }
    final recovering = nudged || recovered;
    _setSawFrames(true);
    _resetStallClock();
    // A picture is up, so the video's tracks are as known as they will get:
    // the snapshot that brought it may be the last one for a while if
    // nothing else changes.
    if (firstFrame) _maybePickPreferredSubtitle(_controller.value);
    // Whatever the status line was announcing has happened - the first
    // picture, or the position moving again after "Reconnecting…". Clearing on
    // the first frame alone would leave the pill up through a recovery.
    if (firstFrame || recovering) _setStatus('');
    if (firstFrame) {
      _qoe.firstFrame(
        surfaceWaitMs: _controller.value.videoSurfaceWait?.inMilliseconds,
      );
      _firstFrame = null;
      // Recorded for the source lists: this row has proved it can be reached.
      _playedRows.add(_attemptIndex);
      _publishPanelData();
      _maybeReadQualityLadder();
      _maybeReadLiveSegment();
      _setFailReason(null);
      // A new picture, so the bars come up over it for a moment; on a
      // television that is also where focus lands.
      if (!wasKept) _chrome.poke();
      // The seek has already been applied as a start position, so this is a
      // notice rather than a prompt - and it belongs on the first real frame,
      // not on the stage change, which fires while the engine is still opening.
      if (_initialResume != null && !_resumeHintOffered) {
        _resumeHintOffered = true;
        if (mounted) setState(() => _showResumeHint = true);
      }
    }
  }

  /// Records the open of [stream] at [index], and whether it is a reopen of
  /// the same source or a move to another.
  void _qoeOpened(
    int index,
    StreamResult stream,
    Duration startAt,
    String reason, {
    bool keptPicture = false,
  }) {
    final previous = _qoeIndex;
    _qoeIndex = index;
    _qoeTracksKnown = false;
    _qoe.open(
      sourceIndex: index,
      kind: _qoeKind(stream),
      url: stream.url,
      startAtMs: startAt.inMilliseconds,
      reason: reason,
      keptPicture: keptPicture,
    );
    if (reason == 'first') return;
    if (previous != null && previous != index) {
      _qoe.failover(from: previous, to: index, reason: reason);
    } else {
      _qoe.reopen(
        reason: reason,
        positionMs: startAt.inMilliseconds,
        keptPicture: keptPicture,
      );
    }
  }

  /// What kind of media [stream] is, for the QoE record.
  String _qoeKind(StreamResult stream) {
    final url = stream.url;
    if (isTorrentSource(stream) || _torrentFileIndex != null) return 'torrent';
    if (url.startsWith('/') || url.startsWith('file:')) return 'local';
    if (isLiveSource(widget.item, url)) return 'live';
    final uri = Uri.tryParse(url);
    if (uri != null && looksLikeHls(uri)) return 'hls';
    if (uri != null && uri.path.toLowerCase().endsWith('.mpd')) return 'dash';
    return 'file';
  }

  /// Records stalls and track changes as they begin and end.
  void _qoeObserve(VlcPlayerValue value) {
    if (value.isStalled != _qoeStalled) {
      _qoeStalled = value.isStalled;
      if (_qoeStalled) {
        _qoe.stall(
          value.position.inMilliseconds,
          prebuffer: value.bufferingProgress,
        );
      } else {
        _qoe.stallEnd();
      }
    }
    final audio = value.activeAudioTrackId;
    final subtitle = value.activeSubtitleTrackId;
    if (_qoeTracksKnown) {
      if (audio != _qoeAudio) _qoe.track(kind: 'audio', id: audio ?? -1);
      if (subtitle != _qoeSubtitle) {
        _qoe.track(kind: 'subtitle', id: subtitle ?? -1);
      }
    }
    _qoeAudio = audio;
    _qoeSubtitle = subtitle;
    _qoeTracksKnown = _qoeTracksKnown || audio != null;
  }

  /// Records a seek when one is asked for, and when it has landed. A held
  /// reopen's start is published as the target too (FORK.md 33), and is no
  /// seek: only a target that came with a seek request counts.
  void _qoeSeekChanged() {
    final target = _controller.pendingSeekTarget.value;
    final requests = _controller.seekRequests;
    if (target != null && requests != _qoeSeekRequests) {
      _qoeSeekRequests = requests;
      _qoeSeekTarget = target;
      _qoe.seek(
        fromMs: _controller.value.position.inMilliseconds,
        toMs: target.inMilliseconds,
      );
    } else if (target == null && _qoeSeekTarget != null) {
      _qoeSeekTarget = null;
      _qoe.seekDone();
    }
  }

  /// Replaces the one line the viewer is given about what the player is doing.
  ///
  /// Cheap enough to call unconditionally: it is a no-op when the text has not
  /// changed, which is what stops per-tick callers rebuilding the screen.
  void _setStatus(String status) {
    if (_disposed || !mounted || status == _status) return;
    setState(() => _status = status);
  }

  /// The second line under the status, or none. Same no-op-on-equal rule as
  /// [_setStatus], for the same reason.
  void _setFailReason(String? reason) {
    if (_disposed || !mounted || reason == _failReason) return;
    setState(() => _failReason = reason);
  }

  /// Whether this attempt has a picture yet, set through the build.
  ///
  /// Written here rather than assigned in place because the startup view
  /// hangs off it: `setMedia` returns long before the engine has opened
  /// anything, so this is the flag that decides whether the viewer is looking
  /// at the video or at an opaque panel saying what is being tried.
  void _setSawFrames(bool value) {
    // The lock belongs to the picture that was on screen when it was set, and
    // every path that takes that picture away comes through here.
    //
    // Ahead of the early return on purpose: `_setSawFrames(false)` is called
    // twice on some paths and the second call would otherwise do nothing.
    if (!value && !_keptPicture) _clearLock();
    if (_sawFrames == value) return;
    _sawFrames = value;
    if (mounted && !_disposed) setState(() {});
  }

  /// Whether a same-source reopen shows the last picture, set through the
  /// build: the start-up view, the controls and the pill all follow
  /// [_pictureUp].
  void _setKeptPicture(bool value) {
    if (_keptPicture == value) return;
    _keptPicture = value;
    if (!value && !_sawFrames) _clearLock();
    if (mounted && !_disposed) setState(() {});
  }

  /// Fans the playing/not-playing edge out to the two things that follow it.
  ///
  /// Only on the flip: `MainActivity.isPlaying` is otherwise set once, at
  /// enterPip time, and the wakelock is a platform call with no business
  /// running on every position tick.
  ///
  /// The wakelock follows playback rather than the screen's lifetime, so a
  /// player parked on pause lets the display sleep.
  void _syncPlayingState(VlcPlayerValue value) {
    if (value.isPlaying == _wasPlaying) return;
    _wasPlaying = value.isPlaying;
    _platform.syncPipState(value.isPlaying, videoSize: value.videoSize);
    // Only a real stop releases the screen. The engine also reports
    // not-playing across every setMedia - failover, a torrent file switch, the
    // next episode - and a reopen can take minutes on a cold magnet; dropping
    // the wakelock there is exactly the case initState took it out for.
    unawaited(
      value.isPlaying
          ? WakelockPlus.enable()
          : (_sawFrames ? WakelockPlus.disable() : Future<void>.value()),
    );
  }

  /// Points the device the way the video is shaped.
  ///
  /// `displayVideoSize` rather than `videoSize`, which does not know which way
  /// up the picture is: a portrait clip is stored as landscape frames plus a
  /// 90 degree matrix, so pinning from `videoSize` would turn the device the
  /// wrong way. A backend that knows neither reports null and this pins
  /// nothing.
  ///
  /// [PlayerFormFactor.tv] and [PlayerFormFactor.desktop] are excluded:
  /// `setPreferredOrientations` has no handler in the macOS, Windows or Linux
  /// embedders, and a television is landscape by construction.
  ///
  /// No `unknown` guard: the service's own form-factor gate handles a profile
  /// that is still resolving, and also disarms a settle that a change of form
  /// factor has invalidated.
  ///
  /// Nothing once [_handBack] has run: the engine plays on while the route
  /// leaves, and its next tick would start the settle again and turn the page
  /// underneath sideways. Nor before this attempt's media is with the engine
  /// ([_handedToEngine]): until then every tick is the outgoing video's, and
  /// its shape is not the next one's to settle on.
  void _syncOrientation(VlcPlayerValue value) {
    if (_handedBack || !_handedToEngine) return;
    _platform.applyVideoOrientation(
      _form,
      renderedSize: value.displayVideoSize,
    );
  }

  /// The rotate button: turns the handset the other way for the rest of this
  /// video. [_startEpisode] and a torrent file switch hand the say back to the
  /// video, since each opens a different one; a failover is the same video
  /// from another source and keeps the viewer's choice.
  void _flipOrientation() {
    if (_handedBack) return;
    _platform.flipOrientation(_form);
    setState(() {});
  }

  /// Raises the up-next card in the closing seconds of an episode.
  ///
  /// Position-driven rather than end-of-media driven, so the viewer decides
  /// during the credits.
  void _maybeOfferNextEpisode(ProgressSample sample) {
    // _advancing matters: the transition awaits a download lookup and a full
    // resolve, and a late tick from the outgoing episode would re-arm the card
    // over the episode already loading.
    if (_nextEpisodeDeclined ||
        _nextEpisodeOffer != null ||
        _advancing ||
        _isLive) {
      return;
    }
    if (sample.duration - sample.position > _kNextEpisodeLeadIn) return;
    final next = nextEpisodeFor(
      item: widget.item,
      current: _currentEpisode,
      videoUrl: _videoUrl,
    ).next;
    if (next == null || !mounted) return;
    setState(() => _nextEpisodeOffer = next);
  }

  /// Raises the same card because the viewer pressed Skip Outro, rather than
  /// because the position reached the last fifteen seconds.
  ///
  /// The one deliberate asymmetry is the refusal: the automatic path
  /// early-returns on [_nextEpisodeDeclined], this one clears it. "Not this
  /// time, automatically" must not veto "yes, now, on purpose".
  void _offerNextEpisodeNow() {
    if (_disposed || !mounted) return;
    // The same two guards the automatic path opens with, for the same
    // reasons: an advance in flight already owns the transition and a card
    // raised into it would stand over the episode already loading, and a live
    // channel has no next episode to offer.
    if (_advancing || _isLive) return;
    final next = nextEpisodeFor(
      item: widget.item,
      current: _currentEpisode,
      videoUrl: _videoUrl,
    ).next;
    if (next == null) return;
    setState(() {
      _nextEpisodeDeclined = false;
      _nextEpisodeOffer = next;
    });
  }

  /// Writes the last known-good sample, bypassing the rate limit.
  void _flushProgress() {
    final sample = _sample;
    final recorder = _recorder;
    if (sample == null || recorder == null) return;
    recorder.record(sample, lastStreamUrl: _lastStreamUrl, force: true);
  }

  /// What the screen has to do about the app coming and going.
  ///
  /// Pausing and resuming playback is deliberately not here: that policy lives
  /// on [VlcPlayerController] (see `VlcPlayerConfig.backgroundPolicy`). What is
  /// left is the last chance to write progress, and the watchdog's clock.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed || !mounted) return;
    // Only a foreground player is worth watching for stalls; off screen the
    // position freezes for reasons that are nobody's fault. `inactive` is
    // deliberately still foreground - on desktop it only means the window lost
    // focus, and on Android it is what entering PiP looks like. Playback
    // carries on through both.
    _foreground =
        state != AppLifecycleState.paused &&
        state != AppLifecycleState.hidden &&
        state != AppLifecycleState.detached;
    // Recovery checks nothing off screen, and checks at once on the return
    // (spec 2, *Background*). Picture-in-picture is on screen: `inactive`.
    _run(_policy.foreground(visible: _foreground));
    if (state == AppLifecycleState.resumed) {
      // However long the app was away is not time this source spent stalled,
      // and the engine needs a moment to get its position moving again.
      _resetStallClock();
      // A backstop behind `pipModeChanged`: returning to the foreground is
      // what ending PiP looks like, and the chrome must come back with it
      // whether or not the activity got round to telling us. The native
      // attempt is stopped too, so a window that opened while the app was
      // away does not keep floating over the film it came from, and an
      // auto-start that never opened is cancelled rather than left to pop
      // up after the viewer is back.
      if (_inPip) {
        unawaited(_controller.stopPictureInPicture());
        setState(() => _inPip = false);
      } else if (_pipImminent) {
        // A start was held as imminent (see the `inactive` branch) but no
        // window opened — a transient foreground interruption (Control
        // Center, Notification Center, a call) that never left the app.
        // Release the hold so the background pause is not held off
        // forever, and cancel the native attempt if one is still pending.
        // The native stop is a no-op when nothing is open or pending.
        _pipImminent = false;
        unawaited(_controller.stopPictureInPicture());
      }
    }
    if (state == AppLifecycleState.inactive) {
      // iOS: do NOT start PiP here. `inactive` fires for a transient
      // overlay too — Control Center, Notification Center, a call — and
      // starting PiP for one of those re-frames the video (the PiP host
      // view comes to the front at the picture's rect, so the picture
      // pulls in) and clears the lock, both for a window that never
      // opens. Leaving the app for real (Home, the app switcher) is
      // handled natively instead: the eager controller's
      // `canStartPictureInPictureAutomaticallyFromInline` opens the
      // window when the app backgrounds, and the plugin starts it from
      // `didEnterBackground` as a backstop (see
      // VlcPictureInPicture.swift). A transient inactive never
      // backgrounds the app, so neither fires for Control Center and
      // the video and the lock are left alone.
      // What `inactive` does do on iOS is mark a start as imminent, so
      // the background pause (which fires when the app actually goes
      // away) holds off and the film keeps playing under the window
      // that is about to open. Only while it is actually playing, and
      // only where PiP exists; a paused film stays paused. The hold is
      // released on `resumed` above when no window opened (Control
      // Center), and by the `pictureInPicture` event when one did.
      // Android keeps its own path: there `inactive` IS the moment to
      // enter PiP (MainActivity.enterPictureInPictureMode is a
      // synchronous Activity call, not a slow gate), and the watchdog
      // test holds it shut.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        if (!_inPip &&
            !_pipImminent &&
            _pipAvailable &&
            _controller.value.isPlaying) {
          _pipImminent = true;
          _controller.notePictureInPictureImminent();
        }
      } else if (!_inPip && _pipAvailable && _controller.value.isPlaying) {
        unawaited(_enterPip());
      }
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // The process may not come back. This is the last guaranteed chance.
      _flushProgress();
    }
  }

  /// A brief notice over the video. The app's messenger rather than a bespoke
  /// overlay, so it looks and dismisses like every other toast.
  void _notify(String message) {
    if (_disposed || !mounted) return;
    // maybeOf: a player that cannot find a messenger should still play, not
    // throw on the way past a failed source.
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Back, from the remote, the gesture or the on-screen button alike.
  ///
  /// [fromChrome] marks the arrow in the top bar. The viewer can only press it
  /// while the bars are up, so answering by taking the bars away would be the
  /// one wrong reading of the press.
  ///
  /// The lock comes first, ahead of everything including [_dismissOverlay]:
  /// nothing the screen could have open is reachable from behind a lock, and a
  /// press that got past it to pop the route would make the lock decorative.
  void _handleBack({bool fromChrome = false}) {
    if (_locked.value && _lockedBack()) return;
    if (_dismissOverlay()) return;
    if (!fromChrome && _hideChromeForBack()) return;
    final navigator = Navigator.of(context);
    // The player is normally pushed over something. If it is not - a deep link
    // straight into playback - Back leaves the app, which is what it would
    // have done without the PopScope in the way.
    if (navigator.canPop()) {
      _handBack();
      navigator.pop();
    } else {
      unawaited(SystemNavigator.pop());
    }
  }

  /// What Back does on a locked screen: two presses to get out.
  ///
  /// Reports whether the press was spent here. The first press reveals the
  /// unlock chip and nothing else. A second press inside [_kLockBackEscape]
  /// takes the lock off and falls through to the ordinary pop, so a viewer who
  /// cannot find the chip is never trapped.
  ///
  /// [_backEcho] is consulted first: some devices deliver one press twice, and
  /// the second delivery must not be read as the deliberate second press.
  bool _lockedBack() {
    if (_backEcho?.isActive ?? false) return true;
    if (_lockEscape?.isActive ?? false) {
      // Second press, and it means it. The lock comes off here rather than in
      // dispose so that the fall-through is an ordinary Back on an ordinary
      // player, with no locked state left behind for a route that may yet
      // refuse to pop.
      _clearLock();
      return false;
    }
    _backEcho = Timer(_kBackEcho, () {});
    _lockEscape = Timer(_kLockBackEscape, () {});
    // poke(), never keepAlive() and never toggle(). keepAlive is a no-op while
    // the chrome is down, which is exactly when Back is pressed on a screen
    // that has been locked and left alone; toggle() would take the chip away
    // again on the press after.
    _chrome.poke();
    return true;
  }

  /// Takes the lock off from the screen's own paths - a failover, an episode
  /// advance, an ending, a terminal failure, picture-in-picture, and the
  /// two-press escape itself.
  ///
  /// Guarded because teardown can still reach it: [_setSawFrames] is called
  /// from unawaited open attempts that outlive the State, and the notifier is
  /// disposed in [dispose].
  ///
  /// Writes the flag and nothing else; everything that follows from the lock
  /// coming off lives in [_onUnlocked].
  void _clearLock() {
    if (_disposed) return;
    _locked.value = false;
  }

  /// The one owner of the lock's off transition, whichever writer made it:
  /// this screen through [_clearLock], or the controls' unlock chip.
  ///
  /// The Back timers go off with the lock. [_lockEscape] left armed would make
  /// the next Back on a freshly re-locked screen count as the second press of
  /// a sequence the viewer never started; [_backEcho] left armed would swallow
  /// a Back for 300 ms after an unlock.
  ///
  /// Hung off the notifier rather than written into [_clearLock] because the
  /// flag has two writers, and a reset on one call path is one the other can
  /// bypass. Only a real edge fires it, so repeated [_clearLock] calls over an
  /// already-unlocked screen cost nothing.
  void _onUnlocked() {
    if (_locked.value) return;
    _lockEscape?.cancel();
    _lockEscape = null;
    _backEcho?.cancel();
    _backEcho = null;
  }

  /// On a television Back with the bars up means "put the bars away", and only
  /// Back over bare video means "leave". Reports whether the press was spent
  /// on that. Paused or playing alike: [ChromeVisibilityController] hides on
  /// demand through `toggle()` even though its clock refuses to auto-hide over
  /// a still picture.
  ///
  /// A phone is left out: it has a tap to dismiss the bars with, and a swipe
  /// that only cleared the chrome would read as the gesture failing.
  ///
  /// A press arriving while [_backEcho] runs is swallowed whether or not the
  /// bars are up: it is the same press again.
  bool _hideChromeForBack() {
    if (_backEcho?.isActive ?? false) return true;
    // The ended card unmounts the whole controls subtree, so there are no bars
    // left to put away and the press belongs to the pop. `ended` is a
    // paused-looking state with the chrome flag wherever the last nudge left
    // it, so it has to be excluded explicitly.
    if (_ended != null) return false;
    if (_form != PlayerFormFactor.tv ||
        _stage != _Stage.playing ||
        !_pictureUp ||
        _inPip) {
      return false;
    }
    // A hold - a D-pad seek in flight - would keep the bars up through
    // toggle(), and a Back that visibly did nothing is worse than one that
    // leaves.
    if (!_chrome.value || _chrome.isHeld) return false;
    _backEcho = Timer(_kBackEcho, () {});
    // toggle() is the controller's only way down; guarded above so it cannot
    // be its way up.
    _chrome.toggle();
    return true;
  }

  /// Closes whatever the screen has over the video, and reports whether there
  /// was anything to close.
  ///
  /// The source sheet is a route of its own and usually pops itself, but on a
  /// television Back also arrives as a key event; without one guarded path a
  /// single press can dismiss the panel and leave the player in the same
  /// frame.
  bool _dismissOverlay() {
    final sheet = _sheetContext;
    if (sheet == null || !sheet.mounted) return false;
    // `mounted` is not enough: through the panel's exit transition its element
    // is still mounted while its route is no longer the current one, so a
    // second Back arriving mid-animation would pop the player out from under
    // the closing panel.
    if (!(ModalRoute.of(sheet)?.isCurrent ?? false)) return false;
    // maybePop rather than pop: the panel may be a step in - on the online
    // search - and Back from a step is a step back, which the panel's own
    // PopScope answers. From its tabs the pop goes through and closes it,
    // and [_openPanel] lets go of [_sheetContext] once it has.
    unawaited(Navigator.of(sheet).maybePop());
    return true;
  }

  void _fail(String message) {
    if (_disposed) return;
    _qoe.error(message);
    // Nothing is opening any more, so nothing has a first frame to be late for.
    _firstFrame = null;
    // Media still queued for a native player that has not come must not start
    // behind the failed frame when one does.
    if (!_controller.isAttached) unawaited(_controller.stop());
    // Same rule as [_showEnded] and [_setSawFrames]: the failed frame unmounts
    // the whole controls subtree, so the chip that undoes the lock goes with
    // it and Back would do nothing on the first press.
    _setKeptPicture(false);
    _clearLock();
    // Nothing plays here: the display may sleep. Retry and a pick take the
    // wakelock again as they open.
    unawaited(WakelockPlus.disable());
    setState(() {
      _stage = _Stage.failed;
      // Resolution itself can fail before anything opened. A pick from the
      // failed stage is a fresh open, not a choice for a resolve that is over.
      _awaitingFirstOpen = false;
      _error = message;
      // The failed frame says it in [_error]; carried past here it would
      // resurface under the next hand-picked source's line.
      _failReason = null;
    });
    // Nothing is playing any more, so the panel's tick has to go out - the
    // last publish was [_openAttempt]'s, naming the candidate that just died.
    _publishPanelData();
  }

  /// Plugins hand back both real URLs and bare filesystem paths; only the
  /// former survive [Uri.parse].
  Uri? _playableUri(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('/') ||
        (Platform.isWindows && value.contains(':\\'))) {
      return Uri.file(value);
    }
    final uri = Uri.tryParse(value);
    return (uri != null && uri.hasScheme) ? uri : null;
  }

  /// Returns a URL libVLC can open while still presenting [headers].
  ///
  /// libVLC 3.x can transmit only User-Agent and Referer; there is no option
  /// for Cookie, Authorization, Origin or anything custom. When a stream needs
  /// one, the URL goes to the local proxy instead, which re-injects the full
  /// set on the real request and across redirects.
  Future<Uri> _deliverableUri(Uri uri, Map<String, String> headers) async {
    if (!uri.scheme.startsWith('http')) return uri;
    if (unsupportedVlcHeaders(headers).isEmpty) return uri;
    return _proxied(uri, headers);
  }

  /// Routes an encrypted DASH manifest through the decrypting proxy.
  Future<Uri> _decryptingUri(
    Uri uri,
    Map<String, String> headers,
    ClearKey clearKey,
  ) async {
    await LocalProxyService.instance.startServer();
    return Uri.parse(
      LocalProxyService.instance.getDecryptingDashUrl(
        uri.toString(),
        key: clearKey.key,
        keyId: clearKey.keyId,
        headers: headers,
      ),
    );
  }

  Future<Uri> _proxied(Uri uri, Map<String, String> headers) async {
    if (!uri.scheme.startsWith('http')) return uri;
    // getProxyUrl starts the server without awaiting it, and the port is 0
    // until the bind completes - so a cold first call would build a URL
    // pointing at port 0. Start it explicitly first.
    await LocalProxyService.instance.startServer();
    return Uri.parse(
      LocalProxyService.instance.getProxyUrl(
        uri.toString(),
        headers: headers,
        // Without this the proxy strips Cookie outright
        // (local_proxy_service.dart:563), which would defeat the whole point
        // of routing through it. Keep exactly the cookies the source supplied.
        options: ProxyOptions(keepCookies: _cookieNames(headers)),
      ),
    );
  }

  List<String> _cookieNames(Map<String, String> headers) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() != 'cookie') continue;
      return entry.value
          .split(';')
          .map((pair) => pair.split('=').first.trim())
          .where((name) => name.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  /// Keeps libVLC's length for an HLS stream honest - see
  /// hls_video_length.dart for how it goes wrong.
  ///
  /// The measuring starts at the first length libVLC reports rather than at
  /// open: its own requests for the playlists are behind it by then, and a
  /// live stream, which reports none, is never measured at all. The check
  /// then repeats on every report, because libVLC loads a rendition's
  /// playlist when it is first wanted - turning subtitles on is enough - so
  /// the length can grow after the measurement.
  void _checkReportedLength(VlcPlayerValue value) {
    final media = _hlsMedia;
    if (media == null || value.duration <= Duration.zero) return;
    final measured = _videoLength;
    if (measured != null) {
      if (value.duration > measured + _kLengthSlack) _capLength(measured);
      return;
    }
    if (_videoLengthAsked) return;
    _videoLengthAsked = true;
    unawaited(_measureVideoLength(media.uri, media.headers, _generation));
  }

  Future<void> _measureVideoLength(
    Uri uri,
    Map<String, String> headers,
    int generation,
  ) async {
    final length = await measureHlsVideoLength(
      uri,
      (url) => url == uri
          ? _readOpenedPlaylist(url, headers)
          : _fetchPlaylist(url, headers),
    );
    if (_disposed || generation != _generation || length == null) return;
    _videoLength = length;
    if (_controller.value.duration > length + _kLengthSlack) {
      _capLength(length);
    }
  }

  /// Reads a live HLS stream's target duration once a picture shows, for its
  /// window's stretch (spec section 8): from the playlist this attempt
  /// opened, or the first one a master lists. Unread, the window assumes 10 s
  /// segments.
  void _maybeReadLiveSegment() {
    final media = _liveMedia;
    if (media == null) return;
    _liveMedia = null;
    final generation = _generation;
    unawaited(() async {
      var playlist = await _readOpenedPlaylist(media.uri, media.headers);
      if (playlist != null && targetDurationOf(playlist) == null) {
        // A master served through SkyStream's proxy names its variants
        // relative to the real address, which the proxy carries in its query.
        final real = media.uri.path == '/proxy'
            ? Uri.tryParse(media.uri.queryParameters['url'] ?? '')
            : null;
        final variant = firstVariantOf(playlist, base: real ?? media.uri);
        playlist = variant == null
            ? null
            : await _fetchPlaylist(variant, media.headers);
      }
      final segment = playlist == null ? null : targetDurationOf(playlist);
      if (segment == null || _disposed || generation != _generation) return;
      setState(() => _liveSegment = segment);
    }());
  }

  /// Seeks a live stream inside its window (spec section 8), and keeps what
  /// it was for [_onSeekSettled].
  void _seekInLiveWindow(double fraction, {bool toLive = false}) {
    final value = _controller.value;
    final window = LiveWindow.of(value, targetDuration: _liveSegment);
    if (window == null) return;
    _liveSeek = (
      target: value.position + window.length * (fraction - window.fraction),
      behind: window.length * (1 - fraction),
      segment: window.segment,
      toLive: toLive,
    );
    unawaited(_controller.seekToWindowFraction(fraction));
  }

  /// Back to the live edge: one segment from the end, as close as libVLC 3
  /// plays.
  void _goLive() {
    final window = LiveWindow.of(
      _controller.value,
      targetDuration: _liveSegment,
    );
    if (window == null) return;
    _seekInLiveWindow(window.endFraction, toLive: true);
  }

  /// A seek in a live window has settled: taken, or given up after the
  /// controller sent it once more. One libVLC didn't take reopens the stream
  /// with its live delay set to the target's distance from the edge, which
  /// makes libVLC start there; LIVE's reopens at the live start.
  void _onSeekSettled() {
    final seek = _liveSeek;
    if (seek == null || _controller.pendingSeekTarget.value != null) return;
    _liveSeek = null;
    final value = _controller.value;
    if (_disposed || _stage != _Stage.playing) return;
    // Settled because the media went away: that is the recovery's business.
    final state = value.state;
    if (state != VlcPlaybackState.playing &&
        state != VlcPlaybackState.buffering &&
        state != VlcPlaybackState.paused) {
      return;
    }
    if ((value.position - seek.target).abs() <= seek.segment * 1.5) return;
    _nextLiveDelayMs = seek.toLive ? null : seek.behind.inMilliseconds;
    unawaited(
      _openAttempt(
        _attemptIndex,
        startAt: Duration.zero,
        reason: 'live',
        keepPicture: true,
      ),
    );
  }

  /// Reads the Quality tab's ladder for the media this attempt opened, once
  /// per source: after its first picture, so libVLC has read the playlist
  /// first - an address that works once is the player's to spend.
  void _maybeReadQualityLadder() {
    final media = _qualityMedia;
    if (media == null || media.source == _qualityLadderOf) return;
    _qualityLadderOf = media.source;
    unawaited(_readQualityLadder(media.uri, media.headers, media.source));
  }

  Future<void> _readQualityLadder(
    Uri uri,
    Map<String, String> headers,
    String source,
  ) async {
    final playlist = await _readOpenedPlaylist(uri, headers);
    // Another source's open has taken the ladder down and asks for its own.
    if (_disposed || _qualityLadderOf != source) return;
    if (playlist == null) {
      // Asked again the next time this source shows a picture.
      _qualityLadderOf = null;
      return;
    }
    _qualityLadder = qualityLadderOf(hlsVariantsOf(playlist));
    _publishPanelData();
  }

  void _capLength(Duration length) {
    _controller.setDurationCap(length);
    // Taken before the cap, with libVLC's length in it - and on a video too
    // short to be sampled again, the last word [_handleEnded] would get: a
    // real ending read as a stream dying 27 hours short.
    final sample = _sample;
    if (sample != null && sample.duration > length) _sample = null;
  }

  /// The playlist this attempt opened, asked for at most once - see
  /// [_openedPlaylist].
  Future<String?> _readOpenedPlaylist(Uri uri, Map<String, String> headers) {
    final read = _openedPlaylist;
    if (read != null && read.uri == uri) return read.playlist;
    final playlist = _fetchPlaylist(uri, headers);
    _openedPlaylist = (uri: uri, playlist: playlist);
    return playlist;
  }

  /// One playlist, asked for with the headers libVLC was given for it.
  ///
  /// Read as it arrives, and only while it is one: an address marked adaptive
  /// can answer with a film, which read as text would be held in memory
  /// whole. Null for an answer that doesn't start `#EXTM3U`, or runs past
  /// [_kPlaylistMaxBytes].
  Future<String?> _fetchPlaylist(Uri url, Map<String, String> headers) async {
    final hangUp = CancelToken();
    final Stream<Uint8List>? body;
    try {
      final response = await _read(dioClientProvider).getUri<ResponseBody>(
        url,
        cancelToken: hangUp,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
          receiveTimeout: _kPlaylistTimeout,
          sendTimeout: _kPlaylistTimeout,
        ),
      );
      body = response.data?.stream;
    } catch (_) {
      return null;
    }
    if (body == null) return null;
    final read = Completer<String?>();
    final bytes = BytesBuilder(copy: false);
    var looked = false;
    late final StreamSubscription<Uint8List> reading;
    // Dio reads a streamed answer to its end after its reader has stopped,
    // so stopping is not enough: only a cancel hangs up the rest.
    void stop() {
      unawaited(reading.cancel());
      hangUp.cancel();
      if (!read.isCompleted) read.complete(null);
    }

    reading = body.listen(
      (chunk) {
        bytes.add(chunk);
        if (bytes.length > _kPlaylistMaxBytes) {
          stop();
        } else if (!looked && bytes.length >= _kPlaylistHeadBytes) {
          if (_startsAsPlaylist(bytes.toBytes())) {
            looked = true;
          } else {
            stop();
          }
        }
      },
      onError: (Object _) => stop(),
      onDone: () {
        if (read.isCompleted) return;
        final all = bytes.takeBytes();
        read.complete(
          looked || _startsAsPlaylist(all)
              ? utf8.decode(all, allowMalformed: true)
              : null,
        );
      },
      cancelOnError: true,
    );
    return read.future;
  }

  /// Whether [bytes] open the way an HLS playlist does, past any byte order
  /// mark and blank lines.
  static bool _startsAsPlaylist(List<int> bytes) => utf8
      .decode(bytes.take(_kPlaylistHeadBytes).toList(), allowMalformed: true)
      .replaceFirst('\uFEFF', '')
      .trimLeft()
      .startsWith('#EXTM3U');

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _platform.removeWindowListener(this);
    // Hands the top of the window back to the desktop title bar.
    setImmersiveRoute(active: false);
    // Order matters: dispose() stops the player, and a stopped libVLC reports
    // position zero. Write first, tear down second. finish() runs after the
    // local write and emits exactly one terminal tracking event.
    _flushProgress();
    _tracker?.finish();
    _disposed = true;
    _torrentPoll?.cancel();
    _waitAwake?.cancel();
    _pickCooldown?.cancel();
    _abandonPendingResolve();
    _backEcho?.cancel();
    _lockEscape?.cancel();
    _watchdog?.cancel();
    _recoveryTimer?.cancel();
    _subtitleReanchorTimer?.cancel();
    unawaited(_checkChanges?.cancel());
    _checkTick?.cancel();
    // After the controls, which unmount first and stop listening; its hide
    // clock is still armed and nothing else would stop it.
    _chrome.dispose();
    // Same order and the same reason: the controls listen to it through a
    // ValueListenableBuilder and have already gone by here.
    _locked.removeListener(_onUnlocked);
    _locked.dispose();
    // After _disposed is set, so no late publisher writes to a dead notifier;
    // an open panel's builder may still unsubscribe, which a disposed
    // notifier allows.
    _panelData.dispose();
    _playerSettings.dispose();
    _bufferedFraction.dispose();
    // The pinch zoom's notifier: the controls write it through the gesture
    // layer, and the Transform reads it through a ValueListenableBuilder.
    // Disposed after the controls are gone, like the other notifiers they
    // listen to.
    _videoScale.removeListener(_onVideoScaleChanged);
    _videoScale.dispose();
    _sideCars.removeListener(_onSideCars);
    _sideCars.dispose();
    unawaited(_connectivity?.cancel());
    // Unconditional and required: Android keeps delivering over this channel
    // while it tears the PiP window down, and a handler left registered closes
    // over a screen that no longer exists.
    _platform.detachPipListener();
    _handBack();
    _qoe.end(
      _stage == _Stage.failed
          ? 'failed'
          : _ended != null
          ? 'ended'
          : 'left',
    );
    _qoeMemory?.cancel();
    _pipWatchdog?.cancel();
    _pipWatchdog = null;
    _controller.pendingSeekTarget.removeListener(_qoeSeekChanged);
    _controller.pendingSeekTarget.removeListener(_onSeekSettled);
    _controller.pendingSeekTarget.removeListener(_followSeekTarget);
    _controller.isPictureInPicture.removeListener(_onPictureInPicture);
    _controller.removeListener(_onPlaybackValue);
    _controller.dispose();
    // The torrent server seeds in the background; nothing else stops it.
    if (_startedTorrent) unawaited(_read(torrentServiceProvider).stop());
    WakelockPlus.disable();
    super.dispose();
  }

  /// Gives the device back as the rest of the app wants it: the handset's
  /// rotation, the system bars, a desktop window out of full screen.
  ///
  /// From Back, before the pop, so all three start with the route's exit
  /// transition (300 to 500 ms) rather than after it; and from [dispose], for
  /// a route that went any other way. Once only.
  void _handBack() {
    if (_handedBack) return;
    _handedBack = true;
    // A window left full screen after the video closes traps the user in a
    // chrome-less shell. Not gated on _isFullscreen: that only tracks the
    // toggles we issued, and is wrong whenever the OS window control was used
    // instead - which is exactly when this matters.
    unawaited(_platform.exitFullscreen());
    // Hands orientation back to the system: outside the player the app
    // follows the device, the user's rotation lock included.
    _platform.restoreOrientation();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  /// The read-ahead for [stream], opening as [media] on a network that is
  /// [metered] or not, under the rule in [bufferPlanFor], recorded in the QoE
  /// log.
  Future<BufferPlan> _planBuffer(
    StreamResult stream,
    BufferMedia media, {
    required bool metered,
  }) async {
    final memory = await _memory;
    // The next open's reading, taken while this one plays.
    _memory = readDeviceMemory();
    final profile = _read(deviceProfileProvider).asData?.value;
    final settings =
        _read(playerSettingsProvider).asData?.value ?? const PlayerSettings();
    final item = widget.item;
    final plan = bufferPlanFor(
      media: media,
      memory: memory,
      fallbackRamMb:
          profile?.physicalRamMb ??
          tierRamMb(profile?.tier ?? DeviceTier.standard),
      metered: metered,
      fileBytes: probedSizeOf(stream.url) ?? sizeFromLabel(stream.source),
      runtime: runtimeFor(
        measured: _initialResume?.total,
        episodeMinutes: _currentEpisode?.runtime,
        itemMinutes: item.duration,
        tmdbMinutes: item is TmdbDetails ? item.runtime : null,
      ),
      label: stream.source,
      height: stream.quality,
      maxHeight: _renditionCap,
      overrideMb: settings.bufferOverrideMb,
    );
    _qoe.buffer({
      ...plan.toJson(),
      'totalMb': memory.totalMb,
      'freeMb': memory.freeMb,
      'metered': metered,
      'overrideMb': settings.bufferOverrideMb,
    });
    return plan;
  }

  /// What kind of media [mediaUri] is, for the buffer rule.
  BufferMedia _bufferMediaFor(Uri mediaUri) {
    if (_attemptIsTorrent) return BufferMedia.torrent;
    if (mediaUri.scheme == 'file' || mediaUri.scheme == 'content') {
      return BufferMedia.local;
    }
    if (_isLive) return BufferMedia.live;
    if (looksLikeHls(mediaUri) || looksLikeDash(mediaUri)) {
      return BufferMedia.adaptive;
    }
    return BufferMedia.httpFile;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // A pure derivation of a watched value, cached because the orientation and
    // teardown calls run from places that have no context. The profile
    // resolves asynchronously, so this is also how a session that started
    // before it landed picks it up.
    final profile = ref.watch(deviceProfileProvider).asData?.value;
    _form = playerFormFactorOf(profile);
    final canRotate = playerCanRotate(profile);
    final isTv = _form == PlayerFormFactor.tv;

    return PopScope(
      // One guarded path for Back: dismiss what the screen has open, and only
      // then leave playback. canPop is false because a pop cannot be taken
      // back once it has started, and on a remote Back is the only way out of
      // a panel.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: playerScaffoldColor,
        // One Stack in every stage. The VlcPlayer is its first child whenever
        // there is one: a separate PiP branch would change the widget in this
        // slot, detaching and killing the native player, so the episode
        // restarts every time the window shrinks. Hiding the chrome inside the
        // same Stack keeps the element and the engine.
        body: Stack(
          fit: StackFit.expand,
          children: [
            // The fit is the widget's, not just the engine's: on the texture
            // path VlcPlayer draws its own FittedBox from this, and the
            // native setFit behind it is a no-op on Windows and Linux.
            //
            // In the tree from the screen's first frame, so libVLC and its
            // output are created while the route animates and the links
            // resolve (spec 1.8): on the texture platforms VlcPlayer's own
            // initState attaches the native player. Offstage, which keeps the
            // element and drops only the paint, until the media is handed
            // over, and under the diagnostic switch.
            Offstage(
              offstage:
                  PlayerDiagnostics.suppressVideoSurface ||
                  _stage != _Stage.playing,
              // Pinch-to-zoom: the zoom itself is a Transform.scale over the
              // picture, driven by [_videoScale] — but the gesture no longer
              // lives here. A scale recognizer under the controls' screen-wide
              // drag recognizers lost the gesture arena to them, so two
              // fingers mostly scrubbed the video instead of zooming it. The
              // pinch is handled by the controls' gesture layer now, which
              // owns the one scale recognizer for both pan and pinch; this
              // widget only reads the value. The ValueListenableBuilder keeps
              // a pinch at 60 fps: only the Transform repaints, not the whole
              // screen.
              child: ValueListenableBuilder<double>(
                valueListenable: _videoScale,
                builder: (context, scale, child) => Transform.scale(
                  scale: scale,
                  alignment: Alignment.center,
                  child: child,
                ),
                child: KeyedSubtree(
                  key: _videoKey,
                  child: VlcPlayer(
                    key: ValueKey<int>(_playerMount),
                    controller: _controller,
                    fit: _fit,
                    darwinRenderer: playerDarwinRenderer,
                    androidRenderer: playerAndroidRenderer,
                    backgroundColor: playerBackdropColor,
                  ),
                ),
              ),
            ),
            // Subtitle files, drawn over the picture rather than into it, so
            // the fit never reaches them - and in PiP as well, as libVLC's
            // were. They sit at the picture's bottom edge, like the embedded
            // track's, and never move when the controls show or hide.
            if (_stage == _Stage.playing) _sideCarSubtitles(),
            // Everything before a picture: getting links, checking them,
            // opening one - `setMedia` hands libVLC a URL and returns, so the
            // playing stage begins with the video widget an empty surface -
            // and the dead end when none of them played. Keyed, so the view
            // is one element across all of it: the player is inserted
            // beneath it as opening begins, and unkeyed it would be rebuilt
            // there with its list back at the top.
            if (_stage != _Stage.playing || (!_inPip && !_pictureUp))
              _startupView(l10n, isTv: isTv),
            // At PiP size the frame is about a sixth of the screen: bars,
            // scrims and gesture layers are an unreadable smear over most of
            // it, and there is nothing there to tap them with anyway.
            //
            // `_ended == null` unmounts this subtree rather than fading it.
            // The controls' play button carries `autofocus: isTv`, so
            // leaving them mounted under the card would be two autofocus
            // nodes in one route, and their key sink would keep taking the
            // remote back.
            if (_stage == _Stage.playing &&
                !_inPip &&
                _pictureUp &&
                _ended == null) ...[
              // The overlay gets its own layer so a chrome repaint never
              // forces the embedder to recomposite the video surface beneath
              // it.
              RepaintBoundary(
                child: VlcPlayerControls(
                  controller: _controller,
                  bufferedFraction: _bufferedFraction,
                  chrome: _chrome,
                  // The texture platforms honour fit through VlcPlayer's
                  // FittedBox, not through the native setFit, so the button
                  // has to reach this state to do anything there.
                  fit: _fit,
                  // The pinch zoom's value: the controls' gesture layer
                  // writes it (see `VlcPlayerControls.videoScale`), and the
                  // Transform over the video reads it.
                  videoScale: _videoScale,
                  onFitChanged: (fit) {
                    if (!mounted) return;
                    setState(() => _fit = fit);
                    // The picture's place on screen changed with it, and
                    // libVLC's lines are drawn into the picture.
                    _reanchorSubtitles();
                  },
                  // Only where the OS turns the device when asked: a phone, or
                  // a tablet that has not stopped listening (see
                  // playerCanRotate).
                  onRotate: canRotate ? _flipOrientation : null,
                  rotationHeld: _platform.viewerChoseOrientation,
                  title: _chromeTitle(l10n),
                  subtitle: _chromeSubtitle(),
                  onBack: () => _handleBack(fromChrome: true),
                  // Each is null unless the thing it does is actually
                  // available, so the overlay never renders a button that
                  // would do nothing.
                  onNextEpisode: _hasNextEpisode
                      ? () => unawaited(_advance())
                      : null,
                  // Null on a film and on the first episode, so the bar has no
                  // previous button to render rather than a dead one.
                  onPreviousEpisode: _previousEpisode == null
                      ? null
                      : () => unawaited(_goToPreviousEpisode()),
                  // One panel, one callback: the controls render a button
                  // per tab in [panelTabs] and open the panel on it. The
                  // tabs come from the same helper the panel strip reads, so
                  // a button can never open a tab that does not exist.
                  onOpenPanel: (tab) => _openPanel(tab),
                  panelTabs: _panelData.value.tabs,
                  onEnterPip: _pipAvailable
                      ? () => _enterPip(fromButton: true)
                      : null,
                  onToggleFullscreen: _fullscreenAvailable
                      ? _toggleFullscreen
                      : null,
                  isFullscreen: _isFullscreen,
                  isLive: _isLive,
                  liveSegment: _liveSegment,
                  // The delay a live stream opens at, not a fallback
                  // reopen's own: that one is the distance it went back.
                  liveDelay: Duration(
                    milliseconds:
                        PlayerDiagnostics.liveDelayMs ?? kLiveDelayMs,
                  ),
                  onLiveSeek: _seekInLiveWindow,
                  onGoLive: _goLive,
                  skipSegments: _skipSegments,
                  // Null on a film and on the last episode, where the chip
                  // keeps its plain seek to the end of the credits because
                  // there is nothing to move on to.
                  onSkipOutro: _hasNextEpisode ? _offerNextEpisodeNow : null,
                  // The skip chip and the up-next card are both bottom-right
                  // and the card is a later child of this Stack, so without
                  // this the chip stays underneath it: a tap that lands on
                  // the card, and an invisible focus stop inside the card's
                  // rectangle on a remote. `_ended` is here so the rule
                  // survives the gate above changing.
                  promptVisible: _nextEpisodeOffer != null || _ended != null,
                  // Phone and tablet only, and null - not false - anywhere
                  // else: with nothing here the controls have no padlock to
                  // render and no locked branch to reach. A remote has no
                  // accidental surface and a mouse has no pocket.
                  locked: _form.isTouch ? _locked : null,
                  torrentStatus: _torrentStatus,
                ),
              ),
              // Both overlays position themselves against the chrome and sit
              // above it, so they stay readable while the bars are down.
              if (_showResumeHint && _initialResume != null)
                _unlessLocked(
                  ResumeHint(
                    position: _initialResume!.position,
                    isTv: isTv,
                    onStartOver: () {
                      _resumePosition = Duration.zero;
                      unawaited(_controller.seekTo(Duration.zero));
                    },
                    onDismissed: () {
                      if (mounted) setState(() => _showResumeHint = false);
                    },
                  ),
                ),
              if (_nextEpisodeOffer != null)
                _unlessLocked(_nextEpisodeCard(isTv: isTv)),
              // Anything the player has to say while a picture is actually
              // up. A failover no longer lands here - it clears the frame
              // flag and the startup view takes the screen instead.
              if (_status.isNotEmpty)
                Align(
                  alignment: Alignment.topCenter,
                  child: IgnorePointer(child: _statusPill(_status)),
                ),
            ],
            // A sibling of the controls, never a child: see the gate above.
            if (_ended case final kind?
                when _stage == _Stage.playing && !_inPip && _pictureUp)
              _endedCard(kind, isTv: isTv),
          ],
        ),
      ),
    );
  }

  Widget _sideCarSubtitles() {
    return Consumer(
      builder: (context, ref, _) {
        final settings =
            ref.watch(playerSettingsProvider).asData?.value ??
            const PlayerSettings();
        // The lines sit at one fixed place — the area's bottom margin,
        // see [subtitleTargetY] — so a pinch never moves them, and the
        // chrome is not in it: the lines never move when the controls
        // show or hide.
        return SideCarSubtitleView(
          controller: _controller,
          subtitles: _sideCars,
          settings: settings,
        );
      },
    );
  }

  /// Withholds a screen-level overlay while the screen lock is on.
  ///
  /// The resume hint and the up-next card are live tap targets over a picture
  /// the viewer believes is inert: a pocket press on Play loses the position,
  /// and one on Cancel ends the episode and takes the lock off with it.
  ///
  /// Withheld rather than wrapped in an [IgnorePointer]: a dead button that is
  /// still drawn reads as a broken player, and withholding also stops the
  /// countdown deciding an advance from behind a surface nobody can see.
  ///
  /// Off touch [_locked] is never set, so this is a rebuild that never fires.
  Widget _unlessLocked(Widget child) => ValueListenableBuilder<bool>(
    valueListenable: _locked,
    builder: (context, locked, child) =>
        locked ? const SizedBox.shrink() : child!,
    child: child,
  );

  /// What a film - or the last episode of a series, or an episode whose
  /// advance was declined - ends on.
  ///
  /// Everything the card renders is resolved here, so [EndedCard] itself never
  /// touches the item, the episode list or the engine.
  Widget _endedCard(EndedKind kind, {required bool isTv}) {
    final l10n = AppLocalizations.of(context)!;
    final episode = _currentEpisode;
    // Re-asked rather than remembered: the list is the only authority on what
    // follows, and between the refusal and the credits a season can have been
    // switched underneath this.
    final next = kind == EndedKind.declinedNext
        ? nextEpisodeFor(
            item: widget.item,
            current: episode,
            videoUrl: _videoUrl,
          ).next
        : null;
    // A declined kind with nothing to offer is not reachable through
    // [_advance], but the card asserts the pair, so degrade to Start Over
    // rather than assert if that stops being true.
    final effective = next == null ? EndedKind.finished : kind;

    return EndedCard(
      key: endedCardKey,
      kind: effective,
      isTv: isTv,
      // The series title is right for a finale and wrong for a declined
      // episode: "you've finished Breaking Bad" after episode two is a lie.
      title: effective == EndedKind.declinedNext
          ? _declinedTitle(l10n, episode)
          : widget.item.title,
      nextLabel: next == null ? null : _nextEpisodeLabel(l10n, next),
      onNextEpisode: next == null
          ? null
          : () {
              setState(() => _ended = null);
              // Not `automatic`: this is the viewer changing their mind, and
              // the refusal that stopped the auto-advance must not stop them.
              unawaited(_advance());
            },
      onStartOver: _startOver,
      onClose: _handleBack,
    );
  }

  /// What to call the episode a viewer declined to move on from.
  ///
  /// Never the series title while there is anything else to say: a plugin that
  /// scraped its season list without episode names would otherwise claim the
  /// whole series was finished on episode one. The numbers match the episode
  /// panel's own composition (player_episodes_tab.dart:126-133), so the two
  /// read the same and this spends no new key.
  String _declinedTitle(AppLocalizations l10n, Episode? episode) {
    final name = episode?.name.trim() ?? '';
    if (name.isNotEmpty) return name;
    final season = episode?.season ?? 0;
    final number = episode?.episode ?? 0;
    if (season > 0 && number > 0) {
      return l10n.playerSeasonEpisode(season, number);
    }
    if (number > 0) return l10n.playerEpisodeNumber(number);
    // Nothing on the entry identifies it at all - no name and no numbers - so
    // the series title is the only name there is to print.
    return widget.item.title;
  }

  /// `Next S2 E5`, or a plain `Next` when the numbers are unknown - the
  /// details screen's own composition (details_layout_widgets.dart:134-143),
  /// so the two read the same and no new ARB key is spent on it.
  String _nextEpisodeLabel(AppLocalizations l10n, Episode next) {
    if (next.season > 0 && next.episode > 0) {
      return l10n.playEpisode(l10n.next, next.season, next.episode);
    }
    if (next.episode > 0) return l10n.playEpisodeOnly(l10n.next, next.episode);
    return l10n.next;
  }

  /// The up-next card, with its countdown following actual playback.
  ///
  /// The `paused` input comes through a selector because the screen
  /// deliberately does not rebuild on every playback value.
  Widget _nextEpisodeCard({required bool isTv}) {
    final next = _nextEpisodeOffer!;
    final runtime = next.runtime;
    return PlayerValueSelector<bool>(
      controller: _controller,
      selector: (v) => v.isPlaying,
      builder: (context, playing) => NextEpisodeCountdown(
        title: next.name,
        posterUrl: next.posterUrl,
        season: next.season > 0 ? next.season : null,
        episode: next.episode > 0 ? next.episode : null,
        rating: next.rating,
        runtime: runtime == null ? null : Duration(minutes: runtime),
        description: next.description,
        paused: !playing,
        isTv: isTv,
        onPlayNext: () {
          setState(() => _nextEpisodeOffer = null);
          unawaited(_advance());
        },
        onCancel: () => setState(() {
          _nextEpisodeOffer = null;
          _nextEpisodeDeclined = true;
        }),
      ),
    );
  }

  /// Starts the whole resolve-and-open chain again from the failed stage.
  ///
  /// Deliberately from [_start] rather than from the last candidate: the
  /// failure may have been in resolution itself, and every recovery budget is
  /// spent by the time this screen is reachable.
  void _retry() {
    if (_disposed) return;
    _policy.reset();
    // Awake from here: resolving again can take seconds before the open.
    unawaited(WakelockPlus.enable());
    // A Stremio title's links came from its add-on, and by now every one of
    // them has failed - or expired, on a page left open: ask it again.
    if (widget.item.source == kAddonItemSource) _preloaded = null;
    setState(() {
      _stage = _Stage.resolving;
      _error = '';
      _status = '';
    });
    _publishPanelData();
    unawaited(_start());
  }

  Widget _statusPill(String text) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      ),
    ),
  );

  /// The one view up whenever there is no picture: getting links, checking
  /// them, opening one - and the dead end when none of them played.
  ///
  /// Everything it says is decided here, from state this screen already
  /// keeps; the view only lays it out.
  Widget _startupView(AppLocalizations l10n, {required bool isTv}) {
    final sources = _resolved?.streams ?? _candidates;
    final current = _startupCurrentIndex;
    final hasCurrent = current != null && current < sources.length;
    final failed = _stage == _Stage.failed;
    return PlayerStartupView(
      key: openingOverlayKey,
      title: widget.item.title,
      episodeLine: _episodeLine(l10n),
      logoUrl: widget.item.logoUrl,
      backdropUrl: widget.item.backdropImageUrl,
      sourceName:
          _torrentFileLabel ??
          (hasCurrent ? sourceRowLabel(sources[current]) : null),
      status: _startupStatus(l10n, sources: sources),
      detail: _torrentDetail(l10n),
      reason: failed ? null : _failReason,
      attempt: hasCurrent ? (index: current + 1, total: sources.length) : null,
      rows: <StartupRow>[
        for (var i = 0; i < sources.length; i++)
          StartupRow(
            label: sourceRowLabel(sources[i]),
            reachability: sourceReachabilityOf(
              sources[i],
              _probes[i],
              hasPlayed: _playedRows.contains(i),
            ),
            playState: sourcePlayStateOf(
              isCurrent: i == current,
              hasPicture: _pictureUp,
              failed: _failedRows.contains(i),
            ),
          ),
      ],
      currentIndex: current,
      failed: failed,
      onPick: _pickFromStartup,
      onBack: _handleBack,
      onRetry: _retry,
      // Desktop only, like the gesture over the video it mirrors: a phone or
      // a television has no window to full-screen.
      onDoubleClick: _fullscreenAvailable ? _toggleFullscreen : null,
      isTv: isTv,
    );
  }

  /// The line under "Preparing torrent…" (spec 5): peers connected out of
  /// those known, the speed and what is loaded, from the 3 s status poll. All
  /// three always, so the line doesn't jump about while metadata comes.
  String? _torrentDetail(AppLocalizations l10n) {
    final status = _torrentStatus;
    if (!_attemptIsTorrent ||
        _pictureUp ||
        _stage == _Stage.failed ||
        status == null) {
      return null;
    }
    return l10n.playerTorrentPeers(
      status.peers,
      status.totalPeers,
      '${formatFileSize(status.downloadSpeed, fractionDigits: 1)}/s',
      formatFileSize(status.loadedBytes, fractionDigits: 0),
    );
  }

  /// The row the startup view marks as being opened, or null when none is.
  ///
  /// Not [_attemptIndex] until this resolve has opened something: that still
  /// names the last resolve's source, or nothing at all. Until then it is the
  /// row the viewer picked, if they have.
  int? get _startupCurrentIndex {
    if (_stage == _Stage.failed) return null;
    if (_awaitingFirstOpen) return _pickedBeforeOpen;
    return _attemptIndex;
  }

  /// The startup view's status line: only what its rows cannot say.
  ///
  /// With a list up, its rows already read "Checking…" and "Opening…", and a
  /// line repeating them was noise. What is left is the wait before there is
  /// a list, whatever is unusual about an open - a torrent still being
  /// prepared, a live feed reconnecting - and why nothing played.
  String? _startupStatus(
    AppLocalizations l10n, {
    required List<StreamResult> sources,
  }) {
    if (_stage == _Stage.failed) return _error;
    if (sources.isEmpty) {
      final checking = _checkWait(l10n);
      if (checking != null) return checking;
      final plugin = _pluginName;
      return plugin == null ? l10n.loading : l10n.playerGettingLinks(plugin);
    }
    return _status.isEmpty ? null : _status;
  }

  /// The bot check the plugin's links wait on, while it's tried: one line,
  /// counted in seconds by [_checkTick].
  String? _checkWait(AppLocalizations l10n) {
    final clearance = Clearance.instance;
    final asked = _linksAskedAt;
    if (!clearance.isReady || asked == null) return null;
    final source = pluginFor(_read, widget.item, _videoUrl)?.checkSource;
    return checkLineText(
      clearance.checks,
      source,
      asked.subtract(const Duration(seconds: 5)),
      l10n,
    );
  }

  /// Runs [_checkTick] while the check the links wait on is tried.
  void _keepCheckTick() {
    final clearance = Clearance.instance;
    final asked = _linksAskedAt;
    final check =
        !clearance.isReady || asked == null || _stage != _Stage.resolving
        ? null
        : clearance.checks.latestFor(
            pluginFor(_read, widget.item, _videoUrl)?.checkSource,
            since: asked.subtract(const Duration(seconds: 5)),
          );
    if (check?.pending ?? false) {
      _checkTick ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _disposed) return;
        // The startup view is gone: so is its clock.
        if (_stage != _Stage.resolving) return _keepCheckTick();
        setState(() {});
      });
    } else {
      _checkTick?.cancel();
      _checkTick = null;
    }
  }

  /// `S1 E3 · Name` for an episode of a series, or null for anything else.
  String? _episodeLine(AppLocalizations l10n) {
    if (!_isEpisodic) return null;
    final episode = _currentEpisode;
    if (episode == null) return null;
    final number = l10n.playerSeasonEpisode(episode.season, episode.episode);
    final name = episode.name.trim();
    return name.isEmpty ? number : '$number · $name';
  }

  /// Whether what is playing is an episode of a series, rather than a film, a
  /// live channel or anything else that plays as one video.
  ///
  /// The content type decides, not the presence of an episode: plugins file a
  /// film as a one-episode show, which printed "S1 E1 · Full Movie" over it -
  /// in the startup view and in the top bar alike, so both ask this.
  bool get _isEpisodic {
    final type = widget.item.contentType;
    return type == MultimediaContentType.series ||
        type == MultimediaContentType.anime;
  }
}
