import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

class PlayerPlatformService {
  Future<void> enterPip(bool isPlaying) async {
    try {
      const platform = MethodChannel('dev.akash.skystream.player/pip');
      await platform.invokeMethod('enterPip', {'isPlaying': isPlaying});
    } catch (e) {
      if (kDebugMode) debugPrint("PIP Error: $e");
    }
  }

  void syncPipState(bool isPlaying) {
    if (Platform.isAndroid) {
      const MethodChannel(
        'dev.akash.skystream.player/pip',
      ).invokeMethod('setPipState', {'isPlaying': isPlaying});
    }
  }

  void toggleOrientation(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    if (orientation == Orientation.landscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  void updateOrientation(int? width, int? height) {
    try {
      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) return;
    } catch (e) {
      if (kDebugMode) debugPrint('PlayerPlatformService.updateOrientation: $e');
    }

    if (width != null && height != null && width > 0 && height > 0) {
      if (width >= height) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      }
    }
  }

  /// Leaves full screen, whatever put the window there.
  ///
  /// Deliberately not a toggle. The player only ever wants to *exit* on the way
  /// out, and a toggle would depend on mirrored state that is wrong the moment
  /// the user uses the OS window control instead of ours - which then leaves
  /// them stranded in a chrome-less full-screen window after the video closes.
  /// Setting false unconditionally is a no-op when already windowed.
  Future<void> exitFullscreen() async {
    if (Platform.isAndroid || Platform.isIOS) return;
    try {
      if (await windowManager.isFullScreen()) {
        await windowManager.setFullScreen(false);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('PlayerPlatformService.exitFullscreen: $e');
    }
  }

  Future<bool> toggleFullscreen() async {
    if (Platform.isAndroid || Platform.isIOS) return false;
    try {
      final isFull = await windowManager.isFullScreen();
      if (!isFull) {
        await windowManager.setFullScreen(true);
        return true;
      } else {
        await windowManager.setFullScreen(false);
        return false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('PlayerPlatformService.toggleFullscreen: $e');
    }
    return false;
  }
}
