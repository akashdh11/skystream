import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vlc_player/vlc_player.dart';

class FullPlayerExamplePage extends StatefulWidget {
  const FullPlayerExamplePage({
    super.key,
    this.showPlayer = true,
    this.playerOptions = const <String>[],
  });

  final bool showPlayer;
  final List<String> playerOptions;

  @override
  State<FullPlayerExamplePage> createState() => _FullPlayerExamplePageState();
}

class _FullPlayerExamplePageState extends State<FullPlayerExamplePage> {
  late final VlcPlayerController _controller = VlcPlayerController(
    mediaSource: VlcMediaSource(
      uri: Uri.parse('https://media.w3.org/2010/05/sintel/trailer.mp4'),
    ),
    options: widget.playerOptions,
  );

  bool _isLandscape = false;
  bool _wantsPlaying = false;
  VlcVideoFit _fit = VlcVideoFit.contain;
  double? _dragValue;
  double? _pendingSeekTarget;

  @override
  void dispose() {
    unawaited(_restoreSystemUi());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          unawaited(_restoreSystemUi());
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: ValueListenableBuilder<VlcPlayerValue>(
            valueListenable: _controller,
            builder: (context, value, child) {
              final displayedSeekValue = _displayedSeekValue(value);
              return Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: widget.showPlayer
                            ? VlcPlayer(controller: _controller, fit: _fit)
                            : const ColoredBox(color: Colors.black),
                      ),
                    ),
                  ),
                  if (_showsLoading(value))
                    Center(
                      child: SizedBox.square(
                        dimension: 44,
                        child: CircularProgressIndicator(
                          value: value.bufferingProgress,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      color: Colors.white,
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _PlayerControls(
                      value: value,
                      canControl: widget.showPlayer && _controller.isAttached,
                      isPlaying: _isShowingPlaying(value),
                      isLandscape: _isLandscape,
                      fit: _fit,
                      seekValue: displayedSeekValue,
                      onPlayPause: () => unawaited(_togglePlayPause(value)),
                      onSnapshot: () => unawaited(_takeSnapshot()),
                      onCycleFit: _cycleFit,
                      onSeekStart: (value) {
                        setState(() {
                          _dragValue = value;
                        });
                      },
                      onSeekChanged: (value) {
                        setState(() {
                          _dragValue = value;
                        });
                      },
                      onSeekEnd: (seconds) =>
                          unawaited(_seekTo(seconds, value)),
                      onToggleOrientation: () =>
                          unawaited(_toggleOrientation()),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _togglePlayPause(VlcPlayerValue value) async {
    if (!widget.showPlayer || !_controller.isAttached) {
      return;
    }
    final wasPlaying = _isShowingPlaying(value);
    setState(() {
      _wantsPlaying = !wasPlaying;
    });
    final succeeded = await _runPlayerCommand(
      wasPlaying ? _controller.pause : _controller.play,
    );
    if (!succeeded && mounted) {
      setState(() {
        _wantsPlaying = wasPlaying;
      });
    }
  }

  Future<void> _takeSnapshot() async {
    if (!widget.showPlayer || !_controller.isAttached) {
      return;
    }
    try {
      final bytes = await _controller.takeSnapshot(width: 320);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Snapshot captured (${bytes.length} bytes)')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Snapshot failed: $error')));
    }
  }

  void _cycleFit() {
    final values = VlcVideoFit.values;
    setState(() {
      _fit = values[(_fit.index + 1) % values.length];
    });
  }

  bool _isShowingPlaying(VlcPlayerValue value) {
    if (value.isPlaying) {
      return true;
    }
    if (value.state == VlcPlaybackState.paused ||
        value.state == VlcPlaybackState.stopped ||
        value.state == VlcPlaybackState.ended ||
        value.state == VlcPlaybackState.error) {
      return false;
    }
    return _wantsPlaying;
  }

  bool _showsLoading(VlcPlayerValue value) {
    return widget.showPlayer &&
        _controller.isAttached &&
        !value.isReady &&
        !value.hasError;
  }

  Future<void> _seekTo(double seconds, VlcPlayerValue value) async {
    if (!value.isReady || !value.isSeekable || value.isLive) {
      return;
    }
    final target = Duration(milliseconds: (seconds * 1000).round());
    setState(() {
      _dragValue = seconds;
      _pendingSeekTarget = seconds;
    });
    final succeeded = await _runPlayerCommand(() => _controller.seekTo(target));
    if (!succeeded && mounted) {
      setState(() {
        _dragValue = null;
        _pendingSeekTarget = null;
      });
    }
  }

  double? _displayedSeekValue(VlcPlayerValue value) {
    final pending = _pendingSeekTarget;
    if (pending == null) {
      return _dragValue;
    }

    final positionSeconds = value.position.inMilliseconds / 1000;
    if ((positionSeconds - pending).abs() < 0.75) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _pendingSeekTarget != pending) {
          return;
        }
        setState(() {
          _pendingSeekTarget = null;
          _dragValue = null;
        });
      });
      return _dragValue;
    }
    return _dragValue ?? pending;
  }

  Future<void> _toggleOrientation() async {
    final nextLandscape = !_isLandscape;
    setState(() {
      _isLandscape = nextLandscape;
    });
    if (!_supportsPreferredOrientations) {
      return;
    }
    await SystemChrome.setPreferredOrientations(
      nextLandscape
          ? <DeviceOrientation>[
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : <DeviceOrientation>[
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ],
    );
  }

  Future<void> _restoreSystemUi() {
    if (!_supportsPreferredOrientations) {
      return Future<void>.value();
    }
    return SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  bool get _supportsPreferredOrientations {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<bool> _runPlayerCommand(Future<void> Function() command) async {
    try {
      await command();
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Player command failed: $error')));
      return false;
    }
  }
}

class _PlayerControls extends StatelessWidget {
  const _PlayerControls({
    required this.value,
    required this.canControl,
    required this.isPlaying,
    required this.isLandscape,
    required this.fit,
    required this.seekValue,
    required this.onPlayPause,
    required this.onSnapshot,
    required this.onCycleFit,
    required this.onSeekStart,
    required this.onSeekChanged,
    required this.onSeekEnd,
    required this.onToggleOrientation,
  });

  final VlcPlayerValue value;
  final bool canControl;
  final bool isPlaying;
  final bool isLandscape;
  final VlcVideoFit fit;
  final double? seekValue;
  final VoidCallback onPlayPause;
  final VoidCallback onSnapshot;
  final VoidCallback onCycleFit;
  final ValueChanged<double> onSeekStart;
  final ValueChanged<double> onSeekChanged;
  final ValueChanged<double> onSeekEnd;
  final VoidCallback onToggleOrientation;

  @override
  Widget build(BuildContext context) {
    final durationSeconds = value.duration.inMilliseconds / 1000;
    final positionSeconds = value.position.inMilliseconds / 1000;
    final canSeek =
        canControl && value.isReady && value.isSeekable && !value.isLive;
    final maxSeconds = canSeek && durationSeconds > 0 ? durationSeconds : 1.0;
    final sliderValue = canSeek
        ? (seekValue ?? positionSeconds).clamp(0.0, maxSeconds)
        : 0.0;
    final displayedPosition = Duration(
      milliseconds: ((canSeek ? sliderValue : positionSeconds) * 1000).round(),
    );
    final durationLabel = value.isLive
        ? 'LIVE'
        : _formatDuration(value.duration);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.82),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Slider(
              key: const ValueKey<String>('full-player-seek-slider'),
              value: sliderValue,
              max: maxSeconds,
              onChangeStart: canSeek ? onSeekStart : null,
              onChanged: canSeek ? onSeekChanged : null,
              onChangeEnd: canSeek ? onSeekEnd : null,
            ),
            Row(
              children: <Widget>[
                IconButton(
                  key: const ValueKey<String>('full-player-play-pause-button'),
                  onPressed: canControl ? onPlayPause : null,
                  color: Colors.white,
                  disabledColor: Colors.white38,
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                  tooltip: isPlaying ? 'Pause' : 'Play',
                ),
                Text(
                  '${_formatDuration(displayedPosition)} / $durationLabel',
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                IconButton(
                  key: const ValueKey<String>('full-player-snapshot-button'),
                  onPressed: canControl && value.isReady ? onSnapshot : null,
                  color: Colors.white,
                  disabledColor: Colors.white38,
                  icon: const Icon(Icons.camera_alt),
                  tooltip: 'Snapshot',
                ),
                IconButton(
                  key: const ValueKey<String>('full-player-fit-button'),
                  onPressed: onCycleFit,
                  color: Colors.white,
                  icon: const Icon(Icons.fit_screen),
                  tooltip: 'Fit ${fit.name}',
                ),
                IconButton(
                  key: const ValueKey<String>('full-player-orientation-button'),
                  onPressed: onToggleOrientation,
                  color: Colors.white,
                  icon: Icon(
                    isLandscape
                        ? Icons.stay_current_portrait
                        : Icons.stay_current_landscape,
                  ),
                  tooltip: isLandscape ? 'Portrait' : 'Landscape',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
