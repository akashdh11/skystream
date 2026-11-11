import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleListener, AppLifecycleState, WidgetsBinding;

import 'vlc_media_info.dart';
import 'vlc_http_headers.dart';
import 'vlc_media_source.dart';
import 'vlc_playback_clock.dart';
import 'vlc_player_config.dart';
import 'vlc_media_stats.dart';
import 'vlc_player_controller_internals.dart';
import 'vlc_player_error.dart';
import 'vlc_player_value.dart';
import 'vlc_video_fit.dart';
import 'vlc_video_geometry.dart';

/// Playlist repeat behavior used by `VlcPlayerController.setPlaylist`.
enum VlcPlaylistLoopMode {
  /// Stop at the beginning or end of the playlist.
  none,

  /// Repeat the current playlist item when it ends.
  loopOne,

  /// Wrap to the first or last item when advancing past an edge.
  loopAll,
}

/// Controls a `VlcPlayer` and exposes playback state.
///
/// A controller can be configured before it is attached to a widget. Calls to
/// [setMedia] or [setPlaylist] are remembered and applied when the native
/// player is created. Playback commands such as [play] and [pause] require the
/// controller to be attached to a `VlcPlayer`.
abstract class VlcPlayerController extends ValueNotifier<VlcPlayerValue> {
  /// Creates a controller.
  ///
  /// Use [mediaSource] when an initial media item should be applied when the
  /// native player is created.
  /// Prefer [config] over hand-written [options]: it is typed, documented, and
  /// spells the VLC flags for you. When both are given, [config] is expanded
  /// first and [options] appended, so a raw option always wins over the
  /// generated equivalent.
  factory VlcPlayerController({
    VlcMediaSource? mediaSource,
    bool autoPlay = false,
    VlcPlayerConfig? config,
    List<String> options = const <String>[],
    Duration? eventThrottleInterval,
    Duration stallIndicatorDelay = const Duration(milliseconds: 1000),
  }) {
    return _VlcPlayerController(
      mediaSource: mediaSource,
      autoPlay: autoPlay,
      options: <String>[...?config?.toOptions(), ...options],
      eventThrottleInterval: eventThrottleInterval,
      stallIndicatorDelay: stallIndicatorDelay,
      // The nullable value, not the resolved one: the platform default is
      // read at the moment it is needed so a const config cannot freeze it.
      configuredBackgroundPolicy: config?.backgroundPolicy,
    );
  }

  VlcPlayerController._() : super(const VlcPlayerValue());

  /// Whether the initially configured media source should start playback
  /// immediately.
  bool get autoPlay;

  /// VLC instance options applied when the native player is created.
  List<String> get options;

  /// Optional interval used to coalesce progress-only native events.
  ///
  /// When set to a positive duration, updates that only change playback
  /// position, media duration, or buffering progress are delivered at most once
  /// per interval. State, readiness, track metadata, volume, speed, and errors
  /// still notify listeners immediately. The default `null` keeps every
  /// distinct native value update visible immediately.
  Duration? get eventThrottleInterval;

  /// How long the position clock may stand still on a playing player before
  /// [VlcPlayerValue.isStalled] is raised.
  ///
  /// The default of one second is not a taste choice. The desktop backends
  /// poll libVLC every 500 ms and the host may throttle events on top of that
  /// ([eventThrottleInterval]), so two consecutive snapshots of healthy
  /// playback can legitimately be up to poll-plus-throttle apart. A delay
  /// shorter than that reads the gap between polls as a stall and flickers a
  /// spinner over a video that is playing fine. Anything set here must stay
  /// clear of that sum.
  Duration get stallIndicatorDelay;

  /// What the controller does with playback when the app leaves the
  /// foreground, resolved against the platform default.
  ///
  /// Owned here rather than by the host screen so that every embedder of this
  /// package gets the behaviour, and so the "resume only what the policy
  /// paused" bookkeeping lives next to the state it reads.
  VlcBackgroundPolicy get backgroundPolicy;

  /// Whether this controller is currently attached to a native player instance.
  bool get isAttached;

  /// Current playlist items, or an empty list when no playlist is active.
  List<VlcMediaSource> get playlist;

  /// Current playlist index, or `null` when no playlist is active.
  int? get playlistIndex;

  /// Current playlist loop mode.
  VlcPlaylistLoopMode get playlistLoopMode;

  /// Current media source, including a pending source set before attachment.
  VlcMediaSource? get currentMediaSource;

  /// Whether [next] can move to another item without wrapping.
  bool get hasNext;

  /// Whether [previous] can move to another item without wrapping.
  bool get hasPrevious;

  /// Loads a [VlcMediaSource].
  ///
  /// Use this when the item needs HTTP headers, VLC media options, or an
  /// initial seek position. This clears any active playlist.
  ///
  /// [keepPicture] asks the output to keep showing the current picture until
  /// the new media plays from where it was asked to start, rather than the
  /// new media's first decoded picture: see [VlcPlayerValue.isPictureHeld].
  /// It is for reopening the same film at a position. It does nothing when
  /// nothing is on screen yet, or on an output that cannot hold.
  ///
  /// While the picture is held, [pendingSeekTarget] is [source]'s start
  /// position: the engine reports 0 until the new media plays from there.
  Future<void> setMedia(
    VlcMediaSource source, {
    bool autoPlay = false,
    bool keepPicture = false,
  });

  /// Caps the reported [VlcPlayerValue.duration] at [cap], for a media whose
  /// length libVLC gets wrong; null lifts the cap from the next report on.
  ///
  /// libVLC reports an HLS master's length as that of the longest playlist it
  /// has loaded, alternative renditions included, selected or not. A subtitle
  /// file wrapped as one segment that claims 99,999 seconds therefore makes a
  /// fifty-minute episode read 27:46:39. A host that has measured the video's
  /// own playlist passes that length here.
  ///
  /// The cap only ever shortens: a shorter report, or an unknown one, is
  /// published as it is. It applies at once and lasts until the next media.
  void setDurationCap(Duration? cap);

  /// Loads a playlist and selects [initialIndex].
  ///
  /// [sources] must be non-empty. When [autoAdvance] is true, the controller
  /// advances after VLC reports that the current item ended. [loopMode] controls
  /// repeat and wrap behavior.
  Future<void> setPlaylist(
    List<VlcMediaSource> sources, {
    int initialIndex = 0,
    bool autoPlay = false,
    bool autoAdvance = true,
    VlcPlaylistLoopMode loopMode = VlcPlaylistLoopMode.none,
  });

  /// Moves to the next playlist item.
  ///
  /// Returns `false` when there is no next item and [playlistLoopMode] is
  /// [VlcPlaylistLoopMode.none]. Throws [StateError] when no playlist is active.
  Future<bool> next({bool autoPlay = true});

  /// Moves to the previous playlist item.
  ///
  /// Returns `false` when there is no previous item and [playlistLoopMode] is
  /// [VlcPlaylistLoopMode.none]. Throws [StateError] when no playlist is active.
  Future<bool> previous({bool autoPlay = true});

  /// Loads the playlist item at [index].
  ///
  /// Throws [StateError] when no playlist is active.
  Future<void> jumpTo(int index, {bool autoPlay = true});

  /// Appends [source] to the active playlist.
  ///
  /// Throws [StateError] when no playlist is active.
  Future<void> addToPlaylist(VlcMediaSource source);

  /// Inserts [source] into the active playlist at [index].
  ///
  /// Throws [StateError] when no playlist is active.
  Future<void> insertIntoPlaylist(int index, VlcMediaSource source);

  /// Removes the playlist item at [index].
  ///
  /// Removing the current item loads the next valid item. If the removed item
  /// was the only item, playback stops and the playlist is cleared.
  Future<void> removeFromPlaylistAt(int index, {bool autoPlay = true});

  /// Clears the active playlist and stops playback when a player is attached.
  Future<void> clearPlaylist();

  /// Shuffles the active playlist.
  ///
  /// When [seed] is provided, the shuffle order is deterministic.
  Future<void> shufflePlaylist({int? seed});

  /// Starts or resumes playback.
  Future<void> play();

  /// Pauses playback.
  Future<void> pause();

  /// Stops playback.
  ///
  /// With no native player attached yet, the media given to [setMedia] opens
  /// stopped when one attaches, instead of starting on its own.
  Future<void> stop();

  /// Starts iOS picture-in-picture for this player, if the device supports
  /// it.
  ///
  /// True means the request went out; the window opening — or failing to —
  /// is reported through [isPictureInPicture]. False, not an error, when
  /// the device cannot do PiP, when there is no picture yet, or when no
  /// native player is attached. Android has no equivalent here: its PiP is
  /// an activity mode the host screen enters itself, so this stays false
  /// there.
  ///
  /// [sourceRect] is the video picture's on-screen rect, which the native
  /// window opens from: a real frame, not a 1x1 host the system treats as
  /// not-displaying. Null sends no rect and native falls back to the
  /// window's bounds.
  Future<bool> startPictureInPicture({Rect? sourceRect});

  /// Marks a picture-in-picture start as imminent, holding off the
  /// background pause, without asking the native side to start yet.
  ///
  /// The native side starts the window when the app actually backgrounds
  /// (the `didEnterBackground` observer); this only keeps the film
  /// playing until then. Cleared when the window opens or fails (the
  /// `pictureInPicture` event), or by [stopPictureInPicture]. A transient
  /// foreground interruption (Control Center) that never backgrounds the
  /// app never pauses the film, so the hold is released by the caller's
  /// `resumed` handler instead.
  void notePictureInPictureImminent();

  /// Stops iOS picture-in-picture, if one is running. The window closing is
  /// reported through [isPictureInPicture].
  Future<void> stopPictureInPicture();

  /// Whether this player is currently showing in picture-in-picture.
  ///
  /// iOS only, reported by the native PiP window as it opens and closes —
  /// by the request above, by the window's own close button, or by the
  /// viewer tapping the window to come back. Android's PiP is an activity
  /// mode the host screen tracks itself, so this stays false there.
  ValueListenable<bool> get isPictureInPicture;

  /// The last picture-in-picture failure, in the native side's words, and
  /// whether a start would be accepted right now — the debug line the player
  /// shows when a start fails, so a silent button has a reason on screen.
  /// Null when no attempt has been made, or the last one succeeded.
  String? get lastPipError;

  /// Whether the native controller would accept a start right now
  /// (`isPictureInPicturePossible`), as last reported with a PiP event.
  /// Null before any PiP event has arrived.
  bool? get lastPipPossible;

  /// Seeks to [position].
  ///
  /// [position] must be non-negative. [pendingSeekTarget] moves to it at once.
  /// The engine is sent it at once too, unless another seek went out within
  /// the last [seekMergeWindow] - then the two are merged, and the engine is
  /// sent the latest target once the seeks stop arriving for a window. The
  /// returned future completes once the seek is sent or, merged, taken.
  Future<void> seekTo(Duration position);

  /// Seeks to [fraction], from `0.0` to `1.0`, of the window a live HLS or
  /// DASH stream still lists (`libvlc_media_player_set_position`).
  ///
  /// [VlcPlayerValue.duration] is that window's length and
  /// [VlcPlayerValue.positionFraction] where playback is in it; without both
  /// there is no window, and this throws a [StateError]. For a live HLS
  /// stream ([VlcMediaSource.isLive]) the controller works that place out
  /// itself: libVLC 3 counts the stream's time from where it was joined but
  /// measures the window from the playlist it last read, so its own fraction
  /// runs ahead of the window as it moves on. It goes the way
  /// [seekTo] goes - [pendingSeekTarget] moves at once to the matching
  /// position, and seeks within [seekMergeWindow] are merged - but the engine
  /// is sent the window's fraction rather than a time.
  Future<void> seekToWindowFraction(double fraction);

