import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'vlc_player_controller.dart';
import 'vlc_player_controller_internals.dart';
import 'vlc_player_value.dart';

const String _viewType = 'plugins.lingjhf.com/vlc_player/view';

/// How video should be fitted inside the `VlcPlayer` widget bounds.
enum VlcVideoFit {
  /// Preserve the video aspect ratio and show the full frame.
  contain,

  /// Preserve the video aspect ratio and cover the full widget bounds.
  cover,

  /// Stretch the video to fill the widget bounds.
  fill,

  /// Render the video at its natural decoded size when available.
  none,
}

/// Widget that hosts the native VLC video output.
///
/// The widget creates a platform view on Android, iOS, and macOS, and a
/// texture-backed player on Windows and Linux. The owning widget should dispose
/// the [controller] when playback is no longer needed.
class VlcPlayer extends StatefulWidget {
  /// Creates a VLC player widget controlled by [controller].
  const VlcPlayer({
    super.key,
    required this.controller,
    this.backgroundColor = Colors.black,
    this.fit = VlcVideoFit.contain,
  });

  /// Controller used to load media, control playback, and observe state.
  final VlcPlayerController controller;

  /// Background color shown behind the native video output.
  final Color backgroundColor;

  /// How video should be fitted inside this widget.
  final VlcVideoFit fit;

  @override
  State<VlcPlayer> createState() => _VlcPlayerState();
}

class _VlcPlayerState extends State<VlcPlayer> {
  Future<int>? _textureId;
  int _textureGeneration = 0;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    if (_usesTexturePlayer) {
      _textureId = _attachTexturePlayer(widget.controller);
    }
  }

  @override
  void didUpdateWidget(VlcPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }

    if (_usesTexturePlayer) {
      _textureId = _attachTexturePlayer(widget.controller);
      unawaited(_detachPlayer(oldWidget.controller));
    } else {
      unawaited(_detachPlayer(oldWidget.controller));
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _textureGeneration++;
    unawaited(_detachPlayer(widget.controller));
    super.dispose();
  }

  bool get _usesTexturePlayer {
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return ColoredBox(
        color: widget.backgroundColor,
        child: AndroidView(
          key: ValueKey<String>(_platformViewKey),
          viewType: _viewType,
          creationParams: <String, Object?>{
            'options': widget.controller.options,
            'fit': widget.fit.name,
          },
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _handlePlatformViewCreated,
        ),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return ColoredBox(
        color: widget.backgroundColor,
        child: UiKitView(
          key: ValueKey<String>(_platformViewKey),
          viewType: _viewType,
          creationParams: <String, Object?>{
            'options': widget.controller.options,
            'fit': widget.fit.name,
          },
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _handlePlatformViewCreated,
        ),
      );
    }

    if (_usesTexturePlayer) {
      return ColoredBox(
        color: widget.backgroundColor,
        child: FutureBuilder<int>(
          future: _textureId,
          builder: (context, snapshot) {
            final textureId = snapshot.data;
            if (textureId != null) {
              return ValueListenableBuilder<VlcPlayerValue>(
                valueListenable: widget.controller,
                builder: (context, value, child) {
                  return _fitTexture(textureId, value.videoSize);
                },
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                ),
              );
            }
            return const Center(child: CircularProgressIndicator());
          },
        ),
      );
    }

    if (defaultTargetPlatform != TargetPlatform.macOS) {
      return ColoredBox(
        color: widget.backgroundColor,
        child: const Center(
          child: Text(
            'vlc_player currently supports Android, iOS, macOS, Windows and Linux only.',
          ),
        ),
      );
    }

    return ColoredBox(
      color: widget.backgroundColor,
      child: AppKitView(
        key: ValueKey<String>(_platformViewKey),
        viewType: _viewType,
        creationParams: <String, Object?>{
          'options': widget.controller.options,
          'fit': widget.fit.name,
        },
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _handlePlatformViewCreated,
      ),
    );
  }

  void _handlePlatformViewCreated(int viewId) {
    unawaited(_attachPlatformView(widget.controller, viewId));
  }

  String get _platformViewKey {
    return '${identityHashCode(widget.controller)}-${widget.fit.name}';
  }

  Future<int> _attachTexturePlayer(VlcPlayerController controller) async {
    final generation = ++_textureGeneration;
    final textureId = await _attachTextureBackedPlayer(controller);
    if (_isDisposed ||
        generation != _textureGeneration ||
        widget.controller != controller) {
      await _detachPlayer(controller);
    }
    return textureId;
  }

  Future<void> _attachPlatformView(VlcPlayerController controller, int viewId) {
    return (controller as VlcPlayerControllerInternals).attach(viewId);
  }

  Future<int> _attachTextureBackedPlayer(VlcPlayerController controller) {
    return (controller as VlcPlayerControllerInternals).attachTexturePlayer();
  }

  Future<void> _detachPlayer(VlcPlayerController controller) {
    return (controller as VlcPlayerControllerInternals).detach();
  }

  Widget _fitTexture(int textureId, Size? videoSize) {
    final texture = Texture(textureId: textureId);
    final size = videoSize;
    if (widget.fit == VlcVideoFit.fill || size == null) {
      return SizedBox.expand(child: texture);
    }

    final sizedTexture = SizedBox(
      width: size.width,
      height: size.height,
      child: texture,
    );
    return Center(
      child: FittedBox(
        fit: switch (widget.fit) {
          VlcVideoFit.contain => BoxFit.contain,
          VlcVideoFit.cover => BoxFit.cover,
          VlcVideoFit.none => BoxFit.none,
          VlcVideoFit.fill => BoxFit.fill,
        },
        child: sizedTexture,
      ),
    );
  }
}
