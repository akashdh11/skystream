import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vlc_player/vlc_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/network/http_defaults.dart';
import 'vlc_player_controls.dart';

/// Phase 5 of docs/PLAYER_MIGRATION.md: the smallest thing that plays a video
/// on the VLC engine.
///
/// Reached only when [VlcEngineEnabled] is on. The media_kit / video_view
/// screen is untouched and remains the default, so this cannot regress
/// shipping playback.
///
/// Phase 6 added audio/subtitle track selection and subtitle delay, all owned
/// by the engine — see [VlcTrackSheet].
///
/// STILL DELIBERATELY OUT OF SCOPE, and not stubbed either — a missing feature
/// should be obviously missing rather than half-present: live, DRM, torrent,
/// PiP, skip segments, next-episode, gestures, playback speed and volume boost.
/// Phase 7 takes live and then the long tail.
///
/// It is also **read-only against watch history and the scrobblers**. The old
/// controller's saveProgress() branches on `state.useExoPlayer`, which is false
/// on this path, so it would read the idle media_kit handle and persist a
/// position of zero — and markWatched pushes irreversible writes to
/// Trakt/Simkl/MAL. Progress writing needs a validated duration source and is
/// still outstanding.
class VlcPlayerScreen extends ConsumerStatefulWidget {
  const VlcPlayerScreen({
    required this.item,
    required this.videoUrl,
    this.episode,
    this.headers,
    this.subtitles,
    super.key,
  });

  final MultimediaItem item;
  final String videoUrl;
  final Episode? episode;
  final Map<String, String>? headers;

  /// Subtitles the source advertised. Handed straight to the engine as real
  /// tracks — see [VlcTrackSheet] for why there is deliberately no second list
  /// and no `external:` id scheme.
  final List<SubtitleFile>? subtitles;

  @override
  ConsumerState<VlcPlayerScreen> createState() => _VlcPlayerScreenState();
}

class _VlcPlayerScreenState extends ConsumerState<VlcPlayerScreen> {
  /// The screen owns the controller, and its lifetime is exactly this State's.
  ///
  /// This is the ownership the migration plan calls for and the old player got
  /// wrong: PlayerController is ref.keepAlive()'d while PlayerScreen owns and
  /// disposes the actual Player, which is why per-session state leaked across
  /// episodes there. Starting correct is free; retrofitting it is not.
  late final VlcPlayerController _controller;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controller = VlcPlayerController(
      autoPlay: true,
      config: const VlcPlayerConfig(
        network: VlcNetworkConfig(
          // Matches what the mpv path asks for on VOD. Live tuning is Phase 7.
          networkCaching: 3000,
          userAgent: kDefaultBrowserUserAgent,
        ),
      ),
    );
    _controller.setMedia(
      VlcMediaSource(
        uri: Uri.parse(widget.videoUrl),
        httpHeaders: _playbackHeaders(),
      ),
      autoPlay: true,
    );

    // Register external subtitles with the engine rather than tracking them
    // ourselves. VLC turns each into an ordinary subtitle track, so
    // getSubtitleTracks() returns one list containing both embedded and
    // external entries, with one kind of id.
    for (final sub in widget.subtitles ?? const <SubtitleFile>[]) {
      final uri = Uri.tryParse(sub.url);
      if (uri != null) unawaited(_controller.addSubtitle(uri));
    }
  }

  /// Mirrors the old controller's _buildPlaybackHeaders: pass what the plugin
  /// gave us, and supply a browser User-Agent when it did not, because many
  /// CDNs reject libVLC's default and the resolve/playback identities must
  /// match.
  Map<String, String> _playbackHeaders() {
    final headers = <String, String>{...?widget.headers};
    final hasUa = headers.keys.any((k) => k.toLowerCase() == 'user-agent');
    if (!hasUa) headers['User-Agent'] = kDefaultBrowserUserAgent;
    return headers;
  }

  @override
  void dispose() {
    _controller.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          VlcPlayer(controller: _controller),
          VlcPlayerControls(
            controller: _controller,
            title: widget.item.title,
            subtitle: widget.episode?.name,
            onBack: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}