  /// How long after a seek has gone to the engine further seeks are held and
  /// merged into one.
  ///
  /// libVLC answers every seek by flushing its decoders and, whenever the
  /// target is not already in its read-ahead, by dropping that and asking the
  /// network for the stream again - over a new connection on HTTP/1.1. It
  /// merges queued seeks only while one is still being processed (VLC 3.0.21
  /// `src/input/input.c`), so six presses of an arrow key, six taps or six
  /// bumps of a gamepad shoulder button became three full resets, a frame
  /// from each flashing past.
  static const Duration seekMergeWindow = Duration(milliseconds: 400);

  /// Where the last seek is going, until the engine gets there; null when no
  /// seek is on its way.
  ///
  /// libVLC keeps reporting the position it left while a seek repositions the
  /// demuxer and refills the buffer - seconds, on a slow network file - so a
  /// scrubber drawn from [VlcPlayerValue.position] alone springs back to where
  /// the viewer was and jumps forward later. Media3 and the browsers report a
  /// seek's target from the moment it is asked for; a scrubber or a clock that
  /// wants to behave the same shows this while it is set.
  /// [VlcPlayerValue.position] itself stays the engine's own throughout, for
  /// everything that must only ever see a place playback reached.
  ///
  /// Set by [seekTo]. Cleared when the engine's position arrives at it - a
  /// little short counts, since seeks land on a keyframe or a segment boundary
  /// - or goes past it in the seek's direction; when the engine can no longer
  /// get there (stopped, ended, failed, new media); and when playback carries
  /// on somewhere else without ever arriving, which is an engine that did not
  /// take the seek at all.
  ///
  /// A [setMedia] given `keepPicture` and a start position sets it too, to
  /// that start, once the native side has answered and while the output
  /// holds the picture: the engine reports 0 until the new media plays from
  /// its start. That target is never sent and never counted in
  /// [seekRequests]; it goes when the hold ends or the media can no longer
  /// play, and a [seekTo] replaces it with a seek from the start.
  ValueListenable<Duration?> get pendingSeekTarget;

  /// How many seeks have been asked for on this controller.
  ///
  /// Only ever increases, and increases the moment a seek is requested rather
  /// than when the engine acts on one. A host watching for a dead source needs
  /// that distinction: a seek freezes the reported position while the demuxer
  /// repositions and refills, and on a slow source it can stay frozen for
  /// longer than any sane "nothing is happening" threshold. Counting that as a
  /// dead source reopens the media underneath a viewer who only skipped
  /// forward. Comparing this against a remembered value tells a host the freeze
  /// it is looking at was asked for.
  int get seekRequests;

  /// How many pauses and stops this controller has been asked for, or has
  /// made itself.
  ///
  /// Only ever increases, and increases the moment one is asked for, as
  /// [seekRequests] does: every [pause] and [stop], a playlist's own stop,
  /// the pause [backgroundPolicy] sends as the app goes away, and an open it
  /// turns into a stopped one because the app is away. A host watching for a
  /// stop nobody asked for - the engine's own, after a failure it did not
  /// report as one - compares this against a remembered value. A pause the
  /// system makes for an audio interruption is not counted:
  /// [VlcPlayerValue.interruption] says so.
  int get pauseRequests;

  /// Where playback is at this moment, for anything drawn against the
  /// picture between the engine's reports - subtitle lines a host draws
  /// itself, above all.
  ///
  /// Fed every native snapshot ahead of [eventThrottleInterval], and told of
  /// every seek and new media; see [VlcPlaybackClock] for how it runs on and
  /// when it moves back. [VlcPlayerValue.position] stays the engine's own
  /// last word.
  VlcPlaybackClock get playbackClock;

  /// Sets VLC volume.
  ///
  /// Values are clamped to VLC's `0..200` range.
  Future<void> setVolume(int volume);

  /// Sets playback speed.
  ///
  /// [speed] must be finite and greater than zero. `1.0` is normal speed.
  Future<void> setPlaybackSpeed(double speed);

  /// Changes how video is scaled inside the view, without recreating the
  /// native player. Called by `VlcPlayer` when its `fit` changes.
  Future<void> setFit(VlcVideoFit fit);

  /// Sets the audio playback delay.
  ///
  /// Positive values delay audio; negative values play audio earlier.
  Future<void> setAudioDelay(Duration delay);

  /// Sets the subtitle display delay.
  ///
  /// Positive values delay subtitles; negative values show subtitles earlier.
  Future<void> setSubtitleDelay(Duration delay);

  /// Restyles the subtitle lines libVLC draws into the picture while the video
  /// plays: text tracks inside the video show [look] from their next line, and
  /// its raise moves the line on screen at once.
  ///
  /// libVLC 3 has no public call for this; the platform sets the variables its
  /// text renderer reads as it draws. SSA/ASS tracks keep their own styles,
  /// and bitmap tracks their pictures; the raise still moves both. CEA-608
  /// captions keep their grid's size, and closed captions' own colours win.
  /// On Darwin's platform view, which lays lines out on the screen's picture,
  /// the raise comes out smaller than asked. The look stays with the
  /// controller: a player created later starts with it.
  ///
  /// Answers whether the engine applied it - false before any player exists,
  /// on a libVLC other than 3.0, or on a platform without the call.
  Future<bool> setSubtitleLook(VlcSubtitleLook look);

  /// Captures the current video frame as PNG bytes.
  ///
  /// [width] and [height] must be positive when provided.
  Future<Uint8List> takeSnapshot({int? width, int? height});

  /// Returns selectable audio tracks for the current media.
  Future<List<VlcTrackDescription>> getAudioTracks();

  /// Selects an audio track by VLC track [id].
  ///
  /// Use an id returned by [getAudioTracks].
  Future<void> setAudioTrack(int id);

  /// Returns selectable embedded subtitle tracks for the current media.
  Future<List<VlcTrackDescription>> getSubtitleTracks();

  /// Selects an embedded subtitle track by VLC track [id].
  ///
  /// Use an id returned by [getSubtitleTracks].
  Future<void> setSubtitleTrack(int id);

  /// Disables subtitle rendering for the current media.
  Future<void> disableSubtitle();

  /// Asks the engine to add an external subtitle from [uri] and select it.
  ///
  /// [uri] can point to a local file or a remote subtitle URL supported by VLC.
  ///
  /// The future completing does NOT mean the track exists yet. Before
  /// attachment the request is queued and replayed on attach; after it,
  /// libVLC 3 hands the slave to the input thread, so the snapshot that
  /// follows still describes the state from before the add on all five
  /// backends. Wait for [VlcPlayerValue.trackRevision] to move, then re-read
  /// [getSubtitleTracks]; do not treat a list read straight after this call as
  /// authoritative.
  Future<void> addSubtitle(Uri uri);

  /// Returns metadata and discovered track details for the current media.
  Future<VlcMediaInfo> getMediaInfo();

  /// Returns runtime statistics for the current media session.
  Future<VlcMediaStats> getMediaStats();
}

const MethodChannel _methodChannel = MethodChannel('vlc_player');

/// How far short of a seek's target the engine may land and count as there:
/// seeks land on a keyframe or a segment boundary, a little before the
/// millisecond asked for. See `_seekLanded`.
const Duration _kSeekLandsShortBy = Duration(seconds: 3);

/// How far past a seek's target the engine may land and count as there.
const Duration _kSeekLandsLongBy = Duration(milliseconds: 750);

/// How many published positions in a row may move without arriving before a
/// seek is taken as not having happened. Two or three can be reports already
/// on their way when the seek was asked - an earlier step of a chain landing,
/// a tick from the old position - so a handful more than that: about three
/// seconds of playback carrying on at the rate positions are published.
const int _kSeekIgnoredAfterMoves = 12;

/// How far a refusal libVLC logged may be from the time a seek sent, and
/// still be that seek's: the log carries the time libVLC was asked for, in
/// microseconds, and a merged or live seek goes out rounded.
const int _kSeekRefusalMatchMs = 1000;

/// How many times a seek libVLC keeps refusing is sent again. A refusal is
/// libVLC's own word, so each one is worth answering; a stream that refuses
/// every time is not going to change its mind.
const int _kSeekRefusalResends = 3;

/// Where the reports after a seek was sent stand against its echo: none at
/// the time sent yet, the echo seen, or a report from somewhere else since.
/// See `_followSeekEcho`.
enum _SeekEcho { awaited, seen, over }

