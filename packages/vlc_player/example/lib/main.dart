import 'package:flutter/material.dart';

import 'src/full_player_example_page.dart';
import 'src/hls_example_page.dart';
import 'src/video_example_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.showPlayer = true,
    this.videoSource,
    this.hlsSource,
    this.playerOptions = const <String>[],
  });

  final bool showPlayer;
  final Uri? videoSource;
  final Uri? hlsSource;
  final List<String> playerOptions;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: _ExampleListPage(
        showPlayer: showPlayer,
        videoSource: videoSource,
        hlsSource: hlsSource,
        playerOptions: playerOptions,
      ),
    );
  }
}

class _ExampleListPage extends StatelessWidget {
  const _ExampleListPage({
    required this.showPlayer,
    required this.videoSource,
    required this.hlsSource,
    required this.playerOptions,
  });

  final bool showPlayer;
  final Uri? videoSource;
  final Uri? hlsSource;
  final List<String> playerOptions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('vlc_player example')),
      body: ListView(
        children: <Widget>[
          ListTile(
            key: const ValueKey<String>('video-example-tile'),
            title: const Text('Video file'),
            subtitle: const Text('Play an MP4 video file'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => VideoExamplePage(
                    showPlayer: showPlayer,
                    source: videoSource,
                    playerOptions: playerOptions,
                  ),
                ),
              );
            },
          ),
          ListTile(
            key: const ValueKey<String>('hls-example-tile'),
            title: const Text('HLS stream'),
            subtitle: const Text('Play an M3U8 HLS stream'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => HlsExamplePage(
                    showPlayer: showPlayer,
                    source: hlsSource,
                    playerOptions: playerOptions,
                  ),
                ),
              );
            },
          ),
          ListTile(
            key: const ValueKey<String>('full-player-example-tile'),
            title: const Text('Full player'),
            subtitle: const Text('Fullscreen controls, seek, and orientation'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FullPlayerExamplePage(
                    showPlayer: showPlayer,
                    playerOptions: playerOptions,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
