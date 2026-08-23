import 'package:flutter/material.dart';
import 'package:vlc_player/vlc_player.dart';

import 'player_example_view.dart';

class VideoExamplePage extends StatefulWidget {
  const VideoExamplePage({
    super.key,
    this.showPlayer = true,
    this.source,
    this.playerOptions = const <String>[],
  });

  final bool showPlayer;
  final Uri? source;
  final List<String> playerOptions;

  @override
  State<VideoExamplePage> createState() => _VideoExamplePageState();
}

class _VideoExamplePageState extends State<VideoExamplePage> {
  late final VlcPlayerController _controller = VlcPlayerController(
    mediaSource: VlcMediaSource(
      uri:
          widget.source ??
          Uri.parse('https://media.w3.org/2010/05/sintel/trailer.mp4'),
    ),
    options: widget.playerOptions,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlayerExampleView(
      title: 'Video file',
      source: 'MP4 sample video',
      controller: _controller,
      showPlayer: widget.showPlayer,
    );
  }
}
