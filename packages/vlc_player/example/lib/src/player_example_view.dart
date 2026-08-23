import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vlc_player/vlc_player.dart';

class PlayerExampleView extends StatelessWidget {
  const PlayerExampleView({
    super.key,
    required this.title,
    required this.source,
    required this.controller,
    required this.showPlayer,
  });

  final String title;
  final String source;
  final VlcPlayerController controller;
  final bool showPlayer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(source, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: showPlayer
                  ? VlcPlayer(controller: controller)
                  : const ColoredBox(color: Colors.black),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<VlcPlayerValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                final canControl = showPlayer && controller.isAttached;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    IconButton(
                      key: ValueKey<String>('${title.toLowerCase()}-play'),
                      onPressed: canControl
                          ? () => unawaited(
                              _runPlayerCommand(context, controller.play),
                            )
                          : null,
                      icon: const Icon(Icons.play_arrow),
                      tooltip: 'Play $title',
                    ),
                    IconButton(
                      key: ValueKey<String>('${title.toLowerCase()}-pause'),
                      onPressed: canControl
                          ? () => unawaited(
                              _runPlayerCommand(context, controller.pause),
                            )
                          : null,
                      icon: const Icon(Icons.pause),
                      tooltip: 'Pause $title',
                    ),
                    IconButton(
                      key: ValueKey<String>('${title.toLowerCase()}-stop'),
                      onPressed: canControl
                          ? () => unawaited(
                              _runPlayerCommand(context, controller.stop),
                            )
                          : null,
                      icon: const Icon(Icons.stop),
                      tooltip: 'Stop $title',
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runPlayerCommand(
    BuildContext context,
    Future<void> Function() command,
  ) async {
    try {
      await command();
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Player command failed: $error')));
    }
  }
}