class _VlcPlayerController extends VlcPlayerController
    implements VlcPlayerControllerInternals {
  _VlcPlayerController({
    VlcMediaSource? mediaSource,
    this.autoPlay = false,
    List<String> options = const <String>[],
    this.eventThrottleInterval,
    required this.stallIndicatorDelay,
    this.configuredBackgroundPolicy,
  }) : options = List<String>.unmodifiable(options),
       super._() {
    if (eventThrottleInterval case final interval? when interval.isNegative) {
      throw ArgumentError.value(
        eventThrottleInterval,
        'eventThrottleInterval',
        'Must not be negative.',
      );
    }
    if (stallIndicatorDelay <= Duration.zero) {
      throw ArgumentError.value(
        stallIndicatorDelay,
        'stallIndicatorDelay',
        'Must be positive.',
      );
    }
    _pendingMediaSource = mediaSource;
    _pendingAutoPlay = autoPlay;
    // Judged against what is published, not the raw snapshot: a landing held
    // back by the event throttle must not clear the target while the old
    // position is still the one on screen.
    addListener(_watchSeekLanding);
  }

  @override
  final bool autoPlay;

  @override
  final List<String> options;

  @override
  final Duration? eventThrottleInterval;

  @override
  final Duration stallIndicatorDelay;

  /// The host's stated preference, or null to follow the platform.
  final VlcBackgroundPolicy? configuredBackgroundPolicy;

  /// Created on first attach rather than in the constructor.
  ///
  /// [AppLifecycleListener] resolves `WidgetsBinding.instance` eagerly, and a
  /// controller is legitimately built in a plain `flutter_test` `test()` with
  /// no binding at all — configuring one is not the same as playing anything.
  /// There is also nothing to pause before a native player exists.
  AppLifecycleListener? _lifecycleListener;

  /// Whether [backgroundPolicy] is what paused the current playback.
  ///
  /// The whole point of the flag: a viewer who paused by hand and then pressed
  /// Home must come back to a paused player. Resuming unconditionally is the
  /// bug this exists to prevent.
  bool _pausedForBackground = false;

  /// Whether the CURRENT media has actually reached playback.
  ///
  /// [VlcPlayerValue] merges into its predecessor, so straight after
  /// `setMedia` `value.position` still describes the media before it. This is
  /// the flag that tells the two apart, and it is what makes a re-attach able
  /// to trust the live position - see [_mediaForAttach].
  bool _hasPlayedSinceMedia = false;

  /// Whether a play has been asked of the current media - its autoPlay or a
  /// [play] - since it was set, and not taken back by a [pause] or [stop].
  /// Until it plays, such a media is starting whatever the engine says: the
  /// Windows and Linux core reports idle for a moment after a play, before
  /// libVLC opens the input (FORK.md 35).
  bool _playAskedSinceMedia = false;

  /// Whether an audio interruption is what paused the current playback, and
  /// whether it promised to end.
  ///
  /// Set only for [VlcAudioInterruption.focusLostTransient]: a call comes
  /// back, a permanent loss and a yanked pair of headphones do not.
  ///
  /// Tracked apart from [_pausedForBackground] rather than folded into it,
  /// because the two are settled by different events and the interleaving that
  /// matters gets it wrong otherwise. A call arriving and then the call UI
  /// pushing the app away leaves only this one set — the policy stakes its
  /// claim on a player it found playing, and an interrupted player is already
  /// paused — so when focus returns to a backgrounded app, the claim is handed
  /// over deliberately in [_applyInterruption] instead of being assumed.
  ///
  /// Both being set at once is harmless where it can happen, and neither
  /// resume can escape the native focus request: a play that the system
  /// refuses does not start anything, it comes straight back as another
  /// interruption.
  bool _pausedForAudioFocus = false;

  /// Whether the app is currently in the background.
  ///
  /// Distinct from [_pausedForBackground], which only records that the policy
  /// paused something. Media can be opened while the app is away - a cold
  /// magnet resolves for minutes - and that open must not start making noise.
  bool _backgrounded = false;

  int? _viewId;

  /// Moves on with every attach and detach, so a native player whose `create`
  /// answers after its widget has gone - superseded by a newer attach, or
  /// detached - is disposed rather than attached over the newer one.
  int _attachGeneration = 0;
  int? _textureId;
  VlcMediaSource? _pendingMediaSource;

  /// Counts the `setSource` calls sent, so an attach can tell that media it
  /// would send went out already, from a setMedia made while it was getting
  /// the new player ready (FORK.md 34).
  int _sourcesSent = 0;

  /// A background pause asked for while the video was still opening or
  /// rebuffering, sent at its first `playing` (FORK.md 35).
  bool _pauseWhenItPlays = false;
  bool _pendingAutoPlay = false;

  /// External subtitles requested before a player instance existed.
  ///
  /// [setMedia] already tolerates being called before attachment, so callers
  /// reasonably expect [addSubtitle] to as well — otherwise every caller has to
  /// hand-roll the same "wait until attached" dance. They are flushed in order
  /// once a view or texture is attached, and dropped when new media is set.
  final List<Uri> _pendingSubtitles = <Uri>[];
  List<VlcMediaSource> _playlist = const <VlcMediaSource>[];
  int? _playlistIndex;
  bool _playlistAutoAdvance = false;
  VlcPlaylistLoopMode _playlistLoopMode = VlcPlaylistLoopMode.none;
  StreamSubscription<Object?>? _eventsSubscription;
  Timer? _eventThrottleTimer;
  VlcPlayerValue? _pendingThrottledValue;

  /// The host's measured length for the current media - see [setDurationCap].
  Duration? _durationCap;

  /// What the widget last asked libVLC to crop or stretch to; see
  /// [setVideoGeometry]. Lives on the controller rather than the native player
  /// so a player created later - a reattach - starts with it.
  VlcVideoGeometry _videoGeometry = VlcVideoGeometry.none;

  /// The look [setSubtitleLook] last asked for, kept for a player created
  /// later, and sent again when the picture changes size: its raise is a
  /// share of the picture's height, which libVLC takes in pixels.
  VlcSubtitleLook? _subtitleLook;

  /// Counts down [stallIndicatorDelay] from the first snapshot whose position
  /// matched the one before it. Armed only while the engine claims to be
  /// running, and disarmed by any movement of the clock.
  Timer? _stallTimer;

  /// When the clock last moved, and how long it took since the move before:
  /// a clock that moves in steps of about a second gets [_stepGrace] more
  /// before the stall flag (FORK.md 36).
  DateTime? _lastMoveAt;
  Duration? _lastStep;

  /// From this interval between moves, the clock counts as stepping.
  static const Duration _steppingFrom = Duration(milliseconds: 900);

  /// The more a stepping clock gets: every flash measured was under 180 ms.
  static const Duration _stepGrace = Duration(milliseconds: 250);

  Duration get _stallDelay => (_lastStep ?? Duration.zero) >= _steppingFrom
      ? stallIndicatorDelay + _stepGrace
      : stallIndicatorDelay;

  /// The position of the last native snapshot, throttled or not.
  ///
  /// Kept apart from `value.position` on purpose: under [eventThrottleInterval]
  /// the published position lags the engine by up to an interval, and a stall
  /// judged against it would see a frozen clock at every flush.
  Duration? _lastNativePosition;

  final ValueNotifier<Duration?> _pendingSeekTarget = ValueNotifier<Duration?>(
    null,
  );

  /// Whether a picture-in-picture start was requested and its result has not
  /// arrived yet.
  ///
  /// The native start only says the request went out; the window opening —
  /// or failing to — is reported through [isPictureInPicture]. While the
  /// answer is outstanding the background pause must hold off (see
  /// [_pauseForBackground]): pausing now would stop the playback the window
  /// is about to show. Cleared by the event, by [stopPictureInPicture], and
  /// by a native refusal in [startPictureInPicture].
  bool _pictureInPicturePending = false;

  /// Whether the iOS picture-in-picture window is up. See
  /// [VlcPlayerController.isPictureInPicture].
  final ValueNotifier<bool> _pictureInPicture = ValueNotifier<bool>(false);

  @override
  ValueListenable<bool> get isPictureInPicture => _pictureInPicture;

  /// The last picture-in-picture failure the native side reported, and
  /// whether a start would be accepted right now. See
  /// [VlcPlayerController.lastPipError].
  String? _lastPipError;
  bool? _lastPipPossible;

  @override
  String? get lastPipError => _lastPipError;

  @override
  bool? get lastPipPossible => _lastPipPossible;

  /// The published position the pending seek set out from - in a chain of
  /// steps, the previous step's target - so an earlier step landing late is
  /// not taken for this one.
  Duration? _seekOrigin;

  /// The published position when the landing was last checked, and how many
  /// checks in a row have found it moving without arriving. A seek on its way
  /// holds the engine's position still; one that moves and moves without
  /// arriving is playback carrying on somewhere the seek never took it.
  Duration? _seekLastSeen;
  int _seekMovesWithoutLanding = 0;

  /// Whether [pendingSeekTarget] is a held reopen's start rather than a
  /// seek; see [_publishHeldStart].
  bool _heldStart = false;
  bool _isDisposed = false;

  final PlaybackClock _playbackClock = PlaybackClock();

  @override
  VlcPlaybackClock get playbackClock => _playbackClock;

  @override
  VlcBackgroundPolicy get backgroundPolicy =>
      configuredBackgroundPolicy ??
      VlcPlayerConfig.platformDefaultBackgroundPolicy;

  @override
  bool get isAttached => _viewId != null;

  @override
  List<VlcMediaSource> get playlist => _playlist;

  @override
  int? get playlistIndex => _playlistIndex;

  @override
  VlcPlaylistLoopMode get playlistLoopMode => _playlistLoopMode;

  @override
  VlcMediaSource? get currentMediaSource => _pendingMediaSource;

  @override
  bool get hasNext => switch (_playlistIndex) {
    final int index => index + 1 < _playlist.length,
    null => false,
  };

  @override
  bool get hasPrevious => switch (_playlistIndex) {
    final int index => index > 0,
    null => false,
  };

  /// Attaches this controller to a platform-view player instance.
  @override
  Future<void> attach(int viewId) async {
    _ensureNotDisposed();
    if (_viewId == viewId) {
      return;
    }
    _attachGeneration += 1;

    final oldViewId = _viewId;
    _viewId = null;
    _textureId = null;
    await _eventsSubscription?.cancel();
    _eventsSubscription = null;
    _cancelPendingThrottledValue();
    _cancelStallTimer();
    if (oldViewId != null) {
      await _disposeNativeView(oldViewId);
    }
    if (_isDisposed) {
      await _disposeNativeView(viewId);
      throw StateError('The controller has been disposed.');
    }

    _viewId = viewId;
    final sentAtAttach = _sourcesSent;
    _seekRefusals = 0;
    _lastSequence = 0;
    _eventsSubscription = EventChannel(
      'vlc_player/events/$viewId',
    ).receiveBroadcastStream().listen(_handleEvent, onError: _handleEventError);
    _ensureLifecycleListener();
    // Ahead of the media, so its first frame is already the right shape. A
    // new native player has no crop and no aspect of its own, so a fit that
    // needs neither costs no call.
    if (_videoGeometry != VlcVideoGeometry.none) await _sendVideoGeometry();
    // Ahead of the media as well, so its first line already has the look.
    if (_subtitleLook != null) await _resendSubtitleLook();
    _ensureNotDisposed();

    final pendingMediaSource = _pendingMediaSource;
    // Unless a setMedia sent it while the player was being made ready: a second
    // send would retire the player the first one opened (FORK.md 34).
    if (pendingMediaSource != null && _sourcesSent == sentAtAttach) {
      await _setMedia(
        _mediaForAttach(pendingMediaSource),
        autoPlay: _pendingAutoPlay,
      );
      _ensureNotDisposed();
    }
    await _flushPendingSubtitles();
  }

  /// Attaches this controller to a texture-backed player instance.
  @override
  @internal
  Future<int> attachTexturePlayer() async {
    _ensureNotDisposed();

    final existingTextureId = _textureId;
    if (_viewId != null && existingTextureId != null) {
      return existingTextureId;
    }

    final oldViewId = _viewId;
    _viewId = null;
    _textureId = null;
    await _eventsSubscription?.cancel();
    _eventsSubscription = null;
    _cancelPendingThrottledValue();
    _cancelStallTimer();
    if (oldViewId != null) {
      await _disposeNativeView(oldViewId);
    }
    _ensureNotDisposed();

    final attach = ++_attachGeneration;
    final response = await _invokeNativeMap('create', <String, Object?>{
      'options': options,
    });
    final viewId = (response?['viewId'] as num?)?.toInt();
    final textureId = (response?['textureId'] as num?)?.toInt();
    if (viewId == null || textureId == null) {
      throw StateError('vlc_player texture creation returned invalid data.');
    }
    if (_isDisposed) {
      await _disposeNativeView(viewId);
      throw StateError('The controller has been disposed.');
    }
    if (attach != _attachGeneration) {
      // Superseded while the native player was being made: nothing owns it.
      await _disposeNativeView(viewId);
      return textureId;
    }

    _viewId = viewId;
    final sentAtAttach = _sourcesSent;
    _seekRefusals = 0;
    _lastSequence = 0;
    _textureId = textureId;
    _eventsSubscription = EventChannel(
      'vlc_player/events/$viewId',
    ).receiveBroadcastStream().listen(_handleEvent, onError: _handleEventError);
    _ensureLifecycleListener();
    // Ahead of the media, so its first frame is already the right shape. A
    // new native player has no crop and no aspect of its own, so a fit that
    // needs neither costs no call.
    if (_videoGeometry != VlcVideoGeometry.none) await _sendVideoGeometry();
    // Ahead of the media as well, so its first line already has the look.
    if (_subtitleLook != null) await _resendSubtitleLook();
    _ensureNotDisposed();

    final pendingMediaSource = _pendingMediaSource;
    // Unless a setMedia sent it while the player was being made ready: a second
    // send would retire the player the first one opened (FORK.md 34).
    if (pendingMediaSource != null && _sourcesSent == sentAtAttach) {
      await _setMedia(
        _mediaForAttach(pendingMediaSource),
        autoPlay: _pendingAutoPlay,
      );
      _ensureNotDisposed();
    }
    await _flushPendingSubtitles();

    return textureId;
  }

  /// The media to hand a freshly attached player.
  ///
  /// A *re*-attach — the same controller picking up a surface that was torn
  /// down and rebuilt — would otherwise replay the source from the position it
  /// was originally opened at, dropping a viewer an hour into a film back at
  /// the start. The last position this controller saw is the honest answer.
  ///
  /// The configured start survives while nothing has played, which is the
  /// first attach: that is exactly when [VlcMediaSource.startPosition] carries
  /// a resume point and `value.position` is still zero.
  VlcMediaSource _mediaForAttach(VlcMediaSource source) {
    final position = value.position;
    // Only a session that actually reached playback can improve on the
    // configured start. Two traps this avoids: a viewer who rewound below
    // their resume point would otherwise be thrown forward to it again, and a
    // value sampled right after setMedia still carries the PREVIOUS media's
    // position because VlcPlayerValue merges into its predecessor.
    if (!_hasPlayedSinceMedia || position <= Duration.zero) {
      return source;
    }
    return VlcMediaSource(
      uri: source.uri,
      httpHeaders: source.httpHeaders,
      mediaOptions: source.mediaOptions,
      startPosition: position,
      isLive: source.isLive,
    );
  }

  /// Detaches and disposes the native player instance, if one is attached.
  ///
  /// [viewId] names the view the caller believes it owns; a mismatch is a
  /// no-op. Platform-view teardown is not ordered against creation — the
  /// outgoing element's `dispose` can run after the incoming one has already
  /// attached — so an unqualified call would null out a view that is playing.
  /// The texture path never learns the id, so it names the texture its create
  /// handed back in [textureId] instead: a create that answered after its
  /// widget was replaced has been disposed already, and the outgoing widget's
  /// detach must not take the replacement's player with it. Null for both
  /// means "whatever is attached".
  @override
  @internal
  Future<void> detach({int? viewId, int? textureId}) async {
    final attachedViewId = _viewId;
    if (viewId != null && attachedViewId != viewId) {
      return;
    }
    if (textureId != null && _textureId != textureId) {
      return;
    }
    _attachGeneration += 1;
    _viewId = null;
    _textureId = null;
    await _eventsSubscription?.cancel();
    _eventsSubscription = null;
    _cancelPendingThrottledValue();
    _cancelStallTimer();
    if (attachedViewId != null) {
      await _disposeNativeView(attachedViewId);
    }
  }

  /// Starts watching the application lifecycle, once.
  ///
  /// The directional callbacks rather than `onStateChange`, deliberately.
  /// `hidden` is passed through in both directions — leaving is
  /// inactive → hidden and returning is paused → hidden — so a raw state
  /// switch re-arms the background pause on the way back in and then resumes
  /// a player the viewer had stopped by hand. [AppLifecycleListener] already
  /// works out which way the app is travelling; taking its answer is cheaper
  /// than keeping a second copy of the state machine here.
  ///
  /// `onInactive` is deliberately absent. On Android it is what entering
  /// picture-in-picture looks like — the activity pauses while its window
  /// stays on screen and playing — and on desktop it is merely a window that
  /// lost focus.
  void _ensureLifecycleListener() {
    // AppLifecycleListener only reports transitions, so a controller attached
    // while the app is already away would never learn it. Seed from the
    // binding's current answer before subscribing.
    final current = WidgetsBinding.instance.lifecycleState;
    _backgrounded =
        current == AppLifecycleState.paused ||
        current == AppLifecycleState.hidden ||
        current == AppLifecycleState.detached;
    _lifecycleListener ??= AppLifecycleListener(
      onHide: _pauseForBackground,
      onPause: _pauseForBackground,
      onResume: _resumeFromBackground,
    );
  }

  void _pauseForBackground() {
    if (_isDisposed) return;
    // Recorded even when there is nothing to pause yet. Resolution can outlast
    // the app going away, and the open that follows has to know.
    _backgrounded = true;
    if (backgroundPolicy != VlcBackgroundPolicy.pause ||
        _pausedForBackground ||
        _viewId == null ||
        _pictureInPicturePending ||
        _pictureInPicture.value) {
      // The last two are the PiP hold: a window up, or a start in flight,
      // is a viewer still watching, and the film must not stop underneath
      // it. The pause is applied when the attempt ends instead (see
      // [_applyDeferredBackgroundPause]).
      return;
    }
    if (!value.isPlaying) {
      // An input still opening, or refilling after a seek, can't pause yet:
      // libVLC 3 stops one instead. The pause waits for its first playing.
      // An idle media asked to play that hasn't is opening too: the desktop
      // core's idle between the play and libVLC's own opening.
      final state = value.state;
      if (state == VlcPlaybackState.opening ||
          state == VlcPlaybackState.buffering ||
          (state == VlcPlaybackState.idle &&
              _playAskedSinceMedia &&
              !_hasPlayedSinceMedia)) {
        _pauseWhenItPlays = true;
      }
      return;
    }
    _pausedForBackground = true;
    _pauseRequests += 1;
    // Not the public pause(): that one is the user's, and clears the flag this
    // just set. Failures are swallowed because a player that has already gone
    // away has, for this purpose, done what was asked.
    unawaited(_invoke('pause').catchError((Object _) {}));
  }

  void _resumeFromBackground() {
    if (_isDisposed) return;
    _backgrounded = false;
    _pauseWhenItPlays = false;
    if (!_pausedForBackground) return;
    _pausedForBackground = false;
    if (_viewId == null) {
      return;
    }
    unawaited(_invoke('play').catchError((Object _) {}));
  }

  /// Mirrors a native audio interruption into this controller's bookkeeping.
  ///
  /// The engine is already paused, ducked or restored by the time this runs:
  /// audio focus has to be honoured in the instant it moves, not a channel
  /// round trip later. What the native side cannot answer is who owns the
  /// resume, because that depends on the app lifecycle and on
  /// [backgroundPolicy], both of which live here. So it reports, and this
  /// decides.
  ///
  /// Never through the public [play] and [pause]: those mean "the viewer
  /// decided" and clear [_pausedForBackground]. A phone call is not a
  /// decision the viewer made.
  void _applyInterruption(
    VlcAudioInterruption previous,
    VlcAudioInterruption next,
  ) {
    if (_isDisposed || previous == next) return;

    if (next != VlcAudioInterruption.none) {
      _pausedForAudioFocus = next == VlcAudioInterruption.focusLostTransient;
      return;
    }

    if (!_pausedForAudioFocus) return;
    _pausedForAudioFocus = false;
    if (_viewId == null) {
      return;
    }
    if (_backgrounded && backgroundPolicy == VlcBackgroundPolicy.pause) {
      // The call ended while the app is still away. Playing here is exactly
      // the noise nobody asked for, so the claim is handed to the background
      // policy and the trip back to the foreground settles it.
      _pausedForBackground = true;
      return;
    }
    unawaited(_invoke('play').catchError((Object _) {}));
  }

  @override
  Future<void> setMedia(
    VlcMediaSource source, {
    bool autoPlay = false,
    bool keepPicture = false,
  }) async {
    _ensureNotDisposed();
    // New media invalidates side-car subtitles queued for the old one.
    _pendingSubtitles.clear();
    final previousPlaylist = _playlist;
    final previousPlaylistIndex = _playlistIndex;
    final previousPlaylistAutoAdvance = _playlistAutoAdvance;
    final previousPlaylistLoopMode = _playlistLoopMode;
    final previousMediaSource = _pendingMediaSource;
    final previousAutoPlay = _pendingAutoPlay;
    _clearPlaylist();
    try {
      await _setMedia(source, autoPlay: autoPlay, keepPicture: keepPicture);
    } catch (_) {
      _playlist = previousPlaylist;
      _playlistIndex = previousPlaylistIndex;
      _playlistAutoAdvance = previousPlaylistAutoAdvance;
      _playlistLoopMode = previousPlaylistLoopMode;
      _pendingMediaSource = previousMediaSource;
      _pendingAutoPlay = previousAutoPlay;
      rethrow;
    }
  }

  @override
  void setDurationCap(Duration? cap) {
    // Measured off the main path, so it can land after the host let go.
    if (_isDisposed) return;
    _durationCap = cap;
    final pending = _pendingThrottledValue;
    if (pending != null) _pendingThrottledValue = _capDuration(pending);
    final capped = _capDuration(value);
    if (capped != value) value = capped;
  }

  @override
  @internal
  void setVideoGeometry(VlcVideoGeometry geometry) {
    if (_isDisposed || geometry == _videoGeometry) return;
    _videoGeometry = geometry;
    if (_viewId != null) unawaited(_sendVideoGeometry());
  }

  /// Best effort: a backend that does not know the call still plays, only
  /// with subtitles laid out for the whole picture.
  Future<void> _sendVideoGeometry() async {
    final viewId = _viewId;
    if (viewId == null) return;
    final geometry = _videoGeometry;
    try {
      await _invokeNative<void>('setVideoGeometry', <String, Object?>{
        'viewId': viewId,
        'crop': geometry.crop,
        'aspectRatio': geometry.aspectRatio,
      });
    } catch (error) {
      if (kDebugMode) debugPrint('vlc_player: setVideoGeometry failed: $error');
    }
  }

  VlcPlayerValue _capDuration(VlcPlayerValue next) {
    final cap = _durationCap;
    if (cap == null || next.duration <= cap) return next;
    return next.copyWith(duration: cap);
  }

  @override
  Future<void> setPlaylist(
    List<VlcMediaSource> sources, {
    int initialIndex = 0,
    bool autoPlay = false,
    bool autoAdvance = true,
    VlcPlaylistLoopMode loopMode = VlcPlaylistLoopMode.none,
  }) async {
    _ensureNotDisposed();
    if (sources.isEmpty) {
      throw ArgumentError.value(sources, 'sources', 'Must be non-empty.');
    }
    RangeError.checkValidIndex(initialIndex, sources, 'initialIndex');

    final previousPlaylist = _playlist;
    final previousPlaylistIndex = _playlistIndex;
    final previousPlaylistAutoAdvance = _playlistAutoAdvance;
    final previousPlaylistLoopMode = _playlistLoopMode;
    final previousMediaSource = _pendingMediaSource;
    final previousAutoPlay = _pendingAutoPlay;
    _playlist = List<VlcMediaSource>.unmodifiable(sources);
    _playlistIndex = initialIndex;
    _playlistAutoAdvance = autoAdvance;
    _playlistLoopMode = loopMode;
    try {
      await _setMedia(_playlist[initialIndex], autoPlay: autoPlay);
    } catch (_) {
      _playlist = previousPlaylist;
      _playlistIndex = previousPlaylistIndex;
      _playlistAutoAdvance = previousPlaylistAutoAdvance;
      _playlistLoopMode = previousPlaylistLoopMode;
      _pendingMediaSource = previousMediaSource;
      _pendingAutoPlay = previousAutoPlay;
      rethrow;
    }
  }

  @override
  Future<bool> next({bool autoPlay = true}) {
    return _moveInPlaylist(1, autoPlay: autoPlay);
  }

  @override
  Future<bool> previous({bool autoPlay = true}) {
    return _moveInPlaylist(-1, autoPlay: autoPlay);
  }

  @override
  Future<void> jumpTo(int index, {bool autoPlay = true}) async {
    _ensureActivePlaylist();
    RangeError.checkValidIndex(index, _playlist, 'index');
    if (index == _playlistIndex) {
      return;
    }
    await _loadPlaylistIndex(index, autoPlay: autoPlay);
  }

  @override
  Future<void> addToPlaylist(VlcMediaSource source) {
    return insertIntoPlaylist(_playlist.length, source);
  }

  @override
  Future<void> insertIntoPlaylist(int index, VlcMediaSource source) async {
    _ensureActivePlaylist();
    RangeError.checkValueInInterval(index, 0, _playlist.length, 'index');
    final currentIndex = _playlistIndex!;
    final nextPlaylist = <VlcMediaSource>[..._playlist]..insert(index, source);
    _playlist = List<VlcMediaSource>.unmodifiable(nextPlaylist);
    if (index <= currentIndex) {
      _playlistIndex = currentIndex + 1;
    }
  }

  @override
  Future<void> removeFromPlaylistAt(int index, {bool autoPlay = true}) async {
    _ensureActivePlaylist();
    RangeError.checkValidIndex(index, _playlist, 'index');

    final previousPlaylist = _playlist;
    final previousPlaylistIndex = _playlistIndex;
    final previousMediaSource = _pendingMediaSource;
    final previousAutoPlay = _pendingAutoPlay;
    final currentIndex = previousPlaylistIndex!;
    final nextPlaylist = <VlcMediaSource>[..._playlist]..removeAt(index);

    if (nextPlaylist.isEmpty) {
      await _stopIfAttached();
      _clearPlaylist();
      _pendingMediaSource = null;
      _pendingAutoPlay = false;
      return;
    }

    _playlist = List<VlcMediaSource>.unmodifiable(nextPlaylist);
    if (index < currentIndex) {
      _playlistIndex = currentIndex - 1;
      return;
    }
    if (index > currentIndex) {
      _playlistIndex = currentIndex;
      return;
    }

    final nextIndex = math.min(index, nextPlaylist.length - 1);
    _playlistIndex = nextIndex;
    try {
      await _setMedia(_playlist[nextIndex], autoPlay: autoPlay);
    } catch (_) {
      _playlist = previousPlaylist;
      _playlistIndex = previousPlaylistIndex;
      _pendingMediaSource = previousMediaSource;
      _pendingAutoPlay = previousAutoPlay;
      rethrow;
    }
  }

  @override
  Future<void> clearPlaylist() async {
    _ensureNotDisposed();
    if (_playlistIndex == null) {
      return;
    }
    await _stopIfAttached();
    _clearPlaylist();
    _pendingMediaSource = null;
    _pendingAutoPlay = false;
  }

  @override
  Future<void> shufflePlaylist({int? seed}) async {
    _ensureActivePlaylist();
    final currentSource = currentMediaSource;
    final random = seed == null ? math.Random() : math.Random(seed);
    final nextPlaylist = <VlcMediaSource>[..._playlist]..shuffle(random);
    _playlist = List<VlcMediaSource>.unmodifiable(nextPlaylist);
    _playlistIndex = currentSource == null
        ? 0
        : _playlist
              .indexOf(currentSource)
              .clamp(0, _playlist.length - 1)
              .toInt();
  }

  Future<bool> _moveInPlaylist(int delta, {required bool autoPlay}) async {
    _ensureActivePlaylist();
    final index = _playlistIndex!;

    final nextIndex = index + delta;
    if (nextIndex < 0 || nextIndex >= _playlist.length) {
      if (_playlistLoopMode != VlcPlaylistLoopMode.loopAll) {
        return false;
      }
      return _loadPlaylistIndex(
        nextIndex < 0 ? _playlist.length - 1 : 0,
        autoPlay: autoPlay,
      );
    }

    return _loadPlaylistIndex(nextIndex, autoPlay: autoPlay);
  }

  Future<bool> _loadPlaylistIndex(
    int nextIndex, {
    required bool autoPlay,
  }) async {
    final index = _playlistIndex;
    if (index == null) {
      throw StateError('No playlist has been set.');
    }

    _playlistIndex = nextIndex;
    final previousMediaSource = _pendingMediaSource;
    final previousAutoPlay = _pendingAutoPlay;
    try {
      await _setMedia(_playlist[nextIndex], autoPlay: autoPlay);
    } catch (_) {
      _playlistIndex = index;
      _pendingMediaSource = previousMediaSource;
      _pendingAutoPlay = previousAutoPlay;
      rethrow;
    }
    return true;
  }

  Future<void> _setMedia(
    VlcMediaSource source, {
    required bool autoPlay,
    bool keepPicture = false,
  }) async {
    _ensureNotDisposed();
    // A fresh media has not played yet, whatever the merged value still says.
    // The stall clock goes with it: the position it was watching belongs to
    // the media on its way out, and the opening buffer of the new one is the
    // startup spinner's job, not this one's.
    _hasPlayedSinceMedia = false;
    _playAskedSinceMedia = autoPlay;
    _cancelStallTimer();
    _pauseWhenItPlays = false;
    _lastMoveAt = null;
    _lastStep = null;
    // A seek's target belongs to the media it was asked of.
    _clearPendingSeek();
    _dropMergedSeek();
    // So does the clock's position: the new media starts where it is asked
    // to, and nothing the engine said about the last one applies to it.
    _playbackClock.restart(source.startPosition);
    // A measured length belongs to the media it was measured on.
    _durationCap = null;
    // Opening while the app is away must not start audio nobody can stop:
    // there is no notification and no lock-screen control behind this yet.
    // The policy's claim is staked here so the return trip resumes it.
    if (autoPlay &&
        _backgrounded &&
        backgroundPolicy == VlcBackgroundPolicy.pause) {
      autoPlay = false;
      _pausedForBackground = true;
      _pauseRequests += 1;
    }
    _pendingMediaSource = source;
    _pendingAutoPlay = autoPlay;

    final viewId = _viewId;
    if (viewId == null) {
      return;
    }

    // The join a live window is counted from: see [_placeInLiveWindow].
    _mediaSetAt = clock.now();
    _liveWindowFromJoin = null;
    _liveWindowAtJoin = null;
    _sourcesSent += 1;
    await _invokeNative<void>(
      'setSource',
      _sourceArguments(
        viewId,
        source,
        autoPlay: autoPlay,
        keepPicture: keepPicture,
      ),
    );
    _publishHeldStart(source, viewId: viewId, keepPicture: keepPicture);
  }

  /// Publishes a held reopen's start as [pendingSeekTarget], once the native
  /// side has answered `setSource`: every backend sends the new media's
  /// opening snapshot before it answers, so the published value already says
  /// whether the output holds. A start of 0, an output with nothing to hold,
  /// or a newer media or player since has nothing to wait for.
  ///
  /// Not a seek: the start went to the engine with the media, so there is no
  /// origin, no echo to wait for and nothing to send again, and the clock
  /// already stands at the start ([PlaybackClock.restart] above).
  void _publishHeldStart(
    VlcMediaSource source, {
    required int viewId,
    required bool keepPicture,
  }) {
    if (!keepPicture ||
        _isDisposed ||
        _viewId != viewId ||
        !identical(_pendingMediaSource, source) ||
        source.startPosition <= Duration.zero) {
      return;
    }
    final published = value;
    if (!published.isPictureHeld || !_canStillLand(published.state)) return;
    _heldStart = true;
    _pendingSeekTarget.value = source.startPosition;
  }

  /// When the media now playing went to the engine.
  DateTime? _mediaSetAt;

  /// Whether libVLC counts this live media's window from where it was
  /// joined; null until its first report with a window says.
  bool? _liveWindowFromJoin;

  /// The window's length in that first report: the edge then, in the
  /// stream's time counted from the join.
  Duration? _liveWindowAtJoin;

  /// [next] with its [VlcPlayerValue.positionFraction] worked out again for a
  /// live HLS window.
  ///
  /// libVLC 3.0.24 keeps a live HLS stream's time counted from the join, but
  /// measures the window from the start of the playlist it last read, which
  /// every refresh moves on. So its fraction is the time over the window's
  /// length: right at the join, running ahead of the window as the window
  /// moves on, and 0 once past 1. `set_position` does land in the window as
  /// it is now. The window's end - the live edge - runs on with the clock
  /// from where it was at the join, and its start is the end less its
  /// length: a full window moves on as fast as the clock, while one still
  /// filling up keeps its start (SkyStream's harness and suite, 2026-10-13:
  /// every reading within a second, and a window seek on a filling playlist
  /// landed 9.5 s off when the start was taken to move).
  ///
  /// Decided once per media, at the first report with a window: a fraction
  /// that is the time over the length is counted from the join; one that
  /// isn't - DASH's segments carry their own times - is taken as it is.
  VlcPlayerValue _placeInLiveWindow(VlcPlayerValue next) {
    final raw = next.positionFraction;
    final window = next.duration;
    final setAt = _mediaSetAt;
    if (!(_pendingMediaSource?.isLive ?? false) ||
        raw == null ||
        window <= Duration.zero ||
        setAt == null) {
      return next;
    }
    if (_liveWindowFromJoin == null && raw > 0) {
      _liveWindowFromJoin =
          (window * raw - next.position).abs() < const Duration(seconds: 1);
      _liveWindowAtJoin = window;
    }
    final atJoin = _liveWindowAtJoin;
    if (_liveWindowFromJoin != true || atJoin == null) return next;
    final edge = atJoin + clock.now().difference(setAt);
    final start = edge - window;
    final place =
        (next.position - start).inMilliseconds / window.inMilliseconds;
    return next.copyWith(positionFraction: place.clamp(0.0, 1.0).toDouble());
  }

  void _clearPlaylist() {
    _playlist = const <VlcMediaSource>[];
    _playlistIndex = null;
    _playlistAutoAdvance = false;
    _playlistLoopMode = VlcPlaylistLoopMode.none;
  }

  void _ensureActivePlaylist() {
    _ensureNotDisposed();
    if (_playlistIndex == null) {
      throw StateError('No playlist has been set.');
    }
  }

  // play/pause/stop are the deliberate-intent entry points — the on-screen
  // button, a remote, and in due course the media session and the audio-focus
  // handler. Any of them settles the background question on its own terms, so
  // they clear the policy's claim on the next resume: a viewer who pressed
  // play from a notification while the app was hidden has said what they want.
  @override
  Future<void> play() {
    // The background claim goes, because the viewer has settled the question
    // the trip back to the foreground would otherwise answer.
    //
    // The audio-focus claim stays. "Play" and "resume when the call ends" are
    // the same wish, and on Android a play made during a call is refused
    // outright — that refusal comes back as an interruption, and the delayed
    // grant that follows is the only thing that will ever start this playing.
    _pausedForBackground = false;
    _pauseWhenItPlays = false;
    _playAskedSinceMedia = true;
    return _invoke('play');
  }

  @override
  Future<void> pause() {
    _pauseRequests += 1;
    _clearAutomaticPauseClaims();
    // A paused player is not stalled, it is paused. The flag itself is cleared
    // by the paused snapshot when it arrives; what must not happen is the
    // timer firing in the gap before it and painting a spinner over a still
    // frame the viewer asked for.
    _cancelStallTimer();
    return _invoke('pause');
  }

  @override
  Future<void> stop() {
    _ensureNotDisposed();
    _pauseRequests += 1;
    _clearAutomaticPauseClaims();
    _cancelStallTimer();
    if (_viewId == null) {
      // Nothing to stop yet; what is queued for the player to come must not
      // start on its own when it does.
      _pendingAutoPlay = false;
      return Future<void>.value();
    }
    return _invoke('stop');
  }

  @override
  void notePictureInPictureImminent() {
    if (_isDisposed) return;
    // The same flag [startPictureInPicture] sets, so the background pause
    // (which can fire while the native start is still waiting on
    // `isPictureInPicturePossible`) sees the attempt and holds off. The
    // native side starts the window from `didEnterBackground`; the film
    // must not stop underneath it.
    _pictureInPicturePending = true;
  }

  @override
  Future<bool> startPictureInPicture({Rect? sourceRect}) async {
    // Set before the invoke, so the background pause (which can fire on the
    // lifecycle listener while this round trip is in flight) sees the
    // attempt and holds off: pausing now would stop the very playback the
    // PiP window is about to show.
    _pictureInPicturePending = true;
    final started = await _invokeFor<bool>(
      'startPictureInPicture',
      sourceRect == null
          ? null
          : <String, Object?>{
              'x': sourceRect.left,
              'y': sourceRect.top,
              'width': sourceRect.width,
              'height': sourceRect.height,
            },
    );
    if (started != true) {
      // The native side refused outright, so there is no event coming to
      // clear the flag - clear it here, and let the background policy have
      // the pause it was holding off, if the app is away.
      _pictureInPicturePending = false;
      _applyDeferredBackgroundPause();
    }
    return started ?? false;
  }

  @override
  Future<void> stopPictureInPicture() {
    // Settles the attempt too, not just an open window: a pending attempt
    // the screen cancelled (its watchdog, or the viewer coming straight
    // back) must not hold the background pause off forever.
    _pictureInPicturePending = false;
    _applyDeferredBackgroundPause();
    // Best effort: Android has no native stop (its PiP is an activity
    // mode), and a player that has already gone away has, for this purpose,
    // done what was asked. Failures are swallowed so a stop never surfaces
    // as an error far from the call site.
    return _invoke('stopPictureInPicture').catchError((Object _) {});
  }

  /// The background pause a PiP attempt held off, applied once the attempt is
  /// over.
  ///
  /// Only while the app is actually away: in the foreground there is nothing
  /// to pause for, and a PiP window the viewer closed by tapping it to come
  /// back must not pause the film they are looking at. A pause that lands
  /// just before the return is corrected by [_resumeFromBackground], which
  /// resumes exactly what this paused.
  void _applyDeferredBackgroundPause() {
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.hidden &&
        state != AppLifecycleState.detached) {
      return;
    }
    _pauseForBackground();
  }

  /// Drops every claim that would otherwise start playback on its own.
  ///
  /// Asking for silence answers both questions at once: a viewer who pauses
  /// while the app is hidden, or during a phone call, must not have the film
  /// started again by the return trip or by the end of the call.
  void _clearAutomaticPauseClaims() {
    _pausedForBackground = false;
    _pauseWhenItPlays = false;
    _playAskedSinceMedia = false;
    _pausedForAudioFocus = false;
  }

  int _seekRequests = 0;

  @override
  int get seekRequests => _seekRequests;

  int _pauseRequests = 0;

  @override
  int get pauseRequests => _pauseRequests;

  @override
  Future<void> seekTo(Duration position) {
    if (position.isNegative) {
      throw ArgumentError.value(position, 'position', 'Must be non-negative.');
    }
    return _seek(position, inWindow: false);
  }

  @override
  Future<void> seekToWindowFraction(double fraction) {
    if (!fraction.isFinite || fraction < 0 || fraction > 1) {
      throw ArgumentError.value(fraction, 'fraction', 'Must be within 0..1.');
    }
    final current = value;
    final here = current.positionFraction;
    if (here == null || current.duration <= Duration.zero) {
      throw StateError('The media reports no live window to seek in.');
    }
    // libVLC's live time and its window share one timeline, so the
    // fraction's place is a position the landing check and the clock follow.
    final target = current.position + current.duration * (fraction - here);
    return _seek(target.isNegative ? Duration.zero : target, inWindow: true);
  }

  Future<void> _seek(Duration position, {required bool inWindow}) {
    _seekRequests += 1;
    // After a rebuffer, the gap between a seek and the first frame at the new
    // position is the stall a viewer feels most, so the clock restarts here
    // rather than waiting for a snapshot to notice nothing moved.
    //
    // The comparison baseline moves to the target as well. Every backend
    // reports the requested time straight after a seek, before a frame has
    // been decoded there; measured against the OLD position that report looks
    // like movement and would disarm the timer, pushing the spinner out by a
    // whole extra delay. This is a private baseline for the clock, never the
    // published position - a viewer who scrubs still sees the engine's own
    // position, and the host's resume point never records a place the engine
    // did not reach.
    _cancelStallTimer();
    final origin = _pendingSeekTarget.value ?? value.position;
    // A held reopen's start becomes this seek's origin, and stops being one.
    _heldStart = false;
    // A committed seek gets its first second (spec 4): a flag raised by the
    // freeze before it comes down, and the clock above starts again. Not a
    // seek to where playback already is or is going: the player screen's
    // stall watchdog re-issues that to kick a stream that stopped, and the
    // picture stays frozen through it.
    if (position != origin) _clearStalled();
    if (_isRunning((_pendingThrottledValue ?? value).state)) {
      _lastNativePosition = position;
      _armStallTimer();
    }
    _seekOrigin = origin;
    _seekLastSeen = value.position;
    _seekMovesWithoutLanding = 0;
    _seekResent = false;
    _seekRefusalResends = 0;
    _seekInWindow = inWindow;
    _playbackClock.seek(position);
    _pendingSeekTarget.value = position;
    return _sendOrMergeSeek(position);
  }

  /// When a seek last went to the engine, and where to.
  ///
  /// A time rather than an open timer, so a seek on its own leaves nothing
  /// running behind it; a timer exists only while a merged seek waits.
  DateTime? _seekSentAt;
  Duration? _seekSentTarget;

  /// The latest seek asked for inside the window, and the timer that sends it
  /// once the seeks stop arriving.
  Duration? _mergedSeek;
  Timer? _mergedSeekTimer;

  /// The first seek of a burst goes at once; the rest move the target and
  /// restart the window. See [VlcPlayerController.seekMergeWindow].
  ///
  /// A merged seek completes as soon as it is taken. Its caller has nothing
  /// to wait for - the target is already published - and holding it for the
  /// window would hang it outright wherever time does not advance on its own.
  Future<void> _sendOrMergeSeek(Duration position) {
    const window = VlcPlayerController.seekMergeWindow;
    final now = clock.now();
    final sentAt = _seekSentAt;
    final inBurst =
        _mergedSeekTimer != null ||
        (sentAt != null && now.difference(sentAt) < window);
    if (!inBurst) {
      _seekSentAt = now;
      _seekSentTarget = position;
      return _sendSeek(position);
    }
    _mergedSeek = position;
    _mergedSeekTimer?.cancel();
    _mergedSeekTimer = Timer(window, _sendMergedSeek);
    return Future<void>.value();
  }

  void _sendMergedSeek() {
    _mergedSeekTimer = null;
    final target = _mergedSeek;
    _mergedSeek = null;
    // A burst that ends where it began - right, right, left - has nothing to
    // send: the engine already has that target, and a second seek there
    // would flush and refill for nothing.
    if (target == null || target == _seekSentTarget) return;
    // Sending restarts the window, so a burst that carries on straight after
    // is merged again rather than sent press by press.
    _seekSentAt = clock.now();
    _seekSentTarget = target;
    // The engine only has the seek from now, so the landing watcher's count
    // of reports that moved without arriving starts here, not at the press.
    _seekMovesWithoutLanding = 0;
    unawaited(_sendSeek(target));
  }

  /// Forgets a merged seek that has not gone out, and the last one that did:
  /// both belong to media that is going away, and the first seek on the next
  /// one goes at once.
  void _dropMergedSeek() {
    _mergedSeekTimer?.cancel();
    _mergedSeekTimer = null;
    _mergedSeek = null;
    _seekSentAt = null;
    _seekSentTarget = null;
  }

  /// Whether the seek on its way was asked for as a place in a live window
  /// ([seekToWindowFraction]), so it goes to the engine as a fraction.
  bool _seekInWindow = false;

  Future<void> _sendSeek(Duration position) {
    _seekEcho = _SeekEcho.awaited;
    final fraction = _seekInWindow ? _windowFractionOf(position) : null;
    if (fraction != null) {
      return _invoke('seekToFraction', <String, Object?>{'fraction': fraction});
    }
    return _invoke('seekTo', <String, Object?>{
      'position': position.inMilliseconds,
    });
  }

  /// [position] as a fraction of the live window, from the latest reading:
  /// a merged window seek, or one sent once more, goes from where playback
  /// is now.
  double? _windowFractionOf(Duration position) {
    final current = value;
    final here = current.positionFraction;
    final window = current.duration.inMilliseconds;
    if (here == null || window <= 0) return null;
    final fraction =
        here + (position - current.position).inMilliseconds / window;
    return fraction.clamp(0.0, 1.0).toDouble();
  }

  @override
  ValueListenable<Duration?> get pendingSeekTarget => _pendingSeekTarget;

  /// Clears [pendingSeekTarget] once the published value shows the engine has
  /// arrived, cannot arrive, or has carried on without the seek.
  void _watchSeekLanding() {
    final target = _pendingSeekTarget.value;
    if (target == null) return;
    final published = value;
    if (_heldStart) {
      // A held reopen's start lands with the hold's end - libVLC's first
      // time report, which comes only once playback runs from the start - or
      // never, when the media can no longer play.
      if (!published.isPictureHeld || !_canStillLand(published.state)) {
        _clearPendingSeek();
      }
      return;
    }
    final origin = _seekOrigin;
    if (origin == null) return;
    if (!_canStillLand(published.state)) {
      _clearPendingSeek();
      return;
    }
    if (_seekEcho != _SeekEcho.over &&
        published.position == _seekSentTarget &&
        (target - origin).abs() > _kSeekLandsShortBy) {
      // The backend repeating the time it was just given, which says nothing
      // about whether libVLC took the seek. See [_followSeekEcho]. A step of
      // 3 s or less lands on it as before: past the target, a short step back
      // has half its length to land in, less than playback moves on by the
      // engine's next report, which could not tell a refusal from a landing.
      _seekLastSeen = published.position;
      return;
    }
    if (_timeNotKnownYet(published.position, target)) return;
    if (_seekLanded(published.position, target: target, origin: origin)) {
      _clearPendingSeek();
      return;
    }
    final last = _seekLastSeen;
    _seekLastSeen = published.position;
    if (last == null || published.position == last) {
      // Still: the engine repositioning or refilling, which is what a seek on
      // its way looks like, or a report that changed something else. Neither
      // counts, and neither starts the count again: libVLC's time for an HLS
      // stream moves in steps of about a second, with reports in between that
      // change only the track list as a WebVTT track restarts, and a count
      // started again by each of those never reached the re-send.
      return;
    }
    _seekMovesWithoutLanding += 1;
    if (_seekMovesWithoutLanding < _kSeekIgnoredAfterMoves) return;
    if (!_seekResent) {
      // The engine carried on without the seek: libVLC 3 has been seen
      // dropping an HLS seek this way. Asked once more, from here, rather
      // than giving up the viewer's target; a second miss gives it up.
      _seekResent = true;
      _sendSeekAgain(from: published.position, target: target);
      return;
    }
    _clearPendingSeek();
  }

  /// Sends the seek on its way to the engine again, from where playback is.
  void _sendSeekAgain({required Duration from, required Duration target}) {
    _seekMovesWithoutLanding = 0;
    _seekOrigin = from;
    _seekSentAt = clock.now();
    _seekSentTarget = target;
    // A seek on its way again, so the clock waits at its target again: an
    // echo of the first send may have let it run on from where it was.
    _playbackClock.seek(target);
    unawaited(_sendSeek(target));
  }

  /// Whether the seek on its way has been sent a second time, after the
  /// engine carried on without it. See [_watchSeekLanding].
  bool _seekResent = false;

  /// libVLC's refusals as the native player last counted them; see
  /// [_followSeekRefusal]. A new native player counts from 0 again.
  int _seekRefusals = 0;

  /// The number of the last snapshot applied, on the desktop plugins that
  /// number them (FORK.md 37); 0 when none has come. An older one arriving
  /// later is not applied: Windows delivers a snapshot sent from libVLC's
  /// event thread after one sent at once from the platform thread.
  int _lastSequence = 0;

  /// How many times the seek on its way was sent again for a refusal.
  int _seekRefusalResends = 0;

  /// Where the reports since the last seek was sent stand against its echo.
  /// See [_followSeekEcho].
  _SeekEcho _seekEcho = _SeekEcho.over;

  /// Follows the reports after a seek is sent for its echo: the first one at
  /// exactly the time sent, which every backend makes before libVLC has
  /// taken the seek (VLCKit as the time is set).
  ///
  /// libVLC 3 can still refuse the seek. An adaptive stream with a track
  /// restarting is "not seekable" for that moment - an HLS WebVTT track
  /// restarts at every segment, and as it is switched on - and a refusal
  /// flushes and refills all the same, so the time can come back again while
  /// it buffers. Only a report from somewhere else after the echo is the
  /// engine's own word; until then a report at the time sent lands nothing.
  /// A report from before the seek, still on its way, comes before the echo
  /// and changes nothing.
  void _followSeekEcho(Duration position) {
    final sent = _seekSentTarget;
    if (sent == null) return;
    _seekEcho = switch (_seekEcho) {
      _SeekEcho.awaited when position == sent => _SeekEcho.seen,
      _SeekEcho.seen when position != sent => _SeekEcho.over,
      final state => state,
    };
  }

  /// Sends the seek on its way again the moment libVLC says it refused it.
  ///
  /// An adaptive stream with a track restarting answers a seek "not
  /// seekable", and libVLC 3 logs `INPUT_CONTROL_SET_TIME ... failed or not
  /// possible` with no event. The backends that can read libVLC's log
  /// (Darwin, Windows, Linux) count those lines and send the refused time,
  /// so the seek goes again about a second after it was sent, rather than
  /// after [_watchSeekLanding]'s dozen moves: about five seconds on an HLS
  /// stream with WebVTT subtitles (SkyStream's QoE suite, 2026-10-13).
  /// libvlc-android exposes no log, so Android keeps the dozen.
  void _followSeekRefusal(
    Map<Object?, Object?> event, {
    required Duration position,
  }) {
    final refusals = event['seekRefusals'];
    if (refusals is! int || refusals <= _seekRefusals) return;
    _seekRefusals = refusals;
    final refusedAt = event['seekRefusedAt'];
    final target = _pendingSeekTarget.value;
    final sent = _seekSentTarget;
    if (refusedAt is! int || target == null || sent == null) return;
    if ((refusedAt - sent.inMilliseconds).abs() > _kSeekRefusalMatchMs) {
      return;
    }
    if (_seekRefusalResends >= _kSeekRefusalResends) return;
    _seekRefusalResends += 1;
    // libVLC did not move, so the seek still leaves from where it left. The
    // position now can be the backend's echo of the target - VLCKit reports
    // the time it was given until libVLC's next report - and an origin at the
    // target would make the re-send's own echo read as its landing.
    _sendSeekAgain(from: _seekOrigin ?? position, target: target);
  }

  /// Whether [position] shows the engine has taken the seek from [origin] to
  /// [target]: it is at the target - a little short allowed, because seeks
  /// land on a keyframe or a segment boundary - or it has gone past the
  /// target in the direction of the seek.
  ///
  /// Anything else holds, and that is what matters in a chain of D-pad steps:
  /// the report of an earlier step landing is short of this one's target, not
  /// at it.
  static bool _seekLanded(
    Duration position, {
    required Duration target,
    required Duration origin,
  }) {
    final asked = target - origin;
    // Short by at most half the step, so a report from where a short step
    // set out cannot pass for its landing.
    final half = asked.abs() ~/ 2;
    final shortBy = half < _kSeekLandsShortBy ? half : _kSeekLandsShortBy;
    final early = asked.isNegative ? _kSeekLandsLongBy : shortBy;
    final late = asked.isNegative ? shortBy : _kSeekLandsLongBy;
    if (position >= target - early && position <= target + late) return true;
    if (asked == Duration.zero) return false;
    final travelled = position - origin;
    return travelled.isNegative == asked.isNegative &&
        travelled.abs() >= asked.abs();
  }

  /// Whether [next] ends the playback clock's wait at a seek's target: the
  /// engine has arrived there, cannot any more, or there is no seek on its
  /// way.
  ///
  /// Judged on every snapshot rather than on the published value that
  /// [_watchSeekLanding] reads, so a landing held back by the event throttle
  /// does not hold the clock with it.
  bool _seekSettledBy(VlcPlayerValue next) {
    final target = _pendingSeekTarget.value;
    final origin = _seekOrigin;
    if (target == null || origin == null) return true;
    if (!_canStillLand(next.state)) return true;
    return !_timeNotKnownYet(next.position, target) &&
        _seekLanded(next.position, target: target, origin: origin);
  }

  /// Whether [position] is libVLC saying nothing yet about where a seek to
  /// [target] went: an adaptive stream's time reads 0 for half a second or
  /// so after a seek, while libVLC finds it again (SkyStream's harness,
  /// 2026-10-13), and 0 is far past a step back's target in the step's
  /// direction. A target this close to the start can land at 0.
  static bool _timeNotKnownYet(Duration position, Duration target) =>
      position == Duration.zero && target > _kSeekLandsShortBy;

  /// A paused seek still lands; a stopped, ended, errored or idle engine
  /// never will.
  static bool _canStillLand(VlcPlaybackState state) {
    return switch (state) {
      VlcPlaybackState.opening ||
      VlcPlaybackState.buffering ||
      VlcPlaybackState.playing ||
      VlcPlaybackState.paused => true,
      VlcPlaybackState.idle ||
      VlcPlaybackState.stopped ||
      VlcPlaybackState.ended ||
      VlcPlaybackState.error => false,
    };
  }

  void _clearPendingSeek() {
    _seekOrigin = null;
    _seekLastSeen = null;
    _seekMovesWithoutLanding = 0;
    _seekResent = false;
    _seekRefusalResends = 0;
    _seekInWindow = false;
    _heldStart = false;
    _pendingSeekTarget.value = null;
    // Nothing is on its way any more, so the clock stops waiting for it too.
    _playbackClock.endSeek();
  }

  @override
  Future<void> setVolume(int volume) {
    return _invoke('setVolume', <String, Object?>{
      'volume': volume.clamp(0, 200),
    });
  }

  @override
  Future<void> setPlaybackSpeed(double speed) {
    if (!speed.isFinite || speed <= 0) {
      throw ArgumentError.value(
        speed,
        'speed',
        'Must be finite and greater than zero.',
      );
    }
    return _invoke('setPlaybackSpeed', <String, Object?>{'speed': speed});
  }

  @override
  Future<void> setFit(VlcVideoFit fit) {
    return _invoke('setFit', <String, Object?>{'fit': fit.name});
  }

  @override
  Future<void> setAudioDelay(Duration delay) {
    return _invoke('setAudioDelay', <String, Object?>{
      'delay': delay.inMicroseconds,
    });
  }

  @override
  Future<void> setSubtitleDelay(Duration delay) {
    return _invoke('setSubtitleDelay', <String, Object?>{
      'delay': delay.inMicroseconds,
    });
  }

  @override
  Future<bool> setSubtitleLook(VlcSubtitleLook look) async {
    _ensureNotDisposed();
    _subtitleLook = look;
    if (_viewId == null) return false;
    return _sendSubtitleLook();
  }

  Future<bool> _sendSubtitleLook() async {
    final look = _subtitleLook;
    if (look == null) return false;
    try {
      return await _invokeFor<bool>('setSubtitleLook', look.toArguments()) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Best effort: a look the engine cannot take leaves the lines as they were.
  Future<void> _resendSubtitleLook() async {
    if (_viewId == null) return;
    try {
      await _sendSubtitleLook();
    } catch (error) {
      if (kDebugMode) debugPrint('vlc_player: setSubtitleLook failed: $error');
    }
  }

  @override
  Future<Uint8List> takeSnapshot({int? width, int? height}) async {
    if (width != null && width <= 0) {
      throw ArgumentError.value(width, 'width', 'Must be positive.');
    }
    if (height != null && height <= 0) {
      throw ArgumentError.value(height, 'height', 'Must be positive.');
    }
    final data = await _invokeFor<Uint8List>('takeSnapshot', <String, Object?>{
      'width': ?width,
      'height': ?height,
    });
    if (data == null || data.isEmpty) {
      throw StateError('vlc_player snapshot returned no image data.');
    }
    return data;
  }

  @override
  Future<List<VlcTrackDescription>> getAudioTracks() async {
    final tracks = await _invokeFor<List<Object?>>('getAudioTracks');
    return _trackDescriptionsFrom(tracks);
  }

  @override
  Future<void> setAudioTrack(int id) {
    if (id < 0) {
      throw ArgumentError.value(id, 'id', 'Must be non-negative.');
    }
    return _invoke('setAudioTrack', <String, Object?>{'id': id});
  }

  @override
  Future<List<VlcTrackDescription>> getSubtitleTracks() async {
    final tracks = await _invokeFor<List<Object?>>('getSubtitleTracks');
    return _trackDescriptionsFrom(tracks);
  }

  @override
  Future<void> setSubtitleTrack(int id) {
    if (id < 0) {
      throw ArgumentError.value(id, 'id', 'Must be non-negative.');
    }
    return _invoke('setSubtitleTrack', <String, Object?>{'id': id});
  }

  @override
  Future<void> disableSubtitle() => _invoke('disableSubtitle');

  @override
  Future<void> addSubtitle(Uri uri) async {
    _ensureNotDisposed();
    final value = uri.toString();
    if (value.isEmpty) {
      throw ArgumentError.value(uri, 'uri', 'Must be non-empty.');
    }
    if (_viewId == null) {
      _pendingSubtitles.add(uri);
      return;
    }
    await _invoke('addSubtitle', <String, Object?>{'uri': value});
  }

  /// Applies subtitles queued before attachment, in the order requested.
  ///
  /// A failure here must not take down attachment: the video is playable
  /// without a side-car subtitle, so a bad URI is dropped rather than thrown.
  Future<void> _flushPendingSubtitles() async {
    if (_pendingSubtitles.isEmpty || _viewId == null) {
      return;
    }
    final pending = List<Uri>.of(_pendingSubtitles);
    _pendingSubtitles.clear();
    for (final uri in pending) {
      if (_isDisposed || _viewId == null) {
        return;
      }
      try {
        await _invoke('addSubtitle', <String, Object?>{'uri': uri.toString()});
      } catch (_) {
        // Ignored on purpose - see above.
      }
    }
  }

  @override
  Future<VlcMediaInfo> getMediaInfo() async {
    final info = await _invokeFor<Map<Object?, Object?>>('getMediaInfo');
    return VlcMediaInfo.fromMap(info ?? const <Object?, Object?>{});
  }

  @override
  Future<VlcMediaStats> getMediaStats() async {
    final stats = await _invokeFor<Map<Object?, Object?>>('getMediaStats');
    return VlcMediaStats.fromMap(stats ?? const <Object?, Object?>{});
  }

  Future<void> _invoke(String method, [Map<String, Object?>? arguments]) {
    return _invokeFor<void>(method, arguments);
  }

  Future<T?> _invokeFor<T>(String method, [Map<String, Object?>? arguments]) {
    return _invokeNative<T>(method, _attachedArguments(arguments));
  }

  Future<void> _stopIfAttached() {
    if (_viewId == null) {
      return Future<void>.value();
    }
    // The host's own stop, through its playlist: see [pauseRequests].
    _pauseRequests += 1;
    return _invoke('stop');
  }

  Map<String, Object?> _attachedArguments([Map<String, Object?>? arguments]) {
    _ensureNotDisposed();
    final viewId = _viewId;
    if (viewId == null) {
      throw StateError('The controller is not attached to a VlcPlayer.');
    }

    return <String, Object?>{'viewId': viewId, ...?arguments};
  }

  /// Builds every `setSource` payload, so headers can never desync from the
  /// media they belong to.
  ///
  /// HTTP headers are translated to libVLC options **here**, once, rather than
  /// in each of the five native backends. libVLC can transmit only User-Agent
  /// and Referer (see vlc_http_headers.dart); the natives are handed the raw
  /// map as well, but only for mechanisms that are genuinely platform-specific.
  Map<String, Object?> _sourceArguments(
    int viewId,
    VlcMediaSource source, {
    required bool autoPlay,
    bool keepPicture = false,
  }) {
    final headerOptions = vlcHeaderOptions(source.httpHeaders);
    final mediaOptions = <String>[...headerOptions, ...source.mediaOptions];

    assert(() {
      final dropped = unsupportedVlcHeaders(source.httpHeaders);
      if (dropped.isNotEmpty) {
        debugPrint(
          'vlc_player: libVLC cannot send these headers, so they were dropped '
          'for ${source.uri}: ${dropped.join(', ')}. Proxy the media and '
          'inject them upstream if the server requires them.',
        );
      }
      return true;
    }());

    return <String, Object?>{
      'viewId': viewId,
      'uri': source.uri.toString(),
      'autoPlay': autoPlay,
      if (keepPicture) 'keepPicture': true,
      'httpHeaders': source.httpHeaders,
      if (mediaOptions.isNotEmpty) 'mediaOptions': mediaOptions,
      if (source.startPosition > Duration.zero)
        'startPosition': source.startPosition.inMilliseconds,
    };
  }

  Future<T?> _invokeNative<T>(String method, Map<String, Object?> arguments) {
    return _mapPlatformException(
      () => _methodChannel.invokeMethod<T>(method, arguments),
    );
  }

  Future<Map<String, Object?>?> _invokeNativeMap(
    String method,
    Map<String, Object?> arguments,
  ) {
    return _mapPlatformException(
      () => _methodChannel.invokeMapMethod<String, Object?>(method, arguments),
    );
  }

  static Future<T> _mapPlatformException<T>(
    Future<T> Function() operation,
  ) async {
    try {
      return await operation();
    } on PlatformException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        VlcPlayerException.fromPlatformException(error),
        stackTrace,
      );
    }
  }

  static List<VlcTrackDescription> _trackDescriptionsFrom(Object? value) {
    if (value is! Iterable) {
      return const <VlcTrackDescription>[];
    }
    return value
        .whereType<Map>()
        .map(
          (track) =>
              VlcTrackDescription.fromMap(track.cast<Object?, Object?>()),
        )
        .toList(growable: false);
  }

  Future<void> _disposeNativeView(int viewId) {
    return _methodChannel.invokeMethod<void>('dispose', <String, Object?>{
      'viewId': viewId,
    });
  }

  void _handleEvent(Object? event) {
    if (_isDisposed) {
      return;
    }
    final sequence = event is Map ? event['sequence'] : null;
    if (sequence is int) {
      if (sequence < _lastSequence) return;
      _lastSequence = sequence;
    }
    // A PiP-only event carries no snapshot: it says only whether the iOS
    // picture-in-picture window opened or closed. Running it through
    // [VlcPlayerValue.fromEvent] would read its absent keys as a cleared
    // hold and a cleared error, so it owns its notifier instead — and a
    // snapshot that happens to carry the key updates the notifier on its
    // way through.
    if (event is Map && event['pictureInPicture'] is bool) {
      final inPip = event['pictureInPicture'] as bool;
      // The attempt's answer, whatever it is: the window opened, or it
      // failed to. A window that closed while the app is away leaves the
      // background pause owing - the pause was held for the attempt, and
      // the attempt is over - so the policy is applied if the app is still
      // away (see [_applyDeferredBackgroundPause]).
      _pictureInPicturePending = false;
      _pictureInPicture.value = inPip;
      // A failed start carries its reason (`pipError`) and whether a start
      // would be accepted right now (`pipPossible`): the debug line the
      // player shows when a start fails. A window that opened clears the
      // failure.
      final pipError = event['pipError'];
      if (pipError is String) _lastPipError = pipError;
      final pipPossible = event['pipPossible'];
      if (pipPossible is bool) _lastPipPossible = pipPossible;
      if (inPip) _lastPipError = null;
      if (!inPip) _applyDeferredBackgroundPause();
      if (!event.containsKey('state')) {
        return;
      }
    }
    final previousValue = _pendingThrottledValue ?? value;
    final nextValue = _observeStall(
      _placeInLiveWindow(
        _capDuration(VlcPlayerValue.fromEvent(event, previousValue)),
      ),
    );
    // Every snapshot, ahead of the throttle: the clock runs on from the
    // freshest report, and a throttled one is up to an interval old. The
    // echo is followed here too, so a published value is judged against the
    // reports that came before it.
    _followSeekEcho(nextValue.position);
    _playbackClock.report(nextValue, seekSettled: _seekSettledBy(nextValue));
    if (event is Map) _followSeekRefusal(event, position: nextValue.position);
    _setValueFromEvent(previousValue, nextValue);
    if (_pauseWhenItPlays && nextValue.isPlaying) {
      _pauseWhenItPlays = false;
      if (_backgrounded) _pauseForBackground();
    }
    if (nextValue.videoSize != null &&
        nextValue.videoSize != previousValue.videoSize &&
        (_subtitleLook?.raise ?? 0) > 0) {
      unawaited(_resendSubtitleLook());
    }
    _applyInterruption(previousValue.interruption, nextValue.interruption);
    if (_playlistAutoAdvance &&
        previousValue.state != VlcPlaybackState.ended &&
        nextValue.state == VlcPlaybackState.ended) {
      if (_playlistLoopMode == VlcPlaylistLoopMode.loopOne) {
        final current = _pendingMediaSource;
        if (current != null) {
          _runAutoAdvance(_setMedia(current, autoPlay: true));
        }
      } else if (hasNext || _playlistLoopMode == VlcPlaylistLoopMode.loopAll) {
        _runAutoAdvance(next().then<void>((_) {}));
      }
    }
  }

  void _runAutoAdvance(Future<void> operation) {
    unawaited(
      operation.catchError((Object error, StackTrace stackTrace) {
        _handleAutoAdvanceError(error);
      }),
    );
  }

  void _handleAutoAdvanceError(Object error) {
    if (_isDisposed) {
      return;
    }
    final playerError = error is VlcPlayerException
        ? error.error
        : error is PlatformException
        ? VlcPlayerError.fromPlatformException(error)
        : VlcPlayerError(
            code: VlcPlayerErrorCode.playbackError,
            message: error.toString(),
          );
    _setPlayerError(playerError);
  }

  void _handleEventError(Object error) {
    if (_isDisposed) {
      return;
    }
    final playerError = error is PlatformException
        ? VlcPlayerError.fromPlatformException(error)
        : VlcPlayerError(
            code: VlcPlayerErrorCode.eventChannelError,
            message: error.toString(),
          );
    _setPlayerError(playerError);
  }

  void _setPlayerError(VlcPlayerError playerError) {
    _cancelPendingThrottledValue();
    _cancelStallTimer();
    final failed = value.copyWith(
      state: VlcPlaybackState.error,
      error: playerError,
      errorDescription: playerError.message,
    );
    // Not a native snapshot, but the clock has to stop all the same.
    _playbackClock.report(failed, seekSettled: true);
    value = failed;
  }

  void _setValueFromEvent(
    VlcPlayerValue previousValue,
    VlcPlayerValue nextValue,
  ) {
    if (nextValue == previousValue) {
      return;
    }
    if (!_shouldThrottleEvent(previousValue, nextValue)) {
      _setValueImmediately(nextValue);
      return;
    }
    _pendingThrottledValue = nextValue;
    _eventThrottleTimer ??= Timer(eventThrottleInterval!, _flushThrottledValue);
  }

  bool _shouldThrottleEvent(
    VlcPlayerValue previousValue,
    VlcPlayerValue nextValue,
  ) {
    final interval = eventThrottleInterval;
    if (interval == null || interval.inMicroseconds == 0) {
      return false;
    }
    return previousValue.state == nextValue.state &&
        previousValue.volume == nextValue.volume &&
        previousValue.playbackSpeed == nextValue.playbackSpeed &&
        previousValue.audioDelay == nextValue.audioDelay &&
        previousValue.subtitleDelay == nextValue.subtitleDelay &&
        previousValue.isReady == nextValue.isReady &&
        previousValue.isSeekable == nextValue.isSeekable &&
        previousValue.isLive == nextValue.isLive &&
        // A stall flag changing is the whole event, not a progress tick that
        // can wait for the next flush.
        previousValue.isStalled == nextValue.isStalled &&
        // Likewise a track switch or a track list changing shape: the panel
        // that asked for it is waiting on this exact value, and it is not a
        // progress tick.
        previousValue.activeAudioTrackId == nextValue.activeAudioTrackId &&
        previousValue.activeSubtitleTrackId ==
            nextValue.activeSubtitleTrackId &&
        previousValue.trackRevision == nextValue.trackRevision &&
        previousValue.interruption == nextValue.interruption &&
        previousValue.videoSize == nextValue.videoSize &&
        // A hold starting or ending: the screen keeps its controls over the
        // held picture, and lays the new one out, by this (FORK.md 33).
        previousValue.isPictureHeld == nextValue.isPictureHeld &&
        previousValue.error == nextValue.error &&
        previousValue.errorDescription == nextValue.errorDescription;
  }

  void _setValueImmediately(VlcPlayerValue nextValue) {
    _cancelPendingThrottledValue();
    value = nextValue;
  }

  void _flushThrottledValue() {
    final pendingValue = _pendingThrottledValue;
    _eventThrottleTimer = null;
    _pendingThrottledValue = null;
    if (!_isDisposed && pendingValue != null) {
      value = pendingValue;
    }
  }

  void _cancelPendingThrottledValue() {
    _eventThrottleTimer?.cancel();
    _eventThrottleTimer = null;
    _pendingThrottledValue = null;
  }

  /// Reads the position clock in [next] and returns what should be published.
  ///
  /// Runs on every native snapshot, before the equality and throttle gates,
  /// because a snapshot identical to the last one is precisely the evidence a
  /// stall is made of - it must arm the timer even though it publishes
  /// nothing.
  ///
  /// "Moved" rather than "advanced", deliberately: a seek backwards lands the
  /// clock below where it was and a later snapshot from there is progress. A
  /// strictly-greater test would hold the spinner up until playback overtook
  /// the pre-seek position.
  VlcPlayerValue _observeStall(VlcPlayerValue next) {
    final moved = _lastNativePosition != next.position;
    _lastNativePosition = next.position;
    // Set here rather than on publish so that throttled progress ticks count:
    // under an event throttle the first snapshot with a real position is
    // usually coalesced, and a flag that only immediate publishes could set
    // would leave a re-attach unable to trust the live position and this
    // clock unable to arm at all.
    if (next.position > Duration.zero) _hasPlayedSinceMedia = true;

    if (!_isRunning(next.state)) {
      // Paused, stopped, ended, error, opening: none of these is a stall, and
      // the flag clears in this same publish rather than a frame later.
      _cancelStallTimer();
      return next.isStalled ? next.copyWith(isStalled: false) : next;
    }
    if (moved) {
      final now = clock.now();
      final last = _lastMoveAt;
      _lastStep = last == null ? null : now.difference(last);
      _lastMoveAt = now;
      // Movement clears the flag - and RESTARTS the countdown rather than
      // cancelling it. Every native except Android suppresses a snapshot
      // identical to the last one it sent, so a real freeze does not arrive
      // as a repeated position: it arrives as silence. The only way to see
      // that silence is a deadline measured from the last snapshot that
      // moved. Gated the same way as the frozen path: a clock that has never
      // run - a live stream, the pre-first-frame buffer - is not stalling.
      if (_hasPlayedSinceMedia) {
        _restartStallTimer();
      } else {
        _cancelStallTimer();
      }
      return next.isStalled ? next.copyWith(isStalled: false) : next;
    }
    // A clock that has not moved yet is not a stall: a live stream may never
    // report movement, and before the first frame the startup buffer owns the
    // spinner. Only a clock that once ran and has now stopped qualifies.
    if (_hasPlayedSinceMedia) {
      _armStallTimer();
    }
    return next;
  }

  /// Whether [state] claims the engine is producing frames, which is the only
  /// claim a frozen clock can contradict.
  static bool _isRunning(VlcPlaybackState state) {
    return state == VlcPlaybackState.playing ||
        state == VlcPlaybackState.buffering;
  }

  /// Starts the countdown if it is not already running. Never restarts it: on
  /// a native that repeats a frozen position (Android), the stall began at the
  /// first frozen snapshot, not the latest.
  void _armStallTimer() {
    _stallTimer ??= Timer(_stallDelay, _markStalled);
  }

  /// Restarts the countdown from now. Used on every moved snapshot, so that
  /// the deadline always means "nothing has moved for stallIndicatorDelay" -
  /// which is what a stall looks like on the natives that go silent.
  void _restartStallTimer() {
    _stallTimer?.cancel();
    _stallTimer = Timer(_stallDelay, _markStalled);
  }

  void _cancelStallTimer() {
    _stallTimer?.cancel();
    _stallTimer = null;
  }

  void _markStalled() {
    _stallTimer = null;
    if (_isDisposed) {
      return;
    }
    // Both copies, or the next throttle flush overwrites the flag with the
    // pre-stall snapshot it was holding.
    final pending = _pendingThrottledValue;
    if (pending != null) {
      _pendingThrottledValue = pending.copyWith(isStalled: true);
    }
    if (!value.isStalled) {
      value = value.copyWith(isStalled: true);
    }
  }

  /// Takes the stall flag down in both copies, so the next throttle flush
  /// cannot put the stalled value back.
  void _clearStalled() {
    final pending = _pendingThrottledValue;
    if (pending != null && pending.isStalled) {
      _pendingThrottledValue = pending.copyWith(isStalled: false);
    }
    if (value.isStalled) {
      value = value.copyWith(isStalled: false);
    }
  }

  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw StateError('The controller has been disposed.');
    }
  }

  /// Disposes the controller and releases the attached native player.
  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    final viewId = _viewId;
    _viewId = null;
    _textureId = null;
    _eventsSubscription?.cancel();
    _eventsSubscription = null;
    _cancelPendingThrottledValue();
    _cancelStallTimer();
    _clearPendingSeek();
    _dropMergedSeek();
    _pendingSeekTarget.dispose();
    _pictureInPicture.dispose();
    _playbackClock.dispose();
    if (viewId != null) {
      unawaited(_disposeNativeView(viewId));
    }
    super.dispose();
  }
}
