import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart' show Options, ResponseType;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart'
    show ProviderListenable;
import 'package:vlc_player/vlc_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/network/dio_client_provider.dart';
import '../../../../core/network/http_defaults.dart';
import '../../../../core/providers/device_info_provider.dart';
import '../../../settings/presentation/player_settings_provider.dart';
import '../../../../core/extensions/providers.dart';
import '../../../../core/models/torrent_status.dart';
import '../../../../core/services/download_service.dart';
import '../../../../core/services/local_proxy_service.dart';
import '../../../../core/storage/episode_watch_repository.dart';
import '../../../../core/storage/history_repository.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/episode_navigator.dart';
import '../../../skip/data/skip_service.dart';
import '../../domain/clear_key.dart';
import '../../domain/hls_video_length.dart';
import '../../domain/playback_progress.dart';
import '../../domain/buffered_ahead.dart';
import '../../../../core/logger/app_logger.dart';
import '../../domain/network_buffer.dart';
import '../../domain/smoothness.dart';
import '../../domain/track_memory.dart';
import '../../domain/playback_recovery.dart';
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
import '../widgets/hotstar_player_style.dart';
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

/// libVLC's output latency, in milliseconds (`--network-caching`), and the one
/// number that decides how long a newly selected audio or subtitle track stays
/// silent: a stream started mid-playback has to fill this buffer before it
/// emits, while the picture, already full, carries on. Live uses the same
/// value, so the two cannot drift apart.
const int kNetworkCachingMs = 3000;

/// How many times one source is re-opened before moving to the next. Only
/// applies to a source that actually produced frames — one that never played is
/// simply dead and gets no retries.
const int _kSameSourceRetries = 2;

/// How many times a live feed is reopened before giving up on that source.
/// Reset as soon as playback actually resumes, so an all-evening channel that
/// drops once an hour never exhausts it.
const int _kMaxLiveReconnects = 5;

/// Breathing room before reopening a dropped live feed. Without it a dead URL
/// ends instantly and the reopen becomes a hot loop.
const Duration _kLiveReconnectDelay = Duration(seconds: 2);

