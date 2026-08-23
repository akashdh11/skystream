import 'package:flutter/material.dart';
import 'package:vlc_player/vlc_player.dart';

/// Audio and subtitle track selection for the VLC engine.
///
/// Phase 6 of docs/PLAYER_MIGRATION.md, whose whole point is that **the engine
/// owns the track list**. Nothing here caches, mirrors or merges tracks: the
/// list is read from the engine when the sheet opens and thrown away when it
/// closes.
///
/// That single decision deletes, rather than ports, the machinery the old
/// controller needs to keep its own copy in sync:
///
///   * `_scheduleAutoSubtitleSelection` — two engine-specific paths, a magic
///     800 ms delay for one and a track-stream listener racing a 2000 ms
///     timeout for the other. Fetching on open means there is no moment at
///     which we must guess whether tracks have arrived.
///   * `pendingVideoViewSubtitleIdsBeforeReload` /
///     `selectNewestVideoViewSubtitleAfterReload` — state kept solely to
///     survive a reload. If the engine is the only source, a reload needs no
///     reconciliation.
///   * The `external:` id scheme and the two-list merge of stream-provided and
///     user-added subtitles. VLC's `addSubtitle` makes an external file a real
///     track, so there is one list and one kind of id.
///
/// Track ids here are libVLC's own ints. We never invent an id namespace.
class VlcTrackSheet extends StatefulWidget {
  const VlcTrackSheet({required this.controller, super.key});

  final VlcPlayerController controller;

  static Future<void> show(
    BuildContext context,
    VlcPlayerController controller,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      isScrollControlled: true,
      builder: (_) => VlcTrackSheet(controller: controller),
    );
  }

  @override
  State<VlcTrackSheet> createState() => _VlcTrackSheetState();
}

class _VlcTrackSheetState extends State<VlcTrackSheet> {
  late Future<_Tracks> _tracks;

  @override
  void initState() {
    super.initState();
    _tracks = _load();
  }

  /// Asked for at the moment the user wants to see them, which is the only
  /// point at which the answer is both needed and reliable.
  Future<_Tracks> _load() async {
    final audio = await widget.controller.getAudioTracks();
    final subtitle = await widget.controller.getSubtitleTracks();
    return _Tracks(audio: audio, subtitle: subtitle);
  }

  void _reload() => setState(() => _tracks = _load());

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<_Tracks>(
        future: _tracks,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not read tracks: ${snapshot.error}',
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }
          final tracks = snapshot.data!;
          return ListView(
            shrinkWrap: true,
            children: [
              _header('Audio'),
              if (tracks.audio.isEmpty)
                _empty('No audio tracks reported')
              else
                ...tracks.audio.map(
                  (t) => _trackTile(
                    t,
                    onTap: () async {
                      await widget.controller.setAudioTrack(t.id);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ),
              const Divider(height: 1, color: Colors.white12),
              _header('Subtitles'),
              ListTile(
                dense: true,
                leading: const Icon(Icons.subtitles_off, color: Colors.white70),
                title: const Text(
                  'Off',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  await widget.controller.disableSubtitle();
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              ...tracks.subtitle.map(
                (t) => _trackTile(
                  t,
                  onTap: () async {
                    await widget.controller.setSubtitleTrack(t.id);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              _delayRow(),
            ],
          );
        },
      ),
    );
  }

  Widget _header(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    child: Text(text, style: const TextStyle(color: Colors.white38)),
  );

  Widget _trackTile(VlcTrackDescription track, {required VoidCallback onTap}) {
    final language = track.language;
    return ListTile(
      dense: true,
      title: Text(
        track.name.isEmpty ? 'Track ${track.id}' : track.name,
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: (language == null || language.isEmpty)
          ? null
          : Text(language, style: const TextStyle(color: Colors.white54)),
      onTap: onTap,
    );
  }

  /// Subtitle delay is one of the few things VLC genuinely exposes at runtime,
  /// unlike appearance — see docs/PLAYER_MIGRATION.md section 3.
  Widget _delayRow() {
    return ValueListenableBuilder<VlcPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final ms = value.subtitleDelay.inMilliseconds;
        return ListTile(
          dense: true,
          title: const Text(
            'Subtitle delay',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            '${ms >= 0 ? '+' : ''}${(ms / 1000).toStringAsFixed(1)}s',
            style: const TextStyle(color: Colors.white54),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, color: Colors.white),
                onPressed: () => widget.controller.setSubtitleDelay(
                  Duration(milliseconds: ms - 500),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: () => widget.controller.setSubtitleDelay(
                  Duration(milliseconds: ms + 500),
                ),
              ),
            ],
          ),
          onLongPress: _reload,
        );
      },
    );
  }
}

class _Tracks {
  const _Tracks({required this.audio, required this.subtitle});
  final List<VlcTrackDescription> audio;
  final List<VlcTrackDescription> subtitle;
}
