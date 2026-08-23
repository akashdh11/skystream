import 'package:flutter/material.dart';
import 'package:vlc_player/vlc_player.dart';

import 'player_example_view.dart';

class HlsExamplePage extends StatefulWidget {
  const HlsExamplePage({
    super.key,
    this.showPlayer = true,
    this.source,
    this.playerOptions = const <String>[],
  });

  final bool showPlayer;
  final Uri? source;
  final List<String> playerOptions;

  @override
  State<HlsExamplePage> createState() => _HlsExamplePageState();
}

class _HlsExamplePageState extends State<HlsExamplePage> {
  late final VlcPlayerController _controller = VlcPlayerController(
    mediaSource: VlcMediaSource(
      uri:
          widget.source ??
          Uri.parse('https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8'),
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
      title: 'HLS stream',
      source: 'M3U8 sample stream',
      controller: _controller,
      showPlayer: widget.showPlayer,
    );
  }
}