/// How long an attempt must run before its recovery budgets are handed back.
///
/// Not the first frame: a source that plays three seconds after every reopen
/// would otherwise refill its own retry budget forever and never fail over.
const Duration _kHealthyPlayback = Duration(seconds: 30);

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
  /// [_failAttempt] and the [_openAttempt] it calls run in one synchronous
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
  int _attemptRetries = 0;

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

  /// Candidates opened during the current failover walk, so the walk can wrap
  /// past the end of the list without becoming a loop. Cleared once a source
  /// has played for [_kHealthyPlayback] — see [_onProgress].
  final Set<int> _tried = <int>{};

  /// Set while a hand-picked source is on trial, holding the session it
  /// interrupted. A pick that will not open must cost the viewer nothing, so
  /// its failure restores this instead of walking the failover ladder.
  ({int index, Duration position})? _revertTo;

  /// Whether the current attempt is a torrent, which is allowed far longer to
  /// produce its first frame — it is waiting on pieces, not on a socket.
  bool _attemptIsTorrent = false;

  /// How long the current attempt has been running, and how long since the
  /// position last moved. Together they are the watchdog's whole input.
  ///
  /// Counted by the watchdog's own tick rather than off the wall clock: a
  /// clock correction mid-play - NTP, a television leaving standby - would
  /// otherwise read as a stall and fail a healthy source over.
  Duration _attemptAge = Duration.zero;
  Duration _stalledFor = Duration.zero;

  /// The highest watchdog rung already fired for the current stall, so each
  /// fires once. Cleared the moment the position moves.
  StallAction _lastStallAction = StallAction.none;
  Timer? _watchdog;

  /// The current attempt's [kFirstFrameDeadline], armed as it starts opening
  /// and gone with its first picture. See [_armFirstFrameDeadline].
  Timer? _firstFrameDeadline;

  /// The tallest adaptive rendition this session may be handed.
  ///
  /// Seeded in [initState] — see [adaptiveMaxHeightFor] — and lowered a rung
  /// at a time when the decoder proves it cannot keep up. The seeded value
  /// goes on the instance config; a lowered one is carried per-media, because
  /// the instance's options are fixed at construction.
  late int _adaptiveMaxHeight;

  /// The seeded cap, kept so a step-down can be recognised as one. Media
  /// options stay untouched while the two agree.
  late final int _deviceAdaptiveMaxHeight;

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

  /// Consecutive live reopen attempts that have not yet produced playback.
  int _liveReconnects = 0;

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

  /// The source sheet's own context while it is open, so Back has something to
  /// close. Null whenever the video is the only thing on screen.
  BuildContext? _sheetContext;

  /// Whether this session ever started the torrent engine, so teardown only
  /// stops something it actually started.
  bool _startedTorrent = false;

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

  ProviderContainer? _container;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container = ProviderScope.containerOf(context, listen: false);
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

    // The same buffer to the other engine. Here rather than at torrent setup
    // because this is the one place that has the settings and the device tier
    // in hand, and the server may be started later by a source resolver that
    // has neither.
    _applyTorrentBuffer();
    _controller = VlcPlayerController(
      autoPlay: true,
      // Native events are not throttled by default and position ticks are not
      // deduped, so every tick would rebuild the overlay and run the progress
      // listener. Four updates a second is plenty for a seek bar.
      eventThrottleInterval: const Duration(milliseconds: 250),
      config: VlcPlayerConfig(
        network: VlcNetworkConfig(
          // --network-caching is output latency, not read-ahead: every
          // elementary stream has to accumulate this much before it emits
          // anything. That cost is invisible at startup, where all the streams
          // fill together, and very visible afterwards - selecting a different
          // audio or subtitle track starts a stream from empty, so the picture
          // carries on while the new track stays silent for exactly one
          // caching interval. Measured at 60s when this carried a buffer
          // depth in minutes; a seek masked it, because a seek refills every
          // stream at once.
          //
          // So it is pinned to the same interval a live source uses. libVLC 3
          // has no read-ahead-in-seconds control for this to stand in for, and
          // a large value here buys nothing but the silence above.
          networkCaching: kNetworkCachingMs,
          // Read-ahead, which is the knob the caching one was mistaken for:
          // it buys resilience and cheap seeks without delaying a stream that
          // starts mid-playback. KiB is libVLC's unit.
          prefetchBufferKiB: _bufferMb * 1024,
          userAgent: kDefaultBrowserUserAgent,
          // libVLC does adapt, but its estimator starts pessimistic and can
          // sit on a low rendition for a long stretch, so pin the highest.
          // Highest with no ceiling hands a weak device the 4K rung of every
          // HLS stream, so the ceiling below is the other half of the choice.
          adaptiveLogic: VlcAdaptiveLogic.highest,
          adaptiveMaxHeight: _adaptiveMaxHeight,
        ),
        subtitleStyle: subtitleStyleFrom(settings),
        // Off by default; see [PlayerDiagnostics].
        verbose: PlayerDiagnostics.verboseVlcLog,
        // The user's hardware-decoding preference, which reaches a decoder on
        // Android only: every other platform renders through libVLC's vmem
        // callbacks, and libvlc_video_set_callbacks sets `avcodec-hw = "none"`
        // on the media player itself (VLC 3.0.21 lib/media_player.c:1113),
        // below the instance in the variable-inheritance chain.
        //
        // Windows and Linux have no hardware decoder outside avcodec, so they
        // are software-decode-only either way. Darwin decodes on VideoToolbox,
        // which `avcodec-hw` has no authority over, so it keeps its hardware
        // path either way. See VlcDecodingConfig.hardwareAcceleration.
        decoding: VlcDecodingConfig(
          hardwareAcceleration: settings.hardwareDecoding
              ? VlcHardwareAcceleration.automatic
              : VlcHardwareAcceleration.disabled,
        ),
      ),
      // Present in both shipped libVLC builds (VLCKit 3.7.3 and libvlc-all
      // 3.7.0); see FORK.md section 8 on checking option names against the
      // binary.
      options: const <String>['--http-reconnect'],
    );

    _controller.addListener(_onPlaybackValue);
    _sideCars.addListener(_onSideCars);
    _chrome = ChromeVisibilityController(
      isPlaying: () => _controller.value.isPlaying,
    );
    _watchdog = Timer.periodic(_kWatchdogTick, (_) => _checkStall());
    _listenForNetworkRestore();
    _attachPip();
    unawaited(_start());
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
    var target = value.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (value.duration > Duration.zero && target > value.duration) {
      target = value.duration;
    }
    unawaited(_controller.seekTo(target));
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
      _pluginName = _preloaded == null
          ? pluginFor(_read, widget.item, _videoUrl)?.name
          : null;
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
      // and the reconnect budget to the media about to be opened; carrying
      // either forward offers a stale position or refuses to reconnect a feed
      // that has not dropped.
      _resumeHintOffered = false;
      _showResumeHint = false;
      _liveReconnects = 0;
      _revertTo = null;
      _tried.clear();

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
      _publishPanelData();
    });
  }

  /// Opens one candidate.
  ///
  /// The generation counter is bumped first and re-checked after every await.
  /// Without it a failover triggered by a dying source can land after the user
  /// has already moved on, and hand the engine media nobody asked for.
  Future<void> _openAttempt(
    int index, {
    required Duration startAt,
    int retries = 0,
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
    // Whatever the viewer was listening to and reading goes back on once the
    // new media has published its tracks. A reopen restores the position; it
    // has no business also changing the language.
    _restorePending = _rememberedAudio != null || _rememberedSubtitle != null;
    // Every way back into playback goes through here - Start Over, a failover,
    // a hand-picked source - and none of them may leave the ended card up over
    // media that is opening.
    _ended = null;
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
    _attemptRetries = retries;
    _tried.add(index);

    // The outgoing attempt's last position goes to history before it is
    // forgotten: the sample is cleared on the next line.
    _flushProgress();

    // Per attempt, not per session. "Did this source play" and the
    // end-of-media check both ask about this media, and a sample left behind
    // by the last one answers for the wrong one.
    _sample = null;
    _handedToEngine = false;
    _setSawFrames(false);
    // Seeded with the start position rather than zero: the first value after
    // setMedia still carries the previous media's numbers, and treating that
    // as movement would both hide a stall and sample the wrong position.
    _lastSeenPosition = startAt;
    _lastSeenDuration = Duration.zero;
    _hlsMedia = null;
    _videoLengthAsked = false;
    _videoLength = null;
    _startAttemptClock();

    final stream = resolved.streams[index];

    _armFirstFrameDeadline(
      generation,
      torrent: isTorrentSource(stream) || _torrentFileIndex != null,
    );

    // The race only checked the top few. A source opened from past them -
    // picked by the viewer, or reached by failover - is checked now, while it
    // opens rather than in front of it, so its row says what it would have.
    if (!_probes.containsKey(index) && !isUncheckableSource(stream)) {
      _checkWhileOpening(index, stream);
    }

    // Which candidate is being tried is the startup view's to say - its pill,
    // its source line and its highlighted row all follow [_attemptIndex]. What
    // is left for the status line is anything unusual about this open, and a
    // line left over from the last one is not that.
    _setStatus('');

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
        return _failAttempt(
          l10n == null ? 'DRM' : describeDrmObstacle(l10n, obstacle),
          allowSameSourceRetry: false,
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
    if (isTorrent) _setStatus(_l10n?.playerPreparingTorrent ?? '');
    if (isTorrent && _torrentPoll == null) {
      _startedTorrent = true;
      _startTorrentPolling();
    }
    final playable = await playableUrlFor(read: _read, stream: stream);
    if (_disposed || generation != _generation) return;
    if (playable == null) {
      return _failAttempt(
        _l10n?.playerReasonTorrentNotPrepared ??
            'torrent could not be prepared',
      );
    }

    final uri = _playableUri(playable);
    if (uri == null) {
      return _failAttempt(
        _l10n?.playerReasonNoPlayableAddress ??
            'source has no playable address',
      );
    }

    final headers = playbackHeaders(stream);
    final mediaUri = clearKey != null
        ? await _decryptingUri(uri, headers, clearKey)
        : await _deliverableUri(uri, headers);
    if (_disposed || generation != _generation) return;

    _lastStreamUrl = stream.url;
    _isLive = isLiveSource(widget.item, stream.url);
    await _controller.setMedia(
      VlcMediaSource(
        uri: mediaUri,
        httpHeaders: headers,
        startPosition: startAt,
        // A live input takes its latency from --live-caching, which the
        // instance config does not carry, so the same interval VOD gets is
        // named here for both.
        //
        // The rendition ceiling rides here only once it has been lowered from
        // the seeded value, which is already on the instance config.
        mediaOptions: <String>[
          if (_isLive) ':live-caching=$kNetworkCachingMs',
          if (_isLive) ':network-caching=$kNetworkCachingMs',
          if (_adaptiveMaxHeight != _deviceAdaptiveMaxHeight)
            ':adaptive-maxheight=$_adaptiveMaxHeight',
        ],
      ),
      autoPlay: true,
    );
    if (_disposed || generation != _generation) return;
    // From here every tick is this attempt's. Restarted here as well as above:
    // everything between the two is setup — torrent preparation, a proxy
    // handshake — and the deadline the watchdog enforces is on the engine
    // producing a frame, not on getting to setMedia.
    _handedToEngine = true;
    _startAttemptClock();
    if (!_isLive && looksLikeHls(mediaUri)) {
      _hlsMedia = (uri: mediaUri, headers: headers);
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
  /// A non-null active id is the proof that it has.
  void _rememberTracks(VlcPlayerValue value) {
    final audioId = value.activeAudioTrackId;
    final subtitleId = value.activeSubtitleTrackId;

    if (_restorePending) {
      // Nothing to match against yet.
      if (audioId == null && subtitleId == null) return;
      _restorePending = false;
      unawaited(_restoreTracks());
      return;
    }

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

  Future<void> _snapshotAudio(int id) async {
    final generation = _generation;
    try {
      final tracks = await _controller.getAudioTracks();
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
      final tracks = await _controller.getSubtitleTracks();
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
      final audio = _rememberedAudio;
      if (audio != null) {
        final match = matchRememberedTrack(
          await _controller.getAudioTracks(),
          audio,
        );
        if (_disposed || generation != _generation) return;
        if (match != null) await _controller.setAudioTrack(match.id);
      }

      final subtitle = _rememberedSubtitle;
      if (subtitle != null) {
        if (_disposed || generation != _generation) return;
        final match = matchRememberedTrack(
          await _controller.getSubtitleTracks(),
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
      final tracks = await _controller.getSubtitleTracks();
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
        final tracks = (await _controller.getSubtitleTracks())
            .where((track) => track.id >= 0)
            .toList();
        if (superseded()) return;
        List<VlcMediaTrackInfo> info = const [];
        try {
          info = (await _controller.getMediaInfo()).subtitleTracks;
        } on Object {
          // The description is often enough on its own: libVLC names a track
          // `Track 1 - [English]`.
        }
        if (superseded()) return;
        if (kDebugMode) {
          debugPrint(
            'Subtitles: Auto looks for $preferred in '
            '${tracks.map((t) => '${t.id}:${t.name}').toList()} '
            '(on: ${_controller.value.activeSubtitleTrackId})',
          );
        }
        final matches = [
          for (final (index, track) in tracks.indexed)
            // Correlated by position, as the panel does: libVLC offers no
            // other way.
            if ((languageCodeOf(track.language) ??
                    languageCodeOf(
                      index < info.length ? info[index].language : null,
                    ) ??
                    languageCodeOf(track.name)) ==
                preferred)
              track,
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

  /// The current candidate failed. Retry it, or move to the next one.
  ///
  /// Resumes from [_resumePosition] rather than from `controller.value`, which
  /// `setMedia` has already zeroed by the time any retry runs — losing the
  /// user's position is the one thing failover must never do.
  ///
  /// [jumpTo] names where to go instead of the next in line, when the caller
  /// already knows a source that works.
  void _failAttempt(
    String reason, {
    bool allowSameSourceRetry = true,
    int? jumpTo,
  }) {
    if (_disposed) return;
    final resolved = _resolved;
    if (resolved == null) return;

    final startAt = _controller.value.isLive ? Duration.zero : _resumePosition;

    // A hand-picked source is on trial: the session it interrupted was fine,
    // so going back to it beats burning the failover budget on a URL nobody
    // was watching.
    final revert = _revertTo;
    if (revert != null) {
      _revertTo = null;
      _markFailed(_attemptIndex);
      _notify(
        _l10n?.playerSourceRestoredPrevious ??
            'That source would not play. Restored the previous one.',
      );
      unawaited(_openAttempt(revert.index, startAt: revert.position));
      return;
    }

    // Failover is otherwise silent: the engine is quietly handed a different
    // URL behind a frame that has stopped moving, which reads as a freeze.
    // This says why, until the next source produces a frame - naming the
    // source it is about, because the line above it names the next one.
    _setFailReason(
      '${sourceRowLabel(resolved.streams[_attemptIndex])} · $reason',
    );

    // A source that produced frames and then died is worth another try at the
    // same URL; one that never played at all is simply dead.
    // A failure the source cannot recover from - DRM we have no key for -
    // opts out: re-opening the same URL would hit the same wall.
    final hadFrames = _sawFrames;
    if (allowSameSourceRetry &&
        hadFrames &&
        _attemptRetries < _kSameSourceRetries) {
      unawaited(
        _openAttempt(
          _attemptIndex,
          startAt: startAt,
          retries: _attemptRetries + 1,
        ),
      );
      return;
    }

    _markFailed(_attemptIndex);
    // [jumpTo] is a source already proven, which beats the next in line.
    final next =
        jumpTo ??
        nextFailoverIndex(
          from: _attemptIndex,
          total: resolved.streams.length,
          tried: _tried,
          // Known dead before anything opened them, and a dead source that hangs
          // rather than erroring costs the whole stall deadline. Walked last, not
          // dropped: the probe is wrong about slow hosts.
          unreachable: <int>{
            for (final entry in _probes.entries)
              if (entry.value == ProbeOutcome.unhealthy ||
                  entry.value == ProbeOutcome.notVideo)
                entry.key,
          },
          // Picking up where playback stopped: a source that cannot seek would
          // start it again from the top.
          cannotSeek: startAt > Duration.zero
              ? <int>{
                  for (final entry in _probes.entries)
                    if (entry.value == ProbeOutcome.unseekable) entry.key,
                }
              : const <int>{},
        );
    if (next == null) {
      // Say what actually went wrong: a single-source channel refused for DRM
      // should name the scheme rather than just count to one.
      final total = resolved.streams.length;
      return _fail(
        _l10n?.playerNoSourcesPlayableWithReason(total, reason) ??
            (total == 1
                ? reason
                : 'None of the $total sources would play - $reason'),
      );
    }
    unawaited(_openAttempt(next, startAt: startAt));
  }

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
    if (_sawFrames) return;
    final resolved = _resolved;
    if (resolved == null) return;
    final target = firstReachableIndex(
      total: resolved.streams.length,
      probes: _probes,
      failed: _failedRows,
      except: index,
    );
    if (_revertTo == null && target == null) return;
    _failAttempt(
      _l10n?.playerReasonNoAnswer ?? 'no answer from the link',
      allowSameSourceRetry: false,
      jumpTo: target,
    );
  }

  /// Gives the attempt stamped [generation] until [kFirstFrameDeadline] - three
  /// minutes for a [torrent], which is waiting on pieces to seed - to show a
  /// picture, and moves on to the next source if it has not.
  ///
  /// Its own timer, counted from the moment the source starts opening and
  /// whatever the engine reports. The stall watchdog cannot be the judge
  /// here: it stands down while the engine says paused, stopped or ended, and
  /// before the screen reaches its playing stage, and a source stuck in any of
  /// those said "Opening…" for minutes. Off screen - backgrounded, or in
  /// picture-in-picture - the wait is nobody's, so it starts over rather than
  /// giving up on a source nobody is watching.
  void _armFirstFrameDeadline(int generation, {required bool torrent}) {
    _firstFrameDeadline?.cancel();
    _firstFrameDeadline = Timer(
      torrent ? kTorrentStallRecoverAfter : kFirstFrameDeadline,
      () {
        if (_disposed || generation != _generation || _sawFrames) return;
        if (!_foreground || _inPip) {
          _armFirstFrameDeadline(generation, torrent: torrent);
          return;
        }
        _recover(
          _l10n?.playerReasonSourceNeverStarted ?? 'the source never started',
        );
      },
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
    _attemptAge = Duration.zero;
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
    _stalledFor = Duration.zero;
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
      if (_lastStallAction != StallAction.none) _setStatus('');
      _resetStallClock();
      return;
    }

    _attemptAge += _kWatchdogTick;
    _stalledFor += _kWatchdogTick;

    // The position moved since the last tick, so there is no stall to report
    // and this second belongs to the other watchdog - the one that asks
    // whether a picture came with the sound. Exactly one of the two speaks per
    // tick, which is what keeps them from double-reporting the same second.
    if (_stalledFor <= _kWatchdogTick) {
      _watchVideoHealth();
      return;
    }
    // A frozen clock ends the measurement window: the counters would keep
    // ticking over a stall that is not this device's fault and read as a
    // decode failure.
    _videoBaseline = null;
    _videoWindow = Duration.zero;

    // A source that has never shown a picture is the first-frame deadline's to
    // judge, on its own clock - see [_armFirstFrameDeadline]. This one stands
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
        final l10n = _l10n;
        _recover(
          _sawFrames
              ? l10n?.playerReasonSourceStoppedResponding ??
                    'the source stopped responding'
              : l10n?.playerReasonSourceNeverStarted ??
                    'the source never started',
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
    final last = _arrivalReadBytes;
    _arrivalReadBytes = stats.readBytes;
    if (last != null && stats.readBytes > last) _bytesArrivedAt = _attemptAge;
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
        at: _attemptAge,
        // What tells the estimate a skip happened, so the bytes the skip
        // stranded stop being counted as buffer. See [BufferedAheadEstimator].
        seekRequests: _controller.seekRequests,
        speed: value.playbackSpeed,
        // The prefetch window libVLC was given, which is all it can hold.
        capacityBytes: _bufferMb * 1024 * 1024,
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

    final health = videoHealthFor(
      statsAvailable: stats.isAvailable,
      // Track info, not the vout, so this stays true for the very failure
      // being looked for: a video track that exists and is not reaching the
      // screen. False only for genuinely audio-only media.
      hasVideoTrack: _controller.value.videoSize != null,
      measuredFor: _videoWindow,
      displayed: stats.displayedPictures - baseline.displayed,
      lost: stats.lostPictures - baseline.lost,
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
        // Nothing has reached the screen for a whole window while the clock
        // ran. Handed to the ladder, which already knows how to reopen a
        // source once and when to move on.
        _recover(
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
    final next = stepDownFrom(_adaptiveMaxHeight);
    // Already at the floor. Reopening on a loop is worse than the slideshow.
    if (next == null) return;
    _adaptiveMaxHeight = next;
    unawaited(
      _openAttempt(
        _attemptIndex,
        startAt: _resumePosition,
        retries: _attemptRetries,
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

  /// Hands a stalled source to the failover ladder.
  ///
  /// Not a reopen of its own: [_failAttempt] already reopens a source that was
  /// playing, up to [_kSameSourceRetries], and moves on from one that was not.
  /// Routing through it is what keeps the retry budget honest — a source that
  /// stalls, recovers for three seconds and stalls again would otherwise
  /// reopen forever without ever trying a different candidate.
  void _recover(String reason) {
    _resetStallClock();
    _lastStallAction = StallAction.recover;
    _failAttempt(reason);
  }

  /// Network restore short-circuits the wait.
  ///
  /// Scoped to a session that is already stalled: `onConnectivityChanged`
  /// fires for interface changes that say nothing about reachability, and
  /// reopening a healthy stream on one would be a self-inflicted rebuffer.
  void _listenForNetworkRestore() {
    _connectivity = Connectivity().onConnectivityChanged.listen((results) {
      if (_disposed || _stage != _Stage.playing) return;
      if (!results.any((r) => r != ConnectivityResult.none)) return;
      if (_lastStallAction == StallAction.recover) return;
      if (_stalledFor < kStallNudgeAfter) return;
      _recover(_l10n?.playerReasonNetworkDropped ?? 'the network dropped');
    });
  }

  /// End-of-media is ambiguous: a finished film and a truncated download look
  /// identical to the engine. Only a position short of the duration
  /// distinguishes them.
  void _handleEnded() {
    if (_disposed) return;
    _flushProgress();

    // A live feed has no end. Reaching one means the stream dropped, so
    // reopening the same source is the right answer - advancing or failing over
    // to another source would abandon a channel that is merely interrupted.
    if (_isLive) {
      if (_liveReconnects >= _kMaxLiveReconnects) {
        // This source keeps dropping without ever coming back; try another.
        // Explicitly not a same-source retry: reopening is precisely what has
        // just been tried five times.
        _liveReconnects = 0;
        _failAttempt(
          _l10n?.playerReasonLiveFeedDropped ?? 'live feed dropped repeatedly',
          allowSameSourceRetry: false,
        );
        return;
      }
      _liveReconnects++;
      // The wait is spent on the overlay rather than on the last frame the
      // feed produced: a frozen picture under a play glyph reads as a hang.
      // _openAttempt would drop the flag anyway, but only after the delay.
      _setSawFrames(false);
      _setStatus(_l10n?.playerReconnecting ?? '');
      final generation = _generation;
      unawaited(
        Future<void>.delayed(_kLiveReconnectDelay).then((_) async {
          if (_disposed || generation != _generation) return;
          await _openAttempt(
            _attemptIndex,
            startAt: Duration.zero,
            retries: _attemptRetries,
          );
        }),
      );
      return;
    }

    if (!_sawFrames) {
      // This source ended without ever producing a frame, so there is nothing
      // that could have finished. It is a dead candidate, not a watched
      // episode - advancing on it would skip an episode nobody saw.
      _failAttempt(
        _l10n?.playerReasonStreamEndedBeforePlaying ??
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
    // Two ways to be a failure wearing an ending's clothes. Short of the
    // duration is a truncated download. No duration at all cannot be measured
    // - an HLS manifest with no EXT-X-ENDLIST, an unindexed MKV over HTTP, a
    // torrent whose header never completed - and "cannot tell" is treated as
    // a failure so the failover ladder still gets its turn.
    if (duration <= Duration.zero ||
        position < duration - const Duration(seconds: 2)) {
      _failAttempt(
        _l10n?.playerReasonStreamEndedEarly ??
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

  /// Picture-in-picture is an Android activity mode; there is no equivalent on
  /// the other platforms this ships to, and it is meaningless on a television.
  bool get _pipAvailable => Platform.isAndroid && _form != PlayerFormFactor.tv;

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

  Future<void> _enterPip() async {
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
    final entered = await _platform.enterPip(
      _controller.value.isPlaying,
      // Shapes the window to the film. Read at the moment of the request
      // rather than remembered, because a failover or a next-episode start
      // can have changed it since the last size event.
      videoSize: _controller.value.videoSize,
    );
    // Android answers false - not an error - when the user has PiP disabled
    // for the app, and then never sends onPictureInPictureModeChanged. Without
    // this the optimism above is permanent and the chrome never comes back.
    if (entered || _disposed || !mounted || !_inPip) return;
    setState(() => _inPip = false);
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
    // theirs.
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
      onPickEpisode: (episode) => unawaited(_pickEpisode(episode)),
      // The panel has no ProviderScope of its own, so the one question its
      // Episodes tab cannot answer - which of these have been seen - is
      // answered from here, one row at a time as the list builds them.
      episodeProgress: _episodeProgressFor,
      onPickFile: (file) => unawaited(_applyTorrentFile(file)),
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
    final at = _controller.value.isLive ? Duration.zero : _resumePosition;
    // The pick is on trial. Remember what it interrupted so its failure can put
    // that back rather than take the session down with it.
    if (onTrial) {
      _revertTo = (index: _attemptIndex, position: at);
    } else {
      // A hand-picked source deserves the full ladder rather than the leftovers
      // of the walk that already failed.
      _tried.clear();
      _attemptRetries = 0;
    }
    unawaited(_openAttempt(index, startAt: at));
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
    _tried.clear();
    _revertTo = null;
    await _openAttempt(_attemptIndex, startAt: Duration.zero);
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
    _tried.clear();
    _revertTo = null;
    _attemptRetries = 0;
    _liveReconnects = 0;
    _sample = null;
    _handedToEngine = false;
    // The refusal was made about the previous viewing of this episode. Left
    // set, the whole re-watch runs with the auto-advance silently off. The
    // offer goes with it: it belongs to the run that just ended.
    _nextEpisodeDeclined = false;
    _nextEpisodeOffer = null;
    setState(() => _ended = null);
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

    // The outgoing episode's last picture comes down here, before the first
    // await, and not in _openAttempt where every other attempt drops it.
    // Everything between here and setMedia - the download lookup, the plugin
    // resolve, the resume lookup - can take seconds over a frozen frame.
    _handedToEngine = false;
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
    _syncPlayingState(value);
    _syncOrientation(value);
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

    // Both of these are edges, not levels, and neither may run synchronously
    // inside the listener - failing over calls setMedia, which notifies again.
    if (value.state == VlcPlaybackState.error) {
      if (!_sawError) {
        _sawError = true;
        final reason =
            value.errorDescription ??
            _l10n?.playerReasonPlaybackError ??
            'playback error';
        scheduleMicrotask(() => _failAttempt(reason));
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
      _resumePosition = sample.position;
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
    // Read before the clock resets it: this is the only record that the
    // watchdog said anything.
    final recovering = _lastStallAction != StallAction.none;
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
      _firstFrameDeadline?.cancel();
      // Recorded for the source lists: this row has proved it can be reached.
      _playedRows.add(_attemptIndex);
      _publishPanelData();
      _setFailReason(null);
      // The seek has already been applied as a start position, so this is a
      // notice rather than a prompt - and it belongs on the first real frame,
      // not on the stage change, which fires while the engine is still opening.
      if (_initialResume != null && !_resumeHintOffered) {
        _resumeHintOffered = true;
        if (mounted) setState(() => _showResumeHint = true);
      }
    }
    if (_attemptAge < _kHealthyPlayback) return;
    _attemptRetries = 0;
    _liveReconnects = 0;
    // The pick has proved itself; there is nothing left to revert to.
    _revertTo = null;
    // The tried-set describes one failover walk, not the whole session: a
    // source that has just played happily has earned a fresh walk if the
    // network drops an hour from now.
    _tried
      ..clear()
      ..add(_attemptIndex);
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
    if (!value) _clearLock();
    if (_sawFrames == value) return;
    _sawFrames = value;
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
  void _syncOrientation(VlcPlayerValue value) {
    _platform.applyVideoOrientation(
      _form,
      renderedSize: value.displayVideoSize,
    );
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
    if (state == AppLifecycleState.resumed) {
      // However long the app was away is not time this source spent stalled,
      // and the engine needs a moment to get its position moving again.
      _resetStallClock();
      // A backstop behind `pipModeChanged`: returning to the foreground is
      // what ending PiP looks like, and the chrome must come back with it
      // whether or not the activity got round to telling us.
      if (_inPip) setState(() => _inPip = false);
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
        !_sawFrames ||
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
    // Nothing is opening any more, so nothing has a first frame to be late for.
    _firstFrameDeadline?.cancel();
    // Same rule as [_showEnded] and [_setSawFrames]: the failed frame unmounts
    // the whole controls subtree, so the chip that undoes the lock goes with
    // it and Back would do nothing on the first press.
    _clearLock();
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
      (url) => _fetchPlaylist(url, headers),
    );
    if (_disposed || generation != _generation || length == null) return;
    _videoLength = length;
    if (_controller.value.duration > length + _kLengthSlack) {
      _capLength(length);
    }
  }

  void _capLength(Duration length) {
    _controller.setDurationCap(length);
    // Taken before the cap, with libVLC's length in it - and on a video too
    // short to be sampled again, the last word [_handleEnded] would get: a
    // real ending read as a stream dying 27 hours short.
    final sample = _sample;
    if (sample != null && sample.duration > length) _sample = null;
  }

  /// One playlist, asked for with the headers libVLC was given for it.
  Future<String?> _fetchPlaylist(Uri url, Map<String, String> headers) async {
    try {
      final response = await _read(dioClientProvider).getUri<String>(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.plain,
          receiveTimeout: _kPlaylistTimeout,
          sendTimeout: _kPlaylistTimeout,
        ),
      );
      return response.data;
    } catch (_) {
      return null;
    }
  }

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
    _pickCooldown?.cancel();
    _abandonPendingResolve();
    _backEcho?.cancel();
    _lockEscape?.cancel();
    _watchdog?.cancel();
    _firstFrameDeadline?.cancel();
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
    _bufferedFraction.dispose();
    _sideCars.removeListener(_onSideCars);
    _sideCars.dispose();
    unawaited(_connectivity?.cancel());
    // Unconditional and required: Android keeps delivering over this channel
    // while it tears the PiP window down, and a handler left registered closes
    // over a screen that no longer exists.
    _platform.detachPipListener();
    // A window left full screen after the video closes traps the user in a
    // chrome-less shell. Not gated on _isFullscreen: that only tracks the
    // toggles we issued, and is wrong whenever the OS window control was used
    // instead - which is exactly when this matters.
    unawaited(_platform.exitFullscreen());
    _controller.removeListener(_onPlaybackValue);
    _controller.dispose();
    // The torrent server seeds in the background; nothing else stops it.
    if (_startedTorrent) unawaited(_read(torrentServiceProvider).stop());
    WakelockPlus.disable();
    // Hands orientation back the way this device wants it, rather than
    // unlocking rotation app-wide, which would leave every other screen free
    // to land sideways for the rest of the process.
    _platform.restoreOrientation(_form);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  /// The buffer the viewer asked for, in megabytes.
  ///
  /// One number for both engines. libVLC takes it as a prefetch window and
  /// TorrServer as its piece cache: a viewer who chose 256 MB meant it for
  /// whatever they are watching, and a torrent used to ignore them for a
  /// hard-coded 64.
  int get _bufferMb => resolveNetworkBufferMb(
    ref.read(playerSettingsProvider).asData?.value.networkBufferMb,
    ref.read(deviceProfileProvider).asData?.value.tier ?? DeviceTier.standard,
  );

  /// Hands the torrent server the same buffer, split so some of it stays
  /// behind the playhead.
  ///
  /// Fire and forget: the server may not be up, may be about to be started by
  /// a source resolver, or may not be involved at all on a direct stream. It
  /// remembers either way, and nothing about playback waits on it.
  void _applyTorrentBuffer() {
    final mb = _bufferMb;
    unawaited(
      _read(torrentServiceProvider).applyBufferSettings(
        cacheMb: mb,
        readAheadPercent: torrentReadAheadPercent(mb),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // A pure derivation of a watched value, cached because the orientation and
    // teardown calls run from places that have no context. The profile
    // resolves asynchronously, so this is also how a session that started
    // before it landed picks it up.
    _form = playerFormFactorOf(ref.watch(deviceProfileProvider).asData?.value);
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
            // Offstage rather than absent under the diagnostic switch: on
            // the texture platforms VlcPlayer's own initState attaches the
            // native player, so a widget left out of the tree is no player
            // at all. Offstage keeps the element and drops only the paint.
            if (_stage == _Stage.playing)
              Offstage(
                offstage: PlayerDiagnostics.suppressVideoSurface,
                child: VlcPlayer(
                  controller: _controller,
                  fit: _fit,
                  darwinRenderer: playerDarwinRenderer,
                  androidRenderer: playerAndroidRenderer,
                  backgroundColor: playerBackdropColor,
                ),
              ),
            // Subtitle files, drawn over the picture rather than into it, so
            // the fit never reaches them - and in PiP as well, as libVLC's
            // were. Lifted over the controls while those are up.
            if (_stage == _Stage.playing) _sideCarSubtitles(isTv: isTv),
            // Everything before a picture: getting links, checking them,
            // opening one - `setMedia` hands libVLC a URL and returns, so the
            // playing stage begins with the video widget an empty surface -
            // and the dead end when none of them played. Keyed, so the view
            // is one element across all of it: the player is inserted
            // beneath it as opening begins, and unkeyed it would be rebuilt
            // there with its list back at the top.
            if (_stage != _Stage.playing || (!_inPip && !_sawFrames))
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
                _sawFrames &&
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
                  onFitChanged: (fit) {
                    if (mounted) setState(() => _fit = fit);
                  },
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
                  onEnterPip: _pipAvailable ? _enterPip : null,
                  onToggleFullscreen: _fullscreenAvailable
                      ? _toggleFullscreen
                      : null,
                  isFullscreen: _isFullscreen,
                  isLive: _isLive,
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
                when _stage == _Stage.playing && !_inPip && _sawFrames)
              _endedCard(kind, isTv: isTv),
          ],
        ),
      ),
    );
  }

  Widget _sideCarSubtitles({required bool isTv}) {
    final controlsShown = !_inPip && _sawFrames && _ended == null;
    return Consumer(
      builder: (context, ref, _) {
        final settings =
            ref.watch(playerSettingsProvider).asData?.value ??
            const PlayerSettings();
        return ValueListenableBuilder<bool>(
          valueListenable: _chrome,
          builder: (context, chromeUp, _) => SideCarSubtitleView(
            controller: _controller,
            subtitles: _sideCars,
            settings: settings,
            bottomInset: chromeUp && controlsShown
                ? HotstarPlayerStyle.bottomChromeHeightFor(isTv: isTv)
                : 0,
          ),
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
    _tried.clear();
    _revertTo = null;
    _attemptRetries = 0;
    _liveReconnects = 0;
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
              hasPicture: _sawFrames,
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
      final plugin = _pluginName;
      return plugin == null ? l10n.loading : l10n.playerGettingLinks(plugin);
    }
    return _status.isEmpty ? null : _status;
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
