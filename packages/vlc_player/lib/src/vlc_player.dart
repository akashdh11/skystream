import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'vlc_player_controller.dart';
import 'vlc_player_controller_internals.dart';
import 'vlc_player_value.dart';
import 'vlc_video_fit.dart';

const String _viewType = 'plugins.lingjhf.com/vlc_player/view';

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

    // Fit is applied to the running player rather than rebuilding the view.
    if (oldWidget.fit != widget.fit && widget.controller.isAttached) {
      unawaited(widget.controller.setFit(widget.fit));
    }

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
        child: _excludeFromFocus(
          AndroidView(
            key: ValueKey<String>(_platformViewKey),
            viewType: _viewType,
            creationParams: <String, Object?>{
              'options': widget.controller.options,
              'fit': widget.fit.name,
            },
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _handlePlatformViewCreated,
          ),
        ),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return ColoredBox(
        color: widget.backgroundColor,
        child: _excludeFromFocus(
          UiKitView(
            key: ValueKey<String>(_platformViewKey),
            viewType: _viewType,
            creationParams: <String, Object?>{
              'options': widget.controller.options,
              'fit': widget.fit.name,
            },
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _handlePlatformViewCreated,
          ),
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
      child: _excludeFromFocus(
        AppKitView(
          key: ValueKey<String>(_platformViewKey),
          viewType: _viewType,
          creationParams: <String, Object?>{
            'options': widget.controller.options,
            'fit': widget.fit.name,
          },
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _handlePlatformViewCreated,
        ),
      ),
    );
  }

  /// Wraps the platform view so it never participates in focus traversal.
  ///
  /// Flutter inserts a `Focus` node around every platform view — see
  /// `flutter/lib/src/widgets/platform_view.dart`, which declares `_focusNode`,
  /// builds `Focus(focusNode: _focusNode, ...)` and installs an `onFocus`
  /// callback that calls `requestFocus()`. That node exists regardless of what
  /// the native view does, and it defaults to `canRequestFocus: true` /
  /// `skipTraversal: false`.
  ///
  /// On a TV that is a real bug, not a nicety. A full-screen video surface is a
  /// focusable candidate covering the whole screen, so when a host hides its
  /// controls (and with them their focus nodes) the video node is the only
  /// thing left to take focus. Hosts that detect "nothing is focused" by
  /// comparing `FocusManager.instance.primaryFocus` against their own root then
  /// see something focused, stand aside, and no one handles the remote's
  /// Play/Pause. Focus also becomes invisible.
  ///
  /// `ExcludeFocus` sets `descendantsAreFocusable: false`, drops the node from
  /// `traversalDescendants`, and neutralises the engine's `requestFocus`.
  /// Texture-backed platforms do not need this — a `Texture` contributes no
  /// focus node — which is why this only wraps the platform-view branches.
  Widget _excludeFromFocus(Widget platformView) =>
      ExcludeFocus(child: platformView);

  void _handlePlatformViewCreated(int viewId) {
    unawaited(_attachPlatformView(widget.controller, viewId));
  }

  /// Deliberately excludes `fit`.
  ///
  /// It used to be part of this key, which meant every change of video fit
  /// tore down and rebuilt the platform view — recreating the entire LibVLC
  /// instance and stalling playback. Fit is now pushed to the running player
  /// via setFit() in didUpdateWidget.
  String get _platformViewKey => '${identityHashCode(widget.controller)}';

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
